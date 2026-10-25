# Standards Freshness Design

**Date:** 2026-07-14
**Status:** Approved

## Problem

`standards/*.md` has no staleness tracking at all in most files (12 of 15 have zero
frontmatter — `memory-bank/*.md` has had this for a while), and several files cite or should
cite versioned external frameworks (WCAG, OWASP LLM Top 10, the MCP specification) with no
mechanism to notice when those frameworks move on. Confirmed concretely, not hypothetically:
`ACCESSIBILITY.md` still says "WCAG 2.1" with WCAG 2.2 long current; `MCP-SECURITY.md` is
missing real 2026 guidance (OAuth 2.1 authorization flows, the year's SEP hardening work) that
shipped after it was last touched.

Full audit methodology (six-step process used to find all of this) is written up separately
and portably at `standards-freshness-methodology.md` (user's Desktop) for reuse on other
Memory Bank deployments — not duplicated here.

## Solution

Two independent mechanisms, applied per-file based on what that file actually needs:

**Mechanism A — Cadence tracking**, for every standards file: extend the existing
`memory-bank/`-style `last-reviewed`/`review-cycle` frontmatter pattern (already proven in 3
of 15 files — `PERFORMANCE-BUDGET.md`, `SECURITY-RULES.md`, `TRUST-CLASSIFICATION.md`, all
created with it from the start, not retrofitted) to the remaining 12. Pure calendar cadence,
no content awareness.

**Mechanism B — External version tracking**, only for files citing a real, versioned external
spec: compare a version *string* against the framework's current version, never diff content.

## Mechanism B — Design Detail

1. **Centralize the check in this repo — never per-downstream-project.** `standards/*.md` is
   `TEMPLATE_OWNED`, identical across every PMB-managed repo; the external framework's version
   isn't a property of any individual downstream project. Check once, here. Let the existing
   `.pmb-version`/`mb upgrade` distribution mechanism carry any resulting content fix downstream
   — no new distributed-checking infrastructure.
2. **Decouple fetch frequency from surface frequency.** Cache each tracked source's current
   version with a short TTL (7 days). `mb doctor` reads the cache and WARNs on every run once a
   mismatch is cached — never gated behind the file's own `review-cycle` window, since the
   entire point is catching drift *between* scheduled reviews.
3. **No generic version-diff engine.** One small, hand-written comparison adapter per tracked
   framework — WCAG versions as major.minor (2.1 → 2.2), OWASP LLM Top 10 as full-year editions
   (2023 → 2025), MCP as date-stamped spec revisions. These don't share a comparison shape.
4. **Fail toward silence, not false alarms, when the check mechanism itself breaks.** Missing
   network, broken page-scrape parsing (WCAG/MCP have no clean version API — this is fragile by
   nature) → report "unknown, keep last-known-good," never default to "assume mismatch, warn."
5. **Detection only, forever.** WARN nags until a human updates the file's substantive content
   *and* its `external-version` field together. Never auto-edit either — an auto-bumped version
   field with stale content underneath is a false "current" signal, worse than an honest one.
6. **Not every citation gap fits this mechanism.** `SUPPLY-CHAIN.md`'s "research across 17
   LLMs (2025)" citation is a real staleness risk but not a versioned spec — needs a different,
   heavier "is this still the current data" check this design deliberately does not build.
   Named here as an explicit known gap, not silently dropped.

## Tracked Sources (verified by reading content + live lookup, not grepped citations alone)

| External source | Files | Notes |
|---|---|---|
| WCAG | `ACCESSIBILITY.md` | Currently cites 2.1; 2.2 is current — real gap to fix now |
| OWASP LLM Top 10 | `RULES-FILE-INTEGRITY.md`, `SECRETS.md`, `SECURITY-GUARDRAILS.md` | Categories cited (LLM01, LLM02, LLM06, LLM10) are current per live verification; `SECURITY-GUARDRAILS.md`'s citation is missing its year, inconsistent with siblings |
| OWASP LLM Top 10 (gap) | `AGENTIC-SAFETY.md` | Content is entirely LLM01 (Prompt Injection) but never cites it — real gap |
| OWASP LLM Top 10 (gap) | `SUPPLY-CHAIN.md` | Content matches LLM03:2025 (Supply Chain) precisely but never cites it — real gap, verified live against OWASP's 2025 list |
| MCP specification | `MCP-SECURITY.md` | Missing real 2026 content (OAuth 2.1 flows, SEP hardening); its own References section cites third-party blogs, never the spec's own security-best-practices page — verified live |

**Ruled out, with reasoning:** `MCP-SECURITY.md` was initially ruled out (no version pinned to
compare against) — reversed after live verification found the doc genuinely missing current
official guidance. `LOGGING.md` stays ruled out — genuinely LLM-agnostic, no framework fit.
`extensions/*.md` individual pinned example versions (react `^18.2.0`, black `23.12.0`, etc.)
are explicitly out of scope — illustrative example syntax, not authoritative claims; tracking
each one would be exactly the "heavy" mechanism this design avoids. The one real finding there
is a structural/behavioral bug, not a version number: `extensions/typescript.md` recommends the
legacy `.eslintrc.json` format; `pitlogic` (a real downstream repo) already uses flat-config
`eslint.config.js`. Fixed as a direct content correction, unrelated to the tracking mechanism.

## Files Changed

| File | Change |
|------|--------|
| 12 `standards/*.md` files (all except `PERFORMANCE-BUDGET.md`, `SECURITY-RULES.md`, `TRUST-CLASSIFICATION.md`) | Add `last-reviewed`/`review-cycle` frontmatter |
| `standards/ACCESSIBILITY.md` | Update WCAG citation 2.1 → 2.2; add `external-source`/`external-version` frontmatter |
| `standards/AGENTIC-SAFETY.md` | Add OWASP LLM Top 10 (2025) LLM01 citation; add tracking frontmatter |
| `standards/SUPPLY-CHAIN.md` | Add OWASP LLM Top 10 (2025) LLM03 citation; add tracking frontmatter; explicitly note the research-statistic citation as a separate, untracked known gap |
| `standards/SECURITY-GUARDRAILS.md` | Fix inconsistent OWASP citation (add missing year); add tracking frontmatter |
| `standards/RULES-FILE-INTEGRITY.md`, `standards/SECRETS.md` | Add tracking frontmatter (citations already correct) |
| `standards/MCP-SECURITY.md` | Add real 2026 content (OAuth 2.1 authorization, SEP hardening summary); replace third-party References with the official spec's security-best-practices page; add tracking frontmatter |
| `standards/extensions/typescript.md` | Replace `.eslintrc.json` guidance with flat-config `eslint.config.js` |
| `scripts/mb.ps1` / `mb.sh` | New doctor check: read frontmatter across `standards/*.md`, apply cadence WARN (Mechanism A) and cached external-version WARN where declared (Mechanism B) |
| New: a small per-framework adapter script/module (WCAG, OWASP LLM Top 10, MCP) + local cache file | Mechanism B's actual check logic |

## Out of Scope

- Content-level semantic diffing against any external source — version-string comparison only.
- Tracking `SUPPLY-CHAIN.md`'s research-statistic citation — different mechanism, not built here.
- Tracking individual pinned example versions in `extensions/*.md` — illustrative, not authoritative.
- A generic, reusable version-diff engine — each tracked framework gets its own small adapter.
