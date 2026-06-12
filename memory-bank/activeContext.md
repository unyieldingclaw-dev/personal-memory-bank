---
authority: volatile
review-cycle: 7d
retention: archive-after-6m
staleness-threshold: 14d
tags:
  - session/focus
  - session/blockers
  - session/next-steps
last-reviewed: 2026-06-11
compaction_generation: 0
source_type: canonical
confidence: high
lineage: []
---

# Active Context

## Current Focus

v1.1.0 shipped (2026-06-11). Git hooks migrated from `.git/hooks/` copy-on-init to versioned `core.hooksPath = .githooks` layout:
- **`.githooks/pre-push`** and **`.githooks/pre-commit`**: committed, versioned, distributed via `mb upgrade` (TEMPLATE_OWNED)
- **`mb init`**: creates `.githooks/`, copies both hooks, sets `git config core.hooksPath .githooks`
- **`mb upgrade`**: keeps hooks current via TEMPLATE_OWNED; sets `core.hooksPath`; removes old `.git/hooks/pre-push` PMB shim
- **`mb doctor`** check 4: updated in both bash and PowerShell to verify `.githooks/pre-push` presence + `core.hooksPath` value
- **Pre-commit hook now active**: blocked by missing `core.hooksPath` before; now fires on every commit (handoff.md block + AUTOCOMPACT warning)
- **README version badge**: updated to 1.1.0

**Context size**: progress.md archived 2026-06-12 → 12 KB (below 15 KB warning threshold).

## What Was Just Completed (2026-06-11)

**Git Hooks Migration — v1.1.0:**
- `templates/.githooks/pre-push` and `templates/.githooks/pre-commit` created
- `scripts/mb.sh`: init block, TEMPLATE_OWNED entries, upgrade wiring, doctor check — all updated
- `scripts/mb.ps1`: init block, `$templateOwned` entries, upgrade wiring (replaced `Invoke-InstallHooks` call), doctor check — all updated
- `docs/HOOKS-GUIDE.md`: new "Git Hooks (versioned)" section
- `README.md`: pre-push `<details>` block and version badge updated
- `CHANGELOG.md`: 1.1.0 entry prepended
- `VERSION`: 1.0.9 → 1.1.0
- PMB repo itself: `git config core.hooksPath .githooks` (activates previously-dead pre-commit)

## What Was Completed (2026-06-06)

**mb doctor v1.0.8 — 20 checks + compaction gate + agent delegation depth:**
- Checks 17–20: semantic drift, stale decisions, cross-file contradictions, SHA-256 checksums (`mb verify-integrity`)
- Compaction quality gate: pre-compact-check BLOCKS unless activeContext.md ≥3 lines AND progress.md has today's date
- Agent delegation depth: `delegation-depth-check.ps1/.sh` + PreToolUse hook on Agent tool; WARN when depth >1

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

master branch. Uncommitted: scripts/mb.ps1 (diff-u bug fix), memory-bank updates (progress.md archived + activeContext.md). Downstream projects all patched this session.
