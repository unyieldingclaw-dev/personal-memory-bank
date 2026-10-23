#Requires -Modules Pester
# Unit tests for scripts/_review-gate-merge.ps1, the PowerShell half of the merge gate.
# tests/test-merge-gate.sh runs the full fixture table through BOTH hook twins end to end; this
# file pins the helper's own contract under CI's Pester job, including the case-exact payload
# lookups that PowerShell's case-insensitive defaults would otherwise break.

BeforeAll {
    $script:RepoRoot = Split-Path $PSScriptRoot -Parent
    . (Join-Path $script:RepoRoot 'scripts/_review-gate-merge.ps1')
    $script:Sha = '0123456789abcdef0123456789abcdef01234567'
    $script:Canon = "gh pr merge 12 -R acme/web.app --squash --match-head-commit $script:Sha"

    function New-MergePayload {
        param([string]$Command = $script:Canon, $Mode = 'default', [hashtable]$Extra = @{}, [hashtable]$ToolExtra = @{})
        $ti = [ordered]@{ command = $Command }
        foreach ($k in $ToolExtra.Keys) { $ti[$k] = $ToolExtra[$k] }
        $p = [ordered]@{ hook_event_name = 'PreToolUse'; tool_name = 'Bash'; tool_input = $ti }
        if ($null -ne $Mode) { $p['permission_mode'] = $Mode }
        foreach ($k in $Extra.Keys) { $p[$k] = $Extra[$k] }
        $p | ConvertTo-Json -Compress -Depth 5
    }
}

Describe '_review-gate-merge.ps1' {
    BeforeEach {
        $script:Proj = Join-Path $TestDrive ([guid]::NewGuid().ToString())
        New-Item -ItemType Directory -Path (Join-Path $script:Proj '.claude') -Force | Out-Null
        '{"repos": ["acme/web.app"]}' | Set-Content (Join-Path $script:Proj '.claude/merge-gate.json')
        $script:SavedConfig = $env:CLAUDE_CONFIG_DIR
        $env:CLAUDE_CONFIG_DIR = Join-Path $TestDrive 'no-user-config'
        $script:SavedRepo = $env:GH_REPO; $script:SavedHost = $env:GH_HOST
        Remove-Item Env:GH_REPO, Env:GH_HOST -ErrorAction SilentlyContinue
    }
    AfterEach {
        $env:CLAUDE_CONFIG_DIR = $script:SavedConfig
        if ($null -ne $script:SavedRepo) { $env:GH_REPO = $script:SavedRepo }
        if ($null -ne $script:SavedHost) { $env:GH_HOST = $script:SavedHost }
    }

    It 'asks for the canonical form and names PR, repo, method and full SHA' {
        $d = Get-ReviewGateMergeDecision -Raw (New-MergePayload) -ProjectDir $script:Proj
        $d.Decision | Should -BeExactly 'ASK'
        $d.Reason | Should -BeLike "Merge PR #12 in acme/web.app by squash, exactly at head $script:Sha.*"
        $d.Audit | Should -BeExactly "default`tacme/web.app`t12`t$script:Sha"
    }

    It 'denies <Name>' -ForEach @(
        @{ Name = 'an uppercase flag (case-exact match)'; Command = $null; Transform = { param($c) $c -creplace '--squash', '--SQUASH' } }
        @{ Name = 'a regex-unescaped repo';               Command = $null; Transform = { param($c) $c -creplace 'web\.app', 'webXapp' } }
        @{ Name = 'a trailing newline';                   Command = $null; Transform = { param($c) "$c`n" } }
        @{ Name = 'a backtick escape';                    Command = $null; Transform = { param($c) "$c ``--admin``" } }
        @{ Name = 'a leading zero';                       Command = $null; Transform = { param($c) $c -creplace ' 12 ', ' 012 ' } }
    ) {
        $cmd = & $Transform $script:Canon
        (Get-ReviewGateMergeDecision -Raw (New-MergePayload -Command $cmd) -ProjectDir $script:Proj).Decision | Should -BeExactly 'DENY'
    }

    It 'treats agent_id as present whatever its value' {
        foreach ($v in @('a1', '', $null)) {
            $raw = New-MergePayload -Extra @{ agent_id = $v }
            (Get-ReviewGateMergeDecision -Raw $raw -ProjectDir $script:Proj).Decision | Should -BeExactly 'DENY'
        }
    }

    It 'reads permission_mode case-exactly' {
        (Get-ReviewGateMergeDecision -Raw (New-MergePayload -Mode 'Auto') -ProjectDir $script:Proj).Decision | Should -BeExactly 'DENY'
        $raw = (New-MergePayload -Mode $null) -replace '"tool_name"', '"Permission_Mode":"default","tool_name"'
        (Get-ReviewGateMergeDecision -Raw $raw -ProjectDir $script:Proj).Decision | Should -BeExactly 'DENY'
    }

    It 'denies with a generic message when a local allow rule can carry a merge' {
        '{"permissions":{"allow":["Bash(gh api *)"]}}' | Set-Content (Join-Path $script:Proj '.claude/settings.local.json')
        $d = Get-ReviewGateMergeDecision -Raw (New-MergePayload) -ProjectDir $script:Proj
        $d.Decision | Should -BeExactly 'DENY'
        $d.Reason | Should -Not -Match 'settings\.local|gh api'
        $d.Cause | Should -Match 'settings\.local\.json'
    }

    It 'still asks when the settings hold a single unrelated allow rule' {
        # Regression: `$x = if (...) { $array }` unrolled a one-element allow list into a bare
        # string, which then failed the is-a-list check and denied every merge.
        '{"permissions":{"allow":["Bash(git *)"]}}' | Set-Content (Join-Path $script:Proj '.claude/settings.local.json')
        (Get-ReviewGateMergeDecision -Raw (New-MergePayload) -ProjectDir $script:Proj).Decision | Should -BeExactly 'ASK'
    }

    It 'classifies allow rule <Rule> as merge-capable = <Expected>' -ForEach @(
        @{ Rule = 'Bash'; Expected = $true }
        @{ Rule = 'Bash(*)'; Expected = $true }
        @{ Rule = 'Bash(gh:*)'; Expected = $true }
        @{ Rule = 'Bash(gh api *)'; Expected = $true }
        @{ Rule = 'Bash(gh -R o/r *)'; Expected = $true }
        @{ Rule = 'Bash(gh pr *)'; Expected = $true }
        @{ Rule = 'PowerShell(gh pr merge:*)'; Expected = $true }
        @{ Rule = "Bash(python3 -c ' *)"; Expected = $true }
        @{ Rule = "Bash(python3 -I -c ' *)"; Expected = $true }
        @{ Rule = 'Bash(node -e *)'; Expected = $true }
        @{ Rule = "Bash(pwsh -NoProfile -NonInteractive -Command ' *)"; Expected = $true }
        @{ Rule = 'Bash(python -m pytest *)'; Expected = $false }
        @{ Rule = 'Bash(git *)'; Expected = $false }
        @{ Rule = 'Bash(gh pr view *)'; Expected = $false }
        @{ Rule = 'Read(*)'; Expected = $false }
    ) {
        Test-MergeGateCapableRule $Rule | Should -Be $Expected
    }

    It 'denies when the allowlist config is missing' {
        Remove-Item (Join-Path $script:Proj '.claude/merge-gate.json')
        (Get-ReviewGateMergeDecision -Raw (New-MergePayload) -ProjectDir $script:Proj).Decision | Should -BeExactly 'DENY'
    }
}
