# PMB Deep-Dive Closure — 2026-10-24

**Status:** Investigation closure. The research questions are sufficiently answered to stop broad exploration. PMB is **not** yet at implementation/verification closure because several evidence-backed follow-ups remain open.

**Baseline reviewed:** `main` at `10868c2c781be3f7774b78fcadb6f25bd03f1385` (2026-10-24).

**Primary trigger:** https://www.youtube.com/watch?v=eK7Sn0_zHQw and the earlier PMB Context Efficiency & Token-Pressure Review derived from it.

**Related prior PMB work:** `docs/MEMORY-BANK-PARADIGM-REVIEW.md`, `docs/MEMORY-BANK-CAP-ALLOCATION-FINDING.md`, `docs/RETRIEVAL-BASELINE-2026-09-09.md`, and `docs/superpowers/specs/2026-09-18-memory-bank-index-detail-design.md`.

---

## Executive conclusion

The video-driven concern was valid: PMB itself contributes a large, persistent context load, and that is an **observed operational problem**, not a hypothetical scaling risk.

At the reviewed `main`:

| Startup source | Bytes | Approx. tokens | Share |
|---|---:|---:|---:|
| `memory-bank/activeContext.md` | 41,223 | 10,306 | 42.43% |
| `memory-bank/progress.md` | 32,871 | 8,218 | 33.83% |
| `CLAUDE.md` | 18,042 | 4,511 | 18.57% |
| `memory-bank/projectbrief.md` | 1,596 | 399 | 1.64% |
| `memory-bank/systemPatterns.md` | 1,156 | 289 | 1.19% |
| `memory-bank/techContext.md` | 1,152 | 288 | 1.19% |
| `memory-bank/README.md` | 1,116 | 279 | 1.15% |
| **Total** | **97,156** | **~24,289** | **100%** |

The latest PMB Health run on this SHA independently reported **94.9 KiB** of startup context and **~24,289 tokens**, re-paid after compaction. The absolute 25 KiB ceiling remains exceeded by about 3.8x. CI is green because the currently enforced aggregate control is a **no-growth ratchet against `origin/main`**, not the absolute ceiling.

The dominant mass is concentrated: `activeContext.md` + `progress.md` are **76.26%** of PMB-controlled startup bytes. `CLAUDE.md` adds another **18.57%**. Therefore the problem is not “too many tiny metadata files”; it is a few large always-loaded artifacts.

The architecture has already reached the right high-level goal in `projectbrief.md`: **state available at startup, detail fetched on demand**. The actual runtime contract still does the opposite: `CLAUDE.md` explicitly requires reading all of `memory-bank/` in full at startup and again after compaction. That conflict is documented but unresolved.

The right next move is **not** embeddings, a vector database, another memory service, an autonomous token optimizer, or a larger analytics layer. PMB needs to finish the boring work first: make its measurements internally consistent, stop avoidable write growth, prove retrieval on a task that actually requires archived detail, and only then decide whether the existing index/detail design earns implementation cost.

---

## What the video claims mean for PMB

The original review captured these relevant claims:

- repeated conversation/context is expensive;
- large tool output can persist in context;
- tool and MCP definitions can consume context before useful work starts;
- long-lived sessions accumulate cost;
- subagents isolate context but can increase total token use;
- persistent instruction and memory files can become a fixed tax.

Current first-party Anthropic guidance supports the general mechanisms behind those claims:

- compaction trades raw history for a distilled continuation and can lose subtle information if too aggressive;
- subagents are useful for focused, independent exploration because their detailed work stays isolated, but they can consume large token budgets themselves;
- skills use progressive disclosure: metadata is available first and the full body is loaded when invoked;
- large intermediate tool results can pollute context, which is why filtering, pagination, programmatic tool use, and bounded outputs matter.

Sources:
- https://www.anthropic.com/engineering/effective-context-engineering-for-ai-agents
- https://www.anthropic.com/research/equipping-agents-for-the-real-world-with-agent-skills
- https://www.anthropic.com/engineering/advanced-tool-use
- https://docs.anthropic.com/en/docs/build-with-claude/prompt-engineering/prompt-templates-and-variables

The direct YouTube page was not reliably retrievable from this review environment, so this closure does **not** treat unsupported details from the video as authoritative. It evaluates the claims preserved in the original PMB review against the current repository and current first-party guidance.

---

## Original 14-phase investigation — closure status

| Phase | Status | Closure finding |
|---|---|---|
| 1. Measure PMB context footprint | **COMPLETE for PMB-controlled files** | Current startup set and byte/token contribution are measured above. Runtime-owned system/tool/plugin context is outside PMB's repository boundary and should not be invented as PMB cost. |
| 2. Identify context bloat | **COMPLETE** | Observed bloat is concentrated in `activeContext.md`, `progress.md`, and `CLAUDE.md`. Write-rate and always-loaded detail are evidenced. |
| 3. Review loading strategy | **COMPLETE as investigation; implementation open** | Current read-all behavior conflicts with the immutable index/detail goal. Whole-bank tiering was previously rejected; a narrower activeContext index/detail design exists but is not implemented. |
| 4. Review compaction | **NOT COMPLETE operationally** | `mb clean` emits a model-mediated cleanup/condensation prompt. Tests validate presentation and generation metadata, not semantic preservation. There is no invariant proving authority, provenance, freshness, or unique detail survives model condensation. |
| 5. Review context reporting | **PARTIAL; defects found** | PMB now reports startup size, largest contributors, growth, staleness, and budgets, but current Bash/PowerShell/report sections disagree in material ways listed below. |
| 6. Context-health checks | **SUBSTANTIALLY COMPLETE** | Size, staleness, integrity, structural drift, growth, and ratchet checks exist. Remaining work is correctness and severity semantics, not a new subsystem. |
| 7. Compact session-start manifest | **DEFER** | Do not add another manifest before proving retrieval. A manifest that merely restates the current bank risks becoming another startup dump. |
| 8. Memory retrieval value | **PARTIAL** | The 2026-09-09 baseline observed pointers loaded in 16 main-worktree sessions and archived detail fetched in zero; widening to worktrees did not change the numerator. The source explicitly says this does **not** prove retrieval failure because those sessions may never have needed the detail. A task-requiring retrieval experiment is still missing. |
| 9. Instructions / skills / agents audit | **COMPLETE enough for architecture** | Skills and named agents are already progressively disclosed. The primary fixed cost is `CLAUDE.md` + memory-bank read-all, not skill bodies. Do not move policy into skills merely to make files look smaller. |
| 10. Subagent usage | **COMPLETE as policy; telemetry unnecessary for now** | Researcher is Haiku, security-reviewer Sonnet, opposition Opus. Use subagents for bounded exploration/independent review, not simple work. No evidence justifies a new subagent-cost telemetry system. |
| 11. Token-aware operational guidance | **MOSTLY COMPLETE** | `CLAUDE.md` already covers compaction, fresh sessions, bounded delegation, model escalation, and concise tool use. Claims about “token savings” from model escalation should remain a quality/rework tradeoff, not a guaranteed optimization. |
| 12. Efficiency audit | **PARTIAL** | PMB has consolidated commands and many deterministic checks, but reporting still repeats inconsistent calculations and some stale/dead guidance survives. Fix measured duplication before adding observability. |
| 13. Test changes | **PARTIAL** | Test coverage is broad and latest CI is green, but tests do not currently pin the complete startup-file set in Bash reporting or semantic compaction preservation. The index/detail design's proposed query/migration tests do not exist because the design is not implemented. |
| 14. Do not overengineer | **COMPLETE / REAFFIRMED** | Reject token-pricing engines, autonomous context optimizers, vector DBs, semantic-retrieval infrastructure, model-routing systems, and multi-agent optimization absent a demonstrated failure that requires them. |

---

## Current defects found during closure

### 1. Bash startup observability omits `memory-bank/README.md`

The authoritative ceiling calculation in `scripts/mb.sh` recursively includes every Markdown file under `memory-bank/`, including `README.md`.

Later in the same command, the Bash “Startup Context” observability section manually builds a six-file list: `CLAUDE.md` plus the five canonical memory files. It omits `memory-bank/README.md`.

On the latest CI run this produces two different numbers in one `mb doctor` execution:

- ceiling check: **94.9 KiB**, correct;
- observability section: **6 files / ~24,010 tokens**, undercounted by 1,116 bytes / ~279 tokens.

The PowerShell observability section reuses its ceiling file list and does not have this exact omission.

**Disposition: FIX NOW.**

### 2. Bash `show_budget()` materially misreports `CLAUDE.md`

The Bash implementation estimates `CLAUDE.md` size using:

`NR * 4 / 1024`

That is approximately four bytes **per line**, not the file's byte size.

The current file is **18,042 bytes**, but the latest CI log reports:

`CLAUDE.md 0.8 KB ~200 tokens [OK]`

That is false by more than an order of magnitude. The PowerShell implementation uses the actual file length and is materially more correct.

**Disposition: FIX NOW and add a cross-shell fixture.**

### 3. Token Budget reports a false auto-compact state in CI

`.claude/settings.json` sets `CLAUDE_AUTOCOMPACT_PCT_OVERRIDE` to **65**.

Earlier in `mb doctor`, check 5 parses the settings file and correctly reports agreement at 65%.

Later, both `show_budget` implementations read the process environment only. In the current CI environment that variable is not exported, so the same command reports:

`Auto-compact: not set (~95%)`

The command therefore contradicts itself.

**Disposition: FIX NOW.** Read the project setting first; use the process environment only when it is the actual higher-precedence source and that precedence is documented.

### 4. “Total memory-bank size” is not one consistently defined quantity

The freshness audit totals the five canonical files. Token Budget totals the directory. The ceiling recursively includes all Markdown under the directory.

These can all be legitimate views, but they are currently labeled similarly enough to imply equivalence.

**Disposition: FIX NOW by naming the scopes**, e.g. “canonical durable files,” “memory-bank directory,” and “startup-loaded Markdown.”

### 5. The absolute startup ceiling says `[ERROR]` but is intentionally advisory

The latest successful CI run contains:

`[ERROR] Startup context 94.9 KB exceeds 25 KB limit`

and the job still succeeds by design because the enforced control is the no-growth ratchet.

An advisory condition labeled ERROR has already caused confusion in this project.

**Disposition: FIX NOW semantically, not by abruptly making 25 KiB blocking.** Until PMB can actually reach the ceiling without destructive compression, label it `[OVER]` / advisory or explicitly separate “target exceeded” from “enforced regression.” Keep the ratchet blocking.

### 6. Compaction is not semantically verified

`mb clean` tells the model to:

- remove duplicates;
- remove active entries captured in progress;
- archive older work;
- **condense verbose descriptions to decision + rationale**.

The repository's own paradigm review documents context-collapse / brevity-loss risk, and the memory standard requires **verbatim** relocation for `progress.md` archival.

Current tests prove the maintenance prompt appears and size thresholds fire. They do **not** prove that a model-mediated condensation preserves unique facts, qualifiers, provenance, authority, or citations.

**Disposition: FIX DESIGN BEFORE CLAIMING COMPLETION.** Prefer verbatim relocation + deterministic structural checks. Treat any semantic rewrite as a reviewed content edit, not a “compaction invariant.”

### 7. The activeContext index/detail design is still only a design

`docs/superpowers/specs/2026-09-18-memory-bank-index-detail-design.md` is detailed and reviewed, but current `main` has no:

- `docs/next-steps/`;
- `scripts/verify-ns-migration.sh`;
- corresponding migration tests;
- Next-Step-line support in `mb query`;
- lifecycle changes proposed by the spec.

Do not describe the index/detail mechanism as shipped.

**Disposition: DEFER IMPLEMENTATION until the task-requiring retrieval experiment below.**

### 8. Retrieval has an observational baseline, not a success test

`docs/RETRIEVAL-BASELINE-2026-09-09.md` is useful because it measured reality instead of assuming retrieval.

But “pointer loaded, archived detail never fetched” is ambiguous. The next experiment must create or identify a normal task whose correct answer requires detail that is **only** in the retrieved file, then verify whether the agent follows the pointer without being explicitly told the path.

**Disposition: ADD NOW as a bounded experiment.**

### 9. Write-rate control remains the highest-leverage unresolved issue

`[NS-42]` is still open. The earlier measured growth spike in `progress.md` demonstrated that any loading redesign can be refilled if the write policy keeps restating durable history.

The simplest rule remains strong:

> `progress.md` should record cross-session state, unresolved consequences, decisions, and corrections that a commit message cannot provide. Do not restate a commit message merely to prove the session happened.

**Disposition: ADD NOW as a writing rule, then measure before/after growth.**

### 10. Current green CI is not a clean-health signal

The latest `main` PMB Health run is fully green, but `mb doctor` in that run reports:

- startup context above the target ceiling;
- stale `techContext.md`;
- `systemPatterns.md` review due;
- semantic-drift signals;
- `core.hooksPath` unset in the CI checkout;
- project/local PMB version drift (`.pmb-version` = 1.1.1, `VERSION` = 1.2.1);
- review-date drift.

This is not inherently wrong: CI gates and advisory health are different layers. It does mean “CI green” must not be used as shorthand for “PMB healthy.”

**Disposition: DOCUMENTED. Fix the version drift if it is unintended; keep advisory signals advisory.**

---

## Broader PMB deep-dive closure

The broader architecture review is also sufficiently investigated to stop broad discovery. Its central finding still holds: PMB's main risk is **governance/process accretion**, not absence of engineering mechanisms.

### What is strong

- Git-tracked, human-readable durable state.
- Explicit authority tiers.
- Cross-platform CLI with substantial shell and PowerShell coverage.
- Deterministic hooks plus CI rather than relying only on model instructions.
- Strong review culture and mutation-style testing in critical areas.
- Startup-context ratchet prevents silent regression.
- Archive/retrieval experiments are evidence-oriented rather than assumption-driven.
- Current `.claude/worktrees/...` accidental operational artifacts identified in the older review are no longer present in the current `main` tree.

### Where governance is still outrunning value

Current examples are enough to establish the pattern without another survey:

- `CLAUDE.md` is 18 KB of always-loaded governance/instructions.
- `activeContext.md` is 41 KB and 144 lines, close to its 45 KB hard cap.
- `standards/MEMORY-BANK.md` is ~590 lines.
- `docs/MEMORY-BANK-PARADIGM-REVIEW.md` is ~701 lines.
- `CHANGELOG.md` is at 800 lines.
- multiple current rules describe historical corrections to earlier rules.
- an elaborate index/detail specification exists while the simpler prerequisite retrieval experiment remains undone.

The response should **not** be another governance layer. The response is to reduce duplicated ownership, move evidence out of startup context, and only add mechanisms that fix a reproduced failure.

### Broad deep-dive disposition

**STOP broad prior-art intake for PMB until the following measured items are closed.** Harness Engineering can continue broad research separately; PMB should consume only findings that resolve a concrete PMB decision.

---

## Minimal follow-up sequence

### P0 — correctness of existing observability

One small cross-shell change set:

1. Make Bash Startup Context reuse the same complete startup file set as check 15.
2. Fix Bash `CLAUDE.md` byte/token calculation.
3. Make Token Budget report the effective auto-compact setting consistently.
4. Give every displayed context total an explicit scope.
5. Add fixtures that fail if README/startup-file inclusion or cross-shell totals regress.

This changes no memory architecture.

### P1 — stop making semantic-compaction claims PMB cannot prove

Reconcile `mb clean` with `standards/MEMORY-BANK.md`:

- archive/move evidence verbatim where possible;
- do not silently condense load-bearing detail;
- require explicit review for semantic rewrites;
- keep compaction-generation metadata as a risk signal, not proof of semantic integrity.

### P1 — retrieval experiment

Run one bounded task that requires archived detail:

1. Put a necessary fact only in a retrievable detail/archive file.
2. Leave a realistic startup pointer with a useful “open when” trigger.
3. Start a fresh normal session.
4. Ask a task question that requires that fact without naming the detail file.
5. Record whether retrieval occurs, whether the answer is correct, corrective turns, and context delta.
6. Repeat enough times to distinguish one lucky route from a reliable pattern.

Do **not** implement the full activeContext split until this produces useful evidence.

### P1 — write-rate rule

Adopt and test the narrow `progress.md` rule above. Measure 30-day (or available interval) byte growth before/after. If growth is already low enough, do not build automation.

### P2 — decide the activeContext index/detail spec

After P1 retrieval evidence:

- **If retrieval is reliable:** implement only the smallest subset of the existing spec needed to migrate the largest active entries first.
- **If retrieval is unreliable:** do not hide active rules behind more indirection. Improve retrieval handles/trigger wording and retest before migration.
- **If the recovered context is too small to justify lifecycle complexity:** reject the spec and keep the ratchet + write-rate controls.

### P2 — empirical PMB pilot

The earlier build-readiness assessment recommended a 10-session pilot. No durable evidence reviewed here proves that pilot was completed.

Do not create more architecture to replace that missing evidence. Measure:

- continuation correctness;
- memory-caused corrections;
- task success;
- explicit retrieval events;
- PMB maintenance minutes;
- governance false positives;
- startup context.

This is the remaining evidence needed to answer whether PMB's governance cost earns its operational value.

---

## Explicit rejections

Do not add any of the following to close this review:

- vector database;
- embeddings service;
- semantic retrieval service;
- autonomous memory curator;
- token-pricing engine;
- model router;
- automatic session clearer;
- MCP lifecycle manager;
- graph/knowledge-graph orchestration;
- multi-agent memory admission;
- broad telemetry platform.

Any one of those can be reconsidered later only against a reproduced failure that the simpler mechanisms above cannot address.

---

## Definition-of-Done verdict

The original review's **investigation** can now be considered complete.

The original review's **product Definition of Done is not complete** because it also required worthwhile improvements to be implemented and verified. Specifically, these remain open:

1. reporting correctness fixes;
2. semantic-compaction contract;
3. task-requiring retrieval experiment;
4. write-rate rule/evidence;
5. decision on the index/detail implementation after retrieval evidence;
6. the empirical PMB pilot.

That distinction is intentional. We have enough evidence to stop researching the shape of the problem. We do **not** have enough evidence to declare the problem solved.

The durable operating rule from this deep dive is:

> **PMB should preserve durable state without forcing every durable detail into every session. Measure the fixed context tax, keep retrieval explicit and testable, prefer verbatim evidence movement over lossy condensation, and add architecture only after a reproduced failure demonstrates that the simpler path is insufficient.**
