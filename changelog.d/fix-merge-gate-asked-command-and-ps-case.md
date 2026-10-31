### Fixed
- **The merge gate asked about a merge that an allow rule could let through with no prompt.** Its
  settings check matched each allow rule against fixed merge spellings (PR 1, a zero SHA), so it
  missed a rule naming the merged PR or its SHA, such as `Bash(gh pr m* 12*)`. Both twins now
  also match every allow rule against the exact command being asked, under the same step budget,
  and deny on a match (`scripts/_review-gate-merge.py` / `.ps1` and their `templates/` copies).
- **PowerShell allow rules in another case slipped past the merge gate.** Claude Code matches
  PowerShell rules case-insensitively, but the gate compared them case-exactly, so a rule such as
  `PowerShell(GH PR M* 12*)` was not seen. Both twins now fold ASCII case for PowerShell rules
  only; Bash rules stay case-exact. The PowerShell twin is also faster on long rules: with 3,000
  long upper-case rules and one allowlisted repo, 1.3.0's took 16-34 s and this one under 3 s
  (measured, one run each, on a loaded machine).
- **The PowerShell twin prompted for a merge whose payload was a one-element JSON array,** where
  the Python twin denied it. It now reads the payload with `-NoEnumerate`, as it already read
  settings.
- Tests: `tests/test-merge-gate.sh`, `tests/merge-gate.Tests.ps1`, `tests/mutate-merge-gate.sh`.
