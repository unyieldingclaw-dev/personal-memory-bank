# Workflow Standard

Structured feature development from idea to committed code. Prevents the most common AI coding failure mode: writing code before understanding what to build.

## The Problem

AI assistants default to writing code immediately. This produces:
- Code that solves the wrong problem
- Designs that don't survive contact with the actual codebase
- Security issues discovered after implementation
- Sessions that burn context on rework

## The Solution

A 7-phase workflow that front-loads understanding and defers code until the design is locked.

## Phases

### Phase 1 — Brainstorm

**Trigger:** Any non-trivial feature, bug fix with unclear root cause, or architectural change.

**What happens:**
- Explore the codebase to understand existing patterns
- Ask clarifying questions one at a time to understand purpose, constraints, success criteria
- Propose 2–3 approaches with trade-offs
- Get design approved before writing any code

**Output:** Verbal agreement on approach.

**Skip when:** Single-file fix, typo, config value change, renaming, or the change is obvious and < 20 lines.

---

### Phase 2 — Spec

**What happens:**
- Write the validated design to `docs/specs/YYYY-MM-DD-<topic>.md`
- Include: context (why), architecture, components, data flow, error handling, verification steps
- Self-review: no TBDs, no contradictions, no ambiguity
- Get user approval before proceeding

**Output:** `docs/specs/YYYY-MM-DD-<topic>.md` committed to git.

**Skip when:** The change is too small to warrant a spec (single function, obvious fix).

---

### Phase 3 — Plan

Create the implementation plan as a draft in `.claude/plans/YYYY-MM-DD-slug.md`.

After user approval, promote the plan with:
```bash
mb plan promote .claude/plans/YYYY-MM-DD-slug.md
```

This moves the plan to `docs/plans/YYYY-MM-DD-slug.md` and sets `status: planned`.

**Rules:**
- Do NOT treat `.claude/plans/` as durable memory. These are scratch files — gitignored.
- Do NOT load all plans at session start. Summarize only active next steps in `memory-bank/activeContext.md`.
- `progress.md` remains a summary file. Full implementation detail belongs in the plan file.

**Skip when:** No spec was needed.

---

### Phase 3.5 — Independent Plan Review (advisory — not one of the 7 counted phases)

Not a gate. This project's `memory-bank/projectbrief.md` fixes the workflow at 7 phases as a non-negotiable requirement, so this step is deliberately scoped as a recommended practice inserted between Plan and Implement, not an 8th phase — matching the precedent `.claude/commands/change-review.md`'s own "Step 3.5: Baseline Repo Health" already sets for a non-counted, informational step.

**Why:** self-review, however adversarial, shares the blind spots of whoever wrote the plan. A 14-task plan for this repo's own review-gate mechanism passed its author's self-review (which found 3 real gaps) — a separately-dispatched agent with no context from writing it then found 8 more real, file:line-verified defects, including a Blocking-severity bug the self-review missed. See `docs/superpowers/specs/2026-08-12-investigation-integrity-design.md`'s "independent review discipline" (mechanism 3) for the full mechanism.

**What happens:**
- Dispatch a fresh Agent, no context from writing the plan, on a capable model — never a cost-optimized/cheap model (this project's subagent default may be cost-optimized; override it)
- It independently verifies the plan against its spec and the actual current repo state, including tracing shell-script error-handling behavior and templates/ mirror consistency
- Findings use this repo's `standards/CODE-REVIEW.md` vocabulary (`VERIFIED`/`INFERRED`/`SPECULATIVE`, `Severity`, `Blocking`)
- Any `Blocking: true` finding should be fixed before proceeding; non-blocking findings are disclosed in the plan's Design Note, not silently dropped
- If the review agent itself fails to complete, retry once; if still blocked, disclose to the user and get an explicit decision before proceeding without one

**Output:** A plan verified by someone other than its own author, or an explicit, disclosed decision to proceed without one.

**Recommended for:** any plan with real consequence. Lighter-weight for small or low-risk plans — use judgment, since this step is advisory rather than a hard-and-fast gate.

---

### Phase 4 — Implement (TDD)

**Verification-First:** Before asking Claude to start implementing, state upfront:
- Test cases or expected outputs (even informal: "function should return X given Y")
- The success criteria (what does "done" look like?)
- Any constraints (must not change the API, must stay under N ms, etc.)

This is the single highest-leverage prompt engineering habit — it cuts correction cycles significantly.

For each task in the plan:

```
1. Write the failing test
2. Run it — verify it fails with the expected error
3. Write the minimal code to make it pass
4. Run it — verify it passes
5. Commit
```

Never write implementation before the failing test exists.

**Commit frequency:** After each passing test or logical unit. Never accumulate more than one unit of work in a commit.

---

### Phase 5 — Simplify

After implementation is complete:
- Review all changed files for clarity, consistency, and maintainability
- Remove dead code, redundant logic, unnecessary abstraction
- Rename for clarity where needed
- Do NOT change behavior — only improve readability

**Output:** Clean, committed code.

---

### Phase 6 — Security Review

Scan the current diff against 9 patterns:

| Severity | Patterns |
|----------|---------|
| `[CRITICAL]` | Hardcoded secrets, command injection, SQL injection |
| `[HIGH]` | Unvalidated external input, missing auth checks, insecure deserialization |
| `[MEDIUM]` | XSS, exposed error details, unsafe eval/exec |
| `[LOW]` | Patterns safe now but risky under future changes |

**Resolution:** All `[CRITICAL]` and `[HIGH]` findings must be resolved before proceeding. `[MEDIUM]` and `[LOW]` are documented in the PR.

---

### Phase 7 — Commit

```bash
git add <specific files — never git add -A blindly>
git commit -m "feat: <what was built and why in one line>"
```

Never commit `.env`, credentials, or unrelated changes.

---

## Quick Reference

| Phase | Skip when | Output |
|-------|-----------|--------|
| 1. Brainstorm | Trivial change | Agreed approach |
| 2. Spec | No spec needed | docs/specs/*.md |
| 3. Plan | No spec needed | docs/plans/*.md |
| 3.5 Independent Plan Review (advisory) | Small/low-risk plan | Verified plan or documented decision to proceed without |
| 4. Implement | — | Committed, tested code |
| 5. Simplify | — | Clean committed code |
| 6. Security Review | — | Resolved findings |
| 7. Commit | — | Clean commit |

## Claude Code Integration

If using the Superpowers plugin, each phase maps to a skill:

| Phase | Skill |
|-------|-------|
| Brainstorm | `superpowers:brainstorming` |
| Plan | `superpowers:writing-plans` |
| Independent Plan Review (advisory) | No dedicated skill yet — dispatch a fresh `Agent` (general-purpose or Explore) on a capable model, self-contained prompt |
| Implement | `superpowers:executing-plans` or `superpowers:subagent-driven-development` |
| Simplify | `code-simplifier` plugin |
| Security Review | `security` plugin or `/security-review` command |

Run `/feature-dev` in Claude Code to trigger the full workflow automatically.

## Context Management

### When to Hand Off
Trigger a handoff when context reaches 40% or the user types "Handoff":
1. Stop all work immediately
2. Write `handoff.md` to the project root (format: accomplishments, files changed, service state, commands to resume, pending tasks)
3. Respond only: "Handoff ready at `handoff.md`. Start a new conversation."
4. Do not continue

On next session: read `handoff.md` first, merge into Memory Bank, delete it, then continue.

### Token Budget
- **Default model:** Sonnet handles 90%+ of tasks
- **Escalate to Opus** only for: complex architecture, large multi-file refactors, deep cross-file debugging. Switch back after.
- **Compact at task boundaries** (not mid-task): after planning, after debugging, before switching context
- Auto-compact fires at the percentage set by `CLAUDE_AUTOCOMPACT_PCT_OVERRIDE` in `.claude/settings.json`
- Manual compact at ~35% stays ahead of mid-task interruption

## Cursor Integration

Add to `.cursor/rules/workflow.mdc`:

```yaml
---
alwaysApply: true
---

# Development Workflow

For any non-trivial feature: brainstorm → spec → plan → implement (TDD) → simplify → security review → commit.

**Skip to Phase 4** for: single-file fixes, typos, config changes, or changes < 20 lines.

Never write code before the design is approved.
Never commit without running tests.
Never merge with [CRITICAL] or [HIGH] security findings.
```
