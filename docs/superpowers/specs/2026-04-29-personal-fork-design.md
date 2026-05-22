# Personal Fork Design — Memory Bank

**Date:** 2026-04-29
**Status:** Approved for implementation

---

## Context

This project (Memory Bank) is an enterprise AI coding standard built for Eric Nolan ERE teams. It includes 13 standards, 4 slash commands, branding assets, training materials, GitLab integration, and MCP tools — designed for teams, not individuals.

The goal is to create a **personal fork**: a new standalone repo, stripped of all Eric Nolan-specific and enterprise-compliance-only content, while keeping the highest-value pieces intact (memory bank system, code review, security, feature workflow, code quality).

**Motivation:** The enterprise version carries ~500–700 tokens of session overhead from enterprise hygiene in CLAUDE.md, plus 12+ MB of binary assets, 3 pure-compliance standards, and tooling (GitLab API, Eric Nolan MCP, PowerPoint generation) that has no personal use.

---

## What Is Kept

### Core (always on)
- **Memory Bank system** — 5-file structure (projectbrief, systemPatterns, techContext, activeContext, progress) + handoff protocol
- **CLAUDE.md** — trimmed version (see Modifications section)
- **Security Guardrails** (`standards/SECURITY-GUARDRAILS.md`) — 3-tier BLOCK/CONFIRM/WARN system
- **Code Quality** (`standards/CODE-QUALITY.md`) — verification, comments, structure, Karpathy principles
- **Workflow** (`standards/WORKFLOW.md`) — 7-phase feature development process
- **Language extensions** — `extensions/python.md`, `extensions/typescript.md`, `extensions/logging-python.md`

### Commands (both IDEs)
- `.claude/commands/code-review.md` — full multi-agent code review (security / performance / style / test-coverage / opponent-auditor subagents)
- `.claude/commands/feature-dev.md` — full 7-phase feature dev orchestrator
- `.claude/commands/security-review.md` — lightweight 9-pattern security scan

### Cursor rules
- `memory-bank.mdc`, `security.mdc`, `code-quality.mdc`, `workflow.mdc`, `rules-file-integrity.mdc`

### Reference standards (not auto-loaded; consulted on demand)
- `standards/SUPPLY-CHAIN.md` — slopsquatting, SCA, package validation
- `standards/MCP-SECURITY.md` — MCP credential management and tool-poisoning prevention
- `standards/RULES-FILE-INTEGRITY.md` — anti-prompt-injection for rules files

### Scripts and templates
- `scripts/init-memory-bank.ps1/.sh` — updated to remove Eric Nolan refs
- `scripts/mb.ps1/.sh` — unchanged
- `templates/memory-bank/` — all 5 fillable template files
- `templates/claude-commands/` — 3 commands (code-review, feature-dev, security-review)
- `templates/cursor/rules/` — 5 Cursor rules (see above list)
- `templates/CLAUDE.md`, `templates/AGENTS.md`, `templates/handoff.md`

### Docs
- All 6 docs kept; SETUP-GUIDE.md and QUICK-REFERENCE.md updated to remove Eric Nolan/enterprise refs

---

## What Is Removed

### Binary assets (12+ MB)
- `brand/` — entire directory (Eric Nolan PPTX, logos, extracted assets)
- `memory-bank-overview*.pptx` — both deck files at repo root
- `memory-bank-presentation-summary.md`

### Training
- `training/` — entire directory (HTML presentation, exercises)

### Enterprise-only standards
- `standards/DATA-CLASSIFICATION.md` — 4-tier classification; enterprise compliance only
- `standards/MODEL-GOVERNANCE.md` — approved model lists, version pinning, change management
- `standards/LLM-TOP-10-MAPPING.md` — OWASP audit/compliance mapping

### Enterprise-only templates
- `templates/INCIDENT-RUNBOOK.md`
- `templates/claude-commands/accessibility-review.md`
- `templates/cursor/rules/enterprise-logging.mdc`

### Commands
- `.claude/commands/accessibility-review.md`

### Eric Nolan-specific scripts
- `scripts/build_overview_deck.py`
- `scripts/patch_overview_deck.py`
- `scripts/update_gitlab_description.py`

### Eric Nolan-specific root files
- `GITLAB-DESCRIPTION.md`

---

## What Is Modified

### `CLAUDE.md` (and `templates/CLAUDE.md`)
Replace the "Enterprise Hygiene" section with a lean 3-line block:

```
Secrets: Never hardcode credentials — use env vars or secret managers.
Model: Use the most capable Claude model available for the task.
Agent safety: Don't run destructive commands without user confirmation.
```

All other sections stay: memory bank instructions, context compaction recovery, security guardrails ref, code quality ref, workflow ref, logging ref, handoff protocol, coding principles, quick commands.

### `standards/LOGGING.md` (459 lines → ~70 lines)
**Keep:**
- Use structured log format (JSON or key=value)
- Use log levels: DEBUG, INFO, WARN, ERROR
- Never log secrets, tokens, or credentials
- One Python example, one TypeScript example

**Remove:**
- PII redaction rules and patterns
- Correlation ID requirements
- Enterprise anti-pattern list
- Cross-references to data classification tiers
- Extended language examples

### `.claude/settings.local.json`
**Remove:**
- Hardcoded GitLab API token (security fix — rotate this token before archiving the enterprise repo)
- GitLab Bash allowlist entries (`curl` calls to Eric Nolan GitLab)
- Eric Nolan branding MCP tool entries

**Keep:**
- `git *` permission
- WebFetch/WebSearch for security research domains (OWASP, NIST, MITRE, arXiv, defense.gov)
- Any personal MCP tools (to be added by user as needed)

### `scripts/init-memory-bank.ps1` and `init-memory-bank.sh`
Strip output messages that reference Eric Nolan, GitLab, or branding setup steps. Keep the core directory-creation and template-copy logic unchanged.

### `docs/LOGGING-GUIDE.md`
Trim to match the trimmed `standards/LOGGING.md`. Remove PII redaction walkthroughs, correlation ID setup, and enterprise anti-pattern sections. Keep the structured-format intro, log-level guidance, and the "never log credentials" rule.

### `standards/extensions/logging-python.md`
Trim to match the trimmed logging standard — remove enterprise patterns (PII filters, correlation ID middleware) and keep only the core examples (structured output, log levels, credential guard).

### `memory-bank/` (project's own memory files)
The current memory-bank files contain Eric Nolan-specific content (techContext.md references Eric Nolan MCP tools, branding MCP, GitLab, etc.). Reset these files to generic personal-use content by rewriting them as blank-slate templates that describe a generic personal coding standard, not the Eric Nolan enterprise implementation.

### `README.md`
Rewrite to remove Eric Nolan ERE attribution, GitLab distribution instructions, and team-onboarding framing. Replace with personal-use orientation: what this is, how to copy it into a project, quick start.

---

## Final Repository Structure

```
personal-memory-bank/
├── .claude/
│   ├── commands/
│   │   ├── code-review.md
│   │   ├── feature-dev.md
│   │   └── security-review.md
│   └── settings.local.json          ← cleaned
├── .cursor/rules/
│   ├── memory-bank.mdc
│   ├── security.mdc
│   ├── code-quality.mdc
│   ├── workflow.mdc
│   └── rules-file-integrity.mdc
├── docs/
│   ├── SETUP-GUIDE.md               ← updated
│   ├── QUICK-REFERENCE.md           ← updated
│   ├── LOGGING-GUIDE.md             ← trimmed
│   ├── CURSOR-VS-CLAUDE.md
│   ├── GLOBAL-RULES-SETUP.md
│   └── CLAUDE-CODE-PLUGINS.md
├── memory-bank/
│   ├── README.md
│   ├── projectbrief.md
│   ├── systemPatterns.md
│   ├── techContext.md
│   ├── activeContext.md
│   └── progress.md
├── scripts/
│   ├── init-memory-bank.ps1         ← Eric Nolan refs stripped
│   ├── init-memory-bank.sh          ← Eric Nolan refs stripped
│   ├── mb.ps1
│   └── mb.sh
├── standards/
│   ├── MEMORY-BANK.md
│   ├── SECURITY-GUARDRAILS.md
│   ├── CODE-QUALITY.md
│   ├── LOGGING.md                   ← trimmed to ~70 lines
│   ├── WORKFLOW.md
│   ├── SUPPLY-CHAIN.md
│   ├── MCP-SECURITY.md
│   ├── RULES-FILE-INTEGRITY.md
│   └── extensions/
│       ├── python.md
│       ├── typescript.md
│       └── logging-python.md
├── templates/
│   ├── memory-bank/                 ← 5 files
│   ├── claude-commands/             ← 3 files
│   ├── cursor/rules/                ← 5 files
│   ├── CLAUDE.md                    ← trimmed
│   ├── AGENTS.md
│   └── handoff.md
├── CLAUDE.md                        ← trimmed
├── README.md                        ← rewritten
├── CONTRIBUTING.md
└── LICENSE
```

---

## Security Note

The existing `.claude/settings.local.json` contains a **hardcoded GitLab API token** (`glpat-...`). This must be rotated in GitLab before the enterprise repo is archived or shared. The personal fork's settings file will not contain this token.

---

## Verification

After implementation, verify:
1. `git ls-files | grep brand` — returns nothing (brand/ is fully removed)
2. `git ls-files | grep training` — returns nothing
3. `grep -r "Eric Nolan" CLAUDE.md templates/CLAUDE.md` — returns nothing
4. Open Claude Code in a test project using the personal CLAUDE.md — confirm session start reads memory bank, no enterprise hygiene block
5. Run `/feature-dev` — confirm 7-phase flow launches correctly
6. Run `/code-review` — confirm multi-agent review spawns correctly
7. Check token count at session start: should be ~4K–4.5K total (vs ~5K enterprise)
8. Confirm `.claude/settings.local.json` has no token, no Eric Nolan MCP entries
