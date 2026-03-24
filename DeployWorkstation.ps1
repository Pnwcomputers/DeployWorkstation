# DeployWorkstation.ps1 – Optimized Win10/11 Setup & Clean-up
# Version: 5.0 – PNWC Edition
# New in 5.0: HTML deployment report, JSON config export

#Requires -Version 5.1
#Requires -RunAsAdministrator

[CmdletBinding()]
param(
    [string]$LogPath,
    [string]$ReportPath,
    [string]$JsonPath,
    [switch]$SkipAppInstall,
    [switch]$SkipBloatwareRemoval,
    [switch]$SkipSystemConfig
)

# ================================
# Configuration & Setup
# ================================

$ErrorActionPreference = 'Continue'
$ProgressPreference    = 'SilentlyContinue'
$script:StartTime      = Get-Date

if (-not $PSScriptRoot) {
    $PSScriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
}

if (-not $LogPath)    { $LogPath    = Join-Path $PSScriptRoot 'DeployWorkstation.log'  }
if (-not $ReportPath) { $ReportPath = Join-Path $PSScriptRoot 'DeployWorkstation.html' }
if (-not $JsonPath)   { $JsonPath   = Join-Path $PSScriptRoot 'DeployWorkstation.json' }

# --------------------------------
# Restart in Windows PowerShell 5.1 if running under PS Core
# --------------------------------
if ($PSVersionTable.PSEdition -eq 'Core') {
    Write-Warning 'PowerShell Core detected. Restarting in Windows PowerShell 5.1...'
    $params = @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', $PSCommandPath,
                '-LogPath', $LogPath, '-ReportPath', $ReportPath, '-JsonPath', $JsonPath)
    if ($SkipAppInstall)       { $params += '-SkipAppInstall' }
    if ($SkipBloatwareRemoval) { $params += '-SkipBloatwareRemoval' }
    if ($SkipSystemConfig)     { $params += '-SkipSystemConfig' }
    Start-Process -FilePath 'powershell.exe' -ArgumentList $params -Verb RunAs
    exit
}

# --------------------------------
# Logging
# --------------------------------
$logDir = Split-Path $LogPath -Parent
if ($logDir -and -not (Test-Path $logDir)) {
    New-Item -Path $logDir -ItemType Directory -Force | Out-Null
}

# Every log entry is also stored in $script:EventLog for the HTML report
$script:EventLog = [System.Collections.Generic.List[hashtable]]::new()

function Write-Log {
    param(
        [string]$Message,
        [ValidateSet('INFO','WARN','ERROR','SUCCESS','SECTION')]
        [string]$Level = 'INFO'
    )
    $timestamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
    $logEntry  = "[$timestamp] [$Level] $Message"

    $color = switch ($Level) {
        'WARN'    { 'Yellow' }
        'ERROR'   { 'Red'    }
        'SUCCESS' { 'Green'  }
        'SECTION' { 'Cyan'   }
        default   { 'Gray'   }
    }
    Write-Host $logEntry -ForegroundColor $color
    Add-Content -Path $LogPath -Value $logEntry -Encoding UTF8
    $script:EventLog.Add(@{ Timestamp = $timestamp; Level = $Level; Message = $Message })
}

# --------------------------------
# Summary counters
# --------------------------------
$script:Summary = @{
    AppsInstalled       = 0
    AppsFailed          = 0
    AppxRemoved         = 0
    CapabilitiesRemoved = 0
    McAfeeRemoved       = 0
    HardeningApplied    = 0
    HardeningFailed     = 0
}

# Detailed per-item results used in HTML report
# Each entry: @{ Section; Item; Status; Detail }
$script:Results = [System.Collections.Generic.List[hashtable]]::new()

function Add-Result {
    param(
        [string]$Section,
        [string]$Item,
        [ValidateSet('OK','SKIPPED','WARN','FAILED')]
        [string]$Status,
        [string]$Detail = ''
    )
    $script:Results.Add(@{
        Section = $Section
        Item    = $Item
        Status  = $Status
        Detail  = $Detail
    })
}

Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass -Force

Write-Log "===== DeployWorkstation.ps1 v5.0 Started =====" -Level 'SECTION'
Write-Log "PowerShell  : $($PSVersionTable.PSVersion)"
Write-Log "OS          : $((Get-CimInstance Win32_OperatingSystem).Caption)"
Write-Log "Hostname    : $env:COMPUTERNAME"
Write-Log "Log file    : $LogPath"
Write-Log "HTML report : $ReportPath"
Write-Log "JSON export : $JsonPath"

# ================================
# Helper Functions
# ================================

function Set-RegistryValue {
    param(
        [string]$Path,
        [string]$Name,
        [int]   $Value
    )
    try {
        if (-not (Test-Path $Path)) { New-Item -Path $Path -Force | Out-Null }
        Set-ItemProperty -Path $Path -Name $Name -Value $Value -Type DWord -Force -ErrorAction Stop
        Write-Log "Registry OK: $Path\$Name = $Value" -Level 'SUCCESS'
        Add-Result -Section 'System Config' -Item $Name -Status 'OK' -Detail "$Path = $Value"
        $script:Summary.HardeningApplied++
    }
    catch {
        Write-Log "Registry FAIL: $Path\$Name - $($_.Exception.Message)" -Level 'WARN'
        Add-Result -Section 'System Config' -Item $Name -Status 'WARN' -Detail $_.Exception.Message
        $script:Summary.HardeningFailed++
    }
}

# ================================
# Winget Management
# ================================

function Test-Winget {
    try {
        $null = Get-Command winget -ErrorAction Stop
        $version = (winget --version) -replace '[^\d\.]', ''
        Write-Log "Winget found: v$version"
        return $true
    }
    catch {
        Write-Log "Winget not found on PATH." -Level 'ERROR'
        return $false
    }
}

function Initialize-WingetSources {
    Write-Log "Managing winget sources..."
    try {
        $sources = winget source list 2>$null
        if ($sources -match 'msstore') {
            Write-Log "Removing msstore source (performance)..."
            winget source remove --name msstore 2>$null | Out-Null
        }
        Write-Log "Refreshing winget source index..."
        winget source update --name winget 2>$null | Out-Null
    }
    catch {
        Write-Log "Could not manage winget sources: $($_.Exception.Message)" -Level 'WARN'
    }
}

# ================================
# Bloatware Removal
# ================================

function Remove-WingetApps {
    param([string[]]$AppPatterns)
    Write-Log "--- Winget bloatware removal ---" -Level 'SECTION'

    foreach ($pattern in $AppPatterns) {
        Write-Log "Checking: $pattern"
        try {
            $found = winget list --name "$pattern" --accept-source-agreements 2>$null |
                     Where-Object { $_ -and $_ -notmatch 'Name\s+Id\s+Version' -and $_.Trim() }

            if (-not $found) {
                Write-Log "Not found: $pattern"
                Add-Result -Section 'Bloatware' -Item $pattern -Status 'SKIPPED' -Detail 'Not installed'
                continue
            }

            Write-Log "Removing: $pattern"
            winget uninstall --name "$pattern" --silent --force --accept-source-agreements 2>&1 | Out-Null

            if ($LASTEXITCODE -eq 0) {
                Write-Log "Removed: $pattern" -Level 'SUCCESS'
                Add-Result -Section 'Bloatware' -Item $pattern -Status 'OK' -Detail 'Removed via winget'
            } else {
                Write-Log "Removal exit code $LASTEXITCODE for: $pattern" -Level 'WARN'
                Add-Result -Section 'Bloatware' -Item $pattern -Status 'WARN' -Detail "Exit code $LASTEXITCODE"
            }
        }
        catch {
            Write-Log "Error removing $pattern`: $($_.Exception.Message)" -Level 'ERROR'
            Add-Result -Section 'Bloatware' -Item $pattern -Status 'FAILED' -Detail $_.Exception.Message
        }
    }
}

function Remove-AppxPackages {
    Write-Log "--- Appx / UWP package removal ---" -Level 'SECTION'

    $packagesToRemove = @(
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

    foreach ($pattern in $packagesToRemove) {
        try {
            $removed = 0

            $pkgs = Get-AppxPackage -AllUsers -Name $pattern -ErrorAction SilentlyContinue
            foreach ($pkg in $pkgs) {
                Write-Log "Removing Appx: $($pkg.Name)"
                Remove-AppxPackage -Package $pkg.PackageFullName -AllUsers -ErrorAction SilentlyContinue
                $script:Summary.AppxRemoved++
                $removed++
            }

            $provPkgs = Get-AppxProvisionedPackage -Online -ErrorAction SilentlyContinue |
                        Where-Object { $_.DisplayName -like $pattern }
            foreach ($pkg in $provPkgs) {
                Write-Log "Removing provisioned: $($pkg.DisplayName)"
                Remove-AppxProvisionedPackage -Online -PackageName $pkg.PackageName -ErrorAction SilentlyContinue
                $script:Summary.AppxRemoved++
                $removed++
            }

            $label  = $pattern.Replace('*','')
            $status = if ($removed -gt 0) { 'OK' } else { 'SKIPPED' }
            $detail = if ($removed -gt 0) { "Removed $removed package(s)" } else { 'Not installed' }
            Add-Result -Section 'Appx Removal' -Item $label -Status $status -Detail $detail
        }
        catch {
            Write-Log "Error processing $pattern`: $($_.Exception.Message)" -Level 'WARN'
            Add-Result -Section 'Appx Removal' -Item $pattern.Replace('*','') -Status 'WARN' -Detail $_.Exception.Message
        }
    }
}

function Remove-WindowsCapabilities {
    Write-Log "--- Windows optional capability removal ---" -Level 'SECTION'

    $capabilitiesToRemove = @(
        'App.Support.QuickAssist~~~~0.0.1.0',
        'App.Xbox.TCUI~~~~0.0.1.0',
        'App.XboxGameOverlay~~~~0.0.1.0',
        'App.XboxSpeechToTextOverlay~~~~0.0.1.0',
        'OpenSSH.Client~~~~0.0.1.0'
    )

    foreach ($cap in $capabilitiesToRemove) {
        try {
            $state = Get-WindowsCapability -Online -Name $cap -ErrorAction SilentlyContinue
            if ($state -and $state.State -eq 'Installed') {
                Write-Log "Removing capability: $cap"
                Remove-WindowsCapability -Online -Name $cap -ErrorAction SilentlyContinue | Out-Null
                $script:Summary.CapabilitiesRemoved++
                Add-Result -Section 'Capabilities' -Item $cap -Status 'OK' -Detail 'Removed'
            } else {
                Write-Log "Not installed: $cap"
                Add-Result -Section 'Capabilities' -Item $cap -Status 'SKIPPED' -Detail 'Not installed'
            }
        }
        catch {
            Write-Log "Error with capability $cap`: $($_.Exception.Message)" -Level 'WARN'
            Add-Result -Section 'Capabilities' -Item $cap -Status 'WARN' -Detail $_.Exception.Message
        }
    }
}

function Remove-McAfeeProducts {
    Write-Log "--- McAfee removal ---" -Level 'SECTION'

    $uninstallPaths = @(
        'HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*',
        'HKLM:\Software\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*'
    )

    $mcafeeEntries = foreach ($path in $uninstallPaths) {
        Get-ItemProperty $path -ErrorAction SilentlyContinue |
            Where-Object { $_.DisplayName -like '*McAfee*' }
    }

    if (-not $mcafeeEntries) {
        Write-Log "No McAfee products found."
        Add-Result -Section 'McAfee' -Item 'McAfee Products' -Status 'SKIPPED' -Detail 'Not installed'
        return
    }

    foreach ($entry in $mcafeeEntries) {
        $displayName     = $entry.DisplayName
        $uninstallString = $entry.UninstallString
        Write-Log "Found: $displayName"

        if (-not $uninstallString) {
            Write-Log "No uninstall string for $displayName - skipping." -Level 'WARN'
            Add-Result -Section 'McAfee' -Item $displayName -Status 'WARN' -Detail 'No uninstall string'
            continue
        }

        try {
            if ($uninstallString -match '^"([^"]+)"\s*(.*)$') {
                $exe  = $Matches[1]
                $args = $Matches[2]
            } else {
                $parts = $uninstallString.Split(' ', 2)
                $exe   = $parts[0]
                $args  = if ($parts.Length -gt 1) { $parts[1] } else { '' }
            }
            if ($args -notmatch '/S|/silent|/quiet') { $args += ' /S /quiet' }

            Write-Log "Uninstalling: $displayName"
            Start-Process -FilePath $exe -ArgumentList $args -Wait -WindowStyle Hidden -ErrorAction Stop
            Write-Log "Removed: $displayName" -Level 'SUCCESS'
            $script:Summary.McAfeeRemoved++
            Add-Result -Section 'McAfee' -Item $displayName -Status 'OK' -Detail 'Uninstalled'
        }
        catch {
            Write-Log "Failed to uninstall $displayName`: $($_.Exception.Message)" -Level 'ERROR'
            Add-Result -Section 'McAfee' -Item $displayName -Status 'FAILED' -Detail $_.Exception.Message
        }
    }
}

# ================================
# Application Installation
# ================================

function Install-StandardApps {
    Write-Log "--- Application installation ---" -Level 'SECTION'

    $alreadyInstalledCode = -1978335189   # winget 0x8A15002B

    $appsToInstall = @(
        # ---- Security & Maintenance ----
        @{ Id = 'Malwarebytes.Malwarebytes';          Name = 'Malwarebytes'                  },
        @{ Id = 'BleachBit.BleachBit';                Name = 'BleachBit'                     },

        # ---- Browsers & Productivity ----
        @{ Id = 'Google.Chrome';                      Name = 'Google Chrome'                 },
        @{ Id = 'Adobe.Acrobat.Reader.64-bit';        Name = 'Adobe Acrobat Reader (64-bit)' },
        @{ Id = '7zip.7zip';                          Name = '7-Zip'                         },
        @{ Id = 'VideoLAN.VLC';                       Name = 'VLC Media Player'              },

        # ---- .NET Runtimes ----
        @{ Id = 'Microsoft.DotNet.Framework.4.8';     Name = '.NET Framework 4.8'            },
        @{ Id = 'Microsoft.DotNet.DesktopRuntime.6';  Name = '.NET 6 Desktop Runtime'        },
        @{ Id = 'Microsoft.DotNet.DesktopRuntime.7';  Name = '.NET 7 Desktop Runtime'        },
        @{ Id = 'Microsoft.DotNet.DesktopRuntime.8';  Name = '.NET 8 Desktop Runtime'        },

        # ---- Visual C++ Redistributables ----
        @{ Id = 'Microsoft.VCRedist.2015+.x64';       Name = 'VC++ 2015-2022 Redist (x64)'  },
        @{ Id = 'Microsoft.VCRedist.2015+.x86';       Name = 'VC++ 2015-2022 Redist (x86)'  }
    )

    $total = $appsToInstall.Count

    foreach ($app in $appsToInstall) {
        Write-Log "Installing: $($app.Name)  [$($app.Id)]"
        try {
            winget install --id $app.Id --source winget `
                --accept-package-agreements --accept-source-agreements `
                --silent 2>&1 | Out-Null

            if ($LASTEXITCODE -eq 0) {
                Write-Log "OK: $($app.Name)" -Level 'SUCCESS'
                Add-Result -Section 'App Install' -Item $app.Name -Status 'OK' -Detail 'Installed'
                $script:Summary.AppsInstalled++
            } elseif ($LASTEXITCODE -eq $alreadyInstalledCode) {
                Write-Log "Already installed: $($app.Name)" -Level 'SUCCESS'
                Add-Result -Section 'App Install' -Item $app.Name -Status 'OK' -Detail 'Already installed'
                $script:Summary.AppsInstalled++
            } else {
                Write-Log "Failed: $($app.Name) - exit code $LASTEXITCODE" -Level 'WARN'
                Add-Result -Section 'App Install' -Item $app.Name -Status 'WARN' -Detail "Exit code $LASTEXITCODE"
                $script:Summary.AppsFailed++
            }
        }
        catch {
            Write-Log "Error installing $($app.Name): $($_.Exception.Message)" -Level 'ERROR'
            Add-Result -Section 'App Install' -Item $app.Name -Status 'FAILED' -Detail $_.Exception.Message
            $script:Summary.AppsFailed++
        }
    }

    Write-Log "App install: $($script:Summary.AppsInstalled)/$total OK, $($script:Summary.AppsFailed) failed."
}

# ================================
# System Configuration
# ================================

function Set-SystemConfiguration {
    Write-Log "--- System configuration ---" -Level 'SECTION'

    Set-RegistryValue -Path 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\DataCollection' `
                      -Name 'AllowTelemetry' -Value 0

    Set-RegistryValue -Path 'HKLM:\SOFTWARE\Microsoft\Windows\Windows Error Reporting' `
                      -Name 'Disabled' -Value 1

    Set-RegistryValue -Path 'HKLM:\SOFTWARE\Microsoft\SQMClient\Windows' `
                      -Name 'CEIPEnable' -Value 0

    Set-RegistryValue -Path 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\AdvertisingInfo' `
                      -Name 'DisabledByGroupPolicy' -Value 1

    Write-Log "System configuration complete." -Level 'SUCCESS'
}

# ================================
# HTML Report Generator
# ================================

function Export-HtmlReport {
    param([string]$OverallStatus)
    Write-Log "Generating HTML report: $ReportPath"

    $os          = Get-CimInstance Win32_OperatingSystem
    $cpu         = (Get-CimInstance Win32_Processor | Select-Object -First 1).Name
    $ramGB       = [math]::Round($os.TotalVisibleMemorySize / 1MB, 1)
    $uptimeHrs   = [math]::Round(((Get-Date) - $os.LastBootUpTime).TotalHours, 1)
    $duration    = (Get-Date) - $script:StartTime
    $durationFmt = '{0:mm}m {0:ss}s' -f $duration
    $timestamp   = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'

    $badgeColor = switch ($OverallStatus) {
        'SUCCESS' { '#22c55e' }
        'WARNING' { '#f59e0b' }
        default   { '#ef4444' }
    }

    # Build result table rows grouped by section
    $sections  = $script:Results | Group-Object { $_.Section }
    $tableRows = foreach ($section in $sections) {
        "<tr class='section-header'><td colspan='3'>$($section.Name)</td></tr>"
        foreach ($r in $section.Group) {
            $css  = switch ($r.Status) { 'OK'{'status-ok'} 'SKIPPED'{'status-skipped'} 'WARN'{'status-warn'} 'FAILED'{'status-failed'} }
            $icon = switch ($r.Status) { 'OK'{'&#10003;'}  'SKIPPED'{'&#8212;'}        'WARN'{'&#9888;'}     'FAILED'{'&#10007;'}      }
            "<tr><td>$($r.Item)</td><td class='$css'>$icon $($r.Status)</td><td>$($r.Detail)</td></tr>"
        }
    }

    # Build event log rows (last 200 entries)
    $logRows = ($script:EventLog | Select-Object -Last 200) | ForEach-Object {
        $css = switch ($_.Level) { 'ERROR'{'log-error'} 'WARN'{'log-warn'} 'SUCCESS'{'log-success'} 'SECTION'{'log-section'} default{''} }
        "<tr class='$css'><td>$($_.Timestamp)</td><td>$($_.Level)</td><td>$($_.Message)</td></tr>"
    }

    $html = @"
<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<title>DeployWorkstation Report - $env:COMPUTERNAME</title>
<style>
  :root {
    --bg:      #0f172a; --surface: #1e293b; --border: #334155;
    --text:    #e2e8f0; --muted:   #94a3b8;
    --ok:      #22c55e; --warn:    #f59e0b; --fail:   #ef4444;
    --skip:    #64748b; --accent:  #38bdf8;
  }
  * { box-sizing: border-box; margin: 0; padding: 0; }
  body { background: var(--bg); color: var(--text); font-family: 'Segoe UI', system-ui, sans-serif;
         font-size: 14px; padding: 32px 24px; max-width: 1100px; margin: 0 auto; }
  h1   { font-size: 1.6rem; font-weight: 700; margin-bottom: 4px; }
  h2   { font-size: 1.05rem; font-weight: 600; color: var(--accent); margin: 28px 0 12px; }
  .subtitle { color: var(--muted); font-size: 0.85rem; margin-bottom: 24px; }
  .badge { display: inline-block; padding: 6px 20px; border-radius: 9999px; font-weight: 700;
           font-size: 0.9rem; color: #fff; background: $badgeColor; margin-bottom: 28px; }
  /* Info grid */
  .info-grid { display: grid; grid-template-columns: repeat(auto-fill, minmax(200px,1fr)); gap: 12px; margin-bottom: 28px; }
  .info-card { background: var(--surface); border: 1px solid var(--border); border-radius: 8px; padding: 14px 16px; }
  .info-card .label { font-size: 0.72rem; color: var(--muted); text-transform: uppercase; letter-spacing: .05em; }
  .info-card .value { font-size: 0.95rem; font-weight: 600; margin-top: 4px; }
  /* Counters */
  .counter-grid { display: grid; grid-template-columns: repeat(auto-fill, minmax(155px,1fr)); gap: 12px; margin-bottom: 28px; }
  .counter-card { background: var(--surface); border: 1px solid var(--border); border-radius: 8px;
                  padding: 16px; text-align: center; }
  .counter-card .num { font-size: 2rem; font-weight: 700; line-height: 1; }
  .counter-card .lbl { font-size: 0.72rem; color: var(--muted); margin-top: 6px; }
  .num-ok   { color: var(--ok);    }
  .num-warn { color: var(--warn);  }
  .num-fail { color: var(--fail);  }
  .num-info { color: var(--accent);}
  /* Tables */
  .table-wrap { background: var(--surface); border: 1px solid var(--border);
                border-radius: 8px; overflow: hidden; margin-bottom: 28px; }
  table  { width: 100%; border-collapse: collapse; }
  th     { background: #0f172a; color: var(--muted); text-transform: uppercase;
           font-size: 0.72rem; letter-spacing: .06em; padding: 10px 14px; text-align: left; }
  td     { padding: 9px 14px; border-top: 1px solid var(--border); vertical-align: top; word-break: break-all; }
  tr:hover td { background: rgba(255,255,255,.03); }
  tr.section-header td { background: #0f172a; color: var(--accent); font-weight: 600;
                         font-size: 0.78rem; text-transform: uppercase; letter-spacing: .06em; padding: 8px 14px; }
  .status-ok      { color: var(--ok);   font-weight: 600; }
  .status-skipped { color: var(--skip); }
  .status-warn    { color: var(--warn); font-weight: 600; }
  .status-failed  { color: var(--fail); font-weight: 600; }
  tr.log-error   td { color: var(--fail);   }
  tr.log-warn    td { color: var(--warn);   }
  tr.log-success td { color: var(--ok);     }
  tr.log-section td { color: var(--accent); font-weight: 600; }
  /* Collapsible log */
  details summary { cursor: pointer; color: var(--accent); font-weight: 600;
                    font-size: 1.05rem; margin: 28px 0 12px; user-select: none; }
  footer { margin-top: 40px; color: var(--muted); font-size: 0.78rem; text-align: center; }
</style>
</head>
<body>

<h1>&#128187; DeployWorkstation Report</h1>
<div class="subtitle">Generated $timestamp &nbsp;|&nbsp; Pacific Northwest Computers</div>
<div class="badge">$OverallStatus</div>

<h2>System Information</h2>
<div class="info-grid">
  <div class="info-card"><div class="label">Hostname</div><div class="value">$env:COMPUTERNAME</div></div>
  <div class="info-card"><div class="label">Operating System</div><div class="value">$($os.Caption)</div></div>
  <div class="info-card"><div class="label">CPU</div><div class="value">$cpu</div></div>
  <div class="info-card"><div class="label">RAM</div><div class="value">$ramGB GB</div></div>
  <div class="info-card"><div class="label">System Uptime</div><div class="value">$uptimeHrs hrs</div></div>
  <div class="info-card"><div class="label">Script Run Time</div><div class="value">$durationFmt</div></div>
  <div class="info-card"><div class="label">Script Version</div><div class="value">5.0</div></div>
  <div class="info-card"><div class="label">Technician</div><div class="value">PNWC</div></div>
</div>

<h2>Summary</h2>
<div class="counter-grid">
  <div class="counter-card"><div class="num num-ok">$($script:Summary.AppsInstalled)</div><div class="lbl">Apps Installed / OK</div></div>
  <div class="counter-card"><div class="num num-fail">$($script:Summary.AppsFailed)</div><div class="lbl">Apps Failed</div></div>
  <div class="counter-card"><div class="num num-info">$($script:Summary.AppxRemoved)</div><div class="lbl">Appx Removed</div></div>
  <div class="counter-card"><div class="num num-info">$($script:Summary.CapabilitiesRemoved)</div><div class="lbl">Capabilities Removed</div></div>
  <div class="counter-card"><div class="num num-ok">$($script:Summary.HardeningApplied)</div><div class="lbl">Config Keys Set</div></div>
  <div class="counter-card"><div class="num num-warn">$($script:Summary.HardeningFailed)</div><div class="lbl">Config Keys Failed</div></div>
  <div class="counter-card"><div class="num num-info">$($script:Summary.McAfeeRemoved)</div><div class="lbl">McAfee Removed</div></div>
</div>

<h2>Detailed Results</h2>
<div class="table-wrap">
<table>
  <thead><tr><th>Item</th><th>Status</th><th>Detail</th></tr></thead>
  <tbody>
$($tableRows -join "`n")
  </tbody>
</table>
</div>

<details>
  <summary>&#128196; Full Event Log (last 200 entries)</summary>
  <div class="table-wrap">
  <table>
    <thead><tr><th>Timestamp</th><th>Level</th><th>Message</th></tr></thead>
    <tbody>
$($logRows -join "`n")
    </tbody>
  </table>
  </div>
</details>

<footer>Pacific Northwest Computers &nbsp;&bull;&nbsp; jon@pnwcomputers.com &nbsp;&bull;&nbsp; 360-624-7379</footer>
</body>
</html>
"@

    try {
        $html | Set-Content -Path $ReportPath -Encoding UTF8 -Force
        Write-Log "HTML report saved: $ReportPath" -Level 'SUCCESS'
    }
    catch {
        Write-Log "Failed to write HTML report: $($_.Exception.Message)" -Level 'WARN'
    }
}

# ================================
# JSON Config Export
# ================================

function Export-JsonArtifact {
    param([string]$OverallStatus)
    Write-Log "Generating JSON export: $JsonPath"

    $os       = Get-CimInstance Win32_OperatingSystem
    $cpu      = (Get-CimInstance Win32_Processor | Select-Object -First 1).Name
    $ramGB    = [math]::Round($os.TotalVisibleMemorySize / 1MB, 1)
    $duration = [math]::Round(((Get-Date) - $script:StartTime).TotalSeconds, 1)

    $export = [ordered]@{
        schema          = 'pnwc-deploy-v1'
        generatedAt     = (Get-Date -Format 'o')
        durationSeconds = $duration
        overallStatus   = $OverallStatus
        scriptVersion   = '5.0'
        system          = [ordered]@{
            hostname  = $env:COMPUTERNAME
            os        = $os.Caption
            osVersion = $os.Version
            cpu       = $cpu
            ramGB     = $ramGB
        }
        summary         = $script:Summary
        results         = @($script:Results | ForEach-Object {
            [ordered]@{
                section = $_.Section
                item    = $_.Item
                status  = $_.Status
                detail  = $_.Detail
            }
        })
    }

    try {
        $export | ConvertTo-Json -Depth 6 |
            Set-Content -Path $JsonPath -Encoding UTF8 -Force
        Write-Log "JSON export saved: $JsonPath" -Level 'SUCCESS'
    }
    catch {
        Write-Log "Failed to write JSON export: $($_.Exception.Message)" -Level 'WARN'
    }
}

# ================================
# Console Summary
# ================================

function Write-ConsoleSummary {
    $border = '=' * 52
    Write-Log $border -Level 'SECTION'
    Write-Log 'DEPLOYMENT SUMMARY' -Level 'SECTION'
    Write-Log $border -Level 'SECTION'
    Write-Log "Apps installed / skipped  : $($script:Summary.AppsInstalled)"
    Write-Log "Apps failed               : $($script:Summary.AppsFailed)"
    Write-Log "Appx packages removed     : $($script:Summary.AppxRemoved)"
    Write-Log "Capabilities removed      : $($script:Summary.CapabilitiesRemoved)"
    Write-Log "Config keys applied       : $($script:Summary.HardeningApplied)"
    Write-Log "Config keys failed        : $($script:Summary.HardeningFailed)"
    Write-Log "McAfee products removed   : $($script:Summary.McAfeeRemoved)"
    Write-Log $border -Level 'SECTION'
}

# ================================
# Main Execution
# ================================

try {
    if (-not (Test-Winget)) {
        Write-Log "Winget is required. Install 'App Installer' from the Microsoft Store." -Level 'ERROR'
        exit 1
    }

    Initialize-WingetSources

    if (-not $SkipBloatwareRemoval) {
        Write-Log "=== BLOATWARE REMOVAL ===" -Level 'SECTION'
        $bloatwarePatterns = @(
            'Copilot', 'Outlook', 'Quick Assist', 'Remote Desktop',
            'Mixed Reality Portal', 'Clipchamp', 'Xbox', 'Family',
            'Skype', 'LinkedIn', 'OneDrive', 'Teams'
        )
        Remove-WingetApps -AppPatterns $bloatwarePatterns
        Remove-AppxPackages
        Remove-WindowsCapabilities
        Remove-McAfeeProducts
        Write-Log "=== BLOATWARE REMOVAL COMPLETE ===" -Level 'SUCCESS'
    } else {
        Write-Log "Bloatware removal skipped (-SkipBloatwareRemoval)."
    }

    if (-not $SkipAppInstall) {
        Write-Log "=== APP INSTALLATION ===" -Level 'SECTION'
        Install-StandardApps
        Write-Log "=== APP INSTALLATION COMPLETE ===" -Level 'SUCCESS'
    } else {
        Write-Log "App installation skipped (-SkipAppInstall)."
    }

    if (-not $SkipSystemConfig) {
        Write-Log "=== SYSTEM CONFIGURATION ===" -Level 'SECTION'
        Set-SystemConfiguration
        Write-Log "=== SYSTEM CONFIGURATION COMPLETE ===" -Level 'SUCCESS'
    } else {
        Write-Log "System configuration skipped (-SkipSystemConfig)."
    }

    Write-ConsoleSummary

    $overallStatus = if ($script:Summary.AppsFailed -gt 0 -or $script:Summary.HardeningFailed -gt 0) {
        'WARNING'
    } else {
        'SUCCESS'
    }

    Export-HtmlReport   -OverallStatus $overallStatus
    Export-JsonArtifact -OverallStatus $overallStatus

    Write-Log "===== DeployWorkstation.ps1 Completed =====" -Level 'SUCCESS'
    Write-Host "`n*** Setup complete! ***" -ForegroundColor Green
    Write-Host "    Log    : $LogPath"    -ForegroundColor Gray
    Write-Host "    Report : $ReportPath" -ForegroundColor Cyan
    Write-Host "    JSON   : $JsonPath"   -ForegroundColor Gray
    Write-Host "`nPress Enter to exit..." -ForegroundColor Yellow
    Read-Host | Out-Null
}
catch {
    Write-Log "CRITICAL ERROR: $($_.Exception.Message)" -Level 'ERROR'
    # Still attempt reports on failure so you have something to hand the client
    try {
        Export-HtmlReport   -OverallStatus 'FAILED'
        Export-JsonArtifact -OverallStatus 'FAILED'
    } catch {}
    Write-Host "`n*** Setup failed - see log: $LogPath ***" -ForegroundColor Red
    exit 1
}
finally {
    $ProgressPreference = 'Continue'
}
