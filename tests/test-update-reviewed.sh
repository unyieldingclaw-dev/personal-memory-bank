#!/usr/bin/env bash
# tests/test-update-reviewed.sh — regression test for update-reviewed.sh/.ps1
#
# WHY this test exists: this PostToolUse hook is meant to auto-stamp last-reviewed:
# frontmatter after any Write/Edit inside memory-bank/, but it had the same flat-vs-nested
# tool_input.file_path bug that check-contract.sh/dangerous-commands.sh already had fixed
# elsewhere (bd47244) — this script was never included in that fix, so FILE_PATH was always
# empty and the hook silently exited 0 on every call, never once updating last-reviewed since
# its introduction. The fix (c4a468f) reads tool_input.file_path (nested), not file_path
# (flat), but had zero test coverage of its own — a regression back to the flat read would
# reintroduce the exact same silent no-op and nothing in this repo's test suite would catch
# it, since the hook fails open by design (no crash, no error, just does nothing).
set -u

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$REPO_ROOT/tests/helpers/assert.sh"

echo "=== update-reviewed tests ==="

CLEANUP_DIRS=()
cleanup_all() {
    for d in "${CLEANUP_DIRS[@]:-}"; do
        [ -n "$d" ] && rm -rf "$d"
    done
}
trap cleanup_all EXIT

make_reviewed_file() {
    # make_reviewed_file <dir> <name> <old-date> — a memory-bank markdown file with
    # frontmatter, backdated so the "updated to today" assertion is meaningful.
    local dir="$1" name="$2" old_date="$3"
    printf -- "---\nauthority: stable\nlast-reviewed: %s\nstaleness-threshold: 90d\n---\n# %s\nTest content.\n" \
        "$old_date" "$name" > "$dir/memory-bank/$name"
}

invoke_hook() {
    # invoke_hook <script> <file_path> — nested tool_input.file_path payload, matching the
    # real hook payload shape this fix targets.
    local script="$1" file_path="$2"
    printf '{"tool_name":"Edit","tool_input":{"file_path":"%s"}}' "$file_path" \
        | bash "$REPO_ROOT/scripts/$script" 2>/dev/null
}

invoke_hook_flat() {
    # invoke_hook_flat <script> <file_path> — the OLD, broken flat payload shape
    # ({"file_path":...} with no tool_input wrapper). Used to prove the hook doesn't
    # accidentally work via some other read path — only the nested shape should update.
    local script="$1" file_path="$2"
    printf '{"file_path":"%s"}' "$file_path" \
        | bash "$REPO_ROOT/scripts/$script" 2>/dev/null
}

TODAY=$(date +%Y-%m-%d)
OLD_DATE="2020-01-01"

# ── nested tool_input.file_path payload updates last-reviewed (the actual c4a468f fix) ──────
echo ""
echo "--- nested tool_input.file_path payload updates last-reviewed to today ---"
TMPDIR_UPD="$(mktemp -d 2>/dev/null || mktemp -d -t mb-ur-test)"
CLEANUP_DIRS+=("$TMPDIR_UPD")
mkdir -p "$TMPDIR_UPD/memory-bank"
make_reviewed_file "$TMPDIR_UPD" "activeContext.md" "$OLD_DATE"
invoke_hook "update-reviewed.sh" "$TMPDIR_UPD/memory-bank/activeContext.md" >/dev/null
content=$(cat "$TMPDIR_UPD/memory-bank/activeContext.md")
assert_contains "$content" "last-reviewed: $TODAY" "update-reviewed.sh: nested tool_input.file_path payload updates last-reviewed to today"
assert_not_contains "$content" "last-reviewed: $OLD_DATE" "update-reviewed.sh: the old backdated last-reviewed value is gone"

# ── flat (pre-fix-shape) payload is a silent no-op, not a crash and not a false update ──────
echo ""
echo "--- flat (non-nested) file_path payload is a silent no-op (proves the fix reads the nested field, not some other path) ---"
TMPDIR_FLAT="$(mktemp -d 2>/dev/null || mktemp -d -t mb-ur-test)"
CLEANUP_DIRS+=("$TMPDIR_FLAT")
mkdir -p "$TMPDIR_FLAT/memory-bank"
make_reviewed_file "$TMPDIR_FLAT" "activeContext.md" "$OLD_DATE"
invoke_hook_flat "update-reviewed.sh" "$TMPDIR_FLAT/memory-bank/activeContext.md" >/dev/null
flat_exit_code=$?
content=$(cat "$TMPDIR_FLAT/memory-bank/activeContext.md")
assert_contains "$content" "last-reviewed: $OLD_DATE" "update-reviewed.sh: a flat (pre-fix-shape) payload leaves last-reviewed untouched — confirms the update above came from reading the nested field, not some other path"
assert_exit_zero "$flat_exit_code" "update-reviewed.sh: a flat (pre-fix-shape) payload exits 0 (silent no-op, not a crash)"

# ── file outside memory-bank/ is never touched ──────────────────────────────────────────────
echo ""
echo "--- a file outside memory-bank/ is not modified ---"
TMPDIR_OUT="$(mktemp -d 2>/dev/null || mktemp -d -t mb-ur-test)"
CLEANUP_DIRS+=("$TMPDIR_OUT")
mkdir -p "$TMPDIR_OUT/standards"
printf -- "---\nlast-reviewed: %s\n---\n# Standards doc\n" "$OLD_DATE" > "$TMPDIR_OUT/standards/CODE-QUALITY.md"
invoke_hook "update-reviewed.sh" "$TMPDIR_OUT/standards/CODE-QUALITY.md" >/dev/null
content=$(cat "$TMPDIR_OUT/standards/CODE-QUALITY.md")
assert_contains "$content" "last-reviewed: $OLD_DATE" "update-reviewed.sh: a file outside memory-bank/ is left untouched even though it has last-reviewed: frontmatter"

# ── file with no last-reviewed: frontmatter is not given one ────────────────────────────────
echo ""
echo "--- a memory-bank file with no last-reviewed: frontmatter is not modified ---"
TMPDIR_NOFM="$(mktemp -d 2>/dev/null || mktemp -d -t mb-ur-test)"
CLEANUP_DIRS+=("$TMPDIR_NOFM")
mkdir -p "$TMPDIR_NOFM/memory-bank"
printf "# No frontmatter here\nJust content.\n" > "$TMPDIR_NOFM/memory-bank/activeContext.md"
before=$(cat "$TMPDIR_NOFM/memory-bank/activeContext.md")
invoke_hook "update-reviewed.sh" "$TMPDIR_NOFM/memory-bank/activeContext.md" >/dev/null
after=$(cat "$TMPDIR_NOFM/memory-bank/activeContext.md")
assert_not_contains "$after" "last-reviewed:" "update-reviewed.sh: a file with no existing last-reviewed: frontmatter is not given one"
# WHY not assert_contains/assert_not_contains: this checks whole-content equality, not
# substring presence, so it's wired into PASS/FAIL directly rather than force-fitting a
# pattern-match helper -- print_summary()'s exit code comes from these counters, so a bare
# echo here (the prior version) would print FAIL text but still let the suite exit 0.
if [ "$before" = "$after" ]; then
    echo "  PASS: update-reviewed.sh: file content is byte-for-byte unchanged when no last-reviewed: frontmatter exists"
    PASS=$((PASS + 1))
else
    echo "  FAIL: update-reviewed.sh: file content changed even though no last-reviewed: frontmatter exists"
    FAIL=$((FAIL + 1))
fi

# ── cross-shell parity (PowerShell) ─────────────────────────────────────────────────────────
# WHY convert to a Windows-style path before embedding it in the JSON payload: native
# pwsh.exe (not an MSYS-aware process) can't resolve the /tmp/... POSIX-style paths git-bash's
# mktemp produces -- confirmed directly (Test-Path on the raw bash path returned $false even
# though the file exists). cygpath -w converts it to a path Test-Path can actually resolve;
# this only matters for the payload string itself, not the earlier bash-side invoke_hook
# calls, which pass paths to bash's own Test-Path-equivalent ([ -f ]) and need no conversion.
to_win_path() {
    if command -v cygpath >/dev/null 2>&1; then
        cygpath -w "$1"
    else
        printf '%s' "$1"
    fi
}

if command -v pwsh >/dev/null 2>&1 && command -v cygpath >/dev/null 2>&1; then
  echo ""
  echo "--- cross-shell parity: update-reviewed.ps1 nested payload updates last-reviewed ---"
  TMPDIR_PS1="$(mktemp -d 2>/dev/null || mktemp -d -t mb-ur-ps1)"
  CLEANUP_DIRS+=("$TMPDIR_PS1")
  mkdir -p "$TMPDIR_PS1/memory-bank"
  make_reviewed_file "$TMPDIR_PS1" "activeContext.md" "$OLD_DATE"
  WIN_PATH_PS1=$(to_win_path "$TMPDIR_PS1/memory-bank/activeContext.md" | sed 's/\\/\\\\/g')
  printf '{"tool_name":"Edit","tool_input":{"file_path":"%s"}}' "$WIN_PATH_PS1" \
    | pwsh -NoLogo -NonInteractive -File "$REPO_ROOT/scripts/update-reviewed.ps1" >/dev/null 2>&1
  content=$(cat "$TMPDIR_PS1/memory-bank/activeContext.md")
  assert_contains "$content" "last-reviewed: $TODAY" "update-reviewed.ps1: nested tool_input.file_path payload updates last-reviewed to today"

  echo ""
  echo "--- cross-shell parity: update-reviewed.ps1 flat payload is a silent no-op ---"
  TMPDIR_PS1FLAT="$(mktemp -d 2>/dev/null || mktemp -d -t mb-ur-ps1flat)"
  CLEANUP_DIRS+=("$TMPDIR_PS1FLAT")
  mkdir -p "$TMPDIR_PS1FLAT/memory-bank"
  make_reviewed_file "$TMPDIR_PS1FLAT" "activeContext.md" "$OLD_DATE"
  WIN_PATH_PS1FLAT=$(to_win_path "$TMPDIR_PS1FLAT/memory-bank/activeContext.md" | sed 's/\\/\\\\/g')
  printf '{"file_path":"%s"}' "$WIN_PATH_PS1FLAT" \
    | pwsh -NoLogo -NonInteractive -File "$REPO_ROOT/scripts/update-reviewed.ps1" >/dev/null 2>&1
  content=$(cat "$TMPDIR_PS1FLAT/memory-bank/activeContext.md")
  assert_contains "$content" "last-reviewed: $OLD_DATE" "update-reviewed.ps1: a flat (pre-fix-shape) payload leaves last-reviewed untouched"
else
  echo ""
  echo "--- update-reviewed.ps1 tests: SKIPPED (pwsh and/or cygpath not installed on this machine) ---"
fi

print_summary
