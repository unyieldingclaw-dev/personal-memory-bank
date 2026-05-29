# Archive

Flat directory for ephemeral artifacts that have served their purpose
but are worth keeping for reference.

## Naming conventions

| Artifact | Filename pattern | Example |
|---|---|---|
| Handoffs | `handoff-YYYY-MM-DD.md` | `handoff-2026-05-29.md` |
| Memory snapshots | `snapshot-YYYY-MM-DD.md` | `snapshot-2026-05-29.md` |
| Slim outputs | `slim-YYYY-MM-DD.md` | `slim-2026-05-29.md` |
| Context evictions | `context-YYYY-MM-topic.md` | `context-2026-05-auth-refactor.md` |
| Progress evictions | `progress-YYYY-MM-topic.md` | `progress-2026-05-v1-release.md` |

## Rules
- One topic or time period per file — never append to an existing archive file
- Add subfolders only when the flat listing becomes hard to scan (>50 files)
- Files here are reference-only — do not load them into Memory Bank
