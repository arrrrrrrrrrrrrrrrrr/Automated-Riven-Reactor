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

echo -e "${GREEN}Plex Media Server Configuration${NC}"
echo -e "${GREEN}=============================${NC}"
echo -e "${GREEN}This will help you set up Plex Media Server for your media library.${NC}"
echo

echo -e "${YELLOW}Would you like to install Plex Media Server? (y/n)${NC}"
read -p "$(echo -e "${YELLOW}Your choice (y/n): ${NC}")" PLEX_INSTALL

if [[ "$PLEX_INSTALL" =~ ^[Yy][Ee]?[Ss]?$ ]]; then
    echo -e "${GREEN}Setting up Plex Media Server...${NC}"

    # Create ./plex directory
    echo -e "${GREEN}Creating Plex directories...${NC}"
    mkdir -p ./plex/config
    mkdir -p ./plex/transcode

    # Get PLEX_CLAIM from user
    echo -e "${GREEN}Plex Claim Token Configuration:${NC}"
    echo -e "${GREEN}1. Visit https://plex.tv/claim to get your claim token${NC}"
    echo -e "${GREEN}2. The token starts with 'claim-' and is valid for 4 minutes${NC}"
    echo -e "${GREEN}3. Leave blank to skip (you can claim the server later)${NC}"
    read -p "$(echo -e "${YELLOW}Enter your PLEX_CLAIM token: ${NC}")" PLEX_CLAIM

    # Get TZ
    TZ=$(cat /etc/timezone 2>/dev/null || echo "UTC")

    # Create docker-compose.yml for Plex
    echo -e "${GREEN}Creating Plex docker-compose.yml...${NC}"
    cat <<EOF > ./plex/docker-compose.yml
version: '3.8'

services:
  plex:
    image: plexinc/pms-docker
    container_name: plex
    restart: unless-stopped
    environment:
      - TZ=$TZ
      - PLEX_CLAIM=$PLEX_CLAIM
    volumes:
      - ./plex/config:/config
      - ./plex/transcode:/transcode
      - /mnt:/mnt
    ports:
      - "32400:32400"
EOF

    # Start Plex
    echo -e "${GREEN}Starting Plex Media Server...${NC}"
    cd plex
    docker-compose up -d
    if [ $? -ne 0 ]; then
        echo -e "${RED}Error: Failed to start Plex Media Server.${NC}"
        exit 1
    fi
    cd ..
    echo -e "${GREEN}Plex Media Server setup complete.${NC}"
    echo -e "${GREEN}Please go to http://localhost:32400/web to finish Plex setup.${NC}"
    read -p "$(echo -e "${YELLOW}Press Enter to continue after you have completed Plex setup...${NC}")"

    # Since Plex was installed by this script, set RIVEN_PLEX_URL accordingly
    echo "http://plex:32400" > RIVEN_PLEX_URL.txt
else
    echo -e "${GREEN}Skipping Plex setup.${NC}"
    # Prompt for RIVEN_PLEX_URL
    echo -e "${YELLOW}Enter your RIVEN_PLEX_URL:${NC}"
    read -p "$(echo -e "${YELLOW}Your choice: ${NC}")" RIVEN_PLEX_URL
    if [ -z "$RIVEN_PLEX_URL" ]; then
        echo -e "${RED}Error: RIVEN_PLEX_URL cannot be empty.${NC}"
        exit 1
    fi
    echo "$RIVEN_PLEX_URL" > RIVEN_PLEX_URL.txt
fi
