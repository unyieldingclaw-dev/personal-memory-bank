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
content=$(cat "$TMPDIR_FLAT/memory-bank/activeContext.md")
assert_contains "$content" "last-reviewed: $OLD_DATE" "update-reviewed.sh: a flat (pre-fix-shape) payload leaves last-reviewed untouched — confirms the update above came from reading the nested field, not some other path"

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

ps1_takes_test_paths() {
    # True where to_win_path() yields a path pwsh can open: Windows with cygpath, or any other
    # OS, where pwsh reads the POSIX path from mktemp as-is. Same guard as test-review-reminders.sh's;
    # requiring cygpath everywhere skipped the update-reviewed.ps1 cases on Linux CI.
    command -v cygpath >/dev/null 2>&1 && return 0
    case "$(uname -s)" in MINGW*|MSYS*|CYGWIN*) return 1 ;; esac
}

# ── backslash (cygpath -w) path reaches perl as a forward-slash path ────────────────────────
# WHY a perl shim rather than checking the file: the hook's comment above FILE_PATH="$NORMALIZED"
# explains how a backslash path loses the file when the cwd is on another drive. On a
# single-drive box the rename succeeds and the file still updates, so only the argument perl
# receives discriminates the fixed hook from the broken one here.
if command -v cygpath >/dev/null 2>&1; then
  echo ""
  echo "--- a backslash Windows path is handed to perl with forward slashes, and the file is updated ---"
  TMPDIR_WIN="$(mktemp -d 2>/dev/null || mktemp -d -t mb-ur-win)"
  CLEANUP_DIRS+=("$TMPDIR_WIN")
  mkdir -p "$TMPDIR_WIN/memory-bank" "$TMPDIR_WIN/shim" "$TMPDIR_WIN/cwd"
  make_reviewed_file "$TMPDIR_WIN" "activeContext.md" "$OLD_DATE"
  REAL_PERL=$(command -v perl)
  PERL_ARG_LOG="$TMPDIR_WIN/perl-last-arg"
  printf '#!/usr/bin/env bash\nprintf "%%s" "${@: -1}" > "%s"\nexec "%s" "$@"\n' \
    "$PERL_ARG_LOG" "$REAL_PERL" > "$TMPDIR_WIN/shim/perl"
  chmod +x "$TMPDIR_WIN/shim/perl"
  WIN_PATH=$(to_win_path "$TMPDIR_WIN/memory-bank/activeContext.md" | sed 's/\\/\\\\/g')
  (
    cd "$TMPDIR_WIN/cwd" || exit 1
    printf '{"tool_name":"Edit","tool_input":{"file_path":"%s"}}' "$WIN_PATH" \
      | PATH="$TMPDIR_WIN/shim:$PATH" bash "$REPO_ROOT/scripts/update-reviewed.sh" 2>/dev/null
  )
  # WHY case and not assert_not_contains: that helper greps, and a lone '\' pattern is a grep
  # error (exit 2), which assert_not_contains would count as "not found" -- a false PASS.
  if [ ! -f "$PERL_ARG_LOG" ]; then
    echo "  FAIL: update-reviewed.sh: the perl shim never ran, so the hook exited before the edit"
    FAIL=$((FAIL + 1))
  else
    perl_arg=$(cat "$PERL_ARG_LOG")
    case "$perl_arg" in
      *\\*)
        echo "  FAIL: update-reviewed.sh: perl received a backslash path, so perl -i puts its temp file in the cwd: $perl_arg"
        FAIL=$((FAIL + 1)) ;;
      *)
        echo "  PASS: update-reviewed.sh: perl received a forward-slash path, so its temp file lands beside the target"
        PASS=$((PASS + 1)) ;;
    esac
  fi
  if [ ! -f "$TMPDIR_WIN/memory-bank/activeContext.md" ]; then
    echo "  FAIL: update-reviewed.sh: file missing after the hook ran on a backslash Windows path"
    FAIL=$((FAIL + 1))
  else
    content=$(cat "$TMPDIR_WIN/memory-bank/activeContext.md")
    assert_contains "$content" "last-reviewed: $TODAY" "update-reviewed.sh: a backslash Windows path still updates last-reviewed to today"
  fi
else
  echo ""
  echo "--- backslash Windows path test: SKIPPED (cygpath not installed on this machine) ---"
fi

# ── stdin is a native Windows pipe, the way Claude Code launches hooks ──────────────────────
# WHY cmd.exe: every `printf | bash` above hands the hook an MSYS pipe. Claude Code is a native
# process, so the hook really gets a native pipe, and under one /dev/stdin -> /proc/self/fd/0 ->
# pipe:[0] cannot be reopened by path: `cat /dev/stdin` fails (ENOENT), `|| true` swallows it,
# and the hook exits 0 without updating. cmd's `|` builds a native pipe with no python/node.
# WHY a .cmd file: cmd's quoting of paths with spaces is fragile through MSYS argument
# conversion; a batch file sidesteps it. Ported from Side-Quest-Atlas d18a02f.
if command -v cygpath >/dev/null 2>&1 && command -v cmd >/dev/null 2>&1; then
  echo ""
  echo "--- a native Windows pipe on stdin still updates last-reviewed ---"
  TMPDIR_PIPE="$(mktemp -d 2>/dev/null || mktemp -d -t mb-ur-pipe)"
  CLEANUP_DIRS+=("$TMPDIR_PIPE")
  mkdir -p "$TMPDIR_PIPE/memory-bank"
  make_reviewed_file "$TMPDIR_PIPE" "activeContext.md" "$OLD_DATE"
  WIN_PATH_PIPE=$(to_win_path "$TMPDIR_PIPE/memory-bank/activeContext.md" | sed 's/\\/\\\\/g')
  printf '{"tool_name":"Edit","tool_input":{"file_path":"%s"}}' "$WIN_PATH_PIPE" > "$TMPDIR_PIPE/payload.json"
  printf '@type "%s" | "%s" "%s"\r\n' "$(to_win_path "$TMPDIR_PIPE/payload.json")" \
    "$(to_win_path "$(command -v bash)")" "$(to_win_path "$REPO_ROOT/scripts/update-reviewed.sh")" \
    > "$TMPDIR_PIPE/run.cmd"
  cmd //c "$(to_win_path "$TMPDIR_PIPE/run.cmd")" >/dev/null 2>&1
  if [ ! -f "$TMPDIR_PIPE/memory-bank/activeContext.md" ]; then
    echo "  FAIL: update-reviewed.sh: file missing after the hook ran from a native Windows pipe"
    FAIL=$((FAIL + 1))
  else
    content=$(cat "$TMPDIR_PIPE/memory-bank/activeContext.md")
    assert_contains "$content" "last-reviewed: $TODAY" "update-reviewed.sh: a native Windows pipe on stdin still updates last-reviewed to today"
  fi
else
  echo ""
  echo "--- native Windows pipe test: SKIPPED (cygpath and/or cmd not installed on this machine) ---"
fi

# ── cases that can write .pmb-hook-errors.log ───────────────────────────────────────────────
# WHY a scratch cwd for each: the hook appends to .pmb-hook-errors.log in its cwd, and run.sh
# runs this file from the repo root, where mb doctor check 16 would then WARN until someone
# deleted the log.
hook_in_dir() {
    # hook_in_dir <cwd> <json-payload> [dir to put first on PATH]
    local dir="$1" payload="$2" extra="${3:-}"
    (
        cd "$dir" || exit 1
        if [ -n "$extra" ]; then PATH="$extra:$PATH"; fi
        printf '%s' "$payload" | bash "$REPO_ROOT/scripts/update-reviewed.sh" 2>/dev/null
    )
}
payload_for() { printf '{"tool_name":"Edit","tool_input":{"file_path":"%s"}}' "$1"; }

echo ""
echo "--- a CRLF file is stamped and keeps its CRLF line ending ---"
TMPDIR_CRLF="$(mktemp -d 2>/dev/null || mktemp -d -t mb-ur-crlf)"
CLEANUP_DIRS+=("$TMPDIR_CRLF")
mkdir -p "$TMPDIR_CRLF/memory-bank" "$TMPDIR_CRLF/cwd"
printf -- '---\r\nlast-reviewed: %s\r\n---\r\nbody\r\n' "$OLD_DATE" > "$TMPDIR_CRLF/memory-bank/progress.md"
hook_in_dir "$TMPDIR_CRLF/cwd" "$(payload_for "$TMPDIR_CRLF/memory-bank/progress.md")"
# WHY one grep for both the date and the \r: checking the \r alone would pass when nothing
# was stamped, because the untouched old line keeps its \r.
# WHY -U: Git for Windows' grep strips CRs in text mode, so without it no pattern containing
# \r can match there (measured); GNU and BSD grep both accept -U.
if grep -U -q "^last-reviewed: $TODAY"$'\r'"\$" "$TMPDIR_CRLF/memory-bank/progress.md"; then
    echo "  PASS: update-reviewed.sh: a CRLF file is stamped and the stamped line keeps its \\r"
    PASS=$((PASS + 1))
else
    echo "  FAIL: update-reviewed.sh: a CRLF file was not stamped, or the stamped line lost its \\r"
    FAIL=$((FAIL + 1))
fi
assert_file_not_exists "$TMPDIR_CRLF/cwd/.pmb-hook-errors.log" "update-reviewed.sh: a successful stamp writes nothing to .pmb-hook-errors.log"

echo ""
echo "--- a path that starts with '-' is stamped, not read as an option ---"
TMPDIR_DASH="$(mktemp -d 2>/dev/null || mktemp -d -t mb-ur-dash)"
CLEANUP_DIRS+=("$TMPDIR_DASH")
mkdir -p "$TMPDIR_DASH/-x/memory-bank"
make_reviewed_file "$TMPDIR_DASH/-x" "activeContext.md" "$OLD_DATE"
hook_in_dir "$TMPDIR_DASH" "$(payload_for "-x/memory-bank/activeContext.md")"
content=$(cat "$TMPDIR_DASH/-x/memory-bank/activeContext.md")
assert_contains "$content" "last-reviewed: $TODAY" "update-reviewed.sh: a relative path starting with '-' is stamped (grep and perl get --)"

echo ""
echo "--- a failed perl edit is logged and leaves the file intact ---"
TMPDIR_PFAIL="$(mktemp -d 2>/dev/null || mktemp -d -t mb-ur-pfail)"
CLEANUP_DIRS+=("$TMPDIR_PFAIL")
mkdir -p "$TMPDIR_PFAIL/memory-bank" "$TMPDIR_PFAIL/shim" "$TMPDIR_PFAIL/cwd"
make_reviewed_file "$TMPDIR_PFAIL" "activeContext.md" "$OLD_DATE"
printf '#!/usr/bin/env bash\necho "simulated perl failure" >&2\nexit 1\n' > "$TMPDIR_PFAIL/shim/perl"
chmod +x "$TMPDIR_PFAIL/shim/perl"
hook_in_dir "$TMPDIR_PFAIL/cwd" "$(payload_for "$TMPDIR_PFAIL/memory-bank/activeContext.md")" "$TMPDIR_PFAIL/shim"
content=$(cat "$TMPDIR_PFAIL/memory-bank/activeContext.md")
assert_contains "$content" "last-reviewed: $OLD_DATE" "update-reviewed.sh: a failed perl edit leaves the file as it was"
log=$(cat "$TMPDIR_PFAIL/cwd/.pmb-hook-errors.log" 2>/dev/null)
assert_contains "$log" "update-reviewed.sh: .*simulated perl failure" "update-reviewed.sh: a failed perl edit is logged with perl's error"

echo ""
echo "--- a file that is gone after the edit is logged ---"
TMPDIR_GONE="$(mktemp -d 2>/dev/null || mktemp -d -t mb-ur-gone)"
CLEANUP_DIRS+=("$TMPDIR_GONE")
mkdir -p "$TMPDIR_GONE/memory-bank" "$TMPDIR_GONE/shim" "$TMPDIR_GONE/cwd"
make_reviewed_file "$TMPDIR_GONE" "activeContext.md" "$OLD_DATE"
# WHY a shim that deletes the target and exits 0: it produces the PR #59 outcome (the original
# gone) without perl reporting an error, so only the hook's after-edit check can catch it.
printf '#!/usr/bin/env bash\nrm -f -- "${@: -1}"\nexit 0\n' > "$TMPDIR_GONE/shim/perl"
chmod +x "$TMPDIR_GONE/shim/perl"
hook_in_dir "$TMPDIR_GONE/cwd" "$(payload_for "$TMPDIR_GONE/memory-bank/activeContext.md")" "$TMPDIR_GONE/shim"
log=$(cat "$TMPDIR_GONE/cwd/.pmb-hook-errors.log" 2>/dev/null)
assert_contains "$log" "update-reviewed.sh: .*missing after the edit" "update-reviewed.sh: a file that is gone after the edit is logged"

echo ""
echo "--- empty stdin is logged ---"
TMPDIR_EMPTY="$(mktemp -d 2>/dev/null || mktemp -d -t mb-ur-empty)"
CLEANUP_DIRS+=("$TMPDIR_EMPTY")
hook_in_dir "$TMPDIR_EMPTY" ""
log=$(cat "$TMPDIR_EMPTY/.pmb-hook-errors.log" 2>/dev/null)
assert_contains "$log" "update-reviewed.sh: .*empty stdin" "update-reviewed.sh: empty stdin is logged, not silently ignored"

# ── POSIX only: a filename containing a literal backslash ───────────────────────────────────
# WHY: pins the trade-off documented in the hook (the slash form of the path is what gets
# stamped), so changing it has to be deliberate. Windows cannot create such a filename.
if ! command -v cygpath >/dev/null 2>&1; then
  echo ""
  echo "--- a POSIX filename with a literal backslash: the slash-form path is the one stamped ---"
  TMPDIR_BS="$(mktemp -d 2>/dev/null || mktemp -d -t mb-ur-bs)"
  CLEANUP_DIRS+=("$TMPDIR_BS")
  mkdir -p "$TMPDIR_BS/memory-bank/a" "$TMPDIR_BS/cwd"
  printf -- '---\nlast-reviewed: %s\n---\n' "$OLD_DATE" > "$TMPDIR_BS/memory-bank/a\\b.md"
  printf -- '---\nlast-reviewed: %s\n---\n' "$OLD_DATE" > "$TMPDIR_BS/memory-bank/a/b.md"
  hook_in_dir "$TMPDIR_BS/cwd" "$(payload_for "$TMPDIR_BS/memory-bank/a\\\\b.md")"
  content=$(cat "$TMPDIR_BS/memory-bank/a/b.md")
  assert_contains "$content" "last-reviewed: $TODAY" "update-reviewed.sh: a literal-backslash filename stamps the file at its slash-form path"
  content=$(cat "$TMPDIR_BS/memory-bank/a\\b.md")
  assert_contains "$content" "last-reviewed: $OLD_DATE" "update-reviewed.sh: the literal-backslash file itself is left as it was"
else
  echo ""
  echo "--- literal-backslash filename test: SKIPPED (Windows cannot create such a filename) ---"
fi

if command -v pwsh >/dev/null 2>&1 && ps1_takes_test_paths; then
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

  echo ""
  echo "--- cross-shell parity: update-reviewed.ps1 stamps a CRLF file and keeps its CRLF ---"
  TMPDIR_PS1CRLF="$(mktemp -d 2>/dev/null || mktemp -d -t mb-ur-ps1crlf)"
  CLEANUP_DIRS+=("$TMPDIR_PS1CRLF")
  mkdir -p "$TMPDIR_PS1CRLF/memory-bank" "$TMPDIR_PS1CRLF/cwd"
  printf -- '---\r\nlast-reviewed: %s\r\n---\r\nbody\r\n' "$OLD_DATE" > "$TMPDIR_PS1CRLF/memory-bank/progress.md"
  WIN_PATH_PS1CRLF=$(to_win_path "$TMPDIR_PS1CRLF/memory-bank/progress.md" | sed 's/\\/\\\\/g')
  (
    cd "$TMPDIR_PS1CRLF/cwd" || exit 1
    printf '{"tool_name":"Edit","tool_input":{"file_path":"%s"}}' "$WIN_PATH_PS1CRLF" \
      | pwsh -NoLogo -NonInteractive -File "$REPO_ROOT/scripts/update-reviewed.ps1" >/dev/null 2>&1
  )
  if grep -U -q "^last-reviewed: $TODAY"$'\r'"\$" "$TMPDIR_PS1CRLF/memory-bank/progress.md"; then
      echo "  PASS: update-reviewed.ps1: a CRLF file is stamped and the stamped line keeps its \\r"
      PASS=$((PASS + 1))
  else
      echo "  FAIL: update-reviewed.ps1: a CRLF file was not stamped, or the stamped line lost its \\r"
      FAIL=$((FAIL + 1))
  fi
else
  echo ""
  echo "--- update-reviewed.ps1 tests: SKIPPED (pwsh not installed, or Windows without cygpath) ---"
fi

# WHY here, outside the cygpath-gated cases: the Windows workflow runs this file against
# scripts/, so a fix that reaches scripts/update-reviewed.sh but not its templates/ copy
# would pass there while shipping the old bug to every installed repo.
echo ""
echo "--- mirror parity: scripts/ vs templates/scripts/ ---"
diff -q "$REPO_ROOT/scripts/update-reviewed.sh" "$REPO_ROOT/templates/scripts/update-reviewed.sh" >/dev/null 2>&1
assert_exit_zero "$?" "scripts/update-reviewed.sh and its templates/ mirror are byte-identical"
# The .ps1 is the primary hook on Windows (settings.json runs it first), so its mirror matters as much.
diff -q "$REPO_ROOT/scripts/update-reviewed.ps1" "$REPO_ROOT/templates/scripts/update-reviewed.ps1" >/dev/null 2>&1
assert_exit_zero "$?" "scripts/update-reviewed.ps1 and its templates/ mirror are byte-identical"

print_summary
