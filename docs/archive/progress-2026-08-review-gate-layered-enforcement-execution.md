# Archived Progress — Review-Gate Layered Enforcement: 14-Task Execution (2026-08-17)

Archived from `memory-bank/progress.md` on 2026-08-18 to bring that file back under its
400-line CI-enforced limit. Condensed pointer left in place there; nothing operationally
open was dropped — the branch itself (`feature/review-gate-layered-enforcement`) and its
still-pending merge/rebase status are tracked in `activeContext.md`'s Task #33 deferral note.

## 2026-08-17 — Review-Gate Layered Enforcement: All 14 Tasks Implemented and Committed

- ✅ `docs/superpowers/plans/2026-08-12-review-gate-layered-enforcement.md`'s 14 tasks all committed on
  `feature/review-gate-layered-enforcement` (branched from `07788ad`, isolated in
  `.claude/worktrees/review-gate-layered-enforcement`), each via the same cycle: implement (directly, or
  via a scoped implementer subagent forbidden from self-committing/self-marking) → independently verify
  the diff → dispatch an Opposition reviewer (own `pwd` check first, per the Task 5 incident below) → the
  orchestrator independently re-verifies the marker hash before every commit. Full 20-suite test run green
  (`All test suites passed.`) after every task; not yet merged to `main` or pushed.
- 🔴 **Testing item #8's empirical merge-commit result, unresolved at design time (Known Limitation #4):
  a non-fast-forward `git merge` does NOT fire Layer 2's `pre-commit` hook** — confirmed via a live merge
  in a throwaway repo (Task 8). Documented in the design spec and `docs/HOOKS-GUIDE.md` as a known residual
  gap alongside `--no-verify`; Layer 3 (CI containment) is unaffected since it checks commits, not hooks.
- 🔴 **Three real bugs found only because the new test suites were fixed to actually exercise what they
  claimed to, not because anyone went looking for them:**
  1. Task 8's Layer 2 suite silently tested `pre-commit-check.ps1`/`pre-push-check.ps1` instead of the
     `.sh` scripts on any pwsh-equipped machine (incl. this repo's own CI) — the throwaway test repos'
     hooks inherited the real delegator's pwsh-first preference. Fixed by forcing bash explicitly in the
     test fixtures. That fix then surfaced a genuine `set -e` crash in already-shipped `pre-push-check.sh`
     (Task 5): `consume_marker()`'s non-zero return on a missing marker terminated the script under
     `set -e` before it could print its own deny message — push was still blocked, just silently.
  2. Task 9's rewritten peek-only assertion expected a deny that the actual (correct) peek-only behavior
     never produces, and a `resolve_cd_root()` regression test compared a POSIX-style path against a
     Windows-style one returned by the same underlying `git rev-parse` call on this machine — both were
     test bugs, not product bugs, found via the same "run it and see" discipline.
  3. Task 13's `findings_has_blocking()` (present verbatim in the plan's own text) only checked the LAST
     cell of a findings table row — correct for `code-review.md`'s schema but silently wrong for
     `change-review.md`'s (which has a trailing `Confidence` column after `Blocking`), meaning a blocked
     change-review entry would have been treated as clean coverage by the CI containment check. An
     Opposition reviewer caught this on the first pass; fixed to match anywhere in the row, with a new
     regression fixture.
- ✅ One further real bug independently found and fixed while wiring `.github/workflows/pmb-health.yml`:
  the plan's Step 3 assumed `mb-doctor-self-check` was still the last job in the file — it wasn't; an
  already-merged, unrelated commit (`4321147`, wiring Pester into CI) had since added `pester-tests` after
  it. The new `review-gate-containment` job was inserted after the actual last job instead.
- 📌 Every deviation from the plan's literal text (listed above, plus two test-fixture branch-topology
  fixes in Task 13) was independently verified and justified by a re-dispatched Opposition reviewer before
  commit — not just applied and assumed correct.
- 📌 **Not yet done:** wiring `review-gate-containment` into branch protection's required-status-checks
  (a manual, CONFIRM-tier GitHub settings change per `standards/SECURITY-GUARDRAILS.md`, explicitly left
  for the user); merging/pushing the feature branch itself.
