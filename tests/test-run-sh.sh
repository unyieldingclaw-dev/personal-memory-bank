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

print_summary
