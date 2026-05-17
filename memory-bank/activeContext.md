---
authority: volatile
review-cycle: 7d
retention: archive-after-6m
staleness-threshold: 14d
tags:
  - session/focus
  - session/blockers
  - session/next-steps
last-reviewed: 2026-05-17
compaction_generation: 0
source_type: canonical
confidence: high
lineage: []
---

# Active Context

## Current Focus

Three major phases shipped in May 2026. Repo is feature-complete at the lifecycle management + provenance tracking layer. Ready for use as a project template.

## What Was Just Completed (2026-05-17)

**Provenance & Integrity (final phase):**
- All 10 memory-bank files (5 templates + 5 live) carry provenance frontmatter: `compaction_generation`, `source_type`, `confidence`, `lineage`
- `mb doctor` section 8: compaction depth warnings (CAUTION at gen 2, WARN at gen 3+) + canonical-source absence (ERROR — not WARN, recovery impossible)
- `standards/MEMORY-BANK.md` documents the full provenance schema, generation thresholds, additive lineage rationale, field orthogonality, and what `mb doctor` checks
- Severity asymmetry intentional: generation depth = fidelity risk (recoverable), missing lineage root = provenance chain broken (irreversible)

## Next Steps

1. Use the repo — copy to a new project, run `install.bat` or `mb init`
2. When mb doctor lineage-root warnings eventually fire, regenerate from canonical sources
3. Future: semantic identity detection (concept-level drift heuristics, not just file-level)

## Architecture Constraints to Remember

- `confidence:` is intentionally flat (high/medium/low) — sub-dimensions (factual, temporal, lineage, reconciliation) are future work, not yet
- `source_type` (origin semantics) and `compaction_generation` (transformation depth) are independent axes — do not conflate
- Detection-first, resist-automation: auto-remediation is premature without semantic certainty + contradiction modeling

## Git State

Branch: `claude/sharp-newton-6fa593` (merged up to master 83d4c2f)
