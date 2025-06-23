@echo off
REM ========================================================
REM  DeployWorkstation-Launcher.bat
REM  Ensures elevation, then runs DeployWorkstation.ps1
REM  Compatible with the optimized PowerShell script
REM ========================================================

setlocal enabledelayedexpansion

echo.
echo ===== DeployWorkstation Launcher =====
echo.

REM 1) Check if we're already elevated
net session >nul 2>&1
if %errorlevel% neq 0 (
    echo Requesting administrative privileges...
    echo Please click "Yes" in the UAC prompt that appears.
    echo.
    
    REM Re-launch this batch file with elevation
    powershell.exe -NoProfile -Command ^
      "Start-Process -FilePath '%~f0' -Verb RunAs -Wait"
    
    REM Exit the non-elevated instance
    exit /b
)

REM 2) We're now elevated - show confirmation
echo Administrative privileges confirmed.
echo Current directory: %~dp0
echo.

REM 3) Change to script directory
pushd "%~dp0"

REM 4) Check if PowerShell script exists
if not exist "DeployWorkstation.ps1" (
    echo ERROR: DeployWorkstation.ps1 not found in current directory!
    echo Expected location: %~dp0DeployWorkstation.ps1
    echo.
    goto :error_exit
)

REM 5) Show options menu
echo Available options:
echo   1. Full deployment (remove bloatware + install apps)
echo   2. Remove bloatware only
echo   3. Install apps only
echo   4. Exit
echo.
set /p choice="Enter your choice (1-4): "

REM 6) Set PowerShell parameters based on choice
set "ps_params="
if "%choice%"=="1" (
    echo Running full deployment...
    set "ps_params="
) else if "%choice%"=="2" (
    echo Running bloatware removal only...
    set "ps_params=-SkipAppInstall"
) else if "%choice%"=="3" (
    echo Running app installation only...
    set "ps_params=-SkipBloatwareRemoval"
) else if "%choice%"=="4" (
    echo Exiting...
    goto :normal_exit
) else (
    echo Invalid choice. Running full deployment...
    set "ps_params="
)

echo.
echo Starting PowerShell script with Windows PowerShell 5.1...
echo Parameters: %ps_params%
echo.

REM 7) Run the PowerShell script with proper parameters
if "%ps_params%"=="" (
    powershell.exe -NoProfile -ExecutionPolicy Bypass -File "DeployWorkstation.ps1"
) else (
    powershell.exe -NoProfile -ExecutionPolicy Bypass -File "DeployWorkstation.ps1" %ps_params%
)

REM 8) Check exit code and report results
if %errorlevel% equ 0 (
    echo.
    echo ===== Deployment completed successfully =====
) else (
    echo.
    echo ===== Deployment completed with errors =====
    echo Exit code: %errorlevel%
    echo Check the log file for details.
)

goto :normal_exit

:error_exit
echo.
echo ===== Deployment failed =====
popd
pause
exit /b 1

:normal_exit
REM 9) Return to original directory and pause
popd
echo.
echo Press any key to exit...
pause >nul
exit /b 0
