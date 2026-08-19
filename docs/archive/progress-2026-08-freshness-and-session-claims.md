# Archived Progress: Memory Bank Freshness Hook + Concurrent Session Claims (2026-08-08, 2026-08-10)

Archived from `memory-bank/progress.md` on 2026-08-14. Full forensic detail. See `memory-bank/progress.md`
for a condensed pointer and `memory-bank/activeContext.md`'s `Next Steps` ([NS-13] and `/ai-review` for
the concurrent-session-claims branch) for anything still open.

## 2026-08-10 — Memory Bank Freshness Hook: Designed, Spec Committed

- ✅ Ran `superpowers:brainstorming` in response to a reported incident in `ai-code-review-agent`: six
  significant units of work landed in one session with zero `memory-bank/` writes, because CLAUDE.md's
  "update memory-bank after significant work" rule is purely advisory.
- ✅ Verified `ai-code-review-agent` is genuinely PMB-managed but stale — settled scope as
  `TEMPLATE_OWNED`, shipped via `mb upgrade`.
- ✅ Design settled through several rounds of direct pushback rather than defaults: hybrid
  warn-then-block, stateless `git log` lookback over a persistent counter file (avoids the
  corruption-class bugs `concurrent-session-claims` needed several rounds to fix in a comparable state
  file), commit-only trigger, and an explicit exemption for commits made inside a git worktree.
- ✅ **Two real bugs caught by re-reading the repo's own existing code before finalizing:** the
  current-commit exemption originally checked `git diff --cached --name-only`, which would miss a
  `memory-bank/` edit picked up by `git commit -am` — fixed to `git diff HEAD --name-only`, matching
  `_review-gate-lib.ps1`'s own `Get-CommitDiffHash` precedent. Also surfaced a real sharp edge: a
  worktree branch's commits carry their full streak onto main once merged, so a skipped post-merge
  memory-bank commit jumps straight to a hard block with no graduated warning. Decided this is
  intended, documented explicitly in the spec.
- ✅ Spec committed: `docs/superpowers/specs/2026-08-10-memory-bank-freshness-hook-design.md` (`3e475ae`).
- 📌 Not yet implemented as of this writing.

## 2026-08-08 — Concurrent Session Claims Feature Shipped

- ✅ Implemented `docs/superpowers/specs/2026-08-04-concurrent-session-claims-design.md` via
  `superpowers:writing-plans` (13 tasks) → `superpowers:subagent-driven-development`, worktree branch
  `worktree-concurrent-session-claims`, 23 commits.
- ✅ **Mechanism:** `.claude/session-claims.json` (gitignored, canonical in the main worktree only) lets
  multiple Claude Code sessions working this repo at once coordinate on which Next Steps item each is
  working. `mkdir`-based lock with 30s staleness theft, atomic temp-file-then-rename writes,
  self-pruning. Six CLI actions, independently implemented in bash+python3 and PowerShell with full
  behavioral parity. New `SessionStart` hook (`notify`) surfaces live claims automatically. Two new
  `mb doctor` checks. `activeContext.md`'s Next Steps items got stable `[NS-N]` ids.
- ✅ **Real bugs found and fixed across the build, each via TDD + two-stage review**: a `set -u`
  crash/infinite-hang on a dangling trailing CLI flag; a PowerShell array-unwrap bug where a 0/1-element
  claims list serialized wrong — found once generally, then again specifically in `notify`'s
  independent code path, where it briefly **corrupted the live claims file**; missing required-field
  validation on the PowerShell twin's `release`/`force-clear`; an em-dash literal that bash wrote as
  invalid UTF-8 and PowerShell silently substituted with a hyphen; an empty claims file silently
  passing PowerShell's validity check; an unguarded TOCTOU race in `mb doctor`'s PowerShell lock-age
  check; and — found only in the final whole-branch review, after every individual task had already
  passed its own review — PowerShell silently mutating every claim's timestamps from UTC to local
  timezone on every re-save, via `ConvertFrom-Json`'s automatic `[DateTime]` coercion; fixed by forcing
  both timestamp fields back to plain UTC ISO-8601 strings immediately after parse.
- ✅ **Process notes:** this repo's `/code-review` commit gate blocked every single agent-run commit in
  this build (as designed) — the user ran each `git commit` directly in their own terminal for all ~23
  commits. A design-spec correction was needed at planning time (`resolve_cd_root()` doesn't apply to a
  script with no gated command; `git rev-parse --git-common-dir` was the right primitive).
- Full test coverage: `tests/test-session-claims.sh` (51 assertions), 2 new assertions in
  `tests/test-mb-doctor.sh`, both registered in `tests/run.sh`. Full suite green throughout.
- **Task 13 (the `[NS-N]` retrofit) intentionally landed on `docs/branch-protection-rollout` directly,
  not this feature's worktree branch** — `memory-bank/activeContext.md` can never be committed from a
  subworktree. A final whole-branch reviewer initially flagged this as a "Critical: task never
  executed" finding, looking only at the worktree's own branch history — false alarm, corrected after
  independent verification; worth remembering as a real failure mode for any future whole-branch review
  of a multi-worktree feature.
- **Not yet done as of this entry:** merge/PR decision for `worktree-concurrent-session-claims`, and an
  `/ai-review` pass has not yet been run against the branch.
