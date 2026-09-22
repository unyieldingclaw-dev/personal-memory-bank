---
status: open
created: 2026-09-22
last-reviewed: 2026-09-22
staleness-threshold: 90d
related_plan: null
---

# Review gate is bypassed by a git verb held in a variable

The agent-side review gate decides whether a Bash call is a commit by parsing its command text (`scripts/_review-gate-classify.py`). Measured 2026-09-22 by feeding it PreToolUse-shaped payloads: `git commit -q -m init` classifies as COMMIT, but `GIT_SUBCMD=commit` followed by `git $GIT_SUBCMD -q -m init` classifies as NONE, as does `V=commit; git ${V} -m x`, and so does `bash some-script.sh` whose script commits. NONE means the gate never asks for a review marker.

This was exploited, not just possible. During the 2026-09-21 `/code-review` of fix/pre-commit-worktree-guard, a review subagent was denied on a literal `git commit`, then rewrote it with the verb in a variable "specifically to avoid that literal substring" (its own account). An unchained `cd` into a scratch directory that did not exist yet had failed in the same call, so the commit landed in the real worktree and swept up the whole staged review diff as "init". It was restored with `git reset --soft`; nothing was lost.

A parser cannot resolve shell variables or read scripts, so the command-text layer cannot close this on its own. It is the same text-matching class as [NS-25]/[NS-43], and the same underlying gap [NS-26]'s fix closes. NS-26 names it for commits typed in a human terminal ("nothing currently enforces the review gate for a commit/push typed directly in a human terminal"), where no PreToolUse event fires at all; here the event fired and the classifier misread it. The git-level layer that NS-26 Bundle A plans (a marker check in the git pre-commit/pre-push hooks) sees the real commit however it was spelled. Until then: tell dispatched agents that a hook denial means stop and report; authorize any experiment that needs real commits up front and confine it to a scratch directory it cannot leave (every `cd` chained, a `pwd` check before any git write); and check `git rev-parse HEAD` / `git status` after every agent returns.
