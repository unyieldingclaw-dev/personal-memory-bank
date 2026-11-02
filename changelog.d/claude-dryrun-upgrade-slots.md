### Fixed
- **`mb upgrade x --dry-run` ran a real upgrade in `mb.sh`, and in `mb.ps1` under the call
  operator.** `upgrade` (and `mb.sh`'s `update` alias) read `--dry-run` only as the first argument
  after the command, so a preview requested after any other argument wrote template files. The
  installed Windows `mb` (`pwsh -File`, via `mb.bat`) was not affected, since its switch binds in
  any position. Both scripts now honour the flag in any position, matching the guard that refuses
  it on other commands. `tests/mb-upgrade-dry-run.Tests.ps1`, `tests/test-mb-upgrade.sh`.
- `docs/COMMANDS-REFERENCE.md` and `README.md` said `mb update` aliases `mb upgrade`; that holds
  for `mb.sh` only, since `mb.ps1`'s `update` just points at `mb upgrade`.
