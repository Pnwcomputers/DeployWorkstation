# DeployWorkstation-Modular.ps1 – Modular Win10/11 Setup & Clean-up
# Version: 3.0 - Modular Architecture

#Requires -Version 5.1
#Requires -RunAsAdministrator

[CmdletBinding()]
param(
    [string]$LogPath,
    [switch]$SkipAppInstall,
    [switch]$SkipBloatwareRemoval,
    [switch]$SkipSystemConfiguration,
    [switch]$SkipWindowsCapabilities,
    [switch]$SkipUWPCleanup,
    [switch]$SkipWin32Cleanup,
    [switch]$UseOfflineFallback,
    [ValidateSet('Essential', 'Business', 'Developer', 'Multimedia')]
    [string]$AppSuite = 'Essential',
    [switch]$WhatIf
)

# ================================
# Module Import and Initialization
# ================================

$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'

# Get script directory
$ScriptRoot = if ($PSScriptRoot) { $PSScriptRoot } else { Split-Path -Parent $MyInvocation.MyCommand.Path }

# Import all DeployWorkstation modules
$ModulesToImport = @(
    'DeployWorkstation.Core',
    'DeployWorkstation.Logging',
    'DeployWorkstation.WinGet',
    'DeployWorkstation.UWPCleanup',
    'DeployWorkstation.Win32Uninstall',
    'DeployWorkstation.WindowsCapabilities',
    'DeployWorkstation.SystemConfiguration',
    'DeployWorkstation.OfflineFallback'
)

Write-Host "Importing DeployWorkstation modules..." -ForegroundColor Cyan

foreach ($ModuleName in $ModulesToImport) {
    $ModulePath = Join-Path $ScriptRoot "$ModuleName.psm1"
    
    if (Test-Path $ModulePath) {
        try {
            Import-Module $ModulePath -Force -ErrorAction Stop
            Write-Host "  ✓ Imported: $ModuleName" -ForegroundColor Green
        }
        catch {
            Write-Warning "Failed to import $ModuleName`: $($_.Exception.Message)"
            Write-Host "  ✗ Failed: $ModuleName" -ForegroundColor Red
        }
    }
    else {
        Write-Warning "Module not found: $ModulePath"
        Write-Host "  ✗ Missing: $ModuleName" -ForegroundColor Red
    }
}

# ================================
# Pre-flight Checks
# ================================

function Start-DeploymentPreflightChecks {
    Write-Host "`n=== Pre-flight Checks ===" -ForegroundColor Yellow
    
    # Environment validation
    $envCheck = Test-DeployEnvironment
    if (-not $envCheck.IsValid) {
        Write-Host "Environment validation failed:" -ForegroundColor Red
        foreach ($issue in $envCheck.Issues) {
            Write-Host "  • $issue" -ForegroundColor Red
        }
        throw "Pre-flight checks failed"
    }
    
    Write-Host "✓ Environment validation passed" -ForegroundColor Green
    
    # PowerShell edition check
    if ($PSVersionTable.PSEdition -eq 'Core') {
        Write-Host "PowerShell Core detected - switching to Windows PowerShell..." -ForegroundColor Yellow
        
        $params = @{
            LogPath = $LogPath
            SkipAppInstall = $SkipAppInstall
            SkipBloatwareRemoval = $SkipBloatwareRemoval
            SkipSystemConfiguration = $SkipSystemConfiguration
            SkipWindowsCapabilities = $SkipWindowsCapabilities
            SkipUWPCleanup = $SkipUWPCleanup
            SkipWin32Cleanup = $SkipWin32Cleanup
            UseOfflineFallback = $UseOfflineFallback
            AppSuite = $AppSuite
            WhatIf = $WhatIf
        }
        
        if (Switch-ToPowerShellDesktop -ScriptPath $MyInvocation.MyCommand.Path -Parameters $params) {
            exit 0
        }
    }
    
    # Internet connectivity check
    if (-not $UseOfflineFallback) {
        $internetCheck = Test-DeployInternetConnection
        if (-not $internetCheck) {
            Write-Host "No internet connectivity detected. Consider using -UseOfflineFallback" -ForegroundColor Yellow
        } else {
            Write-Host "✓ Internet connectivity confirmed" -ForegroundColor Green
        }
    }
    
    # WinGet availability check
    if (-not $SkipAppInstall) {
        $wingetCheck = Test-WinGet
        if (-not $wingetCheck.IsAvailable) {
            Write-Host "WinGet not available. App installation will be skipped." -ForegroundColor Yellow
            $script:SkipAppInstall = $true
        } else {
            Write-Host "✓ WinGet available: $($wingetCheck.Version)" -ForegroundColor Green
        }
    }
    
    Write-Host "✓ Pre-flight checks completed" -ForegroundColor Green
}

# ================================
# Main Deployment Orchestration
# ================================

function Start-DeploymentProcess {
    param(
        [hashtable]$Config
    )
    
    $deploymentResults = @{
        StartTime = Get-Date
        Modules = @{}
        OverallSuccess = $true
        Summary = @{}
    }
    
    try {
        # Initialize logging
        Write-Host "`n=== Initializing Logging ===" -ForegroundColor Yellow
        $logPath = Initialize-DeployLogging -LogPath $Config.LogPath -Verbose:$Config.Verbose
        Write-DeployLog "===== DeployWorkstation Modular v3.0 Started ====="
        
        # Log system information
        $systemInfo = Get-DeploySystemInfo
        Write-DeployLog "System: $($systemInfo.OSName) ($($systemInfo.OSBuild))"
        Write-DeployLog "Computer: $($systemInfo.ComputerName)"
        Write-DeployLog "User: $($systemInfo.CurrentUser)"
        
        # Set execution policy
        Set-DeployExecutionPolicy
        
        # WinGet initialization
        if (-not $Config.SkipAppInstall -and -not $Config.UseOfflineFallback) {
            Write-Host "`n=== Initializing WinGet ===" -ForegroundColor Yellow
            Write-DeployLog "Initializing WinGet sources..."
            Initialize-WinGetSources -RemoveMSStore -UpdateSources
        }
        
        # Bloatware removal section
        if (-not $Config.SkipBloatwareRemoval) {
            Write-Host "`n=== Bloatware Removal ===" -ForegroundColor Yellow
            Write-DeployLog "Starting bloatware removal phase"
            
            # UWP/Appx cleanup
            if (-not $Config.SkipUWPCleanup) {
                Write-DeployLog "Removing UWP/Appx packages..."
                $uwpResult = Remove-BloatwareAppxPackages -WhatIf:$Config.WhatIf
                $deploymentResults.Modules.UWPCleanup = $uwpResult
            }
            
            # Win32 application cleanup
            if (-not $Config.SkipWin32Cleanup) {
                Write-DeployLog "Removing Win32 applications..."
                
                # Remove common bloatware patterns via WinGet
                $bloatwarePatterns = @(
                    'CoPilot', 'Outlook', 'Quick Assist', 'Remote Desktop',
                    'Mixed Reality Portal', 'Clipchamp', 'Xbox', 'Family',
                    'Skype', 'LinkedIn', 'OneDrive', 'Teams'
                )
                
                $wingetCleanupResult = Remove-WinGetBloatware -Patterns $bloatwarePatterns -WhatIf:$Config.WhatIf
                $deploymentResults.Modules.WinGetCleanup = $wingetCleanupResult
                
                # Remove specific products (like McAfee)
                $win32CleanupResult = Remove-UnwantedWin32Software -WhatIf:$Config.WhatIf
                $deploymentResults.Modules.Win32Cleanup = $win32CleanupResult
            }
            
            # Windows Capabilities cleanup
            if (-not $Config.SkipWindowsCapabilities) {
                Write-DeployLog "Removing Windows capabilities..."
                $capabilitiesResult = Remove-UnwantedWindowsCapabilities -WhatIf:$Config.WhatIf
                $deploymentResults.Modules.WindowsCapabilities = $capabilitiesResult
            }
        }
        
        # Application installation section
        if (-not $Config.SkipAppInstall) {
            Write-Host "`n=== Application Installation ===" -ForegroundColor Yellow
            Write-DeployLog "Starting application installation phase"
            
            if ($Config.UseOfflineFallback) {
                Write-DeployLog "Using offline installation methods..."
                $appInstallResult = Install-AppsOffline -AppSuite $Config.AppSuite -WhatIf:$Config.WhatIf
            } else {
                Write-DeployLog "Installing applications via WinGet..."
                $appInstallResult = Install-StandardAppSuite -AppSuite $Config.AppSuite -WhatIf:$Config.WhatIf
            }
            
            $deploymentResults.Modules.AppInstallation = $appInstallResult
        }
        
        # System configuration section
        if (-not $Config.SkipSystemConfiguration) {
            Write-Host "`n=== System Configuration ===" -ForegroundColor Yellow
            Write-DeployLog "Applying system configuration..."
            $systemConfigResult = Set-OptimalSystemConfiguration -WhatIf:$Config.WhatIf
            $deploymentResults.Modules.SystemConfiguration = $systemConfigResult
        }
        
        $deploymentResults.EndTime = Get-Date
        $deploymentResults.Duration = $deploymentResults.EndTime - $deploymentResults.StartTime
        
        # Generate summary
        Write-Host "`n=== Deployment Summary ===" -ForegroundColor Cyan
        Write-DeployLog "===== Deployment Summary ====="
        Write-DeployLog "Duration: $($deploymentResults.Duration.ToString('hh\:mm\:ss'))"
        
        foreach ($module in $deploymentResults.Modules.Keys) {
            $result = $deploymentResults.Modules[$module]
            if ($result -and $result.GetType().Name -eq 'Hashtable') {
                Write-Host "  $module`: " -NoNewline -ForegroundColor White
                if ($result.ContainsKey('Success') -and $result.Success) {
                    Write-Host "✓ Success" -ForegroundColor Green
                } elseif ($result.ContainsKey('ProcessedItems')) {
                    Write-Host "$($result.ProcessedItems) items processed" -ForegroundColor Yellow
                } else {
                    Write-Host "Completed" -ForegroundColor Green
                }
            }
        }
        
        Write-DeployLog "===== DeployWorkstation Completed Successfully ====="
        
        return $deploymentResults
    }
    catch {
        $deploymentResults.OverallSuccess = $false
        $deploymentResults.Error = $_.Exception.Message
        Write-DeployLog "Critical deployment error: $($_.Exception.Message)" -Level 'ERROR'
        throw
    }
}

# ================================
# Main Execution
# ================================

try {
    Write-Host "DeployWorkstation v3.0 - Modular Architecture" -ForegroundColor Cyan
    Write-Host "=============================================" -ForegroundColor Cyan
    
    # Pre-flight checks
    Start-DeploymentPreflightChecks
    
    # Configuration
    $deploymentConfig = @{
        LogPath = $LogPath
        SkipAppInstall = $SkipAppInstall
        SkipBloatwareRemoval = $SkipBloatwareRemoval
        SkipSystemConfiguration = $SkipSystemConfiguration
        SkipWindowsCapabilities = $SkipWindowsCapabilities
        SkipUWPCleanup = $SkipUWPCleanup
        SkipWin32Cleanup = $SkipWin32Cleanup
        UseOfflineFallback = $UseOfflineFallback
        AppSuite = $AppSuite
        WhatIf = $WhatIf
        Verbose = $VerbosePreference -eq 'Continue'
    }
    
    # Execute deployment
    $results = Start-DeploymentProcess -Config $deploymentConfig
    
    # Success output
    Write-Host "`n✓ Deployment completed successfully!" -ForegroundColor Green
    Write-Host "Duration: $($results.Duration.ToString('hh\:mm\:ss'))" -ForegroundColor White
    
    if ($results.Modules.Keys.Count -gt 0) {
        Write-Host "Log file: $($results.LogPath)" -ForegroundColor Gray
    }
    
    Write-Host "`nPress Enter to exit..." -ForegroundColor Yellow
    if (-not $WhatIf) { Read-Host | Out-Null }
}
catch {
    Write-Host "`n✗ Deployment failed!" -ForegroundColor Red
    Write-Host "Error: $($_.Exception.Message)" -ForegroundColor Red
    
    if ($logPath) {
        Write-Host "Check log file: $logPath" -ForegroundColor Gray
    }
    
    Write-Host "`nPress Enter to exit..." -ForegroundColor Yellow
    Read-Host | Out-Null
    exit 1
}
finally {
    # Cleanup
    $ProgressPreference = 'Continue'
    
    # Remove imported modules
    foreach ($ModuleName in $ModulesToImport) {
        try {
            Remove-Module $ModuleName -Force -ErrorAction SilentlyContinue
        }
        catch {
            # Ignore cleanup errors
        }
    }
}
