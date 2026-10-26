### Fixed
- `scripts/changelog-assemble.sh`: when fragments cannot be deleted after a cut, the message now
  says not to re-run *for another version* (the same version is already refused).
- `tests/test-mirror-parity.sh`: the WORKFLOW.md blank-line pin now says what it checks, the count
  of blank-line differences, not where they are.
- `changelog.d/README.md`: a tab after `#`/`##` is refused too, and so are nameless and empty
  `###` headings.

### Added
- `tests/test-changelog-fragments.sh` now covers the failed-delete path (with an `rm` shim), pins
  every fragment error to one line, merges a heading with a trailing space, and says how to run its
  line-ending cases on Windows (they only bite on an awk that keeps `\r`).
