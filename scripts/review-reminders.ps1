# PreToolUse hook -- blocks git commit/push until the matching review slash command has run.
# /code-review writes .claude/.code-review-ok on an Approve verdict; /change-review writes
# .claude/.change-review-ok when no finding is Blocking. Each marker authorizes exactly one
# commit or push attempt for a SPECIFIC diff -- see below.
#
# WHY the marker holds a SHA-256 hash of the reviewed diff, not an empty file: an empty
# marker is trivially fakeable with `touch` -- anyone (or a rushed agent) can satisfy the
# gate without actually reviewing anything. Binding the marker to a hash of the exact diff
# means it only authorizes committing/pushing that SPECIFIC diff; if the working tree
# changes after the review, the hash no longer matches and the gate re-engages.
#
# WHY the marker is consumed via an atomic rename (Move-Item), not a separate
# Test-Path + Remove-Item: check-then-delete has a TOCTOU window between the two steps.
# Move-Item's underlying rename is a single filesystem operation -- if the source doesn't
# exist, the move simply fails, collapsing "does it exist" and "claim it" into one step.
#
# WHY only commit attempts get failure recovery: HEAD identifies the exact ref a commit can
# move, so the PostToolUse hook can prove failure. A push may target a different remote/ref
# from @{u}; inferring success from the configured upstream minted a fresh marker after a
# successful alternate-remote push. Push markers therefore remain single-use on every attempt.
#
# WHY match "git\s+commit\b" anywhere in $cmd instead of anchoring to command start/operators:
# an anchored regex (^|[;&|]\s*)git\s+commit\b misses real shapes -- multi-line Bash tool
# commands (git commit after a literal newline), a bare single "&", or nested subshells. $cmd
# is already the exact, JSON-parsed command text (not raw payload noise), so an unanchored
# match is safe: the only real risk is a false positive if "git commit" appears as a substring
# elsewhere in the command, which just means an occasional unnecessary re-review -- the safe
# failure direction for a security gate.
#
# WHY a merge gets a permission prompt ("ask") instead of a third diff-bound marker: the gap at
# merge time isn't diff integrity (the commit gate, push gate and strict required checks cover
# that), it's authorization -- the user deciding, in that moment, to merge that PR -- and no
# marker the agent can write encodes that. The harness's own Allow/Deny prompt is the one
# per-action approval the agent cannot forge. It replaced an unconditional deny on 2026-10-20,
# after an in-app measurement in auto mode showed the ask stops for the user's click.
# _review-gate-merge.ps1 decides; only one exact, repo-pinned form is ever asked. Full WHY in
# review-reminders.sh; spec: docs/superpowers/specs/2026-10-20-merge-gate-user-approval-design.md.
#
# WHY hookSpecificOutput.permissionDecision, not top-level "continue": top-level
# {"continue": false} only stops the agent's turn *after* the tool call has already run --
# it does not prevent execution. Verified empirically: an earlier version of this hook using
# {"continue": false} let a real `git commit` through untouched, then interrupted the next
# turn. hookSpecificOutput.permissionDecision = "deny" is the mechanism that actually denies
# the tool call before it executes.
#
function Deny {
    param([string]$Reason)
    @{
        hookSpecificOutput = @{
            hookEventName            = 'PreToolUse'
            permissionDecision       = 'deny'
            permissionDecisionReason = $Reason
        }
    } | ConvertTo-Json -Compress | Write-Output
}

$raw = [Console]::In.ReadToEnd()
if ([string]::IsNullOrWhiteSpace($raw)) { exit 0 }

# Classify before loading anything that can fail. A known guarded action must fail closed
# when its library or repository root is unavailable; read-only commands remain unaffected.
$verdict = $null
$cmd = $null
$verdictFromFallback = $false
try {
    . (Join-Path $PSScriptRoot '_review-gate-classify.ps1')
    $verdict = Get-ReviewGateVerdictFromPayload $raw
    $payload = $raw | ConvertFrom-Json -ErrorAction Stop
    $toolInput = $payload.tool_input
    if ($null -eq $toolInput) { $toolInput = $payload.toolInput }
    $cmd = $toolInput.command
} catch {
    # Preserve the old conservative raw matcher for malformed payloads or a missing
    # classifier. Lowercasing closes the executable-case hole on this fallback path.
    $verdictFromFallback = $true
    $lower = $raw.ToLowerInvariant()
    $fallbackMatches = @()
    if ($lower.Contains('git commit')) { $fallbackMatches += 'COMMIT' }
    if ($lower.Contains('git push')) { $fallbackMatches += 'PUSH' }
    if ($lower.Contains('gh pr merge')) { $fallbackMatches += 'MERGE' }
    $verdict = if ($fallbackMatches.Count -gt 1) { 'MULTI' }
        elseif ($fallbackMatches.Count -eq 1) { $fallbackMatches[0] }
        else { 'NONE' }
}

if ($verdict -eq 'NONE') { exit 0 }
if ($verdict -eq 'MULTI') {
    Deny 'Review gate: compound commands containing multiple guarded actions must be run separately so each action receives its own authorization.'
    exit 0
}
if ($verdict -eq 'MERGE') {
    # Asked only when _review-gate-merge.ps1 answers ASK; a fallback verdict, a missing helper
    # or any throw denies. See the WHY above and the .sh twin.
    $mergeDecision = $null
    if (-not $verdictFromFallback) {
        try {
            . (Join-Path $PSScriptRoot '_review-gate-merge.ps1')
            $projectDir = if ($env:CLAUDE_PROJECT_DIR) { $env:CLAUDE_PROJECT_DIR } else { (Get-Location).Path }
            $mergeDecision = Get-ReviewGateMergeDecision -Raw $raw -ProjectDir $projectDir
        } catch {
            $mergeDecision = $null
        }
    }
    if ($null -ne $mergeDecision -and $mergeDecision.Decision -ceq 'ASK') {
        @{
            hookSpecificOutput = @{
                hookEventName            = 'PreToolUse'
                permissionDecision       = 'ask'
                permissionDecisionReason = $mergeDecision.Reason
            }
        } | ConvertTo-Json -Compress | Write-Output
        # After the decision, and allowed to fail: a record of what was asked, not the answer.
        try {
            Add-Content -LiteralPath (Join-Path (Join-Path $projectDir '.claude') 'merge-asks.log') `
                -Value ("{0}`t{1}" -f (Get-Date).ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ssZ'), $mergeDecision.Audit) `
                -ErrorAction Stop
        } catch {
            # Swallowed on purpose: the decision is already printed, and a throw escaping here would
            # exit non-zero, run the bash fallback and print a second JSON object (no decision).
            $null = $_
        }
    } elseif ($null -ne $mergeDecision -and $mergeDecision.Decision -ceq 'DENY' -and $mergeDecision.Reason) {
        if ($mergeDecision.Cause) { [Console]::Error.WriteLine("merge gate: $($mergeDecision.Cause)") }
        Deny $mergeDecision.Reason
    } else {
        Deny 'This agent merges a pull request only after the merge gate has checked it, and the check could not run here (no classifier verdict, or scripts/_review-gate-merge.ps1 unavailable). Merge in the GitHub UI instead.'
    }
    exit 0
}

try {
    . (Join-Path $PSScriptRoot '_review-gate-lib.ps1')
} catch {
    Deny 'Review gate cannot run: scripts/_review-gate-lib.ps1 is missing or unreadable, so the marker check is unavailable. Restore the file before committing or pushing.'
    exit 0
}

# WHY this exists: `git rev-parse --show-toplevel` below trusts the hook process's own
# ambient cwd, which is empirically wrong for some dispatched-subagent sessions. $cmd is
# already the parsed command string (via ConvertFrom-Json above), so extracting a leading cd
# path is a plain regex, no new dependency needed. Falls back to the ambient resolution on
# any failure -- a session where ambient cwd is already correct is completely unaffected.
$commandContext = Get-ReviewGateCommandContext $cmd
if ($commandContext.Unsupported) {
    Deny "Review gate cannot safely bind this command's explicit --git-dir/--work-tree context to a repository. Run the command from that repository instead."
    exit 0
}
$contextDir = (Get-Location).Path
$contextFailed = $false
foreach ($contextPath in @($commandContext.Paths)) {
    try {
        $candidate = if ([System.IO.Path]::IsPathRooted($contextPath)) {
            $contextPath
        } else {
            Join-Path $contextDir $contextPath
        }
        $contextDir = (Resolve-Path -LiteralPath $candidate -ErrorAction Stop).Path
    } catch {
        $contextFailed = $true
        break
    }
}
if ($contextFailed) {
    Deny "Review gate cannot resolve the command's explicit repository path, so it cannot verify the correct marker."
    exit 0
}
$cdRoot = Resolve-CdRoot -Cmd $cmd
$root = if (@($commandContext.Paths).Count -gt 0) {
    git -C $contextDir rev-parse --show-toplevel 2>$null
} elseif ($cdRoot) {
    $cdRoot
} else {
    git rev-parse --show-toplevel 2>$null
}
if (-not $root) {
    Deny 'Review gate cannot run: the repository root could not be resolved, so the marker check is unavailable.'
    exit 0
}

# WHY Set-Location here, not -C $root on every git call below: resolving $root fixes where
# the marker is looked FOR, but the diff-hash functions and $preSha rev-parse call further
# down still run bare git commands with no directory anchor -- the same ambient-cwd
# assumption just fixed above, at different call sites. Anchoring the rest of this script to
# $root once, here, means every git call downstream is correct by construction instead of
# needing -C $root at each individual site.
try { Set-Location $root } catch {
    Deny "Review gate cannot run: the resolved repository root '$root' is not enterable."
    exit 0
}

function Move-ReviewGateMarkerToClaim {
    param([string]$Marker)
    $claimed = "$Marker.claimed.$PID"
    # WHY [System.IO.File]::Move, not the Move-Item cmdlet: empirically verified (see
    # scripts/mb.ps1's Get-CachedPmbVersion, hardened for the same reason) that Move-Item -Force
    # is NOT the atomic primitive it looks like on this platform's PowerShell 7/NTFS stack --
    # under concurrent load it produced writer-side IOExceptions and reader-side
    # FileNotFoundExceptions, while the raw .NET File.Move overload had zero errors under
    # identical load. This function is the actual security-critical marker-consumption path
    # (unlike the version cache), so it gets the more reliable primitive.
    try {
        [System.IO.File]::Move($Marker, $claimed, $true)
    } catch {
        return $null
    }
    $content = $null
    try { $content = (Get-Content $claimed -Raw -ErrorAction Stop).Trim() } catch {
        Write-Verbose "Could not read claimed marker '$claimed'; treating its content as empty."
    }
    return [PSCustomObject]@{ Marker = $Marker; Claimed = $claimed; Content = $content }
}

function Restore-ReviewGateMarkerFromClaim {
    param($Claim)
    try { [System.IO.File]::Move($Claim.Claimed, $Claim.Marker, $true) } catch {
        Write-Verbose "Could not restore claimed marker '$($Claim.Claimed)' to '$($Claim.Marker)'."
    }
}

function Complete-ReviewGateMarkerClaim {
    param($Claim)
    Remove-Item $Claim.Claimed -Force -ErrorAction SilentlyContinue
}

$emptyDiffSha = 'e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855'
# WHY name the root in the empty-diff denials: a command whose cd was not its first word
# (`N=...; cd "<worktree>" && git push`) fell back to the hook's working directory, the main
# checkout, whose diff was empty -- and the denial gave no hint which tree it had checked.
# The cd form named here is the one the resolvers accept: quoted, first in the command, then &&
# (_review-gate-classify.ps1 / _review-gate-lib.ps1). An unquoted cd falls back to the working directory again.
$rootHint = "The gate checked ${root}: it takes the repository from a quoted cd ""<path>"" && chain at the very start of the command plus any git -C path, else from the hook's working directory. If that is the wrong tree, start the command with cd ""<repo>"" &&."

switch ($verdict) {
    'COMMIT' {
        $expected = Get-CommitDiffHash
        $marker = Join-Path $root '.claude/.code-review-ok'
        if (-not $expected -or $expected -eq $emptyDiffSha) {
            Deny "Review gate: there is no diff to review, so an empty-diff hash cannot serve as proof of review. $rootHint"
            break
        }
        # A commit records the INDEX, but the marker binds `git diff HEAD`, so a reviewed change
        # left partly unstaged would still match (OPP6-1). See review-reminders.sh for why this
        # is a refusal rather than a `git diff --cached HEAD` hash, and why --no-ext-diff and
        # --no-textconv. Before the claim, so a refusal leaves the marker for the retry.
        git diff --quiet --no-ext-diff --no-textconv 2>$null
        if ($LASTEXITCODE -ne 0) {
            Deny "Review gate: tracked changes are unstaged (or git diff failed), so this commit would not contain everything the review marker certifies. Stage every reviewed change in a separate command first -- this hook runs before any git add chained into the same command, and before git commit -a stages anything -- then commit. To keep part of the change out of this commit (whole files only), set it aside with a tagged stash: git stash push -m <unique-tag> -- <paths>, re-run /code-review on what remains, and commit. Then restore it with git stash apply <sha> (the SHA from git stash list --format='%H %gs') and drop that entry by its current stash@{n}. The stash stack is shared across worktrees, so never use a bare git stash pop. $rootHint"
            break
        }
        $claim = Move-ReviewGateMarkerToClaim $marker
        if ($null -eq $claim) {
            Deny 'Run /code-review before committing -- it writes a diff-bound review-ok marker this hook checks.'
        } elseif ($claim.Content -eq $expected) {
            Complete-ReviewGateMarkerClaim $claim
            $preSha = git rev-parse HEAD 2>$null
            if ($preSha) { "$preSha $expected" | Set-Content (Join-Path $root '.claude/.pending-commit-presha') }
        } else {
            Restore-ReviewGateMarkerFromClaim $claim
            Deny 'Run /code-review before committing -- the working tree no longer matches the reviewed diff.'
        }
        break
    }
    'PUSH' {
        $expected = Get-PushDiffHash
        $marker = Join-Path $root '.claude/.change-review-ok'
        if (-not $expected -or $expected -eq $emptyDiffSha) {
            Deny "Review gate: there is no diff to review, so an empty-diff hash cannot serve as proof of review. $rootHint"
            break
        }
        $claim = Move-ReviewGateMarkerToClaim $marker
        if ($null -eq $claim) {
            Deny 'Run /change-review before pushing -- it writes a diff-bound review-ok marker this hook checks.'
        } elseif ($claim.Content -eq $expected) {
            Complete-ReviewGateMarkerClaim $claim
            # A push can target any remote/ref, so @{u} cannot prove whether it succeeded.
            # Decline ambiguous recovery: a failed attempt needs a fresh change review.
            Remove-Item (Join-Path $root '.claude/.pending-push-presha') -Force -ErrorAction SilentlyContinue
        } else {
            Restore-ReviewGateMarkerFromClaim $claim
            Deny 'Run /change-review before pushing -- the branch no longer matches the reviewed diff.'
        }
        break
    }
    default {
        # An unknown verdict must not fall through to exit 0, which is allow. See the .sh twin.
        Deny 'Review gate: unrecognised classifier verdict, so this command cannot be checked. The hook and scripts/_review-gate-classify.ps1 are probably from different versions; run mb upgrade from the main worktree.'
    }
}
