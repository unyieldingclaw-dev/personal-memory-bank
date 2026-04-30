# Data Classification

> **TODO: Validate against T-Mobile internal security / legal / compliance policy before broad adoption.**

Every decision about what to put into a prompt, a memory-bank file, a log, a commit message, or a PR description boils down to one question: **what classification is this data?** This standard names four tiers and defines the rules for each. All other Memory-Bank standards (logging, security guardrails, secrets, accessibility) cross-reference these tiers.

## Tiers

| Tier | Examples | Who can see it | Impact if leaked |
|------|----------|----------------|------------------|
| **Public** | Published docs, marketing copy, open-source code, public-repo README | Anyone | None |
| **Internal** | Design docs, architecture diagrams, internal tooling code, team wikis, non-customer data schemas | Any T-Mobile employee or authorized contractor | Minor — competitive signal, no legal exposure |
| **Confidential** | Customer names, order IDs, email addresses, phone numbers, network topology, system credentials to non-prod, contract data, financial projections | Project team and explicit need-to-know | Regulatory reporting, contractual fines, reputational impact |
| **Restricted** | Production credentials, encryption keys, PII beyond name/email (SSN, payment cards, health data), CPNI, source of intellectual-property differentiators | Strict need-to-know with documented approval | Regulatory violation, breach notification, legal exposure |

If a dataset contains multiple tiers, **classify at the highest tier present** (the "high-water mark" rule).

## Per-tier rules

### What can go into a **prompt / chat context**

| Tier | Allowed in prompt | Notes |
|------|-------------------|-------|
| Public | ✅ Unrestricted | — |
| Internal | ✅ Allowed | Prefer summarization over verbatim large docs; avoid including contractor names unnecessarily |
| Confidential | ⚠️ Case-by-case | Redact identifiers (customer IDs, emails, phone numbers) before sending; use synthetic examples where possible. Document the decision in the project's `activeContext.md`. |
| Restricted | ❌ Never | No exceptions. Use synthetic placeholders. Escalate via security if the task appears to require it. |

### What can go into **memory-bank files**

Memory-bank files (`projectbrief.md`, `systemPatterns.md`, `techContext.md`, `activeContext.md`, `progress.md`) are version-controlled and shared across the team.

| Tier | Allowed in memory-bank | Notes |
|------|-----------------------|-------|
| Public | ✅ Unrestricted | — |
| Internal | ✅ Allowed | Primary home for design context |
| Confidential | ⚠️ Only non-identifying references | "Customer X reported issue" — no names, no IDs, no emails. Link to a separate, access-controlled incident system if detail is needed. |
| Restricted | ❌ Never | No credentials, no keys, no PII beyond name/email, no CPNI. See `standards/SECRETS.md` for where secrets do belong. |

### What can go into **logs**

Aligned with `standards/LOGGING.md`.

| Tier | Allowed in logs | Notes |
|------|-----------------|-------|
| Public | ✅ Unrestricted | — |
| Internal | ✅ Allowed | Service names, request paths, non-PII trace context |
| Confidential | ⚠️ IDs only, no free-text | Log `order_id=ORD-123`, not email or phone. Correlation IDs over PII. |
| Restricted | ❌ Never | PII sanitizer (see `LOGGING.md`) enforces redaction of emails, phones, SSN. Credentials, keys, and health data must never appear in logs — even redacted. |

### What can go into **commit messages / PR descriptions**

| Tier | Allowed | Notes |
|------|---------|-------|
| Public | ✅ Unrestricted | — |
| Internal | ✅ Allowed | Link to internal tickets by ID; avoid quoting internal docs verbatim |
| Confidential | ⚠️ IDs only | "Fix issue reported on ticket #1234" — not the customer narrative |
| Restricted | ❌ Never | Never paste credentials, keys, or PII into commit or PR |

### What can go into **issue trackers / tickets**

| Tier | Allowed | Notes |
|------|---------|-------|
| Public | ✅ Unrestricted | — |
| Internal | ✅ Allowed | — |
| Confidential | ⚠️ Restrict visibility | Mark the issue as confidential / private; limit watcher list |
| Restricted | ❌ Never in comments | Use an access-controlled incident system; reference its ID, nothing more |

## How to decide the tier when it's unclear

1. **Default upward.** If you can't decide between Internal and Confidential, choose Confidential.
2. **Ask the data owner.** If the data came from a customer CRM, network operations tool, or billing system, the owning team sets the tier.
3. **When in doubt, don't prompt.** An agent that doesn't need the data can operate on a synthetic stand-in.

## Interaction with other standards

- `LOGGING.md` PII rules are the log-layer enforcement of Confidential/Restricted tier.
- `SECRETS.md` defines where Restricted-tier credentials live (never in memory-bank, never in env vars visible to agents for longer than needed).
- `SECURITY-GUARDRAILS.md` BLOCK tier refuses to commit Restricted content.
- `MEMORY-BANK.md` already bans secrets/PII/full code dumps in memory-bank files — this standard generalizes that ban per tier.

## Quick-check card

Before pasting anything into a prompt or memory-bank file, ask:

1. Is this **Public**? → safe to use as-is.
2. Is this **Internal**? → safe; prefer summary over verbatim.
3. Is this **Confidential**? → redact identifiers, or use synthetic data.
4. Is this **Restricted**? → don't. Use a synthetic placeholder. Escalate if the task appears to require it.

---

**Version**: 1.0.0
**Last Updated**: April 24, 2026
**Owner**: T-Mobile Release Engineering/AERO Team
