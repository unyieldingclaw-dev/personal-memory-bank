# Semantic Drift Detection Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add 3 deterministic drift checks to `mb doctor` (checks 21-23) and a new `/mb-drift` Claude Code skill for on-demand semantic analysis.

**Architecture:** Phase 1 adds git-vs-reviewed lag, completed-but-still-planned, and stale-next-step checks to both `mb.ps1` and `mb.sh`; a `$driftFound`/`DRIFT_FOUND` flag gates an advisory nudge at the end of the checks. Phase 2 creates `.claude/skills/mb-drift.md` — a read-only skill that asks Claude to reason across all 5 memory-bank files for semantic drift.

**Tech Stack:** PowerShell 7 (`mb.ps1`), bash (`mb.sh`), Markdown (skill file). No new dependencies.

---

## File Map

| File | Change |
|---|---|
| `scripts/mb.ps1` | Add checks 21–23 + `$driftFound` scaffolding inside `Show-Doctor` |
| `scripts/mb.sh` | Mirror of ps1 changes in bash |
| `docs/QUICK-REFERENCE.md` | Update "20-check" → "23-check"; add `/mb-drift` skill row |
| `.claude/skills/mb-drift.md` | New file — the semantic drift skill |
| `memory-bank/progress.md` | Move semantic identity backlog items to Completed |

---

## Task 1: Add drift scaffolding + Check 21 to mb.ps1

**Files:**
- Modify: `scripts/mb.ps1` — inside `Show-Doctor` function (around line 684)

### Context

`Show-Doctor` runs 20 numbered checks. The insertion point for the new checks is **after the checksum refresh block** (around line 1174) and **before** the `# Startup context — observability section` comment. The three new checks share a `$driftFound` flag that controls the advisory nudge.

- [ ] **Step 1: Locate the insertion point**

Open `scripts/mb.ps1`. Find the line:
```powershell
    # Startup context — observability section (not a numbered health check)
```
This is the line immediately after the checksum `try { Set-Content ... }` block. The new checks go **between** the checksum refresh and this comment.

- [ ] **Step 2: Add `$driftFound` initializer near the top of Show-Doctor**

Find this line near the start of `Show-Doctor` (around line 685, just after the function opens):
```powershell
function Show-Doctor {
```
Add `$driftFound = $false` a few lines below, just before the first `# 1.` check comment. Place it alongside any existing local variable initializations. Exact insertion — find the block that starts with:
```powershell
    $pass = $true
```
(or the first variable set near the top of Show-Doctor) and add after it:
```powershell
    $driftFound = $false
```

- [ ] **Step 3: Add Check 21 — Git-vs-reviewed lag**

Insert the following block immediately before `# Startup context — observability section`:

```powershell
    # 21. Git-vs-reviewed lag — last-reviewed frontmatter date vs. last git commit date
    $gitLagFindings = @()
    foreach ($f in @('projectbrief.md','systemPatterns.md','techContext.md','activeContext.md','progress.md')) {
        $p = "memory-bank/$f"
        if (-not (Test-Path $p)) { continue }
        $raw = Get-Content $p -Raw
        $lastReviewed = if ($raw -match '(?m)^last-reviewed:\s*(\d{4}-\d{2}-\d{2})') { $Matches[1] } else { $null }
        if (-not $lastReviewed -or $lastReviewed -eq 'YYYY-MM-DD') { continue }
        $lastCommit = git log -1 --format="%as" -- $p 2>$null
        if (-not $lastCommit) { continue }
        try {
            $revDate    = [datetime]::ParseExact($lastReviewed, 'yyyy-MM-dd', $null)
            $commitDate = [datetime]::ParseExact($lastCommit,   'yyyy-MM-dd', $null)
            if ($commitDate -gt $revDate) {
                $gitLagFindings += [pscustomobject]@{ File = $f; Reviewed = $lastReviewed; Commit = $lastCommit }
            }
        } catch {}
    }
    if ($gitLagFindings.Count -eq 0) {
        Write-Host "[OK]   Git-vs-reviewed lag — all files reviewed after last commit" -ForegroundColor Green
    } else {
        $driftFound = $true
        foreach ($item in $gitLagFindings) {
            Write-Host "[WARN] Drift: $($item.File) last-reviewed $($item.Reviewed), last commit $($item.Commit)" -ForegroundColor Yellow
            Write-Host "       Update last-reviewed frontmatter or confirm no review needed." -ForegroundColor DarkGray
        }
    }
```

- [ ] **Step 4: Verify Check 21 on current clean repo**

```powershell
cd C:\Users\Mizzo\Claude\Personal-Memory-Bank
mb doctor 2>&1 | Select-String "21|Git-vs-reviewed|Drift"
```

Expected output (repo is currently clean):
```
[OK]   Git-vs-reviewed lag — all files reviewed after last commit
```

If this line appears, Check 21 is wired correctly.

- [ ] **Step 5: Commit**

```powershell
git add scripts/mb.ps1
git commit -m "feat(doctor): add Check 21 — git-vs-reviewed lag detection (ps1)"
```

---

## Task 2: Add Checks 22 and 23 to mb.ps1

**Files:**
- Modify: `scripts/mb.ps1` — immediately after the Check 21 block added in Task 1

- [ ] **Step 1: Add the normalize helper and Check 22**

Insert immediately after the Check 21 block:

```powershell
    # Helper: strip emoji/markers, lowercase, collapse whitespace
    function Normalize-MbLine([string]$s) {
        ($s -replace '[✅⏸\-\*#]', '' -replace '\s+', ' ').Trim().ToLower()
    }

    # 22. Completed-but-still-planned — ✅ in progress.md still listed as ⏸ elsewhere
    $completedLines = @()
    if (Test-Path 'memory-bank/progress.md') {
        $completedLines = Get-Content 'memory-bank/progress.md' | Where-Object { $_ -match '✅' }
    }
    $plannedItems = @()
    foreach ($f in @('projectbrief.md','systemPatterns.md','techContext.md','activeContext.md','progress.md')) {
        $p = "memory-bank/$f"
        if (-not (Test-Path $p)) { continue }
        $fLines = Get-Content $p
        for ($i = 0; $i -lt $fLines.Count; $i++) {
            if ($fLines[$i] -match '⏸') {
                $plannedItems += [pscustomobject]@{ Text = $fLines[$i]; File = $f; Line = $i + 1 }
            }
        }
    }
    $c22Matches = @(); $c22Seen = @{}
    foreach ($doneLine in $completedLines) {
        $doneNorm = Normalize-MbLine $doneLine
        $tokens   = $doneNorm -split '\s+' | Where-Object { $_ }
        if ($tokens.Count -lt 4) { continue }
        for ($i = 0; $i -le $tokens.Count - 4; $i++) {
            $window = "$($tokens[$i]) $($tokens[$i+1]) $($tokens[$i+2]) $($tokens[$i+3])"
            if ($c22Seen.ContainsKey($window)) { continue }
            foreach ($planned in $plannedItems) {
                $pNorm = Normalize-MbLine $planned.Text
                if ($pNorm.Contains($window)) {
                    $c22Matches += [pscustomobject]@{ Window = $window; File = $planned.File; Line = $planned.Line }
                    $c22Seen[$window] = $true
                    break
                }
            }
        }
    }
    if ($c22Matches.Count -eq 0) {
        Write-Host "[OK]   Completed-but-still-planned — no cross-file completion conflicts" -ForegroundColor Green
    } else {
        $driftFound = $true
        foreach ($m in $c22Matches | Select-Object -First 5) {
            Write-Host "[WARN] Drift: `"$($m.Window)`" marked ✅ in progress.md but ⏸ in $($m.File) (line $($m.Line))" -ForegroundColor Yellow
            Write-Host "       One of these is stale — resolve before next compaction." -ForegroundColor DarkGray
        }
        if ($c22Matches.Count -gt 5) { Write-Host "       ... ($($c22Matches.Count - 5) more)" -ForegroundColor DarkGray }
    }
```

- [ ] **Step 2: Add Check 23 — Stale next step**

Insert immediately after the Check 22 block:

```powershell
    # 23. Stale next step — Next Steps bullets in activeContext.md already completed in progress.md
    $nextStepLines = @()
    $acPath = 'memory-bank/activeContext.md'
    if (Test-Path $acPath) {
        $acLines = Get-Content $acPath
        $inNextSteps = $false
        foreach ($line in $acLines) {
            if ($line -match '^## Next Steps') { $inNextSteps = $true; continue }
            if ($inNextSteps -and $line -match '^## ')   { $inNextSteps = $false }
            if ($inNextSteps -and $line -match '^\s*[-*]') { $nextStepLines += $line }
        }
    }
    $c23Matches = @(); $c23Seen = @{}
    foreach ($step in $nextStepLines) {
        $stepNorm = Normalize-MbLine $step
        $tokens   = $stepNorm -split '\s+' | Where-Object { $_ }
        if ($tokens.Count -lt 4) { continue }
        for ($i = 0; $i -le $tokens.Count - 4; $i++) {
            $window = "$($tokens[$i]) $($tokens[$i+1]) $($tokens[$i+2]) $($tokens[$i+3])"
            if ($c23Seen.ContainsKey($window)) { continue }
            foreach ($doneLine in $completedLines) {
                $doneNorm = Normalize-MbLine $doneLine
                if ($doneNorm.Contains($window)) {
                    $c23Matches += [pscustomobject]@{ Step = $step.Trim(); Window = $window }
                    $c23Seen[$window] = $true
                    break
                }
            }
        }
    }
    if ($c23Matches.Count -eq 0) {
        Write-Host "[OK]   Stale next steps — all Next Steps items appear pending in progress" -ForegroundColor Green
    } else {
        $driftFound = $true
        foreach ($s in $c23Matches) {
            Write-Host "[WARN] Drift: Next Step appears completed — `"$($s.Step)`"" -ForegroundColor Yellow
            Write-Host "       Remove from activeContext.md Next Steps or verify the progress entry." -ForegroundColor DarkGray
        }
    }
```

- [ ] **Step 3: Add the advisory nudge after Check 23**

Insert immediately after the Check 23 block (still before `# Startup context`):

```powershell
    if ($driftFound) {
        Write-Host ""
        Write-Host "       Structural drift signals detected — run /mb-drift for semantic analysis." -ForegroundColor DarkYellow
    }
```

- [ ] **Step 4: Verify all three checks show [OK] on the clean repo**

```powershell
mb doctor 2>&1 | Select-String "21|22|23|Git-vs-reviewed|Completed-but|Stale next|Drift"
```

Expected (no drift in current repo):
```
[OK]   Git-vs-reviewed lag — all files reviewed after last commit
[OK]   Completed-but-still-planned — no cross-file completion conflicts
[OK]   Stale next steps — all Next Steps items appear pending in progress
```

- [ ] **Step 5: Integration test Check 21 — induce a stale review date**

Temporarily set `last-reviewed` in `memory-bank/systemPatterns.md` to `2020-01-01` (edit frontmatter, do NOT commit the change). Then run:

```powershell
mb doctor 2>&1 | Select-String "Drift|Git-vs-reviewed|WARN"
```

Expected:
```
[WARN] Drift: systemPatterns.md last-reviewed 2020-01-01, last commit <recent date>
```

Restore the original `last-reviewed` date immediately after verifying.

- [ ] **Step 6: Commit**

```powershell
git add scripts/mb.ps1
git commit -m "feat(doctor): add Checks 22-23 + drift advisory nudge (ps1)"
```

---

## Task 3: Mirror drift checks in mb.sh

**Files:**
- Modify: `scripts/mb.sh` — inside the `show_doctor` function, same insertion point as ps1 (after checksum refresh, before startup context)

### Context

The bash doctor function uses `echo -e` with color variables `$GREEN`, `$YELLOW`, `$RED`, `$NC`. The checksum refresh ends around:
```bash
    } > "$CHECKSUM_FILE" 2>/dev/null || true
```
The startup context block starts with:
```bash
    # Startup context — observability section (not a numbered health check)
```
Insert all three checks between these two lines.

- [ ] **Step 1: Add `DRIFT_FOUND=false` near the top of the doctor function**

Find the bash doctor function opening (search for `show_doctor()` or the comment `# mb doctor reports`). Add `DRIFT_FOUND=false` alongside existing local variable initializations near the top of the function body.

- [ ] **Step 2: Add Check 21 in bash**

Insert immediately before `# Startup context — observability section`:

```bash
    # 21. Git-vs-reviewed lag — last-reviewed frontmatter date vs. last git commit date
    GIT_LAG_FOUND=false
    for f in projectbrief.md systemPatterns.md techContext.md activeContext.md progress.md; do
        p="memory-bank/$f"
        [ ! -f "$p" ] && continue
        last_rev=$(grep -m1 '^last-reviewed:' "$p" 2>/dev/null | sed 's/last-reviewed:[[:space:]]*//' | tr -d ' \r')
        [ -z "$last_rev" ] || [ "$last_rev" = "YYYY-MM-DD" ] && continue
        last_commit=$(git log -1 --format="%as" -- "$p" 2>/dev/null)
        [ -z "$last_commit" ] && continue
        # WHY: YYYY-MM-DD dates sort lexicographically — string comparison is safe.
        if [[ "$last_commit" > "$last_rev" ]]; then
            echo -e "${YELLOW}[WARN] Drift: $f last-reviewed $last_rev, last commit $last_commit${NC}"
            echo "       Update last-reviewed frontmatter or confirm no review needed."
            GIT_LAG_FOUND=true
            DRIFT_FOUND=true
        fi
    done
    [ "$GIT_LAG_FOUND" = false ] && echo -e "${GREEN}[OK]   Git-vs-reviewed lag — all files reviewed after last commit${NC}"
```

- [ ] **Step 3: Add Check 22 in bash**

Insert immediately after the Check 21 block:

```bash
    # 22. Completed-but-still-planned — ✅ in progress.md still listed as ⏸ elsewhere
    _mb_normalize() {
        # WHY: strip emoji/markers, lowercase, collapse whitespace for token comparison
        echo "$1" | sed 's/[✅⏸*#-]//g' | tr '[:upper:]' '[:lower:]' | tr -s ' ' | sed 's/^ //;s/ $//'
    }
    C22_FOUND=false
    PROGRESS_FILE="memory-bank/progress.md"
    if [ -f "$PROGRESS_FILE" ]; then
        while IFS= read -r done_line; do
            done_norm=$(_mb_normalize "$done_line")
            read -ra done_tokens <<< "$done_norm"
            n=${#done_tokens[@]}
            [ "$n" -lt 4 ] && continue
            matched=false
            for ((i=0; i<=n-4 && !matched; i++)); do
                window="${done_tokens[$i]} ${done_tokens[$i+1]} ${done_tokens[$i+2]} ${done_tokens[$i+3]}"
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
            done
        done < <(grep '✅' "$PROGRESS_FILE" 2>/dev/null)
    fi
    [ "$C22_FOUND" = false ] && echo -e "${GREEN}[OK]   Completed-but-still-planned — no cross-file completion conflicts${NC}"
```

- [ ] **Step 4: Add Check 23 in bash**

Insert immediately after the Check 22 block:

```bash
    # 23. Stale next step — Next Steps bullets in activeContext.md already in progress ✅
    AC_FILE="memory-bank/activeContext.md"
    C23_FOUND=false
    if [ -f "$AC_FILE" ] && [ -f "$PROGRESS_FILE" ]; then
        in_next_steps=false
        while IFS= read -r line; do
            if echo "$line" | grep -q '^## Next Steps'; then
                in_next_steps=true; continue
            fi
            echo "$line" | grep -q '^## ' && in_next_steps=false
            if [ "$in_next_steps" = true ] && echo "$line" | grep -qE '^\s*[-*]'; then
                step_norm=$(_mb_normalize "$line")
                read -ra step_tokens <<< "$step_norm"
                ns=${#step_tokens[@]}
                [ "$ns" -lt 4 ] && continue
                matched_step=false
                for ((j=0; j<=ns-4 && !matched_step; j++)); do
                    swindow="${step_tokens[$j]} ${step_tokens[$j+1]} ${step_tokens[$j+2]} ${step_tokens[$j+3]}"
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
                done
            fi
        done < "$AC_FILE"
    fi
    [ "$C23_FOUND" = false ] && echo -e "${GREEN}[OK]   Stale next steps — all Next Steps items appear pending in progress${NC}"

    if [ "$DRIFT_FOUND" = true ]; then
        echo ""
        echo -e "${YELLOW}       Structural drift signals detected — run /mb-drift for semantic analysis.${NC}"
    fi
```

- [ ] **Step 5: Verify bash checks pass on clean repo**

```bash
cd /c/Users/Mizzo/Claude/Personal-Memory-Bank
bash scripts/mb.sh doctor 2>&1 | grep -E "21|22|23|Git-vs|Completed-but|Stale next|Drift"
```

Expected (no drift):
```
[OK]   Git-vs-reviewed lag — all files reviewed after last commit
[OK]   Completed-but-still-planned — no cross-file completion conflicts
[OK]   Stale next steps — all Next Steps items appear pending in progress
```

- [ ] **Step 6: Commit**

```bash
git add scripts/mb.sh
git commit -m "feat(doctor): add Checks 21-23 + drift advisory nudge (sh)"
```

---

## Task 4: Update QUICK-REFERENCE.md

**Files:**
- Modify: `docs/QUICK-REFERENCE.md`

- [ ] **Step 1: Update the doctor check count**

Find the line:
```markdown
| `mb doctor` | Full 20-check diagnostic — git, templates, hooks, file sizes, version, startup context, hook errors, semantic drift, integrity |
```

Replace with:
```markdown
| `mb doctor` | Full 23-check diagnostic — git, templates, hooks, file sizes, version, startup context, hook errors, semantic drift, drift flags, integrity |
```

- [ ] **Step 2: Add the /mb-drift skill row**

Find the `/health-check` row in the slash commands table:
```markdown
| `/health-check` | Full PMB health check — runs mb doctor + mb validate + mb audit and prints summary (PMB repo only) |
```

Add a new row after it:
```markdown
| `/mb-drift` | On-demand semantic drift analysis — reads all 5 memory-bank files and finds duplicate concepts, superseded decisions, and authority violations (PMB repo only) |
```

- [ ] **Step 3: Verify the doc looks right**

```powershell
Select-String -Path "docs\QUICK-REFERENCE.md" -Pattern "mb doctor|mb-drift|health-check"
```

- [ ] **Step 4: Commit**

```powershell
git add docs/QUICK-REFERENCE.md
git commit -m "docs: update QUICK-REFERENCE — 23-check doctor, add /mb-drift skill"
```

---

## Task 5: Create the /mb-drift skill

**Files:**
- Create: `.claude/skills/mb-drift.md`

- [ ] **Step 1: Create the skills directory**

```powershell
New-Item -ItemType Directory -Path ".claude\skills" -Force
```

- [ ] **Step 2: Write the skill file**

Create `.claude/skills/mb-drift.md` with the following content:

```markdown
---
name: mb-drift
description: On-demand semantic drift analysis across all 5 memory-bank files. Use when mb doctor reports structural drift signals, or any time the memory bank may have drifted after a long compaction cycle. Reads files and outputs findings — no edits.
---

# Semantic Drift Analysis

You are running a semantic drift analysis on this project's memory bank. Your job is to find concept-level drift that deterministic checks cannot catch.

## Step 1: Read all 5 memory-bank files

Read each of these files now using the Read tool:
- `memory-bank/projectbrief.md`
- `memory-bank/systemPatterns.md`
- `memory-bank/techContext.md`
- `memory-bank/activeContext.md`
- `memory-bank/progress.md`

If a file is missing, note it in the report and continue with the others.

## Step 2: Reason across the files for three drift types

**Authority hierarchy (highest to lowest):**
`projectbrief.md` (immutable) > `systemPatterns.md` / `techContext.md` (stable) > `activeContext.md` (volatile) > `progress.md` (accumulating)

### A. Duplicate concept drift
The same decision slot (database, auth method, deployment target, tech stack choice, etc.) appears in two or more files but with different conclusions or diverging wording that suggests they have drifted apart over time.

Look for: same subject, different answer. Example: systemPatterns.md says "use Postgres" while techContext.md now says "use Supabase."

### B. Supersession rot
A decision is still phrased as active/current in one file, but a newer, contradicting decision exists elsewhere (a later section of the same file, or a different file with higher or lower authority). The old entry should say "superseded by X" but does not.

Look for: old phrasing like "we will X" or "current approach is X" alongside newer text that replaced X with Y.

### C. Authority violations
A volatile file (`activeContext.md`, `progress.md`) contains a claim that directly contradicts an authoritative file (`projectbrief.md`, `systemPatterns.md`) without explicit acknowledgment. The volatile file should defer to or reference the authoritative file, not silently override it.

Look for: a constraint or decision in projectbrief/systemPatterns that is contradicted outright in activeContext/progress.

## Step 3: Output the findings report

Use exactly this format:

```
## mb-drift findings — YYYY-MM-DD

### Duplicate concept drift
- **[concept name]** — [File A §Section] says "[quote]"; [File B §Section] says "[quote]". Which is current?

### Supersession rot
- **[item]** — [File §Section line N] still phrased as active/current, but [File §Section] contains a newer decision that appears to replace it.

### Authority violations
- **[claim]** — [volatile file §Section] asserts "[quote]" which contradicts [authoritative file §Section] "[quote]".

---
Detection only. Review each finding and update the relevant file to resolve.
```

If no findings in a category, write `- None detected.`

## Rules

- Read files only. Do not call Edit, Write, or any other tool.
- Do not suggest specific edits or rewrite any content.
- Do not invoke other skills or subagents.
- If all three categories are clear, say so — a clean result is a valid and useful result.
```

- [ ] **Step 3: Verify the skill is loadable**

In a Claude Code session (this one is fine), run:
```
/mb-drift
```

Expected: Claude reads all 5 memory-bank files and outputs a findings report with "None detected" in all three categories (since the repo is currently clean).

- [ ] **Step 4: Commit**

```powershell
git add .claude/skills/mb-drift.md
git commit -m "feat(skills): add /mb-drift semantic drift analysis skill"
```

---

## Task 6: Update memory-bank/progress.md

**Files:**
- Modify: `memory-bank/progress.md`

- [ ] **Step 1: Move semantic identity items from Backlog to Completed**

In `memory-bank/progress.md`, find the Backlog section containing:
```markdown
**Semantic identity** — file-level health is covered; concept-level drift is not. Trigger: memory bank stable and aging (3–6 months), manual contradictions noticed. Detection-first; no auto-remediation.
- ⏸ Duplicate concept detection — same decision in two files drifting apart over compaction cycles
- ⏸ Supersession rot — old decision still looks authoritative after a newer one replaced it
- ⏸ Cross-file contradiction detection — authority hierarchy violations (e.g. activeContext vs projectbrief)
- ⏸ Claim extraction via `mb query` extension — surface semantically near-duplicate content; bounded scope, no new command needed
```

Replace it with an entry in the appropriate Completed section. Add a new dated entry:

```markdown
## 2026-06-19 — Semantic Drift Detection

- ✅ Checks 21–23 added to `mb doctor`: git-vs-reviewed lag, completed-but-still-planned, stale next step
- ✅ `/mb-drift` skill created — on-demand semantic analysis for duplicate concepts, supersession rot, authority violations
- ✅ `QUICK-REFERENCE.md` updated: 23-check doctor, `/mb-drift` skill listed
```

And remove (or mark as resolved) the corresponding Backlog block.

- [ ] **Step 2: Update `last-reviewed` frontmatter to today**

In `memory-bank/progress.md`, set:
```yaml
last-reviewed: 2026-06-19
```

- [ ] **Step 3: Commit and push**

```powershell
git add memory-bank/progress.md
git commit -m "docs(progress): record semantic drift detection as complete"
git push origin main
```

---

## Self-Review

**Spec coverage check:**

| Spec requirement | Task |
|---|---|
| Check 21 — git-vs-reviewed lag (ps1 + sh) | Tasks 1, 3 |
| Check 22 — completed-but-still-planned (ps1 + sh) | Tasks 2, 3 |
| Check 23 — stale next step (ps1 + sh) | Tasks 2, 3 |
| Advisory nudge when drift found | Tasks 2, 3 |
| `/mb-drift` skill with 3 detection categories | Task 5 |
| QUICK-REFERENCE.md updated (20→23, skill listed) | Task 4 |
| progress.md updated | Task 6 |
| Checks are [WARN] only, do not increment FAILED | Verified in Task 2 Step 4 |
| Advisory nudge omitted when all checks pass cleanly | Controlled by `$driftFound` / `DRIFT_FOUND` flag |

**Placeholder scan:** No TBDs, TODOs, or vague steps. All code is complete.

**Type consistency:** `Normalize-MbLine` is defined once in Task 2 Step 1 before it is used in both checks 22 and 23. The bash `_mb_normalize` function is defined once in Task 3 Step 3 and reused in Step 4.

**Scope check:** Fits a single implementation session. Two independent phases but logically sequential.
