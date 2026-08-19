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
# WHY these assertions were strengthened (found by code review): the original
# `assert_contains "$output" "slim"` is trivially satisfied by every invocation of
# `mb clean` regardless of file size -- the "--- Slim Check ---" section header alone
# contains "Slim", so this assertion never actually exercised the over-400-line branch
# it claimed to test. The assertions below check the specific line-count-dependent
# output show_clean() only prints when PROGRESS_LINES > 400 (scripts/mb.sh:395-396),
# and confirm the exact reported line count so a future off-by-one in the threshold
# check would actually fail this test instead of passing silently.
echo ""
echo "--- oversized progress.md: crosses the 400-line threshold, ACTION NEEDED shown ---"

{
  echo "# Progress"
  for i in $(seq 1 401); do echo "Entry $i: progress note."; done
} > "$TMPDIR_CLEAN/memory-bank/progress.md"
PROGRESS_LINE_COUNT=$(wc -l < "$TMPDIR_CLEAN/memory-bank/progress.md" | tr -d ' ')

output=$(cd "$TMPDIR_CLEAN" && MB_HOME="$REPO_ROOT" bash "$MB" clean 2>&1)
assert_exit_zero $? "mb clean exits 0 with oversized file"
assert_contains "$output" "progress.md: $PROGRESS_LINE_COUNT lines (max: 400)" "mb clean reports progress.md's actual line count against the 400-line max"
assert_contains "$output" "ACTION NEEDED: File is over limit!" "mb clean shows the over-limit warning once progress.md exceeds 400 lines"
# WHY also assert the activeContext.md line is still "OK": proves the two size checks
# are independent -- an oversized progress.md alone should not also flag
# activeContext.md (which setup_test_project leaves at a handful of lines), ruling out
# a bug where the wrong file's line count feeds the wrong threshold check.
assert_contains "$output" "activeContext.md:" "mb clean still reports activeContext.md's own line count independently"

# ── progress.md between 250 and 400 lines: RECOMMENDED, not ACTION NEEDED ──────────────────
# WHY this test exists: the over-400 case above only exercises one of show_clean()'s three
# branches (scripts/mb.sh:395-401). Nothing previously exercised the middle
# "RECOMMENDED: Consider archiving old entries" branch (250 < lines <= 400) at all.
echo ""
echo "--- progress.md between 250 and 400 lines: RECOMMENDED, not ACTION NEEDED ---"

{
  echo "# Progress"
  for i in $(seq 1 260); do echo "Entry $i: progress note."; done
} > "$TMPDIR_CLEAN/memory-bank/progress.md"

output=$(cd "$TMPDIR_CLEAN" && MB_HOME="$REPO_ROOT" bash "$MB" clean 2>&1)
assert_contains "$output" "RECOMMENDED: Consider archiving old entries" "mb clean recommends archiving once progress.md exceeds 250 lines but is still under 400"
assert_not_contains "$output" "ACTION NEEDED: File is over limit!" "mb clean does not show the over-limit warning while progress.md is still under 400 lines"

print_summary
