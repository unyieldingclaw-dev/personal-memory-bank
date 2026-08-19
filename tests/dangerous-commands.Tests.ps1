#Requires -Modules Pester

# WHY subprocess invocation (pwsh -File dangerous-commands.ps1), not dot-sourcing: every
# tier match in the script ends in `exit 0`, and every unrecoverable error path also calls
# `exit 0` or `exit`. Dot-sourced directly into the Pester runspace, any of those `exit`
# calls would terminate the whole test run, not just the one It block -- the exact failure
# mode already documented and fixed for mb.ps1 in tests/mb-backlog.Tests.ps1. The script
# also reads its payload from stdin, not from parameters, so each test pipes a JSON string
# into a fresh subprocess and asserts on its stdout + exit code, mirroring how the real
# PreToolUse hook is actually invoked by Claude Code.
#
# WHY this file exists at all: code review of the git-merge CONFIRM hardening (see
# scripts/dangerous-commands.ps1's confirmPatterns) found that the new regex-based
# dispatch logic -- and the pre-existing JSON-parse-failure fallback -- had zero automated
# coverage on the PowerShell side, only manual ad-hoc verification, despite the repo
# already having Pester wired into CI for other scripts.

BeforeAll {
    $script:RepoRoot = Split-Path $PSScriptRoot -Parent
    $script:HookScript = Join-Path $script:RepoRoot 'scripts/dangerous-commands.ps1'

    function Invoke-DangerousCommandsHook {
        param([string]$Payload)
        $output = $Payload | & pwsh -NoLogo -ExecutionPolicy Bypass -File $script:HookScript 2>&1
        [PSCustomObject]@{
            Output   = ($output -join "`n")
            ExitCode = $LASTEXITCODE
        }
    }
}

Describe "dangerous-commands.ps1 (BLOCK tier)" {
    It "denies a real 'rm -rf' in tool_input.command" {
        $r = Invoke-DangerousCommandsHook '{"tool_name":"Bash","tool_input":{"command":"rm -rf /tmp/some-dir"}}'
        $r.ExitCode | Should -Be 0
        $r.Output | Should -Match '"permissionDecision":"deny"'
        $r.Output | Should -Match "BLOCK:"
    }

    It "does not deny when the trigger phrase is only in tool_input.description" {
        $r = Invoke-DangerousCommandsHook '{"tool_name":"Bash","tool_input":{"command":"echo hello","description":"do not rm -rf anything here"}}'
        $r.Output | Should -Not -Match '"permissionDecision":"deny"'
    }
}

Describe "dangerous-commands.ps1 (CONFIRM tier -- git merge)" {
    It "denies a real 'git merge <branch>' with a CONFIRM message" {
        $r = Invoke-DangerousCommandsHook '{"tool_name":"Bash","tool_input":{"command":"git merge feature/some-branch"}}'
        $r.ExitCode | Should -Be 0
        $r.Output | Should -Match '"permissionDecision":"deny"'
        $r.Output | Should -Match "CONFIRM REQUIRED:"
    }

    It "denies a bare 'git merge' with no branch argument" {
        $r = Invoke-DangerousCommandsHook '{"tool_name":"Bash","tool_input":{"command":"git merge"}}'
        $r.Output | Should -Match '"permissionDecision":"deny"'
    }

    It "does NOT deny 'git merge-base --is-ancestor ...' (trailing-boundary safety)" {
        $r = Invoke-DangerousCommandsHook '{"tool_name":"Bash","tool_input":{"command":"git merge-base --is-ancestor abc123 main"}}'
        $r.Output | Should -Not -Match '"permissionDecision":"deny"'
    }

    It "does NOT deny a command containing 'legit merge' (leading-boundary safety -- regression for the code-review finding)" {
        $r = Invoke-DangerousCommandsHook '{"tool_name":"Bash","tool_input":{"command":"git commit -m \"legit merge of feature A\""}}'
        $r.Output | Should -Not -Match '"permissionDecision":"deny"'
    }

    It "denies 'git merge' preceded by a non-letter (e.g. a semicolon), proving the leading boundary isn't over-strict" {
        $r = Invoke-DangerousCommandsHook '{"tool_name":"Bash","tool_input":{"command":"echo hi; git merge feature/x"}}'
        $r.Output | Should -Match '"permissionDecision":"deny"'
    }

    It "denies 'git merge<TAB>branch' (tab instead of space) -- proves the tab-to-space normalization works, not just a plain-space boundary" {
        $r = Invoke-DangerousCommandsHook '{"tool_name":"Bash","tool_input":{"command":"git merge\tfeature/x"}}'
        $r.Output | Should -Match '"permissionDecision":"deny"'
    }

    It "does NOT deny 'git merge<NBSP>branch' (U+00A0, not a real space) -- regression for the code-review finding that \s treated NBSP as a boundary while bash's [[:space:]] did not" {
        $nbsp = [char]0x00A0
        $payload = '{"tool_name":"Bash","tool_input":{"command":"git merge' + $nbsp + 'feature/x"}}'
        $r = Invoke-DangerousCommandsHook $payload
        $r.Output | Should -Not -Match '"permissionDecision":"deny"'
    }

    It "denies 'GIT merge main' (uppercase executable name) -- this script's -imatch is already case-insensitive; regression proving dangerous-commands.sh's opposition-review case-folding fix keeps the two platforms in parity" {
        $r = Invoke-DangerousCommandsHook '{"tool_name":"Bash","tool_input":{"command":"GIT merge main"}}'
        $r.Output | Should -Match '"permissionDecision":"deny"'
    }
}

Describe "dangerous-commands.ps1 (WARN tier)" {
    It "surfaces a WARNING for id_rsa access without setting permissionDecision" {
        $r = Invoke-DangerousCommandsHook '{"tool_name":"Bash","tool_input":{"command":"cat ~/.ssh/id_rsa"}}'
        $r.ExitCode | Should -Be 0
        $r.Output | Should -Match "WARNING:"
        $r.Output | Should -Not -Match '"permissionDecision":"deny"'
    }
}

Describe "dangerous-commands.ps1 (JSON-parse-failure fallback)" {
    It "falls back to raw-stdin matching and still blocks a real dangerous command in malformed JSON" {
        $r = Invoke-DangerousCommandsHook '{"tool_input":{"command":"rm -rf /tmp/x"'
        $r.ExitCode | Should -Be 0
        $r.Output | Should -Match '"permissionDecision":"deny"'
    }

    It "fails open cleanly on genuinely empty stdin (no crash, no deny)" {
        $r = Invoke-DangerousCommandsHook ''
        $r.ExitCode | Should -Be 0
        $r.Output | Should -Not -Match '"permissionDecision":"deny"'
    }
}
