# =============================================================================
# Fichier     : vault-config.hcl
# Description : Configuration HashiCorp Vault pour le PFE IoT Security
#               Mode production (non-dev), stockage fichier local
# Version     : 1.0
# Date        : 2026-03-09
# =============================================================================

ui = true

# Stockage des données Vault (persistant via volume Docker)
storage "file" {
  path = "/vault/data"
}

# Listener HTTP (TLS sera ajouté en Phase 3)
# AVERTISSEMENT : TLS désactivé — ne pas utiliser en production sans Phase 3 TLS
listener "tcp" {
  address     = "0.0.0.0:8200"
  tls_disable = 1
  # TODO Phase 3 : activer TLS
  # tls_cert_file = "/vault/certs/vault.crt"
  # tls_key_file  = "/vault/certs/vault.key"
  # tls_disable   = 0
}

# Adresse d'accès externe
api_addr = "http://192.168.30.10:8200"

# Désactiver le swap mémoire pour protéger les secrets
disable_mlock = false

# Logs
log_level = "info"
log_format = "json"

# TODO Phase future : CoAP/DTLS — ajouter rôle pki pour certs DTLS
