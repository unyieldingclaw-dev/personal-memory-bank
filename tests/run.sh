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

run_suite "mb plan"         "$REPO_ROOT/tests/test-mb-plan.sh"
run_suite "mb preflight"    "$REPO_ROOT/tests/test-mb-preflight.sh"
run_suite "mb change-check" "$REPO_ROOT/tests/test-mb-change-check.sh"

echo ""
echo "════════════════════════════════════"
if [ "$OVERALL_FAIL" -eq 0 ]; then
  echo "All test suites passed."
else
  echo "One or more test suites had failures."
fi
echo "════════════════════════════════════"

exit "$OVERALL_FAIL"
