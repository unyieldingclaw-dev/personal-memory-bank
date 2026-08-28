#!/usr/bin/env bash
# tests/test-pre-compact-check.sh — tests for the PreCompact memory-bank freshness gate
#
# WHY this file exists at all: until 2026-08-27 this hook had NO test coverage in either shell,
# despite gating every context compaction. That absence is how [NS-22] survived — the bypass was a
# bare `[ -f handoff.md ]` existence check with no staleness test, so a handoff left in the repo
# root from a previous day silently disabled the whole gate. A single test asserting "a stale
# handoff does not bypass" would have caught it the day it was written.
#
# The discriminating case is "stale handoff + thin memory bank must BLOCK". Tests that only check
# the happy path would pass against the broken version too.
set -u

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
HOOK="$REPO_ROOT/scripts/pre-compact-check.sh"
source "$REPO_ROOT/tests/helpers/assert.sh"

echo "=== pre-compact-check tests ==="

TMPDIR_PC="$(mktemp -d 2>/dev/null || mktemp -d -t mb-precompact-test)"
trap 'rm -rf "$TMPDIR_PC"' EXIT

TODAY="$(date +%Y-%m-%d)"

# Builds a memory bank in $1. Pass "fresh" for one that satisfies both checks, "thin" for one
# that fails both (no substantive activeContext lines, no dated progress entry).
make_bank() {
    local dir="$1" kind="$2"
    mkdir -p "$dir/memory-bank"
    if [ "$kind" = "fresh" ]; then
        {
            echo "# Active Context"
            echo "This is a substantive line of session state that is comfortably over twenty characters."
            echo "This is a second substantive line of session state, also well over the threshold length."
            echo "This is a third substantive line of session state, likewise over the threshold length."
        } > "$dir/memory-bank/activeContext.md"
        printf '# Progress\n\n## %s — did some work\n\n- an entry\n' "$TODAY" > "$dir/memory-bank/progress.md"
    else
        printf '# Active Context\n' > "$dir/memory-bank/activeContext.md"
        printf '# Progress\n\n## 2020-01-01 — ancient\n' > "$dir/memory-bank/progress.md"
    fi
}

run_hook() { ( cd "$1" && bash "$HOOK" 2>&1 ); }
hook_code() { ( cd "$1" && bash "$HOOK" >/dev/null 2>&1; echo $? ); }

# ── baseline: no handoff, fresh bank → allow ───────────────────────────────────────────────
echo ""
echo "--- no handoff, fresh memory bank: allows compaction ---"
D="$TMPDIR_PC/fresh"; make_bank "$D" fresh
assert_contains "code=$(hook_code "$D")" "code=0" "fresh memory bank with no handoff exits 0 (allow)"

# ── baseline: no handoff, thin bank → block ────────────────────────────────────────────────
echo ""
echo "--- no handoff, thin memory bank: blocks compaction ---"
D="$TMPDIR_PC/thin"; make_bank "$D" thin
assert_contains "code=$(hook_code "$D")" "code=2" "thin memory bank with no handoff exits 2 (block)"
out="$(run_hook "$D")"
assert_contains "$out" "substantive line" "block message names the activeContext.md failure"
assert_contains "$out" "no entry dated" "block message names the progress.md failure"

# ── the bypass still works when it is legitimate ───────────────────────────────────────────
echo ""
echo "--- handoff dated TODAY: bypasses even a thin memory bank ---"
D="$TMPDIR_PC/handoff-today"; make_bank "$D" thin
printf '# Handoff\n\nin-flight state\n' > "$D/handoff.md"
assert_contains "code=$(hook_code "$D")" "code=0" "a handoff dated today still bypasses the gate (allow)"

# ── [NS-22] the regression this file exists for ────────────────────────────────────────────
# WHY backdate rather than mock: the defect was that mtime was never consulted at all, so the test
# has to exercise a real filesystem timestamp. Two days avoids any midnight-boundary flake.
echo ""
echo "--- [NS-22] handoff dated in the PAST: must NOT bypass a thin memory bank ---"
D="$TMPDIR_PC/handoff-stale"; make_bank "$D" thin
printf '# Handoff\n\nspent state from a previous session\n' > "$D/handoff.md"
touch -d "2 days ago" "$D/handoff.md" 2>/dev/null || touch -t "$(date -d '2 days ago' +%Y%m%d%H%M 2>/dev/null || echo 202001010000)" "$D/handoff.md"
assert_contains "code=$(hook_code "$D")" "code=2" "[NS-22] a stale handoff does NOT bypass the gate (block)"
out="$(run_hook "$D")"
assert_contains "$out" "not today" "stale-handoff message says the handoff is not from today"
assert_contains "$out" "Handoff Protocol step 5" "stale-handoff message points at the delete-after-merge step"

# ── a stale handoff must not HARD-block: it only removes the free pass ─────────────────────
# WHY assert this too: the fix must degrade to "run the ordinary checks", not to "deny". Without
# this case a fix that simply blocked on any stale handoff would look correct.
echo ""
echo "--- handoff stale but memory bank FRESH: allowed, because the real checks pass ---"
D="$TMPDIR_PC/handoff-stale-fresh"; make_bank "$D" fresh
printf '# Handoff\n\nspent state\n' > "$D/handoff.md"
touch -d "2 days ago" "$D/handoff.md" 2>/dev/null || touch -t "$(date -d '2 days ago' +%Y%m%d%H%M 2>/dev/null || echo 202001010000)" "$D/handoff.md"
assert_contains "code=$(hook_code "$D")" "code=0" "a stale handoff removes the bypass but does not hard-block a fresh bank"

# ── sh/ps1 parity ──────────────────────────────────────────────────────────────────────────
# WHY: every assertion above runs the .sh hook only, but Claude Code invokes the .ps1 twin first
# on any machine where pwsh is present -- so the bypass could be correct in the shell under test
# and wrong in the shell that actually runs. Not hypothetical: the immediately preceding commit
# fixed exactly a sh/ps1 divergence ([NS-37]), and this fix's own record claims ps1 parity across
# all five cases on the strength of a MANUAL check, with nothing holding it.
#
# WHY skipped rather than failed when pwsh is missing: CI runs on Linux where pwsh is not
# guaranteed. The skip is loud so it is not mistaken for a pass; PMB_REQUIRE_PARITY=1 makes it fatal.
HOOK_PS1="$REPO_ROOT/scripts/pre-compact-check.ps1"
if command -v pwsh >/dev/null 2>&1; then
    echo ""
    echo "--- sh/ps1 parity: the .ps1 twin must agree on all five cases ---"
    ps1_code() { ( cd "$1" && pwsh -NoProfile -NonInteractive -File "$HOOK_PS1" >/dev/null 2>&1; echo $? ); }

    assert_contains "code=$(ps1_code "$TMPDIR_PC/fresh")"              "code=0" "ps1: fresh bank, no handoff (allow)"
    assert_contains "code=$(ps1_code "$TMPDIR_PC/thin")"               "code=2" "ps1: thin bank, no handoff (block)"
    assert_contains "code=$(ps1_code "$TMPDIR_PC/handoff-today")"      "code=0" "ps1: handoff dated today bypasses (allow)"
    assert_contains "code=$(ps1_code "$TMPDIR_PC/handoff-stale")"      "code=2" "ps1: [NS-22] stale handoff does NOT bypass (block)"
    assert_contains "code=$(ps1_code "$TMPDIR_PC/handoff-stale-fresh")" "code=0" "ps1: stale handoff does not hard-block a fresh bank"
else
    echo ""
    echo "--- sh/ps1 parity: SKIPPED (pwsh not on PATH) ---"
    echo "!!! WARNING: cross-shell parity assertions did NOT run. A sh/ps1 divergence cannot be"
    echo "!!! detected by this run. Set PMB_REQUIRE_PARITY=1 to make this a failure."
    if [ "${PMB_REQUIRE_PARITY:-0}" = "1" ]; then
        assert_contains "pwsh-missing" "pwsh-present" "PMB_REQUIRE_PARITY=1 but pwsh is not on PATH -- parity block could not run"
    fi
fi

# ── mirror parity: scripts/ and templates/scripts/ must not drift ───────────────────────────
# WHY: templates/ is what `mb upgrade` ships to adopters, so a fix landing in scripts/ alone is
# invisible here and broken there. This repo has already shipped that exact mistake once with
# dangerous-commands, and templates/scripts/pre-compact-check.sh has itself fallen behind before
# (7de75e6, syncing a bash optimization it missed). A byte comparison is the cheapest guard.
echo ""
echo "--- mirror parity: scripts/ vs templates/scripts/ ---"
diff -q "$REPO_ROOT/scripts/pre-compact-check.sh" "$REPO_ROOT/templates/scripts/pre-compact-check.sh" >/dev/null 2>&1
assert_exit_zero "$?" "scripts/pre-compact-check.sh and its templates/ mirror are byte-identical"
diff -q "$REPO_ROOT/scripts/pre-compact-check.ps1" "$REPO_ROOT/templates/scripts/pre-compact-check.ps1" >/dev/null 2>&1
assert_exit_zero "$?" "scripts/pre-compact-check.ps1 and its templates/ mirror are byte-identical"

print_summary
