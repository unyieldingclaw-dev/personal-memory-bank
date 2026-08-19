# Archived Progress: mb backlog Feature Task 1 + mb Update-Notifier (2026-07-14, 2026-07-23)

Archived from `memory-bank/progress.md` on 2026-08-14. Full forensic detail. See `memory-bank/progress.md`
for a condensed pointer and `memory-bank/activeContext.md`'s `Next Steps` ([NS-0]) for the still-open
`mb backlog` Tasks 2-5.

## `mb backlog` Feature — Task 1 Shipped (Security Bugs Found + Fixed), Tasks 2-5 Not Started (2026-07-23)

- ✅ Resumed the paused `backlog-feature` worktree under an active task contract. Brought the stale
  worktree current with `docs/branch-protection-rollout` (clean fast-forward) before starting.
- ✅ Task 1 (`mb backlog add/list/show/promote/dismiss` + `tests/test-mb-backlog.sh`) was already
  implemented from a prior session but had no live review marker — went through a full 5-domain
  `/code-review` pass.
- 🔴 **Two real Critical/High security bugs found, both directly reproduced by the reviewer, both
  fixed**: `show`/`promote`/`dismiss` all took the `slug` CLI argument raw with no `..`/`/` rejection —
  unlike `add`, which always slugifies. (1) Path traversal: a crafted slug escapes `docs/backlog/`,
  letting `show` disclose arbitrary file contents. (2) Sed-delimiter injection: `promote`'s `sed -i`
  interpolates the unsanitized slug unescaped — a crafted slug is parsed by sed as a write-flag,
  letting an attacker write chosen content to a chosen file (reviewer reproduced this exact primitive
  standalone). Fixed with one `backlog_validate_slug()` gate called before path construction in all
  three functions.
- ✅ Also fixed: an all-symbol title silently created an invisible, unlistable file; a
  malformed-frontmatter file hitting `promote` silently produced an empty plan stub while still
  marking the item `promoted`.
- ✅ **Maintainability domain caught the highest-value non-security finding**: `tests/test-mb-backlog.sh`
  was never added to `tests/run.sh`'s `run_suite` list — this diff, merged alone, would have made CI
  show green with zero backlog test coverage. Added the one-line registration to Task 1's commit.
- ✅ Opposition review also caught that a new regression test didn't test what it claimed (wrong path
  depth for the planted sentinel file) — fixed.
- ✅ Committed `3c6cb3d`. 31/31 tests passing. **Live end-to-end verification performed**: ran real
  commands plus both attack payloads against the actual command from a scratch directory — both
  correctly rejected.
- ⚠️ **Marker-write hit the safety classifier's self-attestation SECURITY WARNING twice in one commit
  cycle** — once for the parent implementer subagent, once for a second, independently re-dispatched
  verification subagent, despite both having done genuine review work. Surfaced explicitly to the user
  both times; user approved each time. Tracked as its own backlog item rather than treated as fully
  resolved by the 2026-07-16 self-attestation fix.
- ⚠️ **Process cost, worth reading before resuming Tasks 2-5**: Task 1's actual subagent compute summed
  to roughly 30 minutes, but the user experienced a much larger real-world gap (~11am to ~6:30pm) —
  cause unconfirmed. The review process itself ran three full cycles for a single ~300-line bash diff
  — heavier than warranted; worth scoping review depth to diff size more deliberately going forward.
- ✅ **First real dogfood use of the feature just built**: added a backlog item via `mb backlog add` —
  `docs/backlog/harden-the-pre-commit-pre-push-pre-merge-review-ga.md`.
- 📌 Tasks 2-5 (PowerShell parity, `mb doctor`/`mb status` integration, `/backlog` command wrapper, docs
  + final verification) not started as of this writing.

## 2026-07-14 — mb Update-Notifier + Approval-Semantics Guardrail Fix

- ✅ Shipped the `mb` update-notifier feature via `superpowers:subagent-driven-development` on worktree
  branch `worktree-mb-update-notifier`, 4 commits, each independently passed a real 5-domain
  `/code-review` plus a final whole-branch integration review. Three real bugs found and fixed
  pre-commit: bash cache-read gated on `python3` presence silently defeated the caching design on
  machines without it (switched to `sed`); PowerShell's fetch and cache-write shared one `try/catch`,
  so a write failure discarded an already-successful fetch (split in two); `mb update` double-printed
  both its own `[WARN]` and the new generic `[NOTICE]` — caught only by the final whole-branch review.
  Also fixed real Windows/git-bash test flakiness: `kill "$SRV_PID"` cannot terminate a
  natively-spawned `python.exe` test HTTP server (a netstat-discovered PID worked instead), and a flat
  `sleep 1` was marginal (replaced with a curl-based readiness poll).
- ✅ Merged into `docs/branch-protection-rollout` (its true base) — a rebase-onto-`main` attempt was
  tried first, hit a real conflict, and was aborted rather than blindly resolved.
- ⚠️ **Authorization-drift incident, same session:** after presenting the standard 4-option
  finishing-a-branch menu, the user replied "what do you suggest" (a request for a recommendation) and
  the agent merged the branch anyway, misreading the non-answer as approval. Caught by the harness's
  own auto-mode classifier on the very next tool call. Root cause: `standards/SECURITY-GUARDRAILS.md`'s
  CONFIRM tier never listed local `git merge` into a shared/base branch, and nothing anywhere defined
  what does and doesn't count as approval.
- ✅ Fixed (commit `f3b0518`): added "merge into a shared/base branch" to the CONFIRM tier, and a new
  "What Counts as Approval" subsection stating that recommendation-requests are not approval — the
  agent must state its recommendation and explicitly re-ask. Deliberately advisory, not hook-enforced —
  documented the reasoning in `docs/HOOKS-GUIDE.md` as a worked example.
