# Guide d'intégration de la VM Docker-Host dans GNS3

**Fichier**     : docker-host-gns3-integration.md  
**Description** : Guide d'intégration de la VM Docker-Host Ubuntu dans la topologie GNS3  
**Version**     : 1.0  
**Auteur**      : PFE IoT Security Team  
**Date**        : 2026-03-07  

---

## 1. Architecture : macvlan direct vs 802.1Q

### Pourquoi macvlan direct (pas de 802.1Q côté Ubuntu) ?

Dans cette architecture, VMware Workstation crée un réseau L2 **distinct** pour chaque VMnet.
La VM Docker-Host est connectée à **4 VMnets séparés**, chacun correspondant à un VLAN GNS3 :

| Interface Ubuntu | VMnet  | Plage réseau         | VLAN GNS3 |
|------------------|--------|----------------------|-----------|
| eth0             | VMnet1 | 192.168.10.0/24      | VLAN 10   |
| eth1             | VMnet2 | 192.168.20.0/24      | VLAN 20   |
| eth2             | VMnet3 | 192.168.30.0/24      | VLAN 30   |
| eth3             | VMnet8 | DHCP (NAT internet)  | -         |

Chaque VMnet est déjà un segment L2 isolé côté VMware. Il n'est donc **pas nécessaire** de
configurer des sous-interfaces VLAN 802.1Q (`eth0.10`, `eth0.20`, `eth0.30`) sur Ubuntu.
Le driver macvlan Docker s'appuie directement sur les interfaces physiques `eth0`, `eth1`, `eth2`.

---

## 2. Comment GNS3 voit la VM via les Cloud nodes VMnet

GNS3 utilise des **Cloud nodes** pour relier la topologie virtuelle aux VMnets de VMware.
Un Cloud node dans GNS3 peut être associé à une interface réseau du PC hôte Windows,
y compris les interfaces VMnet créées par VMware Workstation.

```
PC Hôte Windows 11
├── VMware Workstation
│   ├── VMnet1 (192.168.10.0/24)  ←→  [Cloud VMnet1] dans GNS3
│   ├── VMnet2 (192.168.20.0/24)  ←→  [Cloud VMnet2] dans GNS3
│   ├── VMnet3 (192.168.30.0/24)  ←→  [Cloud VMnet3] dans GNS3
│   └── VMnet8 (NAT)              ←→  [Cloud VMnet8] dans GNS3
│
└── VM Ubuntu Docker-Host
    ├── eth0  ←→  VMnet1  ←→  [Cloud VMnet1]  ←→  Switch VLAN10_IoT (GNS3)
    ├── eth1  ←→  VMnet2  ←→  [Cloud VMnet2]  ←→  Switch VLAN20_SIEM (GNS3)
    ├── eth2  ←→  VMnet3  ←→  [Cloud VMnet3]  ←→  Switch SW-VLAN30-MGT (GNS3)
    └── eth3  ←→  VMnet8  ←→  accès internet (NAT VMware)
```

---

## 3. Mapping VMnet ↔ VLAN dans GNS3

| Cloud GNS3    | VMnet associé | VLAN    | Switch GNS3      | Plage réseau        |
|---------------|---------------|---------|------------------|---------------------|
| Cloud VMnet1  | VMnet1        | VLAN 10 | Switch VLAN10_IoT| 192.168.10.0/24     |
| Cloud VMnet2  | VMnet2        | VLAN 20 | Switch VLAN20_SIEM| 192.168.20.0/24    |
| Cloud VMnet3  | VMnet3        | VLAN 30 | Switch SW-VLAN30-MGT | 192.168.30.0/24 |

---

## 4. Étapes pour connecter les switches GNS3 aux Cloud VMnet

### 4.1 Prérequis VMware Workstation

Vérifier dans VMware Workstation → Edit → Virtual Network Editor :

| VMnet  | Mode         | Plage réseau          |
|--------|--------------|-----------------------|
| VMnet1 | Host-only    | 192.168.10.0/24       |
| VMnet2 | Host-only    | 192.168.20.0/24       |
| VMnet3 | Host-only    | 192.168.30.0/24       |
| VMnet8 | NAT          | 192.168.200.0/24      |
| VMnet9 | Host-only    | 192.168.100.0/24      |

### 4.2 Configuration des Cloud nodes dans GNS3

1. **Ajouter un Cloud node** pour chaque VMnet :
   - Dans GNS3, faire glisser un nœud « Cloud » dans la topologie
   - Double-cliquer sur le Cloud → onglet « NIO Ethernet »
   - Sélectionner l'interface VMware correspondante (ex. `VMnet1`)
   - Répéter pour VMnet2 et VMnet3

2. **Connecter les switches** :
   ```
   [Switch VLAN10_IoT]  -- port  ↔  [Cloud VMnet1]
   [Switch VLAN20_SIEM] -- port  ↔  [Cloud VMnet2]
   [Switch SW-VLAN30-MGT] -- port ↔ [Cloud VMnet3]
   ```

3. **Connecter MikroTik CHR** aux switches :
   ```
   MikroTik ether2 ↔ Switch VLAN10_IoT
   MikroTik ether3 ↔ Switch VLAN20_SIEM
   MikroTik ether4 ↔ Switch SW-VLAN30-MGT
   ```

### 4.3 Configuration de la VM Ubuntu Docker-Host

Vérifier que la VM Ubuntu a bien **4 adaptateurs réseau** dans les paramètres VMware :

| Adaptateur | VMnet  |
|------------|--------|
| Réseau 1   | VMnet1 |
| Réseau 2   | VMnet2 |
| Réseau 3   | VMnet3 |
| Réseau 4   | VMnet8 |

Lancer le script de configuration :
```bash
sudo bash /opt/PFE-IoT-Security/01-Infrastructure/Docker-Host/setup-docker-host.sh
```

---

## 5. Vérification de la connectivité

### Depuis Ubuntu vers MikroTik (via eth2 / VLAN30 Management)

```bash
# Vérifier les interfaces
ip addr show eth0
ip addr show eth1
ip addr show eth2
ip addr show eth3

# Tester la gateway Management
ping -c 3 192.168.30.1

# Tester l'accès internet (via eth3 NAT)
ping -c 3 8.8.8.8
```

### Vérifier les réseaux Docker macvlan

```bash
# Lancer les conteneurs
cd /opt/docker-host
docker compose up -d

# Vérifier les réseaux macvlan créés
docker network ls
docker network inspect pfe-iot-security_vlan10
docker network inspect pfe-iot-security_vlan20
docker network inspect pfe-iot-security_vlan30

# Tester la connectivité d'un conteneur vers MikroTik
docker exec mosquitto ping -c 3 192.168.10.1
docker exec vault ping -c 3 192.168.30.1
```

### Depuis GNS3 vers Docker-Host

Depuis MikroTik CHR dans GNS3 :
```
/ping 192.168.30.100   # Docker-Host eth2 (Management)
```

---

## 6. Dépannage

| Symptôme                                      | Cause probable                         | Solution                                      |
|-----------------------------------------------|----------------------------------------|-----------------------------------------------|
| `eth0` n'apparaît pas dans Ubuntu             | VMnet1 non assigné à la VM             | Vérifier paramètres VM dans VMware            |
| Ping 192.168.30.1 échoue depuis Ubuntu        | GNS3 non démarré ou Cloud non connecté | Démarrer GNS3 et vérifier Cloud VMnet3        |
| Conteneur Docker sans IP                      | Interface parent macvlan inexistante   | Vérifier `ip link show eth0`                  |
| `docker compose up` échoue sur réseau macvlan | Interface parent down                  | `ip link set eth0 up && ip link set eth1 up`  |
