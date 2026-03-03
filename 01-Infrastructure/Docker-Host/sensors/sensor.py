#!/usr/bin/env python3
# =============================================================================
# Fichier     : sensor.py
# Description : Script générique pour capteur IoT - PFE IoT Security
#               Publie des données de capteur sur un broker MQTT
# Version     : 1.0
# Auteur      : PFE IoT Security Team
# Date        : 2026-03-03
# =============================================================================

import os
import time
import json
import random
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
logger = logging.getLogger("IoTSensor")

# -----------------------------------------------------------------------------
# Variables d'environnement (avec valeurs par défaut)
# -----------------------------------------------------------------------------
MQTT_BROKER      = os.getenv("MQTT_BROKER", "192.168.10.20")
MQTT_PORT        = int(os.getenv("MQTT_PORT", "1883"))
SENSOR_TYPE      = os.getenv("SENSOR_TYPE", "temperature")
SENSOR_ID        = os.getenv("SENSOR_ID", "sensor-001")
PUBLISH_INTERVAL = float(os.getenv("PUBLISH_INTERVAL", "5"))

# Topic MQTT : iot/sensors/{type}/{id}
MQTT_TOPIC = f"iot/sensors/{SENSOR_TYPE}/{SENSOR_ID}"

# Drapeau pour arrêt propre
running = True


def signal_handler(sig, frame):
    """Gestionnaire de signal pour arrêt propre (SIGTERM/SIGINT)."""
    global running
    logger.info(f"[{SENSOR_ID}] Signal reçu ({sig}), arrêt en cours...")
    running = False


def generate_data() -> dict:
    """
    Génère une mesure simulée selon le type de capteur.

    Retourne:
        dict: Payload JSON avec timestamp, id, type, valeur et unité.
    """
    if SENSOR_TYPE == "temperature":
        value = round(random.uniform(18.0, 35.0), 2)
        unit  = "°C"
    elif SENSOR_TYPE == "humidity":
        value = round(random.uniform(30.0, 80.0), 2)
        unit  = "%"
    elif SENSOR_TYPE == "motion":
        value = random.choice([0, 1])
        unit  = "boolean"
    elif SENSOR_TYPE == "pressure":
        value = round(random.uniform(990.0, 1020.0), 2)
        unit  = "hPa"
    elif SENSOR_TYPE == "luminosity":
        value = round(random.uniform(0.0, 1000.0), 1)
        unit  = "lux"
    else:
        value = round(random.uniform(0.0, 100.0), 2)
        unit  = "generic"

    return {
        "timestamp":  time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime()),
        "sensor_id":  SENSOR_ID,
        "type":       SENSOR_TYPE,
        "value":      value,
        "unit":       unit,
    }


def on_connect(client, userdata, flags, rc):
    """Callback appelé lors de la connexion au broker MQTT."""
    if rc == 0:
        logger.info(f"[{SENSOR_ID}] Connecté au broker MQTT {MQTT_BROKER}:{MQTT_PORT}")
    else:
        codes = {
            1: "Protocole incorrect",
            2: "Client ID refusé",
            3: "Serveur indisponible",
            4: "Identifiants incorrects",
            5: "Non autorisé",
        }
        logger.error(f"[{SENSOR_ID}] Connexion échouée : {codes.get(rc, f'code={rc}')}")


def on_disconnect(client, userdata, rc):
    """Callback appelé lors de la déconnexion du broker MQTT."""
    if rc != 0:
        logger.warning(f"[{SENSOR_ID}] Déconnexion inattendue (rc={rc}), tentative de reconnexion...")
    else:
        logger.info(f"[{SENSOR_ID}] Déconnecté proprement du broker")


def on_publish(client, userdata, mid):
    """Callback appelé après la publication réussie d'un message."""
    logger.debug(f"[{SENSOR_ID}] Message {mid} publié avec succès")


def main():
    """Point d'entrée principal du capteur IoT."""
    global running

    # Enregistrement des gestionnaires de signaux pour arrêt propre
    signal.signal(signal.SIGTERM, signal_handler)
    signal.signal(signal.SIGINT, signal_handler)

    logger.info(f"[{SENSOR_ID}] Démarrage capteur {SENSOR_TYPE}")
    logger.info(f"[{SENSOR_ID}] Broker : {MQTT_BROKER}:{MQTT_PORT}")
    logger.info(f"[{SENSOR_ID}] Topic  : {MQTT_TOPIC}")
    logger.info(f"[{SENSOR_ID}] Intervalle : {PUBLISH_INTERVAL}s")

    # Création du client MQTT
    client = mqtt.Client(client_id=SENSOR_ID, clean_session=True)
    client.on_connect    = on_connect
    client.on_disconnect = on_disconnect
    client.on_publish    = on_publish

    # Reconnexion automatique
    client.reconnect_delay_set(min_delay=1, max_delay=30)

    # Connexion au broker avec retry
    connected = False
    retry_count = 0
    max_retries = 10

    while not connected and retry_count < max_retries and running:
        try:
            logger.info(f"[{SENSOR_ID}] Tentative de connexion ({retry_count + 1}/{max_retries})...")
            client.connect(MQTT_BROKER, MQTT_PORT, keepalive=60)
            connected = True
        except (ConnectionRefusedError, OSError) as e:
            retry_count += 1
            wait_time = min(2 ** retry_count, 30)  # Backoff exponentiel
            logger.warning(f"[{SENSOR_ID}] Connexion impossible ({e}), attente {wait_time}s...")
            time.sleep(wait_time)

    if not connected:
        logger.error(f"[{SENSOR_ID}] Impossible de se connecter après {max_retries} tentatives")
        sys.exit(1)

    # Démarrer la boucle réseau MQTT en arrière-plan
    client.loop_start()

    # Boucle principale de publication
    try:
        while running:
            data    = generate_data()
            payload = json.dumps(data, ensure_ascii=False)

            result = client.publish(MQTT_TOPIC, payload, qos=1, retain=False)

            if result.rc == mqtt.MQTT_ERR_SUCCESS:
                logger.info(f"[{SENSOR_ID}] Publié sur {MQTT_TOPIC} : {payload}")
            else:
                logger.warning(f"[{SENSOR_ID}] Échec publication (rc={result.rc})")

            time.sleep(PUBLISH_INTERVAL)

    finally:
        logger.info(f"[{SENSOR_ID}] Arrêt du capteur...")
        client.loop_stop()
        client.disconnect()
        logger.info(f"[{SENSOR_ID}] Capteur arrêté proprement")


if __name__ == "__main__":
    main()
