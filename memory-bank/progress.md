---
authority: accumulating
review-cycle: 30d
retention: archive-after-6m
staleness-threshold: 90d
tags:
  - work/completed
  - work/in-progress
  - work/backlog
last-reviewed: 2026-06-26
compaction_generation: 0
source_type: canonical
confidence: high
lineage: []
---

# Progress

## Status: Ready

Personal fork of the enterprise Memory Bank standard — lifecycle management and provenance tracking implemented.

## What's In This Fork

- ✅ Memory Bank system (5-file + handoff protocol) + authority hierarchy + 3-dimension frontmatter
- ✅ Provenance frontmatter: compaction_generation, source_type, confidence, lineage
- ✅ Security Guardrails (BLOCK/CONFIRM/WARN) + 9-rule registry (SECURITY-RULES.md) + 9 security fixtures
- ✅ Code Quality, Logging, 7-phase Workflow standards; Supply Chain, MCP Security, Rules-File Integrity (reference)
- ✅ Slash commands: /pmb-status, /code-review, /feature-dev, /security-review, /test-audit, /health-check, /mb-drift, /change-review
- ✅ mb CLI: init, status, doctor (24 checks), query, clean, commit, upgrade, verify-integrity, plan (status/list/promote/archive) + deprecated aliases
- ✅ Hook suite: dangerous-commands blocker, contract scope check, delegation depth check, auto-last-reviewed, PreCompact memory gate
- ✅ Versioned git hooks via core.hooksPath (.githooks/pre-push + pre-commit), distributed by mb upgrade (TEMPLATE_OWNED)
- ✅ mb upgrade: TEMPLATE_OWNED/ADVISORY_DIFF distribution model; remote version check
- ✅ CI: template-integrity job + SAST (Semgrep p/bash); CLAUDE_AUTOCOMPACT_PCT_OVERRIDE=40
- ✅ install.bat / install.sh, examples/task-tracker-api, VERSION, CHANGELOG.md, docs/COMMANDS-REFERENCE.md
- ✅ Cursor rules (5 rules + code-review rule)

Full history: CHANGELOG.md

## Removed vs Enterprise

- ❌ Eric Nolan branding and brand assets
- ❌ Data Classification, Model Governance, OWASP LLM Top 10 (compliance only)
- ❌ Incident Runbook, accessibility review command
- ❌ Enterprise logging (PII redaction, correlation IDs)
- ❌ Team onboarding scripts and training materials

## Backlog

**Deferred pending operational evidence:**
- ⏸ handoff CLI, pinned.md, mb update --from-git, mb privacy

## Earlier Sessions (2026-06-19 to 2026-06-24) — condensed, full detail in CHANGELOG.md

- ✅ **06-19:** Semantic drift checks 21-23 added to `mb doctor`; `/mb-drift` skill created; startup context trimmed to below 25 KB.
- ✅ **06-22:** `docs/plans/` + `.claude/plans/` workflow scaffolded; `mb plan status|list|promote|archive`; doctor check 24 (plan hygiene); `/change-review` command created (9-job review + ACR bridge).
- ✅ **06-24 Audit Sprint:** Bug fixes (settings.json JSON, pre-compact false positives, TRUNCATE/DELETE guardrails); 8 new test files (115 assertions); CI hardened to 9 jobs (PSScriptAnalyzer, mb-doctor-self-check); perf fixes (O(n²) pre-cache); ACR P0/P1/P2 (comment markers, SARIF, GitHub annotations, schemaVersion).

## Satellite Projects

- **ai-code-review-agent** — `unyieldingclaw-dev/ai-code-review-agent`. v1.1.0: 15 observe-only agents, profiles, --context memory-bank, SARIF, GitHub annotations, agentPolicy, integration contract. 276 tests passing.

## `mb upgrade` Fixes (2026-07-02)

- ✅ Standards ownership: moved 15 `standards/*.md` from `$advisoryCreate` to `$templateOwned` in `Invoke-Upgrade` — they're pure governance substrate, so projects were silently falling behind template updates. Committed `a453a5a`.
- ✅ Slash-command auto-discovery: `Invoke-Upgrade`'s `$templateOwned` hardcoded 5 command filenames, missing 2 shipped in 1.2.0. Now appends every file found in `templates/claude-commands/` at runtime, same pattern `mb init` already used. Committed `465d5d1`. Note: running `mb upgrade` on a stale project syncs *all* of `$templateOwned`, not just commands — all-or-nothing, not a single-file patch.

## Agent Frontmatter `name:` Fix + mb doctor Check 25 (2026-07-03)

- ✅ Fixed missing `name:` frontmatter on `researcher`/`security-reviewer` agents, which silently broke registration. Added `mb doctor` check 25 (name/parity validation); ported missing check 24 into `mb.ps1`. Full detail: CHANGELOG.md.

## Fixed 4 Pre-Existing CI Failures + Closed a Review-Process Gap (2026-07-04)

- ✅ Root cause: PR #7 (above) passed review but CI showed 4 failing jobs, confirmed pre-existing on `main` (inherited, not caused).
- ✅ **SAST:** `p/bash` Semgrep config 404'd → `--config auto`.
- ✅ **Rules-File Integrity / Forbidden Patterns:** both greps false-positived on doc-formatted examples of the patterns they detect. Took two review rounds to close correctly: a single-char lookbehind (bypassable, 1 stray backtick) → a fenced+paired-backtick stripper with a fence-count guard (opposition review found this *still* bypassable: an odd backtick count on one line lets a stray backtick pair with an unrelated later one, deleting real content between them) → final fix adds a per-line even/odd backtick-parity guard, verified against both bypasses plus all known true/false positives.
- ✅ **PowerShell Lint:** `scripts/PSScriptAnalyzerSettings.psd1` excludes `PSAvoidUsingWriteHost` project-wide (console-output CLI/hook scripts); `Write-Verbose` added to 22 empty catches; BOM added to 17 files; `Normalize-MbLine`→`Format-MbLine` rename; dead `Invoke-InstallHooks` removed; 2 false-positive unused-param warnings suppressed.
- ✅ **Closed the review-process gap** (`docs/HOOKS-GUIDE.md`: Reviewer shouldn't duplicate CI): added `/change-review` Step 3.5 — Baseline Repo Health, local/offline, informational, never blocking. Also fixed its marker-hash commands, which didn't match the push-gate hook in all cases.
- ✅ Two rounds of 5-domain review + opposition caught 3 self-inflicted regressions pre-commit: the bypassable strip logic (twice, above) and a stray em dash that would've reintroduced a BOM warning. `bash tests/run.sh` (44/44), `mb doctor` clean.
- ✅ Pushed (`c83e007`); CI still showed 2 `PSAvoidUsingEmptyCatchBlock` warnings at `check-contract.ps1:64` — a `catch { # comment }` is still "empty" to PSScriptAnalyzer (comments aren't statements), missed in the 22-instance sweep since it wasn't a bare `catch {}`. Fixed with the same `Write-Verbose` pattern (`b1105e3`), both `scripts/` and `templates/scripts/` copies. All 9 CI jobs confirmed green on PR #7.
