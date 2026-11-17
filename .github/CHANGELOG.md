# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/).

---

## [5.4] - 2026-11-17

### Fixed
- McAfee removal: MSI uninstall strings got `/S /quiet` appended, which `msiexec` rejects with a hidden usage dialog — the run hung indefinitely. MSI entries now use `/X{GUID} /qn /norestart`, `QuietUninstallString` is preferred, uninstalls time out after 20 minutes, and real exit codes are checked (`3010`/`1641` = success + restart, `1605` = already gone)
- Winget bootstrap: an outdated winget was re-registered at the same old version and treated as fixed; the version is now re-checked after every step, `Repair-WinGetPackageManager` is tried as a last resort, and an un-upgradable winget runs in compatibility mode (no 1.4+ flags) instead of failing every install
- Package ID resolution no longer reports "ID not found" when `winget show` failed for another reason (offline, source error) — the install now surfaces the real error
- `0x8A150102` (install in progress) and `0x8A150008` (download failed) are retried
- Bloatware removal: `0x8A15010A` (restart required) was treated as "not installed"; restart-to-finish uninstalls are now OK + restart flag; the `winget list` exit code is used so nothing-installed patterns skip the uninstall attempt
- Appx / capability counters only count removals that actually succeeded; protected system packages (`0x80073CFA`) are reported as skipped
- HTML report showed version 5.2 and install counters during update runs
- `DeployWorkstation.bat` printed `(none - full run` and a blank line for option 1 (unescaped parenthesis)
- CI: every run failed before testing (`-OutputFormat` is not a Pester 5 parameter); test file fixed for Pester 5 discovery rules

### Added
- `-NoPause` switch for unattended runs; both launchers pass it and pause themselves
- Exit codes: `0` success, `2` completed with warnings, `1` critical error; the `.bat` launcher reports each
- Log and HTML report fall back to `%ProgramData%\DeployWorkstation` when the script folder is read-only
- Unit tests (run against the script's real functions with a fake winget) for exit-code tables, ID resolution, retries, uninstall-string parsing, bloatware exit handling and the HTML report; CI now also runs under Windows PowerShell 5.1

### Changed
- `Get-AppxProvisionedPackage` is enumerated once per run instead of once per pattern (faster bloatware phase)
- Install/update retry loops share one helper (`Invoke-WingetWithRetry`)

---

## [5.3] - 2026-08-18

### Fixed
- `.NET Framework` winget ID corrected to `Microsoft.DotNet.Framework.Runtime` (with fallback)
- Reboot exit codes `0x8A150109` / `0x8A15010A` were misclassified as network errors and retried
- Exit-code hex comments corrected against winget's `returnCodes.md`
- `--exact` and `--disable-interactivity` added to winget install/upgrade
- Update mode counted not-installed apps as failures

### Added
- Package ID auto-resolution (primary ID → fallback IDs → `winget search`)
- `--include-unknown` on upgrades; `winget source update` before retrying hash mismatches

---

## [5.2] - 2026-06-22

### Fixed
- `QuickStart.cmd` — all 4 menu options passed `-ConfigFile`, a parameter that doesn't exist in the script; rewrote to use the actual `-SkipBloatwareRemoval`, `-SkipAppInstall`, `-SkipSystemConfig`, and `-UpdateApps` flags
- `QuickStart.cmd` — `goto start` on invalid input crashed cmd.exe because no `:start` label existed; fixed by adding the label
- `tests/DeployWorkstation.Tests.ps1` — test asserted `DeployWorkstation.cmd` exists (it never did), causing permanent CI failure; changed to `QuickStart.cmd`
- `.github/workflows/test-powershell.yml` — `upload-artifact@v3` was deprecated and removed by GitHub; upgraded to `@v4`
- `DeployWorkstation.ps1` — `winget --version` can output multiple lines; casting an array to `[Version]` threw silently, bypassing the minimum-version check; fixed with `Where-Object | Select-Object -Last 1`

### Changed
- `DeployWorkstation.ps1` — `Set-ExecutionPolicy` moved from mid-script (line 529) to line 26, immediately after global preferences, so the policy is set before any function definitions run
- `DeployWorkstation.ps1` — removed unused `$script:IsWin11` variable
- `DeployWorkstation.ps1` — `Export-HtmlReport` now uses the cached `$script:OsInfo` instead of calling `Get-CimInstance Win32_OperatingSystem` a second time
- `.NET` runtime targets updated: removed EOL .NET 6 and .NET 7; kept .NET Framework 4.8; added .NET 8 Desktop Runtime (LTS, supported through November 2026) and .NET 10 Desktop Runtime (LTS, supported through November 2030)

---

## [5.11] - 2026-01-20

### Added
- `-UpdateApps` switch — upgrades already-installed managed apps in-place; safe to re-run on existing machines
- Startup banner with PNWC ASCII art, version header, computer name, and log path

---

## [5.1] - 2025-11-01

### Added
- Winget auto-bootstrap — detects missing or outdated winget and installs App Installer automatically (BITS download with WebClient fallback)
- Retry logic for transient network errors during app installation (2 retries, 10-second delay)
- Windows Update guard for capability removal — skips `Get-WindowsCapability` when `wuauserv` is disabled to avoid misleading SKIPPED results
- OEM OneDrive removal — handles OneDrive embedded in `System32\SysWOW64\OneDriveSetup.exe` (missed by Appx removal)
- Windows edition awareness — detects Home vs. Pro/Enterprise and logs a warning when writing policy-only registry keys that have no effect on Home

---

## [5.0] - 2025-09-01

### Added
- Two-tier `Write-Progress` console progress bars (ID 0 = overall deployment, ID 1 = current phase child bar)
- Embedded `en-US` and `es-ES` localization via `$script:Strings` hashtable and `T()` helper; locale auto-detected from `Get-Culture`
- `ConvertTo-HtmlSafe` function for safe HTML encoding of exception messages and paths in the report

### Changed
- Merged all prior modular `.psm1` files back into a single `DeployWorkstation.ps1` for simpler USB/standalone deployment

---

## [4.x and earlier] - 2025-06-16

### Added
- Initial release: zero-touch Windows 10/11 workstation provisioning
- UWP bloatware removal via `Get-AppxPackage` / `Remove-AppxPackage` (all users + provisioned)
- Win32/MSI enterprise software removal via winget and registry uninstall strings (McAfee)
- Windows Capabilities removal via `Get-WindowsCapability` / `Remove-WindowsCapability`
- Standard app installation via winget (`$script:ManagedApps` array)
- Self-elevating `.bat` launcher with UAC prompt
- Centralized logging (`Write-Log`) to both console and `.log` file
- Dark-themed HTML report with system info, summary counters, and full event log
- PS Core detection — relaunches in Windows PowerShell 5.1 automatically
- `#Requires -RunAsAdministrator` guard
