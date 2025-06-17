@echo off
REM ========================================================
REM  DeployWorkstation-Launcher.bat
REM  Ensures elevation, then runs DeployWorkstation-Modular.ps1
REM  Compatible with the modular PowerShell script v3.0
REM ========================================================
setlocal enabledelayedexpansion
echo.
echo ===== DeployWorkstation Launcher v3.0 =====
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
if not exist "DeployWorkstation-Modular.ps1" (
    echo ERROR: DeployWorkstation-Modular.ps1 not found in current directory!
    echo Expected location: %~dp0DeployWorkstation-Modular.ps1
    echo.
    echo Please ensure the following files are present:
    echo   - DeployWorkstation-Modular.ps1
    echo   - All DeployWorkstation.*.psm1 module files
    echo.
    goto :error_exit
)

REM 5) Show enhanced options menu
echo Available deployment options:
echo.
echo   1. Full deployment (Essential apps)
echo   2. Full deployment (Business apps)
echo   3. Full deployment (Developer apps)
echo   4. Full deployment (Multimedia apps)
echo   5. Remove bloatware only
echo   6. Install apps only (Essential)
echo   7. Install apps only (Business)
echo   8. Install apps only (Developer)
echo   9. Install apps only (Multimedia)
echo  10. System configuration only
echo  11. Offline mode (no internet required)
echo  12. What-If mode (preview changes)
echo  13. Exit
echo.
set /p choice="Enter your choice (1-13): "

REM 6) Set PowerShell parameters based on choice
set "ps_params="
if "%choice%"=="1" (
    echo Running full deployment with Essential apps...
    set "ps_params=-AppSuite Essential"
) else if "%choice%"=="2" (
    echo Running full deployment with Business apps...
    set "ps_params=-AppSuite Business"
) else if "%choice%"=="3" (
    echo Running full deployment with Developer apps...
    set "ps_params=-AppSuite Developer"
) else if "%choice%"=="4" (
    echo Running full deployment with Multimedia apps...
    set "ps_params=-AppSuite Multimedia"
) else if "%choice%"=="5" (
    echo Running bloatware removal only...
    set "ps_params=-SkipAppInstall -SkipSystemConfiguration"
) else if "%choice%"=="6" (
    echo Installing Essential apps only...
    set "ps_params=-SkipBloatwareRemoval -SkipSystemConfiguration -AppSuite Essential"
) else if "%choice%"=="7" (
    echo Installing Business apps only...
    set "ps_params=-SkipBloatwareRemoval -SkipSystemConfiguration -AppSuite Business"
) else if "%choice%"=="8" (
    echo Installing Developer apps only...
    set "ps_params=-SkipBloatwareRemoval -SkipSystemConfiguration -AppSuite Developer"
) else if "%choice%"=="9" (
    echo Installing Multimedia apps only...
    set "ps_params=-SkipBloatwareRemoval -SkipSystemConfiguration -AppSuite Multimedia"
) else if "%choice%"=="10" (
    echo Running system configuration only...
    set "ps_params=-SkipAppInstall -SkipBloatwareRemoval"
) else if "%choice%"=="11" (
    echo Running in offline mode...
    set "ps_params=-UseOfflineFallback -AppSuite Essential"
) else if "%choice%"=="12" (
    echo Running in What-If mode (preview only)...
    set "ps_params=-WhatIf -AppSuite Essential"
) else if "%choice%"=="13" (
    echo Exiting...
    goto :normal_exit
) else (
    echo Invalid choice. Running full deployment with Essential apps...
    set "ps_params=-AppSuite Essential"
)

echo.
echo Starting PowerShell script with Windows PowerShell 5.1...
echo Parameters: %ps_params%
echo.

REM 7) Run the PowerShell script with proper parameters
if "%ps_params%"=="" (
    powershell.exe -NoProfile -ExecutionPolicy Bypass -File "DeployWorkstation-Modular.ps1"
) else (
    powershell.exe -NoProfile -ExecutionPolicy Bypass -File "DeployWorkstation-Modular.ps1" %ps_params%
)

REM 8) Check exit code and report results
if %errorlevel% equ 0 (
    echo.
    echo ===== Deployment completed successfully =====
    echo.
    echo The deployment process has finished. Check the console output
    echo and log files for detailed information about what was changed.
) else (
    echo.
    echo ===== Deployment completed with errors =====
    echo Exit code: %errorlevel%
    echo.
    echo Please check:
    echo   - The console output above for error messages
    echo   - Log files in the script directory
    echo   - Ensure all required .psm1 module files are present
)

goto :normal_exit

:error_exit
echo.
echo ===== Deployment failed =====
echo.
echo Common solutions:
echo   - Ensure you're running as Administrator
echo   - Verify all PowerShell module files (.psm1) are present
echo   - Check that PowerShell execution policy allows script execution
echo.
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
