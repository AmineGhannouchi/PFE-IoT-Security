#!/usr/bin/env python3
# =============================================================================
# Fichier     : gateway.py
# Description : IoT Gateway - PFE IoT Security
#               Souscrit à tous les capteurs MQTT et retransmet avec enrichissement
# Version     : 1.0
# Auteur      : PFE IoT Security Team
# Date        : 2026-03-03
# =============================================================================

import os
import time
import json
import logging
import signal
import sys
import paho.mqtt.client as mqtt

# -----------------------------------------------------------------------------
# Configuration du logging structuré
# -----------------------------------------------------------------------------
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s [%(levelname)s] %(name)s: %(message)s',
    datefmt='%Y-%m-%dT%H:%M:%S'
)
logger = logging.getLogger("IoTGateway")

# -----------------------------------------------------------------------------
# Variables d'environnement
# -----------------------------------------------------------------------------
MQTT_BROKER  = os.getenv("MQTT_BROKER", "192.168.10.20")
MQTT_PORT    = int(os.getenv("MQTT_PORT", "1883"))
GATEWAY_ID   = os.getenv("GATEWAY_ID", "gw-001")
SUBSCRIBE_TOPIC = "iot/sensors/#"   # Souscription à tous les capteurs
PUBLISH_PREFIX  = "iot/gateway"     # Préfixe pour les messages retransmis

# Drapeau pour arrêt propre
running = True


def signal_handler(sig, frame):
    """Gestionnaire de signal pour arrêt propre."""
    global running
    logger.info(f"[{GATEWAY_ID}] Signal reçu ({sig}), arrêt en cours...")
    running = False


def enrich_payload(original_payload: str, received_at: str) -> str:
    """
    Enrichit le payload du capteur avec des métadonnées de la gateway.

    Args:
        original_payload: Payload JSON original du capteur.
        received_at: Horodatage de réception par la gateway.

    Retourne:
        str: Payload JSON enrichi.
    """
    try:
        data = json.loads(original_payload)
    except json.JSONDecodeError as e:
        logger.warning(f"[{GATEWAY_ID}] Payload JSON invalide : {e}")
        data = {"raw": original_payload}

    # Ajout des métadonnées de la gateway
    data["gateway_id"]   = GATEWAY_ID
    data["received_at"]  = received_at
    data["forwarded"]    = True

    return json.dumps(data, ensure_ascii=False)


def on_connect(client, userdata, flags, rc):
    """Callback connexion MQTT."""
    if rc == 0:
        logger.info(f"[{GATEWAY_ID}] Connecté au broker MQTT {MQTT_BROKER}:{MQTT_PORT}")
        # Souscription au topic des capteurs après connexion réussie
        client.subscribe(SUBSCRIBE_TOPIC, qos=1)
        logger.info(f"[{GATEWAY_ID}] Souscrit au topic : {SUBSCRIBE_TOPIC}")
    else:
        codes = {
            1: "Protocole incorrect",
            2: "Client ID refusé",
            3: "Serveur indisponible",
            4: "Identifiants incorrects",
            5: "Non autorisé",
        }
        logger.error(f"[{GATEWAY_ID}] Connexion échouée : {codes.get(rc, f'code={rc}')}")


def on_disconnect(client, userdata, rc):
    """Callback déconnexion MQTT."""
    if rc != 0:
        logger.warning(f"[{GATEWAY_ID}] Déconnexion inattendue (rc={rc}), reconnexion auto...")
    else:
        logger.info(f"[{GATEWAY_ID}] Déconnecté proprement")


def on_message(client, userdata, msg):
    """
    Callback réception d'un message capteur.
    Enrichit le payload et le retransmet sur le topic gateway.
    """
    received_at = time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime())

    # Topic de publication : iot/gateway/{topic_original}
    publish_topic = f"{PUBLISH_PREFIX}/{msg.topic}"

    logger.debug(f"[{GATEWAY_ID}] Reçu sur {msg.topic} : {msg.payload.decode('utf-8', errors='replace')}")

    # Enrichissement du payload
    enriched = enrich_payload(msg.payload.decode("utf-8", errors="replace"), received_at)

    # Retransmission sur le topic gateway
    result = client.publish(publish_topic, enriched, qos=1)

    if result.rc == mqtt.MQTT_ERR_SUCCESS:
        logger.info(f"[{GATEWAY_ID}] Retransmis : {msg.topic} → {publish_topic}")
    else:
        logger.warning(f"[{GATEWAY_ID}] Échec retransmission (rc={result.rc})")


def on_subscribe(client, userdata, mid, granted_qos):
    """Callback souscription réussie."""
    logger.info(f"[{GATEWAY_ID}] Souscription confirmée (mid={mid}, qos={granted_qos})")


def main():
    """Point d'entrée principal de la gateway IoT."""
    global running

    # Enregistrement des gestionnaires de signaux
    signal.signal(signal.SIGTERM, signal_handler)
    signal.signal(signal.SIGINT, signal_handler)

    logger.info(f"[{GATEWAY_ID}] Démarrage de la gateway IoT")
    logger.info(f"[{GATEWAY_ID}] Broker       : {MQTT_BROKER}:{MQTT_PORT}")
    logger.info(f"[{GATEWAY_ID}] Souscription : {SUBSCRIBE_TOPIC}")
    logger.info(f"[{GATEWAY_ID}] Publication  : {PUBLISH_PREFIX}/#")

    # Création du client MQTT
    client = mqtt.Client(client_id=f"gateway-{GATEWAY_ID}", clean_session=True)
    client.on_connect    = on_connect
    client.on_disconnect = on_disconnect
    client.on_message    = on_message
    client.on_subscribe  = on_subscribe

    # Reconnexion automatique avec backoff exponentiel
    client.reconnect_delay_set(min_delay=1, max_delay=30)

    # Connexion au broker avec retry
    connected = False
    retry_count = 0
    max_retries = 10

    while not connected and retry_count < max_retries and running:
        try:
            logger.info(f"[{GATEWAY_ID}] Tentative de connexion ({retry_count + 1}/{max_retries})...")
            client.connect(MQTT_BROKER, MQTT_PORT, keepalive=60)
            connected = True
        except (ConnectionRefusedError, OSError) as e:
            retry_count += 1
            wait_time = min(2 ** retry_count, 30)
            logger.warning(f"[{GATEWAY_ID}] Connexion impossible ({e}), attente {wait_time}s...")
            time.sleep(wait_time)

    if not connected:
        logger.error(f"[{GATEWAY_ID}] Impossible de se connecter après {max_retries} tentatives")
        sys.exit(1)

    # Démarrer la boucle MQTT (bloquante jusqu'à arrêt)
    logger.info(f"[{GATEWAY_ID}] Gateway active, en attente de messages...")

    try:
        client.loop_start()
        while running:
            time.sleep(1)
    finally:
        logger.info(f"[{GATEWAY_ID}] Arrêt de la gateway...")
        client.loop_stop()
        client.disconnect()
        logger.info(f"[{GATEWAY_ID}] Gateway arrêtée proprement")


if __name__ == "__main__":
    main()
