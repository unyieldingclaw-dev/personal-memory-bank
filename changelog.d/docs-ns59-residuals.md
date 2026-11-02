### Fixed
- Both `HOOKS-GUIDE.md` copies said the `pre-approval-check` notification popup "closes itself after
  600 s". The scripts only set that timeout, and popups have been seen still open past it, so the
  guides now say it is set to close. `docs/HOOKS-GUIDE.md` also names a failed write to the trial
  log as a case that leaves no line. The Pre-Approval Protocol spec and plan carry matching
  corrections.
