# CHANGELOG archive — `[Unreleased]` › `### Documentation`, entries of 2026-08-27

Moved verbatim out of `CHANGELOG.md` on 2026-10-25, because that file sat at exactly its 800-line
cap (`.github/workflows/pmb-health.yml`'s File Size job fails any markdown file above 800 lines) and
a new Fixed entry needed room. This was the oldest whole block in `[Unreleased]`: every line of it
dates from one commit, `d795abb` (2026-08-27).

**These entries are UNRELEASED.** Unlike `changelog-0.1.0-to-1.2.1.md`, nothing here belongs to a
tagged version. A pointer stays under `[Unreleased]` in `CHANGELOG.md`, so whoever cuts the next
release carries them into its notes.

### Documentation
- **Recorded a cross-project provenance gap.** The ACR session holds a memory-bank entry attributing
  a specific `ai-review-agent` timeout measurement (a 616 s agent runtime against a 282,240 ms
  ceiling) to a brief from this project. That measurement exists nowhere in PMB — not in
  `memory-bank/`, `docs/`, `docs/archive/`, or the ACR brief in the operator's Downloads. It was
  reported back as unsourced rather than reconstructed from the formula, and ACR was advised to
  re-derive it with instrumentation rather than treat it as evidence.
- `memory-bank/activeContext.md` stated `progress.md` was at "599/60,000 — ZERO bytes of headroom,
  deadlock is live". The file was well under both caps by then; the claim was stale from the
  moment the relocation landed, in the same branch that left the paragraph unedited. No
  replacement byte count is recorded here — two attempts to pin one went stale inside this very
  branch, so the number is left to `wc -c` and the CI caps. Its `mb.sh:831` /
  `mb.ps1:1090` citations were also simply wrong (`mb.sh:409,410,967`, `mb.ps1:1189`).
- `memory-bank/progress.md` recorded the relocation as taking the file to a specific byte count.
  Two successive attempts to state that number (40,063, then 46,956) were each already stale when
  written, because entries kept being appended after the measurement. No byte count is recorded in
  any of the three files any more — the relocation's effect is stated as bytes REMOVED (20,953),
  which does not decay, and current size is left to `wc -c` and the CI caps.
- New `[NS-42]` (write-rate control — eviction is symptom relief; the file grew +24,355 bytes in
  three days and `docs/archive/` already holds 149,711 relocated bytes) and `[NS-43]` (the review
  gate structurally forbids commit-splitting, and its purely textual matcher denies any command
  that merely mentions a guarded pattern).
- Agent definitions now carry a scope caveat: their `Bash(...)` entries declare intent and were
  observed not to constrain Bash in practice, so they must not be relied on as a security boundary.
