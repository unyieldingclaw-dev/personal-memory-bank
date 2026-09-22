---
status: open
created: 2026-09-21
last-reviewed: 2026-09-21
staleness-threshold: 90d
related_plan: null
---

# PMB core.hooksPath is absolute and mb doctor misreports it

This repository's `.git/config` sets `core.hooksPath` to an absolute path to the main checkout's `.githooks`, not the relative `.githooks` that `mb init`/`mb upgrade` write. Origin unknown; present since at least 2026-08-17.

Effects, measured 2026-09-21:
- Every linked worktree runs the MAIN CHECKOUT's working-tree copy of each git hook, including any uncommitted edit there, whatever branch the worktree is on. A hook change goes live in PMB only when the branch checked out in the main checkout contains it. With the relative value, each worktree runs its own branch's copy instead (measured in a fixture).
- `mb doctor` check 4d prints "core.hooksPath not set to .githooks -- git hooks won't fire". That is false here: the hooks fire, from the main checkout.
- `mb upgrade` would silently reset it to the relative value (NS-17).

Decision pending with the user. Recommendation: switch back to the relative value after `fix/pre-commit-worktree-guard` merges, so PMB runs what adopters run; and make check 4d compare resolved paths so an absolute path to the same directory is not reported as disabled.
