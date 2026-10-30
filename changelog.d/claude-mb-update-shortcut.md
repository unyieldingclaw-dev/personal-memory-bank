### Changed
- The AI chat shortcut for refreshing the Memory Bank is now "update memory bank" instead of
  `mb update`, which collided with the CLI's `mb update` (an upgrade alias in `mb.sh`, a redirect
  in `mb.ps1`). A user following `docs/SETUP-GUIDE.md` on `mb.sh` could run a real upgrade when
  they meant to ask the AI to update notes. Renamed in `standards/MEMORY-BANK.md`, the Cursor rule,
  `templates/memory-bank/README.md`, `docs/QUICK-REFERENCE.md`, `docs/SETUP-GUIDE.md` and the
  `init-memory-bank` scripts' closing tips; `templates/` copies updated to match.

### Fixed
- `docs/COMMANDS-REFERENCE.md` said `mb clean` absorbs `update`; `update` maps to `mb upgrade`.
