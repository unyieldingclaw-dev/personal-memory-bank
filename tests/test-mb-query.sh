#!/usr/bin/env bash
# tests/test-mb-query.sh — tests for mb query <keyword>
set -u

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
MB="$REPO_ROOT/scripts/mb.sh"
source "$REPO_ROOT/tests/helpers/assert.sh"
source "$REPO_ROOT/tests/setup.sh"

echo "=== mb query tests ==="

TMPDIR_QUERY="$(mktemp -d 2>/dev/null || mktemp -d -t mb-query-test)"
trap 'rm -rf "$TMPDIR_QUERY"' EXIT

setup_test_project "$TMPDIR_QUERY"

# ── No keyword argument ───────────────────────────────────────────────────────
echo ""
echo "--- no keyword: shows usage ---"

output=$(cd "$TMPDIR_QUERY" && MB_HOME="$REPO_ROOT" bash "$MB" query 2>&1)
assert_exit_zero $? "mb query with no args exits zero"

# ── Tag match ─────────────────────────────────────────────────────────────────
echo ""
echo "--- tag match ---"

cat > "$TMPDIR_QUERY/memory-bank/activeContext.md" << 'EOF'
---
authority: volatile
last-reviewed: 2099-01-01
staleness-threshold: 90d
tags:
  - authentication
  - security
---
# Active Context
Current focus on auth system.
EOF

output=$(cd "$TMPDIR_QUERY" && MB_HOME="$REPO_ROOT" bash "$MB" query authentication 2>&1)
assert_exit_zero $? "mb query exits 0 when tag matches"
assert_contains "$output" "activeContext" "mb query returns file with matching tag"

# ── Section header match ──────────────────────────────────────────────────────
echo ""
echo "--- section header match ---"

cat >> "$TMPDIR_QUERY/memory-bank/systemPatterns.md" << 'EOF'

## auth token validation
Describes the auth pattern used in this project.
EOF

output=$(cd "$TMPDIR_QUERY" && MB_HOME="$REPO_ROOT" bash "$MB" query auth 2>&1)
assert_exit_zero $? "mb query exits 0 when section header matches"
assert_contains "$output" "systemPatterns" "mb query returns file with matching section header"

# ── No match ──────────────────────────────────────────────────────────────────
echo ""
echo "--- no match ---"

output=$(cd "$TMPDIR_QUERY" && MB_HOME="$REPO_ROOT" bash "$MB" query nonexistentkeyword99 2>&1)
assert_exit_zero $? "mb query exits 0 when no matches found"
assert_contains "$output" "No matches" "mb query reports no matches for unknown keyword"

print_summary
