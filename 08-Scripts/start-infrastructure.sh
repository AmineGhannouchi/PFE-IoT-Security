#!/usr/bin/env bash
# =============================================================================
# Fichier     : start-infrastructure.sh
# Description : Script de démarrage de toute l'infrastructure Docker
#               PFE IoT Security - Phase 1
# Version     : 1.0
# Auteur      : PFE IoT Security Team
# Date        : 2026-03-03
# Usage       : bash start-infrastructure.sh
#               (Exécuter depuis Docker-Host Ubuntu 22.04)
# =============================================================================

set -euo pipefail

# --- Couleurs ---
ROUGE='\033[0;31m'
VERT='\033[0;32m'
JAUNE='\033[1;33m'
BLEU='\033[0;34m'
CYAN='\033[0;36m'
RESET='\033[0m'
GRAS='\033[1m'

# --- Fonctions ---
info()    { echo -e "${BLEU}[INFO]${RESET}  $*"; }
succes()  { echo -e "${VERT}[OK]${RESET}    $*"; }
avert()   { echo -e "${JAUNE}[AVERT]${RESET} $*"; }
erreur()  { echo -e "${ROUGE}[ERREUR]${RESET} $*"; exit 1; }
etape()   { echo -e "\n${CYAN}${GRAS}>>> $* <<<${RESET}\n"; }

# --- Répertoire de travail ---
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOCKER_DIR="${SCRIPT_DIR}/../01-Infrastructure/Docker-Host"

# Résoudre le chemin absolu
DOCKER_DIR="$(realpath "${DOCKER_DIR}" 2>/dev/null || echo "${SCRIPT_DIR}/../01-Infrastructure/Docker-Host")"

# =============================================================================
# En-tête
# =============================================================================
echo ""
echo -e "${BLEU}${GRAS}╔══════════════════════════════════════════════════════════╗${RESET}"
echo -e "${BLEU}${GRAS}║   PFE IoT Security - Démarrage de l'infrastructure       ║${RESET}"
echo -e "${BLEU}${GRAS}╚══════════════════════════════════════════════════════════╝${RESET}"
echo -e "  Date     : $(date '+%Y-%m-%d %H:%M:%S')"
echo -e "  Hostname : $(hostname)"
echo ""

# =============================================================================
# Étape 1 : Vérification des prérequis
# =============================================================================
etape "Étape 1/5 : Vérification des prérequis"

# Vérifier Docker
if ! command -v docker &>/dev/null; then
    erreur "Docker n'est pas installé. Exécuter d'abord : sudo bash setup-docker-host.sh"
fi
succes "Docker : $(docker --version | head -1)"

# Vérifier docker compose (v2)
if ! docker compose version &>/dev/null; then
    erreur "docker compose (v2) n'est pas disponible. Vérifier l'installation Docker CE."
fi
succes "Docker Compose : $(docker compose version | head -1)"

# Vérifier que Docker daemon est en cours d'exécution
if ! docker info &>/dev/null; then
    erreur "Le daemon Docker n'est pas démarré. Exécuter : sudo systemctl start docker"
fi
succes "Docker daemon : actif"

# Vérifier que le répertoire docker-compose existe
if [[ ! -f "${DOCKER_DIR}/docker-compose.yml" ]]; then
    erreur "Fichier docker-compose.yml non trouvé dans ${DOCKER_DIR}"
fi
succes "Configuration Docker : ${DOCKER_DIR}"

# =============================================================================
# Étape 2 : Vérification des interfaces VLAN
# =============================================================================
etape "Étape 2/5 : Vérification des interfaces VLAN"

INTERFACES_OK=true

for iface in "eth0.10" "eth0.20" "eth0.30"; do
    if ip link show "$iface" &>/dev/null; then
        IP=$(ip -4 addr show "$iface" 2>/dev/null | grep -oP '(?<=inet )\S+' || echo "non configurée")
        succes "Interface ${iface} : ${IP}"
    else
        avert "Interface ${iface} non trouvée (réseau GNS3 connecté ?)"
        INTERFACES_OK=false
    fi
done

if [[ "$INTERFACES_OK" == "false" ]]; then
    echo ""
    avert "Certaines interfaces VLAN sont manquantes."
    avert "Les réseaux macvlan Docker pourraient ne pas fonctionner."
    avert "S'assurer que la topologie GNS3 est démarrée et que VMnet3 est connecté."
    echo ""
    read -r -p "Continuer quand même ? [o/N] " continuer
    if [[ ! "$continuer" =~ ^[oOyY]$ ]]; then
        info "Démarrage annulé."
        exit 0
    fi
fi

# =============================================================================
# Étape 3 : Démarrage des services Docker
# =============================================================================
etape "Étape 3/5 : Démarrage des conteneurs Docker"

cd "${DOCKER_DIR}"

info "Démarrage des services avec docker compose..."
docker compose up -d --remove-orphans

succes "Commande docker compose up exécutée"

# =============================================================================
# Étape 4 : Attente du démarrage des services (health checks)
# =============================================================================
etape "Étape 4/5 : Attente du démarrage des services"

MAX_WAIT=120  # secondes maximum d'attente
INTERVAL=5    # secondes entre chaque vérification
ELAPSED=0

info "Attente du démarrage des services (max ${MAX_WAIT}s)..."

while [[ $ELAPSED -lt $MAX_WAIT ]]; do
    # Compter les services healthy
    HEALTHY=$(docker compose ps --format json 2>/dev/null \
        | python3 -c "import sys,json; data=[json.loads(l) for l in sys.stdin if l.strip()]; print(sum(1 for s in data if s.get('Health','') in ('healthy','')))" \
        2>/dev/null || echo "0")
    TOTAL=$(docker compose ps -q 2>/dev/null | wc -l | tr -d ' ')
    STARTING=$(docker compose ps --format json 2>/dev/null \
        | python3 -c "import sys,json; data=[json.loads(l) for l in sys.stdin if l.strip()]; print(sum(1 for s in data if s.get('Health','') == 'starting'))" \
        2>/dev/null || echo "0")

    info "Services démarrés : ${HEALTHY}/${TOTAL} (en démarrage : ${STARTING})..."

    if [[ "$STARTING" == "0" ]]; then
        break
    fi

    sleep $INTERVAL
    ((ELAPSED += INTERVAL))
done

if [[ $ELAPSED -ge $MAX_WAIT ]]; then
    avert "Timeout atteint (${MAX_WAIT}s). Certains services sont peut-être encore en démarrage."
fi

# =============================================================================
# Étape 5 : Affichage du statut final
# =============================================================================
etape "Étape 5/5 : Statut des services"

docker compose ps

echo ""
echo -e "${VERT}${GRAS}╔══════════════════════════════════════════════════════════╗${RESET}"
echo -e "${VERT}${GRAS}║        Infrastructure démarrée avec succès !              ║${RESET}"
echo -e "${VERT}${GRAS}╚══════════════════════════════════════════════════════════╝${RESET}"
echo ""
echo -e "${CYAN}Services disponibles :${RESET}"
echo -e "  MQTT Broker   : mqtt://192.168.10.20:1883"
echo -e "  MQTT WebSocket: ws://192.168.10.20:9001"
echo -e "  Vault UI      : http://192.168.30.10:8200/ui"
echo -e "  Vault API     : http://192.168.30.10:8200"
echo ""
echo -e "${CYAN}Commandes utiles :${RESET}"
echo -e "  Voir les logs    : docker compose logs -f"
echo -e "  Arrêter          : docker compose down"
echo -e "  Tests réseau     : bash ${SCRIPT_DIR}/test-network-connectivity.sh"
echo ""
echo -e "${JAUNE}Note : Wazuh Manager doit être démarré séparément depuis VMware${RESET}"
echo ""
