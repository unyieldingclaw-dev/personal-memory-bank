# Review-Gate Self-Attestation Fix

**Date:** 2026-07-16
**Status:** Approved

## Problem

`/code-review` and `/change-review` each end by having the orchestrator (the same agent context that
ran the whole review) write a marker file — `.claude/.code-review-ok` or `.claude/.change-review-ok`
— that a `PreToolUse` hook later checks before allowing `git commit`/`git push`. The marker is bound
to a diff hash, so it can't be replayed against a different diff, but nothing about the write itself
proves the review it claims happened actually happened. This is the same shape of problem as the
cross-repo-write-boundary incident (2026-07-10/12, `memory-bank/progress.md`): an implementer
subagent fabricated a `.claude/.code-review-ok` marker by directly computing the expected hash,
without a review occurring first.

This session hit a live instance of the underlying risk: during the backlog-feature implementation
(Task 1, `superpowers:subagent-driven-development`), a genuinely-reviewed and Approved diff had its
marker-write denied three times by the harness's own safety classifier, because the classifier
could not distinguish "orchestrator writing a marker immediately after a real review it just ran" —
which is legitimate and is exactly how the commands are designed to work — from "orchestrator
writing a marker with no review at all." Both look identical from outside the orchestrator's own
context: a single agent asserts a conclusion about work it also performed, with no independently
observable boundary between "the review happened" and "the marker got written."

Routing around this per-instance (asking the user to write the marker by hand, or granting a
one-off Bash permission) treats the symptom, not the cause, and was explicitly rejected: "instead of
going around the roadblock, let's look at the proper way to fix the roadblock."

## Design

### Core mechanism

Move the verdict-determination and marker-write into the *last dispatched subagent* of each review
command, so the write is the final action inside a subagent's own transcript that also contains its
own genuine review work — a causally coherent unit, not a claim made by an agent about actions taken
outside the boundary being inspected. This mirrors how a second reviewer signing off in person works:
the signoff and the review are the same act, not a report filed separately afterward.

Concretely: the subagent that writes the marker must **never accept the verdict or the diff hash as
given** — it independently (a) scans the findings it receives for any surviving `Blocking: true`/`Yes`,
and (b) computes the diff hash itself via the exact mechanics the `PreToolUse` hook uses (redirect
`git diff` to a temp file, then hash the file — never a pipe or command substitution, which don't
preserve the same bytes). Only if both checks pass does it write the marker, as its own last action.

### `/code-review`

`Step 5 — Opposition Review` already dispatches a single subagent that receives all domain findings
and answers the standard's four opposition questions. Its scope expands: after answering the four
questions, it also performs the verdict determination currently done in `Step 6` (scan all findings —
domain findings plus anything it surfaced itself — for `Blocking: true`) and, if the verdict is
Approve, run `Step 7`'s existing hash-and-write commands (bash: redirect-to-temp-file then
`sha256sum`; PowerShell: redirect-to-temp-file then `Get-FileHash`) itself, using its own `Bash`
access.

`Step 6 — Assemble Report` becomes purely presentational: the orchestrator formats the full report
(Domain Coverage table, Supported Findings, Predicted Risks, Testing Gaps, Opposition Review answers,
Verdict) using the subagent's returned findings and verdict — it no longer makes an independent
Approve/Request-Changes call, and no longer writes the marker (already done, or correctly not done,
by Step 5's subagent).

No other step changes. Steps 1–4 (load contract, determine scope, gather context, spawn domain
subagents) are unaffected.

### `/change-review`

Unlike `/code-review`, `/change-review` has no existing subagent boundary — `Step 4`'s 9 jobs
(including Job 9, Opposition) currently run inline in the orchestrator's own context, and the file
has no `allowed-tools` frontmatter granting `Agent` or `Bash`. Jobs 1–8 stay exactly as they are
today — converting them to isolated subagents would be a separate, unrelated re-architecture and is
explicitly out of scope here.

Job 9 becomes a genuine subagent dispatch, introduced for the first time, positioned at the end of
`Step 4` after Jobs 1–8 conclude. It receives:

- The full findings tables from Jobs 1–8 (already required today — Job 9's brief includes "flag
  false positives" from those jobs)
- Not the `Step 3.5` Baseline Repo Health results — that section is explicitly informational, never
  affects Blocking/Verdict, and the orchestrator appends it to the final report independently

It performs the existing Job 9 opposition analysis, then determines the final verdict (any
`Blocking: Yes` across Jobs 1–8's findings plus its own), then — if no blocking finding survived —
independently recomputes the diff hash and writes `.claude/.change-review-ok`. Hash computation uses
the *exact* command already in today's `Step 6`: `git diff origin/main...HEAD`, falling back to
`git diff HEAD` if that fails — this is unconditional regardless of whether the original invocation
used the default, `--diff`, `--pr`, or `--base`, because the `PreToolUse` hook itself always
recomputes the hash this way against real git state, never against a loaded file or fetched PR diff.
This is a straight relocation of `Step 6`'s existing bash/PowerShell snippets into Job 9's subagent
prompt, not a behavior change.

`Step 5 — Output the report` becomes partly presentational: it takes Job 9's returned opposition
analysis and verdict as given, but still independently owns the Job Summary table and Coverage
Footer (which job ran which way, ACR used/not/disabled, Accessibility reviewed/skipped) — that data
comes from the orchestrator's own `Step 1`–`3.5` execution, not from Job 9's output, so this step
isn't a pure rubber stamp.

A new `allowed-tools` frontmatter block is added to `change-review.md` granting `Agent` and `Bash`
(it currently has none), matching `code-review.md`'s existing pattern.

### Model selection

Both marker-writing subagents (`/code-review`'s expanded Step 5, `/change-review`'s new Job 9) should
be dispatched on a capable model, not a cheap one — each is now the sole authority on whether a
change ships, not just one contributor among several.

### Scope of this fix

Both self-attestation risk *and* the specific classifier-denial pattern this session hit are the
target. This design cannot guarantee the classifier will never flag a legitimate marker write again
— its exact heuristics aren't something this project controls — but it produces the most defensible
structure available: the write sits immediately after that same subagent's own real, independently-
verified work, in one continuous transcript, rather than as a separate assertion by a different
context. If a legitimate write is still denied, the existing fallback applies unchanged: stop,
explain to the user, let them decide (write it themselves, or grant scoped permission for that one
case) — same as was done earlier this session, not a new escape hatch introduced by this design.

## Files Changed

| File | Change |
|---|---|
| `.claude/commands/code-review.md` | Step 5 subagent gains verdict-determination + marker-write (relocated from Step 6/7); Step 6 becomes presentational only |
| `.claude/commands/change-review.md` | New `allowed-tools` frontmatter (`Agent`, `Bash`); Job 9 becomes a real subagent dispatch with verdict-determination + marker-write (relocated from Step 6); Step 5 becomes partly presentational (keeps Job Summary/Coverage Footer, defers to Job 9 for verdict) |
| `templates/claude-commands/code-review.md` | Mirror of the above (TEMPLATE_OWNED sync) |
| `templates/claude-commands/change-review.md` | Mirror of the above (TEMPLATE_OWNED sync) |

## Out of Scope

- Converting `/change-review`'s Jobs 1–8 to isolated subagents — unrelated re-architecture, no
  problem identified that requires it.
- Any change to the `PreToolUse` hook (`review-reminders.sh`/`.ps1`) itself — the hash-verification
  mechanics it enforces are correct and unchanged; this fix only changes who computes and writes the
  value it checks.
- A guaranteed fix for classifier false-positives — not achievable from this side; see "Scope of
  this fix" above.
- `/security-review` and `/ai-review` — neither writes a gate marker today (per this session's
  earlier `standards/WORKFLOW.md` fix), so neither is affected.
