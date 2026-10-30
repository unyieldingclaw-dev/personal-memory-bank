#!/usr/bin/env bash
# pre-approval-check.sh -- Stop hook enforcing the Pre-Approval Protocol (standards/WORKFLOW.md).
#
# Tier A: a turn ending in an approve-or-choose ask must carry a "Findings" heading AND a
# Recommendation. Tier B: a turn ending in any other question must carry a Recommendation.
# Spec: docs/superpowers/specs/2026-09-21-pre-approval-protocol-design.md
#
# WHY a JSON decision on stdout and exit 0, never exit 2: settings.json runs this script as the
# second link of `pwsh ... || bash ... || <fallback notifier> || true`, with stderr discarded, so an
# exit-2 reason on stderr never reaches the harness -- the same finding dangerous-commands.sh records
# for PreToolUse. A non-zero exit would also make the chain run its next link, the fallback
# notifier: a second popup, or one after a block.
#
# WHY this script owns the "Claude has paused" notification: the old popup was a separate, modal
# Stop entry the harness waited on, so a block would have shown "waiting for input" about an ask
# that was about to be replaced, and the redo could not start until the user clicked OK.

LOG=".pmb-pre-approval.log"
ERR_LOG=".pmb-hook-errors.log"
BLOCKED=0

REASON_A='Pre-approval protocol: this message asks the user to approve or choose, but lacks a Findings section and/or a Recommendation. Run the checks the options depend on (standards/WORKFLOW.md, Pre-Approval Protocol) and re-send the ask with both. If it does not ask for approval or a choice, reply `Not an approval ask:` with one line of why, and stop.'
REASON_B='Pre-approval protocol: this message ends in a question but gives no Recommendation. Add what you recommend and why. If no recommendation can apply (for example, you need a fact only the user has), reply `No recommendation applies:` with one line of why, and stop.'

notify() {
    # WHY one backgrounding line shared by the stub and the real popup (review finding T1): the tests
    # swap only the inner command, so they exercise the exact launch production uses.
    # WHY the redirects: a Git Bash background job that keeps the hook's pipes open holds the hook
    # until the child exits (measured 3,126 ms without, 194 ms with).
    (
        if [ -n "${PMB_NOTIFY_STUB:-}" ]; then
            sleep "${PMB_NOTIFY_STUB_DELAY:-0}"
            echo notify >> "$PMB_NOTIFY_STUB"
        else
            # WHY WScript.Shell.Popup with a 600 s timeout, not a MessageBox: nothing else closes a
            # detached popup, so ignored ones would pile up (user decision 2026-09-22, spec section 3).
            powershell.exe -NoProfile -Command "(New-Object -ComObject WScript.Shell).Popup('Claude has paused and is waiting for input.', 600, 'Claude Code', 64) | Out-Null"
            osascript -e 'display notification "Claude has paused and is waiting for input." with title "Claude Code"'
            notify-send 'Claude Code' 'Claude has paused and is waiting for input.'
        fi
    ) >/dev/null 2>&1 </dev/null &
    return 0
}

# At most one line per kind, so a persistent fault cannot bury other hooks' errors in `mb doctor`'s
# `tail -3` of the shared log. The key has a session field, but it is always `-`: two callers pass it
# literally, and the third passes the classifier's `ERROR - parse` line, whose session field is `-`
# (most errors come before a session id is known). So in practice it is once per kind until the log
# is cleared. The trial log still records each fail-open this script reaches.
log_error_once() {
    local key="pre-approval-check.sh: session=$1 kind=$2"
    grep -qF -- "$key" "$ERR_LOG" 2>/dev/null && return 0
    printf '[%s] [HOOK] %s %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$key" "$3" >> "$ERR_LOG" 2>/dev/null
    return 0
}

# Every fail-open also goes to the trial log (review finding F6): a truncated payload would otherwise
# let exactly the long, Findings-heavy asks through while the trial counted only blocks.
log_failopen() {
    printf '%s session=%s event=failopen kind=%s\n' "$(date '+%Y-%m-%dT%H:%M:%S')" "$1" "$2" >> "$LOG" 2>/dev/null
    return 0
}

trap '[ "$BLOCKED" = "1" ] || notify; exit 0' EXIT

[ "${PMB_PRE_APPROVAL:-}" = "off" ] && exit 0

INPUT=$(cat 2>/dev/null)

if ! command -v python3 >/dev/null 2>&1; then
    log_error_once "-" "no-python3" "python3 not found; turn allowed without checking"
    log_failopen "-" "no-python3"
    exit 0
fi

# The classifier. The payload reaches it only on stdin, never interpolated into this source.
# pre-approval-check.ps1 implements the same rules; tests/test-pre-approval-check.sh holds them in parity.
PY_SRC=$(cat <<'PY'
import json, re, sys
FLAGS = re.I | re.M
ASK = re.compile(r'should I (proceed|continue)|want me to|shall I|go ahead|does that work|which (option|approach|would you)|your call|tell me (which|whether|how|what)|how would you like|would you like|proceed\?|(say|type) "approved"|\bapprove (it|this|that|the)\b|\bapprove\?|say the word|your go-ahead|let me know (if|once|whether|when|which)|before (I|we) (move|proceed|continue|start|begin)', FLAGS)
FINDINGS = re.compile(r'^#{1,4}[ \t].*\bfindings\b', FLAGS)
RECOMMEND = re.compile(r'^#{1,4}[ \t].*recommend|\*\*[^*\n]*recommend|\*\*verdict:', FLAGS)
ESC_A = re.compile(r'^\W*not an approval ask:', re.I)
ESC_B = re.compile(r'^\W*no recommendation applies:', re.I)
try:
    # WHY bytes decoded as UTF-8: on Windows sys.stdin uses the locale code page, which splits each
    # non-ASCII character into several and shrinks the 400-character window (review finding F5).
    d = json.loads(sys.stdin.buffer.read().decode("utf-8", "replace"))
    if not isinstance(d, dict):
        raise ValueError("payload is not a JSON object")
except Exception:
    print("ERROR - parse")
    sys.exit(0)
sid = str(d.get("session_id") or "-")[:8]
msg = d.get("last_assistant_message")
msg = msg if isinstance(msg, str) else ""
has_f = bool(FINDINGS.search(msg))
has_r = bool(RECOMMEND.search(msg))
if d.get("stop_hook_active") is True:
    esc = "not_an_approval_ask" if ESC_A.search(msg) else ("no_recommendation_applies" if ESC_B.search(msg) else "none")
    print("POSTBLOCK %s findings=%s recommendation=%s escape=%s" % (sid, "yes" if has_f else "no", "yes" if has_r else "no", esc))
    sys.exit(0)
if not msg.strip():
    print("ALLOW " + sid)
    sys.exit(0)
end = msg[-400:]
tier_a = bool(ASK.search(end))
lines = [l for l in re.split(r'\r\n|\n|\r', end) if l.strip()]
tier_b = (not tier_a) and bool(lines) and lines[-1].rstrip().rstrip("*_`'\")").rstrip().endswith("?")
if tier_a and not (has_f and has_r):
    missing = "both" if not (has_f or has_r) else ("findings" if not has_f else "recommendation")
    print("BLOCK %s A %s" % (sid, missing))
elif tier_b and not has_r:
    print("BLOCK %s B recommendation" % sid)
else:
    print("ALLOW " + sid)
PY
)

if [ "${PMB_PRE_APPROVAL_TEST_FAULT:-}" = "1" ]; then
    RESULT=""   # test-only: simulates a classifier failure (tests/test-pre-approval-check.sh)
else
    # WHY -I: with plain -c, Python puts the cwd first on sys.path, so a json.py or re.py there would
    # be imported in place of the standard library, run its code, and disable the check (review
    # finding S2). -I also ignores PYTHON* environment variables and the user site directory.
    RESULT=$(printf '%s' "$INPUT" | python3 -I -c "$PY_SRC" 2>/dev/null)
fi

read -r KIND SID REST <<EOF
$RESULT
EOF
NOW=$(date '+%Y-%m-%dT%H:%M:%S')

case "$KIND" in
    BLOCK)
        read -r TIER MISSING <<EOF
$REST
EOF
        BLOCKED=1
        printf '%s session=%s event=block tier=%s missing=%s\n' "$NOW" "$SID" "$TIER" "$MISSING" >> "$LOG" 2>/dev/null
        if [ "$TIER" = "A" ]; then REASON="$REASON_A"; else REASON="$REASON_B"; fi
        printf '{"decision":"block","reason":"%s"}\n' "$REASON"
        ;;
    POSTBLOCK)
        printf '%s session=%s event=post-block %s\n' "$NOW" "$SID" "$REST" >> "$LOG" 2>/dev/null
        ;;
    ALLOW)
        ;;
    ERROR)
        log_error_once "$SID" "$REST" "payload could not be parsed; turn allowed without checking"
        log_failopen "$SID" "$REST"
        ;;
    *)
        log_error_once "-" "no-result" "classifier produced no result; turn allowed without checking"
        log_failopen "-" "no-result"
        ;;
esac
exit 0
