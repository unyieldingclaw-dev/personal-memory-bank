#!/usr/bin/env bash
# tests/test-codex-compaction-hooks.sh — Codex compaction wiring, adapter, and recovery contract
set -u

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$REPO_ROOT/tests/helpers/assert.sh"

CONFIG="$REPO_ROOT/.codex/hooks.json"
CONFIG_TMPL="$REPO_ROOT/templates/.codex/hooks.json"
ADAPTER_SH="$REPO_ROOT/scripts/codex-compaction-hook.sh"
ADAPTER_PS1="$REPO_ROOT/scripts/codex-compaction-hook.ps1"

echo "=== Codex compaction hook tests ==="

assert_file_exists "$REPO_ROOT/AGENTS.md" "PMB has a project-local AGENTS.md"
assert_file_exists "$CONFIG" "project-local Codex hooks config exists"
assert_file_exists "$CONFIG_TMPL" "Codex hooks config has a template"
assert_file_exists "$ADAPTER_SH" "Codex bash compaction adapter exists"
assert_file_exists "$ADAPTER_PS1" "Codex PowerShell compaction adapter exists"

if [ -f "$CONFIG" ] && [ -f "$CONFIG_TMPL" ]; then
  diff -q "$CONFIG" "$CONFIG_TMPL" >/dev/null 2>&1
  assert_exit_zero "$?" "Codex hooks config is byte-identical to its template"

  # WHY try-then-check-exit-status rather than branching on `command -v` alone: a
  # present-but-broken interpreter (e.g. a Windows Store app-execution-alias stub that
  # resolves but cannot actually run a script) makes `command -v python3` succeed while
  # producing no usable output — the old `if python3 ... elif pwsh` structure then never
  # reaches the pwsh fallback at all, silently disabling the assertions below. Falling
  # through on a NON-ZERO EXIT (not just on the binary being absent) is what lets a
  # working pwsh rescue a broken python3, and vice versa.
  parser_used=""
  if command -v python3 >/dev/null 2>&1; then
    config_summary=$(python3 - "$CONFIG" <<'PY' 2>/dev/null
import json, sys
data = json.load(open(sys.argv[1], encoding="utf-8"))
hooks = data.get("hooks", {})
print("events=" + "|".join(hooks))
for group in hooks.get("SessionStart", []):
    for hook in group.get("hooks", []):
        print("|".join(("SessionStart", group.get("matcher", ""), hook.get("command", ""), hook.get("commandWindows", ""))))
PY
)
    [ $? -eq 0 ] && [ -n "$config_summary" ] && parser_used="python3"
  fi
  if [ -z "$parser_used" ] && command -v pwsh >/dev/null 2>&1; then
    config_summary=$(CONFIG_PATH="$CONFIG" pwsh -NoProfile -NonInteractive -Command '$data = Get-Content -Raw -LiteralPath $env:CONFIG_PATH | ConvertFrom-Json; Write-Output ("events=" + ($data.hooks.PSObject.Properties.Name -join "|")); foreach ($group in @($data.hooks.SessionStart)) { foreach ($hook in @($group.hooks)) { Write-Output ("SessionStart|$($group.matcher)|$($hook.command)|$($hook.commandWindows)") } }' 2>/dev/null)
    [ $? -eq 0 ] && [ -n "$config_summary" ] && parser_used="pwsh"
  fi

  if [ -z "$parser_used" ]; then
    if command -v python3 >/dev/null 2>&1 || command -v pwsh >/dev/null 2>&1; then
      # WHY fail loud, not skip: a parser was on PATH but produced no usable output --
      # per this repo's Evidence Integrity rule, a check that cannot fail does not count
      # as one, and silently no-op'ing here is exactly how a re-introduced PreCompact
      # gate (the regression this file exists to catch) could ship undetected.
      assert_contains "PARSE_FAILED" "PARSE_OK" "structural JSON assertions: a JSON parser was on PATH but produced no usable output for $CONFIG"
    else
      echo "  SKIP: structural JSON assertions (python3 and pwsh unavailable)"
    fi
  else
    assert_not_contains "$config_summary" "PreCompact" "Codex does not register a turn-terminating PreCompact gate"
    assert_contains "$config_summary" 'SessionStart|[\^]compact[$]' "SessionStart recovery matches post-compaction continuation"
    assert_contains "$config_summary" "git rev-parse --show-toplevel" "Unix hook commands resolve from the Git root"
    assert_contains "$config_summary" "pwsh" "config exposes Windows command wiring"
  fi
fi

if [ -f "$ADAPTER_SH" ] && [ -f "$REPO_ROOT/templates/scripts/codex-compaction-hook.sh" ]; then
  diff -q "$ADAPTER_SH" "$REPO_ROOT/templates/scripts/codex-compaction-hook.sh" >/dev/null 2>&1
  assert_exit_zero "$?" "bash Codex adapter is byte-identical to its template"
fi
if [ -f "$ADAPTER_PS1" ] && [ -f "$REPO_ROOT/templates/scripts/codex-compaction-hook.ps1" ]; then
  diff -q "$ADAPTER_PS1" "$REPO_ROOT/templates/scripts/codex-compaction-hook.ps1" >/dev/null 2>&1
  assert_exit_zero "$?" "PowerShell Codex adapter is byte-identical to its template"
fi

TMPDIR_CODEX="$(mktemp -d 2>/dev/null || mktemp -d -t pmb-codex-hooks-test)"
trap 'rm -rf "$TMPDIR_CODEX"' EXIT

make_project() {
  local dir="$1"
  mkdir -p "$dir/scripts"
  git -C "$dir" init -q
}

if [ -f "$ADAPTER_SH" ]; then
  make_project "$TMPDIR_CODEX/bash-recovery"
  cp "$ADAPTER_SH" "$TMPDIR_CODEX/bash-recovery/scripts/codex-compaction-hook.sh"
  recovery_out=$(cd "$TMPDIR_CODEX/bash-recovery" && bash scripts/codex-compaction-hook.sh recover 2>&1)
  assert_contains "$recovery_out" "re-read all five memory-bank files" "recovery context requires the full memory-bank reread"
  assert_contains "$recovery_out" "handoff.md" "recovery context reconciles a handoff supplement"
  assert_contains "$recovery_out" "verified" "recovery resumes from verified state"
fi

if command -v pwsh >/dev/null 2>&1 && [ -f "$ADAPTER_PS1" ]; then
  make_project "$TMPDIR_CODEX/pwsh-recovery"
  cp "$ADAPTER_PS1" "$TMPDIR_CODEX/pwsh-recovery/scripts/codex-compaction-hook.ps1"
  ps_out=$(cd "$TMPDIR_CODEX/pwsh-recovery" && pwsh -NoProfile -NonInteractive -File scripts/codex-compaction-hook.ps1 -Mode recover 2>&1)
  assert_contains "$ps_out" "re-read all five memory-bank files" "PowerShell recovery context requires the full memory-bank reread"
  assert_contains "$ps_out" "handoff.md" "PowerShell recovery context reconciles a handoff supplement"
fi

print_summary
