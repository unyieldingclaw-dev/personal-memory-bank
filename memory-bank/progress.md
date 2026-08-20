---
authority: accumulating
review-cycle: 30d
retention: archive-after-6m
staleness-threshold: 90d
tags: [work/completed, work/in-progress, work/backlog]
last-reviewed: 2026-08-20
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
