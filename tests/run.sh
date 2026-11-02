#!/usr/bin/env bash
# tests/run.sh — run every tracked tests/test-*.sh suite and report one combined result
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
# conflicted there (PR #81's merge-gate line and PR #78's, both added after review-reminders).
# Enumeration retires both. The file name is now the contract: a by-hand harness must not be
# named test-*.sh (see tests/mutate-merge-gate.sh), and a suite must not run this script, or it
# recurses (tests/test-run-sh.sh runs a temp COPY instead).
#
# WHY git ls-files rather than a glob: tests/ can hold untracked work-in-progress suites, and those
# must not run. Tracked is what reaches CI. A NOTE names
# them, because before enumeration a hand-added run_suite line ran a new suite before `git add`.
# ':(glob)' because a plain pathspec's * also matches /, so tests/test-x/y.sh would be listed; -z
# and a read loop keep a name with a space or a non-ASCII byte whole. No sort on this side: ls-files
# prints in index order, which git's index format defines as memcmp order, i.e. LC_ALL=C.
#
# WHY ls-files only when the repository's toplevel IS REPO_ROOT: in a copy extracted inside some
# other repository, ls-files would answer from that repository's index, which does not track this
# copy, so zero suites would run. The check is `-ef` (same device and inode), not a string compare:
# on Git Bash git prints C:/Users/... where pwd prints /c/Users/..., or /c/users/... when run.sh is
# reached through a differently-cased path, or /tmp/... through the mount; and git resolves symlinks
# where plain pwd does not. A string compare after `pwd -P` still missed the case and mount forms.
#
# WHY the glob fallback is acceptable: reviewers run the suite on a `git ls-files | tar` copy with no
# .git, which holds tracked files only. It is loud rather than silent, the same "a silent skip reads
# as a pass" reason as the other SKIP lines in this repo.
SUITES=()
toplevel=""
if command -v git >/dev/null 2>&1; then
  toplevel="$(git -C "$REPO_ROOT" rev-parse --show-toplevel 2>/dev/null)"
fi
if [ -n "$toplevel" ] && [ "$toplevel" -ef "$REPO_ROOT" ]; then
  while IFS= read -r -d '' f; do SUITES+=("$f"); done < <(git -C "$REPO_ROOT" ls-files -z ':(glob)tests/test-*.sh')
  untracked="$(git -C "$REPO_ROOT" ls-files --others --exclude-standard ':(glob)tests/test-*.sh')"
  if [ -n "$untracked" ]; then
    echo ""
    echo "NOTE: untracked suites are not run (git add one to include it):"
    printf '%s\n' "$untracked" | sed 's/^/  /'
  fi
else
  if [ -n "$toplevel" ]; then why="git's toplevel $toplevel is not $REPO_ROOT"; else why="no git checkout at $REPO_ROOT"; fi
  echo ""
  echo "SKIP: git ls-files enumeration ($why) -- running every tests/test-*.sh on disk instead, untracked ones included."
  while IFS= read -r -d '' f; do SUITES+=("$f"); done < <(cd "$REPO_ROOT" && for f in tests/test-*.sh; do [ -f "$f" ] && printf '%s\0' "$f"; done | LC_ALL=C sort -z)
fi

# WHY fail on an empty list: zero suites would otherwise end in "All test suites passed".
if [ "${#SUITES[@]}" -eq 0 ]; then
  echo ""
  echo "FAIL: no tests/test-*.sh suite found under $REPO_ROOT -- nothing ran."
  OVERALL_FAIL=1
fi

for f in "${SUITES[@]}"; do
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
