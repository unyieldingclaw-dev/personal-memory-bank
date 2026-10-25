---
authority: stable
review-cycle: 90d
retention: permanent
staleness-threshold: 180d
tags:
  - performance/budget
  - performance/context
last-reviewed: 2026-05-31
compaction_generation: 0
source_type: canonical
confidence: high
lineage: []
---

# Performance Budget

PMB's primary performance cost is LLM context consumption, not compute.
This document defines explicit limits to prevent gradual context bloat.

## Limits

| Dimension | Limit | Action if Exceeded |
|-----------|-------|-------------------|
| Standards files (`standards/`) | ≤ 20 | Archive or merge redundant standards |
| Memory bank entries (lines in `progress.md`) | ≤ 50 | Run `mb clean` |
| Agent spawns per 2-hour window | ≤ 6 | Consolidate tasks or batch |
| Agent delegation depth (nesting) | 1 | Refactor to inline; not machine-enforced — see below |
| Default scan scope | Changed files first | Full-repo is explicit opt-in only |
| Full-repo scan | Explicit request only | Never triggered automatically |
| Fixture files per security rule | 1 | Keep fixtures minimal |

## Why These Limits

**Standards proliferation** grows context linearly. Every standard added increases tokens
loaded, retrieval work, and reasoning time on every session.

**Duplicate context** is the second risk. Multiple copies of the same content (`.claude/`,
`.cursor/`, generated artifacts) each cost tokens if loaded. Maintain a single source of
truth; generate copies, do not duplicate them independently.

**Agent chains** that call other agents recursively are the primary path to O(n²) complexity.
Keep delegation depth to 1 — but read the next paragraph before treating that as enforced.

**Two different limits, and only one of them is checked.** *Depth* is how deeply delegation nests
(an agent spawning an agent). *Spawn count* is how many agents were started in a window, however
flat. `scripts/delegation-depth-check.{sh,ps1}` measures the SECOND and warns above 6, because the
first is not observable: there is no `PostToolUse:Agent` hook, so nothing can tell a returning
agent from a nesting one. The depth-1 guidance above therefore remains real guidance and is not
machine-enforced, while the number the hook actually prints is a cumulative spawn count.

Recorded because these were conflated for months: this table read "≤ 1" while the shipped hook
had used 6 since `5c0e8c9`, and the hook's own comment cited *this file* as the authority for 6.
Corrected 2026-09-03. If you change the budget, change it in `delegation-depth-check.sh`, its
`.ps1` twin, this table, and `standards/AGENTIC-SAFETY.md` — four hand-synced copies, tested only
for shell-to-shell parity, not against this document.

## mb doctor Integration

`mb doctor` Check 14 counts `.md` files in `standards/` and warns if > 20.
The current count is shown at runtime — run `mb doctor` to see it.

## What to Do When Limits Are Reached

- **Standards > 20:** Review for overlap. Can two standards merge? Is one superseded?
- **Memory entries > 50:** Run `mb clean` on `progress.md` to move completed items.
- **Agent spawns > 6 in a window:** Consolidate related tasks into one well-scoped agent, or batch
  them. The hook warns and continues; it never blocks, because spawning is a user decision.
- **Agent chain nesting > 1:** Inline the sub-task or make it a separate user-invoked command. No
  hook detects this — it is caught in review, not at runtime.
