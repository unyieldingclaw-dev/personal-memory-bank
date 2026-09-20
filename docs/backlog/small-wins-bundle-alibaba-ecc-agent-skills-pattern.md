---
status: open
created: 2026-09-19
last-reviewed: 2026-09-19
staleness-threshold: 90d
related_plan: null
---

# Small-wins bundle: Alibaba/ECC/agent-skills patterns

Three Medium-fit candidates from the 2026-09-18 video-brainstorm survey (docs/VIDEO-BRAINSTORM-BACKLOG-2026-09-18.md), meant as ONE spec, not three. (1) Alibaba open-code-review: not its LLM engine (needs external API, conflicts with PMB's no-external-dependency charter) -- just its structured JSON findings schema (severity+category) and local static HTML results viewer; PMB's review gate findings currently live only in prose/commit messages. (2) ECC: RED-gate wording 'written but not executed ≠ RED' (blocks false-pass claims), and a structured TDD-evidence-report as a defined Commit-phase artifact. (3) agent-skills: post-launch production-verification checklist (health endpoint, error dashboard, critical-flow smoke test) -- PMB's workflow currently ends at Commit/Ship with no post-deploy check at all. Priority: after claude-dashboard.
