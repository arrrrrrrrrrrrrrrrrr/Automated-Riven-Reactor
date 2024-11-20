#!/bin/bash

# Exit on any error
set -e

# Function to check if a command exists
command_exists() {
    command -v "$1" &> /dev/null
}

# Detect the operating system and distribution
detect_os_family() {
    if [[ "$OSTYPE" == "darwin"* ]]; then
        OS_FAMILY="macos"
        OS_NAME="macos"
        OS_PRETTY_NAME="macOS"
        echo "Detected OS: $OS_PRETTY_NAME"
        echo "OS Family: $OS_FAMILY"
    elif [[ -f /etc/os-release ]]; then
        . /etc/os-release
        OS_NAME=$ID
        OS_VERSION=$VERSION_ID
        OS_PRETTY_NAME=$PRETTY_NAME
        OS_ID_LIKE=$ID_LIKE

        if [[ "$ID" =~ (ubuntu|debian) || "$ID_LIKE" =~ (debian) ]]; then
            OS_FAMILY="debian"
        elif [[ "$ID" =~ (arch) || "$ID_LIKE" =~ (arch) ]]; then
            OS_FAMILY="arch"
        elif [[ "$ID" =~ (fedora|rhel|centos) || "$ID_LIKE" =~ (fedora|rhel) ]]; then
            OS_FAMILY="fedora"
        elif [[ "$ID" =~ (opensuse|sles) || "$ID_LIKE" =~ (suse) ]]; then
            OS_FAMILY="suse"
        else
            OS_FAMILY="unknown"
        fi

        # Special handling for WSL
        if grep -qEi "(Microsoft|WSL)" /proc/version; then
            OS_FAMILY="wsl"
        fi

        echo "Detected OS: $OS_PRETTY_NAME"
        echo "OS Family: $OS_FAMILY"
    else
        echo "Error: Unable to detect the operating system."
        exit 1
    fi
}

# Function to check if a package is installed (for Arch)
is_package_installed() {
    pacman -Qi "$1" >/dev/null 2>&1
}

# Function to check if a package is available (for Arch)
is_package_available() {
    pacman -Si "$1" >/dev/null 2>&1
}

# Install rootless Docker dependencies
install_rootless_prerequisites() {
    local target_user=$1
    echo "Installing prerequisites for rootless Docker for user: $target_user"

    case $OS_FAMILY in
        debian|wsl)
            apt-get update
            apt-get install -y \
                uidmap \
                dbus-user-session \
                fuse-overlayfs \
                slirp4netns \
                curl \
                iptables
            ;;
        arch)
            # Update system first
            pacman -Syu --noconfirm

            # List of required packages
            local packages=()
            
            # Check each package
            is_package_installed "shadow" || packages+=("shadow")
            is_package_installed "dbus" || packages+=("dbus")
            is_package_installed "fuse-overlayfs" || packages+=("fuse-overlayfs")
            is_package_installed "slirp4netns" || packages+=("slirp4netns")
            is_package_installed "curl" || packages+=("curl")
            
            # Special handling for iptables
            if ! is_package_installed "iptables" && ! is_package_installed "iptables-nft"; then
                if is_package_installed "iptables-nft"; then
                    echo "iptables-nft is already installed, skipping iptables installation"
                else
                    packages+=("iptables-nft")
                fi
            fi

            # Install packages only if there are any missing
            if [ ${#packages[@]} -gt 0 ]; then
                echo "Installing missing packages: ${packages[*]}"
                pacman -S --noconfirm "${packages[@]}" || {
                    echo "Error installing packages. Please install them manually:"
                    echo "sudo pacman -S ${packages[*]}"
                    exit 1
                }
            else
                echo "All required packages are already installed."
            fi
            ;;
        fedora)
            dnf install -y \
                uidmap \
                dbus-daemon \
                fuse-overlayfs \
                slirp4netns \
                curl \
                iptables \
                shadow-utils
            ;;
        suse)
            zypper refresh
            zypper install -y \
                shadow \
                dbus-1 \
                fuse-overlayfs \
                slirp4netns \
                curl \
                iptables
            ;;
        *)
            echo "Error: Unsupported OS for rootless Docker."
            exit 1
            ;;
    esac

    # Ensure runtime directory exists for the target user
    su - "$target_user" -c 'mkdir -p /run/user/$(id -u)'
    su - "$target_user" -c 'chmod 700 /run/user/$(id -u)'
    return 0
}

# Install rootless Docker
install_rootless_docker() {
    local target_user=$1
    local target_home=$(getent passwd "$target_user" | cut -d: -f6)
    echo "Installing Docker in rootless mode for user: $target_user"

    # Create a temporary installation script
    cat > "$target_home/install_docker_rootless.sh" << 'EOF' || return 1
#!/bin/bash
set -e

# Setup environment
export XDG_RUNTIME_DIR="/run/user/$(id -u)"
mkdir -p "$XDG_RUNTIME_DIR"
chmod 700 "$XDG_RUNTIME_DIR"

# Download and run rootless installation script
curl -fsSL https://get.docker.com/rootless > ~/get-docker-rootless.sh
chmod +x ~/get-docker-rootless.sh
FORCE_ROOTLESS_INSTALL=1 ~/get-docker-rootless.sh

# Configure environment
cat >> ~/.bashrc << 'ENVEOF'
# Rootless Docker configuration
export XDG_RUNTIME_DIR="/run/user/$(id -u)"
export PATH="$HOME/bin:$PATH"
export DOCKER_HOST="unix://$XDG_RUNTIME_DIR/docker.sock"
ENVEOF

# Clean up
rm -f ~/get-docker-rootless.sh
EOF

    # Make the script executable and owned by target user
    chmod +x "$target_home/install_docker_rootless.sh" || return 1
    chown "$target_user:$(id -gn "$target_user")" "$target_home/install_docker_rootless.sh" || return 1

    # Enable lingering for the user
    loginctl enable-linger "$target_user" || return 1

    echo "Running rootless Docker installation as $target_user..."
    su - "$target_user" -c "./install_docker_rootless.sh" || {
        echo "Error: Rootless Docker installation failed"
        return 1
    }
    rm -f "$target_home/install_docker_rootless.sh"

    echo "Rootless Docker installation completed for user: $target_user"
    echo "Please log out and log back in for the changes to take effect."
    return 0
}

# Install normal Docker
install_normal_docker() {
    echo "Installing Docker in normal mode..."
    
    case $OS_FAMILY in
        debian|wsl)
            apt-get update
            apt-get install -y \
                apt-transport-https \
                ca-certificates \
                curl \
                gnupg \
                lsb-release
            
            mkdir -p /etc/apt/keyrings
            curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
            
            echo \
                "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
                $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null
            
            apt-get update
            apt-get install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin
            ;;
            
        arch)
            pacman -Syu --noconfirm
            pacman -S --noconfirm docker docker-compose
            systemctl enable --now docker
            ;;
            
        fedora)
            dnf -y install dnf-plugins-core
            dnf config-manager --add-repo https://download.docker.com/linux/fedora/docker-ce.repo
            dnf install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin
            systemctl enable --now docker
            ;;
            
        suse)
            zypper install -y docker docker-compose
            systemctl enable --now docker
            ;;
            
        *)
            echo "Error: Unsupported OS for Docker installation."
            exit 1
            ;;
    esac
    
    # Configure bridge module and network settings
    echo "Configuring bridge network settings..."
    
    # Load bridge module if not loaded
    if ! lsmod | grep -q "^bridge "; then
        echo "Loading bridge module..."
        modprobe bridge || {
            echo -e "${YELLOW}Warning: Could not load bridge module. This might be normal in some environments.${NC}"
        }
    fi

    # Make the bridge module load at boot
    if [ ! -d "/etc/modules-load.d" ]; then
        mkdir -p /etc/modules-load.d
    fi
    echo "bridge" > /etc/modules-load.d/bridge.conf

    # Configure sysctl settings for Docker
    echo "Configuring network bridge settings..."
    cat > /etc/sysctl.d/99-docker-bridge.conf << 'EOF'
net.bridge.bridge-nf-call-iptables = 1
net.bridge.bridge-nf-call-ip6tables = 1
net.ipv4.ip_forward = 1
EOF

    # Apply sysctl settings if possible
    if sysctl -p /etc/sysctl.d/99-docker-bridge.conf > /dev/null 2>&1; then
        echo "Network bridge settings applied successfully."
    else
        echo -e "${YELLOW}Warning: Could not apply network bridge settings. This might be normal in some environments.${NC}"
    fi

    # Add current user to docker group if specified
    if [ -n "$SUDO_USER" ]; then
        usermod -aG docker "$SUDO_USER"
        echo "Added user $SUDO_USER to docker group."
    fi
    
    echo "Docker installation completed successfully."
    return 0
}

install_macos_docker() {
    echo "Installing Docker for macOS..."
    if ! command -v brew &> /dev/null; then
        echo "Homebrew is required but not installed. Please install Homebrew first (https://brew.sh/)"
        exit 1
    }

    # Install Docker Desktop for Mac
    if ! brew list --cask docker &> /dev/null; then
        brew install --cask docker
    else
        echo "Docker is already installed"
    fi

    # Start Docker
    echo "Starting Docker..."
    open -a Docker
    
    # Wait for Docker to start
    echo "Waiting for Docker to start..."
    while ! docker info &> /dev/null; do
        sleep 1
    done
    
    echo "Docker has been successfully installed and started"
}

# Show usage information
show_usage() {
    echo "Usage: $0 [OPTIONS]"
    echo "Install Docker in either normal or rootless mode."
    echo ""
    echo "Options:"
    echo "  normal              Install Docker in normal mode (requires root)"
    echo "  rootless USERNAME   Install Docker in rootless mode for specified user (requires root)"
    echo ""
    echo "Examples:"
    echo "  $0 normal          # Install normal Docker"
    echo "  $0 rootless john   # Install rootless Docker for user 'john'"
}

# Main script execution
if [[ "$OSTYPE" == "darwin"* ]]; then
    install_macos_docker
else
    if [[ $EUID -ne 0 ]]; then
        echo "Error: This script must be run as root on Linux."
        exit 1
    fi

    detect_os_family || exit 1

    # Parse command line arguments
    case $1 in
        normal)
            install_normal_docker || exit 1
            ;;
        rootless)
            if [ -z "$2" ]; then
                echo "Error: Username required for rootless installation."
                show_usage
                exit 1
            fi
            
            # Check if user exists
            if ! id "$2" &>/dev/null; then
                echo "Error: User $2 does not exist."
                exit 1
            fi
            
            install_rootless_prerequisites "$2" || exit 1
            install_rootless_docker "$2" || exit 1
            ;;
        *)
            show_usage
            exit 1
            ;;
    esac

    exit 0
fi
