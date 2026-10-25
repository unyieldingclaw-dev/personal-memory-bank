#Requires -Modules Pester

BeforeAll {
    $script:RepoRoot = Split-Path $PSScriptRoot -Parent
    $script:Classifier = Join-Path $script:RepoRoot 'scripts/_review-gate-classify.ps1'

    function Invoke-Classifier {
        param($Payload)
        $json = if ($Payload -is [string]) { $Payload } else { $Payload | ConvertTo-Json -Compress -Depth 5 }
        $output = $json | & pwsh -NoLogo -NonInteractive -ExecutionPolicy Bypass -File $script:Classifier 2>&1
        [PSCustomObject]@{ Output = ($output -join '').Trim(); ExitCode = $LASTEXITCODE }
    }

    function New-Payload([string]$Command, [string]$ToolName = 'PowerShell') {
        @{ tool_name = $ToolName; tool_input = @{ command = $Command } }
    }
}

Describe '_review-gate-classify.ps1' {
    It 'classifies <Name>' -ForEach @(
        @{ Name = 'canonical commit'; Command = 'git commit -m x'; Expected = 'COMMIT' }
        @{ Name = 'git -C commit'; Command = 'git -C . commit -m x'; Expected = 'COMMIT' }
        @{ Name = 'git -c commit'; Command = 'git -c user.name=x commit -m x'; Expected = 'COMMIT' }
        @{ Name = 'uppercase git.exe push'; Command = 'GIT.EXE -C . push origin HEAD'; Expected = 'PUSH' }
        @{ Name = 'quoted Windows git.exe'; Command = '& "C:\Program Files\Git\cmd\git.exe" commit -m x'; Expected = 'COMMIT' }
        @{ Name = 'gh merge'; Command = 'gh pr merge 25'; Expected = 'MERGE' }
        @{ Name = 'gh REST merge'; Command = 'gh api -X PUT repos/o/r/pulls/25/merge'; Expected = 'MERGE' }
        @{ Name = 'launcher-wrapped commit'; Command = 'pwsh -c "git commit -m x"'; Expected = 'COMMIT' }
        @{ Name = 'commit then merge'; Command = 'git commit -m x && gh pr merge 25'; Expected = 'MULTI' }
        @{ Name = 'commit then push'; Command = 'git commit -m x && git push origin HEAD'; Expected = 'MULTI' }
        @{ Name = 'read-only git'; Command = 'git log --oneline -5'; Expected = 'NONE' }
        @{ Name = 'prose echo'; Command = 'echo "documenting the git commit gate"'; Expected = 'NONE' }
        @{ Name = 'quoted parentheses prose'; Command = 'echo "(git commit)"'; Expected = 'NONE' }
        @{ Name = 'quoted semicolon prose'; Command = 'echo "docs; git commit"'; Expected = 'NONE' }
        @{ Name = 'nested shell prose'; Command = 'bash -c ''echo "git commit gate"'''; Expected = 'NONE' }
        @{ Name = 'npm test-name prose'; Command = 'npm test -- --name "git commit behavior"'; Expected = 'NONE' }
        @{ Name = 'source grep'; Command = 'rg "git commit" scripts/review-reminders.ps1'; Expected = 'NONE' }
    ) {
        $r = Invoke-Classifier (New-Payload $Command)
        $r.ExitCode | Should -Be 0
        $r.Output | Should -Be $Expected
    }

    It 'accepts the camelCase payload shape used by older harnesses' {
        $r = Invoke-Classifier @{ toolName = 'PowerShell'; toolInput = @{ command = 'git -C . commit -m x' } }
        $r.ExitCode | Should -Be 0
        $r.Output | Should -Be 'COMMIT'
    }

    It 'returns non-zero for malformed JSON so the caller uses its conservative fallback' {
        $r = Invoke-Classifier '{"tool_input":{"command":"git com'
        $r.ExitCode | Should -Not -Be 0
    }
}

Describe 'review-gate settings wiring' {
    It 'wires <Event> review handling to the PowerShell tool in <Settings>' -ForEach @(
        @{ Settings = '.claude/settings.json'; Event = 'PreToolUse'; Script = 'review-reminders.ps1' }
        @{ Settings = '.claude/settings.json'; Event = 'PostToolUse'; Script = 'review-reminders-post.ps1' }
        @{ Settings = 'templates/.claude/settings.json'; Event = 'PreToolUse'; Script = 'review-reminders.ps1' }
        @{ Settings = 'templates/.claude/settings.json'; Event = 'PostToolUse'; Script = 'review-reminders-post.ps1' }
    ) {
        $config = Get-Content (Join-Path $script:RepoRoot $Settings) -Raw | ConvertFrom-Json
        $entries = @($config.hooks.$Event | Where-Object { $_.matcher -eq 'PowerShell' })
        $entries.Count | Should -Be 1
        (@($entries[0].hooks.command) -join "`n") | Should -Match ([regex]::Escape($Script))
    }
}
