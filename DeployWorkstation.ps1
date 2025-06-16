# DeployWorkstation.ps1 – Optimized Win10/11 Setup & Clean-up
# Version: 2.0

#Requires -Version 5.1
#Requires -RunAsAdministrator

[CmdletBinding()]
param(
    [string]$LogPath,
    [switch]$SkipAppInstall,
    [switch]$SkipBloatwareRemoval
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
    $LogPath = Join-Path $PSScriptRoot "DeployWorkstation.log"
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

Write-Log "===== DeployWorkstation.ps1 Started ====="
Write-Log "PowerShell Version: $($PSVersionTable.PSVersion)"
Write-Log "OS Version: $((Get-CimInstance Win32_OperatingSystem).Caption)"

# Set execution policy for session
Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass -Force

# ================================
# Winget Management
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

# ================================
# Bloatware Removal Functions
# ================================

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

function Remove-AppxPackages {
    Write-Log "Removing UWP/Appx packages..."
    
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
        '*QuickAssist*'
    )
    
    foreach ($packagePattern in $packagesToRemove) {
        Write-Log "Processing Appx package: $packagePattern"
        
        try {
            # Remove for all users
            $packages = Get-AppxPackage -AllUsers -Name $packagePattern -ErrorAction SilentlyContinue
            foreach ($package in $packages) {
                Write-Log "Removing package: $($package.Name)"
                Remove-AppxPackage -Package $package.PackageFullName -AllUsers -ErrorAction SilentlyContinue
            }
            
            # Remove provisioned packages
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

function Remove-WindowsCapabilities {
    Write-Log "Removing Windows optional features..."
    
    $capabilitiesToRemove = @(
        'App.Support.QuickAssist~~~~0.0.1.0',
        'App.Xbox.TCUI~~~~0.0.1.0',
        'App.XboxGameOverlay~~~~0.0.1.0',
        'App.XboxSpeechToTextOverlay~~~~0.0.1.0',
        'OpenSSH.Client~~~~0.0.1.0'
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

# ================================
# Application Installation
# ================================

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
# System Configuration
# ================================

function Set-SystemConfiguration {
    Write-Log "Configuring system settings..."
    
    try {
        # Disable Windows Telemetry
        Write-Log "Disabling Windows telemetry..."
        $telemetryPath = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\DataCollection'
        
        if (-not (Test-Path $telemetryPath)) {
            New-Item -Path $telemetryPath -Force | Out-Null
        }
        
        Set-ItemProperty -Path $telemetryPath -Name 'AllowTelemetry' -Value 0 -Type DWord -Force
        
        # Disable Windows Error Reporting
        Write-Log "Disabling Windows Error Reporting..."
        $werPath = 'HKLM:\SOFTWARE\Microsoft\Windows\Windows Error Reporting'
        Set-ItemProperty -Path $werPath -Name 'Disabled' -Value 1 -Type DWord -Force -ErrorAction SilentlyContinue
        
        # Disable Customer Experience Improvement Program
        Write-Log "Disabling Customer Experience Improvement Program..."
        $ceipPath = 'HKLM:\SOFTWARE\Microsoft\SQMClient\Windows'
        if (Test-Path $ceipPath) {
            Set-ItemProperty -Path $ceipPath -Name 'CEIPEnable' -Value 0 -Type DWord -Force
        }
        
        Write-Log "System configuration completed"
    }
    catch {
        Write-Log "Error configuring system: $($_.Exception.Message)" -Level 'ERROR'
    }
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
    
    # Execute bloatware removal
    if (-not $SkipBloatwareRemoval) {
        Write-Log "=== Starting Bloatware Removal ==="
        
        $bloatwarePatterns = @(
            'CoPilot', 'Outlook', 'Quick Assist', 'Remote Desktop',
            'Mixed Reality Portal', 'Clipchamp', 'Xbox', 'Family',
            'Skype', 'LinkedIn', 'OneDrive', 'Teams'
        )
        
        Remove-WingetApps -AppPatterns $bloatwarePatterns
        Remove-AppxPackages
        Remove-WindowsCapabilities
        Remove-McAfeeProducts
        
        Write-Log "=== Bloatware Removal Completed ==="
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
    
    # Configure system settings
    Set-SystemConfiguration
    
    Write-Log "===== DeployWorkstation.ps1 Completed Successfully ====="
    Write-Host "`n*** Setup complete! Log saved to: $LogPath ***" -ForegroundColor Green
    Write-Host "Press Enter to exit..." -ForegroundColor Yellow
    Read-Host | Out-Null
    
}
catch {
    Write-Log "Critical error: $($_.Exception.Message)" -Level 'ERROR'
    Write-Host "`n*** Setup failed! Check log at: $LogPath ***" -ForegroundColor Red
    exit 1
}
finally {
    # Cleanup
    $ProgressPreference = 'Continue'
}