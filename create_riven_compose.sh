#!/bin/bash

# Include common functions
source ./common_functions.sh

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Check for root privileges
if [[ $EUID -ne 0 ]]; then
    echo -e "${RED}Error: This script must be run with administrative privileges. Please run with sudo.${NC}"
    exit 1
fi

    

# Get the local IP for ORIGIN
local_ip=$(retrieve_saved_ip)
if [ -z "$local_ip" ]; then
    echo -e "${RED}Error: Could not retrieve local IP. Please ensure main_setup.sh was run first.${NC}"
    exit 1
fi
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
echo -e "${GREEN}Zurg Library Configuration:${NC}"
echo -e "${GREEN}1. Default path: /mnt/zurg/__all__${NC}"
echo -e "${GREEN}2. Custom path: You'll need to specify the path${NC}"
echo -e "${YELLOW}Type 'y' for default path, 'n' for custom path${NC}"
read -p "$(echo -e "${YELLOW}Your choice (y/n): ${NC}")" ZURG_DEFAULT_PATH

if [[ "$ZURG_DEFAULT_PATH" =~ ^[Yy]$ ]]; then
    ZURG_ALL_PATH="/mnt/zurg/__all__"
else
    echo -e "${GREEN}Enter the full path where your Zurg library is located${NC}"
    echo -e "${GREEN}Example: /path/to/your/zurg/library${NC}"
    read -p "$(echo -e "${YELLOW}Enter your Zurg library path: ${NC}")" ZURG_ALL_PATH
    if [ -z "$ZURG_ALL_PATH" ]; then
        echo -e "${RED}Error: Zurg library path cannot be empty.${NC}"
        exit 1
    fi
fi

# Save ZURG_ALL_PATH for future reference
echo "$ZURG_ALL_PATH" > ZURG_ALL_PATH.txt

# Get Real-Debrid API key using the common function
RIVEN_DOWNLOADERS_REAL_DEBRID_API_KEY=$(get_real_debrid_api_key)
if [ $? -ne 0 ]; then
    echo -e "${RED}Error: Failed to get Real-Debrid API Key.${NC}"
    exit 1
fi

# Ensure the /home/docker/riven-db directory exists with correct permissions
POSTGRES_DIR="/home/docker/riven-db"
if [ ! -d "$POSTGRES_DIR" ]; then
    echo -e "${GREEN}Creating $POSTGRES_DIR...${NC}"
    mkdir -p "$POSTGRES_DIR"
fi

# Set correct ownership and permissions
chown "$PUID":"$PGID" "$POSTGRES_DIR"
chmod 755 -R "$POSTGRES_DIR"
echo -e "${GREEN}Directory $POSTGRES_DIR created with ownership set to PUID: $PUID, PGID: $PGID and permissions set to 755.${NC}"

# Create the .env file for environment variables
cat <<EOF > ./riven/.env
PUID=$PUID
PGID=$PGID
TZ=$TZ
EOF

echo -e "${GREEN}.env file created with PUID, PGID, and TZ.${NC}"

# Create the docker-compose.yml file
cat <<EOF > ./riven/docker-compose.yml
services:
  riven-frontend:
    image: spoked/riven-frontend:latest
    container_name: riven-frontend
    restart: unless-stopped
    ports:
      - "3000:3000"
    volumes:
      - ./riven/rivenfrontend:/riven/config      
    environment:
      - PUID=\${PUID}
      - PGID=\${PGID}
      - TZ=\${TZ}
      - ORIGIN=$ORIGIN
      - BACKEND_URL=http://riven:8080
      - DIALECT=postgres
      - DATABASE_URL=postgresql+psycopg2://postgres:postgres@riven-db/riven
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
    volumes:
      - ./riven/riven:/riven/data
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
      PUID: \${PUID}
      PGID: \${PGID}
      TZ: \${TZ}
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
    echo -e "${RED}Error: Failed to create docker-compose.yml.${NC}"
    exit 1
fi

echo -e "${GREEN}docker-compose.yml created in ./riven directory.${NC}"
