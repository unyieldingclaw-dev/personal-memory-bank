# Concurrent Session Claims

**Date:** 2026-08-04
**Status:** Approved

## Problem

PMB already has partial answers to "multiple sessions, same project": `memory-bank/` is canonical
only in the main worktree (subworktrees read it via `$(git rev-parse --git-common-dir)/../`, never
write it), and a separate boundary hook stops a session from writing into a *different repo's*
working directory. Neither addresses two sessions working the *same* repo at the *same* time —
whether both sitting in the main worktree, one main + several subworktrees, or several subworktrees
with no session in main at all.

The concrete failure mode motivating this: a session reads a handoff / `activeContext.md` listing
several in-flight items (this repo's own `activeContext.md` currently carries 11 numbered "Next
Steps" plus multiple live worktrees) and has no way to tell whether another session already claimed
one of them. Nothing records "who is working on what right now" — only prose, which doesn't
distinguish "still true" from "already picked up by another session an hour ago."

This mirrors a bug already living in this codebase: `.claude/contracts/active-task.json` (scope
contracts, see `docs/CONTRACTS-GUIDE.md`) has an `expires_at` field but no cleanup story — expired
contracts are silently left in place, and `activeContext.md` records at least one case of a session
having to guess whether a contract from a prior session was still valid. This design deliberately
does not repeat that: cleanup is a first-class requirement, not an afterthought.

## Goals

- Prevent two sessions from starting the same unclaimed work item without either knowing about the
  other.
- Make current claims visible automatically at session start, without depending on the agent
  remembering to check a file (the same class of reliability problem that `memory-bank/`'s
  `PreCompact` gate exists to solve).
- Bounded, self-cleaning storage — no manual sweep, no unbounded growth, no history retained past a
  claim's relevance.
- Bash and PowerShell parity from the start, per this repo's established twin-script convention.

## Non-Goals

- **Locking the memory-bank files themselves.** Claims stop two sessions from *starting the same
  work twice*; they do nothing to prevent two sessions from concurrently editing, say,
  `activeContext.md` and losing an update. That's a different problem (raw file-write concurrency,
  not work-item coordination) and solving it would mean adding locking to the memory-bank files
  themselves — out of scope here, stated explicitly rather than silently implied as covered.
- **Fixing `activeContext.md` size/bloat.** The file is already over its own 150-line guideline
  (434 lines as of this writing) — a plausible independent contributor to session confusion. Not
  addressed by this design beyond giving Next Steps items stable IDs (below); the broader cleanup is
  a separate, pre-existing eviction-discipline gap.
- **General distributed locking.** The concurrency control here (below) is best-effort, scoped to
  human-paced parallel sessions on one machine — not a linearizable lock service.
- **Cross-repo claim visibility.** Out of scope per the existing cross-repo write-boundary rule
  (`memory-bank/`'s multi-session guidance) — claims are per-repo, same as `active-task.json`.

## Design

### Storage

One file, canonical in the **main worktree only**: `.claude/session-claims.json`. Same
single-source-of-truth pattern already established for `memory-bank/`, with one difference —
subworktree sessions get *write* access to it (resolved the same way, via
`$(git rev-parse --git-common-dir)/../.claude/session-claims.json`), since a subworktree session must
be able to register its own claim, not just read others'. Gitignored, alongside
`.claude/contracts/*.json` — pure local ephemeral state, not shared history, not meaningful to
version.

```json
{
  "claims": [
    {
      "claim_id": "worktree-mb-backlog-feature",
      "ns_id": "NS-3",
      "item": "Resume mb backlog Tasks 2-5",
      "claimed_at": "2026-08-04T14:00:00Z",
      "expires_at": "2026-08-05T02:00:00Z"
    }
  ]
}
```

No `status` field, no history of past claims. A claim exists or it doesn't — bloat prevention is
structural, not procedural (see Lifecycle).

### Concurrency control

Reads and writes go through an `mkdir`-based lock: `.claude/session-claims.lock/`. Directory
creation is atomic on both NTFS and POSIX — confirmed as the same underlying guarantee whether the
caller is the Bash tool (git-bash `mkdir`) or the PowerShell tool (`New-Item -ItemType Directory
-ErrorAction Stop`), which matters here specifically because both are available in this environment
and could race against each other, not just against another instance of the same tool.

Acquire sequence:
1. Attempt to create the lock directory. Retry briefly (≈2s total) on failure.
2. If a lock directory already exists and its mtime is >30s old, treat it as abandoned (crashed
   holder) and remove it before retrying.
3. If acquisition still fails after the retry window, fail open: skip claim registration, print a
   WARN, do not block the calling operation. Same "never hang, never block" philosophy as
   `check-contract.sh`.

Once held: read the file (treat a missing file as an empty claims array — this is not a special
unlocked case, file creation goes through the same locked path as every other mutation, precisely so
two sessions racing on a fresh repo can't both "helpfully" bootstrap it outside the lock and reintroduce
the exact race this exists to prevent) → prune expired entries → apply the one change (add, remove, or
force-clear a claim) → write to a temp file → atomically rename over the real file → remove the lock
directory.

Temp-file-then-rename also protects against corruption independent of the locking: a crash mid-write
yields either the old file or the fully-written new one, never a partial one.

This is explicitly best-effort concurrency control for a human-paced coordination file, not a general
lock service — stated here as a scope decision, not an oversight.

### Session identity

- If the session is operating in a worktree, its branch name is the `claim_id` — already unique,
  already how sessions are distinguished today (`worktree-mb-backlog-feature`,
  `strange-bun-9a0ffc`, etc.).
- If operating directly in the main worktree with no branch yet, the session self-generates a short
  slug once, in the same style as this repo's existing auto-named worktrees, and reuses it for the
  rest of the conversation.
- To survive context compaction, the active `claim_id` gets recorded in `activeContext.md`'s
  existing volatile-state section — reusing the compaction-recovery path that already exists for
  everything else in that file, rather than inventing a second mechanism.

### Lifecycle

1. **Prune** happens on every read and write — any access strips expired entries first. Combined
   with the SessionStart hook (below), which runs on every session start, this means pruning is
   effectively continuous without any separate cleanup job.
2. **Claim** — before starting real work on a Next Steps item, write an entry through the locked
   path. TTL default: 12 hours. Chosen over a shorter TTL + renewal/heartbeat mechanism — 12h covers
   any realistic single working session on this project (per this repo's own session history) without
   needing renewal logic; a legitimately-abandoned claim self-clears well within a day regardless, and
   the override path below covers the case where someone needs it gone sooner.
3. **Release** — delete the entry through the locked path when the item is completed. This must
   happen as part of the *same* close-out step that marks the Next Steps item complete/evicts it from
   `activeContext.md` — not a separately-remembered action — so a claim can never legitimately point
   at an already-evicted item. If release is skipped anyway (forgotten, session crashed), the claim
   still self-heals via TTL; nothing is left permanently orphaned.
4. **Multiple claims per session are allowed** — no artificial one-claim limit. A session's
   `claim_id` may appear on more than one entry if it's legitimately working several related items.

Matches the existing `activeContext.md` eviction rule ("issue resolved → delete, don't archive") —
a claim has no value once it's done, so there's nothing to retain.

### Conflict / override

Before starting an item, check for a live (unexpired) claim with a matching `ns_id` (or matching
`item` text for ad hoc work with no `ns_id`). If found:
- Surface it via `AskUserQuestion` — item, owner, age, expiry.
- Options: work on something else, or force-clear (explicit user confirmation required each time,
  proportionate to this being ephemeral bookkeeping rather than code/data — no heavier gate needed).
- Force-clear removes the stale entry through the same locked path, then writes the new claim. It
  also adds one line to `activeContext.md` ("force-cleared stale claim on X held by Y, appeared
  abandoned as of Z") — otherwise a returning session would find its claim silently gone with no
  explanation, which just relocates the original confusion problem rather than fixing it. No new
  durable-record mechanism: `activeContext.md` already is the narrative record, and already has its
  own 14-day eviction rule.

### Enforcement — SessionStart hook

A new, read-only `SessionStart` hook (first one in this project) runs prune, then lists remaining
live claims. It resolves the main-worktree path using the same `resolve_cd_root()`-style logic
already fixed for `review-reminders.sh`/`.ps1` (the 2026-07-22/23 worktree-root-resolution fix) —
reused deliberately rather than re-derived, since this exact codebase already hit and fixed that bug
class once.

This upgrades enforcement from pure advisory (CLAUDE.md prose, the tier `memory-bank/` reads
currently use) to hook-level, for the same reason the `PreCompact` gate exists: memory that depends
on the agent remembering to check something is the failure mode this whole feature is meant to close.

**Must be silent when there's nothing to report.** If the claims list is empty after pruning, the
hook prints nothing. A hook that prints on every session start regardless of relevance becomes noise,
and noise gets tuned out — defeating the reason this is hook-enforced instead of advisory in the
first place.

### Next Steps stable IDs

Each `activeContext.md` Next Steps line gets a short leading ID (`[NS-3]`), assigned sequentially
when added, never reused. Claims store the ID in its own `ns_id` field, separate from the free-text
`item` description (`ns_id` for matching — exact string comparison, no parsing required; `item` for
human readability if they ever drift apart). A claim with no corresponding Next Steps item (ad hoc
work never added to the list) simply omits `ns_id`. This replaces fragile free-text fuzzy matching,
which would otherwise be the weakest link in an otherwise well-defined system, and gives both the
claims mechanism and plain human reading of the file a stable thing to point at even as items get
reordered or evicted around it.

### `mb doctor` check

Two additions, consistent with `mb doctor`'s existing "observable integrity signals only" scope:
- `session-claims.json` exists but fails to parse as JSON.
- `session-claims.lock/` exists and is older than ~5 minutes — well past the 30s self-heal window,
  meaning the self-heal mechanism itself somehow failed to fire. This is the same class of silent
  structural failure that let `active-task.json` go unnoticed before; a cheap doctor check closes it
  rather than repeating that precedent.

### Bash / PowerShell parity

- `scripts/session-claims.sh` and `scripts/session-claims.ps1` — prune, list, claim, release,
  force-clear, all built on the `mkdir` lock described above.
- Byte-identical `templates/scripts/` mirrors (TEMPLATE_OWNED sync, matching existing convention).
- New test file(s) covering both platforms **must be registered in `tests/run.sh`'s `run_suite`
  list as an explicit acceptance criterion** — called out specifically because a prior feature
  (`mb backlog`) shipped with a test file that was never wired into the suite, so CI showed green
  with zero real coverage. Not repeating that.
- `SessionStart` hook registered for both `scripts/session-claims.sh` and `.ps1` in
  `.claude/settings.json`, following the same dual-entry pattern already used for the `PreToolUse`
  hooks in that file.

## Testing

1. **Lock contention**: two near-simultaneous claim attempts on the same item (one via the bash
   script, one via the PowerShell script, to specifically exercise cross-tool locking) — assert
   exactly one claim is written and the other either waits and succeeds on a different item or
   observes the existing claim.
2. **Stale lock recovery**: a lock directory artificially aged past 30s — assert the next
   acquisition attempt removes it and proceeds rather than hanging.
3. **Prune correctness**: a claims file with a mix of expired and live entries — assert only live
   entries survive a read/write cycle.
4. **Corruption resistance**: simulate a failure between temp-file-write and rename — assert the
   original file is untouched.
5. **Bootstrap race**: two sessions racing on a repo with no existing claims file — assert both go
   through the lock (no unlocked fast path) and the result is a valid file with both claims (if on
   different items) or one claim plus a surfaced conflict (if on the same item).
6. **Override flow**: a live claim force-cleared — assert the old entry is gone, the new one is
   present, and a breadcrumb line lands in `activeContext.md`.
7. **SessionStart silence**: an empty/all-expired claims file — assert the hook produces no output.
8. **`mb doctor` checks**: malformed JSON and an over-age lock directory each surfaced as findings.

Exact test scaffolding (temp directories, simulated multi-process contention) is an implementation-plan
detail, following this repo's existing test patterns (e.g. `tests/test-review-reminders.sh`'s
worktree-reproduction setup).

## Files Changed

| File | Change |
|---|---|
| `scripts/session-claims.sh` | New — prune/list/claim/release/force-clear, `mkdir`-lock based |
| `scripts/session-claims.ps1` | New — PowerShell twin |
| `templates/scripts/session-claims.sh` / `.ps1` | Byte-identical mirrors (TEMPLATE_OWNED) |
| `.claude/settings.json` | New `SessionStart` hook entries (both scripts) |
| `templates/.claude/settings.json` | Mirrored hook entries |
| `.gitignore` | Add `.claude/session-claims.json`, `.claude/session-claims.lock/` |
| `memory-bank/activeContext.md` | Next Steps items gain `[NS-N]` stable IDs; close-out step now includes claim release; force-clear breadcrumb convention documented |
| `docs/CONTRACTS-GUIDE.md` or a new `docs/SESSION-CLAIMS-GUIDE.md` | Document the mechanism, schema, and lifecycle (decide placement during planning — closely related to contracts but a distinct concept) |
| `scripts/mb.sh` / `.ps1` (`doctor` subcommand) | Two new checks: malformed claims file, over-age lock directory |
| `tests/test-session-claims.sh` (+ PowerShell equivalent if this repo's test convention requires it) | Covers the 8 scenarios above; **registered in `tests/run.sh`'s `run_suite`** |
