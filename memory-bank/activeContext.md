---
authority: volatile
review-cycle: 7d
retention: archive-after-6m
staleness-threshold: 14d
tags:
  - session/focus
  - session/blockers
  - session/next-steps
last-reviewed: 2026-07-04
compaction_generation: 0
source_type: canonical
confidence: high
lineage: []
---

# Active Context

## Last Updated: 2026-07-04

## Current Focus

**PMB v1.2.0 infrastructure complete.** Doctor suite 35/35 passing; all 9 CI jobs green as of 2026-07-04 (details: progress.md). `/change-review` now includes a Baseline Repo Health spot-check.

## Architecture Constraints to Remember

- `confidence:` is intentionally flat (high/medium/low)
- `source_type` and `compaction_generation` are independent axes — do not conflate
- `authority` (volatility) and startup-criticality are independent axes — do not merge into one field
- Detection-first, resist-automation: auto-remediation premature without semantic certainty
- `mb doctor` = observable integrity signals only; not semantic correctness, not workflow compliance
- `fixtures/` and `docs/` are excluded from pre-push secret scanning (intentionally bad code + docs quoting it)
- `mb status` = state ("can I work?"); `mb doctor`/`/health-check` = validation ("is it correct?")
- Doctor test renames use single subdirectory + conditional restore (not whole-dir rename) to prevent data loss

## Next Steps

1. **Monitor PMB CI** — all 9 jobs green as of 2026-07-04; watch for genuinely new PSScriptAnalyzer lint categories in future `.ps1` changes (Write-Host is now excluded project-wide).
2. **mb plan workflow** — `/feature-dev` Phase 3 now drafts plans to `.claude/plans/` and promotes via `mb plan promote`. Ensure new projects use this workflow.
3. **NPM_TOKEN renewal** (ACR) — expires 2026-09-08. Create new Automation token on npmjs.com and update ACR GitHub secret before this date.

## Git State

main branch. All changes committed and pushed. System is clean.
