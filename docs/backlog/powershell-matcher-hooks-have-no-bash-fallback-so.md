---
status: open
created: 2026-09-27
last-reviewed: 2026-09-29
staleness-threshold: 90d
related_plan: null
---

# PowerShell-matcher hooks have no bash fallback, so a missing .ps1 goes ungated

**Measured 2026-09-27.** Line numbers are from `.claude/settings.json` and
`templates/.claude/settings.json`, which are identical at these lines and unchanged since `739f0eb`
(`git diff --stat 739f0eb HEAD -- .claude/settings.json templates/.claude/settings.json` is empty).
Re-read the files before relying on the numbers. The plan and archive facts under "Existing
ownership" were checked 2026-09-29; re-check them the same way.

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

Tested 2026-09-27 and 2026-09-29 on this machine: `pwsh -NonInteractive -File <missing file>` exits
64, prints its usage text to stdout, and leaves stdin unread. In
`{ pwsh -NonInteractive -File ./missing.ps1 2>/dev/null; cat; } < payload`, the `cat` still printed
the whole payload.

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
  the lines above.
- **The plan's gate is met, and one of its steps now targets the wrong line.** Its "Gate" requires
  `[NS-32]` merged, and its "Status as of 2026-08-21" line still says unmerged. That line is stale:
  `[NS-32]` (`4bc107c`) reached `main` as the first commit squashed into PR #21 (`030662c`,
  2026-08-26). Task 3 Step 3 says "Replace line 49" in both settings files, and line 49 is now the
  `Bash`-matcher `review-reminders` entry, so running that step as written would overwrite the
  `Bash` tool's review-gate hook.
- No task has been committed. Task 1's `tests/test-hook-wiring.sh` was written and run, and is
  parked, untracked. The Task 2 form was applied to a scratch copy on 2026-08-21 and withdrawn
  (`docs/archive/progress-2026-08-19-to-21-escalation-and-bundle-1.md`, "Hook-Wiring Fix Withdrawn
  by Its Own Review"). A corrected form, which keeps the fallback inside the `command -v` branch and
  must ship with the plan's Task 4 logging, is parked
  (`docs/archive/context-2026-09-21-ns33-handoff-reconciliation-detail.md`, "Parked"). No open item
  owned it; this item does.
- The plan's Task 2/3 form is
  `if command -v pwsh …; then pwsh -File X.ps1 …; else bash X.sh …; fi`. That selects `pwsh`
  whenever it is installed, so with `pwsh` present and the `.ps1` missing it never reaches bash.
  Run here as `if command -v pwsh >/dev/null 2>&1; then pwsh -NonInteractive -File ./missing.ps1; else …; fi`,
  the `pwsh` branch exited 64 and the `else` branch did not run. Applied to the `Bash` matcher it
  would lose the fallback that the `||` chain has today.
- `docs/backlog/replace-the-gh-pr-merge-deny-with-a-forced-permiss.md` and the Fix outline of
  `docs/backlog/merge-gate-misses-gh-global-flags-graphql-and-powe.md` already note that the
  `PowerShell` matcher has no bash fallback, each in passing.

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

Needs an Opus escalation prompt, a spec, a task contract and a full `/code-review` and
`/change-review`: it changes the hook wiring that enforces the review gate and the BLOCK tier.

1. Give each of the three `PowerShell`-matcher entries a fallback that runs when the `.ps1` is
   absent, not only when `pwsh` is absent. Confirm first that the `.sh` twins parse the
   PowerShell-tool payload, and whether Claude Code honours a deny that follows `pwsh`'s usage
   text (see "Not established").
2. Refresh the 2026-08-20 plan, or mark it superseded by this item: its baseline table, Task 3's
   scope (three entries, not one), Task 3 Step 3's "Replace line 49", and its `command -v pwsh`
   form, which does not cover a missing `.ps1`.
3. Mirror `.claude/settings.json` to `templates/.claude/settings.json`, and update both
   `docs/HOOKS-GUIDE.md` and `templates/docs/HOOKS-GUIDE.md`, which show the `PowerShell` entry as
   PS-only.
4. If the `Bash`-matcher check below fails, extend the fix to the `Bash` matcher.

This covers a missing `.ps1` only. If `pwsh` starts, reads stdin and then crashes, no fallback gets
the payload and the call is allowed; the plan's Task 2 CORRECTION accepts that as fail-open, made
visible by its Task 4 logging.

## Done when

- A committed wiring test (tracked, so `tests/run.sh` fails until it is registered), run in a
  scratch copy of the tree and never the real `scripts/`, deletes each `.ps1` in turn and runs each
  settings command string verbatim with the scratch root as the working directory:
  - `:58` and `:62`, and their `Bash` twins `:45` and `:49`, each deny a guarded command (for
    example a `git commit` without a review marker). "Deny" means stdout is only the deny JSON
    object, unless it has been established that Claude Code honours a deny preceded by other
    output;
  - `:34` and its `Bash` twin `:25` never deny, so for them a commit that consumed a marker and then
    failed still gets the marker reissued.

  The parked `tests/test-hook-wiring.sh` may be a starting point; its fixture strips `/usr/bin` on
  Linux. And
- the 2026-08-20 plan no longer describes one entry, or is marked superseded by this item.

## Related

`docs/backlog/mb-upgrade-can-leave-a-half-review-gate-hook-pair.md` owns detecting and preventing a
missing `.ps1`; this item owns the wiring that leaves a missing one ungated.
