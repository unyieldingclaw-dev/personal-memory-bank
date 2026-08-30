# Code Review Standard

Purpose: define what constitutes a complete review.
This standard does not mandate agent topology, model, or phase count.

## Required Domains
- Security
- Correctness
- Maintainability
- Testing
- Architecture Drift — changes that contradict patterns in systemPatterns.md or introduce abstractions not established elsewhere in the project.

## Conditional Domains
- Performance — activate for runtime-sensitive changes (tight loops, DB queries, I/O paths)
- Accessibility — activate for UI file changes (HTML/JSX/TSX/Vue/Svelte)

## Severity Levels
Critical → High → Medium → Low → Info

## Required Finding Fields
Domain, Severity, Location, Evidence, Basis, Impact, Recommendation, Blocking

Field value scales: Severity uses `Critical | High | Medium | Low | Info`. Blocking uses `true | false`. Basis uses `VERIFIED | INFERRED | SPECULATIVE`.

## Basis Classification

The `Basis` field classifies the epistemic origin of a finding — how the agent arrived at it.

| Basis | Meaning |
|---|---|
| `VERIFIED` | Agent directly observed the defect at the cited location |
| `INFERRED` | Agent reasoned from a code pattern; behavior not directly confirmed |
| `SPECULATIVE` | Suspected risk; consequence is uncertain |

### Absence and attribution claims

For a claim that something does *not* exist — is not referenced, appears in no other file, has no
test, is unreachable — or that one thing cost or caused another, `VERIFIED` requires the **scope
actually searched**, stated as the command, in the finding itself. The conclusion alone is not a Basis.

- Not `VERIFIED` — the conclusion alone: *"no test covers THING"*
- `VERIFIED` — the conclusion **plus** the command that established it and what it returned:
  *"no test covers THING — `grep -rl 'PATTERN' PATHS` returned OUTPUT"*

For attribution, state the decomposition and show the parts sum to the measured whole: *"this change
cost N bytes"* is not a Basis; *"N net = A from the change itself, B from unrelated edits in the same
commit, A + B = N against the measured whole"* is.

**Match the command's reach to the assertion.** A filename filter cannot establish a claim about file
*contents*; a single-directory search cannot establish a claim about the repository; a pattern written
for the wrong syntax returns zero matches indistinguishable from a true absence. Where reach and
assertion differ the finding is false even though the command ran and its output was reported
honestly — and the author cannot catch it by re-reading, because re-reading re-derives the claim
inside the same scope. Only a stated scope lets a second reader see the gap.

Run the command before writing its output. An unrun example is the same defect as an unrun test.

## Evidence Requirements

Evidence must include a `file:line` reference. Prose alone ("this may cause...") is not valid evidence.

**VERIFIED** — must include `file:line` + code excerpt or precise behavioral description.

**INFERRED** — must include `file:line` + reasoning chain explaining the inference.

**SPECULATIVE** — must include `file:line` + observed trigger (the specific code pattern that raised the concern) + explicit uncertainty statement (why the consequence cannot be confirmed). The uncertainty is about the consequence, not the existence of the code.

## Blocking Semantics

`Blocking: true` requires `Severity >= High AND Basis != SPECULATIVE`.

- Critical/High + VERIFIED or INFERRED → may be `Blocking: true`
- Any Severity + SPECULATIVE → must be `Blocking: false`
- Medium/Low/Info → `Blocking: false` by default

High findings default to `Blocking: true` unless the reviewer has specific evidence that risk is contained.

## Required Report Sections
Scope, Files reviewed, Domain coverage, Supported Findings, Predicted Risks (omit if empty), Testing gaps, Opposition review, Verdict

The orchestrator sorts findings into report sections after collecting all domain agent output. Domain agents do not decide section placement.

**Supported Findings** — VERIFIED and INFERRED findings. Each row prefixed `[VERIFIED]` or `[INFERRED]` in the Basis column.

**Predicted Risks** — SPECULATIVE findings. Omit this section entirely if no SPECULATIVE findings exist.

## Opposition Review
Not a summary pass. The reviewer must explicitly answer:
- Is any Critical/High finding overstated? Provide counter-evidence.
- What was not reviewed that could matter?
- Which findings might be false positives in this codebase's context?
- What cross-domain risk did no single domain agent catch?
A passing opposition review requires answers to all four. A general statement that none apply is a failure.

## Evidence Integrity

Two rules about what a completion claim is worth. Both exist because a review found a shipped test
in this repo that could not fail, and because the claim "verified green" was made about it.

### A check that cannot fail does not count as a check

A test whose assertion holds regardless of whether the code it guards works, is broken, or is
deleted provides no regression protection, however green it runs. Before a test is offered as
evidence for a guard, break the guard and confirm the test goes red.

This is not a new practice here — `progress.md` records three separate fixes described as
"mutation-tested". It was never written down, so it was applied when remembered and skipped when
not. The skipped case shipped: a test named for the exact defect class it was meant to pin passed
identically with the normalization deleted, and survived a substantial rewrite of that
normalization without going red.

Two traps, both hit while proving the rule:

- **A mutation that changes bytes has not necessarily changed behaviour.** Replacing a command with
  a no-op that produces the same output looks applied and proves nothing. Confirm the mutated build
  behaves differently on a canary input before concluding a test "stayed green".
- **Redundant match paths mask mutations.** Where two independent code paths can produce the same
  verdict, mutating one leaves the other answering. Mutate all of them, or the result is a false
  negative.

### A self-attested completion counts as UNMET

A claim of completion supported only by the agent's own assertion is not evidence. It ranks *below*
an openly declared gap: an admitted gap is accurate about where the work stopped, whereas an
unsupported claim is indistinguishable from a false one until someone checks.

Practical consequence for this standard: a Testing assessment that reports "suite passes" without
having established that the relevant assertions discriminate has reported an execution, not a
verification. State what was run, what it returned, and — for anything guarding a security or
correctness boundary — what happens to it under mutation.

Adapted from the gates ledger in the external `Unlazy` skill, which treats a ticked checkbox whose
evidence line still reads `pending` as worse than an empty box. Its limitation is worth recording
alongside it: proving a command ran and matched expected text is strictly weaker than proving the
check discriminates. The vacuous test above would have passed such a gate cleanly.

## Failure Criteria
- Skipped required domain
- Missing `file:line` reference on any finding
- Missing Evidence field on any finding
- Evidence does not materially support the finding claim
- `SPECULATIVE` finding marked `Blocking: true`
- No Testing assessment
- A Testing assessment that offers a non-discriminating test as evidence for a guard
- A completion claim presented as verified with no command and no output behind it
- An absence or attribution claim stated without the scope actually searched, as the command
- No Opposition review
- Repo mutation during review without explicit user request

## Remediation
Review identifies and recommends by default. Remediation (editing files, generating tests,
applying fixes) requires explicit user request after findings are presented.

## Compatibility Note
`Basis` replaces `Confidence` (removed). Any tooling that parses review output must be updated from `Confidence` → `Basis`.
