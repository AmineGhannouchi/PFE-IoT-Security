# ==========================================
# MikroTik CHR - Core Switch L3
# PFE IoT Security
# ==========================================

# Interfaces
/interface set ether1 comment="Uplink-pfSense"
/interface set ether2 comment="VLAN10-IoT"
/interface set ether3 comment="VLAN20-SIEM"
/interface set ether4 comment="VLAN30-Management"

# IP Addresses
/ip address add address=192.168.100.2/24 interface=ether1 comment="Uplink to pfSense"
/ip address add address=192.168.10.1/24 interface=ether2 comment="Gateway VLAN10 IoT"
/ip address add address=192.168.20.1/24 interface=ether3 comment="Gateway VLAN20 SIEM"
/ip address add address=192.168.30.1/24 interface=ether4 comment="Gateway VLAN30 Management"

# Default Route
/ip route add dst-address=0.0.0.0/0 gateway=192.168.100.1 comment="Default route via pfSense"

# DNS
/ip dns set servers=8.8.8.8,8.8.4.4 allow-remote-requests=yes

# DHCP Pools
/ip pool add name=pool-vlan10 ranges=192.168.10.100-192.168.10.200
/ip pool add name=pool-vlan20 ranges=192.168.20.100-192.168.20.200
/ip pool add name=pool-vlan30 ranges=192.168.30.100-192.168.30.200

# DHCP Servers
/ip dhcp-server add name=dhcp-vlan10 interface=ether2 address-pool=pool-vlan10 disabled=no
/ip dhcp-server add name=dhcp-vlan20 interface=ether3 address-pool=pool-vlan20 disabled=no
/ip dhcp-server add name=dhcp-vlan30 interface=ether4 address-pool=pool-vlan30 disabled=no

# DHCP Networks
/ip dhcp-server network add address=192.168.10.0/24 gateway=192.168.10.1 dns-server=8.8.8.8 comment="VLAN10-IoT"
/ip dhcp-server network add address=192.168.20.0/24 gateway=192.168.20.1 dns-server=8.8.8.8 comment="VLAN20-SIEM"
/ip dhcp-server network add address=192.168.30.0/24 gateway=192.168.30.1 dns-server=8.8.8.8 comment="VLAN30-Management"

# Firewall Filter
/ip firewall filter add chain=input protocol=icmp action=accept comment="Allow ICMP"
/ip firewall filter add chain=input connection-state=established,related action=accept comment="Allow established"
/ip firewall filter add chain=input in-interface=ether4 action=accept comment="Allow Management to router"
/ip firewall filter add chain=input action=drop log=yes log-prefix="FW-INPUT-DROP" comment="Drop all other input"

/ip firewall filter add chain=forward connection-state=established,related action=accept comment="Allow established forward"
/ip firewall filter add chain=forward src-address=192.168.10.0/24 dst-address=192.168.10.0/24 action=accept comment="IoT internal"
/ip firewall filter add chain=forward src-address=192.168.10.0/24 dst-address=192.168.20.0/24 action=accept comment="IoT to SIEM logs"
/ip firewall filter add chain=forward src-address=192.168.10.0/24 dst-address=192.168.30.10 protocol=tcp dst-port=8200 action=accept comment="IoT to Vault PKI"
/ip firewall filter add chain=forward src-address=192.168.20.0/24 action=accept comment="SIEM monitor all"
/ip firewall filter add chain=forward src-address=192.168.30.0/24 action=accept comment="Management full access"
/ip firewall filter add chain=forward src-address=192.168.10.0/24 out-interface=ether1 action=drop log=yes log-prefix="FW-IOT-BLOCKED" comment="Block IoT to Internet"
/ip firewall filter add chain=forward action=accept comment="Allow remaining forward"

# NAT
/ip firewall nat add chain=srcnat out-interface=ether1 action=masquerade comment="NAT to pfSense"

# Logging
/system logging action add name=remote-wazuh target=remote remote=192.168.20.10 remote-port=514
/system logging add topics=firewall action=remote-wazuh

# System
/system identity set name="CoreSwitch-L3"
/system clock set time-zone-name=Africa/Tunis
/system ntp client set enabled=yes
/system ntp client servers add address=pool.ntp.org

# Services - Restrict to Management VLAN
/ip service set www address=192.168.30.0/24
/ip service set winbox address=192.168.30.0/24
/ip service set ssh address=192.168.30.0/24
/ip service set api disabled=yes
/ip service set api-ssl disabled=yes