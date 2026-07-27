#!/usr/bin/env sh
# PostToolUse hook — companion to review-reminders.sh (PreToolUse). If a git commit/push
# that consumed a review-ok marker then failed, reissues the marker so a rejected attempt
# (e.g. a separate pre-commit hook, nothing staged, a merge conflict) doesn't force a
# pointless re-review -- the diff hasn't changed, so the same review still applies.
#
# WHY compare git ref state instead of parsing tool_response: the exact PostToolUse
# response schema isn't worth depending on when the question can be answered from ground
# truth instead -- if HEAD (for commit) or the upstream ref (for push) didn't move, the
# command failed, full stop.

# WHY hash a file written via redirection: see the matching comment in review-reminders.sh
# -- capturing `git diff` via `$(...)` strips its trailing newline, but a redirected file
# preserves it, matching review-reminders.ps1's byte semantics exactly regardless of which
# hook variant actually enforces the gate on a given machine.
sha256_file() {
    file="$1"
    if command -v sha256sum >/dev/null 2>&1; then
        sha256sum "$file" | cut -d' ' -f1
    elif command -v shasum >/dev/null 2>&1; then
        shasum -a 256 "$file" | cut -d' ' -f1
    else
        printf ''
    fi
}

# WHY this helper: see the matching comment in review-reminders.sh -- collapses the
# mktemp+redirect+hash+cleanup pattern that was previously inlined at both call sites below,
# with a trap so an early exit between mktemp and cleanup can't leak a temp file.
diff_hash() {
    tmp=$(mktemp)
    trap 'rm -f "$tmp"' EXIT
    git diff "$@" > "$tmp" 2>/dev/null
    rc=$?
    sha256_file "$tmp"
    rm -f "$tmp"
    trap - EXIT
    return $rc
}

input=$(cat 2>/dev/null)
[ -z "$input" ] && exit 0

# WHY match against extract_command()'s parsed tool_input.command, not the raw stdin
# payload: see the matching comment in review-reminders.sh -- the real Bash tool's payload
# also carries tool_input.description alongside command, so raw-stdin matching can trigger
# on a read-only command whose description merely mentions "git commit"/"git push", falsely
# reissuing a review-ok marker for a commit/push that never actually happened. Matching the
# parsed command value instead (falling back to raw stdin only when python3 is missing or
# JSON parsing fails) fixes this while keeping the same fail-open-to-over-triggering safety
# direction as the rest of this file.
#
# WHY extract_command() parses the JSON once and resolve_cd_root() takes the already-
# extracted command as a plain-string argument instead of re-parsing JSON itself, and WHY
# extract_command() distinguishes "parsing failed" from "tool_input.command legitimately
# parsed to an empty string" via an explicit presence check and exit code: see the matching
# comments in review-reminders.sh -- both hooks share this exact design.
extract_command() {
    command -v python3 >/dev/null 2>&1 || return 1
    result=$(python3 - "$input" 2>/dev/null <<'PYEOF'
import sys, json

try:
    data = json.loads(sys.argv[1])
    tool_input = data.get("tool_input", {})
    if "command" not in tool_input:
        sys.exit(1)
    sys.stdout.write(tool_input["command"])
except Exception:
    sys.exit(1)
PYEOF
)
    rc=$?
    [ "$rc" -ne 0 ] && return 1
    printf '%s' "$result" | tr -d '\r'
}

# WHY this exists: see the matching comment in review-reminders.sh -- root=$(git rev-parse
# --show-toplevel) trusts the hook process's own ambient cwd, which is empirically wrong for
# some dispatched-subagent sessions. Deriving root from the gated command's own leading `cd`
# fixes this regardless of the underlying cause.
#
# WHY resolve the FULL leading cd chain, and WHY a heredoc+argv instead of `-c "..."`+stdin:
# see the matching comment in review-reminders.sh -- both hooks share this exact function.
resolve_cd_root() {
    # $1: the already-extracted tool_input.command value (a plain string, not JSON) -- see
    # extract_command() above. This function no longer parses JSON at all.
    command -v python3 >/dev/null 2>&1 || return 1
    cd_path=$(python3 - "$1" <<'PYEOF' 2>/dev/null | tr -d '\r'
import sys, os, re

cmd = sys.argv[1]
dq = re.compile(r'^cd\s+"([^"]+)"\s*&&\s*')
sq = re.compile(r"^cd\s+'([^']+)'\s*&&\s*")
rest = cmd
cur = os.getcwd()
matched = False
while True:
    m = dq.match(rest) or sq.match(rest)
    if not m:
        break
    matched = True
    p = m.group(1)
    cur = p if os.path.isabs(p) else os.path.normpath(os.path.join(cur, p))
    rest = rest[m.end():]

print(cur if matched else "")
PYEOF
)
    [ -z "$cd_path" ] && return 1
    cd_root_result=$(git -C "$cd_path" rev-parse --show-toplevel 2>/dev/null)
    [ -z "$cd_root_result" ] && return 1
    printf '%s' "$cd_root_result"
}

if match_target=$(extract_command); then
    extracted=1
else
    match_target="$input"
    extracted=0
fi

# WHY the cmd check runs before resolve_cd_root(), not after: this hook has matcher "Bash" in
# .claude/settings.json, so it fires on EVERY Bash tool call, not just git commit/push --
# resolve_cd_root() (a second python3 fork) and the git rev-parse fallback below are wasted
# work for the overwhelming majority of calls that aren't a commit/push attempt at all.
# Checking cmd first and exiting early preserves the cheap common case; only real commit/push
# attempts pay for root resolution below.
cmd=""
case "$match_target" in
    *'git commit'*) cmd="commit" ;;
    *'git push'*) cmd="push" ;;
esac
[ -z "$cmd" ] && exit 0

root=""
[ "$extracted" = "1" ] && root=$(resolve_cd_root "$match_target")
[ -z "$root" ] && root=$(git rev-parse --show-toplevel 2>/dev/null)
[ -z "$root" ] && exit 0

# WHY cd here: see the matching comment in review-reminders.sh -- diff_hash() and the
# postsha rev-parse calls below still run bare git commands with no directory anchor.
cd "$root" 2>/dev/null || exit 0

if [ "$cmd" = "commit" ]; then
    preshafile="$root/.claude/.pending-commit-presha"
    if [ -f "$preshafile" ]; then
        presha=$(cat "$preshafile" 2>/dev/null | tr -d '[:space:]')
        rm -f "$preshafile"
        postsha=$(git rev-parse HEAD 2>/dev/null)
        if [ -n "$presha" ] && [ -n "$postsha" ] && [ "$postsha" = "$presha" ]; then
            diff_hash HEAD > "$root/.claude/.code-review-ok"
        fi
    fi
elif [ "$cmd" = "push" ]; then
    preshafile="$root/.claude/.pending-push-presha"
    if [ -f "$preshafile" ]; then
        presha=$(cat "$preshafile" 2>/dev/null | tr -d '[:space:]')
        rm -f "$preshafile"
        postsha=$(git rev-parse '@{u}' 2>/dev/null)
        if [ -n "$presha" ] && [ -n "$postsha" ] && [ "$postsha" = "$presha" ]; then
            hash=$(diff_hash origin/main...HEAD)
            rc=$?
            if [ "$rc" -ne 0 ]; then
                hash=$(diff_hash HEAD)
            fi
            printf '%s' "$hash" > "$root/.claude/.change-review-ok"
        fi
    fi
fi
exit 0
