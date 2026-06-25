---
status: approved
created: 2026-06-24
approved: 2026-06-24
related_spec: null
scope: local
risk: low
source: ai-draft
---

# PMB Test Coverage Expansion — Workstream 2

## Context

Full-project audit on 2026-06-24 found that only 3 of 11 `mb` commands have test coverage (`mb plan`, `mb preflight`, `mb change-check`). The remaining 8 commands — including `mb doctor` (24 checks, most complex command in the repo) — have zero tests. This workstream adds comprehensive coverage for all 8 untested commands using the existing bash test framework.

---

## Architecture

**Framework:** No external dependencies. Same pattern as existing tests:
- `tests/setup.sh` — `setup_test_project` creates a minimal initialized temp project
- `tests/helpers/assert.sh` — `assert_exit_zero`, `assert_exit_nonzero`, `assert_contains`, `assert_file_exists`, `print_summary`
- Each suite: `mktemp -d`, `MB_HOME="$REPO_ROOT"`, `bash "$MB" <command>`, capture output, assert, `trap 'rm -rf ...' EXIT`

**8 new test files** registered in `tests/run.sh`:
```
tests/test-mb-doctor.sh
tests/test-mb-status.sh
tests/test-mb-verify-integrity.sh
tests/test-mb-query.sh
tests/test-mb-init.sh
tests/test-mb-clean.sh
tests/test-mb-commit.sh
tests/test-mb-upgrade.sh
```

**`tests/run.sh`** — add all 8 to the `run_suite` block.

---

## Command: `mb doctor` (~25 cases in `test-mb-doctor.sh`)

One clean baseline test (all checks pass), then one failure-trigger test per check.

| Check | Setup mutation | Assert |
|---|---|---|
| Baseline | None — clean project | No `[ERROR]` or `[WARN]` in output |
| 0 — version | `rm VERSION` | `[WARN]` in output |
| 1 — git repo | `rm -rf .git` | `[ERROR]` in output |
| 2 — templates | MB_HOME points to dir without `templates/` | `[WARN]` in output |
| 3 — required files | `rm memory-bank/activeContext.md` | `[ERROR]` in output |
| 4 — hook config | `rm .claude/settings.json` | `[WARN]` in output |
| 5 — token budget | CLAUDE.md without `CLAUDE_AUTOCOMPACT_PCT_OVERRIDE` | `[WARN]` in output |
| 6 — file sizes | Pad `activeContext.md` to 151 lines | `[WARN]` in output |
| 7 — handoff present | `touch handoff.md` | `[WARN]` in output |
| 8 — compaction generation | Set `compaction_generation: 3` in `activeContext.md` frontmatter | `[WARN]` in output |
| 9 — staleness | Set `last-reviewed` to 60 days ago, `staleness-threshold: 7` | `[WARN]` in output |
| 10 — placeholder residue | Append `TODO: fix this` to `activeContext.md` | `[WARN]` in output |
| 11 — required standards | `rm standards/WORKFLOW.md` | `[WARN]` in output |
| 12 — version tracking | `echo "0.0.0" > .pmb-version` | `[WARN]` in output |
| 13 — security fixtures | `rm -rf fixtures/security/SEC-001` (if fixtures copied) | `[ERROR]` in output |
| 14 — standards count | Create 21 `.md` files in `standards/` | `[WARN]` in output |
| 15 — context ceiling | Pad files to exceed 15 KB total | `[WARN]` in output |
| 16 — hook error log | `echo "error" > .pmb-hook-errors.log` | `[WARN]` in output |
| 17 — semantic drift | Append `no longer relevant` to `activeContext.md` | `[WARN]` in output |
| 18 — stale stable | Set `last-reviewed` 200 days ago on `systemPatterns.md` (`authority: stable`) | `[WARN]` in output |
| 19 — authority mismatch | Set `authority: volatile` in `projectbrief.md` frontmatter | `[WARN]` in output |
| 20 — checksum mismatch | Run `mb verify-integrity` to init checksums, then modify a file externally | `[WARN]` in output |
| 21 — git-vs-reviewed lag | Commit `activeContext.md` with `last-reviewed: 2020-01-01` | `[WARN]` in output |
| 22 — completed-but-planned | Add `✅ Fix bug X` to `progress.md`, `⏸ Fix bug X` to `activeContext.md` | `[WARN]` in output |
| 23 — stale next step | Add `## Next Steps` section to `activeContext.md` listing an item already `✅` in `progress.md` | `[WARN]` in output |
| 24 — plan hygiene | `rm -rf docs/plans` | `[WARN]` in output |

**Note on Check 13 (fixtures):** Check 13 looks for `$REPO_ROOT/fixtures/security/SEC-001` through `SEC-009`. Since MB_HOME points to the repo, the fixtures are found at their real location. To trigger the error, temporarily rename one fixture dir, run doctor, then restore via trap:
```bash
mv "$REPO_ROOT/fixtures/security/SEC-001" "$REPO_ROOT/fixtures/security/SEC-001.bak"
trap 'mv "$REPO_ROOT/fixtures/security/SEC-001.bak" "$REPO_ROOT/fixtures/security/SEC-001"' EXIT
output=$(cd "$TMPDIR_DOCTOR" && MB_HOME="$REPO_ROOT" bash "$MB" doctor 2>&1)
assert_contains "$output" "[ERROR]" "doctor errors on missing fixture"
```
Restore must happen before the test suite's own EXIT trap fires — nest traps carefully or use a dedicated restore step.

---

## Command: `mb status` (6 cases in `test-mb-status.sh`)

| Case | Setup | Assert |
|---|---|---|
| Clean project | Default `setup_test_project` | Exit 0; no "⚠" or "attention" in output |
| Signal 1 — not initialized | `rm -rf memory-bank` | "not initialized" or `[WARN]`/`[ERROR]` in output |
| Signal 2 — missing file | `rm memory-bank/activeContext.md` | output flags missing file |
| Signal 3 — stale context | Set `last-reviewed` 30 days ago with 7-day threshold | "stale" in output |
| Signal 4 — no standards | `rm -rf standards` | output flags missing standards |
| Signal 5 — no contracts | `rm -rf .claude/contracts` (default project has no `.json` files — this fires by default; test the positive case too: create a dummy `.json` file, verify signal passes) | output notes no tasks (negative); no tasks warning absent (positive) |

---

## Command: `mb verify-integrity` (3 cases in `test-mb-verify-integrity.sh`)

| Case | Setup | Assert |
|---|---|---|
| First run | No `.pmb-checksums` file | Exit 0; `.pmb-checksums` file created; "baseline" or "written" in output |
| Clean run | Run verify-integrity twice (second run has matching checksums) | Exit 0; "match" or no mismatch warnings |
| Tampered file | Init checksums, then `echo "tamper" >> memory-bank/activeContext.md`, run again | "mismatch" or "changed" or `[WARN]` in output |

---

## Command: `mb query` (4 cases in `test-mb-query.sh`)

| Case | Setup | Assert |
|---|---|---|
| No keyword | `mb query` with no args | Exit nonzero or usage text in output |
| Tag match | Add `tags: [authentication]` to `activeContext.md` frontmatter, `mb query authentication` | `activeContext.md` in output |
| Section match | Add `## Authentication Flow` to `activeContext.md`, `mb query auth` | `activeContext.md` in output |
| No match | `mb query nonexistentkeyword99` | "no matches" or "not found" in output; exit 0 |

---

## Command: `mb init` (3 cases in `test-mb-init.sh`)

| Case | Setup | Assert |
|---|---|---|
| Fresh dir | `mktemp -d`, `git init`, `git commit --allow-empty`, run `mb init` | All 5 memory-bank files exist; `.pmb-version` exists; exit 0 |
| Re-init | Run `mb init` twice in same dir | Exit 0 (no crash); existing files not corrupted |
| Status after init | Run `mb init` then `mb status` | `mb status` exits 0 or outputs no critical errors |

---

## Command: `mb clean` (2 cases in `test-mb-clean.sh`)

| Case | Setup | Assert |
|---|---|---|
| Normal run | Default project | Output contains maintenance guidance text (e.g. "clean", "memory-bank", "slim"); exit 0 |
| Oversized progress | Pad `progress.md` to 401+ lines | "slim" or size warning in output |

---

## Command: `mb commit` (2 cases in `test-mb-commit.sh`)

| Case | Setup | Assert |
|---|---|---|
| Nothing to commit | Clean project (no unstaged memory-bank changes) | Exit 0; graceful "nothing to commit" or "up to date" message |
| Modified file | Append a line to `activeContext.md`, run `mb commit` | Exit 0; `git log --oneline` shows new commit mentioning memory-bank |

---

## Command: `mb upgrade` (3 cases in `test-mb-upgrade.sh`)

| Case | Setup | Assert |
|---|---|---|
| Template sync | `setup_test_project`, delete a TEMPLATE_OWNED file (e.g. `scripts/dangerous-commands.sh`), run `mb upgrade` | Deleted file re-created; exit 0 |
| Version update | Run `mb upgrade` | `.pmb-version` content matches `cat $MB_HOME/VERSION` |
| Missing standard | Delete `standards/WORKFLOW.md`, run `mb upgrade` | `standards/WORKFLOW.md` re-created (ADVISORY_CREATE behavior) |

---

## Files Modified

| File | Operation |
|---|---|
| `tests/run.sh` | Add 8 new `run_suite` calls |
| `tests/test-mb-doctor.sh` | Create — 25 test cases |
| `tests/test-mb-status.sh` | Create — 6 cases |
| `tests/test-mb-verify-integrity.sh` | Create — 3 cases |
| `tests/test-mb-query.sh` | Create — 4 cases |
| `tests/test-mb-init.sh` | Create — 3 cases |
| `tests/test-mb-clean.sh` | Create — 2 cases |
| `tests/test-mb-commit.sh` | Create — 2 cases |
| `tests/test-mb-upgrade.sh` | Create — 3 cases |

**Total: ~53 new test cases across 9 file changes.**

---

## Implementation Notes

### `MB_HOME` pattern
All test commands use `MB_HOME="$REPO_ROOT" bash "$MB" <command>` so the script resolves templates, VERSION, and fixtures from the PMB repo root rather than a random temp directory.

### Frontmatter mutation pattern
For tests that require changing frontmatter fields (e.g. `last-reviewed`, `compaction_generation`, `authority`), use `sed -i` or `perl -i` in-place substitution inside the temp project — same approach the existing `update-reviewed.sh` hook uses.

### Check 13 / fixtures
`setup_test_project` creates a minimal project; `fixtures/security/` comes from MB_HOME. Test Check 13 by temporarily renaming `$REPO_ROOT/fixtures/security/SEC-001` to trigger the error, restoring it in a `trap`. Alternatively, point MB_HOME to a stripped temp dir that lacks fixtures entirely.

### `mb commit` isolation
Use a fresh git repo in the temp dir (already done by `setup_test_project`). The commit runs against that local repo — no remote, no push.

### `mb upgrade` isolation
Point both the source (`MB_HOME=$REPO_ROOT`) and target (temp project) correctly. Upgrade reads templates from `$MB_HOME/templates/` and writes them to the current dir.

---

## Verification

```bash
cd "C:\Users\Mizzo\Claude\Personal-Memory-Bank"
bash tests/run.sh
```

Expected: all existing 33 tests pass + all new tests pass. Final line: `All test suites passed.`
