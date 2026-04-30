# Cursor vs Claude Code: IDE Comparison

How to use the Memory Bank Standard in different AI coding environments.

## Overview

| Feature | Cursor | Claude Code (VS Code) |
|---------|--------|----------------------|
| Rule System | `.cursor/rules/*.mdc` | `CLAUDE.md` |
| Rule Format | YAML frontmatter + Markdown | Plain Markdown |
| Auto-loading | `alwaysApply: true` | Automatic (project root) |
| Scoped Rules | Yes (globs) | Limited |
| Memory Bank | Same files | Same files |

## The Good News

**Memory Bank files are identical** for both IDEs:

```
memory-bank/
├── projectbrief.md      # Same
├── systemPatterns.md    # Same
├── techContext.md       # Same
├── activeContext.md     # Same
└── progress.md          # Same
```

Only the **rule loading mechanism** differs.

## Cursor Setup

### Rule File Location
```
your-project/
└── .cursor/
    └── rules/
        ├── memory-bank.mdc
        ├── security.mdc
        └── code-quality.mdc
```

### Rule File Format
```yaml
---
alwaysApply: true
---

# Rule Title

Rule content in Markdown...
```

### Scoped Rules (Optional)
```yaml
---
globs: ["**/*.py"]
---

# Python-Specific Rules

Only applies to Python files...
```

### Global User Rules
Cursor supports user-level rules that apply to ALL projects:

```
~/.cursor/rules/
├── memory-bank-global.mdc
└── security-global.mdc
```

These are useful for personal preferences or organization-wide standards.

## Claude Code Setup

### Rule File Location
```
your-project/
└── CLAUDE.md    # Single file in project root
```

### Rule File Format
```markdown
# Project Instructions for Claude

Plain Markdown - no special syntax needed.

## Memory Bank

At the start of every conversation (and after any context compaction), read all files in memory-bank/...

## Security Guardrails

### BLOCK
- Never commit secrets...
```

### No Scoped Rules
Claude Code doesn't support file-pattern-specific rules. All instructions in `CLAUDE.md` apply globally.

**Workaround**: Include conditional instructions:
```markdown
## Python Files
When working with `.py` files:
- Use black for formatting
- Run mypy for type checking
```

**Real-world example in this repo — Security (`.cursor/rules/security.mdc`):** uses `alwaysApply: true` so the BLOCK/CONFIRM/WARN guardrails fire on every file in every session. No scoping needed — security rules apply everywhere.

### Global User Rules via ~/.claude/CLAUDE.md
Claude Code supports global rules via `~/.claude/CLAUDE.md` — this file applies to **all projects automatically**. No copying needed.

```powershell
# Windows — one-time setup
Copy-Item .\templates\CLAUDE.md "$env:USERPROFILE\.claude\CLAUDE.md"
```

For project-specific overrides, add a `CLAUDE.md` to the project root. It merges with the global one.

**AGENTS.md alternative:** Place `AGENTS.md` at `~/.claude/AGENTS.md` for a single file readable by Claude Code, Cursor, Codex, and Gemini CLI. See `docs/CLAUDE-CODE-PLUGINS.md` for details.

## Side-by-Side Comparison

### Memory Bank Loading

**Cursor** (`.cursor/rules/memory-bank.mdc`):
```yaml
---
alwaysApply: true
---

# Memory Bank

At the start of every conversation (and after any context compaction), silently read ALL files in memory-bank/...
```

**Claude Code** (`CLAUDE.md`):
```markdown
# Project Instructions

## Memory Bank

At the start of every conversation (and after any context compaction), silently read ALL files in memory-bank/...
```

### Security Guardrails

**Cursor** (`.cursor/rules/security.mdc`):
```yaml
---
alwaysApply: true
---

# Security Guardrails

## TIER 1: BLOCK
- NEVER commit files matching: *.env*...
```

**Claude Code** (`CLAUDE.md`):
```markdown
## Security Guardrails

### BLOCK
- Never commit files matching: *.env*...
```

## Migration Between IDEs

### Cursor → Claude Code

1. Create `CLAUDE.md` in project root
2. Copy content from `.cursor/rules/*.mdc` files
3. Remove YAML frontmatter (`---` blocks)
4. Combine into single file with sections

### Claude Code → Cursor

1. Create `.cursor/rules/` directory
2. Split `CLAUDE.md` into separate `.mdc` files
3. Add YAML frontmatter to each:
   ```yaml
   ---
   alwaysApply: true
   ---
   ```
4. Delete or keep `CLAUDE.md` (doesn't hurt to have both)

## Using Both IDEs

If your team uses both Cursor and Claude Code:

1. **Keep Memory Bank identical** - Works in both
2. **Maintain both rule files**:
   - `.cursor/rules/*.mdc` for Cursor users
   - `CLAUDE.md` for Claude Code users
3. **Sync changes** - When updating rules, update both

### Automation

Create a script to sync rules:

```powershell
# sync-rules.ps1
# Combines Cursor rules into CLAUDE.md

$header = "# Project Instructions for Claude`n`n"
$content = Get-ChildItem .cursor/rules/*.mdc | ForEach-Object {
    $text = Get-Content $_ -Raw
    # Remove YAML frontmatter
    $text -replace '(?s)^---.*?---\s*', ''
}
$header + ($content -join "`n`n---`n`n") | Set-Content CLAUDE.md
```

## Feature Comparison

| Feature | Cursor | Claude Code |
|---------|--------|-------------|
| **Rule Files** | Multiple `.mdc` files | Single `CLAUDE.md` |
| **YAML Frontmatter** | Required | Not supported |
| **File Scoping** | `globs: ["*.py"]` | Not supported |
| **User-Level Rules** | `~/.cursor/rules/` | `~/.claude/CLAUDE.md` (global) |
| **Auto-reload** | Yes | Yes |
| **Memory Bank** | Full support | Full support |
| **Handoff Protocol** | Works | Works |
| **Quick Commands** | Works | Works |

## Recommendations

### For Cursor Users
- Use separate rule files for organization
- Use scoped rules for language-specific patterns
- Consider user-level rules for personal preferences

### For Claude Code Users
- Keep `CLAUDE.md` well-organized with clear sections
- Use headers to separate concerns
- Include language-specific guidance in relevant sections

### For Mixed Teams
- Maintain both `.cursor/rules/` and `CLAUDE.md`
- Use Memory Bank (identical in both)
- Document which IDE each team member uses

## Troubleshooting

### Cursor Rules Not Loading
1. Check `.cursor/rules/` folder exists
2. Verify `.mdc` extension (not `.md`)
3. Check `alwaysApply: true` in frontmatter
4. Restart Cursor

### Claude Code Not Reading CLAUDE.md
1. Check `CLAUDE.md` is in project root
2. Check file is not empty
3. Restart VS Code
4. Explicitly ask: "Read CLAUDE.md"

### Memory Bank Not Working in Either
1. Verify `memory-bank/` folder exists
2. Check files are not empty
3. Reference explicitly: `@memory-bank/projectbrief.md`
