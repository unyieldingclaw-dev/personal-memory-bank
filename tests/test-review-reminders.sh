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

invoke_post_hook_ps1() {
  local command="$1"
  printf '{"tool_input":{"command":"%s"}}' "$command" \
    | (cd "$TMPDIR_RR" && pwsh -NonInteractive -File "$REPO_ROOT/scripts/review-reminders-post.ps1" 2>/dev/null)
}

win_path_for_json() {
  # win_path_for_json <posix-path> — converts a bash-style POSIX path (e.g. from mktemp -d)
  # into a JSON-string-safe native Windows path, for embedding inside a command string sent
  # to review-reminders.ps1. Two steps, both required:
  #   1. cygpath -w: review-reminders.ps1 is a native Windows process with no MSYS
  #      path-translation layer -- Resolve-CdRoot's [System.IO.Path] calls cannot resolve a
  #      POSIX-style "/tmp/tmp.XXXX" path (it silently treats a leading "/" as rooted at the
  #      current drive, producing a nonexistent path). Confirmed directly: an isolated
  #      Resolve-CdRoot call resolves correctly given a real Windows path, and returns empty
  #      given the POSIX form of the identical directory.
  #   2. backslash-doubling: a Windows path's literal backslashes are not valid unescaped
  #      characters inside a JSON string -- e.g. the "\t" in "...\Temp\tmp.XXXX" is a valid
  #      JSON escape sequence (tab) that silently corrupts the path if left unescaped, which
  #      is exactly what step 1 alone produced when first tried here (the hook received a
  #      corrupted path, resolved no root, and silently exited 0 with no output at all --
  #      not a deny, just nothing, which read exactly like a real bypass until traced back to
  #      this missing escape step).
  local posix_path="$1"
  local win_path
  win_path="$(cygpath -w "$posix_path" 2>/dev/null || echo "$posix_path")"
  printf '%s' "${win_path//\\/\\\\}"
}

invoke_hook_from() {
  # invoke_hook_from <script> <spawn-dir> <command-text> — like invoke_hook, but spawns the
  # hook process from <spawn-dir> instead of $TMPDIR_RR, so <command-text> can carry its own
  # leading `cd "$TMPDIR_RR" && ...` to test root-resolution independent of ambient cwd.
  local script="$1" spawn_dir="$2" command="$3"
  printf '{"tool_input":{"command":"%s"}}' "$command" \
    | (cd "$spawn_dir" && bash "$REPO_ROOT/scripts/$script" 2>/dev/null)
}

invoke_hook_ps1_from() {
  # invoke_hook_ps1_from <spawn-dir> <command-text> — PowerShell equivalent of
  # invoke_hook_from, for review-reminders.ps1 specifically. WHY this exists: prior to it,
  # only review-reminders.sh's resolve_cd_root() had spawn-dir-independent coverage for the
  # chained-cd and whitespace-variant fixes -- review-reminders.ps1's own Resolve-CdRoot
  # implements the identical logic but had no test proving it, a real cross-platform coverage
  # gap for a security-relevant root-resolution function (found by code review).
  local spawn_dir="$1" command="$2"
  printf '{"tool_input":{"command":"%s"}}' "$command" \
    | (cd "$spawn_dir" && pwsh -NonInteractive -File "$REPO_ROOT/scripts/review-reminders.ps1" 2>/dev/null)
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
reviewed_c=$(git -C "$TMPDIR_RR" diff HEAD | sha256sum | cut -d' ' -f1)
printf '%s %s' "$presha" "$reviewed_c" > "$TMPDIR_RR/.claude/.pending-commit-presha"
invoke_hook "review-reminders-post.sh" "git commit -m test5" >/dev/null
expected=$(git -C "$TMPDIR_RR" diff HEAD | sha256sum | cut -d' ' -f1)
actual=$(cat "$TMPDIR_RR/.claude/.code-review-ok" 2>/dev/null)
assert_contains "$actual" "$expected" "review-reminders-post.sh reissues .code-review-ok with the correct diff_hash() output when HEAD didn't move (failed commit)"

# ── push recovery: never infer success from the configured upstream ───────────────────────
echo ""
echo "--- push recovery: alternate-remote success stays single-use; no-upstream failure does not mint state ---"
BAREDIR_RR="$(mktemp -d 2>/dev/null || mktemp -d -t mb-rr-bare)"
BAREDIR_ALT_RR="$(mktemp -d 2>/dev/null || mktemp -d -t mb-rr-alt-bare)"
git init -q --bare "$BAREDIR_RR"
git init -q --bare "$BAREDIR_ALT_RR"
git -C "$TMPDIR_RR" remote add origin "$BAREDIR_RR" 2>/dev/null || git -C "$TMPDIR_RR" remote set-url origin "$BAREDIR_RR"
git -C "$TMPDIR_RR" remote add alternate "$BAREDIR_ALT_RR" 2>/dev/null || git -C "$TMPDIR_RR" remote set-url alternate "$BAREDIR_ALT_RR"
git -C "$TMPDIR_RR" add file.txt
git -C "$TMPDIR_RR" commit -q -m "push recovery baseline"
git -C "$TMPDIR_RR" push -q -u origin main 2>/dev/null
echo "alternate remote change" >> "$TMPDIR_RR/file.txt"
git -C "$TMPDIR_RR" add file.txt
git -C "$TMPDIR_RR" commit -q -m "alternate remote change"

rm -f "$TMPDIR_RR/.claude/.change-review-ok" "$TMPDIR_RR/.claude/.pending-push-presha"
reviewed_p=$(git -C "$TMPDIR_RR" diff origin/main...HEAD | sha256sum | cut -d' ' -f1)
printf '%s' "$reviewed_p" > "$TMPDIR_RR/.claude/.change-review-ok"
resp=$(invoke_hook "review-reminders.sh" "git push alternate HEAD:refs/heads/main")
assert_not_contains "$resp" '"permissionDecision":"deny"' "review-reminders.sh accepts an alternate-remote push with its matching marker"
assert_file_not_exists "$TMPDIR_RR/.claude/.pending-push-presha" "review-reminders.sh does not create ambiguous push-recovery state"
git -C "$TMPDIR_RR" push -q alternate HEAD:refs/heads/main
invoke_hook "review-reminders-post.sh" "git push alternate HEAD:refs/heads/main" >/dev/null
assert_file_not_exists "$TMPDIR_RR/.claude/.change-review-ok" "a successful alternate-remote push remains single-use even though the configured upstream did not move"

git -C "$TMPDIR_RR" branch --unset-upstream
printf '%s' "$reviewed_p" > "$TMPDIR_RR/.claude/.change-review-ok"
resp=$(invoke_hook "review-reminders.sh" "git push missing-remote HEAD")
assert_not_contains "$resp" '"permissionDecision":"deny"' "review-reminders.sh accepts the reviewed no-upstream push attempt"
assert_file_not_exists "$TMPDIR_RR/.claude/.pending-push-presha" "a no-upstream push attempt creates no unverifiable recovery state"
invoke_hook "review-reminders-post.sh" "git push missing-remote HEAD" >/dev/null
assert_file_not_exists "$TMPDIR_RR/.claude/.change-review-ok" "a failed no-upstream push requires a fresh review instead of minting a marker"
git -C "$TMPDIR_RR" branch --set-upstream-to=origin/main main >/dev/null 2>&1
echo "line after push policy" >> "$TMPDIR_RR/file.txt"
rm -rf "$BAREDIR_RR" "$BAREDIR_ALT_RR"

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

# A compound command cannot spend one marker on multiple guarded actions. In particular,
# the unconditional merge denial must not be downgraded because a commit appeared first.
echo ""
echo "--- compound guarded actions are denied before any marker is consumed ---"
write_marker_bash_recipe ".code-review-ok"
resp=$(invoke_hook "review-reminders.sh" "git commit -m x && gh pr merge 25")
assert_contains "$resp" '"permissionDecision":"deny"' "review-reminders.sh denies commit-then-merge as a compound guarded command"
assert_file_exists "$TMPDIR_RR/.claude/.code-review-ok" "review-reminders.sh does not consume a commit marker for a denied compound command"
rm -f "$TMPDIR_RR/.claude/.code-review-ok"

if command -v pwsh >/dev/null 2>&1; then
  write_marker_bash_recipe ".code-review-ok"
  resp=$(invoke_hook_ps1 "git commit -m x && gh pr merge 25")
  assert_contains "$resp" '"permissionDecision":"deny"' "review-reminders.ps1 denies commit-then-merge as a compound guarded command"
  assert_file_exists "$TMPDIR_RR/.claude/.code-review-ok" "review-reminders.ps1 does not consume a commit marker for a denied compound command"
  rm -f "$TMPDIR_RR/.claude/.code-review-ok"
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

  # The gate now claims then restores, so a mismatch leaves the marker in place. That is
  # the fix for the marker-destruction defect, and it also removes the signal this test used
  # to rely on: marker-gone no longer proves the hook resolved root correctly, because a
  # matching marker is the only thing that consumes now.
  #
  # Pin the peek behaviour explicitly -- a denial must not destroy an earned marker.
  assert_file_exists "$TMPDIR_RR/.claude/.code-review-ok" "review-reminders.sh does NOT consume the marker when the hash mismatches, so a denial cannot burn an expensively-earned review (peek-before-consume)"

  # Then prove root resolution POSITIVELY, which is strictly stronger than the old
  # consumption check: place a marker at the cd-derived root that DOES match the diff. If
  # root resolution works, the gate allows and writes its presha at that root. If it silently
  # fell back to $TMPDIR_WRONG_RR (which has no .claude/ at all) it would find no marker and
  # deny. Allow-plus-presha-at-the-right-path is therefore unambiguous.
  good_hash=$(git -C "$TMPDIR_RR" diff HEAD | sha256sum | cut -d' ' -f1)
  printf '%s' "$good_hash" > "$TMPDIR_RR/.claude/.code-review-ok"
  rm -f "$TMPDIR_RR/.claude/.pending-commit-presha"
  resp=$(invoke_hook_from "review-reminders.sh" "$TMPDIR_WRONG_RR" "cd \\\"$TMPDIR_RR\\\" && git commit -m test7b")
  assert_not_contains "$resp" '"permissionDecision":"deny"' "review-reminders.sh allows via the cd-derived root when the marker there matches the diff, proving root resolution found the real root"
  assert_file_exists "$TMPDIR_RR/.claude/.pending-commit-presha" "review-reminders.sh wrote its presha at the cd-derived root, confirming root resolution rather than a silent fallback"

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

# ── cross-shell parity: chained-cd fix also holds for review-reminders.ps1 ─────────────────
# WHY this test exists (found by code review): the chained-cd fix and its regression test
# above only ever exercised review-reminders.sh's resolve_cd_root(). review-reminders.ps1's
# Resolve-CdRoot implements the identical last-cd-wins logic but had zero test coverage of
# its own for this security-relevant behavior — a real PowerShell-side parity gap for the
# exact scenario (a decoy repo's valid-but-unrelated marker authorizing a commit in a
# different repo) the bash fix above was written to close. Independent of python3 -- ps1
# parses JSON via ConvertFrom-Json, not the python3 helper the bash hook uses. Paths embedded
# in the command string go through win_path_for_json() (defined above) -- see its own
# comment for why a plain POSIX or unescaped-Windows path breaks this specific hook.
echo ""
echo "--- cross-shell parity: review-reminders.ps1 also resolves root to the LAST cd ---"
# WHY also require cygpath, not just pwsh (found by code review): win_path_for_json()'s
# fallback to the raw POSIX path when cygpath is missing would silently produce a path
# Resolve-CdRoot can't parse, turning an environment gap into a spurious test FAIL instead of
# a clean SKIPPED line -- matching this file's existing skip-not-fail convention elsewhere.
if command -v pwsh >/dev/null 2>&1 && command -v cygpath >/dev/null 2>&1; then
  TMPDIR_DECOY_A_PS1="$(mktemp -d 2>/dev/null || mktemp -d -t mb-rr-decoy-ps1)"
  git -C "$TMPDIR_DECOY_A_PS1" init -q -b main
  git -C "$TMPDIR_DECOY_A_PS1" config user.email "test@example.com"
  git -C "$TMPDIR_DECOY_A_PS1" config user.name "Test"
  echo "decoy one" > "$TMPDIR_DECOY_A_PS1/file.txt"
  git -C "$TMPDIR_DECOY_A_PS1" add file.txt
  git -C "$TMPDIR_DECOY_A_PS1" commit -q -m "initial"
  mkdir -p "$TMPDIR_DECOY_A_PS1/.claude"
  echo "decoy two" >> "$TMPDIR_DECOY_A_PS1/file.txt"
  tmp=$(mktemp)
  git -C "$TMPDIR_DECOY_A_PS1" diff HEAD > "$tmp" 2>/dev/null
  sha256sum "$tmp" | cut -d' ' -f1 > "$TMPDIR_DECOY_A_PS1/.claude/.code-review-ok"
  rm -f "$tmp"

  echo "line nine" >> "$TMPDIR_RR/file.txt"
  rm -f "$TMPDIR_RR/.claude/.code-review-ok"
  DECOY_A_PS1_WIN="$(win_path_for_json "$TMPDIR_DECOY_A_PS1")"
  TMPDIR_RR_WIN="$(win_path_for_json "$TMPDIR_RR")"
  resp=$(invoke_hook_ps1_from "$TMPDIR_DECOY_A_PS1" "cd \\\"$DECOY_A_PS1_WIN\\\" && cd \\\"$TMPDIR_RR_WIN\\\" && git commit -m test8ps1")
  assert_contains "$resp" '"permissionDecision":"deny"' "review-reminders.ps1 resolves root to the LAST cd (RR) in a chained command, not the first (decoy A) — denies because RR has no valid marker of its own"
  assert_file_exists "$TMPDIR_DECOY_A_PS1/.claude/.code-review-ok" "review-reminders.ps1 did not touch decoy A's marker — confirming root resolved to RR (the last cd), not A (the first)"

  rm -rf "$TMPDIR_DECOY_A_PS1"
else
  echo "SKIPPED (pwsh and/or cygpath not installed on this machine)"
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

# ── cross-shell parity: review-reminders.ps1 also accepts the tight-whitespace variant ─────
# WHY this test exists (found by code review): the WHY comment above notes review-reminders.ps1's
# regex was already more permissive than bash's pre-fix pattern -- but nothing actually invoked
# review-reminders.ps1 with this exact input to empirically confirm that, as opposed to inferring
# it from reading the regex. This closes that gap: a live check, not just a re-statement of the
# regex's shape. Independent of python3. Path embedded in the command string goes through
# win_path_for_json() -- see its own comment above for why.
echo ""
echo "--- cross-shell parity: review-reminders.ps1 accepts a cd prefix with no space before && ---"
# WHY also require cygpath: see the identical guard on the chained-cd parity test above.
if command -v pwsh >/dev/null 2>&1 && command -v cygpath >/dev/null 2>&1; then
  TMPDIR_WRONG_WS_PS1="$(mktemp -d 2>/dev/null || mktemp -d -t mb-rr-wrongws-ps1)"
  git init -q -b main "$TMPDIR_WRONG_WS_PS1"

  echo "line ten" >> "$TMPDIR_RR/file.txt"
  write_marker_bash_recipe ".code-review-ok"
  TMPDIR_RR_WIN="$(win_path_for_json "$TMPDIR_RR")"
  resp=$(invoke_hook_ps1_from "$TMPDIR_WRONG_WS_PS1" "cd \\\"$TMPDIR_RR_WIN\\\"&&git commit -m test9ps1")
  assert_not_contains "$resp" '"permissionDecision":"deny"' "review-reminders.ps1 resolves root from a cd prefix with no space before && (tight-whitespace variant), even though the hook process was spawned from an unrelated directory"

  rm -rf "$TMPDIR_WRONG_WS_PS1"
else
  echo "SKIPPED (pwsh and/or cygpath not installed on this machine)"
fi

# ── fail-open: missing _review-gate-lib.sh/.ps1 causes the hook to exit 0, not crash/deny ──
# WHY this test exists: dot-sourcing the shared lib is a new failure path introduced by the
# 2026-07-29 dedup refactor -- a missing/corrupt lib file must make the hook fail open (skip
# the gate) rather than hang, crash, or wrongfully deny. All 4 independent sourcing call
# sites (2 bash hook files, 2 PowerShell hook files) are tested separately -- a mistake in
# one file's sourcing line isn't guaranteed to be caught by testing only one representative
# file per language.
echo ""
echo "--- lib missing: a GUARDED verb is denied, an unguarded command is not ---"
# POLICY CHANGE, deliberate and reversible. This block previously asserted the opposite --
# that a missing _review-gate-lib.sh must NOT deny ("fails open, doesn't wrongfully block").
# That was a considered position, not an oversight: [NS-26] records the fear that a broken
# gate makes commits impossible at all, and --no-verify is CONFIRM-tier and user-run only, so
# a gate that bricks the repo is worse than a gate that is off.
#
# What changed is the evidence. `mb upgrade` run inside a git worktree MANUFACTURES the
# lib-missing state: it copies main's review-reminders.sh (which dot-sources the lib) while
# the TEMPLATE_OWNED list it copies from is the literal in the worktree's own older mb.sh,
# which predates the lib. So fail-open is not a rare broken installation -- it is a state the
# repo's own upgrade path produces, silently, in the trees most likely to be working
# unattended. A gate that is off for that reason grants approval nobody earned.
#
# The work-stoppage concern is answered by SCOPE rather than by allowing: the deny fires only
# once the payload has already been classified as a guarded verb, so every other command in a
# lib-less tree proceeds untouched. The control below is what proves that, and it is why this
# is a discriminating test rather than a blanket "deny everything".
#
# To revert to fail-open, restore the single `|| exit 0` sourcing line in
# scripts/review-reminders.sh and flip the two assertions here.
LIBBAK_SH="$REPO_ROOT/scripts/_review-gate-lib.sh.bak"
trap '[ -f "$LIBBAK_SH" ] && mv "$LIBBAK_SH" "$REPO_ROOT/scripts/_review-gate-lib.sh"; trap - EXIT' EXIT
mv "$REPO_ROOT/scripts/_review-gate-lib.sh" "$LIBBAK_SH"
resp=$(printf '{"tool_input":{"command":"git commit -m test"}}' > "$TMPDIR_RR/libmissing.json"; cd "$TMPDIR_RR" && bash "$REPO_ROOT/scripts/review-reminders.sh" < "$TMPDIR_RR/libmissing.json" 2>/dev/null)
rc=$?
resp_benign=$(printf '{"tool_input":{"command":"ls -la"}}' > "$TMPDIR_RR/libmissing-benign.json"; cd "$TMPDIR_RR" && bash "$REPO_ROOT/scripts/review-reminders.sh" < "$TMPDIR_RR/libmissing-benign.json" 2>/dev/null)
mv "$LIBBAK_SH" "$REPO_ROOT/scripts/_review-gate-lib.sh"
trap - EXIT
assert_exit_zero $rc "review-reminders.sh still exits 0 when _review-gate-lib.sh is missing (a hook must not crash)"
assert_contains "$resp" '"permissionDecision":"deny"' "review-reminders.sh DENIES a guarded verb when _review-gate-lib.sh is missing (fail-closed: a gate that cannot check must not approve)"
assert_not_contains "$resp_benign" '"permissionDecision":"deny"' "review-reminders.sh does NOT deny an unguarded command when the lib is missing (matched control, so the assertion above cannot pass by denying everything)"

echo ""
echo "--- fail-open: review-reminders-post.sh exits 0 when _review-gate-lib.sh is missing ---"
trap '[ -f "$LIBBAK_SH" ] && mv "$LIBBAK_SH" "$REPO_ROOT/scripts/_review-gate-lib.sh"; trap - EXIT' EXIT
mv "$REPO_ROOT/scripts/_review-gate-lib.sh" "$LIBBAK_SH"
printf '{"tool_input":{"command":"git commit -m test"}}' | (cd "$TMPDIR_RR" && bash "$REPO_ROOT/scripts/review-reminders-post.sh" 2>/dev/null)
rc=$?
mv "$LIBBAK_SH" "$REPO_ROOT/scripts/_review-gate-lib.sh"
trap - EXIT
assert_exit_zero $rc "review-reminders-post.sh exits 0 when _review-gate-lib.sh is missing (fails open)"

if command -v pwsh >/dev/null 2>&1; then
  echo ""
  echo "--- fail-open: review-reminders.ps1 exits 0 when _review-gate-lib.ps1 is missing ---"
  LIBBAK_PS1="$REPO_ROOT/scripts/_review-gate-lib.ps1.bak"
  trap '[ -f "$LIBBAK_PS1" ] && mv "$LIBBAK_PS1" "$REPO_ROOT/scripts/_review-gate-lib.ps1"; trap - EXIT' EXIT
  mv "$REPO_ROOT/scripts/_review-gate-lib.ps1" "$LIBBAK_PS1"
  resp=$(printf '{"tool_input":{"command":"git commit -m test"}}' | (cd "$TMPDIR_RR" && pwsh -NonInteractive -File "$REPO_ROOT/scripts/review-reminders.ps1" 2>/dev/null))
  rc=$?
  mv "$LIBBAK_PS1" "$REPO_ROOT/scripts/_review-gate-lib.ps1"
  trap - EXIT
  assert_exit_zero $rc "review-reminders.ps1 exits 0 when _review-gate-lib.ps1 is missing (a hook must not crash)"
  assert_contains "$resp" '"permissionDecision":"deny"' "review-reminders.ps1 denies a guarded verb when _review-gate-lib.ps1 is missing"

  LIBBAK_PS1="$REPO_ROOT/scripts/_review-gate-lib.ps1.bak"
  trap '[ -f "$LIBBAK_PS1" ] && mv "$LIBBAK_PS1" "$REPO_ROOT/scripts/_review-gate-lib.ps1"; trap - EXIT' EXIT
  mv "$REPO_ROOT/scripts/_review-gate-lib.ps1" "$LIBBAK_PS1"
  resp_benign=$(printf '{"tool_input":{"command":"git status --short"}}' | (cd "$TMPDIR_RR" && pwsh -NonInteractive -File "$REPO_ROOT/scripts/review-reminders.ps1" 2>/dev/null))
  mv "$LIBBAK_PS1" "$REPO_ROOT/scripts/_review-gate-lib.ps1"
  trap - EXIT
  assert_not_contains "$resp_benign" '"permissionDecision":"deny"' "review-reminders.ps1 does not deny an unguarded command when the lib is missing"

  echo ""
  echo "--- fail-open: review-reminders-post.ps1 exits 0 when _review-gate-lib.ps1 is missing ---"
  trap '[ -f "$LIBBAK_PS1" ] && mv "$LIBBAK_PS1" "$REPO_ROOT/scripts/_review-gate-lib.ps1"; trap - EXIT' EXIT
  mv "$REPO_ROOT/scripts/_review-gate-lib.ps1" "$LIBBAK_PS1"
  printf '{"tool_input":{"command":"git commit -m test"}}' | (cd "$TMPDIR_RR" && pwsh -NonInteractive -File "$REPO_ROOT/scripts/review-reminders-post.ps1" 2>/dev/null)
  rc=$?
  mv "$LIBBAK_PS1" "$REPO_ROOT/scripts/_review-gate-lib.ps1"
  trap - EXIT
  assert_exit_zero $rc "review-reminders-post.ps1 exits 0 when _review-gate-lib.ps1 is missing (fails open)"
else
  echo ""
  echo "--- fail-open PowerShell tests: SKIPPED (pwsh not installed on this machine) ---"
fi

# ── post-hook: the reissue is BOUND to the reviewed hash (the critical-bypass regression) ───
# WHY this exists, and why the negative case is the one that matters:
#
# review-reminders.sh consumes the marker and writes .pending-commit-presha BEFORE the guarded
# tool runs. If that call is then denied by any other hook, PostToolUse never fires and the
# presha survives. The old post-hook recomputed diff_hash HEAD at post time and wrote it as a
# fresh marker, so a later command whose text matched the verb minted a marker for a tree
# nobody had reviewed. Reproduced on both shells; an `echo` was sufficient.
#
# The fix records "<presha> <reviewed-hash>" and reissues only a marker equal to the recorded
# reviewed hash. A mutation removing that comparison leaves the rest of this file fully green,
# which is why the negative case below is not optional.
echo ""
echo "--- post-hook: refuses to reissue a marker for a tree that changed after the review ---"
rm -f "$TMPDIR_RR/.claude/.code-review-ok" "$TMPDIR_RR/.claude/.pending-commit-presha"
presha_b=$(git -C "$TMPDIR_RR" rev-parse HEAD)
# A reviewed-hash that is deliberately NOT the current tree's hash: this stands in for "the
# tree changed after the review was earned".
printf '%s %s' "$presha_b" "2222222222222222222222222222222222222222222222222222222222222222" > "$TMPDIR_RR/.claude/.pending-commit-presha"
invoke_hook "review-reminders-post.sh" "git commit -m test-bind" >/dev/null
assert_file_not_exists "$TMPDIR_RR/.claude/.code-review-ok" "review-reminders-post.sh does NOT reissue a marker when the recorded reviewed hash no longer matches the tree (closes the presha-residue bypass)"

# Matched positive control: with the CORRECT reviewed hash recorded, the reissue still works.
# Without this, a post-hook that simply never reissued would pass the assertion above.
rm -f "$TMPDIR_RR/.claude/.code-review-ok" "$TMPDIR_RR/.claude/.pending-commit-presha"
reviewed_b=$(git -C "$TMPDIR_RR" diff HEAD | sha256sum | cut -d' ' -f1)
printf '%s %s' "$presha_b" "$reviewed_b" > "$TMPDIR_RR/.claude/.pending-commit-presha"
invoke_hook "review-reminders-post.sh" "git commit -m test-bind2" >/dev/null
actual_b=$(cat "$TMPDIR_RR/.claude/.code-review-ok" 2>/dev/null)
assert_contains "$actual_b" "$reviewed_b" "review-reminders-post.sh still reissues the marker when the reviewed hash matches (matched control, so the test above cannot pass by never reissuing)"
rm -f "$TMPDIR_RR/.claude/.code-review-ok" "$TMPDIR_RR/.claude/.pending-commit-presha"

if command -v pwsh >/dev/null 2>&1; then
  echo ""
  echo "--- PowerShell post-hook: reissue stays bound to the reviewed hash ---"
  printf '%s %s' "$presha_b" "3333333333333333333333333333333333333333333333333333333333333333" > "$TMPDIR_RR/.claude/.pending-commit-presha"
  invoke_post_hook_ps1 "git commit -m test-bind-ps1" >/dev/null
  assert_file_not_exists "$TMPDIR_RR/.claude/.code-review-ok" "review-reminders-post.ps1 does not reissue a marker for a tree changed after review"

  reviewed_ps=$(git -C "$TMPDIR_RR" diff HEAD | sha256sum | cut -d' ' -f1)
  printf '%s %s' "$presha_b" "$reviewed_ps" > "$TMPDIR_RR/.claude/.pending-commit-presha"
  invoke_post_hook_ps1 "git commit -m test-bind-ps1-control" >/dev/null
  actual_ps=$(cat "$TMPDIR_RR/.claude/.code-review-ok" 2>/dev/null)
  assert_contains "$actual_ps" "$reviewed_ps" "review-reminders-post.ps1 reissues only the matching reviewed hash"
  rm -f "$TMPDIR_RR/.claude/.code-review-ok" "$TMPDIR_RR/.claude/.pending-commit-presha"
fi

# ── push gate: denies on a hash mismatch (previously ZERO coverage) ─────────────────────────
# WHY this exists: a mutation replacing the push gate's equality test with a tautology left
# the suite at full green, because the only push-gate assertion was an accept case. The
# property the .change-review-ok marker exists to provide -- that the pushed diff is the
# reviewed diff -- therefore had no regression protection at all.
echo ""
echo "--- push gate: a non-matching .change-review-ok is rejected, and survives the denial ---"
rm -f "$TMPDIR_RR/.claude/.change-review-ok" "$TMPDIR_RR/.claude/.pending-push-presha"
printf '%s' "1111111111111111111111111111111111111111111111111111111111111111" > "$TMPDIR_RR/.claude/.change-review-ok"
resp=$(invoke_hook "review-reminders.sh" "git push origin HEAD")
assert_contains "$resp" '"permissionDecision":"deny"' "review-reminders.sh denies a push whose .change-review-ok does not match the diff"
assert_file_exists "$TMPDIR_RR/.claude/.change-review-ok" "review-reminders.sh does NOT consume a non-matching .change-review-ok (peek-before-consume on the push gate too)"
rm -f "$TMPDIR_RR/.claude/.change-review-ok"

# ── argument forms: git's global options must not smuggle the verb past the gate ────────────
# WHY: `git -C <dir> commit`, `git -c k=v commit` and `git -C <dir> push` each perform the
# guarded action while containing neither two-word substring the old matcher looked for. All
# three were measured passing the gate against matched controls that were correctly denied.
echo ""
echo "--- argument forms: -C / -c / REST merge are gated, read-only git is not ---"
rm -f "$TMPDIR_RR/.claude/.code-review-ok"
for form in "git -C . commit -m x" "git -c user.name=x commit -m x" "git -C . push origin HEAD"; do
  resp=$(invoke_hook "review-reminders.sh" "$form")
  assert_contains "$resp" '"permissionDecision":"deny"' "review-reminders.sh gates the form: $form"
done
resp=$(invoke_hook "review-reminders.sh" "git log --oneline -5")
assert_not_contains "$resp" '"permissionDecision":"deny"' "review-reminders.sh does not gate read-only git (matched control for the forms above)"

if command -v pwsh >/dev/null 2>&1; then
  echo ""
  echo "--- PowerShell argument forms: -C / -c / REST merge are gated, read-only git is not ---"
  rm -f "$TMPDIR_RR/.claude/.code-review-ok" "$TMPDIR_RR/.claude/.change-review-ok"
  for form in "git -C . commit -m x" "git -c user.name=x commit -m x" "git -C . push origin HEAD" "gh api -X PUT repos/o/r/pulls/25/merge"; do
    resp=$(invoke_hook_ps1 "$form")
    assert_contains "$resp" '"permissionDecision":"deny"' "review-reminders.ps1 gates the form: $form"
  done
  resp=$(invoke_hook_ps1 "git log --oneline -5")
  assert_not_contains "$resp" '"permissionDecision":"deny"' "review-reminders.ps1 does not gate read-only git"
fi

# ── explicit git -C root: authorization must bind to the TARGET repository ────────────────
echo ""
echo "--- git -C root binding: an ambient marker cannot authorize a different repository ---"
TMPDIR_CROOT="$(mktemp -d 2>/dev/null || mktemp -d -t mb-rr-croot)"
git -C "$TMPDIR_CROOT" init -q -b main
git -C "$TMPDIR_CROOT" config user.email "test@example.com"
git -C "$TMPDIR_CROOT" config user.name "Test"
echo "base" > "$TMPDIR_CROOT/file.txt"
git -C "$TMPDIR_CROOT" add file.txt
git -C "$TMPDIR_CROOT" commit -q -m initial
mkdir -p "$TMPDIR_CROOT/.claude"
echo "target change" >> "$TMPDIR_CROOT/file.txt"

ambient_hash=$(git -C "$TMPDIR_RR" diff HEAD | sha256sum | cut -d' ' -f1)
target_hash=$(git -C "$TMPDIR_CROOT" diff HEAD | sha256sum | cut -d' ' -f1)
printf '%s' "$ambient_hash" > "$TMPDIR_RR/.claude/.code-review-ok"
rm -f "$TMPDIR_RR/.claude/.pending-commit-presha" "$TMPDIR_CROOT/.claude/.pending-commit-presha"
resp=$(invoke_hook "review-reminders.sh" "git -C $TMPDIR_CROOT commit -m target")
assert_contains "$resp" '"permissionDecision":"deny"' "review-reminders.sh refuses git -C when only the ambient repository has a valid marker"
assert_file_exists "$TMPDIR_RR/.claude/.code-review-ok" "review-reminders.sh leaves the unrelated ambient marker untouched"

printf '%s' "$target_hash" > "$TMPDIR_CROOT/.claude/.code-review-ok"
resp=$(invoke_hook "review-reminders.sh" "git -C $TMPDIR_CROOT commit -m target")
assert_not_contains "$resp" '"permissionDecision":"deny"' "review-reminders.sh accepts git -C only from the target repository's matching marker"
assert_file_not_exists "$TMPDIR_CROOT/.claude/.code-review-ok" "review-reminders.sh consumes the target repository's marker"
assert_file_exists "$TMPDIR_CROOT/.claude/.pending-commit-presha" "review-reminders.sh writes recovery state in the target repository"
rm -f "$TMPDIR_RR/.claude/.code-review-ok" "$TMPDIR_RR/.claude/.pending-commit-presha" "$TMPDIR_CROOT/.claude/.pending-commit-presha"

if command -v pwsh >/dev/null 2>&1; then
  target_win=$(win_path_for_json "$TMPDIR_CROOT")
  printf '%s' "$ambient_hash" > "$TMPDIR_RR/.claude/.code-review-ok"
  resp=$(invoke_hook_ps1 "git -C \\\"$target_win\\\" commit -m target")
  assert_contains "$resp" '"permissionDecision":"deny"' "review-reminders.ps1 refuses git -C when only the ambient repository has a valid marker"
  assert_file_exists "$TMPDIR_RR/.claude/.code-review-ok" "review-reminders.ps1 leaves the unrelated ambient marker untouched"

  printf '%s' "$target_hash" > "$TMPDIR_CROOT/.claude/.code-review-ok"
  resp=$(invoke_hook_ps1 "git -C \\\"$target_win\\\" commit -m target")
  assert_not_contains "$resp" '"permissionDecision":"deny"' "review-reminders.ps1 accepts git -C only from the target repository's matching marker"
  assert_file_not_exists "$TMPDIR_CROOT/.claude/.code-review-ok" "review-reminders.ps1 consumes the target repository's marker"
  assert_file_exists "$TMPDIR_CROOT/.claude/.pending-commit-presha" "review-reminders.ps1 writes recovery state in the target repository"
  rm -f "$TMPDIR_RR/.claude/.code-review-ok" "$TMPDIR_CROOT/.claude/.pending-commit-presha"
fi

# ── post-hook classification: no prose false positive; -C attempts are reconciled ─────────
echo ""
echo "--- post-hook classification follows the pre-hook classifier ---"
presha_c=$(git -C "$TMPDIR_RR" rev-parse HEAD)
reviewed_c=$(git -C "$TMPDIR_RR" diff HEAD | sha256sum | cut -d' ' -f1)
printf '%s %s' "$presha_c" "$reviewed_c" > "$TMPDIR_RR/.claude/.pending-commit-presha"
invoke_hook "review-reminders-post.sh" "echo documenting the git commit gate" >/dev/null
assert_file_not_exists "$TMPDIR_RR/.claude/.code-review-ok" "review-reminders-post.sh ignores prose that merely mentions the guarded verb"
assert_file_exists "$TMPDIR_RR/.claude/.pending-commit-presha" "review-reminders-post.sh preserves pending state for a benign prose command"
invoke_hook "review-reminders-post.sh" "git -C . commit -m failed" >/dev/null
assert_file_exists "$TMPDIR_RR/.claude/.code-review-ok" "review-reminders-post.sh reconciles a classified git -C commit attempt"
assert_file_not_exists "$TMPDIR_RR/.claude/.pending-commit-presha" "review-reminders-post.sh consumes pending state for the classified attempt"
rm -f "$TMPDIR_RR/.claude/.code-review-ok"

if command -v pwsh >/dev/null 2>&1; then
  printf '%s %s' "$presha_c" "$reviewed_c" > "$TMPDIR_RR/.claude/.pending-commit-presha"
  invoke_post_hook_ps1 "echo documenting the git commit gate" >/dev/null
  assert_file_not_exists "$TMPDIR_RR/.claude/.code-review-ok" "review-reminders-post.ps1 ignores prose that merely mentions the guarded verb"
  assert_file_exists "$TMPDIR_RR/.claude/.pending-commit-presha" "review-reminders-post.ps1 preserves pending state for a benign prose command"
  invoke_post_hook_ps1 "git -C . commit -m failed" >/dev/null
  assert_file_exists "$TMPDIR_RR/.claude/.code-review-ok" "review-reminders-post.ps1 reconciles a classified git -C commit attempt"
  assert_file_not_exists "$TMPDIR_RR/.claude/.pending-commit-presha" "review-reminders-post.ps1 consumes pending state for the classified attempt"
  rm -f "$TMPDIR_RR/.claude/.code-review-ok"
fi

rm -rf "$TMPDIR_CROOT"

print_summary
