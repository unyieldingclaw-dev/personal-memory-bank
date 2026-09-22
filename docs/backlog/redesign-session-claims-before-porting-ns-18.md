---
status: open
created: 2026-09-21
last-reviewed: 2026-09-21
staleness-threshold: 90d
related_plan: null
---

# Redesign session-claims before porting NS-18

Assessment of branch `worktree-concurrent-session-claims` (tip f65ed0c) against current main, 2026-09-21. Verdict: targeted redesign, then a main-forward port. The lock/prune/atomic-write core is sound; these parts are not.

1. **Claim identity (most severe).** `claim_id` is the branch/worktree name, so two sessions in one checkout share an identity: a second claim on the same item overwrites instead of conflicting, and one session's bulk `release` frees the other's claims (session-claims.sh:130-136, 160-165; .ps1:160-161, 179-193). The main checkout routinely hosts several sessions. Needs a per-session key. Hook payloads carry a distinct `session_id` per session in both UserPromptSubmit and PreCompact (confirmed by the compact-nudge spike, 2026-09-21); `scratchpad_dir` stayed identical across 4 payloads spanning 3 prompts and a /compact, and is a candidate key the agent itself can see -- unverified that it matches the agent's own scratchpad path.
2. **Force-clear breadcrumb** requires a line in memory-bank/activeContext.md (SESSION-CLAIMS-GUIDE.md:70-72, standards/MEMORY-BANK.md:361-362 on the branch), which a worktree session may not write. No code performs it. Record it in the claims file and surface it via `notify`.
3. **Silent no-ops.** Missing `realpath` -> exit 0; missing `python3` -> exit 0; inside a submodule the root resolves into `.git/modules`. Use the git-dir/common-dir resolution from `.githooks/pre-commit`, and warn instead of staying silent.
4. **12h TTL, no renewal.** Re-running `claim` refreshes; document that and show time remaining in `notify`.
5. **Port traps.** The branch's templates/scripts/session-claims.ps1 is stale vs its live copy (missing the DateTime normalization; main's mirror-parity test in CI will catch it). Its CLAUDE.md edit targets Handoff Protocol text main has since rewritten. python3 adds a caller to the open Tier-1 "no external dependencies" decision. CHANGELOG's "Pending -- session-claims" section moves into a release section only when the port lands.
6. **Scope, stated plainly.** The branch does NOT implement an authorship-bound review marker: its delta (`git diff 8477c75 f65ed0c`, 19 files, 2 already on main) touches no review-gate file, and its spec's Non-Goals exclude locking. The collisions actually observed on 2026-09-21 were shared files in the main checkout (handoff.md, hooks in .claude/settings.json, uncommitted memory-bank/ edits), which claims exclude by design. A redesign spec should decide whether per-session handoff belongs with it.

The NS-26 regression risk (live `trap - EXIT`, zero `write_marker_atomic`) is in the branch's base, not its delta, so applying only the delta to main's files avoids it.
