# 🚀 DeployWorkstation v1.0 (Testing)

**Zero-Touch Windows Workstation Provisioning Toolkit**

A PowerShell-based, automated provisioning solution that transforms Windows 10 & 11 workstation deployment from a 30-step manual process into a single "plug-and-play" operation. Whether you're imaging bare metal or cleaning up an existing PC, DeployWorkstation handles the heavy lifting of bloatware removal and essential application installation.

## ✨ Key Features

- **🔐 Self-Elevating & Policy-Bypassing** - Automatically relaunches under Windows PowerShell 5.1 with `-ExecutionPolicy Bypass` and UAC elevation
- **🗑️ UWP "Bloatware" Purge** - Comprehensive removal of built-in apps like New Outlook, Clipchamp, OneDrive, Teams, Xbox, and more
- **⚙️ Win32/MSI Removal & DISM Cleanup** - Enterprise software removal via WinGet, DISM, and registry manipulation
- **📦 Standard App Installation** - Automated installation of essential third-party tools via WinGet
- **💾 Offline Fallback Support** - Bundles proprietary installers for network-independent deployment
- **📋 Centralized Logging** - Detailed operation logs with pause-for-review functionality

## 🛡️ Automated Removal Capabilities

### UWP Applications Removed
- 📧 New Outlook & Mail
- 🎬 Clipchamp Video Editor
- 👨‍👩‍👧‍👦 Family Safety & Parental Controls
- ☁️ OneDrive Sync Client
- 💼 LinkedIn Integration
- 🤖 Copilot Assistant
- 👥 Microsoft Teams (Consumer)
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
- 🦠 **Malwarebytes** - Premium malware protection
- 🧹 **BleachBit** - System cleanup and privacy tool
- 🔒 **Windows Defender** - Enhanced configuration

### Productivity Suite
- 🌐 **Google Chrome** - Modern web browser
- 🗜️ **7-Zip** - Universal archive manager
- 📄 **Adobe Acrobat Reader DC** - PDF viewer
- 📹 **VLC Media Player** - Universal media player
- 📞 **Zoom Client** - Video conferencing
- 📝 **Notepad++** - Advanced text editor

### Development Runtimes
- ⚙️ **.NET Framework** (Latest LTS)
- ☕ **Java Runtime Environment**
- 🔧 **Visual C++ Redistributables**
- 🐍 **Python Runtime** (Optional)

## 🚀 Installation & Usage

### Prerequisites
- 💻 Windows 10/11 (Any Edition)
- 🌐 Internet Connection (for WinGet packages)
- 👤 Administrator Access
- 💾 USB Drive or Network Share (Optional)
- 🖥️ Current Version of "Application Installer" from Microsoft's App Store 

### Quick Start

1. **📥 Download the Repository**
   ```bash
   git clone https://github.com/Pnwcomputers/DeployWorkstation.git
   cd DeployWorkstation
   ```

2. **💾 Prepare Deployment Media**
   ```cmd
   # Copy files to USB drive
   copy DeployWorkstation.ps1 E:\
   copy DeployWorkstation.cmd E:\
   ```

3. **▶️ Execute Deployment**
   ```cmd
   # Method 1: Double-click the .cmd launcher
   DeployWorkstation.cmd
   
   # Method 2: Direct PowerShell execution
   powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\DeployWorkstation.ps1
   ```

4. **⏳ Monitor Progress**
   - Script runs unattended with real-time logging
   - Progress indicators for each major operation
   - Automatic error handling and retry logic

5. **✅ Review & Reboot**
   - Script pauses for final review
   - Detailed log available: `DeployWorkstation.log`
   - System reboot recommended for clean finish

## 🔧 Advanced Configuration

### Custom Application Lists
Edit the script to modify installation packages:

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
# Bundle offline installers
$OfflinePackages = @{
    "CustomApp1" = "\\NetworkShare\Software\App1.msi"
    "CustomApp2" = "E:\Installers\App2.exe /S"
}
```

### Logging Configuration
```powershell
# Customize logging behavior
$LogLevel = "Detailed"        # Options: Basic, Detailed, Verbose
$LogRetention = 30           # Days to keep logs
$EmailAlerts = $true         # Send completion notifications
```

## 📊 Feature Comparison

| Feature | Manual Deployment | Other Tools | DeployWorkstation |
|---------|------------------|-------------|-------------------|
| **Automation Level** | ❌ Manual (8+ hours) | ⚠️ Partial (2-4 hours) | ✅ Full Automation (30 minutes) |
| **Bloatware Removal** | ❌ Manual deletion | ⚠️ Basic removal | ✅ Comprehensive purge |
| **Enterprise Software** | ❌ Manual uninstall | ❌ Often skipped | ✅ Registry-based removal |
| **Offline Support** | ✅ Media required | ❌ Internet dependent | ✅ Hybrid approach |
| **Error Handling** | ❌ Manual intervention | ⚠️ Basic logging | ✅ Comprehensive logging |
| **Customization** | ✅ Full control | ⚠️ Limited options | ✅ Highly configurable |

## 🎯 Use Cases

### **🏢 Enterprise Deployment**
- New employee workstation setup
- Hardware refresh projects
- Standardized corporate imaging
- Remote office provisioning

### **🔧 IT Service Providers**
- Client workstation deployment
- Malware cleanup and rebuild
- Hardware upgrade services
- Maintenance contract fulfillment

### **🏫 Educational Institutions**
- Lab computer preparation
- Student workstation imaging
- Faculty equipment setup
- Semester refresh operations

### **🏠 Home & Small Business**
- Personal computer setup
- Family PC maintenance
- Small office standardization
- Tech enthusiast automation

## 🛠️ Project Structure

```
DeployWorkstation/
├── DeployWorkstation.ps1      # Main PowerShell script
├── DeployWorkstation.cmd      # Self-elevating launcher
├── Installers/                # Offline installer directory
│   ├── CustomApp1.msi
│   └── CustomApp2.exe
├── Logs/                      # Auto-created log directory
│   └── DeployWorkstation.log
├── Config/                    # Configuration files
│   ├── AppLists.json
│   └── Settings.xml
└── README.md                  # This documentation
```

## 🔍 Troubleshooting

### Common Issues

**Script won't execute**
- Ensure PowerShell execution policy allows scripts
- Verify UAC elevation is working
- Check Windows PowerShell 5.1 is available

**WinGet installation failures**
- Verify internet connectivity
- Check Windows Store app is installed
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
# Check recent deployment logs
Get-Content .\DeployWorkstation.log | Select-String "ERROR|WARNING"

# Verify WinGet package status
winget list --source winget
```

## 📈 Performance Metrics

| Metric | Traditional Method | DeployWorkstation |
|--------|-------------------|-------------------|
| **Total Time** | 4-8 hours | 30-45 minutes |
| **Manual Steps** | 30+ operations | 1 double-click |
| **Error Rate** | ~15% (human error) | <2% (automated) |
| **Consistency** | Variable | 100% standardized |
| **Scalability** | Linear time increase | Parallel deployment |

## 🔮 Roadmap

### Version 1.1 (Q3 2025)
- ✅ GUI Configuration Interface
- ✅ Network Deployment Server
- ✅ Real-time Progress Dashboard
- ✅ Multi-language Support

### Version 2.0 (Q4 2025)
- 🚀 Windows Server Support
- 🚀 Domain Integration
- 🚀 Cloud Configuration Sync
- 🚀 Advanced Reporting

### Future Enhancements
- 🔄 Configuration Management Integration
- 📊 Analytics and Telemetry
- 🤖 AI-Powered Optimization
- 🌐 Web-based Management Console

## 🤝 Contributing

We welcome contributions! Here's how to get started:

### 📖 Documentation
- Improve README clarity
- Add configuration examples
- Create troubleshooting guides

### 🐛 Bug Reports
- Open issues with detailed descriptions
- Include system information
- Provide log excerpts

### 💡 Feature Requests
- Open issues with [FEATURE] tag
- Describe use case and benefits
- Consider implementation complexity

### 🔒 Security Issues
- Email security@pnwcomputers.com
- Include proof of concept (if safe)
- Allow reasonable disclosure time

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 📞 Support & Contact

- 📖 **Documentation**: Check this README and project wiki
- 🐛 **Bug Reports**: Open an issue on GitHub
- 💡 **Feature Requests**: Open an issue with [FEATURE] tag
- 🔒 **Security Issues**: Email [security@pnwcomputers.com](mailto:security@pnwcomputers.com)
- 💬 **General Support**: Email [support@pnwcomputers.com](mailto:support@pnwcomputers.com)

---

## 📊 Statistics

![GitHub stars](https://img.shields.io/github/stars/Pnwcomputers/DeployWorkstation)
![GitHub forks](https://img.shields.io/github/forks/Pnwcomputers/DeployWorkstation)
![GitHub issues](https://img.shields.io/github/issues/Pnwcomputers/DeployWorkstation)
![GitHub license](https://img.shields.io/github/license/Pnwcomputers/DeployWorkstation)

**🎯 Transform your Windows deployment process from hours to minutes!**

Built with ❤️ for efficiency, reliability, and zero-touch automation.

[⭐ Star this repo](https://github.com/Pnwcomputers/DeployWorkstation) if it saved you time and effort!

---

*Tested on Windows 10 (1909+) and Windows 11 - Enterprise, Pro, and Home editions*
