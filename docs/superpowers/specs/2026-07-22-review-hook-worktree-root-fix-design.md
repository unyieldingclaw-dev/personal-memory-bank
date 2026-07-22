# Review-Gate Hook Worktree Root-Resolution Fix

**Date:** 2026-07-22
**Status:** Approved

## Problem

`review-reminders.sh`/`.ps1` (the `PreToolUse` gate for `git commit`/`git push`) and their companion
`review-reminders-post.sh`/`.ps1` (the `PostToolUse` hook that reissues a marker after a failed gated
attempt) both resolve the repo root via:

```
root=$(git rev-parse --show-toplevel 2>/dev/null)
```

This is correct when the calling session's Bash tool cwd tracks the agent's own `cd` history — true
for top-level sessions, where the working directory genuinely persists across tool calls. It is wrong
for subagent-dispatched Bash sessions: empirically confirmed three separate times during the
2026-07-16 review-gate self-attestation fix (`docs/superpowers/specs/2026-07-16-review-gate-self-
attestation-fix-design.md`), a subagent's own Bash tool session did not persist `cd` across calls —
a bare `pwd` with no `cd` prefix kept returning the main repo root even after many prior
`cd "<worktree>" && ...` commands in the same subagent conversation. Every gated commit the subagent
attempted from inside a worktree was denied, even with a correct, matching review-ok marker present
in that worktree's own `.claude/` directory, because the hook resolved root to the main repo instead.

The workaround used throughout that session — the controller manually completing every blocked
commit from its own (correctly-rooted) session, after independently re-verifying the marker — worked,
but doesn't scale: every future multi-task plan executed via `subagent-driven-development` inside a
worktree will hit this same friction on every single commit, unless fixed at the source.

## Design

### Mechanism

Both hook pairs gain one new step, inserted immediately before the existing
`git rev-parse --show-toplevel` call: attempt to extract the actual gated command's text
(`tool_input.command`) from the hook's JSON stdin payload, and check whether it starts with
`cd "<path>" &&` (double- or single-quoted). If it does, resolve root via
`git -C "<path>" rev-parse --show-toplevel` instead of the ambient one, and use that as the effective
root for the rest of the script. This derives root from the specific command actually being gated —
self-contained, with no dependency on whatever cwd-persistence behavior the calling session has —
rather than trusting the hook process's own ambient state, which is exactly the assumption that broke
for subagents.

If no leading `cd` is found, the extracted path doesn't resolve to a git repo, or extraction itself
fails for any reason (missing dependency, malformed JSON) — fall through to exactly today's behavior
(ambient `git rev-parse --show-toplevel`). This is purely additive: top-level sessions, and any
command without a leading `cd`, are completely unaffected.

### Bash vs. PowerShell

- **PowerShell** already parses `tool_input.command` into a clean `$cmd` string via
  `ConvertFrom-Json` (used today for the `git commit`/`git push`/`gh pr merge` matching). The `cd`
  check is a regex against that already-extracted string — no new dependency.
- **Bash** currently never extracts `tool_input.command` as a value — it matches raw stdin text
  directly for presence (`case "$input" in *'git commit'*)`), a deliberate design choice (existing
  comment: presence-only matching doesn't need real parsing, and is robust to JSON-escaping edge
  cases that a fragile field-extraction regex could break on). Getting the `cd` path's actual *value*
  does need real parsing, so bash gains a new python3-based extraction step, used only for this new
  check — the existing raw-text matching for gate detection is untouched. This mirrors
  `check-repo-boundary.sh`'s existing precedent in this repo: python3 for extracting an actual field
  value, with the same fail-open-if-python3-missing convention already established there.

### Fallback / fail-open order

1. Compute `ambient_root` via the existing `git rev-parse --show-toplevel` call (unchanged).
2. Attempt to extract `tool_input.command`; look for a leading `cd "<path>" &&` / `cd '<path>' &&`.
3. If found, compute `cd_root` via `git -C "<path>" rev-parse --show-toplevel 2>/dev/null`.
4. If `cd_root` is non-empty, use it as `root` for the rest of the script. Otherwise use
   `ambient_root`.
5. Any failure in steps 2–3 (no python3, malformed JSON, no leading `cd`, extracted path isn't a git
   repo) falls back to `ambient_root` — the *new* logic fails open, not the whole hook.

### Scope

Both hook pairs: `scripts/review-reminders.sh`/`.ps1` (`PreToolUse` — the one that actually broke
during the 2026-07-16 work) and `scripts/review-reminders-post.sh`/`.ps1` (`PostToolUse` companion —
same `git rev-parse --show-toplevel` pattern, would hit the identical bug the first time it fires
inside a worktree, e.g. reissuing a marker after a gated push fails). Plus their byte-identical
`templates/scripts/` mirrors (TEMPLATE_OWNED sync, matching this repo's existing convention for these
files).

`check-repo-boundary.sh`/`.ps1` is explicitly out of scope. It already resolves root via
`$CLAUDE_PROJECT_DIR` instead of `git rev-parse --show-toplevel`, for a different reason: that hook's
entire purpose is staying pinned to the session's *original* project root regardless of where the
agent `cd`s, to prevent cross-repo writes — the opposite of what this fix wants. It is not the same
bug and does not need the same fix.

### Testing

Extend `tests/test-review-reminders.sh` with:

1. **The actual bug, reproduced**: a real second git worktree, a valid review-ok marker written into
   *that* worktree's `.claude/`, the hook invoked with `cd "<worktree>" && git commit ...` while the
   test process's own cwd is the main repo (mirroring exactly what the subagent hit) — assert the
   commit is now allowed.
2. **Negative control**: same setup, but a wrong/stale marker in the worktree — assert the hook still
   correctly denies.
3. **Non-regression**: a plain command with no leading `cd`, hook run from the correct directory —
   behavior unchanged from today.

Exact test structure (temp directory setup, worktree creation/cleanup) is an implementation-plan
detail, following this file's existing test-scaffolding patterns.

## Out of Scope

- `check-repo-boundary.sh`/`.ps1` — different hook, different intentional semantics (see above).
- Root-causing *why* subagent Bash sessions don't persist `cd` the way top-level sessions do — that's
  harness-level behavior outside this repo's control or visibility. This fix works regardless of the
  underlying cause, by deriving root from the gated command itself rather than depending on ambient
  session state.
- Any change to the marker-write/hash-verification logic itself — untouched; this fix only changes
  how `root` (the directory the marker is looked for in) gets computed.

## Files Changed

| File | Change |
|---|---|
| `scripts/review-reminders.sh` | New python3-based `cd`-prefix extraction + root override, fails open to current behavior |
| `scripts/review-reminders.ps1` | New regex-based `cd`-prefix extraction (from already-parsed `$cmd`) + root override |
| `scripts/review-reminders-post.sh` | Same fix as the `.sh` pair |
| `scripts/review-reminders-post.ps1` | Same fix as the `.ps1` pair |
| `templates/scripts/review-reminders.sh` / `.ps1` / `-post.sh` / `-post.ps1` | Byte-identical mirrors |
| `tests/test-review-reminders.sh` | New worktree-reproduction test, negative control, non-regression check |
