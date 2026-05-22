# Task Contracts Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add machine-readable task contracts — a JSON file Claude writes after user approval, backed by a PreToolUse hook on Write/Edit that warns when writes fall outside the declared scope.

**Architecture:** Five new files (two hook scripts, one gitignore, one example, one docs guide) and three file modifications (settings.json hook entry, CLAUDE.md protocol section, root .gitignore). All new script logic in `scripts/` so CI shellcheck covers it. Contracts are gitignored session artifacts.

**Tech Stack:** Bash (POSIX), PowerShell, Python3 (for JSON parsing in hooks), Claude Code hooks (PreToolUse on Write|Edit), JSON

---

## Pre-Plan Research Notes

- `scripts/check-contract.sh` must pass `shellcheck --severity=error` — CI forbidden-patterns job checks all scripts under `scripts/` via the shellcheck step
- Python3 used for JSON parsing (more reliably present than jq); hook fails open (silent pass) if python3 unavailable — same pattern as `dangerous-commands.sh`
- `CLAUDE_TOOL_INPUT` env var contains the Write/Edit tool input as JSON; `file_path` key holds the target path
- Scope matching: exact path match OR directory prefix match (scope entry ends with `/`) OR fnmatch glob match
- All hook exits are 0 (WARN tier); the hook output is visible to Claude as context
- The `.claude/contracts/` directory and its contents must be gitignored in both the repo root `.gitignore` (for the live project) and in `templates/.claude/contracts/.gitignore` (so new projects inherit the pattern)

---

## File Structure

**Create:**
- `scripts/check-contract.sh` — POSIX hook, reads `CLAUDE_TOOL_INPUT`, checks active-task.json
- `scripts/check-contract.ps1` — PowerShell hook, equivalent logic
- `templates/.claude/contracts/.gitignore` — `*.json` entry so contract files are never committed
- `templates/.claude/contracts/active-task.json.example` — schema reference for new projects
- `docs/CONTRACTS-GUIDE.md` — user-facing reference explaining the full system

**Modify:**
- `templates/.claude/settings.json` — add PreToolUse hook entry for `Write|Edit` matcher
- `templates/CLAUDE.md` — add `## Task Contract Protocol` section before `## Security Guardrails`
- `.gitignore` — add `.claude/contracts/*.json` entry

---

### Task 1: Create `.claude/contracts/` template files

**Files:**
- Create: `templates/.claude/contracts/.gitignore`
- Create: `templates/.claude/contracts/active-task.json.example`
- Modify: `.gitignore`

- [ ] **Step 1: Create the contracts directory gitignore**

Write `templates/.claude/contracts/.gitignore`:

```
# Contract files are session artifacts — never commit them.
# The .example file below is committed as schema documentation.
*.json
```

- [ ] **Step 2: Create the example schema file**

Write `templates/.claude/contracts/active-task.json.example`:

```json
{
  "task": "Example: Add email verification to user authentication",
  "created_at": "2026-01-01T09:00:00Z",
  "expires_at": "2026-01-01T17:00:00Z",
  "scope": {
    "files": [
      "src/auth/user.ts",
      "src/db/migrations/003_add_verification.sql",
      "tests/auth.test.ts"
    ],
    "operations": ["create", "edit"]
  },
  "approved_by": "user",
  "status": "active"
}
```

- [ ] **Step 3: Add contracts directory to root .gitignore**

Read the current `.gitignore` first. Then add after the `handoff.md` entry:

```
# Task contract files — session artifacts, never committed
.claude/contracts/*.json
```

- [ ] **Step 4: Verify .gitignore is clean**

Run:
```bash
git check-ignore -v .claude/contracts/active-task.json
```
Expected: `.gitignore:N:.claude/contracts/*.json    .claude/contracts/active-task.json` (the file is ignored)

- [ ] **Step 5: Commit**

```bash
git add templates/.claude/contracts/.gitignore templates/.claude/contracts/active-task.json.example .gitignore
git commit -m "ci: add task contract gitignore scaffold and schema example"
```

---

### Task 2: Implement `check-contract.sh` (POSIX hook)

**Files:**
- Create: `scripts/check-contract.sh`

The script:
1. Reads `$CLAUDE_TOOL_INPUT` to extract `file_path`
2. Checks for `$CONTRACT_FILE` (`.claude/contracts/active-task.json`)
3. Reads `status`, `expires_at`, `task`, and `scope.files` from the contract
4. Prints a WARN if file is out of scope or contract is expired
5. Always exits 0 (WARN tier)

- [ ] **Step 1: Write `scripts/check-contract.sh`**

```bash
#!/usr/bin/env bash
# check-contract.sh — PreToolUse hook for Write/Edit
# Checks the active task contract and warns if the target file is out of scope.
# Always exits 0 (WARN tier). Exits silently if no contract or python3 unavailable.

set -euo pipefail

CONTRACT_FILE=".claude/contracts/active-task.json"

# --- Dependency check: python3 required for JSON parsing ---
if ! command -v python3 >/dev/null 2>&1; then
  exit 0  # Fail open: no python3, skip the check
fi

# --- Contract existence check ---
if [ ! -f "$CONTRACT_FILE" ]; then
  exit 0  # No contract — silent pass
fi

# --- Parse contract fields via python3 ---
CONTRACT_DATA=$(python3 - "$CONTRACT_FILE" <<'PYEOF'
import sys, json
path = sys.argv[1]
try:
    with open(path) as f:
        data = json.load(f)
    status = data.get("status", "")
    expires_at = data.get("expires_at", "")
    task = data.get("task", "")
    files = data.get("scope", {}).get("files", [])
    print(status)
    print(expires_at)
    print(task)
    print("\n".join(files))
except Exception:
    pass
PYEOF
)

if [ -z "$CONTRACT_DATA" ]; then
  exit 0  # Malformed contract — fail open
fi

# Extract parsed fields (line-delimited)
STATUS=$(echo "$CONTRACT_DATA" | sed -n '1p')
EXPIRES_AT=$(echo "$CONTRACT_DATA" | sed -n '2p')
TASK=$(echo "$CONTRACT_DATA" | sed -n '3p')
SCOPE_FILES=$(echo "$CONTRACT_DATA" | tail -n +4)

# --- Status check ---
if [ "$STATUS" != "active" ]; then
  exit 0  # Contract is complete or cancelled — silent pass
fi

# --- Expiry check ---
if [ -n "$EXPIRES_AT" ]; then
  EXPIRED=$(python3 -c "
from datetime import datetime, timezone
import sys
try:
    expires = datetime.fromisoformat('$EXPIRES_AT'.replace('Z', '+00:00'))
    now = datetime.now(timezone.utc)
    print('yes' if now > expires else 'no')
except Exception:
    print('no')
" 2>/dev/null)
  if [ "$EXPIRED" = "yes" ]; then
    echo "⚠️  CONTRACT EXPIRED: The active task contract has expired."
    echo "    Task: $TASK"
    echo "    Propose a new contract before continuing."
    exit 0
  fi
fi

# --- Extract target file from tool input ---
TARGET_FILE=$(python3 -c "
import sys, json, os
try:
    data = json.loads(os.environ.get('CLAUDE_TOOL_INPUT', '{}'))
    print(data.get('file_path', ''))
except Exception:
    print('')
" 2>/dev/null)

if [ -z "$TARGET_FILE" ]; then
  exit 0  # Can't determine target — fail open
fi

# --- Scope check ---
IN_SCOPE=0
while IFS= read -r pattern; do
  [ -z "$pattern" ] && continue
  # Exact match
  if [ "$TARGET_FILE" = "$pattern" ]; then
    IN_SCOPE=1
    break
  fi
  # Directory prefix match (pattern ends with /)
  if [[ "$pattern" == */ ]] && [[ "$TARGET_FILE" == "$pattern"* ]]; then
    IN_SCOPE=1
    break
  fi
  # Glob match via python3 fnmatch
  MATCH=$(python3 -c "
import fnmatch, sys
print('yes' if fnmatch.fnmatch('$TARGET_FILE', '$pattern') else 'no')
" 2>/dev/null)
  if [ "$MATCH" = "yes" ]; then
    IN_SCOPE=1
    break
  fi
done <<< "$SCOPE_FILES"

if [ "$IN_SCOPE" -eq 0 ]; then
  SCOPE_SUMMARY=$(echo "$SCOPE_FILES" | tr '\n' ',' | sed 's/,$//' | sed 's/,/, /g')
  echo "⚠️  CONTRACT SCOPE: Writing to '$TARGET_FILE' is outside the active contract."
  echo "    Task: $TASK"
  echo "    Declared scope: $SCOPE_SUMMARY"
  echo "    Pause and confirm with user before proceeding."
fi

exit 0
```

- [ ] **Step 2: Make the script executable**

```bash
chmod +x scripts/check-contract.sh
```

- [ ] **Step 3: Run shellcheck**

```bash
shellcheck --severity=error scripts/check-contract.sh
```

Expected: no output, exit 0.

If shellcheck isn't installed locally, note the specific shellcheck version in CI is pre-installed on ubuntu-latest and will catch errors on push.

- [ ] **Step 4: Test the no-contract path**

Run from repo root:
```bash
CLAUDE_TOOL_INPUT='{"file_path":"src/auth/user.ts"}' bash scripts/check-contract.sh
echo "Exit: $?"
```
Expected: no output, exit code 0.

- [ ] **Step 5: Test the out-of-scope WARN path**

First create a test contract:
```bash
mkdir -p .claude/contracts
cat > .claude/contracts/active-task.json << 'EOF'
{
  "task": "Test task",
  "created_at": "2026-01-01T00:00:00Z",
  "expires_at": "2099-12-31T23:59:59Z",
  "scope": {
    "files": ["src/auth/user.ts"],
    "operations": ["edit"]
  },
  "approved_by": "user",
  "status": "active"
}
EOF
```

Run with an in-scope file:
```bash
CLAUDE_TOOL_INPUT='{"file_path":"src/auth/user.ts"}' bash scripts/check-contract.sh
echo "Exit: $?"
```
Expected: no output, exit 0.

Run with an out-of-scope file:
```bash
CLAUDE_TOOL_INPUT='{"file_path":"src/new-feature.ts"}' bash scripts/check-contract.sh
echo "Exit: $?"
```
Expected: WARN output (3-4 lines starting with ⚠️), exit 0.

- [ ] **Step 6: Clean up test contract**

```bash
rm .claude/contracts/active-task.json
```

- [ ] **Step 7: Commit**

```bash
git add scripts/check-contract.sh
git commit -m "feat: add check-contract.sh PreToolUse hook for task scope validation"
```

---

### Task 3: Implement `check-contract.ps1` (PowerShell hook)

**Files:**
- Create: `scripts/check-contract.ps1`

Equivalent logic to the bash script, PowerShell-native. Scope matching uses the same three rules (exact, prefix, glob).

- [ ] **Step 1: Write `scripts/check-contract.ps1`**

```powershell
# check-contract.ps1 — PreToolUse hook for Write/Edit (PowerShell)
# Checks the active task contract and warns if the target file is out of scope.
# Always exits 0 (WARN tier). Exits silently if no contract found.

$ContractFile = ".claude/contracts/active-task.json"

# --- Contract existence check ---
if (-not (Test-Path $ContractFile)) {
    exit 0
}

# --- Parse contract ---
try {
    $contract = Get-Content $ContractFile -Raw | ConvertFrom-Json
} catch {
    exit 0  # Malformed contract — fail open
}

$status   = $contract.status
$task     = $contract.task
$expiresAt = $contract.expires_at
$scopeFiles = $contract.scope.files

# --- Status check ---
if ($status -ne "active") {
    exit 0
}

# --- Expiry check ---
if ($expiresAt) {
    try {
        $expires = [datetime]::Parse($expiresAt, $null, [System.Globalization.DateTimeStyles]::RoundtripKind)
        if ([datetime]::UtcNow -gt $expires) {
            Write-Host "⚠️  CONTRACT EXPIRED: The active task contract has expired."
            Write-Host "    Task: $task"
            Write-Host "    Propose a new contract before continuing."
            exit 0
        }
    } catch {
        # Ignore parse errors — fail open
    }
}

# --- Extract target file from tool input ---
$toolInput = $env:CLAUDE_TOOL_INPUT
if (-not $toolInput) {
    exit 0
}

try {
    $inputData = $toolInput | ConvertFrom-Json
    $targetFile = $inputData.file_path
} catch {
    exit 0
}

if (-not $targetFile) {
    exit 0
}

# --- Scope check ---
$inScope = $false
foreach ($pattern in $scopeFiles) {
    if (-not $pattern) { continue }

    # Exact match
    if ($targetFile -eq $pattern) {
        $inScope = $true
        break
    }

    # Directory prefix match (pattern ends with /)
    if ($pattern.EndsWith("/") -and $targetFile.StartsWith($pattern)) {
        $inScope = $true
        break
    }

    # Glob match (simple wildcard via -like operator)
    if ($targetFile -like $pattern) {
        $inScope = $true
        break
    }
}

if (-not $inScope) {
    $scopeSummary = $scopeFiles -join ", "
    Write-Host "⚠️  CONTRACT SCOPE: Writing to '$targetFile' is outside the active contract."
    Write-Host "    Task: $task"
    Write-Host "    Declared scope: $scopeSummary"
    Write-Host "    Pause and confirm with user before proceeding."
}

exit 0
```

- [ ] **Step 2: Test the no-contract path**

Run from repo root (PowerShell):
```powershell
$env:CLAUDE_TOOL_INPUT = '{"file_path":"src/auth/user.ts"}'
pwsh -NonInteractive -File scripts/check-contract.ps1
Write-Host "Exit: $LASTEXITCODE"
```
Expected: no output, exit code 0.

- [ ] **Step 3: Test the out-of-scope WARN path**

Create test contract:
```powershell
New-Item -ItemType Directory -Force ".claude/contracts" | Out-Null
@'
{
  "task": "Test task",
  "created_at": "2026-01-01T00:00:00Z",
  "expires_at": "2099-12-31T23:59:59Z",
  "scope": {
    "files": ["src/auth/user.ts"],
    "operations": ["edit"]
  },
  "approved_by": "user",
  "status": "active"
}
'@ | Set-Content ".claude/contracts/active-task.json"
```

Run with out-of-scope file:
```powershell
$env:CLAUDE_TOOL_INPUT = '{"file_path":"src/new-feature.ts"}'
pwsh -NonInteractive -File scripts/check-contract.ps1
Write-Host "Exit: $LASTEXITCODE"
```
Expected: WARN output (3-4 lines starting with ⚠️), exit 0.

- [ ] **Step 4: Clean up test contract**

```powershell
Remove-Item ".claude/contracts/active-task.json" -Force
```

- [ ] **Step 5: Commit**

```bash
git add scripts/check-contract.ps1
git commit -m "feat: add check-contract.ps1 PowerShell equivalent of scope validation hook"
```

---

### Task 4: Wire hook into `templates/.claude/settings.json`

**Files:**
- Modify: `templates/.claude/settings.json`

Add a PreToolUse hook entry for the `Write|Edit` matcher. The command calls the PowerShell script first (for Windows), falls back to bash (Linux/macOS), fails open if neither is available (same pattern as `dangerous-commands`).

- [ ] **Step 1: Read the current settings.json**

Read `templates/.claude/settings.json` to confirm the current structure.

- [ ] **Step 2: Add the hook entry**

In the `"PreToolUse"` array, add a second entry after the existing Bash dangerous-commands hook:

```json
      {
        "matcher": "Write|Edit",
        "hooks": [
          {
            "type": "command",
            "command": "pwsh -NonInteractive -File scripts/check-contract.ps1 2>/dev/null || bash scripts/check-contract.sh 2>/dev/null || true"
          }
        ]
      }
```

The complete `"PreToolUse"` block should look like:

```json
    "PreToolUse": [
      {
        "matcher": "Bash",
        "hooks": [
          {
            "type": "command",
            "command": "pwsh -NonInteractive -File scripts/dangerous-commands.ps1 2>/dev/null || bash scripts/dangerous-commands.sh 2>/dev/null || true"
          }
        ]
      },
      {
        "matcher": "Write|Edit",
        "hooks": [
          {
            "type": "command",
            "command": "pwsh -NonInteractive -File scripts/check-contract.ps1 2>/dev/null || bash scripts/check-contract.sh 2>/dev/null || true"
          }
        ]
      }
    ]
```

- [ ] **Step 3: Verify JSON is valid**

```bash
python3 -c "import json; json.load(open('templates/.claude/settings.json')); print('JSON valid')"
```
Expected: `JSON valid`

- [ ] **Step 4: Commit**

```bash
git add templates/.claude/settings.json
git commit -m "feat: wire check-contract hook into settings.json PreToolUse for Write/Edit"
```

---

### Task 5: Add Task Contract Protocol to `templates/CLAUDE.md`

**Files:**
- Modify: `templates/CLAUDE.md`

Add a `## Task Contract Protocol` section. Based on the spec, it goes after `## Governed Assistance Model` and before `## Security Guardrails` — keeping governance content together.

- [ ] **Step 1: Read the current CLAUDE.md**

Read `templates/CLAUDE.md` to confirm current section order and find the exact insertion point.

- [ ] **Step 2: Insert the new section**

Insert the following block immediately before `## Security Guardrails`. The proposal-format example inside uses a triple-backtick code fence — that is intentional and correct for CLAUDE.md.

````markdown
## Task Contract Protocol

Before starting any multi-file task, propose a task contract and wait for approval:

**When a contract is required:** Any task touching more than one file, or the user's request implies a new feature / refactor / migration. Skip for: single-file edits, typos, config-value changes, changes clearly <20 lines.

**Proposal format:**
```
**Task Contract Proposal**

Task: <one-sentence description>

Scope:
- <file or path> (<operation>)
- <file or path> (<operation>)

Type "approved" to begin, or tell me what to adjust.
```

**On "approved":** Write `.claude/contracts/active-task.json` with the schema from `docs/CONTRACTS-GUIDE.md`. Set `expires_at` to 8 hours from now.

**During work:** If the hook warns that a write is outside the declared scope, pause and confirm with the user before proceeding.

**On completion:** Update `status` to `"complete"` in the contract file and note it in the conversation.

**Cancelling:** If the user says "cancel contract" or "stop" mid-task, write `"status": "cancelled"` to the contract file.
````

- [ ] **Step 3: Verify CLAUDE.md line count**

```bash
wc -l templates/CLAUDE.md
```
Expected: Under 170 lines (the file was 134 lines; adding ~35 lines for the new section).

- [ ] **Step 4: Commit**

```bash
git add templates/CLAUDE.md
git commit -m "docs: add Task Contract Protocol section to CLAUDE.md"
```

---

### Task 6: Write `docs/CONTRACTS-GUIDE.md` and push

**Files:**
- Create: `docs/CONTRACTS-GUIDE.md`

- [ ] **Step 1: Write the guide**

````markdown
# Contracts Guide

Task contracts are machine-readable scope declarations Claude writes before touching files. They formalize the "propose before doing" principle from `CLAUDE.md` with a JSON artifact the hook layer can validate.

## How It Works

1. Claude proposes a contract in the conversation (task + file scope)
2. User types "approved"
3. Claude writes `.claude/contracts/active-task.json`
4. The `check-contract` hook warns if Claude writes outside the declared scope
5. On completion, Claude sets `status: "complete"` in the contract

## Contract Schema

```json
{
  "task": "Human-readable task description",
  "created_at": "2026-05-22T14:00:00Z",
  "expires_at": "2026-05-22T22:00:00Z",
  "scope": {
    "files": [
      "src/auth/user.ts",
      "src/db/migrations/003_add_verification.sql",
      "tests/auth.test.ts"
    ],
    "operations": ["create", "edit"]
  },
  "approved_by": "user",
  "status": "active"
}
```

### Status values

| Value | Meaning |
|-------|---------|
| `active` | Work is in progress |
| `complete` | Task finished normally |
| `cancelled` | User cancelled mid-task |

Expired contracts (current time past `expires_at`) are treated as inactive by the hook.

## Scope Matching Rules

A write is **in scope** if the target file:
1. **Exactly matches** a `scope.files` entry, OR
2. **Starts with** a `scope.files` entry that ends in `/` (directory prefix), OR
3. **Matches** a `scope.files` entry interpreted as a glob pattern (`fnmatch`)

Examples:
```
scope.files: ["src/auth/user.ts"]
"src/auth/user.ts"          → IN SCOPE (exact match)
"src/auth/token.ts"         → OUT OF SCOPE

scope.files: ["src/auth/"]
"src/auth/user.ts"          → IN SCOPE (prefix match)
"src/other/file.ts"         → OUT OF SCOPE

scope.files: ["src/**/*.ts"]
"src/auth/user.ts"          → IN SCOPE (glob match)
"src/db/schema.sql"         → OUT OF SCOPE
```

## Hook Behavior

The hook fires on every Write and Edit tool call (PreToolUse). It:
- **Silent pass** when: no contract exists, contract is inactive (complete/cancelled), or target is in scope
- **Prints a WARN** when: target file is outside the declared scope, or contract is expired
- **Always exits 0** — never blocks writes (WARN tier)

The WARN output is visible in Claude's context so Claude can pause and check with you.

## When to Skip Contracts

No contract needed for:
- Single-file edits
- Typo / comment fixes
- Config-value changes
- Work clearly under 20 lines total

## Files

| File | Purpose |
|------|---------|
| `.claude/contracts/active-task.json` | The live contract (gitignored) |
| `scripts/check-contract.sh` | POSIX hook script |
| `scripts/check-contract.ps1` | PowerShell hook script |
| `templates/.claude/contracts/active-task.json.example` | Schema reference |

## Relationship to Other Layers

Contracts sit between the advisory layer (CLAUDE.md) and the structural enforcement layer (hooks):

| Layer | What it does |
|-------|-------------|
| CLAUDE.md protocol | Tells Claude when and how to propose a contract |
| `.claude/contracts/active-task.json` | Machine-readable record of approved scope |
| `check-contract` hook | Surfaces scope violations during work |
| Dangerous-commands hook | Blocks/confirms dangerous operations (separate concern) |
| CI governance | Enforces codebase invariants after push |
````

- [ ] **Step 2: Verify CONTRACTS-GUIDE.md line count**

```bash
wc -l docs/CONTRACTS-GUIDE.md
```
Expected: Under 130 lines (well within the 800-line limit for non-memory-bank docs).

- [ ] **Step 3: Verify shellcheck still passes (regression check)**

```bash
# Build dir list only from dirs that exist (same logic as CI)
SHELL_DIRS=()
[ -d scripts ] && SHELL_DIRS+=(scripts)
[ -d templates/scripts ] && SHELL_DIRS+=(templates/scripts)
if [ "${#SHELL_DIRS[@]}" -gt 0 ]; then
  find "${SHELL_DIRS[@]}" -name "*.sh" -print0 | xargs -r -0 shellcheck --severity=error
fi
echo "shellcheck: OK"
```
Expected: `shellcheck: OK`. The new `check-contract.sh` is included in this check.

- [ ] **Step 4: Commit and push**

```bash
git add docs/CONTRACTS-GUIDE.md
git commit -m "docs: add CONTRACTS-GUIDE.md reference for task contract system"
git push origin master
```

- [ ] **Step 5: Verify CI passes**

```bash
gh run list --limit 3
```
Expected: A "Governance" run appears with status completing. Once done:
```bash
gh run view --log-failed
```
Expected: All three jobs (File Size, Forbidden Patterns, Secret Scan) green.

**Common failure modes:**
- `shellcheck` error in `check-contract.sh`: fix the specific line and re-push
- `file-size` FAIL: the new script or guide exceeded thresholds — check line counts. `docs/CONTRACTS-GUIDE.md` and `scripts/check-contract.sh` are non-memory-bank so limit is 800 lines.
- `forbidden-patterns` credential grep: a false positive in the example JSON — adjust the `{8,}` pattern exemption if needed (unlikely, since example values are short)

---

## Verification Checklist (Post-Push)

- [ ] `scripts/check-contract.sh` exists and passes shellcheck
- [ ] `scripts/check-contract.ps1` exists
- [ ] `templates/.claude/contracts/.gitignore` exists with `*.json` content
- [ ] `templates/.claude/contracts/active-task.json.example` exists with complete schema
- [ ] `docs/CONTRACTS-GUIDE.md` exists with scope-matching examples
- [ ] `templates/.claude/settings.json` has a `Write|Edit` PreToolUse hook entry
- [ ] `templates/CLAUDE.md` has a `## Task Contract Protocol` section
- [ ] `.gitignore` has `.claude/contracts/*.json` entry
- [ ] CI governance run is green (all three jobs pass)
- [ ] Manual test: create a contract, write in-scope file → no WARN; write out-of-scope file → WARN printed, exits 0
