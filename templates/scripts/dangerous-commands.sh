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
# python3's json.load is a real parser, not a fragile regex -- it handles escaped quotes
# correctly, so it closes the false-positive gap without reintroducing the
# truncation risk. Matches dangerous-commands.ps1's existing ConvertFrom-Json approach
# and this repo's established precedent (check-contract.sh, review-reminders.sh's
# resolve_cd_root()).
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
    d = json.load(sys.stdin)
    print(d.get('tool_input', {}).get('command', ''))
except Exception:
    sys.exit(1)
" 2>/dev/null)
    [ $? -eq 0 ] && cmd="$extracted"
fi

deny() {
    printf '{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"deny","permissionDecisionReason":"%s"}}\n' "$1"
}

block() {
    # BLOCK: irreversible or highly destructive — refuse unconditionally
    case "$cmd" in
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
}

confirm() {
    # CONFIRM: advanced op with legitimate uses — require explicit manual invocation
    case "$cmd" in
        *"$1"*)
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

# WARN: credential/secrets access — legitimate workflows exist, surface the access only
warn "id_rsa"           "SSH private key access"                # WHY: SSH private key — may be intentional (key setup)
warn ".pem"             "certificate or key file access"        # WHY: cert/key files — may be intentional (TLS mgmt)
warn ".env.production"  "production secrets file"               # WHY: production secrets — surface access, don't block
warn "credentials.json" "credential file access"                # WHY: credential file — may be intentional (auth setup)

exit 0
