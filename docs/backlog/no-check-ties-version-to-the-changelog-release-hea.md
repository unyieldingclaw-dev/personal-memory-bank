---
status: open
created: 2026-10-26
last-reviewed: 2026-10-31
staleness-threshold: 90d
related_plan: null
---

# No check ties VERSION to the CHANGELOG release heading

Listed as a follow-up in the body of PR #96 (`2ae44a6`), the 1.3.0 release cut. Two things a
release relies on are checked by hand only:

- **`VERSION` against the newest `## [X.Y.Z]` heading.** Nothing compares them. At `b938b6d`,
  `VERSION` reads `1.3.0` and the newest heading is `## [1.3.0] - 2026-10-25` in
  `docs/archive/changelog-1.3.0.md`, but no test or CI job would notice if either moved alone.
  `scripts/changelog-assemble.sh` writes the heading from its argument, and its header comment says
  "It does not bump VERSION", so a cut can leave the two disagreeing. Since PR #97 the newest heading
  may be in `CHANGELOG.md` (right after a cut) or in a `docs/archive/changelog-*.md` file (after the
  section is archived), so a check has to look in both.
- **A release cut kept every line.** The 1.3.0 cut moved `[Unreleased]` into
  `docs/archive/changelog-1.3.0.md`. PR #96's body says the section moved "with its body unchanged";
  that was checked with a one-off `diff` during its review, not by any test.
  `changelog-assemble.sh` checks only that its new `## [X.Y.Z]` heading reached the output before
  replacing `CHANGELOG.md` (its CRLF guard), not the section body, and nothing checks a later move
  of that section into `docs/archive/`.

A related gap, also listed in PR #97's body: `changelog-assemble.sh` refuses a version that
`CHANGELOG.md` already has (its `already has a [$VERSION] section` guard), but does not look in
`docs/archive/`, so it would cut a version that is already archived.

Fix outline, not designed: a test that reads `VERSION`, takes the highest version (by semver, not
by position) among the `## [X.Y.Z]` headings in `CHANGELOG.md` and `docs/archive/changelog-*.md`,
and fails when the two differ. Headings are not uniform. In `docs/archive/changelog-0.1.0-to-1.2.1.md`
the 1.2.x headings repeat a version and separate the date with ` — ` and a parenthetical, and the
older ones carry no brackets at all (`## 1.2.0 — 2026-06-24`), while `changelog-1.3.0.md` uses
` - `. A `## [X.Y.Z]`-only match skips the unbracketed ones; that is safe while a bracketed heading
outranks them, but say so in the test. Fragments in `changelog.d/` belong to the next release and
do not change `VERSION`, so they open no window.

Open design question: should `changelog-assemble.sh` also bump `VERSION`?
