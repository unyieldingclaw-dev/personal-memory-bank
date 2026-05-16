# Changelog

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
- Stripped T-Mobile branding, binary assets, enterprise training materials
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
