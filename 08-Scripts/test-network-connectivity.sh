#!/usr/bin/env bash
# =============================================================================
# Fichier     : test-network-connectivity.sh
# Description : Script de test de connectivité réseau - PFE IoT Security
#               Vérifie que tous les composants de l'infrastructure sont joignables
# Version     : 1.0
# Auteur      : PFE IoT Security Team
# Date        : 2026-03-03
# Usage       : bash test-network-connectivity.sh
#               (Exécuter depuis Docker-Host Ubuntu 22.04)
# =============================================================================

set -euo pipefail

# --- Couleurs ---
ROUGE='\033[0;31m'
VERT='\033[0;32m'
JAUNE='\033[1;33m'
BLEU='\033[0;34m'
CYAN='\033[0;36m'
GRIS='\033[0;37m'
RESET='\033[0m'
GRAS='\033[1m'

# --- Compteurs de résultats ---
TOTAL=0
PASS=0
FAIL=0

# --- Fonctions utilitaires ---
titre()   { echo -e "\n${CYAN}${GRAS}━━━ $* ━━━${RESET}"; }
info()    { echo -e "${GRIS}  $*${RESET}"; }
pass()    { echo -e "  ${VERT}[PASS]${RESET} $*"; ((PASS++)); ((TOTAL++)); }
fail()    { echo -e "  ${ROUGE}[FAIL]${RESET} $*"; ((FAIL++)); ((TOTAL++)); }
skip()    { echo -e "  ${JAUNE}[SKIP]${RESET} $*"; ((TOTAL++)); }

# Teste un ping vers une IP
test_ping() {
    local nom="$1"
    local ip="$2"
    local timeout="${3:-3}"

    if ping -c 1 -W "$timeout" "$ip" &>/dev/null 2>&1; then
        pass "Ping ${nom} (${ip})"
    else
        fail "Ping ${nom} (${ip}) - INJOIGNABLE"
    fi
}

# Teste si un port TCP est ouvert
test_port() {
    local nom="$1"
    local ip="$2"
    local port="$3"
    local timeout="${4:-5}"

    if nc -z -w "$timeout" "$ip" "$port" &>/dev/null 2>&1; then
        pass "Port ${nom} (${ip}:${port}/TCP)"
    else
        fail "Port ${nom} (${ip}:${port}/TCP) - FERMÉ ou INJOIGNABLE"
    fi
}

# Teste une URL HTTP(S)
test_http() {
    local nom="$1"
    local url="$2"
    local timeout="${3:-10}"

    local http_code
    http_code=$(curl -s -o /dev/null -w "%{http_code}" \
        --connect-timeout "$timeout" --max-time "$timeout" "$url" 2>/dev/null || echo "000")

    if [[ "$http_code" =~ ^[23] ]]; then
        pass "HTTP ${nom} (${url}) → HTTP ${http_code}"
    elif [[ "$http_code" == "000" ]]; then
        fail "HTTP ${nom} (${url}) → CONNEXION IMPOSSIBLE"
    else
        pass "HTTP ${nom} (${url}) → HTTP ${http_code} (service répond)"
    fi
}

# Teste si une interface réseau existe
test_interface() {
    local interface="$1"

    if ip link show "$interface" &>/dev/null 2>&1; then
        pass "Interface réseau ${interface} existe"
    else
        fail "Interface réseau ${interface} MANQUANTE"
    fi
}

# =============================================================================
# En-tête du rapport
# =============================================================================
echo ""
echo -e "${BLEU}${GRAS}╔══════════════════════════════════════════════════════════╗${RESET}"
echo -e "${BLEU}${GRAS}║     PFE IoT Security - Tests de Connectivité Réseau      ║${RESET}"
echo -e "${BLEU}${GRAS}╚══════════════════════════════════════════════════════════╝${RESET}"
echo -e "  Date     : $(date '+%Y-%m-%d %H:%M:%S')"
echo -e "  Hostname : $(hostname)"
echo ""

# =============================================================================
# 1. Vérification des interfaces VLAN locales
# =============================================================================
titre "1. Interfaces VLAN du Docker-Host"

test_interface "eth0"
test_interface "eth0.10"
test_interface "eth0.20"
test_interface "eth0.30"

# Afficher les IPs des interfaces VLAN
info "Adresses IP configurées :"
ip -4 addr show eth0.10 2>/dev/null | grep inet | awk '{print "    eth0.10 : " $2}' || info "    eth0.10 : non configurée"
ip -4 addr show eth0.20 2>/dev/null | grep inet | awk '{print "    eth0.20 : " $2}' || info "    eth0.20 : non configurée"
ip -4 addr show eth0.30 2>/dev/null | grep inet | awk '{print "    eth0.30 : " $2}' || info "    eth0.30 : non configurée"

# =============================================================================
# 2. Ping vers les gateways MikroTik
# =============================================================================
titre "2. Connectivité vers MikroTik (Gateways VLAN)"

test_ping "MikroTik Gateway VLAN10 IoT"  "192.168.10.1"
test_ping "MikroTik Gateway VLAN20 SIEM" "192.168.20.1"
test_ping "MikroTik Gateway VLAN30 Mgmt" "192.168.30.1"
test_ping "MikroTik Uplink"              "192.168.100.2"

# =============================================================================
# 3. Ping vers pfSense
# =============================================================================
titre "3. Connectivité vers pfSense"

test_ping "pfSense LAN" "192.168.100.1"

# =============================================================================
# 4. Ping inter-VLAN
# =============================================================================
titre "4. Tests inter-VLAN"

test_ping "Docker-Host VLAN10 → Wazuh VLAN20"       "192.168.20.10"
test_ping "Docker-Host VLAN10 → Vault VLAN30"        "192.168.30.10"
test_ping "Docker-Host VLAN20 → Mosquitto VLAN10"    "192.168.10.20"

# =============================================================================
# 5. Tests des services Docker - VLAN 10 (IoT)
# =============================================================================
titre "5. Services Docker - VLAN 10 (IoT)"

test_ping "Mosquitto MQTT"     "192.168.10.20"
test_port "MQTT (1883)"        "192.168.10.20" "1883"
test_port "MQTT WebSocket (9001)" "192.168.10.20" "9001"

test_ping "IoT Gateway"       "192.168.10.10"
test_ping "Sensor Temperature" "192.168.10.101"
test_ping "Sensor Humidity"    "192.168.10.102"
test_ping "Sensor Motion"      "192.168.10.103"

# =============================================================================
# 6. Tests des services Docker - VLAN 30 (Management)
# =============================================================================
titre "6. Services Docker - VLAN 30 (Management)"

test_ping "Vault PKI"          "192.168.30.10"
test_port "Vault API (8200)"   "192.168.30.10" "8200"
test_http "Vault UI"           "http://192.168.30.10:8200/ui"
test_http "Vault Health"       "http://192.168.30.10:8200/v1/sys/health"

# =============================================================================
# 7. Tests des services Wazuh - VLAN 20 (SIEM)
# =============================================================================
titre "7. Services Wazuh - VLAN 20 (SIEM)"

test_ping "Wazuh Manager"            "192.168.20.10"
test_port "Wazuh API (55000)"        "192.168.20.10" "55000"
test_port "Wazuh Agent (1514/TCP)"   "192.168.20.10" "1514"

# Test API Wazuh (HTTPS, certificat auto-signé ignoré)
if curl -s -k -o /dev/null -w "%{http_code}" \
    --connect-timeout 5 "https://192.168.20.10:55000" 2>/dev/null | grep -q "^[23]"; then
    pass "HTTP Wazuh API (https://192.168.20.10:55000)"
else
    skip "HTTP Wazuh API (https://192.168.20.10:55000) - vérifier manuellement"
fi

# =============================================================================
# 8. Test de connectivité internet (via pfSense)
# =============================================================================
titre "8. Connectivité Internet (via pfSense NAT)"

test_ping "DNS Google (8.8.8.8)"   "8.8.8.8"
test_ping "DNS Cloudflare (1.1.1.1)" "1.1.1.1"

# Test résolution DNS
if host google.com &>/dev/null 2>&1 || nslookup google.com &>/dev/null 2>&1; then
    pass "Résolution DNS (google.com)"
else
    fail "Résolution DNS (google.com)"
fi

# =============================================================================
# Rapport final
# =============================================================================
echo ""
echo -e "${BLEU}${GRAS}╔══════════════════════════════════════════════════════════╗${RESET}"
echo -e "${BLEU}${GRAS}║                    RAPPORT FINAL                         ║${RESET}"
echo -e "${BLEU}${GRAS}╚══════════════════════════════════════════════════════════╝${RESET}"
echo ""
echo -e "  Tests exécutés : ${GRAS}${TOTAL}${RESET}"
echo -e "  ${VERT}${GRAS}[PASS]${RESET} : ${VERT}${GRAS}${PASS}${RESET}"
echo -e "  ${ROUGE}${GRAS}[FAIL]${RESET} : ${ROUGE}${GRAS}${FAIL}${RESET}"
echo ""

if [[ $FAIL -eq 0 ]]; then
    echo -e "  ${VERT}${GRAS}✅ Tous les tests ont réussi ! Infrastructure opérationnelle.${RESET}"
    exit 0
elif [[ $FAIL -le 3 ]]; then
    echo -e "  ${JAUNE}${GRAS}⚠️  Quelques services injoignables. Vérifier les services concernés.${RESET}"
    exit 1
else
    echo -e "  ${ROUGE}${GRAS}❌ Plusieurs services injoignables. Vérifier l'infrastructure réseau.${RESET}"
    exit 2
fi
