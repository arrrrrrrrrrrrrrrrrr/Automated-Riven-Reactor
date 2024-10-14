# Automated Installation of Riven, Plex (Optional), and Zurg with rclone

This script simplifies the installation of Riven and provides optional setups for Plex Media Server and Zurg, integrated with rclone. For Windows users, it also automatically installs WSL (Windows Subsystem for Linux) and Docker if not already present.

## Prerequisites

- You will need your **Real-Debrid API token** to integrate Real-Debrid with Riven and Zurg. To obtain your token, visit [Real-Debrid API Token](https://real-debrid.com/apitoken) and generate it.

## Installation Instructions

### Step 1: Prepare the Directory
- Place all the provided bash scripts in the directory where you intend to run your Docker containers.

### Step 2: Start the Installation
- Follow the appropriate steps for your operating system, ensuring you use **sudo/admin privileges** during the process.

#### Linux Systems:
1. Open a terminal with the necessary permissions.
2. Start the installation by running:

    ```bash
    sudo bash ./main_setup.sh
    ```

#### Windows Systems:
1. The script will automatically install WSL if it’s not already on your system.
2. **Important**: Open **Terminal** as an **Administrator**.
3. In WSL, start the installation by running:

    ```bash
    ./windows_install.bat
    ```

4. If WSL was installed during this process, set up a username and password when prompted. After WSL starts, type `exit` to continue. Use the newly created password when needed.

5. **Troubleshooting Tip**: If you’re unable to access the Riven site after installation, run:

    ```bash
    .\windows_proxy.bat
    ```

#### NOTE
- During installation, you’ll have the option to install Plex Media Server.
- Zurg and rclone will be automatically installed **only if they are present** in the directory. If they are already installed, the script will skip their installation.

## windows_proxy.bat: Proxy WSL Docker Bridge IP to Machine IP

The `windows_proxy.bat` script is designed to simplify access to Docker containers running inside WSL by binding the Docker network's bridge (NAT) IP (typically in the 172.x.x.x range) to your Windows machine's IP address.

This allows any service running inside Docker containers, including Riven, Plex, or other applications, to be accessed using your machine's IP address rather than the internal Docker IP. This makes the containers easily reachable from outside the WSL environment without complex networking setups.

Running `windows_proxy.bat` will ensure that any ports exposed by Docker containers in WSL will be proxied to your machine's IP, providing seamless access to all containerized services.



## Post-Installation Information

After installation, the following default configurations will be set up:

- **Rclone Path**: The default mount point for Rclone is `/mnt/zurg/__all__`. This is where remote media will be accessible for further processing or integration with Riven and Plex.
  
- **Library Path**: The local media library is located at `/mnt/library`, where Riven and Plex scan, manage, and serve your content.

- **Riven Configuration**: You can find the `settings.json` file for Riven in the `riven` folder, located in the same directory where the scripts reside.

- **Riven Database**: The Riven database is stored in `/home/docker/riven-db`.

- **Zurg/Rclone Information**: Zurg and rclone-related files are located in the `zurg` folder, alongside the installation scripts. If they are already installed, the script will skip their reinstallation.

- **Troubleshooting Logs**: Any troubleshooting logs generated after running the script will be saved as `troubleshoot-<timestamp>.txt` in the same directory as the script.

- **Plex URL**: If you set up Plex using this script, then the Plex's URL for Riven to recognize will be `http://plex:32400`.

You can adjust these paths if needed, but ensure any changes are reflected in the appropriate configuration files to ensure smooth operation across Riven, Plex, and other services.

**For further assistance with setup or onboarding, visit the [Riven Wiki](https://rivenmedia.github.io/wiki/) for detailed guides and troubleshooting help.**

We also encourage you to join our Discord community for additional support and discussions. Click below to join:

[![Discord](https://img.shields.io/badge/Discord-Join%20us-7289DA?style=for-the-badge&logo=discord)](https://discord.gg/XTRvJxcF)

## Need Help?

If you need any help with installation or configuration, feel free to join our Discord community by clicking the button above.

## References

This project integrates with the following components:

- [Riven](https://github.com/rivenmedia/riven) by RivenMedia.
- [Zurg](https://github.com/debridmediamanager/zurg-testing) by Debrid Media Manager.
- [Plex Media Server](https://github.com/plexinc/pms-docker) by Plex, Inc.
