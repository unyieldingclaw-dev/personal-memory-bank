# Hooks Guide

Hooks run deterministically at Claude Code lifecycle points. Unlike `CLAUDE.md` (which is advisory — Claude can drift), hooks **always execute** and can block or modify Claude's actions.

## Hook Types

| Hook | When it fires | Primary use |
|------|--------------|-------------|
| `PreToolUse` | Before Claude runs a tool | Block dangerous operations, validate inputs |
| `PostToolUse` | After Claude runs a tool | Auto-format, run lint, log actions |
| `Stop` | When Claude pauses for input | Desktop notification |
| `PreCompact` | Before context compaction | Save state summary |

## Default Hooks in This Standard

Configured in `.claude/settings.json`:

### 1. Dangerous-Command Blocker (`PreToolUse`)

Intercepts Bash tool calls before they run using `scripts/dangerous-commands.ps1` (PowerShell) with bash fallback. Enforces 3-tier safety:

**BLOCK** (11 patterns — command exits non-zero, Claude stops):
`rm -rf` · `mkfs` · `dd if=` · `git push --force` · `git push -f` · `DROP TABLE` · `DROP DATABASE` · `| bash` · `| sh` · `|bash` · `|sh`

**CONFIRM** (5 patterns — surfaces confirmation dialog):
`git filter-branch` · `git update-ref` · `sudo rm` · `chmod -R 777` · `--no-verify`

**WARN** (4 patterns — exits 0, surfaces access alert):
`id_rsa` · `.pem` · `.env.production` · `credentials.json`

If BLOCK is triggered, Claude sees the block message and stops. The command never runs. CONFIRM and WARN surface the access to Claude so it can decide.

Implemented in `scripts/dangerous-commands.ps1` (Windows/pwsh) and `scripts/dangerous-commands.sh` (POSIX/bash). The hook calls `pwsh -NonInteractive -File scripts/dangerous-commands.ps1 2>/dev/null || bash scripts/dangerous-commands.sh 2>/dev/null || true` — it fails open if neither runtime is available.

### 2. Stop Notification (`Stop`) — removed from template

The Stop hook was removed from `templates/.claude/settings.json` because it causes indefinite hangs in `--Remote-Control` mode (Claude in Chrome). In that mode Claude runs headless; the hook fires but no user is present to dismiss the Windows MessageBox, stalling the session permanently. If you need a Stop notification in an interactive-only project, add it to that project's local `.claude/settings.json` manually.

### 3. PostToolUse Lint (`PostToolUse`)

Runs `npm run lint` after every `Write` or `Edit` tool call and streams the last 10 lines of output back to Claude, so lint errors appear immediately without a separate step.

**Why `|| true`?**  
`|| true` ensures the hook always exits 0. This matters for non-Node projects that have no `package.json` or no `lint` script — without it the hook would exit non-zero and Claude would treat every file write as an error. With `|| true` the hook is a best-effort advisory: output when lint is available, silent when it isn't.

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
