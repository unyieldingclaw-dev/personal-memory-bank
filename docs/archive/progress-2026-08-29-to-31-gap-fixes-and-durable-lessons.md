# Archived `progress.md` sections — 2026-08-29 to 2026-08-31

Moved here **verbatim** on 2026-09-11 so that `progress.md` could accept that day's entry at all:
without this relocation that file would have exceeded its CI caps. No level is quoted: read the live
margins against `.github/workflows/pmb-health.yml`'s caps. Nothing was summarised,
condensed, or deleted; this file carries four byte-identical slices of the sections listed below,
concatenated in their original order.

**Delta, not a level: 12,448 bytes moved out of `progress.md`.** A before/after total would
decay the moment anything else in either file changed.

`progress.md` keeps a stub preserving all four headings, so existing citations of the form
"`progress.md`'s 2026-08-31 entry" still resolve there. Citation survival was checked by grep before
the move; the enumeration that stood here has been deleted because one of the four references it
named did not exist. Re-derive the live set instead of trusting a list:

```
grep -rnE 'progress\.md.{0,4}2026-08-(29|30|31)' memory-bank/ docs/
```

## Sections in this file

- 2026-08-31 (post-review) — the gap fixes, and the one finding that came from reading ACR's source
- 2026-08-30 — two durable lessons; the change itself is in the commit message
- 2026-08-30 — Contract 1: what the commit message cannot carry
- 2026-08-29 — absence-claim scope rule (`a11e4df`); a review-gate defect recorded

---

## 2026-08-31 (post-review) — the gap fixes, and the one finding that came from reading ACR's source

Committed `6cae656` on an Approve verdict with eight accepted limits; these close five of them. What the
commit message cannot carry:

- **The most valuable finding of the whole review came from the ONE reviewer who opened the tool's source.**
  Five domain agents reasoned about ACR from this repo's prose; Opposition read
  the ACR build via the global `npm link` — NOT a `node_modules/` directory inside this repo, which does not exist. Measured there: `security` and `adversarial` both carry
  `exclude: ['**/*.md']`, and the whole-agent "skipped by agentPolicy" line renders **only when EVERY changed
  file matches** the exclude. So a markdown-dominant diff containing **one** non-markdown file emits **no Policy
  line at all** while those agents review only that file. `filteredFiles` records it; the markdown formatter
  never prints it. **That is the shape of most diffs in this repo**, and none of row 0's three signals fires on
  it. A fourth signal was added TO THE TABLE and, in that first pass, **NOT to the procedure** — step 3 carried no
  `--format json`, so the row instructed a check the workflow could not produce. Caught by four review domains and
  fixed in the follow-up; recorded here because the first version of this entry called it closed. **Generalises: reviewing a tool's
  behaviour from your own documentation of it cannot find a gap your documentation shares.**
- **EVERY "ACR 1.15.0" MEASUREMENT IN THIS RECORD IS MISLABELLED, and the peer supplied the sharper rule.**
  **THIS REPO ALREADY HAD THIS RULE.** `[NS-27]` recorded it on 2026-08-19 — *"Pin the version or record the SHA
  before treating any ACR run as evidence"* — in `docs/archive/context-2026-08-22-verbose-next-steps.md`, live-pointed
  from `activeContext.md`. The pointer was not followed; the rule was re-derived via an ACR source dive and a peer
  round-trip and then credited to the peer. **A direct counter-example to `[NS-47]`(d)**, committed the same session,
  which claims relocate-verbatim-plus-pointer means only what is LOADED loses detail. Here the detail was archived,
  pointed at, on-topic — and still not retrieved. Resolution decayed on the READ path exactly as the objection that
  killed Lumina's time-decay predicted. Mechanism, restated:
  `ai-review-agent` here is an `npm link` into their working tree: `dist/` is whatever branch they have checked
  out, built, changing without warning. **A version string is not an artifact identity.** My morning note only
  said "a run straddling a rebuild has no clean signal" — too weak. Findings stand (they verified the
  markdown-exclusion path in their own `src/`), but the labels become *linked working tree, commit
  indeterminate*. `npm pack ai-review-agent@<v>` for anything asserted about the PUBLISHED tool. This also
  closes the `earlyExit` discrepancy outright: the gating is on their `fix/early-exit-visibility` branch and I
  read the memory-bank branch — my refusal to resolve it by guessing was the correct call on the evidence.
- **I checked the peer's grep instead of accepting it, and it was overstated in a way that mattered.** They
  reported `filteredFiles` reaching ZERO surfaces ("all producers, no renderer anywhere"). True of the four
  RENDERED surfaces — but `runner.js` spreads the field onto the RESULT OBJECT and `formatJson()` is a raw
  `JSON.stringify(result)`, so `--format json` carries it with no formatter opting in. **Had I taken the grep,
  my new exit-0 fourth signal would have instructed a reviewer to check a field that does not exist.** A grep
  over renderers cannot see a value that ships by being a property of the serialised object.
- **A cause I had listed under exit 1 does not produce exit 1.** Measured against 1.15.0: a missing diff file
  exits **4**. Three of the five listed causes measured correct, one wrong, one unmeasurable at this version —
  against a cell that claimed "all four cases measured". Removed from row 1; row 4 was right all along. The
  five-vs-four arithmetic was flagged by three domains and resolved by none of them; measuring resolved it.
- **Every byte figure this session produced was CRLF-biased.** `.gitattributes` is `eol=lf`, `progress.md` is
  CRLF in the worktree, so `wc -c` overstates by exactly one byte per line against the blobs CI measures
  (33,375 vs 32,996 = +379 for 379 lines). The archive header's 30,448 was 213 bytes high for 213 lines. All
  figures re-measured with `git cat-file -s`. **Measure the artifact CI measures, not the one on your disk.**
- **Seven stale levels replaced with DELTAS, not refreshed levels** — Opposition's point, and the one I would
  have got wrong: refreshing is the remediation that already failed twice at `pmb-health.yml:190-193`. A
  re-measured level is true at the moment of correction and false after the next write.
- **The parity glob fix was mutation-proved to close the hole, not merely to look right.** `*.md` → `*` with
  `[ -f ]`, matching `mb.sh`'s discovery exactly. The mutation that was previously INVISIBLE (a non-`.md`
  template file) now goes RED, as does a non-`.md` live orphan. **Found independently by four of five domains**
  — the strongest corroboration signal in the review.
- **Table rationale moved out of the cells into the `Why` block.** Two cells had reached ~800 characters,
  mixing instruction with provenance and history, in a lookup table read under time pressure mid-review.
- **NOT fixed, and deliberately:** the
  Coverage Footer gained a `too old` value but ACR availability is still decided in two places with different
  criteria; nothing still tests `change-review.md`'s semantics, and the executable half (`mb preflight` reads
  `ACR_VER` and never compares it) is untouched.

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

