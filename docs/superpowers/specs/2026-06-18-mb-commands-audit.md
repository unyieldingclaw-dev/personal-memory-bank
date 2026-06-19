# PMB Commands & Hook Wiring Audit — 2026-06-18

**Scope:** Full audit of mb commands, hook wiring, slash commands, semantic gaps, session/handoff flow, and template parity.
**Method:** 6 parallel Explore agents (one per lens), findings compiled from read-only file analysis.

---

## Finding Schema

| Field | Values |
|---|---|
| Type | Bug \| Gap \| Overstepping \| Wiring Error \| Semantic Issue \| Doc Drift |
| Severity | Critical \| High \| Medium \| Low |

Fix effort groups (used in implementation plan):
- **Zero-effort** — 1-line change, no design needed
- **Low effort** — <30 min, clear fix
- **Medium effort** — design decision required
- **Deferred** — valid observation, not now

---

## Lens 1 — Hook Wiring

| ID | Area | Type | Severity | Description | Recommendation |
|---|---|---|---|---|---|
| H1 | check-contract.ps1/sh | Bug | **Critical** | Reads tool input from `$env:CLAUDE_TOOL_INPUT` (line 55 in .ps1). Claude Code passes hook input via stdin. All other hook scripts (dangerous-commands, update-reviewed) correctly read stdin. Result: contract scope checking is silently broken — every Write/Edit passes without scope validation. | Fix both .ps1 and .sh to read from stdin, matching the pattern in dangerous-commands.ps1 |
| H2 | settings.json PostToolUse | Wiring Error | **High** | PostToolUse hook uses `powershell` (Windows PS 5.x); all PreToolUse, PreCompact, and Stop hooks use `pwsh` (PS 7). Inconsistent runtime with different behavior (encoding, cmdlet availability, error handling). | Change PostToolUse to `pwsh -NonInteractive -File` to match the rest |
| H3 | settings.json fail-open | Semantic Issue | **Medium** | All hooks append `|| true` making them fully fail-open. For check-contract and dangerous-commands, silently swallowing errors means governance is invisible when the script crashes. | Add stderr capture and a minimal log-to-file fallback before `|| true` for BLOCK-tier hooks |
| H4 | Stop hook | Semantic Issue | **Medium** | Stop hook uses `powershell.exe -Command` with WinForms `MessageBox::Show`. Blocks Claude's response thread until dismissed. On Windows 11 Home, WinForms is available but the modal dialog prevents Claude from responding even after the user has returned. | Replace with a non-blocking notification (e.g., toast via BurntToast PS module, or just log to a file). The macOS/Linux fallbacks are fine. |
| H5 | mb doctor | Gap | **High** | `mb doctor` does not check for `.claude/contracts/` directory or the contract file schema. A malformed `active-task.json` fails silently. | Add contract file checks to mb doctor (valid JSON, required fields, expiry parsing) |
| H6 | .pmb-delegation-depth | Doc Drift | **Medium** | `.pmb-delegation-depth` file is gitignored (correct) but not documented anywhere — not in HOOKS-GUIDE.md, not in docs/. Users have no way to know it exists or how to reset it. | Add a brief entry to HOOKS-GUIDE.md; add `mb doctor` check that warns if depth file is stale (mtime > 24h) |
| H7 | dangerous-commands.sh | Bug | **Low** | Bash version uses lowercase-only SQL pattern matching (`drop`, `delete`, `truncate`). PowerShell version uses `-match` (case-insensitive). `DROP TABLE` passes through the Bash hook. | Add `shopt -s nocasematch` or use `[Dd][Rr]...` patterns in the Bash version |
| H8 | pre-compact-check.ps1/.sh | Semantic Issue | **Medium** | Date matching uses substring search in `progress.md` content. The check finds the first occurrence of today's date string anywhere in the file — including old references, code examples, or commit hashes that happen to contain the date. | Match only frontmatter or section headers with explicit date format (e.g., `^## .* 2026-06-18`) |
| H9 | check-contract.ps1/.sh | Semantic Issue | **Low** | Contract `expires_at` field is read but expiry duration is not validated when the contract is written — any duration is accepted. An 800-hour contract provides no governance value. | Add an `mb doctor` check that warns if `expires_at` is more than 24 hours in the future |
| H10 | Stop hook | Wiring Error | **Low** | `powershell.exe` (PS5) is hardcoded in Stop hook command string. On systems where only `pwsh` (PS7) is installed, the WinForms call fails silently (covered by `2>/dev/null`). | Use `pwsh -Command` consistently |

**Clean (no issues):** update-reviewed.ps1/.sh (stdin reading correct), delegation-depth-check.ps1/.sh (logic correct for its threshold), PreCompact matcher (no matcher = fires on all compactions, correct).

---

## Lens 2 — mb Commands

| ID | Area | Type | Severity | Description | Recommendation |
|---|---|---|---|---|---|
| C1 | mb help / ValidateSet | Doc Drift | **Low** | `mb validate` and `mb audit` appear in ValidateSet as active commands but their implementations are deprecated aliases that redirect to `mb doctor`. Help text doesn't clarify this. | Mark them as `(deprecated — use mb doctor)` in help output; eventually remove from ValidateSet |
| C2 | mb doctor check count | Doc Drift | **Medium** | CLAUDE.md states `mb doctor` runs 14 checks. Actual count is 20+. The discrepancy means users (and Claude) don't know what to expect. | Update CLAUDE.md to say "20+ checks" or link to mb doctor output rather than hardcoding a count |
| C3 | mb update — PS vs Bash | Bug | **High** | `mb update` in mb.ps1 (line ~1752) prints a redirect message: "use mb clean". `mb update` in mb.sh (line ~1600) calls `invoke_upgrade`. The commands do fundamentally different things across platforms. | Align both to the same behavior — either both redirect or both call upgrade. Redirect is safer; upgrade should be invoked explicitly. |
| C4 | Guidance-only commands | Gap | **Low** | `mb archive`, `mb slim`, `mb budget` print guidance text only — they take no action. This is intentional but not disclosed. A user running `mb archive` expecting action gets a surprise. | Add `[advisory]` tag to help output for these commands |
| C5 | mb commit — subworktree false positive | Bug | **Medium** | Known bug: `mb commit` triggers subworktree detection incorrectly in some cases, causing false "subworktree detected" errors. Root cause: the check uses `git rev-parse --git-common-dir` and compares paths, which can fail when symlinks or UNC paths are involved on Windows. | Add a workaround note to mb commit output; investigate the exact comparison logic for UNC/symlink edge cases |
| C6 | mb help output | Doc Drift | **Low** | Help text doesn't mention deprecated commands or guidance-only commands. New users may try them and be confused. | Minor help text improvements (see C1, C4) |
| C7 | mb budget deprecation | Doc Drift | **Low** | `mb budget` deprecation message references the old budget system; the new model selection guidance is in CLAUDE.md. | Update mb budget to point to the CLAUDE.md section |
| C8 | ValidateSet bloat | Semantic Issue | **Low** | ValidateSet includes 14 entries including deprecated aliases and guidance-only commands. Reduces discoverability of real commands. | Low priority; acceptable as-is |

---

## Lens 3 — Slash Commands

| ID | Area | Type | Severity | Description | Recommendation |
|---|---|---|---|---|---|
| S1 | feature-dev.md | Doc Drift | **High** | Phase 2 references `docs/specs/` as the spec location. Correct path is `docs/superpowers/specs/`. This causes feature-dev to place specs in the wrong directory. | Update path reference to `docs/superpowers/specs/` |
| S2 | feature-dev.md | Bug | **High** | Phase 5 invokes `code-simplifier` slash command. No such command exists in `.claude/commands/`. This step silently fails. | Either remove Phase 5 or replace with explicit simplification instructions inline |
| S3 | health-check.md | Bug | **High** | Step 5 instructs running `/security-review`. Slash commands cannot invoke other slash commands — the instruction is semantically broken and silently does nothing. | Replace with inline security review instructions referencing `standards/SECURITY-GUARDRAILS.md` |
| S4 | feature-dev.md | Bug | **Medium** | Phase 6 invokes `/security-review` from within a slash command (same issue as S3). | Replace with inline security check referencing SECURITY-GUARDRAILS.md |
| S5 | code-review.md | Wiring Error | **Medium** | Spawns Agent subagents (Step 4, Step 5) but `Agent` is not in `allowed-tools`. Claude Code behavior when an unlisted tool is used from a slash command is undefined — may silently fall through to asking for permission each time. | Add `Agent` to `allowed-tools` in code-review.md frontmatter |
| S6 | feature-dev.md | Wiring Error | **Medium** | Missing `allowed-tools` section entirely. The command reads files, runs git commands, and edits files — all tool uses are implicitly unrestricted. | Add explicit `allowed-tools` list matching actual tool usage |
| S7 | security-review.md | Gap | **Low** | Command doesn't reference `standards/SECURITY-RULES.md`. The live `.claude/agents/security-reviewer.md` does include this reference; the slash command version is less complete. | Add reference to SECURITY-RULES.md in security-review.md |
| S8 | health-check.md | Doc Drift | **Low** | Step headers use inconsistent capitalization (e.g., "Step 4" vs "step 5" in some versions). | Minor formatting fix |
| S9 | pmb-status.md | Semantic Issue | **Low** | Described as "run at session start" but nothing triggers it automatically. Users must manually invoke it. | Add a note that it is advisory/manual; or document in CLAUDE.md's session-start instructions |
| S10 | test-audit.md | Semantic Issue | **Low** | allowed-tools list may be broader than needed for a read-only audit command. Not a security issue in this context, but worth tightening. | Review allowed-tools against actual command steps |

---

## Lens 4 — Semantic Gaps & Overstepping

### Gaps

| ID | Area | Type | Severity | Description | Recommendation |
|---|---|---|---|---|---|
| G1 | Handoff creation | Gap | **Low** | No `mb handoff` command. Handoff creation is advisory-only. However, the real fragility is at detection, not creation: without a SessionStart hook, handoff.md can sit unprocessed indefinitely regardless of how well it was written. A creation script would not fix the detection gap. | Strengthen the CLAUDE.md session-start checklist ("check for handoff.md before anything else"). Adding a creation script is low value until detection is enforcement-grade. Deferred. |
| G2 | Handoff merge | Gap | **Low** | No `mb merge-handoff` command. Cleanup (step 3) is not the missing piece — detection (step 2) is. If Claude never reads handoff.md because there is no SessionStart hook, a merge script has nothing to operate on. | Same root cause as G1: detection gap, not cleanup gap. Defer until SessionStart hook is available. |
| G3 | Stale state cleanup | Gap | **Low** | No way to clear `.pmb-delegation-depth` or expired contracts without manual file deletion. | Add `mb clean --all` flag or `mb reset-state` command |
| G4 | Version transparency | Gap | **Low** | No `mb version` command. Users must read the VERSION file directly. | Add `mb version` that prints VERSION file content |
| G5 | Session-start read | Gap | **High** | Memory bank read at session start is advisory only (CLAUDE.md prose). No hook enforces it. Claude Code has no `SessionStart` hook event — this is a platform limitation, not a bug. | Document this as a known platform limitation in HOOKS-GUIDE.md; consider a `pmb-status` auto-invoke workaround |

### Overstepping

| ID | Area | Type | Severity | Description | Recommendation |
|---|---|---|---|---|---|
| O1 | delegation-depth-check | Overstepping | **High** | The script tracks cumulative Agent spawns per 2-hour window, incrementing on every PreToolUse:Agent call. Warning fires at `depth >= 1`, meaning the second agent spawned in any session always triggers it. PERFORMANCE-BUDGET.md's intent is to prevent recursive chains (Agent → Agent → Agent), but the implementation cannot distinguish a sequential parallel dispatch from true nesting — there is no PostToolUse:Agent event to decrement the counter. A brainstorming session with 6 Explore agents fires 5 warnings. | Raise `$budgetLimit` to 6 and update the comment/description to say "cumulative spawns per session" not "delegation depth". Do NOT attempt to track true nesting depth — no PostToolUse:Agent hook exists. |
| O2 | check-contract | Overstepping | **Low** | Fires on every Write/Edit including routine memory-bank maintenance when no active contract exists. Produces no output in that case (correct), but adds latency to every file write. | Acceptable as-is; contract check is fast. Document the "no contract = pass" behavior in HOOKS-GUIDE.md |
| O3 | pre-compact-check | Overstepping | **Medium** | Blocks compaction if `progress.md` has no entry dated today. On a fresh session with no prior work today, compaction is blocked even for small, safe sessions. | Add a bypass: if `activeContext.md` was touched today OR if a `handoff.md` exists, allow compaction regardless of progress.md |
| O4 | Naming confusion | Semantic Issue | **Low** | `mb validate`, `mb audit` still appear as callable commands but redirect to `mb doctor`. Confusing for new users. | See C1 |

### Redundancy

| ID | Area | Type | Severity | Description | Recommendation |
|---|---|---|---|---|---|
| R1 | mb validate vs mb doctor | Semantic Issue | **Low** | validate was the original name; doctor replaced it. Both resolve to the same implementation. Acceptable: deprecated alias, low friction. | Remove from ValidateSet in next major version; no action now |
| R2 | mb audit vs mb doctor | Semantic Issue | **Low** | Same as R1. | Same as R1 |
| R3 | mb status vs mb doctor | Semantic Issue | **Low** | Intentional distinction: status = "can I work?"; doctor = "is it correct?". Distinction is correct and documented. | No action |
| R4 | /health-check vs mb doctor | Semantic Issue | **Medium** | Both check system health but for different audiences: /health-check is Claude's workflow, mb doctor is the user's CLI check. Overlap is confusing. | Clarify in COMMANDS-REFERENCE.md: mb doctor = structural integrity, /health-check = full governance + workflow validation |

---

## Lens 5 — Session Start & Handoff Flow

| ID | Area | Type | Severity | Description | Recommendation |
|---|---|---|---|---|---|
| F1 | HOOKS-GUIDE.md | Doc Drift | **High** | HOOKS-GUIDE.md states that pre-compact-check "always exits 0 — compaction is never blocked." The script exits 2 when validation fails, which does block compaction. Direct contradiction. | Update HOOKS-GUIDE.md to accurately describe the blocking behavior and what triggers it |
| F2 | Session start | Gap | **High** | No `SessionStart` hook event exists in Claude Code's hook system (platform limitation). Memory bank read at session start is advisory only. Claude may start working without reading context. | Document as platform limitation; add instructions to CLAUDE.md to treat the first user message as a session-start trigger |
| F3 | PostCompact | Gap | **High** | No `PostCompact` hook event in Claude Code. After compaction, Claude is expected to re-read memory bank per CLAUDE.md, but there's no enforcement. If Claude drifts, there's no recovery mechanism. | Document as platform limitation; ensure CLAUDE.md's compaction recovery section is prominent and clear |
| F4 | Pre-compact bypass | Doc Drift | **Medium** | CLAUDE.md mentions `handoff.md` bypasses the pre-compact gate, but this is not documented in HOOKS-GUIDE.md or in the pre-compact-check script comments. | Add inline comment to pre-compact-check scripts; add entry to HOOKS-GUIDE.md |
| F5 | Context threshold | Semantic Issue | **Medium** | CLAUDE.md says handoff fires at "context >= 40%". This threshold is advisory — no hook measures context percentage. The actual trigger is the user typing "Handoff" or Claude estimating context approaching the limit. | Update CLAUDE.md to clarify: "trigger handoff when context is approaching limits OR when explicitly requested" |
| F6 | Date format fragility | Bug | **Medium** | pre-compact-check finds "today's entry" by searching for today's date string in progress.md. Format assumed is ISO 8601 (`YYYY-MM-DD`). If a progress entry uses a different format, the gate always blocks. | Document required date format in progress.md frontmatter; add format check to mb doctor |
| F7 | Live handoff.md | Bug | **Critical** | A `handoff.md` from 2026-06-18 is present on disk and was not deleted/merged in the prior session. Per protocol, it should have been deleted after being read. | Delete handoff.md (contents already read — no new information) |
| F8 | pmb-status trigger | Gap | **Medium** | `/pmb-status` is documented as a session-start tool but requires manual invocation. Nothing in CLAUDE.md's session-start checklist explicitly prompts Claude to run it. | Add `/pmb-status` to CLAUDE.md's session-start sequence |
| F9 | mb clean references | Semantic Issue | **Clean** | All verified `mb clean` references in CLAUDE.md and COMMANDS-REFERENCE.md are correct. No stale `mb compact` references found. | No action |
| F10 | Memory re-read enforcement | Gap | **Medium** | CLAUDE.md's "read ALL files in memory-bank/ at the start of every conversation" is the right instruction but has no structural enforcement. Relies on Claude's compliance. | Consider adding a session-start checklist item that Claude must acknowledge; or a `pmb-status` auto-check |
| F11 | activeContext.md staleness | Semantic Issue | **Low** | `last-reviewed` is 2026-06-12 (6 days ago). Staleness threshold is 14 days. Within threshold — no action required. | No action |
| F12 | Midnight edge case | Bug | **Low** | If auto-compaction fires at 23:59 and the progress.md check runs at 00:01, the gate blocks even if the user worked all day. Unlikely but possible. | Add a 1-hour grace window: if `progress.md` has an entry dated yesterday and mtime is within 2 hours, pass |

---

## Lens 6 — Template Parity

| ID | Area | Type | Severity | Description | Recommendation |
|---|---|---|---|---|---|
| T1 | MEMORY-BANK.md template | Doc Drift | **Medium** | `templates/standards/MEMORY-BANK.md` references `mb compact` (deprecated). Live version was fixed. | Update template to match live: replace `mb compact` with `mb clean` |
| T2 | pre-compact-check templates | Gap | **Medium** | `templates/scripts/pre-compact-check.ps1` and `.sh` exist in templates but are NOT listed in `mb.ps1`'s `Invoke-Init` or `Invoke-Upgrade` distribution functions. These files are never installed by `mb init` or `mb upgrade` — effectively orphaned. | Add pre-compact-check.ps1/.sh to both Invoke-Init and Invoke-Upgrade distribution lists |
| T3 | security-reviewer.md agent | Doc Drift | **High** | `templates/.claude/agents/security-reviewer.md` is missing ~15 lines present in the live version: structured return format specification, `SECURITY-RULES.md` reference, and trust level reporting. New projects get an inferior agent. | Sync template to match live agent file |
| T4 | SECURITY-GUARDRAILS.md | Doc Drift | **High** | Template version is ~218 bytes shorter than live. Specific content differences include missing CONFIRM-tier entries added after last upgrade. New projects get incomplete guardrails. | Sync template to live; run `mb upgrade` audit to catch this class of drift automatically |
| T5 | WORKFLOW.md | Doc Drift | **High** | Template version is ~927 bytes shorter than live — the largest template drift found. New projects get a significantly outdated workflow spec. | Sync template to live immediately; this is the highest-priority template fix |
| T6 | CLAUDE.md template | Doc Drift | **Medium** | Template CLAUDE.md has minor drift from live — confirmed by mb upgrade behavior, which proposes changes on every fresh init. Lower-impact than T3–T5 because CLAUDE.md is advisory, not enforcement. | Sync template after T3–T5 are done; run `diff templates/CLAUDE.md CLAUDE.md` to confirm exact delta |

---

## Summary by Severity

| Severity | Count | IDs |
|---|---|---|
| **Critical** | 2 | H1, F7 |
| **High** | 14 | H2, H5, C3, G5, O1, S1, S2, S3, F1, F2, F3, T3, T4, T5 |
| **Medium** | 19 | H3, H4, H6, H8, C2, C5, S4, S5, S6, O3, R4, F4, F5, F6, F8, F10, T1, T2, T6 |
| **Low** | 23 | H7, H9, H10, C1, C4, C6, C7, C8, S7, S8, S9, S10, G1, G2, G3, G4, O2, O4, R1, R2, R3, F11, F12 |

**Total findings:** 58

---

## Platform Limitations (not bugs)

These are real gaps but cannot be fixed in this project — they require Claude Code platform changes:

- **No SessionStart hook** — memory bank read at session start cannot be enforced by a hook. This also means handoff.md detection (step 2 of the handoff protocol) has no structural enforcement: handoff.md can sit on disk unprocessed across any number of sessions. G1/G2 are consequences of this limitation, not independent fixable gaps.
- **No PostCompact hook** — memory bank re-read after compaction cannot be enforced by a hook. F7's systemic dimension (advisory-only session boundaries failing in practice) is a direct result: without PostCompact, every compaction is a potential context loss event.
- Context percentage is not exposed to hooks — handoff threshold cannot be enforced programmatically

---

## Appendix — Files Audited

**Hook scripts:** check-contract.ps1/.sh, dangerous-commands.ps1/.sh, update-reviewed.ps1/.sh, delegation-depth-check.ps1/.sh, pre-compact-check.ps1/.sh

**mb CLI:** scripts/mb.ps1 (1756 lines), scripts/mb.sh (1589 lines)

**Slash commands:** code-review.md, feature-dev.md, health-check.md, pmb-status.md, security-review.md, test-audit.md

**Config:** .claude/settings.json, .claude/agents/security-reviewer.md

**Templates:** templates/scripts/*.ps1/.sh, templates/.claude/agents/*.md, templates/standards/*.md

**Docs:** CLAUDE.md, docs/HOOKS-GUIDE.md, docs/COMMANDS-REFERENCE.md, memory-bank/activeContext.md
