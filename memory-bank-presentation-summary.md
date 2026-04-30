# Memory-Bank Overview Deck — Build Summary

**Deliverable:** `memory-bank-overview.pptx` (16 slides, editable, built on the T-Mobile v27 brand template).
**Build script:** `scripts/build_overview_deck.py` (re-runnable; regenerates the deck from real repo content on every run).

---

## Slide list

| # | Title | Layout used | Purpose |
|---|-------|-------------|---------|
| 1 | Memory-Bank Project — Safer, more consistent AI coding assistants across sessions | `1.1_Title-Option_Gradient` | Hero title |
| 2 | Who this is for | `1.1_Title-Option_White` | Audience framing |
| 3 | Executive summary | `1.1_Title-Option_White` | One-minute pitch |
| 4 | The problem | `1.1_Title-Option_Black` | Before/after on a dark slide for contrast |
| 5 | Solution overview | `1.1_Title-Option_White` | 9-tile grid of the nine pieces |
| 6 | Persistent memory-bank | `1.1_Title-Option_White` | Five memory-bank files + the "read-first" rule |
| 7 | 3-tier security guardrails | `1.1_Title-Option_White` | BLOCK / CONFIRM / WARN columns |
| 8 | Code quality standards | `1.1_Title-Option_White` | Before Claiming Done · Comments · Errors · Structure |
| 9 | Structured logging | `1.1_Title-Option_White` | Why-it-matters + structlog/pino pattern box |
| 10 | Feature workflow | `1.1_Title-Option_White` | 7-step flow with TDD (step 4) highlighted in magenta |
| 11 | Multi-agent /code-review | `1.1_Title-Option_White` | Three role-separated reviewers (Security · Perf · Style) |
| 12 | Test coverage + opponent auditor | `1.1_Title-Option_White` | Step 4 Test Coverage (generates missing tests) + Step 5 Auditor compare |
| 13 | Install — Windows | `1.1_Title-Option_White` | Five plain-English steps + copy-paste code box |
| 14 | Install — Mac | `1.1_Title-Option_White` | Five plain-English steps + copy-paste code box |
| 15 | Recommended first use | `1.1_Title-Option_White` | 7-step first run + "what good looks like" callouts |
| 16 | Adoption & next steps | `1.1_Title-Option_White` | 4-week rollout phases + closing line |

Every slide has speaker notes with: (1) a short talk track, (2) repo files referenced, and — where applicable — (3) assumptions and (4) missing info / follow-ups.

---

## Repository files used

**Content sources (verbatim):**

- `README.md` — project one-liner (line 3, now updated), five standards table (lines 32–40), templates tree (lines 42–65), how-it-works (lines 86–136), IDE support (lines 138–148).
- `templates/CLAUDE.md` — memory-bank rules (lines 5–20), context compaction (22–31), security tiers (33–62), code quality (64–87), workflow (89–101), logging (103–174), handoff (175–194), Karpathy principles (196–254).
- `templates/memory-bank/*.md` — 6 template files for the memory-bank table on Slide 6.
- `.cursor/rules/security.mdc`, `standards/SECURITY-GUARDRAILS.md` — 3-tier content on Slide 7.
- `standards/CODE-QUALITY.md` + `templates/CLAUDE.md` "Before Claiming Done" — Slide 8.
- `standards/LOGGING.md`, `docs/LOGGING-GUIDE.md`, `README.md` 121–130 — Slide 9.
- `standards/WORKFLOW.md`, `templates/CLAUDE.md` 89–101, `templates/cursor/rules/workflow.mdc` — Slide 10.
- `.claude/commands/code-review.md` Steps 1–3, `.cursor/rules/code-review.mdc` — Slide 11.
- `.claude/commands/code-review.md` Steps 4–6 (lines 76–128), `.cursor/rules/code-review.mdc` — Slide 12.
- `README.md` line 12 (Windows one-liner), `scripts/init-memory-bank.ps1`, `docs/SETUP-GUIDE.md` — Slide 13.
- `README.md` line 21 (Mac one-liner), `scripts/init-memory-bank.sh`, `docs/SETUP-GUIDE.md` — Slide 14.
- `docs/SETUP-GUIDE.md` verification section, `training/exercises/01–02` — Slide 15.
- `CONTRIBUTING.md`, `training/exercises/` — Slide 16.

**Brand inputs:**

- Visual template: `brand/6769772_T-Mobile_Brand-Slide-Template_v27.pptx` — masters, layouts, and theme preserved (6 layouts: 1.1 / 1.2 × Gradient / White / Black).
- T-Mobile Branding MCP — colors (Magenta `#E20074`, Black, White, Dark Gray `#6A6A6A`, Light Gray `#E8E8E8`, Berry `#861B54`), typography (TeleNeo, Arial fallback), voice attributes.
- MCP returned **no PowerPoint-specific brand template**, so the v27 deck was used as the base per the user's instruction hierarchy.

---

## Install commands chosen (verbatim)

**Windows (Slide 13):**
```
irm https://gitlab.com/tmobile/ere/memory-bank/-/raw/master/scripts/init-memory-bank.ps1 | iex
```

**Mac (Slide 14):**
```
curl -sSL https://gitlab.com/tmobile/ere/memory-bank/-/raw/master/scripts/init-memory-bank.sh | bash
```

Both pulled **verbatim** from `README.md` (lines 12 and 21). The reassurance line on both install slides reads: *"You do not need to understand the code. This gives the assistant the instructions it needs."*  The GitLab SSO note reads: *"If prompted to sign in: use your T-Mobile GitLab login."*

Audience-level phrasing follows the user's spec: explain to a non-technical person, five concrete steps, one copy-paste code box per slide.

---

## Documentation updates shipped with this deliverable

To keep docs in sync with the deck, the following files were updated to reflect the current `/code-review` architecture (three role-separated subagents + Test Coverage Review + Opponent Auditor):

- `README.md` — intro paragraph rewritten; `/code-review` added to the claude-commands tree; full multi-agent architecture diagram added to the "How It Works" section.
- `docs/QUICK-REFERENCE.md` — `/code-review` added to the Quick Commands table; a new "/code-review — How It's Structured" section added beneath the Code Quality Checklist.
- `docs/CLAUDE-CODE-PLUGINS.md` — `/code-review` added to the `~/.claude/commands/` tree, to Setup, and to Verification. New "/code-review" section describes all four reviewers (3 parallel + Test Coverage + Auditor).
- `templates/claude-commands/code-review.md` — synced with `.claude/commands/code-review.md` (now includes Subagents A/B/C, Step 4 Test Coverage generation, Step 5 Opponent Check, Auditor verdict column in the summary report).
- `templates/cursor/rules/code-review.mdc` — synced with `.cursor/rules/code-review.mdc` (same structure).
- `GITLAB-DESCRIPTION.md` (new) — paste-ready short description, long description, and topics for the `tmobile/ere/memory-bank` GitLab project settings.

---

## Assumptions (flagged in speaker notes on the relevant slides)

1. **Install scaffolds into the current working directory.** Both `irm | iex` and `curl | bash` run `init-memory-bank` against the working directory, so install slides instruct users to `cd` into the project first. Confirmed by reading `scripts/init-memory-bank.*` and the README's "cd to your project" guidance in `docs/SETUP-GUIDE.md` lines 44–60.
2. **No admin rights are required on Windows.** Neither the README nor the script headers mention elevation. If a locked-down corporate PC blocks `irm | iex`, the speaker notes point users at the README's `git clone` fallback.
3. **GitLab SSO may prompt on first fetch.** Handled with a plain-language note on both install slides.
4. **MCP provided no PowerPoint-specific brand template.** The v27 brand deck is used as the base; the deck inherits its masters/layouts while adding 16 newly-built content slides on top.

---

## Missing information / known gaps

- **No standalone "Testing Guidelines" document exists.** Testing rules are distributed across `templates/CLAUDE.md` (Before Claiming Done + WARN tier + Workflow step 4 + Karpathy goal-driven), `.cursor/rules/code-quality.mdc`, `standards/CODE-QUALITY.md`, `standards/WORKFLOW.md`, and the Python/TypeScript extensions. Slide 12 consolidates the *operational* testing logic inside `/code-review` (Step 4 Test Coverage Review + Step 5 Opponent Auditor). If the org wants a dedicated `standards/TESTING.md`, that is a follow-up.
- **Logo placement.** The deck uses brand-palette accents only; it does not place the T-Mobile wordmark (logo variants were not returned by the MCP and must be sourced from [tmap.t-mobile.com](https://tmap.t-mobile.com) before any external-facing share).
- **Python package note.** `python-pptx 1.0.2` was installed from PyPI using the certifi CA bundle (the `pip config` `global.cert` entry on this machine pointed at a non-existent file; certifi's bundle worked and is the upstream default). If the org policy requires the T-Mobile Enterprise Root CA bundle, restore the correct path in `pip config set global.cert <path>` before re-running the build.

---

## Recommended follow-up edits

1. **Open the deck in PowerPoint** and visually confirm Slide 4 (Black layout) contrast and Slide 10's horizontal process flow render as intended on your display. Adjust font sizes per your projector if needed.
2. **Add logo** to Slide 1 and Slide 16 from the T-Mobile media library once the approved logo file is in `brand/`.
3. **(Optional)** Create `standards/TESTING.md` to consolidate the distributed testing rules and reference it from Slide 12's speaker notes.
4. **Re-run** `python scripts/build_overview_deck.py` any time the repo content drifts — the deck is fully regenerable.
