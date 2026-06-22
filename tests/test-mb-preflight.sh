#!/usr/bin/env bash
# tests/test-mb-preflight.sh — tests for mb preflight
set -e

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
MB="$REPO_ROOT/scripts/mb.sh"
# shellcheck source=tests/helpers/assert.sh
source "$REPO_ROOT/tests/helpers/assert.sh"
source "$REPO_ROOT/tests/setup.sh"

echo "=== mb preflight tests ==="

TMPDIR_PRE="$(mktemp -d 2>/dev/null || mktemp -d -t mb-preflight-test)"
trap 'rm -rf "$TMPDIR_PRE"' EXIT

setup_test_project "$TMPDIR_PRE"

# ── mb preflight (basic) ─────────────────────────────────────────────────────
echo ""
echo "--- mb preflight (basic) ---"

output=$(cd "$TMPDIR_PRE" && MB_HOME="$REPO_ROOT" bash "$MB" preflight 2>&1)
assert_exit_zero $? "mb preflight exits 0"
# mb.sh always prints the Preflight header and checks git
assert_contains "$output" "Preflight" "mb preflight shows header"
assert_contains "$output" "git" "mb preflight reports git status"

# ── mb preflight --staged (flag is ignored; command still runs cleanly) ──────
echo ""
echo "--- mb preflight --staged ---"

output=$(cd "$TMPDIR_PRE" && MB_HOME="$REPO_ROOT" bash "$MB" preflight --staged 2>&1)
assert_exit_zero $? "mb preflight --staged exits 0"
assert_contains "$output" "Preflight" "mb preflight --staged shows header"

# ── mb preflight --json (flag is ignored; command still runs cleanly) ─────────
echo ""
echo "--- mb preflight --json ---"

output=$(cd "$TMPDIR_PRE" && MB_HOME="$REPO_ROOT" bash "$MB" preflight --json 2>&1)
assert_exit_zero $? "mb preflight --json exits 0"
assert_contains "$output" "Preflight" "mb preflight --json shows header"

# ── unknown flag does not crash ────────────────────────────────────────────────
echo ""
echo "--- mb preflight unknown flag ---"

output=$(cd "$TMPDIR_PRE" && MB_HOME="$REPO_ROOT" bash "$MB" preflight --invalid-flag 2>&1)
# show_preflight ignores unrecognised flags; exit code should still be 0
assert_exit_zero $? "mb preflight with unknown flag does not crash"

print_summary
