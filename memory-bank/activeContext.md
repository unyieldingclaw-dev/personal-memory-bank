---
authority: volatile
review-cycle: 7d
retention: archive-after-6m
staleness-threshold: 14d
tags:
  - session/focus
  - session/blockers
  - session/next-steps
last-reviewed: 2026-05-28
compaction_generation: 0
source_type: canonical
confidence: high
lineage: []
---

# Active Context

## Current Focus

Architecture review cycle complete (2026-05-25). All planned workstreams merged. Repo is stable. Next decision point is observation-driven: wait for 30-day startup context growth data before making classification or loader decisions.

## What Was Just Completed (2026-05-29)

**`mb install-hooks` subcommand shipped:**
- `scripts/mb.ps1` — new `install-hooks` command; targeted retrofit for projects that already ran `mb init` before the pre-push hook was added
- Copies `scripts/pre-push-check.ps1` + `.sh` from templates if missing; installs `.git/hooks/pre-push`; reports `[+]`/`[=]` per item; supports `--dry-run`
- Distinct from `mb init` (which uses Copy-IfNew and skips existing files)

**Pre-push hook shipped (2026-05-28/29):**
- `scripts/pre-push-check.ps1` + `.sh` — 7 checks: merge conflicts, conflict markers, dirty tree (warn), missing .gitattributes (warn), secrets scan (blocks on AWS/API/PAT patterns), large files >500 KB (warn), `mb validate` (warn)
- `templates/scripts/pre-push-check.ps1` + `.sh` — distributed via `mb init`
- `templates/hooks/pre-push` — bash shim detecting pwsh/powershell/bash at runtime; cross-platform
- `mb init` — wired to install `.git/hooks/pre-push` and copy pre-push scripts
- `mb upgrade` — pre-push scripts added to TEMPLATE_OWNED list
- `mb doctor` — Check #11: `.git/hooks/pre-push` presence
- `README.md` — "Pre-push git hook (optional)" collapsible section in Advanced Features

## What Was Completed (2026-05-28)

**PreCompact memory gate shipped:**
- `scripts/pre-compact-check.ps1` + `.sh` — fires before compaction; warns if neither memory bank nor handoff captured today; always exits 0
- `templates/scripts/pre-compact-check.ps1` + `.sh` — distributed via `mb init`
- `.claude/settings.json` — `PreCompact` hook wired; `CLAUDE_AUTOCOMPACT_PCT_OVERRIDE` lowered 50 → 40
- `templates/.claude/settings.json` — same changes for new-project distribution
- `CLAUDE.md` + `templates/CLAUDE.md` — threshold references updated 50% → 40%; PreCompact hook mentioned
- `docs/HOOKS-GUIDE.md` — "### 4. PreCompact Memory Gate" section added

**`/test-audit` command shipped + v1.0.2 documentation pass (2026-05-27):**
- Design spec written: `docs/superpowers/specs/2026-05-27-test-audit-design.md`
- `templates/claude-commands/test-audit.md` — canonical template distributed via `mb init`
- `.claude/commands/test-audit.md` — installed copy for PMB dogfooding
- `.claude/commands/health-check.md` — PMB-only full health check (mb doctor + mb validate + mb audit)
- Inline diagnostic command (no subagents, read-only), matches `security-review` lightweight pattern
- 6-step scan: scope → framework detection → source-to-test mapping → empty-file check → config check → CI check
- Severity model: [HIGH] missing tests, [MEDIUM] empty test file / CI no test step, [LOW] no framework / no config / no CI
- v1.0.2: README badge corrected, CHANGELOG entry, COMMANDS-REFERENCE.md created, mb upgrade now includes test-audit.md

**Consistency corrections & v1.0.1 release:**
- `6a8f320` — four documentation/config fixes: Stop hook docs, contract threshold (1→4 files), compaction language, governance→pmb-health rename
- `7eba98b` — mb doctor Check #10 (placeholder residue, lexical/deterministic) + CHANGELOG v1.0.1 entry
- `8d24a99` — mb doctor identity boundary comment in function header
- v1.0.1 tagged and published as first formal GitHub release
- Deferred: handoff CLI, pinned.md, mb update --from-git, mb privacy — pending operational evidence

**Architecture review response (2026-05-25, 4 commits on master):**
- `a62cc7b` — `.claude/worktrees/` added to `.gitignore` (accidental operational artifacts concern from review)
- PR #2 (`feat/comment-provenance`) — CODE-QUALITY.md sections 2+7, CLAUDE.md 3-line provenance anchor, Cursor rule anchor
- PR #3 (`feat/governance-integrity`) — hook scripts in templates, mb doctor Check #4 (hook presence), CI template-integrity job
- PR #4 (`feat/mb-upgrade`) — `mb upgrade` subcommand
- `a498d85` — CLAUDE.md memory update discipline: task-boundary updates, compaction summaries are fallback not primary
- `fa03b70` — `mb doctor` Startup Context observability section (files loaded, estimated tokens, top-3 contributors, 30-day growth, stale-but-loaded)

**Key architectural decisions from review:**
- Portability concern (#2) deferred: valid long-term, not actionable now without evidence
- Token budget: "observable expansion" not "enforced ceilings" — visibility first
- Identity: "governed AI operating model" confirmed, not a generic memory utility
- Contracts: empirical — observe friction before simplifying
- Sequence confirmed: (1) visibility ✅, (2) classification when data supports it, (3) loader gate only if justified

## Next Steps

1. **Wait for 30-day growth data** (~June 4) — startup context section will show real growth % once repo crosses 30-day window; use that data to decide whether classification is needed
2. **Architecture review items on hold** — boring mode (`mb init --minimal`), explicit non-goals doc, `/core` vs `/integrations` separation; none are urgent, revisit if adoption friction surfaces
3. **Semantic identity** (progress.md "Next Major Gap") — concept-level drift detection; detection-first, no auto-remediation; not yet, complexity budget is spent

## Architecture Constraints to Remember

- `confidence:` is intentionally flat (high/medium/low)
- `source_type` and `compaction_generation` are independent axes — do not conflate
- `authority` (volatility) and startup-criticality are independent axes — do not merge into one field
- Detection-first, resist-automation: auto-remediation premature without semantic certainty
- "Overhead proportionate to certainty" — governing principle for any new governance additions
- `mb doctor` = observable integrity signals only; not semantic correctness, not workflow compliance

## Git State

master branch, clean. Last commit: `cb0ca02` — mb install-hooks subcommand.
