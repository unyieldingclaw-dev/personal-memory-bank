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
# WHY $cmdExtracted is captured here, before the raw-stdin fallback below overwrites $cmd:
# Test-TagOnlyPush() below needs to know whether $cmd is trustworthy, parsed command text or
# untrustworthy raw stdin noise -- see its own gating check for why.
$cmdExtracted = ($null -ne $cmd)
if ($null -eq $cmd) { $cmd = $raw }

# WHY match against a quote/backslash-stripped copy, not $cmd itself: a command like
# `git c"o"mmit -m "x"` executes, after the real shell's own quote removal, as a genuine
# `git commit -m x` -- but the parsed (or raw-fallback) command TEXT never contains "git commit"
# as a contiguous match for the regexes below, so every -match check would silently miss it.
# Reproduced directly: that exact payload previously exited 0 with no deny even though bash
# executes it as a real, unreviewed commit -- true even on origin/main, predating this file's
# other fixes. Stripping quote/backslash characters before matching (never from $cmd itself,
# which still needs its real quoting intact for the leading-cd-chain parsing below) can only
# ever make a match MORE likely to fire, matching this file's established "over-trigger, never
# under-gate" safety direction -- it cannot introduce a new bypass, only new (already-accepted)
# false-positive risk.
$cmdStripped = $cmd -replace '["''\\]', ''

# Get-NextSubcommand — walks $Tokens from $Start, skipping recognized flag tokens (an
# --opt=value attached form, a recognized value-taking flag plus its following token, or any
# other single flag token), and returns the first remaining non-flag token plus the index just
# past it. Returns $null if the tokens run out without finding one.
#
# WHY -ccontains (case-sensitive) against the raw token, not -contains against $t.ToLower():
# PowerShell's -contains does a case-INSENSITIVE comparison by default, so `-r` (not a real gh
# global option) was silently matching the real `-R` entry in $OptsWithValue -- causing
# `gh -r pr merge 8` to have `-r` misclassified as a value-consuming flag, which then consumed
# `pr` as if it were `-r`'s value and left `merge` looking like the (wrong) subcommand,
# silently defeating the `sub -eq 'pr'` check entirely. Reproduced directly: that exact payload
# was NOT denied by the unconditional `gh pr merge` control -- a live bypass on this file, the
# PREFERRED runtime. Real git/gh flags are themselves case-sensitive (`-c`/`-C` are different
# git options; gh has no `-r` at all, only `-R`), so case-sensitive matching here is also more
# accurate to what these tools actually accept, not just a security patch.
function Get-NextSubcommand {
    param([string[]]$Tokens, [int]$Start, [string[]]$OptsWithValue)
    $i = $Start
    while ($i -lt $Tokens.Count) {
        $t = $Tokens[$i]
        if ($t.StartsWith('--') -and $t.Contains('=')) { $i++; continue }
        if ($OptsWithValue -ccontains $t) { $i += 2; continue }
        if ($t.StartsWith('-')) { $i++; continue }
        return @($t, ($i + 1))
    }
    return @($null, $i)
}

# Get-CommandTargets — an ADDITIONAL commit/push/merge detector, layered on TOP of
# $cmdStripped's regex check below, never a replacement for it; native-PowerShell counterpart
# to review-reminders.sh's classify_targets(): splits $Command on shell control operators
# (&&/||/;/|) into simple commands, tokenizes each by whitespace (so multi-space/tab/newline
# variants that `-match`'s `\s+` already handled continue to work, and any variant bash's
# tr-based approach couldn't), and for each git/gh invocation skips recognized global options
# (-C <path>, -c <name>=<value>, --opt=value forms, -R/--repo, etc.) to find the REAL
# subcommand -- not just whatever text happens to follow the literal substring "git "/"gh ".
#
# WHY this exists, beyond $cmdStripped above: `git -C /path commit -m x` and
# `git -c user.name=z commit -m x` are ordinary, idiomatic git invocations -- not adversarial
# obfuscation, an agent naturally reaches for `-C` when working across directories -- whose
# text never matches 'git\s+commit\b' as a contiguous run, so $cmdStripped's regex missed them
# entirely. Found via this session's opposition-review pass: the same underlying class of gap
# as the quote-split bug, just in git's own argument syntax instead of shell quoting.
#
# WHY additive (OR'd with $cmdStripped's regex), not a primary detector that can suppress the
# regex check: an earlier version of this fix treated "Get-CommandTargets ran and returned a
# non-null result" as authoritative and skipped $cmdStripped's regex whenever that happened --
# but a recognized head token of exactly "git"/"gh" does NOT match `/usr/bin/git commit`,
# `env git commit`, or any other perfectly ordinary indirect invocation. That version silently
# allowed those through with no deny at all -- a real regression, since $cmdStripped's regex
# alone (still active pre-this-fix) already caught them. Running both checks and OR'ing the
# results means Get-CommandTargets can only ever ADD detection (the -C/-c/whitespace-variant
# forms it understands), never remove coverage $cmdStripped's regex already had.
#
# WHY only the realistic, commonly-used global options are recognized, not a complete
# reimplementation of git's/gh's argument grammar: an unrecognized flag just means
# Get-CommandTargets might miss detecting that specific invocation shape -- harmless given
# $cmdStripped's regex underneath still covers the literal-substring case, and the safe
# direction for an unknown flag is to still treat the next token as a possible subcommand
# (more likely to trigger, never less). No dependency added: this is native PowerShell, unlike
# review-reminders.sh's python3-based classify_targets(), since this file is the PREFERRED
# runtime and shouldn't need a non-native dependency for this detection path.
function Get-CommandTargets {
    param([string]$Command)
    $gitOptsWithValue = @('-c', '-C', '--git-dir', '--work-tree', '--namespace', '--super-prefix', '--exec-path', '--attr-source')
    $ghOptsWithValue = @('-R', '--repo', '--hostname')

    $found = [System.Collections.Generic.HashSet[string]]::new()
    $segments = [regex]::Split($Command, '(?:&&|\|\||;|\|)')
    foreach ($seg in $segments) {
        $tokens = @($seg.Trim() -split '\s+' | Where-Object { $_ -ne '' })
        if ($tokens.Count -eq 0) { continue }
        $head = $tokens[0].ToLower()
        if ($head -eq 'git') {
            $gitSub, $null1 = Get-NextSubcommand -Tokens $tokens -Start 1 -OptsWithValue $gitOptsWithValue
            if ($gitSub -and $gitSub.ToLower() -eq 'commit') { [void]$found.Add('commit') }
            elseif ($gitSub -and $gitSub.ToLower() -eq 'push') { [void]$found.Add('push') }
        } elseif ($head -eq 'gh') {
            $sub1, $nextIdx = Get-NextSubcommand -Tokens $tokens -Start 1 -OptsWithValue $ghOptsWithValue
            if ($sub1 -and $sub1.ToLower() -eq 'pr') {
                $sub2, $null2 = Get-NextSubcommand -Tokens $tokens -Start $nextIdx -OptsWithValue $ghOptsWithValue
                if ($sub2 -and $sub2.ToLower() -eq 'merge') { [void]$found.Add('merge') }
            }
        }
    }
    return $found
}

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

# Test-TagOnlyPush — see the matching (much more extensively commented) tag_only_push() in
# review-reminders.sh: exempts a detected $needsPush from the diff-bound marker requirement
# when EVERY `git push` invocation in the (possibly compound) command targets only a tag,
# never a branch -- either an already-existing tag, or one this SAME command creates via its
# own `git tag <name> ...` half (the tag doesn't need to already exist locally, since creating
# one is itself just labeling an existing commit, never introducing new code -- this is what
# makes `git tag v1.8.0 origin/main && git push origin v1.8.0` exemptable even though the tag
# genuinely doesn't exist yet when this hook fires, before either half of the compound command
# has run). A tag push cannot introduce unreviewed code into origin the way a branch push can,
# since it doesn't change any branch's content. See docs/superpowers/specs/2026-08-03-review-
# gate-tag-push-exemption-design.md for the full writeup and rejected alternatives. Every
# ambiguous or unrecognized shape (0/1/3+ positional args after `push`, --delete, --tags mixed
# with an explicit refspec, a refspec that's neither an existing nor about-to-be-created tag)
# falls through to "not exempt" -- an unrecognized shape only ever costs an unnecessary
# re-review, never grants an unearned exemption. Native PowerShell, no new dependency,
# matching this file's PREFERRED-runtime convention (review-reminders.sh's counterpart uses
# python3, since bash has no equivalent built-in tokenizer).
function Test-TagOnlyPush {
    param([string]$Command)
    $gitOptsWithValue = @('-c', '-C', '--git-dir', '--work-tree', '--namespace', '--super-prefix', '--exec-path', '--attr-source')
    $pushOptsWithValue = @('-o')
    $tagOptsWithValue = @('-m', '-F', '-u', '--local-user', '--cleanup')
    $tagNoncreateFlags = @('-d', '--delete', '-l', '--list', '-v', '--verify')

    $segments = [regex]::Split($Command, '(?:&&|\|\||;|\|)')
    $simples = New-Object System.Collections.Generic.List[object]
    foreach ($seg in $segments) {
        $tokens = @($seg.Trim() -split '\s+' | Where-Object { $_ -ne '' })
        if ($tokens.Count -gt 0) { $simples.Add($tokens) }
    }

    # WHY the bounds check happens BEFORE indexing with a range, not after: PowerShell's `..`
    # range operator on a reversed range (e.g. `5..4`) produces a DESCENDING sequence (5,4)
    # rather than an empty result or an error -- silently reading past the intended slice.
    # Guarding first avoids ever constructing a reversed range at all.
    #
    # WHY BOTH this scriptblock's own return AND every call site below wrap the result in
    # @(...): PowerShell unwraps a 1-element array to its bare scalar element at TWO separate
    # points, and both had to be caught independently. First, `$Simple[2..2]` (a range that
    # resolves to exactly one index) itself returns the single element unwrapped, not a
    # 1-element array -- fixed by wrapping the range indexing here. Second, and separately:
    # even after that fix, capturing this scriptblock's `return`ed 1-element array via plain
    # assignment (`$x = & $restArgs ...`) unwraps it AGAIN at the call site, because any
    # PowerShell function/scriptblock's output stream collapses a 1-item collection back to a
    # scalar when captured -- confirmed by direct inspection: the value was still a proper
    # `System.Object[]` of length 1 *inside* this scriptblock, right up until the `return`
    # crossed back out to the caller. For a single-token push-args result like `--tags`, either
    # unwrapping alone means the caller ends up iterating a bare STRING with `[$i]`, which
    # yields individual [char]s, not [string] tokens -- `$t.StartsWith(...)` then fails
    # outright ([char] has no such method). Reproduced directly: `git push --tags` (whose only
    # push-arg is the single token `--tags`) threw exactly this error. Both wrap points are
    # required; removing either one reintroduces the bug for exactly the 1-token case.
    $restArgs = {
        param($Simple, $StartIdx)
        if ($StartIdx -ge $Simple.Count) { return @() }
        return @($Simple[$StartIdx..($Simple.Count - 1)])
    }

    $createdTagNames = [System.Collections.Generic.HashSet[string]]::new()
    foreach ($simple in $simples) {
        if ($simple[0].ToLower() -ne 'git') { continue }
        $sub, $nextIdx = Get-NextSubcommand -Tokens $simple -Start 1 -OptsWithValue $gitOptsWithValue
        if (-not $sub -or $sub.ToLower() -ne 'tag') { continue }
        $tagArgs = @(& $restArgs $simple $nextIdx)
        $noncreate = $false
        $positional = @()
        $i = 0
        while ($i -lt $tagArgs.Count) {
            $t = $tagArgs[$i]
            if ($tagNoncreateFlags -ccontains $t) { $noncreate = $true; $i++; continue }
            if ($t.StartsWith('--') -and $t.Contains('=')) { $i++; continue }
            if ($tagOptsWithValue -ccontains $t) { $i += 2; continue }
            if ($t.StartsWith('-')) { $i++; continue }
            $positional += $t
            $i++
        }
        if ($noncreate -or $positional.Count -eq 0) { continue }
        [void]$createdTagNames.Add($positional[0])
    }

    $pushInvocations = 0
    $allExempt = $true
    foreach ($simple in $simples) {
        if ($simple[0].ToLower() -ne 'git') { continue }
        $sub, $nextIdx = Get-NextSubcommand -Tokens $simple -Start 1 -OptsWithValue $gitOptsWithValue
        if (-not $sub -or $sub.ToLower() -ne 'push') { continue }
        $pushInvocations++
        $pushArgs = @(& $restArgs $simple $nextIdx)
        $positional = @()
        $hasTagsFlag = $false
        $hasDeleteFlag = $false
        $i = 0
        while ($i -lt $pushArgs.Count) {
            $t = $pushArgs[$i]
            if ($t -eq '--tags') { $hasTagsFlag = $true; $i++; continue }
            if ($t -eq '-d' -or $t -eq '--delete') { $hasDeleteFlag = $true; $i++; continue }
            if ($t.StartsWith('--') -and $t.Contains('=')) { $i++; continue }
            if ($pushOptsWithValue -ccontains $t) { $i += 2; continue }
            if ($t.StartsWith('-')) { $i++; continue }
            $positional += $t
            $i++
        }

        if ($hasDeleteFlag) { $allExempt = $false; continue }

        if ($hasTagsFlag) {
            if ($positional.Count -le 1) { continue }
            $allExempt = $false
            continue
        }

        if ($positional.Count -ne 2) { $allExempt = $false; continue }

        $src = $positional[1].Split(':')[0]
        if ($createdTagNames.Contains($src) -or (Test-ExistingTag $src)) { continue }
        $allExempt = $false
    }

    return ($pushInvocations -gt 0 -and $allExempt)
}

# Test-ExistingTag — resolves $Name against ground truth (git show-ref), never a naming
# heuristic: `git push origin v1.8.0` is syntactically identical whether v1.8.0 resolves
# locally to a tag or a branch, so this asks git directly, and requires the tag to exist
# WITHOUT a same-named branch also existing -- an ambiguous name (both a tag and a branch)
# falls through to "not exempt", the safe direction.
function Test-ExistingTag {
    param([string]$Name)
    if (-not $Name) { return $false }
    if ($Name.StartsWith('refs/') -and -not $Name.StartsWith('refs/tags/')) { return $false }
    $bare = if ($Name.StartsWith('refs/tags/')) { $Name.Substring(10) } else { $Name }
    git show-ref --verify --quiet "refs/tags/$bare" 2>$null
    if ($LASTEXITCODE -ne 0) { return $false }
    git show-ref --verify --quiet "refs/heads/$bare" 2>$null
    return ($LASTEXITCODE -ne 0)
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
    # WHY suffix with $PID, matching review-reminders.sh's consume_marker() ($marker.claimed.$$):
    # without a per-process uniquifier, two concurrent claim attempts (or a claim racing a
    # crashed prior attempt's leftover claimed file) could both target the same destination
    # name -- Move-Item -Force below would silently overwrite one attempt's claimed content
    # with another's before it's ever read, corrupting or misattributing a hash comparison.
    $claimed = "$Marker.claimed.$PID"
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

# WHY $cmdStripped's regex runs unconditionally first, with Get-CommandTargets's result OR'd
# in afterward, rather than Get-CommandTargets running as the primary detector whenever it can:
# an earlier version made Get-CommandTargets authoritative on the $extracted path and skipped
# the regex whenever it ran without error -- but "ran without error" only means the head token
# was recognized as exactly "git"/"gh"; it does NOT match `/usr/bin/git commit`, `env git
# commit`, or any other perfectly ordinary indirect invocation. Reproduced directly: that
# version silently allowed `/usr/bin/git commit -m x` through with no deny at all, even though
# $cmdStripped's regex alone (still active pre-this-fix) already caught it. Running both checks
# and OR'ing the results means Get-CommandTargets can only ever ADD detection, never remove
# coverage the regex already had -- the same "over-trigger, never under-gate" safety direction
# this file commits to everywhere else. Wrapped in try/catch so an unexpected exception from a
# pathological $cmd just means no additional detection, never a lost regex match. $targets may
# be $null (Get-CommandTargets threw, or PowerShell's pipeline unwrapped an empty HashSet to
# $null) -- both are treated identically to "no additional targets found" via the $null -ne
# guards below, never as a signal to skip the regex check.
$targets = $null
try {
    $targets = Get-CommandTargets -Command $cmd
} catch { }

$mergeHit = $cmdStripped -match 'gh\s+pr\s+merge\b'
$needsCommit = $cmdStripped -match 'git\s+commit\b'
$needsPush = $cmdStripped -match 'git\s+push\b'
if ($null -ne $targets) {
    if ($targets.Contains('merge')) { $mergeHit = $true }
    if ($targets.Contains('commit')) { $needsCommit = $true }
    if ($targets.Contains('push')) { $needsPush = $true }
}

# WHY Test-TagOnlyPush only runs when $needsPush is already true AND $cmdExtracted is true:
# exemption LOOSENS the gate, so (like resolve-root's use of $extracted in review-reminders.sh)
# it must only ever act on high-confidence, JSON-parsed command text. On the degraded
# raw-stdin fallback path, $cmd may be noise that merely LOOKS like a tag push without "git"
# actually being the invoked program -- granting an exemption from untrustworthy text would be
# the one place in this file where a false read makes the gate LESS safe, not just an
# unnecessary re-review. See Test-TagOnlyPush's own comment for the exemption logic itself.
if ($needsPush -and $cmdExtracted) {
    try {
        if (Test-TagOnlyPush -Command $cmd) { $needsPush = $false }
    } catch { }
}

# WHY gh pr merge is checked first, unconditionally, before commit/push classification: matches
# this file's pre-existing priority (gh pr merge was already checked as its own branch ahead of
# push in the old if/elseif chain) -- an unconditional deny needs no root/marker access, and
# checking it first means it can never coexist with a commit/push allow-path in a way that
# would try to emit two separate JSON responses for one hook invocation.
#
# WHY this check runs against $mergeHit regardless of whether $cmd came from a successful
# JSON parse or the raw-stdin fallback: an earlier version skipped this check on the fallback
# path, which reopened exactly the "no legitimate case to allow through" gap the unconditional
# deny exists to close -- a REAL `gh pr merge` command would fall straight through unchecked
# whenever JSON parsing failed. The false-positive risk of checking unconditionally (an
# unrelated command whose raw payload merely mentions "gh pr merge", e.g. in
# tool_input.description) is real but is the SAME failure direction commit/push already accept
# on this exact fallback path -- an extra, unnecessary deny, not a security hole.
if ($mergeHit) {
    Deny "This agent never merges pull requests, even with explicit instruction -- merging shared history requires a human to run the command directly. Run this gh pr merge command yourself."
    exit 0
}

# WHY commit and push were classified INDEPENDENTLY above, not via one if/elseif chain: see
# the matching comment in review-reminders.sh -- a compound Bash tool call chaining both
# (`git commit -m x && git push origin main`) matches both. An if/elseif would only ever run
# its first matching branch, so the old code validated the commit half and never even checked
# push's marker, letting an unreviewed push ride through on a valid commit marker alone.
# Reproduced directly against this exact file: seeding only a valid .code-review-ok marker let
# a compound commit+push through untouched, on pwsh -- the PREFERRED runtime.
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
