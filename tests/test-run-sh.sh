#!/usr/bin/env bash
# tests/test-run-sh.sh — tests for tests/run.sh's suite enumeration and its guards.
#
# WHY a temp COPY of run.sh with stub suites, not the real one: run.sh runs every tests/test-*.sh,
# this file included, so calling the real run.sh from here would recurse. The real suite also takes
# over ten minutes and moves the live VERSION file aside. A copy derives REPO_ROOT from its own
# location, so it enumerates only the stubs next to it; no seam or env override is needed.
source "$(dirname "${BASH_SOURCE[0]}")/helpers/assert.sh"

RUN_SH="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/run.sh"
T="$(mktemp -d)"
trap 'rm -rf "$T"' EXIT
# WHY: an inherited GIT_DIR (e.g. from a hook) would point every fixture's git at another repo.
unset GIT_DIR GIT_INDEX_FILE GIT_WORK_TREE

# skip_links WHAT — the loud SKIP for a case that needs a link this machine cannot make (Git Bash on
# Windows without Developer Mode). PMB_REQUIRE_SYMLINKS=1, set in CI, turns it into a failure, as in
# tests/test-pmb-journal.sh.
skip_links() {
  echo "  SKIP: symbolic links cannot be created here; $1"
  if [ "${PMB_REQUIRE_SYMLINKS:-0}" = "1" ]; then
    assert_contains "symlinks-missing" "symlinks-present" "PMB_REQUIRE_SYMLINKS=1 but links cannot be made: $1"
  fi
}

# make_copy <dir> <suite-name>... -> <dir>/tests/run.sh plus one stub per name. A stub named fail-*
# exits 1; every stub prints RAN-<name>, so an assertion can tell which suites actually ran.
make_copy() {
  local dir="$1"; shift
  mkdir -p "$dir/tests"
  cp "$RUN_SH" "$dir/tests/run.sh"
  local n
  for n in "$@"; do
    case "$n" in
      fail-*) printf 'echo RAN-%s\nexit 1\n' "$n" > "$dir/tests/test-$n.sh" ;;
      *)      printf 'echo RAN-%s\nexit 0\n' "$n" > "$dir/tests/test-$n.sh" ;;
    esac
  done
}

git_init() { mkdir -p "$1" && git -C "$1" init -q && git -C "$1" config core.autocrlf false; }

echo "=== tests/run.sh: enumeration and guards ==="

# ── 1. git checkout: tracked suites run, sorted; an untracked suite does not ────────────────────
# Also the path-form guard: on Git Bash git prints C:/... and pwd prints /c/..., so a raw string
# compare would read this checkout as foreign and take the SKIP fallback, running test-wip.sh.
make_copy "$T/repo" b a wip
git_init "$T/repo"
git -C "$T/repo" add tests/run.sh tests/test-a.sh tests/test-b.sh
out="$(bash "$T/repo/tests/run.sh" 2>&1)"; rc=$?
assert_exit_zero "$rc" "checkout: all tracked stubs pass, so run.sh exits 0"
assert_contains "$out" "RAN-a" "checkout: tracked suite a ran"
assert_contains "$out" "RAN-b" "checkout: tracked suite b ran"
assert_not_contains "$out" "RAN-wip" "checkout: untracked suite did not run"
assert_not_contains "$out" "SKIP:" "checkout: no fallback (toplevel matched REPO_ROOT in its own path form)"
assert_contains "$out" "Suite: a$" "checkout: display name comes from the file name"
order="$(printf '%s\n' "$out" | grep -o '^RAN-[a-z]*' | tr '\n' ' ')"
assert_equals "$order" "RAN-a RAN-b " "checkout: suites run in sorted order"
assert_contains "$out" "All test suites passed" "checkout: success line printed"
assert_contains "$out" "NOTE: untracked suites are not run" "checkout: the untracked suite is announced"
assert_contains "$out" "  tests/test-wip.sh" "checkout: the NOTE names the untracked suite"

# ── 2. a failing suite fails the run ───────────────────────────────────────────────────────────
make_copy "$T/failing" a fail-x
git_init "$T/failing"
git -C "$T/failing" add tests
out="$(bash "$T/failing/tests/run.sh" 2>&1)"; rc=$?
assert_exit_nonzero "$rc" "failing suite: run.sh exits non-zero"
assert_contains "$out" "RAN-a" "failing suite: the other suite still ran"
assert_not_contains "$out" "All test suites passed" "failing suite: no success line"

# ── 3. no git (a `git ls-files | tar` copy): loud SKIP, glob fallback ───────────────────────────
# GIT_CEILING_DIRECTORIES stops git's upward search at $T, so this holds even when the temp dir
# sits inside some other repository.
make_copy "$T/nogit/copy" a b
GIT_CEILING_DIRECTORIES="$T/nogit" git -C "$T/nogit/copy" rev-parse --show-toplevel >/dev/null 2>&1; rc=$?
assert_exit_nonzero "$rc" "no git: precondition, git finds no repository above the copy"
out="$(GIT_CEILING_DIRECTORIES="$T/nogit" bash "$T/nogit/copy/tests/run.sh" 2>&1)"; rc=$?
assert_exit_zero "$rc" "no git: stubs pass, so run.sh exits 0"
assert_contains "$out" "SKIP: git ls-files enumeration" "no git: fallback is announced"
assert_contains "$out" "RAN-a" "no git: suite a ran through the glob"
assert_contains "$out" "RAN-b" "no git: suite b ran through the glob"

# ── 4. a copy extracted inside ANOTHER repository: toplevel guard ──────────────────────────────
# The outer index does not track the copy, so trusting ls-files there would enumerate nothing.
git_init "$T/outer"
make_copy "$T/outer/sub" a b
outer_top="$(git -C "$T/outer/sub" rev-parse --show-toplevel 2>/dev/null)"
assert_equals "$(cd "$outer_top" 2>/dev/null && pwd -P)" "$(cd "$T/outer" && pwd -P)"   "inside another repo: precondition, git resolves the copy to the OUTER repository"
out="$(bash "$T/outer/sub/tests/run.sh" 2>&1)"; rc=$?
assert_exit_zero "$rc" "inside another repo: stubs pass, so run.sh exits 0"
assert_contains "$out" "SKIP: git ls-files enumeration" "inside another repo: ls-files not trusted"
assert_contains "$out" "RAN-a" "inside another repo: suite a ran"
assert_contains "$out" "RAN-b" "inside another repo: suite b ran"

# ── 5. empty enumeration fails, never "All test suites passed" ─────────────────────────────────
make_copy "$T/empty-git" wip
git_init "$T/empty-git"
git -C "$T/empty-git" add tests/run.sh
out="$(bash "$T/empty-git/tests/run.sh" 2>&1)"; rc=$?
assert_exit_nonzero "$rc" "empty (git, only an untracked suite): run.sh exits non-zero"
assert_contains "$out" "FAIL: no tests/test-\*.sh suite found" "empty (git): failure is named"
assert_not_contains "$out" "All test suites passed" "empty (git): no success line"

make_copy "$T/empty-nogit/copy"
out="$(GIT_CEILING_DIRECTORIES="$T/empty-nogit" bash "$T/empty-nogit/copy/tests/run.sh" 2>&1)"; rc=$?
assert_exit_nonzero "$rc" "empty (no git): run.sh exits non-zero"
assert_contains "$out" "FAIL: no tests/test-\*.sh suite found" "empty (no git): failure is named"
assert_not_contains "$out" "All test suites passed" "empty (no git): no success line"

# ── 6. run.sh reached through another spelling of the checkout's path ──────────────────────────
# A string compare reads each as a foreign toplevel, takes the fallback and runs test-wip.sh.
# 6a, a symbolic link: git resolves it, plain pwd does not.
if ln -s "$T/repo" "$T/repo-link" 2>/dev/null && [ -L "$T/repo-link" ]; then
  out="$(bash "$T/repo-link/tests/run.sh" 2>&1)"; rc=$?
  assert_exit_zero "$rc" "via symlink: run.sh exits 0"
  assert_not_contains "$out" "SKIP:" "via symlink: no fallback (the link resolves to the toplevel)"
  assert_not_contains "$out" "RAN-wip" "via symlink: untracked suite did not run"
  assert_contains "$out" "RAN-a" "via symlink: tracked suite ran"
else
  skip_links "the symlinked-path case (6a) is not run"
fi
# 6b, a differently-cased path: on a case-insensitive filesystem (Windows) pwd keeps the typed case,
# and git prints the stored one. Elsewhere the upper-cased path does not exist, so 6b is skipped.
repo_top="$(git -C "$T/repo" rev-parse --show-toplevel)"
repo_up="$(printf '%s' "$repo_top" | tr '[:lower:]' '[:upper:]')"
if [ "$repo_up" != "$repo_top" ] && [ -f "$repo_up/tests/run.sh" ] && [ "$repo_up" -ef "$repo_top" ]; then
  out="$(bash "$repo_up/tests/run.sh" 2>&1)"; rc=$?
  assert_exit_zero "$rc" "via upper-cased path: run.sh exits 0"
  assert_not_contains "$out" "SKIP:" "via upper-cased path: no fallback"
  assert_not_contains "$out" "RAN-wip" "via upper-cased path: untracked suite did not run"
else
  echo "  SKIP: the filesystem is case-sensitive here; the differently-cased path case (6b) is not run"
fi

# ── 7. order is byte order on both paths, whatever the locale ──────────────────────────────────
# Under en_US.UTF-8 a glob lists test-a.sh before test-B.sh; byte order puts B (0x42) first. So a
# fallback without `LC_ALL=C sort` runs them a, B. Skipped where that locale does not reorder them.
make_copy "$T/coll-git" a B
git_init "$T/coll-git"
git -C "$T/coll-git" add tests
make_copy "$T/coll-nogit/copy" a B
glob_order="$(cd "$T/coll-nogit/copy/tests" && LC_ALL=en_US.UTF-8 bash -c 'echo test-*.sh' 2>/dev/null)"
if [ "$glob_order" = "test-a.sh test-B.sh" ]; then
  out="$(LC_ALL=en_US.UTF-8 bash "$T/coll-git/tests/run.sh" 2>&1)"
  order="$(printf '%s\n' "$out" | grep -o '^RAN-[A-Za-z]*' | tr '\n' ' ')"
  assert_equals "$order" "RAN-B RAN-a " "collation (git): byte order, not the locale's"
  out="$(LC_ALL=en_US.UTF-8 GIT_CEILING_DIRECTORIES="$T/coll-nogit" bash "$T/coll-nogit/copy/tests/run.sh" 2>&1)"
  assert_contains "$out" "SKIP: git ls-files enumeration" "collation (no git): precondition, the fallback ran"
  order="$(printf '%s\n' "$out" | grep -o '^RAN-[A-Za-z]*' | tr '\n' ' ')"
  assert_equals "$order" "RAN-B RAN-a " "collation (no git): byte order, not the locale's"
else
  echo "  SKIP: en_US.UTF-8 does not reorder a glob here (got: ${glob_order:-nothing}); the collation case (7) is not run"
fi

# ── 8. git absent from PATH: the same loud fallback as no repository ───────────────────────────
# PATH keeps only directories without git; a tool run.sh needs that lived beside git is linked in.
mkdir -p "$T/nogit-bin"
nogit_path="$T/nogit-bin"
old_ifs="$IFS"; IFS=:
for d in $PATH; do
  [ -x "$d/git" ] || [ -x "$d/git.exe" ] || nogit_path="$nogit_path:$d"
done
IFS="$old_ifs"
for tool in bash dirname basename sort sed; do
  PATH="$nogit_path" command -v "$tool" >/dev/null 2>&1 || ln -s "$(command -v "$tool")" "$T/nogit-bin/$tool"
done
PATH="$nogit_path" command -v git >/dev/null 2>&1; rc=$?
assert_exit_nonzero "$rc" "git absent: precondition, git is not on the reduced PATH"
out="$(PATH="$nogit_path" bash "$T/repo/tests/run.sh" 2>&1)"; rc=$?
assert_exit_zero "$rc" "git absent: stubs pass, so run.sh exits 0"
assert_contains "$out" "SKIP: git ls-files enumeration (no git checkout at" "git absent: fallback is announced"
assert_contains "$out" "RAN-a" "git absent: suite a ran through the glob"

# ── 9. a tracked suite deleted from disk fails the run, by name ────────────────────────────────
make_copy "$T/gone" a gone
git_init "$T/gone"
git -C "$T/gone" add tests
rm "$T/gone/tests/test-gone.sh"
out="$(bash "$T/gone/tests/run.sh" 2>&1)"; rc=$?
assert_exit_nonzero "$rc" "deleted suite: run.sh exits non-zero"
assert_contains "$out" "Suite: gone" "deleted suite: it is still enumerated, so its failure is named"
assert_contains "$out" "RAN-a" "deleted suite: the other suite still ran"
assert_not_contains "$out" "All test suites passed" "deleted suite: no success line"

# ── 10. awkward tracked names: a space, a non-ASCII byte, a path one directory down ────────────
# ls-files C-quotes a non-ASCII name unless -z; a space splits an unquoted list; a plain
# pathspec's * matches tests/test-dir/nested.sh, which is not a suite.
make_copy "$T/names" a
printf 'echo RAN-space\nexit 0\n' > "$T/names/tests/test-sp ace.sh"
printf 'echo RAN-accent\nexit 0\n' > "$T/names/tests/test-caf$(printf '\303\251').sh"
mkdir -p "$T/names/tests/test-dir"
printf 'echo RAN-nested\nexit 0\n' > "$T/names/tests/test-dir/nested.sh"
git_init "$T/names"
git -C "$T/names" add tests
out="$(bash "$T/names/tests/run.sh" 2>&1)"; rc=$?
assert_exit_zero "$rc" "awkward names: run.sh exits 0"
assert_contains "$out" "RAN-space" "awkward names: a name with a space ran"
assert_contains "$out" "RAN-accent" "awkward names: a non-ASCII name ran"
assert_not_contains "$out" "RAN-nested" "awkward names: a file one directory down is not a suite"

print_summary
