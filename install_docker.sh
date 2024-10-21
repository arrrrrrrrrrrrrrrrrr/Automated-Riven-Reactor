#!/bin/bash

# install_docker.sh

# Exit immediately if a command exits with a non-zero status
set -e

# Check for root privileges
if [[ $EUID -ne 0 ]]; then
    echo "Error: This script must be run with administrative privileges. Please run with sudo."
    exit 1
fi

# Function to check if a command exists
command_exists() {
    command -v "$1" &> /dev/null
}

# Function to compare Docker versions
is_latest_docker() {
    local_installed_version=$(docker version --format '{{.Server.Version}}' 2>/dev/null || echo "None")
    latest_version=$(curl -s https://api.github.com/repos/docker/docker-ce/releases/latest | grep -Po '"tag_name": "\K.*?(?=")' | sed 's/^v//')

    if [[ "$local_installed_version" == "$latest_version" ]]; then
        return 0
    else
        return 1
    fi
}

# Function to detect OS family
detect_os_family() {
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        OS_NAME=$ID
        OS_VERSION=$VERSION_ID
        OS_PRETTY_NAME=$PRETTY_NAME
        OS_ID_LIKE=$ID_LIKE

        # Map derivative distributions to their parent
        if [[ "$ID" == "ubuntu" || "$ID" == "debian" || "$ID_LIKE" == *"debian"* ]]; then
            OS_FAMILY="debian"
        elif [[ "$ID" == "arch" || "$ID_LIKE" == *"arch"* ]]; then
            OS_FAMILY="arch"
        elif [[ "$ID" == "fedora" || "$ID" == "centos" || "$ID" == "rhel" || "$ID_LIKE" == *"fedora"* ]]; then
            OS_FAMILY="fedora"
        elif [[ "$ID" == "opensuse-leap" || "$ID" == "sles" || "$ID" == "suse" || "$ID_LIKE" == *"suse"* ]]; then
            OS_FAMILY="suse"
        else
            OS_FAMILY="unknown"
        fi

        # Check for WSL
        if grep -qEi "(Microsoft|WSL)" /proc/version &> /dev/null; then
            OS_FAMILY="wsl"
        fi

        echo "Detected OS: $OS_PRETTY_NAME"
        echo "OS Family: $OS_FAMILY"
    else
        echo "Error: Cannot detect the operating system."
        exit 1
    fi
}

# Function to install or update Docker
install_or_update_docker() {
    echo "Installing or updating Docker..."

    if [[ "$OS_FAMILY" == "debian" || "$OS_FAMILY" == "wsl" ]]; then
        sudo apt-get update
        sudo apt-get install -y \
            apt-transport-https \
            ca-certificates \
            curl \
            gnupg \
            lsb-release

        sudo mkdir -p /etc/apt/keyrings
        curl -fsSL https://download.docker.com/linux/$ID/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg

        echo \
          "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/$ID \
          $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

        sudo apt-get update
        sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin docker-compose

        # Start Docker daemon manually since WSL doesn't support systemd by default
        echo "Starting Docker daemon manually in WSL..."
        sudo dockerd > /dev/null 2>&1 &

        # Wait for Docker daemon to start
        sleep 5

        # Verify Docker is running
        if command_exists docker && docker info > /dev/null 2>&1; then
            echo "Docker installed and daemon is running in WSL."
        else
            echo "Error: Docker installation failed in WSL."
            exit 1
        fi

        # Add user to docker group
        sudo groupadd docker || true
        sudo usermod -aG docker "$SUDO_USER"

        echo "Note: Docker daemon has been started manually in WSL."
        echo "To have it start automatically, consider adding 'sudo dockerd > /dev/null 2>&1 &' to your shell's startup script (e.g., ~/.bashrc)."

    elif [[ "$OS_FAMILY" == "debian" ]]; then
        sudo apt-get update
        sudo apt-get install -y \
            apt-transport-https \
            ca-certificates \
            curl \
            gnupg \
            lsb-release

        sudo mkdir -p /etc/apt/keyrings
        curl -fsSL https://download.docker.com/linux/$ID/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg

        echo \
          "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/$ID \
          $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

        sudo apt-get update
        sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin

        # Enable and start Docker
        sudo systemctl enable docker
        sudo systemctl start docker || true

        # Add user to docker group
        sudo usermod -aG docker "$SUDO_USER"

    elif [[ "$OS_FAMILY" == "arch" ]]; then
        sudo pacman -Syu --noconfirm
        sudo pacman -Sy --noconfirm docker docker-compose

        # Enable and start Docker service
        sudo systemctl enable docker
        sudo systemctl start docker

        # Add user to docker group
        sudo usermod -aG docker "$SUDO_USER"

    elif [[ "$OS_FAMILY" == "fedora" ]]; then
        sudo dnf -y install dnf-plugins-core
        sudo dnf config-manager \
            --add-repo \
            https://download.docker.com/linux/fedora/docker-ce.repo

        sudo dnf install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin

        # Enable and start Docker
        sudo systemctl enable docker
        sudo systemctl start docker

        # Add user to docker group
        sudo usermod -aG docker "$SUDO_USER"

    elif [[ "$OS_FAMILY" == "suse" ]]; then
        sudo zypper refresh
        sudo zypper install -y docker docker-compose

        # Enable and start Docker
        sudo systemctl enable docker
        sudo systemctl start docker

        # Add user to docker group
        sudo usermod -aG docker "$SUDO_USER"

    else
        echo "Unsupported OS for automatic Docker installation."
        return 1
    fi

    if ! command_exists docker; then
        echo "Error: Docker installation failed."
        return 1
    fi
}

# Function to install or update Docker Compose
install_or_update_docker_compose() {
    echo "Installing or updating Docker Compose..."

    if [[ "$OS_FAMILY" == "debian" || "$OS_FAMILY" == "wsl" ]]; then
        # Docker Compose is installed via the docker-compose-plugin package
        if docker compose version > /dev/null 2>&1; then
            echo "Docker Compose is already installed and up to date."
        else
            echo "Error: Docker Compose installation failed."
            return 1
        fi
    elif [[ "$OS_FAMILY" == "arch" ]]; then
        # Docker Compose is installed via pacman
        if docker compose version > /dev/null 2>&1; then
            echo "Docker Compose is already installed and up to date."
        else
            echo "Error: Docker Compose installation failed."
            return 1
        fi
    elif [[ "$OS_FAMILY" == "fedora" ]]; then
        # Docker Compose is installed via dnf
        if docker compose version > /dev/null 2>&1; then
            echo "Docker Compose is already installed and up to date."
        else
            echo "Error: Docker Compose installation failed."
            return 1
        fi
    elif [[ "$OS_FAMILY" == "suse" ]]; then
        # Docker Compose is installed via zypper
        if docker compose version > /dev/null 2>&1; then
            echo "Docker Compose is already installed and up to date."
        else
            echo "Error: Docker Compose installation failed."
            return 1
        fi
    else
        # Manual installation for other OS families
        DOCKER_COMPOSE_VERSION=$(curl -s https://api.github.com/repos/docker/compose/releases/latest | grep -Po '"tag_name": "\K.*?(?=")')
        if [[ -z "$DOCKER_COMPOSE_VERSION" ]]; then
            DOCKER_COMPOSE_VERSION="v2.29.2"
        fi

        ARCH=$(uname -m)
        if [[ "$ARCH" == "x86_64" ]]; then
            ARCH="x86_64"
        elif [[ "$ARCH" == "aarch64" || "$ARCH" == "arm64" ]]; then
            ARCH="aarch64"
        fi

        sudo mkdir -p /usr/local/lib/docker/cli-plugins
        sudo curl -SL "https://github.com/docker/compose/releases/download/${DOCKER_COMPOSE_VERSION}/docker-compose-linux-$ARCH" -o /usr/local/lib/docker/cli-plugins/docker-compose
        sudo chmod +x /usr/local/lib/docker/cli-plugins/docker-compose

        if docker compose version > /dev/null 2>&1; then
            echo "Docker Compose installed/updated successfully."
        else
            echo "Error: Docker Compose installation failed."
            return 1
        fi
    fi
}

# Function to install or update Git
install_or_update_git() {
    echo "Installing or updating Git..."
    if [[ "$OS_FAMILY" == "debian" || "$OS_FAMILY" == "wsl" ]]; then
        sudo apt-get update
        sudo apt-get install -y git
    elif [[ "$OS_FAMILY" == "arch" ]]; then
        sudo pacman -Sy --noconfirm git
    elif [[ "$OS_FAMILY" == "fedora" ]]; then
        sudo dnf install -y git
    elif [[ "$OS_FAMILY" == "suse" ]]; then
        sudo zypper install -y git
    else
        echo "Unsupported OS for automatic Git installation."
        return 1
    fi

    if ! command_exists git; then
        echo "Error: Git installation failed."
        return 1
    fi

    echo "Git installed/updated successfully."
}

# Main script execution

# Detect OS family
detect_os_family

# Check if Docker is installed and up to date
if command_exists docker; then
    echo "Docker is already installed. Version: $(docker --version)"
    if ! is_latest_docker; then
        echo "Docker is not the latest version. Attempting to update..."
        if ! install_or_update_docker; then
            echo "Error: Docker update failed."
            exit 1
        else
            echo "Docker updated successfully."
        fi
    else
        echo "Docker is up to date."
    fi
else
    echo "Docker is not installed. Attempting to install..."
    if ! install_or_update_docker; then
        echo "Error: Docker installation failed."
        exit 1
    else
        echo "Docker installed successfully."
    fi
fi

# Check if Docker Compose is installed
if docker compose version > /dev/null 2>&1; then
    echo "Docker Compose is already installed. Version: $(docker compose version --short)"
else
    echo "Docker Compose is not installed. Attempting to install..."
    if ! install_or_update_docker_compose; then
        echo "Error: Docker Compose installation failed."
        exit 1
    else
        echo "Docker Compose installed successfully."
    fi
fi

# Check if Git is installed
if command_exists git; then
    echo "Git is already installed. Version: $(git --version)"
else
    echo "Git is not installed. Attempting to install..."
    if ! install_or_update_git; then
        echo "Error: Git installation failed."
        exit 1
    else
        echo "Git installed successfully."
    fi
fi

echo "All installations are complete."
