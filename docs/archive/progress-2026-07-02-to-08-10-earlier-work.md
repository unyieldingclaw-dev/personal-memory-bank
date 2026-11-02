# Archived: `progress.md` 2026-07-02 → 2026-08-10 — "Earlier Work", relocated 2026-10-14

**Relocated from `memory-bank/progress.md` on 2026-10-14, verbatim.** The section below the first
`---` is lines 420-446 of `memory-bank/progress.md` at `e3c2f43`. Reproduce with
`git show e3c2f43:memory-bank/progress.md | sed -n '420,446p'`, which is byte-identical (`cmp`) to
the text below. Nothing was summarised or reflowed.

**Why:** the PR #55 memory-bank delta (`[NS-66]`, `[NS-67]`, a 2026-10-14 entry) had to fit under
the aggregate startup-context ratchet, which stood at zero margin against `origin/main` at
`e3c2f43`. **Delta, not a level: 2,418 bytes and 28 lines moved out** (27 section lines plus the
blank line after them), measured on the extracted range before the move. The section was already
a condensed layer: each of its four bullets points at its own fuller `docs/archive/` file. Each
bullet is a closed-out summary. The two follow-ups they name are still open, but they are owned by
`[NS-0]` and `[NS-13]` in `activeContext.md`, not by this section.

**Citation survival was grep-verified before the move, for the heading text and `[NS-N]`
references only.** No file outside `progress.md` named the section by heading, and its original
heading stays listed in `progress.md`'s stub. The four archive files its bullets point at describe
it by role instead, as "a condensed pointer" in `memory-bank/progress.md`. Those back-references
now resolve through that stub to this file.

---

## Earlier Work (2026-07-02 through 2026-08-10) — condensed, full detail archived

- **2026-07-16 through 2026-08-05 — Review-gate mechanism evolution**: self-attestation fix (marker-write
  moved into the last dispatched review subagent), a false-positive fix in `review-reminders.sh`'s
  command matching, the confirm-step redesign (durable `docs/review-log/` + user-confirmed marker write),
  a worktree-root-resolution fix (closed a real denial-from-inside-a-worktree bug), a hook-lib dedup
  (`_review-gate-lib.sh`/`.ps1`), and the confirm-step's first live whole-branch review (found and fixed
  one real Blocking finding). Full detail: `docs/archive/progress-2026-07-review-gate-evolution.md`.
- **2026-07-02 through 2026-07-13 — Repo governance, CI hardening, branch protection**: `mb upgrade`
  slash-command auto-discovery fixes, 4 pre-existing CI failures closed (SAST config, 2 false-positive
  greps, PowerShell lint), CI hardening across 3 downstream repos, branch protection rolled out to 5
  public repos, a real hash byte-mismatch bug fixed (bash vs. PowerShell diverged on trailing-newline
  handling), the cross-repo write boundary hook built after a real incident (this session wrote into
  another repo's working directory without checking ownership), and the review-flow fleet audit (found
  real enforcement in only 2 of 11 repos). Full detail:
  `docs/archive/progress-2026-07-repo-governance-and-ci.md`.
- **2026-07-14, 2026-07-23 — `mb backlog` Task 1 + mb update-notifier**: `mb backlog`'s Task 1 shipped
  with two real Critical/High security bugs found and fixed (path traversal, sed-delimiter injection);
  Tasks 2-5 not started (`[NS-0]`). The update-notifier shipped clean, but the same session produced an
  authorization-drift incident (a "what do you suggest" non-answer treated as merge approval) that
  produced the "What Counts as Approval" rule. Full detail:
  `docs/archive/progress-2026-07-mb-backlog-and-notifier.md`.
- **2026-08-08, 2026-08-10 — Concurrent session claims + memory-bank freshness hook**: session-claims
  shipped (13 tasks + 5 post-review fixes, including one found only by a final whole-branch review after
  every individual task had already passed its own two-stage review); the freshness-hook spec was
  designed and committed but not yet implemented (`[NS-13]`). Full detail:
  `docs/archive/progress-2026-08-freshness-and-session-claims.md`.
