---
authority: volatile
review-cycle: 7d
retention: archive-after-6m
staleness-threshold: 14d
tags:
  - session/focus
  - session/blockers
  - session/next-steps
last-reviewed: 2026-06-18
compaction_generation: 0
source_type: canonical
confidence: high
lineage: []
---

# Active Context

## Current Focus

PMB Commands Audit complete (2026-06-18). All 58 findings resolved or triaged. System is clean — no active work in progress.

## What Was Just Completed (2026-06-18)

**PMB Commands Audit — 6-lens parallel review + full fix execution:**
- Audit spec: `docs/superpowers/specs/2026-06-18-mb-commands-audit.md` (58 findings: 2C/14H/19M/23L)
- Implementation plan: `C:\Users\Mizzo\.claude\plans\mb-audit-fixes.md`
- All findings resolved: Z1 (budgetLimit), Z2 (pwsh consistency), L3 (HOOKS-GUIDE exit codes), L4 (handoff bypass already present), L5–L8 (template sync), M2 (pre-compact-check distribution), M3 (Agent in code-review), M4 (session-start steps)
- **L1/M1:** `check-contract.ps1/.sh` (live + templates) fixed to read stdin (`$input|Out-String` / `cat`) — was silently failing open on every invocation due to nonexistent `$env:CLAUDE_TOOL_INPUT`
- **L2:** `health-check.md` step 5 uses `@security-reviewer` (agent notation) — false positive, no change needed
- **mb.sh parity fix:** `TEMPLATE_OWNED` array now includes `scripts/pre-push-check.sh` and `scripts/pre-push-check.ps1` (was missing; `mb.ps1` already had them); ordering matches `mb.ps1`

## Next Steps

1. **Architecture review items on hold** — boring mode (`mb init --minimal`), explicit non-goals doc, `/core` vs `/integrations` separation; revisit if adoption friction surfaces
2. **Semantic identity** (progress.md backlog) — concept-level drift detection; detection-first, no auto-remediation; not yet, complexity budget is spent

## What Was Just Completed (2026-06-18, doc update pass)

- Bumped VERSION to 1.1.1; added CHANGELOG entry documenting 4 fixes (check-contract stdin, mb.sh parity, HOOKS-GUIDE example, QUICK-REFERENCE count)
- Fixed QUICK-REFERENCE.md: `mb doctor` "16-point" → "20-check diagnostic"
- Fixed HOOKS-GUIDE.md: per-project "Lint Before Commit" example corrected from `echo "$CLAUDE_TOOL_INPUT"` to `HOOK_INPUT=$(cat 2>/dev/null); echo "$HOOK_INPUT"`
- Committed audit spec (`docs/superpowers/specs/2026-06-18-mb-commands-audit.md`) as part of doc release
- Pushed master to origin; updated GitHub repo description to reflect v1.1.1

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

master branch. All changes committed and pushed. System is clean.
