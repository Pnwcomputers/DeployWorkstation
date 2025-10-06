# Winget-PackageDiagnostics.ps1
# Quick diagnostic tool to identify winget package issues

<#
.SYNOPSIS
Diagnoses winget package installation issues

.DESCRIPTION
Tests each package ID for availability, architecture compatibility, and provides alternative suggestions

.EXAMPLE
.\Winget-PackageDiagnostics.ps1
Run diagnostics on all packages

.EXAMPLE
.\Winget-PackageDiagnostics.ps1 -PackageId "Malwarebytes.Malwarebytes"
Test a specific package
#>

param(
    [string]$PackageId
)

$SystemArchitecture = if ([Environment]::Is64BitOperatingSystem) { 'x64' } else { 'x86' }

$DefaultPackages = @(
    'Malwarebytes.Malwarebytes',
    'BleachBit.BleachBit',
    'Google.Chrome',
    'Adobe.Acrobat.Reader.64-bit',
    '7zip.7zip',
    'VideoLAN.VLC',
    'Microsoft.DotNet.DesktopRuntime.7',
    'Microsoft.DotNet.DesktopRuntime.8',
    'Microsoft.VCRedist.2015+.x64',
    'Microsoft.VCRedist.2015+.x86',
    'Oracle.JavaRuntimeEnvironment'
)

function Test-PackageDetailed {
    param([string]$Id)
    
    Write-Host "`n========================================" -ForegroundColor Cyan
    Write-Host "Testing Package: $Id" -ForegroundColor Cyan
    Write-Host "========================================" -ForegroundColor Cyan
    
    # Test 1: Search exact
    Write-Host "`n[1] Exact Search Test:" -ForegroundColor Yellow
    $searchExact = winget search --id $Id --exact 2>&1
    $exitCode1 = $LASTEXITCODE
    
    if ($exitCode1 -eq 0) {
        Write-Host "✓ Package found with exact match" -ForegroundColor Green
        Write-Host $searchExact
    }
    else {
        Write-Host "✗ Exact match failed (Exit: $exitCode1)" -ForegroundColor Red
        
        # Try partial search
        Write-Host "`n[1b] Partial Search:" -ForegroundColor Yellow
        $searchPartial = winget search $Id 2>&1
        if ($LASTEXITCODE -eq 0) {
            Write-Host "Similar packages found:" -ForegroundColor Yellow
            Write-Host $searchPartial
        }
    }
    
    # Test 2: Show details
    Write-Host "`n[2] Package Details:" -ForegroundColor Yellow
    $showOutput = winget show --id $Id --exact 2>&1
    $exitCode2 = $LASTEXITCODE
    
    if ($exitCode2 -eq 0) {
        Write-Host "✓ Package details retrieved" -ForegroundColor Green
        
        # Extract key information
        $outputStr = $showOutput | Out-String
        
        # Architecture
        if ($outputStr -match 'Architecture:\s*(.+)') {
            $arch = $matches[1].Trim()
            Write-Host "  Architecture: $arch" -ForegroundColor Cyan
            
            if ($arch -match $SystemArchitecture) {
                Write-Host "    ✓ Matches system ($SystemArchitecture)" -ForegroundColor Green
            }
            else {
                Write-Host "    ⚠ May not match system ($SystemArchitecture)" -ForegroundColor Yellow
            }
        }
        
        # Installer Type
        if ($outputStr -match 'Installer Type:\s*(.+)') {
            Write-Host "  Installer Type: $($matches[1].Trim())" -ForegroundColor Cyan
        }
        
        # Version
        if ($outputStr -match 'Version:\s*(.+)') {
            Write-Host "  Version: $($matches[1].Trim())" -ForegroundColor Cyan
        }
        
        # Publisher
        if ($outputStr -match 'Publisher:\s*(.+)') {
            Write-Host "  Publisher: $($matches[1].Trim())" -ForegroundColor Cyan
        }
        
        Write-Host "`nFull Details:" -ForegroundColor Gray
        Write-Host $outputStr -ForegroundColor Gray
    }
    else {
        Write-Host "✗ Cannot retrieve package details (Exit: $exitCode2)" -ForegroundColor Red
        Write-Host $showOutput -ForegroundColor Red
    }
    
    # Test 3: Simulated install
    Write-Host "`n[3] Simulated Installation Test:" -ForegroundColor Yellow
    Write-Host "Testing installation command..." -ForegroundColor Gray
    
    $installTest = winget install --id $Id --exact --source winget --accept-package-agreements --accept-source-agreements --silent --dry-run 2>&1
    $exitCode3 = $LASTEXITCODE
    
    Write-Host "Exit Code: $exitCode3" -ForegroundColor $(if ($exitCode3 -eq 0) { 'Green' } else { 'Red' })
    
    switch ($exitCode3) {
        0 { Write-Host "✓ Package can be installed" -ForegroundColor Green }
        -1978335189 { Write-Host "⚠ Package already installed" -ForegroundColor Yellow }
        -1978335217 { 
            Write-Host "✗ NO APPLICABLE INSTALLER" -ForegroundColor Red
            Write-Host "  This usually means:" -ForegroundColor Yellow
            Write-Host "  - Architecture mismatch (package doesn't support $SystemArchitecture)" -ForegroundColor Yellow
            Write-Host "  - Package configuration issue" -ForegroundColor Yellow
            Write-Host "  - System requirements not met" -ForegroundColor Yellow
        }
        -1978335212 { Write-Host "✗ Package not found in repository" -ForegroundColor Red }
        default { Write-Host "✗ Installation would fail with error: $exitCode3" -ForegroundColor Red }
    }
    
    # Test 4: List available versions
    Write-Host "`n[4] Available Versions:" -ForegroundColor Yellow
    $versions = winget show --id $Id --versions 2>&1
    if ($LASTEXITCODE -eq 0) {
        Write-Host $versions -ForegroundColor Gray
    }
    else {
        Write-Host "Cannot retrieve version list" -ForegroundColor Red
    }
    
    # Recommendation
    Write-Host "`n[5] Recommendation:" -ForegroundColor Yellow
    if ($exitCode2 -eq 0 -and ($exitCode3 -eq 0 -or $exitCode3 -eq -1978335189)) {
        Write-Host "✓ Package should install successfully" -ForegroundColor Green
    }
    elseif ($exitCode3 -eq -1978335217) {
        Write-Host "✗ Package WILL NOT install - architecture or compatibility issue" -ForegroundColor Red
        Write-Host "Action: Try searching for alternative package or check system compatibility" -ForegroundColor Yellow
    }
    else {
        Write-Host "⚠ Installation may have issues - review errors above" -ForegroundColor Yellow
    }
}

# Main execution
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Winget Package Diagnostics Tool" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "System Architecture: $SystemArchitecture" -ForegroundColor Cyan
Write-Host "Winget Version: $(winget --version)" -ForegroundColor Cyan

if ($PackageId) {
    # Test single package
    Test-PackageDetailed -Id $PackageId
}
else {
    # Test all default packages
    Write-Host "`nTesting all default packages...`n"
    
    $summary = @()
    
    foreach ($pkg in $DefaultPackages) {
        Write-Host "Quick test: $pkg..." -NoNewline
        
        $testInstall = winget install --id $pkg --exact --source winget --accept-package-agreements --accept-source-agreements --silent --dry-run 2>&1
        $exitCode = $LASTEXITCODE
        
        $status = switch ($exitCode) {
            0 { "OK"; "Green" }
            -1978335189 { "INSTALLED"; "Cyan" }
            -1978335217 { "NO INSTALLER"; "Red" }
            -1978335212 { "NOT FOUND"; "Red" }
            default { "ERROR ($exitCode)"; "Yellow" }
        }
        
        Write-Host " $($status[0])" -ForegroundColor $status[1]
        
        $summary += [PSCustomObject]@{
            PackageId = $pkg
            Status = $status[0]
            ExitCode = $exitCode
        }
    }
    
    # Summary table
    Write-Host "`n========================================" -ForegroundColor Cyan
    Write-Host "SUMMARY" -ForegroundColor Cyan
    Write-Host "========================================" -ForegroundColor Cyan
    $summary | Format-Table -AutoSize
    
    $failed = $summary | Where-Object { $_.ExitCode -notin @(0, -1978335189) }
    if ($failed.Count -gt 0) {
        Write-Host "`nPackages with issues:" -ForegroundColor Red
        foreach ($fail in $failed) {
            Write-Host "  - $($fail.PackageId): $($fail.Status)" -ForegroundColor Yellow
        }
        
        Write-Host "`nRun with -PackageId parameter for detailed diagnostics:" -ForegroundColor Cyan
        Write-Host "  .\Winget-PackageDiagnostics.ps1 -PackageId '$($failed[0].PackageId)'" -ForegroundColor Gray
    }
    else {
        Write-Host "`n✓ All packages appear ready to install!" -ForegroundColor Green
    }
}

Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "Diagnostic Complete" -ForegroundColor Cyan
Write-Host "========================================`n" -ForegroundColor Cyan
