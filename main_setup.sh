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
docker-compose up -d
if [ $? -ne 0 ]; then
    echo "Error: docker-compose up failed."
    exit 1
fi

echo "Setup complete! All services are up and running."
