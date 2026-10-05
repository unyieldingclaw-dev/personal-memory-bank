# Compact/Clear Nudge Hook

**Date:** 2026-09-21
**Status:** Revised 2026-09-21, pending re-approval. Supersedes the approved transcript-byte-size
version; see Revision History at the end for what changed and why.

## Problem

`CLAUDE.md`'s Token Budget section says "Manual `/compact` at a natural boundary beats waiting for
auto-compact mid-task" — but nothing structurally reminds anyone of this. `CLAUDE_AUTOCOMPACT_PCT_OVERRIDE=65`
fires automatically once context crosses 65%, at whatever moment that happens to land on, which is
exactly the "waiting for auto-compact mid-task" outcome the instruction argues against. Like the
memory-bank-update instruction before `memory-bank-freshness.sh` existed (see
`2026-08-10-memory-bank-freshness-hook-design.md`), this is advisory-only text that must be
re-remembered continuously for the life of a session, with no forcing function.

The Handoff Protocol has the same gap with the same observable: its "reports context >= 40%"
trigger. Claude cannot see context usage, so today that trigger fires only when the user reads a
percentage off their UI and says so.

Claude Code hooks cannot invoke `/compact` or `/clear` directly — those are conversation-level
actions, not tool calls a hook can trigger. So the achievable version is an advisory nudge, surfaced
back into context, timed off something a hook can actually observe.

## Design

### Trigger: `UserPromptSubmit`, not `PostToolUse`

Considered and rejected: `PostToolUse` with `matcher: "*"`, counting cumulative tool calls (mirroring
the existing Agent Spawn-Volume Advisory hook, `scripts/delegation-depth-check.sh`). Rejected for two
concrete reasons:

1. **Continuous cost vs. rare-case benefit.** `matcher: "*"` spawns a `pwsh`/`bash` interpreter on
   *every* tool call, including `Read`/`Grep`/`Glob` — tool types that currently pay zero hook
   overhead anywhere in this repo. That cost is paid every session, on every call, forever.
2. **An unaddressed race condition.** `delegation-depth-check.sh` does an unlocked read-modify-write
   against `.pmb-delegation-depth`, but only on `Agent` calls, which are relatively rare. The same
   unlocked pattern on `matcher: "*"` collides with genuinely parallel tool-use blocks, which this
   repo's own tool-use guidance encourages.

`UserPromptSubmit` fires once per user turn, before that turn's tool calls begin, so it cannot race
itself. It is also one of the few events whose plain stdout Claude Code surfaces as visible context
(see Messages).

**The trade-off this accepts:** coarser timing. A single turn that grows context enormously won't be
checked until the *next* turn starts — possibly after auto-compact has already fired mid-turn. That
outcome is exactly today's baseline with no hook at all, so the failure mode degrades to "the feature
didn't help this one time," not to anything worse.

### Metric: the API's own token count, read from the transcript

No hook payload field carries a token count or context percentage. That was confirmed against the
hooks reference on 2026-09-21, and re-checked the same day after reviewing Anthropic's newer
compaction features; it is still true. But the payload's `transcript_path` points at a JSONL log in
which every assistant entry records the API's `message.usage` for that request. The context size of
the most recent request is:

```
input_tokens + cache_creation_input_tokens + cache_read_input_tokens
```

**Validated against Claude Code's own figure, not assumed.** Each compaction writes a
`{"type":"system","subtype":"compact_boundary"}` entry whose `compactMetadata.preTokens` is the
context size Claude Code itself measured when it compacted. This session's transcript holds four:

| Boundary (UTC) | Trigger | `preTokens` | Last usage before | First usage after |
|---|---|---|---|---|
| 2026-09-19 17:31 | auto | 791,171 | 790,565 | 107,691 |
| 2026-09-20 01:41 | auto | 639,543 | 633,026 | 114,785 |
| 2026-09-21 19:42 | auto | 637,074 | 636,594 | 111,736 |
| 2026-09-21 21:16 | manual | 453,772 | 452,552 | 116,858 |

The largest gap is 1.0%. This metric is effectively the number auto-compact acts on, and it falls
after compaction the way context actually does.

**Why not transcript byte size (the approved version's metric).** Verification spike 2 found the
transcript is an append-only session log. Across the manual `/compact` in the table above, the file
grew from 19,521,648 to 19,930,408 bytes while context fell from 452,552 to 116,858 tokens. A ~20 MB
file sitting under a ~117K-token context means the byte count measures total session history, not
what is in context. A metric that moves in the opposite direction from the thing it stands for cannot
be fixed by recalibrating thresholds or re-basing the reset.

**What this trades away.** Byte size needed only the file to exist. This metric depends on Claude
Code's JSONL schema (`type`, `message.usage`, `isSidechain`, `subtype: compact_boundary`), which is
internal, undocumented, and can change without notice. The choice is accuracy with a detectable
failure over robustness with a wrong answer. Failure Handling makes schema drift visible rather than
silent.

**Reading it.** Scan backward from the end of the transcript over at most the last `TAIL_LINES=400`
lines, and stop at the first of:

- an assistant entry carrying `message.usage` whose `isSidechain` is not true, which gives the
  current context size;
- a `compact_boundary` entry, which means compaction happened after the last response. That makes
  the pre-compaction usage above it stale, so the reading is "just compacted."

The boundary stop is required, not defensive. After each of the four boundaries, 28–45 lines
(summary, attachments, command entries) precede the first post-compaction assistant entry. A plain
"last usage in the file" read on the first prompt after `/compact` would return the pre-compaction
figure (452,552 at the manual compact) and fire a false nudge right after the user did what it asks.

`isSidechain`: no sidechain entries appear in this transcript, because subagent logs are stored
separately in this version. The one comparison prevents a subagent's context from being read as the
main session's if a format ever interleaves them.

`TAIL_LINES` is sized from observation: roughly ten metadata entries per turn, and at most 45 lines
between a boundary and the next response. The tail is line-based rather than byte-based because a
single line can be megabytes (large tool results).

**Lag.** The documentation says the transcript is written asynchronously. When `UserPromptSubmit`
fires, the previous turn has ended, so its final assistant entry should be on disk. If a write lags,
the reading is one turn stale, which fire-once-per-crossing tolerates.

**What the number covers.** It is the context of the last request, so it excludes the prompt being
submitted and whatever the coming turn adds. Per-prompt growth in this transcript: median 8,929
tokens, p90 36,790, max 102,240, over the 122 prompt-to-prompt increases observed. The nudge runs at
most one turn behind.

### Thresholds

**The context window is inferred, not documented.** `preTokens` up to 791,171 is impossible in a
200K window. With `CLAUDE_AUTOCOMPACT_PCT_OVERRIDE=65`, the two most recent automatic compactions
fired at 637K–640K, which is consistent with a ~1M window. The approved version's threshold
arithmetic assumed 200K. That was a second wrong premise, independent of the byte-size one.

- `FIRST_THRESHOLD_TOKENS=400000`: 40% of ~1M, aligned with the Handoff Protocol's existing "context
  >= 40%" trigger, so this hook makes that trigger observable to Claude instead of dependent on the
  user reporting it. It sits well clear of the ~110K floor a compaction leaves behind (107K–117K
  across four boundaries), so a fresh compaction cannot immediately re-trigger it.
- `RENUDGE_INTERVAL_TOKENS=100000`: about 11 median turns between repeat nudges. In practice that
  means nudges near 400K, 500K, and 600K before auto-compact at ~637K.

Both are documented in `standards/PERFORMANCE-BUDGET.md` (and its `templates/` mirror) next to the
agent-spawn budget, same pattern as `BUDGET_LIMIT=6` in `delegation-depth-check.sh`.

**Accepted limitation: the constants are window-specific.** Neither the payload nor the transcript
carries the window size. On a 200K-window model, auto-compact fires near 130K and the 400K nudge
never fires, so the feature degrades to today's baseline, not to anything worse. Templates ship these
constants unchanged, and an install on a different window has to recalibrate them.

### State and escalation logic

**State is scoped per session.** During verification spike 1, a temporary diagnostic hook wired into
this repo's `.claude/settings.json` fired for a *different*, concurrent Claude Code session rooted in
the same directory. `.claude/settings.json` is per-directory, not per-session, so any hook registered
there fires for every session operating in that directory. A single shared state file would let one
session's context set the threshold another session is compared against, and let two sessions race
the same read-modify-write.

State file `.pmb-compact-nudge-<session_id>` holds one line, `next_nudge_at=<tokens>`. It is written
relative to the directory the session runs in (project root, or a linked worktree's root) and is
gitignored by wildcard. Only this hook reads or writes it, so no other script needs to resolve the
same path. That matters because a concurrent change is altering how `pre-compact-check` resolves
`memory-bank/` inside linked worktrees; this design is unaffected by it.

On each `UserPromptSubmit`:

```
session_id, transcript_path  <- hook payload
state_file = ".pmb-compact-nudge-" + session_id
reading    = backward scan of the transcript tail (see Metric)

if reading is "just compacted" or reading.tokens < FIRST_THRESHOLD_TOKENS:
    delete state_file if it exists          # re-arm
    exit 0
next_nudge_at = value in state_file, else FIRST_THRESHOLD_TOKENS
if reading.tokens >= next_nudge_at:
    print advisory (see Messages)
    write next_nudge_at = reading.tokens + RENUDGE_INTERVAL_TOKENS
exit 0
```

**Self-re-arming.** State clears whenever context is back below the first threshold, whatever put it
there: manual or automatic `/compact`, any automatic trimming that lowers reported usage, or `/clear`.
No other script has to reset anything (see Reset).

**`/clear` is not verified** — whether it starts a new transcript and `session_id` or writes a marker
into the same file. Either way, the first response after it records a small usage and re-arms. The
worst case is one stale advisory on the first prompt after `/clear`. That needs all three: `/clear`
keeps the same transcript, it writes no boundary, and the last pre-clear reading had already crossed
`next_nudge_at`.

**Blocked compaction.** If `pre-compact-check` exits 2, nothing compacts, context stays high, and the
hook keeps nudging on schedule. That is correct, because the condition it reports is still true.

**Fire-once-per-crossing, not fire-on-every-turn.** Unlike `delegation-depth-check.sh`, which warns
on every call once past its threshold (verified by reading its source), this pushes `next_nudge_at`
forward on each nudge. The file is written only on a crossing and deleted only when present below the
threshold, so an ordinary turn does no writes.

**Cold start.** A missing state file means `next_nudge_at = FIRST_THRESHOLD_TOKENS`. The file is
created on first write.

**`\r`-safety.** State-file parsing strips `\r` before comparing. This repo has hit that bug class
before (`check-contract.sh`'s bug 3, `docs/HOOKS-GUIDE.md` §3); the `.sh` side uses the established
`tr -d '\r'` fix.

**`scratchpad_dir` considered and rejected as the storage location.** Its stability across turns of
one session is now observed: four captures on 2026-09-21, spanning three prompts and a `/compact`,
carried the same value. It was rejected anyway because its presence outside this Claude Code surface
is unverified, and templates ship to other installs. The per-session files it would have kept out of
the project root now accumulate only for sessions that end while above the first threshold, because
below it the file is deleted on the next prompt. That residue is accepted.

### Reset: none — `pre-compact-check` is not touched

The approved version reset state from `pre-compact-check.{sh,ps1}`'s exit-0 paths. That required new
stdin JSON parsing in both scripts, a `< /dev/null` fix to `tests/test-pre-compact-check.sh`'s
helpers to stop the new stdin read from hanging them, and coordination with a concurrent change to
the same scripts. The token metric re-arms itself, so all of that is gone. Spike 3's result (the
`PreCompact` payload carries `session_id`) is recorded under Testing but is no longer used by this
design.

### Messages

Plain stdout, exit 0. `UserPromptSubmit` is one of the specific hook events where Claude Code
surfaces plain-text stdout as visible context (confirmed against the hooks reference); most other
events only log stdout to the debug log.

```
[ADVISORY] Context is ~<N>K tokens (nudge point <FIRST>K). Consider a handoff and /compact at the
next natural boundary, or /clear if switching to unrelated work — see CLAUDE.md's Handoff Protocol
and Token Budget sections.
```

The message carries no percentage. The window is inferred, so a hardcoded "40%" would go stale the
moment either the constant or the window changes. That is the lesson CLAUDE.md already records about
figures quoted in-file.

The hook does not choose between `/compact` and `/clear`, or decide whether to hand off. Those are
semantic judgments that `docs/HOOKS-GUIDE.md`'s four-layer table assigns outside what hooks own. What
40% means is already written in the Handoff Protocol; the hook only makes the number visible.

### Failure Handling

Fails open, matching the G2 convention every hook in this repo follows: exit 0, never block a prompt.
Missing `session_id` or `transcript_path`, an unreadable transcript, or a malformed state file all
mean no nudge and a line in `.pmb-hook-errors.log`. A missing `session_id` never falls back to an
unscoped filename.

**Schema drift is logged, not swallowed.** It is the one failure this metric introduces that byte
size did not have. If the scanned tail contains at least one assistant entry but none with readable
`usage`, and no boundary, log `compact-nudge: assistant entries without usage in transcript tail —
transcript schema changed?` to `.pmb-hook-errors.log`. A tail with no assistant entries at all is a
session's first prompt and logs nothing.

## Out of Scope

**Natural-boundary triggers** (a successful `git commit`, a Task Contract flipping to
`status: "complete"`). Considered and deferred: an unproven mechanism stacked on another unproven
mechanism. Possible Phase 2 if this nudge alone proves insufficient in practice.

**Deriving thresholds from the transcript's own history.** `preTokens` on `auto` boundaries gives a
session's empirical auto-compact point, which would remove the window assumption, but only from that
session's second compaction onward. Not built unless the fixed constants prove wrong in practice.

**Rewording the Handoff Protocol trigger** to mention this hook ("reports context >= 40%" plus "or
the compact-nudge advisory fires"). That is the user's call and not part of this change.

**Anthropic's Compaction API** (`compact-2026-09-04` beta). It is a Messages API feature for
applications that manage their own conversations, not the mechanism behind Claude Code's `/compact`
(checked 2026-09-21). No bearing on this design.

## Testing

### Verification spikes (all done 2026-09-21)

1. **`transcript_path` in the `UserPromptSubmit` payload:** present. This spike also surfaced the
   cross-session collision that per-session scoping exists to fix.
2. **Transcript across a real `/compact`:** same path, and the file grew by 408,760 bytes while
   context fell from 452,552 to 116,858 tokens. This invalidated the byte-size metric and led to this
   revision.
3. **`session_id` in the `PreCompact` payload:** present. This design no longer uses it; the result
   is recorded for concurrent worktree and session-claims work that does.
4. **Usage metric vs Claude Code's `preTokens`:** within 1.0% at all four boundaries (table under
   Metric). The stale-usage window after a boundary is 28–45 lines.

**Still unverified, checked at acceptance rather than by another spike:**

- The previous turn's final assistant entry is on disk when `UserPromptSubmit` fires. After wiring,
  compare the hook's reading against `/context` on a few prompts.
- `/clear` behavior. The impact is bounded; see State and escalation logic.

### Behavioral tests: `tests/test-compact-nudge-check.sh`

Fixture transcripts are generated JSONL, never copies of real transcripts, because real ones hold
conversation content. Every case runs against the `.sh`, and against the `.ps1` when `pwsh` is on
PATH. That follows `tests/test-pre-compact-check.sh`'s parity block: skipped without `pwsh`, and made
fatal by `PMB_REQUIRE_PARITY=1`. The `.ps1` is the twin `settings.json` runs first wherever `pwsh`
exists, so testing the `.sh` alone would leave the code path that actually runs on this machine
untested.

- Below `FIRST_THRESHOLD_TOKENS`, no state: no advisory, and no state file is created.
- Crossing `FIRST_THRESHOLD_TOKENS`: advisory printed, and state holds `tokens + RENUDGE_INTERVAL_TOKENS`.
- Next prompt above the first threshold but below the advanced `next_nudge_at`: no advisory. This is
  the negative case `delegation-depth-check.sh` lacks.
- Crossing the advanced `next_nudge_at`: advisory, and state advances again.
- **A `compact_boundary` newer than the last usage entry, with a stale pre-compaction usage above
  `next_nudge_at` further up the file:** no advisory, and the state file is deleted. This is the
  direct regression test for the stale read.
- Usage below the first threshold with state present: state deleted (re-armed).
- Newest usage entry has `isSidechain: true` and an older main entry is below threshold: no advisory,
  because the main entry is the one read.
- Two `session_id`s: independent state files, neither affecting the other.
- Tail has assistant entries but no `usage`: no advisory, and exactly one line in
  `.pmb-hook-errors.log`.
- Tail has no assistant entries (fresh session): no advisory, nothing logged.
- Malformed JSON lines in the tail are skipped, not fatal.
- `\r` in the state file is parsed correctly.
- Missing `session_id`, missing `transcript_path`, or a nonexistent transcript: exit 0, nothing
  written.
- The only usage entry sits beyond `TAIL_LINES` from the end: treated as not found, which bounds the
  scan.

## Files Changed

- New: `scripts/compact-nudge-check.sh`, `scripts/compact-nudge-check.ps1`
- New: `templates/scripts/compact-nudge-check.sh`, `templates/scripts/compact-nudge-check.ps1` (mirrors)
- Edit: `.claude/settings.json`, adding the `UserPromptSubmit` entry in the repo's existing
  `pwsh ... || bash ... || true` form
- Edit: `templates/.claude/settings.json` (mirror)
- Edit: `.gitignore`, adding `.pmb-compact-nudge-*`
- Edit: `scripts/mb.sh` and `scripts/mb.ps1`, adding `.pmb-compact-nudge-*` to `PMB_GITIGNORE_ENTRIES`
  and its `.ps1` twin. These lists must stay identical, and `mb init`/`mb upgrade` use them to write
  ignore rules into adopter repos; the root `.gitignore` alone never reaches an adopter.
- Edit: `docs/HOOKS-GUIDE.md`, adding a new hook entry in the existing numbered-list format
- Edit: `templates/docs/HOOKS-GUIDE.md` (mirror)
- Edit: `standards/PERFORMANCE-BUDGET.md`, documenting `FIRST_THRESHOLD_TOKENS` and
  `RENUDGE_INTERVAL_TOKENS`
- Edit: `templates/standards/PERFORMANCE-BUDGET.md` (mirror)
- New: `tests/test-compact-nudge-check.sh`
- Edit: `tests/run.sh`, adding one `run_suite` line; suites are registered by explicit list

**No longer changed, relative to the approved version:** `scripts/pre-compact-check.{sh,ps1}`, their
`templates/` mirrors, and `tests/test-pre-compact-check.sh`.

## Revision History

- **Approved version (2026-09-21):** metric was transcript byte size against `FIRST_THRESHOLD=400000`
  bytes, with reset done by deleting the state file from `pre-compact-check`'s exit-0 paths.
- **This revision (2026-09-21), after verification spike 2.** Byte size replaced with the API-reported
  token count read from the transcript, validated against `preTokens`. Thresholds rebased from bytes
  on an assumed 200K window to tokens on the observed ~1M window. The reset moved from
  `pre-compact-check` into the hook itself as self-re-arming, which removes every edit to
  `pre-compact-check.{sh,ps1}` and its test. Added the `compact_boundary` stale-read guard, logging
  for schema drift, `.ps1` parity testing, and three missed files (`mb.sh`/`mb.ps1` ignore lists,
  the `templates/standards/PERFORMANCE-BUDGET.md` mirror, `tests/run.sh`).
