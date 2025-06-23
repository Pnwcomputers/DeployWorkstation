# DeployWorkstation-AllUsers.ps1 – Optimized Win10/11 Setup & Clean-up for ALL Users
# Version: 2.1 - Enhanced for All Current and Future Users

#Requires -Version 5.1
#Requires -RunAsAdministrator

[CmdletBinding()]
param(
    [string]$LogPath,
    [switch]$SkipAppInstall,
    [switch]$SkipBloatwareRemoval,
    [switch]$SkipDefaultUserConfig
)

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
    
    Start-Process -FilePath 'powershell.exe' -ArgumentList $params -Verb RunAs
    exit
}

# Initialize logging
function Write-Log {
    param([string]$Message, [string]$Level = 'INFO')
    $timestamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
    $logEntry = "[$timestamp] [$Level] $Message"
    Write-Host $logEntry
    Add-Content -Path $LogPath -Value $logEntry -Encoding UTF8
}

# Create log directory if needed
$logDir = Split-Path $LogPath -Parent
if (-not (Test-Path $logDir)) {
    New-Item -Path $logDir -ItemType Directory -Force | Out-Null
}

Write-Log "===== DeployWorkstation-AllUsers.ps1 Started ====="
Write-Log "PowerShell Version: $($PSVersionTable.PSVersion)"
Write-Log "OS Version: $((Get-CimInstance Win32_OperatingSystem).Caption)"

# Set execution policy for session
Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass -Force

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
    
    foreach ($profile in $UserProfiles) {
        $ntUserPath = Join-Path $profile.ProfilePath "NTUSER.DAT"
        
        if (Test-Path $ntUserPath) {
            try {
                # Check if already mounted
                if (-not (Test-Path "HKU:\$($profile.SID)")) {
                    reg load "HKU\$($profile.SID)" $ntUserPath 2>$null
                    if ($LASTEXITCODE -eq 0) {
                        Write-Log "Mounted registry hive for: $($profile.Username)"
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
}

function Dismount-UserRegistryHives {
    param([array]$UserProfiles)
    
    Write-Log "Dismounting user registry hives..."
    
    foreach ($profile in $UserProfiles) {
        try {
            if (Test-Path "HKU:\$($profile.SID)") {
                reg unload "HKU\$($profile.SID)" 2>$null
                if ($LASTEXITCODE -eq 0) {
                    Write-Log "Dismounted registry hive for: $($profile.Username)"
                }
            }
        }
        catch {
            Write-Log "Failed to dismount registry for $($profile.Username): $($_.Exception.Message)" -Level 'WARN'
        }
    }
}

# ================================
# Enhanced Bloatware Removal Functions
# ================================

function Remove-AppxPackagesAllUsers {
    Write-Log "Removing UWP/Appx packages for all users..."
    
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
        Write-Log "Processing Appx package: $packagePattern"
        
        try {
            # Remove for all users (current and future)
            $packages = Get-AppxPackage -AllUsers -Name $packagePattern -ErrorAction SilentlyContinue
            foreach ($package in $packages) {
                Write-Log "Removing package for all users: $($package.Name)"
                Remove-AppxPackage -Package $package.PackageFullName -AllUsers -ErrorAction SilentlyContinue
            }
            
            # Remove provisioned packages (affects new user accounts)
            $provisionedPackages = Get-AppxProvisionedPackage -Online -ErrorAction SilentlyContinue |
                                 Where-Object { $_.DisplayName -like $packagePattern }
            
            foreach ($package in $provisionedPackages) {
                Write-Log "Removing provisioned package: $($package.DisplayName)"
                Remove-AppxProvisionedPackage -Online -PackageName $package.PackageName -ErrorAction SilentlyContinue
            }
        }
        catch {
            Write-Log "Error removing $packagePattern`: $($_.Exception.Message)" -Level 'WARN'
        }
    }
}

function Set-DefaultUserProfile {
    Write-Log "Configuring default user profile for future accounts..."
    
    if ($SkipDefaultUserConfig) {
        Write-Log "Skipping default user configuration (SkipDefaultUserConfig flag set)"
        return
    }
    
    try {
        # Mount default user profile
        $defaultUserPath = "${env:SystemDrive}\Users\Default\NTUSER.DAT"
        if (Test-Path $defaultUserPath) {
            reg load "HKU\DefaultUser" $defaultUserPath 2>$null
            
            if ($LASTEXITCODE -eq 0) {
                Write-Log "Mounted default user registry hive"
                
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
                    
                    if (-not (Test-Path $fullPath)) {
                        New-Item -Path $fullPath -Force | Out-Null
                    }
                    
                    foreach ($valueName in $defaultUserSettings[$keyPath].Keys) {
                        $value = $defaultUserSettings[$keyPath][$valueName]
                        Set-ItemProperty -Path $fullPath -Name $valueName -Value $value -Type DWord -Force
                        Write-Log "Set default user setting: $keyPath\$valueName = $value"
                    }
                }
                
                # Unmount default user hive
                reg unload "HKU\DefaultUser" 2>$null
                Write-Log "Default user profile configured successfully"
            }
        }
    }
    catch {
        Write-Log "Error configuring default user profile: $($_.Exception.Message)" -Level 'ERROR'
    }
}

function Configure-AllUserProfiles {
    param([array]$UserProfiles)
    
    Write-Log "Configuring settings for all existing user profiles..."
    
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
                    
                    if (-not (Test-Path $fullPath)) {
                        New-Item -Path $fullPath -Force | Out-Null
                    }
                    
                    foreach ($valueName in $userSettings[$keyPath].Keys) {
                        $value = $userSettings[$keyPath][$valueName]
                        
                        if ($null -eq $value) {
                            # Remove the value
                            Remove-ItemProperty -Path $fullPath -Name $valueName -ErrorAction SilentlyContinue
                            Write-Log "Removed $($profile.Username) setting: $keyPath\$valueName"
                        } else {
                            Set-ItemProperty -Path $fullPath -Name $valueName -Value $value -Type DWord -Force
                            Write-Log "Set $($profile.Username) setting: $keyPath\$valueName = $value"
                        }
                    }
                }
            }
        }
        catch {
            Write-Log "Error configuring profile $($profile.Username): $($_.Exception.Message)" -Level 'WARN'
        }
    }
}

# ================================
# Enhanced System Configuration
# ================================

function Set-SystemConfigurationAllUsers {
    Write-Log "Configuring system-wide settings for all users..."
    
    try {
        # Machine-wide policies (affects all users)
        $systemSettings = @{
            # Disable Windows Consumer Features for all users
            'HKLM:\SOFTWARE\Policies\Microsoft\Windows\CloudContent' = @{
                'DisableWindowsConsumerFeatures' = 1
                'DisableConsumerAccountStateContent' = 1
                'DisableTailoredExperiencesWithDiagnosticData' = 1
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
            
            # Disable Windows Tips
            'HKLM:\SOFTWARE\Policies\Microsoft\Windows\CloudContent' = @{
                'DisableSoftLanding' = 1
                'DisableWindowsSpotlightFeatures' = 1
            }
            
            # Disable OneDrive for all users
            'HKLM:\SOFTWARE\Policies\Microsoft\Windows\OneDrive' = @{
                'DisableFileSyncNGSC' = 1
                'DisableFileSync' = 1
            }
        }
        
        foreach ($keyPath in $systemSettings.Keys) {
            if (-not (Test-Path $keyPath)) {
                New-Item -Path $keyPath -Force | Out-Null
            }
            
            foreach ($valueName in $systemSettings[$keyPath].Keys) {
                $value = $systemSettings[$keyPath][$valueName]
                Set-ItemProperty -Path $keyPath -Name $valueName -Value $value -Type DWord -Force
                Write-Log "Set system setting: $keyPath\$valueName = $value"
            }
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
                    Write-Log "Disabling service: $serviceName"
                    Stop-Service -Name $serviceName -Force -ErrorAction SilentlyContinue
                    Set-Service -Name $serviceName -StartupType Disabled -ErrorAction SilentlyContinue
                }
            }
            catch {
                Write-Log "Could not disable service $serviceName`: $($_.Exception.Message)" -Level 'WARN'
            }
        }
        
        Write-Log "System-wide configuration completed"
    }
    catch {
        Write-Log "Error configuring system: $($_.Exception.Message)" -Level 'ERROR'
    }
}

# ================================
# Original Functions (Enhanced)
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

function Remove-WingetApps {
    param([string[]]$AppPatterns)
    
    Write-Log "Starting winget app removal..."
    
    foreach ($pattern in $AppPatterns) {
        Write-Log "Searching for apps matching: $pattern"
        
        try {
            # Get list of installed apps matching pattern
            $apps = winget list --name "$pattern" --accept-source-agreements 2>$null |
                    Where-Object { $_ -and $_ -notmatch "Name\s+Id\s+Version" -and $_.Trim() }
            
            if ($apps) {
                Write-Log "Found $($apps.Count) app(s) matching '$pattern'"
                
                # Try uninstalling by pattern first
                Write-Log "Attempting bulk uninstall for pattern: $pattern"
                $result = winget uninstall --name "$pattern" --silent --force --accept-source-agreements 2>&1
                
                if ($LASTEXITCODE -eq 0) {
                    Write-Log "Successfully removed apps matching: $pattern"
                } else {
                    Write-Log "Bulk uninstall failed for: $pattern" -Level 'WARN'
                }
            } else {
                Write-Log "No apps found matching: $pattern"
            }
        }
        catch {
            Write-Log "Error processing $pattern`: $($_.Exception.Message)" -Level 'ERROR'
        }
    }
}

function Remove-WindowsCapabilities {
    Write-Log "Removing Windows optional features..."
    
    $capabilitiesToRemove = @(
        'App.Support.QuickAssist~~~~0.0.1.0',
        'App.Xbox.TCUI~~~~0.0.1.0',
        'App.XboxGameOverlay~~~~0.0.1.0',
        'App.XboxSpeechToTextOverlay~~~~0.0.1.0',
        'OpenSSH.Client~~~~0.0.1.0',
        'Microsoft.Windows.PowerShell.ISE~~~~0.0.1.0'
    )
    
    foreach ($capability in $capabilitiesToRemove) {
        try {
            $state = Get-WindowsCapability -Online -Name $capability -ErrorAction SilentlyContinue
            
            if ($state -and $state.State -eq 'Installed') {
                Write-Log "Removing capability: $capability"
                Remove-WindowsCapability -Online -Name $capability -ErrorAction SilentlyContinue | Out-Null
            } else {
                Write-Log "Capability not installed: $capability"
            }
        }
        catch {
            Write-Log "Error processing capability $capability`: $($_.Exception.Message)" -Level 'WARN'
        }
    }
}

function Remove-McAfeeProducts {
    Write-Log "Searching for McAfee products..."
    
    $uninstallPaths = @(
        'HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*',
        'HKLM:\Software\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*'
    )
    
    $mcafeeFound = $false
    
    foreach ($path in $uninstallPaths) {
        Get-ItemProperty $path -ErrorAction SilentlyContinue |
        Where-Object { $_.DisplayName -like '*McAfee*' } |
        ForEach-Object {
            $mcafeeFound = $true
            $displayName = $_.DisplayName
            $uninstallString = $_.UninstallString
            
            Write-Log "Found McAfee product: $displayName"
            
            if ($uninstallString) {
                try {
                    Write-Log "Attempting to uninstall: $displayName"
                    
                    # Parse the uninstall string
                    if ($uninstallString -match '^"([^"]+)"\s*(.*)$') {
                        $executable = $Matches[1]
                        $arguments = $Matches[2]
                    } else {
                        $parts = $uninstallString.Split(' ', 2)
                        $executable = $parts[0]
                        $arguments = if ($parts.Length -gt 1) { $parts[1] } else { '' }
                    }
                    
                    # Add silent uninstall flags if not present
                    if ($arguments -notmatch '/S|/silent|/quiet') {
                        $arguments += ' /S /quiet'
                    }
                    
                    Start-Process -FilePath $executable -ArgumentList $arguments -Wait -WindowStyle Hidden -ErrorAction Stop
                    Write-Log "Successfully uninstalled: $displayName"
                }
                catch {
                    Write-Log "Failed to uninstall $displayName`: $($_.Exception.Message)" -Level 'ERROR'
                }
            }
        }
    }
    
    if (-not $mcafeeFound) {
        Write-Log "No McAfee products found"
    }
}

function Install-StandardApps {
    Write-Log "Installing standard applications..."
    
    $appsToInstall = @(
        @{ Id = 'Malwarebytes.Malwarebytes'; Name = 'Malwarebytes' },
        @{ Id = 'BleachBit.BleachBit'; Name = 'BleachBit' },
        @{ Id = 'Google.Chrome'; Name = 'Google Chrome' },
        @{ Id = 'Microsoft.DotNet.DesktopRuntime.7'; Name = '.NET 7 Desktop Runtime' },
        @{ Id = 'Oracle.JavaRuntimeEnvironment'; Name = 'Java Runtime Environment' },
        @{ Id = 'Adobe.Acrobat.Reader.64-bit'; Name = 'Adobe Reader' },
        @{ Id = 'Zoom.Zoom'; Name = 'Zoom' },
        @{ Id = '7zip.7zip'; Name = '7-Zip' },
        @{ Id = 'VideoLAN.VLC'; Name = 'VLC Media Player' }
    )
    
    $successCount = 0
    $totalCount = $appsToInstall.Count
    
    foreach ($app in $appsToInstall) {
        Write-Log "Installing: $($app.Name) ($($app.Id))"
        
        try {
            $installResult = winget install --id $app.Id --source winget --accept-package-agreements --accept-source-agreements --silent 2>&1
            
            if ($LASTEXITCODE -eq 0) {
                Write-Log "Successfully installed: $($app.Name)"
                $successCount++
            } else {
                Write-Log "Failed to install $($app.Name). Exit code: $LASTEXITCODE" -Level 'WARN'
            }
        }
        catch {
            Write-Log "Error installing $($app.Name): $($_.Exception.Message)" -Level 'ERROR'
        }
    }
    
    Write-Log "App installation complete: $successCount/$totalCount successful"
}

# ================================
# Main Execution
# ================================

try {
    # Verify prerequisites
    if (-not (Test-Winget)) {
        Write-Log "Winget is required but not available. Please install App Installer from Microsoft Store." -Level 'ERROR'
        exit 1
    }
    
    Initialize-WingetSources
    
    # Get all user profiles
    $userProfiles = Get-AllUserProfiles
    
    # Mount user registry hives for configuration
    Mount-UserRegistryHives -UserProfiles $userProfiles
    
    # Execute bloatware removal
    if (-not $SkipBloatwareRemoval) {
        Write-Log "=== Starting Enhanced Bloatware Removal for All Users ==="
        
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
        
        Write-Log "=== Enhanced Bloatware Removal Completed ==="
    } else {
        Write-Log "Skipping bloatware removal (SkipBloatwareRemoval flag set)"
    }
    
    # Execute application installation
    if (-not $SkipAppInstall) {
        Write-Log "=== Starting Application Installation ==="
        Install-StandardApps
        Write-Log "=== Application Installation Completed ==="
    } else {
        Write-Log "Skipping application installation (SkipAppInstall flag set)"
    }
    
    # Configure system settings for all users
    Set-SystemConfigurationAllUsers
    
    # Configure existing user profiles
    Configure-AllUserProfiles -UserProfiles $userProfiles
    
    # Configure default user profile for future accounts
    Set-DefaultUserProfile
    
    # Clean up mounted registry hives
    Dismount-UserRegistryHives -UserProfiles $userProfiles
    
    Write-Log "===== DeployWorkstation-AllUsers.ps1 Completed Successfully ====="
    Write-Host "`n*** Setup complete for ALL users (current and future)! Log saved to: $LogPath ***" -ForegroundColor Green
    Write-Host "Press Enter to exit..." -ForegroundColor Yellow
    Read-Host | Out-Null
    
}
catch {
    Write-Log "Critical error: $($_.Exception.Message)" -Level 'ERROR'
    Write-Host "`n*** Setup failed! Check log at: $LogPath ***" -ForegroundColor Red
    
    # Ensure registry hives are cleaned up even on error
    if ($userProfiles) {
        Dismount-UserRegistryHives -UserProfiles $userProfiles
    }
    
    exit 1
}
finally {
    # Cleanup
    $ProgressPreference = 'Continue'
}