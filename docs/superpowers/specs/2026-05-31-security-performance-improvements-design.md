# Security & Performance Improvements Design

**Date:** 2026-05-31
**Status:** Implemented (v1.0.4)

## Context

External review of PMB's security and performance characteristics identified four concrete
improvements. The security reviewer is well-designed (advisory-only, read-only, bounded
authority) but lacked structured finding output and a formal trust model. Performance risk
is low today but context explosion is the future risk — a budget document prevents gradual
bloat.

## Decisions

### 1. Structured Findings Format
Add Rule ID, Evidence snippet, and Confidence level to security-review output.
A rule registry (`SECURITY-RULES.md`) makes rule IDs first-class auditable artifacts.

### 2. Trust Classification
Reference doc only — no runtime enforcement. Trust level is informational context for the
security reviewer. Runtime enforcement belongs in hook/CI layer when actual code exists to
gate. Deferred: base+extension pattern (project-specific rules) pending evidence of friction.

### 3. Security Regression Fixtures
Passive fixtures alone (option A) are not reliably used without automation.
Split approach: `mb doctor` checks structure (fast, no LLM), `mb health-check` runs the
reviewer against fixtures on demand (slow, semantic, explicit).
Fixtures are PMB dogfooding only — not distributed via `mb init`.

### 4. Performance Budget
Reference doc with explicit limits. `mb doctor` Check 14 enforces the standards-count
limit structurally (deterministic). Primary risk is context explosion, not compute.

## Architecture

Four deliverables:
1. `standards/SECURITY-RULES.md` — rule registry, ADVISORY_CREATE
2. `standards/TRUST-CLASSIFICATION.md` — trust reference, ADVISORY_CREATE
3. `standards/PERFORMANCE-BUDGET.md` — budget limits, ADVISORY_CREATE
4. `fixtures/security/` — PMB-only dogfooding infrastructure

Updated: `.claude/commands/security-review.md`, `.claude/agents/security-reviewer.md`,
`mb doctor` (checks 13+14), `mb health-check`, `mb upgrade` ADVISORY_CREATE.

## What Was Not Done

- Autonomous fixes or memory writes (increases risk, not value)
- Runtime trust enforcement (no hook/CI code to back it up)
- Base+extension pattern for project-specific rules (deferred — no friction evidence)
