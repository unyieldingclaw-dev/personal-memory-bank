---
status: open
created: 2026-09-21
last-reviewed: 2026-09-21
staleness-threshold: 90d
related_plan: null
---

# Pre-approval adversarial review ('poke holes') for specs and plans

User request 2026-09-21. The user currently supplies adversarial review manually by typing 'poke holes' / 'look one more time' before approving specs and plans. The closest existing mechanism, standards/WORKFLOW.md Phase 3.5 (Independent Plan Review), falls short on four counts: advisory not a gate; plans only, not specs; no command or skill; and it runs after planning rather than before user approval. It was not applied at any point in the compact-nudge-hook spec's life. Evidence of value: the 2026-09-21 poke-holes pass on docs/superpowers/specs/2026-09-21-compact-nudge-hook-design.md found a ~5.6 s per-prompt stall (Get-Content -Tail on a 21 MB transcript) and a false config premise (the autocompact override assumed to be 65 for compactions that predate that commit). The spec's own self-review and a prior approval had missed both. Both were found by EXECUTING checks (timing, git log), not by reading, so the mechanism should require re-running claims, not just reading them. Design questions: dispatch the existing Opus-pinned opposition agent vs a new agent; a command (/poke-holes <path>) vs a step in the brainstorming/writing-plans user-review gate; whether promoting Phase 3.5 to a gate conflicts with projectbrief.md's fixed 7-phase requirement (Tier 1) -- check before designing. Semantic judgment belongs at the Reviewer/Opponent layer per docs/HOOKS-GUIDE.md; a hook could at most check a structural marker.
