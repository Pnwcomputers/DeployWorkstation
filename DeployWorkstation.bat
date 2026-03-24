@echo off
REM ========================================================
REM  DeployWorkstation.bat
REM  Launcher for DeployWorkstation.ps1
REM  Version 5.0 – PNWC Edition
REM ========================================================

setlocal enabledelayedexpansion

echo.
echo ===== DeployWorkstation Launcher v6.0 =====
echo.

REM --------------------------------------------------------
REM  1) Elevation check
REM     Re-launch this .bat elevated if not already admin.
REM --------------------------------------------------------
net session >nul 2>&1
if %errorlevel% neq 0 (
    echo Requesting administrative privileges...
    echo Please click "Yes" in the UAC prompt.
    echo.
    powershell.exe -NoProfile -Command ^
        "Start-Process -FilePath '%~f0' -Verb RunAs -Wait"
    exit /b
)

echo [OK] Running as Administrator.
echo.

REM --------------------------------------------------------
REM  2) Change to the directory containing this .bat
REM --------------------------------------------------------
pushd "%~dp0"

REM --------------------------------------------------------
REM  3) Verify the PowerShell script is present
REM --------------------------------------------------------
if not exist "DeployWorkstation.ps1" (
    echo [ERROR] DeployWorkstation.ps1 not found.
    echo         Expected: %~dp0DeployWorkstation.ps1
    echo.
    goto :error_exit
)

REM --------------------------------------------------------
REM  4) Menu
REM --------------------------------------------------------
:menu
echo Select deployment mode:
echo.
echo   1. Full deployment  (remove bloatware + install apps + configure system)
echo   2. Remove bloatware only
echo   3. Install apps only
echo   4. System configuration only
echo   5. Exit
echo.
set "choice="
set /p choice="Enter choice (1-5): "

set "ps_params="

if "%choice%"=="1" (
    echo.
    echo [*] Full deployment selected.
) else if "%choice%"=="2" (
    echo.
    echo [*] Bloatware removal only.
    set "ps_params=-SkipAppInstall -SkipSystemConfig"
) else if "%choice%"=="3" (
    echo.
    echo [*] App installation only.
    set "ps_params=-SkipBloatwareRemoval -SkipSystemConfig"
) else if "%choice%"=="4" (
    echo.
    echo [*] System configuration only.
    set "ps_params=-SkipBloatwareRemoval -SkipAppInstall"
) else if "%choice%"=="5" (
    echo Exiting.
    goto :normal_exit
) else (
    echo [!] Invalid choice - please try again.
    echo.
    goto :menu
)

REM --------------------------------------------------------
REM  5) Show what will run, then launch
REM --------------------------------------------------------
if "!ps_params!"=="" (
    echo     Parameters : (none - full run)
) else (
    echo     Parameters : !ps_params!
)
echo.
echo Starting Windows PowerShell 5.1...
echo.

if "!ps_params!"=="" (
    powershell.exe -NoProfile -ExecutionPolicy Bypass -File "DeployWorkstation.ps1"
) else (
    powershell.exe -NoProfile -ExecutionPolicy Bypass -File "DeployWorkstation.ps1" !ps_params!
)

REM Capture exit code immediately before anything can overwrite it
set "ps_exit=%errorlevel%"

REM --------------------------------------------------------
REM  6) Result
REM --------------------------------------------------------
echo.
if "%ps_exit%"=="0" (
    echo ===== Deployment completed successfully =====
) else (
    echo ===== Deployment finished with errors =====
    echo     Exit code : %ps_exit%
    echo     Check DeployWorkstation.log in this folder for details.
)

goto :normal_exit

REM --------------------------------------------------------
:error_exit
echo.
echo ===== Launch aborted =====
popd
pause
exit /b 1

REM --------------------------------------------------------
:normal_exit
popd
echo.
echo Press any key to close...
pause >nul
exit /b 0
