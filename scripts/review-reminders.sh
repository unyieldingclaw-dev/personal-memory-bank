#!/usr/bin/env sh
# PreToolUse hook — blocks git commit/push until the matching review slash command has run,
# and unconditionally blocks `gh pr merge` outright. /code-review writes
# .claude/.code-review-ok on an Approve verdict; /change-review writes .claude/.change-review-ok
# when no finding is Blocking. Each marker authorizes exactly one commit or push attempt for a
# SPECIFIC diff -- see below.
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
# WHY the marker holds a SHA-256 hash of the reviewed diff, not an empty file: an empty
# marker is trivially fakeable with `touch` -- anyone (or a rushed agent) can satisfy the
# gate without actually reviewing anything. Binding the marker to a hash of the exact diff
# means it only authorizes committing/pushing that SPECIFIC diff; if the working tree
# changes after the review, the hash no longer matches and the gate re-engages.
#
# WHY the marker is consumed via an atomic rename (mv), not a separate [ -f ] + rm: check-
# then-delete has a TOCTOU window between the two steps. mv's underlying rename is a single
# filesystem operation -- if the source doesn't exist, the move simply fails, collapsing
# "does it exist" and "claim it" into one step.
#
# WHY this also records a pre-state SHA before consuming the marker: see the companion
# PostToolUse hook (review-reminders-post.sh) -- if the gated commit/push then fails, that
# hook detects the relevant git ref didn't move and reissues the marker, so a rejected
# attempt (e.g. a separate pre-commit hook) doesn't force a pointless re-review.
#
# WHY match raw stdin instead of extracting the "command" field: a `grep -o
# '"command":"[^"]*"'` extraction breaks on any JSON-escaped quote inside the command,
# silently truncating the match and letting anything after it through unchecked. Since
# "git commit"/"git push" only plausibly appear in this hook's stdin inside the command
# field, matching the raw payload directly is robust to that escaping edge case.
#
# WHY hookSpecificOutput.permissionDecision, not top-level "continue": top-level
# {"continue": false} only stops the agent's turn *after* the tool call has already run --
# it does not prevent execution. Verified empirically with a real git commit.
#
# sha256_file()/diff_hash()/resolve_cd_root() are defined in _review-gate-lib.sh -- see that
# file for their WHY (byte-parity hashing, worktree-safe root resolution, fail-open
# semantics). Fails open (skips the gate) if the lib is missing or unreadable.
. "$(dirname "$0")/_review-gate-lib.sh" 2>/dev/null || exit 0

input=$(cat 2>/dev/null)
[ -z "$input" ] && exit 0

root=$(resolve_cd_root)
[ -z "$root" ] && root=$(git rev-parse --show-toplevel 2>/dev/null)
[ -z "$root" ] && exit 0

# WHY cd here, not -C "$root" on every git call below: resolving root fixes where the marker
# is looked FOR, but diff_hash() and the pre-commit/pre-push SHA capture further down still
# run bare `git diff`/`git rev-parse` calls with no directory anchor -- the exact same ambient-
# cwd assumption just fixed above, just at different call sites. Anchoring the whole rest of
# this script to $root once, here, means every git call downstream is correct by construction
# instead of each one needing to remember -C "$root" individually (and any git call added to
# this file later inherits correctness for free instead of silently reintroducing the bug).
cd "$root" 2>/dev/null || exit 0

deny() {
    printf '{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"deny","permissionDecisionReason":"%s"}}\n' "$1"
}

# Attempt an atomic claim: rename the marker to a private name. Fails harmlessly if the
# marker doesn't exist. Prints the claimed marker's content (a hash) on success, empty on
# failure -- caller compares against the expected hash.
consume_marker() {
    marker="$1"
    claimed="$marker.claimed.$$"
    if ! mv "$marker" "$claimed" 2>/dev/null; then
        printf ''
        return 1
    fi
    content=$(cat "$claimed" 2>/dev/null | tr -d '[:space:]')
    rm -f "$claimed"
    printf '%s' "$content"
}

case "$input" in
    *'git commit'*)
        expected=$(diff_hash HEAD)
        marker="$root/.claude/.code-review-ok"
        actual=$(consume_marker "$marker")
        if [ -n "$expected" ] && [ "$actual" = "$expected" ]; then
            presha=$(git rev-parse HEAD 2>/dev/null)
            [ -n "$presha" ] && printf '%s' "$presha" > "$root/.claude/.pending-commit-presha"
        else
            deny "Run /code-review before committing -- it writes a diff-bound review-ok marker this hook checks. If you already reviewed, the working tree changed since then; re-run /code-review."
        fi
        ;;
    *'git push'*)
        expected=$(diff_hash origin/main...HEAD)
        rc=$?
        if [ "$rc" -ne 0 ]; then
            expected=$(diff_hash HEAD)
        fi
        marker="$root/.claude/.change-review-ok"
        actual=$(consume_marker "$marker")
        if [ -n "$expected" ] && [ "$actual" = "$expected" ]; then
            presha=$(git rev-parse '@{u}' 2>/dev/null)
            [ -n "$presha" ] && printf '%s' "$presha" > "$root/.claude/.pending-push-presha"
        else
            deny "Run /change-review before pushing -- it writes a diff-bound review-ok marker this hook checks. If you already reviewed, the diff changed since then; re-run /change-review."
        fi
        ;;
    *'gh pr merge'*)
        deny "This agent never merges pull requests, even with explicit instruction -- merging shared history requires a human to run the command directly. Run this gh pr merge command yourself."
        ;;
esac
exit 0
