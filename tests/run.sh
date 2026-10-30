#!/usr/bin/env bash
# tests/run.sh — run all mb command tests
# Usage: bash tests/run.sh
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

OVERALL_FAIL=0

run_suite() {
  local name="$1" script="$2"
  echo ""
  echo "════════════════════════════════════"
  echo "Suite: $name"
  echo "════════════════════════════════════"

  if ! bash "$script"; then
    OVERALL_FAIL=1
  fi
}

# ── enumerate: every tracked tests/test-*.sh is a suite ─────────────────────────────────────
# WHY enumerate rather than keep a list: the hand-kept run_suite list was the THIRD instance of the
# stale-hardcoded-list bug in this repo (after the slash-command list in 1.2.0 and the agent list in
# ADVISORY_DIFF). A suite missing from it reported nothing, so the runner printed "All test suites
# passed" while skipping it (found 2026-08-27), and a completeness check had to guard the list. The
# list was also one insertion point every new suite appended to: two PRs that each added a suite
# conflicted there (PR #78's f1cbabd sync). Enumeration retires both. The file name is now the
# contract: a by-hand harness must not be named test-*.sh (see tests/mutate-merge-gate.sh), and a
# suite must not run this script, or it recurses (tests/test-run-sh.sh runs a temp COPY instead).
#
# WHY git ls-files rather than a glob: tests/ also holds untracked work-in-progress suites (e.g. a
# withdrawn hook-wiring test), and those must not run. Tracked is what reaches CI.
#
# WHY ls-files only when the repository's toplevel IS REPO_ROOT: in a copy extracted inside some
# other repository, ls-files would answer from that repository's index, which does not track this
# copy, so zero suites would run. Both sides are compared after `cd && pwd -P`, because on Git Bash
# git prints C:/... where pwd prints /c/..., and git resolves symlinks where plain pwd does not.
#
# WHY the glob fallback is acceptable: reviewers run the suite on a `git ls-files | tar` copy with no
# .git, which holds tracked files only. It is loud rather than silent, the same "a silent skip reads
# as a pass" reason as every other SKIP line in this repo.
SUITES=""
toplevel=""
if command -v git >/dev/null 2>&1; then
  toplevel="$(git -C "$REPO_ROOT" rev-parse --show-toplevel 2>/dev/null)"
fi
if [ -n "$toplevel" ] && [ "$(cd "$toplevel" 2>/dev/null && pwd -P)" = "$(cd "$REPO_ROOT" && pwd -P)" ]; then
  SUITES="$(git -C "$REPO_ROOT" ls-files 'tests/test-*.sh' | LC_ALL=C sort)"
else
  echo ""
  echo "SKIP: git ls-files enumeration (no git checkout rooted at $REPO_ROOT) -- running every tests/test-*.sh on disk instead, untracked ones included."
  SUITES="$(cd "$REPO_ROOT" && for f in tests/test-*.sh; do [ -f "$f" ] && echo "$f"; done | LC_ALL=C sort)"
fi

# WHY fail on an empty list: zero suites would otherwise end in "All test suites passed".
if [ -z "$SUITES" ]; then
  echo ""
  echo "FAIL: no tests/test-*.sh suite found under $REPO_ROOT -- nothing ran."
  OVERALL_FAIL=1
fi

for f in $SUITES; do
  name="$(basename "$f" .sh)"
  run_suite "${name#test-}" "$REPO_ROOT/$f"
done

echo ""
echo "════════════════════════════════════"
if [ "$OVERALL_FAIL" -eq 0 ]; then
  echo "All test suites passed."
else
  echo "One or more test suites had failures."
fi
echo "════════════════════════════════════"

exit "$OVERALL_FAIL"
