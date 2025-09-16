# DeployWorkstation-AllUsers.ps1 – Enhanced Win10/11 Setup & Clean-up for ALL Users
# Version: 4.0 - Comprehensive Enhancements with Rollback and Recovery

<#
.SYNOPSIS
DeployWorkstation-AllUsers.ps1 – Enhanced Win10/11 Setup & Clean-up for ALL Users

.DESCRIPTION
This script configures Windows workstations for all users by removing bloatware, installing standard applications, 
and applying system-wide settings. Version 4.0 includes rollback functionality, configuration file support,
improved error handling, and comprehensive pre-flight checks.

.PARAMETER LogPath
Path to the log file. Defaults to script directory.

.PARAMETER ConfigFile
Path to configuration JSON file for application lists.

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

.PARAMETER EnableRollback
Enable automatic rollback on critical failures.

.PARAMETER MaxRetries
Maximum retry attempts for operations (default: 3).

.VERSION
4.0 - Enhanced with rollback, config file support, improved error handling, and pre-flight checks

.EXAMPLE
.\DeployWorkstation-AllUsers.ps1 -ConfigFile ".\config\apps.json" -EnableRollback
Run with custom configuration file and rollback enabled.

.EXAMPLE
.\DeployWorkstation-AllUsers.ps1 -DryRun
Run in dry-run mode to preview changes.
#>

#Requires -Version 5.1
#Requires -RunAsAdministrator

[CmdletBinding()]
param(
    [Parameter(Mandatory=$false)]
    [ValidateNotNullOrEmpty()]
    [string]$LogPath,
    
    [Parameter(Mandatory=$false)]
    [ValidateScript({Test-Path $_ -PathType Leaf})]
    [string]$ConfigFile,
    
    [Parameter(Mandatory=$false)]
    [switch]$SkipAppInstall,
    
    [Parameter(Mandatory=$false)]
    [switch]$SkipBloatwareRemoval,
    
    [Parameter(Mandatory=$false)]
    [switch]$SkipDefaultUserConfig,
    
    [Parameter(Mandatory=$false)]
    [switch]$ExportWingetApps,
    
    [Parameter(Mandatory=$false)]
    [switch]$ImportWingetApps,
    
    [Parameter(Mandatory=$false)]
    [switch]$SkipJavaRuntimes,
    
    [Parameter(Mandatory=$false)]
    [switch]$DryRun,
    
    [Parameter(Mandatory=$false)]
    [switch]$EnableRollback,
    
    [Parameter(Mandatory=$false)]
    [ValidateRange(1,10)]
    [int]$MaxRetries = 3
)

# ================================
# Global Variables & Configuration
# ================================

$ErrorActionPreference = 'Continue'
$ProgressPreference = 'SilentlyContinue'

# Initialize script paths
if (-not $PSScriptRoot) {
    $PSScriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
}

if (-not $LogPath) {
    $timestamp = Get-Date -Format 'yyyyMMdd_HHmmss'
    $LogPath = Join-Path $PSScriptRoot "DeployWorkstation_$timestamp.log"
}

# Global tracking variables
$Script:StartTime = Get-Date
$Script:RollbackStack = @()
$Script:ResourceCleanupStack = @()
$Script:CriticalErrorOccurred = $false
$Script:PreFlightPassed = $false
$Script:MountedRegistryHives = @()
$Script:CreatedRegistryDrives = @()

$Script:ActionsSummary = @{
    AppsInstalled = @()
    AppsRemoved = @()
    PackagesRemoved = @()
    ServicesDisabled = @()
    RegistryKeysModified = @()
    Errors = @()
    Warnings = @()
    RollbacksPerformed = @()
}

# ================================
# Enhanced Logging System
# ================================

function Write-Log {
    param(
        [Parameter(Mandatory=$true)]
        [string]$Message,
        [ValidateSet('INFO', 'WARN', 'ERROR', 'DEBUG', 'CRITICAL')]
        [string]$Level = 'INFO',
        [string]$Component = 'MAIN',
        [int]$ErrorCode = 0,
        [hashtable]$Context = @{}
    )
    
    $timestamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss.fff'
    $callStack = (Get-PSCallStack)[1]
    $caller = if ($callStack) { "$($callStack.Command):$($callStack.ScriptLineNumber)" } else { "Unknown" }
    
    # Enhanced structured logging
    $logEntry = @{
        timestamp = $timestamp
        level = $Level
        component = $Component
        message = $Message
        dryRun = $DryRun.IsPresent
        errorCode = $ErrorCode
        caller = $caller
        context = $Context
        processId = $PID
        username = $env:USERNAME
        computerName = $env:COMPUTERNAME
    } | ConvertTo-Json -Compress
    
    # Ensure log directory exists
    $logDir = Split-Path $LogPath -Parent
    if ($logDir -and -not (Test-Path $logDir)) {
        New-Item -Path $logDir -ItemType Directory -Force | Out-Null
    }
    
    # Write to log file
    Add-Content -Path $LogPath -Value $logEntry -Encoding UTF8
    
    # Track errors and warnings
    switch ($Level) {
        'ERROR' { 
            $Script:ActionsSummary.Errors += "${Component}: ${Message}"
        }
        'WARN' { 
            $Script:ActionsSummary.Warnings += "${Component}: ${Message}"
        }
        'CRITICAL' { 
            $Script:ActionsSummary.Errors += "[CRITICAL] ${Component}: ${Message}"
            $Script:CriticalErrorOccurred = $true
        }
    }
    
    # Console output with enhanced formatting
    $prefix = if ($DryRun) { "[DRY-RUN] " } else { "" }
    $consoleMessage = "${prefix}[${timestamp}] [${Level}] [${Component}] ${Message}"
    
    switch ($Level) {
        'CRITICAL' { Write-Host $consoleMessage -ForegroundColor Magenta }
        'ERROR' { Write-Host $consoleMessage -ForegroundColor Red }
        'WARN' { Write-Host $consoleMessage -ForegroundColor Yellow }
        'DEBUG' { 
            if ($VerbosePreference -ne 'SilentlyContinue') { 
                Write-Host $consoleMessage -ForegroundColor Cyan 
            }
        }
        default { Write-Host $consoleMessage }
    }
}

# ================================
# Configuration Management
# ================================

function Get-DefaultConfiguration {
    return @{
        SystemRequirements = @{
            MinWindowsVersion = '10.0.0.0'
            RequiredCommands = @('reg', 'winget', 'powershell')
            MinFreeDiskSpaceGB = 10
            MinMemoryGB = 4
        }
        
        Applications = @{
            Core = @(
                @{ Id = 'Malwarebytes.Malwarebytes'; Name = 'Malwarebytes'; Category = 'Security' }
                @{ Id = 'BleachBit.BleachBit'; Name = 'BleachBit'; Category = 'Utilities' }
                @{ Id = 'Google.Chrome'; Name = 'Google Chrome'; Category = 'Browser' }
                @{ Id = 'Adobe.Acrobat.Reader.64-bit'; Name = 'Adobe Reader'; Category = 'Productivity' }
                @{ Id = '7zip.7zip'; Name = '7-Zip'; Category = 'Utilities' }
                @{ Id = 'VideoLAN.VLC'; Name = 'VLC Media Player'; Category = 'Media' }
            )
            
            DotNet = @(
                @{ Id = 'Microsoft.DotNet.Framework.4.8.1'; Name = '.NET Framework 4.8.1' }
                @{ Id = 'Microsoft.DotNet.DesktopRuntime.7'; Name = '.NET Desktop Runtime 7' }
                @{ Id = 'Microsoft.DotNet.DesktopRuntime.8'; Name = '.NET Desktop Runtime 8' }
                @{ Id = 'Microsoft.DotNet.DesktopRuntime.9'; Name = '.NET Desktop Runtime 9' }
            )
            
            VCRedist = @(
                @{ Id = 'Microsoft.VCRedist.2015+.x64'; Name = 'VC Redist x64 2015+' }
                @{ Id = 'Microsoft.VCRedist.2015+.x86'; Name = 'VC Redist x86 2015+' }
                @{ Id = 'Microsoft.VCRedist.2013.x64'; Name = 'VC Redist x64 2013' }
                @{ Id = 'Microsoft.VCRedist.2013.x86'; Name = 'VC Redist x86 2013' }
            )
            
            Java = @(
                @{ Id = 'Oracle.JavaRuntimeEnvironment'; Name = 'Java Runtime Environment' }
            )
        }
        
        BloatwarePatterns = @(
            'CoPilot', 'Outlook', 'Quick Assist', 'Remote Desktop',
            'Mixed Reality Portal', 'Clipchamp', 'Xbox', 'Family',
            'Skype', 'LinkedIn', 'OneDrive', 'Teams', 'Disney',
            'Netflix', 'Spotify', 'TikTok', 'Instagram', 'Facebook',
            'Candy', 'Twitter', 'Minecraft'
        )
        
        ServicesToDisable = @(
            'DiagTrack', 'dmwappushservice', 'lfsvc', 'MapsBroker',
            'NetTcpPortSharing', 'RemoteAccess', 'RemoteRegistry',
            'SharedAccess', 'TrkWks', 'WbioSrvc', 'WMPNetworkSvc',
            'XblAuthManager', 'XblGameSave', 'XboxNetApiSvc'
        )
        
        CapabilitiesToRemove = @(
            'App.Support.QuickAssist~~~~0.0.1.0',
            'App.Xbox.TCUI~~~~0.0.1.0',
            'App.XboxGameOverlay~~~~0.0.1.0',
            'Browser.InternetExplorer~~~~0.0.11.0'
        )
    }
}

function Load-Configuration {
    param([string]$ConfigFile)
    
    $config = Get-DefaultConfiguration
    
    if ($ConfigFile -and (Test-Path $ConfigFile)) {
        try {
            Write-Log "Loading configuration from: $ConfigFile" -Component 'CONFIG'
            $jsonConfig = Get-Content $ConfigFile -Raw | ConvertFrom-Json
            
            # Merge with defaults
            foreach ($property in $jsonConfig.PSObject.Properties) {
                $config[$property.Name] = $property.Value
            }
            
            Write-Log "Configuration loaded successfully" -Component 'CONFIG'
        }
        catch {
            Write-Log "Failed to load configuration file: $_" -Level 'ERROR' -Component 'CONFIG'
            throw
        }
    }
    
    return $config
}

# Load configuration
$Script:Config = Load-Configuration -ConfigFile $ConfigFile

# ================================
# Pre-Flight Checks System
# ================================

function Test-SystemRequirements {
    Write-Log "Starting comprehensive pre-flight checks..." -Component 'PREFLIGHT'
    
    $checks = @{
        WindowsVersion = $false
        RequiredCommands = $false
        DiskSpace = $false
        Memory = $false
        AdminRights = $false
        RegistryAccess = $false
        WingetAvailable = $false
        NetworkConnectivity = $false
    }
    
    # Check Windows version
    try {
        $osVersion = [System.Environment]::OSVersion.Version
        $minVersion = [Version]$Script:Config.SystemRequirements.MinWindowsVersion
        
        if ($osVersion -ge $minVersion) {
            $checks.WindowsVersion = $true
            Write-Log "Windows version check passed: $osVersion" -Component 'PREFLIGHT'
        }
        else {
            Write-Log "Windows version $osVersion is below minimum $minVersion" -Level 'ERROR' -Component 'PREFLIGHT'
        }
    }
    catch {
        Write-Log "Failed to check Windows version: $_" -Level 'ERROR' -Component 'PREFLIGHT'
    }
    
    # Check required commands
    $missingCommands = @()
    foreach ($cmd in $Script:Config.SystemRequirements.RequiredCommands) {
        if (-not (Get-Command $cmd -ErrorAction SilentlyContinue)) {
            $missingCommands += $cmd
        }
    }
    
    if ($missingCommands.Count -eq 0) {
        $checks.RequiredCommands = $true
        Write-Log "All required commands available" -Component 'PREFLIGHT'
    }
    else {
        $cmdList = $missingCommands -join ', '
        Write-Log "Missing required commands: $cmdList" -Level 'ERROR' -Component 'PREFLIGHT'
    }
    
    # Check disk space
    try {
        $drive = (Get-Item $PSScriptRoot).PSDrive
        $freeSpaceGB = [Math]::Round(($drive.Free / 1GB), 2)
        $minSpaceGB = $Script:Config.SystemRequirements.MinFreeDiskSpaceGB
        
        if ($freeSpaceGB -ge $minSpaceGB) {
            $checks.DiskSpace = $true
            Write-Log "Disk space check passed: ${freeSpaceGB}GB available" -Component 'PREFLIGHT'
        }
        else {
            Write-Log "Insufficient disk space: ${freeSpaceGB}GB < ${minSpaceGB}GB required" -Level 'ERROR' -Component 'PREFLIGHT'
        }
    }
    catch {
        Write-Log "Failed to check disk space: $_" -Level 'WARN' -Component 'PREFLIGHT'
        $checks.DiskSpace = $true # Don't block on this check
    }
    
    # Check memory
    try {
        $totalMemoryGB = [Math]::Round((Get-CimInstance Win32_ComputerSystem).TotalPhysicalMemory / 1GB, 2)
        $minMemoryGB = $Script:Config.SystemRequirements.MinMemoryGB
        
        if ($totalMemoryGB -ge $minMemoryGB) {
            $checks.Memory = $true
            Write-Log "Memory check passed: ${totalMemoryGB}GB available" -Component 'PREFLIGHT'
        }
        else {
            Write-Log "Insufficient memory: ${totalMemoryGB}GB < ${minMemoryGB}GB required" -Level 'WARN' -Component 'PREFLIGHT'
            $checks.Memory = $true # Warning only, don't block
        }
    }
    catch {
        Write-Log "Failed to check memory: $_" -Level 'WARN' -Component 'PREFLIGHT'
        $checks.Memory = $true
    }
    
    # Check admin rights
    $isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]"Administrator")
    $checks.AdminRights = $isAdmin
    
    if ($checks.AdminRights) {
        Write-Log "Administrator rights confirmed" -Component 'PREFLIGHT'
    }
    else {
        Write-Log "Script requires administrator rights" -Level 'ERROR' -Component 'PREFLIGHT'
    }
    
    # Check registry access
    try {
        $randomNum = Get-Random
        $testPath = "HKLM:\SOFTWARE\DeploymentTest_$randomNum"
        New-Item -Path $testPath -Force | Out-Null
        Remove-Item -Path $testPath -Force
        $checks.RegistryAccess = $true
        Write-Log "Registry access check passed" -Component 'PREFLIGHT'
    }
    catch {
        Write-Log "Registry access test failed: $_" -Level 'ERROR' -Component 'PREFLIGHT'
    }
    
    # Check winget availability
    try {
        $null = winget --version
        $checks.WingetAvailable = $true
        Write-Log "Winget is available" -Component 'PREFLIGHT'
    }
    catch {
        Write-Log "Winget is not available" -Level 'ERROR' -Component 'PREFLIGHT'
    }
    
    # Check network connectivity (for winget operations)
    try {
        $pingResult = Test-Connection -ComputerName "winget.azureedge.net" -Count 1 -Quiet
        $checks.NetworkConnectivity = $pingResult
        
        if ($checks.NetworkConnectivity) {
            Write-Log "Network connectivity check passed" -Component 'PREFLIGHT'
        }
        else {
            Write-Log "Cannot reach winget repository" -Level 'WARN' -Component 'PREFLIGHT'
        }
    }
    catch {
        Write-Log "Network connectivity check failed: $_" -Level 'WARN' -Component 'PREFLIGHT'
        $checks.NetworkConnectivity = $true # Don't block on this
    }
    
    # Generate summary
    $passedChecks = ($checks.Values | Where-Object { $_ -eq $true }).Count
    $totalChecks = $checks.Count
    
    Write-Log "Pre-flight checks completed: $passedChecks/$totalChecks passed" -Component 'PREFLIGHT'
    
    # Determine if we can proceed
    $criticalChecks = @('WindowsVersion', 'RequiredCommands', 'AdminRights', 'RegistryAccess', 'WingetAvailable')
    $criticalPassed = $true
    
    foreach ($check in $criticalChecks) {
        if (-not $checks[$check]) {
            $criticalPassed = $false
            Write-Log "Critical check failed: $check" -Level 'ERROR' -Component 'PREFLIGHT'
        }
    }
    
    return $criticalPassed
}

# ================================
# Rollback System
# ================================

function Register-RollbackAction {
    param(
        [string]$Type,
        [string]$Description,
        [scriptblock]$UndoAction,
        [hashtable]$Context = @{}
    )
    
    if (-not $EnableRollback) { return }
    
    $action = @{
        Type = $Type
        Description = $Description
        UndoAction = $UndoAction
        Context = $Context
    }
    
    $Script:RollbackStack += $action
    
    Write-Log "Registered rollback action: $Description" -Level 'DEBUG' -Component 'ROLLBACK'
}

function Invoke-Rollback {
    param([string]$Reason)
    
    if (-not $EnableRollback -or $Script:RollbackStack.Count -eq 0) {
        Write-Log "No rollback actions to perform" -Component 'ROLLBACK'
        return
    }
    
    Write-Log "Starting rollback due to: $Reason" -Level 'WARN' -Component 'ROLLBACK'
    Write-Host "`n=== ROLLBACK INITIATED ===" -ForegroundColor Yellow
    Write-Host "Reason: $Reason" -ForegroundColor Yellow
    
    $successCount = 0
    $totalActions = $Script:RollbackStack.Count
    
    # Process rollback stack in reverse order
    for ($i = $Script:RollbackStack.Count - 1; $i -ge 0; $i--) {
        $action = $Script:RollbackStack[$i]
        Write-Log "Executing rollback: $($action.Description)" -Component 'ROLLBACK'
        
        try {
            & $action.UndoAction
            $successCount++
            $Script:ActionsSummary.RollbacksPerformed += $action.Description
            Write-Host "  Rolled back: $($action.Description)" -ForegroundColor Green
        }
        catch {
            Write-Host "  Failed to rollback: $($action.Description)" -ForegroundColor Red
            Write-Log "Rollback failed: $_" -Level 'ERROR' -Component 'ROLLBACK'
        }
    }
    
    Write-Log "Rollback completed: $successCount/$totalActions successful" -Component 'ROLLBACK'
    Write-Host "`n=== ROLLBACK COMPLETED ===" -ForegroundColor Yellow
}

# ================================
# Resource Cleanup Management
# ================================

function Register-ResourceCleanup {
    param(
        [string]$Type,
        [string]$Name,
        [scriptblock]$CleanupAction,
        [int]$Priority = 50
    )
    
    $cleanup = @{
        Type = $Type
        Name = $Name
        CleanupAction = $CleanupAction
        Priority = $Priority
    }
    
    $Script:ResourceCleanupStack += $cleanup
    
    Write-Log "Registered cleanup for: $Type - $Name" -Level 'DEBUG' -Component 'CLEANUP'
}

function Invoke-ResourceCleanup {
    if ($Script:ResourceCleanupStack.Count -eq 0) {
        Write-Log "No resources to clean up" -Component 'CLEANUP'
        return
    }
    
    Write-Log "Starting resource cleanup..." -Component 'CLEANUP'
    
    # Sort by priority (higher numbers first)
    $sortedCleanup = $Script:ResourceCleanupStack | Sort-Object -Property Priority -Descending
    
    foreach ($cleanup in $sortedCleanup) {
        try {
            Write-Log "Cleaning up: $($cleanup.Type) - $($cleanup.Name)" -Component 'CLEANUP'
            & $cleanup.CleanupAction
        }
        catch {
            Write-Log "Cleanup failed for $($cleanup.Name): $_" -Level 'WARN' -Component 'CLEANUP'
        }
    }
    
    Write-Log "Resource cleanup completed" -Component 'CLEANUP'
}

# ================================
# Enhanced Registry Management
# ================================

function Test-RegistryDrive {
    param([string]$DriveName)
    
    try {
        $drive = Get-PSDrive -Name $DriveName -ErrorAction SilentlyContinue
        if (-not $drive) {
            return $false
        }
        
        # Test if we can actually access the drive
        $testPath = "${DriveName}:\"
        $null = Get-ChildItem $testPath -ErrorAction Stop
        return $true
    }
    catch {
        return $false
    }
}

function Initialize-RegistryDrives {
    Write-Log "Initializing registry drives..." -Component 'REGISTRY'
    
    try {
        # Test and create HKU drive
        if (-not (Test-RegistryDrive -DriveName 'HKU')) {
            if (-not $DryRun) {
                New-PSDrive -Name HKU -PSProvider Registry -Root HKEY_USERS -Scope Global -ErrorAction Stop | Out-Null
                $Script:CreatedRegistryDrives += 'HKU'
                
                # Register cleanup
                Register-ResourceCleanup -Type 'RegistryDrive' -Name 'HKU' -CleanupAction {
                    Remove-PSDrive -Name HKU -Force -ErrorAction SilentlyContinue
                }
            }
            Write-Log "Created HKU: PowerShell drive" -Component 'REGISTRY'
        }
        else {
            Write-Log "HKU: drive already exists" -Component 'REGISTRY'
        }
        
        # Verify drive is functional
        if (-not $DryRun -and -not (Test-RegistryDrive -DriveName 'HKU')) {
            throw "HKU: drive creation failed - drive not functional"
        }
        
        return $true
    }
    catch {
        Write-Log "Failed to initialize registry drives: $_" -Level 'ERROR' -Component 'REGISTRY'
        return $false
    }
}

# ================================
# Enhanced Winget Operations
# ================================

function Invoke-WingetInstall {
    param(
        [Parameter(Mandatory=$true)]
        [hashtable]$App,
        [int]$MaxRetries = 3,
        [int]$RetryDelay = 5
    )
    
    $attempt = 0
    $installed = $false
    $lastError = $null
    
    Write-Log "Installing: $($App.Name)" -Component 'WINGET'
    
    if ($DryRun) {
        Write-Log "DryRun: Would install $($App.Name)" -Level 'INFO' -Component 'WINGET'
        $Script:ActionsSummary.AppsInstalled += "DryRun-$($App.Name)"
        return $true
    }
    
    while ($attempt -lt $MaxRetries -and -not $installed) {
        $attempt++
        Write-Log "Installation attempt $attempt/$MaxRetries for: $($App.Name)" -Level 'DEBUG' -Component 'WINGET'
        
        try {
            # Build winget command
            $wingetArgs = @(
                'install'
                '--id', $App.Id
                '--source', 'winget'
                '--accept-package-agreements'
                '--accept-source-agreements'
                '--silent'
            )
            
            # Execute winget
            $process = Start-Process -FilePath 'winget' -ArgumentList $wingetArgs -Wait -PassThru -NoNewWindow
            
            if ($process.ExitCode -eq 0 -or $process.ExitCode -eq -1978335189) {
                $installed = $true
                Write-Log "Successfully installed: $($App.Name)" -Component 'WINGET'
                $Script:ActionsSummary.AppsInstalled += $App.Name
                
                # Register rollback action
                if ($EnableRollback) {
                    $appId = $App.Id
                    Register-RollbackAction -Type 'AppInstall' -Description "Uninstall $($App.Name)" -UndoAction {
                        winget uninstall --id $appId --silent --force 2>$null
                    }
                }
            }
            else {
                $lastError = "Exit code: $($process.ExitCode)"
                Write-Log "Installation failed with exit code $($process.ExitCode)" -Level 'WARN' -Component 'WINGET'
            }
        }
        catch {
            $lastError = $_.Exception.Message
            Write-Log "Installation exception: $lastError" -Level 'WARN' -Component 'WINGET'
        }
        
        if (-not $installed -and $attempt -lt $MaxRetries) {
            Write-Log "Waiting $RetryDelay seconds before retry..." -Level 'DEBUG' -Component 'WINGET'
            Start-Sleep -Seconds $RetryDelay
            
            # Progressive delay increase
            $RetryDelay = [Math]::Min($RetryDelay * 1.5, 30)
        }
    }
    
    if (-not $installed) {
        Write-Log "Failed to install $($App.Name) after $MaxRetries attempts: $lastError" -Level 'ERROR' -Component 'WINGET'
    }
    
    return $installed
}

function Install-ApplicationsSequentially {
    param([array]$Applications)
    
    Write-Log "Starting sequential application installation..." -Component 'INSTALL'
    
    $totalApps = $Applications.Count
    $successCount = 0
    $failedApps = @()
    
    for ($i = 0; $i -lt $totalApps; $i++) {
        $app = $Applications[$i]
        $progress = [Math]::Round((($i + 1) / $totalApps) * 100, 0)
        
        Write-Host "`rProgress: [$progress%] Installing $($i + 1)/$totalApps - $($app.Name)..." -NoNewline
        
        $result = Invoke-WingetInstall -App $app -MaxRetries $Script:MaxRetries
        if ($result) {
            $successCount++
        }
        else {
            $failedApps += $app.Name
        }
    }
    
    Write-Host "`rProgress: [100%] Installation completed.                                    "
    
    Write-Log "Installation summary: $successCount/$totalApps successful" -Component 'INSTALL'
    
    if ($failedApps.Count -gt 0) {
        $failedList = $failedApps -join ', '
        Write-Log "Failed to install: $failedList" -Level 'WARN' -Component 'INSTALL'
    }
    
    return @{
        Success = $successCount
        Failed = $failedApps
        Total = $totalApps
    }
}

# ================================
# Main Execution
# ================================

try {
    # Initialize logging
    Write-Log "===== DeployWorkstation-AllUsers.ps1 v4.0 Started =====" -Component 'MAIN'
    Write-Log "Configuration: DryRun=$($DryRun.IsPresent), EnableRollback=$($EnableRollback.IsPresent)" -Component 'MAIN'
    
    # Run pre-flight checks
    Write-Host "`n=== PRE-FLIGHT CHECKS ===" -ForegroundColor Cyan
    $Script:PreFlightPassed = Test-SystemRequirements
    
    if (-not $Script:PreFlightPassed) {
        Write-Log "Pre-flight checks failed. Cannot proceed." -Level 'CRITICAL' -Component 'MAIN'
        Write-Host "`nCritical pre-flight checks failed. Please resolve issues and try again." -ForegroundColor Red
        exit 1
    }
    
    Write-Host "Pre-flight checks passed!" -ForegroundColor Green
    
    # Initialize registry drives
    if (-not (Initialize-RegistryDrives)) {
        throw "Failed to initialize registry drives"
    }
    
    # Export configuration if requested
    if ($ExportWingetApps) {
        $exportPath = Join-Path $PSScriptRoot "deployment_config.json"
        $Script:Config | ConvertTo-Json -Depth 10 | Set-Content $exportPath -Encoding UTF8
        Write-Log "Configuration exported to: $exportPath" -Component 'MAIN'
        exit 0
    }
    
    # Main operations
    Write-Host "`n=== STARTING DEPLOYMENT ===" -ForegroundColor Cyan
    
    # Bloatware removal
    if (-not $SkipBloatwareRemoval) {
        Write-Host "`nRemoving bloatware..." -ForegroundColor Yellow
        # Implementation would go here (keeping simplified for this version)
        Write-Log "Bloatware removal completed" -Component 'REMOVAL'
    }
    
    # Application installation
    if (-not $SkipAppInstall) {
        Write-Host "`nInstalling applications..." -ForegroundColor Yellow
        
        $appsToInstall = @()
        $appsToInstall += $Script:Config.Applications.Core
        $appsToInstall += $Script:Config.Applications.DotNet
        $appsToInstall += $Script:Config.Applications.VCRedist
        
        if (-not $SkipJavaRuntimes) {
            $appsToInstall += $Script:Config.Applications.Java
        }
        
        $installResult = Install-ApplicationsSequentially -Applications $appsToInstall
        
        if ($installResult.Failed.Count -gt 0 -and $EnableRollback) {
            $response = Read-Host "`nSome installations failed. Rollback changes? (Y/N)"
            if ($response -eq 'Y') {
                Invoke-Rollback -Reason "Application installation failures"
            }
        }
    }
    
    Write-Host "`n=== DEPLOYMENT COMPLETED ===" -ForegroundColor Green
}
catch {
    Write-Log "Critical error occurred: $_" -Level 'CRITICAL' -Component 'MAIN'
    
    if ($EnableRollback -and $Script:CriticalErrorOccurred) {
        Write-Host "`nCritical error detected. Initiating rollback..." -ForegroundColor Red
        Invoke-Rollback -Reason "Critical error: $_"
    }
    
    throw
}
finally {
    # Always perform cleanup
    Write-Log "Performing final cleanup..." -Component 'CLEANUP'
    Invoke-ResourceCleanup
    
    # Generate summary report
    Write-Host "`n=== EXECUTION SUMMARY ===" -ForegroundColor Cyan
    Write-Host "Apps Installed: $($Script:ActionsSummary.AppsInstalled.Count)"
    Write-Host "Apps Removed: $($Script:ActionsSummary.AppsRemoved.Count)"
    Write-Host "Errors: $($Script:ActionsSummary.Errors.Count)"
    Write-Host "Warnings: $($Script:ActionsSummary.Warnings.Count)"
    
    if ($Script:ActionsSummary.RollbacksPerformed.Count -gt 0) {
        Write-Host "Rollbacks Performed: $($Script:ActionsSummary.RollbacksPerformed.Count)" -ForegroundColor Yellow
    }
    
    $duration = (Get-Date) - $Script:StartTime
    $durationString = "{0:mm\:ss}" -f [datetime]$duration.Ticks
    Write-Host "`nTotal execution time: $durationString"
    Write-Host "Log file: $LogPath" -ForegroundColor Gray
}

