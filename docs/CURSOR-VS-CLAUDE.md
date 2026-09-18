# Cursor vs Claude Code vs Codex: IDE Comparison

How to use the Memory Bank Standard in different AI coding environments.

## Overview

| Feature | Cursor | Claude Code (VS Code) | Codex |
|---------|--------|------------------------|-------|
| Rule System | `.cursor/rules/*.mdc` | `CLAUDE.md` | `AGENTS.md` |
| Rule Format | YAML frontmatter + Markdown | Plain Markdown | Plain Markdown |
| Auto-loading | `alwaysApply: true` | Automatic (project root) | Automatic (project root) |
| Scoped Rules | Yes (globs) | Limited | Limited |
| Memory Bank | Same files | Same files | Same files |

## The Good News

**Memory Bank files are identical** across all three:

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

**AGENTS.md baseline:** Put `AGENTS.md` at the project root for Codex and other tools that support
the convention. Codex's global path is `~/.codex/AGENTS.md`; Claude Code and Cursor continue to use
their native global paths. There is no universal `~/.claude/AGENTS.md` path.

## Codex Setup

### Rule File Location
```
your-project/
└── AGENTS.md    # Single file in project root, same convention CLAUDE.md follows
```

### Rule File Format
```markdown
# Project Instructions for Codex

Plain Markdown - no special syntax needed.

## Memory Bank

At the start of every conversation, and again after any context compaction, silently read ALL
files in `memory-bank/`...
```

### No Scoped Rules
Like Claude Code, Codex has no file-pattern-specific rule mechanism — everything in `AGENTS.md`
applies globally. The same conditional-instructions workaround used for Claude Code applies here.

### Global User Rules
Codex's global path is `~/.codex/AGENTS.md`, applied to all projects — distinct from Claude Code's
`~/.claude/CLAUDE.md` and Cursor's `~/.cursor/rules/`. There is no shared global path across tools.

### Hooks
Codex hooks live in `.codex/hooks.json` and run only after the exact file is explicitly trusted via
`/hooks` — untrusted project hooks do not run, and local feature or managed-policy settings can
disable them entirely even once trusted. This repo ships one hook, `SessionStart(source=compact)`,
which injects the memory-bank recovery checklist immediately after compaction (see Compaction and
Handoff Boundary below) — it does not gate or block anything before compaction.

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

**Codex** (`AGENTS.md`):
```markdown
# Project Instructions for Codex

## Memory Bank

At the start of every conversation, and again after any context compaction, silently read ALL
files in memory-bank/...
```

### Compaction and Handoff Boundary

| Platform | Enforceable before compaction | Recovery after compaction |
|----------|-------------------------------|---------------------------|
| Claude Code | Yes — `.claude/settings.json` `PreCompact` can block | `CLAUDE.md` requires the Memory Bank reread |
| Codex | No — `PreCompact`'s `continue: false` behavior ends the active turn with no visible remedy in the desktop UI, so this repo ships recovery-only | `SessionStart(source=compact)` injects the recovery checklist immediately, once `.codex/hooks.json` is trusted via `/hooks` |
| Cursor | No — `preCompact` is observational; the 40% trigger is advisory | `memory-bank.mdc` instructs the reread |

On every platform, Memory Bank is read first and `handoff.md` second. The handoff carries only
ephemeral in-flight state and never replaces the authoritative Memory Bank.

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

**Codex** (`AGENTS.md`):
```markdown
## Security Guardrails

- **BLOCK** (refuse): committing secrets, force-push to main/master...
```

## Migration Between IDEs

### Cursor → Claude Code / Codex

1. Create `CLAUDE.md` (or `AGENTS.md`) in project root
2. Copy content from `.cursor/rules/*.mdc` files
3. Remove YAML frontmatter (`---` blocks)
4. Combine into single file with sections

### Claude Code ↔ Codex

`CLAUDE.md` and `AGENTS.md` share the same plain-Markdown, no-frontmatter, single-file format and
the same lack of scoped rules — copying content across usually needs no restructuring, only a
find-and-replace of tool-specific paths (`.claude/` ↔ `.codex/`) and hook syntax.

### Claude Code / Codex → Cursor

1. Create `.cursor/rules/` directory
2. Split `CLAUDE.md`/`AGENTS.md` into separate `.mdc` files
3. Add YAML frontmatter to each:
   ```yaml
   ---
   alwaysApply: true
   ---
   ```
4. Delete or keep the original file (doesn't hurt to have both)

## Using Multiple IDEs

If your team uses Cursor, Claude Code, and/or Codex:

1. **Keep Memory Bank identical** - Works across all three
2. **Maintain each tool's rule file**:
   - `.cursor/rules/*.mdc` for Cursor users
   - `CLAUDE.md` for Claude Code users
   - `AGENTS.md` for Codex users
3. **Sync changes** - When updating rules, update every file in use

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

`AGENTS.md` can be generated the same way, or kept as a lightly-adapted copy of `CLAUDE.md` per
the Migration section above — this repo's own `AGENTS.md`/`CLAUDE.md` pair is maintained by hand,
not by this script.

## Feature Comparison

| Feature | Cursor | Claude Code | Codex |
|---------|--------|-------------|-------|
| **Rule Files** | Multiple `.mdc` files | Single `CLAUDE.md` | Single `AGENTS.md` |
| **YAML Frontmatter** | Required | Not supported | Not supported |
| **File Scoping** | `globs: ["*.py"]` | Not supported | Not supported |
| **User-Level Rules** | `~/.cursor/rules/` | `~/.claude/CLAUDE.md` (global) | `~/.codex/AGENTS.md` (global) |
| **Auto-reload** | Yes | Yes | Yes |
| **Memory Bank** | Full support | Full support | Full support |
| **Handoff Protocol** | Advisory/proactive | Blocking `PreCompact` gate | Advisory — `SessionStart` recovery only, no blocking gate |
| **Quick Commands** | Works | Works | Works |

## Recommendations

### For Cursor Users
- Use separate rule files for organization
- Use scoped rules for language-specific patterns
- Consider user-level rules for personal preferences

### For Claude Code Users
- Keep `CLAUDE.md` well-organized with clear sections
- Use headers to separate concerns
- Include language-specific guidance in relevant sections

### For Codex Users
- Keep `AGENTS.md` well-organized with clear sections, same as `CLAUDE.md`
- Trust `.codex/hooks.json` via `/hooks` so the post-compaction recovery checklist actually runs
- Don't rely on a blocking pre-compaction gate — none exists on this platform; treat the 40% handoff as proactive, the same way Cursor users do

### For Mixed Teams
- Maintain each tool's rule file in use (`.cursor/rules/`, `CLAUDE.md`, `AGENTS.md`)
- Use Memory Bank (identical across all three)
- Document which tool each team member uses

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

### Codex Not Reading AGENTS.md
1. Check `AGENTS.md` is in project root
2. Check file is not empty
3. Explicitly ask: "Read AGENTS.md"

### Codex Hooks Not Running
1. Check `.codex/hooks.json` exists and is valid JSON
2. Confirm it's trusted: run `/hooks` and verify it's listed as trusted, not just present
3. Check for a local feature flag or managed-policy setting disabling project hooks
4. Remember there is no pre-compaction blocking gate on this platform — only `SessionStart(source=compact)` fires, and only after compaction completes

### Memory Bank Not Working in Any
1. Verify `memory-bank/` folder exists
2. Check files are not empty
3. Reference explicitly: `@memory-bank/projectbrief.md`
