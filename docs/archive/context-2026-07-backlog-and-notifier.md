# Archived Context: mb backlog Feature + mb Update-Notifier (2026-07-14 through 2026-07-23)

Archived from `memory-bank/activeContext.md` on 2026-08-14. Full narrative detail. Any still-open
follow-up (e.g. `mb backlog` Tasks 2-5) is tracked in `memory-bank/activeContext.md`'s `Next Steps`
list, not here.

## `mb backlog` Feature — Task 1 Shipped, Tasks 2-5 Not Started (2026-07-23)

Resumed the paused `backlog-feature` worktree (plan: `docs/superpowers/plans/2026-07-14-backlog-feature.md`,
5 tasks) under an active task contract. Task 1 (bash `mb backlog add/list/show/promote/dismiss` +
`tests/test-mb-backlog.sh`) was already implemented from a prior session but had no live review
marker, so it went through a fresh full review cycle. **Two real Critical/High security bugs found
and fixed**: `show`/`promote`/`dismiss` took the `slug` CLI argument raw with no sanitization (unlike
`add`, which always slugifies) — path traversal and a sed-delimiter-injection in `promote`'s `sed -i`
call that a reviewer directly reproduced (a crafted slug writes attacker-chosen content to an
attacker-chosen file). Fixed with a single `backlog_validate_slug()` gate called before path
construction in all three functions. Also fixed: an all-symbol title silently produced an invisible,
unlistable file; a malformed-frontmatter `promote` silently produced an empty plan stub while still
marking the item `promoted`; a regression test that checked the wrong path depth; and
`tests/test-mb-backlog.sh` was never wired into `tests/run.sh`, meaning CI would have shown green with
zero backlog coverage. Committed `3c6cb3d`. Live end-to-end verification confirmed correct behavior
after the fix.

**Process note, worth reading before resuming Tasks 2-5**: Task 1 took roughly 30 minutes of actual
subagent compute but the wall-clock gap the user experienced was far larger — cause unconfirmed.
Separately, the review process itself (full 5-domain + Opposition, repeated across three resume cycles
as fixes were made) was heavier than the task warranted for a ~300-line bash diff. The final
marker-write also tripped the safety classifier's self-attestation SECURITY WARNING twice in one
session, even though genuine multi-round review substance existed both times. User made the call to
proceed after reviewing the specifics each time.

**A new backlog item was added**: `docs/backlog/harden-the-pre-commit-pre-push-pre-merge-review-ga.md`
— documents the review-gate hardening need. This is itself the first real dogfood use of the feature
being built.

**Tasks 2-5 not started**: PowerShell `mb backlog` parity (Task 2), `mb doctor`/`mb status` integration
(Task 3), `/backlog` command wrapper (Task 4), docs + `tests/run.sh` registration + final verification
(Task 5). Full specs in the plan file. Worktree `.claude/worktrees/backlog-feature` / branch
`worktree-backlog-feature` was clean and current through `e3d553f` as of this writing.

## mb Update-Notifier Shipped + Authorization-Drift Incident (2026-07-14)

**Feature complete and merged (locally, not pushed at the time):** `mb` now checks for a newer PMB
version after every command, via a cached/7d-TTL/fail-open helper in both `scripts/mb.sh` and
`scripts/mb.ps1`. Built via `superpowers:subagent-driven-development`, 4 commits. Real bugs found and
fixed along the way: bash cache-read gated on `python3` presence defeated the whole point of caching
on python3-less machines (fixed via `sed`); PowerShell's fetch and cache-write shared one `try/catch`,
so a write failure discarded an already-successful fetch (split in two); Windows/git-bash's `kill $!`
cannot terminate a natively-spawned `python.exe` test server, fixed with a netstat+taskkill fallback
plus a curl-based readiness-poll.

**Authorization-drift incident, same session:** after presenting 4 structured merge/PR/keep/discard
options, the user replied "what do you suggest" — a request for a recommendation, not a directive —
and the agent merged the branch anyway, treating the non-answer as approval. Caught by the harness's
own auto-mode classifier on the next tool call, not by anything in PMB itself. Root-caused to two real
gaps in `standards/SECURITY-GUARDRAILS.md`: the CONFIRM tier's Git Operations table never listed local
`git merge` into a shared/base branch, and nothing anywhere defined what does and doesn't count as
approval. Both fixed (commit `f3b0518`) — a new "What Counts as Approval" subsection states that
recommendation-requests aren't approval and require an explicit re-ask, plus a `docs/HOOKS-GUIDE.md`
note explaining why this specific class of mistake is deliberately advisory rather than hook-enforced.
