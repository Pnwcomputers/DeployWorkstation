@echo off
setlocal EnableExtensions EnableDelayedExpansion

echo.
echo ===== DeployWorkstation Launcher v6.0 =====
echo.

rem Relaunch elevated if needed
net session >nul 2>&1
if errorlevel 1 (
    echo Requesting administrative privileges...
    powershell.exe -NoProfile -ExecutionPolicy Bypass -Command ^
        "Start-Process -FilePath '%~f0' -Verb RunAs"
    exit /b
)

pushd "%~dp0" || (
    echo [ERROR] Could not access script folder.
    pause
    exit /b 1
)

if not exist "%~dp0DeployWorkstation.ps1" (
    echo [ERROR] DeployWorkstation.ps1 not found.
    echo Expected: %~dp0DeployWorkstation.ps1
    set "ps_exit=1"
    goto :done
)

powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%~dp0DeployWorkstation.ps1"
set "ps_exit=%errorlevel%"

echo.
if "%ps_exit%"=="0" (
    echo ===== Deployment completed successfully =====
) else (
    echo ===== Deployment completed with warnings or errors =====
    echo Exit code: %ps_exit%
    echo Review DeployWorkstation.log and DeployWorkstation.html in this folder.
)

:done
popd
echo.
echo Press any key to close...
pause >nul
exit /b %ps_exit%
