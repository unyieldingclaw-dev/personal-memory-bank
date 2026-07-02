#!/usr/bin/env sh
# PreToolUse hook — blocks git commit/push until the matching review slash command has run.
# /code-review writes .claude/.code-review-ok on an Approve verdict; /change-review writes
# .claude/.change-review-ok when no finding is Blocking. Each marker authorizes exactly one
# commit or push -- this hook deletes it the moment it's consumed, so the next change needs a
# fresh review. Uses the {"continue": false, "stopReason": ...} JSON-stdout protocol (not exit
# codes) because settings.json wires this hook with a "|| true" fail-open suffix for portability
# across machines without pwsh/bash -- that wrapping swallows a nonzero exit code, but stdout
# JSON survives it and is what Claude Code actually reads to decide whether to block.

input=$(cat 2>/dev/null)
[ -z "$input" ] && exit 0

cmd=$(printf '%s' "$input" | grep -o '"command":"[^"]*"' | sed 's/"command":"//;s/"$//' 2>/dev/null)
[ -z "$cmd" ] && exit 0

root=$(git rev-parse --show-toplevel 2>/dev/null)
[ -z "$root" ] && exit 0

case "$cmd" in
    "git commit"*|*"&& git commit"*|*"; git commit"*|*"| git commit"*)
        marker="$root/.claude/.code-review-ok"
        if [ -f "$marker" ]; then
            rm -f "$marker"
        else
            printf '{"continue": false, "stopReason": "Run /code-review before committing -- it writes the review-ok marker this hook checks."}\n'
        fi
        ;;
    "git push"*|*"&& git push"*|*"; git push"*|*"| git push"*)
        marker="$root/.claude/.change-review-ok"
        if [ -f "$marker" ]; then
            rm -f "$marker"
        else
            printf '{"continue": false, "stopReason": "Run /change-review before pushing -- it writes the review-ok marker this hook checks."}\n'
        fi
        ;;
esac
exit 0
