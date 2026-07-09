#!/usr/bin/env bash
# tests/test-review-reminders.sh — regression test for review-reminders.sh/.ps1 hash parity
#
# WHY this test exists: review-reminders.sh (bash) and review-reminders.ps1 (PowerShell) are
# meant to be interchangeable implementations of the same commit/push review gate -- but they
# used to compute the diff hash differently (bash: `$(git diff ...)` command substitution,
# which strips the trailing newline; PowerShell: redirect to a file then Get-FileHash, which
# preserves it), producing different hashes for the identical diff. Since settings.json always
# tries pwsh first, any marker written using the bash-documented recipe silently failed to
# validate on a machine with pwsh installed. This test proves both hooks now accept a marker
# written via either recipe, for the same diff.
set -u

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$REPO_ROOT/tests/helpers/assert.sh"

echo "=== review-reminders hash-parity tests ==="

TMPDIR_RR="$(mktemp -d 2>/dev/null || mktemp -d -t mb-rr-test)"
trap 'rm -rf "$TMPDIR_RR"' EXIT

git -C "$TMPDIR_RR" init -q -b main
git -C "$TMPDIR_RR" config user.email "test@example.com"
git -C "$TMPDIR_RR" config user.name "Test"
echo "line one" > "$TMPDIR_RR/file.txt"
git -C "$TMPDIR_RR" add file.txt
git -C "$TMPDIR_RR" commit -q -m "initial"
mkdir -p "$TMPDIR_RR/.claude"

invoke_hook() {
  # invoke_hook <script> <git-command-text>
  local script="$1" command="$2"
  printf '{"tool_input":{"command":"%s"}}' "$command" \
    | (cd "$TMPDIR_RR" && bash "$REPO_ROOT/scripts/$script" 2>/dev/null)
}

invoke_hook_ps1() {
  local command="$1"
  printf '{"tool_input":{"command":"%s"}}' "$command" \
    | (cd "$TMPDIR_RR" && pwsh -NonInteractive -File "$REPO_ROOT/scripts/review-reminders.ps1" 2>/dev/null)
}

write_marker_bash_recipe() {
  # matches code-review.md's / change-review.md's documented Bash recipe exactly
  local marker="$1"
  tmp=$(mktemp)
  git -C "$TMPDIR_RR" diff HEAD > "$tmp" 2>/dev/null
  sha256sum "$tmp" | cut -d' ' -f1 > "$TMPDIR_RR/.claude/$marker"
  rm -f "$tmp"
}

# ── commit gate: bash-written marker accepted by review-reminders.sh ────────────────────────
echo ""
echo "--- commit gate: bash recipe accepted by review-reminders.sh ---"
echo "line two" >> "$TMPDIR_RR/file.txt"
write_marker_bash_recipe ".code-review-ok"
resp=$(invoke_hook "review-reminders.sh" "git commit -m test")
assert_not_contains "$resp" '"permissionDecision":"deny"' "review-reminders.sh accepts a marker written via its own documented bash recipe"

# ── commit gate: consumed marker denies a second attempt ────────────────────────────────────
echo ""
echo "--- commit gate: marker is single-use ---"
resp=$(invoke_hook "review-reminders.sh" "git commit -m test2")
assert_contains "$resp" '"permissionDecision":"deny"' "review-reminders.sh denies a second commit with no new marker"

# ── cross-shell parity: bash-written marker accepted by review-reminders.ps1 ────────────────
if command -v pwsh >/dev/null 2>&1; then
  echo ""
  echo "--- cross-shell parity: bash-written marker accepted by review-reminders.ps1 ---"
  echo "line three" >> "$TMPDIR_RR/file.txt"
  write_marker_bash_recipe ".code-review-ok"
  resp=$(invoke_hook_ps1 "git commit -m test3")
  assert_not_contains "$resp" '"permissionDecision":"deny"' "review-reminders.ps1 accepts a marker written via the bash-documented recipe (regression test for the trailing-newline hash mismatch)"
else
  echo ""
  echo "--- cross-shell parity: SKIPPED (pwsh not installed on this machine) ---"
fi

# ── push gate: no-upstream fallback still hashes correctly ──────────────────────────────────
echo ""
echo "--- push gate: git diff HEAD fallback (no origin/main configured) ---"
echo "line four" >> "$TMPDIR_RR/file.txt"
tmp=$(mktemp)
git -C "$TMPDIR_RR" diff HEAD > "$tmp" 2>/dev/null
sha256sum "$tmp" | cut -d' ' -f1 > "$TMPDIR_RR/.claude/.change-review-ok"
rm -f "$tmp"
resp=$(invoke_hook "review-reminders.sh" "git push origin main")
assert_not_contains "$resp" '"permissionDecision":"deny"' "review-reminders.sh accepts a push-gate marker computed via the HEAD fallback (no origin/main ref exists)"

print_summary
