# Changelog

## [Unreleased]

### Fixed
- **`mb upgrade --dry-run` did not work on Windows.** Through the `mb.bat` launcher (`pwsh -File`)
  it threw "A parameter cannot be found that matches parameter name '-dry-run'"; only `-DryRun`
  worked. Called as `& mb.ps1 upgrade --dry-run`, it ran a REAL upgrade and wrote template files.
  `mb.ps1` now accepts both spellings in both forms. `tests/mb-upgrade-dry-run.Tests.ps1`.

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

## Released history

Versions **0.1.0 (2026-04-29) through 1.2.1 (2026-08-03)** live in
`docs/archive/changelog-0.1.0-to-1.2.1.md`. They were moved there on 2026-09-07 because this file
had reached 901 lines against the 800-line hard cap in `.github/workflows/pmb-health.yml`'s File
Size job — with only 8 lines of headroom before this change.

Version **1.3.0 (2026-10-25)** lives in `docs/archive/changelog-1.3.0.md`. It was archived in the
same change that cut it: its 755-line section left this file at exactly the 800-line cap.

New released sections belong **here**, not in that archive: directly below `## [Unreleased]`, which
is where renaming it at tag-cut leaves them. When this file approaches the cap again, move the oldest
sections to a **new** archive file named for the versions it holds (`changelog-<version>.md` or
`changelog-<first>-to-<last>.md`). A release whose own section would leave this file without
headroom moves there in the change that cuts it, as 1.3.0 did. Never append to an existing one:
`docs/archive/README.md` and `standards/MEMORY-BANK.md` both require one topic or period per file,
and `pmb-health.yml` exempts `docs/archive/` from its *byte* caps because archives do not grow.
Note the 800-line markdown cap still applies there — `docs/archive/*.md` is inside the File Size
job's scope — so appending would eventually red the build in the archive too, which is precisely the
failure this move exists to stop repeating. An earlier version of this pointer said the opposite,
and a later one claimed the archive directory was unwatched; neither was true.
