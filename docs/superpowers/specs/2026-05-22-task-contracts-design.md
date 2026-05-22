# Task Contracts — Design

## Context

The Personal Memory Bank repo completed Sub-projects A (hook coverage), D (philosophy docs), and C (CI governance). The four-layer enforcement stack is documented and running. Sub-project B adds **task contracts** — a lightweight machine-readable declaration Claude writes before touching files, backed by a hook that validates scope.

The governed-assistance model already says "Claude proposes; the user approves." Task contracts make that approval machine-readable: a JSON file Claude writes only after the user explicitly says "approved," with a hook that surfaces scope violations if Claude subsequently writes outside the declared boundary.

## Design

### Approach: Lightweight JSON + WARN-tier hook

One JSON file at `.claude/contracts/active-task.json`. A PreToolUse hook on Write/Edit reads it and WARNs when the target file is outside the declared scope or the contract is expired. Contracts are gitignored session artifacts — they record approval, not code.

**Why WARN and not BLOCK?**
The dangerous-commands hook already covers BLOCK-tier enforcement. Contracts are for *scope transparency*, not catastrophe prevention. A WARN surfaces the drift to Claude (who can then pause and check with the user) without hard-blocking legitimate mid-task redirections. The layered model works: advisory (CLAUDE.md protocol) + structural (hook WARN) = defense in depth without brittleness.

**Why a file and not just conversational?**
A JSON file is machine-readable by the hook, version-inspectable, and survives context compaction. The hook can check it without relying on Claude remembering what was approved in a conversation that may have been compacted.

### Contract Schema

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

**Fields:**

| Field | Type | Description |
|-------|------|-------------|
| `task` | string | What Claude is doing (shown in hook output) |
| `created_at` | ISO 8601 | When the contract was approved |
| `expires_at` | ISO 8601 | `created_at + 8 hours` — end of working session |
| `scope.files` | string[] | Exact paths or glob patterns in scope |
| `scope.operations` | string[] | `create`, `edit`, `delete`, `run` |
| `approved_by` | string | Always `"user"` (reserved for future multi-approver) |
| `status` | string | `active`, `complete`, `cancelled` |

### Proposal Flow

When Claude is about to start work that would touch multiple files:

1. **Claude presents the proposal in conversation:**

```
**Task Contract Proposal**

Task: Add email verification columns to users table

Scope:
- src/auth/user.ts (edit)
- src/db/migrations/003_add_verification.sql (create)
- tests/auth.test.ts (edit)

Expires: 8 hours from approval

Type "approved" to begin, or tell me what to adjust.
```

2. **User types "approved"** (or short forms: "ok", "yes, go ahead")
3. **Claude writes `.claude/contracts/active-task.json`** with the schema above
4. **Work proceeds** — hook validates each write against the scope
5. **On completion:** Claude updates `status` to `"complete"` and notes it in the conversation

### Hook Behavior (PreToolUse on Write|Edit)

The hook at `scripts/check-contract.sh` (and `.ps1` for PowerShell):

```
Input:  CLAUDE_TOOL_INPUT env var (JSON with file_path)

Logic:
  1. If no contract file → exit 0 (silent pass)
  2. If contract status != "active" → exit 0 (silent pass)
  3. If contract expired → print WARN, exit 0
  4. If file_path matches a scope entry → exit 0 (silent pass)
  5. If file_path does NOT match any scope entry → print WARN, exit 0
```

**Scope matching:** A file is in scope if its path:
- Exactly matches a scope entry, OR
- Starts with a scope entry that ends in `/` (directory prefix), OR
- Matches a scope entry treated as a glob pattern (`fnmatch`)

**WARN output format:**
```
⚠️  CONTRACT SCOPE: Writing to 'src/new-feature.ts' is outside the active contract.
    Contract task: Add email verification columns to users table
    Declared scope: src/auth/user.ts, src/db/migrations/..., tests/auth.test.ts
    Pause and confirm with user before proceeding.
```

Exit 0 in all cases — Claude reads the output and pauses to check with the user.

### Skip Criteria

No contract needed for:
- Single-file edits
- Typos, comment fixes, config value changes
- Changes clearly <20 lines total
- Work explicitly described as "quick fix" by the user

This mirrors the existing workflow standard skip rule (Phases 1–3 skip for trivial work).

### Lifecycle States

```
proposed (in conversation)
    ↓ user types "approved"
active (file written)
    ↓ task complete
complete (status updated) or
cancelled (user says "stop" / "cancel contract") or
expired (expires_at passed)
```

When starting a new task, Claude checks for an existing contract. If one exists and is active, it either continues under it (if same scope) or completes it first before proposing a new one.

## Files to Create

- `scripts/check-contract.sh` — POSIX hook script
- `scripts/check-contract.ps1` — PowerShell hook script
- `templates/.claude/contracts/.gitignore` — gitignore for contract files (contents: `*.json`)
- `templates/.claude/contracts/active-task.json.example` — schema reference for new projects
- `docs/CONTRACTS-GUIDE.md` — user-facing reference

## Files to Modify

- `templates/.claude/settings.json` — add PreToolUse hook entry for Write|Edit
- `templates/CLAUDE.md` — add `## Task Contract Protocol` section
- `.gitignore` (repo root) — add `.claude/contracts/*.json` entry

## Verification

1. Write a contract with one file in scope. Use Write tool on that file → hook exits 0, no warning
2. With same contract, write to a file NOT in scope → hook prints WARN, exits 0
3. Create a contract with `expires_at` set to the past → hook prints expiry warning, exits 0
4. No contract file → hook exits 0, no output (silent pass)
5. Contract with `status: "complete"` → hook exits 0, no output (treated as inactive)
6. Shellcheck on `check-contract.sh` with `--severity=error` → no errors (CI gate)
