---
status: open
created: 2026-09-22
last-reviewed: 2026-09-22
staleness-threshold: 90d
related_plan: null
---

# Replace the gh pr merge deny with a forced permission prompt

**This is a proposal. It is not approved, and it must be fully vetted before any design work starts.**
- **Origin.** The user raised it on 2026-09-22, after PR #45 was merged by hand from a command a
  session wrote.
- **Blocked** until `docs/backlog/merge-gate-misses-gh-global-flags-graphql-and-powe.md` is fixed.
  The deny this proposal would replace is not total today.
- **Process.** It changes the enforcement layer, so CLAUDE.md's rules call for an Opus escalation
  prompt, a spec, a task contract, and a full `/code-review` and `/change-review`.

**What decays here, and what to re-verify before relying on it:**
- **Line numbers** were checked at `ac63ccb` on 2026-09-22 and drift with any edit.
- **Version-gated tool behaviour**, which this item's whole safety argument rests on: the Claude
  Code version installed on one machine on 2026-09-22, and the v2.1.211 threshold that decides
  whether Option B is safe at all.
- **Machine-local, untracked configuration**, which has no history to diff against.
- The blocking item carries the same list for the measurements it owns.

## Current behaviour

- **The deny is unconditional, but only for commands classified MERGE.**
  - The deny code is at `scripts/review-reminders.sh:167-171` and `scripts/review-reminders.ps1:92-95`.
  - The rationale comments are at `.sh:8-18` and `.ps1:30-40`. They say "an unconditional deny is
    both correct and total" (`.sh:16-17`).
- **Classification lives in two separate classifiers**, one per shell
  (`scripts/_review-gate-classify.py` for bash, `_review-gate-classify.ps1` for pwsh, which runs
  first here), each with a byte-identical `templates/scripts/` twin. **The blocking item above is
  the source of truth for how they match and which forms they miss** — it is not restated here, so
  that only one file needs correcting when the code changes.
- **Several merge forms are not classified as MERGE and get no decision from any wired hook**
  (measured; see that item): a flag-shaped token before the subcommand, the GraphQL merge route, and
  PowerShell string or process wrappers. A mixed-case subcommand is a bash-only classifier-parity
  case: gh rejects it as an unknown command, so it is not an executable merge route.
- **Both entry points are wired.** In `.claude/settings.json`, `PreToolUse` runs `review-reminders`
  for the `Bash` matcher and for the `PowerShell` matcher. The `PowerShell` matcher has no bash
  fallback.
- **The auto-mode classifier's observed behaviour** is recorded in the blocking item, under "What
  actually stands in the way today". It is not restated here: it is a single-day observation that
  will be re-measured, and it should change in one place.
- **"Platform-enforced" is recorded but cannot be separated from the repo hook.**
  - `memory-bank/activeContext.md:56` says the agent never runs `gh pr merge`, and calls it
    "platform-enforced, not just repo convention". Its source,
    `docs/archive/progress-2026-08-19-to-21-escalation-and-bundle-1.md:47-50`, says the same.
  - But the repo hook's unconditional deny was already live in both twins at `5d573fd`, the commit
    that entry records, so a refusal observed that day is equally explained by the hook.
  - Whether a platform refusal exists independently is therefore unknown, and if it does, it would
    sit above both options below.
- **Today the user runs the merge command themselves,** usually pasting one a session wrote.
  - `standards/SECURITY-GUARDRAILS.md`, "The User Is Never the Compliance Bypass" (heading `:88`,
    text `:90`), says some commands are designed so that only a human runs them. Its examples do not
    include `gh pr merge`. Reading that rule as covering this command is this item's inference.
  - That standard's CONFIRM row on merging (`:115`) covers a local `git merge`, not `gh pr merge`.

## The problem

- **Nothing checks what is actually relayed.** The decision is the user's, but nothing compares the
  pasted command with what was verified. This repo has already seen agent retyping errors. On
  2026-09-22 a session retyped check results into a reviewer's prompt and corrupted them; PR #45's
  body records it as OPP9-2, "mis-transcribed and corrected mid-run". (The specifics — a fabricated
  line of check output, and a SHA-256 missing one character — are from that session, and are not in
  the PR body.) `--match-head-commit <sha>` protects a merge only when the session remembers to
  include it.
- **The relayed command runs where nothing checks it.** A command typed in the user's own terminal
  passes through no agent-side hook ([NS-26]).
- **It adds friction to every merge.**

## Options

- **A. Keep the deny (status quo).** Only once the blocking item is fixed is this a deny that holds.
- **B. Hook-forced prompt.** For a `gh pr merge <N>` that carries `--match-head-commit <40-hex>`, the
  hook prints JSON with `hookSpecificOutput.permissionDecision: "ask"` and a reason.
  - **Everything else stays denied:** no `--match-head-commit`, `--admin`, `--auto`, and every
    other merge form. gh documents `--admin` as "Use administrator privileges to merge a pull
    request that does not meet requirements"; with admin override disabled on this repo (see the
    blocking item's branch-protection note) it would not succeed anyway. (`gh pr merge --help` is itself denied by the gate, since it parses as a merge;
    `gh help pr merge` is not, and that is where this text came from.)
  - **Open design question: where the SHA comes from.** If the agent supplies it, the user is shown
    a hex string they cannot check, and the relay problem survives. Binding it means using a source
    the agent does not control:
    - the hook looks up the PR's head itself, which the current rationale rejects as fragile;
    - or the push gate records the head it reviewed.
- **C. A `permissions.ask` rule in `.claude/settings.json`** for the merge command, on both tools.
  This could be combined with B, with the hook still denying malformed forms.

## What the docs say

Fetched from code.claude.com/docs on 2026-09-22. Re-read the pages before relying on this.

- **`hooks.md`, "PreToolUse decision control":** "A hook's `"ask"` also forces a permission prompt
  in auto mode: the classifier can still deny the tool call, but it can't approve the call
  silently."
  - Before v2.1.211, the classifier could approve a Bash command running outside the sandbox
    without showing the prompt.
  - **The CLI on this machine reports `2.1.178`** (`claude --version`), so B would not be safe on
    it. The version bundled in the desktop app is not verified.
- **Hook precedence:** "`deny` > `defer` > `ask` > `allow`" (same section).
- **Exit codes and JSON:** JSON output fields are read "on every exit code, not just 0". Exit 2 is a
  block; it cannot express "ask".
- **`hooks.md`, PermissionRequest decision control:** a `PermissionRequest` hook's `"allow"` grants
  the permission. So something other than a human can answer a prompt. Deny and ask rules are still
  evaluated after it.
- **`permission-modes.md`, "Actions no mode auto-approves":**
  - It lists "Tools matched by an explicit ask rule", "including `bypassPermissions`". That supports
    C.
  - A hook's "ask" is not listed, so whether B holds under `bypassPermissions` is not stated.
- **`permission-modes.md`, auto mode:** the docs say it "still shows you" prompts forced by an
  `ask` rule or by a hook.
- **`permission-modes.md`, dontAsk:** it "auto-denies every tool call that would otherwise prompt
  you".
- **Not stated:**
  - what an "ask" does in `-p` or SDK runs outside `dontAsk`;
  - whether the prompt shows the full literal command;
  - whether anything records that a human, not the classifier, approved.

## Must be measured before any design

Reading the docs does not count. Each item has a pass condition.

0. **Prerequisite:** the blocking item is fixed, and its regression tests are green.
1. **A human sees the prompt.**
   - Check every mode this repo uses: default, acceptEdits, plan, auto, dontAsk, bypassPermissions.
   - Check every client used: CLI, the desktop app, Remote Control, mobile.
   - Check that each client runs Claude Code **>= 2.1.211**.
   - **Pass:** in every mode, either a human is prompted or the call is denied, and it is never
     silently allowed.
2. **Subagents.** **Pass:** a subagent's merge "ask" either reaches the user or is denied. It is
   never allowed on its own. A review subagent has already evaded a gate here
   (`docs/backlog/review-gate-is-bypassed-by-a-git-verb-held-in-a-va.md`).
3. **No human present** (`-p`, SDK, dontAsk). **Pass:** the call is denied.
4. **Other resolvers.**
   - No installed `PermissionRequest` hook answers a merge prompt.
   - A user's `permissions.allow` entry for the merge does not silently skip the prompt. If it can,
     that has to be documented as an explicit opt-in.
5. **The prompt shows the whole command,** including the SHA.
6. **Failures refuse.** On the merge path, a hook crash must mean deny, never "no decision", because
   "no decision" hands the call to the permission flow.
   - Today, if the pwsh hook drains stdin and then crashes, the bash fallback reads an empty stream
     and exits 0 (2026-09-11 whole-repo review, `memory-bank/progress.md`).
   - The `PowerShell` matcher has no bash fallback.
7. **Parsing, in both classifiers and both raw-text fallbacks.**
   - Find the gh subcommand after skipping any flag-shaped token before it, and match it
     case-insensitively for classifier parity; gh rejects mixed-case subcommands, so this is
     hardening rather than a merge-route fix.
   - Read `--match-head-commit` from the command's actual structure, not by substring matching.
     Otherwise an `echo` of that text would satisfy it ([NS-25], [NS-43]).
   - A compound command still gets denied (MULTI).
8. **Audit trail.** **Pass:** either the design names where each approval is recorded and it can be
   re-read, or it records an explicit decision that no record is needed.
9. **Parity.** B or C lands everywhere at once:
   - both hook twins and both classifier twins, plus all their `templates/` mirrors (TEMPLATE_OWNED,
     shipped to every adopter);
   - a test for each form, each mutation-checked;
   - `tests/gate_matrix.py` needs a third outcome, ASK. Its `run_hook()` (`:119-130`) returns
     ALLOW for anything that is not an explicit deny (`:130`), so it cannot tell a working B from a
     silent allow. **But see step 7 of the blocking item before touching it:** that harness runs in
     no pipeline, refuses without an opt-in token, and rewrites history in whatever tree it is
     given. Adding an ASK outcome satisfies this row only on paper until its topology is fixed;
   - both HOOKS-GUIDE copies;
   - a CHANGELOG note for adopters.

   C also runs into [NS-50](a): `mb upgrade` overwrites `.claude/settings.json`'s `permissions` block.
10. **Docs this would make false,** all updated in the same change. Four of them are *already*
    false and are scheduled for correction by step 6 of the blocking item, which lands first: the
    "correct and total" rationale in both hook twins, and the "no override" sentences in both
    HOOKS-GUIDE copies. What this change adds is that they must then describe the new mechanism.
    - the four already-false statements, which step 6 of the blocking item lists by line;
    - `standards/SECURITY-GUARDRAILS.md:86` and its `templates/` twin say "What Counts as Approval"
      cannot be hook-enforced and is "advisory by necessity";
    - the worked examples at `docs/HOOKS-GUIDE.md:35` and `:37`;
    - `memory-bank/activeContext.md:56`;
    - `CLAUDE.md`'s layering line, which says hooks "cannot be talked around", **and its
      `templates/` twin** (`templates/CLAUDE.md:40`, byte-identical sentence, shipped to every new
      adopter by `mb init`). A prompt a person approves is a different property from that.
11. **Platform refusal.** **Pass:** it is settled whether the refusal recorded on 2026-08-19 is live
    and independent of the repo hook. That needs a real merge attempt, so make it only with the
    user's authorization and only against a throwaway repository they own.
12. **Policy.** Decide which flags are allowed: `--squash` only? `--delete-branch`? Note that
    `--delete-branch` also deletes the local branch, which git refuses while that branch is checked
    out in a worktree. Decide the SHA source (see B). Decide whether every merge prompts, or only
    PRs that touch enforcement files.

## Arguments against

- **A leaks today** (the blocking item). Compare B with A only after that fix. **If any mode, client
  version or other resolver can settle the prompt without a human, B is worse than a fixed A**: the
  agent could merge with no human involved.
- **People click through prompts out of habit.** Pasting a command is just as habitual, and neither
  makes anyone read the PR. If the merge step should include an independent human review, that is a
  separate requirement no hook can enforce.
- **The merge is the only checkpoint today that Claude doesn't perform** ([NS-27]: review is Claude
  reviewing Claude). B keeps a human decision, but moves it inside the agent's session.

Related: [NS-25], [NS-26], [NS-27], [NS-43], [NS-49], [NS-50](a).
