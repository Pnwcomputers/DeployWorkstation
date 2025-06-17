# DeployWorkstation.Win32Uninstall.psm1
# Win32 application uninstall functionality

using module .\DeployWorkstation.Logging.psm1

function Get-InstalledPrograms {
    <#
    .SYNOPSIS
    Gets a list of installed programs from the Windows registry
    
    .PARAMETER Filter
    Optional filter to apply to program names (supports wildcards)
    
    .PARAMETER IncludeSystemComponents
    Whether to include Windows system components
    #>
    [CmdletBinding()]
    param(
        [string]$Filter,
        [bool]$IncludeSystemComponents = $false
    )
    
    Write-LogEntry -Message "Scanning for installed programs..." -Component 'Win32Uninstall'
    
    $uninstallPaths = @(
        'HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*',
        'HKLM:\Software\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*',
        'HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*'
    )
    
    $programs = @()
    
    foreach ($path in $uninstallPaths) {
        try {
            $items = Get-ItemProperty $path -ErrorAction SilentlyContinue |
                    Where-Object { 
                        $_.DisplayName -and 
                        (-not $_.SystemComponent -or $IncludeSystemComponents) -and
                        (-not $_.ParentKeyName) -and
                        ($_.UninstallString -or $_.QuietUninstallString)
                    }
            
            foreach ($item in $items) {
                if (-not $Filter -or $item.DisplayName -like $Filter) {
                    $programs += @{
                        Name = $item.DisplayName
                        Version = $item.DisplayVersion
                        Publisher = $item.Publisher
                        UninstallString = $item.UninstallString
                        QuietUninstallString = $item.QuietUninstallString
                        InstallDate = $item.InstallDate
                        EstimatedSize = $item.EstimatedSize
                        RegistryKey = $item.PSPath
                        SystemComponent = [bool]$item.SystemComponent
                    }
                }
            }
        }
        catch {
            Write-LogEntry -Message "Error scanning registry path $path`: $($_.Exception.Message)" -Level 'Warning' -Component 'Win32Uninstall'
        }
    }
    
    Write-LogEntry -Message "Found $($programs.Count) installed programs" -Component 'Win32Uninstall'
    return $programs
}

function Uninstall-Win32Program {
    <#
    .SYNOPSIS
    Uninstalls a Win32 program using its uninstall string
    
    .PARAMETER Program
    Program object (from Get-InstalledPrograms)
    
    .PARAMETER Silent
    Whether to attempt silent uninstallation
    
    .PARAMETER TimeoutMinutes
    Maximum time to wait for uninstall process
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [hashtable]$Program,
        
        [bool]$Silent = $true,
        
        [int]$TimeoutMinutes = 10
    )
    
    Write-LogEntry -Message "Attempting to uninstall: $($Program.Name)" -Component 'Win32Uninstall'
    
    $uninstallString = $null
    $arguments = $null
    
    # Prefer quiet uninstall if available and silent is requested
    if ($Silent -and $Program.QuietUninstallString) {
        $uninstallString = $Program.QuietUninstallString
        Write-LogEntry -Message "Using quiet uninstall string" -Component 'Win32Uninstall'
    } elseif ($Program.UninstallString) {
        $uninstallString = $Program.UninstallString
        Write-LogEntry -Message "Using standard uninstall string" -Component 'Win32Uninstall'
    } else {
        Write-LogEntry -Message "No uninstall string available for $($Program.Name)" -Level 'Error' -Component 'Win32Uninstall'
        return @{
            Success = $false
            Message = "No uninstall string available"
            Program = $Program.Name
        }
    }
    
    try {
        # Parse the uninstall string
        if ($uninstallString -match '^"([^"]+)"\s*(.*)) {
            $executable = $Matches[1]
            $arguments = $Matches[2].Trim()
        } else {
            $parts = $uninstallString.Split(' ', 2)
            $executable = $parts[0].Trim('"')
            $arguments = if ($parts.Length -gt 1) { $parts[1] } else { '' }
        }
        
        # Add silent flags if not present and silent uninstall is requested
        if ($Silent -and -not $Program.QuietUninstallString) {
            $silentFlags = @('/S', '/silent', '/quiet', '/q', '/VERYSILENT', '/SUPPRESSMSGBOXES')
            $hasQuietFlag = $false
            
            foreach ($flag in $silentFlags) {
                if ($arguments -match [regex]::Escape($flag)) {
                    $hasQuietFlag = $true
                    break
                }
            }
            
            if (-not $hasQuietFlag) {
                # Try common silent flags
                $arguments += ' /S /quiet'
                Write-LogEntry -Message "Added silent flags to uninstall command" -Component 'Win32Uninstall'
            }
        }
        
        Write-LogEntry -Message "Executing: $executable $arguments" -Component 'Win32Uninstall' -Level 'Debug'
        
        $processParams = @{
            FilePath = $executable
            Wait = $true
            WindowStyle = 'Hidden'
            ErrorAction = 'Stop'
        }
        
        if ($arguments) {
            $processParams.ArgumentList = $arguments
        }
        
        $process = Start-Process @processParams -PassThru
        
        # Wait for process with timeout
        $timeoutMs = $TimeoutMinutes * 60 * 1000
        if (-not $process.WaitForExit($timeoutMs)) {
            Write-LogEntry -Message "Uninstall process timed out after $TimeoutMinutes minutes" -Level 'Warning' -Component 'Win32Uninstall'
            $process.Kill()
            return @{
                Success = $false
                Message = "Process timed out"
                Program = $Program.Name
                ExitCode = -1
            }
        }
        
        $exitCode = $process.ExitCode
        
        if ($exitCode -eq 0) {
            Write-LogEntry -Message "Successfully uninstalled: $($Program.Name)" -Component 'Win32Uninstall'
            return @{
                Success = $true
                Message = "Uninstallation successful"
                Program = $Program.Name
                ExitCode = $exitCode
            }
        } else {
            Write-LogEntry -Message "Uninstall completed with exit code $exitCode for: $($Program.Name)" -Level 'Warning' -Component 'Win32Uninstall'
            return @{
                Success = ($exitCode -in @(0, 3010)) # 3010 = success but reboot required
                Message = "Uninstall completed with exit code: $exitCode"
                Program = $Program.Name
                ExitCode = $exitCode
            }
        }
    }
    catch {
        Write-LogEntry -Message "Error uninstalling $($Program.Name): $($_.Exception.Message)" -Level 'Error' -Component 'Win32Uninstall'
        return @{
            Success = $false
            Message = $_.Exception.Message
            Program = $Program.Name
            ExitCode = $null
        }
    }
}

function Remove-McAfeeProducts {
    <#
    .SYNOPSIS
    Specifically targets McAfee products for removal
    
    .PARAMETER TimeoutMinutes
    Maximum time to wait for each uninstall process
    #>
    [CmdletBinding()]
    param(
        [int]$TimeoutMinutes = 15
    )
    
    Write-LogEntry -Message "Searching for McAfee products..." -Component 'Win32Uninstall'
    
    $mcafeePrograms = Get-InstalledPrograms -Filter '*McAfee*'
    
    if ($mcafeePrograms.Count -eq 0) {
        Write-LogEntry -Message "No McAfee products found" -Component 'Win32Uninstall'
        return @{
            Success = $true
            Message = "No McAfee products found"
            ProgramsProcessed = 0
            Results = @()
        }
    }
    
    Write-LogEntry -Message "Found $($mcafeePrograms.Count) McAfee product(s)" -Component 'Win32Uninstall'
    
    $results = @{
        Success = $true
        ProgramsProcessed = $mcafeePrograms.Count
        SuccessfulRemovals = 0
        FailedRemovals = 0
        Results = @()
    }
    
    foreach ($program in $mcafeePrograms) {
        $uninstallResult = Uninstall-Win32Program -Program $program -Silent $true -TimeoutMinutes $TimeoutMinutes
        $results.Results += $uninstallResult
        
        if ($uninstallResult.Success) {
            $results.SuccessfulRemovals++
        } else {
            $results.FailedRemovals++
            $results.Success = $false
        }
    }
    
    Write-LogEntry -Message "McAfee removal complete: $($results.SuccessfulRemovals)/$($results.ProgramsProcessed) successful" -Component 'Win32Uninstall'
    
    return $results
}

function Remove-BloatwarePrograms {
    <#
    .SYNOPSIS
    Removes common bloatware programs by pattern matching
    
    .PARAMETER ProgramPatterns
    Array of program name patterns to remove
    
    .PARAMETER TimeoutMinutes
    Maximum time to wait for each uninstall process
    #>
    [CmdletBinding()]
    param(
        [string[]]$ProgramPatterns,
        [int]$TimeoutMinutes = 10
    )
    
    if (-not $ProgramPatterns) {
        $ProgramPatterns = @(
            '*McAfee*',
            '*Norton*',
            '*WildTangent*',
            '*Candy Crush*',
            '*Farm Heroes*',
            '*Bubble Witch*',
            '*King.*',
            '*Spotify*',
            '*Netflix*',
            '*Disney*',
            '*Prime Video*',
            '*Adobe Flash*',
            '*Java Auto Updater*',
            '*Ask Toolbar*',
            '*Yahoo*',
            '*Bing*'
        )
    }
    
    Write-LogEntry -Message "Removing bloatware programs using $($ProgramPatterns.Count) patterns..." -Component 'Win32Uninstall'
    
    $allResults = @{
        TotalPatterns = $ProgramPatterns.Count
        TotalProgramsFound = 0
        TotalProgramsRemoved = 0
        TotalProgramsFailed = 0
        PatternResults = @()
    }
    
    foreach ($pattern in $ProgramPatterns) {
        Write-LogEntry -Message "Processing pattern: $pattern" -Component 'Win32Uninstall'
        
        $programs = Get-InstalledPrograms -Filter $pattern
        
        $patternResult = @{
            Pattern = $pattern
            ProgramsFound = $programs.Count
            ProgramsRemoved = 0
            ProgramsFailed = 0
            Details = @()
        }
        
        foreach ($program in $programs) {
            $uninstallResult = Uninstall-Win32Program -Program $program -Silent $true -TimeoutMinutes $TimeoutMinutes
            $patternResult.Details += $uninstallResult
            
            if ($uninstallResult.Success) {
                $patternResult.ProgramsRemoved++
                $allResults.TotalProgramsRemoved++
            } else {
                $patternResult.ProgramsFailed++
                $allResults.TotalProgramsFailed++
            }
        }
        
        $allResults.TotalProgramsFound += $patternResult.ProgramsFound
        $allResults.PatternResults += $patternResult
        
        Write-LogEntry -Message "Pattern '$pattern' complete: $($patternResult.ProgramsRemoved)/$($patternResult.ProgramsFound) removed" -Component 'Win32Uninstall'
    }
    
    Write-LogEntry -Message "Bloatware removal complete: $($allResults.TotalProgramsRemoved)/$($allResults.TotalProgramsFound) programs removed successfully" -Component 'Win32Uninstall'
    
    return $allResults
}

function Test-ProgramInstalled {
    <#
    .SYNOPSIS
    Tests if a program is installed by name pattern
    
    .PARAMETER ProgramName
    Program name pattern to search for
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$ProgramName
    )
    
    $programs = Get-InstalledPrograms -Filter $ProgramName
    return $programs.Count -gt 0
}

# Export functions
Export-ModuleMember -Function Get-InstalledPrograms, Uninstall-Win32Program, Remove-McAfeeProducts, Remove-BloatwarePrograms, Test-ProgramInstalled
