# External Agent Systems Mining — 2026-08-29

This note preserves useful design evidence from three public repositories reviewed for the Personal Memory Bank (PMB) project.

The purpose is **research capture, not adoption**. A pattern is not a PMB requirement merely because another project uses it.

## Sources

- Apache Maka — https://github.com/apache/maka
- Modular — https://github.com/modular/modular
- FreeLLMAPI — https://github.com/tashfeenahmed/freellmapi

> Note: the supplied FreeLLMAPI URL was `tashfeenahmed/free`; the current public repository is `tashfeenahmed/freellmapi`.

---

## 1. Apache Maka

### What it does

Maka describes itself as a local-first agent workspace. Its architecture gives **Runtime Host** a single execution authority across Desktop, TUI, CLI, bots, and evaluation clients. Its Runtime Event Log is the semantic source of truth for model messages, tool calls, tool results, permission actions, usage, and terminal facts. UI state, model history, recovery, and other views are projections of that record.

### Strong lessons for PMB

#### A. One execution authority is more valuable than many cooperating authorities

Maka explicitly avoids having each product surface own a second runtime. Clients ask one Runtime Host to execute work.

**PMB lesson:** when multiple commands, agents, or interfaces touch the same memory state, prefer one clearly bounded authority for mutation and lifecycle decisions. Avoid distributed writers merely because they are architecturally possible.

**Potential PMB use:** future multi-agent memory workflows should identify the canonical mutation path rather than allowing each agent surface to invent its own write semantics.

#### B. Facts and projections should not be confused

Maka's central rule is effectively:

```text
state = projection(logged facts, policy, runtime configuration)
```

The saved execution facts are not the same thing as the UI transcript or the next model context. Context pruning can change what the model sees without deleting the recorded evidence.

**PMB lesson:** distinguish durable evidence from derived summaries, indexes, or presentation. A compact context file should not silently become the only record of a decision if the underlying evidence matters operationally.

**Do not over-apply:** PMB does not need an event-sourcing system. The useful principle is separation of canonical facts from projections, not importing Maka's runtime machinery.

#### C. Lifecycle completion should be explicit

Maka treats terminal RuntimeEvents as authoritative. A header or last message cannot by itself prove that an execution completed.

**PMB lesson:** commands and agent workflows should have deterministic completion/failure signals. Do not infer success merely because an agent produced plausible output.

This is especially relevant to future PMB audit/test harnesses.

#### D. Evaluation is a separate concern from execution

Maka separates its evaluation layer from Runtime Host. Experiments expand into explicit cells (`task × repetition × subject`), attempts are immutable, and result selection is deterministic.

**PMB lesson:** if PMB later gains model/agent comparison tests, keep **experiment definition and scoring separate from the execution mechanism**. The same execution path should be able to run different subjects without embedding benchmark semantics into the runtime.

This is directly relevant to the planned multi-model memory/agent experiment work.

#### E. Security claims should distinguish enforcement from heuristics

Maka's security policy is unusually explicit: in-process permission checks and other LLM-facing filters are heuristics; the OS is the actual enforcement boundary. Restricted tool execution can rely on OS-enforced sandbox mechanisms where supported.

**PMB lesson:** do not describe prompts, policy text, or in-process checks as hard security boundaries. State what is actually enforced and by whom.

### Patterns to defer, not adopt

- Full append-only runtime event infrastructure.
- Replayable agent state machines.
- Multi-agent graph scheduling.
- OS-level sandbox orchestration.

These are useful reference patterns, but none is justified for PMB merely by Maka implementing them.

---

## 2. Modular

### What it does

Modular combines MAX model serving and the Mojo programming language behind a unified platform. The repository deliberately distinguishes active/nightly development from stable release branches. Its contribution process also makes a useful distinction between small obvious fixes and non-trivial changes that need design alignment before implementation.

### Strong lessons for PMB

#### A. Separate stable consumption from active development

The Modular repository states that `main` tracks nightly builds and may contain new bugs, while release branches identify stable versions.

**PMB lesson:** preserve a clean distinction between the project's current development state and a known stable/released state. Do not make the latest development snapshot implicitly equivalent to a validated release.

PMB already has versioning/releases; this is reinforcement, not a new architectural requirement.

#### B. Put capability behind a stable boundary

MAX presents a consistent serving interface while provider/hardware-specific implementation details remain behind the platform boundary.

**PMB lesson:** where PMB eventually needs multiple implementations, prefer a small stable contract at the boundary rather than leaking provider/tool-specific behavior throughout the project.

**Caution:** this is only useful where multiple implementations actually exist. Do not introduce an abstraction layer ahead of evidence.

#### C. Scope contribution work by actual change size and risk

Modular explicitly allows small, obvious fixes to go directly to a PR while requiring alignment before larger behavior changes or public-interface work.

**PMB lesson:** this supports the existing PMB preference for lightweight, proportionate process. Small changes should not acquire heavyweight governance just because a larger project uses it.

---

## 3. FreeLLMAPI

### What it does

FreeLLMAPI aggregates many OpenAI-compatible and other provider surfaces behind one endpoint. Its router chooses providers using priority/capability/speed/reliability/rate-limit signals, uses cooldowns and bounded retries, tracks per-key usage, supports sticky sessions, and records the attempt trail when a request exhausts its options.

### Strong lessons for PMB and adjacent agent work

#### A. Operational routing should use observed signals, not static assumptions

The router considers live health, recent errors, rate-limit headroom, speed, and capability instead of treating every provider/model as interchangeable.

**Lesson for PMB experiments:** when comparing models or agent configurations, record observed outcomes and relevant resource usage. Do not rank systems solely from configuration labels or model names.

This supports the earlier idea of a small, repeatable model-comparison experiment rather than a large autonomous routing system.

#### B. Retries need a bounded budget and an attempt trail

FreeLLMAPI uses cooldowns, a bounded number of attempts, and a wall-clock retry budget. When it exhausts the chain, the error includes what was attempted.

**Lesson for PMB:** future automated checks should be bounded and auditable. If a test harness retries or substitutes a model, preserve enough information to explain what actually ran.

#### C. Capability declarations should be honest

FreeLLMAPI advertises model-supported parameters and removes parameters known to be rejected by particular providers. It also distinguishes model/provider compatibility rather than pretending the entire fleet has identical capabilities.

**Lesson for PMB:** when a field, capability, or output contract is not universally supported, make the distinction explicit instead of silently normalizing everything into a misleading common denominator.

This aligns with PMB's existing emphasis on mechanically observable integrity signals.

#### D. Model switching should preserve continuity explicitly

FreeLLMAPI uses sticky sessions and an explicit context-handoff mechanism when a model switch is unavoidable.

**Lesson for agent workflows:** a model/provider change during a long-running task should not be invisible. If continuity matters, carry forward an explicit handoff rather than assuming a new model has the same working context.

#### E. Self-updating metadata can be useful, but it is operationally expensive

FreeLLMAPI updates its model catalog from a signed feed rather than requiring a code pull for every provider/model change.

**Lesson:** separate **data that changes frequently** from **code that changes infrequently** when there is a real operational benefit.

**PMB decision:** do not build a self-updating memory/catalog service. The pattern is worth remembering only if PMB later has genuinely fast-changing external metadata that would otherwise require code releases.

---

## Cross-source synthesis

Three patterns recur strongly enough to keep as PMB design guidance:

1. **Bound authority.** One clear component should own a given class of state mutation or execution lifecycle. Do not create cooperating authorities without an operational reason.
2. **Separate facts from projections.** Saved evidence, working context, summaries, UI output, and derived indexes are different things. Do not silently substitute one for another.
3. **Make automation observable and bounded.** Retries, substitutions, model comparisons, and agent execution should have explicit limits and enough recorded evidence to explain what happened.

Two additional patterns are useful but conditional:

4. **Explicit capability boundaries.** Common interfaces are valuable when multiple implementations actually exist; premature abstraction is not.
5. **Stable vs. development state.** Keep validated/released state distinguishable from the moving development head.

## What this does NOT justify

This research does **not** justify adding any of the following to PMB now:

- a general event-sourcing framework;
- autonomous memory consolidation or "dreaming" infrastructure;
- a model router;
- a provider abstraction layer without a concrete multi-provider need;
- a distributed memory service;
- automatic external catalog synchronization;
- heavyweight governance around ordinary repository changes;
- a general-purpose agent orchestration platform.

The useful output is the **design principles and evidence**, not wholesale architecture import.

## Provenance

Primary source material reviewed directly:

- Apache Maka `README.md` and `ARCHITECTURE.md`, including its Runtime Host, Runtime Event Log, evaluation boundary, and repository layout.
- Apache Maka `SECURITY.md`, including its trust-boundary and heuristic-vs-enforcement framing.
- Modular `README.md` and `CONTRIBUTING.md`, including nightly/stable branch separation and contribution scoping.
- FreeLLMAPI `README.md`, `docs/architecture.md`, and installation/security documentation, including routing, rate tracking, failover, sticky sessions, capability handling, encrypted credentials, and catalog updates.

Research date: 2026-08-29.

This document records the source state observed on that date. External repositories continue to change.
