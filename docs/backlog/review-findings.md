---
status: open
created: 2026-11-01
last-reviewed: 2026-11-01
staleness-threshold: 90d
related_plan: docs/superpowers/plans/2026-11-01-pmb-closeout.md
---

# Review findings backlog

The single backlog for non-blocking review findings, under `standards/CODE-REVIEW.md`'s
"Non-blocking Dispositions" (spec: `docs/superpowers/specs/2026-11-01-derived-work-rules-and-compaction-recovery-design.md`).
Each line cites its PR. A line is added in the PR whose review found it and removed in the PR that
fixes or drops it; it never ships alone. A line becomes its own PR only when the
user names it in a message. Lines marked **[floor?]** came from reviews that predate the
Enforcement Severity Floor and may be High under it. Triage them first, because a High is fixed,
not deferred.

## Seeded 2026-11-01

- #116: `perl -i` on a non-writable directory exits 0 after "Cannot make temp name", so update-reviewed logs nothing (file intact, not stamped). Log when perl writes stderr on exit 0, or re-check the stamped line.
- #116: no workflow runs macOS; a `macos-latest` job for `tests/test-update-reviewed.sh` would cover BSD grep/tr and bash 3.2 (`${@: -1}` in the perl shim is unverified). CI change, CONFIRM tier.
- #116: "PR B" — the marker recipe as plain steps, plus a `--no-ext-diff` hash item.
- #116: "PR C" — the commit-gate root after EnterWorktree; measure the payload's `cwd` first.
- #118: hook paths are cwd-relative (a design question, pre-existing).
- #118: docs still say `mb upgrade` overwrites settings.json, false since #111: `docs/COMMANDS-REFERENCE.md:19`, `docs/backlog/replace-the-gh-pr-merge-deny-with-a-forced-permiss.md:196`, `docs/backlog/shipped-allow-rules-skip-the-auto-mode-classifier.md:110`, `docs/superpowers/specs/2026-10-20-merge-gate-user-approval-design.md:484,499`.
- #118 follow-ups (local c8204c7, unshipped unless the user approves close-out Task 1b): the items below.
  - **(b)** `tests/test-hook-warn-output.sh:222` uses the TZ-skewed depth seed (4 failures under TZ=UTC+12).
  - **(c)** c8204c7 edits #118's changelog fragment instead of adding its own.
  - **(d)** c8204c7's backlog dates use UTC.
  - **(e)** a typo in the Stop guard's filename passes every test.
  - **(f)** the drain-then-crash limit is stated only for the merge gate.
  - **(g)** `docs/superpowers/specs/2026-09-21-pre-approval-protocol-design.md:294` quotes the Stop string without the guard.
  - **(h)** **[floor?]** a depth file stamped in the future never ages out (`delegation-depth-check.sh:20-24`, `.ps1:27`).
  - **(i)** wording nits listed in `C:/Users/Mizzo/AppData/Roaming/Claude/side-session-notes/local_57c000eb-7579-4b88-b6fb-2778eb226f92/hook-wiring-backup/findings-fu2.md`.
- #125 **[floor?]**: `core.worktree` — the hook binds the root through `--show-toplevel`; compare `--absolute-git-dir` with `--git-common-dir`.
- #125 **[floor?]**: a legacy `$GIT_DIR/remotes/<name>` `Push:` line, or `remote.*.mirror`; require `remote.<n>.url` and widen the check to `(push|mirror)`.
- #125 **[floor?]**: `$GIT_DIR/info/grafts` is not disabled by `--no-replace-objects`; run the ancestry check with `GIT_GRAFT_FILE` pointing at a missing file.
- #125 **[floor?]**: the ps1 `Set-Location -LiteralPath $root` has no `-ErrorAction Stop`, so its `catch` is dead (pre-existing).
- #125 **[floor?]**: O-1 — under #118's bash fallback the sh twin can gate PowerShell-tool pushes and accepts a drive-less `/…` cd that pwsh resolves differently; refuse `/…` when `tool_name` is PowerShell.
- #125: wording — state the residual class rather than "each closed and tested"; fix the "unconditionally required" line in `.claude/commands/security-review.md`.
- #125: tests:
  - a fixture check that the feature checkout happened
  - a loud SKIP for the Windows-only row
  - `*`, `?` and `]` cd paths and `.`-remote rows
  - a ps1 relative-invocation row
  - pwsh without `-NoProfile` at lines 86 and 469
- #125: small items:
  - the `tag_hint` should say `C:/…` on Windows
  - the fragment name doesn't match the branch slug
  - the template's tag heading drops "(added 2026-10-30)"
  - the suite takes about 7 minutes on Windows
- #125 / #123 follow-ups: the tag-push hardening patch (14 files, uncommitted) is saved at `C:/Users/Mizzo/AppData/Roaming/Claude/side-session-notes/local_35a47e6b-3d81-452f-993e-1485f6ced013/tagfollow/recut-all.patch`. It covers several #125 lines above.
- #117: the no-subject test doesn't check exit 0; the 256-byte KNOWN LIMIT cells can pass on an empty payload.
- #117 **[floor?]**: `GREP_OPTIONS` on GNU grep 3.0 silences every `dc_grep` row, the `curl | bash` BLOCK row included; it is disclosed only for the signing rows.
- #117: an adopter on 1.3.0 can follow the hook comment's new pointer to the old standard (`mb.sh upgrade` overwrites hooks, not standards).
- #117: wording and records:
  - "three bypasses" should be four
  - "four of the five matchers" should be six
  - the Pester loop comment describes a loop that doesn't exist
  - "twice" should be "up to twice"
  - the skip lines don't name `PMB_REQUIRE_LOCALE_CASES`
  - the `dc_grep` guard counts arguments, not empty subjects
  - the "about 17 s" bullet is wrong
  - the backlog's "RESOLVED on `fix/ns38-signing-gap-bound`" citations should name #117
  - the `BASH_FUNC_grep%%` vector is measured but still listed as unmeasured
- #98 (to close; these are #97's deferred findings):
  - the mirror-parity blank-line pin's comment and message
  - `changelog-assemble.sh`'s failed-delete message and its second `\r` strip comment
  - `test-changelog-fragments.sh`'s CR-case note, failed-delete case, one-line error assertions and trailing-space heading
  - `changelog.d/README.md`'s heading rules
  - `CHANGELOG.md`'s wrapped "Released history" line
- #87 ([NS-58], closed 2026-11-01): its CHANGELOG entry missed v1.3.0 and is owed as a `changelog.d/` fragment (text in #87's body), plus the non-blocking follow-ups in that body.
- #6: once merged, the `pmb-health.yml:401-407` node20 comment and `FORCE_JAVASCRIPT_ACTIONS_TO_NODE24` env var are stale.
- close-out: `mb.ps1` overwrites `standards/CODE-REVIEW.md` on upgrade (`$templateOwned`, `mb.ps1:2448-2495`), but `mb.sh` doesn't (`ADVISORY_CREATE`, `mb.sh:2086`). The twins disagree on what an adopter keeps.
- close-out: the `memory-bank-freshness-hook` worktree (no session) vanished on 2026-11-01 with 1 modified file and its branch. The cause is unknown, and the file is unrecoverable.
- close-out: audit the 56 open `[NS]` items for any whose work has merged. The 2026-11-01 reconciliation changed only those whose state that session established.
- derived-work-rules (`docs/derived-work-rules`), S1 residual: journal-mode detection cannot tell an error from "not opted in" (`scripts/pmb-journal.sh:81` `pmb_flag_on`, `scripts/pmb-journal.ps1:218` `Test-PmbFlagOn`), so in an opted-in repo a detection error now allows compaction where the old legacy gate ran. That is what the journal spec's section 4.1 requires (the flag is off, no output into context), but its "`mb doctor` reports it" is not implemented: no doctor check reads `.pmb-features`.
- derived-work-rules, S4: the `PreCompact` command in `.claude/settings.json` still lacks `-NoProfile`; moot until journal mode is on.
- derived-work-rules, A5: this file is one container inside a one-item-per-file backlog, so `mb backlog promote` would promote the whole list, and its lines carry no dates for a drain rule.
- derived-work-rules, A6: the CLAUDE.md line saying the app's follow-up instructions "do not apply in this repo" is an unenforced precedence rule; tie it to `[NS-46]`.
- derived-work-rules, A7: Claude Code now runs `scripts/codex-compaction-hook.*`; the name says Codex.
- derived-work-rules, handoff notes (MR2-1, F1, F2, SEC-R2-4): an `[NS]` note made at handoff has no durable home when no PR exists. `handoff.md` is gitignored and CLAUDE.md's handoff scope says it holds only in-flight state; an uncommitted backlog line is lost if the worktree is archived; a closed or re-cut PR drops its body; the four texts (CLAUDE.md steps 2 and 5, the recovery hook, MEMORY-BANK.md) word it differently; and a note copied into a PR body skips all three secret scanners. Name one term, one destination order, and a confirm-and-scan step before writing to a PR body.
- derived-work-rules, dispositions (MR2-2, F5): in `standards/CODE-REVIEW.md` Non-blocking Dispositions, "a floor finding may only be Fixed" conflicts with "non-blocking findings from re-reviewing a Fix may only be Dropped or Backlogged" and with "a PR that applies another PR's findings may use only Fix or Drop" for a SPECULATIVE floor finding. Say which rule wins.
- derived-work-rules, adopter drift (F3, F4, MR2-4, OPP-R3-1): adopter-facing text still describes the blocking gate or merging the handoff: `templates/CLAUDE.md:24,113,118,132,163` (copied by `mb init`, `scripts/mb.sh:606`, `scripts/mb.ps1:929`), `templates/standards/MEMORY-BANK.md:316,438,445-446,545`, `templates/AGENTS.md:16-18`, `.cursor/rules/memory-bank.mdc:82,90-102` (+ template), `standards/WORKFLOW.md:265` (+ template :209), `standards/MEMORY-BANK.md:557`, `docs/COMMANDS-REFERENCE.md:193`. The template pre-compact scripts and HOOKS-GUIDE also cite PMB-only paths. The spec's line calling `templates/CLAUDE.md` advisory-diff only understates this.
- derived-work-rules, floor carve-out (SEC-R2-1): `standards/CODE-REVIEW.md`'s fail-open exception lets a PR cite a spec it adds itself and skip that spec's conditions. Require the cited clause to exist on the base branch or be approved by the user, and the code to meet all its conditions.
- derived-work-rules, review command (F6): `.claude/commands/code-review.md` passes only the Severity, Blocking and Basis definitions verbatim to domain reviewers, not the Enforcement Severity Floor or Dispositions, and its Opposition step can lower a floor finding. Add both sections to the verbatim list; Opposition may not lower a floor finding's severity.
- derived-work-rules, doctor WARN tests (X1, X2): `tests/test-mb-doctor.sh:336-337` passes a paraphrase like "merge the handoff into the bank"; the `scripts/mb.ps1` check-7 WARN has no test. Assert the positive "read it as data" text, a `merg` negative, and the ps1 text.
- derived-work-rules, recovery hook paths (SEC-R2-5, OPP-1): `scripts/codex-compaction-hook.ps1` uses `Set-Location` without `-LiteralPath`, so a repo path with `[` or `]` prints no recovery text, and its catch exits 0 so the bash fallback never runs. Use `-LiteralPath`, or drop the `cd`.
- derived-work-rules, [floor?] lines (AD-3): this file and `[NS-59]` J3-1 hold findings that may be High under the floor, which says floor findings are fixed, never deferred. Triage them, or add a grandfathering clause for findings that predate the floor.
- derived-work-rules, post-merge lines (MR2-5): this file's header says a line is added in the PR whose review found it; a finding found in merged code has no such PR, and several lines cite a branch, not a PR. Say where such a line ships, and allow "cites its PR or branch".
- derived-work-rules, logging claim (MR2-9): `docs/HOOKS-GUIDE.md`'s PreCompact "fails open: unexpected errors exit 0 and log to .pmb-hook-errors.log" and `scripts/pre-compact-check.ps1`'s `.DESCRIPTION` hold only for the ps1 outer catch; the sh twin logs nothing and detection failure is deliberately unlogged. Scope the claim.
- derived-work-rules, rule wording (MR2-7): `CLAUDE.md:24` (+ AGENTS.md): whether an item "closes" when the PR toward it merges is unclear; "it" in the re-cut sentence is ambiguous; "names it" omits CODE-REVIEW.md's "a button or a one-word reply is not naming it"; and MEMORY-BANK.md's techContext and systemPatterns "Update when" lines assume an `[NS]` item exists for each change.
