# Archived: `progress.md` 2026-09-16 → 2026-09-17 — two sections, moved verbatim 2026-09-19

**Relocated from `memory-bank/progress.md` on 2026-09-19**, unchanged. **Verbatim, not summarised** —
the same precedent as every relocation above it in `progress.md`.

**Why:** logging today's review-gate marker-persistence finding broke the aggregate startup-context
ratchet (`CLAUDE.md` + all `memory-bank/*.md`) against `origin/main`'s baseline — a required,
admin-enforced `File Size` CI check that may shrink, never grow. **Delta, not a level: 2,449 bytes
moved out of `progress.md`** (this file's own verbatim body). Both sections' narratives concluded
before the move — PR #28 (2026-09-18) shipped the policy correction both were tracking toward.

**Citation survival was grep-verified before the move**: `grep -n "2026-09-16" memory-bank/activeContext.md`
found one reference (`activeContext.md`'s PR #28/#29 entry, citing "progress.md's 2026-09-16→18
entries") — updated in the same commit to point at this file for the 09-16→17 portion, with the live
09-18 entry cited separately.

---

## 2026-09-17 — Recovery-only Codex review

- Full independent diff review covered security, performance/reliability, style, test coverage, and an adversarial audit. Security, performance, and style found no actionable issues; `git diff --check` and the focused suites remained clean.
- The adversarial audit found two MEDIUM issues: invalid JSON in both hook-config mirrors can make the structural test skip its assertions, and the now-historical implementation plan still instructs future agents to restore the removed blocking `PreCompact` gate. The user requested a handoff before authorizing either fix.

## 2026-09-16 — Codex PreCompact reproduction and pending UX review

- PR #27 is merged on `main` at `5c386808`. Its project-local Codex hooks were trusted and enabled by the user; the user later disabled `PreCompact` only to isolate an observed failure, leaving `SessionStart` enabled.
- Three reproductions showed a brief “Thinking” state followed by no assistant response with `PreCompact` enabled. The live Windows adapter emitted `{"continue":false,"stopReason":"Compaction paused — PMB state needs attention."}` and exited 0; its delegated gate exited 2 because `progress.md` had no entry dated 2026-09-16. Per official Codex hooks documentation, `continue:false` on `PreCompact` stops before compaction. The observed desktop UI did not surface the accompanying `systemMessage`, making this a silent turn-loss UX failure rather than a hook hang.
- Active user-approved wording diff remains uncommitted: 12 files, 13 insertions/10 deletions. Focused verification passed: `test-pre-compact-check.sh` 23/0, `test-codex-compaction-hooks.sh` 26/0, `test-mirror-parity.sh` 148/0. User requested a deeper official-docs review; policy redesign is pending and must be approved before implementation.
- Official-documentation review confirmed that no alternate Codex lifecycle hook can both block automatic compaction and guarantee an actionable continuation. The user approved recovery-only Codex support: `.codex/hooks.json` now retains only `SessionStart(source=compact)`, and the paired adapters emit recovery context only. Claude Code retains the existing executable gate; the checker remains available as an explicit Codex diagnostic.
- The active contract was superseded for the policy correction. Focused verification after the change: pre-compact 23/0, Codex recovery 17/0, mirror parity 146/0; `git diff --check` is clean.
