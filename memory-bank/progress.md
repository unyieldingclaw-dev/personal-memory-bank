---
authority: accumulating
review-cycle: 30d
retention: archive-after-6m
staleness-threshold: 90d
tags:
  - work/completed
  - work/in-progress
  - work/backlog
last-reviewed: 2026-05-28
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
- ✅ /code-review, /feature-dev, /security-review, /test-audit commands (all distributed via mb init)
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

### Consistency Corrections & Tooling (May 2026)
- ✅ v1.0.1: first formally tagged GitHub release (four consistency corrections from architecture review)
- ✅ mb doctor Check #10: template residue detection — lexical patterns only
- ✅ mb doctor: identity boundary in function header — "observable integrity signals, not semantic correctness"
- ✅ v1.0.2: /test-audit command + /health-check (PMB-only); COMMANDS-REFERENCE.md; mb upgrade includes test-audit; README badge fixed
- ✅ PreCompact memory gate: pre-compact-check.ps1/.sh + settings.json hook + HOOKS-GUIDE.md documentation (2026-05-28)
- ✅ Pre-push hook: pre-push-check.ps1/.sh (7 checks) + templates/hooks/pre-push shim + mb init/upgrade/doctor wiring (2026-05-29)
- ✅ mb install-hooks: retrofit subcommand for existing projects; dry-run support (2026-05-29)
- ⏸ Deferred pending operational evidence: handoff CLI, pinned.md, mb update --from-git, mb privacy

## Removed vs Enterprise

- ❌ Eric Nolan branding and brand assets
- ❌ Data Classification, Model Governance, OWASP LLM Top 10 (compliance only)
- ❌ Incident Runbook, accessibility review command
- ❌ Enterprise logging (PII redaction, correlation IDs)
- ❌ Team onboarding scripts and training materials

## Next Major Gap

**Semantic identity** — the system detects file-level degeneration but not concept-level drift. Duplicate concepts, contradictions, and stale supersession currently require human judgment. Detection-first approach: add heuristics before any auto-remediation.
