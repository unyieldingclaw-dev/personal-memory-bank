#!/usr/bin/env bash
# scripts/baseline-health.sh — run this repo's deterministic CI checks locally.
#
# WHY THIS EXISTS: the review commands (`/code-review`, `/change-review`) each carried a prose
# description of which CI checks to run and how. That is a transcription of logic, re-performed by
# hand on every review, and it was measurably unreliable: reproducing the spec placeholder scan
# correctly requires a 20-line awk function with a fence-parity guard and a per-line backtick-parity
# guard, and an orchestrator's naive `grep` reimplementation reported 3 false positives on a clean
# tree. Transcribed CI *numbers* had already bitten this repo three times (see
# tests/test-threshold-parity.sh's header); transcribed CI *logic* is the same defect one level up.
#
# WHY EXTRACTION RATHER THAN REIMPLEMENTATION: this script does not contain a copy of any check. It
# locates each step by name in .github/workflows/pmb-health.yml, lifts the body of its `run:` block,
# and executes that verbatim. The workflow stays the single source of truth, so a threshold or
# pattern changed there takes effect here on the next run with no edit to this file. Nothing in this
# script needs updating when a cap is ratcheted.
#
# WHY AN EMPTY EXTRACTION IS A HARD ERROR RATHER THAN A SKIP: measured before this script was
# written — asking the extractor for a step name that does not exist yields zero bytes, and running
# zero bytes of bash exits 0. A runner that did not check would report a confident PASS for a check
# that never executed, and would do so the moment anyone renamed a step or re-indented the workflow.
# That is the "check that cannot fail" defect standards/CODE-REVIEW.md forbids by name, and it would
# make this script strictly WORSE than the prose it replaces, because prose does not emit a green
# tick. Every expected step must extract non-empty or this script fails loudly, naming the step, with
# an exit code distinct from a real check failure so the two are never confused.
#
# WHY CI'S OWN SHELL FLAGS: every step in the workflow declares `shell: bash`, which in GitHub
# Actions means `bash --noprofile --norc -eo pipefail`. Running the bodies under a plain `bash`
# would be measuring with a different instrument than the one being mirrored — the results happened
# to agree on both a clean and a deliberately broken tree when tested, but agreeing by luck is not
# the same as being correct.
#
# NETWORK: not fully offline. The "Check file sizes" step includes the startup-context ratchet,
# which runs `git fetch --depth=1 origin main || true` to establish its baseline. That is one
# shallow fetch, it fails soft, and it is disclosed here rather than denied — an earlier version of
# the review-command prose claimed this whole set was "fully local and offline", which was false.
#
# EXIT CODES — deliberately distinct, because these mean different things:
#   0  every check passed
#   1  at least one check FAILED (the repo has a real problem)
#   2  the workflow is not present (checks were SKIPPED, nothing was verified)
#   3  a step could not be extracted (this script or the workflow is broken — NOT a clean tree)

set -u

WORKFLOW=".github/workflows/pmb-health.yml"

# The steps to run, by their exact `- name:` in the workflow. Semgrep, PSScriptAnalyzer and
# gitleaks are deliberately absent: each needs a registry fetch, module install or network action,
# and per this repo's layering rule they are correctly CI-only.
#
# One list, used by both review commands. Previously each command carried its own prose list and
# the two had already drifted apart — one included Template Integrity, the other the ratchet.
STEPS=(
    "Check file sizes"
    "Credential grep"
    "Spec placeholder grep"
    "Invisible Unicode characters"
    "Hidden HTML comments in Markdown"
    "LLM bypass phrases"
    "Validate hook scripts referenced in templates/.claude/settings.json exist in templates/scripts/"
)

VERBOSE=0
for arg in "$@"; do
    case "$arg" in
        -v|--verbose) VERBOSE=1 ;;
        -h|--help)
            echo "usage: bash scripts/baseline-health.sh [-v|--verbose]"
            echo "Runs the deterministic checks from $WORKFLOW by extracting and executing them."
            echo "Exit: 0 pass  1 a check failed  2 workflow absent  3 extraction failed"
            exit 0
            ;;
        *) echo "baseline-health: unknown argument '$arg'" >&2; exit 3 ;;
    esac
done

# Run from the repository root: the workflow steps are written for that working directory.
ROOT=$(git rev-parse --show-toplevel 2>/dev/null)
if [ -z "$ROOT" ]; then
    echo "baseline-health: not inside a git repository" >&2
    exit 3
fi
cd "$ROOT" || exit 3

if [ ! -f "$WORKFLOW" ]; then
    echo "=== baseline health ==="
    for s in "${STEPS[@]}"; do
        printf 'SKIPPED: %s\n' "$s"
    done
    echo ""
    echo "baseline-health: SKIPPED — $WORKFLOW is not present in this repository."
    echo "Nothing was verified. Do not report these checks as passing, and do not substitute"
    echo "remembered thresholds; this repository may not define these caps at all."
    exit 2
fi

# Lift the body of a step's `run: |` block. Matches the step by its exact name, then strips the
# 10-space block indent the workflow uses. Blank lines are preserved as blank rather than treated
# as the end of the block, since a blank line inside a run block is common and legal.
extract_step() {
    awk -v want="$1" '
        $0 ~ /^      - name: / {
            name = $0; sub(/^      - name: /, "", name)
            instep = (name == want); inrun = 0; next
        }
        instep && /^        run: \|/ { inrun = 1; next }
        inrun {
            if ($0 ~ /^[[:space:]]*$/) { print ""; next }
            if ($0 !~ /^          /) { inrun = 0; instep = 0; next }
            sub(/^          /, ""); print
        }
    ' "$WORKFLOW"
}

echo "=== baseline health ($WORKFLOW) ==="
FAILED=0
BODY=$(mktemp) || exit 3
OUT=$(mktemp) || exit 3
trap 'rm -f "$BODY" "$OUT"' EXIT

for step in "${STEPS[@]}"; do
    # WHY uniqueness is checked BEFORE extraction, and separately from emptiness:
    # extract_step matches on the step name and is not job-scoped, so a second step with the same
    # name anywhere in the file has its body CONCATENATED onto the first. Duplicate step names are
    # legal YAML — verified with a parser, not assumed — so this is reachable through a workflow
    # GitHub accepts, and the resulting body is non-empty, which means the emptiness guard below
    # passes it. That combination executes content nobody intended, under a known check's name,
    # and still reports PASS. The emptiness guard cannot catch it; only a count can.
    matches=$(grep -Fxc "      - name: ${step}" "$WORKFLOW" || true)
    if [ "${matches:-0}" -eq 0 ]; then
        echo ""
        echo "baseline-health: EXTRACTION FAILED for step: $step"
        echo "  No step with that exact name exists in $WORKFLOW."
        echo "  It was probably renamed or the file re-indented. This is NOT a passing check —"
        echo "  nothing ran. Fix the name in this script's STEPS list, or fix the workflow."
        exit 3
    fi
    if [ "$matches" -ne 1 ]; then
        echo ""
        echo "baseline-health: AMBIGUOUS STEP NAME: $step"
        echo "  Found $matches steps with this exact name in $WORKFLOW; expected exactly 1."
        echo "  Extraction concatenates every match, so this would run unintended content under"
        echo "  this check's name. NOTHING WAS VERIFIED for this step."
        exit 3
    fi

    extract_step "$step" > "$BODY"

    # See the header: an empty extraction is a broken workflow or a broken extractor, never a pass.
    if [ ! -s "$BODY" ]; then
        echo ""
        echo "baseline-health: EXTRACTION FAILED for step: $step"
        echo "  No 'run:' body was found under that exact name in $WORKFLOW."
        echo "  The step was probably renamed or the file re-indented. This is NOT a passing check —"
        echo "  nothing ran. Fix the name in this script's STEPS list, or fix the workflow."
        exit 3
    fi

    if bash --noprofile --norc -eo pipefail "$BODY" > "$OUT" 2>&1; then
        printf 'PASS:    %s\n' "$step"
        [ "$VERBOSE" -eq 1 ] && sed 's/^/         /' "$OUT"
    else
        printf 'FAIL:    %s\n' "$step"
        sed 's/^/         /' "$OUT"
        FAILED=1
    fi
done

echo ""
if [ "$FAILED" -eq 0 ]; then
    echo "baseline-health: PASS (${#STEPS[@]} checks)"
else
    echo "baseline-health: FAIL — at least one check above failed."
    echo "A failure here is a real CI failure: these are the same check bodies the workflow runs."
fi
exit "$FAILED"
