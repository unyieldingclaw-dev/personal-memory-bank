---
authority: accumulating
review-cycle: 30d
retention: archive-after-6m
staleness-threshold: 90d
tags:
  - work/completed
  - work/in-progress
  - work/backlog
last-reviewed: 2026-06-11
compaction_generation: 0
source_type: canonical
confidence: high
lineage: []
---

# Progress

## Status: Ready

Personal fork of the enterprise Memory Bank standard — lifecycle management and provenance tracking implemented.

## What's In This Fork

### Core Standards
- ✅ Memory Bank system (5-file + handoff protocol)
- ✅ Security Guardrails (BLOCK/CONFIRM/WARN)
- ✅ Code Quality standard
- ✅ Logging standard (essentials)
- ✅ 7-phase Workflow standard
- ✅ Supply Chain, MCP Security, Rules-File Integrity (reference)
- ✅ /pmb-status, /code-review, /feature-dev, /security-review, /test-audit commands (all distributed via mb init)
- ✅ /health-check command (PMB-only self-diagnostic)
- ✅ docs/COMMANDS-REFERENCE.md — full reference for all mb + slash commands
- ✅ Cursor rules (5 rules + code-review rule)

### Lifecycle Management (May 2026)
- ✅ Authority hierarchy: immutable > stable > volatile > accumulating
- ✅ 3-dimension frontmatter: review-cycle, retention, staleness-threshold
- ✅ Hierarchical tags (domain/concept format)
- ✅ Automated last-reviewed via PostToolUse hook (update-reviewed.ps1 / .sh)
- ✅ Partitioned archive: docs/archive/context/, progress/, decisions/
- ✅ mb audit, mb query, mb compact commands
- ✅ Worktree guard in mb commit

### Token Budget (May 2026)
- ✅ CLAUDE_AUTOCOMPACT_PCT_OVERRIDE=40 in settings.json (lowered from 50)
- ✅ PreCompact hook: memory gate warns before compaction if memory bank stale and no handoff.md
- ✅ mb budget: KB + token estimates
- ✅ mb doctor: CLAUDE.md drift detection
- ✅ Auto-clarity exception documented

### Provenance & Integrity (May 2026)
- ✅ Provenance frontmatter: compaction_generation, source_type, confidence, lineage
- ✅ mb doctor section 8: compaction depth warning (WARN at gen ≥ 2) + canonical-source absence (ERROR)
- ✅ Additive lineage chains (non-replacement)
- ✅ Field orthogonality documented (source_type ≠ compaction_generation ≠ authority)

### Usability & Adoption (May 2026)
- ✅ mb init, mb validate commands
- ✅ install.bat / install.sh scripts
- ✅ docs/RECOVERY.md, docs/UPGRADE.md
- ✅ examples/task-tracker-api (full working example)
- ✅ VERSION, CHANGELOG.md

### Governance & Observability (May 2026)
- ✅ Governance integrity: hook scripts in templates, mb doctor Check #4, CI template-integrity job (PR #3)
- ✅ Code quality provenance: CODE-QUALITY.md sections 2+7, CLAUDE.md anchors, Cursor rule anchor (PR #2)
- ✅ mb upgrade subcommand: TEMPLATE_OWNED/ADVISORY_DIFF model (PR #4)
- ✅ mb doctor Check #9: staleness summary (volatile/stable breakdown)
- ✅ mb doctor Startup Context section: token visibility, growth rate, stale-but-loaded
- ✅ CLAUDE.md memory update discipline: task-boundary updates, compaction summaries are fallback
- ✅ .gitignore: .claude/worktrees/ excluded

### v1.0.1–v1.0.3 — Consistency Corrections & Tooling (May–June 2026)
- ✅ v1.0.1–1.0.3: architecture review corrections; mb doctor checks 10–12 (template residue, required standards, .pmb-version); PreCompact memory gate (pre-compact-check.ps1/.sh); pre-push hook (7 checks, pre-push-check.ps1/.sh); mb install-hooks; standards distribution (12 files via ADVISORY_CREATE); remote version check in mb upgrade; /test-audit + /health-check commands; COMMANDS-REFERENCE.md

### v1.0.8 — Command Consolidation + Semantic Intelligence (2026-06-06)
- ✅ mb command surface finalized: 8 active commands; mb.sh/mb.ps1 parity; mb doctor expanded to 20 checks (17: semantic drift, 18: stale stable decisions, 19: cross-file contradiction, 20: SHA-256 via `mb verify-integrity`); compaction quality gate blocks unless memory bank captured (exits 2); agent delegation depth hook (WARN depth>1); AGENTIC-SAFETY.md updated; all scripts templated

### Branch Cleanup Session (2026-06-12)
- ✅ Reviewed all stale local branches (6) and remote branches (4) post-v1.1.0 commit
- ✅ Removed two orphaned worktrees (`.claude/worktrees/`), deleted their branches
- ✅ Rescued Bowling Tracker enforcement plan from unmerged branch `claude/memory-bank-upgrade-logic-28kmkn` — preserved in master via manual edit
- ✅ Deleted remote branches: `feat/comment-provenance`, `feat/governance-integrity`, `feat/mb-upgrade`, `feat/mb-doctor-staleness`, `claude/memory-bank-upgrade-logic-28kmkn` (all content merged or preserved)
- ✅ `git fetch --prune` cleaned stale remote-tracking refs for 3 already-deleted remotes

### Git Hooks Migration — v1.1.0 (2026-06-11)
- ✅ **`core.hooksPath = .githooks`** — hooks now versioned in project repo, not copied to `.git/hooks/`; distributed via `mb upgrade` TEMPLATE_OWNED
- ✅ **`templates/.githooks/pre-push`** and **`templates/.githooks/pre-commit`** created
- ✅ **`mb init`** updated (bash + PowerShell): creates `.githooks/` dir, copies both hooks, sets `git config core.hooksPath .githooks`
- ✅ **`mb upgrade`** updated (bash + PowerShell): TEMPLATE_OWNED entries for both hooks; sets `core.hooksPath`; removes old `.git/hooks/pre-push` PMB shim (migration cleanup)
- ✅ **`mb doctor` check 4** updated (bash + PowerShell): verifies `.githooks/pre-push` + `core.hooksPath` value; bash parity (was PowerShell-only)
- ✅ **Pre-commit hook activated**: existed in PMB repo but was dead; now fires (`git config core.hooksPath .githooks` run in PMB repo)
- ✅ **`docs/HOOKS-GUIDE.md`**: new "Git Hooks (versioned)" section — mechanism, hook inventory, TEMPLATE_OWNED model, migration notes, verification commands
- ✅ **`README.md`**: pre-push `<details>` block updated; version badge 1.0.9 → 1.1.0
- ✅ **Breaking change**: projects must run `mb upgrade` to activate new layout; old `.git/hooks/pre-push` shim removed automatically

### Satellite Project Fixes + Hook Performance Plan (2026-06-10)
- ✅ **BT CLAUDE.md — session-start gap** — added "Memory Bank" section telling Claude to read all 5 memory-bank files at conversation start (was missing cold-start instruction; only had compaction recovery)
- ✅ **BT CLAUDE.md — Task Contract Protocol** — added full Task Contract Protocol section; BT had hook infrastructure (check-contract.ps1/.sh) but no advisory layer telling Claude when to propose contracts
- ✅ **Performance fixes design doc** — audited check-contract.sh (4 Python spawns + sed), pre-compact-check.sh (sed-in-loop), mb.sh check 10 (70 grep calls), mb.sh check 17 (400 subshell greps); design doc written at `docs/superpowers/specs/2026-06-10-pmb-performance-fixes-design.md`
- ✅ **Performance fixes implementation plan** — written at `docs/superpowers/plans/2026-06-10-pmb-performance-fixes.md`; 5 tasks with TDD steps and commit checkpoints; ready to execute

### Hook Script Performance Fixes — perf/hook-script-fixes (2026-06-11)
- ✅ **check-contract.sh** — consolidated 3 Python spawns + 6 sed subshells into single Python heredoc invocation (~150–300 ms saved per Write/Edit hook call); branch commit 8c8c740
- ✅ **pre-compact-check.sh** — replaced sed subprocess in per-line loop with bash parameter expansion (~100 processes saved per compaction check); branch commit ee47554
- ✅ **mb.sh check 10** — replaced 7 per-pattern grep calls per file with one combined grep per file (35 → 5–10 total grep calls); branch commit 54c8e26
- ✅ **mb.sh check 17** — replaced per-line echo|grep loop (~400 subshell greps) with grep -inE directly on file (2 calls total); branch commit 17508d8

### Guardrails Batch — G1–G6 (2026-06-06)
- ✅ G1: PS dangerous-commands patterns; G2: hook failure log (`.pmb-hook-errors.log`) + Check 16; G3: `PMB_CONTRACT_HARD_BLOCK=1` hard-block mode; G4: pre-push first-push secret scan fix; G5: CI rules-file-integrity job (invisible Unicode, HTML comments, bypass phrases); G6: CI SAST (Semgrep p/bash); Check 15: startup context ceiling (WARN >15 KB, ERROR >25 KB)

### Code Review Standard — v1.0.6 (2026-06-03)
- ✅ `Confidence` → `Basis: VERIFIED|INFERRED|SPECULATIVE` rename; per-basis evidence requirements (file:line required); blocking constraint (Severity≥High + Basis≠SPECULATIVE); report split into Supported Findings + Predicted Risks; breaking change documented

### `/pmb-status` + `mb status` Redesign — v1.0.5 (2026-06-03)
- ✅ `mb status` reworked to 5-signal state check; `/pmb-status` as thin CLI wrapper; code review shell hardening fixes; all docs updated (README, QUICK-REFERENCE, RECOVERY, SETUP-GUIDE, COMMANDS-REFERENCE)

### Security & Performance Improvements — v1.0.4 (2026-06-01)
- ✅ SEC-001–009 rule registry (SECURITY-RULES.md); TRUST-CLASSIFICATION.md; PERFORMANCE-BUDGET.md; 9 security fixtures in `fixtures/security/`; structured finding format (Rule ID + Evidence + Basis + Fix); mb doctor checks 13–14; /health-check step 5; pre-push fixtures/docs exclusion from secret scan; all 3 standards distributed via templates/

## Removed vs Enterprise

- ❌ Eric Nolan branding and brand assets
- ❌ Data Classification, Model Governance, OWASP LLM Top 10 (compliance only)
- ❌ Incident Runbook, accessibility review command
- ❌ Enterprise logging (PII redaction, correlation IDs)
- ❌ Team onboarding scripts and training materials

## Backlog

**Semantic identity** — file-level health is covered; concept-level drift is not. Trigger: memory bank stable and aging (3–6 months), manual contradictions noticed. Detection-first; no auto-remediation.
- ⏸ Duplicate concept detection — same decision in two files drifting apart over compaction cycles
- ⏸ Supersession rot — old decision still looks authoritative after a newer one replaced it
- ⏸ Cross-file contradiction detection — authority hierarchy violations (e.g. activeContext vs projectbrief)
- ⏸ Claim extraction via `mb query` extension — surface semantically near-duplicate content; bounded scope, no new command needed

**Deferred pending operational evidence:**
- ⏸ handoff CLI, pinned.md, mb update --from-git, mb privacy

### mb.ps1 `diff -u` Windows Bug Fix (2026-06-12, complete)
- ✅ **Root cause**: PowerShell aliases `diff` → `Compare-Object`; `& diff -u $src $target` called `Compare-Object -u`, failing with "parameter not found"
- ✅ **Fix**: replaced both advisory-diff blocks (~lines 1628, 1667) with `@(git diff --no-index --unified=3 -- $src $target 2>$null)` + 20-line truncation guard; no `Get-Command diff` check needed

### Cross-Project PreCompact + v1.1.0 Audit (2026-06-12, complete)
- ✅ Scanned all 6 downstream projects for PreCompact hook + v1.1.0 git hooks
- ✅ **Bowling-Tracker** — already had PreCompact + v1.1.0 hooks (confirmed, no action needed)
- ✅ **Google-Organizer** — `mb upgrade` run; PreCompact hook added, delegation-depth added, AUTOCOMPACT 50→40, v1.1.0 git hooks installed
- ✅ **GrillTimer** — `mb upgrade` run; same as Google-Organizer
- ✅ **Nolan-Budget** — `mb upgrade` run; custom npm permissions (dev/build/preview/install) restored after TEMPLATE_OWNED overwrite
- ✅ **rfx-cook-tracker** — manual patch (no mb upgrade — custom hook structure); PreCompact hook added pointing to `.claude/hooks/pre-compact-check.sh`; AUTOCOMPACT 50→40 fixed; `pre-compact-check.sh` created in `.claude/hooks/`
- ✅ **AI-Code-Review-Agent** — `mb upgrade` run; `.githooks/pre-push` added (pre-commit + `core.hooksPath` were already present); custom `Stop` hook + `permissions.allow` survived TEMPLATE_OWNED overwrite intact

### Bowling Tracker — Memory Bank Enforcement (2026-06-12, complete)
- ✅ `CLAUDE.md` has Memory Bank section + sprint-completion rule + compaction recovery (was already present)
- ✅ `scripts/pre-compact-check.sh/.ps1` present in BT (was already deployed)
- ✅ PreCompact hook wired in BT `.claude/settings.json` (was already present)
- ✅ `mb upgrade` run in BT: v1.1.0 hooks installed (`.githooks/pre-push`, `.githooks/pre-commit`, `core.hooksPath = .githooks`; old `.git/hooks/pre-push` shim removed)

## Satellite Projects

- **ai-code-review-agent** (2026-06-04) — standalone GitHub Actions CI reviewer; repo `unyieldingclaw-dev/ai-code-review-agent` (private). LLM reviewer + verifier agents, finding cap, GITHUB_STEP_SUMMARY. Status: built and pushed, pending calibration PR validation.
