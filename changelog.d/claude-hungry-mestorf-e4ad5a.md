### Fixed
- **`mb upgrade --dry-run` did not work on Windows.** Through the `mb.bat` launcher (`pwsh -File`)
  it threw "A parameter cannot be found that matches parameter name '-dry-run'"; only `-DryRun`
  worked. Called as `& mb.ps1 upgrade --dry-run`, it ran a REAL upgrade and wrote template files.
  `mb.ps1` now accepts both spellings in both forms. `tests/mb-upgrade-dry-run.Tests.ps1`.
