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
    # WHY the `x` rows: `pwsh -File` is the installed mb.bat route, where the switch binds by name in
    # any position -- this pins that a preview after another argument stays a preview there too.
    It "accepts '<Line>' through pwsh -File and writes nothing" -ForEach @(
        @{ Line = 'upgrade --dry-run' }
        @{ Line = 'upgrade -DryRun' }
        @{ Line = 'upgrade x --dry-run' }
        @{ Line = 'upgrade x -DryRun' }
    ) {
        $project = New-DryRunProject
        Push-Location $project
        try {
            $cliArgs = $Line -split ' '
            $output = (& pwsh -NoLogo -NoProfile -ExecutionPolicy Bypass -File $script:MbScript @cliArgs 2>&1) -join "`n"
            $output | Should -Not -Match 'A parameter cannot be found'
            $output | Should -Match 'dry run'
            @(Get-ChildItem -LiteralPath $project -Force).Name | Should -Be @('memory-bank')
        } finally {
            Pop-Location
        }
    }

    # WHY the later positions: the token lands in whichever positional slot it occupies, and
    # reading only $Arg made `upgrade x --dry-run` run a REAL upgrade (measured).
    It "treats '<Line>' as a dry run under the call operator, where --dry-run binds positionally" -ForEach @(
        @{ Line = 'upgrade --dry-run' }
        @{ Line = 'upgrade x --dry-run' }
        @{ Line = 'upgrade x y --dry-run' }
    ) {
        $project = New-DryRunProject
        Push-Location $project
        try {
            $command = "& '$($script:MbScript -replace "'", "''")' $Line"
            $output = (& pwsh -NoLogo -NoProfile -ExecutionPolicy Bypass -Command $command 2>&1) -join "`n"
            $output | Should -Match 'dry run'
            @(Get-ChildItem -LiteralPath $project -Force).Name | Should -Be @('memory-bank')
        } finally {
            Pop-Location
        }
    }

    # WHY a git fixture: the tests above have no .git, so Invoke-Upgrade's `if (Test-Path ".git")`
    # block -- `git config core.hooksPath` and deleting the old .git/hooks/pre-push shim -- never
    # ran in them. Those two guards were the ones that read the switch's spelling (`$DryRun`)
    # rather than the local, so they were the lines a rename could break unseen.
    It "leaves core.hooksPath and an old .git/hooks/pre-push alone under call-operator --dry-run" {
        $project = New-DryRunProject
        Push-Location $project
        try {
            git init -q 2>$null
            git config core.hooksPath original-hooks
            $oldHook = Join-Path $project '.git/hooks/pre-push'
            New-Item -ItemType Directory -Path (Split-Path $oldHook) -Force | Out-Null
            Set-Content -LiteralPath $oldHook -Value 'exec scripts/pre-push-check.sh'

            $command = "& '$($script:MbScript -replace "'", "''")' upgrade --dry-run"
            $output = (& pwsh -NoLogo -NoProfile -ExecutionPolicy Bypass -Command $command 2>&1) -join "`n"

            # Positive proof the block ran: the would-be messages only print inside it.
            $output | Should -Match 'core\.hooksPath \(would set'
            $output | Should -Match '\.git/hooks/pre-push \(would remove'
            git config core.hooksPath | Should -Be 'original-hooks'
            Test-Path -LiteralPath $oldHook | Should -Be $true
            @(Get-ChildItem -LiteralPath $project -Force).Name | Sort-Object | Should -Be @('.git', 'memory-bank')
        } finally {
            Pop-Location
        }
    }

    # WHY a positive control: every case above asserts "nothing written", which a flag that was
    # always on would also satisfy. A plain upgrade must still really write.
    It "still runs a real upgrade for '<Line>' with no --dry-run" -ForEach @(
        @{ Line = 'upgrade' }
        @{ Line = 'upgrade x' }
    ) {
        $project = New-DryRunProject
        Push-Location $project
        $savedCache = $env:MB_VERSION_CACHE_DIR; $savedUrl = $env:MB_VERSION_CHECK_URL
        try {
            # Keep the version check off the network and out of the real ~/.mb cache.
            $env:MB_VERSION_CACHE_DIR = Join-Path $TestDrive 'mb-cache'
            $env:MB_VERSION_CHECK_URL = 'http://127.0.0.1:9/VERSION'
            $cliArgs = $Line -split ' '
            $output = (& pwsh -NoLogo -NoProfile -ExecutionPolicy Bypass -File $script:MbScript @cliArgs 2>&1) -join "`n"
            $output | Should -Not -Match 'dry run'
            Test-Path -LiteralPath (Join-Path $project '.pmb-version') | Should -Be $true
        } finally {
            $env:MB_VERSION_CACHE_DIR = $savedCache; $env:MB_VERSION_CHECK_URL = $savedUrl
            Pop-Location
        }
    }
}
