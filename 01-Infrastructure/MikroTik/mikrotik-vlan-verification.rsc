# =============================================================================
# Fichier     : mikrotik-vlan-verification.rsc
# Description : Script de vérification de la configuration VLAN MikroTik CHR
#               Phase 1 du PFE IoT Security
# Version     : 1.0
# Auteur      : PFE IoT Security Team
# Date        : 2026-03-03
# Usage       : /import mikrotik-vlan-verification.rsc
# =============================================================================

:log info "=== Début vérification configuration MikroTik CHR ==="

# -----------------------------------------------------------------------------
# 1. Vérification des interfaces VLAN
# -----------------------------------------------------------------------------
:log info "--- Interfaces VLAN ---"
/interface vlan print
:put "--- Interfaces VLAN (print) ---"
/interface vlan print

# -----------------------------------------------------------------------------
# 2. Vérification des adresses IP
# -----------------------------------------------------------------------------
:log info "--- Adresses IP ---"
:put "--- Adresses IP ---"
/ip address print

# -----------------------------------------------------------------------------
# 3. Vérification des routes
# -----------------------------------------------------------------------------
:log info "--- Table de routage ---"
:put "--- Table de routage ---"
/ip route print

# -----------------------------------------------------------------------------
# 4. Vérification des règles firewall
# -----------------------------------------------------------------------------
:log info "--- Règles Firewall Filter ---"
:put "--- Règles Firewall Filter ---"
/ip firewall filter print

:log info "--- Règles Firewall NAT ---"
:put "--- Règles Firewall NAT ---"
/ip firewall nat print

# -----------------------------------------------------------------------------
# 5. Vérification DHCP
# -----------------------------------------------------------------------------
:log info "--- Serveurs DHCP ---"
:put "--- Serveurs DHCP ---"
/ip dhcp-server print

:put "--- Baux DHCP actifs ---"
/ip dhcp-server lease print

# -----------------------------------------------------------------------------
# 6. Vérification du NTP
# -----------------------------------------------------------------------------
:put "--- Client NTP ---"
/system ntp client print

# -----------------------------------------------------------------------------
# 7. Vérification des services
# -----------------------------------------------------------------------------
:put "--- Services IP ---"
/ip service print

# -----------------------------------------------------------------------------
# 8. Tests de connectivité inter-VLAN (ping)
# -----------------------------------------------------------------------------
:log info "--- Tests de connectivité inter-VLAN ---"
:put ""
:put "=== Tests de connectivité inter-VLAN ==="

# Ping vers pfSense
:put "Ping pfSense (192.168.100.1)..."
/ping 192.168.100.1 count=3

# Ping vers Docker-Host VLAN10
:put "Ping Docker-Host VLAN10 (192.168.10.100)..."
/ping 192.168.10.100 count=3

# Ping vers Wazuh VLAN20
:put "Ping Wazuh VLAN20 (192.168.20.10)..."
/ping 192.168.20.10 count=3

# Ping vers Vault VLAN30
:put "Ping Vault VLAN30 (192.168.30.10)..."
/ping 192.168.30.10 count=3

# Ping vers Internet (via pfSense)
:put "Ping Internet (8.8.8.8)..."
/ping 8.8.8.8 count=3

# -----------------------------------------------------------------------------
# 9. Vérification du port SPAN/Mirror
# -----------------------------------------------------------------------------
:put ""
:put "--- Configuration port Mirror/SPAN ---"
/interface ethernet switch print
/tool sniffer print

# -----------------------------------------------------------------------------
# 10. Résumé système
# -----------------------------------------------------------------------------
:put ""
:put "=== Informations système ==="
/system identity print
/system resource print
/system clock print

:log info "=== Fin vérification configuration MikroTik CHR ==="
:put ""
:put "=== Vérification terminée. Consultez les logs : /log print ==="
