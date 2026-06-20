# Semantic Drift Detection Design

**Date:** 2026-06-19
**Status:** Approved
**Scope:** Personal Memory Bank — concept-level drift detection across the 5 memory-bank files

---

## Problem

`mb doctor` covers file-level integrity (staleness thresholds, checksum mismatches, missing files, hook errors). It does not detect concept-level drift: the same decision appearing in two files with different conclusions, a superseded decision still phrased as current, or a volatile file contradicting an authoritative one. This drift accumulates silently over compaction cycles and manual edits.

## Goals

- Surface drift early, before it misleads a future Claude session
- Detection-first — no auto-remediation
- Overhead proportionate to certainty — deterministic checks are cheap and run always; semantic analysis is expensive and runs on demand
- No new external dependencies; no AI required at runtime for the deterministic layer

## Non-Goals

- Automatic resolution of detected drift
- Detecting drift in non-memory-bank files
- Continuous/background monitoring

---

## Architecture

Two phases, two layers:

| Layer | Trigger | Mechanism | Cost |
|---|---|---|---|
| Phase 1 — Deterministic drift flags | Every `mb doctor` run | String/date analysis, no AI | Free |
| Phase 2 — Semantic drift analysis | On-demand `/mb-drift` skill | Claude reads all 5 files and reasons across them | AI in-session |

The CLI (`mb doctor`) stays deterministic. The AI-backed layer lives as a Claude Code skill so it runs in-session without an external API key or separate process. When Phase 1 flags fire, `mb doctor` appends one advisory line nudging the user to run `/mb-drift`.

---

## Phase 1 — Deterministic Doctor Checks

Three new `[WARN]`-tier checks appended after the existing 20. They do not increment `FAILED` and do not block pushes. All three are implemented in both `scripts/mb.ps1` (PowerShell) and `scripts/mb.sh` (bash), following the existing doctor pattern.

### Check 21 — Git-vs-reviewed lag

**What it detects:** A memory-bank file was modified (committed) after its `last-reviewed:` frontmatter date, meaning content changed but the review date was not updated.

**Implementation:**
1. For each of the 5 memory-bank files, extract `last-reviewed:` from frontmatter (YAML `last-reviewed: YYYY-MM-DD`)
2. Get the file's last git commit date: `git log -1 --format="%as" -- memory-bank/<file>`
3. If commit date > last-reviewed date, emit `[WARN]`

**Output:**
```
[WARN] Drift: systemPatterns.md last-reviewed 2026-05-14, last commit 2026-06-18
       Update last-reviewed frontmatter or confirm no review needed.
```

**False positive rate:** Low. A genuine mismatch means someone edited and committed the file without updating the review date. The one legitimate case (a commit that only changes formatting) is acceptable noise.

### Check 22 — Completed-but-still-planned

**What it detects:** An item marked ✅ (done) in `progress.md` is still listed as ⏸ (planned/deferred) in another file — classic supersession rot.

**Implementation:**
1. Extract ✅-prefixed lines from `progress.md`
2. Extract ⏸-prefixed lines from all 5 files
3. For each ✅ line, normalize (strip leading emoji and list markers, lowercase, collapse whitespace), check if any ⏸ line contains the same normalized substring of ≥4 consecutive whitespace-delimited tokens
4. Flag matching pairs with file and line reference

**Output:**
```
[WARN] Drift: "mb doctor staleness" marked ✅ in progress.md but ⏸ in activeContext.md (line 41)
       One of these is stale — resolve before next compaction.
```

**False positive rate:** Medium. Short phrases may match incidentally. The 4-word minimum reduces noise.

### Check 23 — Stale next step

**What it detects:** A bullet in `activeContext.md`'s Next Steps section references something already marked ✅ in `progress.md`.

**Implementation:**
1. Extract lines from the `## Next Steps` section of `activeContext.md`
2. Normalize each line (strip leading `- `, lowercase, trim)
3. Check against normalized ✅ lines from `progress.md`
4. Flag matches

**Output:**
```
[WARN] Drift: Next Step "semantic identity" (activeContext.md) appears completed in progress.md
       Remove from Next Steps or verify the completion entry is accurate.
```

**False positive rate:** Low-medium. Next Steps entries and progress entries are usually distinct enough in length that accidental matches are rare.

### Advisory nudge

When any of checks 21–23 fire, append one line at the bottom of `mb doctor` output (after the PASS/BLOCKED summary):

```
       Structural drift signals detected — run /mb-drift for semantic analysis.
```

This line is omitted when all three checks pass cleanly.

---

## Phase 2 — `/mb-drift` Skill

A new Claude Code skill at `.claude/skills/mb-drift.md`.

### Trigger

User invokes `/mb-drift` manually — typically after `mb doctor` reports structural drift signals, or when they suspect the memory bank has drifted after a long compaction cycle.

### Behavior

The skill instructs Claude to:

1. Read all 5 memory-bank files using the Read tool
2. Reason across them for three categories of drift (see below)
3. Output a structured findings report
4. Stop — no edits, no tool calls beyond Read

If a file is missing, the skill notes it and continues with the remaining files.

### Detection categories

**Duplicate concept drift**
The same decision slot appears in two or more files with different conclusions or diverging wording. Signals: same subject (database choice, auth method, deployment target) but different answers across files.

**Supersession rot**
A decision is still phrased as active/current in one file, but a newer contradicting decision exists elsewhere (or in a later section of the same file). The old entry should be marked superseded but isn't.

**Authority violation**
A volatile file (`activeContext.md`, `progress.md`) contains a claim that directly contradicts an authoritative file (`projectbrief.md`, `systemPatterns.md`) without explicit acknowledgment. The authority hierarchy is: `projectbrief` > `systemPatterns`/`techContext` > `activeContext` > `progress`.

### Output format

```
## mb-drift findings — YYYY-MM-DD

### Duplicate concept drift
- **[concept name]** — [file A §section] says "[quote]"; [file B §section] says "[quote]".
  Which is current?

### Supersession rot
- **[item]** — [file §section line N] still phrased as active, but [file §section]
  contains a newer decision that appears to replace it.

### Authority violations
- **[claim]** — [volatile file §section] asserts "[quote]" which contradicts
  [authoritative file §section] "[quote]".

---
Detection only. Review each finding and update the relevant file to resolve.
```

If no findings in a category, output `- None detected.`

### Scope boundary

The skill reads files and outputs findings. It does not:
- Suggest specific edits
- Call Edit or Write
- Invoke other skills or subagents
- Persist findings anywhere (the user decides what to act on)

---

## Implementation Order

1. **Phase 1 first** — add checks 21–23 to `mb doctor` in both `mb.ps1` and `mb.sh`, plus the advisory nudge. Update `mb doctor` count in `docs/QUICK-REFERENCE.md` (20 → 23).
2. **Phase 2 second** — write `.claude/skills/mb-drift.md`. Update `QUICK-REFERENCE.md` to list the new skill. Update `memory-bank/progress.md` to move these items from Backlog to Completed.

No changes to templates for Phase 1 (doctor checks are in the mb CLI scripts, not in TEMPLATE_OWNED files). The skill file (Phase 2) is project-local and not distributed via `mb upgrade`.

---

## Success Criteria

- `mb doctor` reports check 21/22/23 results alongside existing checks
- A repo with a known stale `last-reviewed` date triggers Check 21
- A repo with a ✅/⏸ mismatch triggers Check 22 or 23
- `/mb-drift` skill runs to completion on a clean memory bank and reports "None detected" in all three categories
- `/mb-drift` skill on a deliberately drifted memory bank surfaces at least one finding per category
