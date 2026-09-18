---
authority: accumulating
review-cycle: 30d
retention: archive-after-6m
staleness-threshold: 90d
tags: [work/completed, work/in-progress, work/backlog]
last-reviewed: 2026-09-17
compaction_generation: 0
source_type: canonical
confidence: high
lineage: []
---

# Progress

## 2026-09-17 — Recovery-only Codex review

- Full independent diff review covered security, performance/reliability, style, test coverage, and an adversarial audit. Security, performance, and style found no actionable issues; `git diff --check` and the focused suites remained clean.
- The adversarial audit found two MEDIUM issues: invalid JSON in both hook-config mirrors can make the structural test skip its assertions, and the now-historical implementation plan still instructs future agents to restore the removed blocking `PreCompact` gate. The user requested a handoff before authorizing either fix.

## 2026-09-16 — Codex PreCompact reproduction and pending UX review

- PR #27 is merged on `main` at `5c386808`. Its project-local Codex hooks were trusted and enabled by the user; the user later disabled `PreCompact` only to isolate an observed failure, leaving `SessionStart` enabled.
- Three reproductions showed a brief “Thinking” state followed by no assistant response with `PreCompact` enabled. The live Windows adapter emitted `{"continue":false,"stopReason":"Compaction paused — PMB state needs attention."}` and exited 0; its delegated gate exited 2 because `progress.md` had no entry dated 2026-09-16. Per official Codex hooks documentation, `continue:false` on `PreCompact` stops before compaction. The observed desktop UI did not surface the accompanying `systemMessage`, making this a silent turn-loss UX failure rather than a hook hang.
- Active user-approved wording diff remains uncommitted: 12 files, 13 insertions/10 deletions. Focused verification passed: `test-pre-compact-check.sh` 23/0, `test-codex-compaction-hooks.sh` 26/0, `test-mirror-parity.sh` 148/0. User requested a deeper official-docs review; policy redesign is pending and must be approved before implementation.
- Official-documentation review confirmed that no alternate Codex lifecycle hook can both block automatic compaction and guarantee an actionable continuation. The user approved recovery-only Codex support: `.codex/hooks.json` now retains only `SessionStart(source=compact)`, and the paired adapters emit recovery context only. Claude Code retains the existing executable gate; the checker remains available as an explicit Codex diagnostic.
- The active contract was superseded for the policy correction. Focused verification after the change: pre-compact 23/0, Codex recovery 17/0, mirror parity 146/0; `git diff --check` is clean.

## 2026-09-15 — review-gate paired paths corrected and opposition-approved

This branch closes three reviewed bypasses: classifiers collect every guarded invocation and emit `MULTI`; quote-aware, syntax-specific launcher handling avoids scanning arbitrary data; and unverifiable push recovery is declined while commit recovery remains bound to `HEAD` and the reviewed hash. Live/template twins match.
Focused evidence: classifier 39/39, classifier/wiring Pester 23/23, hooks 71/71, installer 23/23, upgrade 49/49, presence 14/14, Windows installer 14/14, and mutation baseline 44/44 with 15/15 removals detected; the corrected harness recovered two unintended local baseline commits without losing changes.
The permitted opposition re-check approved the corrections. Final CI-equivalent suites passed once: every registered Bash suite and Pester 128/128. PR delivery remains.

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

## 2026-09-14 — baseline-health's CI-only failure was a shallow nested-clone ref assumption

`tests/test-baseline-health.sh` passed locally but its two `--no-fetch` ratchet assertions failed in
`MB Command Tests`. Reproducing Actions' actual topology (shallow checkout, `origin/main` fetched,
detached HEAD, no local branch) produced 42 pass / 2 fail: `new_sandbox` cloned the checkout and
assumed that carried `origin/main`. It does not -- clone sources do not advertise remote-tracking
refs, so the nested sandbox could not perform the comparison once `--no-fetch` suppressed recovery.
The first correction used a direct local refspec transfer and passed a detached but non-shallow
reproduction. It still failed in CI: from a shallow source Git copied the object, rejected the ref
update, and returned success, leaving the same advisory skip hidden behind a green setup command.

**Fixed in the harness only:** `new_sandbox` fetches the source checkout's already-fetched main
object via the local repository path, then creates and verifies `refs/remotes/origin/main` as a
separate step. This performs no network access and leaves `scripts/baseline-health.sh`'s fetch
interceptor unchanged. The identical shallow, detached topology is green at 44 pass / 0 fail after
the change.

## 2026-09-13 — check 15's real cause found and fixed: `$env:USERPROFILE`, not the bracket glob

The 2026-09-12 entry below attributed check 15's CI failure to the bracketed-`MB_HOME` divergence
(`[NS-51]`). That attribution was wrong, not merely incomplete: reproduced in Docker
(`mcr.microsoft.com/powershell:latest`, matching `ubuntu-latest`'s no-`cygpath` code branch of
`tests/test-mb-doctor.sh` -- a Windows-side repro attempt takes the OTHER branch and passes clean,
which is why this took a second look). The real error, `Cannot bind argument to parameter 'Path'
because it is null`, comes from `scripts/mb.ps1:112` and `:1233` -- both used
`Join-Path $env:USERPROFILE ...`, a Windows-only env var that is null on Linux/macOS pwsh. (`:113`,
`:117`, `:147` merely consume the already-computed path; they are not independent bug sites, despite
what this entry said on first write.) Non-terminating error, so `doctor` still completed and looked
healthy afterward -- but the forbidden string still appeared and failed the assertion.

**Fixed**: both sites now use `$HOME`, matching `scripts/mb.sh`'s existing identical pattern
(`$HOME/.mb`, `$HOME/.claude/CLAUDE.md`). Verified via a 4-domain code-review (Security/Correctness/
Testing/Maintainability+Architecture-Drift): Architecture Drift caught that this entry's first draft
wrongly claimed `mb.ps1` needed a `templates/` TEMPLATE_OWNED mirror -- neither `mb.sh` nor `mb.ps1`
appears in either script's own TEMPLATE_OWNED array, and the CLI ships via `git clone`, not
`mb upgrade`; no mirror exists or is needed. Testing found the existing check 15 coverage of this
class was real but accidental (a generic string match, true only because CI happens to run
`ubuntu-latest`) and that `tests/test-mb-version-notifier.sh` never exercised the actual `$HOME`
fallback branch (both its pwsh invocations always override `MB_VERSION_CACHE_DIR`). Added a dedicated,
Linux/macOS-gated test there, mutation-proven red-on-revert/green-on-fix in the same Docker image.

## 2026-09-12 — PR #25 stays red after the grep-portability fix; a second, pre-existing failure

`tests/test-mb-doctor.sh:1079`, check 15's `Resolve-Path`-throws assertion, fails on Linux `pwsh` in
CI (run `34683137897`) alongside the grep-mutation failure fixed on `fix/baseline-health-ci-portability`
-- independent of it, not introduced by either branch. Manifestation of the bracketed-`MB_HOME`
divergence `CHANGELOG.md:58` already tracks as narrowed, not closed, and `[NS-51]` points at the audit
spec for. **Corrected 2026-09-13: this attribution was wrong — see the entry above.**

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

## Relocated 2026-09-09 — one section moved verbatim 2026-09-17

Moved to `docs/archive/progress-2026-09-09-ci-check-vacuity-and-retrieval-baseline.md` **verbatim**,
not summarised — same precedent as every relocation above. **Why:** the Codex PreCompact recovery-only
policy correction's two new dated entries pushed this file to 512 of its 500-line cap and the
aggregate startup-context ratchet 3,057 bytes over `origin/main`. Citation survival grep-verified
(`activeContext.md`'s `[NS-44]` cites the sibling doc, not this section, by name); the original
heading is preserved below so `progress.md <date>` references still resolve.

- **2026-09-09 — a CI check that had never been able to fail, and what found it**

## Relocated 2026-09-01 — two sections moved verbatim 2026-09-13

Moved to `docs/archive/progress-2026-09-01-review-rounds-4-5.md` **verbatim**, not summarised — the
same precedent as every relocation above. **Why:** `progress.md` hit 520 of its 500-line CI cap after
the 2026-09-13 `[NS-51]` entry landed; these were the oldest full-detail sections not yet relocated.
Citation survival grep-verified before the move (`activeContext.md:40`, `[NS-48]`); each original
heading is preserved below and in the archive file, so existing `progress.md <date>` references
still resolve.

- **2026-09-01 (round 5) — why the exit-code table stopped enumerating, and the cost of four rounds**
- **2026-09-01 — the Request Changes round: what blocked, and two reversals of my own**
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
