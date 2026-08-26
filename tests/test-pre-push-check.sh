#!/usr/bin/env bash
# tests/test-pre-push-check.sh — tests for the pre-push gate's three-state result model.
#
# WHY this suite exists: pre-push-check.sh had NO test coverage, and shipped a check that
# reported "[OK] mb validate passed" on every push while validating nothing. The defect
# survived because nothing asserted the relationship between what the checks found and
# what the summary claimed. These tests assert exactly that relationship.
#
# WHY every `[TAG]` in an assertion is escaped as `\[TAG\]`: assert_contains uses
# `grep -qi "$pattern"`, so the pattern is a BASIC REGEX, not a literal string. Unescaped,
# `[WARN]` is a character class matching one of W/A/R/N — which makes bracketed
# assertions silently unreliable in BOTH directions. `[BLOCKED]` matches any output
# containing B, L, O, C, K, E or D (a spurious PASS), while `[WARN] Uncommitted` can
# never match, because the real output has `]` where the class expects a single letter
# (a spurious FAIL). Both were observed while writing this suite. Do not "simplify"
# these back to bare brackets.
set -e

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
HOOK="$REPO_ROOT/scripts/pre-push-check.sh"
# shellcheck source=tests/helpers/assert.sh
source "$REPO_ROOT/tests/helpers/assert.sh"

echo "=== pre-push-check tests ==="

TMPDIR_PP="$(mktemp -d 2>/dev/null || mktemp -d -t mb-pp-test)"
trap 'rm -rf "$TMPDIR_PP"' EXIT

# A clean repo with a committed file, .gitattributes present, and no remote.
# WHY no remote: the secret scan then takes its "no upstream" path, which is the
# branch a first push would hit — the case most likely to be skipped silently.
make_clean_repo() {
    local d="$1"
    mkdir -p "$d"
    (
        cd "$d"
        git init -q 2>/dev/null
        git config user.email "test@example.com"
        git config user.name "Test"
        git config commit.gpgsign false
        printf '* text=auto eol=lf\n' > .gitattributes
        printf 'hello\n' > file.txt
        git add -A
        git commit -qm "initial" 2>/dev/null
    )
}

# WHY PATH is rebuilt around git rather than blanked: an earlier version of this helper
# used PATH="/usr/bin:/bin" to hide `mb`, which also hid `git`. Checks 1, 2, 3, 5 and 6
# all guard their git calls with `|| true`, so they silently no-op'd and the suite
# reported failures that were artifacts of the harness. Keep git reachable; control only
# the presence and behaviour of `mb`.
GIT_DIR_PATH="$(dirname "$(command -v git)")"

# Run the hook with `mb` guaranteed ABSENT.
# WHY the precondition is asserted rather than assumed: this fixture proves "an unrunnable
# check reports UNKNOWN", which is only meaningful if mb is genuinely unreachable. If mb were
# installed somewhere still on the rebuilt PATH (e.g. /usr/bin), the hook would run it, report
# OK, and the UNKNOWN assertions would fail for an environmental reason that looks exactly
# like a code regression. Fail loudly on that instead of producing a misleading result.
run_hook_without_mb() {
    local d="$1"; shift
    local test_path="$GIT_DIR_PATH:/usr/bin:/bin"
    if env PATH="$test_path" sh -c 'command -v mb' >/dev/null 2>&1; then
        echo "FIXTURE ERROR: mb is reachable on the restricted PATH — UNKNOWN tests cannot be trusted." >&2
        return 99
    fi
    (
        cd "$d"
        env PATH="$test_path" "$@" bash "$HOOK" 2>&1
    )
}

# Run the hook with a stub `mb` whose `doctor` output is supplied by the caller.
# This is what lets the dead-shim case be tested directly: a stub that prints a
# redirect notice and exits 0 reproduces exactly the defect this change fixes.
run_hook_with_stub_mb() {
    local d="$1" stub_body="$2"
    local stub_dir="$TMPDIR_PP/stub-$RANDOM"
    mkdir -p "$stub_dir"
    {
        printf '#!/usr/bin/env bash\n'
        printf '%s\n' "$stub_body"
    } > "$stub_dir/mb"
    chmod +x "$stub_dir/mb"
    (
        cd "$d"
        env PATH="$stub_dir:$GIT_DIR_PATH:/usr/bin:/bin" bash "$HOOK" 2>&1
    )
}

# ── UNKNOWN: a check that cannot run must not be reported as passed ──────────
echo ""
echo "--- unverifiable check reports UNKNOWN, never PASS ---"

REPO_A="$TMPDIR_PP/clean"
make_clean_repo "$REPO_A"

output=$(run_hook_without_mb "$REPO_A" || true)
assert_contains "$output" "\[UNKNOWN\]" "mb absent reports UNKNOWN"
assert_contains "$output" "NOT verified" "UNKNOWN states the memory bank was not verified"
assert_contains "$output" "\[DEGRADED\]" "summary reports DEGRADED when a check could not run"

# The regression this suite exists for: the old summary printed this line whenever no
# BLOCKING check failed, even with an unrun check directly above it.
assert_not_contains "$output" "All pre-push checks passed" \
    "summary does NOT claim all checks passed when one could not run"

# ── Advisory warnings must reach the summary ────────────────────────────────
echo ""
echo "--- warnings are not overwritten by a green summary ---"

REPO_B="$TMPDIR_PP/dirty"
make_clean_repo "$REPO_B"
printf 'uncommitted\n' > "$REPO_B/dirty.txt"

output=$(run_hook_without_mb "$REPO_B" || true)
assert_contains "$output" "\[WARN\] Uncommitted changes" "dirty tree warns"
assert_not_contains "$output" "All pre-push checks passed" \
    "summary does NOT claim all checks passed when a warning fired"

# ── ENFORCE opt-in ──────────────────────────────────────────────────────────
# WHY advisory by default: a gate that blocks because a template is stale gets disabled
# within a week. Honest reporting is the default; blocking is opt-in.
echo ""
echo "--- ENFORCE promotes unverified/warned to blocking, default does not ---"

set +e
run_hook_without_mb "$REPO_A" >/dev/null 2>&1
default_exit=$?
run_hook_without_mb "$REPO_A" ENFORCE=true >/dev/null 2>&1
enforce_exit=$?
set -e

assert_exit_zero $default_exit "default run does not block on DEGRADED"
assert_exit_nonzero $enforce_exit "ENFORCE=true blocks on DEGRADED"

# ── Blocking checks still block ─────────────────────────────────────────────
# Guards against the opposite failure: the new state model must not demote a real
# blocking finding into an advisory warning.
#
# This is ALSO the regression test for a secret-scanning bypass. These fixtures have no
# remote, so the scan takes its "no upstream" branch — which used to run
# `git log --not --remotes`, with no positive rev. With no remote-tracking refs there is
# nothing to walk from, so it returned NOTHING and the scan silently passed while
# printing "no commits to push", in exactly the first-push case that branch exists to
# cover. Verified before the fix: 0 diff lines and the planted key undetected. The fix
# names `HEAD` explicitly. If someone removes it, this test fails.
echo ""
echo "--- a genuine blocking finding still blocks (and the no-remote scan actually runs) ---"

REPO_C="$TMPDIR_PP/secret"
make_clean_repo "$REPO_C"
(
    cd "$REPO_C"
    printf 'AKIA%s\n' "ABCDEFGHIJKLMNOP" > leak.txt
    git add -A
    git commit -qm "add key" 2>/dev/null
)

set +e
output=$(run_hook_without_mb "$REPO_C")
blocked_exit=$?
set -e

assert_contains "$output" "\[BLOCKED\]" "secret in push diff blocks"
assert_contains "$output" "AWS access key" "the planted key is named, proving the scan ran"
assert_not_contains "$output" "no unpushed commits found" \
    "no-remote repo does NOT silently skip the secret scan"
assert_exit_nonzero $blocked_exit "blocking finding exits non-zero"
assert_not_contains "$output" "All pre-push checks passed" \
    "blocked run does not also claim all checks passed"

# ── The exact defect: a command that exits 0 while doing nothing ────────────
# This is the regression test for the original bug. The old check called `mb validate`,
# read only its exit code, and printed "[OK] mb validate passed". A stub that prints a
# redirect notice and exits 0 reproduces that precisely.
echo ""
echo "--- a command that exits 0 without running checks is UNKNOWN, not OK ---"

output=$(run_hook_with_stub_mb "$REPO_A" \
    'echo "mb doctor is now part of something else. Run: something"; exit 0' || true)
assert_contains "$output" "\[UNKNOWN\]" "exit-0 no-op reports UNKNOWN"
assert_contains "$output" "no check results" "UNKNOWN explains that no results were emitted"
assert_not_contains "$output" "All pre-push checks passed" \
    "exit-0 no-op does not produce a green summary"

# ── Positive path: real results, no errors ──────────────────────────────────
echo ""
echo "--- structured output with no errors reports OK ---"

output=$(run_hook_with_stub_mb "$REPO_A" \
    'echo "[OK]   Memory Bank v1.2.1"; echo "[OK]   Git repository detected"; exit 0' || true)
assert_contains "$output" "\[OK\]   mb doctor: 2 result lines, no errors" "counts result lines and reports OK"
assert_not_contains "$output" "\[UNKNOWN\]" "a real run is not reported as UNKNOWN"
# Positive assertion of the green summary. Everywhere else this string is asserted ABSENT;
# without this, a bug that never emits it would go unnoticed.
assert_contains "$output" "All pre-push checks passed" \
    "clean repo with a healthy mb DOES report the green summary"

# ── Errors in doctor output surface as a warning ────────────────────────────
# WHY parsed from output rather than exit code: mb doctor exits 0 regardless of what it
# finds, so an exit-code-based check would report success here.
echo ""
echo "--- errors in output surface even though the command exits 0 ---"

output=$(run_hook_with_stub_mb "$REPO_A" \
    'echo "[OK]   Memory Bank v1.2.1"; echo "[ERROR] Startup context too large"; exit 0' || true)
assert_contains "$output" "reported 1 error(s)" "surfaces errors despite exit 0"
assert_contains "$output" "Startup context too large" "echoes the offending line"
assert_not_contains "$output" "All pre-push checks passed" \
    "errors do not produce a green summary"

# ── WARN state, distinct from DEGRADED ──────────────────────────────────────
# Reaching `[PASS with N warning(s)]` requires a healthy mb (so UNKNOWN stays 0) AND a
# warning. Without a stub this path is unreachable, so it went untested in the first draft.
echo ""
echo "--- warnings alone produce PASS-with-warnings, and ENFORCE blocks it ---"

REPO_D="$TMPDIR_PP/warn-only"
make_clean_repo "$REPO_D"
printf 'uncommitted\n' > "$REPO_D/dirty.txt"

HEALTHY_STUB='echo "[OK]   Memory Bank v1.2.1"; exit 0'
output=$(run_hook_with_stub_mb "$REPO_D" "$HEALTHY_STUB" || true)
assert_contains "$output" "PASS with 1 warning" "dirty tree + healthy mb reports PASS with warnings"
assert_not_contains "$output" "\[DEGRADED\]" "a warning is not misreported as DEGRADED"

set +e
run_hook_with_stub_mb "$REPO_D" "$HEALTHY_STUB" >/dev/null 2>&1
warn_default_exit=$?
ENFORCE=true run_hook_with_stub_mb "$REPO_D" "$HEALTHY_STUB" >/dev/null 2>&1
warn_enforce_exit=$?
set -e
assert_exit_zero $warn_default_exit "warnings alone do not block by default"
assert_exit_nonzero $warn_enforce_exit "ENFORCE=true blocks on warnings"

# ── The dead-shim class ─────────────────────────────────────────────────────
# The root defect: a deprecated alias that prints a notice and exits 0 is
# indistinguishable from success to any caller reading only the exit code.
echo ""
echo "--- deprecated redirect shims exit non-zero ---"

MB="$REPO_ROOT/scripts/mb.sh"
set +e
bash "$MB" validate >/dev/null 2>&1
validate_exit=$?
set -e
assert_exit_nonzero $validate_exit "mb validate (dead shim) exits non-zero"

# `update` is a LIVE alias for the upgrade path in mb.sh, not a redirect notice.
# Asserted so a future blanket "make deprecated aliases fail" cannot silently
# break a working command.
assert_contains "$(grep -A1 '^    update)' "$MB" || true)" "invoke_upgrade" \
    "mb update remains a live alias, not a dead shim"

print_summary
