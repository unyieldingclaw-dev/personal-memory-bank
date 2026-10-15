---
authority: stable
review-cycle: 90d
retention: permanent
staleness-threshold: 180d
tags:
  - architecture/decisions
  - patterns/code
  - anti-patterns
last-reviewed: 2026-05-14
compaction_generation: 0
source_type: canonical
confidence: high
lineage: []
---

# System Patterns

## Core Concepts

### Memory Bank (5 files)
Persistent context across AI sessions. Read at session start, updated after significant changes.

### Security Guardrails (3-tier)
- BLOCK — refuse (force push, hardcoded secrets, destructive commands)
- CONFIRM — ask first (deletions, bulk ops, CI changes, schema changes)
- WARN — note the risk (large changes, missing tests, new files)

### 7-Phase Feature Workflow
Brainstorm → Spec → Plan → Implement → Simplify → Security Review → Commit

### Handoff Protocol
At 40% context (or user types "Handoff"): stop, write handoff.md, start new chat.


### Skill Composition, Routing, and Promotion (2026-10-15)

Mined from Anthropic's public Small Business skill library and its current router/build-agent patterns.
The business workflows themselves are not PMB dependencies; the transferable design rules are.

- **Composition role is a second axis, not a replacement taxonomy.** A skill may be a utility
  (one bounded job) or an orchestrator (select/order utilities and combine their outputs). Keep that
  separate from what the skill *is* — workflow, reviewer, diagnostic, implementation heuristic,
  domain reference, etc.
- **Route by plain-language intent to one best capability.** Do not make users memorize commands or
  dump a menu when one route clearly owns the request. When two skills plausibly match the same
  phrasing, fix the boundary: positive triggers, negative/exclusion triggers, explicit precedence,
  or one clarifying question.
- **Treat routing collisions as correctness and cost defects.** Loading the wrong skill wastes
  context, can start the wrong work, and often forces a second run. Audit sibling skill
  descriptions for overlapping trigger phrases whenever a collision is found.
- **Create reusable skills from observed behavior, not invented abstraction.** Prefer a real task
  the user just completed. Extract the transcript's corrections as candidate rules, separate
  **fixed** steps from **variable** inputs and **judgment** points, then turn consequential or
  ambiguous judgment into approval gates.
- **Replay before promotion.** Test a candidate skill against a case whose expected outcome is
  already known. A skill that has not reproduced a known-good case is not ready to become a
  trusted reusable workflow.
- **Shared policy has one owner.** Cross-cutting style, safety, authority, and output conventions
  should be referenced from a canonical owner rather than copied into every skill. Keep the
  always-loaded routing contract small; load detailed guidance only when the task needs it.
- **Automate toward the authority boundary, not through it.** Gathering, normalizing, checking,
  ranking, and drafting are good automation targets. Sending, publishing, deleting, paying,
  signing, merging, or other consequential actions remain explicit human decisions unless the
  project's authority model deliberately says otherwise.
- **Skill libraries need retirement, not only growth.** Create → use → measure → consolidate →
  retire. Remove or merge low-value/overlapping skills instead of allowing routing surface and
  maintenance cost to grow forever.

## Coding Principles

- Think before coding — explore alternatives before writing
- Simplicity first — smallest change that solves the problem
- Surgical changes — touch only what needs to change
- Goal-driven — if a step doesn't serve the goal, skip it
