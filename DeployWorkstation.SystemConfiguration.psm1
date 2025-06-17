# DeployWorkstation.SystemConfiguration.psm1
# System configuration and registry modifications

# Import logging if available
if (Get-Module DeployWorkstation.Logging -ListAvailable) {
    Import-Module DeployWorkstation.Logging
}

function Set-TelemetryConfiguration {
    <#
    .SYNOPSIS
    Configures Windows telemetry settings
    
    .PARAMETER DisableTelemetry
    Whether to disable telemetry (default: true)
    
    .OUTPUTS
    Boolean indicating success
    #>
    param(
        [bool]$DisableTelemetry = $true
    )
    
    if (Get-Command Write-LogEntry -ErrorAction SilentlyContinue) {
        $action = if ($DisableTelemetry) { "Disabling" } else { "Enabling" }
        Write-LogEntry -Message "$action Windows telemetry..." -Level 'Info' -Component 'SystemConfig'
    }
    
    try {
        $telemetryPath = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\DataCollection'
        
        if (-not (Test-Path $telemetryPath)) {
            New-Item -Path $telemetryPath -Force | Out-Null
        }
        
        $telemetryValue = if ($DisableTelemetry) { 0 } else { 1 }
        Set-ItemProperty -Path $telemetryPath -Name 'AllowTelemetry' -Value $telemetryValue -Type DWord -Force
        
        if (Get-Command Write-LogEntry -ErrorAction SilentlyContinue) {
            Write-LogEntry -Message "Telemetry configuration completed" -Level 'Info' -Component 'SystemConfig'
        }
        
        return $true
    }
    catch {
        if (Get-Command Write-LogEntry -ErrorAction SilentlyContinue) {
            Write-LogEntry -Message "Error configuring telemetry: $($_.Exception.Message)" -Level 'Error' -Component 'SystemConfig'
        }
        return $false
    }
}

function Set-ErrorReportingConfiguration {
    <#
    .SYNOPSIS
    Configures Windows Error Reporting settings
    
    .PARAMETER DisableErrorReporting
    Whether to disable error reporting (default: true)
    
    .OUTPUTS
    Boolean indicating success
    #>
    param(
        [bool]$DisableErrorReporting = $true
    )
    
    if (Get-Command Write-LogEntry -ErrorAction SilentlyContinue) {
        $action = if ($DisableErrorReporting) { "Disabling" } else { "Enabling" }
        Write-LogEntry -Message "$action Windows Error Reporting..." -Level 'Info' -Component 'SystemConfig'
    }
    
    try {
        $werPath = 'HKLM:\SOFTWARE\Microsoft\Windows\Windows Error Reporting'
        
        if (Test-Path $werPath) {
            $disabledValue = if ($DisableErrorReporting) { 1 } else { 0 }
            Set-ItemProperty -Path $werPath -Name 'Disabled' -Value $disabledValue -Type DWord -Force
            
            if (Get-Command Write-LogEntry -ErrorAction SilentlyContinue) {
                Write-LogEntry -Message "Error reporting configuration completed" -Level 'Info' -Component 'SystemConfig'
            }
            
            return $true
        } else {
            if (Get-Command Write-LogEntry -ErrorAction SilentlyContinue) {
                Write-LogEntry -Message "Windows Error Reporting registry path not found" -Level 'Warning' -Component 'SystemConfig'
            }
            return $false
        }
    }
    catch {
        if (Get-Command Write-LogEntry -ErrorAction SilentlyContinue) {
            Write-LogEntry -Message "Error configuring error reporting: $($_.Exception.Message)" -Level 'Error' -Component 'SystemConfig'
        }
        return $false
    }
}

function Set-CustomerExperienceConfiguration {
    <#
    .SYNOPSIS
    Configures Customer Experience Improvement Program settings
    
    .PARAMETER DisableCEIP
    Whether to disable CEIP (default: true)
    
    .OUTPUTS
    Boolean indicating success
    #>
    param(
        [bool]$DisableCEIP = $true
    )
    
    if (Get-Command Write-LogEntry -ErrorAction SilentlyContinue) {
        $action = if ($DisableCEIP) { "Disabling" } else { "Enabling" }
        Write-LogEntry -Message "$action Customer Experience Improvement Program..." -Level 'Info' -Component 'SystemConfig'
    }
    
    try {
        $ceipPath = 'HKLM:\SOFTWARE\Microsoft\SQMClient\Windows'
        
        if (Test-Path $ceipPath) {
            $ceipValue = if ($DisableCEIP) { 0 } else { 1 }
            Set-ItemProperty -Path $ceipPath -Name 'CEIPEnable' -Value $ceipValue -Type DWord -Force
            
            if (Get-Command Write-LogEntry -ErrorAction SilentlyContinue) {
                Write-LogEntry -Message "CEIP configuration completed" -Level 'Info' -Component 'SystemConfig'
            }
            
            return $true
        } else {
            if (Get-Command Write-LogEntry -ErrorAction SilentlyContinue) {
                Write-LogEntry -Message "CEIP registry path not found" -Level 'Info' -Component 'SystemConfig'
            }
            return $true # Not an error if path doesn't exist
        }
    }
    catch {
        if (Get-Command Write-LogEntry -ErrorAction SilentlyContinue) {
            Write-LogEntry -Message "Error configuring CEIP: $($_.Exception.Message)" -Level 'Error' -Component 'SystemConfig'
        }
        return $false
    }
}

function Set-ExecutionPolicyConfiguration {
    <#
    .SYNOPSIS
    Sets PowerShell execution policy for the current process
    
    .PARAMETER ExecutionPolicy
    The execution policy to set (default: Bypass)
    
    .OUTPUTS
    Boolean indicating success
    #>
    param(
        [Microsoft.PowerShell.ExecutionPolicy]$ExecutionPolicy = 'Bypass'
    )
    
    if (Get-Command Write-LogEntry -ErrorAction SilentlyContinue) {
        Write-LogEntry -Message "Setting execution policy to: $ExecutionPolicy" -Level 'Info' -Component 'SystemConfig'
    }
    
    try {
        Set-ExecutionPolicy -Scope Process -ExecutionPolicy $ExecutionPolicy -Force
        
        if (Get-Command Write-LogEntry -ErrorAction SilentlyContinue) {
            Write-LogEntry -Message "Execution policy set successfully" -Level 'Info' -Component 'SystemConfig'
        }
        
        return $true
    }
    catch {
        if (Get-Command Write-LogEntry -ErrorAction SilentlyContinue) {
            Write-LogEntry -Message "Error setting execution policy: $($_.Exception.Message)" -Level 'Error' -Component 'SystemConfig'
        }
        return $false
    }
}

function Test-PowerShellVersion {
    <#
    .SYNOPSIS
    Tests if we're running the correct PowerShell version and edition
    
    .PARAMETER RequireDesktop
    Whether Windows PowerShell Desktop is required (default: true)
    
    .OUTPUTS
    Hashtable with version information and compatibility status
    #>
    param(
        [bool]$RequireDesktop = $true
    )
    
    $versionInfo = @{
        Version = $PSVersionTable.PSVersion
        Edition = $PSVersionTable.PSEdition
        IsDesktop = $PSVersionTable.PSEdition -eq 'Desktop'
        IsCompatible = $true
        Message = ""
    }
    
    if ($RequireDesktop -and $PSVersionTable.PSEdition -eq 'Core') {
        $versionInfo.IsCompatible = $false
        $versionInfo.Message = "PowerShell Core detected. Windows PowerShell Desktop required for Appx cmdlets."
        
        if (Get-Command Write-LogEntry -ErrorAction SilentlyContinue) {
            Write-LogEntry -Message $versionInfo.Message -Level 'Warning' -Component 'SystemConfig'
        }
    }
    
    if (Get-Command Write-LogEntry -ErrorAction SilentlyContinue) {
        Write-LogEntry -Message "PowerShell Version: $($versionInfo.Version), Edition: $($versionInfo.Edition)" -Level 'Info' -Component 'SystemConfig'
    }
    
    return $versionInfo
}

function Restart-InDesktopPowerShell {
    <#
    .SYNOPSIS
    Restarts the current script in Windows PowerShell Desktop
    
    .PARAMETER ScriptPath
    Path to the script to restart
    
    .PARAMETER Parameters
    Additional parameters to pass to the restarted script
    
    .OUTPUTS
    Does not return - exits current process
    #>
    param(
        [Parameter(Mandatory)]
        [string]$ScriptPath,
        
        [hashtable]$Parameters = @{}
    )
    
    if (Get-Command Write-LogEntry -ErrorAction SilentlyContinue) {
        Write-LogEntry -Message "Restarting in Windows PowerShell Desktop..." -Level 'Info' -Component 'SystemConfig'
    }
    
    $params = @(
        '-NoProfile',
        '-ExecutionPolicy', 'Bypass',
        '-File', $ScriptPath
    )
    
    # Add parameters
    foreach ($key in $Parameters.Keys) {
        if ($Parameters[$key] -is [switch] -and $Parameters[$key]) {
            $params += "-$key"
        } elseif ($Parameters[$key] -isnot [switch]) {
            $params += "-$key"
            $params += $Parameters[$key]
        }
    }
    
    Start-Process -FilePath 'powershell.exe' -ArgumentList $params -Verb RunAs
    exit
}

function Get-SystemInformation {
    <#
    .SYNOPSIS
    Retrieves basic system information for logging
    
    .OUTPUTS
    Hashtable with system information
    #>
    try {
        $osInfo = Get-CimInstance Win32_OperatingSystem -ErrorAction SilentlyContinue
        
        $systemInfo = @{
            OSCaption = if ($osInfo) { $osInfo.Caption } else { "Unknown" }
            OSVersion = if ($osInfo) { $osInfo.Version } else { "Unknown" }
            OSBuild = if ($osInfo) { $osInfo.BuildNumber } else { "Unknown" }
            Architecture = $env:PROCESSOR_ARCHITECTURE
            PowerShellVersion = $PSVersionTable.PSVersion.ToString()
            PowerShellEdition = $PSVersionTable.PSEdition
            IsAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")
        }
        
        if (Get-Command Write-LogEntry -ErrorAction SilentlyContinue) {
            Write-LogEntry -Message "OS: $($systemInfo.OSCaption)" -Level 'Info' -Component 'SystemConfig'
            Write-LogEntry -Message "PowerShell: $($systemInfo.PowerShellVersion) ($($systemInfo.PowerShellEdition))" -Level 'Info' -Component 'SystemConfig'
            Write-LogEntry -Message "Running as Administrator: $($systemInfo.IsAdmin)" -Level 'Info' -Component 'SystemConfig'
        }
        
        return $systemInfo
    }
    catch {
        if (Get-Command Write-LogEntry -ErrorAction SilentlyContinue) {
            Write-LogEntry -Message "Error retrieving system information: $($_.Exception.Message)" -Level 'Error' -Component 'SystemConfig'
        }
        return @{}
    }
}

function Set-AllSystemConfigurations {
    <#
    .SYNOPSIS
    Applies all standard system configurations
    
    .PARAMETER ConfigOptions
    Hashtable of configuration options to override defaults
    
    .OUTPUTS
    Hashtable with results of each configuration
    #>
    param(
        [hashtable]$ConfigOptions = @{}
    )
    
    if (Get-Command Write-LogEntry -ErrorAction SilentlyContinue) {
        Write-LogEntry -Message "Configuring system settings..." -Level 'Info' -Component 'SystemConfig'
    }
    
    # Default configuration options
    $defaultOptions = @{
        DisableTelemetry = $true
        DisableErrorReporting = $true
        DisableCEIP = $true
        SetExecutionPolicy = $true
        ExecutionPolicy = 'Bypass'
    }
    
    # Merge with provided options
    foreach ($key in $ConfigOptions.Keys) {
        $defaultOptions[$key] = $ConfigOptions[$key]
    }
    
    $results = @{
        Telemetry = $false
        ErrorReporting = $false
        CEIP = $false
        ExecutionPolicy = $false
        OverallSuccess = $false
    }
    
    # Apply configurations
    if ($defaultOptions.DisableTelemetry) {
        $results.Telemetry = Set-TelemetryConfiguration -DisableTelemetry $defaultOptions.DisableTelemetry
    }
    
    if ($defaultOptions.DisableErrorReporting) {
        $results.ErrorReporting = Set-ErrorReportingConfiguration -DisableErrorReporting $defaultOptions.DisableErrorReporting
    }
    
    if ($defaultOptions.DisableCEIP) {
        $results.CEIP = Set-CustomerExperienceConfiguration -DisableCEIP $defaultOptions.DisableCEIP
    }
    
    if ($defaultOptions.SetExecutionPolicy) {
        $results.ExecutionPolicy = Set-ExecutionPolicyConfiguration -ExecutionPolicy $defaultOptions.ExecutionPolicy
    }
    
    # Determine overall success
    $results.OverallSuccess = $results.Telemetry -and $results.ErrorReporting -and $results.CEIP -and $results.ExecutionPolicy
    
    if (Get-Command Write-LogEntry -ErrorAction SilentlyContinue) {
        $status = if ($results.OverallSuccess) { "completed successfully" } else { "completed with some failures" }
        Write-LogEntry -Message "System configuration $status" -Level 'Info' -Component 'SystemConfig'
    }
    
    return $results
}

# Export functions
Export-ModuleMember -Function @(
    'Set-TelemetryConfiguration',
    'Set-ErrorReportingConfiguration', 
    'Set-CustomerExperienceConfiguration',
    'Set-ExecutionPolicyConfiguration',
    'Test-PowerShellVersion',
    'Restart-InDesktopPowerShell',
    'Get-SystemInformation',
    'Set-AllSystemConfigurations'
)
