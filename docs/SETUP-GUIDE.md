# Personal Memory Bank - Setup Guide

A step-by-step guide to implementing the Memory Bank in your project.

## Prerequisites

- A supported coding assistant (Claude Code, Codex, or Cursor)
- A project to add Memory Bank to
- 15-30 minutes for initial setup

## One-Time Global Setup (Do This First)

Run this once on your machine. It installs the `mb` command, Claude Code rules and slash commands,
and Cursor user rules. Project-local Codex instructions and hooks are installed by `mb init`.

**Windows:**
```
install.bat
```

**Mac/Linux:**
```bash
chmod +x install.sh && ./install.sh
```

This copies the Claude Code and Cursor global files to their native locations, then registers the
`mb` utility on your PATH. There is no single global instruction path shared by every tool.

After global setup, run `mb init` in each project to scaffold Memory Bank and its project-local
Claude Code, Codex, and Cursor integration files.

## Quick Start (5 minutes)

### Option 1: Use mb init (Recommended)

Navigate to your project directory and run:

```bash
mb init
```

This creates the `memory-bank/` directory, adds `CLAUDE.md`, `AGENTS.md`, and `.cursor/rules/` when
missing, installs `.codex/hooks.json`, and delivers the Claude Code and Codex hook scripts.

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
   │   ├── workflow.mdc
   │   └── rules-file-integrity.mdc
   ├── .codex/
   │   └── hooks.json               # Codex compaction gate + recovery
   ├── scripts/
   │   ├── codex-compaction-hook.sh
   │   └── codex-compaction-hook.ps1
   ├── CLAUDE.md                    # Claude Code project instructions
   └── AGENTS.md                    # Codex project instructions; portable where supported
   ```
   Note: The global setup does not replace project-local `.codex/hooks.json`; Codex hooks are
   trusted per definition in each project.

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
4. The AI should read all five Memory Bank files first, then `handoff.md` as an ephemeral supplement

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

### Codex

`AGENTS.md` supplies the project-local protocol. `.codex/hooks.json` adds an enforceable
pre-compaction gate and a post-compaction recovery instruction, but project hooks do not run until
their exact definition is trusted.

1. Open Codex from the project root
2. Run `/hooks`, inspect the PMB hook definitions, and trust them
3. Make sure `memory-bank/activeContext.md` and `memory-bank/progress.md` are current
4. Run `/compact` and verify that the recovery instruction causes all five Memory Bank files to be
   reread before work resumes

If `.codex/hooks.json` changes, its hash changes and Codex requires another `/hooks` review. Local
feature settings or managed policy may disable project hooks; in that case `AGENTS.md` remains
advisory and cannot guarantee the gate.

## Daily Usage

### Starting a Session

1. Open your project in Claude Code, Codex, or Cursor
2. Start AI conversation
3. AI automatically has full context

### During Development

Use quick commands:
- `mb status` - Quick state check (initialized, memory fresh, standards loaded, tasks tracked)
- `mb update` - Update files after changes

### Ending a Session

1. If context is getting full (approaching 40%), type "Handoff"
2. Or type "done" and AI will offer to update Memory Bank

### Continuing After Handoff

1. Start new conversation
2. AI reads all five Memory Bank files first
3. AI reads `handoff.md` second, reconciles it with `activeContext.md`, and verifies git/test state
4. AI merges durable state into Memory Bank, deletes the spent handoff, and continues

## Troubleshooting

### AI Doesn't Know Project Context

1. Check Memory Bank files exist
2. Check rule files are in correct location
3. Restart IDE
4. Explicitly reference: `@memory-bank/projectbrief.md`

### Memory Bank Files Too Large

Run `mb clean` to get an AI prompt that deduplicates and summarizes memory, or manually:
1. Keep only current state in `activeContext.md`
2. Archive old completed items in `progress.md`
3. Run `mb doctor` to confirm sizes are back in range

### Handoff Not Working

1. Check AI understood "Handoff" command
2. Verify `handoff.md` was created
3. In new conversation, check if AI reads it
4. If not, explicitly say "Read handoff.md"

## Next Steps

1. **Complete global setup** — Run the one-time setup at the top of this guide
2. **Read the standards** — Memory Bank, Security Guardrails, Code Quality, Logging, Workflow, and Karpathy Coding Principles (all in CLAUDE.md after global setup)
3. **Add language extension** — Python/TypeScript rules are included
4. **Use `/feature-dev`** — Run this in Claude Code at the start of any new feature

## Getting Help

- [Memory Bank Standard](../standards/MEMORY-BANK.md) - Full documentation
- [Quick Reference](QUICK-REFERENCE.md) - One-page cheatsheet
- [Cursor vs Claude Code](CURSOR-VS-CLAUDE.md) - IDE differences
