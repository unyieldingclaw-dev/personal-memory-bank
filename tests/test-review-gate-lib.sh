#!/usr/bin/env bash
# tests/test-review-gate-lib.sh — unit tests for scripts/_review-gate-lib.sh's sha256_file()/
# diff_hash(), and (where pwsh is available) _review-gate-lib.ps1's Get-FileHashHex, covering
# trailing-newline and empty-file inputs directly.
#
# WHY this test exists: the 2026-07-09 trailing-newline hash-mismatch bug was specifically an
# edge case in this exact byte-handling (command substitution stripping a trailing newline vs.
# redirect-to-file preserving it) -- the class of bug this whole dedup refactor is designed to
# prevent from recurring across duplicated copies. Relying solely on the end-to-end
# test-review-reminders.sh suite happening to cover this edge case is not sufficient given how
# central it is to the design's own risk argument (see
# docs/superpowers/specs/2026-07-29-review-gate-hook-lib-dedup-design.md, Testing section).
set -u

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$REPO_ROOT/tests/helpers/assert.sh"
. "$REPO_ROOT/scripts/_review-gate-lib.sh"

echo "=== _review-gate-lib.sh unit tests ==="

TMPDIR_LIB="$(mktemp -d 2>/dev/null || mktemp -d -t mb-lib-test)"
trap 'rm -rf "$TMPDIR_LIB"' EXIT

# ── sha256_file: trailing-newline sensitivity ────────────────────────────────
echo ""
echo "--- sha256_file: a trailing newline changes the hash (proves byte-exact hashing) ---"
printf 'hello' > "$TMPDIR_LIB/no-newline.txt"
printf 'hello\n' > "$TMPDIR_LIB/with-newline.txt"
hash_no_nl=$(sha256_file "$TMPDIR_LIB/no-newline.txt")
hash_with_nl=$(sha256_file "$TMPDIR_LIB/with-newline.txt")
if [ "$hash_no_nl" != "$hash_with_nl" ]; then
  echo "  PASS: sha256_file distinguishes a trailing newline (regression guard for the 2026-07-09 bug class)"
  PASS=$((PASS + 1))
else
  echo "  FAIL: sha256_file did not distinguish a trailing newline -- hashes were identical"
  FAIL=$((FAIL + 1))
fi

# ── sha256_file: matches sha256sum directly on a known trailing-newline file ─
echo ""
echo "--- sha256_file: matches sha256sum's own output for a file with a trailing newline ---"
expected=$(sha256sum "$TMPDIR_LIB/with-newline.txt" | cut -d' ' -f1)
assert_contains "$hash_with_nl" "$expected" "sha256_file matches sha256sum for a trailing-newline file"

# ── sha256_file: empty file ──────────────────────────────────────────────────
echo ""
echo "--- sha256_file: empty file hashes to the well-known SHA-256 empty-string hash ---"
: > "$TMPDIR_LIB/empty.txt"
hash_empty=$(sha256_file "$TMPDIR_LIB/empty.txt")
assert_contains "$hash_empty" "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855" "sha256_file on an empty file matches the well-known empty-string SHA-256"

# ── diff_hash: a diff whose content ends without a trailing newline ─────────
echo ""
echo "--- diff_hash: hash of a diff whose new content has no trailing newline ---"
git -C "$TMPDIR_LIB" init -q -b main
git -C "$TMPDIR_LIB" config user.email "test@example.com"
git -C "$TMPDIR_LIB" config user.name "Test"
printf 'line one' > "$TMPDIR_LIB/file.txt"
git -C "$TMPDIR_LIB" add file.txt
git -C "$TMPDIR_LIB" commit -q -m initial
printf 'line one\nline two' > "$TMPDIR_LIB/file.txt"
diff_hash_result=$(cd "$TMPDIR_LIB" && diff_hash HEAD)
git -C "$TMPDIR_LIB" diff HEAD > "$TMPDIR_LIB/manual.diff" 2>/dev/null
manual_expected=$(sha256sum "$TMPDIR_LIB/manual.diff" | cut -d' ' -f1)
assert_contains "$diff_hash_result" "$manual_expected" "diff_hash matches a manually-redirected-and-hashed git diff for a no-trailing-newline file change"

# ── diff_hash: empty diff (no changes) still returns the empty-file hash ────
echo ""
echo "--- diff_hash: no changes present produces the empty-file hash, not an error ---"
git -C "$TMPDIR_LIB" add file.txt
git -C "$TMPDIR_LIB" commit -q -m "second"
no_change_hash=$(cd "$TMPDIR_LIB" && diff_hash HEAD)
assert_contains "$no_change_hash" "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855" "diff_hash on a clean tree (no diff) matches the empty-file SHA-256"

# ── diff_hash: never touches the EXIT trap, in either calling convention ────
# WHY this test exists: diff_hash() used to end with an unconditional `trap - EXIT`, which
# would silently clear a caller's own EXIT trap in a direct, same-shell call. A save-and-
# restore fix (`trap -p EXIT` + eval it back) was tried and reverted after it was found to
# cause a WORSE bug: in a command-substitution subshell (`$(diff_hash ...)`, the pattern
# review-reminders.sh actually uses), explicitly re-registering an inherited trap arms it for
# that subshell's own exit -- bash treats a merely-inherited, never-touched trap as dormant on
# subshell exit, but the moment `trap` is called explicitly (even to restore the same value),
# it fires early. This proves the final, no-trap-manipulation-at-all design leaves a caller's
# own EXIT trap byte-identical before and after calling diff_hash(), for BOTH calling
# conventions -- a direct call in the same shell, and a call via command substitution.
echo ""
echo "--- diff_hash: leaves a caller's own EXIT trap untouched (direct call, same shell) ---"
direct_check=$(
  cd "$TMPDIR_LIB" || exit 1
  trap 'true' EXIT
  before_trap=$(trap -p EXIT)
  diff_hash HEAD > "$TMPDIR_LIB/direct-call-output.txt"
  after_trap=$(trap -p EXIT)
  [ "$before_trap" = "$after_trap" ] && echo "UNCHANGED" || echo "CHANGED"
)
assert_contains "$direct_check" "UNCHANGED" "diff_hash leaves a caller's own EXIT trap untouched on a direct, same-shell call"

echo ""
echo "--- diff_hash: does not prematurely fire an inherited EXIT trap in a subshell call ---"
TRAP_MARKER="$TMPDIR_LIB/outer-trap-fired"
rm -f "$TRAP_MARKER"
# WHY echo a status string instead of checking $TRAP_MARKER after this command substitution
# returns: the outer `( ... )` subshell's OWN real exit (falling off the end, after the echo)
# legitimately fires its trap and creates the marker too -- checking the marker file from
# outside this command substitution can't distinguish "diff_hash fired it early" from "the
# outer subshell fired it at its own, correct, real exit," since both leave the marker present
# by the time control returns here. The marker must be checked INSIDE the subshell, immediately
# after the diff_hash call and before anything else can trigger this subshell's own exit, with
# the verdict carried out via stdout instead.
subshell_status=$(
  cd "$TMPDIR_LIB" || { echo "SETUP_FAILED"; exit 1; }
  trap 'touch "'"$TRAP_MARKER"'"' EXIT
  diff_hash HEAD > /dev/null
  if [ -f "$TRAP_MARKER" ]; then
    echo "FIRED_EARLY"
  else
    echo "OK"
  fi
)
if [ "$subshell_status" = "OK" ]; then
  echo "  PASS: diff_hash does not prematurely fire an inherited EXIT trap when called via command substitution"
  PASS=$((PASS + 1))
else
  echo "  FAIL: diff_hash does not prematurely fire an inherited EXIT trap when called via command substitution"
  echo "    status was '$subshell_status' -- the inherited trap fired early, inside diff_hash's own subshell,"
  echo "    which is the exact regression found and reverted (deletes a caller's real working directory"
  echo "    prematurely, e.g. \$TMPDIR_LIB, before the caller's own real exit)"
  FAIL=$((FAIL + 1))
fi
rm -f "$TRAP_MARKER" "$TMPDIR_LIB/direct-call-output.txt"

# ── Get-FileHashHex (_review-gate-lib.ps1): trailing-newline + empty-file parity ─
# WHY convert paths via cygpath first: $REPO_ROOT/$TMPDIR_LIB are POSIX-style git-bash paths
# (e.g. /c/Users/...). PowerShell's -File parameter gets this auto-translated by git-bash's
# MSYS layer because the whole argument IS a path, but a path embedded as a substring inside
# a -Command script block is not auto-translated -- confirmed via direct reproduction: PowerShell
# reported "The term '/c/Users/.../_review-gate-lib.ps1' is not recognized" for the untranslated
# form. Converting explicitly with cygpath -w (available in git-bash) avoids relying on MSYS's
# argv-level heuristic for a path used mid-string.
# WHY also require cygpath, not just pwsh (found on GitHub Actions ubuntu-latest, which ships
# pwsh but not cygpath -- cygpath is git-bash/MSYS-only): matches the identical guard already
# used by test-review-reminders.sh and test-update-reviewed.sh for the same reason -- without
# it, this block runs on any Linux/macOS box with pwsh installed, cygpath's "command not found"
# leaves the *_WIN vars empty, and the PowerShell calls fail for an environment reason having
# nothing to do with Get-FileHashHex itself, turning a clean SKIP into a spurious FAIL.
if command -v pwsh >/dev/null 2>&1 && command -v cygpath >/dev/null 2>&1; then
  echo ""
  echo "--- Get-FileHashHex: trailing-newline and empty-file hashes match sha256_file's bash output ---"
  LIB_PS1_WIN=$(cygpath -w "$REPO_ROOT/scripts/_review-gate-lib.ps1")
  WITH_NL_WIN=$(cygpath -w "$TMPDIR_LIB/with-newline.txt")
  EMPTY_WIN=$(cygpath -w "$TMPDIR_LIB/empty.txt")
  ps1_hash_with_nl=$(pwsh -NonInteractive -Command ". '$LIB_PS1_WIN'; Get-FileHashHex '$WITH_NL_WIN'" | tr -d '\r\n')
  assert_contains "$ps1_hash_with_nl" "$hash_with_nl" "Get-FileHashHex matches bash sha256_file for a trailing-newline file (cross-shell hash parity)"

  ps1_hash_empty=$(pwsh -NonInteractive -Command ". '$LIB_PS1_WIN'; Get-FileHashHex '$EMPTY_WIN'" | tr -d '\r\n')
  assert_contains "$ps1_hash_empty" "$hash_empty" "Get-FileHashHex matches bash sha256_file for an empty file (cross-shell hash parity)"
else
  echo ""
  echo "--- Get-FileHashHex tests: SKIPPED (pwsh and/or cygpath not installed on this machine) ---"
fi

print_summary
