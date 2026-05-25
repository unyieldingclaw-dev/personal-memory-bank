# mb doctor Check #9 — Staleness Summary Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add Check #9 (staleness summary) to `mb doctor` so it surfaces stale memory-bank files without duplicating `mb audit`'s full table.

**Architecture:** Read `last-reviewed`, `staleness-threshold`, and `authority` frontmatter from each of the 5 memory-bank files directly inside `show_doctor()` / `Show-Doctor()`. Count stale files by authority tier, emit one summary line. Reuse the cross-platform date arithmetic already in `show_audit()`. Same change in both `mb.sh` (bash) and `mb.ps1` (PowerShell).

**Tech Stack:** Bash (POSIX + GNU/macOS `date`), PowerShell 7+, standard `grep`/`sed` for frontmatter extraction.

---

## File Map

| File | Change |
|------|--------|
| `scripts/mb.sh` | Insert Check #9 block (32 lines) after line 517, before `echo ""` at line 519 |
| `scripts/mb.ps1` | Insert Check #9 block (27 lines) after line 599, before `Write-Host ""` at line 601 |

No new files. No tests file (manual verification via `last-reviewed` manipulation).

---

### Task 1: Create feature branch

**Files:**
- No file changes — git only

- [ ] **Step 1: Verify you are on master and it is clean**

```bash
git status
```

Expected: `On branch master`, nothing to commit.

- [ ] **Step 2: Create and switch to the feature branch**

```bash
git checkout -b feat/mb-doctor-staleness
```

Expected: `Switched to a new branch 'feat/mb-doctor-staleness'`

---

### Task 2: Add Check #9 to `scripts/mb.sh`

**Files:**
- Modify: `scripts/mb.sh:517-519`

The compaction integrity block ends at line 517:
```
        echo -e "       Run 'mb compact' to regenerate from lower-generation sources"
    fi
                          ← INSERT HERE (before this blank line and closing brace)
    echo ""
}
```

- [ ] **Step 1: Open `scripts/mb.sh` and locate the insertion point**

Find this exact block near line 510–519:

```bash
    if [ ${#INTEGRITY_ISSUES[@]} -eq 0 ]; then
        echo -e "${GREEN}[OK]   Compaction integrity — all files at generation 0-1${NC}"
    else
        for issue in "${INTEGRITY_ISSUES[@]}"; do
            echo -e "$issue"
        done
        echo -e "       Run 'mb compact' to regenerate from lower-generation sources"
    fi

    echo ""
}
```

- [ ] **Step 2: Insert Check #9 between the `fi` on line 517 and the `echo ""` on line 519**

The file after the edit should read (lines 510–530 approximately):

```bash
    if [ ${#INTEGRITY_ISSUES[@]} -eq 0 ]; then
        echo -e "${GREEN}[OK]   Compaction integrity — all files at generation 0-1${NC}"
    else
        for issue in "${INTEGRITY_ISSUES[@]}"; do
            echo -e "$issue"
        done
        echo -e "       Run 'mb compact' to regenerate from lower-generation sources"
    fi

    # 9. Staleness summary
    echo "9. Staleness summary"
    STALE_VOLATILE=0
    STALE_STABLE=0
    TODAY=$(date +%s)
    for f in projectbrief.md systemPatterns.md techContext.md activeContext.md progress.md; do
        p="memory-bank/$f"
        [ ! -f "$p" ] && continue
        last_reviewed=$(grep -m1 '^last-reviewed:' "$p" 2>/dev/null | sed 's/last-reviewed:[[:space:]]*//' | tr -d ' \r')
        threshold=$(grep -m1 '^staleness-threshold:' "$p" 2>/dev/null | sed 's/staleness-threshold:[[:space:]]*//' | sed 's/d$//' | tr -d ' \r')
        authority=$(grep -m1 '^authority:' "$p" 2>/dev/null | sed 's/authority:[[:space:]]*//' | tr -d ' \r')
        [ -z "$last_reviewed" ] || [ "$last_reviewed" = "YYYY-MM-DD" ] && continue
        [ -z "$threshold" ] && continue
        [ "$authority" = "immutable" ] && continue
        REVIEWED_EPOCH=$(date -d "$last_reviewed" +%s 2>/dev/null || date -j -f "%Y-%m-%d" "$last_reviewed" +%s 2>/dev/null || echo "0")
        DAYS_SINCE=$(( (TODAY - REVIEWED_EPOCH) / 86400 ))
        if [ "$DAYS_SINCE" -gt "$threshold" ]; then
            if [ "$authority" = "stable" ]; then
                STALE_STABLE=$((STALE_STABLE + 1))
            else
                STALE_VOLATILE=$((STALE_VOLATILE + 1))
            fi
        fi
    done
    STALE_TOTAL=$((STALE_VOLATILE + STALE_STABLE))
    if [ "$STALE_TOTAL" -eq 0 ]; then
        echo -e "${GREEN}[OK]   All memory-bank files within staleness threshold${NC}"
    else
        DETAIL=""
        [ "$STALE_VOLATILE" -gt 0 ] && DETAIL="${STALE_VOLATILE} volatile/accumulating"
        [ "$STALE_STABLE" -gt 0 ] && DETAIL="${DETAIL:+$DETAIL, }${STALE_STABLE} stable"
        echo -e "${YELLOW}[WARN] ${STALE_TOTAL} stale memory-bank file(s) detected (${DETAIL}) — run 'mb audit' for details${NC}"
    fi

    echo ""
}
```

- [ ] **Step 3: Verify the script is valid bash**

```bash
bash -n scripts/mb.sh
```

Expected: no output (exit code 0). Any output means a syntax error — fix before continuing.

- [ ] **Step 4: Commit**

```bash
git add scripts/mb.sh
git commit -m "feat: add mb doctor check #9 — staleness summary (bash)"
```

---

### Task 3: Add Check #9 to `scripts/mb.ps1`

**Files:**
- Modify: `scripts/mb.ps1:599-601`

The compaction integrity block ends at line 599:
```powershell
        Write-Host "       Run 'mb compact' to regenerate from lower-generation sources" -ForegroundColor DarkGray
    }

    Write-Host ""    ← INSERT BEFORE THIS LINE
}
```

- [ ] **Step 1: Open `scripts/mb.ps1` and locate the insertion point**

Find this exact block near lines 591–602:

```powershell
    if ($integrityIssues.Count -eq 0) {
        Write-Host "[OK]   Compaction integrity — all files at generation 0-1" -ForegroundColor Green
    } else {
        foreach ($issue in $integrityIssues) {
            $color = if ($issue.Level -eq "ERROR") { "Red" } elseif ($issue.Level -eq "WARN") { "Yellow" } else { "DarkYellow" }
            Write-Host "[$($issue.Level)] $($issue.Msg)" -ForegroundColor $color
        }
        Write-Host "       Run 'mb compact' to regenerate from lower-generation sources" -ForegroundColor DarkGray
    }

    Write-Host ""
}
```

- [ ] **Step 2: Insert Check #9 between the closing `}` on line 599 and `Write-Host ""` on line 601**

The file after the edit should read (lines 591–635 approximately):

```powershell
    if ($integrityIssues.Count -eq 0) {
        Write-Host "[OK]   Compaction integrity — all files at generation 0-1" -ForegroundColor Green
    } else {
        foreach ($issue in $integrityIssues) {
            $color = if ($issue.Level -eq "ERROR") { "Red" } elseif ($issue.Level -eq "WARN") { "Yellow" } else { "DarkYellow" }
            Write-Host "[$($issue.Level)] $($issue.Msg)" -ForegroundColor $color
        }
        Write-Host "       Run 'mb compact' to regenerate from lower-generation sources" -ForegroundColor DarkGray
    }

    # 9. Staleness summary
    Write-Host "9. Staleness summary"
    $staleVolatile = 0
    $staleStable = 0
    foreach ($f in @("projectbrief.md", "systemPatterns.md", "techContext.md", "activeContext.md", "progress.md")) {
        $p = "memory-bank/$f"
        if (-not (Test-Path $p)) { continue }
        $content = Get-Content $p -Raw
        $lastReviewed = if ($content -match '(?m)^last-reviewed:\s*(\d{4}-\d{2}-\d{2})') { $Matches[1] } else { $null }
        $thresholdStr = if ($content -match '(?m)^staleness-threshold:\s*(\d+)d') { $Matches[1] } else { $null }
        $authority = if ($content -match '(?m)^authority:\s*(\S+)') { $Matches[1] } else { $null }
        if (-not $lastReviewed -or -not $thresholdStr) { continue }
        if ($authority -eq 'immutable') { continue }
        try {
            $lastDate = [datetime]::ParseExact($lastReviewed, 'yyyy-MM-dd', $null)
            $daysSince = ([datetime]::Today - $lastDate).Days
            $thresholdDays = [int]$thresholdStr
            if ($daysSince -gt $thresholdDays) {
                if ($authority -eq 'stable') { $staleStable++ } else { $staleVolatile++ }
            }
        } catch { continue }
    }
    $staleTotal = $staleVolatile + $staleStable
    if ($staleTotal -eq 0) {
        Write-Host "[OK]   All memory-bank files within staleness threshold" -ForegroundColor Green
    } else {
        $parts = @()
        if ($staleVolatile -gt 0) { $parts += "$staleVolatile volatile/accumulating" }
        if ($staleStable -gt 0) { $parts += "$staleStable stable" }
        $detail = $parts -join ", "
        Write-Host "[WARN] $staleTotal stale memory-bank file(s) detected ($detail) — run 'mb audit' for details" -ForegroundColor Yellow
    }

    Write-Host ""
}
```

- [ ] **Step 3: Verify PowerShell syntax**

```powershell
pwsh -NoProfile -Command "& { [void](Get-Command -Name 'scripts/mb.ps1' -ErrorAction SilentlyContinue); $null = [System.Management.Automation.Language.Parser]::ParseFile((Resolve-Path 'scripts/mb.ps1'), [ref]$null, [ref]$errors); $errors }"
```

Expected: no output (no parse errors). Alternatively, run the whole script with `pwsh -File scripts/mb.ps1 doctor` and look for syntax errors in the output.

- [ ] **Step 4: Commit**

```bash
git add scripts/mb.ps1
git commit -m "feat: add mb doctor check #9 — staleness summary (PowerShell)"
```

---

### Task 4: Manual verification

**Files:** `memory-bank/activeContext.md`, `memory-bank/systemPatterns.md` — temporary edits only, reverted after testing

This task has no permanent file changes. It uses the bash script on the current platform. If on Windows, run `bash scripts/mb.sh doctor` inside Git Bash or WSL.

- [ ] **Step 1: Verify the [OK] case — all files fresh**

Check that all `last-reviewed` fields in `memory-bank/*.md` are recent (within each file's `staleness-threshold`). If any are already stale, note them — they'll show up in the test below.

Run:
```bash
bash scripts/mb.sh doctor 2>&1 | grep -A2 "9\. Staleness"
```

Expected:
```
9. Staleness summary
[OK]   All memory-bank files within staleness threshold
```

- [ ] **Step 2: Simulate one stale volatile file**

In `memory-bank/activeContext.md`, temporarily change `last-reviewed` to `2020-01-01` (its `staleness-threshold` is `14d`, so any old date works):

```bash
# Save original value first
ORIG=$(grep '^last-reviewed:' memory-bank/activeContext.md)

# Set to stale date
sed -i 's/^last-reviewed:.*/last-reviewed: 2020-01-01/' memory-bank/activeContext.md
```

On macOS (no `-i` without extension):
```bash
sed -i '' 's/^last-reviewed:.*/last-reviewed: 2020-01-01/' memory-bank/activeContext.md
```

Run:
```bash
bash scripts/mb.sh doctor 2>&1 | grep -A2 "9\. Staleness"
```

Expected:
```
9. Staleness summary
[WARN] 1 stale memory-bank file(s) detected (1 volatile/accumulating) — run 'mb audit' for details
```

- [ ] **Step 3: Simulate one stale stable file (in addition)**

In `memory-bank/systemPatterns.md`, temporarily set `last-reviewed: 2020-01-01` (its `staleness-threshold` is `90d`, `authority: stable`):

```bash
sed -i 's/^last-reviewed:.*/last-reviewed: 2020-01-01/' memory-bank/systemPatterns.md
```

Run:
```bash
bash scripts/mb.sh doctor 2>&1 | grep -A2 "9\. Staleness"
```

Expected:
```
9. Staleness summary
[WARN] 2 stale memory-bank file(s) detected (1 volatile/accumulating, 1 stable) — run 'mb audit' for details
```

- [ ] **Step 4: Confirm immutable files are skipped**

In `memory-bank/projectbrief.md`, temporarily set `last-reviewed: 2020-01-01` (`authority: immutable`):

```bash
sed -i 's/^last-reviewed:.*/last-reviewed: 2020-01-01/' memory-bank/projectbrief.md
```

Run:
```bash
bash scripts/mb.sh doctor 2>&1 | grep -A2 "9\. Staleness"
```

Expected: count unchanged — still shows 2, not 3 (immutable skipped).

- [ ] **Step 5: Restore all files to original `last-reviewed` values**

```bash
git checkout memory-bank/activeContext.md memory-bank/systemPatterns.md memory-bank/projectbrief.md
```

Run doctor once more to confirm `[OK]` or the pre-test baseline:
```bash
bash scripts/mb.sh doctor 2>&1 | grep -A2 "9\. Staleness"
```

- [ ] **Step 6: Commit verification note**

No code change in this task — no commit needed.

---

### Task 5: Commit spec and finalize

**Files:**
- `docs/superpowers/specs/2026-05-22-mb-doctor-staleness-design.md` — already written, needs committing
- `docs/superpowers/plans/2026-05-22-mb-doctor-staleness.md` — this plan file

- [ ] **Step 1: Stage the spec and plan docs**

```bash
git add docs/superpowers/specs/2026-05-22-mb-doctor-staleness-design.md
git add docs/superpowers/plans/2026-05-22-mb-doctor-staleness.md
git commit -m "docs: add spec and plan for mb doctor staleness check #9"
```

- [ ] **Step 2: Confirm branch history**

```bash
git log --oneline feat/mb-doctor-staleness ^master
```

Expected (3 commits):
```
<sha> docs: add spec and plan for mb doctor staleness check #9
<sha> feat: add mb doctor check #9 — staleness summary (PowerShell)
<sha> feat: add mb doctor check #9 — staleness summary (bash)
```

- [ ] **Step 3: Merge or create PR**

Option A — merge locally:
```bash
git checkout master
git merge feat/mb-doctor-staleness
git branch -d feat/mb-doctor-staleness
```

Option B — push and open PR:
```bash
git push -u origin feat/mb-doctor-staleness
gh pr create --title "feat: mb doctor check #9 — staleness summary" --body "$(cat <<'EOF'
## Summary
- Adds Check #9 to \`mb doctor\` in both \`mb.sh\` and \`mb.ps1\`
- Surfaces stale memory-bank file count by authority tier (volatile/accumulating vs stable)
- Immutable files skipped by design; uninitialized placeholders skipped silently
- Reuses existing date arithmetic from \`show_audit()\`; no new detection logic

## Test plan
- [ ] \`mb doctor\` shows \`[OK]\` when all files are within threshold
- [ ] \`mb doctor\` shows \`[WARN] N stale...\` with correct breakdown when files are stale
- [ ] Immutable files do not affect the count
- [ ] \`bash -n scripts/mb.sh\` exits clean
EOF
)"
```
