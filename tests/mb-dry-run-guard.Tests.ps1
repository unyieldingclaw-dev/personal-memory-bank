#Requires -Modules Pester
# tests/mb-dry-run-guard.Tests.ps1 -- Pester regression test for refusing -DryRun / --dry-run on
# every mb.ps1 command except `upgrade` (mb.sh's guard is covered by tests/test-mb-upgrade.sh).
# The rationale lives at the guard in scripts/mb.ps1; this file pins its behaviour.
#
# WHY subprocesses: the flag reaches the script by two different binding routes (the switch under
# `pwsh -File`, a positional slot under the call operator), and an in-process call skips both --
# same reasoning as tests/mb-upgrade-dry-run.Tests.ps1. The guard also calls `exit`.
#
# WHY the "nothing written" assertion: a guard that printed the error after dispatch would still
# pass an output-only check. It discriminates for the writing commands here (init, backlog add);
# for read-only ones the exit code and message carry the check.

BeforeAll {
    $script:MbScript = Join-Path (Split-Path $PSScriptRoot -Parent) 'scripts/mb.ps1'

    function New-GuardProject {
        $path = Join-Path $TestDrive ([System.Guid]::NewGuid().ToString())
        New-Item -ItemType Directory -Path (Join-Path $path 'memory-bank') -Force | Out-Null
        return $path
    }

    # Runs mb.ps1 in a fresh project by the given route and returns output, exit code and what the
    # project contains afterwards.
    function Invoke-MbRoute {
        param([string]$Route, [string[]]$CliArgs)
        $project = New-GuardProject
        Push-Location $project
        try {
            if ($Route -eq 'File') {
                $raw = & pwsh -NoLogo -NoProfile -ExecutionPolicy Bypass -File $script:MbScript @CliArgs 2>&1
            } else {
                $invocation = "& '$($script:MbScript -replace "'", "''")' $($CliArgs -join ' ')"
                $raw = & pwsh -NoLogo -NoProfile -ExecutionPolicy Bypass -Command $invocation 2>&1
            }
            return @{
                Output   = ($raw -join "`n")
                ExitCode = $LASTEXITCODE
                Contents = @(Get-ChildItem -LiteralPath $project -Force).Name
            }
        } finally {
            Pop-Location
        }
    }
}

Describe "mb.ps1 refuses --dry-run outside upgrade (subprocess, real CLI binding)" {
    It "refuses <CliArgs> via <Route> and writes nothing" -ForEach @(
        @{ Route = 'File';     CliArgs = @('init', '--dry-run') }
        @{ Route = 'File';     CliArgs = @('init', '-DryRun') }
        @{ Route = 'File';     CliArgs = @('doctor', '--dry-run') }
        @{ Route = 'File';     CliArgs = @('status', '--dry-run') }
        @{ Route = 'File';     CliArgs = @('help', '--dry-run') }
        @{ Route = 'File';     CliArgs = @('backlog', 'add', 't', '--dry-run') }
        # WHY update is refused here: in mb.ps1 it is only a redirect notice (it never calls
        # Invoke-Upgrade), unlike mb.sh where it is a live upgrade alias and stays exempt.
        @{ Route = 'File';     CliArgs = @('update', '--dry-run') }
        # Under the call operator the token lands in the positional slot it occupies.
        @{ Route = 'Operator'; CliArgs = @('init', '--dry-run') }               # $Arg
        @{ Route = 'Operator'; CliArgs = @('query', '--dry-run') }              # $Arg
        @{ Route = 'Operator'; CliArgs = @('init', '.', '--dry-run') }          # $Arg2
        @{ Route = 'Operator'; CliArgs = @('plan', 'list', '--dry-run') }       # $Arg2
        @{ Route = 'Operator'; CliArgs = @('backlog', 'add', 't', '--dry-run') } # $Arg3
    ) {
        $result = Invoke-MbRoute -Route $Route -CliArgs $CliArgs
        $result.ExitCode | Should -Be 1
        $result.Output | Should -Match "--dry-run is only supported by 'mb upgrade', not 'mb $($CliArgs[0])'"
        $result.Contents | Should -Be @('memory-bank')
    }

    # WHY: the guard reads positional slots that other commands use for real values -- this pins
    # that only the literal flag is refused.
    It "does not refuse an ordinary positional argument via <Route>" -ForEach @(
        @{ Route = 'File' }
        @{ Route = 'Operator' }
    ) {
        $result = Invoke-MbRoute -Route $Route -CliArgs @('query', 'some-keyword')
        $result.ExitCode | Should -Be 0
        $result.Output | Should -Not -Match 'only supported by'
    }
}
