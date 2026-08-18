---
authority: volatile
review-cycle: 7d
retention: archive-after-6m
staleness-threshold: 14d
tags:
  - session/focus
  - session/blockers
  - session/next-steps
last-reviewed: 2026-08-18
compaction_generation: 0
source_type: canonical
confidence: high
lineage: []
---

# Active Context

## Last Updated: 2026-08-18

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

**Implementation plan written, self-reviewed, and independently reviewed**: `docs/superpowers/plans/2026-08-12-review-gate-layered-enforcement.md`, 14 tasks. The plan's own self-review found 3 real gaps between the spec's prose
and its own Files-Changed table (documented in the plan's "Design note," not silently reconciled). An
independent pre-implementation review agent, after being interrupted twice by an account-level
spend-limit error, was re-dispatched to completion on 2026-08-14 and found 8 more real defects — see
`[NS-15]` and `progress.md`'s 2026-08-14 entry. All 8 are fixed in the plan. **Still not implemented** —
do not assume any task in the plan has started without checking; still needs an execution-mode decision.

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
14. [NS-14] **Fleet version-drift, real incident (2026-08-12):** see entry above. Blocked on ACR resyncing first (cross-repo write boundary) — the detection-gap design work can start independently of that block. **Update (2026-08-17):** checked `mb.sh`'s actual version-check code directly — three distinct version values exist (target project's `.pmb-version`, the local PMB source clone's `$REPO_ROOT/VERSION`, GitHub `main`'s true latest) and nothing compares all three; `mb doctor` only checks target-vs-local-clone (WARN-only), a separate notifier only checks local-clone-vs-GitHub, so a stale local PMB clone makes `mb doctor` report "up to date" even when genuinely behind upstream. Full detail in `progress.md`'s 2026-08-17 entry, not repeated here.
15. [NS-15] **Execute the review-gate layered enforcement plan** (`docs/superpowers/plans/2026-08-12-review-gate-layered-enforcement.md`, 14 tasks, self-reviewed AND independently reviewed — see the "Review-Gate Layered Enforcement" entry above). Not started (no code changes made, plan still untracked). The independent pre-implementation review (interrupted twice by a spend-limit error, per the prior version of this entry) was re-run to completion on 2026-08-14 and found 8 real defects (3 Blocking, 2 High, 1 Medium, 2 Low) the self-review missed, including a `set -e` crash on a mainline push path. All 8 are now fixed directly in the plan document, within its existing Design Note section (matching the plan's existing self-review-gap convention). The plan itself has not been executed yet — still needs a Subagent-Driven vs. Inline execution decision before starting Task 1.
16. [NS-16] **Commit and hand off `investigation-integrity` design + the portable work-MB briefs.** Design committed `15df2c2`; the third mechanism (independent review discipline) plus 3 portable briefs — `docs/WORK-MB-INVESTIGATION-BRIEF.md`, `docs/WORK-MB-HOOKS-AND-SKILLS-BRIEF.md`, `docs/WORK-MB-DOCUMENT-STRUCTURE-BRIEF.md` — committed `70a06c1`. Run `superpowers:writing-plans` on the investigation-integrity spec next (still not started — `.claude/skills/investigation-integrity/SKILL.md` does not exist). Confirm with the user when the *current* 3-brief set should be delivered to the work-MB session — that specific set has not been sent in this form (an earlier, 2026-08-12 version of `docs/WORK-MB-INVESTIGATION-BRIEF.md` was already sent and its response already actioned — see `[NS-17]`; that is a different, older artifact from the one committed here). This entry's own correction history (two rounds of independent review, both finding this entry's *own* text inaccurate) is recorded in `progress.md`'s 2026-08-14 entry, not repeated here — that file is the accumulating/historical record per this project's authority-order convention; this entry now states only current state.
17. [NS-17] **Act on the confirmed findings from independently verifying the imported MB governance brief (2026-08-14)** — full detail in `progress.md`'s 2026-08-14 entry. Under an active task contract as of this entry: memory-bank trim (this file, in progress), ACR exit-code failure path in `/change-review` Job 7 (done), `mb clean` progress.md display (done). Optional, lower-priority: warn before `mb init`/`mb upgrade` overwrites a pre-existing non-default `core.hooksPath`.
18. [NS-18] **Resolve `worktree-concurrent-session-claims`**: run `/ai-review` against it (agreed with the user, not yet done), then `superpowers:finishing-a-development-branch` for the merge/PR decision — full detail archived in `docs/archive/context-2026-08-freshness-and-session-claims.md`. Added 2026-08-14 after an independent review caught that this item had fallen out of the numbered Next Steps list during today's memory-bank trim, contradicting the archive files' own claim that it was still tracked here.
19. [NS-19] **`templates/standards/WORKFLOW.md` has pre-existing drift from the live file** (Phase 3 describes an older `docs/plans/`-direct workflow; the live file describes the newer `.claude/plans/` draft + `mb plan promote` flow). Found 2026-08-14 while adding the new Phase 3.5 (Independent Plan Review) to both files — not caused by that change, not resolved by it either (Phase 3.5 was inserted at the equivalent position in both, leaving the pre-existing Phase 3 divergence untouched). Given this repo's own Fleet Version Drift Incident, this should be reconciled deliberately rather than left implicitly unnoticed. **Correction (independent review, 2026-08-14):** the new Phase 3.5 sections themselves also deliberately differ between the two files on one line — the template's "Why:" paragraph both omits the PMB-specific incident narrative and rewrites the trailing sentence (not just an omission) — kept generic for portability; not an accident, but not disclosed here until this correction. The two tables (Quick Reference, Claude Code Integration) are identical in both files. **Second correction (independent review, 2026-08-14):** `.claude/commands/feature-dev.md` is `TEMPLATE_OWNED` in `scripts/mb.sh` (overwritten unconditionally on `mb upgrade`) while `standards/WORKFLOW.md` is `ADVISORY_CREATE` (diff-and-warn, never silently overwritten) — its new Phase 3.5 note says "See `standards/WORKFLOW.md` for the full mechanism," so a downstream repo could get the force-updated `feature-dev.md` pointing at a `WORKFLOW.md` Phase 3.5 section it declined via the advisory diff. Not fixed here (INFERRED risk, not observed against a real downstream repo) — flagged for whoever next touches either file's distribution tier.
20. [NS-20] **`docs/specs/2026-08-14-document-structure-and-plan-lifecycle-design.md` is written and approved but NOT YET IMPLEMENTED.** Only that file and `docs/WORK-MB-DOCUMENT-STRUCTURE-BRIEF.md` exist. Still pending: the `CLAUDE.md` override (+ `templates/CLAUDE.md` mirror) redirecting `brainstorming`/`writing-plans` off their plugin defaults, `templates/docs/plans/README.md`, and frozen-as-of-date marker READMEs in `docs/superpowers/specs/` and `docs/superpowers/plans/`. Found by 3 independent `/code-review` domains (Correctness, Maintainability, Architecture Drift) converging on the same gap: the spec's own Files Changed table read as if these were already done. Needs `superpowers:writing-plans` next, same as `[NS-16]`.
21. [NS-21] **Audit PMB for mechanisms that exist but are undiscoverable or misrouted by their actual invocation path** — user-requested 2026-08-14, following two real incidents found within a few days of each other, in different mechanisms: `mb-drift.md` (fixed 2026-08-12, was a flat file instead of `<name>/SKILL.md`) and `/code-review` (found 2026-08-14). **Corrected via independent review, not the original attribution:** invoking `/code-review` via the `Skill` tool's bare name silently resolved to a **user-level (global config scope) twin at `~/.claude/commands/code-review.md`** — an older/generic ancestor of PMB's project version, with no `standards/CODE-REVIEW.md` contract, no marker-write step, and an instruction to generate tests during review (a `standards/CODE-REVIEW.md` Failure Criterion). It is **not** an installed marketplace plugin — `~/.claude/plugins/installed_plugins.json` was checked directly and contains no `code-review` entry; a marketplace plugin of that name exists only in the uninstalled catalog. Confirmed via `claude-code-guide`: typing `/code-review` literally is documented to correctly prefer the project-local command; the `Skill` tool's bare-name resolution across config scopes is undocumented, and this collision was reproduced and verified live (the returned content's exact subagent section names matched the user-level file byte-for-byte). **Checking for siblings (not treating this as isolated) found two more:** `~/.claude/commands/feature-dev.md` also exists and does **not** contain the new Phase 3.5 content just added to PMB's project version (`grep -c "3.5"` → 0) — anything invoking `feature-dev` ambiguously would silently get the version missing today's update. `~/.claude/commands/security-review.md` is, by contrast, byte-identical to PMB's project version (`diff` → empty) — no shadowing risk there, but it also has no hook/marker gate at all (checked `review-reminders.sh`/`dangerous-commands.sh`/`.githooks/` — none reference it), so its `[CRITICAL]`/`[HIGH]` findings are enforced only by `standards/WORKFLOW.md`'s advisory Phase 6, same trust ceiling as everything not wired into the review-gate marker system. **Separately found, adjacent but distinct:** `~/.claude/commands/ai-review.md` exists only at the user level — PMB's own `code-review.md` tells people to fall back to `/ai-review` for offline review, but PMB does not ship or own that command itself; a session without that global file would hit a dead reference. Audit scope: check every `.claude/commands/*.md` and `.claude/skills/*/SKILL.md` against its `~/.claude/commands/`/`~/.claude/skills/` equivalent for the same class of gap, not just plugin collisions. **Update (2026-08-14):** `security-review` and `ai-review` sub-findings resolved; a new hook (`scripts/warn-stale-review-marker.sh`/`.ps1`) was also built the same session. Full detail and rationale in `progress.md`'s 2026-08-14 entries, not repeated here. **Still open:** the original `/code-review` Skill-tool shadowing risk itself (worked around, not fixed at the mechanism level), `feature-dev.md`'s user-level/project-level drift, and the broader audit scope above. **Update (2026-08-17):** a hardening audit of `/code-review`, `/security-review`, `/change-review` (same audit family as this item) found real, non-speculative drift — `/change-review` Job 7's inline security fallback has silently diverged from `/security-review`'s pattern list in both directions, dropping the XSS and unsafe-eval/exec checks entirely while adding others; `/code-review`'s 5 required domains share no concrete checklist beyond Architecture Drift, so Security/Correctness/Maintainability/Testing findings rest on unconstrained model judgment. Full detail in `progress.md`'s 2026-08-17 entry, not repeated here.
22. [NS-22] **Compaction/handoff protocol is advisory-only and silently rots — same trust ceiling as `[NS-21]`.** Found 2026-08-17: two stale, untracked `handoff.md` files (repo root, dated 2026-08-03/04; `.claude/worktrees/mystifying-hertz-c54477/`, dated 2026-07-27) sat undetected for weeks — nothing enforces `CLAUDE.md:124`'s instruction to delete a handoff file after merging its content into Memory Bank. Full detail in `progress.md`'s 2026-08-17 entry, not repeated here. Not designed yet — needs its own brainstorming pass.
23. [NS-23] **No mechanism verifies `standards/*.md` content against the external authorities it cites (WCAG, OWASP, etc.).** Found 2026-08-17, same audit pass as `[NS-22]`. Only 3 of ~15 standards files carry `review-cycle`/`staleness-threshold` frontmatter at all (`PERFORMANCE-BUDGET.md`, `SECURITY-RULES.md`, `TRUST-CLASSIFICATION.md`); `ACCESSIBILITY.md` (claims WCAG 2.1 AA), `SECURITY-GUARDRAILS.md`, `CODE-QUALITY.md` have none. Where present, the mechanism only prompts a manual re-read on a timer — no doctor/CI check compares against the actual current external standard version. Full detail in `progress.md`'s 2026-08-17 entry. Not designed yet.
24. [NS-24] **Working through the full `/change-review` pass's findings (3 Blocking + 8 non-blocking) on `docs/branch-protection-rollout`, per "fix all found issues... new and preexisting."** Committed so far: doc-accuracy fixes (`6d92ba3`), `mb.ps1` backlog port (`42885b4`/`77b699c`), `dangerous-commands.sh`/`.ps1` git-merge CONFIRM hardening (`499dbe5` — went through 2 full review rounds, each catching real defects the prior round missed: a leading-boundary false-positive, an sh/ps1 Unicode-whitespace divergence, an sh/ps1 case-sensitivity divergence, and a `templates/scripts/` mirror gap the opposition reviewer caught that neither domain-review round did). **Live-reproduced the still-pending marker-destruction-on-denial bug** (tracked below as a remaining item) during this same work: a `git commit` denied by `dangerous-commands.sh` (commit message literally contained the guarded phrase) still let the marker-consuming logic destroy an already-written, already-independently-verified `.claude/.code-review-ok`, forcing a restore-and-reverify cycle before the commit could land. **Also committed:** `warn-stale-review-marker` hook documented in `HOOKS-GUIDE.md` + template mirror (`7d6d2b9`); all 3 test-coverage gaps closed (`2991093` — version-notifier quote-stripping, `mb clean`'s weak assertion, and PowerShell parity for `review-reminders.ps1`'s `Resolve-CdRoot`, the last of which required discovering that testing a native PowerShell process needs real Windows paths with escaped backslashes, not bash's POSIX-style `mktemp` paths — an unescaped backslash inside a JSON string silently corrupts the path and looks exactly like a real bypass until traced back). **Also fixed, same task family:** `test-mb-version-notifier.sh`'s live-fetch sub-test silently proceeded if its background `python3 -m http.server` never became reachable (10×0.3s poll fell through with no signal), producing a confusing "14 passed, 9 failed" cascade that looked like a real regression — root-caused via deliberate reproduction (neutering the server-launch line), fixed with a `server_ready` flag + explicit SKIP message (`d64a4fc`), then refined to also capture and print the server's stderr in that SKIP message (`bbb697a`) so a genuine bind failure is diagnosable — verified against a real Windows port-exclusion-range bind failure (`PermissionError: [WinError 10013]`) surfacing correctly, both by the orchestrator and independently by the Opposition reviewer using a different repro method (port-exclusion range vs. simple pre-occupation). **Process note:** the first attempt at this diff's review collapsed domain-review and Opposition into one self-contained agent call, which the harness correctly flagged as self-approval (reviewer and reviewed-change must be separate agents) — redone properly as two separate agents before commit.
**Marker-destruction-on-denial deliberately deferred (2026-08-18):** the real fix already exists on
`feature/review-gate-layered-enforcement` (14 tasks, done — peek-only `PreToolUse` removes this bug class),
but it can't cleanly rebase onto `main` (see 2026-08-17 entry). A second branch,
`fix/review-gate-reconcile-designs` (uncommitted WIP), also touches this area — a narrow patch here would
be a third overlapping mechanism. Recommendation followed (user deferred): leave disclosed-pending, do
#34/#35, treat the 3-way reconciliation as its own future design pass. **Still pending:** the bug (live
repro on hand); #34 (cache-write/trap hardening); #35 (test run + `/change-review` + push/merge PR #8).

## Cross-Repo Write Boundary Gate — Governance Note

`memory-bank/` is tracked (not gitignored) and per-branch — editing it from a worktree would diverge that branch's copy from main's. Per this file's own rule ("Never update or commit memory-bank/ from a subworktree"), updates are made from the main checkout, never from within a worktree.

## Git State

main branch is protected as of 2026-07-08 (PR + passing checks required, enforce_admins: true).
Direct `git push origin main` no longer works on this repo — create a branch, commit, push the
branch, then open a PR and merge once required checks pass.
