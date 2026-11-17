# DeployWorkstation.ps1 – Optimized Win10/11 Setup & Clean-up
# Version: 5.4 – PNWC Edition 11.17.2026
# New in 5.0:  Write-Progress console bars, embedded en-US / es-ES localization
# New in 5.1:  Winget auto-bootstrap, install retry logic, WU guard, OEM OneDrive, edition awareness
# New in 5.11: App update mode (-UpdateApps), startup banner
# New in 5.2:  Updated .NET runtimes (8 LTS + 10 LTS); bug fixes in QuickStart.cmd,
#              winget version detection, CI workflow; code quality improvements
# New in 5.3:  Package ID auto-resolution (Resolve-WingetPackageId with per-app
#              fallback IDs + winget search suggestions); fixed .NET Framework ID
#              (Microsoft.DotNet.Framework.4.8 -> Microsoft.DotNet.Framework.Runtime);
#              corrected winget exit-code handling (reboot codes 0x8A150109/10A/10B
#              were misclassified as network errors and retried); reboot-required
#              installs now count as success + end-of-run restart notice;
#              --exact and --disable-interactivity on all winget install/upgrade calls
# New in 5.4:  Reliability pass — outdated winget is actually upgraded (or used in
#              compatibility mode), offline runs no longer misreport "ID not found",
#              "install in progress" / download failures are retried, McAfee MSI
#              uninstalls no longer hang, removal counters only count real removals,
#              exit code 2 on warnings, -NoPause switch, log fallback to ProgramData

#Requires -Version 5.1
#Requires -RunAsAdministrator

[CmdletBinding()]
param(
    [string]$LogPath,
    [string]$ReportPath,
    [switch]$SkipAppInstall,
    [switch]$SkipBloatwareRemoval,
    [switch]$SkipSystemConfig,
    [switch]$UpdateApps,
    [switch]$NoPause
)

# ================================
# Configuration & Setup
# ================================

$script:Version        = '5.4'
$ErrorActionPreference = 'Continue'
$ProgressPreference    = 'Continue'          # Must be Continue for Write-Progress to render
Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass -Force
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
    if ($UpdateApps)           { $params += '-UpdateApps' }
    if ($NoPause)              { $params += '-NoPause' }
    Start-Process -FilePath 'powershell.exe' -ArgumentList $params -Verb RunAs
    exit
}

# --------------------------------
# Log location — fall back to ProgramData when the script folder is read-only
# (e.g. a write-protected USB stick or a read-only network share)
# --------------------------------
try {
    $logDir = Split-Path $LogPath -Parent
    if ($logDir -and -not (Test-Path $logDir)) {
        New-Item -Path $logDir -ItemType Directory -Force -ErrorAction Stop | Out-Null
    }
    [System.IO.File]::AppendAllText($LogPath, '')
}
catch {
    $fallbackDir = Join-Path $env:ProgramData 'DeployWorkstation'
    New-Item -Path $fallbackDir -ItemType Directory -Force -ErrorAction SilentlyContinue | Out-Null
    Write-Warning "Cannot write log to '$LogPath' ($($_.Exception.Message)). Using '$fallbackDir' instead."
    $LogPath = Join-Path $fallbackDir (Split-Path $LogPath -Leaf)
}

# ── Startup Banner ───────────────────────────────────────────────────────────
# Pure-ASCII art — no UTF-8 box-drawing chars. Safe on PS 5.1 regardless of
# console codepage (some hosts decode as cp1252, producing mojibake with box-drawing).
try { $host.UI.RawUI.WindowTitle = "DeployWorkstation v$($script:Version)" } catch {}
Clear-Host
Write-Host ""
Write-Host "  ######   ##  ##   ##    ##   ######" -ForegroundColor Cyan
Write-Host "  ##  ##   ### ##   ##    ##   ##    " -ForegroundColor Cyan
Write-Host "  ######   ######   ## ## ##   ##    " -ForegroundColor Cyan
Write-Host "  ##       ## ###   ########   ##    " -ForegroundColor Cyan
Write-Host "  ##       ##  ##   ##    ##   ######" -ForegroundColor Cyan
Write-Host ""
Write-Host "  Pacific Northwest Computers" -ForegroundColor White
Write-Host "  Windows Workstation Deployment Toolkit" -ForegroundColor DarkGray
Write-Host ""
Write-Host ("=" * 70) -ForegroundColor DarkCyan
Write-Host "   DeployWorkstation v$($script:Version) -- Automated Win10/11 Setup & Hardening    " -ForegroundColor Cyan
Write-Host "   Pacific Northwest Computers  |  jon@pnwcomputers.com               " -ForegroundColor Gray
Write-Host "   Bloatware Removal  /  App Install  /  System Configuration         " -ForegroundColor DarkGray
Write-Host ("=" * 70) -ForegroundColor DarkCyan
Write-Host ""
Write-Host "  Started  : $(Get-Date -Format 'dddd MMMM dd yyyy  HH:mm:ss')" -ForegroundColor Gray
Write-Host "  Computer : $env:COMPUTERNAME" -ForegroundColor Gray
Write-Host "  Log      : $LogPath" -ForegroundColor Gray
Write-Host ""

# ================================
# Localization
# ================================
# Auto-detected from Get-Culture, falls back to en-US.
# To add a new language: copy the en-US block, change the key, translate the values.
# Progress bars, log messages, summary labels, and HTML report headings are all localized.

$script:Strings = @{

    'en-US' = @{
        # Startup
        Started           = 'DeployWorkstation v5.4 Started'
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

        # Winget bootstrap
        WingetOld         = 'Winget outdated, updating'
        WingetBootstrap   = 'Installing App Installer (winget)'
        WingetBootOK      = 'App Installer installed successfully'
        WingetBootFail    = 'Failed to install App Installer'
        WingetReRegister  = 'Attempting package re-registration'
        WingetDownload    = 'Downloading App Installer from Microsoft'

        # Reliability
        InstallRetrying   = 'Transient error, retrying'
        RebootToFinish    = 'Installed - restart required to finish'
        NotInstalledSkip  = 'Not installed on this machine, skipping'
        IdNotFound        = 'Package ID not found in winget source'
        IdChanged         = 'Package ID changed, using'
        IdCandidates      = 'Possible replacement IDs for'
        IdUnverified      = 'Could not verify package ID (winget source unreachable?) - attempting anyway'
        SumReboot         = '*** One or more installs require a RESTART to finish ***'
        SumAppsSkipped    = 'Apps skipped (not installed)'
        WingetCompat      = 'Could not upgrade winget - continuing in compatibility mode with'
        WingetRepair      = 'Attempting winget repair via Microsoft.WinGet.Client'
        AppxProtected     = 'Protected system package, cannot be removed'
        UninstallTimeout  = 'Uninstaller did not finish in time and was stopped'
        McAfeeHint        = 'If McAfee remains, use the McAfee Consumer Product Removal tool (MCPR)'
        CapWuUnavail      = 'Skipped - Windows Update not accessible on this system'
        HomeEditionNote   = 'Policy key written but has no effect on Windows Home edition'
        OneDriveOem       = 'OneDrive OEM binary removal'
        OneDriveOemFound  = 'Found OEM OneDrive binary'
        OneDriveOemDone   = 'OEM OneDrive uninstall completed'
        OneDriveOemNone   = 'No OEM OneDrive setup binary found'

        # HTML report additions
        HtmlEdition       = 'Edition'
        HtmlBuild         = 'Build'

        # Progress — winget init & report steps
        ProgWingetCheck   = 'Checking Winget'
        ProgSourcesList   = 'Listing sources'
        ProgSourcesUpdate = 'Updating sources'
        ProgReportCollect = 'Collecting system info'
        ProgReportBuild   = 'Building report'
        ProgReportWrite   = 'Writing report file'

        # Update mode
        PhaseUpdate       = 'APP UPDATE'
        ProgUpdate        = 'Updating Applications'
        Updating          = 'Updating'
        UpdateOK          = 'Updated'
        AlreadyUpToDate   = 'Already up to date'
        UpdateFail        = 'Update failed'
        UpdateError       = 'Error updating'
        SumAppsUpdated    = 'Apps updated'
        SumAppsUpdateFail = 'App updates failed'

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
        HtmlAppsUpdated   = 'Apps Updated / OK'
        HtmlAppsUpdFail   = 'App Updates Failed'
        HtmlAppsSkipped   = 'Apps Skipped'
        HtmlHrs           = 'hrs'
    }

    'es-ES' = @{
        # Startup
        Started           = 'DeployWorkstation v5.4 Iniciado'
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

        # Winget bootstrap
        WingetOld         = 'Winget desactualizado, actualizando'
        WingetBootstrap   = 'Instalando App Installer (winget)'
        WingetBootOK      = 'App Installer instalado exitosamente'
        WingetBootFail    = 'Error al instalar App Installer'
        WingetReRegister  = 'Intentando re-registro del paquete'
        WingetDownload    = 'Descargando App Installer de Microsoft'

        # Reliability
        InstallRetrying   = 'Error transitorio, reintentando'
        RebootToFinish    = 'Instalado - se requiere reinicio para finalizar'
        NotInstalledSkip  = 'No instalado en este equipo, omitiendo'
        IdNotFound        = 'ID de paquete no encontrado en la fuente winget'
        IdChanged         = 'ID de paquete cambiado, usando'
        IdCandidates      = 'Posibles IDs de reemplazo para'
        IdUnverified      = 'No se pudo verificar el ID del paquete (fuente winget inaccesible?) - intentando de todos modos'
        SumReboot         = '*** Una o mas instalaciones requieren REINICIO para finalizar ***'
        SumAppsSkipped    = 'Aplicaciones omitidas (no instaladas)'
        WingetCompat      = 'No se pudo actualizar winget - continuando en modo de compatibilidad con'
        WingetRepair      = 'Intentando reparar winget mediante Microsoft.WinGet.Client'
        AppxProtected     = 'Paquete de sistema protegido, no se puede eliminar'
        UninstallTimeout  = 'El desinstalador no termino a tiempo y fue detenido'
        McAfeeHint        = 'Si McAfee permanece, use la herramienta McAfee Consumer Product Removal (MCPR)'
        CapWuUnavail      = 'Omitido - Windows Update no accesible en este sistema'
        HomeEditionNote   = 'Clave de politica escrita pero sin efecto en Windows Home'
        OneDriveOem       = 'Eliminacion de OneDrive OEM'
        OneDriveOemFound  = 'Binario OEM de OneDrive encontrado'
        OneDriveOemDone   = 'Desinstalacion de OneDrive OEM completada'
        OneDriveOemNone   = 'No se encontro binario de configuracion de OneDrive OEM'

        # HTML report additions
        HtmlEdition       = 'Edicion'
        HtmlBuild         = 'Version de Compilacion'

        # Progress — winget init & report steps
        ProgWingetCheck   = 'Verificando Winget'
        ProgSourcesList   = 'Listando fuentes'
        ProgSourcesUpdate = 'Actualizando fuentes'
        ProgReportCollect = 'Recopilando informacion del sistema'
        ProgReportBuild   = 'Construyendo informe'
        ProgReportWrite   = 'Escribiendo archivo de informe'

        # Update mode
        PhaseUpdate       = 'ACTUALIZACION DE APLICACIONES'
        ProgUpdate        = 'Actualizando Aplicaciones'
        Updating          = 'Actualizando'
        UpdateOK          = 'Actualizado'
        AlreadyUpToDate   = 'Ya esta actualizado'
        UpdateFail        = 'Error en actualizacion'
        UpdateError       = 'Error al actualizar'
        SumAppsUpdated    = 'Aplicaciones actualizadas'
        SumAppsUpdateFail = 'Actualizaciones fallidas'

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
        HtmlAppsUpdated   = 'Aplicaciones Actualizadas / OK'
        HtmlAppsUpdFail   = 'Actualizaciones Fallidas'
        HtmlAppsSkipped   = 'Aplicaciones Omitidas'
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
    # Never let a log-file hiccup (USB pulled, AV lock) interrupt the deployment
    Add-Content -Path $LogPath -Value $logEntry -Encoding UTF8 -ErrorAction SilentlyContinue
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
    AppsSkipped         = 0
    AppsUpdated         = 0
    AppsUpdateFailed    = 0
    RebootNeeded        = $false
    AppxRemoved         = 0
    CapabilitiesRemoved = 0
    McAfeeRemoved       = 0
    HardeningApplied    = 0
    HardeningFailed     = 0
}

$script:Results = [System.Collections.Generic.List[hashtable]]::new()

# Update mode replaces the install phase, so summaries show update counters instead
$script:UpdateMode = [bool]($UpdateApps -and -not $SkipAppInstall)

# Applications managed by DeployWorkstation — used by both Install-StandardApps and Update-InstalledApps
#   Id        : primary winget package ID (verified against the winget source at run time)
#   Name      : display name (also used as the winget search term if all IDs fail to resolve)
#   Fallbacks : optional list of alternate IDs tried in order when the primary ID
#               no longer exists in the winget source (IDs get renamed/retired over time)
$script:ManagedApps = @(
    # ---- Security & Maintenance ----
    @{ Id = 'Malwarebytes.Malwarebytes';          Name = 'Malwarebytes'                  },
    @{ Id = 'BleachBit.BleachBit';                Name = 'BleachBit'                     },

    # ---- Browsers & Productivity ----
    @{ Id = 'Google.Chrome';                      Name = 'Google Chrome'
       Fallbacks = @('Google.Chrome.EXE')                                                },
    @{ Id = 'Adobe.Acrobat.Reader.64-bit';        Name = 'Adobe Acrobat Reader (64-bit)' },
    @{ Id = '7zip.7zip';                          Name = '7-Zip'                         },
    @{ Id = 'VideoLAN.VLC';                       Name = 'VLC Media Player'              },

    # ---- .NET Runtimes ----
    # NOTE: 'Microsoft.DotNet.Framework.4.8' was never a valid winget ID (it always
    # returns 0x8A150014 NO_APPLICATIONS_FOUND). The runtime package is
    # 'Microsoft.DotNet.Framework.Runtime' (currently 4.8.1). .NET Fx 4.8 also ships
    # in-box on Win10 1903+ and all Win11, so on modern builds this resolves to a no-op.
    @{ Id = 'Microsoft.DotNet.Framework.Runtime';  Name = '.NET Framework Runtime'
       Fallbacks = @('Microsoft.DotNet.Framework.DeveloperPack_4')                       },
    @{ Id = 'Microsoft.DotNet.DesktopRuntime.8';   Name = '.NET 8 Desktop Runtime'
       Fallbacks = @('Microsoft.DotNet.DesktopRuntime.8.x64')                            },
    @{ Id = 'Microsoft.DotNet.DesktopRuntime.10';  Name = '.NET 10 Desktop Runtime'
       Fallbacks = @('Microsoft.DotNet.DesktopRuntime.10.x64')                           },

    # ---- Visual C++ Redistributables ----
    @{ Id = 'Microsoft.VCRedist.2015+.x64';       Name = 'VC++ 2015-2022 Redist (x64)'  },
    @{ Id = 'Microsoft.VCRedist.2015+.x86';       Name = 'VC++ 2015-2022 Redist (x86)'  }
)

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

# Cache OS info once — used for edition-aware behavior throughout the script
$script:OsInfo  = Get-CimInstance Win32_OperatingSystem
$script:OsBuild = [int]$script:OsInfo.BuildNumber
$script:IsHome  = $script:OsInfo.Caption -match '\bHome\b'

Write-Log "===== $(T 'Started') =====" -Level 'SECTION'
Write-Log "PowerShell  : $($PSVersionTable.PSVersion)"
Write-Log "OS          : $($script:OsInfo.Caption) (Build $script:OsBuild)"
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

# Minimum winget version for the flags this script relies on
# (--disable-interactivity and --include-unknown arrived in winget 1.4)
$script:WingetMinVersion = [Version]'1.4.0'

# $false only when bootstrap could not bring winget up to $WingetMinVersion —
# the newer flags are then left off so an old winget still works
$script:WingetModern = $true

function Get-WingetVersionString {
    $out = winget --version 2>$null
    ((@($out) | Where-Object { "$_" -match '\d+\.\d+' } | Select-Object -Last 1) -replace '[^\d\.]', '').Trim('.')
}

function Test-WingetVersionOk {
    param([string]$VersionString)
    try   { return ([Version]$VersionString -ge $script:WingetMinVersion) }
    catch { return $true }   # unparseable version string — assume current
}

function Test-WingetReady {
    # The App Installer alias folder can be missing from PATH in an elevated session
    $aliasDir = Join-Path $env:LOCALAPPDATA 'Microsoft\WindowsApps'
    if (-not (Get-Command winget -ErrorAction SilentlyContinue) -and
        (Test-Path $aliasDir) -and ($env:Path -notlike "*$aliasDir*")) {
        $env:Path = "$env:Path;$aliasDir"
    }
    if (-not (Get-Command winget -ErrorAction SilentlyContinue)) { return $false }

    $ver = Get-WingetVersionString
    if (Test-WingetVersionOk -VersionString $ver) {
        Write-Log "$(T 'WingetFound'): v$ver"
        return $true
    }
    return $false
}

function Get-WingetCompatArgs {
    param([ValidateSet('install','upgrade','uninstall')][string]$Verb)
    if (-not $script:WingetModern) { return @() }
    if ($Verb -eq 'upgrade') { return @('--include-unknown', '--disable-interactivity') }
    return @('--disable-interactivity')
}

function Install-WingetIfNeeded {
    Set-PhaseProgress -Activity (T 'ProgWingetCheck') -Status (T 'Checking') -Current 1 -Total 4

    # --- Check existing winget ---
    if (Get-Command winget -ErrorAction SilentlyContinue) {
        $rawVer = Get-WingetVersionString
        if (Test-WingetVersionOk -VersionString $rawVer) {
            Write-Log "$(T 'WingetFound'): v$rawVer"
            Clear-PhaseProgress
            return $true
        }
        Write-Log "$(T 'WingetOld'): v$rawVer (minimum $($script:WingetMinVersion))" -Level 'WARN'
    } else {
        Write-Log (T 'WingetMissing') -Level 'WARN'
    }

    Write-Log "$(T 'WingetBootstrap')..." -Level 'SECTION'

    # Older Win10 builds default to TLS 1.0/1.1, which Microsoft download endpoints reject
    try {
        [Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12
    } catch {}

    # --- Bootstrap Step 1: re-register existing package (works on most OEM builds) ---
    Set-PhaseProgress -Activity (T 'ProgWingetCheck') -Status (T 'WingetReRegister') -Current 2 -Total 4
    try {
        Write-Log (T 'WingetReRegister')
        Add-AppxPackage -RegisterByFamilyName -MainPackage 'Microsoft.DesktopAppInstaller_8wekyb3d8bbwe' -ErrorAction Stop
        Start-Sleep -Seconds 3
        # Re-registering only restores the version already on disk, so verify it is new enough
        if (Test-WingetReady) {
            Write-Log (T 'WingetBootOK') -Level 'SUCCESS'
            Clear-PhaseProgress
            return $true
        }
        Write-Log 'Re-registration did not produce a winget at the minimum version' -Level 'WARN'
    }
    catch {
        Write-Log "Re-registration failed: $($_.Exception.Message)" -Level 'WARN'
    }

    # --- Bootstrap Step 2: download MSIX bundle from Microsoft ---
    Set-PhaseProgress -Activity (T 'ProgWingetCheck') -Status (T 'WingetDownload') -Current 3 -Total 4
    $tempPath = Join-Path $env:TEMP 'AppInstaller.msixbundle'
    try {
        Write-Log (T 'WingetDownload')

        # Prefer BITS (handles resume on slow/interrupted connections); fall back to WebClient
        if (Get-Command Start-BitsTransfer -ErrorAction SilentlyContinue) {
            Start-BitsTransfer -Source 'https://aka.ms/getwinget' -Destination $tempPath -ErrorAction Stop
        } else {
            (New-Object System.Net.WebClient).DownloadFile('https://aka.ms/getwinget', $tempPath)
        }

        Add-AppxPackage -Path $tempPath -ForceApplicationShutdown -ErrorAction Stop
        Start-Sleep -Seconds 3
        if (Test-WingetReady) {
            Write-Log (T 'WingetBootOK') -Level 'SUCCESS'
            Clear-PhaseProgress
            return $true
        }
        Write-Log 'App Installer bundle installed, but winget is still below the minimum version' -Level 'WARN'
    }
    catch {
        Write-Log "$(T 'WingetBootFail'): $($_.Exception.Message)" -Level 'WARN'
    }
    finally {
        Remove-Item $tempPath -Force -ErrorAction SilentlyContinue
    }

    # --- Bootstrap Step 3: Microsoft's repair cmdlet (also installs VCLibs / UI.Xaml dependencies,
    #     the usual reason Step 2 fails on LTSC and bare OEM images) ---
    Set-PhaseProgress -Activity (T 'ProgWingetCheck') -Status (T 'WingetRepair') -Current 4 -Total 4
    try {
        Write-Log (T 'WingetRepair')
        Install-PackageProvider -Name NuGet -MinimumVersion 2.8.5.201 -Force -ErrorAction Stop | Out-Null
        if (-not (Get-Module -ListAvailable -Name Microsoft.WinGet.Client)) {
            Install-Module -Name Microsoft.WinGet.Client -Repository PSGallery -Force -ErrorAction Stop
        }
        Import-Module Microsoft.WinGet.Client -ErrorAction Stop
        $repairParams = @{ ErrorAction = 'Stop' }
        if ((Get-Command Repair-WinGetPackageManager -ErrorAction Stop).Parameters.ContainsKey('AllUsers')) {
            $repairParams.AllUsers = $true
        }
        Repair-WinGetPackageManager @repairParams | Out-Null
        Start-Sleep -Seconds 3
        if (Test-WingetReady) {
            Write-Log (T 'WingetBootOK') -Level 'SUCCESS'
            Clear-PhaseProgress
            return $true
        }
    }
    catch {
        Write-Log "$(T 'WingetBootFail'): $($_.Exception.Message)" -Level 'WARN'
    }

    Clear-PhaseProgress

    # An older winget is still far better than aborting the whole run
    if (Get-Command winget -ErrorAction SilentlyContinue) {
        $script:WingetModern = $false
        Write-Log "$(T 'WingetCompat') v$(Get-WingetVersionString)" -Level 'WARN'
        return $true
    }

    Write-Log (T 'WingetBootFail') -Level 'ERROR'
    return $false
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
# Winget Exit Codes & Package ID Resolution
# ================================

# Codes that mean "package is effectively present" — count as success
$script:WingetOkCodes = @(
    -1978335189,  # 0x8A15002B UPDATE_NOT_APPLICABLE (already installed / no applicable upgrade)
    -1978334963,  # 0x8A15010D INSTALL_ALREADY_INSTALLED (another version already installed)
    -1978334962   # 0x8A15010E INSTALL_DOWNGRADE (a HIGHER version is already installed)
)

# Success, but Windows needs a restart to finish — count as success + flag reboot
$script:WingetRebootOkCodes = @(
    -1978334967,  # 0x8A150109 INSTALL_REBOOT_REQUIRED_TO_FINISH
    -1978334965   # 0x8A15010B INSTALL_REBOOT_INITIATED
)

# Genuinely transient — worth retrying after a delay
# (NOTE: 0x8A150109/0x8A15010A are REBOOT codes, not network codes — pre-5.3
#  versions retried them as "network errors", masking the real condition)
$script:WingetTransientCodes = @(
    -1978334969,  # 0x8A150107 INSTALL_NO_NETWORK
    -1978334974,  # 0x8A150102 INSTALL_IN_PROGRESS (another installer is running — common right after OOBE)
    -1978335224,  # 0x8A150008 DOWNLOAD_FAILED
    -1978335215,  # 0x8A150011 INSTALLER_HASH_MISMATCH (often a stale manifest/CDN race — refresh + retry once)
    -2147012894,  # 0x80072EE2 WinHTTP timeout
    -2147012887,  # 0x80072EE9 connection reset by peer
    -2147012873,  # 0x80072EF7 DNS name not resolved
    -2147012867,  # 0x80072EFD connection refused
    -2147012889   # 0x80072EE7 InternetOpenUrl failed / WinHTTP unknown error
)

# Package ID missing from source — triggers ID re-resolution, never a retry
$script:WingetNotFoundCode = -1978335212   # 0x8A150014 NO_APPLICATIONS_FOUND

# Another install holds the Windows Installer lock — wait longer than a network blip before retrying
$script:WingetInstallInProgressCode = -1978334974   # 0x8A150102

function Format-WingetExitCode {
    param([int]$ExitCode)
    '0x{0:X8}' -f ($ExitCode -band 0xFFFFFFFFL)
}

function Get-WingetFailReason {
    param([int]$ExitCode)
    switch ($ExitCode) {
        -1978335224 { 'Installer download failed (all retries exhausted)'                 }  # 0x8A150008
        -1978335215 { 'Installer hash mismatch - manifest may be stale; check proxy/AV'  }  # 0x8A150011
        -1978335212 { 'Package not found in winget source (ID may have changed)'          }  # 0x8A150014
        -1978335211 { 'Multiple installed packages match this name'                       }  # 0x8A150015
        -1978334975 { 'Application is running - close it and retry'                       }  # 0x8A150101
        -1978334974 { 'Another installation is in progress (all retries exhausted)'       }  # 0x8A150102
        -1978334961 { 'Installer blocked by security policy'                              }  # 0x8A15010F
        -1978334960 { 'A dependency failed to install'                                    }  # 0x8A150110
        -1978334959 { 'Application is in use - close it and retry'                        }  # 0x8A150111
        -1978334966 { 'Windows must be restarted before this app can install'             }  # 0x8A15010A
        -1978334971 { 'Disk full'                                                         }  # 0x8A150105
        -1978334969 { 'Network failure -no connectivity (all retries exhausted)'         }  # 0x8A150107
        -1978334955 { 'Installer returned a custom error - see winget log'                }  # 0x8A150115
        -2147012894 { 'Network failure -timed out (all retries exhausted)'               }  # 0x80072EE2
        -2147012887 { 'Network failure -connection reset (all retries exhausted)'        }  # 0x80072EE9
        -2147012873 { 'Network failure -DNS not resolved (all retries exhausted)'        }  # 0x80072EF7
        -2147012867 { 'Network failure -connection refused (all retries exhausted)'      }  # 0x80072EFD
        -2147012889 { 'Network failure -WinHTTP error (all retries exhausted)'           }  # 0x80072EE7
        default     { "Exit code $ExitCode ($(Format-WingetExitCode $ExitCode))"         }
    }
}

# Cache so install + update runs don't re-resolve the same app twice
$script:ResolvedIds = @{}

function Get-WingetIdStatus {
    # Returns the `winget show` exit code: 0 = exists, $script:WingetNotFoundCode = missing,
    # anything else = could not check (offline, source error, ...)
    param([string]$Id)
    $null = winget show --id $Id --exact --source winget --accept-source-agreements 2>&1
    return [int]$LASTEXITCODE
}

function Test-WingetIdExists {
    param([string]$Id)
    return ((Get-WingetIdStatus -Id $Id) -eq 0)
}

function Resolve-WingetPackageId {
    <#
        Returns a usable winget package ID for an app entry, or $null.
        Order: cached result -> primary Id -> each Fallback Id -> winget search by Name.
        A search hit is auto-selected only when it is unambiguous (exactly one
        candidate ID); otherwise candidates are logged for manual list maintenance.
    #>
    param([hashtable]$App)

    if ($script:ResolvedIds.ContainsKey($App.Id)) { return $script:ResolvedIds[$App.Id] }

    # 1) Primary ID
    $primaryCode = Get-WingetIdStatus -Id $App.Id
    if ($primaryCode -eq 0) {
        $script:ResolvedIds[$App.Id] = $App.Id
        return $App.Id
    }
    if ($primaryCode -eq $script:WingetNotFoundCode) {
        Write-Log "$(T 'IdNotFound'): $($App.Id)" -Level 'WARN'
    }

    # 2) Known fallback IDs
    foreach ($alt in @($App.Fallbacks)) {
        if (-not $alt) { continue }
        if (Test-WingetIdExists -Id $alt) {
            Write-Log "$(T 'IdChanged'): $($App.Id) -> $alt" -Level 'WARN'
            $script:ResolvedIds[$App.Id] = $alt
            return $alt
        }
    }

    # 3) Last resort: search the winget source by display name and parse candidate IDs.
    #    winget's table output is locale/width dependent, so instead of column slicing
    #    we harvest tokens that look like package IDs (publisher.product[.suffix]).
    try {
        $searchOut = winget search "$($App.Name)" --source winget --accept-source-agreements 2>&1
        $candidates = @(
            $searchOut |
                ForEach-Object { [regex]::Matches("$_", '(?<=\s|^)([A-Za-z0-9+][\w+.-]*\.[\w+.-]*[A-Za-z0-9+])(?=\s|$)') } |
                ForEach-Object { $_.Groups[1].Value } |
                Where-Object { $_ -notmatch '^\d+(\.\d+)+$' } |     # drop bare version numbers
                Select-Object -Unique
        )
    } catch { $candidates = @() }

    if ($candidates.Count -eq 1) {
        # Unambiguous — verify and adopt it
        if (Test-WingetIdExists -Id $candidates[0]) {
            Write-Log "$(T 'IdChanged'): $($App.Id) -> $($candidates[0]) (via winget search)" -Level 'WARN'
            $script:ResolvedIds[$App.Id] = $candidates[0]
            return $candidates[0]
        }
    } elseif ($candidates.Count -gt 1) {
        Write-Log "$(T 'IdCandidates') '$($App.Name)': $($candidates -join ', ')" -Level 'WARN'
    }

    # The primary ID was never confirmed missing — `winget show` itself failed (offline, source
    # error). Hand back the primary ID uncached so the install reports the real error and gets
    # the transient-error retries, instead of a misleading "ID not found".
    if ($primaryCode -ne $script:WingetNotFoundCode) {
        Write-Log "$(T 'IdUnverified'): $($App.Id) [$(Format-WingetExitCode $primaryCode)]" -Level 'WARN'
        return $App.Id
    }

    $script:ResolvedIds[$App.Id] = $null
    return $null
}

function Invoke-WingetWithRetry {
    <#
        Runs winget with the given arguments, retrying transient failures.
        Returns @{ ExitCode; Output }. Codes in -StopCodes end the loop immediately.
    #>
    param(
        [string[]]$Arguments,
        [string]  $AppName,
        [int[]]   $StopCodes     = @(),
        [int]     $MaxRetries    = 2,
        [int]     $RetryDelaySec = 10
    )

    $attempt = 0
    do {
        $attempt++
        $output   = & winget @Arguments 2>&1
        $exitCode = [int]$LASTEXITCODE

        if ($exitCode -eq 0 -or
            $exitCode -in $StopCodes -or
            $exitCode -in $script:WingetOkCodes -or
            $exitCode -in $script:WingetRebootOkCodes) { break }

        if ($attempt -le $MaxRetries -and $exitCode -in $script:WingetTransientCodes) {
            Write-Log "$(T 'InstallRetrying') ($attempt/$MaxRetries): $AppName [exit $exitCode]" -Level 'WARN'
            # Hash mismatches are often a stale local manifest cache — refresh before retrying
            if ($exitCode -eq -1978335215) { winget source update --name winget 2>$null | Out-Null }
            $delay = if ($exitCode -eq $script:WingetInstallInProgressCode) { $RetryDelaySec * 3 } else { $RetryDelaySec }
            Start-Sleep -Seconds $delay
        } else {
            break
        }
    } while ($true)

    return @{ ExitCode = $exitCode; Output = $output }
}

function Write-WingetDiagnostics {
    # Log the last clean lines of winget output — strip progress-bar/spinner noise
    param($Output)
    $diagLines = (@($Output) | Where-Object { "$_".Trim() }) | Select-Object -Last 8
    foreach ($line in $diagLines) {
        $clean = ("$line" -replace '[^ -~]', '').Trim()
        if ($clean.Length -lt 8)          { continue }  # spinner chars: \|/-
        if ($clean -match '^[\|/\-]+$')  { continue }  # pure spinner frame
        if ($clean -match '^\s*\d+\s*MB') { continue }  # "141 MB / 143 MB" lines
        Write-Log "  $clean" -Level 'WARN'
    }
}

# ================================
# Bloatware Removal
# ================================

function Remove-WingetApps {
    param([string[]]$AppPatterns)
    Write-Log "--- $(T 'ProgBloatware') ---" -Level 'SECTION'

    # Winget exit codes that mean "nothing to uninstall" — treat as SKIPPED, not WARN
    # (0x8A15010A is "restart required before install", NOT "not found" — handled below)
    $notFoundCodes = @(
        -1978335212,  # 0x8A150014  NO_APPLICATIONS_FOUND — nothing installed matches
        -1978335189   # 0x8A15002B  UPDATE_NOT_APPLICABLE — package not applicable / already gone
    )
    $compatArgs = Get-WingetCompatArgs -Verb 'uninstall'

    $total   = $AppPatterns.Count
    $current = 0

    foreach ($pattern in $AppPatterns) {
        $current++
        Set-PhaseProgress -Activity (T 'ProgBloatware') `
                          -Status   "$(T 'Checking'): $pattern" `
                          -Current  $current -Total $total

        Write-Log "$(T 'Checking'): $pattern"
        try {
            $listOut  = winget list --name "$pattern" --accept-source-agreements 2>$null
            $listCode = [int]$LASTEXITCODE
            $found    = $listOut | Where-Object { $_ -and $_ -notmatch 'Name\s+Id\s+Version' -and "$_".Trim() }

            # winget prints "No installed package found..." (a non-empty line) when nothing
            # matches, so the exit code is the reliable signal; the text check stays as a backstop
            if ($listCode -eq $script:WingetNotFoundCode -or -not $found) {
                Write-Log "$(T 'NotFound'): $pattern"
                Add-Result -Section (T 'PhaseBloatware') -Item $pattern -Status 'SKIPPED' -Detail (T 'NotInstalled')
                continue
            }

            Set-PhaseProgress -Activity (T 'ProgBloatware') `
                              -Status   "$(T 'Removing'): $pattern" `
                              -Current  $current -Total $total

            winget uninstall --name "$pattern" --silent --force --accept-source-agreements @compatArgs 2>&1 | Out-Null
            $code = [int]$LASTEXITCODE

            if ($code -eq 0) {
                Write-Log "$(T 'Removed'): $pattern" -Level 'SUCCESS'
                Add-Result -Section (T 'PhaseBloatware') -Item $pattern -Status 'OK' -Detail (T 'Removed')
            } elseif ($code -in $script:WingetRebootOkCodes) {
                Write-Log "$(T 'Removed'): $pattern - $(T 'RebootToFinish')" -Level 'SUCCESS'
                Add-Result -Section (T 'PhaseBloatware') -Item $pattern -Status 'OK' -Detail (T 'RebootToFinish')
                $script:Summary.RebootNeeded = $true
            } elseif ($code -in $notFoundCodes) {
                Write-Log "$(T 'NotFound'): $pattern"
                Add-Result -Section (T 'PhaseBloatware') -Item $pattern -Status 'SKIPPED' -Detail (T 'NotInstalled')
            } else {
                if ($code -eq -1978334966) { $script:Summary.RebootNeeded = $true }  # 0x8A15010A restart first
                $reason = Get-WingetFailReason -ExitCode $code
                Write-Log "$(T 'RemoveExitCode') $code for: $pattern - $reason" -Level 'WARN'
                Add-Result -Section (T 'PhaseBloatware') -Item $pattern -Status 'WARN' -Detail $reason
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

    # Enumerating provisioned packages takes several seconds — do it once, not per pattern
    $allProvPkgs = @(Get-AppxProvisionedPackage -Online -ErrorAction SilentlyContinue)

    foreach ($pattern in $packagesToRemove) {
        $current++
        $label = $pattern.Replace('*','')
        Set-PhaseProgress -Activity (T 'ProgAppx') -Status $label -Current $current -Total $total

        try {
            $removed   = 0
            $failed    = 0
            $protected = 0
            $lastError = ''

            $pkgs = Get-AppxPackage -AllUsers -Name $pattern -ErrorAction SilentlyContinue
            foreach ($pkg in $pkgs) {
                Write-Log "$(T 'AppxRemoving'): $($pkg.Name)"
                try {
                    Remove-AppxPackage -Package $pkg.PackageFullName -AllUsers -ErrorAction Stop
                    $script:Summary.AppxRemoved++
                    $removed++
                }
                catch {
                    # 0x80073CFA = component of Windows that cannot be uninstalled — expected, not a fault
                    if ($_.Exception.Message -match '0x80073CFA') {
                        Write-Log "$(T 'AppxProtected'): $($pkg.Name)"
                        $protected++
                    } else {
                        Write-Log "$(T 'RemoveError') $($pkg.Name): $($_.Exception.Message)" -Level 'WARN'
                        $lastError = $_.Exception.Message
                        $failed++
                    }
                }
            }

            $provPkgs = $allProvPkgs | Where-Object { $_.DisplayName -like $pattern }
            foreach ($pkg in $provPkgs) {
                Write-Log "$(T 'AppxProvRemoving'): $($pkg.DisplayName)"
                try {
                    Remove-AppxProvisionedPackage -Online -PackageName $pkg.PackageName -ErrorAction Stop | Out-Null
                    $script:Summary.AppxRemoved++
                    $removed++
                }
                catch {
                    Write-Log "$(T 'RemoveError') $($pkg.DisplayName): $($_.Exception.Message)" -Level 'WARN'
                    $lastError = $_.Exception.Message
                    $failed++
                }
            }

            if ($failed -gt 0) {
                $status = if ($removed -gt 0) { 'OK' } else { 'WARN' }
                $detail = "$(T 'Removed') $removed, $(T 'InstallFail') $failed - $lastError"
            } elseif ($removed -gt 0) {
                $status = 'OK'
                $detail = "$(T 'Removed') $removed"
            } elseif ($protected -gt 0) {
                $status = 'SKIPPED'
                $detail = T 'AppxProtected'
            } else {
                $status = 'SKIPPED'
                $detail = T 'NotInstalled'
            }
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

    # Get-WindowsCapability requires Windows Update to be accessible.
    # On Home with metered connections, WSUS-redirected builds, or disabled WU it returns
    # $null silently and produces misleading SKIPPED results — guard against that.
    $wuSvc = Get-Service -Name wuauserv -ErrorAction SilentlyContinue
    $wuAccessible = $wuSvc -and $wuSvc.StartType -ne 'Disabled'

    if (-not $wuAccessible) {
        Write-Log (T 'CapWuUnavail') -Level 'WARN'
        foreach ($cap in $capabilitiesToRemove) {
            Add-Result -Section (T 'ProgCaps') -Item $cap -Status 'SKIPPED' -Detail (T 'CapWuUnavail')
        }
        Clear-PhaseProgress
        return
    }

    $total   = $capabilitiesToRemove.Count
    $current = 0

    foreach ($cap in $capabilitiesToRemove) {
        $current++
        Set-PhaseProgress -Activity (T 'ProgCaps') -Status $cap -Current $current -Total $total

        try {
            $state = Get-WindowsCapability -Online -Name $cap -ErrorAction SilentlyContinue
            if ($state -and $state.State -eq 'Installed') {
                Write-Log "$(T 'CapRemoving'): $cap"
                $capResult = Remove-WindowsCapability -Online -Name $cap -ErrorAction Stop
                if ($capResult -and $capResult.RestartNeeded) { $script:Summary.RebootNeeded = $true }
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

function Get-UninstallCommand {
    <#
        Turns a registry UninstallString / QuietUninstallString into a silent command.
        Returns @{ FilePath; Arguments; IsMsi } or $null.
        MSI entries become `msiexec /X{GUID} /qn /norestart` — the old blanket "/S /quiet"
        made msiexec show a (hidden) usage dialog and wait forever.
    #>
    param(
        [string]$UninstallString,
        [string]$QuietUninstallString
    )

    $useQuiet = [bool]$QuietUninstallString
    $raw      = if ($useQuiet) { $QuietUninstallString.Trim() } elseif ($UninstallString) { $UninstallString.Trim() } else { '' }
    if (-not $raw) { return $null }

    if ($raw -match '^"([^"]+)"\s*(.*)$') {
        $exe = $Matches[1]; $exeArgs = $Matches[2]
    } elseif ($raw -match '^(.+?\.exe)(?:\s+(.*))?$') {
        # Unquoted path that may contain spaces, e.g. C:\Program Files\McAfee\uninst.exe /x
        $exe = $Matches[1]; $exeArgs = "$($Matches[2])"
    } else {
        $parts   = $raw.Split(' ', 2)
        $exe     = $parts[0]
        $exeArgs = if ($parts.Length -gt 1) { $parts[1] } else { '' }
    }
    $exe     = $exe.Trim()
    $exeArgs = $exeArgs.Trim()

    $isMsi = (Split-Path $exe -Leaf) -match '^msiexec(\.exe)?$'
    if ($isMsi) {
        if ($raw -match '\{[0-9A-Fa-f\-]{36}\}') {
            $exeArgs = "/X$($Matches[0]) /qn /norestart"
        } elseif ($exeArgs -notmatch '/q') {
            $exeArgs = "$exeArgs /qn /norestart".Trim()
        }
    } elseif (-not $useQuiet -and $exeArgs -notmatch '/S|/silent|/quiet') {
        $exeArgs = "$exeArgs /S /quiet".Trim()
    }

    return @{ FilePath = $exe; Arguments = $exeArgs; IsMsi = $isMsi }
}

function Wait-ProcessTree {
    <#
        Waits for a process AND any child processes it spawned (matching Start-Process -Wait,
        which many uninstallers rely on because they hand off to a child and exit).
        Returns $true when everything exited, $false on timeout (remaining processes are stopped).
    #>
    param(
        [System.Diagnostics.Process]$Process,
        [int]$TimeoutSec
    )

    $deadline  = (Get-Date).AddSeconds($TimeoutSec)
    # Only processes started after the root count as its children (guards against PID reuse)
    $startTime = try { $Process.StartTime } catch { (Get-Date).AddMinutes(-1) }
    $tree      = [System.Collections.Generic.HashSet[int]]::new()
    [void]$tree.Add($Process.Id)

    $remainingMs = [int][Math]::Max(0, ($deadline - (Get-Date)).TotalMilliseconds)
    $rootExited  = $Process.WaitForExit($remainingMs)

    while ($true) {
        $procs = @(Get-CimInstance Win32_Process -ErrorAction SilentlyContinue |
                   Where-Object { $_.CreationDate -ge $startTime })
        do {
            $added = $false
            foreach ($p in $procs) {
                if ($tree.Contains([int]$p.ParentProcessId) -and $tree.Add([int]$p.ProcessId)) { $added = $true }
            }
        } while ($added)

        $alive = @($procs | Where-Object { $tree.Contains([int]$_.ProcessId) -and $_.ProcessId -ne $Process.Id })
        if ($rootExited -and $alive.Count -eq 0) { return $true }

        if ((Get-Date) -ge $deadline) {
            if (-not $rootExited) { try { $Process.Kill() } catch {} }
            foreach ($p in $alive) { Stop-Process -Id $p.ProcessId -Force -ErrorAction SilentlyContinue }
            return $false
        }

        Start-Sleep -Seconds 2
        if (-not $rootExited) { $rootExited = $Process.HasExited }
    }
}

function Remove-McAfeeProducts {
    Write-Log "--- $(T 'ProgMcAfee') ---" -Level 'SECTION'

    $uninstallTimeoutSec = 20 * 60

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
        $displayName = $entry.DisplayName

        Set-PhaseProgress -Activity (T 'ProgMcAfee') -Status $displayName -Current $current -Total $total
        Write-Log "$(T 'McAfeeFound'): $displayName"

        $cmd = Get-UninstallCommand -UninstallString $entry.UninstallString -QuietUninstallString $entry.QuietUninstallString
        if (-not $cmd) {
            Write-Log "$(T 'McAfeeNoStr') for $displayName" -Level 'WARN'
            Add-Result -Section (T 'ProgMcAfee') -Item $displayName -Status 'WARN' -Detail (T 'McAfeeNoStr')
            continue
        }

        try {
            Write-Log "$(T 'McAfeeUninstall'): $displayName  [$($cmd.FilePath) $($cmd.Arguments)]"
            $spParams = @{ FilePath = $cmd.FilePath; WindowStyle = 'Hidden'; PassThru = $true; ErrorAction = 'Stop' }
            if ($cmd.Arguments) { $spParams.ArgumentList = $cmd.Arguments }
            $proc = Start-Process @spParams
            $null = $proc.Handle   # PS 5.1: ExitCode is only populated if the handle was opened before exit

            if (-not (Wait-ProcessTree -Process $proc -TimeoutSec $uninstallTimeoutSec)) {
                Write-Log "$(T 'McAfeeFailed') $displayName`: $(T 'UninstallTimeout')" -Level 'ERROR'
                Write-Log (T 'McAfeeHint') -Level 'WARN'
                Add-Result -Section (T 'ProgMcAfee') -Item $displayName -Status 'FAILED' -Detail (T 'UninstallTimeout')
                continue
            }

            $code = $proc.ExitCode
            if ($code -in 0, 3010, 1641) {
                # 3010 / 1641 = success, restart required / initiated
                if ($code -ne 0) { $script:Summary.RebootNeeded = $true }
                Write-Log "$(T 'McAfeeRemoved'): $displayName" -Level 'SUCCESS'
                $script:Summary.McAfeeRemoved++
                Add-Result -Section (T 'ProgMcAfee') -Item $displayName -Status 'OK' -Detail (T 'McAfeeRemoved')
            } elseif ($code -eq 1605) {
                # MSI: product is not installed (stale registry entry)
                Write-Log "$(T 'NotInstalled'): $displayName"
                Add-Result -Section (T 'ProgMcAfee') -Item $displayName -Status 'SKIPPED' -Detail (T 'NotInstalled')
            } else {
                Write-Log "$(T 'McAfeeFailed') $displayName`: exit code $code" -Level 'WARN'
                Write-Log (T 'McAfeeHint') -Level 'WARN'
                Add-Result -Section (T 'ProgMcAfee') -Item $displayName -Status 'WARN' -Detail "exit code $code - $(T 'McAfeeHint')"
            }
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

    $maxRetries    = 2
    $retryDelaySec = 10

    $appsToInstall = $script:ManagedApps

    $total   = $appsToInstall.Count
    $current = 0

    foreach ($app in $appsToInstall) {
        $current++
        Set-PhaseProgress -Activity (T 'ProgApps') `
                          -Status   "$(T 'Installing'): $($app.Name) ($current/$total)" `
                          -Current  $current -Total $total

        Write-Log "$(T 'Installing'): $($app.Name)  [$($app.Id)]"
        try {
            # Verify the package ID still exists; fall back / search if it changed
            $resolvedId = Resolve-WingetPackageId -App $app
            if (-not $resolvedId) {
                Write-Log "$(T 'InstallFail'): $($app.Name) - $(T 'IdNotFound')" -Level 'WARN'
                Add-Result -Section (T 'PhaseApps') -Item $app.Name -Status 'WARN' -Detail (T 'IdNotFound')
                $script:Summary.AppsFailed++
                continue
            }

            $wingetArgs = @('install', '--id', $resolvedId, '--exact', '--source', 'winget',
                            '--accept-package-agreements', '--accept-source-agreements', '--silent') +
                          @(Get-WingetCompatArgs -Verb 'install')
            $run       = Invoke-WingetWithRetry -Arguments $wingetArgs -AppName $app.Name `
                             -MaxRetries $maxRetries -RetryDelaySec $retryDelaySec
            $exitCode  = $run.ExitCode
            $wingetOut = $run.Output

            if ($exitCode -eq 0) {
                Write-Log "$(T 'InstallOK'): $($app.Name)" -Level 'SUCCESS'
                Add-Result -Section (T 'PhaseApps') -Item $app.Name -Status 'OK' -Detail (T 'InstallOK')
                $script:Summary.AppsInstalled++
            } elseif ($exitCode -in $script:WingetRebootOkCodes) {
                # Install succeeded but Windows needs a restart to finish — NOT a failure
                Write-Log "$(T 'InstallOK'): $($app.Name) - $(T 'RebootToFinish')" -Level 'SUCCESS'
                Add-Result -Section (T 'PhaseApps') -Item $app.Name -Status 'OK' -Detail (T 'RebootToFinish')
                $script:Summary.AppsInstalled++
                $script:Summary.RebootNeeded = $true
            } elseif ($exitCode -in $script:WingetOkCodes) {
                Write-Log "$(T 'AlreadyInstalled'): $($app.Name)" -Level 'SUCCESS'
                Add-Result -Section (T 'PhaseApps') -Item $app.Name -Status 'OK' -Detail (T 'AlreadyInstalled')
                $script:Summary.AppsInstalled++
            } else {
                $failReason = Get-WingetFailReason -ExitCode $exitCode
                if ($exitCode -eq -1978334966) { $script:Summary.RebootNeeded = $true }  # reboot-before-install
                Write-Log "$(T 'InstallFail'): $($app.Name) - $failReason" -Level 'WARN'
                Write-WingetDiagnostics -Output $wingetOut
                Add-Result -Section (T 'PhaseApps') -Item $app.Name -Status 'WARN' -Detail $failReason
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
# App Update
# ================================

function Update-InstalledApps {
    # 0x8A150014 NO_APPLICATIONS_FOUND from `winget upgrade --id` means the app
    # isn't installed on this machine — a skip, not an error, in update mode
    $notInstalledCode = $script:WingetNotFoundCode

    $maxRetries    = 2
    $retryDelaySec = 10

    $appsToUpdate = $script:ManagedApps
    $total        = $appsToUpdate.Count
    $current      = 0

    foreach ($app in $appsToUpdate) {
        $current++
        Set-PhaseProgress -Activity (T 'ProgUpdate') `
                          -Status   "$(T 'Updating'): $($app.Name) ($current/$total)" `
                          -Current  $current -Total $total

        Write-Log "$(T 'Updating'): $($app.Name)  [$($app.Id)]"
        try {
            $resolvedId = Resolve-WingetPackageId -App $app
            if (-not $resolvedId) {
                Write-Log "$(T 'UpdateFail'): $($app.Name) - $(T 'IdNotFound')" -Level 'WARN'
                Add-Result -Section (T 'PhaseUpdate') -Item $app.Name -Status 'WARN' -Detail (T 'IdNotFound')
                $script:Summary.AppsUpdateFailed++
                continue
            }

            # --include-unknown (from Get-WingetCompatArgs): upgrade apps whose installed version
            # winget can't read (common after Windows Update services .NET runtimes out from under winget)
            $wingetArgs = @('upgrade', '--id', $resolvedId, '--exact', '--source', 'winget',
                            '--accept-package-agreements', '--accept-source-agreements', '--silent') +
                          @(Get-WingetCompatArgs -Verb 'upgrade')
            $run       = Invoke-WingetWithRetry -Arguments $wingetArgs -AppName $app.Name `
                             -StopCodes @($notInstalledCode) `
                             -MaxRetries $maxRetries -RetryDelaySec $retryDelaySec
            $exitCode  = $run.ExitCode
            $wingetOut = $run.Output

            if ($exitCode -eq 0) {
                Write-Log "$(T 'UpdateOK'): $($app.Name)" -Level 'SUCCESS'
                Add-Result -Section (T 'PhaseUpdate') -Item $app.Name -Status 'OK' -Detail (T 'UpdateOK')
                $script:Summary.AppsUpdated++
            } elseif ($exitCode -in $script:WingetRebootOkCodes) {
                Write-Log "$(T 'UpdateOK'): $($app.Name) - $(T 'RebootToFinish')" -Level 'SUCCESS'
                Add-Result -Section (T 'PhaseUpdate') -Item $app.Name -Status 'OK' -Detail (T 'RebootToFinish')
                $script:Summary.AppsUpdated++
                $script:Summary.RebootNeeded = $true
            } elseif ($exitCode -eq $notInstalledCode) {
                Write-Log "$(T 'NotInstalledSkip'): $($app.Name)" -Level 'INFO'
                Add-Result -Section (T 'PhaseUpdate') -Item $app.Name -Status 'SKIPPED' -Detail (T 'NotInstalledSkip')
                $script:Summary.AppsSkipped++
            } elseif ($exitCode -in $script:WingetOkCodes) {
                Write-Log "$(T 'AlreadyUpToDate'): $($app.Name)" -Level 'SUCCESS'
                Add-Result -Section (T 'PhaseUpdate') -Item $app.Name -Status 'OK' -Detail (T 'AlreadyUpToDate')
                $script:Summary.AppsUpdated++
            } else {
                $failReason = Get-WingetFailReason -ExitCode $exitCode
                if ($exitCode -eq -1978334966) { $script:Summary.RebootNeeded = $true }
                Write-Log "$(T 'UpdateFail'): $($app.Name) - $failReason" -Level 'WARN'
                Write-WingetDiagnostics -Output $wingetOut
                Add-Result -Section (T 'PhaseUpdate') -Item $app.Name -Status 'WARN' -Detail $failReason
                $script:Summary.AppsUpdateFailed++
            }
        }
        catch {
            Write-Log "$(T 'UpdateError') $($app.Name): $($_.Exception.Message)" -Level 'ERROR'
            Add-Result -Section (T 'PhaseUpdate') -Item $app.Name -Status 'FAILED' -Detail $_.Exception.Message
            $script:Summary.AppsUpdateFailed++
        }
    }

    Clear-PhaseProgress
    Write-Log "$(T 'PhaseUpdate'): $($script:Summary.AppsUpdated)/$total OK, $($script:Summary.AppsUpdateFailed) failed."
}

# ================================
# System Configuration
# ================================

function Set-SystemConfiguration {
    Write-Log "--- $(T 'ProgConfig') ---" -Level 'SECTION'

    # Flag policy-only keys — on Home edition these write successfully but have no effect.
    # We log a WARN rather than SUCCESS so the report reflects reality.
    $configItems = @(
        @{ Path = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\DataCollection'; Name = 'AllowTelemetry';         Value = 0; PolicyOnly = $true  },
        @{ Path = 'HKLM:\SOFTWARE\Microsoft\Windows\Windows Error Reporting'; Name = 'Disabled';               Value = 1; PolicyOnly = $false },
        @{ Path = 'HKLM:\SOFTWARE\Microsoft\SQMClient\Windows';               Name = 'CEIPEnable';             Value = 0; PolicyOnly = $false },
        @{ Path = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\AdvertisingInfo'; Name = 'DisabledByGroupPolicy'; Value = 1; PolicyOnly = $true  }
    )

    $total   = $configItems.Count
    $current = 0

    foreach ($item in $configItems) {
        $current++
        Set-PhaseProgress -Activity (T 'ProgConfig') -Status $item.Name -Current $current -Total $total
        if ($item.PolicyOnly -and $script:IsHome) {
            Write-Log "$(T 'HomeEditionNote'): $($item.Name)" -Level 'WARN'
        }
        Set-RegistryValue -Path $item.Path -Name $item.Name -Value $item.Value
    }

    Clear-PhaseProgress
    Write-Log (T 'SysConfigDone') -Level 'SUCCESS'
}

function Remove-OneDriveOem {
    # On some OEM builds OneDrive is embedded as a setup binary in System32/SysWOW64
    # rather than deployed as an Appx, so winget and Get-AppxPackage both miss it.
    Write-Log "--- $(T 'OneDriveOem') ---" -Level 'SECTION'

    $setupPaths = @(
        # OEM-embedded binaries — these are system-wide and reliable under admin elevation.
        # Per-user OneDrive installs ($env:LOCALAPPDATA) are excluded: under RunAs, LOCALAPPDATA
        # resolves to the admin profile, not the interactive user, making the path unreliable.
        "$env:SystemRoot\SysWOW64\OneDriveSetup.exe",
        "$env:SystemRoot\System32\OneDriveSetup.exe"
    )

    foreach ($path in $setupPaths) {
        if (Test-Path $path) {
            Write-Log "$(T 'OneDriveOemFound'): $path"
            try {
                Start-Process -FilePath $path -ArgumentList '/uninstall' -Wait -WindowStyle Hidden -ErrorAction Stop
                Write-Log (T 'OneDriveOemDone') -Level 'SUCCESS'
                Add-Result -Section (T 'PhaseBloatware') -Item 'OneDrive (OEM binary)' -Status 'OK' -Detail $path
            }
            catch {
                Write-Log "OEM OneDrive uninstall failed: $($_.Exception.Message)" -Level 'WARN'
                Add-Result -Section (T 'PhaseBloatware') -Item 'OneDrive (OEM binary)' -Status 'WARN' -Detail $_.Exception.Message
            }
            return   # only process first binary found
        }
    }

    Write-Log (T 'OneDriveOemNone')
}

# ================================
# HTML Report Generator
# ================================

function Export-HtmlReport {
    param([string]$OverallStatus)
    Write-Log "$(T 'PhaseReporting')..."

    Set-PhaseProgress -Activity (T 'PhaseReporting') -Status (T 'ProgReportCollect') -Current 1 -Total 3

    $os          = $script:OsInfo
    $cpu         = ConvertTo-HtmlSafe (Get-CimInstance Win32_Processor | Select-Object -First 1).Name
    $osCaption   = ConvertTo-HtmlSafe $os.Caption
    $editionRaw  = switch -Regex ($os.Caption) {
                       '\bHome\b'       { 'Home'        }
                       '\bPro\b'        { 'Pro'         }
                       '\bEnterprise\b' { 'Enterprise'  }
                       '\bEducation\b'  { 'Education'   }
                       '\bServer\b'     { 'Server'      }
                       default          { 'Unknown'     }
                   }
    $osEdition   = ConvertTo-HtmlSafe $editionRaw
    $osBuild     = $script:OsBuild
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
    $lEdition         = T 'HtmlEdition'
    $lBuild           = T 'HtmlBuild'

    # Update mode replaces the install phase, so show its counters instead
    if ($script:UpdateMode) {
        $appCounters = @(
            "<div class=`"counter-card`"><div class=`"num num-ok`">$($script:Summary.AppsUpdated)</div><div class=`"lbl`">$(T 'HtmlAppsUpdated')</div></div>"
            "<div class=`"counter-card`"><div class=`"num num-fail`">$($script:Summary.AppsUpdateFailed)</div><div class=`"lbl`">$(T 'HtmlAppsUpdFail')</div></div>"
            "<div class=`"counter-card`"><div class=`"num num-info`">$($script:Summary.AppsSkipped)</div><div class=`"lbl`">$(T 'HtmlAppsSkipped')</div></div>"
        ) -join "`n  "
    } else {
        $appCounters = @(
            "<div class=`"counter-card`"><div class=`"num num-ok`">$($script:Summary.AppsInstalled)</div><div class=`"lbl`">$lAppsOK</div></div>"
            "<div class=`"counter-card`"><div class=`"num num-fail`">$($script:Summary.AppsFailed)</div><div class=`"lbl`">$lAppsFail</div></div>"
        ) -join "`n  "
    }

    $rebootHtml = if ($script:Summary.RebootNeeded) {
        "<div class=`"reboot`">$(ConvertTo-HtmlSafe (T 'SumReboot'))</div>"
    } else { '' }

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
  .reboot { background: rgba(245,158,11,.12); border: 1px solid var(--warn); color: var(--warn);
            border-radius: 8px; padding: 12px 16px; font-weight: 600; margin-bottom: 28px; }
</style>
</head>
<body>

<h1>&#128187; $lHtmlTitle</h1>
<div class="subtitle">$lGenerated $timestamp &nbsp;|&nbsp; Pacific Northwest Computers</div>
<div class="badge">$OverallStatus</div>
$rebootHtml

<h2>$lSysInfo</h2>
<div class="info-grid">
  <div class="info-card"><div class="label">$lHostname</div><div class="value">$env:COMPUTERNAME</div></div>
  <div class="info-card"><div class="label">$lOS</div><div class="value">$osCaption</div></div>
  <div class="info-card"><div class="label">$lEdition</div><div class="value">$osEdition</div></div>
  <div class="info-card"><div class="label">$lBuild</div><div class="value">$osBuild</div></div>
  <div class="info-card"><div class="label">$lCPU</div><div class="value">$cpu</div></div>
  <div class="info-card"><div class="label">$lRAM</div><div class="value">$ramGB GB</div></div>
  <div class="info-card"><div class="label">$lUptime</div><div class="value">$uptimeHrs $lHrs</div></div>
  <div class="info-card"><div class="label">$lRunTime</div><div class="value">$durationFmt</div></div>
  <div class="info-card"><div class="label">$lVersion</div><div class="value">$($script:Version)</div></div>
  <div class="info-card"><div class="label">$lTechnician</div><div class="value">PNWC</div></div>
</div>

<h2>$lSummary</h2>
<div class="counter-grid">
  $appCounters
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
        $html | Set-Content -Path $ReportPath -Encoding UTF8 -Force -ErrorAction Stop
        Write-Log "$(T 'ReportSaved'): $ReportPath" -Level 'SUCCESS'
    }
    catch {
        Write-Log "$(T 'ReportFail'): $($_.Exception.Message)" -Level 'WARN'
        # Same fallback as the log: the script folder may be read-only
        try {
            $fallbackDir = Join-Path $env:ProgramData 'DeployWorkstation'
            New-Item -Path $fallbackDir -ItemType Directory -Force -ErrorAction SilentlyContinue | Out-Null
            $script:ReportPath = Join-Path $fallbackDir (Split-Path $ReportPath -Leaf)
            $html | Set-Content -Path $script:ReportPath -Encoding UTF8 -Force -ErrorAction Stop
            Write-Log "$(T 'ReportSaved'): $script:ReportPath" -Level 'SUCCESS'
        }
        catch {
            Write-Log "$(T 'ReportFail'): $($_.Exception.Message)" -Level 'WARN'
        }
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
    if ($script:UpdateMode) {
        Write-Log "$( (T 'SumAppsUpdated')    ) : $($script:Summary.AppsUpdated)"
        Write-Log "$( (T 'SumAppsUpdateFail') ) : $($script:Summary.AppsUpdateFailed)"
        Write-Log "$( (T 'SumAppsSkipped')    ) : $($script:Summary.AppsSkipped)"
    } else {
        Write-Log "$( (T 'SumAppsOK')    ) : $($script:Summary.AppsInstalled)"
        Write-Log "$( (T 'SumAppsFail')  ) : $($script:Summary.AppsFailed)"
    }
    Write-Log "$( (T 'SumAppx')      ) : $($script:Summary.AppxRemoved)"
    Write-Log "$( (T 'SumCaps')      ) : $($script:Summary.CapabilitiesRemoved)"
    Write-Log "$( (T 'SumConfigOK')  ) : $($script:Summary.HardeningApplied)"
    Write-Log "$( (T 'SumConfigFail')) : $($script:Summary.HardeningFailed)"
    Write-Log "$( (T 'SumMcAfee')    ) : $($script:Summary.McAfeeRemoved)"
    if ($script:Summary.RebootNeeded) {
        Write-Log (T 'SumReboot') -Level 'WARN'
    }
    Write-Log $border -Level 'SECTION'
}

# ================================
# Main Execution
# ================================

# Overall progress weights (must total 100)
# Phases: Init=5, Bloatware=35, Apps=40, Config=15, Report=5
$script:PhasePct = @{ Init = 5; BloatStart = 5; BloatEnd = 40; AppsStart = 40; AppsEnd = 80; ConfigStart = 80; ConfigEnd = 95; Done = 100 }

# Process exit code: 0 = success, 1 = critical error, 2 = completed with warnings
$script:ExitCode = 0

try {
    Set-OverallProgress -Status (T 'ManagingSources') -Percent $script:PhasePct.Init

    if (-not (Install-WingetIfNeeded)) {
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
        Remove-OneDriveOem
        Remove-WindowsCapabilities
        Remove-McAfeeProducts
        Set-OverallProgress -Status "$(T 'PhaseBloatware') - Complete" -Percent $script:PhasePct.BloatEnd
        Write-Log "=== $(T 'PhaseBloatware') COMPLETE ===" -Level 'SUCCESS'
    } else {
        Write-Log (T 'SkipBloatware')
    }

    if (-not $SkipAppInstall) {
        if ($UpdateApps) {
            Set-OverallProgress -Status (T 'PhaseUpdate') -Percent $script:PhasePct.AppsStart
            Write-Log "=== $(T 'PhaseUpdate') ===" -Level 'SECTION'
            Update-InstalledApps
            Set-OverallProgress -Status "$(T 'PhaseUpdate') - Complete" -Percent $script:PhasePct.AppsEnd
            Write-Log "=== $(T 'PhaseUpdate') COMPLETE ===" -Level 'SUCCESS'
        } else {
            Set-OverallProgress -Status (T 'PhaseApps') -Percent $script:PhasePct.AppsStart
            Write-Log "=== $(T 'PhaseApps') ===" -Level 'SECTION'
            Install-StandardApps
            Set-OverallProgress -Status "$(T 'PhaseApps') - Complete" -Percent $script:PhasePct.AppsEnd
            Write-Log "=== $(T 'PhaseApps') COMPLETE ===" -Level 'SUCCESS'
        }
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

    $overallStatus = if ($script:Summary.AppsFailed -gt 0 -or $script:Summary.HardeningFailed -gt 0 -or $script:Summary.AppsUpdateFailed -gt 0) {
        'WARNING'
    } else {
        'SUCCESS'
    }
    if ($overallStatus -eq 'WARNING') { $script:ExitCode = 2 }

    Set-OverallProgress -Status (T 'PhaseReporting') -Percent $script:PhasePct.ConfigEnd
    Export-HtmlReport -OverallStatus $overallStatus
    Set-OverallProgress -Status (T 'Completed') -Percent $script:PhasePct.Done

    Write-Log "===== $(T 'Completed') =====" -Level 'SUCCESS'
    Write-Host "`n*** $(T 'SetupComplete') ***" -ForegroundColor Green
    Write-Host "    Log    : $LogPath"          -ForegroundColor Gray
    Write-Host "    Report : $ReportPath"       -ForegroundColor Cyan
    if ($script:Summary.RebootNeeded) {
        Write-Host "`n$(T 'SumReboot')"         -ForegroundColor Yellow
    }
    if (-not $NoPause) {
        Write-Host "`n$(T 'PressEnter')"        -ForegroundColor Yellow
        Read-Host | Out-Null
    }
}
catch {
    $script:ExitCode = 1
    Write-Log "$(T 'CriticalError'): $($_.Exception.Message)" -Level 'ERROR'
    try { Export-HtmlReport -OverallStatus 'FAILED' } catch {}
    Write-Host "`n*** $(T 'SetupFailed'): $LogPath ***" -ForegroundColor Red
    # Keep the window open so the error can be read (it closes on exit when relaunched elevated)
    if (-not $NoPause) {
        Write-Host "`n$(T 'PressEnter')"        -ForegroundColor Yellow
        try { Read-Host | Out-Null } catch {}
    }
}
finally {
    # Always clear progress bars — runs on success, failure, and Ctrl+C
    Write-Progress -Id 1 -Activity ' ' -Completed
    Write-Progress -Id 0 -Activity ' ' -Completed
}

exit $script:ExitCode
