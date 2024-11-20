#!/bin/bash

source ./common_functions.sh

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# File path for the settings.json
SETTINGS_FILE="./riven/riven/riven/settings.json"

# Get local IP for Plex URL
local_ip=$(retrieve_saved_ip)
if [ -z "$local_ip" ]; then
    echo -e "${RED}Error: Could not retrieve local IP. Please ensure main_setup.sh was run first.${NC}"
    exit 1
fi

# Set Plex URLs
DEFAULT_PLEX_URL="http://$local_ip:32400"
PLEX_URL="http://$local_ip:32400"

# Function to check if jq is installed and install if necessary
install_jq_if_missing() {
  if ! command -v jq &> /dev/null; then
    echo -e "${YELLOW}'jq' is not installed. Installing now...${NC}"
    
    if [[ "$OSTYPE" == "darwin"* ]]; then
      if ! command -v brew &> /dev/null; then
        echo -e "${RED}Homebrew is required but not installed. Please install Homebrew first (https://brew.sh/)${NC}"
        exit 1
      fi
      brew install jq
    elif [[ "$OSTYPE" == "linux-gnu"* ]]; then
      if [ -f /etc/debian_version ]; then
        sudo apt update && sudo apt install -y jq
      elif [ -f /etc/redhat-release ]; then
        sudo yum install -y jq
      elif [ -f /etc/arch-release ]; then
        sudo pacman -S jq
      else
        echo -e "${RED}Unsupported Linux distribution. Please install jq manually.${NC}"
        exit 1
      fi
    else
      echo -e "${RED}Unsupported operating system. Please install jq manually.${NC}"
      exit 1
    fi
  else
    echo -e "${GREEN}'jq' is already installed.${NC}"
  fi
}

# Step 2: Install jq if missing
install_jq_if_missing

# Function to retrieve Real-Debrid API Key and Plex URL from files
get_existing_values_from_files() {
  if [ -f "./real_debrid_api_key.txt" ]; then
    REAL_DEBRID_API=$(cat "./real_debrid_api_key.txt")
  elif [ -f "./RIVEN_DOWNLOADERS_REAL_DEBRID_API_KEY.txt" ]; then
    REAL_DEBRID_API=$(cat "./RIVEN_DOWNLOADERS_REAL_DEBRID_API_KEY.txt")
  else
    REAL_DEBRID_API=""
  fi

  if [ -f "./RIVEN_PLEX_URL.txt" ]; then
    PLEX_URL=$(cat "./RIVEN_PLEX_URL.txt")
  else
    PLEX_URL=""
  fi
}

# Step 3: Attempt to retrieve values from existing files
get_existing_values_from_files

# Get Real-Debrid API Key using the common function
REAL_DEBRID_API=$(get_real_debrid_api_key)
if [ $? -ne 0 ]; then
    echo -e "${RED}Error: Failed to get Real-Debrid API Key.${NC}"
    exit 1
fi

# Step 5: Handle Plex URL
echo -e "${GREEN}Plex Server Configuration:${NC}"
echo -e "${GREEN}1. Default URL: $DEFAULT_PLEX_URL${NC}"
echo -e "${GREEN}2. Current URL: $PLEX_URL${NC}"
echo -e "${GREEN}The URL should point to your Plex server (usually http://IP:32400)${NC}"
read -p "$(echo -e "${YELLOW}Is this configuration correct? (y/n): ${NC}")" PLEX_URL_CONFIRM

if [[ ! "$PLEX_URL_CONFIRM" =~ ^[Yy][Ee]?[Ss]?$ ]]; then
    echo -e "${GREEN}Enter the URL that points to your Plex server:${NC}"
    echo -e "${GREEN}If Plex is running on this machine, use: $DEFAULT_PLEX_URL${NC}"
    echo -e "${GREEN}If Plex is on another machine, use: http://MACHINE_IP:32400${NC}"
    read -p "$(echo -e "${YELLOW}Enter Plex URL: ${NC}")" PLEX_URL
else
    # Ensure we're using the local IP URL if user confirms it's correct
    PLEX_URL="$DEFAULT_PLEX_URL"
fi

# Verify the Plex URL before proceeding
echo -e "${GREEN}Using Plex URL: $PLEX_URL${NC}"

# Step 6: Manual Plex Token Configuration
echo -e "${GREEN}Plex Token Configuration:${NC}"
if [ -n "$PLEX_TOKEN" ]; then
    echo -e "${GREEN}Current Plex Token: $PLEX_TOKEN${NC}"
    read -p "$(echo -e "${YELLOW}Do you want to keep this token? (y/n): ${NC}")" KEEP_TOKEN
    if [[ ! "$KEEP_TOKEN" =~ ^[Yy][Ee]?[Ss]?$ ]]; then
        read -p "$(echo -e "${YELLOW}Enter your Plex Token: ${NC}")" PLEX_TOKEN
    fi
else
    read -p "$(echo -e "${YELLOW}Enter your Plex Token: ${NC}")" PLEX_TOKEN
fi

# Step 7: Ask user if they want 4K enabled
echo -e "${GREEN}Quality Settings Configuration:${NC}"
echo -e "${GREEN}1. Default: 1080p and 720p enabled${NC}"
echo -e "${GREEN}2. Optional: 4K (2160p) quality${NC}"
echo -e "${GREEN}Note: You can change these settings later in Riven Settings${NC}"
read -p "$(echo -e "${YELLOW}Would you like to enable 4K quality? (y/n): ${NC}")" ENABLE_4K

# Base jq command
jq_command='.symlink.rclone_path = "/mnt/zurg/__all__" |
    .symlink.library_path = "/mnt/library" |
    .updaters.plex.enabled = true |
    .updaters.plex.url = $plex_url |
    .updaters.plex.token = $plex_token |
    .downloaders.real_debrid.enabled = true |
    .downloaders.real_debrid.api_key = $real_debrid_api |
    .downloaders.real_debrid.proxy_enabled = false |
    .scraping.knightcrawler.enabled = true |
    .scraping.torrentio.enabled = true |
    .content.plex_watchlist.enabled = true'

# Check if 4K should be enabled and append to jq command
if [[ "$ENABLE_4K" =~ ^[Yy][Ee]?[Ss]?$ ]]; then
    jq_command="$jq_command | .ranking.resolutions[\"2160p\"] = true"
fi

# Modify the settings.json
jq --arg real_debrid_api "$REAL_DEBRID_API" \
   --arg plex_url "$PLEX_URL" \
   --arg plex_token "$PLEX_TOKEN" \
   "$jq_command" \
   "$SETTINGS_FILE" > "${SETTINGS_FILE}.tmp" && mv "${SETTINGS_FILE}.tmp" "$SETTINGS_FILE"

echo -e "${GREEN}Settings have been updated.${NC}"

# Step 9: Restart riven to apply settings

sudo docker restart riven
echo -e "${GREEN}Riven service restarted successfully.${NC}"
echo -e "${GREEN}Setup complete. Enjoy!${NC}"
