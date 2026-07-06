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

## Last Updated: 2026-07-06

## Current Focus

**CI-hardening task contract complete (2026-07-06)**: fixed the two red mains found in the
branch-protection planning pass (`Bowling-Tracker`, `gmail-organizer` — both green now), then
applied a "continue-on-error + gate" pattern across all 4 PMB-based repos so a failing early CI
step can never again mask a later real failure for weeks: `personal-memory-bank/pmb-health.yml`
(2 jobs), `Bowling-Tracker/ci.yml`, `Google-Organizer/ci.yml` — all edited, uncommitted, must be
committed/pushed by the user in their own repos (this session's review-gate hook only binds to
personal-memory-bank, so Claude cannot self-satisfy it elsewhere). Also created
`AI-Code-Review-Agent/.github/workflows/ci.yml` from scratch — that repo had no push/PR CI gate at
all (typecheck/lint/test/build only ran at release-tag time); fixed 6 pre-existing `format:check`
drifted files there so the new gate starts green.

**PMB v1.2.1** — fixed `templates/docs/` scaffolding gap (see `progress.md`). Downstream `mb upgrade` reruns still pending.

**Also completed (separate session, merged in):** PMB v1.2.0 CI infrastructure — doctor suite 35/35 passing, all 9 CI jobs confirmed green on PR #7 (`b1105e3`) as of 2026-07-04 (details: progress.md); `/change-review` now includes a Baseline Repo Health spot-check.

Next (deferred, not started): branch-protect `personal-memory-bank` + 8 downstream repos per the plan at `handoff-quiet-aho.md`, once all CI-hardening commits above are pushed and confirmed green.

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

1. Fix red CI on `Bowling-Tracker`/`gmail-organizer`, then branch-protect `personal-memory-bank` + 8 downstream repos using each repo's own CI (not PMB's 9-job workflow).
2. Re-run `mb upgrade` on downstream projects (Nolan-Budget + 8 repos) once 1.2.1 lands, to pick up `templates/docs/`.
3. Port `mb.ps1`'s command auto-discovery fix to `mb.sh` (still hardcodes a stale list — see CHANGELOG).
4. **Monitor PMB CI** — all 9 jobs confirmed green on PR #7 as of 2026-07-04, PSScriptAnalyzer at Warning severity; watch for genuinely new lint categories in future `.ps1` changes (Write-Host is now excluded project-wide; comment-only catch blocks still count as "empty").
5. **mb plan workflow** — `/feature-dev` Phase 3 now drafts plans to `.claude/plans/` and promotes via `mb plan promote`. Ensure new projects use this workflow.
6. **NPM_TOKEN renewal** (ACR) — expires 2026-09-08. Create new Automation token on npmjs.com and update ACR GitHub secret before this date.

## Git State

main branch. v1.2.1 fix pending commit/push this session.
