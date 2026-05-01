# Personal Memory Bank — 2025 Modernization Design

**Date:** 2026-05-01
**Status:** Approved for implementation

## Context

The Personal Memory Bank standard was forked from an enterprise repo in April 2026. It is clean of T-Mobile/enterprise content and has solid coverage of security, workflow, and logging. However, Claude Code released several major features in mid-to-late 2025 (hooks, `.claude/agents/`, skills) that are not yet in the standard. The always-loaded files (CLAUDE.md, AGENTS.md) also have duplication and verbosity that inflates the token budget on every session start. Research on 2,500+ repos and Anthropic's 2025 best-practices guide surface a verification-first pattern and a lean-CLAUDE.md principle not yet reflected.

**Goal:** Full 2025 parity — add missing Claude Code features, slim always-loaded files, update /code-review with AI-era antipatterns, differentiate CLAUDE.md vs AGENTS.md by actual tool purpose.

## Files Modified

| File | Change | Lines |
|------|--------|-------|
| `templates/CLAUDE.md` | Slim + add Tools section + verification-first | 107 → ~75 |
| `templates/AGENTS.md` | Differentiate as tool-agnostic; strip Claude Code-specific refs | 93 → ~60 |
| `.cursor/rules/memory-bank.mdc` | Mirror CLAUDE.md concept changes | update |
| `standards/WORKFLOW.md` | Add Verification-First pattern in Phase 4 | +6 lines |
| `standards/SECURITY-GUARDRAILS.md` | Tighten enforcement table + incident response | 387 → ~280 |
| `standards/CODE-QUALITY.md` | Tighten Karpathy section prose | 385 → ~300 |
| `.claude/commands/code-review.md` | Add AI antipatterns + dependency check + prompt injection | update |
| `.cursor/rules/code-review.mdc` | Mirror code-review.md changes | update |

## Files Added

| File | Purpose |
|------|---------|
| `templates/.claude/settings.json` | Hooks template — dangerous-command blocker + stop notification |
| `docs/HOOKS-GUIDE.md` | Explains hooks vs CLAUDE.md, documents default hooks, per-project stubs |
| `.claude/agents/security-reviewer.md` | Focused security review subagent — read-only |
| `.claude/agents/researcher.md` | Codebase investigation subagent — keeps main context clean |
| `templates/.claude/agents/security-reviewer.md` | Template mirror |
| `templates/.claude/agents/researcher.md` | Template mirror |

## Key Design Decisions

### CLAUDE.md vs AGENTS.md Split
- `CLAUDE.md` = Claude Code–specific (hooks, /commands, MCP, agents directory)
- `AGENTS.md` = Tool-agnostic (works with Claude, Gemini, Codex, any agent)

### Hooks vs CLAUDE.md
- CLAUDE.md is advisory — Claude can drift from its instructions
- Hooks are deterministic — always run at lifecycle points, can't be ignored
- Default hooks: dangerous-command blocker (PreToolUse) + stop notification (Stop)

### Verification-First Pattern
Research shows stating test cases/expected output upfront before asking for implementation cuts correction cycles significantly. Added to WORKFLOW.md Phase 4 and CLAUDE.md.

### /code-review Updates
The 6-step subagent architecture is kept intact. Two targeted additions:
- Subagent A: dependency validation (hallucinated packages) + prompt injection for LLM code
- Subagent C: AI-era antipatterns (over-abstraction, unnecessary wrappers, hallucinated imports)

## Implementation Tasks

1. Write this spec doc (Task 1 — this task)
2. Slim templates/CLAUDE.md
3. Differentiate templates/AGENTS.md
4. Add hooks template + HOOKS-GUIDE.md
5. Add agent definitions (security-reviewer, researcher)
6. Update /code-review command and Cursor mirror
7. Add Verification-First to WORKFLOW.md
8. Trim SECURITY-GUARDRAILS.md
9. Trim CODE-QUALITY.md
10. Update memory-bank.mdc
11. Final verification pass
