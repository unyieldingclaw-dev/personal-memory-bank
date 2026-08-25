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

# WHY join backslash-newline continuations before any tier matching: the shell parser
# removes a backslash followed by a newline before the command ever reaches git, so
#     git config commit.gpgsign \
#       false
# executes exactly as `git config commit.gpgsign false`. The hook receives the raw two-line
# text, and no pattern's key-to-value glue matches a backslash or a newline -- so the gate
# stayed silent while signing was genuinely disabled. See dangerous-commands.sh for the live
# verification and the full rationale; this predates the commit-signing patterns and is not
# specific to them (a BLOCK substring such as "git push --force" was equally evadable).
#
# WHY $cmd globally rather than a separate copy for one tier: the goal is to make the hook's
# view match what the shell will actually run, which is correct for every tier.
#
# WHY \r? is present: the payload may carry CRLF on Windows, and the backslash must still be
# recognized as line-final. The sh twin's awk rule matches /\\[\r]?$/ for the same reason.
#
# The first attempt replaced only the backslash-newline and left the continuation line's
# indentation. That works for the signing regexes, which glue with ` *`, but silently broke
# the BLOCK tier -- those are literal substrings, so "git push \<newline>  --force" joined to
# "git push   --force" and no longer contained "git push --force".
# WHY the join DELETES rather than substitutes, with whitespace collapsed separately: shell
# backslash-newline elision inserts nothing. Substituting a space broke the no-whitespace case
# ("rm -r\<nl>f" -> "rm -r f", losing the literal "rm -rf"), while not stripping the indent broke
# the indented case ("git push \<nl>  --force" -> "git push   --force"). Both were live bypasses
# found by review. Deletion reproduces the shell; collapsing blank runs reproduces its
# tokenization. See dangerous-commands.sh for the full history.
# The property this protects, which must survive any future edit here: dangerous-commands.ps1's
# boundary regex uses \s (Unicode-aware, matches NBSP and other Unicode space separators) while
# dangerous-commands.sh's confirm_boundary() uses POSIX [[:space:]] (locale-dependent, typically
# ASCII-only). A single-character substitution -- an NBSP in place of the space after "git merge"
# -- therefore bypassed the CONFIRM gate on one platform but not the other, verified by direct
# execution. Folding tabs to a plain literal space lets both boundary checks compare against one
# ASCII character, with no character-class or locale ambiguity. This deliberately does NOT fold
# other Unicode whitespace (NBSP, em-space) to a boundary character on either side: those stay
# non-boundaries consistently everywhere, rather than a boundary on one platform only.
#
# WHY tab folding lives HERE and nowhere else, added round 8: it used to ALSO happen in a separate
# earlier step. Two sufficient mechanisms for one property meant no behavioural test could
# discriminate either -- neutering the earlier step left every tab assertion byte-identically
# green, so the regression guard for the parity bug above was already dead while still looking
# healthy. Redundant normalization in a matcher does not add safety; it removes testability.
# Keep exactly ONE folding site so the tests can prove it.
$cmd = $cmd -replace '\\\r?\n', ''
$cmd = $cmd -replace '[ \t]+', ' '

# WHY a second, aggressively de-escaped view: a shell strips a backslash before ANY character,
# not only before a newline, and concatenates adjacent quoted segments with no separator. So
# `r\m -r\f` runs as `rm -rf`, and `git config "commit."'gpgsign' false` runs as
# `git config commit.gpgsign false`. The faithful view above models only backslash-NEWLINE
# elision and cannot see either. Both were live, unprompted bypasses of the BLOCK and CONFIRM
# tiers respectively, and both PRE-DATE the commit-signing work.
#
# WHY match both views rather than replacing the faithful one: this view is deliberately NOT
# faithful -- it destroys information a real shell keeps. Matching it in ADDITION can only ever
# ADD a match, never remove one, so the change is strictly fail-closed. Kept byte-identical in
# intent with the sh twin's $cmd_loose; see dangerous-commands.sh for the full rationale.
#
# KNOWN COST, stated rather than hidden: stripping quotes creates matches a real shell would not
# produce -- `echo "rm" "-rf"` collapses to `echo rm -rf` and now trips BLOCK. Same accepted
# class as the documented quoted-invocation-as-text false positive.
$cmdLoose = ($cmd -replace '[\\"'']', '') -replace ' +', ' '

# WHY Singleline, added round 9 alongside the `.*` gaps: under `grep -z` the sh twin treats the
# whole payload as ONE record, so its `.` matches a newline. .NET's `.` does NOT, unless
# Singleline is set. With the gaps written as `[^|;&]*` that difference was latent -- no pattern
# contained a bare `.`. Introducing `.*` would have activated it, giving opposite verdicts on any
# multi-line command: verified, `git status<LF>echo hello --no-gpg-sign` matches in grep -z and
# does not in .NET without this flag.
#
# This is the THIRD time this exact line-vs-string mismatch has come up in this file -- `sed`
# vs .NET `-replace` in round 4, `grep` vs `-imatch` in round 6 (fixed with -z), and now `.`
# vs `.`. confirm_regex()'s comment in the sh twin asked that a third instance be made harder
# to write; this is that instance, handled at the same time as the change that would cause it.
$DcRegexOpts = [System.Text.RegularExpressions.RegexOptions]'IgnoreCase, Singleline'

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

# WHY a length bound before any matching, and why it is defined AFTER Deny: the CONFIRM regexes
# contain gap groups of the shape `git (<gap>)config (<gap>)`, and .NET's backtracking engine
# blows up on a long run containing many `config` tokens and none of `|`, `;` or `&`. GNU grep
# uses a DFA and stays flat, so this blowup is .NET-side -- but the bound is applied identically
# in BOTH shells, because a guard that behaves differently per platform is precisely the defect
# class this file has already shipped twice.
#
# ROUND 8: growth was measured to be CUBIC, not quadratic (~8x per doubling), making the real
# worst case at this bound ~47 minutes rather than the "roughly 8 seconds" previously claimed.
# Only the two NESTED-gap `config` patterns blow up; they are bounded to {0,300}. The two
# single-gap patterns are deliberately left unbounded -- bounding them broke the --no-gpg-sign
# CONFIRM for any ordinary commit message, because that gap holds the message rather than flags.
# See dangerous-commands.sh for the per-pattern measurements and why test assertions were
# preferred to a regex timeout.
#
# WHY it denies rather than truncating: truncation is fail-OPEN -- a dangerous substring
# straddling the cut point would simply vanish.
#
# WHY UTF8.GetByteCount and not .Length: .NET's .Length counts UTF-16 code units, so this side
# used to count LOW on any non-ASCII command and admit payloads the sh twin refused -- a fail-open
# divergence. Counting UTF-8 BYTES fixes this half.
#
# CORRECTED round 8: an earlier version of this comment claimed the change made the two shells
# "agree by construction". It did not -- it inverted the divergence. The sh twin was using
# `${#cmd}`, which counts characters in the CURRENT LOCALE, so under the UTF-8 locales CI actually
# runs under bash counted LOW while this side counted bytes. The sh side now measures with
# `wc -c`, which is byte-based in every locale; only that made the two units genuinely equal.
$DcMaxCmd = if ($env:DC_MAX_CMD) { [int]$env:DC_MAX_CMD } else { 50000 }
$cmdLen = [System.Text.Encoding]::UTF8.GetByteCount($cmd)
if ($cmdLen -gt $DcMaxCmd) {
    Deny "CONFIRM REQUIRED: command is $cmdLen bytes, above the $DcMaxCmd-byte limit this guard can analyze reliably. Run manually if intentional."
    exit 0
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
    $isMatch = if ($entry.regex) { [regex]::IsMatch($cmd, $entry.pattern, $DcRegexOpts) -or [regex]::IsMatch($cmdLoose, $entry.pattern, $DcRegexOpts) } else { $cmd.Contains($entry.pattern, [System.StringComparison]::OrdinalIgnoreCase) -or $cmdLoose.Contains($entry.pattern, [System.StringComparison]::OrdinalIgnoreCase) }
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
    # WHY these sit beside the hook-skip flag above: same class of action -- routing around
    # local governance. See dangerous-commands.sh for the full rationale and the incident.
    # WHY regex and not plain substrings: `-c key=value` and `git config key value` are the
    # same action with different separators, and neither is expressible as one literal. The
    # REGEX is identical to the sh twin's, using only the subset valid in both .NET and GNU ERE
    # -- no [[:space:]], which .NET does not support. The escaped string LITERALS are NOT
    # byte-identical: sh double-quotes need \" where PowerShell single-quotes need ''. See the
    # note below the pattern list; the parity block asserts equal behaviour, not equal text.
    # WHY these require a `config` subcommand or a `-c` flag and not merely a `git` token:
    # requiring only `git` made every git command carrying the key as TEXT fire, including
    # `git commit -m "...commit.gpgsign false..."` -- which meant this feature could not be
    # committed with a message describing it. See the sh twin for the measured cases, the
    # --unset-all and quoted-value gaps this closes, and the full KNOWN LIMITS list
    # (GIT_CONFIG_* env vars, direct .git/config writes, tag.gpgsign/push.gpgSign).
    # WHY the escaping differs from the sh twin while the regex does not: sh double-quotes
    # need \" and PowerShell single-quotes need '' for the same two characters. The
    # engine-visible pattern is identical; the parity test asserts behaviour, not text.
    @{ pattern = '(^|[^a-z])git (.*)-c *["'']?commit\.gpgsign["'']? *= *["'']?(false|no|off|0)([^a-z0-9]|$)'; regex = $true; reason = "bypasses commit signing (local governance)" }
    @{ pattern = '(^|[^a-z])git (.{0,300})config (.{0,300})["'']?commit\.gpgsign["'']? *[= ] *["'']?(false|no|off|0)([^a-z0-9]|$)'; regex = $true; reason = "bypasses commit signing (local governance)" }
    @{ pattern = '(^|[^a-z])git (.{0,300})config (.{0,300})--unset(-all)? +["'']?commit\.gpgsign'; regex = $true; reason = "bypasses commit signing (local governance)" }
    @{ pattern = '(^|[^a-z])git (.*)--no-gpg-sign'; regex = $true; reason = "bypasses commit signing (local governance)" }
    # WHY regex, not a plain substring: "git merge" as a bare substring also matches
    # "git merge-base", a common, harmless read-only command — the character after
    # "merge" there is "-", not a word boundary in the usual sense. Requiring
    # space-or-end-of-string after "merge" excludes that case while still matching
    # "git merge <branch>", "git merge --no-ff <branch>", and bare "git merge". WHY a
    # literal space, not \s, on the trailing side: $cmd already had tabs normalized to
    # spaces before this pattern ever runs (see the blank-run collapse above), and
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
    $isMatch = if ($entry.regex) { [regex]::IsMatch($cmd, $entry.pattern, $DcRegexOpts) -or [regex]::IsMatch($cmdLoose, $entry.pattern, $DcRegexOpts) } else { $cmd.Contains($entry.pattern, [System.StringComparison]::OrdinalIgnoreCase) -or $cmdLoose.Contains($entry.pattern, [System.StringComparison]::OrdinalIgnoreCase) }
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
