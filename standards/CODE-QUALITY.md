# Code Quality Standard

Generic code quality rules for AI-generated code, with an extension system for language-specific patterns.

## Overview

AI coding assistants can generate inconsistent code if not given clear guidelines. This standard ensures:
- Verification before claiming completion
- Consistent commenting practices
- Proper error handling
- Clean code structure

## Generic Core Rules

These rules apply to **all languages**.

### 1. Verification

**Never claim "done" without evidence.**

| Rule | Implementation |
|------|----------------|
| Run tests after changes | Execute test suite, report results |
| Check for lint errors | Run linter, fix issues |
| Verify build succeeds | Run build command, confirm no errors |
| Confirm functionality | Describe what was tested |

```
❌ "Done! I've implemented the feature."

✅ "Done! I've implemented the feature.
    - Tests passing: 47/47
    - Lint: No errors
    - Build: Successful
    - Tested: Created user, verified in database"
```

### 2. Comments

**Comment the WHY, not the WHAT.**

| Rule | Example |
|------|---------|
| No obvious comments | ❌ `// Import the module` |
| WHY comments for non-obvious logic | ✅ `// Use UTC to avoid timezone bugs in scheduling` |
| No commented-out code | ❌ `// oldFunction()` |
| Document breaking changes | ✅ `// BREAKING: Changed from sync to async` |

```python
# ❌ BAD - Obvious comment
# Loop through users
for user in users:
    process(user)

# ✅ GOOD - Explains WHY
# Process sequentially to avoid rate limiting on external API
for user in users:
    process(user)
```

### 3. Structure

**Keep code organized and maintainable.**

| Rule | Rationale |
|------|-----------|
| Imports at top of file | Predictable location, easy to find |
| No inline imports | Avoid hidden dependencies |
| Prefer editing over creating files | Reduce code sprawl |
| Small incremental changes | Easier to review and debug |
| Single responsibility | Functions do one thing well |

### 4. Error Handling

**Handle all error cases explicitly.**

| Rule | Implementation |
|------|----------------|
| Never swallow exceptions silently | Always log or re-raise |
| Meaningful error messages | Include context, not just "Error" |
| Handle edge cases | Empty inputs, null values, boundaries |
| Graceful degradation | Partial results better than crash |

```python
# ❌ BAD - Silent swallow
try:
    result = api_call()
except:
    pass

# ✅ GOOD - Explicit handling
try:
    result = api_call()
except ConnectionError as e:
    logger.warning("API unavailable, using cached data", error=str(e))
    result = get_cached_result()
except ValueError as e:
    logger.error("Invalid API response", error=str(e))
    raise
```

### 5. Documentation

**Keep documentation in sync with code.**

| Rule | When |
|------|------|
| Update docs with behavior changes | Any user-facing change |
| Document breaking changes | Any API/interface change |
| Clear function signatures | Parameters, return types, exceptions |
| README for new features | Major additions |

### 6. File Management

**Be conservative with file creation.**

| Rule | Rationale |
|------|-----------|
| Prefer editing existing files | Reduces complexity |
| Don't create empty placeholder files | Creates noise |
| Don't generate binary/hash content | Expensive and unhelpful |
| Group related code | Avoid single-function files |

## Language Extensions

Add language-specific rules in `standards/extensions/<language>.md`.

### Extension Template

```markdown
# [Language] Extension for Code Quality Standard

## Formatting
- Tool: [formatter name]
- Config: [config file if any]
- Rules: [key formatting rules]

## Type Safety
- Tool: [type checker name]
- Rules: [type annotation requirements]

## Testing
- Framework: [test framework]
- Coverage: [coverage requirements]
- Patterns: [test naming, structure]

## Anti-Patterns
- [Language-specific things to avoid]
- [Common AI mistakes in this language]

## IDE Integration
- [How to enable in Cursor/Claude Code]
```

### Available Extensions

| Language | File | Key Tools |
|----------|------|-----------|
| Python | [python.md](extensions/python.md) | black, isort, mypy, pytest |
| TypeScript | [typescript.md](extensions/typescript.md) | prettier, eslint, tsc |
| Template | [_template.md](extensions/_template.md) | For new languages |

## Implementation

### Cursor IDE

Create `.cursor/rules/code-quality.mdc`:

```yaml
---
alwaysApply: true
---

# Code Quality Standards

## Verification (ALWAYS do these)
- Run tests after making changes
- Check for lint errors after editing
- Verify build succeeds before claiming done
- Never claim "done" without running verification

## Comments
- No obvious comments ("// Import module", "// Define function")
- Add WHY comments for non-obvious logic
- No commented-out code
- Document breaking changes

## Structure
- Keep imports at top of file
- No inline imports
- Prefer editing existing files over creating new ones
- Make small incremental changes

## Error Handling
- Never swallow exceptions silently
- Provide meaningful error messages
- Handle edge cases explicitly
- Prefer graceful degradation

## Documentation
- Update docs when behavior changes
- Document breaking changes
- Ensure function signatures are clear
```

### Claude Code

Add to `CLAUDE.md`:

```markdown
## Code Quality

### Before Claiming Done
- Run tests and report results
- Check for lint errors
- Verify build succeeds

### Comments
- WHY comments only, not obvious WHAT comments
- No commented-out code

### Structure
- Imports at top
- Prefer editing over creating files
- Small incremental changes

### Errors
- Handle all error cases
- Meaningful error messages
- Never swallow exceptions
```

## Quality Checklist

Use this checklist before completing work:

```markdown
## Code Quality Checklist

### Verification
- [ ] Tests pass (run `pytest` / `npm test`)
- [ ] No lint errors (run `flake8` / `eslint`)
- [ ] Build succeeds (run `npm run build`)
- [ ] Functionality verified manually

### Code Review
- [ ] No obvious/redundant comments
- [ ] WHY comments for complex logic
- [ ] No commented-out code
- [ ] Imports organized at top

### Error Handling
- [ ] All error cases handled
- [ ] Meaningful error messages
- [ ] Edge cases covered

### Documentation
- [ ] README updated if needed
- [ ] Breaking changes documented
- [ ] Function signatures clear
```

## Common AI Mistakes

| Mistake | Prevention |
|---------|------------|
| Claiming done without testing | Require test output in response |
| Creating duplicate files | Search before creating |
| Obvious comments everywhere | Explicit "no obvious comments" rule |
| Swallowing exceptions | Require error handling patterns |
| Large monolithic changes | Prefer incremental approach |
| Missing error handling | Require explicit handling |

## Metrics

Track code quality with:

| Metric | Target | Tool |
|--------|--------|------|
| Test coverage | >80% new code | pytest-cov, nyc |
| Lint errors | 0 | flake8, eslint |
| Type coverage | >90% | mypy, tsc |
| Complexity | <10 per function | radon, eslint |

## Enforcement

### Soft Enforcement (AI Rules)
- AI follows these guidelines
- Can be overridden by user

### Hard Enforcement (CI/CD)
- Pre-commit hooks for linting
- CI pipeline for tests
- Code review requirements
- Branch protection

Recommended pre-commit config:

```yaml
# .pre-commit-config.yaml
repos:
  - repo: local
    hooks:
      - id: lint
        name: lint
        entry: npm run lint
        language: system
        pass_filenames: false
      - id: test
        name: test
        entry: npm test
        language: system
        pass_filenames: false
```

## Success Indicators

Code quality is improving when:
- ✅ Tests consistently pass
- ✅ No lint errors in PRs
- ✅ Code reviews are faster
- ✅ Fewer bugs in AI-generated code
- ✅ Consistent style across codebase
- ✅ New team members understand code quickly

## Karpathy Coding Principles

Behavioral guidelines to reduce common LLM coding mistakes. These apply in both Claude Code and Cursor.

**Tradeoff:** These guidelines bias toward caution over speed. For trivial tasks, use judgment.

### 1. Think Before Coding
**Don't assume. Don't hide confusion. Surface tradeoffs.**

Before implementing:
- State your assumptions explicitly. If uncertain, ask.
- If multiple interpretations exist, present them — don't pick silently.
- If a simpler approach exists, say so. Push back when warranted.
- If something is unclear, stop. Name what's confusing. Ask.

### 2. Simplicity First
**Minimum code that solves the problem. Nothing speculative.**

- No features beyond what was asked.
- No abstractions for single-use code.
- No "flexibility" or "configurability" that wasn't requested.
- No error handling for impossible scenarios.
- If you write 200 lines and it could be 50, rewrite it.

Ask yourself: "Would a senior engineer say this is overcomplicated?" If yes, simplify.

### 3. Surgical Changes
**Touch only what you must. Clean up only your own mess.**

When editing existing code:
- Don't "improve" adjacent code, comments, or formatting.
- Don't refactor things that aren't broken.
- Match existing style, even if you'd do it differently.
- If you notice unrelated dead code, mention it — don't delete it.

When your changes create orphans:
- Remove imports/variables/functions that YOUR changes made unused.
- Don't remove pre-existing dead code unless asked.

The test: Every changed line should trace directly to the user's request.

### 4. Goal-Driven Execution
**Define success criteria. Loop until verified.**

Transform tasks into verifiable goals:
- "Add validation" → "Write tests for invalid inputs, then make them pass"
- "Fix the bug" → "Write a test that reproduces it, then make it pass"
- "Refactor X" → "Ensure tests pass before and after"

For multi-step tasks, state a brief plan:
```
1. [Step] → verify: [check]
2. [Step] → verify: [check]
3. [Step] → verify: [check]
```

Strong success criteria let you loop independently. Weak criteria ("make it work") require constant clarification.

**These principles are active when:** fewer unnecessary changes appear in diffs, rewrites due to overcomplication decrease, and clarifying questions come before implementation rather than after mistakes.
