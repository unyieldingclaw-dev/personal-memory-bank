# changelog.d/

Release notes for changes merged since the last release, one file per pull request.

- **Read them:** `bash scripts/changelog-assemble.sh --preview` prints them merged, as the next
  release section will read.
- **Write one:** see `standards/WORKFLOW.md`, Phase 7. The file is `<branch-slug>.md` and holds
  `### Added` / `### Changed` / `### Fixed` (and similar) headings with bullets. No line may start
  with `#` or `##` followed by a space or nothing, even inside a code fence: the script does not
  parse fences.
- **Release:** `bash scripts/changelog-assemble.sh <X.Y.Z>` folds them into `CHANGELOG.md` and
  deletes them. This file stays.
