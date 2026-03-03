#!/usr/bin/env bash
# =============================================================================
# Fichier     : setup-docker-host.sh
# Description : Script de configuration complète de la VM Docker-Host Ubuntu 22.04
#               pour le PFE IoT Security - Phase 1
# Version     : 1.0
# Auteur      : PFE IoT Security Team
# Date        : 2026-03-03
# Usage       : sudo bash setup-docker-host.sh
# Prérequis   : Ubuntu 22.04 Server, 2 interfaces réseau (eth0=VMnet3, eth1=VMnet8)
# =============================================================================

set -euo pipefail

# --- Couleurs pour les messages ---
ROUGE='\033[0;31m'
VERT='\033[0;32m'
JAUNE='\033[1;33m'
BLEU='\033[0;34m'
CYAN='\033[0;36m'
RESET='\033[0m'
GRAS='\033[1m'

# --- Fonctions de logging ---
info()    { echo -e "${BLEU}[INFO]${RESET}  $*"; }
succes()  { echo -e "${VERT}[OK]${RESET}    $*"; }
avert()   { echo -e "${JAUNE}[AVERT]${RESET} $*"; }
erreur()  { echo -e "${ROUGE}[ERREUR]${RESET} $*"; exit 1; }
etape()   { echo -e "\n${CYAN}${GRAS}>>> $* <<<${RESET}\n"; }

# --- Variables de configuration ---
INTERFACE_GNS3="eth0"       # Interface connectée à VMnet3 (réseau GNS3)
INTERFACE_NAT="eth1"        # Interface connectée à VMnet8 (NAT internet)
IP_VLAN10="192.168.10.100"  # IP Docker-Host dans VLAN10 IoT
IP_VLAN20="192.168.20.100"  # IP Docker-Host dans VLAN20 SIEM
IP_VLAN30="192.168.30.100"  # IP Docker-Host dans VLAN30 Management
GW_VLAN10="192.168.10.1"    # Gateway VLAN10 (MikroTik)
GW_VLAN20="192.168.20.1"    # Gateway VLAN20 (MikroTik)
GW_VLAN30="192.168.30.1"    # Gateway VLAN30 (MikroTik)
REPO_URL="https://github.com/AmineGhannouchi/PFE-IoT-Security"
REPO_DIR="/opt/PFE-IoT-Security"

# =============================================================================
# Vérification des prérequis
# =============================================================================
etape "Vérification des prérequis"

# Vérifier que le script est exécuté en root
if [[ $EUID -ne 0 ]]; then
    erreur "Ce script doit être exécuté en tant que root (sudo bash $0)"
fi

# Vérifier Ubuntu 22.04
if ! grep -q "22.04" /etc/os-release 2>/dev/null; then
    avert "Ce script est optimisé pour Ubuntu 22.04 LTS"
fi

succes "Prérequis vérifiés"

# =============================================================================
# Étape 1 : Mise à jour du système
# =============================================================================
etape "Étape 1/8 : Mise à jour du système"

info "Mise à jour de la liste des paquets..."
apt-get update -qq

info "Mise à jour des paquets installés..."
DEBIAN_FRONTEND=noninteractive apt-get upgrade -y -qq

succes "Système mis à jour"

# =============================================================================
# Étape 2 : Installation de Docker CE
# =============================================================================
etape "Étape 2/8 : Installation de Docker CE"

if command -v docker &>/dev/null; then
    avert "Docker est déjà installé : $(docker --version)"
else
    info "Installation des dépendances Docker..."
    DEBIAN_FRONTEND=noninteractive apt-get install -y -qq \
        ca-certificates curl gnupg lsb-release apt-transport-https

    info "Ajout de la clé GPG officielle Docker..."
    install -m 0755 -d /etc/apt/keyrings
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg \
        | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
    chmod a+r /etc/apt/keyrings/docker.gpg

    info "Ajout du dépôt Docker..."
    echo \
        "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] \
        https://download.docker.com/linux/ubuntu \
        $(. /etc/os-release && echo "$VERSION_CODENAME") stable" \
        | tee /etc/apt/sources.list.d/docker.list > /dev/null

    apt-get update -qq
    DEBIAN_FRONTEND=noninteractive apt-get install -y -qq \
        docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

    # Activer et démarrer Docker
    systemctl enable --now docker
    succes "Docker CE installé : $(docker --version)"
fi

# Ajouter l'utilisateur courant au groupe docker (si ce n'est pas root)
if [[ -n "${SUDO_USER:-}" ]]; then
    usermod -aG docker "$SUDO_USER"
    succes "Utilisateur $SUDO_USER ajouté au groupe docker"
fi

# =============================================================================
# Étape 3 : Installation des outils réseau
# =============================================================================
etape "Étape 3/8 : Installation des outils réseau"

info "Installation de net-tools, tcpdump, iproute2, vlan..."
DEBIAN_FRONTEND=noninteractive apt-get install -y -qq \
    net-tools \
    tcpdump \
    iproute2 \
    vlan \
    iputils-ping \
    netcat-openbsd \
    curl \
    wget \
    jq \
    git \
    vim

# Charger le module kernel 8021q pour les VLANs
if ! lsmod | grep -q "^8021q"; then
    modprobe 8021q
    echo "8021q" >> /etc/modules
    succes "Module kernel 8021q chargé"
else
    succes "Module kernel 8021q déjà actif"
fi

# =============================================================================
# Étape 4 : Configuration des interfaces VLAN via Netplan
# =============================================================================
etape "Étape 4/8 : Configuration des interfaces VLAN (Netplan)"

NETPLAN_FILE="/etc/netplan/99-vlans.yaml"

info "Création du fichier Netplan : $NETPLAN_FILE"

cat > "$NETPLAN_FILE" << EOF
# =============================================================================
# Fichier     : 99-vlans.yaml
# Description : Configuration VLAN pour Docker-Host - PFE IoT Security
# Version     : 1.0
# Généré par  : setup-docker-host.sh
# =============================================================================
network:
  version: 2
  renderer: networkd

  ethernets:
    # Interface GNS3 (VMnet3 - réseau host-only)
    ${INTERFACE_GNS3}:
      dhcp4: false
      dhcp6: false

    # Interface NAT (VMnet8 - accès internet)
    ${INTERFACE_NAT}:
      dhcp4: true
      dhcp6: false

  vlans:
    # VLAN 10 - Réseau IoT
    ${INTERFACE_GNS3}.10:
      id: 10
      link: ${INTERFACE_GNS3}
      addresses:
        - ${IP_VLAN10}/24
      routes:
        - to: 192.168.10.0/24
          via: ${GW_VLAN10}

    # VLAN 20 - Réseau SIEM
    ${INTERFACE_GNS3}.20:
      id: 20
      link: ${INTERFACE_GNS3}
      addresses:
        - ${IP_VLAN20}/24
      routes:
        - to: 192.168.20.0/24
          via: ${GW_VLAN20}

    # VLAN 30 - Réseau Management/PKI
    ${INTERFACE_GNS3}.30:
      id: 30
      link: ${INTERFACE_GNS3}
      addresses:
        - ${IP_VLAN30}/24
      routes:
        - to: 192.168.30.0/24
          via: ${GW_VLAN30}
EOF

# Restreindre les permissions Netplan (requis depuis Ubuntu 22.04)
chmod 600 "$NETPLAN_FILE"

info "Application de la configuration Netplan..."
netplan apply

succes "Interfaces VLAN configurées :"
succes "  ${INTERFACE_GNS3}.10 → ${IP_VLAN10}/24 (VLAN10 IoT)"
succes "  ${INTERFACE_GNS3}.20 → ${IP_VLAN20}/24 (VLAN20 SIEM)"
succes "  ${INTERFACE_GNS3}.30 → ${IP_VLAN30}/24 (VLAN30 Management)"

# =============================================================================
# Étape 5 : Création de la structure de répertoires Docker
# =============================================================================
etape "Étape 5/8 : Création de la structure de répertoires"

DOCKER_DIR="/opt/docker-host"

mkdir -p "${DOCKER_DIR}"/{mosquitto/{config,data,log},vault/{config,data},sensors,gateway}

succes "Structure créée dans ${DOCKER_DIR}"

# =============================================================================
# Étape 6 : Clone du dépôt PFE-IoT-Security
# =============================================================================
etape "Étape 6/8 : Clone du dépôt PFE-IoT-Security"

if [[ -d "$REPO_DIR" ]]; then
    info "Le dépôt existe déjà, mise à jour..."
    git -C "$REPO_DIR" pull --ff-only
else
    info "Clone du dépôt depuis $REPO_URL..."
    git clone "$REPO_URL" "$REPO_DIR"
fi

# Copier les fichiers de configuration vers le répertoire Docker
if [[ -d "$REPO_DIR/01-Infrastructure/Docker-Host" ]]; then
    info "Copie des fichiers de configuration..."
    cp -r "$REPO_DIR/01-Infrastructure/Docker-Host/." "${DOCKER_DIR}/"
    succes "Fichiers de configuration copiés"
fi

# =============================================================================
# Étape 7 : Configuration du service systemd pour démarrage automatique
# =============================================================================
etape "Étape 7/8 : Configuration du démarrage automatique"

SYSTEMD_SERVICE="/etc/systemd/system/pfe-docker-infrastructure.service"

cat > "$SYSTEMD_SERVICE" << 'EOF'
# =============================================================================
# Service systemd pour démarrage automatique de l'infrastructure Docker
# PFE IoT Security - Phase 1
# =============================================================================
[Unit]
Description=PFE IoT Security - Infrastructure Docker
After=docker.service network-online.target
Requires=docker.service
Wants=network-online.target

[Service]
Type=oneshot
RemainAfterExit=yes
WorkingDirectory=/opt/docker-host
ExecStart=/usr/bin/docker compose up -d
ExecStop=/usr/bin/docker compose down
TimeoutStartSec=300
TimeoutStopSec=60

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable pfe-docker-infrastructure.service
succes "Service systemd créé et activé"

# =============================================================================
# Étape 8 : Tests de connectivité
# =============================================================================
etape "Étape 8/8 : Tests de connectivité"

info "Test des interfaces VLAN..."

# Test VLAN10
if ip link show "${INTERFACE_GNS3}.10" &>/dev/null; then
    succes "Interface ${INTERFACE_GNS3}.10 active"
else
    avert "Interface ${INTERFACE_GNS3}.10 non disponible (GNS3 non connecté ?)"
fi

# Test VLAN20
if ip link show "${INTERFACE_GNS3}.20" &>/dev/null; then
    succes "Interface ${INTERFACE_GNS3}.20 active"
else
    avert "Interface ${INTERFACE_GNS3}.20 non disponible (GNS3 non connecté ?)"
fi

# Test VLAN30
if ip link show "${INTERFACE_GNS3}.30" &>/dev/null; then
    succes "Interface ${INTERFACE_GNS3}.30 active"
else
    avert "Interface ${INTERFACE_GNS3}.30 non disponible (GNS3 non connecté ?)"
fi

# Test ping gateways (optionnel - peut échouer si MikroTik pas démarré)
info "Test ping vers les gateways MikroTik (5s timeout)..."
for gw in "$GW_VLAN10" "$GW_VLAN20" "$GW_VLAN30"; do
    if ping -c 1 -W 5 "$gw" &>/dev/null; then
        succes "  Gateway $gw → accessible"
    else
        avert "  Gateway $gw → non accessible (MikroTik démarré ?)"
    fi
done

# =============================================================================
# Résumé final
# =============================================================================
echo ""
echo -e "${VERT}${GRAS}============================================${RESET}"
echo -e "${VERT}${GRAS}  Docker-Host configuré avec succès !      ${RESET}"
echo -e "${VERT}${GRAS}============================================${RESET}"
echo ""
echo -e "${CYAN}Interfaces VLAN configurées :${RESET}"
echo -e "  VLAN10 IoT  : ${IP_VLAN10}/24 (${INTERFACE_GNS3}.10)"
echo -e "  VLAN20 SIEM : ${IP_VLAN20}/24 (${INTERFACE_GNS3}.20)"
echo -e "  VLAN30 Mgmt : ${IP_VLAN30}/24 (${INTERFACE_GNS3}.30)"
echo ""
echo -e "${CYAN}Prochaines étapes :${RESET}"
echo -e "  1. Démarrer GNS3 et la topologie PFE"
echo -e "  2. Vérifier la connectivité : ping ${GW_VLAN10}"
echo -e "  3. Démarrer les conteneurs : cd ${DOCKER_DIR} && docker compose up -d"
echo -e "  4. Vérifier les services  : docker compose ps"
echo ""
echo -e "${JAUNE}Fichiers importants :${RESET}"
echo -e "  Configuration Docker : ${DOCKER_DIR}/docker-compose.yml"
echo -e "  Dépôt PFE           : ${REPO_DIR}"
echo ""
