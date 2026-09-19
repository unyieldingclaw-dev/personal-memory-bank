#!/usr/bin/env bash
# tests/test-mb-doctor.sh — tests for mb doctor (all 25 checks + clean baseline)
set -u

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
MB="$REPO_ROOT/scripts/mb.sh"
source "$REPO_ROOT/tests/helpers/assert.sh"
source "$REPO_ROOT/tests/setup.sh"

echo "=== mb doctor tests ==="

# Helper: write a minimal memory-bank file with frontmatter
write_mb_file() {
    local path="$1" authority="$2" threshold="$3"
    cat > "$path" <<EOF
---
authority: $authority
last-reviewed: $(date +%Y-%m-%d)
staleness-threshold: ${threshold}d
---
# $(basename "$path")
Test content.
EOF
}

# Helper: fully set up TMPDIR_DOC with everything doctor needs (no warnings)
setup_doctor_project() {
    local dir="$1"
    setup_test_project "$dir"

    mkdir -p "$dir/.claude"
    cat > "$dir/.claude/settings.json" <<'JSON'
{
  "hooks": {
    "PostToolUse": [{"matcher": "Edit", "hooks": [{"type": "command", "command": "scripts/update-last-reviewed.sh"}]}]
  }
}
JSON

    mkdir -p "$dir/scripts"
    echo "#!/usr/bin/env bash" > "$dir/scripts/update-last-reviewed.sh"
    chmod +x "$dir/scripts/update-last-reviewed.sh"

    mkdir -p "$dir/.githooks"
    echo "#!/usr/bin/env bash" > "$dir/.githooks/pre-push"
    chmod +x "$dir/.githooks/pre-push"

    (cd "$dir" && git config core.hooksPath .githooks)

    cp "$REPO_ROOT/VERSION" "$dir/.pmb-version"

    mkdir -p "$dir/docs/plans"

    (cd "$dir" && git add -A && git commit -q -m "doctor-test-setup" 2>/dev/null)
}

# Restore a standard memory-bank file to clean state
restore_mb() {
    local dir="$1" f="$2" authority="$3" threshold="$4"
    write_mb_file "$dir/memory-bank/$f" "$authority" "$threshold"
}

# ── Shared project used for individual check tests ────────────────────────────
TMPDIR_DOC="$(mktemp -d 2>/dev/null || mktemp -d -t mb-doc-test)"
trap 'rm -rf "$TMPDIR_DOC"' EXIT

setup_doctor_project "$TMPDIR_DOC"

# ── Baseline: clean project — no [ERROR] expected ────────────────────────────
echo ""
echo "--- baseline: clean project ---"

TMPDIR_CLEAN="$(mktemp -d 2>/dev/null || mktemp -d -t mb-clean-baseline)"
trap 'rm -rf "$TMPDIR_CLEAN"' EXIT

setup_doctor_project "$TMPDIR_CLEAN"

output=$(cd "$TMPDIR_CLEAN" && MB_HOME="$REPO_ROOT" bash "$MB" doctor 2>&1)
if echo "$output" | grep -q "\[ERROR\]"; then
    echo "  FAIL: baseline — unexpected [ERROR] in clean project"
    echo "    Errors found:"
    echo "$output" | grep "\[ERROR\]" | sed 's/^/      /'
    FAIL=$((FAIL + 1))
else
    echo "  PASS: baseline — clean project has no [ERROR]"
    PASS=$((PASS + 1))
fi

# ── Check 0: VERSION file not found ──────────────────────────────────────────
echo ""
echo "--- check 0: VERSION file not found ---"

trap 'mv "$REPO_ROOT/VERSION.bak" "$REPO_ROOT/VERSION" 2>/dev/null || true; trap - EXIT' EXIT
mv "$REPO_ROOT/VERSION" "$REPO_ROOT/VERSION.bak"
output=$(cd "$TMPDIR_DOC" && MB_HOME="$REPO_ROOT" bash "$MB" doctor 2>&1)
mv "$REPO_ROOT/VERSION.bak" "$REPO_ROOT/VERSION"
trap - EXIT

assert_contains "$output" "\[WARN\] VERSION file not found" "check 0: VERSION file missing → [WARN]"

# ── Check 1: Not a git repository ────────────────────────────────────────────
echo ""
echo "--- check 1: not a git repository ---"

TMPDIR_NOGIT="$(mktemp -d 2>/dev/null || mktemp -d -t mb-nogit-test)"
trap 'rm -rf "$TMPDIR_NOGIT"' EXIT

mkdir -p "$TMPDIR_NOGIT/memory-bank"
for f in projectbrief.md systemPatterns.md techContext.md activeContext.md progress.md; do
    write_mb_file "$TMPDIR_NOGIT/memory-bank/$f" "stable" "90"
done
echo "# Project" > "$TMPDIR_NOGIT/CLAUDE.md"
echo "CLAUDE_AUTOCOMPACT_PCT_OVERRIDE=40" >> "$TMPDIR_NOGIT/CLAUDE.md"

output=$(cd "$TMPDIR_NOGIT" && MB_HOME="$REPO_ROOT" bash "$MB" doctor 2>&1)
rc=$?
assert_contains "$output" "\[WARN\] Not a git repository" "check 1: non-git dir → [WARN]"

# WHY the next two assertions reuse this fixture rather than adding another: the [WARN] above is
# emitted in the first ~20 lines, so it kept passing while doctor was ABORTING a few checks later
# and nothing noticed. Under `set -e` a bare `VAR=$(git ...)` assignment kills the script when git
# exits 128 outside a repo — `2>/dev/null` hides the message, not the status. Three such sites
# existed at three different depths. Provenance, blamed rather than assumed: `last_commit` (check
# 21) and `COMMIT_30D` (in the Startup Context block, which precedes show_budget — an earlier
# draft of this comment placed it in Token Budget) both came from `030662c`, which is on main;
# `_mb_common` came from `e1d77f2` — the startup-context ratchet, which is branch-only and NOT on
# main, so this branch introduced that one and shipped it through review. That same earlier draft
# credited it to the check-25 work and called all three inherited; both were wrong. Because the
# three sit at different depths, an assertion naming any single check catches only one. These
# assert the INVARIANT instead — doctor runs to completion outside a repo — which catches a future
# site wherever it is added. Every other fixture in this file git-inits, so this is the only place
# the invariant can be tested.
assert_equals "$rc" "0" "check 1: non-git dir — doctor exits 0, not git's 128"
assert_contains "$output" "Token Budget Health" "check 1: non-git dir — doctor runs to completion (final section emitted)"

# ── Check 2: Templates not found ─────────────────────────────────────────────
echo ""
echo "--- check 2: templates not found ---"

# WHY MB_HOME points at an empty temp dir instead of renaming anything: doctor's check 2
# tests `-d "$REPO_ROOT/templates"` — the templates PARENT. The previous fixture renamed
# `templates/memory-bank` (a subdirectory, deliberately, since renaming the whole dir risks
# data loss if a restore is interrupted), which left the parent in place, so doctor
# correctly reported [OK] and [ERROR] never appeared. The assertion nevertheless "passed"
# for the entire life of this test because its unescaped `[ERROR]` was a grep character
# class matching almost any output. Escaping it surfaced the real failure.
#
# Pointing MB_HOME at a directory with no templates/ exercises the genuine [ERROR] branch
# and touches no real files at all — no rename, no restore, no data-loss window.
TMPDIR_NOTPL="$(mktemp -d 2>/dev/null || mktemp -d -t mb-doc-notpl)"
output=$(cd "$TMPDIR_DOC" && MB_HOME="$TMPDIR_NOTPL" bash "$MB" doctor 2>&1)
rm -rf "$TMPDIR_NOTPL"

# Brackets escaped: assert_contains uses `grep -qi`, so an unescaped `[ERROR]` is a
# character class matching any one of E/R/O — it matched almost any output, making this
# assertion vacuous (it passed regardless of whether doctor reported an error).
assert_contains "$output" "\[ERROR\] Templates not found" "check 2: templates missing → [ERROR]"

# ── Check 3: memory-bank files missing ───────────────────────────────────────
echo ""
echo "--- check 3: memory-bank files missing ---"

TMPDIR_NOMEM="$(mktemp -d 2>/dev/null || mktemp -d -t mb-nomem-test)"
trap 'rm -rf "$TMPDIR_NOMEM"' EXIT

mkdir -p "$TMPDIR_NOMEM/memory-bank" "$TMPDIR_NOMEM/standards"
for s in WORKFLOW.md CODE-QUALITY.md SECURITY-GUARDRAILS.md CODE-REVIEW.md; do
    echo "# $s" > "$TMPDIR_NOMEM/standards/$s"
done
echo "# Project" > "$TMPDIR_NOMEM/CLAUDE.md"
echo "CLAUDE_AUTOCOMPACT_PCT_OVERRIDE=40" >> "$TMPDIR_NOMEM/CLAUDE.md"
(cd "$TMPDIR_NOMEM" && git init -q && git config user.email t@t.com && git config user.name T && git commit -q --allow-empty -m init)

output=$(cd "$TMPDIR_NOMEM" && MB_HOME="$REPO_ROOT" bash "$MB" doctor 2>&1)
assert_contains "$output" "\[ERROR\] One or more memory-bank files missing" "check 3: memory-bank files missing → [ERROR]"

# ── Check 3b: CLAUDE.md missing ──────────────────────────────────────────────
echo ""
echo "--- check 3b: CLAUDE.md missing ---"

TMPDIR_NOCLAUDEMD="$(mktemp -d 2>/dev/null || mktemp -d -t mb-noclaudemd-test)"
trap 'rm -rf "$TMPDIR_NOCLAUDEMD"' EXIT

mkdir -p "$TMPDIR_NOCLAUDEMD/memory-bank" "$TMPDIR_NOCLAUDEMD/standards"
for f in projectbrief.md systemPatterns.md techContext.md activeContext.md progress.md; do
    write_mb_file "$TMPDIR_NOCLAUDEMD/memory-bank/$f" "stable" "90"
done
for s in WORKFLOW.md CODE-QUALITY.md SECURITY-GUARDRAILS.md CODE-REVIEW.md; do
    echo "# $s" > "$TMPDIR_NOCLAUDEMD/standards/$s"
done
# No CLAUDE.md
(cd "$TMPDIR_NOCLAUDEMD" && git init -q && git config user.email t@t.com && git config user.name T && git commit -q --allow-empty -m init)

output=$(cd "$TMPDIR_NOCLAUDEMD" && MB_HOME="$REPO_ROOT" bash "$MB" doctor 2>&1)
assert_contains "$output" "\[ERROR\] CLAUDE.md missing" "check 3b: CLAUDE.md missing → [ERROR]"

# ── Check 4: No .claude/settings.json ────────────────────────────────────────
echo ""
echo "--- check 4: no .claude/settings.json ---"

TMPDIR_NOSETTINGS="$(mktemp -d 2>/dev/null || mktemp -d -t mb-nosettings-test)"
trap 'rm -rf "$TMPDIR_NOSETTINGS"' EXIT

setup_test_project "$TMPDIR_NOSETTINGS"
# setup_test_project does NOT create .claude/settings.json

output=$(cd "$TMPDIR_NOSETTINGS" && MB_HOME="$REPO_ROOT" bash "$MB" doctor 2>&1)
assert_contains "$output" "\[WARN\] No .claude/settings.json" "check 4: no settings.json → [WARN]"

# ── Check 4b: settings.json exists but no PostToolUse hook ───────────────────
echo ""
echo "--- check 4b: settings.json without PostToolUse hook ---"

TMPDIR_NOHOOK="$(mktemp -d 2>/dev/null || mktemp -d -t mb-nohook-test)"
trap 'rm -rf "$TMPDIR_NOHOOK"' EXIT

setup_test_project "$TMPDIR_NOHOOK"
mkdir -p "$TMPDIR_NOHOOK/.claude"
echo '{"hooks": {}}' > "$TMPDIR_NOHOOK/.claude/settings.json"

output=$(cd "$TMPDIR_NOHOOK" && MB_HOME="$REPO_ROOT" bash "$MB" doctor 2>&1)
assert_contains "$output" "\[WARN\] No PostToolUse hook" "check 4b: settings.json no PostToolUse → [WARN]"

# ── Check 4c: .githooks/pre-push missing ─────────────────────────────────────
echo ""
echo "--- check 4c: .githooks/pre-push missing ---"

TMPDIR_NOPREPUSH="$(mktemp -d 2>/dev/null || mktemp -d -t mb-noprepush-test)"
trap 'rm -rf "$TMPDIR_NOPREPUSH"' EXIT

setup_test_project "$TMPDIR_NOPREPUSH"
mkdir -p "$TMPDIR_NOPREPUSH/.claude" "$TMPDIR_NOPREPUSH/scripts"
cat > "$TMPDIR_NOPREPUSH/.claude/settings.json" <<'JSON'
{"hooks": {"PostToolUse": [{"matcher": "Edit", "hooks": [{"type": "command", "command": "scripts/update-last-reviewed.sh"}]}]}}
JSON
echo "#!/usr/bin/env bash" > "$TMPDIR_NOPREPUSH/scripts/update-last-reviewed.sh"
# No .githooks/pre-push

output=$(cd "$TMPDIR_NOPREPUSH" && MB_HOME="$REPO_ROOT" bash "$MB" doctor 2>&1)
assert_contains "$output" "\[WARN\] .githooks/pre-push missing" "check 4c: .githooks/pre-push missing → [WARN]"

# ── Check 4d: core.hooksPath not set to .githooks ────────────────────────────
echo ""
echo "--- check 4d: core.hooksPath not set ---"

TMPDIR_NOHOOKSPATH="$(mktemp -d 2>/dev/null || mktemp -d -t mb-nohookspath-test)"
trap 'rm -rf "$TMPDIR_NOHOOKSPATH"' EXIT

setup_test_project "$TMPDIR_NOHOOKSPATH"
mkdir -p "$TMPDIR_NOHOOKSPATH/.claude" "$TMPDIR_NOHOOKSPATH/scripts" "$TMPDIR_NOHOOKSPATH/.githooks"
cat > "$TMPDIR_NOHOOKSPATH/.claude/settings.json" <<'JSON'
{"hooks": {"PostToolUse": [{"matcher": "Edit", "hooks": [{"type": "command", "command": "scripts/update-last-reviewed.sh"}]}]}}
JSON
echo "#!/usr/bin/env bash" > "$TMPDIR_NOHOOKSPATH/scripts/update-last-reviewed.sh"
echo "#!/usr/bin/env bash" > "$TMPDIR_NOHOOKSPATH/.githooks/pre-push"
# core.hooksPath NOT set to .githooks (leave at default)

output=$(cd "$TMPDIR_NOHOOKSPATH" && MB_HOME="$REPO_ROOT" bash "$MB" doctor 2>&1)
assert_contains "$output" "\[WARN\] core.hooksPath not set to .githooks" "check 4d: core.hooksPath not set → [WARN]"

# ── Check 5: Token Budget drift ───────────────────────────────────────────────
echo ""
echo "--- check 5: token budget drift ---"

# WHY: Previously mb.sh used `grep -c ... || echo 0` which on Git Bash produced "0\n0"
# on no-match (grep exits 1, || fires, appending a second 0). Fixed in mb.sh to use
# grep -q + explicit 0/1 assignment. Check 5 now runs correctly on all platforms.
#
# WHY this fixture writes a settings.json value: check 5 was rewritten 2026-08-25 to compare
# the THRESHOLD each instruction file states against the live setting, rather than testing
# whether the variable NAME appears in both files. The old form reported "[OK] Token Budget
# section current" while ~/.claude/CLAUDE.md hardcoded 50% against a settings.json of 65 --
# a presence check reported as a correctness check. With no value in settings.json there is
# no ground truth to compare against and the check correctly SKIPs, so the fixture has to
# supply one.

TMPDIR_DRIFT="$(mktemp -d 2>/dev/null || mktemp -d -t mb-drift-test)"
trap 'rm -rf "$TMPDIR_DRIFT"' EXIT

setup_doctor_project "$TMPDIR_DRIFT"
# Ground truth for the comparison: 65.
cat > "$TMPDIR_DRIFT/.claude/settings.json" <<'JSON'
{
  "env": {"CLAUDE_AUTOCOMPACT_PCT_OVERRIDE": "65"},
  "hooks": {
    "PostToolUse": [{"matcher": "Edit", "hooks": [{"type": "command", "command": "scripts/update-last-reviewed.sh"}]}]
  }
}
JSON
FAKE_HOME="$(mktemp -d 2>/dev/null || mktemp -d -t mb-drift-home)"
trap 'rm -rf "$FAKE_HOME"' EXIT
mkdir -p "$FAKE_HOME/.claude"
# Global file states a threshold that disagrees with settings.json — this is the drift.
echo "auto-compact fires at 40% context" > "$FAKE_HOME/.claude/CLAUDE.md"
# Local file states no number at all: deferring is correct and must NOT be flagged.
echo "# Project" > "$TMPDIR_DRIFT/CLAUDE.md"

output=$(cd "$TMPDIR_DRIFT" && HOME="$FAKE_HOME" MB_HOME="$REPO_ROOT" bash "$MB" doctor 2>&1)
assert_contains "$output" "\[WARN\].*Token Budget drift" "check 5: stated 40% vs live 65% → [WARN]"
assert_contains "$output" "states 40%" "check 5: names the drifted value"

# Discrimination: a stated value that AGREES must not warn. WHY this case exists: without it
# the assertion above passes just as well for a check that warns unconditionally, which is
# exactly the defect being fixed here -- a check that cannot fail does not count as a check.
echo "auto-compact fires at 65% context" > "$FAKE_HOME/.claude/CLAUDE.md"
output=$(cd "$TMPDIR_DRIFT" && HOME="$FAKE_HOME" MB_HOME="$REPO_ROOT" bash "$MB" doctor 2>&1)
assert_contains "$output" "\[OK\].*Token Budget" "check 5: agreeing value → [OK] (discrimination)"

# ── Check 6: File size over limit ─────────────────────────────────────────────
echo ""
echo "--- check 6: file size over limit ---"

{
    echo "---"
    echo "authority: volatile"
    echo "last-reviewed: $(date +%Y-%m-%d)"
    echo "staleness-threshold: 14d"
    echo "---"
    echo "# activeContext"
    for i in $(seq 1 151); do echo "Entry $i: some active context content here."; done
} > "$TMPDIR_DOC/memory-bank/activeContext.md"

output=$(cd "$TMPDIR_DOC" && MB_HOME="$REPO_ROOT" bash "$MB" doctor 2>&1)
assert_contains "$output" "is 15" "check 6: oversized file → [WARN] with line count"
assert_contains "$output" "run 'mb clean'" "check 6: oversized file mentions mb clean"

# Restore activeContext.md
restore_mb "$TMPDIR_DOC" "activeContext.md" "volatile" "14"

# ── Check 7: handoff.md found ─────────────────────────────────────────────────
echo ""
echo "--- check 7: handoff.md found ---"

echo "# Handoff" > "$TMPDIR_DOC/handoff.md"
output=$(cd "$TMPDIR_DOC" && MB_HOME="$REPO_ROOT" bash "$MB" doctor 2>&1)
assert_contains "$output" "handoff.md found" "check 7: handoff.md present → [WARN]"

rm -f "$TMPDIR_DOC/handoff.md"

# ── Check 8: compaction_generation >= 3 ──────────────────────────────────────
echo ""
echo "--- check 8: high compaction_generation ---"

cat > "$TMPDIR_DOC/memory-bank/progress.md" <<EOF
---
authority: accumulating
compaction_generation: 3
last-reviewed: $(date +%Y-%m-%d)
staleness-threshold: 30d
---
# Progress
Test content.
EOF

output=$(cd "$TMPDIR_DOC" && MB_HOME="$REPO_ROOT" bash "$MB" doctor 2>&1)
assert_contains "$output" "compaction_generation=3" "check 8: compaction_generation=3 → [WARN]"

# Restore
restore_mb "$TMPDIR_DOC" "progress.md" "accumulating" "30"

# ── Check 9: stale files ──────────────────────────────────────────────────────
echo ""
echo "--- check 9: stale files ---"

cat > "$TMPDIR_DOC/memory-bank/activeContext.md" <<'EOF'
---
authority: volatile
last-reviewed: 2020-01-01
staleness-threshold: 14d
---
# activeContext
Test content.
EOF

output=$(cd "$TMPDIR_DOC" && MB_HOME="$REPO_ROOT" bash "$MB" doctor 2>&1)
assert_contains "$output" "stale memory-bank file" "check 9: stale file warning message"

# Restore
restore_mb "$TMPDIR_DOC" "activeContext.md" "volatile" "14"

# ── Check 10: placeholder text ────────────────────────────────────────────────
echo ""
echo "--- check 10: placeholder text ---"

cat > "$TMPDIR_DOC/memory-bank/techContext.md" <<EOF
---
authority: stable
last-reviewed: $(date +%Y-%m-%d)
staleness-threshold: 90d
---
# Tech Context
TODO: fill this in.
EOF

output=$(cd "$TMPDIR_DOC" && MB_HOME="$REPO_ROOT" bash "$MB" doctor 2>&1)
assert_contains "$output" "placeholder text detected" "check 10: placeholder text warning message"

# Restore
restore_mb "$TMPDIR_DOC" "techContext.md" "stable" "90"

# ── Check 11: missing required standards file ─────────────────────────────────
echo ""
echo "--- check 11: missing standards file ---"

rm -f "$TMPDIR_DOC/standards/WORKFLOW.md"
output=$(cd "$TMPDIR_DOC" && MB_HOME="$REPO_ROOT" bash "$MB" doctor 2>&1)
assert_contains "$output" "WORKFLOW.md not found" "check 11: missing standards file → [WARN]"

# Restore
echo "# WORKFLOW" > "$TMPDIR_DOC/standards/WORKFLOW.md"

# ── Check 12: no .pmb-version ─────────────────────────────────────────────────
echo ""
echo "--- check 12: no .pmb-version ---"

rm -f "$TMPDIR_DOC/.pmb-version"
output=$(cd "$TMPDIR_DOC" && MB_HOME="$REPO_ROOT" bash "$MB" doctor 2>&1)
assert_contains "$output" "No .pmb-version found" "check 12: no .pmb-version → [WARN]"

# Restore
cp "$REPO_ROOT/VERSION" "$TMPDIR_DOC/.pmb-version"

# ── Check 13: fixtures/security/ missing ──────────────────────────────────────
echo ""
echo "--- check 13: fixtures/security/ missing ---"

# Rename only one fixture subdir — safer than renaming the entire security/ dir
SEC001="$REPO_ROOT/fixtures/security/SEC-001-hardcoded-secret"
trap '[ -d "${SEC001}.bak" ] && mv "${SEC001}.bak" "$SEC001" 2>/dev/null || true; trap - EXIT' EXIT
mv "$SEC001" "${SEC001}.bak"
output=$(cd "$TMPDIR_DOC" && MB_HOME="$REPO_ROOT" bash "$MB" doctor 2>&1)
# Conditional restore: always runs, even if output capture failed
[ -d "${SEC001}.bak" ] && mv "${SEC001}.bak" "$SEC001"
trap - EXIT

assert_contains "$output" "SEC-001" "check 13: missing fixture → [WARN]"

# ── Check 14: standards count > 20 ───────────────────────────────────────────
echo ""
echo "--- check 14: standards count > 20 ---"

EXTRA_STD_FILES=()
trap 'for f in "${EXTRA_STD_FILES[@]}"; do rm -f "$f"; done; trap - EXIT' EXIT
for i in $(seq 1 15); do
    f="$REPO_ROOT/standards/EXTRA-STD-$i.md"
    echo "# Extra $i" > "$f"
    EXTRA_STD_FILES+=("$f")
done

output=$(cd "$TMPDIR_DOC" && MB_HOME="$REPO_ROOT" bash "$MB" doctor 2>&1)

for f in "${EXTRA_STD_FILES[@]}"; do rm -f "$f"; done
trap - EXIT

assert_contains "$output" "standards files" "check 14: standards count warning message"
assert_contains "$output" "budget is" "check 14: budget message present"

# ── Check 15: startup context > 15 KB ────────────────────────────────────────
echo ""
echo "--- check 15: startup context > 15 KB ---"

# WHY: target 15-25 KB range to hit WARN (not ERROR). Base files ~600 bytes; need
# activeContext.md at ~16 KB. At ~85 chars/line, 200 lines = ~17 KB. Total ~17.6 KB.
{
    echo "---"
    echo "authority: volatile"
    echo "last-reviewed: $(date +%Y-%m-%d)"
    echo "staleness-threshold: 14d"
    echo "---"
    echo "# activeContext"
    for i in $(seq 1 200); do
        echo "Entry $i: long content line to push startup context over the 15 KB warn threshold xxxxxxxxxxx."
    done
} > "$TMPDIR_DOC/memory-bank/activeContext.md"

output=$(cd "$TMPDIR_DOC" && MB_HOME="$REPO_ROOT" bash "$MB" doctor 2>&1)
assert_contains "$output" "consider slimming" "check 15: startup context > 15 KB → [WARN] consider slimming"

# Restore
restore_mb "$TMPDIR_DOC" "activeContext.md" "volatile" "14"

# ── Check 16: hook error log entries ─────────────────────────────────────────
echo ""
echo "--- check 16: hook error log entries ---"

echo "2026-01-01 error: something failed" > "$TMPDIR_DOC/.pmb-hook-errors.log"
output=$(cd "$TMPDIR_DOC" && MB_HOME="$REPO_ROOT" bash "$MB" doctor 2>&1)
assert_contains "$output" "Hook error log has 1 entry" "check 16: hook error log → [WARN]"

rm -f "$TMPDIR_DOC/.pmb-hook-errors.log"

# ── Check 17: semantic drift signals ─────────────────────────────────────────
echo ""
echo "--- check 17: semantic drift signals ---"

cat > "$TMPDIR_DOC/memory-bank/activeContext.md" <<EOF
---
authority: volatile
last-reviewed: $(date +%Y-%m-%d)
staleness-threshold: 14d
---
# activeContext
We are no longer using the old approach.
Test content.
EOF

output=$(cd "$TMPDIR_DOC" && MB_HOME="$REPO_ROOT" bash "$MB" doctor 2>&1)
assert_contains "$output" "Semantic drift signals" "check 17: drift signal → [WARN]"

# Restore
restore_mb "$TMPDIR_DOC" "activeContext.md" "volatile" "14"

# ── Check 18: stable-authority decisions old (180+ days) ─────────────────────
echo ""
echo "--- check 18: stable decisions not reviewed in 180+ days ---"

cat > "$TMPDIR_DOC/memory-bank/systemPatterns.md" <<'EOF'
---
authority: stable
last-reviewed: 2020-01-01
staleness-threshold: 180d
---
# systemPatterns
Test content.
EOF

output=$(cd "$TMPDIR_DOC" && MB_HOME="$REPO_ROOT" bash "$MB" doctor 2>&1)
assert_contains "$output" "not reviewed in" "check 18: not reviewed in N days message"

# Restore
restore_mb "$TMPDIR_DOC" "systemPatterns.md" "stable" "90"

# ── Check 19: cross-file authority violation ──────────────────────────────────
echo ""
echo "--- check 19: authority hierarchy violation ---"

cat > "$TMPDIR_DOC/memory-bank/projectbrief.md" <<EOF
---
authority: stable
last-reviewed: $(date +%Y-%m-%d)
staleness-threshold: 90d
---
# projectbrief
Test content.
EOF
# projectbrief.md expects authority:immutable — authority:stable triggers check 19

output=$(cd "$TMPDIR_DOC" && MB_HOME="$REPO_ROOT" bash "$MB" doctor 2>&1)
assert_contains "$output" "authority conflict" "check 19: authority violation → [WARN]"

# Restore
cat > "$TMPDIR_DOC/memory-bank/projectbrief.md" <<EOF
---
authority: immutable
last-reviewed: $(date +%Y-%m-%d)
staleness-threshold: 90d
---
# projectbrief
Test content.
EOF

# ── Check 20: integrity checksum mismatch ────────────────────────────────────
echo ""
echo "--- check 20: integrity checksum mismatch ---"

# First run to establish baseline checksums
(cd "$TMPDIR_DOC" && MB_HOME="$REPO_ROOT" bash "$MB" doctor > /dev/null 2>&1)

# Modify a file externally (not through mb tools)
echo "External modification." >> "$TMPDIR_DOC/memory-bank/progress.md"

# Second run — should detect the mismatch
output=$(cd "$TMPDIR_DOC" && MB_HOME="$REPO_ROOT" bash "$MB" doctor 2>&1)
assert_contains "$output" "hash mismatch" "check 20: hash mismatch message"

# Restore progress.md and clear checksums so future runs start fresh
restore_mb "$TMPDIR_DOC" "progress.md" "accumulating" "30"
rm -f "$TMPDIR_DOC/.pmb-checksums"

# ── Check 21: git-vs-reviewed lag ────────────────────────────────────────────
echo ""
echo "--- check 21: git-vs-reviewed lag ---"

cat > "$TMPDIR_DOC/memory-bank/techContext.md" <<'EOF'
---
authority: stable
last-reviewed: 2020-01-01
staleness-threshold: 90d
---
# techContext
This file was committed after the last-reviewed date.
EOF
(cd "$TMPDIR_DOC" && git add memory-bank/techContext.md && git commit -q -m "tech-context-old-reviewed")

output=$(cd "$TMPDIR_DOC" && MB_HOME="$REPO_ROOT" bash "$MB" doctor 2>&1)
assert_contains "$output" "last-reviewed 2020-01-01" "check 21: lag message shows old date"

# Restore
restore_mb "$TMPDIR_DOC" "techContext.md" "stable" "90"
(cd "$TMPDIR_DOC" && git add memory-bank/techContext.md && git commit -q -m "restore-tech-context")

# ── Check 22: completed-but-still-planned ────────────────────────────────────
echo ""
echo "--- check 22: completed-but-still-planned ---"

cat > "$TMPDIR_DOC/memory-bank/progress.md" <<EOF
---
authority: accumulating
last-reviewed: $(date +%Y-%m-%d)
staleness-threshold: 30d
---
# Progress
## Completed
- ✅ implement new authentication feature for user login
EOF

cat > "$TMPDIR_DOC/memory-bank/activeContext.md" <<EOF
---
authority: volatile
last-reviewed: $(date +%Y-%m-%d)
staleness-threshold: 14d
---
# activeContext
## Next Steps
- ⏸ implement new authentication feature for user login
EOF

output=$(cd "$TMPDIR_DOC" && MB_HOME="$REPO_ROOT" bash "$MB" doctor 2>&1)
assert_contains "$output" "marked" "check 22: completed-but-still-planned drift message"

# Restore
restore_mb "$TMPDIR_DOC" "progress.md" "accumulating" "30"
restore_mb "$TMPDIR_DOC" "activeContext.md" "volatile" "14"

# ── Check 23: stale next steps ────────────────────────────────────────────────
echo ""
echo "--- check 23: stale next steps ---"

cat > "$TMPDIR_DOC/memory-bank/progress.md" <<EOF
---
authority: accumulating
last-reviewed: $(date +%Y-%m-%d)
staleness-threshold: 30d
---
# Progress
## Completed
- ✅ deploy the refactored database migration scripts
EOF

cat > "$TMPDIR_DOC/memory-bank/activeContext.md" <<EOF
---
authority: volatile
last-reviewed: $(date +%Y-%m-%d)
staleness-threshold: 14d
---
# activeContext
## Next Steps
- deploy the refactored database migration scripts
EOF

output=$(cd "$TMPDIR_DOC" && MB_HOME="$REPO_ROOT" bash "$MB" doctor 2>&1)
assert_contains "$output" "Next Step appears completed" "check 23: stale next step → [WARN]"

# Restore
restore_mb "$TMPDIR_DOC" "progress.md" "accumulating" "30"
restore_mb "$TMPDIR_DOC" "activeContext.md" "volatile" "14"

# ── Check 24: docs/plans/ not found ──────────────────────────────────────────
echo ""
echo "--- check 24: docs/plans/ not found ---"

TMPDIR_NOPLANS="$(mktemp -d 2>/dev/null || mktemp -d -t mb-noplans-test)"
trap 'rm -rf "$TMPDIR_NOPLANS"' EXIT

setup_test_project "$TMPDIR_NOPLANS"
rm -rf "$TMPDIR_NOPLANS/docs/plans"

output=$(cd "$TMPDIR_NOPLANS" && MB_HOME="$REPO_ROOT" bash "$MB" doctor 2>&1)
assert_contains "$output" "docs/plans/ not found" "check 24: docs/plans missing → [WARN]"

# ── Check 25: agent missing name: in frontmatter ─────────────────────────────
echo ""
echo "--- check 25: agent missing name: → [WARN] ---"

TMPDIR_AGENTNONAME="$(mktemp -d 2>/dev/null || mktemp -d -t mb-agentnoname-test)"
trap 'rm -rf "$TMPDIR_AGENTNONAME"' EXIT

setup_test_project "$TMPDIR_AGENTNONAME"
mkdir -p "$TMPDIR_AGENTNONAME/.claude/agents"
cat > "$TMPDIR_AGENTNONAME/.claude/agents/researcher.md" <<'EOF'
---
description: Codebase investigator.
tools:
  - Read
---
You are a researcher.
EOF

output=$(cd "$TMPDIR_AGENTNONAME" && MB_HOME="$REPO_ROOT" bash "$MB" doctor 2>&1)
assert_contains "$output" "missing name: in frontmatter" "check 25: agent missing name: → [WARN]"

# ── Check 25: agent name: mismatches filename ─────────────────────────────────
echo ""
echo "--- check 25: agent name: mismatches filename → [WARN] ---"

TMPDIR_AGENTMISMATCH="$(mktemp -d 2>/dev/null || mktemp -d -t mb-agentmismatch-test)"
trap 'rm -rf "$TMPDIR_AGENTMISMATCH"' EXIT

setup_test_project "$TMPDIR_AGENTMISMATCH"
mkdir -p "$TMPDIR_AGENTMISMATCH/.claude/agents"
cat > "$TMPDIR_AGENTMISMATCH/.claude/agents/researcher.md" <<'EOF'
---
name: not-researcher
description: Codebase investigator.
tools:
  - Read
---
You are a researcher.
EOF

output=$(cd "$TMPDIR_AGENTMISMATCH" && MB_HOME="$REPO_ROOT" bash "$MB" doctor 2>&1)
assert_contains "$output" "doesn't match their filename" "check 25: agent name: mismatches filename → [WARN]"

# ── Check 25: agents/ clean → [OK] ────────────────────────────────────────────
echo ""
echo "--- check 25: agents/ clean → [OK] ---"

TMPDIR_AGENTCLEAN="$(mktemp -d 2>/dev/null || mktemp -d -t mb-agentclean-test)"
trap 'rm -rf "$TMPDIR_AGENTCLEAN"' EXIT

setup_test_project "$TMPDIR_AGENTCLEAN"
mkdir -p "$TMPDIR_AGENTCLEAN/.claude/agents"
cat > "$TMPDIR_AGENTCLEAN/.claude/agents/researcher.md" <<'EOF'
---
name: researcher
description: Codebase investigator.
tools:
  - Read
---
You are a researcher.
EOF

output=$(cd "$TMPDIR_AGENTCLEAN" && MB_HOME="$REPO_ROOT" bash "$MB" doctor 2>&1)
assert_contains "$output" "All agent definitions have name" "check 25: agents/ clean → [OK]"

# ── Check 25: mixed missing + mismatched agents both reported ────────────────
echo ""
echo "--- check 25: missing + mismatched agents both reported → both [WARN] ---"

TMPDIR_AGENTMIXED="$(mktemp -d 2>/dev/null || mktemp -d -t mb-agentmixed-test)"
trap 'rm -rf "$TMPDIR_AGENTMIXED"' EXIT

setup_test_project "$TMPDIR_AGENTMIXED"
mkdir -p "$TMPDIR_AGENTMIXED/.claude/agents"
cat > "$TMPDIR_AGENTMIXED/.claude/agents/researcher.md" <<'EOF'
---
name: not-researcher
description: Codebase investigator.
tools:
  - Read
---
You are a researcher.
EOF
cat > "$TMPDIR_AGENTMIXED/.claude/agents/security-reviewer.md" <<'EOF'
---
description: Security-focused code reviewer.
tools:
  - Read
---
You are a security reviewer.
EOF

output=$(cd "$TMPDIR_AGENTMIXED" && MB_HOME="$REPO_ROOT" bash "$MB" doctor 2>&1)
assert_contains "$output" "missing name: in frontmatter" "check 25: mixed case — missing name still reported"
assert_contains "$output" "doesn't match their filename" "check 25: mixed case — mismatched name still reported (not suppressed by elif)"

# ── Check 25: name: extraction scoped to frontmatter, not body text ──────────
echo ""
echo "--- check 25: body text starting with name: is not mistaken for frontmatter → [WARN] missing ---"

TMPDIR_AGENTBODY="$(mktemp -d 2>/dev/null || mktemp -d -t mb-agentbody-test)"
trap 'rm -rf "$TMPDIR_AGENTBODY"' EXIT

setup_test_project "$TMPDIR_AGENTBODY"
mkdir -p "$TMPDIR_AGENTBODY/.claude/agents"
cat > "$TMPDIR_AGENTBODY/.claude/agents/researcher.md" <<'EOF'
---
description: Codebase investigator.
tools:
  - Read
---
Example frontmatter shown to the user:
name: not-a-real-frontmatter-field
EOF

output=$(cd "$TMPDIR_AGENTBODY" && MB_HOME="$REPO_ROOT" bash "$MB" doctor 2>&1)
assert_contains "$output" "missing name: in frontmatter" "check 25: name: in body text is not mistaken for frontmatter"

# ── Check 25: quoted name: value matches filename cleanly ────────────────────
echo ""
echo "--- check 25: quoted name: value → [OK] ---"

TMPDIR_AGENTQUOTED="$(mktemp -d 2>/dev/null || mktemp -d -t mb-agentquoted-test)"
trap 'rm -rf "$TMPDIR_AGENTQUOTED"' EXIT

setup_test_project "$TMPDIR_AGENTQUOTED"
mkdir -p "$TMPDIR_AGENTQUOTED/.claude/agents"
cat > "$TMPDIR_AGENTQUOTED/.claude/agents/researcher.md" <<'EOF'
---
name: "researcher"
description: Codebase investigator.
tools:
  - Read
---
You are a researcher.
EOF

output=$(cd "$TMPDIR_AGENTQUOTED" && MB_HOME="$REPO_ROOT" bash "$MB" doctor 2>&1)
assert_contains "$output" "All agent definitions have name" "check 25: quoted name: value matches filename → [OK]"

# ── Check 25: quoted name: value with trailing whitespace still matches ──────
echo ""
echo "--- check 25: quoted name: value with trailing whitespace → [OK] ---"

TMPDIR_AGENTQUOTEDWS="$(mktemp -d 2>/dev/null || mktemp -d -t mb-agentquotedws-test)"
trap 'rm -rf "$TMPDIR_AGENTQUOTEDWS"' EXIT

setup_test_project "$TMPDIR_AGENTQUOTEDWS"
mkdir -p "$TMPDIR_AGENTQUOTEDWS/.claude/agents"
{
  printf '%s\n' '---'
  printf 'name: "researcher"   \n'
  printf '%s\n' 'description: Codebase investigator.'
  printf '%s\n' 'tools:'
  printf '%s\n' '  - Read'
  printf '%s\n' '---'
  printf '%s\n' 'You are a researcher.'
} > "$TMPDIR_AGENTQUOTEDWS/.claude/agents/researcher.md"

output=$(cd "$TMPDIR_AGENTQUOTEDWS" && MB_HOME="$REPO_ROOT" bash "$MB" doctor 2>&1)
assert_contains "$output" "All agent definitions have name" "check 25: quoted name: with trailing whitespace matches filename → [OK]"

# ── Check 25: multiple clean agents → [OK], correct pluralization elsewhere ──
echo ""
echo "--- check 25: multiple agents, one broken → count reflects only the broken one ---"

TMPDIR_AGENTMULTI="$(mktemp -d 2>/dev/null || mktemp -d -t mb-agentmulti-test)"
trap 'rm -rf "$TMPDIR_AGENTMULTI"' EXIT

setup_test_project "$TMPDIR_AGENTMULTI"
mkdir -p "$TMPDIR_AGENTMULTI/.claude/agents"
cat > "$TMPDIR_AGENTMULTI/.claude/agents/researcher.md" <<'EOF'
---
name: researcher
description: Codebase investigator.
tools:
  - Read
---
You are a researcher.
EOF
cat > "$TMPDIR_AGENTMULTI/.claude/agents/security-reviewer.md" <<'EOF'
---
description: Security-focused code reviewer.
tools:
  - Read
---
You are a security reviewer.
EOF

output=$(cd "$TMPDIR_AGENTMULTI" && MB_HOME="$REPO_ROOT" bash "$MB" doctor 2>&1)
assert_contains "$output" "1 agent(s) missing name: in frontmatter" "check 25: multiple agents — count reflects only the broken one"

# ── Check 25: no .claude/agents/ directory → no check-25 output ──────────────
echo ""
echo "--- check 25: no .claude/agents/ dir → check silently skipped ---"

TMPDIR_NOAGENTS="$(mktemp -d 2>/dev/null || mktemp -d -t mb-noagents-test)"
trap 'rm -rf "$TMPDIR_NOAGENTS"' EXIT

setup_test_project "$TMPDIR_NOAGENTS"
rm -rf "$TMPDIR_NOAGENTS/.claude/agents"

output=$(cd "$TMPDIR_NOAGENTS" && MB_HOME="$REPO_ROOT" bash "$MB" doctor 2>&1)
assert_not_contains "$output" "agent definitions have name" "check 25: no .claude/agents/ → no OK line printed"
assert_not_contains "$output" "missing name: in frontmatter" "check 25: no .claude/agents/ → no WARN line printed"

# ── Check 25: live/template parity — divergent copy → [WARN] ─────────────────
echo ""
echo "--- check 25: live agent differs from templates/.claude/agents/ copy → [WARN] ---"

TMPDIR_AGENTPARITY="$(mktemp -d 2>/dev/null || mktemp -d -t mb-agentparity-test)"
trap 'rm -rf "$TMPDIR_AGENTPARITY"' EXIT

setup_test_project "$TMPDIR_AGENTPARITY"
mkdir -p "$TMPDIR_AGENTPARITY/.claude/agents" "$TMPDIR_AGENTPARITY/templates/.claude/agents"
cat > "$TMPDIR_AGENTPARITY/.claude/agents/researcher.md" <<'EOF'
---
name: researcher
description: Codebase investigator — LIVE VERSION.
tools:
  - Read
---
You are a researcher.
EOF
cat > "$TMPDIR_AGENTPARITY/templates/.claude/agents/researcher.md" <<'EOF'
---
name: researcher
description: Codebase investigator — TEMPLATE VERSION.
tools:
  - Read
---
You are a researcher.
EOF

output=$(cd "$TMPDIR_AGENTPARITY" && MB_HOME="$REPO_ROOT" bash "$MB" doctor 2>&1)
assert_contains "$output" "differ from their templates/.claude/agents/ copy" "check 25: live/template parity — divergent copy → [WARN]"

# ── New check: _review-gate-lib.sh missing but review-reminders.sh present → [ERROR] ────────
echo ""
echo "--- new check: _review-gate-lib.sh missing → [ERROR] ---"

TMPDIR_NOLIB="$(mktemp -d 2>/dev/null || mktemp -d -t mb-nolib-test)"
trap 'rm -rf "$TMPDIR_NOLIB"' EXIT

setup_test_project "$TMPDIR_NOLIB"
mkdir -p "$TMPDIR_NOLIB/.claude" "$TMPDIR_NOLIB/scripts"
cat > "$TMPDIR_NOLIB/.claude/settings.json" <<'JSON'
{"hooks": {"PostToolUse": [{"matcher": "Edit", "hooks": [{"type": "command", "command": "scripts/update-last-reviewed.sh"}]}]}}
JSON
echo "#!/usr/bin/env bash" > "$TMPDIR_NOLIB/scripts/update-last-reviewed.sh"
echo "#!/usr/bin/env sh" > "$TMPDIR_NOLIB/scripts/review-reminders.sh"
# _review-gate-lib.sh deliberately NOT created

output=$(cd "$TMPDIR_NOLIB" && MB_HOME="$REPO_ROOT" bash "$MB" doctor 2>&1)
assert_contains "$output" "\[ERROR\].*_review-gate-lib.sh missing" "new check: _review-gate-lib.sh missing but review-reminders.sh present → [ERROR]"

# ── Check 25: review agents must pin a capable model ──────────────────────────
# WHY this exists: `security-reviewer` shipped with no `model:` field and ran on haiku for an
# unknown period (found 2026-08-26) — a cheap security review that finds nothing is
# indistinguishable from a thorough one that finds nothing, and nothing structural caught it.
# The check added in response is itself enforcement logic, so it needs a test that discriminates
# rather than an assertion that it ran.
#
# WHY `researcher` is asserted ABSENT rather than simply not mentioned: haiku is the RIGHT model
# for retrieval work, so the check must be scoped, not blanket. A version that warned on every
# haiku-pinned agent would pass a test that only looked for the two positive cases.
echo ""
echo "--- check 25: review agents not pinned to a capable model → [WARN] ---"

TMPDIR_AGENTMODEL="$(mktemp -d 2>/dev/null || mktemp -d -t mb-agentmodel-test)"
trap 'rm -rf "$TMPDIR_AGENTMODEL"' EXIT

setup_test_project "$TMPDIR_AGENTMODEL"
mkdir -p "$TMPDIR_AGENTMODEL/.claude/agents"

cat > "$TMPDIR_AGENTMODEL/.claude/agents/opposition.md" <<'EOF'
---
name: opposition
description: Adversarial reviewer.
---
Body.
EOF

cat > "$TMPDIR_AGENTMODEL/.claude/agents/security-reviewer.md" <<'EOF'
---
name: security-reviewer
description: Security reviewer.
model: "haiku"
---
Body.
EOF

cat > "$TMPDIR_AGENTMODEL/.claude/agents/researcher.md" <<'EOF'
---
name: researcher
description: Codebase investigator.
model: haiku
---
Body.
EOF

output=$(cd "$TMPDIR_AGENTMODEL" && MB_HOME="$REPO_ROOT" bash "$MB" doctor 2>&1)
assert_contains "$output" "review agent(s) not pinned to a capable model" "check 25: unpinned review agent → [WARN]"
assert_contains "$output" "opposition.md (no model:" "check 25: names the agent with no model: field"
# The QUOTED value is the discriminating case: mb.ps1 strips quotes via .Trim(), and bash did not
# until 2026-08-27 — so a quoted haiku was caught by pwsh and silently missed by sh.
assert_contains "$output" "security-reviewer.md (model: haiku" "check 25: catches a QUOTED model: \"haiku\" (sh/ps1 parity)"
assert_not_contains "$output" "researcher.md (model: haiku" "check 25: researcher is exempt — haiku is correct for retrieval work"

# ── Check 25: correctly-pinned review agents produce no warning ───────────────
TMPDIR_AGENTPINNED="$(mktemp -d 2>/dev/null || mktemp -d -t mb-agentpinned-test)"
trap 'rm -rf "$TMPDIR_AGENTPINNED"' EXIT

setup_test_project "$TMPDIR_AGENTPINNED"
mkdir -p "$TMPDIR_AGENTPINNED/.claude/agents"

cat > "$TMPDIR_AGENTPINNED/.claude/agents/opposition.md" <<'EOF'
---
name: opposition
description: Adversarial reviewer.
model: opus
---
Body.
EOF

cat > "$TMPDIR_AGENTPINNED/.claude/agents/security-reviewer.md" <<'EOF'
---
name: security-reviewer
description: Security reviewer.
model: sonnet
---
Body.
EOF

output=$(cd "$TMPDIR_AGENTPINNED" && MB_HOME="$REPO_ROOT" bash "$MB" doctor 2>&1)
assert_not_contains "$output" "not pinned to a capable model" "check 25: correctly-pinned agents produce no warning (discrimination)"

# --- check 15 (startup context ceiling): bracketed main-repo path, mb.ps1 -----------------------
# WHY no PWSH_USABLE probe like tests/test-mb-commit.sh has: this does not need one. That probe
# exists because `assert_equals rc 0` and `assert_not_contains` both pass against a pwsh stub that
# executes nothing and prints nothing. Here the positive proof is inside the assertions themselves
# — a silent stub fails `assert_contains` — so the discrimination is structural rather than gated.
# Do not "harmonise" this by adding a probe; it would add machinery, not rigour.
#
# WHAT it pins: mb.ps1 check 15 resolved --git-common-dir with a WILDCARD Resolve-Path carrying no
# -ErrorAction. (An earlier draft said "alone among that file's four call sites"; review measured
# that as false -- Invoke-Setup's Resolve-Path lacks it too.) A bracket in the MAIN repo path
# therefore resolved to $null and `Split-Path -Parent $null` threw
# ParameterBindingValidationException. Reachable only from inside a subworktree, since only there
# is --git-common-dir absolute rather than the relative `.git`.
#
# The throw is NOT the serious half, and an earlier version of this comment said it was. Measured:
# doctor does not die on it. It prints the stack trace, carries on with $startupRoot still at ".",
# and so measures the SUBWORKTREE's own memory-bank instead of the main worktree's — which is
# exactly the phantom-reduction failure this check's worktree-awareness exists to prevent. With
# the main worktree inflated past the 25 KB ceiling and the subworktree left small, pre-fix
# reported "[OK] Startup context: 0.6 KB" for a tree measuring 27 KB against a 25 KB hard limit
# (27,607 B vs a 25,600 B ceiling -- 27 KB in total, not 27 KB in excess). A false OK in a
# governance check outranks a crash, so the inflation below is load-bearing, not decoration: the
# no-throw assertion alone passes against a build that still measures the wrong tree.
#
# Discrimination measured against HEAD before the fix, all four cells: bracketed main THREW and
# reported [OK] 0.6 KB; bracketed main post-fix reported [ERROR] 27 KB; plain main reported
# [ERROR] 27 KB both pre- and post-fix. So the bracket is the discriminator, not mere absence,
# and `assert_contains "exceeds 25 KB"` is the assertion that actually fails against the defect.
#
# `cd` rather than `git -C`: git -C fails on a bracketed path on Git for Windows ("cannot change
# to ...: No such file or directory") even though the directory exists and cd into it works.
#
# Cleanup is explicit, with no `trap ... EXIT` registration: bash keeps only the LAST EXIT trap,
# and this file registers many, so adding one more would silently disarm the one before it. That
# pre-existing defect is not fixed here — it is simply not joined.
if ! command -v pwsh >/dev/null 2>&1; then
    echo "  SKIP: pwsh not available — check 15 bracketed-path case not exercised"
else
    TMPDIR_BRACKET="$(mktemp -d)"
    BR_MAIN="$TMPDIR_BRACKET/main[x]"
    setup_test_project "$BR_MAIN" >/dev/null 2>&1
    if command -v cygpath >/dev/null 2>&1; then
        BR_SUB_ARG="$(cygpath -w "$TMPDIR_BRACKET/sub")"
        MBPS1_D="$(cygpath -w "$REPO_ROOT/scripts/mb.ps1")"
        MB_HOME_D="$(cygpath -w "$REPO_ROOT")"
    else
        BR_SUB_ARG="$TMPDIR_BRACKET/sub"
        MBPS1_D="$REPO_ROOT/scripts/mb.ps1"
        MB_HOME_D="$REPO_ROOT"
    fi
    if ! ( cd "$BR_MAIN" && git worktree add "$BR_SUB_ARG" -b brackettest ) >/dev/null 2>&1; then
        echo "  SKIP: git worktree add unavailable — check 15 bracketed-path case not exercised"
    else
        # Inflate the MAIN worktree past the 25 KB ceiling, leaving the subworktree's own copy
        # small. Measuring the wrong tree is then visible as an [OK] where an [ERROR] is due.
        head -c 20000 /dev/urandom | base64 > "$BR_MAIN/memory-bank/bulk.md"
        # Path via the ENVIRONMENT with a single-quoted -Command body: see the injection note in
        # tests/test-mb-commit.sh. An interpolated path containing  ' ; #  is otherwise executable.
        output=$(cd "$TMPDIR_BRACKET/sub" && MB_HOME="$MB_HOME_D" MB_SCRIPT="$MBPS1_D" pwsh -NoProfile -Command \
            '$PSStyle.OutputRendering="PlainText"; & $env:MB_SCRIPT doctor' 2>&1)
        assert_contains "$output" "Startup context" "check 15: bracketed main repo — doctor reaches the ceiling check (positive proof pwsh executed mb.ps1)"
        assert_not_contains "$output" "Cannot bind argument to parameter" "check 15: bracketed main repo — Resolve-Path does not glob the path away and throw"
        assert_contains "$output" "exceeds 25 KB limit" "check 15: bracketed main repo — measures the MAIN worktree, not the subworktree (no false OK)"
    fi
    rm -rf "$TMPDIR_BRACKET"
fi

# ── Check 26: exit code reflects fatal vs. advisory findings ─────────────────
# Added 2026-09-19 (2026-09-11 whole-repo review, finding 2): doctor's exit code was always 0
# regardless of what it printed, so CI's "MB Doctor Self-Check" job could never fail on a real
# problem. Fixed by gating only on the genuinely fatal [ERROR] sites (FATAL_FOUND in
# scripts/mb.sh) -- checksum-mismatch and the startup-context ceiling stay advisory by design
# (see that variable's own comment) and must NOT flip the exit code, so both directions are
# asserted here, not just the fatal one. A test that only checks the fatal case would pass on a
# blanket "any [ERROR] -> exit 1" implementation too, which is the wrong-grained fix this
# section exists to rule out.
echo ""
echo "--- check 26: exit code reflects fatal vs. advisory findings ---"

TMPDIR_EXITCODE="$(mktemp -d 2>/dev/null || mktemp -d -t mb-exitcode-test)"
trap 'rm -rf "$TMPDIR_EXITCODE"' EXIT

mkdir -p "$TMPDIR_EXITCODE/memory-bank" "$TMPDIR_EXITCODE/standards"
for f in projectbrief.md systemPatterns.md techContext.md activeContext.md progress.md; do
    write_mb_file "$TMPDIR_EXITCODE/memory-bank/$f" "stable" "90"
done
for s in WORKFLOW.md CODE-QUALITY.md SECURITY-GUARDRAILS.md CODE-REVIEW.md; do
    echo "# $s" > "$TMPDIR_EXITCODE/standards/$s"
done
# No CLAUDE.md -- the fatal condition under test.
(cd "$TMPDIR_EXITCODE" && git init -q && git config user.email t@t.com && git config user.name T && git commit -q --allow-empty -m init)

output=$(cd "$TMPDIR_EXITCODE" && MB_HOME="$REPO_ROOT" bash "$MB" doctor 2>&1)
rc=$?
assert_contains "$output" "\[ERROR\] CLAUDE.md missing" "check 26: fatal fixture actually has the CLAUDE.md-missing [ERROR]"
assert_equals "$rc" "1" "check 26: fatal condition (CLAUDE.md missing) — doctor exits 1"

rm -rf "$TMPDIR_EXITCODE"
trap - EXIT

# Advisory only: a checksum mismatch prints [ERROR] but must not make doctor exit non-zero.
(cd "$TMPDIR_DOC" && MB_HOME="$REPO_ROOT" bash "$MB" doctor > /dev/null 2>&1)
echo "External modification." >> "$TMPDIR_DOC/memory-bank/progress.md"
output=$(cd "$TMPDIR_DOC" && MB_HOME="$REPO_ROOT" bash "$MB" doctor 2>&1)
rc=$?
assert_contains "$output" "\[ERROR\].*hash mismatch" "check 26: advisory-only fixture actually has a checksum-mismatch [ERROR]"
assert_equals "$rc" "0" "check 26: advisory-only condition (checksum mismatch) — doctor still exits 0"

restore_mb "$TMPDIR_DOC" "progress.md" "accumulating" "30"
rm -f "$TMPDIR_DOC/.pmb-checksums"

# Clean baseline must also exit 0.
output=$(cd "$TMPDIR_DOC" && MB_HOME="$REPO_ROOT" bash "$MB" doctor 2>&1)
rc=$?
assert_not_contains "$output" "\[ERROR\]" "check 26: clean baseline has no [ERROR]"
assert_equals "$rc" "0" "check 26: clean baseline — doctor exits 0"

print_summary
