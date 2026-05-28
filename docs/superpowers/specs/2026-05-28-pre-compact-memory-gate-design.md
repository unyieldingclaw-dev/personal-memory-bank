# Pre-Compact Memory Gate — Design Spec

**Date:** 2026-05-28  
**Status:** Approved  

## Problem

Auto-compaction fires at 50% context. By the time it fires, there may not be enough budget remaining for Claude to act on any warning and write memory-bank files. The existing CLAUDE.md advisory ("compact manually at ~40%") is unenforced — Claude can drift or forget. Sessions compact with stale memory banks, and the next session starts cold.

## Goal

Ensure that before any compaction, Claude has a clear signal if the memory bank hasn't been updated and a specific action to take. Lower the compaction threshold to create buffer for that action.

## Design

### 1. Threshold Change

Lower `CLAUDE_AUTOCOMPACT_PCT_OVERRIDE` from `"50"` to `"40"` in:
- `.claude/settings.json`
- `templates/.claude/settings.json`

This gives Claude ~10% context buffer between when the hook fires and when context is exhausted — enough to write `activeContext.md` or create `handoff.md` before compaction.

### 2. PreCompact Hook

Add a `PreCompact` hook entry to `settings.json` (both PMB and template) pointing to the script pair:

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

The hook always exits 0. Compaction is never blocked.

### 3. Detection Logic

The script checks two conditions using file mtime — no frontmatter parsing:

**Pass (silent) if either is true:**
- `memory-bank/activeContext.md` or `memory-bank/progress.md` was modified today (mtime date = today's date)
- `handoff.md` exists in the project root

**Warn if neither is true:**
```
[PreCompact] Memory bank has not been updated this session and no handoff.md exists.
Update memory-bank/activeContext.md with current state, or run the Handoff Protocol
(create handoff.md) before compaction proceeds.
```

"Today" (same calendar date) is a reliable proxy for "this session" — sessions don't typically span midnight, and it requires no session tracking.

### 4. Script Files

Four new files following the exact pattern of `dangerous-commands.ps1/.sh`:

| File | Purpose |
|------|---------|
| `scripts/pre-compact-check.ps1` | PowerShell implementation |
| `scripts/pre-compact-check.sh` | Bash fallback |
| `templates/scripts/pre-compact-check.ps1` | Template copy distributed via `mb init` |
| `templates/scripts/pre-compact-check.sh` | Template copy distributed via `mb init` |

The template copies are identical to the project copies — same pattern as all other script pairs.

### 5. CLAUDE.md Updates

Two files reference the old 50% threshold and need surgical updates:
- `CLAUDE.md` (PMB project) — "auto-compact fires at 50%" → 40%; add PreCompact hook mention
- `templates/CLAUDE.md` — "compacts at ~50%" → 40%

The global `~/.claude/CLAUDE.md` also references 50% but is out of scope for this project's changes — flag to user separately.

### 6. HOOKS-GUIDE.md Update

Add a `PreCompact` section documenting: what fires it, the detection logic, why exits 0, and how to customize the memory-bank file list.

## Files Touched

| File | Operation |
|------|-----------|
| `.claude/settings.json` | Edit — add PreCompact hook, change threshold |
| `templates/.claude/settings.json` | Edit — add PreCompact hook, change threshold |
| `scripts/pre-compact-check.ps1` | Create |
| `scripts/pre-compact-check.sh` | Create |
| `templates/scripts/pre-compact-check.ps1` | Create |
| `templates/scripts/pre-compact-check.sh` | Create |
| `CLAUDE.md` | Edit — threshold reference + PreCompact hook mention |
| `templates/CLAUDE.md` | Edit — threshold reference |
| `docs/HOOKS-GUIDE.md` | Edit — add PreCompact section |

## Verification

1. Confirm `CLAUDE_AUTOCOMPACT_PCT_OVERRIDE` reads `"40"` in both settings files
2. Confirm `PreCompact` key exists in both settings files with correct command string
3. Run `scripts/pre-compact-check.ps1` manually with no `handoff.md` and no recent memory-bank writes — confirm warning is printed and exit code is 0
4. Run again after `touch memory-bank/activeContext.md` — confirm silent pass
5. Run again after creating `handoff.md` — confirm silent pass
6. Confirm `templates/scripts/` contains the new script pair
