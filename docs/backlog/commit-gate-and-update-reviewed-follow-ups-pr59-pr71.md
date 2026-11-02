---
status: open
created: 2026-10-20
last-reviewed: 2026-10-30
staleness-threshold: 90d
related_plan: null
---

# Follow-ups from PR #59 (update-reviewed.sh) and PR #71 (OPP6-1 unstaged-changes gate)

Source: the "Follow-ups" / "Backlog candidates" sections of `gh pr view 59` and `gh pr view 71`.
Items marked Done or Dropped below are resolved; the rest are open.
The empty-stdin-after-pwsh item is already in
`replace-the-gh-pr-merge-deny-with-a-forced-permiss.md` and is not repeated.

## From PR #71 (commit gate, `2c4088f`)
- `GIT_INDEX_FILE`/`GIT_DIR`/`GIT_WORK_TREE`/`GIT_OBJECT_DIRECTORY`/`GIT_COMMON_DIR` assigned before a
  commit should be unsupported context. Reproduced, pre-existing bypass.
- A chained edit-or-stage before the commit still passes. Pre-existing.
- The marker hash ignores content under an external diff driver, and `diff.ignoreSubmodules` hides
  staged gitlink bumps. The fix needs `--no-ext-diff --no-textconv --ignore-submodules=none` in the
  libs' hash and in the review commands' marker recipes, changed together.
- A dirty submodule refuses agent commits permanently (no fleet repo has `.gitmodules` today).
- `git add -p` has no agent route; the stash recipe works on whole files only.
- "Drop by current `stash@{n}`" races if another session pushes or pops between lookup and drop.
- `[NS-26]` Layer 2 must choose between replicating the index==worktree check and re-hashing the
  staged content (re-hashing also closes the path, `--amend` and `--patch` gaps). See also `[NS-43]`.
- `tests/mutate.py` labels a missing anchor "STILL GREEN" and covers only the sh hook; ps1 rows skip
  silently without pwsh.
- Pin rows for the documented not-covered forms (`--amend`, path-named commits) so refusals cannot flip silently.
- `mb.sh`/`mb.ps1` still print a "Next: git add -A" then commit hint that the gate now refuses.

## From PR #59 (update-reviewed.sh, `5c6f8e4`)
- **Done** (branch `fix/update-reviewed-hardening`): silent file loss is now detected rather than
  prevented. `update-reviewed.sh` logs to `.pmb-hook-errors.log` when the file is missing after the
  edit, when perl fails, and on empty stdin. Writing the temp beside the target and `mv`-ing it was
  tried as a design and dropped: probes on Windows measured four regressions against `perl -i`
  (a temp file left in `memory-bank/` when perl or `mv` fails, the read-only bit dropped, `mv -f`
  onto a directory reporting success, and `TMP` clobbering Git Bash's exported temp dir).
- **Done:** `perl -i` and `grep` get `--`.
- **Dropped:** rejecting `..` in the memory-bank filter. The hook only stamps a file the agent has
  just written, only rewrites its `last-reviewed:` line, and a symlink inside `memory-bank/` would
  bypass the check anyway.
- **Open, new:** the substring filter also stamps `templates/memory-bank/` and
  `examples/*/memory-bank/` files in this repo. Whether that is wanted is undecided.
- **Done, found while fixing:** both twins dropped the `\r` from the stamped line of a CRLF file.
- The `/code-review` and `/change-review` marker procedure is one chained command, which the worktree
  guard refuses inside an isolated worktree; it had to be run as separate steps. Planned as its own
  PR together with the `--no-ext-diff` hash item above, which changes the same recipe lines.
- Gate root resolution: after EnterWorktree the commit gate looks for the marker in the hook's ambient
  cwd, not the session's worktree; the commit passed only with a leading `cd`. Planned as its own PR:
  first measure whether the hook payload's `cwd` follows EnterWorktree.
- **Done:** the six wording/test nits. The comment now says "the other stdin-reading hooks"; the
  stacked WHY comments are merged; the Cygwin rationale and its "not reproduced locally" caveat live
  once, in the hook, and the test points there (the released 1.3.0 entry in
  `docs/archive/changelog-1.3.0.md` is left as history); tests use `to_win_path`; a
  Linux/macOS-only test pins the backslash-filename trade-off.
