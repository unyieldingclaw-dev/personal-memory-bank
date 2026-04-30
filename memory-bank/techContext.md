# Technical Context - Memory Bank Standard

**Last Updated**: April 10, 2026

## Development Environment

| Component | Value |
|-----------|-------|
| OS | Windows 10/11 (primary), macOS/Linux (supported) |
| Shell | PowerShell 5.1+ (Windows), Bash 4+ (macOS/Linux) |
| IDE | Cursor (primary), VS Code with Claude (secondary) |
| Git | Required for version control |
| Package Manager | None required (template-based distribution) |

## Repository Structure

```
C:\Users\ENolan2\cursor\Memory-Bank\
├── README.md                    # Overview and quick start
├── .gitignore                   # Ignore patterns
├── memory-bank/                 # This project's own context
│   ├── projectbrief.md
│   ├── systemPatterns.md
│   ├── techContext.md           # (this file)
│   ├── activeContext.md
│   └── progress.md
├── standards/                   # Full standard documentation
│   ├── MEMORY-BANK.md
│   ├── SECURITY-GUARDRAILS.md
│   ├── CODE-QUALITY.md
│   ├── LOGGING.md               — Structured logging specification (v1.2.0)
│   ├── WORKFLOW.md              — 7-phase feature workflow (v1.3.0)
│   └── extensions/
│       ├── python.md
│       ├── typescript.md
│       └── _template.md
├── templates/                   # Files to copy to projects
│   ├── memory-bank/
│   ├── AGENTS.md                — Cross-tool rules (Claude Code + Cursor + Codex + Gemini) (v1.3.0)
│   ├── claude-commands/
│   │   ├── feature-dev.md       — /feature-dev slash command
│   │   └── security-review.md   — /security-review slash command
│   ├── cursor/rules/
│   │   ├── enterprise-logging.mdc
│   │   └── workflow.mdc
│   ├── CLAUDE.md
│   ├── handoff.md
│   └── plan.md
├── scripts/                     # Setup and utility scripts
│   ├── init-memory-bank.ps1
│   ├── init-memory-bank.sh
│   └── mb.ps1
├── docs/                        # Documentation
│   ├── SETUP-GUIDE.md
│   ├── QUICK-REFERENCE.md
│   ├── CURSOR-VS-CLAUDE.md
│   ├── GLOBAL-RULES-SETUP.md
│   └── CLAUDE-CODE-PLUGINS.md   — Plugin setup guide (v1.3.0)
├── training/                    # Onboarding materials
│   ├── presentation.html
│   └── exercises/
│       ├── 01-basic-setup.md
│       ├── 02-handoff-practice.md
│       ├── 03-task-planning.md
│       └── 04-security-quality.md
└── examples/                    # (empty - for future examples)
```

## File Formats

### Markdown Files (`.md`)
- Standard GitHub-flavored Markdown
- Tables for structured data
- Code blocks with language hints
- No special processing required

### Cursor Rule Files (`.mdc`)
- YAML frontmatter between `---` delimiters
- `alwaysApply: true` for global rules
- `globs: ["**/*.py"]` for file-specific rules
- Markdown content after frontmatter

### HTML Files (`.html`)
- Self-contained (no external dependencies)
- Inline CSS for styling
- Minimal JavaScript for interactivity
- Works offline

### Shell Scripts
- PowerShell (`.ps1`): Windows native
- Bash (`.sh`): macOS/Linux native
- No external dependencies
- Self-documenting with help text

## IDE Configuration

### Cursor

Rule files location: `.cursor/rules/`

| File | Purpose | Scope |
|------|---------|-------|
| `memory-bank.mdc` | Memory Bank loading | All files |
| `security.mdc` | Security guardrails | All files |
| `code-quality.mdc` | Quality standards | All files |
| `python.mdc` | Python patterns | `**/*.py` |
| `typescript.mdc` | TypeScript patterns | `**/*.ts`, `**/*.tsx` |

User-level rules: `~/.cursor/rules/` (Windows: `%USERPROFILE%\.cursor\rules\`)

### Claude Code

Rule file location: `CLAUDE.md` in project root

~/.claude/CLAUDE.md is supported as a global user-level rules file (applies to all projects)

## Configuration

### Environment Variables

None required. All configuration is file-based.

### .gitignore Entries

Standard ignores added by setup script:
```
.superpowers/      # Brainstorming sessions
handoff.md         # Temporary handoff file
```

## Compatibility

### Supported IDEs
| IDE | Version | Support Level |
|-----|---------|---------------|
| Cursor | Any | Full |
| VS Code + Claude | Any | Full |
| Other | - | Templates may work, not tested |

### Supported Platforms
| Platform | Shell | Status |
|----------|-------|--------|
| Windows 10+ | PowerShell | Full support |
| macOS | Bash/Zsh | Full support |
| Linux | Bash | Full support |

## Dependencies

**Runtime Dependencies**: None

**Development Dependencies**: None

**Distribution**: Template copy (no package manager)

## Related Projects

### Reference Implementation
The RMI Deconfliction Tool project serves as the reference implementation:
- Location: `C:\Users\ENolan2\cursor\Deconflit`
- Uses all three standards
- Has project-specific rule files
- Full memory-bank populated

### Future Integrations
- Internal GitLab repository (planned)
- npm package (considered)
- VS Code extension (future)
