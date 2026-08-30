# Archived from `memory-bank/progress.md` on 2026-08-30 — verbatim, not summarised

Six sections covering 2026-08-22 through 2026-08-27, moved under the archive rule in
`standards/MEMORY-BANK.md` ("Move **verbatim** to a bounded destination ... leaving a dated pointer
that carries the original heading text"). **Delta, not a level: 20,452 bytes moved out.** No before/after total is stated here on
purpose. Two earlier attempts to pin one in this repo were stale inside the same branch,
because entries kept being appended after the measurement was written — and the first draft of
THIS header repeated that mistake, quoting a CRLF-inflated 59,986 and a projected 39,534 that
the branch's own later commits had already invalidated. The delta is the only figure that
does not decay.

Every original `##` heading is preserved below and reproduced in the pointer left behind, so any
citation of the form `progress.md` <date> still resolves. Citation survival was grep-verified before
the move, not assumed: `activeContext.md:45` cites `2026-08-24/26`, which the pointer carries.

All six describe work that is complete. Nothing here is an open item.

---

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

