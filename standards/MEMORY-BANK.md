# Memory Bank Standard

A structured system for maintaining persistent project context across AI coding sessions.

## Overview

The Memory Bank pattern solves the "context amnesia" problem in AI-assisted development. Instead of re-explaining your project every session, you maintain structured files that AI reads automatically.

## File Structure

```
memory-bank/
├── projectbrief.md      # Non-negotiable requirements (rarely changes)
├── systemPatterns.md    # Architecture decisions, code patterns
├── techContext.md       # Tech stack, dependencies, environment
├── activeContext.md     # Current focus, recent decisions
└── progress.md          # Completed, in-progress, planned work
```

## File Purposes

### projectbrief.md
**The "constitution" of your project** - fundamental requirements that rarely change.

Contains:
- Core business purpose and goals
- Non-negotiable constraints (performance, compliance, technical)
- Success metrics
- Key stakeholders

Update when: Core requirements change (rare)

### systemPatterns.md
**Established architectural patterns** that AI must follow.

Contains:
- Architecture decisions (microservices, monolith, etc.)
- Code patterns (error handling, async patterns, etc.)
- Frontend patterns (state management, styling, etc.)
- "Never do this" rules
- Testing patterns

Update when: New patterns established, anti-patterns discovered

### techContext.md
**Complete technical environment** specification.

Contains:
- Development environment (OS, IDE, tools)
- Backend stack (languages, frameworks, databases)
- Frontend stack (frameworks, build tools, UI libraries)
- Infrastructure (Docker, services, ports)
- External service constraints

Update when: Dependencies change, services added, config updated

### activeContext.md
**Current session state** - what you're working on right now.

Contains:
- Current focus area
- Recent decisions made this session
- Next steps (priority ordered)
- Known issues and blockers
- Environment status (running services, git state)

Update when: Every session, when focus changes, at milestones

### progress.md
**Project-wide progress tracker**.

Contains:
- Completed features (checked off)
- In-progress work
- Planned work (backlog)
- Known bugs
- Version history

Update when: Features completed, bugs found, milestones reached

## File Size Guidelines

Keep Memory Bank files focused and scannable:

| File | Target | Max | If Exceeded |
|------|--------|-----|-------------|
| projectbrief.md | 50-80 lines | 150 | Review - should rarely grow |
| systemPatterns.md | 100-180 lines | 300 | Consolidate similar patterns |
| techContext.md | 150-250 lines | 400 | Move details to docs/ |
| activeContext.md | 50-100 lines | 150 | Archive to `docs/ARCHIVE.md` |
| progress.md | 100-250 lines | 400 | Archive old versions |

## What Must Never Appear in Memory Bank Files

Memory Bank files are version-controlled and loaded into AI context on every request. Never store:

- Secrets, API keys, tokens, passwords, or credentials
- PII: names, emails, phone numbers, SSNs, customer identifiers
- Production data samples or database exports
- Full code file dumps (reference file paths instead)
- Internal IP addresses, hostnames, or network topology

## Rule Loading

### Cursor IDE

Create `.cursor/rules/memory-bank.mdc`:

```yaml
---
alwaysApply: true
---

# Memory Bank - Persistent Context

At the start of every conversation (and after any context compaction), silently read ALL files in memory-bank/ to restore context.
Never ask the user to repeat constraints already documented there.

## Files to Read (in order)
1. memory-bank/projectbrief.md - Non-negotiable constraints
2. memory-bank/systemPatterns.md - Patterns to follow
3. memory-bank/techContext.md - Tech stack details
4. memory-bank/activeContext.md - Current focus
5. memory-bank/progress.md - What's done/planned

## Rules
- Never violate constraints in projectbrief.md
- Always follow patterns in systemPatterns.md
- Don't ask for info already in techContext.md
- Update Memory Bank after significant changes
```

### Claude Code

Create `CLAUDE.md` in project root with Memory Bank instructions (see template).

## Claude Code vs Cursor: Context Lifecycle

These two tools load memory-bank rules differently — the difference matters for context management.

### Cursor IDE
`.cursor/rules/memory-bank.mdc` with `alwaysApply: true` **re-injects** the memory-bank instruction on every response. Even after context fills, rules are always present.

### Claude Code
`CLAUDE.md` loads **once at session start** as part of the system prompt. It is NOT re-injected after auto-compaction.

Claude Code auto-compacts at approximately **75% context** — silently, with no hook or notification to the agent. The session continues with a compressed summary; detailed history is lost.

### Implications for Handoff Thresholds

| Tool | Handoff Threshold | Why |
|------|------------------|-----|
| Claude Code | **65%** | Fires before 75% auto-compaction |
| Cursor | **80%** | Rules re-inject automatically; compaction less critical |

### Post-Compaction Recovery (Claude Code)
If compaction fires before handoff, instruct the agent to re-read all `memory-bank/` files:
```
Please re-read all memory-bank/ files to restore full context
```
The `templates/CLAUDE.md` includes a compaction recovery instruction block that handles this automatically when observed.

## Handoff Protocol

When context fills up (user reports 65% in Claude Code, 80% in Cursor), create a handoff:

### Trigger
- User types "Handoff"
- User reports context >= 65% (Claude Code) or >= 80% (Cursor)
  - Claude Code auto-compacts at ~75%; 65% fires before that
  - Cursor rules re-inject on every response; 80% is safe

### Agent Actions
1. **STOP** all work immediately
2. **CREATE** `handoff.md` in project root:
   - Summary of accomplishments
   - Files modified this session
   - Current service state
   - Commands to resume
   - Pending tasks
   - Context for next agent
3. **RESPOND** only: "Handoff ready at `handoff.md`. Start a new conversation."
4. **STOP RESPONDING** - do not continue

### Next Session
1. Check for `handoff.md` - if exists, read it FIRST
2. Continue work from where previous agent stopped
3. Merge handoff info into Memory Bank when appropriate
4. Delete `handoff.md` after merging

## Task Decomposition

For multi-session work, create `plan.md`:

```markdown
# Plan: [Feature Name]

## Scope
Brief description of what we're building.

## Chunks (each fits one session)
- [ ] Chunk 1: Backend API endpoints
- [ ] Chunk 2: Database schema + migrations
- [ ] Chunk 3: Frontend components
- [ ] Chunk 4: Integration + testing

## Handoff Points
After each chunk, update activeContext.md and commit.

## Dependencies
- Chunk 2 depends on Chunk 1
- Chunks 3-4 can start after Chunk 2
```

### Scope Heuristics

| Task Type | Estimated Sessions | Planning |
|-----------|-------------------|----------|
| Single file change | < 1 | No planning needed |
| Feature (1 component) | 1 | May need handoff |
| Feature (multi-file) | 1-2 | Consider plan.md |
| New service/module | 2-3 | Definitely plan.md |
| Large refactor | 3+ | Break into phases |

## Quick Commands

Teach AI to recognize these shortcuts:

| Command | Action |
|---------|--------|
| `mb update` | Update all relevant Memory Bank files |
| `mb status` | Show file sizes, timestamps, health check |
| `mb archive` | Move old history to `docs/ARCHIVE.md` |
| `mb slim` | Trim activeContext.md to essentials |
| `mb commit` | Stage and commit Memory Bank changes |

## Auto-Update Behavior

Agent should proactively update Memory Bank:

- After completing feature/fix → progress.md
- After adding dependencies → techContext.md
- After establishing patterns → systemPatterns.md
- At session end ("done", "wrap up") → offer to update

## Integration with AGENTS.md

If your project uses AGENTS.md for session history:

- **Memory Bank**: Structured, curated knowledge (organized by topic)
- **AGENTS.md**: Chronological session log (detailed history)
- **handoff.md**: Temporary transition document (delete after merging)

## Success Indicators

Memory Bank is working when:
- ✅ AI never asks for your tech stack
- ✅ AI follows established patterns without prompting
- ✅ New sessions start immediately productive
- ✅ Decisions persist across sessions
- ✅ Code consistency improves
- ✅ Less time explaining, more time building

## Troubleshooting

### AI Not Loading Memory Bank
1. Check rule file exists (`.cursor/rules/memory-bank.mdc` or `CLAUDE.md`)
2. Verify `alwaysApply: true` is set (Cursor)
3. Restart IDE
4. Explicitly reference: `@memory-bank/projectbrief.md`

### Memory Bank Getting Stale
1. Review `activeContext.md` weekly
2. Archive old decisions to `docs/ARCHIVE.md`
3. Update `progress.md` after each milestone
4. Clean up outdated information

### Memory Bank Too Large
1. Move detailed session logs to `docs/ARCHIVE.md`
2. Remove implementation details (keep decisions only)
3. Consolidate related patterns
4. Archive historical context to `docs/ARCHIVE.md`
