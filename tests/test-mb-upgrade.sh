#!/usr/bin/env bash
# tests/test-mb-upgrade.sh — tests for mb upgrade
set -u

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
MB="$REPO_ROOT/scripts/mb.sh"
source "$REPO_ROOT/tests/helpers/assert.sh"
source "$REPO_ROOT/tests/setup.sh"

echo "=== mb upgrade tests ==="

TMPDIR_UP="$(mktemp -d 2>/dev/null || mktemp -d -t mb-upgrade-test)"
trap 'rm -rf "$TMPDIR_UP"' EXIT

setup_test_project "$TMPDIR_UP"

# ── Template sync: deleted TEMPLATE_OWNED file is restored ───────────────────
echo ""
echo "--- template sync: restores TEMPLATE_OWNED file ---"

mkdir -p "$TMPDIR_UP/scripts"
rm -f "$TMPDIR_UP/scripts/dangerous-commands.sh"
assert_file_not_exists "$TMPDIR_UP/scripts/dangerous-commands.sh" "file absent before upgrade"

output=$(cd "$TMPDIR_UP" && MB_HOME="$REPO_ROOT" bash "$MB" upgrade 2>&1)
assert_exit_zero $? "mb upgrade exits 0"
assert_file_exists "$TMPDIR_UP/scripts/dangerous-commands.sh" "upgrade restores TEMPLATE_OWNED script"

# ── Version tracking: .pmb-version updated ───────────────────────────────────
echo ""
echo "--- version tracking: .pmb-version matches repo VERSION ---"

output=$(cd "$TMPDIR_UP" && MB_HOME="$REPO_ROOT" bash "$MB" upgrade 2>&1)
assert_exit_zero $? "mb upgrade exits 0 on second run"
assert_contains "$output" ".pmb-version" "mb upgrade reports .pmb-version update"

EXPECTED_VER=$(tr -d '[:space:]' < "$REPO_ROOT/VERSION")
ACTUAL_VER=$(tr -d '[:space:]' < "$TMPDIR_UP/.pmb-version" 2>/dev/null || echo "missing")
assert_contains "$ACTUAL_VER" "$EXPECTED_VER" ".pmb-version matches repo VERSION after upgrade"

# ── Missing standard: ADVISORY_CREATE restores it ────────────────────────────
echo ""
echo "--- missing standard: upgrade creates it ---"

rm -f "$TMPDIR_UP/standards/WORKFLOW.md"
assert_file_not_exists "$TMPDIR_UP/standards/WORKFLOW.md" "WORKFLOW.md absent before upgrade"

output=$(cd "$TMPDIR_UP" && MB_HOME="$REPO_ROOT" bash "$MB" upgrade 2>&1)
assert_exit_zero $? "mb upgrade exits 0 with missing standard"
assert_file_exists "$TMPDIR_UP/standards/WORKFLOW.md" "upgrade restores missing WORKFLOW.md"

# ── Missing doc: ADVISORY_CREATE restores it ─────────────────────────────────
echo ""
echo "--- missing doc: upgrade creates it ---"

rm -f "$TMPDIR_UP/docs/HOOKS-GUIDE.md"
assert_file_not_exists "$TMPDIR_UP/docs/HOOKS-GUIDE.md" "docs/HOOKS-GUIDE.md absent before upgrade"

output=$(cd "$TMPDIR_UP" && MB_HOME="$REPO_ROOT" bash "$MB" upgrade 2>&1)
assert_exit_zero $? "mb upgrade exits 0 with missing doc"
assert_file_exists "$TMPDIR_UP/docs/HOOKS-GUIDE.md" "upgrade restores missing docs/HOOKS-GUIDE.md"

print_summary
