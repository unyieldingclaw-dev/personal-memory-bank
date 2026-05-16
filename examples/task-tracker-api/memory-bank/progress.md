---
authority: accumulating
review-cycle: 30d
retention: archive-after-6m
staleness-threshold: 90d
tags:
  - work/completed
  - work/in-progress
  - work/backlog
last-reviewed: 2026-05-15
---

# Progress — Task Tracker API

## Completed

### Core API (v0.1.0 — v0.3.0)
- [x] Task CRUD (`GET/POST/PUT/DELETE /tasks`)
- [x] Project CRUD (`GET/POST/PUT/DELETE /projects`)
- [x] Task filtering by project, status, due date
- [x] Alembic migrations setup
- [x] Pydantic v2 schemas for all endpoints
- [x] SQLAlchemy 2.x query style throughout (no legacy `.query()`)

### Timer (v0.4.0)
- [x] `POST /tasks/{id}/timer/start` — records start timestamp
- [x] `POST /tasks/{id}/timer/stop` — calculates elapsed, adds to `time_spent`
- [x] Guard: timer/start returns 409 if timer already running
- [x] Guard: timer/stop returns 409 if no active timer

### Weekly Summary (v0.4.1)
- [x] `GET /summary/weekly` — returns JSON: tasks completed, time by project
- [x] Week boundaries in UTC, `week_offset` param for past weeks

### Deployment
- [x] Systemd service on Hetzner VPS
- [x] Nginx reverse proxy with SSL
- [x] Git-push deploy workflow

## In Progress

- [ ] `GET /summary/weekly/export` — Markdown export (see activeContext.md)

## Backlog

- [ ] `?project=foo` returning 200 with empty list for unknown projects (low priority)
- [ ] Bulk status update endpoint (`PATCH /tasks/bulk`)
- [ ] Task archiving (soft delete, hidden from default list)
- [ ] `GET /tasks/due-today` convenience endpoint

## Version History

| Version | Date | Summary |
|---------|------|---------|
| 0.4.1 | 2026-05-10 | Weekly summary endpoint |
| 0.4.0 | 2026-04-22 | Timer start/stop |
| 0.3.0 | 2026-04-01 | Project CRUD, task filtering |
| 0.2.0 | 2026-03-15 | Full task CRUD, Alembic |
| 0.1.0 | 2026-03-01 | Initial FastAPI scaffold |
