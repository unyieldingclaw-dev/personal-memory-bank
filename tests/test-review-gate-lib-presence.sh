#!/usr/bin/env bash
# tests/test-review-gate-lib-presence.sh — unit tests for
# scripts/check-review-gate-lib-presence.sh, the hardcoded (not settings.json-derived)
# lib-existence check shared by mb doctor and the CI template-integrity job.
set -u

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CHECKER="$REPO_ROOT/scripts/check-review-gate-lib-presence.sh"
source "$REPO_ROOT/tests/helpers/assert.sh"

echo "=== check-review-gate-lib-presence.sh unit tests ==="

TMPDIR_CHK="$(mktemp -d 2>/dev/null || mktemp -d -t mb-libcheck-test)"
trap 'rm -rf "$TMPDIR_CHK"' EXIT

# ── Clean: both hooks + both libs present → exit 0, no output ───────────────
echo ""
echo "--- clean: hooks and libs both present → PASS, no output ---"
touch "$TMPDIR_CHK/review-reminders.sh" "$TMPDIR_CHK/review-reminders.ps1"
touch "$TMPDIR_CHK/_review-gate-lib.sh" "$TMPDIR_CHK/_review-gate-lib.ps1"
out=$(bash "$CHECKER" "$TMPDIR_CHK"); rc=$?
assert_exit_zero $rc "clean dir: checker exits 0"
if [ -z "$out" ]; then
  echo "  PASS: clean dir produces no output"
  PASS=$((PASS + 1))
else
  echo "  FAIL: clean dir produced unexpected output: $out"
  FAIL=$((FAIL + 1))
fi

# ── Missing bash lib, bash hook present → exit 1, ERROR mentions .sh ────────
echo ""
echo "--- missing _review-gate-lib.sh with review-reminders.sh present → FAIL ---"
rm -f "$TMPDIR_CHK/_review-gate-lib.sh"
out=$(bash "$CHECKER" "$TMPDIR_CHK"); rc=$?
assert_exit_nonzero $rc "missing bash lib: checker exits non-zero"
assert_contains "$out" "_review-gate-lib.sh missing" "missing bash lib: error message names the missing file"
touch "$TMPDIR_CHK/_review-gate-lib.sh"

# ── Missing ps1 lib, ps1 hook present → exit 1, ERROR mentions .ps1 ─────────
echo ""
echo "--- missing _review-gate-lib.ps1 with review-reminders.ps1 present → FAIL ---"
rm -f "$TMPDIR_CHK/_review-gate-lib.ps1"
out=$(bash "$CHECKER" "$TMPDIR_CHK"); rc=$?
assert_exit_nonzero $rc "missing ps1 lib: checker exits non-zero"
assert_contains "$out" "_review-gate-lib.ps1 missing" "missing ps1 lib: error message names the missing file"
touch "$TMPDIR_CHK/_review-gate-lib.ps1"

# ── -post variant alone also triggers the check (not just the non-post name) ─
echo ""
echo "--- review-reminders-post.sh alone (no review-reminders.sh) still requires the lib ---"
TMPDIR_CHK2="$(mktemp -d 2>/dev/null || mktemp -d -t mb-libcheck-test2)"
trap 'rm -rf "$TMPDIR_CHK2"' EXIT
touch "$TMPDIR_CHK2/review-reminders-post.sh"
out=$(bash "$CHECKER" "$TMPDIR_CHK2"); rc=$?
assert_exit_nonzero $rc "post-only variant: checker exits non-zero when its lib is missing"
assert_contains "$out" "_review-gate-lib.sh missing" "post-only variant: error message names the missing file"

# ── No hooks at all → exit 0, no output (nothing to check) ──────────────────
echo ""
echo "--- no review-reminders files at all → PASS, no output ---"
TMPDIR_CHK3="$(mktemp -d 2>/dev/null || mktemp -d -t mb-libcheck-test3)"
trap 'rm -rf "$TMPDIR_CHK3"' EXIT
out=$(bash "$CHECKER" "$TMPDIR_CHK3"); rc=$?
assert_exit_zero $rc "no hooks present: checker exits 0"
if [ -z "$out" ]; then
  echo "  PASS: no hooks present produces no output"
  PASS=$((PASS + 1))
else
  echo "  FAIL: no hooks present produced unexpected output: $out"
  FAIL=$((FAIL + 1))
fi

print_summary
