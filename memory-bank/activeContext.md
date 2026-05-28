---
authority: volatile
review-cycle: 7d
retention: archive-after-6m
staleness-threshold: 14d
tags:
  - session/focus
  - session/blockers
  - session/next-steps
last-reviewed: 2026-05-25
compaction_generation: 0
source_type: canonical
confidence: high
lineage: []
---

# Active Context

## Current Focus

Architecture review cycle complete (2026-05-25). All planned workstreams merged. Repo is stable. Next decision point is observation-driven: wait for 30-day startup context growth data before making classification or loader decisions.

## What Was Just Completed (2026-05-27)

**`/test-audit` command shipped:**
- Design spec written: `docs/superpowers/specs/2026-05-27-test-audit-design.md`
- `templates/claude-commands/test-audit.md` — canonical template distributed via `mb init`
- `.claude/commands/test-audit.md` — installed copy for PMB dogfooding
- Inline diagnostic command (no subagents, read-only), matches `security-review` lightweight pattern
- 6-step scan: scope → framework detection → source-to-test mapping → empty-file check → config check → CI check
- Severity model: [HIGH] missing tests, [MEDIUM] empty test file / CI no test step, [LOW] no framework / no config / no CI

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

master at `8d24a99`, clean working tree, v1.0.1 tagged and pushed
