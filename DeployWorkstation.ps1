# DeployWorkstation.ps1 – Optimized Win10/11 Setup & Clean-up
# Version: 6.0 – PNWC Edition
# New in 6.0: Write-Progress console bars, embedded en-US / es-ES localization

#Requires -Version 5.1
#Requires -RunAsAdministrator

[CmdletBinding()]
param(
    [string]$LogPath,
    [string]$ReportPath,
    [switch]$SkipAppInstall,
    [switch]$SkipBloatwareRemoval,
    [switch]$SkipSystemConfig
)

# ================================
# Configuration & Setup
# ================================

$ErrorActionPreference = 'Continue'
$ProgressPreference    = 'Continue'          # Must be Continue for Write-Progress to render
$script:StartTime      = Get-Date

# $PSScriptRoot is read-only in PS5.1 — use a separate variable for fallback safety
$scriptRoot = if ($PSScriptRoot) { $PSScriptRoot } else { Split-Path -Parent $MyInvocation.MyCommand.Path }

if (-not $LogPath)    { $LogPath    = Join-Path $scriptRoot 'DeployWorkstation.log'  }
if (-not $ReportPath) { $ReportPath = Join-Path $scriptRoot 'DeployWorkstation.html' }

# --------------------------------
# Restart in Windows PowerShell 5.1 if running under PS Core
# --------------------------------
if ($PSVersionTable.PSEdition -eq 'Core') {
    Write-Warning 'PowerShell Core detected. Restarting in Windows PowerShell 5.1...'
    # Wrap path values in escaped quotes so spaces in paths survive Start-Process argument joining
    $params = @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', "`"$PSCommandPath`"",
                '-LogPath', "`"$LogPath`"", '-ReportPath', "`"$ReportPath`"")
    if ($SkipAppInstall)       { $params += '-SkipAppInstall' }
    if ($SkipBloatwareRemoval) { $params += '-SkipBloatwareRemoval' }
    if ($SkipSystemConfig)     { $params += '-SkipSystemConfig' }
    Start-Process -FilePath 'powershell.exe' -ArgumentList $params -Verb RunAs
    exit
}

# ================================
# Localization
# ================================
# Auto-detected from Get-Culture, falls back to en-US.
# To add a new language: copy the en-US block, change the key, translate the values.
# Progress bars, log messages, summary labels, and HTML report headings are all localized.

$script:Strings = @{

    'en-US' = @{
        # Startup
        Started           = 'DeployWorkstation v6.0 Started'
        WingetRequired    = "Winget is required. Install 'App Installer' from the Microsoft Store."
        WingetFound       = 'Winget found'
        WingetMissing     = 'Winget not found on PATH.'
        ManagingSources   = 'Managing winget sources'
        ProgSources       = 'Managing Winget Sources'
        RemovingMsstore   = 'Removing msstore source (performance)'
        RefreshingSources = 'Refreshing winget source index'
        SourcesFailed     = 'Could not manage winget sources'

        # Phase names (console + progress bar)
        PhaseBloatware    = 'BLOATWARE REMOVAL'
        PhaseApps         = 'APP INSTALLATION'
        PhaseConfig       = 'SYSTEM CONFIGURATION'
        PhaseReporting    = 'GENERATING REPORT'

        # Skip messages
        SkipBloatware     = 'Bloatware removal skipped (-SkipBloatwareRemoval).'
        SkipApps          = 'App installation skipped (-SkipAppInstall).'
        SkipConfig        = 'System configuration skipped (-SkipSystemConfig).'

        # Progress bar activity labels
        ProgOverall       = 'Deploying Workstation'
        ProgBloatware     = 'Removing Bloatware'
        ProgAppx          = 'Removing Appx Packages'
        ProgCaps          = 'Removing Windows Capabilities'
        ProgMcAfee        = 'Checking for McAfee'
        ProgApps          = 'Installing Applications'
        ProgConfig        = 'Configuring System'

        # Item-level actions / outcomes
        Checking          = 'Checking'
        NotFound          = 'Not found'
        Removing          = 'Removing'
        Removed           = 'Removed'
        RemoveExitCode    = 'Removal exit code'
        RemoveError       = 'Error removing'
        AppxRemoving      = 'Removing Appx'
        AppxProvRemoving  = 'Removing provisioned'
        NotInstalled      = 'Not installed'
        Installing        = 'Installing'
        InstallOK         = 'OK'
        AlreadyInstalled  = 'Already installed'
        InstallFail       = 'Failed'
        InstallError      = 'Error installing'
        CapRemoving       = 'Removing capability'
        CapError          = 'Error with capability'
        McAfeeNone        = 'No McAfee products found.'
        McAfeeFound       = 'Found'
        McAfeeNoStr       = 'No uninstall string'
        McAfeeUninstall   = 'Uninstalling'
        McAfeeRemoved     = 'Removed'
        McAfeeFailed      = 'Failed to uninstall'
        RegistryOK        = 'Registry OK'
        RegistryFail      = 'Registry FAIL'
        SysConfigDone     = 'System configuration complete.'

        # Summary labels
        SumTitle          = 'DEPLOYMENT SUMMARY'
        SumAppsOK         = 'Apps installed / skipped'
        SumAppsFail       = 'Apps failed'
        SumAppx           = 'Appx packages removed'
        SumCaps           = 'Capabilities removed'
        SumConfigOK       = 'Config keys applied'
        SumConfigFail     = 'Config keys failed'
        SumMcAfee         = 'McAfee products removed'

        # Completion
        Completed         = 'DeployWorkstation.ps1 Completed'
        SetupComplete     = 'Setup complete!'
        SetupFailed       = 'Setup failed - see log'
        PressEnter        = 'Press Enter to exit...'
        ReportSaved       = 'HTML report saved'
        ReportFail        = 'Failed to write HTML report'
        CriticalError     = 'CRITICAL ERROR'

        # Progress — winget init & report steps
        ProgWingetCheck   = 'Checking Winget'
        ProgSourcesList   = 'Listing sources'
        ProgSourcesUpdate = 'Updating sources'
        ProgReportCollect = 'Collecting system info'
        ProgReportBuild   = 'Building report'
        ProgReportWrite   = 'Writing report file'

        # HTML report headings
        HtmlTitle         = 'DeployWorkstation Report'
        HtmlGenerated     = 'Generated'
        HtmlSysInfo       = 'System Information'
        HtmlSummary       = 'Summary'
        HtmlResults       = 'Detailed Results'
        HtmlEventLog      = 'Full Event Log (last 200 entries)'
        HtmlHostname      = 'Hostname'
        HtmlOS            = 'Operating System'
        HtmlCPU           = 'CPU'
        HtmlRAM           = 'RAM'
        HtmlUptime        = 'System Uptime'
        HtmlRunTime       = 'Script Run Time'
        HtmlVersion       = 'Script Version'
        HtmlTechnician    = 'Technician'
        HtmlItem          = 'Item'
        HtmlStatus        = 'Status'
        HtmlDetail        = 'Detail'
        HtmlTimestamp     = 'Timestamp'
        HtmlLevel         = 'Level'
        HtmlMessage       = 'Message'
        HtmlAppsOK        = 'Apps Installed / OK'
        HtmlAppsFail      = 'Apps Failed'
        HtmlAppxRemoved   = 'Appx Removed'
        HtmlCapsRemoved   = 'Capabilities Removed'
        HtmlConfigOK      = 'Config Keys Set'
        HtmlConfigFail    = 'Config Keys Failed'
        HtmlMcAfee        = 'McAfee Removed'
        HtmlHrs           = 'hrs'
    }

    'es-ES' = @{
        # Startup
        Started           = 'DeployWorkstation v6.0 Iniciado'
        WingetRequired    = "Se requiere Winget. Instale 'App Installer' desde Microsoft Store."
        WingetFound       = 'Winget encontrado'
        WingetMissing     = 'Winget no encontrado en el PATH.'
        ManagingSources   = 'Administrando fuentes de winget'
        ProgSources       = 'Administrando Fuentes de Winget'
        RemovingMsstore   = 'Eliminando fuente msstore (rendimiento)'
        RefreshingSources = 'Actualizando indice de fuentes winget'
        SourcesFailed     = 'No se pudieron administrar las fuentes de winget'

        # Phase names
        PhaseBloatware    = 'ELIMINACION DE SOFTWARE NO DESEADO'
        PhaseApps         = 'INSTALACION DE APLICACIONES'
        PhaseConfig       = 'CONFIGURACION DEL SISTEMA'
        PhaseReporting    = 'GENERANDO INFORME'

        # Skip messages
        SkipBloatware     = 'Eliminacion de software omitida (-SkipBloatwareRemoval).'
        SkipApps          = 'Instalacion de aplicaciones omitida (-SkipAppInstall).'
        SkipConfig        = 'Configuracion del sistema omitida (-SkipSystemConfig).'

        # Progress bar activity labels
        ProgOverall       = 'Configurando Estacion de Trabajo'
        ProgBloatware     = 'Eliminando Software No Deseado'
        ProgAppx          = 'Eliminando Paquetes Appx'
        ProgCaps          = 'Eliminando Capacidades de Windows'
        ProgMcAfee        = 'Verificando McAfee'
        ProgApps          = 'Instalando Aplicaciones'
        ProgConfig        = 'Configurando Sistema'

        # Item-level actions / outcomes
        Checking          = 'Verificando'
        NotFound          = 'No encontrado'
        Removing          = 'Eliminando'
        Removed           = 'Eliminado'
        RemoveExitCode    = 'Codigo de salida de eliminacion'
        RemoveError       = 'Error al eliminar'
        AppxRemoving      = 'Eliminando Appx'
        AppxProvRemoving  = 'Eliminando paquete aprovisionado'
        NotInstalled      = 'No instalado'
        Installing        = 'Instalando'
        InstallOK         = 'OK'
        AlreadyInstalled  = 'Ya instalado'
        InstallFail       = 'Fallo'
        InstallError      = 'Error al instalar'
        CapRemoving       = 'Eliminando capacidad'
        CapError          = 'Error con capacidad'
        McAfeeNone        = 'No se encontraron productos McAfee.'
        McAfeeFound       = 'Encontrado'
        McAfeeNoStr       = 'Sin cadena de desinstalacion'
        McAfeeUninstall   = 'Desinstalando'
        McAfeeRemoved     = 'Eliminado'
        McAfeeFailed      = 'Error al desinstalar'
        RegistryOK        = 'Registro OK'
        RegistryFail      = 'Fallo de registro'
        SysConfigDone     = 'Configuracion del sistema completada.'

        # Summary labels
        SumTitle          = 'RESUMEN DE DESPLIEGUE'
        SumAppsOK         = 'Aplicaciones instaladas / omitidas'
        SumAppsFail       = 'Aplicaciones fallidas'
        SumAppx           = 'Paquetes Appx eliminados'
        SumCaps           = 'Capacidades eliminadas'
        SumConfigOK       = 'Claves de configuracion aplicadas'
        SumConfigFail     = 'Claves de configuracion fallidas'
        SumMcAfee         = 'Productos McAfee eliminados'

        # Completion
        Completed         = 'DeployWorkstation.ps1 Completado'
        SetupComplete     = 'Configuracion completada!'
        SetupFailed       = 'Configuracion fallida - ver registro'
        PressEnter        = 'Presione Enter para salir...'
        ReportSaved       = 'Informe HTML guardado'
        ReportFail        = 'Error al escribir el informe HTML'
        CriticalError     = 'ERROR CRITICO'

        # Progress — winget init & report steps
        ProgWingetCheck   = 'Verificando Winget'
        ProgSourcesList   = 'Listando fuentes'
        ProgSourcesUpdate = 'Actualizando fuentes'
        ProgReportCollect = 'Recopilando informacion del sistema'
        ProgReportBuild   = 'Construyendo informe'
        ProgReportWrite   = 'Escribiendo archivo de informe'

        # HTML report headings
        HtmlTitle         = 'Informe de DeployWorkstation'
        HtmlGenerated     = 'Generado'
        HtmlSysInfo       = 'Informacion del Sistema'
        HtmlSummary       = 'Resumen'
        HtmlResults       = 'Resultados Detallados'
        HtmlEventLog      = 'Registro de Eventos (ultimas 200 entradas)'
        HtmlHostname      = 'Nombre de Host'
        HtmlOS            = 'Sistema Operativo'
        HtmlCPU           = 'Procesador'
        HtmlRAM           = 'Memoria RAM'
        HtmlUptime        = 'Tiempo de Actividad'
        HtmlRunTime       = 'Tiempo de Ejecucion'
        HtmlVersion       = 'Version del Script'
        HtmlTechnician    = 'Tecnico'
        HtmlItem          = 'Elemento'
        HtmlStatus        = 'Estado'
        HtmlDetail        = 'Detalle'
        HtmlTimestamp     = 'Marca de Tiempo'
        HtmlLevel         = 'Nivel'
        HtmlMessage       = 'Mensaje'
        HtmlAppsOK        = 'Aplicaciones Instaladas / OK'
        HtmlAppsFail      = 'Aplicaciones Fallidas'
        HtmlAppxRemoved   = 'Appx Eliminados'
        HtmlCapsRemoved   = 'Capacidades Eliminadas'
        HtmlConfigOK      = 'Claves de Config. Aplicadas'
        HtmlConfigFail    = 'Claves de Config. Fallidas'
        HtmlMcAfee        = 'McAfee Eliminados'
        HtmlHrs           = 'hrs'
    }
}

# Resolve active language — exact match first, then primary tag, then en-US fallback
$culture      = (Get-Culture).Name          # e.g. 'es-ES', 'en-US'
$primaryTag   = $culture.Split('-')[0]      # e.g. 'es', 'en'
$resolvedLang = if ($script:Strings.ContainsKey($culture)) {
                    $culture
                } else {
                    $tagMatch = $script:Strings.Keys |
                                Where-Object { $_ -match "^$primaryTag-" } |
                                Select-Object -First 1
                    if ($tagMatch) { $tagMatch } else { 'en-US' }
                }
$script:Lang  = $script:Strings[$resolvedLang]

# T() — short translate helper used throughout the script
function T {
    param([string]$Key)
    if ($script:Lang.ContainsKey($Key)) { return $script:Lang[$Key] }
    return $Key   # fall back to the key name itself if missing
}

# ConvertTo-HtmlSafe — encodes special chars so exception messages / paths
# don't break the HTML report structure
function ConvertTo-HtmlSafe {
    param([string]$Text)
    if (-not $Text) { return '' }
    $Text -replace '&','&amp;' -replace '<','&lt;' -replace '>','&gt;' -replace '"','&quot;'
}

# ================================
# Logging
# ================================

$logDir = Split-Path $LogPath -Parent
if ($logDir -and -not (Test-Path $logDir)) {
    New-Item -Path $logDir -ItemType Directory -Force | Out-Null
}

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

# ================================
# Progress Bar Helpers
# ================================
# Two-tier layout:
#   ID 0 — overall deployment (phases, shown as % complete)
#   ID 1 — current phase items (child bar, shown as current item name)

function Set-OverallProgress {
    param(
        [string]$Status,
        [int]   $Percent
    )
    Write-Progress -Id 0 -Activity (T 'ProgOverall') -Status $Status -PercentComplete $Percent
}

function Set-PhaseProgress {
    param(
        [string]$Activity,
        [string]$Status,
        [int]   $Current,
        [int]   $Total
    )
    $pct = if ($Total -gt 0) { [int](($Current / $Total) * 100) } else { 0 }
    Write-Progress -Id 1 -ParentId 0 -Activity $Activity -Status $Status -PercentComplete $pct
}

function Clear-PhaseProgress {
    Write-Progress -Id 1 -Activity ' ' -Completed
}

# ================================
# Summary Counters & Results
# ================================

$script:Summary = @{
    AppsInstalled       = 0
    AppsFailed          = 0
    AppxRemoved         = 0
    CapabilitiesRemoved = 0
    McAfeeRemoved       = 0
    HardeningApplied    = 0
    HardeningFailed     = 0
}

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

Write-Log "===== $(T 'Started') =====" -Level 'SECTION'
Write-Log "PowerShell  : $($PSVersionTable.PSVersion)"
Write-Log "OS          : $((Get-CimInstance Win32_OperatingSystem).Caption)"
Write-Log "Hostname    : $env:COMPUTERNAME"
Write-Log "Language    : $resolvedLang"
Write-Log "Log file    : $LogPath"
Write-Log "HTML report : $ReportPath"

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
        Write-Log "$(T 'RegistryOK'): $Path\$Name = $Value" -Level 'SUCCESS'
        Add-Result -Section (T 'PhaseConfig') -Item $Name -Status 'OK' -Detail "$Path = $Value"
        $script:Summary.HardeningApplied++
    }
    catch {
        Write-Log "$(T 'RegistryFail'): $Path\$Name - $($_.Exception.Message)" -Level 'WARN'
        Add-Result -Section (T 'PhaseConfig') -Item $Name -Status 'WARN' -Detail $_.Exception.Message
        $script:Summary.HardeningFailed++
    }
}

# ================================
# Winget Management
# ================================

function Test-Winget {
    Set-PhaseProgress -Activity (T 'ProgWingetCheck') -Status (T 'Checking') -Current 1 -Total 1
    try {
        $null = Get-Command winget -ErrorAction Stop
        $version = (winget --version) -replace '[^\d\.]', ''
        Write-Log "$(T 'WingetFound'): v$version"
        Clear-PhaseProgress
        return $true
    }
    catch {
        Write-Log (T 'WingetMissing') -Level 'ERROR'
        Clear-PhaseProgress
        return $false
    }
}

function Initialize-WingetSources {
    Write-Log (T 'ManagingSources')
    try {
        Set-PhaseProgress -Activity (T 'ProgSources') -Status (T 'ProgSourcesList') -Current 1 -Total 2
        $sources = winget source list 2>$null

        if ($sources -match 'msstore') {
            # msstore present — extend to 3 steps
            Set-PhaseProgress -Activity (T 'ProgSources') -Status (T 'RemovingMsstore') -Current 2 -Total 3
            Write-Log (T 'RemovingMsstore')
            winget source remove --name msstore 2>$null | Out-Null
            Set-PhaseProgress -Activity (T 'ProgSources') -Status (T 'ProgSourcesUpdate') -Current 3 -Total 3
        } else {
            Set-PhaseProgress -Activity (T 'ProgSources') -Status (T 'ProgSourcesUpdate') -Current 2 -Total 2
        }

        Write-Log (T 'RefreshingSources')
        winget source update --name winget 2>$null | Out-Null
    }
    catch {
        Write-Log "$(T 'SourcesFailed'): $($_.Exception.Message)" -Level 'WARN'
    }
    finally {
        Clear-PhaseProgress
    }
}

# ================================
# Bloatware Removal
# ================================

function Remove-WingetApps {
    param([string[]]$AppPatterns)
    Write-Log "--- $(T 'ProgBloatware') ---" -Level 'SECTION'

    $total   = $AppPatterns.Count
    $current = 0

    foreach ($pattern in $AppPatterns) {
        $current++
        Set-PhaseProgress -Activity (T 'ProgBloatware') `
                          -Status   "$(T 'Checking'): $pattern" `
                          -Current  $current -Total $total

        Write-Log "$(T 'Checking'): $pattern"
        try {
            $found = winget list --name "$pattern" --accept-source-agreements 2>$null |
                     Where-Object { $_ -and $_ -notmatch 'Name\s+Id\s+Version' -and $_.Trim() }

            if (-not $found) {
                Write-Log "$(T 'NotFound'): $pattern"
                Add-Result -Section (T 'PhaseBloatware') -Item $pattern -Status 'SKIPPED' -Detail (T 'NotInstalled')
                continue
            }

            Set-PhaseProgress -Activity (T 'ProgBloatware') `
                              -Status   "$(T 'Removing'): $pattern" `
                              -Current  $current -Total $total

            winget uninstall --name "$pattern" --silent --force --accept-source-agreements 2>&1 | Out-Null

            if ($LASTEXITCODE -eq 0) {
                Write-Log "$(T 'Removed'): $pattern" -Level 'SUCCESS'
                Add-Result -Section (T 'PhaseBloatware') -Item $pattern -Status 'OK' -Detail (T 'Removed')
            } else {
                Write-Log "$(T 'RemoveExitCode') $LASTEXITCODE for: $pattern" -Level 'WARN'
                Add-Result -Section (T 'PhaseBloatware') -Item $pattern -Status 'WARN' -Detail "$(T 'RemoveExitCode') $LASTEXITCODE"
            }
        }
        catch {
            Write-Log "$(T 'RemoveError') $pattern`: $($_.Exception.Message)" -Level 'ERROR'
            Add-Result -Section (T 'PhaseBloatware') -Item $pattern -Status 'FAILED' -Detail $_.Exception.Message
        }
    }

    Clear-PhaseProgress
}

function Remove-AppxPackages {
    Write-Log "--- $(T 'ProgAppx') ---" -Level 'SECTION'

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

    $total   = $packagesToRemove.Count
    $current = 0

    foreach ($pattern in $packagesToRemove) {
        $current++
        $label = $pattern.Replace('*','')
        Set-PhaseProgress -Activity (T 'ProgAppx') -Status $label -Current $current -Total $total

        try {
            $removed = 0

            $pkgs = Get-AppxPackage -AllUsers -Name $pattern -ErrorAction SilentlyContinue
            foreach ($pkg in $pkgs) {
                Write-Log "$(T 'AppxRemoving'): $($pkg.Name)"
                Remove-AppxPackage -Package $pkg.PackageFullName -AllUsers -ErrorAction SilentlyContinue
                $script:Summary.AppxRemoved++
                $removed++
            }

            $provPkgs = Get-AppxProvisionedPackage -Online -ErrorAction SilentlyContinue |
                        Where-Object { $_.DisplayName -like $pattern }
            foreach ($pkg in $provPkgs) {
                Write-Log "$(T 'AppxProvRemoving'): $($pkg.DisplayName)"
                Remove-AppxProvisionedPackage -Online -PackageName $pkg.PackageName -ErrorAction SilentlyContinue
                $script:Summary.AppxRemoved++
                $removed++
            }

            $status = if ($removed -gt 0) { 'OK' } else { 'SKIPPED' }
            $detail = if ($removed -gt 0) { "$(T 'Removed') $removed" } else { T 'NotInstalled' }
            Add-Result -Section (T 'ProgAppx') -Item $label -Status $status -Detail $detail
        }
        catch {
            Write-Log "$(T 'RemoveError') $pattern`: $($_.Exception.Message)" -Level 'WARN'
            Add-Result -Section (T 'ProgAppx') -Item $label -Status 'WARN' -Detail $_.Exception.Message
        }
    }

    Clear-PhaseProgress
}

function Remove-WindowsCapabilities {
    Write-Log "--- $(T 'ProgCaps') ---" -Level 'SECTION'

    $capabilitiesToRemove = @(
        'App.Support.QuickAssist~~~~0.0.1.0',
        'App.Xbox.TCUI~~~~0.0.1.0',
        'App.XboxGameOverlay~~~~0.0.1.0',
        'App.XboxSpeechToTextOverlay~~~~0.0.1.0',
        'OpenSSH.Client~~~~0.0.1.0'
    )

    $total   = $capabilitiesToRemove.Count
    $current = 0

    foreach ($cap in $capabilitiesToRemove) {
        $current++
        Set-PhaseProgress -Activity (T 'ProgCaps') -Status $cap -Current $current -Total $total

        try {
            $state = Get-WindowsCapability -Online -Name $cap -ErrorAction SilentlyContinue
            if ($state -and $state.State -eq 'Installed') {
                Write-Log "$(T 'CapRemoving'): $cap"
                Remove-WindowsCapability -Online -Name $cap -ErrorAction SilentlyContinue | Out-Null
                $script:Summary.CapabilitiesRemoved++
                Add-Result -Section (T 'ProgCaps') -Item $cap -Status 'OK' -Detail (T 'Removed')
            } else {
                Write-Log "$(T 'NotInstalled'): $cap"
                Add-Result -Section (T 'ProgCaps') -Item $cap -Status 'SKIPPED' -Detail (T 'NotInstalled')
            }
        }
        catch {
            Write-Log "$(T 'CapError') $cap`: $($_.Exception.Message)" -Level 'WARN'
            Add-Result -Section (T 'ProgCaps') -Item $cap -Status 'WARN' -Detail $_.Exception.Message
        }
    }

    Clear-PhaseProgress
}

function Remove-McAfeeProducts {
    Write-Log "--- $(T 'ProgMcAfee') ---" -Level 'SECTION'

    Set-PhaseProgress -Activity (T 'ProgMcAfee') -Status (T 'Checking') -Current 1 -Total 2

    $uninstallPaths = @(
        'HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*',
        'HKLM:\Software\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*'
    )

    $mcafeeEntries = foreach ($path in $uninstallPaths) {
        Get-ItemProperty $path -ErrorAction SilentlyContinue |
            Where-Object { $_.DisplayName -like '*McAfee*' }
    }

    if (-not $mcafeeEntries) {
        Write-Log (T 'McAfeeNone')
        Add-Result -Section (T 'ProgMcAfee') -Item 'McAfee' -Status 'SKIPPED' -Detail (T 'NotInstalled')
        Clear-PhaseProgress
        return
    }

    $total   = @($mcafeeEntries).Count
    $current = 0

    foreach ($entry in $mcafeeEntries) {
        $current++
        $displayName     = $entry.DisplayName
        $uninstallString = $entry.UninstallString

        Set-PhaseProgress -Activity (T 'ProgMcAfee') -Status $displayName -Current $current -Total $total
        Write-Log "$(T 'McAfeeFound'): $displayName"

        if (-not $uninstallString) {
            Write-Log "$(T 'McAfeeNoStr') for $displayName" -Level 'WARN'
            Add-Result -Section (T 'ProgMcAfee') -Item $displayName -Status 'WARN' -Detail (T 'McAfeeNoStr')
            continue
        }

        try {
            if ($uninstallString -match '^"([^"]+)"\s*(.*)$') {
                $exe           = $Matches[1]
                $uninstallArgs = $Matches[2]
            } else {
                $parts         = $uninstallString.Split(' ', 2)
                $exe           = $parts[0]
                $uninstallArgs = if ($parts.Length -gt 1) { $parts[1] } else { '' }
            }
            if ($uninstallArgs -notmatch '/S|/silent|/quiet') { $uninstallArgs += ' /S /quiet' }

            Write-Log "$(T 'McAfeeUninstall'): $displayName"
            Start-Process -FilePath $exe -ArgumentList $uninstallArgs -Wait -WindowStyle Hidden -ErrorAction Stop
            Write-Log "$(T 'McAfeeRemoved'): $displayName" -Level 'SUCCESS'
            $script:Summary.McAfeeRemoved++
            Add-Result -Section (T 'ProgMcAfee') -Item $displayName -Status 'OK' -Detail (T 'McAfeeRemoved')
        }
        catch {
            Write-Log "$(T 'McAfeeFailed') $displayName`: $($_.Exception.Message)" -Level 'ERROR'
            Add-Result -Section (T 'ProgMcAfee') -Item $displayName -Status 'FAILED' -Detail $_.Exception.Message
        }
    }

    Clear-PhaseProgress
}

# ================================
# Application Installation
# ================================

function Install-StandardApps {
    Write-Log "--- $(T 'ProgApps') ---" -Level 'SECTION'

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

    $total   = $appsToInstall.Count
    $current = 0

    foreach ($app in $appsToInstall) {
        $current++
        Set-PhaseProgress -Activity (T 'ProgApps') `
                          -Status   "$(T 'Installing'): $($app.Name) ($current/$total)" `
                          -Current  $current -Total $total

        Write-Log "$(T 'Installing'): $($app.Name)  [$($app.Id)]"
        try {
            winget install --id $app.Id --source winget `
                --accept-package-agreements --accept-source-agreements `
                --silent 2>&1 | Out-Null

            if ($LASTEXITCODE -eq 0) {
                Write-Log "$(T 'InstallOK'): $($app.Name)" -Level 'SUCCESS'
                Add-Result -Section (T 'PhaseApps') -Item $app.Name -Status 'OK' -Detail (T 'InstallOK')
                $script:Summary.AppsInstalled++
            } elseif ($LASTEXITCODE -eq $alreadyInstalledCode) {
                Write-Log "$(T 'AlreadyInstalled'): $($app.Name)" -Level 'SUCCESS'
                Add-Result -Section (T 'PhaseApps') -Item $app.Name -Status 'OK' -Detail (T 'AlreadyInstalled')
                $script:Summary.AppsInstalled++
            } else {
                Write-Log "$(T 'InstallFail'): $($app.Name) - exit code $LASTEXITCODE" -Level 'WARN'
                Add-Result -Section (T 'PhaseApps') -Item $app.Name -Status 'WARN' -Detail "Exit code $LASTEXITCODE"
                $script:Summary.AppsFailed++
            }
        }
        catch {
            Write-Log "$(T 'InstallError') $($app.Name): $($_.Exception.Message)" -Level 'ERROR'
            Add-Result -Section (T 'PhaseApps') -Item $app.Name -Status 'FAILED' -Detail $_.Exception.Message
            $script:Summary.AppsFailed++
        }
    }

    Clear-PhaseProgress
    Write-Log "$(T 'PhaseApps'): $($script:Summary.AppsInstalled)/$total OK, $($script:Summary.AppsFailed) failed."
}

# ================================
# System Configuration
# ================================

function Set-SystemConfiguration {
    Write-Log "--- $(T 'ProgConfig') ---" -Level 'SECTION'

    $configItems = @(
        @{ Path = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\DataCollection'; Name = 'AllowTelemetry';         Value = 0 },
        @{ Path = 'HKLM:\SOFTWARE\Microsoft\Windows\Windows Error Reporting'; Name = 'Disabled';               Value = 1 },
        @{ Path = 'HKLM:\SOFTWARE\Microsoft\SQMClient\Windows';               Name = 'CEIPEnable';             Value = 0 },
        @{ Path = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\AdvertisingInfo'; Name = 'DisabledByGroupPolicy'; Value = 1 }
    )

    $total   = $configItems.Count
    $current = 0

    foreach ($item in $configItems) {
        $current++
        Set-PhaseProgress -Activity (T 'ProgConfig') -Status $item.Name -Current $current -Total $total
        Set-RegistryValue -Path $item.Path -Name $item.Name -Value $item.Value
    }

    Clear-PhaseProgress
    Write-Log (T 'SysConfigDone') -Level 'SUCCESS'
}

# ================================
# HTML Report Generator
# ================================

function Export-HtmlReport {
    param([string]$OverallStatus)
    Write-Log "$(T 'PhaseReporting')..."

    Set-PhaseProgress -Activity (T 'PhaseReporting') -Status (T 'ProgReportCollect') -Current 1 -Total 3

    $os          = Get-CimInstance Win32_OperatingSystem
    $cpu         = ConvertTo-HtmlSafe (Get-CimInstance Win32_Processor | Select-Object -First 1).Name
    $osCaption   = ConvertTo-HtmlSafe $os.Caption
    $ramGB       = [math]::Round($os.TotalVisibleMemorySize / 1MB, 1)
    $uptimeHrs   = [math]::Round(((Get-Date) - $os.LastBootUpTime).TotalHours, 1)
    $duration     = (Get-Date) - $script:StartTime
    $durationMins = [Math]::Floor($duration.TotalMinutes)
    $durationSecs = $duration.Seconds
    $durationFmt  = "${durationMins}m ${durationSecs}s"
    $timestamp    = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'

    Set-PhaseProgress -Activity (T 'PhaseReporting') -Status (T 'ProgReportBuild') -Current 2 -Total 3

    $badgeColor = switch ($OverallStatus) {
        'SUCCESS' { '#22c55e' }
        'WARNING' { '#f59e0b' }
        default   { '#ef4444' }
    }

    $sections  = $script:Results | Group-Object { $_.Section }
    $tableRows = foreach ($section in $sections) {
        "<tr class='section-header'><td colspan='3'>$(ConvertTo-HtmlSafe $section.Name)</td></tr>"
        foreach ($r in $section.Group) {
            $css  = switch ($r.Status) { 'OK'{'status-ok'} 'SKIPPED'{'status-skipped'} 'WARN'{'status-warn'} 'FAILED'{'status-failed'} }
            $icon = switch ($r.Status) { 'OK'{'&#10003;'}  'SKIPPED'{'&#8212;'}        'WARN'{'&#9888;'}     'FAILED'{'&#10007;'}      }
            "<tr><td>$(ConvertTo-HtmlSafe $r.Item)</td><td class='$css'>$icon $($r.Status)</td><td>$(ConvertTo-HtmlSafe $r.Detail)</td></tr>"
        }
    }

    $logRows = ($script:EventLog | Select-Object -Last 200) | ForEach-Object {
        $css = switch ($_.Level) { 'ERROR'{'log-error'} 'WARN'{'log-warn'} 'SUCCESS'{'log-success'} 'SECTION'{'log-section'} default{''} }
        "<tr class='$css'><td>$($_.Timestamp)</td><td>$($_.Level)</td><td>$(ConvertTo-HtmlSafe $_.Message)</td></tr>"
    }

    # Localized HTML labels
    $lHtmlTitle       = T 'HtmlTitle'
    $lGenerated       = T 'HtmlGenerated'
    $lSysInfo         = T 'HtmlSysInfo'
    $lSummary         = T 'HtmlSummary'
    $lResults         = T 'HtmlResults'
    $lEventLog        = T 'HtmlEventLog'
    $lHostname        = T 'HtmlHostname'
    $lOS              = T 'HtmlOS'
    $lCPU             = T 'HtmlCPU'
    $lRAM             = T 'HtmlRAM'
    $lUptime          = T 'HtmlUptime'
    $lRunTime         = T 'HtmlRunTime'
    $lVersion         = T 'HtmlVersion'
    $lTechnician      = T 'HtmlTechnician'
    $lItem            = T 'HtmlItem'
    $lStatus          = T 'HtmlStatus'
    $lDetail          = T 'HtmlDetail'
    $lTimestamp       = T 'HtmlTimestamp'
    $lLevel           = T 'HtmlLevel'
    $lMessage         = T 'HtmlMessage'
    $lAppsOK          = T 'HtmlAppsOK'
    $lAppsFail        = T 'HtmlAppsFail'
    $lAppxRemoved     = T 'HtmlAppxRemoved'
    $lCapsRemoved     = T 'HtmlCapsRemoved'
    $lConfigOK        = T 'HtmlConfigOK'
    $lConfigFail      = T 'HtmlConfigFail'
    $lMcAfee          = T 'HtmlMcAfee'
    $lHrs             = T 'HtmlHrs'

    $html = @"
<!DOCTYPE html>
<html lang="$resolvedLang">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<title>$lHtmlTitle - $env:COMPUTERNAME</title>
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
  .info-grid { display: grid; grid-template-columns: repeat(auto-fill, minmax(200px,1fr)); gap: 12px; margin-bottom: 28px; }
  .info-card { background: var(--surface); border: 1px solid var(--border); border-radius: 8px; padding: 14px 16px; }
  .info-card .label { font-size: 0.72rem; color: var(--muted); text-transform: uppercase; letter-spacing: .05em; }
  .info-card .value { font-size: 0.95rem; font-weight: 600; margin-top: 4px; }
  .counter-grid { display: grid; grid-template-columns: repeat(auto-fill, minmax(155px,1fr)); gap: 12px; margin-bottom: 28px; }
  .counter-card { background: var(--surface); border: 1px solid var(--border); border-radius: 8px;
                  padding: 16px; text-align: center; }
  .counter-card .num { font-size: 2rem; font-weight: 700; line-height: 1; }
  .counter-card .lbl { font-size: 0.72rem; color: var(--muted); margin-top: 6px; }
  .num-ok   { color: var(--ok);    }
  .num-warn { color: var(--warn);  }
  .num-fail { color: var(--fail);  }
  .num-info { color: var(--accent);}
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
  details summary { cursor: pointer; color: var(--accent); font-weight: 600;
                    font-size: 1.05rem; margin: 28px 0 12px; user-select: none; }
  footer { margin-top: 40px; color: var(--muted); font-size: 0.78rem; text-align: center; }
</style>
</head>
<body>

<h1>&#128187; $lHtmlTitle</h1>
<div class="subtitle">$lGenerated $timestamp &nbsp;|&nbsp; Pacific Northwest Computers</div>
<div class="badge">$OverallStatus</div>

<h2>$lSysInfo</h2>
<div class="info-grid">
  <div class="info-card"><div class="label">$lHostname</div><div class="value">$env:COMPUTERNAME</div></div>
  <div class="info-card"><div class="label">$lOS</div><div class="value">$osCaption</div></div>
  <div class="info-card"><div class="label">$lCPU</div><div class="value">$cpu</div></div>
  <div class="info-card"><div class="label">$lRAM</div><div class="value">$ramGB GB</div></div>
  <div class="info-card"><div class="label">$lUptime</div><div class="value">$uptimeHrs $lHrs</div></div>
  <div class="info-card"><div class="label">$lRunTime</div><div class="value">$durationFmt</div></div>
  <div class="info-card"><div class="label">$lVersion</div><div class="value">6.0</div></div>
  <div class="info-card"><div class="label">$lTechnician</div><div class="value">PNWC</div></div>
</div>

<h2>$lSummary</h2>
<div class="counter-grid">
  <div class="counter-card"><div class="num num-ok">$($script:Summary.AppsInstalled)</div><div class="lbl">$lAppsOK</div></div>
  <div class="counter-card"><div class="num num-fail">$($script:Summary.AppsFailed)</div><div class="lbl">$lAppsFail</div></div>
  <div class="counter-card"><div class="num num-info">$($script:Summary.AppxRemoved)</div><div class="lbl">$lAppxRemoved</div></div>
  <div class="counter-card"><div class="num num-info">$($script:Summary.CapabilitiesRemoved)</div><div class="lbl">$lCapsRemoved</div></div>
  <div class="counter-card"><div class="num num-ok">$($script:Summary.HardeningApplied)</div><div class="lbl">$lConfigOK</div></div>
  <div class="counter-card"><div class="num num-warn">$($script:Summary.HardeningFailed)</div><div class="lbl">$lConfigFail</div></div>
  <div class="counter-card"><div class="num num-info">$($script:Summary.McAfeeRemoved)</div><div class="lbl">$lMcAfee</div></div>
</div>

<h2>$lResults</h2>
<div class="table-wrap">
<table>
  <thead><tr><th>$lItem</th><th>$lStatus</th><th>$lDetail</th></tr></thead>
  <tbody>
$($tableRows -join "`n")
  </tbody>
</table>
</div>

<details>
  <summary>&#128196; $lEventLog</summary>
  <div class="table-wrap">
  <table>
    <thead><tr><th>$lTimestamp</th><th>$lLevel</th><th>$lMessage</th></tr></thead>
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
        Set-PhaseProgress -Activity (T 'PhaseReporting') -Status (T 'ProgReportWrite') -Current 3 -Total 3
        $html | Set-Content -Path $ReportPath -Encoding UTF8 -Force
        Write-Log "$(T 'ReportSaved'): $ReportPath" -Level 'SUCCESS'
    }
    catch {
        Write-Log "$(T 'ReportFail'): $($_.Exception.Message)" -Level 'WARN'
    }
    finally {
        Clear-PhaseProgress
    }
}

# ================================
# Console Summary
# ================================

function Write-ConsoleSummary {
    $border = '=' * 52
    Write-Log $border -Level 'SECTION'
    Write-Log (T 'SumTitle') -Level 'SECTION'
    Write-Log $border -Level 'SECTION'
    Write-Log "$( (T 'SumAppsOK')    ) : $($script:Summary.AppsInstalled)"
    Write-Log "$( (T 'SumAppsFail')  ) : $($script:Summary.AppsFailed)"
    Write-Log "$( (T 'SumAppx')      ) : $($script:Summary.AppxRemoved)"
    Write-Log "$( (T 'SumCaps')      ) : $($script:Summary.CapabilitiesRemoved)"
    Write-Log "$( (T 'SumConfigOK')  ) : $($script:Summary.HardeningApplied)"
    Write-Log "$( (T 'SumConfigFail')) : $($script:Summary.HardeningFailed)"
    Write-Log "$( (T 'SumMcAfee')    ) : $($script:Summary.McAfeeRemoved)"
    Write-Log $border -Level 'SECTION'
}

# ================================
# Main Execution
# ================================

# Overall progress weights (must total 100)
# Phases: Init=5, Bloatware=35, Apps=40, Config=15, Report=5
$script:PhasePct = @{ Init = 5; BloatStart = 5; BloatEnd = 40; AppsStart = 40; AppsEnd = 80; ConfigStart = 80; ConfigEnd = 95; Done = 100 }

try {
    Set-OverallProgress -Status (T 'ManagingSources') -Percent $script:PhasePct.Init

    if (-not (Test-Winget)) {
        Write-Log (T 'WingetRequired') -Level 'ERROR'
        throw 'Winget not available'
    }

    Initialize-WingetSources

    if (-not $SkipBloatwareRemoval) {
        Set-OverallProgress -Status (T 'PhaseBloatware') -Percent $script:PhasePct.BloatStart
        Write-Log "=== $(T 'PhaseBloatware') ===" -Level 'SECTION'
        $bloatwarePatterns = @(
            'Copilot', 'Outlook', 'Quick Assist', 'Remote Desktop',
            'Mixed Reality Portal', 'Clipchamp', 'Xbox', 'Family',
            'Skype', 'LinkedIn', 'OneDrive', 'Teams'
        )
        Remove-WingetApps -AppPatterns $bloatwarePatterns
        Remove-AppxPackages
        Remove-WindowsCapabilities
        Remove-McAfeeProducts
        Set-OverallProgress -Status "$(T 'PhaseBloatware') - Complete" -Percent $script:PhasePct.BloatEnd
        Write-Log "=== $(T 'PhaseBloatware') COMPLETE ===" -Level 'SUCCESS'
    } else {
        Write-Log (T 'SkipBloatware')
    }

    if (-not $SkipAppInstall) {
        Set-OverallProgress -Status (T 'PhaseApps') -Percent $script:PhasePct.AppsStart
        Write-Log "=== $(T 'PhaseApps') ===" -Level 'SECTION'
        Install-StandardApps
        Set-OverallProgress -Status "$(T 'PhaseApps') - Complete" -Percent $script:PhasePct.AppsEnd
        Write-Log "=== $(T 'PhaseApps') COMPLETE ===" -Level 'SUCCESS'
    } else {
        Write-Log (T 'SkipApps')
    }

    if (-not $SkipSystemConfig) {
        Set-OverallProgress -Status (T 'PhaseConfig') -Percent $script:PhasePct.ConfigStart
        Write-Log "=== $(T 'PhaseConfig') ===" -Level 'SECTION'
        Set-SystemConfiguration
        Set-OverallProgress -Status "$(T 'PhaseConfig') - Complete" -Percent $script:PhasePct.ConfigEnd
        Write-Log "=== $(T 'PhaseConfig') COMPLETE ===" -Level 'SUCCESS'
    } else {
        Write-Log (T 'SkipConfig')
    }

    Write-ConsoleSummary

    $overallStatus = if ($script:Summary.AppsFailed -gt 0 -or $script:Summary.HardeningFailed -gt 0) {
        'WARNING'
    } else {
        'SUCCESS'
    }

    Set-OverallProgress -Status (T 'PhaseReporting') -Percent $script:PhasePct.ConfigEnd
    Export-HtmlReport -OverallStatus $overallStatus
    Set-OverallProgress -Status (T 'Completed') -Percent $script:PhasePct.Done

    Write-Log "===== $(T 'Completed') =====" -Level 'SUCCESS'
    Write-Host "`n*** $(T 'SetupComplete') ***" -ForegroundColor Green
    Write-Host "    Log    : $LogPath"          -ForegroundColor Gray
    Write-Host "    Report : $ReportPath"       -ForegroundColor Cyan
    Write-Host "`n$(T 'PressEnter')"            -ForegroundColor Yellow
    Read-Host | Out-Null
}
catch {
    Write-Log "$(T 'CriticalError'): $($_.Exception.Message)" -Level 'ERROR'
    try { Export-HtmlReport -OverallStatus 'FAILED' } catch {}
    Write-Host "`n*** $(T 'SetupFailed'): $LogPath ***" -ForegroundColor Red
    exit 1
}
finally {
    # Always clear progress bars — runs on success, failure, and Ctrl+C
    Write-Progress -Id 1 -Activity ' ' -Completed
    Write-Progress -Id 0 -Activity ' ' -Completed
}
