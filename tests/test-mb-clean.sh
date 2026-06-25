#!/usr/bin/env bash
# tests/test-mb-clean.sh — tests for mb clean
set -u

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
MB="$REPO_ROOT/scripts/mb.sh"
source "$REPO_ROOT/tests/helpers/assert.sh"
source "$REPO_ROOT/tests/setup.sh"

echo "=== mb clean tests ==="

TMPDIR_CLEAN="$(mktemp -d 2>/dev/null || mktemp -d -t mb-clean-test)"
trap 'rm -rf "$TMPDIR_CLEAN"' EXIT

setup_test_project "$TMPDIR_CLEAN"

# ── Normal run: shows maintenance guidance ────────────────────────────────────
echo ""
echo "--- normal run: maintenance guidance ---"

output=$(cd "$TMPDIR_CLEAN" && MB_HOME="$REPO_ROOT" bash "$MB" clean 2>&1)
assert_exit_zero $? "mb clean exits 0"
assert_contains "$output" "Maintenance" "mb clean shows Memory Bank Maintenance header"
assert_contains "$output" "Slim" "mb clean shows Slim Check section"

# ── Oversized progress.md: slim warning ───────────────────────────────────────
echo ""
echo "--- oversized progress.md: slim warning ---"

{
  echo "# Progress"
  for i in $(seq 1 401); do echo "Entry $i: progress note."; done
} > "$TMPDIR_CLEAN/memory-bank/progress.md"

output=$(cd "$TMPDIR_CLEAN" && MB_HOME="$REPO_ROOT" bash "$MB" clean 2>&1)
assert_exit_zero $? "mb clean exits 0 with oversized file"
assert_contains "$output" "slim" "mb clean mentions slim when progress.md is oversized"

print_summary
