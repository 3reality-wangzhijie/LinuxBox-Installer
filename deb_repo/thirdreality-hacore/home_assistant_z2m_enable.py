#!/srv/homeassistant/bin/python3
# -*- coding: utf-8 -*-

# home_assistant_z2m_enable.py

import os
import re
import json
import sys
import subprocess
import uuid
from datetime import datetime, timezone

# Base path
BASE_PATH = "/var/lib/homeassistant"

class ConfigError(Exception):
    """Exception raised for configuration errors."""
    pass

def check_required_services():
    """Check if required services exist"""
    required_services = ['mosquitto.service', 'zigbee2mqtt.service']
    missing_services = []
    
    for service in required_services:
        result = subprocess.run(['systemctl', 'is-enabled', service], 
                               stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
        
        # If return code is non-zero and not 'disabled', the service doesn't exist
        if result.returncode != 0 and 'disabled' not in result.stdout:
            missing_services.append(service)
    
    if missing_services:
        missing_list = ', '.join(missing_services)
        print(f"Error: Required services not installed: {missing_list}")
        print("Cannot enable Zigbee2MQTT integration without these services.")
        raise ConfigError(f"Required services missing: {missing_list}")


def check_and_stop_ha_service():
    """Check if home-assistant.service is running and stop it if needed"""
    need_restart = False
    
    try:
        result = subprocess.run(['systemctl', 'is-active', 'home-assistant.service'], 
                               stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
        
        if result.stdout.strip() == 'active':
            print("Stopping home-assistant.service...")
            subprocess.run(['systemctl', 'stop', 'home-assistant.service'], 
                          stdout=subprocess.PIPE, stderr=subprocess.PIPE)
            need_restart = True
    except Exception as e:
        print(f"Error checking or stopping home-assistant.service: {e}")
    
    return need_restart

def update_config_entries():
    """Update config entries to remove ZHA and ensure MQTT is configured"""
    config_entries_path = os.path.join(BASE_PATH, "homeassistant/.storage/core.config_entries")
    zha_entry_id = None
    mqtt_entry_id = None
    
    if not os.path.exists(config_entries_path):
        raise ConfigError(f"Error: {config_entries_path} does not exist")
    
    try:
        with open(config_entries_path, 'r') as f:
            config_data = json.load(f)
    except Exception as e:
        raise ConfigError(f"Error reading {config_entries_path}: {e}")
    
    # Check if entries exist
    if 'data' not in config_data or 'entries' not in config_data['data']:
        raise ConfigError("Error: Invalid format in config_entries file")
    
    entries = config_data['data']['entries']
    new_entries = []
    
    # First pass: Find ZHA and MQTT entries
    for entry in entries:
        if entry.get('domain') == 'zha':
            zha_entry_id = entry.get('entry_id')
            print(f"Found ZHA configuration with entry_id: {zha_entry_id}, will remove it")
            continue  # Skip this entry (remove it)
        elif entry.get('domain') == 'mqtt':
            mqtt_entry_id = entry.get('entry_id')
            print(f"Found MQTT configuration with entry_id: {mqtt_entry_id}")
        new_entries.append(entry)
    
    # If no MQTT configuration exists, add one
    if not mqtt_entry_id:
        # Generate a new entry_id
        # Format similar to: 01JWJ3XGKNCN35YTRYE0W9MCQE
        mqtt_entry_id = f"01{uuid.uuid4().hex.upper()[:24]}"
        now = datetime.now(timezone.utc).isoformat()
        mqtt_entry = {
            "created_at": now,
            "data": {
                "broker": "localhost",
                "password": "thirdreality",
                "port": 1883,
                "username": "thirdreality"
            },
            "disabled_by": None,
            "discovery_keys": {},
            "domain": "mqtt",
            "entry_id": mqtt_entry_id,
            "minor_version": 2,
            "modified_at": now,
            "options": {},
            "pref_disable_new_entities": False,
            "pref_disable_polling": False,
            "source": "user",
            "subentries": [],
            "title": "localhost",
            "unique_id": None,
            "version": 1
        }
        new_entries.append(mqtt_entry)
        print(f"Added MQTT configuration with entry_id: {mqtt_entry_id}")
    
    # Update entries
    config_data['data']['entries'] = new_entries
    
    # Write back to file
    try:
        with open(config_entries_path, 'w') as f:
            json.dump(config_data, f, indent=2)
        print(f"Updated {config_entries_path}")
    except Exception as e:
        raise ConfigError(f"Error writing to {config_entries_path}: {e}")
    
    return zha_entry_id, mqtt_entry_id


def update_device_registry(zha_entry_id, mqtt_entry_id):
    """Update device registry to remove ZHA devices and add Zigbee2MQTT Bridge if needed"""
    device_registry_path = os.path.join(BASE_PATH, "homeassistant/.storage/core.device_registry")
    
    if not os.path.exists(device_registry_path):
        raise ConfigError(f"Error: {device_registry_path} does not exist")
    
    try:
        with open(device_registry_path, 'r') as f:
            device_data = json.load(f)
    except Exception as e:
        raise ConfigError(f"Error reading {device_registry_path}: {e}")
    
    # Check if devices exist
    if 'data' not in device_data or 'devices' not in device_data['data']:
        raise ConfigError("Error: Invalid format in device_registry file")
    
    devices = device_data['data']['devices']
    new_devices = []
    
    # Remove devices linked to ZHA entry_id if it exists
    has_z2m_bridge = False
    for device in devices:
        # Check if this is the Zigbee2MQTT Bridge
        if device.get('name') == "Zigbee2MQTT Bridge":
            has_z2m_bridge = True
            print("Zigbee2MQTT Bridge already exists in registry")
            # Update the bridge to use the current MQTT entry_id
            if device.get('config_entries') and mqtt_entry_id not in device.get('config_entries', []):
                device['config_entries'] = [mqtt_entry_id]
                device['config_entries_subentries'] = {mqtt_entry_id: [None]}
                device['primary_config_entry'] = mqtt_entry_id
                device['modified_at'] = datetime.now(timezone.utc).isoformat()
                print("Updated Zigbee2MQTT Bridge with current MQTT entry_id")
            new_devices.append(device)
            continue
            
        # Skip devices linked to ZHA if zha_entry_id exists
        if zha_entry_id and 'config_entries' in device:
            if zha_entry_id in device['config_entries']:
                print(f"Removing device linked to ZHA: [ {device.get('name', 'Unknown device')} ]")
                continue
        new_devices.append(device)
    
    # If Zigbee2MQTT Bridge doesn't exist, add it
    if not has_z2m_bridge:
        now = datetime.now(timezone.utc).isoformat()
        bridge_device = {
            "area_id": None,
            "config_entries": [mqtt_entry_id],
            "config_entries_subentries": {mqtt_entry_id: [None]},
            "configuration_url": None,
            "connections": [],
            "created_at": now,
            "disabled_by": None,
            "entry_type": None,
            "hw_version": "zigate 321",
            "id": f"{uuid.uuid4().hex}",
            "identifiers": [["mqtt", "zigbee2mqtt_bridge_0x1c784ba0ffca0000"]],
            "labels": [],
            "manufacturer": "Zigbee2MQTT",
            "model": "Bridge",
            "model_id": None,
            "modified_at": now,
            "name_by_user": None,
            "name": "Zigbee2MQTT Bridge",
            "primary_config_entry": mqtt_entry_id,
            "serial_number": None,
            "sw_version": "2.3.0",
            "via_device_id": None
        }
        new_devices.append(bridge_device)
        print("Added Zigbee2MQTT Bridge device")
    
    # Update devices
    device_data['data']['devices'] = new_devices
    
    # Write back to file
    try:
        with open(device_registry_path, 'w') as f:
            json.dump(device_data, f, indent=2)
        print(f"Updated {device_registry_path}")
    except Exception as e:
        raise ConfigError(f"Error writing to {device_registry_path}: {e}")

def update_entity_registry():
    """Update entity registry to remove ZHA platform entities"""
    entity_registry_path = os.path.join(BASE_PATH, "homeassistant/.storage/core.entity_registry")
    
    if not os.path.exists(entity_registry_path):
        print(f"Warning: {entity_registry_path} does not exist, skipping entity registry update")
        return
    
    try:
        with open(entity_registry_path, 'r') as f:
            entity_data = json.load(f)
    except Exception as e:
        print(f"Warning: Error reading {entity_registry_path}: {e}")
        return
    
    # Check if entities exist
    if 'data' not in entity_data or 'entities' not in entity_data['data']:
        print("Warning: Invalid format in entity_registry file, skipping entity registry update")
        return
    
    entities = entity_data['data']['entities']
    new_entities = []
    removed_count = 0
    
    # Remove ZHA platform entities
    for entity in entities:
        if entity.get('platform') == 'zha':
            removed_count += 1
            continue
        new_entities.append(entity)
    
    if removed_count > 0:
        print(f"Removed {removed_count} ZHA platform entities from entity registry")
    
    # Update entities
    entity_data['data']['entities'] = new_entities
    
    # Write back to file
    try:
        with open(entity_registry_path, 'w') as f:
            json.dump(entity_data, f, indent=2)
        print(f"Updated {entity_registry_path}")
    except Exception as e:
        print(f"Warning: Error writing to {entity_registry_path}: {e}")


def start_and_enable_services():
    """Start and enable zigbee2mqtt and mosquitto services if they exist"""
    services = ['mosquitto.service', 'zigbee2mqtt.service']
    
    for service in services:
        # Check if service exists
        result = subprocess.run(['systemctl', 'is-enabled', service], 
                               stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
        
        if result.returncode == 0 or 'disabled' in result.stdout:
            # Service exists, enable and start it
            print(f"Enabling {service}...")
            subprocess.run(['systemctl', 'enable', service], 
                          stdout=subprocess.PIPE, stderr=subprocess.PIPE)
            
            print(f"Starting {service}...")
            subprocess.run(['systemctl', 'start', service], 
                          stdout=subprocess.PIPE, stderr=subprocess.PIPE)
        else:
            print(f"{service} not found, skipping")


def main():
    need_restart = False
    
    try:
        # Step 1: Check if required services exist
        check_required_services()
        
        # Step 2: Check and stop Home Assistant service if running
        need_restart = check_and_stop_ha_service()
        
        # Step 3: Update config entries to remove ZHA and ensure MQTT is configured
        zha_entry_id, mqtt_entry_id = update_config_entries()
        
        # Step 4: Update device registry to remove ZHA devices and add Zigbee2MQTT Bridge
        update_device_registry(zha_entry_id, mqtt_entry_id)
        
        # Step 5: Update entity registry to remove ZHA platform entities
        update_entity_registry()
        
        # Step 6: Start and enable zigbee2mqtt and mosquitto services
        start_and_enable_services()
        
        print("Zigbee2MQTT integration setup completed successfully")
        
    except ConfigError as e:
        print(f"Error: {e}")
        return 1
    except Exception as e:
        print(f"Unexpected error: {e}")
        return 1
    finally:
        # Restart Home Assistant if it was running before
        if need_restart:
            print("Restarting home-assistant.service...")
            subprocess.run(['systemctl', 'start', 'home-assistant.service'], 
                          stdout=subprocess.PIPE, stderr=subprocess.PIPE)
    
    return 0


if __name__ == "__main__":
    sys.exit(main())
