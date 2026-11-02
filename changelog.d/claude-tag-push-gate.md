### Changed
- **Pushing a tag of an already-merged commit no longer needs a `/change-review` marker.** The push
  gate bound every push to `git diff origin/main...HEAD`, which says nothing about what a tag push
  publishes. A release tag needed a fresh review of whatever branch was checked out, and could not
  pass at all from main, where that diff is empty.
- The command must be exactly `cd "<absolute path>" && git push <remote> refs/tags/<t>` (or
  `tag <t>`), and every tag must be a real, non-symbolic `refs/tags/<t>` on a commit in
  `refs/remotes/origin/main`. A tag-shaped push that fails that check is denied with a reason that
  names the tag.
- The cd is required: exactly one, to an absolute path, `C:/…` or `/…`. On Windows the PowerShell
  twin refuses `/…`, and off Windows the sh twin refuses `C:/…`. The path is limited to printable
  ASCII and may not contain its own quote, `$`, a backtick, `\`, `[`, `]`, `*` or `?`. These rules
  close the ways found so far for the gate and the shell to resolve different repositories.
- The route is refused while any `remote.<name>.push` is configured, since git can map a tag
  refspec onto a branch through it. The ancestry check ignores `git replace` grafts.
- Every other push form still needs the marker: bare tag names, a tag push without the cd,
  `--tags`, `--follow-tags`, force, delete, and other chained commands.
- The push denials now name the accepted tag spelling.
- Changed in `scripts/review-reminders.sh`/`.ps1` and `_review-gate-classify.py`/`.ps1`, mirrored
  into `templates/scripts/`. The PowerShell twin now enters the resolved repository root with
  `-LiteralPath`.
- Tests: `tests/test-review-gate-tag-push.sh`.
