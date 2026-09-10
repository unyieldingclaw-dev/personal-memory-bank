---
status: open
created: 2026-09-08
last-reviewed: 2026-09-08
staleness-threshold: 90d
related_plan: null
---

# Fix the inert invisible-Unicode check in pmb-health.yml

SECURITY: .github/workflows/pmb-health.yml:450 has never been able to fail. Its pattern is: LC_ALL=C grep -Pn with \x{200B} etc. GNU grep rejects that with 'character value in \x{} or \o{} is too large', rc=2, and the step body swallows it with 2>/dev/null, so the if is false, FAIL stays 0, and it prints 'OK: No invisible Unicode characters found'. VERIFIED locally by planting a real U+200B. Scope is standards/ + CLAUDE.md + templates/CLAUDE.md, 21 files. There is NO fallback detector: mb verify-integrity is checksums, which catches modification but not a zero-width char authored in legitimately. DO NOT use the fix of merely dropping LC_ALL=C -- measured, still inert, because the ambient locale is also non-UTF-8. Three forms that DO work, all measured: LC_ALL=C.UTF-8, the (*UTF) verb, or matching literal UTF-8 bytes. A corrected check finds 0 hits on the current tree, so it lands green. The workflow comment at :449 claiming 'grep -P matches literal bytes for the Unicode code points' is the false belief that produced this. Found by the opposition reviewer 2026-09-08 by planting violations, after surviving every CI run since it was written plus three review rounds.

FIXED 2026-09-09 by `1f7a7e7`, with detection-efficacy coverage added in `tests/test-baseline-health.sh` blocks 8 and 9. `status:` stays `open` deliberately: `mb`'s backlog schema has only `open`/`promoted`/`dismissed` (`scripts/mb.sh:2744,2753`) and none of them means "fixed directly" — `dismissed` would assert this was dropped rather than done, and an invented value would fail `promote`'s validation. The missing state is the real gap; do not resolve this by mislabelling the entry.
