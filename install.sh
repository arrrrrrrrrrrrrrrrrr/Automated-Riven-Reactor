#!/bin/bash

# Check for root privileges
if [[ $EUID -ne 0 ]]; then
   echo "This script must be run with administrative privileges. Please run with sudo."
   exit 1
fi

# Function to get local IP
get_local_ip() {
    echo "Retrieving local IP address..."
    local_ip=$(hostname -I | awk '{print $1}')
    echo "Local IP detected: $local_ip"
}

# Function to provide instructions for installing WSL
install_wsl() {
    echo "Windows OS detected."
    echo "Please install WSL manually:"
    echo "1. Open PowerShell as Administrator."
    echo "2. Run: wsl --install"
    echo "3. Restart your computer."
    echo "After installing WSL, rerun this script within the WSL environment."
    exit 1
}

# Function to detect OS Distribution
detect_os() {
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        OS_NAME=$ID
        OS_VERSION=$VERSION_ID
        echo "Detected OS: $PRETTY_NAME"
    else
        echo "Cannot detect the operating system."
        exit 1
    fi
}

# Function to install Docker and Docker Compose
install_docker() {
    echo "Installing Docker and Docker Compose..."

    if [[ "$OS_NAME" == "ubuntu" || "$OS_NAME" == "debian" ]]; then
        echo "Using apt for installation..."
        apt update
        apt install -y docker.io docker-compose git
        systemctl start docker
        systemctl enable docker
        usermod -aG docker $SUDO_USER
    elif [[ "$OS_NAME" == "arch" || "$OS_NAME" == "manjaro" || "$OS_NAME" == "garuda" ]]; then
        echo "Using pacman for installation..."
        pacman -Sy --noconfirm docker docker-compose git
        systemctl start docker
        systemctl enable docker
        usermod -aG docker $SUDO_USER
    else
        echo "Unsupported distribution: $OS_NAME. Please install Docker, Docker Compose, and Git manually."
        exit 1
    fi

    echo "Docker, Docker Compose, and Git installed."
}

# Function to setup zurg and rclone
setup_zurg_and_rclone() {
    read -p "Do you have 'zurg and rclone' running? (yes/no): " ZURG_RUNNING

    if [[ "$ZURG_RUNNING" == "no" ]]; then
        echo "Setting up zurg and rclone..."

        # Clone zurg-testing repository
        git clone https://github.com/debridmediamanager/zurg-testing.git zurg

        # Edit config.yml
        cd zurg
        sed -i "s/token: yourtoken/token: $RIVEN_DOWNLOADERS_REAL_DEBRID_API_KEY/g" config.yml

        # Start docker compose in zurg directory
        docker compose up -d

        # Go back to the original directory
        cd ..

        echo "zurg and rclone setup complete."
    else
        echo "Skipping zurg and rclone setup."
    fi
}

# Function to create docker-compose.yml for riven
create_docker_compose() {
    echo "Creating docker-compose.yml..."

    # Prompt for environment variables that require user input
    read -p "Enter your RIVEN_PLEX_TOKEN: " RIVEN_PLEX_TOKEN
    read -p "Enter your RIVEN_PLEX_URL: " RIVEN_PLEX_URL

    # Get PUID and PGID from the user who invoked sudo
    PUID=$(id -u "$SUDO_USER")
    PGID=$(id -g "$SUDO_USER")

    ORIGIN="http://$local_ip:3000"
    TZ=$(cat /etc/timezone 2>/dev/null || echo "UTC")

    # Create local folder called 'riven' for /riven/data/
    DATA_PATH="./riven"
    mkdir -p "$DATA_PATH"
    chown "$PUID:$PGID" "$DATA_PATH"
    chmod 755 "$DATA_PATH"

    # Prompt for zurg __all__ folder directory path
    read -p "Enter the zurg __all__ folder directory path: " ZURG_ALL_PATH

    # Use /mnt/library/, create if it doesn't exist
    LIBRARY_PATH="/mnt/library"
    mkdir -p "$LIBRARY_PATH"
    chown "$PUID:$PGID" "$LIBRARY_PATH"
    chmod 755 "$LIBRARY_PATH"

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
      - "$DATA_PATH:/riven/data/"
      - "$ZURG_ALL_PATH:/zur"
      - "$LIBRARY_PATH:/mnt/library"
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
      DATABASE_URL: "postgresql+psycopg2://postgres:postgres@riven_postgresql:5432/riven"
    ports:
      - "3000:3000"
    networks:
      - riven

  riven_postgresql:
    image: postgres:16.3-alpine3.20
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

    echo "docker-compose.yml created."
}

# Function to create directories with correct permissions
create_directories() {
    echo "Creating directories with permissions 755 and owner $SUDO_USER..."

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

    echo "Directories created and permissions set."
}

# Main script execution
echo "Starting setup..."

# Detect OS Distribution
detect_os

# Detect OS Type
OS_TYPE=$(uname -s)
if [[ "$OS_TYPE" == "Linux" ]]; then
    # Check if running under WSL
    if grep -qi microsoft /proc/version; then
        echo "Running under Windows Subsystem for Linux."
    else
        echo "Linux system detected."
    fi
    get_local_ip
    install_docker

    # Prompt for RIVEN_DOWNLOADERS_REAL_DEBRID_API_KEY needed for zurg and rclone
    read -p "Enter your RIVEN_DOWNLOADERS_REAL_DEBRID_API_KEY: " RIVEN_DOWNLOADERS_REAL_DEBRID_API_KEY

    setup_zurg_and_rclone

    # Proceed to install riven
    create_docker_compose
    create_directories

    echo "Bringing up Riven Docker containers..."
    docker compose up -d

    echo "Setup complete! All services are up and running."

elif [[ "$OS_TYPE" == "Darwin" ]]; then
    echo "macOS detected. This script supports Linux systems."
    exit 1
elif [[ "$OS_TYPE" == "CYGWIN"* || "$OS_TYPE" == "MINGW"* || "$OS_TYPE" == "MSYS_NT"* ]]; then
    install_wsl
else
    echo "Unsupported operating system: $OS_TYPE"
    exit 1
fi
