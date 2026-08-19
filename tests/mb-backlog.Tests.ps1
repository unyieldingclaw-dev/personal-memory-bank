#Requires -Modules Pester
# tests/mb-backlog.Tests.ps1 -- Pester regression test for the mb backlog command
# family on the PowerShell side (mb.sh already has tests/test-mb-backlog.sh).
#
# WHY this test exists: mb.ps1 had no `backlog` command at all -- ValidateSet didn't
# even list it, so `mb.ps1 backlog add ...` threw a parameter-validation error before
# any script body ran. This proves the ported PowerShell implementation behaves the
# same as the bash original: slug generation/collision, default list excludes
# promoted/dismissed, promote seeds a .claude/plans/ stub without touching
# docs/plans/, dismiss/promote never delete the backlog file, and the same
# malformed-frontmatter/slug-validation guards apply. See
# docs/superpowers/specs/2026-07-14-backlog-design.md.
#
# Reconciliation (mb plan promote picking up a backlog-sourced stub) is already
# covered by tests/mb-plan-promote.Tests.ps1 -- not duplicated here.
#
# WHY error-path tests use a subprocess (pwsh -File mb.ps1 ...), not a direct
# in-process function call: every error path in the ported functions (Invoke-BacklogAdd,
# Resolve-BacklogSlug, Invoke-BacklogPromote) calls `exit 1`. Dot-sourced directly into
# the Pester runspace, that `exit` terminates the whole test run, not just the one
# test -- the same reasoning tests/mb-setup.Tests.ps1 already documents for
# Invoke-Init/Invoke-Upgrade. Happy-path tests call the functions in-process (faster,
# matches tests/mb-plan-promote.Tests.ps1's style) since they never hit an exit path.

BeforeAll {
    $RepoRoot = Split-Path $PSScriptRoot -Parent
    . (Join-Path $RepoRoot 'scripts/mb.ps1') -Command help 2>$null
    $script:MbScript = Join-Path $RepoRoot 'scripts/mb.ps1'
}

Describe "mb backlog command family (in-process happy paths)" {
    BeforeEach {
        $script:ProjectPath = Join-Path $TestDrive ([System.Guid]::NewGuid().ToString())
        New-Item -ItemType Directory -Path $script:ProjectPath -Force | Out-Null
        Push-Location $script:ProjectPath
        New-Item -ItemType Directory -Path "docs/backlog", ".claude/plans" -Force | Out-Null
    }

    AfterEach {
        Pop-Location
    }

    It "add: creates docs/backlog/<slug>.md with correct frontmatter" {
        Invoke-BacklogAdd -Title "Investigate Foo Bar" -Desc "A short description"

        Test-Path "docs/backlog/investigate-foo-bar.md" | Should -Be $true
        $Content = Get-Content "docs/backlog/investigate-foo-bar.md" -Raw
        $Content | Should -Match "status: open"
        $Content | Should -Match "staleness-threshold: 90d"
        $Content | Should -Match "related_plan: null"
        $Content | Should -Match "# Investigate Foo Bar"
        $Content | Should -Match "A short description"
    }

    It "add: slug collision appends -2" {
        Invoke-BacklogAdd -Title "Same Title"
        Invoke-BacklogAdd -Title "Same Title"

        Test-Path "docs/backlog/same-title.md" | Should -Be $true
        Test-Path "docs/backlog/same-title-2.md" | Should -Be $true
    }

    It "list: shows open items only by default, --all includes dismissed" {
        Invoke-BacklogAdd -Title "Open Item"
        Invoke-BacklogAdd -Title "Dismissed Item"
        Invoke-BacklogDismiss -Slug "dismissed-item"

        # WHY 6>&1 not a plain pipe: Show-BacklogList uses Write-Host (matching this
        # file's existing Show-PlanList convention), which writes to the Information
        # stream (6), not the success/output stream a plain pipe captures.
        $DefaultOutput = (Show-BacklogList 6>&1) | Out-String
        $DefaultOutput | Should -Match "open-item"
        $DefaultOutput | Should -Not -Match "dismissed-item"

        $AllOutput = (Show-BacklogList -All 6>&1) | Out-String
        $AllOutput | Should -Match "dismissed-item"
    }

    It "show: prints the item's content" {
        Invoke-BacklogAdd -Title "Showable Item" -Desc "Detail text here"

        $Output = Show-BacklogItem -Slug "showable-item" | Out-String
        $Output | Should -Match "Detail text here"
    }

    It "dismiss: sets status: dismissed, file is kept" {
        Invoke-BacklogAdd -Title "To Dismiss"
        Invoke-BacklogDismiss -Slug "to-dismiss"

        Test-Path "docs/backlog/to-dismiss.md" | Should -Be $true
        (Get-Content "docs/backlog/to-dismiss.md" -Raw) | Should -Match "status: dismissed"
    }

    It "promote: seeds a plan stub in .claude/plans/, updates backlog frontmatter, does not touch docs/plans/" {
        Invoke-BacklogAdd -Title "Worth Planning" -Desc "Needs a real plan"

        Invoke-BacklogPromote -Slug "worth-planning"

        $Stubs = Get-ChildItem ".claude/plans" -Filter "*worth-planning*" -ErrorAction SilentlyContinue
        $Stubs.Count | Should -Be 1
        $Content = Get-Content "docs/backlog/worth-planning.md" -Raw
        $Content | Should -Match "status: promoted"
        $Content | Should -Not -Match "related_plan: null"
        (Test-Path "docs/plans") | Should -Be $false
    }

    It "promote: preserves a literal '---' inside the body" {
        Invoke-BacklogAdd -Title "Has A Rule"
        Add-Content "docs/backlog/has-a-rule.md" @"

Above the rule.
---
Below the rule.
"@
        Invoke-BacklogPromote -Slug "has-a-rule"

        $Stub = (Get-ChildItem ".claude/plans" -Filter "*has-a-rule*").FullName
        $StubContent = Get-Content $Stub -Raw
        $StubContent | Should -Match "Above the rule\."
        $StubContent | Should -Match "(?m)^---$"
        $StubContent | Should -Match "Below the rule\."
    }
}

Describe "mb backlog command family (subprocess CLI paths)" {
    BeforeEach {
        $script:ProjectPath = New-Item -ItemType Directory -Path (Join-Path $TestDrive ([System.Guid]::NewGuid().ToString())) -Force
        Push-Location $script:ProjectPath
        New-Item -ItemType Directory -Path "docs/backlog", ".claude/plans" -Force | Out-Null
        $env:MB_HOME = $RepoRoot
    }

    AfterEach {
        Remove-Item Env:\MB_HOME -ErrorAction SilentlyContinue
        Pop-Location
    }

    # WHY this test exists: "mb backlog list --all" bypassed the parameter binder
    # entirely when tested via a direct in-process Show-BacklogList call (the "in-
    # process happy paths" Describe block above), which is how a real Correctness bug
    # was missed initially -- PowerShell's binder intercepts a bare "--all" token as an
    # attempted named-parameter bind before the script body runs at all, regardless of
    # quoting, exactly the same reasoning $DryRun documents for "--dry-run". Only a
    # real subprocess invocation exercises the actual CLI argument-parsing boundary.
    It "list --all: works via the real CLI invocation, not just in-process" {
        & pwsh -NoLogo -ExecutionPolicy Bypass -File $script:MbScript backlog add "Open Item" 2>&1 | Out-Null
        & pwsh -NoLogo -ExecutionPolicy Bypass -File $script:MbScript backlog add "Dismissed Item" 2>&1 | Out-Null
        & pwsh -NoLogo -ExecutionPolicy Bypass -File $script:MbScript backlog dismiss "dismissed-item" 2>&1 | Out-Null

        $Output = (& pwsh -NoLogo -ExecutionPolicy Bypass -File $script:MbScript backlog list --all 2>&1) -join "`n"

        $LASTEXITCODE | Should -Be 0
        $Output | Should -Match "dismissed-item"
    }

    It "add: rejects a title with no alphanumeric characters" {
        $Output = (& pwsh -NoLogo -ExecutionPolicy Bypass -File $script:MbScript backlog add "!!! ??? ###" 2>&1) -join "`n"

        $LASTEXITCODE | Should -Be 1
        $Output | Should -Match "at least one letter or number"
        Test-Path "docs/backlog/.md" | Should -Be $false
    }

    It "show: unknown slug errors clearly" {
        $Output = (& pwsh -NoLogo -ExecutionPolicy Bypass -File $script:MbScript backlog show "nonexistent-slug" 2>&1) -join "`n"

        $LASTEXITCODE | Should -Be 1
        $Output | Should -Match "not found"
    }

    It "promote: refuses a backlog item with malformed frontmatter (no fences)" {
        Set-Content "docs/backlog/no-fences.md" @"
status: open
# No Frontmatter Fences
"@
        $Output = (& pwsh -NoLogo -ExecutionPolicy Bypass -File $script:MbScript backlog promote "no-fences" 2>&1) -join "`n"

        $LASTEXITCODE | Should -Be 1
        $Output | Should -Match "malformed frontmatter"
        Get-ChildItem ".claude/plans" -Filter "*no-fences*" -ErrorAction SilentlyContinue | Should -BeNullOrEmpty
        (Get-Content "docs/backlog/no-fences.md" -Raw) | Should -Not -Match "status: promoted"
    }

    It "promote: refuses a backlog item with fences but no status: field" {
        Set-Content "docs/backlog/no-status.md" @"
---
created: 2026-08-16
related_plan: null
---

# No Status Field
"@
        $Output = (& pwsh -NoLogo -ExecutionPolicy Bypass -File $script:MbScript backlog promote "no-status" 2>&1) -join "`n"

        $LASTEXITCODE | Should -Be 1
        $Output | Should -Match "missing 'status:' field"
        Test-Path ".claude/plans/*no-status*" | Should -Be $false
    }

    It "promote: refuses a backlog item with content before the frontmatter fence" {
        Set-Content "docs/backlog/preamble.md" @"
Some notes I jotted before I understood the format.
---
status: open
---
More notes.
"@
        $Output = (& pwsh -NoLogo -ExecutionPolicy Bypass -File $script:MbScript backlog promote "preamble" 2>&1) -join "`n"

        $LASTEXITCODE | Should -Be 1
        $Output | Should -Match "must start with"
        Test-Path ".claude/plans/*preamble*" | Should -Be $false
    }

    # WHY this also proves a genuine single-line "---" file is diagnosed correctly:
    # regression test for a Get-Content scalar-vs-array bug where a single-line file
    # made [0] index into the first *character* instead of the line, misreporting
    # "must start with '---'" for a file that already starts with it.
    It "promote: a single-line '---' file is diagnosed as missing delimiters, not as missing the opening fence" {
        Set-Content "docs/backlog/singleline.md" "---" -NoNewline

        $Output = (& pwsh -NoLogo -ExecutionPolicy Bypass -File $script:MbScript backlog promote "singleline" 2>&1) -join "`n"

        $LASTEXITCODE | Should -Be 1
        $Output | Should -Match "expected two '---' delimiters"
        $Output | Should -Not -Match "must start with"
    }

    It "promote: refuses to re-promote an item that isn't status: open" {
        & pwsh -NoLogo -ExecutionPolicy Bypass -File $script:MbScript backlog add "Repromote Me" "Needs a real plan" 2>&1 | Out-Null
        & pwsh -NoLogo -ExecutionPolicy Bypass -File $script:MbScript backlog promote "repromote-me" 2>&1 | Out-Null
        $Stub = (Get-ChildItem ".claude/plans" -Filter "*repromote-me*").FullName
        Add-Content $Stub "HAND-EDITED CONTENT THAT MUST SURVIVE"

        $Output = (& pwsh -NoLogo -ExecutionPolicy Bypass -File $script:MbScript backlog promote "repromote-me" 2>&1) -join "`n"

        $LASTEXITCODE | Should -Be 1
        $Output | Should -Match "Cannot promote"
        (Get-Content $Stub -Raw) | Should -Match "HAND-EDITED CONTENT THAT MUST SURVIVE"
    }

    It "slug validation: rejects a path-traversal slug and does not leak a file outside docs/backlog/" {
        # WHY two ".." segments land on $ProjectPath, not $ParentDir: the slug is
        # appended as docs/backlog/<slug>.md, so escaping back to the project root
        # (two directories up from docs/backlog/) requires exactly two ".." segments.
        # The decoy is planted at the project root so a real leak (were validation
        # absent) would actually reach it -- not one level higher, which no path this
        # code ever builds could reach anyway.
        Set-Content (Join-Path $script:ProjectPath.FullName "secret.md") "TOP SECRET"

        $Output = (& pwsh -NoLogo -ExecutionPolicy Bypass -File $script:MbScript backlog show "../../secret" 2>&1) -join "`n"

        $LASTEXITCODE | Should -Be 1
        $Output | Should -Match "Invalid slug"
        $Output | Should -Not -Match "TOP SECRET"
    }

    It "slug validation: rejects a slug containing characters outside [a-z0-9-]" {
        $Output = (& pwsh -NoLogo -ExecutionPolicy Bypass -File $script:MbScript backlog promote 'evil#w /tmp/pwned' 2>&1) -join "`n"

        $LASTEXITCODE | Should -Be 1
        $Output | Should -Match "Invalid slug"
    }
}
