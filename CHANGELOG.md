# Changelog

**Changes merged since the last release are not in this file.** Each pull request adds a fragment
to [`changelog.d/`](changelog.d/), and `bash scripts/changelog-assemble.sh --preview` prints them.
A release folds them into a new section directly below `[Unreleased]`, which stays empty. The rule
is in `standards/WORKFLOW.md`, Phase 7.

## [Unreleased]

### Fixed
- **The PowerShell review gate allowed commits that the sh gate denied.** Its classifier compared
  command tokens by culture, which ignores U+00AD and equates look-alikes. So it allowed
  `echo x | xargs -I<U+00AD> git commit` and `git -c a.b=c<U+207D>x commit` (both ran, measured), and
  the gate never asked for a review. All its comparisons are now ordinal (`scripts/` and
  `templates/`). New `tests/test-review-gate-classify-parity.sh` checks that the two classifiers agree,
  that the hook denies both forms, and, by parsing the file, that no culture-aware comparison is left.
  The classifier is still not complete: `docs/backlog/review-gate-classifier-gaps-beyond-culture-compari.md`.

## Pending — NOT part of any release

The session-claims entries that stood here are now in
`docs/archive/changelog-2026-10-23-pending-session-claims.md`. They were moved on 2026-10-23
because this file had reached the File Size job's 800-line cap. They describe the branch
`worktree-concurrent-session-claims`, which will not merge, because `[NS-18]` was closed as
superseded on 2026-09-29. They are kept as history only.

## Released history

Versions **0.1.0 (2026-04-29) through 1.2.1 (2026-08-03)** live in
`docs/archive/changelog-0.1.0-to-1.2.1.md`. They were moved there on 2026-09-07 because this file
had reached 901 lines against the 800-line hard cap in `.github/workflows/pmb-health.yml`'s File
Size job — with only 8 lines of headroom before this change.

Version **1.3.0 (2026-10-25)** lives in `docs/archive/changelog-1.3.0.md`. It was archived in the
same change that cut it: its 755-line section left this file at exactly the 800-line cap.

New released sections belong **here**, not in that archive: directly below the empty
`## [Unreleased]`, which is where `scripts/changelog-assemble.sh` puts them. When this file
approaches the cap again, move the oldest sections to a **new** archive file named for the versions
it holds (`changelog-<version>.md` or `changelog-<first>-to-<last>.md`). A release whose own
section would leave this file without headroom moves there in the change that cuts it, as 1.3.0
did. Never append to an existing one: `docs/archive/README.md` and `standards/MEMORY-BANK.md` both
require one topic or period per file, and
`pmb-health.yml` exempts `docs/archive/` from its *byte* caps because archives do not grow.
Note the 800-line markdown cap still applies there — `docs/archive/*.md` is inside the File Size
job's scope — so appending would eventually red the build in the archive too, which is precisely the
failure this move exists to stop repeating. An earlier version of this pointer said the opposite,
and a later one claimed the archive directory was unwatched; neither was true.
