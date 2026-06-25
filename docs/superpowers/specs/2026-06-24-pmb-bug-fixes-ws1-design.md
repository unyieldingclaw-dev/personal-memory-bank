---
status: approved
created: 2026-06-24
approved: 2026-06-24
related_spec: null
scope: local
risk: low
source: ai-draft
---

# PMB Bug Fixes — Workstream 1

## Context

Full-project audit on 2026-06-24 identified three confirmed bugs:
1. `settings.json` is invalid JSON — missing comma breaks strict parsers
2. `pre-compact-check` date matching uses free substring search — false positives from embedded dates in content
3. `dangerous-commands` scripts are missing `TRUNCATE TABLE` and `DELETE FROM` — both are destructive SQL operations listed as CONFIRM-tier in SECURITY-GUARDRAILS.md

All three are surgical fixes. No new features. No architecture changes.

---

## Fix 1: settings.json — missing comma (B1)

**File:** `.claude/settings.json`

**Problem:** Line 88 is missing a trailing comma. Python's `json` module hard-fails; other JSON parsers may too.

```json
// BEFORE (lines 87–89)
"Bash(python -m ruff *)"
"Bash(bash tests/*.sh)"

// AFTER
"Bash(python -m ruff *)",
"Bash(bash tests/*.sh)"
```

**Verification:** `python3 -c "import json; json.load(open('.claude/settings.json'))" && echo valid`

---

## Fix 2: pre-compact-check — anchor date to line start (B3)

**Files:** `scripts/pre-compact-check.sh`, `scripts/pre-compact-check.ps1`,
`templates/scripts/pre-compact-check.sh`, `templates/scripts/pre-compact-check.ps1`

**Problem:** Both scripts match `$today` anywhere in `progress.md`. A line like
`"see spec from 2026-06-24"` triggers a false positive, allowing compaction when no
actual progress entry was written today.

**Fix:** Require the date to appear at the start of a line, optionally preceded by a
markdown heading marker (`#`) or list prefix (`- `). This covers all real progress
entry formats without matching embedded dates in prose.

### sh fix

```sh
# BEFORE (pre-compact-check.sh line 50)
if ! grep -q "$today" "$PROGRESS_FILE" 2>/dev/null; then

# AFTER
if ! grep -qE "(^|^#+ |^- )${today}" "$PROGRESS_FILE" 2>/dev/null; then
```

### ps1 fix

```powershell
# BEFORE (pre-compact-check.ps1 line 51)
if ($content -notmatch [regex]::Escape($today)) {

# AFTER — reuse existing $content variable, split by line, require date at line start
$hasEntry = ($content -split "`n") | Where-Object { $_ -match "^(#{1,6} |- )?$([regex]::Escape($today))" }
if (-not $hasEntry) {
```

Apply the identical fix to the `templates/scripts/` copies.

---

## Fix 3: dangerous-commands — add TRUNCATE TABLE and DELETE FROM (B4)

**Files:** `scripts/dangerous-commands.sh`, `scripts/dangerous-commands.ps1`,
`templates/scripts/dangerous-commands.sh`, `templates/scripts/dangerous-commands.ps1`

**Problem:** `TRUNCATE TABLE` and `DELETE FROM` are listed as CONFIRM-tier in
`standards/SECURITY-GUARDRAILS.md` but are absent from both scripts.

**Tier justification:**
- `TRUNCATE TABLE` — removes all rows, bypasses transaction logs in many engines → CONFIRM
- `DELETE FROM` — removes rows, potentially without a WHERE clause → CONFIRM
  (not BLOCK because intentional bulk deletes with WHERE are common)

### sh additions

Add after the existing SQL block patterns (after line 64, before the `| bash` block):

```sh
confirm "TRUNCATE TABLE"   "SQL table truncation"              # WHY: deletes all rows, not easily reversed in many engines
confirm "truncate table"   "SQL table truncation (lowercase)"  # WHY: parity with ps1 OrdinalIgnoreCase
confirm "DELETE FROM"      "SQL delete rows"                   # WHY: can delete data without a WHERE clause
confirm "delete from"      "SQL delete rows (lowercase)"       # WHY: parity with ps1 OrdinalIgnoreCase
```

### ps1 additions

Add to `$confirmPatterns` array after the existing entries:

```powershell
@{ pattern = "TRUNCATE TABLE"; reason = "SQL table truncation"  }  # WHY: deletes all rows, not easily reversed in many engines
@{ pattern = "DELETE FROM";    reason = "SQL delete rows"        }  # WHY: can delete data without a WHERE clause
```

(PowerShell matching is case-insensitive by default — one variant covers both cases.)

Apply the identical additions to the `templates/scripts/` copies.

---

## Files Modified

| File | Change |
|---|---|
| `.claude/settings.json` | Add missing comma after `"Bash(python -m ruff *)"` |
| `scripts/pre-compact-check.sh` | Anchor date grep to line start |
| `scripts/pre-compact-check.ps1` | Anchor date regex to line start |
| `templates/scripts/pre-compact-check.sh` | Same |
| `templates/scripts/pre-compact-check.ps1` | Same |
| `scripts/dangerous-commands.sh` | Add TRUNCATE TABLE + DELETE FROM confirm patterns |
| `scripts/dangerous-commands.ps1` | Add TRUNCATE TABLE + DELETE FROM confirm patterns |
| `templates/scripts/dangerous-commands.sh` | Same |
| `templates/scripts/dangerous-commands.ps1` | Same |

**Total: 9 files, ~15 lines changed.**

---

## Verification

```bash
# B1 — settings.json is valid JSON
python3 -c "import json; json.load(open('.claude/settings.json'))" && echo valid

# B3 — pre-compact false positive gone: a line with embedded date should NOT match
echo "see spec from $(date +%Y-%m-%d) for context" > /tmp/test-progress.md
today=$(date +%Y-%m-%d)
grep -qE "(^|^#+ |^- )${today}" /tmp/test-progress.md && echo "MATCH (bad)" || echo "no match (correct)"

# B3 — real entry at line start should still match
echo "$(date +%Y-%m-%d): completed fix" > /tmp/test-progress.md
grep -qE "(^|^#+ |^- )${today}" /tmp/test-progress.md && echo "match (correct)" || echo "no match (bad)"

# B4 — new patterns present in both scripts
grep -i "TRUNCATE TABLE" scripts/dangerous-commands.sh scripts/dangerous-commands.ps1
grep -i "DELETE FROM" scripts/dangerous-commands.sh scripts/dangerous-commands.ps1

# Full bash test suite still passes
bash tests/run.sh
```
