#!/usr/bin/env bash
# tests/test-threshold-parity.sh — memory-bank line caps must agree across all three enforcers
#
# WHY: on 2026-08-27 an audit found THREE divergences between CI and the two runtime checkers,
# running in BOTH directions. progress.md was stricter at runtime (400) than in CI (600), so
# `mb doctor` WARNed about a file the shipped docs certified compliant. Worse and unrecorded:
# projectbrief.md (150 vs 120) and techContext.md (400 vs 300) were LOOSER at runtime than in CI,
# so a clean `mb doctor` could be followed directly by a red build. Only the progress.md case had
# ever been written down. Aligning the numbers by hand fixes today; this test is what stops the
# drift recurring, since nothing else compares the three sources.
set -u

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$REPO_ROOT/tests/helpers/assert.sh"

echo "=== threshold parity tests ==="

CI_YML="$REPO_ROOT/.github/workflows/pmb-health.yml"
MB_SH="$REPO_ROOT/scripts/mb.sh"
MB_PS1="$REPO_ROOT/scripts/mb.ps1"

# CI is the source of truth: the MB_FAIL associative array.
CI_LINE=$(grep -m1 'declare -A MB_FAIL=(' "$CI_YML")

FILES="projectbrief.md systemPatterns.md techContext.md activeContext.md progress.md"

for f in $FILES; do
    ci=$(printf '%s' "$CI_LINE"  | sed -n "s/.*\[$f\]=\([0-9]*\).*/\1/p")
    sh=$(grep -o "check_size \"memory-bank/$f\" *[0-9]*" "$MB_SH" | grep -o '[0-9]*$')
    ps=$(grep -o "Name=\"$f\"; Max=[0-9]*" "$MB_PS1" | grep -o '[0-9]*$')

    echo ""
    echo "--- $f: CI=$ci mb.sh=$sh mb.ps1=$ps ---"
    assert_contains "ci=$ci" "ci=[0-9]"          "CI declares a cap for $f"
    assert_contains "sh=$sh" "sh=$ci"            "mb.sh cap for $f matches CI ($ci)"
    assert_contains "ps=$ps" "ps=$ci"            "mb.ps1 cap for $f matches CI ($ci)"
done



# ── the reverted-per-call-fold measurement must agree wherever it is stated ─────────────────
# WHY: the "before -> after" figure for the reverted per-call fold is restated verbatim in seven
# in-repo locations (two code comments, two HOOKS-GUIDE copies, the Work-MB brief, a progress.md
# entry, and a test comment) with no single source. This repo's own round-9 history records that
# exact failure already happening once: a falsified performance figure survived in two files after
# being corrected everywhere else. Nothing compared them, so nothing caught it. This does.
echo ""
echo "--- perf figure parity across all stating locations ---"

FIGURE_FILES="
docs/HOOKS-GUIDE.md
memory-bank/progress.md
docs/WORK-MB-PARADIGM-DELTA-BRIEF.md
scripts/dangerous-commands.sh
templates/docs/HOOKS-GUIDE.md
templates/scripts/dangerous-commands.sh
tests/test-dangerous-commands.sh
"

CANON=""
CANON_SRC=""
for f in $FIGURE_FILES; do
    # Extract the figure GENERICALLY -- never hard-code the digits. A pattern containing the
    # expected numbers cannot detect drift: a drifted file matches nothing, yields an empty
    # string, and (if it is the first file scanned) makes every later comparison compare against
    # empty. That exact bug was written here first and caught by mutation on 2026-08-27.
    pair=$(grep -hoE '[0-9]+\.[0-9]+s? *(->|→) *[0-9]+\.[0-9]+s?' "$REPO_ROOT/$f" 2>/dev/null            | head -1 | sed 's/→/->/' | tr -d ' s')
    if [ -z "$pair" ]; then
        echo "    $f: <no figure found>"
        assert_contains "STATE_ABSENT" "STATE_PRESENT" "$f states the shared perf figure"
        continue
    fi
    if [ -z "$CANON" ]; then CANON="$pair"; CANON_SRC="$f"; fi
    # Compare by exact equality. assert_contains is a SUBSTRING match (grep -qi), so comparing
    # raw values would let "1.07->2.3" pass against "1.07->2.33". The verdict words are chosen so
    # neither contains the other -- "MISMATCH" contains "MATCH", which would be the same trap.
    if [ "$pair" = "$CANON" ]; then verdict=SAME; else verdict=DIFFERENT; fi
    echo "    $f: $pair"
    assert_contains "$verdict" "SAME" "$f figure ($pair) agrees with $CANON_SRC ($CANON)"
done

print_summary
