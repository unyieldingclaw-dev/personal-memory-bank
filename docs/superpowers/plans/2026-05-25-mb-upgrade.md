# mb upgrade — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add `mb upgrade` subcommand that propagates current governance templates to an existing project, and patch the comment provenance drift gap in the Cursor rule file.

**Architecture:** Two deliverables in one feature branch. Deliverable 1 is surgical (3-line insert into a template file). Deliverable 2 adds ~90 lines to each of `scripts/mb.sh` and `scripts/mb.ps1`, following existing patterns: an `invoke_upgrade()` / `Invoke-Upgrade` function inserted before the routing block, plus entries in `show_help` / `Show-Help` and the `case` / `switch` dispatcher. Template-to-target path mapping is NOT a naive 1:1 because `.cursor/rules/` lives at `templates/cursor/rules/` (no dot) and `.claude/commands/` maps from `templates/claude-commands/`. All other paths are direct.

**Tech Stack:** bash (mb.sh, shellcheck-clean), PowerShell 7+ (mb.ps1), Git

---

## Critical Path Mappings

These non-obvious mappings must be encoded in the helper function — a naive `$TEMPLATES_DIR/$target` will not work for cursor rules or claude-commands:

| Target path (in project) | Template source path |
|--------------------------|----------------------|
| `.cursor/rules/X` | `$TEMPLATES_DIR/cursor/rules/X` |
| `.claude/commands/X` | `$TEMPLATES_DIR/claude-commands/X` |
| `.claude/settings.json` | `$TEMPLATES_DIR/.claude/settings.json` |
| `scripts/X` | `$TEMPLATES_DIR/scripts/X` |
| `CLAUDE.md` | `$TEMPLATES_DIR/CLAUDE.md` |
| `.claude/agents/X` | `$TEMPLATES_DIR/.claude/agents/X` |

---

## Files Modified

| File | Change |
|------|--------|
| `templates/cursor/rules/code-quality.mdc` | Add 3-line comment provenance anchor under `## Comments / ### DO` |
| `scripts/mb.sh` | Add `upgrade` to `show_help()`, case dispatcher, and add `invoke_upgrade()` function (~90 lines) |
| `scripts/mb.ps1` | Add `upgrade` to `Show-Help`, `ValidateSet`, switch dispatcher, and add `Invoke-Upgrade` function (~90 lines) |

No new files.

---

## Task 1: Create feature branch

**Files:** (none modified)

- [ ] **Step 1: Create and switch to branch**

```bash
git checkout -b feat/mb-upgrade
```

- [ ] **Step 2: Verify**

```bash
git branch --show-current
```

Expected output: `feat/mb-upgrade`

---

## Task 2: Add comment provenance anchor to Cursor rule file

**Files:**
- Modify: `templates/cursor/rules/code-quality.mdc` (lines 19–24)

**Context:** The `## Comments / ### DO` section currently has 4 bullet points. The comment provenance anchor (3 lines) was added to `CLAUDE.md` and `templates/CLAUDE.md` in PR #2 but never to the Cursor rule file. This is the governance drift gap.

Current content of that section (lines 19–24):
```
### DO
- Add WHY comments for non-obvious logic
- Document breaking changes
- Explain trade-offs and constraints
- Note workarounds and their reasons
```

- [ ] **Step 1: Insert the 3-line anchor after "Add WHY comments for non-obvious logic"**

The new content of the `### DO` block should be:
```
### DO
- Add WHY comments for non-obvious logic
- Comment the WHY, not the WHAT
- Do not invent rationale, optimization claims, or historical intent not supported by observable behavior, documentation, or explicit project guidance
- Treat dead-code identification as advisory unless non-use can be proven deterministically
- Document breaking changes
- Explain trade-offs and constraints
- Note workarounds and their reasons
```

Edit `templates/cursor/rules/code-quality.mdc`, old_string:
```
- Add WHY comments for non-obvious logic
- Document breaking changes
```

New_string:
```
- Add WHY comments for non-obvious logic
- Comment the WHY, not the WHAT
- Do not invent rationale, optimization claims, or historical intent not supported by observable behavior, documentation, or explicit project guidance
- Treat dead-code identification as advisory unless non-use can be proven deterministically
- Document breaking changes
```

- [ ] **Step 2: Verify the edit is correct**

Read lines 19–30 of `templates/cursor/rules/code-quality.mdc` and confirm the 3 lines appear between "Add WHY comments" and "Document breaking changes".

- [ ] **Step 3: Commit**

```bash
git add templates/cursor/rules/code-quality.mdc
git commit -m "fix: add comment provenance anchor to cursor code-quality rule

Closes governance intent parity gap opened in PR #2: the 3-line
comment provenance anchor was added to CLAUDE.md and templates/CLAUDE.md
but not to templates/cursor/rules/code-quality.mdc."
```

---

## Task 3: Wire `upgrade` into help and routing (both scripts)

**Files:**
- Modify: `scripts/mb.sh` — `show_help()` (lines 41–68) and case statement (lines 819–838)
- Modify: `scripts/mb.ps1` — `Show-Help` (lines 38–65), `ValidateSet` in param block (line 23), and switch statement (lines 879–893)

This task does NOT add the implementation function yet — that comes in Tasks 4 and 5. The intermediate state (routing wired, function not yet defined) is safe: bash functions are looked up at call time, and calling `mb upgrade` before the function is defined will produce a clear "function not found" error rather than silent failure.

- [ ] **Step 1: Add `upgrade` line to `show_help()` in `scripts/mb.sh`**

Insert after the `commit` line and before the `budget` line in the `echo "Commands:"` block:

Old string:
```
  echo "  commit   Stage and commit Memory Bank changes"
  echo "  budget   Check token budget health (CLAUDE.md + memory-bank/ sizes)"
```

New string:
```
  echo "  commit   Stage and commit Memory Bank changes"
  echo "  upgrade  Propagate current governance templates to this project"
  echo "  budget   Check token budget health (CLAUDE.md + memory-bank/ sizes)"
```

- [ ] **Step 2: Add `upgrade` to the case statement in `scripts/mb.sh`**

Old string (near line 830):
```
    commit)   invoke_commit ;;
    budget)   show_budget ;;
```

New string:
```
    commit)   invoke_commit ;;
    upgrade)  invoke_upgrade ;;
    budget)   show_budget ;;
```

- [ ] **Step 3: Add `upgrade` line to `Show-Help` in `scripts/mb.ps1`**

Old string:
```
    Write-Host "  commit   Stage and commit Memory Bank changes"
    Write-Host "  budget   Check token budget health (CLAUDE.md + memory-bank/ sizes)"
```

New string:
```
    Write-Host "  commit   Stage and commit Memory Bank changes"
    Write-Host "  upgrade  Propagate current governance templates to this project"
    Write-Host "  budget   Check token budget health (CLAUDE.md + memory-bank/ sizes)"
```

- [ ] **Step 4: Add `"upgrade"` to `ValidateSet` in `scripts/mb.ps1`**

Old string (line 23):
```
    [ValidateSet("init", "validate", "doctor", "status", "audit", "query", "compact", "update", "archive", "slim", "commit", "budget", "help")]
```

New string:
```
    [ValidateSet("init", "validate", "doctor", "status", "audit", "query", "compact", "update", "archive", "slim", "commit", "upgrade", "budget", "help")]
```

- [ ] **Step 5: Add `upgrade` to the switch statement in `scripts/mb.ps1`**

Old string (near line 890):
```
    "commit"  { Invoke-Commit }
    "budget"  { Show-Budget }
```

New string:
```
    "commit"  { Invoke-Commit }
    "upgrade" { Invoke-Upgrade }
    "budget"  { Show-Budget }
```

- [ ] **Step 6: Verify help output**

```bash
bash scripts/mb.sh help
```

Expected: `upgrade  Propagate current governance templates to this project` appears in the Commands list.

- [ ] **Step 7: Commit**

```bash
git add scripts/mb.sh scripts/mb.ps1
git commit -m "feat: wire upgrade subcommand into help and routing"
```

---

## Task 4: Add `invoke_upgrade()` to `scripts/mb.sh`

**Files:**
- Modify: `scripts/mb.sh` — insert `invoke_upgrade()` before `case "$COMMAND" in` (currently line 819)

**Critical:** The script uses `set -e`. All commands that can return non-zero must be wrapped in conditionals or `|| true`. The `diff` command exits 1 when files differ — capture it with `|| true`. The `cmp -s` command is safe inside `if` conditionals.

- [ ] **Step 1: Insert `invoke_upgrade()` before the case statement**

Find the line `case "$COMMAND" in` and insert the full function immediately before it. The old_string anchor:

```
case "$COMMAND" in
    init)     invoke_init ;;
```

New string (insert the function before the case):

```bash
invoke_upgrade() {
    DRY_RUN=false
    if [ "$ARG" = "--dry-run" ]; then
        DRY_RUN=true
    fi

    echo ""
    echo -e "${CYAN}mb upgrade${NC}"
    echo -e "${CYAN}==========${NC}"
    if [ "$DRY_RUN" = true ]; then
        echo -e "${YELLOW}(dry run — no files will be written)${NC}"
    fi
    echo ""

    # WHY: upgrade requires an mb-managed project; memory-bank/ is the sentinel.
    # Without this gate, upgrade could silently run in unrelated directories.
    if [ ! -d "memory-bank" ]; then
        echo -e "${RED}Error: No memory-bank/ directory found. Run 'mb upgrade' from the root of an mb-managed project.${NC}"
        exit 1
    fi

    TEMPLATES_DIR="$REPO_ROOT/templates"
    if [ ! -d "$TEMPLATES_DIR" ]; then
        echo -e "${RED}Error: Templates not found at $TEMPLATES_DIR${NC}"
        echo -e "${YELLOW}Set MB_HOME or run from the memory-bank repo.${NC}"
        exit 1
    fi

    # WHY: Ownership is hardcoded as explicit arrays — NOT a config file.
    # Ownership semantics are behavior, not data. A config file would invite
    # accidental expansion of overwrite scope. Rationale comments are per-group.
    TEMPLATE_OWNED=(
        # Cursor governance rules — pure governance substrate, no project customization expected
        ".cursor/rules/code-quality.mdc"
        ".cursor/rules/memory-bank.mdc"
        ".cursor/rules/workflow.mdc"
        ".cursor/rules/security.mdc"
        ".cursor/rules/code-review.mdc"
        ".cursor/rules/rules-file-integrity.mdc"
        # Claude Code settings — hook wiring, not project-specific
        ".claude/settings.json"
        # Hook scripts — deterministic enforcement scripts, no project customization
        "scripts/dangerous-commands.sh"
        "scripts/dangerous-commands.ps1"
        "scripts/check-contract.sh"
        "scripts/check-contract.ps1"
        "scripts/update-reviewed.sh"
        "scripts/update-reviewed.ps1"
        # Slash commands — governance workflow commands from templates, not project-specific
        ".claude/commands/code-review.md"
        ".claude/commands/feature-dev.md"
        ".claude/commands/security-review.md"
    )

    ADVISORY_DIFF=(
        # CLAUDE.md is a user cognition surface — users annotate it with project-specific guidance
        "CLAUDE.md"
        # Agent definitions likely contain project-specific tool lists and instructions
        ".claude/agents/researcher.md"
        ".claude/agents/security-reviewer.md"
    )

    # WHY: Template source paths are NOT a 1:1 mirror of target paths.
    # .cursor/rules/X lives at templates/cursor/rules/X (no dot prefix) because
    # the templates directory uses non-hidden layout. .claude/commands/X maps to
    # templates/claude-commands/X (different directory name). All other targets
    # resolve directly under $TEMPLATES_DIR.
    _upgrade_src() {
        local target="$1"
        case "$target" in
            .cursor/rules/*)    echo "$TEMPLATES_DIR/cursor/rules/${target#.cursor/rules/}" ;;
            .claude/commands/*) echo "$TEMPLATES_DIR/claude-commands/${target#.claude/commands/}" ;;
            *)                  echo "$TEMPLATES_DIR/$target" ;;
        esac
    }

    # Process TEMPLATE_OWNED — overwrite unconditionally if stale
    for target in "${TEMPLATE_OWNED[@]}"; do
        src="$(_upgrade_src "$target")"
        if [ ! -f "$src" ]; then
            echo -e "${YELLOW}[?] $target (template-owned source missing — skipped)${NC}"
            continue
        fi
        if [ ! -f "$target" ]; then
            if [ "$DRY_RUN" = true ]; then
                echo -e "${GREEN}[+?] $target (would add)${NC}"
            else
                mkdir -p "$(dirname "$target")"
                cp "$src" "$target"
                echo -e "${GREEN}[+] $target (added)${NC}"
            fi
        elif cmp -s "$src" "$target"; then
            echo -e "${GRAY}[=] $target (unchanged)${NC}"
        else
            if [ "$DRY_RUN" = true ]; then
                echo -e "${YELLOW}[~?] $target (would update)${NC}"
            else
                cp "$src" "$target"
                echo -e "${YELLOW}[~] $target (updated)${NC}"
            fi
        fi
    done

    # Process ADVISORY_DIFF — compare and emit advisory diff, never write
    for target in "${ADVISORY_DIFF[@]}"; do
        src="$(_upgrade_src "$target")"
        if [ ! -f "$src" ]; then
            echo -e "${YELLOW}[?] $target (advisory source missing — cannot compare)${NC}"
            continue
        fi
        if [ ! -f "$target" ]; then
            echo -e "${GRAY}[=] $target (not present in project — no action needed)${NC}"
            continue
        fi
        if cmp -s "$src" "$target"; then
            echo -e "${GRAY}[=] $target (matches template)${NC}"
        else
            echo -e "${YELLOW}[!] $target (differs from template — review manually)${NC}"
            if command -v diff >/dev/null 2>&1; then
                # WHY: diff exits 1 when files differ; || true prevents set -e from aborting.
                DIFF_OUTPUT=$(diff -u "$src" "$target" 2>/dev/null || true)
                DIFF_LINES=$(printf '%s' "$DIFF_OUTPUT" | wc -l)
                if [ "$DIFF_LINES" -le 20 ]; then
                    printf '%s\n' "$DIFF_OUTPUT" | sed 's/^/    /'
                else
                    printf '%s\n' "$DIFF_OUTPUT" | head -n 20 | sed 's/^/    /'
                    REMAINING=$((DIFF_LINES - 20))
                    echo "    ... ($REMAINING more lines — compare manually with: diff $src $target)"
                fi
            else
                echo "    (diff not available — compare manually with: diff $src $target)"
            fi
        fi
    done

    echo ""
}

case "$COMMAND" in
    init)     invoke_init ;;
```

- [ ] **Step 2: Run shellcheck to confirm no warnings**

```bash
shellcheck --severity=error scripts/mb.sh
```

Expected: no output (passes with zero errors).

- [ ] **Step 3: Verify dry-run from this repo (which IS an mb-managed project)**

```bash
bash scripts/mb.sh upgrade --dry-run
```

Expected output structure (exact statuses will vary based on current project state):
- `mb upgrade` header printed
- `(dry run — no files will be written)` line printed
- One status line per TEMPLATE_OWNED entry (`[=]`, `[+?]`, or `[~?]` — never `[+]` or `[~]`)
- One status line per ADVISORY_DIFF entry (`[=]` or `[!]`)
- No files written

- [ ] **Step 4: Verify error case — run from a directory without memory-bank/**

```bash
mkdir /tmp/no-mb-test && cd /tmp/no-mb-test
bash /path/to/scripts/mb.sh upgrade
```

Expected: `Error: No memory-bank/ directory found. Run 'mb upgrade' from the root of an mb-managed project.`

Then `cd -` back to project root.

- [ ] **Step 5: Commit**

```bash
git add scripts/mb.sh
git commit -m "feat: add invoke_upgrade() to mb.sh"
```

---

## Task 5: Add `Invoke-Upgrade` to `scripts/mb.ps1`

**Files:**
- Modify: `scripts/mb.ps1` — insert `Invoke-Upgrade` before `# Run command` (currently line 878)

**Notes for PowerShell:**
- Use `Get-FileHash` (available in PS4+/PS7) for byte-identical comparison instead of `cmp -s`
- Forward slashes in target paths work natively in PS7 on Windows (no replacement needed)
- Check for `diff` with `Get-Command diff -ErrorAction SilentlyContinue`; it may not exist on Windows (fall back to advisory message)
- Comments inside `@()` arrays work in PS7 — `#` starts a comment to end-of-line
- `Invoke-Upgrade` uses `$Arg` (defined in the param block at the top of the script) and `$RepoRoot` (also from the param block)
- The nested `Get-TemplateSrc` function uses `$TemplatesDir` from the outer function scope via closure — same pattern as `Copy-IfNew` in `Invoke-Init`

- [ ] **Step 1: Insert `Invoke-Upgrade` before the `# Run command` comment**

Old_string anchor:
```
# Run command
switch ($Command) {
    "init"    { Invoke-Init }
```

New string:

```powershell
function Invoke-Upgrade {
    $dryRun = $false
    if ($Arg -eq "--dry-run") { $dryRun = $true }

    Write-Host ""
    Write-Host "mb upgrade" -ForegroundColor Cyan
    Write-Host "==========" -ForegroundColor Cyan
    if ($dryRun) { Write-Host "(dry run — no files will be written)" -ForegroundColor Yellow }
    Write-Host ""

    # WHY: upgrade requires an mb-managed project; memory-bank/ is the sentinel.
    # Without this gate, upgrade could silently run in unrelated directories.
    if (-not (Test-Path "memory-bank")) {
        Write-Host "Error: No memory-bank/ directory found. Run 'mb upgrade' from the root of an mb-managed project." -ForegroundColor Red
        exit 1
    }

    $TemplatesDir = Join-Path $RepoRoot "templates"
    if (-not (Test-Path $TemplatesDir)) {
        Write-Host "Error: Templates not found at $TemplatesDir" -ForegroundColor Red
        Write-Host "Set MB_HOME or run from the memory-bank repo." -ForegroundColor Yellow
        exit 1
    }

    # WHY: Ownership is hardcoded as explicit arrays — NOT a config file.
    # Ownership semantics are behavior, not data. A config file would invite
    # accidental expansion of overwrite scope. Rationale comments are per-group.
    $templateOwned = @(
        # Cursor governance rules — pure governance substrate, no project customization expected
        ".cursor/rules/code-quality.mdc"
        ".cursor/rules/memory-bank.mdc"
        ".cursor/rules/workflow.mdc"
        ".cursor/rules/security.mdc"
        ".cursor/rules/code-review.mdc"
        ".cursor/rules/rules-file-integrity.mdc"
        # Claude Code settings — hook wiring, not project-specific
        ".claude/settings.json"
        # Hook scripts — deterministic enforcement scripts, no project customization
        "scripts/dangerous-commands.sh"
        "scripts/dangerous-commands.ps1"
        "scripts/check-contract.sh"
        "scripts/check-contract.ps1"
        "scripts/update-reviewed.sh"
        "scripts/update-reviewed.ps1"
        # Slash commands — governance workflow commands from templates, not project-specific
        ".claude/commands/code-review.md"
        ".claude/commands/feature-dev.md"
        ".claude/commands/security-review.md"
    )

    $advisoryDiff = @(
        # CLAUDE.md is a user cognition surface — users annotate it with project-specific guidance
        "CLAUDE.md"
        # Agent definitions likely contain project-specific tool lists and instructions
        ".claude/agents/researcher.md"
        ".claude/agents/security-reviewer.md"
    )

    # WHY: Template source paths are NOT a 1:1 mirror of target paths.
    # .cursor/rules/X -> templates/cursor/rules/X (no dot prefix)
    # .claude/commands/X -> templates/claude-commands/X (different directory name)
    # All other targets resolve directly under $TemplatesDir.
    function Get-TemplateSrc {
        param([string]$Target)
        if ($Target -like ".cursor/rules/*") {
            return Join-Path $TemplatesDir ("cursor/rules/" + $Target.Substring(".cursor/rules/".Length))
        } elseif ($Target -like ".claude/commands/*") {
            return Join-Path $TemplatesDir ("claude-commands/" + $Target.Substring(".claude/commands/".Length))
        } else {
            return Join-Path $TemplatesDir $Target
        }
    }

    # Process TEMPLATE_OWNED — overwrite unconditionally if stale
    foreach ($target in $templateOwned) {
        $src = Get-TemplateSrc -Target $target
        if (-not (Test-Path $src)) {
            Write-Host "[?] $target (template-owned source missing — skipped)" -ForegroundColor Yellow
            continue
        }
        if (-not (Test-Path $target)) {
            if ($dryRun) {
                Write-Host "[+?] $target (would add)" -ForegroundColor Green
            } else {
                $dir = Split-Path -Parent $target
                if ($dir -and -not (Test-Path $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
                Copy-Item -Path $src -Destination $target -Force
                Write-Host "[+] $target (added)" -ForegroundColor Green
            }
        } elseif ((Get-FileHash $src).Hash -eq (Get-FileHash $target).Hash) {
            Write-Host "[=] $target (unchanged)" -ForegroundColor DarkGray
        } else {
            if ($dryRun) {
                Write-Host "[~?] $target (would update)" -ForegroundColor Yellow
            } else {
                Copy-Item -Path $src -Destination $target -Force
                Write-Host "[~] $target (updated)" -ForegroundColor Yellow
            }
        }
    }

    # Process ADVISORY_DIFF — compare and emit advisory diff, never write
    foreach ($target in $advisoryDiff) {
        $src = Get-TemplateSrc -Target $target
        if (-not (Test-Path $src)) {
            Write-Host "[?] $target (advisory source missing — cannot compare)" -ForegroundColor Yellow
            continue
        }
        if (-not (Test-Path $target)) {
            Write-Host "[=] $target (not present in project — no action needed)" -ForegroundColor DarkGray
            continue
        }
        if ((Get-FileHash $src).Hash -eq (Get-FileHash $target).Hash) {
            Write-Host "[=] $target (matches template)" -ForegroundColor DarkGray
        } else {
            Write-Host "[!] $target (differs from template — review manually)" -ForegroundColor Yellow
            $diffCmd = Get-Command diff -ErrorAction SilentlyContinue
            if ($diffCmd) {
                $diffOutput = & diff -u $src $target 2>$null
                $lines = if ($diffOutput) { $diffOutput -split "`n" } else { @() }
                if ($lines.Count -le 20) {
                    foreach ($line in $lines) { Write-Host "    $line" }
                } else {
                    for ($i = 0; $i -lt 20; $i++) { Write-Host "    $($lines[$i])" }
                    $remaining = $lines.Count - 20
                    Write-Host "    ... ($remaining more lines — compare manually with: diff $src $target)"
                }
            } else {
                Write-Host "    (diff not available — compare manually with: diff $src $target)"
            }
        }
    }

    Write-Host ""
}

# Run command
switch ($Command) {
    "init"    { Invoke-Init }
```

- [ ] **Step 2: Verify dry-run (PowerShell)**

```powershell
pwsh scripts/mb.ps1 upgrade --dry-run
```

Expected: Same structure as bash dry-run — header, `(dry run)` line, one status per file, no writes.

- [ ] **Step 3: Verify error case**

```powershell
$null = New-Item -ItemType Directory -Force -Path "$env:TEMP\no-mb-test"
Push-Location "$env:TEMP\no-mb-test"
pwsh C:\path\to\scripts\mb.ps1 upgrade
Pop-Location
```

Expected: `Error: No memory-bank/ directory found.`

- [ ] **Step 4: Commit**

```bash
git add scripts/mb.ps1
git commit -m "feat: add Invoke-Upgrade to mb.ps1"
```

---

## Task 6: Manual end-to-end verification

**Files:** (no code changes — verification only, then commit if fixes needed)

This task verifies both scripts against the spec's output format requirements.

- [ ] **Step 1: Verify `mb help` output in both shells**

```bash
bash scripts/mb.sh help
```
```powershell
pwsh scripts/mb.ps1 help
```

Expected: `upgrade  Propagate current governance templates to this project` visible in Commands block.

- [ ] **Step 2: Run shellcheck on mb.sh**

```bash
shellcheck --severity=error scripts/mb.sh
```

Expected: exits 0, no output.

- [ ] **Step 3: Run `mb upgrade --dry-run` from project root (this repo is mb-managed)**

```bash
bash scripts/mb.sh upgrade --dry-run
```

Verify:
- Every TEMPLATE_OWNED file produces exactly one `[=]`, `[+?]`, or `[~?]` line
- Every ADVISORY_DIFF file produces exactly one `[=]` or `[!]` line
- No files are written (`git status` unchanged after this)
- No silent lines — total output lines = 16 (TEMPLATE_OWNED) + 3 (ADVISORY_DIFF) + header/footer lines

- [ ] **Step 4: Run `mb upgrade` (no flags) and verify output + writes**

```bash
bash scripts/mb.sh upgrade
```

Then:
```bash
git status
```

Verify:
- Files that were out of date now appear in `git diff` with updated content
- `[~]` lines correspond exactly to what `git status` shows as modified
- `[+]` lines correspond to files newly created
- `[=]` lines correspond to files with no `git diff` entry
- `memory-bank/` does NOT appear in `git status` (protected invariant)

- [ ] **Step 5: Run `mb upgrade` a second time immediately — verify idempotency**

```bash
bash scripts/mb.sh upgrade
```

Expected: all lines are `[=]` (unchanged). No `[~]` or `[+]`. Exit 0. This verifies idempotency.

- [ ] **Step 6: Commit any fixes, then final commit**

```bash
git add scripts/mb.sh scripts/mb.ps1 templates/cursor/rules/code-quality.mdc
git status  # confirm no unexpected files staged
git commit -m "feat: mb upgrade — propagate governance templates to existing projects

- Add 3-line comment provenance anchor to templates/.cursor/rules/code-quality.mdc
- Add invoke_upgrade() to mb.sh: binary ownership model (overwrite/advisory/never)
- Add Invoke-Upgrade to mb.ps1: equivalent PowerShell implementation
- Supports --dry-run flag; 20-line diff cap on advisory files; exits 0 on [?]"
```

---

## Spec Reference: Output Status Codes

| Code | Meaning | When emitted |
|------|---------|--------------|
| `[=]` | Unchanged / matches template | File present, content identical |
| `[~]` | Updated | TEMPLATE_OWNED, was stale, now overwritten |
| `[+]` | Added | TEMPLATE_OWNED, was absent, now created |
| `[?]` | Template source missing | Source file absent from installation; exits 0 |
| `[!]` | Advisory diff | ADVISORY_DIFF file differs from template; never written |
| `[~?]` | Would update (dry-run) | Same trigger as `[~]` but in dry-run mode |
| `[+?]` | Would add (dry-run) | Same trigger as `[+]` but in dry-run mode |

Exit codes: `0` in all cases except hard failures (missing CWD, unreadable template → exit 1).
