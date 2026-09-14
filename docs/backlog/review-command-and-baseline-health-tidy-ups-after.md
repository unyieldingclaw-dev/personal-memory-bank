---
status: open
created: 2026-09-08
last-reviewed: 2026-09-08
staleness-threshold: 90d
related_plan: null
---

# Review-command and baseline-health tidy-ups after f1ae4ce

Non-blocking defects found during the f1ae4ce review that were deliberately deferred rather than re-reviewed. All four command files are TEMPLATE_OWNED, so live and templates/claude-commands/ mirrors must stay byte-identical. (1) BLANK LINE, user-flagged: .claude/commands/change-review.md line 58/59 has no blank line between the last bullet and the paragraph starting 'Run them with bash scripts/baseline-health.sh'. CommonMark treats that as a lazy continuation, so the key instruction renders inside the Template Integrity bullet. Missed by three domain agents and the opposition reviewer; found on an end-to-end read. (2) Exit-3 docs name only 'renamed or re-indented' and never mention the new ambiguous/duplicate cause, in all four command files. (3) tests/test-baseline-health.sh lines 126-137 hold an orphaned '# 7.' header plus a duplicate ANTI-VACUITY comment sitting before the '# 6.' block; the correctly-placed copy is at 167-177. (4) Same file line 183 says 'test 6' inside what the file labels test 7. (5) Same file line 48 says 'five full repo clones' but there are six call sites now. (6) new_sandbox at lines 50-56 creates the tempdir before it can return the path, so a clone or cp failure leaks it -- register before the fallible ops. (7) Replace the literal 7 in the anti-vacuity floor with bash's own count of the STEPS array, so two independently-derived counts agree instead of one count against a hand-bumped constant. (8) The uniqueness guard only recognises block-style YAML; a flow-mapping duplicate is under-counted and reports a clean PASS -- false assurance, not RCE. THE MECHANISM behind all of this: nothing tests that the checks DETECT. Only 1 of 7 steps has detection-efficacy coverage, which is why an always-passing security check survived indefinitely. Plant a real violation per check and assert it fires.
