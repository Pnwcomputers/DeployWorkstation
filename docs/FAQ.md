# Frequently Asked Questions

## General

**Q: Is this safe to run on an already-deployed machine?**
Yes. Every phase is idempotent. Winget skips already-installed apps, `Remove-AppxPackage` skips packages that aren't present, and registry writes are silent no-ops if the value already matches. Use `-UpdateApps` to upgrade managed apps in-place on existing machines.

---

**Q: Can I run just one phase (e.g., apps only, no bloatware removal)?**
Yes. Use the skip flags:
```powershell
# Apps only
.\DeployWorkstation.ps1 -SkipBloatwareRemoval -SkipSystemConfig

# Config/hardening only
.\DeployWorkstation.ps1 -SkipBloatwareRemoval -SkipAppInstall

# Update existing apps
.\DeployWorkstation.ps1 -SkipBloatwareRemoval -SkipSystemConfig -UpdateApps
```
Or use `DeployWorkstation.bat` / `QuickStart.cmd` which present a menu.

---

**Q: Do I need internet access?**
Yes — all apps are downloaded at runtime via winget from the Microsoft winget repository. Winget itself is also downloaded if missing. Offline scenarios are not currently supported.

---

**Q: What PowerShell version is required?**
Windows PowerShell 5.1 (included with Windows 10 and 11). The script detects PowerShell 7/Core and automatically relaunches itself in `powershell.exe` (Windows PowerShell 5.1).

---

**Q: Does the script support Windows Server?**
The script targets Windows 10 and 11 workstations. Some phases (Appx package removal, Windows Capabilities) behave differently on Server SKUs. Use with care on Server and test thoroughly before deploying.

---

## Application Installation

**Q: How do I add or remove apps from the install list?**
Edit the `$script:ManagedApps` array in `DeployWorkstation.ps1`. See [CONFIGURATION.md](CONFIGURATION.md#adding-or-changing-applications) for instructions and the winget search command.

---

**Q: An app failed to install — what do I do?**
Check `DeployWorkstation.log` for the failure reason. Common causes:
- **Package not found**: Run `winget search <AppName>` — the ID may have changed. Update `$script:ManagedApps`.
- **Network failure**: The script retries twice with a 10-second delay. If it still fails, check your internet connection, proxy, or firewall rules.
- **Hash mismatch**: A winget CDN caching issue — run the script again later or install manually.

---

**Q: Why is winget taking so long or timing out?**
Winget may be rebuilding its source cache on first run. The script runs `winget source update` to refresh the index. On slow or metered connections this can take several minutes. The script will retry on transient network errors.

---

## Bloatware Removal

**Q: What gets removed?**
See the [README Automated Removal Capabilities](../README.md#automated-removal-capabilities) section for the full list of UWP packages, Windows Capabilities, and enterprise software (McAfee).

---

**Q: What if I want to keep an app that would be removed?**
Edit `Remove-AppxPackages` in `DeployWorkstation.ps1` and remove the corresponding pattern from the `$packagesToRemove` array. Or run with `-SkipBloatwareRemoval` and perform selective removal manually.

---

**Q: Will removing OneDrive affect synced files?**
The script removes the OneDrive client app and the OEM-embedded setup binary. Files already synced to `C:\Users\<name>\OneDrive` remain on disk — they are not deleted.

---

## Reporting & Logging

**Q: Where are the log and report files saved?**
By default in the same directory as the script:
- `DeployWorkstation.log` — plain-text log
- `DeployWorkstation.html` — dark-themed HTML report

Use `-LogPath` and `-ReportPath` to write them elsewhere.

---

**Q: The HTML report shows "FAILED" — does that mean the run failed?**
The badge reflects whether any individual item failed or warned. A `WARNING` badge means at least one app install or registry key failed; other phases may have succeeded. Review the detailed results table and the event log in the report.

---

## Support

**Q: How do I get support?**
- Open a [GitHub issue](https://github.com/Pnwcomputers/DeployWorkstation/issues) and attach your `DeployWorkstation.log`
- Email [support@pnwcomputers.com](mailto:support@pnwcomputers.com)
