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
At 65% context: stop, write handoff.md, start new chat.

## Coding Principles

- Think before coding — explore alternatives before writing
- Simplicity first — smallest change that solves the problem
- Surgical changes — touch only what needs to change
- Goal-driven — if a step doesn't serve the goal, skip it
