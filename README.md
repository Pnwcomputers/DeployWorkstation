# DeployWorkstation v3.0 - Modular Architecture

DeployWorkstation is a PowerShell-based, zero-touch provisioning toolkit for Windows 10 & 11 workstations. Whether you're imaging bare metal or cleaning up an existing PC, DeployWorkstation handles the heavy lifting of bloatware removal, application installations, and system configuration through a flexible, modular architecture.

## Key Features

* **Modular Design** - Built with 8 specialized PowerShell modules for maximum flexibility and maintainability
* **Self-elevating & policy-bypassing** - Automatically relaunches under Windows PowerShell 5.1 with `-ExecutionPolicy Bypass` and UAC elevation, so you can double-click the `.bat` launcher without tweaking system settings
* **Comprehensive UWP "bloatware" purge** - Removes and de-provisions built-in apps like New Outlook, Clipchamp, Family Safety, OneDrive, LinkedIn, Copilot, Teams, Skype, Xbox, and more in a single pass
* **Advanced Win32/MSI removal & DISM cleanup** - Removes legacy Windows capabilities (Quick Assist, Remote Desktop, Mixed Reality, Game Bar, etc.) via WinGet, DISM and registry operations, plus uninstalls enterprise bloatware such as McAfee by parsing UninstallStrings
* **Flexible app suites via WinGet** - Choose from Essential, Business, Developer, or Multimedia application bundles (Chrome, .NET Runtimes, Java, Adobe Reader, Zoom, 7-Zip, VLC, Visual Studio Code, Docker, and more) with parallel installation and comprehensive error logging
* **Offline fallback support** - Bundles proprietary installers (MSIs/EXEs) and runs them silently when WinGet can't reach the network or community repositories
* **Granular control options** - Skip specific phases (bloatware removal, app installation, system configuration) or run individual components as needed
* **What-If mode** - Preview all changes before execution for testing and validation
* **Enhanced logging & reporting** - Detailed logs with timestamps, error tracking, and deployment summaries

## Modular Architecture

DeployWorkstation v3.0 consists of these specialized modules:

- **DeployWorkstation.Core** - Core functionality, environment validation, and system utilities
- **DeployWorkstation.Logging** - Centralized logging system with multiple output levels
- **DeployWorkstation.WinGet** - WinGet management, source configuration, and app installation
- **DeployWorkstation.UWPCleanup** - UWP/Appx package removal and de-provisioning
- **DeployWorkstation.Win32Uninstall** - Win32 application removal via registry parsing
- **DeployWorkstation.WindowsCapabilities** - DISM-based Windows feature management
- **DeployWorkstation.SystemConfiguration** - Registry tweaks and system optimization
- **DeployWorkstation.OfflineFallback** - Offline installer support for air-gapped environments

## Usage Options

### Quick Start (Recommended)
1. **Copy** the complete DeployWorkstation folder (containing `DeployWorkstation-Modular.ps1`, all `.psm1` modules, and `DeployWorkstation-Launcher.bat`) to your USB drive or network share
2. **Double-click** `DeployWorkstation-Launcher.bat` to launch the interactive menu
3. **Choose** your deployment option:
   - Full deployment with different app suites (Essential/Business/Developer/Multimedia)
   - Selective operations (bloatware removal only, apps only, system config only)
   - Offline mode for air-gapped systems
   - What-If mode for testing
4. **Let it run** - the process is fully automated with progress reporting

### Advanced Usage (PowerShell Direct)
```powershell
# Full deployment with Business apps
.\DeployWorkstation-Modular.ps1 -AppSuite Business

# Bloatware removal only
.\DeployWorkstation-Modular.ps1 -SkipAppInstall -SkipSystemConfiguration

# Offline mode with custom log path
.\DeployWorkstation-Modular.ps1 -UseOfflineFallback -LogPath "C:\Logs\Deploy.log"

# Preview mode (no actual changes)
.\DeployWorkstation-Modular.ps1 -WhatIf -AppSuite Developer
```

### Available Parameters
- `-AppSuite` - Choose application bundle: Essential, Business, Developer, or Multimedia
- `-SkipAppInstall` - Skip application installation phase
- `-SkipBloatwareRemoval` - Skip bloatware cleanup phase
- `-SkipSystemConfiguration` - Skip system configuration phase
- `-SkipUWPCleanup` - Skip UWP/Appx package removal
- `-SkipWin32Cleanup` - Skip Win32 application removal
- `-SkipWindowsCapabilities` - Skip Windows capabilities removal
- `-UseOfflineFallback` - Use offline installers instead of WinGet
- `-WhatIf` - Preview changes without executing them
- `-LogPath` - Specify custom log file location

## Application Suites

**Essential** - Core productivity and security tools
- Web browsers, PDF readers, compression tools, media players, antivirus, system utilities

**Business** - Enterprise and office productivity
- Essential suite + Microsoft Office alternatives, remote access tools, business communication apps

**Developer** - Development and IT tools  
- Business suite + IDEs, version control, containers, development frameworks, system administration tools

**Multimedia** - Creative and media production
- Essential suite + advanced media editors, graphics tools, streaming software, creative applications

## File Structure
```
DeployWorkstation/
├── DeployWorkstation-Modular.ps1      # Main orchestration script
├── DeployWorkstation-Launcher.bat     # Interactive launcher
├── DeployWorkstation.Core.psm1        # Core utilities module
├── DeployWorkstation.Logging.psm1     # Logging module
├── DeployWorkstation.WinGet.psm1      # WinGet management module
├── DeployWorkstation.UWPCleanup.psm1  # UWP cleanup module
├── DeployWorkstation.Win32Uninstall.psm1 # Win32 removal module
├── DeployWorkstation.WindowsCapabilities.psm1 # Windows features module
├── DeployWorkstation.SystemConfiguration.psm1 # System config module
├── DeployWorkstation.OfflineFallback.psm1 # Offline support module
└── OfflineInstallers/                  # Optional offline installer directory
```

## Benefits

DeployWorkstation v3.0 transforms workstation provisioning from a complex, multi-hour manual process into a streamlined, automated operation:

- **Time Savings** - Reduce 30+ manual steps to a single automated process
- **Consistency** - Identical configuration across all deployed workstations  
- **Flexibility** - Modular design allows customization for different use cases
- **Reliability** - Comprehensive error handling and logging for troubleshooting
- **Scalability** - Deploy to single workstations or integrate into larger imaging workflows

Whether you're an IT professional managing dozens of workstations or a power user setting up a new machine, DeployWorkstation provides the automation and flexibility you need. The modular architecture makes it easy to customize, extend, and maintain for your specific requirements.

**Ready to deploy?** Download the complete package and experience zero-touch workstation provisioning!
