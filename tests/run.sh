#!/usr/bin/env bash
# tests/run.sh — run all mb command tests
# Usage: bash tests/run.sh
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

OVERALL_FAIL=0

run_suite() {
  local name="$1" script="$2"
  echo ""
  echo "════════════════════════════════════"
  echo "Suite: $name"
  echo "════════════════════════════════════"

  if ! bash "$script"; then
    OVERALL_FAIL=1
  fi
}

run_suite "mb plan"              "$REPO_ROOT/tests/test-mb-plan.sh"
run_suite "mb preflight"         "$REPO_ROOT/tests/test-mb-preflight.sh"
run_suite "mb change-check"      "$REPO_ROOT/tests/test-mb-change-check.sh"
run_suite "mb status"            "$REPO_ROOT/tests/test-mb-status.sh"
run_suite "mb verify-integrity"  "$REPO_ROOT/tests/test-mb-verify-integrity.sh"
run_suite "mb query"             "$REPO_ROOT/tests/test-mb-query.sh"
run_suite "mb init"              "$REPO_ROOT/tests/test-mb-init.sh"
run_suite "mb clean"             "$REPO_ROOT/tests/test-mb-clean.sh"
run_suite "mb commit"            "$REPO_ROOT/tests/test-mb-commit.sh"
run_suite "mb upgrade"           "$REPO_ROOT/tests/test-mb-upgrade.sh"
run_suite "mb doctor"            "$REPO_ROOT/tests/test-mb-doctor.sh"
run_suite "review-gate-lib-presence" "$REPO_ROOT/tests/test-review-gate-lib-presence.sh"
run_suite "review-gate-lib"          "$REPO_ROOT/tests/test-review-gate-lib.sh"
run_suite "review-reminders"     "$REPO_ROOT/tests/test-review-reminders.sh"
run_suite "mb-version-notifier"  "$REPO_ROOT/tests/test-mb-version-notifier.sh"
run_suite "update-reviewed"      "$REPO_ROOT/tests/test-update-reviewed.sh"
run_suite "dangerous-commands"   "$REPO_ROOT/tests/test-dangerous-commands.sh"
run_suite "mb-backlog"           "$REPO_ROOT/tests/test-mb-backlog.sh"
run_suite "pre-push-check"       "$REPO_ROOT/tests/test-pre-push-check.sh"
run_suite "threshold-parity"     "$REPO_ROOT/tests/test-threshold-parity.sh"
run_suite "pre-compact-check"    "$REPO_ROOT/tests/test-pre-compact-check.sh"
run_suite "mirror-parity"        "$REPO_ROOT/tests/test-mirror-parity.sh"
run_suite "baseline-health"     "$REPO_ROOT/tests/test-baseline-health.sh"

# ── completeness: every tracked test suite must be registered above ──────────────────
# WHY: the list above is hand-maintained, which is the THIRD instance of the stale-hardcoded
# list bug in this repo -- after the slash-command list in 1.2.0 and the agent list in
# ADVISORY_DIFF (both fixed by auto-discovery). Here it is worse than elsewhere, because a
# suite that is never invoked reports nothing at all: the runner prints "All test suites
# passed" while silently skipping it. Found 2026-08-27, when a newly added suite was not
# picked up.
#
# WHY git ls-files rather than a glob: tests/ also holds untracked work-in-progress suites
# (e.g. a withdrawn hook-wiring test), and a glob would fail the run on files that were
# deliberately never committed. Tracked-and-unregistered is the case that actually matters,
# since that is what reaches CI.
# WHY the pattern is anchored to a run_suite line rather than a bare basename grep: a basename
# search matches the file being NAMED anywhere in this script -- including inside a comment or a
# TODO -- so a tracked suite mentioned in prose but never wired up reads as registered and still
# never runs. Verified by reproduction 2026-08-27: a tracked tests/test-ghost.sh referenced only
# in a comment was reported as registered. Anchoring to "^run_suite ... /tests/<name>\"" requires
# an actual invocation; comments begin with # and cannot match. Dots in the basename are escaped
# so they are literal rather than regex any-char.
UNREGISTERED=""
if command -v git >/dev/null 2>&1 && git -C "$REPO_ROOT" rev-parse --git-dir >/dev/null 2>&1; then
  for f in $(git -C "$REPO_ROOT" ls-files 'tests/test-*.sh'); do
    base_esc=$(basename "$f" | sed 's/\./\\./g')
    grep -qE "^run_suite .*/tests/${base_esc}\"" "$REPO_ROOT/tests/run.sh"       || UNREGISTERED="$UNREGISTERED $f"
  done
else
  # WHY loud rather than silent: a completeness check that quietly evaporates outside a git
  # checkout is the same "silent skip reads as a pass" shape this repo has been bitten by before.
  echo ""
  echo "SKIP: suite-registration completeness check (no git available) -- suites themselves still ran."
fi
if [ -n "$UNREGISTERED" ]; then
  echo ""
  echo "FAIL: tracked test suite(s) not registered in tests/run.sh — they never ran:"
  for f in $UNREGISTERED; do echo "        $f"; done
  OVERALL_FAIL=1
fi

echo ""
echo "════════════════════════════════════"
if [ "$OVERALL_FAIL" -eq 0 ]; then
  echo "All test suites passed."
else
  echo "One or more test suites had failures."
fi
echo "════════════════════════════════════"

exit "$OVERALL_FAIL"
