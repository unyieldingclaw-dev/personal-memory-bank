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
2026-07-16 review-gate self-attestation fix session (documented in `memory-bank/progress.md`'s
2026-07-16 entry, not that fix's own design spec, which explicitly scoped `review-reminders.sh`/
`.ps1` as untouched), a subagent's own Bash tool session did not persist `cd` across calls —
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
  `check-contract.sh`'s existing precedent in this repo (already cited in `review-reminders.sh`'s
  own sha256sum-fallback comment): python3 for extracting an actual field value, with the same
  fail-open-if-python3-missing convention already established there.

### Fallback / fail-open order

1. Compute `ambient_root` via the existing `git rev-parse --show-toplevel` call (unchanged).
2. Attempt to extract `tool_input.command`; look for a leading `cd "<path>" &&` / `cd '<path>' &&`.
3. If found, compute `cd_root` via `git -C "<path>" rev-parse --show-toplevel 2>/dev/null`.
4. If `cd_root` is non-empty, use it as `root` for the rest of the script. Otherwise use
   `ambient_root`.
5. Any failure in steps 2–3 (no python3, malformed JSON, no leading `cd`, extracted path isn't a git
   repo) falls back to `ambient_root` — the *new* logic fails open, not the whole hook.

### Propagating `root` to every subsequent git call (correction, added after implementation review)

Resolving `root` correctly is necessary but not sufficient: everything downstream of that point —
`diff_hash()`'s `git diff` call, and every bare `git rev-parse HEAD` / `git rev-parse '@{u}'` used to
record pre-commit/pre-push SHAs for the `PostToolUse` companion — was still relying on the hook
process's own ambient cwd, the exact same assumption being fixed for the marker-lookup path. Found
during Task 1's implementation (its own mandated manual verification step caught the gap directly:
root resolved correctly, the marker was found, but the *hash comparison* still mismatched because
`diff_hash` computed against the wrong repo). This was a real gap in the original version of this
spec, which incorrectly scoped hash-verification logic as untouched — see the corrected Out of Scope
section below.

**Fix:** immediately after `root` is resolved (by either path above), `cd "$root"` (bash) /
`Set-Location $root` (PowerShell) once, before any of the existing commit/push logic runs. Every
subsequent bare `git diff`/`git rev-parse` call in the script — `diff_hash()`, the pre-commit/pre-push
SHA capture, and their `review-reminders-post` companions — becomes correct by construction, not by
each call site individually remembering to pass `-C "$root"`. This was chosen over patching each of
the ~10 individual call sites across the 4 files with an explicit `-C "$root"`: fewer places to get
wrong, and any git call added to these files in the future is correct by default rather than silently
reintroducing this bug. Fails open the same way as root-resolution itself: if `cd`/`Set-Location`
fails (e.g. `root` no longer exists), exit 0 rather than proceeding with a mismatched cwd.

### Scope

Both hook pairs: `scripts/review-reminders.sh`/`.ps1` (`PreToolUse` — the one that actually broke
during the 2026-07-16 work) and `scripts/review-reminders-post.sh`/`.ps1` (`PostToolUse` companion —
same `git rev-parse --show-toplevel` pattern, would hit the identical bug the first time it fires
inside a worktree, e.g. reissuing a marker after a gated push fails). Plus their byte-identical
`templates/scripts/` mirrors (TEMPLATE_OWNED sync, matching this repo's existing convention for these
files).

`check-repo-boundary.sh`/`.ps1` is explicitly out of scope. As of this writing it exists only on the
separate, unmerged `worktree-cross-repo-write-boundary` branch, not on this one — but even once merged,
it resolves root via `$CLAUDE_PROJECT_DIR` instead of `git rev-parse --show-toplevel`, for a different
reason: that hook's entire purpose is staying pinned to the session's *original* project root
regardless of where the agent `cd`s, to prevent cross-repo writes — the opposite of what this fix
wants. It is not the same bug and does not need the same fix.

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

**A real constraint on how verification must be performed, found during implementation:** any test
of the commit/push gate necessarily needs the literal text "git commit" or "git push" to exist
*somewhere*, to simulate the command being gated. If that text appears directly in a live Bash tool
call (rather than inside a file), it triggers this repo's own governing `PreToolUse` hook on the
*testing* agent's own tool call, before the test under construction ever runs — the test collides
with the exact mechanism it's exercising. `tests/test-review-reminders.sh` already solves this
correctly: the trigger text lives inside the test script file (written via a file-writing tool), and
the Bash call that *executes* the file doesn't contain the trigger text in its own command string.
Any manual verification during implementation must use this same pattern — write the test scenario to
a script file first, then run that file via a clean Bash call. Splitting, concatenating, or otherwise
obfuscating the trigger text specifically to prevent the governing hook from recognizing a live Bash
command is not an acceptable workaround, regardless of how benign the underlying test is: it defeats
the detection mechanism itself rather than avoiding an unnecessary collision with it, and this
distinction matters more than usual in a file whose entire purpose is closing gaps in that same
detection layer.

## Out of Scope

- `check-repo-boundary.sh`/`.ps1` — different hook, different intentional semantics (see above); also
  not present on this branch as of this writing (see Scope).
- Root-causing *why* subagent Bash sessions don't persist `cd` the way top-level sessions do — that's
  harness-level behavior outside this repo's control or visibility. This fix works regardless of the
  underlying cause, by deriving root from the gated command itself rather than depending on ambient
  session state.
- *What* the hash-verification logic computes (the algorithm, the diff commands used, the marker
  schema) — unchanged. *Where* it computes it now consistently follows the resolved `root` (see
  "Propagating `root`" above) rather than ambient cwd — this is a correction to the original version
  of this scope statement, which incorrectly claimed no hash-verification code would be touched.

## Files Changed

| File | Change |
|---|---|
| `scripts/review-reminders.sh` | New python3-based `cd`-prefix extraction + root override, fails open to current behavior; `cd "$root"` once root is resolved so `diff_hash()` and the pre-commit/pre-push SHA capture are anchored to it too |
| `scripts/review-reminders.ps1` | New regex-based `cd`-prefix extraction (from already-parsed `$cmd`) + root override; `Set-Location $root` for the same reason |
| `scripts/review-reminders-post.sh` | Same fix as the `.sh` pair |
| `scripts/review-reminders-post.ps1` | Same fix as the `.ps1` pair |
| `templates/scripts/review-reminders.sh` / `.ps1` / `-post.sh` / `-post.ps1` | Byte-identical mirrors |
| `tests/test-review-reminders.sh` | New worktree-reproduction test, negative control, non-regression check |
