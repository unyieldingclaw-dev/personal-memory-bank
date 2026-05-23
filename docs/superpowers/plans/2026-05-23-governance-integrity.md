# Governance Integrity Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Move the 6 hook scripts from `scripts/` to `templates/scripts/` (making templates the canonical distribution surface), extend `mb init` to copy them on adoption, and extend `mb doctor` Check #4 to verify each referenced hook script actually exists on disk.

**Architecture:** The repo transitions from implicit "hook scripts live in scripts/" to explicit "hook scripts live in templates/scripts/ and are distributed by mb init." Two enforcement layers validate this: `mb doctor` (local runtime existence check per project) and a new CI job (template integrity — settings.json references exist in templates/scripts/). The doctor check is path-aware and platform-neutral: it extracts the full relative script path from settings.json, strips the extension, and checks for any matching implementation file — meaning it works correctly for both adopted projects (scripts/X) and this repo itself (templates/scripts/X).

**Tech Stack:** Bash (POSIX-compatible where possible, bash arrays where needed), PowerShell 7+, GitHub Actions, git mv.

---

## File Map

| File | Operation | Notes |
|------|-----------|-------|
| `scripts/dangerous-commands.sh` | Move → `templates/scripts/` | `git mv` preserves history |
| `scripts/dangerous-commands.ps1` | Move → `templates/scripts/` | |
| `scripts/check-contract.sh` | Move → `templates/scripts/` | |
| `scripts/check-contract.ps1` | Move → `templates/scripts/` | |
| `scripts/update-reviewed.sh` | Move → `templates/scripts/` | |
| `scripts/update-reviewed.ps1` | Move → `templates/scripts/` | |
| `templates/scripts/README.md` | Create | Documents the production surface |
| `.claude/settings.json` | Modify | Update hook commands: `scripts/X` → `templates/scripts/X` (this repo's own hooks only; `templates/.claude/settings.json` is unchanged) |
| `scripts/mb.sh` | Modify: `invoke_init()` | Add 8-line hook script copy block after settings.json line |
| `scripts/mb.sh` | Modify: `show_doctor()` | Replace Check #4 Hooks block with expanded version including existence check |
| `scripts/mb.ps1` | Modify: `Invoke-Init()` | PowerShell equivalent of mb.sh invoke_init change |
| `scripts/mb.ps1` | Modify: `Show-Doctor()` | PowerShell equivalent of mb.sh doctor change |
| `.github/workflows/governance.yml` | Modify | Add `template-integrity` job |

---

## Task 1: Create Feature Branch

**Files:** (git only)

- [ ] **Step 1: Create and switch to the feature branch**

```bash
git checkout -b feat/governance-integrity
```

Expected: `Switched to a new branch 'feat/governance-integrity'`

---

## Task 2: Move Hook Scripts to templates/scripts/

**Files:**
- Move: `scripts/dangerous-commands.{sh,ps1}`, `scripts/check-contract.{sh,ps1}`, `scripts/update-reviewed.{sh,ps1}` → `templates/scripts/`
- Create: `templates/scripts/README.md`

- [ ] **Step 1: Create the templates/scripts/ directory and move all 6 scripts**

```bash
mkdir templates/scripts
git mv scripts/dangerous-commands.sh  templates/scripts/dangerous-commands.sh
git mv scripts/dangerous-commands.ps1 templates/scripts/dangerous-commands.ps1
git mv scripts/check-contract.sh      templates/scripts/check-contract.sh
git mv scripts/check-contract.ps1     templates/scripts/check-contract.ps1
git mv scripts/update-reviewed.sh     templates/scripts/update-reviewed.sh
git mv scripts/update-reviewed.ps1    templates/scripts/update-reviewed.ps1
```

Expected: no output (silent success). Verify with `git status` — you should see 6 renamed files.

- [ ] **Step 2: Verify the move looks correct**

```bash
git status --short
```

Expected: 6 lines like `R  scripts/dangerous-commands.sh -> templates/scripts/dangerous-commands.sh`

```bash
ls templates/scripts/
```

Expected: 6 files — all `.sh` and `.ps1` variants.

```bash
ls scripts/
```

Expected: only `mb.sh`, `mb.ps1`, `init-memory-bank.sh`, `init-memory-bank.ps1` remain.

- [ ] **Step 3: Create templates/scripts/README.md**

Write this exact content to `templates/scripts/README.md`:

```markdown
# templates/scripts/

This directory is **production infrastructure**, not examples. Every script here is
copied into adopter `scripts/` directories by `mb init`.

## Exported scripts (explicit allowlist)

- `dangerous-commands.sh` / `dangerous-commands.ps1` — blocks dangerous shell commands (PreToolUse/Bash)
- `check-contract.sh` / `check-contract.ps1` — enforces task contract scope (PreToolUse/Write|Edit)
- `update-reviewed.sh` / `update-reviewed.ps1` — auto-updates `last-reviewed` frontmatter (PostToolUse/Write|Edit)

## Adding a new script

1. Add the file(s) to this directory
2. Add the filename(s) to the allowlist in `scripts/mb.sh` `invoke_init()` and `scripts/mb.ps1` `Invoke-Init()`
3. The CI `template-integrity` job validates every reference in `templates/.claude/settings.json` exists here
```

- [ ] **Step 4: Commit**

```bash
git add templates/scripts/README.md
git commit -m "refactor: move hook scripts to templates/scripts/ (canonical adoptable surface)"
```

---

## Task 3: Update This Repo's .claude/settings.json

This repo's `.claude/settings.json` currently references `scripts/X`. After the move, those paths don't exist. Update the three hook commands to point to `templates/scripts/X`.

**Files:**
- Modify: `.claude/settings.json`

- [ ] **Step 1: Read the current file to confirm the three command lines**

```bash
grep '"command":' .claude/settings.json
```

Expected output (3 lines):
```
            "command": "powershell -File scripts/update-reviewed.ps1 2>/dev/null || bash scripts/update-reviewed.sh 2>/dev/null || true"
            "command": "pwsh -NonInteractive -File scripts/dangerous-commands.ps1 2>/dev/null || bash scripts/dangerous-commands.sh 2>/dev/null || true"
            "command": "pwsh -NonInteractive -File scripts/check-contract.ps1 2>/dev/null || bash scripts/check-contract.sh 2>/dev/null || true"
```

- [ ] **Step 2: Replace `scripts/` with `templates/scripts/` in the three command lines**

In `.claude/settings.json`, replace the `"command":` values for the three hook blocks:

**update-reviewed** (PostToolUse):
Old: `"command": "powershell -File scripts/update-reviewed.ps1 2>/dev/null || bash scripts/update-reviewed.sh 2>/dev/null || true"`
New: `"command": "powershell -File templates/scripts/update-reviewed.ps1 2>/dev/null || bash templates/scripts/update-reviewed.sh 2>/dev/null || true"`

**dangerous-commands** (PreToolUse/Bash):
Old: `"command": "pwsh -NonInteractive -File scripts/dangerous-commands.ps1 2>/dev/null || bash scripts/dangerous-commands.sh 2>/dev/null || true"`
New: `"command": "pwsh -NonInteractive -File templates/scripts/dangerous-commands.ps1 2>/dev/null || bash templates/scripts/dangerous-commands.sh 2>/dev/null || true"`

**check-contract** (PreToolUse/Write|Edit):
Old: `"command": "pwsh -NonInteractive -File scripts/check-contract.ps1 2>/dev/null || bash scripts/check-contract.sh 2>/dev/null || true"`
New: `"command": "pwsh -NonInteractive -File templates/scripts/check-contract.ps1 2>/dev/null || bash templates/scripts/check-contract.sh 2>/dev/null || true"`

- [ ] **Step 3: Verify the paths updated correctly**

```bash
grep '"command":' .claude/settings.json
```

Expected: all 3 lines now reference `templates/scripts/X`, none reference `scripts/X`.

- [ ] **Step 4: Commit**

```bash
git add .claude/settings.json
git commit -m "fix: update .claude/settings.json hook paths after templates/scripts/ migration"
```

---

## Task 4: Extend mb.sh invoke_init() — Hook Script Copy Block

Add the hook scripts allowlist copy block immediately after the `.claude/settings.json` copy line in `scripts/mb.sh`.

**Files:**
- Modify: `scripts/mb.sh` (insert ~8 lines after the `.claude/settings.json` copy_if_new call)

- [ ] **Step 1: Locate the insertion point**

```bash
grep -n "\.claude/settings\.json" scripts/mb.sh
```

Expected: one line like `301:    copy_if_new "$TEMPLATES_DIR/.claude/settings.json" "$TARGET/.claude/settings.json" ".claude/settings.json"`

- [ ] **Step 2: Insert the hook scripts block**

In `scripts/mb.sh`, find this exact text:

```bash
    # .claude/settings.json
    copy_if_new "$TEMPLATES_DIR/.claude/settings.json" "$TARGET/.claude/settings.json" ".claude/settings.json"

    # .claude/commands/
```

Replace it with:

```bash
    # .claude/settings.json
    copy_if_new "$TEMPLATES_DIR/.claude/settings.json" "$TARGET/.claude/settings.json" ".claude/settings.json"

    # Hook scripts (explicit allowlist — prevents accidental export of future internal files)
    # NOTE: These are the only portable governance scripts exported by mb init.
    # Additions require a corresponding entry in templates/scripts/ AND a CI integrity update.
    for script in dangerous-commands.sh dangerous-commands.ps1 \
                  check-contract.sh check-contract.ps1 \
                  update-reviewed.sh update-reviewed.ps1; do
        copy_if_new "$TEMPLATES_DIR/scripts/$script" "$TARGET/scripts/$script" "scripts/$script"
    done

    # .claude/commands/
```

- [ ] **Step 3: Verify the insertion looks correct**

```bash
grep -A 10 "Hook scripts (explicit allowlist" scripts/mb.sh
```

Expected: shows the NOTE comment and the 6-script for loop.

- [ ] **Step 4: Run shellcheck to confirm no syntax errors**

```bash
shellcheck --severity=error scripts/mb.sh
```

Expected: no output (exit 0).

- [ ] **Step 5: Commit**

```bash
git add scripts/mb.sh
git commit -m "feat(init): copy hook scripts from templates/scripts/ on mb init"
```

---

## Task 5: Extend mb.ps1 Invoke-Init() — Hook Script Copy Block

PowerShell parallel of Task 4.

**Files:**
- Modify: `scripts/mb.ps1` (insert ~7 lines after the `.claude/settings.json` Copy-IfNew call)

- [ ] **Step 1: Locate the insertion point**

```bash
grep -n "\.claude.settings\.json" scripts/mb.ps1
```

Expected: one line like `355:    Copy-IfNew -Src (Join-Path $TemplatesDir ".claude\settings.json") -Dst (Join-Path $Target ".claude\settings.json") -Label ".claude/settings.json"`

- [ ] **Step 2: Insert the hook scripts block**

In `scripts/mb.ps1`, find this exact text:

```powershell
    # .claude/settings.json
    Copy-IfNew -Src (Join-Path $TemplatesDir ".claude\settings.json") -Dst (Join-Path $Target ".claude\settings.json") -Label ".claude/settings.json"

    # .claude/commands/
```

Replace it with:

```powershell
    # .claude/settings.json
    Copy-IfNew -Src (Join-Path $TemplatesDir ".claude\settings.json") -Dst (Join-Path $Target ".claude\settings.json") -Label ".claude/settings.json"

    # Hook scripts (explicit allowlist — prevents accidental export of future internal files)
    # NOTE: These are the only portable governance scripts exported by mb init.
    # Additions require a corresponding entry in templates/scripts/ AND a CI integrity update.
    foreach ($script in @("dangerous-commands.sh","dangerous-commands.ps1","check-contract.sh","check-contract.ps1","update-reviewed.sh","update-reviewed.ps1")) {
        Copy-IfNew -Src (Join-Path $TemplatesDir "scripts\$script") -Dst (Join-Path $Target "scripts\$script") -Label "scripts/$script"
    }

    # .claude/commands/
```

- [ ] **Step 3: Verify the insertion looks correct**

```bash
grep -A 8 "Hook scripts (explicit allowlist" scripts/mb.ps1
```

Expected: shows the NOTE comment and the foreach loop with the 6 script names.

- [ ] **Step 4: Commit**

```bash
git add scripts/mb.ps1
git commit -m "feat(init): copy hook scripts from templates/scripts/ on mb init (PowerShell)"
```

---

## Task 6: Extend mb.sh show_doctor() Check #4 — Hook Script Existence

Replace the existing Check #4 Hooks block (which only checks PostToolUse presence) with an expanded version that also verifies each referenced hook script exists on disk. The check is path-aware (works for `scripts/X` or `templates/scripts/X`) and platform-neutral (any file extension counts as a valid implementation of a logical target).

**Files:**
- Modify: `scripts/mb.sh` (~35 lines replacing the existing 10-line Check #4 block)

- [ ] **Step 1: Locate the current Check #4 block**

```bash
grep -n "4\. Hooks" scripts/mb.sh
```

Expected: one line like `436:    # 4. Hooks`

- [ ] **Step 2: Replace the Check #4 block**

In `scripts/mb.sh`, find this exact text (the complete `# 4. Hooks` block):

```bash
    # 4. Hooks
    if [ -f ".claude/settings.json" ]; then
        if grep -q "PostToolUse" ".claude/settings.json" 2>/dev/null; then
            echo -e "${GREEN}[OK]   PostToolUse hook active (last-reviewed auto-updates)${NC}"
        else
            echo -e "${YELLOW}[WARN] No PostToolUse hook — last-reviewed won't auto-update${NC}"
        fi
    else
        echo -e "${YELLOW}[WARN] No .claude/settings.json — safety hooks inactive${NC}"
    fi
```

Replace it with:

```bash
    # 4. Hooks
    if [ -f ".claude/settings.json" ]; then
        if grep -q "PostToolUse" ".claude/settings.json" 2>/dev/null; then
            echo -e "${GREEN}[OK]   PostToolUse hook active (last-reviewed auto-updates)${NC}"
        else
            echo -e "${YELLOW}[WARN] No PostToolUse hook — last-reviewed won't auto-update${NC}"
        fi
        # Hook script existence: extract full relative paths from "command": lines,
        # deduplicate by logical name (basename), check any implementation file exists.
        # Works for both adopted projects (scripts/X) and this repo (templates/scripts/X).
        SEEN_HOOK_NAMES=""
        MISSING_HOOKS=()
        PRESENT_HOOKS=()
        HOOK_PATHS=$(grep '"command":' ".claude/settings.json" 2>/dev/null \
            | grep -oE '[A-Za-z][A-Za-z0-9_/-]*\.(sh|ps1)' \
            | sort -u)
        for hook_path in $HOOK_PATHS; do
            base="${hook_path%.*}"
            name="$(basename "$base")"
            case " $SEEN_HOOK_NAMES " in *" $name "*) continue ;; esac
            SEEN_HOOK_NAMES="$SEEN_HOOK_NAMES $name"
            if compgen -G "${base}.*" > /dev/null 2>&1; then
                PRESENT_HOOKS+=("$name")
            else
                MISSING_HOOKS+=("$name")
            fi
        done
        if [ ${#MISSING_HOOKS[@]} -eq 0 ] && [ ${#PRESENT_HOOKS[@]} -gt 0 ]; then
            echo -e "${GREEN}[OK]   Hook scripts present ($(IFS=', '; echo "${PRESENT_HOOKS[*]}"))${NC}"
        elif [ ${#MISSING_HOOKS[@]} -gt 0 ]; then
            for h in "${MISSING_HOOKS[@]}"; do
                echo -e "${YELLOW}[WARN] Hook script missing: $h — run 'mb init' to install${NC}"
            done
        fi
    else
        echo -e "${YELLOW}[WARN] No .claude/settings.json — safety hooks inactive${NC}"
    fi
```

- [ ] **Step 3: Verify the block was inserted correctly**

```bash
grep -A 35 "4\. Hooks" scripts/mb.sh | head -40
```

Expected: shows the full new block including `SEEN_HOOK_NAMES`, `HOOK_PATHS`, `compgen -G`, and the output logic.

- [ ] **Step 4: Run shellcheck**

```bash
shellcheck --severity=error scripts/mb.sh
```

Expected: no output (exit 0).

- [ ] **Step 5: Quick smoke test — run mb doctor from the repo root**

```bash
bash scripts/mb.sh doctor 2>/dev/null | grep -A 3 "Hooks"
```

Expected output (approximately):
```
[OK]   PostToolUse hook active (last-reviewed auto-updates)
[OK]   Hook scripts present (dangerous-commands, check-contract, update-reviewed)
```

(The exact names may appear in different order; all three should be in the OK line.)

- [ ] **Step 6: Commit**

```bash
git add scripts/mb.sh
git commit -m "feat(doctor): Check #4 now verifies hook script existence (basename-agnostic)"
```

---

## Task 7: Extend mb.ps1 Show-Doctor() Check #4 — Hook Script Existence

PowerShell parallel of Task 6.

**Files:**
- Modify: `scripts/mb.ps1` (~35 lines replacing the existing ~14-line Check #4 block)

- [ ] **Step 1: Locate the current Check #4 block**

```bash
grep -n "4\. Hooks" scripts/mb.ps1
```

Expected: one line like `502:    # 4. Hooks`

- [ ] **Step 2: Replace the Check #4 block**

In `scripts/mb.ps1`, find this exact text (the complete `# 4. Hooks` block):

```powershell
    # 4. Hooks
    $settingsPath = ".claude/settings.json"
    if (Test-Path $settingsPath) {
        $settings = Get-Content $settingsPath -Raw
        if ($settings -match "PostToolUse") {
            Write-Host "[OK]   PostToolUse hook active (last-reviewed auto-updates)" -ForegroundColor Green
        } else {
            Write-Host "[WARN] No PostToolUse hook — last-reviewed won't auto-update" -ForegroundColor Yellow
            Write-Host "       Copy templates/.claude/settings.json to enable" -ForegroundColor DarkGray
        }
    } else {
        Write-Host "[WARN] No .claude/settings.json — safety hooks inactive" -ForegroundColor Yellow
        Write-Host "       Copy templates/.claude/settings.json to enable" -ForegroundColor DarkGray
    }
```

Replace it with:

```powershell
    # 4. Hooks
    $settingsPath = ".claude/settings.json"
    if (Test-Path $settingsPath) {
        $settings = Get-Content $settingsPath -Raw
        if ($settings -match "PostToolUse") {
            Write-Host "[OK]   PostToolUse hook active (last-reviewed auto-updates)" -ForegroundColor Green
        } else {
            Write-Host "[WARN] No PostToolUse hook — last-reviewed won't auto-update" -ForegroundColor Yellow
            Write-Host "       Copy templates/.claude/settings.json to enable" -ForegroundColor DarkGray
        }
        # Hook script existence: extract full relative paths from "command": lines,
        # deduplicate by logical name (basename), check any implementation file exists.
        # Works for both adopted projects (scripts/X) and this repo (templates/scripts/X).
        $commandLines = ($settings -split "`n") | Where-Object { $_ -match '"command":' }
        $hookPaths = $commandLines | ForEach-Object {
            [regex]::Matches($_, '[A-Za-z][A-Za-z0-9_/-]*\.(sh|ps1)') | ForEach-Object { $_.Value }
        } | Sort-Object -Unique
        $seenBases = @{}
        $missingHooks = @()
        $presentHooks = @()
        foreach ($hookPath in $hookPaths) {
            $base = $hookPath -replace '\.[^.]+$', ''
            $name = Split-Path -Leaf $base
            if ($seenBases.ContainsKey($name)) { continue }
            $seenBases[$name] = $true
            if (Get-ChildItem "${base}.*" -ErrorAction SilentlyContinue) {
                $presentHooks += $name
            } else {
                $missingHooks += $name
            }
        }
        if ($missingHooks.Count -eq 0 -and $presentHooks.Count -gt 0) {
            Write-Host "[OK]   Hook scripts present ($($presentHooks -join ', '))" -ForegroundColor Green
        } elseif ($missingHooks.Count -gt 0) {
            foreach ($h in $missingHooks) {
                Write-Host "[WARN] Hook script missing: $h — run 'mb init' to install" -ForegroundColor Yellow
            }
        }
    } else {
        Write-Host "[WARN] No .claude/settings.json — safety hooks inactive" -ForegroundColor Yellow
        Write-Host "       Copy templates/.claude/settings.json to enable" -ForegroundColor DarkGray
    }
```

- [ ] **Step 3: Verify the block was inserted correctly**

```bash
grep -A 40 "4\. Hooks" scripts/mb.ps1 | head -45
```

Expected: shows the full new block including `$commandLines`, `$hookPaths`, `Get-ChildItem "${base}.*"`, and the output logic.

- [ ] **Step 4: Commit**

```bash
git add scripts/mb.ps1
git commit -m "feat(doctor): Check #4 now verifies hook script existence — PowerShell"
```

---

## Task 8: Add CI template-integrity Job

Add a new job to `.github/workflows/governance.yml` that validates every script path referenced in `templates/.claude/settings.json` has a corresponding file in `templates/scripts/`.

**Files:**
- Modify: `.github/workflows/governance.yml` (add job after `secret-scan`)

- [ ] **Step 1: Read the current end of governance.yml to confirm where to append**

```bash
tail -20 .github/workflows/governance.yml
```

Expected: the last few lines of the `secret-scan` job.

- [ ] **Step 2: Append the template-integrity job**

In `.github/workflows/governance.yml`, find the last line of the file (the closing of the `secret-scan` job):

```yaml
      - uses: gitleaks/gitleaks-action@v2.3.9
        env:
          GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}
          FORCE_JAVASCRIPT_ACTIONS_TO_NODE24: true
```

Replace it with:

```yaml
      - uses: gitleaks/gitleaks-action@v2.3.9
        env:
          GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}
          FORCE_JAVASCRIPT_ACTIONS_TO_NODE24: true

  template-integrity:
    name: Template Integrity
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v6.0.2

      - name: Validate hook scripts referenced in templates/.claude/settings.json exist in templates/scripts/
        shell: bash
        run: |
          FAIL=0
          SETTINGS="templates/.claude/settings.json"

          # Extract full relative base paths (without extension) from "command": lines
          # e.g. scripts/dangerous-commands.ps1 → scripts/dangerous-commands
          BASEPATHS=$(grep '"command":' "$SETTINGS" \
            | grep -oE '[A-Za-z][A-Za-z0-9_/-]*\.(sh|ps1)' \
            | sed 's/\.[^.]*$//' \
            | sort -u)

          for base in $BASEPATHS; do
            # Canonical substrate: the script must exist under templates/
            if compgen -G "templates/${base}.*" > /dev/null 2>&1; then
              echo "OK:   templates/${base}.* present"
            else
              echo "ERROR: $SETTINGS references $base but the script is missing from templates/:"
              printf  "       Expected: templates/%s.sh\n" "$base"
              printf  "       Expected: templates/%s.ps1\n" "$base"
              FAIL=1
            fi
          done

          [ "$FAIL" -eq 0 ] && echo "template-integrity: PASS" || echo "template-integrity: FAIL"
          exit $FAIL
```

- [ ] **Step 3: Verify the YAML structure is valid**

```bash
python3 -c "import yaml; yaml.safe_load(open('.github/workflows/governance.yml'))" && echo "YAML valid"
```

Expected: `YAML valid`

- [ ] **Step 4: Verify the new job appears at the right indentation level**

```bash
grep -E "^  [a-z]" .github/workflows/governance.yml
```

Expected: four lines — `file-size:`, `forbidden-patterns:`, `secret-scan:`, `template-integrity:` — all at the same `  ` (two-space) indentation.

- [ ] **Step 5: Commit**

```bash
git add .github/workflows/governance.yml
git commit -m "ci: add template-integrity job — validates templates/.claude/settings.json references exist in templates/scripts/"
```

---

## Task 9: Manual Verification and Final Commit

No automated test framework exists for mb.sh/mb.ps1. Verify all three changes work end-to-end.

**Files:** (verification only — no file changes unless bugs found)

- [ ] **Step 1: Run mb doctor from repo root — expect OK for hook scripts**

```bash
bash scripts/mb.sh doctor 2>/dev/null
```

Expected in output (lines may be interspersed with others):
```
[OK]   PostToolUse hook active (last-reviewed auto-updates)
[OK]   Hook scripts present (dangerous-commands, check-contract, update-reviewed)
```

If you see `[WARN] Hook script missing:` instead, the `.claude/settings.json` path update (Task 3) or `compgen -G` check (Task 6) has a bug. Re-read both files.

- [ ] **Step 2: Simulate a project that's missing hook scripts — expect WARN**

```bash
mkdir -p /tmp/mb-test/.claude
cp .claude/settings.json /tmp/mb-test/.claude/settings.json
```

Now run doctor from that directory (hook scripts won't exist there):

```bash
cd /tmp/mb-test && bash /c/Users/Mizzo/Claude/Personal-Memory-Bank/scripts/mb.sh doctor 2>/dev/null | grep -A 5 "4\. Hooks"
```

Expected:
```
[OK]   PostToolUse hook active (last-reviewed auto-updates)
[WARN] Hook script missing: dangerous-commands — run 'mb init' to install
[WARN] Hook script missing: check-contract — run 'mb init' to install
[WARN] Hook script missing: update-reviewed — run 'mb init' to install
```

(3 WARN lines because the temp dir has no `scripts/` at all)

```bash
cd /c/Users/Mizzo/Claude/Personal-Memory-Bank
```

Return to repo root before Step 3.

- [ ] **Step 3: Simulate mb init on a fresh project — expect hook scripts copied**

```bash
rm -rf /tmp/mb-init-test && mkdir /tmp/mb-init-test
cd /tmp/mb-init-test && bash /c/Users/Mizzo/Claude/Personal-Memory-Bank/scripts/mb.sh init
```

Expected output: `[+] scripts/dangerous-commands.sh`, `[+] scripts/dangerous-commands.ps1`, `[+] scripts/check-contract.sh`, `[+] scripts/check-contract.ps1`, `[+] scripts/update-reviewed.sh`, `[+] scripts/update-reviewed.ps1` (among other `[+]` lines).

```bash
ls /tmp/mb-init-test/scripts/
```

Expected: 6 files — all 6 hook scripts.

Then run doctor from that initialized project:

```bash
cd /tmp/mb-init-test && bash /c/Users/Mizzo/Claude/Personal-Memory-Bank/scripts/mb.sh doctor 2>/dev/null | grep "Hook"
```

Expected: `[OK]   Hook scripts present (dangerous-commands, check-contract, update-reviewed)`

```bash
cd /c/Users/Mizzo/Claude/Personal-Memory-Bank
```

Return to repo root.

- [ ] **Step 4: Run shellcheck on all modified shell scripts**

```bash
shellcheck --severity=error scripts/mb.sh templates/scripts/dangerous-commands.sh templates/scripts/check-contract.sh templates/scripts/update-reviewed.sh
```

Expected: no output (exit 0). The scripts moved to templates/scripts/ haven't changed content, so any pre-existing shellcheck issues would have existed before.

- [ ] **Step 5: Verify git log looks clean**

```bash
git log --oneline feat/governance-integrity ^master
```

Expected: 7 commits in reverse order:
```
<sha>  ci: add template-integrity job ...
<sha>  feat(doctor): Check #4 now verifies hook script existence — PowerShell
<sha>  feat(doctor): Check #4 now verifies hook script existence (basename-agnostic)
<sha>  feat(init): copy hook scripts from templates/scripts/ on mb init (PowerShell)
<sha>  feat(init): copy hook scripts from templates/scripts/ on mb init
<sha>  fix: update .claude/settings.json hook paths after templates/scripts/ migration
<sha>  refactor: move hook scripts to templates/scripts/ (canonical adoptable surface)
```

- [ ] **Step 6: Clean up temp directories**

```bash
rm -rf /tmp/mb-test /tmp/mb-init-test
```
