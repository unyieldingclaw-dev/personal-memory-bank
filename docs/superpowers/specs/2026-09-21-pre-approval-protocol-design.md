# Pre-Approval Protocol

**Date:** 2026-09-21
**Status:** Approved by the user on 2026-09-21, after three rounds of independent `opposition`
review:
- First verdict: Request Changes, findings F1–F8. All addressed.
- Second verdict: Approve with conditions, findings N1–N4. All addressed below; N5 is added to
  spike 2.
- Third verdict: Approve with conditions, a narrow pass on three later changes. Both conditions
  (the audit's scope and promotion rule, and stale block-rate figures) are addressed below.

**Amended 2026-09-22** with two decisions the user took after further review rounds on the plan:
- **The parity conflict:** option A+ (§5).
- **The popup:** it closes itself after 600 s (§3).

Those rounds found that the plan as written would fail CI, because
`tests/test-mirror-parity.sh:354-421` pins the live Stop wiring to the template's.

## Problem

The user has had to supply adversarial review by hand: "are you sure", "dig deeper", "look one
more time", "poke holes". In their words: "As a user, I expect that you have already done that
before you ask me what to choose. I also want you to always provide what you recommend and why."

Each prompted pass on 2026-09-21 found real defects the unprompted version had missed. Among them
were a ~5.6 s per-prompt stall, a false config premise, and a diagnostic hook writing a peer
session's prompt text to disk. The same pattern was recorded in August (six "one more look" rounds,
`2026-08-12-investigation-integrity-design.md`). The existing mechanism is `standards/WORKFLOW.md`
Phase 3.5 (Independent Plan Review), and it falls short in four ways:
- it is advisory;
- it covers plans only;
- it has no command;
- it runs after planning rather than before the user is asked to approve.

It was not applied at any point in the compact-nudge-hook spec's life.

## Decisions Already Made (with the user, 2026-09-21)

| Question | Decision |
|---|---|
| What triggers the protocol | **Anything Claude asks the user to approve or choose**: design recommendations, specs, plans, task contracts, "should I proceed" |
| Who pokes the holes | **Hybrid.** Claude always runs the pass itself. The Opus `opposition` agent is added when CLAUDE.md's Opus-escalation trigger list fires |
| What decides "complex enough" | **CLAUDE.md's existing escalation list**, the single source of truth. It already includes "writing a design spec or implementation plan" |
| What the user sees | **A full findings list every time**, so a clean pass never looks like a skipped one |
| Enforcement | **Protocol text plus a Stop hook.** No document-status check |

## Design

### 1. The protocol (procedure)

Before any message that asks the user to approve or choose:

1. **Run the checks the options depend on.** Execute rather than re-read. Re-derive every number
   being relied on. Measure anything performance-relevant. Read config instead of assuming it.
   Check each claim about a file against the file as it is now.

   Checks must not mutate the shared working tree. For example, `tests/run.sh` moves `VERSION`
   aside and is not concurrency-safe; cite its last run instead of running it mid-ask.
2. **If the ask hits CLAUDE.md's escalation list**, dispatch `opposition` (Opus-pinned) after
   step 1. Give it the artifact, the step-1 findings, and the instruction to attack premises and
   re-derive the load-bearing numbers. Its verdict joins the findings. If it fails, retry once; if
   it fails again, disclose that rather than proceeding silently.
3. **Fix what is within the thing being proposed.** Anything that would change a decision the user
   already made goes under the decision instead.
4. **Send the ask with the required sections** (see §2).

**Division of labor.** Measurement runs in step 1, in the main session. `opposition` attacks
premises and re-derives numbers; its results are never relied on for measurement.

Its declared tools are read-only, and they exclude `python3` and `pwsh`. That scoping has now been
observed not to be enforced twice: on 2026-08-27, and during this spec's own review, where it ran
`python3`. So the declared scoping is not a boundary in either direction.

**Location:** a new "Pre-Approval Protocol" section in `standards/WORKFLOW.md`. Phase 3.5's heading
stays, so existing references still resolve. Its body becomes a pointer, and its parenthetical
changes from "advisory" to "superseded by the Pre-Approval Protocol". The escalation list is
referenced, never copied.

### 2. Required output format

```
## Findings
| # | Question | How I checked (command or source) | Result |

## Recommendation
<what I recommend, and why>
<holes I could not close>
<the decision needed>
```

- Every row names a re-runnable command or source.
- When nothing load-bearing needed checking, the table still appears, with one row saying so.
- When the escalation list fired, one row carries the `opposition` verdict.
- **Both sections go in the final text block of the message.** The hook reads
  `last_assistant_message`, which may carry only that block (spike 1).

### 3. Stop hook: `pre-approval-check`

**Input:** the Stop payload's `last_assistant_message`. The hooks reference says Stop hooks
"should use `last_assistant_message` … instead of reading the transcript", so there is no transcript
read. The hook also reads `stop_hook_active`.

**Two tiers, one for each of the user's two statements:**
- **Tier A (approve or choose):** "have already done that before you ask me what to choose". The
  message must carry Findings **and** Recommendation.
- **Tier B (any other question):** "always provide what you recommend and why". The message must
  carry a Recommendation. This keeps clarifying questions from needing a full findings table
  (review finding F4).

**Logic:**

```
if env PMB_PRE_APPROVAL == "off":        notify; allow                  # kill switch
if stop_hook_active is true:             log "post-block: sections present yes/no"; notify; allow   # loop guard
msg = last_assistant_message             # missing or empty: notify; allow
end = last 400 characters of msg
tierA = APPROVAL_PATTERN matches end
tierB = not tierA and the last non-empty line, stripped of trailing whitespace
        and * _ ` ' " ), ends in "?"
if tierA and has_findings(msg) and has_recommendation(msg): notify; allow
if tierB and has_recommendation(msg):                       notify; allow
if not tierA and not tierB:                                 notify; allow
log "block: tier, missing section"; emit block JSON         # no notification on a block
```

- `APPROVAL_PATTERN`, case-insensitive:
  `should I (proceed|continue)|want me to|shall I|go ahead|does that work|which (option|approach|would you)|your call|tell me (which|whether|how|what)|how would you like|would you like|proceed\?|(say|type) "approved"|\bapprove (it|this|that|the)\b|\bapprove\?|say the word|your go-ahead|let me know (if|once|whether|when|which)|before (I|we) (move|proceed|continue|start|begin)`
  - The bare `approv` from the first draft is gone. It matched "Verdict: Approve" and "anything I
    ask you to approve" (review finding F3).
  - The last four alternatives were added after the out-of-sample measurement (evidence row 10).
    Without them, the detector missed declarative asks, and those were the highest-stakes ones:
    push approvals ("Say the word and I will"), a deletion ("I'll wait for your go-ahead"), and the
    brainstorming skill's own spec-approval line ("let me know if you want any changes before we
    move to the implementation plan").
- `has_findings`: a heading line (`#` to `####`) containing the word "Findings". That includes
  `/code-review`'s "Supported Findings".
- `has_recommendation`: a heading or bold label containing "Recommend", **or** a `**Verdict:**`
  line. That is how `/code-review` and `/change-review` reports end (F3).
- **All matching is case-insensitive in both scripts (review finding N3).** PowerShell's `-match`
  ignores case by default and Python's `re` does not, so the `.sh` passes `re.I`. Without this, a
  real tier-B message ("**My recommendation:**") passed the `.ps1` and was blocked by the `.sh`.

**Reason texts (review finding N4).** Two constants, one per tier, each with its own escape:
- **Tier A:** "Pre-approval protocol: this message asks the user to approve or choose, but lacks a
  Findings section and/or a Recommendation. Run the checks the options depend on
  (standards/WORKFLOW.md, Pre-Approval Protocol) and re-send the ask with both. If it does not ask
  for approval or a choice, reply `Not an approval ask:` with one line of why, and stop."
- **Tier B:** "Pre-approval protocol: this message ends in a question but gives no Recommendation.
  Add what you recommend and why. If no recommendation can apply (for example, you need a fact only
  the user has), reply `No recommendation applies:` with one line of why, and stop."

The two escapes are distinct so the trial log can tell them apart. Only the tier-A escape counts as
a false-positive proxy. A tier-B escape is a legitimate answer to a clarifying question.

**Notify on every exit except a block (review finding N2).** That includes the fail-open paths:
parse errors, missing fields, and any unexpected error. The `.ps1` wraps its body in
`try`/`finally`, and the `.sh` uses an `EXIT` trap. The only path without a notification is the one
that emits a block.

The `.ps1` always exits 0, so `|| bash` never runs after it. Otherwise one stop could produce two
popups, or two conflicting decisions. The one way left to lose the popup is both interpreters
failing to start (Known Limitation 9).

**Block channel: a JSON decision on stdout, never an exit code.** Every hook entry in
`.claude/settings.json` except `pre-compact-check` ends in `2>/dev/null || true`, and the
notification popup ends in `; true`. Under that wiring an exit-2 block is erased and a stderr reason
is discarded. `dangerous-commands.sh:82-86` records the same finding for PreToolUse. The hook emits
`{"decision":"block","reason":"<constant>"}` and exits 0. There are two constant reason texts, one
per tier, and neither contains payload content.

**Loop guard: `stop_hook_active` (review finding F2).** After a block, the Stop that follows is
allowed, whatever the continuation says. That includes a one-line "this is not an ask", which is
the escape hatch for false positives.

The first draft keyed the guard to `prompt_id` instead. Whether `prompt_id` survives a
continuation has never been observed, and if it changes the guard never matches and the hook blocks
forever. Keying on `stop_hook_active` also removes the per-session state file, its filename
validation, and its `.gitignore` entry.

**Contingency:** if spike 1 shows `stop_hook_active` is absent, the hook never blocks (it logs only)
until a guard is proven by spike 2's post-block capture. Failing toward "no loop" beats failing
toward "no stop".

**The hook owns the Stop notification (review finding F1).** Today's "Claude has paused" popup is a
modal `MessageBox`. Stop-hook durations in `stop_hook_summary` are dominated by it: median 4.1 s,
max 601 s, and 31 of 159 over 60 s. So the harness waits for it. `docs/HOOKS-GUIDE.md:116` already
records that it can stall a session "permanently".

With two independent Stop entries, every block would pop a "waiting for input" notice about an ask
that is about to be replaced, and the redo would not start until the user clicked OK. So this
script **replaces** the popup entry and launches the same notification **detached**, and only on
allow. On a block there is no popup.

- **Windows, from `.ps1`:** `Start-Process`. The reviewer measured it returning in 680 ms without
  holding the output pipe.
- **Windows, from `.sh`:** `powershell.exe -Command "…" >/dev/null 2>&1 </dev/null &`. **The
  redirects are required (review finding N1).** A Git Bash background job that keeps the hook's
  pipes open holds the hook until the child exits: 3,126 ms without them, 194 ms with them.
- **macOS and Linux:** `osascript` and `notify-send` are already non-blocking.

This changes the popup from modal to non-modal. It no longer holds the session until dismissed,
which also removes the stall that `HOOKS-GUIDE:116` records.

**The popup closes itself after 600 s** (user decision 2026-09-22). On Windows it is
`(New-Object -ComObject WScript.Shell).Popup(<text>, 600, 'Claude Code', 64)`, not a `MessageBox`.

Why it has a timeout:
- A detached popup is closed by nothing else, so ignored popups would pile up, one per turn end at
  about 73 MB each.
- The old modal popup's 601 s maximum was the harness's hook timeout. Whether killing the hook also
  closed that window was never tested, so 600 s is chosen to match, not claimed as equivalent.

Checked 2026-09-22 with a 3 s timeout: launched through `Start-Process` with a hidden window, the
popup closed itself and its process exited after 4.2 s. The 600 s value itself has not been timed.

**Trial measurement (review finding F5).** One line per block, and one per post-block Stop, goes
to `.pmb-pre-approval.log` (gitignored). Each line holds a timestamp, a `session_id` prefix, the
tier, the missing section, and whether the sections were present after the block. No message text
is logged.

The post-block line records one of three outcomes:
- sections added;
- `Not an approval ask:`, the false-positive proxy;
- `No recommendation applies:`, a legitimate tier-B answer that does not count as a false positive.

**Trial:** two weeks after merge. If false-positive proxies exceed 20% of blocks, narrow the
detector before any template rollout. Record the result in `progress.md`.

**Trial-end provenance audit.** This measures the checkable half of Known Limitation 1. It is a
one-off script, not a hook, run over the trial's session transcripts. For each Findings table, it
checks that every command or file a row cites appears in an actual tool call.

- **Scope includes subagent logs** (third review). Subagent tool calls live in
  `<session>/subagents/*.jsonl`, not the main transcript. This session has 176 such files and zero
  subagent entries in the main file. Without them, every check an `opposition` pass ran would read
  as fabricated.
- **Prior-run citations are allowed and checked on their own terms.** §1 tells the model to cite
  the last run of a mutating check like `tests/run.sh` rather than rerun it. A row that does so must
  name when or where that run happened. The audit checks that reference, not the current turn.
- **Promotion needs a confirmed fabrication.** The audit only flags. Each flagged row is confirmed
  by hand, with the user, before anything is promoted. One *confirmed* fabricated row turns the
  cross-check into a blocking hook check.

The audit's known blind spot: a cited file that was read earlier for an unrelated reason satisfies
the substring match, so it can miss a real fabrication. That makes it a floor on fabrication, not a
proof of its absence.

Measuring first, rather than building the check into v1, keeps the transcript read (JSON-escaped
commands, long turns, subagent files) out of the per-turn hook until there is evidence it is
needed. The kill switch
(`PMB_PRE_APPROVAL=off` in the `settings.json` env block) is the rollback, with no wiring edit.

**Failure handling.** Fails open, per the repo's G2 convention: a parse error means allow, plus one
`.pmb-hook-errors.log` line per session so it cannot bury other hooks' errors in `mb doctor`'s
`tail -3`. Payload values reach `python3` only through stdin, never interpolated into its source.

**Every fail-open also writes one line to the trial log:** `event=failopen kind=<kind>`, no message
text. The main checkout's `.pmb-hook-errors.log` holds 95 truncated-payload errors out of 160 lines.
If long Stop payloads truncate, the hook silently allows exactly the long, Findings-heavy asks, and
without this line the trial would count blocks but never those misses.

**The `.ps1` reads stdin as UTF-8**, using the reader in `dangerous-commands.ps1:84-86`.
`[Console]::In` decodes with the OEM code page (ibm437) there, which shrinks the 400-character
window whenever the text contains non-ASCII characters.

**A missing or empty `last_assistant_message` is an allow, not a fail-open, and is not logged**
(review finding L8). A turn can end in a tool call with no text, and logging every such stop would
flood the trial log. Spike 1 establishes that the field is present at all.

**Wiring:** the single `Stop` entry, replacing the popup:
`pwsh -NoProfile -NonInteractive -File scripts/pre-approval-check.ps1 2>/dev/null || bash scripts/pre-approval-check.sh 2>/dev/null || { (powershell.exe -Command "<self-closing popup>"; osascript -e '<notification>'; notify-send '<notification>') >/dev/null 2>&1 </dev/null & } || true`
- `-NoProfile` keeps profile output out of the hook's JSON, and it matches the command the tests
  invoke.
- **The braces are required.** In POSIX shell, `&` binds looser than `||`. Without the braces,
  `A || B || (popup) & true` backgrounds the whole chain, not just the popup. The shell then exits
  before the hook's JSON decision is written, and the block can be lost. A test pins this.
- **The last link is the notification fallback.** Both scripts always exit 0 once they start, so it
  runs only when neither can start or run at all. It is today's popup chain, detached.
- With it, the notification is no less reliable than today. The only way left to lose it is the
  hook-running shell itself failing, and that already kills today's popup.

**Cost:** one interpreter start per turn end, after the response renders. This spec first estimated
0.35–0.7 s from compact-nudge measurements. A review on 2026-09-22 measured 1.2–1.35 s for an allowed
stop and about 1.15 s for a block, under CPU load from a concurrent `tests/run.sh`. Treat the true
unloaded figure as unmeasured. With the popup detached, nothing waits on the user. A block costs one extra
model turn.

### 4. `AskUserQuestion`: no hook (dropped after review)

The first draft proposed a PreToolUse check that questions carry a `(Recommended)` option with a
description. Twelve of the 13 questions asked this session already did (review finding F8). The
user's complaint on that channel was depth of reasoning, which a label check cannot see. The
protocol text still covers these asks. Spikes 3 and 4 are removed with it.

### 5. What does not change, and why

- **CLAUDE.md: no edit.** The startup-context ratchet (`pmb-health.yml`, a required,
  enforce-admins check) fails any branch where CLAUDE.md plus `memory-bank/` is larger than on
  `origin/main`. CLAUDE.md's Workflow line already points to `standards/WORKFLOW.md`. The
  first-pass reminder lives in the auto-memory index (`feedback_poke_holes_before_asking.md`). The
  hook's reason text names the protocol's location.

  Whether auto-memory reaches linked-worktree sessions is unproven either way. The review found no
  per-worktree `memory/` folders, which fits a per-repo store. The cost if it does not is bounded by
  the guard: at most one block per ask.
- **`templates/`: no edit** beyond `HOOKS-GUIDE.md` (see Files Changed). The hook is PMB-only until
  the trial ends. `WORKFLOW.md` is on the mirror test's `STD_DIVERGE_OK` allowlist; a new
  `standards/PRE-APPROVAL.md` would need a byte-identical template twin.
- **`tests/test-mirror-parity.sh`: a narrow, dated trial exemption** (option A+, user decision
  2026-09-22).
  - **Why it's needed.** `test-mirror-parity.sh:354-421` requires live and template hook wiring to
    be identical, both the `"command":` lines and the (event, matcher, commands) triples. Replacing
    only the live Stop line fails it: 146 passed, 2 failed. The mirror-parity rule was cited at
    evidence row 9 (lines 176-190) but its settings block was missed.
  - **What it exempts.** Exactly one live line containing `scripts/pre-approval-check.` is compared
    as if it were the template's popup line. The exemption follows the test's own `STD_DIVERGE_OK`
    pattern, a sanctioned divergence with an anti-rot guard.
  - **Its guards.**
    - An exactly-once assertion fails if the hook is lost (for example, to `mb upgrade` run inside
      PMB) or duplicated.
    - Every other hook, matcher and event is still compared. Checked 2026-09-22 with five mutations,
      on Windows and Linux.
    - A dated expiry assertion fails CI once the trial end plus a grace period passes, forcing a
      promote, remove or extend decision. It is a hard failure, because this repo has already
      recorded a WARN being ignored (the 2026-08-12 fleet-version-drift incident).
  - **What still checks the exempted line.** The new suite exercises the command it reads from the
    live `.claude/settings.json`.
  - **Options rejected** (reviewed 2026-09-22):
    - B. Ship enabled to templates: no trial.
    - C and F′. Ship dormant scripts to templates behind a flag. F′ passed every test, but it
      reverses this section's decisions, and `mb upgrade` never deletes scripts, so a failed trial
      would leave dead code in every adopter. F′ is the candidate shape for promotion.
    - F. The same, with an env flag: it also leaks into every subprocess.
    - D. `settings.local.json`: unversioned, and the modal popup remains.
    - E. "Template ⊆ live": the change replaces the popup rather than adding a hook.
    - G1. `async` on the popup, and G2, moving the notifier to a `Notification`/`idle_prompt` hook:
      both untested, and both change the notifier design for every adopter.
- **Found in that review, not fixed here: the template contradicts the guide.**
  `templates/.claude/settings.json` installs the modal Stop popup, while both `HOOKS-GUIDE.md`
  copies say it is "excluded from install template".
  - `71d5899` (2026-05-13) removed it from the template deliberately.
  - `f976530` (2026-05-14, "add token budget, Karpathy principles, mb budget command") swapped it
    back in without mention.
  - Whether adopters should get a Stop popup is a separate user decision. This spec only corrects
    the guide's false sentence.
- **`.claude/commands/feature-dev.md`: no edit, known drift.** Its Phase 3.5 note still calls the
  step "advisory" and scopes it to "plans with real consequence". That becomes stale for PMB, but
  commands are strict byte-identity mirrors, so correcting it would ship the change to adopters.
  Reconcile at template rollout (review finding F6).
- **No document-status check.** Every spec or plan approval is itself a chat ask, which the hook
  covers. A status check would need exemptions for the 20 specs already marked Approved and a new
  convention for the 27 of 29 plans without a status line, and it would verify form only.

### 6. Why a hook, when the August design ruled hook enforcement out

`2026-08-12-investigation-integrity-design.md` puts "any hook-level enforcement mechanism" out of
scope as "structurally impossible". Its target was the quality of the reasoning itself: whether a
claim was really verified. No hook can observe that, and this spec does not claim to.

This hook enforces something narrower: **whether an ask carries the required sections at all.**
That omission is the failure the user actually hit.

`docs/HOOKS-GUIDE.md:28` frames hooks as per-tool-call structural enforcement, and `:32` warns that
a semantic check in a hook "creates false confidence" (review finding F7). Two differences apply:
- The hook runs per turn end, not per tool call.
- Its ask detection is a measured heuristic trigger, not a judgment of quality.

The false-confidence risk is real: **a message that passes the hook has sections, not necessarily a
good pass.** The `HOOKS-GUIDE` entry states this, and Known Limitation 1 restates it. Adequacy
stays with the Reviewer/Opponent layer via the `opposition` pass.

## Measured Evidence (2026-09-21)

| # | Question | How checked | Result |
|---|---|---|---|
| 1 | Is the final message available when a Stop hook runs? | `stop_hook_summary` entries: assistant timestamp vs hook start (summary time minus `hookInfos` duration) | Before hook start in **159/159** (independently re-derived by `opposition`; minimum gap 13 ms) |
| 2 | Can a Stop hook force continuation? | Hooks reference | Yes. Nothing under `~/.claude/projects` has ever recorded a Stop block, so the mechanics are spike 2 |
| 3 | How often would this block, at today's habits? | The final §3 rules (extended pattern, case-insensitive) run against the final text block at each real Stop event | **About a third.** This session: 55 of 162 (34.0%); the reviewer counted 56 (34.6%). The 41 other PMB transcripts: 542 of 1,718 (31.5%); the reviewer counted 549 (32.0%). The denominators match; the small gaps come from how the two scripts pick the final text block, which `last_assistant_message`'s scope settles (spike 1) |
| 4 | Asks via `AskUserQuestion` | Transcript count, plus `opposition` review | 12 calls; 12 of 13 questions already carried `(Recommended)` with a description |
| 5 | Is there a documented loop guard? | Hooks reference | Not in the fetched content. Hence the `stop_hook_active` guard and the spike-1 contingency |
| 6 | Does exit-code blocking survive the repo's wiring? | `settings.json` wiring; `dangerous-commands.sh:82-86` | No, so the hook uses a JSON decision |
| 7 | Does the popup hold the session? | `stop_hook_summary` durations | Median 4.1 s, max 601 s, 31/159 over 60 s. So the hook owns and detaches the notification |
| 8 | Can CLAUDE.md take a new section? | `pmb-health.yml` aggregate ratchet | No growth vs `origin/main` allowed |
| 9 | Can the protocol be a new standards file? | `tests/test-mirror-parity.sh:176-190` | Only with a byte-identical template twin. So `WORKFLOW.md` (allowlisted) |
| 10 | Does the detector generalize beyond this session? | The §3 rules over **41 other PMB transcripts** (main checkout plus 8 worktrees), this session excluded. Here a "turn ending" is the last assistant text block before each real user prompt, excluding tool results, meta and compact-summary entries: 1,975 endings. The reviewer's count by the same definition was 2,030, and 1,718 when counted at Stop events instead (row 3) | See below |

**Row 10 result:**
- **Original pattern:** caught 523. All 10 sampled tier-A hits were genuine asks. 116 ask-shaped
  endings went uncaught, including push, deletion and spec-approval asks.
- **Extended pattern:** 89 more caught; the reviewer counted 80–92, depending on delimitation. Of
  20 sampled, 14 were clear asks, 1 was a false positive ("Let me know once it's through"), and 5
  could not be judged from the snippet.
- **"Let me know once" is kept despite that false positive.** It also carries real go-ahead asks
  ("Let me know once that's done and I'll invoke `subagent-driven-development`"), and the reviewer
  put its false-positive share at about 2% of blocks, well under the trial's 20% threshold. The
  trial log will show whether it earns its place.
- **Left uncaught:** 35 ask-shaped endings. Going by the earlier sample, roughly half of those are
  real asks.

Every measurement here is on this repo's sessions and one model's phrasing; other projects were
not measured.

## Verification Spikes (first implementation tasks)

Every spike hook filters to the implementing session's own `session_id` before acting or writing.
Hooks in `.claude/settings.json` fire for every session in the directory, and a diagnostic once
captured a peer session's private prompt. Blocking spikes act only on messages containing a
sentinel string.

1. **Stop payload fields.** Is `last_assistant_message` present, and does it hold only the last
   text block or the whole message? Is `stop_hook_active` present?
2. **Block mechanics under the real wiring, with the merged notifier.** Confirm four things:
   - `{"decision":"block"}` via the standard `|| true` wiring prevents stopping;
   - the reason reaches the model;
   - no popup appears on a block, and the continuation starts without any click;
   - the captured Stop payload that follows a block, including whether `stop_hook_active` is true
     and whether `prompt_id` changed;
   - that `PMB_PRE_APPROVAL=off` set in the `settings.json` env block actually reaches the hook, and
     whether a running session needs a restart to pick it up (review finding N5).

   If the block does not work, stop and redesign the channel before building anything else.

## Testing: `tests/test-pre-approval-check.sh`

Every case runs against the `.sh`, and against the `.ps1` when `pwsh` is on PATH, following
`tests/test-pre-compact-check.sh`'s parity block (`PMB_REQUIRE_PARITY=1` makes a missing `pwsh`
fatal). The invocation is the exact `settings.json` command string. The notifier can be overridden
via `PMB_NOTIFY_CMD`, pointing at a stub that records calls. Fixtures are synthetic payloads; no
real conversation text is committed.

- Not an ask: allowed, notifier called once.
- Tier A ("Want me to …?", "Type \"approved\" to begin", "approve it or tell me …") without
  Findings: block JSON, notifier **not** called, one log line.
- Not tier A: "**Verdict:** Approve" alone, and "anything I ask you to approve." (the measured
  false-positive shapes).
- Tier B ("Which should we brainstorm first?") without a Recommendation: block. With one: allowed.
- Trailing markdown after the "?" (`…first?**`): still tier B.
- Tier A with Findings and Recommendation: allowed.
- A `/code-review`-shaped report ("## Supported Findings" … "**Verdict:** Approve", ending in a
  question): allowed.
- `stop_hook_active: true`: allowed, notifier called, a post-block log line recording
  sections-present.
- `PMB_PRE_APPROVAL=off`: allowed, notifier called, nothing logged.
- Missing or empty `last_assistant_message`: allowed.
- Malformed JSON: allowed, **notifier called**, logged once; a second run adds no line.
- A forced unexpected error: allowed, notifier called, and the `.ps1` exits 0.
- **A notifier stub that sleeps 5 s does not delay the hook**: the hook returns in under 1.5 s, in
  both shells.
- "**My recommendation:**" (lower-case) satisfies tier B in both shells.
- Declarative asks are tier A: "Say the word and I'll push", "I'll wait for your go-ahead", and
  "let me know if you want any changes before we move to the implementation plan".
- The measured false-positive shape, "Let me know once it's through.", is tier A by design. The
  test documents that its escape is `Not an approval ask:`.
- Fallback chain: the exact `settings.json` command with both script paths replaced by nonexistent
  ones still calls the notifier stub, detached.
- The chain is synchronous on the primary path. Run the exact command with stdout redirected to a
  file and a tier-A payload on stdin. The block JSON must already be in the file when the shell
  returns. This fails if the braces are dropped.
- Post-block lines record the escape used (`Not an approval ask:` or `No recommendation applies:`)
  or "sections added".
- Log lines never contain message text.
- **`stop_hook_active: true` on a tier-A ask with no sections: allowed, no block JSON.** This is
  the loop guard's key property. Deleting the `.ps1` guard's `return` left the earlier cases green.
- Upper-case headings (`## FINDINGS`, `## RECOMMENDATION`) satisfy the check, which proves the
  matching is case-insensitive.
- A raw UTF-8 payload (non-ASCII text not `\u`-escaped) is read correctly by the `.ps1`.
- Every fail-open writes one `event=failopen` line to the trial log.
- In `tests/test-mirror-parity.sh`, the trial exemption fails when the hook line is absent or
  duplicated, when the expiry date has passed, and when the date is still the placeholder.
  Absent and duplicated were verified by mutation at design time (2026-09-22); the executor
  re-verifies the expiry case (plan Task 7 Step 4).

## Files Changed

- New: `scripts/pre-approval-check.sh`, `scripts/pre-approval-check.ps1`
- Edit: `.claude/settings.json` (the Stop popup entry is replaced by this hook, which owns the
  detached notification)
- Edit: `.gitignore` (`.pmb-pre-approval.log`)
- Edit: `standards/WORKFLOW.md` (new Pre-Approval Protocol section; Phase 3.5 parenthetical and body
  updated; Quick Reference and Claude Code Integration rows)
- Edit: `docs/HOOKS-GUIDE.md` and `templates/docs/HOOKS-GUIDE.md`. The sync note requires
  hand-mirroring, so the entry goes in both:
  - marked "PMB-only, not installed by `mb init`";
  - with the §6 false-confidence caveat in **both** copies;
  - with the false "excluded from install template" sentence corrected (§5).

  `HOOKS-GUIDE.md:116`'s popup-stall note is updated.
- Edit: `tests/test-mirror-parity.sh` (the dated trial exemption, §5)
- New: `tests/test-pre-approval-check.sh`
- Edit: `tests/run.sh` (one `run_suite` line, a known one-line overlap with a concurrent worktree
  session's planned edit)

Not changed: `CLAUDE.md`, `templates/` except `HOOKS-GUIDE.md`, `.claude/commands/*`, and
`memory-bank/`.

## Implementation Notes

- **Work in a worktree off `origin/main`.** The main checkout holds another session's uncommitted
  edits.
- **Ratchet budget:** the implementing branch starts from `origin/main`, so no earlier uncommitted
  bytes come with it. (The +880-byte CLAUDE.md paragraph was parked outside the repo on
  2026-09-22.) Any `progress.md` entry it adds must be offset by an equal archive, per
  `standards/MEMORY-BANK.md`'s eviction rules.

## Known Limitations

1. **Form, not substance, in two halves.**
   - **Were the cited checks actually run?** This is checkable. It is measured by the trial-end
     provenance audit (§3), and it becomes a hook check if the audit finds a fabricated row.
   - **Were they the right checks, and was anything missed?** No mechanism can close this. An
     omission leaves nothing for a program to find: it was never a claim. This is the ceiling the
     August design named. The independent Opus pass reduces it but does not remove it, because it
     is also a model.
2. **About a third of turn endings (31.5–34.6%) would be blocked at today's habits** (evidence
   row 3).
   The friction falls as habits change, and the trial log measures whether it does.
3. **Detector recall is high but not total.** 35 ask-shaped endings remained uncaught out of 1,975
   out-of-sample (evidence row 10). Other projects' phrasing was not measured. A miss degrades to
   today's behavior, and the trial log tracks blocks, not misses.
4. **Fires for every session in this directory** once merged, including peers mid-task.
5. **The popup becomes non-modal and closes itself after 600 s.** That is a deliberate behavior
   change (§3). A notice ignored for longer than that is lost.
6. **The first-pass reminder is user-level auto-memory**, not version-controlled. Revisit at
   template rollout.
7. **`feature-dev.md` drift** until template rollout (§5).
8. **`stop_hook_active` and the scope of `last_assistant_message` are unverified**; spikes 1 and 2
   settle them.
9. **Notification reliability is at parity with today, not better.** If both scripts fail, the
   wiring's fallback link still shows the popup. The remaining case is the hook-running shell
   itself failing, which already disables today's popup.
10. **The hook's working directory is not guaranteed** (INFERRED from the 2.1.178 binary: hooks
    start in the session's current directory). Like every hook here, the wiring uses relative
    `scripts/…` paths. If a session's directory is a subfolder, both scripts fail to start, the
    fallback popup fires, and the turn is allowed with no log line, so the trial undercounts
    silently. Anchoring on `CLAUDE_PROJECT_DIR` would fix it for all hooks, which is a separate,
    house-wide change.
11. **Adopters keep the modal popup** that `HOOKS-GUIDE.md` says was removed (§5). Resolving that
    by removing the template popup would break the trial exemption, whose swap needs the
    template's popup line; rewrite the exemption in the same change (review finding L3). This is a
    separate decision.
12. **The trial exemption must be resolved by its expiry date.** CI fails after that date until the
    exemption is removed (hook promoted or deleted) or the date is deliberately extended.

## Out of Scope

- **Rollout to `templates/` and adopters.** This comes after the trial, decided from the log.
- **A `/poke-holes` command.** The protocol is automatic.
- **Any CLAUDE.md edit**, because of the ratchet. (The handoff-trigger paragraph that would have
  failed it was parked outside the repo on 2026-09-22.)
- **Reconciling with the August `investigation-integrity` skill.** A review on 2026-09-22 found it
  on no branch, so there is nothing to reference.
- **Whether adopters get a Stop popup at all** (the template/guide contradiction, §5).
