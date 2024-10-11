# setup_zurg_and_rclone.sh
#!/bin/bash

# Check for root privileges
if [[ $EUID -ne 0 ]]; then
   echo "Error: This script must be run with administrative privileges. Please run with sudo."
   exit 1
fi

read -p "Do you have 'zurg and rclone' running? (yes/no): " ZURG_RUNNING

if [[ "$ZURG_RUNNING" == "no" ]]; then
    echo "Setting up zurg and rclone..."

    # Prompt for RIVEN_DOWNLOADERS_REAL_DEBRID_API_KEY
    read -p "Enter your RIVEN_DOWNLOADERS_REAL_DEBRID_API_KEY: " RIVEN_DOWNLOADERS_REAL_DEBRID_API_KEY
    if [ -z "$RIVEN_DOWNLOADERS_REAL_DEBRID_API_KEY" ]; then
        echo "Error: RIVEN_DOWNLOADERS_REAL_DEBRID_API_KEY cannot be empty."
        exit 1
    fi
    echo "$RIVEN_DOWNLOADERS_REAL_DEBRID_API_KEY" > RIVEN_DOWNLOADERS_REAL_DEBRID_API_KEY.txt

    # Get PUID and PGID from the user who invoked sudo
    PUID=$(id -u "$SUDO_USER")
    PGID=$(id -g "$SUDO_USER")
    TZ=$(cat /etc/timezone 2>/dev/null || echo "UTC")

    # Create /mnt/zurg and set permissions
    mkdir -p /mnt/zurg
    chown "$PUID:$PGID" /mnt/zurg
    chmod 755 /mnt/zurg

    # Clone zurg-testing repository
    git clone https://github.com/debridmediamanager/zurg-testing.git zurg
    if [ $? -ne 0 ]; then
        echo "Error: Failed to clone zurg-testing repository."
        exit 1
    fi

    # Edit config.yml
    cd zurg
    sed -i "s/token: yourtoken/token: $RIVEN_DOWNLOADERS_REAL_DEBRID_API_KEY/g" config.yml

    # Edit docker-compose.yml
    sed -i "s/PUID: 1000/PUID: $PUID/g" docker-compose.yml
    sed -i "s/PGID: 1000/PGID: $PGID/g" docker-compose.yml
    sed -i "s|TZ: Europe/Berlin|TZ: $TZ|g" docker-compose.yml
    sed -i "s|/mnt/zurg|/mnt/zurg|g" docker-compose.yml
    sed -i '/volumes:/a\          - /mnt/zurg:/data:rshared' docker-compose.yml

    # Create /mnt/zurg/__all__ directory
    mkdir -p /mnt/zurg/__all__
    chown "$PUID:$PGID" /mnt/zurg/__all__
    chmod 755 /mnt/zurg/__all__

    # Start docker compose in zurg directory
    docker-compose up -d
    if [ $? -ne 0 ]; then
        echo "Error: Failed to start zurg and rclone containers."
        exit 1
    fi

    # Go back to the original directory
    cd ..

    echo "zurg and rclone setup complete."
else
    echo "Skipping zurg and rclone setup."
fi
