# DeployWorkstation.Logging.psm1
# Centralized logging functionality for DeployWorkstation

# Module variables
$script:LogPath = $null
$script:LogLevel = 'Info'
$script:LogToConsole = $true

# Valid log levels in order of severity
$script:LogLevels = @{
    'Debug' = 0
    'Info' = 1
    'Warning' = 2
    'Error' = 3
    'Critical' = 4
}

function Initialize-Logging {
    <#
    .SYNOPSIS
    Initializes the logging system for DeployWorkstation
    
    .PARAMETER LogPath
    Path to the log file. If not specified, creates a default path
    
    .PARAMETER LogLevel
    Minimum log level to record (Debug, Info, Warning, Error, Critical)
    
    .PARAMETER LogToConsole
    Whether to also output log messages to console
    #>
    [CmdletBinding()]
    param(
        [string]$LogPath,
        [ValidateSet('Debug', 'Info', 'Warning', 'Error', 'Critical')]
        [string]$LogLevel = 'Info',
        [bool]$LogToConsole = $true
    )
    
    if (-not $LogPath) {
        $LogDirectory = Join-Path $env:TEMP "DeployWorkstation"
        if (-not (Test-Path $LogDirectory)) {
            New-Item -ItemType Directory -Path $LogDirectory -Force | Out-Null
        }
        $script:LogPath = Join-Path $LogDirectory "DeployWorkstation_$(Get-Date -Format 'yyyyMMdd_HHmmss').log"
    } else {
        # Ensure log directory exists
        $logDir = Split-Path $LogPath -Parent
        if (-not (Test-Path $logDir)) {
            New-Item -Path $logDir -ItemType Directory -Force | Out-Null
        }
        $script:LogPath = $LogPath
    }
    
    $script:LogLevel = $LogLevel
    $script:LogToConsole = $LogToConsole
    
    Write-LogEntry -Message "Logging initialized. Log file: $script:LogPath" -Level 'Info'
}

function Write-LogEntry {
    <#
    .SYNOPSIS
    Writes a log entry to the log file and optionally to console
    
    .PARAMETER Message
    The log message
    
    .PARAMETER Level
    The log level (Debug, Info, Warning, Error, Critical)
    
    .PARAMETER Component
    Optional component name for categorization
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Message,
        
        [ValidateSet('Debug', 'Info', 'Warning', 'Error', 'Critical')]
        [string]$Level = 'Info',
        
        [string]$Component = 'General'
    )
    
    # Check if we should log this level
    if ($script:LogLevels[$Level] -lt $script:LogLevels[$script:LogLevel]) {
        return
    }
    
    $Timestamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
    $LogEntry = "[$Timestamp] [$Level] [$Component] $Message"
    
    # Write to file if path is set
    if ($script:LogPath) {
        try {
            Add-Content -Path $script:LogPath -Value $LogEntry -Encoding UTF8
        } catch {
            Write-Warning "Failed to write to log file: $_"
        }
    }
    
    # Write to console if enabled
    if ($script:LogToConsole) {
        switch ($Level) {
            'Debug' { Write-Host $LogEntry -ForegroundColor Gray }
            'Info' { Write-Host $LogEntry -ForegroundColor White }
            'Warning' { Write-Host $LogEntry -ForegroundColor Yellow }
            'Error' { Write-Host $LogEntry -ForegroundColor Red }
            'Critical' { Write-Host $LogEntry -ForegroundColor Magenta }
        }
    }
}

function Get-LogPath {
    <#
    .SYNOPSIS
    Gets the current log file path
    #>
    return $script:LogPath
}

function Set-LogLevel {
    <#
    .SYNOPSIS
    Sets the minimum log level
    #>
    [CmdletBinding()]
    param(
        [ValidateSet('Debug', 'Info', 'Warning', 'Error', 'Critical')]
        [string]$Level
    )
    
    $script:LogLevel = $Level
    Write-LogEntry -Message "Log level changed to: $Level" -Level 'Info'
}

# Export functions
Export-ModuleMember -Function Initialize-Logging, Write-LogEntry, Get-LogPath, Set-LogLevel
