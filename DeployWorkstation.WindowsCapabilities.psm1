# DeployWorkstation.WindowsCapabilities.psm1
# Windows Optional Features and Capabilities Management

#Requires -Version 5.1
#Requires -RunAsAdministrator

# ================================
# Windows Capabilities Management
# ================================

function Remove-UnwantedWindowsCapabilities {
    <#
    .SYNOPSIS
        Removes unwanted Windows optional features/capabilities
    .PARAMETER CapabilityNames
        Array of capability names to remove
    .PARAMETER Force
        Force removal without confirmation
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [string[]]$CapabilityNames = @(
            'App.Support.QuickAssist~~~~0.0.1.0',
            'App.Xbox.TCUI~~~~0.0.1.0',
            'App.XboxGameOverlay~~~~0.0.1.0',
            'App.XboxSpeechToTextOverlay~~~~0.0.1.0',
            'Browser.InternetExplorer~~~~0.0.11.0',
            'MathRecognizer~~~~0.0.1.0',
            'Media.WindowsMediaPlayer~~~~0.0.12.0',
            'Microsoft.Windows.MSPaint~~~~0.0.1.0',
            'Microsoft.Windows.PowerShell.ISE~~~~0.0.1.0',
            'Microsoft.Windows.WordPad~~~~0.0.1.0',
            'OpenSSH.Client~~~~0.0.1.0',
            'Print.Fax.Scan~~~~0.0.1.0'
        ),
        
        [switch]$Force
    )
    
    Write-Host "Managing Windows Capabilities..." -ForegroundColor Yellow
    
    $results = @{
        ProcessedCapabilities = 0
        RemovedCapabilities = 0
        NotInstalledCapabilities = 0
        FailedRemovals = 0
        Details = @()
    }
    
    foreach ($capabilityName in $CapabilityNames) {
        Write-Host "Checking capability: $capabilityName" -ForegroundColor Cyan
        $results.ProcessedCapabilities++
        
        try {
            $capability = Get-WindowsCapability -Online -Name $capabilityName -ErrorAction SilentlyContinue
            
            if (-not $capability) {
                Write-Host "  Capability not found: $capabilityName" -ForegroundColor Gray
                $results.Details += @{
                    Name = $capabilityName
                    State = 'NotFound'
                    Action = 'Skipped'
                }
                continue
            }
            
            if ($capability.State -eq 'NotPresent') {
                Write-Host "  Already removed: $capabilityName" -ForegroundColor Green
                $results.NotInstalledCapabilities++
                $results.Details += @{
                    Name = $capabilityName
                    State = 'NotPresent'
                    Action = 'AlreadyRemoved'
                }
            }
            elseif ($capability.State -eq 'Installed') {
                if ($Force -or $PSCmdlet.ShouldProcess($capabilityName, "Remove Windows Capability")) {
                    try {
                        Write-Host "  Removing: $capabilityName" -ForegroundColor Yellow
                        Remove-WindowsCapability -Online -Name $capabilityName -ErrorAction Stop | Out-Null
                        
                        Write-Host "  Successfully removed: $capabilityName" -ForegroundColor Green
                        $results.RemovedCapabilities++
                        $results.Details += @{
                            Name = $capabilityName
                            State = 'Installed'
                            Action = 'Removed'
                        }
                    }
                    catch {
                        Write-Warning "Failed to remove $capabilityName`: $($_.Exception.Message)"
                        $results.FailedRemovals++
                        $results.Details += @{
                            Name = $capabilityName
                            State = 'Installed'
                            Action = 'Failed'
                            Error = $_.Exception.Message
                        }
                    }
                }
            }
            else {
                Write-Host "  Capability state: $($capability.State)" -ForegroundColor Gray
                $results.Details += @{
                    Name = $capabilityName
                    State = $capability.State
                    Action = 'Skipped'
                }
            }
        }
        catch {
            Write-Warning "Error processing $capabilityName`: $($_.Exception.Message)"
            $results.FailedRemovals++
            $results.Details += @{
                Name = $capabilityName
                State = 'Unknown'
                Action = 'Error'
                Error = $_.Exception.Message
            }
        }
    }
    
    Write-Host "`nWindows Capabilities Summary:" -ForegroundColor Cyan
    Write-Host "  Processed: $($results.ProcessedCapabilities)" -ForegroundColor White
    Write-Host "  Removed: $($results.RemovedCapabilities)" -ForegroundColor Green
    Write-Host "  Already Removed: $($results.NotInstalledCapabilities)" -ForegroundColor Yellow
    Write-Host "  Failed: $($results.FailedRemovals)" -ForegroundColor Red
    
    return $results
}

function Get-WindowsCapabilitiesStatus {
    <#
    .SYNOPSIS
        Gets the status of Windows capabilities
    .PARAMETER CapabilityNames
        Specific capabilities to check, or all if not specified
    .PARAMETER ShowOnlyInstalled
        Show only installed capabilities
    #>
    [CmdletBinding()]
    param(
        [string[]]$CapabilityNames,
        
        [switch]$ShowOnlyInstalled
    )
    
    Write-Host "Getting Windows Capabilities status..." -ForegroundColor Yellow
    
    try {
        if ($CapabilityNames) {
            $capabilities = @()
            foreach ($name in $CapabilityNames) {
                $cap = Get-WindowsCapability -Online -Name $name -ErrorAction SilentlyContinue
                if ($cap) { $capabilities += $cap }
            }
        }
        else {
            Write-Host "Getting all Windows capabilities (this may take a moment)..." -ForegroundColor Gray
            $capabilities = Get-WindowsCapability -Online -ErrorAction Stop
        }
        
        if ($ShowOnlyInstalled) {
            $capabilities = $capabilities | Where-Object { $_.State -eq 'Installed' }
        }
        
        $results = $capabilities | Select-Object Name, State, Description | Sort-Object Name
        
        Write-Host "`nFound $($results.Count) capabilities" -ForegroundColor Cyan
        return $results
    }
    catch {
        Write-Error "Failed to get Windows capabilities: $($_.Exception.Message)"
        return @()
    }
}

function Enable-WindowsCapability {
    <#
    .SYNOPSIS
        Enables a Windows capability
    .PARAMETER CapabilityName
        Name of the capability to enable
    .PARAMETER Source
        Source path for the capability files
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory)]
        [string]$CapabilityName,
        
        [string]$Source
    )
    
    Write-Host "Enabling Windows Capability: $CapabilityName" -ForegroundColor Yellow
    
    try {
        $capability = Get-WindowsCapability -Online -Name $CapabilityName -ErrorAction Stop
        
        if ($capability.State -eq 'Installed') {
            Write-Host "Capability already installed: $CapabilityName" -ForegroundColor Green
            return @{
                Success = $true
                AlreadyInstalled = $true
                Name = $CapabilityName
            }
        }
        
        if ($PSCmdlet.ShouldProcess($CapabilityName, "Enable Windows Capability")) {
            $params = @{
                Online = $true
                Name = $CapabilityName
                ErrorAction = 'Stop'
            }
            
            if ($Source) {
                $params.Source = $Source
            }
            
            $result = Add-WindowsCapability @params
            
            Write-Host "Successfully enabled: $CapabilityName" -ForegroundColor Green
            return @{
                Success = $true
                AlreadyInstalled = $false
                Name = $CapabilityName
                Result = $result
            }
        }
    }
    catch {
        Write-Error "Failed to enable $CapabilityName`: $($_.Exception.Message)"
        return @{
            Success = $false
            Name = $CapabilityName
            Error = $_.Exception.Message
        }
    }
}

function Remove-WindowsOptionalFeatures {
    <#
    .SYNOPSIS
        Removes Windows optional features
    .PARAMETER FeatureNames
        Array of feature names to remove
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [string[]]$FeatureNames = @(
            'Internet-Explorer-Optional-amd64',
            'MediaPlayback',
            'WindowsMediaPlayer',
            'WorkFolders-Client',
            'Printing-XPSServices-Features',
            'FaxServicesClientPackage'
        )
    )
    
    Write-Host "Managing Windows Optional Features..." -ForegroundColor Yellow
    
    $results = @{
        ProcessedFeatures = 0
        RemovedFeatures = 0
        NotInstalledFeatures = 0
        FailedRemovals = 0
        Details = @()
    }
    
    foreach ($featureName in $FeatureNames) {
        Write-Host "Checking feature: $featureName" -ForegroundColor Cyan
        $results.ProcessedFeatures++
        
        try {
            $feature = Get-WindowsOptionalFeature -Online -FeatureName $featureName -ErrorAction SilentlyContinue
            
            if (-not $feature) {
                Write-Host "  Feature not found: $featureName" -ForegroundColor Gray
                $results.Details += @{
                    Name = $featureName
                    State = 'NotFound'
                    Action = 'Skipped'
                }
                continue
            }
            
            if ($feature.State -eq 'Disabled') {
                Write-Host "  Already disabled: $featureName" -ForegroundColor Green
                $results.NotInstalledFeatures++
                $results.Details += @{
                    Name = $featureName
                    State = 'Disabled'
                    Action = 'AlreadyDisabled'
                }
            }
            elseif ($feature.State -eq 'Enabled') {
                if ($PSCmdlet.ShouldProcess($featureName, "Disable Windows Optional Feature")) {
                    try {
                        Write-Host "  Disabling: $featureName" -ForegroundColor Yellow
                        Disable-WindowsOptionalFeature -Online -FeatureName $featureName -NoRestart -ErrorAction Stop | Out-Null
                        
                        Write-Host "  Successfully disabled: $featureName" -ForegroundColor Green
                        $results.RemovedFeatures++
                        $results.Details += @{
                            Name = $featureName
                            State = 'Enabled'
                            Action = 'Disabled'
                        }
                    }
                    catch {
                        Write-Warning "Failed to disable $featureName`: $($_.Exception.Message)"
                        $results.FailedRemovals++
                        $results.Details += @{
                            Name = $featureName
                            State = 'Enabled'
                            Action = 'Failed'
                            Error = $_.Exception.Message
                        }
                    }
                }
            }
        }
        catch {
            Write-Warning "Error processing $featureName`: $($_.Exception.Message)"
            $results.FailedRemovals++
            $results.Details += @{
                Name = $featureName
                State = 'Unknown'
                Action = 'Error'
                Error = $_.Exception.Message
            }
        }
    }
    
    Write-Host "`nWindows Optional Features Summary:" -ForegroundColor Cyan
    Write-Host "  Processed: $($results.ProcessedFeatures)" -ForegroundColor White
    Write-Host "  Disabled: $($results.RemovedFeatures)" -ForegroundColor Green
    Write-Host "  Already Disabled: $($results.NotInstalledFeatures)" -ForegroundColor Yellow
    Write-Host "  Failed: $($results.FailedRemovals)" -ForegroundColor Red
    
    return $results
}

# ================================
# Export Module Members
# ================================

Export-ModuleMember -Function @(
    'Remove-UnwantedWindowsCapabilities',
    'Get-WindowsCapabilitiesStatus',
    'Enable-WindowsCapability',
    'Remove-WindowsOptionalFeatures'
)
