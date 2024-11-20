#!/bin/bash

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Function to detect the platform (Linux, WSL, or Windows)
detect_platform() {
    if grep -qEi "(Microsoft|WSL)" /proc/version &> /dev/null; then
        echo "wsl"
    elif [[ "$OSTYPE" == "linux-gnu"* ]]; then
        echo "linux"
    elif [[ "$OSTYPE" == "cygwin" || "$OSTYPE" == "msys" || "$OSTYPE" == "win32" ]]; then
        echo "windows"
    elif [[ "$OSTYPE" == "darwin"* ]]; then
        echo "darwin"
    else
        echo "unknown"
    fi
}

# Function to check if an IP address is valid and not in restricted ranges
is_valid_ip() {
    local ip="$1"
    
    # Check if IP is empty
    if [ -z "$ip" ]; then
        return 1
    fi
    
    # Check if IP is in restricted ranges
    if [[ $ip =~ ^127\. ]] || [[ $ip =~ ^172\. ]] || [[ $ip == "0.0.0.0" ]] || [[ $ip == "localhost" ]]; then
        return 1
    fi
    
    # Basic IP format validation (xxx.xxx.xxx.xxx where xxx is 1-3 digits)
    if [[ ! $ip =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]]; then
        return 1
    fi
    
    # Validate each octet
    local IFS='.'
    read -ra ADDR <<< "$ip"
    for i in "${ADDR[@]}"; do
        if [ $i -lt 0 ] || [ $i -gt 255 ]; then
            return 1
        fi
    done
    
    return 0
}

# Function to save IP to file
save_ip() {
    local ip="$1"
    echo "$ip" > local_ip.txt
    return $?
}

# Function to retrieve saved IP from file
retrieve_saved_ip() {
    if [ ! -f local_ip.txt ]; then
        return 1
    fi
    local ip=$(cat local_ip.txt)
    if [ -z "$ip" ] || ! is_valid_ip "$ip"; then
        return 1
    fi
    echo "$ip"
}

# Function to get the local IP address
get_local_ip() {
    if [[ "$OSTYPE" == "darwin"* ]]; then
        # macOS specific IP retrieval
        local_ip=$(ifconfig | grep "inet " | grep -v 127.0.0.1 | awk '{print $2}' | head -n 1)
    else
        # Linux IP retrieval
        local_ip=$(ip -4 addr show | grep -oP '(?<=inet\s)\d+(\.\d+){3}' | grep -v '127.0.0.1' | head -n 1)
    fi
    echo "$local_ip"
}

# Function to prompt the user for manual IP input and retry until valid
manual_ip_prompt() {
    echo -e "${GREEN}Local IP Configuration:${NC}"
    echo -e "${GREEN}Valid IP Format Examples:${NC}"
    echo -e "${GREEN}1. 192.168.1.xxx${NC}"
    echo -e "${GREEN}2. 10.0.0.xxx${NC}"
    echo -e "${GREEN}Note: IP cannot be from ranges 127.x.x.x, 172.x.x.x, 0.0.0.0, or localhost${NC}"
    
    while true; do
        read -p "$(echo -e "${YELLOW}Please enter your machine's IP address: ${NC}")" manual_ip
        if is_valid_ip "$manual_ip"; then
            save_ip "$manual_ip"
            break
        else
            echo -e "${RED}Error: Invalid IP entered. Please check the format examples above and try again.${NC}"
        fi
    done
}

# Function to get and store Real-Debrid API key
get_real_debrid_api_key() {
    local api_key_file="./riven/real_debrid_api_key.txt"
    
    # First try to read from existing files
    if [ -f "$api_key_file" ]; then
        local api_key=$(cat "$api_key_file")
        if [ ! -z "$api_key" ]; then
            echo "$api_key"
            return 0
        fi
    fi
    
    # If not found or empty, prompt for it
    echo -e "${GREEN}Real-Debrid API Key Configuration:${NC}"
    echo -e "${GREEN}A Real-Debrid API key is required for downloading content${NC}"
    echo -e "${GREEN}You can find your API key at: https://real-debrid.com/apitoken${NC}"
    
    local api_key=""
    while [[ -z "$api_key" ]]; do
        read -p "$(echo -e "${YELLOW}Enter your Real-Debrid API Key: ${NC}")" api_key
        if [[ -z "$api_key" ]]; then
            echo -e "${RED}Error: Real-Debrid API Key cannot be empty.${NC}"
        fi
    done
    
    # Store the API key
    if ! echo "$api_key" > "$api_key_file"; then
        echo -e "${YELLOW}Warning: Failed to store API key for future use.${NC}" >&2
    fi
    
    echo "$api_key"
    return 0
}

# Function to check package manager
check_package_manager() {
    if [[ "$OSTYPE" == "darwin"* ]]; then
        if ! command -v brew &> /dev/null; then
            echo "Homebrew is not installed. Please install Homebrew first (https://brew.sh/)"
            exit 1
        fi
        package_manager="brew"
    else
        if ! command -v apt-get &> /dev/null; then
            echo "apt-get is not installed. Please install apt-get first"
            exit 1
        fi
        package_manager="apt-get"
    fi
}
