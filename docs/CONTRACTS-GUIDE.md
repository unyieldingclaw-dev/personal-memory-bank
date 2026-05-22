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
