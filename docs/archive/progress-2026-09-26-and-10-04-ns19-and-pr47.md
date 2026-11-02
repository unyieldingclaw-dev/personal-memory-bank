# progress.md sections relocated 2026-10-20 (verbatim)

Moved verbatim from `memory-bank/progress.md` to fund the 2026-10-20 entry under the startup-context
ratchet. Stubs with the original headings remain there.

## 2026-10-04 — PR #47 merged (`19931dc`); `fix/ns19` rebased onto it

- `fix/ns19-plan-workflow-template` was rebased onto `437d3c1` and `19931dc`, and on 10-05 onto
  `07e3bd2` (#51). Its `progress.md` and `CHANGELOG.md` conflicts were resolved by date order
  and by keeping both entries. Its hash citations now name the branch, because a rebase and a
  squash merge both rewrite hashes.
- The stale root `handoff.md` (2026-09-25) has landed except for two things: its Codex-sandbox ACR
  note, carried by PR #48 (still open), and the open decision to track or ignore `.agents/` and
  `.codex/`. PR #48 tracks only 1 of the 9 `.agents/` files. Delete it only once both have a
  durable home, and with user confirmation.

## 2026-09-26 — [NS-19] plan workflow fixed; diff-only standards reversed by fleet data

- Pre-approval adversarial review of "make `mb.ps1` diff-only for `standards/`": 7 of 8 adopter repos hold the
  same OLD shipped blobs (e.g. `CODE-REVIEW.md` `8b9d06c1` in 3 repos, spot-checked), so the harm is stale
  standards, not lost edits. Diff-only deferred to a design (overwrite only on a known shipped version).

