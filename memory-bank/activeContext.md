---
authority: volatile
review-cycle: 7d
retention: archive-after-6m
staleness-threshold: 14d
tags:
  - session/focus
  - session/blockers
  - session/next-steps
last-reviewed: 2026-08-13
compaction_generation: 0
source_type: canonical
confidence: high
lineage: []
---

# Active Context

## Last Updated: 2026-08-14

## This File Was Trimmed Today (2026-08-14)

Was 671 lines, over its own 150-line CI-enforced limit (found while independently verifying an
imported governance-review document — see `progress.md`'s 2026-08-14 entry for the full finding and
the other fixes it produced: an ACR exit-code failure path in `/change-review` Job 7, and `mb clean`'s
Slim Check now also surfacing `progress.md`'s status). Historical narrative for everything dated
2026-07-13 through 2026-08-05 moved to `docs/archive/context-2026-07-*.md` /
`docs/archive/context-2026-08-freshness-and-session-claims.md` — condensed pointers below. Nothing
operationally open was dropped; check `Next Steps` for the authoritative pending-work list.

## User-As-Bypass Hardened Into Governance + Investigation-Integrity Design (2026-08-12)

The user caught this session's own established habit ("hand the user the exact commit commands when
the marker-write gets classifier-blocked") live and named it directly: never use the user as the
bypass for a control the agent itself couldn't satisfy — distinct from CONFIRM/BLOCK-tier commands
(force-push, `--no-verify`, etc.) where a human's hands are the *designed* resolution. Hardened into
`standards/SECURITY-GUARDRAILS.md` (+ template mirror) and `docs/HOOKS-GUIDE.md` (+ trimmed mirror),
not left as private-memory-only. Also fixed a real ~2-month latent bug found along the way: `.claude/skills/mb-drift.md` was never discoverable (Claude Code requires `<name>/SKILL.md`, not a flat
file) — fixed via `git mv`, live-confirmed.

New spec `docs/superpowers/specs/2026-08-12-investigation-integrity-design.md` and portable brief
`docs/WORK-MB-INVESTIGATION-BRIEF.md` (for the user's separate work Memory-Bank project) — both
committed `15df2c2`. **A proposed "review-depth classification" amendment to the review-gate spec was
explicitly designed then withdrawn** on the user's principled objection ("do we really have to scheme
on how to get out of regulated actions?") — it was a standing, self-administered review-scope
exception, the same failure class as the original user-as-bypass mistake. Do not re-propose without
re-litigating this. **Standing rule: full `/code-review`, every time, no lite path.**

## Review-Gate Layered Enforcement — Spec Committed, Plan Written (2026-08-12 / 2026-08-13)

Design spec `docs/superpowers/specs/2026-08-12-review-gate-layered-enforcement-design.md` (`f2cec79`,
fixed `b47db8f`) closes the structural bypass above: CC `PreToolUse` hook downgraded to non-consuming
peek; `.githooks/pre-commit`/`pre-push` promoted to sole authoritative marker consumer (fires
regardless of invoker); new CI containment check as the only actually-unbypassable backstop, reading a
new durable `docs/review-log/` record + invocation-start log. Explicitly disclosed, not hidden:
`--no-verify` and an unset `core.hooksPath` still fully defeat the git-hook layer; a fully adversarial
agent could still fabricate both the marker and the review-log entry — closes the structural
invoker-switching bypass only, not the deeper self-attestation trust problem.

**Implementation plan written and self-reviewed**: `docs/superpowers/plans/2026-08-12-review-gate-layered-enforcement.md`, 14 tasks. The plan's own self-review found 3 real gaps between the spec's prose
and its own Files-Changed table (documented in the plan's "Design note," not silently reconciled). An
independent pre-implementation review agent was dispatched and interrupted twice by an account-level
spend-limit error — handled by stopping and disclosing plainly rather than working around it; not yet
re-run to completion as of this entry. **Not yet implemented** — do not assume any task in the plan
has started without checking.

## Fleet Version Drift Incident — ACR Found 2 Versions Behind (2026-08-12)

Cross-session report: `ai-code-review-agent`'s `.pmb-version` reads `1.1.1` while PMB's own `VERSION`
is `1.2.1` plus unreleased work — ACR ran a real 13-task implementation effort under review-gate hooks
two versions stale before this was caught. Root cause: `mb doctor`'s existing version-mismatch check
is a passive WARN, easy to miss. The "`mb upgrade` should not just look at date" question is resolved,
not open: `TEMPLATE_OWNED` sync is already unconditional; the actual gap is nothing *triggers* a run.
**Not yet resolved** — blocked on ACR resyncing from its own session (cross-repo write boundary); see
`[NS-14]`.

## Memory Bank Freshness Hook, Concurrent Session Claims, Confirm-Step Live Review, mb backlog Feature

Full narrative archived — `docs/archive/context-2026-08-freshness-and-session-claims.md` covers the
2026-08-10 freshness-hook spec (committed `3e475ae`, not yet implemented, `[NS-13]`) and the
2026-08-08 concurrent-session-claims ship (13 tasks + 5 post-review fixes, `/ai-review` still pending
on that branch). `docs/archive/context-2026-07-review-gate-hardening.md` covers the review-gate
mechanism's evolution 2026-07-16 through 2026-08-05 (self-attestation fix, false-positive fix,
confirm-step redesign, worktree-root-resolution fix, hook-lib-dedup, first live whole-branch review).
`docs/archive/context-2026-07-backlog-and-notifier.md` covers `mb backlog` Task 1 (shipped, Tasks 2-5
not started, `[NS-0]`) and the mb update-notifier + authorization-drift incident that produced the
"What Counts as Approval" rule.

## Current Focus

Branch protection rolled out 2026-07-08 to the 5 public PMB-based repos (full detail:
`docs/archive/context-2026-07-fleet-audit-and-branch-protection.md`, which also covers the 2026-07-13
fleet audit finding real review-flow enforcement in only 2 of 11 repos). `docs/branch-protection-rollout`
is the working branch; PR #8 open, CI-green, unmerged as of last check — see `[NS-4]`.

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

0. [NS-0] **Resume `mb backlog` Tasks 2-5** from `.claude/worktrees/backlog-feature` (branch `worktree-backlog-feature`, Task 1 committed at `3c6cb3d`) — full detail archived, see above. Task contract there expired 2026-07-24T00:59:18Z — re-propose. Full task specs: `docs/superpowers/plans/2026-07-14-backlog-feature.md`.
1. [NS-1] **Decide what to do with unrelated uncommitted WIP** (`/ai-review` merge-gate nudge + a "Hook-Enforced Review Gate" section in `standards/WORKFLOW.md`) — no matching commit/branch/memory-bank entry found anywhere as of last check. Needs its own review + commit decision.
2. [NS-2] **`docs/branch-protection-rollout` needs pushing** — was significantly ahead of `origin` as of last check; today's session added more commits on top. Re-check ahead-count before pushing.
3. [NS-3] **Merge two pending worktree branches:** `worktree-cross-repo-write-boundary` (8 commits, tests green) and `worktree-fix-workflow-doc-paths` (single commit `b52f63d`). Both need a PR + user-run merge.
4. [NS-4] PR #8 (`docs/branch-protection-rollout`) — this session's own `gh pr merge` gate means it can never merge this itself; user needs to run `gh pr merge` directly.
5. [NS-5] Delete `rfx-data-analytics` manually (blocked on missing `gh` OAuth scope).
6. [NS-6] **Tipsy-Bunghole, before syncing:** commit + push its pending planning-doc commits first, then run `mb upgrade` from inside that repo's own session. `Nolan-Budget` needs the opposite: its already-current local state just needs committing and pushing.
7. [NS-7] Fix red CI on `Bowling-Tracker`/`gmail-organizer` (confirm still red), then write real CI workflows for `pitlogic`/`Spotify-Road-Trip`/`Pit-timer`.
8. [NS-8] Port `mb.ps1`'s command auto-discovery fix to `mb.sh` (still hardcodes a stale list).
9. [NS-9] **Monitor PMB CI** — watch for genuinely new PSScriptAnalyzer lint categories in future `.ps1` changes.
10. [NS-10] `mb plan` workflow reconciliation with `/superpowers:writing-plans` — investigated and declined (no actual incident behind it); not planned unless a concrete need surfaces.
11. [NS-11] **NPM_TOKEN renewal** (ACR) — expires 2026-09-08. Create new Automation token on npmjs.com and update ACR GitHub secret before this date.
12. [NS-12] **Fleet-wide `mb` command gap:** no `mb upgrade-all`/project registry exists. Worth a real design pass if drift recurs — see `[NS-14]`, which is the recurrence.
13. [NS-13] **Write the implementation plan for the memory-bank freshness hook** (spec: `docs/superpowers/specs/2026-08-10-memory-bank-freshness-hook-design.md`, committed `3e475ae`) via `superpowers:writing-plans`. Not started.
14. [NS-14] **Fleet version-drift, real incident (2026-08-12):** see entry above. Blocked on ACR resyncing first (cross-repo write boundary) — the detection-gap design work can start independently of that block.
15. [NS-15] **Execute the review-gate layered enforcement plan** (`docs/superpowers/plans/2026-08-12-review-gate-layered-enforcement.md`, 14 tasks, self-reviewed) via `superpowers:subagent-driven-development` or `superpowers:executing-plans`. Not started — an independent pre-implementation review was interrupted by a spend-limit error and not yet completed; consider re-running it first.
16. [NS-16] **Commit and hand off `investigation-integrity` design + the portable work-MB brief** — both committed as of `15df2c2`. Run `superpowers:writing-plans` on the investigation-integrity spec next, and confirm with the user when the portable brief should be delivered to the work-MB session.
17. [NS-17] **Act on the confirmed findings from independently verifying the imported MB governance brief (2026-08-14)** — full detail in `progress.md`'s 2026-08-14 entry. Under an active task contract as of this entry: memory-bank trim (this file, in progress), ACR exit-code failure path in `/change-review` Job 7 (done), `mb clean` progress.md display (done). Optional, lower-priority: warn before `mb init`/`mb upgrade` overwrites a pre-existing non-default `core.hooksPath`.
18. [NS-18] **Resolve `worktree-concurrent-session-claims`**: run `/ai-review` against it (agreed with the user, not yet done), then `superpowers:finishing-a-development-branch` for the merge/PR decision — full detail archived in `docs/archive/context-2026-08-freshness-and-session-claims.md`. Added 2026-08-14 after an independent review caught that this item had fallen out of the numbered Next Steps list during today's memory-bank trim, contradicting the archive files' own claim that it was still tracked here.

## Cross-Repo Write Boundary Gate — Governance Note

`memory-bank/` is tracked (not gitignored) and per-branch — editing it from a worktree would diverge that branch's copy from main's. Per this file's own rule ("Never update or commit memory-bank/ from a subworktree"), updates are made from the main checkout, never from within a worktree.

## Git State

main branch is protected as of 2026-07-08 (PR + passing checks required, enforce_admins: true).
Direct `git push origin main` no longer works on this repo — create a branch, commit, push the
branch, then open a PR and merge once required checks pass.
