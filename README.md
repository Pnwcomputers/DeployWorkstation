# 🚀 DeployWorkstation - Automated Setup & Update Windows Utility

<p align="center">
  <img src="assets/deployworkstation.png" alt="A PowerShell-based, automated provisioning solution that transforms a Windows 10 or Windows 11 workstation deployment process into a single plug-and-play operation." width="600"/>
</p>

![Automation Level](https://img.shields.io/badge/Automation-Zero%20Touch-green)
![Windows Support](https://img.shields.io/badge/Windows-10%20%7C%2011-blue)
![PowerShell Version](https://img.shields.io/badge/PowerShell-5.1%2B-blue)
![Enterprise Ready](https://img.shields.io/badge/Enterprise-Ready-purple)
![GitHub issues](https://img.shields.io/github/issues/Pnwcomputers/DeployWorkstation)
![Maintenance](https://img.shields.io/badge/Maintained-Yes-green)

**Zero-Touch Windows Workstation Provisioning & Maintenance Toolkit**
 
A PowerShell-based, automated provisioning solution that transforms Windows 10 & 11 workstation deployment from a 30-step manual process into a single "plug-and-play" operation. Whether you're imaging bare metal, cleaning up an existing PC, or running routine maintenance on already-deployed machines, DeployWorkstation handles bloatware removal, essential application installation, and in-place app upgrades.
 
## 🆕 What's New in v5.2
 
- 🔄 **App Update Support** — detects and upgrades already-installed applications in-place; safe to re-run on existing machines
- 🛡️ **Winget Auto-Bootstrap** — automatically downloads and installs winget on OEM machines where it's missing or outdated
- 🔁 **Network Retry Logic** — automatic retries with delay on transient network errors during installation
- 🖥️ **Windows Edition Awareness** — detects Home vs. Pro/Enterprise and warns when policy keys will have no effect
- 🗑️ **OEM OneDrive Removal** — three-path removal covering both Appx and embedded OEM binaries
- 🌐 **Multi-Language Support** — auto-detects locale via `Get-Culture`; ships with `en-US` and `es-ES`
- ✅ **Real-time Progress** — `Write-Progress` console bars throughout all major operations
- 🐛 **Stability Fixes** — improved interactive menu logic, optimized HTML report generation, and robust winget version parsing

## ✨ Key Features
 
- **🔐 Self-Elevating & Policy-Bypassing** — automatically relaunches under Windows PowerShell 5.1 with `-ExecutionPolicy Bypass` and UAC elevation
- **🗑️ UWP "Bloatware" Purge** — comprehensive removal of built-in apps including Copilot, Teams, New Outlook, Clipchamp, OneDrive, Xbox, and more
- **⚙️ Win32/MSI Removal & DISM Cleanup** — enterprise software removal via WinGet, DISM, and registry manipulation
- **📦 Standard App Installation & Upgrade** — automated install and in-place upgrade of essential third-party tools via WinGet
- **💾 Offline Fallback Support** — bundles proprietary installers for network-independent deployment
- **📋 Centralized Logging** — detailed operation logs plus an HTML report with pause-for-review functionality

## 🛡️ Automated Removal Capabilities
 
### UWP Applications Removed
- 📧 New Outlook & Mail
- 🤖 Copilot Assistant
- 👥 Microsoft Teams (Consumer)
- 🎬 Clipchamp Video Editor
- 👨‍👩‍👧‍👦 Family Safety & Parental Controls
- ☁️ OneDrive Sync Client (Appx + OEM binary)
- 💼 LinkedIn Integration
- 📞 Skype for Windows
- 🎮 Xbox Gaming Suite
- 🎵 Groove Music
- 📰 News & Weather Apps
- 🗺️ Maps Application

### Legacy Features Disabled
- 🆘 Quick Assist Remote Support
- 🖥️ Remote Desktop Services
- 🥽 Mixed Reality Platform
- 🎮 Game Bar & Gaming Features
- 📺 Windows Media Player Legacy
- 🔍 Windows Search Indexing (Optional)

### Enterprise Software Removal
- 🛡️ McAfee Security Suite
- 🔒 Norton Antivirus
- 📺 Bloatware Media Applications
- 🎯 Manufacturer-Specific Utilities
- 📊 Trial Software & Demos

## 📥 Essential Applications Installed
 
### Security & Maintenance
- 🦠 **Malwarebytes** — premium malware protection
- 🧹 **BleachBit** — system cleanup and privacy tool
- 🔒 **Windows Defender** — enhanced configuration

### Productivity Suite
- 🌐 **Google Chrome** — modern web browser
- 🗜️ **7-Zip** — universal archive manager
- 📄 **Adobe Acrobat Reader DC** — PDF viewer
- 📹 **VLC Media Player** — universal media player
- 📝 **Notepad++** — advanced text editor

### Development Runtimes
- ⚙️ **.NET Framework 4.8** — legacy app compatibility
- ⚙️ **.NET Desktop Runtime 6 / 7 / 8** — modern app support
- 🔧 **Visual C++ 2015–2022 Redistributables** (x64 & x86)

## 🚀 Installation & Usage
 
### Prerequisites
- 💻 Windows 10/11 (Any Edition)
- 🌐 Internet Connection (for WinGet packages — winget auto-installs if missing)
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
   copy QuickStart.cmd E:\
   ```
 
3. **▶️ Execute Deployment**
   ```cmd
   # Method 1: Double-click the .cmd launcher (recommended)
   QuickStart.cmd
 
   # Method 2: Direct PowerShell execution
   powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\DeployWorkstation.ps1
   ```
 
4. **⏳ Select Deployment Mode**
   The launcher presents four options:
   | Option | Description |
   |--------|-------------|
   | **1 — Full Deployment** | Bloatware removal + app install + system config |
   | **2 — Bloatware Removal Only** | Skips app installation |
   | **3 — App Installation Only** | Skips bloatware removal |
   | **4 — System Config Only** | Registry/policy hardening only |

5. **✅ Review & Reboot**
   - Script pauses for final review on completion
   - HTML report generated: `DeployWorkstation.html`
   - Detailed log available: `DeployWorkstation.log`
   - System reboot recommended for a clean finish

### Re-Running on Existing Machines
 
v5.2 is safe to run on already-deployed workstations. The upgrade logic updates any managed apps with newer versions available via winget.
 
```powershell
# Re-run for app updates only (skip bloatware removal on a previously cleaned machine)
.\DeployWorkstation.ps1 -SkipBloatwareRemoval
 
# Dry-run to preview what would change without making any modifications
.\DeployWorkstation.ps1 -DryRun
```
 
## 🔧 Advanced Configuration
 
### Command-Line Parameters
 
| Parameter | Description |
|-----------|-------------|
| `-SkipAppInstall` | Skip all application installation |
| `-SkipBloatwareRemoval` | Skip bloatware and UWP removal |
| `-SkipDefaultUserConfig` | Skip default user profile configuration |
| `-SkipSystemConfig` | Skip registry/policy hardening |
| `-SkipJavaRuntimes` | Skip Java runtime installation |
| `-UpdateApps` | Force in-place update checks for existing applications |
| `-ExportWingetApps` | Export currently installed winget apps to `apps.json` |
| `-ImportWingetApps` | Import and install apps from `apps.json` |
| `-DryRun` | Simulate all actions without making changes |
| `-LogPath <path>` | Custom path for the log file |
 
### Custom Application Lists
 
```powershell
# Core Applications (Always Installed)
$CoreApps = @(
    "Google.Chrome",
    "7zip.7zip",
    "VideoLAN.VLC",
    "Malwarebytes.Malwarebytes"
)
 
# Optional Applications (User Selectable)
$OptionalApps = @(
    "Microsoft.VisualStudioCode",
    "Git.Git",
    "Docker.DockerDesktop"
)
```
 
### Offline Package Management
```powershell
$OfflinePackages = @{
    "CustomApp1" = "\\NetworkShare\Software\App1.msi"
    "CustomApp2" = "E:\Installers\App2.exe /S"
}
```
 
### Logging Configuration
```powershell
$LogLevel = "Detailed"   # Options: Basic, Detailed, Verbose
$LogRetention = 30       # Days to keep logs
```
 
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
| **Offline Support** | ✅ Media required | ❌ Internet dependent | ✅ Hybrid approach |
| **Error Handling** | ❌ Manual intervention | ⚠️ Basic logging | ✅ Retry logic + HTML report |
| **Customization** | ✅ Full control | ⚠️ Limited options | ✅ Highly configurable |
 
## 📈 Performance Metrics
 
| Metric | Traditional Method | DeployWorkstation |
|--------|-------------------|-------------------|
| **Total Time** | 4-8 hours | 30-45 minutes |
| **Manual Steps** | 30+ operations | 1 double-click |
| **Error Rate** | ~15% (human error) | <2% (automated) |
| **Consistency** | Variable | 100% standardized |
| **Scalability** | Linear time increase | Parallel deployment |
 
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
- Maintenance contract fulfillment — re-run to keep apps current

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

**Offline installers not found**
- Verify installer paths in script
- Check file permissions on USB drive
- Ensure installers support silent installation

### Log Analysis
```powershell
# Check for errors and warnings in the deployment log
Get-Content .\DeployWorkstation.log | Select-String "ERROR|WARNING"
 
# Verify WinGet package status
winget list --source winget
```
 
The HTML report (`DeployWorkstation.html`) provides the same information in a readable format — open it in any browser after the run completes.
 
## 🛠️ Project Structure
 
```text
DeployWorkstation/
├── DeployWorkstation.ps1      # Main PowerShell script
├── QuickStart.cmd             # Self-elevating launcher with menu
├── Installers/                # Offline installer directory
│   ├── CustomApp1.msi
│   └── CustomApp2.exe
├── Logs/                      # Auto-created log directory
│   ├── DeployWorkstation.log
│   └── DeployWorkstation.html # Post-run HTML report
├── Config/                    # Configuration files
│   ├── AppLists.json
│   └── Settings.xml
└── README.md
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
 
- **📖 Documentation** — improve README clarity, add configuration examples, create troubleshooting guides
- **🐛 Bug Reports** — open issues with detailed descriptions, system info, and log excerpts
- **💡 Feature Requests** — open issues with `[FEATURE]` tag, describe use case and benefits
- **🔒 Security Issues** — email [support@pnwcomputers.com](mailto:support@pnwcomputers.com) with proof of concept; allow reasonable disclosure time

## 📄 License
 
This project is licensed under the MIT License — see the [LICENSE](LICENSE.md) file for details.
 
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
 
**🎯 Transform your Windows deployment process from hours to minutes — and keep it current with every re-run.**
 
Built with ❤️ for efficiency, reliability, and zero-touch automation.
 
[⭐ Star this repo](https://github.com/Pnwcomputers/DeployWorkstation) if it saved you time and effort!
 
---
*Updated June 2026*
*Tested on Windows 10 (1909+) and Windows 11 — Enterprise, Pro, and Home Editions*
