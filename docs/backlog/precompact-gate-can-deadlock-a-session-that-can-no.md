---
status: open
created: 2026-09-27
last-reviewed: 2026-10-18
staleness-threshold: 90d
related_plan: null
---

# PreCompact gate can deadlock a session that can no longer take a turn

**Status 2026-10-18: fixed in journal mode only.** PR #57 (`d751b73`) implements option (b) below for the
journal-mode gate:
- an automatic compaction is never blocked;
- a manual `/compact` is blocked once, and an immediate repeat passes.

Journal mode stays off until Plan C's flag PR (`[NS-68]`). The legacy gate still blocks both triggers
and still has this deadlock. The question below remains open for it.

The PreCompact gate can only be satisfied by a model turn (update the memory bank, or write a `handoff.md`). A session that can no longer take a turn therefore cannot pass it, and at full context every prompt, including `handoff`, fails with "Prompt is too long". The user is left with two ways out: clear the session, which is worse than a lossy compaction, or work around the hook by hand. This is the constraint behind the Codex recovery-only decision (approved 2026-09-16, committed 2026-09-17 as `065d0ae`; `docs/archive/progress-2026-09-16-to-17-codex-precompact-reproduction-and-review.md`): no Codex hook could both block automatic compaction and guarantee an actionable continuation. The archive records that Claude Code kept its gate, but gives no reason. This incident shows that in Claude Code, too, a blocked session may be unable to act on the block.

Related: `[NS-34]` in `memory-bank/activeContext.md` (the gate's midnight expiry and over-block), `precompact-gate-reads-a-worktree-s-own-memory-bank.md` (the path defect that was also present in this incident), and `handoff-md-is-a-single-unscoped-file-shared-across.md` (the bypass's scoping).

## Evidence (2026-09-27, Side-Quest-Atlas worktree `zen-rubin-36fb6d`, transcript `b7e92f76-be34-42d6-8d99-acf962fa1e01.jsonl`)

All of the following was observed by the PMB session from that transcript and those checkouts.

- `CLAUDE_AUTOCOMPACT_PCT_OVERRIDE=65`. Context grew from ~622k tokens (23:54Z) to ~976k (02:30Z) of a 1M window. **No `compact_boundary` appears before the lock-up**, and **no transcript entry records an automatic compaction being attempted or blocked**. The only "Compaction blocked" entries are the three manual `/compact` runs after the first "Prompt is too long".
- So from the transcript alone we cannot tell whether automatic compaction was blocked with nothing recorded, or never fired. Either way the model ran ~2.5 h past the 65% mark with ~350k tokens of headroom and got no signal it could act on.
- **Fixing the path defect would not have prevented this lock-up.** Main's `progress.md` at that time (`0f0f68d`) had no line the gate accepts as a 2026-09-27 entry. Its dates were in forms like `**Update 2026-09-27**:`, which the gate's pattern doesn't match. So reading main's memory bank, the gate would still have exited 2.
- Claude Code's hooks docs (`code.claude.com/docs/en/hooks`, checked 2026-09-27) don't say where a PreCompact exit-2 reason goes (stdout or stderr, the user or the model), and don't say whether the hook differs between manual and auto triggers. They do list `session_id` and `trigger` in the input. **Superseded 2026-09-29** by the C1 spec's U12
(`docs/superpowers/specs/2026-09-26-multi-session-memory-design.md`). The docs, read again, say the
reason reaches the user only, never the model. Measured on the CLI: a JSON `reason` on stdout is shown
with the existing `2>/dev/null` wiring, and stderr text is not shown.
- The manual-trigger block showed the user only the hook's command line. The scripts print their reasons to stdout, and the wiring ends in `2>/dev/null`.
- Side-Quest-Atlas's own CLAUDE.md says the hook "warns". The script it ships blocks.

## Open design question

For the legacy gate, pick one:
- **(a) Recovery-only, as for Codex.** Drop the gate and add a `SessionStart(source=compact)`
  recovery hook. Codex has one; this repo's `.claude/settings.json` has none.
- **(b) Block once.** Block the first `/compact` per `session_id`, pass any repeat with a warning, and
  let `trigger=auto` pass with a warning. This is what journal mode does.

Per U12, a blocked automatic compaction never reaches the model, so for the model the auto path is a
silent trap under any gate that blocks it.

Choosing (a) reverses recorded policy for Claude Code. Start from `grep -rln PreCompact` outside
`docs/archive`, `docs/backlog`, `docs/superpowers` and `CHANGELOG.md`. On 2026-10-18 that named:
- `CLAUDE.md` (Context Compaction Recovery) and `templates/CLAUDE.md`;
- `AGENTS.md` and `templates/AGENTS.md`;
- `standards/MEMORY-BANK.md`;
- `docs/HOOKS-GUIDE.md` and `templates/docs/HOOKS-GUIDE.md`;
- `docs/CURSOR-VS-CLAUDE.md` and `docs/QUICK-REFERENCE.md`;
- `templates/handoff.md`;
- both `settings.json` copies.

Update `[NS-34]` too.

Whichever wins, emit the reason as JSON on stdout. That form is measured to reach the user with the
current wiring; stderr is not.
