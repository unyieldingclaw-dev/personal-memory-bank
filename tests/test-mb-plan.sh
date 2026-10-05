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

# ── mb plan promote: status handling is scoped to the frontmatter ([NS-19]) ─────
# WHY: standards/WORKFLOW.md Phase 3 tells adopters promote COPIES the draft and sets
# `status: planned` unless a later status is set. Before [NS-19] a frontmatter block with no
# `status:` key (or an empty one) was promoted with no status at all while printing
# "draft -> planned", and the rewrite ran over the whole file, so a body line starting
# `status: draft` was rewritten too. `mb plan status` then flagged the plan it had just made.
echo ""
echo "--- mb plan promote: status handling (frontmatter only) ---"

_promote() { (cd "$TMPDIR_PLAN" && MB_HOME="$REPO_ROOT" bash "$MB" plan promote ".claude/plans/$1" 2>&1); }
# Frontmatter lines only: between the opening fence and the first closing fence, CR stripped.
_fm() { awk 'NR==1 {next} {sub(/\r$/, "")} /^---[ \t]*$/ {exit} {print}' "$TMPDIR_PLAN/docs/plans/$1"; }

printf -- '---\nstatus: draft\n---\n\n# Body\nstatus: draft is how this line starts\n' \
    > "$TMPDIR_PLAN/.claude/plans/2099-02-01-draft.md"
output=$(_promote 2099-02-01-draft.md)
assert_equals "$(_fm 2099-02-01-draft.md | grep -c '^status: planned$')" "1" "draft status becomes planned in the frontmatter"
assert_equals "$(grep -c '^status: draft is how this line starts$' "$TMPDIR_PLAN/docs/plans/2099-02-01-draft.md")" "1" \
    "a body line starting 'status: draft' is left alone"
assert_file_exists "$TMPDIR_PLAN/.claude/plans/2099-02-01-draft.md" "promote copies: the draft stays in .claude/plans/"

printf -- '---\ncreated: 2099-01-01\n---\n\n# No status key\n' > "$TMPDIR_PLAN/.claude/plans/2099-02-02-nokey.md"
output=$(_promote 2099-02-02-nokey.md)
assert_equals "$(_fm 2099-02-02-nokey.md | grep -c '^status: planned$')" "1" "frontmatter without a status key gains status: planned"
assert_not_contains "$output" "draft → planned" "no status key: the message does not claim a draft was rewritten"

printf -- '---\nstatus:\n---\n\n# Empty status\n' > "$TMPDIR_PLAN/.claude/plans/2099-02-03-empty.md"
_promote 2099-02-03-empty.md > /dev/null
assert_equals "$(_fm 2099-02-03-empty.md | grep -c '^status: planned$')" "1" "an empty status: becomes planned"

printf -- '---\nstatus: "draft"\n---\n\n# Quoted\n' > "$TMPDIR_PLAN/.claude/plans/2099-02-04-quoted.md"
_promote 2099-02-04-quoted.md > /dev/null
assert_equals "$(_fm 2099-02-04-quoted.md | grep -c '^status: planned$')" "1" "a quoted \"draft\" status becomes planned"

printf -- '---\nstatus: active\n---\n\n# Later\n' > "$TMPDIR_PLAN/.claude/plans/2099-02-05-later.md"
output=$(_promote 2099-02-05-later.md)
assert_equals "$(_fm 2099-02-05-later.md | grep -c '^status: active$')" "1" "a later status is kept"
assert_contains "$output" "preserved" "a kept status is reported as preserved"

# A leading horizontal rule with no closing fence is not frontmatter: inserting a status line
# after it would corrupt the body, so the draft is treated as having no frontmatter.
printf -- '---\n\n# Starts with a rule, no closing fence\n' > "$TMPDIR_PLAN/.claude/plans/2099-02-06-rule.md"
_promote 2099-02-06-rule.md > /dev/null
assert_equals "$(_fm 2099-02-06-rule.md | grep -c '^status: planned$')" "1" "an unclosed leading --- gets new frontmatter"
assert_equals "$(grep -c '^# Starts with a rule, no closing fence$' "$TMPDIR_PLAN/docs/plans/2099-02-06-rule.md")" "1" \
    "an unclosed leading --- keeps its original content"

printf -- '---\r\ncreated: 2099-01-01\r\n---\r\n\r\n# CRLF\r\n' > "$TMPDIR_PLAN/.claude/plans/2099-02-07-crlf.md"
_promote 2099-02-07-crlf.md > /dev/null
assert_equals "$(_fm 2099-02-07-crlf.md | grep -c '^status: planned$')" "1" "a CRLF draft gains status: planned"
# WHY awk with BINMODE=3, not grep: Git Bash's grep strips CR before matching, so the earlier
# `grep -vc $'\r$'` counted 0 for ANY file and could not fail. Other awks ignore BINMODE.
assert_equals "$(awk -v BINMODE=3 '!/\r$/ {n++} END {print n+0}' "$TMPDIR_PLAN/docs/plans/2099-02-07-crlf.md")" "0" \
  "a CRLF draft stays CRLF on every line"

# Both runtimes: the key is case-sensitive (YAML), the draft value is not.
printf -- '---\nstatus: DRAFT\n---\n\n# Upper\n' > "$TMPDIR_PLAN/.claude/plans/2099-02-08-upper.md"
_promote 2099-02-08-upper.md > /dev/null
assert_equals "$(_fm 2099-02-08-upper.md | grep -c '^status: planned$')" "1" "an uppercase DRAFT value becomes planned"
printf -- '---\nStatus: active\n---\n\n# Key case\n' > "$TMPDIR_PLAN/.claude/plans/2099-02-09-keycase.md"
_promote 2099-02-09-keycase.md > /dev/null
assert_equals "$(_fm 2099-02-09-keycase.md | grep -c '^status: planned$')" "1" "a capitalised Status: key is not the status key"

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
