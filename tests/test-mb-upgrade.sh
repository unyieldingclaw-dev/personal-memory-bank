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

# ── Template sync: review-reminders scripts are TEMPLATE_OWNED too ───────────
# Regression test: templates/.claude/settings.json invokes review-reminders.sh/.ps1 and
# review-reminders-post.sh/.ps1 directly, but they were missing from TEMPLATE_OWNED, so a
# deleted or stale copy was never restored by mb upgrade.
echo ""
echo "--- template sync: restores review-reminders TEMPLATE_OWNED scripts ---"

rm -f "$TMPDIR_UP/scripts/review-reminders.sh" "$TMPDIR_UP/scripts/review-reminders-post.sh"
assert_file_not_exists "$TMPDIR_UP/scripts/review-reminders.sh" "review-reminders.sh absent before upgrade"

output=$(cd "$TMPDIR_UP" && MB_HOME="$REPO_ROOT" bash "$MB" upgrade 2>&1)
assert_exit_zero $? "mb upgrade exits 0"
assert_file_exists "$TMPDIR_UP/scripts/review-reminders.sh" "upgrade restores TEMPLATE_OWNED review-reminders.sh"
assert_file_exists "$TMPDIR_UP/scripts/review-reminders-post.sh" "upgrade restores TEMPLATE_OWNED review-reminders-post.sh"

# ── Template sync: _review-gate-lib.sh/.ps1 are TEMPLATE_OWNED too ───────────
echo ""
echo "--- template sync: restores _review-gate-lib TEMPLATE_OWNED scripts ---"

rm -f "$TMPDIR_UP/scripts/_review-gate-lib.sh" "$TMPDIR_UP/scripts/_review-gate-lib.ps1"
assert_file_not_exists "$TMPDIR_UP/scripts/_review-gate-lib.sh" "_review-gate-lib.sh absent before upgrade"

output=$(cd "$TMPDIR_UP" && MB_HOME="$REPO_ROOT" bash "$MB" upgrade 2>&1)
assert_exit_zero $? "mb upgrade exits 0"
assert_file_exists "$TMPDIR_UP/scripts/_review-gate-lib.sh" "upgrade restores TEMPLATE_OWNED _review-gate-lib.sh"
assert_file_exists "$TMPDIR_UP/scripts/_review-gate-lib.ps1" "upgrade restores TEMPLATE_OWNED _review-gate-lib.ps1"

# ── Template sync: ALL command files are auto-discovered, not a hardcoded subset ─
# Regression test: TEMPLATE_OWNED used to hardcode 4 of 8 command files
# (code-review.md, feature-dev.md, security-review.md, pmb-status.md), so
# accessibility-review.md, change-review.md, health-check.md, and test-audit.md
# were silently never restored by `mb upgrade` even though `mb init` already
# discovered them correctly. Fixed to auto-discover from templates/claude-commands/
# instead, matching mb.ps1's Invoke-Upgrade.
echo ""
echo "--- template sync: restores ALL command files, not just the previously-hardcoded 4 ---"

rm -f "$TMPDIR_UP/.claude/commands/accessibility-review.md" \
      "$TMPDIR_UP/.claude/commands/change-review.md" \
      "$TMPDIR_UP/.claude/commands/health-check.md" \
      "$TMPDIR_UP/.claude/commands/test-audit.md"
assert_file_not_exists "$TMPDIR_UP/.claude/commands/change-review.md" "change-review.md absent before upgrade"

output=$(cd "$TMPDIR_UP" && MB_HOME="$REPO_ROOT" bash "$MB" upgrade 2>&1)
assert_exit_zero $? "mb upgrade exits 0"
assert_file_exists "$TMPDIR_UP/.claude/commands/accessibility-review.md" "upgrade restores accessibility-review.md"
assert_file_exists "$TMPDIR_UP/.claude/commands/change-review.md" "upgrade restores change-review.md"
assert_file_exists "$TMPDIR_UP/.claude/commands/health-check.md" "upgrade restores health-check.md"
assert_file_exists "$TMPDIR_UP/.claude/commands/test-audit.md" "upgrade restores test-audit.md"

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
