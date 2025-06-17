# DeployWorkstation.UWPCleanup.psm1
# UWP/Appx package cleanup functionality

using module .\DeployWorkstation.Logging.psm1

function Get-DefaultBloatwarePackages {
    <#
    .SYNOPSIS
    Returns the default list of UWP packages to remove
    #>
    return @(
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
        '*Microsoft.Teams*',
        '*Microsoft.GetHelp*',
        '*Microsoft.Getstarted*',
        '*Microsoft.ZuneMusic*',
        '*Microsoft.ZuneVideo*',
        '*Microsoft.BingNews*',
        '*Microsoft.BingWeather*',
        '*Microsoft.BingFinance*',
        '*Microsoft.BingSports*',
        '*Microsoft.People*',
        '*Microsoft.Messaging*',
        '*Microsoft.Microsoft3DViewer*',
        '*Microsoft.MicrosoftSolitaireCollection*',
        '*Microsoft.MicrosoftStickyNotes*',
        '*Microsoft.Office.OneNote*',
        '*Microsoft.WindowsFeedbackHub*',
        '*Microsoft.WindowsMaps*',
        '*Microsoft.WindowsSoundRecorder*',
        '*Microsoft.YourPhone*'
    )
}

function Remove-AppxPackage {
    <#
    .SYNOPSIS
    Removes a specific UWP/Appx package pattern
    
    .PARAMETER PackagePattern
    The package name pattern to remove (supports wildcards)
    
    .PARAMETER RemoveForAllUsers
    Whether to remove for all users (default: true)
    
    .PARAMETER RemoveProvisioned
    Whether to remove provisioned packages (default: true)
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$PackagePattern,
        
        [bool]$RemoveForAllUsers = $true,
        
        [bool]$RemoveProvisioned = $true
    )
    
    Write-LogEntry -Message "Processing Appx package: $PackagePattern" -Component 'UWPCleanup'
    
    $results = @{
        PackagePattern = $PackagePattern
        UserPackagesRemoved = 0
        ProvisionedPackagesRemoved = 0
        Errors = @()
    }
    
    try {
        # Remove for all users
        if ($RemoveForAllUsers) {
            $packages = Get-AppxPackage -AllUsers -Name $PackagePattern -ErrorAction SilentlyContinue
            
            foreach ($package in $packages) {
                try {
                    Write-LogEntry -Message "Removing user package: $($package.Name) (Version: $($package.Version))" -Component 'UWPCleanup'
                    Remove-AppxPackage -Package $package.PackageFullName -AllUsers -ErrorAction Stop
                    $results.UserPackagesRemoved++
                    Write-LogEntry -Message "Successfully removed user package: $($package.Name)" -Component 'UWPCleanup'
                }
                catch {
                    $errorMsg = "Failed to remove user package $($package.Name): $($_.Exception.Message)"
                    Write-LogEntry -Message $errorMsg -Level 'Warning' -Component 'UWPCleanup'
                    $results.Errors += $errorMsg
                }
            }
        }
        
        # Remove provisioned packages
        if ($RemoveProvisioned) {
            $provisionedPackages = Get-AppxProvisionedPackage -Online -ErrorAction SilentlyContinue |
                                 Where-Object { $_.DisplayName -like $PackagePattern }
            
            foreach ($package in $provisionedPackages) {
                try {
                    Write-LogEntry -Message "Removing provisioned package: $($package.DisplayName) (Version: $($package.Version))" -Component 'UWPCleanup'
                    Remove-AppxProvisionedPackage -Online -PackageName $package.PackageName -ErrorAction Stop
                    $results.ProvisionedPackagesRemoved++
                    Write-LogEntry -Message "Successfully removed provisioned package: $($package.DisplayName)" -Component 'UWPCleanup'
                }
                catch {
                    $errorMsg = "Failed to remove provisioned package $($package.DisplayName): $($_.Exception.Message)"
                    Write-LogEntry -Message $errorMsg -Level 'Warning' -Component 'UWPCleanup'
                    $results.Errors += $errorMsg
                }
            }
        }
        
        # Log summary
        if ($results.UserPackagesRemoved -gt 0 -or $results.ProvisionedPackagesRemoved -gt 0) {
            Write-LogEntry -Message "Package cleanup summary for $PackagePattern`: $($results.UserPackagesRemoved) user packages, $($results.ProvisionedPackagesRemoved) provisioned packages removed" -Component 'UWPCleanup'
        } else {
            Write-LogEntry -Message "No packages found matching: $PackagePattern" -Component 'UWPCleanup'
        }
        
        return $results
    }
    catch {
        $errorMsg = "Error processing package pattern $PackagePattern`: $($_.Exception.Message)"
        Write-LogEntry -Message $errorMsg -Level 'Error' -Component 'UWPCleanup'
        $results.Errors += $errorMsg
        return $results
    }
}

function Remove-AppxPackages {
    <#
    .SYNOPSIS
    Removes multiple UWP/Appx packages
    
    .PARAMETER PackagePatterns
    Array of package patterns to remove. If not specified, uses default bloatware list
    
    .PARAMETER RemoveForAllUsers
    Whether to remove for all users (default: true)
    
    .PARAMETER RemoveProvisioned
    Whether to remove provisioned packages (default: true)
    #>
    [CmdletBinding()]
    param(
        [string[]]$PackagePatterns,
        
        [bool]$RemoveForAllUsers = $true,
        
        [bool]$RemoveProvisioned = $true
    )
    
    if (-not $PackagePatterns) {
        $PackagePatterns = Get-DefaultBloatwarePackages
    }
    
    Write-LogEntry -Message "Removing UWP/Appx packages. Processing $($PackagePatterns.Count) patterns..." -Component 'UWPCleanup'
    
    $overallResults = @{
        TotalPatterns = $PackagePatterns.Count
        TotalUserPackagesRemoved = 0
        TotalProvisionedPackagesRemoved = 0
        TotalErrors = 0
        DetailedResults = @()
    }
    
    foreach ($pattern in $PackagePatterns) {
        $result = Remove-AppxPackage -PackagePattern $pattern -RemoveForAllUsers $RemoveForAllUsers -RemoveProvisioned $RemoveProvisioned
        
        $overallResults.TotalUserPackagesRemoved += $result.UserPackagesRemoved
        $overallResults.TotalProvisionedPackagesRemoved += $result.ProvisionedPackagesRemoved
        $overallResults.TotalErrors += $result.Errors.Count
        $overallResults.DetailedResults += $result
    }
    
    Write-LogEntry -Message "UWP cleanup complete. Removed $($overallResults.TotalUserPackagesRemoved) user packages and $($overallResults.TotalProvisionedPackagesRemoved) provisioned packages. $($overallResults.TotalErrors) errors encountered." -Component 'UWPCleanup'
    
    return $overallResults
}

function Remove-WindowsCapabilities {
    <#
    .SYNOPSIS
    Removes Windows optional features/capabilities
    
    .PARAMETER Capabilities
    Array of capability names to remove. If not specified, uses default list
    #>
    [CmdletBinding()]
    param(
        [string[]]$Capabilities
    )
    
    if (-not $Capabilities) {
        $Capabilities = @(
            'App.Support.QuickAssist~~~~0.0.1.0',
            'App.Xbox.TCUI~~~~0.0.1.0',
            'App.XboxGameOverlay~~~~0.0.1.0',
            'App.XboxSpeechToTextOverlay~~~~0.0.1.0',
            'OpenSSH.Client~~~~0.0.1.0',
            'Media.WindowsMediaPlayer~~~~0.0.12.0',
            'Browser.InternetExplorer~~~~0.0.11.0',
            'MathRecognizer~~~~0.0.1.0'
        )
    }
    
    Write-LogEntry -Message "Removing Windows optional features..." -Component 'UWPCleanup'
    
    $results = @{
        Total = $Capabilities.Count
        Removed = 0
        NotInstalled = 0
        Errors = 0
        Details = @()
    }
    
    foreach ($capability in $Capabilities) {
        try {
            Write-LogEntry -Message "Checking capability: $capability" -Component 'UWPCleanup'
            $state = Get-WindowsCapability -Online -Name $capability -ErrorAction SilentlyContinue
            
            if ($state -and $state.State -eq 'Installed') {
                Write-LogEntry -Message "Removing capability: $capability" -Component 'UWPCleanup'
                $removeResult = Remove-WindowsCapability -Online -Name $capability -ErrorAction Stop
                
                if ($removeResult.RestartNeeded) {
                    Write-LogEntry -Message "Capability $capability removed successfully (restart required)" -Component 'UWPCleanup'
                } else {
                    Write-LogEntry -Message "Capability $capability removed successfully" -Component 'UWPCleanup'
                }
                
                $results.Removed++
                $results.Details += @{
                    Capability = $capability
                    Action = 'Removed'
                    RestartNeeded = $removeResult.RestartNeeded
                }
            } else {
                Write-LogEntry -Message "Capability not installed: $capability" -Component 'UWPCleanup'
                $results.NotInstalled++
                $results.Details += @{
                    Capability = $capability
                    Action = 'NotInstalled'
                }
            }
        }
        catch {
            Write-LogEntry -Message "Error processing capability $capability`: $($_.Exception.Message)" -Level 'Warning' -Component 'UWPCleanup'
            $results.Errors++
            $results.Details += @{
                Capability = $capability
                Action = 'Error'
                Error = $_.Exception.Message
            }
        }
    }
    
    Write-LogEntry -Message "Windows capabilities cleanup complete: $($results.Removed) removed, $($results.NotInstalled) not installed, $($results.Errors) errors" -Component 'UWPCleanup'
    
    return $results
}

function Get-AppxPackageReport {
    <#
    .SYNOPSIS
    Generates a report of currently installed UWP packages
    
    .PARAMETER IncludeProvisioned
    Whether to include provisioned packages in the report
    #>
    [CmdletBinding()]
    param(
        [bool]$IncludeProvisioned = $true
    )
    
    Write-LogEntry -Message "Generating UWP package report..." -Component 'UWPCleanup'
    
    $report = @{
        UserPackages = @()
        ProvisionedPackages = @()
        Timestamp = Get-Date
    }
    
    try {
        # Get user packages
        $userPackages = Get-AppxPackage -AllUsers -ErrorAction SilentlyContinue
        foreach ($package in $userPackages) {
            $report.UserPackages += @{
                Name = $package.Name
                Version = $package.Version
                Architecture = $package.Architecture
                Publisher = $package.Publisher
                PackageFullName = $package.PackageFullName
            }
        }
        
        # Get provisioned packages
        if ($IncludeProvisioned) {
            $provisionedPackages = Get-AppxProvisionedPackage -Online -ErrorAction SilentlyContinue
            foreach ($package in $provisionedPackages) {
                $report.ProvisionedPackages += @{
                    DisplayName = $package.DisplayName
                    Version = $package.Version
                    Architecture = $package.Architecture
                    PackageName = $package.PackageName
                }
            }
        }
        
        Write-LogEntry -Message "UWP package report generated: $($report.UserPackages.Count) user packages, $($report.ProvisionedPackages.Count) provisioned packages" -Component 'UWPCleanup'
        
        return $report
    }
    catch {
        Write-LogEntry -Message "Error generating UWP package report: $($_.Exception.Message)" -Level 'Error' -Component 'UWPCleanup'
        return $null
    }
}

# Export functions
Export-ModuleMember -Function Get-DefaultBloatwarePackages, Remove-AppxPackage, Remove-AppxPackages, Remove-WindowsCapabilities, Get-AppxPackageReport
