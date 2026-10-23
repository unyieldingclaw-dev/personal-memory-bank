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
        $script:SavedRepo = $env:GH_REPO; $script:SavedHost = $env:GH_HOST; $script:SavedGhConfig = $env:GH_CONFIG_DIR
        Remove-Item Env:GH_REPO, Env:GH_HOST, Env:GH_CONFIG_DIR -ErrorAction SilentlyContinue
    }
    AfterEach {
        $env:CLAUDE_CONFIG_DIR = $script:SavedConfig
        if ($null -ne $script:SavedRepo) { $env:GH_REPO = $script:SavedRepo }
        if ($null -ne $script:SavedHost) { $env:GH_HOST = $script:SavedHost }
        if ($null -ne $script:SavedGhConfig) { $env:GH_CONFIG_DIR = $script:SavedGhConfig } else { Remove-Item Env:GH_CONFIG_DIR -ErrorAction SilentlyContinue }
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

    It 'compares keys and values ordinally, so an ignorable character makes them differ' {
        # -ceq and -ccontains are culture-aware and compared each of these equal (2026-10-23).
        $zw = [string][char]0x200b
        (Get-MergeGateProperty ('{"a' + $zw + '": 1, "a": 2}' | ConvertFrom-Json) 'a').Value | Should -Be 2
        Test-MergeGateCapableRule ('Bash(*' + $zw + ')') | Should -Be $false
        (Get-ReviewGateMergeDecision -Raw (New-MergePayload -Mode ('default' + $zw)) -ProjectDir $script:Proj).Decision | Should -BeExactly 'DENY'
        $raw = New-MergePayload -ToolExtra @{ description = 'Merge pull request (verify the details in the hook reason)' + $zw }
        (Get-ReviewGateMergeDecision -Raw $raw -ProjectDir $script:Proj).Decision | Should -BeExactly 'DENY'
        ('{"permissions' + $zw + '":{"allow":[]},"permissions":{"allow":["Bash(*)"]}}') | Set-Content (Join-Path $script:Proj '.claude/settings.local.json')
        (Get-ReviewGateMergeDecision -Raw (New-MergePayload) -ProjectDir $script:Proj).Decision | Should -BeExactly 'DENY'
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

    It 'matches allow rule <Rule> against the asked command, not only the probes: <Expected>' -ForEach @(
        # The probes use PR 1 and a zero SHA; the asked command is #12 at a SHA ending in 7.
        @{ Rule = 'Bash(gh pr m* 12*)'; Expected = 'DENY' }
        @{ Rule = 'Bash(*pr merge 12*)'; Expected = 'DENY' }
        @{ Rule = 'Bash(*--match-head-commit 0123*)'; Expected = 'DENY' }
        @{ Rule = 'PowerShell(gh p*7)'; Expected = 'DENY' }
        @{ Rule = 'Bash(gh pr m* 77*)'; Expected = 'ASK' }
        @{ Rule = 'Bash(gh p*8)'; Expected = 'ASK' }
    ) {
        Test-MergeGateCapableRule $Rule (Get-MergeGateProbeCommand @('acme/web.app')) | Should -Be $false
        ('{"permissions":{"allow":["' + $Rule + '"]}}') | Set-Content (Join-Path $script:Proj '.claude/settings.local.json')
        $d = Get-ReviewGateMergeDecision -Raw (New-MergePayload) -ProjectDir $script:Proj
        $d.Decision | Should -BeExactly $Expected
        if ($Expected -ceq 'DENY') {
            $d.Reason | Should -Not -Match 'settings\.local'
            $d.Cause | Should -BeLike 'allow rule matches this merge command in: *settings.local.json'
        }
    }

    It 'spends one step budget on the probes and the asked command together' {
        # 460 rules fit the budget for the probes alone (177,560 steps), not with the command (225,400).
        $rules = @('Bash(*' + ('0' * 39) + 'x)') * 460
        @{ permissions = @{ allow = $rules } } | ConvertTo-Json -Depth 3 | Set-Content (Join-Path $script:Proj '.claude/settings.local.json')
        $d = Get-ReviewGateMergeDecision -Raw (New-MergePayload) -ProjectDir $script:Proj
        $d.Decision | Should -BeExactly 'DENY'
        $d.Cause | Should -BeLike 'allow rule matches this merge command in: *'
    }

    It 'denies a payload that is a one-element array' {
        (Get-ReviewGateMergeDecision -Raw ('[' + (New-MergePayload) + ']') -ProjectDir $script:Proj).Decision | Should -BeExactly 'DENY'
    }

    It 'runs on a host where -ceq is culture-aware (canary for the ordinal tests)' {
        # Under .NET invariant globalization -ceq is ordinal, so the U+200B tests in this file and
        # the ordinal mutations in tests/mutate-merge-gate.sh pass whether or not the helper
        # compares ordinally. Skipped loudly there, rather than passing for the wrong reason.
        if (-not (('a' + [char]0x200b) -ceq 'a')) {
            Write-Warning 'merge-gate canary: -ceq is ordinal on this host, so the ordinal-comparison tests prove nothing here'
            Set-ItResult -Skipped -Because '-ceq is ordinal on this host (.NET invariant globalization?); the U+200B ordinal tests cannot fail here'
            return
        }
        ('a' + [char]0x200b) -ceq 'a' | Should -BeTrue
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

    It 'matches rule <Rule> as a wildcard against the merge probes = <Expected>' -ForEach @(
        @{ Rule = 'Bash(gh pr m*)'; Expected = $true }
        @{ Rule = 'Bash(g*)'; Expected = $true }
        @{ Rule = 'Bash(gh a*)'; Expected = $true }
        @{ Rule = 'Bash(*merge*)'; Expected = $true }
        @{ Rule = 'Bash(gh * pr merge *)'; Expected = $true }
        @{ Rule = 'Bash(gh pr * -R acme/web.app *)'; Expected = $true }
        @{ Rule = 'Bash(gh pr * -R acme/other *)'; Expected = $false }
        @{ Rule = 'Bash(git *)'; Expected = $false }
        @{ Rule = 'Bash(gh apix *)'; Expected = $false }
        @{ Rule = 'Bash(gh pr .*)'; Expected = $false }
        @{ Rule = 'Bash(g*:*)'; Expected = $true }
        @{ Rule = 'Bash(gh pr m*e 1 --squash*)'; Expected = $true }
        @{ Rule = 'Bash(* --merge --match-head-commit*)'; Expected = $true }
    ) {
        Test-MergeGateCapableRule $Rule (Get-MergeGateProbeCommand @('acme/web.app')) | Should -Be $Expected
    }

    It 'keeps its whitespace character set and regex class in step' {
        $set = @{}
        foreach ($c in $script:MergeGateWsChars) { $set[[int]$c] = $true }
        $mismatch = @(0..0x30FF | Where-Object { ([string][char]$_ -cmatch ('\A' + $script:MergeGateWs + '\z')) -ne $set.ContainsKey($_) })
        $mismatch.Count | Should -Be 0
        (Get-MergeGateTrimmedText ([string][char]0x3000 + 'x' + [char]0x1c)) | Should -BeExactly 'x'
    }

    It 'answers a many-star rule quickly and fails closed at its bounds' {
        $probes = Get-MergeGateProbeCommand @('acme/web.app')
        $sw = [Diagnostics.Stopwatch]::StartNew()
        Test-MergeGateCapableRule ('Bash(' + ('*0' * 14) + '*x)') $probes | Should -Be $false
        $sw.Elapsed.TotalSeconds | Should -BeLessThan 5
        Test-MergeGateCapableRule ('Bash(' + ('x' * 4100) + ')') $probes | Should -Be $true
        Test-MergeGateGlob 'gh pr view *' $probes[1] @{ Steps = 1 } | Should -Be $true
        Test-MergeGateGlob 'gh pr view *' $probes[1] @{ Steps = 1000 } | Should -Be $false
    }

    It 'denies an allowlist of more than ten repos' {
        $repos = @('acme/web.app') + (0..9 | ForEach-Object { "acme/r$_" })
        @{ repos = $repos } | ConvertTo-Json | Set-Content (Join-Path $script:Proj '.claude/merge-gate.json')
        (Get-ReviewGateMergeDecision -Raw (New-MergePayload) -ProjectDir $script:Proj).Reason | Should -BeLike '*must list "repos" as 1 to 10*'
    }

    It 'reads whitespace and case like the Python twin: <Name>' -ForEach @(
        @{ Name = 'EM SPACE before -c';            Rule = "Bash(python3$([char]0x2003)-c *)"; Expected = $true }
        @{ Name = 'control char 0x1c before -c';   Rule = "Bash(python3$([char]0x1c)-c *)";   Expected = $true }
        @{ Name = 'control char 0x1c leading';     Rule = "$([char]0x1c)Bash(*)";             Expected = $true }
        @{ Name = 'ASCII case folded';             Rule = 'Bash(Python3 -c *)';               Expected = $true }
        @{ Name = 'long s not folded to s';        Rule = "Bash(ba$([char]0x17F)h -c *)";     Expected = $false }
    ) {
        Test-MergeGateCapableRule $Rule | Should -Be $Expected
    }

    It 'denies a settings file that is not strict JSON: <Name>' -ForEach @(
        @{ Name = 'a comment';               Body = '{"permissions": {"allow": []}} // c' }
        @{ Name = 'a trailing comma';        Body = '{"permissions": {"allow": [],},}' }
        @{ Name = 'NaN';                     Body = '{"permissions": {"allow": []}, "x": NaN}' }
        @{ Name = 'single quotes';           Body = "{'permissions': {'allow': []}}" }
        @{ Name = 'a one-element array';     Body = '[{"permissions": {"allow": ["Bash(git *)"]}}]' }
    ) {
        $Body | Set-Content (Join-Path $script:Proj '.claude/settings.local.json')
        (Get-ReviewGateMergeDecision -Raw (New-MergePayload) -ProjectDir $script:Proj).Decision | Should -BeExactly 'DENY'
    }

    It 'denies when GH_CONFIG_DIR is set' {
        $env:GH_CONFIG_DIR = Join-Path $TestDrive 'gh'
        (Get-ReviewGateMergeDecision -Raw (New-MergePayload) -ProjectDir $script:Proj).Decision | Should -BeExactly 'DENY'
    }

    It 'gives the not-configured text when merge-gate.json has no repos key' {
        '{"other": 1}' | Set-Content (Join-Path $script:Proj '.claude/merge-gate.json')
        (Get-ReviewGateMergeDecision -Raw (New-MergePayload) -ProjectDir $script:Proj).Reason | Should -BeLike '*must list "repos"*'
    }

    It 'denies when the allowlist config is missing' {
        Remove-Item (Join-Path $script:Proj '.claude/merge-gate.json')
        (Get-ReviewGateMergeDecision -Raw (New-MergePayload) -ProjectDir $script:Proj).Decision | Should -BeExactly 'DENY'
    }
}
