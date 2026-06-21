---
authority: volatile
review-cycle: 7d
retention: archive-after-6m
staleness-threshold: 14d
tags:
  - session/focus
  - session/blockers
  - session/next-steps
last-reviewed: 2026-06-19
compaction_generation: 0
source_type: canonical
confidence: high
lineage: []
---

# Active Context

## Current Focus

Semantic drift detection complete (2026-06-19). System is clean — no active work in progress.

## What Was Just Completed (2026-06-19)

**Semantic drift detection — spec, plan, and full implementation:**
- Spec: `docs/superpowers/specs/2026-06-19-semantic-drift-detection-design.md`
- Plan: `docs/superpowers/plans/2026-06-19-semantic-drift-detection.md`
- Check 21 (git-vs-reviewed lag), Check 22 (completed-but-still-planned), Check 23 (stale next step) added to `mb doctor` in both `scripts/mb.ps1` and `scripts/mb.sh`
- Advisory nudge fires when any drift check warns: "run /mb-drift for semantic analysis"
- `/mb-drift` skill created at `.claude/skills/mb-drift.md` — on-demand semantic analysis for duplicate concepts, supersession rot, authority violations
- `QUICK-REFERENCE.md` updated: 23-check doctor, `/mb-drift` skill listed

**Also completed this session (2026-06-19):**
- `master` → `main` rename across all 8 repos (PMB + 7 satellites); GitHub defaults fixed
- CLAUDE.md updated in Bowling-Tracker (PMB session-start sections) and GrillTimer (full PMB-format rewrite)
- `pre-push-check.sh`/`.ps1` bug fixed: `2>&1` → `2>/dev/null` on `--diff-filter=U` and `--porcelain` lines (CRLF warnings were being treated as merge conflicts on Windows)

## Next Steps

1. **Architecture review items on hold** — boring mode (`mb init --minimal`), explicit non-goals doc, `/core` vs `/integrations` separation; revisit if adoption friction surfaces

## Architecture Constraints to Remember

- `confidence:` is intentionally flat (high/medium/low)
- `source_type` and `compaction_generation` are independent axes — do not conflate
- `authority` (volatility) and startup-criticality are independent axes — do not merge into one field
- Detection-first, resist-automation: auto-remediation premature without semantic certainty
- "Overhead proportionate to certainty" — governing principle for any new governance additions
- `mb doctor` = observable integrity signals only; not semantic correctness, not workflow compliance
- `fixtures/` and `docs/` are excluded from pre-push secret scanning (intentionally bad code + docs quoting it)
- `mb status` = state ("can I work?"); `mb doctor`/`/health-check` = validation ("is it correct?")

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

main branch. All changes committed and pushed. System is clean. `mb doctor` shows 23 checks — Check 21 will warn until each file's `last-reviewed` catches up with recent commits.
