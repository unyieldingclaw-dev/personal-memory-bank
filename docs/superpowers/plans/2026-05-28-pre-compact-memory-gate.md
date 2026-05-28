# Pre-Compact Memory Gate Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a `PreCompact` hook that warns Claude when neither the memory bank nor a handoff has been captured before context compaction, and lower the auto-compact threshold from 50% to 40% to give Claude room to act.

**Architecture:** A new script pair (`pre-compact-check.ps1` / `.sh`) fires before every compaction, checks file mtime and handoff presence, and prints an actionable warning if state hasn't been captured. Threshold change and hook wiring go into both PMB's own `settings.json` and the distributed template. CLAUDE.md files are updated to reflect the new threshold. The hook always exits 0 — compaction is never blocked.

**Tech Stack:** PowerShell (pwsh), POSIX sh, JSON (settings.json)

---

## File Map

| File | Operation | Responsibility |
|------|-----------|----------------|
| `scripts/pre-compact-check.ps1` | Create | PowerShell implementation of memory gate check |
| `scripts/pre-compact-check.sh` | Create | Bash fallback implementation |
| `templates/scripts/pre-compact-check.ps1` | Create | Template copy distributed via `mb init` |
| `templates/scripts/pre-compact-check.sh` | Create | Template copy distributed via `mb init` |
| `.claude/settings.json` | Edit | Add PreCompact hook entry, change threshold 50→40 |
| `templates/.claude/settings.json` | Edit | Add PreCompact hook entry, change threshold 50→40 |
| `CLAUDE.md` | Edit | Update threshold reference 50→40 in Token Budget section |
| `templates/CLAUDE.md` | Edit | Update threshold reference 50→40 in Context Compaction Recovery section |
| `docs/HOOKS-GUIDE.md` | Edit | Add PreCompact hook section |

---

### Task 1: Create `scripts/pre-compact-check.ps1`

**Files:**
- Create: `scripts/pre-compact-check.ps1`

- [ ] **Step 1: Write the script**

```powershell
<#
.SYNOPSIS
    PreCompact hook — memory gate check before context compaction.
.DESCRIPTION
    Checks whether memory-bank volatile files were modified today OR handoff.md exists.
    If neither: prints an actionable warning so Claude can update state before compaction.
    Always exits 0 — compaction is never blocked. Fails open on any error.
#>

param()

try {
    $today = (Get-Date).Date

    $memoryBankFresh = $false
    foreach ($file in @("memory-bank/activeContext.md", "memory-bank/progress.md")) {
        if (Test-Path $file) {
            $mtime = (Get-Item $file).LastWriteTime.Date
            if ($mtime -eq $today) {
                $memoryBankFresh = $true
                break
            }
        }
    }

    if ($memoryBankFresh -or (Test-Path "handoff.md")) {
        exit 0
    }

    Write-Host "[PreCompact] Memory bank has not been updated this session and no handoff.md exists."
    Write-Host "Update memory-bank/activeContext.md with current state, or run the Handoff Protocol"
    Write-Host "(create handoff.md) before compaction proceeds."
    exit 0
} catch {
    Write-Host "[HOOK ERROR] pre-compact-check.ps1 failed unexpectedly. Proceeding in fails-open mode."
    exit 0
}
```

- [ ] **Step 2: Verify — warn case (no fresh files, no handoff)**

Run from project root (ensure `handoff.md` does not exist and memory-bank files have an old mtime — or just run from a directory without a `memory-bank/` folder):

```powershell
pwsh -NonInteractive -File scripts/pre-compact-check.ps1
echo "Exit: $LASTEXITCODE"
```

Expected output:
```
[PreCompact] Memory bank has not been updated this session and no handoff.md exists.
Update memory-bank/activeContext.md with current state, or run the Handoff Protocol
(create handoff.md) before compaction proceeds.
Exit: 0
```

- [ ] **Step 3: Verify — silent pass (handoff.md exists)**

```powershell
New-Item handoff.md -ItemType File -Force | Out-Null
pwsh -NonInteractive -File scripts/pre-compact-check.ps1
echo "Exit: $LASTEXITCODE"
Remove-Item handoff.md
```

Expected: no output, exit 0.

- [ ] **Step 4: Verify — silent pass (memory-bank file modified today)**

```powershell
(Get-Item memory-bank/activeContext.md).LastWriteTime = Get-Date
pwsh -NonInteractive -File scripts/pre-compact-check.ps1
echo "Exit: $LASTEXITCODE"
```

Expected: no output, exit 0.

---

### Task 2: Create `scripts/pre-compact-check.sh`

**Files:**
- Create: `scripts/pre-compact-check.sh`

- [ ] **Step 1: Write the script**

```sh
#!/usr/bin/env sh
# PreCompact hook — memory gate check before context compaction.
# Checks whether memory-bank volatile files were modified today OR handoff.md exists.
# Warns if neither. Always exits 0 — compaction is never blocked. Fails open on errors.

today=$(date +%Y-%m-%d)

memory_bank_fresh=0
for file in memory-bank/activeContext.md memory-bank/progress.md; do
    if [ -f "$file" ]; then
        # GNU date (Linux): date -r file +%Y-%m-%d
        # BSD/macOS stat: stat -f "%Sm" -t "%Y-%m-%d" file
        if mtime=$(date -r "$file" +%Y-%m-%d 2>/dev/null); then
            :
        elif mtime=$(stat -f "%Sm" -t "%Y-%m-%d" "$file" 2>/dev/null); then
            :
        else
            # Cannot determine mtime — fail open
            exit 0
        fi
        if [ "$mtime" = "$today" ]; then
            memory_bank_fresh=1
            break
        fi
    fi
done

if [ "$memory_bank_fresh" -eq 1 ]; then
    exit 0
fi

if [ -f "handoff.md" ]; then
    exit 0
fi

printf '[PreCompact] Memory bank has not been updated this session and no handoff.md exists.\n'
printf 'Update memory-bank/activeContext.md with current state, or run the Handoff Protocol\n'
printf '(create handoff.md) before compaction proceeds.\n'
exit 0
```

- [ ] **Step 2: Make executable**

```bash
chmod +x scripts/pre-compact-check.sh
```

- [ ] **Step 3: Verify — warn case**

```bash
bash scripts/pre-compact-check.sh
echo "Exit: $?"
```

Expected output:
```
[PreCompact] Memory bank has not been updated this session and no handoff.md exists.
Update memory-bank/activeContext.md with current state, or run the Handoff Protocol
(create handoff.md) before compaction proceeds.
Exit: 0
```

- [ ] **Step 4: Verify — silent pass (handoff.md)**

```bash
touch handoff.md
bash scripts/pre-compact-check.sh
echo "Exit: $?"
rm handoff.md
```

Expected: no output, exit 0.

- [ ] **Step 5: Commit**

```bash
git add scripts/pre-compact-check.ps1 scripts/pre-compact-check.sh
git commit -m "feat: add pre-compact-check hook scripts"
```

---

### Task 3: Wire hook and lower threshold in `.claude/settings.json`

**Files:**
- Modify: `.claude/settings.json`

- [ ] **Step 1: Change threshold and add PreCompact hook**

In `.claude/settings.json`, make two changes:

**Change 1** — threshold (in `"env"` block):
```json
"CLAUDE_AUTOCOMPACT_PCT_OVERRIDE": "40"
```
(was `"50"`)

**Change 2** — add `"PreCompact"` key alongside the existing hook keys:
```json
"PreCompact": [
  {
    "hooks": [
      {
        "type": "command",
        "command": "pwsh -NonInteractive -File scripts/pre-compact-check.ps1 2>/dev/null || bash scripts/pre-compact-check.sh 2>/dev/null || true"
      }
    ]
  }
]
```

The full `"hooks"` object after the edit:
```json
"hooks": {
  "PostToolUse": [
    {
      "matcher": "Write|Edit",
      "hooks": [
        {
          "type": "command",
          "command": "powershell -File scripts/update-reviewed.ps1 2>/dev/null || bash scripts/update-reviewed.sh 2>/dev/null || true"
        }
      ]
    }
  ],
  "PreToolUse": [
    {
      "matcher": "Bash",
      "hooks": [
        {
          "type": "command",
          "command": "pwsh -NonInteractive -File scripts/dangerous-commands.ps1 2>/dev/null || bash scripts/dangerous-commands.sh 2>/dev/null || true"
        }
      ]
    },
    {
      "matcher": "Write|Edit",
      "hooks": [
        {
          "type": "command",
          "command": "pwsh -NonInteractive -File scripts/check-contract.ps1 2>/dev/null || bash scripts/check-contract.sh 2>/dev/null || true"
        }
      ]
    }
  ],
  "PreCompact": [
    {
      "hooks": [
        {
          "type": "command",
          "command": "pwsh -NonInteractive -File scripts/pre-compact-check.ps1 2>/dev/null || bash scripts/pre-compact-check.sh 2>/dev/null || true"
        }
      ]
    }
  ],
  "Stop": [
    {
      "hooks": [
        {
          "type": "command",
          "command": "powershell.exe -Command \"Add-Type -AssemblyName System.Windows.Forms; [System.Windows.Forms.MessageBox]::Show('Claude has paused and is waiting for input.','Claude Code',[System.Windows.Forms.MessageBoxButtons]::OK,[System.Windows.Forms.MessageBoxIcon]::Information)\" 2>/dev/null; osascript -e 'display notification \"Claude has paused and is waiting for input.\" with title \"Claude Code\"' 2>/dev/null; notify-send 'Claude Code' 'Claude has paused and is waiting for input.' 2>/dev/null; true"
        }
      ]
    }
  ]
}
```

- [ ] **Step 2: Verify**

```powershell
Get-Content .claude/settings.json | ConvertFrom-Json | Select-Object -ExpandProperty env | Select-Object CLAUDE_AUTOCOMPACT_PCT_OVERRIDE
Get-Content .claude/settings.json | ConvertFrom-Json | Select-Object -ExpandProperty hooks | Select-Object -ExpandProperty PreCompact
```

Expected: `CLAUDE_AUTOCOMPACT_PCT_OVERRIDE` = `40`; PreCompact array with one entry.

- [ ] **Step 3: Commit**

```bash
git add .claude/settings.json
git commit -m "feat: add PreCompact hook and lower threshold to 40% in PMB settings"
```

---

### Task 4: Copy scripts to `templates/scripts/` and update `templates/.claude/settings.json`

**Files:**
- Create: `templates/scripts/pre-compact-check.ps1`
- Create: `templates/scripts/pre-compact-check.sh`
- Modify: `templates/.claude/settings.json`

- [ ] **Step 1: Copy script files to templates**

```bash
cp scripts/pre-compact-check.ps1 templates/scripts/pre-compact-check.ps1
cp scripts/pre-compact-check.sh  templates/scripts/pre-compact-check.sh
chmod +x templates/scripts/pre-compact-check.sh
```

- [ ] **Step 2: Update `templates/.claude/settings.json`**

Apply the same two changes as Task 3:

**Change 1** — threshold:
```json
"CLAUDE_AUTOCOMPACT_PCT_OVERRIDE": "40"
```

**Change 2** — add `"PreCompact"` key (identical hook command as `.claude/settings.json`).

Note: the template `settings.json` includes a `Stop` hook. This is intentional — see `docs/HOOKS-GUIDE.md` for the note about headless mode; users can remove it if needed.

- [ ] **Step 3: Verify**

```powershell
Get-Content templates/.claude/settings.json | ConvertFrom-Json | Select-Object -ExpandProperty env | Select-Object CLAUDE_AUTOCOMPACT_PCT_OVERRIDE
Get-Content templates/.claude/settings.json | ConvertFrom-Json | Select-Object -ExpandProperty hooks | Select-Object -ExpandProperty PreCompact
diff scripts/pre-compact-check.ps1 templates/scripts/pre-compact-check.ps1
diff scripts/pre-compact-check.sh  templates/scripts/pre-compact-check.sh
```

Expected: threshold = `40`; PreCompact present; diffs are empty (files identical).

- [ ] **Step 4: Commit**

```bash
git add templates/scripts/pre-compact-check.ps1 templates/scripts/pre-compact-check.sh templates/.claude/settings.json
git commit -m "feat: distribute pre-compact-check scripts and hook config via templates"
```

---

### Task 5: Update CLAUDE.md threshold references

**Files:**
- Modify: `CLAUDE.md` (project root)
- Modify: `templates/CLAUDE.md`

- [ ] **Step 1: Update `CLAUDE.md` — Token Budget section**

Find and replace the threshold block in the `## Token Budget` section:

Old:
```
**Compact at task boundaries — auto-compact fires at 50%:**
- Auto-compaction is set to fire at 50% context (`CLAUDE_AUTOCOMPACT_PCT_OVERRIDE=50` in settings.json)
- Compact manually at natural boundaries before that point:
  - After planning: `/compact Focus on decisions and file paths`
  - After debugging: `/compact Focus on what was tried and what worked`
  - Before switching to unrelated work: `/clear`
- Manual `/compact` at a natural boundary beats waiting for auto-compact mid-task
```

New:
```
**Compact at task boundaries — auto-compact fires at 40%:**
- Auto-compaction is set to fire at 40% context (`CLAUDE_AUTOCOMPACT_PCT_OVERRIDE=40` in settings.json)
- A `PreCompact` hook warns Claude if memory-bank files haven't been updated today and no `handoff.md` exists — act on the warning before compaction proceeds
- Compact manually at natural boundaries before that point:
  - After planning: `/compact Focus on decisions and file paths`
  - After debugging: `/compact Focus on what was tried and what worked`
  - Before switching to unrelated work: `/clear`
- Manual `/compact` at a natural boundary beats waiting for auto-compact mid-task
```

- [ ] **Step 2: Update `templates/CLAUDE.md` — Context Compaction Recovery section**

Old:
```
Claude Code compacts at ~50% (via `CLAUDE_AUTOCOMPACT_PCT_OVERRIDE=50` in settings.json) — before the 40% handoff threshold.
```

New:
```
Claude Code compacts at ~40% (via `CLAUDE_AUTOCOMPACT_PCT_OVERRIDE=40` in settings.json). A `PreCompact` hook warns if memory-bank files are stale and no `handoff.md` exists — update state before compaction when warned.
```

- [ ] **Step 3: Verify no remaining "50%" threshold references**

```bash
grep -rn "AUTOCOMPACT_PCT_OVERRIDE=50\|auto-compact fires at 50\|compacts at ~50" CLAUDE.md templates/CLAUDE.md
```

Expected: no matches.

- [ ] **Step 4: Commit**

```bash
git add CLAUDE.md templates/CLAUDE.md
git commit -m "docs: update auto-compact threshold references from 50% to 40%"
```

---

### Task 6: Add PreCompact section to `docs/HOOKS-GUIDE.md`

**Files:**
- Modify: `docs/HOOKS-GUIDE.md`

- [ ] **Step 1: Add PreCompact row to the Hook Types table**

Find the table:
```markdown
| `PreCompact` | Before context compaction | Save state summary |
```

This row already exists. No change needed here.

- [ ] **Step 2: Add new section under "Default Hooks in This Standard"**

After the existing "### 3. PostToolUse Lint" section, add the following content verbatim:

---

### 4. Pre-Compact Memory Gate (`PreCompact`)

Fires before every context compaction. Checks whether the memory bank has been updated this session or a handoff has been created. If neither is true, prints an actionable warning so Claude can capture state before compaction proceeds.

**Detection logic (two conditions — either is sufficient to pass silently):**
- `memory-bank/activeContext.md` or `memory-bank/progress.md` has a modification time of today (same calendar date)
- `handoff.md` exists in the project root

**Warning output (when neither condition is met):**

    [PreCompact] Memory bank has not been updated this session and no handoff.md exists.
    Update memory-bank/activeContext.md with current state, or run the Handoff Protocol
    (create handoff.md) before compaction proceeds.

**Always exits 0** — compaction is never blocked. The hook is advisory; Claude decides how to respond.

Implemented in `scripts/pre-compact-check.ps1` (Windows/pwsh) and `scripts/pre-compact-check.sh` (POSIX/bash). Called via: `pwsh -NonInteractive -File scripts/pre-compact-check.ps1 2>/dev/null || bash scripts/pre-compact-check.sh 2>/dev/null || true`.

**Why calendar-date mtime instead of frontmatter `last-reviewed`?** The `last-reviewed` field is date-granular only (no time), so it can't distinguish "updated earlier today" from "updated at session start." File mtime is set by the OS on every write and is reliable without parsing.

**To customize the monitored files,** edit the file list in both `scripts/pre-compact-check.ps1` and `scripts/pre-compact-check.sh`.

---

- [ ] **Step 3: Verify**

```bash
grep -n "PreCompact\|pre-compact" docs/HOOKS-GUIDE.md
```

Expected: at least 3 matches (table row, section heading, script references).

- [ ] **Step 4: Commit**

```bash
git add docs/HOOKS-GUIDE.md
git commit -m "docs: document PreCompact memory gate hook in HOOKS-GUIDE"
```

---

### Task 7: Update memory-bank

**Files:**
- Modify: `memory-bank/activeContext.md`
- Modify: `memory-bank/progress.md`

- [ ] **Step 1: Update `memory-bank/activeContext.md`**

Replace the `## Current Focus` section to reflect the completed feature and reset next steps:

```markdown
## Current Focus

Pre-compact memory gate shipped (2026-05-28). Repo stable. Next observation window: 30-day startup context growth data (~June 4).
```

Add to `## What Was Just Completed`:

```markdown
**Pre-compact memory gate (2026-05-28):**
- `scripts/pre-compact-check.ps1` + `.sh` — PreCompact hook fires before compaction; warns if memory bank stale and no handoff.md
- `.claude/settings.json` + `templates/.claude/settings.json` — threshold lowered 50→40, PreCompact hook wired
- `templates/scripts/pre-compact-check.ps1` + `.sh` — distributed via mb init
- `CLAUDE.md` + `templates/CLAUDE.md` — threshold references updated
- `docs/HOOKS-GUIDE.md` — PreCompact section added
```

- [ ] **Step 2: Update `memory-bank/progress.md`**

Under `### Governance & Observability (May 2026)`, add:

```markdown
- ✅ Pre-compact memory gate: PreCompact hook + threshold 40%; warns if memory bank stale; distributed via templates
```

- [ ] **Step 3: Commit**

```bash
git add memory-bank/activeContext.md memory-bank/progress.md
git commit -m "chore: update memory bank for pre-compact memory gate feature"
```

---

## End-to-End Verification

After all tasks complete:

1. `CLAUDE_AUTOCOMPACT_PCT_OVERRIDE` = `"40"` in both settings files
2. `PreCompact` key present in both settings files
3. `scripts/pre-compact-check.ps1` and `.sh` exist; `.sh` is executable
4. `templates/scripts/pre-compact-check.ps1` and `.sh` exist; identical to `scripts/` copies
5. No `"50"` threshold references in `CLAUDE.md` or `templates/CLAUDE.md`
6. `docs/HOOKS-GUIDE.md` contains a PreCompact section with the warning text
7. Run `pwsh -NonInteractive -File scripts/pre-compact-check.ps1` with no `handoff.md` and stale memory bank — warning printed, exit 0
8. Run again after `touch handoff.md` — silent, exit 0
