---
status: open
created: 2026-09-21
last-reviewed: 2026-10-19
staleness-threshold: 90d
related_plan: null
---

# handoff.md is a single unscoped file shared across concurrent sessions in the same directory

**Status 2026-10-18: addressed by design, not yet live.** The C1 multi-session journal (PR #57,
`d751b73`) gives each session its own records keyed by `CLAUDE_CODE_SESSION_ID`, and its journal-mode
gate does not read `handoff.md`. Journal mode stays off until Plan C's `.pmb-features` flag PR
(`[NS-68]`). Until then the legacy gate's bypass below still applies. Re-review this item when that
flag PR merges: the journal is this repository only (spec M6,
`docs/superpowers/specs/2026-09-26-multi-session-memory-design.md`), so the bypass stays live in adopters.

pre-compact-check.sh's handoff-bypass (its `if [ -f "handoff.md" ]` block, lines 64-83 at `7a43f78`) accepts ANY handoff.md dated today regardless of author or content, and handoff.md itself has no session-scoping -- confirmed live 2026-09-21 when the 'PMB full review and PR #12 disposition' session's handoff.md (14:43 today) silently overwrote this session's own earlier handoff.md, and would bypass pre-compact-check for any other session sharing this directory today regardless of relevance. Same session-identity gap as the compact-nudge-hook spec's per-session state-file problem and the concurrent-session-claims branch's claim-identity bug (uses branch name). Needs a per-session or per-branch handoff naming scheme, or some other session-scoping mechanism, before this stops being a silent cross-session clobber. Found via cross-session coordination with the 'Worktree-boundary guard hardening' peer session while scoping its PreCompact worktree-root fix -- that fix deliberately does NOT touch handoff.md resolution to avoid making the bypass MORE broadly shared (resolving to main root would extend the bypass to every worktree session too).
