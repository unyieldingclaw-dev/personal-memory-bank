# PMB Test Coverage — Workstream 2 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add 53 test cases across 8 new test files covering all untested `mb` commands, registered in `tests/run.sh`.

**Architecture:** Pure bash, zero external dependencies. Every test file follows the pattern of `tests/test-mb-plan.sh`: source `helpers/assert.sh` and `setup.sh`, create a temp dir with `mktemp -d`, call `setup_test_project`, run `MB_HOME="$REPO_ROOT" bash "$MB" <command>`, assert on exit code and output text, clean up via `trap`. Tests assert on existing behavior — they should pass immediately without any implementation changes.

**Tech Stack:** POSIX sh / bash, `tests/helpers/assert.sh` (custom assertions), `tests/setup.sh` (`setup_test_project`). Repo: `C:\Users\Mizzo\Claude\Personal-Memory-Bank`

---

## File Map

| File | Operation |
|---|---|
| `tests/run.sh` | Modify — add 8 `run_suite` calls |
| `tests/test-mb-status.sh` | Create — 6 cases |
| `tests/test-mb-verify-integrity.sh` | Create — 3 cases |
| `tests/test-mb-query.sh` | Create — 4 cases |
| `tests/test-mb-init.sh` | Create — 3 cases |
| `tests/test-mb-clean.sh` | Create — 2 cases |
| `tests/test-mb-commit.sh` | Create — 2 cases |
| `tests/test-mb-upgrade.sh` | Create — 3 cases |
| `tests/test-mb-doctor.sh` | Create — 25 cases |

---

## Task 1: Register all new suites in tests/run.sh

**Files:**
- Modify: `tests/run.sh:20-22`

- [ ] **Step 1: Add 8 new run_suite calls**

Replace the existing three `run_suite` calls (lines 20–22) with all 11:

```bash
run_suite "mb plan"              "$REPO_ROOT/tests/test-mb-plan.sh"
run_suite "mb preflight"         "$REPO_ROOT/tests/test-mb-preflight.sh"
run_suite "mb change-check"      "$REPO_ROOT/tests/test-mb-change-check.sh"
run_suite "mb status"            "$REPO_ROOT/tests/test-mb-status.sh"
run_suite "mb verify-integrity"  "$REPO_ROOT/tests/test-mb-verify-integrity.sh"
run_suite "mb query"             "$REPO_ROOT/tests/test-mb-query.sh"
run_suite "mb init"              "$REPO_ROOT/tests/test-mb-init.sh"
run_suite "mb clean"             "$REPO_ROOT/tests/test-mb-clean.sh"
run_suite "mb commit"            "$REPO_ROOT/tests/test-mb-commit.sh"
run_suite "mb upgrade"           "$REPO_ROOT/tests/test-mb-upgrade.sh"
run_suite "mb doctor"            "$REPO_ROOT/tests/test-mb-doctor.sh"
```

- [ ] **Step 2: Verify run.sh still passes with only existing tests (new suites don't exist yet)**

```bash
cd "C:\Users\Mizzo\Claude\Personal-Memory-Bank"
bash tests/run.sh
```

Expected: existing 3 suites pass; new suites fail with "No such file" — that's expected at this stage, **not** a regression. The runner will set `OVERALL_FAIL=1` but that's fine — we're adding tests incrementally.

- [ ] **Step 3: Commit**

```bash
cd "C:\Users\Mizzo\Claude\Personal-Memory-Bank"
git add tests/run.sh
git commit -m "test: register 8 new test suites in run.sh"
```

---

## Task 2: mb status tests

**Files:**
- Create: `tests/test-mb-status.sh`

- [ ] **Step 1: Create the test file**

```bash
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

# ── Clean project (all signals pass) ────────────────────────────────────────
echo ""
echo "--- clean project ---"

output=$(cd "$TMPDIR_STATUS" && MB_HOME="$REPO_ROOT" bash "$MB" status 2>&1)
assert_exit_zero $? "mb status exits 0 on clean project"
assert_contains "$output" "Initialized" "mb status shows Initialized signal"
assert_contains "$output" "0 Issues" "mb status shows 0 Issues on clean project"

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
printf -- "---\nauthority: stable\nlast-reviewed: %s\nstaleness-threshold: 90d\n---\n# activeContext\nTest.\n" \
  "$(date +%Y-%m-%d)" > "$TMPDIR_STATUS/memory-bank/activeContext.md"

# ── Signal 3: Stale active context ───────────────────────────────────────────
echo ""
echo "--- signal 3: stale active context ---"

# Set last-reviewed to 30 days ago with 7d threshold
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

# ── Signal 5: No active tasks (negative) + positive ──────────────────────────
echo ""
echo "--- signal 5: no active tasks ---"

output=$(cd "$TMPDIR_STATUS" && MB_HOME="$REPO_ROOT" bash "$MB" status 2>&1)
assert_contains "$output" "No Active Tasks" "mb status shows No Active Tasks when .claude/contracts/ is empty"

echo ""
echo "--- signal 5: tasks present ---"

printf '{"task":"test","status":"active"}\n' > "$TMPDIR_STATUS/.claude/contracts/active-task.json"
output=$(cd "$TMPDIR_STATUS" && MB_HOME="$REPO_ROOT" bash "$MB" status 2>&1)
assert_contains "$output" "Tasks Present" "mb status shows Tasks Present when contract json exists"

print_summary
```

- [ ] **Step 2: Run the test**

```bash
cd "C:\Users\Mizzo\Claude\Personal-Memory-Bank"
bash tests/test-mb-status.sh
```

Expected: all assertions pass, `Results: N passed, 0 failed`

- [ ] **Step 3: Run full suite**

```bash
bash tests/run.sh
```

Expected: existing suites pass + mb status passes.

- [ ] **Step 4: Commit**

```bash
git add tests/test-mb-status.sh
git commit -m "test: add mb status tests — 6 cases covering all 5 signals"
```

---

## Task 3: mb verify-integrity tests

**Files:**
- Create: `tests/test-mb-verify-integrity.sh`

- [ ] **Step 1: Create the test file**

```bash
#!/usr/bin/env bash
# tests/test-mb-verify-integrity.sh — tests for mb verify-integrity
set -u

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
MB="$REPO_ROOT/scripts/mb.sh"
source "$REPO_ROOT/tests/helpers/assert.sh"
source "$REPO_ROOT/tests/setup.sh"

echo "=== mb verify-integrity tests ==="

TMPDIR_VI="$(mktemp -d 2>/dev/null || mktemp -d -t mb-vi-test)"
trap 'rm -rf "$TMPDIR_VI"' EXIT

setup_test_project "$TMPDIR_VI"

# ── First run: no baseline ───────────────────────────────────────────────────
echo ""
echo "--- first run: establishes baseline ---"

assert_file_not_exists "$TMPDIR_VI/.pmb-checksums" ".pmb-checksums absent before first run"

output=$(cd "$TMPDIR_VI" && MB_HOME="$REPO_ROOT" bash "$MB" verify-integrity 2>&1)
assert_exit_zero $? "mb verify-integrity exits 0 on first run"
assert_contains "$output" "baseline" "mb verify-integrity reports baseline established"
assert_file_exists "$TMPDIR_VI/.pmb-checksums" ".pmb-checksums created after first run"

# ── Second run: no changes ───────────────────────────────────────────────────
echo ""
echo "--- second run: checksums match ---"

output=$(cd "$TMPDIR_VI" && MB_HOME="$REPO_ROOT" bash "$MB" verify-integrity 2>&1)
assert_exit_zero $? "mb verify-integrity exits 0 when checksums match"
assert_contains "$output" "verified" "mb verify-integrity reports checksums verified"

# ── Third run: tampered file ──────────────────────────────────────────────────
echo ""
echo "--- third run: tampered file triggers mismatch ---"

echo "# external edit" >> "$TMPDIR_VI/memory-bank/activeContext.md"
output=$(cd "$TMPDIR_VI" && MB_HOME="$REPO_ROOT" bash "$MB" verify-integrity 2>&1)
assert_contains "$output" "mismatch" "mb verify-integrity warns on hash mismatch after external edit"

print_summary
```

- [ ] **Step 2: Run the test**

```bash
cd "C:\Users\Mizzo\Claude\Personal-Memory-Bank"
bash tests/test-mb-verify-integrity.sh
```

Expected: all assertions pass.

- [ ] **Step 3: Commit**

```bash
git add tests/test-mb-verify-integrity.sh
git commit -m "test: add mb verify-integrity tests — first run, clean run, tampered file"
```

---

## Task 4: mb query tests

**Files:**
- Create: `tests/test-mb-query.sh`

- [ ] **Step 1: Create the test file**

```bash
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
assert_exit_nonzero $? "mb query with no args exits non-zero"

# ── Tag match ─────────────────────────────────────────────────────────────────
echo ""
echo "--- tag match ---"

# Inject tags into activeContext.md frontmatter
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

## Authentication Flow
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
```

- [ ] **Step 2: Run the test**

```bash
cd "C:\Users\Mizzo\Claude\Personal-Memory-Bank"
bash tests/test-mb-query.sh
```

Expected: all assertions pass.

- [ ] **Step 3: Commit**

```bash
git add tests/test-mb-query.sh
git commit -m "test: add mb query tests — no keyword, tag match, section match, no match"
```

---

## Task 5: mb init tests

**Files:**
- Create: `tests/test-mb-init.sh`

- [ ] **Step 1: Create the test file**

```bash
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

# Minimal git repo (mb init requires git)
cd "$TMPDIR_INIT" || exit 1
git init -q
git config user.email "test@test.com"
git config user.name "Test"
git commit -q --allow-empty -m "init"
cd - > /dev/null || exit 1

output=$(cd "$TMPDIR_INIT" && MB_HOME="$REPO_ROOT" bash "$MB" init 2>&1)
assert_exit_zero $? "mb init exits 0 in fresh directory"

# All 5 memory-bank files created
for f in projectbrief.md systemPatterns.md techContext.md activeContext.md progress.md; do
  assert_file_exists "$TMPDIR_INIT/memory-bank/$f" "mb init creates memory-bank/$f"
done

# .pmb-version written
assert_file_exists "$TMPDIR_INIT/.pmb-version" "mb init creates .pmb-version"

# ── Re-init: already initialized ─────────────────────────────────────────────
echo ""
echo "--- re-init: already initialized ---"

output=$(cd "$TMPDIR_INIT" && MB_HOME="$REPO_ROOT" bash "$MB" init 2>&1)
assert_exit_zero $? "mb init exits 0 on re-init"
assert_contains "$output" "initialized" "mb init reports already initialized on re-init"

# ── mb status passes after init ───────────────────────────────────────────────
echo ""
echo "--- mb status passes after init ---"

# setup_test_project creates CLAUDE.md; mb init may not; create it for this test
[ ! -f "$TMPDIR_INIT/CLAUDE.md" ] && printf "# Project\nCLAUDE_AUTOCOMPACT_PCT_OVERRIDE=40\n" > "$TMPDIR_INIT/CLAUDE.md"

output=$(cd "$TMPDIR_INIT" && MB_HOME="$REPO_ROOT" bash "$MB" status 2>&1)
assert_exit_zero $? "mb status exits 0 after mb init"
assert_contains "$output" "Initialized" "mb status confirms initialized after mb init"

print_summary
```

- [ ] **Step 2: Run the test**

```bash
cd "C:\Users\Mizzo\Claude\Personal-Memory-Bank"
bash tests/test-mb-init.sh
```

Expected: all assertions pass.

- [ ] **Step 3: Commit**

```bash
git add tests/test-mb-init.sh
git commit -m "test: add mb init tests — fresh dir, re-init, status after init"
```

---

## Task 6: mb clean tests

**Files:**
- Create: `tests/test-mb-clean.sh`

- [ ] **Step 1: Create the test file**

```bash
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
echo ""
echo "--- oversized progress.md: slim warning ---"

# Pad progress.md to 401 lines (limit is 400)
{
  printf "# Progress\n"
  for i in $(seq 1 401); do printf "- Entry %d: progress note.\n" "$i"; done
} > "$TMPDIR_CLEAN/memory-bank/progress.md"

output=$(cd "$TMPDIR_CLEAN" && MB_HOME="$REPO_ROOT" bash "$MB" clean 2>&1)
assert_exit_zero $? "mb clean exits 0 with oversized file"
assert_contains "$output" "slim" "mb clean mentions slim when progress.md is oversized"

print_summary
```

- [ ] **Step 2: Run the test**

```bash
cd "C:\Users\Mizzo\Claude\Personal-Memory-Bank"
bash tests/test-mb-clean.sh
```

Expected: all assertions pass.

- [ ] **Step 3: Commit**

```bash
git add tests/test-mb-clean.sh
git commit -m "test: add mb clean tests — maintenance guidance, oversized file slim warning"
```

---

## Task 7: mb commit tests

**Files:**
- Create: `tests/test-mb-commit.sh`

**Note:** `mb commit` is interactive (prompts `y/n`). Pipe `"y\n"` to stdin for the "modified file" case. The "no changes" case exits before the prompt.

- [ ] **Step 1: Create the test file**

```bash
#!/usr/bin/env bash
# tests/test-mb-commit.sh — tests for mb commit
set -u

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
MB="$REPO_ROOT/scripts/mb.sh"
source "$REPO_ROOT/tests/helpers/assert.sh"
source "$REPO_ROOT/tests/setup.sh"

echo "=== mb commit tests ==="

TMPDIR_COMMIT="$(mktemp -d 2>/dev/null || mktemp -d -t mb-commit-test)"
trap 'rm -rf "$TMPDIR_COMMIT"' EXIT

setup_test_project "$TMPDIR_COMMIT"

# ── No changes: graceful message ─────────────────────────────────────────────
echo ""
echo "--- no changes: nothing to commit ---"

output=$(cd "$TMPDIR_COMMIT" && MB_HOME="$REPO_ROOT" bash "$MB" commit 2>&1)
assert_exit_zero $? "mb commit exits 0 when nothing to commit"
assert_contains "$output" "No changes" "mb commit reports no changes when memory-bank is clean"

# ── Modified file: commit succeeds ───────────────────────────────────────────
echo ""
echo "--- modified file: commit succeeds ---"

echo "# New entry" >> "$TMPDIR_COMMIT/memory-bank/progress.md"

# Pipe 'y' to confirm the commit prompt
output=$(echo "y" | (cd "$TMPDIR_COMMIT" && MB_HOME="$REPO_ROOT" bash "$MB" commit 2>&1))
assert_exit_zero $? "mb commit exits 0 after confirming"
assert_contains "$output" "Committed" "mb commit reports Committed on success"

# Verify a new commit was created (started with 1 commit from setup, now should have 2)
commit_count=$(cd "$TMPDIR_COMMIT" && git rev-list --count HEAD 2>&1)
assert_contains "$commit_count" "2" "git shows 2 commits after mb commit"

print_summary
```

- [ ] **Step 2: Run the test**

```bash
cd "C:\Users\Mizzo\Claude\Personal-Memory-Bank"
bash tests/test-mb-commit.sh
```

Expected: all assertions pass.

- [ ] **Step 3: Commit**

```bash
git add tests/test-mb-commit.sh
git commit -m "test: add mb commit tests — no changes path, modified file commit"
```

---

## Task 8: mb upgrade tests

**Files:**
- Create: `tests/test-mb-upgrade.sh`

- [ ] **Step 1: Create the test file**

```bash
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

# dangerous-commands.sh is TEMPLATE_OWNED — delete it and verify upgrade restores it
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

print_summary
```

- [ ] **Step 2: Run the test**

```bash
cd "C:\Users\Mizzo\Claude\Personal-Memory-Bank"
bash tests/test-mb-upgrade.sh
```

Expected: all assertions pass.

- [ ] **Step 3: Commit**

```bash
git add tests/test-mb-upgrade.sh
git commit -m "test: add mb upgrade tests — template sync, version tracking, missing standard"
```

---

## Task 9: mb doctor tests

**Files:**
- Create: `tests/test-mb-doctor.sh`

This is the largest test file: 25 cases (1 clean baseline + 1 per check). A single shared temp project is mutated per check; each mutation is either left in place (if harmless to subsequent checks) or restored immediately. Checks that require repo-level mutations (fixtures, templates) use rename/restore with a nested trap.

- [ ] **Step 1: Create the test file**

```bash
#!/usr/bin/env bash
# tests/test-mb-doctor.sh — tests for mb doctor (all 24 checks + clean baseline)
# WHY: set -e absent intentionally — commands expected to return non-zero won't abort suite.
set -u

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
MB="$REPO_ROOT/scripts/mb.sh"
source "$REPO_ROOT/tests/helpers/assert.sh"
source "$REPO_ROOT/tests/setup.sh"

echo "=== mb doctor tests ==="

# ── Baseline: clean project — no warnings ────────────────────────────────────
echo ""
echo "--- baseline: clean project ---"

TMPDIR_CLEAN="$(mktemp -d 2>/dev/null || mktemp -d -t mb-doctor-clean)"
trap 'rm -rf "$TMPDIR_CLEAN"' EXIT

setup_test_project "$TMPDIR_CLEAN"
# Copy fixtures and security dir so Check 13 passes on baseline
mkdir -p "$TMPDIR_CLEAN/fixtures"
cp -r "$REPO_ROOT/fixtures" "$TMPDIR_CLEAN/" 2>/dev/null || true

output=$(cd "$TMPDIR_CLEAN" && MB_HOME="$REPO_ROOT" bash "$MB" doctor 2>&1)
assert_exit_zero $? "mb doctor exits 0 on clean project"

# ── Shared project for individual check tests ────────────────────────────────
TMPDIR_DOC="$(mktemp -d 2>/dev/null || mktemp -d -t mb-doctor-checks)"
trap 'rm -rf "$TMPDIR_DOC"' EXIT

setup_test_project "$TMPDIR_DOC"

# ── Check 0: Missing VERSION file ────────────────────────────────────────────
echo ""
echo "--- check 0: missing VERSION ---"

# Doctor reads VERSION from REPO_ROOT, not project dir — temporarily rename it
mv "$REPO_ROOT/VERSION" "$REPO_ROOT/VERSION.bak"
output=$(cd "$TMPDIR_DOC" && MB_HOME="$REPO_ROOT" bash "$MB" doctor 2>&1)
mv "$REPO_ROOT/VERSION.bak" "$REPO_ROOT/VERSION"
assert_contains "$output" "[WARN]" "doctor warns when VERSION file missing"

# ── Check 1: Not a git repository ────────────────────────────────────────────
echo ""
echo "--- check 1: no git repo ---"

TMPDIR_NOGIT="$(mktemp -d 2>/dev/null || mktemp -d -t mb-doctor-nogit)"
trap 'rm -rf "$TMPDIR_NOGIT"' EXIT
setup_test_project "$TMPDIR_NOGIT"
rm -rf "$TMPDIR_NOGIT/.git"
output=$(cd "$TMPDIR_NOGIT" && MB_HOME="$REPO_ROOT" bash "$MB" doctor 2>&1)
assert_contains "$output" "[WARN]" "doctor warns when not a git repository"

# ── Check 2: Templates not found ─────────────────────────────────────────────
echo ""
echo "--- check 2: no templates dir ---"

mv "$REPO_ROOT/templates" "$REPO_ROOT/templates.bak"
output=$(cd "$TMPDIR_DOC" && MB_HOME="$REPO_ROOT" bash "$MB" doctor 2>&1)
mv "$REPO_ROOT/templates.bak" "$REPO_ROOT/templates"
assert_contains "$output" "[ERROR]" "doctor errors when templates dir missing"

# ── Check 3: Missing required memory-bank file ───────────────────────────────
echo ""
echo "--- check 3: missing activeContext.md ---"

rm "$TMPDIR_DOC/memory-bank/activeContext.md"
output=$(cd "$TMPDIR_DOC" && MB_HOME="$REPO_ROOT" bash "$MB" doctor 2>&1)
assert_contains "$output" "[ERROR]" "doctor errors when memory-bank file missing"

# Restore
printf -- "---\nauthority: volatile\nlast-reviewed: %s\nstaleness-threshold: 7d\n---\n# Active Context\nTest.\n" \
  "$(date +%Y-%m-%d)" > "$TMPDIR_DOC/memory-bank/activeContext.md"

# ── Check 4: No .claude/settings.json ────────────────────────────────────────
echo ""
echo "--- check 4: no settings.json ---"

rm -f "$TMPDIR_DOC/.claude/settings.json"
output=$(cd "$TMPDIR_DOC" && MB_HOME="$REPO_ROOT" bash "$MB" doctor 2>&1)
assert_contains "$output" "[WARN]" "doctor warns when .claude/settings.json missing"

# ── Check 5: Token budget drift ───────────────────────────────────────────────
echo ""
echo "--- check 5: no CLAUDE_AUTOCOMPACT_PCT_OVERRIDE ---"

printf "# Project\n" > "$TMPDIR_DOC/CLAUDE.md"
output=$(cd "$TMPDIR_DOC" && MB_HOME="$REPO_ROOT" bash "$MB" doctor 2>&1)
assert_contains "$output" "[WARN]" "doctor warns on token budget drift"
printf "# Project\nCLAUDE_AUTOCOMPACT_PCT_OVERRIDE=40\n" > "$TMPDIR_DOC/CLAUDE.md"

# ── Check 6: File size over limit ─────────────────────────────────────────────
echo ""
echo "--- check 6: oversized activeContext.md ---"

{
  printf -- "---\nauthority: volatile\nlast-reviewed: %s\nstaleness-threshold: 7d\n---\n# Active Context\n" "$(date +%Y-%m-%d)"
  for i in $(seq 1 155); do printf "- Entry %d: some test content here.\n" "$i"; done
} > "$TMPDIR_DOC/memory-bank/activeContext.md"
output=$(cd "$TMPDIR_DOC" && MB_HOME="$REPO_ROOT" bash "$MB" doctor 2>&1)
assert_contains "$output" "[WARN]" "doctor warns on oversized activeContext.md"

# Restore normal-sized file
printf -- "---\nauthority: volatile\nlast-reviewed: %s\nstaleness-threshold: 7d\n---\n# Active Context\nTest.\n" \
  "$(date +%Y-%m-%d)" > "$TMPDIR_DOC/memory-bank/activeContext.md"

# ── Check 7: handoff.md present ───────────────────────────────────────────────
echo ""
echo "--- check 7: handoff.md present ---"

touch "$TMPDIR_DOC/handoff.md"
output=$(cd "$TMPDIR_DOC" && MB_HOME="$REPO_ROOT" bash "$MB" doctor 2>&1)
assert_contains "$output" "[WARN]" "doctor warns when handoff.md present"
rm -f "$TMPDIR_DOC/handoff.md"

# ── Check 8: High compaction generation ───────────────────────────────────────
echo ""
echo "--- check 8: compaction_generation >= 3 ---"

# Insert compaction_generation: 3 into progress.md frontmatter
cat > "$TMPDIR_DOC/memory-bank/progress.md" << 'EOF'
---
authority: accumulating
last-reviewed: 2099-01-01
staleness-threshold: 90d
compaction_generation: 3
source_type: compacted
lineage:
  - progress.md
---
# Progress
Test.
EOF
output=$(cd "$TMPDIR_DOC" && MB_HOME="$REPO_ROOT" bash "$MB" doctor 2>&1)
assert_contains "$output" "[WARN]" "doctor warns on high compaction_generation"

# Restore
printf -- "---\nauthority: accumulating\nlast-reviewed: %s\nstaleness-threshold: 90d\n---\n# Progress\nTest.\n" \
  "$(date +%Y-%m-%d)" > "$TMPDIR_DOC/memory-bank/progress.md"

# ── Check 9: Stale memory-bank file ───────────────────────────────────────────
echo ""
echo "--- check 9: stale volatile file ---"

STALE_DATE=$(date -d "60 days ago" +%Y-%m-%d 2>/dev/null || date -v-60d +%Y-%m-%d 2>/dev/null || echo "2020-01-01")
printf -- "---\nauthority: volatile\nlast-reviewed: %s\nstaleness-threshold: 7d\n---\n# Active Context\nTest.\n" \
  "$STALE_DATE" > "$TMPDIR_DOC/memory-bank/activeContext.md"
output=$(cd "$TMPDIR_DOC" && MB_HOME="$REPO_ROOT" bash "$MB" doctor 2>&1)
assert_contains "$output" "[WARN]" "doctor warns on stale volatile file"

# Restore
printf -- "---\nauthority: volatile\nlast-reviewed: %s\nstaleness-threshold: 7d\n---\n# Active Context\nTest.\n" \
  "$(date +%Y-%m-%d)" > "$TMPDIR_DOC/memory-bank/activeContext.md"

# ── Check 10: Placeholder text ────────────────────────────────────────────────
echo ""
echo "--- check 10: placeholder text in memory-bank ---"

echo "TODO: fix this" >> "$TMPDIR_DOC/memory-bank/activeContext.md"
output=$(cd "$TMPDIR_DOC" && MB_HOME="$REPO_ROOT" bash "$MB" doctor 2>&1)
assert_contains "$output" "[WARN]" "doctor warns on placeholder text"

# Restore
printf -- "---\nauthority: volatile\nlast-reviewed: %s\nstaleness-threshold: 7d\n---\n# Active Context\nTest.\n" \
  "$(date +%Y-%m-%d)" > "$TMPDIR_DOC/memory-bank/activeContext.md"

# ── Check 11: Missing required standard ───────────────────────────────────────
echo ""
echo "--- check 11: missing WORKFLOW.md ---"

rm -f "$TMPDIR_DOC/standards/WORKFLOW.md"
output=$(cd "$TMPDIR_DOC" && MB_HOME="$REPO_ROOT" bash "$MB" doctor 2>&1)
assert_contains "$output" "[WARN]" "doctor warns when required standard missing"
printf "# WORKFLOW\n" > "$TMPDIR_DOC/standards/WORKFLOW.md"

# ── Check 12: PMB version mismatch ────────────────────────────────────────────
echo ""
echo "--- check 12: .pmb-version mismatch ---"

echo "0.0.0" > "$TMPDIR_DOC/.pmb-version"
output=$(cd "$TMPDIR_DOC" && MB_HOME="$REPO_ROOT" bash "$MB" doctor 2>&1)
assert_contains "$output" "[WARN]" "doctor warns on PMB version mismatch"
rm -f "$TMPDIR_DOC/.pmb-version"

# ── Check 13: Missing security fixture ────────────────────────────────────────
echo ""
echo "--- check 13: missing security fixture ---"

# Temporarily rename SEC-001 in REPO_ROOT to simulate missing fixture
mv "$REPO_ROOT/fixtures/security/SEC-001" "$REPO_ROOT/fixtures/security/SEC-001.bak"
output=$(cd "$TMPDIR_DOC" && MB_HOME="$REPO_ROOT" bash "$MB" doctor 2>&1)
mv "$REPO_ROOT/fixtures/security/SEC-001.bak" "$REPO_ROOT/fixtures/security/SEC-001"
assert_contains "$output" "[ERROR]" "doctor errors on missing security fixture"

# ── Check 14: Too many standards ──────────────────────────────────────────────
echo ""
echo "--- check 14: >20 standards files ---"

# Create dummy standards files to exceed 20
for i in $(seq 1 10); do
  printf "# Extra Standard %d\n" "$i" > "$TMPDIR_DOC/standards/EXTRA-${i}.md"
done
output=$(cd "$TMPDIR_DOC" && MB_HOME="$REPO_ROOT" bash "$MB" doctor 2>&1)
assert_contains "$output" "[WARN]" "doctor warns when standards count exceeds 20"
rm -f "$TMPDIR_DOC/standards/EXTRA-"*.md

# ── Check 15: Startup context ceiling ─────────────────────────────────────────
echo ""
echo "--- check 15: startup context exceeds 15KB ---"

# Pad CLAUDE.md to push total over 15KB
{
  printf "# Project\nCLAUDE_AUTOCOMPACT_PCT_OVERRIDE=40\n"
  for i in $(seq 1 500); do printf "xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx\n"; done
} > "$TMPDIR_DOC/CLAUDE.md"
output=$(cd "$TMPDIR_DOC" && MB_HOME="$REPO_ROOT" bash "$MB" doctor 2>&1)
assert_contains "$output" "[WARN]" "doctor warns on startup context exceeding 15KB"
printf "# Project\nCLAUDE_AUTOCOMPACT_PCT_OVERRIDE=40\n" > "$TMPDIR_DOC/CLAUDE.md"

# ── Check 16: Hook error log present ──────────────────────────────────────────
echo ""
echo "--- check 16: .pmb-hook-errors.log present ---"

echo "[HOOK ERROR] test error at $(date)" > "$TMPDIR_DOC/.pmb-hook-errors.log"
output=$(cd "$TMPDIR_DOC" && MB_HOME="$REPO_ROOT" bash "$MB" doctor 2>&1)
assert_contains "$output" "[WARN]" "doctor warns when hook error log has content"
rm -f "$TMPDIR_DOC/.pmb-hook-errors.log"

# ── Check 17: Semantic drift signals ──────────────────────────────────────────
echo ""
echo "--- check 17: semantic drift in activeContext.md ---"

echo "This feature is no longer relevant to the project." >> "$TMPDIR_DOC/memory-bank/activeContext.md"
output=$(cd "$TMPDIR_DOC" && MB_HOME="$REPO_ROOT" bash "$MB" doctor 2>&1)
assert_contains "$output" "[WARN]" "doctor warns on semantic drift signals"

# Restore
printf -- "---\nauthority: volatile\nlast-reviewed: %s\nstaleness-threshold: 7d\n---\n# Active Context\nTest.\n" \
  "$(date +%Y-%m-%d)" > "$TMPDIR_DOC/memory-bank/activeContext.md"

# ── Check 18: Old stable-authority decision ────────────────────────────────────
echo ""
echo "--- check 18: stable file reviewed >180 days ago ---"

printf -- "---\nauthority: stable\nlast-reviewed: 2020-01-01\nstaleness-threshold: 180d\n---\n# System Patterns\nTest.\n" \
  > "$TMPDIR_DOC/memory-bank/systemPatterns.md"
output=$(cd "$TMPDIR_DOC" && MB_HOME="$REPO_ROOT" bash "$MB" doctor 2>&1)
assert_contains "$output" "[WARN]" "doctor warns when stable file not reviewed in 180+ days"

# Restore
printf -- "---\nauthority: stable\nlast-reviewed: %s\nstaleness-threshold: 90d\n---\n# System Patterns\nTest.\n" \
  "$(date +%Y-%m-%d)" > "$TMPDIR_DOC/memory-bank/systemPatterns.md"

# ── Check 19: Authority mismatch ──────────────────────────────────────────────
echo ""
echo "--- check 19: wrong authority on projectbrief.md ---"

sed -i.bak 's/authority: .*/authority: volatile/' "$TMPDIR_DOC/memory-bank/projectbrief.md"
rm -f "$TMPDIR_DOC/memory-bank/projectbrief.md.bak"
output=$(cd "$TMPDIR_DOC" && MB_HOME="$REPO_ROOT" bash "$MB" doctor 2>&1)
assert_contains "$output" "[WARN]" "doctor warns on authority mismatch in projectbrief.md"

# Restore
sed -i.bak 's/authority: volatile/authority: immutable/' "$TMPDIR_DOC/memory-bank/projectbrief.md"
rm -f "$TMPDIR_DOC/memory-bank/projectbrief.md.bak"

# ── Check 20: Checksum mismatch ───────────────────────────────────────────────
echo ""
echo "--- check 20: checksum mismatch after external edit ---"

(cd "$TMPDIR_DOC" && MB_HOME="$REPO_ROOT" bash "$MB" verify-integrity > /dev/null 2>&1)
echo "# external edit" >> "$TMPDIR_DOC/memory-bank/techContext.md"
output=$(cd "$TMPDIR_DOC" && MB_HOME="$REPO_ROOT" bash "$MB" doctor 2>&1)
assert_contains "$output" "[WARN]" "doctor warns on integrity checksum mismatch"

# Restore techContext
printf -- "---\nauthority: stable\nlast-reviewed: %s\nstaleness-threshold: 90d\n---\n# Tech Context\nTest.\n" \
  "$(date +%Y-%m-%d)" > "$TMPDIR_DOC/memory-bank/techContext.md"
rm -f "$TMPDIR_DOC/.pmb-checksums"

# ── Check 21: git-vs-reviewed lag ─────────────────────────────────────────────
echo ""
echo "--- check 21: git-vs-reviewed lag ---"

printf -- "---\nauthority: stable\nlast-reviewed: 2020-01-01\nstaleness-threshold: 90d\n---\n# Tech Context\nCommitted with old date.\n" \
  > "$TMPDIR_DOC/memory-bank/techContext.md"
(cd "$TMPDIR_DOC" && git add memory-bank/techContext.md && git commit -q -m "commit with stale last-reviewed")
output=$(cd "$TMPDIR_DOC" && MB_HOME="$REPO_ROOT" bash "$MB" doctor 2>&1)
assert_contains "$output" "[WARN]" "doctor warns when last-reviewed precedes last git commit"

# Restore
printf -- "---\nauthority: stable\nlast-reviewed: %s\nstaleness-threshold: 90d\n---\n# Tech Context\nTest.\n" \
  "$(date +%Y-%m-%d)" > "$TMPDIR_DOC/memory-bank/techContext.md"

# ── Check 22: Completed-but-still-planned ─────────────────────────────────────
echo ""
echo "--- check 22: item completed in progress but still planned elsewhere ---"

echo "- ✅ Fix critical bug X" >> "$TMPDIR_DOC/memory-bank/progress.md"
echo "- ⏸ Fix critical bug X" >> "$TMPDIR_DOC/memory-bank/activeContext.md"
output=$(cd "$TMPDIR_DOC" && MB_HOME="$REPO_ROOT" bash "$MB" doctor 2>&1)
assert_contains "$output" "[WARN]" "doctor warns on completed-but-still-planned item"

# Restore
printf -- "---\nauthority: volatile\nlast-reviewed: %s\nstaleness-threshold: 7d\n---\n# Active Context\nTest.\n" \
  "$(date +%Y-%m-%d)" > "$TMPDIR_DOC/memory-bank/activeContext.md"
printf -- "---\nauthority: accumulating\nlast-reviewed: %s\nstaleness-threshold: 90d\n---\n# Progress\nTest.\n" \
  "$(date +%Y-%m-%d)" > "$TMPDIR_DOC/memory-bank/progress.md"

# ── Check 23: Stale next step ─────────────────────────────────────────────────
echo ""
echo "--- check 23: stale next step already completed in progress.md ---"

cat >> "$TMPDIR_DOC/memory-bank/progress.md" << 'EOF'

## Done
- ✅ Deploy new dashboard
EOF
cat >> "$TMPDIR_DOC/memory-bank/activeContext.md" << 'EOF'

## Next Steps
- Deploy new dashboard
EOF
output=$(cd "$TMPDIR_DOC" && MB_HOME="$REPO_ROOT" bash "$MB" doctor 2>&1)
assert_contains "$output" "[WARN]" "doctor warns on stale next step already completed"

# Restore
printf -- "---\nauthority: volatile\nlast-reviewed: %s\nstaleness-threshold: 7d\n---\n# Active Context\nTest.\n" \
  "$(date +%Y-%m-%d)" > "$TMPDIR_DOC/memory-bank/activeContext.md"
printf -- "---\nauthority: accumulating\nlast-reviewed: %s\nstaleness-threshold: 90d\n---\n# Progress\nTest.\n" \
  "$(date +%Y-%m-%d)" > "$TMPDIR_DOC/memory-bank/progress.md"

# ── Check 24: Plan hygiene — missing docs/plans ───────────────────────────────
echo ""
echo "--- check 24: missing docs/plans dir ---"

rm -rf "$TMPDIR_DOC/docs/plans"
output=$(cd "$TMPDIR_DOC" && MB_HOME="$REPO_ROOT" bash "$MB" doctor 2>&1)
assert_contains "$output" "[WARN]" "doctor warns when docs/plans/ dir missing"

print_summary
```

- [ ] **Step 2: Run the test**

```bash
cd "C:\Users\Mizzo\Claude\Personal-Memory-Bank"
bash tests/test-mb-doctor.sh
```

Expected: all 25 assertions pass.

- [ ] **Step 3: Run the full suite**

```bash
bash tests/run.sh
```

Expected: all suites pass. Final line: `All test suites passed.`

- [ ] **Step 4: Commit**

```bash
git add tests/test-mb-doctor.sh
git commit -m "test: add mb doctor tests — all 24 checks + clean baseline (25 cases)"
```

---

## Final Verification

After all 9 tasks:

```bash
cd "C:\Users\Mizzo\Claude\Personal-Memory-Bank"
bash tests/run.sh
```

Expected output ends with:
```
════════════════════════════════════
All test suites passed.
════════════════════════════════════
```

Total test count should increase from 33 to ~86 (33 existing + ~53 new).
