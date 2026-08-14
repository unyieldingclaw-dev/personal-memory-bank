---
authority: accumulating
review-cycle: 30d
retention: archive-after-6m
staleness-threshold: 90d
tags:
  - work/completed
  - work/in-progress
  - work/backlog
last-reviewed: 2026-08-14
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
- 📌 Not yet committed. Not yet applied to an actual implementation plan in practice (the review-gate plan below was reviewed *before* this mechanism formally existed — it's the incident that motivated the mechanism, not an example of the mechanism already running).

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
