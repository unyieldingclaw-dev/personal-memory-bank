---
authority: volatile
review-cycle: 7d
retention: archive-after-6m
staleness-threshold: 14d
tags:
  - session/focus
  - session/next-steps
  - session/blockers
last-reviewed: 2026-05-15
---

# Active Context — Task Tracker API

## Current Focus

Adding the **Markdown export endpoint** (`GET /summary/weekly/export`) so I can paste weekly output directly into my review notes.

## Next Steps

1. **Implement `/summary/weekly/export`** — returns Markdown string, not JSON
   - Reuse the existing `weekly_summary()` helper in `routers/summary.py`
   - Format: `## Week of YYYY-MM-DD\n### By Project\n- project: Xh Ym (N tasks)`
   - Response content-type: `text/plain` (not `application/json`)

2. **Write tests for the export endpoint** — use `TestClient`, assert response is valid Markdown

3. **Update iOS Shortcut** — change URL from `/summary/weekly` to `/summary/weekly/export` for the "Weekly Review" shortcut

## Known Issues

- `GET /tasks?project=foo` returns 200 with empty list when project doesn't exist — should return 404. Low priority, doesn't affect iOS Shortcut (it always creates the project first).

## Environment Status

- Dev server: run `python -m uvicorn main:app --reload`
- DB: `tasks.db` in project root, already migrated to latest schema
- Prod: running v0.4.1, last deployed 2026-05-10

## Recent Decisions

- Chose `text/plain` over `application/json` for the export endpoint — the iOS Shortcut copies it directly to clipboard, simpler without JSON parsing
- Decided NOT to add date-range params to the export endpoint for now — `?week_offset=N` can be added later if needed
