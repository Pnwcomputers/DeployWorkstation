# DeployWorkstation.WinGet.psm1
# WinGet management and application installation functionality

using module .\DeployWorkstation.Logging.psm1

function Test-WinGet {
    <#
    .SYNOPSIS
    Tests if WinGet is available and returns version information
    
    .OUTPUTS
    Returns hashtable with IsAvailable (bool) and Version (string)
    #>
    [CmdletBinding()]
    param()
    
    try {
        $null = Get-Command winget -ErrorAction Stop
        $versionOutput = winget --version 2>$null
        $version = ($versionOutput -replace '[^\d\.]', '').Trim()
        
        Write-LogEntry -Message "WinGet found: v$version" -Component 'WinGet'
        return @{
            IsAvailable = $true
            Version = $version
        }
    }
    catch {
        Write-LogEntry -Message "WinGet not available: $($_.Exception.Message)" -Level 'Error' -Component 'WinGet'
        return @{
            IsAvailable = $false
            Version = $null
        }
    }
}

function Initialize-WinGetSources {
    <#
    .SYNOPSIS
    Configures WinGet sources for optimal performance
    
    .PARAMETER RemoveMSStore
    Whether to remove the Microsoft Store source for better performance
    #>
    [CmdletBinding()]
    param(
        [bool]$RemoveMSStore = $true
    )
    
    Write-LogEntry -Message "Managing winget sources..." -Component 'WinGet'
    
    try {
        # Get current sources
        $sourcesOutput = winget source list 2>$null
        
        if ($RemoveMSStore -and ($sourcesOutput -match 'msstore')) {
            Write-LogEntry -Message "Removing msstore source for better performance..." -Component 'WinGet'
            $result = winget source remove --name msstore 2>&1
            if ($LASTEXITCODE -eq 0) {
                Write-LogEntry -Message "Successfully removed msstore source" -Component 'WinGet'
            } else {
                Write-LogEntry -Message "Failed to remove msstore source: $result" -Level 'Warning' -Component 'WinGet'
            }
        }
        
        # Update winget source
        Write-LogEntry -Message "Updating winget sources..." -Component 'WinGet'
        $updateResult = winget source update --name winget 2>&1
        
        if ($LASTEXITCODE -eq 0) {
            Write-LogEntry -Message "Successfully updated winget sources" -Component 'WinGet'
            return $true
        } else {
            Write-LogEntry -Message "Failed to update winget sources: $updateResult" -Level 'Warning' -Component 'WinGet'
            return $false
        }
    }
    catch {
        Write-LogEntry -Message "Error managing winget sources: $($_.Exception.Message)" -Level 'Error' -Component 'WinGet'
        return $false
    }
}

function Install-WinGetApplication {
    <#
    .SYNOPSIS
    Installs a single application via WinGet
    
    .PARAMETER Id
    The WinGet package ID
    
    .PARAMETER Name
    Friendly name for logging (optional)
    
    .PARAMETER Source
    WinGet source to use (default: winget)
    
    .PARAMETER Silent
    Whether to install silently (default: true)
    
    .PARAMETER AcceptAgreements
    Whether to accept license agreements (default: true)
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Id,
        
        [string]$Name,
        
        [string]$Source = 'winget',
        
        [bool]$Silent = $true,
        
        [bool]$AcceptAgreements = $true
    )
    
    if (-not $Name) {
        $Name = $Id
    }
    
    Write-LogEntry -Message "Installing: $Name ($Id)" -Component 'WinGet'
    
    try {
        $arguments = @('install', '--id', $Id, '--source', $Source)
        
        if ($Silent) {
            $arguments += '--silent'
        }
        
        if ($AcceptAgreements) {
            $arguments += @('--accept-package-agreements', '--accept-source-agreements')
        }
        
        $installResult = & winget @arguments 2>&1
        
        if ($LASTEXITCODE -eq 0) {
            Write-LogEntry -Message "Successfully installed: $Name" -Component 'WinGet'
            return @{
                Success = $true
                Message = "Installation successful"
                ExitCode = $LASTEXITCODE
            }
        } else {
            Write-LogEntry -Message "Failed to install $Name. Exit code: $LASTEXITCODE" -Level 'Warning' -Component 'WinGet'
            return @{
                Success = $false
                Message = "Installation failed with exit code: $LASTEXITCODE"
                ExitCode = $LASTEXITCODE
                Output = $installResult
            }
        }
    }
    catch {
        Write-LogEntry -Message "Error installing $Name`: $($_.Exception.Message)" -Level 'Error' -Component 'WinGet'
        return @{
            Success = $false
            Message = $_.Exception.Message
            ExitCode = $null
        }
    }
}

function Install-WinGetApplications {
    <#
    .SYNOPSIS
    Installs multiple applications via WinGet
    
    .PARAMETER Applications
    Array of hashtables containing Id and Name for each application
    
    .PARAMETER ContinueOnError
    Whether to continue installing other apps if one fails
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [hashtable[]]$Applications,
        
        [bool]$ContinueOnError = $true
    )
    
    Write-LogEntry -Message "Installing $($Applications.Count) applications..." -Component 'WinGet'
    
    $results = @{
        Total = $Applications.Count
        Success = 0
        Failed = 0
        Results = @()
    }
    
    foreach ($app in $Applications) {
        $installResult = Install-WinGetApplication -Id $app.Id -Name $app.Name
        $results.Results += $installResult
        
        if ($installResult.Success) {
            $results.Success++
        } else {
            $results.Failed++
            if (-not $ContinueOnError) {
                Write-LogEntry -Message "Stopping installation due to failure and ContinueOnError=false" -Level 'Warning' -Component 'WinGet'
                break
            }
        }
    }
    
    Write-LogEntry -Message "App installation complete: $($results.Success)/$($results.Total) successful" -Component 'WinGet'
    return $results
}

function Uninstall-WinGetApplication {
    <#
    .SYNOPSIS
    Uninstalls applications via WinGet using pattern matching
    
    .PARAMETER Pattern
    Pattern to match application names
    
    .PARAMETER Force
    Whether to force uninstallation
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Pattern,
        
        [bool]$Force = $true
    )
    
    Write-LogEntry -Message "Searching for apps matching: $Pattern" -Component 'WinGet'
    
    try {
        # Get list of installed apps matching pattern
        $listResult = winget list --name "$Pattern" --accept-source-agreements 2>$null
        $apps = $listResult | Where-Object { $_ -and $_ -notmatch "Name\s+Id\s+Version" -and $_.Trim() }
        
        if ($apps) {
            Write-LogEntry -Message "Found $($apps.Count) app(s) matching '$Pattern'" -Component 'WinGet'
            
            # Try uninstalling by pattern
            Write-LogEntry -Message "Attempting uninstall for pattern: $Pattern" -Component 'WinGet'
            
            $arguments = @('uninstall', '--name', $Pattern, '--silent', '--accept-source-agreements')
            if ($Force) {
                $arguments += '--force'
            }
            
            $result = & winget @arguments 2>&1
            
            if ($LASTEXITCODE -eq 0) {
                Write-LogEntry -Message "Successfully removed apps matching: $Pattern" -Component 'WinGet'
                return @{
                    Success = $true
                    Message = "Uninstallation successful"
                    AppsFound = $apps.Count
                }
            } else {
                Write-LogEntry -Message "Uninstall failed for: $Pattern (Exit code: $LASTEXITCODE)" -Level 'Warning' -Component 'WinGet'
                return @{
                    Success = $false
                    Message = "Uninstallation failed"
                    ExitCode = $LASTEXITCODE
                    Output = $result
                    AppsFound = $apps.Count
                }
            }
        } else {
            Write-LogEntry -Message "No apps found matching: $Pattern" -Component 'WinGet'
            return @{
                Success = $true
                Message = "No matching apps found"
                AppsFound = 0
            }
        }
    }
    catch {
        Write-LogEntry -Message "Error processing $Pattern`: $($_.Exception.Message)" -Level 'Error' -Component 'WinGet'
        return @{
            Success = $false
            Message = $_.Exception.Message
            AppsFound = 0
        }
    }
}

function Get-StandardApplications {
    <#
    .SYNOPSIS
    Returns the standard set of applications to install
    #>
    return @(
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
}

# Export functions
Export-ModuleMember -Function Test-WinGet, Initialize-WinGetSources, Install-WinGetApplication, Install-WinGetApplications, Uninstall-WinGetApplication, Get-StandardApplications
