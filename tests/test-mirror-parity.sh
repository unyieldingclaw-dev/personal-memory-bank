#!/usr/bin/env bash
# tests/test-mirror-parity.sh — the .cursor/rules governance substrate must not drift from templates/
#
# WHY this file exists: `.cursor/rules/*.mdc` is TEMPLATE_OWNED (scripts/mb.sh, TEMPLATE_OWNED array),
# meaning `mb upgrade` overwrites the live copy from `templates/cursor/rules/` unconditionally. So the
# template is the authoritative artifact and the live copy is a build product. Nothing verified they
# agreed: a grep across tests/ and .github/workflows/ for "cursor" returned zero hits before this file
# existed. That gap let a stale rule ship to every adopter with no signal, and it is the same class of
# defect that has already bitten `dangerous-commands` (fix landed in scripts/ but not templates/) and
# `pre-compact-check` (7de75e6, template left behind on a bash optimization).
#
# WHY auto-discovery instead of a hardcoded list of the six rule files: a hand-maintained list would
# repeat the stale-hardcoded-list bug this repo has shipped twice — `ADVISORY_DIFF` hardcoded two agent
# paths so `mb upgrade` would never have delivered a new agent, itself a repeat of the slash-command
# list bug documented in 1.2.0. tests/run.sh carries a completeness check for the same reason.
# Discovering from the filesystem means a rule file added later is covered for free.
#
# WHY the check runs in BOTH directions, stated precisely: a live `.mdc` with no template behind it is
# NOT deleted by `mb upgrade` — that loop only creates or updates, and TEMPLATE_OWNED is a fixed array
# of six target paths, so an unlisted orphan is never visited at all. The real hazard is subtler: such
# a file is invisible to and unmanaged by `mb upgrade`, so it silently persists in this repo, never
# ships to adopters, and drifts from the governance substrate forever with nothing reporting it.
# (An earlier draft claimed `mb upgrade` "would silently delete" it. False, and caught in review.
# A follow-up round then found the correction itself was over-broad: both shells DO contain delete
# paths elsewhere — cache/backup cleanup, a one-time git-hook migration — so the accurate claim is
# narrow, that no delete path reaches a `.cursor/rules` orphan. Corrected twice rather than quietly
# dropped, because the assertion text below prints on every run and a future maintainer would read
# whatever it says as fact.)
set -u

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$REPO_ROOT/tests/helpers/assert.sh"

LIVE_DIR="$REPO_ROOT/.cursor/rules"
TMPL_DIR="$REPO_ROOT/templates/cursor/rules"

echo "=== mirror parity: .cursor/rules vs templates/cursor/rules ==="
echo ""

# ── every template has a live counterpart, and it is byte-identical ─────────────────────────
# WHY assert_file_exists rather than a literal-pair assert_contains: the helper tests the real
# filesystem condition. A hardcoded pair like assert_contains "backed" "backed" cannot fail for any
# state on disk — it only reports which branch an enclosing `if` already chose. That construct is
# behaviourally correct but reads as a tautology, and standards/CODE-REVIEW.md's Evidence Integrity
# rule ("a check that cannot fail does not count as a check") is the reason this file exists at all.
echo "--- templates/cursor/rules/*.mdc -> .cursor/rules/ ---"
tmpl_count=0
for tmpl in "$TMPL_DIR"/*.mdc; do
    [ -e "$tmpl" ] || continue
    tmpl_count=$((tmpl_count + 1))
    name="$(basename "$tmpl")"
    live="$LIVE_DIR/$name"
    assert_file_exists "$live" "$name: template has a live counterpart"
    if [ -f "$live" ]; then
        diff -q "$tmpl" "$live" >/dev/null 2>&1
        assert_exit_zero "$?" "$name: template and live copy are byte-identical"
    fi
done

# WHY assert the sweep found something: if TMPL_DIR is moved or renamed, the loop above iterates zero
# times and every assertion silently disappears — a suite that passes because it tested nothing. The
# comparison below is a real arithmetic test, not a literal compared against itself.
echo ""
echo "--- the sweep actually ran ---"
[ "$tmpl_count" -gt 0 ]
assert_exit_zero "$?" "templates/cursor/rules/ contained at least one .mdc to compare (found $tmpl_count)"

# ── every live file has a template behind it ────────────────────────────────────────────────
echo ""
echo "--- .cursor/rules/*.mdc -> templates/cursor/rules/ ---"
for live in "$LIVE_DIR"/*.mdc; do
    [ -e "$live" ] || continue
    name="$(basename "$live")"
    assert_file_exists "$TMPL_DIR/$name" \
        "$name: live rule has a template behind it (an orphan is unmanaged by mb upgrade, never ships)"
done

print_summary
