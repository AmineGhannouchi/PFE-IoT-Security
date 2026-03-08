#!/usr/bin/env bash
# =============================================================================
# Fichier     : setup-pki.sh
# Description : Script de bootstrap PKI via HashiCorp Vault - PFE IoT Security
#               Phase 2 : génération Root CA, rôles, et certificats TLS pour
#               Vault (HTTPS) et Mosquitto (mTLS port 8883)
# Version     : 1.0
# Auteur      : PFE IoT Security Team
# Date        : 2026-03-08
# Usage       : bash setup-pki.sh
# Prérequis   :
#   - Vault initialisé et descellé (vault operator init + unseal)
#   - export VAULT_ADDR=http://192.168.30.10:8200
#   - export VAULT_TOKEN=<root-token>
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

info()   { echo -e "${BLEU}[INFO]${RESET}  $*"; }
succes() { echo -e "${VERT}[OK]${RESET}    $*"; }
avert()  { echo -e "${JAUNE}[AVERT]${RESET} $*"; }
erreur() { echo -e "${ROUGE}[ERREUR]${RESET} $*"; exit 1; }
etape()  { echo -e "\n${CYAN}${GRAS}>>> $* <<<${RESET}\n"; }

# --- Configuration ---
VAULT_ADDR="${VAULT_ADDR:-http://192.168.30.10:8200}"
VAULT_TOKEN="${VAULT_TOKEN:-}"
CA_TTL="87600h"
CERT_TTL="8760h"
CERTS_DIR_MOSQUITTO="/opt/docker-host/mosquitto/certs"
CERTS_DIR_VAULT="/opt/docker-host/vault/certs"
MOSQUITTO_CN="mosquitto.iot.local"
VAULT_CN="vault.mgmt.local"

etape "Vérification des prérequis"
[[ -z "${VAULT_TOKEN}" ]] && erreur "Variable VAULT_TOKEN non définie."
command -v vault >/dev/null 2>&1 || erreur "vault CLI introuvable."
command -v jq    >/dev/null 2>&1 || erreur "jq introuvable (apt install jq)."
export VAULT_ADDR VAULT_TOKEN
vault status | grep -q "Sealed.*false" || erreur "Vault est scellé."
succes "Vault accessible et descellé"

etape "Étape 1/5 : Activation PKI secrets engine"
if vault secrets list | grep -q "^pki/"; then
    avert "PKI déjà activé, skip"
else
    vault secrets enable -path=pki -max-lease-ttl="${CA_TTL}" pki
    succes "PKI engine activé"
fi

etape "Étape 2/5 : Génération Root CA"
EXISTING_CA=$(vault read -field=certificate pki/cert/ca 2>/dev/null || echo "")
if [[ -n "${EXISTING_CA}" ]]; then
    avert "Root CA déjà existant, skip"
else
    vault write -field=certificate pki/root/generate/internal \
        common_name="PFE-IoT-Security Root CA" \
        issuer_name="pfe-iot-root-ca" \
        ttl="${CA_TTL}" \
        key_type="rsa" \
        key_bits=4096 > /tmp/pfe-root-ca.crt
    succes "Root CA généré"
fi
vault write pki/config/urls \
    issuing_certificates="${VAULT_ADDR}/v1/pki/ca" \
    crl_distribution_points="${VAULT_ADDR}/v1/pki/crl"
succes "URLs PKI configurées"

etape "Étape 3/5 : Création des rôles PKI"
vault write pki/roles/iot-services \
    allowed_domains="iot.local" allow_subdomains=true \
    allow_ip_sans=true max_ttl="${CERT_TTL}" key_type="rsa" key_bits=2048
succes "Rôle iot-services créé"

vault write pki/roles/vault-server \
    allowed_domains="mgmt.local" allow_subdomains=true \
    allow_ip_sans=true max_ttl="${CERT_TTL}" key_type="rsa" key_bits=2048
succes "Rôle vault-server créé"

etape "Étape 4/5 : Certificat Mosquitto (mTLS)"
mkdir -p "${CERTS_DIR_MOSQUITTO}"
MOSQ_CERT_JSON=$(vault write -format=json pki/issue/iot-services \
    common_name="${MOSQUITTO_CN}" alt_names="${MOSQUITTO_CN}" \
    ip_sans="192.168.10.10" ttl="${CERT_TTL}")
echo "${MOSQ_CERT_JSON}" | jq -r '.data.certificate' > "${CERTS_DIR_MOSQUITTO}/server.crt"
echo "${MOSQ_CERT_JSON}" | jq -r '.data.private_key' > "${CERTS_DIR_MOSQUITTO}/server.key"
echo "${MOSQ_CERT_JSON}" | jq -r '.data.issuing_ca'  > "${CERTS_DIR_MOSQUITTO}/ca.crt"
chmod 600 "${CERTS_DIR_MOSQUITTO}/server.key"
chown -R 1883:1883 "${CERTS_DIR_MOSQUITTO}" 2>/dev/null || avert "chown ignoré (docker gérera)"
succes "Certificat Mosquitto émis dans ${CERTS_DIR_MOSQUITTO}"

etape "Étape 5/5 : Certificat Vault (HTTPS)"
mkdir -p "${CERTS_DIR_VAULT}"
VAULT_CERT_JSON=$(vault write -format=json pki/issue/vault-server \
    common_name="${VAULT_CN}" alt_names="${VAULT_CN}" \
    ip_sans="192.168.30.10" ttl="${CERT_TTL}")
echo "${VAULT_CERT_JSON}" | jq -r '.data.certificate' > "${CERTS_DIR_VAULT}/vault.crt"
echo "${VAULT_CERT_JSON}" | jq -r '.data.private_key' > "${CERTS_DIR_VAULT}/vault.key"
echo "${VAULT_CERT_JSON}" | jq -r '.data.issuing_ca'  > "${CERTS_DIR_VAULT}/ca.crt"
chmod 600 "${CERTS_DIR_VAULT}/vault.key"
succes "Certificat Vault émis dans ${CERTS_DIR_VAULT}"

echo ""
echo -e "\033[0;32m\033[1m=== PKI Bootstrap Phase 2 terminé ===\033[0m"
echo "Certificats Mosquitto : ${CERTS_DIR_MOSQUITTO}"
echo "Certificats Vault     : ${CERTS_DIR_VAULT}"
echo ""
echo "Prochaines étapes :"
echo "  1. docker compose restart vault mosquitto"
echo "  2. Vérifier TLS : vault status (HTTPS), mosquitto_sub --cafile ca.crt -p 8883"
echo "IMPORTANT : Conservez les clés unseal et le root token en lieu sûr !"