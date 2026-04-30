# Incident Response Runbook — Template

> **TODO: Validate against T-Mobile internal security / legal / compliance policy before broad adoption.**

Copy this file into a project as `INCIDENT-RUNBOOK.md` or `docs/INCIDENT-RUNBOOK.md`. It is a **starting point**, not a policy document — fill in project-specific contacts, systems, and escalation paths in the places marked `[FILL IN]`.

---

## Severity classification

| Severity | Criteria | Initial response time | Example |
|----------|----------|-----------------------|---------|
| **SEV 1** | Production outage, data exposure (Confidential / Restricted), regulatory exposure, multi-team or customer-facing impact | Immediate — page on-call within 15 minutes | Customer data leak; auth outage; credential exposed publicly |
| **SEV 2** | Major feature degraded, single-team blocker, non-prod but urgent, potential for escalation | Within 1 hour | CI/CD pipeline failed; tool chain broken; agent-generated code shipped bad config |
| **SEV 3** | Minor feature degraded, workaround exists, no customer impact | Within 1 business day | Flaky test; slow-down; small config drift |
| **SEV 4** | Cosmetic, doc-only, follow-up item | Weekly review | Typo in doc; minor UX glitch; backlog noise |

---

## Initial response checklist

Use this in the first 15 minutes. Don't wait for full understanding before starting.

### Contain

- [ ] Stop bleeding: revert the last change, disable the feature flag, pull the affected service, revoke the exposed credential — whichever applies.
- [ ] Communicate: post in `[FILL IN — project Teams channel]` noting severity and what you know. Default to over-communicating.
- [ ] Page: if SEV 1, page `[FILL IN — on-call rotation]`. If the incident involves security or customer data, also page `[FILL IN — security on-call]`.

### Preserve evidence

- [ ] Capture the current state: `git log`, relevant logs, terminal output, affected file contents.
- [ ] Do **not** destroy evidence while containing — e.g., don't `git reset --hard` over the offending commit; revert with a new commit instead.
- [ ] If an AI agent produced the bad change, capture: which IDE, which model (from `standards/MODEL-GOVERNANCE.md` pinned version), which slash command if any, the user prompt that led to the change, and the agent's explanation.
- [ ] Snapshot shell history if credential exposure is suspected: `cp ~/.bash_history /tmp/incident-$(date +%s).history` (store in an access-controlled location — this itself may be sensitive).

### Escalate

- [ ] SEV 1 or 2: notify the owner listed in `projectbrief.md` of the affected project.
- [ ] Security-relevant: notify `[FILL IN — security team contact]`.
- [ ] Legal/regulatory-relevant (data exposure, CPNI, PII): notify `[FILL IN — legal / compliance contact]` — do not assess severity yourself.

---

## If AI-assisted code was involved

This section is a required checklist when the incident involves code that was generated, modified, or suggested by an AI tool.

- [ ] **Model attribution** — which model produced the change? Check commit trailers (if the `Assisted-by:` convention is in use), the IDE's history, or ask the developer. Record in the post-mortem.
- [ ] **Session provenance** — was a slash command involved (`/feature-dev`, `/code-review`, `/accessibility-review`, `/security-review`)? Include the session transcript if recoverable.
- [ ] **MCP tool usage** — did the agent call any MCP tools? If yes, list them. A compromised or rug-pulled tool is a credible attack vector (see `standards/MCP-SECURITY.md`).
- [ ] **Rules-file check** — did the project's `.cursorrules`, `CLAUDE.md`, `AGENTS.md`, or `.mdc` files change recently in a way that could have influenced the agent's behavior? If so, see `standards/RULES-FILE-INTEGRITY.md`.
- [ ] **Credential rotation** — if the agent had access to credentials during the incident window, rotate them. Do not assume "it didn't read them" — rotate as default.
- [ ] **Model-pinning check** — did the IDE / CI silently switch to a non-approved or deprecated model? Cross-reference `standards/MODEL-GOVERNANCE.md`.

---

## Post-mortem template

Write this within 5 business days of resolution. Store it in `docs/postmortems/YYYY-MM-DD-<short-title>.md` in the affected project.

```markdown
# Post-mortem: <short title>

**Date of incident:** YYYY-MM-DD (UTC)
**Severity:** SEV X
**Duration:** HH:MM to HH:MM (UTC) — N hours
**Authors:** <names>
**Status:** Draft / Reviewed / Closed

## Impact

One paragraph. Who was affected, how many, for how long, and what did they experience?

## Timeline

UTC timestamps. Keep it factual — no blame, no speculation.

- HH:MM — <event>
- HH:MM — <event>

## Root cause

What actually caused the incident. Distinguish from contributing factors.

## Contributing factors

What made it worse, or made it easier to happen. Monitoring gaps, training gaps, tool gaps.

## What went well

- …

## What went poorly

- …

## Action items

Each item: owner, due date, priority. Prefer prevention (systemic fixes) over detection (better alerts) over response (better runbooks).

| # | Action | Owner | Due | Priority |
|---|--------|-------|-----|----------|
| 1 | | | | |

## AI involvement (if any)

Filled in if the "If AI-assisted code was involved" checklist was triggered. Which model, which commit, what instruction, what went wrong, what we're changing.

## Lessons learned

Short. Quotable. Shareable with other teams.
```

---

## What this runbook is **not**

- Not a replacement for a formal incident-management system.
- Not a legal notification procedure — that lives in `[FILL IN — T-Mobile incident notification policy]`.
- Not a substitute for talking to the on-call / security team. When in doubt, page.

## References

- `standards/SECURITY-GUARDRAILS.md` — BLOCK / CONFIRM / WARN tiers; know what an agent can and cannot do
- `standards/SECRETS.md` — ephemeral secrets policy; rotation-as-default posture
- `standards/MODEL-GOVERNANCE.md` — approved model list; check for silent downgrades
- `standards/RULES-FILE-INTEGRITY.md` — rules-file tampering investigation
- `standards/MCP-SECURITY.md` — MCP tool-poisoning threat model
- [Google SRE — Postmortem Culture](https://sre.google/sre-book/postmortem-culture/) — the template is inspired by this pattern
- [CISA Incident Response guidance](https://www.cisa.gov/topics/cybersecurity-best-practices/organizations-and-cyber-safety/cybersecurity-incident-response)

---

**Version**: 1.0.0
**Last Updated**: April 24, 2026
**Owner**: T-Mobile Release Engineering/AERO Team
