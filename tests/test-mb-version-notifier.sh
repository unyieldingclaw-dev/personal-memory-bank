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

# kill_server_on_port — terminates a background test HTTP server, given both
# bash's $! and the port it's listening on.
#
# WHY not just `kill "$pid"`: on Windows/git-bash, bash's $! for a natively-
# spawned python.exe is an internal MSYS id, not the real Windows PID that
# owns the socket -- `kill`/`kill -9` against it silently no-ops ("process
# not found"), leaving the server bound to the port for the next run.
# Confirmed via direct reproduction: bash $! and the PID netstat reports for
# the same process were different numbers, and taskkill against $! failed.
# Falling back to a netstat-discovered PID + taskkill reliably frees the
# port; this branch is a no-op on POSIX systems, where kill_server_on_port
# already succeeded via bash's own kill above.
kill_server_on_port() {
    pid="$1"
    port="$2"
    kill "$pid" 2>/dev/null
    if command -v taskkill >/dev/null 2>&1 && command -v netstat >/dev/null 2>&1; then
        real_pid=$(netstat -ano 2>/dev/null | grep ":$port " | grep LISTENING | head -1 | awk '{print $NF}')
        [ -n "$real_pid" ] && taskkill //F //PID "$real_pid" >/dev/null 2>&1
    fi
    return 0
}

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
assert_contains "$output" "\[NOTICE\]" "mb.sh: cache hit with differing version prints [NOTICE]"
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
assert_not_contains "$output" "\[NOTICE\]" "mb.sh: cache hit with matching version prints no [NOTICE]"

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
assert_not_contains "$output" "\[NOTICE\]" "mb.sh: unreachable remote prints no [NOTICE]"
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
assert_not_contains "$output" "\[NOTICE\]" "mb.sh: mb upgrade suppresses the generic [NOTICE] (it has its own WARN)"

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
assert_not_contains "$output" "\[NOTICE\]" "mb.sh: mb help suppresses the generic [NOTICE]"

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
  trap 'kill_server_on_port "$SRV_PID" "$PORT"; rm -rf "$TMPDIR_FETCH" "$SRVDIR"' EXIT
  # WHY poll for readiness instead of a fixed sleep: a flat `sleep 1` was
  # observed to be marginal on this Windows/git-bash environment -- the
  # server was already listening (confirmed via netstat) but the first
  # connection attempt still timed out under mb.sh's own 2s --max-time,
  # while an immediate retry succeeded. Polling until the server actually
  # answers removes the race instead of guessing a longer fixed delay.
  for _ in 1 2 3 4 5 6 7 8 9 10; do
    curl -sf --max-time 1 "http://127.0.0.1:$PORT/VERSION" >/dev/null 2>&1 && break
    sleep 0.3
  done
  cd "$TMPDIR_FETCH" || exit 1
  output=$(MB_HOME="$REPO_ROOT" MB_VERSION_CACHE_DIR="$TMPDIR_FETCH/.mb" MB_VERSION_CHECK_URL="http://127.0.0.1:$PORT/VERSION" bash "$MB" status 2>&1)
  cd - > /dev/null || exit 1
  kill_server_on_port "$SRV_PID" "$PORT"
  assert_contains "$output" "\[NOTICE\]" "mb.sh: live fetch shows [NOTICE] for the served version"
  assert_contains "$output" "7.7.7" "mb.sh: [NOTICE] mentions the fetched version"
  assert_file_exists "$TMPDIR_FETCH/.mb/version-check-cache.json" "mb.sh: live fetch writes the cache file"
  cache_content=$(cat "$TMPDIR_FETCH/.mb/version-check-cache.json")
  assert_contains "$cache_content" "7.7.7" "mb.sh: cache file contains the fetched version"
else
  echo "--- live fetch test: SKIPPED (python3 not installed on this machine) ---"
fi

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
  assert_contains "$output" "\[NOTICE\]" "mb.ps1: cache hit with differing version prints [NOTICE]"
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
  assert_not_contains "$output" "\[NOTICE\]" "mb.ps1: mb upgrade suppresses the generic [NOTICE]"
else
  echo ""
  echo "--- mb.ps1 tests: SKIPPED (pwsh not installed on this machine) ---"
fi

print_summary
