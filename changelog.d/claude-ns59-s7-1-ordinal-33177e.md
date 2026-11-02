### Fixed
- **The PowerShell Pre-Approval Protocol hook treated a "?" followed by an invisible character as a
  question; the sh hook did not.** Its Tier B check (`EndsWith('?')`) and its `PMB_PRE_APPROVAL=off`
  test (`-ceq`) were culture-aware, which ignores zero-width, soft-hyphen and some control characters
  (measured: U+200B, U+200C, U+200E, U+00AD, U+200D, U+FEFF, U+2060). Both are now ordinal
  (`scripts/pre-approval-check.ps1`), so the `.ps1` also no longer blocks a message that ends "?" plus
  one of those characters, and `off` plus U+200B no longer disables it. New cases in
  `tests/test-pre-approval-check.sh` run in both shells. The twins still differ elsewhere, for example:
  they trim different whitespace sets, so "?" plus U+001C to U+001F is a question in the `.sh` and now
  not in the `.ps1`; and they count the 400-character window and fold case differently (the last two
  are listed in spec section 5, Twin parity).
- The two comments that stated the Windows popup's 600 s close as fact now say it is set to 600 s
  and has not been timed (spec section 3).
