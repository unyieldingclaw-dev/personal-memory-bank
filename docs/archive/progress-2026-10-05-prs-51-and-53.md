# progress.md section relocated 2026-10-23 (verbatim)

Moved verbatim from `memory-bank/progress.md` to fund the 2026-10-23 PR #81 entry under the startup-context
ratchet. A stub with the original heading remains there.

## 2026-10-05 — PRs #51 (`07e3bd2`) and #53 (`3cadb06`, [NS-19]) merged

- **#53:** `/change-review` approved it with conditions. The CHANGELOG `mb plan promote` entry
  blamed `awk`; the shipped bug was `sed -i`. Corrected here. Its parity and test gaps are listed
  in the PR #53 body.
- **A reviewer subagent ran `git commit` inside a script file**, which the PreToolUse gate cannot
  see. It targeted a scratch repo, and the reflog was clean.
  `docs/backlog/review-gate-is-bypassed-by-a-git-verb-held-in-a-va.md` already measured that case.
- **`mb verify-integrity` flagged all five files** against a PowerShell-written baseline, which
  holds uppercase hashes. That is [NS-36], live.
