# Memory Bank Standard - Setup Guide

A step-by-step guide to implementing the Memory Bank Standard in your project.

## Prerequisites

- A code editor (Cursor or VS Code with Claude Code)
- A project to add Memory Bank to
- 15-30 minutes for initial setup

## One-Time Global Setup (Do This First)

Run this once on your machine. It installs rules, plugins, and slash commands that apply to **every project automatically** — no per-project copying needed.

```powershell
# 1. Global Claude Code rules (apply to all projects)
Copy-Item .\templates\CLAUDE.md "$env:USERPROFILE\.claude\CLAUDE.md"
Copy-Item .\templates\AGENTS.md "$env:USERPROFILE\.claude\AGENTS.md"

# 2. Claude Code slash commands
New-Item -ItemType Directory -Force -Path "$env:USERPROFILE\.claude\commands"
Copy-Item .\templates\claude-commands\*.md "$env:USERPROFILE\.claude\commands\"

# 3. Global Cursor rules (apply to all projects)
New-Item -ItemType Directory -Force -Path "$env:USERPROFILE\.cursor\rules"
Copy-Item .\templates\cursor\rules\*.mdc "$env:USERPROFILE\.cursor\rules\"

# 4. Enable plugins — edit ~/.claude/settings.json and add:
#    "enabledPlugins": {
#      "superpowers@claude-plugins-official": true,
#      "code-simplifier@claude-plugins-official": true,
#      "context7@claude-plugins-official": true
#    }
```

See [Claude Code Plugins](CLAUDE-CODE-PLUGINS.md) for the full plugin setup guide.

After global setup, the only per-project step is scaffolding the `memory-bank/` directory (below).

## Quick Start (5 minutes)

### Option 1: Use the Scaffold Script

**Windows (PowerShell):**
```powershell
# Navigate to your project
cd C:\path\to\your\project

# Run the scaffold script
.\path\to\memory-bank-standard\scripts\init-memory-bank.ps1
```

**macOS/Linux (Bash):**
```bash
# Navigate to your project
cd /path/to/your/project

# Run the scaffold script
bash /path/to/memory-bank-standard/scripts/init-memory-bank.sh
```

The script will:
1. Create `memory-bank/` directory with template files
2. Create `.cursor/rules/` with rule files (if using Cursor)
3. Create `CLAUDE.md` (if using Claude Code)
4. Add `.superpowers/` to `.gitignore`

### Option 2: Manual Setup

1. **Copy the templates folder** to your project:
   ```
   memory-bank-standard/templates/ → your-project/
   ```

2. **Your project should now have:**
   ```
   your-project/
   ├── memory-bank/
   │   ├── projectbrief.md
   │   ├── systemPatterns.md
   │   ├── techContext.md
   │   ├── activeContext.md
   │   ├── progress.md
   │   └── README.md
   ├── .cursor/rules/               # For Cursor (project-level)
   │   ├── memory-bank.mdc
   │   ├── security.mdc
   │   ├── code-quality.mdc
   │   ├── enterprise-logging.mdc
   │   └── workflow.mdc
   ├── CLAUDE.md                    # For Claude Code (project-level)
   └── AGENTS.md                    # Cross-tool (Claude Code + Cursor + Codex + Gemini)
   ```
   Note: If you completed the one-time global setup above, `CLAUDE.md` and the Cursor rules are already active globally — the per-project copies are for project-specific overrides only.

## Fill In Your Project Details (15-20 minutes)

### Step 1: projectbrief.md

Open `memory-bank/projectbrief.md` and fill in:

1. **Core Purpose** - What does your project do?
2. **Non-Negotiable Constraints** - What must always be true?
3. **Key Goals** - What are you trying to achieve?
4. **Success Metrics** - How do you measure success?

**Example:**
```markdown
## Core Purpose
E-commerce platform for selling handmade crafts, targeting small business owners who need a simple online store.

## Non-Negotiable Constraints
### Business Requirements
- Payment processing must be PCI-DSS compliant
- Orders must never be lost (zero data loss)
- Site must load in under 3 seconds

### Technical Constraints
- Must work on shared hosting (no Docker required)
- PostgreSQL for production, SQLite for development
- Mobile-first responsive design
```

### Step 2: techContext.md

Fill in your technology stack:

1. **Development Environment** - OS, IDE, tools
2. **Backend Stack** - Languages, frameworks, databases
3. **Frontend Stack** - Frameworks, build tools
4. **Services & Ports** - What runs where

**Example:**
```markdown
## Development Environment
| Component | Value |
|-----------|-------|
| OS | Windows 11 |
| Shell | PowerShell 7 |
| IDE | Cursor |
| Package Manager | pnpm |

## Backend Stack
- **Language**: Python 3.11
- **Framework**: FastAPI
- **Database**: PostgreSQL 15 (prod) / SQLite (dev)
- **ORM**: SQLAlchemy 2.0
```

### Step 3: systemPatterns.md

Document your architectural decisions:

1. **Architecture Patterns** - How is the system structured?
2. **Code Patterns** - Conventions to follow
3. **Never Do This** - Anti-patterns to avoid

**Example:**
```markdown
## Architecture Patterns

### API-First Design
**Decision**: All functionality exposed via REST API first, then UI built on top.
**Rationale**: Enables mobile app, third-party integrations, and clear separation.

## Never Do This
- ❌ Direct database queries in route handlers (use service layer)
- ❌ Hardcoded configuration (use environment variables)
- ❌ Commit without running tests
```

### Step 4: activeContext.md

Set up your current working context:

1. **Current Focus** - What are you working on now?
2. **Next Steps** - What's the priority?
3. **Environment Status** - What's running?

This file changes frequently - update it every session.

### Step 5: progress.md

Initialize your progress tracker:

1. **Completed Features** - What's done?
2. **In Progress** - What's being worked on?
3. **Planned** - What's coming next?

## Verify Setup

### Test the Memory Bank

1. Start a new AI conversation
2. Ask: "What is this project about?"
3. The AI should answer based on `projectbrief.md` without you explaining

### Test the Handoff

1. In your AI conversation, type: "Handoff"
2. The AI should create `handoff.md` and stop
3. Start a new conversation
4. The AI should read `handoff.md` and know the context

## IDE-Specific Setup

### Cursor

The `.cursor/rules/*.mdc` files are automatically loaded. Verify by:

1. Open Cursor
2. Start a new conversation
3. The AI should mention reading Memory Bank files

**If not working:**
- Check `.cursor/rules/` folder exists
- Verify files have `.mdc` extension
- Restart Cursor

### Claude Code

`~/.claude/CLAUDE.md` applies globally to all projects. Per-project `CLAUDE.md` files merge with it. Verify by:

1. Open any project in Claude Code
2. Start a new conversation
3. The AI should follow Memory Bank protocol without being told

**If not working:**
- Check `~/.claude/CLAUDE.md` exists (global) or `CLAUDE.md` exists in project root
- Restart Claude Code
- Explicitly ask: "Read CLAUDE.md"

**Slash commands** (`/feature-dev`, `/security-review`) require files in `~/.claude/commands/` — see the global setup section above.

## Daily Usage

### Starting a Session

1. Open your project in Cursor/VS Code
2. Start AI conversation
3. AI automatically has full context

### During Development

Use quick commands:
- `mb status` - Check Memory Bank health
- `mb update` - Update files after changes

### Ending a Session

1. If context is getting full (approaching 80%), type "Handoff"
2. Or type "done" and AI will offer to update Memory Bank

### Continuing After Handoff

1. Start new conversation
2. AI reads `handoff.md` automatically
3. Continue where you left off
4. AI merges handoff into Memory Bank

## Adding Team Members

When a new team member joins:

1. They clone the repo (Memory Bank included)
2. They open in Cursor or VS Code
3. They immediately have full project context

No onboarding documentation needed - it's in the Memory Bank.

## Troubleshooting

### AI Doesn't Know Project Context

1. Check Memory Bank files exist
2. Check rule files are in correct location
3. Restart IDE
4. Explicitly reference: `@memory-bank/projectbrief.md`

### Memory Bank Files Too Large

Run `mb slim` or manually:
1. Move detailed history to `AGENTS.md`
2. Keep only current state in `activeContext.md`
3. Archive old versions in `progress.md`

### Handoff Not Working

1. Check AI understood "Handoff" command
2. Verify `handoff.md` was created
3. In new conversation, check if AI reads it
4. If not, explicitly say "Read handoff.md"

## Next Steps

1. **Complete global setup** — Run the one-time setup at the top of this guide
2. **Read the standards** — Memory Bank, Security Guardrails, Code Quality, Logging, Workflow, and Karpathy Coding Principles (all in CLAUDE.md after global setup)
3. **If you work on UI code** — The [Accessibility standard](../standards/ACCESSIBILITY.md) (WCAG 2.1 Level AA) auto-applies via `.cursor/rules/accessibility.mdc` on `.html`, `.jsx`, `.tsx`, `.vue`, `.svelte`, `.astro`, `.css`, `.scss`. Run `/accessibility-review` for an on-demand deep audit.
4. **Add language extension** — Python/TypeScript rules are included
5. **Use `/feature-dev`** — Run this in Claude Code at the start of any new feature
6. **Share with team** — Each member runs global setup once; per-project memory-bank scaffolds automatically; Karpathy principles are included automatically

## Getting Help

- [Memory Bank Standard](../standards/MEMORY-BANK.md) - Full documentation
- [Accessibility Standard](../standards/ACCESSIBILITY.md) - WCAG 2.1 AA requirements for UI code
- [Quick Reference](QUICK-REFERENCE.md) - One-page cheatsheet
- [Cursor vs Claude Code](CURSOR-VS-CLAUDE.md) - IDE differences
