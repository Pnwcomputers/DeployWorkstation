# Configuration Guide

## Overview

DeployWorkstation is configured via **command-line parameters** passed to `DeployWorkstation.ps1`. The `Config/Examples/` directory contains **reference JSON profiles** showing representative app lists for different deployment scenarios — these files are not loaded by the script automatically, but serve as a guide for customizing the `$script:ManagedApps` array.

---

## Command-Line Parameters

| Parameter | Type | Description |
|-----------|------|-------------|
| `-SkipAppInstall` | Switch | Skip all application installation |
| `-SkipBloatwareRemoval` | Switch | Skip bloatware and UWP removal |
| `-SkipSystemConfig` | Switch | Skip registry/policy hardening |
| `-UpdateApps` | Switch | Upgrade already-installed managed apps in-place |
| `-LogPath <path>` | String | Custom path for the log file |
| `-ReportPath <path>` | String | Custom path for the HTML report |

---

## Adding or Changing Applications

Edit the `$script:ManagedApps` array near the top of `DeployWorkstation.ps1`. Each entry requires a winget package ID and a display name:

```powershell
$script:ManagedApps = @(
    @{ Id = 'Google.Chrome';               Name = 'Google Chrome'                 },
    @{ Id = 'Malwarebytes.Malwarebytes';   Name = 'Malwarebytes'                  },
    @{ Id = 'Microsoft.DotNet.DesktopRuntime.8'; Name = '.NET 8 Desktop Runtime' },
    # Add more entries here
)
```

Find winget IDs with: `winget search <AppName> --source winget`

---

## Example Profiles (Reference Only)

The following JSON files in `Config/Examples/` show suggested app lists for different deployment types. They are **not read by the script** — use them as a reference when updating `$script:ManagedApps`.

<a name="corporate"></a>
### Corporate Profile — [Corporate.json](../Config/Examples/Corporate.json)

Designed for business workstations. Emphasizes security, productivity, and enterprise tooling:
- Core: Chrome, 7-Zip, Acrobat Reader, VLC, Malwarebytes
- Business: Microsoft Teams, Zoom, Microsoft Office
- Security: Windows Defender enabled, consumer features disabled

<a name="developer"></a>
### Developer Profile — [Developer.json](../Config/Examples/Developer.json)

Designed for programming workstations. Adds development tooling on top of the core set:
- Core: Chrome, 7-Zip, Acrobat Reader, VLC
- Dev tools: VS Code, Git, Windows Terminal, Docker Desktop, Node.js, Python, Postman
- Utilities: PowerToys, JetBrains Toolbox, Notepad++, WinSCP
- Developer mode enabled

<a name="home-user"></a>
### Home User Profile — [HomeUser.json](../Config/Examples/HomeUser.json)

Designed for personal/home computers. Lighter touch — preserves media apps:
- Core: Chrome, 7-Zip, Acrobat Reader, VLC
- Home apps: Skype, Zoom, Spotify, Discord
- Preserves: Calculator, Camera, Photos, Movies & TV
- Telemetry disabled, advertising ID disabled

---

## System Configuration (Registry Hardening)

The `Set-SystemConfiguration` function applies the following registry settings:

| Key | Value | Effect | Home Edition |
|-----|-------|--------|--------------|
| `HKLM:\SOFTWARE\Policies\Microsoft\Windows\DataCollection\AllowTelemetry` | 0 | Disables telemetry | Policy-only — written but has no effect |
| `HKLM:\SOFTWARE\Microsoft\Windows\Windows Error Reporting\Disabled` | 1 | Disables error reporting | Effective |
| `HKLM:\SOFTWARE\Microsoft\SQMClient\Windows\CEIPEnable` | 0 | Disables CEIP | Effective |
| `HKLM:\SOFTWARE\Policies\Microsoft\Windows\AdvertisingInfo\DisabledByGroupPolicy` | 1 | Disables advertising ID | Policy-only — written but has no effect |

> **Windows Home note:** Policy-key paths (`SOFTWARE\Policies\...`) are written successfully but have no enforced effect on Windows Home edition. The script logs a `WARN` for these keys when running on Home.
