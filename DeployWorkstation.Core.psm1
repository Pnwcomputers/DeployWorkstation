# DeployWorkstation.Core.psm1
# Core utilities and common functions

#Requires -Version 5.1

# Module variables
$Script:ModuleLogPath = $null
$Script:ModuleVerbose = $false

# ================================
# Logging Functions
# ================================

function Initialize-DeployLogging {
    <#
    .SYNOPSIS
        Initializes logging for DeployWorkstation modules
    .PARAMETER LogPath
        Path to the log file
    .PARAMETER Verbose
        Enable verbose logging
    #>
    [CmdletBinding()]
    param(
        [string]$LogPath,
        [switch]$Verbose
    )
    
    if (-not $LogPath) {
        $LogPath = Join-Path $env:TEMP "DeployWorkstation-$(Get-Date -Format 'yyyyMMdd-HHmmss').log"
    }
    
    # Create log directory if needed
    $logDir = Split-Path $LogPath -Parent
    if (-not (Test-Path $logDir)) {
        New-Item -Path $logDir -ItemType Directory -Force | Out-Null
    }
    
    $Script:ModuleLogPath = $LogPath
    $Script:ModuleVerbose = $Verbose.IsPresent
    
    Write-DeployLog "Logging initialized: $LogPath"
    return $LogPath
}

function Write-DeployLog {
    <#
    .SYNOPSIS
        Writes a log entry with timestamp and level
    .PARAMETER Message
        The message to log
    .PARAMETER Level
        Log level (INFO, WARN, ERROR, DEBUG)
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Message,
        
        [ValidateSet('INFO', 'WARN', 'ERROR', 'DEBUG')]
        [string]$Level = 'INFO'
    )
    
    $timestamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
    $logEntry = "[$timestamp] [$Level] $Message"
    
    # Console output with color
    $color = switch ($Level) {
        'ERROR' { 'Red' }
        'WARN'  { 'Yellow' }
        'DEBUG' { 'Gray' }
        default { 'White' }
    }
    
    Write-Host $logEntry -ForegroundColor $color
    
    # File output
    if ($Script:ModuleLogPath) {
        try {
            Add-Content -Path $Script:ModuleLogPath -Value $logEntry -Encoding UTF8 -ErrorAction SilentlyContinue
        }
        catch {
            Write-Warning "Failed to write to log file: $_"
        }
    }
}

# ================================
# Environment Validation
# ================================

function Test-DeployEnvironment {
    <#
    .SYNOPSIS
        Validates the deployment environment
    .DESCRIPTION
        Checks PowerShell version, admin rights, and Windows version
    #>
    [CmdletBinding()]
    param()
    
    $results = @{
        IsValid = $true
        Issues = @()
        Info = @{}
    }
    
    # Check PowerShell version
    if ($PSVersionTable.PSVersion.Major -lt 5) {
        $results.IsValid = $false
        $results.Issues += "PowerShell 5.1 or higher required. Current: $($PSVersionTable.PSVersion)"
    }
    
    # Check if running as administrator
    $currentPrincipal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
    $isAdmin = $currentPrincipal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
    
    if (-not $isAdmin) {
        $results.IsValid = $false
        $results.Issues += "Script must be run as Administrator"
    }
    
    # Check Windows version
    try {
        $osInfo = Get-CimInstance Win32_OperatingSystem -ErrorAction Stop
        $results.Info.OSVersion = $osInfo.Caption
        $results.Info.OSBuild = $osInfo.BuildNumber
        
        # Ensure Windows 10/11
        if ($osInfo.BuildNumber -lt 10240) {
            $results.IsValid = $false
            $results.Issues += "Windows 10 or higher required"
        }
    }
    catch {
        $results.Issues += "Could not determine OS version: $($_.Exception.Message)"
    }
    
    # Check PowerShell edition for Appx cmdlets
    if ($PSVersionTable.PSEdition -eq 'Core') {
        $results.Issues += "Windows PowerShell Desktop required for Appx operations"
    }
    
    $results.Info.PSVersion = $PSVersionTable.PSVersion.ToString()
    $results.Info.PSEdition = $PSVersionTable.PSEdition
    $results.Info.IsAdmin = $isAdmin
    
    return $results
}

function Switch-ToPowerShellDesktop {
    <#
    .SYNOPSIS
        Switches from PowerShell Core to Windows PowerShell Desktop
    .PARAMETER ScriptPath
        Path to the script to restart
    .PARAMETER Parameters
        Parameters to pass to the restarted script
    #>
    [CmdletBinding()]
    param(
        [string]$ScriptPath,
        [hashtable]$Parameters = @{}
    )
    
    if ($PSVersionTable.PSEdition -ne 'Core') {
        Write-DeployLog "Already running Windows PowerShell Desktop" -Level 'DEBUG'
        return $false
    }
    
    Write-DeployLog "PowerShell Core detected. Restarting in Windows PowerShell Desktop..." -Level 'WARN'
    
    $params = @('-NoProfile', '-ExecutionPolicy', 'Bypass')
    
    if ($ScriptPath) {
        $params += @('-File', $ScriptPath)
        
        # Add parameters
        foreach ($key in $Parameters.Keys) {
            if ($Parameters[$key] -is [switch] -and $Parameters[$key]) {
                $params += "-$key"
            }
            elseif ($Parameters[$key]) {
                $params += @("-$key", $Parameters[$key])
            }
        }
    }
    
    try {
        Start-Process -FilePath 'powershell.exe' -ArgumentList $params -Verb RunAs -Wait
        return $true
    }
    catch {
        Write-DeployLog "Failed to restart in Windows PowerShell: $($_.Exception.Message)" -Level 'ERROR'
        return $false
    }
}

# ================================
# Utility Functions
# ================================

function Set-DeployExecutionPolicy {
    <#
    .SYNOPSIS
        Sets execution policy for the current process
    #>
    [CmdletBinding()]
    param()
    
    try {
        Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass -Force
        Write-DeployLog "Execution policy set to Bypass for current process"
    }
    catch {
        Write-DeployLog "Failed to set execution policy: $($_.Exception.Message)" -Level 'WARN'
    }
}

function Get-DeploySystemInfo {
    <#
    .SYNOPSIS
        Gets system information for deployment
    #>
    [CmdletBinding()]
    param()
    
    $info = @{}
    
    try {
        $os = Get-CimInstance Win32_OperatingSystem -ErrorAction Stop
        $info.OSName = $os.Caption
        $info.OSVersion = $os.Version
        $info.OSBuild = $os.BuildNumber
        $info.Architecture = $os.OSArchitecture
        $info.TotalMemoryGB = [math]::Round($os.TotalVisibleMemorySize / 1MB, 2)
        $info.FreeMemoryGB = [math]::Round($os.FreePhysicalMemory / 1MB, 2)
    }
    catch {
        Write-DeployLog "Failed to get OS information: $($_.Exception.Message)" -Level 'WARN'
    }
    
    try {
        $computer = Get-CimInstance Win32_ComputerSystem -ErrorAction Stop
        $info.ComputerName = $computer.Name
        $info.Domain = $computer.Domain
        $info.Manufacturer = $computer.Manufacturer
        $info.Model = $computer.Model
    }
    catch {
        Write-DeployLog "Failed to get computer information: $($_.Exception.Message)" -Level 'WARN'
    }
    
    $info.PSVersion = $PSVersionTable.PSVersion.ToString()
    $info.PSEdition = $PSVersionTable.PSEdition
    $info.CurrentUser = [System.Security.Principal.WindowsIdentity]::GetCurrent().Name
    
    return $info
}

function Test-DeployInternetConnection {
    <#
    .SYNOPSIS
        Tests internet connectivity
    #>
    [CmdletBinding()]
    param(
        [string[]]$TestUrls = @('https://www.google.com', 'https://www.microsoft.com')
    )
    
    foreach ($url in $TestUrls) {
        try {
            $response = Invoke-WebRequest -Uri $url -Method Head -TimeoutSec 10 -UseBasicParsing -ErrorAction Stop
            if ($response.StatusCode -eq 200) {
                Write-DeployLog "Internet connectivity confirmed via $url"
                return $true
            }
        }
        catch {
            Write-DeployLog "Failed to connect to $url`: $($_.Exception.Message)" -Level 'DEBUG'
        }
    }
    
    Write-DeployLog "No internet connectivity detected" -Level 'WARN'
    return $false
}

# ================================
# Export Module Members
# ================================

Export-ModuleMember -Function @(
    'Initialize-DeployLogging',
    'Write-DeployLog',
    'Test-DeployEnvironment',
    'Switch-ToPowerShellDesktop',
    'Set-DeployExecutionPolicy',
    'Get-DeploySystemInfo',
    'Test-DeployInternetConnection'
)
