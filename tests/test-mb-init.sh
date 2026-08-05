#!/usr/bin/env bash
# tests/test-mb-init.sh — tests for mb init
set -u

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
MB="$REPO_ROOT/scripts/mb.sh"
source "$REPO_ROOT/tests/helpers/assert.sh"
source "$REPO_ROOT/tests/setup.sh"

echo "=== mb init tests ==="

# ── Fresh directory ───────────────────────────────────────────────────────────
echo ""
echo "--- fresh directory: creates all files ---"

TMPDIR_INIT="$(mktemp -d 2>/dev/null || mktemp -d -t mb-init-test)"
trap 'rm -rf "$TMPDIR_INIT"' EXIT

cd "$TMPDIR_INIT" || exit 1
git init -q
git config user.email "test@test.com"
git config user.name "Test"
git commit -q --allow-empty -m "init"
cd - > /dev/null || exit 1

output=$(cd "$TMPDIR_INIT" && MB_HOME="$REPO_ROOT" bash "$MB" init 2>&1)
assert_exit_zero $? "mb init exits 0 in fresh directory"

for f in projectbrief.md systemPatterns.md techContext.md activeContext.md progress.md; do
  assert_file_exists "$TMPDIR_INIT/memory-bank/$f" "mb init creates memory-bank/$f"
done

assert_file_exists "$TMPDIR_INIT/.pmb-version" "mb init creates .pmb-version"

for f in CONTRACTS-GUIDE.md HOOKS-GUIDE.md; do
  assert_file_exists "$TMPDIR_INIT/docs/$f" "mb init creates docs/$f"
done

# review-reminders.sh/.ps1/-post.sh/-post.ps1 are invoked directly by templates/.claude/settings.json
# but were missing from the init copy loop's script allowlist -- mb init shipped a settings.json
# referencing hook scripts that were never actually copied into scripts/.
for f in review-reminders.sh review-reminders.ps1 review-reminders-post.sh review-reminders-post.ps1; do
  assert_file_exists "$TMPDIR_INIT/scripts/$f" "mb init creates scripts/$f"
done

# ── Re-init: already initialized ─────────────────────────────────────────────
echo ""
echo "--- re-init: already initialized ---"

output=$(cd "$TMPDIR_INIT" && MB_HOME="$REPO_ROOT" bash "$MB" init 2>&1)
assert_exit_zero $? "mb init exits 0 on re-init"
assert_contains "$output" "kept existing" "mb init reports kept existing on re-init"

# ── mb status passes after init ───────────────────────────────────────────────
echo ""
echo "--- mb status passes after init ---"

output=$(cd "$TMPDIR_INIT" && MB_HOME="$REPO_ROOT" bash "$MB" status 2>&1)
assert_exit_zero $? "mb status exits 0 after mb init"
assert_contains "$output" "Initialized" "mb status confirms initialized after mb init"

print_summary
