#Requires -Modules Pester
# tests/mb-plan-promote.Tests.ps1 -- Pester regression test for Invoke-PlanPromote's
# related_plan reconciliation (mb.ps1 side of the fix in scripts/mb.sh).
#
# WHY this test exists: mb backlog promote (mb.sh only, as of this fix -- mb.ps1's
# backlog port is separate follow-up work) stamps a
# "<!-- pmb-backlog-source: <slug> -->" line into the stub body it seeds.
# Invoke-PlanPromote reads that marker to find the originating backlog item by
# identity (not by path) and rewrite its related_plan to the plan's durable
# docs/plans/ destination. See
# docs/superpowers/specs/2026-07-14-backlog-design.md "Plan-lifecycle reconciliation".
# These tests seed docs/backlog/*.md and the draft file by hand (mb.ps1 has no
# `backlog` command yet) to prove Invoke-PlanPromote's reconciliation logic itself is
# correct, independent of whichever shell created the backlog file.

BeforeAll {
    $RepoRoot = Split-Path $PSScriptRoot -Parent
    . (Join-Path $RepoRoot 'scripts/mb.ps1') -Command help 2>$null
}

Describe "Invoke-PlanPromote related_plan reconciliation" {
    BeforeEach {
        $script:ProjectPath = Join-Path $TestDrive ([System.Guid]::NewGuid().ToString())
        New-Item -ItemType Directory -Path $script:ProjectPath -Force | Out-Null
        Push-Location $script:ProjectPath
        New-Item -ItemType Directory -Path "docs/backlog", ".claude/plans" -Force | Out-Null
    }

    AfterEach {
        Pop-Location
    }

    It "rewrites related_plan to the docs/plans/ destination via the backlog-source marker" {
        $stub = ".claude/plans/2026-08-16-reconcile-me.md"
        Set-Content "docs/backlog/reconcile-me.md" @"
---
status: promoted
created: 2026-08-16
last-reviewed: 2026-08-16
staleness-threshold: 90d
related_plan: $stub
---

# Reconcile Me
"@
        Set-Content $stub "---`nstatus: draft`n---`n`n# Reconcile Me plan`n`n<!-- pmb-backlog-source: reconcile-me -->`n"

        Invoke-PlanPromote -Draft $stub

        $backlogContent = Get-Content "docs/backlog/reconcile-me.md" -Raw
        $backlogContent | Should -Match "related_plan: docs/plans/2026-08-16-reconcile-me\.md"
        $backlogContent | Should -Not -Match "related_plan: \.claude/plans/"
        Test-Path "docs/plans/2026-08-16-reconcile-me.md" | Should -Be $true
    }

    It "reconciles even when the draft was renamed after mb backlog promote" {
        # WHY this test exists: matching by exact draft path (the original design)
        # broke the moment the user renamed the stub while fleshing it out with
        # superpowers:writing-plans -- exactly the workflow the spec's own
        # "Plan-lifecycle reconciliation" section describes as the reason this
        # feature exists. The marker travels with the file's content, so it
        # survives the rename even though the path no longer matches anything.
        Set-Content "docs/backlog/rename-scenario.md" @"
---
status: promoted
created: 2026-08-16
last-reviewed: 2026-08-16
staleness-threshold: 90d
related_plan: .claude/plans/2026-08-16-rename-scenario.md
---

# Rename Scenario
"@
        Set-Content ".claude/plans/2026-08-16-rename-scenario.md" "---`nstatus: draft`n---`n`n# Rename Scenario plan`n`n<!-- pmb-backlog-source: rename-scenario -->`n"
        Rename-Item ".claude/plans/2026-08-16-rename-scenario.md" "renamed-during-writing-plans.md"

        Invoke-PlanPromote -Draft ".claude/plans/renamed-during-writing-plans.md"

        $backlogContent = Get-Content "docs/backlog/rename-scenario.md" -Raw
        $backlogContent | Should -Match "related_plan: docs/plans/renamed-during-writing-plans\.md"
    }

    It "reconciles even when content was appended after the marker" {
        # WHY this test exists: an earlier design required the marker to be the
        # file's last non-blank line, which broke as soon as the user added any
        # content after it -- exactly what "flesh it out with
        # superpowers:writing-plans" instructs them to do. The HTML-comment
        # format doesn't depend on position, so this must keep working
        # regardless of where the marker ends up.
        Set-Content "docs/backlog/appended-after.md" @"
---
status: promoted
created: 2026-08-16
last-reviewed: 2026-08-16
staleness-threshold: 90d
related_plan: .claude/plans/2026-08-16-appended-after.md
---

# Appended After
"@
        Set-Content ".claude/plans/2026-08-16-appended-after.md" "---`nstatus: draft`n---`n`n# Appended After plan`n`n<!-- pmb-backlog-source: appended-after -->`n`n## Implementation Steps`n1. Do the thing.`n2. Ship it.`n"

        Invoke-PlanPromote -Draft ".claude/plans/2026-08-16-appended-after.md"

        $backlogContent = Get-Content "docs/backlog/appended-after.md" -Raw
        $backlogContent | Should -Match "related_plan: docs/plans/2026-08-16-appended-after\.md"
    }

    It "ignores a decoy mention of the marker format in prose" {
        # WHY this test exists: an earlier design used a plain "(Backlog
        # source: x)" line, which reads as natural English prose -- a plan
        # document that discusses this exact feature (plausible in this very
        # repo) could contain that string without it being a genuine marker,
        # causing reconciliation to corrupt an unrelated backlog item that
        # happens to share the mentioned slug. Regression test for the
        # HTML-comment marker format, which nothing writes by coincidence.
        Set-Content "docs/backlog/unrelated-item.md" @"
---
status: open
created: 2026-08-16
last-reviewed: 2026-08-16
staleness-threshold: 90d
related_plan: null
---

# Unrelated Item
"@
        Set-Content "discussing-the-feature.md" "---`nstatus: draft`n---`n`n# Discussing The Backlog Feature`n`nThis plan explains the marker format, e.g. (Backlog source: unrelated-item), used by mb backlog promote to identify the originating item.`n"

        Invoke-PlanPromote -Draft "discussing-the-feature.md"

        $backlogContent = Get-Content "docs/backlog/unrelated-item.md" -Raw
        $backlogContent | Should -Match "related_plan: null"
    }

    It "reconciles correctly when the destination filename contains regex replacement tokens" {
        # WHY this test exists: the reconciliation code used to interpolate $Dest
        # directly into a -replace replacement string. PowerShell's -replace
        # treats $1/$&/$$/etc. in the replacement as regex backreference tokens --
        # a destination filename containing '$&' corrupted/duplicated the
        # related_plan line instead of being written literally. Regression test
        # for the fix (plain string interpolation, no replacement-string parsing).
        Set-Content "docs/backlog/token-path.md" @"
---
status: promoted
created: 2026-08-16
last-reviewed: 2026-08-16
staleness-threshold: 90d
related_plan: .claude/plans/2026-08-16-token-path.md
---

# Token Path
"@
        Set-Content 'cost-$&-report.md' "---`nstatus: draft`n---`n`n# Token Path plan`n`n<!-- pmb-backlog-source: token-path -->`n"

        Invoke-PlanPromote -Draft 'cost-$&-report.md'

        $backlogContent = Get-Content "docs/backlog/token-path.md" -Raw
        $backlogContent | Should -Match ([regex]::Escape('related_plan: docs/plans/cost-$&-report.md'))
    }

    It "only touches the backlog item named by the marker, not other backlog items" {
        Set-Content "docs/backlog/named-item.md" @"
---
status: promoted
created: 2026-08-16
last-reviewed: 2026-08-16
staleness-threshold: 90d
related_plan: .claude/plans/2026-08-16-named-item.md
---

# Named Item
"@
        Set-Content "docs/backlog/other-item.md" @"
---
status: open
created: 2026-08-16
last-reviewed: 2026-08-16
staleness-threshold: 90d
related_plan: null
---

# Other Item
"@
        Set-Content ".claude/plans/2026-08-16-named-item.md" "---`nstatus: draft`n---`n`n# Named Item plan`n`n<!-- pmb-backlog-source: named-item -->`n"

        Invoke-PlanPromote -Draft ".claude/plans/2026-08-16-named-item.md"

        (Get-Content "docs/backlog/named-item.md" -Raw) | Should -Match "related_plan: docs/plans/2026-08-16-named-item\.md"
        (Get-Content "docs/backlog/other-item.md" -Raw) | Should -Match "related_plan: null"
    }

    It "still promotes normally when the draft has no backlog-source marker" {
        $stub = ".claude/plans/2026-08-16-no-backlog.md"
        Set-Content $stub "---`nstatus: draft`n---`n`n# No Backlog Link`n"

        Invoke-PlanPromote -Draft $stub

        Test-Path "docs/plans/2026-08-16-no-backlog.md" | Should -Be $true
    }
}

# WHY: standards/WORKFLOW.md Phase 3 says promote COPIES the draft and sets `status: planned`
# unless a later status is set. Before [NS-19] Invoke-PlanPromote rewrote every line matching
# '^status: draft' (body included), left a frontmatter without a status key unset, and printed no
# status outcome. Mirrors tests/test-mb-plan.sh's frontmatter-scoped cases.
Describe "Invoke-PlanPromote status handling is scoped to the frontmatter" {
    BeforeEach {
        $script:ProjectPath = Join-Path $TestDrive ([System.Guid]::NewGuid().ToString())
        New-Item -ItemType Directory -Path $script:ProjectPath -Force | Out-Null
        Push-Location $script:ProjectPath
        New-Item -ItemType Directory -Path ".claude/plans" -Force | Out-Null
        # Frontmatter lines only (between the opening fence and the first closing fence).
        function script:Get-Fm([string]$Path) {
            $lines = (Get-Content $Path -Raw) -split "`r?`n"
            $close = 1..($lines.Count - 1) | Where-Object { $lines[$_].TrimEnd() -eq '---' } | Select-Object -First 1
            if ($close) { $lines[1..($close - 1)] } else { @() }
        }
    }

    AfterEach {
        Pop-Location
    }

    It "turns draft into planned without touching a body line that starts 'status: draft'" {
        $stub = ".claude/plans/2099-02-01-draft.md"
        Set-Content $stub "---`nstatus: draft`n---`n`n# Body`nstatus: draft is how this line starts`n" -NoNewline
        Invoke-PlanPromote -Draft $stub
        @(Get-Fm "docs/plans/2099-02-01-draft.md" | Where-Object { $_ -eq 'status: planned' }).Count | Should -Be 1
        (Get-Content "docs/plans/2099-02-01-draft.md") -contains 'status: draft is how this line starts' | Should -Be $true
        Test-Path $stub | Should -Be $true
    }

    It "adds status: planned when the frontmatter has no status key, and says so" {
        $stub = ".claude/plans/2099-02-02-nokey.md"
        Set-Content $stub "---`ncreated: 2099-01-01`n---`n`n# No status key`n" -NoNewline
        $out = Invoke-PlanPromote -Draft $stub 6>&1 | Out-String
        @(Get-Fm "docs/plans/2099-02-02-nokey.md" | Where-Object { $_ -eq 'status: planned' }).Count | Should -Be 1
        $out | Should -Match 'status: planned added'
    }

    It "turns an empty status: into planned" {
        $stub = ".claude/plans/2099-02-03-empty.md"
        Set-Content $stub "---`nstatus:`n---`n`n# Empty`n" -NoNewline
        Invoke-PlanPromote -Draft $stub
        @(Get-Fm "docs/plans/2099-02-03-empty.md" | Where-Object { $_ -eq 'status: planned' }).Count | Should -Be 1
    }

    It "keeps a later status and reports it as preserved" {
        $stub = ".claude/plans/2099-02-05-later.md"
        Set-Content $stub "---`nstatus: active`n---`n`n# Later`n" -NoNewline
        $out = Invoke-PlanPromote -Draft $stub 6>&1 | Out-String
        @(Get-Fm "docs/plans/2099-02-05-later.md" | Where-Object { $_ -eq 'status: active' }).Count | Should -Be 1
        $out | Should -Match 'preserved'
    }

    It "treats a leading --- with no closing fence as having no frontmatter" {
        $stub = ".claude/plans/2099-02-06-rule.md"
        Set-Content $stub "---`n`n# Starts with a rule, no closing fence`n" -NoNewline
        Invoke-PlanPromote -Draft $stub
        @(Get-Fm "docs/plans/2099-02-06-rule.md" | Where-Object { $_ -eq 'status: planned' }).Count | Should -Be 1
        (Get-Content "docs/plans/2099-02-06-rule.md") -contains '# Starts with a rule, no closing fence' | Should -Be $true
    }

    It "keeps a CRLF draft CRLF on every line" {
        $stub = ".claude/plans/2099-02-07-crlf.md"
        [System.IO.File]::WriteAllText((Join-Path $PWD $stub), "---`r`ncreated: 2099-01-01`r`n---`r`n`r`n# CRLF`r`n")
        Invoke-PlanPromote -Draft $stub
        $raw = [System.IO.File]::ReadAllText((Join-Path $PWD "docs/plans/2099-02-07-crlf.md"))
        @(Get-Fm "docs/plans/2099-02-07-crlf.md" | Where-Object { $_ -eq 'status: planned' }).Count | Should -Be 1
        ($raw -replace "`r`n", '') -match "`n" | Should -Be $false
    }

    # Both runtimes: the key is case-sensitive (YAML), the draft value is not.
    It "treats an uppercase DRAFT value as draft" {
        $stub = ".claude/plans/2099-02-08-upper.md"
        Set-Content $stub "---`nstatus: DRAFT`n---`n`n# Upper`n" -NoNewline
        Invoke-PlanPromote -Draft $stub
        @(Get-Fm "docs/plans/2099-02-08-upper.md" | Where-Object { $_ -eq 'status: planned' }).Count | Should -Be 1
    }

    It "does not treat a capitalised Status: key as the status key" {
        $stub = ".claude/plans/2099-02-09-keycase.md"
        Set-Content $stub "---`nStatus: active`n---`n`n# Key case`n" -NoNewline
        Invoke-PlanPromote -Draft $stub
        @(Get-Fm "docs/plans/2099-02-09-keycase.md" | Where-Object { $_ -ceq 'status: planned' }).Count | Should -Be 1
    }
}
