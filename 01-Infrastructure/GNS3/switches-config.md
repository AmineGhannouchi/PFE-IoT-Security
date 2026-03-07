# Guide de Configuration des Switches GNS3 - Phase 1

**Fichier**     : switches-config.md  
**Description** : Guide détaillé pour reconfigurer les switches Ethernet GNS3 et augmenter la RAM pfSense  
**Version**     : 1.0  
**Auteur**      : PFE IoT Security Team  
**Date**        : 2026-03-03  

---

## Contexte

Dans GNS3, les nœuds de type `ethernet_switch` sont configurés par défaut avec **tous les ports en VLAN 1** (mode access). Il faut les reconfigurer manuellement via l'interface graphique GNS3 pour correspondre à l'architecture VLAN du projet.

> **Important** : GNS3 ne supporte pas les configurations de switch sauvegardables dans un fichier `.rsc` comme MikroTik. La configuration se fait via l'interface graphique ou le fichier `.gns3` directement.

---

## 0. Augmenter la RAM de pfSense à 1024 Mo

### Étapes

1. **Arrêter** le nœud `pfSense-FW` dans GNS3 (clic droit → Stop)
2. Faire un **clic droit** sur `pfSense-FW` → **Configure**
3. Dans l'onglet **General settings** :
   - Champ `RAM` : remplacer `512` par **`1024`** (Mo)
4. Cliquer **OK** pour valider
5. **Redémarrer** le nœud pfSense

```
Avant : RAM = 512 Mo  ❌ (insuffisant pour pfSense 2.7+)
Après : RAM = 1024 Mo ✅
```

---

## 1. Switch VLAN10_IoT

### Rôle
Ce switch connecte les équipements du réseau IoT (VLAN 10) au routeur MikroTik.

### Topologie des ports

| Port | Type    | VLAN | Connecté à                      |
|------|---------|------|---------------------------------|
| e0   | trunk   | 10   | MikroTik ether2                 |
| e1   | access  | 10   | Docker-Host (IoT-Gateway)       |
| e2   | access  | 10   | Docker-Host (MQTT-Broker)       |
| e3   | access  | 10   | Docker-Host (IoT-Sensors)       |

### Procédure de configuration

1. **Arrêter** le nœud `VLAN10_IoT` (clic droit → Stop)
2. Clic droit → **Configure**
3. Onglet **Ports** :

   **Port e0 (Trunk vers MikroTik)** :
   - Type : `dot1q`
   - VLAN : `10`
   - Ethernet : `e0`

   **Port e1 (Access IoT-Gateway)** :
   - Type : `access`
   - VLAN : `10`
   - Ethernet : `e1`

   **Port e2 (Access MQTT-Broker)** :
   - Type : `access`
   - VLAN : `10`
   - Ethernet : `e2`

   **Port e3 (Access IoT-Sensors)** :
   - Type : `access`
   - VLAN : `10`
   - Ethernet : `e3`

4. Cliquer **OK** → **Démarrer** le nœud

### Vérification dans le fichier .gns3

Dans `PFE-GNS3/PFE-GNS3.gns3`, le nœud `VLAN10_IoT` doit avoir :

```json
"ports": [
  {"name": "Ethernet0", "port_number": 0, "type": "dot1q", "vlan": 10},
  {"name": "Ethernet1", "port_number": 1, "type": "access", "vlan": 10},
  {"name": "Ethernet2", "port_number": 2, "type": "access", "vlan": 10},
  {"name": "Ethernet3", "port_number": 3, "type": "access", "vlan": 10}
]
```

---

## 2. Switch VLAN20_SIEM

### Rôle
Ce switch connecte les équipements du réseau SIEM/monitoring (VLAN 20) au routeur MikroTik.

### Topologie des ports

| Port | Type    | VLAN | Connecté à                          |
|------|---------|------|-------------------------------------|
| e0   | trunk   | 20   | MikroTik ether3                     |
| e1   | access  | 20   | VM Wazuh (VMware VMnet3)            |
| e2   | access  | 20   | Docker-Host (Suricata)              |
| e3   | access  | 20   | Port SPAN/Mirror (trafic miroir)    |

### Procédure de configuration

1. **Arrêter** le nœud `VLAN20_SIEM`
2. Clic droit → **Configure**
3. Onglet **Ports** :

   **Port e0 (Trunk vers MikroTik)** :
   - Type : `dot1q`
   - VLAN : `20`

   **Port e1 (Access Wazuh)** :
   - Type : `access`
   - VLAN : `20`

   **Port e2 (Access Suricata)** :
   - Type : `access`
   - VLAN : `20`

   **Port e3 (Port SPAN mirror)** :
   - Type : `access`
   - VLAN : `20`
   - Note : Connecté à ether5 de MikroTik (port miroir)

4. Cliquer **OK** → **Démarrer**

### Vérification dans le fichier .gns3

```json
"ports": [
  {"name": "Ethernet0", "port_number": 0, "type": "dot1q", "vlan": 20},
  {"name": "Ethernet1", "port_number": 1, "type": "access", "vlan": 20},
  {"name": "Ethernet2", "port_number": 2, "type": "access", "vlan": 20},
  {"name": "Ethernet3", "port_number": 3, "type": "access", "vlan": 20}
]
```

---

## 3. Switch SW-VLAN30-MGT

### Rôle
Ce switch connecte les équipements du réseau Management/PKI (VLAN 30) au routeur MikroTik.

### Topologie des ports

| Port | Type    | VLAN | Connecté à                       |
|------|---------|------|----------------------------------|
| e0   | trunk   | 30   | MikroTik ether4                  |
| e1   | access  | 30   | Docker-Host (Vault PKI)          |
| e2   | access  | 30   | hote-windows (Cloud VMnet8)      |

### Procédure de configuration

1. **Arrêter** le nœud `SW-VLAN30-MGT`
2. Clic droit → **Configure**
3. Onglet **Ports** :

   **Port e0 (Trunk vers MikroTik)** :
   - Type : `dot1q`
   - VLAN : `30`

   **Port e1 (Access Vault)** :
   - Type : `access`
   - VLAN : `30`

   **Port e2 (Access host-windows)** :
   - Type : `access`
   - VLAN : `30`

4. Cliquer **OK** → **Démarrer**

### Vérification dans le fichier .gns3

```json
"ports": [
  {"name": "Ethernet0", "port_number": 0, "type": "dot1q", "vlan": 30},
  {"name": "Ethernet1", "port_number": 1, "type": "access", "vlan": 30},
  {"name": "Ethernet2", "port_number": 2, "type": "access", "vlan": 30}
]
```

---

## 4. Remplacement des nœuds VPCS par Docker

Les nœuds VPCS suivants doivent être **supprimés** et remplacés par des références à la VM Docker-Host :

| Nœud VPCS à supprimer | Remplacé par                          | VLAN |
|------------------------|---------------------------------------|------|
| IoT-Gateway            | Docker container `iot-gateway`        | 10   |
| MQTT-Broker            | Docker container `mosquitto`          | 10   |
| IoT-Sensors            | Docker containers `sensor-*`         | 10   |
| Suricata-IDS           | Docker container `suricata`           | 20   |
| Vault                  | Docker container `vault`              | 30   |

### Procédure

1. **Arrêter** et **supprimer** les nœuds VPCS dans GNS3
2. Ajouter un nœud **Cloud** pointant vers `VMnet3` (réseau GNS3 host-only)
3. Connecter ce nœud Cloud aux switches appropriés
4. Démarrer la VM Docker-Host (Ubuntu 22.04 sur VMware VMnet3)
5. Les conteneurs Docker communiqueront via les interfaces physiques (`eth0`, `eth1`, `eth2`) en mode macvlan

---

## 5. Récapitulatif de l'ordre de démarrage GNS3

Pour éviter les problèmes de convergence réseau, démarrer les nœuds dans cet ordre :

```
1. Switches (VLAN10_IoT, VLAN20_SIEM, SW-VLAN30-MGT)
2. pfSense-FW
3. MikroTik-CHR-CoreSwitch
4. VM Docker-Host (depuis VMware)
5. VM Wazuh (depuis VMware)
6. Cloud hote-windows
```

---

## 6. Dépannage courant

### Problème : Pas de connectivité après reconfiguration des switches

**Cause** : Les ports du switch ethernet GNS3 n'ont pas été sauvegardés correctement.

**Solution** :
1. Arrêter le nœud
2. Rouvrir la configuration (clic droit → Configure)
3. Vérifier que les types de ports sont corrects (`dot1q` pour trunk, `access` pour access)
4. Redémarrer le nœud

### Problème : pfSense ne boot pas après augmentation RAM

**Cause** : VMware Workstation peut avoir besoin d'être redémarré.

**Solution** : Redémarrer GNS3 et VMware Workstation, puis relancer la topologie.

### Problème : MikroTik ne route pas entre VLANs

**Solution** : Vérifier que les interfaces VLAN sont bien créées :
```
/interface vlan print
/ip address print
/ip route print
```
