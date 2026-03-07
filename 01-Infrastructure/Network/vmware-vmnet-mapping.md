# Cartographie VMware VMnet ↔ VLAN PFE IoT Security

**Fichier**     : vmware-vmnet-mapping.md  
**Description** : Table de correspondance VMnet VMware ↔ VLANs ↔ interfaces Linux  
**Version**     : 1.0  
**Date**        : 2026-03-07  

## Tableau de correspondance

| VMnet VMware | Type VMware | VLAN GNS3 | Subnet | Interface Linux (Docker-Host) | Rôle |
|---|---|---|---|---|---|
| VMnet1 | Host-only | VLAN 10 IoT | 192.168.10.0/24 | ens33 | Parent macvlan conteneurs IoT |
| VMnet2 | Host-only | VLAN 20 SIEM | 192.168.20.0/24 | ens34 | Parent macvlan conteneurs SIEM / Wazuh OVA |
| VMnet3 | Host-only | VLAN 30 Management | 192.168.30.0/24 | ens35 | IP fixe 192.168.30.100 |
| VMnet8 | NAT | WAN/Internet | DHCP | ens36 | Accès internet |

## Configuration VMware Virtual Network Editor

Vérifier dans VMware → Edit → Virtual Network Editor :

- **VMnet1** : Host-only, pas de DHCP, subnet 192.168.10.0/24
- **VMnet2** : Host-only, pas de DHCP, subnet 192.168.20.0/24
- **VMnet3** : Host-only, pas de DHCP, subnet 192.168.30.0/24
- **VMnet8** : NAT (par défaut VMware)

## Machines connectées par VMnet

### VMnet1 (VLAN10 IoT)
- Docker-Host Ubuntu (ens33) — parent macvlan
- Conteneurs Docker : Mosquitto (192.168.10.20), IoT-Gateway (192.168.10.10), Capteurs (192.168.10.101-103)

### VMnet2 (VLAN20 SIEM)
- Docker-Host Ubuntu (ens34) — parent macvlan
- **Wazuh 4.14.2 OVA** (192.168.20.10) ← À reconfigurer depuis VMnet3
- Conteneur Suricata (192.168.20.30)

### VMnet3 (VLAN30 Management)
- Docker-Host Ubuntu (ens35) — IP fixe 192.168.30.100
- Conteneur Vault (192.168.30.10)
- GNS3 VM (192.168.30.20)
- Host Windows (192.168.30.1 ou DHCP selon config)

### VMnet8 (NAT Internet)
- Docker-Host Ubuntu (ens36) — DHCP
- Host Windows — DHCP VMware NAT

## Note importante sur macvlan

Avec macvlan, les conteneurs Docker sont "directement" sur le réseau physique VMnet.
Le Docker-Host lui-même ne peut PAS communiquer directement avec les conteneurs via macvlan
(limitation Linux macvlan). Pour résoudre cela, un bridge macvlan est nécessaire :

```bash
# Créer un bridge pour permettre au Docker-Host de parler aux conteneurs VLAN10
ip link add macvlan10-bridge link ens33 type macvlan mode bridge
ip addr add 192.168.10.200/24 dev macvlan10-bridge
ip link set macvlan10-bridge up
```

Ce bridge doit être créé après `docker compose up` si une communication hôte↔conteneur est nécessaire.

## TODO — Amélioration future

- [ ] Ajouter support CoAP/DTLS (protocole UDP pour capteurs contraints)
- [ ] Évaluer migration vers GNS3 natif avec Docker integration
