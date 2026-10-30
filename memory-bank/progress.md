---
authority: accumulating
review-cycle: 30d
retention: archive-after-6m
staleness-threshold: 90d
tags: [work/completed, work/in-progress, work/backlog]
last-reviewed: 2026-10-30
compaction_generation: 0
source_type: canonical
confidence: high
lineage: []
---

# Progress

## 2026-10-29 — PR #78 merged; v1.3.0 released; merge-aware review spec merged

- **PR #78 (`6ecda5a`, 2026-10-27):** the ps1 review-gate classifier compares ordinally; two measured commits
  that got NONE from the ps1 hook are now denied. New `tests/test-review-gate-classify-parity.sh`. Detail,
  open follow-ups and the still-incomplete list: `[NS-68]`, `changelog.d/fix-review-gate-classify-ordinal.md`,
  the PR body's "Follow-ups" and `docs/backlog/review-gate-classifier-gaps-beyond-culture-compari.md`. PR #104
  (open; replays closed #90) stacks test and guard hardening on it. After approval it took seven merges from `main` (two made
  by GitHub's "Update branch"), one merge reconciling two parallel syncs of the same `main` tip, and one fragment
  commit (`gh pr view 78 --json commits`, parents via `git log -1 --format=%p`). The PR body is stale: it lists
  four merges and records reviews for three. This is the cost PR #92 targets; its §6 step 4 would count syncs like these (its own #78 baseline lists three).
- **PR #92 (`76a8491`):** the merge-aware review-gate spec,
  `docs/superpowers/specs/2026-10-23-merge-aware-review-budget-design.md`; the user's decisions are its §7.
  Fragments (PR #97) and the release (PR #96) came out of it; the gate itself is `[NS-70]`.
- **v1.3.0 (annotated tag `v1.3.0` on `2ae44a6`, PR #96):** the first release since 1.2.1. Notes:
  `docs/archive/changelog-1.3.0.md`. PR #97 (`8d21b56`) moved release notes into per-PR fragments in
  `changelog.d/`. PR #78 is not in the tag; its fragment ships in the next release.
- The 2026-09-11 section moved verbatim to `docs/archive/` to fund this entry (stub below).

## 2026-10-23 — PR #85 merged (`c2a5d1c`): merge-gate follow-ups; their sessions; an ACR timeout

- What changed, the verification figures and the /change-review conditions: the PR #85 body and the messages of
  `73deeeb`, `dadda3e`, `3439d4b` and `208ab36`. The gate merged its own PR (the user clicked Allow; logged in
  `.claude/merge-asks.log`). Open conditions and owners: `[NS-65]`.
- Also 2026-10-23: `[NS-58]` got an owner; ACR 1.15.0's ~307 s "fetch failed" is undici's 300 s headersTimeout
  (`[NS-48]`).

## 2026-10-23 — PR #81 merged: the merge deny became a user-clicked permission prompt

- Detail and open items (G1-G3; `327c6c2`, rebased as `73deeeb`, merged in PR #85): `[NS-65]` in `activeContext.md`; spec
  `docs/superpowers/specs/2026-10-20-merge-gate-user-approval-design.md`.

## 2026-10-20 — PRs #77 (`1b086c7`) and #58 (`25515a2`) merged

- **#77:** the review gate's empty-diff denial now names the root it checked (`review-reminders` sh/ps1 + templates
  mirrors); J5-1 path pinned in `tests/test-review-reminders.sh`. Merged 2026-10-19.
- **#58:** `docs/CLAUDE-CODE-PLUGINS.md` limits external skill-library guidance to actual plugin choices.

## 2026-10-20 — PRs #59 (`5c6f8e4`) and #71 (`2c4088f`) merged

- **#59:** `update-reviewed.sh` bash fallback: no file loss on a backslash Windows path, stdin read under a
  native pipe (SQA #25/#26). Its advisory, paths-filtered Windows CI workflow must not become a required check.
- **#71 (OPP6-1):** the commit gate refuses while any tracked change is unstaged (marker hashes the working
  tree, a commit records the index; near-miss 2026-10-16). Stage in a separate command; `git commit -a` is
  refused. Outside-pushed `1be7055c`, `e2b52866` retired by an `-s ours` merge. Follow-ups: `[NS-69]`.

## Relocated 2026-10-04 → 2026-10-19 — five sections moved verbatim 2026-10-23

Moved to `docs/archive/progress-2026-10-04-to-19-c1-plan-a-and-journal-hardening.md` **verbatim**, to fund
the PR #85 entry under the ratchet. Citation check: that file's header. The original headings are kept
below, so `progress.md <date>` references still resolve. Three earlier stubs are folded in, with their files.

- **2026-10-19 — PRs #64, #72, #69, #74 and #75 merged**
- **2026-10-19 — PR #65 merged (`0b67d9d`): no FIFO hang at `started` or the gate probe**
- **2026-10-19 — PR #63 merged (`d3f87f8`): FIFO-safe journal gate, ps1 regular-file check**
- **2026-10-18 — C1 Plan A merged (#57, `d751b73`); PreCompact lock-up recorded (#62, `e38620f`)**
- **2026-10-14 — PR #55 opened (WARN-tier hooks → JSON); its review's findings recorded**
- **2026-10-13 — Memory-bank reconciliation committed after an 8-day pause**
  (both: `docs/archive/progress-2026-10-13-and-10-14-reconciliation-and-pr55.md`)
- **2026-10-05 — PRs #51 (`07e3bd2`) and #53 (`3cadb06`, [NS-19]) merged**: `docs/archive/progress-2026-10-05-prs-51-and-53.md`
- **2026-10-04 — `mb doctor --check` and pre-push Check 7 (PR #51)**

## 2026-10-04 — PR #47 merged (`19931dc`); `fix/ns19` rebased onto it

Moved verbatim to `docs/archive/progress-2026-09-26-and-10-04-ns19-and-pr47.md`. Still open: PR #48
and the track-or-ignore decision for `.agents/`/`.codex/`.

## 2026-09-30 — PR #49 merged (`584a8e4`); two review-gate escapes open

- **Unfixed:** an apostrophe in a heredoc body before a commit in one command makes both
  classifiers return NONE (chip 08). A wrapper's own options do the same; fix `0e04fa0` is
  unpushed on `docs/wrapper-option-classifier-escape`.

## 2026-09-26 — [NS-19] plan workflow fixed; diff-only standards reversed by fleet data

Moved verbatim to `docs/archive/progress-2026-09-26-and-10-04-ns19-and-pr47.md`.

## Relocated 2026-09-21 → 2026-09-25 — three sections moved verbatim 2026-10-05

Moved to `docs/archive/progress-2026-09-21-to-25-ns-audit-preapproval-plan-and-pr46.md`
**verbatim**, to fund PR #51's owed delta under the ratchet. Delta and citation check: that file's
header. The original headings are kept below, so `progress.md <date>` references still resolve.

- **2026-09-24 → 25 — PR #46 merged; local `main` reconciled; two more merge-gate escapes**
- **2026-09-22 — Pre-Approval Protocol plan: six review rounds, and my "Approve" was wrong twice**
- **2026-09-21 — Next-Steps audit; NPM_TOKEN resolved; false "unmerged" claims found**

## Relocated 2026-09-19 → 2026-09-21 — three sections moved verbatim 2026-09-25

Moved to `docs/archive/progress-2026-09-19-to-21-ai-review-config-and-ns44.md` **verbatim** to fund
the 2026-09-24 → 25 entry under the ratchet. Delta and citation check: that file's header.

- **2026-09-21 — `ai-review.config.json` test guard ships (PR #40); mid-session data-loss recovery**
- **2026-09-19 — `ai-review.config.json` ships NS-48; first draft was a near-miss**
- **2026-09-19 — NS-44 design (PR #33); NS-55 opened; write-rate fix confirmed insufficient**

## Relocated 2026-09-15 → 2026-09-19 — three sections moved 2026-09-22

Moved to `docs/archive/progress-2026-09-15-to-19-review-gate-pr28-29-and-marker-writes.md` without rewriting the narrative text; section separators were normalized. See its header for why.
The original headings are kept below, so `progress.md <date>` references still resolve.

- **2026-09-19 — Review-gate marker writes intermittently vanish; a platform classifier, not a repo hook**
- **2026-09-18 — PR #28 and #29 merged; both change-review push-gates run for the first time**
- **2026-09-15 — review-gate paired paths corrected and opposition-approved**

## Relocated 2026-09-16 → 2026-09-17 — two sections moved verbatim 2026-09-19

Moved to `docs/archive/progress-2026-09-16-to-17-codex-precompact-reproduction-and-review.md`
**verbatim**, not summarised — same precedent as every relocation above. **Why:** today's review-gate
marker-persistence finding broke the aggregate startup-context ratchet; this move relocates 2,449 bytes
(gross, matching the archive header's own body — delta, not a level). Citation survival grep-verified
(`activeContext.md`'s PR #28/#29 entry cited this range; updated in the same commit to split the
citation between this archive file and the live 09-18 entry). Original headings preserved below so
`progress.md 2026-09-16`/`2026-09-17` references still resolve.

- **2026-09-17 — Recovery-only Codex review**
- **2026-09-16 — Codex PreCompact reproduction and pending UX review**

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

Moved to `docs/archive/progress-2026-08-28-round3-gate-passes-and-brief-staleness.md` **verbatim**, not summarised. **Delta, not a level: 30,235 bytes moved out** (LF blob — an earlier draft said 30,448, the CRLF worktree figure).
Citation survival grep-verified before the move; each original heading is preserved below and in
the archive file, so existing `progress.md` <date> references still resolve.

- **2026-08-28 — `[NS-22]` committed; Cursor's handoff threshold re-derived; `[NS-22]` action 3 closed as not-a-defect**
- **2026-08-28 (later) — `d550282` committed; branch `/change-review` run; the nine-instance pattern named**
- **2026-08-28 (continued) — Round-3 pass, Opposition Approve, committed `2052c3c`**
- **2026-08-28 (fix) — `mb init` agent delivery closed; the exported Work-MB briefs found stale**
- **2026-08-28 (eviction) — `activeContext.md` resolved-entry pass; its own finding was false**

## Relocated 2026-09-12 → 2026-09-14 — three sections moved verbatim 2026-09-18

Moved to `docs/archive/progress-2026-09-12-to-14-check15-and-baseline-health-ci-fixes.md`
**verbatim**, not summarised — same precedent as every relocation above. **Why:** today's PR #28/#29
merge log and `[NS-54]` broke the aggregate startup-context ratchet; this move relocates 3,892 bytes
(gross, matching the archive header's own body — delta, not a level). Citation survival grep-verified (`activeContext.md`'s
`[NS-37]`/`[NS-51]` cited these sections by date; both updated in the same commit to point at the
archive file instead). Original headings preserved below so `progress.md <date>` references still
resolve.

- **2026-09-14 — baseline-health's CI-only failure was a shallow nested-clone ref assumption**
- **2026-09-13 — check 15's real cause found and fixed: `$env:USERPROFILE`, not the bracket glob**
- **2026-09-12 — PR #25 stays red after the grep-portability fix; a second, pre-existing failure**

## 2026-09-11 — whole-repo review: the enforcement layer does not enforce; and a scratchpad collision

Moved verbatim 2026-10-29 to `docs/archive/progress-2026-09-11-whole-repo-review.md`, to fund the
v1.3.0 entry. Its eleven findings, and where the report and patch are held, are there.

## Relocated 2026-09-09 — one section moved verbatim 2026-09-17

Moved to `docs/archive/progress-2026-09-09-ci-check-vacuity-and-retrieval-baseline.md` **verbatim**,
not summarised — same precedent as every relocation above. **Why:** the Codex PreCompact recovery-only
policy correction's two new dated entries pushed this file to 512 of its 500-line cap and the
aggregate startup-context ratchet 3,057 bytes over `origin/main`. Citation survival grep-verified
(`activeContext.md`'s `[NS-44]` cites the sibling doc, not this section, by name); the original
heading is preserved below so `progress.md <date>` references still resolve.

- **2026-09-09 — a CI check that had never been able to fail, and what found it**

## Relocated 2026-09-01 — two sections moved verbatim 2026-09-13

Moved to `docs/archive/progress-2026-09-01-review-rounds-4-5.md` **verbatim**, not summarised — the
same precedent as every relocation above. **Why:** `progress.md` hit 520 of its 500-line CI cap after
the 2026-09-13 `[NS-51]` entry landed; these were the oldest full-detail sections not yet relocated.
Citation survival grep-verified before the move (`activeContext.md:40`, `[NS-48]`); each original
heading is preserved below and in the archive file, so existing `progress.md <date>` references
still resolve.

- **2026-09-01 (round 5) — why the exit-code table stopped enumerating, and the cost of four rounds**
- **2026-09-01 — the Request Changes round: what blocked, and two reversals of my own**
## Relocated 2026-08-29 → 2026-08-31 — four sections moved verbatim 2026-09-11

Moved to `docs/archive/progress-2026-08-29-to-31-gap-fixes-and-durable-lessons.md` **verbatim**, not
summarised. **Delta, not a level: 12,448 bytes moved out.** Without the move this file could not have
accepted the 2026-09-11 entry at all — the same cap deadlock recorded on 2026-08-23 and 2026-08-28.
No level is quoted, and none should be reconstructed from this stub: read both margins live against
`pmb-health.yml`'s caps.

Citation survival grep-verified before the move; each original heading is preserved below and in the
archive file, so existing `progress.md` <date> references still resolve.

**STILL OPEN — carried forward, not relocated.** The four sections below are archived narrative, but
four of their findings are self-marked unfixed, and `CLAUDE.md` loads `memory-bank/` only, so the
archive cannot hold a live rule. (1) **The BLOCK-tier hook receives TRUNCATED payloads**:
`.pmb-hook-errors.log` has carried `Unterminated string` since 2026-08-17, the hook then falls back
to matching raw text, and **a BLOCK substring past the truncation point is not seen** — undiagnosed,
and separate from the OEM-code-page fix. (2) **Mutate a scratch copy, not the shared tree** —
copy-aside-and-restore can revert a peer's concurrent edit, and checksum-verifying the restore proves
your copy intact, not that nobody else wrote. (3) ACR availability is decided in two places with
different criteria, and `mb preflight` reads `ACR_VER` without ever comparing it. (4) `show_slim()`
and `Show-Slim` exist in both shells and are dispatched from neither.

- **2026-08-31 (post-review) — the gap fixes, and the one finding that came from reading ACR's source**
- **2026-08-30 — two durable lessons; the change itself is in the commit message**
- **2026-08-30 — Contract 1: what the commit message cannot carry**
- **2026-08-29 — absence-claim scope rule (`a11e4df`); a review-gate defect recorded**

## Relocated 2026-08-31 — “what four Opposition rounds cost, and the one rule worth keeping”, moved verbatim 2026-09-09

Moved to `docs/archive/progress-2026-08-31-opposition-rounds.md` to clear the 500-line CI cap; this
file stood at 498/500 and could not accept the dated entry the `PreCompact` gate requires — the gate
demanded exactly what the cap forbade, and the gate was measured exiting 2 before this pass.
**18,208 bytes and 173 lines moved out.** Stated as a delta rather than
before/after totals, which decay on the next edit. Second occurrence of this bind; see the archive
file's header for why that is structural rather than incidental.

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

## Relocated 2026-07-02 → 2026-08-10 — "Earlier Work", moved verbatim 2026-10-14

Moved to `docs/archive/progress-2026-07-02-to-08-10-earlier-work.md` **verbatim** to fund the
PR #55 delta under the ratchet. Delta and citation check: that file's header.

- **Earlier Work (2026-07-02 through 2026-08-10) — condensed, full detail archived**

## Backlog

Deferred pending operational evidence: handoff CLI, pinned.md, mb update --from-git, mb privacy.

## Reference Sections — relocated 2026-08-23

Project inventory, scope-delta vs enterprise, the 2026-06-19/24 session summary, and satellite-project
pointers moved **verbatim** to `docs/archive/progress-reference-sections-2026-08-23.md` to recover line
headroom under the 400-line CI cap. Nothing was condensed or rewritten. `## Backlog` stays above because
it is still actionable. One-time recovery, not a fix — see `[NS-35]` decision 3.
