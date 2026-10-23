---
status: open
created: 2026-10-20
last-reviewed: 2026-10-20
staleness-threshold: 90d
related_plan: null
---

# Follow-ups from PR #59 (update-reviewed.sh) and PR #71 (OPP6-1 unstaged-changes gate)

Source: the "Follow-ups" / "Backlog candidates" sections of `gh pr view 59` and `gh pr view 71`.
None is fixed. The empty-stdin-after-pwsh item is already in
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
- Silent file loss on any rename failure: write the temp beside the target, or check the file still exists afterwards.
- Hook hardening: the memory-bank filter is a substring match (`memory-bank/../..` passes); `perl -i` gets no `--`.
- The `/code-review` and `/change-review` marker procedure is one chained command, which the worktree
  guard refuses inside an isolated worktree; it had to be run as separate steps.
- Gate root resolution: after EnterWorktree the commit gate looks for the marker in the hook's ambient
  cwd, not the session's worktree; the commit passed only with a leading `cd`.
- Six wording/test nits (comment overstates "every other shell hook"; CHANGELOG lacks the
  "not reproduced locally" caveat; Cygwin rationale written three times; tests call `cygpath -w`
  instead of `to_win_path`; stacked WHY comments; no POSIX test for the backslash-filename trade-off).
