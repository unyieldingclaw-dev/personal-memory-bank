# Commands Reference

Complete reference for all commands in the Personal Memory Bank system.

---

## `mb` CLI Commands

Run from any project directory where `mb init` has been run. On Windows: `mb <command>`. On Mac/Linux: `mb <command>`.

| Command | What It Does | Output / Side Effect |
|---------|--------------|----------------------|
| `mb init` | Scaffold memory-bank/ in the current project | Creates 5 memory-bank files, `CLAUDE.md`, `.claude/settings.json`, hook scripts, and slash commands. Skips files that already exist. |
| `mb status` | Show file sizes vs. limits | Table: lines vs. target/max per file. Red = over limit, yellow = consider trimming, green = OK. |
| `mb validate` | Check required files and frontmatter | Pass/fail for each file; flags missing `authority:` or `last-reviewed:` fields. |
| `mb audit` | Freshness audit | Table: days since last review vs. `staleness-threshold`; flags stale (red) and overdue (yellow) files. |
| `mb query <TAG>` | Search memory-bank by tag or section header | Lists files with matching tags or `##` headings. Supports partial hierarchical match (`mb query auth` matches `auth/session`). |
| `mb compact` | Print AI prompt for memory compaction | Copy-paste prompt to give the AI; guides deduplication, contradiction surfacing, and summarization. |
| `mb update` | Print session-end update reminder | Copy-paste prompt to tell the AI to update memory-bank files after a work session. |
| `mb archive` | Print archiving instructions | Instructions for moving stale content from `activeContext.md` to `docs/archive/`. |
| `mb slim` | Check if activeContext.md needs trimming | Reports current/target/max line count; prints the prompt to trim if needed. |
| `mb commit` | Stage and commit memory-bank/ changes | Runs `git add memory-bank/` + `git commit`; checks for subworktree and refuses if detected. |
| `mb upgrade` | Propagate latest governance templates | Overwrites template-owned files (hook scripts, slash commands, `.claude/settings.json`, Cursor rules); shows advisory diff for `CLAUDE.md`. Run `mb upgrade --dry-run` to preview. |
| `mb budget` | Token budget health | Shows KB + estimated tokens for `CLAUDE.md` and `memory-bank/`; reports auto-compact setting. |
| `mb doctor` | Full 10-point diagnostic + startup context | See [mb doctor Checks](#mb-doctor-checks) below. |
| `mb help` | Show command list | Prints all commands with one-line descriptions and examples. |

---

## Slash Commands (Claude Code)

Installed in `.claude/commands/` and invoked with `/command-name` in Claude Code. Four commands are distributed to every project via `mb init`; one is PMB-only.

### `/code-review`

Multi-agent deep code review.

| Step | What Runs |
|------|-----------|
| 1 | Determine scope (git diff or explicit path) |
| 2 | Gather context (git log per file) |
| 3 | Three parallel subagents: Security · Performance · Style — each runs in an isolated context so findings don't bias each other |
| 4 | Test coverage review: maps source files to test files; generates stubs for missing ones |
| 5 | Opponent auditor: confirms high-confidence findings, downgrades false positives |
| 6 | Summary report with auditor verdict column |

**Distributed via `mb init`:** Yes

---

### `/feature-dev`

Full 7-phase feature development workflow.

```
Brainstorm → Spec → Plan → Implement (TDD) → Simplify → Security Review → Commit
```

Guides each phase interactively. Skip to Implement for single-file fixes, typos, or config changes under 20 lines.

**Distributed via `mb init`:** Yes

---

### `/security-review`

Lightweight inline security scan of the current diff.

Scans for 9 patterns: injection (SQL, command, LDAP), XSS, broken auth, insecure deserialization, sensitive data exposure, XXE, broken access control, security misconfiguration, and known-vulnerable components.

No subagents — read-only, fast. Outputs findings by severity with file + line references.

**Distributed via `mb init`:** Yes

---

### `/test-audit`

Audit test coverage for changed files or the full project.

| Step | What It Does |
|------|-------------|
| 1 — Scope | Default: changed files from `git diff HEAD`. Pass `--all` for full project, or a path (e.g. `src/`) for a subtree. |
| 2 — Framework | Auto-detects: Jest, Vitest, Mocha, pytest, Go stdlib, RSpec, Rust stdlib. Falls back to filename conventions. |
| 3 — Mapping | For each source file, checks whether a corresponding test file exists using framework conventions. |
| 4 — Empty check | Greps each test file for at least one test declaration (`def test_`, `it(`, `func Test`, etc.). |
| 5 — Config check | Verifies a framework config file exists (e.g. `jest.config.ts`, `pytest.ini`). |
| 6 — CI check | Globs `.github/workflows/*.yml` and similar; checks for a test invocation step. |

**Severity model:**

| Severity | Condition |
|----------|-----------|
| `[HIGH]` | Source file has no corresponding test file |
| `[MEDIUM]` | Test file exists but contains no test functions |
| `[MEDIUM]` | CI config exists but invokes no test command |
| `[LOW]` | No test framework detected |
| `[LOW]` | Framework detected but no config file found |
| `[LOW]` | No CI configuration in project |

**Distributed via `mb init`:** Yes

---

### `/health-check`

Full PMB health check. Runs `mb doctor` + `mb validate` + `mb audit` and `git status`/`git log`, then prints a labeled summary with overall status (✅ / ⚠️ / ❌).

**Distributed via `mb init`:** No — PMB repo only (self-diagnostic for maintaining the memory bank system itself)

---

## Claude Code Built-in Commands

These are built into Claude Code and don't require the memory bank system.

| Command | What It Does |
|---------|--------------|
| `Handoff` (keyword, not a slash command) | AI creates `handoff.md` summarizing in-progress work; use when context reaches ~40%. Start a new session — the AI reads `handoff.md` and continues from where you left off. |
| `/compact <hint>` | Compacts the conversation context. Use at natural task boundaries (`/compact Focus on decisions and file paths`). |
| `/clear` | Clears conversation context entirely. Use when switching to unrelated work. |
| `/model opus` | Switch to Claude Opus for complex architecture decisions or large cross-file refactors. |
| `/model sonnet` | Switch back to Claude Sonnet (the default for most tasks). |
| `/cost` | Show current session quota usage. |
| `/usage` | Show token breakdown for current session. |
| `/fast` | Toggle fast mode (Opus with faster output). |

---

## `mb doctor` Checks

`mb doctor` runs 10 deterministic health checks and prints a startup context observability section.

| # | Check | Pass Condition | What to Do on Failure |
|---|-------|---------------|----------------------|
| 0 | Version | `VERSION` file is readable | Check MB_HOME; re-run installer |
| 1 | Git repo | Running inside a git working tree | `git init` if missing; `mb commit` won't work without it |
| 2 | Templates | `$MB_HOME/templates/` is reachable | Re-run `install.bat` / `install.sh` from the PMB repo |
| 3 | Required files | All 5 `memory-bank/` files + `CLAUDE.md` present | Run `mb init` |
| 4 | Hooks | `PostToolUse` hook in `.claude/settings.json`; hook scripts exist on disk | Run `mb init` or copy from `templates/.claude/settings.json` |
| 5 | CLAUDE.md drift | `CLAUDE_AUTOCOMPACT_PCT_OVERRIDE` present in `CLAUDE.md` | Run `mb init` or copy Token Budget section from global `~/.claude/CLAUDE.md` |
| 6 | File sizes | No `memory-bank/` file exceeds its Max line limit | Run `mb slim` or `mb archive` |
| 7 | Handoff | No `handoff.md` in project root | Merge `handoff.md` into memory-bank and delete it |
| 8 | Compaction integrity | No file at `compaction_generation` ≥ 2; all `lineage:` ancestors exist on disk | Run `mb compact` to regenerate from canonical sources |
| 9 | Staleness summary | No `memory-bank/` files past their `staleness-threshold` | Run `mb audit` for details; update stale files |
| 10 | Placeholder residue | No `TODO`/`TBD`/`FIXME`/`FILL IN`/`[your ...`/`lorem ipsum`/`YYYY-MM-DD` in memory-bank files | Fill in placeholder content left from `mb init` |
| — | Startup context | (observability, not a health check) — reports files loaded, estimated tokens, largest contributors, 30-day growth, stale-but-loaded count | Use to decide when files need trimming |

---

## File Size Limits

| File | Target Lines | Max Lines | Authority |
|------|-------------|-----------|-----------|
| `projectbrief.md` | 50–80 | 150 | immutable |
| `systemPatterns.md` | 100–180 | 300 | stable |
| `techContext.md` | 150–250 | 400 | stable |
| `activeContext.md` | 50–100 | 150 | volatile |
| `progress.md` | 100–250 | 400 | accumulating |

When a file exceeds its Max: run `mb slim` (for `activeContext.md`) or `mb archive` / `mb compact` (for others).
