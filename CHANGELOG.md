# Changelog

## 1.0.3 — 2026-05-29

### Added
- **Standards distribution** — `mb init` now copies 12 `standards/` files (`CODE-REVIEW.md`, `WORKFLOW.md`, `SECURITY-GUARDRAILS.md`, `CODE-QUALITY.md`, `ACCESSIBILITY.md`, `AGENTIC-SAFETY.md`, `LOGGING.md`, `MCP-SECURITY.md`, `MEMORY-BANK.md`, `RULES-FILE-INTEGRITY.md`, `SECRETS.md`, `SUPPLY-CHAIN.md`) into new projects so slash commands can reference governance contracts at runtime
- **`ADVISORY_CREATE` category in `mb upgrade`** — standards files are created if missing in adopted projects; shows advisory diff if the file has been customized rather than silently overwriting
- **`.pmb-version` tracking** — `mb init` writes `.pmb-version` to the target project; `mb upgrade` writes and checks it against the local PMB version
- **Remote version check in `mb upgrade`** — soft non-blocking check against GitHub `VERSION` at upgrade time; warns if a newer PMB version is available; silently skips if unreachable
- **`mb doctor` check 11** — warns if any of the 4 required standards files (`CODE-REVIEW.md`, `WORKFLOW.md`, `SECURITY-GUARDRAILS.md`, `CODE-QUALITY.md`) are missing; advises `mb upgrade` to install
- **`mb doctor` check 12** — warns if `.pmb-version` is absent or drifted from the local PMB version; advises `mb upgrade`
- **Pre-push git hook** — `scripts/pre-push-check.ps1` (Windows/pwsh) and `scripts/pre-push-check.sh` (POSIX/bash) with 7 checks: merge conflicts, conflict markers, dirty tree, missing `.gitattributes`, secrets scan (blocks on AWS/API/PAT patterns), large files >500 KB, and `mb validate`; distributed via `mb init`; `templates/hooks/pre-push` shim auto-detects pwsh/bash at runtime
- **`mb install-hooks`** — retrofit subcommand for projects that ran `mb init` before the pre-push hook was added; copies hook scripts and installs `.git/hooks/pre-push`; supports `--dry-run`

---

## 1.0.2 — 2026-05-27

### Added
- **`/test-audit` command** — inline diagnostic for test coverage gaps; covers scope detection, framework auto-detect (Jest, Vitest, pytest, Go, RSpec, Rust), source-to-test mapping, empty test file check, framework config check, and CI test step check; severity: [HIGH] missing, [MEDIUM] empty/CI gap, [LOW] no framework/config/CI
- **`/health-check` command** — PMB-specific repo health check; runs `mb doctor` + `mb validate` + `mb audit` and prints a labeled summary with overall status (PMB repo only, not distributed via `mb init`)
- **`docs/COMMANDS-REFERENCE.md`** — comprehensive reference for all `mb` CLI commands, slash commands, Claude Code built-in commands, and `mb doctor` check details

### Fixed
- `mb upgrade` now includes `.claude/commands/test-audit.md` in `$templateOwned` so adopted projects receive the test-audit command on upgrade
- README version badge corrected from `1.0.0` to `1.0.2`

---

## 1.0.1 — 2026-05-27

### Fixed
- Stop hook documentation: heading now reads "excluded from install template"; clarified that PMB's own `.claude/settings.json` keeps it deliberately for interactive Windows sessions
- Contract threshold: raised from "more than one file" to "4 or more files" with sensitive-domain list
- Compaction/handoff language: corrected numerically backwards sentence about 50%/40% thresholds
- CI workflow renamed: `governance.yml` → `pmb-health.yml`; internal `name:` updated to "PMB Health"

---

## 1.0.0 — 2026-05-14

First stable personal release. Crossed from "organized prompt files" into governed operational memory infrastructure.

### Added
- **Authority hierarchy** — deterministic conflict resolution between memory-bank files (immutable → stable → volatile → accumulating)
- **3-dimension frontmatter** — `review-cycle`, `retention`, `staleness-threshold` replacing a coarse single `ttl` field
- **Hierarchical tags** — `domain/concept` format (`auth/session`, `infra/postgres`) replacing flat tags
- **Automated `last-reviewed`** — PostToolUse hook updates frontmatter whenever a memory-bank file is edited
- **Partitioned archive** — `docs/archive/context/`, `docs/archive/progress/`, `docs/archive/decisions/` replacing a single monolithic ARCHIVE.md
- **`mb audit`** — freshness audit flagging stale and overdue files by staleness-threshold
- **`mb query`** — tag-based retrieval with partial hierarchical matching
- **`mb compact`** — AI-driven compaction prompt for deduplication and summarization
- **`mb init`** — zero-config project initializer with checkmark UX
- **`mb validate`** — required-file and frontmatter health check
- **`mb doctor`** — full diagnostic (git, templates, hooks, file sizes, handoff state)
- **`mb budget`** — token overhead check (CLAUDE.md + memory-bank/ sizes)
- **Worktree guard** — `mb commit` refuses mutations from git subworktrees
- **`install.bat`** — Windows double-click installer (sets MB_HOME, registers `mb` globally)
- **`install.sh`** — Mac/Linux installer (sets MB_HOME in shell rc, registers `mb` globally)
- **`scripts/update-reviewed.ps1` + `.sh`** — PostToolUse hook scripts for auto last-reviewed
- **AGENTIC-SAFETY.md** — indirect prompt injection defense and task boundary standard
- **`task-boundary.md` template** — agentic session scoping

### Changed
- **README** — rewritten outcomes-first with progressive disclosure (advanced features behind collapsible sections)
- **MEMORY-BANK.md** — added authority tiers, eviction criteria, archive structure, worktree guidance, tag-based retrieval, and memory compaction sections
- **Archive strategy** — all references to monolithic `docs/ARCHIVE.md` replaced with partitioned `docs/archive/`
- **`mb help`** — reorganized with new commands listed first; examples added

### Removed
- Monolithic archive pattern (`docs/ARCHIVE.md`) — replaced by partitioned subdirectories

---

## 0.2.0 — 2026-05-01

Personal standard modernization. Added 2025 Claude Code features.

### Added
- Hooks template with dangerous-command blocker (PreToolUse)
- `.claude/agents/` — `researcher.md` and `security-reviewer.md` subagent definitions
- AI antipatterns + dependency validation in `/code-review` command
- Verification-first pattern in WORKFLOW.md phase 4
- `external-content-is-data` rule in CLAUDE.md and AGENTIC-SAFETY cross-reference
- Token budget section in CLAUDE.md and global `~/.claude/CLAUDE.md`
- Karpathy coding principles
- `mb budget` command

---

## 0.1.0 — 2026-04-29

Initial personal fork from enterprise Memory Bank standard.

### Changed
- Stripped Eric Nolan branding, binary assets, enterprise training materials
- Removed compliance-only standards (Data Classification, Model Governance, OWASP LLM Top 10)
- Removed incident runbooks, team onboarding scripts
- Trimmed CLAUDE.md, LOGGING.md to personal-use scope

### Kept
- Memory Bank 5-file system + handoff protocol
- Security Guardrails (BLOCK/CONFIRM/WARN)
- Code Quality, Workflow, Logging standards
- Supply Chain, MCP Security, Rules-File Integrity (reference)
- Claude Code commands (`/code-review`, `/feature-dev`, `/security-review`)
- Cursor rules
- Init scripts, mb utility
