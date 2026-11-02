### Fixed
- **`--dry-run` on any command but `mb upgrade` was silently ignored, so the command ran for
  real.** `mb init --dry-run` performed a real init, and `mb backlog add t --dry-run` created the
  item. Both `mb.ps1` (either spelling, through `mb.bat` or the call operator, in any argument
  position) and `mb.sh` (any position) now refuse the flag with an error naming the command and
  exit 1 before anything runs. `mb.sh` still accepts it on `update`, its live upgrade alias; in
  `mb.ps1`, where `update` is only a redirect notice, `mb update --dry-run` is refused too.
  `tests/mb-dry-run-guard.Tests.ps1`, `tests/test-mb-upgrade.sh`.
