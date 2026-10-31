### Changed

- `tests/run.sh` trusts `git ls-files` when git's toplevel is the same directory as the repository
  root (`-ef`), not when the two paths are equal strings. **Why:** on Git Bash a differently-cased
  path or the `/tmp` mount form of `%TEMP%` failed the string compare, so the run fell back to
  globbing and ran untracked suites. It now also prints a `NOTE:` naming untracked
  `tests/test-*.sh` files, which it does not run, and reads names with `':(glob)'` and `-z`, so a
  space or a non-ASCII byte in a name stays whole. `tests/test-run-sh.sh` adds cases for a
  symlinked path, a differently-cased path, locale order, git missing from `PATH`, a deleted
  tracked suite and awkward names. Follow-ups from the reviews of PR #94 (landed as PR #106).
