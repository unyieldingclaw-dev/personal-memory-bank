<#
.SYNOPSIS
    PreToolUse hook — 3-tier dangerous command guardrails for Claude Code.
.DESCRIPTION
    Reads the Bash tool input JSON from stdin, extracts the command string,
    and enforces BLOCK / CONFIRM / WARN tier matching via simple substring and
    regex checks. All output goes to stdout so messages are visible even when
    stderr is suppressed. Fails open on a genuine read failure (empty stdin):
    prints [HOOK ERROR] and exits 0. On a JSON-parse failure with non-empty
    stdin, falls back to matching tier patterns against the raw payload instead
    of exiting immediately -- see the WHY comment on the catch block below.

    WHY hookSpecificOutput.permissionDecision, not exit code: top-level exit codes are
    unreliable here -- settings.json wires this hook as "... 2>/dev/null || bash ... || true"
    for cross-platform fail-open portability, and that "|| true" suffix silently converts any
    nonzero exit code to 0. This was empirically confirmed while building review-reminders.ps1:
    a hook using "exit 1" to signal block did not actually prevent the tool call from running.
    hookSpecificOutput.permissionDecision = "deny" is read from stdout JSON regardless of the
    wrapping shell's final exit code, so it's the only reliable way to actually block.
#>

param()

# Centralized tier messages — all pattern matches use these templates, no custom text per pattern.
$BLOCK_MSG   = "BLOCK: {0}. Refusing this command."
$CONFIRM_MSG = "CONFIRM REQUIRED: {0}. Run manually if intentional."
$WARN_MSG    = "WARNING: {0}. Proceeding."

try {
    # WHY: $input | Out-String matches how update-reviewed.ps1 reads stdin from Claude Code hooks.
    $raw = $input | Out-String
    if ([string]::IsNullOrWhiteSpace($raw)) { exit 0 }
    $data = $raw | ConvertFrom-Json -ErrorAction Stop
    # WHY .tool_input.command, not .command: the real payload nests everything under
    # "tool_input" (e.g. {"tool_name":"Bash","tool_input":{"command":"..."}}), confirmed
    # by capturing a live hook payload. The prior version read $data.command (flat),
    # which is always null against the real payload shape -- $cmd was always "", so no
    # BLOCK/CONFIRM/WARN pattern has ever matched anything, regardless of exit code.
    $cmd = if ($data.tool_input.command) { [string]$data.tool_input.command } else { "" }
} catch {
    # WHY fall back to raw-stdin matching (not exit 0 immediately) on a JSON-parse
    # failure: mirrors dangerous-commands.sh's identical fallback exactly — a real
    # dangerous command's text is still present somewhere in the raw payload even when
    # structured extraction fails, so raw matching never misses a true positive, it
    # only risks occasional false ones. Exiting immediately here would silently
    # disable the guardrail entirely on a parse error, the wrong direction for a
    # safety gate. Only applies when $raw was actually captured (the IsNullOrWhiteSpace
    # early-exit above already handles the genuine "nothing to check" case, which
    # this catch block never reaches).
    if ($raw) {
        $cmd = $raw
        try { Add-Content ".pmb-hook-errors.log" "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] [HOOK] dangerous-commands.ps1: JSON parse failed, fell back to raw-stdin matching: $_" -ErrorAction SilentlyContinue } catch { Write-Verbose "Could not write .pmb-hook-errors.log; ignoring." }
    } else {
        Write-Host "[HOOK ERROR] dangerous-commands.ps1 failed unexpectedly."
        Write-Host "Proceeding in fails-open mode."
        try { Add-Content ".pmb-hook-errors.log" "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] [HOOK] dangerous-commands.ps1: $_" -ErrorAction SilentlyContinue } catch { Write-Verbose "Could not write .pmb-hook-errors.log; ignoring." }
        exit 0
    }
}

# WHY normalize tabs to spaces here, once, before any tier matching: code review found
# that this file's boundary regex used \s (Unicode-aware, matches NBSP and other
# Unicode space separators) while dangerous-commands.sh's confirm_boundary() used the
# POSIX [[:space:]] class (locale-dependent, typically ASCII-only) -- a single-character
# substitution (e.g. an NBSP in place of the space after "git merge") silently bypassed
# the CONFIRM gate on one platform but not the other, verified by direct execution.
# Normalizing tabs to spaces up front lets both boundary checks compare against a plain
# literal space -- no character classes, no locale/Unicode ambiguity, byte-identical
# semantics on both platforms. This intentionally does NOT normalize other Unicode
# whitespace (NBSP, em-space, etc.) to a boundary character on either side: those stay
# non-boundaries consistently everywhere, rather than a boundary on one platform only.
$cmd = $cmd.Replace("`t", " ")

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

# BLOCK: irreversible or highly destructive — refuse unconditionally
$blockPatterns = @(
    @{ pattern = "rm -rf";           reason = "irreversible recursive deletion" }           # WHY: recursive deletion is irreversible
    @{ pattern = "mkfs";             reason = "filesystem format" }                          # WHY: formats/destroys entire filesystem
    @{ pattern = "dd if=";           reason = "disk wipe or dump" }                         # WHY: raw disk access, wipes or dumps data
    @{ pattern = "git push --force"; reason = "force push (long form)" }                    # WHY: rewrites remote history irreversibly
    @{ pattern = "git push -f";      reason = "force push (short form)" }                   # WHY: same as --force, short flag form
    @{ pattern = "DROP TABLE";       reason = "SQL table drop" }                            # WHY: irreversible schema destruction
    @{ pattern = "DROP DATABASE";    reason = "SQL database drop" }                         # WHY: destroys entire database
    @{ pattern = '\|\s*bash\b'; regex = $true; reason = "command piped to bash (curl|bash, wget|bash, etc.)" } # WHY: remote code execution vector. Regex with \b (not a plain substring): matches both spaced ("| bash") and unspaced ("|bash") forms in one pattern.
    @{ pattern = '\|\s*sh\b';   regex = $true; reason = "command piped to sh" }              # WHY: remote code execution via sh. WHY regex, not substring: a plain "| sh" substring check false-positives on any command containing "| sha256sum", "| shasum", etc. -- tools this repo's own review-gate hash verification depends on (found when fixing the field-path bug that had made this pattern a no-op made this collision real). \b requires "sh" to end at a word boundary, so "sha256sum" (sh immediately followed by "a", no boundary) doesn't match, but a literal pipe-to-sh interpreter does.
    # PowerShell-native equivalents (triggered by the PowerShell tool)
    @{ pattern = "Remove-Item -Recurse -Force"; reason = "recursive force deletion (PowerShell rm -rf equivalent)" }         # WHY: Remove-Item -Recurse -Force is the PS equivalent of rm -rf
    @{ pattern = "Remove-Item -Force -Recurse"; reason = "recursive force deletion (PowerShell rm -rf, flags reversed)" }   # WHY: same as above — flag order varies in real commands
    @{ pattern = "Format-Volume";               reason = "disk volume format (PowerShell)" }                                # WHY: destroys all data on a volume
    @{ pattern = "| Invoke-Expression";         reason = "command piped to Invoke-Expression (PS code execution)" }         # WHY: pipe-to-iex is the PS equivalent of pipe-to-bash
    @{ pattern = "|Invoke-Expression";          reason = "command piped to Invoke-Expression (no-space form)" }             # WHY: no-space form evades space-prefixed pattern
    @{ pattern = "| iex";                       reason = "command piped to iex (PS eval shorthand)" }                      # WHY: iex is the common alias for Invoke-Expression
    @{ pattern = "|iex";                        reason = "command piped to iex (no-space form)" }                          # WHY: no-space form evades space-prefixed pattern
)

foreach ($entry in $blockPatterns) {
    $isMatch = if ($entry.regex) { $cmd -imatch $entry.pattern } else { $cmd.Contains($entry.pattern, [System.StringComparison]::OrdinalIgnoreCase) }
    if ($isMatch) {
        Deny ($BLOCK_MSG -f $entry.reason)
        exit 0
    }
}

# CONFIRM: advanced ops with legitimate uses — require explicit manual invocation
$confirmPatterns = @(
    @{ pattern = "git filter-branch"; reason = "history rewriting" }                        # WHY: rewrites commit history, rarely intentional
    @{ pattern = "git update-ref";    reason = "low-level ref manipulation" }               # WHY: low-level plumbing, bypasses safety checks
    @{ pattern = "sudo rm";           reason = "privileged deletion" }                      # WHY: elevated deletion can remove system files
    @{ pattern = "chmod -R 777";      reason = "world-writable recursive chmod" }           # WHY: makes entire tree world-writable
    @{ pattern = "--no-verify";       reason = "bypasses pre-commit hooks (local governance)" } # WHY: skips safety hooks on commit
    # WHY regex, not a plain substring: "git merge" as a bare substring also matches
    # "git merge-base", a common, harmless read-only command — the character after
    # "merge" there is "-", not a word boundary in the usual sense. Requiring
    # space-or-end-of-string after "merge" excludes that case while still matching
    # "git merge <branch>", "git merge --no-ff <branch>", and bare "git merge". WHY a
    # literal space, not \s, on the trailing side: $cmd already had tabs normalized to
    # spaces before this pattern ever runs (see the .Replace("`t"," ") call above), and
    # dangerous-commands.sh does the same normalization -- so both sides only ever need
    # to check for a plain ASCII space here, with no \s-vs-[[:space:]] Unicode/locale
    # ambiguity to keep in parity (an earlier version used \s, which -- unlike bash's
    # [[:space:]] under the C/POSIX locale -- also matches NBSP and other Unicode space
    # separators; that mismatch let an NBSP-substituted "git merge" silently bypass the
    # CONFIRM gate on bash but not PowerShell, found by code review and verified by
    # direct execution).
    # WHY a leading boundary too (^|[^a-zA-Z]) (found by code review, not present in
    # the original version): without one, the pattern also matches as a substring of
    # a longer word — e.g. "git commit -m 'legit merge of feature A'" contains the
    # literal substring "git merge " inside "le-GIT- -MERGE-of", which would wrongly
    # trigger CONFIRM. Requiring the character before "git" to be absent (start of
    # string) or not a letter closes that gap. Mirrors dangerous-commands.sh's
    # confirm_boundary() leading-boundary fix exactly, for sh/ps1 parity.
    @{ pattern = '(^|[^a-zA-Z])git merge( |$)'; regex = $true; reason = "merge into a shared/base branch — standards/SECURITY-GUARDRAILS.md CONFIRM tier" } # WHY: precipitating incident for that CONFIRM-tier row was a plain `git merge`, not `gh pr merge` (already denied elsewhere)
)

foreach ($entry in $confirmPatterns) {
    $isMatch = if ($entry.regex) { $cmd -imatch $entry.pattern } else { $cmd.Contains($entry.pattern, [System.StringComparison]::OrdinalIgnoreCase) }
    if ($isMatch) {
        Deny ($CONFIRM_MSG -f $entry.reason)
        exit 0
    }
}

# WARN: credential/secrets access — legitimate workflows exist, surface the access only
# (advisory only — no permissionDecision set, so the command proceeds)
$warnPatterns = @(
    @{ pattern = "id_rsa";           reason = "SSH private key access" }                    # WHY: SSH private key — may be intentional (key setup)
    @{ pattern = ".pem";             reason = "certificate or key file access" }            # WHY: cert/key files — may be intentional (TLS mgmt)
    @{ pattern = ".env.production";  reason = "production secrets file" }                   # WHY: production secrets — surface access, don't block
    @{ pattern = "credentials.json"; reason = "credential file access" }                    # WHY: credential file — may be intentional (auth setup)
)

foreach ($entry in $warnPatterns) {
    if ($cmd.Contains($entry.pattern, [System.StringComparison]::OrdinalIgnoreCase)) {
        Write-Host ($WARN_MSG -f $entry.reason)
    }
}

exit 0
