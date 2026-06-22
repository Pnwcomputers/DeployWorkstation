# Troubleshooting

## Common Issues

### Script won't execute

- Verify you are running as Administrator (right-click → Run as administrator)
- Ensure Windows PowerShell 5.1 is installed (`$PSVersionTable.PSVersion` must be ≥ 5.1)
- The `.bat` launcher handles execution policy automatically — if running the `.ps1` directly, use:
  ```powershell
  powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\DeployWorkstation.ps1
  ```

---

### Winget installation fails or "winget not found"

- The script attempts to auto-install/repair winget on OEM machines
- If the auto-bootstrap also fails, verify internet connectivity
- Ensure Windows is up to date — winget ships as part of App Installer via Windows Update
- On LTSC or air-gapped builds, install App Installer manually from the Microsoft Store

---

### App install fails with "package not found"

- Run `winget source update` to refresh the package index
- Verify the winget ID is current: `winget search <AppName>`
- Check the `$script:ManagedApps` array in `DeployWorkstation.ps1` for the correct ID

---

### Bloatware returns after reboot

- Ensure the script ran as Administrator
- Some OEM builds re-provision removed Appx packages on next login — run the script after all user profiles have been created
- Check Group Policy restrictions (WSUS/MDM policies can block Appx removal)

---

### Windows Capabilities not removed (Quick Assist, Xbox, OpenSSH)

- `Get-WindowsCapability` requires Windows Update to be accessible
- The script skips capability removal when the `wuauserv` service is disabled
- Ensure Windows Update is not blocked by policy, then re-run

---

### OneDrive returns after removal

- OEM-embedded OneDrive (in `System32\OneDriveSetup.exe`) is handled separately from the Appx version
- If OEM OneDrive re-installs, run the script again — it checks both the Appx package and the OEM binary
- Windows Update may re-install OneDrive; a recurring scheduled task or GPO setting is needed to prevent this permanently

---

### HTML report not generated

- Check that the script has write access to the output path (default: same folder as the script)
- Use `-ReportPath` to redirect: `.\DeployWorkstation.ps1 -ReportPath C:\Temp\report.html`
- Review `DeployWorkstation.log` for `ReportFail` entries

---

## Log Analysis

```powershell
# Check for errors and warnings in the deployment log
Get-Content .\DeployWorkstation.log | Select-String "ERROR|WARN"

# Show only failed app installs
Get-Content .\DeployWorkstation.log | Select-String "Failed|InstallFail"

# Verify installed winget packages
winget list --source winget
```

The HTML report (`DeployWorkstation.html`) provides the same information in a dark-themed, browser-readable format — open it after the run completes.

---

## Getting Help

- Open a [GitHub issue](https://github.com/Pnwcomputers/DeployWorkstation/issues) with the log file attached
- Email [support@pnwcomputers.com](mailto:support@pnwcomputers.com) for direct support
