# Comment Provenance & Dead Code Authority — Design Spec

**Status:** Approved  
**Date:** 2026-05-24  
**Scope:** `standards/CODE-QUALITY.md` (Section 2 additions + new Section 7) and `CLAUDE.md` (3-line anchor)

---

## Problem

This repo already has a healthy WHY comment culture. The problem is not a missing comment philosophy — it's two AI-specific failure modes that the current standard doesn't constrain:

1. **Rationale fabrication.** AI systems generate plausible-sounding rationale without traceable provenance. Invented optimization claims, speculative architectural history, and authoritative-sounding fiction end up as comments that degrade over time and mislead readers.

2. **Overconfident dead-code deletion.** AI systems cannot deterministically prove non-use. Shell fallbacks, platform branches, hook scripts, and CI conditions are all examples of code that appears unused during static or local analysis but is load-bearing in runtime contexts. The current standard has no guard against this.

These failure modes are amplified in AI-assisted development: a human developer who writes "// O(1) lookup for performance" at least *observed* that performance was a concern. An AI writing the same comment may be pattern-matching on code structure rather than reporting an observed fact.

The fix is narrow: extend the comment standard with provenance requirements, add an explicit dead-code authority model, and anchor both in `CLAUDE.md`.

---

## Approach

**Hybrid framing** — not an AI-only callout, not a purely generic rule. Write universal engineering standards that happen to call out the specific ways AI systems fail at them. This framing:
- Applies to human and AI authors alike (no double standard)
- Makes the rationale for each rule explicit (avoids "why does this rule exist?" drift)
- Keeps the spec philosophically coherent with the existing standard

---

## Section 1: Changes to `standards/CODE-QUALITY.md`

### 1a. Section 2 (Comments) — three new table rows

Insert after the existing `| Document breaking changes | ✅ \`// BREAKING: Changed from sync to async\` |` row:

| Rule | Example |
|------|---------|
| Rationale must trace to observable behavior, documented constraint, or explicit project guidance | ❌ `// Using Set here for significant performance gains` ✅ `// Set prevents duplicate hook registration — settings loader may merge repeated entries on reload` |
| No speculative performance or optimization claims | ❌ `// Parallelized for performance` ✅ `// Parallelized because the upstream API enforces a 5s per-call timeout; sequential execution exceeds dashboard SLA` |
| Do not document rationale you cannot support with observable behavior, documented constraints, or explicit project guidance — this covers historical intent, optimization claims, and architectural explanations equally | ❌ `// Legacy compatibility` (unsupported — no linked ticket, no observable constraint) ✅ [omit the comment rather than invent a reason] |

### 1b. Section 2 — AI callout note (insert after the Python good/bad example block)

```
> **AI-assisted development amplifies the risk of plausible but unsupported rationale** —
> invented optimization claims, speculative architectural history, and authoritative-sounding
> fiction. These provenance standards apply regardless of whether a change is authored by
> a human or an AI system.
>
> **Absence of rationale is preferable to speculative rationale.** When the reason is not
> traceable to observable behavior, documentation, or explicit project guidance, the comment
> should not exist. Most AI-generated technical debt now comes from plausible explanatory
> fiction, not missing comments.
```

### 1c. New Section 7 — Dead Code & Cleanup Authority

Insert as a new top-level section after Section 6 (File Management) and before the "Language Extensions" heading.

**Full text of Section 7:**

---

### 7. Dead Code & Cleanup Authority

**Identifying dead code and removing it are separate authority levels.**

| Authority | When allowed | Required evidence |
|-----------|-------------|-------------------|
| **Observe** | Always | State why it appears unused and what references were checked |
| **Remove** | Only with deterministic proof or explicit human confirmation | Proof that no execution path reaches it (static analysis + runtime + all platform branches) |

**The key constraint:** Lack of observed execution is not deterministic proof of non-use.

Code that appears unused during local analysis may be:
- A shell fallback for an alternate platform or runtime
- A CI-only branch activated by an env variable
- A hook script referenced by external config
- An extension point loaded dynamically by convention
- A compatibility shim that activates only on certain OS versions

**Default posture for infra, scripting, and governance code:** Observe-only. Shell scripts, platform branches, CI conditions, and hook scripts carry the highest risk of false dead-code detection. Do not remove without a human confirmation that the code path is truly unreachable.

**Observation format:** When flagging suspected dead code, state:
1. Why it appears unused (what signals suggest it's dead)
2. What references were checked (grep, call-site analysis, CI config, hook config)
3. Confidence level and the specific contexts that would need to be verified to be certain

**Example:**

```
# Suspected dead code: install_legacy_wrapper() — no call sites found via grep,
# not referenced in mb.sh invoke_* dispatch table.
# NOT removed: didn't check init-memory-bank.sh wrapper scripts or external CI callers.
# Recommend: human confirms before deletion.
```

**What this is not:** This section does not prohibit refactoring or cleanup. It constrains *autonomous deletion of code whose reachability cannot be proven*. Cleanup with human confirmation, cleanup of code the implementer just wrote, and cleanup where the full call graph is known — all fine.

---

## Section 2: Changes to `CLAUDE.md`

Add to the `## Code Quality` section (which currently points to `standards/CODE-QUALITY.md`). Insert after the existing line "Follow patterns in `standards/CODE-QUALITY.md`...":

```
Comment the WHY, not the WHAT.
Do not invent rationale, optimization claims, or historical intent not supported by observable behavior, documentation, or explicit project guidance.
Treat dead-code identification as advisory unless non-use can be proven deterministically.
```

These three lines are the behavioral anchor. They must be exactly 3 lines — no expansion. The full policy is in `CODE-QUALITY.md`; CLAUDE.md carries only the compact operating rule.

---

## Files Changed

| File | Change |
|------|--------|
| `standards/CODE-QUALITY.md` | Add 3 rows to Section 2 table, add AI callout blockquote, add Section 7 |
| `CLAUDE.md` | Add 3-line anchor after existing Code Quality pointer |
| `templates/CLAUDE.md` | Same 3-line anchor (keeps template in sync) |

**Note on `templates/CLAUDE.md`:** The template is the adoptable surface distributed by `mb init`. It should stay in sync with this repo's `CLAUDE.md`. The 3-line anchor is generic enough to apply to any adopted project. Sync discipline: `templates/CLAUDE.md` should remain structurally minimal — not a forked variant. When this repo's `CLAUDE.md` gains new behavioral anchors that belong to the portable governance substrate, they go into `templates/CLAUDE.md` as well. Repo-specific tooling details (mb CLI usage, workflow phases, etc.) do not.

---

## Success Criteria

1. After implementation, a code quality reviewer agent that reads `standards/CODE-QUALITY.md` will flag invented rationale as a violation
2. After implementation, a code quality reviewer reading `CLAUDE.md` will classify autonomous dead-code deletion as requiring human confirmation
3. The new Section 7 text is self-contained — a developer can read it without needing to understand the AI failure-mode context to know what to do
4. No existing rules are removed or contradicted
5. `CLAUDE.md` anchor remains exactly 3 lines

---

## What This Is Not

- **Not a prohibition on WHY comments.** The existing culture is healthy — this adds provenance constraints, not replacements. Keep commenting on failure modes, integration quirks, and ordering rationale.

- **Not an AI-only rule.** Provenance discipline applies to all authors. Humans also fabricate rationale; AI systems do it more fluently and at higher volume.

- **Not a ban on cleanup.** Duplicate reduction, simplification, dead-code identification, and refactoring are all encouraged — when evidence-bounded (you know what you're removing) and authority-bounded (you own that decision or have confirmation). Section 7 constrains *autonomous deletion of code whose reachability cannot be proven*, not cleanup generally.

- **Not a requirement to explain obvious code.** Section 2 already says "no obvious comments." That rule remains. "Comment the WHY" means comment on non-obvious reasoning — not every line needs a rationale.

- **Not a prohibition on performance work.** The standard bans *unsupported* optimization claims, not optimization itself. "Parallelized because the upstream API enforces a 5s per-call timeout" is fully supported. "Parallelized for performance" is not.

- **Not a general refactoring policy.** Section 7 does not govern human-led cleanup sessions where the developer has read the full codebase. It governs autonomous AI-initiated deletion where the reachability question is open.
