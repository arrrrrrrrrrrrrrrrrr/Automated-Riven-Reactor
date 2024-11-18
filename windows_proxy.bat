@echo off
setlocal enabledelayedexpansion

:: Check if running as administrator
net session >nul 2>&1
if %errorlevel% neq 0 (
    echo This script must be run as administrator
    pause
    exit /b 1
)

:: Check WSL network status
echo Checking WSL network status...
wsl ping -c 1 8.8.8.8 >nul 2>&1
if %errorlevel% neq 0 (
    echo WSL network is not properly configured. Please check your WSL installation.
    exit /b 1
)

:: Fetch the WSL IP dynamically using PowerShell and only pick the first IP
for /f "tokens=1" %%i in ('powershell -command "wsl hostname -I"') do set WSL_IP=%%i

:: Get the local machine's IP address for user confirmation
for /f "tokens=2 delims=:" %%i in ('ipconfig ^| findstr "IPv4"') do set USER_IP=%%i
set USER_IP=%USER_IP: =%

:: Define default ports
set DEFAULT_PORT=3000
set PLEX_PORT=32400

:: Initialize list of additional ports to process later
set ADDITIONAL_PORTS=

:: Ask about firewall rules
set /p CONFIGURE_FIREWALL="Do you want to allow external devices on your network to access these ports? (Y/N): "
if /i "%CONFIGURE_FIREWALL%"=="Y" (
    echo Firewall rules will be configured to allow external access.
) else (
    echo Firewall rules will not be modified. Only local access will be possible.
)

:: Function to validate port number
:validate_port
set PORT=%1
if %PORT% LSS 1 (
    echo Invalid port number: %PORT%
    exit /b 1
)
if %PORT% GTR 65535 (
    echo Invalid port number: %PORT%
    exit /b 1
)
goto :eof

:: Step 1: Ensure port 3000 is proxied
echo Ensuring port %DEFAULT_PORT% is proxied...
call :validate_port %DEFAULT_PORT%
if %errorlevel% equ 0 (
    call :proxy_port %DEFAULT_PORT%
)

:: Step 2: Ask if user wants Plex (32400) to be proxied via their machine IP
set /p PROXY_PLEX="Do you want to access Plex via %USER_IP%:%PLEX_PORT%? (Y/N): "
if /i "%PROXY_PLEX%"=="Y" (
    echo Adding Plex port %PLEX_PORT% to the list for proxying...
    call :validate_port %PLEX_PORT%
    if %errorlevel% equ 0 (
        set ADDITIONAL_PORTS=%PLEX_PORT%
    )
)

:: Step 3: Ask if user wants to proxy any other ports
set /p ADD_PORTS="Do you want to make any other ports accessible via %USER_IP%:? (Y/N): "
if /i "%ADD_PORTS%"=="Y" (
    set /p ADDITIONAL_PORTS_INPUT="Enter the port(s) you want to proxy (comma-separated, e.g., 8080,9090): "
    
    :: Process the input and append to ADDITIONAL_PORTS
    for %%p in (%ADDITIONAL_PORTS_INPUT%) do (
        call :validate_port %%p
        if %errorlevel% equ 0 (
            set ADDITIONAL_PORTS=!ADDITIONAL_PORTS! %%p
        )
    )
)

:: Step 4: Process all additional ports collected
if not "%ADDITIONAL_PORTS%"=="" (
    echo Processing the following ports: %ADDITIONAL_PORTS%
    for %%p in (%ADDITIONAL_PORTS%) do (
        call :proxy_port %%p
    )
)

:: End of script
echo All ports have been configured successfully!
goto :eof

:: Function to proxy a port and configure firewall
:proxy_port
set PORT=%1
echo Checking if port %PORT% is already proxied...

:: Check if the port proxy rule already exists
netsh interface portproxy show v4tov4 | findstr "%PORT%" >nul
if %ERRORLEVEL% equ 0 (
    echo Port forwarding already exists for port %PORT%
    goto :configure_firewall
)

:: Add port forwarding rule to proxy the specified port for all interfaces
echo Adding port forwarding for 0.0.0.0:%PORT% to WSL2 IP %WSL_IP%:%PORT%
netsh interface portproxy add v4tov4 listenaddress=0.0.0.0 listenport=%PORT% connectaddress=%WSL_IP% connectport=%PORT%

:configure_firewall
:: Only configure firewall if user chose to do so
if /i "%CONFIGURE_FIREWALL%"=="Y" (
    :: Configure the firewall - only add if it doesn't exist
    netsh advfirewall firewall show rule name="Allow Port %PORT%" >nul 2>&1
    if %ERRORLEVEL% neq 0 (
        echo Adding firewall rule for port %PORT% to allow external access...
        netsh advfirewall firewall add rule name="Allow Port %PORT%" dir=in action=allow protocol=TCP localport=%PORT%
    ) else (
        echo Firewall rule already exists for port %PORT%
    )
) else (
    echo Skipping firewall configuration for port %PORT% as per user choice.
)

:: Show current configuration for this port
echo Current port proxy configuration for port %PORT%:
netsh interface portproxy show v4tov4 | findstr "%PORT%"

goto :eof
