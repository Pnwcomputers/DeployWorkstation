@echo off
REM ========================================================
REM  DeployWorkstation.bat
REM  Launcher for DeployWorkstation.ps1
REM  Version 5.1 – PNWC Edition (fixed)
REM ========================================================

setlocal EnableExtensions EnableDelayedExpansion

echo.
echo ===== DeployWorkstation Launcher v5.1 =====
echo.

REM --------------------------------------------------------
REM  1) Elevation check
REM --------------------------------------------------------
net session >nul 2>&1
if errorlevel 1 (
    echo Requesting administrative privileges...
    echo Please click "Yes" in the UAC prompt.
    echo.
    powershell.exe -NoProfile -ExecutionPolicy Bypass -Command ^
        "Start-Process -FilePath '%~f0' -Verb RunAs"
    exit /b
)

echo [OK] Running as Administrator.
echo.

REM --------------------------------------------------------
REM  2) Change to the directory containing this .bat
REM --------------------------------------------------------
pushd "%~dp0"
if errorlevel 1 (
    echo [ERROR] Failed to access script folder.
    goto :error_exit
)

REM --------------------------------------------------------
REM  3) Verify the PowerShell script is present
REM --------------------------------------------------------
if not exist "%~dp0DeployWorkstation.ps1" (
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
set /p "choice=Enter choice (1-5): "

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
    set "ps_exit=0"
    goto :normal_exit
) else (
    echo [!] Invalid choice - please try again.
    echo.
    goto :menu
)

REM --------------------------------------------------------
REM  5) Show what will run, then launch
REM --------------------------------------------------------
if defined ps_params (
    echo     Parameters : !ps_params!
) else (
    echo     Parameters : (none - full run)
)
echo.
echo Starting Windows PowerShell 5.1...
echo.

powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%~dp0DeployWorkstation.ps1" !ps_params!

REM Capture exit code immediately
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
set "ps_exit=1"

REM --------------------------------------------------------
:normal_exit
popd
echo.
echo Press any key to close...
pause >nul
exit /b %ps_exit%
