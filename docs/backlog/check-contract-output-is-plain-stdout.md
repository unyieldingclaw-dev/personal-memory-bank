---
status: open
created: 2026-10-14
last-reviewed: 2026-10-14
staleness-threshold: 90d
related_plan: null
---

# The Contract Scope Check's output reaches no one

`check-contract.sh` and `check-contract.ps1` (and their `templates/` copies) still print plain
text. A `PreToolUse` hook's plain stdout never reaches the model (PR #55 measured this on
2026-10-14 and fixed it for three other hooks) and, per Claude Code's docs, is not shown in the
visible transcript; Claude Code only records it (debug log, session file). PR #55 did not touch
these two, so all three of their outputs are lost:

- **Out-of-scope write (default).** The `CONTRACT SCOPE` warning reaches neither the user nor the
  model (the model side was measured; the user side rests on Claude Code's docs, since a headless
  run cannot show it). The Task Contract Protocol step "If the hook warns that a write is outside
  the declared scope, pause" therefore has no live signal. It appears in `CLAUDE.md`, `AGENTS.md`
  and `templates/CLAUDE.md`, and both `CONTRACTS-GUIDE.md` copies say "the `check-contract` hook
  warns if Claude writes outside the declared scope" (step 4 of their opening list).
- **Expired contract.** The `CONTRACT EXPIRED` notice is lost too, and the expiry branch exits 0
  before the scope check runs. So an expired contract silently turns scope checking off.
- **Hard-block mode (`PMB_CONTRACT_HARD_BLOCK=1`).** Both twins print the scope warning (`echo` /
  `Write-Host`) before the deny JSON, so stdout is not one JSON object and the deny is ignored. The
  setting is not enabled in either `settings.json`, so nothing relies on it today, but
  `standards/SECURITY-GUARDRAILS.md` says the hook "exits 2" (it exits 0) and `docs/HOOKS-GUIDE.md`
  says the call "is denied", each with a `templates/` copy. No test covers the hard-block path
  (`grep -rln HARD_BLOCK tests` finds nothing at `bea0823`).

Fix outline: give both twins the same single-object output the other WARN hooks now use
(`systemMessage` and/or `additionalContext` for WARN and EXPIRED; `permissionDecision: deny` with no
other stdout for hard-block), cover all three paths in `tests/test-hook-warn-output.sh`, and correct
the docs above and their copies. Whether an expired contract should keep checking scope, or deny, is
the open design question in the contract-expiry proposal.

Related: `memory-bank/activeContext.md` `[NS-66]` (contract-expiry proposal) and `[NS-67]` (a)
and (d), which land with PR #56 and are absent until it merges. The proposal's outline, per
`[NS-66]`: an expired contract denies, plus renewal and worktree fields. In desktop worktree sessions the hooks may read the main checkout's contract, not the
worktree's (`[NS-67]` (d), not verified).
