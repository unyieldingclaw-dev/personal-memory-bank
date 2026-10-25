# Cross-Tool Pre-Compaction Handoff Implementation Plan

> **SUPERSEDED 2026-09-17 — do not execute this plan.** Success Criteria #2/#3 below and Task 2's
> steps require Codex to run a turn-terminating `PreCompact` gate. That gate shipped, then was found
> to cause three reproduced silent turns in the desktop UI (`continue:false` ended the active turn
> without surfacing its `systemMessage`) and was deliberately removed in favor of a recovery-only
> `SessionStart(source=compact)` hook — see `memory-bank/activeContext.md`'s `[NS-53]` and
> `memory-bank/progress.md`'s 2026-09-16/17 entries for the incident and the fix. Running this plan
> today would reintroduce the removed defect. Left in place, unedited below, as the historical record
> of what was originally built and why — this banner is the only change.

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. This repository task is an explicit one-primary-agent exception: execute inline and do not dispatch subagents.

**Goal:** Make PMB's Claude, Cursor, and Codex handoff claims match what each platform can actually enforce, including deterministic Codex pre-compaction blocking and post-compaction recovery.

**Architecture:** Keep the existing Claude `PreCompact` checker as the single policy implementation. Add thin Codex adapters that translate its exit contract into Codex's documented JSON contract and emit compact recovery context after compaction. Keep Cursor's 40% protocol explicitly advisory because its native `preCompact` event is observational. Ship the Codex files through both `mb init` and `mb upgrade` without overwriting project-customized `AGENTS.md`.

**Tech Stack:** Bash, PowerShell 7, JSON hook configuration, existing shell test harness.

---

## Success criteria

1. Claude Code continues to run the existing executable `PreCompact` gate unchanged.
2. Trusted project-local Codex hooks run on `PreCompact` (`manual|auto`) and `SessionStart` (`compact`).
3. A Codex pre-compaction adapter returns `continue: false` exactly when the existing checker returns its policy-block exit code; unexpected adapter/checker failures remain fail-open.
4. Codex recovery context explicitly requires all five memory-bank files to be reread, any `handoff.md` to be reconciled second, conflicts to be surfaced, and work to resume only from verified state.
5. Cursor text says the 40% handoff is proactive/advisory and does not claim a blocking native event.
6. `mb init` and `mb upgrade` deliver `AGENTS.md`, `.codex/hooks.json`, and the Codex adapters with the intended ownership semantics.
7. Live/template pairs remain byte-identical where they are template-owned.
8. Focused suites pass; the local full suite is not rerun because PR CI is the final full-suite evidence.

## Task 1: Pin the missing behavior with failing focused tests

**Files:**
- Create: `tests/test-codex-compaction-hooks.sh`
- Modify: `tests/test-mb-init.sh`
- Modify: `tests/test-mb-upgrade.sh`
- Modify: `tests/test-mirror-parity.sh`
- Modify: `tests/run.sh`

**Steps:**

1. Add a focused Codex suite that asserts:
   - `.codex/hooks.json` is valid JSON and mirrors `templates/.codex/hooks.json`.
   - both documented events and matchers exist.
   - Unix and Windows commands point at the paired adapters via the Git root.
   - the adapter allows a fresh bank, blocks a thin bank with valid Codex JSON, fails open on unexpected checker failure, and emits required recovery instructions.
   - both adapter pairs are byte-identical to their templates.
2. Extend init tests to require root `AGENTS.md`, `.codex/hooks.json`, and both adapters.
3. Extend upgrade tests to prove `.codex/hooks.json` and adapters are restored as template-owned while a customized existing `AGENTS.md` is preserved and diff-reported.
4. Extend mirror verification to cover the shared recovery contract in the PMB-specific root
   `AGENTS.md` and generic template, plus byte parity for the template-owned Codex config and adapters.
5. Register the new suite in `tests/run.sh`.
6. Run only the touched focused suites and confirm they fail for the intended missing artifacts.

## Task 2: Add portable Codex hook wiring and adapters

**Files:**
- Create: `.codex/hooks.json`
- Create: `templates/.codex/hooks.json`
- Create: `scripts/codex-compaction-hook.sh`
- Create: `scripts/codex-compaction-hook.ps1`
- Create: `templates/scripts/codex-compaction-hook.sh`
- Create: `templates/scripts/codex-compaction-hook.ps1`

**Steps:**

1. Configure synchronous `PreCompact` for `manual|auto` and `SessionStart` for `compact`.
2. Use `command` plus `commandWindows`, resolving scripts from `git rev-parse --show-toplevel` so sessions started in subdirectories remain correct.
3. In `pre` mode, invoke the existing platform checker in a child process:
   - exit 0 → no output and allow;
   - exit 2 → valid Codex JSON with `continue: false`, `stopReason`, and `systemMessage`;
   - any other result or missing prerequisite → exit 0, fail open.
4. In `recover` mode, emit concise plain text suitable for `SessionStart.additionalContext` that names the five-file reread, handoff reconciliation order, conflict handling, and verified-state resume rule.
5. Keep live/template files byte-identical.
6. Run `tests/test-codex-compaction-hooks.sh` until green.

## Task 3: Deliver the Codex surfaces through PMB lifecycle commands

**Files:**
- Modify: `scripts/mb.sh`
- Modify: `scripts/mb.ps1`

**Steps:**

1. `mb init`: create `AGENTS.md` if absent; create `.codex/hooks.json`; copy both adapters.
2. `mb upgrade`:
   - make `.codex/hooks.json` and both adapters `TEMPLATE_OWNED`;
   - make `AGENTS.md` `ADVISORY_CREATE`, preserving project customizations and showing a diff.
3. Keep Bash and PowerShell ownership lists semantically aligned.
4. Run `tests/test-mb-init.sh` and `tests/test-mb-upgrade.sh` until green.

## Task 4: Correct the project-local rules and platform boundary

**Files:**
- Create: `AGENTS.md`
- Modify: `templates/AGENTS.md`
- Modify: `.cursor/rules/memory-bank.mdc`
- Modify: `templates/cursor/rules/memory-bank.mdc`

**Steps:**

1. Make the PMB-specific root `AGENTS.md` and portable template state the same recovery ordering
   without requiring the project-specific and generic files to be byte-identical:
   - memory bank first and authoritative;
   - `handoff.md` second and ephemeral;
   - surface conflicts;
   - delete a spent handoff only after reconciliation;
   - resume from verified git/worktree/test state.
2. State that Codex's project hooks provide the executable pre/post-compaction path only after the user trusts the exact hook definition.
3. Keep the 40% proactive handoff instruction as a portable fallback, not a claim that every platform exposes a native blocking event.
4. Update both Cursor rule copies byte-identically to label the workflow advisory/user-triggered and its native `preCompact` event non-blocking.
5. Run the Codex, mirror-parity, and threshold-parity focused suites.

## Task 5: Correct the directly affected documentation

**Files:**
- Modify: `docs/HOOKS-GUIDE.md`
- Modify: `templates/docs/HOOKS-GUIDE.md`
- Modify: `docs/SETUP-GUIDE.md`
- Modify: `docs/GLOBAL-RULES-SETUP.md`
- Modify: `docs/CLAUDE-CODE-PLUGINS.md`
- Modify: `docs/CURSOR-VS-CLAUDE.md`
- Modify: `docs/QUICK-REFERENCE.md`

**Steps:**

1. Document the platform matrix:
   - Claude Code: executable, blocking `PreCompact` gate.
   - Codex: executable `PreCompact` plus immediate `SessionStart(source=compact)` recovery, subject to project trust and feature/policy settings.
   - Cursor: proactive/advisory 40% workflow; native `preCompact` is observational and cannot block or modify compaction.
2. Correct Codex global `AGENTS.md` guidance from `~/.claude/AGENTS.md` to `~/.codex/AGENTS.md`; do not claim one global path serves every tool.
3. Explain `/hooks` trust review and that changed hook hashes require re-review.
4. Mirror the shared hook descriptions into `templates/docs/HOOKS-GUIDE.md` while preserving the
   live guide's intentional PMB-specific history sections.
5. Run targeted grep checks for the retired wrong path and false cross-platform claims.

## Task 6: Focused verification and PR handoff

**Files:**
- Update: `.claude/contracts/active-task.json` (ignored operational state)

**Steps:**

1. Run only:
   - `bash tests/test-codex-compaction-hooks.sh`
   - `bash tests/test-mb-init.sh`
   - `bash tests/test-mb-upgrade.sh`
   - `bash tests/test-mirror-parity.sh`
   - `bash tests/test-threshold-parity.sh`
2. Run PowerShell adapter cases directly when `pwsh` is available.
3. Run the installed Codex `/hooks` trust review and `/compact` smoke test if the current client exposes them; otherwise report that runtime verification as unavailable rather than implying it passed.
4. Inspect the final diff and working tree; do not rerun the full local suite.
5. Mark the contract complete, update the main-worktree execution queue, commit, push, open a separate PR, and use PR CI as the full-suite evidence.
