#!/bin/bash

# Function to detect the platform (Linux, WSL, or Windows)
detect_platform() {
    if grep -qEi "(Microsoft|WSL)" /proc/version &> /dev/null; then
        echo "wsl"
    elif [[ "$OSTYPE" == "linux-gnu"* ]]; then
        echo "linux"
    elif [[ "$OSTYPE" == "cygwin" || "$OSTYPE" == "msys" || "$OSTYPE" == "win32" ]]; then
        echo "windows"
    else
        echo "unknown"
    fi
}

# Function to check if an IP address is valid and not in restricted ranges
is_valid_ip() {
    local ip="$1"
    if [[ -n "$ip" && "$ip" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ && ! "$ip" =~ ^172\.|^127\.|^0\.0\.0\.0$ && "$ip" != "localhost" ]]; then
        return 0  # valid IP
    else
        return 1  # invalid IP
    fi
}

# Function to get the local IP address (now prompts user for manual input)
get_local_ip() {
    manual_ip_prompt
}

# Function to prompt the user for manual IP input and retry until valid
manual_ip_prompt() {
    while true; do
        read -p "Please enter a valid machine IP manually(usullay start with 192.): " manual_ip
        if is_valid_ip "$manual_ip"; then
            local_ip="$manual_ip"
            echo "$local_ip" > local_ip.txt
            break
        else
            echo "Error: Invalid IP entered. The IP cannot be from ranges 127.x.x.x, 172.x.x.x, 0.0.0.0, or localhost. Please try again."
        fi
    done
}

# Function to retrieve saved IP from file
retrieve_saved_ip() {
    if [ -f local_ip.txt ]; then
        cat local_ip.txt
    else
        echo "Error: No saved IP found. Run get_local_ip to generate one."
        exit 1
    fi
}
