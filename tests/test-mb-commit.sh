#!/usr/bin/env bash
# tests/test-mb-commit.sh — tests for mb commit
set -u

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
MB="$REPO_ROOT/scripts/mb.sh"
source "$REPO_ROOT/tests/helpers/assert.sh"
source "$REPO_ROOT/tests/setup.sh"

echo "=== mb commit tests ==="

TMPDIR_COMMIT="$(mktemp -d 2>/dev/null || mktemp -d -t mb-commit-test)"
trap 'rm -rf "$TMPDIR_COMMIT"' EXIT

setup_test_project "$TMPDIR_COMMIT"

# ── No changes: graceful message ─────────────────────────────────────────────
echo ""
echo "--- no changes: nothing to commit ---"

output=$(cd "$TMPDIR_COMMIT" && MB_HOME="$REPO_ROOT" bash "$MB" commit 2>&1)
assert_exit_zero $? "mb commit exits 0 when nothing to commit"
assert_contains "$output" "No changes" "mb commit reports no changes when memory-bank is clean"

# ── Modified file: commit succeeds ───────────────────────────────────────────
echo ""
echo "--- modified file: commit succeeds ---"

echo "# New entry" >> "$TMPDIR_COMMIT/memory-bank/progress.md"

output=$(echo "y" | (cd "$TMPDIR_COMMIT" && MB_HOME="$REPO_ROOT" bash "$MB" commit 2>&1))
assert_exit_zero $? "mb commit exits 0 after confirming"
assert_contains "$output" "Committed" "mb commit reports Committed on success"

commit_count=$(cd "$TMPDIR_COMMIT" && git rev-list --count HEAD 2>&1)
assert_contains "$commit_count" "2" "git shows 2 commits after mb commit"

print_summary
