---
name: mb-drift
description: On-demand semantic drift analysis across all 5 memory-bank files. Use when mb doctor reports structural drift signals, or any time the memory bank may have drifted after a long compaction cycle. Reads files and outputs findings — no edits.
---

# Semantic Drift Analysis

You are running a semantic drift analysis on this project's memory bank. Your job is to find concept-level drift that deterministic checks cannot catch.

## Step 1: Read all 5 memory-bank files

Read each of these files now using the Read tool:
- `memory-bank/projectbrief.md`
- `memory-bank/systemPatterns.md`
- `memory-bank/techContext.md`
- `memory-bank/activeContext.md`
- `memory-bank/progress.md`

If a file is missing, note it in the report and continue with the others.

## Step 2: Reason across the files for three drift types

**Authority hierarchy (highest to lowest):**
`projectbrief.md` (immutable) > `systemPatterns.md` / `techContext.md` (stable) > `activeContext.md` (volatile) > `progress.md` (accumulating)

### A. Duplicate concept drift
The same decision slot (database, auth method, deployment target, tech stack choice, etc.) appears in two or more files but with different conclusions or diverging wording that suggests they have drifted apart over time.

Look for: same subject, different answer. Example: systemPatterns.md says "use Postgres" while techContext.md now says "use Supabase."

### B. Supersession rot
A decision is still phrased as active/current in one file, but a newer, contradicting decision exists elsewhere (a later section of the same file, or a different file with higher or lower authority). The old entry should say "superseded by X" but does not.

Look for: old phrasing like "we will X" or "current approach is X" alongside newer text that replaced X with Y.

### C. Authority violations
A volatile file (`activeContext.md`, `progress.md`) contains a claim that directly contradicts an authoritative file (`projectbrief.md`, `systemPatterns.md`) without explicit acknowledgment. The volatile file should defer to or reference the authoritative file, not silently override it.

Look for: a constraint or decision in projectbrief/systemPatterns that is contradicted outright in activeContext/progress.

## Step 3: Output the findings report

Use exactly this format:

```
## mb-drift findings — YYYY-MM-DD

### Duplicate concept drift
- **[concept name]** — [File A §Section] says "[quote]"; [File B §Section] says "[quote]". Which is current?

### Supersession rot
- **[item]** — [File §Section line N] still phrased as active/current, but [File §Section] contains a newer decision that appears to replace it.

### Authority violations
- **[claim]** — [volatile file §Section] asserts "[quote]" which contradicts [authoritative file §Section] "[quote]".

---
Detection only. Review each finding and update the relevant file to resolve.
```

If no findings in a category, write `- None detected.`

## Rules

- Read files only. Do not call Edit, Write, or any other tool.
- Do not suggest specific edits or rewrite any content.
- Do not invoke other skills or subagents.
- If all three categories are clear, say so — a clean result is a valid and useful result.
