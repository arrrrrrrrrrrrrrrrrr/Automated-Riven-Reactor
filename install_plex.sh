# install_plex.sh
#!/bin/bash

# Check for root privileges
if [[ $EUID -ne 0 ]]; then
   echo "Error: This script must be run with administrative privileges. Please run with sudo."
   exit 1
fi

read -p "Do you have Plex installed? (yes/no): " PLEX_INSTALLED

if [[ "$PLEX_INSTALLED" == "no" ]]; then
    echo "Setting up Plex Media Server..."

    # Create ./plex directory
    mkdir -p ./plex/config
    mkdir -p ./plex/transcode

    # Get PLEX_CLAIM from user
    read -p "Enter your PLEX_CLAIM token (or leave blank if you don't have one): " PLEX_CLAIM

    # Get TZ
    TZ=$(cat /etc/timezone 2>/dev/null || echo "UTC")

    # Create docker-compose.yml for Plex
    cat <<EOF > ./plex/docker-compose.yml
version: '3.8'

services:
  plex:
    image: plexinc/pms-docker
    container_name: plex
    restart: unless-stopped
    network_mode: "host"
    environment:
      - TZ=$TZ
      - PLEX_CLAIM=$PLEX_CLAIM
    volumes:
      - ./plex/config:/config
      - ./plex/transcode:/transcode
      - /mnt:/mnt
EOF

    # Start Plex
    cd plex
    docker-compose up -d
    if [ $? -ne 0 ]; then
        echo "Error: Failed to start Plex Media Server."
        exit 1
    fi
    cd ..

    echo "Plex Media Server setup complete."
    echo "Please go to http://localhost:32400/web to finish Plex setup."
    read -p "Press Enter to continue after you have completed Plex setup..."

    # Since Plex was installed by this script, set RIVEN_PLEX_URL accordingly
    echo "http://plex:32400" > RIVEN_PLEX_URL.txt

else
    echo "Skipping Plex setup."
    # Prompt for RIVEN_PLEX_URL
    read -p "Enter your RIVEN_PLEX_URL: " RIVEN_PLEX_URL
    if [ -z "$RIVEN_PLEX_URL" ]; then
        echo "Error: RIVEN_PLEX_URL cannot be empty."
        exit 1
    fi
    echo "$RIVEN_PLEX_URL" > RIVEN_PLEX_URL.txt
fi
