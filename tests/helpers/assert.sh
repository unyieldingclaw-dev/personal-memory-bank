#!/usr/bin/env bash
# tests/helpers/assert.sh — minimal test assertion helpers (no external deps)
# Source this file in test scripts: source "$(dirname "${BASH_SOURCE[0]}")/helpers/assert.sh"

PASS=0
FAIL=0

assert_contains() {
  local output="$1" pattern="$2" desc="$3"
  if echo "$output" | grep -qi "$pattern"; then
    echo "  PASS: $desc"
    PASS=$((PASS + 1))
  else
    echo "  FAIL: $desc"
    echo "    Expected output to contain (case-insensitive): '$pattern'"
    FAIL=$((FAIL + 1))
  fi
}

assert_exit_zero() {
  local code="$1" desc="$2"
  if [ "$code" -eq 0 ]; then
    echo "  PASS: $desc"
    PASS=$((PASS + 1))
  else
    echo "  FAIL: $desc (exit code: $code)"
    FAIL=$((FAIL + 1))
  fi
}

assert_exit_nonzero() {
  local code="$1" desc="$2"
  if [ "$code" -ne 0 ]; then
    echo "  PASS: $desc"
    PASS=$((PASS + 1))
  else
    echo "  FAIL: $desc (expected non-zero exit)"
    FAIL=$((FAIL + 1))
  fi
}

assert_file_exists() {
  local path="$1" desc="$2"
  if [ -e "$path" ]; then
    echo "  PASS: $desc"
    PASS=$((PASS + 1))
  else
    echo "  FAIL: $desc (not found: $path)"
    FAIL=$((FAIL + 1))
  fi
}

assert_file_not_exists() {
  local path="$1" desc="$2"
  if [ ! -e "$path" ]; then
    echo "  PASS: $desc"
    PASS=$((PASS + 1))
  else
    echo "  FAIL: $desc (should not exist: $path)"
    FAIL=$((FAIL + 1))
  fi
}

print_summary() {
  echo ""
  echo "Results: $PASS passed, $FAIL failed"
  [ "$FAIL" -eq 0 ] && return 0 || return 1
}
