#!/bin/bash

# Function to flash zigbee firmware with service management
flash_zigbee() {
    echo "upgrade zigbee firmware ..."
    
    # Check and stop services if they are running
    local services_to_manage=("home-assistant.service" "zigbee2mqtt.service")
    local stopped_services=()
    
    for service in "${services_to_manage[@]}"; do
        if systemctl is-active --quiet "$service"; then
            echo "Stopping $service before flashing..."
            systemctl stop "$service"
            stopped_services+=("$service")
        fi
    done
    
    # Execute flash command
    cd /usr/lib/firmware/bl706/
    ./bl706_func.sh flash zigbee
    
    # Restart previously stopped services
    for service in "${stopped_services[@]}"; do
        echo "Restarting $service after flashing..."
        systemctl start "$service"
    done
}

# Function to flash thread firmware with service management
flash_thread() {
    echo "upgrade thread firmware ..."
    
    # Check and stop otbr-agent.service if it is running
    local service_to_manage="otbr-agent.service"
    local was_running=false
    
    if systemctl is-active --quiet "$service_to_manage"; then
        echo "Stopping $service_to_manage before flashing..."
        systemctl stop "$service_to_manage"
        was_running=true
    fi
    
    # Execute flash command
    cd /usr/lib/firmware/bl706/
    ./bl706_func.sh flash thread
    
    # Restart otbr-agent.service if it was running before
    if [ "$was_running" = true ]; then
        echo "Restarting $service_to_manage after flashing..."
        systemctl start "$service_to_manage"
    fi
}

if [ -e "/usr/local/bin/supervisor" ]; then
    /usr/local/bin/supervisor led sys_device_pairing
fi

# Call zigbee flash function
flash_zigbee

# Call thread flash function
flash_thread

if [ -e "/usr/local/bin/supervisor" ]; then
    /usr/local/bin/supervisor led sys_event_off
fi
