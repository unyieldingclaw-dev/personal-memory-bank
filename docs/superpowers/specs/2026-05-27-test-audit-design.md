# `/test-audit` Command — Design

## Context

PMB ships three slash commands to user projects via `templates/claude-commands/`: `code-review`,
`feature-dev`, and `security-review`. None of them answer: "Does this project have test suites
set up?" A developer before a PR has no fast signal for which files are missing tests, whether
the test runner is configured, or whether CI actually runs tests.

This command fills that gap: a diagnostic/audit slash command that answers all four questions
in a single pass, inline in the main agent.

## Design

### Approach: Inline scan, detection-first

The command runs entirely in the main agent — no subagents, no file writes. It matches the
`security-review` lightweight pattern, not the `code-review` orchestration pattern.

**Why no subagents?**
The checks are orthogonal. "Does `test_auth.py` exist?" does not contaminate "does `pytest.ini`
exist?" Cross-lens isolation (the justification for `code-review`'s parallel subagents) adds
cost without correctness benefit here. PMB principle: overhead proportionate to certainty.

**Why no stub generation?**
PMB follows detection-first/resist-automation. Stubs create false confidence — they look like
coverage but may test nothing meaningful. Auto-generating files also adds write permissions and
blast radius to a command that should be read-only. Report the gap; let the engineer decide
what to do.

### Modes

| Invocation | Behavior |
|-----------|----------|
| `/test-audit` | Scope to `git diff HEAD --name-only` (changed files only) |
| `/test-audit --all` | Scan entire project source tree |
| `/test-audit <path>` | Scan a specific folder |

If the diff is empty in default mode: report it and stop.

### Step 1 — Determine Scope

Run `git diff HEAD --name-only` for the default mode. Filter to source files: exclude files
already matching test patterns, exclude `.md` files, config files, `node_modules/`, `.git/`.
If `--all` or a path argument is provided, use `find` to enumerate source files instead.

### Step 2 — Auto-Detect Framework

Check for signals in priority order:

| Signal file | Detected framework |
|-------------|-------------------|
| `package.json` with jest/vitest/mocha in scripts or devDependencies | Jest / Vitest / Mocha |
| `jest.config.{ts,js,mjs}`, `vitest.config.{ts,js}` | Confirms JS/TS framework |
| `requirements.txt` or `pyproject.toml` containing `pytest` | pytest |
| `setup.cfg` with `[tool:pytest]` | pytest |
| `go.mod` | Go (stdlib testing) |
| `Gemfile` or `.rspec` | Ruby/RSpec |
| `Cargo.toml` | Rust (stdlib testing) |

If no framework is detected: report `[LOW] No test framework detected` and continue using
convention-only patterns (filenames containing `test` or `spec`).

### Step 3 — Source-to-Test File Mapping

Per-framework conventions:

| Framework | Source file | Test file locations to check |
|-----------|-------------|------------------------------|
| Python/pytest | `src/auth/login.py` | `tests/test_login.py`, `tests/auth/test_login.py`, `src/auth/test_login.py` |
| JS/TS (Jest/Vitest) | `src/auth/login.ts` | `src/auth/login.test.ts`, `src/auth/login.spec.ts`, `src/auth/__tests__/login.test.ts` |
| Go | `auth/login.go` | `auth/login_test.go` (same directory only) |
| Ruby/RSpec | `lib/auth/login.rb` | `spec/auth/login_spec.rb` |
| Fallback | `any/path/file.ext` | Any file matching `*test*` or `*spec*` within 3 directory levels |

### Step 4 — Non-Empty Test File Check

For each found test file, grep for at least one test function or block:

| Framework | Pattern |
|-----------|---------|
| Python | `def test_` |
| Jest / Vitest / Mocha | `it(`, `test(`, `describe(` |
| Go | `func Test` |
| RSpec | `it `, `describe ` |
| Rust | `#[test]` |

A test file that exists but matches none of these patterns is reported as [MEDIUM].

### Step 5 — Framework Config Check (once per project)

Verify that a test runner config file exists:

| Framework | Expected config |
|-----------|----------------|
| Jest | `jest.config.{ts,js,mjs,cjs}` or `"jest"` key in `package.json` |
| Vitest | `vitest.config.{ts,js}` or `"vitest"` key in `package.json` |
| pytest | `pytest.ini`, `pyproject.toml` with `[tool.pytest.ini_options]`, or `setup.cfg` with `[tool:pytest]` |
| Go | No config required (stdlib); skip this check |
| RSpec | `.rspec` or `spec/spec_helper.rb` |

Reports `[LOW]` if a framework was detected but no config file is found.

### Step 6 — CI Test Step Check (once per project)

Glob for CI config files: `.github/workflows/*.yml`, `.circleci/config.yml`,
`Jenkinsfile`, `.gitlab-ci.yml`.

If no CI config exists: report `[LOW] No CI configuration found`.

If CI configs exist, grep for test invocation patterns:
- `npm test`, `npm run test`, `yarn test`, `npx vitest`, `npx jest`
- `pytest`, `python -m pytest`
- `go test`
- `rspec`, `bundle exec rspec`
- `cargo test`

If CI configs exist but no test step is found: report `[MEDIUM] CI configuration found but no test step detected`.

### Severity Model

| Severity | Condition |
|----------|-----------|
| [HIGH] | Source file in scope has no corresponding test file |
| [MEDIUM] | Test file exists but contains no test functions or blocks |
| [MEDIUM] | CI configuration exists but invokes no test command |
| [LOW] | No test framework detected |
| [LOW] | Framework detected but no config file found |
| [LOW] | No CI configuration in project |

### Output Format

```
## Test Audit — [diff: 3 files] or [full: src/ — 47 files]
Framework detected: Jest (jest.config.ts ✓)
Framework config:   ✓ jest.config.ts
CI test step:       ✓ .github/workflows/ci.yml

### File Coverage
| Source File               | Test File                        | Has Tests | Severity |
|---------------------------|----------------------------------|-----------|----------|
| src/auth/login.ts         | src/auth/login.test.ts ✓         | ✓         | —        |
| src/payments/charge.ts    | ✗ missing                        | —         | [HIGH]   |
| src/utils/format.ts       | src/utils/format.spec.ts ✓       | ✗ empty   | [MEDIUM] |

### Summary
2 issues found: 1 [HIGH], 1 [MEDIUM]
- [HIGH]   src/payments/charge.ts — no test file found
- [MEDIUM] src/utils/format.ts — test file has no test functions
```

If all checks pass:
```
✅ All checked files have test coverage. Framework config and CI test step present.
```

## Files to Create

1. `templates/claude-commands/test-audit.md` — canonical template distributed to user projects via `mb init`
2. `.claude/commands/test-audit.md` — installed copy for PMB's own dogfooding

Both files are identical in content. `mb init` copies `templates/claude-commands/` into `.claude/commands/` in the user project.

## Verification

1. Run `/test-audit` in a project with no tests → each source file reports `[HIGH]`
2. Run `/test-audit` after adding a test file → that file no longer flagged
3. Run `/test-audit` with a test file containing no `def test_` / `it(` → reports `[MEDIUM]`
4. Run `/test-audit --all` → full project scan, not just diff
5. Run `/test-audit` with empty diff → "no files to review" message, stop
6. Run in a Go project → `go.mod` detected, `*_test.go` conventions used
