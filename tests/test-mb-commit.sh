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

print_summary
