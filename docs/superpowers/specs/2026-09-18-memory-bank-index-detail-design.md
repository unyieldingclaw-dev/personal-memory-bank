# Design: activeContext.md Next-Steps Index/Detail Split (partially addresses [NS-44])

**This does not close `[NS-44]`.** `docs/MEMORY-BANK-CAP-ALLOCATION-FINDING.md:131-150` ranks four
options for that entry by leverage: (1) stop restating commit-message content in `progress.md` —
"highest leverage"; (2) give `mb doctor` check 15 teeth, or delete it; (3) redistribute the per-file
caps; (4) revisit the eviction criteria — "last, if at all... low-yield by construction." This design
is a fifth approach, closer in spirit to (4) but not identical to it, and touches none of (1)-(3);
(1) and (2) are explicitly out of scope below, (3) isn't addressed at all. Quantified: startup context
is currently 101,795 bytes against check 15's 25,600-byte ERROR threshold (3.98×); this design's own
best-case recovery (~14.5–15.5 KB) leaves roughly 86,800 bytes, still **~3.4× over**. `[NS-44]`'s
headline problem — "ceiling exceeded nearly fivefold, structurally unenforceable" — is reduced, not
resolved. Do not mark `[NS-44]` DONE on this document's authority alone; under this same design's own
lifecycle rule, doing so would collapse it to a stub and lose the still-open cap-misallocation and
check-15-enforcement findings it tracks.

## Problem

`projectbrief.md`'s immutable, non-negotiable requirement states: *"Memory Bank state is available
at session start: an index is loaded, detail is fetched on demand."* No mechanism implementing that
exists. The interim is "read every memory-bank file in full, every session" — which the requirement's
own meta-rule already names as a mechanism frozen into a goal-tier file, not the goal itself.

`activeContext.md` is where this actually bites: 44,182 bytes / 136 lines, **98.2% of its 45,000-byte
CI cap**. As of 2026-09-18, the aggregate startup-context byte ratchet against `origin/main` is at
**zero margin** (confirmed live by a peer session working the same repo) — meaning any further growth
anywhere in `CLAUDE.md` + `memory-bank/*.md` fails CI immediately.

Two prior attempts to shrink this file both failed, for specific, recorded reasons
(`progress.md`, 2026-09-11):
- **Rewrite-in-place**: verifying agents rewrote entries they had just checked and introduced factual
  errors at close to the rate they corrected — "a verifying pass is a good detector and a bad author."
- **Generated pointer relocation**: a non-greedy regex match terminated early on an inline code span,
  silently truncating `[NS-48]`'s title and dropping "NOT APPLIED" from a finding.

This design must not repeat either failure class.

**A directly analogous mechanism was already designed and rejected once — `[NS-35]` decision 1.** In
2026-08-26, an index-line-plus-on-demand-detail-file scheme (native "tiered loading," spanning the
whole memory bank) was designed, Opposition-reviewed, and dropped because the index didn't fit:
~117 bytes/item of budget was available against ~198 bytes/item measured
(`docs/archive/progress-2026-08-31-opposition-rounds.md`). That figure does not transfer to this
design unchanged, but it does not automatically clear it either — see "Alternatives considered" for
the corrected, scoped comparison this design's own numbers were checked against.

## Why `progress.md` is out of scope

`progress.md` already has a working mitigation: verbatim relocation to `docs/archive/` with a pointer.
`docs/RETRIEVAL-BASELINE-2026-09-09.md` measured 16/16 sessions loading the pointer and 0/16 fetching
the archived detail — a pilot signal that the pattern is at least not actively harmful, **not proof
that retrieval works when it's actually needed**; the source document itself is explicit that "zero
does not mean retrieval failed... equally consistent with the 16 sessions never needing the
narrative" and that it is "one pointer, n=16, one repo... not a general result." Cited here as
directional support for the pointer-plus-detail-file shape, not as validation. Its live size
(34,551 bytes, 62.8% of cap, down from 96.3% at the 2026-08-28 measurement) shows the mechanism at
least not making things worse as recent relocations landed. Its dominant remaining problem is
**write rate** — `standards/MEMORY-BANK.md` already states the fix: stop restating commit-message
content, since a commit message is permanent and costs zero context while a `progress.md` entry costs
context forever. That is a separate, already-identified, near-zero-risk fix, recommended as an
independent follow-up — not part of this design.

`projectbrief.md` + `systemPatterns.md` + `techContext.md` total **3,904 bytes** (measured:
`wc -c` gives 1,596 + 1,156 + 1,152), roughly **4.7%** of the five canonical memory-bank files'
combined mass (82,637 bytes — `projectbrief.md` + `systemPatterns.md` + `techContext.md` +
`activeContext.md` + `progress.md`; `memory-bank/README.md` is a sixth file, not counted here) —
`projectbrief.md` is Tier 1 IMMUTABLE, `systemPatterns.md`/`techContext.md` are Tier 2 STABLE per
`standards/MEMORY-BANK.md`'s Authority Tiers table (two different tiers, not one "stable" group);
both are rarely edited in practice. Splitting them adds indirection for a small fraction of the
problem.

## Scope

**Only `memory-bank/activeContext.md`'s numbered `[NS-N]` Next Steps entries.**

## Mechanism

Split each entry into two pieces:

- **Index line** — stays in `activeContext.md`, in the existing numbered-list format
  (`N. [NS-N] ...`), unchanged in kind so existing tooling that pattern-matches on it keeps working
  (`progress.md` itself documents `grep -cE '^[0-9]+\. \[NS-[0-9]+\]' memory-bank/activeContext.md`
  as the entry-count method). Contains: current state in one line, a pointer to the detail file, and
  an explicit **"open when:"** trigger. The trigger is load-bearing, not decorative — the
  retrieval-baseline document's own intervention found that a bare path/summary pointer isn't enough
  (`[NS-27]`'s archived rule was missed once and had to be re-derived because its pointer didn't say
  when to open it).
- **Detail file** — `docs/next-steps/NS-<N>.md`, one file per entry. Content is **moved verbatim**
  from the current inline text — not rewritten, not summarized. This is the anti-fabrication
  safeguard: the *only* newly authored content in a migration is the short index line. Everything
  else is a mechanical, diff-verifiable move, the same discipline `standards/MEMORY-BANK.md` already
  requires for `progress.md` → `docs/archive/` relocations ("verbatim means no condensing, no
  summarising, no rewriting").

Because each entry is written as a single dense physical line in the current file (confirmed:
`file` reports "very long lines"; no entry spans multiple raw lines), the migration's extraction
boundary is mechanical and unambiguous — an entry is exactly the one line matching
`^N\. \[NS-N\]`, start to end. This removes the multi-line-boundary ambiguity a more general rule
would need, and avoids the specific failure class (a boundary a regex gets wrong) that produced the
`[NS-48]` truncation.

No search engine, no database, no new runtime dependency (deliberately narrower than `context-mode`'s
SQLite-FTS5 approach, which was considered and rejected — see "Alternatives considered"). Because the
index itself gets small once detail moves out, "search" reduces to: read the small index at session
start, `Read()` a specific detail file when its trigger condition applies.

## File layout — a deliberate departure from the archive convention

`docs/next-steps/NS-<N>.md`, one file per entry. This differs from `docs/archive/`'s convention of
batched, date+topic-named files (e.g. `progress-2026-08-29-to-31-gap-fixes-and-durable-lessons.md`)
**on purpose**: archive files bundle a one-time relocation of several already-resolved narrative
sections; Next Steps entries are individually open and resolve on independent timelines, so each
needs its own addressable file rather than being bundled into a batch that doesn't yet exist. See
"Alternatives considered" for why `docs/backlog/`'s existing one-file-per-item convention wasn't
reused instead.

**Bound on `docs/next-steps/`:** unlike `docs/archive/` (write-once by convention) these files are
open-lifetime, so an explicit bound is needed rather than relying on the "archive files don't grow"
assumption. Proposed soft bound: flag (via the new `mb doctor` check below) any individual detail
file over 10 KB, and the directory as a whole if it exceeds roughly the count of open `[NS-N]`
entries times 2 KB — generous relative to the current entries' sizes, intended to catch runaway
growth rather than constrain normal use. This is advisory (WARN) via `mb doctor`, not registered in
`.github/workflows/pmb-health.yml`'s `DEST_WARN_BYTES`/`DEST_FAIL_BYTES` map (used today for
`docs/MEMORY-BANK-PARADIGM-REVIEW.md`) — that map is a per-file table rooted at `docs/$dest` guarded
by a file-existence check, so it can't take a growing directory of individually-named files without
being extended, which is an implementation decision, not a design one. **Correction: these files are
not exempt from CI regardless** — `pmb-health.yml` already runs a generic markdown-file-size FAIL
(>800 lines) across the repo and does not exclude `docs/next-steps/`. **This is a weaker backstop
than it sounds for this design's actual growth shape, though**: the generic check is line-count only
(no byte check, unlike the `memory-bank/` block above it in the same workflow), and each detail file
is, by this design's own mechanism, always exactly one physical line — so a file can grow arbitrarily
in bytes without its line count ever approaching 500/800. The `mb doctor` WARN above (byte-based,
10 KB/file and ~2 KB/entry aggregate) is the only control that can actually see this design's
characteristic failure mode (a single dense line getting denser, the same pattern that produced
`activeContext.md`'s original problem) — but it's advisory, not enforcing, the same distinction
`CLAUDE.md` draws between advisory and enforcement layers. The CI line check only catches unrelated
multi-line growth. If this needs to become a hard gate rather than a WARN, the intended path is
extending `DEST_WARN_BYTES`/`DEST_FAIL_BYTES` to take a directory (see above) — an implementation
decision to make if this bound proves insufficient in practice, not something this design assumes.

## Lifecycle on resolution

`standards/MEMORY-BANK.md`'s current Eviction Criteria table says *"Next Steps item completed → move
to `progress.md` immediately"* and *"Issue marked resolved → delete — do not archive."* Observed
practice has deviated from this for entries with live inbound citations: the 2026-08-28 eviction record
(`docs/archive/progress-2026-08-28-round3-gate-passes-and-brief-staleness.md`) stubbed a cited entry in
place rather than deleting it, explicitly noting this reflects "not a new convention." **Updated
2026-09-19:** a separate, still-open PR (#34, `77587d1`) instead deletes `[NS-37]`/`[NS-51]`/`[NS-53]`
outright, following the standard's literal text. Two of the three — `[NS-37]` (cited by
`[NS-38]`/`[NS-40]`) and `[NS-53]` (cited, as a load-bearing pointer inside a still-retained
superseded-plan banner, by `docs/superpowers/plans/2026-09-15-cross-tool-precompact-handoff.md:7`) —
are exactly the situation that record says to stub, not delete. That's the undocumented drift this
design exists to resolve: not a repo torn between two conventions, but one recorded convention the
written standard doesn't capture, that a good-faith cleanup pass can still violate by following the
letter of the stale rule instead. Evidence trail: `progress.md`'s 2026-08-26 entry and
`docs/archive/progress-2026-09-12-to-14-check15-and-baseline-health-ci-fixes.md`.

**Decision: follow observed practice, and fix the standard to match, as part of this work** —
deletion would lose citations other entries make to a resolved one, and the terse-stub-with-pointer
pattern is already validated in production for `progress.md`. Concretely, the table's two
`activeContext.md` rows are **replaced** (not supplemented) with:

| File | Condition | Action |
|---|---|---|
| `activeContext.md` | `[NS-N]` entry resolved | Collapse the index line to a one-line "✅ DONE" stub citing `progress.md` and/or the detail file; do not delete outright (preserves citations other entries may make) |
| `activeContext.md` | `docs/next-steps/NS-<N>.md` detail file for a resolved entry, no longer cited anywhere (verified by `grep`, not assumed) | Relocate verbatim into a batched `docs/archive/context-YYYY-MM-topic.md` file alongside other entries resolved in the same period, following the existing archive convention |

**This replaces the table's existing two rows because they directly contradict observed practice**
(this isn't a move to `progress.md`, and it isn't a delete) — adding a third row alongside two
contradictory ones would leave a reader with three disagreeing instructions instead of one gap.

**This edit must land in both copies of the standard, in the same commit: `standards/MEMORY-BANK.md`
AND `templates/standards/MEMORY-BANK.md`.** Checked directly: `templates/standards/MEMORY-BANK.md`
carries the identical two rows at the same line numbers, and `tests/test-mirror-parity.sh` explicitly
allowlists `MEMORY-BANK.md` out of its live/template byte-identity check
(`STD_DIVERGE_OK="AGENTIC-SAFETY.md MEMORY-BANK.md WORKFLOW.md"`). `standards/MEMORY-BANK.md` is also
in `mb.ps1`'s `$templateOwned` set, meaning `mb upgrade` force-overwrites it from the template on a
PowerShell adopter. If only the live file is edited, the next `mb upgrade` silently reverts this
entire lifecycle for any such adopter — the same `TEMPLATE_OWNED` self-reverting-scope failure
recorded as the second reason `[NS-35]` decision 1 was dropped. **Narrowing `STD_DIVERGE_OK` is not a viable option, not just a heavier one** — checked directly:
`standards/MEMORY-BANK.md` and `templates/standards/MEMORY-BANK.md` differ deliberately at the same
Eviction Criteria table's `progress.md` row (line 198 in both — the live copy names `pmb-health.yml`
specifically; the template names a generic `memory-bank-size.yml` an adopter would actually have),
immediately below the two `activeContext.md` rows this design edits (lines 196-197), so forcing full byte-identity would
require deleting an intentional, adopter-facing difference. The remaining option — a dedicated check
that diffs only the two Eviction Criteria rows this design touches, independent of the file's other
legitimate divergences — is what implementation should build. The requirement stated here is that
both copies change together and something checks that they did, not a specific mechanism.

**This is procedurally more complex than the two rows it replaces** (stub → cited detail file →
manual-grep-gated archive, versus an unconditional move-or-delete) — stated plainly as a trade of
simplicity for citation-preservation and consistency with the already-working `progress.md`
convention, not as a pure simplification.

**Row 1 of the same table** ("Entry > 14 days old and not an active blocker → archive") can overlap
with the revised rows above for a completed entry that's also past 14 days — both paths terminate at
the same archive convention, so the practical divergence is small, but this pre-existing ambiguity is
worth noting since this design already touches the table.

**Existing `mb doctor` check 23 ("Stale next step") is already dead code in both shells** — it matches
bullet-list regex `^\s*[-*]` (`scripts/mb.sh:1518`, `scripts/mb.ps1:1839`) against a file that has used
a numbered list for its entire observed history. This design's migration work should fix or remove
check 23 rather than leave it, since it directly overlaps the section this design restructures.

## Search integration

`mb query <keyword>` already exists (`scripts/mb.sh:1886`, `show_query()`) but only greps frontmatter
tags and `## ` markdown headers — `[NS-N]` entries are numbered-list items under one `## Next Steps`
header, so today's `mb query` cannot find an individual entry at all.

**Decision: keep the numbered-list index-line format** rather than switching to markdown
sub-headings — switching would make entries `mb query`-discoverable for free, but would break the
existing `grep -cE '^[0-9]+\. \[NS-[0-9]+\]'` counting convention that other files already reference
by name. Not worth the breakage for the gain.

Instead, `show_query()` (and its PowerShell twin) gets a small additive change: also grep
`activeContext.md`'s Next Steps index lines directly, in addition to its existing tag/header search.
Small, isolated, no new subsystem.

**Shell-twin parity requirement, and the correct mechanism for it.** This repo's history has a long,
expensive record of bash/PowerShell divergence causing real bugs (a trailing-newline hash mismatch, a
case-sensitivity gate hole, a gate "wired to one of two doors" because only one matcher was updated).
`tests/test-mirror-parity.sh` is **not** the right gate for this: it only compares `TEMPLATE_OWNED`
declaration arrays and byte-diffs template mirrors — `mb.sh`/`mb.ps1` aren't even present under
`templates/scripts/`, so it structurally cannot detect a behavioral divergence in either script. The
repo's actual convention for this is a dedicated test block inline in the feature's own test file,
run under `pwsh` directly (e.g. `tests/test-mb-doctor.sh` for check 15, `tests/test-mb-commit.sh`,
`tests/test-mb-version-notifier.sh`). The `show_query()` change lands in `mb.sh` and `mb.ps1`
together, in the same commit, with matching cases (including a no-match/negative case) added to
`tests/test-mb-query.sh` for both shells before being considered done.

## Anti-fabrication safeguard for migration

Every migrated entry produces exactly two artifacts, and this design's guarantees for them are
different in kind — stated precisely so neither is oversold:

1. **A detail file**, which must be **byte-identical** to the original entry's full text — mechanically
   verifiable, and mechanically producible, given the single-physical-line boundary rule above: the
   detail file's body is exactly the migrated line's post-marker text, byte for byte. `scripts/verify-
   ns-migration.sh` (to be added under `scripts/`) checks this mechanically: diff the detail file
   against the pre-migration git blob for that line, and run the citation-survival grep (search the
   rest of the repo for any inline citation of the entry being moved, confirm each still resolves
   after the move — same practice already used for `progress.md` → `docs/archive/` moves). This is
   the check that guards against the `[NS-48]`-class failure (content silently dropped from the repo):
   a byte-diff mechanically catches any truncation, full stop.
2. **A new index line**, which **is** newly authored. Whether it faithfully preserves what's
   load-bearing from the original (a qualifier like "NOT APPLIED," a correction, a scope limit) is a
   **semantic judgment, not a mechanical one** — consistent with this design's own stated philosophy
   for its `mb doctor` checks ("observable integrity signals only, not semantic correctness, no LLM
   judgment involved"). No script checks this, and none is proposed to. The safeguard here is
   narrower and different in kind: because the detail file is byte-identical and one `Read()` away,
   an under-signalling index line is a **retrieval-completeness risk** (the reader might not know to
   open the detail file), not a content-loss risk (the content is never gone) — and it's caught, if
   at all, by ordinary migration-commit review, the same as any other new prose in this repo.

`scripts/verify-ns-migration.sh` gets its own test file (`tests/test-verify-ns-migration.sh`,
matching the convention every other new mechanism in this design already commits to) — for symmetry
with the `mb doctor` check and `show_query()` fixes, not because a design-stage doc must specify tests
for every future script (most specs in this repo don't).

Migrations happen as **small, independent, individually-reviewable diffs** — never a single large
rewrite pass. Both prior failures were large, single-pass attempts; this is the specific shape to
avoid.

## Rollout

Measured entry sizes (each entry is one physical line; measured directly with `awk`, cross-validated
against `sed`/`head`/`wc`) identify the actual highest-leverage targets. The 9 largest entries —
`[NS-26]` (2,920 B), `[NS-25]` (2,587 B), `[NS-29]` (2,155 B), `[NS-35]` (1,862 B), `[NS-18]`
(1,837 B), `[NS-28]` (1,818 B), `[NS-48]` (1,620 B), `[NS-19]` (1,609 B), `[NS-47]` (1,490 B) —
total 17,898 bytes, **~40.5% of the file's current mass** (17,898 / 44,182), out of 51 entries total.
An earlier pass of this measurement used a block-accumulation method that mis-attributed one entry's
boundary and produced a wrong figure for a since-corrected 9th entry; the list above is the
re-verified one, cross-checked with three independent single-line measurement methods.

1. Migrate those 9 entries first, each as its own small commit, as the initial implementation task.
2. All new or substantially-edited `[NS-N]` entries use the split convention from creation onward.
3. Remaining small entries migrate opportunistically when next touched — not forced in bulk. This
   leaves the file in a **permanently mixed format** (some entries split, most not) indefinitely.
   That is the intended steady state, not an unfinished migration — forcing full conversion in one
   pass is exactly the large-single-pass shape both prior failures had.

### Worked example (validates the recovery estimate below)

`[NS-26]` is the largest entry (2,920 B) and among the most operationally dense — a bare one-line
summary would lose the "do not rebase or replay" warning that makes it load-bearing. A realistic
migrated index line, measured directly (`wc -c`, 373 bytes including a trailing newline):

> `26. [NS-26] Review-gate Layers 2+3 port — supersedes [NS-15]. Two bundles designed (A: atomic`
> `marker-peek flip, ~14 files; B: independent CI containment), neither implemented. **Open when:**`
> `touching review-gate/hook files, planning a worktree-branch port, or before assuming [NS-15]'s`
> `rebase/replay approach is current (superseded, unsafe). →` `docs/next-steps/NS-26.md`

That's **~372 bytes of content — an 87% reduction** on this entry. Denser entries need more room for
a trigger that's actually specific enough to be useful; thinner ones will compress harder. The
recovery estimate below uses this worked, measured ratio.

**This design is narrower than the `[NS-35]` decision-1 attempt it descends from, and its own numbers
clear the bar that one failed.** That attempt's budget was ~117 bytes/item available (whole-memory-bank
index, after `README.md` and mandatory frontmatter) against ~198 bytes/item measured — short by 1.7×.
This design's available budget, scoped to `activeContext.md` alone, is
`(45,000 cap − 5,254 non-entry bytes) / 51 entries ≈ 779 bytes/item`; the worked measurement above is
~372–375 bytes/item — **2.1× headroom**, not a shortfall. The earlier attempt's failure doesn't
transfer to this one because the scope and the resulting per-item budget are both different, not
because the underlying index/detail-file idea was wrong.

## Validation — new `mb doctor` structural check

Purely structural, matching `mb doctor`'s existing "observable integrity signals only, not semantic
correctness" philosophy. No LLM judgment involved in the check itself:

- Every detail-file link in an index line resolves to an existing file (orphan-link / typo
  detection), **and, as a separate fire condition with its own fixture**, the resolved path stays
  under `docs/next-steps/` (a path-confinement guard so a hand-edited link can't point outside the
  intended directory, e.g. escaping to `../../standards/`) — two distinct failure modes needing two
  distinct fire-case fixtures, matching how the existing check-25 convention already pairs each
  failure mode with its own case rather than one shared one.
- Every file under `docs/next-steps/` is referenced by at least one index line (orphaned detail file
  detection).
- **Every index line that carries a `docs/next-steps/` link also carries an "open when:" trigger**
  (a greppable, purely structural check — presence of the substring, not judgment of its quality).
  The trigger is the one element this design calls load-bearing (the `[NS-27]` incident it cites as
  motivation was exactly a pointer with no trigger, missed and re-derived); this check is what
  actually enforces that, rather than just asserting it in prose. It cannot verify the trigger is
  *good*, only that migration didn't skip writing one.
- **Among index lines that carry a `docs/next-steps/` link** (i.e., already-migrated entries — the
  only lines this check can distinguish from not-yet-migrated ones, since both use the same
  `N. [NS-N]` format), exceeding a length threshold (proposed: ~400 bytes, checked against the worked
  example's measured ~373 bytes, with headroom rather than a tight margin — the worked example sits
  only ~27 bytes under a bare 400 B line, and the doc's own point is that denser entries need *more*
  room for a specific trigger, not less; the threshold should be expected to need tuning once the
  first 9 migrations produce real index lines, not treated as fixed) WARNs — catches the index
  re-bloating before it becomes a crisis again. Scoped deliberately to migrated lines only:
  measured today, 33 of the 51 not-yet-migrated entries already exceed 400 bytes, and the Rollout
  section's "permanently mixed format" steady state means most of them stay that way indefinitely by
  design — an unscoped check would WARN on roughly two dozen entries forever with no remediation path,
  defeating its own purpose.
- Entries marked "✅ DONE" older than 14 days (matching the standard's existing age test) that haven't
  been evicted per the Eviction Criteria table above WARN — partial mitigation for the limitation
  below.
- Individual `docs/next-steps/NS-<N>.md` files over ~10 KB, or the directory's aggregate size
  exceeding roughly 2 KB per open entry, WARN (see "Bound on `docs/next-steps/`" above).
- The Next Steps section contains no line that is neither a numbered `[NS-N]` entry, a blank line,
  nor a `## ` header — turning "every entry is currently a single physical line" (the assumption the
  whole extraction-boundary mechanism depends on) from a fact true today into a continuously-checked
  invariant, so a future entry hand-wrapped across multiple lines WARNs instead of silently breaking
  a later migration's boundary detection.

**Updated 2026-09-19 — this design's own drift examples may be gone by the time the check exists.**
`[NS-37]`/`[NS-51]`/`[NS-53]` — discussed above as the entries a separate, still-open PR (#34,
`77587d1`) targets for outright deletion — may not be live by the time this check is implemented. This
design is a spec only: the DONE-entry-WARN check has no implementation yet, so it has no "first run"
until a later plan lands the code, by which point these entries (and possibly others) may already be
gone regardless of merge order between this doc and #34. The synthetic fire-case fixture below is
therefore **load-bearing, not a formality**: it's the only proof this check can fire that doesn't depend on any
particular backlog existing when it's implemented — exactly the "check that cannot fail" trap this
repo's own standard warns against.

**Every new WARN condition needs a dedicated fire-case fixture, not just a clean-input pass** — per
this repo's own rule that "a check that cannot fail does not count as a check"
(`standards/CODE-REVIEW.md`), matching the existing convention at `tests/test-mb-doctor.sh` (e.g.
check 25 pairs every fire-case with a false-positive-avoidance case). Success criteria below require
this explicitly.

Same shell-twin-parity requirement as above: this check lands in `mb.sh` and `mb.ps1` together, with
matching fixtures in `tests/test-mb-doctor.sh` for both shells, in the same commit —
`test-mirror-parity.sh` does not cover this and should not be cited as though it does.

## Explicit limitations

- **Does not fix why weekly eviction (`activeContext.md` is Tier 3, documented "evict stale content
  weekly") apparently isn't happening.** This design reduces bytes-per-entry, not entry-count growth.
  If eviction discipline doesn't improve, the index itself can eventually re-bloat — 200 entries at
  ~250 bytes each is ~50,000 bytes, back near today's cap. The new doctor check above gives partial,
  not complete, mitigation. Not solved here; flagged for future attention if it recurs.
- **Adds a recurring cost, not just a one-time migration cost**: every future archival of a resolved
  entry's detail file requires the citation-survival grep, layered on top of the identical, already-
  existing burden for `progress.md` relocations. Not automated away by this design — the verification
  script above checks it mechanically, but a human/agent still has to run the migration itself.
- Does not touch `progress.md` (separate, already-identified fix, recommended as an independent
  follow-up: stop restating commit-message content).
- Does not give `mb doctor` check 15 (the aggregate startup-context ceiling) an actual exit code —
  it remains advisory; the real CI gate is the ratchet-vs-`origin/main` comparison. Separate,
  already-identified item, out of scope here.

## Alternatives considered

**`context-mode`-style SQLite FTS5 index (rejected).** Researched as the originating idea for this
design. Rejected because: (a) it requires Python's `sqlite3` module, which would deepen an already
unreconciled Tier-1 conflict — `projectbrief.md`'s "no external dependencies" constraint is already
silently violated by `_review-gate-lib.sh`/`check-contract.sh` shelling out to `python3`, and adding a
second, larger dependency on the same unresolved conflict compounds rather than resolves it; (b) once
the index itself is small (the actual goal here), a search engine is solving a problem that no longer
exists for this scope — plain-text index + `Read()`-on-demand is sufficient and simpler.

**All 5 memory-bank files uniformly (rejected).** `projectbrief.md`/`systemPatterns.md`/
`techContext.md` combined are ~4.7% of the five files' mass and stable-tier. Not worth the added
indirection for a small fraction of the problem.

**`[NS-35]` decision 1's whole-memory-bank tiered index (rejected as scoped, re-evaluated narrower —
see the Rollout section's worked example for the budget comparison that shows why this design's
narrower scope clears the bar that attempt failed.)**

**`docs/backlog/`'s existing one-file-per-item convention (considered, not reused).**
`docs/superpowers/specs/2026-07-14-backlog-design.md` already defines exactly this shape — one file
per item under `docs/backlog/<slug>.md`, a frontmatter status lifecycle, a `staleness-threshold`, and
full `mb backlog add/list/show/promote/dismiss` tooling. It was not reused because the two things
being tracked are semantically different: backlog items are *parked, not-yet-prioritized* ideas
awaiting a decision to pursue (`open`/`promoted`/`dismissed`), while Next Steps entries are *already
active, currently tracked* priority work — an entry doesn't need "promoting" into relevance, it's
relevant now. Conflating the two lifecycles would blur that distinction. The CLI-tooling *pattern*
(dedicated list/show/add commands) is still a reasonable model for how `docs/next-steps/` tooling
could eventually be built, even though the underlying status lifecycle doesn't transfer.

## Success criteria

- `activeContext.md` byte count drops by roughly the front-loaded migration's recovery — the worked
  example measured an 87% reduction on the densest of the 9 targeted entries (17,898 B → roughly
  2,300–3,400 B inline, i.e. **~14.5–15.5 KB net recovery**), verified by measurement against the
  live file once migrated — not asserted from this document.
- New `mb doctor` structural check passes with zero orphans / zero missing links / zero missing
  triggers on the migrated set, **and** each new WARN condition has a dedicated fixture proving it
  fires, not only a clean-input pass.
- Citation-survival grep run and clean for every migrated entry, checked by the verification script
  named above, not self-reported.
- `scripts/verify-ns-migration.sh` has its own test file, `tests/test-verify-ns-migration.sh`,
  covering both its checks (byte-identity, citation-survival) with at least one fire case each —
  named in "Anti-fabrication safeguard" above but not previously gated here, so an implementation
  could otherwise ship the script without it.
- Aggregate startup-context ratchet vs. `origin/main` does not regress (must be net negative, given
  the currently-zero margin).
- `standards/MEMORY-BANK.md` **and** `templates/standards/MEMORY-BANK.md` both updated with the new
  lifecycle rows, in the same commit, with the live/template divergence for **these two rows
  specifically** verified closed (not just assumed from the general `STD_DIVERGE_OK` allowlist, and
  not extended to the table's separate, intentionally-divergent `progress.md` row at line 198, which
  must keep differing).
- `show_query()` (both shells) extended to grep Next Steps index lines, with match, no-match, and
  both-shell cases added to `tests/test-mb-query.sh`.

## Provenance

Originated from a survey of external repos (`context-mode`, `claude-dashboard`, `worktrunk`,
Alibaba `open-code-review`, `ECC`, `agent-skills`, `Logic-Loop`, `deckgauge`, `campus-ai-os`,
`Reckoner`) requested 2026-09-18. `context-mode`'s index/detail-on-demand mechanism was the direct
inspiration; the design that resulted departs from it structurally per "Alternatives considered"
above. Byte/line/cap figures measured live against this repo on 2026-09-18 (superseding the stale
2026-08-28 figures in `docs/MEMORY-BANK-CAP-ALLOCATION-FINDING.md`); origin/main ratchet-margin and
worktree-conflict state confirmed via cross-session coordination with a peer PMB session
("PMB full review and PR #12 disposition") working the same repository concurrently.

This design went through a full `/code-review` pass (5 domains + Opposition, 2026-09-18) that
returned a **Request Changes** verdict on an earlier draft, with two blocking findings: (1) this
draft's Eviction Criteria table edit didn't account for the `templates/standards/MEMORY-BANK.md`
mirror and would have self-reverted for PowerShell adopters via `mb upgrade` — the exact
`TEMPLATE_OWNED` failure class that dropped `[NS-35]` decision 1 before; (2) the shell-twin-parity
safeguard was pointed at `tests/test-mirror-parity.sh`, which cannot detect the divergence it was
cited to guard against. Both are fixed in this version. The review also caught a real measurement bug
in the original rollout list (`[NS-52]` was measured via a buggy multi-line accumulation script and
overstated at 1,679 B against an actual 647 B; the true 9th-largest entry, `[NS-47]`, was missing) —
also fixed, and cross-validated with three independent single-line measurement methods this time.

A second full `/code-review` pass (2026-09-19, after the branch was fast-forwarded onto a newer
`origin/main`) again returned **Request Changes**, with one blocking finding: the title claimed this
design "closes `[NS-44]`," which `docs/MEMORY-BANK-CAP-ALLOCATION-FINDING.md`'s ranked options show
is false — this design implements none of that entry's top three leverage options and, even at its
own best-case recovery, leaves startup context ~3.4× over check 15's ERROR threshold. Retitled to
"partially addresses," with the gap stated explicitly above. Two Testing findings from that same round
(a semantic-content-loss check and an unnamed template-mirror-parity mechanism) were raised as
High/Blocking and then downgraded by Opposition with specific counter-evidence — recorded here because
that reasoning shaped this version: the byte-identity check mechanically guards against content loss
(the `[NS-48]` failure class), but cannot and does not claim to guard index-line *faithfulness*, which
is now stated as an explicit, honest limitation rather than an oversold guarantee (see "Anti-fabrication
safeguard for migration"). Also added from that round: a structural check that a migrated index line
actually carries an "open when:" trigger, closing the gap between calling the trigger load-bearing and
having nothing verify one exists.