# DeployWorkstation v2.0 (Testing)

*This is a testing edition of the Version 2 I hope to release; which will allow this process to be compeleted for any/all user accounts on a Windows system.

DeployWorkstation is a PowerShell-based, zero-touch provisioning toolkit proof of concept for Windows 10 & 11 workstations. 
Whether you’re imaging bare metal or cleaning up an existing PC, DeployWorkstation handles the heavy lifting of standard software and Apps removal, as well as basic application installations.
DeployWorkstation turns what used to be a 30-60 minute manual process into a single “plug-and-play” operation, saving you valuable time on every workstation you configure. Feel free to fork, tweak the app list/script, and contribute back!  

- **Self-elevating & policy-bypassing**  
  Automatically relaunches under Windows PowerShell 5.1 with `-ExecutionPolicy Bypass` and UAC elevation, so you can double-click or run a single .cmd wrapper without tweaking system settings.

- **UWP “bloatware” purge**  
  In one Desktop-PowerShell pass it uninstalls and de-provisions built-in apps like New Outlook, Clipchamp, Family Safety, OneDrive, LinkedIn, Copilot, Teams, Skype, Xbox, and more.

- **Win32/Msi removal & DISM cleanup**  
  Removes legacy features (Quick Assist, Remote Desktop, Mixed Reality, Game Bar, etc.) via WinGet, DISM and registry, and uninstalls enterprise software such as McAfee by parsing their UninstallStrings from the registry.

- **Standard app install via WinGet**  
  Installs your golden image of third-party tools (Malwarebytes, BleachBit, Chrome, .NET Runtimes, Java, Adobe Reader, Zoom, 7-Zip, VLC, etc.) in parallel or sequentially, with silent-install flags and built-in error logging.

- **Offline fallback support**  
  Bundles proprietary installers (MSIs/EXEs) on USB and runs them silently if Winget can’t reach the network or community feed.

- **Centralized logging & pause-for-review**  
  Writes a detailed `DeployWorkstation.log` in its script folder and pauses at the end so you can inspect any errors or warnings before rebooting.

## Usage
1. **Copy** the `DeployWorkstation.ps1` and its `.cmd` launcher onto your USB or network share.  
2. **Double-click** the `.cmd` (or run `powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\DeployWorkstation.ps1`) to start.  
3. **Let it run** unattended!
4. When it finishes, it will pause for review and reboot for a clean, ready-to-use machine.

# With parameters
.\DeployWorkstation-AllUsers.ps1 -SkipAppInstall -LogPath "C:\Logs\deploy.log"

# Skip certain sections
.\DeployWorkstation-AllUsers.ps1 -SkipBloatwareRemoval -SkipDefaultUserConfig


# Apps Removed by DeployWorkstation.ps1
This lists all o the applications, packages, and services that are automatically removed or disabled by the script to create a cleaner, more secure Windows environment.

## 🗑️ Winget Applications Removed
The script searches for and removes applications matching these patterns:

| Application Pattern | Description |
|-------------------|-------------|
| **CoPilot** | Microsoft Copilot AI assistant |
| **Outlook** | Microsoft Outlook (new version) |
| **Quick Assist** | Windows remote assistance tool |
| **Remote Desktop** | Microsoft Remote Desktop client |
| **Mixed Reality Portal** | Windows Mixed Reality applications |
| **Clipchamp** | Microsoft video editing software |
| **Xbox** | Xbox gaming applications and services |
| **Family** | Microsoft Family Safety apps |
| **Skype** | Skype communication software |
| **LinkedIn** | LinkedIn social networking app |
| **OneDrive** | Microsoft cloud storage client |
| **Teams** | Microsoft Teams collaboration software |
| **Disney** | Disney+ streaming app |
| **Netflix** | Netflix streaming app |
| **Spotify** | Spotify music streaming app |
| **TikTok** | TikTok social media app |
| **Instagram** | Instagram social media app |
| **Facebook** | Facebook social media app |
| **Candy** | Candy Crush and similar games |
| **Twitter** | Twitter/X social media app |
| **Minecraft** | Minecraft gaming apps |

## 📦 UWP/AppX Packages Removed
These Windows Store apps are removed for **all users** (current and future):

### Microsoft Applications
- `Microsoft.OutlookForWindows` - New Outlook client
- `Clipchamp` - Video editing software
- `MicrosoftFamily` - Family Safety features
- `OneDrive` - Cloud storage integration
- `LinkedIn` - Professional networking
- `Skype` - Communication platform
- `MixedReality` - Mixed Reality Portal
- `RemoteDesktop` - Remote Desktop client
- `QuickAssist` - Remote assistance tool
- `MicrosoftTeams` - Collaboration platform

### Gaming Applications
- `Xbox*` - All Xbox-related apps and services
- `Minecraft*` - Minecraft gaming apps

### Entertainment & Social Media
- `Disney*` - Disney+ streaming service
- `Netflix*` - Netflix streaming service  
- `Spotify*` - Music streaming service
- `TikTok*` - Short-form video platform
- `Instagram*` - Photo sharing platform
- `Facebook*` - Social networking platform
- `Twitter*` - Microblogging platform
- `Candy*` - Casual gaming apps (Candy Crush, etc.)

## 🔧 Windows Capabilities Removed
These optional Windows features are uninstalled:

| Capability | Description |
|-----------|-------------|
| `App.Support.QuickAssist~~~~0.0.1.0` | Quick Assist remote help |
| `App.Xbox.TCUI~~~~0.0.1.0` | Xbox Game Bar UI |
| `App.XboxGameOverlay~~~~0.0.1.0` | Xbox Game Overlay |
| `App.XboxSpeechToTextOverlay~~~~0.0.1.0` | Xbox Speech-to-Text |
| `OpenSSH.Client~~~~0.0.1.0` | OpenSSH Client |
| `Microsoft.Windows.PowerShell.ISE~~~~0.0.1.0` | PowerShell ISE |

## 🛡️ Security Software Removed
The script specifically targets and removes McAfee products:

- **All McAfee products** found in the system's uninstall registry
- Includes McAfee antivirus, security suites, and related components
- Uses silent uninstall parameters for automated removal

## ⚙️ Services Disabled
These Windows services are stopped and disabled:

| Service Name | Display Name | Purpose |
|-------------|-------------|---------|
| `DiagTrack` | Connected User Experiences and Telemetry | Data collection |
| `dmwappushservice` | WAP Push Message Routing Service | Mobile messaging |
| `lfsvc` | Geolocation Service | Location tracking |
| `MapsBroker` | Downloaded Maps Manager | Offline maps |
| `NetTcpPortSharing` | Net.Tcp Port Sharing Service | Network sharing |
| `RemoteAccess` | Routing and Remote Access | Remote connectivity |
| `RemoteRegistry` | Remote Registry | Remote registry access |
| `SharedAccess` | Internet Connection Sharing | Network sharing |
| `TrkWks` | Distributed Link Tracking Client | File tracking |
| `WbioSrvc` | Windows Biometric Service | Fingerprint/face recognition |
| `WMPNetworkSvc` | Windows Media Player Network Sharing | Media streaming |
| `XblAuthManager` | Xbox Live Auth Manager | Xbox authentication |
| `XblGameSave` | Xbox Live Game Save Service | Xbox cloud saves |
| `XboxNetApiSvc` | Xbox Live Networking Service | Xbox networking |

## 🚫 Registry Settings Disabled

### System-Wide Policies (All Users)
- Windows Consumer Features
- Windows Spotlight Features
- Tailored Experiences with Diagnostic Data
- Windows Telemetry and Data Collection
- Windows Error Reporting
- Customer Experience Improvement Program
- Advertising ID
- OneDrive File Sync

### User-Specific Settings (Per Profile)
- OneDrive startup entries
- Windows tips and suggestions
- Content delivery manager features
- Rotating lock screen
- Subscribed content notifications

### Default User Profile (Future Users)
- Consumer features and suggestions
- Privacy settings
- Content delivery settings
- All promotional content

# Apps Installed by DeployWorkstation.ps1
This lists all of the applications that are automatically installed by the script to provide essential functionality for a Windows workstation.

## 📦 Standard Applications Installed

The script installs these essential applications via Winget:

### 🛡️ Security & Maintenance
| Application | Winget ID | Description | Purpose |
|-------------|-----------|-------------|---------|
| **Malwarebytes** | `Malwarebytes.Malwarebytes` | Anti-malware protection | Real-time malware detection and removal |
| **BleachBit** | `BleachBit.BleachBit` | System cleaner | Disk cleanup and privacy protection |

### 🌐 Web Browsers
| Application | Winget ID | Description | Purpose |
|-------------|-----------|-------------|---------|
| **Google Chrome** | `Google.Chrome` | Web browser | Primary internet browsing |

### 🔧 Development & Runtime
| Application | Winget ID | Description | Purpose |
|-------------|-----------|-------------|---------|
| **.NET 7 Desktop Runtime** | `Microsoft.DotNet.DesktopRuntime.7` | Application framework | Required for .NET applications |
| **Java Runtime Environment** | `Oracle.JavaRuntimeEnvironment` | Java runtime | Required for Java applications |

### 📄 Document & Media Tools
| Application | Winget ID | Description | Purpose |
|-------------|-----------|-------------|---------|
| **Adobe Acrobat Reader** | `Adobe.Acrobat.Reader.64-bit` | PDF viewer | Reading and viewing PDF documents |
| **VLC Media Player** | `VideoLAN.VLC` | Media player | Playing various audio/video formats |

### 💼 Business & Productivity
| Application | Winget ID | Description | Purpose |
|-------------|-----------|-------------|---------|
| **Zoom** | `Zoom.Zoom` | Video conferencing | Online meetings and webinars |

### 🗜️ Utilities
| Application | Winget ID | Description | Purpose |
|-------------|-----------|-------------|---------|
| **7-Zip** | `7zip.7zip` | File archiver | Compression and extraction of archives |

## 📊 Installation Statistics

The script tracks installation success and provides a summary:
- **Total Applications**: 9
- **Success Rate**: Logged per application
- **Installation Method**: Silent installation via Winget
- **Source**: Official Winget repository

## ⚙️ Installation Features

### 🔄 Automated Installation
- **Silent Installation**: All apps install without user prompts
- **Source Verification**: Uses official Winget repository
- **Agreement Acceptance**: Automatically accepts package and source agreements
- **Error Handling**: Continues installation even if individual apps fail
- **Logging**: Detailed logging of each installation attempt

### 📋 Prerequisites
- **Winget Required**: Script verifies Winget availability before proceeding
- **Admin Rights**: Requires administrator privileges for installation
- **Internet Connection**: Required for downloading packages
- **Windows Version**: Compatible with Windows 10/11

## 🎯 Rationale for Selected Applications

### Security First
- **Malwarebytes**: Industry-leading anti-malware protection
- **BleachBit**: Removes traces and cleans system for privacy

### Essential Productivity
- **Google Chrome**: Most widely used web browser with extensive extension support
- **Adobe Reader**: Industry standard for PDF viewing
- **7-Zip**: Free, powerful archive tool supporting many formats

### Runtime Support
- **.NET 7 Runtime**: Required for many modern Windows applications
- **Java Runtime**: Needed for Java-based applications and web content

### Communication & Media
- **Zoom**: Essential for remote work and video conferencing
- **VLC**: Versatile media player supporting virtually all formats

## 🛠️ Customization Options

### Adding Applications
To add more applications to the installation list, modify the `$appsToInstall` array in the script:

```powershell
$appsToInstall = @(
    # Existing apps...
    @{ Id = 'Publisher.AppName'; Name = 'Display Name' }
)
```

### Skipping Installation
Use the `-SkipAppInstall` parameter to skip all application installations:
```powershell
.\DeployWorkstation-AllUsers.ps1 -SkipAppInstall
```

### Finding Winget IDs
Search for applications using Winget:
```powershell
winget search "application name"
```

## 🔍 Installation Verification
After script completion, verify installations:

### Via PowerShell
```powershell
# Check installed programs
Get-WmiObject -Class Win32_Product | Where-Object {$_.Name -like "*AppName*"}

# Check via Winget
winget list
```

### Via GUI
- Check Windows "Add or Remove Programs"
- Look for applications in Start Menu
- Verify desktop shortcuts (if created)

## 🚫 Installation Failures
Common reasons for installation failures:
- **Network Issues**: Slow or unstable internet connection
- **Antivirus Blocking**: Security software preventing downloads
- **Insufficient Space**: Not enough disk space available
- **Permission Issues**: Lack of administrator privileges
- **Package Conflicts**: Existing installations interfering
- **Corporate Policies**: Group policies blocking installations

## 📈 Success Optimization
For best installation success rates:
1. **Run as Administrator**: Always use elevated privileges
2. **Disable Antivirus**: Temporarily disable real-time protection
3. **Stable Connection**: Ensure reliable internet connectivity
4. **Clean System**: Run on freshly installed Windows when possible
5. **Check Logs**: Review installation logs for troubleshooting

## ⚠️ Important Notes
1. **Irreversible Changes**: Many of these removals require Windows reinstallation or manual restoration to undo.
2. **Future Users**: Settings applied to the default user profile affect all newly created user accounts.
3. **Provisioned Packages**: Removing provisioned packages prevents automatic installation for new users.
4. **Enterprise Considerations**: Some disabled services may be required in enterprise environments.
5. **Gaming Impact**: Xbox-related removals will affect Windows gaming features and Game Bar functionality.

## 🔄 Restoration
To restore removed functionality:
- **UWP Apps**: Reinstall from Microsoft Store
- **Windows Features**: Re-enable via "Turn Windows features on or off"
- **Services**: Re-enable via `services.msc`
- **Registry Settings**: Manual registry editing required
- **McAfee**: Download and reinstall from McAfee website

---

**Last Updated**: June 2025  
**Script Version**: 2.1
