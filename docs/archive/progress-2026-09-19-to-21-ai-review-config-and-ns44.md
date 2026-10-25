# Archived: `progress.md` 2026-09-19 → 2026-09-21 — three sections relocated 2026-09-25

**Relocated from `memory-bank/progress.md` on 2026-09-25, verbatim** — lines copied by range, not
retyped; nothing summarised.

**Why:** the 2026-09-24 → 25 entry could not fit under the aggregate startup-context ratchet, which
had 410 bytes of margin against `origin/main`. **Delta, not a level: 2,162 bytes moved out** (this
file's body below the first `---`, LF). All three describe merged work whose live state is carried
by `activeContext.md`'s `[NS-44]`, `[NS-48]` and `[NS-56]`.

**Citation survival:** `[NS-48]` cites `progress.md` 2026-09-19 and `[NS-56]` cites 2026-09-21;
each original heading stays listed in `progress.md`'s stub, so both still resolve.

---
## 2026-09-21 — `ai-review.config.json` test guard ships (PR #40); mid-session data-loss recovery

Built `tests/test-ai-review-config.sh` (20 assertions, closes the loop `[NS-48]` opened) asserting only
on ACR's deterministic `policy`/`filteredFiles` fields, never finding content (non-deterministic: 3/4 runs
of the identical diff found nothing, 1 found `high`).

**Mid-session data loss:** `git checkout -- <file>` on a file only ever `git add -N`'d (intent-to-add, no
blob) reverted it to 0 bytes, not prior content — destroyed a fully-reviewed ~411-line draft with no
backup/stash/reflog trace. Reconstructed from conversation memory. General git pitfall, not PMB-specific.

CI-enforcement scope, array-symmetry correction: see commit `cf301a0` (not restated, per `[NS-42]`).

## 2026-09-19 — `ai-review.config.json` ships NS-48; first draft was a near-miss

First draft dropped `memory-bank/**`/`docs/**` from NS-48's own plan — caught by 2 domain reviewers
plus a peer's live ACR run reproducing 3 hallucinated findings on real `activeContext.md` prose.
Revised to restore those excludes plus `templates/docs/**`, narrow `fixtures/security/**` to its
README, and empirically confirm (live runs, not grep) `.claude/commands/security-review.md` and
`.claude/agents/security-reviewer.md` are safe to admit. Grep alone missed that narrative prose,
not just code fences, triggers the misread. **Round 2:** same gap on `templates/memory-bank/**`
— reproduced live (one run hit `high`); `examples/**` mirror added by analogy, confirmed via policy
check only.

## 2026-09-19 — NS-44 design (PR #33); NS-55 opened; write-rate fix confirmed insufficient

Design narrative in commit `31ad347`/PR body; shallow-clone mechanism in `[NS-55]` — not restated. Recorded here:
- `[NS-37]`/`[NS-51]`/`[NS-53]` verified genuinely done (PRs #25/#28 `MERGED`, fixes present in code) — evicted to fund this entry plus `[NS-44]`/`[NS-55]` inside the zero-margin ratchet.
- The write-rate fix ("stop restating commit messages") is correct but insufficient: this entry is compliant and still cost bytes against a ratchet at exactly 0 margin. `[NS-42]` remains open.
