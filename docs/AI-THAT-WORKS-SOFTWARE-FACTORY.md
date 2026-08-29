# AI That Works — Software Factory / Harness Research

**Research date:** 2026-08-29  
**Source repository:** https://github.com/ai-that-works/ai-that-works  
**Status:** Research input only. No architecture change is implied by this document.

## Why this was captured

The `ai-that-works` repository contains unusually concrete material on agent harnesses, software-factory loops, backpressure, evaluations, observability, and model churn. The useful question for PMB / Harness Engineering is not "how do we copy their factory?" but:

> Which mechanisms have demonstrated leverage, and which are merely implementation choices for their environment?

This document records the reusable ideas before they get mixed with our own architecture decisions.

---

## 1. The strongest idea: a software factory is a set of feedback loops

The June 23, 2026 Software Factory for Agent Tools episode describes a persistent loop rather than a monolithic "factory":

1. An agent attempts real work.
2. The system captures the run/transcript and what went wrong.
3. Findings are turned into actionable issues.
4. A human decides whether the issue is real and what category it belongs to.
5. An agent drafts or redrafts the issue/fix based on human feedback.
6. An implementation agent creates a PR.
7. A second loop iterates on the PR until checks pass or a bounded turn limit is reached.
8. The resulting fixes feed back into the system.

Their implementation runs this process repeatedly against the latest release, rather than waiting for humans to discover every failure manually.

**Important distinction:** the value comes from the feedback loop and its evidence, not from having a large number of agents.

### PMB / HE implication

For Harness Engineering, model the system as **small, explicit loops with clear inputs, outputs, and stopping conditions**, not as one grand autonomous architecture.

Before adding another agent, ask whether the existing loop has a missing feedback signal, weak verification, or an unclear human decision point.

---

## 2. Separate "finding the problem" from "fixing the problem"

The software-factory example deliberately separates two loops:

### Issue loop

Agent execution → evidence → candidate issue → human validation/direction → revised issue → approval.

### PR loop

Approved issue → implementation agent → checks/review → revision → merge decision.

This separation is valuable because the two loops have different contracts. The first is primarily about **truth and problem definition**. The second is about **implementation correctness**.

### PMB / ACR implication

This is directly relevant to ACR. ACR should remain an independent feedback/evidence layer rather than becoming the implementation authority.

A useful general pattern is:

> **Detect → substantiate → decide → implement → verify**

Do not collapse those stages merely because an agent can technically perform all of them.

---

## 3. Human leverage is concentrated in judgment, not typing

The software-factory discussion repeatedly puts humans at the points where judgment matters:

- Is the reported issue real?
- Is it a skill/documentation problem or a product/compiler bug?
- Is the suggested fix appropriate?
- Is the architectural direction correct?
- Should the work proceed at all?

Agents perform the detailed investigation and code generation, but humans retain the decision about what counts and what direction is acceptable.

This is consistent with the April 21 Harness Engineering discussion: the useful question is where the human has the highest leverage, not how to remove the human from every loop.

### PMB / HE implication

Prefer bounded authority and explicit decision points over autonomous escalation. Human review should move toward **high-leverage architectural, quality, and tradeoff decisions**, while deterministic checks absorb routine verification.

---

## 4. Evidence is more valuable than another clever prompt

The software-factory system records the actual agent run, including the transcript and what failed. That makes the agent's behavior inspectable rather than relying on a human's reconstruction of what happened.

The April 21 harness episode makes the broader point: when agent behavior is nondeterministic, looking at the data returned by the system is more valuable than reasoning from assumptions about what the model "should" have done.

### PMB / HE implication

When a workflow is unreliable, first capture enough evidence to distinguish:

- model failure;
- context-selection failure;
- tool/interface failure;
- orchestration failure;
- deterministic verification failure;
- human-direction failure.

Do not respond to an observed failure by immediately adding more instructions or another agent.

---

## 5. Backpressure is a core design primitive

The July 14 benchmark discussion emphasizes that the tighter and cheaper the feedback loop is, the less likely an agent is to drift off course. Examples include type checking, linting, tests, static analysis, mutation testing, and other deterministic gates.

The February 10 Agentic Backpressure episode frames small proof programs and tests as a way to validate understanding before an agent gets deep into implementation.

### PMB / HE implication

Prefer **cheap, deterministic feedback early** over expensive model-mediated correction late.

Potential sequence:

> understand → prove the important assumption → implement → deterministic checks → independent review → human judgment

This is especially relevant to ACR: ACR should complement deterministic verification, not become a substitute for it.

---

## 6. Evals are more durable than prompts and implementations

The April 21 harness episode explicitly treats evals as the specification that survives model and implementation churn.

The July 29 model-evaluation episode recommends evaluating the same real task/prompt across models using task-specific measures of:

- output quality;
- cost;
- latency/speed;
- user experience / usefulness.

It also recommends starting with small, bespoke evaluation tools instead of building one universal evaluation framework.

The June 23 software-factory episode extends this to documentation: their "arena" compares versions of agent-facing documentation/skills on the same tasks and measures cost, turns, and success rate.

### PMB / HE implication

For future model/harness experiments, preserve a small set of **stable, representative tasks** and run them against competing configurations.

The durable artifact should be the test/eval and its observed result, not a claim that a particular model, prompt, or harness is permanently best.

This is particularly important for the planned PMB/ACR harness assessment.

---

## 7. Do not confuse benchmark success with codebase quality

The July 14 benchmark discussion makes a useful distinction:

- passing a task test is not the same as writing maintainable code;
- one-off coding benchmarks do not capture six-month architectural consequences;
- a system can optimize toward the grader rather than the actual engineering objective.

### PMB / ACR implication

When designing ACR or Harness Engineering evaluations, avoid a single scalar "agent quality" score.

Measure the dimensions that actually matter for the workflow, and preserve human judgment where the criterion is inherently architectural or taste-based.

---

## 8. Observability must exist before the failure

The July 7 Agent Observability episode makes a strong operational point: observability is primarily useful in hindsight. Once a failure occurs, the trace must already exist or the system may be impossible to reconstruct reliably.

Their recommendation is to capture structured, queryable execution data and make it accessible to agents as well as humans. They also emphasize broad instrumentation and automatic redaction rather than depending on every future code author to remember to add tracing.

### PMB / HE implication

For any future autonomous or long-running workflow, determine the minimum execution metadata needed to explain materially different behavior:

- model/provider/runtime;
- relevant context sources;
- tool calls;
- important outputs/results;
- stopping reason;
- verification results;
- session/run identity.

Do not build a telemetry platform merely because observability is fashionable. First identify which questions we cannot currently answer when something goes wrong.

---

## 9. Harness engineering: exhaust the simple loop first

The April 21 Harness Engineering episode is deliberately skeptical of unnecessary harness construction. Its central framing is that a harness is the operating environment around an agent loop, while nested agents are effectively nested loops.

The episode argues that teams should exhaust improvements available within a single agent loop before introducing another layer of orchestration. Additional loops and abstractions should justify their complexity for the specific task.

The May 5 discussion adds an important nuance: the useful "outer harness" advantage is often in workflow-specific orchestration, context injection, and domain knowledge, while model vendors retain advantages from post-training on their own tool formats.

### PMB / HE implication

This supports the existing assessment posture:

- do not build a custom harness simply because one is possible;
- do not add agents to compensate for an unverified context or tooling problem;
- prefer small, reversible orchestration changes;
- evaluate the current harness before replacing it;
- distinguish provider/model advantages from project-specific workflow advantages.

---

## 10. Product design and technical design should not be conflated

The June 16 Product Specs with AI episode separates:

1. product design — user experience, success criteria, scope;
2. technical design — architecture and contracts;
3. program design — test seams, function signatures, and implementation structure.

The stated rationale is practical: a design can look correct at the product level while still producing poor implementation decisions if technical structure is deferred too long.

The episode also emphasizes moving decisions and verification earlier, where there is more leverage.

### PMB / HE implication

This reinforces keeping product decisions, implementation plans, and code-review judgments distinct. A durable handoff artifact should make clear **which kind of decision it represents** rather than blending everything into one large planning document.

---

## 11. Agent-facing documentation should be treated as an interface

The June 23 software-factory episode describes A/B testing documentation/skills just as they would test code. Different versions of the same agent-facing documentation can be evaluated on identical tasks.

The April 21 and June 16 material also argues that good tools/interfaces can reduce the need for procedural instruction.

### PMB / HE implication

When an instruction is repeatedly necessary, ask whether the underlying interface is underspecified.

Do not automatically remove instructions because a newer model appears capable of inferring the behavior. Instead, test whether the instruction is still producing measurable value.

This aligns with the existing Harness Engineering rule: **model capability drift is evidence to reassess guidance, not permission to delete it blindly.**

---

## 12. Patterns worth testing, not adopting

The following are interesting but are **not recommendations for PMB** based on this research alone:

- 24/7 autonomous agent execution;
- automatic issue creation in Linear;
- automatic PR creation/iteration;
- multiple nested agent loops;
- always-on tracing of every operation;
- a universal evaluation framework;
- replacing human review with a judge model;
- a dedicated custom harness solely to coordinate these pieces.

These may be justified in a different operating environment. They require evidence of a corresponding PMB problem before they belong in the architecture.

---

## 13. Candidate experiment for PMB / ACR

When PMB and ACR reach a stable baseline, use a small fixed evaluation set rather than comparing models by anecdote.

For each candidate model/harness configuration, run the **same tasks** and record:

- correctness / substantive quality;
- unsupported claims or hallucinations;
- adherence to explicit constraints;
- unnecessary process or tool use;
- deterministic verification results;
- turns / execution time;
- token consumption where available;
- human usefulness of the final result.

Do not optimize for the lowest token count or highest finding count in isolation.

The goal is to identify which configuration produces the best **useful outcome for the least unnecessary work**.

---

## 14. Research conclusions

### Strongly supported patterns

1. **Feedback loops matter more than factory branding.**
2. **Deterministic backpressure should be cheap and early.**
3. **Human judgment should remain at high-leverage decision points.**
4. **Evals are more durable than prompts, models, or implementation details.**
5. **Agent runs should produce evidence that can be inspected after failure.**
6. **Separate problem discovery/validation from implementation.**
7. **Add orchestration only when the additional loop earns its complexity.**
8. **Evaluate models and agent-facing documentation empirically on real tasks.**

### Not established for PMB

Nothing in this research establishes that PMB needs:

- more agents;
- autonomous background execution;
- a new memory architecture;
- a custom harness;
- RAG/vector search;
- a universal eval platform;
- automated self-modification.

Those remain hypotheses to test against PMB's actual operational problems.

---

## Primary source material

- [AI That Works repository](https://github.com/ai-that-works/ai-that-works)
- [Harness Engineering Without the Hype — 2026-04-21](https://github.com/ai-that-works/ai-that-works/tree/main/2026-04-21-harness-engineering-without-the-hype)
- [OpenAI tells you not to build your own harness — 2026-05-05](https://github.com/ai-that-works/ai-that-works/tree/main/2026-05-05-openai-tells-you-not-to-build-your-own-harness)
- [Product Specs with AI — 2026-06-16](https://github.com/ai-that-works/ai-that-works/tree/main/2026-06-16-product-specs-with-ai)
- [Software Factory for Agent Tools — 2026-06-23](https://github.com/ai-that-works/ai-that-works/tree/main/2026-06-23-software-factory-for-agent-tools)
- [Agent Observability — 2026-07-07](https://github.com/ai-that-works/ai-that-works/tree/main/2026-07-07-agent-observability)
- [SOTA Coding Agent Benchmarks — 2026-07-14](https://github.com/ai-that-works/ai-that-works/tree/main/2026-07-14-sota-coding-agent-benchmarks)
- [Evaluating Prompts Across Models — 2025-07-29](https://github.com/ai-that-works/ai-that-works/tree/main/2025-07-29-eval-many-models-same-prompt)
- [Agentic Backpressure Deep Dive — 2026-02-10](https://github.com/ai-that-works/ai-that-works/tree/main/2026-02-10-agentic-backpressure-deep-dive)

## Relationship to Harness Engineering

This document is a **research record**, not a design specification. The existing Harness Engineering assessment remains the mechanism for determining whether any of these patterns correspond to observed PMB or ACR problems.
