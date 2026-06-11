# PMB Hook & Script Performance Fixes Design

**Date:** 2026-06-10
**Status:** Draft

## Context

A performance audit of PMB's hook scripts identified 4 bottlenecks adding 150–500ms of latency per Write/Edit tool call. The root cause in each case is unnecessary subprocess spawning — Python3 processes, `sed` invocations, and `grep` calls that can be eliminated or collapsed. All fixes are behaviorally equivalent: same checks, fewer processes.

**Approach:** Surgical per-file changes. No behavioral changes, no new features, no refactoring of unrelated code.

---

## Fix 1: `scripts/check-contract.sh`

**Problem:** 3 separate Python3 spawns + 6 `echo "$CONTRACT_DATA" | sed -n 'Np'` subshells on every Write/Edit hook call.

- Python spawn 1 (lines 21–38): parse JSON fields (status, expires_at, task, scope)
- Python spawn 2 (lines 57–66): expiry check via `datetime.fromisoformat`
- Python spawn 3 (lines 104–108): `fnmatch` scope matching — one spawn per scope pattern
- 6 sed subshells: extract individual fields from the contract JSON by line number

**Fix:** Collapse into **one Python invocation** that handles all three tasks in a single script:
1. Read and parse the contract file
2. Extract all fields inline (no sed)
3. Check status, expiry, and scope patterns
4. Print the appropriate message and exit with the correct code

The bash wrapper becomes: call Python once, capture exit code, done.

**Expected gain:** ~150–300ms reduction per Write/Edit hook call (eliminates 2 extra Python startups + 6 sed processes).

---

## Fix 2: `scripts/pre-compact-check.sh`

**Problem:** Line 36 spawns a `sed` process per line of `activeContext.md` inside a `while IFS= read -r line` loop:

```bash
trimmed=$(echo "$line" | sed 's/^[[:space:]]*//')
```

For a 100-line file, this is 100 subprocesses.

**Fix:** Replace with pure bash parameter expansion — zero subprocesses:

```bash
trimmed="${line#"${line%%[! ]*}"}"
```

This trims leading whitespace using nested parameter expansion:
- `${line%%[! ]*}` — longest prefix of non-space characters (i.e., the leading spaces)
- `${line#...}` — strip that prefix from the front

**Expected gain:** Eliminates ~100 processes per compaction check.

---

## Fix 3: `scripts/mb.sh` — Check 10 (placeholder residue)

**Problem:** Lines 744–774 run 7 separate `grep -ciE` calls per file, one per placeholder pattern, across 5 memory-bank files = up to 35 grep invocations.

**Fix:** One combined `grep -ciE` per file with all patterns joined by `|`:

```bash
grep -ciE 'TODO|TBD|FIXME|FILL IN|\[your |\[YOUR |lorem ipsum|YYYY-MM-DD' "$file"
```

5 total grep calls instead of 35. Result is summed — same count reported.

---

## Fix 4: `scripts/mb.sh` — Check 17 (semantic drift)

**Problem:** Lines 869–899 pipe each line through grep inside a `while read` loop:

```bash
echo "$line" | grep -qiE '(no longer|migrat...|deprecat...|obsolet...|removed|was replaced|legacy)'
```

For two files averaging 100 lines each ≈ ~400 subshell + grep processes.

**Fix:** Run grep directly on each file — let grep do the line iteration:

```bash
grep -inE '(no longer|migrat|deprecat|obsolet|removed|was replaced|legacy)' "$df"
```

2 total grep calls instead of ~400. Output is the same (matching lines with line numbers).

---

## Verification

For each fix, verify behavioral equivalence:

1. **check-contract.sh** — Run with: no contract file, expired contract, out-of-scope file, valid in-scope file. All four cases should produce the same output and exit codes as before.
2. **pre-compact-check.sh** — Run against an `activeContext.md` with leading-space lines. Confirm substantive-line count matches the old sed-based result.
3. **mb.sh check 10** — Run `mb doctor` against a memory-bank file containing one each of the placeholder patterns. Confirm count equals 7.
4. **mb.sh check 17** — Run `mb doctor` against a file containing "no longer relevant" on one line. Confirm it is flagged exactly as before.
