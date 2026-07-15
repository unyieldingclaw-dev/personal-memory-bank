---
status: open
created: 2026-07-14
last-reviewed: 2026-07-14
staleness-threshold: 90d
related_plan: null
---

# Audit PMB for missing/inefficient skills

Run an audit across PMB to identify functionality that currently exists (CLI commands, hook
behaviors, workflows) but isn't exposed as a discoverable skill/command
(`.claude/commands/*.md`) — following the same discoverability pattern used for `/backlog`
(docs/superpowers/specs/2026-07-14-backlog-design.md): a well-crafted `description:` gets a
capability noticed every session, at zero standing CLAUDE.md/memory-bank footprint. Candidates
to check: anything currently only reachable by remembering to type an `mb` CLI command directly,
or by knowing it exists from prior conversation rather than from an automatic prompt.

Also audit the *existing* skill/command set for efficiency — description length/token cost, any
overlapping or redundant skills, whether some are broader than they need to be.

Separately, look into a "master skills.md" pattern — a lightweight index/reference file that
points to the main skills rather than each skill carrying its full detail inline — as a possible
way to reduce context bloat further, either as an alternative to or a complement of the
per-skill-description mechanism already in use. Not yet clear whether this solves a real problem
here or duplicates what the automatic skill-description delivery already provides — worth
investigating rather than assuming.
