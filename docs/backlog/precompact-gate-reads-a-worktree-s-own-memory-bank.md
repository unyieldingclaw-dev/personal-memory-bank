---
status: open
created: 2026-09-21
last-reviewed: 2026-10-18
staleness-threshold: 90d
related_plan: null
---

# PreCompact gate reads a worktree's own memory-bank, not main's

**Status 2026-10-18: fixed in journal mode only.** The C1 journal (PR #57, `d751b73`) keeps its records
under the shared git common dir, so its gate reads the same state from every worktree. Journal mode
stays off until Plan C's flag PR (`[NS-68]`). The legacy gate described below is unchanged and still
has this defect.

`scripts/pre-compact-check.sh` reads `handoff.md` (line 56), `memory-bank/activeContext.md` (line 79) and `memory-bank/progress.md` (line 108) relative to the current directory; the `.ps1` twin does the same. For a session whose working directory is a linked worktree, that is the branch's stale copy of memory-bank/, not the main worktree's. Measured 2026-09-21: the gate exited 0 from a fresh worktree only because origin/main's progress.md happened to carry that day's entry. On any later day a worktree session can satisfy it only by editing the worktree's memory-bank/ (which CLAUDE.md forbids, and which `.githooks/pre-commit` now refuses to commit) or by leaving a handoff.md in the worktree root.

Fix: resolve memory-bank/ from the main worktree -- `git rev-parse --git-dir` vs `--git-common-dir`, normalized with `cd && pwd -P` as in `.githooks/pre-commit`, not `realpath` (measured missing-realpath fail-open in mb.sh). Change ONLY the memory-bank/ paths, with no global `cd`. Do NOT move handoff.md to the main root: the gate exits 0 for any handoff.md dated today in its directory, whoever wrote it, so resolving it from the main root would hand every worktree session another session's bypass. Per-session handoff is a separate, unscoped problem (logged by the compact-nudge session, 2026-09-21).

Coordinated 2026-09-21 with the compact-nudge work: its redesign no longer touches pre-compact-check.{sh,ps1}, their templates/ copies, or tests/test-pre-compact-check.sh. Scope: both twins, both TEMPLATE_OWNED mirrors, tests/test-pre-compact-check.sh.

## Present in a field incident, 2026-09-27 — but not its sole cause

Side-Quest-Atlas session "Fix stale claims in docs/HOOKS-GUIDE.md" (worktree `.claude/worktrees/zen-rubin-36fb6d`) filled its context mid-edit. From then on every `/compact` was blocked and every prompt, including `handoff`, returned "Prompt is too long". Reproduced from that worktree: the gate exits 2 with `progress.md has no entry dated 2026-09-27`. The session was unwedged from outside by the PMB session: it wrote a gitignored `handoff.md` into the worktree root, then re-ran the gate and saw it exit 0. The main lesson is in `precompact-gate-can-deadlock-a-session-that-can-no.md`.

**This defect was present but did not cause the block on its own.** The same gate exited 0 from that repo's main checkout. That was NOT because main's memory bank was fresh: main's `progress.md` (`0f0f68d`) had no line the gate accepts as a 2026-09-27 entry. Main passed only because a `handoff.md` headed "Handoff — 2026-09-06" was still in its root. With this item's fix applied, the gate would still have exited 2. The 2026-09-27 reproduction missed this because it never checked main's root for a handoff; a later review caught it.

Two fleet hazards it exposed:

- **Side-Quest-Atlas ran the pre-2026-08-27 gate**, where any `handoff.md` bypasses regardless of date. The unwedging file therefore disabled the gate in that worktree until it was deleted. The successor session was told so in the file itself. It resumed and compacted, and the file was deleted 2026-10-15; the gate was re-checked and exited 2 (armed).
- **A spent handoff silently disabled the main checkout's gate.** Session transcripts show the 2026-09-06 handoff being read there from 2026-09-07 through 2026-10-02 (UTC), and it was gone by 2026-10-15. This is the failure the 2026-08-27 staleness fix exists for, still live in an un-upgraded repo. `mb upgrade` there closes it.
