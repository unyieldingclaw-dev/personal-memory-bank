---
description: Full PMB health check — mb doctor (9 checks), staleness audit, and structure validation on this repo's own memory bank. Reports a summary with pass/warn/fail for each area.
allowed-tools:
  - Bash(mb doctor)
  - Bash(mb validate)
  - Bash(mb audit)
  - Bash(git status)
  - Bash(git log *)
---

# /health-check

Run the following checks in order and print a labeled result for each. At the end, print a one-paragraph summary with overall status (✅ all clear / ⚠️ warnings / ❌ failures).

## 1. Doctor

Run `mb doctor` from this repo's root. This runs all 9 health checks including structure, frontmatter, compaction integrity, and staleness summary.

**Output header:** `### mb doctor`

Print the full output. Call out any check that is not `[OK]`.

## 2. Validate

Run `mb validate` on this repo's own `memory-bank/`. This checks that all required files exist and have valid frontmatter.

**Output header:** `### mb validate`

## 3. Staleness Audit

Run `mb audit`. This lists each memory-bank file with its staleness status (days since last review vs threshold).

**Output header:** `### mb audit`

Note any files flagged as stale. Stable files (90d threshold) and volatile files (7d threshold) have very different cadences — flag volatile overdue files as higher priority.

## 4. Git Status

Run `git status --short` and `git log --oneline -5`. Note any uncommitted changes, work in flight, or branches ahead of main.

**Output header:** `### Git Status`

## 5. Summary

Print a short paragraph summarizing all four areas. Use ✅ for clean, ⚠️ for warnings, ❌ for failures. Example:

> ✅ mb doctor: all 9 checks OK. ✅ mb validate: structure valid. ⚠️ mb audit: activeContext.md is 9 days past its 7-day threshold. ✅ Working tree clean, main is up to date.
