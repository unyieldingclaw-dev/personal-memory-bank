---
status: open
created: 2026-09-27
last-reviewed: 2026-10-15
staleness-threshold: 90d
related_plan: null
---

# PreCompact gate can deadlock a session that can no longer take a turn

The PreCompact gate can only be satisfied by a model turn (update the memory bank, or write a `handoff.md`). A session that can no longer take a turn therefore cannot pass it, and at full context every prompt, including `handoff`, fails with "Prompt is too long". The user is left with two ways out: clear the session, which is worse than a lossy compaction, or work around the hook by hand. This is the constraint behind the Codex recovery-only decision (approved 2026-09-16, committed 2026-09-17 as `065d0ae`; `docs/archive/progress-2026-09-16-to-17-codex-precompact-reproduction-and-review.md`): no Codex hook could both block automatic compaction and guarantee an actionable continuation. The archive records that Claude Code kept its gate, but gives no reason. This incident shows that in Claude Code, too, a blocked session may be unable to act on the block.

Related: `[NS-34]` in `memory-bank/activeContext.md` (the gate's midnight expiry and over-block), `precompact-gate-reads-a-worktree-s-own-memory-bank.md` (the path defect that was also present in this incident), and `handoff-md-is-a-single-unscoped-file-shared-across.md` (the bypass's scoping).

## Evidence (2026-09-27, Side-Quest-Atlas worktree `zen-rubin-36fb6d`, transcript `b7e92f76-be34-42d6-8d99-acf962fa1e01.jsonl`)

All of the following was observed by the PMB session from that transcript and those checkouts.

- `CLAUDE_AUTOCOMPACT_PCT_OVERRIDE=65`. Context grew from ~622k tokens (23:54Z) to ~976k (02:30Z) of a 1M window. **No `compact_boundary` appears before the lock-up**, and **no transcript entry records an automatic compaction being attempted or blocked**. The only "Compaction blocked" entries are the three manual `/compact` runs after the first "Prompt is too long".
- So from the transcript alone we cannot tell whether automatic compaction was blocked with nothing recorded, or never fired. Either way the model ran ~2.5 h past the 65% mark with ~350k tokens of headroom and got no signal it could act on.
- **Fixing the path defect would not have prevented this lock-up.** Main's `progress.md` at that time (`0f0f68d`) had no line the gate accepts as a 2026-09-27 entry. Its dates were in forms like `**Update 2026-09-27**:`, which the gate's pattern doesn't match. So reading main's memory bank, the gate would still have exited 2.
- Claude Code's hooks docs (`code.claude.com/docs/en/hooks`, checked 2026-09-27) don't say where a PreCompact exit-2 reason goes (stdout or stderr, the user or the model), and don't say whether the hook differs between manual and auto triggers. They do list `session_id` and `trigger` in the input.
- The manual-trigger block showed the user only the hook's command line. The scripts print their reasons to stdout, and the wiring ends in `2>/dev/null`.
- Side-Quest-Atlas's own CLAUDE.md says the hook "warns". The script it ships blocks.

## Open design question

Pick one: (a) recovery-only, as for Codex (drop the gate and keep `SessionStart(source=compact)` recovery); or (b) block the first `/compact` per `session_id`, pass any repeat with a warning, and let `trigger=auto` pass with a warning. First measure whether an auto-trigger block is visible to the model at all. If it isn't, the auto path is a silent trap and (a) is the simpler fit. Choosing (a) reverses recorded policy for Claude Code, so it also means updating CLAUDE.md's Context Compaction Recovery section and `[NS-34]`. Whichever wins, send the reasons to stderr and drop `2>/dev/null` from both settings.json copies. Record the measurement and the command used here once it's done.
