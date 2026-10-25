# Portable Brief: Handoff Documents Shouldn't Carry Priority

**For a fresh Claude Code session in a different repo.** This describes a problem found and fixed
in a separate project ("the source repo" below) — read it, then check whether your own repo's
handoff/compaction process has the same shape before assuming it does. Do not import the source
repo's specific file names or memory-bank structure verbatim; the diagnostic in Part 2 and the
principle in Part 3 are the portable parts, not the exact wording used in Part 1.

---

## Part 1: The problem, as observed (not as a template to copy)

The symptom: after a handoff, telling the new session to read the handoff document and report
back "the next set of tasks in priority order" produced answers that missed things — especially
on long, complicated sessions. This was observed happening, not a single isolated incident, which
is what prompted looking past the symptom for a structural cause rather than just patching the
document with more detail.

The root cause wasn't that the handoff document was incomplete. It was structural: the handoff
document was being asked to do two different jobs that have opposite operating conditions.

- **Job A — durable priority and rationale** ("what matters, why, what's next"). This is best
  built incrementally, throughout a session, with time to think about ordering and cross-check it
  against what's already been tried.
- **Job B — ephemeral in-flight state** ("exact line I was editing, uncommitted diff, what I was
  about to test"). This can only be captured at the moment of handoff — there's no earlier
  opportunity — but it doesn't require synthesis or judgment, just a snapshot.

The old design wrote both into the same document, at the same moment: right when a session hits a
context/compaction limit. That's the worst possible moment for Job A — high time pressure, high
token pressure, the exact conditions under which synthesis quality drops — and it's also
completely unnecessary for Job A, since nothing about priority-setting requires waiting until the
handoff moment. Job B, by contrast, genuinely can't be done earlier. Bundling them meant Job A was
consistently done badly, dragged down by being co-located with a task that has a hard deadline.

## Part 2: Diagnostic questions for your own repo

1. **What does your new-session-after-handoff instruction actually ask for?** If it says
   something like "read the handoff doc and tell me what to do next in priority order," that's
   asking a document written under pressure to be the priority source — check whether that's
   actually happening for you, not just in theory.
2. **Do you already have a running, continuously-updated record of current focus and next steps
   somewhere other than the handoff doc** (a project journal, a status file, an active-work
   tracker)? If yes, is it actually being kept current throughout a session, or does it also only
   get written at the end? A durable source of truth that's only updated at handoff time doesn't
   solve the pressure problem — it just relocates it.
3. **Does anything enforce that the durable record stays current**, or is it purely a written
   instruction someone (or some session) can drift away from? A rule that's only advisory decays;
   check whether staleness would actually get caught before a handoff happens on top of it.
4. **Have you separated what's genuinely time-sensitive from what isn't**, in your own handoff
   content? Exact edit position, uncommitted diff state, a process left running in a non-default
   state — these can only be captured at handoff time. Task priority, rationale, what's been tried
   and ruled out — these can be captured any time, and are usually better captured while the
   context is fresh mid-session rather than reconstructed at the end.

## Part 3: The general design principle

**Don't let a document written under deadline pressure be the source of truth for anything that
didn't need to wait for the deadline.** If you have a durable, incrementally-updated record
already (or can build one), that record — not the handoff document — should own priority and
rationale. The handoff document's job shrinks to exactly the state that has no earlier capture
opportunity: in-flight position, uncommitted work, anything left running or half-applied, and
enough of a pointer to resume mechanically.

The new-session instructions should then read the durable record **first**, treat it as
authoritative for priority, read the handoff document **second** as a narrow supplement, and
explicitly **reconcile** the two — surfacing any conflict between them to the user rather than
silently picking one. This reconciliation step matters: it's what catches the case where the
in-flight state doesn't match what the durable record implies should be happening (e.g., the
record says a task is done but the handoff snapshot shows uncommitted work still on it).

One honest caveat worth stating up front if you propose this to your own team: this fix only works
if the durable record is actually kept current. If nothing enforces that (see diagnostic question
3), narrowing the handoff document just shifts the failure mode from "handoff doc is bad under
pressure" to "durable record silently goes stale and nobody notices until a handoff exposes the
gap." Worth checking whether you have (or should add) some check — even a lightweight one — that
catches staleness in the durable record before or during handoff, not just at read time in the new
session.

## Part 4: If you decide to change your own handoff process

- **Don't add richer handoff-document content as the fix.** The instinct is often "the new session
  missed things, so let's put more detail in the handoff doc" — a title, better verbiage, more
  sections. That treats the symptom (missing detail) without fixing the cause (synthesis happening
  under pressure). More content written under the same pressure conditions doesn't reliably fix
  synthesis quality, and it grows the very document that's hardest to get right at that moment.
- **Prefer narrowing the pressured document over enriching it**, if you already have (or can
  build) a durable record that's naturally updated across the session rather than only at its end.
- **State explicitly, in whatever new-session instructions you write, which source is
  authoritative for priority.** Don't leave it implicit — an instruction like "read both and
  figure out what to do" reproduces the original problem in a new shape (the new session doing ad
  hoc synthesis across two documents instead of one).
