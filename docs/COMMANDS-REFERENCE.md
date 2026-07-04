# Commands Reference

Complete reference for all commands in the Personal Memory Bank system.

---

## `mb` CLI Commands

Run from any project directory where `mb init` has been run. On Windows: `mb <command>`. On Mac/Linux: `mb <command>`.

| Command | What It Does | Output / Side Effect |
|---------|--------------|----------------------|
| `mb init` | Scaffold memory-bank/ in the current project | Creates 5 memory-bank files, `CLAUDE.md`, `.claude/settings.json`, hook scripts, slash commands, and `standards/` files. Writes `.pmb-version`. Skips files that already exist. |
| `mb status` | Quick state check | 5 signals: Initialized, Core Memory Present, Active Context Current, Standards Available, Tasks Present. Green ✓ per signal; ⚠ items surface in an Attention section with remediation hint. |
| `mb doctor` | Full 25-point diagnostic + startup context | See [mb doctor Checks](#mb-doctor-checks) below. Absorbs `validate`, `audit`, and `budget` checks. Writes `.pmb-checksums` on each run. |
| `mb query <TAG>` | Search memory-bank by tag or section header | Lists files with matching tags or `##` headings. Supports partial hierarchical match (`mb query auth` matches `auth/session`). |
| `mb clean` | Memory bank maintenance | Slim check for `activeContext.md`; prints guided cleanup prompt (archive + compact + update). Absorbs `compact`, `update`, `archive`, `slim`. |
| `mb commit` | Stage and commit memory-bank/ changes | Runs `git add memory-bank/` + `git commit`; checks for subworktree and refuses if detected. |
| `mb upgrade` / `mb update` | Propagate latest governance templates | Overwrites template-owned files (hook scripts, slash commands, `.claude/settings.json`, Cursor rules); shows advisory diff for `CLAUDE.md`; creates missing `standards/` files; installs pre-push hook; writes `.pmb-version`; soft remote version check. Run `mb upgrade --dry-run` to preview. Absorbs `install-hooks`. (`mb update` is an alias — both run the same upgrade logic.) |
| `mb verify-integrity` | Check and refresh file checksums | Compares current SHA-256 hashes of memory-bank/ files against `.pmb-checksums`. Reports any external modifications as WARN. Always refreshes checksums. |
| `mb help` | Show command list | Prints all primary commands with one-line descriptions and examples. |

**Deprecated commands** (still work as redirects, not shown in `mb help`):

| Deprecated | Routes to |
|-----------|-----------|
| `mb validate` | `mb doctor` |
| `mb audit` | `mb doctor` |
| `mb budget` | `mb doctor` |
| `mb compact` / `mb archive` / `mb slim` | `mb clean` |
| `mb install-hooks` | `mb upgrade` |

---

## Slash Commands (Claude Code)

Installed in `.claude/commands/` and invoked with `/command-name` in Claude Code. Five commands are distributed to every project via `mb init`; one is PMB-only.

### `/code-review`

Multi-agent deep code review.

| Step | What Runs |
|------|-----------|
| 1 | Load review contract from `standards/CODE-REVIEW.md` |
| 2 | Determine scope (git diff or explicit path) |
| 3 | Gather context (`git log` per file); determine which conditional domains apply |
| 4 | Five required domain subagents — **Security · Correctness · Maintainability · Testing · Architecture Drift** — each in an isolated context. Conditional subagents added when applicable: **Performance** (tight loops, DB queries, I/O paths) and **Accessibility** (HTML/JSX/TSX/Vue/Svelte files) |
| 5 | Opposition review subagent: must explicitly answer four questions — overstated Critical/High findings, gaps not reviewed, false positives, cross-domain risks. A general "none apply" answer is a failure. |
| 6 | Report assembled with two finding sections: **Supported Findings** (VERIFIED + INFERRED) and **Predicted Risks** (SPECULATIVE only; omitted if empty). Finding schema uses `Basis: VERIFIED \| INFERRED \| SPECULATIVE` (replaced `Confidence`). No test stubs generated — remediation requires explicit user request. |

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

### `/pmb-status`

Fast state check — the `git status` equivalent for PMB. Runs `mb status` and presents the result. Use at session start, after pulling changes, or before beginning work.

Answers "can I work?" with 5 signals: Initialized, Core Memory Present, Active Context Current, Standards Available, Tasks Present. Attention items include a one-line remediation hint. No deep validation — that belongs in `/health-check`.

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

`mb doctor` runs 25 deterministic health checks and prints a startup context observability section. On every run it writes `.pmb-checksums` to establish or refresh the integrity baseline.

| # | Check | Pass Condition | What to Do on Failure |
|---|-------|---------------|----------------------|
| 0 | Version | `VERSION` file is readable | Check MB_HOME; re-run installer |
| 1 | Git repo | Running inside a git working tree | `git init` if missing; `mb commit` won't work without it |
| 2 | Templates | `$MB_HOME/templates/` is reachable | Re-run `install.bat` / `install.sh` from the PMB repo |
| 3 | Required files | All 5 `memory-bank/` files + `CLAUDE.md` present | Run `mb init` |
| 4 | Hooks | `PostToolUse` hook in `.claude/settings.json`; hook scripts exist on disk | Run `mb init` or copy from `templates/.claude/settings.json` |
| 5 | CLAUDE.md drift | `CLAUDE_AUTOCOMPACT_PCT_OVERRIDE` present in `CLAUDE.md` | Run `mb init` or copy Token Budget section from global `~/.claude/CLAUDE.md` |
| 6 | File sizes | No `memory-bank/` file exceeds its Max line limit | Run `mb clean` |
| 7 | Handoff | No `handoff.md` in project root | Merge `handoff.md` into memory-bank and delete it |
| 8 | Compaction integrity | No file at `compaction_generation` ≥ 2; all `lineage:` ancestors exist on disk | Run `mb clean` (compaction prompt) to regenerate from canonical sources |
| 9 | Staleness summary | No `memory-bank/` files past their `staleness-threshold` | Update stale files; run `mb doctor` for full freshness audit |
| 10 | Placeholder residue | No `TODO`/`TBD`/`FIXME`/`FILL IN`/`[your ...`/`lorem ipsum`/`YYYY-MM-DD` in memory-bank files | Fill in placeholder content left from `mb init` |
| 11 | Required standards files | `standards/CODE-REVIEW.md`, `WORKFLOW.md`, `SECURITY-GUARDRAILS.md`, `CODE-QUALITY.md` all present | Run `mb upgrade` to install missing files |
| 12 | PMB version tracking | `.pmb-version` exists and matches local PMB version | Run `mb upgrade` to write or sync `.pmb-version` |
| 13 | Security fixtures | `fixtures/security/` exists with all 9 rule subdirectories | Create fixtures manually or re-clone PMB repo |
| 14 | Standards count | `standards/` contains ≤ 20 `.md` files | Review standards for overlap; see `PERFORMANCE-BUDGET.md` |
| 15 | Startup context ceiling | `CLAUDE.md` + `memory-bank/` total ≤ 25 KB (WARN >15 KB, ERROR >25 KB) | Slim `CLAUDE.md` or archive old `progress.md` entries |
| 16 | Hook error log | `.pmb-hook-errors.log` absent or empty | Review log for root cause; delete file when resolved |
| 17 | Semantic drift signals | No transition/removal language in volatile files (`activeContext.md`, `progress.md`) that may contradict stable files | Review flagged lines against `systemPatterns.md`/`projectbrief.md`; update stable files if decisions changed |
| 18 | Old stable decisions | All `authority:stable` files reviewed within 180 days | Review decisions and update `last-reviewed` date, or revise if drifted |
| 19 | Cross-file contradictions | No `authority:` mismatches from expected hierarchy; no negation language under shared `##` headings | Resolve authority conflicts; clarify intentional transitions vs. real contradictions |
| 20 | Integrity checksums | All memory-bank file SHA-256 hashes match `.pmb-checksums` baseline | Review external edits; checksums refresh automatically on each `mb doctor` run |
| 21 | Git-vs-reviewed lag | `last-reviewed` frontmatter date is not before the file's last git commit date | Update `last-reviewed` frontmatter or confirm no review is needed |
| 22 | Completed-but-still-planned | No item marked ✅ complete in `progress.md` still appears as ⏸ planned/pending elsewhere | Resolve the stale planned-item drift before the next compaction |
| 23 | Stale Next Steps | No `activeContext.md` Next Steps item already appears completed in `progress.md` | Remove it from Next Steps or verify the `progress.md` entry |
| 24 | Plan hygiene | `docs/plans/` exists; no tracked scratch plans in `.claude/plans/`; all plans have frontmatter; no plan stale 30+ days | Run `mb plan status` for setup; `git rm --cached` tracked scratch plans; add frontmatter; review stale plans |
| 25 | Agent frontmatter | `.claude/agents/*.md` declare a `name:` field matching the filename (WARN-tier) | Add a `name:` field matching the filename to the agent's frontmatter |
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

When a file exceeds its Max: run `mb clean` to get an AI-guided cleanup prompt.
