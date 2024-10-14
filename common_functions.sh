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

# Function to get the local IP address based on the detected platform
get_local_ip() {
    platform=$(detect_platform)
    
    case "$platform" in
        "linux")
            # For Linux (Debian/Ubuntu/CentOS/Arch)
            local_ip=$(ip route get 1 | awk '{print $NF; exit}')
            if [ -z "$local_ip" ]; then
                local_ip=$(hostname -I | awk '{print $1}')
            fi
            ;;
        "wsl")
            # For WSL (Windows Subsystem for Linux)
            local_ip=$(cat /etc/resolv.conf | grep nameserver | awk '{print $2}')
            ;;
        "windows")
            # For native Windows
            local_ip=$(powershell.exe -Command "(Get-NetIPAddress -AddressFamily IPv4).IPAddress" | sed 's/\r$//')
            ;;
        *)
            echo "Error: Unsupported platform. Attempting manual IP entry."
            manual_ip_prompt
            return
            ;;
    esac

    # If the retrieved IP is invalid or restricted, prompt for manual input
    if ! is_valid_ip "$local_ip"; then
        echo "Warning: Detected IP ($local_ip) is invalid or in a restricted range (172.x.x.x, 127.x.x.x, 0.0.0.0, localhost)."
        manual_ip_prompt
    fi

    # Save the valid IP to a file for sharing
    echo "$local_ip" > local_ip.txt
}

# Function to prompt the user for manual IP input and retry until valid
manual_ip_prompt() {
    while true; do
        read -p "Please enter a valid external IP manually: " manual_ip
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
