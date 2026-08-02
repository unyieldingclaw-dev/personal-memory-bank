# PostToolUse hook — companion to review-reminders.ps1 (PreToolUse). If a git commit/push
# that consumed a review-ok marker then failed, reissues the marker so a rejected attempt
# (e.g. a separate pre-commit hook, nothing staged, a merge conflict) doesn't force a
# pointless re-review -- the diff hasn't changed, so the same review still applies.
#
# WHY compare git ref state instead of parsing tool_response: the exact PostToolUse
# response schema (success/exitCode field names) isn't worth depending on when the
# question can be answered from ground truth instead -- if HEAD (for commit) or the
# upstream ref (for push) didn't move, the command failed, full stop, regardless of what
# any response field says.
$raw = [Console]::In.ReadToEnd()
if ([string]::IsNullOrWhiteSpace($raw)) { exit 0 }
$cmd = $null
try {
    $parsed = $raw | ConvertFrom-Json
    if ($null -ne $parsed.tool_input.PSObject.Properties['command']) {
        $cmd = $parsed.tool_input.command
    }
} catch { }
if ($null -eq $cmd) { $cmd = $raw }

# WHY match against a quote/backslash-stripped copy, not $cmd itself: see the matching comment
# in review-reminders.ps1 -- a command like `git c"o"mmit -m "x"` executes, after real shell
# quote removal, as a genuine `git commit -m x`, but the command TEXT never contains "git
# commit" as a contiguous match for the regexes below. Stripping quote/backslash characters
# before matching (never from $cmd itself, which the leading-cd-chain parsing below still needs
# with real quoting intact) can only make a match MORE likely to fire -- the same safe
# direction as everywhere else in this file.
$cmdStripped = $cmd -replace '["''\\]', ''

# Get-NextSubcommand / Get-CommandTargets — see the matching (much more extensively
# commented) definitions in review-reminders.ps1: an ADDITIONAL commit/push detector, layered
# on TOP of $cmdStripped's regex check below, never a replacement for it -- splitting $Command
# on shell control operators and tokenizing each simple command past git's own documented
# global options (-C, -c, --opt=value, etc.) to find the REAL subcommand. Closes the same
# `git -C <path> commit` / `git -c k=v commit` gap $cmdStripped's regex still misses, since
# regex substring matching doesn't understand git's own argument grammar.
function Get-NextSubcommand {
    param([string[]]$Tokens, [int]$Start, [string[]]$OptsWithValue)
    $i = $Start
    while ($i -lt $Tokens.Count) {
        $t = $Tokens[$i]
        if ($t.StartsWith('--') -and $t.Contains('=')) { $i++; continue }
        if ($OptsWithValue -contains $t.ToLower()) { $i += 2; continue }
        if ($t.StartsWith('-')) { $i++; continue }
        return @($t, ($i + 1))
    }
    return @($null, $i)
}

function Get-CommandTargets {
    param([string]$Command)
    $gitOptsWithValue = @('-c', '-C', '--git-dir', '--work-tree', '--namespace', '--super-prefix', '--exec-path', '--attr-source')

    $found = [System.Collections.Generic.HashSet[string]]::new()
    $segments = [regex]::Split($Command, '(?:&&|\|\||;|\|)')
    foreach ($seg in $segments) {
        $tokens = @($seg.Trim() -split '\s+' | Where-Object { $_ -ne '' })
        if ($tokens.Count -eq 0) { continue }
        if ($tokens[0].ToLower() -ne 'git') { continue }
        $sub, $null1 = Get-NextSubcommand -Tokens $tokens -Start 1 -OptsWithValue $gitOptsWithValue
        if ($sub -and $sub.ToLower() -eq 'commit') { [void]$found.Add('commit') }
        elseif ($sub -and $sub.ToLower() -eq 'push') { [void]$found.Add('push') }
    }
    return $found
}

# WHY needsCommit/needsPush (two independent checks), not one if/elseif: see the matching
# comment in review-reminders.ps1 -- a compound `git commit -m x && git push origin main`
# matches both. An if/elseif only reissues whichever marker matches first, silently leaving
# the OTHER action's presha file unprocessed even though the compound command may have
# genuinely failed on both halves.
#
# WHY $cmdStripped's regex runs unconditionally first, with Get-CommandTargets's result OR'd
# in afterward: see the matching WHY comment in review-reminders.ps1 -- a recognized head token
# of exactly "git" does NOT match `/usr/bin/git commit`/`env git commit`, so treating
# Get-CommandTargets as authoritative whenever it runs without error silently loses the
# coverage $cmdStripped's regex already had for those ordinary indirect invocations. OR'ing the
# two means Get-CommandTargets can only ever ADD detection, never remove it. $targets may be
# $null (an exception, or PowerShell unwrapping an empty HashSet) -- both are treated as "no
# additional targets found" via the $null -ne guard, never as a reason to skip the regex.
$targets = $null
try {
    $targets = Get-CommandTargets -Command $cmd
} catch { }

$needsCommit = $cmdStripped -match 'git\s+commit\b'
$needsPush = $cmdStripped -match 'git\s+push\b'
if ($null -ne $targets) {
    if ($targets.Contains('commit')) { $needsCommit = $true }
    if ($targets.Contains('push')) { $needsPush = $true }
}
if (-not $needsCommit -and -not $needsPush) { exit 0 }

# WHY this exists: see the matching comment in review-reminders.ps1.
#
# WHY resolve the FULL leading cd chain: see the matching comment in review-reminders.ps1 --
# both hooks share this exact logic.
$cdRoot = $null
$chainPatternText = @'
^cd\s+(?:"([^"]+)"|'([^']+)')\s*&&\s*
'@
$chainPattern = [regex]$chainPatternText
$restCmd = $cmd
$curDir = (Get-Location).Path
$matchedAny = $false
while ($true) {
    $m = $chainPattern.Match($restCmd)
    if (-not $m.Success) { break }
    $matchedAny = $true
    $p = if ($m.Groups[1].Success) { $m.Groups[1].Value } else { $m.Groups[2].Value }
    $curDir = if ([System.IO.Path]::IsPathRooted($p)) { $p } else { [System.IO.Path]::GetFullPath((Join-Path $curDir $p)) }
    $restCmd = $restCmd.Substring($m.Length)
}
if ($matchedAny) {
    $candidate = git -C $curDir rev-parse --show-toplevel 2>$null
    if ($candidate) { $cdRoot = $candidate }
}

$root = if ($cdRoot) { $cdRoot } else { git rev-parse --show-toplevel 2>$null }
if (-not $root) { exit 0 }

# WHY Set-Location here: see the matching comment in review-reminders.ps1.
try { Set-Location $root } catch { exit 0 }

# WHY replay the persisted .pending-*-hash instead of recomputing a fresh hash here, and WHY
# fail CLOSED (skip reissuing) when the hash file is missing/torn: see the matching comment in
# review-reminders-post.sh -- recomputing fresh assumed "a failed commit/push can't have
# altered the working tree," which is false whenever a downstream project's own pre-commit
# hook mutates files and then rejects the commit (e.g. an auto-formatter). Replaying the hash
# review-reminders.ps1 persisted at validation time means the reissued marker always
# corresponds to a diff that was genuinely reviewed; falling back to a fresh recompute when
# the hash file is missing would silently reintroduce that exact bug for that one case.
if ($needsCommit) {
    $preShaFile = Join-Path $root '.claude/.pending-commit-presha'
    $hashFile = Join-Path $root '.claude/.pending-commit-hash'
    if (Test-Path $preShaFile) {
        $preSha = (Get-Content $preShaFile -Raw -ErrorAction SilentlyContinue)
        $preSha = if ($preSha) { $preSha.Trim() } else { $null }
        $origHash = $null
        if (Test-Path $hashFile) {
            $origHash = (Get-Content $hashFile -Raw -ErrorAction SilentlyContinue)
            $origHash = if ($origHash) { $origHash.Trim() } else { $null }
        }
        Remove-Item $preShaFile -Force -ErrorAction SilentlyContinue
        Remove-Item $hashFile -Force -ErrorAction SilentlyContinue
        $postSha = git rev-parse HEAD 2>$null
        if ($preSha -and $postSha -and $postSha -eq $preSha -and $origHash) {
            $origHash | Set-Content (Join-Path $root '.claude/.code-review-ok')
        }
    }
}

if ($needsPush) {
    $preShaFile = Join-Path $root '.claude/.pending-push-presha'
    $hashFile = Join-Path $root '.claude/.pending-push-hash'
    if (Test-Path $preShaFile) {
        $preSha = (Get-Content $preShaFile -Raw -ErrorAction SilentlyContinue)
        $preSha = if ($preSha) { $preSha.Trim() } else { $null }
        $origHash = $null
        if (Test-Path $hashFile) {
            $origHash = (Get-Content $hashFile -Raw -ErrorAction SilentlyContinue)
            $origHash = if ($origHash) { $origHash.Trim() } else { $null }
        }
        Remove-Item $preShaFile -Force -ErrorAction SilentlyContinue
        Remove-Item $hashFile -Force -ErrorAction SilentlyContinue
        $postSha = git rev-parse '@{u}' 2>$null
        if ($preSha -and $postSha -and $postSha -eq $preSha -and $origHash) {
            $origHash | Set-Content (Join-Path $root '.claude/.change-review-ok')
        }
    }
}
exit 0
