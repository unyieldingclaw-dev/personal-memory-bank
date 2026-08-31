---
authority: accumulating
review-cycle: 30d
retention: archive-after-6m
staleness-threshold: 90d
tags: [work/completed, work/in-progress, work/backlog]
last-reviewed: 2026-08-29
compaction_generation: 0
source_type: canonical
confidence: high
lineage: []
---

# Progress

## Relocated 2026-08-12 → 2026-08-18 — five sections moved verbatim 2026-08-28

Moved to `docs/archive/progress-2026-08-condensed-sections.md` to clear the 60,000-byte CI cap; this
file had reached it and could not accept a new dated entry. **12,965 bytes moved out, 1,490 added
back as this stub — net −11,475.** Stated as a delta rather than before/after totals, which decay the
moment anything else in the file changes. **Nothing was summarised or deleted** — the 2026-08-25 pass was reverted for removing content, and this follows the
relocate-verbatim convention that replaced it.

Each original heading is preserved below so existing citations of the form "`progress.md`'s
2026-08-14 entry" still resolve. All five were already marked *condensed, full detail archived*
before this move, so their fuller narrative was already in `docs/archive/context-2026-*`; this
relocation moves the condensed layer out as well.

- 2026-08-12 through 2026-08-14 — Investigation-Integrity Mechanism: Design, 5 Independent Review Rounds, Stale-Marker Hook — condensed, full detail archived
- 2026-08-17 — Review-Gate Layered Enforcement: All 14 Tasks Implemented and Committed — condensed, full detail archived
- 2026-08-17 (continued) — Branch-Ancestry Diagnosis, Handoff/Compaction Gap, Standards-Freshness Gap, Review-Gate Hardening Audit — condensed, full detail archived
- 2026-08-18 — `dangerous-commands.sh`/`.ps1` Git-Merge CONFIRM Hardening (Task #30, committed `499dbe5`) — condensed, full detail archived
- 2026-08-18 (continued) — Tasks #33–#35, Version-Notifier Fix, Handoff Redesign — condensed, full detail archived

## Relocated 2026-08-19 → 2026-08-21 — four sections moved verbatim 2026-08-28

Moved to `docs/archive/progress-2026-08-19-to-21-escalation-and-bundle-1.md` **verbatim**, not
summarised. **Delta, not a level: 16,670 bytes moved out.** Citation survival grep-verified before
the move. The citation surface is larger than a short list captures — `activeContext.md` alone
carries five references to these entries, enumerated in full in the archive header — so the check
that matters is that each original heading is preserved below, which it is.

- **2026-08-19 — Model/Effort Escalation Guidance; Review-Gate Port Design Corrected (Opus deep dive)**
- **2026-08-20 — Archive Pass; Session-Crossed-Midnight Dating Error Caught by the Gate It Broke**
- **2026-08-20 (continued) — Enforcement Integrity Bundle 1 (committed 2026-08-21 as `4bc107c`)**
- **2026-08-21 — Bundle 1 Committed; Hook-Wiring Fix Withdrawn by Its Own Review**

## Relocated 2026-08-22 → 2026-08-27 — six sections moved verbatim 2026-08-30

Moved to `docs/archive/progress-2026-08-22-to-27-gate-passes-and-bundle-review.md` **verbatim**, not summarised. **Delta, not a level: 20452 bytes moved out.**
Citation survival grep-verified before the move; each original heading is preserved below and in
the archive file, so existing `progress.md` <date> references still resolve.

- **2026-08-26 — PR #21: round-10 gate pass, Approve + 4 must-fixes**
- **2026-08-26 (continued) — `[NS-37]` closed at the mechanism; a measured perf revert; cap deadlock resolved by relocation**
- **2026-08-26 (later) — review-gate model pinning; `mb upgrade` agent-delivery fix; tiered-loading design DROPPED on review**
- **2026-08-27 — Full `/code-review` of the five-concern bundle; 24 findings remediated; three new mechanism bugs**
- **2026-08-23 (continued) — Cap Deadlock Cleared by Relocation; Round-6 Pre-Gate Hardening**
- **2026-08-22 — Commit-Signing CONFIRM Tier; Two Review-Driven Corrections; Midnight Gate-Expiry Found**

## Relocated 2026-08-28 — five sections moved verbatim 2026-08-31

Moved to `docs/archive/progress-2026-08-28-round3-gate-passes-and-brief-staleness.md` **verbatim**, not summarised. **Delta, not a level: 30448 bytes moved out.**
Citation survival grep-verified before the move; each original heading is preserved below and in
the archive file, so existing `progress.md` <date> references still resolve.

- **2026-08-28 — `[NS-22]` committed; Cursor's handoff threshold re-derived; `[NS-22]` action 3 closed as not-a-defect**
- **2026-08-28 (later) — `d550282` committed; branch `/change-review` run; the nine-instance pattern named**
- **2026-08-28 (continued) — Round-3 pass, Opposition Approve, committed `2052c3c`**
- **2026-08-28 (fix) — `mb init` agent delivery closed; the exported Work-MB briefs found stale**
- **2026-08-28 (eviction) — `activeContext.md` resolved-entry pass; its own finding was false**

## 2026-08-31 — what four Opposition rounds cost, and the one rule worth keeping

Detail is in `11ec83b` and `e1d77f2`. Only what a commit message cannot carry:

- **Overcorrecting in the self-critical direction is its own false record.** A confession is a claim
  and takes the same evidence as any other. The BOM finding was recorded WRONG THREE TIMES: as a
  bypass (reproduced with a malformed hybrid), then as a regression I had introduced, then as an
  effect unrelated to the setting. An 8-case byte matrix settled it; each wrong version was asserted
  from a proxy rather than measured, **including the self-critical one**, which is the version that
  reads as rigour and therefore gets challenged least. ACR recorded the same rule independently after
  their own memory bank carried my wrong version for hours because they believed my self-criticism.
- **Review-by-reading produced nothing this session; review-by-breaking-something-adjacent produced
  everything.** Five domain agents plus two Opposition rounds passed a diff containing a
  space-splitting bypass of a required check. Four separate "checks that cannot fail" were found only
  by mutating the code they guarded. The BOM error surfaced only from writing the test meant to
  confirm the fix. Nothing was found by re-reading.
- **A fix that reaches one sibling and not the other is the recurring mechanism here, not a series of
  incidents.** Three instances in one file family this session: `ceil_region` → `region_claude`;
  `region_claude` fixed for `mb.sh` but not `pmb-health.yml`; `1,116` correct in PMB's repo and wrong
  in the template. Worth treating as a class when reviewing any two-copy change.
- **Cross-session:** ACR (`ai-code-review-agent`) and this repo ran a full day of paired review. Their
  findings against PMB and mine against ACR are recorded in each other's banks as *peer-reported, not
  reproduced locally*. That labelling is deliberate and should be preserved — it is what let both
  sides correct a wrong claim without it hardening into either record.

- **The six remaining Work-MB exports refreshed 2026-08-31; three verified claims came out of it.**
  (a) `030662c` shipped **four of the six** recommendations in
  `WORK-MB-ENFORCEMENT-INTEGRITY-VERIFICATION-AND-DESIGN.md`, whose header still read "nothing
  implemented" — including its self-described core fix, the three-state result model (`DEGRADED` is
  live in both `pre-push-check.{sh,ps1}`). Template hashing and a `SessionStart` staleness hook did
  NOT land (searched `scripts/*.{sh,ps1}` and `.claude/settings.json`; not searched: unmerged
  branches). (b) The handoff brief's "four surfaces still carry the superseded protocol" claim is
  **still true 11 days on** — `templates/AGENTS.md:61,65`, both `.cursor/rules/memory-bank.mdc`
  copies, `templates/memory-bank/README.md:37`. The corrected protocol reached the surfaces a Claude
  Code session reads and stopped at the ones other tools read. (c) `docs/MEMORY-BANK-REDESIGN-VALIDATION.md`
  **still does not exist**, so D1-D4 still has no written home anywhere.
- **The inbound MB testing overview predicted two defects PMB later hit independently — worth the
  reciprocity.** Its 2026-08-22 §9.3.2 recommended a `cursor-parity` drift gate; PMB built parity
  gating of that class for `standards/` and thresholds and never for `.cursor/rules/`, which is
  exactly the gap (b) above measures. Its §9.3.5 recommended SHA **scope** tests on the review marker;
  PMB reached `[NS-41]` (a marker can attest to an EMPTY diff) from the other direction five days
  later. **A peer's recommendation that we declined is now a measured cost, twice.** That document is
  inbound and its body was annotated, not edited — preserve that distinction.

- **`[NS-35]` condensed 5,822->1,860 B; `[NS-46]` added** (global-vs-project arbitration, untracked until now because the file was at its cap).
  `activeContext.md`: **3 bytes** of headroom -> 3,965. **The recovery came from a human overriding the eviction criteria on an ACTIVE entry, not
  from the mechanism** — the seven entries actually marked resolved total 2,131 B even if deleted outright. `[NS-44]`'s §5 finding survives intact.
- **The condensation exposed a false claim I had shipped hours earlier.** `[NS-35]` decision 1 (tiered loading) was **DESIGNED, Opposition-reviewed
  and DROPPED 2026-08-26** on six blocking findings — the index does not fit (~117 B/item available vs 198 measured) and its scope self-reverted via
  `TEMPLATE_OWNED`. Both `[NS-35]` and the paradigm review still carried the PRE-DROP framing, so Document 14 of today's Work-MB brief asserted "a
  porting problem, not a design problem" — the exact belief Opposition falsified. Corrected in both. **A tracking entry is not a substitute for the
  record it summarises**, and a summary written before a reversal looks identical to one written after.
- **`progress.md` relocation ran 2026-08-31 at 499/500 lines** — one line of headroom against a `PreCompact` hook that
  *requires* a dated entry, i.e. a mandated write the cap forbade. Five 2026-08-28 sections moved verbatim (30,448 B,
  213 lines); file went 499->**298** lines and 53,662->**24,153** B. Byte accounting reconciles exactly: 30,448 out,
  29,509 net, 939 B pointer block. Four dated sub-references verified resolving in BOTH the pointer and the archive.
- **Measured effect on the thing that actually matters:** startup context (CLAUDE.md + the five files) fell from
  **110.5 KB to 84.7 KB** — still **3.4x** check 15's 25 KB ERROR, but the ratchet delta vs `origin/main` improved
  from -5,139 to **-37,461**. Note what did the work: **relocation and one hand-condensed active entry, not eviction.**
- **`[NS-47]` + Work-MB Document 16 written from an external survey (Codex, ai-that-works, OmniRoute), doc-level only,
  nothing installed or reproduced.** The finding that reframes `[NS-46]`: **Codex runs TWO precedence systems in
  OPPOSITE directions on purpose** — prose (`AGENTS.md`) is positional, most-local-wins, so project beats global;
  policy (`config.toml`/`requirements.toml`) is layered, managed-wins, MDM > cloud layers > system requirements >
  user/project. **PMB has ONE file type carrying BOTH at two scopes under one asserted rule**, so guidance and
  guardrails get identical precedence when they want opposite ones. The stale-constant incident was not a check that
  escaped — it was policy routed through a channel whose precedence was designed for guidance. **Fix the split
  before writing an arbitration rule.** Honest limit found in the same docs: managed config sets startup DEFAULTS and
  a user may change them mid-run; only `allow_managed_hooks_only` is hard. That distinction IS the compliance claim.
- **Decaying-Resolution Memory names what this repo already does by hand** — resolution decays, the memory does not,
  which is why it survives the objection that killed Lumina's time-decay. Today's `[NS-35]` condensation and the
  relocate-verbatim-plus-pointer archive are both DRM performed reactively at cap-breach. **Adopt it only on the READ
  path** — full resolution stays on disk forever, only what is LOADED loses detail; DRM's summarise-the-store variant
  is the ACE/SSGM degradation this repo already reverted a pass for. **OmniRoute REJECTED, and the SECOND instance of
  its class** (SwitchYard was first): a routing gateway needs a request path the harness owns, its compression targets
  model-readable text against a PR-reviewability requirement, and its vector memory fails the observability objection.
  Two instances make it a class — record the three reasons so the next gateway proposal gets an answer, not a shrug.
- **Findings F and G closed in `.claude/commands/change-review.md` and its template mirror (byte-identical after).**
  F: the exit-1 row now discriminates on **whether a report exists** before reading exit 1 as findings — with none it
  is a usage error (unknown flag, bad `--fail-on`, unknown profile, missing diff file, or ACR <1.10.0 rejecting
  `--chunk`), handled as `4` but with stderr read FIRST, since a usage error is deterministic and retrying it changes
  nothing. A **version preflight** was added as the new step 2: below 1.10.0 ACR is treated as UNAVAILABLE and the job
  goes inline as `basis: llm` — explicitly NOT falling back to a non-chunked run, which would reintroduce the silent
  truncation the job exists to prevent. G: the exit-3 row's "re-run with `--chunk`" is gone; the safety clause stays.
- **NEW FINDING, surfaced BY that edit and not fixed: `.claude/commands/` <-> `templates/claude-commands/` is a
  TEMPLATE_OWNED mirror pair with NO parity test.** `mb.sh:2028` auto-discovers every `templates/claude-commands/*`
  into `TEMPLATE_OWNED`, so `mb upgrade` overwrites the live copy **unconditionally** — divergence is silently
  reverted. That is verbatim the rationale `tests/test-mirror-parity.sh` states for guarding `.cursor/rules`, and it
  guards that family and not this one. The two copies are identical today only because this edit kept them so BY HAND.
  Extending the existing test is the obvious fix and is NOT done — new assertions here must be mutation-proved per
  source. **Also honest: nothing tests `change-review.md`'s content at all, so F and G are unverified by any suite.**
- **`tests/test-mirror-parity.sh` extended to a third mirror pair: `.claude/commands` <-> `templates/claude-commands`.
  50 -> 75 assertions** (8 pairs x exists+identical, 1 sweep guard, 8 orphan checks). All 8 measured byte-identical,
  none diverging by design, so it is STRICT-identity like `.cursor/rules` rather than allowlisted like `standards/`.
  Recorded in the file: the pair is TEMPLATE_OWNED by a **different route** — cursor rules are six literal array
  entries, commands are AUTO-DISCOVERED into the array (`mb.sh`), so the array holds exactly those commands that HAVE
  a template; a live orphan is therefore never in it, never visited, never shipped, and drifts silently. Directory
  names are asymmetric (`templates/claude-commands/` -> `.claude/commands/`), which a naive path derivation breaks on.
- **Mutation-proved on a SCRATCH copy, per the 2026-08-30 rule — never the shared tree.** A faithful scratch harness
  reproduced 75/0 before any mutation. Four mutations, each isolating one new assertion: one-byte divergence -> 74/1;
  live copy removed -> 72/1; live orphan added -> 75/1; template dir renamed -> **50/9**. The last is the one worth
  keeping: **50 is exactly the pre-extension count**, i.e. renaming the directory makes all 16 template-side
  assertions VANISH and only the sweep guard stands between that and a suite passing on nothing. The anti-tautology
  guard was demonstrated, not asserted.
- **`[NS-43]`(b) IS BROADER THAN RECORDED — new instance, reproduced today.** That entry says the review gate's
  textual matcher denies any Bash command merely MENTIONING the commit verb, "so this entry could not be written from
  a heredoc". The same thing happens for the BLOCK-tier recursive-delete pattern: writing THIS progress entry was
  denied because the prose quoted that pattern verbatim, and it had to be reworded to land. So the defect is not
  specific to the commit verb — **any BLOCK/deny pattern is unquotable in the record it governs.** Fail-safe, and it
  means the repo systematically cannot document its own guardrails from the tool it uses to write them. Reworded
  rather than bypassed, per the no-user-as-bypass rule.
- **Two operational notes.** The BLOCK tier also refused a recursive delete of my own scratch directory — correct, it
  does not whitelist scratch paths; worked within it using a fresh directory and `mv`. And a first full-suite run was
  KILLED at a 2-minute timeout; `run.sh` moves the real `VERSION` aside, so the tree was checked before continuing —
  `VERSION` intact at 1.2.1, no stray backups, no unintended modifications.
- **The exit-0 row was fixed too, and it is the most interesting of the three.** `0` no longer asserts "Ran fully";
  it now requires READING THE BODY, because a fail-fast/`earlyExit` ACR run exits `0` and declares itself INCOMPLETE
  in the body rather than the code. **Peer-reported by the ACR session (their PR #83), NOT reproduced here** —
  labelling preserved. Step 5's fall-through was widened to cover an exit `0`/`1` whose body contradicts its code.
- **What makes it worth recording: the old wording was NOT wrong when written.** Before that PR a fail-fast run was
  indistinguishable from a complete one on every readable surface, so "Ran fully" was accurate. It was made false by
  a change in ANOTHER repository, with no edit to this file and nothing here able to detect it. **A correct claim can
  be invalidated by a change elsewhere** — which is the cross-project form of the drift class this repo keeps
  finding internally, and the argument for citing a source of truth rather than restating its current state.
- **Cost of taking it mid-review, recorded because the sequencing is the lesson.** Five domain agents were already
  running against `git diff HEAD`. Editing without stopping them would have produced a marker binding a tree that
  **five of six reviewers never saw** — the marker-attests-to-unreviewed-content failure this repo has logged before.
  So they were stopped, all edits made, and the review restarted once against a frozen tree. Partial reuse of their
  findings was available and deliberately not taken.
- **ACR independently verified F and G in this checkout rather than accepting them, and found a measurement trap.**
  `grep -c "re-run with \`--chunk\`"` returns **1**, reading as "still present" — but the survivor is inside the
  parenthetical that RECORDS ITS OWN DELETION. **A count is the wrong instrument for "was this removed" whenever the
  record of removal quotes the removed text.** Same family as the check satisfied by a comment, one tier up: not a
  test that cannot fail, but a measurement that cannot distinguish.
- **RELEASE CONTRACT — scheduling decided by the operator 2026-08-31, so it stops being re-relayed.**
  The substance was approved 2026-08-28 (tag -> dirty-tree guard -> ref-sourcing). Only the *when*
  was outstanding, and it had died twice: relayed to `personal-memory-bank-7b`, which correctly
  declined to act second-hand, and that session ended. **Decision: cut the first tag AFTER this
  branch merges.** Rationale, unchanged from the constraint that produced the question: `mb upgrade`
  sources the WORKING TREE, so no tag may be cut against a dirty one, and the branch is 11 commits
  unpushed behind an open push gate. Recorded here rather than relayed again — a scheduling decision
  passed between sessions is how it gets acted on twice.
- **The 13 Medium ACR findings are NOT recoverable, and the scope of that claim is stated.** Searched:
  all 24 session transcripts under `~/.claude/projects/C--Users-Mizzo-.../`, the entire scratchpad tree
  (18 session dirs, unfiltered by extension), the ACR working tree for a default report location
  (there is none), and this repo. **What WAS recovered** from transcript `6bfddd35` (lines 5040-5071):
  the run metrics (`ACR_EXIT=1`, 200s, 15 findings), the per-agent chunk breakdown, and **both High
  findings in full with their disproofs**. The reviewing session printed only the `## Medium (13)`
  header and read the two High bodies; the Medium bodies never entered its context and ACR wrote no
  report file. **Product consequence for ACR, now in their brief:** a 200-second run whose output
  cannot be recovered fifteen minutes later is a workflow hazard independent of finding quality.
- **Both recovered High findings were false, by two mechanisms worth keeping.** (1) ACR read a
  **deleted `-` line as current code** and recommended exactly what the branch had already done —
  generalises to *a diff that fixes a bug contains the buggy code by construction, so the better the
  fix, the more false Highs it generates*. (2) It **inferred absence of behaviour from absence of an
  idiom** (no `ToLower` in the ps1), where PowerShell operators are case-insensitive by default;
  disproved behaviourally 4/4, not by argument. Also confirmed: 1.15.0 now emits `**Location
  unverified** (evidence not found at this line)` — PMB's own 2026-08-26 recommended invariant,
  implemented — and **both false Highs carried it**, so it works as a confidence signal but does not
  clear `Blocking: Yes`.
- **Downloads Work-MB exports refreshed 2026-08-31** (channel kept, per operator decision; a GitHub
  migration was considered and declined). `ACR-1.15.0-...-2026-08-31.md` created and the 1.13.1 file
  bannered SUPERSEDED; `PMB-Findings-for-Work-MB.md` header corrected `2052c3c` -> `11ec83b` and
  Documents 13-15 added (session-start load + the ratchet; the pointer mechanism; the five
  checks-that-could-not-fail); Round3 annotated as a deliberate snapshot; the paradigm-review HTML
  given a currency banner correcting **Q1** — its *"nothing structural can proceed until this is
  answered"* was falsified, since the ratchet shipped with the pointer mechanism still unbuilt, and
  the outcome was a third option neither Q1 branch anticipated.

## 2026-08-30 — two durable lessons; the change itself is in the commit message

- **The startup-context ratchet was worktree-blind, and worktrees are the common multi-session
  shape here.** It measured whichever `memory-bank/` sat beside it. From a subworktree that copy is
  stale by construction — `CLAUDE.md` forbids updating memory-bank there — so the gate reported
  **69,594 bytes "under" origin/main** when nothing had shrunk: a falsely reassuring green on the
  one check meant to be unfoolable, in exactly the case that happens most (a side job spun up in a
  worktree while the main session runs). Now resolved via `git rev-parse --git-common-dir`, so all
  four readings — two shells x main-checkout/worktree — agree. **The general rule: a measurement
  that varies by which session takes it is not a gate.**
- **Correction to a claim I made earlier today: the review marker does NOT silently invalidate.**
  I said a peer session's edit in a shared checkout would silently void an approved marker.
  Verified false by reading `scripts/review-reminders.sh` and simulating both states: the hash is
  bound to the WHOLE-tree diff, so any mismatch takes the `deny` branch with an explicit "the
  working tree changed since then; re-run" message. It is fail-safe — it can cost a review pass,
  never admit unreviewed code. The real multi-session cost is **wasted review passes**, not a
  bypass.
- **The genuine lost-update hazard is explicitly out of scope in this repo's own design.**
  `worktree-concurrent-session-claims` (unmerged; only two comments reference it in live `scripts/`)
  states in its own guide that claims "do nothing about two sessions concurrently editing
  `activeContext.md` and losing an update. Different problem, not addressed here." So two sessions
  in ONE checkout remain unprotected by design, not by oversight. **Practice consequence:
  mutation-testing that copies a live file aside and restores it can revert a peer's concurrent
  edit — checksum-verifying the restore proves my copy is intact, not that nobody else wrote in
  between. Mutate a scratch copy, not the shared tree.**

- **The BLOCK-tier hook receives TRUNCATED payloads, and that is still open.** Separate from the
  OEM-code-page decoding bug fixed here. `.pmb-hook-errors.log` carries the same signature from
  `2026-08-17` through today — `Unterminated string`, `Unexpected end when deserializing object` —
  i.e. the JSON arrives incomplete, for a reason not diagnosed. On that path the hook falls back to
  matching the raw text, so **a BLOCK substring past the truncation point is not seen.** The decoding
  fix does not touch this and must not be read as having characterised the stdin path; the scope
  limit is stated in the hook's own comment. Recorded here rather than `activeContext.md` because
  that file has 484 bytes of headroom and this is a finding spanning commits, which is what this
  file is for.

Per the write-rate rule added to `standards/MEMORY-BANK.md` in this same change, what the commits
already carry is not repeated here. Only what they cannot:

- **Disproving one cause is not finding one.** `dangerous-commands.Tests.ps1:546` failed for weeks
  with "cause unknown" after the leading hypothesis (`ConvertTo-Json` escaping non-ASCII) was
  correctly tested and disproved — and the disproof ended the investigation instead of redirecting
  it. What located the bug was arithmetic on the observed numbers: 275 = 5 + (135 x 2), every
  high-bit byte becoming two, which is double-encoding and not escaping at all. **When a hypothesis
  is disproved, measure the residual before proposing another mechanism.**
- **When a correct threshold cannot be enforced yet, enforce monotonicity instead of waiting.** The
  25 KB startup-context ceiling stayed advisory for months on sound reasoning — the repo is ~4x over
  and failing on it would block the work needed to get under it. What went unnoticed is that
  "advisory" was read as "may grow", and it did. Enforcing the DIRECTION costs nothing, cannot block
  a reduction, and would have caught the growth. Generalises to any cap a codebase is already over.
- **`projectbrief.md`'s Tier-1 goal now describes a mechanism that does not exist**, and `CLAUDE.md`
  documents the read-all it actually does as interim. That gap is deliberate and OPEN, not settled;
  `[NS-35]` decisions 1 and 3 are where it gets closed.

## 2026-08-30 — Contract 1: what the commit message cannot carry

- **Threshold parity was never measurement parity.** `mb.ps1` sized files with `Measure-Object
  -Line`, which skips blank lines: `activeContext.md` read **118** where `wc -l` read **146**. All
  three statements of the caps agreed the whole time, so every parity test passed while the two
  shells disagreed about the number being compared. Found by RUNNING both, not by reading either.
  **Generalises: a parity test over CONSTANTS says nothing about the MEASUREMENT applied to them.**
- `show_slim()`/`Show-Slim` exist in both shells and are dispatched from neither. Pre-existing,
  unfixed, advisory.
- `/change-review` and `/code-review` use `Basis` for orthogonal things — detector provenance vs
  evidentiary strength — so the absence-claim rule could not be forwarded wholesale; it hangs off
  change-review's **Evidence** field, collision documented in place.

## 2026-08-29 — absence-claim scope rule (`a11e4df`); a review-gate defect recorded

- **The rule, its placement rationale and its four accepted limits are in `a11e4df`'s commit message
  and are not restated here.** What that message does not cover follows.
- **`[NS-45]` — the review gate destroys its marker before the guarded verb runs.**
  `review-reminders.sh:92-93` writes `.pending-commit-presha` at PreToolUse;
  `review-reminders-post.sh:40` and `.ps1:43` delete it on entry to the commit branch, *before* the
  presha==postsha test that gates reissue — so its survival proves that branch never ran. A surviving
  presha then lets a later text-matching command mint a marker for an unreviewed tree.
  **Basis is INFERRED, not measured.** The chain is read from source; the bypass was never reproduced.
  What was observed is narrower: an orphaned presha survived a run on 2026-08-29, and two more dated
  2026-07-26 sit in worktrees.
- **The defect lives in an untested branch.** `tests/test-review-reminders.sh` covers "the commit ran
  and failed, HEAD unchanged" but nothing simulates the presha surviving because PostToolUse never
  fired at all; `review-reminders-post.ps1`'s reissue path has no Pester coverage.

## Review rounds 4-9 (2026-08-23 → 2026-08-25) — relocated 2026-08-26, detail in `docs/MEMORY-BANK-PARADIGM-REVIEW.md`

Five dated sections were moved **verbatim** to `docs/MEMORY-BANK-PARADIGM-REVIEW.md` § "Rounds 4-9"
— nothing summarised, reworded or deleted — because this file had 5 bytes of headroom against its
60,000-byte CI hard-fail. Same convention the Round 10 entry already uses. Each keeps its heading
there, so a citation to any of them still resolves:

- **2026-08-25 — Round 9 Completed (all six domains); Separator Hole Closed; Figures Corrected Outward**
- **2026-08-24 (rounds 8-9) — Round 8's Fixes Rejected by Round 8; Round 9 Then Found the Gap Class Was Itself a Bypass**
- **2026-08-24 (continued) — Review Round 7 — condensed; all five findings superseded by rounds 8-9**
- **2026-08-24 — Review Round 6: One Blocker, Two Pre-Existing Bypasses Closed, Cap Metric Fixed**
- **2026-08-23 — Review Round 4: A Pre-Existing Critical, and a Fix Withdrawn** — cited by `[NS-35]`

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
