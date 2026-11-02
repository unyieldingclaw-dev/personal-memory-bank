### Fixed
- **`update-reviewed` left CRLF memory-bank files with one LF-only line.** Both twins stamped
  `last-reviewed:` with a regex whose `.*` also consumed the line's `\r`. They now match
  `[^\r\n]*` with no trailing `$` (a `$` there cannot match before the `\r`, so CRLF files would
  not be stamped at all). `scripts/update-reviewed.sh` / `.ps1` and their `templates/` copies.
- **`update-reviewed.sh` failed silently.** Empty stdin, a non-zero perl exit, and a file that is
  missing after the edit are now appended to `.pmb-hook-errors.log`, which `update-reviewed.ps1`
  already writes and `mb doctor` check 16 reports. The hook still exits 0 and never blocks. A loss
  like PR #59's (seen on Side-Quest-Atlas's Windows CI, not reproduced on a single-drive machine)
  is logged either way: as a perl failure if perl exits non-zero, or by the missing-file check if
  it exits 0.
- **A path starting with `-` was read as an option** by the hook's `grep` and `perl`; both now get
  `--`.
- Tests: `tests/test-update-reviewed.sh` (CRLF in both twins, `-` path, the three logged failures,
  and a Linux/macOS-only pin of the literal-backslash filename trade-off); each new assertion was
  checked by reverting its fix.
