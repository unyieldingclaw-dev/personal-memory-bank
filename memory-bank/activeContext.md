---
authority: volatile
review-cycle: 7d
retention: archive-after-6m
staleness-threshold: 14d
tags:
  - session/focus
  - session/blockers
  - session/next-steps
last-reviewed: 2026-06-01
compaction_generation: 0
source_type: canonical
confidence: high
lineage: []
---

# Active Context

## Current Focus

v1.0.4 shipped (2026-06-01). Security & performance improvements complete. Repo is stable. Next decision point is observation-driven: wait for 30-day startup context growth data (~June 4) before making classification or loader decisions.

## What Was Just Completed (2026-06-01)

**Security & Performance Improvements — v1.0.4:**
- `standards/SECURITY-RULES.md` — rule registry SEC-001–009 (CRITICAL/HIGH/MEDIUM); distributed via mb init/upgrade (ADVISORY_CREATE)
- `standards/TRUST-CLASSIFICATION.md` — TRUSTED/SEMI_TRUSTED/UNTRUSTED source classification reference; pointers wired into AGENTIC-SAFETY.md and SECURITY-GUARDRAILS.md
- `standards/PERFORMANCE-BUDGET.md` — explicit limits: ≤20 standards, ≤50 memory entries, ≤1 agent delegation, changed-files-first scan scope
- `fixtures/security/` — 9 known-bad code samples (SEC-001–009) for security regression testing; PMB dogfooding only, not distributed
- Structured finding format in `/security-review` command and security-reviewer agent: Rule ID, Evidence snippet, Confidence, Fix
- Trust level note in security-reviewer agent for prompt-injection/rules-file-integrity findings
- `mb doctor` Check 13: verifies fixtures/security/ structure (9 subdirectories); Check 14: standards count warns if >20
- `/health-check` updated: step 5 runs `/security-review` against fixtures, reports caught/missed per rule ID
- `docs/COMMANDS-REFERENCE.md` updated: checks 13+14 added, count updated to 14
- All 3 new standards distributed via mb init (glob loop) and mb upgrade (ADVISORY_CREATE)
- **Fix:** Pre-push secret scan now excludes `fixtures/` and `docs/` (known-bad test fixtures + docs quoting them)
- Design spec: `docs/superpowers/specs/2026-05-31-security-performance-improvements-design.md`

## What Was Completed (2026-05-29)

**v1.0.3 — Standards distribution, version tracking, pre-push hook, install-hooks:**
- `mb install-hooks` subcommand (retrofit for existing projects; dry-run support)
- Pre-push hook: 7 checks (conflicts, markers, dirty tree, .gitattributes, secrets scan, large files, mb validate)
- Standards distribution: templates/standards/ (12 files) + mb init glob loop + mb upgrade ADVISORY_CREATE
- `.pmb-version` tracking: written by mb init/upgrade; mb doctor Check 12
- Remote version check in mb upgrade (soft, non-blocking)
- mb doctor Checks 11 (required standards) and 12 (.pmb-version)

## Next Steps

1. **Wait for 30-day growth data** (~June 4) — startup context section will show real growth % once repo crosses 30-day window; use that data to decide whether classification is needed
2. **Architecture review items on hold** — boring mode (`mb init --minimal`), explicit non-goals doc, `/core` vs `/integrations` separation; none are urgent, revisit if adoption friction surfaces
3. **Semantic identity** (progress.md backlog) — concept-level drift detection; detection-first, no auto-remediation; not yet, complexity budget is spent

## Architecture Constraints to Remember

- `confidence:` is intentionally flat (high/medium/low)
- `source_type` and `compaction_generation` are independent axes — do not conflate
- `authority` (volatility) and startup-criticality are independent axes — do not merge into one field
- Detection-first, resist-automation: auto-remediation premature without semantic certainty
- "Overhead proportionate to certainty" — governing principle for any new governance additions
- `mb doctor` = observable integrity signals only; not semantic correctness, not workflow compliance
- `fixtures/` and `docs/` are excluded from pre-push secret scanning (intentionally bad code + docs quoting it)

## Git State

master branch, clean. Last commit: `c837e3d` — pre-push scan exclusion fix. v1.0.4 tagged and pushed.
