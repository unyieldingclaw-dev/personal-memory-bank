---
authority: immutable
review-cycle: never
retention: permanent
staleness-threshold: 365d
tags:
  - requirements/core
  - constraints/non-negotiable
last-reviewed: 2026-05-15
---

# Project Brief — Task Tracker API

## Purpose

A personal task tracking REST API. I use it to manage work items across projects, track time, and generate weekly summaries. Built for my own use — no multi-tenancy, no auth complexity, just a clean API I can call from scripts and mobile shortcuts.

## Non-Negotiable Constraints

- **No cloud dependencies in the hot path** — SQLite primary, no external DB required to run locally
- **Single binary deploy** — the whole thing runs with `python main.py`, no Docker required for local dev
- **Sub-100ms response times** for all list/get endpoints under 1000 tasks
- **No breaking API changes** — I have scripts and iOS Shortcuts that call this API; changing response schemas breaks them silently

## What It Does

- CRUD for tasks (title, project, status, due_date, time_spent)
- Project grouping and filtering
- Time tracking (start/stop timer per task)
- Weekly summary endpoint (tasks completed, time by project)
- Markdown export for weekly review

## Out of Scope

- User accounts / authentication (single-user only)
- Real-time updates / WebSockets
- File attachments
- Mobile app (iOS Shortcuts call the API directly)
