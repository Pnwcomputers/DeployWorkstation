#Requires -Version 5.1
#Requires -RunAsAdministrator
[CmdletBinding()]
param(
    [ValidateSet('Full','BloatwareOnly','AppsOnly','ConfigOnly')]
    [string]$Mode,
    [string]$LogPath,
    [string]$ReportPath
)

$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'

$script:Version   = '6.0'
$script:StartTime = Get-Date
$script:ScriptRoot = if ($PSScriptRoot) { $PSScriptRoot } else { Split-Path -Parent $MyInvocation.MyCommand.Path }

if (-not $LogPath)    { $LogPath    = Join-Path $script:ScriptRoot 'DeployWorkstation.log' }
if (-not $ReportPath) { $ReportPath = Join-Path $script:ScriptRoot 'DeployWorkstation.html' }

$script:Results = New-Object System.Collections.Generic.List[object]
$script:EventLog = New-Object System.Collections.Generic.List[object]
$script:Summary = [ordered]@{
    AppsInstalled       = 0
    AppsFailed          = 0
    PackagesRemoved     = 0
    AppxRemoved         = 0
    CapabilitiesRemoved = 0
    McAfeeRemoved       = 0
    ConfigApplied       = 0
    ConfigFailed        = 0
}

function Write-Log {
    param(
        [Parameter(Mandatory)][string]$Message,
        [ValidateSet('INFO','WARN','ERROR','SUCCESS','SECTION')]
        [string]$Level = 'INFO'
    )
    $timestamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
    $line = "[$timestamp] [$Level] $Message"
    $color = switch ($Level) {
        'WARN'    { 'Yellow' }
        'ERROR'   { 'Red' }
        'SUCCESS' { 'Green' }
        'SECTION' { 'Cyan' }
        default   { 'Gray' }
    }
    Write-Host $line -ForegroundColor $color
    Add-Content -Path $LogPath -Value $line -Encoding UTF8
    $script:EventLog.Add([pscustomobject]@{
        Timestamp = $timestamp
        Level     = $Level
        Message   = $Message
    }) | Out-Null
}

function Add-Result {
    param(
        [Parameter(Mandatory)][string]$Section,
        [Parameter(Mandatory)][string]$Item,
        [ValidateSet('OK','SKIPPED','WARN','FAILED')]
        [string]$Status,
        [string]$Detail = ''
    )
    $script:Results.Add([pscustomobject]@{
        Section = $Section
        Item    = $Item
        Status  = $Status
        Detail  = $Detail
    }) | Out-Null
}

function ConvertTo-HtmlSafe {
    param([AllowNull()][string]$Text)
    if ([string]::IsNullOrEmpty($Text)) { return '' }
    return ($Text -replace '&','&amp;' -replace '<','&lt;' -replace '>','&gt;' -replace '"','&quot;')
}

function Get-WindowsEditionId {
    try {
        return [string](Get-ItemProperty -Path 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion' -Name EditionID -ErrorAction Stop).EditionID
    } catch {
        return 'Unknown'
    }
}

function Test-WingetPresent {
    return [bool](Get-Command winget.exe -ErrorAction SilentlyContinue)
}

function Ensure-Winget {
    if (Test-WingetPresent) {
        Write-Log "Winget found: $(winget.exe --version 2>$null)"
        return $true
    }

    Write-Log 'Winget not found. Attempting to install App Installer...' -Level 'WARN'

    $bundle = Join-Path $env:TEMP 'Microsoft.DesktopAppInstaller.msixbundle'
    try {
        if (Get-Command Start-BitsTransfer -ErrorAction SilentlyContinue) {
            Start-BitsTransfer -Source 'https://aka.ms/getwinget' -Destination $bundle -ErrorAction Stop
        } else {
            $wc = New-Object System.Net.WebClient
            $wc.DownloadFile('https://aka.ms/getwinget', $bundle)
        }

        Add-AppxPackage -Path $bundle -ErrorAction Stop
        Start-Sleep -Seconds 5

        if (Test-WingetPresent) {
            Write-Log 'Winget installed successfully.' -Level 'SUCCESS'
            return $true
        }

        Write-Log 'Winget installation did not make winget.exe available.' -Level 'ERROR'
        return $false
    } catch {
        Write-Log "Winget bootstrap failed: $($_.Exception.Message)" -Level 'ERROR'
        return $false
    } finally {
        Remove-Item -Path $bundle -Force -ErrorAction SilentlyContinue
    }
}

function Get-WingetListText {
    try {
        return (winget.exe list --accept-source-agreements 2>&1 | Out-String)
    } catch {
        return ''
    }
}

function Initialize-WingetSources {
    if (-not (Test-WingetPresent)) { return }

    try {
        $sourceList = winget.exe source list 2>&1 | Out-String
        if ($sourceList -match '(?im)^\s*msstore\s') {
            Write-Log 'Removing winget msstore source for better reliability...'
            winget.exe source remove --name msstore 2>&1 | Out-Null
        }
        Write-Log 'Refreshing winget source index...'
        winget.exe source update 2>&1 | Out-Null
    } catch {
        Write-Log "Winget source maintenance warning: $($_.Exception.Message)" -Level 'WARN'
    }
}

function Remove-WingetAppByName {
    param([Parameter(Mandatory)][string]$Name)

    try {
        $listText = Get-WingetListText
        if ($listText -notmatch [regex]::Escape($Name)) {
            Write-Log "$Name not detected by winget list."
            Add-Result -Section 'Bloatware Removal' -Item $Name -Status 'SKIPPED' -Detail 'Not installed'
            return
        }

        Write-Log "Removing $Name..."
        & winget.exe uninstall --name $Name --silent --force --accept-source-agreements 2>&1 | Out-Null
        $exit = $LASTEXITCODE

        if ($exit -eq 0) {
            Write-Log "$Name removed." -Level 'SUCCESS'
            Add-Result -Section 'Bloatware Removal' -Item $Name -Status 'OK' -Detail 'Removed'
            $script:Summary.PackagesRemoved++
        } else {
            Write-Log "Winget uninstall for $Name returned exit code $exit." -Level 'WARN'
            Add-Result -Section 'Bloatware Removal' -Item $Name -Status 'WARN' -Detail "Exit code $exit"
        }
    } catch {
        Write-Log "Error removing $Name: $($_.Exception.Message)" -Level 'WARN'
        Add-Result -Section 'Bloatware Removal' -Item $Name -Status 'WARN' -Detail $_.Exception.Message
    }
}

function Remove-AppxTargets {
    param([Parameter(Mandatory)][string[]]$Patterns)

    foreach ($pattern in $Patterns) {
        try {
            $count = 0
            $packages = @(Get-AppxPackage -AllUsers -Name $pattern -ErrorAction SilentlyContinue)
            foreach ($pkg in $packages) {
                Remove-AppxPackage -Package $pkg.PackageFullName -AllUsers -ErrorAction SilentlyContinue
                $count++
            }

            $prov = @(Get-AppxProvisionedPackage -Online -ErrorAction SilentlyContinue | Where-Object { $_.DisplayName -like $pattern })
            foreach ($pkg in $prov) {
                Remove-AppxProvisionedPackage -Online -PackageName $pkg.PackageName -ErrorAction SilentlyContinue | Out-Null
                $count++
            }

            if ($count -gt 0) {
                Write-Log "Removed Appx target $pattern ($count item(s))." -Level 'SUCCESS'
                Add-Result -Section 'Appx Removal' -Item $pattern -Status 'OK' -Detail "Removed $count"
                $script:Summary.AppxRemoved += $count
            } else {
                Add-Result -Section 'Appx Removal' -Item $pattern -Status 'SKIPPED' -Detail 'Not installed'
            }
        } catch {
            Write-Log "Appx removal warning for $pattern: $($_.Exception.Message)" -Level 'WARN'
            Add-Result -Section 'Appx Removal' -Item $pattern -Status 'WARN' -Detail $_.Exception.Message
        }
    }
}

function Remove-WindowsCapabilitiesSafe {
    param([Parameter(Mandatory)][string[]]$Names)

    if (-not (Get-Command Get-WindowsCapability -ErrorAction SilentlyContinue)) {
        Write-Log 'Windows capability cmdlets not available on this system.' -Level 'WARN'
        foreach ($name in $Names) {
            Add-Result -Section 'Capability Removal' -Item $name -Status 'SKIPPED' -Detail 'Capability cmdlets unavailable'
        }
        return
    }

    foreach ($name in $Names) {
        try {
            $cap = Get-WindowsCapability -Online -Name $name -ErrorAction SilentlyContinue
            if ($cap -and $cap.State -eq 'Installed') {
                Remove-WindowsCapability -Online -Name $name -ErrorAction SilentlyContinue | Out-Null
                Write-Log "Removed capability $name." -Level 'SUCCESS'
                Add-Result -Section 'Capability Removal' -Item $name -Status 'OK' -Detail 'Removed'
                $script:Summary.CapabilitiesRemoved++
            } else {
                Add-Result -Section 'Capability Removal' -Item $name -Status 'SKIPPED' -Detail 'Not installed'
            }
        } catch {
            Write-Log "Capability removal warning for $name: $($_.Exception.Message)" -Level 'WARN'
            Add-Result -Section 'Capability Removal' -Item $name -Status 'WARN' -Detail $_.Exception.Message
        }
    }
}

function Remove-McAfeeProducts {
    $paths = @(
        'HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*',
        'HKLM:\Software\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*'
    )

    $entries = foreach ($path in $paths) {
        Get-ItemProperty -Path $path -ErrorAction SilentlyContinue | Where-Object { $_.DisplayName -like '*McAfee*' }
    }

    $entries = @($entries | Sort-Object DisplayName -Unique)

    if (-not $entries -or $entries.Count -eq 0) {
        Add-Result -Section 'McAfee Removal' -Item 'McAfee' -Status 'SKIPPED' -Detail 'Not installed'
        return
    }

    foreach ($entry in $entries) {
        $name = [string]$entry.DisplayName
        $uninstallString = [string]$entry.UninstallString

        if ([string]::IsNullOrWhiteSpace($uninstallString)) {
            Write-Log "No uninstall string found for $name." -Level 'WARN'
            Add-Result -Section 'McAfee Removal' -Item $name -Status 'WARN' -Detail 'No uninstall string'
            continue
        }

        try {
            if ($uninstallString -match '^"([^"]+)"\s*(.*)$') {
                $exe = $Matches[1]
                $args = $Matches[2]
            } else {
                $parts = $uninstallString.Split(' ', 2)
                $exe = $parts[0]
                $args = if ($parts.Count -gt 1) { $parts[1] } else { '' }
            }

            if ($exe -match 'msiexec(\.exe)?$' -and $args -notmatch '(/qn|/quiet)') {
                $args = "$args /qn /norestart"
            } elseif ($args -notmatch '(/S|/silent|/quiet)') {
                $args = "$args /S"
            }

            Write-Log "Uninstalling $name..."
            Start-Process -FilePath $exe -ArgumentList $args -Wait -WindowStyle Hidden -ErrorAction Stop
            Write-Log "$name removed." -Level 'SUCCESS'
            Add-Result -Section 'McAfee Removal' -Item $name -Status 'OK' -Detail 'Removed'
            $script:Summary.McAfeeRemoved++
        } catch {
            Write-Log "McAfee removal warning for $name: $($_.Exception.Message)" -Level 'WARN'
            Add-Result -Section 'McAfee Removal' -Item $name -Status 'WARN' -Detail $_.Exception.Message
        }
    }
}

function Test-WingetIdInstalled {
    param([Parameter(Mandatory)][string]$Id)
    try {
        $output = & winget.exe list --id $Id --exact --accept-source-agreements 2>&1 | Out-String
        return ($output -match [regex]::Escape($Id))
    } catch {
        return $false
    }
}

function Install-WingetId {
    param(
        [Parameter(Mandatory)][string]$Id,
        [Parameter(Mandatory)][string]$Name
    )

    if (-not (Test-WingetPresent)) {
        Write-Log "Skipping $Name because winget is unavailable." -Level 'WARN'
        Add-Result -Section 'Application Installation' -Item $Name -Status 'WARN' -Detail 'Winget unavailable'
        $script:Summary.AppsFailed++
        return
    }

    try {
        if (Test-WingetIdInstalled -Id $Id) {
            Write-Log "$Name already installed."
            Add-Result -Section 'Application Installation' -Item $Name -Status 'OK' -Detail 'Already installed'
            $script:Summary.AppsInstalled++
            return
        }

        Write-Log "Installing $Name..."
        & winget.exe install --id $Id --exact --source winget --accept-package-agreements --accept-source-agreements --silent 2>&1 | Out-Null
        $exit = $LASTEXITCODE

        if ($exit -eq 0 -or (Test-WingetIdInstalled -Id $Id)) {
            Write-Log "$Name installed." -Level 'SUCCESS'
            Add-Result -Section 'Application Installation' -Item $Name -Status 'OK' -Detail 'Installed'
            $script:Summary.AppsInstalled++
        } else {
            Write-Log "Install of $Name returned exit code $exit." -Level 'WARN'
            Add-Result -Section 'Application Installation' -Item $Name -Status 'WARN' -Detail "Exit code $exit"
            $script:Summary.AppsFailed++
        }
    } catch {
        Write-Log "Install warning for $Name: $($_.Exception.Message)" -Level 'WARN'
        Add-Result -Section 'Application Installation' -Item $Name -Status 'WARN' -Detail $_.Exception.Message
        $script:Summary.AppsFailed++
    }
}

function Set-RegistryDword {
    param(
        [Parameter(Mandatory)][string]$Path,
        [Parameter(Mandatory)][string]$Name,
        [Parameter(Mandatory)][int]$Value
    )

    try {
        if (-not (Test-Path -Path $Path)) {
            New-Item -Path $Path -Force | Out-Null
        }

        $existing = Get-ItemProperty -Path $Path -Name $Name -ErrorAction SilentlyContinue
        if ($null -eq $existing) {
            New-ItemProperty -Path $Path -Name $Name -PropertyType DWord -Value $Value -Force -ErrorAction Stop | Out-Null
        } else {
            Set-ItemProperty -Path $Path -Name $Name -Value $Value -Force -ErrorAction Stop
        }

        Write-Log "Registry set: $Path\$Name = $Value" -Level 'SUCCESS'
        Add-Result -Section 'System Configuration' -Item $Name -Status 'OK' -Detail "$Path = $Value"
        $script:Summary.ConfigApplied++
    } catch {
        Write-Log "Registry warning for $Path\$Name: $($_.Exception.Message)" -Level 'WARN'
        Add-Result -Section 'System Configuration' -Item $Name -Status 'WARN' -Detail $_.Exception.Message
        $script:Summary.ConfigFailed++
    }
}

function Set-SystemConfiguration {
    $items = @(
        @{ Path = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\DataCollection';  Name = 'AllowTelemetry';         Value = 0 },
        @{ Path = 'HKLM:\SOFTWARE\Microsoft\Windows\Windows Error Reporting';  Name = 'Disabled';               Value = 1 },
        @{ Path = 'HKLM:\SOFTWARE\Microsoft\SQMClient\Windows';                Name = 'CEIPEnable';             Value = 0 },
        @{ Path = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\AdvertisingInfo'; Name = 'DisabledByGroupPolicy'; Value = 1 }
    )

    foreach ($item in $items) {
        Set-RegistryDword -Path $item.Path -Name $item.Name -Value $item.Value
    }
}

function Export-HtmlReport {
    param([Parameter(Mandatory)][string]$OverallStatus)

    $os = Get-CimInstance Win32_OperatingSystem
    $cpu = (Get-CimInstance Win32_Processor | Select-Object -First 1).Name
    $edition = Get-WindowsEditionId
    $ramGB = [math]::Round($os.TotalVisibleMemorySize / 1MB, 1)
    $uptimeHours = [math]::Round(((Get-Date) - $os.LastBootUpTime).TotalHours, 1)
    $runTime = (Get-Date) - $script:StartTime

    $resultRows = foreach ($row in $script:Results) {
        '<tr><td>{0}</td><td>{1}</td><td>{2}</td><td>{3}</td></tr>' -f `
            (ConvertTo-HtmlSafe $row.Section),
            (ConvertTo-HtmlSafe $row.Item),
            (ConvertTo-HtmlSafe $row.Status),
            (ConvertTo-HtmlSafe $row.Detail)
    }

    $eventRows = foreach ($row in ($script:EventLog | Select-Object -Last 200)) {
        '<tr><td>{0}</td><td>{1}</td><td>{2}</td></tr>' -f `
            (ConvertTo-HtmlSafe $row.Timestamp),
            (ConvertTo-HtmlSafe $row.Level),
            (ConvertTo-HtmlSafe $row.Message)
    }

    $html = @"
<!DOCTYPE html>
<html>
<head>
<meta charset="utf-8" />
<title>DeployWorkstation Report</title>
<style>
body { font-family: Segoe UI, Arial, sans-serif; margin: 20px; color: #222; }
h1, h2 { color: #0b5394; }
table { border-collapse: collapse; width: 100%; margin-bottom: 24px; }
th, td { border: 1px solid #d9d9d9; padding: 8px; text-align: left; vertical-align: top; }
th { background: #f3f6f9; }
</style>
</head>
<body>
<h1>DeployWorkstation Report</h1>
<p>Generated: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')</p>

<h2>System Information</h2>
<table>
<tr><th>Hostname</th><td>$(ConvertTo-HtmlSafe $env:COMPUTERNAME)</td></tr>
<tr><th>Operating System</th><td>$(ConvertTo-HtmlSafe $os.Caption)</td></tr>
<tr><th>Edition</th><td>$(ConvertTo-HtmlSafe $edition)</td></tr>
<tr><th>Build</th><td>$(ConvertTo-HtmlSafe $os.BuildNumber)</td></tr>
<tr><th>CPU</th><td>$(ConvertTo-HtmlSafe $cpu)</td></tr>
<tr><th>RAM</th><td>$ramGB GB</td></tr>
<tr><th>System Uptime</th><td>$uptimeHours hours</td></tr>
<tr><th>Script Run Time</th><td>$([math]::Round($runTime.TotalMinutes,1)) minutes</td></tr>
<tr><th>Script Version</th><td>$script:Version</td></tr>
<tr><th>Technician</th><td>$(ConvertTo-HtmlSafe $env:USERNAME)</td></tr>
<tr><th>Status</th><td>$(ConvertTo-HtmlSafe $OverallStatus)</td></tr>
</table>

<h2>Summary</h2>
<table>
<tr><th>Apps Installed</th><td>$($script:Summary.AppsInstalled)</td></tr>
<tr><th>Apps Failed</th><td>$($script:Summary.AppsFailed)</td></tr>
<tr><th>Winget Packages Removed</th><td>$($script:Summary.PackagesRemoved)</td></tr>
<tr><th>Appx Removed</th><td>$($script:Summary.AppxRemoved)</td></tr>
<tr><th>Capabilities Removed</th><td>$($script:Summary.CapabilitiesRemoved)</td></tr>
<tr><th>McAfee Removed</th><td>$($script:Summary.McAfeeRemoved)</td></tr>
<tr><th>Config Applied</th><td>$($script:Summary.ConfigApplied)</td></tr>
<tr><th>Config Failed</th><td>$($script:Summary.ConfigFailed)</td></tr>
</table>

<h2>Detailed Results</h2>
<table>
<tr><th>Section</th><th>Item</th><th>Status</th><th>Detail</th></tr>
$($resultRows -join "`r`n")
</table>

<h2>Event Log (last 200 entries)</h2>
<table>
<tr><th>Timestamp</th><th>Level</th><th>Message</th></tr>
$($eventRows -join "`r`n")
</table>
</body>
</html>
"@

    [System.IO.File]::WriteAllText($ReportPath, $html, [System.Text.UTF8Encoding]::new($false))
    Write-Log "HTML report written to $ReportPath" -Level 'SUCCESS'
}

function Show-ModeMenu {
    Write-Host ''
    Write-Host 'Select deployment mode:' -ForegroundColor Cyan
    Write-Host '  1. Full deployment'
    Write-Host '  2. Remove bloatware only'
    Write-Host '  3. Install apps only'
    Write-Host '  4. System configuration only'
    Write-Host '  5. Exit'
    Write-Host ''

    do {
        $choice = Read-Host 'Enter choice (1-5)'
        switch ($choice) {
            '1' { return 'Full' }
            '2' { return 'BloatwareOnly' }
            '3' { return 'AppsOnly' }
            '4' { return 'ConfigOnly' }
            '5' { return $null }
            default { Write-Host 'Invalid choice. Please try again.' -ForegroundColor Yellow }
        }
    } while ($true)
}

function Invoke-BloatwareRemoval {
    Write-Log '--- BLOATWARE REMOVAL ---' -Level 'SECTION'

    if (Test-WingetPresent) {
        $removeNames = @(
            'McAfee',
            'WildTangent',
            'Dropbox Promotion',
            'Booking.com',
            'ExpressVPN',
            'Amazon Alexa',
            'Spotify'
        )
        foreach ($name in $removeNames) {
            Remove-WingetAppByName -Name $name
        }
    } else {
        Write-Log 'Winget unavailable; skipping winget package removals.' -Level 'WARN'
        Add-Result -Section 'Bloatware Removal' -Item 'Winget package removals' -Status 'SKIPPED' -Detail 'Winget unavailable'
    }

    Remove-AppxTargets -Patterns @(
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

    Remove-WindowsCapabilitiesSafe -Names @(
        'App.Support.QuickAssist~~~~0.0.1.0',
        'App.Xbox.TCUI~~~~0.0.1.0',
        'App.XboxGameOverlay~~~~0.0.1.0',
        'App.XboxSpeechToTextOverlay~~~~0.0.1.0',
        'OpenSSH.Client~~~~0.0.1.0'
    )

    Remove-McAfeeProducts
}

function Invoke-AppInstallation {
    Write-Log '--- APP INSTALLATION ---' -Level 'SECTION'

    $apps = @(
        @{ Id = 'Malwarebytes.Malwarebytes';         Name = 'Malwarebytes' },
        @{ Id = 'BleachBit.BleachBit';               Name = 'BleachBit' },
        @{ Id = 'Google.Chrome';                     Name = 'Google Chrome' },
        @{ Id = 'Adobe.Acrobat.Reader.64-bit';       Name = 'Adobe Acrobat Reader (64-bit)' },
        @{ Id = '7zip.7zip';                         Name = '7-Zip' },
        @{ Id = 'VideoLAN.VLC';                      Name = 'VLC Media Player' },
        @{ Id = 'Microsoft.DotNet.Framework.4.8';    Name = '.NET Framework 4.8' },
        @{ Id = 'Microsoft.DotNet.DesktopRuntime.6'; Name = '.NET 6 Desktop Runtime' },
        @{ Id = 'Microsoft.DotNet.DesktopRuntime.7'; Name = '.NET 7 Desktop Runtime' },
        @{ Id = 'Microsoft.DotNet.DesktopRuntime.8'; Name = '.NET 8 Desktop Runtime' },
        @{ Id = 'Microsoft.VCRedist.2015+.x64';      Name = 'VC++ 2015-2022 Redist (x64)' },
        @{ Id = 'Microsoft.VCRedist.2015+.x86';      Name = 'VC++ 2015-2022 Redist (x86)' }
    )

    foreach ($app in $apps) {
        Install-WingetId -Id $app.Id -Name $app.Name
    }
}

function Invoke-SystemConfiguration {
    Write-Log '--- SYSTEM CONFIGURATION ---' -Level 'SECTION'
    Set-SystemConfiguration
}

# Preflight
try {
    if (-not (Test-Path -Path (Split-Path -Parent $LogPath))) {
        New-Item -Path (Split-Path -Parent $LogPath) -ItemType Directory -Force | Out-Null
    }

    Write-Log "DeployWorkstation v$($script:Version) started." -Level 'SECTION'
    Write-Log "Computer: $env:COMPUTERNAME"
    Write-Log "User: $env:USERNAME"
    Write-Log "OS: $((Get-CimInstance Win32_OperatingSystem).Caption)"
    Write-Log "Edition: $(Get-WindowsEditionId)"
    Write-Log "PowerShell: $($PSVersionTable.PSVersion)"

    if (-not $Mode) {
        $Mode = Show-ModeMenu
        if (-not $Mode) {
            Write-Log 'User chose to exit.'
            exit 0
        }
    }

    $needsWinget = $Mode -in @('Full','BloatwareOnly','AppsOnly')
    if ($needsWinget) {
        $wingetReady = Ensure-Winget
        if ($wingetReady) {
            Initialize-WingetSources
        } else {
            Write-Log 'Winget could not be initialized. Winget-dependent actions will be skipped or warned.' -Level 'WARN'
        }
    }

    switch ($Mode) {
        'Full' {
            Invoke-BloatwareRemoval
            Invoke-AppInstallation
            Invoke-SystemConfiguration
        }
        'BloatwareOnly' { Invoke-BloatwareRemoval }
        'AppsOnly'      { Invoke-AppInstallation }
        'ConfigOnly'    { Invoke-SystemConfiguration }
        default         { throw "Unsupported mode: $Mode" }
    }

    $overallStatus = if ($script:Summary.AppsFailed -gt 0 -or $script:Summary.ConfigFailed -gt 0) {
        'Completed with warnings'
    } else {
        'Completed successfully'
    }

    Export-HtmlReport -OverallStatus $overallStatus
    Write-Log 'DeployWorkstation completed.' -Level 'SECTION'

    if ($script:Summary.AppsFailed -gt 0 -or $script:Summary.ConfigFailed -gt 0) {
        exit 1
    } else {
        exit 0
    }
} catch {
    try {
        Write-Log "Fatal error: $($_.Exception.Message)" -Level 'ERROR'
        Add-Result -Section 'Fatal' -Item 'Unhandled exception' -Status 'FAILED' -Detail $_.Exception.Message
        Export-HtmlReport -OverallStatus 'Failed'
    } catch {
        Write-Host "Fatal error while generating failure report: $($_.Exception.Message)" -ForegroundColor Red
    }
    exit 1
}
