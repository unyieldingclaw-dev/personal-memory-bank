# Merge-aware review gates, branch freshness, and single-insertion-point files — design

**Status:** design only. No hook, workflow, test or repository setting is changed by this document.
**Date:** 2026-10-23. **Branch:** `docs/review-budget-spec`, based on `origin/main` 0ee9a3c.
**Trigger:** CLAUDE.md Token Budget lists "enforcement or security-boundary changes" as a trigger for
Opus and a written spec before code. Item 1 below changes what the commit and push gates accept.

## 1. Problem, with the evidence

PR #78 (`fix/review-gate-classify-ordinal`) carried no new code after its first approval. Auto-fix
still had to merge `main` into it twice, as 4e62cff (2026-10-20) and f1cbabd (2026-10-23), to clear
conflicts. Each merge then needed a full `/code-review` (six Sonnet domains plus Opus opposition)
and a `/change-review` before the push. The second round cost about 985k tokens across 6 domain
agents and 2 Opus oppositions, by the agents' own usage reports as relayed by the originating
session. Its `/code-review` payload (`merge2-review.patch`) was 289 KB and 40 files, almost all of
it main's already-reviewed PRs #58, #80, #81, #84 and #85. No finding in either round was
blocking. All were Info or Low except m2-maintainability F1 (Medium): CHANGELOG has 12 lines of
headroom left. Sources: `m-*.md`, `m2-*.md` and `crm2-jobs1-8.md` in the `ordinal-classify/`
notes folder. After all that, `gh pr merge` was refused. Branch protection's
`strict: true` required the branch to be up to date again, because `main` had meanwhile gained
#79, #86 and #87.

Both conflicts came from files that every PR appends to at one spot:
- `CHANGELOG.md`: both sides add entries at the top of `[Unreleased]`.
- `tests/run.sh`: two PRs each appended one `run_suite` line after the same line.

`CHANGELOG.md` on `main` is now exactly **800 lines** (`wc -l`, 0ee9a3c), the File Size job's
hard cap. Any PR that adds a changelog line fails CI until something is moved out.

When this was written there were 14 open PRs: 9 `BEHIND`, 4 `DIRTY`, and #78 `BLOCKED`
(`gh pr list`, 2026-10-23). Two of #78's three syncs were forced by conflicts, not by
up-to-dateness. The first conflicted in `CHANGELOG.md`; the second in `tests/run.sh` and, through
the line cap, `CHANGELOG.md`.

## 2. Measured facts this design rests on

All were measured with git 2.55.0.windows.3 in throwaway repositories. Every git call was pinned
with `-C` to the probe repository. The scripts and their outputs are in the side-session notes
folder `review-budget-spec/`: `probe.sh` with `probe.out` and `probe-longpath.out`, and `probe2.sh`
with `probe2.out`, and `probe3.out` (F3, an inline command, recorded with its output). They are
outside the repository, so re-derive them from this table if that
folder is gone. Re-measure anything you rely on.

| # | Fact | Consequence |
|---|---|---|
| F1 | During `git merge --no-commit` of a clean merge, `git write-tree` of the index equals the first line of `git merge-tree --write-tree HEAD MERGE_HEAD` (both `a176c78…`). | "Staged tree equals trial tree" is a usable, exact test for "no manual resolution". |
| F2 | For a conflicted merge, `git diff <trial-tree> <staged-tree>` before the commit shows the resolution: conflict markers removed, the chosen text added. It is the same hunk content `git show --remerge-diff` shows after the commit, but **not byte-identical**. Marker labels differ (`<<<<<<< pr` against `<<<<<<< 131e0dc (sync clean)`), and remerge-diff adds a `remerge CONFLICT` line. | Hook and command must hash the output of **one** computation. remerge-diff cannot stand in for the pre-commit diff. |
| F3 | merge-tree's conflict-marker labels are the **argument spelling**. Passing full OIDs gives OID labels, and passing `lblA` gives `lblA`. `-c merge.conflictStyle=diff3` changes the markers. | Always pass full 40-hex OIDs, and pin `merge.conflictStyle`. |
| F4 | `git show --remerge-diff` failed with "Filename too long" and then **segfaulted** when the repository path was ~170 characters, because its temporary object directory pushed paths to 268 characters. merge-tree in the same repository worked. | Do not build a gate on remerge-diff on Windows. merge-tree plus diff is the primitive. |
| F5 | `git diff --cc` of an "evil" clean merge showed the injected hunk only because the result differed from **both** parents. Git documents that `--cc` hides hunks where the result takes one parent's version unchanged. | `--cc` hides exactly the dangerous resolution: silently keeping our side and dropping main's fix. Not usable as a scope. |
| F6 | A hand-written `.git/MERGE_HEAD` resolves, and with no real merge done the staged tree differs from the trial tree. Not measured: whether the next `git commit` records it as a parent. | Trusting MERGE_HEAD is unsafe. Comparing content against it is safe (§3.6). |
| F7 | `* merge=union` in `.git/info/attributes`, which is untracked and needs no config, turned a conflicting merge into a **clean** merge-tree (rc 0) with both sides concatenated. `git --attr-source=<empty tree>` did **not** neutralize it. | Untracked attributes can redefine "automatic". |
| F8 | `merge.evil.driver = printf 'INJECTED\n' > %A` in `.git/config`, with `* merge=evil` in info/attributes, made merge-tree report a clean merge whose content was `INJECTED`, and it **ran the driver command**. `-c merge.evil.driver=` is not a clean neutralizer (spawn error, then fallback). | The pass must refuse **before** running merge-tree whenever any merge driver or `merge` attribute is in effect. |
| F9 | `git diff main...pr` hashed the same before and after a clean sync in which main touched only a different file. | The push gate's hash changes only when main touched files, or context lines, that the PR also touches. `CHANGELOG.md` is the usual case. |
| F10 | `_review-gate-classify.py` (`_verdict_from`) returns COMMIT or PUSH only for the `commit` and `push` verbs. The opposition review measured `git merge --continue` classifying as NONE. The desktop app's `sync_with_base_branch` merges on the host, outside every hook. HOOKS-GUIDE's "Known gaps" list is about git's own `pre-commit` hook, not this gate. | **Clean syncs never reach the commit gate today.** Their cost lands on the push gate. The commit gate pays only when a merge is finished with `git commit`. |

F10 means a clean sync costs only a push-gate review. Classes of PR #78's three syncs, measured with
`merge-tree --write-tree` and `comm -12` over `diff --name-only --no-renames` from the merge base to
each parent (round-2 opposition):

| Merge | Conflicted paths | Overlap set | Class |
|---|---|---|---|
| 4e62cff | `CHANGELOG.md` | `CHANGELOG.md` | S2 |
| f1cbabd | `tests/run.sh` | `CHANGELOG.md`, `tests/run.sh` | S2 (plus a hand-edit for the line cap) |
| 7e839fd | none | empty | S0 (assumes the §3.2 merge-config precondition held, which was not measured) |

So the expensive rounds were the S2 path (§3.2). Which gate costs more in general
is a measurement for §6 step 4, not a conclusion of this document.

## 3. Change 1 — merge-aware review gates

### 3.1 Why a sync is expensive today

- **Commit gate** (`review-reminders.sh:275`, `.ps1` twin): during a merge, `diff_hash HEAD` is
  main's entire delta since the merge base, plus the resolution. A sync of N main PRs re-reviews N
  PRs.
- **Push gate** (`:313`): hashes `git diff origin/main...HEAD`.
  - That diff runs from merge-base(origin/main, HEAD) to HEAD. After a sync that merge base is
    the new main tip, so the diff is the PR's own net change, re-expressed against the new main.
  - If main touched none of the PR's files, the hash is unchanged (F9). The marker is still
    single-use and was consumed by the previous push, so an **identical** diff needs a fresh
    `/change-review` anyway.
  - If main did touch the PR's files, the hash changes, and the PR's whole net diff is reviewed
    again.

### 3.2 Definitions

- **Base ref:** `refs/remotes/origin/main`, fully qualified. A local branch named `origin/main`
  shadows the short spelling (memory: Git/Windows facts). Adopters may need this configurable;
  OQ-7 defers that (§7).
- **Sync merge:** a two-parent merge M = merge(P1, P2) where P2 equals, or is an ancestor of, the
  base ref, and there is exactly one merge base. An octopus merge, a criss-cross with several
  merge bases, or any other P2 is **not** a sync. It takes today's full path.
- **Trial tree** T = first line of
  `git -c merge.conflictStyle=merge merge-tree --write-tree <P1-oid> <P2-oid>`, with full OIDs
  (F3). Its exit code says clean (0) or conflicted (1).
- **Resolution diff** = `git diff --no-ext-diff --no-textconv --no-color <T> <recorded-tree>`, where
  the recorded tree is the staged tree before the commit, or `M^{tree}` after it.
- **Overlap set** = paths changed in both mb..P1 and mb..P2, where mb is the merge base. Computed
  with `git diff --name-only --no-renames`, both sides. Rename detection (`diff.renames`, on by
  default) would let a main-side rename plus a PR-side edit yield an empty overlap, even though
  merge-tree content-merges the edit into the renamed file.
- **Merge-config precondition.** All of the following must hold, or there is no pass of any kind:
  - **No unknown merge config.** `git config --get-regexp '^merge\.'` returns no key outside an
    allowlist. The allowlist is fixed in the helper; its starting proposal is `merge.ff`,
    `merge.log` and `merge.conflictStyle`. This covers drivers (`merge.<x>.driver`),
    `merge.default`, which names a driver for paths whose `merge` attribute is unspecified (git
    2.55 gitattributes docs), and `merge.renormalize`.
  - **Pinned flags on merge-tree:** `-c merge.default=text -c merge.renormalize=false
    -c merge.conflictStyle=merge`.
  - **No `merge` attribute in effect.** `git check-attr merge` reports `unspecified` for every
    path in mb..P1 ∪ mb..P2.
  - **No `filter` attribute in effect** on any path in the overlap set.

  These checks run **before** merge-tree, which executes drivers (F7, F8). A `merge` attribute
  committed in `.gitattributes` is reviewed content, but it still disables the pass. That is
  simpler than telling attribute sources apart, and it fails in the safe direction (§5.1 d).
  `merge.default` and `filter` are inferred from the docs, not probed. They need fixtures (§8).

Every merge then falls into one class:

| Class | Condition | Gate behaviour |
|---|---|---|
| **S0** clean, disjoint | sync merge; precondition holds; trial clean; recorded tree == T; overlap set empty | **Deterministic pass. No marker, no review.** |
| **S1** clean, overlapping | as S0, but the overlap set is non-empty | Pass only if **every** overlap path is on a **pass-safe allowlist** (OQ-4, decided in §7). The list is narrow: `CHANGELOG.md`, `changelog.d/**`, `docs/backlog/**`, `docs/archive/**`. Otherwise a scoped review (§3.5). A denylist of enforcement paths was rejected: it missed `tests/**` (gate tests, `tests/mutate.py` anchors), `standards/**`, `CLAUDE.md` and `.gitattributes`. |
| **S2** resolved | sync merge; precondition holds; the trial conflicted, or recorded tree ≠ T | Scoped review of the resolution diff. The marker binds §3.4's scope hash. |
| **N** not a sync | anything else, or any step errors | Today's behaviour, unchanged. |

**Why S1 is separate from S0.** A clean textual merge can still be semantically wrong, and CI
catches only part of that. So S1 keeps a reviewer on every shared path outside the allowlist.

**Premise against S0, decided acceptable (OQ-9, §7).** The one real interaction #78's merge reviews checked (round-2
brief, focus item 3) was **not** a shared path:
- #78 changed `scripts/_review-gate-classify.ps1`;
- main's #81/#85 changed `scripts/review-reminders.ps1`, which dot-sources that file.

A clean sync with only that coupling has an empty overlap set, so it is **S0: a deterministic
pass, no reviewer**. Path overlap does not detect cross-file coupling. The user accepted this on
2026-10-24: for S0, CI on the synced head is the only check. That relies on strict required checks
(OQ-1); an adopter without strict lacks it.

### 3.3 Commit gate (a conflicted merge finished with `git commit`)

When MERGE_HEAD resolves, the gate classifies (P1 = HEAD, P2 = MERGE_HEAD, recorded tree =
`git write-tree`) after the existing "unstaged changes" refusal, which stays first.
- **S0 / S1-pass:** allow, and drop no marker. The post hook has nothing to reissue.
- **S2 / S1-review:** expected = the scope hash. The rest is today's claim / compare / release
  logic, including the `EMPTY_DIFF_SHA` refusal.
- **N:** today's `diff_hash HEAD`.

Git itself refuses `--amend` and partial commits during a merge. Treat that as a test to write,
not a fact.

### 3.4 Push gate

**The trust anchor is a reviewed tip the gate records, not the remote-tracking ref.** Content on
the remote PR branch has not always gone through the gate: there are recorded evasions (`git $VAR`,
a commit inside a script), the app's sync once merged a non-main branch, and a refspec push from
another worktree moves the ref. Today the whole PR is re-hashed at the next gated push, so such a
slip is caught. An anchor on the remote ref would make it permanent.

**Recording.** When the push gate consumes a matching `.change-review-ok` marker, it appends
`<branch> <HEAD-oid>` to a gitignored `.claude/.reviewed-tips`. That is the moment the full-PR
review is proved to cover HEAD. The file is agent-writable, the same trust class as a marker
(§3.7). It records review, not push success, which is what the pass needs.

**Pass conditions.** The merge-aware path applies only when **all** of these hold. Anything else
takes today's path, `origin/main...HEAD`:
1. The classified command is a **single** `git push` segment, not chained. A chained command such
   as `git cherry-pick X && git push` runs after this hook has looked at HEAD. The classifier
   already returns PUSH for it.
2. **No refspec**, or a refspec whose source is the current branch. No `--all`, `--tags`,
   `--mirror` or `--delete`. Classifier context work is needed for this.
3. The branch has a recorded tip X. X is an ancestor of HEAD.
4. `git rev-list --first-parent X..HEAD` is **non-empty**. An empty list is vacuously "all
   merges", and must not pass.
5. Every commit on that list is a sync merge (§3.2).

Then:
- if every merge is S0 or S1-pass, the push passes deterministically, and HEAD is recorded as a
  new tip;
- otherwise, expected = the scope hash over the S2 and S1-review merges, in first-parent order.

`@{u}` is not used. In this very worktree it resolves to `origin/main`, which would put the PR's
own commits on the list.

**Scope hash.** It is a single byte stream, produced by one helper (§3.6):
- a version line, `pmb-merge-scope v1`;
- for each merge in scope, a line `merge <M> <P1> <P2>`, its overlap paths if S1, then its
  resolution diff;
- for S1, the reviewed content: `git diff <P1> <T> -- <overlap paths not on the pass-safe allowlist>`, that is, what
  main's side changes in those files.

The commit gate uses the same format with M = `PENDING` and P1 = HEAD.

### 3.5 What the review commands do

`/code-review` and `/change-review` gain a merge mode. Neither works out scope by itself. Both run
the helper (§3.6), which prints the class, the scope payload and its hash:
- **S0 / S1-pass:** nothing to review. The command says so and writes no marker. The gate passes
  on its own.
- **S2 / S1-review:** the hashed payload is the review subject. As context only, not hashed:
  - for each conflicted or overlap path, `git diff <mb> <P1> -- <path>` and
    `git diff <mb> <P2> -- <path>`, so a reviewer sees what each side meant;
  - `git log --oneline mb..P2`.

  Domain focus is fixed: does the resolution keep both sides' intent, and do the two sides'
  changes to shared enforcement files still compose?
- **Panel** (decided, OQ-3, §7):
  - full panel with Opus opposition when the scope includes an enforcement path, as defined
    in §7;
  - otherwise correctness and maintainability, with opposition on Sonnet ("mechanical re-review",
    per the reviewer-model memory).

The domain-brief SAFETY RULES block is unchanged, including "never touch .git/MERGE_HEAD".

### 3.6 One helper, which fails back to today's behaviour

Add `scripts/_review-gate-merge-scope.py` (name provisional). The sh hook, the ps1 hook, both post
hooks and both commands call it. It does not get a PowerShell twin. Why this differs from the
classifier, which has twins: a classifier fallback must fail **closed** (deny), so the classifier
needs a native ps1 path. This helper's absence fails over to **today's** scope, which is the most
expensive outcome but never a hole. With no python3, an exception, a timeout, unparsable git
output, or a helper version that does not match, every caller takes class N.

If the command used the helper and the hook could not, the hashes differ, the gate denies, and the
review re-runs at full scope. That disagreement also lands in the safe direction.

`review-reminders-post.*` (marker reissue after a failed commit) must compute `expected` through
the same helper, or a failed S2 commit would get no reissue. That is safe but wasteful.

### 3.7 Attack surface

Threat model, unchanged from the existing gate: a rushed or drifting agent, not a determined
adversary. The latter can already write a correct sha256 into a marker. A pass must therefore be
**at least as hard to obtain by accident** as today's marker, and nothing in it may rest on state
the agent writes as a side effect of ordinary work.

| Attack | What stops it |
|---|---|
| **Evil merge:** a clean sync plus extra edits | The recorded tree ≠ T, so the merge is S2 and the extra edits *are* the resolution diff under review (F1, F2). |
| **Resolution that silently drops main's fix** (takes ours) | Shows in the resolution diff, which compares against the conflicted trial tree. `--cc` would hide it (F5). |
| **Forged MERGE_HEAD** with no real merge | Never trusted, only compared against. The staged tree must equal merge-tree(HEAD, MERGE_HEAD), or the merge is S2 and its difference is reviewed (F6). A forged MERGE_HEAD naming a non-base commit is class N. |
| **Merge of an unreviewed non-main branch** | P2 is not an ancestor of the base ref, so class N: today's full scope at commit, and its content shows up in the push gate's `origin/main...HEAD`. |
| **Forged base ref** (`git fetch . X:refs/remotes/origin/main`, or a hand-edited ref file; `git update-ref` is **confirm**-tier in dangerous-commands, not blocked) | Locally, X's content would pass as "main". **CI backstop (§3.8)**: every first-parent merge's P2 must be an ancestor of the *real* base. It is a required check, so X cannot reach main. **This holds only once OQ-5's stacking exemption has an operational definition.** As worded in §7 the exemption covers every merge, so a forged-base merge would be exempt (§10, SEC3-1). |
| **Forged or stale remote-tracking ref** | Not consulted (§3.4). The anchor is the gate-recorded reviewed tip. |
| **Forged `.claude/.reviewed-tips` entry** | Same trust class as writing a marker by hand, which the threat model already accepts. It takes deliberate work, not an accident. **This is a new agent-writable trust input, created by this design.** |
| **Chained command**, **refspec push**, **empty X..HEAD** | §3.4 conditions 1, 2 and 4: each takes today's path. |
| **Merge drivers, `merge.default`, `merge.renormalize`, filters** (F7, F8) | The §3.2 precondition refuses any pass, before merge-tree runs, so the hook never executes a driver. |
| **Renames hiding an overlap** | `--no-renames` (§3.2). |
| **rerere** auto-applying an old resolution | `git merge` applies it but merge-tree does not, so the recorded tree ≠ T and the merge is S2. Safe direction. |
| **Config drift** between hook and command (conflictStyle, diff options) | One helper with pinned `-c` flags (§3.6). |
| **Conflict markers committed by mistake** | Visible in an S2 resolution diff. The existing CI conflict-marker check stays. |

**Residuals, which exist today and which this design neither causes nor closes:**
1. The push gate's `origin/main...HEAD` already trusts the local `origin/main`. Forging it to an
   unreviewed non-merge commit shrinks today's push diff. Backlog candidate: compare against
   `git ls-remote` at push time, which is a network operation anyway.
2. Clean `git merge`, `cherry-pick`, `revert`, `rebase --continue` and `am` create commits with
   no commit gate (F10). This design does not gate them. It makes the push gate cheap for the
   sync subset.

### 3.8 CI backstop: a required check, which must land with the push-gate pass

This is a new job, or a step in an existing required job. With `fetch-depth: 0` on the
pull_request merge ref, base = `HEAD^1` and the PR head = `HEAD^2`. For every merge M in
`git rev-list --first-parent --merges <base>..<pr-head>`, P2 must satisfy
`git merge-base --is-ancestor <P2> <base>`. Any other merge fails the job, naming M and P2.

- **What it settles:** the local pass's only unverifiable input, the base ref. CI fetched the real
  one.
- **What it does not settle:** whether an S2 review happened. No CI check verifies markers today
  either.
- **Cost to the workflow:** it forbids merging any non-main branch into a PR branch, so it is a
  workflow rule, not just a check. It conflicts with branch stacking, which the global CLAUDE.md
  gives as an example of a reversible alternative: #90 is stacked on #78, and syncing a stacked
  branch with its parent is exactly the non-main merge this rule fails.
- **Decided (OQ-5, §7):** exempt a stack parent. **The operational definition is OPEN.** The
  wording first recorded, "P2's commits lie in the PR's own base..head range", is always true.
  P2 is reachable from M, and M is in base..head, so that wording exempts every non-main merge.
  Measured: `git rev-list 1eda52c..07dfd49` contains 33b7517, which is not in base. A usable
  definition names the parent, for example "P2 is an ancestor of a named, gate-reviewed
  stack-parent head". Choosing it is the user's call, and it is needed before step 5.
- **Also OPEN (§10, F6, 2026-10-30):** a reconcile merge whose P2 is a PR-branch-only commit, such
  as c9bfba1 with P2 335974e, fails the ancestor rule on a correct, reviewed history.

**Adopters (templates).** The review-gate scripts are mirrored into `templates/scripts/` and
shipped by `mb upgrade`, but `templates/.github/workflows/` holds only `memory-bank-size.yml`, and
a required check is a per-repo setting. Shipping the helper as-is would hand ACR and SQA exactly
the "pass alone" configuration §6 rules out.
- The pass is therefore **off by default**. It turns on only when `.claude/merge-gate.json`
  declares the backstop, for example `"sync_pass_backstop": "<required check name>"`.
- The implementation PR carries the templates mirror and its mirror-parity rows.

### 3.9 What this does not save

- Syncs that conflict in enforcement files still get Opus. That is intended.
- Wall clock and CI minutes per sync are unchanged. Item 2 is the lever for those.
- CHANGELOG overlaps:
  - In 4e62cff the CHANGELOG overlap conflicted.
  - In f1cbabd it merged clean, but the result broke the line cap. The cap fix is a hand-edit, so
    it is S2 anyway.

  Only fragments (§5.1) remove both causes.

## 4. Change 2 — "require branches to be up to date" (`strict: true`)

**Current settings,** read-only via `gh api …/branches/main/protection`, 2026-10-23:
- `required_status_checks.strict: true`, with 9 required contexts;
- `enforce_admins: true`;
- 0 required approving reviews;
- `allow_update_branch: false`;
- squash, merge and rebase merges are all allowed.

The repository is **public and user-owned**.

**Strict is load-bearing today. Do not drop it silently.** It is stated as a premise in all of
these places, found by `grep -rn -i "strict: *true\|strict:true"` over `*.sh`, `*.ps1` and `*.md`
plus the ps1 wording:
- `docs/HOOKS-GUIDE.md:257`;
- `templates/scripts/review-reminders.sh:10` and `templates/scripts/review-reminders.ps1:31`,
  the adopter mirrors;
- `docs/backlog/merge-gate-misses-gh-global-flags-graphql-and-powe.md:207,220`;
- and the three below.
- `review-reminders.sh:8-11` says a mergeable PR's diff has already passed CI on the current head
  "per branch protection's required-status-checks with strict:true";
- `review-reminders.ps1:31` says the same;
- the merge-gate spec (`2026-10-20-merge-gate-user-approval-design.md`) builds its rationale on
  it at line 37, and at lines 184-185 rejects in-hook checks because GitHub already enforces
  strict required checks.

Dropping strict removes a premise of the live merge gate, so that change must also edit those
comments and the merge-gate spec's premise, or add the check they deferred to GitHub (option C′).

**Cost shape.** Each merge to main makes every other open PR `BEHIND`.
- **Eager syncing** (Auto-fix syncing every PR each time it falls behind) costs about n(n−1)/2
  syncs to land n PRs.
- **Lazy syncing** (sync a PR only right before its own merge) costs about n−1.
- Most of #78's cost was not strict at all: two of its three syncs were forced by conflicts, which
  must be resolved whatever this setting says.

**What strict buys.** pull_request workflows check out `refs/pull/N/merge`, the merge with main
**as of the triggering event**. All 12 `actions/checkout` uses in `pmb-health.yml` set no `ref:`,
so they take that default. When main moves, GitHub recomputes mergeability but **does not re-run
the workflows**. Without strict, a green check can describe a merge with an older main, and a
semantic conflict lands on main. The push-to-main run of `pmb-health.yml` catches it after the
fact.

**What raises the stakes here.** No release has been cut since 1.2.1, and `mb upgrade` copies the
working tree (release-policy memory). Main **is** the distribution channel for ACR and SQA, so a
broken main is visible downstream, not just inconvenient.

| Option | Token cost per main merge | Risk | Notes |
|---|---|---|---|
| A. Keep strict, today's gates, eager syncing | O(n) full reviews | lowest | Today's situation. Unsustainable at 5 parallel sessions. |
| A′. Keep strict, **sync lazily**: only the PR about to merge is synced | one sync per merge | lowest | No setting or code change. It is a working rule for Auto-fix and sessions: do not sync a `BEHIND` PR that is not next to merge. Its cost is still one full review per sync until item 1 or item 3 lands. |
| B. Keep strict, plus item 1 | O(n) syncs, ~0 review tokens for S0/S1-pass | lowest | Wall clock and CI still O(n²). Needs the enforcement change to land first. |
| C. Drop strict | 0 syncs unless a PR actually conflicts | stale-CI semantic conflict reaches main, then caught by push CI | One click, reversible. Conflicting PRs still need syncs: GitHub refuses to merge a conflicted PR either way. **Invalidates the merge gate's stated premise** (above), so the same change must edit those rationale comments and the merge-gate spec. |
| C′. Drop strict, and the merge gate's ask names CI staleness | as C | as C, but visible at the one moment the user decides | Small merge-gate change. Show the base OID the last PR run tested against current main (the run's `HEAD^1`, recorded in the job log or an artifact). Enforcement change, so spec it first. |
| D. Merge queue | 0 local syncs, since GitHub tests the merge group | lowest | **Availability for a user-owned repo is unverified.** The GitHub docs pages fetched do not state eligibility. My recollection that queues need an organization-owned repo is unconfirmed. Also needs a `merge_group:` trigger on every required workflow, and changes to the merge gate, which today denies `--auto`. |

**Recommendation:**
- **Now: A′.** Keep strict and sync lazily. It needs no setting change and leaves the merge gate's
  premise intact. It cuts the eager O(n²) to about one sync per merge. *Narrowed 2026-10-30
  (§10, F1): never Update branch while the PR's session has unpushed commits.*
- **Not C on its own.** C drops a premise of a live enforcement layer while main is still the
  distribution channel, and it would not have avoided #78's conflict-driven syncs.
- **If a stronger cut is wanted later: C′.** It adds the staleness check before strict goes, as an
  enforcement change with its own spec and review.
- **Check D's availability** by looking for "Require merge queue" under Settings → Branches. That
  is a read, not a change.
- **After a release is cut (§5.1 a)**, adopters can pin a tag by checking it out by hand. The
  stakes drop fully only once `mb upgrade` sources from a ref; it still copies the working tree.
  At that point C′ or D become easier to justify.

This is the user's decision. Nothing here changes a setting.

## 5. Change 3 — single-insertion-point files

### 5.1 `CHANGELOG.md` and the 800-line cap

The cap is the generic markdown rule in `pmb-health.yml`'s File Size job (warn above 500, fail
above 800, every `*.md` except `memory-bank/`, `docs/superpowers/plans/` and worktrees).
CHANGELOG gets no special treatment.

The "Released history" remedy, moving the oldest released sections to a new dated archive file,
cannot apply: everything since 1.2.1 is `[Unreleased]`.

The release-policy memory says:
- releases were decided on 2026-08-28;
- the first tag was scheduled for after `fix/block-tier-case-sensitivity` merged.

That branch merged as #25 (103b146, 2026-09-14). `git tag -l 'v*'` still ends at `v1.0.4`, while
VERSION says 1.2.1. **The precondition has been met for five weeks and the tag was never cut.**

| Option | Fixes the cap | Fixes conflicts and push-hash churn (F9) | Cost |
|---|---|---|---|
| a. Cut a release now | yes, once: rename `[Unreleased]` and archive it per the Released-history rule | **no**: every PR still inserts at the top of `[Unreleased]` | User action (a tag is publishing). Also fixes "1.2.1 names no artifact". |
| b. Per-PR fragments `changelog.d/<branch-slug>.md`, assembled at release | yes: the file stops growing between releases | **yes**: no shared lines, so no conflicts and no CHANGELOG overlap in S1 | A small assembly script with a test; a convention line in the commands that tell agents to write changelog entries. Branch slug, not PR number, because the number does not exist at first commit. |
| c. Exempt CHANGELOG from the cap, or raise it | yes | no | One workflow line. It only postpones. The cap's purpose (reading cost) is weak for CHANGELOG, which is not startup context. |
| d. `CHANGELOG.md merge=union` in `.gitattributes` | no | locally only (F7). Unverified whether GitHub's mergeability honours it | It also disables item 1's pass for CHANGELOG (§3.2 precondition), and union silently reorders or duplicates entries. **Not recommended.** |

**Recommendation: b, then a.** Fragments remove the conflict class. A release then folds the
fragments and gives the cap headroom for good. a alone buys headroom but keeps every conflict.
Release cadence is on demand (OQ-6, §7). Until a release exists, unreleased notes live in
`changelog.d/`, so readers need `ls changelog.d/` or the assembly script's `--preview`. That
trade is real; name it in the PR.

Things the fragments PR has to handle:
- **It must trim CHANGELOG itself.** Any added pointer line takes the file from 800 to 801.
- **Readers who start at CHANGELOG need a pointer.** `docs/UPGRADE.md:93` sends adopters to
  CHANGELOG.md, and backlog files cite CHANGELOG entries by heading.
- **There is no instruction to put the convention next to.** No command tells agents to write a
  changelog entry today. The convention will live in `standards/WORKFLOW.md` (OQ-8, §7).
- **Verified, from the opposition review:** nothing in `scripts/` or `templates/` reads
  CHANGELOG.md, so `mb upgrade` is unaffected.

### 5.2 `tests/run.sh`'s hand-kept `run_suite` registry

Today there are 29 `run_suite` lines and 29 tracked `tests/test-*.sh` files. A completeness check
(`run.sh:49-81`) fails when a tracked suite is not registered. That check exists **only** because
the list is maintained by hand: its own comment calls the list "the THIRD instance of the
stale-hardcoded list bug".

**Proposal:** enumerate `git ls-files 'tests/test-*.sh'`, sorted, and run each one. The display
name comes from the file name. Delete the list and the completeness check.
- **Why `git ls-files` and not a shell glob:** the existing comment's reason still holds. Untracked
  work-in-progress suites must not run.
- **Fallback without git:** reviewers run suites on a `git ls-files | tar` copy, which has no
  `.git` (domain brief). There, a shell glob over `tests/test-*.sh` is correct, because the copy
  has no untracked files. Print a loud `NOTE:` line, matching the existing SKIP convention.
- **Guard against zero suites.** Trust `ls-files` only when `git rev-parse --show-toplevel` equals
  REPO_ROOT. A tar copy extracted inside another repository would otherwise list nothing, and the
  run would print "All test suites passed". Also **fail when the enumerated list is empty**.
- **What it loses:**
  - Custom display names. Cosmetic.
  - Hand-chosen order: alphabetical instead of "mb commands first". No suite is known to depend on
    order. The known interference is concurrency, not order (memory: test suite not
    concurrency-safe). Confirm by running the suite in the new order once.
- Not an enforcement change. Ordinary review applies.

## 6. Recommended order

Cheapest and most reversible first. Measure before building the expensive part.

1. **`tests/run.sh` enumeration** (§5.2). Small, not enforcement, and it removes one conflict
   point.
2. **CHANGELOG fragments** (§5.1 b). Small. Also lands the trim CHANGELOG needs anyway, since it
   is at 800 lines.
3. **User decisions, none of them code** (both decided on 2026-10-24, §7): cut the first release
   as 1.3.0 (§5.1 a), and adopt lazy syncing (§4 A′).
4. **Measure for two weeks.** Count syncs, how many conflicted (S2), and **which gate paid**
   (commit or push). Until then the only evidence is #78: two conflicted syncs (S2) and one clean
   one (S0, 7e839fd). *First measurement taken early on 2026-10-30: build neither yet (§10).*
5. **What to build next depends on step 4's measurement** (strict is kept, per OQ-1):
   - **Clean syncs still common** (many S0; count local syncs that reach a gate, not GitHub
     Update-branch merges, which pass through none, §10): build the push-gate S0/S1 pass, the CI backstop and
     the templates opt-in **in one PR** (§3.4, §3.8). The pass relies on the backstop. First
     close the OPEN items in §10's round-2 list, including AD-F1, SEC-F1 and B3 (fixed in form
     only). Opus review.
   - **Conflicted syncs still common:** build S2 scoping, the commands' merge mode, and the
     commit gate (§3.3, §3.5). For #78, the reviewed scope would have been small:
     - 4e62cff: the CHANGELOG resolution;
     - f1cbabd: the `tests/run.sh` resolution plus the CHANGELOG cap edit, including the new
       46-line `docs/archive/changelog-2026-10-23-pending-session-claims.md`;
     - 7e839fd: no review at all.

     All of it is far smaller than the 289 KB payload of the full-diff review.
   - **Syncs rare** (after fragments and lazy syncing): build neither. **This is a real possible
     outcome, not a formality.**

## 7. Decisions on the open questions (user, 2026-10-24)

| OQ | Question | Decision |
|---|---|---|
| OQ-1 | `strict` up-to-date (§4) | **A′: keep strict, sync lazily.** Only the PR next to merge is synced. No setting change. Narrowed 2026-10-30 (§10, F1): and never while its session has unpushed commits. |
| OQ-2 | First release | **Cut 1.3.0 now** (§5.1 a). The user approves the tag push. |
| OQ-3 | Panel for scoped reviews (§3.5) | **Full 5 domains plus Opus opposition when the scope touches an enforcement path.** Otherwise correctness and maintainability with a Sonnet opposition. |
| — | Enforcement paths (defines C4's missing term) | `scripts/`, `.githooks/`, `mb.sh`, `mb.ps1`, `.claude/`, `.github/`, `templates/`, `tests/`, `standards/`, `CLAUDE.md`, `.gitattributes`, `.gitignore`. |
| OQ-4 | Pass-safe overlap allowlist (§3.2) | As proposed: `CHANGELOG.md`, `changelog.d/**`, `docs/backlog/**`, `docs/archive/**`. |
| OQ-5 | Non-main merges and stacking (§3.8) | **Exempt in-PR parents.** Allow a merge whose P2 commits lie in the PR's own range; fail any other non-main merge. **Intent decided: support stacking. Operational definition OPEN**, because as worded the condition is always true and so exempts every non-main merge (§3.8, §10 SEC3-1). |
| OQ-6 | Release cadence | **On demand:** when adopters need a change, or at about 20 fragments. The user approves each tag. |
| OQ-7 | Configurable base ref | **Deferred** until the merge-aware pass is built. |
| OQ-8 | Home of the fragment rule | **`standards/WORKFLOW.md`**, Commit phase. Not CLAUDE.md, whose startup size is ratcheted. |
| OQ-9 | Clean syncs with cross-file coupling (§3.2) | **Acceptable.** S0 relies on CI on the synced head. |

## 8. Test plan sketch (for the implementation PRs, not this one)

- **One fixture per §3.7 row,** in a temp repo pinned with `git -C` and run in both shells. The
  F7 and F8 rows must show that the driver **did not run**, using a marker file the driver would
  create.
- **Untested config cases:** `merge.default=union`, `merge.renormalize=true`, and a `filter`
  attribute on an overlap path, none of which were probed for this spec.
- **Push conditions:** a chained `git cherry-pick X && git push`, a refspec push of another branch,
  an empty X..HEAD list, and a branch with no recorded tip. Each must take today's path.
- **Renames:** a main-side rename plus a PR-side edit must produce a non-empty overlap.
- **Templates:** the opt-in is off by default, so an adopter gets today's behaviour.
- **run.sh:** a tar copy inside another repository, and an empty enumeration, must both fail.
- **S0 / S1 / S2 / N classification table:** clean disjoint, clean overlapping in an enforcement
  path, conflicted, evil, forged MERGE_HEAD, octopus, criss-cross, a non-main P2, a forged base
  ref.
- **Byte parity:** the helper's scope hash, called from sh and from ps1, for the same S2 merge.
- **Fail-back:** helper missing, python3 absent, or helper crashing: each must produce today's
  hash. Assert the deny message, not just the deny (PR #78 follow-up m-testing F1).
- **Git's own refusals during a merge** (`--amend`, partial commit): measured, not assumed.
- **CI backstop:** a main-only sync passes. Under the OQ-5 definition, once it is chosen:
  - a stack-parent merge passes;
  - an unrelated, unreviewed branch merge fails;
  - a merge whose P2 is a forged base fails.

  A stacked sync stays class N locally (§3.2).
- **Fixtures added by the 2026-10-30 measurement (§10):**
  - Backstop: a reconcile merge whose P2 is a PR-branch-only commit that a squash merge left out
    of main (c9bfba1 with P2 335974e). The expected verdict is OPEN until the OQ-5 definition is
    chosen.
  - Push: unpushed local commits, then an Update branch on the remote, then a non-fast-forward
    rejection. Assert what happens to the push marker (F1).

## 9. Out of scope

- Gating clean `git merge` and the other commit-creating verbs (F10, residual 2).
- Verifying the base ref with `git ls-remote` in the push gate (residual 1).
- Any `pmb-health.yml`, settings or hook edit. This document only proposes them.

## 10. Opposition review

**Round 1 (Opus, 2026-10-23): Request Changes.**
- The spec landing as a document is not blocked.
- Building the push-gate pass is blocked until B1–B4 are fixed, and §4 could not go to the user
  until B5 was fixed.
- The full report is `review-budget-spec/opposition-r1.md` in the side-session notes folder.

The round-1 findings are addressed as listed below. Round 2 judged the §3.4 redesign (the
recorded tip and the push conditions) and found it still has open defects. It needs its own Opus
pass before step 5 is built.

| ID | Sev | Blocking | Disposition in this revision |
|---|---|---|---|
| B1 | High | yes | §3.4 conditions 1, 2 and 4 (single segment, refspec, non-empty list); §3.7 row; §8 fixtures. |
| B2 | High | yes | The anchor moved from the remote-tracking ref to a gate-recorded reviewed tip (§3.4). Forged-ref rows re-filed in §3.7; the new trust input is named. |
| B3 | High | yes | The templates opt-in is off by default and needs a backstop declaration in `merge-gate.json`; mirror and parity work named (§3.8). |
| B4 | Medium | yes (step 5) | `merge.*` allowlist, pinned `merge.default` and `merge.renormalize`, filter refusal (§3.2); untested, so fixtures in §8. |
| B5 | High | yes (§4 text) | The strict premise is stated with its three sources. Lazy syncing (A′) added. The recommendation changed from C to A′, with C only through C′ (§4). |
| N1 | Medium | no | §6 step 5 now branches on step 4's measurement (OQ-1 has since been decided). F10's "most money is in the push gate" claim withdrawn. |
| N2 | Medium | no | `@{u}` dropped; the recorded tip replaces R. |
| N3 | Medium | no | `--no-renames` on the overlap set. |
| N4 | Medium | no | Denylist inverted to a pass-safe allowlist. §3.9's CHANGELOG claim corrected. |
| N5 | Medium | no | Toplevel guard and empty-list failure (§5.2). |
| N6 | Low | no | F3 evidence saved (`probe3.out`); F6 scoped to what was measured; §1 counts (9 BEHIND) and the Medium finding corrected; `update-ref` is confirm-tier; F10 source fixed. |
| N7 | Low | no | Stacking conflict named in §3.8 and OQ-5. |
| N8 | Low | no | Trim, pointers and convention home added to §5.1 and OQ-8. |

**Round 2: `/code-review` (5 Sonnet domains plus Opus opposition, 2026-10-24)**

The first verdict was Request Changes, for false statements of fact (OPP-1) and an overclaim in this
section (OPP-2). Both are corrected above: the §2 class table, the §3.2 premise, §3.9 and §6. The
round-2 findings are in `review-budget-spec/cr-domains.md` and `opposition` hand-backs.

**After the round-2 Approve (commit 1e3165a):**
- The opposition's NEW-1 to NEW-4 are fixed:
  - NEW-1, the stale "not re-reviewed" line in §6;
  - NEW-2, the ps1 mirror added to the §4 strict list;
  - NEW-3, the order of the open questions, now superseded by §7's table;
  - NEW-4, the archive file in f1cbabd's scope, and the unmeasured precondition for 7e839fd.
- §7 now records the user's decisions of 2026-10-24.

**Still OPEN, not addressed by this revision.** Opposition moved each blocking item to "blocks
building step 5, not committing this record".
- **AD-F1 (High).** This design does not reconcile with the Approved
  `2026-08-12-review-gate-layered-enforcement-design.md`.
  - That spec's Layer 3 (lines 192-197) requires a git-tracked review-log entry covering every
    commit in `merge-base..HEAD`. An S0 pass writes none, so every S0 sync would fail that CI
    check once Layer 3 exists.
  - Its Layer 1 also changes from consuming a marker to a peek-and-deny. That changes §3.1's
    premise that a push marker is single-use.
  - Before step 5: supersede that design, build on it, or sequence behind it. Probably by making
    the recorded tip a Layer 3 review-log entry.
- **SEC-F1 (High).** No class covers a conflicted merge that also has clean overlap on a
  non-allowlisted path. That case happened: f1cbabd conflicted in `tests/run.sh` and had a clean
  CHANGELOG overlap. Fix: S2 scope = S1-review scope plus the resolution diff.
- **B3 is fixed in form only** (C3, SEC-F6, AD-F2, M3). The opt-in in `.claude/merge-gate.json`
  is agent-writable. That file belongs to the `gh pr merge` gate and denies every merge when it is
  malformed. Nothing verifies the declared check.
- **Open Medium items, to fold into §3.2, §3.4, §3.7 and §8 before step 5:**
  - SEC-F2: `refs/replace` and `.git/shallow`.
  - SEC-F3: record a tip only on the `origin/main...HEAD` path, not the `HEAD` fallback.
  - SEC-F4: `check-attr --source`.
  - SEC-F5: push config (`push.default`, `remote.*.push`).
  - SEC-F7: the tips file needs a `.gitignore` entry, tree OIDs and an expiry rule.
  - T1: mutation requirements. The `merge.default` and `merge.renormalize` pins are dead behind
    the key allowlist.
  - T2: positive and single-condition fixtures.
  - T3: a "take ours" fixture.
  - T5: P2-side `.gitattributes`.
  - T6: a run.sh test seam.
  - T7: helper presence and mirror rows.
  - M1 and C3: the helper name collides with `_review-gate-merge.py`, and its registration points
    are unlisted.
  - M2: interpreter discovery for the ps1 hooks.
  - M4: the tips-file lifecycle.
  - M8: the fragments script's language, twin and test.
  - C4: resolved after round 2. §7 now defines the enforcement paths, and §3.4 uses the
    allowlist instead.
  - C6: `SKIP:` not `NOTE:`; path-form compare on Git Bash.
- **Round 3** (`/code-review` of the decisions revision, 2026-10-24; findings in
  `review-budget-spec/cr3-domains.md`):
  - **SEC3-1 (High). OPEN, blocks step 5's backstop.** OQ-5's stacking exemption, as first
    worded, is always true, so it exempts every non-main merge, including a forged base (§3.8).
    The user needs to decide how a stack parent is identified, for example "an ancestor of a
    named, gate-reviewed stack-parent head".
  - **OPEN: gaps in the enforcement-path set** (SEC3-2, T3-3, AD3-5). These tracked paths are on
    neither list: `.gitleaks.toml`, `AGENTS.md`, `.cursor/rules/`, `.codex/hooks.json`,
    `VERSION`, `install.*` and `ai-review.config.json`. A scoped review touching only them gets
    the reduced panel. Before step 5, the user should decide whether to extend the set or invert
    it, so that only a named docs/data list gets the reduced panel.
  - **Other open items:**
    - T3-2: the helper should emit an enforcement flag, and the panel choice should be tested.
    - T3-4: settle whether allowlisted overlap paths enter the S1 hash (§3.4).
    - AD3-1: `tests/test-mirror-parity.sh` allows exactly one differing line in
      `standards/WORKFLOW.md`, so the OQ-8 rule must be live-only with the pin updated, or
      mirrored generically.
    - AD3-3: a tag alone does not change what `mb upgrade` ships until it sources from a ref
      (`memory-bank/activeContext.md`: tag → dirty-tree guard → ref-sourcing).
- **Measured by Correctness in round 2:**
  - `merge.default=union` in `.git/config` turns a conflict into a clean concatenation, and
    `check-attr` still says `unspecified`. So the `merge.*` key check is necessary.
  - A `merge=union` attribute present only in P2's tree was **not** honoured by merge-tree.

**Measurement 2026-10-30 (§6 step 4, taken early; Opus opposition: Agree with changes).**
Outcome: **build neither gate yet.** The two-week window runs to about 2026-11-08, and this entry
can be revised when it closes. The raw notes (`sync-measure-*.txt` and
`opposition-build-or-wait-2026-10-30.md` in the side-session notes folder) are not kept in the repo.
The git commands under each figure are the durable evidence. Counts, dates, ancestry and conflict
lists were re-derived with `git` on origin/main e73d92a. Resolution-diff sizes use §3.2's trial-tree
method and equal the notes' figures. Finding labels F1-F6 are the 2026-10-30 opposition's own and
are not the F-numbers used earlier in this spec.

- **Counts.** Scope: merge commits on PRs #78, #88, #89, #93-#96, #98, #99 and #103 (2026-10-20 to
  2026-10-30), 22 in all (`git log --merges <PR head> ^origin/main` per PR). `git log --all
  --merges --since=2026-10-19` lists about 50 (49 when first counted; the number is
  time-dependent and includes stash commits), so this is a sample. The merges it omits include
  8abc850 and bb53065, both local, clean and overlapping enforcement paths, so neither would be an
  S0 pass. Of the 22, 21 are syncs of `main` and c9bfba1 is a
  reconcile merge from the PR's own remote branch. 15 of the 21 were made by GitHub's "Update
  branch" (`git log -1 --format=%cn`: `GitHub`; subject `Merge branch 'main' into …`). The other 6
  were local (`Merge remote-tracking branch 'origin/main' …`). GitHub's merges ran no local gate.
  By the §3.2 classes there are 14 S0 (13 GitHub plus c873d0c), 3 S1 and 4 S2. The opposition's
  "13 of 18" did not reproduce: it matches none of these counts (21 syncs, 15 GitHub-made, 14 S0).
- **F1 (High). Update branch is free only while the PR branch has no unpushed local work.**
  The #78 race is the counter-example. GitHub made 335974e at 2026-10-26 20:38:16Z with parents
  dc8dcb6 and a384084, while the local commits 9185ea7 (18:12:56Z) and d48b0d3 were unpushed.
  c873d0c then re-merged the same main tip (a384084) locally, at 20:45:15Z. The two lines had to be
  reconciled by c9bfba1 (class N, 2026-10-27), whose P2 is 335974e. The push marker is dropped in
  PreToolUse, so a push rejected as non-fast-forward burns it. The lazy-sync rule (§4 A′, OQ-1) is
  narrowed accordingly: Update branch only on the PR about to merge, and never while its session
  has unpushed commits.
- **F2 (Medium). Conflicts still happen.** `git merge-tree --write-tree --name-only` finds 4 of
  the 21 syncs conflicted: 4e62cff, dc8dcb6 and a76f0d9 in `CHANGELOG.md`, and f1cbabd in
  `tests/run.sh`. All 4 were local, because GitHub's Update branch is unavailable on a conflicted
  branch. All 4 predate the changelog fragments (#97, merged 2026-10-26T16:45:49Z, 8d21b56; `git merge-base
  --is-ancestor 8d21b56 <merge>` exits 1 for all four). Since fragments:
  - 14e4ce4 (`feat/pre-approval-protocol`, made locally, outside the PR set above, 2026-10-26
    23:24:43Z) conflicted in `CHANGELOG.md` and `tests/test-mirror-parity.sh`. Its resolution diff
    is 76,076 B against a commit-gate scope of 919,380 B (`git diff 14e4ce4^1 14e4ce4 | wc -c`).
  - #94 conflicted in the `tests/run.sh` registry and was DIRTY when measured. It has the SEC-F1
    shape (a conflict in `tests/run.sh` plus clean overlap in `tests/test-mirror-parity.sh`), as does
    2fc0841. 14e4ce4 has it too: its clean overlap includes `.claude/settings.json` and
    `scripts/mb.sh`.
  - #90 was also DIRTY. #90 and #94 are now CLOSED unmerged (#90 replayed as #104, #94 re-cut as
    #106, merged e73d92a).
  - The #106 re-cut itself conflicted on `tests/run.sh` again. The merge 2fc0841 (GitHub, 2026-10-30
    21:10:57Z) is a web-editor resolution. `git merge-tree` on its parents conflicts in
    `tests/run.sh`. So a re-cut limits the scope but does not prevent a new conflict.
- **F3 (Medium). Which syncs paid.** Per the opposition, 9185ea7 and c873d0c were the app's
  host-side sync, outside every hook (git shows only a local committer). Per the notes, the syncs
  that cost a review were dc8dcb6 and a76f0d9, both S2 conflicts in the CHANGELOG during the 1.3.0
  restructure. Their resolution diffs are 67,235 B of 189,957 B and 68,322 B of 137,130 B.
- **F4 (Medium). The "resolution diff is 35-50% of the full diff" argument is withdrawn as a stable
  figure.** The ratio is 2.2% for 4e62cff (1,736 of 77,334 B), 2.2% for f1cbabd (6,426 of 289,068
  B), 35% for dc8dcb6, 50% for a76f0d9 and 8% for 14e4ce4 (76,076 of 919,380 B). It is dispersed, not
  reliably high. The case for the commit gate is now frequency, plus a cheaper lever (below).
- **F5 (Low). Lazy sync (OQ-1) was not followed on 2026-10-29 and 10-30.** GitHub merged `main` into
  #88 (317979d) and #89 (b5bee6c) 14 s apart on 10-29, then into #89 again (7c4f0c1) and #103
  (9a71145, then again a661040) on 10-30. These were clean and ran no local gate, but the rule is not being applied.
- **F6 (Medium, new defect). The §3.8 CI backstop would fail #78's real history.** c9bfba1's P2 is
  335974e, a commit that exists only on the PR branch. `git merge-base --is-ancestor` exits 1 for
  both 335974e and c9bfba1 against origin/main, and 6ecda5a (the #78 squash, 2026-10-27) is a
  child of a384084. So "P2 is an ancestor of base" fails a PR that was reviewed and correct. The
  backstop needs the F1 reconcile case specified before it can be built.
- **The push-gate S0 pass would have saved no reviews in this window.** Of the 6 local syncs, 4 were
  conflicted (S2) and 9185ea7 overlapped `CHANGELOG.md` and `tests/run.sh` (not S0). The one clean,
  non-overlapping local merge, c873d0c, reached the remote only inside the c9bfba1 push, which is
  class N and does not qualify for the pass. The 15 GitHub merges are made on the remote and
  pass through no local gate. That is a cost finding: the pass is a relaxation of review, so it
  never had a security case. The §3.8 backstop is needed only if the pass is built.

**Resulting practice (recommended 2026-10-30 by the measuring session and the Opus opposition; it
becomes the decision when the user merges this PR; no code).**
1. For a conflicted PR, re-cut it from `origin/main`, or resolve the conflict in GitHub's web
   editor. Do not merge `main` into it locally. Re-cutting makes the commit-gate scope the PR's own
   change: for #94 that was 14,704 B (`git diff $(git merge-base origin/main 311799b) 311799b |
   wc -c`) against 135,650 B for its last sync merge (`git diff 311799b^1 311799b | wc -c`). Limits:
   a web-editor resolution is a GitHub-made commit that neither the commit gate nor the push gate
   sees (2fc0841), so for a conflict in an enforcement path (§7) re-cutting is the option that keeps
   the review. A re-cut can conflict again.
2. "Update branch" only on the PR about to merge, and never while its session has unpushed commits.
3. Do not build the commit-gate S2 slice, the push-gate S0/S1 pass or the §3.8 backstop yet. Revisit
   at about 2026-11-08 with the same counts.
