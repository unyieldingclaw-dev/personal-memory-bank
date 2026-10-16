#!/usr/bin/env bash
# tests/test-pre-approval-check.sh -- the Stop hook that enforces the Pre-Approval Protocol.
#
# WHY both shells: settings.json runs the .ps1 first wherever pwsh exists, so the .sh passing alone
# would leave the code path that actually runs on Windows untested. The .ps1 block is skipped loudly
# (fatal under PMB_REQUIRE_PARITY=1) where pwsh is absent, matching test-pre-compact-check.sh.
#
# WHY every notification assertion waits: the notifier is launched detached by design, so it lands
# after the hook returns. "Not notified" waits too, or it would pass vacuously.
set -u

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$REPO_ROOT/tests/helpers/assert.sh"

echo "=== pre-approval-check tests ==="

SB="$(mktemp -d 2>/dev/null || mktemp -d -t pmb-preapproval-test)"
trap 'rm -rf "$SB"' EXIT
mkdir -p "$SB/scripts"
cp "$REPO_ROOT/scripts/pre-approval-check.sh" "$REPO_ROOT/scripts/pre-approval-check.ps1" "$SB/scripts/" 2>/dev/null

# A fresh stub file per case (review finding T2): a detached notifier from the previous case can land
# ~200 ms after its hook returns, and must not satisfy the next case's "notified" check.
CASE=0
new_stub() {
    CASE=$((CASE + 1))
    STUB="$SB/notify-$CASE.log"
    STUB_NATIVE="$STUB"
    command -v cygpath >/dev/null 2>&1 && STUB_NATIVE="$(cygpath -w "$STUB")"
}
new_stub

now_ms() { python3 -c 'import time; print(int(time.time() * 1000))'; }

# payload MESSAGE [STOP_HOOK_ACTIVE 0|1] -- the message travels in argv, never into Python source.
payload() {
    python3 -c 'import json, sys
print(json.dumps({"session_id": "testsess-0001-aaaa", "prompt_id": "p-1", "hook_event_name": "Stop",
                  "stop_hook_active": sys.argv[2] == "1", "last_assistant_message": sys.argv[1]}))' "$1" "${2:-0}"
}

# payload_utf8_dashes -- a tier A ask followed by 150 em dashes, sent as raw UTF-8 rather than
# \u-escaped, as the harness may send it (review finding F5). Built inside Python so no non-ASCII
# text crosses argv or a console encoding on the way.
payload_utf8_dashes() {
    python3 -c 'import json, sys
msg = "Want me to push it now? " + "\u2014" * 150 + " ok."
sys.stdout.buffer.write(json.dumps({"session_id": "testsess-0001-aaaa", "stop_hook_active": False,
                  "last_assistant_message": msg}, ensure_ascii=False).encode("utf-8"))'
}

# run_case SHELL BODY [ENV=VALUE...] -- fresh state, then one hook run. Sets OUT, CODE, MS.
run_case() {
    rm -f "$SB/.pmb-pre-approval.log" "$SB/.pmb-hook-errors.log"
    new_stub
    rerun_case "$@"
}
# rerun_case -- the same, but keeps the log files from the previous run.
rerun_case() {
    local shell="$1" body="$2" t0 t1
    shift 2
    t0=$(now_ms)
    if [ "$shell" = "ps1" ]; then
        OUT=$(cd "$SB" && printf '%s' "$body" | env PMB_NOTIFY_STUB="$STUB_NATIVE" "$@" pwsh -NoProfile -NonInteractive -File scripts/pre-approval-check.ps1 2>/dev/null)
    else
        OUT=$(cd "$SB" && printf '%s' "$body" | env PMB_NOTIFY_STUB="$STUB" "$@" bash scripts/pre-approval-check.sh 2>/dev/null)
    fi
    CODE=$?
    t1=$(now_ms)
    MS=$((t1 - t0))
}

# notified TIMEOUT_S -- 0 if the detached notifier wrote its stub line within the timeout.
notified() {
    local i=0 max=$(( ${1:-6} * 4 ))
    while [ "$i" -lt "$max" ]; do
        [ -s "$STUB" ] && return 0
        sleep 0.25
        i=$((i + 1))
    done
    return 1
}

log_text() { cat "$SB/.pmb-pre-approval.log" 2>/dev/null; }

# assert_allowed MSG -- the hook printed nothing AND logged no fail-open (review finding T2). An empty
# OUT alone also passes when the classifier crashes and fails open, so a regression that fails every
# compliant ask open would stay green. It does NOT catch a missing script, or a crash before anything
# is logged: neither writes a log. The block cases in this suite catch those.
assert_allowed() {
    assert_equals "$OUT" "" "$1"
    assert_not_contains "$(log_text)" "event=failopen" "$1 (and did not fail open)"
}

check_shell() {
    local S="$1" ask
    echo ""
    echo "--- [$S] classification ---"

    run_case "$S" "$(payload 'Done. The file is updated and the suite is green.')"
    assert_allowed "[$S] a statement is allowed silently"
    notified 6; assert_exit_zero "$?" "[$S] a statement still shows the paused notification"

    run_case "$S" "$(payload 'I checked it. Want me to push it now? Zanzibar')"
    assert_contains "$OUT" '"decision":"block"' "[$S] a tier A ask without sections is blocked"
    assert_contains "$OUT" 'Not an approval ask:' "[$S] a tier A block carries the tier A escape"
    assert_contains "$(log_text)" 'event=block tier=A missing=both' "[$S] a tier A block is logged with what was missing"
    assert_not_contains "$(log_text)" 'Zanzibar' "[$S] the log never contains message text"
    sleep 3; assert_file_not_exists "$STUB" "[$S] no notification on a block"

    for ask in 'Type "approved" to begin, or tell me what to adjust.' \
               'Review the spec and approve it or tell me what to change.' \
               'Say the word and I will push the branch.' \
               'Since it is a deletion, I will wait for your go-ahead.' \
               'Please review it and let me know if you want any changes before we move to the implementation plan.'; do
        run_case "$S" "$(payload "$ask")"
        assert_contains "$OUT" '"decision":"block"' "[$S] tier A: $ask"
    done

    run_case "$S" "$(payload $'Review complete.\n\n**Verdict:** Approve')"
    assert_allowed "[$S] a bare Verdict: Approve line is not an ask"
    run_case "$S" "$(payload 'The protocol covers anything I ask you to approve.')"
    assert_allowed "[$S] mentioning approve in prose is not an ask"

    run_case "$S" "$(payload 'Which should we brainstorm first?')"
    assert_contains "$OUT" 'No recommendation applies:' "[$S] a tier B question without a Recommendation is blocked"
    assert_contains "$(log_text)" 'tier=B missing=recommendation' "[$S] a tier B block is logged"

    run_case "$S" "$(payload '**Which should we brainstorm first?**')"
    assert_contains "$OUT" '"decision":"block"' "[$S] trailing markdown after the ? is still a question"

    run_case "$S" "$(payload $'## Recommendation\nStart with the hook, because it unblocks the rest.\n\nWhich should we brainstorm first?')"
    assert_allowed "[$S] tier B with a Recommendation heading is allowed"

    run_case "$S" "$(payload $'**My recommendation:** start with the hook.\n\nWhich should we brainstorm first?')"
    assert_allowed "[$S] a lower-case recommendation in a bold label counts (case-insensitive)"

    run_case "$S" "$(payload $'## Findings\n| # | Question | How | Result |\n|---|---|---|---|\n| 1 | x | `ls` | ok |\n\n## Recommendation\nShip it.\n\nWant me to proceed?')"
    assert_allowed "[$S] tier A with Findings and Recommendation is allowed"
    notified 6; assert_exit_zero "$?" "[$S] an allowed ask shows the notification"

    run_case "$S" "$(payload $'## FINDINGS\n| 1 | x | `ls` | ok |\n\n## RECOMMENDATION\nShip it.\n\nWant me to proceed?')"
    assert_allowed "[$S] upper-case section headings count (review finding F10)"

    run_case "$S" "$(payload $'I ran the checks below before asking.\n\n## Findings\n| 1 | x | `ls` | ok |\n\n## Recommendation\nShip it.\n\nWant me to proceed?')"
    assert_allowed "[$S] a Findings heading after a preamble line counts (multiline anchor; review finding T3)"

    # 150 em dashes are 150 characters but 450 bytes. Decoded as UTF-8, the ask stays inside the
    # 400-character window; decoded byte by byte (the ibm437/cp1252 bug), it falls outside and is missed.
    run_case "$S" "$(payload_utf8_dashes)"
    assert_contains "$OUT" '"decision":"block"' "[$S] raw UTF-8 input is decoded as UTF-8 (review finding F5)"

    run_case "$S" "$(payload $'## Findings\n| 1 | x | `ls` | ok |\n\nWant me to proceed?')"
    assert_contains "$(log_text)" 'missing=recommendation' "[$S] Findings without a Recommendation is blocked"

    run_case "$S" "$(payload $'## Supported Findings\n| Domain | Severity |\n\n**Verdict:** Approve\n\nWant me to commit?')"
    assert_allowed "[$S] a /code-review-shaped report (Supported Findings + Verdict) is allowed"

    echo "--- [$S] loop guard and post-block logging ---"
    run_case "$S" "$(payload 'Not an approval ask: that was a status update.' 1)"
    assert_allowed "[$S] stop_hook_active true is always allowed"
    assert_contains "$(log_text)" 'event=post-block findings=no recommendation=no escape=not_an_approval_ask' "[$S] the tier A escape is logged"
    notified 6; assert_exit_zero "$?" "[$S] the post-block stop shows the notification"

    run_case "$S" "$(payload 'I checked it. Want me to push it now?' 1)"
    assert_allowed "[$S] stop_hook_active true allows even an unsectioned tier A ask (review finding F8)"

    run_case "$S" "$(payload 'No recommendation applies: I need the repo URL from you.' 1)"
    assert_contains "$(log_text)" 'escape=no_recommendation_applies' "[$S] the tier B escape is logged separately"

    run_case "$S" "$(payload $'## Findings\n| 1 | x | `ls` | ok |\n\n## Recommendation\nShip it.\n\nWant me to proceed?' 1)"
    assert_contains "$(log_text)" 'findings=yes recommendation=yes escape=none' "[$S] sections added after a block are logged"

    echo "--- [$S] kill switch, fail-open, detachment ---"
    run_case "$S" "$(payload 'Want me to push it now?')" PMB_PRE_APPROVAL=off
    assert_equals "$OUT" "" "[$S] PMB_PRE_APPROVAL=off allows even a tier A ask"
    assert_file_not_exists "$SB/.pmb-pre-approval.log" "[$S] PMB_PRE_APPROVAL=off logs nothing"
    notified 6; assert_exit_zero "$?" "[$S] PMB_PRE_APPROVAL=off still notifies"

    run_case "$S" "$(payload 'Want me to push it now?')" PMB_PRE_APPROVAL=OFF
    assert_contains "$OUT" '"decision":"block"' "[$S] the kill switch is case-sensitive: OFF does not disable it (review finding C2)"

    if [ "$S" = "sh" ]; then
        # A json.py in the hook's cwd must not shadow the standard library (review finding S2).
        printf 'open("shadowed", "w").write("x")\n' > "$SB/json.py"
        run_case "$S" "$(payload 'Want me to push it now?')"
        rm -f "$SB/json.py"
        assert_contains "$OUT" '"decision":"block"' "[$S] a json.py in the cwd does not disable the check (python3 -I; review finding S2)"
        assert_file_not_exists "$SB/shadowed" "[$S] a json.py in the cwd is never imported"
    fi

    run_case "$S" "$(payload '')"
    assert_allowed "[$S] an empty message is allowed"

    run_case "$S" 'this is not json'
    assert_equals "$OUT" "" "[$S] malformed JSON is allowed"
    assert_exit_zero "$CODE" "[$S] malformed JSON exits 0"
    notified 6; assert_exit_zero "$?" "[$S] malformed JSON still notifies"
    assert_contains "$(log_text)" 'event=failopen kind=parse' "[$S] a parse fail-open is recorded in the trial log (review finding F6)"
    rerun_case "$S" 'this is not json'
    assert_equals "$(grep -c 'kind=parse' "$SB/.pmb-hook-errors.log" 2>/dev/null)" "1" "[$S] a repeated parse error is logged once"

    run_case "$S" "$(payload 'Want me to push it now?')" PMB_PRE_APPROVAL_TEST_FAULT=1
    assert_equals "$OUT" "" "[$S] an unexpected fault allows the turn"
    assert_exit_zero "$CODE" "[$S] an unexpected fault exits 0"
    notified 6; assert_exit_zero "$?" "[$S] an unexpected fault still notifies"
    assert_contains "$(log_text)" 'event=failopen kind=' "[$S] an unexpected fault is recorded in the trial log (review finding F6)"

    run_case "$S" "$(payload 'Done.')" PMB_NOTIFY_STUB_DELAY=6
    assert_contains "fast=$([ "$MS" -lt 3000 ] && echo yes || echo no) ms=$MS" "fast=yes" "[$S] a 6 s notifier does not delay the hook (under 3 s)"
    notified 10; assert_exit_zero "$?" "[$S] the slow notifier still ran after the hook returned"
}

check_shell sh

if command -v pwsh >/dev/null 2>&1; then
    check_shell ps1
else
    echo ""
    echo "--- [ps1] SKIPPED (pwsh not on PATH) ---"
    echo "!!! WARNING: the .ps1 twin did NOT run. Set PMB_REQUIRE_PARITY=1 to make this a failure."
    if [ "${PMB_REQUIRE_PARITY:-0}" = "1" ]; then
        assert_contains "pwsh-missing" "pwsh-present" "PMB_REQUIRE_PARITY=1 but pwsh is not on PATH"
    fi
fi

# ── twin parity: the rule literals, compared directly (review finding T1) ──────────────────────
# WHY on top of the behavioural cases: those exercise only a few of the ASK alternatives, so a typo
# in one twin's copy of any other alternative passed every case. Python raw strings and PowerShell
# single-quoted strings both keep backslashes literally, so identical source text means identical
# pattern text. A renamed variable fails too: each literal must be found exactly once in each twin.
# NOT compared: the regex options. Python's flags and PowerShell's RegexOptions have no common
# spelling. The behavioural cases pin IgnoreCase and Multiline for ASK, FINDINGS and RECOMMEND;
# nothing pins the two escape regexes' options.
# WHY -c and not `python3 - FILE <<heredoc`: on Windows, python3 can be the Python install manager,
# which then treats the first FILE argument as the script and runs its shebang. Here that ran the
# hook script itself with bash.
echo ""
echo "--- twin parity: rule literals ---"
PARITY_SRC=$(cat <<'PY'
import re, sys
sh = open(sys.argv[1], encoding="utf-8").read()
ps = open(sys.argv[2], encoding="utf-8").read()
out = []
for py_name, ps_name in [("ASK", "askRx"), ("FINDINGS", "findingsRx"), ("RECOMMEND", "recommendRx"), ("ESC_A", "escARx"), ("ESC_B", "escBRx")]:
    a = re.findall(r"^%s = re\.compile\(r'(.*)', " % py_name, sh, re.M)
    b = re.findall(r"^\$%s = \[regex\]::new\('(.*)', " % ps_name, ps, re.M)
    out.append(py_name + "=" + ("same" if len(a) == 1 and len(b) == 1 and a[0] == b[0] else "DIFFERENT"))
# One line, written with no newline: Windows Python's text-mode stdout turns each newline into CRLF,
# and the command substitution below strips only a trailing newline, so a CR would remain.
sys.stdout.write(" ".join(out))
PY
)
PARITY=$(python3 -I -c "$PARITY_SRC" "$REPO_ROOT/scripts/pre-approval-check.sh" "$REPO_ROOT/scripts/pre-approval-check.ps1" 2>&1)
assert_equals "$PARITY" "ASK=same FINDINGS=same RECOMMEND=same ESC_A=same ESC_B=same" "the five rule regexes' pattern literals are identical in both twins (options not compared)"

# ── settings.json wiring: the exact command the harness runs ─────────────────────────────────
echo ""
echo "--- settings.json Stop wiring ---"
STOP_INFO=$(python3 -c 'import json, sys
s = json.load(open(sys.argv[1], encoding="utf-8"))
cmds = [h["command"] for e in s["hooks"].get("Stop", []) for h in e.get("hooks", [])]
print(len(cmds))
print(cmds[0] if cmds else "")' "$REPO_ROOT/.claude/settings.json")
STOP_COUNT=$(printf '%s\n' "$STOP_INFO" | sed -n 1p)
CHAIN=$(printf '%s\n' "$STOP_INFO" | sed -n 2p)
assert_equals "$STOP_COUNT" "1" "exactly one Stop hook (the old modal popup entry is gone)"
assert_contains "$CHAIN" "pre-approval-check.ps1" "the Stop hook runs pre-approval-check"
bash -n -c "$CHAIN" 2>/dev/null
assert_exit_zero "$?" "the Stop command parses as shell"

new_stub
rm -f "$SB/chain.out"
( cd "$SB" && payload 'Want me to push it now?' | PMB_NOTIFY_STUB="$STUB" bash -c "$CHAIN" > "$SB/chain.out" 2>/dev/null )
assert_contains "$(cat "$SB/chain.out")" '"decision":"block"' "the block JSON is already written when the chain returns (primary path is synchronous)"

BROKEN="${CHAIN//pre-approval-check/no-such-hook}"
new_stub
( cd "$SB" && payload 'Done.' | PMB_NOTIFY_STUB="$STUB" bash -c "$BROKEN" >/dev/null 2>&1 )
notified 6; assert_exit_zero "$?" "with both scripts missing, the fallback link still notifies"

print_summary
