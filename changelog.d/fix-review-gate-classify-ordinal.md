### Fixed
- **The PowerShell review gate allowed commits that the sh gate denied.** Its classifier compared
  command tokens by culture, which ignores U+00AD and equates look-alikes. So it allowed
  `echo x | xargs -I<U+00AD> git commit` and `git -c a.b=c<U+207D>x commit` (both ran, measured), and
  the gate never asked for a review. Its string and character comparisons are now ordinal (`scripts/`
  and `templates/`); the `-match` regexes stay, since they only add matches. New
  `tests/test-review-gate-classify-parity.sh` checks that the two classifiers agree, that the hook
  denies both forms, and, by parsing the file, that none of the culture-aware forms it lists is left.
  That parse is a list, not a proof: it trusts the scanner's int variables by name and does not see
  a comparer passed to a .NET API. The classifier is still not complete:
  `docs/backlog/review-gate-classifier-gaps-beyond-culture-compari.md`.
