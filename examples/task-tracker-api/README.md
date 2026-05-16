# Example: Task Tracker API

This is a realistic example of a fully populated Memory Bank for a small Python/FastAPI project.

Use it as a reference when filling in your own project's memory-bank files.

## What This Shows

- **projectbrief.md** — clear constraints, explicit out-of-scope items, no filler text
- **techContext.md** — specific versions, exact commands to run things, deployment notes
- **systemPatterns.md** — decisions with rationale, anti-patterns with reasons, concrete code examples
- **activeContext.md** — focused current work, specific next steps, recent decisions
- **progress.md** — version history, concrete backlog (not "future ideas")

## Key Habits Demonstrated

**Be specific.** `fastapi==0.110.0` is more useful than `FastAPI`. `"Do not use .query() syntax"` is more useful than `"Follow best practices"`.

**Document the why.** `systemPatterns.md` explains *why* decisions were made, not just what was decided. Without the rationale, the AI (and future-you) can't tell which decisions are load-bearing.

**Keep activeContext.md small and current.** This example has one clear focus area and three next steps. If you have ten next steps in activeContext, it's a sign some of them belong in progress.md backlog.

**Anti-patterns with teeth.** Each ❌ in systemPatterns.md names a specific thing and says why it's forbidden. `"Don't break the API"` doesn't tell an AI anything. `"Do not change existing response field names — iOS Shortcuts parse by field name; renames break them silently"` does.
