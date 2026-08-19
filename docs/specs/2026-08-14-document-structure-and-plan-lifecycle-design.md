# Document Structure and Plan Lifecycle

**Date:** 2026-08-14
**Status:** Approved, design only — **not yet implemented**. This document specifies what should
change; the "Files Changed" table below is a plan, not a record. As of this writing, only this
file and `docs/WORK-MB-DOCUMENT-STRUCTURE-BRIEF.md` actually exist — the `CLAUDE.md` override,
its `templates/CLAUDE.md` mirror, `templates/docs/plans/README.md`, and the two frozen-directory
marker READMEs have not been created. See `memory-bank/activeContext.md`'s `[NS-20]` for the
tracked pending-work record; do not assume this is closed without checking there first.

**Note on this file's own location:** this is the first spec written under the convention this
document establishes — `docs/specs/`, not `docs/superpowers/specs/`. Everything before it stays
where it is; see "Migration Policy" below for why. **This also means the drift this spec exists to
close is not yet actually closed** — until the `CLAUDE.md` override lands, new specs/plans will
keep landing in `docs/superpowers/specs/`/`docs/superpowers/plans/` exactly as before; this file's
own location is a manually-chosen exception, not yet an enforced convention.

## Problem

Two parallel drifts, found while investigating a user complaint about nested folders
(`docs/superpowers/specs/`, not `docs/specs/`):

**1. Location drift.** `standards/WORKFLOW.md`, `.claude/commands/feature-dev.md`, and
`.claude/commands/change-review.md` have always correctly documented `docs/specs/` and
`docs/plans/` as the canonical locations. They were never wrong. But the `superpowers` plugin's
`brainstorming`/`writing-plans` skills default to `docs/superpowers/specs/`/`docs/superpowers/plans/`
instead, and nothing in this repo ever bridged the gap — both skills explicitly support a
project-level override (`"(User preferences for ... location override this default)"`), but it
was never set. Result: `docs/specs/` doesn't exist at all; every one of 35 real specs and 25 real
plans landed in the plugin's nested default instead.

**2. Dead lifecycle tooling.** A full plan-lifecycle system (`mb plan status/list/promote/archive`,
status frontmatter, staleness detection, `docs/plans/` → `docs/archive/plans/`) was built and
shipped 2026-06-22 — fully tested (17/17 passing today), full dual-shell parity. It has never been
used. Every plan since, including plans written after it existed, went to
`docs/superpowers/plans/` via drift #1 instead, which has no lifecycle, no status, no staleness
detection — plans just accumulate as flat files forever.

Specs have no equivalent lifecycle tool, built or otherwise — just the location drift.

## Design

### Canonical locations, going forward only

- Specs: `docs/specs/YYYY-MM-DD-<topic>.md` (already `WORKFLOW.md`'s documented convention; already
  has a lightweight `**Status:**` header line in 22 of 35 existing specs — sufficient, no new
  lifecycle tool needed).
- Plans: draft in `.claude/plans/YYYY-MM-DD-<slug>.md` (gitignored scratch) → `mb plan promote` →
  `docs/plans/YYYY-MM-DD-<slug>.md` (status frontmatter, tracked) → `mb plan archive` →
  `docs/archive/plans/` on completion.

### Why plans get real lifecycle tooling and specs don't

A plan represents work with live execution state — something can be `active` and silently go
stale if abandoned mid-flight, which is dangerous if resumed later against a drifted repo (see
`docs/superpowers/specs/2026-08-12-investigation-integrity-design.md`'s "independent review
discipline" (mechanism 3) for a concrete case this session). That risk is exactly why `mb plan status`'s
30-day staleness check exists. A spec has no comparable execution state — it's approved once,
then referenced, not resumed. Building a parallel `mb spec` command would be new, untested
engineering solving a problem specs don't actually have. Not built here.

### Closing the drift at its root: one `CLAUDE.md` override

The fix is not to change what `WORKFLOW.md`/`feature-dev.md` say (they were already right) — it's
to make the plugin skills that actually produce specs/plans agree with them. Add to `CLAUDE.md`'s
`## Workflow` section (both live and `templates/` — see "Distribution" below):

```markdown
**Plan/spec file locations override the superpowers plugin defaults:**
- Specs: `docs/specs/YYYY-MM-DD-<topic>.md` (not `docs/superpowers/specs/`)
- Plan drafts: `.claude/plans/YYYY-MM-DD-<slug>.md` (not `docs/superpowers/plans/`), promoted to
  `docs/plans/` via `mb plan promote` once approved — see `docs/plans/README.md`.
```

### Distribution: shipped to `templates/CLAUDE.md`, not PMB-local

This is a genuinely better default (flat structure, actually-used lifecycle tooling instead of
dead code), not a PMB-specific preference, so it ships to every repo that runs `mb upgrade`. Cost
to downstream repos is low: they either already follow this convention or gain a strictly better
one. Explicitly disclosed, not hidden: this does change behavior on next `mb upgrade` for any
repo that had drifted the same way PMB had.

### Fixing the one real gap found in the already-built system

`docs/plans/README.md` (the lifecycle's own explanation, referenced by `mb plan status`'s
guidance text) is not currently in `templates/docs/` — confirmed via direct check. Add it, so
repos adopting this convention via `mb upgrade` get the explanation along with the mechanism.

### Migration Policy: freeze history, fix forward only

**Do not move any of the 35 existing specs or 25 existing plans.** Checked directly, not assumed —
a real, double-digit number of files (memory-bank + archive + specs) cross-reference
`docs/superpowers/specs/*` and `docs/superpowers/plans/*` by exact path. The precise count is
sensitive to grep scope (whether worktree checkouts, self-references, and README files are
included or excluded) and isn't load-bearing here — under any reasonable counting convention it's
large enough that moving the underlying files would break real references for historical record
with no corresponding benefit, since these are completed work, not active plans needing lifecycle
tracking. Add a short note (not a full README rewrite) to the top of `docs/superpowers/specs/` and
`docs/superpowers/plans/` marking them frozen as of this date, so the two-directory split reads as
a deliberate historical boundary later, not unfinished cleanup.

## Testing

1. **Override actually works**: trigger `brainstorming`/`writing-plans` for a trivial throwaway
   topic after the `CLAUDE.md` change lands, confirm the file is written to `docs/specs/`/
   `.claude/plans/` and not the plugin default. Delete the throwaway file after confirming.
2. **`mb plan` suite still passes**: `bash tests/test-mb-plan.sh` and the PowerShell equivalent,
   both shells — no code in `mb.sh`/`mb.ps1` changes, so this should be unaffected, but re-run to
   confirm nothing in this change touches it unexpectedly.
3. **No broken cross-references**: re-run the same `grep -rl "docs/superpowers/specs/"` /
   `"docs/superpowers/plans/"` check used during design and confirm the same file set still
   resolves (nothing was moved, so this should be a no-op confirmation, not a fix).
4. **`mb doctor`/`mb health-check` clean**: run after the `templates/` changes to confirm no new
   drift warnings (e.g., template-vs-live mismatch checks).

## Known Limitations (disclosed, not hidden)

1. **The override is advisory, same ceiling as every other `CLAUDE.md` rule.** A compacted
   session or one that doesn't load `CLAUDE.md` correctly can still drift back to the plugin
   defaults. No hook enforces file-write locations for skill output.
2. **Downstream repos that already have real content in their own `docs/superpowers/specs/`
   will get the same "two directories" split PMB just got**, not a clean migration — this design
   doesn't solve that for them, it just stops the drift from continuing.
3. **`mb plan`'s lifecycle has been dry-run tested but not yet exercised in real, sustained use.**
   17/17 passing tests confirm the mechanics work; it doesn't confirm the workflow is actually
   pleasant or sustainable over months of real use the way the ad-hoc flat-file approach
   (imperfect as it is) has empirically been for two months. Worth revisiting after real use.

## Out of Scope

- Building `mb spec` or any spec-equivalent lifecycle tool — explicitly not needed, see Design.
- Migrating any of the 35 existing specs or 25 existing plans — explicitly frozen in place.
- Fixing the same drift in any downstream repo directly — out of the cross-repo write boundary;
  they inherit the fix via their own next `mb upgrade`, same as any other template change.
- Rewriting `WORKFLOW.md`/`feature-dev.md`/`change-review.md` — already correct, not touched.

## Files Changed

**Status column added deliberately** — unlike a changelog, this table describes a plan, not a
completed diff. Do not read "Planned" rows as done; check `memory-bank/activeContext.md`'s
`[NS-20]` for the current, authoritative status before assuming any row below has landed.

| File | Change | Status |
|---|---|---|
| `CLAUDE.md` | New override note in `## Workflow` section, redirecting plugin skill defaults | Planned |
| `templates/CLAUDE.md` | Same override note — shipped, not PMB-local | Planned |
| `templates/docs/plans/README.md` | New — was missing from template distribution entirely | Planned |
| `docs/superpowers/specs/README.md` | New — short frozen-as-of-date note | Planned |
| `docs/superpowers/plans/README.md` | New — short frozen-as-of-date note | Planned |
| `docs/specs/2026-08-14-document-structure-and-plan-lifecycle-design.md` | This file | Done |
| `docs/WORK-MB-DOCUMENT-STRUCTURE-BRIEF.md` | New — portable brief for the user's separate work Memory Bank, per the established convention | Done |
