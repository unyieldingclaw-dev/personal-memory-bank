# PMB Performance + Docs Cleanup — Workstream 4 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Apply 5 small independent improvements — O(n²) normalization fix, find-pipe optimization, stale check count in docs, undocumented runtime file, and mb help deprecated alias section.

**Architecture:** All changes are surgical edits to existing files. Each task is fully independent and produces its own commit. No new files created. No tests modified (existing suite stays green throughout).

**Tech Stack:** POSIX sh, PowerShell 7, Markdown. Repo: `C:\Users\Mizzo\Claude\Personal-Memory-Bank`

---

## File Map

| File | Task |
|---|---|
| `scripts/mb.sh` | Task 1 (O(n²) fix, find pipe, help aliases) |
| `scripts/mb.ps1` | Task 1 (O(n²) ps1 port, help aliases) |
| `.claude/commands/health-check.md` | Task 2 (20→24 check count) |
| `docs/HOOKS-GUIDE.md` | Task 3 (.pmb-delegation-depth docs) |

---

## Task 1: Performance + mb help (scripts/mb.sh and scripts/mb.ps1)

**Files:**
- Modify: `scripts/mb.sh` — O(n²) checks 22 & 23, find pipe x2, help aliases
- Modify: `scripts/mb.ps1` — O(n²) checks 22 & 23, help aliases

This task groups all `scripts/` changes together so they can be verified and committed atomically.

### Part A: Pre-cache fix for check 22 in mb.sh

- [ ] **Step 1: Locate the check 22 section in mb.sh**

Run:
```bash
grep -n "_mb_normalize\|C22_FOUND\|PLANNED_CACHE\|Completed-but" scripts/mb.sh | head -10
```

Check 22 starts around line 1037 with `_mb_normalize()` definition, then the outer loop at line 1044.

- [ ] **Step 2: Add pre-built planned cache before the check 22 outer loop**

Insert these lines immediately before the `C22_FOUND=false` line (around line 1041), after the `_mb_normalize()` function definition closes:

```sh
    # Pre-normalize all ⏸ lines once — avoids O(n²) subprocess spawning in inner loop
    _PLANNED_CACHE=()
    _PLANNED_FILES=()
    for _pf in projectbrief.md systemPatterns.md techContext.md activeContext.md progress.md; do
        _pp="memory-bank/$_pf"
        [ ! -f "$_pp" ] && continue
        while IFS= read -r _pl; do
            _PLANNED_CACHE+=("$(_mb_normalize "$_pl")")
            _PLANNED_FILES+=("$_pf")
        done < <(grep '⏸' "$_pp" 2>/dev/null)
    done
```

- [ ] **Step 3: Replace the inner file-reading loop in check 22 with an array scan**

The current inner loop (inside the `for ((i=0; ...))` block) looks like:

```sh
                for pf in projectbrief.md systemPatterns.md techContext.md activeContext.md progress.md; do
                    pp="memory-bank/$pf"
                    [ ! -f "$pp" ] && continue
                    while IFS= read -r planned_line; do
                        planned_norm=$(_mb_normalize "$planned_line")
                        if echo "$planned_norm" | grep -qF "$window"; then
                            echo -e "${YELLOW}[WARN] Drift: \"$window\" marked ✅ in progress.md but ⏸ in $pf${NC}"
                            echo "       One of these is stale — resolve before next compaction."
                            C22_FOUND=true
                            DRIFT_FOUND=true
                            matched=true
                            break 2
                        fi
                    done < <(grep '⏸' "$pp" 2>/dev/null)
                done
```

Replace it with:

```sh
                for _ci in "${!_PLANNED_CACHE[@]}"; do
                    if echo "${_PLANNED_CACHE[$_ci]}" | grep -qF "$window"; then
                        echo -e "${YELLOW}[WARN] Drift: \"$window\" marked ✅ in progress.md but ⏸ in ${_PLANNED_FILES[$_ci]}${NC}"
                        echo "       One of these is stale — resolve before next compaction."
                        C22_FOUND=true
                        DRIFT_FOUND=true
                        matched=true
                        break 2
                    fi
                done
```

### Part B: Pre-cache fix for check 23 in mb.sh

- [ ] **Step 4: Add pre-built done-lines cache before the check 23 outer loop**

Check 23 starts around line 1073 with `AC_FILE` and `C23_FOUND=false`. Insert these lines immediately before `C23_FOUND=false`:

```sh
    # Pre-normalize all ✅ lines from progress.md once — avoids O(n²) subprocess spawning
    _DONE_CACHE=()
    if [ -f "$PROGRESS_FILE" ]; then
        while IFS= read -r _dl; do
            _DONE_CACHE+=("$(_mb_normalize "$_dl")")
        done < <(grep '✅' "$PROGRESS_FILE" 2>/dev/null)
    fi
```

- [ ] **Step 5: Replace the inner done-line loop in check 23 with an array scan**

The current inner loop (inside the `for ((j=0; ...))` block):

```sh
                    while IFS= read -r done_line; do
                        done_norm=$(_mb_normalize "$done_line")
                        if echo "$done_norm" | grep -qF "$swindow"; then
                            trimmed_step=$(echo "$line" | sed 's/^[[:space:]]*//')
                            echo -e "${YELLOW}[WARN] Drift: Next Step appears completed — \"$trimmed_step\"${NC}"
                            echo "       Remove from activeContext.md Next Steps or verify the progress entry."
                            C23_FOUND=true
                            DRIFT_FOUND=true
                            matched_step=true
                            break
                        fi
                    done < <(grep '✅' "$PROGRESS_FILE" 2>/dev/null)
```

Replace with:

```sh
                    for _di in "${!_DONE_CACHE[@]}"; do
                        if echo "${_DONE_CACHE[$_di]}" | grep -qF "$swindow"; then
                            trimmed_step=$(echo "$line" | sed 's/^[[:space:]]*//')
                            echo -e "${YELLOW}[WARN] Drift: Next Step appears completed — \"$trimmed_step\"${NC}"
                            echo "       Remove from activeContext.md Next Steps or verify the progress entry."
                            C23_FOUND=true
                            DRIFT_FOUND=true
                            matched_step=true
                            break
                        fi
                    done
```

### Part C: Fix find pipe in mb.sh (x2 locations)

- [ ] **Step 6: Fix line 1258 in show_budget**

Current (line 1258):
```sh
        MB_BYTES=$(find "$MEMORY_BANK_PATH" -maxdepth 1 -type f | xargs wc -c 2>/dev/null | tail -1 | awk '{print $1}' || echo "0")
```

Replace with:
```sh
        MB_BYTES=$(find "$MEMORY_BANK_PATH" -maxdepth 1 -type f -exec wc -c {} + 2>/dev/null | tail -1 | awk '{print $1}' || echo "0")
```

- [ ] **Step 7: Fix line 1423 in show_query**

Current (line 1423):
```sh
        TOTAL_BYTES=$(find "$MEMORY_BANK_PATH" -maxdepth 1 -type f | xargs wc -c 2>/dev/null | tail -1 | awk '{print $1}' || echo "0")
```

Replace with:
```sh
        TOTAL_BYTES=$(find "$MEMORY_BANK_PATH" -maxdepth 1 -type f -exec wc -c {} + 2>/dev/null | tail -1 | awk '{print $1}' || echo "0")
```

### Part D: Add deprecated aliases to mb help in mb.sh

- [ ] **Step 8: Add deprecated section to show_help in mb.sh**

The current `show_help` function ends with:
```sh
    echo "  mb clean              Get maintenance prompt for memory bank cleanup"
    echo ""
}
```

Replace that closing block with:
```sh
    echo "  mb clean              Get maintenance prompt for memory bank cleanup"
    echo ""
    echo "Deprecated aliases (redirect to current commands):"
    echo "  validate, audit  → mb doctor"
    echo "  update           → mb upgrade"
    echo "  compact, slim, archive, budget  → mb clean"
    echo "  install-hooks    → mb upgrade"
    echo ""
}
```

### Part E: O(n²) fix in mb.ps1 (check 22)

- [ ] **Step 9: Add NormText to planned items in mb.ps1 check 22**

In `scripts/mb.ps1`, check 22 builds `$plannedItems` around line 1218. The planned items object currently stores `Text` and `File` and `Line`. Add `NormText` at build time:

Current line inside the for loop (around line 1225):
```powershell
                $plannedItems += [pscustomobject]@{ Text = $fLines[$i]; File = $f; Line = $i + 1 }
```

Replace with:
```powershell
                $plannedItems += [pscustomobject]@{ Text = $fLines[$i]; NormText = (Normalize-MbLine $fLines[$i]); File = $f; Line = $i + 1 }
```

Then in the inner foreach loop (around line 1238):

Current:
```powershell
                $pNorm = Normalize-MbLine $planned.Text
                if ($pNorm.Contains($window)) {
```

Replace with:
```powershell
                if ($planned.NormText.Contains($window)) {
```

### Part F: O(n²) fix in mb.ps1 (check 23)

- [ ] **Step 10: Pre-build completedNorms for check 23 in mb.ps1**

Before the `foreach ($step in $nextStepLines)` loop (around line 1271), add:

```powershell
    # Pre-normalize completed lines once to avoid O(n²) Normalize-MbLine calls
    $completedNorms = $completedLines | ForEach-Object { Normalize-MbLine $_ }
```

Then in the inner loop (around line 1278), replace:

```powershell
            foreach ($doneLine in $completedLines) {
                $doneNorm = Normalize-MbLine $doneLine
                if ($doneNorm.Contains($window)) {
```

With:

```powershell
            foreach ($doneNorm in $completedNorms) {
                if ($doneNorm.Contains($window)) {
```

### Part G: Add deprecated aliases to mb.ps1 Show-Help

- [ ] **Step 11: Add deprecated section to Show-Help in mb.ps1**

The current `Show-Help` function ends with:
```powershell
    Write-Host "  mb clean              Get maintenance prompt for memory bank cleanup"
    Write-Host ""
}
```

Replace with:
```powershell
    Write-Host "  mb clean              Get maintenance prompt for memory bank cleanup"
    Write-Host ""
    Write-Host "Deprecated aliases (redirect to current commands):"
    Write-Host "  validate, audit  -> mb doctor"
    Write-Host "  update           -> mb upgrade"
    Write-Host "  compact, slim, archive, budget  -> mb clean"
    Write-Host "  install-hooks    -> mb upgrade"
    Write-Host ""
}
```

### Verification and commit

- [ ] **Step 12: Verify mb.sh runs without errors**

```bash
cd "C:\Users\Mizzo\Claude\Personal-Memory-Bank"
bash scripts/mb.sh help 2>&1 | grep -i "deprecated"
```

Expected: shows the deprecated aliases section.

```bash
bash scripts/mb.sh help 2>&1 | grep "xargs"
```

Expected: no output (xargs removed).

- [ ] **Step 13: Run the full test suite**

```bash
bash tests/run.sh 2>&1 | tail -4
```

Expected: `All test suites passed.`

- [ ] **Step 14: Commit**

```bash
cd "C:\Users\Mizzo\Claude\Personal-Memory-Bank"
git add scripts/mb.sh scripts/mb.ps1
git commit -m "perf: pre-cache O(n^2) normalization in doctor checks 22+23; fix find pipe; add deprecated help section"
```

---

## Task 2: Fix stale check count in health-check.md

**Files:**
- Modify: `.claude/commands/health-check.md`

Note: `templates/claude-commands/health-check.md` does not exist — only the live command file needs updating.

- [ ] **Step 1: Update both occurrences of "20 checks" to "24 checks"**

`.claude/commands/health-check.md` has two occurrences on lines 2 and 59:

Line 2 (frontmatter description):
```
# BEFORE
description: Full PMB health check — mb doctor (20 checks), staleness audit...

# AFTER
description: Full PMB health check — mb doctor (24 checks), staleness audit...
```

Line 59 (example output):
```
# BEFORE
> ✅ mb doctor: all 20 checks OK. ✅ mb validate...

# AFTER
> ✅ mb doctor: all 24 checks OK. ✅ mb validate...
```

- [ ] **Step 2: Verify**

```bash
grep "20 checks\|20 check" .claude/commands/health-check.md
```

Expected: no output.

```bash
grep "24 checks\|24 check" .claude/commands/health-check.md
```

Expected: 2 lines.

- [ ] **Step 3: Run tests**

```bash
bash tests/run.sh 2>&1 | tail -4
```

Expected: `All test suites passed.`

- [ ] **Step 4: Commit**

```bash
git add .claude/commands/health-check.md
git commit -m "docs: correct mb doctor check count from 20 to 24 in health-check command"
```

---

## Task 3: Document .pmb-delegation-depth in HOOKS-GUIDE.md

**Files:**
- Modify: `docs/HOOKS-GUIDE.md`

- [ ] **Step 1: Add section 6 after section 5 (PreCompact)**

Section 5 ends around line 113 (before the `## Git Hooks (versioned)` heading). Insert a new section between section 5 and the Git Hooks section:

```markdown
### 6. Agent Delegation Depth Check (`PreToolUse` — Agent tool)

Fires before every `Agent` tool call. Tracks nested agent delegation depth and emits a WARN when depth exceeds the budget defined in `standards/PERFORMANCE-BUDGET.md` (default: ≤1 subagent deep). Implemented in `scripts/delegation-depth-check.ps1` and `scripts/delegation-depth-check.sh`.

**Runtime state file:** The hook stores its counter in `.pmb-delegation-depth` in the project root (gitignored). This file is created automatically on the first agent dispatch and resets after 2 hours of inactivity. Delete it manually to reset the depth counter mid-session without restarting.

**Hook error logging:** unexpected errors are logged to `.pmb-hook-errors.log`.

```

- [ ] **Step 2: Verify section appears correctly**

```bash
grep -n "delegation\|pmb-delegation\|### 6" docs/HOOKS-GUIDE.md
```

Expected: at least 3 matching lines.

- [ ] **Step 3: Run tests**

```bash
bash tests/run.sh 2>&1 | tail -4
```

Expected: `All test suites passed.`

- [ ] **Step 4: Commit and push**

```bash
git add docs/HOOKS-GUIDE.md
git commit -m "docs: add section 6 (agent delegation depth hook + .pmb-delegation-depth file) to HOOKS-GUIDE"
git push origin main
```

---

## Final Verification

After all 3 tasks are committed and pushed:

```bash
cd "C:\Users\Mizzo\Claude\Personal-Memory-Bank"

# 1. Tests pass
bash tests/run.sh 2>&1 | tail -3

# 2. No xargs wc in mb.sh
grep "xargs wc" scripts/mb.sh
# Expected: no output

# 3. Deprecated aliases in help
bash scripts/mb.sh help | grep -i deprecated
# Expected: shows aliases line

# 4. Doctor count correct
grep "24 check" .claude/commands/health-check.md | wc -l
# Expected: 2

# 5. Delegation depth documented
grep "pmb-delegation-depth" docs/HOOKS-GUIDE.md | wc -l
# Expected: ≥1
```
