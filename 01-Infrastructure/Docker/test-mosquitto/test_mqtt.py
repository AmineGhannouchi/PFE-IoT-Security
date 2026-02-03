#!/usr/bin/env python3
"""
Script de test MQTT simple
"""

import paho.mqtt.client as mqtt
import time
import random

# Configuration
BROKER = "localhost"
PORT = 1883
TOPIC = "test/sensor"

def on_connect(client, userdata, flags, rc):
    if rc == 0:
        print("✅ Connecté au broker MQTT")
        client.subscribe(TOPIC)
    else:
        print(f"❌ Échec connexion, code: {rc}")

def on_message(client, userdata, msg):
    print(f"📩 Message reçu sur {msg.topic}: {msg.payload.decode()}")

def main():
    # Client subscriber
    client_sub = mqtt.Client(client_id="test-subscriber")
    client_sub.on_connect = on_connect
    client_sub.on_message = on_message
    client_sub.connect(BROKER, PORT, 60)
    client_sub.loop_start()
    
    time.sleep(2)
    
    # Client publisher
    client_pub = mqtt.Client(client_id="test-publisher")
    client_pub.connect(BROKER, PORT, 60)
    
    print("\n🚀 Envoi de 5 messages de test...\n")
    
    for i in range(5):
        temperature = round(random.uniform(18.0, 28.0), 2)
        message = f"Temperature: {temperature}°C"
        
        result = client_pub.publish(TOPIC, message)
        
        if result.rc == mqtt.MQTT_ERR_SUCCESS:
            print(f"📤 Envoyé: {message}")
        else:
            print(f"❌ Échec envoi")
        
        time.sleep(1)
    
    time.sleep(2)
    
    client_pub.disconnect()
    client_sub.loop_stop()
    client_sub.disconnect()
    
    print("\n✅ Test terminé avec succès!")

if __name__ == "__main__":
    main()