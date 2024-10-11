# create_directories.sh
#!/bin/bash

# Check for root privileges
if [[ $EUID -ne 0 ]]; then
   echo "Error: This script must be run with administrative privileges. Please run with sudo."
   exit 1
fi

echo "Creating directories with permissions 755 and owner $SUDO_USER..."

# Get PUID and PGID from the user who invoked sudo
PUID=$(id -u "$SUDO_USER")
PGID=$(id -g "$SUDO_USER")

# Create /mnt/library if it doesn't exist
LIBRARY_PATH="/mnt/library"
mkdir -p "$LIBRARY_PATH"
chown "$PUID:$PGID" "$LIBRARY_PATH"
chmod 755 "$LIBRARY_PATH"

# Paths to create
MOVIES_PATH="$LIBRARY_PATH/movies"
SHOWS_PATH="$LIBRARY_PATH/shows"

# Create directories if they do not exist
mkdir -p "$MOVIES_PATH"
mkdir -p "$SHOWS_PATH"

# Set permissions to 755
chmod 755 "$MOVIES_PATH"
chmod 755 "$SHOWS_PATH"

# Set ownership to specified user and group
chown "$PUID:$PGID" "$MOVIES_PATH"
chown "$PUID:$PGID" "$SHOWS_PATH"

# Create local folder called 'riven' for /riven/data/
DATA_PATH="./riven"
mkdir -p "$DATA_PATH"
chown "$PUID:$PGID" "$DATA_PATH"
chmod 755 "$DATA_PATH"

echo "Directories created and permissions set."
