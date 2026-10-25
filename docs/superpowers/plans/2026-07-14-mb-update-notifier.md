# mb Update-Notifier Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make `mb` check whether a newer PMB version is available on every invocation (not just inside `mb upgrade`), using a cached, rate-limited, fail-open check — never a live network call on every command.

**Architecture:** A shared helper (`get_cached_pmb_version` in `mb.sh`, `Get-CachedPmbVersion` in `mb.ps1`) reads/writes a local JSON cache (`~/.mb/version-check-cache.json`, TTL 7 days). `Invoke-Upgrade`/`invoke_upgrade` is refactored to call this helper instead of its own inline fetch (behavior-preserving). A new check runs once at the very end of the main script, after command dispatch, for every command except `upgrade` and `help`, printing a single `[NOTICE]` line if the cache shows PMB is behind.

**Tech Stack:** POSIX `sh`, PowerShell 7 (`pwsh`), `curl`/`Invoke-WebRequest`, `python3` (bash-side JSON parsing only, matching existing convention), bash test harness (`tests/helpers/assert.sh`), `python3 -m http.server` for the one test that needs a real HTTP fetch.

---

### Task 1: Bash helper implementation + core test suite

**Files:**
- Modify: `scripts/mb.sh`
- Create: `tests/test-mb-version-notifier.sh`

- [ ] **Step 1: Write the test file**

Create `tests/test-mb-version-notifier.sh` with this exact content:

```sh
#!/usr/bin/env bash
# tests/test-mb-version-notifier.sh — regression test for the mb update-notifier
#
# WHY this test exists: mb only checked for a newer PMB version inside `mb upgrade`
# itself. This suite proves the new cached, rate-limited, fail-open check works
# correctly: cache hit shows a NOTICE without a network call, matching versions
# show nothing, an unreachable remote fails open silently, upgrade/help never
# double-print the generic NOTICE (upgrade has its own WARN), and a real fetch
# correctly populates the cache.
set -u

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$REPO_ROOT/tests/helpers/assert.sh"
source "$REPO_ROOT/tests/setup.sh"

echo "=== mb version-notifier tests ==="

MB="$REPO_ROOT/scripts/mb.sh"

# ── cache hit, versions differ → NOTICE shown ────────────────────────────────
echo ""
echo "--- cache hit: stale version shows [NOTICE] ---"
TMPDIR_HIT="$(mktemp -d 2>/dev/null || mktemp -d -t mb-vn-test)"
trap 'rm -rf "$TMPDIR_HIT"' EXIT
setup_test_project "$TMPDIR_HIT"
mkdir -p "$TMPDIR_HIT/.mb"
NOW_EPOCH=$(date +%s)
printf '{"checkedAtEpoch":%s,"remoteVersion":"9.9.9"}' "$NOW_EPOCH" > "$TMPDIR_HIT/.mb/version-check-cache.json"
cd "$TMPDIR_HIT" || exit 1
output=$(MB_HOME="$REPO_ROOT" MB_VERSION_CACHE_DIR="$TMPDIR_HIT/.mb" bash "$MB" status 2>&1)
cd - > /dev/null || exit 1
assert_contains "$output" "[NOTICE]" "mb.sh: cache hit with differing version prints [NOTICE]"
assert_contains "$output" "9.9.9" "mb.sh: [NOTICE] mentions the cached remote version"

# ── cache hit, versions match → no NOTICE ────────────────────────────────────
echo ""
echo "--- cache hit: matching version shows nothing ---"
TMPDIR_MATCH="$(mktemp -d 2>/dev/null || mktemp -d -t mb-vn-test)"
trap 'rm -rf "$TMPDIR_MATCH"' EXIT
setup_test_project "$TMPDIR_MATCH"
mkdir -p "$TMPDIR_MATCH/.mb"
LOCAL_VER=$(tr -d '[:space:]' < "$REPO_ROOT/VERSION")
printf '{"checkedAtEpoch":%s,"remoteVersion":"%s"}' "$NOW_EPOCH" "$LOCAL_VER" > "$TMPDIR_MATCH/.mb/version-check-cache.json"
cd "$TMPDIR_MATCH" || exit 1
output=$(MB_HOME="$REPO_ROOT" MB_VERSION_CACHE_DIR="$TMPDIR_MATCH/.mb" bash "$MB" status 2>&1)
cd - > /dev/null || exit 1
assert_not_contains "$output" "[NOTICE]" "mb.sh: cache hit with matching version prints no [NOTICE]"

# ── unreachable remote → fails open silently ─────────────────────────────────
echo ""
echo "--- no cache, unreachable remote: fails open, no crash ---"
TMPDIR_UNREACH="$(mktemp -d 2>/dev/null || mktemp -d -t mb-vn-test)"
trap 'rm -rf "$TMPDIR_UNREACH"' EXIT
setup_test_project "$TMPDIR_UNREACH"
cd "$TMPDIR_UNREACH" || exit 1
output=$(MB_HOME="$REPO_ROOT" MB_VERSION_CACHE_DIR="$TMPDIR_UNREACH/.mb" MB_VERSION_CHECK_URL="http://127.0.0.1:1/VERSION" bash "$MB" status 2>&1)
exit_code=$?
cd - > /dev/null || exit 1
assert_not_contains "$output" "[NOTICE]" "mb.sh: unreachable remote prints no [NOTICE]"
assert_exit_zero "$exit_code" "mb.sh: unreachable remote does not fail the command"

# ── mb upgrade never double-prints the generic [NOTICE] ──────────────────────
echo ""
echo "--- mb upgrade suppresses the generic [NOTICE] ---"
TMPDIR_UPG="$(mktemp -d 2>/dev/null || mktemp -d -t mb-vn-test)"
trap 'rm -rf "$TMPDIR_UPG"' EXIT
setup_test_project "$TMPDIR_UPG"
mkdir -p "$TMPDIR_UPG/.mb"
printf '{"checkedAtEpoch":%s,"remoteVersion":"9.9.9"}' "$NOW_EPOCH" > "$TMPDIR_UPG/.mb/version-check-cache.json"
cd "$TMPDIR_UPG" || exit 1
output=$(MB_HOME="$REPO_ROOT" MB_VERSION_CACHE_DIR="$TMPDIR_UPG/.mb" bash "$MB" upgrade 2>&1)
cd - > /dev/null || exit 1
assert_not_contains "$output" "[NOTICE]" "mb.sh: mb upgrade suppresses the generic [NOTICE] (it has its own WARN)"

# ── mb help suppresses the generic [NOTICE] ──────────────────────────────────
echo ""
echo "--- mb help suppresses the generic [NOTICE] ---"
TMPDIR_HELP="$(mktemp -d 2>/dev/null || mktemp -d -t mb-vn-test)"
trap 'rm -rf "$TMPDIR_HELP"' EXIT
setup_test_project "$TMPDIR_HELP"
mkdir -p "$TMPDIR_HELP/.mb"
printf '{"checkedAtEpoch":%s,"remoteVersion":"9.9.9"}' "$NOW_EPOCH" > "$TMPDIR_HELP/.mb/version-check-cache.json"
cd "$TMPDIR_HELP" || exit 1
output=$(MB_HOME="$REPO_ROOT" MB_VERSION_CACHE_DIR="$TMPDIR_HELP/.mb" bash "$MB" help 2>&1)
cd - > /dev/null || exit 1
assert_not_contains "$output" "[NOTICE]" "mb.sh: mb help suppresses the generic [NOTICE]"

# ── real fetch populates the cache correctly ─────────────────────────────────
echo ""
if command -v python3 >/dev/null 2>&1; then
  echo "--- live fetch: populates cache with the served version ---"
  TMPDIR_FETCH="$(mktemp -d 2>/dev/null || mktemp -d -t mb-vn-test)"
  trap 'rm -rf "$TMPDIR_FETCH"' EXIT
  setup_test_project "$TMPDIR_FETCH"
  SRVDIR="$(mktemp -d 2>/dev/null || mktemp -d -t mb-vn-srv)"
  echo "7.7.7" > "$SRVDIR/VERSION"
  PORT=18734
  (cd "$SRVDIR" && python3 -m http.server "$PORT" >/dev/null 2>&1) &
  SRV_PID=$!
  trap 'kill "$SRV_PID" 2>/dev/null; rm -rf "$TMPDIR_FETCH" "$SRVDIR"' EXIT
  sleep 1
  cd "$TMPDIR_FETCH" || exit 1
  output=$(MB_HOME="$REPO_ROOT" MB_VERSION_CACHE_DIR="$TMPDIR_FETCH/.mb" MB_VERSION_CHECK_URL="http://127.0.0.1:$PORT/VERSION" bash "$MB" status 2>&1)
  cd - > /dev/null || exit 1
  kill "$SRV_PID" 2>/dev/null
  assert_contains "$output" "[NOTICE]" "mb.sh: live fetch shows [NOTICE] for the served version"
  assert_contains "$output" "7.7.7" "mb.sh: [NOTICE] mentions the fetched version"
  assert_file_exists "$TMPDIR_FETCH/.mb/version-check-cache.json" "mb.sh: live fetch writes the cache file"
  cache_content=$(cat "$TMPDIR_FETCH/.mb/version-check-cache.json")
  assert_contains "$cache_content" "7.7.7" "mb.sh: cache file contains the fetched version"
else
  echo "--- live fetch test: SKIPPED (python3 not installed on this machine) ---"
fi

print_summary
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `cd "C:\Users\Mizzo\Claude\Personal-Memory-Bank" && bash tests/test-mb-version-notifier.sh`

Expected: most assertions fail — `mb.sh` doesn't recognize `MB_VERSION_CACHE_DIR`/`MB_VERSION_CHECK_URL` yet and never prints `[NOTICE]`. Confirm at least one `FAIL:` line in the output.

- [ ] **Step 3: Implement the bash helper**

In `scripts/mb.sh`, find the existing remote-version-check block inside `invoke_upgrade` (currently at line 1575, immediately after the `TEMPLATES_DIR` existence check):

```sh
    # Remote version check — soft warning, never blocks upgrade
    if [ -f "$REPO_ROOT/VERSION" ]; then
        LOCAL_VERSION=$(tr -d '[:space:]' < "$REPO_ROOT/VERSION")
        if command -v curl >/dev/null 2>&1; then
            REMOTE_VERSION=$(curl -sf --max-time 3 \
                "https://raw.githubusercontent.com/unyieldingclaw-dev/personal-memory-bank/main/VERSION" \
                2>/dev/null | tr -d '[:space:]' || true)
            if [ -n "$REMOTE_VERSION" ] && [ "$REMOTE_VERSION" != "$LOCAL_VERSION" ]; then
                echo -e "${YELLOW}[WARN] PMB $LOCAL_VERSION installed locally, $REMOTE_VERSION available${NC}"
                echo -e "${YELLOW}       Consider updating PMB: https://github.com/unyieldingclaw-dev/personal-memory-bank${NC}"
                echo ""
            elif [ -z "$REMOTE_VERSION" ]; then
                echo -e "${GRAY}[INFO] Remote version check skipped (unreachable)${NC}"
            fi
        fi
    fi
```

Replace it with a call to a new shared helper:

```sh
    # Remote version check — soft warning, never blocks upgrade
    get_cached_pmb_version
    if [ -n "$REMOTE_VERSION" ] && [ -n "$LOCAL_VERSION" ] && [ "$REMOTE_VERSION" != "$LOCAL_VERSION" ]; then
        echo -e "${YELLOW}[WARN] PMB $LOCAL_VERSION installed locally, $REMOTE_VERSION available${NC}"
        echo -e "${YELLOW}       Consider updating PMB: https://github.com/unyieldingclaw-dev/personal-memory-bank${NC}"
        echo ""
    elif [ -n "$LOCAL_VERSION" ] && [ -z "$REMOTE_VERSION" ]; then
        echo -e "${GRAY}[INFO] Remote version check skipped (unreachable)${NC}"
    fi
```

Now add the `get_cached_pmb_version` function itself. Place it near the top of `scripts/mb.sh`, immediately after the `REPO_ROOT`/color-variable setup (find the line `TEMPLATES_DIR=` is first referenced near the top of the file, or any convenient point before `invoke_upgrade` is defined — function definitions in bash just need to exist before they're *called*, not before their location in the file, but for readability place it near the other shared helpers):

```sh
# get_cached_pmb_version — sets LOCAL_VERSION and REMOTE_VERSION.
#
# WHY a shared helper instead of inlining in invoke_upgrade: the same check now
# also runs once after every command (see the notifier block near the end of
# this file), not just inside `mb upgrade`. One helper, one cache, one place to
# get the TTL/fail-open logic right.
#
# WHY cached with a TTL instead of a live fetch every call: a live network call
# on every single mb invocation would be slow and flaky. Caching for 7 days
# means the check is nearly free on every call except roughly once a week.
#
# WHY MB_VERSION_CACHE_DIR / MB_VERSION_CHECK_URL env var overrides: lets tests
# point this at a temp dir and a local/unreachable URL instead of the real
# user cache and the real GitHub URL. Production code paths never need to set
# these; they default to the real values.
#
# WHY python3 for JSON parsing here: matches this repo's existing convention
# (check-contract.sh, update-reviewed.sh) of using python3 as the bash-side
# JSON parser, with graceful degradation if it's missing.
#
# WHY fail open (leave REMOTE_VERSION empty) on any error — missing python3,
# unreachable network, malformed cache: this is an optional notice, never a
# gate. A broken check must never block or slow down real work.
get_cached_pmb_version() {
    LOCAL_VERSION=""
    REMOTE_VERSION=""
    [ -f "$REPO_ROOT/VERSION" ] || return 0
    LOCAL_VERSION=$(tr -d '[:space:]' < "$REPO_ROOT/VERSION")

    CACHE_DIR="${MB_VERSION_CACHE_DIR:-$HOME/.mb}"
    CACHE_FILE="$CACHE_DIR/version-check-cache.json"
    CHECK_URL="${MB_VERSION_CHECK_URL:-https://raw.githubusercontent.com/unyieldingclaw-dev/personal-memory-bank/main/VERSION}"
    NOW_EPOCH=$(date +%s)

    if [ -f "$CACHE_FILE" ] && command -v python3 >/dev/null 2>&1; then
        CACHED_EPOCH=$(python3 -c "
import json
try:
    print(json.load(open('$CACHE_FILE')).get('checkedAtEpoch', 0))
except Exception:
    print(0)
" 2>/dev/null || echo 0)
        AGE_SECONDS=$(( NOW_EPOCH - CACHED_EPOCH ))
        if [ "$AGE_SECONDS" -lt 604800 ] 2>/dev/null; then
            REMOTE_VERSION=$(python3 -c "
import json
try:
    print(json.load(open('$CACHE_FILE')).get('remoteVersion', ''))
except Exception:
    print('')
" 2>/dev/null || true)
            [ -n "$REMOTE_VERSION" ] && return 0
        fi
    fi

    if command -v curl >/dev/null 2>&1; then
        REMOTE_VERSION=$(curl -sf --max-time 2 "$CHECK_URL" 2>/dev/null | tr -d '[:space:]' || true)
        if [ -n "$REMOTE_VERSION" ]; then
            mkdir -p "$CACHE_DIR" 2>/dev/null || true
            printf '{"checkedAtEpoch":%s,"remoteVersion":"%s"}' "$NOW_EPOCH" "$REMOTE_VERSION" > "$CACHE_FILE" 2>/dev/null || true
        fi
    fi
}
```

- [ ] **Step 4: Add the end-of-script notifier**

Find the end of `scripts/mb.sh`'s `case "$COMMAND" in ... esac` block (the final `esac` in the file). Immediately after it, add:

```sh

# Update notifier — runs after every command except upgrade (has its own WARN
# above) and help (no need to nag on a bare help lookup). Cached/fail-open via
# get_cached_pmb_version — see that function's WHY comments for the reasoning.
if [ "$COMMAND" != "upgrade" ] && [ "$COMMAND" != "help" ]; then
    get_cached_pmb_version
    if [ -n "$REMOTE_VERSION" ] && [ -n "$LOCAL_VERSION" ] && [ "$REMOTE_VERSION" != "$LOCAL_VERSION" ]; then
        echo -e "${YELLOW}[NOTICE] PMB $LOCAL_VERSION installed, $REMOTE_VERSION available — run: mb upgrade${NC}"
    fi
fi
```

- [ ] **Step 5: Run the test to verify it passes**

Run: `cd "C:\Users\Mizzo\Claude\Personal-Memory-Bank" && bash tests/test-mb-version-notifier.sh`

Expected: `Results: N passed, 0 failed` (the live-fetch test only runs if `python3` is available on this machine — it is, so it should run and pass too).

- [ ] **Step 6: Commit**

```bash
cd "C:\Users\Mizzo\Claude\Personal-Memory-Bank"
git add scripts/mb.sh tests/test-mb-version-notifier.sh
git commit -m "feat: add cached update-notifier to mb.sh"
```

---

### Task 2: PowerShell helper implementation

**Files:**
- Modify: `scripts/mb.ps1`
- Modify: `tests/test-mb-version-notifier.sh` (add cross-shell parity assertions — the bash version is already correct from Task 1)

- [ ] **Step 1: Add PowerShell parity assertions to the test file**

Add this block to `tests/test-mb-version-notifier.sh`, immediately before the final `print_summary` call:

```sh
# ── cross-shell parity (PowerShell) ──────────────────────────────────────────
if command -v pwsh >/dev/null 2>&1; then
  echo ""
  echo "--- cross-shell parity: mb.ps1 cache hit shows [NOTICE] ---"
  TMPDIR_PS1="$(mktemp -d 2>/dev/null || mktemp -d -t mb-vn-ps1)"
  trap 'rm -rf "$TMPDIR_PS1"' EXIT
  setup_test_project "$TMPDIR_PS1"
  mkdir -p "$TMPDIR_PS1/.mb"
  printf '{"checkedAtEpoch":%s,"remoteVersion":"9.9.9"}' "$(date +%s)" > "$TMPDIR_PS1/.mb/version-check-cache.json"
  cd "$TMPDIR_PS1" || exit 1
  output=$(MB_HOME="$REPO_ROOT" MB_VERSION_CACHE_DIR="$TMPDIR_PS1/.mb" pwsh -NoLogo -File "$REPO_ROOT/scripts/mb.ps1" status 2>&1)
  cd - > /dev/null || exit 1
  assert_contains "$output" "[NOTICE]" "mb.ps1: cache hit with differing version prints [NOTICE]"
  assert_contains "$output" "9.9.9" "mb.ps1: [NOTICE] mentions the cached remote version"

  echo ""
  echo "--- cross-shell parity: mb.ps1 upgrade suppresses the generic [NOTICE] ---"
  TMPDIR_PS1U="$(mktemp -d 2>/dev/null || mktemp -d -t mb-vn-ps1u)"
  trap 'rm -rf "$TMPDIR_PS1U"' EXIT
  setup_test_project "$TMPDIR_PS1U"
  mkdir -p "$TMPDIR_PS1U/.mb"
  printf '{"checkedAtEpoch":%s,"remoteVersion":"9.9.9"}' "$(date +%s)" > "$TMPDIR_PS1U/.mb/version-check-cache.json"
  cd "$TMPDIR_PS1U" || exit 1
  output=$(MB_HOME="$REPO_ROOT" MB_VERSION_CACHE_DIR="$TMPDIR_PS1U/.mb" pwsh -NoLogo -File "$REPO_ROOT/scripts/mb.ps1" upgrade 2>&1)
  cd - > /dev/null || exit 1
  assert_not_contains "$output" "[NOTICE]" "mb.ps1: mb upgrade suppresses the generic [NOTICE]"
else
  echo ""
  echo "--- mb.ps1 tests: SKIPPED (pwsh not installed on this machine) ---"
fi
```

- [ ] **Step 2: Run the test to verify the new PowerShell assertions fail**

Run: `cd "C:\Users\Mizzo\Claude\Personal-Memory-Bank" && bash tests/test-mb-version-notifier.sh`

Expected: the two new `cross-shell parity` assertions show `FAIL:` (mb.ps1 doesn't recognize `MB_VERSION_CACHE_DIR` yet). All Task 1 assertions still pass.

- [ ] **Step 3: Implement the PowerShell helper**

In `scripts/mb.ps1`, find the existing remote-version-check block inside `Invoke-Upgrade` (currently at line 1851, immediately after the `Templates not found` existence check):

```powershell
    # Remote version check — soft warning, never blocks upgrade
    $versionFile = Join-Path $RepoRoot "VERSION"
    if (Test-Path $versionFile) {
        $localVersion = (Get-Content $versionFile -Raw).Trim()
        try {
            $response = Invoke-WebRequest `
                -Uri "https://raw.githubusercontent.com/unyieldingclaw-dev/personal-memory-bank/main/VERSION" `
                -TimeoutSec 3 -UseBasicParsing -ErrorAction Stop
            $remoteVersion = $response.Content.Trim()
            if ($remoteVersion -ne $localVersion) {
                Write-Host "[WARN] PMB $localVersion installed locally, $remoteVersion available" -ForegroundColor Yellow
                Write-Host "       Consider updating PMB: https://github.com/unyieldingclaw-dev/personal-memory-bank" -ForegroundColor Yellow
                Write-Host ""
            }
        } catch {
            Write-Host "[INFO] Remote version check skipped (unreachable)" -ForegroundColor DarkGray
        }
    }
```

Replace it with a call to a new shared helper:

```powershell
    # Remote version check — soft warning, never blocks upgrade
    Get-CachedPmbVersion
    if ($script:PmbRemoteVersion -and $script:PmbLocalVersion -and $script:PmbRemoteVersion -ne $script:PmbLocalVersion) {
        Write-Host "[WARN] PMB $($script:PmbLocalVersion) installed locally, $($script:PmbRemoteVersion) available" -ForegroundColor Yellow
        Write-Host "       Consider updating PMB: https://github.com/unyieldingclaw-dev/personal-memory-bank" -ForegroundColor Yellow
        Write-Host ""
    } elseif ($script:PmbLocalVersion -and -not $script:PmbRemoteVersion) {
        Write-Host "[INFO] Remote version check skipped (unreachable)" -ForegroundColor DarkGray
    }
```

Now add the `Get-CachedPmbVersion` function. Place it near the other shared helper functions at the top of the file, immediately after the `Get-MbMode` function (around line 58):

```powershell
# Get-CachedPmbVersion — sets $script:PmbLocalVersion and $script:PmbRemoteVersion.
#
# WHY a shared helper instead of inlining in Invoke-Upgrade: the same check now
# also runs once after every command (see the notifier block near the end of
# this file), not just inside `mb upgrade`. One helper, one cache, one place to
# get the TTL/fail-open logic right.
#
# WHY cached with a TTL instead of a live fetch every call: a live network call
# on every single mb invocation would be slow and flaky. Caching for 7 days
# means the check is nearly free on every call except roughly once a week.
#
# WHY $env:MB_VERSION_CACHE_DIR / $env:MB_VERSION_CHECK_URL overrides: lets
# tests point this at a temp dir and a local/unreachable URL instead of the
# real user cache and the real GitHub URL. Production code paths never need to
# set these; they default to the real values.
#
# WHY fail open (leave $script:PmbRemoteVersion empty) on any error — network
# unreachable, malformed cache JSON: this is an optional notice, never a gate.
# A broken check must never block or slow down real work.
function Get-CachedPmbVersion {
    $script:PmbLocalVersion = $null
    $script:PmbRemoteVersion = $null

    $versionFile = Join-Path $RepoRoot "VERSION"
    if (-not (Test-Path $versionFile)) { return }
    $script:PmbLocalVersion = (Get-Content $versionFile -Raw).Trim()

    $cacheDir = if ($env:MB_VERSION_CACHE_DIR) { $env:MB_VERSION_CACHE_DIR } else { Join-Path $env:USERPROFILE ".mb" }
    $cacheFile = Join-Path $cacheDir "version-check-cache.json"
    $checkUrl = if ($env:MB_VERSION_CHECK_URL) { $env:MB_VERSION_CHECK_URL } else { "https://raw.githubusercontent.com/unyieldingclaw-dev/personal-memory-bank/main/VERSION" }
    $nowEpoch = [DateTimeOffset]::UtcNow.ToUnixTimeSeconds()

    if (Test-Path $cacheFile) {
        try {
            $cache = Get-Content $cacheFile -Raw | ConvertFrom-Json -ErrorAction Stop
            $ageSeconds = $nowEpoch - [int64]$cache.checkedAtEpoch
            if ($ageSeconds -lt 604800 -and $cache.remoteVersion) {
                $script:PmbRemoteVersion = $cache.remoteVersion
                return
            }
        } catch {
            # WHY silent: a malformed cache file just means we fall through to
            # a fresh fetch below, same as a missing cache file.
        }
    }

    try {
        $response = Invoke-WebRequest -Uri $checkUrl -TimeoutSec 2 -UseBasicParsing -ErrorAction Stop
        $script:PmbRemoteVersion = $response.Content.Trim()
        if ($script:PmbRemoteVersion) {
            if (-not (Test-Path $cacheDir)) { New-Item -ItemType Directory -Path $cacheDir -Force | Out-Null }
            @{ checkedAtEpoch = $nowEpoch; remoteVersion = $script:PmbRemoteVersion } | ConvertTo-Json -Compress | Set-Content $cacheFile
        }
    } catch {
        $script:PmbRemoteVersion = $null
    }
}
```

- [ ] **Step 4: Add the end-of-script notifier**

Find the end of `scripts/mb.ps1`'s `switch ($Command) { ... }` block (the final closing `}` of that switch, currently around line 2501). Immediately after it, add:

```powershell

# Update notifier — runs after every command except upgrade (has its own WARN
# above) and help (no need to nag on a bare help lookup). Cached/fail-open via
# Get-CachedPmbVersion — see that function's WHY comments for the reasoning.
if ($Command -ne "upgrade" -and $Command -ne "help") {
    Get-CachedPmbVersion
    if ($script:PmbRemoteVersion -and $script:PmbLocalVersion -and $script:PmbRemoteVersion -ne $script:PmbLocalVersion) {
        Write-Host "[NOTICE] PMB $($script:PmbLocalVersion) installed, $($script:PmbRemoteVersion) available — run: mb upgrade" -ForegroundColor Yellow
    }
}
```

- [ ] **Step 5: Run the full test suite to verify it passes**

Run: `cd "C:\Users\Mizzo\Claude\Personal-Memory-Bank" && bash tests/test-mb-version-notifier.sh`

Expected: `Results: N passed, 0 failed`, including both cross-shell parity assertions now passing.

- [ ] **Step 6: Commit**

```bash
cd "C:\Users\Mizzo\Claude\Personal-Memory-Bank"
git add scripts/mb.ps1 tests/test-mb-version-notifier.sh
git commit -m "feat: add cached update-notifier to mb.ps1"
```

---

### Task 3: Register the test suite and run full verification

**Files:**
- Modify: `tests/run.sh`

- [ ] **Step 1: Add the new test suite registration**

In `tests/run.sh`, find this line:

```
run_suite "review-reminders"     "$REPO_ROOT/tests/test-review-reminders.sh"
```

Add immediately after it:

```
run_suite "mb-version-notifier"  "$REPO_ROOT/tests/test-mb-version-notifier.sh"
```

- [ ] **Step 2: Run the full test suite**

Run: `cd "C:\Users\Mizzo\Claude\Personal-Memory-Bank" && bash tests/run.sh`

Expected: every existing suite still passes, and a new `mb-version-notifier` suite section appears with `Results: N passed, 0 failed`.

- [ ] **Step 3: Manually verify the notice against the real command line (not just the test harness)**

Run this to confirm end-to-end wiring against a throwaway project, using a fake stale cache so no real network call is needed:

```bash
cd "C:\Users\Mizzo\Claude\Personal-Memory-Bank"
TESTDIR=$(mktemp -d)
mkdir -p "$TESTDIR/memory-bank" "$TESTDIR/.mb"
echo '{"checkedAtEpoch":'"$(date +%s)"',"remoteVersion":"99.0.0"}' > "$TESTDIR/.mb/version-check-cache.json"
cd "$TESTDIR"
MB_HOME="C:\Users\Mizzo\Claude\Personal-Memory-Bank" MB_VERSION_CACHE_DIR="$TESTDIR/.mb" bash "C:\Users\Mizzo\Claude\Personal-Memory-Bank\scripts\mb.sh" status
cd - > /dev/null
rm -rf "$TESTDIR"
```

Expected: normal `mb status` output, followed by a line reading
`[NOTICE] PMB <current-version> installed, 99.0.0 available — run: mb upgrade`.

- [ ] **Step 4: Commit**

```bash
cd "C:\Users\Mizzo\Claude\Personal-Memory-Bank"
git add tests/run.sh
git commit -m "test: register mb-version-notifier suite in tests/run.sh"
```

---

## Final Verification (run after all tasks complete)

1. `cd "C:\Users\Mizzo\Claude\Personal-Memory-Bank" && bash tests/run.sh` — full suite passes, including `mb-version-notifier`.
2. Confirm `mb upgrade` on this repo still shows its own `[WARN]`/`[INFO]` messages correctly (manually run `mb upgrade --dry-run` from this repo and check output is unchanged in format from before this plan).
3. Confirm `mb help` prints no `[NOTICE]` under any cache state (already covered by Step 5 of Task 1's test, but worth a manual sanity run: `bash scripts/mb.sh help`).
4. Confirm a completely fresh project (no `.mb/` cache directory at all, real network reachable) shows either a correct `[NOTICE]` or nothing (if already current) on first-ever `mb status` — this is the one path the automated tests don't exercise against the real GitHub URL. Run manually once, expect no crash either way.
