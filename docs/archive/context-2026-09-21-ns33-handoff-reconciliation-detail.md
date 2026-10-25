# [NS-33] Handoff-Protocol Reconciliation — Full Detail

Evicted from `memory-bank/activeContext.md` 2026-09-21 to fund that session's ratchet overage.
`activeContext.md`'s live `[NS-33]` entry keeps the headline (REJECTED by its own gate 2026-08-21,
6 blocking, 2 cleared; stashed at `stash@{2}`, identify by message not index) and points here for
the fix list and status below.

## Fix before re-review

(a) `memory-bank/systemPatterns.md:32` is a **9th** copy of the protocol, Tier-2 STABLE authority,
still pre-`3a2a7fd` — never touched.

(b) `templates/handoff.md` is caught by the unanchored `.gitignore:27` and has **never** been in
git — the rewrite exists on disk only and cannot ship.

(c) **CLEARED — stale as of 2026-09-21.** Originally: `standards/MEMORY-BANK.md:131,385` said
`mb compact` vs the template's `mb clean`, logged 2026-06-18 as audit finding T1. Actually fixed
2026-08-28 (`docs/archive/progress-2026-08-28-round3-gate-passes-and-brief-staleness.md:26`) — both
`standards/MEMORY-BANK.md` and its template now say `mb clean` throughout, reconfirmed by direct
grep 2026-09-21 (zero `mb compact` matches in either file). This item never caught up to that fix.

(d) done.

(e) nothing guards mirror re-divergence, though the mechanism exists at `scripts/mb.sh:1384`.

## Unowned, breaks adopters

`scripts/init-memory-bank.sh:173` copies `templates/handoff.md` under `set -e` — not in git, so
onboarding aborts on a fresh clone.

## Parked

Hook-wiring fix withdrawn; the corrected form keeps the fallback *inside* the `command -v` branch
and must ship together with plan Task 4 or the drain-then-crash case stays silent; WIP patch in
scratchpad; `tests/test-hook-wiring.sh` + `tests/helpers/stub-pwsh.sh` untracked, and the fixture
strips all of `/usr/bin` on Linux. Plan: `docs/superpowers/plans/2026-08-20-hook-enforcement-integrity.md`
(untracked).
