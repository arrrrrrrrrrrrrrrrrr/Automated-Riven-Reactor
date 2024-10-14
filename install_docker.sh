#!/bin/bash

# install_docker.sh

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
    local_installed_version=$(docker version --format '{{.Server.Version}}')
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
        elif grep -qEi "(Microsoft|WSL)" /proc/version &> /dev/null; then
            OS_FAMILY="wsl"
        else
            OS_FAMILY="unknown"
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

    if [[ "$OS_FAMILY" == "debian" ]]; then
        sudo apt-get update
        sudo apt-get install -y docker-ce docker-ce-cli containerd.io

        # Enable and start Docker
        sudo systemctl enable docker
        sudo systemctl start docker

        # Add user to docker group
        sudo usermod -aG docker "$SUDO_USER"

    elif [[ "$OS_FAMILY" == "arch" ]]; then
        sudo pacman -Syu --noconfirm
        sudo pacman -Sy --noconfirm docker

        # Enable and start Docker service
        sudo systemctl enable docker
        sudo systemctl start docker

        # Add user to docker group
        sudo usermod -aG docker "$SUDO_USER"

    elif [[ "$OS_FAMILY" == "fedora" ]]; then
        sudo dnf -y install docker-ce docker-ce-cli containerd.io

        # Start Docker
        sudo systemctl enable docker
        sudo systemctl start docker

        # Add user to docker group
        sudo usermod -aG docker "$SUDO_USER"

    elif [[ "$OS_FAMILY" == "suse" ]]; then
        sudo zypper refresh
        sudo zypper install -y docker

        # Start Docker
        sudo systemctl enable docker
        sudo systemctl start docker

        # Add user to docker group
        sudo usermod -aG docker "$SUDO_USER"

    elif [[ "$OS_FAMILY" == "wsl" ]]; then
        echo "Detected WSL. Installing Docker Desktop is recommended."
        echo "Please install Docker Desktop for Windows and enable WSL integration."
        return 1
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

    DOCKER_COMPOSE_VERSION=$(curl -s https://api.github.com/repos/docker/compose/releases/latest | grep -Po '"tag_name": "\K.*?(?=")')
    if [[ -z "$DOCKER_COMPOSE_VERSION" ]]; then
        DOCKER_COMPOSE_VERSION="2.29.2"
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

    if ! command_exists docker-compose; then
        echo "Error: Docker Compose installation failed."
        return 1
    fi
}

# Function to install or update Git
install_or_update_git() {
    echo "Installing or updating Git..."
    if [[ "$OS_FAMILY" == "debian" ]]; then
        sudo apt-get update
        sudo apt-get install -y git
    elif [[ "$OS_FAMILY" == "arch" ]]; then
        sudo pacman -Sy --noconfirm git
    elif [[ "$OS_FAMILY" == "fedora" ]]; then
        sudo dnf install -y git
    else
        echo "Unsupported OS for automatic Git installation."
        return 1
    fi

    if ! command_exists git; then
        echo "Error: Git installation failed."
        return 1
    fi
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
if command_exists docker-compose; then
    echo "Docker Compose is already installed. Version: $(docker-compose --version)"
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
