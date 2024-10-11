# main_setup.sh
#!/bin/bash

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

# Stop and remove existing containers if they exist
echo "Checking for existing Riven containers..."

CONTAINERS=("riven" "riven-frontend" "riven_postgres")

for CONTAINER in "${CONTAINERS[@]}"; do
    if [ "$(docker ps -a -q -f name="^${CONTAINER}$")" ]; then
        echo "Found existing container: $CONTAINER"
        echo "Stopping and removing $CONTAINER..."
        docker stop "$CONTAINER"
        docker rm "$CONTAINER"
    fi
done

# Now bring up the containers
docker-compose up -d
if [ $? -ne 0 ]; then
    echo "Error: docker-compose up failed."
    exit 1
fi

echo "Setup complete! All services are up and running."

# Function to get local IP address
get_local_ip() {
    # Try hostname -I (Linux)
    local_ip=$(hostname -I 2>/dev/null | awk '{print $1}')
    if [[ -z "$local_ip" ]]; then
        # Try ipconfig getifaddr en0 (macOS)
        local_ip=$(ipconfig getifaddr en0 2>/dev/null)
    fi
    if [[ -z "$local_ip" ]]; then
        # Try ifconfig (Unix/macOS)
        local_ip=$(ifconfig 2>/dev/null | grep -E 'inet ' | grep -v '127.0.0.1' | awk '{ print $2 }' | head -n 1)
    fi
    if [[ -z "$local_ip" ]]; then
        # Try ip route (Linux)
        local_ip=$(ip route get 1 | awk '{print $NF;exit}' 2>/dev/null)
    fi
    if [[ -z "$local_ip" ]]; then
        echo "Unable to automatically detect your local IP address."
        read -p "Please enter your machine's IP address (default is 'localhost'): " user_input
        local_ip=${user_input:-localhost}
    else
        echo "Local IP detected: $local_ip"
    fi
}

# Get the local IP address
get_local_ip

echo "Continue to http://$local_ip:3000 to start Riven onboarding"
