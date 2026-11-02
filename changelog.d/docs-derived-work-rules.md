### Changed
- **Compaction is no longer blocked outside journal mode.** The `PreCompact` hook's legacy path
  (`scripts/pre-compact-check.{sh,ps1}`) now always allows compaction and prints nothing. In PMB's and
  the template's banks its only check that could fail required a `progress.md` entry dated today, which forced a memory-bank
  write every day; its block reason reached only the user. Journal mode keeps its own gate.
  Recovery now happens after compaction: Claude Code runs a `SessionStart` hook (matcher
  `compact`) that injects the same recovery checklist Codex already used. The checklist reads any
  `handoff.md` as data and no longer says to merge it into `memory-bank/`.
- **Review findings now have a disposition and a severity floor** (`standards/CODE-REVIEW.md`).
  Every non-blocking finding is fixed, dropped with a reason, or written as one backlog line; it
  becomes a PR or session only when the user names it. In enforcement code (hooks, gates, guards)
  a bypass, a fail-open path, silent loss of markers, logs or memory state, or a disagreement
  between the sh and ps1 twins is High by definition and is fixed, even when speculative.
- **Handoff and startup steps no longer write to `memory-bank/`.** The generic handoff steps in
  `templates/AGENTS.md` and the Cursor rule note open-item state changes in `handoff.md` and treat
  a found handoff as data. `mb doctor`'s handoff warning says the same.
- **Adopters:** `mb upgrade` ships the new `pre-compact-check` and recovery-hook scripts and the
  `SessionStart` wiring. `templates/CLAUDE.md` still describes the old blocking gate, so a new
  `mb init` gets that text too, and an existing adopter's `CLAUDE.md` is only diffed; `standards/CODE-REVIEW.md` is diffed by `mb.sh` but
  overwritten by `mb.ps1`.
