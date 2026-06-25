---
status: approved
created: 2026-06-24
approved: 2026-06-24
related_spec: null
scope: local
risk: low
source: ai-draft
---

# PMB CI Hardening — Workstream 3

## Context

Full-project audit on 2026-06-24 identified two CI gaps:
1. PowerShell scripts (`.ps1`) have zero linting — shellcheck covers bash, but nothing covers PowerShell
2. `mb doctor` never runs in CI against the PMB repo itself — drift in memory-bank, standards count, plan hygiene, and hook config goes undetected until a human runs it manually

Skipped markdownlint (markdown linting adds noise for a docs-heavy repo; shellcheck + PSScriptAnalyzer together cover the real format gap).

---

## Changes

Two new jobs added to `.github/workflows/pmb-health.yml`.

---

## Job 1: `powershell-lint`

**Purpose:** Lint all `.ps1` files with PSScriptAnalyzer at Error severity. Bash scripts already have `shellcheck` in the `sast` job.

**Runner:** `ubuntu-latest` (pwsh is pre-installed on GitHub-hosted runners since 2021)

**Files scanned:** `scripts/*.ps1` and `templates/scripts/*.ps1`

**Severity:** Only `Error`-level findings fail the job. `Warning` and `Information` findings are advisory — they appear in the log but do not block CI.

**Rationale for Error-only:** PSScriptAnalyzer's Warning rules include stylistic preferences (e.g. alias usage like `ls` instead of `Get-ChildItem`) that are intentional in PMB's hook scripts for readability. Error-level rules catch real bugs: undefined variables, missing mandatory parameters, syntax errors, and command injection patterns.

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

---

## Job 2: `mb-doctor-self-check`

**Purpose:** Run `mb doctor` against the PMB repo itself on every push/PR. Catches: memory-bank drift, stale files, missing standards, plan hygiene issues, compaction integrity problems, hook config gaps.

**Runner:** `ubuntu-latest`

**Exit behavior:** `mb doctor` exits 0 unless it crashes. The job surfaces all `[OK]`, `[WARN]`, and `[ERROR]` output in the CI log. An `[ERROR]` in the log is visible to reviewers even though the job doesn't hard-fail — this matches the design intent of `mb doctor` as a visibility tool, not a hard gate.

**MB_HOME:** Set to `$(pwd)` (the checkout root) so the script resolves templates, VERSION, and fixtures relative to the repo itself.

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

---

## File Modified

| File | Change |
|---|---|
| `.github/workflows/pmb-health.yml` | Add `powershell-lint` job and `mb-doctor-self-check` job |

---

## Verification

After pushing:
1. Check GitHub Actions tab — both new jobs appear and pass
2. PSScriptAnalyzer output visible in `powershell-lint` job log
3. `mb doctor` output visible in `mb-doctor-self-check` job log
4. All existing jobs (file-size, forbidden-patterns, secret-scan, sast, rules-file-integrity, template-integrity, mb-command-tests) still pass
