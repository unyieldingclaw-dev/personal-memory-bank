# Archived: `progress.md` 2026-08-31 — one section, moved verbatim 2026-09-09

**Relocated from `memory-bank/progress.md` on 2026-09-09**, unchanged. **Verbatim, not summarised** —
a 2026-08-25 pass was reverted for removing content, and that precedent governs here.

**Why:** `progress.md` stood at **498 of its 500-line CI cap** while the `PreCompact` hook requires an
entry dated today — two lines of headroom against a mandated write. The gate was measured exiting 2
on 2026-09-09. This is the **second** occurrence of the same bind: the 2026-08-31 pass archived five
sections for the identical reason at 499 of 500. A cap and a mandatory daily write that collide on a
schedule are a structural conflict, not an accident of housekeeping.

**Delta, not a level: 18,208 bytes and 173 lines moved out.** Measured on the LF content, which is what
git stores and CI reads — confirmed by `tr -cd '
' | wc -c` returning 0 and by the blob size matching
the file size. The 2026-08-31 pass was caught by a CRLF working tree reading one byte per line high;
this tree is LF, so that trap did not apply here. Recorded because an earlier draft of this header
asserted the opposite from a `grep -c $'
'` that matched every line rather than counting CR bytes.

**Citation survival was grep-verified before and after the move.** The original heading is preserved
both here and in the pointer left in `progress.md`, so existing `progress.md 2026-08-31` references
still resolve. Six `[NS-N]` items appear in this content — NS-35, 41, 43, 44, 46, 47 — and every one
is also carried in `activeContext.md`, so none is orphaned by the move. An earlier draft of this
line said nine and listed NS-27, 45 and 48 as well: that count came from grepping the range under
consideration rather than the range actually moved. Corrected on review. The rule requires this be
grep-verified, and the first attempt verified the wrong set.

---

## 2026-08-31 — what four Opposition rounds cost, and the one rule worth keeping

Detail is in `11ec83b` and `e1d77f2`. Only what a commit message cannot carry:

- **Overcorrecting in the self-critical direction is its own false record.** A confession is a claim
  and takes the same evidence as any other. The BOM finding was recorded WRONG THREE TIMES: as a
  bypass (reproduced with a malformed hybrid), then as a regression I had introduced, then as an
  effect unrelated to the setting. An 8-case byte matrix settled it; each wrong version was asserted
  from a proxy rather than measured, **including the self-critical one**, which is the version that
  reads as rigour and therefore gets challenged least. ACR recorded the same rule independently after
  their own memory bank carried my wrong version for hours because they believed my self-criticism.
- **Review-by-reading produced nothing this session; review-by-breaking-something-adjacent produced
  everything.** Five domain agents plus two Opposition rounds passed a diff containing a
  space-splitting bypass of a required check. Four separate "checks that cannot fail" were found only
  by mutating the code they guarded. The BOM error surfaced only from writing the test meant to
  confirm the fix. Nothing was found by re-reading.
- **A fix that reaches one sibling and not the other is the recurring mechanism here, not a series of
  incidents.** Three instances in one file family this session: `ceil_region` → `region_claude`;
  `region_claude` fixed for `mb.sh` but not `pmb-health.yml`; `1,116` correct in PMB's repo and wrong
  in the template. Worth treating as a class when reviewing any two-copy change.
- **Cross-session:** ACR (`ai-code-review-agent`) and this repo ran a full day of paired review. Their
  findings against PMB and mine against ACR are recorded in each other's banks as *peer-reported, not
  reproduced locally*. That labelling is deliberate and should be preserved — it is what let both
  sides correct a wrong claim without it hardening into either record.

- **The six remaining Work-MB exports refreshed 2026-08-31; three verified claims came out of it.**
  (a) `030662c` shipped **four of the six** recommendations in
  `WORK-MB-ENFORCEMENT-INTEGRITY-VERIFICATION-AND-DESIGN.md`, whose header still read "nothing
  implemented" — including its self-described core fix, the three-state result model (`DEGRADED` is
  live in both `pre-push-check.{sh,ps1}`). Template hashing and a `SessionStart` staleness hook did
  NOT land (searched `scripts/*.{sh,ps1}` and `.claude/settings.json`; not searched: unmerged
  branches). (b) The handoff brief's "four surfaces still carry the superseded protocol" claim is
  **still true 11 days on** — `templates/AGENTS.md:61,65`, both `.cursor/rules/memory-bank.mdc`
  copies, `templates/memory-bank/README.md:37`. The corrected protocol reached the surfaces a Claude
  Code session reads and stopped at the ones other tools read. (c) `docs/MEMORY-BANK-REDESIGN-VALIDATION.md`
  **still does not exist**, so D1-D4 still has no written home anywhere.
- **The inbound MB testing overview predicted two defects PMB later hit independently — worth the
  reciprocity.** Its 2026-08-22 §9.3.2 recommended a `cursor-parity` drift gate; PMB built parity
  gating of that class for `standards/` and thresholds and never for `.cursor/rules/`, which is
  exactly the gap (b) above measures. Its §9.3.5 recommended SHA **scope** tests on the review marker;
  PMB reached `[NS-41]` (a marker can attest to an EMPTY diff) from the other direction five days
  later. **A peer's recommendation that we declined is now a measured cost, twice.** That document is
  inbound and its body was annotated, not edited — preserve that distinction.

- **`[NS-35]` condensed 5,823->1,861 B (LF); `[NS-46]` added** (global-vs-project arbitration, untracked until now because the file was at its cap).
  Net effect on `activeContext.md`: **+286 B** — the condensation recovered 3,962 and `[NS-46]`+`[NS-47]` spent
  4,248, so the largest-entry position TRANSFERRED rather than cleared. Headroom is a level; read it from
  `pmb-health.yml`'s `MB_FAIL_BYTES`, never from here. **The recovery came from a human overriding the eviction criteria on an ACTIVE entry, not
  from the mechanism** — the seven entries actually marked resolved total 2,131 B even if deleted outright. `[NS-44]`'s §5 finding survives intact.
- **The condensation exposed a false claim I had shipped hours earlier.** `[NS-35]` decision 1 (tiered loading) was **DESIGNED, Opposition-reviewed
  and DROPPED 2026-08-26** on six blocking findings — the index does not fit (~117 B/item available vs 198 measured) and its scope self-reverted via
  `TEMPLATE_OWNED`. Both `[NS-35]` and the paradigm review still carried the PRE-DROP framing, so Document 14 of today's Work-MB brief asserted "a
  porting problem, not a design problem" — the exact belief Opposition falsified. Corrected in both. **A tracking entry is not a substitute for the
  record it summarises**, and a summary written before a reversal looks identical to one written after.
- **`progress.md` relocation ran 2026-08-31 at 499/500 lines** — one line of headroom against a `PreCompact` hook that
  *requires* a dated entry, i.e. a mandated write the cap forbade. Five 2026-08-28 sections moved verbatim:
  **213 lines / 30,235 B** (LF blob). Byte accounting, one convention throughout
  (LF): **30,235 B out**. The pointer-block and net figures are deliberately omitted — the block is LIVE and this same commit edits it, so any figure for it is false on write. An earlier draft mixed LF and CRLF three figures apart, then quoted a pointer-block size its own edit invalidated. Four dated sub-references verified resolving in BOTH the pointer and the archive.
- **Measured effect on the thing that actually matters:** for startup context (CLAUDE.md + **all six** `memory-bank/*.md`, the set CI measures),
  **the ratchet passes** — margin deliberately not quoted. A branch-vs-`origin/main` figure is a LEVEL IN DISGUISE:
  both endpoints move, so it decays like any level. Read the margin from CI.
  Absolute KB and multiples-of-the-ceiling are deliberately NOT stated — they decay on the next write to any
  measured file, which is exactly how four figures in this entry went stale inside one session. Note what did the work: **relocation and one hand-condensed active entry, not eviction.**
- **`[NS-47]` + Work-MB Document 16 written from an external survey (Codex, ai-that-works, OmniRoute), doc-level only,
  nothing installed or reproduced.** The finding that reframes `[NS-46]`: **Codex runs TWO precedence systems in
  OPPOSITE directions on purpose** — prose (`AGENTS.md`) is positional, most-local-wins, so project beats global;
  policy (`config.toml`/`requirements.toml`) is layered, managed-wins, MDM > cloud layers > system requirements >
  user/project. **PMB has ONE file type carrying BOTH at two scopes under one asserted rule**, so guidance and
  guardrails get identical precedence when they want opposite ones. The stale-constant incident was not a check that
  escaped — it was policy routed through a channel whose precedence was designed for guidance. **Fix the split
  before writing an arbitration rule.** Honest limit found in the same docs: managed config sets startup DEFAULTS and
  a user may change them mid-run; only `allow_managed_hooks_only` is hard. That distinction IS the compliance claim.
- **Decaying-Resolution Memory names what this repo already does by hand** — resolution decays, the memory does not,
  which is why it survives the objection that killed Lumina's time-decay. Today's `[NS-35]` condensation and the
  relocate-verbatim-plus-pointer archive are both DRM performed reactively at cap-breach. **Adopt it only on the READ
  path** — full resolution stays on disk forever, only what is LOADED loses detail; DRM's summarise-the-store variant
  is the ACE/SSGM degradation this repo already reverted a pass for. **OmniRoute REJECTED, and the SECOND instance of
  its class** (SwitchYard was first): a routing gateway needs a request path the harness owns, its compression targets
  model-readable text against a PR-reviewability requirement, and its vector memory fails the observability objection.
  Two instances make it a class — record the three reasons so the next gateway proposal gets an answer, not a shrug.
- **Findings F and G closed in `.claude/commands/change-review.md` and its template mirror (byte-identical after).**
  F: the exit-1 row now discriminates on **whether a report exists** before reading exit 1 as findings — with none it
  is a usage error (unknown flag, bad `--fail-on`, unknown profile, missing diff file, or ACR <1.10.0 rejecting
  `--chunk`), handled as `4` but with stderr read FIRST, since a usage error is deterministic and retrying it changes
  nothing. A **version preflight** was added as the new step 2: below 1.10.0 ACR is treated as UNAVAILABLE and the job
  goes inline as `basis: llm` — explicitly NOT falling back to a non-chunked run, which would reintroduce the silent
  truncation the job exists to prevent. G: the exit-3 row's "re-run with `--chunk`" is gone; the safety clause stays.
- **NEW FINDING, surfaced BY that edit and not fixed: `.claude/commands/` <-> `templates/claude-commands/` is a
  TEMPLATE_OWNED mirror pair with NO parity test.** `mb.sh` auto-discovers every `templates/claude-commands/*` (grep `TEMPLATE_OWNED`; no line number, the repo's own convention — they have gone stale repeatedly)
  into `TEMPLATE_OWNED`, so `mb upgrade` overwrites the live copy **unconditionally** — divergence is silently
  reverted. That is verbatim the rationale `tests/test-mirror-parity.sh` states for guarding `.cursor/rules`, and it
  guards that family and not this one. The two copies are identical today only because this edit kept them so BY HAND.
  Extending the existing test is the obvious fix. **SUPERSEDED by the next bullet — it was done later the same
  session.** Recorded as found-then-fixed rather than rewritten. New assertions here must be mutation-proved per
  source. **Also honest: nothing tests `change-review.md`'s content at all, so F and G are unverified by any suite.**
- **`tests/test-mirror-parity.sh` extended to a third mirror pair: `.claude/commands` <-> `templates/claude-commands`.
  50 -> 75 assertions** (8 pairs x exists+identical, 1 sweep guard, 8 orphan checks). All 8 measured byte-identical,
  none diverging by design, so it is STRICT-identity like `.cursor/rules` rather than allowlisted like `standards/`.
  Recorded in the file: the pair is TEMPLATE_OWNED by a **different route** — cursor rules are six literal array
  entries, commands are AUTO-DISCOVERED into the array (`mb.sh`), so the array holds exactly those commands that HAVE
  a template; a live orphan is therefore never in it, never visited, never shipped, and drifts silently. Directory
  names are asymmetric (`templates/claude-commands/` -> `.claude/commands/`), which a naive path derivation breaks on.
- **Mutation-proved on a SCRATCH copy, per the 2026-08-30 rule — never the shared tree.** A faithful scratch harness
  reproduced 75/0 before any mutation. Four mutations, each isolating one new assertion: one-byte divergence -> 74/1;
  live copy removed -> 72/1; live orphan added -> 75/1; template dir renamed -> **50/9**. The last is the one worth
  keeping: **50 is exactly the pre-extension count**, i.e. renaming the directory makes all 16 template-side
  assertions VANISH and only the sweep guard stands between that and a suite passing on nothing. The anti-tautology
  guard was demonstrated, not asserted.
- **`[NS-43]`(b) IS BROADER THAN RECORDED — new instance, reproduced today.** That entry says the review gate's
  textual matcher denies any Bash command merely MENTIONING the commit verb, "so this entry could not be written from
  a heredoc". The same thing happens for the BLOCK-tier recursive-delete pattern: writing THIS progress entry was
  denied because the prose quoted that pattern verbatim, and it had to be reworded to land. So the defect is not
  specific to the commit verb — **any BLOCK/deny pattern is unquotable in the record it governs.** Fail-safe, and it
  means the repo systematically cannot document its own guardrails from the tool it uses to write them. Reworded
  rather than bypassed, per the no-user-as-bypass rule.
- **Two operational notes.** The BLOCK tier also refused a recursive delete of my own scratch directory — correct, it
  does not whitelist scratch paths; worked within it using a fresh directory and `mv`. And a first full-suite run was
  KILLED at a 2-minute timeout; `run.sh` moves the real `VERSION` aside, so the tree was checked before continuing —
  `VERSION` intact at 1.2.1, no stray backups, no unintended modifications.
- **The exit-0 row was fixed too, and it is the most interesting of the three.** `0` no longer asserts "Ran fully";
  it now requires READING THE BODY, because a fail-fast/`earlyExit` ACR run exits `0` and declares itself INCOMPLETE
  in the body rather than the code. **Peer-reported by the ACR session (their PR #83), NOT reproduced here** —
  labelling preserved. Step 5's fall-through was widened to cover an exit `0`/`1` whose body contradicts its code.
- **What makes it worth recording: the old wording was NOT wrong when written.** Before that PR a fail-fast run was
  indistinguishable from a complete one on every readable surface, so "Ran fully" was accurate. It was made false by
  a change in ANOTHER repository, with no edit to this file and nothing here able to detect it. **A correct claim can
  be invalidated by a change elsewhere** — which is the cross-project form of the drift class this repo keeps
  finding internally, and the argument for citing a source of truth rather than restating its current state.
- **Cost of taking it mid-review, recorded because the sequencing is the lesson.** Five domain agents were already
  running against `git diff HEAD`. Editing without stopping them would have produced a marker binding a tree that
  **five of six reviewers never saw** — the marker-attests-to-unreviewed-content failure this repo has logged before.
  So they were stopped, all edits made, and the review restarted once against a frozen tree. Partial reuse of their
  findings was available and deliberately not taken.
- **ACR independently verified F and G in this checkout rather than accepting them, and found a measurement trap.**
  `grep -c "re-run with \`--chunk\`"` returns **1**, reading as "still present" — but the survivor is inside the
  parenthetical that RECORDS ITS OWN DELETION. **A count is the wrong instrument for "was this removed" whenever the
  record of removal quotes the removed text.** Same family as the check satisfied by a comment, one tier up: not a
  test that cannot fail, but a measurement that cannot distinguish.
- **RELEASE CONTRACT — scheduling decided by the operator 2026-08-31, so it stops being re-relayed.**
  The substance was approved 2026-08-28 (tag -> dirty-tree guard -> ref-sourcing). Only the *when*
  was outstanding, and it had died twice: relayed to `personal-memory-bank-7b`, which correctly
  declined to act second-hand, and that session ended. **Decision: cut the first tag AFTER this
  branch merges.** Rationale, unchanged from the constraint that produced the question: `mb upgrade`
  sources the WORKING TREE, so no tag may be cut against a dirty one, and the branch is 11 commits
  unpushed behind an open push gate. Recorded here rather than relayed again — a scheduling decision
  passed between sessions is how it gets acted on twice.
- **The 13 Medium ACR findings are NOT recoverable, and the scope of that claim is stated.** Searched:
  all 24 session transcripts under `~/.claude/projects/C--Users-Mizzo-.../`, the entire scratchpad tree
  (18 session dirs, unfiltered by extension), the ACR working tree for a default report location
  (there is none), and this repo. **What WAS recovered** from transcript `6bfddd35` (lines 5040-5071):
  the run metrics (`ACR_EXIT=1`, 200s, 15 findings), the per-agent chunk breakdown, and **both High
  findings in full with their disproofs**. The reviewing session printed only the `## Medium (13)`
  header and read the two High bodies; the Medium bodies never entered its context and ACR wrote no
  report file. **Product consequence for ACR, now in their brief:** a 200-second run whose output
  cannot be recovered fifteen minutes later is a workflow hazard independent of finding quality.
- **Both recovered High findings were false, by two mechanisms worth keeping.** (1) ACR read a
  **deleted `-` line as current code** and recommended exactly what the branch had already done —
  generalises to *a diff that fixes a bug contains the buggy code by construction, so the better the
  fix, the more false Highs it generates*. (2) It **inferred absence of behaviour from absence of an
  idiom** (no `ToLower` in the ps1), where PowerShell operators are case-insensitive by default;
  disproved behaviourally 4/4, not by argument. Also confirmed: 1.15.0 now emits `**Location
  unverified** (evidence not found at this line)` — PMB's own 2026-08-26 recommended invariant,
  implemented — and **both false Highs carried it**, so it works as a confidence signal but does not
  clear `Blocking: Yes`.
- **Downloads Work-MB exports refreshed 2026-08-31** (channel kept, per operator decision; a GitHub
  migration was considered and declined). `ACR-1.15.0-...-2026-08-31.md` created and the 1.13.1 file
  bannered SUPERSEDED; `PMB-Findings-for-Work-MB.md` header corrected `2052c3c` -> `11ec83b` and
  Documents 13-15 added (session-start load + the ratchet; the pointer mechanism; the five
  checks-that-could-not-fail); Round3 annotated as a deliberate snapshot; the paradigm-review HTML
  given a currency banner correcting **Q1** — its *"nothing structural can proceed until this is
  answered"* was falsified, since the ratchet shipped with the pointer mechanism still unbuilt, and
  the outcome was a third option neither Q1 branch anticipated.

