# PMB Bug Fixes — Workstream 1 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Fix three confirmed bugs — invalid JSON in settings.json, pre-compact date false positives, and missing TRUNCATE/DELETE FROM guardrails — across 9 files.

**Architecture:** All changes are surgical edits to existing files. No new files. Each fix is independent and can be committed separately. Template copies must always be updated alongside the live scripts (TEMPLATE_OWNED distribution model means `mb upgrade` pushes templates to target projects).

**Tech Stack:** POSIX sh, PowerShell 7 (pwsh), JSON. Repo: `C:\Users\Mizzo\Claude\Personal-Memory-Bank`

---

## File Map

| File | Change |
|---|---|
| `.claude/settings.json` | Add missing comma on line 88 |
| `scripts/pre-compact-check.sh` | Anchor date grep to line start (line 50) |
| `scripts/pre-compact-check.ps1` | Anchor date regex to line start (line 51) |
| `templates/scripts/pre-compact-check.sh` | Same as scripts/ copy |
| `templates/scripts/pre-compact-check.ps1` | Same as scripts/ copy |
| `scripts/dangerous-commands.sh` | Add TRUNCATE TABLE + DELETE FROM after line 75 |
| `scripts/dangerous-commands.ps1` | Add TRUNCATE TABLE + DELETE FROM to $confirmPatterns (after line 67) |
| `templates/scripts/dangerous-commands.sh` | Same as scripts/ copy |
| `templates/scripts/dangerous-commands.ps1` | Same as scripts/ copy |

---

## Task 1: Fix settings.json invalid JSON (B1)

**Files:**
- Modify: `.claude/settings.json:88`

- [ ] **Step 1: Confirm the JSON is currently invalid**

```bash
cd "C:\Users\Mizzo\Claude\Personal-Memory-Bank"
python3 -c "import json; json.load(open('.claude/settings.json'))" 2>&1
```

Expected: `JSONDecodeError: Expecting ',' delimiter: line 89`

- [ ] **Step 2: Add the missing comma**

In `.claude/settings.json`, line 88 currently reads:
```json
      "Bash(python -m ruff *)"
```

Change it to:
```json
      "Bash(python -m ruff *)",
```

The surrounding context for orientation (lines 86–90):
```json
      "Bash(python -m pytest *)",
      "Bash(python -m mypy *)",
      "Bash(python -m ruff *)",
      "Bash(bash tests/*.sh)"
    ]
```

- [ ] **Step 3: Verify JSON is now valid**

```bash
cd "C:\Users\Mizzo\Claude\Personal-Memory-Bank"
python3 -c "import json; json.load(open('.claude/settings.json')); print('valid')"
```

Expected output: `valid`

- [ ] **Step 4: Commit**

```bash
cd "C:\Users\Mizzo\Claude\Personal-Memory-Bank"
git add .claude/settings.json
git commit -m "fix: add missing comma in settings.json permissions array (invalid JSON)"
```

---

## Task 2: Anchor pre-compact date check to line start (B3)

**Files:**
- Modify: `scripts/pre-compact-check.sh:50`
- Modify: `scripts/pre-compact-check.ps1:51`
- Modify: `templates/scripts/pre-compact-check.sh:50`
- Modify: `templates/scripts/pre-compact-check.ps1:51`

**Background:** The current check does `grep -q "$today" progress.md` which matches the date string *anywhere* in the file — including prose like "see spec from 2026-06-24". The fix requires the date to appear at the *start* of a line, optionally preceded by markdown heading markers (`## `) or list prefix (`- `). This matches all real progress entry formats while rejecting embedded dates in sentences.

- [ ] **Step 1: Fix `scripts/pre-compact-check.sh` line 50**

Find this block (lines 47–55):
```sh
# Check 2: progress.md — must contain at least one entry dated today
PROGRESS_FILE="memory-bank/progress.md"
if [ -f "$PROGRESS_FILE" ]; then
    if ! grep -q "$today" "$PROGRESS_FILE" 2>/dev/null; then
        BLOCK_REASONS+=("progress.md has no entry dated $today — add today's progress before compacting")
    fi
else
    BLOCK_REASONS+=("progress.md missing — run 'mb init'")
fi
```

Replace line 50 only — change the `grep` call:
```sh
# Check 2: progress.md — must contain at least one entry dated today
PROGRESS_FILE="memory-bank/progress.md"
if [ -f "$PROGRESS_FILE" ]; then
    if ! grep -qE "(^|^#+ |^- )${today}" "$PROGRESS_FILE" 2>/dev/null; then
        BLOCK_REASONS+=("progress.md has no entry dated $today — add today's progress before compacting")
    fi
else
    BLOCK_REASONS+=("progress.md missing — run 'mb init'")
fi
```

- [ ] **Step 2: Fix `scripts/pre-compact-check.ps1` lines 50–53**

Find this block (lines 47–56):
```powershell
    # Check 2: progress.md — must contain at least one entry dated today
    $progressFile = "memory-bank/progress.md"
    if (Test-Path $progressFile) {
        $content = Get-Content $progressFile -Raw
        if ($content -notmatch [regex]::Escape($today)) {
            $blockReasons += "progress.md has no entry dated $today — add today's progress before compacting"
        }
    } else {
        $blockReasons += "progress.md missing — run 'mb init'"
    }
```

Replace lines 50–53 (keep the surrounding `if` structure):
```powershell
    # Check 2: progress.md — must contain at least one entry dated today
    $progressFile = "memory-bank/progress.md"
    if (Test-Path $progressFile) {
        $content = Get-Content $progressFile -Raw
        $hasEntry = ($content -split "`n") | Where-Object { $_ -match "^(#{1,6} |- )?$([regex]::Escape($today))" }
        if (-not $hasEntry) {
            $blockReasons += "progress.md has no entry dated $today — add today's progress before compacting"
        }
    } else {
        $blockReasons += "progress.md missing — run 'mb init'"
    }
```

- [ ] **Step 3: Apply the same changes to the template copies**

`templates/scripts/pre-compact-check.sh` — apply the identical line 50 change from Step 1.

`templates/scripts/pre-compact-check.ps1` — apply the identical lines 50–53 change from Step 2.

Verify the templates match the scripts exactly:
```bash
cd "C:\Users\Mizzo\Claude\Personal-Memory-Bank"
diff scripts/pre-compact-check.sh templates/scripts/pre-compact-check.sh
diff scripts/pre-compact-check.ps1 templates/scripts/pre-compact-check.ps1
```

Expected: no output (files are identical).

- [ ] **Step 4: Manually verify the sh fix logic**

```bash
cd "C:\Users\Mizzo\Claude\Personal-Memory-Bank"
today=$(date +%Y-%m-%d)

# FALSE POSITIVE test — embedded date in prose should NOT match
echo "see spec from ${today} for context" > /tmp/test-progress.md
grep -qE "(^|^#+ |^- )${today}" /tmp/test-progress.md \
  && echo "FAIL: matched embedded date" || echo "PASS: no match for embedded date"

# TRUE POSITIVE tests — real entry formats SHOULD match
printf "## %s\n" "$today" > /tmp/test-progress.md
grep -qE "(^|^#+ |^- )${today}" /tmp/test-progress.md \
  && echo "PASS: matched heading entry" || echo "FAIL: did not match heading entry"

printf "- %s: did work\n" "$today" > /tmp/test-progress.md
grep -qE "(^|^#+ |^- )${today}" /tmp/test-progress.md \
  && echo "PASS: matched list entry" || echo "FAIL: did not match list entry"

printf "%s: did work\n" "$today" > /tmp/test-progress.md
grep -qE "(^|^#+ |^- )${today}" /tmp/test-progress.md \
  && echo "PASS: matched bare date entry" || echo "FAIL: did not match bare date entry"

rm /tmp/test-progress.md
```

Expected output:
```
PASS: no match for embedded date
PASS: matched heading entry
PASS: matched list entry
PASS: matched bare date entry
```

- [ ] **Step 5: Run bash test suite**

```bash
cd "C:\Users\Mizzo\Claude\Personal-Memory-Bank"
bash tests/run.sh
```

Expected: all tests pass.

- [ ] **Step 6: Commit**

```bash
cd "C:\Users\Mizzo\Claude\Personal-Memory-Bank"
git add scripts/pre-compact-check.sh scripts/pre-compact-check.ps1
git add templates/scripts/pre-compact-check.sh templates/scripts/pre-compact-check.ps1
git commit -m "fix: anchor pre-compact date check to line start — prevents false positives from embedded dates"
```

---

## Task 3: Add TRUNCATE TABLE and DELETE FROM to dangerous-commands (B4)

**Files:**
- Modify: `scripts/dangerous-commands.sh:75` (after the `--no-verify` confirm entry)
- Modify: `scripts/dangerous-commands.ps1:67` (after the `--no-verify` entry in `$confirmPatterns`)
- Modify: `templates/scripts/dangerous-commands.sh:75`
- Modify: `templates/scripts/dangerous-commands.ps1:67`

**Background:** `SECURITY-GUARDRAILS.md` lists `DELETE`/`TRUNCATE` as CONFIRM-tier. Both scripts are missing these patterns entirely. CONFIRM (not BLOCK) because intentional bulk deletes with WHERE clauses are common in legitimate workflows. PowerShell's `Contains(..., OrdinalIgnoreCase)` is case-insensitive so only one variant is needed per pattern; bash `case` is case-sensitive so both cases need explicit entries.

- [ ] **Step 1: Add patterns to `scripts/dangerous-commands.sh`**

After line 75 (`confirm "--no-verify" ...`), before the blank line that precedes `# WARN:`:

```sh
confirm "TRUNCATE TABLE"   "SQL table truncation"              # WHY: deletes all rows, not easily reversed in many engines
confirm "truncate table"   "SQL table truncation (lowercase)"  # WHY: parity with ps1 OrdinalIgnoreCase — catches lowercase SQL
confirm "DELETE FROM"      "SQL delete rows"                   # WHY: can delete data without a WHERE clause
confirm "delete from"      "SQL delete rows (lowercase)"       # WHY: parity with ps1 OrdinalIgnoreCase — catches lowercase SQL
```

The surrounding context for orientation (lines 70–83 after edit):
```sh
# CONFIRM: advanced ops with legitimate uses — require explicit manual invocation
confirm "git filter-branch" "history rewriting"
confirm "git update-ref"    "low-level ref manipulation"
confirm "sudo rm"           "privileged deletion"
confirm "chmod -R 777"      "world-writable recursive chmod"
confirm "--no-verify"       "bypasses pre-commit hooks (local governance)"
confirm "TRUNCATE TABLE"   "SQL table truncation"
confirm "truncate table"   "SQL table truncation (lowercase)"
confirm "DELETE FROM"      "SQL delete rows"
confirm "delete from"      "SQL delete rows (lowercase)"

# WARN: credential/secrets access — legitimate workflows exist, surface the access only
```

- [ ] **Step 2: Add patterns to `scripts/dangerous-commands.ps1`**

After line 67 (`@{ pattern = "--no-verify"; ... }`), before the closing `)` of `$confirmPatterns`:

```powershell
    @{ pattern = "TRUNCATE TABLE"; reason = "SQL table truncation"  }  # WHY: deletes all rows, not easily reversed in many engines
    @{ pattern = "DELETE FROM";    reason = "SQL delete rows"        }  # WHY: can delete data without a WHERE clause
```

The surrounding context for orientation (lines 62–68 after edit):
```powershell
$confirmPatterns = @(
    @{ pattern = "git filter-branch"; reason = "history rewriting" }
    @{ pattern = "git update-ref";    reason = "low-level ref manipulation" }
    @{ pattern = "sudo rm";           reason = "privileged deletion" }
    @{ pattern = "chmod -R 777";      reason = "world-writable recursive chmod" }
    @{ pattern = "--no-verify";       reason = "bypasses pre-commit hooks (local governance)" }
    @{ pattern = "TRUNCATE TABLE"; reason = "SQL table truncation"  }
    @{ pattern = "DELETE FROM";    reason = "SQL delete rows"        }
)
```

- [ ] **Step 3: Apply the same changes to the template copies**

`templates/scripts/dangerous-commands.sh` — apply the identical additions from Step 1.

`templates/scripts/dangerous-commands.ps1` — apply the identical additions from Step 2.

Verify templates match scripts:
```bash
cd "C:\Users\Mizzo\Claude\Personal-Memory-Bank"
diff scripts/dangerous-commands.sh templates/scripts/dangerous-commands.sh
diff scripts/dangerous-commands.ps1 templates/scripts/dangerous-commands.ps1
```

Expected: no output.

- [ ] **Step 4: Verify new patterns present in all 4 files**

```bash
cd "C:\Users\Mizzo\Claude\Personal-Memory-Bank"
grep -i "TRUNCATE TABLE" scripts/dangerous-commands.sh scripts/dangerous-commands.ps1 \
  templates/scripts/dangerous-commands.sh templates/scripts/dangerous-commands.ps1
grep -i "DELETE FROM" scripts/dangerous-commands.sh scripts/dangerous-commands.ps1 \
  templates/scripts/dangerous-commands.sh templates/scripts/dangerous-commands.ps1
```

Expected: 6 lines per pattern — 2 per .sh file (uppercase + lowercase variants) and 1 per .ps1 file (case-insensitive so only one entry needed).

- [ ] **Step 5: Run bash test suite**

```bash
cd "C:\Users\Mizzo\Claude\Personal-Memory-Bank"
bash tests/run.sh
```

Expected: all tests pass.

- [ ] **Step 6: Commit**

```bash
cd "C:\Users\Mizzo\Claude\Personal-Memory-Bank"
git add scripts/dangerous-commands.sh scripts/dangerous-commands.ps1
git add templates/scripts/dangerous-commands.sh templates/scripts/dangerous-commands.ps1
git commit -m "fix: add TRUNCATE TABLE and DELETE FROM to CONFIRM-tier guardrails (missing from both shells)"
```

---

## Final Verification

After all 3 tasks are committed:

```bash
cd "C:\Users\Mizzo\Claude\Personal-Memory-Bank"

# 1. settings.json is valid JSON
python3 -c "import json; json.load(open('.claude/settings.json')); print('settings.json: valid')"

# 2. New SQL patterns present in all 4 dangerous-commands files
grep -c "TRUNCATE TABLE\|DELETE FROM" \
  scripts/dangerous-commands.sh \
  scripts/dangerous-commands.ps1 \
  templates/scripts/dangerous-commands.sh \
  templates/scripts/dangerous-commands.ps1

# 3. Template copies match live scripts
diff scripts/pre-compact-check.sh templates/scripts/pre-compact-check.sh && echo "pre-compact sh: in sync"
diff scripts/pre-compact-check.ps1 templates/scripts/pre-compact-check.ps1 && echo "pre-compact ps1: in sync"
diff scripts/dangerous-commands.sh templates/scripts/dangerous-commands.sh && echo "dangerous-commands sh: in sync"
diff scripts/dangerous-commands.ps1 templates/scripts/dangerous-commands.ps1 && echo "dangerous-commands ps1: in sync"

# 4. Test suite still passes
bash tests/run.sh
```
