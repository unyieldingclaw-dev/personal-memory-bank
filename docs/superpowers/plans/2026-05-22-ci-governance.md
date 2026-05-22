# CI Governance Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Create `.github/workflows/governance.yml` (three parallel jobs: file-size, forbidden-patterns, secret-scan) and `.gitleaks.toml` to add the CI deterministic gate layer to the Personal Memory Bank enforcement stack.

**Architecture:** Single workflow file with three parallel jobs that run on every push and PR to master. Jobs are independent — all three run even if one fails. No new directories beyond `.github/workflows/`.

**Tech Stack:** GitHub Actions, ubuntu-latest, Bash, shellcheck (pre-installed), gitleaks/gitleaks-action@v2, actions/checkout@v4

---

## Pre-Plan Research Findings (incorporated into tasks below)

These differ from the brainstormed spec — apply them:

1. **File-size scope**: strict check targets `memory-bank/*.md` (NOT `templates/memory-bank/`). Template files are 156–176 lines; they'd immediately fail the 150-line threshold.
2. **Credential grep pattern**: must include `{8,}` minimum length: `(password|api_key|token|secret)\s*=\s*[A-Za-z0-9]{8,}`. Verified clean exit against current repo. Without `{8,}`, documentation examples like `api_key=api_key` produce false positives.
3. **Plan file exclusion**: `docs/superpowers/plans/` must be excluded from the relaxed file-size check. The 2026-04-21 plan is 1,670 lines — it would fail the 800-line threshold immediately.
4. **No local shellcheck**: verification for shellcheck job deferred to CI run. Node v24.15.0 available locally.

---

## File Structure

**Create:**
- `.github/workflows/governance.yml` — single workflow, three parallel jobs (~80 lines)
- `.gitleaks.toml` — allowlist scaffold (comments only, no active rules)

**No files modified.**

---

### Task 1: Create `.gitleaks.toml` allowlist scaffold

**Files:**
- Create: `.gitleaks.toml`

- [ ] **Step 1: Create the file**

```toml
# Gitleaks allowlist — add entries here to suppress known false positives.
# Documentation: https://github.com/gitleaks/gitleaks#configuration
#
# Example entry:
# [[allowlist]]
# description = "known safe example value in docs"
# paths = ["docs/superpowers/specs/example.md"]
# regexes = ["EXAMPLE_KEY_FOR_DOCS"]
```

- [ ] **Step 2: Verify file exists at repo root**

Run: `ls -la .gitleaks.toml`
Expected: file exists, non-empty

- [ ] **Step 3: Commit**

```bash
git add .gitleaks.toml
git commit -m "ci: add gitleaks allowlist scaffold for future false-positive suppression"
```

---

### Task 2: Implement `file-size` job

**Files:**
- Create: `.github/workflows/governance.yml` (initial version with file-size job only; later tasks add the other two jobs)

**Key implementation details:**
- Strict threshold (`memory-bank/*.md`): warn >80 lines, fail >150 lines
- Relaxed threshold (all other `.md`): warn >500 lines, fail >800 lines
- Exclude from relaxed check: `.git/`, `memory-bank/`, `docs/superpowers/plans/`
- Use `find ... -print0 | while IFS= read -r -d '' file` (null-safe, handles spaces)
- Report all offenders before exiting non-zero (collect failures, then exit)

- [ ] **Step 1: Create `.github/workflows/` directory and write the initial workflow**

```bash
mkdir -p .github/workflows
```

Write `.github/workflows/governance.yml`:

```yaml
name: Governance

on:
  push:
    branches: [master]
  pull_request:
    branches: [master]

jobs:
  file-size:
    name: File Size
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Check file sizes
        shell: bash
        run: |
          FAIL=0

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

          echo ""
          echo "=== all other markdown files (warn: 500, fail: 800) ==="
          while IFS= read -r -d '' file; do
            lines=$(wc -l < "$file")
            if [ "$lines" -gt 800 ]; then
              echo "FAIL: $file ($lines lines -- limit 800)"
              FAIL=1
            elif [ "$lines" -gt 500 ]; then
              echo "WARN: $file ($lines lines -- warn 500)"
            fi
          done < <(find . -name "*.md" \
            -not -path "./memory-bank/*" \
            -not -path "./.git/*" \
            -not -path "./docs/superpowers/plans/*" \
            -print0)

          echo ""
          [ "$FAIL" -eq 0 ] && echo "file-size: PASS" || echo "file-size: FAIL"
          exit $FAIL
```

- [ ] **Step 2: Verify the bash locally against the actual repo**

Run the file-size script locally (from repo root, bash):

```bash
FAIL=0

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

echo ""
echo "=== all other markdown files (warn: 500, fail: 800) ==="
while IFS= read -r -d '' file; do
  lines=$(wc -l < "$file")
  if [ "$lines" -gt 800 ]; then
    echo "FAIL: $file ($lines lines -- limit 800)"
    FAIL=1
  elif [ "$lines" -gt 500 ]; then
    echo "WARN: $file ($lines lines -- warn 500)"
  fi
done < <(find . -name "*.md" \
  -not -path "./memory-bank/*" \
  -not -path "./.git/*" \
  -not -path "./docs/superpowers/plans/*" \
  -print0)

echo ""
[ "$FAIL" -eq 0 ] && echo "file-size: PASS" || echo "file-size: FAIL"
exit $FAIL
```

Expected: exit 0. No FAIL lines. Memory-bank files should all be OK (all under 75 lines). Other markdown files may show WARN for large docs but no FAIL (specs and READMEs are under 200 lines; plans are excluded).

If any FAIL lines appear, investigate before committing — the script or exclusions need adjustment.

- [ ] **Step 3: Commit**

```bash
git add .github/workflows/governance.yml
git commit -m "ci: add file-size job (memory-bank strict, docs relaxed, plans excluded)"
```

---

### Task 3: Implement `forbidden-patterns` job

**Files:**
- Modify: `.github/workflows/governance.yml` — add `forbidden-patterns` job

**Key implementation details:**
- Credential grep: `(password|api_key|token|secret)\s*=\s*[A-Za-z0-9]{8,}` with `-P` (Perl regex), `-i` (case-insensitive), `git grep` (respects .gitignore). Exclude `.gitleaks.toml` and `.gitignore` from scan with pathspec exclusion.
- Spec placeholder grep: `find docs/superpowers/specs -name "*.md" | xargs grep -lE '\bTBD\b|\bTODO\b'`
- Shellcheck: `find scripts templates/scripts -name "*.sh" -print0 | xargs -0 shellcheck --severity=error`

- [ ] **Step 1: Add `forbidden-patterns` job to the workflow**

Read the current `.github/workflows/governance.yml` and add the `forbidden-patterns` job after the `file-size` job:

```yaml
  forbidden-patterns:
    name: Forbidden Patterns
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Credential grep
        shell: bash
        run: |
          if git grep -P -i '(password|api_key|token|secret)\s*=\s*[A-Za-z0-9]{8,}' \
            -- ':(exclude).gitleaks.toml' ':(exclude).gitignore'; then
            echo "FAIL: Literal credential assignment found above"
            exit 1
          fi
          echo "OK: No literal credential assignments found"

      - name: Spec placeholder grep
        shell: bash
        run: |
          FOUND=$(find docs/superpowers/specs -name "*.md" -print0 \
            | xargs -0 grep -lE '\bTBD\b|\bTODO\b' 2>/dev/null || true)
          if [ -n "$FOUND" ]; then
            echo "FAIL: TBD or TODO found in spec files:"
            echo "$FOUND"
            exit 1
          fi
          echo "OK: No TBD/TODO in spec files"

      - name: Shellcheck
        shell: bash
        run: |
          find scripts templates/scripts -name "*.sh" -print0 \
            | xargs -0 shellcheck --severity=error
```

The complete `jobs:` block now has two jobs: `file-size` and `forbidden-patterns`.

- [ ] **Step 2: Verify credential grep locally**

Run from repo root (bash):

```bash
if git grep -P -i '(password|api_key|token|secret)\s*=\s*[A-Za-z0-9]{8,}' \
  -- ':(exclude).gitleaks.toml' ':(exclude).gitignore'; then
  echo "FAIL: matches found"
  exit 1
fi
echo "OK: exit $?"
```

Expected: exit 1 from `git grep` (no matches found = grep exits 1) → the `if` branch is NOT taken → "OK" is printed → overall script exits 0.

Wait — `git grep` exits 1 when no matches are found. The `if` condition is true only when `git grep` exits 0 (matches found). So no matches → `git grep` exits 1 → `if` is false → fall through to the echo → script exits 0. That is correct behavior.

If any matches are printed, identify them. All current repo files should produce no matches (verified during pre-plan research with the `{8,}` pattern).

- [ ] **Step 3: Verify spec placeholder grep locally**

Run from repo root (bash):

```bash
FOUND=$(find docs/superpowers/specs -name "*.md" -print0 \
  | xargs -0 grep -lE '\bTBD\b|\bTODO\b' 2>/dev/null || true)
if [ -n "$FOUND" ]; then
  echo "FAIL: $FOUND"
  exit 1
fi
echo "OK: no TBD/TODO in specs"
```

Expected: "OK: no TBD/TODO in specs". All spec files were written following the writing-plans "no placeholders" rule.

- [ ] **Step 4: Commit**

```bash
git add .github/workflows/governance.yml
git commit -m "ci: add forbidden-patterns job (credential grep, spec placeholder, shellcheck)"
```

---

### Task 4: Implement `secret-scan` job and push to CI

**Files:**
- Modify: `.github/workflows/governance.yml` — add `secret-scan` job

**Key implementation details:**
- `fetch-depth: 0` on checkout — gitleaks needs full history for push scans
- `GITHUB_TOKEN` environment variable is required by the action
- No `.gitleaks.toml` configuration needed beyond the scaffold (default ruleset handles this repo)

- [ ] **Step 1: Add `secret-scan` job to the workflow**

Read the current `.github/workflows/governance.yml` and add the `secret-scan` job after `forbidden-patterns`:

```yaml
  secret-scan:
    name: Secret Scan
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
        with:
          fetch-depth: 0
      - uses: gitleaks/gitleaks-action@v2
        env:
          GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}
```

The complete workflow now has three parallel jobs: `file-size`, `forbidden-patterns`, `secret-scan`.

- [ ] **Step 2: Read the complete workflow file and verify structure**

Read `.github/workflows/governance.yml` in full. Confirm:
- `on:` block triggers on push and PR to master
- Three jobs defined: `file-size`, `forbidden-patterns`, `secret-scan`
- All three run on `ubuntu-latest`
- `secret-scan` has `fetch-depth: 0`
- `secret-scan` has `GITHUB_TOKEN` env var
- No `needs:` dependencies (all three are parallel)
- YAML indentation is consistent (2-space)

- [ ] **Step 3: Commit**

```bash
git add .github/workflows/governance.yml
git commit -m "ci: add secret-scan job via gitleaks-action@v2"
```

- [ ] **Step 4: Push all commits to origin**

```bash
git push origin master
```

Expected: push succeeds. Three commits pushed (Tasks 1–3 commits, plus Task 4 commit = 4 commits total from this work, plus the Task 1 .gitleaks.toml commit).

- [ ] **Step 5: Verify CI triggered (check GitHub Actions)**

Run:

```bash
gh run list --limit 5
```

Expected: a workflow run named "Governance" appears with status "queued" or "in_progress" or "completed". If "completed", check the conclusion:

```bash
gh run view --log-failed
```

Expected: all three jobs pass. If any job fails, read the failure output and fix.

**Common failure modes to check:**
- `file-size` FAIL: a markdown file exceeded threshold unexpectedly → check which file and add exclusion if justified
- `forbidden-patterns` credential grep: a new file has a pattern match → read the match and determine if it's a real credential or needs allowlisting
- `secret-scan`: gitleaks found a high-entropy string → add `.gitleaks.toml` allowlist entry with the path and regex
- `shellcheck` error: a shell script has a shellcheck error (e.g., unquoted variable `$FILE`) → fix the script

---

## Verification Checklist (Post-Push)

After CI completes green:

- [ ] `file-size` job green: memory-bank files all under 150 lines; no plan files scanned
- [ ] `forbidden-patterns` job green: credential grep, spec placeholder grep, shellcheck all pass
- [ ] `secret-scan` job green: gitleaks found no secrets in history or diff
- [ ] `gh run view` shows all three jobs with conclusion `success`
- [ ] Run `git log --oneline -6` — confirm 4 new commits (gitleaks scaffold + 3 workflow commits) are present and pushed

## Post-Merge: Branch Protection (Manual)

After CI confirms green, configure branch protection in GitHub Settings:

1. Settings → Branches → Add rule for `master`
2. Require status checks: `File Size`, `Forbidden Patterns`, `Secret Scan`
3. Require branches to be up to date before merging

This step cannot be automated — it is a one-time manual GitHub UI action.
