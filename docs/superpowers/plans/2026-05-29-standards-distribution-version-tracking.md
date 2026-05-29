# Standards Distribution + Version Tracking Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Distribute `standards/` files to target projects via `mb init` and `mb upgrade`, add `.pmb-version` tracking, and add a soft remote version check to `mb upgrade`.

**Architecture:** Three independent additions to `scripts/mb.sh` and `scripts/mb.ps1`: (1) a new `ADVISORY_CREATE` category in upgrade that creates missing standards files and shows diffs on existing ones; (2) `.pmb-version` written after init/upgrade; (3) a non-blocking remote `VERSION` fetch at the start of upgrade. Two new `mb doctor` checks warn on missing standards files and version drift. Prerequisites: `templates/standards/` directory must exist before wiring the script changes.

**Tech Stack:** Bash (mb.sh), PowerShell 7+ (mb.ps1), curl (remote check in bash), Invoke-WebRequest (remote check in PS1)

---

## File Change Map

| File | Operation | What Changes |
|---|---|---|
| `templates/standards/` | **Create** | New directory — copy all files from `standards/` |
| `scripts/mb.sh` | **Edit** | `invoke_init`: add standards loop; `invoke_upgrade`: add `ADVISORY_CREATE` array + loop, `.pmb-version` write, remote check; `show_doctor`: add checks 11 and 12 |
| `scripts/mb.ps1` | **Edit** | Same additions in PowerShell |

---

## Task 1: Create `templates/standards/`

**Files:**
- Create: `templates/standards/` (directory + all standards files)

The `_upgrade_src` path resolver in both scripts maps `standards/X` → `templates/standards/X` via the `*` fallback case. This directory must exist before any script changes are wired.

- [ ] **Step 1: Verify `templates/standards/` does not exist**

```bash
ls "C:\Users\Mizzo\Claude\Personal-Memory-Bank\templates\" 2>/dev/null || true
```

Expected: no `standards` subdirectory listed.

- [ ] **Step 2: Copy all standards files into the new templates directory**

```bash
cd "C:\Users\Mizzo\Claude\Personal-Memory-Bank"
mkdir -p templates/standards
cp standards/*.md templates/standards/
```

This copies the 12 top-level standards files (ACCESSIBILITY.md, AGENTIC-SAFETY.md, CODE-QUALITY.md, CODE-REVIEW.md, LOGGING.md, MCP-SECURITY.md, MEMORY-BANK.md, RULES-FILE-INTEGRITY.md, SECRETS.md, SECURITY-GUARDRAILS.md, SUPPLY-CHAIN.md, WORKFLOW.md). The `extensions/` subdirectory is not distributed — language-specific extensions are reference docs, not runtime-critical.

- [ ] **Step 3: Verify file count**

```bash
ls templates/standards/ | wc -l
```

Expected: 12

- [ ] **Step 4: Commit**

```bash
git add templates/standards/
git commit -m "feat: add templates/standards/ for distribution via mb init and mb upgrade"
```

---

## Task 2: Add standards to `mb init` in `scripts/mb.sh`

**Files:**
- Modify: `scripts/mb.sh` — `invoke_init` function

The existing init function uses a `copy_if_new` helper and loops over `templates/memory-bank/` and `templates/claude-commands/`. Add an identical loop for `templates/standards/`.

- [ ] **Step 1: Read the current `invoke_init` function**

Read `scripts/mb.sh` lines 265-360 to confirm the loop pattern before editing.

- [ ] **Step 2: Add the standards loop**

Find the `.claude/commands/` loop block in `invoke_init` (the block that copies claude-commands):

```bash
    # .claude/commands/
    for f in "$TEMPLATES_DIR/claude-commands"/*; do
        [ -f "$f" ] && copy_if_new "$f" "$TARGET/.claude/commands/$(basename "$f")" ".claude/commands/$(basename "$f")"
    done
```

Insert the following block immediately after it:

```bash

    # standards/ files — governance contracts referenced at runtime by commands
    if [ -d "$TEMPLATES_DIR/standards" ]; then
        for f in "$TEMPLATES_DIR/standards"/*; do
            [ -f "$f" ] && copy_if_new "$f" "$TARGET/standards/$(basename "$f")" "standards/$(basename "$f")"
        done
    fi
```

- [ ] **Step 3: Verify the edit**

```bash
grep -A5 "standards/ files" scripts/mb.sh
```

Expected: the new block is present.

- [ ] **Step 4: Shellcheck**

```bash
shellcheck --severity=error scripts/mb.sh
```

Expected: no errors.

- [ ] **Step 5: Commit**

```bash
git add scripts/mb.sh
git commit -m "feat: distribute standards/ files in mb init (bash)"
```

---

## Task 3: Add standards to `mb init` in `scripts/mb.ps1`

**Files:**
- Modify: `scripts/mb.ps1` — `Invoke-Init` function

Mirror of Task 2 in PowerShell.

- [ ] **Step 1: Read the current `Invoke-Init` function**

Read `scripts/mb.ps1` lines 322-419 to confirm the loop pattern.

- [ ] **Step 2: Add the standards loop**

Find the `.claude/commands/` loop block in `Invoke-Init`:

```powershell
    # .claude/commands/
    foreach ($f in Get-ChildItem (Join-Path $TemplatesDir "claude-commands") -File) {
        Copy-IfNew -Src $f.FullName -Dst (Join-Path $Target ".claude\commands\$($f.Name)") -Label ".claude/commands/$($f.Name)"
    }
```

Insert the following block immediately after it:

```powershell

    # standards/ files — governance contracts referenced at runtime by commands
    $standardsTemplate = Join-Path $TemplatesDir "standards"
    if (Test-Path $standardsTemplate) {
        foreach ($f in Get-ChildItem $standardsTemplate -File) {
            Copy-IfNew -Src $f.FullName -Dst (Join-Path $Target "standards\$($f.Name)") -Label "standards/$($f.Name)"
        }
    }
```

- [ ] **Step 3: Verify the edit**

```powershell
Select-String -Path scripts/mb.ps1 -Pattern "standards/ files" -Context 0,5
```

Expected: the new block is present.

- [ ] **Step 4: Commit**

```bash
git add scripts/mb.ps1
git commit -m "feat: distribute standards/ files in mb init (PowerShell)"
```

---

## Task 4: Add `ADVISORY_CREATE` to `invoke_upgrade` in `scripts/mb.sh`

**Files:**
- Modify: `scripts/mb.sh` — `invoke_upgrade` function

`ADVISORY_DIFF` for missing files outputs `[=] (not present — no action needed)` and skips. Standards files need a third behavior: **create if missing, diff if present**. Add a new `ADVISORY_CREATE` array and processing loop.

- [ ] **Step 1: Read the current `invoke_upgrade` function**

Read `scripts/mb.sh` around lines 927-1063 to locate the end of the `ADVISORY_DIFF` array and the end of the function.

- [ ] **Step 2: Add the `ADVISORY_CREATE` array**

Find the `ADVISORY_DIFF` array block (ends with the closing `)`). Insert after it:

```bash

    # WHY: ADVISORY_CREATE — files that must exist for commands to work at runtime.
    # Create if missing (unlike ADVISORY_DIFF which skips missing files), but show
    # a diff rather than silently overwriting if the file has been customized.
    ADVISORY_CREATE=(
        "standards/CODE-REVIEW.md"
        "standards/WORKFLOW.md"
        "standards/SECURITY-GUARDRAILS.md"
        "standards/CODE-QUALITY.md"
        "standards/ACCESSIBILITY.md"
        "standards/AGENTIC-SAFETY.md"
        "standards/LOGGING.md"
        "standards/MCP-SECURITY.md"
        "standards/MEMORY-BANK.md"
        "standards/RULES-FILE-INTEGRITY.md"
        "standards/SECRETS.md"
        "standards/SUPPLY-CHAIN.md"
    )
```

- [ ] **Step 3: Add the `ADVISORY_CREATE` processing loop**

Find the end of the ADVISORY_DIFF loop (the `done` that closes the `for target in "${ADVISORY_DIFF[@]}"` loop). Insert the following block after it, before the closing `echo ""` of `invoke_upgrade`:

```bash

    # Process ADVISORY_CREATE — create if missing, show advisory diff if exists
    for target in "${ADVISORY_CREATE[@]}"; do
        src="$(_upgrade_src "$target")"
        if [ ! -f "$src" ]; then
            echo -e "${YELLOW}[?] $target (template source missing — skipped)${NC}"
            continue
        fi
        if [ ! -f "$target" ]; then
            if [ "$DRY_RUN" = true ]; then
                echo -e "${GREEN}[+?] $target (would add — missing in project)${NC}"
            else
                mkdir -p "$(dirname "$target")"
                cp "$src" "$target"
                echo -e "${GREEN}[+] $target (added — was missing)${NC}"
            fi
        elif cmp -s "$src" "$target"; then
            echo -e "${GRAY}[=] $target (matches template)${NC}"
        else
            echo -e "${YELLOW}[!] $target (differs from template — review manually)${NC}"
            if command -v diff >/dev/null 2>&1; then
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
```

- [ ] **Step 4: Verify**

```bash
grep -c "ADVISORY_CREATE" scripts/mb.sh
```

Expected: at least 2 (definition + loop reference).

```bash
shellcheck --severity=error scripts/mb.sh
```

Expected: no errors.

- [ ] **Step 5: Commit**

```bash
git add scripts/mb.sh
git commit -m "feat: add ADVISORY_CREATE category to mb upgrade for standards distribution (bash)"
```

---

## Task 5: Add `ADVISORY_CREATE` to `Invoke-Upgrade` in `scripts/mb.ps1`

**Files:**
- Modify: `scripts/mb.ps1` — `Invoke-Upgrade` function

Mirror of Task 4 in PowerShell. The PS1 upgrade function uses `$advisoryDiff` (camelCase) and a `Get-UpgradeSrc` helper function (or inline switch — read the file to confirm exact pattern).

- [ ] **Step 1: Read `Invoke-Upgrade` in `scripts/mb.ps1`**

Read lines 1100-1239 to confirm the `$advisoryDiff` array and processing loop pattern, and the name of the path-resolver helper.

- [ ] **Step 2: Add the `$advisoryCreate` array**

Find the `$advisoryDiff` array block (ends with closing `)`). Insert after it:

```powershell

    # WHY: $advisoryCreate — files that must exist for commands to work at runtime.
    # Create if missing, but show a diff rather than silently overwriting if customized.
    $advisoryCreate = @(
        "standards/CODE-REVIEW.md"
        "standards/WORKFLOW.md"
        "standards/SECURITY-GUARDRAILS.md"
        "standards/CODE-QUALITY.md"
        "standards/ACCESSIBILITY.md"
        "standards/AGENTIC-SAFETY.md"
        "standards/LOGGING.md"
        "standards/MCP-SECURITY.md"
        "standards/MEMORY-BANK.md"
        "standards/RULES-FILE-INTEGRITY.md"
        "standards/SECRETS.md"
        "standards/SUPPLY-CHAIN.md"
    )
```

- [ ] **Step 3: Add the `$advisoryCreate` processing loop**

Find the end of the `$advisoryDiff` loop. Insert after it (use the same path-resolver helper and `$DryRun` variable that the existing loops use — read the file to get exact names):

```powershell

    # Process $advisoryCreate — create if missing, show advisory diff if exists
    foreach ($target in $advisoryCreate) {
        $src = Get-UpgradeSrc $target  # use whatever helper name the file uses
        if (-not (Test-Path $src)) {
            Write-Host "[?] $target (template source missing — skipped)" -ForegroundColor Yellow
            continue
        }
        $dst = $target -replace '/', '\'
        if (-not (Test-Path $dst)) {
            if ($DryRun) {
                Write-Host "[+?] $target (would add — missing in project)" -ForegroundColor Green
            } else {
                $dir = Split-Path -Parent $dst
                if (-not (Test-Path $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
                Copy-Item -Path $src -Destination $dst -Force
                Write-Host "[+] $target (added — was missing)" -ForegroundColor Green
            }
        } elseif ((Get-FileHash $src).Hash -eq (Get-FileHash $dst).Hash) {
            Write-Host "[=] $target (matches template)" -ForegroundColor DarkGray
        } else {
            Write-Host "[!] $target (differs from template — review manually)" -ForegroundColor Yellow
            if (Get-Command diff -ErrorAction SilentlyContinue) {
                $diffOutput = diff $src $dst 2>$null
                if ($diffOutput.Count -le 20) {
                    $diffOutput | ForEach-Object { Write-Host "    $_" }
                } else {
                    $diffOutput | Select-Object -First 20 | ForEach-Object { Write-Host "    $_" }
                    Write-Host "    ... ($($diffOutput.Count - 20) more lines — compare manually)"
                }
            } else {
                Write-Host "    (diff not available — compare manually with: diff $src $dst)"
            }
        }
    }
```

**Important:** When reading the file in Step 1, check the actual helper function name (it may be an inline switch/case instead of a named function). Adapt the `Get-UpgradeSrc $target` call accordingly. Also confirm `$DryRun` vs `-DryRun` switch name.

- [ ] **Step 4: Verify**

```powershell
Select-String -Path scripts/mb.ps1 -Pattern "advisoryCreate" | Measure-Object | Select-Object -ExpandProperty Count
```

Expected: at least 2.

- [ ] **Step 5: Commit**

```bash
git add scripts/mb.ps1
git commit -m "feat: add advisoryCreate category to mb upgrade for standards distribution (PowerShell)"
```

---

## Task 6: Add `.pmb-version` write + remote check to `invoke_upgrade` in `scripts/mb.sh`

**Files:**
- Modify: `scripts/mb.sh` — `invoke_upgrade` function (remote check at top) and `invoke_init` function (version write at bottom)

Two changes in one task since both touch version-write logic and are small.

- [ ] **Step 1: Add remote version check at the start of `invoke_upgrade`**

In `invoke_upgrade`, find the block that checks for `memory-bank/` directory:

```bash
    if [ ! -d "memory-bank" ]; then
        echo -e "${RED}Error: No memory-bank/ directory found...
```

Insert the remote version check immediately after the `TEMPLATES_DIR` existence check (the second `if [ ! -d "$TEMPLATES_DIR" ]` block). Add it before the `TEMPLATE_OWNED=(` array definition:

```bash

    # Remote version check — soft warning, never blocks upgrade
    if [ -f "$REPO_ROOT/VERSION" ]; then
        LOCAL_VERSION=$(tr -d '[:space:]' < "$REPO_ROOT/VERSION")
        if command -v curl >/dev/null 2>&1; then
            REMOTE_VERSION=$(curl -sf --max-time 3 \
                "https://raw.githubusercontent.com/unyieldingclaw-dev/personal-memory-bank/master/VERSION" \
                2>/dev/null | tr -d '[:space:]' || true)
            if [ -n "$REMOTE_VERSION" ] && [ "$REMOTE_VERSION" != "$LOCAL_VERSION" ]; then
                echo -e "${YELLOW}[WARN] PMB $LOCAL_VERSION installed locally, $REMOTE_VERSION available${NC}"
                echo -e "${YELLOW}       Consider updating PMB: https://github.com/unyieldingclaw-dev/personal-memory-bank${NC}"
                echo ""
            elif [ -z "$REMOTE_VERSION" ]; then
                echo -e "${GRAY}[INFO] Remote version check skipped (unreachable)${NC}"
            fi
        fi
    fi
```

- [ ] **Step 2: Add `.pmb-version` write at the end of `invoke_upgrade`**

Find the closing `echo ""` at the end of `invoke_upgrade` (the last line before the closing `}`). Insert before it:

```bash

    # Write .pmb-version — records which PMB version this project was last upgraded with
    if [ -f "$REPO_ROOT/VERSION" ] && [ "$DRY_RUN" = false ]; then
        LOCAL_VERSION=$(tr -d '[:space:]' < "$REPO_ROOT/VERSION")
        printf '%s\n' "$LOCAL_VERSION" > ".pmb-version"
        echo -e "${GREEN}[✓] .pmb-version updated to $LOCAL_VERSION${NC}"
    fi
```

- [ ] **Step 3: Add `.pmb-version` write at the end of `invoke_init`**

Find the closing `echo ""` at the end of `invoke_init` (the last `echo ""` before `}`). Insert before it:

```bash

    # Write .pmb-version — records which PMB version initialized this project
    if [ -f "$REPO_ROOT/VERSION" ]; then
        LOCAL_VERSION=$(tr -d '[:space:]' < "$REPO_ROOT/VERSION")
        printf '%s\n' "$LOCAL_VERSION" > "$TARGET/.pmb-version"
        CREATED+=(".pmb-version")
    fi
```

Note: add this before the `for item in "${CREATED[@]}"` display loop so it shows up in the created list.

- [ ] **Step 4: Shellcheck**

```bash
shellcheck --severity=error scripts/mb.sh
```

Expected: no errors.

- [ ] **Step 5: Commit**

```bash
git add scripts/mb.sh
git commit -m "feat: add .pmb-version tracking and remote version check to mb.sh"
```

---

## Task 7: Add `.pmb-version` write + remote check to `Invoke-Upgrade` in `scripts/mb.ps1`

**Files:**
- Modify: `scripts/mb.ps1` — `Invoke-Upgrade` and `Invoke-Init` functions

Mirror of Task 6 in PowerShell.

- [ ] **Step 1: Add remote version check at the start of `Invoke-Upgrade`**

Read `scripts/mb.ps1` around `Invoke-Upgrade` to find the location after the TEMPLATES_DIR check. Insert before the `$templateOwned` array definition:

```powershell

    # Remote version check — soft warning, never blocks upgrade
    $versionFile = Join-Path $RepoRoot "VERSION"
    if (Test-Path $versionFile) {
        $localVersion = (Get-Content $versionFile -Raw).Trim()
        try {
            $response = Invoke-WebRequest -Uri "https://raw.githubusercontent.com/unyieldingclaw-dev/personal-memory-bank/master/VERSION" `
                -TimeoutSec 3 -UseBasicParsing -ErrorAction Stop
            $remoteVersion = $response.Content.Trim()
            if ($remoteVersion -ne $localVersion) {
                Write-Host "[WARN] PMB $localVersion installed locally, $remoteVersion available" -ForegroundColor Yellow
                Write-Host "       Consider updating PMB: https://github.com/unyieldingclaw-dev/personal-memory-bank" -ForegroundColor Yellow
                Write-Host ""
            }
        } catch {
            Write-Host "[INFO] Remote version check skipped (unreachable)" -ForegroundColor DarkGray
        }
    }
```

- [ ] **Step 2: Add `.pmb-version` write at the end of `Invoke-Upgrade`**

Find the closing `Write-Host ""` at the end of `Invoke-Upgrade`. Insert before it:

```powershell

    # Write .pmb-version — records which PMB version this project was last upgraded with
    $versionFile = Join-Path $RepoRoot "VERSION"
    if ((Test-Path $versionFile) -and (-not $DryRun)) {
        $localVersion = (Get-Content $versionFile -Raw).Trim()
        Set-Content -Path ".pmb-version" -Value $localVersion -NoNewline
        Write-Host "[✓] .pmb-version updated to $localVersion" -ForegroundColor Green
    }
```

- [ ] **Step 3: Add `.pmb-version` write at the end of `Invoke-Init`**

Find the section in `Invoke-Init` where `$Created` items are printed. Insert the version write before that display loop:

```powershell

    # Write .pmb-version — records which PMB version initialized this project
    $versionFile = Join-Path $RepoRoot "VERSION"
    if (Test-Path $versionFile) {
        $localVersion = (Get-Content $versionFile -Raw).Trim()
        Set-Content -Path (Join-Path $Target ".pmb-version") -Value $localVersion -NoNewline
        $Created += ".pmb-version"
    }
```

- [ ] **Step 4: Verify**

```powershell
Select-String -Path scripts/mb.ps1 -Pattern "pmb-version" | Measure-Object | Select-Object -ExpandProperty Count
```

Expected: at least 3 (one per write location, plus the doctor checks will add more).

- [ ] **Step 5: Commit**

```bash
git add scripts/mb.ps1
git commit -m "feat: add .pmb-version tracking and remote version check to mb.ps1"
```

---

## Task 8: Add doctor checks 11 and 12 in `scripts/mb.sh`

**Files:**
- Modify: `scripts/mb.sh` — `show_doctor` function

Add two new checks at the end of `show_doctor`, before the closing summary/exit.

- [ ] **Step 1: Read the end of `show_doctor`**

Find where the last existing check ends in `show_doctor` (check 10 — staleness audit). Insert after it.

- [ ] **Step 2: Add check 11 — required standards files**

```bash

    # 11. Required standards files
    REQUIRED_STANDARDS=("CODE-REVIEW.md" "WORKFLOW.md" "SECURITY-GUARDRAILS.md" "CODE-QUALITY.md")
    MISSING_STANDARDS=()
    for s in "${REQUIRED_STANDARDS[@]}"; do
        [ ! -f "standards/$s" ] && MISSING_STANDARDS+=("standards/$s")
    done
    if [ ${#MISSING_STANDARDS[@]} -eq 0 ]; then
        echo -e "${GREEN}[OK]   Required standards files present${NC}"
    else
        for s in "${MISSING_STANDARDS[@]}"; do
            echo -e "${YELLOW}[WARN] $s not found — run mb upgrade to install${NC}"
        done
    fi
```

- [ ] **Step 3: Add check 12 — `.pmb-version` tracking**

```bash

    # 12. PMB version tracking
    if [ -f "$REPO_ROOT/VERSION" ]; then
        LOCAL_VERSION=$(tr -d '[:space:]' < "$REPO_ROOT/VERSION")
        if [ ! -f ".pmb-version" ]; then
            echo -e "${YELLOW}[WARN] No .pmb-version found — run mb upgrade to initialize version tracking${NC}"
        else
            PROJECT_VERSION=$(tr -d '[:space:]' < ".pmb-version")
            if [ "$PROJECT_VERSION" = "$LOCAL_VERSION" ]; then
                echo -e "${GREEN}[OK]   PMB version: $LOCAL_VERSION${NC}"
            else
                echo -e "${YELLOW}[WARN] Project on PMB $PROJECT_VERSION, local PMB is $LOCAL_VERSION — run mb upgrade${NC}"
            fi
        fi
    fi
```

- [ ] **Step 4: Shellcheck**

```bash
shellcheck --severity=error scripts/mb.sh
```

Expected: no errors.

- [ ] **Step 5: Commit**

```bash
git add scripts/mb.sh
git commit -m "feat: add mb doctor checks for standards files and .pmb-version (bash)"
```

---

## Task 9: Add doctor checks 11 and 12 in `scripts/mb.ps1`

**Files:**
- Modify: `scripts/mb.ps1` — `Show-Doctor` function

Mirror of Task 8 in PowerShell.

- [ ] **Step 1: Read the end of `Show-Doctor`**

Find where the last existing check ends in `Show-Doctor`. Insert after it.

- [ ] **Step 2: Add check 11 — required standards files**

```powershell

    # 11. Required standards files
    $requiredStandards = @("CODE-REVIEW.md", "WORKFLOW.md", "SECURITY-GUARDRAILS.md", "CODE-QUALITY.md")
    $missingStandards = @()
    foreach ($s in $requiredStandards) {
        if (-not (Test-Path "standards\$s")) { $missingStandards += "standards/$s" }
    }
    if ($missingStandards.Count -eq 0) {
        Write-Host "[OK]   Required standards files present" -ForegroundColor Green
    } else {
        foreach ($s in $missingStandards) {
            Write-Host "[WARN] $s not found — run mb upgrade to install" -ForegroundColor Yellow
        }
    }
```

- [ ] **Step 3: Add check 12 — `.pmb-version` tracking**

```powershell

    # 12. PMB version tracking
    $versionFile = Join-Path $RepoRoot "VERSION"
    if (Test-Path $versionFile) {
        $localVersion = (Get-Content $versionFile -Raw).Trim()
        if (-not (Test-Path ".pmb-version")) {
            Write-Host "[WARN] No .pmb-version found — run mb upgrade to initialize version tracking" -ForegroundColor Yellow
        } else {
            $projectVersion = (Get-Content ".pmb-version" -Raw).Trim()
            if ($projectVersion -eq $localVersion) {
                Write-Host "[OK]   PMB version: $localVersion" -ForegroundColor Green
            } else {
                Write-Host "[WARN] Project on PMB $projectVersion, local PMB is $localVersion — run mb upgrade" -ForegroundColor Yellow
            }
        }
    }
```

- [ ] **Step 4: Commit**

```bash
git add scripts/mb.ps1
git commit -m "feat: add mb doctor checks for standards files and .pmb-version (PowerShell)"
```

---

## Verification Checklist

Run after all tasks complete:

- [ ] `ls templates/standards/ | wc -l` returns 12
- [ ] Run `mb init` in a temp directory → `standards/` files present, `.pmb-version` file written with content `1.0.2`
- [ ] Run `mb upgrade` (dry-run) in a project without `standards/CODE-REVIEW.md` → shows `[+?] standards/CODE-REVIEW.md (would add)`
- [ ] Run `mb upgrade` (dry-run) in a project with a modified `standards/CODE-REVIEW.md` → shows `[!] standards/CODE-REVIEW.md (differs from template — review manually)` with diff
- [ ] Run `mb upgrade` offline (disable network) → shows `[INFO] Remote version check skipped (unreachable)` and completes
- [ ] Run `mb doctor` in a project without `standards/WORKFLOW.md` → shows `[WARN] standards/WORKFLOW.md not found`
- [ ] Run `mb doctor` in a project where `.pmb-version` is `0.9.0` and local PMB is `1.0.2` → shows `[WARN] Project on PMB 0.9.0, local PMB is 1.0.2 — run mb upgrade`
- [ ] Run `mb doctor` in a project where `.pmb-version` matches local → shows `[OK] PMB version: 1.0.2`
- [ ] `shellcheck --severity=error scripts/mb.sh` returns no errors
- [ ] `git log --oneline HEAD~9..HEAD` shows 9 clean commits
