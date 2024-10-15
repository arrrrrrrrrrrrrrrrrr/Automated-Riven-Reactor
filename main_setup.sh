#!/bin/bash

# main_setup.sh

# Include common functions
source ./common_functions.sh

# Check for root privileges
if [[ $EUID -ne 0 ]]; then
    echo "Error: This script must be run with administrative privileges. Please run with sudo."
    exit 1
fi

# Make scripts executable
chmod +x install_docker.sh
chmod +x setup_zurg_and_rclone.sh
chmod +x install_plex.sh
chmod +x create_directories.sh
chmod +x create_riven_compose.sh
chmod +x common_functions.sh
chmod +x create_troubleshooting_file.sh
chmod +x onboarding.sh

# Run scripts with error checking
echo "Running install_docker.sh..."
./install_docker.sh
if [ $? -ne 0 ]; then
    echo "Error: install_docker.sh failed."
    exit 1
fi

echo "Running setup_zurg_and_rclone.sh..."
./setup_zurg_and_rclone.sh
if [ $? -ne 0 ]; then
    echo "Error: setup_zurg_and_rclone.sh failed."
    exit 1
fi

echo "Running install_plex.sh..."
./install_plex.sh
if [ $? -ne 0 ]; then
    echo "Error: install_plex.sh failed."
    exit 1
fi

echo "Running create_directories.sh..."
./create_directories.sh
if [ $? -ne 0 ]; then
    echo "Error: create_directories.sh failed."
    exit 1
fi

echo "Running create_riven_compose.sh..."
./create_riven_compose.sh
if [ $? -ne 0 ]; then
    echo "Error: create_riven_compose.sh failed."
    exit 1
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
        docker stop $CONTAINERS
        docker rm $CONTAINERS
    fi
done

# Now bring up the containers
sudo docker-compose up -d
if [ $? -ne 0 ]; then
    echo "Error: docker-compose up failed."
    exit 1
fi


# Create troubleshooting file
./create_troubleshooting_file.sh

echo "Setup complete! All services are up and running."

# Get the local IP address
if [ -f local_ip.txt ]; then
    local_ip=$(retrieve_saved_ip)
else
    # If no IP is saved, run get_local_ip to generate one
    get_local_ip
    local_ip=$(retrieve_saved_ip)
fi

echo "SSSSSS   U     U   CCCCC   CCCCC   EEEEE  SSSSSS  SSSSSS"
echo "S        U     U  C       C        E      S       S"
echo "SSSSSS   U     U  C       C        EEEEE   SSSSS  SSSSSS"
echo "     S   U     U  C       C        E           S       S"
echo "SSSSSS   UUUUUUU   CCCCC   CCCCC   EEEEE  SSSSSS  SSSSSS"

# Ask the user if they want to go through onboarding or minimum config
echo "We can also finish the onboarding for you!"
read -p "Do you want to me to configure onboarding for you ? It will configure Riven just enough to start, you can configure the rest later in Riven Settings (yes/no): " CONFIG_CHOICE

if [ "$CONFIG_CHOICE" == "yes" ]; then
    ./onboarding.sh
    echo "Continue to http://$local_ip:3000 to start Riven"

else
    echo "Continue to http://$local_ip:3000 to start Riven onboarding"
    echo "If you are Windows users, if you have trouble opening Riven onboarding from http://$local_ip:3000, please run '.\windows_proxy.bat' first!"
    exit
fi



