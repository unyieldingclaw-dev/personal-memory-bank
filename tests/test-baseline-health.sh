#!/usr/bin/env bash
# tests/test-baseline-health.sh — scripts/baseline-health.sh must DISCRIMINATE, not merely run green
#
# WHY THIS SUITE IS MUTATION-FIRST: baseline-health.sh extracts check bodies out of
# .github/workflows/pmb-health.yml by step name and executes them. Its dominant failure mode is not
# a wrong answer, it is a CONFIDENT GREEN FOR NOTHING — asking awk for a step name that no longer
# exists yields zero bytes, and running zero bytes of bash exits 0. Measured before the script was
# written. A suite that only ran the script against a healthy repo would pass identically whether
# the extraction worked or silently matched nothing, which is precisely the vacuous-test defect
# standards/CODE-REVIEW.md names ("a check that cannot fail does not count as a check").
#
# So every assertion below is paired with a mutation: the repo is cloned into a sandbox, one thing
# is deliberately broken, and the script is required to go red in a SPECIFIC way. The four exit
# codes are distinct on purpose and are asserted individually — collapsing them would let a broken
# extractor (3) masquerade as a failing check (1) or a clean tree (0).
#
# WHY A CLONE RATHER THAN A TEMP FIXTURE: the checks are written against a real repository — they
# call `git rev-parse`, `git cat-file origin/main:...`, and walk memory-bank/, standards/ and
# templates/. A synthetic directory would not exercise them. Cloning also keeps the working repo
# untouched, which matters because this suite runs alongside others.
set -u

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$REPO_ROOT/tests/helpers/assert.sh"

echo "=== baseline-health tests ==="

SCRIPT="$REPO_ROOT/scripts/baseline-health.sh"
assert_file_exists "$SCRIPT" "scripts/baseline-health.sh exists"

if ! bash -n "$SCRIPT" 2>/dev/null; then
    echo "  FAIL: scripts/baseline-health.sh is not valid bash"
    print_summary
    exit 1
fi
echo "  PASS: scripts/baseline-health.sh parses as bash"

# One sandbox per mutation. Accumulating array + a single trap: registering `trap ... EXIT` more
# than once silently overwrites the earlier registration, which this repo has fixed twice before
# (see tests/test-mb-backlog.sh and tests/test-mb-version-notifier.sh).
SANDBOXES=()
cleanup() { for d in "${SANDBOXES[@]:-}"; do [ -n "$d" ] && rm -rf "$d"; done; }
trap cleanup EXIT

# WHY the caller registers the sandbox rather than this function: every call site invokes this as
# `X=$(new_sandbox)`, and command substitution runs the function in a SUBSHELL. An array append
# performed in here is discarded when that subshell exits, so the parent's SANDBOXES stayed empty
# and the cleanup trap iterated nothing — measured, five full repo clones (~80 MB) leaked per run.
# The path is returned instead, and each call site appends it in the parent shell.
new_sandbox() {
    local d
    d=$(mktemp -d) || return 1
    git -C "$REPO_ROOT" clone -q "$REPO_ROOT" "$d/repo" 2>/dev/null || return 1
    cp "$SCRIPT" "$d/repo/scripts/baseline-health.sh" || return 1
    # The clone carries COMMITTED state. The script is copied in above precisely
    # because of that — and the workflow it extracts from needs identical
    # treatment, which it was not getting. MEASURED 2026-09-08: mutation 8 failed
    # against a fix that was present and correct in the working tree, because the
    # sandbox was still running HEAD's copy of pmb-health.yml. Without this line
    # no workflow change can be tested until after it is committed, which inverts
    # the point of a mutation suite: the one edit you most want to prove is the
    # one edit the harness cannot see.
    cp "$REPO_ROOT/.github/workflows/pmb-health.yml" "$d/repo/.github/workflows/pmb-health.yml" || return 1
    printf '%s' "$d"
}


run_in() {  # run_in <dir> ; echoes output, returns the script's exit code
    ( cd "$1" && bash scripts/baseline-health.sh 2>&1 )
}

# ---------------------------------------------------------------------------
# 1. CONTROL — a clean clone must pass. Without this the mutations below prove
#    nothing: a script that always fails would "pass" every mutation test.
# ---------------------------------------------------------------------------
BASE_D=$(new_sandbox) || { echo "  FAIL: could not create sandbox"; print_summary; exit 1; }
SANDBOXES+=("$BASE_D"); BASE="$BASE_D/repo"
out=$(run_in "$BASE"); rc=$?
assert_equals "0" "$rc" "clean clone: exits 0 (control — mutations below are meaningless without it)"
assert_contains "$out" "baseline-health: PASS" "clean clone: reports PASS"
assert_contains "$out" "PASS:    Check file sizes" "clean clone: names each check it ran"

# ---------------------------------------------------------------------------
# 2. MUTATION — a real check failure. An 801-line markdown file breaches the
#    File Size job's hard cap, so the script must go red AND name the check.
# ---------------------------------------------------------------------------
SBX_D=$(new_sandbox) || { echo "  FAIL: could not create sandbox"; print_summary; exit 1; }
SANDBOXES+=("$SBX_D"); SBX="$SBX_D/repo"
awk 'BEGIN{for(i=1;i<=801;i++) print "line "i}' > "$SBX/docs/ZZ-OVERSIZE.md"
out=$(run_in "$SBX"); rc=$?
assert_equals "1" "$rc" "broken check: exits 1, distinct from extraction failure (3)"
assert_contains "$out" "FAIL:    Check file sizes" "broken check: names the check that failed"
assert_contains "$out" "ZZ-OVERSIZE.md" "broken check: surfaces the offending file, not just a verdict"

# ---------------------------------------------------------------------------
# 3. MUTATION — THE CENTRAL ONE. Rename a step in the workflow. The extractor
#    then matches nothing, and an unguarded runner would execute zero bytes and
#    report success. The script must instead fail loudly with exit 3.
# ---------------------------------------------------------------------------
SBX_D=$(new_sandbox) || { echo "  FAIL: could not create sandbox"; print_summary; exit 1; }
SANDBOXES+=("$SBX_D"); SBX="$SBX_D/repo"
sed -i 's/^      - name: Credential grep$/      - name: Credential grep RENAMED/' \
    "$SBX/.github/workflows/pmb-health.yml"
out=$(run_in "$SBX"); rc=$?
assert_equals "3" "$rc" "renamed step: exits 3 — a silently-unmatched step is NOT a pass"
assert_contains "$out" "EXTRACTION FAILED" "renamed step: says extraction failed"
assert_contains "$out" "Credential grep" "renamed step: names which step could not be found"
assert_not_contains "$out" "baseline-health: PASS" "renamed step: never claims an overall pass"

# ---------------------------------------------------------------------------
# 4. MUTATION — re-indent the workflow body. Same silent-empty risk as a rename,
#    reached a different way, because the extractor keys on the block indent too.
# ---------------------------------------------------------------------------
SBX_D=$(new_sandbox) || { echo "  FAIL: could not create sandbox"; print_summary; exit 1; }
SANDBOXES+=("$SBX_D"); SBX="$SBX_D/repo"
sed -i 's/^      - name: Invisible Unicode characters$/       - name: Invisible Unicode characters/' \
    "$SBX/.github/workflows/pmb-health.yml"
out=$(run_in "$SBX"); rc=$?
assert_equals "3" "$rc" "re-indented step: exits 3 rather than silently skipping it"
assert_contains "$out" "Invisible Unicode characters" "re-indented step: names the step it lost"

# ---------------------------------------------------------------------------
# 5. MUTATION — the adopter case. No workflow at all must be SKIPPED (2), which
#    is neither a pass nor a repo failure, and must say nothing was verified.
# ---------------------------------------------------------------------------
SBX_D=$(new_sandbox) || { echo "  FAIL: could not create sandbox"; print_summary; exit 1; }
SANDBOXES+=("$SBX_D"); SBX="$SBX_D/repo"
rm -f "$SBX/.github/workflows/pmb-health.yml"
out=$(run_in "$SBX"); rc=$?
assert_equals "2" "$rc" "workflow absent: exits 2, distinct from both pass (0) and failure (1)"
assert_contains "$out" "SKIPPED" "workflow absent: reports SKIPPED"
assert_contains "$out" "Nothing was verified" "workflow absent: says plainly that nothing was checked"
assert_not_contains "$out" "baseline-health: PASS" "workflow absent: never reports a pass"

# ---------------------------------------------------------------------------
# 7. The step list must stay in sync with the workflow. This is what catches a
#    rename in the REAL repo before it reaches a review — mutation 3 proves the
#    script reacts, this proves the current pairing is actually correct.
# ---------------------------------------------------------------------------
# ANTI-VACUITY FLOOR, and it is the point of this block rather than a nicety. The enumeration
# anchors on the literal `STEPS=(`. Rename the array and the sed matches nothing, the loop never
# runs, `missing` keeps its initial 0, and the block reports success having checked zero entries —
# measured, not theorised. Pinning the count to a literal makes that failure loud. It also means
# adding an entry to STEPS deliberately fails this test until the number here is updated: the count
# IS the assertion.
# ---------------------------------------------------------------------------
# 6. MUTATION — a DUPLICATE step name. This is the one that mattered: step names
#    are not required to be unique by YAML, so a second step with a tracked name
#    is legal in a workflow GitHub accepts. The extractor matches by name and
#    concatenates every match, so an unguarded run executes the extra body under
#    the real check's name and still reports PASS. Verified reachable with a YAML
#    parser before this guard was written.
# ---------------------------------------------------------------------------
SBX_D=$(new_sandbox) || { echo "  FAIL: could not create sandbox"; print_summary; exit 1; }
SANDBOXES+=("$SBX_D"); SBX="$SBX_D/repo"
cat >> "$SBX/.github/workflows/pmb-health.yml" <<'YAML'

  decoy-job:
    name: Decoy
    runs-on: ubuntu-latest
    steps:
      - name: Credential grep
        shell: bash
        run: |
          echo "INJECTED_BODY_EXECUTED"
YAML
out=$(run_in "$SBX"); rc=$?
assert_equals "$rc" "3" "duplicate step name: exits 3 rather than executing a concatenated body"
assert_contains "$out" "AMBIGUOUS STEP NAME" "duplicate step name: says the name is ambiguous"
assert_contains "$out" "Credential grep" "duplicate step name: names the ambiguous step"
assert_not_contains "$out" "INJECTED_BODY_EXECUTED" "duplicate step name: the smuggled body never runs"
assert_not_contains "$out" "baseline-health: PASS" "duplicate step name: never reports an overall pass"

# ---------------------------------------------------------------------------
# 8. MUTATION - DETECTION EFFICACY, a different question from every mutation
#    above. Those prove the RUNNER behaves: it extracts, it refuses an ambiguous
#    name, it exits with the right code. None of them proves an extracted check
#    can still FIND anything. That gap is not theoretical - it concealed a check
#    that had never once been able to fail. pmb-health.yml's invisible-Unicode
#    grep errored on its own pattern, the step body swallowed the error with
#    2>/dev/null, and it printed "OK: No invisible Unicode characters found"
#    over a tree containing a real U+200B. Found 2026-09-08 by planting a
#    violation rather than by reading the code, which is the whole point: no CI
#    run since the check was written could have surfaced it, because ordinary CI
#    never injects a violation.
#    A green suite is worth nothing if the checks it runs are inert.
# ---------------------------------------------------------------------------
SBX_D=$(new_sandbox) || { echo "  FAIL: could not create sandbox"; print_summary; exit 1; }
SANDBOXES+=("$SBX_D"); SBX="$SBX_D/repo"
# Both planted as printf escapes rather than pasted literally: a fixture that
# smuggles invisible characters into the repo to prove invisible characters are
# detectable is a fixture nobody can review by eye.
# TWO vectors, in two files, because they fail differently. U+200B is the
# historical one that went undetected. U+E0061 is a Unicode Tag-block character,
# which hides a whole ASCII payload one invisible char per letter and was MISSED
# by the enumerated class this check used until 2026-09-08 — the strongest
# vector, absent from a list written to stop exactly this. Planting only the
# historical one would pass against a pattern still blind to the worse attack.
# Both target files sit far under the 500-warn/800-fail markdown cap, so a size
# failure cannot masquerade as the detection asserted here.
#
# TWO PLANT SHAPES, because each catches mutants the other misses. Both previous
# fixtures were defeatable and the history is the argument for this one:
#
#   v1  "Zero-width space follows:<ZWSP> end."  — distinctive visible text, so
#       replacing the WHOLE class with the literal `follows:` still passed every
#       assertion. It proved a pattern matched something, not that it detected an
#       invisible character.
#   v2  the bare character alone on a line — removed the visible text, but could
#       not distinguish "detects invisible characters" from "detects lines made
#       ONLY of invisible characters". Merely ANCHORING the shipped class,
#       (*UTF)^[\p{Cf}...]+$, passed 30/0 while missing a payload embedded in
#       prose — the realistic attack, and the one the comment in pmb-health.yml
#       calls the strongest vector. v1 had actually caught that mutant; v2 lost it.
#
# EMBEDDED plant: a duplicate of a line that ALREADY EXISTS in the clean tree,
# with the character inserted MID-LINE. Any pattern keying on the visible text
# therefore also fires on the untouched original — which breaks the CONTROL in
# mutation 1, not this block. That leaves the invisible character as the only
# thing that can discriminate. Derived from the file at runtime rather than
# hardcoded, so it cannot drift out of sync with the file's actual content.
# BARE plant: the character alone on a line. Kept because it catches mutants the
# embedded form misses — anything requiring surrounding non-space context.
#
# ONE SHAPE PER FILE, and that separation is load-bearing rather than tidiness.
# When both shapes shared LOGGING.md, an anchored pattern still found the bare
# one there, so that file's assertion passed and THREE of the five mutants below
# were discriminated by the single SECRETS.md assertion — measured, 29/1 each.
# Deleting one fixture line would have silently restored the blind spot for all
# three. Split across files, each shape fails its own assertion independently.
# plant_embedded <file> <utf8-escape> — duplicates the file's first non-blank
# line with the character inserted at the MIDPOINT, not after the first byte. An
# earlier version split after char 1, which in these files is the "#" of an H1;
# `(*UTF)^.?[...]` then passed 31/0 while missing a payload buried in prose, and
# the comment's own claim of "mid-line" was not what the fixture tested.
plant_embedded() {
    local f="$1" ch="$2" base mid
    base=$(grep -m1 -v '^[[:space:]]*$' "$f")
    mid=$(( ${#base} / 2 ))
    printf "%s${ch}%s\n" "${base:0:mid}" "${base:mid}" >> "$f"
}
plant_embedded "$SBX/standards/LOGGING.md"            '\xe2\x80\x8b'      # U+200B  in \p{Cf}
plant_embedded "$SBX/standards/SECRETS.md"            '\xf3\xa0\x81\xa1'  # U+E0061 in \p{Cf}, Tag block
# U+3164 HANGUL FILLER is category Lo, NOT Cf — it is covered only by the four
# explicit code points in the shipped class. Without this plant, deleting those
# four and keeping the bare category passed 31/0 while a planted U+3164 went
# undetected end to end. The comment above the pattern argues for categories and
# against lists, which makes deleting that residual list the most invited edit on
# the line; this is the assertion that makes the edit fail instead of ship.
plant_embedded "$SBX/standards/TRUST-CLASSIFICATION.md" '\xe3\x85\xa4'    # U+3164, Lo not Cf
printf '\xe2\x80\x8b\n' >> "$SBX/standards/SECURITY-RULES.md"
# ONE PLANT PER SCOPE ROOT. The check scans THREE roots — `find standards
# CLAUDE.md templates/CLAUDE.md` — and every plant above sits under the first.
# Narrowing that find to `standards` alone therefore passed 32/0 while a real
# U+200B in CLAUDE.md went undetected end to end: measured in both directions.
# CLAUDE.md is the highest-value target in this check's threat model, being the
# file whose whole function is carrying instructions to the agent. The narrowing
# is also SCHEDULED rather than hypothetical — widening the scan to cover
# templates/standards/ (a known follow-up) edits precisely that line, so without
# these two plants the next planned change lands on the blind spot.
plant_embedded "$SBX/CLAUDE.md"           '\xe2\x80\x8b'
plant_embedded "$SBX/templates/CLAUDE.md" '\xe2\x80\x8b'
out=$(run_in "$SBX"); rc=$?
assert_equals "$rc" "1" "planted invisible Unicode: exits 1 - the check must DETECT, not merely run"
# WHY the detection string and not the step banner. baseline-health.sh prints
# "FAIL:    <step>" for ANY non-zero exit of the extracted body, so asserting on
# it pins WHICH step failed but not WHY. Measured: deleting just the (*UTF) token
# makes every file error with status 2, the step reports FAIL for a scan that
# examined nothing, and a banner-only assertion still passes — the same
# can't-fail defect this mutation exists to close, one level deeper. The success
# path emits "invisible Unicode character(s) found above"; the broken-scanner
# path emits "NOT scanned". Assert the first and forbid the second.
assert_contains "$out" "invisible Unicode character(s) found above" "planted invisible Unicode: reports a real DETECTION, not merely a failing step"
assert_not_contains "$out" "NOT scanned" "planted invisible Unicode: the scanner ran — a broken scan must not stand in for a detection"
assert_contains "$out" "LOGGING.md" "planted U+200B embedded mid-line: surfaces the zero-width-space file"
assert_contains "$out" "SECRETS.md" "planted U+E0061 embedded mid-line: surfaces the Tag-block file the old enumerated class missed"
assert_contains "$out" "SECURITY-RULES.md" "planted bare U+200B: surfaces the isolated-character file — an independent discriminator, so no single fixture line carries three mutants"
assert_contains "$out" "TRUST-CLASSIFICATION.md" "planted U+3164 (category Lo, not Cf): surfaces the file covering the four explicit code points — deleting them for the bare category must not pass"
assert_contains "$out" "CLAUDE.md" "planted U+200B in CLAUDE.md: pins the second scope root — narrowing the find to standards/ alone must not pass"
assert_contains "$out" "templates/CLAUDE.md" "planted U+200B in templates/CLAUDE.md: pins the third scope root"
assert_not_contains "$out" "baseline-health: PASS" "planted invisible Unicode: never reports an overall pass"

# ---------------------------------------------------------------------------
# 9. MUTATION — the BROKEN-SCANNER branch, a third outcome distinct from both a
#    detection and a clean tree. The step reads grep's exit status explicitly:
#    0 is a hit, 1 is clean, anything else means grep itself failed. That third
#    branch is precisely what the original defect lacked — a `2>/dev/null` and an
#    `if` collapsed "errored" into "clean", so the step printed OK for a scan
#    that never happened. Mutation 8 proves a real hit is caught; this proves a
#    BROKEN scan is reported loudly rather than passing silently. Without it,
#    neutering the branch to `elif false` left every assertion green.
# ---------------------------------------------------------------------------
SBX_D=$(new_sandbox) || { echo "  FAIL: could not create sandbox"; print_summary; exit 1; }
SANDBOXES+=("$SBX_D"); SBX="$SBX_D/repo"
# Dropping (*UTF) returns PCRE to 8-bit mode, where \x{200B} exceeds the
# single-byte maximum, so grep aborts on its own pattern for EVERY file. That is
# the original defect's exact mechanism, reintroduced deliberately. Scoped to the
# grep line so the surrounding explanatory comments are left intact.
sed -i "/grep -Pn/s/(\*UTF)//" "$SBX/.github/workflows/pmb-health.yml"
out=$(run_in "$SBX"); rc=$?
assert_equals "$rc" "1" "broken grep pattern: exits 1 rather than passing a scan that never ran"
assert_contains "$out" "NOT scanned" "broken grep pattern: says plainly the file was not scanned"
assert_contains "$out" "broken check, not a pass" "broken grep pattern: names it a broken check rather than a clean tree"
assert_not_contains "$out" "baseline-health: PASS" "broken grep pattern: never reports an overall pass"

WF="$REPO_ROOT/.github/workflows/pmb-health.yml"

# ANTI-VACUITY FLOOR, and it is the whole point of this block rather than a nicety. The enumeration
# anchors on the literal STEPS=( . Rename that array and the extraction matches nothing, the loop
# below never executes, missing keeps its initial 0, and the block reports success having checked
# zero entries — measured, not theorised. Pinning the count to a literal makes that failure loud.
# It also means deliberately adding an entry to STEPS fails this test until the number here is
# updated: the count IS the assertion, not bookkeeping around it.
#
# grep -oE + tr rather than a sed backreference: the backreference was silently lost in transit
# once already while editing this file, leaving an empty replacement that made the enumeration
# return blank lines and the count 0 — the exact vacuity this floor exists to catch, introduced by
# the edit that added the floor.
steps_of() {
    sed -n '/^STEPS=(/,/^)/p' "$1" | grep -oE '"[^"]+"' | tr -d '"'
}

enumerated=$(steps_of "$SCRIPT" | grep -c .)
assert_equals "$enumerated" "7" "test 6 enumerated all 7 STEPS entries (0 here would mean this test checked nothing)"

missing=0
while IFS= read -r step; do
    [ -z "$step" ] && continue
    grep -qF "      - name: $step" "$WF" || { echo "    unmatched STEPS entry: $step"; missing=$((missing + 1)); }
done < <(steps_of "$SCRIPT")
# Routed through assert_equals so a real desync FAILS THE SUITE. The previous version printed a bare
# echo that print_summary never saw, so a genuine mismatch still exited 0.
assert_equals "$missing" "0" "every STEPS entry resolves to a real step name in the workflow"

print_summary
