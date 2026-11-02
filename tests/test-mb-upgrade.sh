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

echo ""
echo "--- template sync: restores review-gate classifiers ---"
rm -f "$TMPDIR_UP/scripts/_review-gate-classify.py" "$TMPDIR_UP/scripts/_review-gate-classify.ps1"
output=$(cd "$TMPDIR_UP" && MB_HOME="$REPO_ROOT" bash "$MB" upgrade 2>&1)
assert_exit_zero $? "mb upgrade exits 0"
assert_file_exists "$TMPDIR_UP/scripts/_review-gate-classify.py" "upgrade restores TEMPLATE_OWNED Python classifier"
assert_file_exists "$TMPDIR_UP/scripts/_review-gate-classify.ps1" "upgrade restores TEMPLATE_OWNED PowerShell classifier"

echo ""
echo "--- template sync: restores merge-gate helpers ---"
rm -f "$TMPDIR_UP/scripts/_review-gate-merge.py" "$TMPDIR_UP/scripts/_review-gate-merge.ps1"
output=$(cd "$TMPDIR_UP" && MB_HOME="$REPO_ROOT" bash "$MB" upgrade 2>&1)
assert_exit_zero $? "mb upgrade exits 0"
assert_file_exists "$TMPDIR_UP/scripts/_review-gate-merge.py" "upgrade restores TEMPLATE_OWNED Python merge helper"
assert_file_exists "$TMPDIR_UP/scripts/_review-gate-merge.ps1" "upgrade restores TEMPLATE_OWNED PowerShell merge helper"

echo ""
echo "--- template sync: restores Codex hook wiring and adapters ---"
rm -f "$TMPDIR_UP/.codex/hooks.json" \
      "$TMPDIR_UP/scripts/codex-compaction-hook.sh" \
      "$TMPDIR_UP/scripts/codex-compaction-hook.ps1"
output=$(cd "$TMPDIR_UP" && MB_HOME="$REPO_ROOT" bash "$MB" upgrade 2>&1)
assert_exit_zero $? "mb upgrade exits 0 while restoring Codex hooks"
assert_file_exists "$TMPDIR_UP/.codex/hooks.json" "upgrade restores TEMPLATE_OWNED Codex hook wiring"
assert_file_exists "$TMPDIR_UP/scripts/codex-compaction-hook.sh" "upgrade restores TEMPLATE_OWNED Codex bash adapter"
assert_file_exists "$TMPDIR_UP/scripts/codex-compaction-hook.ps1" "upgrade restores TEMPLATE_OWNED Codex PowerShell adapter"

echo ""
echo "--- advisory create: AGENTS.md is delivered without overwriting customization ---"
rm -f "$TMPDIR_UP/AGENTS.md"
output=$(cd "$TMPDIR_UP" && MB_HOME="$REPO_ROOT" bash "$MB" upgrade 2>&1)
assert_exit_zero $? "mb upgrade exits 0 while creating missing AGENTS.md"
assert_file_exists "$TMPDIR_UP/AGENTS.md" "upgrade creates missing AGENTS.md"
printf '# Project-specific agent rules\nkeep-this-customization\n' > "$TMPDIR_UP/AGENTS.md"
output=$(cd "$TMPDIR_UP" && MB_HOME="$REPO_ROOT" bash "$MB" upgrade 2>&1)
assert_contains "$(cat "$TMPDIR_UP/AGENTS.md")" "keep-this-customization" "upgrade preserves customized AGENTS.md"
assert_contains "$output" "AGENTS.md.*differs from template" "upgrade reports customized AGENTS.md for manual review"

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
# assert_equals, not assert_contains: the latter is an unanchored grep, so a stale .pmb-version of
# "1.2.10" would have PASSED against a repo VERSION of "1.2.1". Pre-existing on origin/main:89.
assert_equals "$ACTUAL_VER" "$EXPECTED_VER" ".pmb-version matches repo VERSION after upgrade"

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
# WHY: standards/WORKFLOW.md Phase 3 and the feature-dev command both tell adopters that
# .claude/plans/ drafts are gitignored scratch files, and mb doctor reports a tracked one as an
# ERROR. Until [NS-19] the entry existed only in PMB's own .gitignore, so the claim was false in
# every adopter.
assert_equals "$(grep -c '^\.claude/plans/$' "$TMPDIR_GI/.gitignore")" "1" \
    "upgrade back-fills .claude/plans/ (the scratch-plan directory WORKFLOW.md calls gitignored)"

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
# CI would have re-appended every entry on EVERY run, unbounded, to the very file the
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

echo ""
echo "--- .gitignore: mb.sh and mb.ps1 install the same entries ---"
# WHY: both arrays carry a comment saying they must stay identical because they already drifted
# once, and every case above runs mb.sh only -- so an entry added to one runtime alone would pass
# this suite while bash and pwsh adopters diverged again.
_gi_entries() {  # $1 = file, $2 = regex matching the array's opening line
    awk -v start="$2" '$0 ~ start {f=1; next} f && /^[[:space:]]*\)/ {exit} f' "$1" |
        grep -o '"[^"]*"' | tr -d '"' | sort
}
SH_GI="$(_gi_entries "$REPO_ROOT/scripts/mb.sh" '^PMB_GITIGNORE_ENTRIES=[(]')"
PS_GI="$(_gi_entries "$REPO_ROOT/scripts/mb.ps1" '^[$]PmbGitignoreEntries = @[(]')"
assert_contains "$SH_GI" "contracts" "mb.sh gitignore entry list was extracted (non-vacuous)"
assert_equals "$PS_GI" "$SH_GI" "mb.ps1 and mb.sh gitignore entry lists are identical"

echo ""
echo "--- --dry-run is refused outside upgrade/update ---"
# The rationale lives at the guard in scripts/mb.sh; mb.ps1's guard is covered by
# tests/mb-dry-run-guard.Tests.ps1. The later-position lines are the forms where the flag is not $2.
TMPDIR_DRYGUARD="$(mktemp -d 2>/dev/null || mktemp -d -t mb-dry-guard)"
# WHY both: each EXIT trap in this file replaces the last, and TMPDIR_GIDRY is still unremoved.
trap 'rm -rf "$TMPDIR_DRYGUARD" "$TMPDIR_GIDRY"' EXIT
mkdir -p "$TMPDIR_DRYGUARD/memory-bank"
while read -r line; do
    # shellcheck disable=SC2086  # word-splitting $line into arguments is the point
    # </dev/null: the loop's stdin is the case list, which a command run unguarded must not eat.
    output=$(cd "$TMPDIR_DRYGUARD" && MB_HOME="$REPO_ROOT" bash "$MB" $line 2>&1 </dev/null)
    assert_equals "$?" "1" "mb $line exits 1"
    # The pattern omits the leading "--dry-run": assert_contains hands it to grep as an argument.
    assert_contains "$output" "dry-run is only supported by 'mb upgrade', not 'mb ${line%% *}'" \
        "mb $line names the command in its error"
done <<'EOF'
init --dry-run
doctor --dry-run
status --dry-run
query --dry-run
help --dry-run
init . --dry-run
plan list --dry-run
backlog add t --dry-run
EOF
assert_equals "$(ls -A "$TMPDIR_DRYGUARD")" "memory-bank" "refused --dry-run commands wrote nothing"

# WHY: update is a live upgrade alias in mb.sh, so its --dry-run must keep working.
setup_test_project "$TMPDIR_DRYGUARD"
output=$(cd "$TMPDIR_DRYGUARD" && MB_HOME="$REPO_ROOT" bash "$MB" update --dry-run 2>&1)
assert_contains "$output" "dry run" "mb update --dry-run is still a dry run"

# WHY: upgrade/update read --dry-run only from $2 before, so a flag after another argument ran a
# REAL upgrade (measured: .claude/, .githooks/, standards/ written). A bare memory-bank/ shows it.
for cmd in upgrade update; do
    TMPDIR_DRYLATE="$(mktemp -d 2>/dev/null || mktemp -d -t mb-dry-late)"
    mkdir -p "$TMPDIR_DRYLATE/memory-bank"
    output=$(cd "$TMPDIR_DRYLATE" && MB_HOME="$REPO_ROOT" bash "$MB" "$cmd" x --dry-run 2>&1 </dev/null)
    assert_contains "$output" "dry run" "mb $cmd x --dry-run is a dry run"
    assert_equals "$(ls -A "$TMPDIR_DRYLATE")" "memory-bank" "mb $cmd x --dry-run wrote nothing"
    # WHY a positive control: "wrote nothing" would also pass if the flag were always on.
    output=$(cd "$TMPDIR_DRYLATE" && MB_HOME="$REPO_ROOT" bash "$MB" "$cmd" x 2>&1 </dev/null)
    assert_file_exists "$TMPDIR_DRYLATE/.pmb-version" "mb $cmd x without --dry-run still upgrades for real"
    rm -rf "$TMPDIR_DRYLATE"
done

echo ""
echo "--- no shipped doc teaches mb update as an AI chat shortcut ---"
# WHY: `mb update` is a CLI command (a live upgrade alias in mb.sh), and these files once also
# taught it as a chat shortcut for "update the memory bank", so a reader could run a real upgrade
# meaning to ask the AI. The shortcut is "update memory bank"; this keeps the old one from returning.
SHORTCUT_DOCS="standards/MEMORY-BANK.md templates/standards/MEMORY-BANK.md .cursor/rules/memory-bank.mdc templates/cursor/rules/memory-bank.mdc templates/memory-bank/README.md docs/QUICK-REFERENCE.md docs/SETUP-GUIDE.md scripts/init-memory-bank.sh scripts/init-memory-bank.ps1"
stale_shortcut=""
for f in $SHORTCUT_DOCS; do
    assert_file_exists "$REPO_ROOT/$f" "$f exists (keeps this check non-vacuous)"
    grep -q "mb update" "$REPO_ROOT/$f" && stale_shortcut="$stale_shortcut $f"
done
assert_equals "$stale_shortcut" "" "no chat-shortcut doc mentions mb update"

# ── settings.json: permissions are merged, never overwritten ─────────────────
# WHY: settings.json was force-copied, which silently deleted an adopter's deny rules (signing
# bypass, --no-verify, gh pr merge) on upgrade -- found in the AI-Code-Review-Agent repo's dry run,
# 2026-10-24. Each mb upgrade costs about a minute here, so one fixture carries every case: a BOM
# and CRLF file (Windows editors), project rules in every list, a one-element ask list (must stay
# an array), a non-ASCII rule, governance-weakening keys that must NOT survive, and flag triggers.
echo ""
echo "--- settings.json: upgrade merges permissions ---"

TMPDIR_SJ="$(mktemp -d 2>/dev/null || mktemp -d -t mb-settings-merge)"
trap 'rm -rf "$TMPDIR_SJ"' EXIT
setup_test_project "$TMPDIR_SJ"
SJ="$TMPDIR_SJ/.claude/settings.json"
SJ_FIXTURE="$TMPDIR_SJ/fixture-settings.json"
python3 - "$REPO_ROOT/templates/.claude/settings.json" "$SJ_FIXTURE" <<'PYEOF'
import json, sys
s = json.load(open(sys.argv[1], encoding="utf-8"))
p = s["permissions"]
p["allow"] = p["allow"][:3] + ["Bash(npm ci)", "Bash", "mcp__gh__merge_pull_request", "Bash(echo café)", "Bash(retired-thing)", "mcp__x__Merge_PR", "Bash(*)"]
p["deny"] = ["Bash(gh pr merge *)"]
p["ask"] = ["Bash(rm *)"]
p["additionalDirectories"] = ["../shared"]
p["disableBypassPermissionsMode"] = "disable"
p["defaultMode"] = "acceptEdits"
s["disableAllHooks"] = True
s["apiKeyHelper"] = "helper.sh"
s["env"]["PROJECT_ONLY"] = "1"
del s["hooks"]["Stop"]
text = json.dumps(s, indent=2, ensure_ascii=False).replace("\n", "\r\n")
open(sys.argv[2], "w", encoding="utf-8-sig", newline="").write(text)
PYEOF
cp "$SJ_FIXTURE" "$SJ"

# Prints one key=value line per property the assertions below check.
_sj_facts() {
    python3 - "$1" "$REPO_ROOT/templates/.claude/settings.json" <<'PYEOF'
import json, sys
m = json.load(open(sys.argv[1], encoding="utf-8-sig")); t = json.load(open(sys.argv[2], encoding="utf-8"))
p = m.get("permissions", {})
print("deny_project=%s" % ("Bash(gh pr merge *)" in p.get("deny", [])))
print("deny_template=%s" % all(e in p.get("deny", []) for e in t["permissions"]["deny"]))
print("allow_project=%s" % ("Bash(npm ci)" in p.get("allow", [])))
print("allow_template=%s" % all(e in p.get("allow", []) for e in t["permissions"]["allow"]))
print("allow_nonascii=%s" % ("Bash(echo café)" in p.get("allow", [])))
print("ask=%s" % json.dumps(p.get("ask")))
print("dirs=%s" % json.dumps(p.get("additionalDirectories")))
print("bypass=%s" % p.get("disableBypassPermissionsMode"))
print("defaultMode=%s" % ("defaultMode" in p))
print("disableAllHooks=%s" % ("disableAllHooks" in m))
print("apiKeyHelper=%s" % ("apiKeyHelper" in m))
print("hooks_equal=%s" % (m.get("hooks") == t["hooks"]))
print("env_equal=%s" % (m.get("env") == t["env"]))
raw = open(sys.argv[1], "rb").read()
print("bom=%s crlf=%s" % (raw.startswith(b"\xef\xbb\xbf"), b"\r\n" in raw))
PYEOF
}

# WHY a planted module: the merge runs python in the project directory; without -I a project's own
# subprocess.py would be imported and executed in place of the standard library's.
printf 'open("PLANTED-MODULE-RAN", "w").close()\n' > "$TMPDIR_SJ/subprocess.py"
output=$(cd "$TMPDIR_SJ" && MB_HOME="$REPO_ROOT" bash "$MB" upgrade 2>&1)
assert_exit_zero $? "settings merge: mb upgrade exits 0"
assert_file_not_exists "$TMPDIR_SJ/PLANTED-MODULE-RAN" "settings merge: a project's own subprocess.py is never imported"
rm -f "$TMPDIR_SJ/subprocess.py"
facts=$(_sj_facts "$SJ")
assert_contains "$output" "\[~\] .claude/settings.json (updated; kept 11 project permission rules)" "settings merge: reports update and kept-rule count"
assert_contains "$facts" "deny_project=True" "settings merge: project deny rule survives"
assert_contains "$facts" "deny_template=True" "settings merge: template deny rules added"
assert_contains "$facts" "allow_project=True" "settings merge: project allow rule survives"
assert_contains "$facts" "allow_template=True" "settings merge: template allow rules present"
assert_contains "$facts" "allow_nonascii=True" "settings merge: non-ASCII rule survives a BOM+CRLF file"
assert_contains "$facts" 'ask=\["Bash(rm \*)"\]' "settings merge: one-element ask list stays an array"
assert_contains "$facts" 'dirs=\["../shared"\]' "settings merge: additionalDirectories survives"
assert_contains "$facts" "bypass=disable" "settings merge: disableBypassPermissionsMode survives"
assert_contains "$facts" "defaultMode=False" "settings merge: permissions.defaultMode dropped"
assert_contains "$facts" "disableAllHooks=False" "settings merge: disableAllHooks dropped"
assert_contains "$facts" "apiKeyHelper=False" "settings merge: apiKeyHelper dropped"
assert_contains "$facts" "hooks_equal=True" "settings merge: hooks come from the template"
assert_contains "$facts" "env_equal=True" "settings merge: env comes from the template"
assert_contains "$facts" "bom=False crlf=False" "settings merge: written as UTF-8 without BOM, LF"
assert_contains "$output" "kept deny: Bash(gh pr merge \*)" "settings merge: kept deny rule is named"
assert_contains "$output" "dropped top-level key disableAllHooks" "settings merge: dropped disableAllHooks is named"
assert_contains "$output" "dropped permissions.defaultMode" "settings merge: dropped defaultMode is named"
assert_contains "$output" "dropped env.PROJECT_ONLY" "settings merge: dropped env key is named"
assert_contains "$output" "replaced hooks with the template's" "settings merge: replaced hooks are named"
assert_contains "$output" "\[!\] kept allow rule mentions merge.*mcp__gh__merge_pull_request" "settings merge: MCP merge allow flagged"
assert_contains "$output" "\[!\] kept allow rule mentions merge.*mcp__x__Merge_PR" "settings merge: merge flag is case-insensitive"
assert_not_contains "$output" "mentions merge.*Bash(gh" "settings merge: a kept deny rule is never merge-flagged (allow only)"
assert_contains "$output" "\[!\] kept allow rule is broad: Bash$" "settings merge: bare-tool allow flagged"
assert_contains "$output" "\[!\] kept allow rule is broad: Bash(\*)$" "settings merge: Tool(*) allow flagged"
assert_not_contains "$output" "PMB no longer ships" "settings merge: nothing flagged as retired against the real history"
SJ_MERGED_HASH=$(git hash-object "$SJ")

# A second run must recognise its own output: no rewrite, no "updated".
output=$(cd "$TMPDIR_SJ" && MB_HOME="$REPO_ROOT" bash "$MB" upgrade 2>&1)
assert_contains "$output" "\[=\] .claude/settings.json (unchanged; keeps 11 project permission rules)" "settings merge: second run reports unchanged"
assert_equals "$(git hash-object "$SJ")" "$SJ_MERGED_HASH" "settings merge: second run leaves the file byte-identical"

echo ""
echo "--- settings.json: --dry-run shows the merge, writes nothing; retired rules flagged ---"
# WHY a scratch PMB home: no rule has ever been removed from the real template, so the retired-rule
# flag needs a history where one was. Only templates/ and VERSION are copied (git ls-files, never
# the worktree itself, whose .git pointer would let commits land in the real branch).
FAKE_HOME="$TMPDIR_SJ/pmb-home"
mkdir -p "$FAKE_HOME"
(cd "$REPO_ROOT" && git ls-files templates VERSION | tar -cf - -T -) | (cd "$FAKE_HOME" && tar -xf -)
(
    set -e
    cd "$FAKE_HOME"
    git init -q
    git config user.email "test@test.com"; git config user.name "Test"; git config commit.gpgsign false
    cp templates/.claude/settings.json "$TMPDIR_SJ/current-template.json"
    python3 - templates/.claude/settings.json <<'PYEOF'
import json, sys
s = json.load(open(sys.argv[1], encoding="utf-8"))
s["permissions"]["allow"].append("Bash(retired-thing)")
open(sys.argv[1], "w", encoding="utf-8", newline="\n").write(json.dumps(s, indent=2) + "\n")
PYEOF
    git add -A; git commit -q -m "ship retired-thing"
    cp "$TMPDIR_SJ/current-template.json" templates/.claude/settings.json
    git add -A; git commit -q -m "withdraw retired-thing"
)
cp "$SJ_FIXTURE" "$SJ"
CMD_FILE="$(cd "$TMPDIR_SJ" && ls .claude/commands/*.md | head -1)"
printf 'local edit\n' >> "$TMPDIR_SJ/$CMD_FILE"
SJ_BEFORE=$(git hash-object "$SJ"); CMD_BEFORE=$(git hash-object "$TMPDIR_SJ/$CMD_FILE")
output=$(cd "$TMPDIR_SJ" && MB_HOME="$FAKE_HOME" bash "$MB" upgrade --dry-run 2>&1)
assert_equals "$(git hash-object "$SJ")" "$SJ_BEFORE" "dry run: settings.json untouched"
assert_equals "$(git hash-object "$TMPDIR_SJ/$CMD_FILE")" "$CMD_BEFORE" "dry run: edited command file untouched"
assert_contains "$output" "\[~?\] .claude/settings.json (would update, +[0-9][0-9]*/-[0-9][0-9]* lines; keeps 11 project permission rules)" "dry run: settings.json line counts and kept count"
assert_contains "$output" "\[~?\] $CMD_FILE (would update, +0/-1 lines)" "dry run: template-owned file shows its line counts"
assert_contains "$output" "^      -  \"disableAllHooks\": true," "dry run: merged diff shows the dropped key"
assert_contains "$output" "\[!\] PMB no longer ships this rule; kept -- remove it if unneeded: allow Bash(retired-thing)" "dry run: retired template rule flagged"
assert_equals "$(cd "$TMPDIR_SJ/.claude" && ls -a | grep -c 'mb-upgrade')" "0" "dry run: no temp file left behind"

echo ""
echo "--- settings.json: invalid JSON is left untouched ---"
printf '{ "permissions": { "deny": ["Bash(gh pr merge *)"], }\n' > "$SJ"
SJ_BEFORE=$(git hash-object "$SJ")
output=$(cd "$TMPDIR_SJ" && MB_HOME="$REPO_ROOT" bash "$MB" upgrade 2>&1)
assert_exit_zero $? "invalid JSON: mb upgrade still exits 0"
assert_contains "$output" "\[!\] .claude/settings.json not updated: project file is not valid JSON" "invalid JSON: [!] names the reason"
assert_equals "$(git hash-object "$SJ")" "$SJ_BEFORE" "invalid JSON: file untouched"

echo ""
echo "--- settings.json: no runnable python leaves the file untouched ---"
# WHY a stub that exists but fails: the Windows Store python3 alias is on PATH yet runs nothing,
# so a command -v check would pass and the merge would fall through.
STUB="$TMPDIR_SJ/stub-bin"; mkdir -p "$STUB"
printf '#!/bin/sh\nexit 9009\n' > "$STUB/python3"; cp "$STUB/python3" "$STUB/python"; chmod +x "$STUB/python3" "$STUB/python"
cp "$SJ_FIXTURE" "$SJ"
SJ_BEFORE=$(git hash-object "$SJ")
assert_equals "$(PATH="$STUB:$PATH" command -v python3)" "$STUB/python3" "no python: the stub shadows python3 (non-vacuous)"
output=$(cd "$TMPDIR_SJ" && PATH="$STUB:$PATH" MB_HOME="$REPO_ROOT" bash "$MB" upgrade 2>&1)
assert_contains "$output" "\[!\] .claude/settings.json not updated: no runnable python3/python" "no python: [!] names the reason"
assert_equals "$(git hash-object "$SJ")" "$SJ_BEFORE" "no python: file untouched"

print_summary
