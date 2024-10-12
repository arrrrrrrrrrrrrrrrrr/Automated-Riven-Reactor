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
- The script will automatically install WSL if it is not already installed.
- **Important**: Run the terminal with **administrator privileges**.
- Then, execute the following command within WSL:
  
  ```bash
  ./windows_install.bat

If WSL was installed by this script, once you set up a username and password for WSL, it will start. Type exit to continue, and input the password if prompted.

## References

This project integrates the following:

- [Riven](https://github.com/rivenmedia/riven) from RivenMedia.
- [Zurg](https://github.com/debridmediamanager/zurg-testing) from Debrid Media Manager.
- [Plex Media Server](https://github.com/plexinc/pms-docker) from Plex, Inc.
