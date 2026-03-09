#!/usr/bin/env bash
# =============================================================================
# Fichier     : 03-vault-pki-setup.sh
# Description : Configuration de HashiCorp Vault PKI avec CA intermédiaire
#               PKI Option C - Étape 3/3 : Vault issuance engine
# Version     : 1.0
# Date        : 2026-03-09
# Usage       : bash 03-vault-pki-setup.sh
# Prérequis   : Vault démarré (docker compose up -d vault)
#               02-create-intermediate-ca.sh exécuté avec succès
#               VAULT_TOKEN exporté dans l'environnement
# =============================================================================
set -euo pipefail

VAULT_ADDR="${VAULT_ADDR:-http://192.168.30.10:8200}"
PKI_DIR="/opt/pfe-pki"
INT_CA_CRT="${PKI_DIR}/intermediate/intermediate-ca.crt"
INT_CA_KEY="${PKI_DIR}/intermediate/intermediate-ca.key"
INT_CA_CHAIN="${PKI_DIR}/intermediate/ca-chain.crt"

VERT='\033[0;32m'; ROUGE='\033[0;31m'; CYAN='\033[0;36m'; RESET='\033[0m'; GRAS='\033[1m'
info()   { echo -e "\033[0;34m[INFO]${RESET}  $*"; }
succes() { echo -e "${VERT}[OK]${RESET}    $*"; }
erreur() { echo -e "${ROUGE}[ERREUR]${RESET} $*"; exit 1; }
etape()  { echo -e "\n${CYAN}${GRAS}>>> $* <<<${RESET}\n"; }

[[ -z "${VAULT_TOKEN:-}" ]] && erreur "VAULT_TOKEN non défini. Exporter le token root Vault."
[[ ! -f "${INT_CA_CRT}" ]] && erreur "CA intermédiaire introuvable. Exécuter 02-create-intermediate-ca.sh d'abord."

export VAULT_ADDR

etape "Vérification de la connexion Vault"
vault status || erreur "Vault inaccessible à ${VAULT_ADDR}"

etape "Activation du moteur PKI Vault (path: pki_iot)"
vault secrets enable -path=pki_iot pki || info "Moteur PKI déjà activé"
vault secrets tune -max-lease-ttl=87600h pki_iot
succes "Moteur PKI activé sur path: pki_iot"

etape "Import de la CA intermédiaire dans Vault"
# Combiner clé + cert + chaîne pour l'import
# NOTE : la clé privée transite en mémoire uniquement ; ne pas laisser de fichier bundle
CA_BUNDLE=$(cat "${INT_CA_KEY}" "${INT_CA_CHAIN}")
vault write pki_iot/config/ca pem_bundle="${CA_BUNDLE}"
CA_BUNDLE=""   # effacer la variable pour limiter l'exposition de la clé privée
succes "CA intermédiaire importée dans Vault"

etape "Configuration de l'URL CRL et issuing"
vault write pki_iot/config/urls \
  issuing_certificates="${VAULT_ADDR}/v1/pki_iot/ca" \
  crl_distribution_points="${VAULT_ADDR}/v1/pki_iot/crl"
succes "URLs CRL configurées"

etape "Création du rôle Vault pour le broker MQTT (Mosquitto)"
vault write pki_iot/roles/mqtt-broker \
  allowed_domains="mqtt-broker,192.168.10.20,localhost" \
  allow_ip_sans=true \
  allow_localhost=true \
  allow_bare_domains=true \
  max_ttl="8760h" \
  ttl="8760h" \
  key_type="rsa" \
  key_bits=2048 \
  require_cn=false
succes "Rôle mqtt-broker créé"

etape "Création du rôle Vault pour les capteurs IoT (clients MQTT)"
vault write pki_iot/roles/iot-sensor \
  allowed_domains="sensor,iot-sensor,192.168.10.0/24" \
  allow_ip_sans=true \
  allow_subdomains=true \
  allow_bare_domains=true \
  max_ttl="2160h" \
  ttl="720h" \
  key_type="rsa" \
  key_bits=2048
succes "Rôle iot-sensor créé"

etape "Création du rôle Vault pour l'IoT Gateway"
vault write pki_iot/roles/iot-gateway \
  allowed_domains="iot-gateway,192.168.10.10" \
  allow_ip_sans=true \
  allow_bare_domains=true \
  max_ttl="8760h" \
  ttl="8760h" \
  key_type="rsa" \
  key_bits=2048
succes "Rôle iot-gateway créé"

etape "Création des policies Vault (AppRole)"
# Policy pour le broker Mosquitto
vault policy write mqtt-broker-policy - <<'POLICY'
path "pki_iot/issue/mqtt-broker" {
  capabilities = ["create", "update"]
}
path "pki_iot/ca" {
  capabilities = ["read"]
}
path "pki_iot/crl" {
  capabilities = ["read"]
}
POLICY

# Policy pour les capteurs IoT
vault policy write iot-sensor-policy - <<'POLICY'
path "pki_iot/issue/iot-sensor" {
  capabilities = ["create", "update"]
}
path "pki_iot/ca" {
  capabilities = ["read"]
}
path "pki_iot/crl" {
  capabilities = ["read"]
}
POLICY
succes "Policies Vault créées"

etape "Activation AppRole et création des rôles"
vault auth enable approle || info "AppRole déjà activé"

# AppRole pour Mosquitto
vault write auth/approle/role/mqtt-broker \
  token_policies="mqtt-broker-policy" \
  token_ttl=24h \
  token_max_ttl=48h

# AppRole pour les capteurs
vault write auth/approle/role/iot-sensor \
  token_policies="iot-sensor-policy" \
  token_ttl=1h \
  token_max_ttl=2h

succes "AppRoles créés"

etape "Émission du certificat test pour Mosquitto"
vault write pki_iot/issue/mqtt-broker \
  common_name="mqtt-broker" \
  ip_sans="192.168.10.20" \
  ttl="8760h" \
  | tee /tmp/mqtt-broker-cert-test.json
succes "Certificat test Mosquitto émis (voir /tmp/mqtt-broker-cert-test.json)"

echo ""
echo -e "${VERT}${GRAS}=====================================${RESET}"
echo -e "${VERT}${GRAS}  Vault PKI configuré avec succès !  ${RESET}"
echo -e "${VERT}${GRAS}=====================================${RESET}"
echo ""
echo "  Vault URL    : ${VAULT_ADDR}"
echo "  PKI path     : pki_iot"
echo "  Rôles        : mqtt-broker, iot-sensor, iot-gateway"
echo "  AppRoles     : mqtt-broker, iot-sensor"
echo ""
echo "Prochaine étape : bash 04-issue-mqtt-certs.sh"

# TODO Phase future : Ajouter rôle CoAP/DTLS (certificat avec EKU id-kp-clientAuth)
