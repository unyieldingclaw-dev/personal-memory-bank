#!/usr/bin/env bash
# check-contract.sh — PreToolUse hook for Write/Edit
# Consolidated: single Python invocation handles all contract checks.
# Exits 0 (warn) or 2 (hard-block only). Fails open on any error.
# WHY: Original had 3 separate python3 spawns + 6 sed subshells per call.
# Collapsed into one heredoc invocation: ~150-300ms saved per Write/Edit hook.

CONTRACT_FILE=".claude/contracts/active-task.json"

command -v python3 >/dev/null 2>&1 || exit 0
[ -f "$CONTRACT_FILE" ] || exit 0

python3 - "$CONTRACT_FILE" <<'PYEOF'
import sys, json, os, fnmatch
from datetime import datetime, timezone

contract_file = sys.argv[1]
try:
    with open(contract_file) as f:
        data = json.load(f)
except Exception:
    sys.exit(0)  # fail open: malformed contract

if data.get("status") != "active":
    sys.exit(0)

expires_at = data.get("expires_at", "")
if expires_at:
    try:
        expires = datetime.fromisoformat(expires_at.replace('Z', '+00:00'))
        if datetime.now(timezone.utc) > expires:
            task = data.get("task", "")
            print("⚠️  CONTRACT EXPIRED: The active task contract has expired.")
            print(f"    Task: {task}")
            print("    Propose a new contract before continuing.")
            sys.exit(0)
    except Exception:
        pass  # fail open: unparseable expiry

try:
    target_file = json.loads(os.environ.get('CLAUDE_TOOL_INPUT', '{}')).get('file_path', '')
except Exception:
    target_file = ''

if not target_file:
    sys.exit(0)  # fail open: can't determine target

scope_files = data.get("scope", {}).get("files", [])
task = data.get("task", "")

in_scope = any(
    p and (
        target_file == p
        or (p.endswith('/') and target_file.startswith(p))
        or fnmatch.fnmatch(target_file, p)
    )
    for p in scope_files
)

if not in_scope:
    scope_summary = ", ".join(p for p in scope_files if p)
    print(f"⚠️  CONTRACT SCOPE: Writing to '{target_file}' is outside the active contract.")
    print(f"    Task: {task}")
    print(f"    Declared scope: {scope_summary}")
    # WHY: PMB_CONTRACT_HARD_BLOCK=1 promotes scope warnings to blocks (exit 2).
    # Default is warn-only (exit 0); hard-block is opt-in for strict enforcement.
    if os.environ.get('PMB_CONTRACT_HARD_BLOCK') == '1':
        print("    Hard-block active (PMB_CONTRACT_HARD_BLOCK=1) — write blocked.")
        sys.exit(2)
    print("    Pause and confirm with user before proceeding.")

sys.exit(0)
PYEOF
