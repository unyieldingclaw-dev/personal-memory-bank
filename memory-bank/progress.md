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

## 2026-08-28 — `[NS-22]` committed; Cursor's handoff threshold re-derived; `[NS-22]` action 3 closed as not-a-defect

- **`[NS-22]` committed as `7917905`** after a full six-domain + Opposition (opus) pass. **The first review pass used the WRONG command** — the bare skill name resolved to a plugin twin instead of `.claude/commands/code-review.md`, exactly the `[NS-21]` shadowing risk already on record. The twin has 7 steps to the project's 5, no `standards/CODE-REVIEW.md` contract load, no model pin on Opposition, and its Step 5 *instructs generating tests* — which the project command forbids at line 209. So the repo was mutated during review, a listed Failure Criterion. Re-run clean with read-only agent types so the domains structurally could not edit.
- **Opposition returned Approve, overturning Security's sole blocker on a strict-subset proof:** post-fix allows ⊆ pre-fix allows, so the change cannot permit any compaction `main` blocks today — a `touch` fails to close a residual rather than opening a hole, and the recommended `Date:`-line fix is equally forgeable. It disproved 3 of 4 claimed non-adversarial triggers by measurement (`handoff.md` is gitignored; OneDrive is a *sibling* of the repo, not an ancestor). **Its sharpest point, which no domain could see alone: the severity ordering was inverted relative to the diff's risk direction** — the change can only ever block *more*, so the whole new risk surface was the two over-blocking Mediums while the High was a pre-existing residual.
- **Two regressions accepted as documented limits** — GNU-only `date -r` (BSD `stat -f` fallback from the 2026-05-28 design not carried forward; live exposure zero) and the midnight hard-block that folds into `[NS-34]`. Both enumerated in `7917905`'s message. **Both then demonstrated live in this session:** the handoff went stale at rollover and `progress.md` had no entry dated today, so the gate blocked its own author.
- **Cursor's handoff threshold re-derived 80% → 40%.** Reasoning deliberately NOT restated here — it lives in `standards/MEMORY-BANK.md`, "Implications for Handoff Thresholds", which is the governed home for it; a second copy is the restatement-drift class this repo rules against. In one line: the 80% was justified on continuity (Cursor re-injects `.mdc` rules) and silent on output quality degrading with input length, which is IDE-independent. **Found by the user asking "isn't 80% too high?" on a third look** — my first pass called it drift (wrong: different decisions), my second withdrew the finding as documented-and-justified (wrong: justified on the wrong axis). The middle pass was the worst of the three and is the one that would have shipped.
- **`[NS-22]` action 3 CLOSED as not-a-defect.** "Handoff at 40% is user-triggered with nothing automating it" is true and *unfixable*: hooks cannot observe context %, now confirmed first-party — Sonnet 4.5 carries built-in context awareness model-side with no documented hook exposure. It is advisory by necessity, not by oversight. There is no incoherence left to reconcile: 40 < 65 in Claude Code, and Cursor is now 40 with no backstop to precede.
- **`tests/test-mirror-parity.sh` added** — the `.cursor/rules` ↔ `templates/cursor/rules` pairs had **zero** guards despite being `TEMPLATE_OWNED`. Auto-discovering and bidirectional; mutation-proved both ways. Full rationale in the file's own WHY block, not restated here.
- **The Round 10 deferred `standards/` parity check is not implementable as specified.** Byte-identity is the wrong invariant there: of three divergent pairs, **two are correct by design** — `AGENTIC-SAFETY.md` and `WORKFLOW.md` carry PMB-specific incidents and paths in the live copy that must not ship to adopters. Only `MEMORY-BANK.md`'s `mb compact` (verified: exits 2, superseded by `mb clean`) was a genuine defect, and it was **inverted** — the template shipped the correct instruction while PMB's own copy did not. Fixed here. Re-file the parity item with a different invariant rather than leaving it queued as merely unscheduled.
- **ACR provenance gap CLOSED — carried over from `handoff.md` before deleting it, and independently corroborated the same day by an ACR session message.** The 616 s figure this repo could not source: ACR re-derived it with per-invocation instrumentation and reports **do not raise the ceiling** — 12 invocations, slowest genuine attempt 213.2 s against a 315.4 s ceiling (~68%). The one row appearing to exceed it (611.7 s vs 354.7 s) was wall time across a retried `fetch failed`, a measurement artifact rather than an agent running long. **Record it exactly as ACR states it:** they judge the resemblance to the unsourced 616 s **suggestive, not established** — their words — and explicitly decline to call it confirmed (an earlier draft of this entry said *strong*, an adjective ACR never used; they flagged it 2026-08-28 and it is corrected here), because a resemblance cannot promote an unsourced number to evidence — which was the whole point of the gap. Do not upgrade that hedge. Shipped in ACR 1.15.0; `ReviewResult.timings` now lands in the CI artifact, so the rows accumulate instead of needing another half-day of local trials.
- **Still open from the handoff, not absorbed:** the competing opposition agent on `fix/review-gate-reconcile-designs` requires human confirmation rather than writing the marker itself, which may be the better design than what shipped.
- **Cursor 80% → 40%, and the reasoning took four passes to get right.** Pass 1 called it drift (wrong — Claude Code and Cursor were genuinely different decisions). Pass 2 withdrew the finding as documented-and-justified (wrong, and the worst of the four: it verified a rationale *existed* without checking it covered the binding constraint). Pass 3, prompted only by the user asking "isn't 80% too high?", found the rationale addresses **continuity** (rules re-inject, so instructions survive) and is silent on **quality** (output degrades with input length regardless) — and the quality curve is IDE-independent. Pass 4 found the *strongest* argument had been sitting unread the whole time: `systemPatterns.md:33` already stated 40% with no IDE qualifier. **But the tempting version of that argument is wrong** — `systemPatterns.md` carries `authority: stable` while `standards/MEMORY-BANK.md` has no frontmatter and no tier, and `CLAUDE.md`'s authority order ranks only `memory-bank/` files. So it was two governing documents in conflict with **no stated arbitration**, the third instance of that gap in one day (after global-vs-project `CLAUDE.md` and standards-vs-`CLAUDE.md`). The general gap stays open.
- **The sweep missed two adopter-facing files and a reviewer caught them.** `templates/AGENTS.md` (three occurrences — the cross-tool file read by Claude Code, Cursor, Codex and Gemini) and `templates/memory-bank/README.md`. Found by grepping the whole repo, which is not a mechanism. **Correction, caught by a later review round:** an earlier draft of this entry said both ship via `mb init`. Only `README.md` does (the `memory-bank/*` glob in `invoke_init`). **`AGENTS.md` has NO `mb` CLI distribution path at all** — zero references in `mb.sh`, absent from `TEMPLATE_OWNED` and both advisory lists; it is copied only by the standalone `scripts/init-memory-bank.sh:155`, which the documented `mb init` onboarding never invokes. So the file the repo calls its cross-tool rules file reaches adopters only through a bootstrap path the docs do not point at — a separate latent gap the wrong claim was hiding. **The fix that matters is `tests/test-threshold-parity.sh`'s new block**, which now extracts the threshold from all 9 prescriptive surfaces and asserts agreement — matching only *instructions* ("context >= N%", "at N% context", "at or above N%"), never bare percentages, so the files' own history sections describing the old 80% are not flagged as drift and nobody is pressured into deleting the explanation. Mutation-proved.
- **Three defects in my own new code, all caught by review, none by me.** A comment claiming `mb upgrade` "would silently delete" an orphaned rule file — **it has no delete path at all**, verified in both shells; the claim was plausible, motivating, false, and printed in assertion text on every run. And two assertions comparing a literal to itself and a variable to itself: behaviourally backstopped by their enclosing `if`, but unable to fail, in a file whose own header quotes "a check that cannot fail does not count as a check". Replaced with helpers that test the real condition.
- **Pre-existing, fixed in passing:** `tests/run.sh`'s `sed 's/\./\./g'` was a no-op (replaces a literal dot with a literal dot) while its comment claimed it escaped dots for the `grep -E` anchor; and both `.cursor/rules/memory-bank.mdc` copies carried duplicate `mb clean` rows, one of which claimed archived history goes to `AGENTS.md`.
- **`progress.md` cap deadlock cleared by relocation, not by trimming.** The file hit its 60,000-byte cap writing the entry above and could not accept another. Five sections dated 2026-08-12 → 2026-08-18, already marked *condensed, full detail archived*, moved **verbatim** to `docs/archive/progress-2026-08-condensed-sections.md` with dated pointers carrying each original heading; citation survival verified by grep beforehand (five live references, all still resolving). **Recorded as a delta, not a level: 12,965 bytes moved out, 1,490 added back as the pointer stub, net −11,475.** An earlier draft stated before/after totals instead; two reviewers independently flagged them, because a level is false the moment anything else in the file changes — and this entry's own later bullets changed it. That is the delta-not-level rule, violated in the entry that cites it. **Framing borrowed from an ACR session that hit its own caps four times in one day: move the evidence out, leave the rule in.**
- **Review round 2 found three blocking items; one was rejected on measurement.** (a) The threshold guard I added to close coverage holes **had a coverage hole of the same shape** — `[ -z "$vals" ] && continue` dropped a file from the sweep on a reword, and `[ -f ] || continue` dropped one on a delete, both silently while the suite reported success. The correct per-file `STATE_ABSENT` idiom already existed 20 lines above in the same file; the block was modelled on that one and did not carry over the part that makes it complete. Fixed, mutation-proved both triggers on the real file (31/1 each). (b) The authority/arbitration argument lived **only** in `CHANGELOG.md` and this file while both cited `standards/MEMORY-BANK.md` as its home — the no-duplication rule enforced for one half of the reasoning and violated with the other. Moved to the standard, trimmed here to a pointer. (c) **A byte-count finding was REJECTED**: the reviewer reconstructed 64,314 by adding the *final* entry to HEAD, conflating two states; `54,611 + 5,305 = 59,916` exactly, and the file was never over cap. Corrected the figure anyway, for the delta-not-level reason two other domains gave.
- **`standards/MEMORY-BANK.md` was shipping a superseded Handoff Protocol, and the divergence inverted an authority rule.** Found when the user asked why the handoff reply lacked the expected structure — the answer was that *two* structures exist. The standard listed "Summary of accomplishments / Files modified / Pending tasks / Context for next agent" as handoff contents, all of which `CLAUDE.md` explicitly forbids ("that duplicates memory-bank and risks drifting from it"). Worse, its **Next Session step 1 said to read `handoff.md` FIRST**, while `CLAUDE.md` says read all `memory-bank/` files first and the handoff second, never as authoritative — so the standard told the next session to synthesise priority from the file written under the worst conditions for it. `CLAUDE.md` supersedes (user ruled 2026-08-28); both `standards/` copies rewritten to match and verified identical. **Fourth instance in one day of the no-arbitration gap** — after global-vs-project `CLAUDE.md`, `standards`-vs-`CLAUDE.md`, and `systemPatterns`-vs-`standards`. The template mirror had been shipping the inverted ordering to every adopter.
- **Reported by ACR, not yet acted on: `mb upgrade` distributes a working tree, not a release.** No `git archive`/`checkout`/`describe` anywhere in `mb.sh` — it copies whatever is in the PMB checkout at that moment. Combined with `TEMPLATE_OWNED`'s unconditional overwrite of files adopters may not patch locally, an in-flight edit silently replaces working downstream scripts. **Verified here while answering them, and worse than reported:** `VERSION` says `1.2.1`, `.pmb-version` says `1.1.1`, and the newest git tag is `v1.0.4` — three numbers, and **no tag exists for either 1.1.x or 1.2.x**, so there is nothing to pin a release to and a dirty-tree guard is the only near-term option. ACR has been blocked on 1.1.1 for this reason with a dead `last-reviewed` sensor they cannot fix locally. Their session ended before I could reply.

## 2026-08-28 (later) — `d550282` committed; branch `/change-review` run; the nine-instance pattern named

- **`d550282` committed** after two five-domain rounds and **two** Opposition passes. Opposition's
  first pass returned Request Changes with three required fixes, and its diagnosis is the one worth
  keeping: *"this is a docs-only change whose entire deliverable is the accuracy of prose, three of
  its prose claims are verifiably wrong, all three were introduced AFTER every review ended, and none
  has ever been read by anyone but me."* **The fix passes were the defect source, at a 3-of-5 rate.**
- **New standing rule, learned the expensive way — PRE-FLIGHT before dispatching any review.**
  Mechanically re-derive every checkable claim in the artifact: figures, `file:line` citations,
  enumerations, and any sentence of the form "I verified X." Reviews are for judgement, not
  arithmetic. Applied to the branch afterwards it cost ~90 seconds and came back clean; not applying
  it to `d550282` cost two rounds and two Opposition passes whose combined output was four one-line
  corrections to claims a `grep` would have caught.
- **`/change-review` run on the full branch** (46 files, +3,019/−707, 4 commits) to obtain the push
  marker. 9 jobs; Job 8 correctly skipped (no UI files). **ACR was DISQUALIFIED**: installed and
  invoked, but exited **3** having processed **2,000 of 4,743 diff lines (42%)** — the exact silent
  failure recorded on 2026-08-26. Job 7 fell through to the inline security logic, `basis: llm`.
  The command's insistence on checking the exit code rather than the binary's presence is what
  caught it.
- **ONE BLOCKING FINDING, and this branch causes it: `mb init` never delivers `.claude/agents/*.md`.**
  `invoke_init` copies every `templates/claude-commands/*` — including `code-review.md` and
  `change-review.md`, which each dispatch `subagent_type: opposition` — and contains **zero**
  references to `.claude/agents`. Before `d795abb` the commands asked for "a capable model" in prose;
  `d795abb` made it a named-agent dependency, converting a latent gap into a live break. **The
  documented fallback is broken by the same gap:** `code-review.md:98` says to fall back to
  `general-purpose` "pasting the body of `.claude/agents/opposition.md` in as the prompt" — a file
  `init` also never delivers. So a fresh adopter's review gate is dead on arrival with no graceful
  degradation. `progress.md` 2026-08-27 recorded half of this and dismissed it as "consistent, so not
  a parity bug" — true when written, false the moment `d795abb` landed.
- **THE PATTERN, named after nine instances in one day: a guard built for a class, scoped to the one
  path that prompted it.** It splits into two families needing different fixes.
  - **Family A — coverage decided by a hand-maintained list (6 of 9):** `mb doctor` checks lines not
    bytes; `test-threshold-parity` compares the line-cap map not the byte-cap map; ownership class
    answers "may they customize" not "how does a fix reach them"; agent delivery covers `upgrade` not
    `init`; the handoff threshold is swept across 9 surfaces but the protocol *text* is unguarded;
    (`run.sh`'s suite registration was this and is already fixed). **Fix: derive the set from the
    authority at runtime, never enumerate it, and assert the derived set is non-empty.** The repo
    already has this idiom in three places and applies it per-incident rather than as policy.
  - **Family B — a guard that silently no-ops when a precondition is absent (3 of 9):**
    `PMB_REQUIRE_PARITY` unset makes parity failures non-fatal and **CI never sets it**, so a runner
    image without pwsh turns the sh/ps1 parity proof into a silent skip; `date -r` is GNU-only.
    **Fix: absence must be loud.** The `STATE_ABSENT`/`STATE_PRESENT` idiom exists in this repo and
    is used in one block of a file while the block above it uses a bare `continue`.
  - **What no mechanism catches, so it must become a review obligation:** a fix with no failing input
    (the `sed` dot-escape — correct, behaviourally inert), which comparisons need exact equality
    rather than `assert_contains`' substring match, and relocation verbatim-ness. Required question
    for any diff adding a guard: *enumerate what it covers and what it excludes; is the exclusion
    derived or accidental?*
- **Instance #8 deserves its own line: `tests/test-threshold-parity.sh:34-36` uses
  `assert_contains "sh=$sh" "sh=$ci"`** — unanchored, so `sh=1200` passes against `ci=120`. Two
  blocks below, the same file guards against that exact trap with exact-equality and non-overlapping
  verdict words, and explains why in a comment. Latent only; live values agree today.
- **Job 7 (Security), HIGH, not fixed here:** the `opposition` agent is new in this branch and is
  granted marker-write authority, while its own frontmatter documents that its `Bash(...)` allowlist
  does not constrain Bash — it was observed running `rm`, `curl`, `python3` and arbitrary redirects.
  So the gate's sole authority runs under an unenforced read-only assumption. Compensating control
  used throughout today: the orchestrator independently recomputed every marker hash rather than
  trusting the value. Needs a PreToolUse hook and its own contract.
- **A hook false positive while testing the hook.** A payload constructed to check whether the marker
  could be forged was denied — "command piped to bash (curl|bash)" — because the *test command* named
  both `curl` and `bash`, though nothing piped anywhere. Sixth recorded instance of `[NS-25]`'s
  match-the-text-not-the-intent class. The forge vector is therefore **unverified**, not cleared.
- **Approved plan:** the `mb init` fix under its own tight contract (`mb.sh`, `mb.ps1`, plus a
  regression test on each shell using the completeness-invariant shape) → then the template-surface
  completeness invariant, which retires Family A → then a spec for the review-obligation and
  meta-test layers.

## 2026-08-28 (continued) — Round-3 pass, Opposition Approve, committed `2052c3c`

- **Committed `2052c3c`** after all five required domains plus Opposition (opus). 14 files, +543/−193,
  suite **577/0 across 22 suites** measured serialized. The seven accepted limits are enumerated in
  the commit message and deliberately not restated here.
- **Three domains returned `Blocking: true`; Opposition overturned all three on one fact.** Every
  *Handoff Protocol line* in `templates/AGENTS.md` and both `.cursor/rules/memory-bank.mdc` copies is
  **byte-identical to `main`** — only the percentage changed in those lines. (Stated precisely,
  because a looser earlier draft here said the *files* were byte-identical and only the percentage
  changed. False at file level: the `.cursor/rules` copies also gained a five-line threshold
  rationale blockquote and an `mb clean` row rewrite. Neither is a protocol change, so Opposition's
  reasoning holds — but the compression of it did not, and a reader checking the file would have
  found the claim wrong.) **The orchestrator argued it was blocking before any domain reported it**,
  then found the `git show 030662c` counter-evidence itself. The convergence was weaker than it
  looked: the domains were told what the diff was *meant* to fix, which primed them to check whether
  it had. Prompt framing is not independent confirmation.
- **The surface count was wrong, and then the correction to it was ambiguous. Stating the criterion
  first, because that is the actual defect.** A surface "carries the superseded protocol" here iff it
  **explicitly states either the forbidden contents list** ("accomplishments / files modified /
  service state / commands to resume / pending tasks") **or the inverted read order** ("read
  `handoff.md` first"). Under that criterion the true figures are **7 total → 5 remaining**:
  - Fixed by `2052c3c` (2): `standards/MEMORY-BANK.md`, `templates/standards/MEMORY-BANK.md`.
  - Still carrying it (5): `templates/AGENTS.md:61,65`; `.cursor/rules/memory-bank.mdc:61-67,72`;
    `templates/cursor/rules/memory-bank.mdc:61-67,72`; `standards/WORKFLOW.md:194,198`;
    `templates/standards/WORKFLOW.md:188,192`. The last two were found only in round 1 of this
    entry's own review — nobody had enumerated them before.
  - `templates/memory-bank/README.md` is a **sixth** surface under a *looser* criterion: it is silent
    on the new memory-bank-first ordering without contradicting it. Counting it gives `8 → 6`, which
    is where the earlier figure came from. Applied consistently that looser criterion would catch
    several more surfaces than six across the repo — a further reason the strict one is what is
    stated here. Both numbers were defensible; **neither was
    checkable, because the criterion was never stated.** That is the finding, not the digit.
  - **`2052c3c`'s commit message says `6 → 4`.** It is superseded and cannot be corrected without
    rewriting history. This entry is authoritative. That split — a frozen copy and a mutable one,
    only the second fixable — is exactly the hazard flagged one round earlier about restating
    commit-message content here, now demonstrated rather than predicted.
  - The direction of Opposition's ruling is unaffected: the drift is pre-existing on `main` and the
    commit still reduces the count. Only the size of the remaining work changed.
- **Architecture Drift cited a file not in the diff.** It offered "the rewritten `CLAUDE.md:111-128`"
  as evidence the change *created* a contradiction. `CLAUDE.md` is not among the 14 files and already
  carried the narrow protocol on `main`. Failure Criterion "Evidence does not materially support the
  finding claim" — caught by Opposition, not by the orchestrator, who read the finding and did not
  check its citation.
- **A cross-domain disagreement settled by measurement.** Correctness called the `tests/run.sh` `sed`
  fix "genuinely necessary"; Testing mutation-proved the grep verdict identical either way. Testing
  was right — an unescaped `.` in an ERE still matches a literal `.`, and none of the 22 tracked suites
  differ only at that position. Correct hardening, zero live coverage closed; do not cite it as a
  coverage fix.
- **`tests/run.sh` is NOT concurrency-safe.** `test-mb-doctor.sh:94` `mv`s the live `VERSION` aside
  while `mb.sh:702` gates `.pmb-version` on its presence (was `:681`; the agent-delivery insert of
  2026-08-28 shifted it +21 — a live demonstration of why a `file:line` citation decays). A peer session's concurrent run produced a
  spurious `mb init` failure (576/1) the suite alone did not reproduce (19/19). Interference is
  asymmetric — it can only fake a FAILURE, never a pass — so a green run is trustworthy and a red one
  needs the isolation check. A bare `grep -c FAIL` also counts section headers; use `^  FAIL:`.
  Committing mid-run is worse than slow: the transient `VERSION` deletion breaks the hash check and
  `consume_marker()` destroys the marker *before* comparing, so the denial eats the approval. Backlog.
- **Opposition raised two findings no domain reached and retracted two of its own with the evidence
  that killed them.** `[O1]` `mb upgrade` lands the `.cursor/rules` number (`TEMPLATE_OWNED`, hard
  overwrite) but never the `standards/` rationale (`ADVISORY_CREATE`, not copied when the file exists),
  so an adopter's two copies disagree until they act on the printed prompt. `[O2]`
  `standards/MEMORY-BANK.md:342-345` names absolute input length as the binding variable, then reasons
  in percentages of two different, unstated context windows.

## 2026-08-28 (fix) — `mb init` agent delivery closed; the exported Work-MB briefs found stale

- **The `/change-review` blocker is fixed, under contract `mb-init-agent-delivery-2026-08-28`.** Both
  `invoke_init` and `Invoke-Init` now auto-discover `templates/.claude/agents/*.md`, mirroring the
  delivery already present on the `upgrade` path. Filtered to `*.md` on both sides so the two shells
  discover the same set — the pwsh helper defaults to `*`, which would have delivered stray files the
  bash glob skips.
- **Both regression tests were mutation-proved RED before GREEN, in that order, and the order is the
  point.** bash 20/1 → 21/0; Pester 10/1 → 11/0, failing with exactly
  `opposition.md,researcher.md,security-reviewer.md`. The pre-existing
  `Invoke-Upgrade agent advisory-create` test passed throughout, which is the whole diagnosis in one
  line: the covered path was never the broken one.
- **Both new tests assert their derived set is NON-EMPTY.** Without it an absent or empty template
  directory iterates zero times and reports PASS while delivering nothing — Family B's fail-silent
  shape, in a test written to close a Family A gap. **`tests/test-mb-upgrade.sh:109-113` still lacks
  this guard**; recorded in the contract's exclusions rather than fixed in passing, because it is
  adjacent pre-existing work and this contract is deliberately tight.
- **The contract for this work had been approved and never written** — caught only because the branch
  state was re-derived at session start rather than trusted. The `active-task.json` in place was a
  *different*, completed task (the Cursor threshold). `.claude/contracts/*.json` is gitignored, so
  overwriting it would have destroyed the only copy; parked as
  `completed-cursor-handoff-threshold-2026-08-28.json` instead.
- **Seventh instance of `[NS-25]`'s match-the-text-not-the-intent class, hit while writing the Pester
  test.** A heredoc was denied by the push gate because its *content* — Pester fixture setup — contains
  the literal text `git commit -q --allow-empty`. Nothing was being committed. Worked around with the
  Edit tool, the same precedent instances 4-5 used. The count in `[NS-25]` said five as of 2026-08-19
  and six as of 2026-08-28; this is seven, and the trigger is again *documenting or testing* commands
  rather than running them.
- **The two Work-MB briefs in `~/Downloads` carry no Work-MB findings.** Diffed against `docs/`:
  byte-identical plus a provenance banner, 32/33 lines added, zero removed. They are PMB's outbound
  exports. **But the paradigm brief's banner is itself stale, superseded by `d550282` one commit after
  it was written.** It claims `2052c3c` reduced the superseded-handoff-protocol surfaces "from six to
  four" and names `templates/memory-bank/README.md` as one of the four. Verified against the files:
  `standards/WORKFLOW.md:194,198` and `templates/standards/WORKFLOW.md:188,192` carry **both**
  disqualifying markers (the forbidden contents list *and* "read `handoff.md` first") and appear
  nowhere in the banner, while `README.md:34,37` carries **neither** and is a looser-criterion surface
  only. So the export under-counts by two and mis-includes one; the authoritative figure stays 7 → 5.
  An export with a provenance banner is not self-updating, and this is the first demonstration that
  the banner ages faster than the body it guards.

## 2026-08-28 (eviction) — `activeContext.md` resolved-entry pass; its own finding was false

- **Delta: −533 bytes net** on `activeContext.md`, in three parts: **−864 from the eviction**
  (`[NS-2]` −127, `[NS-22]` −640, `[NS-24]` −97), **+82** from same-commit status edits unrelated to
  it, **+249** for the `[NS-44]` pointer. Three buckets, not two: the first draft folded the status
  edits into the eviction figure and understated it by 82 bytes — a decomposition that misattributed,
  in the bullet claiming to decompose *because* a single figure misattributes. Caught in review.
  Under `standards/MEMORY-BANK.md`'s activeContext row 3
  ("Issue marked resolved → Delete — do not archive"); no archive file created. `[NS-2]` deleted
  (zero inbound); `[NS-22]`/`[NS-24]` compressed to stubs because live entries cite them — the
  practice Trim History already records for 2026-08-20, not a new convention. `[NS-10]` kept: its
  "investigated and declined" exists in no other file.
- **The pass's headline finding was FALSE and Opposition caught it.** It claimed `[NS-4]` and
  `[NS-31]` had dangling pointers to relocated sections. They resolved fine — the forwarding blocks
  at lines 24-25 preserve each original heading for exactly that purpose. **The check was
  `grep "^## <date>"`; the headings are bullets.** Wrong anchor, manufactured defect. Reverted: the
  "repair" had spent 134 bytes rewriting working pointers into the binding-constraint file, against
  this standard's guidance that doing so spends headroom in a second capped file. Third wrong-boundary
  check this session (bracket-only, single-file, `^##`); self-review caught none, Opposition caught all.
- **It also relieved the wrong file.** `activeContext.md` is flat across today's commits while
  `progress.md` grew +9,583 in one and is force-written every compaction by `pre-compact-check.sh`.
  `[NS-42]` already says write rate is the binding constraint — demonstrated here, not restated.

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
