# DeployWorkstation.OfflineFallback.psm1
# Offline fallback handling for when internet connectivity is limited

using module .\DeployWorkstation.Logging.psm1

function Test-InternetConnectivity {
    <#
    .SYNOPSIS
    Tests internet connectivity to various services
    
    .PARAMETER TestEndpoints
    Array of endpoints to test connectivity to
    
    .PARAMETER TimeoutSeconds
    Timeout for each connectivity test
    #>
    [CmdletBinding()]
    param(
        [string[]]$TestEndpoints = @(
            'google.com',
            'microsoft.com',
            'github.com',
            '8.8.8.8'
        ),
        [int]$TimeoutSeconds = 5
    )
    
    Write-LogEntry -Message "Testing internet connectivity..." -Component 'OfflineFallback'
    
    $results = @{
        HasInternet = $false
        TestedEndpoints = @()
        SuccessfulEndpoints = @()
        FailedEndpoints = @()
    }
    
    foreach ($endpoint in $TestEndpoints) {
        try {
            Write-LogEntry -Message "Testing connectivity to: $endpoint" -Component 'OfflineFallback' -Level 'Debug'
            
            $result = Test-NetConnection -ComputerName $endpoint -Port 80 -InformationLevel Quiet -WarningAction SilentlyContinue -ErrorAction Stop
            
            $endpointResult = @{
                Endpoint = $endpoint
                Success = $result
                Method = 'Test-NetConnection'
            }
            
            $results.TestedEndpoints += $endpointResult
            
            if ($result) {
                $results.SuccessfulEndpoints += $endpoint
                $results.HasInternet = $true
                Write-LogEntry -Message "Successfully connected to: $endpoint" -Component 'OfflineFallback' -Level 'Debug'
            } else {
                $results.FailedEndpoints += $endpoint
                Write-LogEntry -Message "Failed to connect to: $endpoint" -Component 'OfflineFallback' -Level 'Debug'
            }
        }
        catch {
            # Fallback to ping test
            try {
                $pingResult = Test-Connection -ComputerName $endpoint -Count 1 -Quiet -ErrorAction Stop
                
                $endpointResult = @{
                    Endpoint = $endpoint
                    Success = $pingResult
                    Method = 'Test-Connection'
                }
                
                $results.TestedEndpoints += $endpointResult
                
                if ($pingResult) {
                    $results.SuccessfulEndpoints += $endpoint
                    $results.HasInternet = $true
                    Write-LogEntry -Message "Successfully pinged: $endpoint" -Component 'OfflineFallback' -Level 'Debug'
                } else {
                    $results.FailedEndpoints += $endpoint
                    Write-LogEntry -Message "Failed to ping: $endpoint" -Component 'OfflineFallback' -Level 'Debug'
                }
            }
            catch {
                $results.FailedEndpoints += $endpoint
                Write-LogEntry -Message "All connectivity tests failed for: $endpoint" -Component 'OfflineFallback' -Level 'Debug'
            }
        }
    }
    
    if ($results.HasInternet) {
        Write-LogEntry -Message "Internet connectivity confirmed. $($results.SuccessfulEndpoints.Count)/$($TestEndpoints.Count) endpoints reachable" -Component 'OfflineFallback'
    } else {
        Write-LogEntry -Message "No internet connectivity detected. All $($TestEndpoints.Count) endpoints unreachable" -Level 'Warning' -Component 'OfflineFallback'
    }
    
    return $results
}

function Get-OfflineInstallerPath {
    <#
    .SYNOPSIS
    Gets the path to offline installers directory
    
    .PARAMETER BasePath
    Base path for offline installers (defaults to script directory)
    #>
    [CmdletBinding()]
    param(
        [string]$BasePath
    )
    
    if (-not $BasePath) {
        $BasePath = $PSScriptRoot
    }
    
    $offlinePath = Join-Path $BasePath "OfflineInstallers"
    
    if (-not (Test-Path $offlinePath)) {
        Write-LogEntry -Message "Creating offline installers directory: $offlinePath" -Component 'OfflineFallback'
        New-Item -Path $offlinePath -ItemType Directory -Force | Out-Null
    }
    
    return $offlinePath
}

function Install-OfflineApplication {
    <#
    .SYNOPSIS
    Installs an application from offline installer
    
    .PARAMETER InstallerPath
    Path to the offline installer
    
    .PARAMETER ApplicationName
    Name of the application for logging
    
    .PARAMETER Silent
    Whether to install silently
    
    .PARAMETER Arguments
    Additional arguments for the installer
    
    .PARAMETER TimeoutMinutes
    Maximum time to wait for installation
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$InstallerPath,
        
        [string]$ApplicationName,
        
        [bool]$Silent = $true,
        
        [string]$Arguments,
        
        [int]$TimeoutMinutes = 10
    )
    
    if (-not $ApplicationName) {
        $ApplicationName = [System.IO.Path]::GetFileNameWithoutExtension($InstallerPath)
    }
    
    if (-not (Test-Path $InstallerPath)) {
        Write-LogEntry -Message "Offline installer not found: $InstallerPath" -Level 'Error' -Component 'OfflineFallback'
        return @{
            Success = $false
            Message = "Installer file not found"
            Application = $ApplicationName
        }
    }
    
    Write-LogEntry -Message "Installing $ApplicationName from offline installer: $InstallerPath" -Component 'OfflineFallback'
    
    try {
        $extension = [System.IO.Path]::GetExtension($InstallerPath).ToLower()
        
        # Determine default silent arguments based on installer type
        if (-not $Arguments -and $Silent) {
            switch ($extension) {
                '.msi' { $Arguments = '/i /quiet /norestart' }
                '.exe' { 
                    # Try common silent flags
                    $Arguments = '/S /silent /quiet'
                }
                default { $Arguments = '/S' }
            }
        }
        
        $processParams = @{
            Wait = $true
            WindowStyle = 'Hidden'
            ErrorAction = 'Stop'
            PassThru = $true
        }
        
        if ($extension -eq '.msi') {
            $processParams.FilePath = 'msiexec.exe'
            $processParams.ArgumentList = $Arguments + " `"$InstallerPath`""
        } else {
            $processParams.FilePath = $InstallerPath
            if ($Arguments) {
                $processParams.ArgumentList = $Arguments
            }
        }
        
        Write-LogEntry -Message "Executing: $($processParams.FilePath) $($processParams.ArgumentList)" -Component 'OfflineFallback' -Level 'Debug'
        
        $process = Start-Process @processParams
        
        # Wait with timeout
        $timeoutMs = $TimeoutMinutes * 60 * 1000
        if (-not $process.WaitForExit($timeoutMs)) {
            Write-LogEntry -Message "Installation timed out after $TimeoutMinutes minutes" -Level 'Warning' -Component 'OfflineFallback'
            $process.Kill()
            return @{
                Success = $false
                Message = "Installation timed out"
                Application = $ApplicationName
                ExitCode = -1
            }
        }
        
        $exitCode = $process.ExitCode
        
        if ($exitCode -eq 0 -or $exitCode -eq 3010) {
            Write-LogEntry -Message "Successfully installed $ApplicationName (Exit code: $exitCode)" -Component 'OfflineFallback'
            return @{
                Success = $true
                Message = "Installation successful"
                Application = $ApplicationName
                ExitCode = $exitCode
                RestartRequired = ($exitCode -eq 3010)
            }
        } else {
            Write-LogEntry -Message "Installation failed for $ApplicationName (Exit code: $exitCode)" -Level 'Warning' -Component 'OfflineFallback'
            return @{
                Success = $false
                Message = "Installation failed with exit code: $exitCode"
                Application = $ApplicationName
                ExitCode = $exitCode
            }
        }
    }
    catch {
        Write-LogEntry -Message "Error installing $ApplicationName`: $($_.Exception.Message)" -Level 'Error' -Component 'OfflineFallback'
        return @{
            Success = $false
            Message = $_.Exception.Message
            Application = $ApplicationName
        }
    }
}

function Get-OfflineInstallers {
    <#
    .SYNOPSIS
    Scans for available offline installers
    
    .PARAMETER OfflineInstallerPath
    Path to offline installers directory
    
    .PARAMETER Extensions
    File extensions to look for
    #>
    [CmdletBinding()]
    param(
        [string]$OfflineInstallerPath,
        [string[]]$Extensions = @('*.exe', '*.msi', '*.zip')
    )
    
    if (-not $OfflineInstallerPath) {
        $OfflineInstallerPath = Get-OfflineInstallerPath
    }
    
    Write-LogEntry -Message "Scanning for offline installers in: $OfflineInstallerPath" -Component 'OfflineFallback'
    
    $installers = @()
    
    foreach ($extension in $Extensions) {
        try {
            $files = Get-ChildItem -Path $OfflineInstallerPath -Filter $extension -ErrorAction SilentlyContinue
            
            foreach ($file in $files) {
                $installers += @{
                    Name = [System.IO.Path]::GetFileNameWithoutExtension($file.Name)
                    FullPath = $file.FullName
                    Extension = $file.Extension
                    Size = $file.Length
                    LastWriteTime = $file.LastWriteTime
                }
            }
        }
        catch {
            Write-LogEntry -Message "Error scanning for $extension files: $($_.Exception.Message)" -Level 'Warning' -Component 'OfflineFallback'
        }
    }
    
    Write-LogEntry -Message "Found $($installers.Count) offline installers" -Component 'OfflineFallback'
    
    return $installers
}

function Invoke-OfflineFallback {
    <#
    .SYNOPSIS
    Main function to handle offline fallback scenarios
    
    .PARAMETER RequiredApplications
    Array of applications that should be installed offline if online installation fails
    
    .PARAMETER OfflineInstallerPath
    Path to offline installers directory
    
    .PARAMETER TestConnectivity
    Whether to test connectivity before attempting offline installation
    #>
    [CmdletBinding()]
    param(
        [hashtable[]]$RequiredApplications = @(),
        [string]$OfflineInstallerPath,
        [bool]$TestConnectivity = $true
    )
    
    if (-not $OfflineInstallerPath) {
        $OfflineInstallerPath = Get-OfflineInstallerPath
    }
    
    Write-LogEntry -Message "Initiating offline fallback process..." -Component 'OfflineFallback'
    
    $results = @{
        ConnectivityTest = $null
        AvailableInstallers = @()
        InstallationResults = @()
        OfflineMode = $false
    }
    
    # Test connectivity if requested
    if ($TestConnectivity) {
        $results.ConnectivityTest = Test-InternetConnectivity
        $results.OfflineMode = -not $results.ConnectivityTest.HasInternet
    } else {
        $results.OfflineMode = $true
    }
    
    # Get available offline installers
    $results.AvailableInstallers = Get-OfflineInstallers -OfflineInstallerPath $OfflineInstallerPath
    
    if ($results.OfflineMode) {
        Write-LogEntry -Message "Operating in offline mode. Attempting to install from offline installers..." -Component 'OfflineFallback'
        
        foreach ($app in $RequiredApplications) {
            $appName = $app.Name
            $matchingInstaller = $results.AvailableInstallers | Where-Object { $_.Name -like "*$appName*" }
            
            if ($matchingInstaller) {
                Write-LogEntry -Message "Found offline installer for: $appName" -Component 'OfflineFallback'
                $installResult = Install-OfflineApplication -InstallerPath $matchingInstaller.FullPath -ApplicationName $appName
                $results.InstallationResults += $installResult
            } else {
                Write-LogEntry -Message "No offline installer found for: $appName" -Level 'Warning' -Component 'OfflineFallback'
                $results.InstallationResults += @{
                    Success = $false
                    Message = "No offline installer available"
                    Application = $appName
                }
            }
        }
    } else {
        Write-LogEntry -Message "Internet connectivity available. Offline fallback not required." -Component 'OfflineFallback'
    }
    
    return $results
}

function Export-OfflineConfiguration {
    <#
    .SYNOPSIS
    Exports configuration for offline deployment
    
    .PARAMETER ConfigPath
    Path to save the configuration file
    
    .PARAMETER IncludeInstallerInventory
    Whether to include an inventory of available offline installers
    #>
    [CmdletBinding()]
    param(
        [string]$ConfigPath,
        [bool]$IncludeInstallerInventory = $true
    )
    
    if (-not $ConfigPath) {
        $ConfigPath = Join-Path (Get-OfflineInstallerPath) "OfflineConfig.json"
    }
    
    Write-LogEntry -Message "Exporting offline configuration to: $ConfigPath" -Component 'OfflineFallback'
    
    $config = @{
        ExportDate = Get-Date
        OfflineInstallerPath = Get-OfflineInstallerPath
        AvailableInstallers = @()
        RecommendedApplications = @()
    }
    
    if ($IncludeInstallerInventory) {
        $config.AvailableInstallers = Get-OfflineInstallers
    }
    
    # Add recommended applications list
    $config.RecommendedApplications = @(
        @{ Name = "Google Chrome"; Installer = "ChromeSetup.exe" },
        @{ Name = "7-Zip"; Installer = "7z*.exe" },
        @{ Name = "VLC Media Player"; Installer = "vlc*.exe" },
        @{ Name = "Adobe Reader"; Installer = "AcroRdrDC*.exe" },
        @{ Name = "Malwarebytes"; Installer = "MBSetup.exe" }
    )
    
    try {
        $config | ConvertTo-Json -Depth 5 | Out-File -FilePath $ConfigPath -Encoding UTF8
        Write-LogEntry -Message "Offline configuration exported successfully" -Component 'OfflineFallback'
        return $true
    }
    catch {
        Write-LogEntry -Message "Failed to export offline configuration: $($_.Exception.Message)" -Level 'Error' -Component 'OfflineFallback'
        return $false
    }
}

# Export functions
Export-ModuleMember -Function Test-InternetConnectivity, Get-OfflineInstallerPath, Install-OfflineApplication, Get-OfflineInstallers, Invoke-OfflineFallback, Export-OfflineConfiguration
