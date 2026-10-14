#!/usr/bin/env bash
# tests/test-hook-warn-output.sh — WARN-tier PreToolUse hooks emit one JSON object, not plain text
#
# WHY this test exists: Claude Code writes a PreToolUse hook's plain-text stdout to its debug log
# only -- the model never sees it, and neither does the transcript. Measured 2026-10-14 with two
# throwaway hooks on one Write call: the model reported the JSON `additionalContext` codeword and
# not the plain-text one, in the main agent and in a subagent. So every WARN these hooks printed
# was invisible. The doc also requires stdout to be NOTHING BUT the JSON object, so a second
# notice printed as a second object, or a line of text beside one, voids the whole output.
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
#   dec=<permissionDecision or -> / keys=<sorted top-level keys>
# WHY a real parser over the WHOLE stdout: "contains a JSON-looking line" would pass the exact
# failure this suite guards against -- text beside the object, or two objects.
# WHY PYTHONIOENCODING: on Windows python3's stdio defaults to cp1252, so a decoded "≤" (the ps1
# twin escapes it as ≤) raised on print AFTER "OBJ" was out -- measured: the shape read as a
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
print("keys=" + ",".join(sorted(d.keys())))
'
}

field() { printf '%s\n' "$1" | sed -n "s/^$2=//p"; }

payload_bash() {
    python3 -c 'import json,sys; print(json.dumps({"tool_name":"Bash","tool_input":{"command":sys.argv[1]}}))' "$1"
}

mkdir -p "$TMPDIR_HW/dc"

# ── dangerous-commands: one WARN row ────────────────────────────────────────────────────────
echo ""
echo "--- dangerous-commands: a WARN row emits one object to user and model ---"
P_ONE=$(payload_bash 'cat ~/.ssh/id_rsa')
for t in $TWINS; do
    out=$(run_hook "$t" dangerous-commands "$TMPDIR_HW/dc" "$P_ONE")
    s=$(shape "$out")
    assert_equals "$(printf '%s' "$s" | head -1)" "OBJ" "$t: id_rsa output is exactly one JSON object"
    assert_equals "$(field "$s" sys)" "WARNING: SSH private key access. Proceeding." "$t: systemMessage carries the WARNING text"
    assert_contains "$(field "$s" ctx)" "SSH private key access" "$t: additionalContext names the access for the model"
    assert_not_contains "$(field "$s" ctx)" "WARNING:" "$t: additionalContext does not repeat the WARNING: token (one notice per match)"
    assert_equals "$(field "$s" evt)" "PreToolUse" "$t: hookEventName is PreToolUse"
    assert_equals "$(field "$s" dec)" "-" "$t: a WARN sets no permissionDecision"
done

# ── dangerous-commands: two WARN rows merge into ONE object ─────────────────────────────────
echo ""
echo "--- dangerous-commands: two WARN rows merge into one object ---"
P_TWO=$(payload_bash 'cat ~/.ssh/id_rsa server.pem')
for t in $TWINS; do
    out=$(run_hook "$t" dangerous-commands "$TMPDIR_HW/dc" "$P_TWO")
    s=$(shape "$out")
    assert_equals "$(printf '%s' "$s" | head -1)" "OBJ" "$t: two WARN rows still produce exactly one JSON object"
    assert_contains "$(field "$s" sys)" "SSH private key access" "$t: merged systemMessage has the first reason"
    assert_contains "$(field "$s" sys)" "certificate or key file access" "$t: merged systemMessage has the second reason"
    assert_contains "$(field "$s" ctx)" "certificate or key file access" "$t: merged additionalContext has the second reason"
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
    assert_equals "$(field "$s" sys)" "-" "$t: the deny carries no WARN systemMessage (BLOCK exits first)"
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
assert_equals "$(field "$s" ctx)" "-" "sh: the fail-open notice is user-facing only"

# ── warn-stale-review-marker ────────────────────────────────────────────────────────────────
echo ""
echo "--- warn-stale-review-marker: silent without a marker, one model-facing object with one ---"
P_EDIT='{"tool_name":"Edit","tool_input":{"file_path":"x.txt"}}'
mkdir -p "$TMPDIR_HW/ws-none/.claude" "$TMPDIR_HW/ws-one/.claude" "$TMPDIR_HW/ws-two/.claude"
: > "$TMPDIR_HW/ws-one/.claude/.code-review-ok"
: > "$TMPDIR_HW/ws-two/.claude/.code-review-ok"
: > "$TMPDIR_HW/ws-two/.claude/.change-review-ok"
for t in $TWINS; do
    assert_equals "$(shape "$(run_hook "$t" warn-stale-review-marker "$TMPDIR_HW/ws-none" "$P_EDIT")" | head -1)" "EMPTY" "$t: no marker, no output"
    s=$(shape "$(run_hook "$t" warn-stale-review-marker "$TMPDIR_HW/ws-one" "$P_EDIT")")
    assert_equals "$(printf '%s' "$s" | head -1)" "OBJ" "$t: one marker gives exactly one JSON object"
    assert_contains "$(field "$s" ctx)" ".claude/.code-review-ok" "$t: additionalContext names the marker"
    assert_equals "$(field "$s" sys)" "-" "$t: no systemMessage (model-facing advice only)"
    assert_equals "$(field "$s" evt)" "PreToolUse" "$t: hookEventName is PreToolUse"
    s=$(shape "$(run_hook "$t" warn-stale-review-marker "$TMPDIR_HW/ws-two" "$P_EDIT")")
    assert_equals "$(printf '%s' "$s" | head -1)" "OBJ" "$t: two markers still give exactly one JSON object"
    assert_contains "$(field "$s" ctx)" ".claude/.change-review-ok" "$t: merged additionalContext names the second marker"
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
    d="$TMPDIR_HW/dd-over-$t"; mkdir -p "$d"
    printf 'depth=6\ntimestamp=%s\n' "$NOW_TS" > "$d/.pmb-delegation-depth"
    s=$(shape "$(run_hook "$t" delegation-depth-check "$d" "$P_AGENT")")
    assert_equals "$(printf '%s' "$s" | head -1)" "OBJ" "$t: over budget gives exactly one JSON object"
    assert_contains "$(field "$s" sys)" "Agent spawn count: 7" "$t: systemMessage carries the count"
    assert_not_contains "$(field "$s" sys)" "this session" "$t: message does not claim a per-session count (the counter is per checkout)"
    assert_equals "$(field "$s" keys)" "systemMessage" "$t: systemMessage only -- nothing reaches the model"
done

# ── cross-shell parity: the twins emit the same bytes ───────────────────────────────────────
# WHY bytes, not parsed fields: identical output is the simplest proof the twins agree, and these
# messages are ASCII-only except delegation's "≤", which the ps1 twin escapes -- so that one case
# compares parsed fields instead.
if [ "$HAVE_PWSH" -eq 1 ]; then
    echo ""
    echo "--- cross-shell parity ---"
    for p in "$P_ONE" "$P_TWO"; do
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
