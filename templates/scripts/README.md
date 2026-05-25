# templates/scripts/

This directory is **production infrastructure**, not examples. Every script here is
copied into adopter `scripts/` directories by `mb init`.

## Exported scripts (explicit allowlist)

- `dangerous-commands.sh` / `dangerous-commands.ps1` — blocks dangerous shell commands (PreToolUse/Bash)
- `check-contract.sh` / `check-contract.ps1` — enforces task contract scope (PreToolUse/Write|Edit)
- `update-reviewed.sh` / `update-reviewed.ps1` — auto-updates `last-reviewed` frontmatter (PostToolUse/Write|Edit)

## Adding a new script

1. Add the file(s) to this directory
2. Add the filename(s) to the allowlist in `scripts/mb.sh` `invoke_init()` and `scripts/mb.ps1` `Invoke-Init()`
3. The CI `template-integrity` job validates every reference in `templates/.claude/settings.json` exists here
