@echo off
title DeployWorkstation Quick Start
setlocal

:start
echo.
echo ==========================================
echo   DeployWorkstation Quick Start v5.2
echo   Pacific Northwest Computers
echo ==========================================
echo.
echo Select a deployment option:
echo.
echo   1. Full Deployment  (bloatware removal + app install + system config)
echo   2. Install Apps Only
echo   3. System Configuration Only
echo   4. Update Installed Apps
echo   5. Exit
echo.
set /p choice="Enter your choice (1-5): "

if "%choice%"=="1" goto full
if "%choice%"=="2" goto apps_only
if "%choice%"=="3" goto config_only
if "%choice%"=="4" goto update
if "%choice%"=="5" goto exit_now
goto invalid

:full
echo.
echo Starting full deployment...
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0DeployWorkstation.ps1"
goto end

:apps_only
echo.
echo Installing applications only...
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0DeployWorkstation.ps1" -SkipBloatwareRemoval -SkipSystemConfig
goto end

:config_only
echo.
echo Running system configuration only...
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0DeployWorkstation.ps1" -SkipBloatwareRemoval -SkipAppInstall
goto end

:update
echo.
echo Updating installed applications...
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0DeployWorkstation.ps1" -SkipBloatwareRemoval -SkipSystemConfig -UpdateApps
goto end

:invalid
echo.
echo Invalid choice. Please enter 1-5.
pause
cls
goto start

:exit_now
endlocal
exit /b 0

:end
echo.
echo Done. Press any key to close.
pause >nul
endlocal
