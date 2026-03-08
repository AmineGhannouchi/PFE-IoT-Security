# =============================================================================
# Fichier     : vault-config.hcl
# Description : Configuration HashiCorp Vault - PFE IoT Security
#               Phase 2 : TLS activé, PKI secrets engine
# Version     : 2.0
# Auteur      : PFE IoT Security Team
# Date        : 2026-03-08
# =============================================================================

storage "file" {
  path = "/vault/data"
}

listener "tcp" {
  address       = "0.0.0.0:8200"
  tls_disable   = false

  tls_cert_file = "/vault/certs/vault.crt"
  tls_key_file  = "/vault/certs/vault.key"
  tls_ca_file   = "/vault/certs/ca.crt"

  # Pour revenir Phase 1 : tls_disable = true
}

api_addr     = "https://192.168.30.10:8200"
cluster_addr = "https://192.168.30.10:8201"

ui = true

log_level = "info"

# vault operator init
# vault operator unseal <clé 1-3>

default_lease_ttl = "168h"
max_lease_ttl     = "720h"