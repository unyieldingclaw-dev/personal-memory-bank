# AI Coding Rules

## Memory Bank

At the start of every session, if `memory-bank/` exists in the project root:
1. Read `memory-bank/projectbrief.md` — non-negotiable requirements and constraints
2. Read `memory-bank/systemPatterns.md` — architecture decisions and patterns to follow
3. Read `memory-bank/techContext.md` — tech stack, dependencies, environment
4. Read `memory-bank/activeContext.md` — current focus and next steps
5. Read `memory-bank/progress.md` — what is complete and planned

Never ask for information already in Memory Bank. Never violate constraints in projectbrief.md.
Never write secrets, credentials, API keys, PII, production data, or full code dumps to memory-bank/ files.

At session end or before context hits 80%:
1. Update `memory-bank/activeContext.md` — current state, key decisions, blockers
2. Update `memory-bank/progress.md` — what shipped, what is queued
3. If context is at 80%, create `handoff.md` and stop (see Handoff Protocol below)

## Verification-First

Before implementing: state test cases, expected output, or success criteria upfront.
This is the single highest-leverage habit for improving output quality.

## Security Guardrails

Three tiers — `standards/SECURITY-GUARDRAILS.md` has the full enumerated lists.

- **BLOCK** (refuse): committing secrets, force-push to main/master, destructive system commands, exposing secrets in logs, unverified package recommendations (slopsquatting), hardcoded credentials.
- **CONFIRM** (ask first): deletions, file overwrites without reading, bulk ops on >3 files, `git commit --amend`, `--no-verify`, force-push to any branch, interactive rebase, `DROP`/`DELETE` without `WHERE`/`TRUNCATE`, schema changes, edits to `*auth*`/`*security*`/`*permission*`, CI/CD config changes.
- **WARN** (note the risk): >5 files or >200 lines, new files, missing tests, skipping verification.

## Workflow

Always follow this sequence for any non-trivial feature:

1. **Brainstorm** — Understand requirements, explore codebase, propose 2–3 approaches, get design approved before writing code
2. **Spec** — Write the validated design to `docs/specs/YYYY-MM-DD-<topic>.md`
3. **Plan** — Create a bite-sized implementation plan with exact file paths and complete code
4. **Implement** — TDD: write failing test → implement → verify passing → commit
5. **Simplify** — Review changed code for clarity and consistency without changing behavior
6. **Security Review** — Scan diff for secrets, injection, XSS, and related patterns; see `standards/SECURITY-GUARDRAILS.md`
7. **Commit** — Stage and commit with a descriptive message

**Skip to step 4** for: single-file fixes, typos, config changes, or changes < 20 lines.

## Code Quality

- Never hardcode secrets — use environment variables or a secrets manager
- Validate inputs only at system boundaries (user input, external APIs)
- Remove dead code before committing — no unused functions, variables, or imports
- Each function does one thing
- Default to no comments — only add one when the WHY is non-obvious
- Run tests and report results before claiming done
- **UI code only:** apply WCAG 2.1 AA basics (semantic HTML, alt text, form labels, keyboard nav)

## Handoff Protocol

When context hits 80% or user types "Handoff":
1. STOP all work immediately
2. CREATE `handoff.md` with: accomplishments, files modified, service state, commands to resume, pending tasks
3. RESPOND only: "Handoff ready at `handoff.md`. Start a new conversation."
4. STOP — do not continue

When starting a new conversation: check for `handoff.md` first, read it, merge into Memory Bank, delete it, continue.
