# Finding: the startup-context ceiling is exceeded nearly fivefold, cannot fail anything, and the per-file caps that can are misallocated

**Status:** finding, not a design. Measured 2026-08-28. **Every figure here is a snapshot and nothing
re-verifies it — re-measure before acting.** Figures are the working tree of the commit
that introduces this file, which itself edits two of the measured files — they were recomputed after
the last such edit. No implementation proposed beyond an ordering
of options — each needs its own contract.

**Companion document:** `docs/MEMORY-BANK-PARADIGM-REVIEW.md` covers memory-bank sizing from the
paradigm/read-contract angle and carries its own measured table. This document is narrower: cap
*allocation* and *enforceability*. Read that one for the tiered-loading history, including decision 1,
which was designed and **dropped** on review.

**How this was found.** A contract was run to evict resolved `[NS-N]` entries from `activeContext.md`,
which sat 401 bytes from a hard CI cap that is a *required, enforce-admins* status check. The pass
cost a contract, a five-domain review, an Opposition **Request Changes**, and two rewrites, and
recovered **864 bytes** from the eviction itself. The commit's *realized* gain on the file is
**533**, after +82 of unrelated status edits and +249 for the `[NS-44]` pointer this document
required. Either ratio prompted measuring the constraint itself; the realized one is worse.

**Correction, 2026-08-28.** The first version of this document claimed no aggregate budget existed.
That was false and is corrected in §3. It was produced by grepping `standards/PERFORMANCE-BUDGET.md`
alone and generalising to the whole system — the fourth instance in one session of checking with the
wrong boundary. The corrected finding is stronger than the false one.

---

## 1. The measurement

Against `MB_FAIL_BYTES` and `MB_FAIL` in `.github/workflows/pmb-health.yml`:

| file | bytes | cap | used | lines | cap | used |
|---|---:|---:|---:|---:|---:|---:|
| `projectbrief.md` | 948 | 20,000 | **4.7%** | 33 | 120 | 27.5% |
| `systemPatterns.md` | 1,156 | 40,000 | **2.9%** | 40 | 300 | 13.3% |
| `techContext.md` | 1,152 | 40,000 | **2.9%** | 39 | 300 | 13.0% |
| `activeContext.md` | 44,066 | 45,000 | **97.9%** | 145 | 150 | **96.7%** |
| `progress.md` | 57,809 | 60,000 | **96.3%** | 409 | 600 | 68.2% |
| **capped total** | **105,131** | **205,000** | **51.3%** | | | |

Loaded at session start: the five files above plus `memory-bank/README.md` (1,116) and `CLAUDE.md`
(16,782) = **123,029 bytes**.

## 2. Finding — the per-file caps are misallocated, not too small

Three files consume **3,256 bytes of the 100,000** allocated to them (3.3%). Two consume **101,875 of
105,000** (97.0%). **~99,869 bytes sit unused under the caps while `activeContext.md` was 401 bytes
from making the PR unmergeable.**

The caps were set as five independent per-file ratchets; real usage concentrated in two. The resulting
pressure is an allocation artifact, and every relief pass so far has fought it rather than the thing
the caps exist for.

This does **not** argue for raising caps. That was rejected on record (`progress.md` 2026-08-26) on
sound grounds: `pmb-health.yml` defines the byte FAIL as a **downward** ratchet, and measured growth
of +24,355 bytes in three days means a raise buys about a day. Both still hold. The point is narrower:
the *distribution* is wrong, and redistributing is not raising.

**The line dimension binds nearly as hard and is easy to miss.** `activeContext.md` is at 96.7% of its
line cap (5 lines of headroom) while at 97.9% of its byte cap. Any redistribution that moves only
`MB_FAIL_BYTES` would leave the line cap binding almost immediately.

## 3. Finding — the aggregate ceiling exists, is exceeded nearly fivefold, and cannot fail anything

`scripts/mb.sh:1169` implements check 15, "Startup context size ceiling — WARN >15 KB, ERROR >25 KB".
It sums `CLAUDE.md` plus the five memory-bank files (**not** `README.md`) and compares against
hard byte thresholds of 15,360 and 25,600.

Current value: **121,913 bytes = 119.1 KB, or 4.76x the ERROR threshold.** Every `mb doctor` run
prints:

```
[ERROR] Startup context 119.1 KB exceeds 25 KB limit — compact memory-bank/ immediately
```

**And nothing happens.** `show_doctor()` has no failure exit path; `mb doctor` returns 0 while
printing that line, so the `mb-doctor-self-check` CI job passes. An `[ERROR]` that has been true for
an unknown length of time, is printed on every invocation, and gates nothing is indistinguishable
from decoration.

Two corollaries:

- **The budget is not missing; its teeth are.** `standards/PERFORMANCE-BUDGET.md` does contain no byte
  or aggregate limit — its only memory-bank row is `lines in progress.md <= 50`, ruled stale on
  2026-08-26 against a then-410-line file (now 409 against a CI cap of 600). But the ceiling lives in
  `mb.sh`, not the standard, and the standard does not mention it. The authority is split from the
  implementation.
- **This was already known and recorded.** `[NS-28]` in `activeContext.md` states: *"Measured
  2026-08-19: PMB's SessionStart footprint is ~22,072 tokens"*, and already recommends surfacing
  per-file share in `mb doctor`. Any future contract here is continuing that entry, not opening new
  ground.

**Consequence: passing CI is not evidence of health, and neither is a clean `mb doctor`.** The one
check that measures the quantity that actually matters is advisory by construction.

## 4. Finding — the write rate is behavioural, not structural

`scripts/pre-compact-check.sh` blocks compaction on two conditions: `activeContext.md` must have >=3
substantive lines, **and** `progress.md` must contain at least one entry dated today. The second
imposes no size requirement. The hook mandates *an* entry; convention supplies the volume.

Measured on this branch: commit `bf636e1` added **9,583 bytes** to `progress.md` in one commit, while
also carrying a **4,389-byte** commit message covering the same change. `activeContext.md` over the
same span was flat (43,702 -> 44,109 -> 44,599 -> 44,066).

`progress.md`'s own `2026-08-28 (continued)` entry already names this hazard — a frozen copy (the
commit message) and a mutable one (the entry), only the second correctable. Recorded, unaddressed.

## 5. Finding — eviction cannot reach the mass

`standards/MEMORY-BANK.md`'s `activeContext.md` eviction rows key on *resolved* status or an age test
of >14 days for entries that are not active blockers. `[NS-35]` is **5,823 bytes — 13.2% of the
file** — and satisfies neither: 5 days old and explicitly active. The criteria structurally exempt the
largest entries, because size correlates with being recent and active.

The eviction pass that produced this document recovered 864 bytes. One untouchable entry is **6.7x**
that.

## 6. Options, in leverage order

Each needs its own contract. Ordered by expected effect on the 123,029-byte session load.

1. **Stop restating commit-message content in `progress.md`.** Highest leverage, no mechanism needed,
   addresses the dominant write rate. Commit messages are permanent, searchable, and cost zero
   context; `progress.md` entries cost context at every session start forever. Candidate rule:
   `progress.md` records what a commit message cannot — cross-session state, decisions, and
   corrections to earlier entries — never a restatement of the change itself.
2. **Give check 15 teeth, or delete it.** It is the only mechanism measuring the real quantity and it
   cannot fail. Either make `mb doctor` exit non-zero on ERROR (which would immediately turn CI red at
   4.7x over, so it needs a migration path), or gate it in CI directly, or remove the ERROR vocabulary
   and stop implying enforcement that does not exist. Also reconcile the split between the ceiling in
   `mb.sh` and the silent `standards/PERFORMANCE-BUDGET.md`.
3. **Redistribute the per-file caps to match observed use, on both dimensions.** Stops manufacturing
   emergencies in two files while ~100 KB sits unused in three. Reduces no context cost; removes false
   ones. Must preserve the downward-ratchet property and must move line caps alongside byte caps.
4. **Revisit the eviction criteria last, if at all.** Low-yield by construction and unable to reach
   large active entries. `standards/MEMORY-BANK.md` already calls eviction symptom relief and names
   write rate as the binding constraint (`[NS-42]`).

## 7. Evidence, and how far verified

- **Measured this session, `wc -c` / `wc -l` against the working tree**, caps read from
  `.github/workflows/pmb-health.yml`: every figure in §1, the §2 roll-ups, and the 121,913 / 119.1 KB
  / 4.76x figures in §3 (recomputed by hand from the summands `mb.sh:1169-1175` uses).
- **Measured with `git show <sha>:<path> | wc -c`**: the `+9,583` and the `activeContext.md` flatness
  in §4.
- **Measured with `git log -1 --format=%B <sha> | wc -c`**: the 4,389-byte commit message in §4. The
  first version of this document said "~2,800" with no method behind it; that was wrong by 57% and is
  corrected here.
- **Verified by reading source**: check 15 at `scripts/mb.sh:1169-1181` including its thresholds and
  its lack of a failure exit; `pre-compact-check.sh`'s two conditions; `PERFORMANCE-BUDGET.md`'s
  Limits table.
- **Taken from the record, not re-derived**: the +24,355-bytes-in-three-days growth figure and the
  downward-ratchet rationale (`progress.md` 2026-08-26); the 2026-08-26 ruling that the 50-line row is
  stale; `[NS-28]`'s ~22,072-token measurement.
- **Not established**: whether redistributing caps is safe against the ratchet property; what the
  aggregate ceiling's correct value is, given it has been exceeded 4.7x for an unknown period without
  incident; and what migration path would let check 15 become blocking without turning CI red on the
  first run. All three are design questions this document does not answer.
