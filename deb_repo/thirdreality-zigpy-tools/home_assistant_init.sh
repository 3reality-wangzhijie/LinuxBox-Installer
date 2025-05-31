#!/bin/bash
# Script for homeassistant-core-matter

CONFIG_DIR="/var/lib/homeassistant"
VENV_PATH="/srv/homeassistant/bin/activate"
ZHA_CONF="${CONFIG_DIR}/zha.conf"

# Function to execute zigpy command and retrieve IEEE address
function get_zigpy_ieee_from_device {
    if [ ! -f "$ZHA_CONF" ]; then
        # Execute zigpy command and save its output
        if [[ -e "/dev/ttyAML3" ]]; then
            # This is HubV3
            # First try ZiGate radio type
            if zigpy radio zigate /dev/ttyAML3 info > "$ZHA_CONF" 2>&1; then
                echo "ZiGate radio detected. Output saved to $ZHA_CONF"
                echo "Radio Type: zigate" >> "$ZHA_CONF"
            # If ZiGate fails, try EZSP radio type
            elif zigpy radio ezsp /dev/ttyAML3 info > "$ZHA_CONF" 2>&1; then
                echo "EZSP radio detected. Output saved to $ZHA_CONF"
                echo "Radio Type: ezsp" >> "$ZHA_CONF"
            else
                echo "Error: Failed to detect any supported radio type"
                rm -rf "$ZHA_CONF" > /dev/null 2>&1 || true
                return 1
            fi
        else
            echo "Error: Device /dev/ttyAML3 not found"
            rm -rf "$ZHA_CONF"
            return 1
        fi
    fi
}

# Function to update IEEE addresses in the device registry
function enable_zha_for_home_assistant {
    if [[  -e "/srv/homeassistant/bin/home_assistant_zha_enable.py" ]]; then
        [[ ! -f "$DEVICE_REGISTRY" ]] && {
            echo "Error: Core device registry $DEVICE_REGISTRY does not exist."
            exit 1
        }

        if [ ! -f "$ZHA_CONF" ]; then        
            echo "Error: ZIGBEE config $ZHA_CONF does not exist."
            exit 1
        fi

        /srv/homeassistant/bin/home_assistant_zha_enable.py
    fi
}

# Check and activate the virtual environment
[[ ! -f "$VENV_PATH" ]] && {
    echo "Error: Virtual environment not found at $VENV_PATH"
    exit 1
}

source "$VENV_PATH"

get_zigpy_ieee_from_device
enable_zha_for_home_assistant

deactivate

