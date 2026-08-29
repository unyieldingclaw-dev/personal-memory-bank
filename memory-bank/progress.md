---
authority: accumulating
review-cycle: 30d
retention: archive-after-6m
staleness-threshold: 90d
tags: [work/completed, work/in-progress, work/backlog]
last-reviewed: 2026-08-28
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

## 2026-08-26 — PR #21: round-10 gate pass, Approve + 4 must-fixes

- Six-agent gate → **Approve + 4 must-fixes, all applied.** Check 5's matcher showed a **false OK** (the row this branch hand-fixed yields no claim) *and* **false WARN** (`th(at) 50%`); `\b` closed the WARN, the OK gap is a recorded KNOWN LIMIT. `-cnotcontains` closes a **third** sh/ps1 case divergence. Suites 39/47/19/9. Detail: `docs/MEMORY-BANK-PARADIGM-REVIEW.md` § Round 10.

## 2026-08-26 (continued) — `[NS-37]` closed at the mechanism; a measured perf revert; cap deadlock resolved by relocation

- **`[NS-37]` was filed as a BLOCK-tier gap and was actually the mechanism.** `block()`, `block_boundary()`, `confirm()` and `warn()` all matched with a bare POSIX `case` — 4 of 6 matchers, spanning **three tiers** — against a `.ps1` twin that is `IgnoreCase` at every site. Five mixed-case payloads got **no verdict at all** from bash while PowerShell denied them: live on any machine without `pwsh`, CI included. Widened past the ticket at user direction on the monotone argument — folding both sides of an ASCII compare can only ADD matches, never remove one, so it cannot open a bypass; the whole risk is false positives, bounded by the existing word boundaries. Fixed by folding both views **once**, hoisted beside `cmd_loose`. The two lowercase SQL literals from the earlier per-instance patch are gone, restoring structural parity with `$blockPatterns`, which never had them.
- **A per-call fold was implemented, measured, and reverted.** Folding `$1` inside each matcher costs a `printf | tr` subshell per matcher *call* — ~25 per invocation, on a hook that runs on **every Bash tool call**: **1.07s → 2.33s**, measured over 10 runs. Patterns are written lower case instead, which creates a silent **fail-open** trap (an upper-case pattern matches nothing, ever; `chmod -R 777` was already that shape). Mutation-proved both directions — the mutant emits no output at all — and guarded by a new structural invariant in both suites. Verified 155/155 sh, 62/62 Pester, 494/494 full repo.
- **Cap deadlock resolved by relocation, not eviction and not a cap raise.** Rounds 4-9 (20,953 bytes) moved **verbatim** to `docs/MEMORY-BANK-PARADIGM-REVIEW.md`, dated pointers left behind; the relocation removed **20,953 bytes** from this file. **Its resulting size is deliberately not recorded here.** Two attempts to pin it — 40,063, then 46,956 — were each stale within the same branch, because entries kept being appended after the measurement was written. A number that decays faster than the document is worse than no number: read it with `wc -c`, and let CI enforce the caps. Raising the byte FAIL was rejected on three grounds: `pmb-health.yml` defines it as a **downward** ratchet ("a FAIL value that is never tightened is a cap in name only"), measured growth was **+24,355 bytes in three days** so a raise buys about a day, and the binding budget is the 25 KB aggregate startup ceiling — 121 KB → 102 KB, still **408%**. Condensation was rejected because rounds 1-9 detail exists nowhere else (verified absent from the review doc and `docs/archive/`), and this file has twice lost content to condensation.
- Open, unchanged: `[NS-38]` (pipe-newline continuation) and the new `[NS-40]` (WARN tier ignores the de-escaped view — a **shared** sh/ps1 limit, not a divergence). Filed first as `[NS-39]`, which collided with an existing id; `mb doctor` does not check id uniqueness, and nothing else does either. Branch `fix/block-tier-case-sensitivity` is implemented and verified but **not merged**.

## 2026-08-26 (later) — review-gate model pinning; `mb upgrade` agent-delivery fix; tiered-loading design DROPPED on review

- **`[NS-35]` decision 1 (tiered loading) was designed, Opposition-reviewed, and DROPPED — not deferred.** Six blocking findings. Two decisive: the index does **not fit on day one** (~117 bytes/item available once `memory-bank/README.md` (1,116 B) and the mandatory frontmatter blocks (530 B) are counted, against **198 bytes/item measured** in this operator's own tiered auto-memory `MEMORY.md`); and `.cursor/rules/memory-bank.mdc` plus both `pre-compact-check` scripts are `TEMPLATE_OWNED`, overwritten unconditionally by `mb upgrade`, so its "this repo only" scope was self-reverting. Opposition also showed the treadmill is driven by **write volume, not the read contract** — `docs/archive/` already holds 149,711 bytes relocated by exactly that mechanism while both files stayed pinned at their caps. Successor problem: write-rate control. Cheaper root fix identified and approved: collapse the threshold declarations to one authoritative source (**three** dimensions drifted, not one — `progress.md` lines 50/400/600, `techContext.md` lines 300 vs 400, `activeContext.md` bytes 40000 vs 45000). `[NS-35]`'s recorded "RESOLVED — raised across all nine live locations" is **false**; `mb.sh:409,410,967` and `mb.ps1:1189` still say 400, and `standards/PERFORMANCE-BUDGET.md` (**stable** authority) says 50 against a 410-line file — user ruled that one stale.
- **Review agents were running on haiku.** `.claude/settings.json` sets `CLAUDE_CODE_SUBAGENT_MODEL=haiku`; neither shipped agent pinned a model, and both review commands stated "never a cost-optimized model" for Opposition as **prose only**. So `security-reviewer` ran cheap and an Opposition pass silently would have, producing identically-shaped output. Fixed by pinning `model:` in frontmatter (`opposition: opus`, `security-reviewer: sonnet`, `researcher: haiku` stated deliberately) and adding a named `.claude/agents/opposition.md` so the requirement lives in config. **Verified 2026-08-26: frontmatter DOES override the env var** — spawned with no `model` param, it reported `claude-opus-5`. Also corrected two false claims I had already written into four files: agent definitions are picked up after a **refresh lag**, not at a session boundary.
- **`mb upgrade` would never have delivered the new agent.** `ADVISORY_DIFF` hardcoded two agent paths in **both** shells (`mb.sh:1917`, `mb.ps1:2159`) — the same stale-list bug the file already documents for slash commands in 1.2.0, recurring immediately. Fixed by auto-discovering `templates/.claude/agents/*.md` into **`ADVISORY_CREATE`** (not `ADVISORY_DIFF`, which *skips missing targets* — and a newly-shipped agent is missing for every adopter by definition, so discovery alone would still have delivered nothing). Regression test added with a completeness invariant; mutation-proved against the pre-fix file, where the agent appeared in zero lists.
- **Review-gate findings, not yet fixed.** `/change-review` writes `.change-review-ok` which gates **push** (`diff_hash origin/main...HEAD`); `git commit` checks `.code-review-ok` (`diff_hash HEAD`). On a branch with no commits the former hashes an **empty diff** — measured 0 bytes vs 159,027 — and the `rc -ne 0` fallback cannot catch it because the command *succeeds* with empty output. A marker records only a hash, never what it covered. Fix started and stopped at handoff: make `diff_hash()` return empty for an empty diff so the existing `[ -n "$expected" ]` guard denies.
- **ACR 1.13.1** (current latest, no drift): ran all 4 agents, diff not truncated, but **all three `file:line` citations were wrong** — one attributed test-file content to the guard script — and 2 of 3 findings were false positives including its only `Blocking: Yes`. Latent ordering bug: `hasBlocker` (exit 1) is checked before `truncated` (exit 3), so exit 1 masks truncation. Written up for the ACR session in `Downloads/ACR-1.13.1-Findings-from-PMB-2026-08-26.md`.

## 2026-08-27 — Full `/code-review` of the five-concern bundle; 24 findings remediated; three new mechanism bugs

- **Gate ran Needs Discussion, not Approve.** Six domains + Opposition (opus). Only two findings survived as blocking, both in memory/doc files, neither in the shell code. Opposition **disproved** the orchestrator's own `[O1]` (it ran the marker-write procedure successfully — the agent `tools:` `Bash(...)` entries do NOT constrain Bash) and corrected `[P1]`'s magnitude in both directions (hot path is noise, not "5-11% faster"; BLOCK path +25%, not +12.5-18%). Concern (a) verified sound: 8 live bypasses closed, zero regressions, across 15 constructed payloads.
- **`standards/MEMORY-BANK.md` eviction criteria amended, and the amendment was PROVEN before adoption.** The two age rows (>6mo/>3mo) had never fired and could not — repo is 4 months old (first commit 2026-04-29) while `progress.md` grows ~8,118 B/day. Worse, the old table returned the SAME verdict (deny) for `8847714` and `da62ad2` (both merged) as for the 2026-08-25 pass (reverted): a rule that cannot separate cases decided oppositely was not governing the decision. The real discriminator, found by inspection, is **citation survival** — the merged passes left the original `##` headings in place, the reverted one broke `[NS-35]`'s citation. The replacement row reproduces all four historical outcomes including the revert. An earlier draft (replace the guard with "citation resolves") was **withdrawn**: the archive note documents that citation rewrites cascade into `activeContext.md`, measured at **149 lines against a 150 hard-fail**.
- **Three divergences in the memory-bank line caps, running in BOTH directions.** Only `progress.md` (runtime 400 vs CI 600) had ever been recorded. `projectbrief.md` (150 vs 120) and `techContext.md` (400 vs 300) were **looser at runtime than in CI**, so a clean `mb doctor` could precede a red build. All aligned to CI; `tests/test-threshold-parity.sh` added and mutation-proved in both directions. `tests/test-mb-clean.sh` had pinned the pre-alignment 400 and is why the divergence stayed live.
- **`tests/run.sh` hardcodes its suite list — the THIRD instance of this bug class** (after slash commands in 1.2.0 and agents in `ADVISORY_DIFF`). A newly added suite never ran while the runner printed "All test suites passed". Closed with a `git ls-files`-based completeness invariant (tracked-only, so untracked WIP suites don't fail the run), mutation-proved.
- **A test of mine was vacuous and mutation caught it.** The first perf-figure parity check hard-coded the expected digits, so a drifted file matched nothing and yielded an empty string — and since `assert_contains` is a substring match (`grep -qi`), comparing against empty passed trivially. Rewritten to extract generically and compare by exact equality, with verdict words chosen so neither contains the other ("MISMATCH" contains "MATCH"). Now fails 5 assertions on canon drift, 1 on middle-file drift.
- **`mb upgrade` (pwsh only) could deliver non-agent files into `.claude/agents/`** — `Get-TemplateDirFile` had no extension filter while bash globbed `*.md`. Proved: pre-fix it returned a `.txt` and a `README`. Also confirmed `mb init` delivers NO agents on either shell (only `upgrade` does) — consistent, so not a parity bug, but a fresh adopter has no review agents until they upgrade.
- **Six hook false positives hit while doing this work**, all fail-safe: a `grep` alternation that de-escaped into a pipe-to-shell; a heredoc containing the commit verb; a heredoc quoting that first byte sequence; a heredoc carrying a mixed-case SQL literal (a cost of this branch's own folding fix); the payload for `[T2]` itself; and this very entry, for naming the deletion commands below. **The `[T2]` case is its own root cause:** a payload test for a guarded pattern cannot be authored from a shell heredoc, which is why that pattern had zero coverage. Written with file-editing tools instead. Two TRUE positives were also hit — the recursive-force-delete form on each shell — and were NOT reworded; the commands were dropped instead.
- **Caught and reverted a signing bypass I introduced myself:** a `gpgsign` disable written reflexively into a new Pester fixture. Forbidden by global CLAUDE.md, and gating that exact bypass was the subject of PR #21.
- **A finding attributed to PMB does not exist in PMB.** The ACR session asked this one to disambiguate a timeout measurement its memory bank credits to a PMB brief (616 s agent runtime against a 282,240 ms ceiling). Searched `memory-bank/`, `docs/`, `docs/archive/` and the ACR brief in Downloads: **zero hits** for any of it. Answered as unsourced rather than reconstructed from ACR's own formula, and recommended they re-derive it with per-invocation instrumentation. Two lessons for this side: PMB's record of ACR behaviour is thinner than assumed (the 1.13.1 findings are recorded in detail, the timeout work not at all), and an unsourced claim crossed a project boundary and became load-bearing there. Cross-project briefs need the same provenance discipline as in-repo citations.
- **`[NS-22]` closed at the mechanism (actions 1-2 of 3).** The PreCompact freshness gate short-circuited on a bare `[ -f handoff.md ]` existence check with **no staleness test**. Verified live: a handoff dated 2026-08-26 was still sitting in the repo root on 2026-08-27, so **every compaction in this session bypassed the gate**. The bypass was inverted — the staler the handoff, the more likely the memory bank actually needed checking. Both shells now require the handoff to be dated today. **The gate had ZERO test coverage in either shell**, which is how a bare existence check survived from 2026-08-19 escalation to now; `tests/test-pre-compact-check.sh` adds 16 assertions, mutation-proved in both shells (reverting the sh fix reddens exactly the 3 NS-22 sh assertions; reverting the ps1 fix reddens its NS-22 assertion **and** the mirror-parity guard). **`/code-review` then found three gaps in that first version**, all fixed here: a stale `handoff.md present ... skips both checks` bullet left behind in BOTH `HOOKS-GUIDE.md` copies while the surrounding prose was updated; ps1 parity claimed on a MANUAL check with nothing holding it (now 5 automated assertions, the same shape as `test-dangerous-commands.sh`'s parity block, skipped loudly when pwsh is absent unless `PMB_REQUIRE_PARITY=1`); and no `scripts/` vs `templates/scripts/` byte-identity guard despite `templates/` being what `mb upgrade` ships — the defect class that already bit `dangerous-commands` once and `7de75e6` once. **The first fix was wrong and the new test caught it**: appending the stale-handoff message to BLOCK_REASONS made a stale handoff hard-block a *healthy* memory bank — it must only remove the bypass. Docs updated in `CLAUDE.md`, both `HOOKS-GUIDE.md` copies. Closing the entry freed 1,244 bytes in `activeContext.md`, which had 44 bytes of headroom. **Action 3 remains:** the 40%-handoff / 65%-autocompact incoherence, which is advisory-by-construction since hooks cannot see context %.
- New: `[NS-42]` (write-rate control), `[NS-43]` (the gate structurally forbids commit-splitting — one marker equals one all-inclusive commit, and it is consumed on use).

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
