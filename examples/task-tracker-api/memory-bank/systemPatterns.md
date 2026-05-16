---
authority: stable
review-cycle: 90d
retention: permanent
staleness-threshold: 180d
tags:
  - architecture/decisions
  - patterns/code
  - anti-patterns
  - patterns/api
last-reviewed: 2026-05-15
---

# System Patterns — Task Tracker API

## Architecture Decisions

### Sync SQLAlchemy, Not Async
**Decision:** Use synchronous SQLAlchemy sessions, not async.
**Rationale:** Single-user API with no concurrency requirements. Async adds complexity (dependency injection patterns, session lifecycle) that provides zero benefit here. Revisit only if this becomes multi-user.

### Flat Router Structure
**Decision:** One file per resource in `routers/`, no nested routers.
**Rationale:** The API has 4 resources. A nested structure would be premature abstraction. Add nesting only when a router exceeds ~200 lines.

### Schema Separation (models.py vs schemas.py)
**Decision:** SQLAlchemy models in `models.py`, Pydantic schemas in `schemas.py`. Never mix.
**Rationale:** Prevents accidental exposure of ORM internals in API responses. All endpoints return Pydantic schemas, never ORM objects directly.

## Code Patterns

### Response Schemas
Always use explicit Pydantic response models — never return raw dicts or ORM objects:
```python
@router.get("/tasks/{task_id}", response_model=TaskResponse)
def get_task(task_id: int, db: Session = Depends(get_db)):
    task = db.get(Task, task_id)
    if not task:
        raise HTTPException(status_code=404, detail="Task not found")
    return task
```

### Database Session
Always use the `get_db` dependency — never create sessions manually in route handlers:
```python
def get_task(task_id: int, db: Session = Depends(get_db)):
```

### 404 Pattern
Raise `HTTPException(404)` for missing resources. Never return `None` or an empty response.

### Timestamps
All timestamps stored as UTC in the DB (`datetime.utcnow()`), returned as ISO 8601 strings in responses. The client (iOS Shortcut) handles local timezone display.

## Anti-Patterns

- ❌ **Do not use `db.query(Model).filter(...)` syntax** — use `db.execute(select(Model).where(...))` (SQLAlchemy 2.x style)
- ❌ **Do not add optional fields to response schemas for "future use"** — add them when the endpoint actually uses them
- ❌ **Do not expose SQLAlchemy model objects in responses** — always go through Pydantic schemas
- ❌ **Do not add authentication middleware** — out of scope (see projectbrief.md)
- ❌ **Do not change existing response field names** — iOS Shortcuts parse by field name; renames break them silently

## Testing Patterns

Tests use an in-memory SQLite DB (`:memory:`), separate from the dev DB:
```python
# conftest.py
engine = create_engine("sqlite:///:memory:")
```

Run tests: `pytest tests/ -v`

Minimum coverage expectation: all CRUD endpoints, the timer start/stop flow, and the weekly summary calculation.
