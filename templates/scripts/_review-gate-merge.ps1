# Decide whether a payload the classifier already labelled MERGE may be put to the user.
#
# Dot-sourced by review-reminders.ps1 only after the classifier returned MERGE. The PowerShell
# twin of _review-gate-merge.py: the two must agree on every fixture in tests/test-merge-gate.sh,
# and the WHY for each rule lives in that file's comments -- not repeated here.
#
# Returns @{ Decision = 'ASK' | 'DENY'; Reason; Audit; Cause }. The hook treats anything other
# than Decision -ceq 'ASK' -- including a throw or this file failing to load -- as deny.
#
# Every comparison is case-exact (-cmatch / -ceq / -ccontains), because PowerShell's defaults
# are case-insensitive and the Python twin is not. ConvertFrom-Json property access is also
# case-insensitive, so payload keys are looked up through Get-MergeGateProperty.

$script:MergeGateModes = @('default', 'acceptEdits', 'auto')
$script:MergeGateDescription = 'Merge pull request (verify the details in the hook reason)'
$script:MergeGateGenericDeny = "Merge gate precondition failed. Ask the user to check this checkout's Claude settings."

function Get-MergeGateProperty {
    param($Object, [string]$Name)
    if ($null -eq $Object -or $Object -isnot [System.Management.Automation.PSCustomObject]) {
        return [pscustomobject]@{ Present = $false; Value = $null }
    }
    $prop = @($Object.PSObject.Properties | Where-Object { $_.Name -ceq $Name })
    if ($prop.Count -eq 0) { return [pscustomobject]@{ Present = $false; Value = $null } }
    [pscustomobject]@{ Present = $true; Value = $prop[0].Value }
}

function New-MergeGateDeny {
    param([string]$Reason, [string]$Cause)
    [pscustomobject]@{ Decision = 'DENY'; Reason = $Reason; Audit = $null; Cause = $Cause }
}

function Test-MergeGateCapableRule {
    param([string]$Rule)
    $r = $Rule.Trim()
    if ($r -cnotmatch '(?s)\A(Bash|PowerShell)(?:\((.*)\))?\z') { return $false }
    if (-not $Matches.ContainsKey(2)) { return $true }
    $body = $Matches[2].Trim()
    if ($body -ceq '*' -or $body -ceq ':*') { return $true }
    if ($body -cmatch '\Agh(?:\s*\*|:\*)?\z') { return $true }
    if ($body -cmatch '\Agh\s+(?:api\b|-)') { return $true }
    if ($body -cmatch '\Agh\s+pr(?:\s*\*|:\*)\z' -or $body -cmatch '\Agh\s+pr\s+merge\b') { return $true }
    $interp = '\A(?:python3?|py|node|pwsh|powershell|bash|sh|cmd)(?:\.exe)?(?:\s.*)?\s(?:-c|-e|--eval|-Command|-EncodedCommand|/c)\b'
    return ($body.Contains('*') -and $body -match $interp)
}

function Get-MergeGateSettingsFiles {
    param([string]$ProjectDir)
    $config = if ($env:CLAUDE_CONFIG_DIR) { $env:CLAUDE_CONFIG_DIR } else { Join-Path $HOME '.claude' }
    @(
        (Join-Path $config 'settings.json'),
        (Join-Path (Join-Path $ProjectDir '.claude') 'settings.json'),
        (Join-Path (Join-Path $ProjectDir '.claude') 'settings.local.json')
    )
}

function Get-ReviewGateMergeDecision {
    param([string]$Raw, [string]$ProjectDir)

    $payload = $Raw | ConvertFrom-Json -ErrorAction Stop
    if ($payload -isnot [System.Management.Automation.PSCustomObject]) {
        return New-MergeGateDeny $script:MergeGateGenericDeny 'payload is not a JSON object'
    }
    if ((Get-MergeGateProperty $payload 'agent_id').Present) {
        return New-MergeGateDeny 'Subagents never merge pull requests. Ask the user, in the main conversation.'
    }
    $mode = (Get-MergeGateProperty $payload 'permission_mode').Value
    if ($mode -isnot [string] -or -not ($script:MergeGateModes -ccontains $mode)) {
        return New-MergeGateDeny 'Merges are only put to the user in default, acceptEdits or auto mode; this session cannot show a prompt for it. Merge in the GitHub UI instead.'
    }
    if ((Test-Path Env:GH_HOST) -or (Test-Path Env:GH_REPO)) {
        return New-MergeGateDeny $script:MergeGateGenericDeny 'GH_HOST or GH_REPO is set in the hook environment'
    }

    foreach ($path in (Get-MergeGateSettingsFiles $ProjectDir)) {
        if (-not (Test-Path -LiteralPath $path)) { continue }
        try {
            $data = Get-Content -LiteralPath $path -Raw -ErrorAction Stop | ConvertFrom-Json -ErrorAction Stop
        } catch {
            return New-MergeGateDeny $script:MergeGateGenericDeny "unreadable or malformed settings: $path"
        }
        if ($data -isnot [System.Management.Automation.PSCustomObject]) {
            return New-MergeGateDeny $script:MergeGateGenericDeny "settings is not a JSON object: $path"
        }
        $hooks = (Get-MergeGateProperty $data 'hooks').Value
        if ($null -ne $hooks) {
            if ($hooks -isnot [System.Management.Automation.PSCustomObject]) {
                return New-MergeGateDeny $script:MergeGateGenericDeny "hooks is not an object: $path"
            }
            $pr = (Get-MergeGateProperty $hooks 'PermissionRequest').Value
            if ($null -ne $pr -and -not ($pr -is [System.Array] -and $pr.Count -eq 0)) {
                return New-MergeGateDeny $script:MergeGateGenericDeny "PermissionRequest hook configured: $path"
            }
        }
        $perms = (Get-MergeGateProperty $data 'permissions').Value
        # Assigned directly: `$allow = if (...) { ... }` unrolls a one-element array into a bare
        # string, which then fails the list check (measured).
        $allow = $null
        if ($perms -is [System.Management.Automation.PSCustomObject]) { $allow = (Get-MergeGateProperty $perms 'allow').Value }
        if ($null -ne $allow -and $allow -isnot [System.Array]) {
            return New-MergeGateDeny $script:MergeGateGenericDeny "permissions.allow is not a list: $path"
        }
        foreach ($rule in @($allow)) {
            if ($null -eq $rule) { continue }
            if ($rule -isnot [string] -or (Test-MergeGateCapableRule $rule)) {
                return New-MergeGateDeny $script:MergeGateGenericDeny "merge-capable allow rule in: $path"
            }
        }
    }

    $notConfigured = 'Merge gate is not configured: .claude/merge-gate.json must list "repos" as owner/repo strings. Merge in the GitHub UI instead.'
    try {
        $config = Get-Content -LiteralPath (Join-Path (Join-Path $ProjectDir '.claude') 'merge-gate.json') -Raw -ErrorAction Stop | ConvertFrom-Json -ErrorAction Stop
    } catch {
        return New-MergeGateDeny 'Merge gate is not configured: .claude/merge-gate.json is missing or malformed, so no repository is allowed. Merge in the GitHub UI instead.'
    }
    $repos = (Get-MergeGateProperty $config 'repos').Value
    if ($repos -isnot [System.Array] -or $repos.Count -eq 0) { return New-MergeGateDeny $notConfigured }
    foreach ($r in $repos) {
        if ($r -isnot [string] -or $r -cnotmatch '\A[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+\z') { return New-MergeGateDeny $notConfigured }
    }

    $toolInput = (Get-MergeGateProperty $payload 'tool_input').Value
    if ($toolInput -isnot [System.Management.Automation.PSCustomObject]) {
        return New-MergeGateDeny $script:MergeGateGenericDeny 'payload has no tool_input object'
    }
    $command = (Get-MergeGateProperty $toolInput 'command').Value
    $alt = ($repos | ForEach-Object { [regex]::Escape($_) }) -join '|'
    $canonical = "\Agh pr merge (?<n>[1-9][0-9]{0,8}) -R (?<repo>$alt) (?<method>--squash|--merge) --match-head-commit (?<sha>[0-9a-f]{40})\z"
    if ($command -isnot [string] -or $command -cnotmatch $canonical) {
        return New-MergeGateDeny ("This agent merges a pull request only in exactly this form, with nothing before or after it: gh pr merge <N> -R " + $repos[0] + " --squash --match-head-commit <full 40-hex head SHA> (or --merge in place of --squash). Use the PR number and head SHA the user asked for.")
    }
    $m = $Matches
    $desc = Get-MergeGateProperty $toolInput 'description'
    if ($desc.Present -and -not ($desc.Value -is [string] -and $desc.Value -ceq $script:MergeGateDescription)) {
        return New-MergeGateDeny ('Set the tool description to exactly "' + $script:MergeGateDescription + '", or omit it. The prompt shows it, so it must not describe the merge in the agent''s own words.')
    }

    $method = if ($m['method'] -ceq '--squash') { 'squash' } else { 'merge commit' }
    [pscustomobject]@{
        Decision = 'ASK'
        Reason   = "Merge PR #$($m['n']) in $($m['repo']) by $method, exactly at head $($m['sha']). Approve only if YOU asked to merge this PR just now. This approval covers this one command."
        Audit    = "$mode`t$($m['repo'])`t$($m['n'])`t$($m['sha'])"
        Cause    = $null
    }
}
