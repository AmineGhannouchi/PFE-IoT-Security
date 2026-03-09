#!/usr/bin/env bash
# =============================================================================
# Fichier     : 01-create-root-ca.sh
# Description : Création de la CA racine PFE IoT Security avec OpenSSL
#               PKI Option C - Étape 1/3 : CA Racine (offline)
# Version     : 1.0
# Date        : 2026-03-09
# Usage       : sudo bash 01-create-root-ca.sh
# Résultat    : /opt/pfe-pki/ca/root-ca.crt + root-ca.key
# =============================================================================
set -euo pipefail

PKI_DIR="/opt/pfe-pki"
CA_DIR="${PKI_DIR}/ca"
ROOT_CA_SUBJ="/C=TN/ST=Tunis/L=Tunis/O=PFE-IoT-Security/OU=PKI/CN=PFE-Root-CA"
ROOT_CA_DAYS=3650   # 10 ans
ROOT_CA_KEY="${CA_DIR}/root-ca.key"
ROOT_CA_CRT="${CA_DIR}/root-ca.crt"
ROOT_CA_CSR="${CA_DIR}/root-ca.csr"

# Couleurs
VERT='\033[0;32m'; ROUGE='\033[0;31m'; CYAN='\033[0;36m'; RESET='\033[0m'; GRAS='\033[1m'
info()   { echo -e "\033[0;34m[INFO]${RESET}  $*"; }
succes() { echo -e "${VERT}[OK]${RESET}    $*"; }
erreur() { echo -e "${ROUGE}[ERREUR]${RESET} $*"; exit 1; }
etape()  { echo -e "\n${CYAN}${GRAS}>>> $* <<<${RESET}\n"; }

[[ $EUID -ne 0 ]] && erreur "Exécuter en root : sudo bash $0"

etape "Création de la structure PKI"
mkdir -p "${CA_DIR}"/{certs,crl,newcerts,private}
chmod 700 "${CA_DIR}/private"
touch "${CA_DIR}/index.txt"
echo 1000 > "${CA_DIR}/serial"
echo 1000 > "${CA_DIR}/crlnumber"

etape "Génération de la clé privée CA racine (RSA 4096)"
openssl genrsa -aes256 -out "${ROOT_CA_KEY}" 4096
chmod 400 "${ROOT_CA_KEY}"
succes "Clé privée générée : ${ROOT_CA_KEY}"

etape "Génération du certificat auto-signé CA racine"
openssl req -new -x509 \
  -key "${ROOT_CA_KEY}" \
  -out "${ROOT_CA_CRT}" \
  -days "${ROOT_CA_DAYS}" \
  -subj "${ROOT_CA_SUBJ}" \
  -extensions v3_ca \
  -config /etc/ssl/openssl.cnf
chmod 444 "${ROOT_CA_CRT}"

succes "CA Racine créée !"
echo ""
echo "  Clé  : ${ROOT_CA_KEY}"
echo "  Cert : ${ROOT_CA_CRT}"
echo ""
openssl x509 -noout -subject -issuer -dates -in "${ROOT_CA_CRT}"

# TODO Phase future : CoAP/DTLS — ajouter profil certificat DTLS dans cette CA
