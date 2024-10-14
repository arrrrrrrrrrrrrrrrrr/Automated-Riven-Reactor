#!/bin/bash

# create_troubleshooting_file.sh

# Check for root privileges
if [[ $EUID -ne 0 ]]; then
    echo "Error: This script must be run with administrative privileges. Please run with sudo."
    exit 1
fi

TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
TROUBLESHOOT_FILE="troubleshooting_$TIMESTAMP.txt"

echo "Creating troubleshooting file: $TROUBLESHOOT_FILE"

{
    echo "=== System Information ==="
    echo "Date: $(date)"
    echo "Hostname: $(hostname)"
    echo "Uptime: $(uptime -p)"
    echo "Logged in users:"
    who
    echo

    echo "=== Operating System ==="
    lsb_release -a 2>/dev/null || cat /etc/os-release
    echo

    echo "=== Docker Info ==="
    docker info
    echo

    echo "=== Docker Containers ==="
    docker ps -a
    echo

    echo "=== Docker Images ==="
    docker images
    echo

    echo "=== Environment Variables ==="
    # Exclude sensitive variables
    env | grep -v -E 'RIVEN_PLEX_TOKEN|RIVEN_PLEX_URL|RIVEN_DOWNLOADERS_REAL_DEBRID_API_KEY'
    echo

    echo "=== docker-compose.yml Contents ==="
    # Mask sensitive information in docker-compose.yml
    sed -e 's/\(RIVEN_PLEX_TOKEN:\).*/\1 [MASKED]/' \
        -e 's/\(RIVEN_PLEX_URL:\).*/\1 [MASKED]/' \
        -e 's/\(RIVEN_DOWNLOADERS_REAL_DEBRID_API_KEY:\).*/\1 [MASKED]/' \
        docker-compose.yml
    echo

    echo "=== Disk Usage ==="
    df -h
    echo

    echo "=== Network Configuration ==="
    ip addr show
    echo

    echo "=== Running Processes ==="
    ps aux
    echo

    echo "=== Docker Container Logs ==="
    CONTAINERS=$(docker ps -a -q)
    if [ -n "$CONTAINERS" ]; then
        for CONTAINER in $CONTAINERS; do
            CONTAINER_NAME=$(docker inspect --format='{{.Name}}' "$CONTAINER" | sed 's/^\/\|\/$//g')
            echo "--- Logs for container: $CONTAINER_NAME ($CONTAINER) ---"
            # Retrieve the last 1000 lines of logs to limit the output size
            docker logs --tail 1000 "$CONTAINER" 2>&1 | sed -e 's/\(.*\)RIVEN_PLEX_TOKEN=[^ ]*/\1RIVEN_PLEX_TOKEN=[MASKED]/g' \
                                                           -e 's/\(.*\)RIVEN_PLEX_URL=[^ ]*/\1RIVEN_PLEX_URL=[MASKED]/g' \
                                                           -e 's/\(.*\)RIVEN_DOWNLOADERS_REAL_DEBRID_API_KEY=[^ ]*/\1RIVEN_DOWNLOADERS_REAL_DEBRID_API_KEY=[MASKED]/g'
            echo
        done
    else
        echo "No Docker containers found."
    fi
    echo

} > "$TROUBLESHOOT_FILE"

# Set permissions to restrict access to the troubleshooting file
chmod 600 "$TROUBLESHOOT_FILE"
chown "$SUDO_USER":"$SUDO_USER" "$TROUBLESHOOT_FILE"

echo "Troubleshooting file created: $TROUBLESHOOT_FILE"
