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
