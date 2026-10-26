#!/usr/bin/env bash
# tests/test-changelog-fragments.sh — scripts/changelog-assemble.sh and the changelog.d/ fragments
#
# WHY A COPY OF THE SCRIPT IN A SANDBOX: the script resolves CHANGELOG.md and changelog.d/ from its
# own location, and a release cut deletes fragments. Running it against this checkout would eat the
# real fragments, so each case copies it into a temp tree with a fixture CHANGELOG.md.
#
# WHY THE LAST CASES READ THE REAL TREE: they are the only checks that the fragments committed in
# this repo are well formed and that CHANGELOG.md's [Unreleased] is still there and empty, so a PR
# that breaks either fails CI itself rather than surfacing at release time.
#
# WHY EVERY REFUSAL NAMES ITS REASON: several guards can refuse the same input (the final insert
# check also catches a missing [Unreleased]), so a refusal alone cannot show which guard fired.
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

# Without --date the section is dated today; only the shape is asserted, so the test cannot race
# midnight.
T="$(new_tree cut-today)"
printf '### Fixed\n- one fix\n' > "$T/changelog.d/x.md"
bash "$T/scripts/changelog-assemble.sh" 1.5.0 >/dev/null 2>&1; RC=$?
assert_exit_zero "$RC" "a cut without --date exits 0"
grep -qE '^## \[1\.5\.0\] - [0-9]{4}-[0-9]{2}-[0-9]{2}$' "$T/CHANGELOG.md"
assert_exit_zero "$?" "a cut without --date dates the section YYYY-MM-DD"

echo ""
echo "--- refusals leave everything untouched ---"
# expect_refusal <tree> <desc> <reason> <args...>: nonzero exit, an error containing <reason>, and
# CHANGELOG.md and the fragments unchanged.
expect_refusal() {
    local t="$1" desc="$2" reason="$3"; shift 3
    local before frags_before err
    before="$(cat "$t/CHANGELOG.md")"
    frags_before="$(ls "$t/changelog.d")"
    err="$(bash "$t/scripts/changelog-assemble.sh" "$@" 2>&1 >/dev/null)"
    assert_exit_nonzero "$?" "$desc: refused"
    assert_contains "$err" "$reason" "$desc: the error says '$reason'"
    assert_equals "$(cat "$t/CHANGELOG.md")" "$before" "$desc: CHANGELOG.md unchanged"
    assert_equals "$(ls "$t/changelog.d")" "$frags_before" "$desc: changelog.d/ unchanged"
}

expect_refusal "$(new_tree none)" "a cut with no fragments" "no fragments" 1.4.0

T="$(new_tree dup)"; add_fragments "$T"
printf '%s\n\n## [1.4.0] - 2026-01-01\n' "$FIXTURE_CHANGELOG" > "$T/CHANGELOG.md"
expect_refusal "$T" "a version CHANGELOG.md already has" "already has" 1.4.0

T="$(new_tree dirty)"; add_fragments "$T"
printf '%s\n' "$FIXTURE_CHANGELOG" | sed 's/^## \[Unreleased\]$/&\n\n- a hand-written entry/' > "$T/CHANGELOG.md"
expect_refusal "$T" "a non-empty [Unreleased]" "has entries" 1.4.0

T="$(new_tree no-unrel)"; add_fragments "$T"
printf '%s\n' "$FIXTURE_CHANGELOG" | grep -v '^## \[Unreleased\]$' > "$T/CHANGELOG.md"
expect_refusal "$T" "a CHANGELOG.md with no [Unreleased] heading" "exactly one" 1.4.0

T="$(new_tree two-unrel)"; add_fragments "$T"
printf '%s\n\n## [Unreleased]\n' "$FIXTURE_CHANGELOG" > "$T/CHANGELOG.md"
expect_refusal "$T" "a CHANGELOG.md with two [Unreleased] headings" "exactly one" 1.4.0

# WHY CRLF gets its own case: see the comment above the insert check in the script. Git Bash's awk
# strips the \r and succeeds; a Linux awk keeps it and must refuse. Either is accepted here; losing
# the notes is not.
T="$(new_tree crlf)"; add_fragments "$T"
printf '%s\n' "$FIXTURE_CHANGELOG" | sed 's/$/\r/' > "$T/CHANGELOG.md"
BEFORE="$(cat "$T/CHANGELOG.md")"
ERR="$(bash "$T/scripts/changelog-assemble.sh" 1.4.0 --date 2026-11-01 2>&1 >/dev/null)"; RC=$?
if [ "$RC" -eq 0 ]; then
    grep -q "added from b" "$T/CHANGELOG.md"
else
    case "$ERR" in *"could not find where"*) ;; *) false ;; esac \
        && [ "$(cat "$T/CHANGELOG.md")" = "$BEFORE" ] \
        && [ -f "$T/changelog.d/a-first.md" ] && [ -f "$T/changelog.d/b-second.md" ]
fi
assert_exit_zero "$?" "a CRLF CHANGELOG.md either gets the notes or is refused untouched (rc $RC)"

T="$(new_tree badver)"; add_fragments "$T"
expect_refusal "$T" "a version that is not X.Y.Z" "usage" 1.4
T="$(new_tree baddate)"; add_fragments "$T"
expect_refusal "$T" "a malformed --date" "usage" 1.4.0 --date 2026-1-1
T="$(new_tree mixed)"; add_fragments "$T"
expect_refusal "$T" "--preview combined with a version" "usage" --preview 1.4.0

echo ""
echo "--- malformed fragments are named, in --preview too ---"
# expect_bad_fragment <desc> <file name> <reason> <content>
expect_bad_fragment() {
    local t out
    t="$(new_tree "bad-$2")"
    printf '%b' "$4" > "$t/changelog.d/$2"
    out="$(bash "$t/scripts/changelog-assemble.sh" --preview 2>&1)"
    assert_exit_nonzero "$?" "$1: --preview fails"
    assert_contains "$out" "changelog.d/$2" "$1: the error names the file"
    expect_refusal "$t" "$1" "$3" 1.4.0
}
expect_bad_fragment "text before the first heading" "pre.md" "text before" "- orphan bullet\n### Added\n- x\n"
# The # and ## lines come after a ### heading so that the text-before-heading rule cannot catch
# them instead.
expect_bad_fragment "a ## heading" "h2.md" "only ### headings" "### Added\n- x\n## [9.9.9]\n"
expect_bad_fragment "a # heading" "h1.md" "only ### headings" "### Added\n- x\n# Title\n"
expect_bad_fragment "a bare ## line" "h2-bare.md" "only ### headings" "### Added\n- x\n##\n"
expect_bad_fragment "a nameless ### heading" "noname.md" "no name" "### \n- orphan\n### Added\n- x\n"
expect_bad_fragment "a bare ### line" "bare3.md" "no name" "### Added\n- x\n###\n- y\n"
expect_bad_fragment "a tab after ###" "tab.md" "not a tab" "### Added\n- x\n###\tFixed\n- y\n"
expect_bad_fragment "a heading with nothing under it, mid-file" "hollow-mid.md" "line 1: ### heading has nothing" "### Added\n\n### Fixed\n- x\n"
expect_bad_fragment "a heading with nothing under it, at the end" "hollow-end.md" "line 1: ### heading has nothing" "### Added\n"
# The empty heading follows a filled one, so the per-heading reset is what catches it.
expect_bad_fragment "an empty heading after a filled one" "hollow-late.md" "line 3: ### heading has nothing" "### Added\n- x\n### Fixed\n"
expect_bad_fragment "no heading at all" "empty.md" "no ### heading" ""
expect_bad_fragment "a non-.md file" "note.txt" "not a fragment" "### Added\n- x\n"

echo ""
echo "--- line endings ---"
# A CRLF fragment must merge with an LF one under the same heading, and must not carry \r through.
T="$(new_tree crlf-frag)"
printf '### Added\r\n- crlf bullet\r\n' > "$T/changelog.d/a-crlf.md"
printf '### Added\n- lf bullet\n' > "$T/changelog.d/b-lf.md"
OUT="$(bash "$T/scripts/changelog-assemble.sh" --preview 2>&1)"; RC=$?
assert_exit_zero "$RC" "--preview accepts a CRLF fragment"
assert_equals "$OUT" "### Added
- crlf bullet
- lf bullet" "a CRLF fragment merges with an LF one under one heading, with no \\r left"
# A kept \r would stop the end-of-line alternative in the ## rule from matching a bare "##".
expect_bad_fragment "a bare ## line in a CRLF fragment" "crlf-h2.md" "only ### headings" "### Added\r\n- x\r\n##\r\n"

echo ""
echo "--- this repo's own changelog.d/ ---"
OUT="$(bash "$SCRIPT" --preview 2>&1)"
assert_exit_zero "$?" "--preview accepts every fragment committed in changelog.d/ (output: $OUT)"
# WHY: a PR that edits or renames [Unreleased] out of habit would otherwise surface only at release
# time, when the cut refuses. This makes it fail in that PR's own CI run. The heading count comes
# first because the emptiness check alone passes when the heading is gone.
assert_equals "$(grep -c '^## \[Unreleased\][[:space:]]*$' "$REPO_ROOT/CHANGELOG.md")" "1" \
    "CHANGELOG.md has exactly one '## [Unreleased]' heading"
UNREL="$(awk '/^## \[Unreleased\]/ { on = 1; next } on && /^## / { exit } on && NF { print }' "$REPO_ROOT/CHANGELOG.md")"
assert_equals "$UNREL" "" "CHANGELOG.md's [Unreleased] is empty (entries belong in changelog.d/)"

print_summary
