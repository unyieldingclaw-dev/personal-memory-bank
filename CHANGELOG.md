# Changelog

## [1.2.1] — 2026-08-03 (mb.ps1 review-reminders export gap)

### Fixed
- `scripts/mb.ps1`: `Invoke-Init`'s hook-scripts copy loop excluded `review-reminders.sh`/`.ps1` and `review-reminders-post.sh`/`.ps1` — only `Invoke-Upgrade`'s `$templateOwned`/gap-detection got the 1.2.0 (review-gate hardening) fix, so a fresh PowerShell `mb init` shipped a `settings.json` referencing hook scripts never actually copied into `scripts/` (they'd only appear on a subsequent `mb upgrade`). This closes the PowerShell-side twin of the same-day `mb.sh` fix below. Added regression coverage: `tests/mb-setup.Tests.ps1` asserts `mb init` (subprocess) creates all 4 files.

## [1.2.1] — 2026-08-03 (mb.sh review-reminders export gap)

### Fixed
- `scripts/mb.sh`: `templates/.claude/settings.json` invokes `scripts/review-reminders.sh`/`.ps1` and `scripts/review-reminders-post.sh`/`.ps1` directly for the commit/push review gate, but none of the 4 files were in `mb init`'s hook-scripts copy loop or `mb upgrade`'s `TEMPLATE_OWNED` array — a fresh `mb init`/`mb upgrade` shipped a `settings.json` referencing hook scripts that were never actually copied into the target project's `scripts/` directory, silently disabling the review gate for every project onboarded via `mb.sh` (only this repo's own native copies worked). `scripts/mb.ps1` got the `TEMPLATE_OWNED` half of this fix in 1.2.0 (review-gate hardening) but not the corresponding `mb.sh` change — this closes that parity gap. Added regression coverage: `tests/test-mb-init.sh` asserts all 4 files are created by `mb init`; `tests/test-mb-upgrade.sh` asserts `mb upgrade` restores them via `TEMPLATE_OWNED`.

### Known gap, not fixed here (closed above)
- `scripts/mb.ps1`'s `Invoke-Init` copy loop also excludes these 4 files (only its `TEMPLATE_OWNED`/gap-detection got the 1.2.0 fix) — PowerShell `mb init` on a fresh project has the same bug. Tracked separately.

## [1.2.1] — 2026-07-04 (template scaffolding gap)

### Fixed
- `templates/CLAUDE.md` references `docs/CONTRACTS-GUIDE.md` and `docs/HOOKS-GUIDE.md`, but neither file existed anywhere under `templates/` — `mb init`/`mb upgrade`/`mb setup` never scaffolded them into downstream projects, leaving every project's `CLAUDE.md` pointing at docs that don't exist. Discovered via `mb-setup.bat` flagging governance gaps on an existing project.
- Added `templates/docs/CONTRACTS-GUIDE.md` (verbatim copy of PMB's own guide, already generic) and `templates/docs/HOOKS-GUIDE.md` (trimmed — dropped PMB-repo-specific "bug found and fixed" postmortem prose, kept the reusable hook reference).
- `scripts/mb.ps1`: `Invoke-Init`, `Invoke-Upgrade`'s `$templateOwned`, and `Get-MbUpgradeAnalysis`'s gap-detection now all auto-discover `templates/docs/*.md` (same pattern already used for `templates/claude-commands/*` — a hardcoded list of these went stale before, per the existing comment on that fix).
- `scripts/mb.sh`: `invoke_init` now copies `templates/docs/*`; `invoke_upgrade`'s `ADVISORY_CREATE` now includes both doc files (create-if-missing, matching how `mb.sh` already handles other reference docs).

### Remediation for already-scaffolded projects
Any project that ran `mb init`/`mb setup` before this fix has a `CLAUDE.md` with dangling doc references. Re-running `mb upgrade` in that project after upgrading to PMB 1.2.1 will create the two missing files (now template-owned / advisory-create, so "create if missing" applies retroactively).

## [1.2.0] — 2026-07-03 (review-gate hardening)

### Fixed
- `scripts/dangerous-commands.ps1/.sh`, `scripts/check-contract.ps1/.sh`: read the wrong JSON field path (flat `.command`/`.file_path` instead of nested `tool_input.command`/`tool_input.file_path`) and signaled denial via exit codes, which `settings.json`'s fail-open wrapper silently erased — both hooks were near-total no-ops. Fixed to use `hookSpecificOutput.permissionDecision: "deny"`.
- `scripts/check-contract.ps1/.sh`: schema bug — read `scope.files` instead of the documented `scope: [{file, op}]` array. `.sh` version also had a Windows CRLF bug from Python's `print()` breaking exact-match comparisons.
- `scripts/dangerous-commands.ps1/.sh`: pipe-to-shell BLOCK pattern collided with `sha256sum`/`shasum` — fixed with word-boundary matching.
- Hash mismatch between documented review-gate commands and hook verification: PowerShell's pipeline re-tokenizes external-command output, so array-join hashing didn't reproduce the byte stream a raw shell pipe sees. Fixed by hashing a file written via redirection instead.
- `.claude/settings.json` + `templates/.claude/settings.json`: stale `CLAUDE_AUTOCOMPACT_PCT_OVERRIDE=40` bumped to `65` to match current guidance.

### Added
- `scripts/review-reminders.ps1/.sh` + `-post.ps1/.sh`: `PreToolUse`/`PostToolUse` hook pair mechanically enforcing review-before-commit/push via a SHA-256 diff-hash marker (see ai-code-review-agent CHANGELOG for full design). Wired into PMB's own live `.claude/settings.json` (dogfooding) and added to `scripts/mb.ps1`'s `$templateOwned` list so `mb init`/`mb upgrade` distribute it to downstream projects.
- `docs/HOOKS-GUIDE.md`: documented the fixed dangerous-commands/check-contract mechanisms and the review-gate hash-binding/atomic-consume/reissue design.

## [1.2.0] — 2026-07-04 (CI health fixes)

### Fixed
- **`.github/workflows/pmb-health.yml` SAST job** — `semgrep --config "p/bash"` returned HTTP 404 (no longer a resolvable registry ruleset); switched to `--config auto`.
- **Rules-File Integrity "hidden HTML comments" check** — false-positived on `standards/RULES-FILE-INTEGRITY.md`'s own backtick-wrapped documentation examples. Refined to strip fenced code blocks and paired inline-code spans before matching, with two guard rails found necessary through two rounds of adversarial review: (1) an odd count of ``` fence markers falls back to inline-only stripping, so a malformed fence can't hide the rest of a file from the check; (2) an odd count of backticks *on a single line* leaves that line unstripped entirely, since a naive `` s/`[^`]*`//g `` still pairs a stray backtick with an unrelated later one and silently deletes everything between — including a real hidden comment placed right after the stray backtick. (Two earlier variants — a single-character negative lookbehind, then a stripper without the per-line parity guard — were each found bypassable in review and replaced before shipping.)
- **Forbidden Patterns "spec placeholder grep"** — false-positived on two spec docs' own code-formatted examples of the TBD/TODO pattern. Uses the identical strip-fenced-code-and-paired-backticks helper (with both guard rails) as the fix above.
- **PowerShell Lint** — added `scripts/PSScriptAnalyzerSettings.psd1` excluding `PSAvoidUsingWriteHost` project-wide (every `.ps1` here is a CLI/hook script whose job is console output); added `Write-Verbose` diagnostics to 22 previously-empty `catch {}` blocks; added a UTF-8 BOM to the 17 `.ps1` files that needed it; renamed `Normalize-MbLine` → `Format-MbLine` in `mb.ps1` (not an approved PowerShell verb); removed the dead `Invoke-InstallHooks` function (~92 lines, zero call sites); added targeted suppressions for `$DryRun`/`$Force` false-positive unused-parameter warnings (both read via script-scope chaining in nested functions).
- **`.claude/commands/change-review.md` marker-hash commands** — both the Bash and PowerShell snippets were missing the `git diff HEAD` fallback that `scripts/review-reminders.sh`/`.ps1` actually use when no `origin/main` upstream exists; added to match exactly.

### Added
- **`.claude/commands/change-review.md` Step 3.5 — Baseline Repo Health** — a new informational-only, offline-only spot-check against the whole working tree (not diff-scoped), so a diff-clean review doesn't silently approve a change sitting on a CI-red base branch. Never blocking; explicitly excludes network-dependent tools (Semgrep, PSScriptAnalyzer, gitleaks), which remain CI-only per this repo's layered-enforcement design.

## [1.2.0] — 2026-07-03 (agent frontmatter fix)

### Fixed
- **`.claude/agents/*.md` missing `name:` field** — Claude Code silently fails to register a custom subagent without a `name:` frontmatter field; `researcher.md` and `security-reviewer.md` (plus their `templates/.claude/agents/` copies) had this bug. Added `name:` to all 4 files.
- **`.claude/commands/health-check.md`** — corrected a mislabeled "Check 24" reference to the actual staleness check (check 9); removed the only non-functional `@agent-name` invocation-syntax mention in the repo.
- **`mb doctor` check 25 ("Agent frontmatter") elif-suppression** — a directory with both a missing-`name:` agent and a mismatched-`name:` agent only reported the first; now both report independently.
- **`mb doctor` check 25 `name:` extraction** — now scoped to the frontmatter block only (was scanning the whole file), strips surrounding quotes, and no longer over-strips internal spaces from multi-word values, on both `mb.sh` and `mb.ps1`.
- **`mb.ps1` check 24 (Plan hygiene) port** — was previously missing entirely from `mb.ps1`, leaving `mb.sh`/`mb.ps1` doctor check counts out of sync; ported, including a `ParseExact` try/catch guard matching sibling call sites (was unguarded, could abort the rest of `mb doctor` on an unparseable git date) and a frontmatter-presence match aligned with `mb.sh`'s looser `grep -c '^---'` behavior.
- **"24 checks" → "25 checks"** — updated `README.md` (both occurrences), `.claude/commands/health-check.md`, `docs/COMMANDS-REFERENCE.md` (was already stale at "20 checks"; table extended through check 25), and `tests/test-mb-doctor.sh` header.

### Added
- **`mb doctor` check 25 ("Agent frontmatter")** — scans `.claude/agents/*.md`, warns on missing or filename-mismatched `name:` fields, in both `mb.sh` and `mb.ps1`.
- **`mb doctor` check 25 live/template parity check** — in the PMB source repo (where `templates/.claude/agents/` exists), warns if a live agent file diverges from its template copy.

## [1.2.0] — 2026-06-26 (additional hardening)

### Fixed
- `scripts/mb.sh`: doctor check 5 token budget drift — replaced `grep -c` with `grep -q` + explicit 0/1 assignment (was permanently SKIP in Git Bash due to double-output bug)
- `tests/test-mb-doctor.sh`: added EXIT trap guards to all 4 sites that mutated `$REPO_ROOT` directly — git status now clean after any test outcome
- `scripts/check-contract.sh` + `.ps1`: empty scope `[]` no longer fires spurious out-of-scope warning; malformed JSON now emits visible warning instead of silent pass; handles both ACR `[{file,op}]` and PMB `{files:[]}` scope schemas
- `.claude/commands/health-check.md`: removed deprecated `mb validate` and `mb audit` (now aliases for `mb doctor`); replaced with `mb status` and doctor staleness review
- `.github/workflows/pmb-health.yml`: PSScriptAnalyzer now checks `-Severity Error,Warning`; gitleaks-action pinned to commit SHA `ff98106e`

### Added
- `.github/dependabot.yml`: weekly GitHub Actions version tracking
- `.claude/commands/change-review.md` Job 7: now passes `--diff <tmpfile>` to ACR (was reviewing wrong diff surface for non-default invocations)

---

## 1.2.0 — 2026-06-24

### Added
- **Comprehensive bash test suite** — expanded from 3 tested commands to all 11 `mb` commands. Added 8 new test files covering `mb doctor` (25 cases — all 24 checks + clean baseline), `mb status` (6 cases), `mb verify-integrity` (3 cases), `mb query` (4 cases), `mb init` (3 cases), `mb clean` (2 cases), `mb commit` (2 cases), and `mb upgrade` (3 cases). Total test count: 115 assertions across 11 suites.
- **CI: `powershell-lint` job** — PSScriptAnalyzer at Error severity on all `.ps1` files in `scripts/` and `templates/scripts/`. CI now has 9 jobs total.
- **CI: `mb-doctor-self-check` job** — runs `mb doctor` against the PMB repo itself on every push, surfacing drift in memory-bank, standards count, plan hygiene, and hook config.

### Fixed
- **`mb doctor` check 2 + check 13 fixture restore hardened** — test previously renamed entire `templates/` or `fixtures/security/` directories; now renames a single subdirectory with conditional restore, preventing data loss if interrupted.

### Changed
- **`mb doctor` checks 22 & 23: O(n²) → pre-cached normalization** — normalized strings are now pre-built once before the outer loop in both `mb.sh` and `mb.ps1`, eliminating ~10,000 subprocess spawns per doctor run on 100-line files.
- **`show_budget` find pipe** — replaced `find | xargs wc -c` with `find -exec wc -c {} +` (single `wc` call instead of one per file) in `mb.sh`.
- **`mb help` deprecated aliases** — both `mb.sh` and `mb.ps1` now show a `Deprecated aliases` section at the bottom of help output. `mb.ps1` Show-Help also gains `plan`, `preflight`, and `change-check` in the active commands list (parity with `mb.sh`).

### Documentation
- **`docs/HOOKS-GUIDE.md`** — added section 6 (Agent Delegation Depth Check) documenting the `.pmb-delegation-depth` runtime state file, 2-hour reset behavior, and error logging.
- **`.claude/commands/health-check.md`** — corrected `mb doctor` check count from 20 to 24.

---

## 1.1.2 — 2026-06-24

### Fixed
- **`settings.json` invalid JSON** — missing comma in the `permissions.allow` array (after `"Bash(python -m ruff *)"`) caused strict JSON parsers to reject the file. Added the missing comma.
- **`pre-compact-check` false positives** — the progress.md date check used a free substring search (`grep -q "$today"`), which matched dates embedded in prose (e.g. "see spec from 2026-06-24") and incorrectly allowed compaction. Fixed to require the date at the start of a line (optionally preceded by a markdown heading or list prefix). Applied to `scripts/pre-compact-check.sh`, `scripts/pre-compact-check.ps1`, and their template copies.
- **Missing `TRUNCATE TABLE` and `DELETE FROM` guardrails** — both patterns were listed as CONFIRM-tier in `standards/SECURITY-GUARDRAILS.md` but absent from the dangerous-commands scripts. Added to `scripts/dangerous-commands.sh`, `scripts/dangerous-commands.ps1`, and their template copies. Shell scripts include explicit lowercase variants for POSIX case-sensitivity parity; PowerShell uses its native case-insensitive matching.
- **`templates/scripts/pre-compact-check.sh` stale whitespace trimming** — template was still using a `sed` subprocess per line; synced with the live script's pure bash parameter expansion (~100 fewer process spawns per compaction check).

### Documentation
- **`docs/HOOKS-GUIDE.md`** — updated CONFIRM pattern count from 5 to 7; corrected PreCompact detection logic description from mtime-based to content-based (the actual implementation).

---

## 1.1.1 — 2026-06-18

### Fixed
- **`check-contract.ps1` / `check-contract.sh` stdin fix** — both live and template copies were reading tool input from `$env:CLAUDE_TOOL_INPUT` (PowerShell) / `os.environ.get('CLAUDE_TOOL_INPUT')` (bash), an env var that Claude Code never sets. Hooks were silently failing open on every invocation. Fixed to read stdin: `$input | Out-String` (PowerShell) and `HOOK_INPUT=$(cat 2>/dev/null)` (bash).
- **`mb.sh` TEMPLATE_OWNED parity** — `scripts/pre-push-check.sh` and `scripts/pre-push-check.ps1` were missing from the bash `TEMPLATE_OWNED` array; `mb upgrade` on bash systems would silently skip overwriting these files. `mb.ps1` and the `invoke_init` for-loop already had them. Now consistent across all four sites.
- **`docs/HOOKS-GUIDE.md` per-project example** — "Lint Before Commit" example used `echo "$CLAUDE_TOOL_INPUT"` (same broken env-var pattern). Fixed to `HOOK_INPUT=$(cat 2>/dev/null); echo "$HOOK_INPUT"`.
- **`docs/QUICK-REFERENCE.md` doctor check count** — description read "16-point diagnostic"; doctor has had 20 checks since v1.0.8.

---

## 1.1.0 — 2026-06-11

### Changed
- **Git hooks migrated to `core.hooksPath = .githooks`** — hooks are now versioned in the project repo (`.githooks/pre-push`, `.githooks/pre-commit`) and distributed via `mb upgrade` (TEMPLATE_OWNED). `mb init` and `mb upgrade` set `core.hooksPath = .githooks` automatically. `mb upgrade` performs one-shot cleanup of the old `.git/hooks/pre-push` shim on legacy projects.
- **Pre-commit hook now active** — `.githooks/pre-commit` existed in the PMB repo but was dead (`core.hooksPath` not set). Now fires on every commit: blocks `handoff.md` staging, warns if `CLAUDE_AUTOCOMPACT_PCT_OVERRIDE` is missing from `.claude/settings.json`.
- **`mb doctor` check 4 updated** — verifies `.githooks/pre-push` presence and `core.hooksPath = .githooks`; bash doctor gains equivalent check (previously missing).
- **`docs/HOOKS-GUIDE.md`** — new "Git Hooks (versioned)" section documents the two hooks, `core.hooksPath` activation, and migration path from `.git/hooks/`.

### Breaking
- Projects using PMB hooks must run `mb upgrade` to activate the new layout. After upgrade, `.git/hooks/pre-push` is removed (if it is the PMB shim) and hooks run from `.githooks/` instead.

---

## 1.0.9 — 2026-06-11

### Added
- **`mb update` alias** — `mb update` now runs the same upgrade logic as `mb upgrade`; documented in `docs/COMMANDS-REFERENCE.md`

### Changed
- **Hook script performance** — behavioral no-ops, same output, fewer processes:
  - `check-contract.sh`: 3 Python spawns + 6 sed subshells → single Python heredoc invocation
  - `pre-compact-check.sh`: sed subprocess per line → bash parameter expansion
  - `mb doctor` check 10: 7 grep calls per file → 1 combined grep per file
  - `mb doctor` check 17: echo|grep per line (~400 subshells) → grep directly on file (2 calls)

---

## 1.0.8 — 2026-06-06

### Added
- **Command consolidation finalized** — `mb verify-integrity` added as an explicit command; all 8 deprecated aliases updated to clearer redirect messages; `mb clean` output references corrected from `mb slim`/`mb archive`/`mb compact`
- **`mb doctor` Check 17 — Semantic drift detection** — scans `activeContext.md` and `progress.md` for transition/removal language (`deprecated`, `migrated from`, `replaced by`, `no longer`, `switching from`, etc.) and surfaces matching lines for human review against stable files; heuristic, low-noise (skips frontmatter, headings, blank lines)
- **`mb doctor` Check 18 — Old stable decisions** — flags `authority:stable` or `authority:immutable` files whose `last-reviewed` date is >180 days ago; prompts review to confirm decisions are still accurate
- **`mb doctor` Check 19 — Cross-file contradiction detection** — verifies authority hierarchy is consistent with PMB conventions (`projectbrief.md=immutable`, `systemPatterns.md/techContext.md=stable`, `activeContext.md=volatile`, `progress.md=accumulating`); also checks for negation language under shared `##` headings across stable vs. volatile files
- **`mb doctor` Check 20 + `mb verify-integrity` — Integrity checksums** — computes SHA-256 of all 5 memory-bank files; stores in `.pmb-checksums` (gitignored); on next run, compares against baseline and reports [ERROR] for any file modified outside mb tooling; `mb verify-integrity` runs this check standalone
- **Compaction quality gate** — `pre-compact-check.ps1`/`.sh` now BLOCK compaction (exit 2) unless: (1) `activeContext.md` has ≥3 substantive content lines and (2) `progress.md` has an entry dated today; `handoff.md` bypasses the gate; errors remain fails-open (exit 0)
- **Agent delegation depth enforcement** — new `scripts/delegation-depth-check.ps1`/`.sh`; wired as `PreToolUse` hook on the `Agent` tool in `.claude/settings.json`; emits WARN when delegation depth exceeds budget (≤1 per `PERFORMANCE-BUDGET.md`); state stored in `.pmb-delegation-depth` (gitignored), resets after 2h inactivity
- **`mb doctor` checks 15–16 added to `mb.sh`** — previously only in PowerShell; bash script now has parity on startup context ceiling and hook error log checks
- **`.gitignore` entries** — `.pmb-checksums`, `.pmb-delegation-depth`, and `.pmb-hook-errors.log` added to project root `.gitignore`; `mb init` now adds all three to new project `.gitignore`
- **`standards/AGENTIC-SAFETY.md`** — new "Agent Delegation Depth Enforcement" section documenting the hook behavior, threat model, budget limit, and how to disable

### Changed
- `mb init` allowlist expanded: `delegation-depth-check.ps1`/`.sh` added to exported hook scripts
- `mb upgrade` `TEMPLATE_OWNED` expanded: `delegation-depth-check.ps1`/`.sh` now overwritten on upgrade
- `docs/COMMANDS-REFERENCE.md` — updated to 20-check doctor table; `mb verify-integrity` added to command table
- All deprecated alias redirect messages changed from past-tense to present-tense ("has been integrated" → "is now part of")

---

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
