#Requires -Version 5.1
#Requires -RunAsAdministrator

<#
.SYNOPSIS
    Enhanced workstation deployment script with retry logic, idempotency, and parallel processing.

.DESCRIPTION
    Deploys software packages using WinGet, DISM, and offline installers with robust error handling,
    retry mechanisms, and parallel processing capabilities.

.PARAMETER Profile
    Deployment profile to use (Standard, Minimal, Full, Custom)

.PARAMETER SkipOfflineFallback
    Skip offline installer fallback if WinGet fails

.PARAMETER NoReboot
    Prevent automatic reboot after installation

.PARAMETER ContinueOnError
    Continue deployment even if individual packages fail

.PARAMETER MaxRetries
    Maximum number of retry attempts for network operations (default: 3)

.PARAMETER RetryDelay
    Initial delay between retries in seconds (default: 5)

.PARAMETER ParallelJobs
    Maximum number of parallel installation jobs (default: 3)

.PARAMETER ConfigPath
    Path to configuration file (default: .\config\packages.json)

.EXAMPLE
    .\Deploy-Workstation.ps1 -Profile Standard -ContinueOnError

.EXAMPLE
    .\Deploy-Workstation.ps1 -SkipOfflineFallback -NoReboot -MaxRetries 5
#>

[CmdletBinding()]
param(
    [ValidateSet('Standard', 'Minimal', 'Full', 'Custom')]
    [string]$Profile,
    
    [switch]$SkipOfflineFallback,
    [switch]$NoReboot,
    [switch]$ContinueOnError,
    
    [ValidateRange(1, 10)]
    [int]$MaxRetries = 3,
    
    [ValidateRange(1, 60)]
    [int]$RetryDelay = 5,
    
    [ValidateRange(1, 10)]
    [int]$ParallelJobs = 3,
    
    [string]$ConfigPath = ".\config\packages.json"
)

# Global variables for tracking
$script:TotalSteps = 0
$script:CurrentStep = 0
$script:FailedPackages = @()
$script:SuccessfulPackages = @()

#region Helper Functions

function Write-Log {
    param(
        [string]$Message,
        [ValidateSet('Info', 'Warning', 'Error', 'Success')]
        [string]$Level = 'Info'
    )
    
    $timestamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
    $color = switch ($Level) {
        'Info' { 'White' }
        'Warning' { 'Yellow' }
        'Error' { 'Red' }
        'Success' { 'Green' }
    }
    
    Write-Host "[$timestamp] [$Level] $Message" -ForegroundColor $color
    
    # Also log to file if needed
    $logFile = ".\logs\deployment_$(Get-Date -Format 'yyyyMMdd_HHmmss').log"
    if (!(Test-Path (Split-Path $logFile))) {
        New-Item -ItemType Directory -Path (Split-Path $logFile) -Force | Out-Null
    }
    "$timestamp [$Level] $Message" | Out-File -FilePath $logFile -Append
}

function Update-Progress {
    param(
        [string]$Activity,
        [string]$Status = "Processing...",
        [int]$PercentComplete
    )
    
    if ($PercentComplete -eq -1) {
        $PercentComplete = [math]::Round(($script:CurrentStep / $script:TotalSteps) * 100)
    }
    
    Write-Progress -Activity $Activity -Status $Status -PercentComplete $PercentComplete
}

function Invoke-WithRetry {
    param(
        [scriptblock]$ScriptBlock,
        [string]$Operation,
        [int]$MaxAttempts = $MaxRetries,
        [int]$DelaySeconds = $RetryDelay,
        [switch]$ExponentialBackoff
    )
    
    $attempt = 1
    $delay = $DelaySeconds
    
    do {
        try {
            Write-Log "Attempting $Operation (attempt $attempt/$MaxAttempts)"
            $result = & $ScriptBlock
            Write-Log "$Operation succeeded on attempt $attempt" -Level Success
            return $result
        }
        catch {
            Write-Log "$Operation failed on attempt $attempt`: $($_.Exception.Message)" -Level Warning
            
            if ($attempt -eq $MaxAttempts) {
                Write-Log "$Operation failed after $MaxAttempts attempts" -Level Error
                throw $_
            }
            
            Write-Log "Waiting $delay seconds before retry..."
            Start-Sleep -Seconds $delay
            
            if ($ExponentialBackoff) {
                $delay *= 2
            }
            
            $attempt++
        }
    } while ($attempt -le $MaxAttempts)
}

function Test-PackageInstalled {
    param(
        [string]$PackageName,
        [string]$WinGetId
    )
    
    # Check via Get-Package first (faster)
    try {
        $package = Get-Package -Name "*$PackageName*" -ErrorAction SilentlyContinue
        if ($package) {
            return $true
        }
    }
    catch {
        # Fallback to other methods
    }
    
    # Check via WinGet if ID provided
    if ($WinGetId) {
        try {
            $wingetResult = winget list --id $WinGetId --exact 2>$null
            if ($LASTEXITCODE -eq 0 -and $wingetResult -match $WinGetId) {
                return $true
            }
        }
        catch {
            # Continue to next check
        }
    }
    
    # Check registry for common installation paths
    $registryPaths = @(
        "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*",
        "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*",
        "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*"
    )
    
    foreach ($path in $registryPaths) {
        try {
            $installed = Get-ItemProperty $path -ErrorAction SilentlyContinue | 
                        Where-Object { $_.DisplayName -like "*$PackageName*" }
            if ($installed) {
                return $true
            }
        }
        catch {
            continue
        }
    }
    
    return $false
}

function Install-WinGetPackage {
    param(
        [string]$PackageId,
        [string]$PackageName,
        [hashtable]$InstallArgs = @{}
    )
    
    if (Test-PackageInstalled -PackageName $PackageName -WinGetId $PackageId) {
        Write-Log "$PackageName is already installed, skipping" -Level Success
        return $true
    }
    
    try {
        $operation = "Installing $PackageName via WinGet"
        
        Invoke-WithRetry -Operation $operation -ScriptBlock {
            $args = @('install', '--id', $PackageId, '--exact', '--silent', '--accept-package-agreements', '--accept-source-agreements')
            
            if ($InstallArgs.Count -gt 0) {
                $args += '--override'
                $args += ($InstallArgs.Values -join ' ')
            }
            
            $result = & winget @args 2>&1
            
            if ($LASTEXITCODE -ne 0) {
                throw "WinGet installation failed with exit code $LASTEXITCODE`: $result"
            }
            
            return $result
        } -ExponentialBackoff
        
        # Verify installation
        if (Test-PackageInstalled -PackageName $PackageName -WinGetId $PackageId) {
            Write-Log "$PackageName installed successfully" -Level Success
            $script:SuccessfulPackages += $PackageName
            return $true
        }
        else {
            throw "Package installation verification failed"
        }
    }
    catch {
        Write-Log "Failed to install $PackageName via WinGet: $($_.Exception.Message)" -Level Error
        $script:FailedPackages += @{Name = $PackageName; Method = 'WinGet'; Error = $_.Exception.Message}
        return $false
    }
}

function Install-OfflinePackage {
    param(
        [string]$PackageName,
        [string]$InstallerPath,
        [string[]]$InstallArgs = @('/S', '/VERYSILENT')
    )
    
    if (Test-PackageInstalled -PackageName $PackageName) {
        Write-Log "$PackageName is already installed, skipping offline installation" -Level Success
        return $true
    }
    
    if (!(Test-Path $InstallerPath)) {
        Write-Log "Offline installer not found: $InstallerPath" -Level Error
        return $false
    }
    
    try {
        $operation = "Installing $PackageName via offline installer"
        
        Invoke-WithRetry -Operation $operation -ScriptBlock {
            $process = Start-Process -FilePath $InstallerPath -ArgumentList $InstallArgs -Wait -PassThru -NoNewWindow
            
            if ($process.ExitCode -ne 0) {
                throw "Offline installer failed with exit code $($process.ExitCode)"
            }
            
            return $process.ExitCode
        }
        
        # Verify installation
        Start-Sleep -Seconds 3  # Allow time for installation to register
        if (Test-PackageInstalled -PackageName $PackageName) {
            Write-Log "$PackageName installed successfully via offline installer" -Level Success
            $script:SuccessfulPackages += $PackageName
            return $true
        }
        else {
            throw "Offline package installation verification failed"
        }
    }
    catch {
        Write-Log "Failed to install $PackageName via offline installer: $($_.Exception.Message)" -Level Error
        $script:FailedPackages += @{Name = $PackageName; Method = 'Offline'; Error = $_.Exception.Message}
        return $false
    }
}

function Install-WindowsfeatureWithRetry {
    param(
        [string]$FeatureName
    )
    
    try {
        $feature = Get-WindowsOptionalFeature -Online -FeatureName $FeatureName -ErrorAction SilentlyContinue
        if ($feature.State -eq 'Enabled') {
            Write-Log "Windows feature $FeatureName is already enabled" -Level Success
            return $true
        }
        
        $operation = "Enabling Windows feature $FeatureName"
        
        Invoke-WithRetry -Operation $operation -ScriptBlock {
            $result = Enable-WindowsOptionalFeature -Online -FeatureName $FeatureName -All -NoRestart
            
            if ($result.RestartNeeded) {
                Write-Log "Restart required after enabling $FeatureName" -Level Warning
            }
            
            return $result
        }
        
        Write-Log "Windows feature $FeatureName enabled successfully" -Level Success
        return $true
    }
    catch {
        Write-Log "Failed to enable Windows feature $FeatureName`: $($_.Exception.Message)" -Level Error
        return $false
    }
}

function Show-InteractiveMenu {
    Write-Host "`n=== Workstation Deployment Menu ===" -ForegroundColor Cyan
    Write-Host "1. Cleanup Only" -ForegroundColor White
    Write-Host "2. Install Only" -ForegroundColor White
    Write-Host "3. Full Deploy (Cleanup + Install)" -ForegroundColor White
    Write-Host "4. Custom Profile Selection" -ForegroundColor White
    Write-Host "5. Exit" -ForegroundColor White
    
    do {
        $choice = Read-Host "`nPlease select an option (1-5)"
    } while ($choice -notmatch '^[1-5]$')
    
    switch ($choice) {
        '1' { return 'CleanupOnly' }
        '2' { return 'InstallOnly' }
        '3' { return 'FullDeploy' }
        '4' { 
            $profiles = @('Standard', 'Minimal', 'Full', 'Custom')
            $selectedProfile = $profiles | Out-GridView -Title "Select Deployment Profile" -OutputMode Single
            return $selectedProfile
        }
        '5' { 
            Write-Log "Deployment cancelled by user"
            exit 0
        }
    }
}

function Get-PackageConfiguration {
    param([string]$ConfigPath)
    
    if (!(Test-Path $ConfigPath)) {
        Write-Log "Configuration file not found: $ConfigPath" -Level Error
        
        # Return default configuration
        return @{
            Standard = @{
                WinGetPackages = @(
                    @{Id = 'Google.Chrome'; Name = 'Google Chrome'; Args = @{}},
                    @{Id = 'Mozilla.Firefox'; Name = 'Mozilla Firefox'; Args = @{}},
                    @{Id = 'Adobe.Acrobat.Reader.64-bit'; Name = 'Adobe Reader'; Args = @{}},
                    @{Id = 'VideoLAN.VLC'; Name = 'VLC Media Player'; Args = @{}}
                )
                OfflinePackages = @()
                WindowsFeatures = @('NetFx3')
            }
        }
    }
    
    try {
        $config = Get-Content $ConfigPath -Raw | ConvertFrom-Json -AsHashtable
        return $config
    }
    catch {
        Write-Log "Failed to parse configuration file: $($_.Exception.Message)" -Level Error
        throw
    }
}

function Install-PackagesInParallel {
    param(
        [array]$Packages,
        [string]$InstallationType
    )
    
    if ($Packages.Count -eq 0) {
        return
    }
    
    Write-Log "Installing $($Packages.Count) packages in parallel ($InstallationType)"
    
    # Use PowerShell 7+ ForEach-Object -Parallel if available, otherwise use jobs
    if ($PSVersionTable.PSVersion.Major -ge 7) {
        $Packages | ForEach-Object -Parallel {
            $package = $_
            $MaxRetries = $using:MaxRetries
            $RetryDelay = $using:RetryDelay
            $SkipOfflineFallback = $using:SkipOfflineFallback
            
            # Import functions in parallel scope
            . $using:MyInvocation.MyCommand.Path
            
            if ($using:InstallationType -eq 'WinGet') {
                $success = Install-WinGetPackage -PackageId $package.Id -PackageName $package.Name -InstallArgs $package.Args
                
                if (!$success -and !$SkipOfflineFallback -and $package.OfflineInstaller) {
                    Install-OfflinePackage -PackageName $package.Name -InstallerPath $package.OfflineInstaller
                }
            }
            elseif ($using:InstallationType -eq 'Offline') {
                Install-OfflinePackage -PackageName $package.Name -InstallerPath $package.InstallerPath -InstallArgs $package.Args
            }
        } -ThrottleLimit $ParallelJobs
    }
    else {
        # Fallback to background jobs for PowerShell 5.1
        $jobs = @()
        
        foreach ($package in $Packages) {
            while ((Get-Job -State Running).Count -ge $ParallelJobs) {
                Start-Sleep -Milliseconds 100
            }
            
            $job = Start-Job -ScriptBlock {
                param($pkg, $type, $maxRetries, $retryDelay, $skipOffline)
                
                # Job implementation would go here
                # Note: This is simplified - in practice you'd need to import the module/functions
                
            } -ArgumentList $package, $InstallationType, $MaxRetries, $RetryDelay, $SkipOfflineFallback
            
            $jobs += $job
        }
        
        # Wait for all jobs to complete
        $jobs | Wait-Job | Receive-Job
        $jobs | Remove-Job
    }
}

#endregion

#region Main Script Logic

function Main {
    Write-Log "Starting Enhanced Workstation Deployment" -Level Success
    Write-Log "PowerShell Version: $($PSVersionTable.PSVersion)"
    
    # Show interactive menu if no parameters provided
    if (!$Profile -and !$PSBoundParameters.ContainsKey('SkipOfflineFallback')) {
        $menuChoice = Show-InteractiveMenu
        
        if ($menuChoice -in @('Standard', 'Minimal', 'Full', 'Custom')) {
            $Profile = $menuChoice
        }
        else {
            $action = $menuChoice
        }
    }
    
    # Load configuration
    try {
        $config = Get-PackageConfiguration -ConfigPath $ConfigPath
    }
    catch {
        if (!$ContinueOnError) {
            Write-Log "Fatal error: Cannot continue without configuration" -Level Error
            exit 1
        }
        Write-Log "Using minimal default configuration" -Level Warning
        $config = @{Standard = @{WinGetPackages = @(); OfflinePackages = @(); WindowsFeatures = @()}}
    }
    
    # Set default profile if not specified
    if (!$Profile) {
        $Profile = 'Standard'
    }
    
    # Get profile configuration
    $profileConfig = $config[$Profile]
    if (!$profileConfig) {
        Write-Log "Profile '$Profile' not found in configuration" -Level Error
        if (!$ContinueOnError) { exit 1 }
        return
    }
    
    # Calculate total steps for progress tracking
    $script:TotalSteps = 0
    $script:TotalSteps += $profileConfig.WinGetPackages.Count
    $script:TotalSteps += $profileConfig.OfflinePackages.Count
    $script:TotalSteps += $profileConfig.WindowsFeatures.Count
    $script:TotalSteps += 2  # Cleanup and finalization steps
    
    Write-Log "Deploying profile: $Profile ($script:TotalSteps total steps)"
    
    # Step 1: System Cleanup (if requested)
    if ($action -eq 'CleanupOnly' -or $action -eq 'FullDeploy' -or !$action) {
        $script:CurrentStep++
        Update-Progress -Activity "System Cleanup" -Status "Cleaning temporary files and updating system..."
        
        try {
            # Add your cleanup logic here
            Write-Log "Performing system cleanup..." -Level Info
            # Example: Clear temp files, update Windows, etc.
            Start-Sleep -Seconds 2  # Placeholder
        }
        catch {
            Write-Log "Cleanup step failed: $($_.Exception.Message)" -Level Warning
            if (!$ContinueOnError) { throw }
        }
    }
    
    # Step 2: Install WinGet Packages
    if ($action -eq 'InstallOnly' -or $action -eq 'FullDeploy' -or !$action) {
        if ($profileConfig.WinGetPackages.Count -gt 0) {
            $script:CurrentStep++
            Update-Progress -Activity "Installing WinGet Packages" -Status "Installing $($profileConfig.WinGetPackages.Count) packages..."
            
            Install-PackagesInParallel -Packages $profileConfig.WinGetPackages -InstallationType 'WinGet'
        }
    }
    
    # Step 3: Install Offline Packages
    if ($profileConfig.OfflinePackages.Count -gt 0) {
        $script:CurrentStep++
        Update-Progress -Activity "Installing Offline Packages" -Status "Installing offline installers..."
        
        Install-PackagesInParallel -Packages $profileConfig.OfflinePackages -InstallationType 'Offline'
    }
    
    # Step 4: Enable Windows Features
    if ($profileConfig.WindowsFeatures.Count -gt 0) {
        $script:CurrentStep++
        Update-Progress -Activity "Enabling Windows Features" -Status "Configuring Windows features..."
        
        foreach ($feature in $profileConfig.WindowsFeatures) {
            Install-WindowsFeatureWithRetry -FeatureName $feature
        }
    }
    
    # Step 5: Finalization
    $script:CurrentStep++
    Update-Progress -Activity "Finalizing Deployment" -Status "Completing deployment..."
    
    Write-Progress -Activity "Deployment Complete" -Completed
    
    # Report Results
    Write-Log "`n=== Deployment Summary ===" -Level Success
    Write-Log "Successfully installed: $($script:SuccessfulPackages.Count) packages" -Level Success
    Write-Log "Failed installations: $($script:FailedPackages.Count) packages" -Level $(if ($script:FailedPackages.Count -gt 0) { 'Warning' } else { 'Success' })
    
    if ($script:SuccessfulPackages.Count -gt 0) {
        Write-Log "Successful packages: $($script:SuccessfulPackages -join ', ')" -Level Success
    }
    
    if ($script:FailedPackages.Count -gt 0) {
        Write-Log "Failed packages:" -Level Warning
        foreach ($failed in $script:FailedPackages) {
            Write-Log "  - $($failed.Name) ($($failed.Method)): $($failed.Error)" -Level Warning
        }
    }
    
    # Handle reboot if needed
    if (!$NoReboot) {
        $rebootChoice = Read-Host "`nReboot system now? (y/N)"
        if ($rebootChoice -match '^[Yy]') {
            Write-Log "Initiating system reboot..." -Level Info
            Restart-Computer -Force
        }
    }
    
    Write-Log "Deployment completed successfully!" -Level Success
}

# Execute main function
try {
    Main
}
catch {
    Write-Log "Fatal error during deployment: $($_.Exception.Message)" -Level Error
    Write-Log "Stack trace: $($_.ScriptStackTrace)" -Level Error
    exit 1
}

#endregion
