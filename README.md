# DeployWorkstation v2.2 (Comprehensive Runtime Support)

DeployWorkstation is a PowerShell-based, zero-touch provisioning toolkit for Windows 10 & 11 workstations. 
Whether you're imaging bare metal or cleaning up an existing PC, DeployWorkstation handles the heavy lifting of bloatware removal and comprehensive application/runtime installations.
DeployWorkstation turns what used to be a 30-60 minute manual process into a single "plug-and-play" operation, saving you valuable time on every workstation you configure. Feel free to fork, tweak the app list/script, and contribute back!  

- **Self-elevating & policy-bypassing**  
  Automatically relaunches under Windows PowerShell 5.1 with `-ExecutionPolicy Bypass` and UAC elevation, so you can double-click or run a single .cmd wrapper without tweaking system settings.

- **UWP "bloatware" purge**  
  In one Desktop-PowerShell pass it uninstalls and de-provisions built-in apps like New Outlook, Clipchamp, Family Safety, OneDrive, LinkedIn, Copilot, Teams, Skype, Xbox, and more.

- **Win32/MSI removal & DISM cleanup**  
  Removes legacy features (Quick Assist, Remote Desktop, Mixed Reality, Game Bar, etc.) via WinGet, DISM and registry, and uninstalls enterprise software such as McAfee by parsing their UninstallStrings from the registry.

- **Comprehensive runtime library installation**  
  Installs complete runtime coverage including .NET Framework/Desktop Runtimes, Visual C++ Redistributables (2005-2015+), and Java JRE/JDK packages to ensure maximum application compatibility.

- **Standard app install via WinGet**  
  Installs your golden image of third-party tools (Malwarebytes, BleachBit, Chrome, Adobe Reader, Zoom, 7-Zip, VLC, etc.) with silent-install flags and built-in error logging.

- **Enhanced error handling & logging**  
  Comprehensive try-catch blocks, return value validation, and detailed logging with severity levels (INFO, WARN, ERROR, DEBUG) for better troubleshooting.

- **Flexible deployment options**  
  New parameters for app export/import, selective Java installation, and granular control over deployment phases.

- **Centralized logging & graceful degradation**  
  Writes a detailed `DeployWorkstation-AllUsers.log` in its script folder and accepts 80% success rate for realistic deployment scenarios.

## Usage
1. **Copy** the `DeployWorkstation-AllUsers.ps1` and its `.cmd` launcher onto your USB or network share.  
2. **Double-click** the `.cmd` (or run `powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\DeployWorkstation-AllUsers.ps1`) to start.  
3. **Let it run** unattended!
4. When it finishes, it will pause for review and display completion status.

### Command Line Parameters

```powershell
# Basic usage
.\DeployWorkstation-AllUsers.ps1

# With parameters
.\DeployWorkstation-AllUsers.ps1 -SkipAppInstall -LogPath "C:\Logs\deploy.log"

# Skip certain sections
.\DeployWorkstation-AllUsers.ps1 -SkipBloatwareRemoval -SkipDefaultUserConfig

# Skip Java runtime installations (reduces install time)
.\DeployWorkstation-AllUsers.ps1 -SkipJavaRuntimes

# Export current winget apps to apps.json
.\DeployWorkstation-AllUsers.ps1 -ExportWingetApps

# Import apps from apps.json
.\DeployWorkstation-AllUsers.ps1 -ImportWingetApps
```

### Available Parameters
- `-LogPath` - Custom log file location
- `-SkipAppInstall` - Skip all application installations
- `-SkipBloatwareRemoval` - Skip bloatware removal process
- `-SkipDefaultUserConfig` - Skip default user profile configuration
- `-SkipJavaRuntimes` - Skip Java JRE/JDK installations
- `-ExportWingetApps` - Export installed apps to apps.json
- `-ImportWingetApps` - Import apps from apps.json

# Apps Removed by DeployWorkstation.ps1
This lists all of the applications, packages, and services that are automatically removed or disabled by the script to create a cleaner, more secure Windows environment.

## Winget Applications Removed
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

## UWP/AppX Packages Removed
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

## Windows Capabilities Removed
These optional Windows features are uninstalled:

| Capability | Description |
|-----------|-------------|
| `App.Support.QuickAssist~~~~0.0.1.0` | Quick Assist remote help |
| `App.Xbox.TCUI~~~~0.0.1.0` | Xbox Game Bar UI |
| `App.XboxGameOverlay~~~~0.0.1.0` | Xbox Game Overlay |
| `App.XboxSpeechToTextOverlay~~~~0.0.1.0` | Xbox Speech-to-Text |
| `OpenSSH.Client~~~~0.0.1.0` | OpenSSH Client |
| `Microsoft.Windows.PowerShell.ISE~~~~0.0.1.0` | PowerShell ISE |

## Security Software Removed
The script specifically targets and removes McAfee products:

- **All McAfee products** found in the system's uninstall registry
- Includes McAfee antivirus, security suites, and related components
- Uses silent uninstall parameters for automated removal

## Services Disabled
These Windows services are stopped and disabled:

| Service Name | Display Name | Purpose |
|-------------|-------------|---------|
| `DiagTrack` | Connected User Experiences and Telemetry | Data collection |
| `dmwappushservice` | WAP Push Message Routing Service | Mobile messaging |
| `lfsvc` | Geolocation Service | Location tracking |
| `MapsBroker` | Downloaded Maps Manager | Offline maps |
| `XblAuthManager` | Xbox Live Auth Manager | Xbox authentication |
| `XblGameSave` | Xbox Live Game Save Service | Xbox cloud saves |
| `XboxNetApiSvc` | Xbox Live Networking Service | Xbox networking |

## Registry Settings Disabled

### System-Wide Policies (All Users)
- Windows Consumer Features
- Windows Spotlight Features
- Tailored Experiences with Diagnostic Data
- Windows Telemetry (set to basic level for security updates)
- Windows Error Reporting
- Customer Experience Improvement Program
- Advertising ID
- OneDrive File Sync

### User-Specific Settings (Per Profile)
- OneDrive startup entries
- Windows tips and suggestions
- Content delivery manager features
- Privacy settings

### Default User Profile (Future Users)
- Consumer features and suggestions
- Privacy settings
- Content delivery settings
- All promotional content

# Apps Installed by DeployWorkstation.ps1
This lists all of the applications and runtime libraries that are automatically installed by the script to provide comprehensive functionality for a Windows workstation.

## Standard Applications Installed

### Security & Maintenance
| Application | Winget ID | Description | Purpose |
|-------------|-----------|-------------|---------|
| **Malwarebytes** | `Malwarebytes.Malwarebytes` | Anti-malware protection | Real-time malware detection and removal |
| **BleachBit** | `BleachBit.BleachBit` | System cleaner | Disk cleanup and privacy protection |

### Web Browsers
| Application | Winget ID | Description | Purpose |
|-------------|-----------|-------------|---------|
| **Google Chrome** | `Google.Chrome` | Web browser | Primary internet browsing |

### Document & Media Tools
| Application | Winget ID | Description | Purpose |
|-------------|-----------|-------------|---------|
| **Adobe Acrobat Reader** | `Adobe.Acrobat.Reader.64-bit` | PDF viewer | Reading and viewing PDF documents |
| **VLC Media Player** | `VideoLAN.VLC` | Media player | Playing various audio/video formats |

### Business & Productivity
| Application | Winget ID | Description | Purpose |
|-------------|-----------|-------------|---------|
| **Zoom** | `Zoom.Zoom` | Video conferencing | Online meetings and webinars |

### Utilities
| Application | Winget ID | Description | Purpose |
|-------------|-----------|-------------|---------|
| **7-Zip** | `7zip.7zip` | File archiver | Compression and extraction of archives |

## Comprehensive Runtime Libraries

### .NET Framework & Desktop Runtimes
| Runtime | Winget ID | Description | Compatibility |
|---------|-----------|-------------|---------------|
| **.NET Framework 4.8.1** | `Microsoft.DotNet.Framework.4.8.1` | Latest .NET Framework | Legacy Windows applications |
| **.NET Desktop Runtime 8** | `Microsoft.DotNet.DesktopRuntime.8` | .NET 8 Desktop apps | Modern Windows applications |
| **.NET Desktop Runtime 9** | `Microsoft.DotNet.DesktopRuntime.9` | .NET 9 Desktop apps | Latest Windows applications |

### Visual C++ Redistributables (Complete Coverage)
| Version | Architecture | Winget ID | Description |
|---------|-------------|-----------|-------------|
| **2015+** | x64 | `Microsoft.VCRedist.2015+.x64` | Latest VC++ libraries (recommended) |
| **2015+** | x86 | `Microsoft.VCRedist.2015+.x86` | Latest VC++ libraries (32-bit) |
| **2013** | x64 | `Microsoft.VCRedist.2013.x64` | Visual Studio 2013 libraries |
| **2013** | x86 | `Microsoft.VCRedist.2013.x86` | Visual Studio 2013 libraries (32-bit) |
| **2012** | x64 | `Microsoft.VCRedist.2012.x64` | Visual Studio 2012 libraries |
| **2012** | x86 | `Microsoft.VCRedist.2012.x86` | Visual Studio 2012 libraries (32-bit) |
| **2010** | x64 | `Microsoft.VCRedist.2010.x64` | Visual Studio 2010 libraries |
| **2010** | x86 | `Microsoft.VCRedist.2010.x86` | Visual Studio 2010 libraries (32-bit) |
| **2008** | x64 | `Microsoft.VCRedist.2008.x64` | Visual Studio 2008 libraries |
| **2008** | x86 | `Microsoft.VCRedist.2008.x86` | Visual Studio 2008 libraries (32-bit) |
| **2005** | x64 | `Microsoft.VCRedist.2005.x64` | Visual Studio 2005 libraries |
| **2005** | x86 | `Microsoft.VCRedist.2005.x86` | Visual Studio 2005 libraries (32-bit) |

### Java Runtime & Development Kits (Optional)
| Type | Version | Winget ID | Description |
|------|---------|-----------|-------------|
| **JRE** | 8 | `Eclipse.Temurin.8.JRE` | Java Runtime Environment 8 |
| **JRE** | 11 | `Eclipse.Temurin.11.JRE` | Java Runtime Environment 11 LTS |
| **JRE** | 17 | `Eclipse.Temurin.17.JRE` | Java Runtime Environment 17 LTS |
| **JRE** | 21 | `Eclipse.Temurin.21.JRE` | Java Runtime Environment 21 LTS |
| **JDK** | 8 | `Eclipse.Temurin.8.JDK` | Java Development Kit 8 |
| **JDK** | 11 | `Eclipse.Temurin.11.JDK` | Java Development Kit 11 LTS |
| **JDK** | 17 | `Eclipse.Temurin.17.JDK` | Java Development Kit 17 LTS |
| **JDK** | 21 | `Eclipse.Temurin.21.JDK` | Java Development Kit 21 LTS |

*Note: Java installations can be skipped using the `-SkipJavaRuntimes` parameter*

## Installation Statistics

### Package Count by Category
- **Core Applications**: 7 packages
- **.NET Frameworks/Runtimes**: 3 packages  
- **Visual C++ Redistributables**: 12 packages
- **Java JRE Packages**: 4 packages (optional)
- **Java JDK Packages**: 4 packages (optional)
- **Total Packages**: Up to 30 packages

### Installation Features
- **Silent Installation**: All apps install without user prompts
- **Source Verification**: Uses official Winget repository
- **Agreement Acceptance**: Automatically accepts package and source agreements
- **Error Handling**: Continues installation even if individual apps fail
- **Success Threshold**: 80% success rate considered acceptable
- **Detailed Logging**: Individual package success/failure tracking
- **Installation Throttling**: 500ms delays between installations to prevent system overload

## Rationale for Runtime Library Coverage

### Complete Compatibility
The comprehensive runtime library installation ensures compatibility with:
- **Legacy Applications**: Older software requiring 2005-2013 VC++ libraries
- **Modern Applications**: New software using .NET 8/9 and latest VC++ 2015+
- **Enterprise Software**: Business applications often requiring specific runtime versions
- **Development Tools**: Java-based IDEs and development environments
- **Gaming**: Many games require specific VC++ redistributable versions

### Version Coverage Strategy
- **Visual C++ 2015+**: Covers most modern applications (backwards compatible)
- **Individual Legacy Versions**: Required for specific older software that doesn't use newer libraries
- **Both Architectures**: x64 and x86 coverage for mixed environments
- **.NET Coverage**: Framework 4.8.1 for legacy, Desktop Runtime 8/9 for modern apps
- **Java LTS Versions**: Long-term support versions (8, 11, 17, 21) for maximum compatibility

## Customization Options

### Adding Applications
To add more applications to the installation list, modify the `$coreApps` array in the script:

```powershell
$coreApps = @(
    # Existing apps...
    @{ Id = 'Publisher.AppName'; Name = 'Display Name' }
)
```

### Skipping Components
Use parameters to skip specific installation categories:
```powershell
# Skip all application installations
.\DeployWorkstation-AllUsers.ps1 -SkipAppInstall

# Skip only Java runtime installations  
.\DeployWorkstation-AllUsers.ps1 -SkipJavaRuntimes
```

### App Export/Import
Backup and restore application lists:
```powershell
# Export current installations
.\DeployWorkstation-AllUsers.ps1 -ExportWingetApps

# Import from backup
.\DeployWorkstation-AllUsers.ps1 -ImportWingetApps
```

## Installation Verification
After script completion, verify installations:

### Via PowerShell
```powershell
# Check installed programs
winget list

# Verify specific runtime
winget list --id Microsoft.VCRedist.2015+.x64
```

### Via GUI
- Check Windows "Add or Remove Programs"
- Look for applications in Start Menu
- Verify runtime libraries in installed programs list

## Troubleshooting Installation Failures

### Common Issues
- **Network Issues**: Slow or unstable internet connection
- **Antivirus Blocking**: Security software preventing downloads
- **Insufficient Space**: Not enough disk space available
- **Permission Issues**: Lack of administrator privileges
- **Package Conflicts**: Existing installations interfering
- **Corporate Policies**: Group policies blocking installations

### Success Optimization
For best installation success rates:
1. **Run as Administrator**: Always use elevated privileges
2. **Disable Antivirus**: Temporarily disable real-time protection during installation
3. **Stable Connection**: Ensure reliable internet connectivity
4. **Clean System**: Run on freshly installed Windows when possible
5. **Check Logs**: Review detailed installation logs for troubleshooting
6. **Use Parameters**: Skip problematic categories with command-line parameters

## Important Notes
1. **Comprehensive Coverage**: The extensive runtime library installation ensures maximum application compatibility
2. **Selective Installation**: Use `-SkipJavaRuntimes` to reduce installation time if Java isn't needed
3. **Future-Proof**: Includes both legacy and modern runtime support
4. **Enterprise Ready**: Suitable for business environments requiring broad software compatibility
5. **Logging**: Detailed success/failure tracking for each package category
6. **Graceful Degradation**: 80% success rate acceptance allows for realistic deployment scenarios

## Restoration
To restore removed functionality:
- **UWP Apps**: Reinstall from Microsoft Store
- **Windows Features**: Re-enable via "Turn Windows features on or off"
- **Services**: Re-enable via `services.msc`
- **Registry Settings**: Manual registry editing required
- **McAfee**: Download and reinstall from McAfee website

---

**Last Updated**: September 2025  
**Script Version**: 2.2
