# Installation Guide

## System Requirements

### Minimum Requirements
- **Operating System**: Windows 10 (1909) or Windows 11
- **PowerShell**: Windows PowerShell 5.1 (built into Windows 10/11)
- **RAM**: 4 GB minimum, 8 GB recommended
- **Storage**: 2 GB free space for downloaded applications
- **Network**: Internet connection for winget packages (winget auto-installs if missing)
- **Account**: Local Administrator or Domain Admin

> **Note:** The script runs exclusively under Windows PowerShell 5.1. If launched from PowerShell 7/Core, it automatically relaunches itself in `powershell.exe` (Windows PowerShell 5.1).

---

## Installation Methods

### Method 1: Git Clone (Recommended)
```bash
git clone https://github.com/Pnwcomputers/DeployWorkstation.git
cd DeployWorkstation
```

### Method 2: Direct Download
1. Go to the [GitHub releases page](https://github.com/Pnwcomputers/DeployWorkstation/releases)
2. Download the latest `.zip` archive
3. Extract to a folder (e.g., `C:\Deploy` or a USB drive root)

---

## Running the Script

### Option A: Batch Launcher (Recommended)

Double-click `DeployWorkstation.bat`. It:
- Requests UAC elevation automatically
- Presents a menu with 6 deployment modes
- Launches the correct PowerShell parameters based on your choice

### Option B: Quick Start Menu

Run `QuickStart.cmd` for a simplified 5-option menu (no UAC auto-elevation).

### Option C: Direct PowerShell

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\DeployWorkstation.ps1
```

With options:
```powershell
# App install only (skip bloatware removal and system config)
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\DeployWorkstation.ps1 -SkipBloatwareRemoval -SkipSystemConfig

# Update already-installed apps in-place
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\DeployWorkstation.ps1 -SkipBloatwareRemoval -SkipSystemConfig -UpdateApps
```

---

## Deployment Modes

| Mode | Parameters | Description |
|------|-----------|-------------|
| Full Deployment | *(none)* | Bloatware removal + app install + system config |
| Bloatware Only | `-SkipAppInstall -SkipSystemConfig` | Remove UWP/Win32 bloatware only |
| Apps Only | `-SkipBloatwareRemoval -SkipSystemConfig` | Install/update managed apps only |
| Config Only | `-SkipBloatwareRemoval -SkipAppInstall` | Registry/policy hardening only |
| Update Apps | `-SkipBloatwareRemoval -SkipSystemConfig -UpdateApps` | Upgrade already-installed managed apps |

---

## USB / Network Share Deployment

1. Copy both `DeployWorkstation.ps1` and `DeployWorkstation.bat` to the same folder on your USB drive or network share
2. On the target machine, open the USB/share in File Explorer
3. Double-click `DeployWorkstation.bat`

The script uses `$PSScriptRoot` to resolve all paths, so it works from any location.

---

## Output Files

After the run completes, two files are created in the same folder as the script:

| File | Description |
|------|-------------|
| `DeployWorkstation.log` | Plain-text log with timestamps and log levels |
| `DeployWorkstation.html` | Dark-themed HTML report with system info, summary counters, and full event log |

Use `-LogPath` and `-ReportPath` to write these to a different location:
```powershell
.\DeployWorkstation.ps1 -LogPath C:\Logs\deploy.log -ReportPath C:\Logs\deploy.html
```

---

## Troubleshooting

See [TROUBLESHOOTING.md](TROUBLESHOOTING.md) for common issues and their resolutions.
