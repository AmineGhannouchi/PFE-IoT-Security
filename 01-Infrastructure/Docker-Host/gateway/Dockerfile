# =============================================================================
# Fichier     : Dockerfile
# Description : Image Docker pour l'IoT Gateway - PFE IoT Security
# Version     : 1.0
# Auteur      : PFE IoT Security Team
# Date        : 2026-03-03
# =============================================================================

FROM python:3.11-alpine

# Métadonnées de l'image
LABEL maintainer="PFE IoT Security Team"
LABEL description="IoT Gateway MQTT - PFE IoT Security Phase 1"
LABEL version="1.0"

# Répertoire de travail
WORKDIR /app

# Installer les dépendances Python
# paho-mqtt : client MQTT pour Python
COPY requirements.txt ./
RUN pip install --no-cache-dir -r requirements.txt

# Copier le script de la gateway
COPY gateway.py .

# Variables d'environnement par défaut
ENV MQTT_BROKER=192.168.10.20 \
    MQTT_PORT=1883 \
    GATEWAY_ID=gw-001

# Lancer la gateway
CMD ["python", "-u", "gateway.py"]
