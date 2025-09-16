# DeployWorkstation-AllUsers.ps1 – Optimized Win10/11 Setup & Clean-up for ALL Users
# Version: 3 - Bug Fixes and Improvements

<#
.SYNOPSIS
DeployWorkstation-AllUsers.ps1 – Optimized Win10/11 Setup & Clean-up for ALL Users

.DESCRIPTION
This script configures Windows workstations for all users by removing bloatware, installing standard applications, 
and applying system-wide settings. It includes enhancements such as parameter validation, admin check, dry-run mode, 
structured logging, and retry logic.

.PARAMETER LogPath
Path to the log file. Defaults to script directory.

.PARAMETER SkipAppInstall
Skip application installation.

.PARAMETER SkipBloatwareRemoval
Skip bloatware removal.

.PARAMETER SkipDefaultUserConfig
Skip default user configuration.

.PARAMETER ExportWingetApps
Export installed winget apps to apps.json.

.PARAMETER ImportWingetApps
Import winget apps from apps.json.

.PARAMETER SkipJavaRuntimes
Skip Java runtime installation.

.PARAMETER DryRun
Simulate actions without making changes.

.VERSION
3.0 - Enhanced with improved error handling, retry logic, structured logging, and dry-run mode

.EXAMPLE
.\DeployWorkstation-AllUsers.ps1 -DryRun
Run the script in dry-run mode to see what would be changed without making actual changes.

.EXAMPLE
.\DeployWorkstation-AllUsers.ps1 -SkipAppInstall -ExportWingetApps
Skip app installation and export currently installed winget apps.
#>
#Requires -Version 5.1
#Requires -RunAsAdministrator

[CmdletBinding()]
param(
    [Parameter(Mandatory=$false, HelpMessage="Path to the log file.")]
    [ValidateNotNullOrEmpty()]
    [string]$LogPath,
    
    [Parameter(Mandatory=$false, HelpMessage="Skip application installation.")]
    [switch]$SkipAppInstall,
    
    [Parameter(Mandatory=$false, HelpMessage="Skip bloatware removal.")]
    [switch]$SkipBloatwareRemoval,
    
    [Parameter(Mandatory=$false, HelpMessage="Skip default user configuration.")]
    [switch]$SkipDefaultUserConfig,
    
    [Parameter(Mandatory=$false, HelpMessage="Export installed winget apps.")]
    [switch]$ExportWingetApps,
    
    [Parameter(Mandatory=$false, HelpMessage="Import winget apps from apps.json.")]
    [switch]$ImportWingetApps,
    
    [Parameter(Mandatory=$false, HelpMessage="Skip Java runtime installation.")]
    [switch]$SkipJavaRuntimes,
    
    [Parameter(Mandatory=$false, HelpMessage="Simulate actions without making changes.")]
    [switch]$DryRun
)

# ================================
# Telemetry and Summary Functions
# ================================

function Write-ExecutionSummary {
    Write-Log "=== EXECUTION SUMMARY ===" -Component 'SUMMARY'
    
    $summary = @"

+==============================================================================+
|                           DEPLOYMENT SUMMARY REPORT                         |
+==============================================================================+
| Execution Mode: $(if ($DryRun) { "DRY-RUN (No changes made)" } else { "LIVE EXECUTION" })                                              |
| Start Time: $($Script:StartTime.ToString('yyyy-MM-dd HH:mm:ss'))                                              |
| End Time: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')                                                |
| Duration: $((New-TimeSpan -Start $Script:StartTime -End (Get-Date)).ToString('mm\:ss'))                                                      |
+==============================================================================+
| APPLICATIONS INSTALLED: $($Script:ActionsSummary.AppsInstalled.Count.ToString().PadLeft(2))                                        |
+==============================================================================+
"@

    if ($Script:ActionsSummary.AppsInstalled.Count -gt 0) {
        foreach ($app in $Script:ActionsSummary.AppsInstalled) {
            $summary += "|   + $($app.PadRight(72)) |`n"
        }
        $summary += "+==============================================================================+`n"
    }

    $summary += @"
| APPLICATIONS REMOVED: $($Script:ActionsSummary.AppsRemoved.Count.ToString().PadLeft(2))                                          |
+==============================================================================+
"@

    if ($Script:ActionsSummary.AppsRemoved.Count -gt 0) {
        foreach ($app in $Script:ActionsSummary.AppsRemoved) {
            $summary += "|   - $($app.PadRight(72)) |`n"
        }
        $summary += "+==============================================================================+`n"
    }

    $summary += @"
| PACKAGES REMOVED: $($Script:ActionsSummary.PackagesRemoved.Count.ToString().PadLeft(2))                                            |
+==============================================================================+
"@

    if ($Script:ActionsSummary.PackagesRemoved.Count -gt 0) {
        foreach ($pkg in ($Script:ActionsSummary.PackagesRemoved | Select-Object -First 5)) {
            $summary += "|   - $($pkg.PadRight(72)) |`n"
        }
        if ($Script:ActionsSummary.PackagesRemoved.Count -gt 5) {
            $summary += "|   ... and $($Script:ActionsSummary.PackagesRemoved.Count - 5) more packages                                      |`n"
        }
        $summary += "+==============================================================================+`n"
    }

    $summary += @"
| SERVICES DISABLED: $($Script:ActionsSummary.ServicesDisabled.Count.ToString().PadLeft(2))                                          |
+==============================================================================+
"@

    if ($Script:ActionsSummary.ServicesDisabled.Count -gt 0) {
        foreach ($svc in ($Script:ActionsSummary.ServicesDisabled | Select-Object -First 5)) {
            $summary += "|   * $($svc.PadRight(72)) |`n"
        }
        if ($Script:ActionsSummary.ServicesDisabled.Count -gt 5) {
            $summary += "|   ... and $($Script:ActionsSummary.ServicesDisabled.Count - 5) more services                                     |`n"
        }
        $summary += "+==============================================================================+`n"
    }

    $summary += @"
| REGISTRY KEYS MODIFIED: $($Script:ActionsSummary.RegistryKeysModified.Count.ToString().PadLeft(2))                                     |
+==============================================================================+
| ERRORS ENCOUNTERED: $($Script:ActionsSummary.Errors.Count.ToString().PadLeft(2))                                         |
+==============================================================================+
"@

    if ($Script:ActionsSummary.Errors.Count -gt 0) {
        foreach ($error in ($Script:ActionsSummary.Errors | Select-Object -First 3)) {
            $truncatedError = if ($error.Length -gt 72) { $error.Substring(0, 69) + "..." } else { $error }
            $summary += "|   ! $($truncatedError.PadRight(72)) |`n"
        }
        if ($Script:ActionsSummary.Errors.Count -gt 3) {
            $summary += "|   ... and $($Script:ActionsSummary.Errors.Count - 3) more errors (see log file)                           |`n"
        }
        $summary += "+==============================================================================+`n"
    }

    $summary += @"
| Log File: $($LogPath.PadRight(63)) |
+==============================================================================+
"@

    Write-Host $summary -ForegroundColor $(if ($Script:ActionsSummary.Errors.Count -eq 0) { 'Green' } else { 'Yellow' })
    
    # Log the summary as well
    Write-Log "Execution completed with $($Script:ActionsSummary.Errors.Count) errors" -Component 'SUMMARY'
    Write-Log "Apps Installed: $($Script:ActionsSummary.AppsInstalled.Count), Apps Removed: $($Script:ActionsSummary.AppsRemoved.Count)" -Component 'SUMMARY'
    Write-Log "Packages Removed: $($Script:ActionsSummary.PackagesRemoved.Count), Services Disabled: $($Script:ActionsSummary.ServicesDisabled.Count)" -Component 'SUMMARY'
    Write-Log "Registry Keys Modified: $($Script:ActionsSummary.RegistryKeysModified.Count)" -Component 'SUMMARY'
}

# ================================
# Initialize Tracking Variables
# ================================

$Script:StartTime = Get-Date

# ================================
# Configuration & Setup
# ================================

$ErrorActionPreference = 'Continue'
$ProgressPreference = 'SilentlyContinue'

# Initialize script root and log path
if (-not $PSScriptRoot) {
    $PSScriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
}

if (-not $LogPath) {
    $LogPath = Join-Path $PSScriptRoot "DeployWorkstation-AllUsers.log"
}

# Admin check
if (-not ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) {
    Write-Host "ERROR: Script must be run as Administrator." -ForegroundColor Red
    exit 1
}

# Ensure we're in Windows PowerShell Desktop for Appx cmdlets
if ($PSVersionTable.PSEdition -eq 'Core') {
    Write-Warning 'PowerShell Core detected. Restarting in Windows PowerShell Desktop...'
    $params = @(
        '-NoProfile'
        '-ExecutionPolicy', 'Bypass'
        '-File', $PSCommandPath
    )
    if ($SkipAppInstall) { $params += '-SkipAppInstall' }
    if ($SkipBloatwareRemoval) { $params += '-SkipBloatwareRemoval' }
    if ($SkipDefaultUserConfig) { $params += '-SkipDefaultUserConfig' }
    if ($ExportWingetApps) { $params += '-ExportWingetApps' }
    if ($ImportWingetApps) { $params += '-ImportWingetApps' }
    if ($SkipJavaRuntimes) { $params += '-SkipJavaRuntimes' }
    if ($DryRun) { $params += '-DryRun' }
    
    Start-Process -FilePath 'powershell.exe' -ArgumentList $params -Verb RunAs
    exit
}

# ================================
# Enhanced Logging Functions
# ================================

# Global tracking variables
$Script:ActionsSummary = @{
    AppsInstalled = @()
    AppsRemoved = @()
    PackagesRemoved = @()
    ServicesDisabled = @()
    RegistryKeysModified = @()
    Errors = @()
}

function Write-Log {
    param(
        [Parameter(Mandatory=$true)]
        [string]$Message,
        [ValidateSet('INFO', 'WARN', 'ERROR', 'DEBUG')]
        [string]$Level = 'INFO',
        [string]$Component = 'MAIN',
        [int]$ErrorCode = 0
    )
    
    $timestamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
    
    # Structured logging for file
    $logEntry = @{
        timestamp = $timestamp
        level = $Level
        component = $Component
        message = $Message
        dryRun = $DryRun.IsPresent
        errorCode = $ErrorCode
    } | ConvertTo-Json -Compress
    
    # Create log directory if needed
    $logDir = Split-Path $LogPath -Parent
    if (-not (Test-Path $logDir)) {
        New-Item -Path $logDir -ItemType Directory -Force | Out-Null
    }
    
    Add-Content -Path $LogPath -Value $logEntry -Encoding UTF8
    
    # Optional Windows Event Log
    try {
        if (-not $DryRun -and (Get-EventLog -LogName Application -Source "DeployWorkstation" -Newest 1 -ErrorAction SilentlyContinue)) {
            $eventType = switch ($Level) {
                'ERROR' { 'Error' }
                'WARN' { 'Warning' }
                default { 'Information' }
            }
            Write-EventLog -LogName Application -Source "DeployWorkstation" -EntryType $eventType -EventId 1000 -Message "[$Component] $Message"
        }
    }
    catch {
        # Silently continue if event log isn't available
    }
    
    # Track errors for summary
    if ($Level -eq 'ERROR') {
        $Script:ActionsSummary.Errors += "$Component`: $Message"
    }
    
    # Console output with colors and dry-run prefix
    $prefix = if ($DryRun) { "[DRY-RUN] " } else { "" }
    $consoleMessage = "$prefix[$timestamp] [$Level] [$Component] $Message"
    
    switch ($Level) {
        'ERROR' { Write-Host $consoleMessage -ForegroundColor Red }
        'WARN'  { Write-Host $consoleMessage -ForegroundColor Yellow }
        'DEBUG' { if ($VerbosePreference -ne 'SilentlyContinue') { Write-Host $consoleMessage -ForegroundColor Cyan } }
        default { Write-Host $consoleMessage }
    }
}

function Initialize-EventLogSource {
    if ($DryRun) { return }
    
    try {
        if (-not ([System.Diagnostics.EventLog]::SourceExists("DeployWorkstation"))) {
            New-EventLog -LogName Application -Source "DeployWorkstation"
            Write-Log "Created Windows Event Log source" -Component 'LOGGING'
        }
    }
    catch {
        Write-Log "Could not create Event Log source: $($_.Exception.Message)" -Level 'DEBUG' -Component 'LOGGING'
    }
}

function Backup-RegistryKey {
    param(
        [string]$KeyPath,
        [string]$BackupPath
    )
    
    if ($DryRun) {
        Write-Log "DryRun: Would backup registry key $KeyPath" -Level 'INFO' -Component 'REGISTRY'
        return $true
    }
    
    try {
        $regFileName = ($KeyPath -replace ':', '') -replace '\\', '_'
        $backupFile = Join-Path $BackupPath "$regFileName.reg"
        
        reg export $KeyPath $backupFile /y 2>$null
        if ($LASTEXITCODE -eq 0) {
            Write-Log "Backed up registry key: $KeyPath -> $backupFile" -Component 'REGISTRY'
            return $true
        } else {
            Write-Log "Failed to backup registry key: $KeyPath" -Level 'WARN' -Component 'REGISTRY'
            return $false
        }
    }
    catch {
        Write-Log "Error backing up registry key $KeyPath`: $($_.Exception.Message)" -Level 'ERROR' -Component 'REGISTRY'
        return $false
    }
}

function Test-Prerequisites {
    Write-Log "Validating system prerequisites..." -Component 'VALIDATION'
    
    $requiredCommands = @('reg', 'winget', 'powershell')
    $missing = @()
    
    foreach ($cmd in $requiredCommands) {
        try {
            $null = Get-Command $cmd -ErrorAction Stop
            Write-Log "Found required command: $cmd" -Level 'DEBUG' -Component 'VALIDATION'
        }
        catch {
            $missing += $cmd
            Write-Log "Missing required command: $cmd" -Level 'ERROR' -Component 'VALIDATION' -ErrorCode 1001
        }
    }
    
    # Check Windows version
    $osVersion = [System.Environment]::OSVersion.Version
    if ($osVersion.Major -lt 10) {
        Write-Log "Unsupported Windows version: $($osVersion.ToString())" -Level 'ERROR' -Component 'VALIDATION' -ErrorCode 1002
        $missing += "Windows 10/11"
    }
    
    if ($missing.Count -gt 0) {
        Write-Log "Missing prerequisites: $($missing -join ', ')" -Level 'ERROR' -Component 'VALIDATION' -ErrorCode 1003
        return $false
    }
    
    Write-Log "All prerequisites validated successfully" -Component 'VALIDATION'
    return $true
}

# ================================
# Enhanced Retry Logic Functions
# ================================

function Invoke-WingetCommand {
    param(
        [Parameter(Mandatory=$true)]
        [string]$Command,
        [int]$MaxRetries = 3,
        [int]$DelaySeconds = 2,
        [string]$AppName = "Unknown"
    )
    
    $attempt = 1
    while ($attempt -le $MaxRetries) {
        Write-Log "Executing winget command (Attempt $attempt/$MaxRetries): $Command" -Level 'DEBUG' -Component 'WINGET'
        
        if ($DryRun) {
            Write-Log "DryRun: Would execute '$Command'" -Level 'INFO' -Component 'WINGET'
            return $true
        }
        
        try {
            $result = Invoke-Expression $Command 2>&1
            $exitCode = $LASTEXITCODE
            
            if ($exitCode -eq 0) {
                Write-Log "Winget command succeeded: $AppName" -Component 'WINGET'
                return $true
            } elseif ($exitCode -eq -1978335189) {  # Already installed
                Write-Log "App already installed: $AppName" -Component 'WINGET'
                return $true
            } else {
                Write-Log "Winget command failed with exit code $exitCode for $AppName" -Level 'WARN' -Component 'WINGET' -ErrorCode $exitCode
                if ($result) {
                    Write-Log "Command output: $result" -Level 'DEBUG' -Component 'WINGET'
                }
            }
        } catch {
            Write-Log "Exception during winget command for $AppName`: $($_.Exception.Message)" -Level 'ERROR' -Component 'WINGET' -ErrorCode 1100
        }
        
        if ($attempt -lt $MaxRetries) {
            Write-Log "Waiting $DelaySeconds seconds before retry..." -Level 'DEBUG' -Component 'WINGET'
            Start-Sleep -Seconds $DelaySeconds
        }
        $attempt++
    }
    
    Write-Log "Winget command failed after $MaxRetries attempts for $AppName" -Level 'ERROR' -Component 'WINGET' -ErrorCode 1101
    return $false
}

function Invoke-ParallelWingetInstall {
    param(
        [array]$AppList,
        [int]$MaxConcurrentJobs = 3
    )
    
    Write-Log "Starting parallel app installation with max $MaxConcurrentJobs concurrent jobs" -Component 'WINGET'
    
    if ($DryRun) {
        Write-Log "DryRun: Would install $($AppList.Count) apps in parallel" -Level 'INFO' -Component 'WINGET'
        return $AppList.Count
    }
    
    $jobs = @()
    $completed = @()
    
    foreach ($app in $AppList) {
        # Wait if we have too many concurrent jobs
        while ((Get-Job -State Running).Count -ge $MaxConcurrentJobs) {
            Start-Sleep -Seconds 1
            $finishedJobs = Get-Job -State Completed
            foreach ($job in $finishedJobs) {
                $result = Receive-Job $job
                Remove-Job $job
                $completed += $result
            }
        }
        
        # Start new job
        $scriptBlock = {
            param($appId, $appName, $logPath)
            
            $result = @{
                AppName = $appName
                AppId = $appId
                Success = $false
                Error = $null
            }
            
            try {
                $installResult = winget install --id $appId --source winget --accept-package-agreements --accept-source-agreements --silent 2>&1
                if ($LASTEXITCODE -eq 0 -or $LASTEXITCODE -eq -1978335189) {
                    $result.Success = $true
                } else {
                    $result.Error = "Exit code: $LASTEXITCODE"
                }
            }
            catch {
                $result.Error = $_.Exception.Message
            }
            
            return $result
        }
        
        $job = Start-Job -ScriptBlock $scriptBlock -ArgumentList $app.Id, $app.Name, $LogPath
        $jobs += $job
        Write-Log "Started installation job for: $($app.Name)" -Level 'DEBUG' -Component 'WINGET'
    }
    
    # Wait for all jobs to complete
    Write-Log "Waiting for all installation jobs to complete..." -Component 'WINGET'
    Wait-Job $jobs | Out-Null
    
    # Collect results
    foreach ($job in $jobs) {
        $result = Receive-Job $job
        Remove-Job $job
        $completed += $result
    }
    
    # Process results
    $successCount = 0
    foreach ($result in $completed) {
        if ($result.Success) {
            Write-Log "Successfully installed: $($result.AppName)" -Component 'WINGET'
            $Script:ActionsSummary.AppsInstalled += $result.AppName
            $successCount++
        } else {
            Write-Log "Failed to install $($result.AppName): $($result.Error)" -Level 'ERROR' -Component 'WINGET' -ErrorCode 1102
        }
    }
    
    return $successCount
}

function Get-WingetAppByPattern {
    param([string]$Pattern)
    
    if ($DryRun) {
        return @("DryRun-MockApp-$Pattern")
    }
    
    try {
        # More robust winget parsing
        $output = winget list --name "$Pattern" --accept-source-agreements 2>$null
        if (-not $output) {
            # Try with ID if name search fails
            $output = winget list --id "$Pattern" --accept-source-agreements 2>$null
        }
        
        $apps = @()
        $foundData = $false
        
        foreach ($line in $output) {
            # Skip header lines and empty lines
            if ($line -match "Name\s+Id\s+Version" -or $line -match "^-+") {
                $foundData = $true
                continue
            }
            
            if ($foundData -and $line.Trim() -and $line -notmatch "^Available upgrades") {
                # Parse the line to extract app info
                $parts = $line -split '\s{2,}'  # Split on multiple spaces
                if ($parts.Count -ge 2) {
                    $apps += @{
                        Name = $parts[0].Trim()
                        Id = $parts[1].Trim()
                        Version = if ($parts.Count -gt 2) { $parts[2].Trim() } else { "Unknown" }
                    }
                }
            }
        }
        
        return $apps
    }
    catch {
        Write-Log "Error searching for apps with pattern '$Pattern': $($_.Exception.Message)" -Level 'ERROR' -Component 'WINGET' -ErrorCode 1103
        return @()
    }
}

function Invoke-RegistryOperation {
    param(
        [Parameter(Mandatory=$true)]
        [scriptblock]$Operation,
        [string]$Description,
        [int]$MaxRetries = 2
    )
    
    $attempt = 1
    while ($attempt -le $MaxRetries) {
        try {
            Write-Log "Registry operation (Attempt $attempt/$MaxRetries): $Description" -Level 'DEBUG'
            
            if ($DryRun) {
                Write-Log "DryRun: Would perform registry operation - $Description" -Level 'INFO'
                return $true
            }
            
            & $Operation
            Write-Log "Registry operation succeeded: $Description"
            return $true
        }
        catch {
            Write-Log "Registry operation failed (Attempt $attempt): $Description - $($_.Exception.Message)" -Level 'WARN'
            if ($attempt -lt $MaxRetries) {
                Start-Sleep -Seconds 1
            }
        }
        $attempt++
    }
    
    Write-Log "Registry operation failed after $MaxRetries attempts: $Description" -Level 'ERROR'
    return $false
}

# ================================
# Registry Drive Management
# ================================

function Initialize-RegistryDrives {
    Write-Log "Initializing registry drives..."
    
    # Create HKU: drive if it doesn't exist
    if (-not (Get-PSDrive -Name HKU -ErrorAction SilentlyContinue)) {
        try {
            if (-not $DryRun) {
                New-PSDrive -Name HKU -PSProvider Registry -Root HKEY_USERS -Scope Global | Out-Null
            }
            Write-Log "Created HKU: PowerShell drive"
            
            # Verify the drive was created (skip in dry-run)
            if (-not $DryRun -and (Get-PSDrive -Name HKU -ErrorAction SilentlyContinue)) {
                Write-Log "HKU: drive verified successfully"
            } elseif (-not $DryRun) {
                Write-Log "HKU: drive creation failed - drive not found after creation" -Level 'ERROR'
                return $false
            }
        }
        catch {
            Write-Log "Failed to create HKU: drive: $($_.Exception.Message)" -Level 'ERROR'
            return $false
        }
    } else {
        Write-Log "HKU: drive already exists"
    }
    
    return $true
}

function Remove-RegistryDrives {
    Write-Log "Cleaning up registry drives..."
    
    if ($DryRun) {
        Write-Log "DryRun: Would remove HKU: PowerShell drive" -Level 'INFO'
        return
    }
    
    # Remove HKU: drive if we created it
    if (Get-PSDrive -Name HKU -ErrorAction SilentlyContinue) {
        try {
            Remove-PSDrive -Name HKU -Force -ErrorAction SilentlyContinue
            Write-Log "Removed HKU: PowerShell drive"
        }
        catch {
            Write-Log "Could not remove HKU: drive: $($_.Exception.Message)" -Level 'WARN'
        }
    }
}

# ================================
# User Profile Management
# ================================

function Get-AllUserProfiles {
    Write-Log "Discovering user profiles..."
    
    $profiles = @()
    
    # Get all user profiles from registry
    $profileListPath = 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\ProfileList'
    Get-ChildItem $profileListPath | ForEach-Object {
        $profilePath = (Get-ItemProperty $_.PSPath -Name ProfileImagePath -ErrorAction SilentlyContinue).ProfileImagePath
        $sid = $_.PSChildName
        
        if ($profilePath -and (Test-Path $profilePath) -and $profilePath -notlike '*\systemprofile*' -and $profilePath -notlike '*\LocalService*' -and $profilePath -notlike '*\NetworkService*') {
            $username = Split-Path $profilePath -Leaf
            $profiles += @{
                Username = $username
                ProfilePath = $profilePath
                SID = $sid
                RegistryPath = "HKU:\$sid"
            }
        }
    }
    
    Write-Log "Found $($profiles.Count) user profiles"
    return $profiles
}

function Mount-UserRegistryHives {
    param([array]$UserProfiles)
    
    Write-Log "Mounting user registry hives..."
    
    if ($DryRun) {
        Write-Log "DryRun: Would mount registry hives for $($UserProfiles.Count) users" -Level 'INFO'
        return
    }
    
    foreach ($profile in $UserProfiles) {
        $ntUserPath = Join-Path $profile.ProfilePath "NTUSER.DAT"
        
        if (Test-Path $ntUserPath) {
            try {
                # Check if already mounted
                if (-not (Test-Path "HKU:\$($profile.SID)")) {
                    reg load "HKU\$($profile.SID)" $ntUserPath 2>$null
                    if ($LASTEXITCODE -eq 0) {
                        Write-Log "Mounted registry hive for: $($profile.Username)"
                    } else {
                        Write-Log "Failed to mount registry hive for: $($profile.Username) (Exit code: $LASTEXITCODE)" -Level 'WARN'
                    }
                } else {
                    Write-Log "Registry hive already mounted for: $($profile.Username)"
                }
            }
            catch {
                Write-Log "Failed to mount registry for $($profile.Username): $($_.Exception.Message)" -Level 'WARN'
            }
        }
    }
    
    # Wait a moment for registry changes to be available
    Start-Sleep -Seconds 2
}

function Dismount-UserRegistryHives {
    param([array]$UserProfiles)
    
    Write-Log "Dismounting user registry hives..."
    
    if ($DryRun) {
        Write-Log "DryRun: Would dismount registry hives for $($UserProfiles.Count) users" -Level 'INFO'
        return
    }
    
    foreach ($profile in $UserProfiles) {
        $maxAttempts = 3
        $attempt = 1
        $dismountSuccess = $false
        
        try {
            if (Test-Path "HKU:\$($profile.SID)") {
                Write-Log "Dismounting registry hive for: $($profile.Username)"
                
                while ($attempt -le $maxAttempts -and -not $dismountSuccess) {
                    Write-Log "Dismount attempt $attempt of $maxAttempts for: $($profile.Username)" -Level 'DEBUG'
                    
                    # Force garbage collection and wait for finalizers
                    [System.GC]::Collect()
                    [System.GC]::WaitForPendingFinalizers()
                    [System.GC]::Collect()
                    
                    # Wait for any registry handles to be released
                    Start-Sleep -Seconds 2
                    
                    # Close any open registry keys for this hive
                    try {
                        $registryKey = [Microsoft.Win32.Registry]::Users.OpenSubKey($profile.SID, $false)
                        if ($registryKey) {
                            $registryKey.Close()
                            $registryKey.Dispose()
                        }
                    }
                    catch {
                        # Registry key might not be open, continue
                    }
                    
                    # Additional wait before unmount attempt
                    Start-Sleep -Seconds 1
                    
                    # Attempt to unmount
                    reg unload "HKU\$($profile.SID)" 2>$null
                    $exitCode = $LASTEXITCODE
                    
                    if ($exitCode -eq 0) {
                        Write-Log "Successfully dismounted registry hive for: $($profile.Username)"
                        $dismountSuccess = $true
                    } else {
                        Write-Log "Dismount attempt $attempt failed for $($profile.Username) (Exit code: $exitCode)" -Level 'WARN'
                        
                        if ($attempt -lt $maxAttempts) {
                            # Wait longer between attempts
                            Write-Log "Waiting before retry..." -Level 'DEBUG'
                            Start-Sleep -Seconds 5
                        }
                    }
                    
                    $attempt++
                }
                
                if (-not $dismountSuccess) {
                    Write-Log "Failed to dismount registry hive for $($profile.Username) after $maxAttempts attempts. This may not affect system functionality." -Level 'WARN'
                }
            } else {
                Write-Log "Registry hive not mounted for: $($profile.Username)"
            }
        }
        catch {
            Write-Log "Error during dismount process for $($profile.Username): $($_.Exception.Message)" -Level 'ERROR'
        }
    }
    
    # Final cleanup - force garbage collection one more time
    Write-Log "Performing final cleanup..." -Level 'DEBUG'
    [System.GC]::Collect()
    [System.GC]::WaitForPendingFinalizers()
    [System.GC]::Collect()
    
    # Wait a moment for system to stabilize
    Start-Sleep -Seconds 2
}

# ================================
# Enhanced Winget Management
# ================================

function Test-Winget {
    try {
        $null = Get-Command winget -ErrorAction Stop
        $version = (winget --version) -replace '[^\d\.]', ''
        Write-Log "Winget found: v$version"
        return $true
    }
    catch {
        Write-Log "Winget not available" -Level 'ERROR'
        return $false
    }
}

function Initialize-WingetSources {
    Write-Log "Managing winget sources..."
    
    if ($DryRun) {
        Write-Log "DryRun: Would manage winget sources" -Level 'INFO'
        return $true
    }
    
    try {
        # Remove msstore source to improve performance
        $sources = winget source list 2>$null
        if ($sources -match 'msstore') {
            Write-Log "Removing msstore source for better performance..."
            winget source remove --name msstore 2>$null | Out-Null
        }
        
        # Ensure winget source is updated
        Write-Log "Updating winget sources..."
        winget source update --name winget 2>$null | Out-Null
        return $true
    }
    catch {
        Write-Log "Failed to manage winget sources: $($_.Exception.Message)" -Level 'WARN'
        return $false
    }
}

function Export-WingetApps {
    Write-Log "Exporting installed winget apps..."
    
    $exportPath = Join-Path $PSScriptRoot "apps.json"
    
    if ($DryRun) {
        Write-Log "DryRun: Would export winget apps to $exportPath" -Level 'INFO'
        return
    }
    
    try {
        $result = Invoke-WingetCommand -Command "winget export --output `"$exportPath`""
        if ($result) {
            Write-Log "Successfully exported winget apps to: $exportPath"
        } else {
            Write-Log "Failed to export winget apps" -Level 'ERROR'
        }
    }
    catch {
        Write-Log "Error exporting winget apps: $($_.Exception.Message)" -Level 'ERROR'
    }
}

function Import-WingetApps {
    Write-Log "Importing winget apps from apps.json..."
    
    $importPath = Join-Path $PSScriptRoot "apps.json"
    
    if (-not (Test-Path $importPath)) {
        Write-Log "apps.json not found at: $importPath" -Level 'ERROR'
        return
    }
    
    if ($DryRun) {
        Write-Log "DryRun: Would import winget apps from $importPath" -Level 'INFO'
        return
    }
    
    try {
        $result = Invoke-WingetCommand -Command "winget import --import-file `"$importPath`" --accept-package-agreements --accept-source-agreements"
        if ($result) {
            Write-Log "Successfully imported winget apps from: $importPath"
        } else {
            Write-Log "Failed to import winget apps" -Level 'ERROR'
        }
    }
    catch {
        Write-Log "Error importing winget apps: $($_.Exception.Message)" -Level 'ERROR'
    }
}

# ================================
# Enhanced Bloatware Removal Functions
# ================================

function Remove-WingetApps {
    param([string[]]$AppPatterns)
    
    Write-Log "Starting winget app removal..." -Component 'REMOVAL'
    
    foreach ($pattern in $AppPatterns) {
        Write-Log "Searching for apps matching: $pattern" -Component 'REMOVAL'
        
        try {
            if ($DryRun) {
                Write-Log "DryRun: Would search and remove apps matching '$pattern'" -Level 'INFO' -Component 'REMOVAL'
                $Script:ActionsSummary.AppsRemoved += "DryRun-$pattern"
                continue
            }
            
            # Use enhanced app search
            $foundApps = Get-WingetAppByPattern -Pattern $pattern
            
            if ($foundApps -and $foundApps.Count -gt 0) {
                Write-Log "Found $($foundApps.Count) app(s) matching '$pattern'" -Component 'REMOVAL'
                
                foreach ($app in $foundApps) {
                    if ($app -is [string]) {
                        $appName = $app
                        $uninstallCmd = "winget uninstall --name `"$pattern`" --silent --force --accept-source-agreements"
                    } else {
                        $appName = $app.Name
                        $uninstallCmd = "winget uninstall --id `"$($app.Id)`" --silent --force --accept-source-agreements"
                    }
                    
                    Write-Log "Attempting to uninstall: $appName" -Component 'REMOVAL'
                    $result = Invoke-WingetCommand -Command $uninstallCmd -AppName $appName
                    
                    if ($result) {
                        Write-Log "Successfully removed: $appName" -Component 'REMOVAL'
                        $Script:ActionsSummary.AppsRemoved += $appName
                    } else {
                        Write-Log "Failed to remove: $appName" -Level 'WARN' -Component 'REMOVAL' -ErrorCode 3001
                    }
                }
            } else {
                Write-Log "No apps found matching: $pattern" -Component 'REMOVAL'
            }
        }
        catch {
            Write-Log "Error processing $pattern`: $($_.Exception.Message)" -Level 'ERROR' -Component 'REMOVAL' -ErrorCode 3000
        }
    }

    Write-Log "Winget app removal completed" -Component 'REMOVAL'
}

function Remove-AppxPackagesAllUsers {
    Write-Log "Removing UWP/Appx packages for all users..." -Component 'APPX'
    
    $packagesToRemove = @(
        '*Microsoft.OutlookForWindows*',
        '*Clipchamp*',
        '*MicrosoftFamily*',
        '*OneDrive*',
        '*LinkedIn*',
        '*Xbox*',
        '*Skype*',
        '*MixedReality*',
        '*RemoteDesktop*',
        '*QuickAssist*',
        '*MicrosoftTeams*',
        '*Disney*',
        '*Netflix*',
        '*Spotify*',
        '*TikTok*',
        '*Instagram*',
        '*Facebook*',
        '*Candy*',
        '*Twitter*',
        '*Minecraft*'
    )
    
    foreach ($packagePattern in $packagesToRemove) {
        Write-Log "Processing Appx package: $packagePattern" -Component 'APPX'
        
        if ($DryRun) {
            Write-Log "DryRun: Would remove Appx package pattern '$packagePattern'" -Level 'INFO' -Component 'APPX'
            $Script:ActionsSummary.PackagesRemoved += "DryRun-$packagePattern"
            continue
        }
        
        try {
            # Remove for all users (current and future)
            $packages = Get-AppxPackage -AllUsers -Name $packagePattern -ErrorAction SilentlyContinue
            foreach ($package in $packages) {
                Write-Log "Removing package for all users: $($package.Name)" -Component 'APPX'
                Remove-AppxPackage -Package $package.PackageFullName -AllUsers -ErrorAction SilentlyContinue
                $Script:ActionsSummary.PackagesRemoved += $package.Name
            }
            
            # Remove provisioned packages (affects new user accounts)
            $provisionedPackages = Get-AppxProvisionedPackage -Online -ErrorAction SilentlyContinue |
                                 Where-Object { $_.DisplayName -like $packagePattern }
            
            foreach ($package in $provisionedPackages) {
                Write-Log "Removing provisioned package: $($package.DisplayName)" -Component 'APPX'
                Remove-AppxProvisionedPackage -Online -PackageName $package.PackageName -ErrorAction SilentlyContinue
                $Script:ActionsSummary.PackagesRemoved += $package.DisplayName
            }
        }
        catch {
            Write-Log "Error removing $packagePattern`: $($_.Exception.Message)" -Level 'WARN' -Component 'APPX' -ErrorCode 3002
        }
    }
}

function Remove-WindowsCapabilities {
    Write-Log "Removing Windows optional features..." -Component 'CAPABILITIES'
    
    $capabilitiesToRemove = @(
        'App.Support.QuickAssist~~~~0.0.1.0',
        'App.Xbox.TCUI~~~~0.0.1.0',
        'App.XboxGameOverlay~~~~0.0.1.0',
        'App.XboxSpeechToTextOverlay~~~~0.0.1.0',
        'App.StepsRecorder~~~~0.0.1.0',
        'Browser.InternetExplorer~~~~0.0.11.0',
        'MathRecognizer~~~~0.0.1.0',
        'OpenSSH.Client~~~~0.0.1.0',
        'Microsoft.Windows.PowerShell.ISE~~~~0.0.1.0',
        'Print.Fax.Scan~~~~0.0.1.0',
        'Print.Management.Console~~~~0.0.1.0'
    )
    
    foreach ($capability in $capabilitiesToRemove) {
        Write-Log "Processing capability: $capability" -Component 'CAPABILITIES'
        
        try {
            if ($DryRun) {
                Write-Log "DryRun: Would check and remove capability '$capability'" -Level 'INFO' -Component 'CAPABILITIES'
                continue
            }
            
            $state = Get-WindowsCapability -Online -Name $capability -ErrorAction SilentlyContinue
            
            if ($state -and $state.State -eq 'Installed') {
                Write-Log "Removing capability: $capability" -Component 'CAPABILITIES'
                Remove-WindowsCapability -Online -Name $capability -ErrorAction SilentlyContinue | Out-Null
                
                # Verify removal
                $newState = Get-WindowsCapability -Online -Name $capability -ErrorAction SilentlyContinue
                if ($newState -and $newState.State -eq 'NotPresent') {
                    Write-Log "Successfully removed capability: $capability" -Component 'CAPABILITIES'
                    $Script:ActionsSummary.PackagesRemoved += $capability
                } else {
                    Write-Log "Capability removal may have failed: $capability" -Level 'WARN' -Component 'CAPABILITIES' -ErrorCode 3004
                }
            } elseif ($state -and $state.State -eq 'NotPresent') {
                Write-Log "Capability not installed: $capability" -Component 'CAPABILITIES'
            } else {
                Write-Log "Capability not found: $capability" -Level 'WARN' -Component 'CAPABILITIES'
            }
        }
        catch {
            Write-Log "Error processing capability $capability`: $($_.Exception.Message)" -Level 'WARN' -Component 'CAPABILITIES' -ErrorCode 3005
        }
    }
    
    Write-Log "Windows capabilities removal completed" -Component 'CAPABILITIES'
}

function Remove-McAfeeProducts {
    Write-Log "Searching for McAfee products..." -Component 'REMOVAL'
    
    $uninstallPaths = @(
        'HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*',
        'HKLM:\Software\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*'
    )
    
    $mcafeeFound = $false
    
    if ($DryRun) {
        Write-Log "DryRun: Would search for and remove McAfee products" -Level 'INFO' -Component 'REMOVAL'
        return
    }
    
    foreach ($path in $uninstallPaths) {
        Get-ItemProperty $path -ErrorAction SilentlyContinue |
        Where-Object { $_.DisplayName -like '*McAfee*' } |
        ForEach-Object {
            $mcafeeFound = $true
            $displayName = $_.DisplayName
            $uninstallString = $_.UninstallString
            
            Write-Log "Found McAfee product: $displayName" -Component 'REMOVAL'
            
            if ($uninstallString) {
                try {
                    Write-Log "Attempting to uninstall: $displayName" -Component 'REMOVAL'
                    
                    # Simple parsing without regex
                    if ($uninstallString.StartsWith('"')) {
                        $endQuote = $uninstallString.IndexOf('"', 1)
                        if ($endQuote -gt 0) {
                            $executable = $uninstallString.Substring(1, $endQuote - 1)
                            $arguments = $uninstallString.Substring($endQuote + 1).Trim()
                        } else {
                            $executable = $uninstallString
                            $arguments = ""
                        }
                    } else {
                        $parts = $uninstallString.Split(' ', 2)
                        $executable = $parts[0]
                        $arguments = if ($parts.Length -gt 1) { $parts[1] } else { "" }
                    }
                    
                    if ($arguments -notmatch '/S|/silent|/quiet') {
                        $arguments += ' /S /quiet'
                    }
                    
                    Start-Process -FilePath $executable -ArgumentList $arguments -Wait -WindowStyle Hidden -ErrorAction Stop
                    Write-Log "Successfully uninstalled: $displayName" -Component 'REMOVAL'
                    $Script:ActionsSummary.AppsRemoved += $displayName
                }
                catch {
                    Write-Log "Failed to uninstall $displayName : $($_.Exception.Message)" -Level 'ERROR' -Component 'REMOVAL' -ErrorCode 3003
                }
            }
        }
    }
    
    if (-not $mcafeeFound) {
        Write-Log "No McAfee products found" -Component 'REMOVAL'
    }
}

# ================================
# Enhanced Application Installation with Parallel Processing
# ================================

function Install-StandardApps {
    param(
        [int]$MaxConcurrentJobs = 3
    )
    
	Write-Log "Installing standard applications and runtime libraries..."
	
    # Core applications
    $coreApps = @(
        @{ Id = 'Malwarebytes.Malwarebytes'; Name = 'Malwarebytes' },
        @{ Id = 'BleachBit.BleachBit'; Name = 'BleachBit' },
        @{ Id = 'Google.Chrome'; Name = 'Google Chrome' },
        @{ Id = 'Adobe.Acrobat.Reader.64-bit'; Name = 'Adobe Reader' },
        @{ Id = 'Zoom.Zoom'; Name = 'Zoom' },
        @{ Id = '7zip.7zip'; Name = '7-Zip' },
        @{ Id = 'VideoLAN.VLC'; Name = 'VLC Media Player' }
    )
    
    # .NET Framework and Desktop Runtimes
    $dotnetApps = @(
        @{ Id = 'Microsoft.DotNet.Framework.4.8.1'; Name = '.NET Framework 4.8.1' },
        @{ Id = 'Microsoft.DotNet.DesktopRuntime.8'; Name = '.NET Desktop Runtime 8' },
        @{ Id = 'Microsoft.DotNet.DesktopRuntime.8'; Name = '.NET Desktop Runtime x64 8' },  # Same package for x64
        @{ Id = 'Microsoft.DotNet.DesktopRuntime.9'; Name = '.NET Desktop Runtime 9' },
        @{ Id = 'Microsoft.DotNet.DesktopRuntime.9'; Name = '.NET Desktop Runtime x64 9' }   # Same package for x64
    )
    
    # Visual C++ Redistributables (All requested versions - x64 and x86 only)
    $vcredistApps = @(
        # 2015+ (Latest - recommended)
        @{ Id = 'Microsoft.VCRedist.2015+.x64'; Name = 'VC Redist x64 2015+' },
        @{ Id = 'Microsoft.VCRedist.2015+.x86'; Name = 'VC Redist x86 2015+' },
        
        # 2013
        @{ Id = 'Microsoft.VCRedist.2013.x64'; Name = 'VC Redist x64 2013' },
        @{ Id = 'Microsoft.VCRedist.2013.x86'; Name = 'VC Redist x86 2013' },
        
        # 2012
        @{ Id = 'Microsoft.VCRedist.2012.x64'; Name = 'VC Redist x64 2012' },
        @{ Id = 'Microsoft.VCRedist.2012.x86'; Name = 'VC Redist x86 2012' },
        
        # 2010
        @{ Id = 'Microsoft.VCRedist.2010.x64'; Name = 'VC Redist x64 2010' },
        @{ Id = 'Microsoft.VCRedist.2010.x86'; Name = 'VC Redist x86 2010' },
        
        # 2008
        @{ Id = 'Microsoft.VCRedist.2008.x64'; Name = 'VC Redist x64 2008' },
        @{ Id = 'Microsoft.VCRedist.2008.x86'; Name = 'VC Redist x86 2008' },
        
        # 2005
        @{ Id = 'Microsoft.VCRedist.2005.x64'; Name = 'VC Redist x64 2005' },
        @{ Id = 'Microsoft.VCRedist.2005.x86'; Name = 'VC Redist x86 2005' }
    )

	# Combine app lists based on parameters
	$appsToInstall = $coreApps + $dotnetApps + $vcredistApps

	# Add Java runtimes if not skipped
	$javaApps = @()	
	if (-not $SkipJavaRuntimes) {
		$javaApps = @(@{ Id = 'Oracle.JavaRuntimeEnvironment'; Name = 'Java Runtime Environment' })
		$appsToInstall += $javaApps
	}

		if ($DryRun) {
			Write-Log "DryRun: Would install $($appsToInstall.Count) applications" -Level 'INFO' -Component 'INSTALL'
			foreach ($app in $appsToInstall) {
				$Script:ActionsSummary.AppsInstalled += "DryRun-$($app.Name)"
			}
			return $appsToInstall.Count
		}

	$totalCount = $appsToInstall.Count

	Write-Log "Installing $totalCount applications and runtime libraries..."
	Write-Log "Categories: Core Apps ($($coreApps.Count)), .NET ($($dotnetApps.Count)), VC++ Redist ($($vcredistApps.Count)), Java Runtime ($(if (-not $SkipJavaRuntimes) { 1 } else { 0 }))"

	$successCount = Invoke-ParallelWingetInstall -AppList $appsToInstall -MaxConcurrentJobs 3
    
    Write-Log "App installation complete: $successCount/$totalCount successful"
    
    # Log summary by category
    Write-Log "Installation Summary:"
    Write-Log "- Core Applications: $($coreApps.Count) packages"
    Write-Log "- .NET Frameworks/Runtimes: $($dotnetApps.Count) packages"
    Write-Log "- Visual C++ Redistributables: $($vcredistApps.Count) packages"
	if (-not $SkipJavaRuntimes) {
    Write-Log "- Java Runtime: $($javaApps.Count) package(s)"
	}

	return ($successCount -ge ($totalCount * 0.8))  # Consider successful if 80% or more installed
}

# ================================
# Enhanced System Configuration
# ================================

function Set-SystemConfigurationAllUsers {
    Write-Log "Configuring system-wide settings for all users..." -Component 'SYSTEM'
    
    if ($DryRun) {
        Write-Log "DryRun: Would configure system-wide settings" -Level 'INFO' -Component 'SYSTEM'
        return
    }
    
    # Create backup directory
    $backupDir = Join-Path $PSScriptRoot "RegistryBackups_$(Get-Date -Format 'yyyyMMdd_HHmmss')"
    New-Item -Path $backupDir -ItemType Directory -Force | Out-Null
    Write-Log "Created registry backup directory: $backupDir" -Component 'SYSTEM'
    
    try {
        # Machine-wide policies (affects all users)
        $systemSettings = @{
            # Disable Windows Consumer Features and Tips for all users
            'HKLM:\SOFTWARE\Policies\Microsoft\Windows\CloudContent' = @{
                'DisableWindowsConsumerFeatures' = 1
                'DisableConsumerAccountStateContent' = 1
                'DisableTailoredExperiencesWithDiagnosticData' = 1
                'DisableSoftLanding' = 1
                'DisableWindowsSpotlightFeatures' = 1
            }
            
            # Disable Windows Telemetry
            'HKLM:\SOFTWARE\Policies\Microsoft\Windows\DataCollection' = @{
                'AllowTelemetry' = 0
                'MaxTelemetryAllowed' = 0
            }
            
            # Disable Windows Error Reporting
            'HKLM:\SOFTWARE\Microsoft\Windows\Windows Error Reporting' = @{
                'Disabled' = 1
            }
            
            # Disable Customer Experience Improvement Program
            'HKLM:\SOFTWARE\Microsoft\SQMClient\Windows' = @{
                'CEIPEnable' = 0
            }
            
            # Disable advertising ID
            'HKLM:\SOFTWARE\Policies\Microsoft\Windows\AdvertisingInfo' = @{
                'DisabledByGroupPolicy' = 1
            }
            
            # Disable OneDrive for all users
            'HKLM:\SOFTWARE\Policies\Microsoft\Windows\OneDrive' = @{
                'DisableFileSyncNGSC' = 1
                'DisableFileSync' = 1
            }
        }
        
        foreach ($keyPath in $systemSettings.Keys) {
            # Backup existing registry key
            Backup-RegistryKey -KeyPath $keyPath -BackupPath $backupDir
            
            $operation = {
                if (-not (Test-Path $keyPath)) {
                    New-Item -Path $keyPath -Force | Out-Null
                }
                
                foreach ($valueName in $systemSettings[$keyPath].Keys) {
                    $value = $systemSettings[$keyPath][$valueName]
                    Set-ItemProperty -Path $keyPath -Name $valueName -Value $value -Type DWord -Force
                    Write-Log "Set system setting: $keyPath\$valueName = $value" -Level 'DEBUG' -Component 'REGISTRY'
                    $Script:ActionsSummary.RegistryKeysModified += "$keyPath\$valueName"
                }
            }
            
            Invoke-RegistryOperation -Operation $operation -Description "Configure registry path: $keyPath"
        }
        
        # Disable Windows services that affect all users
        $servicesToDisable = @(
            'DiagTrack',  # Connected User Experiences and Telemetry
            'dmwappushservice',  # WAP Push Message Routing Service
            'lfsvc',  # Geolocation Service
            'MapsBroker',  # Downloaded Maps Manager
            'NetTcpPortSharing',  # Net.Tcp Port Sharing Service
            'RemoteAccess',  # Routing and Remote Access
            'RemoteRegistry',  # Remote Registry
            'SharedAccess',  # Internet Connection Sharing
            'TrkWks',  # Distributed Link Tracking Client
            'WbioSrvc',  # Windows Biometric Service
            'WMPNetworkSvc',  # Windows Media Player Network Sharing Service
            'XblAuthManager',  # Xbox Live Auth Manager
            'XblGameSave',  # Xbox Live Game Save Service
            'XboxNetApiSvc'  # Xbox Live Networking Service
        )
        
        foreach ($serviceName in $servicesToDisable) {
            try {
                $service = Get-Service -Name $serviceName -ErrorAction SilentlyContinue
                if ($service) {
                    Write-Log "Disabling service: $serviceName" -Component 'SERVICE'
                    Stop-Service -Name $serviceName -Force -ErrorAction SilentlyContinue
                    Set-Service -Name $serviceName -StartupType Disabled -ErrorAction SilentlyContinue
                    $Script:ActionsSummary.ServicesDisabled += $serviceName
                }
            }
            catch {
                Write-Log "Could not disable service $serviceName`: $($_.Exception.Message)" -Level 'WARN' -Component 'SERVICE' -ErrorCode 2001
            }
        }
        
        Write-Log "System-wide configuration completed" -Component 'SYSTEM'
    }
    catch {
        Write-Log "Error configuring system: $($_.Exception.Message)" -Level 'ERROR' -Component 'SYSTEM' -ErrorCode 2000
    }
}

function Set-DefaultUserProfile {
    Write-Log "Configuring default user profile for future accounts..."
    
    if ($SkipDefaultUserConfig) {
        Write-Log "Skipping default user configuration (SkipDefaultUserConfig flag set)"
        return
    }
    
    if ($DryRun) {
        Write-Log "DryRun: Would configure default user profile" -Level 'INFO'
        return
    }
    
    $defaultUserMounted = $false
    
    try {
        # Verify HKU drive exists
        if (-not (Get-PSDrive -Name HKU -ErrorAction SilentlyContinue)) {
            Write-Log "HKU: drive not available, attempting to recreate..." -Level 'WARN'
            if (-not (Initialize-RegistryDrives)) {
                Write-Log "Cannot configure default user profile - HKU drive unavailable" -Level 'ERROR'
                return
            }
        }
        
        # Mount default user profile
        $defaultUserPath = "${env:SystemDrive}\Users\Default\NTUSER.DAT"
        if (Test-Path $defaultUserPath) {
            Write-Log "Mounting default user registry hive from: $defaultUserPath"
            reg load "HKU\DefaultUser" $defaultUserPath 2>$null
            
            if ($LASTEXITCODE -eq 0) {
                $defaultUserMounted = $true
                Write-Log "Successfully mounted default user registry hive"
                
                # Wait for registry to be available
                Start-Sleep -Seconds 3
                
                # Configure settings for new users
                $defaultUserSettings = @{
                    # Disable consumer features
                    'SOFTWARE\Policies\Microsoft\Windows\CloudContent' = @{
                        'DisableWindowsConsumerFeatures' = 1
                        'DisableConsumerAccountStateContent' = 1
                        'DisableTailoredExperiencesWithDiagnosticData' = 1
                    }
                    
                    # Privacy settings
                    'SOFTWARE\Microsoft\Windows\CurrentVersion\Privacy' = @{
                        'TailoredExperiencesWithDiagnosticDataEnabled' = 0
                    }
                    
                    # Disable suggestions and tips
                    'SOFTWARE\Microsoft\Windows\CurrentVersion\ContentDeliveryManager' = @{
                        'SilentInstalledAppsEnabled' = 0
                        'SystemPaneSuggestionsEnabled' = 0
                        'SoftLandingEnabled' = 0
                        'RotatingLockScreenEnabled' = 0
                        'RotatingLockScreenOverlayEnabled' = 0
                        'SubscribedContent-310093Enabled' = 0
                        'SubscribedContent-314559Enabled' = 0
                        'SubscribedContent-338387Enabled' = 0
                        'SubscribedContent-338388Enabled' = 0
                        'SubscribedContent-338389Enabled' = 0
                        'SubscribedContent-338393Enabled' = 0
                        'SubscribedContent-353694Enabled' = 0
                        'SubscribedContent-353696Enabled' = 0
                    }
                }
                
                foreach ($keyPath in $defaultUserSettings.Keys) {
                    $fullPath = "HKU:\DefaultUser\$keyPath"
                    
                    $operation = {
                        # Verify HKU drive is still available
                        if (-not (Test-Path "HKU:\")) {
                            throw "HKU: drive became unavailable during configuration"
                        }
                        
                        if (-not (Test-Path $fullPath)) {
                            Write-Log "Creating registry path: $fullPath" -Level 'DEBUG'
                            New-Item -Path $fullPath -Force | Out-Null
                        }
                        
                        foreach ($valueName in $defaultUserSettings[$keyPath].Keys) {
                            $value = $defaultUserSettings[$keyPath][$valueName]
                            Set-ItemProperty -Path $fullPath -Name $valueName -Value $value -Type DWord -Force
                            Write-Log "Set default user setting: $keyPath\$valueName = $value" -Level 'DEBUG'
                        }
                    }
                    
                    Invoke-RegistryOperation -Operation $operation -Description "Configure default user registry path: $keyPath"
                }
            } else {
                Write-Log "Failed to mount default user registry hive (Exit code: $LASTEXITCODE)" -Level 'WARN'
            }
        } else {
            Write-Log "Default user profile not found at: $defaultUserPath" -Level 'WARN'
        }
    }
    catch {
        Write-Log "Error configuring default user profile: $($_.Exception.Message)" -Level 'ERROR'
    }
    finally {
        # Enhanced unmount process for default user
        if ($defaultUserMounted) {
            Write-Log "Unmounting default user registry hive..."
            
            $maxAttempts = 3
            $attempt = 1
            $unmountSuccess = $false
            
            while ($attempt -le $maxAttempts -and -not $unmountSuccess) {
                # Force garbage collection and handle cleanup
                [System.GC]::Collect()
                [System.GC]::WaitForPendingFinalizers()
                [System.GC]::Collect()
                
                # Close any open registry handles
                try {
                    $registryKey = [Microsoft.Win32.Registry]::Users.OpenSubKey("DefaultUser", $false)
                    if ($registryKey) {
                        $registryKey.Close()
                        $registryKey.Dispose()
                    }
                }
                catch {
                    # Registry key might not be open
                }
                
                Start-Sleep -Seconds 2
                
                reg unload "HKU\DefaultUser" 2>$null
                $exitCode = $LASTEXITCODE
                
                if ($exitCode -eq 0) {
                    Write-Log "Successfully unmounted default user registry hive"
                    $unmountSuccess = $true
                } else {
                    Write-Log "Default user unmount attempt $attempt failed (Exit code: $exitCode)" -Level 'WARN'
                    if ($attempt -lt $maxAttempts) {
                        Start-Sleep -Seconds 3
                    }
                }
                
                $attempt++
            }
            
            if (-not $unmountSuccess) {
                Write-Log "Failed to unmount default user hive after $maxAttempts attempts. This may not affect functionality." -Level 'WARN'
            }
        }
    }
}

function Configure-AllUserProfiles {
    param([array]$UserProfiles)
    
    Write-Log "Configuring settings for all existing user profiles..."
    
    if ($DryRun) {
        Write-Log "DryRun: Would configure $($UserProfiles.Count) user profiles" -Level 'INFO'
        return
    }
    
    foreach ($profile in $UserProfiles) {
        Write-Log "Configuring profile: $($profile.Username)"
        
        try {
            if (Test-Path $profile.RegistryPath) {
                # Configure user-specific settings
                $userSettings = @{
                    # Disable OneDrive
                    'SOFTWARE\Microsoft\Windows\CurrentVersion\Run' = @{
                        'OneDriveSetup' = $null  # Remove OneDrive startup
                    }
                    
                    # Privacy settings
                    'SOFTWARE\Microsoft\Windows\CurrentVersion\Privacy' = @{
                        'TailoredExperiencesWithDiagnosticDataEnabled' = 0
                    }
                    
                    # Disable Windows tips and suggestions
                    'SOFTWARE\Microsoft\Windows\CurrentVersion\ContentDeliveryManager' = @{
                        'SilentInstalledAppsEnabled' = 0
                        'SystemPaneSuggestionsEnabled' = 0
                        'SoftLandingEnabled' = 0
                    }
                }
                
                foreach ($keyPath in $userSettings.Keys) {
                    $fullPath = "$($profile.RegistryPath)\$keyPath"
                    
                    $operation = {
                        if (-not (Test-Path $fullPath)) {
                            New-Item -Path $fullPath -Force | Out-Null
                        }
                        
                        foreach ($valueName in $userSettings[$keyPath].Keys) {
                            $value = $userSettings[$keyPath][$valueName]
                            
                            if ($null -eq $value) {
                                # Remove the value
                                Remove-ItemProperty -Path $fullPath -Name $valueName -ErrorAction SilentlyContinue
                                Write-Log "Removed $($profile.Username) setting: $keyPath\$valueName" -Level 'DEBUG'
                            } else {
                                Set-ItemProperty -Path $fullPath -Name $valueName -Value $value -Type DWord -Force
                                Write-Log "Set $($profile.Username) setting: $keyPath\$valueName = $value" -Level 'DEBUG'
                            }
                        }
                    }
                    
                    Invoke-RegistryOperation -Operation $operation -Description "Configure user registry for $($profile.Username): $keyPath"
                }
            } else {
                Write-Log "Registry path not accessible for $($profile.Username): $($profile.RegistryPath)" -Level 'WARN'
            }
        }
        catch {
            Write-Log "Error configuring profile $($profile.Username): $($_.Exception.Message)" -Level 'WARN'
        }
    }
}

# ================================
# Main Execution
# ================================

try {
    # Initialize logging
	Write-Log "===== DeployWorkstation-AllUsers.ps1 v3.0 Started =====" -Component 'MAIN'
	Write-Log "PowerShell Version: $($PSVersionTable.PSVersion)" -Component 'MAIN'
	Write-Log "OS Version: $((Get-CimInstance Win32_OperatingSystem).Caption)" -Component 'MAIN'
	Write-Log "DryRun mode: $($DryRun.IsPresent)" -Component 'MAIN'
	Write-Log "Parameters: SkipAppInstall=$($SkipAppInstall.IsPresent), SkipBloatwareRemoval=$($SkipBloatwareRemoval.IsPresent), SkipDefaultUserConfig=$($SkipDefaultUserConfig.IsPresent)" -Component 'MAIN'

	# Set execution policy for session
	Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass -Force

	# Initialize Event Log source
	Initialize-EventLogSource
	
	# Handle winget export/import operations first
    if ($ExportWingetApps) {
        if (-not (Test-Winget)) {
            Write-Log "Winget is required for export but not available. Please install App Installer from Microsoft Store." -Level 'ERROR' -Component 'MAIN' -ErrorCode 1004
            exit 1
        }
        Export-WingetApps
        Write-Log "Export completed. Exiting." -Component 'MAIN'
        exit 0
    }
    
    # Validate prerequisites
    if (-not (Test-Prerequisites)) {
        Write-Log "Prerequisite validation failed. Cannot continue." -Level 'ERROR' -Component 'MAIN' -ErrorCode 1005
        exit 1
    }
    
    # Initialize registry drives first
    if (-not (Initialize-RegistryDrives)) {
        Write-Log "Failed to initialize registry drives. Cannot continue." -Level 'ERROR' -Component 'MAIN' -ErrorCode 1006
        exit 1
    }
    
    # Verify winget is available
    if (-not (Test-Winget)) {
        Write-Log "Winget is required but not available. Please install App Installer from Microsoft Store." -Level 'ERROR' -Component 'MAIN' -ErrorCode 1007
        exit 1
    }
    
    Initialize-WingetSources
    
    # Handle winget import if requested
    if ($ImportWingetApps) {
        Import-WingetApps
    }
    
    # Get all user profiles
    $userProfiles = Get-AllUserProfiles
    
    # Mount user registry hives for configuration
    Mount-UserRegistryHives -UserProfiles $userProfiles
    
    # Execute bloatware removal
    if (-not $SkipBloatwareRemoval) {
        Write-Log "=== Starting Enhanced Bloatware Removal for All Users ===" -Component 'MAIN'
        
        $bloatwarePatterns = @(
            'CoPilot', 'Outlook', 'Quick Assist', 'Remote Desktop',
            'Mixed Reality Portal', 'Clipchamp', 'Xbox', 'Family',
            'Skype', 'LinkedIn', 'OneDrive', 'Teams', 'Disney',
            'Netflix', 'Spotify', 'TikTok', 'Instagram', 'Facebook',
            'Candy', 'Twitter', 'Minecraft'
        )
        
        Remove-WingetApps -AppPatterns $bloatwarePatterns
        Remove-AppxPackagesAllUsers  # Enhanced version
        Remove-WindowsCapabilities
        Remove-McAfeeProducts
        
        Write-Log "=== Enhanced Bloatware Removal Completed ===" -Component 'MAIN'
    } else {
        Write-Log "Skipping bloatware removal (SkipBloatwareRemoval flag set)" -Component 'MAIN'
    }
    
    # Execute application installation
    if (-not $SkipAppInstall) {
        Write-Log "=== Starting Application Installation ===" -Component 'MAIN'
        Install-StandardApps
        Write-Log "=== Application Installation Completed ===" -Component 'MAIN'
    } else {
        Write-Log "Skipping application installation (SkipAppInstall flag set)" -Component 'MAIN'
    }
    
    # Configure system settings for all users
    Set-SystemConfigurationAllUsers
    
    # Configure existing user profiles
    Configure-AllUserProfiles -UserProfiles $userProfiles
    
    # Configure default user profile for future accounts
    Set-DefaultUserProfile
    
    # Clean up mounted registry hives with enhanced error handling
    if ($userProfiles -and $userProfiles.Count -gt 0) {
        Write-Log "Starting registry cleanup process..." -Component 'CLEANUP'
        Dismount-UserRegistryHives -UserProfiles $userProfiles
    } else {
        Write-Log "No user profiles to dismount" -Component 'CLEANUP'
    }
    
    Write-Log "===== DeployWorkstation-AllUsers.ps1 v3.0 Completed Successfully =====" -Component 'MAIN'
    
    # Display comprehensive summary
    Write-ExecutionSummary
    
    Write-Host "`nPress Enter to exit..." -ForegroundColor Yellow
    Read-Host | Out-Null
    
}
catch {
    Write-Log "Critical error: $($_.Exception.Message)" -Level 'ERROR' -Component 'MAIN' -ErrorCode 9999
    Write-Host "`n*** Setup failed! Check log at: $LogPath ***" -ForegroundColor Red
    
    # Ensure registry hives are cleaned up even on error
    if ($userProfiles -and $userProfiles.Count -gt 0) {
        Write-Log "Emergency cleanup: Dismounting registry hives due to error..." -Component 'CLEANUP'
        try {
            Dismount-UserRegistryHives -UserProfiles $userProfiles
        }
        catch {
            Write-Log "Emergency cleanup failed: $($_.Exception.Message)" -Level 'ERROR' -Component 'CLEANUP' -ErrorCode 9998
        }
    }
    
    # Display summary even on failure
    Write-ExecutionSummary
    
    exit 1
}
finally {
    # Cleanup registry drives and restore progress preference
    Remove-RegistryDrives
    $ProgressPreference = 'Continue'
}
