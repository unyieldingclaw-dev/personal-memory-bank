# Memory & Instruction File Paradigm — Portable Brief

**Read this if:** you're a Claude Code session working in a Work-MB-style deployment — a governed
project whose purpose is to hold *non-specialist* authors to a standard — and someone has pointed
you here because the origin repo (PMB) just reviewed how its memory and instruction files should be
written and maintained.

**Do not copy the origin repo's conclusions.** They were reached for a personal standard used by one
expert operator on one machine. Your deployment inverts the two variables that mattered most: who is
at the keyboard, and whether the standard is optional. Three of the four decisions change as a
result. What is portable is the *reasoning* and the primary sources — investigate your own
deployment before adopting anything below.

**Why this exists before the redesign rather than after:** if the origin repo restructures first and
you inherit, personal-use assumptions get baked into a team product and surface months later. That
failure has already occurred once in this fleet — a downstream repo ran two versions behind and
completed a full feature under stale governance hooks before anyone noticed, and a `WARN` from
`mb doctor` was not enough to stop it. Your constraints belong in the redesign as inputs.

---

## Part 1: The two variables that flip the conclusions

**Variable one — the author cannot audit the outcome.** An expert notices when context is missing
and goes and fetches it. A non-specialist does not, because they have no model of what should have
been loaded. Every conclusion about moving content out of the always-loaded set has to be re-derived
under that assumption.

**Variable two — the standard is imposed, not chosen.** The origin repo's operator wants the rules
to hold. Your users are subject to them. That difference means advisory prose does more work in the
origin repo than it will ever do in yours, and it means an enforcement layer exists for you that the
origin repo has no reason to touch.

## Part 2: What changes

### The always-load requirement should relax *less*, not more

The origin repo is moving from "all memory files loaded in full at session start" to "an index is
loaded, detail is fetched on demand." That is safe for an expert.

The strongest objection to on-demand loading is that **a file which is not loaded has 0% adherence**
— and that objection lands much harder on your side, because nobody at the keyboard will notice the
gap. Investigate whether your always-loaded index should carry the actual rules rather than pointers
to them, moving only genuinely archival history out of context. The origin repo's ratio is not
your ratio.

### The tiering pattern is externally corroborated — which does not change the advice above

Two external context systems were surveyed at README level on 2026-08-24. **OpenViking** loads in
three tiers (~100-token abstract, ~2k-token overview, full detail on demand) and reports large token
savings from that alone. **Lumina** splits memory into never-expiring identity/structural layers plus
a decaying session layer. Set against the origin repo's own authority order, all three describe the
same shape.

**Read this as corroboration of the pattern, not as pressure to relax your always-load requirement.**
The argument above still holds and is the more important one for you: a file that is not loaded has
0% adherence, and your users will not notice the gap. What the convergence supports is that *when*
you tier, the split should be abstract-versus-detail rather than important-versus-unimportant — the
index carries what must always apply, and only genuinely archival material moves out of context.

Lumina contributes one rule worth stealing outright, and it is a governance rule rather than a
storage one: **nothing is promoted into the permanent layers automatically, ever.** For a team
deployment where standards are the permanent layer, an automatic-promotion path is how an unreviewed
session note becomes a standard nobody agreed to.

Neither system is adoptable as software — both are runtime applications, and OpenViking's core is
AGPLv3, which is disqualifying for anything vendored into a template that ships to other teams.

### Entry-lifecycle machinery is lower priority

The origin repo's growth problem comes from a prolific operator generating dense session history at
a rate that filled a 400-line cap in nine days. Your files hold standards, which change slowly. The
delta-update and pruning work that dominates the origin repo's roadmap is unlikely to be where your
budget belongs. Measure your own accumulation rate before assuming otherwise.

### There is an enforcement layer the origin repo does not use

Claude Code supports an organization-wide `CLAUDE.md` at a managed policy path, or inline via the
`claudeMd` key in `managed-settings.json`. It loads before user and project instructions and
**cannot be excluded by individual settings**. Alongside it, `permissions.deny` in managed settings
blocks specific tools, commands, and file paths outright, enforced by the client regardless of what
Claude decides.

This is a closer match to "force a set of standards" than anything in the origin repo's design,
which uses none of it — a personal standard has nobody to enforce against. Investigate whether it
should be the *spine* of your deployment rather than an addition to it.

**Investigate first:** it requires Group Policy or MDM access. If that is not obtainable in your
organization, this entire branch collapses back to project-level files and the enforcement story
weakens substantially. Settle that before building on it.

### The portable store stops being a preference and becomes a requirement

Native auto memory is machine-local and explicitly not shared across machines. For a personal
standard that is a drawback weighed against real benefits. For a team standard it is disqualifying:
standards that live on one person's laptop and cannot be reviewed in a pull request are not
standards. Keep files in version control.

The mechanism worth taking from the native system is its **write-time enforcement loop** — measure
the index on every write, apply backpressure near the cap, hard-error over it. That matters more in
your deployment than in the origin repo, because nobody on your side is going to run a manual
archive pass.

## Part 3: The ladder, with its middle rungs missing

Your users will not have a semantic review agent, will not run a local review model, and will not
have an opinion about CI.

| Layer | Present? | Reliability |
|---|---|---|
| Managed policy CLAUDE.md / settings | Only if IT deploys it | Non-excludable |
| Project CLAUDE.md / rules | Yes | Context, not enforcement |
| Hooks | Yes | Deterministic |
| Semantic review agent | Assume no | — |
| CI | Only on a supported host | Deterministic |

**The design rule that follows: if a standard matters, it lives in a hook or in managed settings.**
Prose is for standards that would merely be nice to follow. Official guidance is explicit that
CLAUDE.md "instructions shape Claude's behavior but are not a hard enforcement layer," and that a
`PreToolUse` hook is the mechanism for blocking something regardless of what Claude decides.

## Part 4: Evidence, and how far it was verified

Do not treat these as settled. The origin repo's full ledger is in
`docs/MEMORY-BANK-PARADIGM-REVIEW.md`; the short version:

- **Well supported (primary sources read):** long context degrades output non-uniformly across 18
  models tested by Chroma, with focused ~300-token prompts beating full 113k-token prompts on
  LongMemEval; `@path` imports do *not* reduce context; path-scoped rules and skills do; auto memory
  is machine-local; managed policy is non-excludable. ACE (ICLR 2026) names both *context collapse*
  and *brevity bias* as failures of iteratively rewritten context, with quantified gains from delta
  updates over monolithic rewrites.
- **Weaker than it is usually quoted:** the widely cited finding that CLAUDE.md structure does not
  affect adherence comes from a single-author preprint, not peer reviewed, reporting a null result.
  Its Bayesian support covers file size and contradiction only — position and architecture are
  inconclusive. Its within-session decay figure is post-hoc and non-monotonic. Do not build a
  Work-MB argument on it without reading arXiv:2605.10039 yourself.
- **Withdrawn:** an earlier draft cited "FLenQA 0.92 → 0.68" attributed to the Chroma report. That
  attribution is wrong and the figure should not be used.
- **README-level only, treat as unverified (added 2026-08-24):** the OpenViking and Lumina claims
  above come from project READMEs. Neither was installed, no source was read, and the token-reduction
  and retention figures are vendor benchmarks with no independent replication. They are strong enough
  to corroborate a design direction and not strong enough to justify a number in a plan.

## Part 5: Questions this brief cannot answer

1. **Who owns deployment of the managed policy layer?** Without Group Policy or MDM access the
   spine of the design is unavailable.
2. **What are non-specialist authors actually getting wrong?** The origin repo's rule set was shaped
   by one operator's incidents. Copying it across is the tempting move and probably the wrong one —
   nobody has measured your failure modes yet.
3. **How is version drift from the origin repo detected?** This fleet has already shipped work under
   stale governance hooks once, and an advisory warning did not prevent it. Whatever the answer is,
   it should not be "someone checks."
