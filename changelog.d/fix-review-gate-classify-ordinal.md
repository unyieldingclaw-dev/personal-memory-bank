### Fixed
- **The PowerShell review gate allowed commits that the sh gate denied.** Its classifier compared
  command tokens by culture, which ignores U+00AD and equates look-alikes. So it allowed
  `echo x | xargs -I<U+00AD> git commit` and `git -c a.b=c<U+207D>x commit` (both ran, measured), and
  the gate never asked for a review. All its comparisons are now ordinal (`scripts/` and
  `templates/`). New `tests/test-review-gate-classify-parity.sh` checks that the two classifiers agree,
  that the hook denies both forms, and, by parsing the file, that no culture-aware comparison is left.
  The classifier is still not complete: `docs/backlog/review-gate-classifier-gaps-beyond-culture-compari.md`.
