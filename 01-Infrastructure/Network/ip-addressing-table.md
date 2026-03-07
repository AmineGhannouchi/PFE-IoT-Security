# Tableau d'adressage IP - PFE IoT Security

**Fichier**     : ip-addressing-table.md  
**Description** : Tableau complet d'adressage IP de l'infrastructure PFE IoT Security  
**Version**     : 3.0  
**Auteur**      : PFE IoT Security Team  
**Date**        : 2026-03-07  

---

## 1. Résumé des réseaux

| Réseau           | VLAN | Plage d'adresses    | Gateway        | Rôle                        |
|------------------|------|---------------------|----------------|-----------------------------|
| Uplink pfSense   | -    | 192.168.100.0/24    | 192.168.100.1  | Lien pfSense ↔ MikroTik    |
| IoT              | 10   | 192.168.10.0/24     | 192.168.10.1   | Capteurs et broker MQTT     |
| SIEM             | 20   | 192.168.20.0/24     | 192.168.20.1   | Monitoring et détection     |
| Management/PKI   | 30   | 192.168.30.0/24     | 192.168.30.1   | Administration et PKI       |
| WAN (VMware NAT) | -    | 192.168.111.0/24    | 192.168.111.2  | Accès internet (DHCP)       |

---

## 2. Équipements réseau

| Équipement             | Interface | Adresse IP         | MAC          | Rôle                              |
|------------------------|-----------|--------------------|--------------|-----------------------------------|
| pfSense-FW             | WAN (em0) | DHCP (VMware NAT)  | Dynamique    | Firewall périmétrique / NAT       |
| pfSense-FW             | LAN (em1) | 192.168.100.1/24   | Dynamique    | Gateway vers MikroTik             |
| MikroTik-CHR           | ether1    | 192.168.100.2/24   | Dynamique    | Uplink vers pfSense               |
| MikroTik-CHR           | ether2    | -                  | Dynamique    | Trunk VLAN10 IoT                  |
| MikroTik-CHR           | vlan10-iot| 192.168.10.1/24    | Dynamique    | Gateway VLAN 10                   |
| MikroTik-CHR           | ether3    | -                  | Dynamique    | Trunk VLAN20 SIEM                 |
| MikroTik-CHR           | vlan20-siem| 192.168.20.1/24   | Dynamique    | Gateway VLAN 20                   |
| MikroTik-CHR           | ether4    | -                  | Dynamique    | Trunk VLAN30 Management           |
| MikroTik-CHR           | vlan30-mgmt| 192.168.30.1/24   | Dynamique    | Gateway VLAN 30                   |
| MikroTik-CHR           | ether5    | -                  | Dynamique    | Port SPAN/Mirror → Suricata       |
| hote-windows           | VMnet8    | DHCP (VMware NAT)  | Dynamique    | PC hôte Windows 11                |

---

## 3. VM Docker-Host

| Équipement | Interface VMware | Interface Linux | Adresse IP | Rôle |
|---|---|---|---|---|
| Docker-Host (Ubuntu Server) | VMnet1 | ens33 | aucune (parent macvlan) | VLAN10 IoT |
| Docker-Host (Ubuntu Server) | VMnet2 | ens34 | aucune (parent macvlan) | VLAN20 SIEM |
| Docker-Host (Ubuntu Server) | VMnet3 | ens35 | 192.168.30.100/24 | VLAN30 Management |
| Docker-Host (Ubuntu Server) | VMnet8 | ens36 | DHCP | NAT Internet |

### Reconfiguration Wazuh OVA

| Équipement | Interface VMware | Adresse IP cible | Statut | Note |
|---|---|---|---|---|
| Wazuh 4.14.2 OVA | VMnet2 | 192.168.20.10/24 | À reconfigurer | Actuellement sur VMnet3 (192.168.30.129) |

---

## 4. Conteneurs Docker (VLAN 10 - IoT)

| Conteneur      | IP              | Ports exposés         | Rôle                          |
|----------------|-----------------|----------------------|-------------------------------|
| mosquitto      | 192.168.10.20   | 1883, 8883, 9001     | Broker MQTT central           |
| iot-gateway    | 192.168.10.10   | -                    | Gateway MQTT (enrichissement) |
| sensor-temp    | 192.168.10.101  | -                    | Capteur température           |
| sensor-humid   | 192.168.10.102  | -                    | Capteur humidité              |
| sensor-motion  | 192.168.10.103  | -                    | Capteur mouvement             |

---

## 5. Conteneurs Docker (VLAN 20 - SIEM)

| Conteneur  | IP              | Ports exposés | Rôle                            |
|------------|-----------------|---------------|---------------------------------|
| suricata   | host (réseau hôte) | -          | IDS - analyse trafic SPAN       |

---

## 6. Conteneurs Docker (VLAN 30 - Management)

| Conteneur | IP              | Ports exposés | Rôle                         |
|-----------|-----------------|---------------|------------------------------|
| vault     | 192.168.30.10   | 8200          | Gestionnaire de secrets / PKI |

---

## 7. VMs VMware

| VM              | Réseau VMware               | Adresse IP         | Rôle                              |
|-----------------|-----------------------------|--------------------|-----------------------------------|
| Wazuh Manager   | VMnet2                      | 192.168.20.10      | SIEM - collecte et analyse logs   |
| Docker-Host     | VMnet1, VMnet2, VMnet3, VMnet8 | Voir section 3  | Hébergement conteneurs Docker     |

---

## 8. Table de routage MikroTik CHR

| Destination       | Masque | Via Gateway     | Interface   | Description                    |
|-------------------|--------|-----------------|-------------|--------------------------------|
| 0.0.0.0/0         | /0     | 192.168.100.1   | ether1      | Route par défaut vers pfSense  |
| 192.168.100.0     | /24    | -               | ether1      | Réseau uplink (directement)    |
| 192.168.10.0      | /24    | -               | vlan10-iot  | Réseau IoT (directement)       |
| 192.168.20.0      | /24    | -               | vlan20-siem | Réseau SIEM (directement)      |
| 192.168.30.0      | /24    | -               | vlan30-mgmt | Réseau Management (directement)|

---

## 9. Règles Firewall MikroTik (résumé)

### Chaîne INPUT (vers le routeur)

| Protocole | Action  | Description                     |
|-----------|---------|---------------------------------|
| ICMP      | Accept  | Autoriser les pings             |
| Established/Related | Accept | Connexions établies  |
| VLAN30-Mgmt | Accept | Administration depuis Mgmt    |
| Tout      | Drop    | Refus par défaut                |

### Chaîne FORWARD (transit)

| Source              | Destination         | Action | Description                    |
|---------------------|---------------------|--------|--------------------------------|
| Established/Related | *                   | Accept | Connexions établies            |
| 192.168.10.0/24     | 192.168.10.0/24     | Accept | IoT interne                    |
| 192.168.10.0/24     | 192.168.20.0/24     | Accept | IoT → SIEM (logs)              |
| 192.168.10.0/24     | 192.168.30.10:8200  | Accept | IoT → Vault PKI                |
| 192.168.10.0/24     | ether1 (internet)   | Drop   | Bloquer IoT → Internet         |
| 192.168.20.0/24     | 192.168.10.0/24     | Drop   | Bloquer SIEM → IoT             |
| 192.168.20.0/24     | *                   | Accept | SIEM → tout (monitoring)       |
| 192.168.30.0/24     | *                   | Accept | Management → tout              |
| *                   | *                   | Drop   | Refus par défaut               |

---

## 10. Ports applicatifs importants

| Service        | IP              | Port  | Protocole | Description                    |
|----------------|-----------------|-------|-----------|--------------------------------|
| MQTT           | 192.168.10.20   | 1883  | TCP       | MQTT non sécurisé (Phase 1)    |
| MQTT TLS       | 192.168.10.20   | 8883  | TCP/TLS   | MQTT sécurisé (Phase 3)        |
| MQTT WebSocket | 192.168.10.20   | 9001  | TCP/WS    | MQTT WebSocket                 |
| Vault API      | 192.168.30.10   | 8200  | TCP       | API HashiCorp Vault            |
| Wazuh API      | 192.168.20.10   | 55000 | TCP/HTTPS | API Wazuh Manager              |
| Wazuh Agent    | 192.168.20.10   | 1514  | UDP/TCP   | Communication agents Wazuh     |
| Syslog MikroTik| 192.168.20.10   | 514   | UDP       | Logs firewall MikroTik → Wazuh |
