# Memory Bank Paradigm Review — 2026-08-23

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
- `activeContext.md` has the same shape. Resolved `[NS-N]` entries do not leave; `[NS-2]` has
  decayed to the single line "Resolved — see NS-4 and NS-24" and still costs bytes at every
  session start.
- The only removal path is a human-approved contract, an archive pass, and a review gate.

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

Status meanings: **MEASURED** — command run against this repo on 2026-08-23. **PRIMARY** — read
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

**Withdrawn:** an earlier draft cited "FLenQA accuracy 0.92 → 0.68" attributed to the Chroma
report. That figure is not in the Chroma report; a search summary conflated two papers. Do not use
it. The LongMemEval result above replaces it and is better supported.

> This paragraph previously sat BETWEEN two runs of table rows, which silently terminated the
> Markdown table and rendered the six rows after it as literal text — the rows were present in the
> source but invisible as ledger entries. Keep prose out of the table body; notes go after it.

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
