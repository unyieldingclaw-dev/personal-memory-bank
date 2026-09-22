#!/usr/bin/env bash
# tests/test-mb-commit.sh — tests for mb commit
set -u

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
MB="$REPO_ROOT/scripts/mb.sh"
source "$REPO_ROOT/tests/helpers/assert.sh"
source "$REPO_ROOT/tests/setup.sh"

echo "=== mb commit tests ==="

# WHY one trap over an accumulating array instead of a `trap ... EXIT` per fixture: bash keeps
# only the LAST trap registered for a signal, so each later `trap` silently discards the previous
# one and every fixture but the final one leaks. The per-fixture form was written here first and
# measured leaking two directories per run -- one of them a full setup_test_project git repo --
# before being replaced; that draft was never committed, so this note is the only record of it.
# The same defect was found and fixed twice before in this suite, with WHY comments left at
# tests/test-mb-backlog.sh:18-25 and tests/test-mb-version-notifier.sh:20-27. Register once,
# append per fixture.
ALL_TMPDIRS=()
cleanup_all() {
    # Removing the worktree registration first is belt-and-braces only: ALL_TMPDIRS holds the
    # PARENT ($TMPDIR_WT), so the `rm -rf` below takes the whole worktree pair either way. It is
    # kept so the fixture repo is left without a stale worktree entry if the rm is ever narrowed.
    # Scoped by -C to a mktemp path; it cannot reach the real repo. Both are best-effort --
    # cleanup must never fail the suite.
    if [ -n "${TMPDIR_WT:-}" ] && [ -d "${TMPDIR_WT:-}/main" ]; then
        git -C "$TMPDIR_WT/main" worktree remove --force "$TMPDIR_WT/child" 2>/dev/null || true
    fi
    [ "${#ALL_TMPDIRS[@]}" -gt 0 ] && rm -rf "${ALL_TMPDIRS[@]}"
    return 0
}
trap cleanup_all EXIT

TMPDIR_COMMIT="$(mktemp -d 2>/dev/null || mktemp -d -t mb-commit-test)"
ALL_TMPDIRS+=("$TMPDIR_COMMIT")

setup_test_project "$TMPDIR_COMMIT"

# ── No changes: graceful message ─────────────────────────────────────────────
echo ""
echo "--- no changes: nothing to commit ---"

output=$(cd "$TMPDIR_COMMIT" && MB_HOME="$REPO_ROOT" bash "$MB" commit 2>&1)
assert_exit_zero $? "mb commit exits 0 when nothing to commit"
assert_contains "$output" "No changes" "mb commit reports no changes when memory-bank is clean"

# ── Modified file: commit succeeds ───────────────────────────────────────────
echo ""
echo "--- modified file: commit succeeds ---"

echo "# New entry" >> "$TMPDIR_COMMIT/memory-bank/progress.md"

output=$(echo "y" | (cd "$TMPDIR_COMMIT" && MB_HOME="$REPO_ROOT" bash "$MB" commit 2>&1))
assert_exit_zero $? "mb commit exits 0 after confirming"
assert_contains "$output" "Committed" "mb commit reports Committed on success"

commit_count=$(cd "$TMPDIR_COMMIT" && git rev-list --count HEAD 2>&1)
assert_contains "$commit_count" "2" "git shows 2 commits after mb commit"

# ── Non-git directory: exits gracefully, not at git's 128 ────────────────────
# WHY this fixture is built by hand instead of via setup_test_project: that helper git-inits,
# and every case above therefore runs inside a repo. `invoke_commit` reads git status into a
# bare assignment, so under `set -e` it aborted at exit 128 outside a repo having printed only
# its banner -- no error, no diagnostic. The guarded form four lines above it (COMMON_GIT) shows
# the intended pattern; this asserts the graceful path is actually reachable.
echo ""
echo "--- non-git directory: graceful exit, not 128 ---"

TMPDIR_COMMIT_NOGIT="$(mktemp -d 2>/dev/null || mktemp -d -t mb-commit-nogit)"
ALL_TMPDIRS+=("$TMPDIR_COMMIT_NOGIT")

mkdir -p "$TMPDIR_COMMIT_NOGIT/memory-bank"
printf -- "---\nauthority: stable\nlast-reviewed: %s\nstaleness-threshold: 90d\n---\n# activeContext\nTest content.\n" \
    "$(date +%Y-%m-%d)" > "$TMPDIR_COMMIT_NOGIT/memory-bank/activeContext.md"
echo "# Project" > "$TMPDIR_COMMIT_NOGIT/CLAUDE.md"

output=$(cd "$TMPDIR_COMMIT_NOGIT" && MB_HOME="$REPO_ROOT" bash "$MB" commit 2>&1)
rc=$?
assert_equals "$rc" "1" "non-git: mb commit exits 1 — a clean refusal, not git's 128 crash"
assert_contains "$output" "Not a git repository" "non-git: mb commit names the real condition"
# The discriminating assertion. Without it this test passes just as well against the misleading
# fall-through, which reported "No changes in memory-bank/ to commit" when there was no repo at
# all -- true-sounding, wrong, and indistinguishable from a clean tree.
assert_not_contains "$output" "No changes" "non-git: does NOT claim there were merely no changes"

# ── Subworktree: refusal exits non-zero ──────────────────────────────────────
# WHY this test exists: the subworktree guard returned 0 before the commit that added this test,
# so `mb commit && ...` ran the success branch from a worktree having committed nothing (no date
# is written here -- git blame supplies it and cannot go stale). Changing that is an
# adopter-visible contract change, and one with no test is indistinguishable from an accident.
# On the delivery route, stated narrowly because the obvious guess is wrong: `mb.sh`/`mb.ps1` are
# NOT in TEMPLATE_OWNED and appear in no delivery array, and `templates/scripts/` ships no `mb.*`
# -- so `mb upgrade` does NOT deliver this file. Adopters run `mb` out of their own PMB clone
# (hence `$REPO_ROOT/VERSION`), so they pick the new exit code up whenever that clone updates.
# That is a WEAKER signal than a force-overwrite, not a stronger one: there is no moment where
# an adopter is shown a diff, which is exactly why it has to be named in the commit message.
# This is the only fixture in the suite that builds a real git worktree.
echo ""
echo "--- subworktree: refusal exits non-zero ---"

TMPDIR_WT="$(mktemp -d 2>/dev/null || mktemp -d -t mb-commit-wt)"
ALL_TMPDIRS+=("$TMPDIR_WT")

setup_test_project "$TMPDIR_WT/main"
(cd "$TMPDIR_WT/main" && git worktree add -q "$TMPDIR_WT/child" -b wt-test 2>/dev/null)

if [ -d "$TMPDIR_WT/child" ]; then
    output=$(cd "$TMPDIR_WT/child" && MB_HOME="$REPO_ROOT" bash "$MB" commit 2>&1)
    rc=$?
    assert_equals "$rc" "1" "subworktree: mb commit exits 1, not 0 — a refusal is not a success"
    assert_contains "$output" "git subworktree" "subworktree: names the condition"
    assert_not_contains "$output" "Committed" "subworktree: did not commit"
else
    echo "  SKIP: git worktree add unavailable — subworktree exit-code case not exercised"
fi

# ── PowerShell parity: the guard must DISCRIMINATE, not merely fire ──────────
# WHY this exists, and why it asserts the HAPPY path first: mb.ps1's subworktree guard compared
# two Resolve-Path results with `-ne`. Resolve-Path returns a PathInfo, which has no value
# equality, so that compared REFERENCES and was unconditionally true -- it fired in a healthy
# main worktree where both sides resolved to the identical string. `mb commit` therefore refused
# in EVERY repository on the documented Windows entry point (install.bat -> mb.bat -> pwsh
# mb.ps1) and had never worked there. Both runtimes were checked before that was found, but only
# against non-git and subworktree fixtures -- states where the guard is SUPPOSED to fire, which
# cannot distinguish "works" from "always fires". That gap is why the defect shipped, so the
# main-worktree case is asserted first here and the subworktree case second: together they prove
# discrimination. A test that only exercised refusals would pass against the broken comparison.
echo ""
echo "--- pwsh parity: mb.ps1 guard discriminates (main worktree vs subworktree) ---"

# Set to 1 only once the probe below has proved pwsh really executes mb.ps1. Every later pwsh
# assertion in this file gates on it, not on `command -v pwsh`, because a stub satisfies
# `command -v` and then makes negative assertions pass on its empty output.
PWSH_USABLE=0

if command -v pwsh > /dev/null 2>&1; then
    # `cygpath -w` is kept, but its original justification no longer holds and is corrected here
    # rather than left to rot. It was written for an earlier form that INTERPOLATED the path into
    # the -Command string, where a POSIX `/c/Users/...` path genuinely could not be resolved.
    # Passing the path through the environment instead (see below) changed that: MSYS translates
    # POSIX paths in exported env vars but NOT inside a longer argument, so the fallback branch
    # now resolves and runs correctly too. Measured both ways on this machine. The conversion is
    # retained because it is harmless, explicit, and independent of that MSYS behaviour -- not
    # because the fallback is broken.
    #
    # The vacuous-pass risk the gate below exists for is real regardless: an unresolvable script
    # makes pwsh print "not recognized as a name of a cmdlet" and STILL EXIT 0, so the happy-path
    # assertions (which want rc=0 and no "subworktree" in the output) both pass while executing
    # nothing. A draft of this block did exactly that.
    if command -v cygpath > /dev/null 2>&1; then
        MBPS1="$(cygpath -w "$REPO_ROOT/scripts/mb.ps1")"
        MB_HOME_WIN="$(cygpath -w "$REPO_ROOT")"
    else
        MBPS1="$REPO_ROOT/scripts/mb.ps1"
        MB_HOME_WIN="$REPO_ROOT"
    fi

    # WHY the path goes through the ENVIRONMENT and every -Command body is SINGLE-quoted in bash:
    # interpolating a path into a double-quoted bash string that becomes a single-quoted
    # PowerShell literal is a command-injection primitive, not just a quoting nit. A checkout
    # directory containing  ' ; #  -- all legal in Windows paths -- closes the PowerShell string,
    # chains a statement and comments out the remainder. Demonstrated with a directory named
    #   x'; Write-Host 'INJECTED'; #
    # which executed the injected statement and still exited 0. $env:MB_SCRIPT is read by
    # PowerShell itself, so nothing in the path is ever parsed as code. The same idiom appears
    # unfixed elsewhere in this suite (tests/test-review-gate-lib.sh dot-sources an interpolated
    # path); that is pre-existing and tracked separately, not fixed here.
    ps_commit() { # $1 = fixture dir; sets ps_out / ps_rc
        ps_out=$(cd "$1" && MB_HOME="$MB_HOME_WIN" MB_SCRIPT="$MBPS1" pwsh -NoProfile -Command \
            '$PSStyle.OutputRendering="PlainText"; & $env:MB_SCRIPT commit; exit $LASTEXITCODE' 2>&1)
        ps_rc=$?
    }

    # HARD GATE, and it demands POSITIVE proof that pwsh executed mb.ps1 rather than merely
    # failing to error. Two distinct vacuous-pass modes made that necessary, both measured here:
    #
    #   1. An unresolvable script path: pwsh prints "not recognized as a name of a cmdlet" and
    #      still EXITS 0, because `exit $LASTEXITCODE` sees $null when no native process ran.
    #      (`pwsh -Command 'exit $null'` exits 0.)
    #   2. A `pwsh` that is a non-functional stub -- e.g. a Windows Store app-execution-alias
    #      placeholder, which `command -v pwsh` finds happily. It exits 0 and prints NOTHING.
    #
    # Mode 2 defeats every negative check: rc is 0, which is exactly what the happy-path
    # assertion wants, and empty output contains no forbidden substring, which is what
    # assert_not_contains wants. Measured with a stub on PATH: THREE assertions passed while
    # executing nothing, including both assertions whose entire purpose is proving the guard
    # discriminates. An earlier form of this gate also only WARNED and then fell through, so a
    # run could print "would pass vacuously" and, one line below, PASS them anyway.
    #
    # Asserting a string that only a real mb run emits closes both modes at once. Not unique to
    # mb.ps1 -- scripts/mb.sh:154 prints the same banner -- but nothing except mb prints it, and
    # this probe invokes pwsh against $env:MB_SCRIPT, so only the .ps1 can answer it here. It also
    # replaces the previous `not recognized as (a|the) name` grep, which was pinned to English
    # PowerShell resource text (5.1 says "as THE name ... operable program") and would silently
    # stop firing on a localized build.
    probe=$(MB_SCRIPT="$MBPS1" pwsh -NoProfile -Command '& $env:MB_SCRIPT help' 2>&1)
    probe_rc=$?
    if [ "$probe_rc" -ne 0 ] || ! printf '%s' "$probe" | grep -q 'Usage: mb <command>'; then
        echo "  FAIL: pwsh did not execute $MBPS1 (rc=$probe_rc, no help banner) — parity assertions SKIPPED rather than passed vacuously"
        FAIL=$((FAIL + 1))
    else
        PWSH_USABLE=1
        # Happy path: a healthy main worktree must NOT be mistaken for a subworktree. This is the
        # discriminating case — a refusal-only test passes against the broken comparison.
        ps_commit "$TMPDIR_COMMIT"
        assert_equals "$ps_rc" "0" "pwsh: main worktree exits 0 — guard does not fire in a healthy repo"
        assert_not_contains "$ps_out" "subworktree" "pwsh: main worktree is not reported as a subworktree"

        # Refusal path: a real worktree still must be caught.
        if [ -d "$TMPDIR_WT/child" ]; then
            ps_commit "$TMPDIR_WT/child"
            assert_equals "$ps_rc" "1" "pwsh: subworktree exits 1 — matches mb.sh"
            assert_contains "$ps_out" "git subworktree" "pwsh: subworktree names the condition"
        else
            # An explicit SKIP, matching the bash side above. Without it the pwsh half of the
            # discrimination proof vanished with no output at all when the fixture could not be
            # built, leaving happy-path-only coverage and no trace that it had happened.
            echo "  SKIP: git worktree add unavailable — pwsh subworktree case not exercised"
        fi

        # Not-a-repo path: parity with the bash assertions above.
        ps_commit "$TMPDIR_COMMIT_NOGIT"
        assert_equals "$ps_rc" "1" "pwsh: non-git exits 1 — matches mb.sh"
        assert_contains "$ps_out" "Not a git repository" "pwsh: non-git names the real condition"

        # A SCRIPT PATH CONTAINING SPACES. Real Windows installs put repos under `C:\Program
        # Files\...` or a username with a space, and nothing in this suite exercised one, so the
        # cygpath -w conversion and the env-var handoff were unverified for that shape. This is
        # regression cover for a path that already works, not a fix: measured before adding it,
        # spaces survive both the env-var form and the older interpolated one, because the space
        # is inside a quoted string either way -- only ' ; # break the parse. It guards the
        # handoff against a future rewrite that reintroduces bare interpolation.
        # NOT covered: MB_HOME itself containing spaces. That needs a whole PMB installation
        # relocated under a spacey path, which is heavier than this suite should build; only the
        # script-path half of the conversion is asserted here.
        SPACEDIR="$(mktemp -d 2>/dev/null || mktemp -d -t mb-commit-space)"
        ALL_TMPDIRS+=("$SPACEDIR")
        mkdir -p "$SPACEDIR/Program Files Test/My Repo/scripts"
        cp "$REPO_ROOT/scripts/mb.ps1" "$SPACEDIR/Program Files Test/My Repo/scripts/mb.ps1"
        if command -v cygpath > /dev/null 2>&1; then
            MBPS1_SPACE="$(cygpath -w "$SPACEDIR/Program Files Test/My Repo/scripts/mb.ps1")"
        else
            MBPS1_SPACE="$SPACEDIR/Program Files Test/My Repo/scripts/mb.ps1"
        fi
        ps_out=$(cd "$TMPDIR_COMMIT_NOGIT" && MB_HOME="$MB_HOME_WIN" MB_SCRIPT="$MBPS1_SPACE" \
            pwsh -NoProfile -Command \
            '$PSStyle.OutputRendering="PlainText"; & $env:MB_SCRIPT commit; exit $LASTEXITCODE' 2>&1)
        ps_rc=$?
        assert_equals "$ps_rc" "1" "pwsh: script path with spaces still runs — exits 1 in a non-git dir"
        assert_contains "$ps_out" "Not a git repository" "pwsh: script path with spaces reaches the real guard"

        # A REPO PATH CONTAINING [ ]. Unlike the spaces case above, this one WAS a live defect.
        # Resolve-Path treats its argument as a wildcard, so a bracketed path resolved to $null
        # and the subworktree guard fired in a healthy MAIN worktree -- the same false refusal the
        # .Path fix removed, surviving in a narrower population, with mb.sh saying "No changes"
        # (rc=0) beside mb.ps1 saying "You are in a git subworktree" (rc=1). -LiteralPath closes
        # it. This asserts the HAPPY path for the same reason the main-worktree case above does:
        # a refusal-only test cannot tell a working guard from one that always fires.
        BRACKETDIR="$(mktemp -d 2>/dev/null || mktemp -d -t mb-commit-bracket)"
        ALL_TMPDIRS+=("$BRACKETDIR")
        BRACKETREPO="$BRACKETDIR/my[repo]"
        setup_test_project "$BRACKETREPO"
        ps_commit "$BRACKETREPO"
        assert_equals "$ps_rc" "0" "pwsh: bracketed repo path exits 0 — Resolve-Path does not glob it away"
        assert_not_contains "$ps_out" "subworktree" "pwsh: bracketed main worktree is not reported as a subworktree"

        # ── MB_HOME itself containing brackets ──────────────────────────────
        # WHY this lives in the commit suite: the guard runs at top-level script scope in mb.ps1,
        # above the first function definition and before any
        # command dispatches, so it is not owned by any one command; this file already owns the
        # pwsh + MB_HOME plumbing, so the fixture cost here is one empty directory.
        #
        # The guard is `Test-Path (Join-Path $RepoRoot 'templates') -PathType Container` with
        # $RepoRoot = $env:MB_HOME. Wildcard Test-Path cannot match a path containing [ or ], so an
        # MB_HOME with a bracket failed to find its OWN templates/ and every mb.ps1 command exited 1
        # with a false "templates/ not found", while mb.sh at the same MB_HOME ran normally —
        # measured HEAD rc=1 vs fixed rc=0, plain MB_HOME rc=0 both. A live sh/ps1 divergence, which
        # is the class this branch exists to close.
        #
        # No PWSH_USABLE-style probe is needed: `assert_contains "Usage: mb <command>"` IS the
        # positive proof, so a pwsh that runs nothing fails it rather than passing vacuously. That
        # string is also emitted by scripts/mb.sh:154, so it is not unique to mb.ps1 in the repo —
        # it is unique to *something having actually run mb*, which is what this needs to establish.
        # The assertion is not redundant with the probe above: this run uses a DIFFERENT MB_HOME,
        # which is the variable under test.
        #
        # $RepoRoot only has to contain a templates/ directory for the guard to pass, so this does
        # not relocate a real PMB installation — the contract records that heavier case as still
        # out of scope.
        MBHOMEDIR="$(mktemp -d 2>/dev/null || mktemp -d -t mb-home)"; ALL_TMPDIRS+=("$MBHOMEDIR")
        mkdir -p "$MBHOMEDIR/home[b]/templates"
        if command -v cygpath >/dev/null 2>&1; then
            MBHOME_BR="$(cygpath -w "$MBHOMEDIR/home[b]")"
        else
            MBHOME_BR="$MBHOMEDIR/home[b]"
        fi
        bh_out=$(MB_HOME="$MBHOME_BR" MB_SCRIPT="$MBPS1" pwsh -NoProfile -Command \
            '$PSStyle.OutputRendering="PlainText"; & $env:MB_SCRIPT help; exit $LASTEXITCODE' 2>&1)
        bh_rc=$?
        assert_equals "$bh_rc" "0" "pwsh: bracketed MB_HOME starts — startup guard does not glob its own templates/ away"
        assert_contains "$bh_out" "Usage: mb <command>" "pwsh: bracketed MB_HOME reaches help (positive proof mb.ps1 actually ran)"
        assert_not_contains "$bh_out" "not a valid PMB installation" "pwsh: bracketed MB_HOME is not rejected as an invalid installation"

        # And the bash twin must agree, since a divergence here is what the branch exists to close.
        output=$(cd "$BRACKETREPO" && MB_HOME="$REPO_ROOT" bash "$MB" commit 2>&1)
        rc=$?
        assert_equals "$rc" "0" "bash: bracketed repo path exits 0 — matches mb.ps1"
    fi
else
    echo "  SKIP: pwsh not available — mb.ps1 parity cases not exercised"
fi

# ── git status itself failing must not be reported as "No changes" ───────────
# WHY a corrupted index rather than a mocked git: this is the third behaviour the change claims
# to fix and it was the only one with no fixture, in either runtime. The failure it guards is a
# false SUCCESS -- an empty $STATUS from a FAILED `git status` is indistinguishable from an empty
# $STATUS from a genuinely clean tree, and the `-z` test reports both as "No changes ... to
# commit" with exit 0. So the discriminating assertion is `assert_not_contains "No changes"`:
# without it, a regression to `|| true` (bash) or a dropped $LASTEXITCODE check (pwsh) would pass.
# Truncating .git/index makes `git status --porcelain` exit 128 for real -- no stubbing.
echo ""
echo "--- git status failure is not reported as a clean tree ---"

TMPDIR_BADIDX="$(mktemp -d 2>/dev/null || mktemp -d -t mb-commit-badidx)"
ALL_TMPDIRS+=("$TMPDIR_BADIDX")

setup_test_project "$TMPDIR_BADIDX"
# A REAL uncommitted change, so "No changes" would be wrong even if git were healthy.
echo "# uncommitted entry" >> "$TMPDIR_BADIDX/memory-bank/progress.md"
printf 'X' > "$TMPDIR_BADIDX/.git/index"

if (cd "$TMPDIR_BADIDX" && git status --porcelain memory-bank > /dev/null 2>&1); then
    echo "  SKIP: could not corrupt the index on this platform — git status still succeeds"
else
    output=$(cd "$TMPDIR_BADIDX" && MB_HOME="$REPO_ROOT" bash "$MB" commit 2>&1)
    rc=$?
    assert_equals "$rc" "1" "bad index: mb commit exits 1 rather than reporting success"
    assert_contains "$output" "git status failed" "bad index: names the real condition"
    assert_not_contains "$output" "No changes" "bad index: does NOT claim the tree was clean"

    if [ "$PWSH_USABLE" = "1" ]; then
        ps_out=$(cd "$TMPDIR_BADIDX" && MB_HOME="$MB_HOME_WIN" MB_SCRIPT="$MBPS1" pwsh -NoProfile \
            -Command '$PSStyle.OutputRendering="PlainText"; & $env:MB_SCRIPT commit; exit $LASTEXITCODE' 2>&1)
        ps_rc=$?
        assert_equals "$ps_rc" "1" "pwsh bad index: exits 1 — matches mb.sh"
        assert_not_contains "$ps_out" "No changes" "pwsh bad index: does NOT claim the tree was clean"
    fi
fi

# ── Helpers for the worktree-detection cases below ───────────────────────────
# A path git.exe can read on Windows, unchanged elsewhere.
native_path() {
    if command -v cygpath > /dev/null 2>&1; then cygpath -m "$1"; else printf '%s\n' "$1"; fi
}
# Like ps_commit, but feeds $2 to mb.ps1's confirmation prompt. Only called when PWSH_USABLE=1.
ps_commit_in() { # $1 = dir, $2 = stdin; sets ps_out / ps_rc
    ps_out=$(cd "$1" && printf '%s\n' "$2" | MB_HOME="$MB_HOME_WIN" MB_SCRIPT="$MBPS1" pwsh -NoProfile -Command \
        '$PSStyle.OutputRendering="PlainText"; & $env:MB_SCRIPT commit; exit $LASTEXITCODE' 2>&1)
    ps_rc=$?
}

# ── Subdirectory of the MAIN worktree: refuse, and say why ───────────────────
# WHY: the old comparison put $PWD/.git beside --git-common-dir, so a subdirectory of a perfectly
# healthy main worktree was reported as "a git subworktree". Fixing only the comparison would be
# worse: memory-bank/ is resolved relative to $PWD, so a subdirectory run would look at
# <subdir>/memory-bank, find nothing, and report "No changes" with exit 0 over a dirty memory-bank.
echo ""
echo "--- subdirectory of the main worktree: refused with the real reason ---"
TMPDIR_SUBDIR="$(mktemp -d 2>/dev/null || mktemp -d -t mb-commit-subdir)"; ALL_TMPDIRS+=("$TMPDIR_SUBDIR")
setup_test_project "$TMPDIR_SUBDIR"
echo "# uncommitted entry" >> "$TMPDIR_SUBDIR/memory-bank/progress.md"
output=$(cd "$TMPDIR_SUBDIR/docs" && echo n | MB_HOME="$REPO_ROOT" bash "$MB" commit 2>&1)
rc=$?
assert_equals "$rc" "1" "subdirectory: mb commit refuses (exit 1)"
assert_contains "$output" "repository root" "subdirectory: names the real condition"
assert_not_contains "$output" "subworktree" "subdirectory: not misreported as a subworktree"
assert_not_contains "$output" "No changes" "subdirectory: does not claim memory-bank/ is clean"
if [ "$PWSH_USABLE" = "1" ]; then
    ps_commit_in "$TMPDIR_SUBDIR/docs" n
    assert_equals "$ps_rc" "1" "pwsh subdirectory: refuses (exit 1) — matches mb.sh"
    assert_contains "$ps_out" "repository root" "pwsh subdirectory: names the real condition"
    assert_not_contains "$ps_out" "subworktree" "pwsh subdirectory: not misreported as a subworktree"
fi

# ── Absorbed submodule: its own main worktree, not a subworktree ─────────────
# Its .git is a gitlink FILE, so $PWD/.git never equalled --git-common-dir (.git/modules/<name>).
echo ""
echo "--- absorbed submodule: treated as its own main worktree ---"
TMPDIR_SUBMOD="$(mktemp -d 2>/dev/null || mktemp -d -t mb-commit-submod)"; ALL_TMPDIRS+=("$TMPDIR_SUBMOD")
setup_test_project "$TMPDIR_SUBMOD/src"
setup_test_project "$TMPDIR_SUBMOD/super"
git -C "$TMPDIR_SUBMOD/super" -c protocol.file.allow=always submodule add -q \
    "$(native_path "$TMPDIR_SUBMOD/src")" mod > /dev/null 2>&1
# A broken fixture FAILS rather than skips: a skipped case reads as coverage that never ran.
assert_file_exists "$TMPDIR_SUBMOD/super/mod/memory-bank/progress.md" "submodule fixture: submodule checked out"
if [ -f "$TMPDIR_SUBMOD/super/mod/memory-bank/progress.md" ]; then
    echo "# uncommitted entry" >> "$TMPDIR_SUBMOD/super/mod/memory-bank/progress.md"
    output=$(cd "$TMPDIR_SUBMOD/super/mod" && echo n | MB_HOME="$REPO_ROOT" bash "$MB" commit 2>&1)
    rc=$?
    assert_equals "$rc" "0" "submodule: mb commit proceeds (exit 0)"
    assert_contains "$output" "Changes to commit" "submodule: reaches the commit prompt"
    assert_not_contains "$output" "subworktree" "submodule: not misreported as a subworktree"
    if [ "$PWSH_USABLE" = "1" ]; then
        ps_commit_in "$TMPDIR_SUBMOD/super/mod" n
        assert_equals "$ps_rc" "0" "pwsh submodule: proceeds (exit 0) — matches mb.sh"
        assert_not_contains "$ps_out" "subworktree" "pwsh submodule: not misreported as a subworktree"
    fi
fi

# ── No `realpath` on PATH: the subworktree guard must still fire ─────────────
# WHY: mb.sh compared `realpath` outputs. With realpath missing both came back empty, compared
# equal, and a linked worktree sailed through to the commit prompt. Measured before the fix with a
# stub that exits 127: "Changes to commit", exit 0, from inside a subworktree.
echo ""
echo "--- subworktree with no realpath available: still refused ---"
if [ -d "$TMPDIR_WT/child" ]; then
    NOREALPATH="$(mktemp -d 2>/dev/null || mktemp -d -t mb-commit-norealpath)"; ALL_TMPDIRS+=("$NOREALPATH")
    printf '#!/bin/sh\nexit 127\n' > "$NOREALPATH/realpath"; chmod +x "$NOREALPATH/realpath"
    echo "# uncommitted entry" >> "$TMPDIR_WT/child/memory-bank/progress.md"
    output=$(cd "$TMPDIR_WT/child" && echo n | PATH="$NOREALPATH:$PATH" MB_HOME="$REPO_ROOT" bash "$MB" commit 2>&1)
    rc=$?
    assert_equals "$rc" "1" "no realpath: subworktree still refused (exit 1)"
    assert_contains "$output" "git subworktree" "no realpath: names the condition"
else
    assert_file_exists "$TMPDIR_WT/child" "subworktree fixture exists for the no-realpath case"
fi

# ── Unresolvable git dirs on BOTH sides: refuse, never compare "" to "" ──────
# WHY a stubbed git: two empty values compare equal, which is exactly how the realpath hole above
# let a subworktree through (mb.ps1 has the same shape: `$null -ne $null` is False). A real git
# never returns a directory that does not exist, so the only way to reach that branch is a stub
# that reports one for --git-dir and --git-common-dir and passes every other call through.
echo ""
echo "--- git dirs that cannot be resolved: refused ---"
GITSTUB="$(mktemp -d 2>/dev/null || mktemp -d -t mb-commit-gitstub)"; ALL_TMPDIRS+=("$GITSTUB")
REAL_GIT="$(command -v git)"
mkdir -p "$GITSTUB/sh"
cat > "$GITSTUB/sh/git" <<EOF
#!/usr/bin/env bash
if [ "\${1:-}" = "rev-parse" ] && { [ "\${2:-}" = "--git-dir" ] || [ "\${2:-}" = "--git-common-dir" ]; }; then
    echo "$GITSTUB/does-not-exist/.git"; exit 0
fi
exec "$REAL_GIT" "\$@"
EOF
chmod +x "$GITSTUB/sh/git"
echo "# uncommitted entry" >> "$TMPDIR_COMMIT/memory-bank/progress.md"
output=$(cd "$TMPDIR_COMMIT" && echo n | PATH="$GITSTUB/sh:$PATH" MB_HOME="$REPO_ROOT" bash "$MB" commit 2>&1)
rc=$?
assert_equals "$rc" "1" "unresolvable git dirs: mb commit refuses (exit 1)"
assert_not_contains "$output" "Changes to commit" "unresolvable git dirs: never reaches the commit prompt"
if [ "$PWSH_USABLE" = "1" ]; then
    # PowerShell on Windows only runs PATHEXT files, so it needs a .cmd twin of the stub; on other
    # platforms it runs the bash stub above.
    if command -v cygpath > /dev/null 2>&1; then
        mkdir -p "$GITSTUB/cmd"
        printf '@echo off\r\nif "%%~1"=="rev-parse" if "%%~2"=="--git-dir" goto bogus\r\nif "%%~1"=="rev-parse" if "%%~2"=="--git-common-dir" goto bogus\r\n"%s" %%*\r\nexit /b %%ERRORLEVEL%%\r\n:bogus\r\necho %s\r\nexit /b 0\r\n' \
            "$(cygpath -w "$REAL_GIT")" "$(cygpath -w "$GITSTUB")\\does-not-exist\\.git" > "$GITSTUB/cmd/git.cmd"
        PS_STUB_DIR="$GITSTUB/cmd"
    else
        PS_STUB_DIR="$GITSTUB/sh"
    fi
    ps_out=$(cd "$TMPDIR_COMMIT" && echo n | PATH="$PS_STUB_DIR:$PATH" MB_HOME="$MB_HOME_WIN" MB_SCRIPT="$MBPS1" pwsh -NoProfile -Command \
        '$PSStyle.OutputRendering="PlainText"; & $env:MB_SCRIPT commit; exit $LASTEXITCODE' 2>&1)
    ps_rc=$?
    assert_equals "$ps_rc" "1" "pwsh unresolvable git dirs: refuses (exit 1) — matches mb.sh"
    assert_not_contains "$ps_out" "Changes to commit" "pwsh unresolvable git dirs: never reaches the commit prompt"
fi
git -C "$TMPDIR_COMMIT" checkout -q -- memory-bank

# ── mb commit commits memory-bank/ ONLY ──────────────────────────────────────
# WHY: it ran `git add memory-bank` then a bare `git commit`, which commits the WHOLE index -- so
# anything already staged for other work rode along inside "chore: Update Memory Bank context".
echo ""
echo "--- a file already staged for other work is not swept into the commit ---"
check_only_mb() { # $1 = fixture, $2 = label prefix
    local committed still
    committed=$(git -C "$1" show --name-only --format= HEAD)
    still=$(git -C "$1" diff --cached --name-only)
    assert_contains "$committed" "memory-bank/progress.md" "$2: the memory-bank/ change is committed"
    assert_not_contains "$committed" "other.txt" "$2: the other staged file is NOT committed"
    assert_contains "$still" "other.txt" "$2: the other staged file is still staged"
}
TMPDIR_ONLY="$(mktemp -d 2>/dev/null || mktemp -d -t mb-commit-only)"; ALL_TMPDIRS+=("$TMPDIR_ONLY")
setup_test_project "$TMPDIR_ONLY/sh"
echo other > "$TMPDIR_ONLY/sh/other.txt"; git -C "$TMPDIR_ONLY/sh" add other.txt
echo "# uncommitted entry" >> "$TMPDIR_ONLY/sh/memory-bank/progress.md"
output=$(cd "$TMPDIR_ONLY/sh" && echo y | MB_HOME="$REPO_ROOT" bash "$MB" commit 2>&1)
assert_exit_zero $? "only memory-bank/: mb commit succeeds"
check_only_mb "$TMPDIR_ONLY/sh" "bash"
if [ "$PWSH_USABLE" = "1" ]; then
    setup_test_project "$TMPDIR_ONLY/ps"
    echo other > "$TMPDIR_ONLY/ps/other.txt"; git -C "$TMPDIR_ONLY/ps" add other.txt
    echo "# uncommitted entry" >> "$TMPDIR_ONLY/ps/memory-bank/progress.md"
    ps_commit_in "$TMPDIR_ONLY/ps" y
    assert_equals "$ps_rc" "0" "pwsh only memory-bank/: mb commit succeeds"
    check_only_mb "$TMPDIR_ONLY/ps" "pwsh"
fi

# ── A commit git refuses is not reported as "Committed!" ─────────────────────
# WHY: mb.ps1 printed "Committed!" and exited 0 whatever `git commit` returned, so a pre-commit
# hook rejection read as success. mb.sh was saved only by `set -e`; it is asserted too so the two
# stay in step if that ever changes.
echo ""
echo "--- git commit rejected by a hook: reported as a failure ---"
TMPDIR_REJ="$(mktemp -d 2>/dev/null || mktemp -d -t mb-commit-rej)"; ALL_TMPDIRS+=("$TMPDIR_REJ")
setup_test_project "$TMPDIR_REJ"
mkdir -p "$TMPDIR_REJ/.rejecting-hooks"
printf '#!/bin/sh\necho HOOK-REJECTED\nexit 1\n' > "$TMPDIR_REJ/.rejecting-hooks/pre-commit"
chmod +x "$TMPDIR_REJ/.rejecting-hooks/pre-commit"
git -C "$TMPDIR_REJ" config core.hooksPath .rejecting-hooks
echo "# uncommitted entry" >> "$TMPDIR_REJ/memory-bank/progress.md"
output=$(cd "$TMPDIR_REJ" && echo y | MB_HOME="$REPO_ROOT" bash "$MB" commit 2>&1)
rc=$?
assert_exit_nonzero "$rc" "rejected commit: mb commit exits non-zero"
assert_contains "$output" "HOOK-REJECTED" "rejected commit: the hook really ran (not a vacuous pass)"
assert_not_contains "$output" "Committed!" "rejected commit: does not claim success"
if [ "$PWSH_USABLE" = "1" ]; then
    ps_commit_in "$TMPDIR_REJ" y
    assert_exit_nonzero "$ps_rc" "pwsh rejected commit: exits non-zero — matches mb.sh"
    assert_contains "$ps_out" "HOOK-REJECTED" "pwsh rejected commit: the hook really ran"
    assert_not_contains "$ps_out" "Committed!" "pwsh rejected commit: does not claim success"
fi

# ── Mid-merge: git refuses a partial commit, and mb commit says so ───────────
# WHY: with the bare `git commit` this used to be, running mb commit mid-merge committed the WHOLE
# merge as "chore: Update Memory Bank context". With the pathspec, git refuses ("cannot do a
# partial commit during a merge") and the merge must be left in progress, not concluded.
echo ""
echo "--- mid-merge: refused loudly, merge left in progress ---"
merge_fixture() { # $1 = dir: a repo stopped in a resolved-but-uncommitted merge, memory-bank dirty
    setup_test_project "$1"
    (
        cd "$1" || exit 1
        base=$(git symbolic-ref --short HEAD)
        git checkout -q -b side && echo side > code.txt && git add code.txt && git commit -q -m side
        git checkout -q "$base" && echo main > code.txt && git add code.txt && git commit -q -m main
        git merge -q --no-edit side > /dev/null 2>&1
        echo resolved > code.txt && git add code.txt
        echo "# uncommitted entry" >> memory-bank/progress.md
    )
}
TMPDIR_MERGE="$(mktemp -d 2>/dev/null || mktemp -d -t mb-commit-merge)"; ALL_TMPDIRS+=("$TMPDIR_MERGE")
merge_fixture "$TMPDIR_MERGE/sh"
assert_file_exists "$TMPDIR_MERGE/sh/.git/MERGE_HEAD" "mid-merge fixture: merge in progress"
output=$(cd "$TMPDIR_MERGE/sh" && echo y | MB_HOME="$REPO_ROOT" bash "$MB" commit 2>&1)
rc=$?
assert_equals "$rc" "1" "mid-merge: mb commit exits 1"
assert_contains "$output" "NOT committed" "mid-merge: says nothing was committed"
assert_file_exists "$TMPDIR_MERGE/sh/.git/MERGE_HEAD" "mid-merge: the merge is still in progress, not concluded"
if [ "$PWSH_USABLE" = "1" ]; then
    merge_fixture "$TMPDIR_MERGE/ps"
    ps_commit_in "$TMPDIR_MERGE/ps" y
    assert_equals "$ps_rc" "1" "pwsh mid-merge: exits 1 — matches mb.sh"
    assert_contains "$ps_out" "NOT committed" "pwsh mid-merge: says nothing was committed"
    assert_file_exists "$TMPDIR_MERGE/ps/.git/MERGE_HEAD" "pwsh mid-merge: the merge is still in progress"
fi

print_summary
