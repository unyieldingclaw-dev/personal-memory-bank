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

**What happens:**
- Map out every file to be created or modified
- Break implementation into bite-sized tasks (2–5 minutes each)
- Each task includes: exact file paths, complete code, exact test commands, expected output
- No placeholders — if a step changes code, show the code

Create the implementation plan as a draft in `.claude/plans/YYYY-MM-DD-slug.md`.

After user approval, promote the plan with:
```bash
mb plan promote .claude/plans/YYYY-MM-DD-slug.md
```

This copies the plan to `docs/plans/YYYY-MM-DD-slug.md` and sets `status: planned`, unless the draft's
frontmatter already carries a later status, which is kept. The draft stays in `.claude/plans/`.

**Output:** the promoted `docs/plans/YYYY-MM-DD-slug.md`, committed to git.

**Rules:**
- Do NOT treat `.claude/plans/` as durable memory. These are scratch files — gitignored.
- Do NOT load all plans at session start. Summarize only active next steps in `memory-bank/activeContext.md`.
- `progress.md` remains a summary file. Full implementation detail belongs in the plan file.

**Skip when:** No spec was needed.

---

### Phase 3.5 — Independent Plan Review (superseded by the Pre-Approval Protocol)

Superseded by the Pre-Approval Protocol section below (approved 2026-09-21, in force from the merge
that added it).
- **Every approval ask** now gets that protocol's pre-ask checks, which Claude runs itself.
- **The independent review this phase recommended** (a fresh agent with no context from writing the
  artifact) runs only when the ask hits CLAUDE.md's escalation triggers, through the Opus
  `opposition` agent. Writing a spec or plan is one of those triggers, so specs and plans still get
  it.

The heading stays so existing references to "Phase 3.5" still resolve.

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

**Test Design Principles:**

1. **Test the public interface (the seam), not internals.** A test exercises what a caller can observe — return values, visible side effects, errors — never private state or implementation-specific call sequences. *Why:* tests coupled to internals break on every refactor even when behavior is unchanged, training people to treat red tests as noise instead of signal.

2. **One test per observable behavior — write, implement, verify, commit — before starting the next.** Do not write a batch of tests up front and implement them as a batch. *Why:* batching hides which test is driving which code; a partially-passing batch conceals which minimal-code step actually worked versus which is untested guesswork.

3. **Compute the expected result from an independent source of truth.** Never derive a test's expected value from the same logic or algorithm being tested — that only proves the code agrees with itself, not that either is correct. *Why:* e.g. testing a slug generator by re-implementing the slugify logic inline in the test asserts self-consistency, not correctness; a genuinely wrong algorithm passes its own test every time. Use hand-computed values or a trusted reference, not restated logic.

4. **Start with a tracer bullet.** Before implementing a task's individual units, write and pass one test exercising the smallest meaningful path through the task end-to-end — not a unit in isolation. *Why:* this surfaces integration/wiring problems (imports, plumbing, environment) immediately, instead of after building N isolated units that turn out not to connect.

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

Stage in a command of its own, then commit: the commit review gate runs before a chained `git add` or `git commit -a` stages anything, and refuses while any tracked change is unstaged. To commit only some files, set the rest aside with a tagged stash (`git stash push -m <unique-tag> -- <paths>`), re-run `/code-review` on what remains, and commit. Then restore them with `git stash apply <sha>` (the SHA from `git stash list --format='%H %gs'`) and drop that entry by its current `stash@{n}`. The stash stack is shared across worktrees, so never use a bare `git stash pop`.

Never commit `.env`, credentials, or unrelated changes.

---

## Quick Reference

| Phase | Skip when | Output |
|-------|-----------|--------|
| 1. Brainstorm | Trivial change | Agreed approach |
| 2. Spec | No spec needed | docs/specs/*.md |
| 3. Plan | No spec needed | docs/plans/*.md |
| 3.5 Independent Plan Review (superseded) | — | See Pre-Approval Protocol |
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
| Pre-Approval Protocol | No skill. The procedure is in this file; the `pre-approval-check` Stop hook checks that its sections are present; `opposition` handles escalation-list asks |
| Implement | `superpowers:executing-plans` or `superpowers:subagent-driven-development` |
| Simplify | `code-simplifier` plugin |
| Security Review | `security` plugin or `/security-review` command |

Run `/feature-dev` in Claude Code to trigger the full workflow automatically.

## Pre-Approval Protocol

**Applies to every message that asks the user to approve or choose:** design recommendations, specs,
plans, task contracts, "should I proceed". It is not a phase: it runs inside whichever phase produces
the ask, so the workflow stays at 7 phases. It supersedes Phase 3.5. Design and evidence:
`docs/superpowers/specs/2026-09-21-pre-approval-protocol-design.md`.

**Before the ask:**

1. **Run the checks the options depend on.** Execute rather than re-read. Re-derive every number
   relied on, measure anything performance-relevant, read config instead of assuming it, and check
   each claim about a file against the file as it is now. Checks must not mutate the shared working
   tree: cite the last run of `tests/run.sh`, which moves `VERSION` aside, instead of running it
   mid-ask.
2. **If the ask hits the trigger list in CLAUDE.md's Token Budget section** ("Escalate on
   observable triggers"; referenced, not copied here), dispatch the `opposition` agent after step 1.
   Give it the artifact, the step-1 findings, and the instruction to attack premises and re-derive
   the load-bearing numbers. Retry once on failure; if it fails again, say so in the findings. Use
   CLAUDE.md's list, not this file's own **Token Budget** bullet below: that one is narrower, and
   omits writing a design spec or implementation plan, the trigger this protocol relies on most.
3. **Fix what is within the thing being proposed.** Anything that would change a decision the user
   already made goes under the decision instead.
4. **Send the ask with these sections, in the message's final text block:**

   ```
   ## Findings
   | # | Question | How I checked (command or source) | Result |

   ## Recommendation
   <what I recommend, and why>
   <holes I could not close>
   <the decision needed>
   ```

   - Every row names a re-runnable command or source.
   - When nothing needed checking, the table still appears, with one row saying so.
   - When the escalation list fired, one row carries the `opposition` verdict.
   - A question that is not an approve-or-choose ask still needs a Recommendation.
   - A Task Contract proposal in CLAUDE.md's format is an approval ask too. Put both sections
     above its `Type "approved"` line. The hook checks only that they are present somewhere in the
     message, and sends the proposal back if they are not.

**Enforcement:**
- **The hook:** `pre-approval-check` (PMB-only; `docs/HOOKS-GUIDE.md` §2) sends back, once, any
  turn that ends in an ask without these sections.
- **False positives:** reply `Not an approval ask:` with one line of why. For a clarifying question,
  reply `No recommendation applies:`.
- **What it checks:** the hook confirms the sections exist, not that the checks behind them were
  adequate. Adequacy stays with the `opposition` pass.
- **What it is not:** a gate.
  - It checks a turn once; the continuation after a block always passes.
  - It detects asks heuristically.
  - It fails open on any error.
  - It can be switched off (below).

  It adds friction toward the protocol. Running the checks stays Claude's job.
- **Kill switch:** `"PMB_PRE_APPROVAL": "off"` in the `.claude/settings.json` env block. It
  takes effect on the next turn.

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
