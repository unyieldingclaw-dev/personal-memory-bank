# Comment Provenance & Dead Code Authority Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Extend `standards/CODE-QUALITY.md` with rationale provenance rules and a dead-code authority model, and anchor both in `CLAUDE.md` and `templates/CLAUDE.md`.

**Architecture:** Three purely documentary changes to existing markdown files. Section 2 of `CODE-QUALITY.md` gains three new table rows and an AI callout blockquote; a new Section 7 is inserted before the "Language Extensions" heading; both `CLAUDE.md` files gain a 3-line behavioral anchor after the "Follow patterns..." line.

**Tech Stack:** Markdown, Git (Edit tool for all changes — no new files)

---

## File Map

| File | Change | Insertion point |
|------|--------|-----------------|
| `standards/CODE-QUALITY.md` | 3 new rows in Section 2 table | After `\| Document breaking changes \|` row (line 47) |
| `standards/CODE-QUALITY.md` | AI callout blockquote | After Python example closing ` ``` ` (line 59), before `### 3. Structure` |
| `standards/CODE-QUALITY.md` | New Section 7 | After Section 6 last row (line 121), before `## Language Extensions` (line 123) |
| `CLAUDE.md` | 3-line anchor | After "Follow patterns in `standards/CODE-QUALITY.md`..." (line 85), before Accessibility line (line 86) |
| `templates/CLAUDE.md` | Same 3-line anchor | Same relative position |

---

### Task 1: Create feature branch

**Files:** none

- [ ] **Step 1: Verify current branch and create feature branch**

```bash
cd "C:\Users\Mizzo\Claude\Personal-Memory-Bank"
git checkout main
git pull
git checkout -b feat/comment-provenance
```

Expected output: `Switched to a new branch 'feat/comment-provenance'`

---

### Task 2: Add 3 new rows to Section 2 table in CODE-QUALITY.md

**Files:**
- Modify: `standards/CODE-QUALITY.md` (Section 2 table, around line 47)

The current table has 4 rows ending with `| Document breaking changes | ...`. Insert 3 new rows immediately after it, keeping them inside the table (no blank line between them).

- [ ] **Step 1: Read the file to locate exact text**

Read `standards/CODE-QUALITY.md` lines 42–50 to confirm the exact last row text before editing.

- [ ] **Step 2: Insert the 3 new rows using the Edit tool**

Find this exact string (the last row of the Section 2 table):

    | Document breaking changes | ✅ `// BREAKING: Changed from sync to async` |

Replace with:

    | Document breaking changes | ✅ `// BREAKING: Changed from sync to async` |
    | Rationale must trace to observable behavior, documented constraint, or explicit project guidance | ❌ `// Using Set here for significant performance gains` ✅ `// Set prevents duplicate hook registration — settings loader may merge repeated entries on reload` |
    | No speculative performance or optimization claims | ❌ `// Parallelized for performance` ✅ `// Parallelized because the upstream API enforces a 5s per-call timeout; sequential execution exceeds dashboard SLA` |
    | Do not document rationale you cannot support with observable behavior, documented constraints, or explicit project guidance — this covers historical intent, optimization claims, and architectural explanations equally | ❌ `// Legacy compatibility` (unsupported — no linked ticket, no observable constraint) ✅ [omit the comment rather than invent a reason] |

- [ ] **Step 3: Verify**

Read `standards/CODE-QUALITY.md` lines 42–62. Confirm the table now has 7 rows, the 3 new rows appear after "Document breaking changes", and the Python example follows with no extra blank lines inserted.

---

### Task 3: Add AI callout blockquote to Section 2 of CODE-QUALITY.md

**Files:**
- Modify: `standards/CODE-QUALITY.md` (after Python example block, before `### 3. Structure`)

- [ ] **Step 1: Insert the AI callout using the Edit tool**

Find this exact string (the last line of the Python example and the blank line + next heading):

    for user in users:
        process(user)
    ```
    
    ### 3. Structure

Replace with:

    for user in users:
        process(user)
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
    
    ### 3. Structure

- [ ] **Step 2: Verify**

Read `standards/CODE-QUALITY.md` lines 55–80. Confirm the blockquote appears between the closing ` ``` ` of the Python example and `### 3. Structure`, with a blank line on each side.

- [ ] **Step 3: Commit Task 2 + Task 3 together**

```bash
git add standards/CODE-QUALITY.md
git commit -m "feat: add comment provenance rules and AI callout to CODE-QUALITY.md Section 2

- 3 new table rows: rationale traceability, no speculative perf claims, no invented intent
- AI callout blockquote: absence of rationale > speculative rationale

Co-Authored-By: Claude Sonnet 4.6 <noreply@anthropic.com>"
```

---

### Task 4: Add Section 7 (Dead Code & Cleanup Authority) to CODE-QUALITY.md

**Files:**
- Modify: `standards/CODE-QUALITY.md` (insert Section 7 before `## Language Extensions`)

- [ ] **Step 1: Read the file to locate the insertion point**

Read `standards/CODE-QUALITY.md` lines 115–130. Confirm Section 6's last table row ends at line 121, line 122 is blank, and line 123 is `## Language Extensions`.

- [ ] **Step 2: Insert Section 7 using the Edit tool**

Find this exact string:

    | Group related code | Avoid single-function files |
    
    ## Language Extensions

Replace with:

    | Group related code | Avoid single-function files |
    
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
    
    ## Language Extensions

- [ ] **Step 3: Verify**

Read `standards/CODE-QUALITY.md` lines 115–175. Confirm:
- Section 7 heading appears after Section 6's last table row
- The authority table has exactly 2 data rows (Observe, Remove)
- The `## Language Extensions` heading immediately follows the "What this is not" paragraph
- No Section 7 numbering appears in the existing sections (Sections 1–6 use `###`, not `##`, so there is no numbering conflict — double-check the actual heading level in context)

> **Note on heading levels:** The existing sections (`### 1. Verification`, `### 2. Comments`, etc.) use `###`. Section 7 should also use `###` to be consistent. If the find string shows Section 6 is `### 6. File Management`, change `### 7.` accordingly.

- [ ] **Step 4: Commit**

```bash
git add standards/CODE-QUALITY.md
git commit -m "feat: add Section 7 Dead Code & Cleanup Authority to CODE-QUALITY.md

Observation vs deletion are separate authority levels. Lack of observed
execution is not deterministic proof of non-use. Infra/scripting/governance
code defaults to observe-only.

Co-Authored-By: Claude Sonnet 4.6 <noreply@anthropic.com>"
```

---

### Task 5: Add 3-line anchor to CLAUDE.md

**Files:**
- Modify: `CLAUDE.md` (Code Quality section, around line 85–86)

- [ ] **Step 1: Read the file to locate the Code Quality section**

Read `CLAUDE.md` lines 83–88. Confirm the section looks like:

    ## Code Quality
    
    Follow patterns in `standards/CODE-QUALITY.md`. Language-specific extensions in `standards/extensions/`.
    Accessibility (UI code — HTML/JSX/TSX/Vue/Svelte): apply WCAG 2.1 AA basics. See `standards/ACCESSIBILITY.md`.

- [ ] **Step 2: Insert the 3-line anchor using the Edit tool**

Find this exact string:

    Follow patterns in `standards/CODE-QUALITY.md`. Language-specific extensions in `standards/extensions/`.
    Accessibility (UI code — HTML/JSX/TSX/Vue/Svelte): apply WCAG 2.1 AA basics. See `standards/ACCESSIBILITY.md`.

Replace with:

    Follow patterns in `standards/CODE-QUALITY.md`. Language-specific extensions in `standards/extensions/`.
    Comment the WHY, not the WHAT.
    Do not invent rationale, optimization claims, or historical intent not supported by observable behavior, documentation, or explicit project guidance.
    Treat dead-code identification as advisory unless non-use can be proven deterministically.
    Accessibility (UI code — HTML/JSX/TSX/Vue/Svelte): apply WCAG 2.1 AA basics. See `standards/ACCESSIBILITY.md`.

- [ ] **Step 3: Verify**

Read `CLAUDE.md` lines 83–92. Confirm:
- The 3-line anchor appears between the "Follow patterns" line and the Accessibility line
- No blank lines were introduced between the lines (they should be adjacent, no blank line separator)
- The anchor is exactly 3 lines

- [ ] **Step 4: Commit**

```bash
git add CLAUDE.md
git commit -m "feat: add comment provenance anchor to CLAUDE.md Code Quality section

3-line behavioral anchor: WHY comment discipline, no invented rationale,
dead-code identification is advisory only.

Co-Authored-By: Claude Sonnet 4.6 <noreply@anthropic.com>"
```

---

### Task 6: Add 3-line anchor to templates/CLAUDE.md

**Files:**
- Modify: `templates/CLAUDE.md` (Code Quality section — same anchor, same position)

- [ ] **Step 1: Read the file to locate the Code Quality section**

Read `templates/CLAUDE.md`. Find the Code Quality section — it should contain a "Follow patterns in `standards/CODE-QUALITY.md`..." line followed by an Accessibility line.

- [ ] **Step 2: Insert the 3-line anchor using the Edit tool**

The edit is identical to Task 5. Find:

    Follow patterns in `standards/CODE-QUALITY.md`. Language-specific extensions in `standards/extensions/`.
    Accessibility (UI code — HTML/JSX/TSX/Vue/Svelte): apply WCAG 2.1 AA basics. See `standards/ACCESSIBILITY.md`.

Replace with:

    Follow patterns in `standards/CODE-QUALITY.md`. Language-specific extensions in `standards/extensions/`.
    Comment the WHY, not the WHAT.
    Do not invent rationale, optimization claims, or historical intent not supported by observable behavior, documentation, or explicit project guidance.
    Treat dead-code identification as advisory unless non-use can be proven deterministically.
    Accessibility (UI code — HTML/JSX/TSX/Vue/Svelte): apply WCAG 2.1 AA basics. See `standards/ACCESSIBILITY.md`.

> If `templates/CLAUDE.md` has a slightly different "Follow patterns" line (e.g., different whitespace or line ending), match the actual text exactly. The 3-line anchor content is identical regardless.

- [ ] **Step 3: Verify**

Read `templates/CLAUDE.md` around the Code Quality section. Confirm the 3-line anchor is present, exactly matching the anchor in `CLAUDE.md`.

- [ ] **Step 4: Commit**

```bash
git add templates/CLAUDE.md
git commit -m "feat: sync comment provenance anchor to templates/CLAUDE.md

Keeps portable governance substrate in sync with repo CLAUDE.md.
Anchor applies to any project that adopts this template via mb init.

Co-Authored-By: Claude Sonnet 4.6 <noreply@anthropic.com>"
```

---

## Verification (end-to-end)

After all tasks are committed, run these checks:

```bash
# 1. Confirm branch and commit count
git log --oneline feat/comment-provenance ^main

# Expected: 4 commits
# - docs: add comment provenance and dead code authority spec
# - docs: refine comment provenance spec per review feedback
# - feat: add comment provenance rules and AI callout to CODE-QUALITY.md Section 2
# - feat: add Section 7 Dead Code & Cleanup Authority to CODE-QUALITY.md
# - feat: add comment provenance anchor to CLAUDE.md Code Quality section
# - feat: sync comment provenance anchor to templates/CLAUDE.md

# 2. Confirm Section 7 heading level matches Sections 1-6
grep "^### [0-9]\." standards/CODE-QUALITY.md

# Expected: ### 1. Verification through ### 7. Dead Code & Cleanup Authority

# 3. Confirm CLAUDE.md anchor is exactly 3 lines (not 2, not 4)
grep -A5 "Follow patterns in" CLAUDE.md | head -6

# Expected: "Follow patterns..." line, then 3 anchor lines, then Accessibility line

# 4. Confirm templates/CLAUDE.md matches
diff <(grep -A5 "Follow patterns in" CLAUDE.md) <(grep -A5 "Follow patterns in" templates/CLAUDE.md)

# Expected: no diff (anchor identical in both files)
```

---

## Success Criteria (from spec)

1. A code quality reviewer reading `standards/CODE-QUALITY.md` will flag invented rationale as a violation ✓
2. A code quality reviewer reading `CLAUDE.md` will classify autonomous dead-code deletion as requiring human confirmation ✓
3. Section 7 is self-contained — readable without needing to understand AI failure-mode context ✓
4. No existing rules removed or contradicted ✓
5. `CLAUDE.md` anchor is exactly 3 lines ✓
