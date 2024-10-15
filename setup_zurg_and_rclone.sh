#!/bin/bash

# setup_zurg_and_rclone.sh

# Include common functions
if [ ! -f "./common_functions.sh" ]; then
    echo "Error: common_functions.sh not found in the current directory."
    exit 1
fi
source ./common_functions.sh

# Function to detect the operating system
detect_os() {
    if [[ -e /etc/os-release ]]; then
        . /etc/os-release
        echo "$ID"
    else
        echo "unknown"
    fi
}

# Detect OS
OS_NAME=$(detect_os)

# Check for root privileges
if [[ $EUID -ne 0 ]]; then
    echo "Error: This script must be run with administrative privileges. Please run with sudo."
    exit 1
fi

# Ensure SUDO_USER is set
if [ -z "$SUDO_USER" ]; then
    echo "Error: SUDO_USER is not set. Please run the script using sudo."
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

# Function to check if both Zurg and Rclone containers are running
are_containers_running() {
    local zurg_running rclone_running
    zurg_running=$(docker ps --filter "name=zurg" --filter "status=running" -q)
    rclone_running=$(docker ps --filter "name=rclone" --filter "status=running" -q)
    if [[ -n "$zurg_running" && -n "$rclone_running" ]]; then
        return 0
    else
        return 1
    fi
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

# Clone zurg-testing repository if 'zurg' directory doesn't exist
if [ ! -d "zurg" ]; then
    git clone https://github.com/debridmediamanager/zurg-testing.git zurg
    if [ $? -ne 0 ]; then
        echo "Error: Failed to clone zurg-testing repository."
        exit 1
    fi
fi

# Correct Docker image
ZURG_IMAGE="ghcr.io/debridmediamanager/zurg-testing:latest"

# Use yq to modify YAML file (install if not present)
if ! command -v yq &> /dev/null; then
    echo "Installing yq..."
    case "$OS_NAME" in
        ubuntu|debian)
            apt-get update && apt-get install -y wget
            wget -q https://github.com/mikefarah/yq/releases/download/v4.35.1/yq_linux_amd64 -O /usr/local/bin/yq
            chmod +x /usr/local/bin/yq
            ;;
        arch|manjaro)
            pacman -Sy --noconfirm yq
            ;;
        centos|fedora|rhel)
            wget -q https://github.com/mikefarah/yq/releases/download/v4.35.1/yq_linux_amd64 -O /usr/local/bin/yq
            chmod +x /usr/local/bin/yq
            ;;
        *)
            echo "Your OS is not directly supported by this script."
            echo "Attempting to install yq by downloading the binary."
            wget -q https://github.com/mikefarah/yq/releases/download/v4.35.1/yq_linux_amd64 -O /usr/local/bin/yq
            chmod +x /usr/local/bin/yq
            ;;
    esac
    # Verify installation
    if ! command -v yq &> /dev/null; then
        echo "Error: Failed to install yq."
        exit 1
    fi
fi

# Update the token in config.yml using yq
CONFIG_FILE="./zurg/config.yml"
if [ ! -f "$CONFIG_FILE" ]; then
    echo "Error: $CONFIG_FILE does not exist."
    exit 1
fi

yq eval ".token = \"$REAL_DEBRID_API_KEY\"" -i "$CONFIG_FILE"

# Check if /mnt/zurg is mounted and accessible
if mountpoint -q /mnt/zurg; then
    echo "/mnt/zurg is already mounted."
elif mount | grep "/mnt/zurg" &> /dev/null; then
    echo "/mnt/zurg is mounted but not accessible. Attempting to unmount..."
    umount -l /mnt/zurg
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
    mkdir -p /mnt/zurg
    if [[ $? -ne 0 ]]; then
        echo "Error: Failed to create /mnt/zurg directory."
        exit 1
    fi
fi

# Ensure proper ownership and permissions
chown -R "$PUID:$PGID" /mnt/zurg
chmod -R 755 /mnt/zurg

# Function to detect WSL
is_wsl() {
    grep -qiE 'microsoft|wsl' /proc/version 2>/dev/null
}

# Check if running in WSL
if is_wsl; then
    echo "Detected WSL environment."
    VOLUME_OPTION="/mnt/zurg:/data"
else
    echo "Detected native Linux environment."
    VOLUME_OPTION="/mnt/zurg:/data:rshared"
fi

# Navigate to the zurg directory
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
      - ./plex_update.sh:/app/plex_update.sh
      - ./config.yml:/app/config.yml
      - ./:/app/data
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
      - $VOLUME_OPTION
      - ./rclone.conf:/config/rclone/rclone.conf
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

# Check for required dependencies
for cmd in git curl docker docker-compose; do
    if ! command -v "$cmd" &> /dev/null; then
        echo "Error: $cmd is not installed. Please install it and rerun the script."
        exit 1
    fi
done

# Check if Docker is running
if ! systemctl is-active --quiet docker; then
    echo "Docker service is not running. Starting Docker..."
    systemctl start docker
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
