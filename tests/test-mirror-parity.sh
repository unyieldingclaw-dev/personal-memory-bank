#!/usr/bin/env bash
# tests/test-mirror-parity.sh — the governance substrate must not drift from templates/
#
# THREE pairs, two different rules: .cursor/rules and .claude/commands are STRICT byte-identity;
# standards/ is allowlisted because three files diverge by design. See each block's own WHY.
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

# ── .claude/commands/*.md vs templates/claude-commands/*.md ─────────────────────────────────
# WHY a THIRD pair, and why it is strict-identity like .cursor/rules rather than allowlisted like
# standards/: measured 2026-08-31, all 8 pairs are byte-identical and none diverges by design. The
# live copies carry no repo-specific content, so there is nothing to genericize for adopters.
#
# WHY it is TEMPLATE_OWNED, by a DIFFERENT route than .cursor/rules -- the distinction matters and an
# imprecise version of it would be wrong: the cursor rules are six literal paths in the TEMPLATE_OWNED
# array, whereas commands are AUTO-DISCOVERED into it (scripts/mb.sh, the loop appending
# ".claude/commands/$(basename "$f")" for each templates/claude-commands/*). So the array contains
# exactly those commands that HAVE a template. Two consequences, and they differ:
#   - A live orphan (no template behind it) is therefore NEVER in the array, never visited by
#     `mb upgrade`, and no delete path reaches it. It persists in this repo, never ships to adopters,
#     and drifts from the shipped substrate forever with nothing reporting it. Same hazard as the
#     cursor orphan case, reached by a different mechanism.
#   - A template with no live copy is self-healing: it IS in the array, so upgrade creates it. Still
#     asserted, because an in-repo divergence is a signal regardless of whether upgrade would repair
#     it, and because this suite runs against this repo, not against a freshly upgraded adopter.
#
# WHY this gap existed until 2026-08-31: it was found by editing change-review.md's exit-code table in
# BOTH copies by hand and then asking what enforced that -- nothing did. The file above states the
# TEMPLATE_OWNED rationale for .cursor/rules and it applies verbatim here; the guard was simply never
# extended to the sibling family. That is this repo's recurring defect class (a fix reaching one
# sibling and not the other), caught this time before it shipped rather than after.
#
# WHY the glob is `*` and not `*.md`, corrected 2026-08-31 before this shipped: the first draft
# globbed `*.md` while the mechanism above globs `*`. Four independent review domains caught it and
# it was mutation-proved invisible -- a `helper.txt` added to templates/claude-commands/ left the
# suite green while mb.sh's own discovery loop put it in TEMPLATE_OWNED, i.e. it would ship and
# force-overwrite at every adopter with this guard reporting PASS. **The guarded set must be derived
# the same way as the overwritten set, or the guard is narrower than the thing it guards.** The
# `.cursor/rules` block above does not hit it TODAY, but for a weaker reason than symmetry: its
# TEMPLATE_OWNED entries are six literal `.mdc` paths that happen to coincide with the directory's
# current contents. The derivations still differ (literal array vs directory glob), so the sets agree
# by CONTENT, not by CONSTRUCTION -- and the failure runs the other way: a seventh `.mdc` added to both
# directories by hand passes this test and is never in TEMPLATE_OWNED, so `mb upgrade` never ships it.
# Nothing ties that array to that directory. Unguarded, and out of scope here.
#
# SCOPE OF THE MATCH, stated precisely: the TEMPLATE side matches `mb.sh`'s discovery exactly. It does
# NOT match `mb.ps1`, whose `Get-ChildItem -File -Filter '*'` also returns dotfiles that bash `*` skips
# -- so a committable dotfile (`.gitkeep`, `.editorconfig`) would ship to pwsh adopters with this guard
# green. Pre-existing and untouched here. The LIVE side is an orphan check and is deliberately broader
# than any discovery loop: neither shell ever enumerates `.claude/commands/`.
#
# NOTE the directory names are NOT symmetric: templates/claude-commands/ -> .claude/commands/.
# scripts/mb.sh maps this explicitly; a naive derivation that assumes matching path segments breaks.
CMD_LIVE="$REPO_ROOT/.claude/commands"
CMD_TMPL="$REPO_ROOT/templates/claude-commands"

echo ""
echo "=== mirror parity: .claude/commands vs templates/claude-commands ==="
echo ""
echo "--- templates/claude-commands/* -> .claude/commands/ ---"
cmd_count=0
for tmpl in "$CMD_TMPL"/*; do
    [ -f "$tmpl" ] || continue
    cmd_count=$((cmd_count + 1))
    name="$(basename "$tmpl")"
    live="$CMD_LIVE/$name"
    assert_file_exists "$live" "$name: command template has a live counterpart"
    if [ -f "$live" ]; then
        diff -q "$tmpl" "$live" >/dev/null 2>&1
        assert_exit_zero "$?" "$name: command template and live copy are byte-identical"
    fi
done

# Same anti-tautology guard as the pair above: if CMD_TMPL is renamed or emptied the loop iterates
# zero times and every assertion in it vanishes silently, leaving a suite that passes on nothing.
echo ""
echo "--- the sweep actually ran ---"
[ "$cmd_count" -gt 0 ]
assert_exit_zero "$?" "templates/claude-commands/ contained at least one file to compare (found $cmd_count)"

echo ""
echo "--- .claude/commands/* -> templates/claude-commands/ ---"
for live in "$CMD_LIVE"/*; do
    [ -f "$live" ] || continue
    name="$(basename "$live")"
    assert_file_exists "$CMD_TMPL/$name"         "$name: live command has a template behind it (an orphan is never in TEMPLATE_OWNED, never ships)"
done

# ── standards/*.md vs templates/standards/*.md ──────────────────────────────────────────────
# WHY this is a SECOND pair with DIFFERENT rules, not an extension of the loop above: unlike
# .cursor/rules, standards/ is NOT byte-identical by design. Three files deliberately diverge --
# the live copies name this repo's own paths, incidents and dates, while the shipped templates are
# genericized for adopters (templates/standards/MEMORY-BANK.md even says so in-line: "PMB's own
# copy of this rule names pmb-health.yml"). A naive cmp-all guard would be wrong as written, which
# is exactly why no check existed: the easy version was known-wrong and the correct one was never
# built. Meanwhile the other 12 pairs drifted with nothing watching.
#
# THE ALLOWLIST IS THE DANGEROUS PART. An allowlist that silently grows swallows the check it is
# attached to, so it carries its own anti-rot guard below: each entry must ACTUALLY still diverge.
# If a file is reconciled later, its stale entry turns this RED and must be deleted -- the
# allowlist cannot quietly accumulate permission for pairs that no longer need it.
STD_LIVE="$REPO_ROOT/standards"
STD_TMPL="$REPO_ROOT/templates/standards"
STD_DIVERGE_OK="AGENTIC-SAFETY.md MEMORY-BANK.md WORKFLOW.md"

echo ""
echo "=== mirror parity: standards vs templates/standards ==="
echo ""
echo "--- non-allowlisted pairs must be byte-identical ---"
std_count=0
for live in "$STD_LIVE"/*.md; do
    [ -e "$live" ] || continue
    name="$(basename "$live")"
    case " $STD_DIVERGE_OK " in *" $name "*) continue ;; esac
    std_count=$((std_count + 1))
    assert_file_exists "$STD_TMPL/$name" "$name: standard has a template behind it"
    if [ -f "$STD_TMPL/$name" ]; then
        diff -q "$live" "$STD_TMPL/$name" >/dev/null 2>&1
        assert_exit_zero "$?" "$name: live and template are byte-identical"
    fi
done

echo ""
echo "--- the sweep actually ran ---"
[ "$std_count" -gt 0 ]
assert_exit_zero "$?" "standards/ contained at least one non-allowlisted pair to compare (found $std_count)"

# Anti-rot: an allowlist entry for a pair that no longer diverges is stale permission. Assert each
# one still earns its place, so reconciling a file forces its removal instead of leaving a hole.
echo ""
echo "--- every allowlisted divergence is still a real divergence ---"
for name in $STD_DIVERGE_OK; do
    assert_file_exists "$STD_TMPL/$name" "$name: allowlisted file still has a template"
    if [ -f "$STD_TMPL/$name" ] && [ -f "$STD_LIVE/$name" ]; then
        diff -q "$STD_LIVE/$name" "$STD_TMPL/$name" >/dev/null 2>&1
        assert_exit_nonzero "$?" "$name: allowlist entry still needed (files genuinely differ)"
    fi
done

# ── the rest of TEMPLATE_OWNED: hook scripts, git hooks, settings.json ──────────────────
# WHY this block exists: the three families above cover .cursor/rules, .claude/commands and
# standards/ -- but mb.sh's TEMPLATE_OWNED array is far larger, and everything in it is
# force-overwritten by `mb upgrade` with no prompt. Measured 2026-09-02: .claude/settings.json and
# delegation-depth-check.{sh,ps1} had ALL diverged from their templates while sitting in that array,
# so an upgrade would have silently reverted a live `pwsh` hook fix and a corrected spawn budget.
# Nothing detected it, because this file guarded three families and the array spans five:
# `.cursor/rules`, `.claude/commands` (appended by the discovery loop), `.claude/settings.json`,
# `scripts/`, and `.githooks/`. The first two were covered; the last three were not.
#
# WHY the list is DERIVED from mb.sh rather than written out here: this file already learned that
# lesson one family over -- "the guarded set must be derived the same way as the overwritten set, or
# the guard is narrower than the thing it guards." A hand-copied list would drift the moment someone
# adds an entry to the array, which is exactly the failure being fixed.
echo ""
echo "--- TEMPLATE_OWNED (derived from scripts/mb.sh) -> templates/ ---"
MB_SH="$REPO_ROOT/scripts/mb.sh"
# Literal entries only: the .claude/commands/* members are appended by a discovery loop and are
# already covered by the command-mirror block above.
TO_LIST=$(sed -n '/TEMPLATE_OWNED=(/,/^    )/p' "$MB_SH" | grep -oE '"[^"]+"' | tr -d '"')
to_count=0
for target in $TO_LIST; do
    case "$target" in
        .cursor/rules/*)   continue ;;  # covered above
        .claude/commands/*) continue ;; # covered above
        .claude/settings.json) continue ;; # hook-wiring compared separately below
    esac
    tmpl="$REPO_ROOT/templates/$target"
    live="$REPO_ROOT/$target"
    to_count=$((to_count + 1))
    assert_file_exists "$tmpl" "$target: template exists behind a TEMPLATE_OWNED entry"
    if [ -f "$tmpl" ] && [ -f "$live" ]; then
        diff -q "$live" "$tmpl" >/dev/null 2>&1
        assert_exit_zero "$?" "$target: live and template are byte-identical (mb upgrade overwrites this)"
    fi
done
[ "$to_count" -gt 0 ]
assert_exit_zero "$?" "TEMPLATE_OWNED sweep derived at least one entry from mb.sh (found $to_count)"

# WHY settings.json is compared on HOOK WIRING ONLY, not byte-identity: the file carries two kinds
# of content under one TEMPLATE_OWNED entry. The hooks block IS the deterministic enforcement wiring
# and must match -- a divergence there is how the live `pwsh -NonInteractive` fix nearly got reverted
# to a `powershell` invocation that does not exist off Windows. The permissions block is genuinely
# project-specific (this repo allows its own test runner and linters), and forcing this repo's
# broader grants onto every adopter would widen their agent's authority without their say. That
# split is the real defect -- one TEMPLATE_OWNED file holding both machine-owned and project-owned
# content -- and it is tracked, not fixed here. Comparing the `"command":` lines pins the half that
# must not drift without pretending the other half should match.
echo ""
echo "--- .claude/settings.json: hook wiring must match (permissions deliberately may not) ---"
SJ_LIVE="$REPO_ROOT/.claude/settings.json"
SJ_TMPL="$REPO_ROOT/templates/.claude/settings.json"
assert_file_exists "$SJ_TMPL" "settings.json: template exists"
if [ -f "$SJ_LIVE" ] && [ -f "$SJ_TMPL" ]; then
    sj_live_cmds=$(grep -c '"command":' "$SJ_LIVE" 2>/dev/null || printf '0')
    [ "$sj_live_cmds" -gt 0 ]
    assert_exit_zero "$?" "settings.json: live file declares at least one hook command ($sj_live_cmds)"
    diff <(grep '"command":' "$SJ_LIVE") <(grep '"command":' "$SJ_TMPL") >/dev/null 2>&1
    assert_exit_zero "$?" "settings.json: hook command wiring identical between live and template"
fi

print_summary
