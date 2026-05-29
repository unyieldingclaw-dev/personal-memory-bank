# PMB P0 Improvements Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Close four P0 contract-vs-tooling mismatches in Personal Memory Bank: add a canonical CODE-REVIEW standard, refactor the review command to be a thin consumer of that standard, fix CI per-file size limits, and align the archive path across scripts and standards.

**Architecture:** Standard-first approach — `standards/CODE-REVIEW.md` is the single source of truth for review semantics. Commands read the standard at runtime rather than embedding domain definitions inline. CI enforces per-file thresholds matching each file's natural growth profile. Archive path is a flat `docs/archive/` directory with a README defining naming conventions.

**Tech Stack:** Markdown (standards/commands), Bash (mb.sh), PowerShell 7+ (mb.ps1), GitHub Actions YAML (CI)

---

## File Change Map

| File | Operation | What Changes |
|---|---|---|
| `standards/CODE-REVIEW.md` | **Create** | New canonical review contract |
| `.claude/commands/code-review.md` | **Rewrite** | Thin orchestrator referencing standard |
| `templates/claude-commands/code-review.md` | **Rewrite** | Identical to above (template copy) |
| `.github/workflows/pmb-health.yml` | **Edit** | Replace uniform limit with per-file checks |
| `docs/archive/README.md` | **Create** | Flat archive directory + naming conventions |
| `scripts/mb.sh` | **Edit** | `show_archive()` and `show_slim()` — update path from `docs/ARCHIVE.md` to `docs/archive/` |
| `scripts/mb.ps1` | **Edit** | `Show-Archive` and `Show-Slim` — same path fix |
| `standards/MEMORY-BANK.md` | **Edit** | Lines 168-189 — replace partitioned subdirectory structure with flat approach; update eviction table paths |

---

## Task 1: Create `standards/CODE-REVIEW.md`

**Files:**
- Create: `standards/CODE-REVIEW.md`

- [ ] **Step 1: Create the standard**

Write `standards/CODE-REVIEW.md` with this exact content:

```markdown
# Code Review Standard

Purpose: define what constitutes a complete review.
This standard does not mandate agent topology, model, or phase count.

## Required Domains
- Security
- Correctness
- Maintainability
- Testing
- Architecture Drift

## Conditional Domains
- Performance — activate for runtime-sensitive changes (tight loops, DB queries, I/O paths)
- Accessibility — activate for UI file changes (HTML/JSX/TSX/Vue/Svelte)

## Severity Levels
Critical → High → Medium → Low → Info

## Required Finding Fields
Domain, Severity, Location, Evidence, Impact, Recommendation, Blocking, Confidence

## Required Report Sections
Scope, Files reviewed, Domain coverage, Findings, Testing gaps, Opposition review, Verdict

## Opposition Review
Not a summary pass. The reviewer must explicitly answer:
- Is any Critical/High finding overstated? Provide counter-evidence.
- What was not reviewed that could matter?
- Which findings might be false positives in this codebase's context?
- What cross-domain risk did no single domain agent catch?
A passing opposition review requires answers to all four. A general statement that none apply is a failure.

## Failure Criteria
- Skipped required domain
- Missing Evidence field on any finding
- No Testing assessment
- No Opposition review
- Repo mutation during review without explicit user request

## Remediation
Review identifies and recommends by default. Remediation (editing files, generating tests,
applying fixes) requires explicit user request after findings are presented.
```

- [ ] **Step 2: Verify file exists and is well-formed**

```bash
wc -l standards/CODE-REVIEW.md
head -5 standards/CODE-REVIEW.md
```

Expected: file exists, starts with `# Code Review Standard`

- [ ] **Step 3: Commit**

```bash
git add standards/CODE-REVIEW.md
git commit -m "feat: add canonical CODE-REVIEW standard"
```

---

## Task 2: Rewrite `.claude/commands/code-review.md`

**Files:**
- Modify: `.claude/commands/code-review.md`

The current command (137 lines) embeds domain definitions, severity rules, finding schema, and opposition logic inline. Replace the body with a thin orchestrator that reads the standard. Keep the frontmatter (description, allowed-tools) unchanged.

- [ ] **Step 1: Rewrite the command**

Replace the full content of `.claude/commands/code-review.md` with:

```markdown
---
description: Deep code review covering security, correctness, maintainability, testing, and architecture drift. Spawns separate subagents per domain so findings don't bias each other. Works on git diff or a specific file/folder.
allowed-tools:
  - Bash(git diff *)
  - Bash(git log *)
  - Bash(git status *)
  - Bash(grep -r *)
  - Bash(find * -type f *)
  - Read
---

# Code Review

You are a senior engineer orchestrating a thorough code review. Follow every step below in order. Do not skip any section. The review contract (domains, severity levels, finding schema, report sections, opposition review requirements, and failure criteria) is defined in `standards/CODE-REVIEW.md` — read it at Step 1 and apply it throughout.

## Step 1 — Load Review Contract

Read `standards/CODE-REVIEW.md` in full. This file defines:
- Required and conditional domains
- Severity levels
- Required finding fields
- Required report sections
- Opposition review requirements
- Failure criteria
- Remediation policy

Do not proceed until you have read the standard. All subsequent steps must conform to it.

## Step 2 — Determine Scope

If the user specified a file or folder path, review that target. Otherwise run:

```
git diff HEAD
git status
```

If the diff is empty, let the user know and stop.

## Step 3 — Gather Context

```
git log --oneline -10
```

For each changed file run:
```
git log --oneline -5 -- <filename>
```

Use this to understand why the code exists and whether the change is consistent with past decisions.

Determine which conditional domains apply:
- Performance: does the diff touch tight loops, database queries, or I/O paths?
- Accessibility: does the diff touch HTML/JSX/TSX/Vue/Svelte files?

## Step 4 — Spawn Independent Domain Subagents

Spawn one subagent per required domain from the standard, plus any conditional domains that apply. Each subagent sees only the code and its own domain lens — not other subagents' findings.

For each subagent, provide:
- The diff/file being reviewed
- Its assigned domain name and description from the standard
- The required finding fields from the standard (Domain, Severity, Location, Evidence, Impact, Recommendation, Blocking, Confidence)
- The severity scale from the standard
- Instruction to return structured findings only — no remediation

Domains to spawn (always): Security, Correctness, Maintainability, Testing, Architecture Drift
Domains to spawn (if applicable): Performance, Accessibility

## Step 5 — Opposition Review

Spawn one final subagent as the opposition reviewer. Give it all domain findings. It must answer all four questions from the standard's Opposition Review section:
1. Is any Critical/High finding overstated? Provide counter-evidence.
2. What was not reviewed that could matter?
3. Which findings might be false positives in this codebase's context?
4. What cross-domain risk did no single domain agent catch?

A general statement that none apply is a failure — all four must be explicitly answered.

## Step 6 — Assemble Report

Produce the report using the required sections from the standard:

**Scope:** [git diff HEAD or filename]
**Files reviewed:** N

**Domain Coverage:**
| Domain | Status |
|---|---|
| Security | Reviewed |
| Correctness | Reviewed |
| Maintainability | Reviewed |
| Testing | Reviewed |
| Architecture Drift | Reviewed |
| Performance | Reviewed / Skipped (not applicable) |
| Accessibility | Reviewed / Skipped (not applicable) |

**Findings:**
| Domain | Severity | Location | Evidence | Impact | Recommendation | Blocking | Confidence |
|---|---|---|---|---|---|---|---|
| ... | ... | ... | ... | ... | ... | Yes/No | High/Med/Low |

**Testing Gaps:**
List any missing tests identified by the Testing domain subagent.

**Opposition Review:**
[Answers to all four opposition review questions]

**Verdict:** Approve / Request Changes / Needs Discussion

One paragraph summary of the most important confirmed findings.

---

Do NOT edit files, generate tests, or apply fixes during this review. If the user wants remediation after seeing findings, they will ask explicitly.

---

## Usage

```
/code-review                     # reviews current git diff
/code-review src/auth/login.py   # reviews a specific file
/code-review src/api/            # reviews a whole folder
```
```

- [ ] **Step 2: Verify line count is reasonable**

```bash
wc -l .claude/commands/code-review.md
```

Expected: roughly 80-100 lines (much leaner than the original 137)

- [ ] **Step 3: Confirm standard reference is present**

```bash
grep "standards/CODE-REVIEW.md" .claude/commands/code-review.md
```

Expected: at least one match

- [ ] **Step 4: Confirm no inline domain definitions remain**

```bash
grep -c "Hardcoded secrets\|N+1 query\|Functions longer" .claude/commands/code-review.md
```

Expected: 0

- [ ] **Step 5: Commit**

```bash
git add .claude/commands/code-review.md
git commit -m "refactor: make code-review command a thin consumer of CODE-REVIEW standard"
```

---

## Task 3: Rewrite `templates/claude-commands/code-review.md`

**Files:**
- Modify: `templates/claude-commands/code-review.md`

This file is the template copy — it must match the live command exactly so new projects get the thin version.

- [ ] **Step 1: Copy the rewritten command to the template**

Copy the full content written in Task 2 Step 1 into `templates/claude-commands/code-review.md`. The files should be identical.

- [ ] **Step 2: Verify they match**

```bash
diff .claude/commands/code-review.md templates/claude-commands/code-review.md
```

Expected: no output (files identical)

- [ ] **Step 3: Commit**

```bash
git add templates/claude-commands/code-review.md
git commit -m "chore: sync code-review template with refactored command"
```

---

## Task 4: Fix CI per-file size limits

**Files:**
- Modify: `.github/workflows/pmb-health.yml` (lines 20-32)

The current check applies a single threshold (warn 80, fail 150) to all memory-bank files. Replace it with per-file checks matching each file's natural growth profile.

- [ ] **Step 1: Replace the memory-bank size check block**

In `.github/workflows/pmb-health.yml`, replace lines 20-32 (the entire memory-bank files check block):

**Old block (lines 20-32):**
```yaml
          echo "=== memory-bank files (warn: 80, fail: 150) ==="
          while IFS= read -r -d '' file; do
            lines=$(wc -l < "$file")
            if [ "$lines" -gt 150 ]; then
              echo "FAIL: $file ($lines lines -- limit 150)"
              FAIL=1
            elif [ "$lines" -gt 80 ]; then
              echo "WARN: $file ($lines lines -- warn 80)"
            else
              echo "OK:   $file ($lines lines)"
            fi
          done < <(find memory-bank -name "*.md" -print0 2>/dev/null)
```

**New block:**
```yaml
          echo "=== memory-bank files (per-file limits) ==="
          declare -A MB_WARN=( [projectbrief.md]=80  [activeContext.md]=100 [systemPatterns.md]=200 [techContext.md]=200 [progress.md]=250 )
          declare -A MB_FAIL=( [projectbrief.md]=120 [activeContext.md]=150 [systemPatterns.md]=300 [techContext.md]=300 [progress.md]=400 )
          while IFS= read -r -d '' file; do
            base=$(basename "$file")
            warn=${MB_WARN[$base]:-80}
            fail=${MB_FAIL[$base]:-150}
            lines=$(wc -l < "$file")
            if [ "$lines" -gt "$fail" ]; then
              echo "FAIL: $file ($lines lines -- limit $fail)"
              FAIL=1
            elif [ "$lines" -gt "$warn" ]; then
              echo "WARN: $file ($lines lines -- warn $warn)"
            else
              echo "OK:   $file ($lines lines)"
            fi
          done < <(find memory-bank -name "*.md" -print0 2>/dev/null)
```

- [ ] **Step 2: Verify no current memory-bank file would fail the new limits**

```bash
for f in memory-bank/*.md; do
  lines=$(wc -l < "$f")
  base=$(basename "$f")
  echo "$base: $lines lines"
done
```

Check each against the new limits:
- `projectbrief.md` fail > 120
- `activeContext.md` fail > 150
- `systemPatterns.md` fail > 300
- `techContext.md` fail > 300
- `progress.md` fail > 400

Expected: no file exceeds its new fail threshold.

- [ ] **Step 3: Shellcheck the updated workflow step**

```bash
shellcheck --severity=error - <<'EOF'
#!/bin/bash
FAIL=0
declare -A MB_WARN=( [projectbrief.md]=80  [activeContext.md]=100 [systemPatterns.md]=200 [techContext.md]=200 [progress.md]=250 )
declare -A MB_FAIL=( [projectbrief.md]=120 [activeContext.md]=150 [systemPatterns.md]=300 [techContext.md]=300 [progress.md]=400 )
while IFS= read -r -d '' file; do
  base=$(basename "$file")
  warn=${MB_WARN[$base]:-80}
  fail=${MB_FAIL[$base]:-150}
  lines=$(wc -l < "$file")
  if [ "$lines" -gt "$fail" ]; then
    echo "FAIL: $file ($lines lines -- limit $fail)"
    FAIL=1
  elif [ "$lines" -gt "$warn" ]; then
    echo "WARN: $file ($lines lines -- warn $warn)"
  else
    echo "OK:   $file ($lines lines)"
  fi
done < <(find memory-bank -name "*.md" -print0 2>/dev/null)
EOF
```

Expected: no errors

- [ ] **Step 4: Commit**

```bash
git add .github/workflows/pmb-health.yml
git commit -m "fix: replace uniform CI memory-bank size limit with per-file thresholds"
```

---

## Task 5: Create `docs/archive/` and README

**Files:**
- Create: `docs/archive/README.md`

- [ ] **Step 1: Create the directory and README**

Write `docs/archive/README.md` with this content:

```markdown
# Archive

Flat directory for ephemeral artifacts that have served their purpose
but are worth keeping for reference.

## Naming conventions

| Artifact | Filename pattern | Example |
|---|---|---|
| Handoffs | `handoff-YYYY-MM-DD.md` | `handoff-2026-05-29.md` |
| Memory snapshots | `snapshot-YYYY-MM-DD.md` | `snapshot-2026-05-29.md` |
| Slim outputs | `slim-YYYY-MM-DD.md` | `slim-2026-05-29.md` |
| Context evictions | `context-YYYY-MM-topic.md` | `context-2026-05-auth-refactor.md` |
| Progress evictions | `progress-YYYY-MM-topic.md` | `progress-2026-05-v1-release.md` |

## Rules
- One topic or time period per file — never append to an existing archive file
- Add subfolders only when the flat listing becomes hard to scan (>50 files)
- Files here are reference-only — do not load them into Memory Bank
```

- [ ] **Step 2: Verify the directory and file exist**

```bash
ls docs/archive/
```

Expected: `README.md`

- [ ] **Step 3: Commit**

```bash
git add docs/archive/README.md
git commit -m "feat: create docs/archive/ with flat naming conventions"
```

---

## Task 6: Fix archive path in `scripts/mb.sh`

**Files:**
- Modify: `scripts/mb.sh` — `show_archive()` function and `show_slim()` function

Both functions currently instruct users to archive to `docs/ARCHIVE.md`. Update them to reference `docs/archive/`.

- [ ] **Step 1: Update `show_archive()` in mb.sh**

Find and replace in `scripts/mb.sh`:

**Old `show_archive()` body (lines 167-182):**
```bash
show_archive() {
    echo ""
    echo -e "${CYAN}Archive Old Content${NC}"
    echo -e "${CYAN}===================${NC}"
    echo ""
    echo -e "${YELLOW}To archive old content from activeContext.md:${NC}"
    echo ""
    echo "1. Move detailed session history to docs/ARCHIVE.md"
    echo "2. Keep only current state in activeContext.md"
    echo "3. Completed 'Next Steps' should move to progress.md"
    echo ""
    echo -e "${YELLOW}Tell the AI:${NC}"
    echo ""
    echo '  "Archive old content from activeContext.md to docs/ARCHIVE.md"'
    echo ""
}
```

**New `show_archive()` body:**
```bash
show_archive() {
    echo ""
    echo -e "${CYAN}Archive Old Content${NC}"
    echo -e "${CYAN}===================${NC}"
    echo ""
    echo -e "${YELLOW}To archive old content from activeContext.md:${NC}"
    echo ""
    echo "1. Move detailed session history to docs/archive/ (see docs/archive/README.md for naming)"
    echo "2. Keep only current state in activeContext.md"
    echo "3. Completed 'Next Steps' should move to progress.md"
    echo ""
    echo -e "${YELLOW}Tell the AI:${NC}"
    echo ""
    echo '  "Archive old content from activeContext.md to docs/archive/"'
    echo ""
}
```

- [ ] **Step 2: Update `show_slim()` reference in mb.sh**

Find any reference to `docs/ARCHIVE.md` in the `show_slim()` function and update to `docs/archive/`:

```bash
grep -n "ARCHIVE.md" scripts/mb.sh
```

For each match inside `show_slim()`, replace `docs/ARCHIVE.md` with `docs/archive/`.

- [ ] **Step 3: Verify no remaining `docs/ARCHIVE.md` references in mb.sh**

```bash
grep "ARCHIVE.md" scripts/mb.sh
```

Expected: no output

- [ ] **Step 4: Shellcheck mb.sh**

```bash
shellcheck --severity=error scripts/mb.sh
```

Expected: no errors

- [ ] **Step 5: Commit**

```bash
git add scripts/mb.sh
git commit -m "fix: update mb.sh archive path from docs/ARCHIVE.md to docs/archive/"
```

---

## Task 7: Fix archive path in `scripts/mb.ps1`

**Files:**
- Modify: `scripts/mb.ps1` — `Show-Archive` and `Show-Slim` functions

- [ ] **Step 1: Update `Show-Archive` in mb.ps1**

Find and replace in `scripts/mb.ps1`:

**Old `Show-Archive` body (lines 184-199):**
```powershell
function Show-Archive {
    Write-Host ""
    Write-Host "Archive Old Content" -ForegroundColor Cyan
    Write-Host "===================" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "To archive old content from activeContext.md:" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "1. Move detailed session history to docs/ARCHIVE.md"
    Write-Host "2. Keep only current state in activeContext.md"
    Write-Host "3. Completed 'Next Steps' should move to progress.md"
    Write-Host ""
    Write-Host "Tell the AI:" -ForegroundColor Yellow
    Write-Host ""
    Write-Host '  "Archive old content from activeContext.md to docs/ARCHIVE.md"' -ForegroundColor White
    Write-Host ""
}
```

**New `Show-Archive` body:**
```powershell
function Show-Archive {
    Write-Host ""
    Write-Host "Archive Old Content" -ForegroundColor Cyan
    Write-Host "===================" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "To archive old content from activeContext.md:" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "1. Move detailed session history to docs/archive/ (see docs/archive/README.md for naming)"
    Write-Host "2. Keep only current state in activeContext.md"
    Write-Host "3. Completed 'Next Steps' should move to progress.md"
    Write-Host ""
    Write-Host "Tell the AI:" -ForegroundColor Yellow
    Write-Host ""
    Write-Host '  "Archive old content from activeContext.md to docs/archive/"' -ForegroundColor White
    Write-Host ""
}
```

- [ ] **Step 2: Update any `docs/ARCHIVE.md` reference in `Show-Slim`**

```bash
grep -n "ARCHIVE.md" scripts/mb.ps1
```

For each match inside `Show-Slim`, replace `docs/ARCHIVE.md` with `docs/archive/`.

- [ ] **Step 3: Verify no remaining `docs/ARCHIVE.md` references in mb.ps1**

```bash
grep "ARCHIVE.md" scripts/mb.ps1
```

Expected: no output

- [ ] **Step 4: Commit**

```bash
git add scripts/mb.ps1
git commit -m "fix: update mb.ps1 archive path from docs/ARCHIVE.md to docs/archive/"
```

---

## Task 8: Align `standards/MEMORY-BANK.md` archive section

**Files:**
- Modify: `standards/MEMORY-BANK.md` — Archive Structure section (lines 177-189) and Eviction Criteria table (lines 164-173)

The standard currently defines partitioned subdirectories (`context/`, `progress/`, `decisions/`) under `docs/archive/`. We're using a flat directory instead. Update to match.

- [ ] **Step 1: Replace the Archive Structure section**

Find the "## Archive Structure" section (lines 177-189) and replace:

**Old:**
```markdown
## Archive Structure

Archival is partitioned by category to remain searchable. A monolithic `docs/archive/`
becomes a retrieval dead-zone as it grows; partitioned directories stay queryable.

```
docs/archive/
  context/     YYYY-MM-<topic>.md   (evicted from activeContext.md)
  progress/    YYYY-MM-<topic>.md   (evicted from progress.md)
  decisions/   YYYY-MM-<topic>.md   (evicted from systemPatterns.md — rare)
```

When archiving, create a new file in the appropriate subdirectory named with the current
month and a short topic label (e.g., `2026-05-auth-refactor.md`). Never append to an
existing archive file — keep each file focused on one topic or time period.
```

**New:**
```markdown
## Archive Structure

Archival uses a flat `docs/archive/` directory. See `docs/archive/README.md` for naming
conventions. Files are named with a date prefix and short topic label so the flat listing
stays scannable. Add subdirectories only when the flat listing grows past ~50 files.

```
docs/archive/
  handoff-YYYY-MM-DD.md        (handoff files)
  snapshot-YYYY-MM-DD.md       (memory snapshots)
  context-YYYY-MM-topic.md     (evicted from activeContext.md)
  progress-YYYY-MM-topic.md    (evicted from progress.md)
```

Never append to an existing archive file — one topic or time period per file.
```

- [ ] **Step 2: Update Eviction Criteria table paths**

In the Eviction Criteria table (around lines 164-173), update the Action column entries that reference subdirectories:

- `Move to \`docs/archive/context/YYYY-MM-<topic>.md\`` → `Move to \`docs/archive/context-YYYY-MM-<topic>.md\``
- `Move to \`docs/archive/progress/YYYY-MM-<topic>.md\`` → `Move to \`docs/archive/progress-YYYY-MM-<topic>.md\``

- [ ] **Step 3: Verify no remaining subdirectory references**

```bash
grep "docs/archive/" standards/MEMORY-BANK.md
```

Expected: all references use flat filenames (no `/context/`, `/progress/`, `/decisions/` subdirectory paths)

- [ ] **Step 4: Commit**

```bash
git add standards/MEMORY-BANK.md
git commit -m "fix: align MEMORY-BANK standard archive path to flat docs/archive/ structure"
```

---

## Verification Checklist

Run these after all tasks are complete:

- [ ] `standards/CODE-REVIEW.md` exists with all required sections (domains, severity, finding fields, report sections, opposition review, failure criteria, remediation)
- [ ] `.claude/commands/code-review.md` references `standards/CODE-REVIEW.md` and contains no inline domain definitions
- [ ] `diff .claude/commands/code-review.md templates/claude-commands/code-review.md` returns no output
- [ ] `grep "ARCHIVE.md" scripts/mb.sh` returns no output
- [ ] `grep "ARCHIVE.md" scripts/mb.ps1` returns no output
- [ ] `ls docs/archive/` shows `README.md`
- [ ] `grep "docs/archive/" standards/MEMORY-BANK.md` shows no subdirectory paths (`/context/`, `/progress/`)
- [ ] No current memory-bank file exceeds its new per-file CI threshold
- [ ] `git log --oneline -8` shows 8 clean commits, one per task
