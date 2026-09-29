---
status: open
created: 2026-09-27
last-reviewed: 2026-09-27
staleness-threshold: 90d
related_plan: null
---

# PowerShell-matcher hooks have no bash fallback, so a missing .ps1 goes ungated

**Measured 2026-09-27.** Line numbers are from `.claude/settings.json` and
`templates/.claude/settings.json`, which are identical at these lines and unchanged since `739f0eb`
(`git diff --stat 739f0eb HEAD -- .claude/settings.json templates/.claude/settings.json` is empty).
Re-read the files before relying on the numbers.

## The three entries

Each `PowerShell`-matcher hook runs only the `.ps1` twin, ending `2>/dev/null || true`:

| Line | Event | Script |
|---|---|---|
| `:34` | PostToolUse | `review-reminders-post.ps1` |
| `:58` | PreToolUse | `dangerous-commands.ps1` |
| `:62` | PreToolUse | `review-reminders.ps1` |

The matching `Bash`-matcher entries (`:25`, `:45`, `:49`) add `|| bash scripts/X.sh` before
`|| true`.

## What happens when the .ps1 is missing

Tested 2026-09-27 on this machine: `pwsh -NonInteractive -File <missing file>` exits 64, prints its
usage text, and leaves stdin unread — a `cat` run after it in the same `{ …; } < payload` group
still received the whole payload.

- **Bash tool: the fallback runs.** The chain falls through to `bash scripts/X.sh`, which gets the
  payload intact. Whether the call is then denied was not tested; see "Not established".
- **PowerShell tool: ungated.** Nothing follows the failed `pwsh` except `|| true`, so the hook
  exits 0 and allows the call. For `:58` and `:62` that means neither the BLOCK/CONFIRM tiers nor the
  review gate run for PowerShell-tool calls.

How a single `.ps1` can go missing, and why `mb doctor` does not report it, is in
`docs/backlog/mb-upgrade-can-leave-a-half-review-gate-hook-pair.md` (skip-on-missing-source during
`mb upgrade`; a hook-script check that passes when either twin exists).

## Existing ownership is partial and stale

- `docs/superpowers/plans/2026-08-20-hook-enforcement-integrity.md` Task 3, "Give the
  PowerShell-matcher entry a fallback", covers `dangerous-commands.ps1` only. Its baseline table
  says "1 entry has no fallback at all | line 49, matcher `PowerShell`"; there are now three, at
  the lines above. The plan is gated on `[NS-32]` merging (its "Gate" and "Status as of
  2026-08-21" lines) and has not been executed.
- The plan's replacement form (Task 2 and Task 3) is
  `if command -v pwsh …; then pwsh -File X.ps1 …; else bash X.sh …; fi`. That selects `pwsh`
  whenever it is installed, so with `pwsh` present and the `.ps1` missing it never reaches bash —
  run here, the `pwsh` branch exited 64 and the `else` branch did not run. Applied to the `Bash`
  matcher it would lose the fallback that the `||` chain has today.
- `docs/backlog/replace-the-gh-pr-merge-deny-with-a-forced-permiss.md` already notes "The
  `PowerShell` matcher has no bash fallback", for the merge path only.

## Not established

- Whether a `Bash`-tool call is still denied. `pwsh` also writes its usage text to stdout, so the
  hook's stdout is that text followed by the `.sh` output, and whether Claude Code honours a deny
  that follows other text was not tested. If it does not, the `Bash` tool is ungated too, and a
  `||` fallback would not gate the `PowerShell` matcher either.
- Whether each `.sh` twin correctly parses a PowerShell-tool payload. That has to hold before a
  bash fallback on the `PowerShell` matcher is safe.
- Whether any adopter is in this state now. PMB's own `scripts/` and `templates/scripts/` hold all
  three `.ps1` files.

## Fix outline

Needs a spec, a task contract and a full `/code-review` and `/change-review`: it changes the hook
wiring that enforces the review gate and the BLOCK tier.

1. Give each of the three `PowerShell`-matcher entries a fallback that runs when the `.ps1` is
   absent, not only when `pwsh` is absent. Confirm first that the `.sh` twins parse the
   PowerShell-tool payload.
2. Refresh the 2026-08-20 plan: its baseline table, Task 3's scope (three entries, not one), and
   its `command -v pwsh` form, which does not cover a missing `.ps1`.
3. Mirror `.claude/settings.json` to `templates/.claude/settings.json`.

## Done when

- A wiring test, run in a scratch copy of the tree and never the real `scripts/`, deletes each
  `.ps1` in turn and shows the `PowerShell`-matcher entry still denies a
  guarded command (for example a `git commit` without a review marker), and the same test passes
  for the `Bash` matcher; and
- the 2026-08-20 plan no longer describes one entry, or is marked superseded by this item.
