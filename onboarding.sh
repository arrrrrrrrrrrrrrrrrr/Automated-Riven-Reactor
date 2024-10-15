#!/bin/bash

# File path for the settings.json
SETTINGS_FILE="./riven/settings.json"
DEFAULT_PLEX_URL="http://plex:32400"


# Function to check if jq is installed and install if necessary
install_jq_if_missing() {
  if ! command -v jq &> /dev/null; then
    echo "'jq' is not installed. Installing now..."
    
    if [[ "$OSTYPE" == "linux-gnu"* ]]; then
      if [ -f /etc/debian_version ]; then
        sudo apt update && sudo apt install -y jq
      elif [ -f /etc/redhat-release ]; then
        sudo yum install -y jq
      elif [ -f /etc/arch-release ]; then
        sudo pacman -S jq
      else
        echo "Unsupported Linux distribution. Please install jq manually."
        exit 1
      fi
    elif [[ "$OSTYPE" == "darwin"* ]]; then
      if command -v brew &> /dev/null; then
        brew install jq
      else
        echo "Homebrew is not installed. Please install jq manually via Homebrew (https://brew.sh/)."
        exit 1
      fi
    else
      echo "Unsupported operating system. Please install jq manually."
      exit 1
    fi
  else
    echo "'jq' is already installed."
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
    PLEX_URL="$DEFAULT_PLEX_URL"
  fi
}

# Step 3: Attempt to retrieve values from existing files
get_existing_values_from_files

# Step 4: If Real-Debrid API Key is not found, ask the user
if [ -z "$REAL_DEBRID_API" ]; then
  read -p "Please enter your Real-Debrid API key: " REAL_DEBRID_API
fi

# Step 5: Handle Plex URL
echo "Default by in docker is "http://plex:32400" if Plex was created by Automated-Riven-Reactor"
echo "The current Plex URL for Riven to see was set up by this script: $PLEX_URL"
read -p "Is this correct? (yes/no): " PLEX_URL_CONFIRM

if [ "$PLEX_URL_CONFIRM" == "no" ]; then
  read -p "Please enter the correct Plex URL: " PLEX_URL
fi

# Step 6: Manual Plex Token input
read -p "Please enter your Plex token: " PLEX_TOKEN

# Step 7: Ask user if they want 4K enabled
read -p "Do you want to enable 4K (2160p) quality? (yes/no) (Default is 1080p only, you can change later in Riven Settings): " ENABLE_4K

if [ "$ENABLE_4K" == "yes" ]; then
    ENABLE_4K="true"
else
    ENABLE_4K="false"
fi

# Step 8: Modify the settings.json
jq --arg real_debrid_api "$REAL_DEBRID_API" \
   --arg plex_url "$PLEX_URL" \
   --arg plex_token "$PLEX_TOKEN" \
   --arg enable_4k "$ENABLE_4K" \
   '.symlink.rclone_path = "/mnt/zurg/__all__" |
    .symlink.library_path = "/mnt/library" |
    .updaters.plex.enabled = true |
    .updaters.plex.url = $plex_url |
    .updaters.plex.token = $plex_token |
    .downloaders.real_debrid.enabled = true |
    .downloaders.real_debrid.api_key = $real_debrid_api |
    .downloaders.real_debrid.proxy_enabled = false |
    .content.plex_watchlist.enabled = true |
    .scraping.torrentio.enabled = true |
    .scraping.torrentio["2160p"] = ($enable_4k == "true")' \
    "$SETTINGS_FILE" > "${SETTINGS_FILE}.tmp" && mv "${SETTINGS_FILE}.tmp" "$SETTINGS_FILE"

echo "Settings have been updated."

# Step 9: Restart riven to apply settings
sudo docker restart riven
    echo "Riven service restarted successfully."
    echo "Setup complete. Enjoy!"

