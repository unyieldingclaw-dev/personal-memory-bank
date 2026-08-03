# PreToolUse hook — blocks git commit/push until the matching review slash command has run.
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
# WHY this also records a pre-state SHA before consuming the marker: see the companion
# PostToolUse hook (review-reminders-post.ps1/.sh) -- if the gated commit/push then fails,
# that hook detects the relevant git ref didn't move and reissues the marker, so a rejected
# attempt (e.g. a separate pre-commit hook) doesn't force a pointless re-review.
#
# WHY match "git\s+commit\b" anywhere in $cmd instead of anchoring to command start/operators:
# an anchored regex (^|[;&|]\s*)git\s+commit\b misses real shapes -- multi-line Bash tool
# commands (git commit after a literal newline), a bare single "&", or nested subshells. $cmd
# is already the exact, JSON-parsed command text (not raw payload noise), so an unanchored
# match is safe: the only real risk is a false positive if "git commit" appears as a substring
# elsewhere in the command, which just means an occasional unnecessary re-review -- the safe
# failure direction for a security gate.
#
# WHY `gh pr merge` gets an unconditional deny instead of a third diff-bound marker: by the
# time a PR is mergeable, its diff already passed the commit gate, the push gate, and (per
# branch protection's required-status-checks with strict:true) CI on the current head -- a
# third hash gate here would mostly re-verify what's already verified, while adding real
# fragility (PR-number/--repo parsing, a `gh pr diff` API call inside a hook). The actual gap
# at merge time isn't diff integrity, it's authorization: merging changes shared history and
# should never happen without the user deciding to do it in that moment, and a hash can't
# encode "the user meant this right now." This hook can only ever see commands *this agent*
# runs -- the user's own terminal is invisible to it -- so an unconditional deny is both
# correct and total: if this hook fires at all, it's the agent trying to merge, never the
# user, so there is no legitimate case to allow through.
#
# WHY hookSpecificOutput.permissionDecision, not top-level "continue": top-level
# {"continue": false} only stops the agent's turn *after* the tool call has already run --
# it does not prevent execution. Verified empirically: an earlier version of this hook using
# {"continue": false} let a real `git commit` through untouched, then interrupted the next
# turn. hookSpecificOutput.permissionDecision = "deny" is the mechanism that actually denies
# the tool call before it executes.
#
# Get-FileHashHex/Get-CommitDiffHash/Get-PushDiffHash/Resolve-CdRoot are defined in
# _review-gate-lib.ps1 -- see that file for their WHY (byte-parity hashing, worktree-safe
# root resolution). Dot-sourced inside this same try/catch so a missing/corrupt lib fails
# open (exit 0, gate skipped) exactly like a malformed stdin payload does.
try {
    $raw = [Console]::In.ReadToEnd()
    if ([string]::IsNullOrWhiteSpace($raw)) { exit 0 }
    $cmd = ($raw | ConvertFrom-Json).tool_input.command
    . (Join-Path $PSScriptRoot "_review-gate-lib.ps1")
} catch { exit 0 }

if (-not $cmd) { exit 0 }

# WHY this exists: `git rev-parse --show-toplevel` below trusts the hook process's own
# ambient cwd, which is empirically wrong for some dispatched-subagent sessions. $cmd is
# already the parsed command string (via ConvertFrom-Json above), so extracting a leading cd
# path is a plain regex, no new dependency needed. Falls back to the ambient resolution on
# any failure -- a session where ambient cwd is already correct is completely unaffected.
$cdRoot = Resolve-CdRoot -Cmd $cmd
$root = if ($cdRoot) { $cdRoot } else { git rev-parse --show-toplevel 2>$null }
if (-not $root) { exit 0 }

# WHY Set-Location here, not -C $root on every git call below: resolving $root fixes where
# the marker is looked FOR, but the diff-hash functions and $preSha rev-parse call further
# down still run bare git commands with no directory anchor -- the same ambient-cwd
# assumption just fixed above, at different call sites. Anchoring the rest of this script to
# $root once, here, means every git call downstream is correct by construction instead of
# needing -C $root at each individual site.
try { Set-Location $root } catch { exit 0 }

function Deny {
    param([string]$Reason)
    @{
        hookSpecificOutput = @{
            hookEventName            = "PreToolUse"
            permissionDecision       = "deny"
            permissionDecisionReason = $Reason
        }
    } | ConvertTo-Json -Compress | Write-Output
}

function Test-AndConsumeMarker {
    param([string]$Marker, [string]$ExpectedHash)
    $claimed = "$Marker.claimed"
    try {
        Move-Item -Path $Marker -Destination $claimed -Force -ErrorAction Stop
    } catch {
        return $false
    }
    $content = $null
    try { $content = (Get-Content $claimed -Raw -ErrorAction Stop).Trim() } catch { Write-Verbose "Could not read consumed marker '$claimed'; treating as empty." }
    Remove-Item $claimed -Force -ErrorAction SilentlyContinue
    return ($content -and $content -eq $ExpectedHash)
}

if ($cmd -match 'git\s+commit\b') {
    $expected = Get-CommitDiffHash
    $marker = Join-Path $root '.claude/.code-review-ok'
    if (Test-AndConsumeMarker $marker $expected) {
        $preSha = git rev-parse HEAD 2>$null
        if ($preSha) { $preSha | Set-Content (Join-Path $root '.claude/.pending-commit-presha') }
    } else {
        Deny "Run /code-review before committing -- it writes a diff-bound review-ok marker this hook checks. If you already reviewed, the working tree changed since then; re-run /code-review."
    }
} elseif ($cmd -match 'git\s+push\b') {
    $expected = Get-PushDiffHash
    $marker = Join-Path $root '.claude/.change-review-ok'
    if (Test-AndConsumeMarker $marker $expected) {
        $preSha = git rev-parse '@{u}' 2>$null
        if ($preSha) { $preSha | Set-Content (Join-Path $root '.claude/.pending-push-presha') }
    } else {
        Deny "Run /change-review before pushing -- it writes a diff-bound review-ok marker this hook checks. If you already reviewed, the diff changed since then; re-run /change-review."
    }
} elseif ($cmd -match 'gh\s+pr\s+merge\b') {
    Deny "This agent never merges pull requests, even with explicit instruction -- merging shared history requires a human to run the command directly. Run this gh pr merge command yourself."
}
