# Guide de Configuration pfSense - Phase 1

**Fichier**     : pfSense-config-guide.md  
**Description** : Guide de configuration minimale pfSense pour le PFE IoT Security  
**Version**     : 1.0  
**Auteur**      : PFE IoT Security Team  
**Date**        : 2026-03-03  

---

## Prérequis

- pfSense 2.7+ installé sur la VM GNS3 (QEMU, 1024 Mo RAM)
- Interface **WAN** connectée au Cloud GNS3 (internet via VMware NAT)
- Interface **LAN** connectée au port ether1 de MikroTik

---

## 1. Configuration initiale au démarrage

Lors du premier démarrage de pfSense dans GNS3, une interface console apparaît.

### Assignation des interfaces

```
Do you want to set up VLANs now? → n
Enter the WAN interface name: em0   (connectée au Cloud/internet)
Enter the LAN interface name: em1   (connectée à MikroTik ether1)
Do you want to proceed? → y
```

---

## 2. Configuration WAN (Internet)

### Via la console pfSense (option 2 : Set interface IP)

1. Sélectionner **2) Set interface(s) IP address**
2. Choisir **1) WAN**
3. Configurer en **DHCP** (pfSense obtient une IP du réseau VMware NAT automatiquement)

```
Configure IPv4 address WAN interface via DHCP? → y
Configure IPv6 address WAN interface via DHCP6? → n
```

**Résultat attendu** : pfSense obtient une IP dans le range VMware NAT (ex: 192.168.111.x/24)

---

## 3. Configuration LAN (vers MikroTik)

### Via la console pfSense (option 2 : Set interface IP)

1. Sélectionner **2) Set interface(s) IP address**
2. Choisir **2) LAN**
3. Configurer manuellement :

```
Configure IPv4 address LAN interface via DHCP? → n
Enter the new LAN IPv4 address: 192.168.100.1
Enter the new LAN IPv4 subnet bit count: 24
Enter the new LAN IPv4 upstream gateway address: (laisser vide)
Configure IPv6 address LAN interface via DHCP6? → n
Do you want to enable the DHCP server on LAN? → n
```

**Résultat** : pfSense LAN = 192.168.100.1/24

> **Note** : MikroTik se connecte sur ce réseau avec l'IP 192.168.100.2

---

## 4. Accès à l'interface Web (WebGUI)

### Depuis hote-windows (Cloud VMnet8)

L'accès WebGUI pfSense se fait **depuis la VM hote-windows** via le réseau Management.

> Temporairement, on peut accéder via la console GNS3 pour la configuration initiale.

**URL** : `http://192.168.100.1` (depuis un client sur le réseau 192.168.100.0/24)

**Identifiants par défaut** :
- Login : `admin`
- Password : `pfsense`

> **IMPORTANT** : Changer le mot de passe lors du premier accès.

---

## 5. Configuration NAT Masquerade

### Via WebGUI : Firewall → NAT → Outbound

1. Aller dans **Firewall → NAT → Outbound**
2. Sélectionner **Automatic outbound NAT rule generation**
3. Cliquer **Save** puis **Apply Changes**

**Résultat** : Tout le trafic sortant par WAN est NATé automatiquement.

### Règle NAT manuelle (si mode hybride ou manuel)

| Interface | Source        | Destination | NAT Address | Description              |
|-----------|---------------|-------------|-------------|--------------------------|
| WAN       | 192.168.100.0/24 | *        | Interface WAN address | NAT MikroTik vers WAN |

---

## 6. Règles Firewall pfSense

### Politique :
- **LAN → WAN** : Autorisé (transit internet)
- **Inter-VLAN** : Délégué entièrement à MikroTik
- pfSense ne fait **pas** le routage inter-VLAN (c'est MikroTik qui s'en charge)

### Via WebGUI : Firewall → Rules → LAN

Ajouter la règle suivante :

| Champ       | Valeur              |
|-------------|---------------------|
| Action      | Pass                |
| Interface   | LAN                 |
| Protocol    | Any                 |
| Source      | LAN net             |
| Destination | Any                 |
| Description | Autoriser LAN → WAN |

---

## 7. DNS Resolver

### Via WebGUI : Services → DNS Resolver

1. Aller dans **Services → DNS Resolver**
2. S'assurer que **Enable DNS Resolver** est coché
3. **Network Interfaces** : All
4. **Outgoing Network Interfaces** : WAN
5. Cliquer **Save** puis **Apply Changes**

---

## 8. Vérifications post-configuration

### Depuis la console pfSense

```bash
# Vérifier les interfaces
ifconfig

# Tester la résolution DNS
host google.com

# Tester la connectivité
ping -c 3 8.8.8.8
ping -c 3 192.168.100.2   # MikroTik
```

### Depuis MikroTik (après configuration)

```
/ping 192.168.100.1 count=3    # pfSense LAN
/ping 8.8.8.8 count=3         # Internet via pfSense
```

---

## 9. Récapitulatif des adresses pfSense

| Interface | IP              | Rôle                        |
|-----------|-----------------|-----------------------------|
| WAN (em0) | DHCP (VMware NAT) | Accès internet            |
| LAN (em1) | 192.168.100.1/24 | Gateway vers MikroTik      |

---

## 10. Dépannage courant

### pfSense ne reçoit pas d'IP sur WAN

**Cause** : Le Cloud GNS3 n'est pas configuré sur la bonne interface VMware.

**Solution** :
1. Dans GNS3, éditer le nœud Cloud WAN
2. Sélectionner `VMnet8` (NAT VMware)
3. Redémarrer le nœud pfSense

### MikroTik ne peut pas pinger pfSense

**Cause** : La route par défaut MikroTik pointe vers 192.168.100.1 mais pfSense n'a pas encore son LAN configuré.

**Solution** : Configurer le LAN pfSense en premier (`192.168.100.1/24`), puis configurer MikroTik.

### Pas d'accès internet depuis les VLANs

**Cause** : NAT non configuré ou règle firewall LAN manquante.

**Solution** : Vérifier Firewall → NAT → Outbound et Firewall → Rules → LAN dans WebGUI.
