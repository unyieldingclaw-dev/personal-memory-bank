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
    ├── code-review.md              ← /code-review
    └── accessibility-review.md     ← /accessibility-review
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

### /accessibility-review

On-demand WCAG 2.1 Level AA audit of UI code. Complements the always-on glob-scoped rule `.cursor/rules/accessibility.mdc` (which auto-applies to `.html`, `.jsx`, `.tsx`, `.vue`, `.svelte`, `.astro`, `.css`, `.scss`, `.sass`, `.less`).

The audit checks nine dimensions from `standards/ACCESSIBILITY.md`:

1. Semantic HTML (native elements, heading hierarchy, landmarks)
2. ARIA (roles, states, properties, `aria-live`)
3. Keyboard navigation (tab order, focus trap, skip nav)
4. Focus indicators (≥3:1 contrast)
5. Color & contrast (4.5:1 normal, 3:1 large)
6. Forms & inputs (labels, error association, `fieldset`/`legend`)
7. Images & media (`alt`, captions, transcripts)
8. Motion & animation (`prefers-reduced-motion`, flash limits)
9. Testing expectations (screen reader compatibility, accessibility tree)

Output is a findings table (severity × dimension × file:line) and a remediation checklist with code-level fixes for every CRITICAL or HIGH finding.

Usage: `/accessibility-review` (git diff), `/accessibility-review src/components/Form.tsx`, or `/accessibility-review src/pages/`.

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

`AGENTS.md` is an open standard readable by Claude Code, Cursor, Codex, and Gemini CLI.

Place it at the project root or globally at `~/.claude/AGENTS.md`. It combines the rules from all four `.cursor/rules/*.mdc` files into one file that any tool understands.

Use AGENTS.md when:
- Your team uses multiple AI tools
- You want one file instead of maintaining `.cursor/rules/` + `CLAUDE.md` separately

Use separate files when:
- You want Cursor's glob scoping (language-specific rules for `*.py` files only)
- You want rule names visible in Cursor's UI

Both approaches work. AGENTS.md is simpler; separate files are more powerful in Cursor.

---

## Full Global Setup (One-Time)

```powershell
# 1. Global CLAUDE.md
Copy-Item .\templates\CLAUDE.md "$env:USERPROFILE\.claude\CLAUDE.md"

# 2. Global AGENTS.md
Copy-Item .\templates\AGENTS.md "$env:USERPROFILE\.claude\AGENTS.md"

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
- `/feature-dev`, `/security-review`, `/code-review`, and `/accessibility-review` slash commands

The only per-project step remaining is running `init-memory-bank.ps1` to scaffold the `memory-bank/` directory with project-specific content.

---

## Verification

After setup, test each piece:

```
1. Slash commands:       Type /feature-dev → should trigger 7-phase workflow
2. Security review:      Type /security-review → should scan diff for 9 patterns
3. Code review:          Type /code-review → should spawn 3 role subagents + test coverage + auditor
4. Accessibility review: Type /accessibility-review → should audit UI files against WCAG 2.1 AA
5. Global CLAUDE.md:     New session → Claude should follow memory-bank protocol without being told
6. AGENTS.md:            In Cursor, type @AGENTS.md → rules should be visible
7. Cursor rules:         Ask "what rules are you following?" → should list security + quality rules
```
