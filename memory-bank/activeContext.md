---
authority: volatile
review-cycle: 7d
retention: archive-after-6m
staleness-threshold: 14d
tags:
  - session/focus
  - session/blockers
  - session/next-steps
last-reviewed: 2026-06-22
compaction_generation: 0
source_type: canonical
confidence: high
lineage: []
---

# Active Context

## Current Focus

PMB Infrastructure complete (2026-06-22). ACR integration track in progress — `/change-review` command added, ACR P0 fixes and schema alignment underway in the ACR repo.

## What Was Just Completed (2026-06-22)

**PMB Infrastructure — plan lifecycle and `/change-review`:**
- Plan: `docs/superpowers/plans/2026-06-20-pmb-infrastructure.md`
- `.claude/plans/` gitignored; `docs/plans/` + `docs/archive/plans/` created with README
- `templates/plan.md` updated with YAML frontmatter (status/created/approved/scope/risk/source)
- `mb plan status|list|promote|archive` added to `mb.sh` and `mb.ps1`
- `mb doctor` check 24 added — plan hygiene (docs/plans/ exists, no tracked drafts, frontmatter present, no stale plans); README.md excluded from frontmatter check
- `standards/WORKFLOW.md` + `/feature-dev` updated: Phase 3 now drafts to `.claude/plans/`, promotes to `docs/plans/`
- `/change-review` command created (`.claude/commands/` + `templates/`) — 9-job change package review with optional ACR bridge

**Earlier this session (2026-06-19):**
- Semantic drift detection: Checks 21–23 in `mb doctor`, `/mb-drift` skill
- `master` → `main` across all 8 repos; GitHub defaults fixed
- `pre-push-check.sh`/`.ps1` CRLF false-positive bug fixed

## Next Steps

1. **ACR P0 fixes** (ACR repo) — testgen opt-in, spawnSync, remove Anthropic provider, MCP version sync, agent count drift, dead config field
2. **ACR schema alignment** — `profiles.ts`, extended `Finding` schema, agent prompt updates, formatter updates
3. **Architecture review items on hold** — boring mode, non-goals doc, /core vs /integrations; revisit if adoption friction surfaces

## Architecture Constraints to Remember

- `confidence:` is intentionally flat (high/medium/low)
- `source_type` and `compaction_generation` are independent axes — do not conflate
- `authority` (volatility) and startup-criticality are independent axes — do not merge into one field
- Detection-first, resist-automation: auto-remediation premature without semantic certainty
- "Overhead proportionate to certainty" — governing principle for any new governance additions
- `mb doctor` = observable integrity signals only; not semantic correctness, not workflow compliance
- `fixtures/` and `docs/` are excluded from pre-push secret scanning (intentionally bad code + docs quoting it)
- `mb status` = state ("can I work?"); `mb doctor`/`/health-check` = validation ("is it correct?")

## Git State

main branch. All changes committed and pushed. System is clean.
