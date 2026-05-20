# Hook Coverage Expansion — Design Spec

**Date:** 2026-05-20
**Status:** Approved
**Sub-project:** A of 4 (A: hooks → D: philosophy → C: CI → B: task contracts)

---

## Problem

The PreToolUse dangerous-command hook in `templates/.claude/settings.json` currently blocks 5 patterns inline inside a JSON string. At 17 patterns the inline approach becomes unreadable and unmaintainable. Current coverage also omits significant dangerous patterns (`curl | bash`, `chmod -R 777`, `--no-verify`, secrets access).

---

## Architecture

**External scripts** — the same pattern used by the existing `update-reviewed.ps1/.sh` PostToolUse hook:

- `templates/scripts/dangerous-commands.ps1` — PowerShell (Windows)
- `templates/scripts/dangerous-commands.sh` — Bash/POSIX (Mac/Linux)
- `templates/.claude/settings.json` — updated PreToolUse hook references external scripts instead of inline block

**3-tier enforcement** — maps to the existing BLOCK/CONFIRM/WARN model in `standards/SECURITY-GUARDRAILS.md`:

| Tier | Exit code | Message style |
|------|-----------|---------------|
| BLOCK | 1 | `BLOCK: <reason>` — hard refusal |
| CONFIRM | 1 | `CONFIRM REQUIRED: <reason> — run manually if intentional` |
| WARN | 0 | `WARNING: <reason>` — command proceeds, Claude sees it |

**Implementation rule:** Simple substring matching only. No regex engines. `$command.Contains(pattern)` in PowerShell, `case *pattern*` in shell.

**Centralized tier messages:** Each script defines three message templates at the top. All matching logic uses those variables — no custom text per pattern. This ensures consistent UX and parity between `.ps1` and `.sh`:

```powershell
$BLOCK_MSG   = "BLOCK: Dangerous command detected ({0}). Refusing."
$CONFIRM_MSG = "CONFIRM REQUIRED: {0} — run manually if intentional."
$WARN_MSG    = "WARNING: {0} detected in command. Proceeding."
```

**Rationale comments:** Each pattern in the scripts has a one-line comment stating WHY it exists. Patterns without rationale become cargo cults; documented rationale prevents governance creep.

**Fails-open:** If the script file is missing or errors, the hook exits 0 (command proceeds). Safety net, not a hard dependency. On failure, scripts must print a loud error before exiting:

```
[HOOK ERROR] dangerous-commands.ps1 failed unexpectedly.
Proceeding in fails-open mode.
```

Silent failure creates false confidence — the error must be visible even though the command is allowed to proceed.

---

## Pattern Set

### BLOCK (9 patterns)

| Pattern | Reason |
|---------|--------|
| `rm -rf` | Recursive deletion — irreversible |
| `mkfs` | Filesystem format — irreversible |
| `dd if=` | Disk wipe/dump — irreversible |
| `git push --force` | Force push long form |
| `git push -f` | Force push short form |
| `DROP TABLE` | SQL table drop |
| `DROP DATABASE` | SQL database drop |
| `\| bash` | Command piped to bash (curl\|bash, wget\|bash, etc.) |
| `\| sh` | Command piped to sh |

### CONFIRM (5 patterns)

| Pattern | Reason |
|---------|--------|
| `git filter-branch` | History rewriting — advanced, rarely intentional |
| `git update-ref` | Low-level ref manipulation |
| `sudo rm` | Privileged deletion |
| `chmod -R 777` | World-writable recursive |
| `--no-verify` | Bypasses pre-commit hooks |

### WARN (4 patterns)

| Pattern | Reason |
|---------|--------|
| `id_rsa` | SSH private key access |
| `.pem` | Certificate/key file access |
| `.env.production` | Production secrets |
| `credentials.json` | Credential file access |

Secrets access is WARN (not BLOCK/CONFIRM) because legitimate workflows exist: cert management, deployment scripts, SSH key setup. The warning surfaces the access; it does not block it.

---

## Excluded Patterns

- `*.key` — too broad, matches `api_key`, `public_key`, `ssh_keyscan`, env vars, docs, examples
- `git rebase --onto` — used in normal workflows; force-push coverage already captures downstream danger
- localStorage grep / forbidden imports — CI scope, not hook scope (Sub-project C)

---

## Files to Modify / Create

| Action | File |
|--------|------|
| Modify | `templates/.claude/settings.json` — replace inline PreToolUse block with external script reference |
| Create | `templates/scripts/dangerous-commands.ps1` |
| Create | `templates/scripts/dangerous-commands.sh` |

---

## Hook Invocation in settings.json

The updated PreToolUse hook (PowerShell/Windows path, with POSIX fallback):

```json
{
  "type": "command",
  "command": "pwsh -NonInteractive -File templates/scripts/dangerous-commands.ps1 2>/dev/null || bash templates/scripts/dangerous-commands.sh 2>/dev/null || true",
  "event": "PreToolUse",
  "matcher": "Bash"
}
```

The hook receives the tool input as stdin JSON with a `command` field. Scripts read `$input` (PS) or stdin (sh), extract the command string, run 3-tier matching, exit accordingly.

---

## Verification

1. **BLOCK test:** `echo "rm -rf /tmp/test"` as bash command → hook exits 1 with `BLOCK: rm -rf` message
2. **CONFIRM test:** `git filter-branch` → hook exits 1 with `CONFIRM REQUIRED` message
3. **WARN test:** `cat id_rsa` → hook exits 0 with `WARNING` message, command proceeds
4. **Pass-through test:** `git status` → no hook output, exits 0, proceeds cleanly
5. **Missing script test:** rename `.ps1` temporarily → hook exits 0 (fails open), `[HOOK ERROR]` message printed to stderr

---

## Constraint

> No governance mechanism should require more governance than the code it protects.

This design uses ~60 lines of straightforward pattern matching per script. No dependencies, no build step, no test framework. The scripts are self-evidently correct by inspection.
