@echo off
:: Set working directory to the directory where the script is located
cd /d "%~dp0"

:: Check if the script is being run as administrator
net session >nul 2>&1
if %errorlevel% neq 0 (
    echo This script must be run as administrator. Please run this .bat file with administrative privileges.
    pause
    exit /b 1
)

:: Check if WSL is installed
echo Checking if WSL is installed...
wsl --status >nul 2>&1
if %errorlevel% neq 0 (
    echo WSL is not installed. Proceeding with installation...
    wsl --install

    :: Check if the WSL installation was successful
    echo Checking if WSL installation was successful...
    wsl --status >nul 2>&1
    if %errorlevel% neq 0 (
        echo WSL installation failed. Exiting...
        exit /b 1
    )
    echo WSL installed successfully.
)

:: Check if a WSL distribution is installed
echo Checking if a WSL distribution is installed...
wsl -l -v >nul 2>&1
if %errorlevel% neq 0 (
    echo No WSL distribution found. Installing Ubuntu...
    wsl --install -d Ubuntu
    echo Waiting for Ubuntu to finish installation...
    timeout /t 10 /nobreak >nul
)

:: Ensure the default distribution is set and up to date
echo Setting the default WSL distribution to Ubuntu...
wsl --set-default Ubuntu
wsl --update

:: Move files and execute script

:: Get WSL home path
for /f "delims=" %%i in ('wsl wslpath ~') do set wsl_home_path=%%i

:: Create the Automated-Riven directory in WSL and move files
echo Moving files to WSL home directory...
wsl bash -c "mkdir -p ~/Automated-Riven && rm -rf ~/Automated-Riven/*"

:: Use WSL cp to copy files from Windows to WSL
for /f "delims=" %%i in ('wsl wslpath "%cd%"') do set current_wsl_path=%%i
wsl bash -c "cp -r \"%current_wsl_path%\"/* \"$HOME/Automated-Riven/\""

:: Ensure passwordless sudo for the current WSL user
echo Configuring passwordless sudo for WSL user...
wsl bash -c "echo \"$(whoami) ALL=(ALL) NOPASSWD:ALL\" | sudo tee -a /etc/sudoers > /dev/null"

:: Run main_setup.sh using sudo in WSL from $HOME/Automated-Riven
echo Starting main_setup.sh with sudo...
wsl bash -c "cd ~/Automated-Riven && sudo bash ./main_setup.sh"

pause
