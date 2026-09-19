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

            foreach ($f in @("review-reminders.sh","review-reminders.ps1","review-reminders-post.sh","review-reminders-post.ps1","_review-gate-classify.py","_review-gate-classify.ps1")) {
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
