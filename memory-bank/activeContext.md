---
authority: volatile
review-cycle: 7d
retention: archive-after-6m
staleness-threshold: 14d
tags:
  - session/focus
  - session/blockers
  - session/next-steps
last-reviewed: 2026-06-24
compaction_generation: 0
source_type: canonical
confidence: high
lineage: []
---

# Active Context

## Current Focus

Comprehensive audit + remediation sprint complete (2026-06-24). PMB v1.2.0 and ACR v1.1.0+ are both fully shipped. No active work items.

## What Was Completed (2026-06-24)

**PMB Audit — 4 workstreams:**
- WS1 (v1.1.2): Bug fixes — settings.json invalid JSON, pre-compact false positives, missing TRUNCATE/DELETE FROM guardrails
- WS2 (v1.2.0): Test coverage — 115 assertions across 11 suites; all mb commands now tested
- WS3: CI hardening — PSScriptAnalyzer (PowerShell lint) + mb doctor self-check; 9 total CI jobs
- WS4: Performance + docs — O(n²) pre-cache in doctor checks 22+23, find pipe fix, help aliases, delegation-depth docs

**ACR Audit:**
- P0+P1 partial: comment marker, provider validation, README count, orchestrator deterministic-source guard, sanitizer metadata, Prettier CI, command docs
- P1 deferred (already in v1.1.0): policy layer, SARIF, GitHub annotations — all confirmed implemented
- P2: schemaVersion/toolVersion/profile fields in ReviewResult + integration contract docs in README

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

No active work items. Potential follow-ons:
- ACR calibration against real diffs (calibrate.ts)
- PMB `mb upgrade` on downstream satellite projects to distribute v1.2.0 changes

## Git State

Both repos on `main`, all commits pushed. Working trees clean.
