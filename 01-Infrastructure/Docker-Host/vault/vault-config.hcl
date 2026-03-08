# =============================================================================
# Fichier     : vault-config.hcl
# Description : Configuration HashiCorp Vault - PFE IoT Security
#               Phase 2 : TLS activé, PKI secrets engine
# Version     : 2.0
# Auteur      : PFE IoT Security Team
# Date        : 2026-03-08
# =============================================================================

# -----------------------------------------------------------------------------
# Backend de stockage
# Utilise le système de fichiers local (adapté Phase 1/2)
# En production, préférer Consul ou integrated Raft storage
# -----------------------------------------------------------------------------
storage "file" {
  path = "/vault/data"
}

# -----------------------------------------------------------------------------
# Interface d'écoute TCP
# TLS activé en Phase 2 avec certificats PKI générés par Vault
# -----------------------------------------------------------------------------
listener "tcp" {
  address       = "0.0.0.0:8200"
  tls_disable   = false

  # Certificats TLS générés par Vault PKI (Phase 2)
  tls_cert_file = "/vault/certs/vault.crt"
  tls_key_file  = "/vault/certs/vault.key"
  tls_ca_file   = "/vault/certs/ca.crt"

  # Pour revenir en Phase 1 (tests) :
  # tls_disable = true
}

# -----------------------------------------------------------------------------
# Adresses de l'API Vault (utilisées pour les redirections et le clustering)
# -----------------------------------------------------------------------------
api_addr     = "https://192.168.30.10:8200"
cluster_addr = "https://192.168.30.10:8201"

# -----------------------------------------------------------------------------
# Interface utilisateur Web (Vault UI)
# Accessible sur https://192.168.30.10:8200/ui
# -----------------------------------------------------------------------------
ui = true

# -----------------------------------------------------------------------------
# Niveau de logging
# Valeurs possibles : trace, debug, info, warn, error
# -----------------------------------------------------------------------------
log_level = "info"

# -----------------------------------------------------------------------------
# Désactiver le mode développement (Vault démarre en mode production)
# IMPORTANT : En mode production, Vault démarre scellé (sealed)
# Il faudra l'initialiser et le déverrouiller au premier démarrage :
#   vault operator init
#   vault operator unseal <clé 1>
#   vault operator unseal <clé 2>
#   vault operator unseal <clé 3>
# Conserver les clés de déverrouillage et le root token en lieu sûr !
# -----------------------------------------------------------------------------

# -----------------------------------------------------------------------------
# Paramètres de performance et sécurité
# -----------------------------------------------------------------------------
default_lease_ttl = "168h"    # Durée de vie par défaut des secrets (1 semaine)
max_lease_ttl     = "720h"    # Durée de vie maximale des secrets (30 jours)
