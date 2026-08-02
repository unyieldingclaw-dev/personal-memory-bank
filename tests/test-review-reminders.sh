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

invoke_hook_ps1_post() {
  # invoke_hook_ps1_post <command-text> — like invoke_hook_ps1, but for the PostToolUse
  # companion script (review-reminders-post.ps1) instead of the PreToolUse gate.
  local command="$1"
  printf '{"tool_input":{"command":"%s"}}' "$command" \
    | (cd "$TMPDIR_RR" && pwsh -NonInteractive -File "$REPO_ROOT/scripts/review-reminders-post.ps1" 2>/dev/null)
}

invoke_hook_with_description() {
  # invoke_hook_with_description <script> <command-text> <description-text> — builds a
  # tool_input payload carrying BOTH command and description, mirroring the real Bash tool's
  # PreToolUse/PostToolUse JSON shape, to test that matching keys off tool_input.command alone
  # and not the raw stdin payload (which also contains description).
  local script="$1" command="$2" description="$3"
  printf '{"tool_input":{"command":"%s","description":"%s"}}' "$command" "$description" \
    | (cd "$TMPDIR_RR" && bash "$REPO_ROOT/scripts/$script" 2>/dev/null)
}

invoke_hook_ps1_from() {
  # invoke_hook_ps1_from <spawn-dir> <command-text> — like invoke_hook_from, but for
  # review-reminders.ps1 instead of the bash script.
  local spawn_dir="$1" command="$2"
  printf '{"tool_input":{"command":"%s"}}' "$command" \
    | (cd "$spawn_dir" && pwsh -NonInteractive -File "$REPO_ROOT/scripts/review-reminders.ps1" 2>/dev/null)
}

win_path_for_json() {
  # win_path_for_json <bash-path> — converts a Git-Bash-style path (e.g. /tmp/tmp.XXX) to a
  # native Windows path (git.exe invoked directly from pwsh does not understand /tmp/... --
  # reproduced directly: `git -C '/tmp/tmp.XXX' rev-parse --show-toplevel` fails with "cannot
  # change to ... No such file or directory" when the calling process is pwsh, even though the
  # identical path works fine when the calling process is bash), then doubles backslashes so
  # the result is safe to embed as a JSON string value (a bare single backslash followed by a
  # letter, e.g. \U, is not a valid JSON escape sequence).
  cygpath -w "$1" | sed 's/\\/\\\\/g'
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
# WHY every "does not deny" assertion below is paired with an assert_exit_zero check: these
# hooks print NOTHING on the allow path (a bare `exit 0`, no stdout at all) and every
# invoke_hook* helper redirects stderr away -- so a hook that silently crashed (e.g. a shell
# syntax error from a future edit, which produces empty stdout and a non-zero exit) would look
# byte-for-byte identical to a hook that correctly allowed the command, as far as
# assert_not_contains alone can tell. Checking the exit code too closes that gap.
echo ""
echo "--- commit gate: bash recipe accepted by review-reminders.sh ---"
echo "line two" >> "$TMPDIR_RR/file.txt"
write_marker_bash_recipe ".code-review-ok"
resp=$(invoke_hook "review-reminders.sh" "git commit -m test")
rc=$?
assert_not_contains "$resp" '"permissionDecision":"deny"' "review-reminders.sh accepts a marker written via its own documented bash recipe"
assert_exit_zero "$rc" "hook exited 0 (not a crash) for: review-reminders.sh accepts a marker written via its own documented bash recipe"

# ── commit gate: consumed marker denies a second attempt ────────────────────────────────────
echo ""
echo "--- commit gate: marker is single-use ---"
resp=$(invoke_hook "review-reminders.sh" "git commit -m test2")
assert_contains "$resp" '"permissionDecision":"deny"' "review-reminders.sh denies a second commit with no new marker"

# ── compound-command fix: git commit && git push requires BOTH markers, not just the first ──
# WHY this test exists: the gate used to be a `case`/`if-elseif` that stops at the FIRST
# matching pattern. A compound command like `git commit -m x && git push origin main` matches
# `*git commit*` first, so the push half -- which needs its own .change-review-ok marker from
# the heavier /change-review gate -- was never even checked. Empirically reproduced before this
# fix: seeding only a valid .code-review-ok marker let a chained commit+push through untouched.
echo ""
echo "--- compound-command fix: commit+push chained via && is denied when only .code-review-ok is valid ---"
rm -f "$TMPDIR_RR/.claude/.code-review-ok" "$TMPDIR_RR/.claude/.change-review-ok"
echo "compound line one" >> "$TMPDIR_RR/file.txt"
write_marker_bash_recipe ".code-review-ok"
resp=$(invoke_hook "review-reminders.sh" "git commit -m compound1 && git push origin main")
assert_contains "$resp" '"permissionDecision":"deny"' "review-reminders.sh denies a compound 'git commit && git push' when only .code-review-ok is valid and .change-review-ok is missing -- proves the push half can't ride through on the commit's marker alone"

echo ""
echo "--- compound-command fix: reverse case -- denied when only .change-review-ok is valid ---"
rm -f "$TMPDIR_RR/.claude/.code-review-ok" "$TMPDIR_RR/.claude/.change-review-ok"
tmp=$(mktemp)
git -C "$TMPDIR_RR" diff HEAD > "$tmp" 2>/dev/null
sha256sum "$tmp" | cut -d' ' -f1 > "$TMPDIR_RR/.claude/.change-review-ok"
rm -f "$tmp"
resp=$(invoke_hook "review-reminders.sh" "git commit -m compound2 && git push origin main")
assert_contains "$resp" '"permissionDecision":"deny"' "review-reminders.sh denies a compound 'git commit && git push' when only .change-review-ok is valid and .code-review-ok is missing"

echo ""
echo "--- compound-command fix: negative control -- a standalone commit with a valid marker still works ---"
rm -f "$TMPDIR_RR/.claude/.change-review-ok"
write_marker_bash_recipe ".code-review-ok"
resp=$(invoke_hook "review-reminders.sh" "git commit -m compound3")
rc=$?
assert_not_contains "$resp" '"permissionDecision":"deny"' "review-reminders.sh still allows a standalone git commit with a valid .code-review-ok marker (the compound-command fix didn't break the plain-commit case)"
assert_exit_zero "$rc" "hook exited 0 (not a crash) for: review-reminders.sh still allows a standalone git commit with a valid .code-review-ok marker (the compound-command fix didn't break the plain-commit case)"

echo ""
echo "--- compound-command fix: both markers valid allows the compound command through and consumes both ---"
rm -f "$TMPDIR_RR/.claude/.code-review-ok" "$TMPDIR_RR/.claude/.change-review-ok" "$TMPDIR_RR/.claude/.pending-commit-presha" "$TMPDIR_RR/.claude/.pending-push-presha"
echo "compound line two" >> "$TMPDIR_RR/file.txt"
write_marker_bash_recipe ".code-review-ok"
tmp=$(mktemp)
git -C "$TMPDIR_RR" diff HEAD > "$tmp" 2>/dev/null
sha256sum "$tmp" | cut -d' ' -f1 > "$TMPDIR_RR/.claude/.change-review-ok"
rm -f "$tmp"
resp=$(invoke_hook "review-reminders.sh" "git commit -m compound4 && git push origin main")
rc=$?
assert_not_contains "$resp" '"permissionDecision":"deny"' "review-reminders.sh allows a compound git commit && git push when BOTH .code-review-ok and .change-review-ok are valid"
assert_exit_zero "$rc" "hook exited 0 (not a crash) for: review-reminders.sh allows a compound git commit && git push when BOTH .code-review-ok and .change-review-ok are valid"
assert_file_not_exists "$TMPDIR_RR/.claude/.code-review-ok" "the compound command consumed .code-review-ok"
assert_file_not_exists "$TMPDIR_RR/.claude/.change-review-ok" "the compound command consumed .change-review-ok"
assert_file_exists "$TMPDIR_RR/.claude/.pending-commit-presha" "the compound command recorded a pending-commit-presha"
# WHY no pending-push-presha assertion here: no upstream/remote is configured for $TMPDIR_RR
# yet at this point in the suite (that setup happens later, in the "failed push attempt" test
# below), so `git rev-parse '@{u}'` legitimately returns empty and no file is written -- this
# is the same pre-existing conditional behavior as the single-command push case, not something
# this fix changed. Push-side presha writing is verified with a real upstream further down.
rm -f "$TMPDIR_RR/.claude/.pending-commit-presha" "$TMPDIR_RR/.claude/.pending-push-presha"

# ── cross-shell parity: bash-written marker accepted by review-reminders.ps1 ────────────────
if command -v pwsh >/dev/null 2>&1; then
  echo ""
  echo "--- cross-shell parity: bash-written marker accepted by review-reminders.ps1 ---"
  echo "line three" >> "$TMPDIR_RR/file.txt"
  write_marker_bash_recipe ".code-review-ok"
  resp=$(invoke_hook_ps1 "git commit -m test3")
  rc=$?
  assert_not_contains "$resp" '"permissionDecision":"deny"' "review-reminders.ps1 accepts a marker written via the bash-documented recipe (regression test for the trailing-newline hash mismatch)"
  assert_exit_zero "$rc" "hook exited 0 (not a crash) for: review-reminders.ps1 accepts a marker written via the bash-documented recipe (regression test for the trailing-newline hash mismatch)"

  # ── compound-command fix (PowerShell): git commit && git push requires BOTH markers ────────
  # WHY this test exists: review-reminders.ps1 had the identical if/elseif-stops-at-first-match
  # bug as review-reminders.sh's old case/esac, and this file's own comments elsewhere call
  # PowerShell "the PREFERRED runtime" -- yet only review-reminders.sh had compound-command
  # regression coverage. Mirrors the bash compound-command tests above.
  echo ""
  echo "--- compound-command fix (PS1): commit+push chained via && is denied when only .code-review-ok is valid ---"
  rm -f "$TMPDIR_RR/.claude/.code-review-ok" "$TMPDIR_RR/.claude/.change-review-ok"
  echo "ps1 compound line one" >> "$TMPDIR_RR/file.txt"
  write_marker_bash_recipe ".code-review-ok"
  resp=$(invoke_hook_ps1 "git commit -m ps1compound1 && git push origin main")
  assert_contains "$resp" '"permissionDecision":"deny"' "review-reminders.ps1 denies a compound 'git commit && git push' when only .code-review-ok is valid and .change-review-ok is missing"

  echo ""
  echo "--- compound-command fix (PS1): reverse case -- denied when only .change-review-ok is valid ---"
  rm -f "$TMPDIR_RR/.claude/.code-review-ok" "$TMPDIR_RR/.claude/.change-review-ok"
  tmp=$(mktemp)
  git -C "$TMPDIR_RR" diff HEAD > "$tmp" 2>/dev/null
  sha256sum "$tmp" | cut -d' ' -f1 > "$TMPDIR_RR/.claude/.change-review-ok"
  rm -f "$tmp"
  resp=$(invoke_hook_ps1 "git commit -m ps1compound2 && git push origin main")
  assert_contains "$resp" '"permissionDecision":"deny"' "review-reminders.ps1 denies a compound 'git commit && git push' when only .change-review-ok is valid and .code-review-ok is missing"

  echo ""
  echo "--- compound-command fix (PS1): both markers valid allows the compound command through and consumes both ---"
  rm -f "$TMPDIR_RR/.claude/.code-review-ok" "$TMPDIR_RR/.claude/.change-review-ok" "$TMPDIR_RR/.claude/.pending-commit-presha" "$TMPDIR_RR/.claude/.pending-push-presha" "$TMPDIR_RR/.claude/.pending-commit-hash" "$TMPDIR_RR/.claude/.pending-push-hash"
  echo "ps1 compound line two" >> "$TMPDIR_RR/file.txt"
  write_marker_bash_recipe ".code-review-ok"
  tmp=$(mktemp)
  git -C "$TMPDIR_RR" diff HEAD > "$tmp" 2>/dev/null
  sha256sum "$tmp" | cut -d' ' -f1 > "$TMPDIR_RR/.claude/.change-review-ok"
  rm -f "$tmp"
  resp=$(invoke_hook_ps1 "git commit -m ps1compound3 && git push origin main")
  rc=$?
  assert_not_contains "$resp" '"permissionDecision":"deny"' "review-reminders.ps1 allows a compound git commit && git push when BOTH .code-review-ok and .change-review-ok are valid"
  assert_exit_zero "$rc" "hook exited 0 (not a crash) for: review-reminders.ps1 allows a compound git commit && git push when BOTH .code-review-ok and .change-review-ok are valid"
  assert_file_not_exists "$TMPDIR_RR/.claude/.code-review-ok" "the PS1 compound command consumed .code-review-ok"
  assert_file_not_exists "$TMPDIR_RR/.claude/.change-review-ok" "the PS1 compound command consumed .change-review-ok"
  rm -f "$TMPDIR_RR/.claude/.pending-commit-presha" "$TMPDIR_RR/.claude/.pending-push-presha" "$TMPDIR_RR/.claude/.pending-commit-hash" "$TMPDIR_RR/.claude/.pending-push-hash"
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
rc=$?
assert_not_contains "$resp" '"permissionDecision":"deny"' "review-reminders.sh accepts a push-gate marker computed via the HEAD fallback (no origin/main ref exists)"
assert_exit_zero "$rc" "hook exited 0 (not a crash) for: review-reminders.sh accepts a push-gate marker computed via the HEAD fallback (no origin/main ref exists)"

# ── post-hook: reissues a marker after a failed commit attempt (diff_hash refactor) ─────────
# WHY this test now also writes .pending-commit-hash (not just presha): see the "reissue-hash
# fix" tests further below for the actual regression this guards against -- the post-hook no
# longer recomputes a fresh hash at reissue time, it replays the ORIGINAL hash the pre-hook
# validated. This test's tree doesn't change between "presha capture" and reissue, so the
# original and a fresh hash happen to be identical here -- it's still a valid smoke test of the
# replay path, just not the specific bug the dedicated test below proves.
echo ""
echo "--- post-hook: reissues marker via the persisted original hash after a failed commit attempt ---"
rm -f "$TMPDIR_RR/.claude/.code-review-ok" "$TMPDIR_RR/.claude/.pending-commit-presha" "$TMPDIR_RR/.claude/.pending-commit-hash"
presha=$(git -C "$TMPDIR_RR" rev-parse HEAD)
printf '%s' "$presha" > "$TMPDIR_RR/.claude/.pending-commit-presha"
orighash=$(git -C "$TMPDIR_RR" diff HEAD | sha256sum | cut -d' ' -f1)
printf '%s' "$orighash" > "$TMPDIR_RR/.claude/.pending-commit-hash"
invoke_hook "review-reminders-post.sh" "git commit -m test5" >/dev/null
actual=$(cat "$TMPDIR_RR/.claude/.code-review-ok" 2>/dev/null)
assert_contains "$actual" "$orighash" "review-reminders-post.sh reissues .code-review-ok with the persisted original hash when HEAD didn't move (failed commit)"
assert_file_not_exists "$TMPDIR_RR/.claude/.pending-commit-hash" "review-reminders-post.sh cleans up .pending-commit-hash after reissuing"

# ── git-argument-aware fix: post-hook reissues for a 'git -C <path> commit' failed attempt ──
# WHY this test exists: proves classify_targets() is wired into review-reminders-post.sh too,
# not just the PreToolUse gate -- a failed 'git -C /path commit' attempt must still be
# recognized as a commit attempt for the marker to be reissued.
echo ""
echo "--- git-argument-aware fix: post-hook reissues marker for a 'git -C <path> commit' failed attempt ---"
rm -f "$TMPDIR_RR/.claude/.code-review-ok" "$TMPDIR_RR/.claude/.pending-commit-presha" "$TMPDIR_RR/.claude/.pending-commit-hash"
presha=$(git -C "$TMPDIR_RR" rev-parse HEAD)
printf '%s' "$presha" > "$TMPDIR_RR/.claude/.pending-commit-presha"
orighash=$(git -C "$TMPDIR_RR" diff HEAD | sha256sum | cut -d' ' -f1)
printf '%s' "$orighash" > "$TMPDIR_RR/.claude/.pending-commit-hash"
invoke_hook "review-reminders-post.sh" "git -C /some/repo commit -m testgitc" >/dev/null
actual=$(cat "$TMPDIR_RR/.claude/.code-review-ok" 2>/dev/null)
assert_contains "$actual" "$orighash" "review-reminders-post.sh reissues .code-review-ok for a 'git -C' form commit attempt"

# ── post-hook: reissues a marker after a failed push attempt (origin/main path, not fallback) ─
echo ""
echo "--- post-hook: reissues marker via the persisted original hash after a failed push attempt (origin/main exists) ---"
BAREDIR_RR="$(mktemp -d 2>/dev/null || mktemp -d -t mb-rr-bare)"
git init -q --bare "$BAREDIR_RR"
git -C "$TMPDIR_RR" remote add origin "$BAREDIR_RR" 2>/dev/null || git -C "$TMPDIR_RR" remote set-url origin "$BAREDIR_RR"
git -C "$TMPDIR_RR" push -q -u origin main 2>/dev/null

rm -f "$TMPDIR_RR/.claude/.change-review-ok" "$TMPDIR_RR/.claude/.pending-push-presha" "$TMPDIR_RR/.claude/.pending-push-hash"
presha=$(git -C "$TMPDIR_RR" rev-parse '@{u}')
printf '%s' "$presha" > "$TMPDIR_RR/.claude/.pending-push-presha"
orighash=$(git -C "$TMPDIR_RR" diff origin/main...HEAD | sha256sum | cut -d' ' -f1)
printf '%s' "$orighash" > "$TMPDIR_RR/.claude/.pending-push-hash"
invoke_hook "review-reminders-post.sh" "git push origin main" >/dev/null
actual=$(cat "$TMPDIR_RR/.claude/.change-review-ok" 2>/dev/null)
assert_contains "$actual" "$orighash" "review-reminders-post.sh reissues .change-review-ok with the persisted original hash when the upstream ref didn't move (failed push, origin/main path)"
assert_file_not_exists "$TMPDIR_RR/.claude/.pending-push-hash" "review-reminders-post.sh cleans up .pending-push-hash after reissuing"
rm -rf "$BAREDIR_RR"

# ── reissue-hash fix: reissued marker is the ORIGINAL hash, not a hash freshly recomputed now ─
# WHY this test exists: the post-hook used to recompute diff_hash HEAD fresh at reissue time,
# reasoning "a failed commit can't have altered the working tree." That's false whenever a
# downstream project's OWN pre-commit hook mutates files and then rejects the commit (e.g. an
# auto-formatter like `black --check`/`prettier --check`) -- HEAD doesn't move, but the diff
# does. The old behavior would reissue a marker matching the MUTATED tree, which /code-review
# never actually saw. This test simulates exactly that: capture the original hash, mutate the
# tree afterward (standing in for the formatter), then confirm the reissued marker matches the
# ORIGINAL hash captured before the mutation, not a fresh hash of the now-different tree.
echo ""
echo "--- reissue-hash fix: reissued marker matches the ORIGINAL pre-mutation hash, not a fresh post-mutation recompute ---"
rm -f "$TMPDIR_RR/.claude/.code-review-ok" "$TMPDIR_RR/.claude/.pending-commit-presha" "$TMPDIR_RR/.claude/.pending-commit-hash"
echo "pre-mutation line" >> "$TMPDIR_RR/file.txt"
presha=$(git -C "$TMPDIR_RR" rev-parse HEAD)
printf '%s' "$presha" > "$TMPDIR_RR/.claude/.pending-commit-presha"
orighash=$(git -C "$TMPDIR_RR" diff HEAD | sha256sum | cut -d' ' -f1)
printf '%s' "$orighash" > "$TMPDIR_RR/.claude/.pending-commit-hash"
# Simulate a mutating pre-commit hook (e.g. an auto-formatter) that changed the tree further
# and then rejected the commit -- HEAD still hasn't moved, but the diff is now different.
echo "post-mutation line (simulates an auto-formatter)" >> "$TMPDIR_RR/file.txt"
freshhash=$(git -C "$TMPDIR_RR" diff HEAD | sha256sum | cut -d' ' -f1)
[ "$orighash" != "$freshhash" ] || { echo "TEST SETUP BUG: orighash and freshhash should differ"; exit 1; }
invoke_hook "review-reminders-post.sh" "git commit -m test-mutation" >/dev/null
actual=$(cat "$TMPDIR_RR/.claude/.code-review-ok" 2>/dev/null)
assert_contains "$actual" "$orighash" "review-reminders-post.sh reissues the ORIGINAL pre-mutation hash, not a fresh recompute of the now-mutated tree"
assert_not_contains "$actual" "$freshhash" "the reissued marker does NOT match the mutated tree's fresh hash -- proving the mutated diff was never actually authorized"
git -C "$TMPDIR_RR" checkout -- file.txt
rm -f "$TMPDIR_RR/.claude/.code-review-ok"

# ── reissue-hash fix (PowerShell): reissued marker is the ORIGINAL hash, not a fresh recompute ─
# WHY this test exists: review-reminders-post.ps1 has the identical persist-and-replay /
# fail-closed logic as review-reminders-post.sh, but nothing in this suite ever invoked
# review-reminders-post.ps1 at all -- the PowerShell reissue path (including its own
# fail-closed guard) was completely unexercised. Mirrors the bash mutation test above.
if command -v pwsh >/dev/null 2>&1; then
  echo ""
  echo "--- reissue-hash fix (PS1): reissued marker matches the ORIGINAL pre-mutation hash, not a fresh post-mutation recompute ---"
  rm -f "$TMPDIR_RR/.claude/.code-review-ok" "$TMPDIR_RR/.claude/.pending-commit-presha" "$TMPDIR_RR/.claude/.pending-commit-hash"
  echo "ps1 pre-mutation line" >> "$TMPDIR_RR/file.txt"
  presha=$(git -C "$TMPDIR_RR" rev-parse HEAD)
  printf '%s' "$presha" > "$TMPDIR_RR/.claude/.pending-commit-presha"
  orighash=$(git -C "$TMPDIR_RR" diff HEAD | sha256sum | cut -d' ' -f1)
  printf '%s' "$orighash" > "$TMPDIR_RR/.claude/.pending-commit-hash"
  # Simulate a mutating pre-commit hook (e.g. an auto-formatter) that changed the tree further
  # and then rejected the commit -- HEAD still hasn't moved, but the diff is now different.
  echo "ps1 post-mutation line (simulates an auto-formatter)" >> "$TMPDIR_RR/file.txt"
  freshhash=$(git -C "$TMPDIR_RR" diff HEAD | sha256sum | cut -d' ' -f1)
  [ "$orighash" != "$freshhash" ] || { echo "TEST SETUP BUG: orighash and freshhash should differ"; exit 1; }
  invoke_hook_ps1_post "git commit -m ps1-test-mutation" >/dev/null
  actual=$(cat "$TMPDIR_RR/.claude/.code-review-ok" 2>/dev/null)
  assert_contains "$actual" "$orighash" "review-reminders-post.ps1 reissues the ORIGINAL pre-mutation hash, not a fresh recompute of the now-mutated tree"
  assert_not_contains "$actual" "$freshhash" "the PS1-reissued marker does NOT match the mutated tree's fresh hash -- proving the mutated diff was never actually authorized"
  assert_file_not_exists "$TMPDIR_RR/.claude/.pending-commit-hash" "review-reminders-post.ps1 cleans up .pending-commit-hash after reissuing"
  git -C "$TMPDIR_RR" checkout -- file.txt
  rm -f "$TMPDIR_RR/.claude/.code-review-ok"
else
  echo ""
  echo "--- reissue-hash fix (PS1) test: SKIPPED (pwsh not installed on this machine) ---"
fi

# ── merge gate: gh pr merge is unconditionally denied ────────────────────────────────────────
echo ""
echo "--- merge gate: gh pr merge is always denied (review-reminders.sh) ---"
resp=$(invoke_hook "review-reminders.sh" "gh pr merge 8 --repo owner/repo --squash")
assert_contains "$resp" '"permissionDecision":"deny"' "review-reminders.sh denies gh pr merge unconditionally"

echo ""
echo "--- merge gate: plain git merge is NOT caught by the gh pr merge pattern ---"
resp=$(invoke_hook "review-reminders.sh" "git merge feature-branch")
rc=$?
assert_not_contains "$resp" '"permissionDecision":"deny"' "review-reminders.sh does not deny a plain git merge"
assert_exit_zero "$rc" "hook exited 0 (not a crash) for: review-reminders.sh does not deny a plain git merge"

if command -v pwsh >/dev/null 2>&1; then
  echo ""
  echo "--- merge gate: gh pr merge is always denied (review-reminders.ps1) ---"
  resp=$(invoke_hook_ps1 "gh pr merge 8 --repo owner/repo --squash")
  assert_contains "$resp" '"permissionDecision":"deny"' "review-reminders.ps1 denies gh pr merge unconditionally"

  echo ""
  echo "--- merge gate: plain git merge is NOT caught (review-reminders.ps1) ---"
  resp=$(invoke_hook_ps1 "git merge feature-branch")
  rc=$?
  assert_not_contains "$resp" '"permissionDecision":"deny"' "review-reminders.ps1 does not deny a plain git merge"
  assert_exit_zero "$rc" "hook exited 0 (not a crash) for: review-reminders.ps1 does not deny a plain git merge"

  # WHY this test exists: mirrors the bash "fallback fix: denies gh pr merge via the raw-stdin
  # fallback" test above -- review-reminders.ps1 dropped its own $extracted-only guard on the
  # merge check, but nothing had exercised malformed (non-JSON) stdin specifically for the
  # merge case on the PowerShell side, only the well-formed-JSON path.
  echo ""
  echo "--- fallback fix: review-reminders.ps1 still denies gh pr merge via the raw-stdin fallback on malformed (non-JSON) stdin ---"
  resp=$(printf 'not valid json but contains gh pr merge anyway' | (cd "$TMPDIR_RR" && pwsh -NonInteractive -File "$REPO_ROOT/scripts/review-reminders.ps1" 2>/dev/null))
  assert_contains "$resp" '"permissionDecision":"deny"' "review-reminders.ps1 denies gh pr merge via the raw-stdin fallback, not just the extracted-JSON path"
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
  rc=$?
  assert_not_contains "$resp" '"permissionDecision":"deny"' "review-reminders.sh resolves root from the command's leading cd, finding the correct marker, even though the hook process itself was spawned from an unrelated directory"
  assert_exit_zero "$rc" "hook exited 0 (not a crash) for: review-reminders.sh resolves root from the command's leading cd, finding the correct marker, even though the hook process itself was spawned from an unrelated directory"

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
  rc=$?
  assert_not_contains "$resp" '"permissionDecision":"deny"' "review-reminders.sh resolves root from a cd prefix with no space before && (tight-whitespace variant), even though the hook process was spawned from an unrelated directory"
  assert_exit_zero "$rc" "hook exited 0 (not a crash) for: review-reminders.sh resolves root from a cd prefix with no space before && (tight-whitespace variant), even though the hook process was spawned from an unrelated directory"

  rm -rf "$TMPDIR_WRONG_WS"
else
  echo "SKIPPED (python3 not installed on this machine — resolve_cd_root() fails open to ambient cwd, already covered by the rest of this suite)"
fi

# ── PowerShell coverage: worktree-root, chained-cd, and whitespace-variant fixes ────────────
# WHY these tests exist: the bash tests above only exercise review-reminders.sh. The identical
# cd-chain-walk logic in review-reminders.ps1 (the PREFERRED runtime -- settings.json tries
# pwsh first) had no equivalent regression coverage at all -- only the hash-marker-parity and
# gh-pr-merge tests invoked review-reminders.ps1. A regression in the PowerShell chain-walk
# regex or its Set-Location call would have gone undetected on this repo's own primary
# platform. These mirror the bash worktree-root/chained-cd/whitespace-variant tests exactly,
# against review-reminders.ps1 instead.
if command -v pwsh >/dev/null 2>&1; then
  echo ""
  echo "--- PowerShell coverage: worktree-root fix -- correct marker found via leading cd, even when spawned elsewhere ---"
  TMPDIR_WRONG_PS="$(mktemp -d 2>/dev/null || mktemp -d -t mb-rr-wrongps)"
  git init -q -b main "$TMPDIR_WRONG_PS"

  WIN_TMPDIR_RR=$(win_path_for_json "$TMPDIR_RR")
  echo "line ps-one" >> "$TMPDIR_RR/file.txt"
  write_marker_bash_recipe ".code-review-ok"
  resp=$(invoke_hook_ps1_from "$TMPDIR_WRONG_PS" "cd \\\"$WIN_TMPDIR_RR\\\" && git commit -m testps1")
  rc=$?
  assert_not_contains "$resp" '"permissionDecision":"deny"' "review-reminders.ps1 resolves root from the command's leading cd, finding the correct marker, even though the hook process itself was spawned from an unrelated directory"
  assert_exit_zero "$rc" "hook exited 0 (not a crash) for: review-reminders.ps1 resolves root from the command's leading cd, finding the correct marker, even though the hook process itself was spawned from an unrelated directory"

  echo ""
  echo "--- PowerShell coverage: worktree-root fix -- negative control (wrong marker at the cd-derived root still denies) ---"
  echo "line ps-two" >> "$TMPDIR_RR/file.txt"
  printf '%s' "0000000000000000000000000000000000000000000000000000000000000000" > "$TMPDIR_RR/.claude/.code-review-ok"
  resp=$(invoke_hook_ps1_from "$TMPDIR_WRONG_PS" "cd \\\"$WIN_TMPDIR_RR\\\" && git commit -m testps2")
  assert_contains "$resp" '"permissionDecision":"deny"' "review-reminders.ps1 still denies via the cd-derived root when the marker there doesn't match the diff, proving the fix doesn't weaken hash validation"
  assert_file_not_exists "$TMPDIR_RR/.claude/.code-review-ok" "review-reminders.ps1 consumed the marker at the cd-derived root (not a wrong fallback directory), confirming the prior deny was a real hash mismatch rather than root-resolution silently failing"

  rm -rf "$TMPDIR_WRONG_PS"

  echo ""
  echo "--- PowerShell coverage: chained-cd fix -- root resolves to the LAST cd in a multi-cd command, not the first ---"
  TMPDIR_DECOY_PS="$(mktemp -d 2>/dev/null || mktemp -d -t mb-rr-decoyps)"
  git -C "$TMPDIR_DECOY_PS" init -q -b main
  git -C "$TMPDIR_DECOY_PS" config user.email "test@example.com"
  git -C "$TMPDIR_DECOY_PS" config user.name "Test"
  echo "decoy ps one" > "$TMPDIR_DECOY_PS/file.txt"
  git -C "$TMPDIR_DECOY_PS" add file.txt
  git -C "$TMPDIR_DECOY_PS" commit -q -m "initial"
  mkdir -p "$TMPDIR_DECOY_PS/.claude"
  echo "decoy ps two" >> "$TMPDIR_DECOY_PS/file.txt"
  tmp=$(mktemp)
  git -C "$TMPDIR_DECOY_PS" diff HEAD > "$tmp" 2>/dev/null
  sha256sum "$tmp" | cut -d' ' -f1 > "$TMPDIR_DECOY_PS/.claude/.code-review-ok"
  rm -f "$tmp"

  WIN_TMPDIR_DECOY_PS=$(win_path_for_json "$TMPDIR_DECOY_PS")
  echo "line ps-three" >> "$TMPDIR_RR/file.txt"
  rm -f "$TMPDIR_RR/.claude/.code-review-ok"
  resp=$(invoke_hook_ps1_from "$TMPDIR_DECOY_PS" "cd \\\"$WIN_TMPDIR_DECOY_PS\\\" && cd \\\"$WIN_TMPDIR_RR\\\" && git commit -m testps3")
  assert_contains "$resp" '"permissionDecision":"deny"' "review-reminders.ps1 resolves root to the LAST cd (RR) in a chained command, not the first (decoy) — denies because RR has no valid marker of its own"
  assert_file_exists "$TMPDIR_DECOY_PS/.claude/.code-review-ok" "review-reminders.ps1 did not touch the decoy's marker — confirming root resolved to RR (the last cd), not the decoy (the first)"

  rm -rf "$TMPDIR_DECOY_PS"

  echo ""
  echo "--- PowerShell coverage: whitespace-variant fix -- accepts a cd prefix with no space before && ---"
  TMPDIR_WRONG_WS_PS="$(mktemp -d 2>/dev/null || mktemp -d -t mb-rr-wrongwsps)"
  git init -q -b main "$TMPDIR_WRONG_WS_PS"

  echo "line ps-four" >> "$TMPDIR_RR/file.txt"
  write_marker_bash_recipe ".code-review-ok"
  resp=$(invoke_hook_ps1_from "$TMPDIR_WRONG_WS_PS" "cd \\\"$WIN_TMPDIR_RR\\\"&&git commit -m testps4")
  rc=$?
  assert_not_contains "$resp" '"permissionDecision":"deny"' "review-reminders.ps1 resolves root from a cd prefix with no space before && (tight-whitespace variant), even though the hook process was spawned from an unrelated directory"
  assert_exit_zero "$rc" "hook exited 0 (not a crash) for: review-reminders.ps1 resolves root from a cd prefix with no space before && (tight-whitespace variant), even though the hook process was spawned from an unrelated directory"

  rm -rf "$TMPDIR_WRONG_WS_PS"
else
  echo "SKIPPED (pwsh not installed on this machine)"
fi

# ── false-positive fix: a trigger phrase in an unrelated field must not gate/reissue ────────
# WHY this test exists: both hooks used to match `*'git commit'*`/`*'git push'*` against the
# RAW stdin JSON payload, not just tool_input.command. The real Bash tool's PreToolUse/
# PostToolUse payload also carries tool_input.description alongside command -- a read-only
# command like `git log --oneline` with a description mentioning "git commit" (e.g. "Show git
# commit history") would falsely match the raw payload, even though the actual command being
# run isn't a commit at all. Matching against the parsed tool_input.command value instead
# (mirroring review-reminders.ps1, which already does this) fixes this.
echo ""
echo "--- false-positive fix: review-reminders.sh does not gate a read-only command whose description mentions a trigger phrase ---"
rm -f "$TMPDIR_RR/.claude/.code-review-ok"
resp=$(invoke_hook_with_description "review-reminders.sh" "git log --oneline -5" "Show git commit history")
rc=$?
assert_not_contains "$resp" '"permissionDecision":"deny"' "review-reminders.sh does not deny a plain git log whose description field happens to contain the phrase 'git commit'"
assert_exit_zero "$rc" "hook exited 0 (not a crash) for: review-reminders.sh does not deny a plain git log whose description field happens to contain the phrase 'git commit'"

echo ""
echo "--- false-positive fix: review-reminders-post.sh does not falsely reissue a marker for a read-only command whose description mentions a trigger phrase ---"
rm -f "$TMPDIR_RR/.claude/.code-review-ok"
presha=$(git -C "$TMPDIR_RR" rev-parse HEAD)
printf '%s' "$presha" > "$TMPDIR_RR/.claude/.pending-commit-presha"
invoke_hook_with_description "review-reminders-post.sh" "git log --oneline -5" "Show git commit history" >/dev/null
assert_file_not_exists "$TMPDIR_RR/.claude/.code-review-ok" "review-reminders-post.sh does not reissue .code-review-ok for a git log command whose description field happens to contain 'git commit'"
assert_file_exists "$TMPDIR_RR/.claude/.pending-commit-presha" "review-reminders-post.sh leaves the pending-commit-presha file untouched when the actual command isn't a commit, since it belongs to a still-pending real commit attempt"
rm -f "$TMPDIR_RR/.claude/.pending-commit-presha"

# WHY this test exists: the description-based false-positive tests above only cover the git
# commit/push branches. The gh pr merge branch reuses the same $match_target extraction but
# had no dedicated regression test proving it resists the same class of false positive -- a
# read-only command (e.g. `gh pr view`) whose description merely mentions "merge" should not
# be caught by the unconditional gh pr merge deny.
echo ""
echo "--- false-positive fix: review-reminders.sh does not deny a read-only gh command whose description mentions 'merge' ---"
resp=$(invoke_hook_with_description "review-reminders.sh" "gh pr view 8 --repo owner/repo" "check if this PR is ready to merge")
rc=$?
assert_not_contains "$resp" '"permissionDecision":"deny"' "review-reminders.sh does not deny a plain gh pr view whose description field happens to contain the word 'merge'"
assert_exit_zero "$rc" "hook exited 0 (not a crash) for: review-reminders.sh does not deny a plain gh pr view whose description field happens to contain the word 'merge'"

# ── fallback fix: malformed JSON on stdin still falls back to raw-stdin matching ────────────
# WHY this test exists: extract_command() falls back to raw-stdin matching whenever its
# python3 parse fails (json.loads throws) or python3 itself is unavailable -- but nothing in
# this suite exercised the "parse failed" branch specifically. Faking "python3 missing"
# portably across test machines is impractical (its install location varies), but feeding
# genuinely malformed JSON is cheap and exercises the same fallback branch: json.loads raises,
# extract_command() prints nothing, match_target falls back to $input. This proves the
# fallback doesn't silently disable the gate on bad input -- it degrades to exactly the
# pre-fix raw-stdin behavior, which still catches a real "git commit" substring.
echo ""
echo "--- fallback fix: review-reminders.sh still gates on malformed (non-JSON) stdin via the raw-stdin fallback ---"
resp=$(printf 'not valid json but contains git commit anyway' | (cd "$TMPDIR_RR" && bash "$REPO_ROOT/scripts/review-reminders.sh" 2>/dev/null))
assert_contains "$resp" '"permissionDecision":"deny"' "review-reminders.sh falls back to raw-stdin matching (and still denies, no marker present) when stdin isn't valid JSON, instead of silently letting the gate go unmatched"

echo ""
echo "--- fallback fix: review-reminders.sh still denies gh pr merge via the raw-stdin fallback on malformed (non-JSON) stdin ---"
# WHY this test exists: an earlier version of this fix skipped the gh-pr-merge deny entirely
# whenever extraction failed (extracted=0), reasoning that a raw-stdin false positive here was
# a worse failure direction than for commit/push. On review, that reasoning didn't hold up --
# it's the SAME failure direction (an extra, unnecessary deny) already accepted for commit/push
# on this exact fallback path, and skipping it reopened the "no legitimate case to allow
# through" gap the unconditional gh-pr-merge deny exists to close: a real `gh pr merge` command
# would have sailed through unchecked whenever python3 was unavailable or JSON parsing failed.
resp=$(printf 'not valid json but contains gh pr merge anyway' | (cd "$TMPDIR_RR" && bash "$REPO_ROOT/scripts/review-reminders.sh" 2>/dev/null))
assert_contains "$resp" '"permissionDecision":"deny"' "review-reminders.sh denies gh pr merge via the raw-stdin fallback, not just the extracted-JSON path"

echo ""
echo "--- fallback fix: review-reminders-post.sh still reissues via the raw-stdin fallback on malformed (non-JSON) stdin ---"
rm -f "$TMPDIR_RR/.claude/.code-review-ok" "$TMPDIR_RR/.claude/.pending-commit-hash"
presha=$(git -C "$TMPDIR_RR" rev-parse HEAD)
printf '%s' "$presha" > "$TMPDIR_RR/.claude/.pending-commit-presha"
expected=$(git -C "$TMPDIR_RR" diff HEAD | sha256sum | cut -d' ' -f1)
printf '%s' "$expected" > "$TMPDIR_RR/.claude/.pending-commit-hash"
printf 'not valid json but contains git commit anyway' | (cd "$TMPDIR_RR" && bash "$REPO_ROOT/scripts/review-reminders-post.sh" 2>/dev/null) >/dev/null
actual=$(cat "$TMPDIR_RR/.claude/.code-review-ok" 2>/dev/null)
assert_contains "$actual" "$expected" "review-reminders-post.sh falls back to raw-stdin matching and still reissues .code-review-ok correctly when stdin isn't valid JSON"
rm -f "$TMPDIR_RR/.claude/.pending-commit-presha"

# ── quote-split fix: a quote-split "git commit" still gates, even though the raw command text
# never contains "git commit" as a contiguous substring ────────────────────────────────────
# WHY this test exists: a command like `git c"o"mmit -m "x"` executes, after the real shell's
# own quote removal, as a genuine `git commit -m x` -- but matching the UN-stripped command
# text (whether via extracted JSON or the raw-stdin fallback) never finds "git commit" as a
# contiguous run of characters, so the gate silently missed it. Reproduced directly and
# empirically against this exact file, confirmed present even on origin/main (predating every
# other fix here): piping {"tool_input":{"command":"git c\"o\"mmit -m \"x\""}} in previously
# exited 0 with no deny at all -- a real, unreviewed commit would have gone through untouched.
echo ""
echo "--- quote-split fix: a quote-split 'git c\"o\"mmit' is still denied (review-reminders.sh) ---"
rm -f "$TMPDIR_RR/.claude/.code-review-ok"
resp=$(printf '{"tool_input":{"command":"git c\\"o\\"mmit -m \\"x\\""}}' | (cd "$TMPDIR_RR" && bash "$REPO_ROOT/scripts/review-reminders.sh" 2>/dev/null))
rc=$?
assert_contains "$resp" '"permissionDecision":"deny"' 'review-reminders.sh denies a quote-split git c"o"mmit even though the raw text never contains "git commit" as a contiguous substring'
assert_exit_zero "$rc" "hook exited 0 (not a crash) for: review-reminders.sh denies a quote-split git commit"

echo ""
echo "--- quote-split fix: case-folding also closes 'Git Commit' (mixed case), matching review-reminders.ps1's case-insensitive default ---"
resp=$(printf '{"tool_input":{"command":"Git Commit -m x"}}' | (cd "$TMPDIR_RR" && bash "$REPO_ROOT/scripts/review-reminders.sh" 2>/dev/null))
assert_contains "$resp" '"permissionDecision":"deny"' "review-reminders.sh denies 'Git Commit' (mixed case) -- bash's case/esac was case-sensitive before this fix while review-reminders.ps1's -match already wasn't"

if command -v pwsh >/dev/null 2>&1; then
  echo ""
  echo "--- quote-split fix: a quote-split 'git c\"o\"mmit' is still denied (review-reminders.ps1) ---"
  resp=$(printf '{"tool_input":{"command":"git c\\"o\\"mmit -m \\"x\\""}}' | (cd "$TMPDIR_RR" && pwsh -NonInteractive -File "$REPO_ROOT/scripts/review-reminders.ps1" 2>/dev/null))
  rc=$?
  assert_contains "$resp" '"permissionDecision":"deny"' 'review-reminders.ps1 denies a quote-split git c"o"mmit even though the raw text never contains "git commit" as a contiguous match'
  assert_exit_zero "$rc" "hook exited 0 (not a crash) for: review-reminders.ps1 denies a quote-split git commit"
else
  echo ""
  echo "--- quote-split fix PS1 test: SKIPPED (pwsh not installed on this machine) ---"
fi

# ── git-argument-aware fix: `git -C <path> commit` / `git -c k=v commit` still gate ────────
# WHY this test exists: found during this session's opposition-review pass as a follow-up to
# the quote-split fix -- `git -C /path commit -m x` and `git -c user.name=z commit -m x` are
# ordinary, idiomatic git invocations (an agent naturally reaches for `-C` when working across
# directories, not adversarial obfuscation) whose text never contains "git commit" as a
# contiguous substring, so even the quote-stripped/lowercased match still missed them. Fixed by
# classify_targets()/Get-CommandTargets, a real tokenizer that skips git's own documented
# global options to find the actual subcommand, layered ADDITIVELY on top of the substring
# match (which always runs too, unconditionally -- see the CRITICAL-regression test below for
# why the tokenizer can never be allowed to suppress it).
echo ""
echo "--- git-argument-aware fix: 'git -C <path> commit' is denied (review-reminders.sh) ---"
resp=$(printf '{"tool_input":{"command":"git -C /some/repo commit -m x"}}' | (cd "$TMPDIR_RR" && bash "$REPO_ROOT/scripts/review-reminders.sh" 2>/dev/null))
rc=$?
assert_contains "$resp" '"permissionDecision":"deny"' "review-reminders.sh denies 'git -C /some/repo commit -m x' even though the text never contains 'git commit' as a contiguous substring"
assert_exit_zero "$rc" "hook exited 0 (not a crash) for: review-reminders.sh denies git -C form"

echo ""
echo "--- git-argument-aware fix: 'git -c key=val commit' is denied (review-reminders.sh) ---"
resp=$(printf '{"tool_input":{"command":"git -c user.name=z commit -m x"}}' | (cd "$TMPDIR_RR" && bash "$REPO_ROOT/scripts/review-reminders.sh" 2>/dev/null))
assert_contains "$resp" '"permissionDecision":"deny"' "review-reminders.sh denies 'git -c user.name=z commit -m x'"

echo ""
echo "--- git-argument-aware fix: 'gh -R owner/repo pr merge' is denied (review-reminders.sh) ---"
resp=$(printf '{"tool_input":{"command":"gh -R owner/repo pr merge 8 --squash"}}' | (cd "$TMPDIR_RR" && bash "$REPO_ROOT/scripts/review-reminders.sh" 2>/dev/null))
assert_contains "$resp" '"permissionDecision":"deny"' "review-reminders.sh denies 'gh -R owner/repo pr merge 8' -- the -R global option form"

echo ""
echo "--- git-argument-aware fix negative control: 'git log --grep=commit' is NOT denied (review-reminders.sh) ---"
resp=$(printf '{"tool_input":{"command":"git log --grep=commit"}}' | (cd "$TMPDIR_RR" && bash "$REPO_ROOT/scripts/review-reminders.sh" 2>/dev/null))
rc=$?
assert_not_contains "$resp" '"permissionDecision":"deny"' "review-reminders.sh does not deny a read-only 'git log --grep=commit' -- 'commit' here is an argument value, not the subcommand"
assert_exit_zero "$rc" "hook exited 0 (not a crash) for: review-reminders.sh negative control git log --grep=commit"

echo ""
echo "--- git-argument-aware fix: multi-space/tab 'git   commit' still gates on bash (whitespace-variant gap) ---"
resp=$(printf '{"tool_input":{"command":"git   commit -m x"}}' | (cd "$TMPDIR_RR" && bash "$REPO_ROOT/scripts/review-reminders.sh" 2>/dev/null))
assert_contains "$resp" '"permissionDecision":"deny"' "review-reminders.sh denies 'git   commit' (multiple spaces) -- a real tokenizer splits on any whitespace run, unlike a literal single-space substring match"

# ── CRITICAL regression: tokenizer must be additive, never an exclusive primary ─────────────
# WHY this test exists: an earlier draft of the git-argument-aware fix treated
# classify_targets()/Get-CommandTargets as authoritative whenever it ran without error,
# skipping the substring/regex check entirely. `/usr/bin/git commit`/`env git commit` are
# ordinary indirect invocations whose head token isn't literally "git", so the tokenizer
# correctly-from-a-real-dispatch-standpoint finds nothing there -- but that silently suppressed
# the substring check, which DOES contain "git commit" as a literal substring and would have
# caught it. Reproduced directly against that draft: `/usr/bin/git commit -m x` was silently
# allowed through with no deny at all. This test locks in the fix: substring/regex always runs
# unconditionally as the coverage floor, and the tokenizer's findings are OR'd in on top, never
# replacing it.
echo ""
echo "--- CRITICAL regression: '/usr/bin/git commit' is still denied (review-reminders.sh) ---"
resp=$(printf '{"tool_input":{"command":"/usr/bin/git commit -m x"}}' | (cd "$TMPDIR_RR" && bash "$REPO_ROOT/scripts/review-reminders.sh" 2>/dev/null))
assert_contains "$resp" '"permissionDecision":"deny"' "review-reminders.sh denies '/usr/bin/git commit -m x' via the substring floor even though the tokenizer's head-token check doesn't recognize '/usr/bin/git' as 'git'"

echo ""
echo "--- CRITICAL regression: 'env git commit' is still denied (review-reminders.sh) ---"
resp=$(printf '{"tool_input":{"command":"env git commit -m x"}}' | (cd "$TMPDIR_RR" && bash "$REPO_ROOT/scripts/review-reminders.sh" 2>/dev/null))
assert_contains "$resp" '"permissionDecision":"deny"' "review-reminders.sh denies 'env git commit -m x' via the substring floor"

if command -v pwsh >/dev/null 2>&1; then
  echo ""
  echo "--- CRITICAL regression: '/usr/bin/git commit' is still denied (review-reminders.ps1) ---"
  resp=$(printf '{"tool_input":{"command":"/usr/bin/git commit -m x"}}' | (cd "$TMPDIR_RR" && pwsh -NonInteractive -File "$REPO_ROOT/scripts/review-reminders.ps1" 2>/dev/null))
  assert_contains "$resp" '"permissionDecision":"deny"' "review-reminders.ps1 denies '/usr/bin/git commit -m x' via the regex floor even though Get-CommandTargets's head-token check doesn't recognize '/usr/bin/git' as 'git'"
fi

if command -v pwsh >/dev/null 2>&1; then
  echo ""
  echo "--- git-argument-aware fix: 'git -C <path> commit' is denied (review-reminders.ps1) ---"
  resp=$(printf '{"tool_input":{"command":"git -C /some/repo commit -m x"}}' | (cd "$TMPDIR_RR" && pwsh -NonInteractive -File "$REPO_ROOT/scripts/review-reminders.ps1" 2>/dev/null))
  rc=$?
  assert_contains "$resp" '"permissionDecision":"deny"' "review-reminders.ps1 denies 'git -C /some/repo commit -m x'"
  assert_exit_zero "$rc" "hook exited 0 (not a crash) for: review-reminders.ps1 denies git -C form"

  echo ""
  echo "--- git-argument-aware fix: 'gh -R owner/repo pr merge' is denied (review-reminders.ps1) ---"
  resp=$(printf '{"tool_input":{"command":"gh -R owner/repo pr merge 8 --squash"}}' | (cd "$TMPDIR_RR" && pwsh -NonInteractive -File "$REPO_ROOT/scripts/review-reminders.ps1" 2>/dev/null))
  assert_contains "$resp" '"permissionDecision":"deny"' "review-reminders.ps1 denies 'gh -R owner/repo pr merge 8'"

  echo ""
  echo "--- git-argument-aware fix negative control: 'git log --grep=commit' is NOT denied (review-reminders.ps1) ---"
  resp=$(printf '{"tool_input":{"command":"git log --grep=commit"}}' | (cd "$TMPDIR_RR" && pwsh -NonInteractive -File "$REPO_ROOT/scripts/review-reminders.ps1" 2>/dev/null))
  rc=$?
  assert_not_contains "$resp" '"permissionDecision":"deny"' "review-reminders.ps1 does not deny a read-only 'git log --grep=commit'"
  assert_exit_zero "$rc" "hook exited 0 (not a crash) for: review-reminders.ps1 negative control git log --grep=commit"
else
  echo ""
  echo "--- git-argument-aware fix PS1 tests: SKIPPED (pwsh not installed on this machine) ---"
fi

# ── empty-command fix: a legitimately empty tool_input.command must not fall back to raw stdin ─
# WHY this test exists: extract_command() used to print an empty string both when parsing
# genuinely failed AND when tool_input.command legitimately parsed to "" -- the caller
# couldn't tell those apart, so BOTH cases fell back to raw-stdin matching. That reintroduced
# the exact false-positive this whole fix targets: a well-formed payload with an empty
# command but a description mentioning "git commit" would still match via the fallback, even
# though parsing succeeded and correctly reported "there's no command here." extract_command()
# now signals success/failure via its own exit code (an explicit tool_input.command presence
# check), so a genuinely empty command is distinguishable from a failed parse even though
# both print nothing -- this proves the empty-but-successfully-parsed case does NOT fall back.
if command -v python3 >/dev/null 2>&1; then
  echo ""
  echo "--- empty-command fix: review-reminders.sh does not gate on a legitimately empty tool_input.command, even with a trigger phrase in description ---"
  resp=$(invoke_hook_with_description "review-reminders.sh" "" "remember to git commit these staged changes later")
  rc=$?
  assert_not_contains "$resp" '"permissionDecision":"deny"' "review-reminders.sh does not deny when tool_input.command is legitimately empty, even though description mentions 'git commit'"
  assert_exit_zero "$rc" "hook exited 0 (not a crash) for: review-reminders.sh does not deny when tool_input.command is legitimately empty, even though description mentions 'git commit'"

  echo ""
  echo "--- empty-command fix: review-reminders-post.sh does not falsely reissue a marker for a legitimately empty tool_input.command ---"
  rm -f "$TMPDIR_RR/.claude/.code-review-ok"
  presha=$(git -C "$TMPDIR_RR" rev-parse HEAD)
  printf '%s' "$presha" > "$TMPDIR_RR/.claude/.pending-commit-presha"
  invoke_hook_with_description "review-reminders-post.sh" "" "remember to git commit these staged changes later" >/dev/null
  assert_file_not_exists "$TMPDIR_RR/.claude/.code-review-ok" "review-reminders-post.sh does not reissue .code-review-ok when tool_input.command is legitimately empty, even though description mentions 'git commit'"
  assert_file_exists "$TMPDIR_RR/.claude/.pending-commit-presha" "review-reminders-post.sh leaves the pending-commit-presha file untouched for a legitimately empty command"
  rm -f "$TMPDIR_RR/.claude/.pending-commit-presha"
else
  echo "SKIPPED (python3 not installed on this machine -- extract_command() fails open to raw-stdin matching, already covered by the fallback-fix tests above)"
fi

# ── post-hook root resolution: worktree-root and chained-cd fixes apply to the reissue path too ─
# WHY these tests exist: the worktree-root and chained-cd tests earlier in this file only
# exercise review-reminders.sh (the PreToolUse gate). review-reminders-post.sh has its own
# copy of resolve_cd_root() plus a new `extracted` flag (added so resolve_cd_root() is skipped
# entirely when extract_command() fails, rather than being called with unparsed input) --
# neither was previously exercised with a leading `cd` in the reissue path, only in the gate
# path. A broken plain-string handoff here would silently reissue markers into the wrong
# directory (the ambient cwd) instead of the one the actual git command ran in.
if command -v python3 >/dev/null 2>&1; then
  echo ""
  echo "--- post-hook root resolution: reissues into the cd-derived root, not the ambient (wrong) spawn directory ---"
  TMPDIR_WRONG_POST="$(mktemp -d 2>/dev/null || mktemp -d -t mb-rr-wrongpost)"
  git init -q -b main "$TMPDIR_WRONG_POST"

  rm -f "$TMPDIR_RR/.claude/.code-review-ok" "$TMPDIR_RR/.claude/.pending-commit-presha" "$TMPDIR_RR/.claude/.pending-commit-hash"
  echo "line nine" >> "$TMPDIR_RR/file.txt"
  presha=$(git -C "$TMPDIR_RR" rev-parse HEAD)
  printf '%s' "$presha" > "$TMPDIR_RR/.claude/.pending-commit-presha"
  expected=$(git -C "$TMPDIR_RR" diff HEAD | sha256sum | cut -d' ' -f1)
  printf '%s' "$expected" > "$TMPDIR_RR/.claude/.pending-commit-hash"
  invoke_hook_from "review-reminders-post.sh" "$TMPDIR_WRONG_POST" "cd \\\"$TMPDIR_RR\\\" && git commit -m test10" >/dev/null
  actual=$(cat "$TMPDIR_RR/.claude/.code-review-ok" 2>/dev/null)
  assert_contains "$actual" "$expected" "review-reminders-post.sh reissues .code-review-ok into the cd-derived root ($TMPDIR_RR), not the ambient spawn directory, even with the new plain-string resolve_cd_root() handoff"
  assert_file_not_exists "$TMPDIR_WRONG_POST/.claude/.code-review-ok" "review-reminders-post.sh did not write the marker into the wrong (ambient) directory"

  echo ""
  echo "--- post-hook root resolution: chained cd resolves to the LAST directory, not the first (decoy) ---"
  TMPDIR_DECOY_POST="$(mktemp -d 2>/dev/null || mktemp -d -t mb-rr-decoypost)"
  git -C "$TMPDIR_DECOY_POST" init -q -b main
  mkdir -p "$TMPDIR_DECOY_POST/.claude"
  presha_decoy="0000000000000000000000000000000000000000000000000000000000000000"
  printf '%s' "$presha_decoy" > "$TMPDIR_DECOY_POST/.claude/.pending-commit-presha"

  rm -f "$TMPDIR_RR/.claude/.code-review-ok" "$TMPDIR_RR/.claude/.pending-commit-presha" "$TMPDIR_RR/.claude/.pending-commit-hash"
  echo "line ten" >> "$TMPDIR_RR/file.txt"
  presha=$(git -C "$TMPDIR_RR" rev-parse HEAD)
  printf '%s' "$presha" > "$TMPDIR_RR/.claude/.pending-commit-presha"
  expected=$(git -C "$TMPDIR_RR" diff HEAD | sha256sum | cut -d' ' -f1)
  printf '%s' "$expected" > "$TMPDIR_RR/.claude/.pending-commit-hash"
  invoke_hook_from "review-reminders-post.sh" "$TMPDIR_DECOY_POST" "cd \\\"$TMPDIR_DECOY_POST\\\" && cd \\\"$TMPDIR_RR\\\" && git commit -m test11" >/dev/null
  actual=$(cat "$TMPDIR_RR/.claude/.code-review-ok" 2>/dev/null)
  assert_contains "$actual" "$expected" "review-reminders-post.sh resolves root to the LAST cd (RR) in a chained command, reissuing the marker there, not into the first (decoy) directory"
  assert_file_exists "$TMPDIR_DECOY_POST/.claude/.pending-commit-presha" "review-reminders-post.sh did not touch decoy's unrelated pending-commit-presha file, confirming root resolved to RR (the last cd), not the decoy (the first)"

  rm -rf "$TMPDIR_WRONG_POST" "$TMPDIR_DECOY_POST"
else
  echo "SKIPPED (python3 not installed on this machine -- resolve_cd_root() fails open to ambient cwd, already covered by the rest of this suite)"
fi

print_summary
