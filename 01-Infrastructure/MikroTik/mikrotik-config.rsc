# =============================================================================
# Fichier     : mikrotik-config.rsc
# Description : Configuration complète MikroTik CHR - Core Switch L3
#               Phase 1 du PFE IoT Security
# Version     : 1.0
# Auteur      : PFE IoT Security Team
# Date        : 2026-03-03
# Usage       : Importer via /import mikrotik-config.rsc
# =============================================================================

# -----------------------------------------------------------------------------
# Étape 1 : Identification du système
# -----------------------------------------------------------------------------
/system identity set name="CoreSwitch-L3"
/system clock set time-zone-name=Africa/Tunis

# -----------------------------------------------------------------------------
# Étape 2 : Configuration des interfaces physiques (commentaires)
# -----------------------------------------------------------------------------
/interface set ether1 comment="Uplink-pfSense (192.168.100.0/24)"
/interface set ether2 comment="VLAN10-IoT (192.168.10.0/24)"
/interface set ether3 comment="VLAN20-SIEM (192.168.20.0/24)"
/interface set ether4 comment="VLAN30-Management (192.168.30.0/24)"
/interface set ether5 comment="SPAN-Mirror-Suricata"

# -----------------------------------------------------------------------------
# Étape 3 : Configuration des interfaces VLAN
# Chaque VLAN est mappé sur une interface physique dédiée
# -----------------------------------------------------------------------------
/interface vlan add name=vlan10-iot   vlan-id=10 interface=ether2 comment="VLAN 10 IoT"
/interface vlan add name=vlan20-siem  vlan-id=20 interface=ether3 comment="VLAN 20 SIEM"
/interface vlan add name=vlan30-mgmt  vlan-id=30 interface=ether4 comment="VLAN 30 Management/PKI"

# -----------------------------------------------------------------------------
# Étape 4 : Adresses IP des passerelles (gateways)
# -----------------------------------------------------------------------------
# Uplink vers pfSense
/ip address add address=192.168.100.2/24 interface=ether1 comment="Uplink vers pfSense"

# Gateways VLAN
/ip address add address=192.168.10.1/24  interface=vlan10-iot  comment="Gateway VLAN10 IoT"
/ip address add address=192.168.20.1/24  interface=vlan20-siem comment="Gateway VLAN20 SIEM"
/ip address add address=192.168.30.1/24  interface=vlan30-mgmt comment="Gateway VLAN30 Management"

# -----------------------------------------------------------------------------
# Étape 5 : Route par défaut vers pfSense
# -----------------------------------------------------------------------------
/ip route add dst-address=0.0.0.0/0 gateway=192.168.100.1 comment="Route par défaut via pfSense"

# -----------------------------------------------------------------------------
# Étape 6 : DNS
# -----------------------------------------------------------------------------
/ip dns set servers=8.8.8.8,8.8.4.4 allow-remote-requests=yes

# -----------------------------------------------------------------------------
# Étape 7 : Pools DHCP par VLAN
# -----------------------------------------------------------------------------
/ip pool add name=pool-vlan10 ranges=192.168.10.100-192.168.10.200
/ip pool add name=pool-vlan20 ranges=192.168.20.100-192.168.20.200
/ip pool add name=pool-vlan30 ranges=192.168.30.100-192.168.30.200

# -----------------------------------------------------------------------------
# Étape 8 : Serveurs DHCP par VLAN
# -----------------------------------------------------------------------------
/ip dhcp-server add name=dhcp-vlan10 interface=vlan10-iot  address-pool=pool-vlan10 disabled=no
/ip dhcp-server add name=dhcp-vlan20 interface=vlan20-siem address-pool=pool-vlan20 disabled=no
/ip dhcp-server add name=dhcp-vlan30 interface=vlan30-mgmt address-pool=pool-vlan30 disabled=no

/ip dhcp-server network add address=192.168.10.0/24 gateway=192.168.10.1 dns-server=8.8.8.8 comment="Réseau VLAN10 IoT"
/ip dhcp-server network add address=192.168.20.0/24 gateway=192.168.20.1 dns-server=8.8.8.8 comment="Réseau VLAN20 SIEM"
/ip dhcp-server network add address=192.168.30.0/24 gateway=192.168.30.1 dns-server=8.8.8.8 comment="Réseau VLAN30 Management"

# -----------------------------------------------------------------------------
# Étape 9 : Firewall inter-VLAN
# Politique :
#   - IoT → SIEM : autorisé (logs de sécurité)
#   - IoT → Vault (port 8200) : autorisé (PKI)
#   - IoT → Internet : bloqué
#   - SIEM → IoT : bloqué (isolation)
#   - SIEM → tout : autorisé (monitoring)
#   - Management → tout : autorisé (admin)
#   - Défaut : refus
# -----------------------------------------------------------------------------

# --- Règles de la chaîne INPUT (vers le routeur lui-même) ---
/ip firewall filter add chain=input protocol=icmp action=accept \
    comment="Autoriser ICMP (ping)"
/ip firewall filter add chain=input connection-state=established,related action=accept \
    comment="Autoriser connexions établies"
/ip firewall filter add chain=input in-interface=vlan30-mgmt action=accept \
    comment="Autoriser Management vers routeur"
/ip firewall filter add chain=input action=drop log=yes log-prefix="FW-INPUT-DROP:" \
    comment="Bloquer tout le reste en INPUT"

# --- Règles de la chaîne FORWARD (transit inter-VLAN) ---
# Connexions établies / liées : toujours acceptées
/ip firewall filter add chain=forward connection-state=established,related action=accept \
    comment="Autoriser connexions établies en transit"

# IoT interne
/ip firewall filter add chain=forward \
    src-address=192.168.10.0/24 dst-address=192.168.10.0/24 \
    action=accept comment="IoT → IoT (trafic interne)"

# IoT → SIEM : autorisé (envoi de logs MQTT, syslog)
/ip firewall filter add chain=forward \
    src-address=192.168.10.0/24 dst-address=192.168.20.0/24 \
    action=accept comment="IoT → SIEM (logs autorisés)"

# IoT → Vault PKI uniquement (port 8200)
/ip firewall filter add chain=forward \
    src-address=192.168.10.0/24 dst-address=192.168.30.10 \
    protocol=tcp dst-port=8200 action=accept \
    comment="IoT → Vault PKI (port 8200)"

# IoT → Internet : bloqué
/ip firewall filter add chain=forward \
    src-address=192.168.10.0/24 out-interface=ether1 \
    action=drop log=yes log-prefix="FW-IOT-INTERNET-BLOCK:" \
    comment="Bloquer IoT → Internet"

# SIEM → IoT : bloqué (isolation réseau)
/ip firewall filter add chain=forward \
    src-address=192.168.20.0/24 dst-address=192.168.10.0/24 \
    action=drop log=yes log-prefix="FW-SIEM-IOT-BLOCK:" \
    comment="Bloquer SIEM → IoT (isolation)"

# SIEM → tout : autorisé (monitoring et analyse)
/ip firewall filter add chain=forward \
    src-address=192.168.20.0/24 action=accept \
    comment="SIEM → tout (monitoring)"

# Management → tout : autorisé (administration complète)
/ip firewall filter add chain=forward \
    src-address=192.168.30.0/24 action=accept \
    comment="Management → tout (admin)"

# Règle par défaut : refus
/ip firewall filter add chain=forward action=drop log=yes log-prefix="FW-FORWARD-DROP:" \
    comment="Refus par défaut (default deny)"

# --- NAT Masquerade vers pfSense ---
/ip firewall nat add chain=srcnat out-interface=ether1 action=masquerade \
    comment="NAT masquerade vers pfSense"

# -----------------------------------------------------------------------------
# Étape 10 : Port mirroring / SPAN pour Suricata
# ether5 = port miroir de ether2 (VLAN10) + ether3 (VLAN20)
# Suricata sur Docker-Host écoute sur ce port pour analyse IDS
# -----------------------------------------------------------------------------
/tool sniffer set filter-interface=ether5
/interface ethernet switch set switch1 mirror-source=ether2 mirror-target=ether5
# Note : sur CHR, utiliser packet-sniffer ou port-mirroring selon la version
# Commande alternative si switch ASIC non disponible :
# /interface ethernet switch port set [find name=ether2] mirror-egress=yes mirror-ingress=yes

# -----------------------------------------------------------------------------
# Étape 11 : NTP Client
# -----------------------------------------------------------------------------
/system ntp client set enabled=yes
/system ntp client servers add address=pool.ntp.org
/system ntp client servers add address=time.google.com

# -----------------------------------------------------------------------------
# Étape 12 : SSH et services - restriction au VLAN Management
# -----------------------------------------------------------------------------
/ip ssh set strong-crypto=yes

# Restreindre l'accès aux services au VLAN Management uniquement
/ip service set www      address=192.168.30.0/24 disabled=no
/ip service set www-ssl  address=192.168.30.0/24 disabled=no
/ip service set winbox   address=192.168.30.0/24 disabled=no
/ip service set ssh      address=192.168.30.0/24 disabled=no
/ip service set telnet   disabled=yes
/ip service set ftp      disabled=yes
/ip service set api      disabled=yes
/ip service set api-ssl  disabled=yes

# -----------------------------------------------------------------------------
# Étape 13 : Changement du mot de passe admin
# IMPORTANT : Changer ce mot de passe après le premier démarrage
# -----------------------------------------------------------------------------
/user set admin password="CHANGE_ME_IMMEDIATELY"
/user set admin comment="Administrateur principal - PFE IoT Security"

# -----------------------------------------------------------------------------
# Étape 14 : Logging distant vers Wazuh (syslog)
# -----------------------------------------------------------------------------
/system logging action add name=remote-wazuh target=remote \
    remote=192.168.20.10 remote-port=514 bsd-syslog=yes src-address=192.168.30.1
/system logging add topics=firewall   action=remote-wazuh
/system logging add topics=info       action=remote-wazuh
/system logging add topics=warning    action=remote-wazuh
/system logging add topics=error      action=remote-wazuh

# -----------------------------------------------------------------------------
# Fin de configuration
# Vérification : /import mikrotik-vlan-verification.rsc
# =============================================================================
:log info "Configuration MikroTik CHR Phase 1 appliquée avec succès"
