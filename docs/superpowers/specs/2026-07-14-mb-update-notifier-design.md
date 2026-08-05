# mb Update-Notifier Design

**Date:** 2026-07-14
**Status:** Approved

## Problem

`mb` only checks whether it's behind the latest PMB release *inside* `mb upgrade` itself
(`Invoke-Upgrade` fetches `VERSION` from GitHub and warns on mismatch). Nothing triggers that
check otherwise — a project can sit versions behind indefinitely unless someone thinks to run
`mb upgrade` specifically. Confirmed as a real, not hypothetical, gap: tonight's fleet audit
found 8 of 11 downstream repos stuck on PMB `1.1.1` while `1.2.1` was current.

## Solution

Extend the existing version-check to run (cheaply, cached) on **any** `mb` invocation, not
only `mb upgrade` — same shape as the well-established `update-notifier` pattern (`npm`,
`yarn`, etc. all do this), and the parallel design already approved for the `ai-review-agent`
CLI (see `acr-ai-review-distribution-design.md`, handed to ACR's own session) — independent,
parallel implementations, no shared code between the two projects.

## Approach

- On any `mb <command>` invocation, check the cached last-known comparison between local
  `VERSION` and the GitHub-hosted `VERSION` file.
- **Cache with a TTL (7 days)** — refresh in the background if stale, but never block a
  command on a live network call. Async, timeout-bounded (~2s), fail silent/open on any
  network error — matches this repo's existing "fail open on missing dependency" convention.
- If the cached comparison shows PMB is behind, print one non-blocking line, once per
  invocation, after the command's normal output:
  > `[NOTICE] PMB 1.1.1 installed, 1.2.1 available — run: mb upgrade`
- No auto-upgrade, ever. Detection and instruction only.
- Reuses `Invoke-Upgrade`'s existing remote-VERSION-fetch logic rather than duplicating it —
  extract into a small shared helper both the notifier and `Invoke-Upgrade` call.

## Files Changed

| File | Change |
|------|--------|
| `scripts/mb.ps1` | Extract version-check into a helper; call it (cached) from the main command dispatch, not just `Invoke-Upgrade` |
| `scripts/mb.sh` | Same, bash equivalent |
| `templates/scripts/mb.ps1` / `.sh` | N/A — `mb.ps1`/`mb.sh` are not template-distributed files; this only affects PMB's own copies |

## Out of Scope

- No change to `mb upgrade`'s own existing warning — it stays as-is, this only adds the same
  check to other commands.
- No fleet-wide "upgrade all my projects" command — that's the separate, larger gap noted in
  `activeContext.md`'s Next Steps (item 10), explicitly not being built off this one incident
  per this repo's "no pattern, no proactive build" precedent.
