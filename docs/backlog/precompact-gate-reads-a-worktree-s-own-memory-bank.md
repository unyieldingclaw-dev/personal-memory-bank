---
status: open
created: 2026-09-21
last-reviewed: 2026-09-21
staleness-threshold: 90d
related_plan: null
---

# PreCompact gate reads a worktree's own memory-bank, not main's

`scripts/pre-compact-check.sh` reads `handoff.md` (line 56), `memory-bank/activeContext.md` (line 79) and `memory-bank/progress.md` (line 108) relative to the current directory; the `.ps1` twin does the same. For a session whose working directory is a linked worktree, that is the branch's stale copy of memory-bank/, not the main worktree's. Measured 2026-09-21: the gate exited 0 from a fresh worktree only because origin/main's progress.md happened to carry that day's entry. On any later day a worktree session can satisfy it only by editing the worktree's memory-bank/ (which CLAUDE.md forbids, and which `.githooks/pre-commit` now refuses to commit) or by leaving a handoff.md in the worktree root.

Fix: resolve memory-bank/ from the main worktree -- `git rev-parse --git-dir` vs `--git-common-dir`, normalized with `cd && pwd -P` as in `.githooks/pre-commit`, not `realpath` (measured missing-realpath fail-open in mb.sh). Change ONLY the memory-bank/ paths, with no global `cd`. Do NOT move handoff.md to the main root: the gate exits 0 for any handoff.md dated today in its directory, whoever wrote it, so resolving it from the main root would hand every worktree session another session's bypass. Per-session handoff is a separate, unscoped problem (logged by the compact-nudge session, 2026-09-21).

Coordinated 2026-09-21 with the compact-nudge work: its redesign no longer touches pre-compact-check.{sh,ps1}, their templates/ copies, or tests/test-pre-compact-check.sh. Scope: both twins, both TEMPLATE_OWNED mirrors, tests/test-pre-compact-check.sh.
