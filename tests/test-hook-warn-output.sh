#!/usr/bin/env bash
# tests/test-hook-warn-output.sh — WARN-tier PreToolUse hooks emit one JSON object, not plain text
#
# WHY this test exists: Claude Code only records a PreToolUse hook's plain-text stdout (debug log,
# session file) -- the model never sees it, and per the docs the visible transcript does not show
# it. Measured 2026-10-14 with two throwaway hooks on one Write call (headless `claude -p`): in
# the main agent the model reported the JSON `additionalContext` codeword and not the plain-text
# one; a separate run showed the JSON codeword reaching a subagent too. So every WARN these hooks
# printed was invisible. The doc also requires stdout to be NOTHING BUT the JSON object, so a
# second notice printed as a second object, or a line of text beside one, voids the whole output.
#
# What each hook must emit, and to whom:
#   dangerous-commands WARN      -> systemMessage (user) + additionalContext (model)
#   dangerous-commands HOOK ERROR -> systemMessage only
#   warn-stale-review-marker     -> additionalContext only (agent advice; firing on every edit
#                                   while a marker exists would be noise in the user's UI)
#   delegation-depth-check       -> systemMessage only (user decision 2026-10-14: an agent-count
#                                   budget is the operator's call; nudging the model to
#                                   "consolidate" mid-review would push it to drop reviewers)
#
# Every hook runs inside a temp dir: delegation-depth-check writes its state file to the CWD, and
# the suite is not concurrency-safe against the real checkout.
set -u

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$REPO_ROOT/tests/helpers/assert.sh"

echo "=== WARN-tier hook output tests ==="

TMPDIR_HW="$(mktemp -d 2>/dev/null || mktemp -d -t pmb-hook-warn-test)"
trap 'rm -rf "$TMPDIR_HW"' EXIT

HAVE_PWSH=0
command -v pwsh >/dev/null 2>&1 && HAVE_PWSH=1
TWINS="sh"
[ "$HAVE_PWSH" -eq 1 ] && TWINS="sh ps1"
if [ "$HAVE_PWSH" -eq 0 ]; then
    echo "!!! pwsh not on PATH -- ps1 twin assertions and cross-shell parity did NOT run."
    if [ "${PMB_REQUIRE_PARITY:-}" = "1" ]; then
        assert_contains "pwsh-missing" "pwsh-present" "PMB_REQUIRE_PARITY=1 but pwsh is not on PATH"
    fi
fi

# run_hook <twin> <hook-name> <workdir> <payload> -- stdout only, \r stripped.
# WHY stdout only: stdout is the channel Claude Code parses; stderr is discarded by the
# settings.json wiring (2>/dev/null) and never reaches anyone.
run_hook() {
    local twin="$1" hook="$2" dir="$3" payload="$4"
    if [ "$twin" = "sh" ]; then
        (cd "$dir" && printf '%s' "$payload" | bash "$REPO_ROOT/scripts/$hook.sh" 2>/dev/null) | tr -d '\r'
    else
        (cd "$dir" && printf '%s' "$payload" | pwsh -NoLogo -NonInteractive -File "$REPO_ROOT/scripts/$hook.ps1" 2>/dev/null) | tr -d '\r'
    fi
}

# shape <stdout> -- EMPTY, INVALID, or "OBJ" followed by one field per line:
#   sys=<systemMessage or -> / ctx=<additionalContext or -> / evt=<hookEventName or -> /
#   dec=<permissionDecision or -> / why=<permissionDecisionReason or -> /
#   keys=<sorted top-level keys> /
#   hkeys=<sorted hookSpecificOutput keys>
# WHY exact key sets: a field asserted by name alone passes when an extra key rides along -- e.g. a
# systemMessage added to a hook that must reach only the model.
# WHY a real parser over the WHOLE stdout: "contains a JSON-looking line" would pass the exact
# failure this suite guards against -- text beside the object, or two objects.
# WHY PYTHONIOENCODING: on Windows python3's stdio defaults to cp1252, so a decoded "≤" (the ps1
# twin escapes it as \u2264) raised on print AFTER "OBJ" was out -- measured: the shape read as a
# valid object with every field empty. UTF-8 on both sides also decodes the sh twin's raw bytes.
shape() {
    printf '%s' "$1" | PYTHONIOENCODING=utf-8 python3 -c '
import json, sys
t = sys.stdin.read()
if t.strip() == "":
    print("EMPTY"); sys.exit(0)
try:
    d = json.loads(t)
except Exception:
    print("INVALID"); sys.exit(0)
if not isinstance(d, dict):
    print("INVALID"); sys.exit(0)
h = d.get("hookSpecificOutput") or {}
print("OBJ")
print("sys=" + str(d.get("systemMessage", "-")))
print("ctx=" + str(h.get("additionalContext", "-")))
print("evt=" + str(h.get("hookEventName", "-")))
print("dec=" + str(h.get("permissionDecision", "-")))
print("why=" + str(h.get("permissionDecisionReason", "-")))
print("keys=" + ",".join(sorted(d.keys())))
print("hkeys=" + ",".join(sorted(h.keys())))
'
}

field() { printf '%s\n' "$1" | sed -n "s/^$2=//p"; }

payload_bash() {
    python3 -c 'import json,sys; print(json.dumps({"tool_name":"Bash","tool_input":{"command":sys.argv[1]}}))' "$1"
}

mkdir -p "$TMPDIR_HW/dc"

# ── dangerous-commands: every WARN row ──────────────────────────────────────────────────────
# WHY every row, with exact values: the four rows share one emitter, but each row's reason is its
# own literal -- a row whose reason broke the JSON, or that stopped matching, would pass a test of
# one row. Exact strings also pin "one WARNING: per match" in the systemMessage and none in the
# model-facing text.
echo ""
echo "--- dangerous-commands: each WARN row emits one object to user and model ---"
P_ONE=$(payload_bash 'cat ~/.ssh/id_rsa')
for row in 'cat ~/.ssh/id_rsa|SSH private key access' \
           'cat server.pem|certificate or key file access' \
           'cat .env.production|production secrets file' \
           'cat credentials.json|credential file access'; do
    c="${row%%|*}"; r="${row#*|}"
    p=$(payload_bash "$c")
    for t in $TWINS; do
        s=$(shape "$(run_hook "$t" dangerous-commands "$TMPDIR_HW/dc" "$p")")
        assert_equals "$(printf '%s' "$s" | head -1)" "OBJ" "$t: '$c' output is exactly one JSON object"
        assert_equals "$(field "$s" sys)" "WARNING: $r. Proceeding." "$t: '$c' systemMessage is exactly its WARNING line"
        assert_equals "$(field "$s" ctx)" "dangerous-commands hook: this command matches $r (WARN tier: surfaced, not blocked)." "$t: '$c' additionalContext is exactly its model-facing line"
        assert_equals "$(field "$s" keys)" "hookSpecificOutput,systemMessage" "$t: '$c' top-level keys are exactly systemMessage + hookSpecificOutput"
        assert_equals "$(field "$s" hkeys)" "additionalContext,hookEventName" "$t: '$c' hookSpecificOutput keys are exactly hookEventName + additionalContext"
        assert_equals "$(field "$s" evt)" "PreToolUse" "$t: '$c' hookEventName is PreToolUse"
    done
done

# ── dangerous-commands: two WARN rows merge into ONE object ─────────────────────────────────
echo ""
echo "--- dangerous-commands: two WARN rows merge into one object ---"
P_TWO=$(payload_bash 'cat ~/.ssh/id_rsa server.pem')
for t in $TWINS; do
    s=$(shape "$(run_hook "$t" dangerous-commands "$TMPDIR_HW/dc" "$P_TWO")")
    assert_equals "$(printf '%s' "$s" | head -1)" "OBJ" "$t: two WARN rows still produce exactly one JSON object"
    assert_equals "$(field "$s" sys)" "WARNING: SSH private key access. Proceeding. WARNING: certificate or key file access. Proceeding." "$t: merged systemMessage has both reasons, one WARNING: each"
    assert_equals "$(field "$s" ctx)" "dangerous-commands hook: this command matches SSH private key access, certificate or key file access (WARN tier: surfaced, not blocked)." "$t: merged additionalContext has both reasons"
    assert_equals "$(field "$s" keys)" "hookSpecificOutput,systemMessage" "$t: merged object's top-level keys are exact"
done

# ── dangerous-commands: silent and deny paths are unchanged ─────────────────────────────────
echo ""
echo "--- dangerous-commands: a benign command is silent; a BLOCK with a WARN filename is deny only ---"
P_BENIGN=$(payload_bash 'echo hello')
P_BLOCK=$(payload_bash 'rm -rf /tmp/x/id_rsa')
for t in $TWINS; do
    assert_equals "$(shape "$(run_hook "$t" dangerous-commands "$TMPDIR_HW/dc" "$P_BENIGN")" | head -1)" "EMPTY" "$t: benign command prints nothing"
    s=$(shape "$(run_hook "$t" dangerous-commands "$TMPDIR_HW/dc" "$P_BLOCK")")
    assert_equals "$(printf '%s' "$s" | head -1)" "OBJ" "$t: BLOCK + WARN filename is exactly one JSON object"
    assert_equals "$(field "$s" dec)" "deny" "$t: BLOCK + WARN filename still denies"
    assert_equals "$(field "$s" why)" "BLOCK: irreversible recursive deletion. Refusing this command." "$t: the deny reason is exactly the BLOCK row's"
    # WHY exact key sets here too, per twin: the parity check below compares the twins with each
    # other, so it cannot see a key added to both, and it does not run at all without pwsh.
    assert_equals "$(field "$s" keys)" "hookSpecificOutput" "$t: the deny carries no WARN systemMessage (BLOCK exits first)"
    assert_equals "$(field "$s" hkeys)" "hookEventName,permissionDecision,permissionDecisionReason" "$t: the deny's hookSpecificOutput keys are exact (nothing model-facing beside it)"
done

# ── dangerous-commands: empty stdin ─────────────────────────────────────────────────────────
# The twins already differ here (sh announces the fail-open, ps1 exits silently) -- not this
# change's to settle. Asserted: whatever each prints is parseable, and the sh notice is visible.
echo ""
echo "--- dangerous-commands: empty stdin is empty or one object ---"
for t in $TWINS; do
    s=$(shape "$(run_hook "$t" dangerous-commands "$TMPDIR_HW/dc" "")")
    case "$(printf '%s' "$s" | head -1)" in EMPTY|OBJ) r=ok ;; *) r=bad ;; esac
    assert_equals "$r" "ok" "$t: empty-stdin output is empty or one JSON object"
done
s=$(shape "$(run_hook sh dangerous-commands "$TMPDIR_HW/dc" "")")
assert_contains "$(field "$s" sys)" "HOOK ERROR" "sh: the fail-open notice is a systemMessage"
assert_equals "$(field "$s" keys)" "systemMessage" "sh: the fail-open notice is user-facing only (systemMessage is the only key)"

# ── warn-stale-review-marker ────────────────────────────────────────────────────────────────
echo ""
echo "--- warn-stale-review-marker: silent without a marker, one model-facing object with one ---"
P_EDIT='{"tool_name":"Edit","tool_input":{"file_path":"x.txt"}}'
mkdir -p "$TMPDIR_HW/ws-none/.claude" "$TMPDIR_HW/ws-one/.claude" "$TMPDIR_HW/ws-two/.claude"
: > "$TMPDIR_HW/ws-one/.claude/.code-review-ok"
: > "$TMPDIR_HW/ws-two/.claude/.code-review-ok"
: > "$TMPDIR_HW/ws-two/.claude/.change-review-ok"
ws_note() { printf 'Note: %s exists (an unconsumed review-gate marker). Editing now will invalidate it before commit/push -- if the last verdict was Approve, tell the user before editing further.' "$1"; }
WS_NOTE_CR=$(ws_note .claude/.code-review-ok)
WS_NOTE_CHR=$(ws_note .claude/.change-review-ok)
for t in $TWINS; do
    assert_equals "$(shape "$(run_hook "$t" warn-stale-review-marker "$TMPDIR_HW/ws-none" "$P_EDIT")" | head -1)" "EMPTY" "$t: no marker, no output"
    s=$(shape "$(run_hook "$t" warn-stale-review-marker "$TMPDIR_HW/ws-one" "$P_EDIT")")
    assert_equals "$(printf '%s' "$s" | head -1)" "OBJ" "$t: one marker gives exactly one JSON object"
    # WHY the exact text: the model now reads this note, so its advice is behaviour -- it must point
    # the agent at the user, not at committing or pushing on its own.
    assert_equals "$(field "$s" ctx)" "$WS_NOTE_CR" "$t: additionalContext is exactly the code-review marker note"
    assert_equals "$(field "$s" keys)" "hookSpecificOutput" "$t: no systemMessage (model-facing advice only)"
    assert_equals "$(field "$s" hkeys)" "additionalContext,hookEventName" "$t: hookSpecificOutput keys are exactly hookEventName + additionalContext"
    assert_equals "$(field "$s" evt)" "PreToolUse" "$t: hookEventName is PreToolUse"
    s=$(shape "$(run_hook "$t" warn-stale-review-marker "$TMPDIR_HW/ws-two" "$P_EDIT")")
    assert_equals "$(printf '%s' "$s" | head -1)" "OBJ" "$t: two markers still give exactly one JSON object"
    assert_equals "$(field "$s" ctx)" "$WS_NOTE_CR $WS_NOTE_CHR" "$t: merged additionalContext is both marker notes, in order"
    assert_equals "$(field "$s" keys)" "hookSpecificOutput" "$t: merged note has no systemMessage either"
    assert_equals "$(field "$s" hkeys)" "additionalContext,hookEventName" "$t: merged hookSpecificOutput keys are exact"
done

# ── delegation-depth-check ──────────────────────────────────────────────────────────────────
echo ""
echo "--- delegation-depth-check: silent under budget, user-facing systemMessage over it ---"
P_AGENT='{"tool_name":"Agent","tool_input":{"prompt":"x"}}'
NOW_TS=$(date '+%Y-%m-%d %H:%M')
for t in $TWINS; do
    d="$TMPDIR_HW/dd-under-$t"; mkdir -p "$d"
    assert_equals "$(shape "$(run_hook "$t" delegation-depth-check "$d" "$P_AGENT")" | head -1)" "EMPTY" "$t: first spawn prints nothing"
    assert_contains "$(cat "$d/.pmb-delegation-depth" 2>/dev/null)" "depth=1" "$t: first spawn records depth=1"
    # WHY both sides of the threshold: the sixth spawn (stored depth 5) must stay silent and the
    # seventh (stored depth 6) must warn, so a changed budget or comparison fails here directly.
    d="$TMPDIR_HW/dd-edge-$t"; mkdir -p "$d"
    printf 'depth=5\ntimestamp=%s\n' "$NOW_TS" > "$d/.pmb-delegation-depth"
    assert_equals "$(shape "$(run_hook "$t" delegation-depth-check "$d" "$P_AGENT")" | head -1)" "EMPTY" "$t: sixth spawn (at budget) prints nothing"
    d="$TMPDIR_HW/dd-over-$t"; mkdir -p "$d"
    printf 'depth=6\ntimestamp=%s\n' "$NOW_TS" > "$d/.pmb-delegation-depth"
    s=$(shape "$(run_hook "$t" delegation-depth-check "$d" "$P_AGENT")")
    assert_equals "$(printf '%s' "$s" | head -1)" "OBJ" "$t: over budget gives exactly one JSON object"
    # Exact text, decoded: the ps1 twin writes the budget sign as an escape, the parser restores it.
    assert_equals "$(field "$s" sys)" "[WARN] Agent spawn count: 7 in this checkout since the last 2-hour break (budget: ≤6 per standards/PERFORMANCE-BUDGET.md). High agent volume increases prompt-injection surface. Consider consolidating tasks." "$t: systemMessage is exactly the budget WARN (per checkout, ≤6)"
    assert_equals "$(field "$s" keys)" "systemMessage" "$t: systemMessage only -- nothing reaches the model"
done

# ── cross-shell parity: the twins emit the same bytes ───────────────────────────────────────
# WHY bytes, not parsed fields: identical output is the simplest proof the twins agree, and these
# messages are ASCII-only except delegation's "≤", which the ps1 twin escapes -- so that one case
# compares parsed fields instead.
if [ "$HAVE_PWSH" -eq 1 ]; then
    echo ""
    echo "--- cross-shell parity ---"
    for p in "$P_ONE" "$P_TWO" "$(payload_bash 'cat server.pem')" \
             "$(payload_bash 'cat .env.production')" "$(payload_bash 'cat credentials.json')"; do
        assert_equals "$(run_hook ps1 dangerous-commands "$TMPDIR_HW/dc" "$p")" \
                      "$(run_hook sh dangerous-commands "$TMPDIR_HW/dc" "$p")" "dangerous-commands twins emit identical bytes: $p"
    done
    # The deny path predates this change and its ps1 Deny builds an unordered hashtable, so key
    # order differs between twins (measured) -- both valid. Compared parsed, not byte-for-byte.
    assert_equals "$(shape "$(run_hook ps1 dangerous-commands "$TMPDIR_HW/dc" "$P_BLOCK")")" \
                  "$(shape "$(run_hook sh dangerous-commands "$TMPDIR_HW/dc" "$P_BLOCK")")" "dangerous-commands twins emit the same parsed deny"
    for w in ws-one ws-two; do
        assert_equals "$(run_hook ps1 warn-stale-review-marker "$TMPDIR_HW/$w" "$P_EDIT")" \
                      "$(run_hook sh warn-stale-review-marker "$TMPDIR_HW/$w" "$P_EDIT")" "warn-stale-review-marker twins emit identical bytes: $w"
    done
    for t in sh ps1; do
        d="$TMPDIR_HW/dd-par-$t"; mkdir -p "$d"
        printf 'depth=6\ntimestamp=%s\n' "$NOW_TS" > "$d/.pmb-delegation-depth"
        eval "par_$t=\$(shape \"\$(run_hook $t delegation-depth-check \"\$d\" \"\$P_AGENT\")\")"
    done
    assert_equals "$par_ps1" "$par_sh" "delegation-depth-check twins emit the same parsed fields"
fi

print_summary
