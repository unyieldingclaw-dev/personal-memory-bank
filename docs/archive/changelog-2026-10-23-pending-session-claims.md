# CHANGELOG archive: the pending session-claims section (moved 2026-10-23)

This section was moved out of `CHANGELOG.md` on 2026-10-23, word for word.

**Why it moved:**
- `CHANGELOG.md` sat at exactly 800 lines on `main`, at the 800-line cap in
  `.github/workflows/pmb-health.yml`'s File Size job.
- Every line of it above this section was `[Unreleased]`, so the usual remedy did not apply: that
  remedy, set out in `CHANGELOG.md`'s "Released history" pointer, is to move the oldest *released*
  sections to a new dated archive file.
- This section was the one block that is not release notes for this repository.

**This is not released history, and it will not ship.** It describes the branch
`worktree-concurrent-session-claims`.
- `[NS-18]`, the port of that branch, was closed as superseded on 2026-09-29 (see
  `docs/backlog/redesign-session-claims-before-porting-ns-18.md`).
- So the section's own instruction below, to move these items into a release section when that
  branch merges, will not apply. The section is kept as history only.
- Do not append to this file. `docs/archive/README.md` says never append to an archive file.

## Pending — NOT part of any release

**This section is not release notes and must not be renamed at tag-cut.** It was previously a
`### Added` block inside `[Unreleased]`, carrying a note that its contents were unshipped. The note
was correct but structurally unsafe: renaming `## [Unreleased]` to a version number — the one
mechanical step of cutting a release — would have swept four features that do not exist in this
repository into the release notes for a tag that does not contain them. Moved to its own
`##`-level section on 2026-09-02 so that rename cannot reach it.

Everything below is implemented and committed on the not-yet-merged branch
`worktree-concurrent-session-claims`, not on this branch or tag — see `[NS-18]` in
`memory-bank/activeContext.md`. Move these items into a release section only when that branch
actually merges.

### Pending — session-claims (branch `worktree-concurrent-session-claims`)
- `scripts/session-claims.sh`/`.ps1`: coordinate multiple Claude Code sessions working the same
  repo at once via a gitignored, self-pruning `.claude/session-claims.json` registry —
  `prune`/`list`/`claim`/`release`/`force-clear`/`notify`, `mkdir`-based lock with 30s staleness
  theft, atomic writes. Mirrored into `templates/scripts/`.
- New `SessionStart` hook (`notify`) auto-surfaces live claims at session start; silent when
  there's nothing to report.
- Two new `mb doctor` checks: malformed `session-claims.json`, stuck `session-claims.lock`
  directory.
- `docs/SESSION-CLAIMS-GUIDE.md`; `[NS-N]` stable-id convention for `activeContext.md`'s Next
  Steps list, documented in `standards/MEMORY-BANK.md` and wired into `CLAUDE.md`'s
  session-start/handoff protocol.
