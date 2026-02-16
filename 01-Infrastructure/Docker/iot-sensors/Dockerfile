FROM python:3.11-slim

WORKDIR /app

# Installer paho-mqtt
RUN pip install --no-cache-dir paho-mqtt

# Copier les scripts
COPY sensor_main.py .

CMD ["python", "sensor_main.py"]