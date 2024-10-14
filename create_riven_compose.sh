#!/bin/bash

# Include common functions
source ./common_functions.sh

# Check for root privileges
if [[ $EUID -ne 0 ]]; then
    echo "Error: This script must be run with administrative privileges. Please run with sudo."
    exit 1
fi

# Function to get the local IP address
get_local_ip() {
    local_ip=$(hostname -I | awk '{print $1}')
    if [ -z "$local_ip" ]; then
        echo "Error: Could not retrieve local IP address."
        exit 1
    fi
    echo "Local IP: $local_ip"
}

# Get the local IP for ORIGIN
get_local_ip
ORIGIN="http://$local_ip:3000"

# Get PUID and PGID from the user who invoked sudo
PUID=$(id -u "$SUDO_USER")
PGID=$(id -g "$SUDO_USER")

# Export PUID, PGID, and TZ to be used in docker-compose.yml
export PUID PGID
if [ -f /etc/timezone ]; then
    TZ=$(cat /etc/timezone)
else
    TZ=$(timedatectl | grep "Time zone" | awk '{print $3}')
    TZ=${TZ:-"UTC"}
fi
export TZ

# Ask if zurg library is at default path
echo "Is your zurg library located at /mnt/zurg/__all__? (yes/no)"
read -p "Enter your choice (yes/no): " ZURG_DEFAULT_PATH

if [[ "$ZURG_DEFAULT_PATH" == "yes" ]]; then
    ZURG_ALL_PATH="/mnt/zurg/__all__"
else
    # Prompt for custom zurg __all__ path
    read -p "Enter your zurg library path: " ZURG_ALL_PATH
    if [ -z "$ZURG_ALL_PATH" ]; then
        echo "Error: Zurg library path cannot be empty."
        exit 1
    fi
fi

# Save ZURG_ALL_PATH for future reference
echo "$ZURG_ALL_PATH" > ZURG_ALL_PATH.txt

# Read Real-Debrid API key from a file (if stored)
if [ -f RIVEN_DOWNLOADERS_REAL_DEBRID_API_KEY.txt ]; then
    RIVEN_DOWNLOADERS_REAL_DEBRID_API_KEY=$(cat RIVEN_DOWNLOADERS_REAL_DEBRID_API_KEY.txt)
else
    read -p "Enter your RIVEN_DOWNLOADERS_REAL_DEBRID_API_KEY: " RIVEN_DOWNLOADERS_REAL_DEBRID_API_KEY
    if [ -z "$RIVEN_DOWNLOADERS_REAL_DEBRID_API_KEY" ]; then
        echo "Error: Real-Debrid API key cannot be empty."
        exit 1
    fi
    echo "$RIVEN_DOWNLOADERS_REAL_DEBRID_API_KEY" > RIVEN_DOWNLOADERS_REAL_DEBRID_API_KEY.txt
fi

# Ensure the /home/docker/riven-db directory exists with correct permissions
POSTGRES_DIR="/home/docker/riven-db"
if [ ! -d "$POSTGRES_DIR" ]; then
    echo "Creating $POSTGRES_DIR..."
    mkdir -p "$POSTGRES_DIR"
fi

# Set correct ownership and permissions
chown "$PUID":"$PGID" "$POSTGRES_DIR"
chmod 755 -R "$POSTGRES_DIR"
echo "Directory $POSTGRES_DIR created with ownership set to PUID: $PUID, PGID: $PGID and permissions set to 755."

# Create the .env file for environment variables
cat <<EOF > .env
PUID=$PUID
PGID=$PGID
TZ=$TZ
EOF

echo ".env file created with PUID, PGID, and TZ."

# Create the docker-compose.yml file
cat <<EOF > docker-compose.yml
version: '3.8'
services:
  riven-frontend:
    image: spoked/riven-frontend:latest
    container_name: riven-frontend
    restart: unless-stopped
    ports:
      - "3000:3000"
    environment:
      - PUID=\${PUID}
      - PGID=\${PGID}
      - TZ=\${TZ}
      - ORIGIN=$ORIGIN
      - BACKEND_URL=http://riven:8080
      - DIALECT=postgres
      - DATABASE_URL=postgresql+psycopg2://postgres:postgres@riven-db/riven
    depends_on:
      riven:
        condition: service_healthy
    networks:
      - riven_network

  riven:
    image: spoked/riven:latest
    container_name: riven
    restart: unless-stopped
    environment:
      - PUID=\${PUID}
      - PGID=\${PGID}
      - TZ=\${TZ}
      - RIVEN_FORCE_ENV=true
      - RIVEN_DATABASE_HOST=postgresql+psycopg2://postgres:postgres@riven-db/riven
      - RIVEN_PLEX_URL=
      - RIVEN_PLEX_TOKEN=
      - RIVEN_PLEX_RCLONE_PATH=/mnt/zurg/__all__
      - RIVEN_PLEX_LIBRARY_PATH=/mnt/library
      - RIVEN_DOWNLOADERS_REAL_DEBRID_API_KEY=$RIVEN_DOWNLOADERS_REAL_DEBRID_API_KEY
      - RIVEN_ORIGIN=$ORIGIN
      - REPAIR_SYMLINKS=false
      - HARD_RESET=false
    healthcheck:
      test: ["CMD-SHELL", "curl -s http://localhost:8080 >/dev/null || exit 1"]
      interval: 30s
      timeout: 10s
      retries: 10
    volumes:
      - ./riven:/riven/data
      - /mnt:/mnt/
      - $ZURG_ALL_PATH:/mnt/zurg/__all__
    depends_on:
      riven_postgres:
        condition: service_healthy
    networks:
      - riven_network

  riven_postgres:
    image: postgres:16.3-alpine3.20
    container_name: riven-db
    environment:
      PGDATA: /var/lib/postgresql/data/
      POSTGRES_USER: postgres
      POSTGRES_PASSWORD: postgres
      POSTGRES_DB: riven
    volumes:
       - /home/docker/riven-db:/var/lib/postgresql/data
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U postgres"]
      interval: 10s
      timeout: 5s
      retries: 5
    networks:
      - riven_network


networks:
  riven_network:
    driver: bridge
EOF

if [ $? -ne 0 ]; then
    echo "Error: Failed to create docker-compose.yml."
    exit 1
fi

echo "docker-compose.yml created successfully."
