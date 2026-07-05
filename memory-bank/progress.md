---
authority: accumulating
review-cycle: 30d
retention: archive-after-6m
staleness-threshold: 90d
tags:
  - work/completed
  - work/in-progress
  - work/backlog
last-reviewed: 2026-07-04
compaction_generation: 0
source_type: canonical
confidence: high
lineage: []
---

# Progress

## Status: Ready

Personal fork of the enterprise Memory Bank standard — lifecycle management and provenance tracking implemented.

## What's In This Fork

- ✅ Memory Bank system (5-file + handoff protocol) + authority hierarchy + 3-dimension frontmatter
- ✅ Provenance frontmatter: compaction_generation, source_type, confidence, lineage
- ✅ Security Guardrails (BLOCK/CONFIRM/WARN) + 9-rule registry (SECURITY-RULES.md) + 9 security fixtures
- ✅ Code Quality, Logging, 7-phase Workflow standards; Supply Chain, MCP Security, Rules-File Integrity (reference)
- ✅ Slash commands: /pmb-status, /code-review, /feature-dev, /security-review, /test-audit, /health-check, /mb-drift, /change-review
- ✅ mb CLI: init, status, doctor (24 checks), query, clean, commit, upgrade, verify-integrity, plan (status/list/promote/archive) + deprecated aliases
- ✅ Hook suite: dangerous-commands blocker, contract scope check, delegation depth check, auto-last-reviewed, PreCompact memory gate
- ✅ Versioned git hooks via core.hooksPath (.githooks/pre-push + pre-commit), distributed by mb upgrade (TEMPLATE_OWNED)
- ✅ mb upgrade: TEMPLATE_OWNED/ADVISORY_DIFF distribution model; remote version check
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

## 2026-06-22 — PMB Infrastructure + /change-review

- ✅ `.claude/plans/` gitignored; `docs/plans/` + `docs/archive/plans/` scaffolded with README
- ✅ `templates/plan.md` updated with YAML frontmatter (status/created/approved/scope/risk/source)
- ✅ `mb plan status|list|promote|archive` added to `mb.sh` and `mb.ps1`
- ✅ `mb doctor` check 24 — plan hygiene (folder existence, tracked drafts, missing frontmatter, stale plans)
- ✅ `standards/WORKFLOW.md` + `/feature-dev` Phase 3 updated: draft to `.claude/plans/`, promote to `docs/plans/`
- ✅ `/change-review` command — 9-job change package review with optional ACR bridge

## 2026-06-19 — Semantic Drift Detection

- ✅ Checks 21–23 added to `mb doctor`: git-vs-reviewed lag, completed-but-still-planned, stale next step
- ✅ `/mb-drift` skill created — on-demand semantic analysis for duplicate concepts, supersession rot, authority violations
- ✅ `QUICK-REFERENCE.md` updated: 23-check doctor, `/mb-drift` skill listed

## 2026-06-19 — Startup Context Trim + Satellite Sync

- ✅ `progress.md` trimmed from 11.6 KB to target ~4 KB; session history collapsed to pointer at CHANGELOG.md
- ✅ Ran `mb upgrade` on all downstream satellite projects to distribute v1.1.1 template changes
- ✅ Re-ran `mb doctor` to refresh checksums after direct edits; startup context confirmed below 25 KB threshold

## 2026-06-24 — Comprehensive Audit + Remediation Sprint

**PMB WS1 — Bug fixes (v1.1.2):**
- ✅ `settings.json` invalid JSON (missing comma) fixed
- ✅ `pre-compact-check` false positives fixed (date anchored to line start)
- ✅ Missing TRUNCATE TABLE + DELETE FROM guardrails added to both shells + templates
- ✅ Template pre-compact whitespace trimming synced

**PMB WS2 — Test coverage (v1.2.0):**
- ✅ 8 new test files; 115 assertions across 11 suites; all mb commands now covered
- ✅ Doctor test check-13 fixture rename hardened; check-2 templates rename hardened

**PMB WS3 — CI hardening:**
- ✅ `powershell-lint` job: PSScriptAnalyzer at Error severity on all .ps1 files
- ✅ `mb-doctor-self-check` job: runs mb doctor on PMB repo on every push
- ✅ Total: 9 CI jobs

**PMB WS4 — Performance + docs:**
- ✅ O(n²) pre-cache in doctor checks 22+23 (sh + ps1)
- ✅ `find | xargs wc` → `find -exec wc {} +` in show_budget
- ✅ `mb help` + `mb.ps1 Show-Help` deprecated aliases section; ps1 gains plan/preflight/change-check
- ✅ HOOKS-GUIDE section 6: delegation depth hook + .pmb-delegation-depth runtime file
- ✅ health-check.md: 20→24 check count

**ACR — P0 + P1 + P2:**
- ✅ P0: comment marker versioned, provider validation, README 15-agent count, Prettier CI
- ✅ P1 partial: orchestrator deterministic-source guard, sanitizer JSON metadata, command docs
- ✅ P1 deferred (confirmed already in v1.1.0): policy layer, SARIF, GitHub annotations, agentPolicy docs
- ✅ P2: schemaVersion/toolVersion/profile in ReviewResult + integration contract docs

## Satellite Projects

- **ai-code-review-agent** — `unyieldingclaw-dev/ai-code-review-agent`. v1.1.0: 15 observe-only agents, profiles, --context memory-bank, SARIF, GitHub annotations, agentPolicy, integration contract. 276 tests passing.

## `mb upgrade` Standards Ownership Fix (2026-07-02)

- ✅ Root cause: `standards/*.md` (15 files) were in `$advisoryCreate` — create-if-missing, diff-only-if-different. Standards are pure governance substrate (no per-project customization), so projects silently fell behind template updates instead of auto-syncing.
- ✅ Fix: moved all 15 `standards/` entries from `$advisoryCreate` to `$templateOwned` in `scripts/mb.ps1` (`Invoke-Upgrade`) — now overwritten unconditionally on hash mismatch, same as `.claude/settings.json` and `.githooks/*`.
- ✅ `$advisoryCreate` kept as `@()` for future files that legitimately need create-if-missing + diff-if-customized semantics.
- ✅ README.md corrected: 12 → 15 standards files; overwrite semantics documented instead of advisory-diff.
- ✅ 6/6 `mb-setup.Tests.ps1` Pester tests still pass. Committed `a453a5a`, pushed to origin/main.

## `mb upgrade` Slash Command Auto-Discovery Fix (2026-07-02)

- ✅ Root cause: `Invoke-Upgrade`'s `$templateOwned` hardcoded 5 command filenames. `accessibility-review.md` + `change-review.md` shipped in 1.2.0 but were never added to the list, so `mb upgrade` silently skipped them in every existing project. `mb init` and `Get-MbUpgradeAnalysis` already discover commands dynamically from `templates/claude-commands/` — only the actual upgrade-copy logic was stuck on a stale static list.
- ✅ Fix: `Invoke-Upgrade` now appends every file found in `templates/claude-commands/` to `$templateOwned` at runtime (same pattern `mb init` already used). No list to remember to update when a new command ships.
- ✅ Verified via dry-run + live run against `rfx-cook-tracker`: both missing commands added, existing ones reported unchanged. Committed `465d5d1`, pushed to origin/main.

## Template Docs Scaffolding Gap Fix (2026-07-04) — v1.2.1

- ✅ `templates/docs/` (referenced by CLAUDE.md, never scaffolded) added + wired into init/upgrade. Full detail: CHANGELOG.md.
- ⏳ Downstream `mb upgrade` reruns pending. 📝 Debt: `mb.sh` command list still stale (see CHANGELOG).
- ⚠️ Side effect discovered during verification: running `mb upgrade` for real on a project several versions behind syncs *all* of `$templateOwned`, not just commands — surprised the user mid-session since `rfx-cook-tracker` was behind on cursor rules/settings/standards too. Not a bug, but worth stating explicitly when asking a user to approve running `mb upgrade` on a stale project: it's an all-or-nothing sync of the owned-file set, not a single-file patch.
