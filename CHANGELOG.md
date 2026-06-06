# Changelog

## 1.0.7 — 2026-06-06

### Added
- **G1 — PowerShell tool hook** — `dangerous-commands.ps1` now intercepts both the Bash and PowerShell Claude Code tools; 8 PowerShell-native BLOCK patterns added: `Remove-Item -Recurse -Force`, `Remove-Item -Force -Recurse`, `Format-Volume`, `| Invoke-Expression`, `|Invoke-Expression`, `| iex`, `|iex`; both `.claude/settings.json` and `templates/.claude/settings.json` updated
- **G2 — Hook failure alerting** — all 4 hook scripts (`dangerous-commands`, `check-contract`, `pre-compact-check`, `update-reviewed`) append a timestamped entry to `.pmb-hook-errors.log` on unexpected error; `mb doctor` Check 16 reports log presence and recent entries as WARN; `mb init` adds `.pmb-hook-errors.log` to `.gitignore` for new projects
- **G3 — Contract scope hard-block mode** — `PMB_CONTRACT_HARD_BLOCK=1` env var promotes contract scope warnings to hard blocks (exit 2) in both `check-contract.ps1` and `check-contract.sh`; documented in `standards/SECURITY-GUARDRAILS.md` with `env` block example
- **G4 — First-push secret scan** — `pre-push-check.ps1` / `.sh` now falls back to `git log --not --remotes -p` when no upstream tracking ref exists, scanning all commits not yet on any remote; large-files check (Check 6) also fixed for the no-upstream case; replaces the previous `[SKIP]` behavior
- **G5 — Rules-file integrity CI** — new `rules-file-integrity` job in `pmb-health.yml`: three steps — invisible Unicode characters (U+200B/C/D/FEFF/202E/00AD/2066-2069), hidden HTML comments (`<!--`), LLM bypass phrases in `CLAUDE.md` / `templates/CLAUDE.md`
- **G6 — SAST CI** — new `sast` job in `pmb-health.yml`: Semgrep CLI with `p/bash` ruleset scanning `scripts/` and `templates/scripts/`; exits non-zero on any finding
- **`mb doctor` Check 15** — startup context size ceiling: WARN if `CLAUDE.md` + `memory-bank/` total exceeds 15 KB, ERROR if over 25 KB
- **`mb doctor` Check 16** — hook error log: WARN with entry count and last 3 lines if `.pmb-hook-errors.log` exists and is non-empty
- **`install.bat`** — GUI folder picker to init first project at install time; `mb-new-project.bat` launcher; `pick-folder.ps1` helper

### Changed
- **mb commands redesigned (8 primary commands)** — `mb doctor` now absorbs `audit`, `validate`, and `budget`; `mb clean` added (absorbs `compact`, `update`, `archive`, `slim`); `mb upgrade` absorbs `install-hooks`; deprecated commands still work as redirects; `mb help` updated to show 8 primary commands
- **`.pmb-version`** initialized in the PMB repo itself (was missing)

---

## 1.0.6 — 2026-06-03

### Changed
- **`standards/CODE-REVIEW.md`** — replaced `Confidence: High|Medium|Low` with `Basis: VERIFIED|INFERRED|SPECULATIVE`; added Basis Classification and Evidence Requirements sections with per-basis evidence rules; tightened blocking semantics (`Blocking: true` requires `Severity >= High AND Basis != SPECULATIVE`); updated Required Report Sections to `Supported Findings` + `Predicted Risks`; added three new Failure Criteria (missing `file:line`, evidence not materially supporting claim, SPECULATIVE marked blocking); added Compatibility Note
- **`templates/standards/CODE-REVIEW.md`** — mirrors `standards/CODE-REVIEW.md` (distribution template)
- **`.claude/commands/code-review.md`** — Step 4 updated to reference `Basis` field definitions; Step 6 report template split into `## Supported Findings` (VERIFIED/INFERRED) and `## Predicted Risks` (SPECULATIVE, omitted if empty)
- **`templates/claude-commands/code-review.md`** — mirrors `.claude/commands/code-review.md`

**Breaking change:** `Confidence` field removed from the code review finding schema. Consumers parsing review output must update to `Basis`.

*(Note: VERSION 1.0.5 was not bumped at the time of that release; version counter corrected here.)*

---

## 1.0.5 — 2026-06-03

### Added
- **`/pmb-status` slash command** — fast state check (the `git status` of PMB); answers "can I work?" with 5 signals: Initialized, Core Memory Present, Active Context Current, Standards Available, Tasks Present; surfaces attention items with one-line remediation hints; no deep validation (that belongs in `/health-check`); distributed via `mb init` and `mb upgrade`
- **`templates/claude-commands/pmb-status.md`** — distribution template for `/pmb-status`

### Changed
- **`mb status`** — replaced file-size table with the same 5-signal state check that backs `/pmb-status`; now answers "can I work?" rather than "are files within size limits?" (size budget info remains available via `mb doctor`)

---

## 1.0.4 — 2026-05-31

### Added
- `standards/SECURITY-RULES.md` — rule registry (SEC-001–009) for structured security findings
- `standards/TRUST-CLASSIFICATION.md` — TRUSTED/SEMI_TRUSTED/UNTRUSTED source classification reference
- `standards/PERFORMANCE-BUDGET.md` — explicit limits for standards count, memory entries, agent delegation depth
- `fixtures/security/` — 9 known-bad code samples for security regression testing (SEC-001–009)
- `mb doctor` Check 13: verifies `fixtures/security/` structure (9 subdirectories)
- `mb doctor` Check 14: counts `standards/*.md` files; warns if > 20
- `/health-check` step 5: runs `/security-review` against security fixtures, reports caught/missed per rule ID
- Structured finding format for `/security-review` command and security-reviewer agent: Rule ID, Evidence, Confidence, Fix
- Trust level note in security-reviewer agent for prompt-injection and rules-file-integrity findings
- All 3 new standards distributed via `mb init` and `mb upgrade` (ADVISORY_CREATE)

---

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
