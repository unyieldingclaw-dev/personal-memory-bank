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

# WHY match against a quote/backslash-stripped, lowercased copy, not $match_target itself: see
# the matching comment in review-reminders.sh -- a command like `git c"o"mmit -m "x"` executes,
# after real shell quote removal, as a genuine `git commit -m x`, but the command TEXT never
# contains "git commit" as a contiguous substring; and review-reminders.ps1's `-match` is
# case-insensitive by default while this file's `case`/esac isn't, so `Git Commit` would pass
# through unmatched here even though its .ps1 counterpart would catch it. Neither transform
# touches $match_target itself, which resolve_cd_root() below still needs with real quoting and
# casing intact. Both can only make a match MORE likely to fire -- the same safe direction as
# everywhere else here.
match_target_stripped=$(printf '%s' "$match_target" | tr -d "\"'\\\\" | tr 'A-Z' 'a-z')

# WHY the cmd check runs before resolve_cd_root(), not after: this hook has matcher "Bash" in
# .claude/settings.json, so it fires on EVERY Bash tool call, not just git commit/push --
# resolve_cd_root() (a second python3 fork) and the git rev-parse fallback below are wasted
# work for the overwhelming majority of calls that aren't a commit/push attempt at all.
# Checking cmd first and exiting early preserves the cheap common case; only real commit/push
# attempts pay for root resolution below.
#
# WHY needs_commit/needs_push (two independent checks), not one first-match case/esac: see the
# matching comment in review-reminders.sh -- a compound `git commit -m x && git push origin
# main` contains both substrings. A single case/esac only reissues whichever marker matches
# first, silently leaving the OTHER action's presha file unprocessed (and therefore never
# reissued, and never cleaned up) even though the compound command may have genuinely failed
# on both halves. Checking both independently means a compound command's commit and push
# outcomes are each reconciled on their own.
needs_commit=0
needs_push=0
case "$match_target_stripped" in *'git commit'*) needs_commit=1 ;; esac
case "$match_target_stripped" in *'git push'*) needs_push=1 ;; esac
[ "$needs_commit" = "0" ] && [ "$needs_push" = "0" ] && exit 0

root=""
[ "$extracted" = "1" ] && root=$(resolve_cd_root "$match_target")
[ -z "$root" ] && root=$(git rev-parse --show-toplevel 2>/dev/null)
[ -z "$root" ] && exit 0

# WHY cd here: see the matching comment in review-reminders.sh -- the postsha rev-parse
# calls below still run bare git commands with no directory anchor.
cd "$root" 2>/dev/null || exit 0

# WHY replay the persisted .pending-*-hash instead of recomputing diff_hash fresh here: this
# used to recompute the hash fresh on the assumption "a failed commit/push can't have altered
# the working tree" -- false whenever a downstream project's OWN pre-commit hook mutates files
# and then rejects the commit (e.g. an auto-formatter running `black --check`/`prettier
# --check`, a common and unexceptional pattern). HEAD doesn't move in that case, but the diff
# does -- recomputing fresh would reissue a marker for a diff /code-review or /change-review
# never actually saw. Replaying the hash review-reminders.sh persisted at validation time means
# the reissued marker always corresponds to a diff that was genuinely reviewed.
#
# WHY fail CLOSED (skip reissuing) rather than falling back to a fresh recompute when the hash
# file is missing/torn: falling back to fresh-recompute would silently reintroduce the exact
# bug this fix closes for that one anomalous case. A missing hash file (presha exists without
# its paired hash, or vice versa) means the pending state doesn't fully describe a validated
# attempt this hook can safely vouch for -- the safe direction is no reissue, forcing an
# explicit re-review. This pairing also bounds the impact of overlapping commit/push attempts
# racing on these unkeyed files (e.g. two subagent sessions, or a retry while a prior attempt's
# hooks are still running): even if one attempt's presha/hash pair gets clobbered by another's,
# whatever pair survives is still SOME genuinely-validated hash from a real prior review, never
# an arbitrary freshly-derived value reflecting whatever the tree happens to look like right
# now -- the race can misattribute which attempt's marker gets reissued, but can't manufacture
# an unreviewed one.
if [ "$needs_commit" = "1" ]; then
    preshafile="$root/.claude/.pending-commit-presha"
    hashfile="$root/.claude/.pending-commit-hash"
    if [ -f "$preshafile" ]; then
        presha=$(cat "$preshafile" 2>/dev/null | tr -d '[:space:]')
        orighash=""
        [ -f "$hashfile" ] && orighash=$(cat "$hashfile" 2>/dev/null | tr -d '[:space:]')
        rm -f "$preshafile" "$hashfile"
        postsha=$(git rev-parse HEAD 2>/dev/null)
        if [ -n "$presha" ] && [ -n "$postsha" ] && [ "$postsha" = "$presha" ] && [ -n "$orighash" ]; then
            printf '%s' "$orighash" > "$root/.claude/.code-review-ok"
        fi
    fi
fi

if [ "$needs_push" = "1" ]; then
    preshafile="$root/.claude/.pending-push-presha"
    hashfile="$root/.claude/.pending-push-hash"
    if [ -f "$preshafile" ]; then
        presha=$(cat "$preshafile" 2>/dev/null | tr -d '[:space:]')
        orighash=""
        [ -f "$hashfile" ] && orighash=$(cat "$hashfile" 2>/dev/null | tr -d '[:space:]')
        rm -f "$preshafile" "$hashfile"
        postsha=$(git rev-parse '@{u}' 2>/dev/null)
        if [ -n "$presha" ] && [ -n "$postsha" ] && [ "$postsha" = "$presha" ] && [ -n "$orighash" ]; then
            printf '%s' "$orighash" > "$root/.claude/.change-review-ok"
        fi
    fi
fi
exit 0
