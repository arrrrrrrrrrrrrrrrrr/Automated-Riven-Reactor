#!/bin/bash

# Function to get the local IP address
get_local_ip() {
    # Check if HOST_IP.txt exists
    if [ -f HOST_IP.txt ]; then
        local_ip=$(cat HOST_IP.txt)
        echo "Using saved IP address: $local_ip"
    else
        # Initialize variable
        local_ip=""
        is_wsl=false

        # Detect if running under WSL
        if grep -qEi "(Microsoft|WSL)" /proc/version &> /dev/null ; then
            is_wsl=true
        fi

        if [ "$is_wsl" = true ]; then
            echo "It looks like you're running under WSL."
            echo "Please enter your Windows host machine's IP address."
            read -p "Enter your Windows host IP address: " user_input
            local_ip=${user_input:-localhost}
            echo "Windows host IP set to: $local_ip"
        else
            # Existing code to detect local IP
            # Get list of network interfaces, exclude docker, lo, and other virtual interfaces
            interfaces=$(ip -o -4 addr list | awk '{print $2}' | grep -vE 'docker|br-|veth|lo')

            for iface in $interfaces; do
                # Get the IP address associated with the interface
                ip=$(ip -o -4 addr list $iface | awk '{print $4}' | cut -d/ -f1)
                if [[ $ip != "127.0.0.1" ]]; then
                    local_ip=$ip
                    break
                fi
            done

            if [[ -z "$local_ip" ]]; then
                # Fallback to hostname -I (Linux)
                local_ip=$(hostname -I 2>/dev/null | awk '{print $1}')
            fi

            if [[ -z "$local_ip" ]]; then
                # Fallback to ipconfig getifaddr en0 (macOS)
                local_ip=$(ipconfig getifaddr en0 2>/dev/null)
            fi

            if [[ -z "$local_ip" ]]; then
                # Fallback to ifconfig (Unix/macOS)
                local_ip=$(ifconfig 2>/dev/null | grep -E 'inet ' | grep -v '127.0.0.1' | awk '{ print $2 }' | head -n 1)
            fi

            if [[ -z "$local_ip" ]]; then
                echo "Unable to automatically detect your local IP address."
                read -p "Please enter your machine's IP address (default is 'localhost'): " user_input
                local_ip=${user_input:-localhost}
            else
                echo "Local IP detected: $local_ip"
            fi
        fi

        # Save the IP address to HOST_IP.txt
        echo "$local_ip" > HOST_IP.txt
    fi
}
