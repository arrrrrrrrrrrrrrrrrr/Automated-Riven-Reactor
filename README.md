# Automatic Installation of Riven, Plex (Optional), and Zurg + rclone (Optional)

This script automates the installation of Riven, with optional setups for Plex Media Server and Zurg with rclone. It also installs WSL (on Windows) and Docker if they are not already present on the system.

## Instructions

1. **Place all the bash scripts in the folder where you intend to run your Docker containers.**
2. Depending on your system, run one of the following commands with **sudo/admin privileges** to start the installation:

   ### Linux Systems:

     ```bash
     sudo bash ./main_setup.sh
     ```

   ### Windows Systems:
   - WSL will be installed (the script will install it automatically if missing).
   - **Important**: Start the terminal with **admin privileges**.
   - Then, run the following command in WSL:
     ```bash
     bash ./main_setup.sh
     ```

## Notes
- This script will install WSL and Docker if they are missing from your system.
- Make sure you have the necessary permissions to run the script with administrative privileges.

## References

This project integrates the following:

- [Riven](https://github.com/rivenmedia/riven) from RivenMedia.
- [Zurg](https://github.com/debridmediamanager/zurg-testing) from Debrid Media Manager.
- [Plex Media Server](https://github.com/plexinc/pms-docker) from Plex, Inc.
