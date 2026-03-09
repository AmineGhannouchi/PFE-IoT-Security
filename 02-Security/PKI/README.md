# PKI PFE IoT Security — Option C (OpenSSL CA + Vault PKI)

**Fichier**     : README.md  
**Description** : Documentation de l'infrastructure PKI du PFE IoT Security  
**Version**     : 1.0  
**Date**        : 2026-03-09  

## Architecture PKI Option C

```
[CA Racine OpenSSL] (offline, /opt/pfe-pki/ca/)
       │  signe
       ▼
[CA Intermédiaire OpenSSL] ──import──► [HashiCorp Vault PKI]
                                               │  émet
                              ┌────────────────┼──────────────────┐
                              ▼                ▼                   ▼
                    [Mosquitto TLS]    [IoT Gateway mTLS]  [Capteurs mTLS]
                    192.168.10.20      192.168.10.10        .101/.102/.103
```

## Ordre d'exécution

```bash
# Étape 1 — CA Racine (une seule fois, offline)
cd 02-Security/PKI/scripts
sudo bash 01-create-root-ca.sh

# Étape 2 — CA Intermédiaire (une seule fois)
sudo bash 02-create-intermediate-ca.sh

# Étape 3 — Démarrer Vault
cd /opt/docker-host
docker compose up -d vault
docker compose logs vault  # attendre "Core initialized"

# Étape 4 — Initialiser Vault
bash /opt/PFE-IoT-Security/02-Security/PKI/vault/vault-init.sh
export VAULT_TOKEN=<root_token_affiché>

# Étape 5 — Configurer Vault PKI
bash /opt/PFE-IoT-Security/02-Security/PKI/scripts/03-vault-pki-setup.sh

# Étape 6 — Émettre les certificats MQTT mTLS
bash /opt/PFE-IoT-Security/02-Security/PKI/scripts/04-issue-mqtt-certs.sh
```

## Structure des fichiers

```
02-Security/PKI/
├── scripts/
│   ├── 01-create-root-ca.sh          # CA Racine OpenSSL (offline)
│   ├── 02-create-intermediate-ca.sh  # CA Intermédiaire OpenSSL
│   ├── 03-vault-pki-setup.sh         # Configuration Vault PKI
│   └── 04-issue-mqtt-certs.sh        # Émission certificats MQTT mTLS
└── vault/
    ├── vault-config.hcl              # Configuration Vault production
    └── vault-init.sh                 # Initialisation et unseal Vault
```

## Répertoires générés sur la VM

```
/opt/pfe-pki/
├── ca/
│   ├── root-ca.key        # Clé privée CA racine (protégée AES-256)
│   ├── root-ca.crt        # Certificat CA racine (10 ans)
│   ├── serial
│   ├── index.txt
│   └── private/
├── intermediate/
│   ├── intermediate-ca.key  # Clé privée CA intermédiaire
│   ├── intermediate-ca.crt  # Certificat CA intermédiaire (5 ans)
│   ├── ca-chain.crt         # Chaîne complète (intermediate + root)
│   └── private/
└── certs/
    ├── mosquitto/           # Cert broker MQTT
    ├── iot-gateway/         # Cert IoT Gateway
    ├── sensor-temp/         # Cert capteur température
    ├── sensor-humid/        # Cert capteur humidité
    └── sensor-motion/       # Cert capteur mouvement
```

## Rôles Vault PKI

| Rôle         | Domaines autorisés                    | TTL max | Usage              |
|--------------|---------------------------------------|---------|--------------------|
| mqtt-broker  | mqtt-broker, 192.168.10.20, localhost | 8760h   | Serveur TLS MQTT   |
| iot-sensor   | sensor, iot-sensor, 192.168.10.0/24  | 2160h   | Clients mTLS       |
| iot-gateway  | iot-gateway, 192.168.10.10            | 8760h   | Gateway mTLS       |

## AppRoles Vault

| AppRole     | Policy              | Token TTL |
|-------------|---------------------|-----------|
| mqtt-broker | mqtt-broker-policy  | 24h       |
| iot-sensor  | iot-sensor-policy   | 1h        |

## Infrastructure

- **Vault URL** : http://192.168.30.10:8200
- **PKI mount** : `pki_iot`
- **Mosquitto** : 192.168.10.20:8883 (TLS/mTLS)
- **IoT Gateway** : 192.168.10.10
- **Capteurs** : 192.168.10.101-103

## Prochaine étape (Phase 3)

Activer mTLS dans `mosquitto.conf` et déployer les certificats sur les conteneurs Docker.
