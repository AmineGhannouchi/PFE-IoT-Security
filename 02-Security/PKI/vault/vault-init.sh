#!/usr/bin/env bash
# =============================================================================
# Fichier     : vault-init.sh
# Description : Initialisation et unseal de HashiCorp Vault
#               À exécuter UNE SEULE FOIS après le premier démarrage
# Version     : 1.0
# Date        : 2026-03-09
# Usage       : bash vault-init.sh
# IMPORTANT   : Sauvegarder les clés unseal et le root token en lieu sûr !
# =============================================================================
set -euo pipefail

VAULT_ADDR="${VAULT_ADDR:-http://192.168.30.10:8200}"
INIT_FILE="/opt/pfe-pki/vault-init.json"

VERT='\033[0;32m'; ROUGE='\033[0;31m'; CYAN='\033[0;36m'; JAUNE='\033[1;33m'; RESET='\033[0m'; GRAS='\033[1m'
info()   { echo -e "\033[0;34m[INFO]${RESET}  $*"; }
succes() { echo -e "${VERT}[OK]${RESET}    $*"; }
erreur() { echo -e "${ROUGE}[ERREUR]${RESET} $*"; exit 1; }
etape()  { echo -e "\n${CYAN}${GRAS}>>> $* <<<${RESET}\n"; }
avert()  { echo -e "${JAUNE}[AVERT]${RESET} $*"; }

export VAULT_ADDR

etape "Vérification statut Vault"
vault status 2>/dev/null | head -5 || true

# Vérifier si déjà initialisé
if vault status 2>/dev/null | grep -q "Initialized.*true"; then
  avert "Vault déjà initialisé."
  if vault status 2>/dev/null | grep -q "Sealed.*true"; then
    etape "Vault scellé — Unseal requis"
    info "Entrer les clés unseal (3 clés sur 5 requises) :"
    for i in 1 2 3; do
      read -rsp "Clé unseal ${i}/3 : " unseal_key
      echo ""
      vault operator unseal "${unseal_key}"
    done
    succes "Vault descellé !"
  else
    succes "Vault déjà descellé et opérationnel."
  fi
  exit 0
fi

etape "Initialisation de Vault (5 clés, seuil 3)"
mkdir -p /opt/pfe-pki
vault operator init \
  -key-shares=5 \
  -key-threshold=3 \
  -format=json > "${INIT_FILE}"
chmod 600 "${INIT_FILE}"
# SECURITE : Ce fichier contient les clés unseal et le root token en clair.
# Pour un environnement de production, chiffrer ce fichier (ex: gpg --symmetric)
# et le stocker hors de la VM (coffre-fort, HSM ou gestionnaire de secrets).
succes "Vault initialisé. Clés sauvegardées dans ${INIT_FILE}"

etape "Unseal automatique avec les 3 premières clés"
for i in 0 1 2; do
  UNSEAL_KEY=$(jq -r ".unseal_keys_b64[${i}]" "${INIT_FILE}")
  vault operator unseal "${UNSEAL_KEY}"
done
succes "Vault descellé !"

ROOT_TOKEN=$(jq -r ".root_token" "${INIT_FILE}")

etape "Test d'authentification avec root token"
vault login "${ROOT_TOKEN}"
succes "Authentification réussie"

echo ""
echo -e "${JAUNE}${GRAS}╔══════════════════════════════════════════════════════╗${RESET}"
echo -e "${JAUNE}${GRAS}║  ⚠️  SAUVEGARDER CES INFORMATIONS EN LIEU SÛR !    ║${RESET}"
echo -e "${JAUNE}${GRAS}╚══════════════════════════════════════════════════════╝${RESET}"
echo ""
echo "Root Token   : ${ROOT_TOKEN}"
echo "Clés unseal  : voir ${INIT_FILE}"
echo ""
echo "Prochaine étape :"
echo "  export VAULT_TOKEN=${ROOT_TOKEN}"
echo "  bash 03-vault-pki-setup.sh"
