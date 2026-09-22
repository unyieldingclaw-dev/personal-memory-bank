#!/usr/bin/env bash
# tests/test-pre-commit-hook.sh — behaviour of .githooks/pre-commit, run by real `git commit`s in
# throwaway fixture repos (never this repository).
#
# WHY this suite exists: "never commit memory-bank/ from a linked worktree" was enforced only by
# `mb commit`, so a plain `git commit` walked straight past it. The hook catches `git commit`
# itself, which is the only command git runs pre-commit for. Everything in docs/HOOKS-GUIDE.md's
# known gaps (a clean merge, cherry-pick, revert, rebase, `--no-verify`/`-n`, ...) never runs the
# hook, so no test here can reach it.
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

print_summary
