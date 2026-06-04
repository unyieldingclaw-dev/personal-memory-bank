# MB Commands Redesign (v1.0.7) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Consolidate 15 `mb` commands to 8, add natural language triggers for `mb` commands in CLAUDE.md and Cursor rules, and update all documentation to reflect the new command surface.

**Architecture:** Surgical edits across three layers — scripts (`mb.ps1`, `mb.sh` get new functions and expanded ones), configuration (CLAUDE.md-style files get a new protocol section), and documentation (markdown files get inline reference updates). No new files created; no external dependencies added.

**Tech Stack:** PowerShell 7 (`mb.ps1`), Bash (`mb.sh`), Markdown (all other files)

---

## Pre-flight

- [ ] **Write Task Contract before beginning any edits** (14 files, crosses the 4-file threshold per CLAUDE.md):

```json
// .claude/contracts/active-task.json
{
  "task": "v1.0.7 MB commands redesign",
  "scope": [
    "scripts/mb.ps1",
    "scripts/mb.sh",
    "CLAUDE.md",
    "templates/CLAUDE.md",
    ".cursor/rules/memory-bank.mdc",
    "templates/cursor/rules/memory-bank.mdc",
    "docs/COMMANDS-REFERENCE.md",
    "README.md",
    "QUICK-REFERENCE.md",
    "docs/SETUP-GUIDE.md",
    "docs/UPGRADE.md",
    "docs/RECOVERY.md",
    "CHANGELOG.md",
    "VERSION"
  ],
  "status": "in-progress",
  "expires_at": "<8 hours from start time>"
}
```

---

## Task 1: PS1 — Add `Show-Clean` function + add `clean` to `ValidateSet`

**Files:**
- Modify: `scripts/mb.ps1`

- [ ] **Step 1: Verify `mb clean` fails before implementation**

```powershell
mb clean
# Expected: "The argument 'clean' does not belong to the set..." (ValidateSet rejection)
```

- [ ] **Step 2: Add `clean` to `ValidateSet` in the param block (line 23)**

Find:
```powershell
[ValidateSet("init", "install-hooks", "validate", "doctor", "status", "audit", "query", "compact", "update", "archive", "slim", "commit", "upgrade", "budget", "help")]
```
Replace with:
```powershell
[ValidateSet("init", "install-hooks", "validate", "doctor", "status", "audit", "query", "compact", "update", "archive", "slim", "commit", "upgrade", "budget", "clean", "help")]
```

- [ ] **Step 3: Add `Show-Clean` function after the closing `}` of `Show-Slim` (around line 248)**

```powershell
function Show-Clean {
    Write-Host ""
    Write-Host "Memory Bank Maintenance" -ForegroundColor Cyan
    Write-Host "=======================" -ForegroundColor Cyan
    Write-Host ""

    # Slim check
    Write-Host "--- Slim Check ---" -ForegroundColor Yellow
    $path = Join-Path $MemoryBankPath "activeContext.md"
    if (Test-Path $path) {
        $lines = (Get-Content $path | Measure-Object -Line).Lines
        Write-Host "activeContext.md: $lines lines (target: 50-100, max: 150)"
        if ($lines -gt 150) {
            Write-Host "ACTION NEEDED: File is over limit!" -ForegroundColor Red
        } elseif ($lines -gt 100) {
            Write-Host "RECOMMENDED: Consider trimming" -ForegroundColor Yellow
        } else {
            Write-Host "OK: File is within target range" -ForegroundColor Green
        }
    } else {
        Write-Host "Warning: activeContext.md not found" -ForegroundColor Yellow
    }
    Write-Host ""

    # Unified maintenance prompt
    Write-Host "--- Maintenance Prompt ---" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "Paste this prompt to the AI to perform a full memory bank cleanup:" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "---" -ForegroundColor DarkGray
    Write-Host @"
Perform a full memory bank maintenance pass:

1. Archive old content from activeContext.md:
   - Move detailed session history to docs/archive/ (naming: context-YYYY-MM-<topic>.md)
   - Keep only current state and active next steps

2. Compact the memory bank (run after archiving):
   - Remove duplicate decisions (keep most recent/authoritative)
   - Surface contradictions for review — do not resolve them
   - Remove activeContext.md entries already captured in progress.md
   - Archive progress.md entries for work completed >6 months ago
   - Condense verbose descriptions to decision + rationale

3. Update all memory-bank files with any session progress:
   - activeContext.md (current focus, next steps)
   - progress.md (completed items)
   - techContext.md (if dependencies changed)
   - systemPatterns.md (if new patterns established)

Show a summary of what changed before committing.
"@ -ForegroundColor White
    Write-Host "---" -ForegroundColor DarkGray
    Write-Host ""
}
```

- [ ] **Step 4: Add `clean` dispatch case to the switch statement**

In the switch block (around line 1440), add after the existing cases:
```powershell
    "clean"         { Show-Clean }
```

- [ ] **Step 5: Verify `mb clean` works**

```powershell
mb clean
# Expected first lines:
# Memory Bank Maintenance
# =======================
#
# --- Slim Check ---
# activeContext.md: <N> lines (target: 50-100, max: 150)
# ...
# --- Maintenance Prompt ---
```

- [ ] **Step 6: Commit**

```powershell
git add scripts/mb.ps1
git commit -m "feat(ps1): add mb clean command"
```

---

## Task 2: PS1 — Expand `Show-Doctor` with 3 absorbed sections

**Files:**
- Modify: `scripts/mb.ps1`

- [ ] **Step 1: Verify `mb doctor` does NOT show "Lifecycle Audit" yet**

```powershell
mb doctor | Select-String "Lifecycle Audit"
# Expected: no output
```

- [ ] **Step 2: Add 3 section calls at the end of `Show-Doctor` (around line 985)**

Find:
```powershell
    } else {
        Write-Host "  Stale but loaded:  none [OK]" -ForegroundColor Green
    }

    Write-Host ""
}

function Show-Audit {
```

Replace with:
```powershell
    } else {
        Write-Host "  Stale but loaded:  none [OK]" -ForegroundColor Green
    }

    Write-Host ""
    Write-Host "=== Lifecycle Audit ===" -ForegroundColor Cyan
    Show-Audit

    Write-Host "=== Structural Validation ===" -ForegroundColor Cyan
    Show-Validate

    Write-Host "=== Budget Estimate ===" -ForegroundColor Cyan
    Show-Budget
}

function Show-Audit {
```

- [ ] **Step 3: Verify `mb doctor` shows all 3 sections**

```powershell
mb doctor | Select-String "==="
# Expected:
# === Lifecycle Audit ===
# === Structural Validation ===
# === Budget Estimate ===
```

- [ ] **Step 4: Commit**

```powershell
git add scripts/mb.ps1
git commit -m "feat(ps1): mb doctor absorbs audit, validate, budget"
```

---

## Task 3: PS1 — Replace switch dispatch + update `Show-Help`

**Files:**
- Modify: `scripts/mb.ps1`

- [ ] **Step 1: Verify `mb compact` currently runs the old output**

```powershell
mb compact | Select-String "Memory Compaction"
# Expected: "Memory Compaction" (old Show-Compact output, not a redirect yet)
```

- [ ] **Step 2: Replace the switch statement dispatch block (around lines 1424–1440)**

Find:
```powershell
switch ($Command) {
    "init"          { Invoke-Init }
    "install-hooks" { Invoke-InstallHooks }
    "validate"      { Show-Validate }
    "doctor"        { Show-Doctor }
    "status"        { Show-Status }
    "audit"         { Show-Audit }
    "query"         { Show-Query -Keyword $Arg }
    "compact"       { Show-Compact }
    "update"        { Show-Update }
    "archive"       { Show-Archive }
    "slim"          { Show-Slim }
    "commit"        { Invoke-Commit }
    "upgrade"       { Invoke-Upgrade }
    "budget"        { Show-Budget }
    "clean"         { Show-Clean }
    "help"          { Show-Help }
}
```

Replace with:
```powershell
switch ($Command) {
    "init"          { Invoke-Init }
    "doctor"        { Show-Doctor }
    "status"        { Show-Status }
    "query"         { Show-Query -Keyword $Arg }
    "clean"         { Show-Clean }
    "commit"        { Invoke-Commit }
    "upgrade"       { Invoke-Upgrade }
    "help"          { Show-Help }
    # Deprecated — redirect to replacement commands
    "install-hooks" { Write-Host "mb install-hooks is now part of mb upgrade. Run: mb upgrade" -ForegroundColor Yellow }
    "validate"      { Write-Host "mb validate has been integrated into mb doctor. Run: mb doctor" -ForegroundColor Yellow }
    "audit"         { Write-Host "mb audit has been integrated into mb doctor. Run: mb doctor" -ForegroundColor Yellow }
    "budget"        { Write-Host "mb budget has been integrated into mb doctor. Run: mb doctor" -ForegroundColor Yellow }
    "compact"       { Write-Host "mb compact has been consolidated into mb clean. Run: mb clean" -ForegroundColor Yellow }
    "update"        { Write-Host "mb update has been consolidated into mb clean. Run: mb clean" -ForegroundColor Yellow }
    "archive"       { Write-Host "mb archive has been consolidated into mb clean. Run: mb clean" -ForegroundColor Yellow }
    "slim"          { Write-Host "mb slim has been consolidated into mb clean. Run: mb clean" -ForegroundColor Yellow }
}
```

- [ ] **Step 3: Replace `Show-Help` function body (around line 41)**

Find the current `Show-Help` function body (lines 41–70) and replace with:
```powershell
function Show-Help {
    Write-Host ""
    Write-Host "Memory Bank Utility Commands" -ForegroundColor Cyan
    Write-Host "=============================" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "Usage: mb <command>" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "Commands:"
    Write-Host "  init          Initialize Memory Bank in the current project"
    Write-Host "  status        Quick state check — initialized, memory, context, standards, tasks"
    Write-Host "  doctor        Full diagnostic: health checks + lifecycle audit + structural validation + budget estimate"
    Write-Host "  query         Search memory-bank by tag or section header"
    Write-Host "  clean         Memory bank maintenance: slim check + unified cleanup prompt"
    Write-Host "  commit        Stage and commit Memory Bank changes"
    Write-Host "  upgrade       Propagate current governance templates to this project"
    Write-Host "  help          Show this help message"
    Write-Host ""
    Write-Host "Examples:"
    Write-Host "  mb doctor             Full diagnostic across all health areas"
    Write-Host "  mb query auth         Find files tagged auth/* or sections mentioning auth"
    Write-Host "  mb clean              Get maintenance prompt for memory bank cleanup"
    Write-Host ""
}
```

- [ ] **Step 4: Verify redirects and updated help**

```powershell
mb compact
# Expected: "mb compact has been consolidated into mb clean. Run: mb clean"

mb audit
# Expected: "mb audit has been integrated into mb doctor. Run: mb doctor"

mb install-hooks
# Expected: "mb install-hooks is now part of mb upgrade. Run: mb upgrade"

mb help
# Expected: lists exactly 8 commands — no validate, audit, compact, slim, etc.
```

- [ ] **Step 5: Commit**

```powershell
git add scripts/mb.ps1
git commit -m "feat(ps1): add deprecated command redirects, update help to 8 commands"
```

---

## Task 4: PS1 — Absorb install-hooks into `Invoke-Upgrade`

**Files:**
- Modify: `scripts/mb.ps1`

- [ ] **Step 1: Verify `mb upgrade --dry-run` does not mention install-hooks step**

```powershell
mb upgrade --dry-run | Select-String "install-hooks"
# Expected: no output (or only template file lines, not a hook-installation step)
```

- [ ] **Step 2: Insert install-hooks step after the TEMPLATE_OWNED processing block in `Invoke-Upgrade`**

Find this comment (around line 1340):
```powershell
    # Process ADVISORY_DIFF — compare and emit advisory diff, never write
```

Insert before it:
```powershell
    # Absorbed from install-hooks: wire .git/hooks/ after templates are current
    if (-not $DryRun) {
        Write-Host ""
        Write-Host "Installing git hooks..." -ForegroundColor Cyan
        Invoke-InstallHooks
    } else {
        Write-Host "[~?] .git/hooks/pre-push (would run install-hooks)" -ForegroundColor Yellow
    }

    # Process ADVISORY_DIFF — compare and emit advisory diff, never write
```

- [ ] **Step 3: Verify**

```powershell
mb upgrade --dry-run | Select-String "install-hooks"
# Expected: "[~?] .git/hooks/pre-push (would run install-hooks)"
```

- [ ] **Step 4: Commit**

```powershell
git add scripts/mb.ps1
git commit -m "feat(ps1): mb upgrade absorbs install-hooks step"
```

---

## Task 5: Bash — Add `show_clean` + update `show_help`

**Files:**
- Modify: `scripts/mb.sh`

- [ ] **Step 1: Verify baseline**

```bash
./scripts/mb.sh clean 2>&1
# Expected: "Unknown command: clean" (not in case statement yet)

./scripts/mb.sh help | grep "clean"
# Expected: no output
```

- [ ] **Step 2: Add `show_clean` function after the closing `}` of `show_slim` (around line 263)**

```bash
show_clean() {
    echo ""
    echo -e "${CYAN}Memory Bank Maintenance${NC}"
    echo -e "${CYAN}=======================${NC}"
    echo ""

    # Slim check
    echo -e "${YELLOW}--- Slim Check ---${NC}"
    SLIM_PATH="$MEMORY_BANK_PATH/activeContext.md"
    if [ -f "$SLIM_PATH" ]; then
        LINES=$(wc -l < "$SLIM_PATH" | tr -d ' ')
        echo "activeContext.md: $LINES lines (target: 50-100, max: 150)"
        if [ "$LINES" -gt 150 ]; then
            echo -e "${RED}ACTION NEEDED: File is over limit!${NC}"
        elif [ "$LINES" -gt 100 ]; then
            echo -e "${YELLOW}RECOMMENDED: Consider trimming${NC}"
        else
            echo -e "${GREEN}OK: File is within target range${NC}"
        fi
    else
        echo -e "${YELLOW}Warning: activeContext.md not found${NC}"
    fi
    echo ""

    # Unified maintenance prompt
    echo -e "${YELLOW}--- Maintenance Prompt ---${NC}"
    echo ""
    echo -e "${YELLOW}Paste this prompt to the AI to perform a full memory bank cleanup:${NC}"
    echo ""
    echo "---"
    cat << 'EOF'
Perform a full memory bank maintenance pass:

1. Archive old content from activeContext.md:
   - Move detailed session history to docs/archive/ (naming: context-YYYY-MM-<topic>.md)
   - Keep only current state and active next steps

2. Compact the memory bank (run after archiving):
   - Remove duplicate decisions (keep most recent/authoritative)
   - Surface contradictions for review — do not resolve them
   - Remove activeContext.md entries already captured in progress.md
   - Archive progress.md entries for work completed >6 months ago
   - Condense verbose descriptions to decision + rationale

3. Update all memory-bank files with any session progress:
   - activeContext.md (current focus, next steps)
   - progress.md (completed items)
   - techContext.md (if dependencies changed)
   - systemPatterns.md (if new patterns established)

Show a summary of what changed before committing.
EOF
    echo "---"
    echo ""
}
```

- [ ] **Step 3: Replace `show_help` function body (around line 41)**

Find the current `show_help` function and replace it:
```bash
show_help() {
    echo ""
    echo -e "${CYAN}Memory Bank Utility Commands${NC}"
    echo -e "${CYAN}=============================${NC}"
    echo ""
    echo -e "${YELLOW}Usage: mb <command>${NC}"
    echo ""
    echo "Commands:"
    echo "  init     Initialize Memory Bank in the current project"
    echo "  status   Quick state check — initialized, memory, context, standards, tasks"
    echo "  doctor   Full diagnostic: health checks + lifecycle audit + structural validation + budget estimate"
    echo "  query    Search memory-bank by tag or section header"
    echo "  clean    Memory bank maintenance: slim check + unified cleanup prompt"
    echo "  commit   Stage and commit Memory Bank changes"
    echo "  upgrade  Propagate current governance templates to this project"
    echo "  help     Show this help message"
    echo ""
    echo "Examples:"
    echo "  mb doctor             Full diagnostic across all health areas"
    echo "  mb query auth         Find files tagged auth/* or sections mentioning auth"
    echo "  mb clean              Get maintenance prompt for memory bank cleanup"
    echo ""
}
```

- [ ] **Step 4: Verify**

```bash
./scripts/mb.sh help | grep -E "^  (init|status|doctor|query|clean|commit|upgrade|help)"
# Expected: 8 lines, one per command

./scripts/mb.sh help | grep -E "validate|audit|compact|slim|archive|update|budget|install-hooks"
# Expected: no output
```

- [ ] **Step 5: Commit**

```bash
git add scripts/mb.sh
git commit -m "feat(bash): add show_clean, update show_help to 8 commands"
```

---

## Task 6: Bash — Expand `show_doctor` with 3 absorbed sections

**Files:**
- Modify: `scripts/mb.sh`

- [ ] **Step 1: Verify `mb doctor` does not show "Lifecycle Audit" yet**

```bash
./scripts/mb.sh doctor | grep "Lifecycle Audit"
# Expected: no output
```

- [ ] **Step 2: Find the closing `}` of `show_doctor` and add 3 section calls before it**

Locate `show_doctor` in `scripts/mb.sh`. The function ends with a blank `echo ""` and closing `}`. Before the final `}`, add:

```bash
    echo ""
    echo -e "${CYAN}=== Lifecycle Audit ===${NC}"
    show_audit

    echo -e "${CYAN}=== Structural Validation ===${NC}"
    show_validate

    echo -e "${CYAN}=== Budget Estimate ===${NC}"
    show_budget
```

- [ ] **Step 3: Verify**

```bash
./scripts/mb.sh doctor | grep "==="
# Expected:
# === Lifecycle Audit ===
# === Structural Validation ===
# === Budget Estimate ===
```

- [ ] **Step 4: Commit**

```bash
git add scripts/mb.sh
git commit -m "feat(bash): mb doctor absorbs audit, validate, budget"
```

---

## Task 7: Bash — Replace case statement dispatch

**Files:**
- Modify: `scripts/mb.sh`

- [ ] **Step 1: Verify `mb compact` runs old output**

```bash
./scripts/mb.sh compact | head -3
# Expected: first lines of old show_compact output (not a redirect)
```

- [ ] **Step 2: Replace the full case statement (around lines 1271–1291)**

Find:
```bash
case "$COMMAND" in
    init)     invoke_init ;;
    validate) show_validate ;;
    doctor)   show_doctor ;;
    status)   show_status ;;
    audit)    show_audit ;;
    query)    show_query "$ARG" ;;
    compact)  show_compact ;;
    update)   show_update ;;
    archive)  show_archive ;;
    slim)     show_slim ;;
    commit)   invoke_commit ;;
    upgrade)  invoke_upgrade ;;
    budget)   show_budget ;;
    help)     show_help ;;
    *)
        echo -e "${RED}Unknown command: $COMMAND${NC}"
        show_help
        exit 1
        ;;
esac
```

Replace with:
```bash
case "$COMMAND" in
    init)     invoke_init ;;
    doctor)   show_doctor ;;
    status)   show_status ;;
    query)    show_query "$ARG" ;;
    clean)    show_clean ;;
    commit)   invoke_commit ;;
    upgrade)  invoke_upgrade ;;
    help)     show_help ;;
    # Deprecated — redirect to replacement commands
    install-hooks) echo -e "${YELLOW}mb install-hooks is now part of mb upgrade. Run: mb upgrade${NC}" ;;
    validate)      echo -e "${YELLOW}mb validate has been integrated into mb doctor. Run: mb doctor${NC}" ;;
    audit)         echo -e "${YELLOW}mb audit has been integrated into mb doctor. Run: mb doctor${NC}" ;;
    budget)        echo -e "${YELLOW}mb budget has been integrated into mb doctor. Run: mb doctor${NC}" ;;
    compact)       echo -e "${YELLOW}mb compact has been consolidated into mb clean. Run: mb clean${NC}" ;;
    update)        echo -e "${YELLOW}mb update has been consolidated into mb clean. Run: mb clean${NC}" ;;
    archive)       echo -e "${YELLOW}mb archive has been consolidated into mb clean. Run: mb clean${NC}" ;;
    slim)          echo -e "${YELLOW}mb slim has been consolidated into mb clean. Run: mb clean${NC}" ;;
    *)
        echo -e "${RED}Unknown command: $COMMAND${NC}"
        show_help
        exit 1
        ;;
esac
```

- [ ] **Step 3: Verify**

```bash
./scripts/mb.sh compact
# Expected: "mb compact has been consolidated into mb clean. Run: mb clean"

./scripts/mb.sh clean
# Expected: slim check + maintenance prompt

./scripts/mb.sh audit
# Expected: "mb audit has been integrated into mb doctor. Run: mb doctor"
```

- [ ] **Step 4: Commit**

```bash
git add scripts/mb.sh
git commit -m "feat(bash): add deprecated command redirects, add clean to dispatch"
```

---

## Task 8: Bash — Absorb install-hooks into `invoke_upgrade`

**Files:**
- Modify: `scripts/mb.sh`

Reference: `Invoke-InstallHooks` in `scripts/mb.ps1` (lines 454–544) is the PS1 equivalent — read it to verify the hook shim content matches before committing.

- [ ] **Step 1: Find the end of TEMPLATE_OWNED processing in `invoke_upgrade` (around line 1191)**

Look for this comment immediately after the TEMPLATE_OWNED `done` loop:
```bash
    # Process ADVISORY_DIFF — compare and emit advisory diff, never write
```

- [ ] **Step 2: Insert install-hooks step before that comment**

```bash
    # Absorbed from install-hooks: wire .git/hooks/ after templates are current
    if [ "$DRY_RUN" != true ]; then
        echo ""
        echo -e "${CYAN}Installing git hooks...${NC}"
        HOOKS_DIR=".git/hooks"
        PRE_PUSH_SRC="scripts/pre-push-check.sh"
        PRE_PUSH_HOOK="$HOOKS_DIR/pre-push"
        if [ -d "$HOOKS_DIR" ] && [ -f "$PRE_PUSH_SRC" ]; then
            cat > "$PRE_PUSH_HOOK" << 'HOOK_EOF'
#!/bin/bash
# Memory Bank pre-push hook — do not edit; regenerated by mb upgrade
SCRIPT_DIR="$(cd "$(dirname "$0")/../.." && pwd)"
if [ -f "$SCRIPT_DIR/scripts/pre-push-check.sh" ]; then
    bash "$SCRIPT_DIR/scripts/pre-push-check.sh"
fi
HOOK_EOF
            chmod +x "$PRE_PUSH_HOOK"
            echo -e "${GREEN}[+] .git/hooks/pre-push installed${NC}"
        else
            echo -e "${YELLOW}[?] .git/hooks/pre-push skipped (scripts/pre-push-check.sh not found or .git/hooks/ missing)${NC}"
        fi
    else
        echo -e "${YELLOW}[~?] .git/hooks/pre-push (would run install-hooks)${NC}"
    fi

    # Process ADVISORY_DIFF — compare and emit advisory diff, never write
```

- [ ] **Step 3: Cross-check against PS1 version**

Read `scripts/mb.ps1` lines 454–544 (`Invoke-InstallHooks`). Confirm the hook shim path and file names match what the bash version above generates. Adjust if needed.

- [ ] **Step 4: Verify**

```bash
./scripts/mb.sh upgrade --dry-run 2>&1 | grep "install-hooks"
# Expected: "[~?] .git/hooks/pre-push (would run install-hooks)"
```

- [ ] **Step 5: Commit**

```bash
git add scripts/mb.sh
git commit -m "feat(bash): mb upgrade absorbs install-hooks step"
```

---

## Task 9: `CLAUDE.md` + `templates/CLAUDE.md` — Add MB Commands Protocol

**Files:**
- Modify: `CLAUDE.md`
- Modify: `templates/CLAUDE.md`

- [ ] **Step 1: Verify protocol section does not exist**

```powershell
Select-String "MB Commands Protocol" CLAUDE.md
# Expected: no output
```

- [ ] **Step 2: Add MB Commands Protocol to `CLAUDE.md` after the Handoff Protocol closing**

Find (around line 124):
```markdown
When starting a new conversation:
1. Check for `handoff.md` - if exists, read it FIRST
2. Merge info into Memory Bank
3. Delete `handoff.md`
4. Continue work

## Token Budget
```

Replace with:
```markdown
When starting a new conversation:
1. Check for `handoff.md` - if exists, read it FIRST
2. Merge info into Memory Bank
3. Delete `handoff.md`
4. Continue work

## MB Commands Protocol

When the user types "mb <subcommand>" (or "run mb <subcommand>"):

1. Run `mb <subcommand>` via shell (PowerShell on Windows, bash on Unix)
2. Report the output to the user

Recognized subcommands: `init`, `status`, `doctor`, `query`, `clean`, `commit`, `upgrade`, `help`

## Token Budget
```

- [ ] **Step 3: Apply identical change to `templates/CLAUDE.md`**

Find the same Handoff Protocol closing + Token Budget transition in `templates/CLAUDE.md` and apply the identical insertion from Step 2.

- [ ] **Step 4: Verify**

```powershell
Select-String "MB Commands Protocol" CLAUDE.md, templates/CLAUDE.md
# Expected: 2 matches (one per file)
```

- [ ] **Step 5: Commit**

```powershell
git add CLAUDE.md templates/CLAUDE.md
git commit -m "feat(claude): add MB Commands Protocol for natural language mb triggers"
```

---

## Task 10: Cursor Rules — Update Quick Commands table + add MB Commands Protocol

**Files:**
- Modify: `.cursor/rules/memory-bank.mdc`
- Modify: `templates/cursor/rules/memory-bank.mdc`

Both files are identical; apply the same edit to each.

- [ ] **Step 1: Replace the Quick Commands section in `.cursor/rules/memory-bank.mdc` (lines 70–82)**

Find:
```markdown
## Quick Commands

Recognize these shortcuts and respond accordingly:

| Command | Action |
|---------|--------|
| `mb update` | Update all relevant Memory Bank files based on current session |
| `mb status` | Show file sizes, last updated timestamps, and health check |
| `mb archive` | Move old session history from activeContext.md to AGENTS.md |
| `mb slim` | Trim activeContext.md to essentials (<100 lines target) |
| `mb commit` | Stage and commit all Memory Bank changes |

## Auto-Update Behavior
```

Replace with:
```markdown
## Quick Commands

Recognize these shortcuts and respond accordingly:

| Command | Action |
|---------|--------|
| `mb init` | Scaffold memory-bank/ in the current project |
| `mb status` | Quick state check — initialized, memory, context, standards, tasks |
| `mb doctor` | Full diagnostic: health checks + lifecycle audit + structural validation + budget estimate |
| `mb query <TAG>` | Search memory-bank by tag or section header |
| `mb clean` | Memory bank maintenance: slim check + unified cleanup prompt |
| `mb commit` | Stage and commit Memory Bank changes |
| `mb upgrade` | Propagate current governance templates to this project |
| `mb help` | Show all commands |

## MB Commands Protocol

When the user types "mb <subcommand>" (or "run mb <subcommand>"):

1. Run `mb <subcommand>` via shell (PowerShell on Windows, bash on Unix)
2. Report the output to the user

Recognized subcommands: `init`, `status`, `doctor`, `query`, `clean`, `commit`, `upgrade`, `help`

## Auto-Update Behavior
```

- [ ] **Step 2: Apply the identical change to `templates/cursor/rules/memory-bank.mdc`**

- [ ] **Step 3: Verify**

```powershell
Select-String "MB Commands Protocol" .cursor/rules/memory-bank.mdc, templates/cursor/rules/memory-bank.mdc
# Expected: 2 matches

Select-String "mb update|mb archive|mb slim" .cursor/rules/memory-bank.mdc
# Expected: no matches (deprecated commands removed from table)
```

- [ ] **Step 4: Commit**

```powershell
git add .cursor/rules/memory-bank.mdc templates/cursor/rules/memory-bank.mdc
git commit -m "feat(cursor): update Quick Commands to 8 commands, add MB Commands Protocol"
```

---

## Task 11: Update `docs/COMMANDS-REFERENCE.md`

**Files:**
- Modify: `docs/COMMANDS-REFERENCE.md`

- [ ] **Step 1: Replace the `mb` CLI command table (lines ~10–28)**

Find the table block starting with `| Command | What It Does | Output / Side Effect |` and replace the 8 deprecated rows. New complete table:

```markdown
| Command | What It Does | Output / Side Effect |
|---------|--------------|----------------------|
| `mb init` | Scaffold memory-bank/ in the current project | Creates 5 memory-bank files, `CLAUDE.md`, `.claude/settings.json`, hook scripts, slash commands, and 12 `standards/` files. Writes `.pmb-version`. Skips files that already exist. |
| `mb status` | Quick state check | 5 signals: Initialized, Core Memory Present, Active Context Current, Standards Available, Tasks Present. Green ✓ per signal; ⚠ items surface in an Attention section with remediation hint. |
| `mb doctor` | Full diagnostic | 14 health checks (git, templates, hooks, file sizes, standards presence, version tracking, startup token cost) + Lifecycle Audit (staleness per file) + Structural Validation (required files + frontmatter) + Budget Estimate (KB + token counts). |
| `mb query <TAG>` | Search memory-bank by tag or section header | Lists files with matching tags or `##` headings. Supports partial hierarchical match (`mb query auth` matches `auth/session`). |
| `mb clean` | Memory bank maintenance | Slim check (reports activeContext.md line count vs target) + unified AI prompt covering archive, compact, and update operations. |
| `mb commit` | Stage and commit Memory Bank changes | Runs `git add memory-bank/ CLAUDE.md` then `git commit` with a generated message. |
| `mb upgrade` | Propagate current governance templates to this project | TEMPLATE_OWNED: overwrites governance files. ADVISORY_DIFF: shows diffs for CLAUDE.md and agents. ADVISORY_CREATE: creates missing `standards/`. Runs install-hooks step. Writes `.pmb-version`. Supports `--dry-run`. |
| `mb help` | Show command list | Prints the 8 commands with one-line descriptions. |
```

Add a deprecated-commands note immediately below the table:

```markdown
> **Deprecated in v1.0.7:** `mb validate`, `mb audit`, `mb budget` → use `mb doctor`. `mb compact`, `mb update`, `mb archive`, `mb slim` → use `mb clean`. `mb install-hooks` → use `mb upgrade`. Deprecated names still accepted; each prints a redirect message.
```

- [ ] **Step 2: Update the `/health-check` description (~line 118)**

Find:
```markdown
Full PMB health check. Runs `mb doctor` + `mb validate` + `mb audit` and `git status`/`git log`, then prints a labeled summary with overall status (✅ / ⚠️ / ❌).
```
Replace with:
```markdown
Full PMB health check. Runs `mb doctor` (which includes lifecycle audit and structural validation) and `git status`/`git log`, then prints a labeled summary with overall status (✅ / ⚠️ / ❌).
```

- [ ] **Step 3: Verify no stale references remain**

```powershell
Select-String "mb validate|mb audit|mb compact|mb slim|mb archive|mb update \|| mb budget|mb install-hooks" docs/COMMANDS-REFERENCE.md
# Expected: only the deprecated note line (which is intentional)
```

- [ ] **Step 4: Commit**

```powershell
git add docs/COMMANDS-REFERENCE.md
git commit -m "docs: update COMMANDS-REFERENCE.md to 8-command surface (v1.0.7)"
```

---

## Task 12: Update `README.md` + `QUICK-REFERENCE.md`

**Files:**
- Modify: `README.md`
- Modify: `QUICK-REFERENCE.md`

### README.md

- [ ] **Step 1: Update command count in the feature table (~line 18)**

Find:
```markdown
| `mb` CLI | init, status, validate, audit, query, compact, budget, upgrade, doctor, commit, install-hooks (15 commands) |
```
Replace with:
```markdown
| `mb` CLI | init, status, doctor, query, clean, commit, upgrade, help (8 commands) |
```

- [ ] **Step 2: Replace the command list code block (~lines 73–84)**

Find the code block starting `mb status     Quick state check...` (7–9 lines listing commands) and replace with:
```
mb status     Quick state check — initialized, memory fresh, standards loaded, tasks tracked
mb doctor     Full diagnostic — health checks, lifecycle audit, structural validation, budget estimate
mb query TAG  Find all memory tagged with TAG (e.g. mb query auth)
mb clean      Get maintenance prompt for memory bank cleanup (slim check + archive + compact + update)
mb commit     Commit memory bank changes separately from feature code
mb upgrade    Pull latest templates and standards from the memory bank repo; installs git hooks
mb help       Full command list
```

- [ ] **Step 3: Update inline reference (~line 167)**

Find:
```markdown
Run `mb audit` to see which files are stale. Run `mb compact` to get an AI prompt that deduplicates and summarizes memory.
```
Replace with:
```markdown
Run `mb doctor` to see which files are stale. Run `mb clean` to get a maintenance prompt that deduplicates and summarizes memory.
```

- [ ] **Step 4: Update inline reference (~line 277)**

Find:
```markdown
Run `mb doctor` to see which file is over its target. Run `mb compact` to get an AI prompt that rewrites and deduplicates memory.
```
Replace with:
```markdown
Run `mb doctor` to see which file is over its target. Run `mb clean` to get a maintenance prompt that rewrites and deduplicates memory.
```

### QUICK-REFERENCE.md

- [ ] **Step 5: Replace the command table (~lines 20–38)**

Find the table block starting `| Command | What It Does |` and replace with:
```markdown
| Command | What It Does |
|---------|--------------|
| `mb init` | Scaffold memory-bank/ in the current project |
| `mb status` | Quick state check — initialized, memory fresh, standards loaded, tasks tracked |
| `mb doctor` | Full diagnostic — health checks, lifecycle audit, structural validation, budget |
| `mb query TAG` | Find all memory tagged with TAG |
| `mb clean` | Get maintenance prompt: slim check + archive + compact + update in one |
| `mb commit` | Commit Memory Bank changes separately from feature code |
| `mb upgrade` | Pull latest templates and standards; installs git hooks |
| `Handoff` | Create handoff.md and stop |
| `/pmb-status` | Quick state check — the `git status` of PMB; run at session start or before beginning work |
| `/feature-dev` | Run full 7-phase workflow (Claude Code) |
| `/security-review` | Scan diff for 9 security patterns (Claude Code) |
| `/code-review` | Multi-agent deep review: 5 domain agents (Security, Correctness, Maintainability, Testing, Architecture Drift) + conditional Performance/Accessibility agents + opposition review (Claude Code / Cursor) |
| `/test-audit` | Audit test coverage for changed files or full project; reports missing tests, empty test files, framework config, CI test step (Claude Code) |
| `/health-check` | Full PMB health check — runs `mb doctor` and prints summary (PMB repo only) |
```

- [ ] **Step 6: Update Common Issues table (~line 157)**

Find:
```markdown
| Files too large | Run `mb compact` to deduplicate; run `mb doctor` to verify sizes |
```
Replace with:
```markdown
| Files too large | Run `mb clean` to get a maintenance prompt; run `mb doctor` to verify sizes |
```

- [ ] **Step 7: Update Daily Workflow (~line 181)**

Find `"mb update"` in the daily workflow line and replace with `"mb clean"`.

- [ ] **Step 8: Verify both files are clean**

```powershell
Select-String "mb validate|mb audit|mb compact|mb slim|mb archive| mb update|mb budget|mb install-hooks" README.md, QUICK-REFERENCE.md
# Expected: no matches
```

- [ ] **Step 9: Commit**

```powershell
git add README.md QUICK-REFERENCE.md
git commit -m "docs: update README, QUICK-REFERENCE to 8-command surface (v1.0.7)"
```

---

## Task 13: Update `docs/SETUP-GUIDE.md`, `docs/UPGRADE.md`, `docs/RECOVERY.md`

**Files:**
- Modify: `docs/SETUP-GUIDE.md`
- Modify: `docs/UPGRADE.md`
- Modify: `docs/RECOVERY.md`

### docs/SETUP-GUIDE.md

- [ ] **Step 1: Update "During Development" section (~line 220)**

Find:
```markdown
- `mb update` - Update files after changes
```
Replace with:
```markdown
- `mb clean` - Memory bank maintenance (slim check + cleanup prompt)
```

- [ ] **Step 2: Update "Memory Bank Files Too Large" troubleshooting (~line 245)**

Find:
```markdown
Run `mb compact` to get an AI prompt that deduplicates and summarizes memory, or manually:
```
Replace with:
```markdown
Run `mb clean` to get a maintenance prompt that archives, deduplicates, and summarizes memory, or manually:
```

### docs/UPGRADE.md

- [ ] **Step 3: Update new features mention (~line 13)**

Find:
```markdown
Upgrade when you want new features (`mb audit`, `mb compact`, etc.) or when `mb doctor` reports issues.
```
Replace with:
```markdown
Upgrade when you want new features (`mb doctor`, `mb clean`, etc.) or when `mb doctor` reports issues.
```

- [ ] **Step 4: Update upgrade steps (~line 38)**

Find:
```markdown
mb validate          # is anything missing?
mb doctor            # any new health checks failing?
```
Replace with:
```markdown
mb doctor            # full diagnostic — checks health, validates structure, runs audit
```

### docs/RECOVERY.md

- [ ] **Step 5: Update Quick Triage section (~line 9)**

Find:
```markdown
mb doctor     ← run this first, always
mb validate   ← check files and frontmatter specifically
mb status     ← quick state check (initialized, memory, context, standards, tasks)
```
Replace with:
```markdown
mb doctor     ← run this first, always (includes structural validation and lifecycle audit)
mb status     ← quick state check (initialized, memory, context, standards, tasks)
```

- [ ] **Step 6: Update Scenario 1 diagnose step (~line 23)**

Find:
```markdown
**Diagnose:**
```
mb validate
```
```
Replace with:
```markdown
**Diagnose:**
```
mb doctor
```
```

- [ ] **Step 7: Update Scenario 3 symptoms (~line 63)**

Find:
```markdown
**Symptoms:** `mb audit` shows `NO FRONTMATTER`, `mb validate` warns about missing fields.
```
Replace with:
```markdown
**Symptoms:** `mb doctor` reports `NO FRONTMATTER` or warns about missing fields.
```

- [ ] **Step 8: Update Scenario 3 fix confirmation (~line 81)**

Find:
```markdown
Then run `mb validate` to confirm it's recognized.
```
Replace with:
```markdown
Then run `mb doctor` to confirm it's recognized.
```

- [ ] **Step 9: Update Scenario 5 fix confirmation (~line 112)**

Find:
```markdown
Run `mb validate` to confirm frontmatter survived intact
```
Replace with:
```markdown
Run `mb doctor` to confirm frontmatter survived intact
```

- [ ] **Step 10: Update Scenario 7 steps (~lines 131–136)**

Find:
```markdown
1. Run `mb audit` to see which files are flagged
2. Run `mb compact` to get an AI prompt that rewrites memory to current state
3. After compaction, update `last-reviewed` dates (the hook does this automatically on save, or `mb audit` will reflect the new dates after you've edited the files)
4. Run `mb validate` to confirm health
```
Replace with:
```markdown
1. Run `mb doctor` to see which files are flagged
2. Run `mb clean` to get a maintenance prompt that rewrites memory to current state
3. After cleanup, `last-reviewed` dates update automatically via the PostToolUse hook on save
4. Run `mb doctor` again to confirm health
```

- [ ] **Step 11: Verify all three files are clean**

```powershell
Select-String "mb validate|mb audit|mb compact|mb slim|mb archive|mb update \|| mb budget|mb install-hooks" docs/SETUP-GUIDE.md, docs/UPGRADE.md, docs/RECOVERY.md
# Expected: no matches
```

- [ ] **Step 12: Commit**

```powershell
git add docs/SETUP-GUIDE.md docs/UPGRADE.md docs/RECOVERY.md
git commit -m "docs: update SETUP-GUIDE, UPGRADE, RECOVERY to 8-command surface (v1.0.7)"
```

---

## Task 14: `CHANGELOG.md` + `VERSION` + close contract + final verification

**Files:**
- Modify: `CHANGELOG.md`
- Modify: `VERSION`
- Modify: `.claude/contracts/active-task.json`

- [ ] **Step 1: Bump `VERSION` to 1.0.7**

Replace entire file content with:
```
1.0.7
```

- [ ] **Step 2: Add v1.0.7 entry to the top of `CHANGELOG.md`** (before the current first entry)

```markdown
## [1.0.7] — 2026-06-04

### Added
- `mb clean` command — replaces `mb compact`, `mb update`, `mb archive`, `mb slim` with a single maintenance entry point: slim check + combined AI prompt for archive, compact, and update operations
- MB Commands Protocol in `CLAUDE.md`, `templates/CLAUDE.md`, `.cursor/rules/memory-bank.mdc`, and `templates/cursor/rules/memory-bank.mdc` — Claude now responds to natural language `mb <command>` triggers

### Changed
- `mb doctor` now includes Lifecycle Audit (from `mb audit`), Structural Validation (from `mb validate`), and Budget Estimate (from `mb budget`) as integrated output sections after the 14 health checks
- `mb upgrade` now runs the install-hooks step automatically after TEMPLATE_OWNED processing
- `mb help` lists 8 commands (was 15)
- All documentation updated to reference the 8-command surface

### Deprecated (redirect messages printed; not removed from ValidateSet)
- `mb validate`, `mb audit`, `mb budget` → `mb doctor`
- `mb compact`, `mb update`, `mb archive`, `mb slim` → `mb clean`
- `mb install-hooks` → `mb upgrade`

### Breaking Change
- None — deprecated commands remain in ValidateSet and print a helpful redirect message

```

- [ ] **Step 3: Close the Task Contract**

Update `.claude/contracts/active-task.json`:
```json
{
  "task": "v1.0.7 MB commands redesign",
  "status": "complete"
}
```

- [ ] **Step 4: Run full end-to-end verification**

```powershell
# Script surface
mb help
# Expected: lists exactly 8 commands

mb doctor | Select-String "==="
# Expected: 3 lines — Lifecycle Audit, Structural Validation, Budget Estimate

mb clean | head -5
# Expected: "Memory Bank Maintenance" header + slim check

mb compact
# Expected: redirect message "mb compact has been consolidated into mb clean..."

mb upgrade --dry-run | Select-String "install-hooks"
# Expected: "[~?] .git/hooks/pre-push (would run install-hooks)"

# Doc cleanliness
Select-String "mb validate|mb audit|mb compact|mb slim|mb archive| mb update|mb budget|mb install-hooks" README.md, QUICK-REFERENCE.md, docs/COMMANDS-REFERENCE.md, docs/SETUP-GUIDE.md, docs/UPGRADE.md, docs/RECOVERY.md
# Expected: no matches (CHANGELOG entries are the only place these appear)
```

- [ ] **Step 5: Commit version files**

```powershell
git add CHANGELOG.md VERSION .claude/contracts/active-task.json
git commit -m "chore: bump to v1.0.7 (mb commands redesign)"
```

- [ ] **Step 6: Update memory bank**

```
Tell the AI: "Update memory-bank/activeContext.md and memory-bank/progress.md to reflect that v1.0.7 shipped:
MB Commands Protocol added to CLAUDE.md and Cursor rules, 15-command surface consolidated to 8 (mb clean + mb doctor expansion + mb upgrade absorbs install-hooks), all docs updated."
```

- [ ] **Step 7: Commit memory bank**

```powershell
git add memory-bank/
git commit -m "chore: update memory bank for v1.0.7"
```
