### Added
- **PMB-only trial: the Pre-Approval Protocol and its `pre-approval-check` Stop hook.** PMB's own
  `standards/WORKFLOW.md` gains a Pre-Approval Protocol section that supersedes Phase 3.5. Before any
  approve-or-choose ask: run the checks the options depend on, add an `opposition` pass on
  CLAUDE.md's escalation triggers, and send the ask with Findings and a Recommendation. A Stop hook
  (`scripts/pre-approval-check.{sh,ps1}`) sends back a turn that ends in an ask without them. It also
  now owns the "Claude has paused" notification, which is detached and, on Windows, is set to close
  itself after 600 s.
  - **Adopters:** nothing is installed. `mb init` still installs the modal popup, and both
    `HOOKS-GUIDE.md` copies say so.
  - **Tests:** new `tests/test-pre-approval-check.sh`. `tests/test-mirror-parity.sh` gains a dated
    exemption for the PMB-only Stop line. It also pins `WORKFLOW.md`'s live/template difference to
    named regions, replacing the line-based pin.
