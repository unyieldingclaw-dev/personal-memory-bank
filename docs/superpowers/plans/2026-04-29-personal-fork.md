# Personal Memory Bank Fork — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Create a personal fork of the enterprise Memory Bank by copying the repo and removing/trimming all T-Mobile-specific and enterprise-compliance content, while keeping the core AI coding workflow intact.

**Architecture:** Copy the enterprise repo to a new directory, then surgically remove and rewrite files. No new application code is written — this is pure configuration management and content editing.

**Tech Stack:** Git, PowerShell/Bash, Claude Code, plain Markdown files

**Spec:** `docs/superpowers/specs/2026-04-29-personal-fork-design.md`

---

### Task 1: Create the personal fork repo

**Files:**
- Create: `C:\Users\Mizzo\Claude\Personal-Memory-Bank\` (confirm path with user before running)

- [ ] **Step 1: Copy the enterprise repo to a new location**

```powershell
$src = "C:\Users\Mizzo\Claude\Memory-Bank\Memory-Bank"
$dst = "C:\Users\Mizzo\Claude\Personal-Memory-Bank"
Copy-Item -Path $src -Destination $dst -Recurse
```

- [ ] **Step 2: Re-initialize git as a fresh repo**

```powershell
cd $dst
Remove-Item -Recurse -Force .git
git init
git add .
git commit -m "chore: initial commit from enterprise fork"
```

Expected: `[master (root-commit) xxxxxxx] chore: initial commit from enterprise fork`

---

### Task 2: Remove binary assets and T-Mobile-specific root files

**Files to delete:** `brand/`, `training/`, `memory-bank-overview*.pptx`, `memory-bank-presentation-summary.md`, `GITLAB-DESCRIPTION.md`

- [ ] **Step 1: Remove brand/ and training/ directories**

```powershell
git rm -r brand/
git rm -r training/
```

- [ ] **Step 2: Remove T-Mobile root files**

```powershell
git rm memory-bank-presentation-summary.md
git rm GITLAB-DESCRIPTION.md
git ls-files | Select-String "memory-bank-overview" | ForEach-Object { git rm $_.Line }
```

- [ ] **Step 3: Commit**

```powershell
git commit -m "chore: remove T-Mobile brand assets, training materials, and GitLab files"
```

---

### Task 3: Remove enterprise-only standards files

**Files to delete:** `standards/DATA-CLASSIFICATION.md`, `standards/MODEL-GOVERNANCE.md`, `standards/LLM-TOP-10-MAPPING.md`

- [ ] **Step 1: Remove standards**

```powershell
git rm standards/DATA-CLASSIFICATION.md
git rm standards/MODEL-GOVERNANCE.md
git rm standards/LLM-TOP-10-MAPPING.md
```

- [ ] **Step 2: Commit**

```powershell
git commit -m "chore: remove enterprise compliance standards"
```

---

### Task 4: Remove enterprise-only templates, commands, and scripts

**Files to delete:**
- `templates/INCIDENT-RUNBOOK.md`
- `templates/claude-commands/accessibility-review.md`
- `templates/cursor/rules/enterprise-logging.mdc`
- `templates/cursor/rules/accessibility.mdc` (if exists)
- `.claude/commands/accessibility-review.md`
- `.cursor/rules/accessibility.mdc` (if exists)
- `.cursor/rules/enterprise-logging.mdc` (if exists)
- `scripts/build_overview_deck.py`
- `scripts/patch_overview_deck.py`
- `scripts/update_gitlab_description.py`

- [ ] **Step 1: Remove enterprise templates**

```powershell
git rm templates/INCIDENT-RUNBOOK.md
git rm templates/claude-commands/accessibility-review.md
git rm templates/cursor/rules/enterprise-logging.mdc
if (Test-Path "templates/cursor/rules/accessibility.mdc") {
    git rm "templates/cursor/rules/accessibility.mdc"
}
```

- [ ] **Step 2: Remove enterprise commands and cursor rules**

```powershell
git rm .claude/commands/accessibility-review.md
if (Test-Path ".cursor/rules/accessibility.mdc") { git rm ".cursor/rules/accessibility.mdc" }
if (Test-Path ".cursor/rules/enterprise-logging.mdc") { git rm ".cursor/rules/enterprise-logging.mdc" }
```

- [ ] **Step 3: Remove T-Mobile-specific Python scripts**

```powershell
git rm scripts/build_overview_deck.py
git rm scripts/patch_overview_deck.py
git rm scripts/update_gitlab_description.py
```

- [ ] **Step 4: Commit**

```powershell
git commit -m "chore: remove enterprise-only commands, templates, cursor rules, and T-Mobile scripts"
```

---

### Task 5: Clean settings.local.json

**Files:** Modify `.claude/settings.local.json`

> **CRITICAL:** Before archiving the enterprise repo, rotate the GitLab token in GitLab → User Settings → Access Tokens. Revoke the `glpat-DMEbB1...` token.

- [ ] **Step 1: Read .claude/settings.local.json**

- [ ] **Step 2: Overwrite with clean personal settings**

```json
{
  "permissions": {
    "allow": [
      "Bash(git *)",
      "WebFetch(domain:owasp.org)",
      "WebFetch(domain:nvd.nist.gov)",
      "WebFetch(domain:attack.mitre.org)",
      "WebFetch(domain:arxiv.org)",
      "WebSearch(domain:owasp.org)",
      "WebSearch(domain:nvd.nist.gov)"
    ]
  }
}
```

- [ ] **Step 3: Verify no token**

```powershell
Select-String -Path ".claude/settings.local.json" -Pattern "glpat"
```

Expected: 0 matches.

- [ ] **Step 4: Commit**

```powershell
git add .claude/settings.local.json
git commit -m "security: remove hardcoded GitLab token and T-Mobile MCP entries from settings"
```

---

### Task 6: Trim CLAUDE.md (templates/ version and root if present)

**Files:** Modify `templates/CLAUDE.md` (and root `CLAUDE.md` if it exists)

Three edits:
1. Simplify the Accessibility section (remove `/accessibility-review` and `accessibility.mdc` refs)
2. Replace Enterprise Hygiene section with 3-line personal block
3. Simplify the Logging reference line

- [ ] **Step 1: Read templates/CLAUDE.md in full**

- [ ] **Step 2: Replace the Accessibility section**

Find:
```
### Accessibility (UI code only)
- If you are editing UI files (`.html`, `.jsx`, `.tsx`, `.vue`, `.svelte`, `.astro`, `.css`, `.scss`), follow `standards/ACCESSIBILITY.md` — WCAG 2.1 Level AA is a hard requirement.
- The Cursor rule `.cursor/rules/accessibility.mdc` auto-applies to those file types.
- On-demand audit: `/accessibility-review` for a deep WCAG scan of the current diff or a target path.
```

Replace with:
```
### Accessibility (UI code only)
For HTML/JSX/TSX/Vue/Svelte files: apply WCAG 2.1 AA basics (semantic HTML, alt text, form labels, keyboard nav). See `standards/ACCESSIBILITY.md`.
```

- [ ] **Step 3: Replace the Enterprise Hygiene section**

Find the block starting with `## Enterprise hygiene (v1.5 additions)` through the last bullet before `## Workflow`.

Replace with:
```markdown
## Personal Safety Rules

- **Secrets:** Never hardcode credentials — use env vars or secret managers (`.env`, OS keychain).
- **Model:** Use the most capable Claude model available for the task.
- **Agent safety:** Don't run destructive commands without user confirmation.
```

- [ ] **Step 4: Replace the Logging reference line**

Find:
```
Use structured logging with keyword args (no f-strings), redact PII, propagate correlation IDs. Full spec in `standards/LOGGING.md`. Python extension in `standards/extensions/logging-python.md`. Read these when touching logging code.
```

Replace with:
```
Use structured logging (key-value pairs, not f-strings), use log levels, never log credentials. See `standards/LOGGING.md`.
```

- [ ] **Step 5: Apply identical edits to root CLAUDE.md if it exists**

```powershell
if (Test-Path "CLAUDE.md") { <# repeat Steps 2-4 on CLAUDE.md #> }
```

- [ ] **Step 6: Commit**

```powershell
git add templates/CLAUDE.md CLAUDE.md
git commit -m "feat: trim CLAUDE.md — replace enterprise hygiene with personal safety rules"
```

---

### Task 7: Rewrite standards/LOGGING.md to essentials

**Files:** Modify `standards/LOGGING.md` (459 lines → ~70 lines)

- [ ] **Step 1: Overwrite standards/LOGGING.md with this content**

```markdown
# Logging Standard — Essentials

Core rules for writing logs in any project.

## Rules

1. **Structured format** — use key-value pairs or JSON, not f-string concatenation.
2. **Use log levels** — `DEBUG` (dev details), `INFO` (significant events), `WARN` (unexpected but handled), `ERROR` (failures).
3. **Never log secrets** — no credentials, API keys, tokens, or passwords in logs, ever.
4. **Log the event, not the string** — log what happened and relevant IDs, not a sentence.

## Python

```python
import logging

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s %(levelname)s %(message)s",
)
logger = logging.getLogger(__name__)

# Good: structured, queryable
logger.info("user_authenticated", extra={"user_id": user_id, "method": "oauth"})

# Bad: f-string, unqueryable, secrets exposed
logger.info(f"User {username} logged in with password {password}")  # Never
```

## TypeScript

```typescript
const log = (level: string, event: string, data?: Record<string, unknown>) =>
  console.log(JSON.stringify({ ts: new Date().toISOString(), level, event, ...data }));

// Good
log("INFO", "user_authenticated", { userId });

// Bad: logging secrets
log("INFO", "db_connect", { password });  // Never
```

## Log Level Guide

| Level | When to use |
|-------|-------------|
| `DEBUG` | Dev details — gate behind env var in prod |
| `INFO` | Successful significant events |
| `WARN` | Handled edge cases, degraded behavior |
| `ERROR` | Failures that need attention |

## What Never to Log

- Passwords, API keys, tokens, secrets of any kind
- Full request/response bodies from external APIs (may contain embedded secrets)
- Verbose per-row database output in production loops
```

- [ ] **Step 2: Verify line count**

```powershell
(Get-Content standards/LOGGING.md).Count
```

Expected: ~65–80 lines.

- [ ] **Step 3: Commit**

```powershell
git add standards/LOGGING.md
git commit -m "feat: trim logging standard to essentials"
```

---

### Task 8: Trim docs/LOGGING-GUIDE.md

**Files:** Modify `docs/LOGGING-GUIDE.md`

- [ ] **Step 1: Read docs/LOGGING-GUIDE.md**

- [ ] **Step 2: Remove enterprise sections** (PII redaction, correlation IDs, Splunk/ELK setup, data classification refs). If >50% is enterprise content, replace the entire file with:

```markdown
# Logging Guide

See `standards/LOGGING.md` for the core rules.

## Quick Reference

- Structured format (key-value or JSON), not f-string concatenation
- Log levels: DEBUG / INFO / WARN / ERROR
- Never log secrets, credentials, or tokens
- Log the event and relevant IDs, not a prose sentence

## Python Setup

```python
import logging

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s %(name)s %(levelname)s %(message)s",
)
logger = logging.getLogger(__name__)

logger.info("order_placed", extra={"order_id": order_id, "amount": amount})
```

## TypeScript Setup

```typescript
const log = (level: string, event: string, data?: object) =>
  console.log(JSON.stringify({ ts: new Date().toISOString(), level, event, ...data }));

log("INFO", "order_placed", { orderId, amount });
```
```

- [ ] **Step 3: Commit**

```powershell
git add docs/LOGGING-GUIDE.md
git commit -m "feat: trim logging guide to match essentials standard"
```

---

### Task 9: Trim standards/extensions/logging-python.md

**Files:** Modify `standards/extensions/logging-python.md`

- [ ] **Step 1: Read the file**

- [ ] **Step 2: Remove enterprise patterns** (PII filters, correlation ID middleware, Splunk handlers). If primarily enterprise content, replace with:

```markdown
# Python Logging Extension

Extends `standards/LOGGING.md` with Python-specific patterns.

## Setup

```python
import logging

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s %(name)s %(levelname)s %(message)s",
)

def get_logger(name: str) -> logging.Logger:
    return logging.getLogger(name)
```

## Usage

```python
logger = get_logger(__name__)

# Good
logger.info("order_placed", extra={"order_id": order_id, "amount": amount})

# Never: logging secrets
logger.info("payment", extra={"card_number": card, "cvv": cvv})
```

## Log Levels

```python
logger.debug("cache_miss")               # Dev details
logger.info("request_completed")         # Normal events
logger.warning("rate_limit_near")        # Handled edge cases
logger.error("db_connection_failed")     # Action needed
```
```

- [ ] **Step 3: Commit**

```powershell
git add standards/extensions/logging-python.md
git commit -m "feat: trim Python logging extension to match essentials standard"
```

---

### Task 10: Strip T-Mobile refs from init scripts

**Files:** Modify `scripts/init-memory-bank.ps1`, `scripts/init-memory-bank.sh`

- [ ] **Step 1: Read scripts/init-memory-bank.ps1**

- [ ] **Step 2: Remove or rewrite T-Mobile-specific blocks**

Remove:
- Any step that runs `update_gitlab_description.py`
- Any step referencing T-Mobile MCP or branding setup
- Any step referencing `brand/` directory

Rewrite:
- "Welcome to T-Mobile Memory Bank" → "Memory Bank initialized. Copy templates to your project and fill in memory-bank/ files."

Preserve: all directory-creation logic and template-copy logic.

- [ ] **Step 3: Apply same cleanup to scripts/init-memory-bank.sh**

- [ ] **Step 4: Commit**

```powershell
git add scripts/init-memory-bank.ps1 scripts/init-memory-bank.sh
git commit -m "chore: strip T-Mobile and GitLab refs from init scripts"
```

---

### Task 11: Reset memory-bank/ files to generic personal templates

**Files:** Overwrite all 5 files in `memory-bank/`

- [ ] **Step 1: Overwrite memory-bank/projectbrief.md**

```markdown
# Project Brief

## Purpose

This is my personal AI coding standard — a set of rules, templates, and commands that I copy into any new project to get consistent, high-quality AI-assisted development.

## Non-Negotiable Requirements

- Memory Bank files are read at session start — they persist context across conversations
- Security guardrails (BLOCK/CONFIRM/WARN) are always active
- Code quality standards apply to all generated code
- 7-phase workflow for non-trivial features

## Constraints

- Setup time for a new project: < 10 minutes
- Works in both Claude Code and Cursor
- No external dependencies (self-contained Markdown and config files)
```

- [ ] **Step 2: Overwrite memory-bank/techContext.md**

```markdown
# Tech Context

## Standards

| Standard | File | Loaded |
|----------|------|--------|
| Memory Bank | standards/MEMORY-BANK.md | Session start |
| Security Guardrails | standards/SECURITY-GUARDRAILS.md | Referenced |
| Code Quality | standards/CODE-QUALITY.md | Referenced |
| Logging (essentials) | standards/LOGGING.md | Referenced |
| Workflow | standards/WORKFLOW.md | Referenced |
| Supply Chain | standards/SUPPLY-CHAIN.md | On demand |
| MCP Security | standards/MCP-SECURITY.md | On demand |
| Rules-File Integrity | standards/RULES-FILE-INTEGRITY.md | On demand |

## IDE Support

- **Claude Code** — `.claude/commands/` (code-review, feature-dev, security-review)
- **Cursor** — `.cursor/rules/` (memory-bank, security, code-quality, workflow, rules-file-integrity)

## Distribution

Run `scripts/init-memory-bank.ps1` (Windows) or `scripts/init-memory-bank.sh` (Mac/Linux).
```

- [ ] **Step 3: Overwrite memory-bank/systemPatterns.md**

```markdown
# System Patterns

## Core Concepts

### Memory Bank (5 files)
Persistent context across AI sessions. Read at session start, updated after significant changes.

### Security Guardrails (3-tier)
- BLOCK — refuse (force push, hardcoded secrets, destructive commands)
- CONFIRM — ask first (deletions, bulk ops, CI changes, schema changes)
- WARN — note the risk (large changes, missing tests, new files)

### 7-Phase Feature Workflow
Brainstorm → Spec → Plan → Implement → Simplify → Security Review → Commit

### Handoff Protocol
At 65% context: stop, write handoff.md, start new chat.

## Coding Principles

- Think before coding — explore alternatives before writing
- Simplicity first — smallest change that solves the problem
- Surgical changes — touch only what needs to change
- Goal-driven — if a step doesn't serve the goal, skip it
```

- [ ] **Step 4: Overwrite memory-bank/activeContext.md**

```markdown
# Active Context

## Current Focus

Personal fork setup complete. Ready to use as a template for new projects.

## Next Steps

1. Copy this repo's files into a new project when starting
2. Run the init script to scaffold the structure
3. Fill in memory-bank/ files with project-specific context
```

- [ ] **Step 5: Overwrite memory-bank/progress.md**

```markdown
# Progress

## Status: Ready

Personal fork of the enterprise Memory Bank standard.

## What's In This Fork

- ✅ Memory Bank system (5-file + handoff protocol)
- ✅ Security Guardrails (BLOCK/CONFIRM/WARN)
- ✅ Code Quality standard
- ✅ Logging standard (essentials)
- ✅ 7-phase Workflow standard
- ✅ Supply Chain, MCP Security, Rules-File Integrity (reference)
- ✅ /code-review, /feature-dev, /security-review commands
- ✅ Cursor rules (5 rules)
- ✅ Init scripts + mb utility scripts

## Removed vs Enterprise

- ❌ T-Mobile branding and brand assets
- ❌ Data Classification, Model Governance, OWASP LLM Top 10 (compliance only)
- ❌ Incident Runbook, accessibility review command
- ❌ Enterprise logging (PII redaction, correlation IDs)
- ❌ GitLab integration scripts, training materials
```

- [ ] **Step 6: Commit**

```powershell
git add memory-bank/
git commit -m "chore: reset memory-bank files to generic personal templates"
```

---

### Task 12: Rewrite README.md

**Files:** Modify `README.md`

- [ ] **Step 1: Read current README.md**

- [ ] **Step 2: Overwrite with personal-use README**

```markdown
# Personal Memory Bank

A personal AI coding standard for Claude Code and Cursor. Copy it into any project for consistent, high-quality AI-assisted development.

## What This Is

- **Standards** — code quality, security, logging, workflow, and more
- **Claude Code commands** — `/code-review`, `/feature-dev`, `/security-review`
- **Cursor rules** — auto-apply standards based on file type
- **Memory Bank templates** — 5-file persistent context system for AI sessions
- **Setup scripts** — scaffold any new project in under 10 minutes

## Quick Start

### Windows
```powershell
.\scripts\init-memory-bank.ps1 -ProjectPath "C:\path\to\your\project"
```

### Mac/Linux
```bash
./scripts/init-memory-bank.sh /path/to/your/project
```

Fill in `memory-bank/projectbrief.md` with your project context.

## Core Standards

| Standard | Description |
|----------|-------------|
| SECURITY-GUARDRAILS | BLOCK / CONFIRM / WARN for risky operations |
| CODE-QUALITY | Testing, comments, structure, error handling |
| LOGGING | Structured logs, log levels, no credentials |
| WORKFLOW | 7-phase feature development |
| SUPPLY-CHAIN | Package safety, slopsquatting prevention |

## Commands

| Command | Description |
|---------|-------------|
| `/code-review` | Multi-agent code review (security, performance, style, tests) |
| `/feature-dev` | Full 7-phase feature development workflow |
| `/security-review` | Scan diff for 9 security patterns |

## License

MIT
```

- [ ] **Step 3: Commit**

```powershell
git add README.md
git commit -m "docs: rewrite README for personal use"
```

---

### Task 13: Update docs/ (SETUP-GUIDE.md and QUICK-REFERENCE.md)

**Files:** Modify `docs/SETUP-GUIDE.md`, `docs/QUICK-REFERENCE.md`

- [ ] **Step 1: Read docs/SETUP-GUIDE.md**

Remove: T-Mobile GitLab clone instructions, T-Mobile MCP setup, brand template setup, team-sharing steps, refs to removed standards and `/accessibility-review`.

Keep: directory structure, how to copy files into a project, how to fill memory-bank files, how to run init scripts.

- [ ] **Step 2: Read docs/QUICK-REFERENCE.md**

Remove: T-Mobile MCP refs, accessibility review row, data classification/model governance entries, GitLab refs.

Keep: memory bank file purposes, guardrails summary, workflow phases, 3-command table, code quality rules.

- [ ] **Step 3: Commit after both files are updated**

```powershell
git add docs/SETUP-GUIDE.md docs/QUICK-REFERENCE.md
git commit -m "docs: remove T-Mobile and enterprise refs from docs"
```

---

### Task 14: Final Verification

- [ ] **Step 1: Verify brand/ and training/ are gone**

```powershell
git ls-files | Select-String "brand/" | Measure-Object -Line
git ls-files | Select-String "training/" | Measure-Object -Line
```

Expected: 0 for both.

- [ ] **Step 2: Verify enterprise standards are gone**

```powershell
git ls-files standards/ | Select-String "DATA-CLASSIFICATION|MODEL-GOVERNANCE|LLM-TOP-10"
```

Expected: 0 matches.

- [ ] **Step 3: Verify no T-Mobile refs in CLAUDE.md**

```powershell
Select-String -Path "templates/CLAUDE.md" -Pattern "T-Mobile|enterprise hygiene|accessibility-review|accessibility\.mdc"
```

Expected: 0 matches.

- [ ] **Step 4: Verify no GitLab token in settings**

```powershell
Select-String -Path ".claude/settings.local.json" -Pattern "glpat"
```

Expected: 0 matches.

- [ ] **Step 5: Verify correct commands**

```powershell
Get-ChildItem .claude/commands/
```

Expected: `code-review.md`, `feature-dev.md`, `security-review.md` only.

- [ ] **Step 6: Verify correct cursor rules**

```powershell
Get-ChildItem .cursor/rules/
```

Expected: `memory-bank.mdc`, `security.mdc`, `code-quality.mdc`, `workflow.mdc`, `rules-file-integrity.mdc` only.

- [ ] **Step 7: Final commit if needed**

```powershell
git status
# If clean: done.
# If any unstaged:
git add -A
git commit -m "chore: final cleanup pass"
```
