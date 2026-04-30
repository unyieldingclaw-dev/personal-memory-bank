# Global Rules Setup

How to configure user-level rules that apply to ALL your projects.

## Overview

Instead of copying Memory Bank rules to every project, you can set up **global rules** that apply automatically.

| Approach | Scope | Best For |
|----------|-------|----------|
| **Per-Project** | Single project | Project-specific patterns |
| **User-Level** | All your projects | Personal preferences |
| **Organization** | All team projects | Company standards |

## Cursor: User-Level Rules

### Location

```
~/.cursor/
└── rules/
    ├── memory-bank.mdc
    ├── security.mdc
    ├── code-quality.mdc
    ├── enterprise-logging.mdc
    ├── workflow.mdc
    └── accessibility.mdc     ← glob-scoped to UI files (.html, .jsx, .tsx, .vue, .svelte, .astro, .css, .scss)
```

On Windows: `C:\Users\<username>\.cursor\rules\`

### Setup

1. Create the rules directory:
   ```powershell
   # Windows
   mkdir "$env:USERPROFILE\.cursor\rules"
   
   # macOS/Linux
   mkdir -p ~/.cursor/rules
   ```

2. Copy rule files:
   ```powershell
   # Windows
   Copy-Item .\templates\cursor\rules\*.mdc "$env:USERPROFILE\.cursor\rules\"
   
   # macOS/Linux
   cp ./templates/cursor/rules/*.mdc ~/.cursor/rules/
   ```

3. Restart Cursor

### How It Works

- User rules apply to ALL projects
- Project rules override user rules for specific patterns
- Memory Bank files are still per-project (they contain project-specific info)

### Recommended Setup

**User-Level** (apply everywhere):
- `security.mdc` - Security guardrails
- `code-quality.mdc` - Quality standards

**Project-Level** (project-specific):
- `memory-bank.mdc` - Memory Bank loading (references project's memory-bank/)
- Language-specific rules

### Example User-Level security.mdc

```yaml
---
alwaysApply: true
---

# Global Security Guardrails

## TIER 1: BLOCK
- NEVER commit files matching: *.env*, *credentials*, *secret*, *.pem, *.key
- NEVER git push --force to main/master
- NEVER run destructive system commands

## TIER 2: CONFIRM
- Deleting files
- Amending commits
- Skipping git hooks

## TIER 3: WARN
- Large changes (>5 files)
- Creating new files
- Missing tests
```

## Claude Code: Global Rules via ~/.claude/CLAUDE.md

Claude Code supports global rules via `~/.claude/CLAUDE.md`. This file applies to **every project automatically** — no copying needed.

```
~/.claude/
└── CLAUDE.md    ← applies to ALL projects, all sessions
```

### Setup (One-Time)

```powershell
# Windows
Copy-Item .\templates\CLAUDE.md "$env:USERPROFILE\.claude\CLAUDE.md"
```

```bash
# macOS/Linux
cp ./templates/CLAUDE.md ~/.claude/CLAUDE.md
```

That's it. Every new project inherits the Memory Bank protocol, security guardrails, and quality rules automatically.

### Project-Specific Overrides

Add a `CLAUDE.md` to the project root for project-specific instructions. It merges with the global one — project settings take precedence where they conflict.

### AGENTS.md: The Cross-Tool Alternative

`AGENTS.md` at `~/.claude/AGENTS.md` works like the global `CLAUDE.md` but is also readable by Cursor, Codex, and Gemini CLI. One file, every tool.

```powershell
# Windows - global AGENTS.md
Copy-Item .\templates\AGENTS.md "$env:USERPROFILE\.claude\AGENTS.md"
```

See `docs/CLAUDE-CODE-PLUGINS.md` for the full Claude Code setup including plugins and slash commands.

## Organization-Wide Rules

### Approach 1: Shared Repository

1. Create a repo with standard rules:
   ```
   org-coding-standards/
   ├── cursor-rules/
   │   ├── security.mdc
   │   └── code-quality.mdc
   ├── CLAUDE.md
   └── install.ps1
   ```

2. Developers run install script:
   ```powershell
   .\org-coding-standards\install.ps1
   ```

### Approach 2: Package Manager

Distribute as a package:

**npm (for JS/TS projects):**
```json
{
  "name": "@org/coding-standards",
  "postinstall": "node setup-rules.js"
}
```

**pip (for Python projects):**
```python
# setup.py with post-install script
```

### Approach 3: Git Submodule

Include standards as a submodule:
```bash
git submodule add https://github.com/org/coding-standards .standards
```

Then symlink or copy rules during setup.

## Combining Global and Project Rules

### Cursor Precedence

1. Project rules (`.cursor/rules/`) - Highest priority
2. User rules (`~/.cursor/rules/`) - Default
3. Built-in Cursor rules - Lowest

### Recommended Split

| Rule Type | Level | Rationale |
|-----------|-------|-----------|
| Security | User/Org | Same everywhere |
| Code Quality | User/Org | Consistent standards |
| **Accessibility** | **User/Org** | **WCAG 2.1 AA; glob-scoped to UI files so backend projects see no noise** |
| Logging | User/Org | Production defaults (structlog / pino) |
| Workflow | User/Org | 7-phase feature flow |
| Memory Bank | Project | Project-specific content |
| Language Rules | Project | Stack varies |
| Patterns | Project | Architecture varies |

### Example Project Override

If your project uses different security rules:

```yaml
# .cursor/rules/security.mdc (project-level)
---
alwaysApply: true
---

# Project Security Rules

# Override: Allow force push to feature branches in this repo
## TIER 2: CONFIRM (moved from BLOCK)
- git push --force to feature/* branches
```

## Verification

### Check Active Rules

In Cursor, ask:
> "What rules are you following?"

The AI should list rules from both user and project level.

### Test Security Rules

Try:
> "Commit the .env file"

AI should refuse (BLOCK tier).

### Test Memory Bank

> "What is this project about?"

AI should answer from `memory-bank/projectbrief.md`.

## Troubleshooting

### User Rules Not Loading

1. Check directory exists: `~/.cursor/rules/`
2. Check file extension: `.mdc` not `.md`
3. Check frontmatter: `alwaysApply: true`
4. Restart Cursor

### Project Rules Not Overriding

1. Ensure project rules are in `.cursor/rules/`
2. Check for typos in rule names
3. Project rules should have same structure as user rules

### Rules Conflicting

If user and project rules conflict:
1. Project rules win
2. Be explicit about overrides
3. Document in `CLAUDE.md` or project README

## Best Practices

### DO
- Put universal rules (security, quality) at user level
- Keep project-specific content in project rules
- Document which rules are global vs project
- Version control your rule templates

### DON'T
- Put project-specific patterns in global rules
- Assume everyone has the same global rules
- Forget to update both when standards change

## Templates

### Minimal User Rules

Just security:
```
~/.cursor/rules/
└── security.mdc
```

### Standard User Rules

Security + quality:
```
~/.cursor/rules/
├── security.mdc
└── code-quality.mdc
```

### Full User Rules

Everything reusable:
```
~/.cursor/rules/
├── security.mdc
├── code-quality.mdc
├── python.mdc
└── typescript.mdc
```

Then projects only need `memory-bank.mdc` and custom patterns.
