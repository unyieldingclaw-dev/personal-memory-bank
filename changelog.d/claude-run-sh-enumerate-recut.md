### Changed

- `tests/run.sh` now runs every tracked `tests/test-*.sh` (from `git ls-files`, sorted), not a
  hand-kept `run_suite` list, and the completeness check that guarded that list is gone. Each
  suite's display name comes from its file name. Outside a git checkout rooted at the repository, it
  prints a loud `SKIP:` line and globs the suites on disk. It fails when no suite is found, so an
  empty run can no longer print "All test suites passed". **Why:** every new suite appended a line
  at the same spot, so concurrent PRs conflicted there and each of those syncs needed a full review.
  `tests/test-run-sh.sh` covers the guards. Re-cut of PR #94 onto current `main`.
