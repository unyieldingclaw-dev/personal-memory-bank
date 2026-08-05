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
run_suite "review-reminders"     "$REPO_ROOT/tests/test-review-reminders.sh"
run_suite "mb-version-notifier"  "$REPO_ROOT/tests/test-mb-version-notifier.sh"
run_suite "update-reviewed"      "$REPO_ROOT/tests/test-update-reviewed.sh"
run_suite "dangerous-commands"   "$REPO_ROOT/tests/test-dangerous-commands.sh"

echo ""
echo "════════════════════════════════════"
if [ "$OVERALL_FAIL" -eq 0 ]; then
  echo "All test suites passed."
else
  echo "One or more test suites had failures."
fi
echo "════════════════════════════════════"

exit "$OVERALL_FAIL"
