@echo off
setlocal enabledelayedexpansion

REM ========================================================
REM  DeployWorkstation-Launcher.bat v3.0
REM  Enhanced launcher for DeployWorkstation-AllUsers.ps1
REM  Supports new parameters: DryRun, Export/Import, etc.
REM ========================================================

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
set "ps_script="
if exist "DeployWorkstation-AllUsers.ps1" (
    set "ps_script=DeployWorkstation-AllUsers.ps1"
) else if exist "DeployWorkstation.ps1" (
    set "ps_script=DeployWorkstation.ps1"
) else (
    echo ERROR: PowerShell script not found in current directory!
    echo Expected: DeployWorkstation-AllUsers.ps1 or DeployWorkstation.ps1
    echo Location: %~dp0
    echo.
    echo Files in current directory:
    dir /b *.ps1
    echo.
    goto :error_exit
)

echo Found PowerShell script: %ps_script%
echo.

REM 5) Show enhanced options menu
echo +===============================================================+
echo ^|                    DEPLOYMENT OPTIONS                        ^|
echo +===============================================================+
echo ^|  1. Full deployment (remove bloatware + install apps)        ^|
echo ^|  2. Remove bloatware only                                    ^|
echo ^|  3. Install apps only                                        ^|
echo ^|  4. Install apps only (skip Java runtimes)                   ^|
echo ^|  5. DRY RUN - Test mode (no actual changes)                  ^|
echo ^|  6. Export installed winget apps to apps.json                ^|
echo ^|  7. Import apps from apps.json                               ^|
echo ^|  8. Full deployment + import apps.json                       ^|
echo ^|  9. Exit                                                     ^|
echo +===============================================================+
echo.
set /p choice="Enter your choice (1-9): "

REM 6) Set PowerShell parameters based on choice
set "ps_params="
set "description="

if "%choice%"=="1" (
    set "description=Full deployment"
    set "ps_params="
) else if "%choice%"=="2" (
    set "description=Bloatware removal only"
    set "ps_params=-SkipAppInstall"
) else if "%choice%"=="3" (
    set "description=App installation only"
    set "ps_params=-SkipBloatwareRemoval"
) else if "%choice%"=="4" (
    set "description=App installation only (no Java)"
    set "ps_params=-SkipBloatwareRemoval -SkipJavaRuntimes"
) else if "%choice%"=="5" (
    set "description=DRY RUN - Test mode"
    set "ps_params=-DryRun"
) else if "%choice%"=="6" (
    set "description=Export winget apps"
    set "ps_params=-ExportWingetApps"
) else if "%choice%"=="7" (
    set "description=Import apps from apps.json"
    set "ps_params=-ImportWingetApps -SkipBloatwareRemoval"
) else if "%choice%"=="8" (
    set "description=Full deployment + import apps"
    set "ps_params=-ImportWingetApps"
) else if "%choice%"=="9" (
    echo Exiting...
    goto :normal_exit
) else (
    echo Invalid choice. Running full deployment...
    set "description=Full deployment (default)"
    set "ps_params="
)

echo.
echo +===============================================================+
echo ^|                    EXECUTION DETAILS                         ^|
echo +===============================================================+
echo ^| Mode: %description%
echo ^| Script: %ps_script%
echo ^| Parameters: %ps_params%
echo ^| PowerShell: Windows PowerShell 5.1                          ^|
echo +===============================================================+
echo.

REM 7) Confirmation for non-dry-run operations
if not "%choice%"=="5" if not "%choice%"=="6" (
    echo WARNING: This operation will make changes to your system.
    echo.
    set /p confirm="Are you sure you want to continue? (Y/N): "
    if /i not "!confirm!"=="Y" if /i not "!confirm!"=="YES" (
        echo Operation cancelled by user.
        goto :normal_exit
    )
    echo.
)

REM 8) Special handling for export operation (no admin required)
if "%choice%"=="6" (
    echo NOTE: Export operation does not require system changes.
    echo.
)

echo Starting execution...
echo.

REM 9) Run the PowerShell script with proper parameters
if "%ps_params%"=="" (
    powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%ps_script%"
) else (
    powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%ps_script%" %ps_params%
)

REM 10) Capture and analyze exit code
set "exit_code=%errorlevel%"

echo.
echo +===============================================================+
echo ^|                    EXECUTION RESULTS                         ^|
echo +===============================================================+
if %exit_code% equ 0 (
    echo ^| Status: SUCCESS
    echo ^| Exit Code: %exit_code%
    echo ^| All operations completed successfully
    if "%choice%"=="5" (
        echo ^| NOTE: This was a DRY RUN - no actual changes were made
    )
    if "%choice%"=="6" (
        echo ^| Exported apps saved to: apps.json
    )
) else (
    echo ^| Status: COMPLETED WITH ISSUES
    echo ^| Exit Code: %exit_code%
    echo ^| Some operations may have failed
    echo ^| Check the detailed log file for more information
)
echo +===============================================================+
echo.

REM 11) Additional information based on operation
if "%choice%"=="6" (
    if exist "apps.json" (
        echo INFO: apps.json file created successfully.
        echo You can now use option 7 or 8 to import these apps on other systems.
    ) else (
        echo WARNING: apps.json file was not created. Check the log for errors.
    )
    echo.
)

if "%choice%"=="7" or "%choice%"=="8" (
    if not exist "apps.json" (
        echo WARNING: apps.json file not found in script directory.
        echo Make sure to export apps first using option 6.
    )
    echo.
)

goto :normal_exit

:error_exit
echo.
echo +===============================================================+
echo ^|                      DEPLOYMENT FAILED                       ^|
echo +===============================================================+
echo ^| The deployment could not start due to missing files or       ^|
echo ^| configuration issues. Please check the error message above.  ^|
echo +===============================================================+
popd
echo.
pause
exit /b 1

:normal_exit
REM 12) Return to original directory and provide next steps
popd

echo +===============================================================+
echo ^|                       NEXT STEPS                             ^|
echo +===============================================================+
echo ^| - Review the detailed execution summary above                ^|
echo ^| - Check log files for detailed information                   ^|
echo ^| - Restart the system if prompted by installed applications   ^|
if "%choice%"=="5" (
    echo ^| - Run again without -DryRun to apply changes                ^|
)
echo +===============================================================+
echo.
echo Press any key to exit...
pause >nul
exit /b %exit_code%
