# Automatic Installation of Riven, Plex (Optional), and Zurg + rclone (Optional)

This script automates the installation of Riven, with optional setups for Plex Media Server and Zurg using rclone. It also installs WSL (on Windows) and Docker if they are not already installed on the system.

## Prerequisite

- You will need your **Real-Debrid API token**. To obtain this, visit [https://real-debrid.com/apitoken](https://real-debrid.com/apitoken) and generate your token. This token is necessary for integrating Real-Debrid with Riven and Zurg.

## Installation Instructions

### Step 1: Prepare the Folder
- Place all the bash scripts in the directory where you plan to run your Docker containers.

### Step 2: Start the Installation
- Depending on your operating system, follow the instructions below to begin the installation. **Make sure to use sudo/admin privileges**.

#### Linux Systems:
1. Open a terminal with appropriate permissions.
2. Run the following command to start the setup:

    ```bash
    sudo bash ./main_setup.sh
    ```

#### Windows Systems:
1. The script will install WSL automatically if it is not already present.
2. **Important**: Launch the **Terminal** with **administrator privileges**.
3. Once the terminal is open, run the following command in WSL to begin installation:

    ```bash
    ./windows_install.bat
    ```

4. If WSL was installed using this script, set up a username and password when prompted. After WSL starts, type `exit` to continue the setup. Enter the newly set password if prompted.

### Step 3: Optional Components
- Plex Media Server and Zurg with rclone are optional setups in this script. You can choose to install them during the process.

## Notes
- The script will handle the installation of WSL and Docker on Windows systems if they are missing.
- Make sure you have the necessary permissions to execute the script with administrative privileges.

## Need Help?

If you need assistance with installation or configuration, join our Discord community for help by clicking the button below:

[![Discord](https://img.shields.io/badge/Discord-Join%20us-7289DA?style=for-the-badge&logo=discord)](https://discord.gg/XTRvJxcF)

## References

This project integrates the following components:

- [Riven](https://github.com/rivenmedia/riven) from RivenMedia.
- [Zurg](https://github.com/debridmediamanager/zurg-testing) from Debrid Media Manager.
- [Plex Media Server](https://github.com/plexinc/pms-docker) from Plex, Inc.
