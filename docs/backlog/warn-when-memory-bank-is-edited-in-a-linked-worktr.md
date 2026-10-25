---
status: open
created: 2026-09-21
last-reviewed: 2026-09-21
staleness-threshold: 90d
related_plan: null
---

# Warn when memory-bank is edited in a linked worktree

The rule is "never update OR commit memory-bank/ from a subworktree". `.githooks/pre-commit` (fix/pre-commit-worktree-guard) catches commits only, and not every commit path -- a clean merge, a clean cherry-pick or revert, `rebase --continue` and `am` never run pre-commit (known gaps in docs/HOOKS-GUIDE.md). Suggested by the 2026-09-21 opposition review of the plan for that change: an advisory Claude Code `PreToolUse` hook on Write|Edit that warns when the target is inside memory-bank/ and the session's directory is a linked worktree. Additive to the git hook, not a replacement. Note the same per-branch caveat as every Claude Code hook here: `.claude/settings.json` hook commands use relative `scripts/...` paths, so a worktree on an older branch runs that branch's hooks.
