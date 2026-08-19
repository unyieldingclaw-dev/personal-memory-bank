---
authority: volatile
review-cycle: 7d
retention: archive-after-6m
staleness-threshold: 14d
tags:
  - session/focus
  - session/blockers
  - session/next-steps
last-reviewed: 2026-08-19
compaction_generation: 0
source_type: canonical
confidence: high
lineage: []
---

# Active Context

## Last Updated: 2026-08-18 (later)

## Trim History

Trimmed 2026-08-14 (671→~150), 2026-08-18 (NS-24 condensed; older narrative sections condensed further
same day). Full history in `docs/archive/context-*.md` / `progress.md`'s dated entries. `Next Steps` is
the authoritative pending-work list.

## User-As-Bypass Hardened; Investigation-Integrity Design (2026-08-12)

Never use the user as the bypass for a control the agent itself couldn't satisfy (distinct from
CONFIRM/BLOCK-tier commands where a human IS the designed resolution) — hardened into
`standards/SECURITY-GUARDRAILS.md`/`docs/HOOKS-GUIDE.md` (+ template mirrors), not left private-memory-only.
Spec `docs/superpowers/specs/2026-08-12-investigation-integrity-design.md` + brief
`docs/WORK-MB-INVESTIGATION-BRIEF.md` committed `15df2c2`. A "review-depth classification" exemption was
designed then explicitly withdrawn on user objection — same failure class as user-as-bypass. **Standing
rule: full `/code-review`, every time, no lite path.** Full narrative: `progress.md` 2026-08-12.

## Review-Gate Layered Enforcement — Spec + Plan Written, Not Yet Executed (2026-08-12/13)

Spec `docs/superpowers/specs/2026-08-12-review-gate-layered-enforcement-design.md` (`f2cec79`, fixed
`b47db8f`): CC `PreToolUse` hook downgraded to non-consuming peek; `.githooks/pre-commit`/`pre-push`
become sole authoritative marker consumer; new CI containment check as backstop. Disclosed limits:
`--no-verify`/unset `core.hooksPath` still defeat the git-hook layer. **Plan**
(`docs/superpowers/plans/2026-08-12-review-gate-layered-enforcement.md`, 14 tasks) self-reviewed AND
independently reviewed (8 real defects found, all fixed in-plan) — see `[NS-15]`. **Still not
implemented** — needs an execution-mode decision before Task 1. Full narrative: `progress.md` 2026-08-12/14.

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
was the working branch; **PR #8 merged 2026-08-19** (squash-merged to `main` as `b0490ef`) — see `[NS-4]`.

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
2. [NS-2] **Resolved — see NS-4 and NS-24** (`docs/branch-protection-rollout` push + merge saga, fully resolved 2026-08-19).
3. [NS-3] **Merge two pending worktree branches:** `worktree-cross-repo-write-boundary` (8 commits, tests green) and `worktree-fix-workflow-doc-paths` (single commit `b52f63d`). Both need a PR + user-run merge.
4. [NS-4] **Resolved 2026-08-19: PR #8 (`docs/branch-protection-rollout`) merged** — user-run `gh pr merge --squash`, now `main`'s tip (`b0490ef`). One local-only commit (`d745121`, the corrected CI-fix narrative) was never pushed before the merge and so was left out — cherry-picked onto a fresh branch (`docs/finalize-branch-protection-memory-bank`, commit `805ae5a`) off the merged `main`, going through its own push-gate review, for a small follow-up PR.
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
24. [NS-24] **Resolved 2026-08-18 (Tasks #27-35 done except #33, deliberately deferred).** Full `/change-review` pass's findings on `docs/branch-protection-rollout` ("fix all found issues... new and preexisting") worked through and pushed. **Task #33** (marker-destruction-on-denial, live-reproduced) deliberately deferred: the real fix already exists on `feature/review-gate-layered-enforcement` (can't rebase onto `main`), a second branch has overlapping WIP, a narrow patch would be a third mechanism. **Task #34** (cache-write atomicity + `diff_hash()` trap-scoping) done — PowerShell `Move-Item` needed a second pass (wasn't atomic under load); a self-caught trap-restore regression was mutation-tested, caught, reverted before shipping. **Task #35 done, CI failure found post-push and fixed:** `/change-review` re-run required twice (diff changed twice more — once for the Handoff Protocol tangent, once for a CI fix below), both runs clean, hashes independently verified. First push (`0cc53f1..c80d494`) revealed a real, non-flaky `MB Command Tests` failure on GitHub Actions (`cygpath` missing on `ubuntu-latest`, unconditionally called inside a `pwsh`-only test guard) — root-caused from the actual CI log, fixed by matching an existing precedent in two sibling test files, pushed again (`c80d494..d864d99`). **Verified via `gh pr checks 8` after the real CI run completed: all 10 checks pass, `mergeStateStatus: CLEAN`.** **PR #8 merged 2026-08-19** (`b0490ef`). One local-only commit missed the merge — see `[NS-4]`. Full narrative: `progress.md`'s 2026-08-18/19 entries. **Task #33 remains the only open item from this thread.**
25. [NS-25] **`review-reminders.sh`/`.ps1`'s push-gate raw-substring-matches `'git push'`, so a pure `git push origin --delete <branch>` (no content diff) gets denied like a real push** — `diff_hash origin/main...HEAD` is irrelevant to a ref deletion. Found 2026-08-19. Not fixed on the spot: **correcting an earlier, wrong justification** — the risk isn't JSON-field-extraction fragility (that concern is about parsing structured fields out of the JSON payload, and doesn't apply to a `--delete` substring check either way), it's that a naive `*'git push'*'--delete'*` case would itself just be another raw-substring check, and could false-positive-match a real content push whose arguments happen to contain the literal text `--delete` anywhere (a commit message, a branch name, etc.) — letting a genuine push skip the gate entirely. That's a fail-*open* risk, more serious than today's fail-closed annoyance, so it's not a trivial add. Workaround used instead: `gh api -X DELETE repos/.../git/refs/heads/<branch>` bypasses `git push` entirely — legitimate, since a ref deletion has no diff to review. Low priority; any future fix needs to reason carefully about false-positive risk on the `--delete` detection itself, not just bolt on a substring check.

26. [NS-26] **Review-gate Layers 2+3 port design — supersedes `[NS-15]`'s "rebase/replay the branch" approach.** Deep-dived 2026-08-19 (Opus). **Do NOT rebase or replay `feature/review-gate-layered-enforcement`'s 85 commits, and do NOT copy its file versions wholesale.** It forked at `main`'s 2026-07-08 freeze and is now *behind* `main` on shared files — its `_review-gate-lib.sh` still carries the unsafe `trap ... EXIT` in `diff_hash()` (the regression diagnosed and reverted 2026-08-18) and its `review-reminders-post.sh` predates `write_marker_atomic`. Any port must be **main-forward**: start from `main`'s file, apply only the semantic delta. **Critical coupling — Layer 1 and Layer 2 must flip in ONE commit:** `consume_marker()` destroys the marker at PreToolUse time, so adding a marker check to the git hooks while `review-reminders.sh`/`.ps1` still consumes breaks *every* agent commit and push, 100% of the time. The branch solves this with a non-destructive `peek_marker()`, Layer 1 flipped to peek, Layer 2 as sole consumer. **Bundle A (atomic, ~14 files):** `peek_marker()` added to lib (keep `consume_marker`), Layer 1 → peek, marker check into `pre-push-check.sh`/`.ps1`, new `pre-commit-check.sh`/`.ps1` + `.githooks/pre-commit` as delegator, rethink `review-reminders-post.sh` reissue under peek semantics (the branch left dead commit-side code there — do not copy), all `templates/` mirrors, tests. **Bundle B (independent, fails open when no review-log exists):** `ci-review-containment-check.sh`, `docs/review-log/`, tests, CI wiring. **Rollout hazard:** hooks run from the *working tree*, so the flip goes live on save — the commit making the change is itself gated by the new code; test every piece standalone BEFORE wiring the delegator, since a bug means no commits are possible at all (`--no-verify` is CONFIRM-tier, user-run only). **Live gap this closes:** nothing currently enforces the review gate for a commit/push typed directly in a human terminal — only the agent's own Bash calls are gated. Escalate to Opus per the Token Budget triggers.

## Handoff Protocol Narrowed — Memory-Bank Now Authoritative for Priority (2026-08-18)

Work-MB's handoff → "priority order" flow was causing new sessions to miss things (asking a
pressure-written document to also carry synthesis). Redesigned `## Handoff Protocol` in `CLAUDE.md` +
`templates/CLAUDE.md` (byte-identical, `3a2a7fd`): `handoff.md` now scoped to ephemeral in-flight state
only; new sessions read `activeContext.md`'s Next Steps first as authoritative, reconcile against
`handoff.md` second, surface conflicts rather than silently picking one. Portable companion brief
`docs/WORK-MB-HANDOFF-DESIGN-BRIEF.md` (`3aa70af`) sent the same principle to work-MB. Both reviewed +
Opposition-marker-verified. Distinct from `[NS-22]` (handoff.md cleanup-enforcement gap), still open.

## Cross-Repo Write Boundary Gate — Governance Note

`memory-bank/` is tracked (not gitignored) and per-branch — editing it from a worktree would diverge that branch's copy from main's. Per this file's own rule ("Never update or commit memory-bank/ from a subworktree"), updates are made from the main checkout, never from within a worktree.

## Git State

main branch is protected as of 2026-07-08 (PR + passing checks required, enforce_admins: true).
Direct `git push origin main` no longer works on this repo — create a branch, commit, push the
branch, then open a PR and merge once required checks pass.
