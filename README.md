# Personal Memory Bank

![Version](https://img.shields.io/badge/version-1.0.3-blue)  ![License](https://img.shields.io/badge/license-MIT-green)

Persistent project memory for AI coding assistants (Claude Code, Cursor). Five structured files your AI reads at session start. Includes the `mb` CLI (10+ commands), a `/test-audit` coverage suite, 5-agent `/code-review`, `/security-review`, and governed automation hooks.

## The Problem It Solves

Every AI coding session starts blank. You re-explain your stack, re-describe your patterns, re-establish constraints. That overhead compounds across weeks and months.

Memory Bank solves this by keeping a small set of structured files in your project that your AI reads automatically at the start of every session.

## Features at a Glance

| Area | What you get |
|------|-------------|
| Memory system | 5-file structured context, authority hierarchy, freshness tracking, provenance frontmatter |
| `mb` CLI | init, status, validate, audit, query, compact, budget, upgrade, doctor, commit, install-hooks (15 commands) |
| Slash commands | `/test-audit`, `/code-review`, `/security-review`, `/feature-dev`, `/health-check` |
| Governance | Pre/PostToolUse hooks, CI pipeline, task contracts, subagents |

## Install (Windows)

**1. Clone this repo**
```
git clone https://github.com/unyieldingclaw-dev/personal-memory-bank
cd personal-memory-bank
```

**2. Run the installer**
```
install.bat
```
Double-click it in Explorer, or run it from a terminal. Opens a new terminal automatically when done.

**3. In any project, run:**
```
mb init
```

That's it. Start a Claude Code or Cursor session — your AI will have context immediately.

---

**Mac / Linux:**
```bash
chmod +x install.sh && ./install.sh
```
Then in any project: `mb init`

---

## First Session

After `mb init`, open the two files that matter most:

```
memory-bank/projectbrief.md   ← what does this project do? (2-3 paragraphs)
memory-bank/techContext.md    ← what is your stack?
```

Fill those in. Everything else (systemPatterns, activeContext, progress) fills in naturally as you work.

Then run:
```
mb status
```

to confirm the memory bank is healthy before you start.

## Day-to-Day Commands

```
mb status     Check file sizes and health
mb validate   Verify required files and frontmatter are present
mb audit      See freshness — flag stale or overdue files
mb update     Get a prompt to update memory bank after a session
mb commit     Commit memory bank changes separately from feature code
mb query TAG  Find all memory tagged with TAG (e.g. mb query auth)
mb budget     Check token overhead of CLAUDE.md + memory-bank/
mb upgrade    Pull latest templates and standards from the memory bank repo; creates missing standards/ files; checks remote for newer PMB version
mb install-hooks  Retrofit existing projects with the pre-push git hook (for projects initialized before 1.0.3)
mb doctor     Full diagnostic — git, templates, hooks, file sizes, standards presence, version tracking, startup token cost
mb help       Full command list
```

## Slash Commands

Four commands are distributed to every new project via `mb init`. One additional command (`/health-check`) is installed in the PMB repo itself for self-diagnostics.

### Testing Suite

Two complementary tools that together cover the full test quality picture:

**`/test-audit`** — *Coverage gap diagnostic.* Scans changed files (or full project with `--all`), auto-detects your framework (Jest, Vitest, pytest, Go, RSpec, Rust), maps each source file to its expected test file, and flags:

- Missing test files `[HIGH]`
- Test files with no assertions `[MEDIUM]`
- CI configurations missing a test step `[MEDIUM]`
- Missing framework config `[LOW]`

**`/code-review`** — *5-agent orchestrated review.* Spawns three isolated review subagents (Security, Performance, Style & Standards) with uncorrelated context windows so findings don't bias each other. A fourth **Opponent subagent** then audits all findings — challenging false positives, downgrading over-called severities, and surfacing anything the first three missed. Finally, the main agent runs a **test coverage pass** that evaluates missing tests, edge cases, and generates stubs for uncovered public functions.

Together: `/test-audit` tells you *what's missing*. `/code-review` tells you *whether what exists is good*.

### All Commands

| Command | What it does |
|---------|-------------|
| `/test-audit` | Coverage gap diagnostic — framework detection, source-to-test mapping, CI check |
| `/code-review` | 5-agent orchestrated review — security, performance, style, and test coverage |
| `/security-review` | Scans current diff for 9 security patterns (secrets, injection, auth, crypto, etc.) |
| `/feature-dev` | Runs the full 7-phase feature development workflow (brainstorm → spec → plan → implement → review → commit) |
| `/health-check` | PMB-only: runs `mb doctor` + `mb validate` + `mb audit` and prints a labeled summary |

## How It Works

The memory bank is five markdown files in `memory-bank/`:

| File | What it holds | Changes how often |
|------|--------------|------------------|
| `projectbrief.md` | What the project does and must never do | Rarely |
| `systemPatterns.md` | Architecture decisions and code patterns | When patterns change |
| `techContext.md` | Stack, dependencies, environment | When stack changes |
| `activeContext.md` | What you're working on right now | Every session |
| `progress.md` | What's done, in progress, and planned | After completing work |

Your AI reads all five at the start of every session. You update them when things change. The `mb` utility helps you manage them.

<details>
<summary>Governance model</summary>

Memory Bank is built on **governed assistance** — the idea that AI is most useful when it operates within explicit, layered constraints rather than as an autonomous agent. The system enforces this at four levels:

| Layer | Type | Responsibility |
|-------|------|----------------|
| `CLAUDE.md` | Advisory | Behavioral norms, workflow patterns, code style |
| Hooks | Deterministic structural | Per-command enforcement — blocks/confirms/warns on dangerous ops |
| Reviewer / Opponent | Semantic | Scope drift, spec compliance, code quality checks |
| CI | Deterministic gates | Codebase-wide invariants (file size, forbidden patterns, secrets) |

See [`docs/HOOKS-GUIDE.md`](docs/HOOKS-GUIDE.md) for the full enforcement layer architecture.

</details>

## Advanced Features

These exist when you need them — you don't need to understand them to get started.

<details>
<summary>Authority hierarchy and conflict resolution</summary>

Files have explicit authority levels. When instructions conflict, higher authority wins:

`projectbrief.md` (immutable) → `systemPatterns / techContext` (stable) → `activeContext` (volatile) → `progress` (accumulating)

Your AI is instructed to surface conflicts rather than silently reconcile them.

</details>

<details>
<summary>Freshness tracking and eviction</summary>

Each memory bank file has frontmatter with `staleness-threshold` and `review-cycle`. The PostToolUse hook auto-updates `last-reviewed` whenever you edit a file.

Run `mb audit` to see which files are stale. Run `mb compact` to get an AI prompt that deduplicates and summarizes memory across all files.

`mb doctor` includes a staleness summary — it shows stale file counts by authority tier without running a full audit.

</details>

<details>
<summary>Provenance frontmatter</summary>

Each memory bank file carries `compaction_generation`, `source_type`, `confidence`, and `lineage` fields in its frontmatter. `mb doctor` Check #8 warns when compaction depth reaches gen ≥ 2 and errors when no canonical-source file exists. This lets you tell the difference between a file written by a human and one that has been summarized multiple times by an AI.

</details>

<details>
<summary>Startup context visibility</summary>

`mb doctor` prints a Startup Context section at the end of every run:

```
  Startup Context
  Files loaded:      6
  Estimated tokens:  ~4500
  Largest contributors:
    CLAUDE.md                             ~2500 tokens
    memory-bank/systemPatterns.md         ~780 tokens
    memory-bank/techContext.md            ~420 tokens
  30-day growth:     +8% [OK]
  Stale but loaded:  none [OK]
```

This shows you exactly what token overhead your AI carries at session start, which files are driving it, and whether the context is expanding over time. Use it to decide when files need trimming — before the size becomes a problem.

</details>

<details>
<summary>Tag-based retrieval</summary>

Files use hierarchical tags (`auth/session`, `infra/postgres`) in their frontmatter. Run `mb query auth` to find all memory bank content related to auth — by tag or section header.

</details>

<details>
<summary>Worktree support</summary>

Memory bank lives in the main worktree only. `mb commit` detects and refuses mutations from git subworktrees, preventing split-brain memory.

</details>

<details>
<summary>CI / governance pipeline</summary>

A `pmb-health` CI job runs on every PR: secret scanning (gitleaks), template integrity check (hooks match templates), memory bank file size limits, and CLAUDE.md drift detection. The same checks `mb doctor` runs locally are enforced in CI so drift is caught before merge.

</details>

<details>
<summary>Context handoff protocol</summary>

When Claude Code approaches its context limit, type `Handoff`. The AI creates `handoff.md` with a full summary of in-progress work. Start a new session — the AI reads `handoff.md`, merges it into memory bank, and continues from exactly where you left off.

</details>

<details>
<summary>Standards distribution and version tracking</summary>

`mb init` copies 12 governance standards files (`standards/`) into every new project so slash commands can reference them at runtime. `mb upgrade` checks for missing standards files and creates them; if a file has been customized it shows an advisory diff instead of overwriting.

Each project gets a `.pmb-version` file recording which PMB version initialized or last upgraded it. `mb upgrade` checks the remote for a newer version and warns if one is available (non-blocking — works offline).

`mb doctor` checks 11 and 12 warn on missing required standards files and version drift.

</details>

<details>
<summary>Pre-push git hook (optional)</summary>

`scripts/pre-push-check.ps1` (Windows/pwsh) and `scripts/pre-push-check.sh` (POSIX/bash) are optional git hooks that run before every `git push`. They block on errors and warn on advisory issues:

- Unresolved merge conflicts or conflict markers in staged files
- Uncommitted changes in the working tree
- Missing `.gitattributes`
- Possible secrets in the push diff (AWS keys, API tokens, GitHub PATs)
- Files over 500 KB
- `mb validate` result (if `mb` is in PATH)

To install, copy or symlink the appropriate script into your `.git/hooks/` directory:

```bash
# Linux / macOS
cp scripts/pre-push-check.sh .git/hooks/pre-push
chmod +x .git/hooks/pre-push

# Windows (PowerShell wrapper)
Copy-Item scripts\pre-push-check.ps1 .git\hooks\pre-push.ps1
'#!/bin/sh' + "`npwsh -NonInteractive -File .git/hooks/pre-push.ps1`" | Set-Content .git\hooks\pre-push
```

The hooks fail open — if they error unexpectedly, the push is allowed through.

</details>

## Troubleshooting

**`mb init` says templates not found**
Run `install.bat` again from the memory-bank repo directory.

**AI isn't reading the memory bank**
Check that `CLAUDE.md` is in your project root. For Cursor, verify `.cursor/rules/memory-bank.mdc` exists. Restart the IDE.

**Memory bank is getting large**
Run `mb status` to see which file is over its target. Run `mb compact` to get an AI prompt that rewrites and deduplicates memory.

**Something looks corrupted**
Run `mb doctor` for a full diagnostic.

## License

MIT
