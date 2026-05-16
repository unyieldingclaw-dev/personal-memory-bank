---
authority: stable
review-cycle: 30d
retention: permanent
staleness-threshold: 90d
tags:
  - stack/backend
  - env/tools
  - stack/database
last-reviewed: 2026-05-15
---

# Tech Context — Task Tracker API

## Development Environment

| Component | Value |
|-----------|-------|
| OS | Windows 11 (dev), Ubuntu 22.04 (prod VPS) |
| Shell | PowerShell (dev), bash (prod) |
| Python | 3.11+ |
| IDE | Cursor + Claude Code |
| Git remote | github.com/mizzo/task-tracker-api |

## Stack

### Backend
- **Framework:** FastAPI 0.110+
- **Server:** Uvicorn (dev: `--reload`, prod: systemd service)
- **Validation:** Pydantic v2
- **Database:** SQLite via SQLAlchemy 2.x (sync, not async — simpler for single-user)
- **Migrations:** Alembic

### Key Dependencies
```
fastapi==0.110.0
uvicorn==0.29.0
sqlalchemy==2.0.29
alembic==1.13.1
pydantic==2.6.4
python-dateutil==2.9.0
rich==13.7.1        # CLI output for mb-style scripts
```

## Project Layout

```
task-tracker-api/
├── main.py              # FastAPI app, mounts all routers
├── models.py            # SQLAlchemy ORM models
├── schemas.py           # Pydantic request/response schemas
├── database.py          # DB session, engine setup
├── routers/
│   ├── tasks.py         # /tasks CRUD
│   ├── projects.py      # /projects CRUD
│   ├── timer.py         # /tasks/{id}/timer start/stop
│   └── summary.py       # /summary/weekly
├── alembic/             # migrations
├── memory-bank/         # AI context files
└── tests/
```

## Running Locally

```bash
python -m uvicorn main:app --reload --port 8000
# API at http://localhost:8000
# Docs at http://localhost:8000/docs
```

## Database

- File: `tasks.db` in project root (gitignored)
- Migrations: `alembic upgrade head`
- Reset: delete `tasks.db` and re-run migrations (dev only)

## Prod Deployment

- VPS: Hetzner CX21, Ubuntu 22.04
- Service: systemd unit at `/etc/systemd/system/task-tracker.service`
- Port: 8000, proxied via nginx on port 443
- Deploy: `git pull && systemctl restart task-tracker`
