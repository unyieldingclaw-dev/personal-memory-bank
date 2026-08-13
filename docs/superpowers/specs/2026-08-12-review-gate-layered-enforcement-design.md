# Review-Gate Layered Enforcement

**Date:** 2026-08-12
**Status:** Approved

## Problem

The review-gate marker system (`review-reminders.sh`/`.ps1`, `.claude/.code-review-ok` /
`.change-review-ok`) is the only mechanism in this repo that checks whether `/code-review` or
`/change-review` actually ran before a commit or push lands. It is a `PreToolUse` hook — by
construction, it only ever sees Bash tool calls the agent itself makes. A command typed directly into
the user's own terminal is structurally invisible to it.

Handing the user exact `git commit`/`git push` commands to run themselves is this repo's own
documented, routine workaround for the self-attestation classifier repeatedly blocking the agent's own
marker-writes (see `memory-bank/progress.md`, essentially every session since 2026-07-14). Every time
that workaround is used, the marker gate's enforcement is bypassed entirely — not because review didn't
happen, but because the layer that checks it never fires for a user-run command. Since this has become
the default path rather than a rare escape valve, the gate provides no actual backstop for most real
commits landing in this repo.

`dangerous-commands.sh`'s BLOCK/CONFIRM tiers (force-push, `rm -rf`, `DROP TABLE`, `--no-verify`, etc.)
are the same hook type and have the identical blind spot — arguably more concerning, since they guard
one-shot irreversible actions, not review compliance.

Investigation (this design's own process) found no other layer fills the gap:

- `.githooks/pre-commit`/`pre-push` (installed via `core.hooksPath`, confirmed active in this repo)
  fire regardless of invoker — but their actual content checks unrelated things (`handoff.md` staging,
  merge conflicts, secret patterns, large files, `mb validate`). Zero reference to the review marker
  anywhere in `.githooks/`.
- `.github/workflows/` has one workflow (`pmb-health.yml`); grepping it and all of `.github/` for any
  review-marker/review-log reference returns nothing, despite this repo already having
  `enforce_admins: true` + required-PR + required-status-checks branch protection on `main` (rolled out
  2026-07-08) — the one enforcement tier that cannot be bypassed by anyone, including the repo owner.
  It currently doesn't check review coverage at all.
- `docs/review-log/` — a permanent, git-tracked review record — does not exist on this branch
  (`docs/branch-protection-rollout`). It was assumed to exist based on `memory-bank/progress.md`
  narrative describing work on `claude/strange-bun-9a0ffc`, which was never merged here. The only
  artifact today is the ephemeral `.claude/.code-review-ok`/`.change-review-ok` marker, which is
  gitignored and consumed (deleted) by the same command it authorizes, before that command even runs.
  Nothing survives past the moment of use.

## Design

### Scope decision

This design closes the structural bypass only. It deliberately does not pursue the docs-path review
exemption that motivated the original conversation — see Out of Scope.

Designed independently of two unmerged branches that touch overlapping territory
(`worktree-review-invocation-audit-trail`, branched from `fix/review-gate-reconcile-designs`, and
`claude/strange-bun-9a0ffc`) — explicit decision, so this work isn't blocked on someone else's
in-progress branch. Where useful, mechanisms are borrowed as prior art without depending on either
branch merging first (the `docs/review-log/` file format below follows `claude/strange-bun-9a0ffc`'s
shape closely; its `AskUserQuestion` confirm-step is not adopted here).

### Architecture

Four pieces, each doing a distinct job:

1. **Layer 1 — Claude Code `PreToolUse` hook** (`review-reminders.sh`/`.ps1`): downgraded from
   consumer to a non-consuming pre-check. Still runs before the agent's own `git commit`/`git push`
   Bash calls, still denies early with a friendly message — but only peeks at the marker, never
   consumes it. Purely a fast-feedback convenience; not a security boundary on its own (see Known
   Limitations).
2. **Layer 2 — real git hooks** (`.githooks/pre-commit`/`pre-push`, via `core.hooksPath`): promoted to
   sole authoritative marker consumer. Fires on any `git commit`/`git push` regardless of who typed it.
3. **Layer 3 — CI required check**: new job verifying review coverage for the whole PR before merge to
   `main` is possible. The only tier that is actually unbypassable.
4. **Durable review record** (`docs/review-log/`, new on this branch) + **invocation-start log** (new):
   what Layer 3 reads, and what makes "was this reviewed" answerable after the ephemeral marker is
   long gone.

### Component: durable review-log record

`/code-review` Step 5 and `/change-review` Job 9 write `docs/review-log/<YYYY-MM-DD>-<hash7>-code-review.md`
(or `-change-review.md`) on every verdict — Approve, Request Changes, or Needs Discussion, matching
`claude/strange-bun-9a0ffc`'s existing rationale that a rejected review is still real audit history.
The subagent **explicitly stages the file** (`git add docs/review-log/<filename>`) before the gated
commit/push runs, so it lands in the same commit it documents — closing a real gap found in the prior
art, where the file was written but never explicitly staged (untracked, `git commit -am` wouldn't even
pick it up).

One addition beyond the prior art: each entry records the **exact commit SHA that was HEAD when the
review ran**, not just the diff hash. This lets Layer 3's containment check use
`git merge-base --is-ancestor <commit> <recorded-sha>` — a plain, native git primitive — instead of
re-diffing historical states after the fact.

**Format:** a YAML frontmatter block (matching this repo's own established convention for structured,
machine-parseable fields elsewhere — `memory-bank/*.md`, spec files) precedes the markdown report body:

```yaml
---
type: code-review        # or change-review
diff-hash: <full sha256>
head-sha: <full commit sha>
verdict: Approve          # informational only -- Layer 3 never trusts this alone, see below
---
```

followed by the same Domain Coverage / Supported Findings / Predicted Risks / Testing Gaps / Opposition
Review content already shown in the chat report. `head-sha` and `diff-hash` are read directly from
frontmatter by Layer 3 (no fuzzy text parsing); the findings table in the body is what gets scanned for
`Blocking` values, per the verdict-trust rule below.

**A review-log entry only counts as passing coverage if CI can verify that mechanically, not by
trusting a summary field.** This repo has already shipped a bug where a summary verdict string drifted
out of sync with the underlying findings table (the 2026-07-16 "Blocking-revision → report propagation
gap," `memory-bank/progress.md`). So Layer 3 scans the entry's findings table directly for any
`Blocking: true`/`Blocking: Yes` row — zero such rows plus a matching SHA is what "passed" means, not
the presence of a `verdict: Approve` line alone.

### Component: invocation-start log

Distinct from the review-log completion entries: `/code-review` Step 1 and `/change-review` Step 1 each
append a line (timestamp, actor, scope) as their literal first action, before any findings work begins
— independent of whether the review ever reaches a verdict. This is what lets a later reader tell
"nobody reviewed this" apart from "someone tried and it silently failed" (subagent crash, session drop,
classifier interference — all documented, recurring failure modes in this repo's own history).

Git-tracked, **not** gitignored — a deliberate divergence from the narrower `ai-review-agent`-specific
prior art (`review-invocation-log.sh` on `worktree-review-invocation-audit-trail`, confirmed gitignored
via the blanket `*.log` rule), since this log needs to survive and be checkable, not just serve as local
debug output.

**Explicit limitation:** there is no hook mechanism that fires on "a slash command was invoked" — slash
commands aren't a tool type `PreToolUse`/`PostToolUse` can see, unlike Bash/Edit/Write/Agent calls. This
log is self-reported by the command's own first instruction step, same trust model as everything else
in this design. It is a visibility improvement (catches honest failures, gives real audit signal), not
a new enforcement primitive — it does not stop a genuinely adversarial or badly broken agent from
skipping the entry the same way it could skip a real review. That residual risk is inherent to LLM
self-attestation and is not claimed to be solved here.

### Component: git-hook relocation (Layer 2)

`.githooks/pre-commit` and `pre-push` dot-source `_review-gate-lib.sh`/`.ps1` and reuse its existing
hash functions (`diff_hash`/`sha256_file` etc.) directly — same dedup pattern this repo already
established (2026-08-04 lib-dedup work), no new hashing logic.

**`pre-commit` — two mechanics changes required, not just "copy the check over":**

1. Marker consumption must be the **last** check `pre-commit` runs (after the existing `handoff.md`
   and autocompact-config checks) — consuming first and then failing a later check would burn the
   marker for a commit that never happened.
2. Before attempting consumption, verify the diff being checked (`git diff HEAD`) is actually
   non-empty. Without this, a commit with nothing staged would let `pre-commit` consume the marker and
   then have git itself refuse ("nothing to commit") — wasting the marker on a no-op and forcing an
   unnecessary re-review.

No reissue-on-failure companion is needed for `pre-commit`: a native git hook exiting 0 means the
commit essentially always proceeds (no gap between "hook approved" and "command ran," unlike the CC
`PreToolUse` hook, which fires before the Bash tool call itself runs).

`pre-commit` currently has no PowerShell twin (plain `#!/usr/bin/env bash`, unlike `pre-push`, which
already delegates pwsh-preferred with a bash fallback). Recommendation: add `pre-commit-check.ps1`/`.sh`
and make `.githooks/pre-commit` a thin delegator, matching `pre-push`'s existing shape, for consistency
with this repo's established dual-shell convention rather than leaving `pre-commit` the odd one out.

**`pre-push` — accepted limitation, not solved:** a push can fail *after* `pre-push` exits 0
(non-fast-forward rejection, network failure) with no native git hook to reissue the marker the way
`review-reminders-post.ps1` does today (git has no general "post-push" hook). For a user-run push that
fails, there is no reissue safety net in this design — worst case is re-running `/change-review`, never
a security hole. The existing CC-level reissue mechanism continues to work for agent-run push failures,
since CC's `PostToolUse` still observes those.

### Component: Claude Code hook downgrade (Layer 1)

`review-reminders.sh`/`.ps1`'s `git commit`/`git push` branches switch from consume-and-deny to
peek-and-deny (read the marker, compare, deny early if missing/mismatched — never delete it). The
`gh pr merge` unconditional-deny branch is unchanged; there is no git-hook equivalent for that command,
so Layer 1 remains necessary there.

### Component: CI check (Layer 3)

New job, `fetch-depth: 0`, computes `merge-base(HEAD, main)`. For every commit in that range:

- **Covered** if a `docs/review-log/*-code-review.md` entry's recorded SHA matches it exactly, or it is
  an ancestor (`git merge-base --is-ancestor`) of a `*-change-review.md` entry's recorded SHA — and
  that entry's findings table has zero `Blocking: true`/`Yes` rows.
- The final merged diff itself must also match at least one passing `change-review` entry.

This directly closes the "intermediate commits ride through unexamined inside a later aggregate review"
gap raised during design (a per-commit exact-hash requirement would have been too strict — it breaks on
routine rebase/amend/squash, which this repo's own workflow does constantly; ancestor-containment via
recorded SHA gets the same guarantee without that fragility).

**Manual step, not self-service:** wiring the new job's context into branch protection's
required-status-checks list is a GitHub settings change — CONFIRM-tier per this repo's own
`SECURITY-GUARDRAILS.md` ("CI/CD changes"). The job itself ships in this work; making it *required*
needs explicit user action (`gh api` or the GitHub UI).

## Known Limitations (explicitly accepted, not deferred by oversight)

1. **`--no-verify` fully bypasses Layer 2, for anyone.** `git commit --no-verify`/`git push --no-verify`
   skip local git hooks at the git level — not something this design can prevent. `dangerous-commands.sh`
   already CONFIRM-flags `--no-verify`, but only for agent-run commands, the same blind spot as
   everything motivating this design. **Layer 2 is best-effort, not hard enforcement — only Layer 3 is
   actually unbypassable.**
2. **`core.hooksPath` can be unset or never configured** (fresh clone, no `mb init` run yet, or manually
   unset). Layer 2 silently doesn't fire. `mb doctor` warns; it does not enforce.
3. **Fleet-wide, Layer 3 is the exception, not the norm.** Per the 2026-07-13 Fleet Audit
   (`memory-bank/activeContext.md`), only `personal-memory-bank` and `ai-code-review-agent` have
   equivalent CI + branch protection. Every other PMB-managed repo receives Layer 2 alone via
   `mb upgrade` (git hooks are `TEMPLATE_OWNED`; the CI job is not, per this repo's existing "CI
   generation is out of `templates/` scope" rule) — a real improvement over today given #1/#2, but not
   a closed gap.
4. **Merge-commit hook-firing behavior is unverified**, not confidently asserted either way — required
   as an explicit empirical test during implementation (see Testing). Fast-forward merges are a
   non-issue: no new commit is created, so nothing needs gating that wasn't already gated on the source
   branch.
5. **Rebase/cherry-pick can alter commit content without re-triggering Layer 2 locally** — standard
   `git rebase` replay skips `pre-commit` per replayed commit. This is caught, but late: a rebased
   commit gets a new SHA that won't match any recorded review-log SHA, so Layer 3's containment check
   fails it at PR-merge time rather than at commit time.
6. **A fully adversarial or sufficiently broken agent can still fabricate both the marker and the
   review-log entry without a genuine review having happened.** Inherent to LLM self-attestation, not
   something this design (or the prior art it draws from) claims to close — explicitly accepted
   residual risk, matching this repo's own established precedent for the same limitation elsewhere.

## Out of Scope

- **The docs-path review-friction exemption** that motivated the original conversation. Deferred, not
  dropped: once this design ships and real, universal enforcement is live, the friction profile it
  creates will be known rather than hypothetical, and the exemption question (if it still matters) can
  be scoped against real data instead of a guess.
- **Reconciling with `claude/strange-bun-9a0ffc`'s confirm-step** (`AskUserQuestion` before marker
  write). Not adopted — that branch remains unmerged, out of scope per this design's explicit scoping
  decision.
- **Fleet-wide CI rollout** for PMB-managed repos beyond `personal-memory-bank`/`ai-code-review-agent`.
  Separate, larger undertaking — most repos in the fleet have no CI gate at all today.
- **Fixing the self-attestation classifier's interference** with marker/review-log writes. Pre-existing,
  orthogonal problem (recurring since 2026-07-14 per `memory-bank/progress.md`), neither created nor
  solved by this design.
- **The separate `mb upgrade`/`mb init` drift-detection hardening** raised during this same
  conversation (`[NS-14]`, `memory-bank/activeContext.md`) — a distinct problem (downstream repos
  silently falling behind PMB's own fixes) with its own scoping needs, tracked separately.

## Testing

1. `pre-commit`/`pre-push` marker consumption: mirror `tests/test-review-reminders.sh`'s existing case
   set (missing marker, mismatched hash, matching hash, `-am` unstaged-but-tracked detection) against
   the relocated logic.
2. Empty-diff race: marker present and valid, nothing staged — confirm the marker is *not* consumed and
   remains valid for a subsequent real commit.
3. `pre-commit` ordering: a `handoff.md`-staged commit with a valid marker present — confirm the
   existing `handoff.md` block fires and the marker is *not* consumed.
4. Bash/PowerShell parity for the relocated hook logic, skip-guarded if `pwsh` is absent (matching this
   repo's existing convention).
5. Live end-to-end: a real `git commit` invoked directly in a shell (not through the agent's Bash tool)
   with no marker present — confirm it is denied, proving Layer 2 actually closes the bypass this
   design targets.
6. CI containment check fixtures: a clean linear chain (each commit individually reviewed), a squashed
   commit (no exact-SHA match, but ancestor-covered by a later change-review entry), an orphan commit
   with no covering entry at all (must fail), and a review-log entry with a `Blocking: true` row despite
   a misleading `verdict: Approve` summary line (must not count as coverage).
7. Invocation-start log: confirm it's written before any findings work, confirm it persists (is
   git-tracked) even when the review never reaches a verdict.
8. Explicit merge-commit test (empirical, not assumed): a real non-fast-forward `git merge` with a valid
   marker — confirm actual `pre-commit` firing behavior and document the result, since this was
   unverified at design time (Known Limitations #4).

## Files Changed

| File | Change |
|---|---|
| `.githooks/pre-commit` | Becomes a delegator (matching `pre-push`'s existing shape); marker-consumption logic moves in via new `.ps1`/`.sh` companions |
| `.githooks/pre-commit-check.sh` / `.ps1` | New — marker consumption, ordered last, empty-diff guard |
| `.githooks/pre-push` | Add marker-consumption logic (reusing `_review-gate-lib` functions) alongside existing checks |
| `templates/.githooks/*` | Mirrored, `TEMPLATE_OWNED` |
| `scripts/review-reminders.sh` / `.ps1` | Commit/push branches: consume-and-deny → peek-and-deny; `gh pr merge` branch unchanged |
| `templates/scripts/review-reminders.sh` / `.ps1` | Mirrored |
| `.claude/commands/code-review.md` | Step 1: invocation-start log write. Step 5: review-log write (recorded SHA field) + explicit `git add` staging, before marker write |
| `.claude/commands/change-review.md` | Step 1: invocation-start log write. Job 9: review-log write (recorded SHA field) + explicit `git add` staging, before marker write |
| `templates/claude-commands/code-review.md` / `change-review.md` | Mirrored |
| `.github/workflows/pmb-health.yml` (or new workflow) | New required-check job: containment verification per commit + final-diff coverage |
| `docs/review-log/README.md` | New — documents the format, including the recorded-SHA field |
| `docs/HOOKS-GUIDE.md` | Document the layer changes, the new git-hook files, the invocation-start log, and Known Limitations #1/#2 explicitly (so a future reader doesn't mistake Layer 2 for a hard guarantee) |
| `templates/docs/HOOKS-GUIDE.md` | Trimmed mirror, per existing SYNC NOTE convention |
| `tests/test-review-reminders.sh` | Updated for peek-not-consume behavior |
| New git-hook test suite | Marker consumption, ordering, empty-diff guard |
| New CI-containment test suite | Fixtures per Testing #6 |
| `tests/run.sh` | Register new suites |
