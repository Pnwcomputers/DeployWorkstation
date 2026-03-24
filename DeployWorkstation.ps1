# DeployWorkstation.ps1 – Optimized Win10/11 Setup & Clean-up
# Version: 4.0 – PNWC Edition

#Requires -Version 5.1
#Requires -RunAsAdministrator

[CmdletBinding()]
param(
    [string]$LogPath,
    [switch]$SkipAppInstall,
    [switch]$SkipBloatwareRemoval,
    [switch]$SkipSystemConfig
)

# ================================
# Configuration & Setup
# ================================

$ErrorActionPreference = 'Continue'
$ProgressPreference    = 'SilentlyContinue'

# Resolve script root
if (-not $PSScriptRoot) {
    $PSScriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
}

if (-not $LogPath) {
    $LogPath = Join-Path $PSScriptRoot "DeployWorkstation.log"
}

# --------------------------------
# Restart in Windows PowerShell 5.1 if running under PS Core
# (required for Appx/provisioned package cmdlets)
# --------------------------------
if ($PSVersionTable.PSEdition -eq 'Core') {
    Write-Warning 'PowerShell Core detected. Restarting in Windows PowerShell 5.1...'
    $params = @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', $PSCommandPath,
                '-LogPath', $LogPath)
    if ($SkipAppInstall)       { $params += '-SkipAppInstall' }
    if ($SkipBloatwareRemoval) { $params += '-SkipBloatwareRemoval' }
    if ($SkipSystemConfig)     { $params += '-SkipSystemConfig' }
    Start-Process -FilePath 'powershell.exe' -ArgumentList $params -Verb RunAs
    exit
}

# --------------------------------
# Logging
# --------------------------------
$logDir = Split-Path $LogPath -Parent
if ($logDir -and -not (Test-Path $logDir)) {
    New-Item -Path $logDir -ItemType Directory -Force | Out-Null
}

function Write-Log {
    param(
        [string]$Message,
        [ValidateSet('INFO','WARN','ERROR','SUCCESS')]
        [string]$Level = 'INFO'
    )
    $timestamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
    $logEntry  = "[$timestamp] [$Level] $Message"

    $color = switch ($Level) {
        'WARN'    { 'Yellow' }
        'ERROR'   { 'Red'    }
        'SUCCESS' { 'Green'  }
        default   { 'Gray'   }
    }
    Write-Host $logEntry -ForegroundColor $color
    Add-Content -Path $LogPath -Value $logEntry -Encoding UTF8
}

# Initialise counters used in the final summary
$script:Summary = @{
    AppsInstalled   = 0
    AppsFailed      = 0
    AppxRemoved     = 0
    CapabilitiesRemoved = 0
    McAfeeRemoved   = 0
}

Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass -Force

Write-Log "===== DeployWorkstation.ps1 v4.0 Started ====="
Write-Log "PowerShell  : $($PSVersionTable.PSVersion)"
Write-Log "OS          : $((Get-CimInstance Win32_OperatingSystem).Caption)"
Write-Log "Log file    : $LogPath"

# ================================
# Helper Functions
# ================================

function Set-RegistryValue {
    <#
    .SYNOPSIS
        Creates a registry key path if missing, then sets a DWORD value.
    #>
    param(
        [string]$Path,
        [string]$Name,
        [int]   $Value
    )
    try {
        if (-not (Test-Path $Path)) {
            New-Item -Path $Path -Force | Out-Null
        }
        Set-ItemProperty -Path $Path -Name $Name -Value $Value -Type DWord -Force -ErrorAction Stop
        Write-Log "Registry: $Path\$Name = $Value" -Level 'SUCCESS'
    }
    catch {
        Write-Log "Registry write failed – $Path\$Name : $($_.Exception.Message)" -Level 'WARN'
    }
}

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
        Write-Log "Winget not found on PATH." -Level 'ERROR'
        return $false
    }
}

function Initialize-WingetSources {
    Write-Log "Managing winget sources..."
    try {
        $sources = winget source list 2>$null
        if ($sources -match 'msstore') {
            Write-Log "Removing msstore source (performance)..."
            winget source remove --name msstore 2>$null | Out-Null
        }
        Write-Log "Refreshing winget source index..."
        winget source update --name winget 2>$null | Out-Null
    }
    catch {
        Write-Log "Could not manage winget sources: $($_.Exception.Message)" -Level 'WARN'
    }
}

# ================================
# Bloatware Removal
# ================================

function Remove-WingetApps {
    param([string[]]$AppPatterns)
    Write-Log "--- Winget bloatware removal ---"

    foreach ($pattern in $AppPatterns) {
        Write-Log "Checking for: $pattern"
        try {
            $found = winget list --name "$pattern" --accept-source-agreements 2>$null |
                     Where-Object { $_ -and $_ -notmatch 'Name\s+Id\s+Version' -and $_.Trim() }

            if (-not $found) {
                Write-Log "Not found: $pattern"
                continue
            }

            Write-Log "Removing: $pattern"
            winget uninstall --name "$pattern" --silent --force --accept-source-agreements 2>&1 | Out-Null

            if ($LASTEXITCODE -eq 0) {
                Write-Log "Removed: $pattern" -Level 'SUCCESS'
            } else {
                Write-Log "Removal returned exit code $LASTEXITCODE for: $pattern" -Level 'WARN'
            }
        }
        catch {
            Write-Log "Error removing $pattern`: $($_.Exception.Message)" -Level 'ERROR'
        }
    }
}

function Remove-AppxPackages {
    Write-Log "--- Appx / UWP package removal ---"

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
        '*Microsoft.Copilot*',
        '*Microsoft.Teams*'
    )

    foreach ($pattern in $packagesToRemove) {
        try {
            $pkgs = Get-AppxPackage -AllUsers -Name $pattern -ErrorAction SilentlyContinue
            foreach ($pkg in $pkgs) {
                Write-Log "Removing Appx: $($pkg.Name)"
                Remove-AppxPackage -Package $pkg.PackageFullName -AllUsers -ErrorAction SilentlyContinue
                $script:Summary.AppxRemoved++
            }

            $provPkgs = Get-AppxProvisionedPackage -Online -ErrorAction SilentlyContinue |
                        Where-Object { $_.DisplayName -like $pattern }
            foreach ($pkg in $provPkgs) {
                Write-Log "Removing provisioned: $($pkg.DisplayName)"
                Remove-AppxProvisionedPackage -Online -PackageName $pkg.PackageName -ErrorAction SilentlyContinue
                $script:Summary.AppxRemoved++
            }
        }
        catch {
            Write-Log "Error processing $pattern`: $($_.Exception.Message)" -Level 'WARN'
        }
    }
}

function Remove-WindowsCapabilities {
    Write-Log "--- Windows optional capability removal ---"

    $capabilitiesToRemove = @(
        'App.Support.QuickAssist~~~~0.0.1.0',
        'App.Xbox.TCUI~~~~0.0.1.0',
        'App.XboxGameOverlay~~~~0.0.1.0',
        'App.XboxSpeechToTextOverlay~~~~0.0.1.0',
        'OpenSSH.Client~~~~0.0.1.0'
    )

    foreach ($cap in $capabilitiesToRemove) {
        try {
            $state = Get-WindowsCapability -Online -Name $cap -ErrorAction SilentlyContinue
            if ($state -and $state.State -eq 'Installed') {
                Write-Log "Removing capability: $cap"
                Remove-WindowsCapability -Online -Name $cap -ErrorAction SilentlyContinue | Out-Null
                $script:Summary.CapabilitiesRemoved++
            } else {
                Write-Log "Not installed: $cap"
            }
        }
        catch {
            Write-Log "Error with capability $cap`: $($_.Exception.Message)" -Level 'WARN'
        }
    }
}

function Remove-McAfeeProducts {
    Write-Log "--- McAfee removal ---"

    $uninstallPaths = @(
        'HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*',
        'HKLM:\Software\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*'
    )

    # Collect all matching entries first so pipeline scoping doesn't hide the flag
    $mcafeeEntries = foreach ($path in $uninstallPaths) {
        Get-ItemProperty $path -ErrorAction SilentlyContinue |
            Where-Object { $_.DisplayName -like '*McAfee*' }
    }

    if (-not $mcafeeEntries) {
        Write-Log "No McAfee products found."
        return
    }

    foreach ($entry in $mcafeeEntries) {
        $displayName     = $entry.DisplayName
        $uninstallString = $entry.UninstallString

        Write-Log "Found: $displayName"

        if (-not $uninstallString) {
            Write-Log "No uninstall string for $displayName – skipping." -Level 'WARN'
            continue
        }

        try {
            if ($uninstallString -match '^"([^"]+)"\s*(.*)$') {
                $exe  = $Matches[1]
                $args = $Matches[2]
            } else {
                $parts = $uninstallString.Split(' ', 2)
                $exe   = $parts[0]
                $args  = if ($parts.Length -gt 1) { $parts[1] } else { '' }
            }

            if ($args -notmatch '/S|/silent|/quiet') { $args += ' /S /quiet' }

            Write-Log "Uninstalling: $displayName"
            Start-Process -FilePath $exe -ArgumentList $args -Wait -WindowStyle Hidden -ErrorAction Stop
            Write-Log "Removed: $displayName" -Level 'SUCCESS'
            $script:Summary.McAfeeRemoved++
        }
        catch {
            Write-Log "Failed to uninstall $displayName`: $($_.Exception.Message)" -Level 'ERROR'
        }
    }
}

# ================================
# Application Installation
# ================================

function Install-StandardApps {
    Write-Log "--- Application installation ---"

    # Winget exit code 0x8A15002B (-1978335189) = already installed; treat as success
    $alreadyInstalledCode = -1978335189

    $appsToInstall = @(
        # ---- Security & Maintenance ----
        @{ Id = 'Malwarebytes.Malwarebytes';          Name = 'Malwarebytes'                   },
        @{ Id = 'BleachBit.BleachBit';                Name = 'BleachBit'                      },

        # ---- Browsers & Productivity ----
        @{ Id = 'Google.Chrome';                      Name = 'Google Chrome'                  },
        @{ Id = 'Adobe.Acrobat.Reader.64-bit';        Name = 'Adobe Acrobat Reader (64-bit)'  },
        @{ Id = '7zip.7zip';                           Name = '7-Zip'                          },
        @{ Id = 'VideoLAN.VLC';                        Name = 'VLC Media Player'               },

        # ---- .NET Runtimes ----
        @{ Id = 'Microsoft.DotNet.Framework.4.8';     Name = '.NET Framework 4.8'             },
        @{ Id = 'Microsoft.DotNet.DesktopRuntime.6';  Name = '.NET 6 Desktop Runtime'         },
        @{ Id = 'Microsoft.DotNet.DesktopRuntime.7';  Name = '.NET 7 Desktop Runtime'         },
        @{ Id = 'Microsoft.DotNet.DesktopRuntime.8';  Name = '.NET 8 Desktop Runtime'         },

        # ---- Visual C++ Redistributables ----
        @{ Id = 'Microsoft.VCRedist.2015+.x64';       Name = 'VC++ 2015-2022 Redist (x64)'   },
        @{ Id = 'Microsoft.VCRedist.2015+.x86';       Name = 'VC++ 2015-2022 Redist (x86)'   }
    )

    $total = $appsToInstall.Count

    foreach ($app in $appsToInstall) {
        Write-Log "Installing: $($app.Name)  [$($app.Id)]"
        try {
            winget install --id $app.Id --source winget `
                --accept-package-agreements --accept-source-agreements `
                --silent 2>&1 | Out-Null

            if ($LASTEXITCODE -eq 0 -or $LASTEXITCODE -eq $alreadyInstalledCode) {
                $suffix = if ($LASTEXITCODE -eq $alreadyInstalledCode) { ' (already installed)' } else { '' }
                Write-Log "OK: $($app.Name)$suffix" -Level 'SUCCESS'
                $script:Summary.AppsInstalled++
            } else {
                Write-Log "Failed: $($app.Name) – exit code $LASTEXITCODE" -Level 'WARN'
                $script:Summary.AppsFailed++
            }
        }
        catch {
            Write-Log "Error installing $($app.Name): $($_.Exception.Message)" -Level 'ERROR'
            $script:Summary.AppsFailed++
        }
    }

    Write-Log "App install: $($script:Summary.AppsInstalled)/$total succeeded, $($script:Summary.AppsFailed) failed."
}

# ================================
# System Configuration
# ================================

function Set-SystemConfiguration {
    Write-Log "--- System configuration ---"

    # Telemetry
    Set-RegistryValue -Path 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\DataCollection' `
                      -Name 'AllowTelemetry' -Value 0

    # Windows Error Reporting
    Set-RegistryValue -Path 'HKLM:\SOFTWARE\Microsoft\Windows\Windows Error Reporting' `
                      -Name 'Disabled' -Value 1

    # Customer Experience Improvement Program
    Set-RegistryValue -Path 'HKLM:\SOFTWARE\Microsoft\SQMClient\Windows' `
                      -Name 'CEIPEnable' -Value 0

    # Disable Advertising ID
    Set-RegistryValue -Path 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\AdvertisingInfo' `
                      -Name 'DisabledByGroupPolicy' -Value 1

    Write-Log "System configuration complete." -Level 'SUCCESS'
}

# ================================
# Summary Report
# ================================

function Write-Summary {
    $border = '=' * 50
    Write-Log $border
    Write-Log "DEPLOYMENT SUMMARY"
    Write-Log $border
    Write-Log "Apps installed / skipped  : $($script:Summary.AppsInstalled)"
    Write-Log "Apps failed               : $($script:Summary.AppsFailed)"
    Write-Log "Appx packages removed     : $($script:Summary.AppxRemoved)"
    Write-Log "Capabilities removed      : $($script:Summary.CapabilitiesRemoved)"
    Write-Log "McAfee products removed   : $($script:Summary.McAfeeRemoved)"
    Write-Log $border
}

# ================================
# Main Execution
# ================================

try {
    if (-not (Test-Winget)) {
        Write-Log "Winget is required. Install 'App Installer' from the Microsoft Store." -Level 'ERROR'
        exit 1
    }

    Initialize-WingetSources

    if (-not $SkipBloatwareRemoval) {
        Write-Log "=== BLOATWARE REMOVAL ==="
        $bloatwarePatterns = @(
            'Copilot', 'Outlook', 'Quick Assist', 'Remote Desktop',
            'Mixed Reality Portal', 'Clipchamp', 'Xbox', 'Family',
            'Skype', 'LinkedIn', 'OneDrive', 'Teams'
        )
        Remove-WingetApps       -AppPatterns $bloatwarePatterns
        Remove-AppxPackages
        Remove-WindowsCapabilities
        Remove-McAfeeProducts
        Write-Log "=== BLOATWARE REMOVAL COMPLETE ===" -Level 'SUCCESS'
    } else {
        Write-Log "Bloatware removal skipped (-SkipBloatwareRemoval)."
    }

    if (-not $SkipAppInstall) {
        Write-Log "=== APP INSTALLATION ==="
        Install-StandardApps
        Write-Log "=== APP INSTALLATION COMPLETE ===" -Level 'SUCCESS'
    } else {
        Write-Log "App installation skipped (-SkipAppInstall)."
    }

    if (-not $SkipSystemConfig) {
        Write-Log "=== SYSTEM CONFIGURATION ==="
        Set-SystemConfiguration
        Write-Log "=== SYSTEM CONFIGURATION COMPLETE ===" -Level 'SUCCESS'
    } else {
        Write-Log "System configuration skipped (-SkipSystemConfig)."
    }

    Write-Summary

    Write-Log "===== DeployWorkstation.ps1 Completed Successfully =====" -Level 'SUCCESS'
    Write-Host "`n*** Setup complete!  Log: $LogPath ***" -ForegroundColor Green
    Write-Host "Press Enter to exit..." -ForegroundColor Yellow
    Read-Host | Out-Null
}
catch {
    Write-Log "CRITICAL ERROR: $($_.Exception.Message)" -Level 'ERROR'
    Write-Host "`n*** Setup failed – see log: $LogPath ***" -ForegroundColor Red
    exit 1
}
finally {
    $ProgressPreference = 'Continue'
}
