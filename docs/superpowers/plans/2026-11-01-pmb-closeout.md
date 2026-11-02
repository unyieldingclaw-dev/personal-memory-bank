# PMB Close-out Implementation Plan (rev 4)

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Stop PMB generating derived work. Then clear the existing queue of PRs, sessions and local worktrees under the new rules.

**Architecture:** One main-checkout PR (Task 2) implements the design spec. That means the derived-work rules, the enforcement severity floor, the change to recovery-only compaction, and the one-time memory-bank reconciliation. The freeze lifts when that PR merges. After that come the PR clear-out, the session cleanup and the local cleanup. The coordinating session is the "PR merge queue" session.

**Tech Stack:** git, gh, the app's session tools, PMB review gates.

**Spec:** `docs/superpowers/specs/2026-11-01-derived-work-rules-and-compaction-recovery-design.md`. It holds every exact text and the evidence, and Task 2 implements it verbatim. The user accepted rules R1–R3 and decisions D1′–D4′ on 2026-11-01. The evidence comes from 4 rounds of adversarial review, recorded in this session's transcript.

## Global Constraints

- **Freeze:** from 2026-11-01 until the Task 2 merge, there are no new sessions, no task cards and no PRs beyond those named here.
- **Memory-bank edits** happen only from the main checkout, on a fresh branch off `origin/main` (`.githooks/pre-commit:9-19`).
  - The main checkout is currently on `docs/memory-bank-ns58-pr87` (3 unpushed commits). Its session has stopped and saved a patch.
  - Before switching branches, confirm through `list_sessions` that no running session has the main checkout as its cwd. Then confirm the switch with the user.
- **Caps** for `activeContext.md`: 150 lines and 45,000 B.
- **Ratchet:** `cat CLAUDE.md memory-bank/*.md | wc -c` must not exceed origin/main's value, measured with the same command at run time. It was 86,865 on 8ac026f.
- **`CODE-REVIEW.md`** must stay byte-identical to its `templates/` twin. `MEMORY-BANK.md` must stay divergent from its twin.
- **Reviews:** every commit and push passes /code-review and /change-review, and neither is ever bypassed. Under the spec, Task 2's own findings take dispositions, with the severity floor applied. Review it on Opus.
- **Merges and force-push:** the user merges. Force-push is BLOCK tier.
- **Untouchable:** `refs/stash` (7 stashes) and every path matching `/.codex/` case-insensitively. Don't use `cp -a` on a worktree.
- **Archiving deletes worktrees later**, even ones a live session shares (memory `feedback_archive_deletes_worktrees`). Back up before you archive.
- **Backups** go to `C:/Users/Mizzo/Claude/PMB-worktree-backups/<date>/`. Copy with:
  ```bash
  tar --force-local -C "<wt>" --null -T - -cf out.tar
  ```
  Verify each copy by checking the exit code and comparing `tar -tf` against the file list.
- **Contract:** Task 2 needs a task contract. If the classifier denies the write, ask the user to write the contract, or proceed with the denial noted. Never write it through another tool.

## Decisions you'll be asked for (grouped)

1. Approve this plan and the spec (this covers the contract).
2. The main checkout: OK to switch it off `docs/memory-bank-ns58-pr87`. That branch's NS content goes into Task 2 and the branch is kept unpushed.
3. #118's follow-ups (c8204c7, local): ship as one PR, or not. That PR needs a conflict resolution against #125.
4. The tag-push patch: ship it or move it to the backlog.
5. The "Close the typographic-quote gate bypass" work: under the severity floor a bypass is High, so ship it if it is one.
6. The PR clear-out table, approved as a block. #9 needs CONFIRM, and #98's merge needs an abort OK.
7. Whether Codex is still used here, which decides #48.
8. Whether to keep #95.
9. Session groups A, B and C.
10. The worktree removal list, and the branch deletion list.
11. Merging each PR: Task 2, plus 1b or 1c if you approve them.
12. **[NS-59]: the trial's fate is due before 2026-11-16.** The trial's `.pmb-pre-approval.log` in the `pre-approval-protocol` worktree was likely lost to the archive cleanup, so decide with what remains.

## Review Focus

1. **The severity floor being read narrowly to dodge fixes.** The spec's text says "worst reachable outcome", and a defect counts as reachable unless shown otherwise.
2. **The SessionStart hook not reaching the model.** This is the spec's one unverified assumption. It is measured before merge (spec, Verification 2).
3. **Old-rule text surviving.** The spec's residual grep must be clean.
4. **Cleanup loss.** This covers ignored files, a paused rebase (`rebase-merge/` with no `REBASE_HEAD`), commits of a conflicted rebase that only a branch ref holds, and squash-merged branches.
5. **Gamed metrics.** Task 6 measures after the freeze lifts.

---

### Task 0: done (2026-11-01)

- [x] Sent freeze messages to 7 sessions.
- [x] Archived 33 sessions. Delayed cleanup afterwards removed 7 worktrees of archived sessions. Two of those held unsaved files: `pre-approval-protocol` (1 untracked file plus its ignored files) and `memory-bank-freshness-hook` (1 modified file, and its branch is gone).
- [x] Backed up every remaining worktree (39 with files, verified), plus diffs, head SHAs and 11 HEAD-only bundles, to `C:/Users/Mizzo/Claude/PMB-worktree-backups/2026-11-01/` (11 MB).
- [x] #125 merged as 8ac026f, and #123 is closed.
- [x] Memory notes updated: `feedback_review_foldin_rounds`, `project_pmb_closeout_2026_11`, `feedback_archive_deletes_worktrees`.

### Task 1: in-flight work (each item needs the user's decision)

- [ ] **1b. #118's follow-ups** (local c8204c7 on `fix/hook-wiring-followups`). If you approve it, resolve the `templates/docs/HOOKS-GUIDE.md` conflict with #125, run /code-review, push and open the PR. Its 21 non-blocking findings and owed items (a)–(j) take the spec's dispositions, in that PR's body.
- [ ] **1c. The tag-push patch:** backlog it, unless its STATE.md names a High under the severity floor.
- [ ] **1d. Held-session work that the severity floor makes High** (decision 5). Ship it as a single PR. Everything else held goes to the backlog.

### Task 2: the spec PR (main checkout)

- [ ] **Step 1:** check the main checkout is safe to switch (decision 2), then run:
  ```bash
  git -C "C:/Users/Mizzo/Claude/Personal-Memory-Bank" fetch origin
  ```
  ```bash
  git -C "C:/Users/Mizzo/Claude/Personal-Memory-Bank" switch -c docs/derived-work-rules origin/main
  ```
- [ ] **Step 2:** write the task contract.
- [ ] **Step 3:** apply every "Exact texts" section of the spec, verbatim.
- [ ] **Step 4: reconciliation in `activeContext.md`.** Make NS state changes only. Each line holds state, not PR numbers.
  - [NS-67](b) narrows to PreCompact. Under D1′, PreCompact's legacy path no longer blocks.
  - [NS-34] closes.
  - [NS-69], [NS-38] and [NS-59] get current state.
  - [NS-14] stops calling the ACR tag signal due.
  - Fold in the NS content of the saved NS-58 patch.
  - Close every item whose work is merged, and log the closures in Trim History.
- [ ] **Step 5:** seed `docs/backlog/review-findings.md` with one line per item, each citing its PR:
  - #116: perl exit-0, the macOS CI job, PR B and PR C
  - #118: items 5, 8, 9 and (a)–(j), unless they ship in 1b
  - #125's list
  - #117's list
  - #98's 5 items
  - the tag-push patch
  - #6: the stale node20 comment and env var
  - the `mb.sh`/`mb.ps1` CODE-REVIEW class gap
  - the lost `memory-bank-freshness-hook` file
- [ ] **Step 6:** measure spec Verification 2 (does SessionStart reach the model in Claude Code). Record the result in the PR body, and apply the spec's fallback if it fails.
- [ ] **Step 7:** run spec Verifications 1, 3, 4 and 5. Run the tests individually, then run `tests/run.sh` in the background with its output going to a file, and with TMPDIR set to a `/c/...` path rather than `C:/...` (the colon in `C:` splits PATH).
- [ ] **Step 8:** /code-review (Opus), then commit, then /change-review, then push and open the PR. The user merges. **The freeze lifts on merge.**
- [ ] **Step 9:** in my auto-memory, rewrite every "owed: … record / follow-up PR" line in MEMORY.md and its notes. Each becomes either "in review-findings.md" or the real open state. That includes the `feedback_limit_session_spawning` line about PR-body lists.

### Task 4: PR clear-out (after Task 2 merges)

| PR | Action | Check right before acting |
|---|---|---|
| #9 actions/checkout 7.0.1 | Merge (CONFIRM) | No `pull_request_target` (verified). Click "Update branch", wait for green CI, then merge. |
| #6 gitleaks-action 3.0.0 | Merge after #9 | Comment `@dependabot rebase`, then wait for green CI. |
| #11 | Close as superseded | Run `tests/test-review-reminders.sh` on main first, and confirm the false-positive case passes. |
| #10 | Close as superseded | Its worktree is already backed up. |
| #98 | Close | Its items go to the backlog in Task 2. In `funny-cartwright-a826ca`, its `git diff HEAD` is already backed up. Run `git merge --abort` only with the user's OK. |
| #83 | Close, keep the branch | none |
| #48 | Close only if Codex is no longer used here | Ask about `.agents/skills/` before touching it. |
| #95 | Your call | It is one doc file. |

### Task 5: sessions (after Task 4)

- [ ] Group A: sessions with unsaved work. Group B: cascade-blocked parents. Group C: old main-checkout sessions with no PR.
- [ ] For each session: re-run the backup from Global Constraints, then confirm no live session shares its cwd, then archive it. Groups go in order A, B, C, each archived unless the user objects.

### Task 7: local worktree and branch cleanup (last)

- [ ] **Step 1:** refresh the remote refs, then re-run the verified backup for every candidate:
  ```bash
  git -C "C:/Users/Mizzo/Claude/Personal-Memory-Bank" fetch --prune origin
  ```
  **The backup also stores every local branch ref and its SHA** (`git for-each-ref refs/heads`). That protects commits of a conflicted rebase that only a branch ref holds.
- [ ] **Step 2: removable worktrees.** A worktree is removable only when all of these hold:
  - its path doesn't match `/.codex/`
  - no running session uses it
  - its PR is MERGED or CLOSED, or it has no branch
  - its git dir has none of `MERGE_HEAD`, `REBASE_HEAD`, `CHERRY_PICK_HEAD`, `REVERT_HEAD`, `BISECT_LOG`, `rebase-merge/`, `rebase-apply/` or `sequencer/`
  - its backup is verified

  The user approves the list. Then, for each worktree on it:
  ```bash
  git -C "C:/Users/Mizzo/Claude/Personal-Memory-Bank" worktree remove "<path>"
  ```
  Never pass `--force`. A refusal means the worktree isn't ready. When the list is done:
  ```bash
  git -C "C:/Users/Mizzo/Claude/Personal-Memory-Bank" worktree prune -v
  ```
- [ ] **Step 3: branches. This repo squash-merges, so the test is the PR's head, not `--not --remotes`.** A branch qualifies when:
  - its PR is MERGED or CLOSED
  - no worktree has it checked out
  - the local tip is an ancestor of the PR's head on GitHub. To check, fetch `refs/pull/<n>/head` into `refs/pmb-check/<n>` and run `git merge-base --is-ancestor <tip> refs/pmb-check/<n>`.

  The list and its SHAs go to the backup folder, and the user approves them. Then delete each branch with `git branch -D`, and delete `refs/pmb-check/*` afterwards.
- [ ] **Step 4: worktrees with a stuck operation or unsaved work.** These are Group A's worktrees, plus `fix-update-reviewed-path` (a stuck rebase) and `funny-cartwright-a826ca` (a merge in progress). The user decides on them as one batch.
- [ ] **Step 5: verify.** `worktree list` should show only the main checkout, the Codex worktrees, the worktrees of open PRs and the ones the user kept. `stash list | wc -l` should still be 7.

### Task 6: done check (2 weeks after the freeze lifts)

For the 2 weeks after Task 2 merges, measure:
- the derived-PR share, classified the same way as the deep dive did. The baseline is 69%.
- PRs opened per merged PR
- NS items opened minus closed. The goal is ≤ 0.
- the number of lines in `review-findings.md`. The goal is no more than at merge.
- 5 randomly sampled Drops, each checked as justified

If derived PRs or per-PR records keep appearing, the advisory text isn't holding. There's no hook point for sessions, so that part depends on your practice. For PRs, the next step could be a commit-gate check on PR bodies.
