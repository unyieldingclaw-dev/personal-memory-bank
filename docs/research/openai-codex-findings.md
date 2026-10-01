# OpenAI Codex findings relevant to PMB and ACR

**Status:** Research staging only. Not an adopted PMB or ACR design decision.
**Captured:** 2026-08-29

## Why this is being captured

OpenAI's Codex repository and engineering material provide useful evidence about agent harness design, repository context, skills, review agents, multi-agent execution, and operational guardrails. Capture these observations while PMB is being stabilized so they are not lost.

## PMB-relevant findings

### 1. Repository knowledge as a map, not an encyclopedia

OpenAI's harness-engineering writeup describes a short `AGENTS.md` as a table of contents while the structured `docs/` directory is the system of record. The rationale is that a giant instruction file consumes scarce context, makes everything look important, rots, and is difficult to verify mechanically.

Potential PMB question: whether PMB should distinguish a compact navigation/instruction layer from deeper, structured memory rather than continually growing one large instruction surface.

Source: https://openai.com/index/harness-engineering/

### 2. Explicit review-agent contract

Codex's sample `review-agent` skill is unusually concrete: read applicable instructions, inspect the complete diff and surrounding code, continue through the whole diff after finding an issue, verify findings against tests/call sites, and report only actionable defects introduced by the change. It also explicitly forbids modifying files or delegating the review.

Potential PMB question: whether reusable agent roles benefit from explicit authority boundaries and output contracts rather than broad persona instructions.

Source: https://github.com/openai/codex/blob/main/codex-rs/skills/src/assets/samples/review-agent/SKILL.md

### 3. Evidence attached to agent work

OpenAI describes Codex producing verifiable evidence of actions through terminal logs and test outputs, and emphasizes configured development environments and reliable testing setups.

Potential PMB question: whether important memory claims should retain provenance/evidence sufficient for later validation rather than only storing conclusions.

Source: https://openai.com/index/introducing-codex/

### 4. Bounded multi-agent execution

Codex's experimental collaboration prompt says multi-agent execution is useful for very large tasks with well-defined scopes, independent review, fresh-context debate, or dedicated test execution. It also warns against unnecessary spawning and recursive delegation.

Potential PMB question: whether any future autonomous memory/consolidation work should use bounded, explicit jobs rather than open-ended agent recursion.

Source: https://github.com/openai/codex/blob/main/codex-rs/core/templates/collab/experimental_prompt.md

### 5. Layered instructions can create meta-workflow failure

A current Codex issue reports that layered `AGENTS.md` guidance and reusable skills can lock an agent into repeated planning/review meta-workflows instead of executing an already-approved plan. This is a community-reported issue, not an OpenAI design guarantee, but it is relevant evidence against indiscriminate layering.

Potential PMB question: how to detect instruction/memory systems that cause an agent to spend effort managing the process instead of doing the requested work.

Source: https://github.com/openai/codex/issues/36555

## ACR-relevant findings

These should be evaluated separately in ACR rather than imported into PMB automatically.

### 1. Review-agent contract is directly relevant

The Codex review-agent pattern is a strong candidate for comparison with ACR's reviewer contract: defect-first, read-only, diff-scoped, actionable, introduced-by-change, demonstrated from code, and tested against relevant call paths.

This is especially relevant because ACR's current experiments have exposed reviewers that produce plausible but stale, mis-cited, or speculative findings. ACR should compare its own reviewer contract against this stricter gate.

### 2. Review the actual merge target

The Codex review skill explicitly distinguishes reviewing a branch tip from reviewing the changes that would actually merge. For a base-branch review it resolves the upstream comparison and uses the merge base before inspecting the diff.

ACR investigation: verify that ACR consistently reviews the intended merge delta rather than a stale local/HEAD interpretation, and that the review records which commit/ref was actually reviewed.

### 3. No finding without demonstrated evidence

The Codex contract requires the affected scenario/call path to be demonstrable and says not to flag speculative concerns, pre-existing problems, intentional changes, or style nits.

ACR investigation: test whether adding explicit evidence gates improves precision without suppressing legitimate defects. This is a candidate for the controlled reviewer experiment already planned.

### 4. Multi-agent fan-out needs a cost/benefit boundary

Codex documentation says multi-agent execution should be used wisely and not for simple tasks. Current community issues also report substantial fixed context/tool overhead per spawned subagent and pathological recursive delegation in some workflows.

ACR investigation: measure whether additional specialist reviewers actually increase unique, actionable findings after deduplication, versus simply multiplying context and false positives.

### 5. Skills as reusable operational contracts

Codex treats skills as bundles of instructions, resources, and scripts for repeatable workflows. The app can automatically or explicitly invoke them.

ACR investigation: compare this with ACR's reviewer definitions and orchestration. The useful idea is not copying Codex's skill mechanism, but making reviewer behavior explicit, bounded, and testable.

## Things not to conclude yet

- Do not infer that Codex's architecture should be copied into PMB or ACR.
- Do not treat community GitHub issues as authoritative product behavior.
- Do not add more agents, memory layers, or instruction files merely because Codex has them.
- The strongest candidates for experimentation are **review-target correctness, evidence gates, explicit reviewer contracts, and bounded fan-out**.

## Follow-up experiments

1. Compare ACR findings with and without an explicit "reviewed commit/ref + merge-base" declaration.
2. Run the same review task through ACR reviewers with a strict evidence/actionability gate and measure precision/recall qualitatively or quantitatively.
3. Measure unique actionable findings as reviewer count increases, including token/time cost and duplicate findings.
4. Test whether adding more instruction layers improves results or merely increases planning/meta-work.
