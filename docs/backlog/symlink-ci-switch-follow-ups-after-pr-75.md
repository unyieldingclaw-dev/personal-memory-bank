---
status: open
created: 2026-10-30
last-reviewed: 2026-10-30
staleness-threshold: 90d
related_plan: null
---

# Symbolic-link CI switch: follow-ups after PR #75

PR #75 (`c10cd87`) set `PMB_REQUIRE_SYMLINKS: "1"` in `.github/workflows/pmb-health.yml`'s
"Run mb command tests" step, so `skip_links` in `tests/test-pmb-journal.sh` fails instead of
skipping when a link fixture cannot be made. Its review left three non-blocking items. They are
listed in the PR body, and PRs #80 and #91 both recorded them as "not recorded anywhere in the
memory bank". This file is that record. Line numbers below are from `2089b79`. Each item was
checked against that tree on 2026-10-30.

1. **The workflow's WHY comment leaves out the `show` link refusal.** The comment above the step
   (`pmb-health.yml:670-671`) lists "the writers' link refusals, a dangling-link start sentinel,
   the gate's link checks". `show` is a reader, not a writer, and its link refusal also goes
   through `skip_links` (`tests/test-pmb-journal.sh:593`). PR #75 added a CHANGELOG bullet that
   has the same gap, but 1.3.0 has since archived it in `docs/archive/changelog-1.3.0.md`, a
   released record that is not edited. Only the workflow comment is left to fix: name `show`, or
   mark the list as examples (PR #75's suggestion).
2. **No committed self-test shows that a switch turns a skip into a failure.** No test runs
   `skip_links` with `PMB_REQUIRE_SYMLINKS=1` and asserts that it fails. The same is true of
   `PMB_REQUIRE_FIFO` (`skip_fifo`) and of every `PMB_REQUIRE_PARITY` block in `tests/`. PR #75
   proved its switch once, by hand: with `ln -s` broken in Linux Docker, the switch added exactly
   18 failures. Nothing re-checks that if a later edit makes a helper fail open.
3. **The ps1 dangling-link sentinel case has no `skip_links` fallback.**
   `tests/test-pmb-journal.sh:2087` creates `sessSTLNK_02/started` with `ln -s` and does not check
   whether it worked. If the link cannot be made, the assertion at `:2090` still fails, so the
   case fails closed. Git Bash never reaches this case: `:2035-2037` skip the whole ps1 FIFO block
   there (MINGW/MSYS/CYGWIN). Any other host with `pwsh`, `mkfifo` and `timeout` does, as PR #75's
   Linux Docker run with `ln -s` broken did. The message, "sessSTLNK_02's start sentinel counts as
   started", does not say that the fixture is what is missing. Its sh twin (`:675`) does call
   `skip_links`.

None of these blocks the C1 flag PR (`[NS-68]`).
