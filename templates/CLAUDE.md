# Project Instructions for Claude

This file provides instructions for Claude Code. Read this file and all files in `memory-bank/` at the start of every conversation.

## Memory Bank

At the start of every conversation, and again after any context compaction, silently read ALL files in `memory-bank/` to restore full project context:

1. `memory-bank/projectbrief.md` - Non-negotiable requirements and constraints
2. `memory-bank/systemPatterns.md` - Architecture decisions and patterns to follow
3. `memory-bank/techContext.md` - Tech stack, dependencies, environment
4. `memory-bank/activeContext.md` - Current focus and next steps
5. `memory-bank/progress.md` - What's complete and planned

**Rules:**
- Never ask for information already documented in Memory Bank
- Never violate constraints in projectbrief.md
- Always follow patterns in systemPatterns.md
- Update Memory Bank files after significant changes
- Never write secrets, credentials, API keys, PII, production data, or full code dumps to memory-bank/ files

## Context Compaction Recovery

Claude Code automatically compacts context at approximately 75% — before the 65% handoff threshold. When compaction occurs, a "context was compacted" summary may appear at the top of the conversation.

**If you observe a compaction summary:**
1. Re-read ALL `memory-bank/` files immediately before continuing any work
2. Summarize to the user what context you recovered
3. Ask the user to confirm where to resume if mid-task

**Do not continue work from memory alone after compaction.**

## Security Guardrails

Three tiers — `standards/SECURITY-GUARDRAILS.md` has the full enumerated lists.

- **BLOCK** (refuse): committing secrets, force-push to main/master, `git reset --hard` on shared branches, modifying git config, destructive system commands, exposing secrets, unverified package recommendations, hardcoded MCP credentials.
- **CONFIRM** (ask first): deletions, file overwrites without reading, bulk ops on >3 files, commit amends, `--no-verify`, force-push to any branch, interactive rebase, `DROP`/`DELETE`/`TRUNCATE`, schema changes, edits to `*auth*`/`*security*`/`*permission*`, CI/CD changes.
- **WARN** (note the risk): >5 files or >200 lines, new files, missing tests, skipping verification.

## Code Quality

Before claiming done: tests pass, lint clean, build succeeds, describe what was tested. Comments: WHY not WHAT, no dead code. Structure: edit existing files first, small incremental changes, one thing per function. Errors: explicit, meaningful, never swallowed. Full spec: `standards/CODE-QUALITY.md`.

### Accessibility (UI code only)
For HTML/JSX/TSX/Vue/Svelte files: apply WCAG 2.1 AA basics (semantic HTML, alt text, form labels, keyboard nav). See `standards/ACCESSIBILITY.md`.

## Personal Safety Rules

- **Secrets:** Never hardcode credentials — use env vars or secret managers (`.env`, OS keychain).
- **Model:** Use the most capable Claude model available for the task.
- **Agent safety:** Don't run destructive commands without user confirmation.

## Workflow

Always follow this sequence for any non-trivial feature:

1. **Brainstorm** — Understand requirements, explore codebase, propose 2–3 approaches, get design approved before writing code
2. **Spec** — Write the validated design to `docs/specs/YYYY-MM-DD-<topic>.md`
3. **Plan** — Create a bite-sized implementation plan with exact file paths and complete code
4. **Implement** — TDD: write failing test → implement → verify passing → commit
5. **Simplify** — Review changed code for clarity and consistency without changing behavior
6. **Security Review** — Scan diff for the 9 security patterns (secrets, injection, XSS, etc.) — run `/security-review` or see `standards/SECURITY-GUARDRAILS.md`
7. **Commit** — Stage and commit with a descriptive message

**Skip to step 4** for: single-file fixes, typos, config changes, or changes < 20 lines.

## Logging

Use structured logging (key-value pairs, not f-strings), use log levels, never log credentials. See `standards/LOGGING.md`.

## Handoff Protocol

When user types "Handoff" or reports context >= 65%:

1. **STOP** all work immediately
2. **CREATE** `handoff.md` in project root with:
   - Summary of accomplishments
   - Files modified
   - Service state (running/stopped)
   - Commands to resume
   - Pending tasks
   - Context for next agent
3. **RESPOND** only: "Handoff ready at `handoff.md`. Start a new conversation."
4. **STOP** - do not continue

When starting a new conversation:
1. Check for `handoff.md` - if exists, read it FIRST
2. Merge info into Memory Bank
3. Delete `handoff.md`
4. Continue work

## Coding Principles

Follow the 4 principles in `standards/CODE-QUALITY.md` (Think Before Coding, Simplicity First, Surgical Changes, Goal-Driven Execution). These bias toward caution — use judgment for trivial tasks.

---

## Quick Commands

| Command | Action |
|---------|--------|
| `mb update` | Update all Memory Bank files |
| `mb status` | Show file sizes and health |
| `mb archive` | Move history to AGENTS.md |
| `mb slim` | Trim activeContext.md |
| `Handoff` | Create handoff and stop |
