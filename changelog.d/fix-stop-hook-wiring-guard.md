### Fixed
- **PMB's own Stop hook (`pre-approval-check`) gets the `[ -f ]` guard the other hooks got in
  PR #118.** With `pwsh` installed and the `.ps1` missing, `pwsh` printed its usage text ahead of the
  `.sh` twin's block JSON, so the block was ignored. `tests/test-pre-approval-check.sh` now runs the
  chain with the `.ps1` removed. `tests/test-hook-wiring.sh` now matches `BLOCK: ` case-sensitively
  and seeds the delegation-depth file with a far-future time, so it passes in any time zone.
