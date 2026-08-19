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
#
# sha256_file()/diff_hash()/resolve_cd_root() are defined in _review-gate-lib.sh -- see that
# file for their WHY (byte-parity hashing, worktree-safe root resolution, fail-open
# semantics); shared with review-reminders.sh. Fails open (skips this hook) if the lib is
# missing or unreadable.
. "$(dirname "$0")/_review-gate-lib.sh" 2>/dev/null || exit 0

input=$(cat 2>/dev/null)
[ -z "$input" ] && exit 0

cmd=""
case "$input" in
    *'git commit'*) cmd="commit" ;;
    *'git push'*) cmd="push" ;;
esac
[ -z "$cmd" ] && exit 0

root=$(resolve_cd_root)
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
            diff_hash HEAD | write_marker_atomic "$root/.claude/.code-review-ok"
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
            printf '%s' "$hash" | write_marker_atomic "$root/.claude/.change-review-ok"
        fi
    fi
fi
exit 0
