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
# WHY this no longer calls `mb validate`: that command was deprecated into `mb doctor`
# and now resolves to a shim that prints a redirect notice and exits 0. The old check
# tested only the exit code, so it printed "[OK] mb validate passed" on every push in
# every managed project while validating nothing. An exit code cannot distinguish
# "ran and passed" from "did nothing" — that is the general trap, and every deprecated
# alias that echoes and returns 0 has the same property.
#
# WHY the verdict is parsed from output rather than taken from an exit code: `mb doctor`
# also exits 0 regardless of what it finds, so switching commands alone would have
# preserved the bug. Its output is structured — every check emits [OK], [WARN] or
# [ERROR] — so counting those lines yields both the verdict AND a positive assertion
# that the command actually ran. Zero result lines means no checks executed (deprecated
# shim, crash, missing binary), which is UNKNOWN, never success. Measured: a real run
# emits ~51 result lines; the shim emits 0.
if command -v mb >/dev/null 2>&1; then
    DOCTOR_OUT=$(mb doctor 2>&1 || true)
    RESULT_LINES=$(printf '%s\n' "$DOCTOR_OUT" | grep -cE '\[(OK|WARN|ERROR)\]' 2>/dev/null || true)
    RESULT_LINES=${RESULT_LINES:-0}
    if [ "$RESULT_LINES" -eq 0 ]; then
        echo -e "${YELLOW}[UNKNOWN] mb doctor produced no check results — memory bank NOT verified.${RESET}"
        echo "          The command ran but emitted no [OK]/[WARN]/[ERROR] lines."
        UNKNOWN=$((UNKNOWN + 1))
        echo ""
    else
        DOCTOR_ERRORS=$(printf '%s\n' "$DOCTOR_OUT" | grep -cE '\[ERROR\]' 2>/dev/null || true)
        DOCTOR_ERRORS=${DOCTOR_ERRORS:-0}
        if [ "$DOCTOR_ERRORS" -gt 0 ]; then
            echo -e "${YELLOW}[WARN] mb doctor reported ${DOCTOR_ERRORS} error(s) across ${RESULT_LINES} result lines:${RESET}"
            # `|| true` guards the pipeline: `head -5` closes the pipe once satisfied, and
            # under `set -o pipefail` grep's resulting SIGPIPE would abort the script before
            # the summary block ever runs — turning a warning into a verdict-less exit.
            { printf '%s\n' "$DOCTOR_OUT" | grep -E '\[ERROR\]' | head -5 || true; } | while IFS= read -r line; do echo "       $line"; done
            WARNED=$((WARNED + 1))
            echo ""
        else
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
