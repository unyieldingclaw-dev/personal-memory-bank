---
authority: accumulating
review-cycle: 30d
retention: archive-after-6m
staleness-threshold: 90d
tags:
  - work/completed
  - work/in-progress
  - work/backlog
last-reviewed: 2026-06-06
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

### Consistency Corrections & Tooling (May–June 2026)
- ✅ v1.0.1: first formally tagged GitHub release (four consistency corrections from architecture review)
- ✅ mb doctor Check #10: template residue detection — lexical patterns only
- ✅ mb doctor: identity boundary in function header — "observable integrity signals, not semantic correctness"
- ✅ v1.0.2: /test-audit command + /health-check (PMB-only); COMMANDS-REFERENCE.md; mb upgrade includes test-audit; README badge fixed
- ✅ PreCompact memory gate: pre-compact-check.ps1/.sh + settings.json hook + HOOKS-GUIDE.md documentation (2026-05-28)
- ✅ Pre-push hook: pre-push-check.ps1/.sh (7 checks) + templates/hooks/pre-push shim + mb init/upgrade/doctor wiring (2026-05-29)
- ✅ mb install-hooks: retrofit subcommand for existing projects; dry-run support (2026-05-29)
- ✅ Standards distribution: templates/standards/ (12 files) + mb init loop + mb upgrade ADVISORY_CREATE category (2026-05-29)
- ✅ .pmb-version tracking: written by mb init and mb upgrade; mb doctor check 12 (2026-05-29)
- ✅ Remote version check in mb upgrade: soft non-blocking curl/Invoke-WebRequest; skips offline (2026-05-29)
- ✅ mb doctor checks 11 (required standards) and 12 (.pmb-version) in bash + PowerShell (2026-05-29)
- ✅ v1.0.3: VERSION, CHANGELOG, README, COMMANDS-REFERENCE all updated (2026-05-29)

### Command Consolidation + Semantic Intelligence — v1.0.8 (2026-06-06)
- ✅ **Command surface finalized** — 8 active commands (init, status, doctor, query, clean, commit, upgrade, verify-integrity); deprecated aliases clarified; `mb clean` references fixed throughout
- ✅ **mb.sh parity** — checks 15 (startup context ceiling) and 16 (hook error log) added to mb.sh (were PowerShell-only)
- ✅ **Check 17 — Semantic drift detection** — heuristic scan of volatile files for transition/removal keywords; flags lines for human review against stable files
- ✅ **Check 18 — Old stable decisions** — flags authority:stable files not reviewed in >180 days
- ✅ **Check 19 — Cross-file contradiction** — detects authority hierarchy violations and negation language under shared `##` headings
- ✅ **Check 20 + mb verify-integrity** — SHA-256 checksums for all 5 memory-bank files; stored in `.pmb-checksums` (gitignored); reports external modifications as ERROR; refreshed on every mb doctor run
- ✅ **Compaction quality gate** — pre-compact-check.ps1/.sh now exits 2 (blocks) unless: activeContext.md has ≥3 substantive lines AND progress.md has today's date; handoff.md bypasses
- ✅ **Agent delegation depth** — delegation-depth-check.ps1/.sh; PreToolUse hook on Agent tool in settings.json; WARN when depth >1; session temp file `.pmb-delegation-depth` (gitignored, resets 2h)
- ✅ **standards/AGENTIC-SAFETY.md** — "Agent Delegation Depth Enforcement" section added
- ✅ **Templating** — pre-compact-check, delegation-depth-check scripts mirrored to templates/scripts/; settings.json and AGENTIC-SAFETY.md mirrored to templates/
- ✅ **mb init/upgrade** — delegation-depth-check scripts added to init allowlist and upgrade TEMPLATE_OWNED
- ✅ **docs/COMMANDS-REFERENCE.md** — updated to 20-check table; verify-integrity command added
- ✅ **CHANGELOG.md + VERSION** — bumped to v1.0.8

### Guardrails Batch — G1–G6 (2026-06-06)
- ✅ **G1** — dangerous-commands hook extended to PowerShell tool; 8 PS-native BLOCK patterns added (Remove-Item -Recurse -Force, Format-Volume, pipe-to-iex/Invoke-Expression); both settings.json files updated
- ✅ **G2** — hook failure alerting: all 4 hook scripts (dangerous-commands, check-contract, pre-compact-check, update-reviewed) log errors to `.pmb-hook-errors.log`; mb doctor Check 16 reports log presence; mb init now adds `.pmb-hook-errors.log` to .gitignore
- ✅ **G3** — `PMB_CONTRACT_HARD_BLOCK=1` env var promotes contract scope warnings to blocks (exit 2); documented in `standards/SECURITY-GUARDRAILS.md`; both .ps1 and .sh scripts updated
- ✅ **G4** — pre-push secret scan fixed for first push: when no upstream tracking ref, `git log --not --remotes -p` scans all commits not on any remote; Check 6 (large files) fixed in parallel; all 4 pre-push-check files updated
- ✅ **G5** — `rules-file-integrity` CI job added to pmb-health.yml: invisible Unicode, HTML comments, LLM bypass phrases in CLAUDE.md/standards/
- ✅ **G6** — `sast` CI job added to pmb-health.yml: Semgrep `p/bash` ruleset scanning scripts/ and templates/scripts/
- ✅ **Housekeeping** — merged two handoff.md files; added `.pmb-version`; mb doctor Check 15 (startup context size ceiling: WARN >15 KB, ERROR >25 KB)

### Code Review Standard — v1.0.6 (2026-06-03)
- ✅ `Confidence: High|Medium|Low` replaced by `Basis: VERIFIED|INFERRED|SPECULATIVE` in `standards/CODE-REVIEW.md`, `templates/standards/CODE-REVIEW.md`, both `code-review.md` command files
- ✅ Evidence requirements explicit per-basis: file:line required; SPECULATIVE must cite observed trigger + explicit uncertainty statement
- ✅ Blocking constraint: `Blocking: true` requires `Severity >= High AND Basis != SPECULATIVE`
- ✅ Report sections: `## Supported Findings` (VERIFIED+INFERRED, with [VERIFIED]/[INFERRED] prefix) + `## Predicted Risks` (SPECULATIVE, omit if empty)
- ✅ Three new Failure Criteria added (file:line, evidence materially supports claim, SPECULATIVE/Blocking)
- ✅ Compatibility Note documents breaking `Confidence` → `Basis` rename

### `/pmb-status` + `mb status` Redesign — v1.0.5 (2026-06-03)
- ✅ `mb status` reworked: 5-signal state check replacing file-size table (Initialized, Core Memory Present, Active Context Current, Standards Available, Tasks Present)
- ✅ `/pmb-status` slash command: thin wrapper over `mb status`; CLI owns logic, no duplication
- ✅ Distributed via `mb init` and `mb upgrade`; `templates/claude-commands/pmb-status.md` added
- ✅ Code review hardening: `sed 's/d$//'` trailing anchor, `$STALE_DAYS` numeric guard, `REVIEWED_EPOCH=0` parse-failure path, `compgen -G` replacing `ls|head`
- ✅ All docs updated: README, QUICK-REFERENCE, RECOVERY, SETUP-GUIDE, COMMANDS-REFERENCE, CHANGELOG

### Security & Performance Improvements — v1.0.4 (2026-06-01)
- ✅ `standards/SECURITY-RULES.md` — rule registry SEC-001–009; distributed via mb init/upgrade (ADVISORY_CREATE)
- ✅ `standards/TRUST-CLASSIFICATION.md` — TRUSTED/SEMI_TRUSTED/UNTRUSTED reference; pointers in AGENTIC-SAFETY + SECURITY-GUARDRAILS
- ✅ `standards/PERFORMANCE-BUDGET.md` — explicit limits for standards count, memory entries, agent delegation depth
- ✅ `fixtures/security/` — 9 known-bad code samples for security regression testing (PMB dogfooding only)
- ✅ Structured finding format: Rule ID + Evidence + Confidence + Fix in security-review command and agent
- ✅ Trust level note in security-reviewer agent (prompt-injection/rules-file-integrity findings)
- ✅ mb doctor Check 13 (fixtures structure) and Check 14 (standards count ≤20) — now 14 checks total
- ✅ /health-check step 5: security fixture verification (caught/missed per rule ID)
- ✅ Pre-push hook: fixtures/ and docs/ excluded from secret scan (known-bad code + docs quoting it)
- ✅ All 3 new standards in templates/standards/ for distribution

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

## Satellite Projects

- **ai-code-review-agent** (2026-06-04) — standalone GitHub Actions CI reviewer; repo `unyieldingclaw-dev/ai-code-review-agent` (private). LLM reviewer + verifier agents, finding cap, GITHUB_STEP_SUMMARY. Status: built and pushed, pending calibration PR validation.
