#!/usr/bin/env python3
import os
import time
import json
import random
import paho.mqtt.client as mqtt

SENSOR_TYPE = os.getenv('SENSOR_TYPE', 'temperature')
MQTT_BROKER = os.getenv('MQTT_BROKER', '192.168.10.20')
MQTT_PORT = int(os.getenv('MQTT_PORT', 1883))
SENSOR_ID = os.getenv('SENSOR_ID', 'sensor-001')
PUBLISH_INTERVAL = int(os.getenv('PUBLISH_INTERVAL', 5))

def on_connect(client, userdata, flags, rc):
    if rc == 0:
        print(f"✅ [{SENSOR_ID}] Connected to MQTT broker")
    else:
        print(f"❌ [{SENSOR_ID}] Connection failed, code: {rc}")

def generate_data():
    if SENSOR_TYPE == 'temperature':
        value = round(random.uniform(18.0, 28.0), 2)
        unit = "°C"
    elif SENSOR_TYPE == 'humidity':
        value = round(random.uniform(30.0, 70.0), 2)
        unit = "%"
    elif SENSOR_TYPE == 'motion':
        value = random.choice([0, 1])
        unit = "boolean"
    else:
        value = random.uniform(0, 100)
        unit = "generic"
    
    return {
        "sensor_id": SENSOR_ID,
        "type": SENSOR_TYPE,
        "value": value,
        "unit": unit,
        "timestamp": time.time()
    }

def main():
    client = mqtt.Client(client_id=SENSOR_ID)
    client.on_connect = on_connect
    
    try:
        client.connect(MQTT_BROKER, MQTT_PORT, 60)
        client.loop_start()
        
        topic = f"iot/sensors/{SENSOR_TYPE}/{SENSOR_ID}"
        
        while True:
            data = generate_data()
            payload = json.dumps(data)
            client.publish(topic, payload, qos=1)
            print(f"📤 [{SENSOR_ID}] Published: {payload}")
            time.sleep(PUBLISH_INTERVAL)
            
    except KeyboardInterrupt:
        print(f"\n🛑 [{SENSOR_ID}] Stopping sensor")
    except Exception as e:
        print(f"❌ [{SENSOR_ID}] Error: {e}")
    finally:
        client.loop_stop()
        client.disconnect()

if __name__ == "__main__":
    main()