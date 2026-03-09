#!/usr/bin/env bash
# =============================================================================
# Fichier     : 02-create-intermediate-ca.sh
# Description : Création de la CA intermédiaire signée par la CA racine OpenSSL
#               PKI Option C - Étape 2/3 : CA intermédiaire (sera importée dans Vault)
# Version     : 1.0
# Date        : 2026-03-09
# Usage       : sudo bash 02-create-intermediate-ca.sh
# Prérequis   : 01-create-root-ca.sh exécuté avec succès
# =============================================================================
set -euo pipefail

PKI_DIR="/opt/pfe-pki"
CA_DIR="${PKI_DIR}/ca"
INT_DIR="${PKI_DIR}/intermediate"
ROOT_CA_KEY="${CA_DIR}/root-ca.key"
ROOT_CA_CRT="${CA_DIR}/root-ca.crt"
INT_CA_KEY="${INT_DIR}/intermediate-ca.key"
INT_CA_CSR="${INT_DIR}/intermediate-ca.csr"
INT_CA_CRT="${INT_DIR}/intermediate-ca.crt"
INT_CA_CHAIN="${INT_DIR}/ca-chain.crt"
INT_SUBJ="/C=TN/ST=Tunis/L=Tunis/O=PFE-IoT-Security/OU=PKI-Intermediate/CN=PFE-Intermediate-CA"
INT_CA_DAYS=1825   # 5 ans

VERT='\033[0;32m'; ROUGE='\033[0;31m'; CYAN='\033[0;36m'; RESET='\033[0m'; GRAS='\033[1m'
info()   { echo -e "\033[0;34m[INFO]${RESET}  $*"; }
succes() { echo -e "${VERT}[OK]${RESET}    $*"; }
erreur() { echo -e "${ROUGE}[ERREUR]${RESET} $*"; exit 1; }
etape()  { echo -e "\n${CYAN}${GRAS}>>> $* <<<${RESET}\n"; }

[[ $EUID -ne 0 ]] && erreur "Exécuter en root : sudo bash $0"
[[ ! -f "${ROOT_CA_CRT}" ]] && erreur "CA racine introuvable. Exécuter 01-create-root-ca.sh d'abord."

etape "Création de la structure CA intermédiaire"
mkdir -p "${INT_DIR}"/{certs,crl,newcerts,private,csr}
chmod 700 "${INT_DIR}/private"
touch "${INT_DIR}/index.txt"
echo 2000 > "${INT_DIR}/serial"
echo 2000 > "${INT_DIR}/crlnumber"

etape "Génération clé privée CA intermédiaire (RSA 4096)"
openssl genrsa -aes256 -out "${INT_CA_KEY}" 4096
chmod 400 "${INT_CA_KEY}"
succes "Clé privée intermédiaire : ${INT_CA_KEY}"

etape "Génération CSR CA intermédiaire"
openssl req -new \
  -key "${INT_CA_KEY}" \
  -out "${INT_CA_CSR}" \
  -subj "${INT_SUBJ}"
succes "CSR générée : ${INT_CA_CSR}"

etape "Signature de la CA intermédiaire par la CA racine"
openssl x509 -req \
  -in "${INT_CA_CSR}" \
  -CA "${ROOT_CA_CRT}" \
  -CAkey "${ROOT_CA_KEY}" \
  -CAcreateserial \
  -out "${INT_CA_CRT}" \
  -days "${INT_CA_DAYS}" \
  -extensions v3_intermediate_ca \
  -extfile <(cat <<EOF
[v3_intermediate_ca]
subjectKeyIdentifier = hash
authorityKeyIdentifier = keyid:always,issuer
basicConstraints = critical, CA:true, pathlen:0
keyUsage = critical, digitalSignature, cRLSign, keyCertSign
EOF
)
chmod 444 "${INT_CA_CRT}"

etape "Création de la chaîne de certification (chain)"
cat "${INT_CA_CRT}" "${ROOT_CA_CRT}" > "${INT_CA_CHAIN}"
chmod 444 "${INT_CA_CHAIN}"

succes "CA Intermédiaire créée et signée !"
echo ""
echo "  Clé         : ${INT_CA_KEY}"
echo "  Certificat  : ${INT_CA_CRT}"
echo "  Chaîne      : ${INT_CA_CHAIN}"
echo ""
openssl x509 -noout -subject -issuer -dates -in "${INT_CA_CRT}"
echo ""
echo "Vérification de la chaîne :"
openssl verify -CAfile "${ROOT_CA_CRT}" "${INT_CA_CRT}"
