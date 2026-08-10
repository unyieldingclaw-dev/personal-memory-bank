# Memory Bank Freshness Hook

**Date:** 2026-08-10
**Status:** Approved

## Problem

`CLAUDE.md` states: "After completing any significant task or multi-file change, update the relevant
memory-bank files before continuing to new work." This instruction lives entirely in the advisory
layer — nothing structurally checks whether it happened. During a single multi-hour session in
`ai-code-review-agent` (a PMB-managed repo, `.pmb-version: 1.1.1` at time of writing, several versions
behind current), six distinct significant units of work landed — three bug fixes, a PR merge, an npm
publish, a CI security fix, a full-codebase audit, and a batch of audit-fix commits — without a single
`memory-bank/` write in between, until the user directly asked whether it had been done.

This repo's own `standards/` already distinguish enforcement layers by how deterministic they are:
`CLAUDE.md` text (advisory, can drift under session momentum) → hooks (fire on every tool call,
cannot be talked around) → reviewer/opponent review (semantic) → CI (deterministic gate). The
memory-bank-update instruction sits only in the first layer. The commit-review gate
(`review-reminders.sh`/`.ps1`) is hook-enforced and was never bypassed across the sessions documented
in `memory-bank/progress.md`; the memory-bank-update instruction has no equivalent and was bypassed
repeatedly in the incident above.

The gap is structural, not incidental: "read memory-bank at session start" is a single, front-loaded
action gated by session start itself, so it happens reliably. "Write memory-bank after significant
work" is a recurring obligation with no forcing function — it must be re-remembered after every
qualifying event, for the life of a session, and a long chain of "keep going" is precisely the
condition most likely to crowd it out.

## Design

### Scope decision

`AI-Code-Review-Agent`'s `.pmb-version` file and its `scripts/review-reminders.ps1`,
`check-contract.ps1`, `dangerous-commands.ps1`, and `update-reviewed.ps1` (all `TEMPLATE_OWNED`)
confirm it is PMB-managed, just stale. A fix scoped to `personal-memory-bank` alone would never have
reached the repo where the incident actually happened. This hook is therefore built as
`TEMPLATE_OWNED`, shipped via `mb upgrade`, following the exact registration footprint
`review-reminders` already established — not a `personal-memory-bank`-local addition.

### Mechanism

New hook pair: `scripts/memory-bank-freshness.sh` / `.ps1` (+ `templates/scripts/` mirrors). `PreToolUse`,
matcher `"Bash"`, added as a third command alongside `dangerous-commands` and `review-reminders` in
that matcher's array. Fires only when `$cmd -match 'git\s+commit\b'` (same regex convention as
`review-reminders.ps1`).

Dot-sources `_review-gate-lib.sh`/`.ps1` and reuses `resolve_cd_root()`/`Resolve-CdRoot` — the same
ambient-cwd correction `review-reminders.ps1` already needed for dispatched-subagent sessions — rather
than re-deriving root independently. Once resolved, anchors with `cd "$root"` / `Set-Location $root`
before any git call, matching `review-reminders.ps1`'s existing pattern.

**Skip conditions** (fail open, exit 0, no output), checked in order:

1. Malformed/empty stdin JSON (standard for every hook in this repo)
2. Running inside a git worktree — detected via `git rev-parse --git-dir` vs `--git-common-dir`
   (these differ inside a linked worktree, match in the main checkout; confirmed live against this
   repo's own `.claude/worktrees/*` checkouts). This repo's dominant workflow
   (`subagent-driven-development` on worktree branches) deliberately never touches `memory-bank/` from
   inside a worktree — see `activeContext.md`'s own "Never update or commit memory-bank/ from a
   subworktree" rule. Enforcing the streak inside worktrees would misfire on nearly every commit this
   repo itself makes. The actual incident this hook targets was direct main-branch work, not an
   isolated worktree feature branch, so this exemption does not weaken the fix.
3. No `memory-bank/` directory at the resolved root — harmless no-op outside a PMB-init'd repo.
4. `PMB_MB_FRESHNESS_DISABLE=1` set — explicit opt-out, mirroring the opt-in/opt-out convention
   `PMB_CONTRACT_HARD_BLOCK` already establishes in `check-contract.ps1`/`.sh`.

**Current-commit exemption:** before applying any streak logic, check whether the commit about to
happen already includes a `memory-bank/` path via `git diff HEAD --name-only` — not
`git diff --cached --name-only`. `git diff HEAD` (the same call `Get-CommitDiffHash` in
`_review-gate-lib.ps1` already uses) captures both staged and unstaged tracked changes, so it
correctly handles `git commit -am "..."` picking up an unstaged `memory-bank/` edit at commit time.
`--cached` alone would miss that case and could wrongly warn/block a commit that is itself the
memory-bank update. If `memory-bank/` appears, skip entirely — no output, no streak check.

**Streak detection:** walk `git log --name-only --format=%H` backward from HEAD, counting consecutive
recent commits with no path under `memory-bank/`, stopping at the first one that has one (or at a
hard cap of 20 commits, to bound the walk on long histories — a history that never touches
`memory-bank/` within the cap is treated as already at the cap, which exceeds the block threshold).

- streak == 0 → silent
- streak == 1 or 2 → warn (prints, allows)
- streak >= 3 → deny, unless the current-commit exemption above already applied

### Messages

Warn (`Write-Host`/`echo`, exit 0 — matches `docs/HOOKS-GUIDE.md`'s documented WARN convention:
"surfaces the access as advisory text and lets the command proceed"):

```
⚠️  MEMORY BANK: {streak} commit(s) in a row haven't touched memory-bank/. If this was significant work, update activeContext.md/progress.md before continuing.
```

Deny (`hookSpecificOutput.permissionDecision = "deny"`, same mechanism as `review-reminders.ps1`'s
`Deny` function):

```
MEMORY BANK STALE: {streak} consecutive commits with no memory-bank/ update. Stage a memory-bank/ change (activeContext.md and/or progress.md) as part of this commit, or make a memory-bank-only commit first, then retry. (If you just merged a branch, this is expected -- write the merge summary now.)
```

The parenthetical exists because of a real interaction with this repo's own merge pattern, described
next.

### Interaction with fast-forward merges (a deliberate, not accidental, sharp edge)

A fast-forward merge of a worktree branch creates no new commit, so this hook never fires at merge
time. Whatever streak already exists on the merged-in commits (all legitimately exempt while they
were made inside the worktree) carries forward once those commits are part of main's history. This
repo's own documented habit is to commit a `[NS-N]`-style memory-bank summary immediately after
merging — when that happens, the streak reads 0 again right away, and the hook is invisible in
practice.

If that habit is skipped even once, the next commit made directly on main — even something small and
unrelated — inherits the full pre-merge streak (e.g. 13, from a 13-commit worktree branch) and jumps
straight to a hard block, with no graduated warn-1/warn-2 ramp first. This is intentional: the
entire purpose of this hook is to stop exactly the "real work landed, memory-bank wasn't updated, and
more work piled on top" pattern, and a graduated ramp would blunt the check at the moment — right
after a large merge — where it matters most. The deny message's parenthetical exists so this reads as
expected behavior rather than a confusing overreaction to an innocuous-looking commit.

### Enforcement level rationale

Pure warn-only was considered and rejected: the incident happened because an advisory instruction got
crowded out by session momentum, and a warning that never blocks is only incrementally more forcing
than that — guaranteed to fire, but not guaranteed to change behavior under the same momentum.

Pure block-from-commit-one was also rejected: unlike the commit-review gate (a binary, exact signal —
a marker's hash either matches the diff or it doesn't), "was this commit significant enough to need a
memory-bank update" has no crisp signal. Any mechanical proxy will misfire in both directions, and a
hook that hard-blocks on a fuzzy heuristic risks training users toward hollow "touch the file so the
hook shuts up" writes, or toward `--no-verify`-style bypasses — defeating the actual goal of capturing
real understanding, not clearing a checkbox.

The hybrid (warn every stale commit, block after 3 consecutive) keeps isolated small commits
friction-free while still producing a hard stop for sustained neglect — the exact shape of the
incident that motivated this design.

### Why `git commit` only (not also `git push` / `gh pr merge`)

`git push` does not add commits to `git log` beyond what commit-time already saw — checking again at
push time would evaluate the identical lookback window, adding a second code path with no new
information. `gh pr merge` already receives an unconditional deny for the agent in
`review-reminders.ps1` ("this agent never merges pull requests, even with explicit instruction") — that
path is closed before this hook could matter, and when a user runs `gh pr merge` from their own
terminal, no hook sees it at all (hooks only see commands the agent runs), the same blind spot as for
git. `npm publish` is a different command family with no git-log signal to check against; it is
explicitly out of scope for this design (see below) rather than silently assumed covered.

### Streak weighting

Every commit counts equally toward the streak, regardless of diff size. A size-weighted variant
(skipping commits under some line/file threshold) was considered and rejected: it adds a threshold to
tune and another place the heuristic can misjudge, for a failure mode (a run of many tiny trivial
commits burning down the streak slightly early) whose fix is one line — touch `memory-bank/`, even
briefly — versus the cost of getting the weighting wrong in either direction.

## Out of Scope

- `npm publish` (or any other non-git "significant action") — no git-log signal exists to check
  against. If this becomes a real recurring gap, it needs a separate design matching specific Bash
  command patterns, not an extension of this git-log-based mechanism.
- A persistent state file (e.g. a streak counter in `.claude/`) — considered and rejected in favor of
  the stateless git-log walk. `concurrent-session-claims`' own build (2026-08-08, same repo) needed
  several bug-fix rounds for exactly this class of problem in a comparable state file (timezone
  coercion, array-unwrap, empty-file validity) — a stateless design has no equivalent corruption
  surface to get wrong.
- Excluding worktree-originated commits from the streak once they've landed on main via fast-forward
  merge — considered (see "Interaction with fast-forward merges" above) and rejected as unnecessary
  complexity; the immediate-block-on-first-post-merge-commit behavior is treated as intended, not a
  defect to work around.
- A new `mb doctor` presence-check script (the `check-review-gate-lib-presence.sh` pattern) — that
  pattern exists specifically for dot-sourced files invisible to the generic `settings.json`-derived
  check. This hook is directly referenced in `settings.json` like `review-reminders.ps1` itself, so
  correct `TEMPLATE_OWNED` registration (see Files Changed) is sufficient.

## Testing

New `tests/test-memory-bank-freshness.sh`, registered in `tests/run.sh`, following the existing
scratch-repo-plus-synthetic-stdin convention (`test-review-reminders.sh`'s pattern):

1. Streak 0 (last commit touched `memory-bank/`) → silent allow
2. Streak 1–2 → warn text printed, still allows
3. Streak >=3, current commit's `git diff HEAD` doesn't touch `memory-bank/` → deny
4. Streak >=3, but current commit's `git diff HEAD` does touch `memory-bank/` (including via a
   simulated `-am`-style unstaged-but-tracked change) → silent allow
5. Inside a real `git worktree add` checkout → always skip, regardless of streak
6. No `memory-bank/` directory present → skip
7. Malformed/empty stdin → fail open
8. `PMB_MB_FRESHNESS_DISABLE=1` set → skip regardless of streak
9. Bash/PowerShell parity on identical repo state (skip-guarded if `pwsh` is absent)
10. History longer than the lookback cap, never touching `memory-bank/` → still denies (count clamps
    at the cap, cap >= threshold)

Per the precedent in `docs/superpowers/specs/2026-07-22-review-hook-worktree-root-fix-design.md`: any
test scenario needs the literal text "git commit" to exist somewhere to simulate the gated command.
That text must live inside a test script file (written via a file-writing tool), never directly in a
live Bash tool call made while building/verifying this hook — otherwise the verification work
collides with the very gate it's testing.

## Files Changed

| File | Change |
|---|---|
| `scripts/memory-bank-freshness.sh` | New hook |
| `scripts/memory-bank-freshness.ps1` | New hook |
| `templates/scripts/memory-bank-freshness.sh` / `.ps1` | Byte-identical mirrors |
| `.claude/settings.json` | New `PreToolUse` → `"Bash"` matcher entry |
| `templates/.claude/settings.json` | Same addition, mirrored |
| `scripts/mb.sh` | Add both filenames to the `mb init` copy-loop list and the `TEMPLATE_OWNED` array |
| `scripts/mb.ps1` | Add both filenames to `Invoke-Init`'s copy list, the upgrade-analysis enumeration, and its `TEMPLATE_OWNED`-equivalent array |
| `docs/HOOKS-GUIDE.md` | New section documenting the hook |
| `templates/docs/HOOKS-GUIDE.md` | Trimmed mirror, per existing SYNC NOTE convention |
| `tests/test-memory-bank-freshness.sh` | New test suite |
| `tests/run.sh` | Register the new suite |
