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
# WHY this also records a pre-state ref once validation succeeds, before the gated command
# itself runs: see the companion PostToolUse hook (review-reminders-post.ps1/.sh) -- if the
# gated commit/push then fails, that hook detects the relevant git ref didn't move and
# reissues the marker, so a rejected attempt (e.g. a separate pre-commit hook) doesn't force
# a pointless re-review.
#
# WHY match "git\s+commit\b" anywhere in $cmd instead of anchoring to command start/operators:
# an anchored regex (^|[;&|]\s*)git\s+commit\b misses real shapes -- multi-line Bash tool
# commands (git commit after a literal newline), a bare single "&", or nested subshells. $cmd
# is already the exact, JSON-parsed command text (not raw payload noise), so an unanchored
# match is safe: the only real risk is a false positive if "git commit" appears as a substring
# elsewhere in the command, which just means an occasional unnecessary re-review -- the safe
# failure direction for a security gate.
#
# WHY fall back to matching $raw (the raw stdin payload) instead of exiting on a JSON parse
# failure: this used to just `exit 0` on any parse failure -- silently disabling the gate
# entirely on malformed input, on the PREFERRED runtime (settings.json tries pwsh first). The
# bash sibling's extract_command() already falls back to raw-stdin matching in the equivalent
# case (over-triggering an occasional unnecessary re-review is the safe failure direction for a
# security gate; silently not gating at all is not). Matching this behavior here closes that
# asymmetry -- pwsh being the preferred runtime is exactly why it needs the same fallback, not
# less of one.
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
$raw = [Console]::In.ReadToEnd()
if ([string]::IsNullOrWhiteSpace($raw)) { exit 0 }
$cmd = $null
try {
    $parsed = $raw | ConvertFrom-Json
    if ($null -ne $parsed.tool_input.PSObject.Properties['command']) {
        $cmd = $parsed.tool_input.command
    }
} catch { }
$extracted = ($null -ne $cmd)
if ($null -eq $cmd) { $cmd = $raw }

# WHY this exists: `git rev-parse --show-toplevel` below trusts the hook process's own
# ambient cwd, which is empirically wrong for some dispatched-subagent sessions. $cmd is
# already the parsed command string (via ConvertFrom-Json above), so extracting a leading cd
# path is a plain regex, no new dependency needed. Falls back to the ambient resolution on
# any failure -- a session where ambient cwd is already correct is completely unaffected.
#
# WHY resolve the FULL leading cd chain, not just the first cd: see the matching comment in
# review-reminders.sh -- a chained command (`cd "A" && cd "B" && git commit ...`) must
# resolve to B's root, not A's, or a marker earned reviewing A wrongly authorizes a commit
# that actually runs in B. Reproduced directly against the previous single-match regex: it
# captured "A" and only "A" from that exact chained string. A single-quoted here-string
# (@'...'@) holds the pattern so both `"` and `'` can appear in it with no escaping, matching
# the bash fix's heredoc approach for the same reason.
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

# WHY Set-Location here, not -C $root on every git call below: resolving $root fixes where
# the marker is looked FOR, but the diff-hash functions and $preSha rev-parse call further
# down still run bare git commands with no directory anchor -- the same ambient-cwd
# assumption just fixed above, at different call sites. Anchoring the rest of this script to
# $root once, here, means every git call downstream is correct by construction instead of
# needing -C $root at each individual site.
try { Set-Location $root } catch { exit 0 }

# WHY hash a file written via redirection, not a piped/captured string: PowerShell's
# pipeline re-tokenizes external-command output into a line-object array and back, which
# does not reproduce the exact byte stream (trailing newline, line endings) that piping
# the same command through bash produces. Empirically confirmed: (git diff HEAD) -join
# "`n" then hashed did NOT match `git diff HEAD | sha256sum` for the identical diff.
# Redirecting to a file (`>`) writes raw bytes with no such re-tokenization on either
# platform -- confirmed empirically to produce byte-identical files (and therefore
# identical hashes) whether written from PowerShell or from bash. This matters because
# review-reminders.ps1 is the hook that actually runs on any machine with pwsh installed
# (preferred over the .sh fallback), so its hash must match what /code-review's
# instructions produce regardless of which shell the human or agent used to write it.
function Get-FileHashHex {
    param([string]$Path)
    return (Get-FileHash -Path $Path -Algorithm SHA256).Hash.ToLower()
}

function Get-CommitDiffHash {
    $tmp = [System.IO.Path]::GetTempFileName()
    try {
        git diff HEAD > $tmp 2>$null
        return Get-FileHashHex $tmp
    } finally {
        Remove-Item $tmp -Force -ErrorAction SilentlyContinue
    }
}

function Get-PushDiffHash {
    $tmp = [System.IO.Path]::GetTempFileName()
    try {
        git diff origin/main...HEAD > $tmp 2>$null
        if ($LASTEXITCODE -ne 0) {
            git diff HEAD > $tmp 2>$null
        }
        return Get-FileHashHex $tmp
    } finally {
        Remove-Item $tmp -Force -ErrorAction SilentlyContinue
    }
}

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

# WHY gh pr merge is checked first, unconditionally, before commit/push classification: matches
# this file's pre-existing priority (gh pr merge was already checked as its own branch ahead of
# push in the old if/elseif chain) -- an unconditional deny needs no root/marker access, and
# checking it first means it can never coexist with a commit/push allow-path in a way that
# would try to emit two separate JSON responses for one hook invocation.
#
# WHY this check runs against $cmd regardless of $extracted, unlike the extracted-only skip
# this file used to apply here: that skip was found, on review, to reopen exactly the "no
# legitimate case to allow through" gap the unconditional deny exists to close -- if
# ConvertFrom-Json fails (malformed/unexpected payload), extraction fails, and a REAL
# `gh pr merge` command would fall straight through unchecked, silently disabling the one
# control in this file explicitly designed to have zero override. The false-positive risk this
# used to guard against (an unrelated command whose raw payload merely mentions "gh pr merge",
# e.g. in tool_input.description) is real but is the SAME failure direction commit/push already
# accept on this exact fallback path -- an extra, unnecessary deny, not a security hole.
if ($cmd -match 'gh\s+pr\s+merge\b') {
    Deny "This agent never merges pull requests, even with explicit instruction -- merging shared history requires a human to run the command directly. Run this gh pr merge command yourself."
    exit 0
}

# WHY commit and push are classified and validated INDEPENDENTLY, not via one if/elseif
# chain: see the matching comment in review-reminders.sh -- a compound Bash tool call chaining
# both (`git commit -m x && git push origin main`) matches BOTH regexes. An if/elseif only ever
# runs its first matching branch, so the old code validated the commit half and never even
# checked push's marker, letting an unreviewed push ride through on a valid commit marker
# alone. Reproduced directly against this exact file: seeding only a valid .code-review-ok
# marker let a compound commit+push through untouched, on pwsh -- the PREFERRED runtime.
$needsCommit = $cmd -match 'git\s+commit\b'
$needsPush = $cmd -match 'git\s+push\b'
$commitOk = $true
$pushOk = $true

if ($needsCommit) {
    $commitExpected = Get-CommitDiffHash
    $marker = Join-Path $root '.claude/.code-review-ok'
    if (-not (Test-AndConsumeMarker $marker $commitExpected)) { $commitOk = $false }
}

if ($needsPush) {
    $pushExpected = Get-PushDiffHash
    $marker = Join-Path $root '.claude/.change-review-ok'
    if (-not (Test-AndConsumeMarker $marker $pushExpected)) { $pushOk = $false }
}

if ($needsCommit -and -not $commitOk -and $needsPush -and -not $pushOk) {
    Deny "Run /code-review before committing and /change-review before pushing -- this is a combined commit+push command and both diff-bound review-ok markers are required. Neither is present/valid."
} elseif ($needsCommit -and -not $commitOk) {
    Deny "Run /code-review before committing -- it writes a diff-bound review-ok marker this hook checks. If you already reviewed, the working tree changed since then; re-run /code-review."
} elseif ($needsPush -and -not $pushOk) {
    Deny "Run /change-review before pushing -- it writes a diff-bound review-ok marker this hook checks. If you already reviewed, the diff changed since then; re-run /change-review."
} else {
    # WHY also persist the just-validated expected hash (.pending-commit-hash/.pending-push-
    # hash): see review-reminders-post.ps1's matching comment -- lets the post-hook replay the
    # ORIGINAL validated hash on reissue instead of recomputing a fresh one that may reflect a
    # tree mutated by a downstream project's own pre-commit hook after this validation ran.
    if ($needsCommit) {
        $preSha = git rev-parse HEAD 2>$null
        if ($preSha) {
            $preSha | Set-Content (Join-Path $root '.claude/.pending-commit-presha')
            $commitExpected | Set-Content (Join-Path $root '.claude/.pending-commit-hash')
        }
    }
    if ($needsPush) {
        $preSha = git rev-parse '@{u}' 2>$null
        if ($preSha) {
            $preSha | Set-Content (Join-Path $root '.claude/.pending-push-presha')
            $pushExpected | Set-Content (Join-Path $root '.claude/.pending-push-hash')
        }
    }
}
