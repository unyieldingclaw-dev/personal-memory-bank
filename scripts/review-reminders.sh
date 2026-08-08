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
# WHY extract tool_input.command via python3 instead of matching raw stdin: raw-payload
# matching treats ANY occurrence of "git commit"/"git push" ANYWHERE in the JSON as if it were
# the command being run -- including tool_input.description, which Claude Code populates from
# the Bash tool's own "description" parameter. Reproduced directly: a Bash call running
# `ls -la` with description "prep before git commit review" was denied as an unreviewed commit,
# even though no commit was ever attempted. extract_command() below parses the actual
# tool_input.command value via python3 and the case match runs against that value alone. A
# `grep -o '"command":"[^"]*"'` extraction was considered and rejected: it breaks on any
# JSON-escaped quote inside the command, silently truncating the match. Falls back to matching
# raw stdin, exactly like before this fix, only when python3 is missing or the JSON fails to
# parse -- never a silent bypass of the gate.
#
# WHY hookSpecificOutput.permissionDecision, not top-level "continue": top-level
# {"continue": false} only stops the agent's turn *after* the tool call has already run --
# it does not prevent execution. Verified empirically with a real git commit.
#
# WHY sha256sum with a shasum fallback: sha256sum is standard on Linux and in Git for
# Windows' bundled coreutils, but macOS ships shasum instead. If neither is available,
# fail open (skip the gate entirely) rather than deny everything -- matches this repo's
# established "fail open on missing dependency" convention (see check-contract.sh/python3).
#
# WHY hash a file written via redirection, not piped/captured output: this hook is a
# fallback that only runs when pwsh is unavailable (settings.json tries pwsh first), but
# on any machine where BOTH pwsh and bash exist, a marker written by one must validate
# under the other's hook -- whichever runs is a coin flip the writer can't control. Piping
# `git diff | sha256sum` preserves the trailing newline; capturing via `$(git diff ...)`
# strips it. review-reminders.ps1 redirects to a file (`>`), which also preserves it.
# Hashing a redirected file here, instead of piping or capturing, makes this script's hash
# byte-identical to review-reminders.ps1's for the same diff, regardless of which one
# actually enforces the gate on a given machine. Empirically confirmed: command
# substitution and redirect-to-file produced different SHA-256 hashes for the same diff
# (differing by exactly the trailing newline byte) before this fix.

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

# WHY this helper: the commit and push cases below both need "redirect a git diff to a temp
# file, hash it, clean up" -- inlining that 4 times (2 here, 2 more in the companion
# review-reminders-post.sh) risked exactly the kind of copy-paste drift that caused the
# original trailing-newline bug. One helper, one place to get it right.
#
# WHY return git diff's exit code, not the hash computation's: the push case needs to try
# `origin/main...HEAD` and fall back to `HEAD` if that ref doesn't exist (no upstream). The
# caller decides whether to fall back based on whether the underlying `git diff` succeeded,
# not whether hashing succeeded (sha256_file degrades gracefully to an empty string on its
# own, unrelated failure mode) -- so this returns git diff's own exit code via `$rc`,
# captured before sha256_file has a chance to run and overwrite `$?`.
#
# WHY the trap: without it, a script exit between `mktemp` and the final `rm -f` (e.g. an
# unexpected signal) leaks a temp file. `trap - EXIT` clears it again once this function
# returns normally, since sh traps are shell-global, not function-scoped -- otherwise this
# trap would still be armed (harmlessly, but confusingly) for the rest of the script.
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

# WHY sys.stdout.write, not print: print() adds a trailing newline that becomes \r\n on
# Windows python3 builds, requiring a `tr -d '\r'` cleanup step. write() with no newline
# sidesteps the issue entirely -- nothing to strip.
#
# WHY check python3's own exit code, not just whether output is empty: tool_input.command CAN
# legitimately be empty (JSON parsed fine but the field is genuinely absent, e.g. a non-Bash
# tool call) -- that must fall through to "no match" rather than the raw-stdin fallback. Only a
# python3 failure (missing binary, malformed JSON raising in json.loads) should trigger
# fallback. Capturing python3's exit code directly, with no pipe in between, keeps the two
# failure modes distinguishable.
extract_command() {
    command -v python3 >/dev/null 2>&1 || return 1
    extracted=$(python3 - "$input" <<'PYEOF' 2>/dev/null
import sys, json
data = json.loads(sys.argv[1])
sys.stdout.write(data.get("tool_input", {}).get("command", ""))
PYEOF
)
    [ $? -ne 0 ] && return 1
    printf '%s' "$extracted"
    return 0
}

if cmd=$(extract_command); then
    match_target="$cmd"
else
    match_target="$input"
fi

root=$(git rev-parse --show-toplevel 2>/dev/null)
[ -z "$root" ] && exit 0

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

case "$match_target" in
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
