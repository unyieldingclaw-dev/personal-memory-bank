# Archived: `progress.md` 2026-10-04 → 2026-10-19 — five sections relocated 2026-10-23

**Relocated from `memory-bank/progress.md` on 2026-10-23, verbatim,** to fund the PR #85 entry under the
startup-context ratchet. The five sections below the first `---` are lines 35-66 and 79-87 of
`memory-bank/progress.md` at `c2a5d1c`. Reproduce with
`git show c2a5d1c:memory-bank/progress.md | sed -n '35,66p;79,87p'`, which is byte-identical (`cmp`) to
the text below. Nothing was summarised or reflowed. A pointer with the original headings stays in
`progress.md`. Citation check: `git grep` outside `docs/archive/` found no `progress.md` citation of these dates.

---

## 2026-10-19 — PRs #64, #72, #69, #74 and #75 merged

- #64 (`0e05a6b`): both dangerous-commands hooks decode the payload fallback and also match a CR-deleted view. Its follow-ups: `[NS-38]`'s backlog file.
- #72 (`5301460`): #65's T-A test and O-1 comment.
- #69 (`9c9b739`): the ps1 journal refuses arguments pwsh may have altered.
- #74 (`b35f22b`) freed 25 spec lines (800 → 775); #75 (`c10cd87`) set `PMB_REQUIRE_SYMLINKS` in CI.
- What gates the flag PR: `[NS-68]`. Funded by moving `[NS-47]` verbatim to `docs/archive/`.

## 2026-10-19 — PR #65 merged (`0b67d9d`): no FIFO hang at `started` or the gate probe

- Detail: `0b67d9d`'s message. It joins both branch commits, so it says the sh probe used `mktemp`, then
  dropped it. `main` never used `mktemp`: a fixed `.probe.$$` became a per-attempt name opened with `noclobber`.
- The spec is at 793 of 800 lines; #69's body says merging #69 makes it 800.
- What still gates the flag PR: `[NS-68]`.

## 2026-10-19 — PR #63 merged (`d3f87f8`): FIFO-safe journal gate, ps1 regular-file check

- What changed is in `d3f87f8`'s message. Carry-overs, and what still gates the flag PR: `[NS-68]`.
- Funded by moving `[NS-25]` verbatim to `docs/archive/`; that saves bytes, not lines.

## 2026-10-18 — C1 Plan A merged (#57, `d751b73`); PreCompact lock-up recorded (#62, `e38620f`)

- **#57** adds the bash journal and its PowerShell twin, plus a journal-mode PreCompact gate: auto never
  blocks; a manual one with no new qualifying record is blocked once and passes on repeat (any
  compaction re-arms it), and its two environment blocks repeat until fixed. Inert until Plan C's
  flag PR (`[NS-68]`).
- **Its first Linux CI run hung for about 2 h** on a planted FIFO. On pwsh 7.4.7, `Get-Item` reports a
  FIFO's `UnixMode` as a regular file, and its provider rewrites `\` to `/`. Fixed in `4738ad5` (PR #57 branch; squashed into `d751b73`) with
  `/usr/bin/test -f`. The hardening follow-ups are PR #63.
- **#62** records the 2026-09-27 lock-up in `docs/backlog/`. The dispositions of the four backlog items
  the C1 spec absorbed are set in this entry's commit.

## 2026-10-04 — `mb doctor --check` and pre-push Check 7 (PR #51)

- Two full `/code-review` rounds. Round 1 was blocked on a test that could not fail (the
  redundant-match-path trap in `standards/CODE-REVIEW.md`), caught by the Testing domain's
  mutation run.
- The worktree-isolation guard refuses `/code-review` Step 5's compound marker command, so the
  marker was written in separate commands.
- Correction: `tests/test-mirror-parity.sh` DOES cover `scripts/pre-push-check.*`, through the
  TEMPLATE_OWNED sweep.
