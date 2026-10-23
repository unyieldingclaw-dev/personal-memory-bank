#!/usr/bin/env bash
# tests/test-pre-commit-hook.sh — behaviour of .githooks/pre-commit, run by real `git commit`s in
# throwaway fixture repos (never this repository).
#
# WHY this suite exists: "never commit memory-bank/ from a linked worktree" was enforced only by
# `mb commit`, so a plain `git commit` walked straight past it. Git runs the hook for `git commit`
# and for a conflicted cherry-pick or revert finished with `--continue`. The commands in
# docs/HOOKS-GUIDE.md's known gaps (a clean merge, a clean cherry-pick or revert, `rebase
# --continue`, `am`, `--no-verify`/`-n`, ...) never run it, so no test here can reach them.
#
# WHY the hook's own "git failed" branches have no test: git prepends its exec-path to PATH before
# running a hook (measured 2026-09-21 on Git for Windows: the hook saw /mingw64/libexec/git-core
# first), so a PATH stub cannot intercept the hook's `git` calls. Adding an env var that swaps the
# hook's git binary would make those branches testable and would also hand every caller a one-word
# bypass of a security hook, so it is deliberately not done. The broken-MERGE_HEAD case below IS
# testable, because it uses git's own behaviour rather than a stub.
set -u

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$REPO_ROOT/tests/helpers/assert.sh"
HOOK_SRC="$REPO_ROOT/.githooks/pre-commit"

echo "=== .githooks/pre-commit tests ==="

# One trap over an accumulating array -- see tests/test-mb-commit.sh:12-19 for why a trap per
# fixture leaks every fixture but the last.
ALL_TMPDIRS=()
cleanup_all() {
    [ "${#ALL_TMPDIRS[@]}" -gt 0 ] && rm -rf "${ALL_TMPDIRS[@]}"
    return 0
}
trap cleanup_all EXIT

new_tmp() {
    local d
    d="$(mktemp -d 2>/dev/null || mktemp -d -t pmb-pre-commit)"
    ALL_TMPDIRS+=("$d")
    T="$d"
}

# A path git.exe can read on Windows, unchanged elsewhere. Same pattern as test-mb-commit.sh.
native_path() {
    if command -v cygpath > /dev/null 2>&1; then cygpath -m "$1"; else printf '%s\n' "$1"; fi
}

# make_repo DIR -- a PMB-shaped repo with THIS checkout's hook installed the way `mb init` installs
# it (relative core.hooksPath, hook committed), so a linked worktree runs its own branch's copy.
make_repo() {
    mkdir -p "$1" && (
        cd "$1" || exit 1
        git init -q
        git config user.email "test@test.com"
        git config user.name "Test"
        mkdir -p .githooks memory-bank
        cp "$HOOK_SRC" .githooks/pre-commit && chmod +x .githooks/pre-commit
        git config core.hooksPath .githooks
        echo base > memory-bank/ctx.md
        echo base > code.txt
        git add -A && git commit -q -m init
    )
}

# fresh_pair -- sets T to a new dir holding main/ (main worktree) and wt/ (a linked worktree).
fresh_pair() {
    new_tmp
    make_repo "$T/main" && git -C "$T/main" worktree add -q "$T/wt" -b wt-branch 2>/dev/null
}

# try_commit DIR [git-commit args...] -- sets OUT and RC.
try_commit() {
    local d="$1"; shift
    OUT=$(cd "$d" && git commit -q -m test "$@" 2>&1)
    RC=$?
}

# Every fixture step must succeed; a broken fixture must FAIL the suite, never pass or skip it.
setup_ok() { assert_equals "$1" "0" "fixture: $2"; }

# ── main worktree: memory-bank/ commits are the normal, allowed path ─────────────────────────
echo ""
echo "--- main worktree: memory-bank/ commit allowed ---"
fresh_pair; setup_ok $? "main repo + linked worktree created"
echo edit >> "$T/main/memory-bank/ctx.md"; git -C "$T/main" add memory-bank
try_commit "$T/main"
assert_equals "$RC" "0" "main worktree: memory-bank/ edit commits"

# ── linked worktree: every ordinary way of committing memory-bank/ is refused ─────────────────
echo ""
echo "--- linked worktree: memory-bank/ commit refused ---"
fresh_pair; setup_ok $? "main repo + linked worktree created"
before=$(git -C "$T/wt" rev-parse HEAD)
echo edit >> "$T/wt/memory-bank/ctx.md"; git -C "$T/wt" add memory-bank
try_commit "$T/wt"
assert_exit_nonzero "$RC" "linked worktree: staged memory-bank/ edit is refused"
assert_contains "$OUT" "memory-bank/ctx.md" "linked worktree: refusal names the offending path"
assert_contains "$OUT" "main worktree" "linked worktree: refusal says where to commit instead"
# The refusal must never teach a way around the hook -- that turns a guard into a how-to.
assert_not_contains "$OUT" "no-verify" "linked worktree: refusal does not suggest --no-verify"
assert_not_contains "$OUT" "continue" "linked worktree: refusal does not suggest a --continue path"
assert_equals "$(git -C "$T/wt" rev-parse HEAD)" "$before" "linked worktree: nothing was committed"

echo ""
echo "--- linked worktree: git commit -a (edit never staged by hand) ---"
git -C "$T/wt" reset -q --hard
echo edit >> "$T/wt/memory-bank/ctx.md"
try_commit "$T/wt" -a
assert_exit_nonzero "$RC" "commit -a: unstaged memory-bank/ edit is refused"

echo ""
echo "--- linked worktree: git commit -- <path> (only-mode, temporary index) ---"
git -C "$T/wt" reset -q --hard
echo edit >> "$T/wt/memory-bank/ctx.md"
try_commit "$T/wt" -- memory-bank/ctx.md
assert_exit_nonzero "$RC" "commit -- memory-bank/ctx.md: refused"

echo ""
echo "--- linked worktree: renaming a file OUT of memory-bank/ ---"
# With rename detection on (git's default), --name-only lists only the destination, so the
# memory-bank/ side of the move would be invisible to a naive check.
git -C "$T/wt" reset -q --hard
git -C "$T/wt" mv memory-bank/ctx.md ctx-moved.md
try_commit "$T/wt"
assert_exit_nonzero "$RC" "rename out of memory-bank/: refused"

echo ""
echo "--- linked worktree: Memory-Bank/ spelled with other casing ---"
# Staged straight into the index so the path's case is exact on every filesystem -- on a
# case-insensitive one, a file written to Memory-Bank/ would land in the existing memory-bank/.
git -C "$T/wt" reset -q --hard
blob=$(echo x | git -C "$T/wt" hash-object -w --stdin)
git -C "$T/wt" update-index --add --cacheinfo "100644,$blob,Memory-Bank/other.md"
try_commit "$T/wt"
assert_exit_nonzero "$RC" "Memory-Bank/ casing: refused"
git -C "$T/wt" rm -q --cached Memory-Bank/other.md

echo ""
echo "--- linked worktree: non-ASCII filename (git C-quotes it by default) ---"
# With core.quotePath at its default, --name-only prints "memory-bank/caf\303\251.md" WITH a
# leading double quote, so a ^memory-bank/ match on that output never sees it.
git -C "$T/wt" reset -q --hard
blob=$(echo x | git -C "$T/wt" hash-object -w --stdin)
git -C "$T/wt" update-index --add --cacheinfo "100644,$blob,memory-bank/café.md"
try_commit "$T/wt"
assert_exit_nonzero "$RC" "non-ASCII memory-bank/ filename: refused"
git -C "$T/wt" rm -q --cached "memory-bank/café.md"

echo ""
echo "--- linked worktree: non-memory-bank commit allowed ---"
git -C "$T/wt" reset -q --hard
echo feature > "$T/wt/feature.txt"; git -C "$T/wt" add feature.txt
try_commit "$T/wt"
assert_equals "$RC" "0" "linked worktree: code-only commit is allowed"

echo ""
echo "--- linked worktree: templates/memory-bank/ is not memory-bank/ ---"
mkdir -p "$T/wt/templates/memory-bank"; echo t > "$T/wt/templates/memory-bank/x.md"
git -C "$T/wt" add templates
try_commit "$T/wt"
assert_equals "$RC" "0" "linked worktree: templates/memory-bank/ is allowed (only the top-level dir is guarded)"

# ── merging main into a linked worktree ─────────────────────────────────────────────────────
# Finishing a CONFLICTED merge runs pre-commit (a clean merge does not), and main's memory-bank/
# changes arrive staged. Content taken verbatim from the merged branch is not an edit made here.
echo ""
echo "--- linked worktree: conflicted merge of main, memory-bank/ inherited unchanged ---"
fresh_pair; setup_ok $? "main repo + linked worktree created"
echo main-mb > "$T/main/memory-bank/ctx.md"; echo main-code > "$T/main/code.txt"
git -C "$T/main" commit -q -am "main moves"; setup_ok $? "main commits memory-bank/ + code"
main_tip=$(git -C "$T/main" rev-parse HEAD)
echo wt-code > "$T/wt/code.txt"; git -C "$T/wt" commit -q -am "wt code"; setup_ok $? "worktree commits code"
git -C "$T/wt" merge -q --no-edit "$main_tip" > /dev/null 2>&1
[ -f "$(git -C "$T/wt" rev-parse --git-dir)/MERGE_HEAD" ]; setup_ok $? "merge stopped on a conflict"
echo resolved > "$T/wt/code.txt"; git -C "$T/wt" add code.txt
try_commit "$T/wt" --no-edit
assert_equals "$RC" "0" "merge: memory-bank/ inherited verbatim from MERGE_HEAD is allowed"

echo ""
echo "--- linked worktree: conflicted merge with memory-bank/ edited during resolution ---"
fresh_pair; setup_ok $? "main repo + linked worktree created"
echo main-mb > "$T/main/memory-bank/ctx.md"; echo main-code > "$T/main/code.txt"
git -C "$T/main" commit -q -am "main moves"; setup_ok $? "main commits memory-bank/ + code"
main_tip=$(git -C "$T/main" rev-parse HEAD)
echo wt-code > "$T/wt/code.txt"; git -C "$T/wt" commit -q -am "wt code"; setup_ok $? "worktree commits code"
git -C "$T/wt" merge -q --no-edit "$main_tip" > /dev/null 2>&1
[ -f "$(git -C "$T/wt" rev-parse --git-dir)/MERGE_HEAD" ]; setup_ok $? "merge stopped on a conflict"
echo resolved > "$T/wt/code.txt"; echo hand-edit >> "$T/wt/memory-bank/ctx.md"
git -C "$T/wt" add code.txt memory-bank
try_commit "$T/wt" --no-edit
assert_exit_nonzero "$RC" "merge: memory-bank/ edited during resolution is refused"
assert_contains "$OUT" "git checkout MERGE_HEAD --" "merge: refusal names the way to take the merged side's version"

echo ""
echo "--- linked worktree: MERGE_HEAD that git cannot read fails CLOSED ---"
# If the comparison against MERGE_HEAD errors, its empty output must not read as "nothing here
# differs from the merged side" -- that would wave every memory-bank/ path through.
fresh_pair; setup_ok $? "main repo + linked worktree created"
printf 'deadbeefdeadbeefdeadbeefdeadbeefdeadbeef\n' > "$(git -C "$T/wt" rev-parse --git-dir)/MERGE_HEAD"
echo edit >> "$T/wt/memory-bank/ctx.md"; git -C "$T/wt" add memory-bank
try_commit "$T/wt" --no-edit
assert_exit_nonzero "$RC" "unreadable MERGE_HEAD: commit does not go through"
assert_contains "$OUT" "memory-bank" "unreadable MERGE_HEAD: the hook itself refused (not just git failing later)"

# ── layouts that are NOT linked worktrees, and this repo's own absolute hooksPath ───────────
echo ""
echo "--- absorbed submodule: its own main worktree, allowed ---"
# The submodule's .git is a gitlink FILE, which is what fooled mb commit's $PWD/.git comparison.
new_tmp
make_repo "$T/subsrc" && make_repo "$T/super"; setup_ok $? "superproject and submodule source created"
git -C "$T/super" -c protocol.file.allow=always submodule add -q "$(native_path "$T/subsrc")" mod > /dev/null 2>&1
setup_ok $? "submodule added"
if [ -f "$T/super/mod/.githooks/pre-commit" ]; then
    git -C "$T/super/mod" config user.email "test@test.com"
    git -C "$T/super/mod" config user.name "Test"
    git -C "$T/super/mod" config core.hooksPath .githooks
    echo edit >> "$T/super/mod/memory-bank/ctx.md"; git -C "$T/super/mod" add memory-bank
    try_commit "$T/super/mod"
    assert_equals "$RC" "0" "submodule: memory-bank/ commit is allowed"
    # Proves the hook really runs inside the submodule, so the pass above is not vacuous.
    echo h > "$T/super/mod/handoff.md"; git -C "$T/super/mod" add handoff.md
    try_commit "$T/super/mod"
    assert_exit_nonzero "$RC" "submodule: hook is active there (handoff.md still refused)"
else
    assert_file_exists "$T/super/mod/.githooks/pre-commit" "submodule checkout carries the hook"
fi

echo ""
echo "--- absolute core.hooksPath (this repo's own configuration) ---"
# With an absolute path every worktree runs the MAIN checkout's copy of the hook.
fresh_pair; setup_ok $? "main repo + linked worktree created"
git -C "$T/main" config core.hooksPath "$(native_path "$T/main/.githooks")"
echo edit >> "$T/wt/memory-bank/ctx.md"; git -C "$T/wt" add memory-bank
try_commit "$T/wt"
assert_exit_nonzero "$RC" "absolute hooksPath: linked worktree memory-bank/ commit is refused"

# ── the pre-existing check keeps working ────────────────────────────────────────────────────
echo ""
echo "--- handoff.md is still refused ---"
fresh_pair; setup_ok $? "main repo + linked worktree created"
echo h > "$T/main/handoff.md"; git -C "$T/main" add handoff.md
try_commit "$T/main"
assert_exit_nonzero "$RC" "handoff.md staged: refused"
assert_contains "$OUT" "handoff.md is staged" "handoff.md staged: original message"

# ── format check dispatch [NS-58] ───────────────────────────────────────────────────────────
# The hook lists the staged regular files and pipes them, NUL-terminated, to a repo-owned
# .githooks/format-check. These fixtures install a recorder there that saves its stdin to $FC_LOG
# and exits $FC_EXIT, so every assertion is about exactly what the hook handed over.
export FC_LOG FC_EXIT=0
RECORDER='cat > "$FC_LOG"
exit "${FC_EXIT:-0}"'

# fc_install DIR -- put the recorder in DIR's .githooks/ and point FC_LOG into a fresh tmp dir.
# Not via new_tmp: that reassigns T, which callers are still using.
fc_install() {
    local d
    printf '%s\n' "$RECORDER" > "$1/.githooks/format-check"
    d="$(mktemp -d 2>/dev/null || mktemp -d -t pmb-fc-log)"
    ALL_TMPDIRS+=("$d")
    FC_LOG="$d/fc-stdin"
}
# fc_got -- the recorded paths, one per line in byte order, or "<not run>".
fc_got() {
    if [ -f "$FC_LOG" ]; then tr '\0' '\n' < "$FC_LOG" | LC_ALL=C sort; else echo "<not run>"; fi
}

echo ""
echo "--- format check: no .githooks/format-check, nothing runs ---"
new_tmp; make_repo "$T/r"; setup_ok $? "repo created"
echo x > "$T/r/new.json"; git -C "$T/r" add new.json
try_commit "$T/r"
assert_equals "$RC" "0" "no format-check: commit allowed"
assert_equals "$OUT" "" "no format-check: hook prints nothing"

echo ""
echo "--- format check: exact paths, NUL-terminated, regular files only ---"
new_tmp; R="$T/r"; make_repo "$R"; setup_ok $? "repo created"
fc_install "$R"
mkdir -p "$R/x="
for f in "a b.json" "-dash.json" "café.json" "x=/y.json"; do echo x > "$R/$f"; done
# MSYS_NO_PATHCONV: Git for Windows' bash would hand git.exe "x=C:/Program Files/Git/y.json" --
# the very rewriting the hook avoids by using stdin. It is ignored everywhere else. From inside the
# repo rather than with -C, because it would stop -C's path being converted too.
(cd "$R" && MSYS_NO_PATHCONV=1 git add -- "a b.json" "-dash.json" "café.json" "x=/y.json")
setup_ok $? "unusual names staged"
git -C "$R" rm -q code.txt
head=$(git -C "$R" rev-parse HEAD)
git -C "$R" update-index --add --cacheinfo "160000,$head,submod"
blob=$(printf 'code.txt' | git -C "$R" hash-object -w --stdin)
git -C "$R" update-index --add --cacheinfo "120000,$blob,link.json"
try_commit "$R"
assert_equals "$RC" "0" "recorder exit 0: commit allowed"
# MSYS would rewrite x=/y.json if it were passed as an argument to a native program; on stdin it is
# just bytes. A deletion, a gitlink (a directory) and a symlink are not regular files to format.
assert_equals "$(fc_got)" "$(printf '%s\n' "-dash.json" "a b.json" "café.json" "x=/y.json")" \
    "format-check got exactly the staged regular files (no deletion, gitlink or symlink)"

echo ""
echo "--- format check: every path is NUL-terminated, the last one too ---"
new_tmp; R="$T/r"; make_repo "$R"; setup_ok $? "repo created"
fc_install "$R"
echo x > "$R/one.json"; git -C "$R" add one.json
try_commit "$R"
printf 'one.json\0' | cmp -s - "$FC_LOG"
assert_equals "$?" "0" "stdin is exactly 'one.json\\0'"

echo ""
echo "--- format check: renames and copies are checked under hostile diff config ---"
# NS-58(c): --diff-filter=ACM silently skipped a renamed file. The hook lists with plumbing and
# --no-renames, so neither diff.renames nor color config can change what it sees.
new_tmp; R="$T/r"; make_repo "$R"; setup_ok $? "repo created"
fc_install "$R"
git -C "$R" config diff.renames copies; git -C "$R" config color.ui always
git -C "$R" mv code.txt renamed.txt; echo more >> "$R/renamed.txt"; git -C "$R" add renamed.txt
cp "$R/memory-bank/ctx.md" "$R/copied.md"; git -C "$R" add copied.md
try_commit "$R"
assert_equals "$(fc_got)" "$(printf '%s\n' copied.md renamed.txt)" "rename and copy destinations are listed"

echo ""
echo "--- format check: a symlink that became a regular file is checked ---"
new_tmp; R="$T/r"; make_repo "$R"; setup_ok $? "repo created"
blob=$(printf 'code.txt' | git -C "$R" hash-object -w --stdin)
git -C "$R" update-index --add --cacheinfo "120000,$blob,was-link.json"
try_commit "$R"; setup_ok "$RC" "symlink committed"
fc_install "$R"
blob=$(echo '{}' | git -C "$R" hash-object -w --stdin)
git -C "$R" update-index --cacheinfo "100644,$blob,was-link.json"
try_commit "$R"
assert_equals "$(fc_got)" "was-link.json" "typechange to a regular file is listed"

echo ""
echo "--- format check: nothing to check means the script is not run ---"
new_tmp; R="$T/r"; make_repo "$R"; setup_ok $? "repo created"
fc_install "$R"
git -C "$R" rm -q code.txt
try_commit "$R"
assert_equals "$RC" "0" "deletion-only commit allowed"
assert_equals "$(fc_got)" "<not run>" "deletion-only commit: format-check not invoked with an empty list"

echo ""
echo "--- format check: a failing script refuses the commit ---"
new_tmp; R="$T/r"; make_repo "$R"; setup_ok $? "repo created"
fc_install "$R"
before=$(git -C "$R" rev-parse HEAD)
echo x > "$R/new.json"; git -C "$R" add new.json
FC_EXIT=3; try_commit "$R"; FC_EXIT=0
assert_exit_nonzero "$RC" "recorder exit 3: commit refused"
assert_equals "$(git -C "$R" rev-parse HEAD)" "$before" "recorder exit 3: nothing was committed"
assert_contains "$OUT" ".githooks/format-check" "refusal names the script"
assert_contains "$OUT" "exit 3" "refusal reports the script's exit code"
assert_not_contains "$OUT" "no-verify" "refusal does not suggest --no-verify"

echo ""
echo "--- format check: commit -- <path> and commit -a list what is actually committed ---"
# Both commit through a temporary index (GIT_INDEX_FILE); --cached must read that one.
new_tmp; R="$T/r"; make_repo "$R"; setup_ok $? "repo created"
fc_install "$R"
echo staged > "$R/staged.json"; git -C "$R" add staged.json
echo edit >> "$R/code.txt"
try_commit "$R" -- code.txt
assert_equals "$(fc_got)" "code.txt" "commit -- code.txt: only code.txt, not the other staged file"
rm -f "$FC_LOG"
echo edit2 >> "$R/code.txt"
try_commit "$R" -a
assert_equals "$(fc_got)" "$(printf '%s\n' code.txt staged.json)" "commit -a: tracked edit plus the staged file"

echo ""
echo "--- format check: first commit on an unborn branch ---"
new_tmp; R="$T/r"; mkdir -p "$R"
(
    cd "$R" || exit 1
    git init -q && git config user.email "test@test.com" && git config user.name "Test"
    mkdir -p .githooks && cp "$HOOK_SRC" .githooks/pre-commit && git config core.hooksPath .githooks
); setup_ok $? "unborn repo created"
fc_install "$R"
echo x > "$R/first.json"; git -C "$R" add first.json
try_commit "$R"
assert_equals "$RC" "0" "unborn branch: commit allowed"
assert_equals "$(fc_got)" "first.json" "unborn branch: the first commit's files are listed"

echo ""
echo "--- format check: earlier refusals still win, and the script never runs ---"
for fc_exit in 0 1; do
    new_tmp; R="$T/r"; make_repo "$R"; setup_ok $? "repo created"
    fc_install "$R"
    echo h > "$R/handoff.md"; git -C "$R" add handoff.md
    FC_EXIT=$fc_exit; try_commit "$R"; FC_EXIT=0
    assert_exit_nonzero "$RC" "handoff.md + format-check exiting $fc_exit: refused"
    assert_contains "$OUT" "handoff.md is staged" "handoff.md + format-check exiting $fc_exit: handoff refusal shown"
    assert_equals "$(fc_got)" "<not run>" "handoff.md + format-check exiting $fc_exit: script not run"

    fresh_pair; setup_ok $? "main repo + linked worktree created"
    fc_install "$T/wt"
    echo edit >> "$T/wt/memory-bank/ctx.md"; git -C "$T/wt" add memory-bank
    FC_EXIT=$fc_exit; try_commit "$T/wt"; FC_EXIT=0
    assert_exit_nonzero "$RC" "worktree memory-bank/ + format-check exiting $fc_exit: refused"
    assert_contains "$OUT" "linked worktree" "worktree memory-bank/ + format-check exiting $fc_exit: memory-bank refusal shown"
    assert_equals "$(fc_got)" "<not run>" "worktree memory-bank/ + format-check exiting $fc_exit: script not run"
done

echo ""
echo "--- format check: absolute core.hooksPath runs the committing worktree's own script ---"
fresh_pair; setup_ok $? "main repo + linked worktree created"
git -C "$T/main" config core.hooksPath "$(native_path "$T/main/.githooks")"
fc_install "$T/wt"
echo x > "$T/wt/feature.json"; git -C "$T/wt" add feature.json
try_commit "$T/wt"
assert_equals "$(fc_got)" "feature.json" "absolute hooksPath: the linked worktree's .githooks/format-check ran"

# ── the shipped prettier example [NS-58] ────────────────────────────────────────────────────
# templates/examples/format-check/ is copied by hand into a repo's .githooks/. These cases run it
# through the real hook against a FAKE prettier module, so they need node but not npm or the
# network: the fake marks content containing UNFORMATTED as unformatted and PARSE_ERROR as a
# syntax error. Real prettier is not exercised here.
EXAMPLE_DIR="$REPO_ROOT/templates/examples/format-check"
FAKE_PRETTIER='export const version = "3.1.0"
export async function getFileInfo(p, opts) {
  const ignorePath = [].concat((opts && opts.ignorePath) || [])
  return {
    ignored: p.startsWith("ignored") && ignorePath.includes(".prettierignore"),
    inferredParser: p.endsWith(".sh") ? null : "fake",
  }
}
export async function resolveConfig() { return {} }
export async function check(src, opts) {
  if (!opts || !opts.filepath) throw new Error("check() called without filepath")
  if (src.includes("PARSE_ERROR")) throw new Error("SyntaxError: fake parse failure\n  more detail")
  return !src.includes("UNFORMATTED")
}'

# ex_repo [no-prettier] -- sets R to a repo with the example installed and (unless told otherwise)
# the fake prettier in node_modules/.
ex_repo() {
    new_tmp; R="$T/r"; make_repo "$R" || return 1
    cp "$EXAMPLE_DIR/format-check" "$EXAMPLE_DIR/format-check.mjs" "$R/.githooks/" || return 1
    [ "${1:-}" = "no-prettier" ] && return 0
    mkdir -p "$R/node_modules/prettier" &&
        printf '{"name":"prettier","version":"3.1.0","type":"module","exports":"./index.mjs"}\n' \
            > "$R/node_modules/prettier/package.json" &&
        printf '%s\n' "$FAKE_PRETTIER" > "$R/node_modules/prettier/index.mjs"
}

echo ""
echo "--- example: needs node ---"
command -v node > /dev/null 2>&1
assert_equals "$?" "0" "node is on PATH (the example cases below need it)"

echo ""
echo "--- example: formatted staged file is allowed ---"
ex_repo; setup_ok $? "example repo created"
echo good > "$R/good.json"; git -C "$R" add good.json
try_commit "$R"
assert_equals "$RC" "0" "formatted file: commit allowed"

echo ""
echo "--- example: checks the STAGED content, not the working tree ---"
# Fixed on disk but not re-staged: the commit would still carry unformatted content, which CI fails.
ex_repo; setup_ok $? "example repo created"
echo UNFORMATTED > "$R/a.json"; git -C "$R" add a.json; echo good > "$R/a.json"
try_commit "$R"
assert_exit_nonzero "$RC" "unformatted staged, formatted on disk: refused"
assert_contains "$OUT" "not formatted" "refusal says not formatted"
assert_contains "$OUT" "a.json" "refusal names the file"
# The reverse (CRLF on disk, LF staged, is the common Windows case): staged content is what counts.
ex_repo; setup_ok $? "example repo created"
echo good > "$R/b.json"; git -C "$R" add b.json; echo UNFORMATTED > "$R/b.json"
try_commit "$R"
assert_equals "$RC" "0" "formatted staged, unformatted on disk: allowed"

echo ""
echo "--- example: a parse error is reported as one, not as 'not formatted' ---"
ex_repo; setup_ok $? "example repo created"
echo PARSE_ERROR > "$R/broken.json"; git -C "$R" add broken.json
try_commit "$R"
assert_exit_nonzero "$RC" "parse error: refused"
assert_contains "$OUT" "could not parse" "parse error: says it could not parse"
assert_contains "$OUT" "broken.json" "parse error: names the file"
assert_not_contains "$OUT" "not formatted" "parse error: not reported as unformatted"

echo ""
echo "--- example: ignored files and files prettier has no parser for are skipped ---"
ex_repo; setup_ok $? "example repo created"
echo UNFORMATTED > "$R/ignored.json"; echo UNFORMATTED > "$R/s.sh"
git -C "$R" add ignored.json s.sh
try_commit "$R"
assert_equals "$RC" "0" "ignored and parser-less files: allowed"

echo ""
echo "--- example: unusual names map to the right staged content ---"
ex_repo; setup_ok $? "example repo created"
echo good > "$R/ok one.json"; echo UNFORMATTED > "$R/café two.json"; echo good > "$R/-dash.json"
git -C "$R" add -- "ok one.json" "café two.json" "-dash.json"
try_commit "$R"
assert_exit_nonzero "$RC" "one unformatted among unusual names: refused"
assert_contains "$OUT" "café two.json" "refusal names the unformatted file"
assert_not_contains "$OUT" "ok one.json" "refusal does not name the formatted file"

echo ""
echo "--- example: commit -a checks the temporary index ---"
ex_repo; setup_ok $? "example repo created"
echo UNFORMATTED > "$R/code.txt"
try_commit "$R" -a
assert_exit_nonzero "$RC" "commit -a with an unformatted tracked edit: refused"

echo ""
echo "--- example: prettier not installed warns and allows ---"
ex_repo no-prettier; setup_ok $? "example repo created without prettier"
echo UNFORMATTED > "$R/a.json"; git -C "$R" add a.json
try_commit "$R"
assert_equals "$RC" "0" "no prettier: commit allowed"
assert_contains "$OUT" "not installed" "no prettier: says it is not installed"

print_summary
