# create_riven_compose.sh
#!/bin/bash

# Check for root privileges
if [[ $EUID -ne 0 ]]; then
   echo "Error: This script must be run with administrative privileges. Please run with sudo."
   exit 1
fi

echo "Creating docker-compose.yml for Riven..."

# Prompt for environment variables that require user input
read -p "Enter your RIVEN_PLEX_TOKEN: " RIVEN_PLEX_TOKEN
if [ -z "$RIVEN_PLEX_TOKEN" ]; then
    echo "Error: RIVEN_PLEX_TOKEN cannot be empty."
    exit 1
fi

# If RIVEN_PLEX_URL is not set (Plex was not installed by script), prompt for it
if [ -f RIVEN_PLEX_URL.txt ]; then
    RIVEN_PLEX_URL=$(cat RIVEN_PLEX_URL.txt)
else
    read -p "Enter your RIVEN_PLEX_URL: " RIVEN_PLEX_URL
    if [ -z "$RIVEN_PLEX_URL" ]; then
        echo "Error: RIVEN_PLEX_URL cannot be empty."
        exit 1
    fi
fi

# Get PUID and PGID from the user who invoked sudo
PUID=$(id -u "$SUDO_USER")
PGID=$(id -g "$SUDO_USER")

ORIGIN="http://$(hostname -I | awk '{print $1}'):3000"
TZ=$(cat /etc/timezone 2>/dev/null || echo "UTC")

# ZURG_ALL_PATH is /mnt/zurg/__all__
read -p "Enter the zurg __all__ folder directory path (default is /mnt/zurg/__all__): " ZURG_ALL_PATH
ZURG_ALL_PATH=${ZURG_ALL_PATH:-/mnt/zurg/__all__}

# Read RIVEN_DOWNLOADERS_REAL_DEBRID_API_KEY from a file (if stored)
if [ -f RIVEN_DOWNLOADERS_REAL_DEBRID_API_KEY.txt ]; then
    RIVEN_DOWNLOADERS_REAL_DEBRID_API_KEY=$(cat RIVEN_DOWNLOADERS_REAL_DEBRID_API_KEY.txt)
else
    read -p "Enter your RIVEN_DOWNLOADERS_REAL_DEBRID_API_KEY: " RIVEN_DOWNLOADERS_REAL_DEBRID_API_KEY
    if [ -z "$RIVEN_DOWNLOADERS_REAL_DEBRID_API_KEY" ]; then
        echo "Error: RIVEN_DOWNLOADERS_REAL_DEBRID_API_KEY cannot be empty."
        exit 1
    fi
fi

# Create the docker-compose.yml file
cat <<EOF > docker-compose.yml
version: '3.8'

services:
  riven:
    image: spoked/riven:dev
    container_name: riven
    restart: unless-stopped
    tty: true
    environment:
      PUID: "$PUID"
      PGID: "$PGID"
      ORIGIN: "$ORIGIN"
      RIVEN_PLEX_URL: "$RIVEN_PLEX_URL"
      RIVEN_PLEX_TOKEN: "$RIVEN_PLEX_TOKEN"
      RIVEN_PLEX_RCLONE_PATH: "/mnt/zurg/__all__"
      RIVEN_PLEX_LIBRARY_PATH: "/mnt/library"
      RIVEN_DOWNLOADERS_REAL_DEBRID_ENABLED: "true"
      RIVEN_DOWNLOADERS_REAL_DEBRID_API_KEY: "$RIVEN_DOWNLOADERS_REAL_DEBRID_API_KEY"
      TZ: "$TZ"
      REPAIR_SYMLINKS: "false"
      HARD_RESET: "false"
    ports:
      - "3000:3000"
    volumes:
      - "./riven:/riven/data/"
      - "$ZURG_ALL_PATH:/zur"
      - "/mnt/library:/mnt/library"
      - "$ZURG_ALL_PATH:/mnt/zurg/__all__"
    networks:
      - riven

  riven-frontend:
    image: spoked/riven-frontend:dev
    container_name: riven-frontend
    restart: unless-stopped
    tty: true
    environment:
      ORIGIN: "$ORIGIN"
      BACKEND_URL: "http://riven:3000"
      TZ: "$TZ"
      DIALECT: "postgres"
      DATABASE_URL: "postgresql+psycopg2://postgres:postgres@riven_postgresql/riven"
    ports:
      - "3000:3000"
    networks:
      - riven

  riven_postgresql:
    image: postgres:16.3-alpine3.20
    container_name: riven_postgresql
    environment:
      PUID: "$PUID"
      PGID: "$PGID"
      POSTGRES_PASSWORD: "postgres"
      POSTGRES_USERNAME: "postgres"
      POSTGRES_DB: "riven"
    volumes:
      - "./postgresdata:/var/lib/postgresql/data"
    networks:
      - riven

networks:
  riven:
    driver: bridge
EOF

if [ $? -ne 0 ]; then
    echo "Error: Failed to create docker-compose.yml."
    exit 1
fi

echo "docker-compose.yml created."
