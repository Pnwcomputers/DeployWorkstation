@echo off
title DeployWorkstation Quick Start
echo.
echo ==========================================
echo   DeployWorkstation Quick Start Wizard
echo ==========================================
echo.
echo Select your deployment profile:
echo.
echo 1. Standard Business (Recommended)
echo 2. Developer Workstation
echo 3. Home User
echo 4. Custom Configuration
echo 5. Exit
echo.
set /p choice="Enter your choice (1-5): "

if "%choice%"=="1" goto business
if "%choice%"=="2" goto developer  
if "%choice%"=="3" goto home
if "%choice%"=="4" goto custom
if "%choice%"=="5" goto exit
goto invalid

:business
echo Starting Standard Business deployment...
powershell.exe -ExecutionPolicy Bypass -File "%~dp0DeployWorkstation.ps1" -ConfigFile "%~dp0Config\Examples\Corporate.json"
goto end

:developer
echo Starting Developer Workstation deployment...
powershell.exe -ExecutionPolicy Bypass -File "%~dp0DeployWorkstation.ps1" -ConfigFile "%~dp0Config\Examples\Developer.json"
goto end

:home
echo Starting Home User deployment...
powershell.exe -ExecutionPolicy Bypass -File "%~dp0DeployWorkstation.ps1" -ConfigFile "%~dp0Config\Examples\HomeUser.json"
goto end

:custom
echo.
set /p configfile="Enter path to your configuration file: "
powershell.exe -ExecutionPolicy Bypass -File "%~dp0DeployWorkstation.ps1" -ConfigFile "%configfile%"
goto end

:invalid
echo Invalid choice. Please try again.
pause
cls
goto start

:exit
echo Exiting...
exit

:end
echo.
echo Deployment completed. Press any key to exit.
pause
