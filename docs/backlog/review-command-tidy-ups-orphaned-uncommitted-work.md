---
status: open
created: 2026-09-22
last-reviewed: 2026-09-25
staleness-threshold: 90d
related_plan: null
---

# Orphaned uncommitted work in `.claude/worktrees/review-command-tidy-ups`

**Current state (verified 2026-09-25): no longer orphaned or uncommitted.** The work is committed
as `3edef15` on `worktree-review-command-tidy-ups` and is the head of PR #47, OPEN. Its parent is
`ac63ccb`, one commit behind `main` (`739f0eb`), and GitHub reports the PR `BEHIND`, so it needs a
branch update before the user-run merge. The worktree's contract reads `status: complete`, and
`git status` there shows no task files. Close this item once PR #47 merges. Checked with
`git -C .claude/worktrees/review-command-tidy-ups log -1 --format='%h parent=%p'`, that worktree's
`.claude/contracts/active-task.json`, and `gh pr view 47 --json mergeStateStatus`.

**Everything below is a 2026-09-22 snapshot**, kept as the record of how the work was found. Its
contract dates, "uncommitted diff" and blocker list describe that day, not today.

Found 2026-09-22 while cross-checking a peer session's `handoff.md` (dated 2026-09-21 14:43). The
handoff described "Item 2": a task-contract-approved fix in progress in this worktree, with a
background `/code-review` opposition pass (agent `a239e954f4e1a07cf`) whose result was unknown at
handoff time. At discovery time, `grep -rln 'review-command-tidy-ups\|f1ae4ce'
memory-bank/*.md docs/archive/*.md` returned nothing — the work had fallen through an earlier
compaction uncaptured, on `worktree-review-command-tidy-ups`, HEAD `dd8dd74` (PR #42's squash-merge,
now well behind current `main`). That search scope was itself incomplete (see "Correction" below).
The live memory-bank record is now `[NS-62]` in `activeContext.md`, added by the "Brainstorm video"
peer session — this file is the detail `[NS-62]` points to, not a second pointer.

**Correction:** an earlier draft of this file claimed the review behind the "8 defects" figure
(below) was unfindable anywhere in the repo, based on the grep above. That grep never covered
`docs/backlog/*.md`, where the source review already lived:
`docs/backlog/review-command-and-baseline-health-tidy-ups-after.md` (created 2026-09-08). It
enumerates exactly 8 items, matching the worktree's uncommitted diff item-for-item (see next
section). Caught by a `/code-review` Maintainability + Testing/Evidence-Integrity pass on this
file's own first draft.

**Correction:** an earlier draft also claimed `handoff.md` had been "archived by that peer" without
re-checking. At the time that was false — the file was still present at the repo root, unprocessed.
It has since genuinely been archived: the "Brainstorm video" peer confirmed (cross-session message,
2026-09-22) it copied `handoff.md` byte-identical to
`C:/Users/Mizzo/Claude/pmb-session-artifacts/2026-09-21/handoff-pmb-full-review.md` (out of repo,
matching this repo's convention for holding-pen artifacts — see e.g. `progress.md`'s 2026-09-11
entry) and removed it from the repo root.

## What the work actually is

Task contract (`.claude/worktrees/review-command-tidy-ups/.claude/contracts/active-task.json`,
`approved_by: user`, created `2026-09-21T18:25:51Z`, expired `2026-09-22T02:25:51Z` — confirmed
expired, ~14h56m overdue as of `2026-09-22T17:21:38Z`, per `date -u '+%Y-%m-%dT%H:%M:%SZ'`): "Fix 8
non-blocking defects deferred from the `f1ae4ce` review" (`f1ae4ce`, 2026-09-08, `feat: extract the
CI baseline checks into a runnable script` — the original commit that added
`scripts/baseline-health.sh`). The 8 defects are enumerated in
`docs/backlog/review-command-and-baseline-health-tidy-ups-after.md`.

Uncommitted diff, 6 files, 144 insertions / 31 deletions:

- `scripts/baseline-health.sh` — adds a python3+PyYAML duplicate-step-name detector for the File
  Size job's step-extraction guard, with graceful fallback to the prior exact-line grep when
  python3/PyYAML are unavailable. Closes a real gap: a step redeclared in YAML flow-mapping style
  (`- { name: ..., run: ... }`) was invisible to the old grep, so a smuggled duplicate step could run
  under a trusted check's name undetected.
- `tests/test-baseline-health.sh` — hardens `new_sandbox()`'s cleanup (every failure path after
  `mktemp -d` now explicitly removes its temp dir instead of leaking an ~80MB cloned repo per call);
  adds mutation test 6b proving the flow-style duplicate detector actually fires; replaces a
  hardcoded literal `"7"` anti-vacuity assertion with `native_steps_count()`, a second independent
  parse of the same `STEPS` array compared against the first, so the anti-vacuity floor itself can't
  silently rot as entries are added or removed.
- `.claude/commands/code-review.md` + `change-review.md` (+ `templates/` mirrors) — the exit-3
  documentation now covers "a step's name matched more than one step (ambiguous/duplicate)", not
  only "renamed or re-indented".

## Verification done 2026-09-22

Ran `bash tests/test-baseline-health.sh` directly: **46 passed, 4 failed**. All 4 failures are the
same root cause, not 4 independent defects: the suite's own "clean clone" control case (and its
`--no-fetch` variant) exits 1 instead of the expected 0. Reproduced by hand — cloning the worktree
into a sandbox exactly as `new_sandbox()` does and running the unmodified script:

```
FAIL:    Check file sizes
         FAIL: startup context grew 99.1 KB vs 99.1 KB on origin/main (+3 bytes)
```

Root cause: this worktree's own checked-out commit (`dd8dd74`) predates 2026-09-22's `[NS-N]` audit
trimming (PR #44) and is 3 bytes heavier than current `origin/main` — so the sandbox's "clean" clone
genuinely fails the real, CI-enforced ratchet before any test mutation is even applied. This is
branch staleness, the same class of problem PR #43 and #44 both hit this session (squash-merge SHA
divergence / a stale base), **not a defect in the reviewed code**. Every test specific to the new
functionality — flow-style duplicate detection (5/5), the `native_steps_count` anti-vacuity check
(2/2), the broader mutation suite (all renamed/re-indented/duplicate/Unicode/grep-failure cases) —
passed cleanly.

## What blocked shipping this (as of 2026-09-22 — see "Current state" above for what remains)

1. Update the branch onto current `origin/main` — same pattern used twice this session (a real
   `git merge`, not another rebase, to stay force-push-free; `git merge` into a base-branch-adjacent
   target hit a CONFIRM-tier guardrail requiring the human to run it directly both times it was
   needed today).
2. Re-run `tests/test-baseline-health.sh` — expect 50/50 once the control case sees an up-to-date
   baseline.
3. A full `/code-review` (5 domains + opposition) has never completed for this diff — the one
   background opposition attempt (`a239e954f4e1a07cf`) died with its parent session before writing a
   result (its output file exists, from a now-gone session, and is empty). No `/code-review` or
   `/change-review` marker has ever existed for this branch.
4. `/change-review`, commit, push, PR, user-run merge — same pipeline as PR #43/#44.

Not touched by this entry: whether to actually pick this work up now, or who does it — `[NS-62]`
says the "PMB full review" session (this one) is picking it up, which is a claim about intent, not
yet a commitment executed.
