# Personal Memory Bank

![Version](https://img.shields.io/badge/version-1.0.0-blue)  ![License](https://img.shields.io/badge/license-MIT-green)

Give your AI coding assistant persistent project memory — so every session starts where the last one left off, with full context about your project, stack, and decisions.

## The Problem It Solves

Every AI coding session starts blank. You re-explain your stack, re-describe your patterns, re-establish constraints. That overhead compounds across weeks and months.

Memory Bank solves this by keeping a small set of structured files in your project that your AI reads automatically at the start of every session.

## Install (Windows)

**1. Clone this repo**
```
git clone https://github.com/unyieldingclaw-dev/personal-memory-bank
cd personal-memory-bank
```

**2. Run the installer**
```
install.bat
```
Double-click it in Explorer, or run it from a terminal. Opens a new terminal automatically when done.

**3. In any project, run:**
```
mb init
```

That's it. Start a Claude Code or Cursor session — your AI will have context immediately.

---

**Mac / Linux:**
```bash
chmod +x install.sh && ./install.sh
```
Then in any project: `mb init`

---

## First Session

After `mb init`, open the two files that matter most:

```
memory-bank/projectbrief.md   ← what does this project do? (2-3 paragraphs)
memory-bank/techContext.md    ← what is your stack?
```

Fill those in. Everything else (systemPatterns, activeContext, progress) fills in naturally as you work.

Then run:
```
mb status
```

to confirm the memory bank is healthy before you start.

## Day-to-Day Commands

```
mb status     Check file sizes and health
mb validate   Verify required files and frontmatter are present
mb audit      See freshness — flag stale or overdue files
mb update     Get a prompt to update memory bank after a session
mb commit     Commit memory bank changes separately from feature code
mb query TAG  Find all memory tagged with TAG (e.g. mb query auth)
mb budget     Check token overhead of CLAUDE.md + memory-bank/
mb doctor     Full diagnostic (git, templates, hooks, file sizes)
mb help       Full command list
```

## How It Works

The memory bank is five markdown files in `memory-bank/`:

| File | What it holds | Changes how often |
|------|--------------|------------------|
| `projectbrief.md` | What the project does and must never do | Rarely |
| `systemPatterns.md` | Architecture decisions and code patterns | When patterns change |
| `techContext.md` | Stack, dependencies, environment | When stack changes |
| `activeContext.md` | What you're working on right now | Every session |
| `progress.md` | What's done, in progress, and planned | After completing work |

Your AI reads all five at the start of every session. You update them when things change. The `mb` utility helps you manage them.

## Advanced Features

These exist when you need them — you don't need to understand them to get started.

<details>
<summary>Authority hierarchy and conflict resolution</summary>

Files have explicit authority levels. When instructions conflict, higher authority wins:

`projectbrief.md` (immutable) → `systemPatterns / techContext` (stable) → `activeContext` (volatile) → `progress` (accumulating)

Your AI is instructed to surface conflicts rather than silently reconcile them.

</details>

<details>
<summary>Freshness tracking and eviction</summary>

Each memory bank file has frontmatter with `staleness-threshold` and `review-cycle`. The PostToolUse hook auto-updates `last-reviewed` whenever you edit a file.

Run `mb audit` to see which files are stale. Run `mb compact` to get an AI prompt that deduplicates and summarizes memory across all files.

</details>

<details>
<summary>Tag-based retrieval</summary>

Files use hierarchical tags (`auth/session`, `infra/postgres`) in their frontmatter. Run `mb query auth` to find all memory bank content related to auth — by tag or section header.

</details>

<details>
<summary>Worktree support</summary>

Memory bank lives in the main worktree only. `mb commit` detects and refuses mutations from git subworktrees, preventing split-brain memory.

</details>

<details>
<summary>AI commands (Claude Code)</summary>

Three slash commands are installed in `.claude/commands/`:

- `/code-review` — multi-agent review (security, performance, style, test coverage)
- `/feature-dev` — full 7-phase feature development workflow
- `/security-review` — scan current diff for 9 security patterns

</details>

<details>
<summary>Context handoff protocol</summary>

When Claude Code approaches its context limit, type `Handoff`. The AI creates `handoff.md` with a full summary of in-progress work. Start a new session — the AI reads `handoff.md`, merges it into memory bank, and continues from exactly where you left off.

</details>

## Troubleshooting

**`mb init` says templates not found**
Run `install.bat` again from the memory-bank repo directory.

**AI isn't reading the memory bank**
Check that `CLAUDE.md` is in your project root. For Cursor, verify `.cursor/rules/memory-bank.mdc` exists. Restart the IDE.

**Memory bank is getting large**
Run `mb status` to see which file is over its target. Run `mb compact` to get an AI prompt that rewrites and deduplicates memory.

**Something looks corrupted**
Run `mb doctor` for a full diagnostic.

## License

MIT
