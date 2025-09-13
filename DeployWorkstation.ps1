# DeployWorkstation-AllUsers.ps1 – Optimized Win10/11 Setup & Clean-up for ALL Users
# Version: 2.2 - Bug Fixes and Improvements

#Requires -Version 5.1
#Requires -RunAsAdministrator

[CmdletBinding()]
param(
    [string]$LogPath,
    [switch]$SkipAppInstall,
    [switch]$SkipBloatwareRemoval,
    [switch]$SkipDefaultUserConfig,
    [switch]$ExportWingetApps,
    [switch]$ImportWingetApps,
    [switch]$SkipJavaRuntimes
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
    if ($ExportWingetApps) { $params += '-ExportWingetApps' }
    if ($ImportWingetApps) { $params += '-ImportWingetApps' }
    if ($SkipJavaRuntimes) { $params += '-SkipJavaRuntimes' }
    
    Start-Process -FilePath 'powershell.exe' -ArgumentList $params -Verb RunAs
    exit
}

# Initialize logging
function Write-Log {
    param(
        [Parameter(Mandatory=$true)]
        [string]$Message, 
        [ValidateSet('INFO', 'WARN', 'ERROR', 'DEBUG')]
        [string]$Level = 'INFO'
    )
    $timestamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
    $logEntry = "[$timestamp] [$Level] $Message"
    
    # Use appropriate Write-* cmdlet based on level
    switch ($Level) {
        'ERROR' { Write-Error $logEntry }
        'WARN'  { Write-Warning $logEntry }
        'DEBUG' { Write-Verbose $logEntry }
        default { Write-Host $logEntry }
    }
    
    try {
        Add-Content -Path $LogPath -Value $logEntry -Encoding UTF8 -ErrorAction SilentlyContinue
    }
    catch {
        Write-Warning "Failed to write to log file: $($_.Exception.Message)"
    }
}

# Create log directory if needed
$logDir = Split-Path $LogPath -Parent
if (-not (Test-Path $logDir)) {
    try {
        New-Item -Path $logDir -ItemType Directory -Force | Out-Null
    }
    catch {
        Write-Error "Failed to create log directory: $($_.Exception.Message)"
        exit 1
    }
}

Write-Log "===== DeployWorkstation-AllUsers.ps1 Started ====="
Write-Log "PowerShell Version: $($PSVersionTable.PSVersion)"

# Validate OS version
try {
    $osInfo = Get-CimInstance Win32_OperatingSystem -ErrorAction Stop
    Write-Log "OS Version: $($osInfo.Caption)"
    $osVersion = [Version]$osInfo.Version
    
    if ($osVersion -lt [Version]"10.0") {
        Write-Log "Unsupported OS version: $($osVersion). Script requires Windows 10 or later." -Level 'ERROR'
        exit 1
    }
    
    Write-Log "System Architecture: $($osInfo.OSArchitecture)"
}
catch {
    Write-Log "Failed to get OS information: $($_.Exception.Message)" -Level 'ERROR'
    exit 1
}

# Set execution policy for session
try {
    Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass -Force
}
catch {
    Write-Log "Failed to set execution policy: $($_.Exception.Message)" -Level 'WARN'
}

# ================================
# Registry Drive Management
# ================================

function Initialize-RegistryDrives {
    Write-Log "Initializing registry drives..."
    
    # Create HKU: drive if it doesn't exist
    if (-not (Get-PSDrive -Name HKU -ErrorAction SilentlyContinue)) {
        try {
            New-PSDrive -Name HKU -PSProvider Registry -Root HKEY_USERS -Scope Global | Out-Null
            Write-Log "Created HKU: PowerShell drive"
            
            # Verify the drive was created
            if (Get-PSDrive -Name HKU -ErrorAction SilentlyContinue) {
                Write-Log "HKU: drive verified successfully"
                return $true
            } else {
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
        return $true
    }
}

function Remove-RegistryDrives {
    Write-Log "Cleaning up registry drives..."
    
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
    
    try {
        # Get all user profiles from registry
        $profileListPath = 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\ProfileList'
        
        if (-not (Test-Path $profileListPath)) {
            Write-Log "Profile list registry path not found" -Level 'ERROR'
            return $profiles
        }
        
        Get-ChildItem $profileListPath -ErrorAction SilentlyContinue | ForEach-Object {
            try {
                $profilePath = (Get-ItemProperty $_.PSPath -Name ProfileImagePath -ErrorAction SilentlyContinue).ProfileImagePath
                $sid = $_.PSChildName
                
                if ($profilePath -and (Test-Path $profilePath) -and 
                    $profilePath -notlike '*\systemprofile*' -and 
                    $profilePath -notlike '*\LocalService*' -and 
                    $profilePath -notlike '*\NetworkService*' -and
                    $profilePath -notlike '*\DefaultAppPool*') {
                    
                    $username = Split-Path $profilePath -Leaf
                    $profiles += @{
                        Username = $username
                        ProfilePath = $profilePath
                        SID = $sid
                        RegistryPath = "HKU:\$sid"
                    }
                }
            }
            catch {
                Write-Log "Error processing profile $($_.PSChildName): $($_.Exception.Message)" -Level 'WARN'
            }
        }
        
        Write-Log "Found $($profiles.Count) user profiles"
        return $profiles
    }
    catch {
        Write-Log "Error discovering user profiles: $($_.Exception.Message)" -Level 'ERROR'
        return @()
    }
}

function Mount-UserRegistryHives {
    param([array]$UserProfiles)
    
    if (-not $UserProfiles -or $UserProfiles.Count -eq 0) {
        Write-Log "No user profiles to mount"
        return
    }
    
    Write-Log "Mounting user registry hives..."
    
    foreach ($profile in $UserProfiles) {
        $ntUserPath = Join-Path $profile.ProfilePath "NTUSER.DAT"
        
        if (Test-Path $ntUserPath) {
            try {
                # Check if already mounted
                if (-not (Test-Path "HKU:\$($profile.SID)")) {
                    $result = reg load "HKU\$($profile.SID)" $ntUserPath 2>&1
                    
                    if ($LASTEXITCODE -eq 0) {
                        Write-Log "Mounted registry hive for: $($profile.Username)"
                    } else {
                        Write-Log "Failed to mount registry hive for: $($profile.Username) - $result" -Level 'WARN'
                    }
                } else {
                    Write-Log "Registry hive already mounted for: $($profile.Username)"
                }
            }
            catch {
                Write-Log "Failed to mount registry for $($profile.Username): $($_.Exception.Message)" -Level 'WARN'
            }
        } else {
            Write-Log "NTUSER.DAT not found for $($profile.Username) at: $ntUserPath" -Level 'WARN'
        }
    }
    
    # Wait a moment for registry changes to be available
    Start-Sleep -Seconds 2
}

function Dismount-UserRegistryHives {
    param([array]$UserProfiles)
    
    if (-not $UserProfiles -or $UserProfiles.Count -eq 0) {
        Write-Log "No user profiles to dismount"
        return
    }
    
    Write-Log "Dismounting user registry hives..."
    
    foreach ($profile in $UserProfiles) {
        $maxAttempts = 3
        $attempt = 1
        $dismountSuccess = $false
        
        try {
            if (Test-Path "HKU:\$($profile.SID)") {
                Write-Log "Dismounting registry hive for: $($profile.Username)"
                
                while ($attempt -le $maxAttempts -and -not $dismountSuccess) {
                    Write-Log "Dismount attempt $attempt of $maxAttempts for: $($profile.Username)"
                    
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
                    $result = reg unload "HKU\$($profile.SID)" 2>&1
                    $exitCode = $LASTEXITCODE
                    
                    if ($exitCode -eq 0) {
                        Write-Log "Successfully dismounted registry hive for: $($profile.Username)"
                        $dismountSuccess = $true
                    } else {
                        Write-Log "Dismount attempt $attempt failed for $($profile.Username) - $result" -Level 'WARN'
                        
                        if ($attempt -lt $maxAttempts) {
                            # Wait longer between attempts
                            Write-Log "Waiting before retry..." -Level 'INFO'
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
    Write-Log "Performing final cleanup..."
    [System.GC]::Collect()
    [System.GC]::WaitForPendingFinalizers()
    [System.GC]::Collect()
    
    # Wait a moment for system to stabilize
    Start-Sleep -Seconds 2
}

# ================================
# Winget Management
# ================================

function Test-Winget {
    try {
        $null = Get-Command winget -ErrorAction Stop
        $version = (winget --version 2>$null) -replace '[^\d\.]', ''
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

function Export-WingetApps {
    Write-Log "Exporting installed apps to apps.json..."
    try {
        $exportPath = Join-Path $PSScriptRoot "apps.json"
        winget export -o $exportPath --accept-source-agreements 2>&1
        
        if ($LASTEXITCODE -eq 0 -and (Test-Path $exportPath)) {
            Write-Log "Export completed successfully to: $exportPath"
            return $true
        } else {
            Write-Log "Export may have failed - check file exists at: $exportPath" -Level 'WARN'
            return $false
        }
    }
    catch {
        Write-Log "Failed to export winget apps: $($_.Exception.Message)" -Level 'ERROR'
        return $false
    }
}

function Import-WingetApps {
    Write-Log "Importing apps from apps.json..."
    try {
        $importPath = Join-Path $PSScriptRoot "apps.json"
        
        if (-not (Test-Path $importPath)) {
            Write-Log "apps.json not found at: $importPath" -Level 'ERROR'
            return $false
        }
        
        winget import -i $importPath --accept-source-agreements --accept-package-agreements 2>&1
        
        if ($LASTEXITCODE -eq 0) {
            Write-Log "Import completed successfully."
            return $true
        } else {
            Write-Log "Import completed with warnings or errors (Exit code: $LASTEXITCODE)" -Level 'WARN'
            return $false
        }
    }
    catch {
        Write-Log "Failed to import winget apps: $($_.Exception.Message)" -Level 'ERROR'
        return $false
    }
}

# ================================
# Enhanced Bloatware Removal Functions
# ================================

function Remove-WingetApps {
    param([string[]]$AppPatterns)
    
    if (-not $AppPatterns -or $AppPatterns.Count -eq 0) {
        Write-Log "No app patterns provided for removal"
        return
    }
    
    Write-Log "Starting winget app removal..."
    
    foreach ($pattern in $AppPatterns) {
        Write-Log "Searching for apps matching: $pattern"
        
        try {
            # Get list of installed apps matching pattern (more reliable approach)
            $listOutput = winget list --name "$pattern" --accept-source-agreements 2>$null
            
            if ($listOutput -and ($listOutput | Where-Object { $_ -and $_ -notmatch "^Name\s+Id\s+Version" -and $_.Trim() })) {
                Write-Log "Found app(s) matching '$pattern'"
                
                # Try uninstalling by pattern
                Write-Log "Attempting uninstall for pattern: $pattern"
                $uninstallResult = winget uninstall --name "$pattern" --silent --force --accept-source-agreements 2>&1
                
                if ($LASTEXITCODE -eq 0) {
                    Write-Log "Successfully removed apps matching: $pattern"
                } else {
                    Write-Log "Uninstall completed with warnings for: $pattern (Exit code: $LASTEXITCODE)" -Level 'WARN'
                }
            } else {
                Write-Log "No apps found matching: $pattern"
            }
        }
        catch {
            Write-Log "Error processing pattern: $($_.Exception.Message)" -Level 'ERROR'
        }
    }
}

function Remove-AppxPackagesAllUsers {
    Write-Log "Removing UWP/Appx packages for all users..."

    $packagesToRemove = @(
        '*Outlook*', '*Clipchamp*', '*MicrosoftFamily*', '*OneDrive*', '*LinkedIn*',
        '*Xbox*', '*Skype*', '*MixedReality*', '*RemoteDesktop*', '*QuickAssist*',
        '*MicrosoftTeams*', '*Disney*', '*Netflix*', '*Spotify*', '*TikTok*',
        '*Instagram*', '*Facebook*', '*Candy*', '*Twitter*', '*Minecraft*'
    )

    $removedCount = 0
    $totalPackages = 0

    foreach ($pattern in $packagesToRemove) {
        Write-Log "Processing Appx pattern: $pattern"

        try {
            # Remove installed packages
            $installed = Get-AppxPackage -AllUsers -ErrorAction SilentlyContinue | Where-Object { $_.Name -like $pattern }
            $totalPackages += $installed.Count
            
            if ($installed.Count -gt 0) {
                foreach ($pkg in $installed) {
                    try {
                        Write-Log "Removing installed package: $($pkg.Name)"
                        Remove-AppxPackage -Package $pkg.PackageFullName -AllUsers -ErrorAction Stop
                        $removedCount++
                    }
                    catch {
                        Write-Log "Failed to remove package $($pkg.Name): $($_.Exception.Message)" -Level 'WARN'
                    }
                }
            } else {
                Write-Log "No installed packages found for: $pattern"
            }

            # Remove provisioned packages
            $provisioned = Get-AppxProvisionedPackage -Online -ErrorAction SilentlyContinue | Where-Object { $_.DisplayName -like $pattern }
            
            if ($provisioned.Count -gt 0) {
                foreach ($pkg in $provisioned) {
                    try {
                        Write-Log "Removing provisioned package: $($pkg.DisplayName)"
                        Remove-AppxProvisionedPackage -Online -PackageName $pkg.PackageName -ErrorAction Stop
                    }
                    catch {
                        Write-Log "Failed to remove provisioned package $($pkg.DisplayName): $($_.Exception.Message)" -Level 'WARN'
                    }
                }
            } else {
                Write-Log "No provisioned packages found for: $pattern"
            }
        }
        catch {
            Write-Log "Error removing pattern: $($_.Exception.Message)" -Level 'ERROR'
        }
    }
    
    # Log summary
    try {
        $remainingAppx = Get-AppxPackage -AllUsers -ErrorAction SilentlyContinue
        Write-Log "Package removal summary: $removedCount removed, $($remainingAppx.Count) remaining"
    }
    catch {
        Write-Log "Could not get final package count: $($_.Exception.Message)" -Level 'WARN'
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

    $removedCount = 0

    foreach ($capability in $capabilitiesToRemove) {
        try {
            $state = Get-WindowsCapability -Online -Name $capability -ErrorAction SilentlyContinue
            if ($state -and $state.State -eq 'Installed') {
                Write-Log "Removing capability: $capability"
                Remove-WindowsCapability -Online -Name $capability -ErrorAction Stop | Out-Null
                $removedCount++
                Write-Log "Successfully removed capability: $capability"
            } else {
                Write-Log "Capability not installed or already removed: $capability"
            }
        }
        catch {
            Write-Log "Error processing capability: $($_.Exception.Message)" -Level 'WARN'
        }
    }
    
    Write-Log "Removed $removedCount Windows capabilities"
}

function Remove-McAfeeProducts {
    Write-Log "Searching for McAfee products..."

    $uninstallPaths = @(
        'HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*',
        'HKLM:\Software\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*'
    )

    $mcafeeFound = $false
    $mcafeeProducts = @()

    # First, collect all McAfee products
    foreach ($path in $uninstallPaths) {
        try {
            Get-ItemProperty $path -ErrorAction SilentlyContinue |
            Where-Object { $_.DisplayName -like '*McAfee*' } |
            ForEach-Object {
                $mcafeeFound = $true
                $mcafeeProducts += @{
                    DisplayName = $_.DisplayName
                    UninstallString = $_.UninstallString
                    QuietUninstallString = $_.QuietUninstallString
                }
            }
        }
        catch {
            Write-Log "Error accessing registry path $path`: $($_.Exception.Message)" -Level 'WARN'
        }
    }

    if (-not $mcafeeFound) {
        Write-Log "No McAfee products found"
        return
    }

    Write-Log "Found $($mcafeeProducts.Count) McAfee product(s)"

    # Now attempt to uninstall each product
    foreach ($product in $mcafeeProducts) {
        $displayName = $product.DisplayName
        $uninstallString = $product.UninstallString
        $quietUninstallString = $product.QuietUninstallString

        Write-Log "Processing McAfee product: $displayName"

        # Prefer quiet uninstall string if available
        $targetUninstallString = if ($quietUninstallString) { $quietUninstallString } else { $uninstallString }

        if (-not $targetUninstallString) {
            Write-Log "No uninstall string found for: $displayName" -Level 'WARN'
            continue
        }

        try {
            if ($targetUninstallString -match 'msiexec\.exe.*\{.*\}') {
                # Extract product code from uninstall string
                if ($targetUninstallString -match '\{[0-9A-F-]{36}\}') {
                    $productCode = $Matches[0]
                    $arguments = "/x $productCode /quiet /norestart"
                    Write-Log "Detected MSI-based uninstall for $displayName using product code: $productCode"
                    
                    $process = Start-Process -FilePath "msiexec.exe" -ArgumentList $arguments -Wait -PassThru -WindowStyle Hidden -ErrorAction Stop
                    
                    if ($process.ExitCode -eq 0) {
                        Write-Log "Successfully uninstalled MSI-based product: $displayName"
                    } else {
                        Write-Log "MSI uninstall completed with exit code $($process.ExitCode) for: $displayName" -Level 'WARN'
                    }
                } else {
                    Write-Log "Could not extract product code from MSI uninstall string for: $displayName" -Level 'WARN'
                }
            } else {
                # Parse executable and arguments
                if ($targetUninstallString -match '^"([^"]+)"\s*(.*)$') {
                    $executable = $Matches[1]
                    $arguments = $Matches[2]
                } else {
                    $parts = $targetUninstallString.Split(' ', 2)
                    $executable = $parts[0].Trim('"')
                    $arguments = if ($parts.Length -gt 1) { $parts[1] } else { '' }
                }

                # Add silent flags if not present
                if ($arguments -notmatch '/S|/silent|/quiet|/qn') {
                    $arguments += ' /quiet /norestart'
                }

                if (Test-Path $executable) {
                    $process = Start-Process -FilePath $executable -ArgumentList $arguments -Wait -PassThru -WindowStyle Hidden -ErrorAction Stop
                    
                    if ($process.ExitCode -eq 0) {
                        Write-Log "Successfully uninstalled: $displayName"
                    } else {
                        Write-Log "Uninstall completed with exit code $($process.ExitCode) for: $displayName" -Level 'WARN'
                    }
                } else {
                    Write-Log "Executable not found: $executable" -Level 'ERROR'
                }
            }
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
    Write-Log "Installing standard applications..."
    
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
    
    # .NET Runtimes
    $dotnetApps = @(
        @{ Id = 'Microsoft.DotNet.Framework.4.8.1'; Name = '.NET Framework 4.8.1' },
        @{ Id = 'Microsoft.DotNet.DesktopRuntime.8'; Name = '.NET Desktop Runtime 8' },
        @{ Id = 'Microsoft.DotNet.DesktopRuntime.9'; Name = '.NET Desktop Runtime 9' }
    )
    
    # Visual C++ Redistributables (essential ones only)
    $vcredistApps = @(
        @{ Id = 'Microsoft.VCRedist.2015+.x64'; Name = 'VC Redist x64 2015+' },
        @{ Id = 'Microsoft.VCRedist.2015+.x86'; Name = 'VC Redist x86 2015+' }
    )
    
    # Java Runtimes (only if not skipped)
    $javaApps = @(
        @{ Id = 'Oracle.JavaRuntimeEnvironment'; Name = 'Java Runtime Environment' }
    )
    
    # Combine app lists
    $appsToInstall = $coreApps + $dotnetApps + $vcredistApps
    
    if (-not $SkipJavaRuntimes) {
        $appsToInstall += $javaApps
        Write-Log "Including Java runtimes in installation"
    } else {
        Write-Log "Skipping Java runtimes (SkipJavaRuntimes flag set)"
    }
    
    $successCount = 0
    $totalCount = $appsToInstall.Count
    
    Write-Log "Installing $totalCount applications and runtime libraries..."
    Write-Log "Categories: Core Apps ($($coreApps.Count)), .NET ($($dotnetApps.Count)), VC++ Redist ($($vcredistApps.Count)), Java JRE ($($javaJREApps.Count)), Java JDK ($($javaJDKApps.Count))"
    
    foreach ($app in $appsToInstall) {
        Write-Log "Installing: $($app.Name) ($($app.Id))"
        
        try {
            # Check if already installed first
            $existingApp = winget list --id $app.Id --exact --accept-source-agreements 2>$null
            if ($existingApp -and ($existingApp | Where-Object { $_ -match [regex]::Escape($app.Id) })) {
                Write-Log "Already installed: $($app.Name)"
                $successCount++
                continue
            }
            
            # Attempt installation with proper error handling
            $installResult = winget install --id $app.Id --source winget --accept-package-agreements --accept-source-agreements --silent 2>&1
            
            if ($LASTEXITCODE -eq 0) {
                Write-Log "Successfully installed: $($app.Name)"
                $successCount++
            } elseif ($LASTEXITCODE -eq -1978335189) {
                # Package already installed (detected during install)
                Write-Log "Already installed (detected during install): $($app.Name)"
                $successCount++
            } elseif ($LASTEXITCODE -eq -1978335212) {
                # Package not found
                Write-Log "Package not found in winget: $($app.Name) ($($app.Id))" -Level 'WARN'
            } else {
                Write-Log "Failed to install $($app.Name). Exit code: $LASTEXITCODE" -Level 'WARN'
                if ($installResult) {
                    Write-Log "Install output: $installResult" -Level 'DEBUG'
                }
            }
        }
        catch {
            Write-Log "Error installing $($app.Name): $($_.Exception.Message)" -Level 'ERROR'
        }
        
        # Small delay between installations to prevent overwhelm
        Start-Sleep -Milliseconds 500
    }
    
    Write-Log "App installation complete: $successCount/$totalCount successful"
    
    # Log summary by category
    Write-Log "Installation Summary:"
    Write-Log "- Core Applications: $($coreApps.Count) packages"
    Write-Log "- .NET Frameworks/Runtimes: $($dotnetApps.Count) packages"
    Write-Log "- Visual C++ Redistributables: $($vcredistApps.Count) packages"
    if (-not $SkipJavaRuntimes) {
        Write-Log "- Java JRE Packages: $($javaJREApps.Count) packages"
        Write-Log "- Java JDK Packages: $($javaJDKApps.Count) packages"
    }
    
    return ($successCount -ge ($totalCount * 0.8))  # Consider successful if 80% or more installed
}

# ================================
# Enhanced System Configuration
# ================================

function Set-SystemConfigurationAllUsers {
    Write-Log "Configuring system-wide settings for all users..."
    
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
            
            # Disable Windows Telemetry (but keep minimal for security updates)
            'HKLM:\SOFTWARE\Policies\Microsoft\Windows\DataCollection' = @{
                'AllowTelemetry' = 1  # 1 = Basic (required for security), 0 might break updates
                'MaxTelemetryAllowed' = 1
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
            try {
                if (-not (Test-Path $keyPath)) {
                    New-Item -Path $keyPath -Force | Out-Null
                }
                
                foreach ($valueName in $systemSettings[$keyPath].Keys) {
                    $value = $systemSettings[$keyPath][$valueName]
                    Set-ItemProperty -Path $keyPath -Name $valueName -Value $value -Type DWord -Force
                    Write-Log "Set system setting: $keyPath\$valueName = $value"
                }
            }
            catch {
                Write-Log "Error setting registry key $keyPath`: $($_.Exception.Message)" -Level 'WARN'
            }
        }
        
        # Disable problematic services (be more conservative)
        $servicesToDisable = @(
            'DiagTrack',  # Connected User Experiences and Telemetry
            'dmwappushservice',  # WAP Push Message Routing Service
            'lfsvc',  # Geolocation Service
            'MapsBroker',  # Downloaded Maps Manager
            'XblAuthManager',  # Xbox Live Auth Manager
            'XblGameSave',  # Xbox Live Game Save Service
            'XboxNetApiSvc'  # Xbox Live Networking Service
        )
        
        foreach ($serviceName in $servicesToDisable) {
            try {
                $service = Get-Service -Name $serviceName -ErrorAction SilentlyContinue
                if ($service -and $service.StartType -ne 'Disabled') {
                    Write-Log "Disabling service: $serviceName"
                    if ($service.Status -eq 'Running') {
                        Stop-Service -Name $serviceName -Force -ErrorAction SilentlyContinue
                    }
                    Set-Service -Name $serviceName -StartupType Disabled -ErrorAction SilentlyContinue
                    Write-Log "Successfully disabled service: $serviceName"
                } elseif ($service) {
                    Write-Log "Service already disabled: $serviceName"
                } else {
                    Write-Log "Service not found: $serviceName"
                }
            }
            catch {
                Write-Log "Could not disable service $serviceName`: $($_.Exception.Message)" -Level 'WARN'
            }
        }
        
        Write-Log "System-wide configuration completed"
        return $true
    }
    catch {
        Write-Log "Error configuring system: $($_.Exception.Message)" -Level 'ERROR'
        return $false
    }
}

function Set-DefaultUserProfile {
    Write-Log "Configuring default user profile for future accounts..."
    
    if ($SkipDefaultUserConfig) {
        Write-Log "Skipping default user configuration (SkipDefaultUserConfig flag set)"
        return $true
    }
    
    $defaultUserMounted = $false
    $configurationSuccess = $false
    
    try {
        # Verify HKU drive exists
        if (-not (Get-PSDrive -Name HKU -ErrorAction SilentlyContinue)) {
            Write-Log "HKU: drive not available, attempting to recreate..." -Level 'WARN'
            if (-not (Initialize-RegistryDrives)) {
                Write-Log "Cannot configure default user profile - HKU drive unavailable" -Level 'ERROR'
                return $false
            }
        }

        # Define default user profile path
        $defaultUserPath = "${env:SystemDrive}\Users\Default\NTUSER.DAT"

        # Check if default user profile is accessible
        if (-not (Test-Path $defaultUserPath)) {
            Write-Log "Default user profile not found at: $defaultUserPath" -Level 'WARN'
            return $false
        }

        # Check for processes that might lock the profile
        $maxAttempts = 3
        $attempt = 1
        
        while ($attempt -le $maxAttempts) {
            # More specific check for processes that could lock NTUSER.DAT
            $lockingProcesses = Get-Process | Where-Object {
                try {
                    $_.Modules | Where-Object { $_.FileName -like "*NTUSER.DAT*" }
                } catch { $false }
            }

            if ($lockingProcesses) {
                Write-Log "Attempt $attempt`: Default user profile may be locked. Waiting 5 seconds..." -Level 'WARN'
                Start-Sleep -Seconds 5
                $attempt++
            } else {
                break
            }
        }

        if ($attempt -gt $maxAttempts) {
            Write-Log "Default user profile appears to be locked after $maxAttempts attempts. Proceeding anyway..." -Level 'WARN'
        }

        Write-Log "Mounting default user registry hive from: $defaultUserPath"
        $result = reg load "HKU\DefaultUser" $defaultUserPath 2>&1
        
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
            
            $settingsApplied = 0
            $totalSettings = ($defaultUserSettings.Values | ForEach-Object { $_.Count } | Measure-Object -Sum).Sum
            
            foreach ($keyPath in $defaultUserSettings.Keys) {
                $fullPath = "HKU:\DefaultUser\$keyPath"
                
                try {
                    # Verify HKU drive is still available
                    if (-not (Test-Path "HKU:\")) {
                        Write-Log "HKU: drive became unavailable during configuration" -Level 'ERROR'
                        break
                    }
                    
                    if (-not (Test-Path $fullPath)) {
                        Write-Log "Creating registry path: $fullPath"
                        New-Item -Path $fullPath -Force | Out-Null
                    }
                    
                    foreach ($valueName in $defaultUserSettings[$keyPath].Keys) {
                        try {
                            $value = $defaultUserSettings[$keyPath][$valueName]
                            Set-ItemProperty -Path $fullPath -Name $valueName -Value $value -Type DWord -Force
                            Write-Log "Set default user setting: $keyPath\$valueName = $value"
                            $settingsApplied++
                        }
                        catch {
                            Write-Log "Error setting value $valueName in ${keyPath}: $($_.Exception.Message)" -Level 'WARN'
                        }
                    }
                }
                catch {
                    Write-Log ("Error setting default user registry key {0}: {1}" -f $keyPath, $_.Exception.Message) -Level 'WARN'
                }
            }
            
            Write-Log "Applied $settingsApplied of $totalSettings default user settings"
            $configurationSuccess = ($settingsApplied -gt 0)
            
        } else {
            Write-Log "Failed to mount default user registry hive - $result" -Level 'WARN'
            $configurationSuccess = $false
        }
    }
    catch {
        Write-Log "Error configuring default user profile: $($_.Exception.Message)" -Level 'ERROR'
        $configurationSuccess = $false
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
                
                $result = reg unload "HKU\DefaultUser" 2>&1
                $exitCode = $LASTEXITCODE
                
                if ($exitCode -eq 0) {
                    Write-Log "Successfully unmounted default user registry hive"
                    $unmountSuccess = $true
                } else {
                    Write-Log "Default user unmount attempt $attempt failed - $result" -Level 'WARN'
                    if ($attempt -lt $maxAttempts) {
                        Start-Sleep -Seconds 3
                    }
                }
                
                $attempt++
            }
            
            if (-not $unmountSuccess) {
                Write-Log "Failed to unmount default user hive after $maxAttempts attempts. This may not affect functionality." -Level 'WARN'
                $configurationSuccess = $false
            }
        }
    }
    
    return $configurationSuccess
}

function Configure-AllUserProfiles {
    param([array]$UserProfiles)
    
    if (-not $UserProfiles -or $UserProfiles.Count -eq 0) {
        Write-Log "No user profiles to configure"
        return $true
    }
    
    Write-Log "Configuring settings for all existing user profiles..."
    
    $configuredProfiles = 0
    
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
                
                $settingsApplied = 0
                
                foreach ($keyPath in $userSettings.Keys) {
                    $fullPath = "$($profile.RegistryPath)\$keyPath"
                    
                    try {
                        if (-not (Test-Path $fullPath)) {
                            New-Item -Path $fullPath -Force | Out-Null
                        }
                        
                        foreach ($valueName in $userSettings[$keyPath].Keys) {
                            try {
                                $value = $userSettings[$keyPath][$valueName]
                                
                                if ($null -eq $value) {
                                    # Remove the value
                                    Remove-ItemProperty -Path $fullPath -Name $valueName -ErrorAction SilentlyContinue
                                    Write-Log "Removed $($profile.Username) setting: $keyPath\$valueName"
                                } else {
                                    Set-ItemProperty -Path $fullPath -Name $valueName -Value $value -Type DWord -Force
                                    Write-Log "Set $($profile.Username) setting: $keyPath\$valueName = $value"
                                }
                                $settingsApplied++
                            }
                            catch {
                                Write-Log "Error setting value $valueName for $($profile.Username): $($_.Exception.Message)" -Level 'WARN'
                            }
                        }
                    }
                    catch {
                        Write-Log "Error setting registry key $keyPath for $($profile.Username): $($_.Exception.Message)" -Level 'WARN'
                    }
                }
                
                if ($settingsApplied -gt 0) {
                    $configuredProfiles++
                    Write-Log "Applied $settingsApplied settings for $($profile.Username)"
                }
            } else {
                Write-Log "Registry path not accessible for $($profile.Username): $($profile.RegistryPath)" -Level 'WARN'
            }
        }
        catch {
            Write-Log "Error configuring profile $($profile.Username): $($_.Exception.Message)" -Level 'WARN'
        }
    }
    
    Write-Log "Successfully configured $configuredProfiles of $($UserProfiles.Count) user profiles"
    return ($configuredProfiles -eq $UserProfiles.Count)
}

# ================================
# Main Execution
# ================================

function Main {
    $overallSuccess = $true
    
    try {
        # Initialize registry drives first
        if (-not (Initialize-RegistryDrives)) {
            Write-Log "Failed to initialize registry drives. Cannot continue." -Level 'ERROR'
            return $false
        }

        # Verify prerequisites
        if (-not (Test-Winget)) {
            Write-Log "Winget is required but not available. Please install App Installer from Microsoft Store." -Level 'ERROR'
            return $false
        }

        # Initialize Winget sources
        if (-not (Initialize-WingetSources)) {
            Write-Log "Failed to initialize winget sources" -Level 'WARN'
            $overallSuccess = $false
        }

        # Optional Winget export/import
        if ($ExportWingetApps) {
            Write-Log "ExportWingetApps flag detected. Exporting current winget apps..."
            if (-not (Export-WingetApps)) {
                Write-Log "Failed to export winget apps" -Level 'WARN'
                $overallSuccess = $false
            }
        }

        if ($ImportWingetApps) {
            Write-Log "ImportWingetApps flag detected. Importing apps from apps.json..."
            if (-not (Import-WingetApps)) {
                Write-Log "Failed to import winget apps" -Level 'WARN'
                $overallSuccess = $false
            }
        }

        # Get all user profiles
        $userProfiles = Get-AllUserProfiles
        
        if ($userProfiles.Count -eq 0) {
            Write-Log "No user profiles found - this may indicate a problem" -Level 'WARN'
        }
        
        # Mount user registry hives for configuration
        if ($userProfiles.Count -gt 0) {
            Mount-UserRegistryHives -UserProfiles $userProfiles
        }
        
        # Execute bloatware removal
        if (-not $SkipBloatwareRemoval) {
            Write-Log "=== Starting Enhanced Bloatware Removal for All Users ==="
            
            try {
                $bloatwarePatterns = @(
                    'CoPilot', 'Outlook', 'Quick Assist', 'Remote Desktop',
                    'Mixed Reality Portal', 'Clipchamp', 'Xbox', 'Family',
                    'Skype', 'LinkedIn', 'OneDrive', 'Teams', 'Disney',
                    'Netflix', 'Spotify', 'TikTok', 'Instagram', 'Facebook',
                    'Candy', 'Twitter', 'Minecraft'
                )
                
                Remove-WingetApps -AppPatterns $bloatwarePatterns
                Remove-AppxPackagesAllUsers
                Remove-WindowsCapabilities
                Remove-McAfeeProducts
                
                Write-Log "=== Enhanced Bloatware Removal Completed ==="
            }
            catch {
                Write-Log "Error during bloatware removal: $($_.Exception.Message)" -Level 'ERROR'
                $overallSuccess = $false
            }
        } else {
            Write-Log "Skipping bloatware removal (SkipBloatwareRemoval flag set)"
        }
        
        # Execute application installation
        if (-not $SkipAppInstall) {
            Write-Log "=== Starting Application Installation ==="
            if (-not (Install-StandardApps)) {
                Write-Log "Application installation completed with warnings" -Level 'WARN'
                $overallSuccess = $false
            }
            Write-Log "=== Application Installation Completed ==="
        } else {
            Write-Log "Skipping application installation (SkipAppInstall flag set)"
        }
        
        # Configure system settings for all users
        if (-not (Set-SystemConfigurationAllUsers)) {
            Write-Log "System configuration completed with errors" -Level 'WARN'
            $overallSuccess = $false
        }
        
        # Configure existing user profiles
        if ($userProfiles.Count -gt 0) {
            if (-not (Configure-AllUserProfiles -UserProfiles $userProfiles)) {
                Write-Log "User profile configuration completed with warnings" -Level 'WARN'
                $overallSuccess = $false
            }
        }

        # Configure default user profile for future accounts (only once)
        if (-not (Set-DefaultUserProfile)) {
            Write-Log "Default user profile configuration failed" -Level 'WARN'
            $overallSuccess = $false
        }
        
        return $overallSuccess
    }
    catch {
        Write-Log "Critical error in main execution: $($_.Exception.Message)" -Level 'ERROR'
        return $false
    }
    finally {
        # Clean up mounted registry hives
        if ($userProfiles -and $userProfiles.Count -gt 0) {
            Write-Log "Starting registry cleanup process..."
            Dismount-UserRegistryHives -UserProfiles $userProfiles
        } else {
            Write-Log "No user profiles to dismount"
        }
        
        # Cleanup registry drives and restore progress preference
        Remove-RegistryDrives
        $ProgressPreference = 'Continue'
    }
}

# ================================
# Script Entry Point
# ================================

try {
    $success = Main
    
    if ($success) {
        Write-Log "===== DeployWorkstation-AllUsers.ps1 Completed Successfully ====="
        Write-Host "`n*** Setup complete for ALL users (current and future)! Log saved to: $LogPath ***" -ForegroundColor Green
    } else {
        Write-Log "===== DeployWorkstation-AllUsers.ps1 Completed with Warnings ====="
        Write-Host "`n*** Setup completed with some warnings. Check log at: $LogPath ***" -ForegroundColor Yellow
    }
    
    Write-Host "Press Enter to exit..." -ForegroundColor Yellow
    Read-Host | Out-Null
}
catch {
    Write-Log "Critical error: $($_.Exception.Message)" -Level 'ERROR'
    Write-Host "`n*** Setup failed! Check log at: $LogPath ***" -ForegroundColor Red
    
    # Ensure registry hives are cleaned up even on error
    if ($userProfiles -and $userProfiles.Count -gt 0) {
        Write-Log "Emergency cleanup: Dismounting registry hives due to error..."
        try {
            Dismount-UserRegistryHives -UserProfiles $userProfiles
        }
        catch {
            Write-Log "Emergency cleanup failed: $($_.Exception.Message)" -Level 'ERROR'
        }
    }
    
    Write-Host "Press Enter to exit..." -ForegroundColor Red
    Read-Host | Out-Null
    exit 1
}
