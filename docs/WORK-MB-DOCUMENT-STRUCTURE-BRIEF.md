# Portable Brief: Document Structure Drift and Safe Reorganization

**For a fresh Claude Code session in a different repo.** This describes a pattern found and
fixed in a separate project ("the source repo" below) — read it, then investigate your own
repo's actual state before assuming any of it applies. Do not import these specific paths,
tool names, or plugin names — they're this repo's own mechanism, not a general prescription.
Your team's tooling is likely different (not everyone uses the same plugins, skills, or
conventions), so the diagnostic questions in Part 2 matter more than the specific finding in
Part 1.

---

## Part 1: What was found (as a worked example, not a template to copy)

The source repo's own process documentation had always correctly specified where specs and
plans should live. But the actual AI-assisted tooling that *creates* specs and plans — a
third-party plugin, unrelated to the repo's own docs — defaulted to a different location, and
nothing in the repo ever reconciled the two. Nobody decided this; it just happened, silently,
over months, because the tool's default and the repo's documented convention were never checked
against each other. By the time it was noticed, dozens of real documents existed in the
undocumented location and none in the documented one.

Separately, and worse: a real, working, *tested* lifecycle system for tracking plan status
(draft → active → done, staleness detection for abandoned work) had been built and shipped —
and then never used, because the actual plan-creation tool was never pointed at it. Two months
of real usage went to a parallel, simpler system with no lifecycle tracking at all, while the
built system sat completely idle.

## Part 2: Diagnostic questions for your own repo (do these before designing anything)

1. **Does your documented convention match where things actually land?** Don't assume — grep
   for your actual specs/plans/design-docs and compare their real locations against whatever
   your CONTRIBUTING.md, workflow doc, or team wiki says. A documented convention that's never
   actually followed is a signal, not a formality to skip past.
2. **Is there tooling you built that nobody's actually using?** Check for any status-tracking,
   promotion, or archival mechanism in your repo's own scripts/commands. If it exists, run its
   test suite (if any) before assuming it's safe to adopt — untested-by-disuse code can bit-rot
   silently. If it passes, that's real signal it's usable, not just theoretically sound.
3. **What's actually different in risk between the kinds of documents you're organizing?**
   A live implementation plan that can be abandoned mid-execution and later resumed against a
   drifted codebase has a real failure mode (stale state, silent incorrectness) that justifies
   real lifecycle tooling. A document that's approved once and then only referenced, never
   resumed, usually doesn't have that same risk — don't build tracking machinery it doesn't need
   just because a sibling document type has one.

## Part 3: Reorganizing without breaking things — the general principle

**Before moving any existing file to fix a location/naming drift, count what references it by
its current path.** Grep your own documentation, status-tracking files, and any persistent
memory/context system for the old paths. If real cross-references exist (and they usually do,
more than expected), moving the files breaks every one of those references for historical
content that has no ongoing need to be "correctly" located — the fix has a real cost and the
benefit is mostly cosmetic for anything already completed.

**The workable pattern found here: freeze history, fix forward only.** Leave existing
misplaced files exactly where they are — don't touch them, don't rewrite their cross-references,
don't feel obligated to make the past consistent. Fix the actual cause (the tool/process that
keeps creating new files in the wrong place) so *only new work* goes to the corrected location
going forward. Optionally, add a short note in the old location marking it as a frozen
historical boundary, so a future reader understands why two locations exist rather than reading
it as unfinished cleanup. This is far cheaper and far safer than a full migration, and it
completely stops the drift from continuing.

**Fix the root cause, not the documentation.** If your own docs already said the right thing and
some other tool's default silently diverged, the fix is bridging that gap (an override,
a config setting, an explicit instruction wherever that tool reads its defaults from) — not
rewriting docs that were already correct.

## Part 4: If you decide something needs building or changing

- **Verify need before building lifecycle machinery.** Don't build a promote/archive/status
  system for a document type just because a sibling type has one — check Part 2, question 3
  first. A simple "approved" marker may already be sufficient for documents with no execution
  state to go stale.
- **Decide deliberately whether a fix is local or should propagate** to any other repos/team
  members sharing your tooling or templates. A genuinely better default is usually worth
  propagating; a personal preference usually isn't. State which one you're doing and why,
  rather than defaulting silently either way.
- **Apply this same investigation discipline to the fix itself before calling it done** — check
  whether your proposed fix actually gets used and actually holds up, the same way you checked
  whether the original convention was actually followed. A fix that looks right on paper and
  never gets adopted has fixed nothing.
