# DeployWorkstation

DeployWorkstation is a PowerShell-based, zero-touch provisioning toolkit proof of concept for Windows 10 & 11 workstations. 
Whether you’re imaging bare metal or cleaning up an existing PC, DeployWorkstation handles the heavy lifting of standard software and Apps removal, as well as basic application installations.

- **Self-elevating & policy-bypassing**  
  Automatically relaunches under Windows PowerShell 5.1 with `-ExecutionPolicy Bypass` and UAC elevation, so you can double-click or run a single .cmd wrapper without tweaking system settings.

- **UWP “bloatware” purge**  
  In one Desktop-PowerShell pass it uninstalls and de-provisions built-in apps like New Outlook, Clipchamp, Family Safety, OneDrive, LinkedIn, Copilot, Teams, Skype, Xbox, and more.

- **Win32/Msi removal & DISM cleanup**  
  Removes legacy features (Quick Assist, Remote Desktop, Mixed Reality, Game Bar, etc.) via WinGet, DISM and registry, and uninstalls enterprise software such as McAfee by parsing their UninstallStrings from the registry.

- **Standard app install via WinGet**  
  Installs your golden image of third-party tools (Malwarebytes, BleachBit, Chrome, .NET Runtimes, Java, Adobe Reader, Zoom, 7-Zip, VLC, QuickBooks, Pimsy, Furniture Wizard, etc.) in parallel or sequentially, with silent-install flags and built-in error logging.

- **Offline fallback support**  
  Bundles proprietary installers (MSIs/EXEs) on USB and runs them silently if Winget can’t reach the network or community feed.

- **Centralized logging & pause-for-review**  
  Writes a detailed `DeployWorkstation.log` in its script folder and pauses at the end so you can inspect any errors or warnings before rebooting.

## Usage

1. **Copy** the `DeployWorkstation.ps1` and its `.cmd` launcher onto your USB or network share.  
2. **Double-click** the `.cmd` (or run `powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\DeployWorkstation.ps1`) to start.  
3. **Let it run** unattended—when it finishes, it will pause for review and reboot for a clean, ready-to-use machine.

DeployWorkstation turns what used to be a 30-step manual build into a single “plug-and-play” operation, saving hours on every workstation you configure. 
Feel free to fork, tweak the app list, and contribute back!  
