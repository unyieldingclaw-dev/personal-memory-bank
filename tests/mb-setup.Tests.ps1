#Requires -Modules Pester

BeforeAll {
    $RepoRoot = Split-Path $PSScriptRoot -Parent

    function New-TestProject {
        param([string]$Base, [string]$Name)
        $path = Join-Path $Base $Name
        New-Item -ItemType Directory -Path $path -Force | Out-Null
        return $path
    }

    function New-PartialMbProject {
        param([string]$Base, [string]$Name)
        $path = New-TestProject -Base $Base -Name $Name
        $mb   = Join-Path $path 'memory-bank'
        New-Item -ItemType Directory -Path $mb -Force | Out-Null
        Set-Content (Join-Path $mb 'projectbrief.md') "---`nauthority: immutable`nlast-reviewed: 2026-01-01`n---`n# Project Brief`nContent here.`nMore content.`nLine three.`nLine four."
        return $path
    }
}

Describe "Get-MbMode" {
    BeforeAll {
        . (Join-Path $RepoRoot 'scripts/mb.ps1') -Command help 2>$null
    }

    It "returns 'init' when no memory-bank directory exists" {
        $p = New-TestProject -Base $TestDrive -Name 'mode-init'
        Get-MbMode -ProjectPath $p | Should -Be 'init'
    }

    It "returns 'upgrade' when memory-bank directory exists" {
        $p = New-TestProject -Base $TestDrive -Name 'mode-upgrade'
        New-Item -ItemType Directory -Path (Join-Path $p 'memory-bank') | Out-Null
        Get-MbMode -ProjectPath $p | Should -Be 'upgrade'
    }
}

Describe "Get-MbUpgradeAnalysis" {
    BeforeAll {
        . (Join-Path $RepoRoot 'scripts/mb.ps1') -Command help 2>$null
        $script:RepoRoot2 = $RepoRoot
        $script:TestProject = New-PartialMbProject -Base $TestDrive -Name 'analysis-test'
    }

    It "reports missing memory-bank files" {
        $analysis = Get-MbUpgradeAnalysis -ProjectPath $script:TestProject -TemplatesDir (Join-Path $script:RepoRoot2 'templates')
        $analysis.Missing | Should -Contain 'systemPatterns.md'
        $analysis.Missing | Should -Contain 'techContext.md'
        $analysis.Missing | Should -Contain 'activeContext.md'
        $analysis.Missing | Should -Contain 'progress.md'
    }

    It "reports present memory-bank files" {
        $analysis = Get-MbUpgradeAnalysis -ProjectPath $script:TestProject -TemplatesDir (Join-Path $script:RepoRoot2 'templates')
        $analysis.Present | Should -Contain 'projectbrief.md'
    }

    It "reports missing template docs as governance gaps" {
        $analysis = Get-MbUpgradeAnalysis -ProjectPath $script:TestProject -TemplatesDir (Join-Path $script:RepoRoot2 'templates')
        $analysis.GovMissing | Should -Contain 'docs/CONTRACTS-GUIDE.md'
        $analysis.GovMissing | Should -Contain 'docs/HOOKS-GUIDE.md'
    }
}

Describe "Invoke-MbVerify" {
    BeforeAll {
        . (Join-Path $RepoRoot 'scripts/mb.ps1') -Command help 2>$null
        $script:RepoRoot3 = $RepoRoot

        $script:HealthyProject = New-TestProject -Base $TestDrive -Name 'verify-healthy'
        $mbDst = Join-Path $script:HealthyProject 'memory-bank'
        New-Item -ItemType Directory -Path $mbDst | Out-Null
        Get-ChildItem (Join-Path $RepoRoot 'templates/memory-bank') -File | ForEach-Object {
            $content = Get-Content $_.FullName -Raw
            $content = $content -replace 'YYYY-MM-DD', '2026-06-29'
            Set-Content (Join-Path $mbDst $_.Name) $content -NoNewline
        }

        $script:BadProject = New-TestProject -Base $TestDrive -Name 'verify-bad'
        $mbBad = Join-Path $script:BadProject 'memory-bank'
        New-Item -ItemType Directory -Path $mbBad | Out-Null
        Set-Content (Join-Path $mbBad 'projectbrief.md') "---`nlast-reviewed: 2026-06-29`n---`n# Stub"
    }

    It "passes for a fully initialized project" {
        $result = Invoke-MbVerify -ProjectPath $script:HealthyProject -TemplatesDir (Join-Path $script:RepoRoot3 'templates')
        $result.Passed | Should -Be $true
        $result.Missing.Count | Should -Be 0
    }

    It "fails when required files are missing" {
        $result = Invoke-MbVerify -ProjectPath $script:BadProject -TemplatesDir (Join-Path $script:RepoRoot3 'templates')
        $result.Passed | Should -Be $false
        $result.Missing.Count | Should -BeGreaterThan 0
    }
}

# WHY: subprocess, not an in-process function call — Invoke-Upgrade calls `exit` on error
# paths and mutates the process's current location, which would corrupt the Pester runner
# if invoked directly in-process. This is the only test that exercises Invoke-Upgrade's
# actual $advisoryCreate placement for docs/ (the fix for the mb.ps1-vs-mb.sh overwrite-
# semantics divergence) — the bash suite covers the equivalent ADVISORY_CREATE path in
# scripts/mb.sh, but nothing previously exercised the PowerShell side of that same fix.
Describe "Invoke-Upgrade docs advisory-create (subprocess)" {
    BeforeAll {
        $script:RepoRoot4 = $RepoRoot
        $script:UpgradeDocsProject = New-TestProject -Base $TestDrive -Name 'upgrade-docs-advisory'
    }

    It "creates missing docs/HOOKS-GUIDE.md, then preserves a local edit on re-upgrade instead of overwriting it" {
        $mbScript = Join-Path $script:RepoRoot4 'scripts/mb.ps1'
        Push-Location $script:UpgradeDocsProject
        try {
            git init -q 2>$null
            git config user.email "test@test.com" 2>$null
            git config user.name "Test" 2>$null
            git commit -q --allow-empty -m "init" 2>$null

            $env:MB_HOME = $script:RepoRoot4
            & pwsh -NoLogo -ExecutionPolicy Bypass -File $mbScript init 2>&1 | Out-Null

            $hooksGuidePath = Join-Path $script:UpgradeDocsProject 'docs\HOOKS-GUIDE.md'
            Test-Path $hooksGuidePath | Should -Be $true

            Add-Content $hooksGuidePath "`nuser customization"

            $upgradeOutput = (& pwsh -NoLogo -ExecutionPolicy Bypass -File $mbScript upgrade 2>&1) -join "`n"

            $upgradeOutput | Should -Match 'docs/HOOKS-GUIDE\.md \(differs from template'
            (Get-Content $hooksGuidePath -Raw) | Should -Match 'user customization'
        } finally {
            Remove-Item Env:\MB_HOME -ErrorAction SilentlyContinue
            Pop-Location
        }
    }
}

# WHY subprocess, not in-process: Invoke-Init also calls `exit` on error paths and
# mutates the process's current location, same reasoning as the Invoke-Upgrade test above.
# Regression test: templates/.claude/settings.json invokes review-reminders.sh/.ps1 and
# review-reminders-post.sh/.ps1 directly, but Invoke-Init's hook-scripts copy loop never
# included them -- a fresh PowerShell `mb init` shipped a settings.json referencing hook
# scripts that were never actually copied into scripts/ (the mb.sh side of this same bug
# was fixed separately; see CHANGELOG.md).
Describe "Invoke-Init review-reminders scripts (subprocess)" {
    BeforeAll {
        $script:RepoRoot5 = $RepoRoot
        $script:InitReviewRemindersProject = New-TestProject -Base $TestDrive -Name 'init-review-reminders'
    }

    It "copies review-reminders.sh/.ps1 and review-reminders-post.sh/.ps1 on mb init" {
        $mbScript = Join-Path $script:RepoRoot5 'scripts/mb.ps1'
        Push-Location $script:InitReviewRemindersProject
        try {
            git init -q 2>$null
            git config user.email "test@test.com" 2>$null
            git config user.name "Test" 2>$null
            git commit -q --allow-empty -m "init" 2>$null

            $env:MB_HOME = $script:RepoRoot5
            & pwsh -NoLogo -ExecutionPolicy Bypass -File $mbScript init 2>&1 | Out-Null

            foreach ($f in @("review-reminders.sh","review-reminders.ps1","review-reminders-post.sh","review-reminders-post.ps1","_review-gate-classify.py","_review-gate-classify.ps1","_review-gate-merge.py","_review-gate-merge.ps1")) {
                Test-Path (Join-Path $script:InitReviewRemindersProject "scripts\$f") | Should -Be $true
            }
        } finally {
            Remove-Item Env:\MB_HOME -ErrorAction SilentlyContinue
            Pop-Location
        }
    }
}

# WHY this block exists: the bash side got both a positive test and a completeness invariant for
# agent delivery (tests/test-mb-upgrade.sh), and the pwsh side got neither -- despite ps1 discovery
# being a SEPARATE implementation (Get-TemplateDirFile) from the bash glob. A pwsh-only adopter
# could therefore silently not receive a newly-shipped agent, which is precisely the failure that
# `mb upgrade`'s agent auto-discovery was written to close. Found 2026-08-27.
Describe "Invoke-Upgrade agent advisory-create (subprocess)" {
    BeforeAll {
        $script:RepoRoot6 = $RepoRoot
        $script:UpgradeAgentsProject = New-TestProject -Base $TestDrive -Name 'upgrade-agents-advisory'
    }

    It "delivers EVERY agent in templates/.claude/agents to a project that has none" {
        $mbScript = Join-Path $script:RepoRoot6 'scripts/mb.ps1'
        Push-Location $script:UpgradeAgentsProject
        try {
            git init -q 2>$null
            git config user.email "test@test.com" 2>$null
            git config user.name "Test" 2>$null
            git commit -q --allow-empty -m "init" 2>$null

            $env:MB_HOME = $script:RepoRoot6
            & pwsh -NoLogo -ExecutionPolicy Bypass -File $mbScript init 2>&1 | Out-Null

            # Simulate an adopter that predates the agents: clear whatever init delivered.
            $agentsDir = Join-Path $script:UpgradeAgentsProject '.claude\agents'
            if (Test-Path $agentsDir) {
                Get-ChildItem $agentsDir -Filter '*.md' -File | Remove-Item -Force
            }

            & pwsh -NoLogo -ExecutionPolicy Bypass -File $mbScript upgrade 2>&1 | Out-Null

            # COMPLETENESS INVARIANT, deliberately not "opposition.md exists": a hard-coded name
            # would keep passing on the day a third agent is added and goes undelivered, which is
            # the exact stale-list bug this feature replaced. Assert the delivered set covers the
            # template set instead, so the check has no list of its own to go stale.
            $expected = Get-ChildItem (Join-Path $script:RepoRoot6 'templates/.claude/agents') -Filter '*.md' -File |
                        Select-Object -ExpandProperty Name | Sort-Object
            $expected.Count | Should -BeGreaterThan 0
            $missing = @()
            foreach ($name in $expected) {
                if (-not (Test-Path (Join-Path $agentsDir $name))) { $missing += $name }
            }
            ($missing -join ',') | Should -BeExactly ''
        } finally {
            Remove-Item Env:\MB_HOME -ErrorAction SilentlyContinue
            Pop-Location
        }
    }
}

# WHY a separate Describe from the Invoke-Upgrade agent block above: `upgrade` and `init` are
# different delivery paths with different code, and agent delivery was built into `upgrade` only.
# A fresh adopter runs `init`, never `upgrade`, so the path the review gate actually depends on
# was the one with no coverage. Asserting it through `upgrade` would have kept reporting green.
Describe "Invoke-Init agent delivery (subprocess)" {
    BeforeAll {
        $script:RepoRoot7 = $RepoRoot
        $script:InitAgentsProject = New-TestProject -Base $TestDrive -Name 'init-agents-delivery'
    }

    It "delivers EVERY agent in templates/.claude/agents on a bare mb init" {
        $mbScript = Join-Path $script:RepoRoot7 'scripts/mb.ps1'
        Push-Location $script:InitAgentsProject
        try {
            git init -q 2>$null
            git config user.email "test@test.com" 2>$null
            git config user.name "Test" 2>$null
            git commit -q --allow-empty -m "seed" 2>$null

            $env:MB_HOME = $script:RepoRoot7
            # No upgrade anywhere in this test, deliberately: init alone must be sufficient.
            & pwsh -NoLogo -ExecutionPolicy Bypass -File $mbScript init 2>&1 | Out-Null

            # COMPLETENESS INVARIANT -- see the bash twin in tests/test-mb-init.sh for the full
            # rationale. Derived from templates/ at runtime, never enumerated, and asserted
            # non-empty so an absent template directory fails loudly instead of passing on an
            # empty comparison.
            $expected = Get-ChildItem (Join-Path $script:RepoRoot7 'templates/.claude/agents') -Filter '*.md' -File |
                        Select-Object -ExpandProperty Name | Sort-Object
            $expected.Count | Should -BeGreaterThan 0

            $agentsDir = Join-Path $script:InitAgentsProject '.claude\agents'
            $missing = @()
            foreach ($name in $expected) {
                if (-not (Test-Path (Join-Path $agentsDir $name))) { $missing += $name }
            }
            ($missing -join ',') | Should -BeExactly ''
        } finally {
            Remove-Item Env:\MB_HOME -ErrorAction SilentlyContinue
            Pop-Location
        }
    }
}


# WHY this exists: the review-agent model-pin check (mb doctor check 25) shipped in d795abb with
# BASH coverage ONLY (tests/test-mb-doctor.sh). Its own comment calls it security-relevant -- an
# unpinned review agent silently inherits CLAUDE_CODE_SUBAGENT_MODEL=haiku, and a cheap review that
# finds nothing looks exactly like a thorough one that finds nothing. A pwsh-only adopter had no
# test behind the check at all. Subprocess, matching the other doctor-path tests: Show-Doctor writes
# to the host rather than returning a value.
Describe "Show-Doctor review-agent model pin (subprocess)" {
    BeforeAll {
        $script:RepoRootPin = $RepoRoot
        $script:PinProject  = New-TestProject -Base $TestDrive -Name 'doctor-model-pin'
        $script:PinAgents   = Join-Path $script:PinProject '.claude\agents'
        New-Item -ItemType Directory -Force -Path $script:PinAgents | Out-Null

        # Defined here, not in the Describe body: a function declared directly in a Describe block
        # is not in scope inside It. Pester runs BeforeAll in the container scope, so this is.
        function Invoke-PinDoctor {
            Push-Location $script:PinProject
            try {
                $env:MB_HOME = $script:RepoRootPin
                & pwsh -NoLogo -ExecutionPolicy Bypass -File (Join-Path $script:RepoRootPin 'scripts/mb.ps1') doctor 2>&1 | Out-String
            } finally { Pop-Location }
        }
    }

    BeforeEach {
        # security-reviewer is a gate agent and is always well-formed here, so each case below
        # isolates the ONE field under test on `opposition` alone.
        Set-Content -Path (Join-Path $script:PinAgents 'security-reviewer.md') -Encoding utf8 -Value @(
            '---', 'name: security-reviewer', 'model: sonnet', 'description: t', '---', 'body')
    }

    It "stays silent when every review agent pins a capable model" {
        Set-Content -Path (Join-Path $script:PinAgents 'opposition.md') -Encoding utf8 -Value @(
            '---', 'name: opposition', 'model: opus', 'description: t', '---', 'body')
        Invoke-PinDoctor | Should -Not -Match 'not pinned to a capable model'
    }

    # The two mutations. Without these the test above would pass against a DELETED check, which is
    # the defect class standards/CODE-REVIEW.md names: a check that cannot fail is not a check.
    It "WARNs when a review agent declares no model at all" {
        Set-Content -Path (Join-Path $script:PinAgents 'opposition.md') -Encoding utf8 -Value @(
            '---', 'name: opposition', 'description: t', '---', 'body')
        Invoke-PinDoctor | Should -Match 'not pinned to a capable model'
    }

    It "WARNs when a review agent is pinned to the cost-optimized model" {
        Set-Content -Path (Join-Path $script:PinAgents 'opposition.md') -Encoding utf8 -Value @(
            '---', 'name: opposition', 'model: haiku', 'description: t', '---', 'body')
        Invoke-PinDoctor | Should -Match 'not pinned to a capable model'
    }
}

# WHY this exists: 2026-09-11 whole-repo review, finding 2 -- Show-Doctor never set an exit code
# reflecting what it found, so CI's "MB Doctor Self-Check" job (mb.sh only) and any
# PowerShell-only adopter's own doctor run could never fail on a real problem. Fixed by gating
# only on genuinely fatal conditions (see $fatalFound in scripts/mb.ps1); checksum-mismatch and
# the startup-context ceiling stay advisory by design and must NOT flip the exit code. Both
# directions are asserted, not just the fatal one -- a test that only checks the fatal case
# would also pass against a blanket "any [ERROR] -> exit 1" implementation, which is the
# wrong-grained fix this section exists to rule out (mirrors tests/test-mb-doctor.sh check 26).
Describe "Show-Doctor exit code (subprocess)" {
    BeforeAll {
        $script:RepoRootExit = $RepoRoot

        function Invoke-ExitDoctor {
            param([string]$ProjectPath)
            Push-Location $ProjectPath
            try {
                $env:MB_HOME = $script:RepoRootExit
                $out = & pwsh -NoLogo -ExecutionPolicy Bypass -File (Join-Path $script:RepoRootExit 'scripts/mb.ps1') doctor 2>&1 | Out-String
                [PSCustomObject]@{ Output = $out; ExitCode = $LASTEXITCODE }
            } finally {
                Pop-Location
                Remove-Item Env:\MB_HOME -ErrorAction SilentlyContinue
            }
        }
    }

    It "exits non-zero when a fatal condition is present (CLAUDE.md and memory-bank both missing)" {
        $p = New-TestProject -Base $TestDrive -Name 'doctor-exit-fatal'
        $result = Invoke-ExitDoctor -ProjectPath $p
        $result.Output | Should -Match 'CLAUDE\.md missing'
        $result.ExitCode | Should -Be 1
    }

    It "exits 0 when the only finding is the advisory checksum mismatch" {
        $p = New-TestProject -Base $TestDrive -Name 'doctor-exit-checksum'
        $mb = Join-Path $p 'memory-bank'
        New-Item -ItemType Directory -Force -Path $mb | Out-Null
        foreach ($f in @("projectbrief.md", "systemPatterns.md", "techContext.md", "activeContext.md", "progress.md")) {
            Set-Content -Path (Join-Path $mb $f) "---`nauthority: stable`nlast-reviewed: 2026-01-01`n---`n# $f`nContent."
        }
        Set-Content -Path (Join-Path $p 'CLAUDE.md') "# Project`nCLAUDE_AUTOCOMPACT_PCT_OVERRIDE=40"

        Invoke-ExitDoctor -ProjectPath $p | Out-Null   # baseline run establishes checksums
        Add-Content -Path (Join-Path $mb 'progress.md') 'External modification.'

        $result = Invoke-ExitDoctor -ProjectPath $p
        $result.Output | Should -Match 'hash mismatch'
        $result.ExitCode | Should -Be 0
    }
}

# WHY this exists: plain doctor rewrites .pmb-checksums at the end of every run, so the
# pre-push hook (Check 7) re-baselined on every push and erased the mismatch it had just
# reported. `doctor --check` must leave the working tree untouched so the mismatch is still
# reported on the NEXT run -- persistence is the property, not merely "file unchanged", which
# a build skipping the comparison would also satisfy. Mirrors tests/test-mb-doctor.sh check 27.
#
# Both binding forms are exercised because both reach mb.ps1: `-File` (the mb.bat launcher from
# install.bat, which is how the pre-push hook gets here) binds `--check` to the [switch], while
# the call operator (`& mb.ps1 doctor --check`, interactive use) leaves the literal "--check" in
# positional $Arg. The call form runs in a child pwsh here so its host output reaches stdout; the
# hook could not use that form in-process, since Write-Host escapes its `2>&1` capture.
Describe "Show-Doctor --check is read-only (subprocess)" -ForEach @(
    @{ Form = 'file' }
    @{ Form = 'call' }
) {
    BeforeAll {
        $script:RepoRootChk = $RepoRoot

        function Invoke-ChkDoctor {
            param([string]$ProjectPath, [string[]]$DoctorArgs = @())
            Push-Location $ProjectPath
            try {
                $env:MB_HOME = $script:RepoRootChk
                $env:MB_VERSION_CACHE_DIR = Join-Path $TestDrive 'mb-cache'
                $env:MB_VERSION_CHECK_URL = 'http://127.0.0.1:1/VERSION'
                $mbPs1 = Join-Path $script:RepoRootChk 'scripts/mb.ps1'
                if ($Form -eq 'file') {
                    $out = & pwsh -NoLogo -NoProfile -ExecutionPolicy Bypass -File $mbPs1 doctor @DoctorArgs 2>&1 | Out-String
                } else {
                    # Script path and args via the ENVIRONMENT with a single-quoted -Command body,
                    # so a path containing quote characters cannot become executable text.
                    $env:MB_SCRIPT = $mbPs1
                    $env:MB_DOCTOR_ARGS = ($DoctorArgs -join ' ')
                    $out = & pwsh -NoLogo -NoProfile -ExecutionPolicy Bypass -Command `
                        '$a = @($env:MB_DOCTOR_ARGS -split " " | Where-Object { $_ }); & $env:MB_SCRIPT doctor @a; exit $LASTEXITCODE' 2>&1 | Out-String
                }
                [PSCustomObject]@{ Output = $out; ExitCode = $LASTEXITCODE }
            } finally {
                Pop-Location
                foreach ($v in 'MB_HOME', 'MB_VERSION_CACHE_DIR', 'MB_VERSION_CHECK_URL', 'MB_SCRIPT', 'MB_DOCTOR_ARGS') {
                    Remove-Item "Env:\$v" -ErrorAction SilentlyContinue
                }
            }
        }

        function Get-TreeSnapshot {
            param([string]$ProjectPath)
            Get-ChildItem -LiteralPath $ProjectPath -Recurse -File -Force |
                Where-Object { $_.FullName -notmatch '[\\/]\.git([\\/]|$)' } |
                Sort-Object FullName |
                ForEach-Object { "$($_.FullName.Substring($ProjectPath.Length))=$((Get-FileHash -LiteralPath $_.FullName -Algorithm SHA256).Hash)" } |
                Out-String
        }

        function New-ChkProject {
            param([string]$Name)
            $p = New-TestProject -Base $TestDrive -Name $Name
            $mb = Join-Path $p 'memory-bank'
            New-Item -ItemType Directory -Force -Path $mb | Out-Null
            foreach ($f in @("projectbrief.md", "systemPatterns.md", "techContext.md", "activeContext.md", "progress.md")) {
                Set-Content -Path (Join-Path $mb $f) "---`nauthority: stable`nlast-reviewed: 2026-01-01`n---`n# $f`nContent."
            }
            Set-Content -Path (Join-Path $p 'CLAUDE.md') "# Project`nCLAUDE_AUTOCOMPACT_PCT_OVERRIDE=40"
            return $p
        }
    }

    It "reports a mismatch without writing, and still reports it on the next run (<Form>)" {
        $p = New-ChkProject -Name "chk-persist-$Form"
        Invoke-ChkDoctor -ProjectPath $p | Out-Null   # plain doctor establishes the baseline
        Add-Content -Path (Join-Path $p 'memory-bank/progress.md') 'External modification.'

        $before = Get-TreeSnapshot -ProjectPath $p
        $first = Invoke-ChkDoctor -ProjectPath $p -DoctorArgs '--check'
        $after = Get-TreeSnapshot -ProjectPath $p

        # Exit 0 is only observable under -File. Via the call operator a script that ends
        # without `exit` leaves $LASTEXITCODE at whatever native command it ran last (measured:
        # git's 128 in this non-repo fixture), so the host's exit code says nothing about doctor.
        # The fatal case below IS observable in both forms, because mb.ps1 calls `exit 1`.
        if ($Form -eq 'file') { $first.ExitCode | Should -Be 0 }
        $first.Output | Should -Match '\[ERROR\] memory-bank/progress\.md \(hash mismatch'
        $first.Output | Should -Match 'Integrity check mode: \.pmb-checksums not modified'
        $first.Output | Should -Match 'mb verify-integrity'
        $after | Should -BeExactly $before

        $second = Invoke-ChkDoctor -ProjectPath $p -DoctorArgs '--check'
        $second.Output | Should -Match '\[ERROR\] memory-bank/progress\.md \(hash mismatch'
    }

    It "leaves plain doctor's re-baseline and output unchanged (<Form>)" {
        $p = New-ChkProject -Name "chk-plain-$Form"
        Invoke-ChkDoctor -ProjectPath $p | Out-Null
        Add-Content -Path (Join-Path $p 'memory-bank/progress.md') 'External modification.'

        $plain = Invoke-ChkDoctor -ProjectPath $p
        $plain.Output | Should -Not -Match 'Integrity check mode:'
        $after = Invoke-ChkDoctor -ProjectPath $p -DoctorArgs '--check'
        $after.Output | Should -Not -Match 'hash mismatch'
        $after.Output | Should -Match '\[OK\]   Integrity checksums verified'
    }

    It "does not create a missing baseline, and says so as WARN (<Form>)" {
        $p = New-ChkProject -Name "chk-nobase-$Form"
        $result = Invoke-ChkDoctor -ProjectPath $p -DoctorArgs '--check'
        Test-Path -LiteralPath (Join-Path $p '.pmb-checksums') | Should -BeFalse
        $result.Output | Should -Match '\[WARN\] Integrity checksums: no baseline'
        $result.Output | Should -Match 'Integrity check mode: \.pmb-checksums not modified'
    }

    It "keeps doctor's exit code: a fatal condition exits 1 (<Form>)" {
        $p = New-TestProject -Base $TestDrive -Name "chk-fatal-$Form"
        $result = Invoke-ChkDoctor -ProjectPath $p -DoctorArgs '--check'
        $result.Output | Should -Match 'CLAUDE\.md missing'
        $result.ExitCode | Should -Be 1
    }
}

# WHY: mb upgrade force-copied .claude/settings.json, silently deleting an adopter's deny rules
# (signing bypass, --no-verify, PR merges) -- found in the AI-Code-Review-Agent repo's dry run,
# 2026-10-24. Merge-UpgradeSettingsFile is tested in-process (a full upgrade costs about a minute), and
# against the Python merge embedded in mb.sh, which must produce byte-identical files and lines.
Describe "Merge-UpgradeSettingsFile" {
    BeforeAll {
        # WHY captured before dot-sourcing: mb.ps1 resets $script:SjRoot to $env:MB_HOME when set, which
        # can name a different PMB checkout than the one under test.
        $script:SjRoot = Split-Path $PSScriptRoot -Parent
        . (Join-Path $script:SjRoot 'scripts/mb.ps1') -Command help 2>$null
        $script:SjTemplate = Join-Path $script:SjRoot 'templates/.claude/settings.json'
        $script:SjDir = New-TestProject -Base $TestDrive -Name 'settings-merge'
        New-Item -ItemType Directory -Path (Join-Path $script:SjDir '.claude') -Force | Out-Null
        $script:MergeDeny = 'Bash(gh pr ' + 'merge *)'

        # Same fixture as tests/test-mb-upgrade.sh: BOM + CRLF, project rules in every list, a
        # one-element ask list, a non-ASCII rule, keys that must not survive, and flag triggers.
        function New-SjFixture([string]$Path) {
            $s = Get-Content $script:SjTemplate -Raw | ConvertFrom-Json
            $p = $s.permissions
            $p.allow = [object[]](@($p.allow[0..2]) + @('Bash(npm ci)', 'Bash', 'mcp__gh__merge_pull_request', "Bash(echo caf$([char]0xE9))", 'Bash(retired-thing)', 'mcp__x__Merge_PR', 'Bash(*)'))
            $p.deny = [object[]]@($script:MergeDeny)
            $p | Add-Member ask ([object[]]@('Bash(rm *)'))
            $p | Add-Member additionalDirectories ([object[]]@('../shared'))
            $p | Add-Member disableBypassPermissionsMode 'disable'
            $p | Add-Member defaultMode 'acceptEdits'
            $s | Add-Member disableAllHooks $true
            $s | Add-Member apiKeyHelper 'helper.sh'
            $s.env | Add-Member PROJECT_ONLY '1'
            $s.hooks.PSObject.Properties.Remove('Stop')
            $text = (ConvertTo-Json -InputObject $s -Depth 100) -replace "`r?`n", "`r`n"
            [IO.File]::WriteAllText($Path, $text, [Text.UTF8Encoding]::new($true))
        }

        # Runs the Python merge exactly as mb.sh embeds it.
        $mbSh = Get-Content (Join-Path $script:SjRoot 'scripts/mb.sh') -Raw
        $script:PyMerge = Join-Path $TestDrive 'merge.py'
        $m = [regex]::Match($mbSh, "(?s)<<'PYEOF'\r?\n(import json, re, subprocess, sys.*?)\r?\nPYEOF")
        $m.Success | Should -BeTrue
        [IO.File]::WriteAllText($script:PyMerge, $m.Groups[1].Value + "`n")
        # Same interpreter probe as mb.sh: Windows runners may have only one of the two names.
        $script:Py = @('python3', 'python') | Where-Object { & $_ -I -c 'import json' 2>$null; $LASTEXITCODE -eq 0 } | Select-Object -First 1
        $script:Py | Should -Not -BeNullOrEmpty
        # WHY pin UTF-8: the merge prints UTF-8, but PowerShell decodes native output with
        # [Console]::OutputEncoding, a legacy code page when no console is attached.
        [Console]::OutputEncoding = [Text.UTF8Encoding]::new($false)
        function Invoke-PyMerge([string]$Target, [string]$Out, [string]$MbHome) {
            $lines = @(& $script:Py -I $script:PyMerge $script:SjTemplate $Target $Out $MbHome 2>$null)
            return @{ Code = $LASTEXITCODE; Count = [int]$lines[0]; Lines = @($lines | Select-Object -Skip 1) }
        }
    }

    BeforeEach {
        $script:Sj = Join-Path $script:SjDir '.claude/settings.json'
        $script:Out = Join-Path $script:SjDir '.claude/merged.json'
        Remove-Item $script:Out -ErrorAction SilentlyContinue
        New-SjFixture $script:Sj
    }

    It "keeps every project permission rule, drops weakening keys, and names both" {
        $r = Merge-UpgradeSettingsFile -Src $script:SjTemplate -Target $script:Sj -Out $script:Out -MbHome $script:SjRoot
        $r.Code | Should -Be 0
        $r.Count | Should -Be 11
        $m = Get-Content $script:Out -Raw | ConvertFrom-Json
        $t = Get-Content $script:SjTemplate -Raw | ConvertFrom-Json
        $m.permissions.deny | Should -Contain $script:MergeDeny
        foreach ($e in $t.permissions.deny) { $m.permissions.deny | Should -Contain $e }
        foreach ($e in $t.permissions.allow) { $m.permissions.allow | Should -Contain $e }
        $m.permissions.allow | Should -Contain 'Bash(npm ci)'
        $m.permissions.allow | Should -Contain "Bash(echo caf$([char]0xE9))"
        $m.permissions.disableBypassPermissionsMode | Should -Be 'disable'
        $m.permissions.PSObject.Properties.Name | Should -Not -Contain 'defaultMode'
        $m.PSObject.Properties.Name | Should -Not -Contain 'disableAllHooks'
        $m.PSObject.Properties.Name | Should -Not -Contain 'apiKeyHelper'
        (ConvertTo-Json $m.hooks -Depth 100) | Should -BeExactly (ConvertTo-Json $t.hooks -Depth 100)
        (ConvertTo-Json $m.env -Depth 100) | Should -BeExactly (ConvertTo-Json $t.env -Depth 100)
        $raw = Get-Content $script:Out -Raw
        $raw | Should -Match '"ask": \[\s*"Bash\(rm \*\)"\s*\]'
        $raw | Should -Not -Match "`r"
        [IO.File]::ReadAllBytes($script:Out)[0] | Should -Not -Be 0xEF
        $r.Lines | Should -Contain "kept deny: $($script:MergeDeny)"
        $r.Lines | Should -Contain 'dropped top-level key disableAllHooks (not in the template)'
        $r.Lines | Should -Contain 'dropped env.PROJECT_ONLY (not in the template)'
        $r.Lines | Should -Contain "replaced hooks with the template's"
        ($r.Lines -join "`n") | Should -Match 'dropped permissions\.defaultMode'
        ($r.Lines -join "`n") | Should -Match '\[!\] kept allow rule mentions merge .*mcp__gh__merge_pull_request'
        ($r.Lines -join "`n") | Should -Match '\[!\] kept allow rule mentions merge .*mcp__x__Merge_PR'
        ($r.Lines -join "`n") | Should -Not -Match 'mentions merge .*Bash\(gh'
        $r.Lines | Should -Contain '[!] kept allow rule is broad: Bash'
        $r.Lines | Should -Contain '[!] kept allow rule is broad: Bash(*)'
        ($r.Lines -join "`n") | Should -Not -Match 'PMB no longer ships'
    }

    It "leaves a file that is not a JSON object alone (<Name>)" -TestCases @(
        @{ Name = 'number'; Text = '42' }
        @{ Name = 'boolean'; Text = 'true' }
        @{ Name = 'empty'; Text = '' }
        @{ Name = 'empty array'; Text = '[]' }
        @{ Name = 'one-object array'; Text = '[{"permissions": {}}]' }
        @{ Name = 'string'; Text = '"just a string"' }
    ) {
        [IO.File]::WriteAllText($script:Sj, $Text)
        $r = Merge-UpgradeSettingsFile -Src $script:SjTemplate -Target $script:Sj -Out $script:Out -MbHome $script:SjRoot
        $r.Code | Should -Be 2
        $r.Error | Should -Match '^project file is not (valid JSON|a JSON object)'
        Test-Path $script:Out | Should -BeFalse
        $py = Invoke-PyMerge $script:Sj (Join-Path $script:SjDir '.claude/py.json') $script:SjRoot
        $py.Code | Should -Be 2
    }

    It "reports Code 10 and writes nothing when run on its own output" {
        $null = Merge-UpgradeSettingsFile -Src $script:SjTemplate -Target $script:Sj -Out $script:Out -MbHome $script:SjRoot
        Move-Item $script:Out $script:Sj -Force
        $r2 = Merge-UpgradeSettingsFile -Src $script:SjTemplate -Target $script:Sj -Out $script:Out -MbHome $script:SjRoot
        $r2.Code | Should -Be 10
        Test-Path $script:Out | Should -BeFalse
    }

    It "leaves invalid JSON alone with a reason" {
        Set-Content $script:Sj '{ "permissions": { "deny": ["Bash(x)"], }'
        $r = Merge-UpgradeSettingsFile -Src $script:SjTemplate -Target $script:Sj -Out $script:Out -MbHome $script:SjRoot
        $r.Code | Should -Be 2
        $r.Error | Should -Match '^project file is not valid JSON'
        Test-Path $script:Out | Should -BeFalse
    }

    It "flags a rule PMB shipped and later withdrew, with the same lines as the Python merge" {
        $home2 = Join-Path $TestDrive 'pmb-home'
        New-Item -ItemType Directory -Path (Join-Path $home2 'templates/.claude') -Force | Out-Null
        $tf = Join-Path $home2 'templates/.claude/settings.json'
        Push-Location $home2
        try {
            git init -q; git config user.email t@t; git config user.name T; git config commit.gpgsign false
            $old = Get-Content $script:SjTemplate -Raw | ConvertFrom-Json
            $old.permissions.allow = [object[]](@($old.permissions.allow) + 'Bash(retired-thing)')
            Set-Content $tf (ConvertTo-Json $old -Depth 100)
            git add -A; git commit -q -m old
            Copy-Item $script:SjTemplate $tf -Force
            git add -A; git commit -q -m new
        } finally { Pop-Location }
        $r = Merge-UpgradeSettingsFile -Src $script:SjTemplate -Target $script:Sj -Out $script:Out -MbHome $home2
        $r.Lines | Should -Contain '[!] PMB no longer ships this rule; kept -- remove it if unneeded: allow Bash(retired-thing)'
        $py = Invoke-PyMerge $script:Sj (Join-Path $script:SjDir '.claude/py.json') $home2
        ($py.Lines -join "`n") | Should -BeExactly ($r.Lines -join "`n")
    }

    It "matches the Python merge byte for byte (<Name>)" -TestCases @(
        @{ Name = 'fixture'; Edit = $null }
        @{ Name = 'empty lists and object'; Edit = { param($s) $s.permissions.allow = [object[]]@(); $s.permissions | Add-Member ask ([object[]]@()); $s | Add-Member statusLine ([pscustomobject]@{}) } }
        @{ Name = 'one-element allow, non-ASCII and escapes'; Edit = { param($s) $s.permissions.allow = [object[]]@("Bash(caf$([char]0xE9) <&> 'q')") } }
        # The most common real upgrade: a project still on an older template that had no deny list.
        @{ Name = 'older template without deny'; Edit = { param($s) $s.permissions.PSObject.Properties.Remove('deny') } }
    ) {
        if ($Edit) {
            $s = Get-Content $script:SjTemplate -Raw | ConvertFrom-Json
            & $Edit $s
            [IO.File]::WriteAllText($script:Sj, (ConvertTo-Json $s -Depth 100), [Text.UTF8Encoding]::new($false))
        }
        $pyOut = Join-Path $script:SjDir '.claude/py.json'
        Remove-Item $pyOut -ErrorAction SilentlyContinue
        $r = Merge-UpgradeSettingsFile -Src $script:SjTemplate -Target $script:Sj -Out $script:Out -MbHome $script:SjRoot
        $py = Invoke-PyMerge $script:Sj $pyOut $script:SjRoot
        $py.Code | Should -Be $r.Code
        $py.Count | Should -Be $r.Count
        ($py.Lines -join "`n") | Should -BeExactly ($r.Lines -join "`n")
        if ($r.Code -eq 0) {
            (Get-FileHash $pyOut).Hash | Should -Be (Get-FileHash $script:Out).Hash
        }
        if ($Name -eq 'older template without deny') {
            # Nothing project-specific survives, so both runtimes must hand back the template's bytes.
            (Get-FileHash $script:Out).Hash | Should -Be (Get-FileHash $script:SjTemplate).Hash
        }
    }
}

# WHY subprocess: Invoke-Upgrade calls exit and changes location. One project carries the dry run,
# the update and the idempotent re-run, since each run costs about a minute.
Describe "Invoke-Upgrade settings.json merge (subprocess)" {
    It "dry-runs without writing, keeps a project deny rule, then re-runs as unchanged" {
        $proj = New-TestProject -Base $TestDrive -Name 'upgrade-settings'
        $mbScript = Join-Path $RepoRoot 'scripts/mb.ps1'
        $deny = 'Bash(gh pr ' + 'merge *)'
        Push-Location $proj
        try {
            git init -q 2>$null; git config user.email t@t 2>$null; git config user.name T 2>$null
            git commit -q --allow-empty -m init 2>$null
            $env:MB_HOME = $RepoRoot
            & pwsh -NoLogo -ExecutionPolicy Bypass -File $mbScript init 2>&1 | Out-Null
            $sj = Join-Path $proj '.claude/settings.json'
            $s = Get-Content $sj -Raw | ConvertFrom-Json
            $s.permissions.deny = [object[]](@($s.permissions.deny) + $deny)
            $s | Add-Member disableAllHooks $true
            [IO.File]::WriteAllText($sj, (ConvertTo-Json $s -Depth 100), [Text.UTF8Encoding]::new($false))
            $before = (Get-FileHash $sj).Hash

            $dry = (& pwsh -NoLogo -ExecutionPolicy Bypass -File $mbScript upgrade -DryRun 2>&1) -join "`n"
            $dry | Should -Match '\[~\?\] \.claude/settings\.json \(would update, \+\d+/-\d+ lines; keeps 1 project permission rules\)'
            $dry | Should -Match '-\s+"disableAllHooks": true'
            (Get-FileHash $sj).Hash | Should -Be $before

            $out = (& pwsh -NoLogo -ExecutionPolicy Bypass -File $mbScript upgrade 2>&1) -join "`n"
            $out | Should -Match '\[~\] \.claude/settings\.json \(updated; kept 1 project permission rules\)'
            (Get-Content $sj -Raw | ConvertFrom-Json).permissions.deny | Should -Contain $deny

            $again = (& pwsh -NoLogo -ExecutionPolicy Bypass -File $mbScript upgrade 2>&1) -join "`n"
            $again | Should -Match '\[=\] \.claude/settings\.json \(unchanged; keeps 1 project permission rules\)'
        } finally {
            Remove-Item Env:\MB_HOME -ErrorAction SilentlyContinue
            Pop-Location
        }
    }
}
