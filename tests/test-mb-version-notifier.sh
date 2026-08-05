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

# WHY a single trap registered once, with an accumulating cleanup list, instead of each test
# calling `trap '...' EXIT` itself: bash only ever keeps the LAST trap registered for a given
# signal -- each subsequent `trap ... EXIT` below used to silently discard the previous test's
# cleanup, so only the final test's tmpdir was ever actually removed and the rest leaked on
# disk on every run. Confirmed directly: with the old per-test traps, only one of six tmpdirs
# survived past the script's exit for inspection; the other five remained. Registering once and
# appending to CLEANUP_DIRS instead means every test's directory gets removed regardless of how
# many more tests register after it.
CLEANUP_DIRS=()
SRV_PID=""
SRV_PORT=""
cleanup_all() {
    if [ -n "$SRV_PID" ] && [ -n "$SRV_PORT" ]; then
        kill_server_on_port "$SRV_PID" "$SRV_PORT"
    fi
    for d in "${CLEANUP_DIRS[@]:-}"; do
        [ -n "$d" ] && rm -rf "$d"
    done
}
trap cleanup_all EXIT

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
CLEANUP_DIRS+=("$TMPDIR_HIT")
setup_test_project "$TMPDIR_HIT"
mkdir -p "$TMPDIR_HIT/.mb"
NOW_EPOCH=$(date +%s)
printf '{"checkedAtEpoch":%s,"remoteVersion":"9.9.9"}' "$NOW_EPOCH" > "$TMPDIR_HIT/.mb/version-check-cache.json"
cd "$TMPDIR_HIT" || exit 1
output=$(MB_HOME="$REPO_ROOT" MB_VERSION_CACHE_DIR="$TMPDIR_HIT/.mb" bash "$MB" status 2>&1)
exit_code=$?
cd - > /dev/null || exit 1
assert_contains "$output" "\[NOTICE\]" "mb.sh: cache hit with differing version prints [NOTICE]"
assert_contains "$output" "9.9.9" "mb.sh: [NOTICE] mentions the cached remote version"
assert_exit_zero "$exit_code" "mb.sh: cache hit with differing version does not fail the command"

# ── cache hit, versions match → no NOTICE ────────────────────────────────────
echo ""
echo "--- cache hit: matching version shows nothing ---"
TMPDIR_MATCH="$(mktemp -d 2>/dev/null || mktemp -d -t mb-vn-test)"
CLEANUP_DIRS+=("$TMPDIR_MATCH")
setup_test_project "$TMPDIR_MATCH"
mkdir -p "$TMPDIR_MATCH/.mb"
LOCAL_VER=$(tr -d '[:space:]' < "$REPO_ROOT/VERSION")
printf '{"checkedAtEpoch":%s,"remoteVersion":"%s"}' "$NOW_EPOCH" "$LOCAL_VER" > "$TMPDIR_MATCH/.mb/version-check-cache.json"
cd "$TMPDIR_MATCH" || exit 1
output=$(MB_HOME="$REPO_ROOT" MB_VERSION_CACHE_DIR="$TMPDIR_MATCH/.mb" bash "$MB" status 2>&1)
exit_code=$?
cd - > /dev/null || exit 1
assert_not_contains "$output" "\[NOTICE\]" "mb.sh: cache hit with matching version prints no [NOTICE]"
assert_exit_zero "$exit_code" "mb.sh: cache hit with matching version does not fail the command"

# ── unreachable remote → fails open silently ─────────────────────────────────
echo ""
echo "--- no cache, unreachable remote: fails open, no crash ---"
TMPDIR_UNREACH="$(mktemp -d 2>/dev/null || mktemp -d -t mb-vn-test)"
CLEANUP_DIRS+=("$TMPDIR_UNREACH")
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
CLEANUP_DIRS+=("$TMPDIR_UPG")
setup_test_project "$TMPDIR_UPG"
mkdir -p "$TMPDIR_UPG/.mb"
printf '{"checkedAtEpoch":%s,"remoteVersion":"9.9.9"}' "$NOW_EPOCH" > "$TMPDIR_UPG/.mb/version-check-cache.json"
cd "$TMPDIR_UPG" || exit 1
output=$(MB_HOME="$REPO_ROOT" MB_VERSION_CACHE_DIR="$TMPDIR_UPG/.mb" bash "$MB" upgrade 2>&1)
exit_code=$?
cd - > /dev/null || exit 1
assert_not_contains "$output" "\[NOTICE\]" "mb.sh: mb upgrade suppresses the generic [NOTICE] (it has its own WARN)"
assert_exit_zero "$exit_code" "mb.sh: mb upgrade does not fail the command"

# ── mb update (deprecated alias for upgrade) never double-prints ────────────
echo ""
echo "--- mb update suppresses the generic [NOTICE] ---"
TMPDIR_UPD="$(mktemp -d 2>/dev/null || mktemp -d -t mb-vn-test)"
CLEANUP_DIRS+=("$TMPDIR_UPD")
setup_test_project "$TMPDIR_UPD"
mkdir -p "$TMPDIR_UPD/.mb"
printf '{"checkedAtEpoch":%s,"remoteVersion":"9.9.9"}' "$NOW_EPOCH" > "$TMPDIR_UPD/.mb/version-check-cache.json"
cd "$TMPDIR_UPD" || exit 1
output=$(MB_HOME="$REPO_ROOT" MB_VERSION_CACHE_DIR="$TMPDIR_UPD/.mb" bash "$MB" update 2>&1)
exit_code=$?
cd - > /dev/null || exit 1
assert_not_contains "$output" "\[NOTICE\]" "mb.sh: mb update (deprecated alias, still dispatches to invoke_upgrade) suppresses the generic [NOTICE]"
assert_exit_zero "$exit_code" "mb.sh: mb update (deprecated alias) does not fail the command"

# ── mb help suppresses the generic [NOTICE] ──────────────────────────────────
echo ""
echo "--- mb help suppresses the generic [NOTICE] ---"
TMPDIR_HELP="$(mktemp -d 2>/dev/null || mktemp -d -t mb-vn-test)"
CLEANUP_DIRS+=("$TMPDIR_HELP")
setup_test_project "$TMPDIR_HELP"
mkdir -p "$TMPDIR_HELP/.mb"
printf '{"checkedAtEpoch":%s,"remoteVersion":"9.9.9"}' "$NOW_EPOCH" > "$TMPDIR_HELP/.mb/version-check-cache.json"
cd "$TMPDIR_HELP" || exit 1
output=$(MB_HOME="$REPO_ROOT" MB_VERSION_CACHE_DIR="$TMPDIR_HELP/.mb" bash "$MB" help 2>&1)
exit_code=$?
cd - > /dev/null || exit 1
assert_not_contains "$output" "\[NOTICE\]" "mb.sh: mb help suppresses the generic [NOTICE]"
assert_exit_zero "$exit_code" "mb.sh: mb help does not fail the command"

# ── real fetch populates the cache correctly ─────────────────────────────────
echo ""
if command -v python3 >/dev/null 2>&1; then
  echo "--- live fetch: populates cache with the served version ---"
  TMPDIR_FETCH="$(mktemp -d 2>/dev/null || mktemp -d -t mb-vn-test)"
  CLEANUP_DIRS+=("$TMPDIR_FETCH")
  setup_test_project "$TMPDIR_FETCH"
  SRVDIR="$(mktemp -d 2>/dev/null || mktemp -d -t mb-vn-srv)"
  CLEANUP_DIRS+=("$SRVDIR")
  echo "7.7.7" > "$SRVDIR/VERSION"
  # WHY a randomized port instead of a fixed one: a hardcoded port can collide with another
  # process (this suite's own prior run that failed to clean up, or an unrelated service) on a
  # shared or CI host. Picking a random high port each run makes a collision astronomically
  # unlikely without needing bind-retry logic.
  PORT=$((20000 + RANDOM % 10000))
  (cd "$SRVDIR" && python3 -m http.server "$PORT" >/dev/null 2>&1) &
  SRV_PID=$!
  SRV_PORT="$PORT"
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
  assert_contains "$output" "\[NOTICE\]" "mb.sh: live fetch shows [NOTICE] for the served version"
  assert_contains "$output" "7.7.7" "mb.sh: [NOTICE] mentions the fetched version"
  assert_file_exists "$TMPDIR_FETCH/.mb/version-check-cache.json" "mb.sh: live fetch writes the cache file"
  cache_content=$(cat "$TMPDIR_FETCH/.mb/version-check-cache.json")
  assert_contains "$cache_content" "7.7.7" "mb.sh: cache file contains the fetched version"

  # ── live fetch: quoted VERSION content has its quotes stripped ────────────────────────────
  # WHY this test exists: get_cached_pmb_version's fetch pipes the served content through
  # `tr -d '[:space:]"'`, stripping literal `"` characters as well as whitespace. Nothing
  # previously exercised that stripping -- the live-fetch test above serves a bare, unquoted
  # version, so a regression that dropped the `"` from the tr charset would go unnoticed.
  echo ""
  echo "--- live fetch: quoted VERSION content has its quotes stripped ---"
  TMPDIR_QUOTE="$(mktemp -d 2>/dev/null || mktemp -d -t mb-vn-test)"
  CLEANUP_DIRS+=("$TMPDIR_QUOTE")
  setup_test_project "$TMPDIR_QUOTE"
  printf '"6.6.6"' > "$SRVDIR/VERSION"
  cd "$TMPDIR_QUOTE" || exit 1
  output=$(MB_HOME="$REPO_ROOT" MB_VERSION_CACHE_DIR="$TMPDIR_QUOTE/.mb" MB_VERSION_CHECK_URL="http://127.0.0.1:$PORT/VERSION" bash "$MB" status 2>&1)
  cd - > /dev/null || exit 1
  assert_contains "$output" "6.6.6" "mb.sh: quoted VERSION content is stripped of its quotes in the [NOTICE]"
  cache_content=$(cat "$TMPDIR_QUOTE/.mb/version-check-cache.json")
  assert_contains "$cache_content" '"remoteVersion":"6.6.6"' "mb.sh: cache file stores the quote-stripped version, not the raw quoted content"
  echo "7.7.7" > "$SRVDIR/VERSION"

  # ── expired cache (older than CACHE_TTL_SECONDS) triggers a fresh fetch ────────────────────
  # WHY this test exists: every prior cache-hit test used a fresh (now) checkedAtEpoch, so
  # nothing exercised the actual TTL boundary get_cached_pmb_version's own comments call out as
  # a deliberate defensive check (CACHE_TTL_SECONDS=604800, 7 days). This proves an expired
  # cache is correctly treated as stale -- the NOTICE reflects a freshly-fetched value, not the
  # old cached one -- using the same live server above, still serving 7.7.7.
  echo ""
  echo "--- expired cache (older than CACHE_TTL_SECONDS) triggers a live re-fetch, not stale cache ---"
  TMPDIR_TTL="$(mktemp -d 2>/dev/null || mktemp -d -t mb-vn-test)"
  CLEANUP_DIRS+=("$TMPDIR_TTL")
  setup_test_project "$TMPDIR_TTL"
  mkdir -p "$TMPDIR_TTL/.mb"
  EXPIRED_EPOCH=$(( $(date +%s) - 604800 - 3600 ))  # 1 hour past the 7-day TTL
  printf '{"checkedAtEpoch":%s,"remoteVersion":"8.8.8"}' "$EXPIRED_EPOCH" > "$TMPDIR_TTL/.mb/version-check-cache.json"
  cd "$TMPDIR_TTL" || exit 1
  output=$(MB_HOME="$REPO_ROOT" MB_VERSION_CACHE_DIR="$TMPDIR_TTL/.mb" MB_VERSION_CHECK_URL="http://127.0.0.1:$PORT/VERSION" bash "$MB" status 2>&1)
  cd - > /dev/null || exit 1
  assert_contains "$output" "7.7.7" "mb.sh: expired cache triggers a live re-fetch, reflecting the freshly-served version"
  assert_not_contains "$output" "8.8.8" "mb.sh: expired cache's stale remoteVersion is not used once past CACHE_TTL_SECONDS"

  # ── clock-skewed cache (future checkedAtEpoch) also triggers a fresh fetch ─────────────────
  # WHY this test exists: get_cached_pmb_version's own comments call out a future checkedAtEpoch
  # (clock skew, or a cache written once under a wrong system clock) as a case that would
  # otherwise satisfy "age < TTL" forever via a negative age_seconds -- guarded by requiring
  # age_seconds >= 0. Nothing previously exercised that specific guard.
  echo ""
  echo "--- clock-skewed cache (future checkedAtEpoch) triggers a live re-fetch, not stale cache ---"
  TMPDIR_SKEW="$(mktemp -d 2>/dev/null || mktemp -d -t mb-vn-test)"
  CLEANUP_DIRS+=("$TMPDIR_SKEW")
  setup_test_project "$TMPDIR_SKEW"
  mkdir -p "$TMPDIR_SKEW/.mb"
  FUTURE_EPOCH=$(( $(date +%s) + 31536000 ))  # 1 year in the future
  printf '{"checkedAtEpoch":%s,"remoteVersion":"8.8.8"}' "$FUTURE_EPOCH" > "$TMPDIR_SKEW/.mb/version-check-cache.json"
  cd "$TMPDIR_SKEW" || exit 1
  output=$(MB_HOME="$REPO_ROOT" MB_VERSION_CACHE_DIR="$TMPDIR_SKEW/.mb" MB_VERSION_CHECK_URL="http://127.0.0.1:$PORT/VERSION" bash "$MB" status 2>&1)
  cd - > /dev/null || exit 1
  assert_contains "$output" "7.7.7" "mb.sh: clock-skewed (future) cache triggers a live re-fetch, reflecting the freshly-served version"
  assert_not_contains "$output" "8.8.8" "mb.sh: clock-skewed cache's stale remoteVersion is not trusted just because age_seconds went negative"

  kill_server_on_port "$SRV_PID" "$PORT"
  SRV_PID=""
  SRV_PORT=""
else
  echo "--- live fetch test: SKIPPED (python3 not installed on this machine) ---"
fi

# ── cross-shell parity (PowerShell) ──────────────────────────────────────────
if command -v pwsh >/dev/null 2>&1; then
  echo ""
  echo "--- cross-shell parity: mb.ps1 cache hit shows [NOTICE] ---"
  TMPDIR_PS1="$(mktemp -d 2>/dev/null || mktemp -d -t mb-vn-ps1)"
  CLEANUP_DIRS+=("$TMPDIR_PS1")
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
  CLEANUP_DIRS+=("$TMPDIR_PS1U")
  setup_test_project "$TMPDIR_PS1U"
  mkdir -p "$TMPDIR_PS1U/.mb"
  printf '{"checkedAtEpoch":%s,"remoteVersion":"9.9.9"}' "$(date +%s)" > "$TMPDIR_PS1U/.mb/version-check-cache.json"
  cd "$TMPDIR_PS1U" || exit 1
  output=$(MB_HOME="$REPO_ROOT" MB_VERSION_CACHE_DIR="$TMPDIR_PS1U/.mb" pwsh -NoLogo -File "$REPO_ROOT/scripts/mb.ps1" upgrade 2>&1)
  cd - > /dev/null || exit 1
  assert_not_contains "$output" "\[NOTICE\]" "mb.ps1: mb upgrade suppresses the generic [NOTICE]"

  # ── cross-shell parity: PS TTL / clock-skew ──────────────────────────────────
  # WHY these mirror the bash TTL/clock-skew tests above: Get-CachedPmbVersion has the same
  # age_seconds -ge 0 -and age_seconds -lt TTL guard as get_cached_pmb_version, but nothing had
  # exercised either boundary on the PowerShell side -- only bash's had live-server-backed
  # coverage for expired/skewed caches.
  echo ""
  if command -v python3 >/dev/null 2>&1; then
    echo "--- cross-shell parity: mb.ps1 expired cache triggers a live re-fetch, not stale cache ---"
    TMPDIR_PS1_TTL="$(mktemp -d 2>/dev/null || mktemp -d -t mb-vn-ps1ttl)"
    CLEANUP_DIRS+=("$TMPDIR_PS1_TTL")
    setup_test_project "$TMPDIR_PS1_TTL"
    SRVDIR_PS1="$(mktemp -d 2>/dev/null || mktemp -d -t mb-vn-ps1srv)"
    CLEANUP_DIRS+=("$SRVDIR_PS1")
    echo "7.7.7" > "$SRVDIR_PS1/VERSION"
    PS1_PORT=$((20000 + RANDOM % 10000))
    (cd "$SRVDIR_PS1" && python3 -m http.server "$PS1_PORT" >/dev/null 2>&1) &
    SRV_PID=$!
    SRV_PORT="$PS1_PORT"
    for _ in 1 2 3 4 5 6 7 8 9 10; do
      curl -sf --max-time 1 "http://127.0.0.1:$PS1_PORT/VERSION" >/dev/null 2>&1 && break
      sleep 0.3
    done
    mkdir -p "$TMPDIR_PS1_TTL/.mb"
    EXPIRED_EPOCH_PS1=$(( $(date +%s) - 604800 - 3600 ))  # 1 hour past the 7-day TTL
    printf '{"checkedAtEpoch":%s,"remoteVersion":"8.8.8"}' "$EXPIRED_EPOCH_PS1" > "$TMPDIR_PS1_TTL/.mb/version-check-cache.json"
    cd "$TMPDIR_PS1_TTL" || exit 1
    output=$(MB_HOME="$REPO_ROOT" MB_VERSION_CACHE_DIR="$TMPDIR_PS1_TTL/.mb" MB_VERSION_CHECK_URL="http://127.0.0.1:$PS1_PORT/VERSION" pwsh -NoLogo -File "$REPO_ROOT/scripts/mb.ps1" status 2>&1)
    cd - > /dev/null || exit 1
    assert_contains "$output" "7.7.7" "mb.ps1: expired cache triggers a live re-fetch, reflecting the freshly-served version"
    assert_not_contains "$output" "8.8.8" "mb.ps1: expired cache's stale remoteVersion is not used once past CACHE_TTL_SECONDS"

    echo ""
    echo "--- cross-shell parity: mb.ps1 clock-skewed cache triggers a live re-fetch, not stale cache ---"
    TMPDIR_PS1_SKEW="$(mktemp -d 2>/dev/null || mktemp -d -t mb-vn-ps1skew)"
    CLEANUP_DIRS+=("$TMPDIR_PS1_SKEW")
    setup_test_project "$TMPDIR_PS1_SKEW"
    mkdir -p "$TMPDIR_PS1_SKEW/.mb"
    FUTURE_EPOCH_PS1=$(( $(date +%s) + 31536000 ))  # 1 year in the future
    printf '{"checkedAtEpoch":%s,"remoteVersion":"8.8.8"}' "$FUTURE_EPOCH_PS1" > "$TMPDIR_PS1_SKEW/.mb/version-check-cache.json"
    cd "$TMPDIR_PS1_SKEW" || exit 1
    output=$(MB_HOME="$REPO_ROOT" MB_VERSION_CACHE_DIR="$TMPDIR_PS1_SKEW/.mb" MB_VERSION_CHECK_URL="http://127.0.0.1:$PS1_PORT/VERSION" pwsh -NoLogo -File "$REPO_ROOT/scripts/mb.ps1" status 2>&1)
    cd - > /dev/null || exit 1
    assert_contains "$output" "7.7.7" "mb.ps1: clock-skewed (future) cache triggers a live re-fetch, reflecting the freshly-served version"
    assert_not_contains "$output" "8.8.8" "mb.ps1: clock-skewed cache's stale remoteVersion is not trusted just because age_seconds went negative"

    kill_server_on_port "$SRV_PID" "$PS1_PORT"
    SRV_PID=""
    SRV_PORT=""
  else
    echo "--- mb.ps1 TTL/clock-skew tests: SKIPPED (python3 not installed on this machine) ---"
  fi
else
  echo ""
  echo "--- mb.ps1 tests: SKIPPED (pwsh not installed on this machine) ---"
fi

print_summary
