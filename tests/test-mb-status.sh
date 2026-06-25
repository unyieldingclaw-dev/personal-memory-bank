#!/usr/bin/env bash
# tests/test-mb-status.sh — tests for mb status (5 signals)
set -u

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
MB="$REPO_ROOT/scripts/mb.sh"
source "$REPO_ROOT/tests/helpers/assert.sh"
source "$REPO_ROOT/tests/setup.sh"

echo "=== mb status tests ==="

TMPDIR_STATUS="$(mktemp -d 2>/dev/null || mktemp -d -t mb-status-test)"
trap 'rm -rf "$TMPDIR_STATUS"' EXIT

setup_test_project "$TMPDIR_STATUS"

# ── Clean project (all signals pass, except Signal 5 empty) ────────────────
echo ""
echo "--- clean project ---"

output=$(cd "$TMPDIR_STATUS" && MB_HOME="$REPO_ROOT" bash "$MB" status 2>&1)
assert_exit_zero $? "mb status exits 0 on clean project"
assert_contains "$output" "Initialized" "mb status shows Initialized signal"
assert_contains "$output" "No Active Tasks" "mb status shows No Active Tasks when no contract exists"
# Signal 5 (no contract) adds an attention item, so we expect "1 Attention Item"
assert_contains "$output" "1 Attention Item" "mb status shows 1 Attention Item for missing task contract"

# ── Signal 1: Not initialized ────────────────────────────────────────────────
echo ""
echo "--- signal 1: not initialized ---"

rm -rf "$TMPDIR_STATUS/memory-bank"
output=$(cd "$TMPDIR_STATUS" && MB_HOME="$REPO_ROOT" bash "$MB" status 2>&1)
assert_contains "$output" "Initialized" "mb status shows Initialized signal when not initialized"
assert_contains "$output" "Attention" "mb status shows Attention section when not initialized"

# Restore memory-bank for subsequent tests
setup_test_project "$TMPDIR_STATUS"

# ── Signal 2: Missing required file ──────────────────────────────────────────
echo ""
echo "--- signal 2: missing required file ---"

rm "$TMPDIR_STATUS/memory-bank/activeContext.md"
output=$(cd "$TMPDIR_STATUS" && MB_HOME="$REPO_ROOT" bash "$MB" status 2>&1)
assert_contains "$output" "Core Memory" "mb status flags missing Core Memory"
assert_contains "$output" "Attention" "mb status shows Attention when file missing"

# Restore
printf -- "---\nauthority: stable\nlast-reviewed: %s\nstaleness-threshold: 90d\n---\n# activeContext\nTest content.\n" \
  "$(date +%Y-%m-%d)" > "$TMPDIR_STATUS/memory-bank/activeContext.md"

# ── Signal 3: Stale active context ───────────────────────────────────────────
echo ""
echo "--- signal 3: stale active context ---"

STALE_DATE=$(date -d "30 days ago" +%Y-%m-%d 2>/dev/null || date -v-30d +%Y-%m-%d 2>/dev/null || echo "2020-01-01")
sed -i.bak "s/last-reviewed: .*/last-reviewed: $STALE_DATE/" "$TMPDIR_STATUS/memory-bank/activeContext.md"
sed -i.bak "s/staleness-threshold: .*/staleness-threshold: 7d/" "$TMPDIR_STATUS/memory-bank/activeContext.md"
rm -f "$TMPDIR_STATUS/memory-bank/activeContext.md.bak"
output=$(cd "$TMPDIR_STATUS" && MB_HOME="$REPO_ROOT" bash "$MB" status 2>&1)
assert_contains "$output" "Active Context" "mb status flags stale Active Context"
assert_contains "$output" "Attention" "mb status shows Attention when context stale"

# Restore current date
sed -i.bak "s/last-reviewed: .*/last-reviewed: $(date +%Y-%m-%d)/" "$TMPDIR_STATUS/memory-bank/activeContext.md"
sed -i.bak "s/staleness-threshold: .*/staleness-threshold: 90d/" "$TMPDIR_STATUS/memory-bank/activeContext.md"
rm -f "$TMPDIR_STATUS/memory-bank/activeContext.md.bak"

# ── Signal 4: Missing standards ───────────────────────────────────────────────
echo ""
echo "--- signal 4: missing standards ---"

rm -rf "$TMPDIR_STATUS/standards"
output=$(cd "$TMPDIR_STATUS" && MB_HOME="$REPO_ROOT" bash "$MB" status 2>&1)
assert_contains "$output" "Standards" "mb status flags missing Standards"
assert_contains "$output" "Attention" "mb status shows Attention when standards missing"

# Restore
mkdir -p "$TMPDIR_STATUS/standards"
for s in WORKFLOW.md CODE-QUALITY.md SECURITY-GUARDRAILS.md CODE-REVIEW.md; do
  printf "# %s\n" "$s" > "$TMPDIR_STATUS/standards/$s"
done

# ── Signal 5: No active tasks (negative) ────────────────────────────────────
echo ""
echo "--- signal 5: no active tasks ---"

output=$(cd "$TMPDIR_STATUS" && MB_HOME="$REPO_ROOT" bash "$MB" status 2>&1)
assert_contains "$output" "No Active Tasks" "mb status shows No Active Tasks when .claude/contracts/ is empty"

# ── Signal 5: Tasks present (positive) ────────────────────────────────────────
echo ""
echo "--- signal 5: tasks present ---"

printf '{"task":"test","status":"active"}\n' > "$TMPDIR_STATUS/.claude/contracts/active-task.json"
output=$(cd "$TMPDIR_STATUS" && MB_HOME="$REPO_ROOT" bash "$MB" status 2>&1)
assert_contains "$output" "Tasks Present" "mb status shows Tasks Present when contract json exists"
# With all 5 signals passing (including task contract), expect "0 Issues"
assert_contains "$output" "0 Issues" "mb status shows 0 Issues when all 5 signals pass"

print_summary
