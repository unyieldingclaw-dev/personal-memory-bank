### Removed
- Uncalled `show_update`, `show_archive`, `show_slim` and `show_compact` in `mb.sh`, and their
  `Show-*` twins in `mb.ps1`. They printed guidance for commands that are now redirects (exit 2)
  and nothing dispatched to them.

### Fixed
- `mb.sh`'s header and `mb.ps1`'s `.PARAMETER Command` help listed retired commands as current
  (`update` as a "reminder", `audit`, `compact`, `archive`, `slim`); both now point at `mb help`.
- `standards/MEMORY-BANK.md` (and its template) listed `mb clean` twice; merged into one row.
- The init scripts' closing "Quick commands" tips line up again.

### Added
- Tests: `upgrade x --dry-run` / `-DryRun` through `pwsh -File`; a positive control that a plain
  `upgrade` (and `upgrade x`, `update x` in `mb.sh`) still writes; a check that no chat-shortcut
  doc reintroduces `mb update`. `tests/mb-upgrade-dry-run.Tests.ps1`, `tests/test-mb-upgrade.sh`.
