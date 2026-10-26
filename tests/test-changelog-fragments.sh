#!/usr/bin/env bash
# tests/test-changelog-fragments.sh — scripts/changelog-assemble.sh and the changelog.d/ fragments
#
# WHY A COPY OF THE SCRIPT IN A SANDBOX: the script resolves CHANGELOG.md and changelog.d/ from its
# own location, and a release cut deletes fragments. Running it against this checkout would eat the
# real fragments, so each case copies it into a temp tree with a fixture CHANGELOG.md.
#
# WHY THE LAST CASE RUNS --preview ON THE REAL TREE: it is the only check that the fragments
# committed in this repo are well formed, so a malformed one fails CI in the PR that adds it rather
# than at release time.
set -u

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$REPO_ROOT/tests/helpers/assert.sh"

echo "=== changelog-fragments tests ==="

SCRIPT="$REPO_ROOT/scripts/changelog-assemble.sh"
assert_file_exists "$SCRIPT" "scripts/changelog-assemble.sh exists"
if ! bash -n "$SCRIPT" 2>/dev/null; then
    echo "  FAIL: scripts/changelog-assemble.sh is not valid bash"
    print_summary
    exit 1
fi

TMP_ROOT="$(mktemp -d)"
trap 'rm -rf "$TMP_ROOT"' EXIT

FIXTURE_CHANGELOG='# Changelog

Unreleased notes live in changelog.d/.

## [Unreleased]

## Pending — NOT part of any release

- pending item

## Released history

See docs/archive/.'

# new_tree <name>: a sandbox with the script, the fixture CHANGELOG.md and an empty changelog.d/.
new_tree() {
    local d="$TMP_ROOT/$1"
    mkdir -p "$d/scripts" "$d/changelog.d"
    cp "$SCRIPT" "$d/scripts/"
    printf '%s\n' "$FIXTURE_CHANGELOG" > "$d/CHANGELOG.md"
    printf 'How to write a fragment.\n' > "$d/changelog.d/README.md"
    echo "$d"
}

# Two fragments that between them cover heading order, fragment order within a heading, a heading
# outside Keep a Changelog's set, a wrapped bullet and stray blank lines.
add_fragments() {
    cat > "$1/changelog.d/b-second.md" <<'EOF'
### Documentation
- docs from b

### Added
- added from b
EOF
    cat > "$1/changelog.d/a-first.md" <<'EOF'

### Fixed
- fixed from a, with a bullet that
  wraps onto a second line


### Added
- added from a
EOF
}

EXPECTED_NOTES='### Added
- added from a
- added from b

### Fixed
- fixed from a, with a bullet that
  wraps onto a second line

### Documentation
- docs from b'

echo ""
echo "--- --preview ---"
T="$(new_tree preview-empty)"
OUT="$(bash "$T/scripts/changelog-assemble.sh" --preview 2>&1)"; RC=$?
assert_exit_zero "$RC" "--preview with no fragments exits 0"
assert_contains "$OUT" "no fragments" "--preview with no fragments says so"

T="$(new_tree preview)"
add_fragments "$T"
OUT="$(bash "$T/scripts/changelog-assemble.sh" --preview 2>&1)"; RC=$?
assert_exit_zero "$RC" "--preview with fragments exits 0"
assert_equals "$OUT" "$EXPECTED_NOTES" \
    "--preview merges by heading: Added, Fixed, then others; filename order within a heading"
assert_file_exists "$T/changelog.d/a-first.md" "--preview leaves the fragments in place"
assert_equals "$(cat "$T/CHANGELOG.md")" "$FIXTURE_CHANGELOG" "--preview leaves CHANGELOG.md unchanged"

echo ""
echo "--- release cut ---"
T="$(new_tree cut)"
add_fragments "$T"
OUT="$(bash "$T/scripts/changelog-assemble.sh" 1.4.0 --date 2026-11-01 2>&1)"; RC=$?
assert_exit_zero "$RC" "a release cut exits 0"
assert_equals "$(cat "$T/CHANGELOG.md")" "# Changelog

Unreleased notes live in changelog.d/.

## [Unreleased]

## [1.4.0] - 2026-11-01

$EXPECTED_NOTES

## Pending — NOT part of any release

- pending item

## Released history

See docs/archive/." "the release section lands under an empty [Unreleased], before the next ## section"
assert_file_not_exists "$T/changelog.d/a-first.md" "the cut deletes the folded fragments (a-first.md)"
assert_file_not_exists "$T/changelog.d/b-second.md" "the cut deletes the folded fragments (b-second.md)"
assert_file_exists "$T/changelog.d/README.md" "the cut keeps changelog.d/README.md"

# [Unreleased] as the last section: the release section ends the file with a single newline.
T="$(new_tree cut-eof)"
printf '# Changelog\n\n## [Unreleased]\n' > "$T/CHANGELOG.md"
printf '### Fixed\n- one fix\n' > "$T/changelog.d/x.md"
bash "$T/scripts/changelog-assemble.sh" 2.0.0 --date 2026-11-02 >/dev/null 2>&1; RC=$?
assert_exit_zero "$RC" "a cut with [Unreleased] at end of file exits 0"
# WHY cmp against a printf file: $(cat) strips trailing newlines, so assert_equals cannot see them.
printf '# Changelog\n\n## [Unreleased]\n\n## [2.0.0] - 2026-11-02\n\n### Fixed\n- one fix\n' > "$TMP_ROOT/eof-expected"
cmp -s "$T/CHANGELOG.md" "$TMP_ROOT/eof-expected"
assert_exit_zero "$?" "a cut at end of file writes the section and ends in exactly one newline"

echo ""
echo "--- refusals leave everything untouched ---"
# expect_refusal <tree> <desc> <args...>: nonzero exit, CHANGELOG.md and fragments unchanged.
expect_refusal() {
    local t="$1" desc="$2"; shift 2
    local before frags_before
    before="$(cat "$t/CHANGELOG.md")"
    frags_before="$(ls "$t/changelog.d")"
    bash "$t/scripts/changelog-assemble.sh" "$@" >/dev/null 2>&1
    assert_exit_nonzero "$?" "$desc: refused"
    assert_equals "$(cat "$t/CHANGELOG.md")" "$before" "$desc: CHANGELOG.md unchanged"
    assert_equals "$(ls "$t/changelog.d")" "$frags_before" "$desc: changelog.d/ unchanged"
}

expect_refusal "$(new_tree none)" "a cut with no fragments" 1.4.0

T="$(new_tree dup)"; add_fragments "$T"
printf '%s\n\n## [1.4.0] - 2026-01-01\n' "$FIXTURE_CHANGELOG" > "$T/CHANGELOG.md"
expect_refusal "$T" "a version CHANGELOG.md already has" 1.4.0

T="$(new_tree dirty)"; add_fragments "$T"
printf '%s\n' "$FIXTURE_CHANGELOG" | sed 's/^## \[Unreleased\]$/&\n\n- a hand-written entry/' > "$T/CHANGELOG.md"
expect_refusal "$T" "a non-empty [Unreleased]" 1.4.0

T="$(new_tree badver)"; add_fragments "$T"
expect_refusal "$T" "a version that is not X.Y.Z" 1.4
T="$(new_tree baddate)"; add_fragments "$T"
expect_refusal "$T" "a malformed --date" 1.4.0 --date 2026-1-1
T="$(new_tree mixed)"; add_fragments "$T"
expect_refusal "$T" "--preview combined with a version" --preview 1.4.0

echo ""
echo "--- malformed fragments are named, in --preview too ---"
# expect_bad_fragment <desc> <file name> <content>
expect_bad_fragment() {
    local t out
    t="$(new_tree "bad-$2")"
    printf '%b' "$3" > "$t/changelog.d/$2"
    out="$(bash "$t/scripts/changelog-assemble.sh" --preview 2>&1)"
    assert_exit_nonzero "$?" "$1: --preview fails"
    assert_contains "$out" "changelog.d/$2" "$1: the error names the file"
    expect_refusal "$t" "$1" 1.4.0
}
expect_bad_fragment "text before the first heading" "pre.md" "- orphan bullet\n### Added\n- x\n"
# The ## line comes after a ### heading so that the text-before-heading rule cannot catch it instead.
expect_bad_fragment "a ## heading" "h2.md" "### Added\n- x\n## [9.9.9]\n"
expect_bad_fragment "no heading at all" "empty.md" ""
expect_bad_fragment "a non-.md file" "note.txt" "### Added\n- x\n"

echo ""
echo "--- this repo's own changelog.d/ ---"
OUT="$(bash "$SCRIPT" --preview 2>&1)"
assert_exit_zero "$?" "--preview accepts every fragment committed in changelog.d/ (output: $OUT)"

print_summary
