# Hooks Guide

Hooks run deterministically at Claude Code lifecycle points. Unlike `CLAUDE.md` (which is advisory — Claude can drift), hooks **always execute** and can block or modify Claude's actions.

## Hook Types

| Hook | When it fires | Primary use |
|------|--------------|-------------|
| `PreToolUse` | Before Claude runs a tool | Block dangerous operations, validate inputs |
| `PostToolUse` | After Claude runs a tool | Auto-format, run lint, log actions |
| `Stop` | When Claude pauses for input | Desktop notification |
| `PreCompact` | Before context compaction | Save state summary |

## Enforcement Layer Architecture

Hooks are one layer in a four-layer enforcement stack. Understanding which layer owns which concern prevents duplication and drift:

| Layer | Kind | Owns | Does NOT own |
|-------|------|------|-------------|
| **CLAUDE.md** | Advisory | Behavioral norms, workflow philosophy, code style | Anything requiring guaranteed execution |
| **Hooks** | Deterministic structural | Per-tool-call pattern enforcement: dangerous commands, credential access | Semantic correctness, business logic review |
| **Reviewer / Opponent** | Semantic | Spec compliance, scope drift, code quality | Mechanical pattern matching |
| **CI** | Deterministic gate | Codebase invariants: file size, forbidden imports, secret scanning | Real-time per-command interception |

**Design rule:** Don't duplicate concerns across layers. If a check belongs in CI, adding it to hooks creates two places to update when patterns change. If a check is semantic, adding it to hooks creates false confidence (simple pattern matching misses context). Each layer does its job; the stack as a whole provides defense in depth.

## Default Hooks in This Standard

Configured in `.claude/settings.json`:

### 1. Dangerous-Command Blocker (`PreToolUse` — Bash + PowerShell tools)

Intercepts both Bash and PowerShell tool calls before they run using `scripts/dangerous-commands.ps1`. Enforces 3-tier safety:

**BLOCK** (19 patterns — command exits non-zero, Claude stops):\
*Shell:* `rm -rf` · `mkfs` · `dd if=` · `git push --force` · `git push -f` · `DROP TABLE` · `DROP DATABASE` · `| bash` · `| sh` · `|bash` · `|sh`\
*PowerShell-native:* `Remove-Item -Recurse -Force` · `Remove-Item -Force -Recurse` · `Format-Volume` · `| Invoke-Expression` · `|Invoke-Expression` · `| iex` · `|iex`

**CONFIRM** (5 patterns — surfaces confirmation dialog):
`git filter-branch` · `git update-ref` · `sudo rm` · `chmod -R 777` · `--no-verify`

**WARN** (4 patterns — exits 0, surfaces access alert):
`id_rsa` · `.pem` · `.env.production` · `credentials.json`

If BLOCK is triggered, Claude sees the block message and stops. The command never runs. CONFIRM and WARN surface the access to Claude so it can decide.

Implemented in `scripts/dangerous-commands.ps1` (Windows/pwsh) and `scripts/dangerous-commands.sh` (POSIX/bash). Configured in `.claude/settings.json` with two matchers — one for `Bash` (with sh fallback) and one for `PowerShell` (PS-only):

```json
{ "matcher": "Bash",       "command": "pwsh -NonInteractive -File scripts/dangerous-commands.ps1 2>/dev/null || bash scripts/dangerous-commands.sh 2>/dev/null || true" },
{ "matcher": "PowerShell", "command": "pwsh -NonInteractive -File scripts/dangerous-commands.ps1 2>/dev/null || true" }
```

**Hook error logging (G2):** if `dangerous-commands.ps1` fails unexpectedly, the catch block appends a timestamped entry to `.pmb-hook-errors.log` (gitignored). `mb doctor` Check 16 surfaces entries from this log as WARN.

### 2. Stop Notification (`Stop`) — excluded from install template

The Stop hook is excluded from `templates/.claude/settings.json` because it causes indefinite hangs in `--Remote-Control` mode (Claude in Chrome). In that mode Claude runs headless; the hook fires but no user is present to dismiss the Windows MessageBox, stalling the session permanently. PMB's own `.claude/settings.json` keeps this hook as a deliberate choice for interactive Windows sessions; it is excluded from the install template to prevent those hangs in remote/headless environments. If you need a Stop notification in an interactive-only project, add it to that project's local `.claude/settings.json` manually.

### 3. Contract Scope Check (`PreToolUse` — Write + Edit tools)

Checks whether a file being written is within the scope declared in the active task contract (`.claude/contracts/active-task.json`). Implemented in `scripts/check-contract.ps1` and `scripts/check-contract.sh`.

- **No contract / inactive contract:** exits 0 silently.
- **Out-of-scope write (default):** prints a warning and exits 0. Claude sees it and should pause.
- **Out-of-scope write (hard-block mode):** exits 2 (blocked) when `PMB_CONTRACT_HARD_BLOCK=1` is set in the `env` block of `.claude/settings.json`.

Set `PMB_CONTRACT_HARD_BLOCK=1` for sessions where scope discipline is critical. See `standards/SECURITY-GUARDRAILS.md` for the full env-block example.

**Hook error logging (G2):** unexpected errors are logged to `.pmb-hook-errors.log` via a `trap {}` wrapper.

### 4. Auto-Reviewed Update (`PostToolUse` — Write + Edit tools)

Fires after every `Write` or `Edit` tool call. Reads the edited file path from the tool input JSON (via `$input | Out-String`), checks whether it is inside `memory-bank/`, and updates the `last-reviewed:` frontmatter line to today's date if present.

**Why silent failure?** The hook must never block agent work. If the update fails (e.g. file not found, malformed frontmatter), the agent continues and the user can run `mb audit` to find stale files. Implemented in `scripts/update-reviewed.ps1` and `scripts/update-reviewed.sh`.

**Hook error logging (G2):** unexpected errors are logged to `.pmb-hook-errors.log`.

### 5. PreCompact Memory Gate (`PreCompact`)

Fires before Claude Code compacts context. Checks whether either of the two volatile memory-bank files (`memory-bank/activeContext.md`, `memory-bank/progress.md`) was modified today **or** `handoff.md` exists in the project root. If neither condition is met, prints an actionable warning so Claude can update state before the compaction window closes.

**Always exits 0** — compaction is never blocked. The gate is advisory: it surfaces the risk so Claude can act, but does not hard-stop the session.

**Detection logic:**
- Modified today: compares `LastWriteTime` (PowerShell) / `date -r` mtime (sh) to today's date
- Handoff present: checks for `handoff.md` in the project root

**Fails open:** if neither runtime is available or mtime cannot be determined, the hook exits 0 silently.

Implemented in `scripts/pre-compact-check.ps1` (Windows/pwsh) and `scripts/pre-compact-check.sh` (POSIX/sh):

```json
"PreCompact": [
  {
    "hooks": [
      {
        "type": "command",
        "command": "pwsh -NonInteractive -File scripts/pre-compact-check.ps1 2>/dev/null || bash scripts/pre-compact-check.sh 2>/dev/null || true"
      }
    ]
  }
]
```

Note: `PreCompact` hooks have no `matcher` field — the hook type applies to the compaction event itself, not to a specific tool.

## Adding Per-Project Hooks

Copy `.claude/settings.json` into your project, then add hooks as needed.

### Auto-Format After Edit (PostToolUse)

Add to the `PostToolUse` array in `settings.json`:

**Prettier (JavaScript/TypeScript):**
```json
{
  "matcher": "Write|Edit",
  "hooks": [{
    "type": "command",
    "command": "npx prettier --write \"$CLAUDE_TOOL_OUTPUT_PATH\" 2>/dev/null || true"
  }]
}
```

**Black (Python):**
```json
{
  "matcher": "Write|Edit",
  "hooks": [{
    "type": "command",
    "command": "python -m black \"$CLAUDE_TOOL_OUTPUT_PATH\" 2>/dev/null || true"
  }]
}
```

### Lint Before Commit (PreToolUse on Bash)

Add to the `PreToolUse` array (alongside the dangerous-command hook):
```json
{
  "matcher": "Bash",
  "hooks": [{
    "type": "command",
    "command": "echo \"$CLAUDE_TOOL_INPUT\" | grep -q 'git commit' && npm run lint 2>&1 || true"
  }]
}
```

## How to Add a Hook

1. Edit `.claude/settings.json` in your project root
2. Add the hook JSON to the appropriate lifecycle key
3. Test: run a command Claude would use and verify the hook fires correctly
4. Commit `settings.json` so the hook applies to all sessions in this project

## Reference

Full hook documentation: `claude hooks --help` or see the Claude Code docs.
