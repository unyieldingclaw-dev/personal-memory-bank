---
authority: stable
review-cycle: 30d
retention: permanent
staleness-threshold: 90d
tags:
  - stack/backend
  - stack/frontend
  - env/tools
last-reviewed: 2026-05-14
---

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
