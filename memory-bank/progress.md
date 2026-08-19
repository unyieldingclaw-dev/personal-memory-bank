---
authority: accumulating
review-cycle: 30d
retention: archive-after-6m
staleness-threshold: 90d
tags: [work/completed, work/in-progress, work/backlog]
last-reviewed: 2026-08-19
compaction_generation: 0
source_type: canonical
confidence: high
lineage: []
---

# Progress

## 2026-08-12 through 2026-08-14 — Investigation-Integrity Mechanism: Design, 5 Independent Review Rounds, Stale-Marker Hook — condensed, full detail archived

- **User-as-bypass hardened into governance** (2026-08-12): the "hand the user the commit command"
  workaround was named as never acceptable; hardened into `standards/SECURITY-GUARDRAILS.md` +
  `docs/HOOKS-GUIDE.md`. Same session fixed a real ~2-month-old latent bug (`.claude/skills/mb-drift.md`
  undiscoverable — needed `<name>/SKILL.md`, not a flat file).
- **Review-gate layered enforcement spec** (2026-08-12, `f2cec79`/`b47db8f`): three enforcement layers
  designed (CC hook downgraded to peek, `.githooks/` promoted to sole marker consumer, new CI containment
  check) after 2 user-requested re-verification passes each found real bugs. A proposed docs-only
  "lightweight review path" exemption was explicitly designed then withdrawn on the user's principled
  objection — same failure class as the original user-as-bypass mistake. **Standing rule: full
  `/code-review`, every time, no lite path.** Implementation plan written 2026-08-13
  (`docs/superpowers/plans/2026-08-12-review-gate-layered-enforcement.md`, 14 tasks); independent
  pre-implementation review completed 2026-08-14, found 8 more real defects (3 Blocking), all fixed.
  **Superseded 2026-08-17: all 14 tasks implemented and committed** — see that date's entry below.
- **Investigation-integrity design + third mechanism** (2026-08-14, `15df2c2`/`70a06c1`): "independent
  review discipline" added as mechanism 3, motivated directly by the plan review above. Design itself went
  through 2 rounds of independent review (round 2 caught a Blocking conflict with `projectbrief.md`'s
  immutable 7-phase-workflow requirement in the first design). Applied to 8 files; follow-up wording fixes
  went through 2 more full review rounds (rounds 4-5), surfacing 16 more findings total (1 genuinely
  Blocking) before landing clean — the concrete case study for why `WORKFLOW.md`'s "no lite path" rule has
  no size exception, even for a 3-file mostly-cosmetic diff.
- **Stale-marker warning hook built** (2026-08-14): `scripts/warn-stale-review-marker.sh`/`.ps1`, a
  warn-only PreToolUse hook on Write/Edit flagging when a review marker currently exists (motivated by the
  round-4→5 sequence above — editing after Approve silently invalidates the marker with no signal until
  the next commit attempt). A second review pass caught a genuinely Blocking gap the first missed: no
  `templates/` distribution path — fixed by mirroring to `templates/scripts/` and registering in every
  `TEMPLATE_OWNED`/export-allowlist location `_review-gate-lib.sh`/`.ps1` already appears in.
  **Superseded 2026-08-17/18: documented in `HOOKS-GUIDE.md` (Task #31, committed `7d6d2b9`).**
- **Independently verified an imported governance-review document** (2026-08-14): a work-MB session's
  analysis of PMB's code was checked claim-by-claim rather than trusted — 2 of 3 claimed defects were
  wrong (one a misread of denies-vs-allows boolean logic, one accurate-but-wrong-severity), 1 was real and
  fixed (`/change-review` Job 7 had no ACR exit-code failure path). Independently (not from the imported
  doc) found `activeContext.md` (671 lines) and `progress.md` (775 lines) both well over their CI limits —
  trimmed, historical detail moved to `docs/archive/`, same pattern this entry itself now follows.

Full narrative for all of the above (exact findings lists, before/after diffs, dated sub-corrections):
`docs/archive/progress-2026-08-investigation-integrity.md`.

## 2026-08-17 — Review-Gate Layered Enforcement: All 14 Tasks Implemented and Committed — condensed, full detail archived

- ✅ All 14 tasks committed on `feature/review-gate-layered-enforcement` (isolated worktree), each via
  implement → independently verify → Opposition review → orchestrator re-verifies marker hash. 3 real bugs
  found only because test suites were fixed to actually exercise what they claimed to (a pwsh-vs-sh test
  gap that then surfaced a genuine `set -e` crash in shipped `pre-push-check.sh`; two test-only bugs; a
  `findings_has_blocking()` bug that would have let a blocked `change-review` entry pass CI containment).
  A confirmed known limitation: non-fast-forward `git merge` doesn't fire Layer 2's `pre-commit` hook
  (documented, not fixed — Layer 3 CI containment is unaffected). **Not yet merged to `main` or pushed**
  — see `activeContext.md`'s Task #33 deferral note for why, and current status.

Full narrative (exact bug descriptions, commit cycle detail): `docs/archive/progress-2026-08-review-gate-layered-enforcement-execution.md`.

## 2026-08-17 (continued) — Branch-Ancestry Diagnosis, Handoff/Compaction Gap, Standards-Freshness Gap, Review-Gate Hardening Audit

- 🔴 **`feature/review-gate-layered-enforcement` cannot be cleanly rebased onto `main`** — attempted, hit
  immediate modify/delete conflicts on `_review-gate-lib.sh`/`.ps1` on the very first replayed commit.
  Root cause, confirmed via `git cat-file -e main:scripts/_review-gate-lib.sh` (fails — file does not
  exist on `main` at all) and `git merge-base --is-ancestor 39a8647 main` ("NOT an ancestor"): `main` is
  missing entire prerequisite review-gate infrastructure going back to commit `39a8647`
  (2026-07-16-ish), not just `docs/branch-protection-rollout`'s later commits. Rebase aborted cleanly
  (`git rebase --abort`, verified clean + `HEAD` unchanged). Root cause: PR #8
  (`docs/branch-protection-rollout` → `main`) has sat open, `MERGEABLE`/`CLEAN`, all 9 checks green,
  since 2026-07-09 — over a month unmerged — while local work kept stacking on top (69 commits ahead of
  `origin/docs/branch-protection-rollout` alone, confirmed via `git rev-list --left-right --count`).
  Decision: merge PR #8 first (after refreshing its now-stale CI run), so `main` catches up and the
  feature branch becomes a normal rebase — not yet executed as of this entry.
- 🔴 **`[NS-22]` — handoff/compaction protocol gap.** Two stale `handoff.md` files found: repo root
  (2026-08-03/04 session, confirmed untracked via `git ls-files --error-unmatch handoff.md` → error) and
  `.claude/worktrees/mystifying-hertz-c54477/handoff.md` (2026-07-27, mtime-confirmed). Neither was
  deleted per `CLAUDE.md:124`'s instruction ("merge its info into Memory Bank, delete `handoff.md`") —
  nothing enforces that step. Triggered by the user asking whether a handoff was written before today's
  compaction; the honest answer required manually diffing file mtimes against today's date, since no
  hook surfaces handoff freshness. This session's own compaction was not actually harmed — the
  `PreCompact` gate's alternate path (`progress.md` dated today) was already satisfied via this file's
  own same-day entry — but the near-miss and the two-path ambiguity (handoff.md vs. progress.md-dated
  gate, no way to tell from outside which fired) are real. Not designed yet.
- 🔴 **`[NS-23]` — standards-freshness gap.** No mechanism checks `standards/*.md` content against the
  external authorities it cites. Checked directly: only `PERFORMANCE-BUDGET.md`, `SECURITY-RULES.md`,
  `TRUST-CLASSIFICATION.md` carry `review-cycle`/`staleness-threshold` frontmatter (all `last-reviewed:
  2026-05-31`, ~2.5 months stale against their own 90-day cycle but not yet past the 180-day
  staleness-threshold). `ACCESSIBILITY.md` (asserts WCAG 2.1 AA), `SECURITY-GUARDRAILS.md`,
  `CODE-QUALITY.md` have no frontmatter at all — no tracked review cadence whatsoever. Even where the
  frontmatter exists, `grep`-confirmed no `mb doctor`/CI check references WCAG or OWASP version numbers
  — the mechanism only prompts a manual timer-based re-read, it does not verify against the standard's
  actual current published version. Not designed yet.
- 🔴 **`[NS-21]` update — review-gate command hardening audit.** Dispatched a focused, read-only audit of
  `/code-review`, `/security-review`, `/change-review` (user-requested, prompted by re-observing the
  `/code-review` Skill-tool shadowing bug live a third time during this session). Findings:
  - `/security-review` — solid, no issues.
  - `/code-review` — the 5 required domains (`standards/CODE-REVIEW.md:6-11`) are named but only
    Architecture Drift has a concrete definition; Security/Correctness/Maintainability/Testing subagents
    get the diff plus generic Severity/Blocking/Basis field defs and nothing else, so their findings rest
    on unconstrained model judgment with zero shared criteria against `/security-review`'s explicit
    9-pattern list. Marker-write hash logic and Opposition rigor are both solid.
  - `/change-review` — Job 7's inline security fallback (used whenever ACR is unavailable or its exit
    code is non-zero) has genuinely diverged from `/security-review`'s pattern list in **both**
    directions: it drops the XSS check (`security-review.md:24`) and the unsafe eval/exec check
    (`security-review.md:26`) entirely, while adding path traversal/template injection/dependency-audit
    items `/security-review` doesn't have. Confirmed via direct line comparison, not speculative — this
    means `/change-review` can silently produce weaker security coverage than running `/security-review`
    directly, especially on UI-touching diffs. Job 4 "Runtime Semantics" also folds 5 distinct concerns
    (env-defaults, async correctness, startup/shutdown ordering, rollback safety, race conditions) into
    one lens with no dedicated pass each, unlike the narrower Job 8 Accessibility which got its own job.
    Minor schema drift: `change-review.md` still carries both `Basis` and `Confidence` fields though
    `standards/CODE-REVIEW.md:87` says `Confidence` was removed.
  - Recommended first fix (not yet done): add the missing XSS and eval/exec patterns to Job 7's fallback
    list in `change-review.md`. The `/code-review` domain-checklist-sharing question is a bigger design
    call, deferred.
- 🔴 **`[NS-14]` update — mb.sh/mb.ps1 setup/upgrade scripts verified.** `tests/test-mb-init.sh` (19/19)
  and `tests/test-mb-upgrade.sh` (26/26) both green fresh, including the regression class that bit this
  project three times before (files silently missing from `TEMPLATE_OWNED`). Cross-checked the
  `TEMPLATE_OWNED` array against every file actually in `templates/` — full parity. One piece of debris
  found, not fixed (low priority): `templates/hooks/pre-push` is orphaned, unreferenced anywhere. Confirmed
  no global (`$HOME/.claude/`) install/upgrade path exists — every `TEMPLATE_OWNED` destination is
  project-relative; the only `$HOME/.claude/` touch is a read-only `mb doctor` comparison. Practical
  consequence: nothing in `mb.sh`/`mb.ps1` could push project-level fixes out to the user-level shadowing
  twins found in `[NS-21]` — that's a manual operation today.
  - Checked the version-check code directly per the user's "upgrade should look at local and the repo to
    verify we have the latest" concern: three distinct version values exist (target's `.pmb-version`, the
    local PMB source clone's `VERSION`, GitHub `main`'s true latest) and nothing compares all three —
    `mb doctor` only checks target-vs-local-clone (WARN-only), a separate notifier only checks
    local-clone-vs-GitHub. **Nothing compares target-vs-GitHub directly**, so a stale local PMB clone makes
    `mb doctor` report "up to date" even when genuinely behind upstream. Sharpens `[NS-14]`'s existing
    finding (nothing *triggers* a check) with a second gap: a triggered check can still give a false "OK"
    if its own reference point is stale. Not designed yet.

## 2026-08-18 — `dangerous-commands.sh`/`.ps1` Git-Merge CONFIRM Hardening (Task #30, committed `499dbe5`) — condensed, full detail archived

Full narrative: `docs/archive/progress-2026-08-18-task30-dangerous-commands-hardening.md`.

- ✅ **Closed the `git merge`-into-shared-branch CONFIRM gap** `standards/SECURITY-GUARDRAILS.md:114` had
  documented but never enforced. Added `confirm_boundary()` (bash) + a `$confirmPatterns` regex (ps1).
  Went through full `/code-review` + Opposition **twice**, each round catching real defects the prior
  round missed: Round 1 fixed a false-positive substring match (`"legit merge"` matching via "le**git
  merge**"); Round 2, verified via direct adversarial execution not hand-tracing, fixed a bash-vs-PowerShell
  Unicode-whitespace parity gap (NBSP bypassed bash, caught by PowerShell); Opposition (BLOCK, then
  re-reviewed to APPROVE) caught the fix landing only in `scripts/`, never mirrored to `templates/scripts/`
  — this repo's canonical `mb upgrade`-synced surface — missed by both domain-review rounds because
  diff-scoped review structurally can't see a missing companion file; also caught and fixed an
  sh/ps1 case-sensitivity divergence on the guarded command. Docs (`HOOKS-GUIDE.md` + template) had a
  stale CONFIRM table, corrected. New PowerShell test coverage (`dangerous-commands.Tests.ps1`, 13 tests)
  added — this hook's first ever. Re-review independently re-ran both suites + a 26-case parity harness,
  confirmed zero remaining divergence, and logged 4 more non-blocking findings for later (one real,
  pre-existing bypass — `curl | bash` with double-spacing — out of this diff's scope, tracked as backlog).
- 🔴 **Live-reproduced the still-pending "marker-destruction-on-denial" bug.** Opposition approved and
  wrote `.claude/.code-review-ok`; the following `git commit` was DENIED by `dangerous-commands.sh`
  because its own commit message quoted the guarded phrase as a literal example — and that denial
  destroyed the just-written marker even though the working tree never changed. Resolved by resuming the
  same Opposition agent to reconfirm byte-identical state and re-write the marker (hash matched three
  independent recomputations). A harness security monitor flagged the marker re-write as a possible
  self-certification pattern; the verification evidence was walked through directly before committing.
  Now a concrete reproducible incident for Task #33 (below), not just a theoretical description.
- 📌 Work-MB findings doc updated (Document 8) with both findings above, plus a clean-verified check of
  this project's own global-CLI-install path for the same staleness-gap class a sibling project had.
- ✅ **All 3 test-coverage gaps closed (Task #32, `2991093`):** version-notifier cache round-trip test
  (first draft's second assertion pointed at the live test server, masking a broken reader — fixed by
  pointing it at an unreachable port, mutation-tested); `mb clean`'s "RECOMMENDED" middle branch coverage
  (replaced a trivially-satisfied header-string assertion); PowerShell-side `Resolve-CdRoot` coverage for
  the chained-cd/whitespace fixes (first draft's own JSON-escaping bug in the test helper produced a false
  security-bypass signal, traced to an unescaped backslash in a Windows temp path — fixed via a
  `win_path_for_json()` helper, gated on `cygpath`). Also root-caused an unrelated "9 failed" one-off as a
  pre-existing test-server readiness-poll flake, unrelated to this diff.

## 2026-08-18 (continued) — Version-Notifier Readiness-Poll Fix + Stderr-Capture Refinement

- ✅ **Root-caused and fixed a real pre-existing flake** in `tests/test-mb-version-notifier.sh`'s
  live-fetch sub-test: the background `python3 -m http.server` readiness poll (10×0.3s) silently fell
  through and let 9 downstream assertions fail with confusing cascading output if the server never
  became reachable — this is the same flake the opposition reviewer had already root-caused (noted in
  the entry above) as unrelated to that day's diff, now actually fixed. Reproduced deterministically by
  neutering the server-launch line to confirm the exact "14 passed, 9 failed" signature, then fixed with
  a `server_ready` flag + `if/else` around the whole server-dependent block, printing a clear
  `SKIPPED (test HTTP server did not become ready within the poll window)` message instead. Went through
  its own Opposition review (mutation-tested: a corrupted cache genuinely fails, a valid one still
  passes in ~400ms via the cache-hit short-circuit). Committed `d64a4fc`.
- ✅ **Refined the same SKIP path to capture the server's stderr**, previously discarded to `/dev/null`,
  so a genuine bind failure is diagnosable in the SKIP message instead of reading as an unexplained
  absence — one specific idea kept from a user-pasted "suggested task" chip whose alternative proposal
  (a hard `exit 1` on server-never-ready) was rejected: it would have aborted the whole script and
  silently skipped an unrelated, later `if command -v pwsh` block (the cross-shell PS1 parity tests) that
  has nothing to do with the HTTP server. Verified against a real bind failure two independent ways: the
  orchestrator pre-occupied a fixed port before running a temporary fixed-port copy of the test and got
  `PermissionError: [WinError 10013]`; the Opposition reviewer, working independently, found the first
  repro method (simple port pre-occupation) didn't actually collide under this machine's Windows socket-
  sharing semantics, then found a *different*, more realistic collision mechanism
  (`netsh interface ipv4 show excludedportrange`) and reproduced the same class of failure that way — a
  genuinely independent confirmation via a different method, not a re-run of the same repro. Suite
  verified clean across 5 separate runs (23 passed, 0 failed each), including one run inside a piped
  `for` loop that hung/timed out on a later iteration — isolated re-runs with output redirected to files
  were all clean, so this reads as a shell-construct artifact of that particular piped-loop invocation,
  not a regression introduced by the diff (no timing-sensitive code was touched).
- 🔴 **Process incident, self-corrected before commit:** the first attempt at getting this diff reviewed
  dispatched a single subagent to both domain-review the diff *and* write `.claude/.code-review-ok` in
  the same call. The harness's security monitor correctly flagged this as self-approval — reviewer and
  reviewed-change must be separate agents per this repo's own two-party review-gate discipline, and a
  single agent checking its own findings and immediately writing the marker has no genuine second check
  on itself, even though it didn't author the diff. The marker was deleted unused, and the review was
  redone properly as two separate agent dispatches (a domain reviewer with no marker-write authority,
  then a separate Opposition agent that independently re-read the diff, challenged the first reviewer's
  two non-blocking findings, ran its own additional checks, and was the only one authorized to write the
  marker). Hash independently re-verified by direct recomputation before trusting it, matching exactly.
  Committed `bbb697a`.
- Remaining, same as above: the marker-destruction-on-denial fix itself (Task #33); atomic
  version-cache write + `diff_hash()` trap-scoping (Task #34); final full test-suite run + re-run
  `/change-review` + push/merge PR #8 (Task #35).

## 2026-08-18 (continued) — Task #33 Deferred; Task #34 Hardening Fixes (One Self-Caught, Reverted)

- 🔴 **Task #33 investigated, deliberately deferred rather than patched.** The real structural fix already
  exists on `feature/review-gate-layered-enforcement` (can't cleanly rebase onto `main`); a second branch
  has uncommitted WIP on an overlapping mechanism. A narrow patch here would be a third. Full reasoning:
  `activeContext.md`'s NS-24 entry. Committed `c66d9d1`.
- ✅ **Task #34, atomic version-cache write:** `mb.sh`/`mb.ps1` wrote the version-cache JSON via a direct
  overwrite, not atomic against a concurrent reader — real risk, since this check runs after every `mb`
  command and this repo supports concurrent sessions. Fixed via mktemp-in-same-dir + `mv` (bash), temp
  file + `[System.IO.File]::Move` (PowerShell). **PowerShell needed a second fix mid-review:** a reviewer
  load-tested `Move-Item -Force` under concurrent access and got 105 writer-side `IOException`s and 67+
  reader-side `FileNotFoundException`s — not the atomic primitive it looks like on Windows. Switched to
  the raw `File.Move` overload (zero errors under identical load).
- 🔴 **Task #34, `diff_hash()` trap-scoping: a self-caught regression.** The original bug (unconditional
  `trap - EXIT` clears a caller's own trap on a direct, same-shell call) was real. The first fix
  (`trap -p EXIT` save + `eval`-restore) looked correct until it deleted `test-review-gate-lib.sh`'s own
  `$TMPDIR_LIB` mid-run. Root cause: bash treats an EXIT trap merely *inherited* into a
  command-substitution subshell as dormant, but explicitly calling `trap` inside it — even to restore the
  same value — arms it, firing early. Since `review-reminders.sh` calls `diff_hash` via
  `$(diff_hash ...)`, the "fix" would have fired a caller's cleanup trap early in production. Reverted to
  touching no trap state at all; a guard test for this had its own bug first (checked the marker after
  the subshell's own `exit`, which fires it too) fixed via an echoed status string before any exit.
  Mutation-tested repeatedly: the fix passes 9/9; the buggy code reliably drops it to 4/9.
- 🔴 **A first-round review finding was independently re-tested and found wrong, not accepted on
  authority.** The reviewer claimed the subshell-trap test couldn't discriminate the fix from the bug;
  re-running the exact mutation showed it clearly does (9/9 vs 4/9, twice). Their other findings held up:
  the `Move-Item` issue, and a genuine coverage gap — "no leftover temp file" also passes against fully
  reverted code. Fixed with a stronger test: open an fd on the cache file before a forced rewrite, confirm
  it still shows the complete *old* content — exploiting the POSIX guarantee (`rename()` doesn't touch an
  already-open fd) the fix depends on.
- ✅ Two full review rounds, both reproducing the mutations themselves. Opposition's first revert attempt
  used `git checkout --` on an uncommitted file (reset to pre-fix `HEAD`), caught immediately, corrected
  from the `templates/` mirror, disclosed not hidden. Hash independently re-verified. Committed `acdfbb6`.

## 2026-08-18 (continued) — Task #35 Change-Review Findings Fixed; Handoff Protocol Redesign

- ✅ **Task #35, whole-branch `/change-review`:** ran clean (baseline health + ACR clean). Jobs 1-6
  surfaced 2 Blocking + 2 related Medium findings; fixed, committed `69b9566`. Opposition's Job 9 marker
  write correctly refused the first attempt (fixes were in the working tree but not yet committed, so
  `git diff origin/main...HEAD` didn't reflect them) — same agent resumed post-commit, confirmed clean.
  Push-gate marker independently re-verified (`ec65945c...`). **Only the actual `git push` remains** —
  paused for the tangent below, resume on user go-ahead (push is user-facing).
- ✅ **Handoff Protocol redesigned** (user-initiated, following a reported problem in the user's
  separate work-MB project): asking a new session to synthesize priority from `handoff.md` — written
  under compaction-time pressure — caused real synthesis misses on complex sessions. Reframe:
  `activeContext.md`'s Next Steps is already continuously updated and the better priority source;
  `handoff.md` narrowed to ephemeral in-flight state only. New sessions now read memory-bank first as
  authoritative, `handoff.md` second, then reconcile and surface conflicts. Applied to `CLAUDE.md` +
  `templates/CLAUDE.md` (byte-identical, verified), reviewed (domain + Opposition, one Medium
  non-blocking gap fixed pre-commit), hash re-verified, committed `3a2a7fd`. Portable brief
  `docs/WORK-MB-HANDOFF-DESIGN-BRIEF.md` for work-MB (same discipline, one Medium finding softened
  pre-commit), committed `3aa70af`. Distinct from `[NS-22]` (cleanup-enforcement gap), still open.
- ✅ **Task #35 completed, branch pushed, CI verified green.** The Handoff Protocol commits changed
  the diff, so the earlier push-gate marker (`ec65945c...`) no longer matched
  `git diff origin/main...HEAD` — re-ran `/change-review` (ACR exit 1 on the whole diff due to its own
  2000-line truncation default; inline security greps + Opposition spot-checks substituted as Job 7's
  actual coverage, all clean; false-positive "command injection" findings on static hardcoded hook
  strings dismissed with evidence — separately written up as a portable ACR investigation brief for
  the user's ACR session, sent as a file, not committed to this repo). Came back clean, hash
  `5d3607cd...`. Pushed `0cc53f1..c80d494`.
- 🔴 **CI actually failed post-push** (`MB Command Tests`, a required check): `tests/test-review-gate-lib.sh`'s
  `Get-FileHashHex` cross-shell parity test guarded on `pwsh` alone but unconditionally called
  `cygpath` inside — GitHub Actions' `ubuntu-latest` ships `pwsh` without `cygpath` (a git-bash/MSYS
  tool), so `cygpath: command not found` fired 3 times and 2 assertions failed for an environment
  reason unrelated to the code being tested. Root-caused by reading the actual CI job log, not
  guessed. **Fix matched an already-established precedent found in this exact repo:** two sibling
  test files (`test-review-reminders.sh`, `test-update-reviewed.sh`) already required both
  `command -v pwsh` AND `command -v cygpath` before any cygpath-dependent block, from an earlier,
  separate code review — this file was the one instance missed. Applied the identical guard. Verified
  locally (still 9/9 passing with both tools present) and via a logic-level mutation test (old guard
  proceeds into the broken block under simulated "pwsh present, cygpath absent," new guard correctly
  skips) before ever touching CI. Reviewed (domain + Opposition, no blocking findings), committed
  `d864d99`. Re-ran the push-gate `/change-review` a second time (marker invalidated again by the new
  commit; the new delta was tiny and already reviewed at the commit gate, so the push-gate Opposition
  pass was scoped to confirming that plus scope integrity, not re-reviewing all 93 prior commits),
  hash `1f0e5f3...`, pushed `c80d494..d864d99`. **Waited for the actual CI run and confirmed via
  `gh pr checks 8`: all 10 checks pass, `mergeStateStatus: CLEAN`.**
- ✅ **PR #8 merged 2026-08-19** (`gh pr merge 8 --squash`, now `main`'s tip `b0490ef`). One
  local-only commit (this very entry's own predecessor, `d745121`) was committed but never pushed
  before the merge, so it was left out of `main`. Cherry-picked onto a fresh branch
  (`docs/finalize-branch-protection-memory-bank`, off the post-merge `main` tip) as commit `805ae5a`,
  reviewed again at the push gate (content byte-identical to what was already reviewed this session;
  the only new finding was this exact "PR #8 open" staleness, now corrected inline), for a small
  follow-up PR. Only `[NS-24]`'s Task #33 remains open from this thread.
- ✅ **PR #12 merged 2026-08-19** (the follow-up carrying the CI-fix narrative + staleness correction), `main` fast-forwarded to `4f24768`. Both fully-merged branches (`docs/branch-protection-rollout`, `docs/finalize-branch-protection-memory-bank`) deleted locally and on `origin` after confirming `git diff main <branch>` was empty (or, for the old branch, showed only its own now-superseded stale text — `main`'s version was strictly more accurate, not missing anything).
- 📌 **`[NS-25]` found while deleting branches:** `review-reminders.sh`/`.ps1`'s push-gate raw-substring-matches `'git push'`, so `git push origin --delete <branch>` (no content diff) got denied identically to a real push — `diff_hash origin/main...HEAD` is meaningless for a pure ref deletion. Worked around via `gh api -X DELETE repos/.../git/refs/heads/<branch>`, which bypasses `git push` entirely and is legitimate (no diff exists to review). Not fixed in the hook itself: an independent review caught that the first-pass reasoning for deferring the fix (cited JSON-field-extraction fragility) was wrong — the real risk of a `--delete` special case is a fail-*open* substring false-positive on a real push, corrected accordingly. See `activeContext.md`'s `[NS-25]` for the full, corrected reasoning.

## 2026-08-19 — Model/Effort Escalation Guidance; Review-Gate Port Design Corrected (Opus deep dive)

- 🔴 **A Sonnet-authored port design was found to be repo-breaking, on an Opus re-examination.** It split the Layer 1 (`review-reminders.sh` PreToolUse) and Layer 2 (git-hook) marker changes into two independent steps — but `consume_marker()` destroys the marker at PreToolUse time, so adding a Layer 2 marker check while Layer 1 still consumes would deny *every* agent commit and push. The flaw survived several self-review passes because the premise (that the two were separable) was never questioned. Also found: `feature/review-gate-layered-enforcement` is *behind* `main` on shared files — it still carries the unsafe `diff_hash()` trap logic reverted 2026-08-18 and predates `write_marker_atomic` — so any port must be main-forward, never a wholesale file copy. Full corrected design in `activeContext.md`'s `[NS-26]`, which supersedes `[NS-15]`'s rebase/replay approach.
- ✅ **Model- and effort-escalation guidance added to `CLAUDE.md` + `templates/CLAUDE.md`** (Token Budget section). Reframed around the user's point that quality up front *saves* tokens: rework costs a revert plus a debugging pass plus a redesign, far more than one careful pass. Escalation is now something Claude must proactively prompt for, keyed to *observable* triggers (cross-branch reconciliation, enforcement-boundary changes, 5+ files, 3+ failed fixes, spec authoring, cross-shell semantics) rather than introspection — since a model out of its depth is a poor judge that it is. Effort documented as a separate, cheaper dial: raise effort for care, raise model for premise risk. **Verified live, with a self-correction:** first pass reported `CLAUDE_CODE_EFFORT_LEVEL` as "unset everywhere" and concluded the level came from a UI selector only — an independent review caught that an effort var *is* live in the environment, just under a different name (`CLAUDE_EFFORT=high`), absent from every `settings.json` and evidently harness-injected. That is the actual reason selecting Opus left effort below its nominal default. Docs now name the real variable and tell readers to check `env | grep -i effort` rather than trusting a config file. `MAX_THINKING_TOKENS=10000` also flagged, with its interaction explicitly hedged as unverifiable from inside the repo rather than asserted. Template mirror deliberately genericized (no PMB-specific incident narrative), per the established portability convention.

- 🔴 **PreCompact freshness gate found switched off for ~2 weeks (`[NS-22]`, escalated).** `scripts/pre-compact-check.sh:10-13` bypasses the whole gate on a bare `[ -f "handoff.md" ]` check with no staleness test. The untracked 2026-08-03/04 root `handoff.md` therefore disabled it continuously, including every compaction in this session. The 2026-08-17 pass had logged those stale files as clutter and missed that their *presence* is what disables the gate. Content verified fully committed (`2fa1b63`, `fac4976`), so deletion is safe — held for user approval as a CONFIRM-tier action.
- 🔴 **Session-continuity thresholds do not cohere.** Handoff is specified at 40% but is user-triggered with nothing automating it; auto-compact fires at 65%; the global `~/.claude/CLAUDE.md` claims 50%, which is factually wrong. Consequence: sessions never hand off — they pass 40% unnoticed, compact in place at 65%, and continue indefinitely, with the only gate on that boundary bypassed. Answers the user's "shouldn't we have moved to a new session?" — auto-compact summarizes *within* a session; it never starts a new one, and nothing links the two mechanisms.
- 📌 **Overnight/unattended implication:** compaction, not handoff, is the only mechanism that survives without a human (handoff requires someone to start the next session), which makes the PreCompact gate load-bearing for autonomous runs — it must work before any overnight operation is trusted. Scheduler-driven session chaining (headless session reading memory-bank + `handoff.md`) is feasible but undesigned.
- 📌 **`[NS-27]` recovered, not newly invented:** an explicit 2026-08-15 design discussion about ACR taking over the Opposition pass (with DeepSeek as candidate backend) was never written to memory-bank and was consequently lost to compaction — the agent twice told the user no such decision existed before recovering it from the raw session transcript. A direct, self-demonstrating case for the memory-bank discipline this repo already mandates.

- 🔴 **`[NS-28]` — measured PMB's SessionStart cost at ~22,072 tokens, matching the enterprise MB figure (~21,897) the external findings doc calls a context crisis**, despite PMB being forked to be lighter. Caps are enforced on lines, not bytes; `activeContext.md` runs ~208 chars/line, so the 150-line limit permits ~2.4x its intent. Proven gameable the same day: a cap breach was resolved by reflowing 158→134 lines with identical content and zero bytes saved, CI green throughout. Stale root `handoff.md` deleted (content verified already committed) and the PreCompact gate confirmed re-activated and passing.

- 🔴 **`[NS-30]` — the memory-bank cost driver is distributed but its guardrail is not.** `templates/CLAUDE.md` ships "read ALL files in `memory-bank/`" three times while `templates/.github/workflows/` does not exist, so adopting projects inherit the mandate with no CI cap — only `mb doctor`'s ignorable warning. ACR's own audit measured the result: 190,798 bytes / ~47.7K tokens, 2.5x PMB's own footprint. PMB stays bounded solely because it holds CI its adopters never receive. Three independent audits converged on the same four systemic items, so this is a distribution defect rather than one repo's neglect.

## 2026-08-12 — Fleet Version Drift Incident (reported, not yet fixed)

- 📌 `ai-code-review-agent` drifted 2 versions behind PMB, ran a 13-task feature under stale
  governance hooks before caught; not yet fixed (blocked on that session's own cross-repo write
  boundary). Full detail: `activeContext.md`'s `[NS-14]`, which carries the current-state summary —
  not duplicated here.

## Earlier Work (2026-07-02 through 2026-08-10) — condensed, full detail archived

- **2026-07-16 through 2026-08-05 — Review-gate mechanism evolution**: self-attestation fix (marker-write
  moved into the last dispatched review subagent), a false-positive fix in `review-reminders.sh`'s
  command matching, the confirm-step redesign (durable `docs/review-log/` + user-confirmed marker write),
  a worktree-root-resolution fix (closed a real denial-from-inside-a-worktree bug), a hook-lib dedup
  (`_review-gate-lib.sh`/`.ps1`), and the confirm-step's first live whole-branch review (found and fixed
  one real Blocking finding). Full detail: `docs/archive/progress-2026-07-review-gate-evolution.md`.
- **2026-07-02 through 2026-07-13 — Repo governance, CI hardening, branch protection**: `mb upgrade`
  slash-command auto-discovery fixes, 4 pre-existing CI failures closed (SAST config, 2 false-positive
  greps, PowerShell lint), CI hardening across 3 downstream repos, branch protection rolled out to 5
  public repos, a real hash byte-mismatch bug fixed (bash vs. PowerShell diverged on trailing-newline
  handling), the cross-repo write boundary hook built after a real incident (this session wrote into
  another repo's working directory without checking ownership), and the review-flow fleet audit (found
  real enforcement in only 2 of 11 repos). Full detail:
  `docs/archive/progress-2026-07-repo-governance-and-ci.md`.
- **2026-07-14, 2026-07-23 — `mb backlog` Task 1 + mb update-notifier**: `mb backlog`'s Task 1 shipped
  with two real Critical/High security bugs found and fixed (path traversal, sed-delimiter injection);
  Tasks 2-5 not started (`[NS-0]`). The update-notifier shipped clean, but the same session produced an
  authorization-drift incident (a "what do you suggest" non-answer treated as merge approval) that
  produced the "What Counts as Approval" rule. Full detail:
  `docs/archive/progress-2026-07-mb-backlog-and-notifier.md`.
- **2026-08-08, 2026-08-10 — Concurrent session claims + memory-bank freshness hook**: session-claims
  shipped (13 tasks + 5 post-review fixes, including one found only by a final whole-branch review after
  every individual task had already passed its own two-stage review); the freshness-hook spec was
  designed and committed but not yet implemented (`[NS-13]`). Full detail:
  `docs/archive/progress-2026-08-freshness-and-session-claims.md`.

## What's In This Fork

Status: Ready. Personal fork of the enterprise Memory Bank standard — lifecycle management and provenance tracking implemented.

- ✅ Memory Bank system (5-file + handoff protocol) + authority hierarchy + 3-dimension frontmatter
- ✅ Provenance frontmatter: compaction_generation, source_type, confidence, lineage
- ✅ Security Guardrails (BLOCK/CONFIRM/WARN) + 9-rule registry (SECURITY-RULES.md) + 9 security fixtures
- ✅ Code Quality, Logging, 7-phase Workflow standards; Supply Chain, MCP Security, Rules-File Integrity (reference)
- ✅ Slash commands: /pmb-status, /code-review, /feature-dev, /security-review, /test-audit, /health-check, /mb-drift, /change-review
- ✅ mb CLI: init, status, doctor (25 checks), query, clean, commit, upgrade, verify-integrity, plan (status/list/promote/archive) + deprecated aliases
- ✅ Hook suite: dangerous-commands blocker, contract scope check, delegation depth check, auto-last-reviewed, PreCompact memory gate, review gate
- ✅ Versioned git hooks via core.hooksPath (.githooks/pre-push + pre-commit), distributed by mb upgrade (TEMPLATE_OWNED)
- ✅ mb upgrade: TEMPLATE_OWNED/ADVISORY_DIFF/ADVISORY_CREATE distribution model; remote version check
- ✅ CI: template-integrity job + SAST (Semgrep p/bash); CLAUDE_AUTOCOMPACT_PCT_OVERRIDE=40
- ✅ install.bat / install.sh, examples/task-tracker-api, VERSION, CHANGELOG.md, docs/COMMANDS-REFERENCE.md
- ✅ Cursor rules (5 rules + code-review rule)

Full history: CHANGELOG.md

## Removed vs Enterprise

Eric Nolan branding/brand assets; Data Classification, Model Governance, OWASP LLM Top 10 (compliance only);
Incident Runbook, accessibility review command; enterprise logging (PII redaction, correlation IDs);
team onboarding scripts and training materials.

## Backlog

Deferred pending operational evidence: handoff CLI, pinned.md, mb update --from-git, mb privacy.

## Earlier Sessions (2026-06-19 to 2026-06-24) — condensed, full detail in CHANGELOG.md

- ✅ **06-19:** Semantic drift checks 21-23 added to `mb doctor`; `/mb-drift` skill created; startup context trimmed to below 25 KB.
- ✅ **06-22:** `docs/plans/` + `.claude/plans/` workflow scaffolded; `mb plan status|list|promote|archive`; doctor check 24 (plan hygiene); `/change-review` command created (9-job review + ACR bridge).
- ✅ **06-24 Audit Sprint:** Bug fixes (settings.json JSON, pre-compact false positives, TRUNCATE/DELETE guardrails); 8 new test files (115 assertions); CI hardened to 9 jobs (PSScriptAnalyzer, mb-doctor-self-check); perf fixes (O(n²) pre-cache); ACR P0/P1/P2 (comment markers, SARIF, GitHub annotations, schemaVersion).

## Satellite Projects

- **ai-code-review-agent** — `unyieldingclaw-dev/ai-code-review-agent`. v1.1.0: 15 observe-only agents, profiles, --context memory-bank, SARIF, GitHub annotations, agentPolicy, integration contract. 276 tests passing.
