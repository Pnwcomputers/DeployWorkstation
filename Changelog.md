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

### 🔗 **Related Issues**
- **Issue #1**: HKU drive not found error
- **Issue #2**: PropertyType parameter not recognized
- **Issue #3**: Registry settings not applying to user profiles
 Registry Hive Dismount Improvements

🎯 Key Enhancements:
1. Retry Logic with Intelligent Backoff
3 attempts per registry hive with increasing delays
Progressive wait times: 2s → 5s → final attempt
Success tracking to avoid unnecessary retries

2. Enhanced Handle Management
Explicit registry key cleanup using .NET Registry classes
Triple garbage collection (collect → finalize → collect)
Extended wait periods for handles to be released
Process diagnostics to identify handle conflicts

3. Better Error Classification
Success/Warning/Error levels with appropriate messaging
Diagnostic information for troubleshooting
Non-critical failure handling (dismount failures often don't affect functionality)

4. Improved Default User Handling
Finally block ensures unmount attempts even on errors
Separate retry logic for default user profile
Mount state tracking to avoid unmounting non-mounted hives

5. Enhanced Error Recovery
Emergency cleanup in catch blocks
Null checking for user profiles array
Graceful degradation when cleanup fails

🔍 New Log Messages:
Success Cases:
[INFO] Successfully dismounted registry hive for: Username
[INFO] Successfully unmounted default user registry hive

Retry Cases:
[WARN] Dismount attempt 1 failed for Username (Exit code: 1)
[INFO] Waiting before retry...
[INFO] Dismount attempt 2 of 3 for: Username

Diagnostic Info:
[INFO] Found 2 reg.exe processes that may be holding handles
[WARN] Failed to dismount registry hive for Username after 3 attempts. This may not affect system functionality.

⚙️ Technical Details:
Handle Cleanup Process:
Garbage Collection - Release managed references
Registry Key Closure - Explicitly close .NET registry handles
Process Diagnostics - Check for conflicting reg.exe processes
Delayed Retry - Allow system time to release resources

Retry Strategy:
Attempt 1: Immediate after cleanup (2s delay)
Attempt 2: 5s delay for handle release
Attempt 3: Final attempt with extended cleanup

**Compatibility**: Windows 10 (1809+), Windows 11  
**Prerequisites**: PowerShell 5.1+, Administrator privileges, Winget installed

### 📋 **Testing Environment**
- **OS**: Windows 10/11
- **PowerShell Version**: 5.1 (Windows PowerShell Desktop)
- **Test User**: TestVM
- **Execution**: Administrator privileges required
- **Result**: Script completed successfully with registry settings properly applied

# DeployWorkstation-AllUsers.ps1 - Version 2.2 Changes (9-12-2025)

## Major Changes Summary

### New Parameters Added
- `$ExportWingetApps` - Export currently installed apps to apps.json
- `$ImportWingetApps` - Import apps from apps.json 
- `$SkipJavaRuntimes` - Skip Java runtime installations

### Application Installation Overhaul

**Old Version:**
- 9 basic applications including minimal .NET and VC++ runtimes
- Single Java Runtime Environment

**New Version:**
- **Core Apps**: Same 7 applications (Malwarebytes, Chrome, etc.)
- **Comprehensive .NET**: Framework 4.8.1, Desktop Runtime 8 & 9
- **Complete VC++ Redistributables**: All versions from 2005-2015+ (x64 & x86)
- **Full Java Support**: JRE + JDK for versions 8, 11, 17, 21 (Eclipse Temurin)
- **Total**: ~25 runtime packages vs. original 9

### Enhanced Error Handling & Logging

**Improvements:**
- Comprehensive try-catch blocks throughout all functions
- Better parameter validation with `[Parameter(Mandatory=$true)]`
- Enhanced logging with severity levels (INFO, WARN, ERROR, DEBUG)
- Proper return value checking in main execution flow
- Input validation for all critical functions

### Code Structure Improvements

**Major Changes:**
- **Fixed Duplicate Functions** - Removed duplicate `Initialize-WingetSources` and `Export-WingetApps` definitions
- **Main() Function** - Created proper main execution function with return value checking
- **Consistent Return Values** - All functions now return boolean success/failure indicators
- **Better Variable Scoping** - Improved variable management and cleanup

### Safety & Security Enhancements

**Key Changes:**
- **Telemetry Setting**: Changed from `0` to `1` (basic level needed for security updates)
- **Conservative Service Disabling**: Removed potentially problematic services from disable list
- **Better Registry Validation**: Enhanced checks before registry operations
- **Improved McAfee Removal**: Better process handling and validation

### Performance & Reliability

**Enhancements:**
- Better winget package validation with regex escaping
- Installation throttling (500ms delays between apps)
- 80% success threshold instead of requiring 100%
- Enhanced registry hive mounting/unmounting with retry logic
- More robust cleanup procedures

## Detailed Function Changes

### Install-StandardApps Function

```powershell
# OLD: 9 total packages
$appsToInstall = @(
    # Basic apps + minimal runtimes
)

# NEW: 25+ comprehensive runtime packages organized by category
$coreApps = @(...)          # 7 apps
$dotnetApps = @(...)        # 3 .NET packages  
$vcredistApps = @(...)      # 12 VC++ packages
$javaJREApps = @(...)       # 4 JRE packages
$javaJDKApps = @(...)       # 4 JDK packages
```

### System Configuration
- **Improved Telemetry Handling**: Set to basic level (1) instead of completely disabled (0)
- **Enhanced Service Management**: More conservative approach to service disabling
- **Better Registry Operations**: Added proper path validation and error handling

### Winget Management
- **Export/Import Functions**: New functionality for app management
- **Better Source Management**: Enhanced winget source initialization
- **Improved Package Detection**: Better existing package checking

## New Features

1. **App Export/Import**: Backup and restore winget app lists
2. **Flexible Java Installation**: Option to skip Java runtimes entirely
3. **Comprehensive Runtime Coverage**: Support for legacy applications requiring older runtimes
4. **Enhanced Logging**: Detailed installation summaries by category
5. **Graceful Degradation**: 80% success rate acceptance for more realistic deployment

## Critical Bug Fixes

1. **Duplicate Function Definitions** - Would have caused PowerShell execution errors
2. **Duplicate Function Calls** - `Set-DefaultUserProfile` was called twice
3. **Inconsistent Error Handling** - Now uniform across all functions
4. **Registry Cleanup Issues** - Enhanced dismounting with retry logic

## Complete Runtime Library Coverage

### .NET Frameworks & Runtimes
- .NET Framework 4.8.1
- .NET Desktop Runtime 8 (includes x64)
- .NET Desktop Runtime 9 (includes x64)

### Visual C++ Redistributables (Complete Set)
- **2015+** (Latest): x64, x86
- **2013**: x64, x86  
- **2012**: x64, x86
- **2010**: x64, x86
- **2008**: x64, x86
- **2005**: x64, x86

### Java Runtime & Development Kits
- **JRE (Runtime)**: Versions 8, 11, 17, 21
- **JDK (Development)**: Versions 8, 11, 17, 21

### Core Applications
- VLC Media Player
- 7-Zip
- Malwarebytes
- Google Chrome
- Adobe Reader
- Zoom
- BleachBit

## Installation Summary Example

The new version provides detailed logging:

```
Installation Summary:
- Core Applications: 7 packages
- .NET Frameworks/Runtimes: 3 packages  
- Visual C++ Redistributables: 12 packages
- Java JRE Packages: 4 packages
- Java JDK Packages: 4 packages
```

## Impact

This represents a significant upgrade from a basic workstation setup script to a comprehensive enterprise-grade deployment tool with extensive runtime library support and robust error handling. The script now ensures maximum application compatibility while maintaining system stability and providing detailed feedback throughout the deployment process.

