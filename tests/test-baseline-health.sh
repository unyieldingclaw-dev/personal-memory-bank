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
