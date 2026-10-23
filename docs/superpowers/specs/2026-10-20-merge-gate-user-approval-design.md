# Merge gate: let the agent merge on the user's per-PR click

**Status:** implemented, revision 4, on branch `claude/merge-gate-user-approval-870329` (its own
PR, not part of #71). The user approved the design at revision 3 and the task contract on
2026-10-20. G0 passed in the desktop app (§3). G1, G2 and G3 (§9) are still to run, and only after
`main` in the main checkout carries this code (§7).

**Review history**, every finding checked against the repo before it was folded in (§10 maps each
one to the change it caused):
- **Revision 2:** an Opposition pass (Opus), Request Changes with blocking B1 and B2, plus a
  security-reviewer pass (Sonnet) with HIGH-1 to HIGH-5.
- **Revision 3:** an Opposition re-review of revision 2, Approve with conditions, all applied.
- **Revision 4:** a third Opposition pass on revision 3 and contract v1, Request Changes, all
  applied.
- **Implementation:** `/code-review` Approve. Its non-blocking doc findings are corrected in this
  revision: the crash-path wording, §7's worktree claim, and the §5.3 audit-field order.

**Line numbers in §1 describe the code before this change**, at `origin/main` `25515a2`.

It **supersedes the open question in** `docs/backlog/replace-the-gh-pr-merge-deny-with-a-forced-permiss.md`
(Option B there). That item says it is blocked until
`docs/backlog/merge-gate-misses-gh-global-flags-graphql-and-powe.md` is fixed. §7 proposes a
narrower prerequisite. **The user decides the ordering; this spec does not.**

## 1. Why the deny exists

- **It was a design choice, not an incident.** `docs/archive/progress-2026-07-repo-governance-and-ci.md:81-83`
  says the deny was "chosen after the user asked 'what do you honestly feel is better' over a more
  complex PR-diff-hash design". It was live-validated against PR #8. It landed in `b0490ef` (#8,
  2026-08-19), and the PowerShell path followed in `a0850a3` (2026-09-15).
- **The rationale** is at `scripts/review-reminders.sh:8-18` and `.ps1:30-40`. Diff integrity is
  already covered by the commit gate, the push gate and strict required checks. The gap at merge
  time is authorization: "a hash can't encode 'the user meant this right now'". The hook only sees
  the agent's commands, so it concluded that "an unconditional deny is both correct and total".
- **The code:** `review-reminders.sh:171-174` and `.ps1:92-95` deny the verdict `MERGE`.
  `_review-gate-classify.py:303-306` and `.ps1:138-139` produce that verdict for `gh pr merge` and
  for the REST route. The raw-text fallbacks (`.sh:158`, `.ps1:81`) produce it when the classifier
  cannot run. The hook's final `case "$verdict"` (`.sh:249-294`) and `switch ($verdict)`
  (`.ps1:199`) have **no default branch**, so an unknown verdict exits 0 with no decision.
- **The surrounding policy:** CLAUDE.md (global) says "Merging, pushing, and publishing are
  per-action decisions". `standards/SECURITY-GUARDRAILS.md:115` makes a local `git merge` CONFIRM
  tier, and `:80-96` says approval cannot be hook-enforced.

**"Total" is already false.** All three of these were re-checked on 2026-10-20:
- **Escape spellings.** These classify as `NONE`:
  - `gh -R o/r pr merge`
  - the GraphQL route
  - `/usr/bin/env gh …`
  - `"FOO=bar" gh …`
- **Silent allow rules.** This worktree **has** an untracked `.claude/settings.local.json`, last
  modified 2026-10-20, contrary to the merge-gate-misses item's line 186.
  - It holds 17 allow rules broad enough to run one of those spellings with **no prompt** in
    default mode: a gh API rule, a gh repo rule, and interpreter one-liners.
  - The exact rules are kept out of this public file, per that item's redaction policy.
- **The app's auto-merge tool.** `mcp__ccd_pr__set_auto_merge` is not a Bash call, so no
  review-gate hook sees it.
  - Its description says the app "may approve without asking" in auto mode.
  - It is **inert on PMB today**, because the repo has `allow_auto_merge: false`.

## 2. Threat model

The new design has to keep these protections, or give each one up in writing.

| # | Threat |
|---|---|
| T1 | The agent decides on its own to merge |
| T2 | A stale approval: "merge #59" is reused for #71, or reused after new commits |
| T3 | A prompt injection ("merge it") arrives in a PR comment, CI log or file |
| T4 | An unreviewed, red-CI or moved head gets merged |
| T5 | The user approves something other than what they think: wrong repo, wrong PR, or an extra payload |
| T6 | A merge with no human present (subagent, `-p`, SDK, a `PermissionRequest` hook) |
| T7 | The hook fails open: crash, timeout, or version skew means no decision |
| T8 | A zero-click alternative route exists next to the prompt |

## 3. Evidence, and gate G0: measured in the app before any implementation

**Headless probe, 2026-10-20.**
- **Setup:** Claude Code CLI 2.1.285, with a PreToolUse hook returning `ask` for `ASKPROBE`.
- **Raw output:** side-session notes folder, `merge-gate-askprobe-2026-10-20/`. Readable from Git
  Bash; Python cannot read files there (MSIX virtualization).

| Requested mode | Mode in the hook payload | Forced `ask` | Control, no hook |
|---|---|---|---|
| default | `default` | refused | n/a |
| acceptEdits | `acceptEdits` | refused | n/a |
| **auto** | **`default`** | refused | refused (`-p` cannot grant) |
| dontAsk | `dontAsk` | refused | n/a |
| bypassPermissions | `bypassPermissions` | **refused** | **ran** |
| bypassPermissions, subagent | `bypassPermissions`, plus `agent_id` and `agent_type` | refused | n/a |

What this shows:
- **Headless never turns an ask into an allow**, and that includes bypassPermissions.
- **Only subagent payloads carry `agent_id`.**
- **Auto mode was never exercised.** `-p --permission-mode auto` ran as `default`. So there is
  **zero evidence** about auto, which is the mode the user runs.
- **The interactive CLI attempt** stopped at the folder-trust dialog. That dialog is the user's to
  accept, so the attempt was abandoned.

**G0 is a hard gate before any implementation, at the user's direction.** It runs in the desktop
app, in **auto mode**, in a throwaway probe folder outside every repo. The folder's
`.claude/settings.json` holds a hook that logs every payload and returns `ask` for its probes. The
user runs all of the following:

1. **Harmless probe.** Ask the session to run `echo ASKPROBE`. This is the strongest test against
   a silent allow, because a harmless command is what the auto classifier is likeliest to approve.
   - **Pass:** an Allow/Deny prompt appears, and the log shows the probe did not run before the
     click.
   - The user clicks **Deny**.
2. **Merge-shaped probe.** Ask it to run an inert `gh pr merge 99999 --squash
   --match-head-commit 0000…` in that folder. The folder is not a git repo, so even an accidental
   Allow cannot resolve a repo.
   - **Pass:** a prompt appears.
   - The user clicks **Deny**.
3. **Subagent probe.** Ask it to have a subagent run probe 1.
   - **Record:** whether the ask reaches the user or is refused.
4. **What the prompt displays.** Record exactly what it shows: the full command, the hook's
   reason, and/or the agent-written `description` field. That last one is agent-controlled text.
5. **The literal `permission_mode` string auto mode sends.** If it is `default`, the hook cannot
   tell auto from default. That is acceptable only if probes 1 and 2 passed.
6. **"Always allow".** Note whether the prompt offers one. If it does, choose it on probe 1, then
   re-run probe 1. **Pass:** it prompts again.
7. **Repeat 1 and 2 from the phone (Remote Control).** The user has push notifications on, so this
   is a realistic approval path.
   - **Pass:** a prompt or a refusal, never a silent run.
   - **Not run:** record it as out of scope, and the design then says mobile approval is unverified.

**If G0 fails** — any silent run, or a prompt that does not show the full command — the design
does not proceed. The recommendation then becomes option D (§4) only.

### G0 result, 2026-10-20: PASS

**Setup.** The run was in the desktop app, Claude Code 2.1.299, in the probe folder
`C:\Users\Mizzo\Claude\merge-gate-askprobe` (not a git repo), in session "G0 probe: merge-gate ask
in auto mode". The user clicked every prompt.
- **Evidence:** the probe's `payloads.jsonl` and `decisions.log`, which `ran-*.txt` files exist,
  and that session's transcript.

| Step | Hook payload | Outcome |
|---|---|---|
| 0 control `echo CONTROL` | `permission_mode: "auto"`, main agent | ran, no prompt (auto mode was live) |
| 1 `echo ASKPROBE` | `"auto"`, main; hook returned ask | prompt shown; user denied; transcript says "Request interrupted by user for tool use"; no `ran-1.txt` |
| 2 inert `gh pr merge 99999 … --match-head-commit 000…` | `"auto"`, main; ask | prompt shown; user denied |
| 3 subagent `echo ASKPROBE` | `"auto"`, **with `agent_id`**; ask | the subagent's ask **reached the user**; user denied; no `ran-3.txt` |
| 4-5 "always allow" | n/a | the prompt offered **only Allow/Deny**, so not applicable |
| 6 phone / Remote Control | not run | **mobile approval stays unverified** (§3 step 7) |

**What the prompt showed:** the full command, the hook's `permissionDecisionReason`, **and** the
agent-written `description`. So §5.4's rule is required, not conditional.

**Auto mode's literal mode string is `"auto"`.** The §5.3 allowlist works as written. Headless
`-p --permission-mode auto` reports `"default"` instead, which is why the earlier probe could not
see auto mode.

**Subagent asks reach the user in the app.** The design still denies them (§5.3). A subagent's
description is written by a model the user did not talk to.

## 4. Options

- **A. Keep the deny.** Handles T1-T3 and T6 for canonical forms only. It leaves T8 open, and it
  keeps the terminal friction.
- **B. The hook returns `ask` for one strict merge form**, and the user clicks Allow in the app.
  - The click comes from the harness and the agent cannot produce it.
  - It is per invocation, which handles T2. The human decides, which handles T1 and T3, provided
    T8 is closed (§7).
  - It depends on G0.
- **C. An agent-written approval marker.** **Rejected.**
  - Every input to the marker passes through the agent. An injection that can make the agent ask
    to merge can make it write the marker too.
  - The review markers work only because they bind a diff hash, and authorization has no hash.
  - The only per-PR approval the agent cannot forge without a terminal is the harness prompt, so C
    reduces to B.
- **D. GitHub-side.** The user clicks Merge in the GitHub web or mobile UI.
  - It changes no enforcement, the agent cannot forge it, and it needs no terminal.
  - The cost is leaving the app.
  - A GitHub approving review cannot be the token: PRs come from the user's own account, and
    GitHub does not let an author approve their own PR.
  - **D works today and is the fallback whatever happens here.**
- **B plus `gh pr view` precondition checks inside the hook.** **Rejected.** It adds a network call
  and its fragility. GitHub already enforces the same things at merge time: required checks with
  `strict`, and `--match-head-commit`.

## 5. Recommended design: B, hardened

### 5.1 The canonical form is a whole-command match, not a segment match

The existing classifier front end is built to answer "does this invoke a guarded verb".
- It splits commands into segments.
- It lifts `$( )` and backticks into nested segments.
- It skips `VAR=` prefixes and wrapper words.
- It accepts any path that ends in `gh`.
- In PowerShell it treats a backtick as substitution, although PowerShell treats it as an escape.

Reusing it would let `canonical-merge; <anything>`, `` …`--admin` ``, `GH_REPO=x gh …` or
`/tmp/gh …` pass as canonical (security HIGH-1, 2 and 4; Opposition S1). So canonical-ness is
decided on the **raw `tool_input.command` string**, read from the parsed JSON, by an anchored full
match:

```
\Agh pr merge [1-9][0-9]{0,8} -R unyieldingclaw-dev/personal-memory-bank (--squash|--merge) --match-head-commit [0-9a-f]{40}\z
```

- **The repo is mandatory and allowlisted** (Opposition B1, security HIGH-5).
  - `-R` overrides `GH_REPO`, the git remotes and `gh repo set-default`, all of which the agent
    can change.
  - The allowed `owner/repo` comes from a tracked file, so adopters set their own; for PMB it is
    the value shown above.
  - Flag order is fixed. Exactly one space separates tokens, with no quotes.
- **Character rules:**
  - Printable ASCII only. No `\r`, `\n`, `;&|()$`<>#"'\{}`, and no `=`.
  - No leading zero on N, because gh would read `007` as 7 while the prompt showed 007.
  - Python uses `re.fullmatch` with `re.ASCII` and **no** `\A`/`\z`. Python 3.11.9 on this machine
    raises `bad escape \z` (measured 2026-10-20). `fullmatch` already anchors both ends, and it
    does not accept a trailing `\n`.
  - PowerShell uses `-cmatch`, which is case-sensitive, with `\A…\z` and `[0-9]`, never `\d`.
  - Both twins share one table of fixtures.
  - **Any exception in the canonical check means deny.** That covers a regex error, a JSON parse
    failure, and an unreadable config.
  - **The allowlisted value is validated, then escaped.** It must match
    `^[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+$`, and it is inserted with `re.escape` /
    `[regex]::Escape`, so a `.` in a name such as `foo.js` cannot match any character.
- **This rejects some legitimate merges, by design.** The agent builds the command, so a fixed
  form costs nothing, and the deny prints the exact form to use. One consequence to expect: this
  repo's sessions habitually lead commands with `cd "<repo>" &&`. A merge led that way is denied,
  and with `-R` the `cd` is not needed.
- **The hook denies if `GH_HOST` or `GH_REPO` is set in its own environment.**
- **Out of scope for the canonical form:** `--admin`, `--auto`, `--delete-branch`, `--rebase`,
  body and subject flags, branch or URL selectors, and `cd` prefixes. Every one of them is denied.

### 5.2 The classifier contract is unchanged, and unknown verdicts deny

This answers security HIGH-3.
- **The classifier still emits plain `MERGE` for every merge.** An old hook paired with a new
  classifier, the partial-install class the comments already document, therefore keeps denying.
- **The canonical check lives in new helper files**, `scripts/_review-gate-merge.py` and
  `scripts/_review-gate-merge.ps1`. Each hook's merge branch calls them only after `MERGE`, and the
  hook never takes the result from classifier output.
  - Separate files keep this change out of the classifier, which open PR #78 is editing.
  - **Install skew, case by case:**
    - Old hook with the new helper: the unchanged MERGE branch denies.
    - New hook with the helper missing: the hook treats anything other than an explicit ASK from
      the helper as deny. The PowerShell twin loads the helper inside a `try`, as
      `review-reminders.ps1:97-101` does for the library.
    - python3 missing: the raw-text fallback gives `MERGE`, and §5.3's first row denies it.
  - Each of these is a named test (§9).
- **Both hooks gain a default-deny branch** for any verdict outside the known set.

### 5.3 Decision table, merge branch

Evaluated top to bottom; the first match wins.

| Condition | Decision |
|---|---|
| The verdict came from the raw-text fallback | deny |
| `MULTI` | deny |
| The top-level key `agent_id` is **present** in the parsed payload, whatever its value | deny: "subagents never merge" |
| `permission_mode` (parsed, exact match) is not in {`default`, `acceptEdits`, `auto`} | deny |
| `GH_HOST` or `GH_REPO` is set in the hook's environment | deny |
| A `PermissionRequest` hook is configured in user, project or local settings (§5.5) | deny, generic message |
| Any of those settings files allows a merge-capable prefix (§5.5) | deny, generic message |
| Any of those settings files exists but is unreadable or malformed | deny, generic message |
| The raw command fails the §5.1 full match | deny, and print the canonical form |
| Otherwise | **ask** |

**The "generic message"** is "Merge gate precondition failed. Ask the user to check this checkout's
Claude settings." It names no file and no rule. A message naming the file that holds a
merge-capable allow rule would point the agent straight at the silent route (third Opposition
pass, S3). The helper writes the specific cause to its stderr. Both hook wirings discard stderr
(`2>/dev/null`), so the cause is visible only when the helper is run by hand. The §9 tests check
that the JSON names neither the file nor the rule.

The ask's `permissionDecisionReason` is built only from the validated match:

> Merge PR #N in owner/repo by squash (or merge-commit), exactly at head <full 40-hex SHA>. Approve
> only if YOU asked to merge this PR just now. This approval covers this one command.

- **Output:** the shell twin writes one JSON object through the same escaping as `deny()`; the
  PowerShell twin uses `ConvertTo-Json`. Both then `exit 0`, so the `|| bash` fallback never fires
  after a decision has been printed.
- **Audit:** on every ask, the hook appends a tab-separated line, `ts, permission_mode, repo, N,
  sha`, to `.claude/merge-asks.log`. That file is ignored by `*.log` at `.gitignore:54`.
  - The hook writes it **after** printing the decision, and ignores any failure.
  - It records asks, not the user's answers.
  - The agent can write to it, so it is not tamper-evident.
  - It lives under the project directory the hook resolves (`CLAUDE_PROJECT_DIR`, else the hook's
    working directory). That directory may be the main checkout, not the worktree (§7).
  - It is a convenience. GitHub's "merged by" event is the authoritative record.

### 5.4 The description field (Opposition S3)

**G0 showed that the prompt displays the agent-written `description`.** The hook therefore
denies unless `tool_input.description` is absent or exactly equals the fixed string
`Merge pull request (verify the details in the hook reason)`. The deny message gives that string.
This stops the agent from labelling the prompt "Merge PR #77 as you asked" over a command that
merges #71.

### 5.5 Other resolvers (Opposition S4)

Under a deny, no `PermissionRequest` hook can override a merge. Under `ask`, a hook that returns
allow becomes a zero-click merge path.
- **In the merge branch:** the hook reads `~/.claude/settings.json`, the project's
  `.claude/settings.json` and `.claude/settings.local.json`. It denies if any of them configures
  `PermissionRequest`.
- **Plugins:** their `hooks.json` files are out of this hook's reach. A follow-up PR adds an
  `mb doctor` check for them; see §11.
  - Until then, a plugin `PermissionRequest` hook is an **accepted residual**.
  - Measured on 2026-10-20: no installed plugin's cache contains `PermissionRequest`. The one
    marketplace plugin that has it is not installed, and its matcher is `AskUserQuestion`.
- **Merge-capable allow rules.** In the same pass, the hook denies when any of the three files
  allows a prefix that can carry a merge with no prompt:
  - a bare `gh` rule, or a `gh api` rule;
  - a `gh pr` rule, or any rule shaped like `gh pr merge`. **Unmeasured:** whether an allow rule
    overrides a hook's ask. Denying these shapes makes the question moot, which is cheaper than
    measuring it;
  - `Bash(*)` or `PowerShell(*)`;
  - wildcard interpreter one-liners (python, node, pwsh `-c`/`-e`/`-Command` forms).
  - **Why this is a per-merge check:** P1 (§7) is a one-time cleanup, and clicking "don't ask
    again" on any ordinary `gh api` read writes such a rule back. Worktrees also inherit the file.
  - The exact prefix list lives in the hook and its tests, not in this public spec.
  - **`Bash(git *)` is deliberately not on the list.** The tracked settings and the template
    both allow it, so listing it would deny every merge, on PMB and for every adopter. See the
    residual below.
- **Known residuals**, stated rather than hidden. Each one is **equal to today's exposure**, not
  created by this change:
  - **Zero-click routes through rules that stay allowed.**
    - A git alias that shells out (`git -c alias.x='!…' x`) classifies as `NONE` (measured
      2026-10-20), and `Bash(git *)` may allow it. Whether Claude Code's prefix rule matches that
      shape is **unmeasured**.
    - In acceptEdits mode, a Write followed by a run under `Bash(bash tests/*.sh)`, `npm run *` or
      `npx *` can execute arbitrary code.
    - The escape-spelling fix and a later rule audit own these routes. P1 does not close them.
  - a plugin `PermissionRequest` hook, until the doctor follow-up lands;
  - settings sources the hook does not read: managed or policy settings, `--settings`/SDK-supplied
    settings, and a non-default `CLAUDE_CONFIG_DIR`;
  - `GH_HOST` set in the Bash tool's own shell (an env file or a profile), which the hook's
    environment check cannot see. That risk is low while only github.com is authenticated;
  - a `gh` function, alias or earlier-on-PATH binary in the user's shell. That would run under an
    approval for the canonical text. Planting one means writing outside the project, which prompts
    in default mode.

### 5.6 App and MCP merge routes (Opposition S7)

**Use `permissions.deny` rules, not a hook.** This replaces revision 3's MCP hook (third
Opposition pass, B1).
- `tests/test-mirror-parity.sh` (`:386-387`, `:429-430`) requires hook wiring in the live
  `.claude/settings.json` to match `templates/.claude/settings.json`, and CI runs it. So a PMB-only
  hook entry would turn CI red.
- The workarounds are both worse. Copying it into the template ships adopters wiring to scripts
  they never receive, and exempting it weakens the parity test.
- Permissions are deliberately not parity-checked (`:368-376`).

The design:
- **Deny rules in the tracked `.claude/settings.json`:**
  - `mcp__ccd_pr__set_auto_merge`;
  - the GitHub plugin server's merge tool, whose exact name is verified at implementation (the
    server is inert today).
- **Why this is better than the hook:**
  - A deny rule cannot crash, so there is no fail-open path.
  - It does not depend on PreToolUse firing for MCP tools.
- **The cost:** `enabled: false` is denied too. That is acceptable, because the user can turn
  auto-merge off in the GitHub UI, and on PMB it cannot be on anyway (`allow_auto_merge: false`).
- **G2** measures it safely: call `set_auto_merge` with `enabled: false` against a bound PR. Pass
  means the call is refused. Nothing can be enabled.
- **Adopters** do not get these rules, because `mb upgrade` owns `permissions` ([NS-50](a)). The
  CHANGELOG says so.

### 5.7 Crash path, a stated deviation (Opposition S6, security MEDIUM-3)

The backlog asked that a crash on the merge path deny. A deny cannot be had cheaply:
- `exit 2` in the wiring would block **every** Bash call whenever both shells are missing.
- So this design instead adds `permissions.ask` rules `Bash(gh pr merge:*)` and
  `PowerShell(gh pr merge:*)` to the tracked `.claude/settings.json`.
- A crash then **prompts without the hook's checks** (subagent, mode, form). It does not run
  silently.
- **This is a deviation from the backlog.** Adopters do not get the rules, because `mb upgrade`
  owns `permissions`, [NS-50](a). For them a crash still means no decision.
- **The docs' claim that an ask rule prompts even in auto mode is unmeasured here.** G1 adds a
  probe for it: in the probe folder, the hook is removed and only a `permissions.ask` rule is left,
  in auto mode. Pass means a prompt appears.
- **NS-50 inside PMB itself:** an `mb upgrade` run in PMB would strip these rules silently. The
  doctor follow-up (§11) warns on that. Until it lands, this is a stated residual.

### 5.8 Per-mode behaviour after the change

| Mode | Canonical merge, main agent | Subagent, or any other form |
|---|---|---|
| default, acceptEdits | prompt | deny |
| auto | prompt (G0 measured this; it never clicked Allow, which G3 covers) | deny |
| plan, dontAsk, bypassPermissions | deny. The hook rule is not a measured fact about prompts: headless cannot show prompts in any mode | deny |
| `-p` or SDK | deny or refused (measured: refused) | deny |

## 6. Honest pushback

- **A click is less deliberate than a paste,** and people click through prompts. What helps: the
  reason names the repo, the PR, the method and the full SHA, and in auto mode a prompt is rare and
  stands out. If the merge step is meant to include the user re-reading the PR, no hook enforces
  that, and this design gives it up.
- **[NS-27]:** the merge stays a human decision, but that decision now happens inside the agent's
  session.
- **The full SHA is still agent-supplied,** and the user cannot verify hex. What `-R` plus
  `--match-head-commit` guarantees is this: the PR shown, in the repo shown, merges only if its
  head is that commit. It does not guarantee that the commit was certified by `/change-review`.
  Any head this agent pushed did pass the push gate. A head pushed by someone else did not. That
  residual is accepted, and an agent-writable "reviewed heads" file would not close it (option C).

## 7. Ordering: a narrower prerequisite than the backlog's

- **The backlog wants every escape spelling fixed first.** The Opposition review showed that the
  part of that problem that is **zero-click**, the silent allow rules in §1, is what makes B
  unsafe. B's own deny branches tell an agent that merging is a sanctioned goal, and an allow rule
  then offers it a silent route.
- **So the prerequisite is P1, an operator task done with the user before G3:**
  - Prune the merge-capable allow rules from `settings.local.json` in the main checkout and in
    every worktree that has one.
  - Record that worktrees **do** carry that file, which corrects the backlog's line 186. Measured
    2026-10-20: 29 of 38 worktrees have one.
  - The rule text stays in the untracked artifacts directory, not here.
- **Hooks in a worktree session run the main checkout's scripts.** This was observed on
  2026-10-20, twice, by the implementing session and by the `/code-review` Opposition pass. A
  merge-shaped command run from this branch's worktree drew the *old* deny text, even with a
  quoted `cd` to the worktree.
  - **So the new gate is live only once the main checkout is on a `main` that contains it.** G1
    must run then, because from a worktree before that it tests the old hook.
  - **The helper then most likely reads the main checkout's settings**, not the worktree's. Which
    directory `CLAUDE_PROJECT_DIR` names in a worktree session is unmeasured.
- **Between the merge of this PR and P1:**
  - The main checkout's `settings.local.json` held 8 merge-capable rules on 2026-10-20, measured
    with the helper's own `merge_capable`. If the inference above holds, every merge is therefore
    denied by the §5.5 check, in every session, until P1. That is safe, and revision 4's claim
    that worktrees without their own `settings.local.json` would ask is withdrawn.
  - **Not measured:** which settings the permission engine itself applies in a worktree session.
  - **The procedural rule:** no real merge through the agent (G3) until P1 is done.
- **P1 does not close every zero-click route.** §5.5's residuals (the git alias, test and npm
  scripts) stay as they are today.
- **The escape-spelling classifier fix stays a separate, already-specified item.** It should
  follow, but it is not a prerequisite. After P1, those spellings are not silent: in default mode
  they prompt, and in auto mode they reach the classifier, exactly as they do today. B does not
  widen them.
- **If the user prefers the backlog's original order,** this spec waits for that item. Nothing in
  it conflicts.

## 8. Parity, reach, and overlap

- **What ships to every adopter (TEMPLATE_OWNED):** both hook twins, both new merge-helper twins,
  and their byte-identical `templates/scripts/` mirrors.
  - **The helpers go in all five `mb` lists that name the classifier today:**
    - `mb init`: `scripts/mb.sh:700-711` and `scripts/mb.ps1:1009`;
    - the governance-missing list: `mb.ps1:240-255`;
    - TEMPLATE_OWNED: `mb.sh:2148` and `mb.ps1:2446`.
  - The doctor's missing-helper error is modelled on `mb.ps1:1282-1283`.
  - Missing any one of these would make `mb init` install the hook without its helper. That fails
    closed, but it denies every merge for new adopters. `test-mb-init.sh`, `test-mb-upgrade.sh` and
    `test-mirror-parity.sh` are among the targeted suites.
  - The allowed `owner/repo` comes from a tracked config, not a literal. Adopters set their own.
  - With the config unset, every merge denies.
- **`.claude/settings.json` gets only permissions entries**: the ask rules and the MCP deny rules.
  They are PMB-only, they are not parity-checked, and the hook wiring is unchanged. The adopter
  impact goes in the CHANGELOG.
- **Overlap.**
  - #71 has merged as `2c4088f`, and implementation bases on current `origin/main`. It changed
    only the COMMIT case.
  - **#78** (open) edits `_review-gate-classify.ps1`, `tests/run.sh` and `CHANGELOG.md`.
  - **#79** (open) edits `tests/test-review-reminders.sh`.
  - This PR avoids the classifier and that test file entirely, by using the new helper and suite
    files. It shares only `tests/run.sh` (one registration line) and `CHANGELOG.md` (one entry)
    with #78. Both are trivial rebase conflicts, resolved by whichever PR lands second.
  - The line numbers cited in §1 will shift once those PRs land.

## 9. Test plan

**Manual acceptance gates.** Only a human can observe a prompt, so each of these needs the user.
- **G0 (§3)** ran before implementation and passed.
- **G1** runs after implementation, in auto mode. It has two parts:
  - **(a)** The canonical merge form against an inert PR number gives a prompt that shows the
    hook's reason. The user clicks Deny.
  - **(b)** In the probe folder, the hook is removed and only a `permissions.ask` rule is active.
    Pass means a prompt appears; it verifies §5.7's crash-path claim.
- **G2:** `mcp__ccd_pr__set_auto_merge` with `enabled: false` against a bound PR is refused by the
  deny rule. Nothing can be enabled.
- **G3:** one real canonical merge of a PR the user chooses, **after P1**, approved by the user's
  click and checked on GitHub. This is the first Allow click, which G0 never made.

**Automated tests.** Each one is mutation-checked: remove the handling and the test must go red.

`tests/test-merge-gate.sh` is a new suite registered in `tests/run.sh`, so it stays clear of #79's
file. It runs against both twins and covers:
- **The canonical form** produces an `ask` whose reason contains the repo, N, the method and the
  full SHA, with exit 0 and exactly one JSON object.
- **Each of these denies:**
  - `-R` missing, or `-R` naming another repo;
  - no SHA, a short SHA, an uppercase SHA, or N with a leading zero;
  - `--admin`, `--auto`, `--delete-branch` or `--rebase`;
  - a different flag order, or a doubled space;
  - a trailing `; x`, `&& x`, `& x`, `| x`, newline, CR, `# c` or `> f`;
  - `$(x)` or a backtick anywhere;
  - `VAR=v` or wrapper prefixes;
  - a path-qualified `gh`, or a `cd` prefix;
  - NBSP between tokens, or a non-ASCII digit;
  - the REST form, or `MULTI`.
- **Payload variants:**
  - `agent_id` present: as null, as `""`, and as an id.
  - `permission_mode` set to `bypassPermissions`, `dontAsk` or `plan`, or missing.
  - Look-alike JSON text inside the command does not spoof the mode or `agent_id`.
- **Environment and settings:**
  - `GH_REPO` or `GH_HOST` set in the environment.
  - A fixture settings file with a `PermissionRequest` hook.
  - A fixture with each merge-capable allow prefix.
  - A malformed settings file.
  - An unreadable settings file.
- **Canonical check failures:**
  - a forced exception inside the check denies;
  - an allowlisted value containing `.` does not match `x`;
  - an allowlisted value that fails `owner/repo` validation denies.
- **Description:** a custom `description` denies. An absent one, or the exact fixed string, gives
  ask. A near-miss of the fixed string (one changed character, a trailing space) denies.
- **Generic deny message:** for each §5.5 precondition failure, stdout's JSON names neither the
  settings file nor the rule.
- **MCP:** the tracked `.claude/settings.json` holds the deny rules, a JSON assertion confirms it,
  and the hook wiring still matches the template.
- **Fallback and version skew:**
  - With python3 unreachable, the fallback denies the canonical form. Pin the verdict path, using
    the `command -v python3` SKIP convention.
  - An unknown verdict string is denied (version-skew guard).
  - **The helper file is missing** for each twin: the canonical form denies.
  - `echo gh pr merge …` stays `NONE`.
- **Twin parity:** `diff -q` assertions for both hooks, both helpers, and their templates.

Other suites:
- **`tests/merge-gate.Tests.ps1`** (new, CI-run by Pester): the same fixture table, run against the
  PowerShell helper.
- **Targeted existing suites:** `test-mb-init.sh`, `test-mb-upgrade.sh` and
  `test-mirror-parity.sh`. They prove the helpers ship through all five `mb` lists and that the
  hook wiring is unchanged.
- **`tests/gate_matrix.py`:** add an `ASK` outcome to `run_hook()`, whose current `ALLOW` default
  would hide a regression from ask to allow. It is only ever run through `mutate.py`, on a copy.

**Mutations to prove:** each of these must turn a test red.
- ask changed to allow;
- the `agent_id` check removed;
- the mode check removed;
- `fullmatch` changed to `match`, in Python;
- `\z` changed to `$`, in PowerShell;
- the allow-rule check removed;
- `re.escape` removed;
- the exception-to-deny handler removed;
- the case-sensitive match changed to a case-insensitive one;
- the repo allowlist removed;
- relaxing the full match, for example by adding `.*` at its end. The implementation has no
  separate charset check: the anchored full match permits only the literal canonical characters,
  so it *is* the charset rule;
- the default-deny verdict branch removed;
- the `PermissionRequest` check removed.

Run the targeted suites in both shells. Do not run `tests/run.sh`, which is not concurrency-safe.

## 10. Review findings and their dispositions

| Finding | Disposition |
|---|---|
| Opp B1 / Sec HIGH-5: repo unbound | §5.1: mandatory `-R`, allowlisted; `GH_*` deny; repo in the reason |
| Opp B2: zero-click allow rules | §7 P1 prerequisite; §1 corrects the backlog |
| Opp S1 / Sec HIGH-1: segment-level canonical check | §5.1 whole-string anchored match |
| Sec HIGH-2: PowerShell backtick escape | §5.1 charset rejects the backtick |
| Sec HIGH-3: new verdict fails open on skew | §5.2: verdict unchanged, plus a default-deny branch |
| Sec HIGH-4: env, wrapper and path prefixes | §5.1 match begins with the literal `gh ` |
| Sec MED-1: twin divergence (case, `$`, `\d`, Unicode, CR) | §5.1 rules plus a shared fixture table |
| Sec MED-2: spoofable mode and `agent_id` | §5.3: parsed top-level keys, presence test |
| Sec MED-3 / Opp S6: fail-open wiring | §5.3 single JSON output with `exit 0`; §5.7 stated deviation |
| Opp S2: G1 could not prove auto mode | §3: G0 in the app before implementation; headless auto ran as `default` |
| Opp S3: agent-written description | §3 G0 step 4; §5.4 |
| Opp S4: `PermissionRequest` resolvers | §5.5 |
| Opp S5: mobile and Remote Control | §3 G0 step 7 |
| Opp S7: auto-merge tool | §5.6: denied, as of revision 4 by a `permissions.deny` rule |
| Opp N1: auto-merge inert on PMB | §1 and §7 reworded |
| Opp N2: bypass row overreach | §5.8 reworded |
| Opp N3: audit trail | §5.3 `.claude/merge-asks.log` |
| Sec LOW-1: sha7 only | §5.3: full SHA and method |
| Re-review: P1 can quietly come undone | §5.3 and §5.5: allow-rule check on every merge; the doctor check is a follow-up (§11) |
| Re-review: Python rejects `\z` | §5.1: `fullmatch` without anchors in Python; an exception denies |
| Re-review: the two MCP matchers conflict | superseded in revision 4: no MCP hook; §5.6 deny rules |
| Re-review: unreadable or malformed settings | §5.3 deny row; §5.5 residual list |
| Re-review: regex escaping, audit log, `gh` identity | §5.1 escape; §5.3 audit notes; §5.5 residual |

**The Opposition re-review of revision 2 returned "Approve with conditions".** Revision 3 met its
four spec conditions, and G0 then passed.

**Third Opposition pass, on revision 3 plus contract v1: "Request Changes".** Revision 4 dispositions:

| Finding | Disposition |
|---|---|
| B1: a PMB-only MCP hook breaks the CI hook-parity test | §5.6: `permissions.deny` rules instead; hook wiring unchanged |
| S1: the helpers missing from three other `mb` lists | §8: all five lists; `mb` suites targeted |
| S2: P1 does not remove every zero-click route; allow rules versus the hook's ask | §5.5: residuals stated (git alias, test and npm scripts); `gh pr` / `gh pr merge` rule shapes denied; `git *` deliberately excluded |
| S3: the deny message names the silent route | §5.3 generic message; §9 test |
| S4: the deferral rationale contradicted §5.5 | §5.5 plugin residual stated with a measurement; §11 says follow-up |
| S5: "denies every merge until P1" is false in 9 worktrees | §7 corrected; G3 after P1 is procedural |
| S6: helper-missing and ask-rule crash path unmeasured | §5.2 skew cases; §9 helper-missing tests; G1(b) |
| Nits: stale §5.8; header against contract; #78 shares `run.sh` and `CHANGELOG`; NS-50 in PMB; G0 never clicked Allow | all reworded (§5.7, §5.8, §8, §9 G3) |

## 11. Docs to update, in the same change

- **The rationale comments** in both hook twins and their mirrors.
- **`docs/HOOKS-GUIDE.md`**, the `gh pr merge` section (`:255`) and the examples at `:35` and
  `:37`, plus the `templates/` copy.
- **`standards/SECURITY-GUARDRAILS.md`** and its twin:
  - add a `gh pr merge` row: CONFIRM, hook-enforced through a harness prompt;
  - amend "What Counts as Approval" (`:80-96`).
- **`CHANGELOG.md`:** the adopter note covers three things:
  - the repo allowlist config, and that every merge is denied when it is unset;
  - that the ask rules and MCP deny rules are PMB-only;
  - the crash-path residual.
- **Both backlog items:**
  - the replace-the-deny item is marked resolved by this spec;
  - the merge-gate-misses item gets the line-186 correction, the app-tool route, and the
    git-alias route.
- **Follow-up PR, not this one: the `mb doctor` checks.** It covers plugin `PermissionRequest`
  hooks, merge-capable allow rules, and missing ask rules. Until it lands, those are the stated
  residuals in §5.5 and §5.7. This change ships only the missing-helper error that parallels
  `mb.ps1:1282`.
- **Owed afterwards, from the main checkout only:** `memory-bank/activeContext.md`'s line saying
  the agent never runs `gh pr merge`.
