# DeployWorkstation.ps1 - Changelog

## Version 2.1.1 - Bug Fixes (2025-06-23)

### 🐛 **Critical Bug Fixes**

#### **Registry Drive Creation Enhancement**
- **Issue**: HKU: PowerShell drive not persisting properly across script execution
- **Fix**: Added `-Scope Global` parameter to `New-PSDrive` command
- **Impact**: Ensures registry drive remains available throughout script execution
- **Line**: Function `Initialize-RegistryDrives`

#### **Set-ItemProperty Parameter Correction**
- **Issue**: Using incorrect parameter `-PropertyType` instead of `-Type`
- **Error**: `A parameter cannot be found that matches parameter name 'PropertyType'`
- **Fix**: Changed all instances of `-PropertyType DWord` to `-Type DWord`
- **Impact**: Registry settings now apply correctly for privacy, bloatware prevention, and user configurations
- **Affected Functions**:
  - `Set-SystemConfigurationAllUsers`
  - `Configure-AllUserProfiles` 
  - `Set-DefaultUserProfile`

#### **Registry Drive Validation**
- **Issue**: Script continuing even when HKU drive unavailable
- **Fix**: Added drive existence verification before registry operations
- **Impact**: Better error handling and automatic recovery
- **Enhancement**: Added fallback logic to recreate drive if it becomes unavailable

### 🔧 **Technical Improvements**

#### **Enhanced Error Handling**
- Added registry drive verification before each operation
- Improved logging for troubleshooting registry issues
- Better error messages for failed registry operations

#### **Registry Hive Management**
- Extended sleep timers for registry hive mounting (2→3 seconds)
- Added garbage collection before unmounting registry hives
- Improved unmount error handling (exit code 1 warnings are normal)

### 📝 **Error Analysis from Testing**

#### **Errors Resolved**
```
[ERROR] Error configuring system: A parameter cannot be found that matches parameter name 'PropertyType'
[WARN] Error setting registry key SOFTWARE\Microsoft\Windows\CurrentVersion\Privacy for TestVM: A parameter cannot be found that matches parameter name 'PropertyType'
[WARN] Error setting default user registry key SOFTWARE\Policies\Microsoft\Windows\CloudContent: A parameter cannot be found that matches parameter name 'PropertyType'
```
**Status**: ✅ **FIXED** - All instances of `-PropertyType` corrected to `-Type`

#### **Warnings - Expected Behavior**
```
[WARN] Failed to dismount registry hive for: TestVM (Exit code: 1)
```
**Status**: ⚠️ **NORMAL** - Registry hive dismount warnings are common and don't impact functionality

### 🎯 **Components Successfully Validated**

| Component | Status | Notes |
|-----------|--------|-------|
| **Winget App Removal** | ✅ Working | Bloatware successfully removed |
| **AppX Package Removal** | ✅ Working | UWP apps removed for all users |
| **Application Installation** | ✅ Working | Essential apps installed via Winget |
| **Windows Services** | ✅ Working | Unwanted services disabled |
| **HKU Drive Creation** | ✅ **FIXED** | Now persists properly |
| **System Registry Settings** | ✅ **FIXED** | Privacy/bloatware settings apply correctly |
| **User Profile Configuration** | ✅ **FIXED** | Existing user settings configured |
| **Default User Profile** | ✅ **FIXED** | Future user accounts pre-configured |

### 🚀 **Deployment Recommendations**

#### **For Fresh Deployments**
- Use the corrected version for new installations
- No additional steps required

#### **For Systems with Previous v2.1 Run**
- Re-run with registry-only flags to apply missed settings:
  ```powershell
  .\DeployWorkstation-AllUsers.ps1 -SkipAppInstall -SkipBloatwareRemoval
  ```

#### **Verification Commands**
Check if registry fixes were applied:
```powershell
# Check system-wide telemetry settings
Get-ItemProperty "HKLM:\SOFTWARE\Policies\Microsoft\Windows\DataCollection" -Name "AllowTelemetry" -ErrorAction SilentlyContinue

# Check consumer features disabled
Get-ItemProperty "HKLM:\SOFTWARE\Policies\Microsoft\Windows\CloudContent" -Name "DisableWindowsConsumerFeatures" -ErrorAction SilentlyContinue

# Check user privacy settings
Get-ItemProperty "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Privacy" -Name "TailoredExperiencesWithDiagnosticDataEnabled" -ErrorAction SilentlyContinue
```

### 📋 **Testing Environment**
- **OS**: Windows 10/11
- **PowerShell Version**: 5.1 (Windows PowerShell Desktop)
- **Test User**: TestVM
- **Execution**: Administrator privileges required
- **Result**: Script completed successfully with registry settings properly applied

### 🔗 **Related Issues**
- **Issue #1**: HKU drive not found error
- **Issue #2**: PropertyType parameter not recognized
- **Issue #3**: Registry settings not applying to user profiles

**Next Version**: 2.1.2 (Planned improvements to registry hive dismount handling)  
**Compatibility**: Windows 10 (1809+), Windows 11  
**Prerequisites**: PowerShell 5.1+, Administrator privileges, Winget installed
