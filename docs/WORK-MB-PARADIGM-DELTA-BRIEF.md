# Memory & Instruction File Paradigm — Portable Brief

**Living document — updated as findings land.** Started 2026-08-23; latest addition
2026-08-26 (the case-folding fix, and what a parity harness structurally cannot tell you).

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

### Cross-shell parity stops being a nicety and becomes a release gate

The origin repo found that its `.sh` and `.ps1` twins diverge on case semantics, silently and in
both directions. Full mechanism and measurements: `MEMORY-BANK-PARADIGM-REVIEW.md`, "The
deterministic layer is not uniformly deterministic". The short version: `mb doctor` and
`mb verify-integrity` rewrite the integrity baseline in the running shell's hex case, sh compares
case-sensitively and pwsh does not, so a pwsh run leaves a baseline that makes the next bash run
report **every** memory-bank file as externally modified.

**Both variables from Part 1 make this worse in a Work-MB deployment, not better.**

*Who is at the keyboard.* The origin repo is one expert operator on one machine, who hit the false
positive, disbelieved it, and reproduced it in both directions inside an hour. A non-specialist
author cannot do any of that. What they see is a security-flavoured warning — "modified outside mb
tools" — on files they know they did not touch. There are only two things they can learn from that,
and both are bad: that the tooling is broken, or that the warning means nothing. The second is the
one that sticks, and it generalises to the true positives.

*Whether the standard is optional.* Because compliance is mandatory in your deployment, a guard that
must be routinely dismissed does not stay a nuisance — it becomes documented procedure to ignore a
security signal. That is a worse outcome than not shipping the guard at all, because it trains the
dismissal habit on everything else in the same channel.

*And the trigger is ordinary there, not exotic.* The origin repo alternates shells occasionally. A
team deployment does it constantly and invisibly: Windows authors in pwsh, WSL or Git Bash for the
hook path, Linux CI runners. The false positive is not an edge case in that environment — it is the
default state.

**What to do differently:**

- **Do not ship a checksum-style integrity guard to non-specialist authors until its two
  implementations are proven to agree.** If you need it before then, normalise case at both ends of
  the comparison, or pin the check to a single shell and refuse to run it elsewhere with a clear
  message. A guard that is wrong 100% of the time in one direction is worse than absent.
- **Make behavioural parity a release gate, not a review item — and wire it into CI.** The origin
  repo has the right mechanism and it is dormant, which is the more instructive failure. Its
  `assert_parity` helper pipes one payload into both the `.sh` and `.ps1` hooks and asserts
  identical verdicts; it covers 11 cases and its own comment names an sh/ps1 case divergence as the
  precedent it exists for. It covers 1 of 12 twin pairs and **skips silently when `pwsh` is absent**
  unless an environment variable is set that nothing in CI sets. (It asserted only one severity tier
  until 2026-08-26; see the addendum below, which is what closing that gap turned up.) On a Linux runner it never executes, so the divergence it was written to catch shipped
  anyway. Copy the harness; do not copy its wiring. A parity test that can skip is a parity test
  that will skip, and a skip that reads as a pass is worse than no test — your authors cannot tell
  the difference, and on a mixed-shell team the skip is the normal case.
- **Treat "our authors can't diagnose this" as a design constraint on every guard, not just this
  one.** In the origin repo a confusing signal costs an expert some time. In yours it either
  generates a support request or, more likely, gets silently ignored. Guards aimed at
  non-specialists need to fail in ways that are unambiguous to someone who cannot read the script.

#### Addendum 2026-08-26 — three things the case-folding fix taught that the section above could not

The origin repo closed the case divergence in its command-guard hook. The gap was much larger than
the ticket describing it: **four of six matchers, spanning three severity tiers**, matched
case-sensitively in `.sh` against a `.ps1` twin that was case-insensitive at every site. Mixed-case
payloads got *no verdict at all* from bash while PowerShell denied them — live on any machine
without `pwsh`, which includes the Linux CI runner. Three findings from it are portable, and two of
them sharpen the advice above rather than restating it.

**1. A parity assertion cannot distinguish "both correct" from "both broken."** This is structural,
not a wiring flaw, and it is the more dangerous sibling of the silent-skip problem already named
above. `assert_parity` asserts the two shells *agree*. If a later edit removes case-insensitivity
from the reference implementation, the two agree again — at the wrong answer — and the parity suite
goes green while doing it. The fix was to add **absolute** assertions on the side that was already
correct, so the reference itself is pinned and cannot drift silently. In your deployment this
matters more, because your authors will read a green parity suite as "the guard works" and have no
way to check the premise. Pair every parity assertion with an absolute one on the reference side.

**2. A guard can be disarmed by a performance fix, silently and fail-open.** Folding the pattern
inside each matcher was correct and cost a subshell per matcher *call* — about 25 per invocation, on
a hook that runs on **every single tool call**. Measured: **1.07s → 2.33s per invocation**. The fix
was to fold the *subject* once and write the patterns in lower case — which then means an
upper-case pattern silently matches nothing, ever. One entry in the shipped list was already that
shape. Nothing at the call site looks wrong; the guard just stops guarding. Two lessons: **budget
guard latency explicitly**, because in a team deployment every author pays it on every command and
the pressure to "optimise" a slow guard is exactly how this class of defect enters; and **when a
fix moves a requirement from the code into a convention, add a structural test for the convention
in the same change**, because a convention with no enforcement is a fail-open trap wearing a
comment.

**3. Prefer structural invariants over payload cases for completeness properties.** The origin
repo's own note records the lesson twice over: a de-escaped-view retrofit missed one matcher of
five, and this case-folding retrofit then missed four of six. Payload tests can only exercise the
matchers someone remembered to write a case for, so they measure *coverage of your imagination*.
The tests that actually hold are the ones that enumerate: no matcher may read an unfolded view; no
pattern may contain an upper-case letter; the two mirrors must be byte-identical. Those fail when a
*new* matcher is added and forgets, which is the failure mode that actually recurs. Cheap to write,
and they do not depend on the author anticipating the bug.

### A per-user global instruction file cannot carry policy in your deployment

**Status in the origin repo: the specific contradiction below was fixed on 2026-08-25** — the global
file now defers to the setting by name, and the drift check was rewritten to compare values instead
of testing for a variable name. **The advice in this section is unchanged**, because the structural
problem was never the wrong number: nothing states which file wins, and a per-user file outside
every repository cannot be reviewed no matter what it currently says.

PMB keeps rules in two places: a per-machine `~/.claude/CLAUDE.md` and a per-project `CLAUDE.md`
committed to the repo. Measured in the origin repo on 2026-08-25, that split has three defects, and
all three get worse when the audience changes.

**The precedence is asserted in one direction and arbitrated in neither.** The global file states
*"Project-level CLAUDE.md files add to these — they do not replace them"*; the project file defines
an authority order for its `memory-bank/` files only and never mentions the global file at all. So
the global claims supremacy, the project is silent, and nothing resolves a direct contradiction.

**There is a live contradiction, and precedence points the wrong way.** `settings.json` sets the
auto-compaction threshold to 65. The global file hardcodes "50%". The project file defers to the
setting by name and is therefore correct. Under the global file's own rule, the **stale hardcoded
constant outranks the correct deferral** — the advisory layer overriding the deterministic one,
which inverts the layering order both files otherwise endorse.

**The drift check that exists cannot see it.** `mb doctor` has a "Token Budget drift" check; run
against this exact contradiction it reports `[OK] Token Budget section current`. It tests only
whether the *variable name* appears in both files and never compares values — a presence check
reported as a correctness check.

**Why this is sharper for Work MB than for PMB.** A `~/.claude/CLAUDE.md` is per-user and lives
outside every repository. That means it is:

- **Unreviewable.** It never appears in a pull request. No reviewer, no CI job, and no hook that
  operates on the repo can see it. For a deployment whose entire purpose is holding authors to a
  reviewable standard, a rule that cannot be reviewed is not a standard.
- **Unenforceable.** Nothing can verify an author's global file matches anyone else's. PMB has one
  operator on one machine, so its global file is effectively a singleton and the drift is invisible.
  With a team, each author's global file drifts independently — and the failure above means they can
  drift *into contradicting the repo while formally outranking it*.
- **Divergent by construction.** Two authors running the same command in the same repo can get
  different behaviour, with nothing in the repo able to detect or explain the difference. That is the
  same shape as the cross-shell divergence recorded above, but with people instead of shells, and no
  parity test is even possible because half the input is outside version control.

**What to do differently:**

- **Put policy in the repo; put only machine facts in the global file.** Anything an author must
  comply with belongs in the committed, reviewable, CI-visible files. The per-user global file should
  carry nothing but genuinely local facts — shell preferences, tool paths, editor quirks — that no
  reviewer would ever need to see. **This is one of the places where your deployment and PMB do
  NOT diverge** — the rule holds for a single expert too; it simply failed quietly there instead of
  loudly. PMB is wrong by this shared standard, not differently-right: *Token Budget* and *Karpathy
  Coding Principles* appear in full in its global file, its project file, AND in the
  `templates/CLAUDE.md` it ships, so every adopter already receives that methodology in-repo and
  reviewable. The global copy is accretion, not design. Treat this section as convergent advice,
  unlike the Part 1 variables that genuinely flip.
- **State the precedence in both directions, and make specificity win.** Whatever you decide, write
  it in *both* files. "Project overrides global" and "global overrides project" are both workable
  rules; "the global file says it wins and the project file has never heard of it" is not.
- **Ban restated constants outright — this is the general fix.** The 50-vs-65 error is not really a
  precedence bug; it is prose restating machine state. Every such restatement is a drift bug that has
  not happened yet, and detecting drift after the fact is strictly worse than making it impossible. A
  document should name the setting and let the reader or the tool resolve it, never copy the value.
  Apply that rule and this class of defect stops recurring instead of being caught one instance at a
  time.

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
- **Measured in the origin repo (added 2026-08-25):** the global-vs-project precedence gap.
  Verified by reading `~/.claude/CLAUDE.md`, the project `CLAUDE.md`, and
  `.claude/settings.json` (which sets the threshold to 65 while the global file states 50),
  and by running `mb doctor`, which reports `[OK] Token Budget section current` against that
  contradiction. **Not verified for a Work-MB deployment** — the multi-author consequences
  are argued from the two Part 1 variables, not observed on a team.
- **Measured in the origin repo, reproduced in both directions (added 2026-08-25):** the
  cross-shell checksum divergence described in Part 2. Verified by running both
  implementations against unedited files in both orders. The claim that no mechanical parity
  check exists for the `.sh`/`.ps1` twins was verified by reading `mb.sh:1384` (covers
  `.claude/agents/` only, WARN-only) and the CI workflows. **Not verified for a Work-MB
  deployment** — the argument about mixed-shell teams and non-specialist habituation follows
  from the two Part 1 variables; it has not been measured in your environment.
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
