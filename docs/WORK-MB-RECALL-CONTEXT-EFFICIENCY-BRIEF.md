# Work-MB: Memory Recall, Context Efficiency & Policy Coverage — Investigation Brief

**Portable handoff for a fresh Work-MB session. Research input, not an adopted Work-MB design. Prepared 2026-10-21 (Central).**

> **Mission:** Investigate whether Work-MB can reduce *unnecessary* agent context without weakening **mandatory standards, policy enforcement, source authority, and team reliability**. Produce a source-grounded design decision and phased, testable work plan. **Do not implement immediately.** Do not assume the personal PMB repository's architecture or failure rates reproduce in Work-MB.

**Originating research:** [PMB ai-memory synthesis](research/2026-10-21-ai-memory-recall-context-evidence.md), [PMB's existing Work-MB paradigm delta](WORK-MB-PARADIGM-DELTA-BRIEF.md), [Work-MB handoff diagnostic](WORK-MB-HANDOFF-DESIGN-BRIEF.md). External reference: [akitaonrails/ai-memory](https://github.com/akitaonrails/ai-memory) (mechanisms and benchmark methods only; **not** a package to install).

## Executive direction

The relevant idea from ai-memory is **selective access to canonical memory, with bounded startup context and measurable recall**, not its Rust server, SQLite index, embeddings or MCP suite. The most transferable practice is to **evaluate retrieval and rule coverage before replacing read-all**.

But Work-MB is meaningfully different from personal PMB:

1. **Non-specialist authors:** people using an assistant may not notice that omitted context would have changed its answer or prevented a bad change. An index pointing to a rule is not equivalent to actually loading/enforcing that rule.
2. **Mandatory standards:** a standard imposed on a team cannot rely solely on one individual's willingness or ability to follow advisory \`CLAUDE.md\` text. Enforceable rules need actual managed policy, hooks, CI or comparable controls, verified in the deployment.
3. **Multi-author/tool variation:** Windows/macOS/Linux, PowerShell/bash, different harnesses, managed configurations, multiple repositories and worktrees introduce sources of drift personal PMB cannot validate for Work-MB.

**Default stance for Work-MB:** keep mandatory policy immediately available or mechanically enforced, consider tiering *explanatory/task/historical* material first, and justify any further reduction by measured correctness and adherence. This may lead to **less aggressive** compression than personal PMB.

## Step 0 — Verify your deployment before proposing architecture

Collect a dated **Work-MB current-state map** backed by concrete files/commands (use repo commit SHA):

- What is Work-MB? Which repositories actually install or consume it? How are updates distributed, versioned and made mandatory? Identify owners, support boundaries and release gates.
- Which assistants and operating systems are really supported? Verify startup, resume, compaction and subagent paths for each; do not generalize a Claude Code behavior to Cursor/Codex.
- Which documents are canonical (project policy, team standards, live project context, decisions, backlog, historical logs)? What is their exact **precedence** and provenance, and what happens on contradictions or supersession?
- What is always injected into model context, conditionally loaded, referenced-but-never-opened, repeated after compaction, duplicated in global and project rules, or loaded by hooks? Capture reproducible byte/token/latency measurements and the method.
- Which requirements are merely advisory, which are enforced in the client by organizational/managed settings, which have blocking hooks, and which fail in CI? **Execute negative tests** rather than trusting labels like "BLOCK" or "enforced".
- Can organizationally managed settings actually be deployed (IT, Group Policy/MDM, agent restrictions, policy ownership)? The old Work-MB brief identifies this as *unknown*. Do not construct a plan that silently assumes access.
- What are current privacy, data-retention, acceptable telemetry and confidentiality rules? Do not collect unredacted employee conversations, secret material, or proprietary decisions into a reusable research corpus.

**Output:** actual-state architecture map; platform/enforcement matrix; policy owner map; startup/restart footprint; observed defects versus unverified hypotheses; current feature/PR inventory. If access to Work-MB is unavailable, report the needed evidence and stop short of asserting that a gap exists.

## Step 1 — Separate *mandatory instructions* from retrievable information

Classify content by both axes, **independently**:

| Category | Potential handling | Risk if omitted |
| --- | --- | --- |
| Mandatory safety/security/process policy | Always supplied or provably enforced by managed policy/hooks/CI; keep succinct where possible | **Unacceptable silent bypass** |
| Current repo constraints and active change boundaries | Always included if task-wide; otherwise targeted with mandatory task-scope trigger | Wrong design, out-of-scope edits |
| Current project status, blocking decisions, task context | Compact trustworthy brief **plus tested retrieval** only if it retains action-critical facts | Lost priorities, stale assumptions |
| Historical reasoning, superseded design, closed issues | On-demand evidence with date, scope and current-status label | Repeating rejected solutions or elevating stale decisions |
| Work journal / handoff / transient execution state | Explicit scoped continuation, only when applicable; never authoritative task priority | Unrelated session consumes baton; corrupted continuation |

Do **not** copy ai-memory's informal precedence chain into Work-MB as-is. Workplace/managed policy can be non-overridable. Verify the effective precedence separately for platform-managed rules, organizational standards, repository policy, current authorized user requests and historical content. A user request must not be treated as overriding higher-level organizational controls.

**Invariant:** an archived journal entry can explain *what happened* but cannot supersede a currently binding standard. An individual user's cross-project preference cannot be promoted automatically into a team requirement.

## Step 2 — Build a Work-MB-specific recall + enforcement evaluation **before compression**

Develop a small, reviewable, sanitized corpus from real Work-MB behavior, with gold evidence and expected answer/action/abstention:

- Required policy/guardrail questions where the right action is to block or request approval.
- Repository-specific workflow and mandatory review/CI checks.
- Current state, owner, blocker, status, version and Next Steps retrieval.
- Superseded policy or decision in journal/history versus current canonical policy.
- Negative knowledge ("this was rejected/not permitted") and intentionally unanswerable questions.
- Intermittent context (compaction, new session, subagent, multi-worktree), two-author conflict and stale installation.
- Deliberately planted missing pointers, changed identifiers, malformed/stale projections, path renames, scope-crossing retrieval, and incomplete handoffs.

Use separate **development/calibration** and **held-out evaluation** question sets; prevent answers from being leaked into startup instructions or the retrieval index as tests. A source must be included only under Work-MB's data-handling policy. Do not export workplace content into personal PMB.

### Required control and candidate

**CONTROL:** Work-MB's verified present-day loading/enforcement path; retain all currently available tooling and detail-access capabilities.

**CANDIDATE:** A bounded, deterministic initial brief + targeted evidence retrieval, **with the same effective mandatory policy protections**. Prototype in a disposable fixture environment; no production startup change.

Hold model, tasks, tool access, runtime environment and revision fixed between arms wherever possible. Explicitly record differences that cannot be fixed.

### Metrics (report individually; don't hide in a single score)

- Correctness of answers **and** actions; required refusal/approval behavior; rule adherence under adversarial or stale context.
- Relevant evidence reached (hit@1/@5, recall where valid), gold-source citation accuracy, authority/time selection, fabricated sources, false certainty and appropriate abstention.
- Always-load context bytes **and observed tokens**; additional retrieved context; latency/timeout; number of reads/tool calls; human correction; false positives and false negatives.
- By-slice regressions: platform, user expertise, rule type, new vs resumed session, active vs historical, contradiction/supersession, and negative-query cases.

Record baseline variance. Set mandatory non-bypass/non-fabrication requirements before testing; set numeric acceptance thresholds after calibration but **before reviewing held-out candidate results**.

### Tests that must demonstrably fail on planted defects

- Hide an applicable mandatory rule from brief **and** enforcement: test must catch the missed rule/action.
- Replace an authoritative current decision with an older historical one: test must catch wrong precedence.
- Remove a detail pointer, archive result, or retrieval keyword: relevant question must detect the lost evidence.
- Introduce a false "healthy" derived index with a modified canonical file: drift check must detect mismatched projection, if an index is adopted.
- Break PowerShell/bash semantics; omit a platform from SessionStart/compaction; simulate an unavailable managed-policy channel. The deployment verification must expose the unsupported condition.

Do not "green" the evaluator by making the candidate the source of gold answers.

## Step 3 — Decide whether and where a bounded brief is justified

Only if Step 2 demonstrates a measurable problem worth addressing:

- First reduce **actual duplication and write rate**, not just context readings. A dense, frequently rewritten live file may be a write-discipline issue.
- Favor a deterministic, generated *view* of authoritative Markdown. If it has an index or cache, it is **rebuildable and disposable**; no secondary editable source of policy truth.
- Prefer **coverage-first** summaries with stable identifiers, meaningful "when to open" cues, source scope and clear markers distinguishing current rules from history. Avoid "first paragraph = most important" assumptions.
- Implement body-text retrieval with bounded citations and negative/no-match behavior only if Work-MB's existing search does not already satisfy the evaluation.
- Preserve required exact tokens: file paths, issue IDs, error codes, URLs, version numbers, and decision links. A synthesis that discards these details is not acceptable merely because it is shorter.
- Do not remove mandatory standard text from all startup/enforcement paths based only on a low aggregate token count or retrieval hit@5.
- Keep opt-in pilot and one-step rollback. Test supported tools and shells together, with installation/template mirrors and worktree behavior. Decide whether read-all remains the safe fallback.

**Do not build:** ai-memory Rust daemon, mandatory SQLite/FTS database, embeddings/vector search, new MCP servers/tool suites, automatic time-based forgetting, uncontrolled LLM consolidation, autonomous policy promotion or a cross-project profile service. Reopen only on measured, Work-MB-specific evidence and a separately approved design.

## Step 4 — Scope a design decision and eventual rollout

Prepare a side-by-side matrix:

1. **Do nothing:** current correctness, context cost, maintenance cost.
2. **Trim duplicated context / improve write discipline:** expected benefit and measured correctness risk.
3. **Keep mandatory rules loaded, tier context/history:** pilot results and cross-platform behavior.
4. **Wider selective loading:** only if it demonstrably preserves all required coverage and is operationally enforceable.

Require explicit approval for the selected option and for any policy, startup, compaction, hook, managed settings, template, CI or installer change. A research brief is not approval to change mandatory rules.

## Deliverables to report back to the Work-MB owner

1. **Evidence inventory:** files/commit, actual startup flow, enforcement and distribution ownership, supported clients/OS, current conflicts and observed incidents.
2. **Authority and mandatory-policy map:** what must be available at SessionStart and after compaction, what may be opened later, and what is mechanically enforced.
3. **Measured control baseline:** question corpus, gold sources, reliability, latency, context cost, implementation/tooling limits.
4. **Candidate recommendation:** smallest concrete change worth piloting, reason, fallback and alternatives rejected.
5. **Executable verification plan:** both-shell/platform behavior, positive/negative/mutation cases, independence of evaluator, no-silent-bypass gates.
6. **Task-contract proposal** sized to Work-MB's own governance, only after the owner accepts the architecture. Report exact file scope, ownership, CI and rollout boundaries; do not start implementation under this research authorization.
7. **Explicit unknowns:** managed policy availability, access scope, confidential data limitations, and any other claims not verified from Work-MB.

## Copy-ready instruction for a Work-MB engineering session

> Investigate whether Work-MB should improve context efficiency through a deterministic bounded SessionStart brief and targeted retrieval. First inspect our *actual* repository, enterprise policy deployment, installed agent clients, startup and compaction flows, templates, hooks, CI, source precedence, and observed failures. Read this brief and its linked PMB research as external inputs **only**. Our deployment may serve non-specialist authors subject to mandatory standards, so never assume a pointer replaces an enforceable rule. Build a sanitized recall **and mandatory-policy-adherence** evaluation against current behavior before proposing a selective-loading change. Report verified findings separately from hypotheses, account for existing plans, include wrong/stale/negative and deliberate mutation cases, demonstrate shell/harness parity, propose the smallest reversible pilot and explicit no-go conditions. **Do not modify production code, policy or startup instructions until the design and scoped task contract have been approved.**

## Source caveats

- PMB's own [retrieval baseline](RETRIEVAL-BASELINE-2026-09-09.md) counts pointer visibility without actual observed fetch; its n=16 does **not** prove a failed retrieval. Work-MB must measure its own tasks.
- PMB's older [index/detail design](superpowers/specs/2026-09-18-memory-bank-index-detail-design.md) concerns personal PMB's \`activeContext.md\` and its size/format. It is prior art, **not** evidence that the design fits Work-MB's rules.
- ai-memory's self-published [3.1.2 benchmark](https://github.com/akitaonrails/ai-memory/blob/1c86aebc14addccc7ac875913d565c681bfa4a50/docs/benchmarks/longmemeval-s-3.1.2-release.md) measures retrieval, not real enterprise policy adherence. Do not import its percentages as Work-MB thresholds.
- Neither PMB review inspected the live Work-MB deployment in this research pass. All Work-MB-specific proposed implementation details remain **conditional** until verified locally.
