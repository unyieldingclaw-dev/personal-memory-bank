#Requires -Modules Pester

# WHY this file exists: pre-push-check.ps1 had no tests, yet it is the twin that runs on every
# Windows push — .githooks/pre-push prefers pwsh whenever it is on PATH, on any OS — while the
# POSIX twin's Check 7 is covered by tests/test-pre-push-check.sh. This covers Check 7 only:
# it must call the read-only `mb doctor --check`, refuse to trust a run that did not confirm
# check mode, give a checksum mismatch its own counted warning, and treat a missing baseline
# as INFO. Mirrors the Check 7 sections of tests/test-pre-push-check.sh.
#
# `mb` is a stub mb.ps1 placed first on PATH: Get-Command resolves a .ps1 found on PATH, and
# the hook's `& mb doctor --check` then reaches it through the call operator, so its $args
# show exactly what the hook passed. The stub prints with Write-Output, which the hook's
# `2>&1 | Out-String` captures. It models what the hook PARSES, not a real install: the real
# mb.ps1 writes with Write-Host, which that capture misses in-process (measured: UNKNOWN), and
# real installs reach the hook through mb.bat (`pwsh -File`) or install.sh's wrapper instead.

BeforeAll {
    $RepoRoot = Split-Path $PSScriptRoot -Parent
    $script:Hook = Join-Path $RepoRoot 'scripts/pre-push-check.ps1'
    $script:Marker = '[OK]   Integrity check mode: .pmb-checksums not modified'

    # A clean repo with a committed file, .gitattributes present, and no remote — the same
    # fixture shape as make_clean_repo in tests/test-pre-push-check.sh.
    $script:Repo = Join-Path $TestDrive 'repo'
    New-Item -ItemType Directory -Path $script:Repo | Out-Null
    Push-Location $script:Repo
    try {
        git init -q 2>$null
        git config user.email 'test@example.com'
        git config user.name 'Test'
        git config commit.gpgsign false
        Set-Content -Path '.gitattributes' -Value '* text=auto eol=lf'
        Set-Content -Path 'file.txt' -Value 'hello'
        git add -A
        git commit -qm 'initial' 2>$null
    } finally { Pop-Location }

    $script:StubDir = Join-Path $TestDrive 'stub'
    New-Item -ItemType Directory -Path $script:StubDir | Out-Null
    $script:ArgsFile = Join-Path $TestDrive 'stub-args.txt'
    # The stub prints the lines in $env:STUB_LINES (separated by '|') and records its args.
    Set-Content -Path (Join-Path $script:StubDir 'mb.ps1') -Value @'
Set-Content -Path $env:STUB_ARGS_FILE -Value ($args -join ' ')
foreach ($l in ($env:STUB_LINES -split '\|')) { if ($l) { Write-Output $l } }
'@

    function Invoke-Hook {
        param([string[]]$StubLines, [switch]$Enforce)
        $savedPath = $env:PATH
        Push-Location $script:Repo
        try {
            $env:PATH = $script:StubDir + [IO.Path]::PathSeparator + $env:PATH
            $env:STUB_LINES = $StubLines -join '|'
            $env:STUB_ARGS_FILE = $script:ArgsFile
            if ($Enforce) { $env:ENFORCE = 'true' } else { Remove-Item Env:\ENFORCE -ErrorAction SilentlyContinue }
            $out = & pwsh -NoLogo -NoProfile -ExecutionPolicy Bypass -File $script:Hook 2>&1 | Out-String
            [PSCustomObject]@{ Output = $out; ExitCode = $LASTEXITCODE }
        } finally {
            Pop-Location
            $env:PATH = $savedPath
            foreach ($v in 'STUB_LINES', 'STUB_ARGS_FILE', 'ENFORCE') { Remove-Item "Env:\$v" -ErrorAction SilentlyContinue }
        }
    }
}

# Git for Windows writes loose objects read-only, and Pester's TestDrive teardown then fails
# with "Access to the path ... is denied" after every test has passed (measured). Clearing the
# attribute is enough; nothing here needs the objects once the tests have run.
AfterAll {
    Get-ChildItem -LiteralPath $script:Repo -Recurse -Force -File -ErrorAction SilentlyContinue |
        ForEach-Object { $_.IsReadOnly = $false }
}

Describe "pre-push-check.ps1 Check 7 (mb doctor --check)" {
    It "invokes exactly 'mb doctor --check'" {
        Invoke-Hook -StubLines @('[OK]   Memory Bank v1.2.1', $script:Marker) | Out-Null
        (Get-Content -Path $script:ArgsFile -Raw).Trim() | Should -BeExactly 'doctor --check'
    }

    It "reports OK and a green summary for a confirmed, clean run" {
        $r = Invoke-Hook -StubLines @('[OK]   Memory Bank v1.2.1', $script:Marker)
        $r.Output | Should -Match '\[OK\]   mb doctor: 2 result lines, no errors'
        $r.Output | Should -Match 'All pre-push checks passed'
    }

    It "reports UNKNOWN, not OK, when results arrive without the check-mode marker" {
        $r = Invoke-Hook -StubLines @('[OK]   Memory Bank v1.2.1', '[OK]   Git repository detected')
        $r.Output | Should -Match '\[UNKNOWN\] mb doctor did not confirm check mode'
        # The remedy must name the clone: `mb upgrade` alone, run from an outdated clone, reinstalls the old hook.
        $r.Output | Should -Match 'update the PMB clone that MB_HOME points at'
        $r.Output | Should -Not -Match '\[OK\]   mb doctor:'
        $r.Output | Should -Not -Match 'All pre-push checks passed'
    }

    It "gives a checksum mismatch its own warning, separate from other errors" {
        $lines = @(
            '[OK]   Memory Bank v1.2.1',
            '[ERROR] memory-bank/progress.md (hash mismatch - modified outside mb tools)',
            '[ERROR] Startup context too large',
            $script:Marker
        )
        $r = Invoke-Hook -StubLines $lines
        $r.Output | Should -Match '\[WARN\] memory-bank changed since the last accepted integrity baseline: 1 file\(s\)'
        $r.Output | Should -Match 'memory-bank/progress\.md'
        $r.Output | Should -Match 'mb verify-integrity'
        $r.Output | Should -Match 'reported 1 error\(s\)'
        $r.Output | Should -Match 'Startup context too large'
    }

    # WHY a mismatch-ONLY stub: the stub above also emits an unrelated [ERROR], which counts a
    # warning through the generic branch on its own, so an ENFORCE assertion built on it stays
    # green with the mismatch branch's counter deleted (measured in review). Here the mismatch
    # line is the only possible warning source on this clean repo.
    It "blocks under ENFORCE=true on a checksum mismatch alone, counted as one warning" {
        $enforced = Invoke-Hook -Enforce -StubLines @(
            '[OK]   Memory Bank v1.2.1',
            '[ERROR] memory-bank/progress.md (hash mismatch - modified outside mb tools)',
            $script:Marker
        )
        $enforced.ExitCode | Should -Not -Be 0
        $enforced.Output | Should -Match 'PASS with 1 warning'
        $enforced.Output | Should -Match 'treating warnings as blocking'
    }

    It "reports a missing baseline as INFO without downgrading the summary" {
        $r = Invoke-Hook -StubLines @(
            '[OK]   Memory Bank v1.2.1',
            '[WARN] Integrity checksums: no baseline (.pmb-checksums absent); --check does not create one. Run: mb verify-integrity',
            $script:Marker
        )
        $r.Output | Should -Match '\[INFO\] No memory-bank integrity baseline yet'
        $r.Output | Should -Match 'All pre-push checks passed'
    }
}
