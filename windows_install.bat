@echo off
setlocal enabledelayedexpansion

:: Set working directory to the directory where the script is located
cd /d "%~dp0"

:: Check if the script is being run as administrator
net session >nul 2>&1
if %errorlevel% neq 0 (
    echo This script must be run as administrator. Please run this .bat file with administrative privileges.
    pause
    exit /b 1
)

:: Check Windows version compatibility
ver | findstr /i "10\." >nul
if %errorlevel% neq 0 (
    ver | findstr /i "11\." >nul
    if %errorlevel% neq 0 (
        echo This script requires Windows 10 or 11.
        pause
        exit /b 1
    )
)

:: Enable Windows features
echo Enabling required Windows features...
dism.exe /online /enable-feature /featurename:Microsoft-Windows-Subsystem-Linux /all /norestart
dism.exe /online /enable-feature /featurename:VirtualMachinePlatform /all /norestart

:: Check if WSL is installed and get version
echo Checking WSL installation...
wsl --status >nul 2>&1
if %errorlevel% neq 0 (
    echo WSL is not installed. Proceeding with installation...
    wsl --install
    echo A system restart may be required to complete WSL installation.
    echo Please run this script again after restart if needed.
    pause
    exit /b 0
)

:: Ensure WSL 2 is set as default
echo Setting WSL 2 as default...
wsl --set-default-version 2

:: Check if Ubuntu is installed and its version
echo Checking Ubuntu installation...
wsl -l -v | findstr "Ubuntu" >nul
if %errorlevel% neq 0 (
    echo Installing Ubuntu...
    wsl --install -d Ubuntu
    echo Waiting for Ubuntu installation to complete...
    echo Note: You may need to set up a username and password in the Ubuntu window that opens.
    timeout /t 30 /nobreak >nul
    
    :: Verify Ubuntu installation
    wsl -d Ubuntu echo "Testing Ubuntu..." >nul 2>&1
    if %errorlevel% neq 0 (
        echo Ubuntu installation requires additional setup.
        echo Please complete the Ubuntu setup in the window that opened and run this script again.
        pause
        exit /b 0
    )
)

:: Update WSL kernel and Ubuntu
echo Updating WSL...
wsl --update
wsl bash -c "sudo apt-get update && sudo apt-get upgrade -y"

:: Ensure the default distribution is Ubuntu
echo Setting Ubuntu as default WSL distribution...
wsl --set-default Ubuntu

:: Check Docker prerequisites
echo Checking Docker prerequisites...
wsl bash -c "if ! command -v docker &> /dev/null; then echo Docker not found.; fi"

:: Create and prepare Automated-Riven directory
echo Preparing installation directory...
wsl bash -c "mkdir -p ~/Automated-Riven"

:: Copy files to WSL
echo Copying files to WSL...
for /f "delims=" %%i in ('wsl wslpath "%cd%"') do set current_wsl_path=%%i
wsl bash -c "cp -r \"%current_wsl_path%\"/* \"$HOME/Automated-Riven/\""

:: Configure sudo access (with warning)
echo Configuring sudo access...
echo Warning: This will allow passwordless sudo access for installation.
set /p SUDO_CONFIRM="Do you want to continue? (Y/N): "
if /i "%SUDO_CONFIRM%"=="Y" (
    wsl bash -c "echo \"$(whoami) ALL=(ALL) NOPASSWD:ALL\" | sudo tee /etc/sudoers.d/automated-riven > /dev/null"
) else (
    echo Setup cancelled by user.
    pause
    exit /b 1
)

:: Run main setup
echo Starting main setup...
wsl bash -c "cd ~/Automated-Riven && sudo bash ./main_setup.sh"

echo Installation completed!
echo Note: If you encounter any issues, please check the troubleshooting guide.
pause