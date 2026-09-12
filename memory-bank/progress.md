---
authority: accumulating
review-cycle: 30d
retention: archive-after-6m
staleness-threshold: 90d
tags: [work/completed, work/in-progress, work/backlog]
last-reviewed: 2026-09-11
compaction_generation: 0
source_type: canonical
confidence: high
lineage: []
---

# Progress

## Relocated 2026-08-12 → 2026-08-18 — five sections moved verbatim 2026-08-28

Moved to `docs/archive/progress-2026-08-condensed-sections.md` to clear the 60,000-byte CI cap; this
file had reached it and could not accept a new dated entry. **12,965 bytes moved out, 1,490 added
back as this stub — net −11,475.** Stated as a delta rather than before/after totals, which decay the
moment anything else in the file changes. **Nothing was summarised or deleted** — the 2026-08-25 pass was reverted for removing content, and this follows the
relocate-verbatim convention that replaced it.

Each original heading is preserved below so existing citations of the form "`progress.md`'s
2026-08-14 entry" still resolve. All five were already marked *condensed, full detail archived*
before this move, so their fuller narrative was already in `docs/archive/context-2026-*`; this
relocation moves the condensed layer out as well.

- 2026-08-12 through 2026-08-14 — Investigation-Integrity Mechanism: Design, 5 Independent Review Rounds, Stale-Marker Hook — condensed, full detail archived
- 2026-08-17 — Review-Gate Layered Enforcement: All 14 Tasks Implemented and Committed — condensed, full detail archived
- 2026-08-17 (continued) — Branch-Ancestry Diagnosis, Handoff/Compaction Gap, Standards-Freshness Gap, Review-Gate Hardening Audit — condensed, full detail archived
- 2026-08-18 — `dangerous-commands.sh`/`.ps1` Git-Merge CONFIRM Hardening (Task #30, committed `499dbe5`) — condensed, full detail archived
- 2026-08-18 (continued) — Tasks #33–#35, Version-Notifier Fix, Handoff Redesign — condensed, full detail archived

## Relocated 2026-08-19 → 2026-08-21 — four sections moved verbatim 2026-08-28

Moved to `docs/archive/progress-2026-08-19-to-21-escalation-and-bundle-1.md` **verbatim**, not
summarised. **Delta, not a level: 16,670 bytes moved out.** Citation survival grep-verified before
the move. The citation surface is larger than a short list captures — `activeContext.md` alone
carries five references to these entries, enumerated in full in the archive header — so the check
that matters is that each original heading is preserved below, which it is.

- **2026-08-19 — Model/Effort Escalation Guidance; Review-Gate Port Design Corrected (Opus deep dive)**
- **2026-08-20 — Archive Pass; Session-Crossed-Midnight Dating Error Caught by the Gate It Broke**
- **2026-08-20 (continued) — Enforcement Integrity Bundle 1 (committed 2026-08-21 as `4bc107c`)**
- **2026-08-21 — Bundle 1 Committed; Hook-Wiring Fix Withdrawn by Its Own Review**

## Relocated 2026-08-22 → 2026-08-27 — six sections moved verbatim 2026-08-30

Moved to `docs/archive/progress-2026-08-22-to-27-gate-passes-and-bundle-review.md` **verbatim**, not summarised. **Delta, not a level: 20452 bytes moved out.**
Citation survival grep-verified before the move; each original heading is preserved below and in
the archive file, so existing `progress.md` <date> references still resolve.

- **2026-08-26 — PR #21: round-10 gate pass, Approve + 4 must-fixes**
- **2026-08-26 (continued) — `[NS-37]` closed at the mechanism; a measured perf revert; cap deadlock resolved by relocation**
- **2026-08-26 (later) — review-gate model pinning; `mb upgrade` agent-delivery fix; tiered-loading design DROPPED on review**
- **2026-08-27 — Full `/code-review` of the five-concern bundle; 24 findings remediated; three new mechanism bugs**
- **2026-08-23 (continued) — Cap Deadlock Cleared by Relocation; Round-6 Pre-Gate Hardening**
- **2026-08-22 — Commit-Signing CONFIRM Tier; Two Review-Driven Corrections; Midnight Gate-Expiry Found**

## Relocated 2026-08-28 — five sections moved verbatim 2026-08-31

Moved to `docs/archive/progress-2026-08-28-round3-gate-passes-and-brief-staleness.md` **verbatim**, not summarised. **Delta, not a level: 30,235 bytes moved out** (LF blob — an earlier draft said 30,448, the CRLF worktree figure).
Citation survival grep-verified before the move; each original heading is preserved below and in
the archive file, so existing `progress.md` <date> references still resolve.

- **2026-08-28 — `[NS-22]` committed; Cursor's handoff threshold re-derived; `[NS-22]` action 3 closed as not-a-defect**
- **2026-08-28 (later) — `d550282` committed; branch `/change-review` run; the nine-instance pattern named**
- **2026-08-28 (continued) — Round-3 pass, Opposition Approve, committed `2052c3c`**
- **2026-08-28 (fix) — `mb init` agent delivery closed; the exported Work-MB briefs found stale**
- **2026-08-28 (eviction) — `activeContext.md` resolved-entry pass; its own finding was false**

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

## 2026-09-09 — a CI check that had never been able to fail, and what found it

**It was found by planting a violation, not by reading.** The invisible-Unicode guard over
`standards/`, `CLAUDE.md` and `templates/CLAUDE.md` had never once been able to fail since the day
it was written, so every green CI run was evidence of nothing. Mechanism and fix: `1f7a7e7`. The
durable part is what found it — **a check never given something to catch is indistinguishable from
one that cannot catch anything.** Five of the seven extracted checks still have no
detection-efficacy coverage; closing them is what changes the cost of the *next* inert check.

**The mutant space has axes, and hunting one mutant at a time never enumerates them.** The fixture
took four attempts, each defeated one axis over — one "fix" was a regression described as an
improvement. It ended by splitting the space into code-point coverage (unbounded, so closed by
argument) and everything else (finite: scope roots, plant position, status branch) — an open-ended
hunt became three cells that could be closed, and were.

**Several of my own verification commands did not verify what they claimed** — a pipe to `head`
(always exits 0), `&&`-chained greps (a no-match aborts the rest), a non-matching `sed`, a grep
whose escaping printed nothing, and a CR-counting grep that matched every line and produced a false
CRLF finding I asserted aloud before catching it. Four failed silently; the one that failed loudly
did so because mutations ran through a Python `assert` on the substitution count. **The fix is not
more care, it is making the check unable to pass without doing its work** — the same principle as
the bug being repaired, applied to the tooling that verifies the repair.

**The commit gate denies on a bare substring, and the denial destroys the marker — REPRODUCED.**
`review-reminders.sh:87` matches `*'git<SP>commit'*` against raw stdin (spelled with `<SP>` here
deliberately — the literal form denies the very tool call that writes it). `consume_marker()`
(`:74-84`) renames and `rm -f`s the marker *before* comparing hashes, with no restore on denial. So
any tool call whose payload merely contains the substring destroys a valid, expensively-earned
review marker. Matched control pair, no git invoked either time: an `echo` containing the substring
was denied, the same `echo` with it broken passed. Three natural instances in one session — a grep
of the hook's own source, a contract file, and this entry. The comment at `:39` asserts the false
premise that the substring "only plausibly" appears inside a command field. Sharper than `[NS-45]`
(filed INFERRED-not-reproduced, and at least an attempted commit); `[NS-25]`'s bug on the commit
side. **Self-suppressing: it blocks its own documentation.**

**Archived detail entered zero sessions while its pointer was loaded by all of them.** `activeContext.md`
has pointed at `docs/archive/context-2026-08-20-narrative-sections.md` since the 2026-08-20 eviction —
externalization with a handle, already shipped. Measured 2026-09-09 by transcript search for content
unique to that file, so a hit means the content entered a session rather than the pointer merely being
loaded: across the **16 main-worktree-directory sessions first-dated 2026-08-22 → 2026-09-09 (UTC) it
entered zero**, while the pointer was loaded in every one. Worktree sessions write to their own
project directory; widening to all nine gives 17/0/17, so the zero is scope-invariant and only the
denominator moves. Protocol, unit, command and limits:
`docs/RETRIEVAL-BASELINE-2026-09-09.md` — kept outside `memory-bank/` so the sessions it measures do not
read it at start.

**What zero does and does not settle.** It is undiagnostic between "never needed" and "needed, never
fetched"; only a task whose correct answer requires the archived detail separates them. It is the same
shape `[NS-27]`'s rule showed on 2026-08-31 (`[NS-47]`(d)'s caveat): archived, pointed at, on-topic, not
retrieved. The pointer was rewritten (the commit landing this entry) because a bare path gives a session no
reason to open it; whether a described handle changes the rate is what the doc's re-measure section exists to find out.

**Correction — the review-gate defect recorded above has been fixed THREE times and merged ZERO
times, and all three fix only half of it.** The reproduction this session was real; the discovery was
not. Three distinct patches to `scripts/review-reminders.sh` (`git patch-id --stable` differs for
each; none has landed, per `git show origin/main:scripts/review-reminders.sh | grep -c
extract_command` returning 0 — do **not** use `git merge-base --is-ancestor` here, because this clone
is shallow and that check answers NO even for commits that are on main, `ea862e8` being the control):
`2fa55b8` (2026-07-27,
PR #10's branch `claude/keen-carson-b30c44`, pushed — the only one of the three that also patches
`review-reminders-post.sh` and its mirror; all three add a description-field case to
`tests/test-review-reminders.sh` — `--stat` for the file list, `git show <sha> --
tests/test-review-reminders.sh` for the case itself, since `--stat` shows counts and never content),
`656a4d2` (2026-07-27, 75 minutes
later, branch `claude/strange-bun-9a0ffc`, **never pushed** — verifiable only on the machine holding
that branch), and `fe73e13` (2026-08-08, twelve days later, branch `fix/review-reminders-raw-stdin`,
pushed as PR #11). The last two share an identical subject line — "fix: extract tool_input.command in
review-reminders.sh instead of matching raw stdin" — but not a body, and neither branch contains the
other: independent rediscovery, not a cherry-pick.
`git show origin/main:scripts/review-reminders.sh | grep -c extract_command` returns **0**: none has
landed.

**What they fix, and what they do not — this sharpens `[NS-24]` Task #33 and `[NS-45]`, and
strengthens `[NS-26]`'s `peek_marker()` case.** All three match on the extracted `tool_input.command`
on the success path, falling back to raw stdin when extraction fails — the description-field half of
the entry above, minus the parse-failure path. `.pmb-hook-errors.log`'s 160 entries are all
`dangerous-commands.ps1` JSON-parse failures on hook stdin, so malformed payloads demonstrably reach
hooks here; that review-reminders' own fallback fires is **INFERRED**, since neither review-reminders
hook writes that log. None changes
the `*'git<SP>commit'*` substring match on the command text itself, and none moves `consume_marker()`'s
rename-and-delete after the hash compare (`git show 2fa55b8:scripts/review-reminders.sh`, lines
229-249: the rename at 232, the delete at 237, the compare at 249), so a command whose text merely
mentions the verb is still denied, and still destroys the marker, after any of them lands. On this
machine `pwsh` 7.6.5 is on PATH and `settings.json` runs `review-reminders.ps1` first, which already
extracts the command (`:56`), regex-matches the verb in it (`:111`), and moves-then-deletes the marker
before the compare (`:90-108`). **INFERRED, not measured:** that the trips recorded above came through
that path follows from hook order plus `pwsh` being present, and neither hook writes
`.pmb-hook-errors.log`, so no artifact records which interpreter denied. What IS measured, by running
both directly: description-only payload → ps1 allow, sh deny; verb in command → both deny. So the
description-field defect is live here only when `pwsh` fails to launch, and every one of the three
fixes leaves the command-text half untouched on both interpreters.

**The durable lesson is not the defect, it is the merge rate.** Three independent fixes to one half of
the defect and no landing means the cost is paid repeatedly in rediscovery while the whole defect stays
live. Cite commits, not session dates: commits are verifiable in-repo and session dates are not. The
re-measurement in `docs/RETRIEVAL-BASELINE-2026-09-09.md` is pointed at from `[NS-44]`, not scheduled —
`activeContext.md` has no headroom for an entry.

**The Next Steps drain is unblocked, and deliberately not done here.** `cbd988c` gave this file the
room that completed items drain into — the stated dependency when this morning's contract deferred
it. Still deferred: 33+ completeness judgements, each needing a citation-survival check, and
`[NS-4]`/`[NS-24]`/`[NS-37]` all have live inbound citations. For whoever takes it — that contract
lists `[NS-30]` among the resolved; it reads "Shipped… but NOT closed in the field."

## 2026-09-01 (round 5) — why the exit-code table stopped enumerating, and the cost of four rounds

- **Round 4's remediation produced FOUR new blocking findings across three domains, one live-reproduced.** Security
  built a diff with an oversized file section, ran `--chunk --format json`, watched the console print "Diff
  truncated" — and the JSON carried **no `truncation` key at all**, exit 0. `chunkRunner`'s merge drops it. So the
  first of the four signals I had just wired was structurally unreachable, and exit `3` is dead code for this
  workflow. Correctness found row `1` still naming a markdown banner that `--format json` never emits. Architecture
  Drift found row `0` and the last-chunk-wins caveat giving OPPOSITE verdicts for the same state — a
  self-contradiction introduced inside the block rewritten to remove a self-contradiction.
- **THE DIAGNOSIS, and it is the durable part: we were maintaining a precise static description of a moving
  target.** `ai-review-agent` is an `npm link` into another session's working tree, on an arbitrary branch, rebuilt
  without warning; its behaviour changed at least THREE times during one session, and `--version` does not identify
  what ran. Every enumeration was correct when written and wrong by review time, and each correction introduced a
  fresh contradiction because the file carried five interlocking claims about internals. **Defect rate stayed flat
  across rounds 3-5 while care increased — that is the signal that the approach, not the diligence, was wrong.**
- **Fix: state the INVARIANT, not the enumeration.** Exit `0` never earns an unqualified clean pass; the field list
  is explicitly INDICATIVE, not exhaustive, with the two known-unreliable fields named. **The lookup surface shrank per ROW
  and the file did not:** the two rewritten ROWS lost 537 B per mirror (row `0` 1,042 -> 756, row `1` 890 -> 639 —
  whole-row lengths, not single cells; a later review measured cell 4 alone and got different figures for that reason; and row `0` was rewritten AGAIN in `c84b06d` to 1,198 B, its longest yet, so 756 is a round-5 figure and not a current one),
  while each mirror grew 2,340 B net, because the rationale moved out of the rows into a longer block quote that
  adds internals of its own. An earlier draft of this bullet claimed ~4,850 characters DELETED across both mirrors —
  sign-inverted, and caught by the round-6 review. Removing three of the four blocking findings **by deletion rather
  than by another correction** is what the fix bought; a smaller artifact is not. Generalises: **when a description of an external
  system keeps going stale faster than you can correct it, stop describing the system and state what must hold
  regardless of it.**
- **The fourth blocking finding was a different class and is fixed separately.** `MEMORY-BANK-CAP-ALLOCATION-FINDING.md`
  restated five cap values CI ratcheted DOWN on 2026-08-30, and §2's finding had already been ACTED ON — the caps
  moved *because of it*. Dating covers a decaying measurement; **a restatement of governing config that changed
  structurally needs superseding, not dating.** Fifth instance of the class `standards/MEMORY-BANK.md` already
  tracks. Banner added; caps now point at `pmb-health.yml`.
- **Also caught: condensing `[NS-47]` pointed its detail at a Downloads file** — out of repo, uncapped,
  unreviewable in a PR, which are the exact two disqualifiers `[NS-35]`(2) used to reject native auto-memory as a
  store. Six facts existed nowhere in the repo. Entry now marks the destination OUT OF REPO and names `progress.md`
  as the in-repo source. **Relocating detail out of a capped file into an uncapped one is hiding, not archiving.**
## 2026-09-01 — the Request Changes round: what blocked, and two reversals of my own

- **The blocking finding was not about operational risk, and that distinction is the useful part.** Row `0`'s
  fourth signal was unreachable, but the row it replaced instructed no body reading at all — so nothing got
  WORSE. What blocked was the **durable false record**: `progress.md` listed the signal among five CLOSED
  limits when it had been added to the table and not the procedure. In a repo whose product is governance
  memory, a wrong "closed" outlives a wrong instruction. **Blocking on the record, not the runtime.**
- **Four domains reached that finding on a premise Opposition disproved.** They argued the four signals needed
  TWO 200s runs (three markdown-only, one JSON-only). False: `formatJson()` serialises the whole result
  object and the "markdown-only" signals are derivations of fields ON that object, so ONE `--format json`
  run yields all four. **Convergence is not corroboration when the domains share a premise** — four agreeing
  reviewers were all wrong about the cost, and only the one that read the formatter caught it.
- **I reversed my own recommendation twice, and both reversals came from reading source I should have read
  first.** (1) Recommended removing ACR's `**/*.md` exclude without checking why it exists — it guards a
  REPRODUCED failure (agents with zero file-type awareness misreading prose as code), and this repo's
  `standards/` is the worst case for it. (2) Over-corrected to "excluding markdown is correct by design" —
  falsified in one command: on the diff under review **all six** `.md` files were excluded (verified 2026-09-01 by calling ACR's own `matchPattern`), two of them copies of `change-review.md`,
  the gate's own definition. **The real axis is inert prose vs executable instruction; a file extension is a
  failing proxy for it in a repo where markdown IS the mechanism.** Now `[NS-48]`, deliberately not applied.
- **`activeContext.md`'s binding dimension FLIPS between bytes and lines, so read BOTH live.** Condensing `[NS-47]` to a pointer bought byte headroom back; a later trim removed lines and inverted it again. No absolute is quoted here on purpose — every figure this bullet has carried went stale within days, including a "149 of 150 lines, exactly ONE more fits" that a trim on this same branch invalidated in both directions at once.
  Read each margin as `pmb-health.yml`'s cap minus the live measure — `git cat-file -s` for bytes, `wc -l` for lines — and act on whichever is tighter, not whichever this file last named. Bytes have been the tighter of the two throughout, but the ratio is deliberately not quoted: an earlier draft said "roughly 8x" and the very edit that introduced it moved the figure to ~5.8x. A trim that counts only one dimension will not help.
## Relocated 2026-08-29 → 2026-08-31 — four sections moved verbatim 2026-09-11

Moved to `docs/archive/progress-2026-08-29-to-31-gap-fixes-and-durable-lessons.md` **verbatim**, not
summarised. **Delta, not a level: 12,448 bytes moved out.** Without the move this file could not have
accepted the 2026-09-11 entry at all — the same cap deadlock recorded on 2026-08-23 and 2026-08-28.
No level is quoted, and none should be reconstructed from this stub: read both margins live against
`pmb-health.yml`'s caps.

Citation survival grep-verified before the move; each original heading is preserved below and in the
archive file, so existing `progress.md` <date> references still resolve.

**STILL OPEN — carried forward, not relocated.** The four sections below are archived narrative, but
four of their findings are self-marked unfixed, and `CLAUDE.md` loads `memory-bank/` only, so the
archive cannot hold a live rule. (1) **The BLOCK-tier hook receives TRUNCATED payloads**:
`.pmb-hook-errors.log` has carried `Unterminated string` since 2026-08-17, the hook then falls back
to matching raw text, and **a BLOCK substring past the truncation point is not seen** — undiagnosed,
and separate from the OEM-code-page fix. (2) **Mutate a scratch copy, not the shared tree** —
copy-aside-and-restore can revert a peer's concurrent edit, and checksum-verifying the restore proves
your copy intact, not that nobody else wrote. (3) ACR availability is decided in two places with
different criteria, and `mb preflight` reads `ACR_VER` without ever comparing it. (4) `show_slim()`
and `Show-Slim` exist in both shells and are dispatched from neither.

- **2026-08-31 (post-review) — the gap fixes, and the one finding that came from reading ACR's source**
- **2026-08-30 — two durable lessons; the change itself is in the commit message**
- **2026-08-30 — Contract 1: what the commit message cannot carry**
- **2026-08-29 — absence-claim scope rule (`a11e4df`); a review-gate defect recorded**

## Relocated 2026-08-31 — “what four Opposition rounds cost, and the one rule worth keeping”, moved verbatim 2026-09-09

Moved to `docs/archive/progress-2026-08-31-opposition-rounds.md` to clear the 500-line CI cap; this
file stood at 498/500 and could not accept the dated entry the `PreCompact` gate requires — the gate
demanded exactly what the cap forbade, and the gate was measured exiting 2 before this pass.
**18,208 bytes and 173 lines moved out.** Stated as a delta rather than
before/after totals, which decay on the next edit. Second occurrence of this bind; see the archive
file's header for why that is structural rather than incidental.

## Review rounds 4-9 (2026-08-23 → 2026-08-25) — relocated 2026-08-26, detail in `docs/MEMORY-BANK-PARADIGM-REVIEW.md`

Five dated sections were moved **verbatim** to `docs/MEMORY-BANK-PARADIGM-REVIEW.md` § "Rounds 4-9"
— nothing summarised, reworded or deleted — because this file had 5 bytes of headroom against its
60,000-byte CI hard-fail. Same convention the Round 10 entry already uses. Each keeps its heading
there, so a citation to any of them still resolves:

- **2026-08-25 — Round 9 Completed (all six domains); Separator Hole Closed; Figures Corrected Outward**
- **2026-08-24 (rounds 8-9) — Round 8's Fixes Rejected by Round 8; Round 9 Then Found the Gap Class Was Itself a Bypass**
- **2026-08-24 (continued) — Review Round 7 — condensed; all five findings superseded by rounds 8-9**
- **2026-08-24 — Review Round 6: One Blocker, Two Pre-Existing Bypasses Closed, Cap Metric Fixed**
- **2026-08-23 — Review Round 4: A Pre-Existing Critical, and a Fix Withdrawn** — cited by `[NS-35]`

## 2026-08-12 — Fleet Version Drift Incident (reported, not yet fixed)

- 📌 ACR drifted 2 versions behind PMB and ran a 13-task feature under stale governance hooks before
  it was caught; still unfixed. Current state: `activeContext.md`'s `[NS-14]`.

## Earlier Work (2026-07-02 through 2026-08-10) — condensed, full detail archived

- **2026-07-16 through 2026-08-05 — Review-gate mechanism evolution**: self-attestation fix (marker-write
  moved into the last dispatched review subagent), a false-positive fix in `review-reminders.sh`'s
  command matching, the confirm-step redesign (durable `docs/review-log/` + user-confirmed marker write),
  a worktree-root-resolution fix (closed a real denial-from-inside-a-worktree bug), a hook-lib dedup
  (`_review-gate-lib.sh`/`.ps1`), and the confirm-step's first live whole-branch review (found and fixed
  one real Blocking finding). Full detail: `docs/archive/progress-2026-07-review-gate-evolution.md`.
- **2026-07-02 through 2026-07-13 — Repo governance, CI hardening, branch protection**: `mb upgrade`
  slash-command auto-discovery fixes, 4 pre-existing CI failures closed (SAST config, 2 false-positive
  greps, PowerShell lint), CI hardening across 3 downstream repos, branch protection rolled out to 5
  public repos, a real hash byte-mismatch bug fixed (bash vs. PowerShell diverged on trailing-newline
  handling), the cross-repo write boundary hook built after a real incident (this session wrote into
  another repo's working directory without checking ownership), and the review-flow fleet audit (found
  real enforcement in only 2 of 11 repos). Full detail:
  `docs/archive/progress-2026-07-repo-governance-and-ci.md`.
- **2026-07-14, 2026-07-23 — `mb backlog` Task 1 + mb update-notifier**: `mb backlog`'s Task 1 shipped
  with two real Critical/High security bugs found and fixed (path traversal, sed-delimiter injection);
  Tasks 2-5 not started (`[NS-0]`). The update-notifier shipped clean, but the same session produced an
  authorization-drift incident (a "what do you suggest" non-answer treated as merge approval) that
  produced the "What Counts as Approval" rule. Full detail:
  `docs/archive/progress-2026-07-mb-backlog-and-notifier.md`.
- **2026-08-08, 2026-08-10 — Concurrent session claims + memory-bank freshness hook**: session-claims
  shipped (13 tasks + 5 post-review fixes, including one found only by a final whole-branch review after
  every individual task had already passed its own two-stage review); the freshness-hook spec was
  designed and committed but not yet implemented (`[NS-13]`). Full detail:
  `docs/archive/progress-2026-08-freshness-and-session-claims.md`.

## Backlog

Deferred pending operational evidence: handoff CLI, pinned.md, mb update --from-git, mb privacy.

## Reference Sections — relocated 2026-08-23

Project inventory, scope-delta vs enterprise, the 2026-06-19/24 session summary, and satellite-project
pointers moved **verbatim** to `docs/archive/progress-reference-sections-2026-08-23.md` to recover line
headroom under the 400-line CI cap. Nothing was condensed or rewritten. `## Backlog` stays above because
it is still actionable. One-time recovery, not a fix — see `[NS-35]` decision 3.
