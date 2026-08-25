#!/usr/bin/env sh
# PreToolUse hook — 3-tier dangerous command guardrails for Claude Code.
# Reads the Bash tool input JSON from stdin and enforces BLOCK / CONFIRM / WARN tier
# matching against the extracted tool_input.command. Fails open: unexpected errors
# exit 0.
#
# WHY extract tool_input.command via python3 instead of matching raw stdin: raw-stdin
# matching false-positived on a trigger phrase appearing ANYWHERE in the JSON payload --
# e.g. a Bash tool call's own "description" field merely mentioning "rm -rf" in prose,
# never actually running it -- incorrectly BLOCKing/CONFIRMing a harmless action. This
# is not the same risk the original raw-stdin approach was written to avoid: that
# concern was specifically about a naive `grep -o '"command":"[^"]*"'` extraction
# breaking on a JSON-escaped quote inside the command and silently truncating the match.
# python3's json.loads is a real parser, not a fragile regex -- it handles escaped quotes
# correctly, so it closes the false-positive gap without reintroducing the
# truncation risk. Matches dangerous-commands.ps1's existing ConvertFrom-Json approach
# and this repo's established precedent (check-contract.sh, review-reminders.sh's
# resolve_cd_root()).
#
# WHY the extraction reads and writes BINARY, not text: on Windows this repo's python3 runs
# with sys.stdin/sys.stdout at cp1252 and errors='surrogateescape' (measured; PYTHONUTF8 and
# PYTHONIOENCODING are both unset repo-wide). Text-mode I/O then corrupts or crashes on any
# non-ASCII command -- an accented name, a curly quote, an em dash, CJK -- and a crash is not
# harmless here: it exits nonzero and drops the hook into the raw-stdin fallback below, which
# is exactly the false-positive mode this extraction exists to prevent. Verified live, the sh
# hook DENIED a CJK payload with "command is 120057 characters" (the byte length of the whole
# JSON file, not the command) while the .ps1 twin allowed it -- opposite verdicts on ordinary
# input. Reading via sys.stdin.buffer and writing via sys.stdout.buffer removes every
# dependence on locale and on those env vars.
#
# WHY BOTH sides had to change, and why fixing only stdout is WORSE than the original: the two
# payload shapes fail in opposite directions, so a one-sided fix just moves the bug.
#   - json.dumps default (ensure_ascii): non-ASCII arrives as \uXXXX, decodes to real characters,
#     and text-mode print() cannot encode them to cp1252 -> UnicodeEncodeError, zero bytes, exit 1.
#   - raw UTF-8 on the wire: text-mode stdin mis-decodes it as cp1252, and surrogateescape turns
#     the undecodable bytes into lone surrogates. The ORIGINAL code survives this only by
#     accident -- print() re-encodes through the same codec and handler, so the mojibake
#     round-trips back to the correct bytes. Add a strict .encode('utf-8') on top of that
#     text-mode read and the lone surrogates become fatal: UnicodeEncodeError, exit 1, raw-stdin
#     fallback again. Measured 2/2 correct for binary-both-sides, 1/2 for either one-sided form.
# Do not "simplify" either half back to text mode; each alone reintroduces a live bypass.
#
# WHY the error handlers and the nested try, added round 8 after review: strict UTF-8 codecs made
# the extraction FAIL -- and therefore fall back to raw-stdin matching -- for reasons that have
# nothing to do with the command being dangerous. Three classes were found by review, each a live
# sh/ps1 divergence:
#   - a lone surrogate (`"echo \ud800"`) is valid JSON but not encodable as strict UTF-8, so
#     `.encode('utf-8')` raised and the hook fell back. `surrogatepass` carries it through.
#   - non-UTF-8 wire bytes (latin-1) made `json.loads(bytes)` raise, so the hook fell back and
#     then BLOCKed on a trigger phrase in the `description` field -- exactly the false positive
#     the extraction exists to prevent. `surrogateescape` decodes any byte sequence.
#   - `json.loads` on BYTES also auto-detects UTF-16/32, and decoding first would destroy that.
#     Hence the nested try: bytes first, surrogateescape only as the fallback. Measured 8/8
#     payload classes correct; the single-codec forms scored 6/8 and 7/8.
#
# CORRECTED round 9, then corrected AGAIN by round 9's own review -- the UTF-16/32 half of that
# rationale is unreachable here, but not for the reason first written. `input=$(cat)` reads stdin
# through command substitution and the shell strips NUL bytes; UTF-16 is half NULs. The first
# correction claimed that mangles the payload into a parse failure and a fail-CLOSED denial. It
# does not: stripping NULs from UTF-16LE-encoded ASCII JSON returns the ASCII bytes EXACTLY
# (`u.encode('utf-16-le').replace(b'\x00', b'') == u.encode('ascii')`), so `json.loads` succeeds
# and extraction works normally. Measured: UTF-16LE, UTF-16BE and UTF-32LE payloads are all
# handled correctly; only a BOM'd payload fails, because the BOM's surviving 0xFF byte is not
# valid JSON. So the practical position is: UTF-16/32 mostly works by accident of NUL-stripping,
# BOM'd input falls back, and none of it is reachable anyway because Claude Code emits UTF-8.
# The branch's OPERATIVE purpose is the non-UTF-8 (e.g. latin-1) case, which is verified working.
# Do not delete the nested try on the strength of the UTF-16 argument alone.
# The rule this encodes: extraction may fail only when the payload is genuinely unparseable, never
# because a legal command contains an awkward character.
#
# WHY fall back to raw-stdin matching (not to no matching at all) when python3 is
# missing or JSON parsing fails: this hook's whole purpose is catching genuinely
# dangerous commands, and a real dangerous command's text is still present SOMEWHERE
# in the raw payload even when extraction isn't possible -- raw matching never misses
# a true positive, it only risks occasional false ones. Disabling the guardrail
# entirely on a missing dependency would trade a rare false-positive-block for a
# silent, total loss of protection, the wrong direction for a safety gate. This
# fallback does NOT apply when python3 succeeds and tool_input.command is genuinely
# empty -- that's a real, parsed answer ("no command to check"), not an extraction
# failure, so it's trusted as-is rather than falling back to raw matching.
#
# WHY hookSpecificOutput.permissionDecision, not exit code: settings.json wires this hook
# as "... 2>/dev/null || bash ... || true" for cross-platform fail-open portability, and
# that "|| true" suffix silently converts any nonzero exit code to 0 -- empirically
# confirmed while building review-reminders.ps1/.sh. permissionDecision:deny is read from
# stdout JSON regardless of the wrapping shell's final exit code.

input=$(cat 2>/dev/null)
if [ -z "$input" ]; then
    printf "[HOOK ERROR] dangerous-commands.sh: could not read stdin.\nProceeding in fails-open mode.\n"
    exit 0
fi

cmd="$input"
if command -v python3 >/dev/null 2>&1; then
    extracted=$(printf '%s' "$input" | python3 -c "
import sys, json
try:
    raw = sys.stdin.buffer.read()
    try:
        d = json.loads(raw)
    except UnicodeDecodeError:
        d = json.loads(raw.decode('utf-8', 'surrogateescape'))
    sys.stdout.buffer.write(d.get('tool_input', {}).get('command', '').encode('utf-8', 'surrogatepass'))
except Exception:
    sys.exit(1)
" 2>/dev/null)
    [ $? -eq 0 ] && cmd="$extracted"
fi

# WHY join backslash-newline continuations before any tier matching: the shell parser
# removes a backslash followed by a newline before the command ever reaches git, so
#     git config commit.gpgsign \
#       false
# executes exactly as `git config commit.gpgsign false`. The hook, though, receives the raw
# two-line text, and no pattern's key-to-value glue matches a backslash or a newline -- so
# the gate stayed silent while signing was genuinely disabled. Verified live: the
# continuation form moved commit.gpgsign from true to false with no CONFIRM, while the
# identical one-line command fired correctly.
#
# WHY this predates the commit-signing work: the original patterns used the same ` *[= ] *`
# glue, so the hole existed from the first version and survived three review rounds before
# the fourth found it. It is not specific to signing either -- a BLOCK substring such as
# "git push --force" was equally evadable by wrapping the line.
#
# WHY this normalizes $cmd globally instead of building a separate copy for one tier: the
# goal is to make the hook's view of the command match what the shell will actually run,
# which is correct for every tier, so it happens once, here, before any matching.
#
# Contrast the argument-STRIPPING approach tried and withdrawn in review round 4: removing
# a command's message and search payloads made the hook's view deliberately DIFFER from
# reality, and introduced two defects of its own -- sed is line-based while .NET -replace is
# not, so the two shells disagreed on multi-line input, and an unquoted multi-word argument
# was only partly removed. It also bought little: anchoring the patterns to a `config`
# subcommand or a `-c` flag already resolved three of the four false positives that
# motivated it. Normalizing TOWARD what the shell does is safe; normalizing away from it is
# not.
#
# WHY awk rather than sed: a continuation spans two lines and sed is line-based; the common
# ':a;N;$!ba' slurp idiom also misbehaves on single-line input under GNU sed. This is plain
# POSIX awk -- when a line ends in a backslash, delete that backslash (and a trailing CR) and
# emit the line with NO separator at all, so the line that follows concatenates directly. This
# rule deliberately inserts nothing; the separate blank-run collapse below is what reproduces
# the shell's tokenization. See the DELETES-rather-than-substitutes note further down -- an
# earlier version of this comment described the withdrawn space-substituting attempt, which is
# the exact behaviour that shipped the round-5 mid-token bypass.
#
# WHY the join must collapse to exactly one space: a first attempt simply swapped the
# backslash for a space and left the continuation line's indentation in place. That works for
# the signing patterns, whose regexes glue with ` *`, but silently broke the BLOCK tier --
# those patterns are literal substrings, so "git push \<newline>  --force" joined to
# "git push   --force" and no longer contained "git push --force". Caught by a probe, not by
# inspection: the wrapped force-push produced no verdict at all while the one-line form
# blocked correctly.
# WHY the join DELETES rather than substitutes, and whitespace is collapsed separately:
# backslash-newline elision in the shell inserts nothing at all. Two earlier attempts each got
# half of this and each shipped a live bypass, both caught by review:
#   1. swap the backslash for a space, keep the continuation indent -> "git push \<nl>  --force"
#      became "git push   --force", which no longer contains the literal "git push --force".
#   2. swap for one space, strip the indent -> fixed that, but broke the no-whitespace case:
#      "rm -r\<nl>f /tmp" became "rm -r f /tmp", losing "rm -rf". Every literal BLOCK substring
#      was then evadable by wrapping a line mid-token. Verified live on both shells.
# Deleting the backslash-newline models the shell CLOSELY -- not exactly, and the difference is
# worth stating: a DOUBLED backslash is an escaped literal, so the shell ends the command there
# and does not join, while this rule strips one trailing backslash regardless of how many precede
# it and joins anyway. It also models only backslash-NEWLINE, not the shell's general rule that a
# backslash escapes ANY next character -- that gap was a live BLOCK-tier bypass, and it is the
# de-escaped second view below, not this rule, that closes it. Both divergences over-join, i.e.
# they can only produce extra matches. Collapsing runs of blanks afterwards reproduces the
# shell's tokenization, which treats any run of blanks as one separator.
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
# WHY a length bound before any matching: the CONFIRM regexes below contain gap groups of the
# shape `git (<gap>)config (<gap>)`, and .NET's backtracking engine blows up on a long run that
# contains many `config` tokens and none of `|`, `;` or `&`. GNU grep uses a DFA and stays flat,
# so the blowup is .ps1-side -- but the bound is applied identically in BOTH shells because a
# guard that behaves differently per platform is the defect class this file has already shipped
# twice.
#
# WHY it CONFIRMs rather than truncating: truncation is fail-OPEN. A dangerous substring
# straddling the cut point would simply disappear. Refusing to silently analyze a command the
# guard cannot analyze reliably is the honest failure direction.
#
# WHY 50000, CORRECTED in round 8 -- the previous figure here was wrong in kind, not just in
# degree. This comment used to claim the bound held the .ps1 worst case to "roughly 8 seconds".
# Two things were wrong. First, the growth is CUBIC, not quadratic: measured in-process on the
# `config` gap shape, 1000/2000/4000/8000 chars took 0.027/0.202/1.438/11.486s -- ~8x per
# doubling, the signature of three nested unbounded quantifiers. Extrapolated, 50000 chars is
# roughly 47 MINUTES for ONE pattern, and there are two of this shape matched against two views.
# Second, the earlier 16s measurement that replaced the 8s figure used a no-separator payload,
# which is not the worst case at all (0.43s here) -- the `config`-token density is what drives it.
# A PreToolUse hook blocks the tool call, so that was a hang, not a slow path, and it was
# reachable by ordinary work: a large heredoc writing prose ABOUT `git config`, with no pipe or
# semicolon in it, is exactly the shape that triggers it.
#
# The blowup is fixed at its source, but ONLY where it exists. This is the part the first round-8
# attempt got wrong: it bounded EVERY gap group to {0,200} uniformly, which broke a live gate.
# Measured per pattern at 50000 chars. NOTE THE PAYLOAD SHAPE -- an earlier version of this table
# used dense `git config ` text, which is the worst case for the NESTED patterns but NOT for the
# single-gap ones; measuring both on the shape that is worst for each gives:
#     one unbounded gap  (`-c ...`, `--no-gpg-sign`)  4.3s   on dense `git ` text
#     two nested gaps    (`config (gap)...(gap)`)     >30s   times out; ~47 min extrapolated
# Only the NESTED pair blows up superlinearly, so only those four groups are bounded, at {0,300}
# (0.74s at 50000 chars). The two single-gap patterns are left UNBOUNDED on purpose.
#
# WHOLE-HOOK worst case at the 50000-byte bound, measured end to end, .ps1 side:
#     dense `git `        17.55s      <- the real number to reason about
#     dense `git config `  9.33s
#     ordinary text        0.44s
# 17.55s is not a hang (the ~47-minute cubic case is gone) but a PreToolUse hook blocks the tool
# call for its whole duration, so this is the honest figure for "what does a pathological 50 KB
# command cost". It is quadratic, not cubic: halving DC_MAX_CMD would quarter it. That trade has
# NOT been made here -- it is recorded so the next person changing DC_MAX_CMD knows the shape.
# The sh twin stays flat (~1.0s) on every shape; GNU grep is a DFA.
#
# WHY leaving them unbounded is not laziness: in `git (<gap>)--no-gpg-sign` the gap holds the
# COMMIT MESSAGE, not flags. Bounding it to 200 silently disabled that CONFIRM for any commit
# message longer than about 185 characters, on BOTH shells -- and ordinary messages in this repo
# exceed that. It is exactly the shape the round-6 note below cites as canonical. The reasoning
# that justified the uniform bound ("real gaps are tiny: `--global` is 9 characters") is true of
# the `config` gaps and false of the message gap; one bound was applied to two different things.
# KNOWN COST of the {0,300} bound that remains: 300+ characters between `git` and `config`, or
# between `config` and the key, no longer matches. That is flag-and-path territory, where gaps
# really are short, and it does not lower the bar for an adversary -- anyone able to pad the
# command text already has the strictly easier S4/S5 bypasses documented as unfixable by any
# text matcher.
#
# WHY test assertions rather than a .NET regex timeout: a timeout converts the hang into a
# DENIAL, so a legitimate documentation command is still blocked, merely sooner -- see [NS-25],
# where guards firing on the TEXT of commands is this repo's most-repeated complaint. It is also
# ps1-only, reintroducing the per-platform divergence named above. The suites instead assert the
# SHAPE structurally (no pattern may carry more than one unbounded gap), on both platforms and in
# constant time, plus a bounded-cost timing check on the .NET side. The first attempt asserted
# wall-clock time on the BASH side too; that assertion could not fail, because GNU grep is a DFA
# and never got slow -- reverting all six bounds left the suite green at 108/0.
#
# KNOWN COST of the length bound itself: a genuinely legitimate single command larger than
# 50000 -- a very large heredoc, say -- prompts. That is a deliberate trade, not an oversight.
cmd=$(printf '%s' "$cmd" | awk '
    {
        line = $0
        if (sub(/\\[\r]?$/, "", line)) printf "%s", line
        else print line
    }' | sed 's/[ 	][ 	]*/ /g')

# WHY a second, aggressively de-escaped view of the command: a shell strips a backslash before
# ANY character, not only before a newline, and concatenates adjacent quoted segments with no
# separator. So `r\m -r\f` runs as `rm -rf`, and `git config "commit."'gpgsign' false` runs as
# `git config commit.gpgsign false` -- both of which the faithful view above cannot see, because
# it deliberately models only backslash-NEWLINE elision. Both were live, unprompted bypasses of
# the BLOCK and CONFIRM tiers respectively, and both PRE-DATE the commit-signing work.
#
# WHY match against both views instead of replacing the faithful one: this view is deliberately
# NOT faithful -- it destroys information a real shell keeps. Matching it in ADDITION can only
# ever ADD a match, never remove one, so the change is strictly fail-closed.
#
# KNOWN COST, stated rather than hidden: stripping quotes creates matches a real shell would not
# produce -- `echo "rm" "-rf"` collapses to `echo rm -rf` and now trips BLOCK. That is the same
# accepted class as the documented quoted-invocation-as-text false positive below.
cmd_loose=$(printf '%s' "$cmd" | tr -d '\\"'"'" | sed 's/  */ /g')

deny() {
    printf '{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"deny","permissionDecisionReason":"%s"}}\n' "$1"
}

# WHY `wc -c` and not `${#cmd}`, corrected round 8: `${#cmd}` counts CHARACTERS IN THE CURRENT
# LOCALE, not bytes. Measured on one string of three U+00E9: 6 under LC_ALL=C, 3 under C.UTF-8 or
# en_US.UTF-8. So the round-8 change that moved the .ps1 side to UTF8.GetByteCount did NOT make the
# two shells agree "by construction" as its first version claimed -- it inverted the divergence,
# leaving bash counting low under exactly the UTF-8 locales CI runs under. `wc -c` counts bytes in
# every locale, which is the unit the .ps1 twin now uses, so the two agree for real.
DC_MAX_CMD=${DC_MAX_CMD:-50000}
cmd_len=$(printf '%s' "$cmd" | wc -c | tr -d '[:space:]')
if [ "$cmd_len" -gt "$DC_MAX_CMD" ]; then
    deny "CONFIRM REQUIRED: command is ${cmd_len} bytes, above the ${DC_MAX_CMD}-byte limit this guard can analyze reliably. Run manually if intentional."
    exit 0
fi

block() {
    # BLOCK: irreversible or highly destructive — refuse unconditionally.
    # Checks the de-escaped view too -- see the cmd_loose note above.
    case "$cmd" in
        *"$1"*)
            deny "BLOCK: $2. Refusing this command."
            exit 0
            ;;
    esac
    case "$cmd_loose" in
        *"$1"*)
            deny "BLOCK: $2. Refusing this command."
            exit 0
            ;;
    esac
}

block_boundary() {
    # Like block(), but requires $1 to end at a word boundary (not immediately followed
    # by a letter) -- for short patterns prone to colliding with longer words, e.g. a
    # plain "| sh" substring check false-positives on "| sha256sum"/"| shasum", tools
    # this repo's own review-gate hash verification depends on (found when fixing the
    # field-path bug that had made this pattern a no-op made the collision real). POSIX
    # case globs have no \b, so this approximates it: match $1 followed by a non-letter,
    # or match $1 as the literal end of the string.
    case "$cmd" in
        *"$1"[!a-zA-Z]*|*"$1")
            deny "BLOCK: $2. Refusing this command."
            exit 0
            ;;
    esac
    case "$cmd_loose" in
        *"$1"[!a-zA-Z]*|*"$1")
            deny "BLOCK: $2. Refusing this command."
            exit 0
            ;;
    esac
}

confirm() {
    # CONFIRM: advanced op with legitimate uses — require explicit manual invocation.
    # Checks the de-escaped view too -- see the cmd_loose note above.
    case "$cmd" in
        *"$1"*)
            deny "CONFIRM REQUIRED: $2. Run manually if intentional."
            exit 0
            ;;
    esac
    case "$cmd_loose" in
        *"$1"*)
            deny "CONFIRM REQUIRED: $2. Run manually if intentional."
            exit 0
            ;;
    esac
}

confirm_regex() {
    # Like confirm(), but matches an extended regex, case-insensitively.
    #
    # WHY a regex helper is needed at all: the commit-signing bypasses below cannot be
    # expressed as literal substrings. `git -c commit.gpgsign=false` and
    # `git config commit.gpgsign false` are the same action with the key and value separated
    # differently, and the second form -- the standard, PERSISTENT one, including --global --
    # was left completely ungated by an earlier literal-substring version of these patterns.
    #
    # WHY case-insensitive: git config keys and boolean values are both case-insensitive
    # (`git -c commit.GPGSign=false` resolves), so a case-sensitive match is evaded by one
    # shifted keystroke. The .ps1 twin applies -imatch to regex entries, so -i here keeps the
    # two shells in agreement.
    #
    # WHY grep -E rather than bash [[ =~ ]]: this file targets POSIX sh, and the ERE subset
    # used by these patterns is also valid .NET regex, so one REGEX serves both the sh and
    # ps1 twins instead of maintaining two dialects. The escaped string LITERALS are not
    # byte-identical -- sh double-quotes need \" where PowerShell single-quotes need '' --
    # see the note above the pattern list below.
    #
    # WHY -e: it is precautionary. None of the four patterns currently in the list begins with
    # a "-", but a future one plausibly could, and grep would then parse it as an option rather
    # than a pattern. An earlier version of this comment claimed several patterns already began
    # with "--"; they do not -- every one begins `(^|[^a-z])git `.
    #
    # WHY -z, and this is the round-6 blocker: WITHOUT it grep is LINE-BASED, so a pattern
    # cannot span a newline, while the .ps1 twin's -imatch runs over the whole string and can.
    # The two shells therefore returned OPPOSITE verdicts on an ordinary multi-line command --
    # `git commit -m "<two-line message>" --no-gpg-sign` passed silently in sh and was denied in
    # ps1. -z makes the whole payload a single record, restoring agreement.
    #
    # This is the SECOND time this exact mismatch has shipped in this file. The argument-
    # stripping approach withdrawn in round 4 was withdrawn *because* `sed` is line-based while
    # .NET -replace is not; the replacement then reintroduced the identical defect one function
    # over, via grep. Recorded here so a third instance is harder to write.
    #
    # Checks the de-escaped view too -- see the cmd_loose note above.
    if printf '%s' "$cmd" | grep -qziE -e "$1"; then
        deny "CONFIRM REQUIRED: $2. Run manually if intentional."
        exit 0
    fi
    if printf '%s' "$cmd_loose" | grep -qziE -e "$1"; then
        deny "CONFIRM REQUIRED: $2. Run manually if intentional."
        exit 0
    fi
}

confirm_boundary() {
    # Like confirm(), but requires $1 to be bounded on BOTH sides: preceded by the
    # start of the string or a non-letter, and followed by whitespace or the literal
    # end of the string — not just any non-letter on the trailing side, which
    # block_boundary() accepts. WHY the stricter trailing boundary: "git merge" as a
    # plain substring (or under block_boundary's non-letter check) also matches
    # "git merge-base", a common, harmless read-only command this repo's own session
    # tooling uses constantly — the character after "merge" in "merge-base" is "-", a
    # non-letter, so block_boundary's boundary rule would still false-positive there.
    # WHY a leading boundary too (found by code review, not present in the original
    # version): without one, "$1" also matches as a substring of a longer word — e.g.
    # "git commit -m 'legit merge of feature A'" contains the literal substring
    # "git merge " inside "le-GIT- -MERGE-of", which would wrongly trigger CONFIRM.
    # Requiring the character before "$1" to be absent (start of string) or a
    # non-letter closes that gap while still matching "git merge <branch>",
    # "git merge --no-ff <branch>", bare "git merge", and "; git merge <branch>".
    # WHY a literal space, not a [[:space:]]/\s character class, on the trailing
    # side: $cmd already had tabs folded to spaces before this function ever
    # runs (see the blank-run collapse above), and dangerous-commands.ps1
    # does the same normalization -- so both sides only ever need to check for a
    # plain ASCII space here, with no character-class/locale/Unicode ambiguity to
    # keep in parity.
    # WHY case-fold both sides before matching (found by opposition review, not
    # present in the original version): POSIX case globs are case-sensitive, but
    # dangerous-commands.ps1's `-imatch` is not -- so "GIT merge main" (the
    # executable name uppercase, the subcommand itself still lowercase, which git
    # accepts) was denied on PowerShell but silently allowed on bash. On Windows
    # this is a real, executable command, not a contrived case: the filesystem
    # resolves "GIT" to git.exe case-insensitively, and git's own subcommand
    # parsing only requires "merge" (not "GIT") to be lowercase. Folding both
    # $cmd and $1 to lowercase before the case match closes that platform gap
    # without touching confirm()/block()/block_boundary(), which are unaffected
    # by this pattern and use the file's existing explicit-lowercase-variant
    # convention (see the "drop table"/"DROP TABLE" pairs above) instead.
    # Checks the de-escaped view too -- see the cmd_loose note above. This function was the
    # ONE matcher of five the de-escaped-view retrofit missed, and the gap was live: with only
    # the faithful view, `git m\erge main` and `git "merge" main` were both SILENT here while
    # the .ps1 twin CONFIRMed both -- a sh/ps1 divergence in the git merge CONFIRM tier,
    # reachable by the same escape and adjacent-quote techniques the retrofit closed in
    # block()/block_boundary()/confirm()/confirm_regex(). The ps1 side never had the gap
    # because its `git merge` entry is one more row in the uniform $confirmPatterns loop.
    #
    # WHY the mutation proof did not catch this: deleting cmd_loose turned the escape tests red,
    # which proves the MECHANISM works where it is wired -- it says nothing about whether every
    # matcher is wired to it. Coverage failures wear correctness clothing. The cheap guard is a
    # COMPLETENESS invariant (enumerate every matcher, assert each references both views), which
    # is a different tool from a discrimination check.
    cmd_lc=$(printf '%s' "$cmd" | tr 'A-Z' 'a-z')
    cmd_loose_lc=$(printf '%s' "$cmd_loose" | tr 'A-Z' 'a-z')
    pat_lc=$(printf '%s' "$1" | tr 'A-Z' 'a-z')
    case "$cmd_lc" in
        "$pat_lc "*|"$pat_lc"|*[!a-zA-Z]"$pat_lc "*|*[!a-zA-Z]"$pat_lc")
            deny "CONFIRM REQUIRED: $2. Run manually if intentional."
            exit 0
            ;;
    esac
    case "$cmd_loose_lc" in
        "$pat_lc "*|"$pat_lc"|*[!a-zA-Z]"$pat_lc "*|*[!a-zA-Z]"$pat_lc")
            deny "CONFIRM REQUIRED: $2. Run manually if intentional."
            exit 0
            ;;
    esac
}

warn() {
    # WARN: credential/secrets access — command proceeds, access is surfaced
    case "$cmd" in
        *"$1"*)
            printf "WARNING: %s. Proceeding.\n" "$2"
            ;;
    esac
}

# BLOCK: irreversible or highly destructive — refuse unconditionally
block "rm -rf"           "irreversible recursive deletion"      # WHY: recursive deletion is irreversible
block "mkfs"             "filesystem format"                    # WHY: formats/destroys entire filesystem
block "dd if="           "disk wipe or dump"                    # WHY: raw disk access, wipes or dumps data
block "git push --force" "force push (long form)"               # WHY: rewrites remote history irreversibly
block "git push -f"      "force push (short form)"              # WHY: same as --force, short flag form
# NOTE: POSIX case is case-sensitive. Adding lowercase variants to match ps1 OrdinalIgnoreCase behavior.
block "DROP TABLE"       "SQL table drop"                       # WHY: irreversible schema destruction
block "DROP DATABASE"    "SQL database drop"                    # WHY: destroys entire database
block "drop table"       "SQL table drop (lowercase)"           # WHY: parity with ps1 OrdinalIgnoreCase — catches lowercase SQL
block "drop database"    "SQL database drop (lowercase)"        # WHY: parity with ps1 OrdinalIgnoreCase — catches lowercase SQL
block_boundary "| bash" "command piped to bash (curl|bash, wget|bash, etc.)"  # WHY: remote code execution vector
block_boundary "| sh"   "command piped to sh"                  # WHY: remote code execution via sh
block_boundary "|bash"  "command piped to bash (no-space form)"  # WHY: curl|bash without spaces evades space-prefixed pattern
block_boundary "|sh"    "command piped to sh (no-space form)"    # WHY: wget|sh without spaces evades space-prefixed pattern

# CONFIRM: advanced ops with legitimate uses — require explicit manual invocation
confirm "git filter-branch" "history rewriting"                 # WHY: rewrites commit history, rarely intentional
confirm "git update-ref"    "low-level ref manipulation"        # WHY: low-level plumbing, bypasses safety checks
confirm "sudo rm"           "privileged deletion"               # WHY: elevated deletion can remove system files
confirm "chmod -R 777"      "world-writable recursive chmod"    # WHY: makes entire tree world-writable
confirm "--no-verify"       "bypasses pre-commit hooks (local governance)"  # WHY: skips safety hooks on commit
# WHY these sit beside the hook-skip flag above: same class of action -- routing around
# local governance -- and that flag already establishes the class as CONFIRM-worthy. An
# agent stopped from skipping hooks was NOT stopped from skipping signing. Reported from
# ai-code-review-agent after an agent disabled signing twice in one session, once right
# after saying it would stop; the gate never fired because no pattern covered it. (Signing
# was unset in that repo, so nothing was actually bypassed -- the gap, not the damage, is
# what was observed.)
# WHY all four falsey spellings: `git config --type=bool` resolves false, 0, no and off to
# false -- verified directly. Truthy spellings are deliberately NOT matched: gating a
# command that turns signing ON would train the operator to dismiss the prompt.
# WHY --unset AND --unset-all: both remove the key entirely, dropping signing back to its
# default-off -- the same outcome by a different route. --unset-all sits beside --unset in
# `git help config`; an earlier version of this pattern required whitespace immediately
# after "--unset" and so could never match it. --replace-all needs no pattern of its own:
# it SETS a value, so the set-form pattern below already covers it.
# WHY the value may be quoted: `git config commit.gpgsign "false"` is ordinary shell style,
# not evasion, and the earlier bare-value-only pattern missed it entirely.
# WHY the key patterns require a `config` subcommand or a `-c` flag, rather than merely a
# `git` token: requiring only `git` made every git command carrying the key as TEXT fire --
# `git commit -m "...commit.gpgsign false..."`, `git log -S "..."`, `git show ... # ...`.
# Anchoring to the flag or subcommand that actually SETS config is what separates a command
# from its data; the normalization block near the top removes the remaining message and
# search payloads. This file is TEMPLATE_OWNED and mb upgrade overwrites it downstream, so
# a noisy pattern cannot be tuned by adopters -- and a tier that fires on ordinary commits
# trains the operator to dismiss it, which is the worse failure direction here.
# WHY the pattern strings differ in ESCAPING between this file and the .ps1 twin while
# remaining identical as regexes: sh double-quotes need \" and PowerShell single-quotes
# need '' for the same two characters. The engine-visible pattern is the same; the parity
# block in tests/test-dangerous-commands.sh asserts equal BEHAVIOUR rather than equal text.
# KNOWN LIMITS -- deliberate, and documented rather than matched.
#
# NOT COVERED (a real shell reaches the same outcome; this file cannot see it):
#   - GIT_CONFIG_COUNT/GIT_CONFIG_KEY_n/GIT_CONFIG_VALUE_n. CORRECTED RATIONALE: an earlier
#     version of this comment said these "set the key before `git` appears in the string", which
#     implied a re-anchored pattern could catch them. It could not. The env-var mechanism is a
#     SUBSTITUTE for `-c`/`config`, so the anchor token these patterns require is simply absent
#     from the invocation, wherever you look for it (verified against git 2.55).
#   - appending "[commit]\ngpgsign=false" straight into .git/config bypasses git entirely
#   - tag.gpgsign and push.gpgSign are a different namespace, out of scope for a commit gate
#   - a computed value: `git config commit.gpgsign $(echo false)`. The literal alternation
#     (false|no|off|0) cannot see through command substitution.
#   - an indirected key: `K=commit.gpgsign; git config "$K" false`. Resolving it requires
#     EVALUATING the shell, not reading it.
# The last two are not fixable by any text matcher, at any level of effort. Writing patterns
# that appeared to cover them would convert an honest limit into a false claim of coverage --
# and the plain .git/config append is simpler than all of them and stays open regardless.
#
# ACCEPTED FALSE POSITIVES: three are enumerated in standards/SECURITY-GUARDRAILS.md under
# "Accepted false positives". They are NOT repeated here -- an earlier version of this comment
# listed only one of the three, so a maintainer reading the code next to the regexes did not
# learn the other two existed. One list, one home.
#
# The de-escaped second view adds a fourth accepted over-match, also listed there: stripping
# backslashes and quotes produces strings a real shell would not (`echo "rm" "-rf"` collapses to
# `echo rm -rf` and trips BLOCK). That is the price of closing the mid-word-escape and
# adjacent-quote bypasses, and it errs toward refusing.
#
# WHY THESE TWO GAPS ARE `.*` AND NOT `[^|;&]*`, round 9 -- the character class was a LIVE
# BYPASS, not a safety measure. Any `|`, `;` or `&` inside the gap made the pattern unmatchable,
# and for these two patterns the gap holds the COMMIT MESSAGE. Verified live, both shells:
#   git commit -m "docs: R&D notes" --no-gpg-sign            -> ALLOWED (no prompt)
#   git commit -m "parser: handle a|b" --no-gpg-sign         -> ALLOWED
# None of those is an evasion attempt; an ampersand in a commit message is ordinary English.
# (A third form, `git -c "alias.x=a|b" config --global commit.gpgsign false`, was allowed by the
# same defect in the CONFIG patterns below rather than by these two -- it is fixed there, not here.)
#
# The class also did not achieve what it cost: NEWLINE was never in the excluded set, so the gap
# already spanned commands freely. It blocked ordinary messages and not the thing it was for.
#
# The two nested-gap `config` patterns keep a BOUND (`.{0,300}`) because they are the cubic pair
# and need one -- but they no longer exclude separators either. That exclusion was left in place
# for one round on the argument that a separator there means a different command; it was then
# measured to be a live hole of its own:
#     git -c "alias.x=a|b" config --global commit.gpgsign false          -> was ALLOWED
#     git -c core.pager='less | head' config --global commit.gpgsign false -> was ALLOWED
# `core.pager` with a pipe is an ordinary git configuration, and both forms permanently unsign
# every commit in every repo. Bounding alone is enough for the ReDoS; measured at 50000 chars the
# bounded-dot form is 0.795s, marginally FASTER than the class it replaces (0.942s).
#
# ACCEPTED COST, and it is the fail-CLOSED direction: `git config user.name x | grep
# commit.gpgsign false` now prompts, as does `git status | grep -- --no-gpg-sign`. Telling those
# apart from the real bypasses above needs shell tokenization, which this matcher does not do --
# so the choice is which way to be wrong, and a spurious prompt is the honest direction where a
# silent miss is not. Both are recorded in the accepted-false-positive list in
# standards/SECURITY-GUARDRAILS.md rather than left for the next reviewer to rediscover.
confirm_regex "(^|[^a-z])git (.*)-c *[\"']?commit\.gpgsign[\"']? *= *[\"']?(false|no|off|0)([^a-z0-9]|$)" "bypasses commit signing (local governance)"
confirm_regex "(^|[^a-z])git (.{0,300})config (.{0,300})[\"']?commit\.gpgsign[\"']? *[= ] *[\"']?(false|no|off|0)([^a-z0-9]|$)" "bypasses commit signing (local governance)"
confirm_regex "(^|[^a-z])git (.{0,300})config (.{0,300})--unset(-all)? +[\"']?commit\.gpgsign" "bypasses commit signing (local governance)"
confirm_regex "(^|[^a-z])git (.*)--no-gpg-sign" "bypasses commit signing (local governance)"
confirm_boundary "git merge" "merge into a shared/base branch — standards/SECURITY-GUARDRAILS.md CONFIRM tier"  # WHY: precipitating incident for that CONFIRM-tier row was a plain `git merge`, not `gh pr merge` (already denied elsewhere)

# WARN: credential/secrets access — legitimate workflows exist, surface the access only
warn "id_rsa"           "SSH private key access"                # WHY: SSH private key — may be intentional (key setup)
warn ".pem"             "certificate or key file access"        # WHY: cert/key files — may be intentional (TLS mgmt)
warn ".env.production"  "production secrets file"               # WHY: production secrets — surface access, don't block
warn "credentials.json" "credential file access"                # WHY: credential file — may be intentional (auth setup)

exit 0
