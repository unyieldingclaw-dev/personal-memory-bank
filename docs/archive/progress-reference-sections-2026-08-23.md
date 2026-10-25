# Archived Reference Sections from `memory-bank/progress.md`

**Relocated 2026-08-23.** Verbatim — no condensation, no summarization, nothing rewritten.

## Why these moved

`progress.md` reached 400/400 lines, the hard CI fail threshold in
`.github/workflows/pmb-health.yml`, and could not record a new entry.

The four sections below are **project description, not progress** — a feature inventory, a
scope-delta note, a condensed pointer to `CHANGELOG.md`, and a satellite-project pointer. They sat
in the accumulating tier by misfiling, not because the tier was doing its job. None had a live
citation anywhere in the repo (the only `grep` hits were worktree copies belonging to other
branches), so relocating them cost no cross-references.

A chronological archive pass was considered first and **rejected on evidence**: every large dated
section in `progress.md` is cited by a live `[NS-N]` entry in `activeContext.md`, so evicting one
forces citation rewrites into a second capped file that has ~25 lines of headroom itself. The only
uncited dated section was 2026-08-22 — the current branch's own work, the worst possible choice.

`## Backlog` was deliberately **left in `progress.md`**: it lists genuinely actionable deferred work.

## What this does not resolve

Net recovery was ~31 lines. That is a **one-time recovery, not a fix.** The growth-vs-eviction
asymmetry identified in `[NS-35]` is untouched, and decision 3 there (entry lifecycle, deterministic
merge/prune, per ACE) remains open — deliberately not settled under a cap deadline. Relocation was
chosen partly *because* it is not a rewrite: the ACE brevity-bias failure mode that
`docs/MEMORY-BANK-PARADIGM-REVIEW.md` diagnoses requires a summarization step, and this has none.

Separately, `[NS-28]` already established that the 400-line cap measures the wrong dimension and
that the byte cap is the correct metric — `progress.md` was at 39,539 bytes against a 60,000 fail
threshold, so bytes were never the binding constraint. Re-baselining the line cap was therefore
arguable, and was **declined for now**: changing a guardrail while blocked by it is the
user-as-bypass shape. The argument is recorded here rather than acted on.

---

## What's In This Fork

Status: Ready. Personal fork of the enterprise Memory Bank standard — lifecycle management and provenance tracking implemented.

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

Eric Nolan branding/brand assets; Data Classification, Model Governance, OWASP LLM Top 10 (compliance only);
Incident Runbook, accessibility review command; enterprise logging (PII redaction, correlation IDs);
team onboarding scripts and training materials.

## Earlier Sessions (2026-06-19 to 2026-06-24) — condensed, full detail in CHANGELOG.md

- ✅ **06-19:** Semantic drift checks 21-23 added to `mb doctor`; `/mb-drift` skill created; startup context trimmed to below 25 KB.
- ✅ **06-22:** `docs/plans/` + `.claude/plans/` workflow scaffolded; `mb plan status|list|promote|archive`; doctor check 24 (plan hygiene); `/change-review` command created (9-job review + ACR bridge).
- ✅ **06-24 Audit Sprint:** Bug fixes (settings.json JSON, pre-compact false positives, TRUNCATE/DELETE guardrails); 8 new test files (115 assertions); CI hardened to 9 jobs (PSScriptAnalyzer, mb-doctor-self-check); perf fixes (O(n²) pre-cache); ACR P0/P1/P2 (comment markers, SARIF, GitHub annotations, schemaVersion).

## Satellite Projects

- **ai-code-review-agent** — `unyieldingclaw-dev/ai-code-review-agent`. v1.1.0: 15 observe-only agents, profiles, --context memory-bank, SARIF, GitHub annotations, agentPolicy, integration contract. 276 tests passing.
