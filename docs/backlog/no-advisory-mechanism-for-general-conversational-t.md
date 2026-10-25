---
status: open
created: 2026-09-21
last-reviewed: 2026-09-21
staleness-threshold: 90d
related_plan: null
---

# No advisory mechanism for general conversational topic drift

Task Contract Protocol's check-contract.ps1/.sh hooks mechanically enforce FILE-scope drift in real time (every Write/Edit checked against the declared contract scope), but there is no equivalent for TOPIC drift -- has the conversation itself wandered from the original request while staying inside in-scope files. docs/HOOKS-GUIDE.md's four-layer table assigns 'scope drift' to the Reviewer/Opponent semantic layer, which only runs during a full /code-review or /change-review pass, not continuously. CLAUDE.md's Governed Assistance Model frames self-monitoring for drift as Claude's own responsibility ('Claude asks, does not assume, infer a mandate, or take creative initiative') but nothing checks that this actually happens -- no periodic advisory nudge, no self-check, nothing. Found 2026-09-21 while designing the compact-nudge hook and the NS-completion handoff trigger (docs/superpowers/specs/2026-09-21-compact-nudge-hook-design.md, CLAUDE.md Handoff Protocol) -- same underlying question (has current activity diverged from the stated goal) as both of those, but unlike them, has zero mechanism today, not even advisory. Needs a design pass: what could actually detect this given a hook cannot make semantic judgments, and whether it is even mechanically reducible the way NS-completion and compact-size are.
