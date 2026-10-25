# Archived: `progress.md` 2026-09-01 — two sections, moved verbatim 2026-09-13

**Relocated from `memory-bank/progress.md` on 2026-09-13**, unchanged. **Verbatim, not summarised** —
the same precedent as every prior relocation in this file: content is moved, never condensed.

**Why:** `progress.md` reached **520 of its 500-line CI cap** after a new 2026-09-13 dated entry
(the `[NS-51]` `$env:USERPROFILE` root-cause fix) had to land — the same `PreCompact`-gate pressure
that drove every relocation before this one. These two sections were the oldest full-detail entries
not yet relocated.

**Citation survival was grep-verified before the move**: `grep -rn "2026-09-01" memory-bank/activeContext.md`
found two references, both citing the date generically (`progress.md`'s 2026-09-01 entries) rather
than a specific line — `activeContext.md:40` (superseded-history pointer) and `[NS-48]` (ACR markdown-exclude
finding). Both resolve against the stub heading left in `progress.md`, unchanged from the original.

---

## 2026-09-01 (round 5) — why the exit-code table stopped enumerating, and the cost of four rounds

- **Round 4's remediation produced FOUR new blocking findings across three domains, one live-reproduced.** Security
  built a diff with an oversized file section, ran `--chunk --format json`, watched the console print "Diff
  truncated" — and the JSON carried **no `truncation` key at all**, exit 0. `chunkRunner`'s merge drops it. So the
  first of the four signals I had just wired was structurally unreachable, and exit `3` is dead code for this
  workflow. Correctness found row `1` still naming a markdown banner that `--format json` never emits. Architecture
  Drift found row `0` and the last-chunk-wins caveat giving OPPOSITE verdicts for the same state — a
  self-contradiction introduced inside the block rewritten to remove a self-contradiction.
- **THE DIAGNOSIS, and it is the durable part: we were maintaining a precise static description of a moving
  target.** `ai-review-agent` is an `npm link` into another session's working tree, on an arbitrary branch, rebuilt
  without warning; its behaviour changed at least THREE times during one session, and `--version` does not identify
  what ran. Every enumeration was correct when written and wrong by review time, and each correction introduced a
  fresh contradiction because the file carried five interlocking claims about internals. **Defect rate stayed flat
  across rounds 3-5 while care increased — that is the signal that the approach, not the diligence, was wrong.**
- **Fix: state the INVARIANT, not the enumeration.** Exit `0` never earns an unqualified clean pass; the field list
  is explicitly INDICATIVE, not exhaustive, with the two known-unreliable fields named. **The lookup surface shrank per ROW
  and the file did not:** the two rewritten ROWS lost 537 B per mirror (row `0` 1,042 -> 756, row `1` 890 -> 639 —
  whole-row lengths, not single cells; a later review measured cell 4 alone and got different figures for that reason; and row `0` was rewritten AGAIN in `c84b06d` to 1,198 B, its longest yet, so 756 is a round-5 figure and not a current one),
  while each mirror grew 2,340 B net, because the rationale moved out of the rows into a longer block quote that
  adds internals of its own. An earlier draft of this bullet claimed ~4,850 characters DELETED across both mirrors —
  sign-inverted, and caught by the round-6 review. Removing three of the four blocking findings **by deletion rather
  than by another correction** is what the fix bought; a smaller artifact is not. Generalises: **when a description of an external
  system keeps going stale faster than you can correct it, stop describing the system and state what must hold
  regardless of it.**
- **The fourth blocking finding was a different class and is fixed separately.** `MEMORY-BANK-CAP-ALLOCATION-FINDING.md`
  restated five cap values CI ratcheted DOWN on 2026-08-30, and §2's finding had already been ACTED ON — the caps
  moved *because of it*. Dating covers a decaying measurement; **a restatement of governing config that changed
  structurally needs superseding, not dating.** Fifth instance of the class `standards/MEMORY-BANK.md` already
  tracks. Banner added; caps now point at `pmb-health.yml`.
- **Also caught: condensing `[NS-47]` pointed its detail at a Downloads file** — out of repo, uncapped,
  unreviewable in a PR, which are the exact two disqualifiers `[NS-35]`(2) used to reject native auto-memory as a
  store. Six facts existed nowhere in the repo. Entry now marks the destination OUT OF REPO and names `progress.md`
  as the in-repo source. **Relocating detail out of a capped file into an uncapped one is hiding, not archiving.**
## 2026-09-01 — the Request Changes round: what blocked, and two reversals of my own

- **The blocking finding was not about operational risk, and that distinction is the useful part.** Row `0`'s
  fourth signal was unreachable, but the row it replaced instructed no body reading at all — so nothing got
  WORSE. What blocked was the **durable false record**: `progress.md` listed the signal among five CLOSED
  limits when it had been added to the table and not the procedure. In a repo whose product is governance
  memory, a wrong "closed" outlives a wrong instruction. **Blocking on the record, not the runtime.**
- **Four domains reached that finding on a premise Opposition disproved.** They argued the four signals needed
  TWO 200s runs (three markdown-only, one JSON-only). False: `formatJson()` serialises the whole result
  object and the "markdown-only" signals are derivations of fields ON that object, so ONE `--format json`
  run yields all four. **Convergence is not corroboration when the domains share a premise** — four agreeing
  reviewers were all wrong about the cost, and only the one that read the formatter caught it.
- **I reversed my own recommendation twice, and both reversals came from reading source I should have read
  first.** (1) Recommended removing ACR's `**/*.md` exclude without checking why it exists — it guards a
  REPRODUCED failure (agents with zero file-type awareness misreading prose as code), and this repo's
  `standards/` is the worst case for it. (2) Over-corrected to "excluding markdown is correct by design" —
  falsified in one command: on the diff under review **all six** `.md` files were excluded (verified 2026-09-01 by calling ACR's own `matchPattern`), two of them copies of `change-review.md`,
  the gate's own definition. **The real axis is inert prose vs executable instruction; a file extension is a
  failing proxy for it in a repo where markdown IS the mechanism.** Now `[NS-48]`, deliberately not applied.
- **`activeContext.md`'s binding dimension FLIPS between bytes and lines, so read BOTH live.** Condensing `[NS-47]` to a pointer bought byte headroom back; a later trim removed lines and inverted it again. No absolute is quoted here on purpose — every figure this bullet has carried went stale within days, including a "149 of 150 lines, exactly ONE more fits" that a trim on this same branch invalidated in both directions at once.
  Read each margin as `pmb-health.yml`'s cap minus the live measure — `git cat-file -s` for bytes, `wc -l` for lines — and act on whichever is tighter, not whichever this file last named. Neither has been tighter throughout — lines bound earlier on this branch, bytes bind now — and the ratio is deliberately not quoted: an earlier draft said "roughly 8x" and the very edit that introduced it moved the figure to ~5.8x. A trim that counts only one dimension will not help.
