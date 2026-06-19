---
authority: accumulating
review-cycle: 30d
retention: archive-after-6m
staleness-threshold: 90d
tags:
  - work/completed
  - work/in-progress
  - work/backlog
last-reviewed: 2026-06-12
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

### PMB Commands Audit (2026-06-18)
- ✅ 6-lens parallel audit completed: hook wiring, mb commands, slash commands, gaps/overstepping, session-start/handoff flow, template parity
- ✅ 58 findings documented in `docs/superpowers/specs/2026-06-18-mb-commands-audit.md` (2 Critical, 14 High, 19 Medium, 23 Low)
- ✅ Key conclusions: O1 = cumulative vs. nesting mismatch (raise budgetLimit to 6); G1/G2 = detection gap, not creation/cleanup gap (deferred); F7 systemic = platform limitation (no SessionStart hook)
- In progress: implementation plan at `C:\Users\Mizzo\.claude\plans\mb-audit-fixes.md`

### Branch Cleanup Session (2026-06-12)
- ✅ Deleted 6 local + 4 remote stale branches post-v1.1.0; removed 2 orphaned worktrees; rescued BT enforcement plan from unmerged branch; `git fetch --prune` cleaned tracking refs

### Git Hooks Migration — v1.1.0 (2026-06-11)
- ✅ `core.hooksPath = .githooks` — hooks versioned in repo (`templates/.githooks/pre-push` + `pre-commit`), distributed via `mb upgrade` TEMPLATE_OWNED
- ✅ `mb init`, `mb upgrade`, `mb doctor` check 4 all updated (bash + PowerShell); pre-commit hook activated in PMB repo; README badge + CHANGELOG updated
- ✅ **Breaking**: projects must run `mb upgrade`; old `.git/hooks/pre-push` shim removed automatically

### Satellite Project Fixes + Hook Performance Plan (2026-06-10)
- ✅ BT CLAUDE.md: added memory bank session-start section + Task Contract Protocol; performance design + plan written for check-contract.sh/pre-compact-check.sh/mb.sh checks 10+17

### Hook Script Performance Fixes — perf/hook-script-fixes (2026-06-11)
- ✅ check-contract.sh (3 Python spawns → 1 heredoc), pre-compact-check.sh (sed loop → bash expansion), mb.sh check 10 (35 → 7 grep calls), check 17 (400 subshell greps → 2 file greps); ~500 ms saved per hook call

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
- ✅ Replaced `diff -u` (PS alias → Compare-Object) with `git diff --no-index --unified=3` in both upgrade advisory-diff blocks; 20-line truncation guard added

### Cross-Project PreCompact + v1.1.0 Audit (2026-06-12, complete)
- ✅ All 6 downstream projects upgraded: Google-Organizer, GrillTimer, Nolan-Budget, AI-Code-Review-Agent via `mb upgrade`; rfx-cook-tracker manual patch (custom hook structure); Bowling-Tracker already current. All have PreCompact hook + v1.1.0 git hooks + AUTOCOMPACT=40

### Bowling Tracker — Memory Bank Enforcement (2026-06-12, complete)
- ✅ BT confirmed: memory bank session-start + sprint rule + PreCompact hook all present; `mb upgrade` installed v1.1.0 hooks (`core.hooksPath = .githooks`; old shim removed)

### Documentation Audit — All 9 Key Docs (2026-06-12, complete)
- ✅ Audited README, CHANGELOG, COMMANDS-REFERENCE, QUICK-REFERENCE, SETUP-GUIDE, RECOVERY, HOOKS-GUIDE, UPGRADE, CONTRACTS-GUIDE; fixed 4 deprecated `mb compact`→`mb clean` references + 2 stale "75% context"→"40%" references; committed + pushed; GitHub repo description updated to reflect v1.1.0 features

## Satellite Projects

- **ai-code-review-agent** (2026-06-04) — standalone GitHub Actions CI reviewer; repo `unyieldingclaw-dev/ai-code-review-agent` (private). LLM reviewer + verifier agents, finding cap, GITHUB_STEP_SUMMARY. Status: built and pushed, pending calibration PR validation.
