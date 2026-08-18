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
echo "--- fail-open: review-reminders.sh exits 0 when _review-gate-lib.sh is missing ---"
LIBBAK_SH="$REPO_ROOT/scripts/_review-gate-lib.sh.bak"
trap '[ -f "$LIBBAK_SH" ] && mv "$LIBBAK_SH" "$REPO_ROOT/scripts/_review-gate-lib.sh"; trap - EXIT' EXIT
mv "$REPO_ROOT/scripts/_review-gate-lib.sh" "$LIBBAK_SH"
resp=$(printf '{"tool_input":{"command":"git commit -m test"}}' | (cd "$TMPDIR_RR" && bash "$REPO_ROOT/scripts/review-reminders.sh" 2>/dev/null))
rc=$?
mv "$LIBBAK_SH" "$REPO_ROOT/scripts/_review-gate-lib.sh"
trap - EXIT
assert_exit_zero $rc "review-reminders.sh exits 0 when _review-gate-lib.sh is missing (fails open, doesn't crash)"
assert_not_contains "$resp" '"permissionDecision":"deny"' "review-reminders.sh does not deny when _review-gate-lib.sh is missing (fails open, doesn't wrongfully block)"

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
  assert_exit_zero $rc "review-reminders.ps1 exits 0 when _review-gate-lib.ps1 is missing (fails open)"
  assert_not_contains "$resp" '"permissionDecision":"deny"' "review-reminders.ps1 does not deny when _review-gate-lib.ps1 is missing (fails open)"

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

print_summary
