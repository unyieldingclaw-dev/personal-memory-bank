# PMB CI Hardening — Workstream 3 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add two new CI jobs to `.github/workflows/pmb-health.yml` — PowerShell linting via PSScriptAnalyzer and an mb doctor self-check.

**Architecture:** Both jobs are appended after the existing `mb-command-tests` job (the last job in the file, line 244). No existing jobs are modified. Each job is independent and can be added in either order.

**Tech Stack:** GitHub Actions YAML, PowerShell 7 (pwsh, pre-installed on ubuntu-latest), PSScriptAnalyzer module, bash.

---

## File Map

| File | Change |
|---|---|
| `.github/workflows/pmb-health.yml` | Append 2 new jobs after line 252 |

---

## Task 1: Add `powershell-lint` job

**Files:**
- Modify: `.github/workflows/pmb-health.yml` (append after line 252)

- [ ] **Step 1: Verify current file ends at line 252**

```bash
cd "C:\Users\Mizzo\Claude\Personal-Memory-Bank"
wc -l .github/workflows/pmb-health.yml
tail -5 .github/workflows/pmb-health.yml
```

Expected: file ends with `run: bash tests/run.sh` followed by a blank line (line ~252-253).

- [ ] **Step 2: Append the powershell-lint job**

Add this block at the end of `.github/workflows/pmb-health.yml` (after the last line):

```yaml

  powershell-lint:
    name: PowerShell Lint
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v6.0.2

      - name: Install PSScriptAnalyzer
        shell: pwsh
        run: Install-Module -Name PSScriptAnalyzer -Force -Scope CurrentUser

      - name: Lint PowerShell scripts
        shell: pwsh
        run: |
          $files = Get-ChildItem -Recurse -Filter "*.ps1" -Path "scripts","templates/scripts" |
            Select-Object -ExpandProperty FullName
          $results = $files | ForEach-Object {
            Invoke-ScriptAnalyzer -Path $_ -Severity Error
          }
          if ($results) {
            $results | Format-Table RuleName,Severity,Line,Message -AutoSize
            exit 1
          }
          Write-Host "PSScriptAnalyzer: no errors found in $($files.Count) file(s)"
```

**Important:** The `powershell-lint:` key must be indented at 2 spaces (same level as `mb-command-tests:`), inside the `jobs:` block. The file has no closing `}` — YAML jobs blocks are open-ended, so appending at the bottom is correct.

- [ ] **Step 3: Validate YAML syntax locally**

```bash
cd "C:\Users\Mizzo\Claude\Personal-Memory-Bank"
python3 -c "import yaml; yaml.safe_load(open('.github/workflows/pmb-health.yml'))" && echo "valid YAML"
```

Expected: `valid YAML`

- [ ] **Step 4: Verify the job appears in the file**

```bash
grep -n "powershell-lint\|PSScriptAnalyzer\|Lint PowerShell" .github/workflows/pmb-health.yml
```

Expected: 3 matching lines with correct line numbers.

- [ ] **Step 5: Run existing bash tests to confirm no regressions**

```bash
bash tests/run.sh 2>&1 | tail -4
```

Expected: `All test suites passed.`

- [ ] **Step 6: Commit**

```bash
cd "C:\Users\Mizzo\Claude\Personal-Memory-Bank"
git add .github/workflows/pmb-health.yml
git commit -m "ci: add powershell-lint job — PSScriptAnalyzer at Error severity on all .ps1 files"
```

---

## Task 2: Add `mb-doctor-self-check` job

**Files:**
- Modify: `.github/workflows/pmb-health.yml` (append after `powershell-lint` job)

- [ ] **Step 1: Verify mb doctor runs successfully on this repo**

```bash
cd "C:\Users\Mizzo\Claude\Personal-Memory-Bank"
MB_HOME="$(pwd)" bash scripts/mb.sh doctor 2>&1 | tail -10
```

Expected: doctor output ends without crashing. Some `[WARN]` lines are expected (e.g. no active task contract, hooks not wired in CI); `[ERROR]` lines are not expected. Confirm exit code:

```bash
MB_HOME="$(pwd)" bash scripts/mb.sh doctor > /dev/null 2>&1; echo "exit: $?"
```

Expected: `exit: 0`

- [ ] **Step 2: Append the mb-doctor-self-check job**

Add this block at the end of `.github/workflows/pmb-health.yml` (after the `powershell-lint` job):

```yaml

  mb-doctor-self-check:
    name: MB Doctor Self-Check
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v6.0.2

      - name: Run mb doctor on this repo
        shell: bash
        run: MB_HOME="$(pwd)" bash scripts/mb.sh doctor
```

- [ ] **Step 3: Validate YAML syntax**

```bash
cd "C:\Users\Mizzo\Claude\Personal-Memory-Bank"
python3 -c "import yaml; yaml.safe_load(open('.github/workflows/pmb-health.yml'))" && echo "valid YAML"
```

Expected: `valid YAML`

- [ ] **Step 4: Verify both new jobs appear**

```bash
grep -n "powershell-lint:\|mb-doctor-self-check:\|mb-command-tests:" .github/workflows/pmb-health.yml
```

Expected: 3 lines — `mb-command-tests` then `powershell-lint` then `mb-doctor-self-check`.

- [ ] **Step 5: Count total jobs in the workflow**

```bash
grep -c "^\s\{2\}[a-z].*:$\|^  [a-z][a-z-]*:$" .github/workflows/pmb-health.yml
```

Expected: 9 (7 original + 2 new).

- [ ] **Step 6: Run existing bash tests**

```bash
bash tests/run.sh 2>&1 | tail -4
```

Expected: `All test suites passed.`

- [ ] **Step 7: Commit and push**

```bash
cd "C:\Users\Mizzo\Claude\Personal-Memory-Bank"
git add .github/workflows/pmb-health.yml
git commit -m "ci: add mb-doctor-self-check job — run mb doctor against the PMB repo on every push"
git push origin main
```

---

## Final Verification

After both commits are pushed:

```bash
cd "C:\Users\Mizzo\Claude\Personal-Memory-Bank"

# 1. YAML is valid
python3 -c "import yaml; yaml.safe_load(open('.github/workflows/pmb-health.yml'))" && echo "valid"

# 2. Both jobs present
grep -E "powershell-lint:|mb-doctor-self-check:" .github/workflows/pmb-health.yml

# 3. Tests still pass
bash tests/run.sh 2>&1 | tail -3
```

Then check GitHub Actions at `https://github.com/unyieldingclaw-dev/personal-memory-bank/actions` to confirm both new jobs appear and pass on the push.
