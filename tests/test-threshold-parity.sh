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
    # WHY the verdict-word indirection rather than assert_contains "sh=$sh" "sh=$ci":
    # assert_contains is an unanchored grep, so "sh=1200" CONTAINS "sh=120": feeding ci=120 and
    # sh=1200 to the old form printed PASS. Reproduced on synthetic input, not observed live --
    # the real caps agree today, so the defect was latent. SAME/DIFFERENT are non-overlapping
    # words, so the substring match cannot false-pass -- the same fix this file already applies
    # to the perf figure and the handoff threshold below.
    # LIMIT: an empty $sh or $ps against a NON-EMPTY $ci yields DIFFERENT and fails loudly, but
    # if $ci is also empty the pair compares SAME. These three assertions are not independent --
    # the "CI declares a cap" one below is what catches a double extraction failure.
    if [ "$sh" = "$ci" ]; then v_sh=SAME; else v_sh=DIFFERENT; fi
    if [ "$ps" = "$ci" ]; then v_ps=SAME; else v_ps=DIFFERENT; fi
    assert_contains "ci=$ci" "ci=[0-9]"          "CI declares a cap for $f"
    assert_contains "$v_sh" "SAME"               "mb.sh cap for $f matches CI ($ci, got $sh)"
    assert_contains "$v_ps" "SAME"               "mb.ps1 cap for $f matches CI ($ci, got $ps)"
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

# ── the handoff threshold must be the same number everywhere it is PRESCRIBED ───────────────
# WHY this block exists: on 2026-08-28 the Cursor handoff threshold moved 80% -> 40% across
# standards/MEMORY-BANK.md, its templates/ mirror, and both .cursor/rules/memory-bank.mdc copies --
# and the sweep MISSED templates/AGENTS.md (three occurrences) and templates/memory-bank/README.md.
# Both are written into every new project by `mb init`, so the stale figure kept shipping to adopters
# through a path nobody checked. It was found by a reviewer grepping the whole repo, which is not a
# mechanism. Nothing compared these surfaces to each other, exactly as the line-cap block above was
# written because nothing compared CI to the two runtimes.
#
# WHY match only PRESCRIPTIVE spellings and not every "NN%": the same files legitimately discuss the
# OLD value in prose ("This was 80% until 2026-08-28", "why Cursor's was 80%"). A bare percentage
# scan would flag that history as drift and push a future maintainer to delete the explanation --
# the brevity-bias failure this repo already rules against. So the patterns below bind the number to
# an instruction ("context >= N%", "At N% context", "context hits N%", "at or above N%", and the
# threshold table rows), never to narrative.
echo ""
echo "--- handoff threshold parity across prescriptive surfaces ---"
HANDOFF_CANON=40
HANDOFF_FILES="CLAUDE.md templates/CLAUDE.md memory-bank/systemPatterns.md standards/MEMORY-BANK.md templates/standards/MEMORY-BANK.md .cursor/rules/memory-bank.mdc templates/cursor/rules/memory-bank.mdc templates/AGENTS.md templates/memory-bank/README.md"
HANDOFF_SEEN=0
# WHY both absence cases assert instead of `continue`: an aggregate "the sweep found something"
# guard proves the sweep is not entirely dead. It does NOT prove each declared surface was checked.
# Skipping silently on either absence lets a file drop out of coverage while the suite still reports
# success — which is the exact defect this block exists to catch, one level up. Both were reproduced:
# with plain `continue`, deleting one declared file and rewording another left the suite GREEN while
# its assertion count fell from 10 to 8. The per-file STATE_ABSENT idiom is borrowed from the
# figure-parity block above, which already had it; this block was modelled on that one and failed to
# carry over the part that makes it complete.
for f in $HANDOFF_FILES; do
    # Absence case 1 — a declared surface has vanished (deleted or renamed), so HANDOFF_FILES is stale.
    if [ ! -f "$REPO_ROOT/$f" ]; then
        echo "    $f: <file absent>"
        assert_contains "STATE_ABSENT" "STATE_PRESENT" "$f exists to state the handoff threshold"
        continue
    fi
    vals=$(grep -oiE "context (is at|>=|hits) [0-9]+%|at [0-9]+% context|at or above [0-9]+%|\| (Cursor|Claude Code) \| \*\*[0-9]+%\*\*" "$REPO_ROOT/$f" 2>/dev/null \
           | grep -oE '[0-9]+' | sort -u)
    # Absence case 2 — the file is present but its wording drifted out of every pattern above, so the
    # value is no longer being compared even though the file still claims to state it.
    if [ -z "$vals" ]; then
        echo "    $f: <no prescriptive threshold found>"
        assert_contains "STATE_ABSENT" "STATE_PRESENT" "$f states the handoff threshold in a recognised form"
        continue
    fi
    for v in $vals; do
        HANDOFF_SEEN=$((HANDOFF_SEEN + 1))
        if [ "$v" = "$HANDOFF_CANON" ]; then verdict=SAME; else verdict=DIFFERENT; fi
        assert_contains "$verdict" "SAME" "$f prescribes ${v}% (canon ${HANDOFF_CANON}%)"
    done
done

# WHY assert the sweep found something: if every pattern above stopped matching -- a reword, a moved
# file -- the loop would silently assert nothing and the suite would still be green.
[ "$HANDOFF_SEEN" -gt 0 ]
assert_exit_zero "$?" "handoff-threshold sweep matched at least one prescriptive statement (found $HANDOFF_SEEN)"

print_summary
