# Pester 5+ tests. Run from the repo root:  Invoke-Pester -Path tests
#
# DeployWorkstation.ps1 performs its work as soon as it is loaded, so it is never
# executed here. Instead its function definitions and lookup tables are pulled
# out of the parsed script (AST) and exercised against a fake `winget`.

BeforeDiscovery {
    $configCases = @(
        Get-ChildItem (Join-Path (Split-Path $PSScriptRoot -Parent) 'Config\Examples\*.json') -ErrorAction SilentlyContinue |
            ForEach-Object { @{ Name = $_.Name; Path = $_.FullName } }
    )
}

BeforeAll {
    $script:RepoRoot   = Split-Path $PSScriptRoot -Parent
    $script:ScriptPath = Join-Path $script:RepoRoot 'DeployWorkstation.ps1'

    $tokens      = $null
    $parseErrors = $null
    $script:Ast  = [System.Management.Automation.Language.Parser]::ParseFile($script:ScriptPath, [ref]$tokens, [ref]$parseErrors)
    $script:ParseErrors = $parseErrors

    # Lookup tables / state defined at script level
    $variableNames = @(
        '$script:Version', '$script:Strings', '$script:Summary', '$script:ManagedApps',
        '$script:WingetMinVersion', '$script:WingetModern',
        '$script:WingetOkCodes', '$script:WingetRebootOkCodes', '$script:WingetTransientCodes',
        '$script:WingetNotFoundCode', '$script:WingetInstallInProgressCode', '$script:ResolvedIds'
    )
    $assignments = $script:Ast.FindAll({
        param($n)
        $n -is [System.Management.Automation.Language.AssignmentStatementAst] -and
        $n.Parent -is [System.Management.Automation.Language.NamedBlockAst]
    }, $true) | Where-Object { $_.Left.Extent.Text -in $variableNames }
    foreach ($a in $assignments) { . ([scriptblock]::Create($a.Extent.Text)) }

    $functionNames = @(
        'T', 'ConvertTo-HtmlSafe', 'Format-WingetExitCode', 'Get-WingetFailReason',
        'Get-WingetVersionString', 'Test-WingetVersionOk', 'Get-WingetCompatArgs',
        'Get-WingetIdStatus', 'Test-WingetIdExists', 'Resolve-WingetPackageId',
        'Invoke-WingetWithRetry', 'Write-WingetDiagnostics', 'Get-UninstallCommand',
        'Remove-WingetApps', 'Export-HtmlReport'
    )
    $functions = $script:Ast.FindAll({ param($n) $n -is [System.Management.Automation.Language.FunctionDefinitionAst] }, $true) |
                 Where-Object { $_.Name -in $functionNames }
    foreach ($f in $functions) { . ([scriptblock]::Create($f.Extent.Text)) }

    $script:Lang = $script:Strings['en-US']

    # ---- Fakes for the script's side-effecting helpers ----
    function Write-Log { param([string]$Message, [string]$Level = 'INFO') $global:DWT_Log.Add("[$Level] $Message") }
    function Add-Result {
        param([string]$Section, [string]$Item, [string]$Status, [string]$Detail = '')
        $global:DWT_Results.Add(@{ Section = $Section; Item = $Item; Status = $Status; Detail = $Detail })
    }
    function Set-PhaseProgress { }
    function Clear-PhaseProgress { }

    # Fake winget: records each call and asks the current handler for an exit code / output
    function winget {
        $line = ($args | ForEach-Object { "$_" }) -join ' '
        $global:DWT_WingetCalls.Add($line)
        $r = & $global:DWT_WingetHandler $line
        $global:LASTEXITCODE = [int]$r.Code
        $r.Out
    }

    # Safety: some tests drive uninstall logic — refuse to run if `winget` would reach the real tool
    if ((Get-Command winget).CommandType -ne 'Function') { throw 'winget fake is not in effect; aborting tests' }

    function Reset-Fakes {
        param([scriptblock]$Handler = { @{ Code = 0 } })
        $global:DWT_WingetHandler = $Handler
        $global:DWT_WingetCalls   = [System.Collections.Generic.List[string]]::new()
        $global:DWT_Log           = [System.Collections.Generic.List[string]]::new()
        $global:DWT_Results       = [System.Collections.Generic.List[hashtable]]::new()
        $global:DWT_Attempt       = 0
        $script:ResolvedIds       = @{}
        $script:WingetModern      = $true
        $script:Summary.RebootNeeded = $false
    }
    Reset-Fakes
}

AfterAll {
    Remove-Variable -Scope Global -Name DWT_WingetHandler, DWT_WingetCalls, DWT_Log, DWT_Results, DWT_Attempt -ErrorAction SilentlyContinue
}

Describe 'DeployWorkstation Prerequisites' {
    Context 'System Requirements' {
        It 'Should be running on Windows 10 or 11' -Skip:($env:OS -ne 'Windows_NT') {
            [System.Environment]::OSVersion.Version.Major | Should -BeGreaterOrEqual 10
        }

        It 'Should have PowerShell 5.1 or later' {
            $PSVersionTable.PSVersion.Major | Should -BeGreaterOrEqual 5
        }

        It 'Should have internet connectivity' -Skip:($env:OS -ne 'Windows_NT') {
            Test-NetConnection -ComputerName '8.8.8.8' -Port 53 -InformationLevel Quiet | Should -Be $true
        }
    }

    Context 'File Structure' {
        It 'Should have main script file' {
            Test-Path (Join-Path $script:RepoRoot 'DeployWorkstation.ps1') | Should -Be $true
        }

        It 'Should have launcher script' {
            Test-Path (Join-Path $script:RepoRoot 'DeployWorkstation.bat') | Should -Be $true
        }

        It 'Should have quick start launcher script' {
            Test-Path (Join-Path $script:RepoRoot 'QuickStart.cmd') | Should -Be $true
        }

        It 'Should have configuration directory' {
            Test-Path (Join-Path $script:RepoRoot 'Config') | Should -Be $true
        }
    }
}

Describe 'Configuration Validation' {
    Context 'JSON Configuration Files' {
        It 'Should have valid JSON format: <Name>' -ForEach $configCases {
            { Get-Content $Path -Raw | ConvertFrom-Json } | Should -Not -Throw
        }

        It 'Should have at least one example configuration' {
            @(Get-ChildItem (Join-Path $script:RepoRoot 'Config\Examples\*.json')).Count | Should -BeGreaterThan 0
        }
    }
}

Describe 'WinGet Availability' {
    # winget.exe (not `winget`) so these hit the real tool rather than the fake above
    Context 'Package Manager' {
        It 'Should have WinGet available' -Skip:(-not (Get-Command winget.exe -ErrorAction SilentlyContinue)) {
            { winget.exe --version } | Should -Not -Throw
        }

        It 'Should be able to search for packages' -Skip:(-not (Get-Command winget.exe -ErrorAction SilentlyContinue)) {
            winget.exe search --id Google.Chrome --exact --source winget --accept-source-agreements | Should -Not -BeNullOrEmpty
        }
    }
}

Describe 'Script integrity' {
    It 'parses without syntax errors' {
        $script:ParseErrors | Should -BeNullOrEmpty
    }

    It 'keeps string literals ASCII (the file has no BOM, so PS 5.1 would print mojibake)' {
        $tokens = $null; $errs = $null
        $null = [System.Management.Automation.Language.Parser]::ParseFile($script:ScriptPath, [ref]$tokens, [ref]$errs)
        $tokens | Where-Object {
            $_.Kind -in 'StringLiteral', 'StringExpandable', 'HereStringLiteral', 'HereStringExpandable' -and $_.Text -match '[^\x00-\x7F]'
        } | ForEach-Object { "L$($_.Extent.StartLineNumber): $($_.Text)" } | Should -BeNullOrEmpty
    }

    It 'has the same localization keys in en-US and es-ES' {
        $en = @($script:Strings['en-US'].Keys | Sort-Object)
        $es = @($script:Strings['es-ES'].Keys | Sort-Object)
        Compare-Object $en $es | Should -BeNullOrEmpty
    }

    It 'defines every localization key the script uses' {
        $used = $script:Ast.FindAll({
                    param($n)
                    $n -is [System.Management.Automation.Language.CommandAst] -and $n.GetCommandName() -eq 'T'
                }, $true) |
                ForEach-Object { $_.CommandElements[1] } |
                Where-Object { $_ -is [System.Management.Automation.Language.StringConstantExpressionAst] } |
                ForEach-Object { $_.Value } | Sort-Object -Unique
        @($used).Count | Should -BeGreaterThan 50
        $used | Where-Object { -not $script:Strings['en-US'].ContainsKey($_) } | Should -BeNullOrEmpty
    }

    It 'uses one version number across the script and launchers' {
        $v = [regex]::Escape($script:Version)
        $script:Strings['en-US'].Started | Should -Match "v$v\b"
        $script:Strings['es-ES'].Started | Should -Match "v$v\b"
        Get-Content (Join-Path $script:RepoRoot 'DeployWorkstation.bat') -Raw | Should -Match "Launcher v$v\b"
        Get-Content (Join-Path $script:RepoRoot 'QuickStart.cmd') -Raw       | Should -Match "Quick Start v$v\b"
    }

    It 'passes -NoPause from both launchers (they pause themselves)' {
        Get-Content (Join-Path $script:RepoRoot 'DeployWorkstation.bat') -Raw | Should -Match 'DeployWorkstation\.ps1" -NoPause'
        @(Select-String -Path (Join-Path $script:RepoRoot 'QuickStart.cmd') -Pattern 'powershell\.exe').Count |
            Should -Be @(Select-String -Path (Join-Path $script:RepoRoot 'QuickStart.cmd') -Pattern 'powershell\.exe.*-NoPause').Count
    }
}

Describe 'Winget exit-code tables' {
    It 'labels NO_APPLICATIONS_FOUND correctly' {
        Format-WingetExitCode $script:WingetNotFoundCode | Should -Be '0x8A150014'
    }

    It 'labels INSTALL_IN_PROGRESS correctly' {
        Format-WingetExitCode $script:WingetInstallInProgressCode | Should -Be '0x8A150102'
    }

    It 'retries download failures and install-in-progress' {
        $hex = $script:WingetTransientCodes | ForEach-Object { Format-WingetExitCode $_ }
        $hex | Should -Contain '0x8A150008'
        $hex | Should -Contain '0x8A150102'
        $hex | Should -Contain '0x8A150107'
    }

    It 'never retries restart codes as network errors' {
        $hex = $script:WingetTransientCodes | ForEach-Object { Format-WingetExitCode $_ }
        foreach ($code in '0x8A150109', '0x8A15010A', '0x8A15010B') { $hex | Should -Not -Contain $code }
    }

    It 'counts restart-to-finish as success' {
        $script:WingetRebootOkCodes | ForEach-Object { Format-WingetExitCode $_ } | Should -Contain '0x8A150109'
    }

    It 'gives a readable reason for known codes' {
        Get-WingetFailReason -ExitCode -1978334974 | Should -Match 'in progress'
        Get-WingetFailReason -ExitCode -1978335224 | Should -Match 'download'
    }

    It 'falls back to the hex code for unknown codes' {
        Get-WingetFailReason -ExitCode -1978335000 | Should -Match '0x8A1500E8'
    }
}

Describe 'Winget version handling' {
    BeforeEach { Reset-Fakes }

    It 'treats "<Version>" as up to date = <Expected>' -ForEach @(
        @{ Version = '1.9.25200'; Expected = $true  }
        @{ Version = '1.10.340';  Expected = $true  }
        @{ Version = '1.4.0';     Expected = $true  }
        @{ Version = '1.3.2691';  Expected = $false }
        @{ Version = '1.2';       Expected = $false }
        @{ Version = '';          Expected = $true  }
        @{ Version = 'garbage';   Expected = $true  }
    ) {
        Test-WingetVersionOk -VersionString $Version | Should -Be $Expected
    }

    It 'reads the version from noisy multi-line output' {
        Reset-Fakes -Handler { @{ Code = 0; Out = @('', 'v1.9.25200') } }
        Get-WingetVersionString | Should -Be '1.9.25200'
    }

    It 'adds the newer flags when winget is current' {
        (Get-WingetCompatArgs -Verb 'upgrade') -join ' ' | Should -Be '--include-unknown --disable-interactivity'
        (Get-WingetCompatArgs -Verb 'install') -join ' ' | Should -Be '--disable-interactivity'
    }

    It 'omits the newer flags in compatibility mode' {
        $script:WingetModern = $false
        @(Get-WingetCompatArgs -Verb 'install').Count | Should -Be 0
        @(Get-WingetCompatArgs -Verb 'upgrade').Count | Should -Be 0
    }
}

Describe 'Resolve-WingetPackageId' {
    BeforeAll {
        $script:Chrome = @{ Id = 'Google.Chrome'; Name = 'Google Chrome'; Fallbacks = @('Google.Chrome.EXE') }
    }
    BeforeEach { Reset-Fakes }

    It 'returns the primary ID when it exists' {
        Reset-Fakes -Handler { @{ Code = 0 } }
        Resolve-WingetPackageId -App $script:Chrome | Should -Be 'Google.Chrome'
    }

    It 'uses a fallback ID when the primary ID is gone' {
        Reset-Fakes -Handler {
            param($line)
            if ($line -match '^show --id Google\.Chrome\.EXE ') { return @{ Code = 0 } }
            @{ Code = -1978335212 }
        }
        Resolve-WingetPackageId -App $script:Chrome | Should -Be 'Google.Chrome.EXE'
    }

    It 'adopts an unambiguous winget search result' {
        Reset-Fakes -Handler {
            param($line)
            if ($line -like 'search*')                   { return @{ Code = 0; Out = @('Name     Id       Version Source', '------', 'Foo App  Foo.App  1.2.3   winget') } }
            if ($line -match '^show --id Foo\.App ')      { return @{ Code = 0 } }
            @{ Code = -1978335212 }
        }
        Resolve-WingetPackageId -App @{ Id = 'Old.Foo'; Name = 'Foo App' } | Should -Be 'Foo.App'
    }

    It 'returns $null (and caches it) when the ID is confirmed missing everywhere' {
        Reset-Fakes -Handler { @{ Code = -1978335212 } }
        Resolve-WingetPackageId -App $script:Chrome | Should -BeNullOrEmpty
        $script:ResolvedIds.ContainsKey('Google.Chrome') | Should -Be $true
    }

    It 'does not misreport an offline machine as "ID not found"' {
        Reset-Fakes -Handler { @{ Code = -2147012894 } }   # 0x80072EE2 WinHTTP timeout
        Resolve-WingetPackageId -App $script:Chrome | Should -Be 'Google.Chrome'
        $script:ResolvedIds.ContainsKey('Google.Chrome') | Should -Be $false
        ($global:DWT_Log -join "`n") | Should -Match 'Could not verify'
        ($global:DWT_Log -join "`n") | Should -Not -Match 'not found in winget source'
    }
}

Describe 'Invoke-WingetWithRetry' {
    BeforeEach { Reset-Fakes }

    It 'returns immediately on success' {
        Reset-Fakes -Handler { @{ Code = 0; Out = 'ok' } }
        $r = Invoke-WingetWithRetry -Arguments @('install', '--id', 'A') -AppName 'A' -RetryDelaySec 0
        $r.ExitCode | Should -Be 0
        $global:DWT_WingetCalls.Count | Should -Be 1
    }

    It 'retries a transient error and then succeeds' {
        Reset-Fakes -Handler { $global:DWT_Attempt++; if ($global:DWT_Attempt -eq 1) { @{ Code = -1978334974 } } else { @{ Code = 0 } } }
        $r = Invoke-WingetWithRetry -Arguments @('install', '--id', 'A') -AppName 'A' -RetryDelaySec 0
        $r.ExitCode | Should -Be 0
        $global:DWT_WingetCalls.Count | Should -Be 2
    }

    It 'gives up after MaxRetries' {
        Reset-Fakes -Handler { @{ Code = -1978335224 } }
        $r = Invoke-WingetWithRetry -Arguments @('install', '--id', 'A') -AppName 'A' -MaxRetries 2 -RetryDelaySec 0
        $r.ExitCode | Should -Be -1978335224
        $global:DWT_WingetCalls.Count | Should -Be 3
    }

    It 'does not retry permanent errors' {
        Reset-Fakes -Handler { @{ Code = -1978334961 } }   # blocked by policy
        $null = Invoke-WingetWithRetry -Arguments @('install', '--id', 'A') -AppName 'A' -RetryDelaySec 0
        $global:DWT_WingetCalls.Count | Should -Be 1
    }

    It 'stops on caller-supplied stop codes' {
        Reset-Fakes -Handler { @{ Code = -1978335212 } }
        $r = Invoke-WingetWithRetry -Arguments @('upgrade', '--id', 'A') -AppName 'A' -StopCodes @(-1978335212) -RetryDelaySec 0
        $r.ExitCode | Should -Be -1978335212
        $global:DWT_WingetCalls.Count | Should -Be 1
    }

    It 'refreshes the winget source before retrying a hash mismatch' {
        Reset-Fakes -Handler {
            param($line)
            if ($line -like 'source*') { return @{ Code = 0 } }
            $global:DWT_Attempt++
            if ($global:DWT_Attempt -eq 1) { @{ Code = -1978335215 } } else { @{ Code = 0 } }
        }
        $null = Invoke-WingetWithRetry -Arguments @('install', '--id', 'A') -AppName 'A' -RetryDelaySec 0
        $global:DWT_WingetCalls | Should -Contain 'source update --name winget'
    }

    It 'passes the exact argument list, with no blanks in compatibility mode' {
        $script:WingetModern = $false
        $wingetArgs = @('install', '--id', 'A', '--exact') + @(Get-WingetCompatArgs -Verb 'install')
        $null = Invoke-WingetWithRetry -Arguments $wingetArgs -AppName 'A' -RetryDelaySec 0
        $global:DWT_WingetCalls[0] | Should -Be 'install --id A --exact'
    }
}

Describe 'Remove-WingetApps' {
    BeforeEach { Reset-Fakes }

    It 'skips the uninstall when winget list finds nothing' {
        Reset-Fakes -Handler {
            param($line)
            if ($line -like 'list*') { return @{ Code = -1978335212; Out = 'No installed package found matching input criteria.' } }
            @{ Code = 0 }
        }
        Remove-WingetApps -AppPatterns @('Clipchamp')
        $global:DWT_WingetCalls | Where-Object { $_ -like 'uninstall*' } | Should -BeNullOrEmpty
        $global:DWT_Results[0].Status | Should -Be 'SKIPPED'
    }

    It 'counts a restart-to-finish uninstall as removed and flags a restart' {
        Reset-Fakes -Handler {
            param($line)
            if ($line -like 'list*') { return @{ Code = 0; Out = @('Name      Id                   Version', 'Clipchamp Clipchamp.Clipchamp  1.0') } }
            @{ Code = -1978334967 }   # 0x8A150109
        }
        Remove-WingetApps -AppPatterns @('Clipchamp')
        $global:DWT_Results[0].Status | Should -Be 'OK'
        $script:Summary.RebootNeeded  | Should -Be $true
    }

    It 'does not report restart-required-first as "not installed"' {
        Reset-Fakes -Handler {
            param($line)
            if ($line -like 'list*') { return @{ Code = 0; Out = @('Name      Id                   Version', 'Clipchamp Clipchamp.Clipchamp  1.0') } }
            @{ Code = -1978334966 }   # 0x8A15010A
        }
        Remove-WingetApps -AppPatterns @('Clipchamp')
        $global:DWT_Results[0].Status | Should -Be 'WARN'
        $script:Summary.RebootNeeded  | Should -Be $true
    }
}

Describe 'Get-UninstallCommand' {
    It 'turns an MSI /I entry into a silent /X uninstall' {
        $c = Get-UninstallCommand -UninstallString 'MsiExec.exe /I{12345678-1234-1234-1234-123456789ABC}'
        $c.IsMsi     | Should -Be $true
        $c.FilePath  | Should -Be 'MsiExec.exe'
        $c.Arguments | Should -Be '/X{12345678-1234-1234-1234-123456789ABC} /qn /norestart'
    }

    It 'adds silent switches to a quoted EXE uninstaller' {
        $c = Get-UninstallCommand -UninstallString '"C:\Program Files\McAfee\MSC\mcuihost.exe" /body:misp://MSCJsRes.dll::uninstall.html /id:uninstall'
        $c.IsMsi     | Should -Be $false
        $c.FilePath  | Should -Be 'C:\Program Files\McAfee\MSC\mcuihost.exe'
        $c.Arguments | Should -Be '/body:misp://MSCJsRes.dll::uninstall.html /id:uninstall /S /quiet'
    }

    It 'leaves existing silent switches alone' {
        (Get-UninstallCommand -UninstallString '"C:\x\uninst.exe" /silent').Arguments | Should -Be '/silent'
    }

    It 'handles an unquoted path that contains spaces' {
        $c = Get-UninstallCommand -UninstallString 'C:\Program Files\McAfee\uninst.exe /x'
        $c.FilePath  | Should -Be 'C:\Program Files\McAfee\uninst.exe'
        $c.Arguments | Should -Be '/x /S /quiet'
    }

    It 'adds silent switches when the uninstaller has no arguments' {
        (Get-UninstallCommand -UninstallString '"C:\x\uninst.exe"').Arguments | Should -Be '/S /quiet'
    }

    It 'prefers QuietUninstallString and uses it unchanged' {
        $c = Get-UninstallCommand -UninstallString '"C:\x\uninst.exe"' -QuietUninstallString '"C:\x\uninst.exe" --mode unattended'
        $c.Arguments | Should -Be '--mode unattended'
    }

    It 'returns $null when there is no uninstall string' {
        Get-UninstallCommand -UninstallString '' | Should -BeNullOrEmpty
    }
}

Describe 'Export-HtmlReport' {
    BeforeAll {
        $script:OsInfo       = [pscustomobject]@{ Caption = 'Microsoft Windows 11 Pro'; TotalVisibleMemorySize = 16777216; LastBootUpTime = (Get-Date).AddHours(-5) }
        $script:OsBuild      = 26100
        $script:StartTime    = (Get-Date).AddMinutes(-3)
        $script:resolvedLang = 'en-US'
        $script:EventLog     = [System.Collections.Generic.List[hashtable]]::new()
        $script:Results      = [System.Collections.Generic.List[hashtable]]::new()
        $script:Results.Add(@{ Section = 'APP UPDATE'; Item = '<7-Zip>'; Status = 'OK'; Detail = 'Updated' })
    }
    BeforeEach {
        Reset-Fakes
        $script:ReportPath = Join-Path $TestDrive 'report.html'
    }

    It 'shows update counters and the restart notice in update mode' {
        $script:UpdateMode           = $true
        $script:Summary.AppsUpdated  = 3
        $script:Summary.AppsSkipped  = 2
        $script:Summary.RebootNeeded = $true
        Export-HtmlReport -OverallStatus 'WARNING'
        $html = Get-Content $script:ReportPath -Raw
        $html | Should -Match 'Apps Updated / OK'
        $html | Should -Match 'Apps Skipped'
        $html | Should -Match 'class="reboot"'
        $html | Should -Not -Match 'Apps Installed / OK'
        $html | Should -Match '&lt;7-Zip&gt;'
    }

    It 'shows install counters and the real script version in install mode' {
        $script:UpdateMode = $false
        Export-HtmlReport -OverallStatus 'SUCCESS'
        $html = Get-Content $script:ReportPath -Raw
        $html | Should -Match 'Apps Installed / OK'
        $html | Should -Match ">$([regex]::Escape($script:Version))<"
        $html | Should -Not -Match 'class="reboot"'
    }
}
