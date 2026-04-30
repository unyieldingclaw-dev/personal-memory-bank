# Model Governance

> **TODO: Validate against T-Mobile internal security / legal / compliance policy before broad adoption.**

Which AI models your team uses, and which versions, and how you roll changes, is itself a dependency surface. Silent deprecations, auto-downgrades to cheaper models, and untracked version drift cause real incidents: behavior regressions, cost surprises, and — with coding agents — code-quality regressions that ship to production before anyone notices. This standard defines the approved-model list, the pinning policy, and the change-management process.

## Principles

1. **A model upgrade is a dependency upgrade.** Treat it with the same rigor as bumping a library major version.
2. **Pin specific versions in production contexts.** Avoid silent behavior drift by not floating to "latest".
3. **Changes go through review.** Adding a model, bumping a version, or swapping a plugin is a reviewed change, not a unilateral decision.
4. **One approved list per team.** Every project that consumes memory-bank should share the same approved list.

## Approved-model list

(This list is the canonical starting point. Update via PR when the team ratifies changes. Cross-reference with T-Mobile's internal AI vendor list and procurement approvals.)

### Claude (Anthropic) — primary

| Model | Status | Typical use | Notes |
|-------|--------|-------------|-------|
| `claude-opus-4-7` | ✅ Approved | Deep code review, architecture design, high-stakes decisions | Highest capability; highest cost |
| `claude-sonnet-4-6` | ✅ Approved | Default coding agent for most day-to-day work | Best balance of capability and cost |
| `claude-haiku-4-5` | ✅ Approved | Quick lookups, small-scope edits, high-volume automation | Lowest cost; verify output for critical tasks |
| `claude-3-*` and earlier | ⚠️ Deprecated | Not recommended for new work | Migrate to Claude 4.x family |

### GPT (OpenAI) — if used

| Model | Status | Notes |
|-------|--------|-------|
| Any production use | ⚠️ Requires approval | Requires T-Mobile data-processing agreement check; confirm with security / legal before sending any Internal-tier or higher data |

### Other models

| Category | Status |
|----------|--------|
| Self-hosted / local (Ollama, LM Studio, etc.) | ⚠️ Approved for dev work with synthetic data only; not for Confidential or Restricted tier |
| Hugging Face public models | ❌ Banned for direct production use without vetting (2025 scans found 3,300+ models with rogue code execution via poisoned pickle files) |
| Any model whose vendor does not publish data-handling terms | ❌ Banned |

## Version pinning policy

### Production code and shipped tooling

- **Pin** the exact model version in configuration: e.g., `model: "claude-opus-4-7"`, not `model: "claude-opus-latest"`.
- Treat the pinned version as part of the dependency surface. Changes to it go through code review.
- Test against the pinned version in CI.

### Development / interactive sessions

- Developers may run whatever approved model they prefer locally.
- If a local task produces code destined for merge, re-run the critical checks (`/code-review`, tests, lint) on the project's pinned model before committing.

### Claude Code / Cursor / IDE settings

- IDE default models can float within the approved list for day-to-day work.
- Slash commands that ship in this repo (`/feature-dev`, `/security-review`, `/code-review`, `/accessibility-review`) should be tested against the pinned model periodically and any prompt tuning documented.

## Change management — adding, removing, or upgrading a model

1. **Propose** the change in a PR that edits this document. Include:
   - Why (use case, cost change, capability gap being closed)
   - Known regressions (if any)
   - Canary plan (where will we test first?)
2. **Canary** the change in one low-risk project or a feature branch. Run:
   - The repo's test suite, if any
   - `/code-review` on a representative recent commit
   - `/security-review` on a representative recent commit
   - Manual smoke test of the slash commands
3. **Review** the canary results. Attach to the PR.
4. **Merge** the updated approved-model list. Propagate any prompt-tuning changes to the rules / commands at the same time.
5. **Communicate** the change on the Teams channel: `RE - SkyNet Support - AI Discussion`.

## What happens when a model is deprecated

Anthropic and OpenAI deprecate models with notice. When you see a deprecation:

1. File an issue referencing this standard.
2. Identify which projects / slash commands / configs use the deprecated model.
3. Pick the successor (usually the next major in the same family).
4. Follow the change-management process above to swap.
5. Remove the deprecated entry from the approved list when the migration is complete, or move it to `⚠️ Deprecated` if there are stragglers.

## Interaction with other standards

- `standards/SECURITY-GUARDRAILS.md` BLOCK tier refuses to exfiltrate data to non-approved vendors. The approved-model list is the authoritative source of what "approved vendor" means for LLM use.
- `standards/DATA-CLASSIFICATION.md` defines what tier of data may be sent to which class of model (e.g., Restricted never leaves trusted infra; Confidential requires approved vendor with data-processing terms).
- `standards/LLM-TOP-10-MAPPING.md` tracks the Top-10 risks per pinned model; re-validate when pinning changes.

## Anti-patterns

- **Floating to "latest"** in production — silent behavior drift, untracked regressions.
- **"It's just a minor version bump"** — minor version bumps can change behavior materially. Canary anyway.
- **Mixing models across environments** — dev on Opus, prod on Haiku: output quality differs, test signal is degraded.
- **Using an unapproved local model with Confidential data** — self-hosted is not the same as "safe"; see Data Classification.
- **Letting MCP tool authors pick the model** — tool-definition-driven model choice is a vector for silent downgrades. The consumer controls the model.

## References

- [FINOS AI Governance Framework — Model Version Pinning](https://air-governance-framework.finos.org/mitigations/mi-10_ai-model-version-pinning.html)
- [Anthropic model deprecation policy](https://docs.anthropic.com/en/docs/about-claude/model-deprecations)
- [OWASP LLM Top 10 (2025)](https://owasp.org/Top10/2025/) — LLM03 Supply Chain, LLM06 Excessive Agency
- [NIST SP 800-218A](https://csrc.nist.gov/pubs/sp/800/218/a/final) — model provenance and change management

---

**Version**: 1.0.0
**Last Updated**: April 24, 2026
**Owner**: T-Mobile Release Engineering/AERO Team
