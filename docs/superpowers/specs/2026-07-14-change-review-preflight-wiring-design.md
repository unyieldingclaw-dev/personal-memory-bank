# /change-review Preflight Wiring + Coverage-Check Loudness Design

**Date:** 2026-07-14
**Status:** Approved

## Problem

`/change-review` Step 2 does its own ad-hoc `which ai-review-agent` check and, if not found,
prints a low-key message and silently continues with reduced coverage — the degradation only
surfaces after the fact, buried in the final report's coverage-footer table
(`ACR backend: not installed`). Meanwhile `mb preflight` (`Show-Preflight` in `mb.ps1`/`mb.sh`)
already does this properly — clear `[OK]`/`[WARN]`/`[ERROR]` lines for git/gh/ai-review-agent/
semgrep — but `/change-review` never calls it, and nothing else does either; it's advisory-only,
opt-in, easy to skip.

Separately: `tests/mb-setup.Tests.ps1` (a real Pester test file) is never invoked by
`tests/run.sh` or any CI job — a different bug (wiring, not degradation), found in the same
audit, fixed in the same batch.

Origin: a real incident on the user's separate work-fork of PMB, where a Pester-based test
suite silently skipped because Pester wasn't installed, discovered only by accident.

## Core Principle

Not "always fail loud" universally — that would break this repo's own deliberate, already-
correct fail-open convention for **blocking hooks** (`review-reminders.sh`,
`dangerous-commands.sh` — failing closed there would block all work, worse than missing one
check; `check-repo-boundary.sh` follows the same convention but lives only on the separate,
unmerged `worktree-cross-repo-write-boundary` branch as of this writing, not on this one). The
real distinction:

- **Blocking gates** (stop an action) → fail open is correct, unchanged by this design.
- **Coverage/review checks** (produce findings someone relies on as "this was verified") →
  silent degradation is the actual danger, since it produces false confidence, not a blocked
  action. This is Job 7's fallback and the orphaned Pester suite.

## Approach

### 1. Wire `/change-review` Step 2 to `mb preflight`

Replace the ad-hoc `which ai-review-agent` check with an actual call to `mb preflight`
(or its underlying logic). Surface the result **before** Job 7 runs, not just in the final
report footer — a proactive notice, not a retroactive footnote. The final coverage-footer
line stays too (`ACR backend: used | not installed | disabled`), now backed by the same
check `mb preflight` already performs rather than a separate, weaker duplicate.

### 2. Wire the orphaned Pester suite into CI

Add a CI step (or `tests/run.sh` step) that runs `tests/mb-setup.Tests.ps1` via
`Invoke-Pester`, mirroring the existing "Install PSScriptAnalyzer" pattern already in
`pmb-health.yml`'s PowerShell Lint job (install Pester if missing, then run). If Pester truly
can't be installed in a given environment, this must fail loud (non-zero exit), not silently
skip — matching the core principle above.

### 3. Document the distinction

Add the blocking-gate-vs-coverage-check distinction to `standards/` (likely
`standards/WORKFLOW.md` or a new short section) so it's available guidance for any future
check design, not just tribal knowledge from this conversation.

## Files Changed

| File | Change |
|------|--------|
| `.claude/commands/change-review.md` | Step 2: call `mb preflight` instead of ad-hoc check; make ACR-unavailable a proactive notice before Job 7, not just a footer line |
| `tests/run.sh` | Add Pester suite invocation (or add a CI-only step if Pester shouldn't run in the bash-only local suite) |
| `.github/workflows/pmb-health.yml` | Add/extend a job to install Pester and run `tests/mb-setup.Tests.ps1`, failing the build if it can't run |
| `standards/WORKFLOW.md` (or new doc) | Document blocking-gate vs. coverage-check distinction |

## Out of Scope

- No shared "require-or-degrade" framework/helper library — exactly one true in-repo instance
  of the silent-degradation pattern was found (Job 7); a sample size of one doesn't clear this
  repo's own "no pattern, no proactive build" bar. Revisit if a genuine third instance appears.
- No changes to the deliberately fail-open blocking hooks — confirmed correct, untouched.
