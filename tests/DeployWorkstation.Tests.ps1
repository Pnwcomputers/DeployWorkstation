# Import Pester module (install if not available)
if (-not (Get-Module -Name Pester -ListAvailable)) {
    Install-Module -Name Pester -Force -SkipPublisherCheck
}

Describe "DeployWorkstation Prerequisites" {
    Context "System Requirements" {
        It "Should be running on Windows 10 or 11" {
            $osVersion = [System.Environment]::OSVersion.Version
            $osVersion.Major | Should -BeGreaterOrEqual 10
        }
        
        It "Should have PowerShell 5.1 or later" {
            $PSVersionTable.PSVersion.Major | Should -BeGreaterOrEqual 5
        }
        
        It "Should have internet connectivity" {
            Test-NetConnection -ComputerName "8.8.8.8" -Port 53 -InformationLevel Quiet | Should -Be $true
        }
    }
    
    Context "File Structure" {
        It "Should have main script file" {
            Test-Path ".\DeployWorkstation.ps1" | Should -Be $true
        }
        
        It "Should have launcher script" {
            Test-Path ".\DeployWorkstation.cmd" | Should -Be $true
        }
        
        It "Should have configuration directory" {
            Test-Path ".\Config" | Should -Be $true
        }
    }
}

Describe "Configuration Validation" {
    Context "JSON Configuration Files" {
        $configFiles = Get-ChildItem ".\Config\Examples\*.json" -ErrorAction SilentlyContinue
        
        foreach ($file in $configFiles) {
            It "Should have valid JSON format: $($file.Name)" {
                { Get-Content $file.FullName | ConvertFrom-Json } | Should -Not -Throw
            }
        }
        
        It "Should have at least one example configuration" {
            $configFiles.Count | Should -BeGreaterThan 0
        }
    }
}

Describe "WinGet Availability" {
    Context "Package Manager" {
        It "Should have WinGet available" {
            { winget --version } | Should -Not -Throw
        }
        
        It "Should be able to search for packages" {
            $result = winget search "Google.Chrome" --exact
            $result | Should -Not -BeNullOrEmpty
        }
    }
}
