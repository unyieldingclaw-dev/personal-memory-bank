#!/usr/bin/env bash
# tests/test-mb-upgrade.sh — tests for mb upgrade
set -u

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
MB="$REPO_ROOT/scripts/mb.sh"
source "$REPO_ROOT/tests/helpers/assert.sh"
source "$REPO_ROOT/tests/setup.sh"

echo "=== mb upgrade tests ==="

TMPDIR_UP="$(mktemp -d 2>/dev/null || mktemp -d -t mb-upgrade-test)"
trap 'rm -rf "$TMPDIR_UP"' EXIT

setup_test_project "$TMPDIR_UP"

# ── Template sync: deleted TEMPLATE_OWNED file is restored ───────────────────
echo ""
echo "--- template sync: restores TEMPLATE_OWNED file ---"

mkdir -p "$TMPDIR_UP/scripts"
rm -f "$TMPDIR_UP/scripts/dangerous-commands.sh"
assert_file_not_exists "$TMPDIR_UP/scripts/dangerous-commands.sh" "file absent before upgrade"

output=$(cd "$TMPDIR_UP" && MB_HOME="$REPO_ROOT" bash "$MB" upgrade 2>&1)
assert_exit_zero $? "mb upgrade exits 0"
assert_file_exists "$TMPDIR_UP/scripts/dangerous-commands.sh" "upgrade restores TEMPLATE_OWNED script"

# ── Template sync: review-reminders scripts are TEMPLATE_OWNED too ───────────
# Regression test: templates/.claude/settings.json invokes review-reminders.sh/.ps1 and
# review-reminders-post.sh/.ps1 directly, but they were missing from TEMPLATE_OWNED, so a
# deleted or stale copy was never restored by mb upgrade.
echo ""
echo "--- template sync: restores review-reminders TEMPLATE_OWNED scripts ---"

rm -f "$TMPDIR_UP/scripts/review-reminders.sh" "$TMPDIR_UP/scripts/review-reminders-post.sh"
assert_file_not_exists "$TMPDIR_UP/scripts/review-reminders.sh" "review-reminders.sh absent before upgrade"

output=$(cd "$TMPDIR_UP" && MB_HOME="$REPO_ROOT" bash "$MB" upgrade 2>&1)
assert_exit_zero $? "mb upgrade exits 0"
assert_file_exists "$TMPDIR_UP/scripts/review-reminders.sh" "upgrade restores TEMPLATE_OWNED review-reminders.sh"
assert_file_exists "$TMPDIR_UP/scripts/review-reminders-post.sh" "upgrade restores TEMPLATE_OWNED review-reminders-post.sh"

# ── Template sync: _review-gate-lib.sh/.ps1 are TEMPLATE_OWNED too ───────────
echo ""
echo "--- template sync: restores _review-gate-lib TEMPLATE_OWNED scripts ---"

rm -f "$TMPDIR_UP/scripts/_review-gate-lib.sh" "$TMPDIR_UP/scripts/_review-gate-lib.ps1"
assert_file_not_exists "$TMPDIR_UP/scripts/_review-gate-lib.sh" "_review-gate-lib.sh absent before upgrade"

output=$(cd "$TMPDIR_UP" && MB_HOME="$REPO_ROOT" bash "$MB" upgrade 2>&1)
assert_exit_zero $? "mb upgrade exits 0"
assert_file_exists "$TMPDIR_UP/scripts/_review-gate-lib.sh" "upgrade restores TEMPLATE_OWNED _review-gate-lib.sh"
assert_file_exists "$TMPDIR_UP/scripts/_review-gate-lib.ps1" "upgrade restores TEMPLATE_OWNED _review-gate-lib.ps1"

# ── Template sync: ALL command files are auto-discovered, not a hardcoded subset ─
# Regression test: TEMPLATE_OWNED used to hardcode 4 of 8 command files
# (code-review.md, feature-dev.md, security-review.md, pmb-status.md), so
# accessibility-review.md, change-review.md, health-check.md, and test-audit.md
# were silently never restored by `mb upgrade` even though `mb init` already
# discovered them correctly. Fixed to auto-discover from templates/claude-commands/
# instead, matching mb.ps1's Invoke-Upgrade.
echo ""
echo "--- template sync: restores ALL command files, not just the previously-hardcoded 4 ---"

rm -f "$TMPDIR_UP/.claude/commands/accessibility-review.md" \
      "$TMPDIR_UP/.claude/commands/change-review.md" \
      "$TMPDIR_UP/.claude/commands/health-check.md" \
      "$TMPDIR_UP/.claude/commands/test-audit.md"
assert_file_not_exists "$TMPDIR_UP/.claude/commands/change-review.md" "change-review.md absent before upgrade"

output=$(cd "$TMPDIR_UP" && MB_HOME="$REPO_ROOT" bash "$MB" upgrade 2>&1)
assert_exit_zero $? "mb upgrade exits 0"
assert_file_exists "$TMPDIR_UP/.claude/commands/accessibility-review.md" "upgrade restores accessibility-review.md"
assert_file_exists "$TMPDIR_UP/.claude/commands/change-review.md" "upgrade restores change-review.md"
assert_file_exists "$TMPDIR_UP/.claude/commands/health-check.md" "upgrade restores health-check.md"
assert_file_exists "$TMPDIR_UP/.claude/commands/test-audit.md" "upgrade restores test-audit.md"

# ── Template sync: ALL agent files are auto-discovered, not a hardcoded subset ─
# Regression test for the SAME defect one directory over, which recurred on 2026-08-26.
# ADVISORY_DIFF hardcoded researcher.md and security-reviewer.md, so when
# .claude/agents/opposition.md was added — and BOTH review commands were changed to dispatch it
# by name — `mb upgrade` would never have delivered it. An adopter's /change-review would fail at
# the Opposition step, which is the gate's sole authority on whether a change ships.
#
# WHY this asserts creation-when-absent specifically: agents used to sit in ADVISORY_DIFF, which
# SKIPS a target missing from the project. A newly-shipped agent is missing for every adopter by
# definition, so a discovered-but-still-ADVISORY_DIFF list would have passed a "no hardcoded
# list" check while still delivering nothing. Deleting the files before upgrading is what makes
# this test discriminate between the two.
echo ""
echo "--- template sync: restores ALL agent files, including newly-shipped ones ---"

rm -f "$TMPDIR_UP/.claude/agents/opposition.md" \
      "$TMPDIR_UP/.claude/agents/researcher.md" \
      "$TMPDIR_UP/.claude/agents/security-reviewer.md"
assert_file_not_exists "$TMPDIR_UP/.claude/agents/opposition.md" "opposition.md absent before upgrade"

output=$(cd "$TMPDIR_UP" && MB_HOME="$REPO_ROOT" bash "$MB" upgrade 2>&1)
assert_exit_zero $? "mb upgrade exits 0"
assert_file_exists "$TMPDIR_UP/.claude/agents/opposition.md" "upgrade restores opposition.md (was never in the hardcoded list)"
assert_file_exists "$TMPDIR_UP/.claude/agents/researcher.md" "upgrade restores researcher.md"
assert_file_exists "$TMPDIR_UP/.claude/agents/security-reviewer.md" "upgrade restores security-reviewer.md"

# Completeness invariant: every agent shipped in templates/ must be delivered. This is what
# actually fails when a FOURTH agent is added later and someone reintroduces a static list —
# the per-file assertions above can only cover agents that existed when this test was written.
# WHY the non-empty guard: without it, an absent or empty templates/.claude/agents/ makes the loop
# below iterate zero times, leaving MISSING_AGENTS empty and reporting PASS while upgrade delivered
# nothing. Absence must be loud. The sibling guard in tests/test-mb-init.sh landed in bf636e1,
# which disclosed this loop's lack of one as "tracked, not fixed here"; this closes it.
EXPECTED_AGENTS=""
for f in "$REPO_ROOT/templates/.claude/agents"/*.md; do
    [ -f "$f" ] || continue
    EXPECTED_AGENTS="$EXPECTED_AGENTS $(basename "$f")"
done
assert_not_contains "expected:${EXPECTED_AGENTS}" "expected:$" "templates/.claude/agents/ yields a non-empty expected set"

MISSING_AGENTS=""
for f in "$REPO_ROOT/templates/.claude/agents"/*.md; do
    [ -f "$f" ] || continue
    [ -f "$TMPDIR_UP/.claude/agents/$(basename "$f")" ] || MISSING_AGENTS="$MISSING_AGENTS $(basename "$f")"
done
assert_contains "missing:${MISSING_AGENTS}" "missing:$" "every agent in templates/.claude/agents/ was delivered by upgrade"

# ── Version tracking: .pmb-version updated ───────────────────────────────────
echo ""
echo "--- version tracking: .pmb-version matches repo VERSION ---"

output=$(cd "$TMPDIR_UP" && MB_HOME="$REPO_ROOT" bash "$MB" upgrade 2>&1)
assert_exit_zero $? "mb upgrade exits 0 on second run"
assert_contains "$output" ".pmb-version" "mb upgrade reports .pmb-version update"

EXPECTED_VER=$(tr -d '[:space:]' < "$REPO_ROOT/VERSION")
ACTUAL_VER=$(tr -d '[:space:]' < "$TMPDIR_UP/.pmb-version" 2>/dev/null || echo "missing")
assert_contains "$ACTUAL_VER" "$EXPECTED_VER" ".pmb-version matches repo VERSION after upgrade"

# ── Missing standard: ADVISORY_CREATE restores it ────────────────────────────
echo ""
echo "--- missing standard: upgrade creates it ---"

rm -f "$TMPDIR_UP/standards/WORKFLOW.md"
assert_file_not_exists "$TMPDIR_UP/standards/WORKFLOW.md" "WORKFLOW.md absent before upgrade"

output=$(cd "$TMPDIR_UP" && MB_HOME="$REPO_ROOT" bash "$MB" upgrade 2>&1)
assert_exit_zero $? "mb upgrade exits 0 with missing standard"
assert_file_exists "$TMPDIR_UP/standards/WORKFLOW.md" "upgrade restores missing WORKFLOW.md"

# ── Missing doc: ADVISORY_CREATE restores it ─────────────────────────────────
echo ""
echo "--- missing doc: upgrade creates it ---"

rm -f "$TMPDIR_UP/docs/HOOKS-GUIDE.md"
assert_file_not_exists "$TMPDIR_UP/docs/HOOKS-GUIDE.md" "docs/HOOKS-GUIDE.md absent before upgrade"

output=$(cd "$TMPDIR_UP" && MB_HOME="$REPO_ROOT" bash "$MB" upgrade 2>&1)
assert_exit_zero $? "mb upgrade exits 0 with missing doc"
assert_file_exists "$TMPDIR_UP/docs/HOOKS-GUIDE.md" "upgrade restores missing docs/HOOKS-GUIDE.md"

# ── .gitignore reconciliation ────────────────────────────────────────────────
# WHY these exist at all: `mb upgrade` never touched .gitignore until 2026-08-25, so an
# entry added to the canonical list could not reach an already-initialized project. The
# helper that fixed it shipped with zero coverage, and a real bug slipped through on the
# one axis nobody exercised -- see the CRLF case below.
echo ""
echo "--- .gitignore: upgrade back-fills a missing entry ---"

TMPDIR_GI="$(mktemp -d 2>/dev/null || mktemp -d -t mb-gitignore-test)"
trap 'rm -rf "$TMPDIR_GI"' EXIT
setup_test_project "$TMPDIR_GI"

# An adopter initialized before the list grew: has the old entries, missing the new one.
printf '# Memory Bank\nhandoff.md\n.pmb-checksums\n' > "$TMPDIR_GI/.gitignore"

output=$(cd "$TMPDIR_GI" && MB_HOME="$REPO_ROOT" bash "$MB" upgrade 2>&1)
assert_contains "$output" "\.gitignore (added" "upgrade reports the entries it added"
assert_contains "$(cat "$TMPDIR_GI/.gitignore")" "\.claude/contracts/\*\.json" \
    "upgrade back-fills .claude/contracts/*.json"
assert_contains "$(grep -c '^handoff\.md$' "$TMPDIR_GI/.gitignore")" "^1$" \
    "an entry already present is not duplicated"

echo ""
echo "--- .gitignore: second upgrade is a no-op ---"

output=$(cd "$TMPDIR_GI" && MB_HOME="$REPO_ROOT" bash "$MB" upgrade 2>&1)
assert_contains "$output" "all mb entries present" "repeat upgrade reports nothing to add"
assert_contains "$(grep -c '^\.claude/contracts/\*\.json$' "$TMPDIR_GI/.gitignore")" "^1$" \
    "repeat upgrade does not duplicate entries"

echo ""
echo "--- .gitignore: CRLF file is not re-appended (regression) ---"
# WHY this is the most important case here: `grep -qxF` does NOT match a CRLF-terminated
# line under real GNU grep, and this repo's own .gitignore is CRLF. Git Bash's grep strips
# CR in text mode, so the bug was invisible on Windows -- an `mb upgrade` from WSL or Linux
# CI would have re-appended all 11 entries on EVERY run, unbounded, to the very file the
# feature exists to repair. Caught in review, not by a test, which is why one exists now.

TMPDIR_GICRLF="$(mktemp -d 2>/dev/null || mktemp -d -t mb-gitignore-crlf)"
trap 'rm -rf "$TMPDIR_GICRLF"' EXIT
setup_test_project "$TMPDIR_GICRLF"

(cd "$TMPDIR_GICRLF" && MB_HOME="$REPO_ROOT" bash "$MB" upgrade >/dev/null 2>&1)
# Rewrite it with CRLF terminators, contents otherwise unchanged.
sed 's/$/\r/' "$TMPDIR_GICRLF/.gitignore" > "$TMPDIR_GICRLF/.gitignore.crlf"
mv "$TMPDIR_GICRLF/.gitignore.crlf" "$TMPDIR_GICRLF/.gitignore"
LINES_BEFORE=$(wc -l < "$TMPDIR_GICRLF/.gitignore")

output=$(cd "$TMPDIR_GICRLF" && MB_HOME="$REPO_ROOT" bash "$MB" upgrade 2>&1)
assert_contains "$output" "all mb entries present" "CRLF .gitignore: entries recognised as present"
LINES_AFTER=$(wc -l < "$TMPDIR_GICRLF/.gitignore")
assert_contains "match=$([ "$LINES_BEFORE" -eq "$LINES_AFTER" ] && echo yes || echo no)" \
    "match=yes" "CRLF .gitignore: upgrade appends nothing ($LINES_BEFORE -> $LINES_AFTER)"

# The two assertions above are PLATFORM-CONDITIONAL and were verified by mutation to prove
# it: with the normalization removed from sync_gitignore they still PASS on Git Bash, whose
# grep runs in text mode and strips the CR for free. They only go red on a shell with binary
# grep semantics -- Linux, WSL, CI -- which is exactly where the bug bit. That makes them
# necessary but not sufficient: on the developer's own machine they cannot fail.
#
# The three below close that hole. They assert the MECHANISM rather than the outcome, so
# deleting the normalization from sync_gitignore turns the suite red on every platform.
assert_contains "$(grep -Uc '^handoff\.md$' "$TMPDIR_GICRLF/.gitignore" || echo 0)" "^0$" \
    "CRLF fixture is genuinely CRLF (binary grep does not match a bare-LF pattern)"
assert_contains "$(sed 's/[[:space:]]*$//' "$TMPDIR_GICRLF/.gitignore" | grep -Uc '^handoff\.md$')" \
    "^1$" "trailing-whitespace normalization makes it match under binary grep"
assert_contains "$(grep -c "sed 's/\[\[:space:\]\]\*\$//'" "$REPO_ROOT/scripts/mb.sh")" "^1$" \
    "sync_gitignore still normalizes before matching (guards the platform-blind case above)"

echo ""
echo "--- .gitignore: leading whitespace does NOT count as present ---"
# WHY: git treats leading whitespace as part of the pattern, so "  handoff.md" does not
# ignore handoff.md. An implementation that trims both ends would skip a needed entry --
# the exact silent-skip failure the whole-line match was introduced to prevent.

TMPDIR_GIWS="$(mktemp -d 2>/dev/null || mktemp -d -t mb-gitignore-ws)"
trap 'rm -rf "$TMPDIR_GIWS"' EXIT
setup_test_project "$TMPDIR_GIWS"
printf '# Memory Bank\n  handoff.md\n' > "$TMPDIR_GIWS/.gitignore"

output=$(cd "$TMPDIR_GIWS" && MB_HOME="$REPO_ROOT" bash "$MB" upgrade 2>&1)
assert_contains "$(grep -c '^handoff\.md$' "$TMPDIR_GIWS/.gitignore")" "^1$" \
    "indented entry does not suppress the real one"

echo ""
echo "--- .gitignore: --dry-run writes nothing ---"

TMPDIR_GIDRY="$(mktemp -d 2>/dev/null || mktemp -d -t mb-gitignore-dry)"
trap 'rm -rf "$TMPDIR_GIDRY"' EXIT
setup_test_project "$TMPDIR_GIDRY"
printf '# Memory Bank\nhandoff.md\n' > "$TMPDIR_GIDRY/.gitignore"
BEFORE=$(cat "$TMPDIR_GIDRY/.gitignore")

output=$(cd "$TMPDIR_GIDRY" && MB_HOME="$REPO_ROOT" bash "$MB" upgrade --dry-run 2>&1)
assert_contains "$output" "would add" "dry-run reports what it would add"
assert_contains "match=$([ "$BEFORE" = "$(cat "$TMPDIR_GIDRY/.gitignore")" ] && echo yes || echo no)" \
    "match=yes" "dry-run leaves .gitignore unchanged"

print_summary
