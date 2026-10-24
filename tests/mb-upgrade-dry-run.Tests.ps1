#Requires -Modules Pester
# tests/mb-upgrade-dry-run.Tests.ps1 -- Pester regression test for `mb upgrade --dry-run` on the
# PowerShell side (mb.sh's `--dry-run` is covered by tests/test-mb-upgrade.sh).
#
# WHY this test exists: the documented spelling `mb upgrade --dry-run` failed both ways a
# PowerShell user reaches mb.ps1. Through the mb.bat launcher (`pwsh -File`) the binder looked
# for a parameter named `dry-run`, found none, and threw before the script body ran -- only
# `-DryRun` worked. Through the call operator (`& mb.ps1 upgrade --dry-run`) the token landed in
# positional $Arg, which Invoke-Upgrade never read, so a requested preview ran a REAL upgrade
# and wrote template files (measured: .claude/, .githooks/, AGENTS.md, ... into the project).
#
# WHY subprocesses, not in-process calls: the bug is in argument binding at the CLI boundary,
# which an in-process function call skips entirely -- same reasoning as the `list --all` test
# in tests/mb-backlog.Tests.ps1. Invoke-Upgrade also calls `exit` and changes location.
#
# WHY the "no files written" assertion: the banner alone proves the switch was seen, but the
# call-operator failure printed no error at all -- only the files it wrote gave it away.

BeforeAll {
    $script:MbScript = Join-Path (Split-Path $PSScriptRoot -Parent) 'scripts/mb.ps1'

    # A bare memory-bank/ satisfies Invoke-Upgrade's project sentinel; anything else that
    # appears afterwards was written by the upgrade.
    function New-DryRunProject {
        $path = Join-Path $TestDrive ([System.Guid]::NewGuid().ToString())
        New-Item -ItemType Directory -Path (Join-Path $path 'memory-bank') -Force | Out-Null
        return $path
    }
}

Describe "mb upgrade dry run (subprocess, real CLI binding)" {
    It "accepts <Spelling> through pwsh -File and writes nothing" -ForEach @(
        @{ Spelling = '--dry-run' }
        @{ Spelling = '-DryRun' }
    ) {
        $project = New-DryRunProject
        Push-Location $project
        try {
            $output = (& pwsh -NoLogo -NoProfile -ExecutionPolicy Bypass -File $script:MbScript upgrade $Spelling 2>&1) -join "`n"
            $output | Should -Not -Match 'A parameter cannot be found'
            $output | Should -Match 'dry run'
            @(Get-ChildItem -LiteralPath $project -Force).Name | Should -Be @('memory-bank')
        } finally {
            Pop-Location
        }
    }

    It "treats --dry-run as a dry run under the call operator, where it binds to positional `$Arg" {
        $project = New-DryRunProject
        Push-Location $project
        try {
            $command = "& '$($script:MbScript -replace "'", "''")' upgrade --dry-run"
            $output = (& pwsh -NoLogo -NoProfile -ExecutionPolicy Bypass -Command $command 2>&1) -join "`n"
            $output | Should -Match 'dry run'
            @(Get-ChildItem -LiteralPath $project -Force).Name | Should -Be @('memory-bank')
        } finally {
            Pop-Location
        }
    }
}
