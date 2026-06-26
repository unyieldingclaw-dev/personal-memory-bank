# Personal Memory Bank

![Version](https://img.shields.io/badge/version-1.2.0-blue)  ![License](https://img.shields.io/badge/license-MIT-green)

Persistent project memory for AI coding assistants (Claude Code, Cursor). Five structured files your AI reads at session start. Includes the `mb` CLI (11 commands), a `/test-audit` coverage suite, 5-agent `/code-review`, `/security-review`, and governed automation hooks.

## The Problem It Solves

Every AI coding session starts blank. You re-explain your stack, re-describe your patterns, re-establish constraints. That overhead compounds across weeks and months.

Memory Bank solves this by keeping a small set of structured files in your project that your AI reads automatically at the start of every session.

## Features at a Glance

| Area | What you get |
|------|-------------|
| Memory system | 5-file structured context, authority hierarchy, freshness tracking, provenance frontmatter |
| `mb` CLI | init, status, doctor, query, clean, commit, upgrade, verify-integrity, help (9 primary commands; `mb update` aliases `mb upgrade`) |
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
mb status     Quick state check — initialized, memory, context, standards, tasks
mb doctor     Full 24-point diagnostic — git, templates, hooks, file sizes, version, drift detection, checksums, context ceiling
mb query TAG  Find all memory tagged with TAG (e.g. mb query auth)
mb clean      Memory bank maintenance — slim check + guided cleanup prompt
mb commit     Commit memory bank changes separately from feature code
mb upgrade    Propagate latest governance templates to this project; checks remote for newer PMB version
mb help       Full command list
```

> Deprecated commands (`validate`, `audit`, `budget`, `compact`, `update`, `archive`, `slim`, `install-hooks`) still work as redirects to their absorbing command. They are not shown in `mb help` but will not error.

## Slash Commands

Five commands are distributed to every new project via `mb init`. One additional command (`/health-check`) is installed in the PMB repo itself for self-diagnostics.

### Testing Suite

Two complementary tools that together cover the full test quality picture:

**`/test-audit`** — *Coverage gap diagnostic.* Scans changed files (or full project with `--all`), auto-detects your framework (Jest, Vitest, pytest, Go, RSpec, Rust), maps each source file to its expected test file, and flags:

- Missing test files `[HIGH]`
- Test files with no assertions `[MEDIUM]`
- CI configurations missing a test step `[MEDIUM]`
- Missing framework config `[LOW]`

**`/code-review`** — *6–8 subagent orchestrated review.* Always spawns five isolated domain subagents (Security, Correctness, Maintainability, Testing, Architecture Drift), each seeing only the diff and its own domain lens so findings don't bias each other. Two conditional domains add on when applicable: Performance (if the diff touches tight loops, database queries, or I/O) and Accessibility (if it touches HTML/JSX/TSX/Vue/Svelte). A final **Opposition subagent** receives all domain findings and must explicitly answer four structured questions — overstatements, coverage gaps, false positives, and cross-domain risks; "none apply" is explicitly a failure. The command does not edit files, generate tests, or apply fixes.

Together: `/test-audit` tells you *what's missing*. `/code-review` tells you *whether what exists is good*.

### All Commands

| Command | What it does |
|---------|-------------|
| `/pmb-status` | Quick state check — the `git status` of PMB; run at session start or before beginning work |
| `/test-audit` | Coverage gap diagnostic — framework detection, source-to-test mapping, CI check |
| `/code-review` | 6–8 subagent review — 5 always-on domains (Security, Correctness, Maintainability, Testing, Architecture Drift) + up to 2 conditional (Performance, Accessibility) + Opposition audit |
| `/security-review` | Scans current diff for 9 security patterns (secrets, injection, auth, crypto, etc.) |
| `/feature-dev` | Runs the full 7-phase feature development workflow (brainstorm → spec → plan → implement → review → commit) |
| `/health-check` | PMB-only: runs `mb doctor` (20 checks) and prints a labeled summary |

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

Run `mb doctor` to see which files are stale (check 9 covers staleness). Run `mb clean` to get an AI prompt that deduplicates and summarizes memory across all files.

`mb doctor` includes a staleness summary, startup context size ceiling (WARN >15 KB, ERROR >25 KB), semantic drift detection (check 17), and SHA-256 integrity checksums (check 20).

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

The `pmb-health` CI workflow runs on every push and PR with six jobs:

| Job | What it checks |
|-----|---------------|
| `file-size` | memory-bank/ per-file line limits; all other .md files (warn: 500, fail: 800) |
| `forbidden-patterns` | credential grep; spec placeholder markers; shellcheck on .sh scripts |
| `secret-scan` | gitleaks on the full commit history |
| `template-integrity` | every hook script referenced in `templates/.claude/settings.json` exists in `templates/scripts/` |
| `rules-file-integrity` | invisible Unicode chars, hidden HTML comments, LLM bypass phrases in `CLAUDE.md` and `standards/` |
| `sast` | Semgrep `p/bash` scan of `scripts/` and `templates/scripts/` |

The same checks `mb doctor` runs locally are enforced in CI so drift is caught before merge.

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
<summary>Git hooks (pre-push and pre-commit)</summary>

PMB installs two git hooks automatically — no manual copying needed.

**`mb init`** creates `.githooks/pre-push` and `.githooks/pre-commit` in the project and sets `core.hooksPath = .githooks` (a local git config, not committed), so git resolves hooks from the versioned `.githooks/` directory. **`mb upgrade`** keeps them current (both hooks are `TEMPLATE_OWNED` — overwritten if stale).

**`.githooks/pre-push`** — runs before every `git push`, blocks on errors:

- Unresolved merge conflicts or conflict markers in staged files
- Uncommitted changes in the working tree
- Missing `.gitattributes`
- Possible secrets in the push diff (AWS keys, API tokens, GitHub PATs) — scans first pushes via `git log --not --remotes` when no upstream tracking ref exists
- Files over 500 KB
- `mb validate` result (if `mb` is in PATH)

Fails open — if the script errors unexpectedly, the push is allowed through.

**`.githooks/pre-commit`** — runs before every `git commit`:

- **Blocks** if `handoff.md` is staged (`handoff.md` is ephemeral and must not be committed)
- **Warns** if `CLAUDE_AUTOCOMPACT_PCT_OVERRIDE` is missing from `.claude/settings.json`

Projects initialized before PMB 1.1.0 have the old shim at `.git/hooks/pre-push`. `mb upgrade` migrates them automatically: installs `.githooks/` hooks, sets `core.hooksPath`, and removes the old shim.

See `docs/HOOKS-GUIDE.md` for the full reference.

</details>

## Troubleshooting

**`mb init` says templates not found**
Run `install.bat` again from the memory-bank repo directory.

**AI isn't reading the memory bank**
Check that `CLAUDE.md` is in your project root. For Cursor, verify `.cursor/rules/memory-bank.mdc` exists. Restart the IDE.

**Memory bank is getting large**
Run `mb doctor` to see which file is over its target. Run `mb clean` to get an AI prompt that rewrites and deduplicates memory.

**Something looks corrupted**
Run `mb doctor` for a full diagnostic.

## License

MIT
