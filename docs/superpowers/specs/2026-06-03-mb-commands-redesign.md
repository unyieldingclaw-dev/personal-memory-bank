# Spec: MB Commands Redesign (v1.0.7)

**Date:** 2026-06-03
**Status:** Approved
**Version target:** 1.0.7

---

## Problem

Two distinct issues addressed together:

1. **Natural language triggers missing.** `mb` subcommands have no protocol entry in CLAUDE.md, so Claude does not respond to "mb status", "mb doctor", etc. The same mechanism that handles "Handoff" needs to exist for `mb` commands.

2. **Command surface too broad.** 15 commands with overlapping concerns: three separate diagnostic commands (`audit`, `validate`, `budget`) alongside `doctor`; four advisory maintenance commands (`compact`, `update`, `archive`, `slim`) with no single entry point. Users must know which diagnostic command to run and when.

---

## Design

### 1. Natural Language Trigger Protocol

Add an `MB Commands Protocol` section to two CLAUDE.md-style files:
- `CLAUDE.md` (PMB's own) — place after the Handoff Protocol section
- `templates/CLAUDE.md` — same placement

```markdown
## MB Commands Protocol

When the user types "mb <subcommand>" (or "run mb <subcommand>"):

1. Run `mb <subcommand>` via shell (PowerShell on Windows, bash on Unix)
2. Report the output to the user

Recognized subcommands: `init`, `status`, `doctor`, `query`, `clean`, `commit`, `upgrade`, `help`
```

For the two Cursor rules files (`.cursor/rules/memory-bank.mdc` and `templates/cursor/rules/memory-bank.mdc`): these already have a **"Quick Commands" table** (lines 75–81) listing deprecated commands. Two changes required per file:
1. Replace the existing Quick Commands table with the 8 final commands (`init`, `status`, `doctor`, `query`, `clean`, `commit`, `upgrade`, `help`) and their descriptions
2. Add the same MB Commands Protocol section (identical to CLAUDE.md addition) after the Quick Commands table

---

### 2. Command Consolidation

**Final 8 commands:** `init`, `status`, `doctor`, `query`, `clean`, `commit`, `upgrade`, `help`

#### `mb doctor` absorbs `audit`, `validate`, `budget`

The three absorbed commands have complete standalone implementations already (`Show-Audit`/`Show-Validate`/`Show-Budget` in PS1; `show_audit`/`show_validate`/`show_budget` in bash). They are called from within the doctor function as additional output sections, appended after the existing 14 checks:

```
=== Lifecycle Audit ===
[existing show_audit / Show-Audit output]

=== Structural Validation ===
[existing show_validate / Show-Validate output]

=== Budget Estimate ===
[existing show_budget / Show-Budget output]
```

No logic changes to the absorbed implementations — just call them. All three sections run unconditionally on every `mb doctor` invocation.

#### `mb clean` (new) absorbs `compact`, `update`, `archive`, `slim`

All four absorbed commands are advisory print-only commands — they print guidance text or prompts; they do not write files. `mb clean` runs them in sequence:

1. **Slim check** — reports activeContext.md line count, warns if >150 lines (from `mb slim`)
2. **Unified maintenance prompt** — single combined AI prompt covering archive old content + compact summaries + update frontmatter fields (combines the three prompt-printing commands into one prompt the user can paste to Claude)

The unified prompt approach is preferred over printing three separate prompts sequentially, since all three advisory actions are typically done together in one Claude instruction.

#### `mb upgrade` absorbs `install-hooks`

The install-hooks logic (`Invoke-InstallHooks` PS1 lines 454–544; no bash equivalent currently) is added as a step in the upgrade flow, **after the TEMPLATE_OWNED processing block** in both scripts. Behavior: run directly, report results. The `--dry-run` flag on the parent `mb upgrade` command gates this step (if `--dry-run` is passed, the install-hooks step is also skipped).

---

### 3. Deprecated Command Redirects

When a user types a removed command name, they get a helpful redirect rather than a cryptic "not recognized" error.

**PowerShell (`mb.ps1`):**
PowerShell's `[ValidateSet()]` runs at parameter binding time, before the function body executes — removing deprecated names would trigger a generic binding error before any redirect code fires. Fix: **keep all deprecated names in ValidateSet** (they remain valid inputs), and add redirect cases in the switch statement that print the redirect message and exit. This allows tab-completion to continue working during the transition period and doesn't require restructuring the parameter block.

**Bash (`mb.sh`):**
Add explicit deprecated cases before the `*)` wildcard in the case statement.

**Redirect messages (both scripts):**

| Typed | Message |
|-------|---------|
| `mb compact` | `mb compact has been consolidated into mb clean. Run: mb clean` |
| `mb update` | `mb update has been consolidated into mb clean. Run: mb clean` |
| `mb archive` | `mb archive has been consolidated into mb clean. Run: mb clean` |
| `mb slim` | `mb slim has been consolidated into mb clean. Run: mb clean` |
| `mb audit` | `mb audit has been integrated into mb doctor. Run: mb doctor` |
| `mb validate` | `mb validate has been integrated into mb doctor. Run: mb doctor` |
| `mb budget` | `mb budget has been integrated into mb doctor. Run: mb doctor` |
| `mb install-hooks` | `mb install-hooks is now part of mb upgrade. Run: mb upgrade` |

---

### 4. Files Changed

14 files total. Task Contract required (crosses 4-file threshold).

**Scripts:**

| File | Change |
|------|--------|
| `mb.ps1` | Keep deprecated names in ValidateSet; add redirect cases to switch; new `Show-Clean` function; doctor expansion (call Show-Audit, Show-Validate, Show-Budget); upgrade expansion (add install-hooks step after TEMPLATE_OWNED); update `Show-Help` to list only 8 commands |
| `mb.sh` | Add deprecated cases to case statement; new `show_clean` function; doctor expansion; upgrade expansion (add install-hooks step after TEMPLATE_OWNED); update `show_help` to list only 8 commands |

**CLAUDE.md-style files (natural language trigger):**

| File | Change |
|------|--------|
| `CLAUDE.md` | Add MB Commands Protocol section after Handoff Protocol |
| `templates/CLAUDE.md` | Same |
| `.cursor/rules/memory-bank.mdc` | Update Quick Commands table to 8 commands; add MB Commands Protocol section |
| `templates/cursor/rules/memory-bank.mdc` | Same as above (files are identical; apply same changes) |

**Documentation (deprecated command references):**

| File | Change |
|------|--------|
| `docs/COMMANDS-REFERENCE.md` | Update command table (15 → 8); add redirect note; update `/health-check` step that references `mb validate + mb audit` |
| `README.md` | Update command list (~line 18, 76–82); update inline references to deprecated commands (~lines 167, 277) |
| `QUICK-REFERENCE.md` | Update command table (~lines 25–31, 40); update inline workflow examples (~lines 157, 181) |
| `docs/SETUP-GUIDE.md` | Update references to `mb update` and `mb compact` (~lines 220, 245) |
| `docs/UPGRADE.md` | Update references to `mb audit`, `mb compact`, `mb validate` (~lines 13, 38) |
| `docs/RECOVERY.md` | Update ~10 references to `mb validate`, `mb audit`, `mb compact` across the file |

**Version:**

| File | Change |
|------|--------|
| `CHANGELOG.md` | v1.0.7 entry |
| `VERSION` | Bump to 1.0.7 |

---

## Verification

After implementation, confirm:

1. `mb help` → output lists exactly 8 commands, no deprecated names
2. `mb doctor` → output includes `=== Lifecycle Audit ===`, `=== Structural Validation ===`, `=== Budget Estimate ===` sections after the 14 checks
3. `mb clean` → slim check runs, then unified maintenance prompt appears
4. `mb compact` → prints redirect message "consolidated into mb clean"
5. `mb audit` → prints redirect message "integrated into mb doctor"
6. `mb install-hooks` → prints redirect message "now part of mb upgrade"
7. `mb upgrade` → install-hooks step runs as part of the flow; `mb upgrade --dry-run` skips install-hooks step
8. Natural language test: type "mb status" in Claude → shell runs `mb status` and output is reported back
9. `README.md`, `QUICK-REFERENCE.md`, `RECOVERY.md` — grep for deprecated command names returns no matches in command-reference contexts
