# GitLab Project Description — ready to paste

This file holds the GitLab project description text for `tmobile/ere/memory-bank`. The GitLab UI has three places the project is described; each is prefilled below.

---

## 1. Short description (≤ 250 chars, shows on project card)

```
Enterprise-ready AI coding standard for Cursor and Claude Code. Persistent memory-bank, 3-tier security guardrails, code quality and logging standards, feature workflow, multi-agent /code-review, and on-demand /accessibility-review (WCAG 2.1 AA).
```

## 2. About / long description (for project settings) — 1,791 chars, fits GitLab's 2,000 cap

```
Enterprise AI coding standards for Cursor and Claude Code. Drop into any repo; productive in under 15 minutes.

Core standards:
• Persistent memory-bank — five files the AI reads at every session start.
• 3-tier security guardrails — BLOCK / CONFIRM / WARN (secrets, force-push, slopsquat packages, MCP creds, long-lived creds in agent env).
• Code quality — verification before done, WHY-only comments, explicit error handling.
• Structured logging — JSON-in-prod, correlation IDs, auto-PII redaction.
• Feature workflow — Brainstorm → Spec → Plan → Implement (TDD) → Simplify → Security Review → Commit.

Conditional + on-demand:
• Accessibility (WCAG 2.1 Level AA) — glob-scoped Cursor rule for UI files; on-demand /accessibility-review audit.
• Multi-agent /code-review — three parallel role subagents (security, performance, style) with uncorrelated contexts, a test-coverage reviewer that generates missing tests, and an opponent auditor that confirms / downgrades / rejects findings.

Enterprise hygiene (v1.5):
• Rules-file integrity — anti-prompt-injection for .cursorrules / CLAUDE.md / AGENTS.md / .mdc / slash commands.
• Data classification — Public / Internal / Confidential / Restricted tiers.
• Ephemeral secrets — Vault / AWS SM / Azure KV; rotate after agent sessions.
• OWASP LLM Top 10 (2025) coverage mapping with residual-gap tracker.
• Model governance — approved model list + version pinning + canary change management.
• Incident response runbook template with AI-involvement checklist.
• Agent resource controls — token budgets, loop detection, 429 handling.

Ships rule files for Cursor (.mdc), Claude Code (CLAUDE.md + slash commands), AGENTS.md for Codex / Gemini CLI. Install scripts for Windows / macOS / Linux. MIT licensed. See README for install one-liners.
```

## 3. Topics / tags (GitLab project tags field)

```
ai-coding, cursor, claude-code, developer-tools, memory-bank, security-guardrails, code-review, accessibility, wcag, structured-logging, enterprise-ai, slash-commands, tmobile-aero
```

---

## How to update (manual, UI)

1. Go to the GitLab project → **Settings → General**.
2. Paste the **Short description** into *Project description*.
3. Paste the topics into *Project topics / tags*.
4. Save changes.
5. For the long description, paste into the project's wiki landing page or the top of the README. (The README.md intro paragraph in this repo is already updated to match.)

## How to update (CLI, if `glab` is installed)

```bash
# Short description + tags
glab repo edit --description "Enterprise-ready AI coding standard for Cursor and Claude Code. Persistent memory-bank, 3-tier security guardrails, code quality and logging standards, feature workflow, and multi-agent /code-review (security · performance · style · test coverage · auditor)."

# Add topics
glab repo edit --add-topic ai-coding --add-topic cursor --add-topic claude-code --add-topic code-review --add-topic memory-bank
```

`glab` is not installed on this machine — run it from wherever you have it, or use the UI steps above.
