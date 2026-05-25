# mb upgrade — Design Spec

## Problem

`mb init` is a one-time setup operation. Templates evolve (new governance rules, anchors, hook scripts, cursor rules) but projects initialized from older versions stay frozen at init time. There is no mechanism to propagate governance changes to existing projects.

A concrete current example: the comment provenance anchor (3 lines) added to `CLAUDE.md` and `templates/CLAUDE.md` in PR #2 is absent from `templates/.cursor/rules/code-quality.mdc`. Projects using Cursor for governance have a drift gap today.

---

## Scope

Two deliverables:

1. **Immediate Cursor fix** — Add the comment provenance anchor to `templates/.cursor/rules/code-quality.mdc` (close current drift gap; ships with the next commit regardless of `mb upgrade` timeline)

2. **`mb upgrade` subcommand** — New `mb` command that propagates current template governance to an existing project

---

## Design

### Core Constraint: Deterministic, Non-Merging

`mb upgrade` is NOT a merge tool. It does not reconcile differences, detect conflicts, or apply partial patches. Upgrade authority is binary:

- **Template-owned files**: overwrite unconditionally
- **User-owned files**: compare and emit advisory diff — never write

This constraint is intentional. A reconciliation engine would be complex, error-prone, and magic. `mb upgrade` must stay inspectable and low-surprise. Every action it takes must be visible in the output, and every output line must be attributable to a deterministic rule.

---

### Ownership Manifest

Ownership is hardcoded as explicit arrays — NOT a config file. Ownership semantics are behavior, not data. A config file would invite accidental expansion of overwrite scope. The arrays live in `mb.sh` and `mb.ps1` with rationale comments.

**TEMPLATE_OWNED** — Safe to overwrite; pure governance substrate with no project-specific content:

```bash
TEMPLATE_OWNED=(
  # Cursor governance rules — pure governance substrate, no project customization expected
  ".cursor/rules/code-quality.mdc"
  ".cursor/rules/memory-bank.mdc"
  ".cursor/rules/workflow.mdc"
  ".cursor/rules/security.mdc"
  ".cursor/rules/code-review.mdc"
  ".cursor/rules/rules-file-integrity.mdc"
  # Claude Code settings — hook wiring, not project-specific
  ".claude/settings.json"
  # Hook scripts — deterministic enforcement scripts, no project customization
  "scripts/dangerous-commands.sh"
  "scripts/dangerous-commands.ps1"
  "scripts/check-contract.sh"
  "scripts/check-contract.ps1"
  "scripts/update-reviewed.sh"
  "scripts/update-reviewed.ps1"
  # Slash commands — governance workflow commands from templates, not project-specific
  ".claude/commands/code-review.md"
  ".claude/commands/feature-dev.md"
  ".claude/commands/security-review.md"
)
```

**ADVISORY_DIFF** — Compare only; emit diff advisory, never write:

```bash
ADVISORY_DIFF=(
  # CLAUDE.md is a user cognition surface — users annotate it with project-specific guidance
  "CLAUDE.md"
  # Agent definitions likely contain project-specific tool lists and instructions
  ".claude/agents/researcher.md"
  ".claude/agents/security-reviewer.md"
)
```

**Never touched** (not in either list, protected aggressively):
- `memory-bank/*` — operational context, never governance substrate
- Anything not explicitly enumerated above

---

### Output Format

Each file gets exactly one status line:

```
[=] .cursor/rules/code-quality.mdc (unchanged)
[~] .claude/settings.json (updated)
[+] scripts/update-reviewed.sh (added)
[?] scripts/check-contract.ps1 (template-owned source missing — skipped)
[!] CLAUDE.md (differs from template — review manually)
[=] CLAUDE.md (matches template)
```

Status codes:
- `[=]` — file present and content matches template (no action needed)
- `[~]` — file present but stale; overwritten with template (TEMPLATE_OWNED only)
- `[+]` — file absent; created from template (TEMPLATE_OWNED only)
- `[?]` — template-owned source is missing from the running `mb` installation; skipped with visible warning
- `[!]` — ADVISORY_DIFF file differs from template; no write, diff printed below

No silent skips. Every file in both arrays produces exactly one output line.

**ADVISORY_DIFF output format:**

```
[!] CLAUDE.md (differs from template — review manually)
    --- template/CLAUDE.md
    +++ CLAUDE.md
    @@ -12,0 +13 @@
    + # Project-specific note added by user
```

Diff output is capped at **20 lines**. If the diff exceeds this, truncate and append:

```
    ... (N more lines — compare manually with: diff <template-source> CLAUDE.md)
```

This prevents large CLAUDE.md divergence from becoming terminal spam. The cap applies per file in ADVISORY_DIFF.

If `diff` is unavailable, fall back to: `[!] CLAUDE.md (differs from template — compare manually with: diff <template-source> CLAUDE.md)`

---

### Command Interface

```
mb upgrade [--dry-run]
```

- **No flags**: perform upgrade (overwrite TEMPLATE_OWNED, emit advisory for ADVISORY_DIFF)
- **`--dry-run`**: show what would change without writing anything; all `[~]` and `[+]` become `[~?]` and `[+?]`

No `--backup` flag in this version (noted as future-compatible: easy to add later if users want pre-upgrade snapshots).

Exit codes:
- `0` — completed (including when advisory diffs were emitted — those are informational, not errors)
- `1` — hard failure (missing CWD, unreadable template, etc.)

**`[?]` (missing template source) exits 0** — the upgrade ran, this file was skipped. The warning is visible; the user can investigate.

---

### Template Source Discovery

`mb upgrade` locates templates relative to the `mb` script itself:

```bash
MB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TEMPLATES_DIR="$MB_DIR/../templates"
```

This is the same pattern used by `mb init`. If `TEMPLATES_DIR` does not exist, error and exit 1.

---

### Target Project Detection

`mb upgrade` must be run from inside a project managed by `mb init`. Detection: check for `memory-bank/` directory in CWD. If absent, print error and exit 1:

```
Error: No memory-bank/ directory found. Run 'mb upgrade' from the root of an mb-managed project.
```

---

### `mb help` Addition

The `upgrade` subcommand must appear in `mb help` output:

```
upgrade   Propagate current governance templates to this project
```

---

## Immediate Cursor Fix

Add the comment provenance anchor to `templates/.cursor/rules/code-quality.mdc`. The anchor closes the governance intent parity gap between Claude Code (CLAUDE.md) and Cursor (.cursor/rules/code-quality.mdc).

The 3 lines to add, under the `## Comments` / `### DO` section (after "Add WHY comments for non-obvious logic"):

```
- Comment the WHY, not the WHAT
- Do not invent rationale, optimization claims, or historical intent not supported by observable behavior, documentation, or explicit project guidance
- Treat dead-code identification as advisory unless non-use can be proven deterministically
```

This ships as a standalone commit before or alongside `mb upgrade` implementation.

---

## Governance Lifecycle

`mb upgrade` completes the four-phase governance lifecycle:

| Phase | Command | What it does |
|-------|---------|--------------|
| Install | `mb init` | One-time setup from templates |
| Validate | `mb doctor` | Health check — are governance files present and wired? |
| Audit | `mb audit` | Content check — are memory-bank files current? |
| Upgrade | `mb upgrade` | Propagate template evolution to existing project |

Each phase is deterministic, bounded, inspectable, and low-magic. `mb upgrade` must maintain this character. It does one thing: overwrite what it owns, report what it doesn't.

---

## Files to Modify

| File | Change |
|------|--------|
| `templates/.cursor/rules/code-quality.mdc` | Add 3-line comment provenance anchor |
| `scripts/mb.sh` | Add `upgrade` subcommand (~80 lines) + add `upgrade` to `show_help()` |
| `scripts/mb.ps1` | Add `upgrade` subcommand (~80 lines) + add `upgrade` to `Show-Help()` |

No new files beyond the plan document.

---

## Out of Scope

- `--backup` flag (future-compatible; add later if users request it)
- Partial patch / reconciliation / merge of any kind
- Upgrade of `memory-bank/` files (never)
- Network fetch of templates (templates are local, co-located with `mb` script)
- Automatic upgrade on `mb doctor` (upgrade is an explicit opt-in action)
