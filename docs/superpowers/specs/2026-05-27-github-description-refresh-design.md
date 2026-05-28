# GitHub Description Refresh — Design

## Context

Personal Memory Bank v1.0.2 has shipped several major capabilities since the repository was first
published: the `mb` CLI (10+ commands), four slash commands distributed via `mb init`, the
`/test-audit` coverage diagnostic, a 5-agent `/code-review` orchestration, and a full governance
layer (hooks, CI, task contracts). None of these appear in the current GitHub About description,
and the README intro doesn't surface the testing suite or agent architecture at all.

This spec defines copy for four GitHub surfaces: the About description (one-liner), repository
topics, the README tagline, and a full README rewrite that promotes the testing suite and
slash commands to first-class visibility.

**Audience:** general developer audience — people who code, with or without prior AI tool
experience.
**Tone:** pragmatic / technical. Let capabilities sell themselves. No hype.
**Approach:** problem-first — lead with the blank-session pain, then show the system that solves it.

---

## Surface 1 — GitHub About Description

One-liner displayed under the repo name on GitHub. 350-char max.

**Final copy:**

> Persistent project memory for AI coding assistants (Claude Code, Cursor). Five structured files
> your AI reads at session start. Includes the `mb` CLI (10+ commands), a `/test-audit` coverage
> suite, 5-agent `/code-review`, `/security-review`, and governed automation hooks.

Character count: ~248. Hits: IDEs, memory system, testing suite, agent count, governance.

---

## Surface 2 — Repository Topics

15 chips. GitHub allows up to 20.

```
claude-code
cursor
memory-bank
ai-tools
developer-tools
productivity
context-management
ai-assistant
claude
testing
code-review
hooks
governance
windows
powershell
```

---

## Surface 3 — README Full Rewrite

### Structure (10 sections)

1. **Header** — Title, version/license badges, one-line tagline (same copy as About description)
2. **The Problem** — "Every AI session starts blank" — existing paragraph, minor tightening
3. **Features at a Glance** — New scannable table near the top (see below)
4. **Install** — Existing Windows + Mac/Linux install steps, unchanged
5. **First Session** — Existing two-file guidance + `mb status`, unchanged
6. **Day-to-Day Commands** — Existing `mb` command table, unchanged
7. **Slash Commands** — *Promoted from buried collapsible to dedicated top-level section* (see below)
8. **Advanced Features** — Existing collapsibles + two new ones (Provenance frontmatter, CI/governance)
9. **Troubleshooting** — Unchanged
10. **License** — Unchanged

---

### Section 3 — Features at a Glance

New table, placed directly after The Problem section:

| Area | What you get |
|---|---|
| Memory system | 5-file structured context, authority hierarchy, freshness tracking, provenance frontmatter |
| `mb` CLI | init, status, validate, audit, query, compact, budget, upgrade, doctor, commit (10 commands) |
| Slash commands | `/test-audit`, `/code-review`, `/security-review`, `/feature-dev`, `/health-check` |
| Governance | Pre/PostToolUse hooks, CI pipeline, task contracts, subagents |

---

### Section 7 — Slash Commands (new top-level section)

Header: `## Slash Commands`

Opening line: "Four commands are distributed to every new project via `mb init`. One additional
command (`/health-check`) is installed in the PMB repo itself for self-diagnostics."

**Testing Suite subsection** (prominently placed first):

---

**Testing Suite** — two complementary tools:

**`/test-audit`** — *Coverage gap diagnostic.* Scans changed files (or full project with `--all`),
auto-detects your framework (Jest, Vitest, pytest, Go, RSpec, Rust), maps each source file to its
expected test file, and flags:
- Missing test files `[HIGH]`
- Test files with no assertions `[MEDIUM]`
- CI configurations missing a test step `[MEDIUM]`
- Missing framework config `[LOW]`

**`/code-review`** — *5-agent orchestrated review.* Spawns three isolated review subagents
(Security, Performance, Style & Standards) with uncorrelated context windows so findings don't
bias each other. A fourth **Opponent subagent** then audits all findings — challenging false
positives, downgrading over-called severities, and surfacing anything the first three missed.
Finally, the main agent runs a **test coverage pass** that evaluates missing tests, edge cases,
and generates stubs for uncovered public functions.

Together: `/test-audit` tells you *what's missing*. `/code-review` tells you *whether what exists is good*.

---

**Remaining commands table:**

| Command | What it does |
|---|---|
| `/security-review` | Scans current diff for 9 security patterns (secrets, injection, auth, crypto, etc.) |
| `/feature-dev` | Runs the full 7-phase feature development workflow (brainstorm → spec → plan → implement → review → commit) |
| `/health-check` | PMB-only: runs `mb doctor` + `mb validate` + `mb audit` and prints a labeled summary |

---

### New Advanced Features collapsibles

**Provenance frontmatter** (new):
> Each memory bank file carries `compaction_generation`, `source_type`, `confidence`, and `lineage`
> fields in its frontmatter. `mb doctor` Check #8 warns when compaction depth reaches gen ≥ 2 and
> errors when no canonical-source file exists. This lets you tell the difference between a file
> written by a human and one that has been summarized multiple times by an AI.

**CI / governance pipeline** (new):
> A `pmb-health` CI job runs on every PR: secret scanning (gitleaks), template integrity check
> (hooks match templates), memory bank file size limits, and CLAUDE.md drift detection. The same
> checks `mb doctor` runs locally are enforced in CI so drift is caught before merge.

---

## Verification

1. Set the About description on GitHub via repo Settings → About. Confirm it renders correctly.
2. Add all 15 topics. Confirm chips appear on repo homepage.
3. Replace README.md content. Review render on GitHub — check table formatting, collapsibles, badges.
4. Confirm `/test-audit` and `/code-review` sections read clearly without prior context.
5. Confirm Features at a Glance table renders in two-column format.
