# CI Governance — Design

## Context

The Personal Memory Bank repo completed Sub-projects A (hook coverage) and D (philosophy docs). The four-layer enforcement stack now has its advisory layer (CLAUDE.md), deterministic structural layer (hooks), and semantic layer (Reviewer / Opponent) documented. Sub-project C adds the fourth layer: **deterministic CI gates** — machine-checkable governance that runs on every push and PR, cannot be talked around, and enforces patterns the hook layer cannot (full-history secret scanning, file size budgets, spec placeholder hygiene, shell script safety).

No `.github/` directory exists. CI starts from scratch.

## Design

### Approach: Single workflow, three parallel jobs

One file: `.github/workflows/governance.yml`. Three jobs run in parallel on every push and PR to master:

| Job | Tool | What it catches |
|-----|------|----------------|
| `file-size` | bash `find` + `wc -l` | Files exceeding size thresholds by directory |
| `forbidden-patterns` | `grep` + `shellcheck` | Literal credential values, spec placeholders, unsafe shell |
| `secret-scan` | `gitleaks/gitleaks-action@v2` | Secrets in git history / PR diff |

**Why parallel:** Jobs are independent. All three complete in the time of the slowest one. Full feedback in one CI run even when multiple jobs fail.

**Why one file:** Single status check to configure in branch protection. One place to maintain.

### Triggers

```yaml
on:
  push:
    branches: [master]
  pull_request:
    branches: [master]
```

No scheduled runs — on-push is sufficient for a template repo with no time-sensitive drift.

### Job 1: `file-size`

Runs `find` + `wc -l` against two directory sets with different thresholds.

**Thresholds:**

| Scope | Warn | Fail |
|-------|------|------|
| `templates/memory-bank/*.md` | 80 lines | 150 lines |
| Everything else (`standards/*.md`, `docs/**/*.md`, `templates/**/*.md` excluding memory-bank) | 500 lines | 800 lines |

Rationale for tight memory-bank limits: each memory-bank file is read into context on every AI session. Files that grow past ~100 lines start consuming meaningful context budget. The `standards/MEMORY-BANK.md` doc already states size targets; CI enforces them.

**Behavior:**
- Warn threshold: prints the file name and line count, continues (exit 0)
- Fail threshold: prints the file name and line count, sets a flag, exits non-zero after checking all files (so all offenders are reported in one run)

### Job 2: `forbidden-patterns`

Three sub-checks, all in one job, run sequentially. Job fails if any sub-check fails.

**Sub-check 1 — Credential grep**

Scans all tracked files for literal credential assignments:

```
pattern: (?i)(password|api_key|token|secret)\s*=\s*[^${\(\s'"\n]
```

This matches `password=abc123` but skips:
- Variable references: `password=$PASSWORD`, `token=${API_KEY}`
- Template placeholders: `token="<your-token>"`, `api_key='...'`
- Empty assignments: `secret=`

Any match is a CI failure. Gitleaks covers structured secret formats (AWS keys, GitHub PATs, etc.); this grep covers prose credential assignments in markdown and config files that pattern-based scanners miss.

**Sub-check 2 — Spec placeholder grep**

Scans `docs/superpowers/specs/*.md` for forbidden placeholders:

```
pattern: \bTBD\b|\bTODO\b
```

Any match fails. The writing-plans skill explicitly forbids TBD/TODO in spec docs; this makes that a hard gate rather than advisory.

**Sub-check 3 — Shellcheck**

Runs `shellcheck` on all `.sh` files:
- `scripts/*.sh`
- `templates/scripts/*.sh`

```bash
shellcheck --severity=error scripts/*.sh templates/scripts/*.sh
```

`--severity=error` means only errors fail CI; warnings and info are advisory. Shellcheck errors in the hook scripts (`dangerous-commands.sh`) are security-relevant — that script runs before every Bash tool call.

`shellcheck` is pre-installed on `ubuntu-latest` GitHub-hosted runners.

### Job 3: `secret-scan`

```yaml
- uses: gitleaks/gitleaks-action@v2
  env:
    GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}
```

**On push:** scans full git history.  
**On PR:** scans the diff (commits in the PR branch not in base).

Default ruleset covers 150+ secret types including AWS access keys, GitHub PATs, Slack tokens, OpenAI keys, Azure connection strings, and high-entropy strings.

**False positives:** add a `.gitleaks.toml` file to the repo root with an `[[allowlist]]` entry. Example:

```toml
[[allowlist]]
description = "known safe example in docs"
paths = ["docs/superpowers/specs/example.md"]
regexes = ["EXAMPLE_KEY_FOR_DOCS"]
```

No baseline file is committed by default — the default ruleset has low false-positive rates for this repo's content (markdown, shell, JSON).

### Failure Behavior

- Any job failure marks the workflow run red
- Jobs are independent: all three run even if one fails — full picture in one CI run
- Gitleaks annotates the offending line directly in the PR diff
- File-size warn messages are printed to the log; only hard-threshold breaches fail the job

### Branch Protection (manual post-merge step)

After the workflow file is merged to master, configure branch protection:

1. Settings → Branches → Add rule for `master`
2. Require status checks: `file-size`, `forbidden-patterns`, `secret-scan`
3. Require branches to be up to date before merging

This is a one-time manual step — CI cannot configure its own branch protection.

## Files to Create

- `.github/workflows/governance.yml` — the workflow (one file, ~80 lines)
- `.gitleaks.toml` — empty allowlist scaffold (added so future false positives have a clear home)

## Verification

1. Push a file with a literal `password=abc123` — `forbidden-patterns` job fails
2. Push a spec file containing `TBD` — `forbidden-patterns` job fails
3. Push a `.sh` file with an unquoted variable (`rm $FILE` instead of `rm "$FILE"`) — `forbidden-patterns` job fails (shellcheck error)
4. Add a line that trips the memory-bank warn threshold (>80 lines in `templates/memory-bank/projectbrief.md`) — job warns but passes
5. Add a line that trips the memory-bank fail threshold (>150 lines) — job fails
6. Push an AWS access key pattern — `secret-scan` job fails
7. All three jobs pass on a clean push — workflow shows green
