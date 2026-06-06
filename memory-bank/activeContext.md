---
authority: volatile
review-cycle: 7d
retention: archive-after-6m
staleness-threshold: 14d
tags:
  - session/focus
  - session/blockers
  - session/next-steps
last-reviewed: 2026-06-03
compaction_generation: 0
source_type: canonical
confidence: high
lineage: []
---

# Active Context

## Current Focus

v1.0.6 shipped (2026-06-03). Guardrails batch (G1–G6) shipped (2026-06-06): PowerShell tool hook, hook failure alerting, contract hard-block mode, first-push secret scan fix, rules-file integrity CI, and SAST CI. Repo is stable.

Two pending workstreams from the 2026-06-03 session — not yet designed or implemented:

**Command consolidation (15 → 8 commands):**
Final command set: `mb init`, `mb status`, `mb doctor`, `mb query`, `mb clean`, `mb commit`, `mb upgrade`, `mb help`
Absorptions: `mb audit` + `mb validate` + `mb budget` → `mb doctor`; `mb compact` + `mb update` + `mb archive` + `mb slim` → `mb clean`; `mb install-hooks` → `mb upgrade`
Key decision: Option B for `mb upgrade` (run directly, report results, no dry-run preview)

**Natural language triggers for mb commands:**
Root cause identified: zero mb subcommands have natural-language triggers in CLAUDE.md.
Fix: add MB Commands Protocol section to `templates/CLAUDE.md`, `CLAUDE.md`, and Cursor rules. Same pattern as Handoff Protocol. Plan file: `C:\Users\Mizzo\.claude\plans\based-on-the-polished-piglet.md`

## What Was Just Completed (2026-06-03)

**Code Review Standard — v1.0.6:**
- `Confidence: High|Medium|Low` replaced by `Basis: VERIFIED|INFERRED|SPECULATIVE` across 4 files (standards/CODE-REVIEW.md, templates/standards/CODE-REVIEW.md, both code-review command files)
- Evidence requirements tightened per-basis: file:line required on all findings; SPECULATIVE must cite observed trigger + explicit uncertainty
- Blocking constraint tightened: `Blocking: true` requires `Severity >= High AND Basis != SPECULATIVE`
- Report format: single Findings table → `## Supported Findings` (VERIFIED+INFERRED) + `## Predicted Risks` (SPECULATIVE, omit if empty)
- Three new Failure Criteria: missing file:line, evidence not materially supporting claim, SPECULATIVE marked blocking
- Breaking change: `Confidence` field removed; documented in Compatibility Note

**`/pmb-status` + `mb status` redesign — v1.0.5:**
- `mb status` reworked: replaced file-size table with 5-signal state check (Initialized, Core Memory Present, Active Context Current, Standards Available, Tasks Present)
- `/pmb-status` slash command: thin wrapper over `mb status` — no logic duplication; CLI owns behavior, slash command owns UX
- Distributed via `mb init` and `mb upgrade` (same tier as other governance commands)
- Design principle: `git status` / `git fsck` distinction — status = state, health-check = validation
- Code review fixes (all confirmed findings addressed):
  - `sed 's/d$//'` — trailing anchor prevents corrupting mid-string 'd' values [HIGH]
  - `$STALE_DAYS` numeric guard prevents integer expression error on malformed frontmatter [HIGH]
  - `REVIEWED_EPOCH=0` treated as parse failure (not ~19,000 false stale days) [MEDIUM]
  - `compgen -G` replaces `ls|head` glob check (zero subprocesses, portable) [MEDIUM]
  - WHY comments added to try/catch and cross-file sync notes [LOW]
- All docs updated: README, QUICK-REFERENCE, RECOVERY, SETUP-GUIDE, COMMANDS-REFERENCE, CHANGELOG

## What Was Completed (2026-06-01)

**Security & Performance Improvements — v1.0.4:**
- `standards/SECURITY-RULES.md` — rule registry SEC-001–009; distributed via mb init/upgrade (ADVISORY_CREATE)
- `standards/TRUST-CLASSIFICATION.md` — TRUSTED/SEMI_TRUSTED/UNTRUSTED reference; pointers in AGENTIC-SAFETY + SECURITY-GUARDRAILS
- `standards/PERFORMANCE-BUDGET.md` — explicit limits: ≤20 standards, ≤50 memory entries, ≤1 agent delegation
- `fixtures/security/` — 9 known-bad code samples for security regression testing (PMB dogfooding only)
- `mb doctor` Checks 13+14; `/health-check` step 5; pre-push scan excludes fixtures/ and docs/

## Next Steps

1. **Wait for 30-day growth data** (~June 4) — startup context section will show real growth % once repo crosses 30-day window; use that data to decide whether classification is needed
2. **Architecture review items on hold** — boring mode (`mb init --minimal`), explicit non-goals doc, `/core` vs `/integrations` separation; revisit if adoption friction surfaces
3. **Semantic identity** (progress.md backlog) — concept-level drift detection; detection-first, no auto-remediation; not yet, complexity budget is spent

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

master branch, clean. Last commit: `10afad8` — code review Basis/evidence standard. v1.0.6 shipped.
