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
MB_STD="$REPO_ROOT/standards/MEMORY-BANK.md"

# CI is the source of truth: the MB_FAIL associative array.
CI_LINE=$(grep -m1 'declare -A MB_FAIL=(' "$CI_YML")
CI_WARN_LINE=$(grep -m1 'declare -A MB_WARN=(' "$CI_YML")

FILES="projectbrief.md systemPatterns.md techContext.md activeContext.md progress.md"

for f in $FILES; do
    ci=$(printf '%s' "$CI_LINE"  | sed -n "s/.*\[$f\]=\([0-9]*\).*/\1/p")
    sh=$(grep -o "check_size \"memory-bank/$f\" *[0-9]*" "$MB_SH" | grep -o '[0-9]*$')
    ps=$(grep -o "Name=\"$f\"; Max=[0-9]*" "$MB_PS1" | grep -o '[0-9]*$')

    echo ""
    echo "--- $f: CI=$ci mb.sh=$sh mb.ps1=$ps ---"
    # These are VALUE comparisons, so they use assert_equals. assert_contains is an unanchored
    # grep: it reported PASS for ci=120 against sh=1200, demonstrated on synthetic input (the real
    # caps agree today, so the defect was latent). An earlier fix hand-rolled a SAME/DIFFERENT
    # verdict-word workaround here; the primitive now exists in helpers/assert.sh and this uses it.
    # LIMIT: equality cannot distinguish "both extracted the same value" from "both extractions
    # returned nothing". These three assertions are not independent -- the "CI declares a cap" one
    # is what catches a double extraction failure.
    assert_contains "ci=$ci" "ci=[0-9]"  "CI declares a cap for $f"
    assert_equals   "$sh" "$ci"          "mb.sh cap for $f matches CI"
    assert_equals   "$ps" "$ci"          "mb.ps1 cap for $f matches CI"
    # FOURTH statement of the same caps: standards/MEMORY-BANK.md's File Size Guidelines table.
    # Found 2026-08-30 by auditing a cap change -- and it was ALREADY divergent before that change
    # (the table said projectbrief 150 against CI's 120, and techContext 400 against 300), with
    # nothing comparing them. A docs table that contradicts CI tells a reader the opposite of what
    # the gate will do. The row is matched on "<N> lines" so the eviction tables below, which reuse
    # the same filenames in their first column, cannot be picked up by mistake.
    doc=$(grep -E "^\| $f \| [0-9]+-[0-9]+ lines \|" "$MB_STD" | head -1 | awk -F'|' '{gsub(/ /,"",$4); print $4}')
    assert_equals   "$doc" "$ci"         "standards/MEMORY-BANK.md table cap for $f matches CI"
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
docs/archive/progress-2026-08-22-to-27-gate-passes-and-bundle-review.md
docs/WORK-MB-PARADIGM-DELTA-BRIEF.md
scripts/dangerous-commands.sh
templates/docs/HOOKS-GUIDE.md
templates/scripts/dangerous-commands.sh
tests/test-dangerous-commands.sh
"

# NOTE 2026-08-30: the progress.md statement was relocated VERBATIM into the archive file named
# above by that day's eviction pass, so the sweep follows it rather than dropping to six sources.
# This test caught the removal the moment it happened, which is the whole point of it -- but note
# that a sweep over NAMED files cannot notice a source that is deleted outright and never replaced;
# only the count below defends that, and it defends the total, not any particular file.
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
    # raw values with it would let "1.07->2.3" pass against "1.07->2.33".
    echo "    $f: $pair"
    assert_equals "$pair" "$CANON" "$f figure ($pair) agrees with $CANON_SRC ($CANON)"
done

# ── the maintenance path states the caps a THIRD time, and nothing compared that copy ────────
# WHY this block exists: the loop above compares CI's MB_FAIL against `mb doctor`'s check_size() in
# both shells. `mb clean` restates the SAME numbers a third time, hardcoded inside show_clean() and
# Show-Clean, and a review found that third copy compared by nothing.
#
# WHY PER-FILE AND ORDERED, not a sorted set of every `-gt` in the function: the first version of
# this block did exactly that, and a review DEMONSTRATED it could not fail on a transposition --
# swapping activeContext's FAIL (150) with progress's WARN (250) leaves the sorted multiset
# identical, so `mb clean` would apply both caps to the wrong file while this stayed green. The
# comment here previously claimed "mutating any single number turns this RED", which was true only
# for single-value drift. Each file's own block is now sliced out and its thresholds compared IN
# ORDER (FAIL then WARN, matching the branch order in both shells), so pairing is asserted, not
# just membership.
slice_clean() {  # $1=file $2=start-regex $3=end-regex(or empty for end-of-function)
    awk -v s="$2" -v e="$3" '
        /^show_clean\(\)|^function Show-Clean/ {inf=1}
        inf && $0 ~ s {grab=1}
        grab && e != "" && $0 ~ e {exit}
        grab {print}
        inf && /^}/ {exit}' "$1" | grep -oE '[-]gt [0-9]+' | grep -oE '[0-9]+' | tr '\n' ' '
}
for cf in activeContext.md progress.md; do
    ci_fail=$(printf '%s' "$CI_LINE"      | sed -n "s/.*\[$cf\]=\([0-9]*\).*/\1/p")
    ci_warn=$(printf '%s' "$CI_WARN_LINE" | sed -n "s/.*\[$cf\]=\([0-9]*\).*/\1/p")
    expect="$ci_fail $ci_warn "
    if [ "$cf" = "activeContext.md" ]; then
        got_sh=$(slice_clean "$MB_SH"  'SLIM_PATH=' 'PROGRESS_PATH=')
        got_ps=$(slice_clean "$MB_PS1" 'activeContext\.md"' 'progressPath =')
    else
        got_sh=$(slice_clean "$MB_SH"  'PROGRESS_PATH=' '')
        got_ps=$(slice_clean "$MB_PS1" 'progressPath =' '')
    fi
    echo ""
    echo "--- mb clean caps for $cf: CI=[$expect] mb.sh=[$got_sh] mb.ps1=[$got_ps] ---"
    # Absence guard: a broken slice yields empty, which must not silently compare nothing to nothing.
    assert_contains "expect=$expect" "expect=[0-9]" "CI declares mb-clean caps for $cf"
    assert_equals "$got_sh" "$expect" "mb.sh show_clean() FAIL,WARN for $cf match CI in order"
    assert_equals "$got_ps" "$expect" "mb.ps1 Show-Clean FAIL,WARN for $cf match CI in order"
done

# ── the startup-context ratchet must be stated identically in all THREE places ───────────────
# WHY: the ratchet is the only HARD-FAIL on the aggregate startup budget, and its first version lived
# solely in .github/workflows/pmb-health.yml -- enforced in CI, mirrored in neither `mb doctor`,
# covered by no test, in the very change that added a parity assertion for every other cap.
#
# It must agree on the MEASUREMENT and the SET, not just exist. Two defects were found here by
# mutation and both are guarded below:
#  - `git show | wc -c` in bash vs a reconstruct-and-re-encode in PowerShell disagreed by 1,698
#    bytes. All three now use `git cat-file -s`, a size git already stores that no shell decodes.
#  - An earlier version of THIS BLOCK compared a hardcoded five-file list with `sort -u`, and its
#    comment claimed "six files ... compared as an ordered list". Both halves were false, and it
#    missed three mutations: dropping CLAUDE.md, dropping a file the source names elsewhere, and
#    duplicating an entry. The sources now ENUMERATE memory-bank/*.md rather than listing, so the
#    assertion is that they enumerate -- a set that cannot be silently short by one.
echo ""
echo "--- startup-context ratchet: same primitive, same enumeration, all three sources ---"
RATCHET_SOURCES="$CI_YML $MB_SH $MB_PS1"
for src in $RATCHET_SOURCES; do
    b=$(basename "$src")
    # ASSERT THE LOOKUP EXPRESSION, not the bare filename. Comment-stripping was the wrong
    # instrument: review demonstrated the assertion still passed for pmb-health.yml with the real
    # baseline lookup deleted, because "CLAUDE.md" also appears in an ECHO line inside the region
    # and sed cannot strip a string literal. A rename mutation survived too. Matching the actual
    # call means only the call can satisfy it.
    #
    # Region bounded by a terminator that EXISTS INDEPENDENTLY of what is asserted -- the OK-flag
    # test following every baseline loop -- rather than the n>=40 line count it replaces, which
    # overshot mb.sh by 9 lines and mb.ps1 by 20 and was green only by luck.
    case "$src" in
        *.ps1) claim_pat='@("CLAUDE.md")'       ; claim_end='if ($ratchetOk' ;;
        *.yml) claim_pat='origin/main:CLAUDE.md' ; claim_end='if [ "$BASE_OK"' ;;
        *)     claim_pat='origin/main:CLAUDE.md' ; claim_end='if [ "$RATCHET_OK"' ;;
    esac
    region_claude=$(awk -v e="$claim_end" '/RATCHET_BASE=|ratchetBase = 0|BASE_CEIL=/{f=1} f&&index($0,e){exit} f{print}' "$src" | grep -v '^[[:space:]]*#' | grep -v '^[[:space:]]*echo \|^[[:space:]]*Write-Host ')
    # >=1, not ==1: each source legitimately calls it twice (once for CLAUDE.md, once per enumerated
    # memory-bank file). An earlier draft asserted "exactly once" and went red against correct code
    # -- the assertion's claim was wrong, not the code.
    assert_contains "$(grep -c 'cat-file -s "origin/main:' "$src" || true)" "^[1-9]" \
        "$b uses the cat-file primitive for the baseline"
    # PER-LANGUAGE, because the vulnerability is per-language. The bash sources word-split an
    # unquoted $(git ls-tree ...) on a filename containing a space -- demonstrated on a real tree
    # with "memory-bank/space file.md", which split into two nonexistent paths and silently
    # degraded this REQUIRED check to advisory. They must use NUL-delimited -rz. PowerShell
    # captures external output one array element per line and is NOT word-split (verified), so
    # demanding -rz there would pin a delimiter it does not parse. Same guarantee, different
    # mechanism -- asserting one pattern for all three would be wrong for one of them.
    case "$src" in
        *.ps1) enum_pat='ls-tree -r --name-only origin/main' ;;
        *)     enum_pat='ls-tree -rz --name-only origin/main' ;;
    esac
    assert_contains "$(grep -c "$enum_pat" "$src" || true)" "^[1-9]" \
        "$b enumerates memory-bank/ safely for its language, not via a hardcoded list"
    # Matched inside the ratchet REGION, not as the literal string "origin/main:CLAUDE.md": mb.ps1
    # builds its path list in a variable, so a literal check reported ABSENT against code that does
    # include the file. Reach has to match the assertion -- the defect this file exists to catch.
    assert_contains "$region_claude" "$claim_pat" \
        "$b performs the CLAUDE.md baseline lookup (16,212 B on main -- exceeds the whole headroom)"
    # A hardcoded memory-bank list anywhere in the ratchet region would reintroduce the short-by-one
    # hole the enumeration closes.
    region=$(awk '/RATCHET_BASE=|ratchetBase = 0|BASE_CEIL=/{f=1} f{print} f&&/^ *(done|})$/{exit}' "$src")
    assert_not_contains "$region" "memory-bank/projectbrief.md" \
        "$b's ratchet region hardcodes no memory-bank filename"
done
# THE CEILING REGION, which the baseline assertions above do NOT reach. Found by review: every
# check here scoped itself to the RATCHET_BASE/BASE_CEIL region, so reverting all three CEILING
# loops to the pre-enumeration hardcoded list passed green -- the exact regression this block exists
# to prevent, with the "Enumerated, not listed" comments left sitting above listing code.
#
# COMMENTS ARE STRIPPED BEFORE ASSERTING. Demonstrated necessary: a mutation that reverted mb.ps1's
# ceiling to a hardcoded list still PASSED the recursion check, because the comment line above it
# says "-Recurse" and the assertion matched the prose rather than the code. An assertion a comment
# can satisfy is not an assertion about behaviour.
#
# The recursion pattern is per-language rather than one alternation for all three: `-type f` marks a
# recursive find on the bash side, `-Recurse` on the PowerShell side. A single shared pattern was
# also what let the comment match.
for src in $RATCHET_SOURCES; do
    b=$(basename "$src")
    ceil_region=$(awk '/CEIL=0$|CEILING_BYTES=0$|ceilingFiles = @\(\)/{f=1} f&&/CEIL_KB=|CEILING_KB=|ceilingKB =/{exit} f{print}' "$src" \
                  | sed 's/[[:space:]]*#.*$//')
    # NO LEADING DASH in the pattern: assert_contains is `grep -qi "$pattern"`, and a pattern
    # beginning with '-' is parsed by grep as OPTIONS, not as a pattern. '-type f' silently never
    # matched (false FAIL on correct code) and '-Recurse' silently always did (false PASS on
    # reverted code) -- the same assertion defect in both directions, from one character.
    case "$src" in
        *.ps1) recur='Recurse' ;;
        *)     recur='type f'  ;;
    esac
    assert_not_contains "$ceil_region" "projectbrief.md" \
        "$b's ceiling enumerates rather than hardcoding a memory-bank file list"
    assert_contains "$ceil_region" "$recur" \
        "$b's ceiling enumeration is RECURSIVE, matching the ls-tree -r baseline"
done

# ── the two shells must resolve the SAME startup root from any session ───────────────────────
# WHY: CLAUDE.md makes the MAIN worktree's memory-bank/ authoritative and forbids updating it from a
# subworktree, so a subworktree's copy is stale by construction. Measuring it reported 69,594 bytes
# "under" origin/main from a worktree where nothing had shrunk -- a falsely reassuring green on the
# one gate meant to be unfoolable, in the shape this repo hits most: a side job spun up in a
# worktree while the main session runs. CI is exempt: it always runs at the repo root, never a
# worktree, so it has no common-dir resolution and must not be asserted to have one.
for src in "$MB_SH" "$MB_PS1"; do
    # SCOPED to the startup-root resolution, not the whole file, and comments stripped. Both
    # matter: mb.ps1 names git-common-dir THREE times (a comment, an unrelated feature near line
    # 685, and this one), so a file-wide grep stays green even when THIS resolution is removed --
    # it would be reporting on someone else's code. Demonstrated: mutating the ceiling's own
    # resolution in BOTH shells left the file-wide form at 65/65 green.
    root_region=$(awk '/STARTUP_ROOT=|startupRoot = "[.]"/{f=1} f{print; n++} n>=8{exit}' "$src" | sed 's/[[:space:]]*#.*$//')
    assert_contains "$root_region" "rev-parse --git-common-dir" \
        "$(basename "$src") resolves the startup root via git-common-dir (worktree-aware)"
done

# Behavioural: the baseline must resolve, or every assertion above is vacuous.
RB=$(git -C "$REPO_ROOT" cat-file -s "origin/main:CLAUDE.md" 2>/dev/null || echo 0)
for f in $(git -C "$REPO_ROOT" ls-tree -r --name-only origin/main -- memory-bank/ 2>/dev/null | grep '\.md$'); do
    RB=$((RB + $(git -C "$REPO_ROOT" cat-file -s "origin/main:$f" 2>/dev/null || echo 0)))
done
assert_contains "base=$RB" "base=[1-9][0-9]*" "origin/main baseline resolves to a non-zero aggregate ($RB)"

# ── the two shells must COUNT lines the same way, not merely agree on thresholds ─────────────
# WHY: matching thresholds are worthless if the measurement differs. `Measure-Object -Line` does not
# count blank lines, so mb.ps1 reported activeContext.md as 118 lines where wc -l reported 146 -- a
# 28-line gap that would let pwsh certify a file OK that CI fails at the same threshold. Found by
# RUNNING `mb.ps1 clean` against the bash twin; reading the thresholds could never have shown it.
PS_MEASURE_LINE=$(grep -c "Measure-Object -Line" "$MB_PS1" || true)
assert_equals "$PS_MEASURE_LINE" "0" "mb.ps1 uses no blank-line-skipping Measure-Object -Line"

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
        assert_equals "$v" "$HANDOFF_CANON" "$f prescribes ${v}% (canon ${HANDOFF_CANON}%)"
    done
done

# WHY assert the sweep found something: if every pattern above stopped matching -- a reword, a moved
# file -- the loop would silently assert nothing and the suite would still be green.
[ "$HANDOFF_SEEN" -gt 0 ]
assert_exit_zero "$?" "handoff-threshold sweep matched at least one prescriptive statement (found $HANDOFF_SEEN)"

# ── adopter-CI direction check ───────────────────────────────────────────────────────
# WHY this is an INEQUALITY and not the equality used above: there are TWO CI cap sets, and they
# are not supposed to match. `.github/workflows/pmb-health.yml` governs THIS repo and has been
# ratcheted down as these files shrank. `templates/.github/workflows/memory-bank-size.yml` ships to
# adopters as a STARTING DEFAULT -- its own comment says "Tune them to your project" -- so forcing
# PMB's tightened values onto a fresh adopter would red their build on install. Asserting equality
# here would be wrong and would have to be deleted the next time this repo ratchets.
#
# WHAT MUST hold is the direction. `mb doctor` ships to adopters too, so if doctor were LOOSER than
# the CI they receive, an adopter would get a clean local check followed by a red build -- the exact
# failure this file's header calls "worse and unrecorded" (projectbrief 150 vs 120, techContext 400
# vs 300). Doctor being STRICTER is merely noisy: a warning their CI does not enforce. So the
# invariant is doctor <= adopter CI, per file, and only the dangerous direction fails.
#
# Found 2026-09-02: nothing compared these two sources at all. CI_YML above is bound to
# pmb-health.yml only, so the adopter workflow was outside every existing assertion.
TMPL_YML="$REPO_ROOT/templates/.github/workflows/memory-bank-size.yml"
echo ""
echo "--- mb doctor must not be looser than the CI shipped to adopters ---"
if [ ! -f "$TMPL_YML" ]; then
    assert_contains "TEMPLATE_ABSENT" "TEMPLATE_PRESENT" "adopter CI workflow exists to compare against"
else
    TMPL_FAIL_LINE=$(grep -m1 'declare -A FAIL_LINES=(' "$TMPL_YML")
    TMPL_SEEN=0
    for f in $FILES; do
        tmpl=$(printf '%s' "$TMPL_FAIL_LINE" | sed -n "s/.*\[$f\]=\([0-9]*\).*/\1/p")
        sh=$(grep -o "check_size \"memory-bank/$f\" *[0-9]*" "$MB_SH" | grep -o '[0-9]*$')
        # Both extractions must have produced a number, or the comparison is vacuous -- the same
        # empty-vs-empty trap the equality block above documents.
        if [ -z "$tmpl" ] || [ -z "$sh" ]; then
            assert_contains "EXTRACT_EMPTY" "EXTRACT_OK" "$f: extracted both adopter-CI ($tmpl) and mb.sh ($sh) caps"
            continue
        fi
        TMPL_SEEN=$((TMPL_SEEN + 1))
        [ "$sh" -le "$tmpl" ]
        assert_exit_zero "$?" "$f: mb doctor ($sh) <= adopter CI ($tmpl) — doctor is not looser than the build it ships beside"
    done
    # Anti-tautology guard: if every extraction above silently stopped matching, the loop would
    # assert nothing per file and this block would read as green.
    [ "$TMPL_SEEN" -gt 0 ]
    assert_exit_zero "$?" "adopter-CI direction sweep compared at least one file (found $TMPL_SEEN)"
fi

print_summary
