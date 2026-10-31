# Archived: `progress.md` 2026-09-11 — whole-repo review section, relocated 2026-10-29

**Relocated from `memory-bank/progress.md` on 2026-10-29, verbatim,** to fund the v1.3.0 release entry
under the startup-context ratchet. The section below the first `---` (this file's lines 15-178) is lines 186-349 of
`memory-bank/progress.md` at `8d21b56`. Reproduce with
`git show 8d21b56:memory-bank/progress.md | sed -n '186,349p'`, which is byte-identical (`cmp`) to the
text below. Nothing was summarised or reflowed. A pointer with the original heading stays in
`progress.md`, so `progress.md 2026-09-11` citations still resolve. Line-number citations of it
(`progress.md:264` in `docs/backlog/merge-gate-misses-gh-global-flags-graphql-and-powe.md`) were
already stale before this move. One reference in the text below, "the 2026-09-01 bullet below",
points at a rule now in `docs/archive/progress-2026-09-01-review-rounds-4-5.md` (line 72), not in this file.

---

## 2026-09-11 — whole-repo review: the enforcement layer does not enforce; and a scratchpad collision

**Eleven blocking findings, five domains, whole repository rather than a diff.** Full report preserved
in `WHOLE-REPO-REVIEW.md`, held outside the repository (see "The patch and the report are NOT in
this repository" below) rather than committed:
the payload and the record were split after two review rounds found the payload was 88% of the diff
and essentially all of the blocking findings.
The ones that matter, and the Tier-1 conflict they sit inside:

- **The review gate mints a valid marker for an UNREVIEWED tree — REPRODUCED on both shells.**
  `review-reminders.sh` consumes the marker and writes `.pending-commit-presha` *before* the guarded
  tool runs; if the call is then denied by any other hook, PostToolUse never fires and the residue
  survives. `review-reminders-post.sh:43` then recomputes `diff_hash HEAD` at post time and writes it
  as a fresh marker, so any later command whose text matches the verb launders the current tree into
  an approved one. An `echo` is sufficient. Nothing stores the reviewed hash, so the reissue could not
  be validated even in principle: the binding was missing, not the check. Sharpens `[NS-45]` (filed
  INFERRED, never reproduced) and `[NS-24]` Task #33; strengthens `[NS-26]`'s `peek_marker()` case.
  Two orphaned presha files sit in `.claude/worktrees/strange-bun-9a0ffc` and `sweet-poincare-ee03fc`.
- **Two CI jobs cannot fail.** `.gitleaks.toml` has no `[[rules]]` and no `[extend] useDefault = true`,
  so gitleaks runs an empty ruleset — reproduced with 8.30.1: no config finds two planted secrets, this
  config finds zero. `standards/SECURITY-GUARDRAILS.md:394` asserts the opposite, on a public repo.
  Separately `show_doctor()` contains no `exit` in either runtime, so `MB Doctor Self-Check` passes
  while printing `[ERROR]` lines. Both are among PR #25's passing checks; `gh pr checks 25` names
  them as `Secret Scan` (`pmb-health.yml`'s gitleaks job) and `MB Doctor Self-Check`; no tally is
  stated here because the live one moves.
  **No historical hit is a live credential** — checked before recording any of this on a public repo:
  running gitleaks with `[extend] useDefault = true` over this branch's own line of history — the clone
  is grafted at the parentless `030662c` (`cat .git/shallow`), so the scanned range is at most
  `git rev-list --count 030662c..HEAD` plus that commit, NOT the project's full history, and no
  full-history scan has been run from this clone — returns findings confined
  to `fixtures/security/`, two `docs/superpowers/plans/` files and the two `MCP-SECURITY.md` copies,
  and every secret value inspected is a visible placeholder. A planted canary was detected by the same
  config, so it discriminates. The count is deliberately unstated: it differs between history mode and
  worktree mode, and the report's own figure did not reproduce in either.
- **Two Tier-1 conflicts, surfaced not reconciled.** `projectbrief.md:26` requires that security
  guardrails "are always active" and `:43` forbids external dependencies. The findings above are
  measured breaches of the first. The second is contradicted already, and was before this work:
  `_review-gate-lib.sh`'s `resolve_cd_root()` shells out to `python3` and `check-contract.sh`
  requires it outright, under a documented "fail open on missing dependency" convention. The fix adds
  another caller, not a new class of dependency — for the current caller set run
  `grep -rln 'python3 -c\|python3 -' scripts/`, which is wider than the two named here — an earlier draft of this entry mis-scoped it as
  something the fix would introduce, which was wrong. `techContext.md`, the stable-tier authority on
  the toolchain, records none of it. Tier 1 governs, so this is a decision to be taken rather than a
  drift to close quietly: amend the constraint deliberately, or reimplement the python3 callers in
  shell. Not taken, and older than this change.
- **The gate is wired to one of two doors.** The `PowerShell` matcher runs `dangerous-commands.ps1`
  only; `review-reminders` is bound to `Bash` alone, so a commit, push or PR merge issued through the
  PowerShell tool meets no marker check. `review-reminders.ps1:56` never inspects `tool_name`, so the
  gap is wiring, not capability. Most hook entries also fail OPEN when their pwsh twin launches,
  drains stdin, then exits non-zero: the bash fallback reads an empty stream and exits 0. No count
  is stated — an earlier draft said "eight of nine" and both numbers were wrong; parse
  `.claude/settings.json` for the current one.
- **Fourteen ordinary argument forms walk past both tiers**, each measured against a matched control
  that was correctly denied: `git -C <dir> commit`, `git -c k=v commit`, `git -C <dir> push`,
  `gh api .../pulls/N/merge`, and ten BLOCK-tier forms including `git push origin main --force`,
  `rm -fr`, `rm -r -f`, `dd bs=... of=... if=...`, `curl | /bin/bash` and `curl | python3`. Both twins
  also allow `rm -rf /` under a `toolInput.command` harness, widening `[NS-50]`(b) to the ps1 side.

- **Four findings summarised here because the report that holds them is out of repo**, and this entry
  itself calls it unrecoverable if that directory is lost. No sole-record claim is made: that needs a
  per-finding search with its scope stated, and B10 in fact has a fuller in-repo record than this
  summary at `scripts/mb.sh:2062-2076` — an earlier draft of this bullet asserted the opposite for all
  four at once, which is the absence-claim shape `standards/CODE-REVIEW.md` rejects. (B8) The push gate's hash comparison had zero
  test coverage — a mutation deleting the comparison left the suite fully green. (B9) A test removes
  the live review-gate library from the working tree while it runs, disarming the gate for any
  concurrent session. (B10) `mb upgrade` on PowerShell force-overwrites `standards/` from templates
  that are known stale, so it can replace a correct governance file with a wrong one. (B11) Two
  `mb doctor` checks cannot fire in this repo or in a fresh adopter. Full text: `WHOLE-REPO-REVIEW.md`
  in the preserved directory.

**A fix for the marker binding, the argument forms and the case hole is built and mutation-proved,
and is NOT applied. It does NOT cover the interpreter wiring** — an earlier draft of this entry
claimed it did, which was false: `grep '^+++ ' gate-fix-v2.patch` lists eight files, none of them
`.claude/settings.json`, where the wiring defect lives. That matters more than the error, because
the wiring is the bypass on the PRIMARY path here: pwsh runs first, and `review-reminders` is bound
to the `Bash` matcher alone, so the fix as built leaves the live hole open. Named rather than numbered: an earlier draft said "the first,
third and fourth" into a list that has since gained a bullet. It also closes a PRE-EXISTING hole this
branch is named for — both matchers compared the executable case-sensitively, the parser via a
case-sensitive basename that kept `.exe` and the raw fallback via lowercase literals in a `case`
statement, so the uppercase and `.exe` spellings walked past both. Windows and macOS default
filesystems are case-insensitive and this repo develops on Windows.

The patch and the report are NOT in this repository. They are preserved at
`C:/Users/Mizzo/Claude/pmb-session-artifacts/2026-09-11/`, deliberately: their whole reason for existing is
that the fix cannot land until the PowerShell half is written, so committing them meant carrying a
holding pen through review. Two rounds established the cost — the payload was 88% of the diff and
23 of round 2's 38 findings were introduced by the previous round's own remediation. The durable
record is what belongs in the memory bank; the payload gets its own review when it is worth one, and
may not need one at all: once the fix is applied, the classifier and harnesses exist as real files
under `scripts/` and `tests/` and a copy of an applied patch is dead weight.

**The figures that were here have been deleted
rather than corrected.** They were v1's, and every count disagreed with the harnesses; deleting
decaying figures beat correcting them every time (`f70e84a`). What survives restating
is qualitative: every guard in v2 goes red when removed, and the one guard whose mutation left the
suite GREEN was redesigned out rather than kept, because a race is not something a sequential test can
prove. Only the bash half exists; applying it alone would leave the primary path unfixed, since
pwsh runs first here.

**`activeContext.md`'s cap is still open and 29% of its pending-work list was mis-declared.** Read
its margins the way the 2026-09-01 bullet below already prescribes — both dimensions live, act on the
tighter — not from any level named here. Two attempts to trim it were reverted, and the pressure is
`[NS-42]` in the field: the same squeeze pushed the PR #12 disposition into a gitignored `handoff.md`
that the tooling then tells the operator to delete (`[NS-52]`). `Next Steps` holds almost all of the
file, so any trim has to come from there.

Every `[NS-N]` entry then present was re-verified against the repository rather than read — the rule
being that a self-attested completion counts as UNMET — and it held: **14 carried a status the repo
contradicts.** For the current denominator run
`grep -cE '^[0-9]+\. \[NS-[0-9]+\]' memory-bank/activeContext.md`; it is one higher than the pass
saw, because `[NS-52]` is added by this same change. `[NS-33]`'s WIP is in `stash@{0}`, not the working tree it claims, so a successor would
look, find nothing, and conclude it was lost. `[NS-13]` still tracks writing an implementation plan
that is already written and committed. `[NS-8]` says `mb.sh` hardcodes a command list it no longer
hardcodes. Those corrections are NOT applied here; only the finding is recorded.

**Attempt 1 — have the verifying agents rewrite the entries they had just checked.** Reverted. Its
own review found the rewrite introducing factual errors at close to the rate it corrected them: a
miscount inside a correction, a branch tip pinned into the very file that forbids pinning counts, and
a commit cited that `merge-base --is-ancestor` places outside this shallow clone's history. **A
verifying pass is a good detector and a bad author.**

**Attempt 2 — move the eight largest entries out verbatim, leaving generated pointers.** Also
reverted, for two reasons worth keeping. First, "a move cannot fabricate" was true of the move and
false of the pointer generator: a non-greedy `**...**` match terminated on the `**` inside `[NS-48]`'s
inline code span, emitting a truncated title that dropped both the consequence and "NOT APPLIED",
while `[NS-26]` lost its operative rule — "do NOT rebase or replay" fell to zero occurrences in the
live file, the rule that stops a worktree-branch merge regressing the review gate. Second, the
destination is measured unread: `docs/RETRIEVAL-BASELINE-2026-09-09.md`, committed the same day,
found content unique to `docs/archive/` entering zero of sixteen sessions while the pointer loaded in
all sixteen. `CLAUDE.md` loads `memory-bank/` only. Relocating RESOLVED narrative is the validated
use of that convention; relocating live rules is not the same move.

**What the two failures establish is that this cap is not reachable by eviction or by paraphrase.**
Eviction breaks retrieval, paraphrase fabricates, and condensation-in-place does both. The remaining
option is the one `projectbrief.md` already mandates and `CLAUDE.md:9-16` already admits does not
exist — state available at session start, detail fetched on demand — i.e. an index, not a list.
That is `[NS-44]`, it is a design decision rather than an edit, and it is left open deliberately
rather than approximated a third time in the same session.

**The repo's own guards blocked their own repair three times in one session** — an `rm -rf` on a
scratch path, a patch script containing the PR-merge phrase, and a JSON payload piped to a local
script. Each was correct by the rule as written and wrong by intent. That is the false-positive half
of the same text-matching defect the fix addresses, and it is why the substring matcher cannot simply
be widened.

**The `opposition` tool-allowlist caveat got a second, independent observation.**
`.claude/agents/opposition.md:26-35` — added by `d795abb`, the same commit that added the allowlist —
already records that those `Bash(...)` entries "declare INTENT, not an enforced boundary", measured
once on 2026-08-27, and explicitly marks it **NOT established** whether that is general harness
behaviour, version-specific, or a misread. It reproduced on 2026-09-11 in a different session: an
agent spawned under that list ran `sha256sum`, `bash <script>` and a `> file` redirect. A second
observation fifteen days later weakens the version-specific reading without settling the question,
and nothing else changes — that file's operational consequence, that the list is not a security
boundary and a real prohibition belongs in the agent's instructions and in hooks, already stands.
**Orchestration finding, not a repo defect: a subagent silently overwrote another's scratch file.**
Roughly thirty subagents across seven review rounds were all told to write scratch files to one shared
session directory. A round-7 reviewer wrote its own `classify.py` (a transcript hit-counter) over the
gate fix's `classify.py` (the payload classifier) — same name, no namespacing, no collision detection.
The source survived only because it had already been copied into a scratch clone under a different
name. The loss would have been silent, and the worse shape is the one that did not happen: reading
another agent's file as if it were one's own and drawing conclusions from it. **Give each dispatched
agent its own subdirectory, or require a per-agent filename prefix** — a shared flat scratch directory
across parallel agents is a silent data-loss vector, and "write only under <scratch>" is not
sufficient instruction.
