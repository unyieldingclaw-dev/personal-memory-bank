#!/usr/bin/env bash
# tests/test-mb-change-check.sh — tests for mb change-check
set -e

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
MB="$REPO_ROOT/scripts/mb.sh"
# shellcheck source=tests/helpers/assert.sh
source "$REPO_ROOT/tests/helpers/assert.sh"
source "$REPO_ROOT/tests/setup.sh"

echo "=== mb change-check tests ==="

TMPDIR_CC="$(mktemp -d 2>/dev/null || mktemp -d -t mb-cc-test)"
trap 'rm -rf "$TMPDIR_CC"' EXIT

setup_test_project "$TMPDIR_CC"

# ── mb change-check (default) ────────────────────────────────────────────────
# The test repo has no remote, so change-check falls through to HEAD~1.
# A single-commit repo has no HEAD~1, so git diff returns nothing and
# show_change_check prints "No diff found… Nothing to check." and returns 0.
# The "Change Check" header is always printed first.
echo ""
echo "--- mb change-check (default) ---"

output=$(cd "$TMPDIR_CC" && MB_HOME="$REPO_ROOT" bash "$MB" change-check 2>&1)
assert_exit_zero $? "mb change-check exits 0"
assert_contains "$output" "Change Check" "mb change-check shows header"

# ── mb change-check with a real diff ─────────────────────────────────────────
# Add a second commit so HEAD~1 exists and produces a non-empty diff.
echo ""
echo "--- mb change-check (with diff) ---"

echo "new content" > "$TMPDIR_CC/memory-bank/activeContext.md"
(cd "$TMPDIR_CC" && git add "memory-bank/activeContext.md" && git commit -q -m "update")

output=$(cd "$TMPDIR_CC" && MB_HOME="$REPO_ROOT" bash "$MB" change-check 2>&1)
assert_exit_zero $? "mb change-check with diff exits 0"
assert_contains "$output" "Change Check" "mb change-check with diff shows header"
assert_contains "$output" "Files:" "mb change-check reports file count"
assert_contains "$output" "Base:" "mb change-check reports base ref"

# ── mb change-check explicit base ref ────────────────────────────────────────
echo ""
echo "--- mb change-check explicit base (HEAD~1) ---"

output=$(cd "$TMPDIR_CC" && MB_HOME="$REPO_ROOT" bash "$MB" change-check HEAD~1 2>&1)
assert_exit_zero $? "mb change-check HEAD~1 exits 0"
assert_contains "$output" "Change Check" "mb change-check HEAD~1 shows header"

print_summary
