# Backlog Functionality Design

**Date:** 2026-07-14
**Status:** Approved

## Problem

The only existing "backlog" concept in PMB is an informal `## Backlog` heading buried inside
`memory-bank/progress.md` — currently just "⏸ handoff CLI, pinned.md, mb update --from-git, mb
privacy". This has three real problems:

1. **Not queryable.** There's no command to pull it up; a user has to scroll/search a growing
   file.
2. **Not fresh.** Nothing tracks whether a backlog item is still relevant — it sits until someone
   happens to notice it again.
3. **Not durable.** `progress.md` has `retention: archive-after-6m` — an open backlog item could
   be silently archived away along with unrelated historical entries.

## Scope

A deliberate parking lot, not a catch-all for "everything not done yet." An item belongs in the
backlog when: the user explicitly asks for it to be added, something gets pushed to "do later,"
something needs more investigation before it can be actioned, or it's an idea worth capturing
without committing to it. Claude may *notice* one of these moments in conversation and offer to
add an item, but never writes a backlog file without the user confirming first (see "Claude
proposes, user approves" in `CLAUDE.md`'s Governed Assistance Model).

## Design

### Storage

One file per item: `docs/backlog/<slug>.md` — no date prefix in the filename (unlike
`docs/plans/`/`docs/superpowers/specs/`), since the `created:` field already carries the date and
a bare slug makes the `<slug>` argument to every `mb backlog` subcommand shorter to type. Slug
generation: lowercase the title, replace whitespace/non-alphanumeric runs with a single hyphen,
strip leading/trailing hyphens, truncate to 50 characters. On collision, append `-2`, `-3`, etc.

Frontmatter:
```yaml
status: open              # open | promoted | dismissed
created: 2026-07-14
last-reviewed: 2026-07-14
staleness-threshold: 90d  # same field/convention as memory-bank/*.md
related_plan: null        # set to the plan path when promoted
```
Body: the title as an H1, then freeform description.

`staleness-threshold` defaults to `90d` at creation time and is not settable via an `mb backlog
add` flag — kept simple, matching the fact that `memory-bank/progress.md`'s own threshold isn't
CLI-settable either. Adjustable by hand-editing the file's frontmatter afterward if a specific
item genuinely needs a different threshold.

No `investigating` status — an item someone's actively looking into is still `open`; a separate
status was considered and cut as unnecessary granularity (see "Rejected Alternatives").

### Commands

`mb backlog <subcommand>`, mirroring the shape of the existing `mb plan <subcommand>` family:

| Subcommand | Behavior |
|---|---|
| `mb backlog add "<title>" ["<description>"]` | Creates the file with the frontmatter above. Description is an optional second positional argument (non-interactive — `mb` runs non-interactively in normal use, including when Claude invokes it on the user's behalf); if omitted, the body is left empty for later editing. |
| `mb backlog list` | Lists `open` items only by default (slug, title, age); `--all` includes `promoted`/`dismissed` |
| `mb backlog show <slug>` | Prints one item's full content |
| `mb backlog promote <slug>` | Seeds a plan draft stub in `.claude/plans/` (title + description carried over as a starting point — not a finished plan), sets `status: promoted` and `related_plan:` on the backlog file. This only *starts* the existing plan lifecycle — the normal `superpowers:writing-plans` → `mb plan promote` flow still applies afterward to turn the stub into a real, user-approved plan in `docs/plans/`. `mb backlog promote` and `mb plan promote` are two different steps in the same lifecycle, not the same operation — deliberately, since a backlog item becoming "worth working on" doesn't mean its plan content has been written or approved yet. The backlog file is kept, not deleted, as an audit trail. |
| `mb backlog dismiss <slug>` | Sets `status: dismissed`; kept for history, excluded from default `list` |

### Freshness

A new `mb doctor` check flags any `open` item whose `last-reviewed` exceeds its own
`staleness-threshold` — the same staleness-check pattern already applied to
`memory-bank/activeContext.md`/`progress.md`, just scoped per-item instead of per-file. This is
what makes "stays fresh" real: an item that's been sitting untouched gets surfaced for a "still
relevant?" decision instead of rotting silently.

### `mb status` integration

One live line: `"N open backlog items — run mb backlog list"`. Computed by scanning
`docs/backlog/` for `status: open` at call time — nothing cached or duplicated, so there's nothing
that can drift out of sync with the actual files.

### Discoverability — no CLAUDE.md footprint

For Claude to reliably *notice* a backlog-worthy moment across future sessions (not just this
conversation), the trigger needs to be delivered automatically every session without living in
`CLAUDE.md` or `memory-bank/` (both read every session; the user explicitly wants to avoid growing
either).

The mechanism: a project command `.claude/commands/backlog.md`, mirrored to
`templates/claude-commands/backlog.md` for distribution via `mb init`/`mb upgrade` — the same
distribution path already used for `/code-review`, `/change-review`, `/pmb-status`. Its
`description:` frontmatter is written with the actual trigger language (defer / later / idea /
needs investigation / "what's in my backlog"). Every Claude Code session automatically receives
the full list of available commands with their descriptions via a system-reminder — this is how
Claude already discovers `/code-review`, `/ai-review`, etc. without any CLAUDE.md mention. A
well-written `description:` is therefore sufficient to make Claude check backlog-relevance on
every message (the `using-superpowers` skill's own rule: "if a skill might apply, even 1% chance,
invoke it"), which is *more* reliable than an advisory CLAUDE.md line — and costs zero standing
token footprint.

The command itself should stay thin — closer to `/pmb-status` (a simple wrapper that runs an `mb`
subcommand and reports back) than to `/code-review` (multi-agent orchestration). Body content:
map user intent to the matching `mb backlog` subcommand; no independent judgment logic beyond
that. Naming: `/backlog`, unprefixed — matches the pattern for workflow commands
(`/feature-dev`, `/code-review`, `/health-check`), as opposed to the `mb-`/`pmb-` prefix used for
the couple of infra-diagnostic commands (`/pmb-status`, `/mb-drift`).

## Rejected Alternatives

- **Hybrid storage** (individual files + an auto-synced summary rolled up into `progress.md`):
  creates two places that can drift, requiring either regenerate-on-every-change logic or manual
  sync discipline — the same "docs vs. reality" problem this session's `WORKFLOW.md` fix was
  about. The "ask and get a quick pull-up" need is already met by `mb backlog list` on demand.
- **A 6th core `memory-bank/backlog.md` file**, read every session: heaviest option — would
  require updating `CLAUDE.md`, `standards/MEMORY-BANK.md`, and every doctor "required files"
  check across the distribution (all currently hardcode 5 files), and grows the every-session
  token footprint the user is explicitly trying to avoid.
- **CLAUDE.md pointer line**: viable and small, but unnecessary once the command-description
  mechanism (above) covers the same discoverability need at zero footprint.
- **`investigating` as a separate status**: a distinction without enough behavioral difference
  from `open` to justify a fourth command surface or extra doctor-check branching.

## Files Changed

| File | Change |
|---|---|
| `scripts/mb.sh` / `scripts/mb.ps1` | New `backlog` command: `add`/`list`/`show`/`promote`/`dismiss` subcommands |
| `docs/backlog/` | New directory; one file per backlog item. Committed to git (durable, unlike `.claude/plans/`'s gitignored scratch drafts) |
| `mb doctor` | New check: flag `open` items past their `staleness-threshold` |
| `mb status` | New line: live open-item count |
| `.claude/commands/backlog.md` + `templates/claude-commands/backlog.md` | New thin command wrapper; description carries the trigger language |
| `tests/test-mb-backlog.sh` | New test suite; register in `tests/run.sh` |
| `docs/QUICK-REFERENCE.md` | Add `mb backlog` row, matching the existing `mb preflight` row's format (there's no `mb plan` row there to match, and no `templates/docs/QUICK-REFERENCE.md` exists — this file isn't currently mirrored to `templates/docs/`, same as `mb plan`/`mb preflight` themselves aren't) |

## Out of Scope

- No automatic backlog-item creation without user confirmation, ever — matches the "Claude
  proposes, user approves" rule and this session's earlier approval-semantics fix.
- No priority/severity field on backlog items — not requested, and `status` + freshness already
  cover the stated need ("what are my backlog items" + "still relevant?").
- No cross-project or cross-repo backlog aggregation — each project's `docs/backlog/` is local to
  that project, same as `docs/plans/`.
