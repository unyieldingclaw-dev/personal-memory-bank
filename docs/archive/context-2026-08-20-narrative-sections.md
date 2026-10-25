# Archived Context — Narrative Sections Evicted from activeContext.md (2026-08-20)

Archived 2026-08-20 to keep `memory-bank/activeContext.md` under its 150-line CI cap; it had reached
148/150 lines with ~980 bytes of headroom, carrying the same deadlock `progress.md` hit the same day.

Every section below duplicates a numbered `[NS-N]` entry that remains live in `activeContext.md`'s
Next Steps — the authoritative pending-work list. Nothing here is the sole record of an open item.
Mapping, verified before eviction:

| Archived section | Live entry that supersedes it |
|---|---|
| User-As-Bypass Hardened; Investigation-Integrity Design | `[NS-16]` |
| Review-Gate Layered Enforcement — Spec + Plan | `[NS-15]`, superseded by `[NS-26]` |
| Fleet Version Drift Incident | `[NS-14]` |
| Memory Bank Freshness Hook / Session Claims / mb backlog | `[NS-13]`, `[NS-18]`, `[NS-0]` |
| Handoff Protocol Narrowed | shipped `3a2a7fd`; open remainder is `[NS-22]` |

**One rule was deliberately NOT archived** — the standing "full `/code-review`, every time, no lite
path" rule was promoted into `activeContext.md`'s `## Architecture Constraints to Remember`, because
it is live governance rather than history and `standards/` does not state it independently (verified
by review: `grep -rn "lite path" standards/` returns nothing).

The user-as-bypass rule in the first section below was **not** promoted, and does not need to be — it
is independently stated at `standards/SECURITY-GUARDRAILS.md:88` ("The User Is Never the Compliance
Bypass") and `docs/HOOKS-GUIDE.md:33`. A first draft promoted it anyway; review caught the redundancy
and it was dropped.

---

## User-As-Bypass Hardened; Investigation-Integrity Design (2026-08-12)

Never use the user as the bypass for a control the agent itself couldn't satisfy (distinct from
CONFIRM/BLOCK-tier commands where a human IS the designed resolution) — hardened into
`standards/SECURITY-GUARDRAILS.md`/`docs/HOOKS-GUIDE.md` (+ template mirrors), not left private-memory-only.
Spec `docs/superpowers/specs/2026-08-12-investigation-integrity-design.md` + brief
`docs/WORK-MB-INVESTIGATION-BRIEF.md` committed `15df2c2`. A "review-depth classification" exemption was
designed then explicitly withdrawn on user objection — same failure class as user-as-bypass. **Standing
rule: full `/code-review`, every time, no lite path.** Full narrative: `progress.md` 2026-08-12.

## Review-Gate Layered Enforcement — Spec + Plan Written, Not Yet Executed (2026-08-12/13)

Spec `docs/superpowers/specs/2026-08-12-review-gate-layered-enforcement-design.md` (`f2cec79`, fixed
`b47db8f`): CC `PreToolUse` hook downgraded to non-consuming peek; `.githooks/pre-commit`/`pre-push`
become sole authoritative marker consumer; new CI containment check as backstop. Disclosed limits:
`--no-verify`/unset `core.hooksPath` still defeat the git-hook layer. **Plan**
(`docs/superpowers/plans/2026-08-12-review-gate-layered-enforcement.md`, 14 tasks) self-reviewed AND
independently reviewed (8 real defects found, all fixed in-plan) — see `[NS-15]`. **Still not
implemented** — needs an execution-mode decision before Task 1. Full narrative: `progress.md` 2026-08-12/14.

## Fleet Version Drift Incident — ACR Found 2 Versions Behind (2026-08-12)

Cross-session report: `ai-code-review-agent`'s `.pmb-version` reads `1.1.1` while PMB's own `VERSION`
is `1.2.1` plus unreleased work — ACR ran a real 13-task implementation effort under review-gate hooks
two versions stale before this was caught. Root cause: `mb doctor`'s existing version-mismatch check
is a passive WARN, easy to miss. The "`mb upgrade` should not just look at date" question is resolved,
not open: `TEMPLATE_OWNED` sync is already unconditional; the actual gap is nothing *triggers* a run.
**Not yet resolved** — blocked on ACR resyncing from its own session (cross-repo write boundary); see
`[NS-14]`.

## Memory Bank Freshness Hook, Concurrent Session Claims, Confirm-Step Live Review, mb backlog Feature

Full narrative archived — `docs/archive/context-2026-08-freshness-and-session-claims.md` covers the
2026-08-10 freshness-hook spec (committed `3e475ae`, not yet implemented, `[NS-13]`) and the
2026-08-08 concurrent-session-claims ship (13 tasks + 5 post-review fixes, `/ai-review` still pending
on that branch). `docs/archive/context-2026-07-review-gate-hardening.md` covers the review-gate
mechanism's evolution 2026-07-16 through 2026-08-05 (self-attestation fix, false-positive fix,
confirm-step redesign, worktree-root-resolution fix, hook-lib-dedup, first live whole-branch review).
`docs/archive/context-2026-07-backlog-and-notifier.md` covers `mb backlog` Task 1 (shipped, Tasks 2-5
not started, `[NS-0]`) and the mb update-notifier + authorization-drift incident that produced the
"What Counts as Approval" rule.


## Handoff Protocol Narrowed — Memory-Bank Now Authoritative for Priority (2026-08-18)

Work-MB's handoff → "priority order" flow was causing new sessions to miss things (asking a
pressure-written document to also carry synthesis). Redesigned `## Handoff Protocol` in `CLAUDE.md` +
`templates/CLAUDE.md` (byte-identical, `3a2a7fd`): `handoff.md` now scoped to ephemeral in-flight state
only; new sessions read `activeContext.md`'s Next Steps first as authoritative, reconcile against
`handoff.md` second, surface conflicts rather than silently picking one. Portable companion brief
`docs/WORK-MB-HANDOFF-DESIGN-BRIEF.md` (`3aa70af`) sent the same principle to work-MB. Both reviewed +
Opposition-marker-verified. Distinct from `[NS-22]` (handoff.md cleanup-enforcement gap), still open.

