# ai-memory → PMB: recall, startup context, and evidence-preserving retrieval

**Research synthesis — 2026-10-21 (America/Chicago). Not an approved design, task contract, or implementation order.**

**Purpose.** Consolidate two independent reviews of [akitaonrails/ai-memory](https://github.com/akitaonrails/ai-memory), reconcile them against *this repository's* evidence and previously rejected designs, and state what PMB should test before attempting to replace read-all startup loading. This is a research record; any implementation needs its own bounded spec, plan, verification, and approvals. Do **not** install ai-memory as a PMB dependency.

## Source and verification ledger

| Basis | Status and limit |
| --- | --- |
| PMB \`main\` at [25515a269f94cb9c05110b5e0dcd871e4331822e](https://github.com/unyieldingclaw-dev/personal-memory-bank/commit/25515a269f94cb9c05110b5e0dcd871e4331822e) | Repository files inspected, **not** local runtime executed or full tests run |
| ai-memory \`main\` at [1c86aebc14addccc7ac875913d565c681bfa4a50](https://github.com/akitaonrails/ai-memory/commit/1c86aebc14addccc7ac875913d565c681bfa4a50) | Source/design/benchmark documents inspected; external benchmark **not independently reproduced** |
| [ai-memory tiered brief design](https://github.com/akitaonrails/ai-memory/blob/1c86aebc14addccc7ac875913d565c681bfa4a50/docs/design-tiered-session-brief.md) | Design-of-record states implemented in **3.1**, PR #1264; extractive L0/L1/L2, default **4,000-byte** brief cap; not a PMB performance result |
| [LongMemEval-S decomposition](https://github.com/akitaonrails/ai-memory/blob/1c86aebc14addccc7ac875913d565c681bfa4a50/docs/benchmarks/longmemeval-s-decomposition-2026-10-12.md) | Self-published, corrected harness; 470 answerable questions; shipped zero-LLM FTS pipeline hit@5 **0.662 → 0.951** after adding a raw-observation ranking stream; **retrieval metric, not answer accuracy** |
| [3.1.2 release benchmark](https://github.com/akitaonrails/ai-memory/blob/1c86aebc14addccc7ac875913d565c681bfa4a50/docs/benchmarks/longmemeval-s-3.1.2-release.md) | Self-published FTS hit@1 **0.857**, hit@5 **0.951**, hit@10 **0.972**, p50 **12 ms**, p95 **103 ms**, average returned context **528 estimated tokens**; local-embedding hit@5 **0.947**; not like-for-like with PMB |
| [Latest public release v3.2.0](https://github.com/akitaonrails/ai-memory/releases/tag/v3.2.0) | GitHub says published **2026-10-22 01:37 UTC** (= October 21, Central); current release is not proof PMB should adopt the runtime |

**Evidence categories:** VERIFIED = directly inspected PMB/ai-memory documents and source; REPORTED = another project's published measurements, not independently rerun; PROPOSED = an idea/experiment, not established project behavior. Do not relabel REPORTED as VERIFIED.

## 1. PMB's actual problem and previous attempts

1. **Goal/runtime disagreement (VERIFIED).** [\`memory-bank/projectbrief.md\`](../../memory-bank/projectbrief.md) requires session-start availability of an **index with on-demand detail**, while [\`AGENTS.md\`](../../AGENTS.md) and [\`CLAUDE.md\`](../../CLAUDE.md) explicitly instruct reading every Memory Bank file at startup and after compaction. Both call read-all an **open conflict / interim mechanism**, not an authorized reinterpretation of the Tier-1 goal.
2. **Search gap (VERIFIED).** [\`scripts/mb.sh\`](../../scripts/mb.sh) \`show_query()\` searches frontmatter tag values and \`##\` headings in only the five canonical files. It does not search Markdown bodies, the archive, or journal history, rank authority, or return bounded cited evidence. The PowerShell twin and existing tests require separate inspection when designing parity; do not assert untested parity.
3. **Earlier whole-bank tiering was rejected (VERIFIED).** [\`activeContext.md\` NS-35](../../memory-bank/activeContext.md) records a **DROPPED**, not deferred, 2026-08-26 proposal. Its index did not fit the available budget (**~117 bytes per item versus ~198 measured**), and a supposedly repo-local change touched TEMPLATE_OWNED distribution paths and would self-revert. Its finding that excessive **write rate** drives much of the context growth also remains relevant. New L0/L1/L2 labels do not erase these failure conditions.
4. **A narrower index/detail design already exists (VERIFIED).** [2026-09-18 NS-44 spec](../superpowers/specs/2026-09-18-memory-bank-index-detail-design.md) was merged **as a design** in PR #33; it scopes indexed detail to \`activeContext.md\`'s numbered Next Steps, keeps tiny stable-tier files full, describes \`mb query\` extension, and specifically states that it does **not** resolve the aggregate startup-cost constraint. Verify whether any implementation has since landed before planning overlapping code.
5. **Archive access is unproven (VERIFIED with limit).** [Retrieval baseline, 2026-09-09](../RETRIEVAL-BASELINE-2026-09-09.md) found an archive pointer in **16/16** selected main-worktree sessions and **zero observed fetches** (17/17 for the alternate cross-worktree window). The report explicitly says **zero does not prove failure**: the sessions may not have needed the archive. Use planted/held-out tasks that require archival material.
6. **C1 is not fully operational (VERIFIED as recorded).** [\`activeContext.md\` NS-68](../../memory-bank/activeContext.md) records C1 Plan A merged, later hardening, Plans B–D pending, and the feature inert until Plan C's \`.pmb-features\` activation. Do not treat journal fallback or explicit pickup as an already-deployed retrieval path.

**Critical distinction:** \`authority\` (immutable/stable/volatile/history) and **startup criticality** are independent. A rule may be brief but non-negotiable; an active task may be long but only task-relevant. Do not order retrieval or brief packing purely by file volatility.

## 2. What the two reviews agree to adopt or reject

| ai-memory observation | PMB disposition | Qualification |
| --- | --- | --- |
| Markdown/Git canonical, searchable projection derived | **Keep principle** | Any generated manifest/brief/cache is disposable, reconstructible, and never an independently editable authority |
| L0 abstract, L1 summary, L2 detail | **Pilot** | Deterministic, bounded, explicit authority; no assumption first paragraph captures key decision; preserve mandatory rules |
| Memory retrieval evaluation with top-k, recall, latency, context cost | **First priority** | Build a PMB-specific answer-and-evidence corpus; retrieval-only hit@5 is insufficient |
| Raw observation ranking stream rescues lost capture evidence | **Adapt insight** | Test how journal/archive/git evidence is discoverable; do not equate raw history with current instructions; stream changes ranking, it is not merely a fallback on miss |
| Explicit offer-before-claim handoff | **C1 corroboration** | Preserve scoped, non-destructive explicit pickup; do not replace existing C1 design |
| Extractive compaction protects paths, identifiers, error codes, URLs | **Research candidate** | Verify that important exact detail survives; do not automatically rewrite durable facts |
| Relevance/age/access decay | **Reject for canonical truth** | A rarely accessed settled rule can remain binding; at most emit an archival-review signal for resolved volatile items |
| Automatic LLM improvement / memory promotion | **Do not adopt now** | Candidate proposals could someday use deterministic side-effect-free checks plus human/semantic review; never auto-promote authoritative rules |
| Cross-project default user profile | **Precedence pattern only** | Project constraints and mandatory organizational policies are not replaced by personal habits; authority model depends on deployment |
| SQLite FTS, Rust service, vector DB, MCP memory-tool suite, web UI, automatic dreaming | **Reject / out of scope** | No demonstrated PMB-specific need justifies infrastructure or dependency conflicts |

The second review adds useful depth absent from the first: implemented tiered packing; a detailed test corpus and A/B methodology; observation-stream capture-loss diagnosis; deliberate *mutation* of the evaluation harness. The first review remains useful as a warning against implementing search before a reproducible retrieval problem is defined.

## 3. Proposed PMB workstream: Recall & Context Efficiency evaluation

**Workstream status: proposed research and test harness, NOT a decision to change startup instructions.**

### Phase 0 — Reconcile existing architecture and evidence (no production behavior changes)

- Check current \`main\`, open PRs, NS-35/NS-44/NS-42, template ownership, and both shell twins before declaring something missing. Preserve prior negative findings in any new design review.
- Measure **actual model context injected** by session-start instructions and hooks per harness, not just tracked bytes. Record file footprints as reproducible snapshots, with commit SHA and measurement method; avoid embedding live-size assertions in canonical instructions.
- Document mandatory rule coverage and what currently blocks/permits operations across Claude Code, Codex, Cursor and installed template versions. A rule omitted from context may cease being followed; a hook claimed to enforce a rule must be exercised.
- Verify current C1 progress before assuming journal availability.

**Deliverable:** frozen baseline commit, source/authority map, current loading/cost map, superseded-design register.

### Phase A — Build a held-out recall corpus and control

- Create questions sampled from **real PMB tasks**, with gold answer (or justified abstention), exact expected evidence and its authority/time. Include current NS status, active priority, architecture constraints, factual history, change-over-time, supersession, scope/worktree restrictions, negative knowledge, and conflicts.
- Include planted tasks requiring archive detail, unanswerable questions, and contradictory stale historical evidence. Do not count "we did not fetch the archive" as failure unless the test actually needed it.
- Keep authoring/calibration examples apart from **sealed/held-out** evaluation examples. Avoid benchmark leakage through startup files, evaluator prompts or new indexes.
- Establish **read-all control** using the same agent/model, tool access, time constraints, task prompts, and available non-startup sources as the candidate. Count correctness, evidence retrieval and citation, explicit abstention, wrong/stale authority, extra tool calls, context bytes/tokens, latency, and human correction. Repeat enough to characterize variance.
- Include a simple lexical baseline (\`grep\`/\`rg\` if available) as a reference, not as a claim it matches ai-memory's FTS ranking.

**Deliverable:** question/evidence fixture set, baseline report with provenance, reproducible runner, known limitations.

### Phase B — Prototype brief and retrieval **together**, outside the default startup path

- Generate a bounded brief deterministically from canonical Markdown at runtime or from verified reconstructible projections, without requiring an LLM or adding authoritative store files. Show source paths, intended depth and explicit "when to fetch" cues.
- Preserve/fully expose security, workflow and other mandatory rules, and make authority precedence explicit; do not treat first-paragraph clipping as an adequate semantic summary by default.
- Test a backwards-compatible extension to \`mb query\`, or a separate \`mb search\`, for **bounded body excerpts and source line/path** over appropriate canonical and durable documents; define archive/journal/git evidence routing separately. Keep citations and scope, negative results, and superseded-version handling.
- Compare the narrowly scoped NS-44 index/detail design rather than duplicating it. Cover bash and PowerShell with the same functional fixtures; avoid new mandatory dependencies.
- Make all derived state disposable/rebuildable. If \`mb doctor\` ever checks it, report source health and projection staleness **separately**, not as semantic correctness.

**Deliverable:** opt-in candidate with rollback, docs of source ownership, both-shell tests; no change to read-all instructions yet.

### Phase C — A/B and mutation evaluation

- Compare control and candidate on the *held-out* corpus. Test question correctness and evidence availability **and** rule-adherence, not just retrieval hit@k.
- Deliberately remove: a current NS pointer, an authority marker, a historical detail source, an index cue, and a supersession signal. Demonstrate the tests catch actual answer/authority failures, not merely a changed byte count.
- Test no-match/abstention, stale cache, deleted/renamed documents, malformed inputs, misleading archived claims, branch/worktree isolation, and first-boot/compaction behavior; avoid unsafe writes to real history.
- Set **non-negotiable requirements** now: no silent elevation of historical material over current canonical rules, no fabricated evidence, no bypass of mandatory controls. Set quantitative recall/context/latency gates **after baseline-calibration variance but before viewing held-out candidate results**; record the thresholds and rationale.
- If selection or retrieval consistently misses mandatory detail, fail the experiment rather than labeling token savings a win.

**Deliverable:** comparative report, failure analysis, pre-registered acceptance criteria, go/no-go recommendation.

### Phase D — Only with proof, stage a reversible startup change

- Introduce scoped opt-in/feature flag and documented rollback. Leave read-all as the fallback until correctness is established across supported harnesses, on session start **and** post-compaction.
- Validate production startup injection and provenance; compare real sessions to measured pilot. Continue monitoring for silent non-fetch, context creep, drift and regressions. Preserve template/installer parity.
- Review and explicitly approve any modification of \`AGENTS.md\`, \`CLAUDE.md\`, Cursor rules, templates, security controls, or Tier-1 contract; do not conflate an evaluation approval with an implementation approval.

**Deliverable:** a separate approved rollout PR, after the evaluation establishes merit.

## 4. Work-MB is **not** a drop-in adopter of a PMB result

PMB's existing [Work-MB paradigm delta brief](../WORK-MB-PARADIGM-DELTA-BRIEF.md) explicitly identifies two reasons results do not automatically transfer: **non-specialist authors may not notice absent context**, and **a mandatory team standard requires enforcement beyond advisory prose**. A portable, deployment-first execution brief accompanies this research: [\`docs/WORK-MB-RECALL-CONTEXT-EFFICIENCY-BRIEF.md\`](../WORK-MB-RECALL-CONTEXT-EFFICIENCY-BRIEF.md).

For Work-MB, always-loaded/enforced mandatory standards may need to remain substantially richer than PMB's eventual brief. Managed-policy/MDM availability, repository rules, CI, hooks, platform coverage, multi-author scope boundaries and sensitive data are Work-MB-local facts to verify, not PMB properties to assume.

## 5. Research debt and explicit non-claims

- No PMB recall harness has been built or run by this synthesis.
- No PMB model-context token savings have been measured here.
- No ai-memory benchmark has been reproduced here. The published hit@5 measures retrieval evidence placement, not whether an agent obeys critical project policy or answers correctly.
- No proof yet that a bounded startup brief beats read-all. NS-35's rejected full-index size is a specific counterexample to premature optimism.
- C1 journal retrieval is future integration until its opt-in/rollout and validation actually land.
- Do not create a new dedicated index database, runtime service or autonomous retention layer on the strength of these papers alone.
- Work-MB recommendations are conditional until Work-MB itself is inspected and tested.

**Decision requested from PMB owner later:** authorize a **bounded evaluation-only** task contract after Phase 0 scoping; the current research approval does not authorize refactoring startup paths.
