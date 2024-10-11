#!/bin/bash

# Check for root privileges
if [[ $EUID -ne 0 ]]; then
   echo "Error: This script must be run with administrative privileges. Please run with sudo."
   exit 1
fi

# Detect OS Distribution
if [ -f /etc/os-release ]; then
    . /etc/os-release
    OS_NAME=$ID
    OS_VERSION=$VERSION_ID
    echo "Detected OS: $PRETTY_NAME"
else
    echo "Error: Cannot detect the operating system."
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

    # Check if 'zurg' directory already exists
    if [ -d "zurg" ]; then
        echo "Error: The 'zurg' directory already exists."
        echo "You can choose to:"
        echo "1. Delete the existing 'zurg' directory and re-clone."
        echo "2. Skip cloning and use the existing directory."
        echo "3. Exit the setup."

        read -p "Enter your choice (1/2/3): " USER_CHOICE

        case "$USER_CHOICE" in
            1)
                echo "Deleting the existing 'zurg' directory..."
                rm -rf zurg
                ;;
            2)
                echo "Using the existing 'zurg' directory."
                ;;
            3)
                echo "Exiting setup."
                exit 1
                ;;
            *)
                echo "Invalid choice. Exiting setup."
                exit 1
                ;;
        esac
    fi

    # Clone zurg-testing repository if 'zurg' directory doesn't exist
    if [ ! -d "zurg" ]; then
        git clone https://github.com/debridmediamanager/zurg-testing.git zurg
        if [ $? -ne 0 ]; then
            echo "Error: Failed to clone zurg-testing repository."
            exit 1
        fi
    fi

    # Proceed with the rest of the setup
    cd zurg

    # Use yq to modify YAML file (install if not present)
    if ! command -v yq &> /dev/null; then
        echo "Installing yq..."
        if [[ "$OS_NAME" == "ubuntu" || "$OS_NAME" == "debian" ]]; then
            curl -L https://github.com/mikefarah/yq/releases/download/v4.35.1/yq_linux_amd64 -o /usr/local/bin/yq
            chmod +x /usr/local/bin/yq
        elif [[ "$OS_NAME" == "arch" || "$OS_NAME" == "manjaro" ]]; then
            pacman -Sy --noconfirm yq
        elif [[ "$OS_NAME" == "centos" || "$OS_NAME" == "fedora" || "$OS_NAME" == "rhel" ]]; then
            curl -L https://github.com/mikefarah/yq/releases/download/v4.35.1/yq_linux_amd64 -o /usr/local/bin/yq
            chmod +x /usr/local/bin/yq
        else
            echo "Your OS is not directly supported by this script."
            echo "Attempting to install yq by downloading the binary."
            curl -L https://github.com/mikefarah/yq/releases/download/v4.35.1/yq_linux_amd64 -o /usr/local/bin/yq
            chmod +x /usr/local/bin/yq
            if ! command -v yq &> /dev/null; then
                echo "Error: Failed to install yq."
                exit 1
            fi
        fi
    fi

    # Update the token in config.yml using yq
    yq eval ".token = \"$RIVEN_DOWNLOADERS_REAL_DEBRID_API_KEY\"" -i config.yml

    # Edit docker-compose.yml
    sed -i "s/PUID: 1000/PUID: $PUID/g" docker-compose.yml
    sed -i "s/PGID: 1000/PGID: $PGID/g" docker-compose.yml
    sed -i "s|TZ: Europe/Berlin|TZ: $TZ|g" docker-compose.yml

    # Ensure /mnt/zurg is set in docker-compose.yml
    sed -i "s|/mnt/zurg|/mnt/zurg|g" docker-compose.yml

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

# After setting up zurg and rclone, store ZURG_ALL_PATH in a file
echo "$ZURG_ALL_PATH" > ZURG_ALL_PATH.txt