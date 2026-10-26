#!/usr/bin/env bash
# scripts/changelog-assemble.sh — fold changelog.d/ fragments into a CHANGELOG.md release section.
#
# Usage:
#   bash scripts/changelog-assemble.sh --preview                       print the unreleased notes
#   bash scripts/changelog-assemble.sh <X.Y.Z> [--date YYYY-MM-DD]     cut them into a release
#
# WHY FRAGMENTS: CHANGELOG.md's [Unreleased] was a single insertion point. Every PR added lines at
# its top, so concurrent PRs conflicted there, and the shared context lines changed the push gate's
# diff hash on every sync of main. Each PR now adds its own changelog.d/<branch-slug>.md instead
# (the rule is in standards/WORKFLOW.md, Phase 7), and this script is the only writer of release
# sections. See docs/superpowers/specs/2026-10-23-merge-aware-review-budget-design.md §5.1.
#
# WHY BASH ONLY, AND NOT SHIPPED TO ADOPTERS: this runs once per release, by whoever cuts it, in
# this repo. It is not a hook and never runs on an adopter's machine, so there is no shell parity to
# keep and no PowerShell twin. It is not in templates/ or mb.sh's TEMPLATE_OWNED either: adopters do
# not get the changelog.d/ convention, and nothing in scripts/ or templates/ reads CHANGELOG.md.
#
# A release cut with this script:
#   - merges the fragments by subsection heading, Keep a Changelog headings first in that order
#     (Added, Changed, Deprecated, Removed, Fixed, Security), any other heading after them in
#     first-seen order, and fragments in filename order within a heading;
#   - inserts "## [X.Y.Z] - DATE" directly under "## [Unreleased]", which must be empty;
#   - deletes the fragments it folded (changelog.d/README.md stays).
# It does not bump VERSION, archive older sections (CHANGELOG.md's "Released history" says when),
# or stage anything.
set -euo pipefail
# WHY C collation: the glob below decides fragment order within a heading, and that order must not
# depend on the release-cutter's locale. Not covered by the test suite: proving it needs a non-C
# locale installed on the machine running the tests.
export LC_ALL=C

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CHANGELOG="$ROOT/CHANGELOG.md"
FRAG_DIR="$ROOT/changelog.d"

usage() {
    echo "usage: bash scripts/changelog-assemble.sh --preview" >&2
    echo "       bash scripts/changelog-assemble.sh <X.Y.Z> [--date YYYY-MM-DD]" >&2
    exit 2
}
die() { echo "changelog-assemble: $*" >&2; exit 1; }

PREVIEW=0 VERSION="" DATE=""
while [ $# -gt 0 ]; do
    case "$1" in
        --preview) PREVIEW=1 ;;
        --date) [ $# -ge 2 ] || usage; DATE="$2"; shift ;;
        -*) usage ;;
        *) [ -z "$VERSION" ] || usage; VERSION="$1" ;;
    esac
    shift
done
if [ "$PREVIEW" -eq 1 ]; then
    [ -z "$VERSION" ] && [ -z "$DATE" ] || usage
else
    [[ "$VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || usage
    [ -n "$DATE" ] || DATE="$(date +%Y-%m-%d)"
    [[ "$DATE" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}$ ]] || usage
fi

# WHY anything that is not a .md file is an error rather than skipped: a fragment saved as .txt or
# .markdown would otherwise vanish from the release notes without a word.
FRAGS=()
if [ -d "$FRAG_DIR" ]; then
    for f in "$FRAG_DIR"/*; do
        [ -e "$f" ] || continue
        name="$(basename "$f")"
        case "$name" in
            README.md) ;;
            *.md) FRAGS+=("$f") ;;
            *) die "changelog.d/$name: not a fragment (fragments are changelog.d/<branch-slug>.md)" ;;
        esac
    done
fi

# A fragment is one or more "### Name" headings, each with content under it, and no "#" or "##"
# line: those would split the release section they are pasted into. A nameless heading would lose
# its content in assemble, and an empty one would vanish from it, so both are refused.
# WHY "##?" and not "#{1,2}": mawk 1.3.4 20200120 (Ubuntu 22.04, Debian 12) reads the interval
# braces as literal text, which let a ## line through in review.
# WHY strip \r: Git Bash's awk drops it and a Linux awk keeps it, and a kept \r defeats every
# end-of-line pattern below. Committed fragments are LF (.gitattributes), so this only matters for an
# uncommitted one.
for f in "${FRAGS[@]+"${FRAGS[@]}"}"; do
    err="$(awk '
        # exit still runs END, which therefore checks "failed" before reporting anything itself.
        function fail(msg) { print msg; failed = 1; exit }
                          { sub(/\r$/, "") }
        /^##?([ \t]|$)/   { fail("line " NR ": only ### headings belong in a fragment (even inside a code fence)") }
        /^###[ \t]*$/     { fail("line " NR ": ### heading has no name") }
        /^###\t/          { fail("line " NR ": put a space, not a tab, after ###") }
        /^### / {
            if (seen && !content) fail("line " head ": ### heading has nothing under it")
            seen = 1; content = 0; head = NR; next
        }
        /^[ \t]*$/        { next }
        !seen             { fail("line " NR ": text before the first ### heading") }
        # Any other line is content under the current heading.
                          { content = 1 }
        END {
            if (failed) exit
            if (!seen) print "no ### heading"
            else if (!content) print "line " head ": ### heading has nothing under it"
        }
    ' "$f")"
    [ -z "$err" ] || die "changelog.d/$(basename "$f"): $err"
done

# Print the merged notes: one "### Heading" block per heading, each followed by a blank line.
assemble() {
    awk '
        BEGIN {
            n = split("Added Changed Deprecated Removed Fixed Security", std, " ")
            for (i = 1; i <= n; i++) order[i] = std[i]
            norder = n
            for (i = 1; i <= n; i++) known[std[i]] = 1
        }
        # Flush the lines buffered under one heading of one fragment, minus leading and trailing
        # blank lines, so fragments join with no gap and interior blank lines survive.
        function flush(   first, last, i, chunk) {
            if (cur == "") return
            first = 1; while (first <= nbuf && buf[first] ~ /^[ \t]*$/) first++
            last = nbuf; while (last >= first && buf[last] ~ /^[ \t]*$/) last--
            chunk = ""
            for (i = first; i <= last; i++) chunk = chunk (chunk == "" ? "" : "\n") buf[i]
            if (chunk != "") body[cur] = body[cur] (body[cur] == "" ? "" : "\n") chunk
            nbuf = 0
        }
        { sub(/\r$/, "") }
        FNR == 1 { flush(); cur = "" }
        /^### / {
            flush()
            cur = substr($0, 5); sub(/[ \t]+$/, "", cur)
            if (!(cur in known) && !(cur in extra)) { extra[cur] = 1; order[++norder] = cur }
            next
        }
        cur != "" { buf[++nbuf] = $0 }
        END {
            flush()
            for (i = 1; i <= norder; i++) {
                h = order[i]
                if (body[h] != "") printf "### %s\n%s\n\n", h, body[h]
            }
        }
    ' "${FRAGS[@]}"
}

if [ "$PREVIEW" -eq 1 ]; then
    if [ "${#FRAGS[@]}" -eq 0 ]; then
        echo "No unreleased notes: changelog.d/ holds no fragments."
    else
        assemble
    fi
    exit 0
fi

[ "${#FRAGS[@]}" -gt 0 ] || die "changelog.d/ holds no fragments; there is nothing to release"
[ -f "$CHANGELOG" ] || die "CHANGELOG.md not found at $CHANGELOG"
[ "$(grep -c '^## \[Unreleased\][[:space:]]*$' "$CHANGELOG")" -eq 1 ] \
    || die "CHANGELOG.md must have exactly one '## [Unreleased]' heading"
! grep -qF "## [$VERSION]" "$CHANGELOG" || die "CHANGELOG.md already has a [$VERSION] section"

SECTION="$(mktemp)"
NEW="$CHANGELOG.tmp.$$"
trap 'rm -f "$SECTION" "$NEW"' EXIT
{ printf '## [%s] - %s\n\n' "$VERSION" "$DATE"; assemble; } > "$SECTION"

# WHY [Unreleased] must be empty: under this convention nothing writes there, so an entry in it is
# either a PR that missed the rule or a hand edit. Folding it in silently would guess at its order;
# refusing lets whoever cuts the release move it into a fragment and run again.
awk -v section="$SECTION" '
    # The section file ends in a blank line (assemble ends every block with one). Keep it as the
    # separator before the next "## " heading; drop it at end of file.
    function emit_section(at_eof,   line, n, i) {
        print ""
        n = 0
        while ((getline line < section) > 0) lines[++n] = line
        close(section)
        if (at_eof) while (n > 0 && lines[n] == "") n--
        for (i = 1; i <= n; i++) print lines[i]
    }
    in_unrel && /^## / { emit_section(0); in_unrel = 0 }
    in_unrel && /^[ \t]*$/ { next }
    in_unrel { bad = 1; exit 1 }
    /^## \[Unreleased\][ \t]*$/ { print; in_unrel = 1; next }
    { print }
    END {
        if (bad) exit 1
        if (in_unrel) emit_section(1)
    }
' "$CHANGELOG" > "$NEW" \
    || die "CHANGELOG.md's [Unreleased] section has entries; move them into a changelog.d/ fragment first"

# WHY check the result rather than trust the guards above: the heading count is grep and the
# insertion is awk, and the two can disagree. Found in review, without this check: with a CRLF
# CHANGELOG.md under mawk, grep's [[:space:]] matches the \r and awk's [ \t] does not, so awk passes
# the file through unchanged, and the fragments are then deleted with their notes written nowhere.
grep -qF "## [$VERSION] - $DATE" "$NEW" \
    || die "could not find where to insert the section (CRLF line endings?); CHANGELOG.md and changelog.d/ are unchanged"

mv "$NEW" "$CHANGELOG"
rm -f "${FRAGS[@]}" \
    || die "CHANGELOG.md now has [$VERSION], but some fragments could not be deleted. Delete the fragment files still in changelog.d/ by hand (keep README.md); do not re-run, which would fold them in again"

echo "Folded ${#FRAGS[@]} fragment(s) into CHANGELOG.md as [$VERSION] - $DATE."
echo "Next: review CHANGELOG.md, archive old sections if it nears the size cap (see 'Released history'),"
echo "bump VERSION, and stage CHANGELOG.md and changelog.d/."
