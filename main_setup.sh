#!/bin/bash

# Exit on any error
set -e

# Include common functions
source ./common_functions.sh

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Print with color
print_color() {
    local color=$1
    local message=$2
    echo -e "${color}${message}${NC}"
}

# Check if script is run as root
if [[ $EUID -ne 0 ]]; then
    print_color "$RED" "Error: This script must be run as root"
    exit 1
fi

# Function to get actual user even when running with sudo
get_actual_user() {
    if [ -n "$SUDO_USER" ]; then
        echo "$SUDO_USER"
    else
        whoami
    fi
}

# Get the actual user who invoked sudo
ACTUAL_USER=$(get_actual_user)

# Manual IP Configuration
print_color "$GREEN" "Network Configuration"
print_color "$GREEN" "===================="
echo
print_color "$GREEN" "Valid IP Format Examples:"
print_color "$GREEN" "1. 192.168.1.xxx"
print_color "$GREEN" "2. 10.0.0.xxx"
print_color "$GREEN" "Note: IP cannot be from ranges 127.x.x.x, 172.x.x.x, 0.0.0.0, or localhost"
echo

while true; do
    read -p "$(print_color "$YELLOW" "Please enter your machine's IP address: ")" manual_ip
    if is_valid_ip "$manual_ip"; then
        if save_ip "$manual_ip"; then
            print_color "$GREEN" "IP Configuration successful: $manual_ip"
            echo
            break
        else
            print_color "$RED" "Error: Failed to save IP address."
            exit 1
        fi
    else
        print_color "$RED" "Invalid IP format or restricted IP range. Please try again."
    fi
done

# Function to prompt for Docker installation mode
prompt_docker_mode() {
    while true; do
        echo
        print_color "$GREEN" "Docker Installation Mode Selection"
        echo "=================================="
        echo
        print_color "$YELLOW" "1) Normal Docker Installation"
        echo "   - Requires root privileges"
        echo "   - Full feature set"
        echo "   - Better performance"
        echo "   - Recommended for most users"
        echo
        print_color "$YELLOW" "2) Rootless Docker Installation"
        echo "   - Enhanced security"
        echo "   - No root privileges required after setup"
        echo "   - Some features limited"
        echo "   - Better for development environments"
        echo
        read -p "Please select installation mode (1/2): " choice
        case $choice in
            1)
                echo "Selected: Normal Docker Installation"
                return 0
                ;;
            2)
                echo "Selected: Rootless Docker Installation"
                return 1
                ;;
            *)
                print_color "$RED" "Invalid choice. Please select 1 or 2."
                ;;
        esac
    done
}

# Function to handle Docker reinstallation
handle_docker_reinstall() {
    local actual_user=$1
    
    if command -v docker >/dev/null 2>&1; then
        # Check if it's rootless Docker
        if systemctl --user -q is-active docker 2>/dev/null; then
            print_color "$YELLOW" "Stopping existing rootless Docker service..."
            sudo -u "$actual_user" systemctl --user stop docker
            sudo -u "$actual_user" rm -f "/home/$actual_user/bin/dockerd"
        elif systemctl -q is-active docker 2>/dev/null; then
            print_color "$YELLOW" "Stopping existing Docker service..."
            systemctl stop docker
        fi
    fi
}

# Function to run remaining setup steps
run_remaining_setup() {
    print_color "$GREEN" "Running remaining setup scripts..."
    
    echo "Running create_directories.sh..."
    if ! ./create_directories.sh; then
        print_color "$RED" "Error: create_directories.sh failed."
        return 1
    fi

    echo "Running setup_zurg_and_rclone.sh..."
    if ! ./setup_zurg_and_rclone.sh; then
        print_color "$RED" "Error: setup_zurg_and_rclone.sh failed."
        return 1
    fi

    echo "Running install_plex.sh..."
    if ! ./install_plex.sh; then
        print_color "$RED" "Error: install_plex.sh failed."
        return 1
    fi

    echo "Running create_riven_compose.sh..."
    if ! ./create_riven_compose.sh; then
        print_color "$RED" "Error: create_riven_compose.sh failed."
        return 1
    fi

    echo "Bringing up Riven Docker containers..."

    # Stop and remove existing containers based on image
    echo "Checking for existing Riven containers by image..."
    IMAGES=("spoked/riven-frontend:latest" "spoked/riven:latest" "postgres:16.3-alpine3.20")

    for IMAGE in "${IMAGES[@]}"; do
        CONTAINERS=$(docker ps -a -q --filter ancestor="$IMAGE")
        if [ -n "$CONTAINERS" ]; then
            echo "Found containers running image $IMAGE"
            echo "Stopping and removing containers..."
            docker stop $CONTAINERS || true
            docker rm $CONTAINERS || true
        fi
    done

    # Now bring up the containers
    if ! (cd ./riven && docker compose up -d); then
        print_color "$RED" "Error: docker compose up failed."
        return 1
    fi

    # Create troubleshooting file
    ./create_troubleshooting_file.sh

    print_color "$GREEN" "Setup complete! All services are up and running."

    # Get the local IP address
    if [ -f local_ip.txt ]; then
        local_ip=$(retrieve_saved_ip)
    else
        # If no IP is saved, run get_local_ip to generate one
        if ! get_local_ip; then
            print_color "$RED" "Error: Failed to get local IP address."
            return 1
        fi
        local_ip=$(retrieve_saved_ip)
    fi

    echo -e "${GREEN}SSSSSS   U     U   CCCCC   CCCCC   EEEEE  SSSSSS  SSSSSS${NC}"
    echo -e "${GREEN}S        U     U  C       C        E      S       S${NC}"
    echo -e "${GREEN}SSSSSS   U     U  C       C        EEEEE   SSSSS  SSSSSS${NC}"
    echo -e "${GREEN}     S   U     U  C       C        E           S       S${NC}"
    echo -e "${GREEN}SSSSSS   UUUUUUU   CCCCC   CCCCC   EEEEE  SSSSSS  SSSSSS${NC}"

    # Ask the user if they want to go through onboarding or minimum config
    echo "We can also finish the onboarding for you!"
    read -p "Do you want to me to configure onboarding for you ? It will configure Riven just enough to start, you can configure the rest later in Riven Settings (yes/no): " CONFIG_CHOICE

    if [[ "$CONFIG_CHOICE" =~ ^[Yy][Ee]?[Ss]?$ ]]; then
        if ! ./onboarding.sh; then
            print_color "$RED" "Error: Onboarding failed."
            return 1
        fi
        echo "Continue to http://$local_ip:3000 to start Riven, it takes about 20 seconds to show up"
    else
        echo "Continue to http://$local_ip:3000 to start Riven onboarding"
        echo "If you are Windows users, if you have trouble opening Riven onboarding from http://$local_ip:3000, please run '.\windows_proxy.bat' first!"
    fi
    return 0
}

# Make scripts executable
chmod +x install_docker.sh
chmod +x setup_zurg_and_rclone.sh
chmod +x install_plex.sh
chmod +x create_directories.sh
chmod +x create_riven_compose.sh
chmod +x common_functions.sh
chmod +x create_troubleshooting_file.sh
chmod +x onboarding.sh

# Main setup process
print_color "$GREEN" "Starting main setup process..."

# Check if Docker is already installed and handle reinstallation
if command -v docker >/dev/null 2>&1; then
    print_color "$YELLOW" "Docker is already installed. Do you want to reinstall/update it? (y/n)"
    read -r response
    if [[ "$response" == "y" ]]; then
        handle_docker_reinstall "$ACTUAL_USER" || {
            print_color "$RED" "Error: Failed to handle Docker reinstallation."
            exit 1
        }
        
        # Install Docker based on selected mode
        if prompt_docker_mode; then
            print_color "$GREEN" "Installing Docker in normal mode..."
            if ! ./install_docker.sh normal; then
                print_color "$RED" "Error: Docker installation failed."
                exit 1
            fi
        else
            print_color "$GREEN" "Installing Docker in rootless mode for user: $ACTUAL_USER..."
            if ! ./install_docker.sh rootless "$ACTUAL_USER"; then
                print_color "$RED" "Error: Docker installation failed."
                exit 1
            fi
        fi
    fi
    
    # Run remaining setup steps
    if ! run_remaining_setup; then
        print_color "$RED" "Error: Setup failed."
        exit 1
    fi
else
    # Fresh Docker installation
    if prompt_docker_mode; then
        print_color "$GREEN" "Installing Docker in normal mode..."
        if ! ./install_docker.sh normal; then
            print_color "$RED" "Error: Docker installation failed."
            exit 1
        fi
    else
        print_color "$GREEN" "Installing Docker in rootless mode for user: $ACTUAL_USER..."
        if ! ./install_docker.sh rootless "$ACTUAL_USER"; then
            print_color "$RED" "Error: Docker installation failed."
            exit 1
        fi
    fi
    
    # Run remaining setup steps
    if ! run_remaining_setup; then
        print_color "$RED" "Error: Setup failed."
        exit 1
    fi
fi

print_color "$GREEN" "Setup completed successfully!"
