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
# WHY only commit attempts get failure recovery: HEAD identifies the exact ref a commit can
# move, so the PostToolUse hook can prove failure. A push may target a different remote/ref
# from @{u}; inferring success from the configured upstream minted a fresh marker after a
# successful alternate-remote push. Push markers therefore remain single-use on every attempt.
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
# ORDER IS LOAD-BEARING. Classification comes FIRST, before anything that can fail open.
#
# The previous order was: source the lib (`|| exit 0`), resolve the repo root (`|| exit 0`),
# then classify. Both of those early exits are ALLOW, so any tree missing the lib -- or any
# payload whose root could not be resolved -- skipped the gate entirely for a real commit,
# push or merge. That is not hypothetical: `mb upgrade` run inside a git worktree writes this
# script (which dot-sources the lib) WITHOUT writing the lib, because the TEMPLATE_OWNED list
# it copies from is the literal in the worktree's own older mb.sh. The result is a tree whose
# gate is silently disabled, produced by the repo's own upgrade path.
#
# Classification needs neither the lib nor the root, so it runs first. Once the verdict says
# a guarded verb is being invoked, every subsequent failure DENIES instead of allowing: for a
# command we know to be gated, "I could not check" must never read as "go ahead".

input=$(cat 2>/dev/null)
[ -z "$input" ] && exit 0

deny() {
    printf '{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"deny","permissionDecisionReason":"%s"}}\n' "$1"
}

# CLAIM-THEN-RESTORE. Two properties have to hold at once, and the obvious shapes each give
# up one of them:
#
#   * Single-use under concurrency. `mv` within a directory is atomic, so exactly one caller
#     can win the rename. Peeking first and consuming after the comparison loses this: two
#     concurrent gated commands both read the same valid marker, both compare equal, and both
#     proceed, because only the rename is atomic and by then it is too late to matter. This
#     repo runs concurrent sessions by design (.claude/session-claims.json), so that is live.
#   * A denial must not destroy the marker. The original consume-first code burned an
#     expensively-earned marker on every denial, including denials raised by a DIFFERENT hook
#     for an unrelated reason -- which also left a `.pending-*-presha` file whose reissue path
#     could then mint a marker for a tree nobody had reviewed.
#
# Claiming atomically and PUTTING THE MARKER BACK when the hash does not match keeps both: the
# rename is still the single point of mutual exclusion, and the only path that consumes is the
# one that is about to allow the command. No check on a race window is needed, because there
# is no window -- which matters because a race is not something a sequential test can prove,
# and an unprovable guard is the kind this repo's Evidence Integrity rule rejects.
claim_marker() {
    marker="$1"
    claimed="$marker.claimed.$$"
    mv "$marker" "$claimed" 2>/dev/null || return 1
    cat "$claimed" 2>/dev/null | tr -d '[:space:]'
    return 0
}

# Give a claimed marker back, unconsumed. Used when the comparison fails.
release_marker() {
    mv "$1.claimed.$$" "$1" 2>/dev/null || true
}

# Finish consuming a claimed marker. Used only on the path that allows the command.
drop_marker() {
    rm -f "$1.claimed.$$"
}

# The sha256 of a zero-byte file. diff_hash() hashes a temp file that is empty BOTH when the
# tree is genuinely clean AND when `git diff` fails outright (e.g. `origin/main...HEAD` with
# no merge base, which is the state of 9 of the trees on this machine). Either way `expected`
# becomes this publicly-known constant, which anyone can write into the marker with printf --
# so the gate would be satisfied by a value that attests to nothing. Refuse to gate on it.
# Recorded as [NS-41]; this closes it at the checker for both the commit and push paths.
EMPTY_DIFF_SHA=e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855

# Classify the payload via the shared classifier, which BOTH shells call so they cannot
# diverge. See scripts/_review-gate-classify.py for why this is a parser and not a substring
# match: the substring matcher produced false positives and false negatives simultaneously,
# and both were measured.
#
# Prints COMMIT / PUSH / MERGE / NONE, or nothing when classification was impossible.
classify_payload() {
    command -v python3 >/dev/null 2>&1 || return 1
    [ -f "$(dirname "$0")/_review-gate-classify.py" ] || return 1
    printf '%s' "$input" | python3 "$(dirname "$0")/_review-gate-classify.py" 2>/dev/null
}

verdict=$(classify_payload)
classifier_rc=$?

# WHY a fallback rather than exiting 0: a payload we cannot classify is not evidence the call
# is safe. python3 absent, the classifier missing, or genuinely malformed JSON all land here.
# The fallback is the OLD raw-substring matcher -- imprecise, occasionally noisy, and
# fail-CLOSED, which is the correct direction for a gate. The truncated-payload class is live
# on this machine, so this path is reachable in practice (.pmb-hook-errors.log).
#
# NOTE the asymmetry this creates, which is why the classifier must be at least as WIDE as
# this fallback: the fallback fires only when classification was IMPOSSIBLE (empty output).
# A confident but wrong NONE suppresses it. Six launcher forms were measured escaping exactly
# that way before _review-gate-classify.py learned to scan launcher arguments.
if [ -z "$verdict" ]; then
    # LOWERCASED BEFORE MATCHING, closing a pre-existing hole in this fallback.
    #
    # These literals are lowercase, and `case` is case-sensitive, so an uppercase or mixed-case
    # spelling of the executable walked straight past -- while the parser's is_git() had the
    # identical defect, so BOTH matchers shared it and neither could catch the other's miss.
    # Windows and macOS default filesystems are case-insensitive, so the uppercase spelling
    # invokes the same executable, and this repo develops on Windows. That is the class the
    # branch fix/block-tier-case-sensitivity is named for.
    #
    # `tr` is POSIX and needs no python3 -- which matters here specifically, because this whole
    # branch exists for the case where python3 or the classifier is unavailable. A fallback that
    # depended on the thing it is falling back from would be no fallback at all.
    lower=$(printf '%s' "$input" | tr '[:upper:]' '[:lower:]')
    fallback_count=0
    fallback_verdict=NONE
    case "$lower" in *'git commit'*) fallback_count=$((fallback_count + 1)); fallback_verdict=COMMIT ;; esac
    case "$lower" in *'git push'*) fallback_count=$((fallback_count + 1)); fallback_verdict=PUSH ;; esac
    case "$lower" in *'gh pr merge'*) fallback_count=$((fallback_count + 1)); fallback_verdict=MERGE ;; esac
    if [ "$fallback_count" -gt 1 ]; then verdict=MULTI; else verdict=$fallback_verdict; fi
fi

# Nothing guarded: leave without touching the lib, the root, or any marker.
[ "$verdict" = NONE ] && exit 0

# One diff-bound marker authorizes exactly one guarded action, never an entire command chain.
if [ "$verdict" = MULTI ]; then
    deny "Review gate: compound commands containing multiple guarded actions must be run separately so each action receives its own authorization."
    exit 0
fi

# A merge needs no root and no marker -- it is refused unconditionally.
if [ "$verdict" = MERGE ]; then
    deny "This agent never merges pull requests, even with explicit instruction -- merging shared history requires a human to run the command directly. Run the merge command yourself."
    exit 0
fi

# From here the command IS gated, so every failure below denies.
#
# sha256_file()/diff_hash()/resolve_cd_root() live in _review-gate-lib.sh -- see that file for
# their WHY (byte-parity hashing, worktree-safe root resolution).
if ! . "$(dirname "$0")/_review-gate-lib.sh" 2>/dev/null; then
    deny "Review gate cannot run: scripts/_review-gate-lib.sh is missing or unreadable, so the marker check is unavailable. This is a broken installation, not a passed review -- restore the file (or run mb upgrade from the MAIN worktree) before committing or pushing."
    exit 0
fi

root=""
if [ "$classifier_rc" -eq 0 ]; then
    context=$(printf '%s' "$input" | python3 "$(dirname "$0")/_review-gate-classify.py" --git-context 2>/dev/null)
    context_rc=$?
    if [ "$context_rc" -ne 0 ]; then
        deny "Review gate classified a guarded command but could not resolve its repository context."
        exit 0
    fi
    context=$(printf '%s' "$context" | tr -d '\r')
    if [ "$context" = "__UNSUPPORTED_GIT_CONTEXT__" ]; then
        deny "Review gate cannot safely bind this command's explicit --git-dir/--work-tree context to a repository. Run the command from that repository instead."
        exit 0
    fi
    if [ -n "$context" ]; then
        context_dir=$(pwd -P)
        context_ok=1
        while IFS= read -r context_path; do
            [ -z "$context_path" ] && continue
            next_dir=$(cd "$context_dir" 2>/dev/null && cd "$context_path" 2>/dev/null && pwd -P) || {
                context_ok=0
                break
            }
            context_dir="$next_dir"
        done <<EOF
$context
EOF
        if [ "$context_ok" -ne 1 ]; then
            deny "Review gate cannot resolve the command's explicit repository path, so it cannot verify the correct marker."
            exit 0
        fi
        root=$(git -C "$context_dir" rev-parse --show-toplevel 2>/dev/null)
        if [ -z "$root" ]; then
            deny "Review gate could not resolve a repository from the command's explicit path."
            exit 0
        fi
    fi
fi
[ -z "$root" ] && root=$(resolve_cd_root)
[ -z "$root" ] && root=$(git rev-parse --show-toplevel 2>/dev/null)
if [ -z "$root" ]; then
    deny "Review gate cannot run: the repository root could not be resolved for this command, so the marker check is unavailable. Run the command from inside the repository, or prefix it with cd \"<repo>\" && so the gate can bind to the right tree."
    exit 0
fi

# WHY cd here, not -C "$root" on every git call below: resolving root fixes where the marker
# is looked FOR, but diff_hash() and the pre-commit/pre-push SHA capture further down still
# run bare `git diff`/`git rev-parse` calls with no directory anchor -- the exact same ambient-
# cwd assumption just fixed above, just at different call sites. Anchoring the whole rest of
# this script to $root once, here, means every git call downstream is correct by construction
# instead of each one needing to remember -C "$root" individually (and any git call added to
# this file later inherits correctness for free instead of silently reintroducing the bug).
if ! cd "$root" 2>/dev/null; then
    deny "Review gate cannot run: the resolved repository root $root is not enterable, so the marker check is unavailable."
    exit 0
fi

case "$verdict" in
    COMMIT)
        expected=$(diff_hash HEAD)
        marker="$root/.claude/.code-review-ok"
        if [ -z "$expected" ] || [ "$expected" = "$EMPTY_DIFF_SHA" ]; then
            deny "Review gate: there is no diff to review (git diff HEAD is empty, or git diff failed). The hash of an empty diff is a public constant, so it cannot serve as proof of review. If you are amending or committing an empty change, run the command yourself."
        elif actual=$(claim_marker "$marker"); then
            if [ "$actual" = "$expected" ]; then
                drop_marker "$marker"
                presha=$(git rev-parse HEAD 2>/dev/null)
                # Record the REVIEWED hash beside the pre-commit SHA. review-reminders-post.sh
                # may reissue only a marker equal to this value, so a tree that changed after
                # the review cannot be laundered into an approved one.
                [ -n "$presha" ] && printf '%s %s' "$presha" "$expected" > "$root/.claude/.pending-commit-presha"
            else
                release_marker "$marker"
                deny "Run /code-review before committing -- it writes a diff-bound review-ok marker this hook checks. If you already reviewed, the working tree changed since then; re-run /code-review."
            fi
        else
            deny "Run /code-review before committing -- it writes a diff-bound review-ok marker this hook checks. If you already reviewed, the working tree changed since then; re-run /code-review."
        fi
        ;;
    PUSH)
        expected=$(diff_hash origin/main...HEAD)
        rc=$?
        if [ "$rc" -ne 0 ]; then
            expected=$(diff_hash HEAD)
        fi
        marker="$root/.claude/.change-review-ok"
        if [ -z "$expected" ] || [ "$expected" = "$EMPTY_DIFF_SHA" ]; then
            deny "Review gate: there is no diff to review (both origin/main...HEAD and HEAD produced an empty diff, or git diff failed). The hash of an empty diff is a public constant and cannot serve as proof of review."
        elif actual=$(claim_marker "$marker"); then
            if [ "$actual" = "$expected" ]; then
                drop_marker "$marker"
                # A push can target any remote/ref, so @{u} cannot prove whether it succeeded.
                # Decline ambiguous recovery: a failed attempt needs a fresh change review.
                rm -f "$root/.claude/.pending-push-presha"
            else
                release_marker "$marker"
                deny "Run /change-review before pushing -- it writes a diff-bound review-ok marker this hook checks. If you already reviewed, the diff changed since then; re-run /change-review."
            fi
        else
            deny "Run /change-review before pushing -- it writes a diff-bound review-ok marker this hook checks. If you already reviewed, the diff changed since then; re-run /change-review."
        fi
        ;;
esac
exit 0
