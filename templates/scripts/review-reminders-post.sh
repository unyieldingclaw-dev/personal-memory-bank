#!/usr/bin/env sh
# PostToolUse hook — companion to review-reminders.sh (PreToolUse). If a git commit that
# consumed a review-ok marker then failed, reissues the marker so a rejected attempt (e.g.
# a separate pre-commit hook, nothing staged, a merge conflict) doesn't force a pointless
# re-review -- the diff hasn't changed, so the same review still applies.
#
# WHY compare git ref state instead of parsing tool_response: the exact PostToolUse
# response schema isn't worth depending on when the question can be answered from ground
# truth instead -- if HEAD didn't move, the commit failed. Push recovery is deliberately
# unsupported because the actual destination may differ from the configured upstream.
#
# sha256_file()/diff_hash()/resolve_cd_root() are defined in _review-gate-lib.sh -- see that
# file for their WHY (byte-parity hashing, worktree-safe root resolution, fail-open
# semantics); shared with review-reminders.sh. Fails open (skips this hook) if the lib is
# missing or unreadable.
. "$(dirname "$0")/_review-gate-lib.sh" 2>/dev/null || exit 0

input=$(cat 2>/dev/null)
[ -z "$input" ] && exit 0

command -v python3 >/dev/null 2>&1 || exit 0
classifier="$(dirname "$0")/_review-gate-classify.py"
[ -f "$classifier" ] || exit 0
verdict=$(printf '%s' "$input" | python3 "$classifier" 2>/dev/null) || exit 0
cmd=""
case "$verdict" in
    COMMIT) cmd="commit" ;;
esac
[ -z "$cmd" ] && exit 0

root=""
context=$(printf '%s' "$input" | python3 "$classifier" --git-context 2>/dev/null) || exit 0
context=$(printf '%s' "$context" | tr -d '\r')
[ "$context" = "__UNSUPPORTED_GIT_CONTEXT__" ] && exit 0
if [ -n "$context" ]; then
    context_dir=$(pwd -P)
    while IFS= read -r context_path; do
        [ -z "$context_path" ] && continue
        context_dir=$(cd "$context_dir" 2>/dev/null && cd "$context_path" 2>/dev/null && pwd -P) || exit 0
    done <<EOF
$context
EOF
    root=$(git -C "$context_dir" rev-parse --show-toplevel 2>/dev/null)
    [ -z "$root" ] && exit 0
fi
[ -z "$root" ] && root=$(resolve_cd_root)
[ -z "$root" ] && root=$(git rev-parse --show-toplevel 2>/dev/null)
[ -z "$root" ] && exit 0

# WHY cd here: see the matching comment in review-reminders.sh -- diff_hash() and the
# postsha rev-parse calls below still run bare git commands with no directory anchor.
cd "$root" 2>/dev/null || exit 0

# WHY the reissue is bound to the REVIEWED hash, and not recomputed here:
#
# The previous version wrote `diff_hash HEAD` computed at POST time. That made the residue a
# bypass primitive rather than a compensator. Reproduced on both shells: earn a marker, have
# the guarded call denied by any other hook so PostToolUse never fires, leave the presha file
# behind, change the tree, then run any command whose text matches the verb -- this hook saw
# the stale presha, found HEAD unmoved, and minted a marker equal to the NEW, unreviewed
# hash. An `echo` was sufficient. Nothing stored what had actually been reviewed, so the
# reissue could not be validated even in principle; the binding was missing, not the check.
#
# review-reminders.sh now records "<presha> <reviewed-hash>". A marker is reissued only when
# HEAD has not moved AND the tree still hashes to the reviewed value -- i.e. the review
# genuinely still stands. Any drift leaves no marker, which is the fail-safe direction.
if [ "$cmd" = "commit" ]; then
    preshafile="$root/.claude/.pending-commit-presha"
    if [ -f "$preshafile" ]; then
        preshaline=$(cat "$preshafile" 2>/dev/null | tr -d '\r')
        rm -f "$preshafile"
        presha=$(printf '%s' "$preshaline" | awk '{print $1}')
        reviewed=$(printf '%s' "$preshaline" | awk '{print $2}')
        postsha=$(git rev-parse HEAD 2>/dev/null)
        if [ -n "$presha" ] && [ -n "$postsha" ] && [ "$postsha" = "$presha" ]; then
            current=$(diff_hash HEAD)
            if [ -n "$reviewed" ] && [ -n "$current" ] && [ "$current" = "$reviewed" ]; then
                printf '%s' "$reviewed" | write_marker_atomic "$root/.claude/.code-review-ok"
            fi
        fi
    fi
fi
exit 0
