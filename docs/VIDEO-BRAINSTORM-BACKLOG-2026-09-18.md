# Video Brainstorm Backlog — 2026-09-18

**Status:** triage output from a one-time brainstorm, not itself a spec — see "Priority queue" for
what's next. **Not pointed to from `activeContext.md` by design**, to avoid the zero-margin
byte-ratchet cost (`[NS-42]`/`[NS-44]`); the three actionable items are tracked as `mb backlog`
entries instead (`mb backlog list`), which cost nothing against that ratchet. This file itself is
discoverable only by browsing `docs/` or from those backlog entries' own citations back to it.

A pasted podcast/video transcript named 10 external GitHub repos as candidates for functionality
PMB could mine. Researched via `/superpowers:brainstorming` (10 parallel research agents, one per
repo, briefed on PMB's architecture and open gaps), then synthesized against two criteria:

1. **Immutable-charter fit** — does it close a gap `projectbrief.md` names as unmet?
2. **Risk vs. scope** — for non-charter items, weight by open incidents vs. forward-looking polish.

## Verdict table

| Repo | Verdict | Why |
|---|---|---|
| **context-mode** (mksglu) | High — **pursued** | `ctx_index`/`ctx_search` (SQLite FTS5, chunked by heading, snippet-level retrieval, no cloud dependency for core function) matched `projectbrief.md`'s then-open requirement: "an index is loaded, detail is fetched on demand." That's `[NS-44]`/`[NS-28]`/`[NS-35]` (`[NS-42]` is the related-but-distinct write-rate half, not the same gap), three prior attempts none of which stuck. **Shipped**: `docs/superpowers/specs/2026-09-18-memory-bank-index-detail-design.md`, merged PR #33 (`1eda52c`) — structural piece only, doesn't clear the binding aggregate constraint alone, `[NS-42]` untouched. The shipped design explicitly **rejected** context-mode's own SQLite-FTS5 mechanism (its "Alternatives considered" section), keeping only the general index/detail-on-demand idea — no new runtime dependency. |
| **claude-dashboard** | High — **next priority** | Reads Claude Code's own local session/transcript files directly. Its "departures board" (idle/stuck detection) and "unpushed work" strip map onto `[NS-52]` (WIP lost in gitignored `handoff.md`) and fleet version drift across stale worktree sessions. Self-contained; one optional external call, toggleable off. Adapt-existing-tool, not a novel design — shorter spec than NS-44 was. |
| **worktrunk** (max-sixty) | Medium | Self-contained Rust CLI. `wt merge`'s rebase-before-merge safety check would have caught the incident class behind `[NS-26]` (stale worktree branches regressing shared hook files). `wt list` is a model for a `mb worktrees` status command. No open incident actively bleeding from this right now, unlike NS-44's four-times-flagged status — lower urgency than claude-dashboard. |
| **open-code-review** (Alibaba) | Medium | Core LLM-review engine needs external API access — not adoptable as-is, conflicts with PMB's no-external-dependency charter and its already-working 9-job review pipeline. Its structured JSON findings schema (severity+category) and local static HTML results viewer ARE reusable — PMB's review gate findings currently live only in prose/commit messages. Fold into the small-wins bundle below, doesn't carry enough weight for its own spec. (Podcast description of git-hook integration was wrong — it has none.) |
| **ECC** (affaan-m) | Medium | Same idea as PMB's 7-phase workflow, larger scope. Two worth stealing: RED-gate wording "written but not executed ≠ RED" (blocks false-pass claims), and a structured "TDD evidence report" as a defined Commit-phase artifact. Small-wins bundle. |
| **agent-skills** (addyosmani) | Medium | Purely advisory, no hook enforcement. Its post-launch production-verification checklist (health endpoint, error dashboard, critical-flow smoke test) plugs a real hole: PMB's workflow ends at Commit/Ship with no post-deploy check at all. Small-wins bundle. |
| **Logic-Loop** (SuperLogicAI) | Medium, early-stage (11 stars) | Not a tool to adopt. Its *pattern* — a durable, structured, transcript-derived event log instead of hand-written, loseable `handoff.md` — is a second angle on `[NS-52]`, complementary to claude-dashboard. Fold into claude-dashboard's scope rather than a separate item. |
| **deckgauge** (Codpal-Limited) | Low — dropped | Heavy multi-service platform aggregating *from* Jira/GitHub — architecturally opposite to PMB's single-file model. Podcast's framing was wrong (doesn't replace issue trackers). |
| **Campus AIOS** (trainingsites) | Low — dropped | Real project, built for solo-coach business ops, not coding governance. Domain mismatch. |
| **Reckoner** (CaptainASIC) | Low — dropped | Tracks account-level *billing* credit across providers via external APIs — not Claude Code session/context-token usage, which is PMB's actual gap. UI-pattern reference only, nothing to adopt. |

## Priority queue (after NS-44's partial design, which has shipped — see Verdict table, doesn't close the entry)

Tracked as `mb backlog` entries (`docs/backlog/`, `mb backlog list` to see current status). Their
rationale paragraphs are living copies meant to be kept current; the Verdict table above is a frozen
2026-09-18 snapshot — if a backlog entry's assessment changes, update the entry, not this table.

1. **claude-dashboard** — spec next. `docs/backlog/adapt-claude-dashboard-patterns-for-pmb.md`.
2. **Small-wins bundle**, one spec covering Alibaba + ECC + agent-skills.
   `docs/backlog/small-wins-bundle-alibaba-ecc-agent-skills-pattern.md`.
3. **worktrunk** — worktree safety patterns, lower urgency.
   `docs/backlog/adopt-worktrunk-worktree-safety-patterns.md`.

## Provenance

Recovered 2026-09-19 from the pre-compaction portion of the session transcript
(`26736dfa-6f79-4dd3-8a21-62fd5081a05d.jsonl`) after the live conversation context no longer held
this detail and nothing had been written to `memory-bank/` about it. **Correction:** an earlier
draft of this section claimed a `grep -rniE` for all 10 repo names returned zero hits outside
NS-44's own `activeContext.md` entry — that's false. `docs/superpowers/specs/2026-09-18-memory-bank-index-detail-design.md`
(already merged via PR #33, `1eda52c`, before this file was written) names all 10 repos (9 verbatim,
`campus-ai-os` spelled as this doc's "Campus AIOS") in its own Provenance section, and discusses
`context-mode` in its "Alternatives considered" section.
That document covers the same 10-repo survey in more depth for the one item that shipped; this file
is the first internal record covering all 10, including the 9 that didn't.
