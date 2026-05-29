# Code Review Standard

Purpose: define what constitutes a complete review.
This standard does not mandate agent topology, model, or phase count.

## Required Domains
- Security
- Correctness
- Maintainability
- Testing
- Architecture Drift

## Conditional Domains
- Performance — activate for runtime-sensitive changes (tight loops, DB queries, I/O paths)
- Accessibility — activate for UI file changes (HTML/JSX/TSX/Vue/Svelte)

## Severity Levels
Critical → High → Medium → Low → Info

## Required Finding Fields
Domain, Severity, Location, Evidence, Impact, Recommendation, Blocking, Confidence

## Required Report Sections
Scope, Files reviewed, Domain coverage, Findings, Testing gaps, Opposition review, Verdict

## Opposition Review
Not a summary pass. The reviewer must explicitly answer:
- Is any Critical/High finding overstated? Provide counter-evidence.
- What was not reviewed that could matter?
- Which findings might be false positives in this codebase's context?
- What cross-domain risk did no single domain agent catch?
A passing opposition review requires answers to all four. A general statement that none apply is a failure.

## Failure Criteria
- Skipped required domain
- Missing Evidence field on any finding
- No Testing assessment
- No Opposition review
- Repo mutation during review without explicit user request

## Remediation
Review identifies and recommends by default. Remediation (editing files, generating tests,
applying fixes) requires explicit user request after findings are presented.
