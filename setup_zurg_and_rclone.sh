#!/bin/bash

# setup_zurg_and_rclone.sh

# Include common functions
source ./common_functions.sh

# Check for root privileges
if [[ $EUID -ne 0 ]]; then
    echo "Error: This script must be run with administrative privileges. Please run with sudo."
    exit 1
fi

echo "Running setup_zurg_and_rclone.sh..."

echo "Setting up Zurg and Rclone..."

# Get PUID and PGID from the user who invoked sudo
PUID=$(id -u "$SUDO_USER")
PGID=$(id -g "$SUDO_USER")

# Export PUID, PGID, and TZ to be used in docker-compose.yml
export PUID PGID
export TZ=$(cat /etc/timezone 2>/dev/null || echo "UTC")

# Function to check if Zurg and Rclone containers are running
are_containers_running() {
    docker ps --filter "name=zurg" --filter "name=rclone" | grep -q "zurg"
}

# Check if Zurg and Rclone are already installed
if are_containers_running; then
    echo "Zurg and Rclone are already running. Skipping installation."
    exit 0
fi

# Prompt for Real-Debrid API Key
read -p "Enter your Real-Debrid API Key: " REAL_DEBRID_API_KEY

if [ -z "$REAL_DEBRID_API_KEY" ]; then
    echo "Error: Real-Debrid API Key cannot be empty."
    exit 1
fi

# Save the API key for future reference (ensure permissions are set to prevent unauthorized access)
echo "$REAL_DEBRID_API_KEY" > real_debrid_api_key.txt
chmod 600 real_debrid_api_key.txt
chown "$SUDO_USER":"$SUDO_USER" real_debrid_api_key.txt

# Correct Docker image
ZURG_IMAGE="ghcr.io/debridmediamanager/zurg-testing:latest"

# Handle /mnt/zurg directory

# Check if /mnt/zurg is mounted and accessible
if mountpoint -q /mnt/zurg; then
    echo "/mnt/zurg is already mounted."
elif mount | grep "/mnt/zurg" &> /dev/null; then
    echo "/mnt/zurg is mounted but not accessible. Attempting to unmount..."
    sudo umount -l /mnt/zurg
    if [[ $? -ne 0 ]]; then
        echo "Error: Failed to unmount /mnt/zurg."
        exit 1
    fi
    echo "Successfully unmounted /mnt/zurg."
else
    echo "/mnt/zurg is not mounted."
fi

# Ensure /mnt/zurg directory exists and is not a mount point
if [ -d "/mnt/zurg" ]; then
    # Verify if it's a mount point
    if mountpoint -q /mnt/zurg; then
        echo "/mnt/zurg is still a mount point after unmounting. Exiting to prevent conflicts."
        exit 1
    else
        echo "/mnt/zurg directory exists and is accessible."
    fi
else
    # Create /mnt/zurg directory
    echo "Creating /mnt/zurg directory..."
    sudo mkdir -p /mnt/zurg
    if [[ $? -ne 0 ]]; then
        echo "Error: Failed to create /mnt/zurg directory."
        exit 1
    fi
fi

# Ensure proper ownership and permissions
sudo chown -R "$PUID:$PGID" /mnt/zurg
sudo chmod -R 755 /mnt/zurg

# Navigate to the zurg directory
if [ ! -d "zurg" ]; then
    mkdir zurg
fi

cd zurg

# Remove existing docker-compose.yml if it exists to avoid conflicts
if [ -f "docker-compose.yml" ]; then
    echo "Removing existing docker-compose.yml..."
    rm docker-compose.yml
    echo "Existing docker-compose.yml removed."
fi

# Create the docker-compose.yml file without the version field
cat <<EOF > docker-compose.yml
services:
  zurg:
    image: $ZURG_IMAGE
    container_name: zurg
    restart: unless-stopped
    environment:
      - PUID=$PUID
      - PGID=$PGID
      - TZ=$TZ
      - RD_API_KEY=$REAL_DEBRID_API_KEY
    volumes:
      - /mnt/zurg:/data
    networks:
      - zurg_network

  rclone:
    image: rclone/rclone:latest
    container_name: rclone
    restart: unless-stopped
    command: "mount zurg: /data --allow-other --allow-non-empty --dir-cache-time 10s --vfs-cache-mode full"
    cap_add:
      - SYS_ADMIN
    devices:
      - /dev/fuse
    security_opt:
      - apparmor:unconfined
    environment:
      - PUID=$PUID
      - PGID=$PGID
      - TZ=$TZ
    volumes:
      - /mnt/zurg:/mnt/zurg
      - ./rclone:/config
    networks:
      - zurg_network

networks:
  zurg_network:
    driver: bridge
EOF

if [ $? -ne 0 ]; then
    echo "Error: Failed to create docker-compose.yml."
    exit 1
fi

echo "docker-compose.yml created successfully."

# Ensure the rclone config directory exists
if [ ! -d "rclone" ]; then
    mkdir rclone
    echo "Created rclone configuration directory."
fi

# Check if Docker is running
if ! systemctl is-active --quiet docker; then
    echo "Docker service is not running. Starting Docker..."
    sudo systemctl start docker
    if [[ $? -ne 0 ]]; then
        echo "Error: Failed to start Docker service."
        exit 1
    fi
fi

echo "Docker service is running."

echo "Bringing up Zurg and Rclone Docker containers..."

# Bring up the containers
docker-compose up -d

if [ $? -ne 0 ]; then
    echo "Error: Failed to start Zurg and Rclone containers."
    exit 1
fi

echo "Zurg and Rclone containers are up and running."
