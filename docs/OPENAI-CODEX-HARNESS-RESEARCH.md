# OpenAI Codex — Harness / Agent Workflow Research

**Research date:** 2026-08-29  
**Source repository:** https://github.com/openai/codex  
**Source commit researched:** `f5636bb733c4653a6b91413fed1aaf8842374f2e`  
**Source branch:** `main`  
**Repository status at capture:** public, not archived  
**License:** Apache-2.0  
**Status:** Research input only. No PMB architecture change is implied by this document.

## Preservation / provenance

This is a durable PMB research record of the Codex repository as inspected on 2026-08-29. We are preserving the conclusions and provenance, not mirroring the external repository.

The commit SHA identifies the exact source revision used for the review. The upstream repository may continue to change; future claims should be re-verified against a newer revision when material.

### Source areas inspected

- `AGENTS.md`
- `codex-rs/skills/`
- `codex-rs/skills/src/assets/samples/review-agent/SKILL.md`
- Codex repository structure and current repository metadata

---

## Why this was captured

The useful question is not whether PMB should imitate Codex. It is which mechanisms Codex uses to make agent work bounded, reviewable, testable, and maintainable, and whether any of those mechanisms address an observed PMB / ACR problem.

The current Codex repository describes itself as a lightweight coding agent, but the engineering guidance around it contains several useful patterns for agent authority, context management, review, testing, and change sizing.

---

## 1. Authority should be explicit, not merely requested in a prompt

Codex's sample `review-agent` skill explicitly makes the reviewer read-only: it must not modify files, create commits, push branches, post review comments, or delegate the review. It also requires the reviewer to inspect the complete requested target and enough surrounding code to understand changed paths.

### PMB / ACR implication

This reinforces a broader design principle:

> **If a role must not mutate state, make that boundary part of the execution contract or tooling where practical; do not rely solely on prose saying "don't change anything."**

This is especially relevant to ACR and any future advisory/review roles.

Do not infer that PMB needs OS-level sandboxing for every role. The mechanism should match the actual risk.

---

## 2. Review the actual merge target, not whatever local diff happens to be convenient

Codex's review-agent guidance is unusually explicit about base-branch review. It resolves the comparison ref, uses `git merge-base`, and reviews the diff from the merge base rather than blindly comparing against a branch tip. It also tries the configured upstream when the local branch cannot be resolved.

### PMB / ACR implication

This is directly relevant to the recent Big Pickle experiment, where the reviewer reported a working-tree scope while the repository state had already changed.

A review contract should establish **what exact state is being reviewed** before findings are generated.

Candidate invariant:

> **Every review result identifies the target revision/range it actually inspected.**

This is more important than adding another reviewer prompt.

---

## 3. Findings require evidence and must be introduced by the reviewed change

The review-agent skill requires every finding to be:

- meaningful for correctness, security, performance, or maintainability;
- discrete and actionable;
- introduced by the reviewed change;
- demonstrable from code/call path;
- something the author would probably fix.

It explicitly excludes speculative concerns, pre-existing problems, intentional behavior changes, and style nits that do not obscure the code.

### PMB / ACR implication

This is a useful **finding contract**. It gives ACR a stronger basis for distinguishing a real review finding from a plausible-sounding concern.

It should be evaluated against ACR's existing finding schema rather than copied blindly.

---

## 4. "No findings" is a valid result

Codex explicitly instructs the review agent to return `No findings.` when no qualifying issue exists and not to invent a finding merely to fill the result.

### PMB / ACR implication

This is small but important. A reviewer should have an explicit, successful empty-result state. Otherwise multi-agent systems can drift toward producing noise because an answer is expected.

This is particularly relevant to the planned multi-model review experiment: **finding count should not be treated as quality.** False positives are a first-class failure mode.

---

## 5. Context has hard bounds

Codex's repository guidance says model-visible context must be built incrementally, avoid unnecessary history rewrites, and have bounded item sizes. It sets a hard maximum of 10K tokens for individual injected items and calls out newly added items that can exceed 1K tokens for additional review.

### PMB implication

The important idea is not the exact token numbers. It is the policy shape:

> **Every context injection should have an explicit size boundary.**

This connects strongly to the other context research already captured in PMB: context should be selected and bounded for the task rather than accumulating indefinitely.

We should not copy Codex's thresholds without evidence that they fit PMB.

---

## 6. Context changes can have operational cost

Codex's guidance warns against frequent context changes that cause cache misses and favors incremental construction.

### PMB implication

When evaluating context-management changes, measure not only answer quality but also execution cost and cache behavior where observable.

This supports a practical rule:

> **Do not add context machinery merely because it is theoretically cleaner; establish that the change improves the task enough to justify its runtime/token cost.**

---

## 7. Prefer explicit API shapes over ambiguous parameters

The repository's engineering guidance discourages boolean or ambiguous `Option` parameters that make call sites opaque, preferring enums, named methods, or newtypes when they make intent clearer.

### PMB implication

This is ordinary software-engineering guidance, but it is especially applicable to PMB's CLI and harness controls. User-facing commands should make important modes obvious rather than encoding behavior in unexplained flags or positional booleans.

This supports the existing direction toward small interactive choices rather than a large flag matrix.

---

## 8. Keep orchestration modules from becoming dumping grounds

Codex explicitly resists continuing to grow `codex-core`, encourages new modules for new concepts, and targets smaller Rust modules. It also discourages one-off helper methods and asks contributors to minimize API surface.

### PMB implication

This is a useful counterweight to harness engineering becoming a single giant orchestrator.

The transferable principle is:

> **Keep ownership explicit and keep central orchestration from absorbing every new concern.**

But this does **not** imply PMB should introduce more modules or abstractions now. The actual PMB structure should determine whether this becomes a problem.

---

## 9. Tests should exercise agent behavior at the integration level

Codex's guidance says agent changes should prefer integration tests over unit tests and that changes to agent logic must add an integration test describing major logic changes and user-facing behavior. It also recommends deep object comparisons where practical.

### PMB / ACR implication

For agent/harness changes, unit tests can prove local mechanics but cannot establish that the whole workflow behaves correctly.

A useful testing hierarchy is:

1. deterministic unit tests for local transformations;
2. integration tests for agent workflow behavior;
3. fixed evaluation tasks for cross-model/harness comparisons;
4. human judgment for criteria that cannot be reduced safely to a deterministic assertion.

This is a stronger model than relying on a growing unit-test count alone.

---

## 10. Change size is itself a reviewability constraint

Codex places explicit limits around large changes and recommends splitting large changes into reviewable stages based on the actual diff and dependencies.

### PMB implication

This supports staged harness changes. A complicated improvement should land as the smallest coherent contract first, followed by implementation and optimization, rather than combining all three.

This is particularly relevant when PMB changes involve memory, orchestration, CLI behavior, and agent prompts at the same time.

---

## 11. Skills are executable contracts, not just prompt snippets

The Codex skill system treats a skill as a structured artifact with a narrow purpose, explicit behavioral rules, and references/tests around it. The review-agent skill is a concrete example: scope, authority, review procedure, finding criteria, priorities, and output contract are all explicit.

### PMB implication

This reinforces treating agent-facing instructions as an **interface contract**.

For PMB skills, the useful questions are:

- What inputs are assumed?
- What state may the skill inspect or mutate?
- What must it verify?
- What is a valid empty result?
- What evidence must accompany a claim?
- What exact output shape does the caller depend on?

These can be tested rather than trusted because the prose sounds good.

---

## 12. Completion and verification should be separable

Codex's broader agent design is useful as a model for separating the act of producing work from the act of deciding whether that work satisfies its contract. The review-agent guidance itself embodies this by requiring the reviewer to inspect the complete change and validate findings rather than accepting an agent's own completion statement.

### PMB / ACR implication

This connects directly to the current "did the model actually finish the work it presented?" research.

A stronger completion pattern is:

> **Task contract → execution → observable evidence → independent verification → completion decision**

The model saying "done" is an output, not proof.

---

## 13. What we should NOT copy from Codex

Nothing in this research establishes that PMB needs:

- Codex's Rust/Bazel architecture;
- its full app-server/TUI machinery;
- its exact context token thresholds;
- its complete skill packaging/build system;
- a larger orchestration framework;
- additional agents merely because Codex has multiple roles;
- a universal review framework.

Those are implementation choices for Codex's environment unless PMB evidence demonstrates otherwise.

---

## 14. Candidate PMB / ACR experiment inputs

Codex suggests several concrete dimensions for the next controlled experiment once ACR is stable:

### Review-target integrity

Give every reviewer an explicit target identifier (commit SHA or merge-base/range) and compare whether models report the correct target.

### Finding discipline

Use the same change containing a mix of real issues, intentional changes, and plausible-but-speculative concerns. Measure:

- true positives;
- false positives;
- missed findings;
- whether findings are actionable;
- whether citations overlap the actual reviewed change.

### Empty-result discipline

Include clean changes and measure whether the model correctly returns no findings rather than manufacturing one.

### Completion integrity

Require the reviewer to state what target it inspected and what verification it performed. Compare that statement against the actual execution evidence.

These are much more valuable than simply asking which model "feels smartest."

---

## Research conclusion

The most useful Codex lesson for PMB is not a new architecture. It is **contract discipline**:

> **Bound authority, bound context, define the review target, require evidence, allow a valid empty result, and separate completion claims from verification.**

Those mechanisms fit naturally with the research already gathered around PMB, ACR, context engineering, Unlazy, and software-factory loops.

The strongest candidate for eventual implementation is therefore not "build Codex-like orchestration." It is to strengthen the **contracts around the work we already do**.

---

## Primary source

- https://github.com/openai/codex
- `AGENTS.md` at commit `f5636bb733c4653a6b91413fed1aaf8842374f2e`
- `codex-rs/skills/src/assets/samples/review-agent/SKILL.md` at commit `f5636bb733c4653a6b91413fed1aaf8842374f2e`
