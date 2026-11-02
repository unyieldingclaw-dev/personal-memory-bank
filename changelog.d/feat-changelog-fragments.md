### Changed
- Changelog entries now go in per-PR fragments, `changelog.d/<branch-slug>.md`, instead of
  `CHANGELOG.md`'s `[Unreleased]` section, so concurrent PRs no longer conflict there. The rule is
  in `standards/WORKFLOW.md`, Phase 7.

### Added
- `scripts/changelog-assemble.sh`: `--preview` prints the unreleased notes; `<X.Y.Z>` folds the
  fragments into a new `CHANGELOG.md` section and deletes them. Bash only, not shipped to adopters.
  Tested by `tests/test-changelog-fragments.sh`, which also checks every committed fragment.
