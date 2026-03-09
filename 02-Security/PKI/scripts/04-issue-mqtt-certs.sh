#!/usr/bin/env bash
# =============================================================================
# Fichier     : 04-issue-mqtt-certs.sh
# Description : Émission des certificats mTLS pour MQTT depuis Vault PKI
#               PKI Option C - Déploiement des certificats
# Version     : 1.0
# Date        : 2026-03-09
# Usage       : bash 04-issue-mqtt-certs.sh
# Prérequis   : 03-vault-pki-setup.sh exécuté avec succès
# =============================================================================
set -euo pipefail

VAULT_ADDR="${VAULT_ADDR:-http://192.168.30.10:8200}"
CERTS_DIR="/opt/pfe-pki/certs"
DOCKER_DIR="/opt/docker-host"
PKI_DIR="/opt/pfe-pki"

VERT='\033[0;32m'; ROUGE='\033[0;31m'; CYAN='\033[0;36m'; RESET='\033[0m'; GRAS='\033[1m'
info()   { echo -e "\033[0;34m[INFO]${RESET}  $*"; }
succes() { echo -e "${VERT}[OK]${RESET}    $*"; }
erreur() { echo -e "${ROUGE}[ERREUR]${RESET} $*"; exit 1; }
etape()  { echo -e "\n${CYAN}${GRAS}>>> $* <<<${RESET}\n"; }

[[ -z "${VAULT_TOKEN:-}" ]] && erreur "VAULT_TOKEN non défini."
export VAULT_ADDR

_issue_cert() {
  local role="$1" cn="$2" ip_sans="$3" out_dir="$4"
  mkdir -p "${out_dir}"
  local result
  result=$(vault write -format=json "pki_iot/issue/${role}" \
    common_name="${cn}" ip_sans="${ip_sans}" ttl="8760h")
  echo "${result}" | jq -r '.data.certificate'       > "${out_dir}/${cn}.crt"
  echo "${result}" | jq -r '.data.private_key'       > "${out_dir}/${cn}.key"
  echo "${result}" | jq -r '.data.issuing_ca'        > "${out_dir}/ca.crt"
  echo "${result}" | jq -r '.data.ca_chain[]'        > "${out_dir}/ca-chain.crt" 2>/dev/null || true
  chmod 600 "${out_dir}/${cn}.key"
  chmod 644 "${out_dir}/${cn}.crt" "${out_dir}/ca.crt"
  # Restreindre la propriété au propriétaire du répertoire de destination
  chown "$(stat -c '%U:%G' "${out_dir}")" "${out_dir}/${cn}.key" "${out_dir}/${cn}.crt" "${out_dir}/ca.crt" 2>/dev/null || true
  succes "Certificat émis : ${out_dir}/${cn}.crt"
}

etape "Émission cert Mosquitto broker (serveur TLS)"
_issue_cert "mqtt-broker" "mqtt-broker" "192.168.10.20" \
  "${CERTS_DIR}/mosquitto"

etape "Émission cert IoT Gateway (client mTLS)"
_issue_cert "iot-gateway" "iot-gateway" "192.168.10.10" \
  "${CERTS_DIR}/iot-gateway"

etape "Émission cert sensor-temp (client mTLS)"
_issue_cert "iot-sensor" "sensor-temp" "192.168.10.101" \
  "${CERTS_DIR}/sensor-temp"

etape "Émission cert sensor-humid (client mTLS)"
_issue_cert "iot-sensor" "sensor-humid" "192.168.10.102" \
  "${CERTS_DIR}/sensor-humid"

etape "Émission cert sensor-motion (client mTLS)"
_issue_cert "iot-sensor" "sensor-motion" "192.168.10.103" \
  "${CERTS_DIR}/sensor-motion"

etape "Copie des certificats vers le répertoire Docker"
# CA pour validation côté clients
cp "${PKI_DIR}/ca/root-ca.crt" "${DOCKER_DIR}/mosquitto/certs/ca.crt" 2>/dev/null || \
  cp "${CERTS_DIR}/mosquitto/ca.crt" "${DOCKER_DIR}/mosquitto/certs/ca.crt"

# Mosquitto broker
mkdir -p "${DOCKER_DIR}/mosquitto/certs"
cp "${CERTS_DIR}/mosquitto/mqtt-broker.crt" "${DOCKER_DIR}/mosquitto/certs/server.crt"
cp "${CERTS_DIR}/mosquitto/mqtt-broker.key" "${DOCKER_DIR}/mosquitto/certs/server.key"

# Capteurs + Gateway
for service in iot-gateway sensor-temp sensor-humid sensor-motion; do
  mkdir -p "${DOCKER_DIR}/sensors/certs/${service}"
  cp "${CERTS_DIR}/${service}/"*.crt "${DOCKER_DIR}/sensors/certs/${service}/" 2>/dev/null || true
  cp "${CERTS_DIR}/${service}/"*.key "${DOCKER_DIR}/sensors/certs/${service}/" 2>/dev/null || true
done

succes "Certificats déployés !"
echo ""
echo "Certificats disponibles dans :"
echo "  Broker   : ${DOCKER_DIR}/mosquitto/certs/"
echo "  Capteurs : ${DOCKER_DIR}/sensors/certs/"
echo ""
echo "Prochaine étape : Phase 3 — Activer mTLS dans mosquitto.conf"
