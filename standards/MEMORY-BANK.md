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

## Authority Tiers

Memory Bank files have explicit authority levels. When an agent encounters a contradiction
between files, the higher-tier file governs. The agent must surface the conflict and ask
the user to resolve it before changing a higher-tier decision.

| Tier | Level | Files | Behavior |
|------|-------|-------|----------|
| 1 | IMMUTABLE | projectbrief.md | Never negotiated; overrides all other files |
| 2 | STABLE | systemPatterns.md, techContext.md | Change requires deliberate decision + user confirm |
| 3 | VOLATILE | activeContext.md | Session state; evict stale content weekly |
| 4 | ACCUMULATING | progress.md | Archive to `docs/archive/` partitioned by category |

**Conflict resolution:** `projectbrief.md` > `systemPatterns.md` / `techContext.md` >
`activeContext.md` > `progress.md`. Agents must not silently reconcile contradictions —
they must flag them.

## File Size Guidelines

Keep Memory Bank files focused and scannable:

| File | Target | Max | If Exceeded |
|------|--------|-----|-------------|
| projectbrief.md | 50-80 lines | 150 | Review - should rarely grow |
| systemPatterns.md | 100-180 lines | 300 | Consolidate similar patterns |
| techContext.md | 150-250 lines | 400 | Move details to docs/ |
| activeContext.md | 50-100 lines | 150 | Archive to `docs/archive/` |
| progress.md | 100-250 lines | 400 | Archive old versions |

## Eviction Criteria

Content should leave Memory Bank files on objective criteria, not agent judgment.

| File | Condition | Action |
|------|-----------|--------|
| activeContext.md | Entry > 14 days old and not an active blocker | Move to `docs/archive/context/YYYY-MM-<topic>.md` |
| activeContext.md | "Next Steps" item completed | Move to `progress.md` immediately |
| activeContext.md | Issue marked resolved | Delete — do not archive |
| progress.md | Work completed > 6 months ago | Move to `docs/archive/progress/YYYY-MM-<topic>.md` |
| progress.md | Bug fixed > 3 months ago | Move to `docs/archive/progress/YYYY-MM-<topic>.md` |

Run `mb audit` to surface files that are stale or due for review.

## Archive Structure

Archival is partitioned by category to remain searchable. A monolithic `docs/archive/`
becomes a retrieval dead-zone as it grows; partitioned directories stay queryable.

```
docs/archive/
  context/     YYYY-MM-<topic>.md   (evicted from activeContext.md)
  progress/    YYYY-MM-<topic>.md   (evicted from progress.md)
  decisions/   YYYY-MM-<topic>.md   (evicted from systemPatterns.md — rare)
```

When archiving, create a new file in the appropriate subdirectory named with the current
month and a short topic label (e.g., `2026-05-auth-refactor.md`). Never append to an
existing archive file — keep each file focused on one topic or time period.

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

## Worktree Guidance

`memory-bank/` is canonical and lives in the **main worktree** only.

- From a git subworktree, read memory-bank/ from the main worktree root:
  ```bash
  $(git rev-parse --git-common-dir)/../memory-bank/
  ```
- Never update or commit memory-bank/ files from within a subworktree. Update the
  main worktree instead, then pull the changes into your branch if needed.
- `mb commit` detects subworktrees and refuses with a redirect message.

This keeps a single authoritative copy. Subworktrees are ephemeral execution branches;
the memory-bank is shared state.

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
| `mb archive` | Move old history to `docs/archive/` |
| `mb slim` | Trim activeContext.md to essentials |
| `mb commit` | Stage and commit Memory Bank changes |

## Auto-Update Behavior

Agent should proactively update Memory Bank:

- After completing feature/fix → progress.md
- After adding dependencies → techContext.md
- After establishing patterns → systemPatterns.md
- At session end ("done", "wrap up") → offer to update

## Tag-Based Retrieval

Each memory-bank file carries YAML frontmatter with hierarchical tags:

```yaml
tags:
  - auth/session
  - infra/postgres
```

Use `domain/concept` format. Flat tags (`auth`, `session`) are not used — they accumulate
synonym drift and require maintenance discipline that rarely survives project scale.

`mb query <keyword>` searches tags and section headers across all memory-bank files.
Partial hierarchical matches work: `mb query auth` matches `auth/session`, `auth/oauth`.

**Upgrade path:** Tags are embedding labels. To add semantic retrieval later, wire the
`tags:` field to a vector pipeline — no structural changes to the files required.

## Memory Compaction

Compaction is distinct from eviction. Eviction removes stale entries. Compaction rewrites,
summarizes, deduplicates, and resolves contradictions across all memory-bank files.

**When to compact:** when `mb audit` shows ≥ 2 files stale AND `memory-bank/` total size
exceeds 60 KB. Run `mb compact` to get a structured AI prompt for the operation.

**What compaction does (AI-driven):**
1. Reads all files in authority order
2. Identifies: duplicate decisions, contradictory claims, orphaned sections, entries
   already captured elsewhere
3. Rewrites each file to its canonical minimal form
4. Reports what was removed and why

Compaction requires human review of the AI's output before committing. It is never
fully automatic — the AI proposes, the human approves.

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
2. Archive old decisions to `docs/archive/`
3. Update `progress.md` after each milestone
4. Clean up outdated information

### Memory Bank Too Large
1. Move detailed session logs to `docs/archive/`
2. Remove implementation details (keep decisions only)
3. Consolidate related patterns
4. Archive historical context to `docs/archive/`
