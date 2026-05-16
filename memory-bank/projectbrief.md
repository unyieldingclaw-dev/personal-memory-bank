---
authority: immutable
review-cycle: never
retention: permanent
staleness-threshold: 365d
tags:
  - requirements/core
  - constraints/non-negotiable
last-reviewed: 2026-05-14
---

# Project Brief

## Purpose

This is my personal AI coding standard — a set of rules, templates, and commands that I copy into any new project to get consistent, high-quality AI-assisted development.

## Non-Negotiable Requirements

- Memory Bank files are read at session start — they persist context across conversations
- Security guardrails (BLOCK/CONFIRM/WARN) are always active
- Code quality standards apply to all generated code
- 7-phase workflow for non-trivial features

## Constraints

- Setup time for a new project: < 10 minutes
- Works in both Claude Code and Cursor
- No external dependencies (self-contained Markdown and config files)
