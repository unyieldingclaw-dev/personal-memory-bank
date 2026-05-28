# Personal Memory Bank - Quick Reference

One-page cheatsheet for daily use.

---

## Memory Bank Files

| File | Purpose | Update When |
|------|---------|-------------|
| `projectbrief.md` | Requirements, constraints, goals | Rarely |
| `systemPatterns.md` | Architecture, patterns, anti-patterns | New patterns |
| `techContext.md` | Tech stack, ports, environment | Tech changes |
| `activeContext.md` | Current focus, next steps | Every session |
| `progress.md` | Done, in progress, planned | Milestones |

---

## Quick Commands

| Command | What It Does |
|---------|--------------|
| `mb init` | Scaffold memory-bank/ in the current project |
| `mb status` | Show file sizes and health |
| `mb validate` | Verify required files and frontmatter are present |
| `mb audit` | See freshness — flag stale or overdue files |
| `mb update` | Get a prompt to update memory bank after a session |
| `mb commit` | Commit Memory Bank changes separately from feature code |
| `mb query TAG` | Find all memory tagged with TAG |
| `mb budget` | Check token overhead of CLAUDE.md + memory-bank/ |
| `mb compact` | Get an AI prompt to deduplicate and summarize memory |
| `mb upgrade` | Pull latest templates and standards from the memory bank repo |
| `mb doctor` | Full diagnostic — git, templates, hooks, file sizes, startup token cost |
| `Handoff` | Create handoff.md and stop |
| `/feature-dev` | Run full 7-phase workflow (Claude Code) |
| `/security-review` | Scan diff for 9 security patterns (Claude Code) |
| `/code-review` | Multi-agent deep review: 3 parallel role subagents (security, performance, style) + test coverage review (generates missing tests) + opponent auditor compare (Claude Code / Cursor) |
| `/test-audit` | Audit test coverage for changed files or full project; reports missing tests, empty test files, framework config, CI test step (Claude Code) |
| `/health-check` | Full PMB health check — runs mb doctor + mb validate + mb audit and prints summary (PMB repo only) |

---

## Handoff Process

**When to handoff:** Context reaches 40%

**What happens:**
1. Type "Handoff"
2. AI creates `handoff.md`
3. Start new conversation
4. AI reads handoff and continues

---

## Security Guardrails

| Tier | Action | Examples |
|------|--------|----------|
| **BLOCK** | AI refuses | Commit secrets, force push main, rule-file injection patterns, long-lived creds in agent env |
| **CONFIRM** | AI asks first | Delete files, amend commits, bulk ops on >3 files |
| **WARN** | AI notes risk | Large changes, missing tests, new files |

---

## File Size Limits

| File | Target | Max |
|------|--------|-----|
| projectbrief.md | 50-80 | 150 |
| systemPatterns.md | 100-180 | 300 |
| techContext.md | 150-250 | 400 |
| activeContext.md | 50-100 | 150 |
| progress.md | 100-250 | 400 |

---

## Code Quality Checklist

Before saying "done":
- [ ] Tests pass
- [ ] No lint errors
- [ ] Build succeeds
- [ ] WHY comments for complex logic
- [ ] No obvious comments
- [ ] Errors handled

---

## /code-review — How It's Structured

| Step | Role | Who runs it |
|------|------|-------------|
| 1 | Determine scope (git diff or explicit path) | Main agent |
| 2 | Gather context (git log per file) | Main agent |
| 3 | 🔐 Security · ⚡ Performance · 🎨 Style | 3 parallel subagents, uncorrelated contexts |
| 4 | 🧪 Test Coverage Review (generates missing tests) | Main agent |
| 5 | 🧑‍⚖️ Opponent Auditor (confirm / downgrade / false-positive) | Final subagent |
| 6 | Summary report with Auditor verdict column | Main agent |

**Why role separation?** Each subagent sees only the code and its own lens. A security finding can't bias how performance is read, and the auditor catches both misses and over-flags.

---

## Karpathy Coding Principles

Four rules that reduce common LLM over-engineering. Active in all projects via `~/.claude/CLAUDE.md`.

| # | Rule | What It Means |
|---|------|---------------|
| 1 | **Think Before Coding** | State assumptions, surface tradeoffs, ask before implementing |
| 2 | **Simplicity First** | Minimum code that solves the problem — no speculative features |
| 3 | **Surgical Changes** | Touch only what the request requires; remove only your own orphans |
| 4 | **Goal-Driven Execution** | Define success criteria upfront; verify before claiming done |

**These are working if:** diffs are smaller, rewrites due to overcomplication drop, and clarifying questions come *before* implementation.

---

## IDE Rule Files

| IDE | Location | Scope |
|-----|----------|-------|
| Cursor (project) | `.cursor/rules/*.mdc` | Single project |
| Cursor (global) | `~/.cursor/rules/*.mdc` | All projects |
| Claude Code (project) | `CLAUDE.md` | Single project |
| Claude Code (global) | `~/.claude/CLAUDE.md` | All projects |
| Any tool (global) | `~/.claude/AGENTS.md` | All projects, all tools |

---

## Task Planning

For multi-session work, create `plan.md`:

```markdown
## Chunks
- [ ] Chunk 1: Backend API
- [ ] Chunk 2: Database
- [ ] Chunk 3: Frontend
- [ ] Chunk 4: Testing
```

**Scope heuristics:**
- 1 file change = no planning
- 1 feature = 1 session
- 1 service = 1-2 sessions
- Large refactor = plan.md required

---

## Common Issues

| Problem | Solution |
|---------|----------|
| AI doesn't know context | Check rule files, restart IDE |
| Files too large | Run `mb compact`, then `mb status` |
| Handoff not working | Explicitly: "Read handoff.md" |
| Wrong patterns | Reference: `@memory-bank/systemPatterns.md` |

---

## Feature Workflow

For non-trivial features, follow this sequence:

```
Brainstorm → Spec → Plan → Implement (TDD) → Simplify → Security Review → Commit
```

In Claude Code: `/feature-dev` runs this automatically.
In Cursor: workflow.mdc enforces it via rules.

Skip to Implement for: single-file fixes, typos, config changes.

---

## Daily Workflow

```
Start Session -> AI reads Memory Bank automatically -> Work on tasks (use /feature-dev for new features) -> If context gets full -> Type "Handoff" -> Start new chat -> When done for the day -> "mb update" -> Commit
```
