---
authority: volatile
review-cycle: 7d
retention: archive-after-6m
staleness-threshold: 14d
tags:
  - session/focus
  - session/blockers
  - session/next-steps
last-reviewed: 2026-05-14
compaction_generation: 0
source_type: canonical
confidence: high
lineage: []
---

# Active Context

## Current Focus

Personal fork setup complete. Ready to use as a template for new projects.

## Next Steps

1. Copy this repo's files into a new project when starting
2. Run the init script to scaffold the structure
3. Fill in memory-bank/ files with project-specific context

### Session — Token Budget Integration
Added token budget optimizations to the Personal-Memory-Bank template:
- templates/.claude/settings.json: model=sonnet, MAX_THINKING_TOKENS=10000, CLAUDE_CODE_SUBAGENT_MODEL=haiku, DISABLE_NON_ESSENTIAL_MODEL_CALLS=1
- templates/CLAUDE.md: Token Budget section + Karpathy Coding Principles appended
- scripts/mb.ps1: Added `mb budget` command (checks CLAUDE.md and memory-bank/ sizes)
- C:\Users\Mizzo\.claude\CLAUDE.md: Created global file with Karpathy principles + token budget
