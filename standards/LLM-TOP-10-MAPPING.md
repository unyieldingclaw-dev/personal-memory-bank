# OWASP LLM Top 10 (2025) — Memory-Bank Coverage Mapping

> **TODO: Validate against T-Mobile internal security / legal / compliance policy before broad adoption.**

This document maps each risk in the [OWASP Top 10 for LLM Applications (2025)](https://owasp.org/Top10/2025/) to the Memory-Bank control(s) that address it, and explicitly calls out residual gaps. It exists as compliance evidence and as a living gap tracker — when a residual gap is closed in a future version, update the row here.

## Coverage summary

| ✅ = Covered | 🟡 = Partial | 🔴 = Not covered this pass |

| OWASP risk (2025) | Coverage | Memory-Bank control(s) | Residual gap |
|-------------------|----------|------------------------|--------------|
| **LLM01 Prompt Injection** | 🟡 Partial → ✅ with v1.5 additions | `standards/SECURITY-GUARDRAILS.md` (BLOCK destructive actions); `standards/RULES-FILE-INTEGRITY.md` (new); `.cursor/rules/rules-file-integrity.mdc` (new); `standards/MCP-SECURITY.md` | Indirect prompt injection via dependency READMEs and retrieved documents is still a residual risk (see LLM08). |
| **LLM02 Sensitive Information Disclosure** | ✅ | `standards/LOGGING.md` (auto-PII redaction for emails / phones / SSN); `standards/DATA-CLASSIFICATION.md` (new — tier-specific prompt / memory-bank / log rules); `standards/MEMORY-BANK.md` (explicit PII ban) | — |
| **LLM03 Supply Chain Vulnerabilities** | 🟡 Partial | `standards/SUPPLY-CHAIN.md` (slopsquatting + SCA guidance); `standards/MCP-SECURITY.md` (MCP credential hygiene); `standards/MODEL-GOVERNANCE.md` (new — approved model list + version pinning) | No SBOM (SPDX / CycloneDX) generation; no code signing for AI-assisted commits; no model-artifact scanning. Deferred — likely org-wide tooling. |
| **LLM04 Data and Model Poisoning** | 🔴 Not covered this pass | — | Residual gap. Requires explicit data-supply-chain validation, training-data integrity checks, and poisoning detection — out of scope for the current repo (model-layer concerns). |
| **LLM05 Improper Output Handling** | ✅ | `standards/CODE-QUALITY.md` (verification gates — tests, lint, build); `.claude/commands/code-review.md` (3 role-separated subagents + test-coverage + opponent auditor); `.claude/commands/security-review.md` (9-pattern scan) | — |
| **LLM06 Excessive Agency** | ✅ | `standards/SECURITY-GUARDRAILS.md` 3-tier BLOCK/CONFIRM/WARN system; "Agent resource controls" section (token caps, loop detection, rate-limit handling); `standards/SECRETS.md` (ephemeral credentials) | — |
| **LLM07 System Prompt Leakage** | 🔴 Not covered this pass | — | Residual gap. Memory-Bank's CLAUDE.md / AGENTS.md files are effectively "system prompt" content and should be treated as non-secret. Any secret in a system prompt is a bug (enforced by `SECURITY-GUARDRAILS.md` BLOCK tier + `standards/RULES-FILE-INTEGRITY.md`). |
| **LLM08 Vector and Embedding Weaknesses** | 🔴 Not covered this pass | — | Residual gap. Memory-Bank does not currently use a vector store or RAG. If a downstream project adopts retrieval, it must add: retrieved-document sanitization, embedding-source provenance, per-tenant isolation, and injection-pattern scoring. |
| **LLM09 Misinformation** | 🔴 Not covered this pass | — | Residual gap. AI-generated code / claims / citations may be incorrect. Mitigations (to add in a future pass): citation verification, fact-check passes, evidence-before-assertion pattern. Partial mitigation via `standards/CODE-QUALITY.md` (verification before claiming done) and `/code-review` auditor step. |
| **LLM10 Unbounded Consumption** | ✅ | `standards/SECURITY-GUARDRAILS.md` "Agent resource controls" section (token / cost caps per session, loop detection, rate-limit awareness, MCP call monitoring) | — |

## Explicit out-of-scope residuals

The following remain **residual gaps** after this pass:

- **LLM04 Data and Model Poisoning** — requires model-lifecycle controls we do not own at the repo level.
- **LLM07 System Prompt Leakage** — partially mitigated by rules-file integrity; no automated scanning for accidental secret-in-prompt is in place.
- **LLM08 Vector / Embedding Weaknesses** — no current RAG or vector-store usage; standard must be added if that changes.
- **LLM09 Misinformation** — partial mitigation only; no factual-accuracy verification pipeline.

These are **acknowledged, not ignored.** When a future pass addresses them, update the rows above from 🔴 to 🟡 or ✅ and link to the new control.

## How to use this document

- **Compliance reviews**: cite this mapping as evidence of OWASP LLM Top 10 (2025) consideration.
- **New feature reviews**: before introducing a RAG system, vector store, training pipeline, or external tool use, revisit LLM04 / LLM07 / LLM08 and confirm the new surface is addressed.
- **Standard updates**: when adding or revising a standard, update the matching row(s) here in the same commit.

## References

- [OWASP Top 10 for LLM Applications — 2025](https://owasp.org/Top10/2025/)
- [OWASP Gen AI Security Project](https://genai.owasp.org/llm-top-10/)
- [NIST SP 800-218A — Secure Software Development Practices for AI Models](https://csrc.nist.gov/pubs/sp/800/218/a/final)
- [NIST AI Risk Management Framework](https://www.nist.gov/itl/ai-risk-management-framework)
- [CISA AI Security Guidance](https://www.cisa.gov/ai)
- [MITRE ATLAS — AI/ML Threat Taxonomy](https://atlas.mitre.org/)

---

**Version**: 1.0.0
**Last Updated**: April 24, 2026
**Owner**: T-Mobile Release Engineering/AERO Team
