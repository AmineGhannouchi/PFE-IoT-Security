# Guide de reconfiguration réseau Wazuh OVA — PFE IoT Security

**Fichier**     : wazuh-network-setup.md  
**Description** : Guide pour reconfigurer la VM Wazuh 4.14.2 OVA du VMnet3 vers VMnet2  
**Version**     : 1.0  
**Date**        : 2026-03-07  

## Contexte

La VM Wazuh 4.14.2 OVA est actuellement connectée à VMnet3 avec l'IP 192.168.30.129 (VLAN30 Management).
Elle doit être reconfigurée sur VMnet2 (VLAN20 SIEM) avec l'IP fixe 192.168.20.10/24.

## Étape 1 : Changer l'interface réseau dans VMware

1. Éteindre la VM Wazuh dans VMware
2. VM Settings → Network Adapter → changer de VMnet3 vers **VMnet2**
3. Démarrer la VM

## Étape 2 : Reconfigurer l'IP dans Wazuh OVA

La Wazuh OVA utilise Ubuntu. Identifier le nom de l'interface réseau :

```bash
ip link show
```

Modifier la configuration Netplan (le fichier peut varier) :

```bash
sudo nano /etc/netplan/50-cloud-init.yaml
# ou
sudo nano /etc/netplan/00-installer-config.yaml
```

Configuration cible :

```yaml
network:
  version: 2
  ethernets:
    ens33:   # ou le nom détecté
      dhcp4: false
      addresses:
        - 192.168.20.10/24
      routes:
        - to: default
          via: 192.168.20.1
      nameservers:
        addresses: [8.8.8.8, 8.8.4.4]
```

Appliquer :

```bash
sudo chmod 600 /etc/netplan/*.yaml
sudo netplan apply
```

## Étape 3 : Vérifier la connectivité

```bash
# Depuis Wazuh OVA
ping 192.168.20.1    # Gateway MikroTik VLAN20
ping 192.168.30.100  # Docker-Host Management
ping 8.8.8.8         # Internet via pfSense

# Depuis Docker-Host
ping 192.168.20.10   # Wazuh OVA
```

## Étape 4 : Accéder au Dashboard Wazuh

URL : https://192.168.20.10  
Credentials par défaut : admin / admin (à changer !)

## Adresses finales VLAN20

| Service | IP | Port |
|---|---|---|
| Wazuh Manager | 192.168.20.10 | 1514 (agents), 1515 (enrollment) |
| OpenSearch | 192.168.20.10 | 9200 |
| Wazuh Dashboard | 192.168.20.10 | 443 |
| Suricata (Docker) | 192.168.20.30 | - |

## Note amélioration future

TODO : Ajouter support CoAP/DTLS (aiocoap) pour les capteurs IoT qui utilisent UDP.
Voir : https://aiocoap.readthedocs.io/
