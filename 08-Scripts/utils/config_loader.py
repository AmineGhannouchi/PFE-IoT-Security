#!/usr/bin/env python3
"""
Utilitaire de chargement de la configuration globale
"""

import yaml
from pathlib import Path

class ConfigLoader:
    """Charge et gère la configuration du projet"""
    
    def __init__(self, config_path="config.yml"):
        """
        Initialise le loader avec le chemin du fichier de config
        
        Args:
            config_path: Chemin vers le fichier config.yml (relatif à la racine du projet)
        """
        # Trouver la racine du projet (où se trouve config.yml)
        self.project_root = self._find_project_root()
        self.config_file = self.project_root / config_path
        
        if not self.config_file.exists():
            raise FileNotFoundError(f"Configuration file not found: {self.config_file}")
        
        self.config = self._load_config()
    
    def _find_project_root(self):
        """Trouve la racine du projet en remontant jusqu'à trouver config.yml"""
        current = Path(__file__).resolve()
        
        # Remonter jusqu'à trouver config.yml
        for parent in current.parents:
            if (parent / "config.yml").exists():
                return parent
        
        raise FileNotFoundError("Could not find project root (config.yml not found)")
    
    def _load_config(self):
        """Charge le fichier YAML"""
        with open(self.config_file, 'r', encoding='utf-8') as f:
            return yaml.safe_load(f)
    
    def get(self, key_path, default=None):
        """
        Récupère une valeur de configuration avec notation pointée
        
        Args:
            key_path: Chemin vers la clé (ex: "networking.ports.mqtt_tls")
            default: Valeur par défaut si la clé n'existe pas
        
        Returns:
            La valeur de configuration ou default
        
        Example:
            >>> config = ConfigLoader()
            >>> mqtt_port = config.get("networking.ports.mqtt_tls")
            >>> print(mqtt_port)  # 8883
        """
        keys = key_path.split('.')
        value = self.config
        
        for key in keys:
            if isinstance(value, dict) and key in value:
                value = value[key]
            else:
                return default
        
        return value
    
    def get_vm_config(self, vm_name):
        """Récupère la configuration d'une VM spécifique"""
        return self.config.get('virtual_machines', {}).get(vm_name)
    
    def get_network_config(self, vlan_name=None):
        """Récupère la configuration réseau"""
        if vlan_name:
            return self.config.get('networking', {}).get('vlans', {}).get(vlan_name)
        return self.config.get('networking')
    
    def get_path(self, path_name):
        """Récupère un chemin du projet"""
        relative_path = self.config.get('paths', {}).get(path_name)
        if relative_path:
            return self.project_root / relative_path
        return None
    
    def __getitem__(self, key):
        """Permet l'accès avec config['key']"""
        return self.config[key]
    
    def __repr__(self):
        return f"ConfigLoader(project='{self.config['project']['name']}', root='{self.project_root}')"


# ==========================================
# Exemple d'utilisation
# ==========================================
if __name__ == "__main__":
    # Charger la configuration
    config = ConfigLoader()
    
    print("=" * 60)
    print("🔧 Configuration du Projet")
    print("=" * 60)
    
    # Informations générales
    print(f"\n📋 Projet: {config.get('project.name')}")
    print(f"👤 Auteur: {config.get('project.author')}")
    print(f"📅 Année: {config.get('project.year')}")
    
    # Environnement
    print(f"\n💻 Environnement:")
    print(f"  OS: {config.get('environment.os')}")
    print(f"  Hyperviseur: {config.get('environment.hypervisor')}")
    print(f"  RAM: {config.get('environment.ram_total_gb')} Go")
    print(f"  CPU: {config.get('environment.cpu_cores')} cœurs")
    
    # Réseau
    print(f"\n🌐 Ports principaux:")
    print(f"  MQTT TLS: {config.get('networking.ports.mqtt_tls')}")
    print(f"  Wazuh API: {config.get('networking.ports.wazuh_api')}")
    print(f"  Vault: {config.get('networking.ports.vault')}")
    
    # VLANs
    print(f"\n🔌 VLANs:")
    for vlan_name, vlan_config in config['networking']['vlans'].items():
        print(f"  {vlan_name}: {vlan_config['subnet']} (VLAN {vlan_config['id']})")
    
    # VMs
    print(f"\n🖥️  Machines Virtuelles:")
    for vm_name, vm_config in config['virtual_machines'].items():
        print(f"  {vm_config['name']}:")
        print(f"    RAM: {vm_config['ram_gb']} Go")
        print(f"    CPU: {vm_config['cpu_cores']} cœurs")
        print(f"    IP: {vm_config['ip']}")
    
    # PKI
    print(f"\n🔐 PKI:")
    print(f"  CA Validity: {config.get('pki.ca.validity_days')} jours")
    print(f"  Client Cert Validity: {config.get('pki.client_certificates.validity_days')} jours")
    print(f"  Rotation: {config.get('pki.client_certificates.rotation_enabled')}")
    
    # Chemins
    print(f"\n📂 Chemins principaux:")
    print(f"  Certificats: {config.get_path('certificates')}")
    print(f"  Logs: {config.get_path('logs')}")
    print(f"  Datasets: {config.get_path('datasets')}")
    
    print("\n" + "=" * 60)
    print("✅ Configuration chargée avec succès!")
    print("=" * 60)