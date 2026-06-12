---
authority: volatile
review-cycle: 7d
retention: archive-after-6m
staleness-threshold: 14d
tags:
  - session/focus
  - session/blockers
  - session/next-steps
last-reviewed: 2026-06-12
compaction_generation: 0
source_type: canonical
confidence: high
lineage: []
---

# Active Context

## Current Focus

v1.1.0 shipped and all 9 key docs audited (2026-06-12). Startup context was at 29.3 KB (above 25 KB ERROR threshold) — memory bank maintenance pass in progress to bring it below threshold. After `mb clean` cleanup: run `mb verify-integrity`, `mb doctor`, then `mb commit`.

## What Was Just Completed (2026-06-12)

**Documentation Audit + Memory Maintenance:**
- All 9 key docs audited; fixed 4 `mb compact`→`mb clean` references + 2 "75%"→"40%" references in RECOVERY.md; committed + pushed
- GitHub repo description updated to reflect v1.1.0 (versioned git hooks, slash commands suite)
- Memory bank maintenance pass: compressed 7 verbose sections in progress.md, added docs audit entry

## Next Steps

1. **Architecture review items on hold** — boring mode (`mb init --minimal`), explicit non-goals doc, `/core` vs `/integrations` separation; revisit if adoption friction surfaces
2. **Semantic identity** (progress.md backlog) — concept-level drift detection; detection-first, no auto-remediation; not yet, complexity budget is spent

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

master branch. Clean — all session work committed and pushed. Pending: `mb verify-integrity` + `mb doctor` + `mb commit` to close out memory bank maintenance.
