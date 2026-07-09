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

cmd=""
case "$input" in
    *'git commit'*) cmd="commit" ;;
    *'git push'*) cmd="push" ;;
esac
[ -z "$cmd" ] && exit 0

root=$(git rev-parse --show-toplevel 2>/dev/null)
[ -z "$root" ] && exit 0

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
