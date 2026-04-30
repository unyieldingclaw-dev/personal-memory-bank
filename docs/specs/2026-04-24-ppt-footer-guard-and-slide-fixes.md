# PPT footer-overflow guardrail + slide 13 redesign + 4 slide fixes

**Date:** 2026-04-24
**Target file:** `scripts/build_overview_deck.py`
**Output:** `memory-bank-overview.pptx` (23 slides, 13.333 × 7.5 inches)

## Problem

After the previous layout pass, five slides in the overview deck still have content overflowing the footer band:

- **Slide 6** (`build_slide_6_memory_bank`) — flagged by user but math shows current content ends at y=6.65 vs footer at 7.15. Likely fine; verify during rebuild.
- **Slide 10** (`build_slide_accessibility`) — 3×3 "nine dimensions" grid ends at y=7.17, footer at 7.15. Overflows by 0.02".
- **Slide 13** (`build_slide_10_workflow`) — step descriptions end at y=7.20, and they also overlap the bottom callout at y=5.85–6.80. Additionally, the user says the horizontal 7-step flow with tiny step boxes and disconnected descriptions does not communicate the workflow's meaning. Full redesign requested.
- **Slide 18** (`build_slide_make_it_global`) — bottom note at y=6.95 h=0.30 ends at y=7.25. Overflows by 0.10".
- **Slide 23** (`build_slide_resources`) — Support box at y=6.50 h=1.35 ends at y=7.85. Overflows by 0.70".

Root cause: no compile-time or runtime check enforces a safe content bound. Each slide function positions its boxes by hand; drift past y=7.15 has accumulated as slides gained content over versions.

## Goals

1. Fix the 5 overflows so the rebuilt deck visually respects the footer band.
2. Redesign slide 13's content layout so it communicates the 7-phase workflow clearly, matching the user's preferred HTML-style structure (breadcrumb line + "Each phase" / "Skip rule" / "How to trigger" sections).
3. Install a runtime guardrail so future slide edits that overflow the footer fail the build loudly, not silently.

## Non-goals

- Changing brand colors, fonts, title bar, footer band typography.
- Touching untouched slides (1–5, 7–9, 11–12, 14–17, 19–22) beyond what the `_check_bounds` guard would enforce automatically.
- Changing the `BUILDERS` list or slide order.
- Refactoring the `add_code_box` hardcoded 16pt-bold-Consolas choice (out of scope).

## Design

### Part A — Runtime guardrail

Add at module scope, near the existing constants block:

```python
FOOTER_Y = 7.15            # top of the footer band (brand-template constraint)
MAX_CONTENT_Y = 7.10       # 0.05" safety margin; strict upper bound for body content

def _check_bounds(top_in, height_in, kind):
    """Fail loudly if body-region content would overrun the footer."""
    if top_in > 1.5 and top_in + height_in > MAX_CONTENT_Y:
        raise ValueError(
            f"{kind} at y={top_in:.2f}, h={height_in:.2f} ends at "
            f"{top_in + height_in:.2f} — exceeds MAX_CONTENT_Y={MAX_CONTENT_Y}. "
            f"Fix the slide layout instead of raising this bound."
        )
```

Instrument four helpers with a single call each at the top of their bodies (after signature, before any shape creation):

- `add_text` — `_check_bounds(top_in, height_in, "add_text")`
- `add_bullets` — `_check_bounds(top_in, height_in, "add_bullets")`
- `add_rounded_box` — `_check_bounds(top_in, height_in, "add_rounded_box")`
- `add_code_box` — `_check_bounds(top_in, height_in, "add_code_box")`

The `top > 1.5` condition exempts the title/subtitle zone (which sits at y≈0.3 with h≈0.9) from the check. Footer-band rendering (if any) typically happens via a separate helper and will not route through these four.

### Part B — Slide 13 redesign (`build_slide_10_workflow`, lines 693–753)

Replace the entire body with:

**Breadcrumb line** (y=2.10, h=0.50, centered, 16pt bold):
```
Brainstorm  →  Spec  →  Plan  →  Implement (TDD)  →  Simplify  →  Security Review  →  Commit
```
Render "Implement (TDD)" in magenta, the rest white, with the `→` arrows in subdued gray.

**Two-column body** below the breadcrumb:

Left column ("Each phase") at x=0.70, w=6.80, y=2.85:
- Section header "Each phase" (14pt bold magenta) at y=2.85, h=0.35.
- Seven phase rows at y=3.25, each 0.33" tall, 12pt body:
  - **Brainstorm** — explore, propose 2–3 approaches.
  - **Spec** — write validated design to `docs/specs/`.
  - **Plan** — bite-sized plan, exact file paths.
  - **Implement** — TDD: failing test → code → green.
  - **Simplify** — clarity review, no behavior change.
  - **Security Review** — scan for 9 patterns.
  - **Commit** — descriptive message; push.
  - Phase names bold white; em-dash + description in SUB_TEXT.
- Last phase row ends at y = 3.25 + 7×0.33 = 5.56.

Right column ("Skip rule" + "How to trigger") at x=7.60, w=5.10, y=2.85:
- Section header "Skip rule" (14pt bold magenta) at y=2.85, h=0.35.
- "Jump straight to Implement for:" (12pt white) at y=3.25, h=0.30.
- Four bullets at y=3.55, each 0.28" tall, 12pt SUB_TEXT:
  - Single-file fixes
  - Typos
  - Config changes
  - Changes under 20 lines
- Last bullet ends at y=3.55 + 4×0.28 = 4.67.
- Section header "How to trigger" at y=4.95, h=0.35, magenta bold 14pt.
- Two lines at y=5.30 and y=5.60, each 0.28" tall, 12pt:
  - "Claude Code: `/feature-dev` runs the full 7-phase flow."
  - "Cursor: `.cursor/rules/workflow.mdc` enforces it automatically."
- Last line ends at y=5.88.

All content ends by y=5.88 — 1.22" below the MAX_CONTENT_Y guard. Speaker notes (`set_notes`) are preserved verbatim.

### Part C — Four targeted slide fixes

#### Slide 6 (`build_slide_6_memory_bank`, 501–546)

Math shows content ends at y=6.65 with the current callout (already adjusted in the previous pass to y=5.95, h=0.70). **No change planned.** If the rebuild still shows visual overflow, the likely culprit is the 150-char rule text wrapping beyond the text-box height — remediate by shortening the rule text or raising the callout's text-box height then. Verify first; edit only if needed.

#### Slide 10 (`build_slide_accessibility`, 1346–1412)

3×3 grid currently: `top0 = 5.1`, `row_h = 0.65`, row gap 0.06 → row 2 ends at y=7.17.

Edit line ~1393: `row_h = 0.65` → **`0.62`**.
Edit line ~1394: `top0 = 5.1` → **`5.05`**.

Row 2 now ends at 5.05 + 2×(0.62+0.06) + 0.62 = **7.03**. Margin to footer: 0.12".

#### Slide 18 (`build_slide_make_it_global`, 1126–1201)

Bottom note currently: y=6.95, h=0.30, text = ~120 chars → ends at y=7.25.

Edit line ~1190: `add_rounded_box(slide, 0.7, 6.95, SLIDE_W_IN - 1.4, 0.3, ...)` → **y=6.90, h=0.20**.
Edit line ~1192: `add_text(slide, 0.9, 6.98, SLIDE_W_IN - 1.8, 0.25, ...)` → **y=6.93, h=0.15**.
Edit the text content at line ~1193: shorten from
  "Restart Claude Code and Cursor so they pick up the new global rules. See docs/GLOBAL-RULES-SETUP.md for org-wide patterns."
to
  "Restart Claude Code / Cursor to pick up new globals. See `docs/GLOBAL-RULES-SETUP.md`."
(85 chars, fits on one 11pt line).

Note ends at y=7.10. Exactly at MAX_CONTENT_Y; the guard will pass.

#### Slide 23 (`build_slide_resources`, 1292–1343)

Docs list and support box both contribute to overflow.

Edit line ~1310: `row_h = 0.5` → **`0.42`**. With 8 docs starting at top0=2.2, last row ends at 2.2 + 7×0.42 + 0.40 (row text height) = **5.54**.

Edit line ~1319: `support_top = top0 + len(docs) * row_h + 0.3` — formula now yields 2.2 + 8×0.42 + 0.3 = **5.86**.

Edit line ~1320: `add_rounded_box(slide, 0.7, support_top, SLIDE_W_IN - 1.4, 1.35, ...)` → **h=1.15**.

Compress support box internal offsets:
- Line ~1322: `support_top + 0.12` → **+0.08** (label "Support")
- Line ~1325: `support_top + 0.55` → **+0.40** (Teams: label)
- Line ~1327: `support_top + 0.55` → **+0.40** (Teams value)
- Line ~1330: `support_top + 0.9` → **+0.72** (GitLab: label)
- Line ~1332: `support_top + 0.9` → **+0.72** (GitLab value)

Support box ends at 5.86 + 1.15 = **7.01**. Margin 0.09".

## Implementation sequence

1. Write spec (this file) and commit.
2. Add `FOOTER_Y`, `MAX_CONTENT_Y`, `_check_bounds` near top of `scripts/build_overview_deck.py`.
3. Instrument the four `add_*` helpers.
4. Apply fixes to slides 10, 18, 23 (small coord edits).
5. Redesign slide 13 (replace body of `build_slide_10_workflow`).
6. Run `python scripts/build_overview_deck.py`. Expect success; if any existing slide fails the guard, inspect and fix.
7. Open `memory-bank-overview.pptx`, visually verify slides 6, 10, 13, 18, 23.
8. Commit + push (per user's prior authorization for this repo's master branch).

## Verification

- **Build gate:** `python scripts/build_overview_deck.py` exits 0, writes 23 slides. A raised `ValueError` from `_check_bounds` blocks the build and names the offending helper + coords.
- **Visual spot-checks:**
  - Slide 6 — callout text fully within its box, clearly above the footer.
  - Slide 10 — "Nine dimensions" 3×3 grid all 9 tiles visible with margin to the footer.
  - Slide 13 — breadcrumb line on top, "Each phase" 7 rows on left, "Skip rule" + "How to trigger" on right, no overlap; slide reads naturally top-to-bottom and left-to-right.
  - Slide 18 — bottom note single short line, clearly above footer.
  - Slide 23 — all 8 doc rows visible, support box fully on-slide with Teams and GitLab rows readable.
- **Diff sanity:** `git diff scripts/build_overview_deck.py` should show changes in the helpers (one line each), the new constants + function, and the five named slide functions. No changes to `BUILDERS`, imports, other slide functions, or brand constants.
- **Regression safety:** Because the `_check_bounds` guard runs during build, any previously hidden overflow in the 18 untouched slides will raise at build time. If the build fails on an unexpected slide, treat it as a bug to fix in a follow-up commit.
