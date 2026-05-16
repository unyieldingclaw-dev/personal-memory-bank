# Recovery Guide

What to do when something breaks. Start with `mb doctor` — it diagnoses most issues automatically.

---

## Quick Triage

```
mb doctor     ← run this first, always
mb validate   ← check files and frontmatter specifically
mb status     ← check file sizes
```

---

## Scenario 1: AI Keeps Ignoring Memory Bank

**Symptoms:** AI asks for your tech stack every session, doesn't follow established patterns.

**Diagnose:**
```
mb validate
```

**Fixes, in order:**

1. **CLAUDE.md is missing** — run `mb init`. If it already exists, check the first line says `# Project Instructions for Claude`.

2. **memory-bank/ files are empty or placeholder** — open each file and confirm you've replaced the template text with real project content. A file full of `[Fill in your...]` brackets does nothing.

3. **Context was compacted mid-session** — Claude Code compacts at ~75% context and CLAUDE.md doesn't reload. Tell the AI: *"Re-read all memory-bank/ files to restore context."* Then run `mb status` and consider a `/compact` before your next session.

4. **Cursor: rule not applying** — open `.cursor/rules/memory-bank.mdc` and verify `alwaysApply: true` is in the frontmatter. Restart Cursor.

---

## Scenario 2: `mb` Command Not Found

**Symptoms:** `mb: command not found` or `mb is not recognized`.

**Windows fix:**
```
install.bat        ← re-run from the memory-bank repo
```
Then open a **new** terminal window (PATH changes don't apply to open terminals).

If still not found, verify `%USERPROFILE%\.mb\bin` is in your PATH:
```powershell
$env:PATH -split ';' | Select-String "\.mb"
```

**Mac/Linux fix:**
```bash
source ~/.zshrc     # or source ~/.bashrc
```
If MB_HOME isn't set, re-run `./install.sh` from the memory-bank repo.

---

## Scenario 3: Corrupted or Missing Frontmatter

**Symptoms:** `mb audit` shows `NO FRONTMATTER`, `mb validate` warns about missing fields.

**Fix:** Add the frontmatter block manually to the top of the affected file. Use the template from `templates/memory-bank/<filename>` as reference. Fill in `last-reviewed` with today's date.

```yaml
---
authority: volatile
review-cycle: 7d
retention: archive-after-6m
staleness-threshold: 14d
tags:
  - session/focus
  - session/blockers
  - session/next-steps
last-reviewed: 2026-05-15
---
```

Then run `mb validate` to confirm it's recognized.

---

## Scenario 4: memory-bank/ Files Got Corrupted or Overwritten

**Symptoms:** A file is blank, has wrong content, or was accidentally overwritten.

**Fix:** The files are version-controlled. Restore from git:
```bash
git log memory-bank/activeContext.md          # find last good commit
git checkout <commit-hash> -- memory-bank/activeContext.md
```

If the file was never committed, restore from the template and refill:
```bash
cp /path/to/memory-bank-repo/templates/memory-bank/activeContext.md memory-bank/activeContext.md
```

---

## Scenario 5: Merge Conflict in memory-bank/ Files

**Symptoms:** Git shows conflict markers (`<<<<`, `====`, `>>>>`) inside memory-bank files.

**Fix:** Memory bank files are human-authored content — resolve conflicts manually, the same as any other file. The authority hierarchy helps: when in doubt about which version of a decision is correct, the higher-authority file governs.

1. Open the conflicted file
2. Read both versions
3. Keep the more recent / more specific content
4. Remove conflict markers
5. Run `mb validate` to confirm frontmatter survived intact

---

## Scenario 6: Handoff Was Lost (Session Ended Before Handoff)

**Symptoms:** Context ran out without a `handoff.md` being created. Next session has no continuity.

**Recovery:**
1. Open `progress.md` and `activeContext.md` — they contain enough to reconstruct state
2. At the start of the new session, tell the AI: *"Read memory-bank/ and tell me what you understand about the current state of the project."*
3. Correct anything missing, then continue

For future sessions: run `/compact` at 60% context rather than waiting for auto-compaction at 75%.

---

## Scenario 7: Memory Bank Is Stale After Long Break

**Symptoms:** Returning to a project after weeks/months. `mb audit` shows multiple `[STALE]` files.

**Fix:**
1. Run `mb audit` to see which files are flagged
2. Run `mb compact` to get an AI prompt that rewrites memory to current state
3. After compaction, update `last-reviewed` dates (the hook does this automatically on save, or `mb audit` will reflect the new dates after you've edited the files)
4. Run `mb validate` to confirm health

---

## Scenario 8: `mb commit` Refusing With Worktree Error

**Symptoms:** `[ERROR] You are in a git subworktree.`

**This is intentional.** Memory bank is canonical in the main worktree. Switch to your main worktree branch and commit from there:

```bash
cd /path/to/main/worktree
git add memory-bank/
git commit -m "chore: update memory bank context"
```

---

## Scenario 9: install.bat / install.sh Fails

**Windows — "Access Denied" on setx:**
Run `install.bat` as Administrator (right-click → Run as administrator).

**Windows — mb.bat exists but fails to find mb.ps1:**
`MB_HOME` may point to an old location. Open a new terminal and check:
```powershell
echo $env:MB_HOME
```
If wrong, re-run `install.bat` from the correct repo location.

**Mac/Linux — Permission denied on install.sh:**
```bash
chmod +x install.sh && ./install.sh
```

**Mac/Linux — PATH not updating after install:**
```bash
source ~/.zshrc    # or ~/.bashrc
```

---

## When All Else Fails

1. Run `mb doctor` and share the output
2. Check [UPGRADE.md](UPGRADE.md) to see if a recent change is relevant
3. File an issue with the `mb doctor` output attached
