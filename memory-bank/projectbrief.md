---
authority: immutable
review-cycle: never
retention: permanent
staleness-threshold: 365d
tags:
  - requirements/core
  - constraints/non-negotiable
last-reviewed: 2026-05-14
compaction_generation: 0
source_type: canonical
confidence: high
lineage: []
---

# Project Brief

## Purpose

This is my personal AI coding standard — a set of rules, templates, and commands that I copy into any new project to get consistent, high-quality AI-assisted development.

## Non-Negotiable Requirements

- Memory Bank state is available at session start: an index is loaded, detail is fetched on
  demand — context persists across conversations without every file being loaded in full
- Security guardrails (BLOCK/CONFIRM/WARN) are always active
- Code quality standards apply to all generated code
- 7-phase workflow for non-trivial features

## Meta-Rule for This File

**Immutable-tier entries state GOALS, never MECHANISMS.** The requirement above previously read
"Memory Bank files are read at session start" — a 2024 implementation frozen into the tier that
cannot be revised, which then blocked its own replacement: the mechanism could not be improved
without amending a file marked `review-cycle: never`. A goal ("state is available") admits better
mechanisms; a mechanism ("files are read") forbids them. Amended 2026-08-30 under explicit prior
authorization, sequenced after the commit-signing change landed (`030662c`).

## Constraints

- Setup time for a new project: < 10 minutes
- Works in both Claude Code and Cursor
- No external dependencies (self-contained Markdown and config files)
