#!/usr/bin/env bash
# tests/test-mb-verify-integrity.sh — tests for mb verify-integrity
set -u

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
MB="$REPO_ROOT/scripts/mb.sh"
source "$REPO_ROOT/tests/helpers/assert.sh"
source "$REPO_ROOT/tests/setup.sh"

echo "=== mb verify-integrity tests ==="

TMPDIR_VI="$(mktemp -d 2>/dev/null || mktemp -d -t mb-vi-test)"
trap 'rm -rf "$TMPDIR_VI"' EXIT

setup_test_project "$TMPDIR_VI"

# ── First run: no baseline ───────────────────────────────────────────────────
echo ""
echo "--- first run: establishes baseline ---"

assert_file_not_exists "$TMPDIR_VI/.pmb-checksums" ".pmb-checksums absent before first run"

output=$(cd "$TMPDIR_VI" && MB_HOME="$REPO_ROOT" bash "$MB" verify-integrity 2>&1)
assert_exit_zero $? "mb verify-integrity exits 0 on first run"
assert_contains "$output" "baseline" "mb verify-integrity reports baseline established"
assert_file_exists "$TMPDIR_VI/.pmb-checksums" ".pmb-checksums created after first run"

# ── Second run: no changes ───────────────────────────────────────────────────
echo ""
echo "--- second run: checksums match ---"

output=$(cd "$TMPDIR_VI" && MB_HOME="$REPO_ROOT" bash "$MB" verify-integrity 2>&1)
assert_exit_zero $? "mb verify-integrity exits 0 when checksums match"
assert_contains "$output" "refreshed" "mb verify-integrity reports checksums refreshed"

# ── Third run: tampered file ──────────────────────────────────────────────────
echo ""
echo "--- third run: tampered file triggers mismatch ---"

echo "# external edit" >> "$TMPDIR_VI/memory-bank/activeContext.md"
output=$(cd "$TMPDIR_VI" && MB_HOME="$REPO_ROOT" bash "$MB" verify-integrity 2>&1)
assert_contains "$output" "mismatch" "mb verify-integrity warns on hash mismatch after external edit"

print_summary
