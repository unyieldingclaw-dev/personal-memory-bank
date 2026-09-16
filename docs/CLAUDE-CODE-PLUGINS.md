# Claude Code Plugin Setup

How to configure Claude Code with plugins, global rules, and slash commands for the full Memory Bank workflow.

## Global Rules (The Big One)

**Claude Code DOES have global rules.** `~/.claude/CLAUDE.md` applies to every project automatically — you do not need to copy `CLAUDE.md` into each project.

```
~/.claude/
└── CLAUDE.md    ← applies to ALL projects
```

Setup:
```powershell
# Windows
Copy-Item .\templates\CLAUDE.md "$env:USERPROFILE\.claude\CLAUDE.md"
```

```bash
# macOS/Linux
cp ./templates/CLAUDE.md ~/.claude/CLAUDE.md
```

For project-specific overrides, add a `CLAUDE.md` to the project root — it merges with the global one.

---

## Recommended Plugin Stack

Plugins are configured in `~/.claude/settings.json` under `enabledPlugins`.

```json
{
  "enabledPlugins": {
    "superpowers@claude-plugins-official": true,
    "code-simplifier@claude-plugins-official": true,
    "context7@claude-plugins-official": true
  }
}
```

| Plugin | What It Does | Token Impact |
|--------|-------------|--------------|
| `superpowers` | Brainstorming, code-review, planning, debugging skills | Low |
| `code-simplifier` | Post-implementation cleanup and clarity review | Low |
| `context7` | Fetches live library/framework docs on demand | Low (on-demand only) |

**Note:** Security scanning is handled by the `/security-review` slash command (not a plugin) — it runs a 9-pattern scan on the current diff on demand.

**Rule of thumb:** 3 plugins max. More plugins = more context loaded per session = slower, more expensive.

### Installing Plugins

Claude Code downloads plugins automatically when listed in `enabledPlugins`. Just add the entry and restart.

To find available plugins: `claude.com/plugins` or search the Claude Code plugin marketplace.

---

## Custom Slash Commands

Slash commands live in `~/.claude/commands/` as markdown files. They're available in every session.

```
~/.claude/
└── commands/
    ├── feature-dev.md              ← /feature-dev
    ├── security-review.md          ← /security-review
    └── code-review.md              ← /code-review
```

### Setup

```powershell
# Windows
New-Item -ItemType Directory -Force -Path "$env:USERPROFILE\.claude\commands"
Copy-Item .\templates\claude-commands\*.md "$env:USERPROFILE\.claude\commands\"
```

### /feature-dev

Triggers the full 7-phase workflow (brainstorm → spec → plan → implement → simplify → security review → commit). Use this at the start of any non-trivial feature.

### /security-review

Scans the current git diff for 9 security patterns. Run after completing any feature before committing.

### /code-review

Deep multi-agent code review. Unlike `/security-review` (which runs a single 9-pattern pass), `/code-review` orchestrates four role-separated reviewers so their findings don't bias each other:

1. **Three parallel subagents** with uncorrelated contexts — 🔐 Security, ⚡ Performance, 🎨 Style & Standards. Each sees only the code and its own lens.
2. **Test Coverage Review** in the main agent — checks for tests on changed code across happy path, edge cases, and error paths. If tests are missing, it generates them (one test file per changed module).
3. **Opponent Auditor** — a final subagent that receives all findings and either *confirms*, *downgrades*, or marks each as *false positive*, and surfaces anything the three reviewers missed.
4. **Summary report** — Security / Performance / Style / Test Coverage tables, each with an "Auditor verdict" column, and an overall Approve / Request Changes / Needs Discussion verdict.

Usage: `/code-review` (git diff), `/code-review src/auth/login.py`, or `/code-review src/api/`. In Cursor, say "do a code review" or "review src/api/routes.py" — the `.cursor/rules/code-review.mdc` rule triggers the same flow.


---

## Auto-Memory System

Claude Code has a built-in auto-memory system at `~/.claude/projects/<project-hash>/memory/`. This is separate from `memory-bank/`.

| Feature | memory-bank/ | Auto-Memory |
|---------|-------------|-------------|
| What it stores | Project context, architecture, progress | User preferences, feedback, non-obvious facts |
| Who writes it | You + AI collaboratively | Claude Code automatically |
| Who reads it | Both Claude Code and Cursor | Claude Code only |
| Format | 5 structured markdown files | Individual memory files with frontmatter |

**Use both:**
- `memory-bank/` for project state (works in Cursor too)
- Auto-memory for Claude Code to remember your preferences and past feedback across all projects

---

## AGENTS.md (Cross-Tool Alternative)

`AGENTS.md` is a portable project-instruction convention. Codex loads it natively; other tools may
make it readable without treating it as their native always-loaded rule file.

Place it at the project root for portable project instructions. Codex's global path is
`~/.codex/AGENTS.md`; Claude Code and Cursor retain their own native paths. Do not assume one global
file is loaded by every tool.

Use AGENTS.md when:
- Your team uses multiple AI tools
- You want one file instead of maintaining `.cursor/rules/` + `CLAUDE.md` separately

Use separate files when:
- You want Cursor's glob scoping (language-specific rules for `*.py` files only)
- You want rule names visible in Cursor's UI

Use `AGENTS.md` for the shared project-level baseline and keep native files for platform-specific
features such as Cursor globs and executable hooks.

---

## Full Global Setup (One-Time)

```powershell
# 1. Global CLAUDE.md
Copy-Item .\templates\CLAUDE.md "$env:USERPROFILE\.claude\CLAUDE.md"

# 2. Global Codex AGENTS.md
New-Item -ItemType Directory -Force -Path "$env:USERPROFILE\.codex"
Copy-Item .\templates\AGENTS.md "$env:USERPROFILE\.codex\AGENTS.md"

# 3. Slash commands
New-Item -ItemType Directory -Force -Path "$env:USERPROFILE\.claude\commands"
Copy-Item .\templates\claude-commands\*.md "$env:USERPROFILE\.claude\commands\"

# 4. Settings (plugins)
# Edit ~/.claude/settings.json and add enabledPlugins block (see above)

# 5. Global Cursor rules
New-Item -ItemType Directory -Force -Path "$env:USERPROFILE\.cursor\rules"
Copy-Item .\templates\cursor\rules\*.mdc "$env:USERPROFILE\.cursor\rules\"
```

After this, every new project automatically has:
- Memory Bank protocol (reads memory-bank/ at session start)
- Security guardrails (BLOCK/CONFIRM/WARN)
- Code quality rules
- Logging standards
- Workflow rules (7-phase feature development)
- Karpathy Coding Principles (Think Before Coding, Simplicity First, Surgical Changes, Goal-Driven Execution)
- Rules-file integrity hygiene (`.cursor/rules/rules-file-integrity.mdc` — glob-scoped to `.cursorrules` / `CLAUDE.md` / `AGENTS.md` / `.mdc` / slash-command `.md` files)
- `/feature-dev`, `/security-review`, and `/code-review` slash commands

Run `mb init` in each project to scaffold `memory-bank/`, project-root `AGENTS.md`, native rule
files, and the project-local Codex compaction hooks.

---

## Verification

After setup, test each piece:

```
1. Slash commands:   Type /feature-dev → should trigger 7-phase workflow
2. Security review:  Type /security-review → should scan diff for 9 patterns
3. Code review:      Type /code-review → should spawn 3 role subagents + test coverage + auditor
4. Global CLAUDE.md: New session → Claude should follow memory-bank protocol without being told
5. AGENTS.md:        Start Codex in the project → it should load the project-root instructions
6. Codex hooks:      Run /hooks → review and trust the PMB project hooks
7. Cursor rules:     Ask "what rules are you following?" → should list security + quality rules
```
