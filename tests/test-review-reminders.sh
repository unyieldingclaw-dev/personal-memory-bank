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

invoke_hook_from() {
  # invoke_hook_from <script> <spawn-dir> <command-text> — like invoke_hook, but spawns the
  # hook process from <spawn-dir> instead of $TMPDIR_RR, so <command-text> can carry its own
  # leading `cd "$TMPDIR_RR" && ...` to test root-resolution independent of ambient cwd.
  local script="$1" spawn_dir="$2" command="$3"
  printf '{"tool_input":{"command":"%s"}}' "$command" \
    | (cd "$spawn_dir" && bash "$REPO_ROOT/scripts/$script" 2>/dev/null)
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

# ── post-hook: reissues a marker after a failed commit attempt (diff_hash refactor) ─────────
echo ""
echo "--- post-hook: reissues marker via diff_hash() after a failed commit attempt ---"
rm -f "$TMPDIR_RR/.claude/.code-review-ok" "$TMPDIR_RR/.claude/.pending-commit-presha"
presha=$(git -C "$TMPDIR_RR" rev-parse HEAD)
printf '%s' "$presha" > "$TMPDIR_RR/.claude/.pending-commit-presha"
invoke_hook "review-reminders-post.sh" "git commit -m test5" >/dev/null
expected=$(git -C "$TMPDIR_RR" diff HEAD | sha256sum | cut -d' ' -f1)
actual=$(cat "$TMPDIR_RR/.claude/.code-review-ok" 2>/dev/null)
assert_contains "$actual" "$expected" "review-reminders-post.sh reissues .code-review-ok with the correct diff_hash() output when HEAD didn't move (failed commit)"

# ── post-hook: reissues a marker after a failed push attempt (origin/main path, not fallback) ─
echo ""
echo "--- post-hook: reissues marker via diff_hash() after a failed push attempt (origin/main exists) ---"
BAREDIR_RR="$(mktemp -d 2>/dev/null || mktemp -d -t mb-rr-bare)"
git init -q --bare "$BAREDIR_RR"
git -C "$TMPDIR_RR" remote add origin "$BAREDIR_RR" 2>/dev/null || git -C "$TMPDIR_RR" remote set-url origin "$BAREDIR_RR"
git -C "$TMPDIR_RR" push -q -u origin main 2>/dev/null

rm -f "$TMPDIR_RR/.claude/.change-review-ok" "$TMPDIR_RR/.claude/.pending-push-presha"
presha=$(git -C "$TMPDIR_RR" rev-parse '@{u}')
printf '%s' "$presha" > "$TMPDIR_RR/.claude/.pending-push-presha"
invoke_hook "review-reminders-post.sh" "git push origin main" >/dev/null
expected=$(git -C "$TMPDIR_RR" diff origin/main...HEAD | sha256sum | cut -d' ' -f1)
actual=$(cat "$TMPDIR_RR/.claude/.change-review-ok" 2>/dev/null)
assert_contains "$actual" "$expected" "review-reminders-post.sh reissues .change-review-ok with the correct diff_hash() output when the upstream ref didn't move (failed push, origin/main path)"
rm -rf "$BAREDIR_RR"

# ── merge gate: gh pr merge is unconditionally denied ────────────────────────────────────────
echo ""
echo "--- merge gate: gh pr merge is always denied (review-reminders.sh) ---"
resp=$(invoke_hook "review-reminders.sh" "gh pr merge 8 --repo owner/repo --squash")
assert_contains "$resp" '"permissionDecision":"deny"' "review-reminders.sh denies gh pr merge unconditionally"

echo ""
echo "--- merge gate: plain git merge is NOT caught by the gh pr merge pattern ---"
resp=$(invoke_hook "review-reminders.sh" "git merge feature-branch")
assert_not_contains "$resp" '"permissionDecision":"deny"' "review-reminders.sh does not deny a plain git merge"

if command -v pwsh >/dev/null 2>&1; then
  echo ""
  echo "--- merge gate: gh pr merge is always denied (review-reminders.ps1) ---"
  resp=$(invoke_hook_ps1 "gh pr merge 8 --repo owner/repo --squash")
  assert_contains "$resp" '"permissionDecision":"deny"' "review-reminders.ps1 denies gh pr merge unconditionally"

  echo ""
  echo "--- merge gate: plain git merge is NOT caught (review-reminders.ps1) ---"
  resp=$(invoke_hook_ps1 "git merge feature-branch")
  assert_not_contains "$resp" '"permissionDecision":"deny"' "review-reminders.ps1 does not deny a plain git merge"
else
  echo ""
  echo "--- merge gate PowerShell tests: SKIPPED (pwsh not installed on this machine) ---"
fi

# ── worktree-root fix: hook resolves root from the command's own leading cd ─────────────────
echo ""
echo "--- worktree-root fix: correct marker found via leading cd, even when spawned elsewhere ---"
if command -v python3 >/dev/null 2>&1; then
  TMPDIR_WRONG_RR="$(mktemp -d 2>/dev/null || mktemp -d -t mb-rr-wrong)"
  git init -q -b main "$TMPDIR_WRONG_RR"

  echo "line five" >> "$TMPDIR_RR/file.txt"
  write_marker_bash_recipe ".code-review-ok"
  resp=$(invoke_hook_from "review-reminders.sh" "$TMPDIR_WRONG_RR" "cd \\\"$TMPDIR_RR\\\" && git commit -m test6")
  assert_not_contains "$resp" '"permissionDecision":"deny"' "review-reminders.sh resolves root from the command's leading cd, finding the correct marker, even though the hook process itself was spawned from an unrelated directory"

  echo ""
  echo "--- worktree-root fix: negative control (wrong marker at the cd-derived root still denies) ---"
  echo "line six" >> "$TMPDIR_RR/file.txt"
  # Explicitly write a marker that does NOT match the current diff (rather than relying on
  # the previous test's marker having been consumed) -- this specifically proves a *wrong*
  # marker at the cd-derived root is rejected, not just an *absent* one (already covered by
  # the existing "marker is single-use" test earlier in this file).
  printf '%s' "0000000000000000000000000000000000000000000000000000000000000000" > "$TMPDIR_RR/.claude/.code-review-ok"
  resp=$(invoke_hook_from "review-reminders.sh" "$TMPDIR_WRONG_RR" "cd \\\"$TMPDIR_RR\\\" && git commit -m test7")
  assert_contains "$resp" '"permissionDecision":"deny"' "review-reminders.sh still denies via the cd-derived root when the marker there doesn't match the diff, proving the fix doesn't weaken hash validation"

  # The deny above is ambiguous by itself: it looks identical whether root resolution correctly
  # found $TMPDIR_RR and rejected its stale marker, OR silently fell back to $TMPDIR_WRONG_RR
  # (which has no .claude/ directory at all) and denied for finding no marker whatsoever --
  # confirmed by direct reproduction that this test previously couldn't tell the two apart.
  # consume_marker()'s atomic mv only removes the marker file it actually operates on, so
  # checking that the marker at $TMPDIR_RR/.claude/.code-review-ok is gone afterward proves the
  # hook really did resolve root to $TMPDIR_RR (not fall back), and denied because its content
  # didn't match -- not for the wrong reason.
  assert_file_not_exists "$TMPDIR_RR/.claude/.code-review-ok" "review-reminders.sh consumed the marker at the cd-derived root (not a wrong fallback directory), confirming the prior deny was a real hash mismatch rather than root-resolution silently failing"

  rm -rf "$TMPDIR_WRONG_RR"
else
  echo "SKIPPED (python3 not installed on this machine — resolve_cd_root() fails open to ambient cwd, already covered by the rest of this suite)"
fi

# ── chained-cd fix: root resolves to the LAST cd, not the first ────────────────────────────
# WHY this test exists: resolve_cd_root() used to extract only the FIRST leading `cd "X" &&`
# from tool_input.command. For a chained command (`cd "A" && cd "B" && git commit ...`), that
# meant root, marker lookup, and diff_hash all resolved against A while the actual git command
# ran in B -- a decoy repo A with its own genuinely-valid marker could authorize a commit in a
# completely different repo B whose diff was never reviewed. Reproduced directly before this
# fix: the sed/regex extraction returned A's path from that exact chained string.
echo ""
echo "--- chained-cd fix: root resolves to the LAST cd in a multi-cd command, not the first ---"
if command -v python3 >/dev/null 2>&1; then
  TMPDIR_DECOY_A="$(mktemp -d 2>/dev/null || mktemp -d -t mb-rr-decoy)"
  git -C "$TMPDIR_DECOY_A" init -q -b main
  git -C "$TMPDIR_DECOY_A" config user.email "test@example.com"
  git -C "$TMPDIR_DECOY_A" config user.name "Test"
  echo "decoy one" > "$TMPDIR_DECOY_A/file.txt"
  git -C "$TMPDIR_DECOY_A" add file.txt
  git -C "$TMPDIR_DECOY_A" commit -q -m "initial"
  mkdir -p "$TMPDIR_DECOY_A/.claude"
  echo "decoy two" >> "$TMPDIR_DECOY_A/file.txt"
  # Decoy A gets its own genuinely-valid marker for ITS OWN diff -- proving this isn't just an
  # absent/stale marker being rejected, but a real, currently-valid marker that must NOT be
  # usable to authorize a commit actually happening in a different repo (RR).
  tmp=$(mktemp)
  git -C "$TMPDIR_DECOY_A" diff HEAD > "$tmp" 2>/dev/null
  sha256sum "$tmp" | cut -d' ' -f1 > "$TMPDIR_DECOY_A/.claude/.code-review-ok"
  rm -f "$tmp"

  echo "line seven" >> "$TMPDIR_RR/file.txt"
  rm -f "$TMPDIR_RR/.claude/.code-review-ok"
  resp=$(invoke_hook_from "review-reminders.sh" "$TMPDIR_DECOY_A" "cd \\\"$TMPDIR_DECOY_A\\\" && cd \\\"$TMPDIR_RR\\\" && git commit -m test8")
  assert_contains "$resp" '"permissionDecision":"deny"' "review-reminders.sh resolves root to the LAST cd (RR) in a chained command, not the first (decoy A) — denies because RR has no valid marker of its own, proving decoy A's valid-but-unrelated marker cannot be reused to authorize a commit actually happening in RR"

  # If root had wrongly resolved to decoy A (the pre-fix bug), decoy A's marker would have
  # been consumed and the commit allowed. Confirming it's still present proves root correctly
  # resolved to RR, not A.
  assert_file_exists "$TMPDIR_DECOY_A/.claude/.code-review-ok" "review-reminders.sh did not touch decoy A's marker — confirming root resolved to RR (the last cd), not A (the first)"

  rm -rf "$TMPDIR_DECOY_A"
else
  echo "SKIPPED (python3 not installed on this machine — resolve_cd_root() fails open to ambient cwd, already covered by the rest of this suite)"
fi

# ── whitespace-variant fix: bash and PowerShell now accept the same cd-prefix shapes ────────
# WHY this test exists: bash's original sed pattern required exactly one space before `&&`
# (`cd "path" &&`); review-reminders.ps1's regex was more permissive (`\s+`/`\s*`). A command
# like `cd "path"&&git commit` (no space before `&&`) resolved correctly on PowerShell but
# silently fell back to ambient cwd on bash -- an unstated cross-platform divergence. The
# chained-cd fix above unified both hooks on the same permissive `\s+`/`\s*` shape; this proves
# bash now accepts a tight-whitespace variant it previously rejected.
echo ""
echo "--- whitespace-variant fix: review-reminders.sh accepts a cd prefix with no space before && ---"
if command -v python3 >/dev/null 2>&1; then
  TMPDIR_WRONG_WS="$(mktemp -d 2>/dev/null || mktemp -d -t mb-rr-wrongws)"
  git init -q -b main "$TMPDIR_WRONG_WS"

  echo "line eight" >> "$TMPDIR_RR/file.txt"
  write_marker_bash_recipe ".code-review-ok"
  resp=$(invoke_hook_from "review-reminders.sh" "$TMPDIR_WRONG_WS" "cd \\\"$TMPDIR_RR\\\"&&git commit -m test9")
  assert_not_contains "$resp" '"permissionDecision":"deny"' "review-reminders.sh resolves root from a cd prefix with no space before && (tight-whitespace variant), even though the hook process was spawned from an unrelated directory"

  rm -rf "$TMPDIR_WRONG_WS"
else
  echo "SKIPPED (python3 not installed on this machine — resolve_cd_root() fails open to ambient cwd, already covered by the rest of this suite)"
fi

print_summary
