# Memory Bank Standard

Enterprise-ready AI coding standards that make Cursor and Claude Code safer, more consistent, and productive in under 15 minutes. Ships **five universal standards** (persistent memory-bank, 3-tier security guardrails, code quality, structured logging, and feature-development workflow) plus a **conditional Accessibility standard** (WCAG 2.1 Level AA) that auto-applies to UI files only. Includes IDE rule files for Cursor and Claude Code, Windows/Mac/Linux setup scripts, hands-on training, a multi-agent `/code-review` command (parallel Security / Performance / Style subagents + test-coverage reviewer that can generate missing tests + opponent auditor), and an on-demand `/accessibility-review` WCAG audit.

## Quick Start

### Option 1: Run the Scaffold Script (Recommended)

**PowerShell (Windows):**
```powershell
# Download and run
irm https://gitlab.com/tmobile/ere/memory-bank/-/raw/master/scripts/init-memory-bank.ps1 | iex

# Or clone and run locally
git clone https://gitlab.com/tmobile/ere/memory-bank.git
.\memory-bank\scripts\init-memory-bank.ps1
```

**Bash (macOS/Linux):**
```bash
curl -sSL https://gitlab.com/tmobile/ere/memory-bank/-/raw/master/scripts/init-memory-bank.sh | bash
```

### Option 2: Manual Setup

1. Copy the `templates/` folder contents to your project
2. Fill in the memory-bank files with your project details
3. Start coding with persistent AI context

## What's Included

### Five Standards

| Standard | Purpose | Key Features |
|----------|---------|--------------|
| [Memory Bank](standards/MEMORY-BANK.md) | Context persistence across AI sessions | 5-file structure, handoff at 80%, task decomposition |
| [Security Guardrails](standards/SECURITY-GUARDRAILS.md) | Prevent dangerous AI actions | 3-tier BLOCK/CONFIRM/WARN system |
| [Code Quality](standards/CODE-QUALITY.md) | Consistent AI-generated code | Generic core + language extensions |
| [Logging](standards/LOGGING.md) | Production-grade structured logging | Structured logs, PII sanitization, correlation IDs |
| [Workflow](standards/WORKFLOW.md) | Structured feature development | Brainstorm → spec → plan → implement → simplify → security review → commit |

### Conditional rule — Accessibility (UI code only)

| Reference | Scope | Activation |
|-----------|-------|------------|
| [Accessibility](standards/ACCESSIBILITY.md) | WCAG 2.1 Level AA — semantic HTML, ARIA, keyboard, focus, contrast, forms, media, motion, testing | Cursor rule `.cursor/rules/accessibility.mdc` auto-applies to `.html`, `.jsx`, `.tsx`, `.vue`, `.svelte`, `.astro`, `.css`, `.scss`, `.sass`, `.less`. On-demand audit: `/accessibility-review`. |

### Templates

```
templates/
├── memory-bank/           # 5 context files for your project
│   ├── projectbrief.md    # Non-negotiable requirements
│   ├── systemPatterns.md  # Architecture decisions
│   ├── techContext.md     # Tech stack details
│   ├── activeContext.md   # Current session focus
│   └── progress.md        # What's done/planned
├── cursor/rules/          # Cursor IDE rules
│   ├── memory-bank.mdc    # Auto-load context
│   ├── security.mdc       # Security guardrails
│   ├── code-quality.mdc   # Quality standards
│   ├── enterprise-logging.mdc # Structured logging
│   ├── workflow.mdc       # Feature development workflow
│   ├── accessibility.mdc  # WCAG 2.1 AA — glob-scoped to UI files only
│   └── rules-file-integrity.mdc # Anti-prompt-injection hygiene — glob-scoped to rule files themselves
├── claude-commands/       # Claude Code slash commands
│   ├── feature-dev.md     # /feature-dev — full 7-phase workflow
│   ├── security-review.md # /security-review — 9-pattern security scan
│   ├── code-review.md     # /code-review — multi-agent review (security, perf, style, tests, auditor)
│   └── accessibility-review.md # /accessibility-review — WCAG 2.1 AA audit (on-demand)
├── CLAUDE.md              # Claude Code global instructions
├── AGENTS.md              # Cross-tool rules (Claude Code + Cursor + Codex + Gemini)
├── handoff.md             # Session handoff template
└── plan.md                # Task planning template
```

### Documentation

- [Setup Guide](docs/SETUP-GUIDE.md) - Step-by-step for beginners
- [Quick Reference](docs/QUICK-REFERENCE.md) - 1-page cheatsheet
- [Logging Guide](docs/LOGGING-GUIDE.md) - Structured logging quick start
- [Cursor vs Claude Code](docs/CURSOR-VS-CLAUDE.md) - IDE comparison
- [Global Rules Setup](docs/GLOBAL-RULES-SETUP.md) - User-level configuration
- [Claude Code Plugins](docs/CLAUDE-CODE-PLUGINS.md) - Plugins, slash commands, auto-memory, global setup
- [Telemetry Guide](docs/TELEMETRY-GUIDE.md) - AI tool telemetry opt-out settings
- [Supply Chain Security](standards/SUPPLY-CHAIN.md) - Slopsquatting, SCA, rules file integrity
- [MCP Security](standards/MCP-SECURITY.md) - MCP credential management and tool poisoning
- [Rules-File Integrity](standards/RULES-FILE-INTEGRITY.md) - `.cursorrules` / `CLAUDE.md` / `.mdc` / slash-command hygiene (anti-prompt-injection)
- [Data Classification](standards/DATA-CLASSIFICATION.md) - Public / Internal / Confidential / Restricted tiers with per-tier prompt, memory-bank, log, and commit rules
- [Secrets Management](standards/SECRETS.md) - Ephemeral-by-default credentials, agent-safe posture, rotation SLAs
- [OWASP LLM Top 10 (2025) Mapping](standards/LLM-TOP-10-MAPPING.md) - Coverage evidence and residual-gap tracker
- [Model Governance](standards/MODEL-GOVERNANCE.md) - Approved model list, version pinning, change management
- [Incident Response Runbook (template)](templates/INCIDENT-RUNBOOK.md) - SEV classification, response checklist, post-mortem template, AI-involvement checklist
- [Accessibility (WCAG 2.1 AA)](standards/ACCESSIBILITY.md) - UI code a11y requirements (rule is glob-scoped, not always-on)

### Scripts

- `init-memory-bank.ps1` - PowerShell scaffold for Windows
- `init-memory-bank.sh` - Bash scaffold for macOS/Linux
- `mb.ps1` - Quick commands utility for Windows (status, update, archive)
- `mb.sh` - Quick commands utility for macOS/Linux (status, update, archive)

## How It Works

### The Problem

AI coding assistants lose context between sessions:
- Re-explain tech stack every session
- Repeat constraints and patterns
- Risk inconsistent code when AI forgets decisions
- Lose progress when context fills up

### The Solution

**Memory Bank** stores project context in structured files that AI reads at session start:

```
Session 1: You explain your project → AI learns → Updates memory-bank/
Session 2: AI reads memory-bank/ → Already knows everything → Productive immediately
```

**Handoff** ensures continuity when context fills up:

```
Context hits 80% → AI creates handoff.md → You start new chat → AI reads handoff.md → Continues seamlessly
```

**Security Guardrails** prevent dangerous actions:

```
BLOCK: AI refuses (commit secrets, force push)
CONFIRM: AI pauses for approval (delete files, amend commits)
WARN: AI notes risk but proceeds (large changes, missing tests)
```

**Logging Standards** ensure production-ready logs:

```python
# Structured, queryable logs
logger.info("order_created", order_id="ORD-123", total=99.99)

# Auto-redacted PII
logger.info("user_registered", email="***@***.com")

# Correlation IDs for tracing
logger = logger.bind(correlation_id="req-abc123")
```

**Workflow Standard** prevents the most common AI failure mode — writing code before understanding the problem:

```
Brainstorm → Spec → Plan → Implement (TDD) → Simplify → Security Review → Commit
```

**Multi-agent `/code-review`** runs four role-separated reviewers against your diff so findings don't bias each other:

```
                    git diff
                       │
      ┌────────────────┼────────────────┐
      ▼                ▼                ▼
 🔐 Security     ⚡ Performance    🎨 Style & Standards    (3 parallel subagents,
 (injection,     (N+1, blocking    (length, nesting,      uncorrelated contexts)
  secrets, auth,  I/O, large       naming, duplication)
  crypto, eval)   payloads)
      │                │                │
      └────────────────┼────────────────┘
                       ▼
            🧪 Test Coverage Review
     (main agent — flags gaps; generates missing tests
      for happy path, edge cases, and error paths)
                       ▼
            🧑‍⚖️ Opponent Auditor (compare)
     (confirms / downgrades / rejects findings,
      and surfaces anything the three reviewers missed)
                       ▼
                  Summary Report
    (Security · Perf · Style · Test Coverage tables,
     each with an Auditor verdict column)
```

In Claude Code: `/code-review`, `/code-review src/auth/login.py`, or `/code-review src/api/`.
In Cursor: "do a code review" / "review src/api/routes.py" (rule file at `.cursor/rules/code-review.mdc`).

## IDE Support

| IDE | Rule File | How to Enable |
|-----|-----------|---------------|
| Cursor | `.cursor/rules/*.mdc` | Automatic (alwaysApply: true) |
| Claude Code | `CLAUDE.md` or `~/.claude/CLAUDE.md` | Automatic (project or global) |
| Any tool (Claude Code, Cursor, Codex, Gemini) | `AGENTS.md` | Single cross-tool file |

All IDEs use the **same** memory-bank/ files — only the rule loading mechanism differs.

For global setup (rules that apply to every project automatically), see [Claude Code Plugins](docs/CLAUDE-CODE-PLUGINS.md) and [Global Rules Setup](docs/GLOBAL-RULES-SETUP.md).

## Quick Commands

After setup, use these shortcuts in your AI chat:

| Command | Action |
|---------|--------|
| `mb update` | Update all Memory Bank files from session |
| `mb status` | Show file sizes, timestamps, health check |
| `mb archive` | Move old history to docs/ARCHIVE.md |
| `mb slim` | Trim activeContext.md to essentials |
| `mb commit` | Stage and commit Memory Bank changes |
| `Handoff` | Create handoff.md and stop (at 80% context) |

## Language Extensions

Code quality rules can be extended per language:

| Language | Extension | Status |
|----------|-----------|--------|
| Python | [python.md](standards/extensions/python.md) | Included |
| TypeScript | [typescript.md](standards/extensions/typescript.md) | Included |
| Go | [_template.md](standards/extensions/_template.md) | Template |
| Java | [_template.md](standards/extensions/_template.md) | Template |

## Training

For team onboarding, see:
- [Training Presentation](training/presentation.html)
- [Hands-on Exercises](training/exercises/)

## Contributing

1. Fork this repository
2. Add your language extension or improvement
3. Submit a pull request

## License

MIT License - Use freely in your organization.

## Support

- Issues: [GitLab Issues](https://gitlab.com/tmobile/ere/memory-bank/-/issues)
- Discussions: Teams channel [RE - SkyNet Support - AI Discussion](https://teams.microsoft.com/l/channel/19%3A7130c6f6eb354efda1d4b3fa89546215%40thread.tacv2/RE%20-%20SkyNet%20Support%20-%20AI%20Discussion?groupId=4f72c46d-e46e-43b9-a3d6-1de811294cf8&tenantId=be0f980b-dd99-4b19-bd7b-bc71a09b026c), or email Eric Nolan (eric.c.nolan@t-mobile.com)
