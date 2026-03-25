# DeployWorkstation.ps1 – Optimized Win10/11 Setup & Clean-up
# Version: 5.2 – PNWC Edition
# Fixed: registry property creation in PS 5.1, safer edition detection, safer report generation,
# more resilient winget/bootstrap handling, cleaned exit behavior

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

$ErrorActionPreference = 'Continue'
$ProgressPreference    = 'Continue'
$script:StartTime      = Get-Date
$script:Version        = '5.2'

$scriptRoot = if ($PSScriptRoot) { $PSScriptRoot } else { Split-Path -Parent $MyInvocation.MyCommand.Path }

if (-not $LogPath)    { $LogPath    = Join-Path $scriptRoot 'DeployWorkstation.log' }
if (-not $ReportPath) { $ReportPath = Join-Path $scriptRoot 'DeployWorkstation.html' }

if ($PSVersionTable.PSEdition -eq 'Core') {
    Write-Warning 'PowerShell Core detected. Restarting in Windows PowerShell 5.1...'
    $params = @(
        '-NoProfile',
        '-ExecutionPolicy', 'Bypass',
        '-File', "`"$PSCommandPath`"",
        '-LogPath', "`"$LogPath`"",
        '-ReportPath', "`"$ReportPath`""
    )
    if ($SkipAppInstall)       { $params += '-SkipAppInstall' }
    if ($SkipBloatwareRemoval) { $params += '-SkipBloatwareRemoval' }
    if ($SkipSystemConfig)     { $params += '-SkipSystemConfig' }

    Start-Process -FilePath 'powershell.exe' -ArgumentList $params -Verb RunAs
    exit
}

# ================================
# Localization
# ================================

$script:Strings = @{
    'en-US' = @{
        Started           = 'DeployWorkstation v5.2 Started'
        WingetRequired    = "Winget is required. Install 'App Installer' from the Microsoft Store."
        WingetFound       = 'Winget found'
        WingetMissing     = 'Winget not found on PATH.'
        ManagingSources   = 'Managing winget sources'
        ProgSources       = 'Managing Winget Sources'
        RemovingMsstore   = 'Removing msstore source (performance)'
        RefreshingSources = 'Refreshing winget source index'
        SourcesFailed     = 'Could not manage winget sources'

        PhaseBloatware    = 'BLOATWARE REMOVAL'
        PhaseApps         = 'APP INSTALLATION'
        PhaseConfig       = 'SYSTEM CONFIGURATION'
        PhaseReporting    = 'GENERATING REPORT'

        SkipBloatware     = 'Bloatware removal skipped (-SkipBloatwareRemoval).'
        SkipApps          = 'App installation skipped (-SkipAppInstall).'
        SkipConfig        = 'System configuration skipped (-SkipSystemConfig).'

        ProgOverall       = 'Deploying Workstation'
        ProgBloatware     = 'Removing Bloatware'
        ProgAppx          = 'Removing Appx Packages'
        ProgCaps          = 'Removing Windows Capabilities'
        ProgMcAfee        = 'Checking for McAfee'
        ProgApps          = 'Installing Applications'
        ProgConfig        = 'Configuring System'

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

        SumTitle          = 'DEPLOYMENT SUMMARY'
        SumAppsOK         = 'Apps installed / skipped'
        SumAppsFail       = 'Apps failed'
        SumAppx           = 'Appx packages removed'
        SumCaps           = 'Capabilities removed'
        SumConfigOK       = 'Config keys applied'
        SumConfigFail     = 'Config keys failed'
        SumMcAfee         = 'McAfee products removed'

        Completed         = 'DeployWorkstation.ps1 Completed'
        SetupComplete     = 'Setup complete!'
        SetupFailed       = 'Setup failed - see log'
        PressEnter        = 'Press Enter to exit...'
        ReportSaved       = 'HTML report saved'
        ReportFail        = 'Failed to write HTML report'
        CriticalError     = 'CRITICAL ERROR'

        WingetOld         = 'Winget outdated, updating'
        WingetBootstrap   = 'Installing App Installer (winget)'
        WingetBootOK      = 'App Installer installed successfully'
        WingetBootFail    = 'Failed to install App Installer'
        WingetReRegister  = 'Attempting package re-registration'
        WingetDownload    = 'Downloading App Installer from Microsoft'

        InstallRetrying   = 'Network error, retrying'
        CapWuUnavail      = 'Skipped - Windows Update not accessible on this system'
        HomeEditionNote   = 'Policy key written but has no effect on Windows Home edition'
        OneDriveOem       = 'OneDrive OEM binary removal'
        OneDriveOemFound  = 'Found OEM OneDrive binary'
        OneDriveOemDone   = 'OEM OneDrive uninstall completed'
        OneDriveOemNone   = 'No OEM OneDrive setup binary found'

        HtmlEdition       = 'Edition'
        HtmlBuild         = 'Build'
        ProgWingetCheck   = 'Checking Winget'
        ProgSourcesList   = 'Listing sources'
        ProgSourcesUpdate = 'Updating sources'
        ProgReportCollect = 'Collecting system info'
        ProgReportBuild   = 'Building report'
        ProgReportWrite   = 'Writing report file'

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
        Started           = 'DeployWorkstation v5.2 Iniciado'
        WingetRequired    = "Se requiere Winget. Instale 'App Installer' desde Microsoft Store."
        WingetFound       = 'Winget encontrado'
        WingetMissing     = 'Winget no encontrado en el PATH.'
        ManagingSources   = 'Administrando fuentes de winget'
        ProgSources       = 'Administrando Fuentes de Winget'
        RemovingMsstore   = 'Eliminando fuente msstore (rendimiento)'
        RefreshingSources = 'Actualizando indice de fuentes winget'
        SourcesFailed     = 'No se pudieron administrar las fuentes de winget'

        PhaseBloatware    = 'ELIMINACION DE SOFTWARE NO DESEADO'
        PhaseApps         = 'INSTALACION DE APLICACIONES'
        PhaseConfig       = 'CONFIGURACION DEL SISTEMA'
        PhaseReporting    = 'GENERANDO INFORME'

        SkipBloatware     = 'Eliminacion de software omitida (-SkipBloatwareRemoval).'
        SkipApps          = 'Instalacion de aplicaciones omitida (-SkipAppInstall).'
        SkipConfig        = 'Configuracion del sistema omitida (-SkipSystemConfig).'

        ProgOverall       = 'Configurando Estacion de Trabajo'
        ProgBloatware     = 'Eliminando Software No Deseado'
        ProgAppx          = 'Eliminando Paquetes Appx'
        ProgCaps          = 'Eliminando Capacidades de Windows'
        ProgMcAfee        = 'Verificando McAfee'
        ProgApps          = 'Instalando Aplicaciones'
        ProgConfig        = 'Configurando Sistema'

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

        SumTitle          = 'RESUMEN DE DESPLIEGUE'
        SumAppsOK         = 'Aplicaciones instaladas / omitidas'
        SumAppsFail       = 'Aplicaciones fallidas'
        SumAppx           = 'Paquetes Appx eliminados'
        SumCaps           = 'Capacidades eliminadas'
        SumConfigOK       = 'Claves de configuracion aplicadas'
        SumConfigFail     = 'Claves de configuracion fallidas'
        SumMcAfee         = 'Productos McAfee eliminados'

        Completed         = 'DeployWorkstation.ps1 Completado'
        SetupComplete     = 'Configuracion completada!'
        SetupFailed       = 'Configuracion fallida - ver registro'
        PressEnter        = 'Presione Enter para salir...'
        ReportSaved       = 'Informe HTML guardado'
        ReportFail        = 'Error al escribir el informe HTML'
        CriticalError     = 'ERROR CRITICO'

        WingetOld         = 'Winget desactualizado, actualizando'
        WingetBootstrap   = 'Instalando App Installer (winget)'
        WingetBootOK      = 'App Installer instalado exitosamente'
        WingetBootFail    = 'Error al instalar App Installer'
        WingetReRegister  = 'Intentando re-registro del paquete'
        WingetDownload    = 'Descargando App Installer de Microsoft'

        InstallRetrying   = 'Error de red, reintentando'
        CapWuUnavail      = 'Omitido - Windows Update no accesible en este sistema'
        HomeEditionNote   = 'Clave de politica escrita pero sin efecto en Windows Home'
        OneDriveOem       = 'Eliminacion de OneDrive OEM'
        OneDriveOemFound  = 'Binario OEM de OneDrive encontrado'
        OneDriveOemDone   = 'Desinstalacion de OneDrive OEM completada'
        OneDriveOemNone   = 'No se encontro binario de configuracion de OneDrive OEM'

        HtmlEdition       = 'Edicion'
        HtmlBuild         = 'Version de Compilacion'
        ProgWingetCheck   = 'Verificando Winget'
        ProgSourcesList   = 'Listando fuentes'
        ProgSourcesUpdate = 'Actualizando fuentes'
        ProgReportCollect = 'Recopilando informacion del sistema'
        ProgReportBuild   = 'Construyendo informe'
        ProgReportWrite   = 'Escribiendo archivo de informe'

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

$culture      = (Get-Culture).Name
$primaryTag   = $culture.Split('-')[0]
$resolvedLang = if ($script:Strings.ContainsKey($culture)) {
    $culture
} else {
    $tagMatch = $script:Strings.Keys | Where-Object { $_ -match "^$primaryTag-" } | Select-Object -First 1
    if ($tagMatch) { $tagMatch } else { 'en-US' }
}
$script:Lang = $script:Strings[$resolvedLang]

function T {
    param([string]$Key)
    if ($script:Lang.ContainsKey($Key)) { return $script:Lang[$Key] }
    return $Key
}

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
    $script:EventLog.Add(@{
        Timestamp = $timestamp
        Level     = $Level
        Message   = $Message
    })
}

# ================================
# Progress
# ================================

function Set-OverallProgress {
    param(
        [string]$Status,
        [int]$Percent
    )
    Write-Progress -Id 0 -Activity (T 'ProgOverall') -Status $Status -PercentComplete $Percent
}

function Set-PhaseProgress {
    param(
        [string]$Activity,
        [string]$Status,
        [int]$Current,
        [int]$Total
    )
    $pct = if ($Total -gt 0) { [int](($Current / $Total) * 100) } else { 0 }
    Write-Progress -Id 1 -ParentId 0 -Activity $Activity -Status $Status -PercentComplete $pct
}

function Clear-PhaseProgress {
    Write-Progress -Id 1 -Activity ' ' -Completed
}

# ================================
# Summary and Results
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

# ================================
# OS Detection
# ================================

$script:OsInfo  = Get-CimInstance Win32_OperatingSystem
$script:OsBuild = [int]$script:OsInfo.BuildNumber
$script:IsWin11 = $script:OsBuild -ge 22000

try {
    $regOs = Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion' -ErrorAction Stop
    $script:EditionId = [string]$regOs.EditionID
} catch {
    $script:EditionId = ''
}

$script:IsHome = $script:EditionId -match 'Home'

Write-Log "===== $(T 'Started') =====" -Level 'SECTION'
Write-Log "PowerShell  : $($PSVersionTable.PSVersion)"
Write-Log "OS          : $($script:OsInfo.Caption) (Build $script:OsBuild)"
Write-Log "Edition ID  : $($script:EditionId)"
Write-Log "Hostname    : $env:COMPUTERNAME"
Write-Log "Language    : $resolvedLang"
Write-Log "Log file    : $LogPath"
Write-Log "HTML report : $ReportPath"

# ================================
# Helpers
# ================================

function Set-RegistryValue {
    param(
        [string]$Path,
        [string]$Name,
        [int]$Value
    )

    try {
        if (-not (Test-Path $Path)) {
            New-Item -Path $Path -Force | Out-Null
        }

        $existing = Get-ItemProperty -Path $Path -Name $Name -ErrorAction SilentlyContinue
        if ($null -eq $existing) {
            New-ItemProperty -Path $Path -Name $Name -Value $Value -PropertyType DWord -Force -ErrorAction Stop | Out-Null
        } else {
            Set-ItemProperty -Path $Path -Name $Name -Value $Value -Force -ErrorAction Stop
        }

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

function Install-WingetIfNeeded {
    $minVersion = [Version]'1.2.0'
    Set-PhaseProgress -Activity (T 'ProgWingetCheck') -Status (T 'Checking') -Current 1 -Total 3

    $needsInstall = $false
    $wingetCmd    = Get-Command winget -ErrorAction SilentlyContinue

    if (-not $wingetCmd) {
        Write-Log (T 'WingetMissing') -Level 'WARN'
        $needsInstall = $true
    } else {
        $rawVer = (winget --version 2>$null) -replace '[^\d\.]', ''
        try {
            if ([Version]$rawVer -lt $minVersion) {
                Write-Log "$(T 'WingetOld'): v$rawVer (minimum $minVersion)" -Level 'WARN'
                $needsInstall = $true
            } else {
                Write-Log "$(T 'WingetFound'): v$rawVer"
            }
        }
        catch {
            Write-Log "$(T 'WingetFound'): $rawVer"
        }
    }

    if (-not $needsInstall) {
        Clear-PhaseProgress
        return $true
    }

    Write-Log "$(T 'WingetBootstrap')..." -Level 'SECTION'
    Set-PhaseProgress -Activity (T 'ProgWingetCheck') -Status (T 'WingetReRegister') -Current 2 -Total 3

    try {
        Write-Log (T 'WingetReRegister')
        Add-AppxPackage -RegisterByFamilyName -MainPackage 'Microsoft.DesktopAppInstaller_8wekyb3d8bbwe' -ErrorAction Stop
        Start-Sleep -Seconds 3
        $null = Get-Command winget -ErrorAction Stop
        Write-Log (T 'WingetBootOK') -Level 'SUCCESS'
        Clear-PhaseProgress
        return $true
    }
    catch {
        Write-Log "Re-registration failed: $($_.Exception.Message)" -Level 'WARN'
    }

    Set-PhaseProgress -Activity (T 'ProgWingetCheck') -Status (T 'WingetDownload') -Current 3 -Total 3
    $tempPath = Join-Path $env:TEMP 'AppInstaller.msixbundle'

    try {
        Write-Log (T 'WingetDownload')
        if (Get-Command Start-BitsTransfer -ErrorAction SilentlyContinue) {
            Start-BitsTransfer -Source 'https://aka.ms/getwinget' -Destination $tempPath -ErrorAction Stop
        } else {
            (New-Object System.Net.WebClient).DownloadFile('https://aka.ms/getwinget', $tempPath)
        }

        Add-AppxPackage -Path $tempPath -ErrorAction Stop
        Start-Sleep -Seconds 3
        $null = Get-Command winget -ErrorAction Stop

        Write-Log (T 'WingetBootOK') -Level 'SUCCESS'
        Clear-PhaseProgress
        return $true
    }
    catch {
        Write-Log "$(T 'WingetBootFail'): $($_.Exception.Message)" -Level 'ERROR'
        return $false
    }
    finally {
        Remove-Item $tempPath -Force -ErrorAction SilentlyContinue
        Clear-PhaseProgress
    }
}

function Initialize-WingetSources {
    Write-Log (T 'ManagingSources')
    try {
        Set-PhaseProgress -Activity (T 'ProgSources') -Status (T 'ProgSourcesList') -Current 1 -Total 2
        $sources = winget source list 2>$null

        if ($sources -match 'msstore') {
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
        Set-PhaseProgress -Activity (T 'ProgBloatware') -Status "$(T 'Checking'): $pattern" -Current $current -Total $total

        Write-Log "$(T 'Checking'): $pattern"
        try {
            $found = winget list --name "$pattern" --accept-source-agreements 2>$null |
                     Where-Object { $_ -and $_ -notmatch 'Name\s+Id\s+Version' -and $_.Trim() }

            if (-not $found) {
                Write-Log "$(T 'NotFound'): $pattern"
                Add-Result -Section (T 'PhaseBloatware') -Item $pattern -Status 'SKIPPED' -Detail (T 'NotInstalled')
                continue
            }

            Set-PhaseProgress -Activity (T 'ProgBloatware') -Status "$(T 'Removing'): $pattern" -Current $current -Total $total
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
                Remove-AppxProvisionedPackage -Online -PackageName $pkg.PackageName -ErrorAction SilentlyContinue | Out-Null
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

            if ($uninstallArgs -notmatch '/S|/silent|/quiet') {
                $uninstallArgs += ' /S /quiet'
            }

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
# App Installation
# ================================

function Install-StandardApps {
    Write-Log "--- $(T 'ProgApps') ---" -Level 'SECTION'

    $alreadyInstalledCode = -1978335189
    $networkErrorCodes = @(
        -1978334967,
        -1978334966,
        -2147012887,
        -2147012873,
        -2147012867
    )

    $maxRetries    = 2
    $retryDelaySec = 10

    $appsToInstall = @(
        @{ Id = 'Malwarebytes.Malwarebytes';         Name = 'Malwarebytes'                  },
        @{ Id = 'BleachBit.BleachBit';               Name = 'BleachBit'                     },
        @{ Id = 'Google.Chrome';                     Name = 'Google Chrome'                 },
        @{ Id = 'Adobe.Acrobat.Reader.64-bit';       Name = 'Adobe Acrobat Reader (64-bit)' },
        @{ Id = '7zip.7zip';                         Name = '7-Zip'                         },
        @{ Id = 'VideoLAN.VLC';                      Name = 'VLC Media Player'              },
        @{ Id = 'Microsoft.DotNet.Framework.4.8';    Name = '.NET Framework 4.8'            },
        @{ Id = 'Microsoft.DotNet.DesktopRuntime.6'; Name = '.NET 6 Desktop Runtime'        },
        @{ Id = 'Microsoft.DotNet.DesktopRuntime.7'; Name = '.NET 7 Desktop Runtime'        },
        @{ Id = 'Microsoft.DotNet.DesktopRuntime.8'; Name = '.NET 8 Desktop Runtime'        },
        @{ Id = 'Microsoft.VCRedist.2015+.x64';      Name = 'VC++ 2015-2022 Redist (x64)'   },
        @{ Id = 'Microsoft.VCRedist.2015+.x86';      Name = 'VC++ 2015-2022 Redist (x86)'   }
    )

    $total   = $appsToInstall.Count
    $current = 0

    foreach ($app in $appsToInstall) {
        $current++
        Set-PhaseProgress -Activity (T 'ProgApps') -Status "$(T 'Installing'): $($app.Name) ($current/$total)" -Current $current -Total $total

        Write-Log "$(T 'Installing'): $($app.Name) [$($app.Id)]"
        try {
            $attempt   = 0
            $exitCode  = -1
            $wingetOut = $null

            do {
                $attempt++
                $wingetOut = winget install --id $app.Id --source winget --accept-package-agreements --accept-source-agreements --silent 2>&1
                $exitCode  = $LASTEXITCODE

                if ($exitCode -eq 0 -or $exitCode -eq $alreadyInstalledCode) { break }

                if ($attempt -le $maxRetries -and $exitCode -in $networkErrorCodes) {
                    Write-Log "$(T 'InstallRetrying') ($attempt/$maxRetries): $($app.Name) [exit $exitCode]" -Level 'WARN'
                    Start-Sleep -Seconds $retryDelaySec
                } else {
                    break
                }
            } while ($true)

            if ($exitCode -eq 0) {
                Write-Log "$(T 'InstallOK'): $($app.Name)" -Level 'SUCCESS'
                Add-Result -Section (T 'PhaseApps') -Item $app.Name -Status 'OK' -Detail (T 'InstallOK')
                $script:Summary.AppsInstalled++
            } elseif ($exitCode -eq $alreadyInstalledCode) {
                Write-Log "$(T 'AlreadyInstalled'): $($app.Name)" -Level 'SUCCESS'
                Add-Result -Section (T 'PhaseApps') -Item $app.Name -Status 'OK' -Detail (T 'AlreadyInstalled')
                $script:Summary.AppsInstalled++
            } else {
                Write-Log "$(T 'InstallFail'): $($app.Name) - exit code $exitCode" -Level 'WARN'
                $diagLines = ($wingetOut | Where-Object { "$_".Trim() }) | Select-Object -Last 5
                foreach ($line in $diagLines) {
                    Write-Log "  $line" -Level 'WARN'
                }
                Add-Result -Section (T 'PhaseApps') -Item $app.Name -Status 'WARN' -Detail "Exit code $exitCode"
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
        @{ Path = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\DataCollection';  Name = 'AllowTelemetry';          Value = 0; PolicyOnly = $true  },
        @{ Path = 'HKLM:\SOFTWARE\Microsoft\Windows\Windows Error Reporting';  Name = 'Disabled';                Value = 1; PolicyOnly = $false },
        @{ Path = 'HKLM:\SOFTWARE\Microsoft\SQMClient\Windows';                Name = 'CEIPEnable';              Value = 0; PolicyOnly = $false },
        @{ Path = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\AdvertisingInfo'; Name = 'DisabledByGroupPolicy';  Value = 1; PolicyOnly = $true  }
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
    Write-Log "--- $(T 'OneDriveOem') ---" -Level 'SECTION'

    $setupPaths = @(
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
            return
        }
    }

    Write-Log (T 'OneDriveOemNone')
}

# ================================
# HTML Report
# ================================

function Export-HtmlReport {
    param([string]$OverallStatus)

    Write-Log "$(T 'PhaseReporting')."
    Set-PhaseProgress -Activity (T 'PhaseReporting') -Status (T 'ProgReportCollect') -Current 1 -Total 3

    $os        = Get-CimInstance Win32_OperatingSystem
    $cpu       = ConvertTo-HtmlSafe ((Get-CimInstance Win32_Processor | Select-Object -First 1).Name)
    $osCaption = ConvertTo-HtmlSafe $os.Caption

    try {
        $regOs       = Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion' -ErrorAction Stop
        $osEditionRaw = if ($regOs.EditionID) { [string]$regOs.EditionID } else { 'Unknown' }
    }
    catch {
        $osEditionRaw = 'Unknown'
    }

    $osEdition   = ConvertTo-HtmlSafe $osEditionRaw
    $osBuild     = $script:OsBuild
    $ramGB       = [math]::Round($os.TotalVisibleMemorySize / 1MB, 1)
    $uptimeHrs   = [math]::Round(((Get-Date) - $os.LastBootUpTime).TotalHours, 1)
    $duration    = (Get-Date) - $script:StartTime
    $durationMins = [Math]::Floor($duration.TotalMinutes)
    $durationHrs  = [Math]::Round($duration.TotalHours, 2)

    $resultsRows = foreach ($row in $script:Results) {
        "<tr><td>$(ConvertTo-HtmlSafe $row.Section)</td><td>$(ConvertTo-HtmlSafe $row.Item)</td><td>$(ConvertTo-HtmlSafe $row.Status)</td><td>$(ConvertTo-HtmlSafe $row.Detail)</td></tr>"
    }

    $eventRows = foreach ($entry in ($script:EventLog | Select-Object -Last 200)) {
        "<tr><td>$(ConvertTo-HtmlSafe $entry.Timestamp)</td><td>$(ConvertTo-HtmlSafe $entry.Level)</td><td>$(ConvertTo-HtmlSafe $entry.Message)</td></tr>"
    }

    Set-PhaseProgress -Activity (T 'PhaseReporting') -Status (T 'ProgReportBuild') -Current 2 -Total 3

    $html = @"
<!DOCTYPE html>
<html>
<head>
<meta charset="utf-8" />
<title>$(T 'HtmlTitle')</title>
<style>
body { font-family: Segoe UI, Arial, sans-serif; margin: 20px; color: #222; }
h1, h2 { color: #0b5394; }
table { border-collapse: collapse; width: 100%; margin-bottom: 24px; }
th, td { border: 1px solid #d9d9d9; padding: 8px; text-align: left; vertical-align: top; }
th { background: #f3f6f9; }
.ok { color: #0a7d28; font-weight: bold; }
.warn { color: #b36b00; font-weight: bold; }
.failed { color: #b00020; font-weight: bold; }
.section { margin-top: 24px; }
.meta { margin-bottom: 16px; color: #555; }
</style>
</head>
<body>
<h1>$(T 'HtmlTitle')</h1>
<div class="meta">$(T 'HtmlGenerated'): $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')</div>

<h2>$(T 'HtmlSysInfo')</h2>
<table>
<tr><th>$(T 'HtmlHostname')</th><td>$(ConvertTo-HtmlSafe $env:COMPUTERNAME)</td></tr>
<tr><th>$(T 'HtmlOS')</th><td>$osCaption</td></tr>
<tr><th>$(T 'HtmlEdition')</th><td>$osEdition</td></tr>
<tr><th>$(T 'HtmlBuild')</th><td>$osBuild</td></tr>
<tr><th>$(T 'HtmlCPU')</th><td>$cpu</td></tr>
<tr><th>$(T 'HtmlRAM')</th><td>$ramGB GB</td></tr>
<tr><th>$(T 'HtmlUptime')</th><td>$uptimeHrs $(T 'HtmlHrs')</td></tr>
<tr><th>$(T 'HtmlRunTime')</th><td>$durationMins min ($durationHrs $(T 'HtmlHrs'))</td></tr>
<tr><th>$(T 'HtmlVersion')</th><td>$($script:Version)</td></tr>
<tr><th>Status</th><td>$(ConvertTo-HtmlSafe $OverallStatus)</td></tr>
<tr><th>$(T 'HtmlTechnician')</th><td>$(ConvertTo-HtmlSafe $env:USERNAME)</td></tr>
</table>

<h2>$(T 'HtmlSummary')</h2>
<table>
<tr><th>$(T 'HtmlAppsOK')</th><td>$($script:Summary.AppsInstalled)</td></tr>
<tr><th>$(T 'HtmlAppsFail')</th><td>$($script:Summary.AppsFailed)</td></tr>
<tr><th>$(T 'HtmlAppxRemoved')</th><td>$($script:Summary.AppxRemoved)</td></tr>
<tr><th>$(T 'HtmlCapsRemoved')</th><td>$($script:Summary.CapabilitiesRemoved)</td></tr>
<tr><th>$(T 'HtmlConfigOK')</th><td>$($script:Summary.HardeningApplied)</td></tr>
<tr><th>$(T 'HtmlConfigFail')</th><td>$($script:Summary.HardeningFailed)</td></tr>
<tr><th>$(T 'HtmlMcAfee')</th><td>$($script:Summary.McAfeeRemoved)</td></tr>
</table>

<h2>$(T 'HtmlResults')</h2>
<table>
<tr>
<th>Section</th>
<th>$(T 'HtmlItem')</th>
<th>$(T 'HtmlStatus')</th>
<th>$(T 'HtmlDetail')</th>
</tr>
$($resultsRows -join "`r`n")
</table>

<h2>$(T 'HtmlEventLog')</h2>
<table>
<tr>
<th>$(T 'HtmlTimestamp')</th>
<th>$(T 'HtmlLevel')</th>
<th>$(T 'HtmlMessage')</th>
</tr>
$($eventRows -join "`r`n")
</table>
</body>
</html>
"@

    Set-PhaseProgress -Activity (T 'PhaseReporting') -Status (T 'ProgReportWrite') -Current 3 -Total 3

    try {
        [System.IO.File]::WriteAllText($ReportPath, $html, [System.Text.Encoding]::UTF8)
        Write-Log (T 'ReportSaved') -Level 'SUCCESS'
    }
    catch {
        Write-Log "$(T 'ReportFail'): $($_.Exception.Message)" -Level 'ERROR'
    }
    finally {
        Clear-PhaseProgress
    }
}

# ================================
# Main
# ================================

$overallStatus = 'OK'
$fatalError    = $false

try {
    if (-not (Install-WingetIfNeeded)) {
        throw (T 'WingetRequired')
    }

    Initialize-WingetSources

    if ($SkipBloatwareRemoval) {
        Write-Log (T 'SkipBloatware') -Level 'WARN'
        Add-Result -Section (T 'PhaseBloatware') -Item 'Bloatware Removal' -Status 'SKIPPED' -Detail (T 'SkipBloatware')
    } else {
        Set-OverallProgress -Status (T 'PhaseBloatware') -Percent 15

        Remove-WingetApps -AppPatterns @(
            'McAfee',
            'WildTangent',
            'Dropbox Promotion',
            'Booking.com',
            'ExpressVPN',
            'Amazon Alexa',
            'Spotify'
        )
        Remove-AppxPackages
        Remove-WindowsCapabilities
        Remove-McAfeeProducts
        Remove-OneDriveOem
    }

    if ($SkipAppInstall) {
        Write-Log (T 'SkipApps') -Level 'WARN'
        Add-Result -Section (T 'PhaseApps') -Item 'Application Installation' -Status 'SKIPPED' -Detail (T 'SkipApps')
    } else {
        Set-OverallProgress -Status (T 'PhaseApps') -Percent 55
        Install-StandardApps
    }

    if ($SkipSystemConfig) {
        Write-Log (T 'SkipConfig') -Level 'WARN'
        Add-Result -Section (T 'PhaseConfig') -Item 'System Configuration' -Status 'SKIPPED' -Detail (T 'SkipConfig')
    } else {
        Set-OverallProgress -Status (T 'PhaseConfig') -Percent 80
        Set-SystemConfiguration
    }

    if ($script:Summary.AppsFailed -gt 0 -or $script:Summary.HardeningFailed -gt 0) {
        $overallStatus = 'Completed with warnings'
    } else {
        $overallStatus = 'Completed successfully'
    }
}
catch {
    $fatalError    = $true
    $overallStatus = 'Failed'
    Write-Log "$(T 'CriticalError'): $($_.Exception.Message)" -Level 'ERROR'
    Add-Result -Section 'Fatal' -Item 'Unhandled exception' -Status 'FAILED' -Detail $_.Exception.Message
}
finally {
    Set-OverallProgress -Status (T 'PhaseReporting') -Percent 95
    Export-HtmlReport -OverallStatus $overallStatus
    Write-Progress -Id 0 -Completed

    Write-Log "===== $(T 'Completed') =====" -Level 'SECTION'

    if ($fatalError) {
        Write-Host (T 'SetupFailed') -ForegroundColor Red
        exit 1
    } elseif ($script:Summary.AppsFailed -gt 0 -or $script:Summary.HardeningFailed -gt 0) {
        Write-Host (T 'SetupFailed') -ForegroundColor Yellow
        exit 1
    } else {
        Write-Host (T 'SetupComplete') -ForegroundColor Green
        exit 0
    }
}
