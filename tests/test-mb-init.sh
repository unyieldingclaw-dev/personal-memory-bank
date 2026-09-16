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

# _review-gate-lib.sh/.ps1 are dot-sourced by review-reminders*.sh/.ps1 but are never
# referenced directly in settings.json -- they need their own explicit entry in mb init's
# copy loop, or a project onboarded via mb init ships hook files that fail open (silently
# skip the gate) because the lib they source doesn't exist.
for f in _review-gate-lib.sh _review-gate-lib.ps1; do
  assert_file_exists "$TMPDIR_INIT/scripts/$f" "mb init creates scripts/$f"
done

for f in _review-gate-classify.py _review-gate-classify.ps1; do
  assert_file_exists "$TMPDIR_INIT/scripts/$f" "mb init creates scripts/$f"
done

# ── Agent definitions ────────────────────────────────────────────────────────
# WHY this exists: mb init copied every templates/claude-commands/* -- including code-review.md
# and change-review.md, which dispatch `subagent_type: opposition` BY NAME -- while containing
# zero references to .claude/agents. d795abb turned a latent gap live by making the agent a named
# dependency: a fresh adopter's review gate died at Opposition, and the documented fallback
# (code-review.md:98, "paste the body of .claude/agents/opposition.md in as the prompt") needed
# the same file init never delivered. Agent delivery had been fixed for `mb upgrade` and scoped
# to the one path that prompted it.
#
# COMPLETENESS INVARIANT, deliberately not `assert_file_exists .../opposition.md`: a hard-coded
# name keeps passing on the day a fourth agent is added and goes undelivered, which is the exact
# stale-list bug this feature replaced. Derive the expected set from templates/ at runtime so the
# check has no list of its own to go stale.
EXPECTED_AGENTS=""
for f in "$REPO_ROOT/templates/.claude/agents"/*.md; do
  [ -f "$f" ] || continue
  EXPECTED_AGENTS="$EXPECTED_AGENTS $(basename "$f")"
done
# WHY the non-empty assertion: without it, a missing or empty templates/.claude/agents/ makes the
# loop below iterate zero times, leaving MISSING_AGENTS empty and reporting PASS while delivering
# nothing. That is the fail-silent-when-a-precondition-is-absent shape (Family B); absence must be
# loud. tests/test-mb-upgrade.sh's equivalent block still lacks this guard -- tracked, not fixed here.
assert_not_contains "expected:${EXPECTED_AGENTS}" "expected:$" "templates/.claude/agents/ yields a non-empty expected set"

MISSING_AGENTS=""
for f in "$REPO_ROOT/templates/.claude/agents"/*.md; do
  [ -f "$f" ] || continue
  [ -f "$TMPDIR_INIT/.claude/agents/$(basename "$f")" ] || MISSING_AGENTS="$MISSING_AGENTS $(basename "$f")"
done
assert_contains "missing:${MISSING_AGENTS}" "missing:$" "mb init delivers every agent in templates/.claude/agents/"

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
