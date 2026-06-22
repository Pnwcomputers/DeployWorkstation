# 🚀 DeployWorkstation
## *Automated Application Setup, Bloatware Removal & Updating Utility for Windows 10/11 Computers*

<p align="center">
  <img src="assets/deployworkstation.png" alt="A PowerShell-based, automated provisioning solution that transforms a Windows 10 or Windows 11 workstation deployment process into a single plug-and-play operation." width="600"/>
</p>

![Automation Level](https://img.shields.io/badge/Automation-Zero%20Touch-green)
![Windows Support](https://img.shields.io/badge/Windows-10%20%7C%2011-blue)
![PowerShell Version](https://img.shields.io/badge/PowerShell-5.1%2B-blue)
![Enterprise Ready](https://img.shields.io/badge/Enterprise-Ready-purple)
![GitHub issues](https://img.shields.io/github/issues/Pnwcomputers/DeployWorkstation)
![Maintenance](https://img.shields.io/badge/Maintained-Yes-green)

### **Zero-Touch Windows Workstation Provisioning & Maintenance Toolkit**
 
A PowerShell-based, automated provisioning solution that transforms Windows 10 & 11 workstation deployment from a 30-step manual process into a single "plug-and-play" operation. Whether you're imaging bare metal, cleaning up an existing PC, or running routine maintenance on already-deployed machines, DeployWorkstation handles bloatware removal, essential application installation, and in-place app upgrades.
 
## 🐛 Bugs Fixed in v5.2

| # | File | Issue | Fix |
|---|------|-------|-----|
| 1 | `QuickStart.cmd` | All 4 menu options passed `-ConfigFile` - a parameter that doesn't exist in the PS1. Every choice errored immediately. | Rewrote to use the actual `-SkipBloatwareRemoval`, `-SkipAppInstall`, `-SkipSystemConfig`, and `-UpdateApps` params. |
| 2 | `QuickStart.cmd` | `goto start` on invalid input → no `:start` label existed → `cmd.exe` crashed the script. | Added `:start` label at the top of the menu block. |
| 3 | `tests/DeployWorkstation.Tests.ps1:42` | Test asserted `DeployWorkstation.cmd` exists - it never did - permanent CI failure. | Changed to check `QuickStart.cmd` which actually exists. |
| 4 | `.github/workflows/test-powershell.yml:37` | `upload-artifact@v3` was deprecated and removed by GitHub. | Upgraded to `@v4`. |
| 5 | `DeployWorkstation.ps1:587` | `winget--version` can output multiple lines; `-replace` on an array returns an array; `[Version]` cast on an array throws and silently skips the minimum version check. | Added `Where-Object` + `Select-Object-Last 1` before the replace. |

### Code Quality Updates/Fixes:

| # | File | Issue | Fix |
|---|------|-------|-----|
| 6 | `DeployWorkstation.ps1:529` | `Set-ExecutionPolicy` was placed mid-file after all function definitions - if it threw, the machine would be left partially configured. | Moved to line 26, right after `$ProgressPreference`. |
| 7 | `DeployWorkstation.ps1:535` | `$script:IsWin11` computed but never referenced anywhere. | Removed. |
| 8 | `Export-HtmlReport` | Called `Get-CimInstance Win32_OperatingSystem` a second time at report generation, even though it was already cached as `$script:OsInfo`. | Replaced with `$script:OsInfo`. |

---

## ✨ Key Features
 
- **🔐 Self-Elevating & Policy-Bypassing** - Automatically relaunches under Windows PowerShell 5.1 with `-ExecutionPolicy Bypass` and UAC elevation
- **🗑️ UWP "Bloatware" Purge** - Comprehensive removal of built-in apps including Copilot, Teams, New Outlook, Clipchamp, OneDrive, Xbox, and more
- **⚙️ Win32/MSI Removal & DISM Cleanup** - Enterprise software removal via WinGet, DISM, and registry manipulation
- **📦 Standard App Installation & Upgrade** - Automated install and in-place upgrade of essential third-party tools via WinGet
- **📋 Centralized Logging** - Detailed operation logs plus a dark-themed HTML report with system info summary and full event log
- **🔄 App Update Support** - Detects and upgrades already-installed applications in-place; safe to re-run on existing machines
- **🛡️ Winget Auto-Bootstrap** - Automatically downloads and installs winget on OEM machines where it's missing or outdated
- **🔁 Network Retry Logic** - Automatic retries with delay on transient network errors during installation
- **🖥️ Windows Edition Awareness** - Detects Home vs. Pro/Enterprise and warns when policy keys will have no effect
- **🗑️ OEM OneDrive Removal** - Three-path removal covering both Appx and embedded OEM binaries
- **🌐 Multi-Language Support** - Auto-detects locale via `Get-Culture`; ships with `en-US` and `es-ES`
- **✅ Real-time Progress** - `Write-Progress` console bars throughout all major operations

## 🛡️ Automated Removal Capabilities
 
### UWP Applications Removed
- 📧 New Outlook (Microsoft.OutlookForWindows)
- 🤖 Copilot Assistant
- 👥 Microsoft Teams (Consumer)
- 🎬 Clipchamp Video Editor
- 👨‍👩‍👧‍👦 Family Safety & Parental Controls
- ☁️ OneDrive Sync Client (Appx + OEM binary)
- 💼 LinkedIn Integration
- 📞 Skype for Windows
- 🎮 Xbox Gaming Suite
- 🥽 Mixed Reality Portal
- 🖥️ Remote Desktop App
- 🆘 Quick Assist

### Windows Capabilities Removed
- 🆘 Quick Assist capability
- 🎮 Xbox TCUI, Game Overlay & Speech-to-Text overlays
- 🔑 OpenSSH Client

### Enterprise Software Removal
- 🛡️ McAfee Security Suite (registry-based uninstall)

### Privacy & Telemetry Hardening
- Disables Windows telemetry collection
- Disables Windows Error Reporting
- Disables CEIP (Customer Experience Improvement Program)
- Disables Advertising ID

## 📥 Essential Applications Installed
 
### Security & Maintenance
- 🦠 **Malwarebytes** - Malware protection
- 🧹 **BleachBit** - System cleanup and privacy tool

### Productivity Suite
- 🌐 **Google Chrome** - Web browser
- 🗜️ **7-Zip** - Universal archive manager
- 📄 **Adobe Acrobat Reader DC** (64-bit) - PDF viewer
- 📹 **VLC Media Player** - Universal media player

### Development Runtimes
- ⚙️ **.NET Framework 4.8** - Legacy app compatibility
- ⚙️ **.NET 8 Desktop Runtime** - LTS, supported through November 2026
- ⚙️ **.NET 10 Desktop Runtime** - LTS, supported through November 2030
- 🔧 **Visual C++ 2015–2022 Redistributables** (x64 & x86)

## 🚀 Installation & Usage
 
### Prerequisites
- 💻 Windows 10/11 (Most Editions)
- 🌐 Internet Connection (for WinGet packages - Winget auto-installs if missing)
- 👤 Administrator Access
- 💾 USB Drive or Network Share (Optional)

### Quick Start
 
1. **📥 Download the Repository**
   ```bash
   git clone https://github.com/Pnwcomputers/DeployWorkstation.git
   cd DeployWorkstation
   ```
 
2. **💾 Prepare Deployment Media**
   ```cmd
   copy DeployWorkstation.ps1 E:\
   copy DeployWorkstation.bat E:\
   ```

3. **▶️ Execute Deployment**
   ```cmd
   :: Method 1: Double-click the .bat launcher (recommended)
   DeployWorkstation.bat

   :: Method 2: Direct PowerShell execution
   powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\DeployWorkstation.ps1
   ```

4. **⏳ Select Deployment Mode**

   The launcher presents six options:

   | Option | Description |
   |--------|-------------|
   | **1 - Full Deployment** | Bloatware removal + app install + system config |
   | **2 - Bloatware Removal Only** | Skips app installation and system config |
   | **3 - App Installation Only** | Skips bloatware removal and system config |
   | **4 - System Config Only** | Registry/policy hardening only |
   | **5 - Update Installed Apps** | Upgrades managed apps in-place |
   | **6 - Exit** | |

5. **✅ Review & Reboot**
  - Script pauses for final review on completion
  - HTML report generated: `DeployWorkstation.html`
  - Detailed log available: `DeployWorkstation.log`
  - System reboot recommended for a clean finish

### Re-Running on Existing Machines
 
v5.2 is safe to run on already-deployed workstations. The upgrade logic updates any managed apps with newer versions available via winget.
 
```powershell
# Update managed apps only
.\DeployWorkstation.ps1 -SkipBloatwareRemoval -SkipSystemConfig -UpdateApps

# Re-run app install on a previously cleaned machine
.\DeployWorkstation.ps1 -SkipBloatwareRemoval
```
 
## 🔧 Advanced Configuration
 
### Command-Line Parameters
 
| Parameter | Description |
|-----------|-------------|
| `-SkipAppInstall` | Skip all application installation |
| `-SkipBloatwareRemoval` | Skip bloatware and UWP removal |
| `-SkipSystemConfig` | Skip registry/policy hardening |
| `-UpdateApps` | Upgrade already-installed managed apps in-place |
| `-LogPath <path>` | Custom path for the log file |
| `-ReportPath <path>` | Custom path for the HTML report |

### Adding Applications

To add or change which apps are installed, edit the `$script:ManagedApps` array near the top of `DeployWorkstation.ps1`. Each entry needs a winget ID and a display name:

```powershell
$script:ManagedApps = @(
    @{ Id = 'Google.Chrome';        Name = 'Google Chrome'   },
    @{ Id = 'Notepad++.Notepad++';  Name = 'Notepad++'       },
    # add more entries here
)
```

Find winget IDs with: `winget search <AppName>`
 
## 🎪 Configuration Profiles
 
| Profile | Use Case | Applications | Configuration |
|---------|----------|--------------|---------------|
| **[Corporate](Config/Examples/Corporate.json)** | Business workstations | Office tools, security software | [Details](docs/CONFIGURATION.md#corporate) |
| **[Developer](Config/Examples/Developer.json)** | Programming workstations | IDEs, development tools | [Details](docs/CONFIGURATION.md#developer) |
| **[Home User](Config/Examples/HomeUser.json)** | Personal computers | Media, communication apps | [Details](docs/CONFIGURATION.md#home-user) |
 
## 📊 Feature Comparison
 
| Feature | Manual Deployment | Other Tools | DeployWorkstation |
|---------|------------------|-------------|-------------------|
| **Automation Level** | ❌ Manual (8+ hours) | ⚠️ Partial (2-4 hours) | ✅ Full Automation (30 minutes) |
| **Bloatware Removal** | ❌ Manual deletion | ⚠️ Basic removal | ✅ Comprehensive purge |
| **Enterprise Software** | ❌ Manual uninstall | ❌ Often skipped | ✅ Registry-based removal |
| **App Updates** | ❌ Manual per-app | ⚠️ Separate tool needed | ✅ In-place upgrade on re-run |
| **Error Handling** | ❌ Manual intervention | ⚠️ Basic logging | ✅ Retry logic + HTML report |
| **Multi-Language** | ❌ | ❌ | ✅ en-US & es-ES auto-detected |
 
## 📈 Performance Metrics
 
| Metric | Traditional Method | DeployWorkstation |
|--------|-------------------|-------------------|
| **Total Time** | 4-8 hours | 30-45 minutes |
| **Manual Steps** | 30+ operations | 1 double-click |
| **Error Rate** | ~15% (human error) | <2% (automated) |
| **Consistency** | Variable | 100% standardized |
 
## 🎯 Use Cases
 
### **🏢 Enterprise Deployment**
- New employee workstation setup
- Hardware refresh projects
- Standardized corporate imaging
- Remote office provisioning

### **🔧 IT Service Providers**
- Client workstation deployment and routine maintenance
- Malware cleanup and rebuild
- Hardware upgrade services
- Maintenance contract fulfillment - re-run to keep apps current

### **🏫 Educational Institutions**
- Lab computer preparation
- Student workstation imaging
- Faculty equipment setup
- Semester refresh operations

### **🏠 Home & Small Business**
- Personal computer setup
- Family PC maintenance
- Small office standardization

## 🔍 Troubleshooting
 
### Common Issues
 
**Script won't execute**
- Ensure PowerShell execution policy allows scripts
- Verify UAC elevation is working
- Check Windows PowerShell 5.1 is available

**WinGet installation failures**
- The script will attempt to auto-install/repair winget on OEM machines
- Verify internet connectivity if bootstrap also fails
- Update Windows to latest version

**Bloatware returns after reboot**
- Run script as Administrator
- Ensure all user profiles are processed
- Check Group Policy restrictions

**App install fails with "package not found"**
- Run `winget source update` to refresh the package index
- Verify the winget ID is still current: `winget search <AppName>`

### Log Analysis
```powershell
# Check for errors and warnings in the deployment log
Get-Content .\DeployWorkstation.log | Select-String "ERROR|WARN"

# Verify WinGet package status
winget list --source winget
```
 
The HTML report (`DeployWorkstation.html`) provides the same information in a readable format - open it in any browser after the run completes.
 
## 🛠️ Project Structure
 
```text
DeployWorkstation/
├── DeployWorkstation.ps1      # Main PowerShell script
├── DeployWorkstation.bat      # Self-elevating launcher with full menu
├── QuickStart.cmd             # Simplified quick-launch menu
├── Installers/                # Place offline installers here (optional)
├── Logs/                      # Auto-created; holds log and HTML report
│   ├── DeployWorkstation.log
│   └── DeployWorkstation.html # Post-run HTML report
├── Config/
│   └── Examples/
│       ├── Corporate.json     # Example corporate profile
│       ├── Developer.json     # Example developer profile
│       └── HomeUser.json      # Example home user profile
├── docs/
│   ├── CONFIGURATION.md
│   ├── INSTALLATION.md
│   └── TROUBLESHOOTING.md
└── tests/
    └── DeployWorkstation.Tests.ps1
```
 
## 🔮 Roadmap
 
- 🖥️ GUI Configuration Interface (pre-run checkbox dialog)
- 🌐 Web-based Management Console
- 🚀 Domain Integration
- 🚀 Cloud Configuration Sync
- 🚀 Windows Server Hardening Mode (no app install)
- 📊 Analytics & Telemetry (CSV/JSON export for fleet tracking)

## 🤝 Contributing
 
We welcome contributions! Here's how to get started:
 
- **📖 Documentation** - Improve README clarity, add configuration examples, create troubleshooting guides
- **🐛 Bug Reports** - Open issues with detailed descriptions, system info, and log excerpts
- **💡 Feature Requests** - Open issues with `[FEATURE]` tag, describe use case and benefits
- **🔒 Security Issues** - Email [support@pnwcomputers.com](mailto:support@pnwcomputers.com) with proof of concept; allow reasonable disclosure time

## 📄 License
 
This project is licensed under the MIT License - See the [LICENSE](LICENSE.md) file for details.
 
## 📞 Support & Contact
 
- 📖 **Documentation**: Check this README and the [project wiki](docs/)
- 🐛 **Bug Reports**: Open an issue on GitHub
- 💡 **Feature Requests**: Open an issue with `[FEATURE]` tag
- 💬 **General Support**: [support@pnwcomputers.com](mailto:support@pnwcomputers.com)

---
 
## 📊 Statistics
 
![GitHub stars](https://img.shields.io/github/stars/Pnwcomputers/DeployWorkstation)
![GitHub forks](https://img.shields.io/github/forks/Pnwcomputers/DeployWorkstation)
![GitHub issues](https://img.shields.io/github/issues/Pnwcomputers/DeployWorkstation)
![GitHub license](https://img.shields.io/github/license/Pnwcomputers/DeployWorkstation)
 
**🎯 Transform your Windows deployment process from hours to minutes, and keep it current with every re-run.**
 
Built with ❤️ for efficiency, reliability, and zero-touch automation.
 
[⭐ Star this repo](https://github.com/Pnwcomputers/DeployWorkstation) if it saved you time and effort!
 
---
*Updated June 2026*
*Tested on Windows 10 (1909+) and Windows 11 - Pro & Home Editions*
