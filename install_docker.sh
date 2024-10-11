# install_docker.sh
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

# Install Docker and Docker Compose
echo "Installing Docker and Docker Compose..."

if [[ "$OS_NAME" == "ubuntu" || "$OS_NAME" == "debian" ]]; then
    echo "Using apt for installation..."
    apt update && apt install -y docker.io docker-compose git
    if [ $? -ne 0 ]; then
        echo "Error: Failed to install Docker and Docker Compose with apt."
        exit 1
    fi
    systemctl start docker
    systemctl enable docker
    usermod -aG docker $SUDO_USER
elif [[ "$OS_NAME" == "arch" || "$OS_NAME" == "manjaro" || "$OS_NAME" == "garuda" ]]; then
    echo "Using pacman for installation..."
    pacman -Sy --noconfirm docker docker-compose git
    if [ $? -ne 0 ]; then
        echo "Error: Failed to install Docker and Docker Compose with pacman."
        exit 1
    fi
    systemctl start docker
    systemctl enable docker
    usermod -aG docker $SUDO_USER
else
    echo "Error: Unsupported distribution: $OS_NAME. Please install Docker, Docker Compose, and Git manually."
    exit 1
fi

echo "Docker, Docker Compose, and Git installed."
