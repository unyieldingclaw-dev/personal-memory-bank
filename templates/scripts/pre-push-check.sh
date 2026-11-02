#!/usr/bin/env bash
# Pre-push git hook — full error and warning check before any push.
# Called by .git/hooks/pre-push. Blocks on errors; warns on advisory issues.
# Fails open: unexpected errors print [HOOK ERROR] and allow the push.

set -euo pipefail 2>/dev/null || true   # bash 3 compat

# WHY three counters, not one flag: a check has three possible outcomes — it passed,
# it failed, or it could not run. The original model had only FAILED, so both "warned"
# and "could not determine" rendered as success, and the summary printed
# "All pre-push checks passed" over the top of them. Four of the seven checks below are
# advisory and can never set FAILED, so that summary was asserting a result it had not
# earned. UNKNOWN exists specifically so a check that did not execute cannot be
# mistaken for one that passed.
FAILED=0
WARNED=0
UNKNOWN=0

# ENFORCE=true promotes warnings and unknowns to blocking. Default is advisory, matching
# templates/.github/workflows/memory-bank-size.yml — a gate that blocks on a stale
# template gets disabled within a week, so honesty is the default and enforcement opt-in.
ENFORCE="${ENFORCE:-false}"

RED='\033[0;31m'
YELLOW='\033[1;33m'
GREEN='\033[0;32m'
GRAY='\033[0;90m'
RESET='\033[0m'

echo ""
echo -e "${GREEN}Pre-push checks${RESET}"
echo "==============="
echo ""

# Check 1: Unresolved merge conflicts (block)
CONFLICTS=$(git diff --name-only --diff-filter=U 2>/dev/null || true)
if [ -n "$CONFLICTS" ]; then
    echo -e "${RED}[ERROR] Unresolved merge conflicts:${RESET}"
    echo "$CONFLICTS" | while IFS= read -r f; do echo "        $f"; done
    FAILED=1
    echo ""
fi

# Check 2: Conflict markers in tracked files (block)
if git grep -lq "^<<<<<<< " --cached 2>/dev/null; then
    echo -e "${RED}[ERROR] Conflict markers found in staged files:${RESET}"
    git grep -l "^<<<<<<< " --cached | while IFS= read -r f; do echo "        $f"; done
    FAILED=1
    echo ""
fi

# Check 3: Uncommitted changes in working tree (warn)
DIRTY=$(git status --porcelain 2>/dev/null || true)
if [ -n "$DIRTY" ]; then
    echo -e "${YELLOW}[WARN] Uncommitted changes in working tree:${RESET}"
    echo "$DIRTY" | head -10 | while IFS= read -r line; do echo "       $line"; done
    echo -e "${YELLOW}       Commit or stash before pushing if these should be included.${RESET}"
    WARNED=$((WARNED + 1))
    echo ""
fi

# Check 4: .gitattributes present (warn)
if [ ! -f ".gitattributes" ]; then
    echo -e "${YELLOW}[WARN] No .gitattributes — line-ending normalization not enforced.${RESET}"
    echo "       Create .gitattributes with '* text=auto eol=lf' to suppress CRLF warnings."
    WARNED=$((WARNED + 1))
    echo ""
else
    echo -e "${GREEN}[OK]   .gitattributes present${RESET}"
fi

# Check 5: Possible secrets in commits being pushed (block)
# When a tracking ref exists, diff against it. When there is none (first push or
# untracked branch), scan all commits not yet on any known remote so first pushes
# are covered rather than silently skipped.
REMOTE=$(git rev-parse --abbrev-ref --symbolic-full-name '@{u}' 2>&1 || true)
HAS_UPSTREAM=0
if [[ "$REMOTE" != *"fatal"* ]] && [ -n "$REMOTE" ]; then HAS_UPSTREAM=1; fi

# WHY: fixtures/ and docs/ are excluded from secret scanning:
# fixtures/security/ intentionally contains vulnerable code for regression testing;
# docs/ (specs, plans) may quote fixture content as documentation examples.
if [ "$HAS_UPSTREAM" -eq 1 ]; then
    PUSH_DIFF=$(git diff "${REMOTE}..HEAD" 2>&1 | awk '
        /^\+\+\+ b\// { in_excl = ($0 ~ /^\+\+\+ b\/(fixtures|docs)\//) }
        /^\+[^+]/ && !in_excl { print }
    ' || true)
else
    # WHY: HEAD --not --remotes finds every commit reachable from HEAD but not from any
    # remote-tracking ref — exactly what a first push would send. --format="" drops
    # commit headers so only patch lines remain.
    #
    # WHY `HEAD` is stated explicitly and must not be removed: without a positive rev,
    # `git log --not --remotes` has no starting point to walk from and returns NOTHING
    # when the repo has no remote-tracking refs — silently skipping the secret scan in
    # exactly the first-push case this branch exists to cover, while printing
    # "no commits to push". Verified: in a fresh repo containing a planted AKIA key,
    # the form without HEAD yields 0 lines; with HEAD it yields the commit and the key
    # is caught. Covered by tests/test-pre-push-check.sh.
    PUSH_DIFF=$(git log HEAD --not --remotes --format="" -p 2>&1 | awk '
        /^\+\+\+ b\// { in_excl = ($0 ~ /^\+\+\+ b\/(fixtures|docs)\//) }
        /^\+[^+]/ && !in_excl { print }
    ' || true)
    if [ -z "$PUSH_DIFF" ]; then
        echo -e "${GRAY}[SKIP] Secret scan — no unpushed commits found to scan.${RESET}"
        echo ""
    fi
fi

check_secret() {
    local label="$1" pattern="$2"
    local hits
    hits=$(echo "$PUSH_DIFF" | grep -E "$pattern" | head -3 || true)
    if [ -n "$hits" ]; then
        echo -e "${RED}[ERROR] Possible ${label} in push diff:${RESET}"
        echo "$hits" | while IFS= read -r line; do echo "        $line"; done
        FAILED=1
        echo ""
    fi
}

check_secret "AWS access key"            'AKIA[0-9A-Z]{16}'
check_secret "OpenAI/Anthropic API key"  'sk-[a-zA-Z0-9]{32,}'
check_secret "GitHub personal token"     'ghp_[a-zA-Z0-9]{36}'
check_secret "Generic password"          'password[[:space:]]*=[[:space:]]*["'"'"'][^"'"'"'[:space:]]{8,}'
check_secret "Generic secret"            'secret[[:space:]]*=[[:space:]]*["'"'"'][^"'"'"'[:space:]]{8,}'

# Check 6: Files over 500 KB in push (warn)
if [ "$HAS_UPSTREAM" -eq 1 ]; then
    PUSH_FILE_LIST=$(git diff --name-only "${REMOTE}..HEAD" 2>/dev/null || true)
else
    # `HEAD` explicit for the same reason as the secret scan above — without it this
    # returns nothing when no remote-tracking refs exist.
    PUSH_FILE_LIST=$(git log HEAD --not --remotes --format="" --name-only 2>/dev/null | sort -u | grep -v '^$' || true)
fi
LARGE=$(echo "$PUSH_FILE_LIST" | while IFS= read -r f; do
    if [ -n "$f" ] && [ -f "$f" ]; then
        bytes=$(wc -c < "$f" 2>/dev/null || echo 0)
        if [ "$bytes" -gt 512000 ]; then
            kb=$(( bytes / 1024 ))
            echo "$f (${kb} KB)"
        fi
    fi
done || true)
if [ -n "$LARGE" ]; then
    echo -e "${YELLOW}[WARN] Large files in push (>500 KB):${RESET}"
    echo "$LARGE" | while IFS= read -r line; do echo "       $line"; done
    echo "       Consider .gitignore or Git LFS for binary/generated files."
    WARNED=$((WARNED + 1))
    echo ""
fi

# Check 7: memory-bank integrity via mb doctor
#
# WHY this no longer calls `mb validate`: that command was deprecated into `mb doctor` and
# now resolves to a shim that prints a redirect notice and exits 2 (measured, not assumed).
# The old check treated any non-zero exit as a memory-bank problem, so every push in every
# managed project emitted "[WARN] mb validate reported issues — memory bank may be
# inconsistent:" and then quoted the redirect notice underneath it as though that were the
# evidence. Nothing could clear it: the warning did not describe the memory bank at all, and
# it was immediately followed by "[PASS] All pre-push checks passed" — a self-contradicting
# gate. Observed on ai-code-review-agent, which is pinned at PMB 1.1.1 and still runs the old
# check. An exit code cannot distinguish "ran and passed" from "ran and failed" from "never
# ran" — that is the general trap, and every deprecated alias inherits it.
#
# WHY the verdict is parsed from output rather than taken from an exit code: doctor exits 1
# only for a FATAL finding; its advisory [ERROR] lines (checksum mismatch, startup-context
# ceiling) leave the exit code at 0, so the exit code cannot carry the verdict this check
# reports — and `|| true` below discards it anyway so a fatal run still gets parsed. Its
# output is structured — every check emits [OK], [WARN] or [ERROR] — so counting those lines
# yields both the verdict AND a positive assertion that the command actually ran. Zero result
# lines means no checks executed (deprecated shim, crash, missing binary, or an mb.ps1 old
# enough to reject --check), which is UNKNOWN, never success. Measured: a real run emits ~51
# result lines; the shim emits 0.
#
# WHY `--check`, and why the marker is required: plain `mb doctor` rewrites .pmb-checksums at
# the end of every run, so calling it here re-baselined on every push — a memory-bank
# mismatch was reported once, by the run that then erased it. `--check` compares without
# writing, and confirms so with a fixed ASCII marker line. An mb.sh that predates --check
# ignores the flag and rewrites silently; the missing marker is how that run is caught, as
# UNKNOWN rather than trusted.
#
# WHY the checksum mismatch gets its own line: it would otherwise be folded into the generic
# error count and can fall outside the first-five echo. It counts as a warning, so
# ENFORCE=true blocks until the mismatch is accepted with `mb verify-integrity`.
if command -v mb >/dev/null 2>&1; then
    DOCTOR_OUT=$(mb doctor --check 2>&1 || true)
    RESULT_LINES=$(printf '%s\n' "$DOCTOR_OUT" | grep -cE '\[(OK|WARN|ERROR)\]' 2>/dev/null || true)
    RESULT_LINES=${RESULT_LINES:-0}
    if [ "$RESULT_LINES" -eq 0 ]; then
        echo -e "${YELLOW}[UNKNOWN] mb doctor produced no check results — memory bank NOT verified.${RESET}"
        echo "          The command ran but emitted no [OK]/[WARN]/[ERROR] lines."
        # WHY the fix names the clone, not just `mb upgrade`: upgrade copies templates FROM the
        # PMB clone behind `mb` (MB_HOME), so run from an outdated clone it reinstalls the old
        # hook — clearing this message by bringing back the silent re-baseline.
        echo "          One cause: an mb older than this hook, which rejects --check."
        echo "          Fix: update the PMB clone that MB_HOME points at, then run: mb upgrade"
        UNKNOWN=$((UNKNOWN + 1))
        echo ""
    else
        CHECK_MODE_SEEN=false
        printf '%s\n' "$DOCTOR_OUT" | grep -qF 'Integrity check mode:' && CHECK_MODE_SEEN=true
        if [ "$CHECK_MODE_SEEN" != true ]; then
            echo -e "${YELLOW}[UNKNOWN] mb doctor did not confirm check mode — integrity NOT verified.${RESET}"
            echo "          The mb on PATH predates 'doctor --check' and may have re-baselined .pmb-checksums."
            echo "          Fix: update the PMB clone that MB_HOME points at, then run: mb upgrade"
            UNKNOWN=$((UNKNOWN + 1))
            echo ""
        fi
        MISMATCH_LINES=$(printf '%s\n' "$DOCTOR_OUT" | grep -E '\[ERROR\].*hash mismatch' || true)
        OTHER_ERRORS=$(printf '%s\n' "$DOCTOR_OUT" | grep -E '\[ERROR\]' | grep -v 'hash mismatch' || true)
        if [ -n "$MISMATCH_LINES" ]; then
            MISMATCH_COUNT=$(printf '%s\n' "$MISMATCH_LINES" | grep -c . || true)
            echo -e "${YELLOW}[WARN] memory-bank changed since the last accepted integrity baseline: ${MISMATCH_COUNT} file(s)${RESET}"
            printf '%s\n' "$MISMATCH_LINES" | while IFS= read -r line; do echo "       $line"; done
            echo "       Review the changes, then accept them with: mb verify-integrity"
            WARNED=$((WARNED + 1))
            echo ""
        fi
        if [ -n "$OTHER_ERRORS" ]; then
            DOCTOR_ERRORS=$(printf '%s\n' "$OTHER_ERRORS" | grep -c . || true)
            echo -e "${YELLOW}[WARN] mb doctor reported ${DOCTOR_ERRORS} error(s) across ${RESULT_LINES} result lines:${RESET}"
            # `|| true` guards the pipeline: `head -5` closes the pipe once satisfied, and
            # under `set -o pipefail` printf's resulting SIGPIPE would abort the script before
            # the summary block ever runs — turning a warning into a verdict-less exit.
            { printf '%s\n' "$OTHER_ERRORS" | head -5 || true; } | while IFS= read -r line; do echo "       $line"; done
            WARNED=$((WARNED + 1))
            echo ""
        fi
        if printf '%s\n' "$DOCTOR_OUT" | grep -qF 'Integrity checksums: no baseline'; then
            # INFO, not a warning: a fresh clone or worktree has no baseline (.pmb-checksums is
            # gitignored) and --check never creates one, so counting it would warn — and with
            # ENFORCE, block — on every push until someone ran a command unrelated to the push.
            echo "[INFO] No memory-bank integrity baseline yet — run 'mb verify-integrity' to start tracking edits."
            echo ""
        fi
        if [ "$CHECK_MODE_SEEN" = true ] && [ -z "$MISMATCH_LINES" ] && [ -z "$OTHER_ERRORS" ]; then
            # "result lines", not "checks": this counts emitted [OK]/[WARN]/[ERROR] markers,
            # which exceeds the number of named doctor checks. Claiming a check count this
            # figure does not represent would repeat the unearned-assertion bug being fixed.
            echo -e "${GREEN}[OK]   mb doctor: ${RESULT_LINES} result lines, no errors${RESET}"
        fi
    fi
else
    echo -e "${YELLOW}[UNKNOWN] mb not in PATH — memory bank NOT verified.${RESET}"
    UNKNOWN=$((UNKNOWN + 1))
fi

echo ""
# WHY the summary distinguishes three states: "[PASS] All pre-push checks passed" may
# only print when every check actually passed. Previously it printed whenever no
# BLOCKING check failed, so it appeared directly beneath warnings it contradicted, and
# beneath a check that had not run at all. A summary that cannot express "warned" or
# "could not verify" will always overstate the result.
if [ "$FAILED" -ne 0 ]; then
    echo -e "${RED}[BLOCKED] Push aborted. Fix the errors above, then push again.${RESET}"
    echo ""
    exit 1
elif [ "$UNKNOWN" -ne 0 ]; then
    echo -e "${YELLOW}[DEGRADED] ${UNKNOWN} check(s) could not run; ${WARNED} warning(s). Not all checks were verified.${RESET}"
    if [ "$ENFORCE" = "true" ]; then
        echo -e "${RED}           ENFORCE=true — treating unverified checks as blocking.${RESET}"
        echo ""
        exit 1
    fi
    echo ""
    exit 0
elif [ "$WARNED" -ne 0 ]; then
    echo -e "${YELLOW}[PASS with ${WARNED} warning(s)] No blocking issues; review the warnings above.${RESET}"
    if [ "$ENFORCE" = "true" ]; then
        echo -e "${RED}           ENFORCE=true — treating warnings as blocking.${RESET}"
        echo ""
        exit 1
    fi
    echo ""
    exit 0
else
    echo -e "${GREEN}[PASS] All pre-push checks passed.${RESET}"
    echo ""
    exit 0
fi
