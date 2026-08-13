# Investigation Integrity

**Date:** 2026-08-12
**Status:** Approved

## Problem

Across a single session, the user asked for one more verification pass on in-progress work **six separate times**, and every single one produced real, substantive findings — not restated concerns, not nitpicks:

1. First full review-gate design presented, confident tone throughout, no gaps disclosed.
2. "Do we log reviews run?" → a real gap: no invocation-start log existed in the design at all.
3. "Passed, not just run" → a real bug: the CI containment check would have counted a *rejected* review (Request Changes/Needs Discussion) as passing coverage, since it only checked "does an entry exist," not its verdict.
4. "Take one more deep dive" → **seven** more issues in one pass: `--no-verify` fully defeats the git-hook layer, `core.hooksPath` can be unset, the fix is fleet-wide-soft not fleet-wide-hard, an empty-diff marker-burn race, a missing PowerShell twin for `pre-commit`, an unverified assumption about merge-commit hook-firing behavior, rebase silently invalidating local gating.
5. After the spec was written and committed, "look again" → **three** more: no concrete file path for the invocation log, a step-ordering bug (code-review.md's Step 1 doesn't know scope yet, Step 2 does), and a single shared log file that would have caused real merge conflicts across this repo's own parallel-worktree workflow.
6. Drafting the `SECURITY-GUARDRAILS.md` hardening text, "review again" → my own draft **directly contradicted** an existing, intentional rule in the same document (`dangerous-commands.sh`'s CONFIRM tier, where the user running a blocked command directly is the *correct*, designed resolution — not the bypass pattern the new rule targets).

A seventh instance happened *while designing the fix for this exact problem*: this document's own draft used the word "checklist" in two incompatible senses — once to describe the failure mode ("a checklist doesn't fix a calibration problem"), then again a few messages later to describe the proposed fix, with no acknowledgment that these were different things. The user caught it. This is, if anything, the single strongest piece of evidence in the whole investigation: the exact failure mode under discussion recurred inside the discussion about how to prevent it.

**The precise failure, stated plainly:** the first pass on any nontrivial investigative claim is reliably not the best-effort pass — it is a plausible-sounding draft, delivered with the same confident tone that would be appropriate for something fully scrutinized. The deeper, adversarial work only happens once the user signals dissatisfaction with "sounds right." That is a more specific and more serious problem than "misses edge cases sometimes." It means confidence, as expressed, is not currently correlated with how much verification actually happened.

**What this is not:** a request for zero future gaps. The user explicitly acknowledged that 100% completeness is not achievable — no design or investigation can be proven to have no unknown unknowns. The actual ask is narrower and fully achievable: **the confidence I express should accurately reflect what was actually checked, every time**, so that when a gap does surface, it's because a disclosed, accepted limitation turned out to matter — not because something was silently assumed and asserted as settled.

## Design

### Two distinct mechanisms, not one

Early drafts of this design conflated "add a checklist" with "fix the confidence-calibration problem." They are not the same fix, and treating them as one is exactly the ambiguity the user caught. Two separate mechanisms are needed, because they catch two different failure classes:

**1. Grounding discipline (per-claim, applied as the investigation happens, not retrospectively).** Every material claim in an investigative response gets tagged with its actual basis, reusing `standards/CODE-REVIEW.md`'s existing, already-precise vocabulary rather than inventing new terms:
- `VERIFIED` — directly observed just now (a file read, a command run, an actual grep result) or earlier in this same conversation with an explicit reference to when.
- `INFERRED` — reasoned from a pattern, not directly confirmed; the reasoning chain must be stated, not just the conclusion.
- `SPECULATIVE` — a suspected risk whose consequence is genuinely uncertain; must say so explicitly rather than being folded into confident prose.

This targets fabrication of *individual claims* — stating something with more confidence than its actual basis supports.

**2. Coverage discipline (a genuine adversarial pass before presenting anything as final).** Grounding alone doesn't catch a category of concern that was never raised as a claim in the first place — `--no-verify` wasn't a mis-cited claim in the first review-gate draft, it was **absent entirely**. No amount of "cite your sources" touches an omission. This requires, before presenting: generating a fresh, domain-appropriate list of "what could be wrong or missing here" (not a fixed universal list — the categories for a debugging session and a security audit are genuinely different) and explicitly working through each one, with results visible, not silently absorbed into the final answer.

Both are necessary. Grounding without coverage still misses whole categories. Coverage without grounding can still assert unverified conclusions confidently within the categories it does check.

### Anti-theater safeguard (named explicitly, using this conversation as the worked example)

A checklist — even the two-mechanism version above — can be satisfied by going through the motions: write four section headers, assert each was "considered," move on. This is not hypothetical; it is what happened with the word "checklist" itself earlier in this exact design process. The skill's own instructions must name this directly, the same way `docs/HOOKS-GUIDE.md`'s worked examples name real incidents rather than describing failure modes abstractly. Structural defense against it: coverage-discipline output isn't a checkbox list, it's the same `VERIFIED`/`INFERRED`/`SPECULATIVE` grounding applied to *each category checked* — "I considered X" is not itself a claim with a basis; "I checked X by reading file Y, here's what I found" is. This doesn't make theater impossible (a sufficiently unwilling instance of me could still fabricate a plausible-looking citation) — it makes theater *visible and spot-checkable* rather than indistinguishable from genuine work, the same residual-risk shape this repo already accepted for the review-gate's self-attestation limits.

### Trigger design: structural, not judgment-based

The trigger cannot be "use judgment about whether this feels important enough" — that judgment call is the exact thing shown to be unreliable tonight (the same reasoning that decided "docs changes are low-risk, skip review" is the reasoning that would decide "this investigation is simple enough, skip the adversarial pass"). Borrowing `verification-before-completion`'s already-proven pattern instead: trigger on the **linguistic shape** of what's about to be said — completion language, conclusion language, recommendation language ("here's what I found," "the root cause is," "I recommend," "this should work," "here's the design") — not a stakes assessment. Recognizing "I am about to make this *type* of statement" is a narrower, more mechanical recognition task than "is this important," and far less prone to motivated reasoning.

Explicit bias, matching `using-superpowers`' own standing rule ("even a 1% chance, invoke it"): when genuinely uncertain whether something counts as a conclusion-shaped statement, apply the discipline. Under-triggering is the failure mode that actually happened six times tonight; over-triggering's cost is proportionality friction, addressed next, not a security or trust failure.

### Proportionality, without recreating the bootstrapping problem

Genuinely trivial exchanges (a direct factual lookup, a mechanical action with no judgment call, something the user could verify themselves in seconds) shouldn't carry the full weight of both disciplines — a design that makes every single response balloon into a structured report would itself fail on "fluid," and this repo has already lived through the cost of an over-applied gate becoming routinely bypassed (the review-gate's own history). But the *carve-out* criteria have to be as narrow and structural as the trigger itself, not a re-opened judgment call: the discipline applies to anything presented as a **conclusion, finding, recommendation, or "this is complete/correct"** claim. It does not apply to a direct answer with no investigative content behind it. When a specific interaction doesn't obviously sort into either bucket, it defaults to the trigger firing, same bias as above.

### Output format requirements

- Every material claim in a conclusion-shaped response carries a `VERIFIED`/`INFERRED`/`SPECULATIVE` tag, per `standards/CODE-REVIEW.md`'s existing rules for what each requires.
- An explicit, always-present "what was not checked / open risk" section — even when empty, it must say so explicitly ("nothing identified as unchecked") rather than being silently omitted, mirroring `mb-drift/SKILL.md`'s existing rule that a clean result is a valid result and must be reported, not skipped.
- Coverage-pass categories are generated fresh per investigation (domain-appropriate), not pulled from one fixed universal list — but the *requirement* to generate and explicitly work through them is fixed.

### Why this produces "fluid" interaction — the actual mechanism, not a hope

The user asked for the interaction to flow, and for trust that homework was actually done. Neither of those means "the AI is right the first time, always" — that's not achievable, and the user already said so directly. What's achievable, and what this design actually targets, is **moving disclosure of limits from reactive to proactive.** Tonight, every gap was extracted through the user's own repeated interrogation — a costly, adversarial dynamic where the human has to do detection work the assistant should have done. If the same limits are stated upfront, unprompted, as part of the answer itself, the user's role shifts from *catching* undisclosed gaps to *deciding whether to accept* disclosed ones. That second dynamic is collaborative rather than extractive — which is the actual, concrete definition of "fluid" this design is aiming at, not a vague aspiration toward fewer mistakes.

### Relationship to existing skills — explicit, not assumed

- **`systematic-debugging`** governs *how* to debug (root-cause phases, hypothesis testing). This skill governs whether a *conclusion* — root cause or otherwise — is presented with calibrated confidence. Complementary; each should reference the other rather than silently overlapping.
- **`verification-before-completion`** covers claims with a command and an exit code. This skill covers claims that have no single command to run (design judgments, root-cause conclusions, audit findings) — same "evidence before claims" spirit, different mechanism because the evidence type differs. `VBC`'s Iron Law is a special case of this skill's grounding discipline, restricted to mechanically-verifiable claims.
- **`/code-review`'s Opposition Review / `/change-review`'s Job 9** already do exactly this pattern — adversarial pass, required basis tags — scoped specifically to code diffs with a fixed domain checklist. This design generalizes the *pattern* beyond code diffs. Explicit rule, to avoid redundant stacking: if already inside `/code-review` or `/change-review`, their own Opposition Review satisfies this skill's coverage discipline for that diff — do not run a second, separate pass on top.
- **`mb-drift/SKILL.md`** is the closest existing precedent in this exact repo: auto-triggering, fixed-but-domain-scoped checklist, required-citation output ("[File A §Section] says '[quote]'"), explicit "clean is valid" rule. It's narrowly scoped to memory-bank file consistency. This design is best understood as generalizing `mb-drift`'s *structure* to any investigative domain — not modifying `mb-drift` itself, which isn't broken and is out of scope here.

### Distribution and placement

Verified directly (not assumed): `templates/.claude/skills/` does not exist yet, and `grep -n "skills" scripts/mb.sh` returns nothing — `skills/` is not currently part of the `TEMPLATE_OWNED` distribution mechanism at all. `mb-drift/SKILL.md` itself is local to this repo only, never fleet-distributed via `mb upgrade`.

**Decision: wire `skills/` into the `TEMPLATE_OWNED` mechanism as part of this work — but not by "mirroring `scripts/`/`commands/`," which turned out on inspection not to be one consistent pattern to mirror in the first place.** Checked directly rather than assumed, three real findings:

1. **`scripts/` (bash) uses an explicit named allowlist** in both the `mb init` copy loop and the `TEMPLATE_OWNED` array — every file must be individually listed by name in `mb.sh`.
2. **`.claude/commands/` (bash) uses a flat wildcard glob** for the `mb init` copy loop (`for f in "$TEMPLATES_DIR/claude-commands"/*`), but the bash `TEMPLATE_OWNED` array still hardcodes each command filename individually — an already-existing asymmetry inside bash itself (init auto-discovers, upgrade-tracking doesn't), not something introduced by this design.
3. **`.claude/commands/` (PowerShell) auto-discovers via `Get-TemplateDirFile -Subdir "claude-commands"`** for *both* init and the `TEMPLATE_OWNED`-equivalent list — a deliberate anti-hardcoding fix already present in `mb.ps1` (explicit `WHY:` comment at line 2027), avoiding the exact class of bash-side gap this repo already found and fixed once before (the `_review-gate-lib` export gap, 2026-08-04).

None of these three existing patterns handle a **one-level-nested** structure (`skills/<name>/SKILL.md`) — `Get-TemplateDirFile` specifically calls `Get-ChildItem $dir -File`, which is flat and non-recursive, confirmed by reading its actual body, not inferred from its name. Extending it to recurse would risk changing behavior for the already-working `commands/` path it's also used for. The correct fix is a **new, purpose-built helper** for the nested case, kept separate from the flat-file one:

- **PowerShell**: new `Get-TemplateSkillDir` (or similarly named) helper — enumerates immediate subdirectories of `templates/.claude/skills/`, and for each, locates `SKILL.md` inside it. Wired into both `Invoke-Init`'s copy loop and `Get-MbUpgradeAnalysis`'s `TEMPLATE_OWNED`-equivalent list, following the same auto-discovery philosophy already chosen for `commands/` — new skills shouldn't require a code change to `mb.ps1` to be picked up, matching the precedent this repo already set for exactly this reason.
- **Bash**: a new glob loop over `$TEMPLATES_DIR/.claude/skills/*/`, copying each subdirectory's `SKILL.md` to the matching path under `$TARGET/.claude/skills/<name>/`, mirroring the auto-discovering shape of the *existing* `commands/` init loop (not the hardcoded `scripts/` allowlist) for the copy step. The `TEMPLATE_OWNED` array itself will still need an explicit per-skill entry on the bash side, consistent with how `commands/` already works there today — this is a pre-existing bash/PowerShell asymmetry this design inherits, not one it needs to resolve; resolving it fleet-wide is a separate, larger undertaking outside this scope.

Reasoning for doing this work at all, restated precisely now that the mechanism is concrete rather than assumed: the entire point of this design is portability and consistency of judgment quality — shipping it PMB-local-only would leave every other PMB-managed repo (per the 2026-07-13 Fleet Audit) without it, undermining the design's own purpose. This is additional, real scope beyond "add one skill file," named explicitly here rather than folded in silently.

### The portable investigation brief (for the user's separate, inaccessible work Memory Bank)

This is explicitly **not** a copy of the skill file. The user's work Memory Bank is a separate system I have no access to and whose actual structure I don't know — it may not share PMB's conventions, may have different or no existing skill/hook mechanisms, and blindly dropping in a PMB-shaped file risks being inert or actively wrong there. Instead, this deliverable is a self-contained **investigation brief** — a document meant to be read by a fresh Claude Code session inside that other repo, instructing it to do its own grounded investigation rather than import a conclusion it never verified (which would be a small, ironic act of exactly the failure mode this whole design exists to prevent).

Required content of that brief:
1. **The problem, stated generally** — the six-instance pattern and the reframe ("not zero gaps, calibrated confidence") described above, without PMB-specific file paths or mechanism names.
2. **The two-mechanism structure** (grounding discipline, coverage discipline) as portable *principles*, with the `VERIFIED`/`INFERRED`/`SPECULATIVE` vocabulary offered as one working example, not a mandate — the receiving system may already have its own equivalent classification worth reusing instead.
3. **Explicit instructions to investigate before implementing**: discover what enforcement/skill/hook mechanisms already exist there, identify whether something like this already exists in another form, and only then design an implementation fitted to that system's actual conventions.
4. **The anti-theater warning**, using this same checklist-ambiguity incident as the worked example — it's short, concrete, and portable without modification.
5. **An explicit instruction not to skip the "investigate first" step** — pointedly, since skipping straight to implementation would itself be the exact failure this brief exists to prevent.

## Testing

There's no exit code for "did this catch enough" — the same problem this design exists to solve. Testing approach has to be scenario- and regression-based instead:

1. **Regression against this session's own history.** Re-run the coverage discipline against the *first* review-gate design draft (before any of the six "look again" rounds) and confirm it surfaces `--no-verify`, `core.hooksPath`, the empty-diff race, and the others — on what would be a genuine first pass, not a fourth one. This is a strong test because the "before" and "after" states are both real, not synthetic.
2. **Planted-gap fixtures**, matching this repo's existing fixture philosophy (`fixtures/security/` for intentionally vulnerable code): construct a small design with a deliberately planted contradiction (mirroring the CONFIRM-tier conflict) and confirm the coverage pass catches it when the categories generated include "check new content against existing content."
3. **Anti-gaming check**: confirm the skill's own file explicitly contains the anti-theater warning and the worked example, not just a generic "be thorough" instruction — a structural check on the artifact itself, not just its effects.

## Known Limitations (disclosed, not hidden)

1. **Still advisory.** No hook can verify genuine internal reasoning quality — the same ceiling this repo already accepted for the review-gate hardening's own advisory pieces. This skill cannot be enforced any more than "never use the user as a bypass" could be.
2. **Citation requirements raise the cost of theater; they don't eliminate it.** A sufficiently unwilling or broken instance of me could still fabricate a plausible `VERIFIED` tag. Structurally visible and spot-checkable is the actual guarantee, not impossible-to-fake.
3. **Trigger relies on recognizing linguistic shape.** An unusually phrased conclusion could slip past unrecognized. Mitigated, not solved, by defaulting to apply when uncertain.
4. **Effectiveness depends on recognition, not just existence.** The skill file persists across sessions, but it only does anything if a given session actually recognizes a conclusion-shaped moment and invokes it. A compacted session, or one that doesn't match the trigger, can drift back to the exact pattern documented here even with the file present and unchanged. This is the same class of limitation `CLAUDE.md` itself already names for advisory text generally.

## Out of Scope

- Rewriting `mb-drift/SKILL.md` to be a formal instance of this new skill — not broken, not touched.
- Directly porting anything into the user's work Memory Bank — no access to that system; the investigation brief is the full extent of what's possible from here.
- Any hook-level enforcement mechanism — established above as structurally impossible for this class of problem, same as the review-gate's own advisory-only pieces.
- Fleet-wide CI or `mb upgrade` rollout beyond wiring `skills/` into the existing `TEMPLATE_OWNED` mechanism — actually running `mb upgrade` against other repos remains out of this session's reach per the existing cross-repo write boundary.

## Files Changed

| File | Change |
|---|---|
| `.claude/skills/investigation-integrity/SKILL.md` | New skill: grounding discipline, coverage discipline, anti-theater worked example, trigger/proportionality rules, cross-references to adjacent skills |
| `templates/.claude/skills/investigation-integrity/SKILL.md` | New — mirror, `TEMPLATE_OWNED` |
| `scripts/mb.sh` | New glob loop over `.claude/skills/*/` in the `mb init` copy step (mirroring `commands/`'s auto-discovering shape, not `scripts/`'s hardcoded allowlist), plus an explicit new `TEMPLATE_OWNED` array entry per skill (bash's existing, pre-established asymmetry for `commands/` — init auto-discovers, upgrade-tracking doesn't) |
| `scripts/mb.ps1` | New `Get-TemplateSkillDir`-style helper (nested-directory-aware, since `Get-TemplateDirFile` is flat/non-recursive and shouldn't be changed for the already-working `commands/` case), wired into `Invoke-Init`'s copy loop and `Get-MbUpgradeAnalysis`'s `TEMPLATE_OWNED`-equivalent enumeration |
| `docs/HOOKS-GUIDE.md` | New section documenting this skill and why it's advisory-only, matching the existing worked-example convention |
| `templates/docs/HOOKS-GUIDE.md` | Trimmed mirror |
| `docs/WORK-MB-INVESTIGATION-BRIEF.md` | New — the portable, PMB-agnostic investigation brief for the user's separate work Memory Bank, placed at the docs/ root (not `docs/superpowers/`, which is reserved for PMB's own design artifacts) since this file is meant to be extracted and carried elsewhere |
| `tests/test-mb-init.sh` / `test-mb-upgrade.sh` | Regression coverage for the new `skills/` distribution category, following the existing pattern for `scripts/`/`commands/` |
