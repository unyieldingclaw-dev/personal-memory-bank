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
