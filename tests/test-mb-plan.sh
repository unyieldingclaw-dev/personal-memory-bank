#!/usr/bin/env bash
# tests/test-mb-plan.sh — tests for mb plan status|list|promote|archive
# WHY: set -e is intentionally absent here so that commands expected to return
# non-zero exit codes (e.g. "mb plan promote" on a duplicate) don't abort the
# suite. We capture $? explicitly after each command instead.
set -u

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
MB="$REPO_ROOT/scripts/mb.sh"
# shellcheck source=tests/helpers/assert.sh
source "$REPO_ROOT/tests/helpers/assert.sh"
source "$REPO_ROOT/tests/setup.sh"

echo "=== mb plan tests ==="

# mktemp on Git Bash / Windows may need -d explicitly
TMPDIR_PLAN="$(mktemp -d 2>/dev/null || mktemp -d -t mb-plan-test)"
trap 'rm -rf "$TMPDIR_PLAN"' EXIT

setup_test_project "$TMPDIR_PLAN"

# ── mb plan status ──────────────────────────────────────────────────────────
echo ""
echo "--- mb plan status ---"

output=$(cd "$TMPDIR_PLAN" && MB_HOME="$REPO_ROOT" bash "$MB" plan status 2>&1)
assert_exit_zero $? "mb plan status exits 0"
assert_contains "$output" "Plan Status" "mb plan status shows header"
assert_contains "$output" "Drafts:" "mb plan status shows draft count"

# ── mb plan list (empty docs/plans/) ────────────────────────────────────────
echo ""
echo "--- mb plan list (empty) ---"

# Remove docs/plans so we can test the missing-dir path
rmdir "$TMPDIR_PLAN/docs/plans"

output=$(cd "$TMPDIR_PLAN" && MB_HOME="$REPO_ROOT" bash "$MB" plan list 2>&1)
assert_exit_zero $? "mb plan list exits 0 when docs/plans/ is absent"
assert_contains "$output" "plans" "mb plan list mentions plans"

# Recreate for subsequent tests
mkdir -p "$TMPDIR_PLAN/docs/plans"

# ── mb plan promote ──────────────────────────────────────────────────────────
echo ""
echo "--- mb plan promote ---"

mkdir -p "$TMPDIR_PLAN/.claude/plans"
cat > "$TMPDIR_PLAN/.claude/plans/2099-01-01-test.md" << 'EOF'
# Test Plan
This is a test draft.
EOF

output=$(cd "$TMPDIR_PLAN" && MB_HOME="$REPO_ROOT" bash "$MB" plan promote ".claude/plans/2099-01-01-test.md" 2>&1)
assert_exit_zero $? "mb plan promote exits 0"
# mb.sh prints "Added frontmatter and promoted to $DEST" or "Promoted to $DEST"
assert_contains "$output" "promoted" "mb plan promote reports success"
assert_file_exists "$TMPDIR_PLAN/docs/plans/2099-01-01-test.md" "promoted file appears in docs/plans/"

# Promoted file should have status: frontmatter injected
status_count=$(grep -c '^status:' "$TMPDIR_PLAN/docs/plans/2099-01-01-test.md" 2>/dev/null || echo 0)
assert_contains "$status_count" "1" "promoted file has status: frontmatter"

# ── mb plan promote (duplicate) ──────────────────────────────────────────────
echo ""
echo "--- mb plan promote (duplicate blocked) ---"

# Recreate the source draft (promote does not delete the source)
cat > "$TMPDIR_PLAN/.claude/plans/2099-01-01-test.md" << 'EOF'
# Test Plan Again
EOF
output=$(cd "$TMPDIR_PLAN" && MB_HOME="$REPO_ROOT" bash "$MB" plan promote ".claude/plans/2099-01-01-test.md" 2>&1)
assert_exit_nonzero $? "mb plan promote refuses to overwrite existing plan"

# ── mb plan list (with plan) ─────────────────────────────────────────────────
echo ""
echo "--- mb plan list (with plan) ---"

output=$(cd "$TMPDIR_PLAN" && MB_HOME="$REPO_ROOT" bash "$MB" plan list 2>&1)
assert_exit_zero $? "mb plan list exits 0 with plans present"
assert_contains "$output" "2099-01-01-test" "mb plan list shows promoted plan"

# ── mb plan archive ──────────────────────────────────────────────────────────
echo ""
echo "--- mb plan archive ---"

# Update status to done so archive accepts it
sed -i.bak 's/^status: planned/status: done/' "$TMPDIR_PLAN/docs/plans/2099-01-01-test.md"
rm -f "$TMPDIR_PLAN/docs/plans/2099-01-01-test.md.bak"

# git add so that git mv works (file must be tracked)
(cd "$TMPDIR_PLAN" && git add "docs/plans/2099-01-01-test.md" && git commit -q -m "add plan")

output=$(cd "$TMPDIR_PLAN" && MB_HOME="$REPO_ROOT" bash "$MB" plan archive "docs/plans/2099-01-01-test.md" 2>&1)
assert_exit_zero $? "mb plan archive exits 0"
assert_contains "$output" "Archived" "mb plan archive reports success"
assert_file_exists "$TMPDIR_PLAN/docs/archive/plans/2099-01-01-test.md" "archived file in docs/archive/plans/"
assert_file_not_exists "$TMPDIR_PLAN/docs/plans/2099-01-01-test.md" "original removed from docs/plans/"

# ── mb plan archive (wrong status) ───────────────────────────────────────────
echo ""
echo "--- mb plan archive (wrong status blocked) ---"

cat > "$TMPDIR_PLAN/docs/plans/2099-active.md" << 'EOF'
---
status: active
---
# Active plan
EOF
output=$(cd "$TMPDIR_PLAN" && MB_HOME="$REPO_ROOT" bash "$MB" plan archive "docs/plans/2099-active.md" 2>&1)
assert_exit_nonzero $? "mb plan archive refuses to archive active plan"

print_summary
