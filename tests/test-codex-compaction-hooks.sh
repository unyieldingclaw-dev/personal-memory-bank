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

  if command -v python3 >/dev/null 2>&1; then
    config_summary=$(python3 - "$CONFIG" <<'PY'
import json, sys
data = json.load(open(sys.argv[1], encoding="utf-8"))
for event in ("PreCompact", "SessionStart"):
    for group in data.get("hooks", {}).get(event, []):
        for hook in group.get("hooks", []):
            print("|".join((event, group.get("matcher", ""), hook.get("command", ""), hook.get("commandWindows", ""))))
PY
)
    assert_contains "$config_summary" "PreCompact|manual|auto" "PreCompact covers manual and automatic compaction"
    assert_contains "$config_summary" 'SessionStart|[\^]compact[$]' "SessionStart recovery matches post-compaction continuation"
    assert_contains "$config_summary" "git rev-parse --show-toplevel" "Unix hook commands resolve from the Git root"
    assert_contains "$config_summary" "pwsh" "config exposes Windows command wiring"
  else
    echo "  SKIP: structural JSON assertions (python3 unavailable)"
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
  local dir="$1" mode="$2"
  mkdir -p "$dir/memory-bank" "$dir/scripts"
  git -C "$dir" init -q
  if [ "$mode" = "fresh" ]; then
    printf '%s\n' '---' 'authority: volatile' '---' '# Active Context' \
      'Current task has a verified implementation checkpoint.' \
      'Focused tests and their expected results are recorded.' \
      'The next action is explicit and independently reproducible.' > "$dir/memory-bank/activeContext.md"
    printf '# Progress\n\n## %s — focused test state\n' "$(date +%Y-%m-%d)" > "$dir/memory-bank/progress.md"
  else
    printf '# Active Context\n\nThin.\n' > "$dir/memory-bank/activeContext.md"
    printf '# Progress\n\nNo current entry.\n' > "$dir/memory-bank/progress.md"
  fi
}

if [ -f "$ADAPTER_SH" ]; then
  for mode in fresh thin; do
    make_project "$TMPDIR_CODEX/$mode" "$mode"
    cp "$ADAPTER_SH" "$TMPDIR_CODEX/$mode/scripts/codex-compaction-hook.sh"
    cp "$REPO_ROOT/scripts/pre-compact-check.sh" "$TMPDIR_CODEX/$mode/scripts/pre-compact-check.sh"
  done

  fresh_out=$(cd "$TMPDIR_CODEX/fresh" && bash scripts/codex-compaction-hook.sh pre 2>&1)
  fresh_code=$?
  assert_exit_zero "$fresh_code" "bash adapter exits 0 when the existing gate allows compaction"
  assert_equals "$fresh_out" "" "bash adapter emits no output on allow"

  thin_out=$(cd "$TMPDIR_CODEX/thin" && bash scripts/codex-compaction-hook.sh pre 2>&1)
  thin_code=$?
  assert_exit_zero "$thin_code" "bash adapter reports a policy block through JSON, not process failure"
  if command -v python3 >/dev/null 2>&1; then
    thin_continue=$(printf '%s' "$thin_out" | python3 -c 'import json,sys; print(json.load(sys.stdin)["continue"])' 2>/dev/null || printf 'parse-error')
    assert_equals "$thin_continue" "False" "bash adapter translates checker exit 2 to continue:false"
  elif command -v pwsh >/dev/null 2>&1; then
    thin_continue=$(printf '%s' "$thin_out" | pwsh -NoProfile -NonInteractive -Command '$data = [Console]::In.ReadToEnd() | ConvertFrom-Json; $data.continue')
    assert_equals "$thin_continue" "False" "bash adapter translates checker exit 2 to continue:false"
  fi
  assert_contains "$thin_out" "memory-bank" "bash block response tells the operator what state to update"

  make_project "$TMPDIR_CODEX/failure" fresh
  cp "$ADAPTER_SH" "$TMPDIR_CODEX/failure/scripts/codex-compaction-hook.sh"
  printf '#!/usr/bin/env bash\nexit 1\n' > "$TMPDIR_CODEX/failure/scripts/pre-compact-check.sh"
  failure_out=$(cd "$TMPDIR_CODEX/failure" && bash scripts/codex-compaction-hook.sh pre 2>&1)
  failure_code=$?
  assert_exit_zero "$failure_code" "bash adapter fails open on an unexpected checker error"
  assert_equals "$failure_out" "" "unexpected checker errors do not emit a false policy block"

  recovery_out=$(cd "$TMPDIR_CODEX/fresh" && bash scripts/codex-compaction-hook.sh recover 2>&1)
  assert_contains "$recovery_out" "re-read all five memory-bank files" "recovery context requires the full memory-bank reread"
  assert_contains "$recovery_out" "handoff.md" "recovery context reconciles a handoff supplement"
  assert_contains "$recovery_out" "verified" "recovery resumes from verified state"
fi

if command -v pwsh >/dev/null 2>&1 && [ -f "$ADAPTER_PS1" ]; then
  make_project "$TMPDIR_CODEX/pwsh-thin" thin
  cp "$ADAPTER_PS1" "$TMPDIR_CODEX/pwsh-thin/scripts/codex-compaction-hook.ps1"
  cp "$REPO_ROOT/scripts/pre-compact-check.ps1" "$TMPDIR_CODEX/pwsh-thin/scripts/pre-compact-check.ps1"
  ps_out=$(cd "$TMPDIR_CODEX/pwsh-thin" && pwsh -NoProfile -NonInteractive -File scripts/codex-compaction-hook.ps1 -Mode pre 2>&1)
  ps_code=$?
  assert_exit_zero "$ps_code" "PowerShell adapter reports a policy block through JSON, not process failure"
  if command -v python3 >/dev/null 2>&1; then
    ps_continue=$(printf '%s' "$ps_out" | python3 -c 'import json,sys; print(json.load(sys.stdin)["continue"])' 2>/dev/null || printf 'parse-error')
    assert_equals "$ps_continue" "False" "PowerShell adapter translates checker exit 2 to continue:false"
  else
    ps_continue=$(printf '%s' "$ps_out" | pwsh -NoProfile -NonInteractive -Command '$data = [Console]::In.ReadToEnd() | ConvertFrom-Json; $data.continue')
    assert_equals "$ps_continue" "False" "PowerShell adapter translates checker exit 2 to continue:false"
  fi
fi

print_summary
