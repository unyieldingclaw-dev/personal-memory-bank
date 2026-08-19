#!/usr/bin/env bash
# tests/test-mb-backlog.sh — regression test for the mb backlog command family
#
# WHY this test exists: proves add/list/show/promote/dismiss all behave as designed
# in docs/superpowers/specs/2026-07-14-backlog-design.md — slug generation and
# collision handling, default list excludes promoted/dismissed, promote seeds a
# .claude/plans/ stub without touching docs/plans/, dismiss/promote never delete
# the backlog file (audit trail).
set -u

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$REPO_ROOT/tests/helpers/assert.sh"
source "$REPO_ROOT/tests/setup.sh"

echo "=== mb backlog tests ==="

MB="$REPO_ROOT/scripts/mb.sh"

# WHY a single array + single EXIT trap: `trap ... EXIT` occupies one slot —
# each subsequent `trap` call overwrites the previous handler instead of
# stacking, so five separate per-block traps would leak four of the five
# tmpdirs. Registering once here and appending to the array in each block
# ensures every tmpdir actually gets cleaned up.
ALL_TMPDIRS=()
trap 'rm -rf "${ALL_TMPDIRS[@]}"' EXIT

# ── add: creates a file with correct frontmatter and slug ───────────────────
echo ""
echo "--- add: creates docs/backlog/<slug>.md with correct frontmatter ---"
TMPDIR_ADD="$(mktemp -d 2>/dev/null || mktemp -d -t mb-bl-test)"
ALL_TMPDIRS+=("$TMPDIR_ADD")
setup_test_project "$TMPDIR_ADD"
cd "$TMPDIR_ADD" || exit 1
output=$(bash "$MB" backlog add "Investigate Foo Bar" "A short description" 2>&1)
cd - > /dev/null || exit 1
assert_file_exists "$TMPDIR_ADD/docs/backlog/investigate-foo-bar.md" "mb backlog add: creates slugged file"
content=$(cat "$TMPDIR_ADD/docs/backlog/investigate-foo-bar.md")
assert_contains "$content" "status: open" "mb backlog add: status defaults to open"
assert_contains "$content" "staleness-threshold: 90d" "mb backlog add: staleness-threshold defaults to 90d"
assert_contains "$content" "related_plan: null" "mb backlog add: related_plan defaults to null"
assert_contains "$content" "# Investigate Foo Bar" "mb backlog add: body has title as H1"
assert_contains "$content" "A short description" "mb backlog add: body includes description"

# ── add: slug collision gets a numeric suffix ────────────────────────────────
echo ""
echo "--- add: slug collision appends -2 ---"
TMPDIR_COLLIDE="$(mktemp -d 2>/dev/null || mktemp -d -t mb-bl-test)"
ALL_TMPDIRS+=("$TMPDIR_COLLIDE")
setup_test_project "$TMPDIR_COLLIDE"
cd "$TMPDIR_COLLIDE" || exit 1
bash "$MB" backlog add "Same Title" > /dev/null 2>&1
output=$(bash "$MB" backlog add "Same Title" 2>&1)
cd - > /dev/null || exit 1
assert_file_exists "$TMPDIR_COLLIDE/docs/backlog/same-title.md" "mb backlog add: first item gets bare slug"
assert_file_exists "$TMPDIR_COLLIDE/docs/backlog/same-title-2.md" "mb backlog add: second item with same title gets -2 suffix"

# ── list: shows open items, excludes promoted/dismissed by default ──────────
echo ""
echo "--- list: shows open items only by default ---"
TMPDIR_LIST="$(mktemp -d 2>/dev/null || mktemp -d -t mb-bl-test)"
ALL_TMPDIRS+=("$TMPDIR_LIST")
setup_test_project "$TMPDIR_LIST"
cd "$TMPDIR_LIST" || exit 1
bash "$MB" backlog add "Open Item" > /dev/null 2>&1
bash "$MB" backlog add "Dismissed Item" > /dev/null 2>&1
bash "$MB" backlog dismiss dismissed-item > /dev/null 2>&1
output=$(bash "$MB" backlog list 2>&1)
cd - > /dev/null || exit 1
assert_contains "$output" "open-item" "mb backlog list: shows open items"
assert_not_contains "$output" "dismissed-item" "mb backlog list: excludes dismissed items by default"

echo ""
echo "--- list --all: shows dismissed items too ---"
cd "$TMPDIR_LIST" || exit 1
output=$(bash "$MB" backlog list --all 2>&1)
cd - > /dev/null || exit 1
assert_contains "$output" "dismissed-item" "mb backlog list --all: includes dismissed items"

# ── show: prints one item's full content ─────────────────────────────────────
echo ""
echo "--- show: prints the item's content ---"
TMPDIR_SHOW="$(mktemp -d 2>/dev/null || mktemp -d -t mb-bl-test)"
ALL_TMPDIRS+=("$TMPDIR_SHOW")
setup_test_project "$TMPDIR_SHOW"
cd "$TMPDIR_SHOW" || exit 1
bash "$MB" backlog add "Showable Item" "Detail text here" > /dev/null 2>&1
output=$(bash "$MB" backlog show showable-item 2>&1)
cd - > /dev/null || exit 1
assert_contains "$output" "Detail text here" "mb backlog show: prints item body"

echo ""
echo "--- show: unknown slug errors clearly ---"
cd "$TMPDIR_SHOW" || exit 1
output=$(bash "$MB" backlog show nonexistent-slug 2>&1)
cd - > /dev/null || exit 1
assert_contains "$output" "not found" "mb backlog show: unknown slug prints a not-found message"

# ── dismiss: sets status, keeps the file, excludes from default list ────────
echo ""
echo "--- dismiss: sets status: dismissed, file is kept ---"
TMPDIR_DISMISS="$(mktemp -d 2>/dev/null || mktemp -d -t mb-bl-test)"
ALL_TMPDIRS+=("$TMPDIR_DISMISS")
setup_test_project "$TMPDIR_DISMISS"
cd "$TMPDIR_DISMISS" || exit 1
bash "$MB" backlog add "To Dismiss" > /dev/null 2>&1
bash "$MB" backlog dismiss to-dismiss > /dev/null 2>&1
cd - > /dev/null || exit 1
assert_file_exists "$TMPDIR_DISMISS/docs/backlog/to-dismiss.md" "mb backlog dismiss: file is kept, not deleted"
content=$(cat "$TMPDIR_DISMISS/docs/backlog/to-dismiss.md")
assert_contains "$content" "status: dismissed" "mb backlog dismiss: status updated to dismissed"

# ── promote: seeds a .claude/plans/ stub, sets status + related_plan ────────
echo ""
echo "--- promote: seeds a plan stub in .claude/plans/, updates backlog frontmatter ---"
TMPDIR_PROMOTE="$(mktemp -d 2>/dev/null || mktemp -d -t mb-bl-test)"
ALL_TMPDIRS+=("$TMPDIR_PROMOTE")
setup_test_project "$TMPDIR_PROMOTE"
cd "$TMPDIR_PROMOTE" || exit 1
bash "$MB" backlog add "Worth Planning" "Needs a real plan" > /dev/null 2>&1
output=$(bash "$MB" backlog promote worth-planning 2>&1)
cd - > /dev/null || exit 1
assert_contains "$output" ".claude/plans/" "mb backlog promote: reports the stub path"
STUB_COUNT=$(find "$TMPDIR_PROMOTE/.claude/plans" -name "*worth-planning*" 2>/dev/null | wc -l | tr -d ' ')
assert_contains "$STUB_COUNT" "1" "mb backlog promote: exactly one stub file created"
content=$(cat "$TMPDIR_PROMOTE/docs/backlog/worth-planning.md")
assert_contains "$content" "status: promoted" "mb backlog promote: backlog file status updated to promoted"
assert_not_contains "$content" "related_plan: null" "mb backlog promote: related_plan is no longer null"
DOCS_PLANS_COUNT=$(find "$TMPDIR_PROMOTE/docs/plans" -name "*worth-planning*" 2>/dev/null | wc -l | tr -d ' ')
assert_contains "$DOCS_PLANS_COUNT" "0" "mb backlog promote: does not touch docs/plans/"

# ── promote: refuses to promote an item with malformed frontmatter ──────────
# WHY this test exists: without a delimiter-count guard, a hand-edited backlog
# file missing one or both '---' fences produced a silently empty stub while
# still marking the item promoted — a silent data loss. Regression test for
# that fix.
echo ""
echo "--- promote: refuses a backlog item with malformed frontmatter ---"
TMPDIR_MALFORMED="$(mktemp -d 2>/dev/null || mktemp -d -t mb-bl-test)"
ALL_TMPDIRS+=("$TMPDIR_MALFORMED")
setup_test_project "$TMPDIR_MALFORMED"
mkdir -p "$TMPDIR_MALFORMED/docs/backlog"
{
    echo "status: open"
    echo "# No Frontmatter Fences"
} > "$TMPDIR_MALFORMED/docs/backlog/no-fences.md"
cd "$TMPDIR_MALFORMED" || exit 1
output=$(bash "$MB" backlog promote no-fences 2>&1)
cd - > /dev/null || exit 1
assert_contains "$output" "malformed frontmatter" "mb backlog promote: reports malformed frontmatter clearly"
MALFORMED_STUB_COUNT=$(find "$TMPDIR_MALFORMED/.claude/plans" -name "*no-fences*" 2>/dev/null | wc -l | tr -d ' ')
assert_contains "$MALFORMED_STUB_COUNT" "0" "mb backlog promote: does not create a stub for a malformed item"
malformed_content=$(cat "$TMPDIR_MALFORMED/docs/backlog/no-fences.md")
assert_not_contains "$malformed_content" "status: promoted" "mb backlog promote: does not mark a malformed item promoted"

# ── slug validation: rejects path traversal and sed-delimiter characters ────
# WHY this test exists: show/promote/dismiss originally used the slug argv
# raw to build a filesystem path and (in promote's case) interpolate into a
# sed substitution — a slug containing '..'/'/' escaped docs/backlog/, and
# one containing '#' could break out of the sed script. Regression test for
# the backlog_validate_slug guard added to close both holes.
echo ""
echo "--- slug validation: rejects a path-traversal slug ---"
TMPDIR_TRAVERSAL="$(mktemp -d 2>/dev/null || mktemp -d -t mb-bl-test)"
ALL_TMPDIRS+=("$TMPDIR_TRAVERSAL")
setup_test_project "$TMPDIR_TRAVERSAL"
echo "TOP SECRET" > "$TMPDIR_TRAVERSAL/secret.md"
cd "$TMPDIR_TRAVERSAL" || exit 1
# WHY "../../secret" and not "../secret": the slug is appended as
# docs/backlog/<slug>.md, so escaping back to the project root (where
# secret.md was planted, two directories up from docs/backlog/) requires
# two ".." segments, not one. A single ".." only reaches docs/secret.md,
# which doesn't exist, so that assertion would pass even without the fix.
output=$(bash "$MB" backlog show "../../secret" 2>&1)
cd - > /dev/null || exit 1
assert_contains "$output" "Invalid slug" "mb backlog show: rejects a path-traversal slug"
assert_not_contains "$output" "TOP SECRET" "mb backlog show: does not disclose a file outside docs/backlog/"

echo ""
echo "--- slug validation: rejects a slug containing promote's sed delimiter ---"
TMPDIR_SEDCHAR="$(mktemp -d 2>/dev/null || mktemp -d -t mb-bl-test)"
ALL_TMPDIRS+=("$TMPDIR_SEDCHAR")
setup_test_project "$TMPDIR_SEDCHAR"
cd "$TMPDIR_SEDCHAR" || exit 1
output=$(bash "$MB" backlog promote 'evil#w /tmp/pwned' 2>&1)
cd - > /dev/null || exit 1
assert_contains "$output" "Invalid slug" "mb backlog promote: rejects a slug containing '#'"

# ── add: a title with no alphanumeric characters is rejected, not silently ──
# ── slugified to an empty/invisible item ─────────────────────────────────────
# WHY this test exists: backlog_slugify strips every non-alnum character, so
# an all-symbol title ("!!! ??? ###") slugified to an empty string, and add
# silently wrote docs/backlog/.md — a file `list`'s *.md glob can never match
# (no dotglob), making the item permanently invisible. Regression test for
# the empty-slug guard added to invoke_backlog_add.
echo ""
echo "--- add: rejects a title with no alphanumeric characters ---"
TMPDIR_SYMBOLS="$(mktemp -d 2>/dev/null || mktemp -d -t mb-bl-test)"
ALL_TMPDIRS+=("$TMPDIR_SYMBOLS")
setup_test_project "$TMPDIR_SYMBOLS"
cd "$TMPDIR_SYMBOLS" || exit 1
output=$(bash "$MB" backlog add "!!! ??? ###" 2>&1)
cd - > /dev/null || exit 1
assert_contains "$output" "at least one letter or number" "mb backlog add: rejects an all-symbol title clearly"
assert_file_not_exists "$TMPDIR_SYMBOLS/docs/backlog/.md" "mb backlog add: does not create an invisible .md file"

# ── promote: a literal '---' in the body (e.g. a markdown horizontal rule) ──
# WHY this test exists: the frontmatter-stripping awk originally matched any
# line that was exactly '---', not just the two real delimiters, so a body
# containing its own '---' rule got silently eaten by promote. Regression
# test for that fix.
echo ""
echo "--- promote: preserves a literal '---' inside the body ---"
TMPDIR_HR="$(mktemp -d 2>/dev/null || mktemp -d -t mb-bl-test)"
ALL_TMPDIRS+=("$TMPDIR_HR")
setup_test_project "$TMPDIR_HR"
cd "$TMPDIR_HR" || exit 1
bash "$MB" backlog add "Has A Rule" > /dev/null 2>&1
{
    echo ""
    echo "Above the rule."
    echo "---"
    echo "Below the rule."
} >> "docs/backlog/has-a-rule.md"
bash "$MB" backlog promote has-a-rule > /dev/null 2>&1
cd - > /dev/null || exit 1
STUB_FILE=$(find "$TMPDIR_HR/.claude/plans" -name "*has-a-rule*" 2>/dev/null | head -1)
stub_content=$(cat "$STUB_FILE" 2>/dev/null)
assert_contains "$stub_content" "Above the rule." "mb backlog promote: keeps body content before the literal ---"
# WHY "^---$" and not a bare "---": assert_contains passes the pattern straight
# to `grep -qi`, and a bare "---" is parsed as a (nonexistent) grep option
# rather than a pattern. Anchoring it turns it into a regex, sidestepping that.
assert_contains "$stub_content" "^---$" "mb backlog promote: preserves the literal --- horizontal rule itself"
assert_contains "$stub_content" "Below the rule." "mb backlog promote: keeps body content after the literal ---"

# ── plan promote: reconciles related_plan from the .claude/plans/ stub ──────
# ── to the durable docs/plans/ location ──────────────────────────────────────
# WHY this test exists: mb backlog promote sets related_plan to the ephemeral,
# gitignored .claude/plans/ stub path. Without reconciliation, that pointer
# permanently references a path no other clone of the repo ever has, once the
# real plan lands in docs/plans/ via mb plan promote. Regression test for the
# fix described in docs/superpowers/specs/2026-07-14-backlog-design.md
# "Plan-lifecycle reconciliation".
echo ""
echo "--- plan promote: rewrites related_plan to the docs/plans/ destination ---"
TMPDIR_RECONCILE="$(mktemp -d 2>/dev/null || mktemp -d -t mb-bl-test)"
ALL_TMPDIRS+=("$TMPDIR_RECONCILE")
setup_test_project "$TMPDIR_RECONCILE"
cd "$TMPDIR_RECONCILE" || exit 1
bash "$MB" backlog add "Reconcile Me" "Needs a real plan" > /dev/null 2>&1
bash "$MB" backlog promote reconcile-me > /dev/null 2>&1
STUB=$(find ".claude/plans" -name "*reconcile-me*" 2>/dev/null | head -1)
output=$(bash "$MB" plan promote "$STUB" 2>&1)
cd - > /dev/null || exit 1
assert_contains "$output" "Reconciled related_plan" "mb plan promote: reports the reconciliation"
content=$(cat "$TMPDIR_RECONCILE/docs/backlog/reconcile-me.md")
assert_contains "$content" "related_plan: docs/plans/" "mb plan promote: related_plan now points at docs/plans/"
assert_not_contains "$content" "related_plan: .claude/plans/" "mb plan promote: related_plan no longer points at the ephemeral stub"

echo ""
echo "--- plan promote: a draft unrelated to any backlog item is a no-op ---"
TMPDIR_NOBACKLOG="$(mktemp -d 2>/dev/null || mktemp -d -t mb-bl-test)"
ALL_TMPDIRS+=("$TMPDIR_NOBACKLOG")
setup_test_project "$TMPDIR_NOBACKLOG"
mkdir -p "$TMPDIR_NOBACKLOG/.claude/plans"
{
    echo "---"
    echo "status: draft"
    echo "---"
    echo ""
    echo "# Unrelated Plan"
} > "$TMPDIR_NOBACKLOG/.claude/plans/2026-08-16-unrelated.md"
cd "$TMPDIR_NOBACKLOG" || exit 1
output=$(bash "$MB" plan promote ".claude/plans/2026-08-16-unrelated.md" 2>&1)
cd - > /dev/null || exit 1
assert_not_contains "$output" "Reconciled related_plan" "mb plan promote: no backlog item referenced, no reconciliation attempted"
assert_file_exists "$TMPDIR_NOBACKLOG/docs/plans/2026-08-16-unrelated.md" "mb plan promote: still promotes normally"

# NOTE: a "reconciles even when the draft path uses backslashes" test used to live here. It
# was written when reconciliation matched by comparing related_plan against $DRAFT's literal
# path (see the now-removed DRAFT_NORM backslash-to-forward-slash normalization). The
# marker-based redesign (see "Plan-lifecycle reconciliation" in
# docs/superpowers/specs/2026-07-14-backlog-design.md) no longer compares paths at all, so
# that normalization was removed from scripts/mb.sh -- but the test kept passing anyway,
# because bash's `[ -f ]` on this Windows/Git-Bash (MSYS) environment happens to resolve a
# backslash-separated path transparently. On the project's actual CI target (ubuntu-latest,
# real POSIX), a backslash is just a literal filename character, not a separator, and the
# same test would fail with "Draft not found". Removed rather than "fixed" because nothing in
# the design requires mb.sh's plan promote to accept backslash-form paths in the first place
# -- a Windows user on the bash side is expected to be in Git Bash, where forward slashes are
# already the norm; the PowerShell side (mb.ps1) is the one that needs native backslash
# support, and it already has it for free via .NET's path handling, unrelated to this code.

# ── plan promote: reconciliation escapes sed metacharacters in the ─────────
# ── destination filename instead of corrupting the frontmatter or ──────────
# ── breaking the sed call ────────────────────────────────────────────────────
# WHY this test exists: $DEST in the reconciliation code is derived from the
# user-chosen $DRAFT filename (mb plan promote <path>), which is never
# charset-restricted the way a backlog slug is. Interpolating it unescaped
# into sed's replacement text let a literal '&' (sed's "whole match" token)
# duplicate content into the frontmatter, and a literal '#' (this
# substitution's own delimiter) broke the sed command outright and silently
# skipped the rewrite while still printing a "Reconciled" success message.
# Regression test for escaping both before interpolation. Reconciliation
# matches by the "<!-- pmb-backlog-source: <slug> -->" marker mb backlog
# promote stamps into the stub body, not by path, so the fixture embeds that
# marker directly rather than going through the real promote flow (which
# would never itself produce a '&'/'#'-containing filename).
echo ""
echo "--- plan promote: reconciles correctly when the destination filename contains '&' ---"
TMPDIR_AMP="$(mktemp -d 2>/dev/null || mktemp -d -t mb-bl-test)"
ALL_TMPDIRS+=("$TMPDIR_AMP")
setup_test_project "$TMPDIR_AMP"
cd "$TMPDIR_AMP" || exit 1
mkdir -p docs/backlog .claude/plans
{
    echo "---"
    echo "status: promoted"
    echo "created: 2026-08-16"
    echo "last-reviewed: 2026-08-16"
    echo "staleness-threshold: 90d"
    echo "related_plan: .claude/plans/2026-08-16-amp-path.md"
    echo "---"
    echo ""
    echo "# Amp Path"
} > docs/backlog/amp-path.md
{
    echo "---"
    echo "status: draft"
    echo "---"
    echo ""
    echo "# Amp Path plan"
    echo ""
    echo "<!-- pmb-backlog-source: amp-path -->"
} > "amp&path.md"
output=$(bash "$MB" plan promote "amp&path.md" 2>&1)
cd - > /dev/null || exit 1
assert_contains "$output" "Reconciled related_plan" "mb plan promote: reconciles despite '&' in the destination filename"
content=$(cat "$TMPDIR_AMP/docs/backlog/amp-path.md")
assert_contains "$content" "related_plan: docs/plans/amp&path.md" "mb plan promote: related_plan is the literal path, not duplicated/corrupted"

echo ""
echo "--- plan promote: reconciles correctly when the destination filename contains '#' ---"
TMPDIR_HASH="$(mktemp -d 2>/dev/null || mktemp -d -t mb-bl-test)"
ALL_TMPDIRS+=("$TMPDIR_HASH")
setup_test_project "$TMPDIR_HASH"
cd "$TMPDIR_HASH" || exit 1
mkdir -p docs/backlog .claude/plans
{
    echo "---"
    echo "status: promoted"
    echo "created: 2026-08-16"
    echo "last-reviewed: 2026-08-16"
    echo "staleness-threshold: 90d"
    echo "related_plan: .claude/plans/2026-08-16-hash-path.md"
    echo "---"
    echo ""
    echo "# Hash Path"
} > docs/backlog/hash-path.md
{
    echo "---"
    echo "status: draft"
    echo "---"
    echo ""
    echo "# Hash Path plan"
    echo ""
    echo "<!-- pmb-backlog-source: hash-path -->"
} > "hash#path.md"
output=$(bash "$MB" plan promote "hash#path.md" 2>&1)
cd - > /dev/null || exit 1
assert_not_contains "$output" "sed:" "mb plan promote: no sed error from '#' in the destination filename"
assert_contains "$output" "Reconciled related_plan" "mb plan promote: reconciles despite '#' in the destination filename"
content=$(cat "$TMPDIR_HASH/docs/backlog/hash-path.md")
assert_contains "$content" "related_plan: docs/plans/hash#path.md" "mb plan promote: related_plan is the literal path, not left stale"

# ── plan promote: reconciliation survives the draft being renamed before ────
# ── promotion (the spec's own motivating scenario) ───────────────────────────
# WHY this test exists: matching by exact draft path (the original design)
# broke the moment the user renamed the stub while fleshing it out with
# superpowers:writing-plans -- exactly the workflow the spec's own
# "Plan-lifecycle reconciliation" section describes as the reason this
# feature exists. Regression test for the marker-based redesign that fixes it.
echo ""
echo "--- plan promote: reconciles even when the stub was renamed after mb backlog promote ---"
TMPDIR_RENAME="$(mktemp -d 2>/dev/null || mktemp -d -t mb-bl-test)"
ALL_TMPDIRS+=("$TMPDIR_RENAME")
setup_test_project "$TMPDIR_RENAME"
cd "$TMPDIR_RENAME" || exit 1
bash "$MB" backlog add "Rename Scenario" "Needs a real plan" > /dev/null 2>&1
bash "$MB" backlog promote rename-scenario > /dev/null 2>&1
STUB=$(find ".claude/plans" -name "*rename-scenario*" 2>/dev/null | head -1)
RENAMED="$(dirname "$STUB")/renamed-during-writing-plans.md"
mv "$STUB" "$RENAMED"
output=$(bash "$MB" plan promote "$RENAMED" 2>&1)
cd - > /dev/null || exit 1
assert_contains "$output" "Reconciled related_plan" "mb plan promote: reconciles a renamed stub via the embedded backlog-source marker"
content=$(cat "$TMPDIR_RENAME/docs/backlog/rename-scenario.md")
assert_contains "$content" "related_plan: docs/plans/renamed-during-writing-plans.md" "mb plan promote: related_plan points at the renamed file's actual destination"

# ── backlog promote: refuses to re-promote an already-promoted item ─────────
# WHY this test exists: promote used to unconditionally overwrite the stub
# at its deterministic .claude/plans/<date>-<slug>.md path, so re-running it
# on an already-promoted item silently destroyed any hand-edited content in
# the stub, with an identical success message both times. Regression test
# for the status:open guard.
echo ""
echo "--- promote: refuses to re-promote an item that isn't status: open ---"
TMPDIR_REPROMOTE="$(mktemp -d 2>/dev/null || mktemp -d -t mb-bl-test)"
ALL_TMPDIRS+=("$TMPDIR_REPROMOTE")
setup_test_project "$TMPDIR_REPROMOTE"
cd "$TMPDIR_REPROMOTE" || exit 1
bash "$MB" backlog add "Repromote Me" "Needs a real plan" > /dev/null 2>&1
bash "$MB" backlog promote repromote-me > /dev/null 2>&1
STUB=$(find ".claude/plans" -name "*repromote-me*" 2>/dev/null | head -1)
echo "HAND-EDITED CONTENT THAT MUST SURVIVE" >> "$STUB"
output=$(bash "$MB" backlog promote repromote-me 2>&1)
cd - > /dev/null || exit 1
assert_contains "$output" "Cannot promote" "mb backlog promote: refuses to re-promote an already-promoted item"
assert_contains "$(cat "$TMPDIR_REPROMOTE/$STUB")" "HAND-EDITED CONTENT THAT MUST SURVIVE" "mb backlog promote: does not clobber the existing stub on refusal"

# ── backlog promote: refuses an item with two fences but no status: field ───
# WHY this test exists: the original malformed-frontmatter guard only
# checked for two '---' delimiters, not that a status: field actually exists
# between them -- a file with fences but no status line passed the guard,
# then the status-rewrite sed silently matched nothing, leaving the item
# invisible from the default list while never truly promoted, despite a
# "Seeded plan stub" success message. Regression test for the added guard.
echo ""
echo "--- promote: refuses a backlog item with fences but no status: field ---"
TMPDIR_NOSTATUS="$(mktemp -d 2>/dev/null || mktemp -d -t mb-bl-test)"
ALL_TMPDIRS+=("$TMPDIR_NOSTATUS")
setup_test_project "$TMPDIR_NOSTATUS"
mkdir -p "$TMPDIR_NOSTATUS/docs/backlog"
{
    echo "---"
    echo "created: 2026-08-16"
    echo "related_plan: null"
    echo "---"
    echo ""
    echo "# No Status Field"
} > "$TMPDIR_NOSTATUS/docs/backlog/no-status.md"
cd "$TMPDIR_NOSTATUS" || exit 1
output=$(bash "$MB" backlog promote no-status 2>&1)
cd - > /dev/null || exit 1
assert_contains "$output" "missing 'status:' field" "mb backlog promote: reports the missing status: field clearly"
assert_file_not_exists "$TMPDIR_NOSTATUS/.claude/plans" "mb backlog promote: does not create .claude/plans/ for a rejected item"

# ── promote: refuses an item with preamble content before an accidental ─────
# ── '---'-'---' pair ─────────────────────────────────────────────────────────
# WHY this test exists: the malformed-frontmatter guard originally only
# counted '---' delimiters anywhere in the file, not that the first one is on
# line 1. A file with prose before a legacy/accidental '---'-'---' pair still
# had DELIM_COUNT>=2 and a status: line, so it passed both guards -- the awk
# body-extractor then treated that pair as the real fences and silently
# dropped the preamble into nowhere while still reporting "Seeded plan stub".
# Regression test for anchoring the guard to line 1.
echo ""
echo "--- promote: refuses a backlog item with content before the frontmatter fence ---"
TMPDIR_PREAMBLE="$(mktemp -d 2>/dev/null || mktemp -d -t mb-bl-test)"
ALL_TMPDIRS+=("$TMPDIR_PREAMBLE")
setup_test_project "$TMPDIR_PREAMBLE"
mkdir -p "$TMPDIR_PREAMBLE/docs/backlog"
{
    echo "Some notes I jotted before I understood the format."
    echo "---"
    echo "status: open"
    echo "---"
    echo "More notes."
} > "$TMPDIR_PREAMBLE/docs/backlog/preamble.md"
cd "$TMPDIR_PREAMBLE" || exit 1
output=$(bash "$MB" backlog promote preamble 2>&1)
cd - > /dev/null || exit 1
assert_contains "$output" "must start with" "mb backlog promote: refuses a file whose frontmatter fence isn't on line 1"
assert_file_not_exists "$TMPDIR_PREAMBLE/.claude/plans" "mb backlog promote: does not create .claude/plans/ for a rejected item"

# ── plan promote: reconciliation ignores a decoy mention of the marker ──────
# ── format in prose, and is not fooled into touching an unrelated item ──────
# WHY this test exists: an earlier design used a plain "(Backlog source: x)"
# line, which reads as natural English prose -- a plan document that
# discusses this exact feature (plausible in this very repo) could contain
# that string without it being a genuine marker, causing reconciliation to
# either silently no-op for the real source item or corrupt an unrelated
# backlog item that happens to share the mentioned slug. Regression test for
# the HTML-comment marker format, which nothing writes by coincidence.
echo ""
echo "--- plan promote: a decoy mention of the marker format in prose does not reconcile ---"
TMPDIR_DECOY="$(mktemp -d 2>/dev/null || mktemp -d -t mb-bl-test)"
ALL_TMPDIRS+=("$TMPDIR_DECOY")
setup_test_project "$TMPDIR_DECOY"
cd "$TMPDIR_DECOY" || exit 1
mkdir -p docs/backlog .claude/plans
{
    echo "---"
    echo "status: open"
    echo "created: 2026-08-16"
    echo "last-reviewed: 2026-08-16"
    echo "staleness-threshold: 90d"
    echo "related_plan: null"
    echo "---"
    echo ""
    echo "# Unrelated Item"
} > docs/backlog/unrelated-item.md
{
    echo "---"
    echo "status: draft"
    echo "---"
    echo ""
    echo "# Discussing The Backlog Feature"
    echo ""
    echo "This plan explains the marker format, e.g. (Backlog source: unrelated-item),"
    echo "used by mb backlog promote to identify the originating item."
} > "discussing-the-feature.md"
output=$(bash "$MB" plan promote "discussing-the-feature.md" 2>&1)
cd - > /dev/null || exit 1
assert_not_contains "$output" "Reconciled related_plan" "mb plan promote: a decoy prose mention does not trigger reconciliation"
content=$(cat "$TMPDIR_DECOY/docs/backlog/unrelated-item.md")
assert_contains "$content" "related_plan: null" "mb plan promote: the unrelated backlog item is left untouched"

# ── plan promote: reconciles even when the marker is no longer the last ─────
# ── line, because the user appended content while fleshing out the plan ─────
# WHY this test exists: an earlier design required the marker to be the
# file's last non-blank line, which broke as soon as the user added any
# content after it -- exactly what "flesh it out with superpowers:writing-
# plans" instructs them to do. The HTML-comment format doesn't depend on
# position, so this must keep working regardless of where the marker ends up.
echo ""
echo "--- plan promote: reconciles even when content was appended after the marker ---"
TMPDIR_APPENDED="$(mktemp -d 2>/dev/null || mktemp -d -t mb-bl-test)"
ALL_TMPDIRS+=("$TMPDIR_APPENDED")
setup_test_project "$TMPDIR_APPENDED"
cd "$TMPDIR_APPENDED" || exit 1
bash "$MB" backlog add "Appended After" "Needs a real plan" > /dev/null 2>&1
bash "$MB" backlog promote appended-after > /dev/null 2>&1
STUB=$(find ".claude/plans" -name "*appended-after*" 2>/dev/null | head -1)
{
    echo ""
    echo "## Implementation Steps"
    echo "1. Do the thing."
    echo "2. Ship it."
} >> "$STUB"
output=$(bash "$MB" plan promote "$STUB" 2>&1)
cd - > /dev/null || exit 1
assert_contains "$output" "Reconciled related_plan" "mb plan promote: reconciles even though the marker is no longer the last line"
content=$(cat "$TMPDIR_APPENDED/docs/backlog/appended-after.md")
assert_contains "$content" "related_plan: docs/plans/" "mb plan promote: related_plan was updated despite content appended after the marker"

print_summary
