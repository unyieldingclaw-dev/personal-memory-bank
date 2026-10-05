---
status: open
created: 2026-09-21
last-reviewed: 2026-09-21
staleness-threshold: 90d
related_plan: null
---

# handoff.md is a single unscoped file shared across concurrent sessions in the same directory

pre-compact-check.sh's handoff-bypass (lines 56-64) accepts ANY handoff.md dated today regardless of author or content, and handoff.md itself has no session-scoping -- confirmed live 2026-09-21 when the 'PMB full review and PR #12 disposition' session's handoff.md (14:43 today) silently overwrote this session's own earlier handoff.md, and would bypass pre-compact-check for any other session sharing this directory today regardless of relevance. Same session-identity gap as the compact-nudge-hook spec's per-session state-file problem and the concurrent-session-claims branch's claim-identity bug (uses branch name). Needs a per-session or per-branch handoff naming scheme, or some other session-scoping mechanism, before this stops being a silent cross-session clobber. Found via cross-session coordination with the 'Worktree-boundary guard hardening' peer session while scoping its PreCompact worktree-root fix -- that fix deliberately does NOT touch handoff.md resolution to avoid making the bypass MORE broadly shared (resolving to main root would extend the bypass to every worktree session too).
