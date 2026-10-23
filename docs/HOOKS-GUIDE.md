# Hooks Guide

<!-- SYNC NOTE: templates/docs/HOOKS-GUIDE.md is a manually-trimmed copy of this file (PMB's
     own postmortem/bug-history prose and maintainer notes about PMB's internal plans, such as
     the [NS-26] bullet, removed; everything else kept). Edits to shared content
     here (hook tables, config snippets, per-hook descriptions) must be mirrored there by hand. -->

PMB uses native lifecycle hooks where the platform exposes an enforceable event. Claude Code can
block compaction; Codex provides deterministic post-compaction recovery; Cursor's `preCompact` event
is observational, so its handoff rule remains advisory. Unlike instruction files, configured hooks execute outside the
model's discretion, subject to platform enablement and trust settings.

## Hook Types

| Hook | When it fires | Primary use |
|------|--------------|-------------|
| `PreToolUse` | Before Claude runs a tool | Block dangerous operations, validate inputs |
| `PostToolUse` | After Claude runs a tool | Auto-format, run lint, log actions |
| `Stop` | When Claude pauses for input | Desktop notification |
| `PreCompact` | Before context compaction | Save state summary |

## Enforcement Layer Architecture

Hooks are one layer in a four-layer enforcement stack. Understanding which layer owns which concern prevents duplication and drift:

| Layer | Kind | Owns | Does NOT own |
|-------|------|------|-------------|
| **CLAUDE.md** | Advisory | Behavioral norms, workflow philosophy, code style | Anything requiring guaranteed execution |
| **Hooks** | Deterministic structural | Per-tool-call pattern enforcement: dangerous commands, credential access | Semantic correctness, business logic review |
| **Reviewer / Opponent** | Semantic | Spec compliance, scope drift, code quality | Mechanical pattern matching |
| **CI** | Deterministic gate | Codebase invariants: file size, forbidden imports, secret scanning | Real-time per-command interception |

**Design rule:** Don't duplicate concerns across layers. If a check belongs in CI, adding it to hooks creates two places to update when patterns change. If a check is semantic, adding it to hooks creates false confidence (simple pattern matching misses context). Each layer does its job; the stack as a whole provides defense in depth.

**Worked example — why "was this authorized?" stays advisory:** A session merged a feature branch into a shared branch after the user replied "what do you suggest" to a structured choice — a request for a recommendation, not a directive, but the agent treated it as one. A `PreToolUse` hook can't fix this: it sees only the `git merge` command about to run, never the chat turn that did or didn't authorize it. The tempting fix — a marker file the agent writes after concluding "the user approved this" — is exactly as fakeable as a self-written code-review marker, which is why `/code-review` and `/change-review` bind their markers to a SHA-256 of the actual reviewed diff instead of an unverifiable claim (see the `review-reminders.sh`/`.ps1` header comments). There's no equivalent artifact to hash for "the user meant this right now," so this stays a `standards/SECURITY-GUARDRAILS.md` rule (see "What Counts as Approval") — caught by drift-resistant discipline, not a gate that always fires.

**Worked example — why "the user ran it themselves" can't be hook-enforced either:** A session made several commits by asking the user to run `git commit` directly whenever the review-gate marker-write was blocked — a workaround this repo had normalized across many prior sessions, since the `PreToolUse` hook only sees Bash calls the agent itself makes, never a command typed into the user's own terminal. The user caught this live and named it directly: the user must never be used to bypass a control the agent couldn't satisfy. This is distinct from `dangerous-commands.sh`'s BLOCK/CONFIRM tiers — force-push is refused outright (BLOCK), while `filter-branch`/`--no-verify`/`chmod -R 777` prompt "run manually if intentional" (CONFIRM) — those blocks exist specifically so only a human's hands ever pull that trigger, and the user running them directly genuinely resolves the concern. The review-gate marker's purpose is different: verifying review already happened, which the user running the command themselves does nothing to make true. No hook fix exists for this either — asking the user to run something isn't a tool call, so there's nothing for `PreToolUse` to see or deny. It stays a `standards/SECURITY-GUARDRAILS.md` rule (see "The User Is Never the Compliance Bypass") for the same reason "What Counts as Approval" does: some things can only be caught by discipline, not by a gate. The actual hard backstop for this specific case is designed, not yet built — see `docs/superpowers/specs/2026-08-12-review-gate-layered-enforcement-design.md`'s Layer 3 CI check, which would catch an unreviewed commit regardless of how it landed.

## Default Hooks in This Standard

Configured in `.claude/settings.json`:

**How a `PreToolUse` hook is heard.** Plain text a `PreToolUse` hook prints never reaches Claude (measured), and Claude Code's docs say it is not shown in the visible transcript — it is only recorded (debug log, session file). So each hook prints at most ONE JSON object: `permissionDecision: "deny"` to block, top-level `systemMessage` for you, `hookSpecificOutput.additionalContext` for Claude. Any text beside that object makes Claude Code ignore it. The Contract Scope Check (§3) still prints plain text, so its warning is currently not seen.

### 1. Dangerous-Command Blocker (`PreToolUse` — Bash + PowerShell tools)

Intercepts both Bash and PowerShell tool calls before they run using `scripts/dangerous-commands.ps1`. Enforces 3-tier safety:

**BLOCK** (19 patterns — command exits non-zero, Claude stops):\
*Shell:* `rm -rf` · `mkfs` · `dd if=` · `git push --force` · `git push -f` · `DROP TABLE` · `DROP DATABASE` · `| bash` · `| sh` · `|bash` · `|sh`\
*PowerShell-native:* `Remove-Item -Recurse -Force` · `Remove-Item -Force -Recurse` · `Format-Volume` · `| Invoke-Expression` · `|Invoke-Expression` · `| iex` · `|iex`

**CONFIRM** (10 patterns — surfaces confirmation dialog):
`git filter-branch` · `git update-ref` · `sudo rm` · `chmod -R 777` · `--no-verify` · `git merge <branch>` (boundary-matched: excludes `git merge-base`) · commit-signing bypass (regex, four patterns: `commit.gpgsign` set to any falsey value — key or value quoted or bare — via `git -c`, the same via a `git config` subcommand, `--unset`/`--unset-all commit.gpgsign`, and `--no-gpg-sign`)

The signing key patterns anchor to the flag or subcommand that actually sets config, so
`git commit -m "...commit.gpgsign false..."`, `git log -S "..."` and trailing `#` comments do not
fire. Before any tier matches, backslash-newline continuations are **deleted** and runs of blanks
collapsed, so a wrapped command is matched as the shell will actually run it. Deletion rather than
substitution matters: a line break placed mid-token would otherwise split a literal BLOCK
substring (`rm -r\`⏎`f` → `rm -r f`), and a break inside double quotes concatenates with no space
at all. This applies to every tier. See `standards/SECURITY-GUARDRAILS.md` for the accepted false
positives and for what the gate deliberately does not cover (`GIT_CONFIG_*` env vars, direct
`.git/config` writes, `tag.gpgsign`/`push.gpgSign`).

**WARN** (4 patterns — exits 0, surfaces access alert):
`id_rsa` · `.pem` · `.env.production` · `credentials.json`

If BLOCK or CONFIRM is triggered, the tool call is denied before it executes. WARN surfaces the access — a `systemMessage` for you and `additionalContext` for Claude, all matches in one object — and lets the command proceed.

#### Matching is case-insensitive — and in `.sh`, **patterns must be written in lower case**

Every tier matches without regard to case, in both shells. `.ps1` gets this from
`OrdinalIgnoreCase` / `RegexOptions.IgnoreCase` at each site. `.sh` gets it by folding the command
to lower case **once** — `cmd_lc` and `cmd_loose_lc`, built beside `cmd_loose` — and matching every
`case` against those folded views.

**The rule when adding a pattern to `dangerous-commands.sh`: write it in lower case.** `block`,
`confirm`, `confirm_boundary` and `warn` compare `$1` against an already-folded
subject and do **not** fold `$1` themselves. An upper-case pattern therefore matches nothing, ever —
silently, and **fail-open**. Nothing at the call site looks wrong; the guard simply stops guarding.
This is why `chmod -R 777` is spelled `chmod -r 777` in **the script's** pattern list, while the
tier lists above show the command as an operator would actually type it. The real `chmod -R 777` is
still caught, because the *subject* is folded before comparison.

`confirm_regex` and `block_regex` are the exception — their patterns go to `grep -qziE`, which folds via `-i`, so case
there is unconstrained.

**Regex rows and locale.** Case-insensitive regex matching follows the locale unless it is pinned.
The `.ps1` regexes set `RegexOptions.CultureInvariant`. Under tr-TR, `IgnoreCase` alone does not
fold `I` to `i`: measured on a copy without it, the signing rows and the `iex` regexes returned no
verdict. On the sh side, `block_regex` runs under `LC_ALL=C` only. `confirm_regex` runs twice, under
the caller's locale and then under `LC_ALL=C`, because each alone misses a bypass. The byte locale
counts the `.{0,255}` gaps in bytes, and a Turkish UTF-8 locale misses an upper-case key. So a new sh regex
row inherits its matcher's locale rule, which can change what it matches.

**Platform requirement (sh hook):** stated once, with what each missing piece costs, in
`standards/SECURITY-GUARDRAILS.md` under "Platform requirement (sh hook)". Keep regex repetition bounds at 255 or below, the POSIX `RE_DUP_MAX` guarantee, so
a grep that supports `-z` but caps bounds there can still compile every row. The test suite fails on
any row above 255.

**Why the patterns aren't just folded per call** (the obvious alternative, which was built and then
reverted): folding `$1` inside each matcher costs a `printf | tr` subshell per matcher *call* —
about 25 per invocation, on a hook that runs on **every single Bash tool call**. Measured over 10
runs of one benign command: **1.07s → 2.33s per invocation**. Folding the two subjects once instead
costs two subshells total (three when the command holds a carriage return) and measures at
parity with the pre-fold baseline.

Both suites assert this structurally, so the fail-open trap is a red test rather than a silent
hole: no matcher may match against an unfolded view, and no pattern argument may contain an
upper-case letter. Both mirrors (`scripts/` and `templates/scripts/`) are checked, plus a
byte-identity assertion between them.

Implemented in `scripts/dangerous-commands.ps1` (Windows/pwsh) and `scripts/dangerous-commands.sh` (POSIX/bash). Configured in `.claude/settings.json` with two matchers — one for `Bash` (with sh fallback) and one for `PowerShell` (PS-only):

```json
{ "matcher": "Bash",       "command": "pwsh -NonInteractive -File scripts/dangerous-commands.ps1 2>/dev/null || bash scripts/dangerous-commands.sh 2>/dev/null || true" },
{ "matcher": "PowerShell", "command": "pwsh -NonInteractive -File scripts/dangerous-commands.ps1 2>/dev/null || true" }
```

**Timeout (checked against the Claude Code hooks reference on 2026-10-15):** neither entry sets
`timeout`, so each gets the default for a command hook, 600 seconds. A PreToolUse hook that times
out does not block the tool call: its output is discarded and the call continues through the
normal permission flow, unless the entry sets `"onFailure": "block"` (Claude Code v2.1.295 or
later). The PowerShell hook's measured worst case, a ~50 KB command, is under 30 seconds (the
figures are in `standards/SECURITY-GUARDRAILS.md`), far inside the default. Whether to set
`onFailure` is an open decision in `docs/backlog/dangerous-commands-follow-ups-after-ns38-ns40.md`.

**Two bugs found and fixed (2026-07-02) that made this hook a near-total no-op:**

1. **Wrong JSON field path.** The hook read `$data.command` (flat), but the real `PreToolUse` payload nests everything under `tool_input` (`{"tool_name":"Bash","tool_input":{"command":"..."}}`), confirmed by capturing a live hook payload. `$cmd` was always empty, so no BLOCK/CONFIRM/WARN pattern ever matched, regardless of the command run. Fixed to read `$data.tool_input.command`.
2. **Non-blocking exit code.** BLOCK/CONFIRM used `exit 1` to signal denial. `settings.json` wires this hook with a `... || true` fail-open suffix for cross-platform portability (so a missing `pwsh`/`bash` doesn't break every Bash call) — that suffix silently converts *any* nonzero exit code to 0, including an intentional block. Verified empirically: a real `git commit` went through untouched despite the hook firing. Fixed by switching BLOCK/CONFIRM to `hookSpecificOutput.permissionDecision: "deny"`, printed to stdout — Claude Code reads this regardless of the wrapping shell's final exit code, unlike an exit code which the `|| true` suffix erases.

Both bugs were latent since the hook was written; neither is specific to this repo's platform. If you're auditing a PMB-managed project that predates 2026-07-02, run `mb upgrade` to pick up the fix.

**Hook error logging (G2):** if `dangerous-commands.ps1` fails unexpectedly, the catch block appends a timestamped entry to `.pmb-hook-errors.log` (gitignored). `mb doctor` Check 16 surfaces entries from this log as WARN.

### 2. Stop Notification (`Stop`) — excluded from install template

The Stop hook is excluded from `templates/.claude/settings.json` because it causes indefinite hangs in `--Remote-Control` mode (Claude in Chrome). In that mode Claude runs headless; the hook fires but no user is present to dismiss the Windows MessageBox, stalling the session permanently. PMB's own `.claude/settings.json` keeps this hook as a deliberate choice for interactive Windows sessions; it is excluded from the install template to prevent those hangs in remote/headless environments. If you need a Stop notification in an interactive-only project, add it to that project's local `.claude/settings.json` manually.

### 3. Contract Scope Check (`PreToolUse` — Write + Edit tools)

Checks whether a file being written is within the scope declared in the active task contract (`.claude/contracts/active-task.json`). Implemented in `scripts/check-contract.ps1` and `scripts/check-contract.sh`.

- **No contract / inactive contract:** exits 0 silently.
- **Out-of-scope write (default):** prints a warning and exits 0. The warning is plain text, so it currently reaches neither you nor Claude (see "How a `PreToolUse` hook is heard" above; tracked in `docs/backlog/check-contract-output-is-plain-stdout.md`).
- **Out-of-scope write (hard-block mode):** the tool call is denied when `PMB_CONTRACT_HARD_BLOCK=1` is set in the `env` block of `.claude/settings.json`.

Set `PMB_CONTRACT_HARD_BLOCK=1` for sessions where scope discipline is critical. See `standards/SECURITY-GUARDRAILS.md` for the full env-block example.

**Three bugs found and fixed (2026-07-02) that made this check silently never work:**

1. **Wrong contract schema.** The hook read `contract.scope.files`, but the documented schema (`docs/CONTRACTS-GUIDE.md`) is `scope: [{file, op}, ...]` — an array, not an object with a `.files` property. Against a real contract, `$scopeFiles` was always null, so the scope check never matched an in-scope file correctly.
2. **Wrong JSON field path for the target file.** Same class of bug as `dangerous-commands.ps1`: the hook read `$inputData.file_path` (flat), but the real payload nests it under `tool_input.file_path`. Confirmed by capturing a live hook payload for an `Edit` tool call.
3. **Hidden `\r` characters on Windows (`.sh` only).** Windows Python's `print()` emits `\r\n`. Piping a single value through `$(...)` strips the trailing `\n` but not `\r`; multi-line output extracted via `tail`/`read` preserves embedded `\r` entirely (unlike `sed -n Np`, which happens to normalize it away). This made exact-match scope comparisons fail even after fixing bug 1 — `"scripts/foo.ps1\r" != "scripts/foo.ps1"`. Fixed by piping every python3 extraction through `tr -d '\r'`.

Hard-block mode also switched from `exit 2` to `hookSpecificOutput.permissionDecision: "deny"`, for the same reason as `dangerous-commands.ps1` — `settings.json`'s `... || true` fail-open wiring silently erases exit-code-based signals.

**Hook error logging (G2):** unexpected errors are logged to `.pmb-hook-errors.log` via a `trap {}` wrapper.

### 4. Auto-Reviewed Update (`PostToolUse` — Write + Edit tools)

Fires after every `Write` or `Edit` tool call. Reads the edited file path from the tool input JSON (via `$input | Out-String`), checks whether it is inside `memory-bank/`, and updates the `last-reviewed:` frontmatter line to today's date if present.

**Why silent failure?** The hook must never block agent work. If the update fails (e.g. file not found, malformed frontmatter), the agent continues and the user can run `mb doctor` to find stale files. Implemented in `scripts/update-reviewed.ps1` and `scripts/update-reviewed.sh`.

**Hook error logging (G2):** unexpected errors are logged to `.pmb-hook-errors.log`.

### 5. PreCompact Memory Gate and Codex Recovery

Claude Code enforces the content policy before compaction. Codex instead injects recovery context
after compaction; Cursor cannot enforce the policy before compaction.

| Platform | Before compaction | After compaction |
|----------|-------------------|------------------|
| Claude Code | `.claude/settings.json` runs the checker; exit 2 blocks | Instructions require a Memory Bank reread |
| Codex | No gate — Codex `PreCompact` `continue: false` ends the active turn | Trusted `SessionStart` with `source: compact` injects the recovery checklist |
| Cursor | The 40% rule is proactive/advisory; native `preCompact` cannot block or modify compaction | The always-applied rule instructs a Memory Bank reread |

Codex project hooks must be reviewed and trusted in `/hooks`; a local feature setting or managed
policy can disable them. See the [Codex hooks documentation](https://learn.chatgpt.com/docs/hooks)
and [Cursor hooks documentation](https://prod.cursor.com/docs/hooks).

The shared checker runs two content-based quality checks on the memory bank **or** bypasses via a
`handoff.md` dated today. Claude Code runs it as its gate; in Codex it remains an explicit manual diagnostic.

**Claude Code exit codes:**
- **Exits 0** — both checks pass (or a `handoff.md` dated today is present). Compaction proceeds normally.
- **Exits 2** — one or more checks fail. **Compaction is blocked.** Claude Code treats a non-zero exit from a PreCompact hook as a block signal. The hook prints an actionable message explaining what to do.

**To unblock:** address the failing check (see below), then retry. Alternatively, create a `handoff.md` **dated today** to bypass the gate (the handoff file signals that session state has been captured via the Handoff Protocol).

**Why the date matters.** Until 2026-08-27 the bypass triggered on the file merely existing. A handoff is meant to be deleted once merged into `memory-bank/` (Handoff Protocol step 5), so one that outlives its session is spent — yet it kept handing out a free pass. A handoff dated 2026-08-26 was found still in a repo root on 2026-08-27, silently disabling this gate for every compaction in a long session. The bypass was inverted: the staler the handoff, the more likely the memory bank actually needed checking. A stale handoff now removes only the *bypass* — it is not itself a failure, so a genuinely fresh memory bank still passes.

**Detection logic (content-based, not mtime):**
- **Check 1 — `activeContext.md` substantive content:** counts non-frontmatter, non-heading, non-empty lines with ≥20 characters. Requires ≥3 such lines. A file that was only touched (e.g. `last-reviewed` timestamp updated) fails this check.
- **Check 2 — `progress.md` dated entry:** looks for at least one line starting with today's date (or a markdown heading/list prefix followed by today's date). The date must appear at the start of a line — embedded dates in prose do not count.
- **Bypass:** `handoff.md` dated today in the project root skips both checks.

**Fails open:** unexpected errors (missing runtimes, unreadable files) exit 0 silently and log to `.pmb-hook-errors.log`.

The shared policy is implemented in `scripts/pre-compact-check.ps1` (Windows/pwsh) and
`scripts/pre-compact-check.sh` (POSIX/sh). Claude Code wires it directly:

```json
"PreCompact": [
  {
    "hooks": [
      {
        "type": "command",
        "command": "pwsh -NonInteractive -File scripts/pre-compact-check.ps1 2>/dev/null || bash scripts/pre-compact-check.sh 2>/dev/null || true"
      }
    ]
  }
]
```

That no-matcher note applies to this Claude Code wiring. Codex deliberately has no `PreCompact`
handler: its documented `continue: false` behavior ends the active turn, which cannot safely enforce
a state that needs agent or user action. Codex uses `matcher: "^compact$"` for `SessionStart`;
its `scripts/codex-compaction-hook.{sh,ps1}` adapters emit only the post-compaction recovery
checklist.

### 6. Agent Spawn-Volume Advisory (`PreToolUse` — Agent tool)

Fires before every `Agent` tool call. Increments a CUMULATIVE SPAWN COUNT and emits a WARN once it exceeds the budget in `standards/PERFORMANCE-BUDGET.md` (default: ≤6 spawns, counted per checkout and reset only after 2 hours with no spawn). The WARN is a `systemMessage` only — shown to you, deliberately not to Claude, so an agent mid-review is not nudged to drop reviewers. Always exits 0 — advisory, never blocking. Implemented in `scripts/delegation-depth-check.ps1` and `scripts/delegation-depth-check.sh`.

**It does not measure nesting depth, despite the name.** There is no `PostToolUse:Agent` event, so a hook cannot tell a returned agent from a running one — six parallel agents and a six-deep chain are indistinguishable to it. The file name, state file and internal variable still say "depth" for compatibility; the semantics have only ever been a spawn count. This entry described it as nesting depth, with a ≤1 default, until 2026-09-03; the shipped scripts had used 6 since `5c0e8c9`.

**Runtime state file:** The hook stores its counter in `.pmb-delegation-depth` in the project root (gitignored). This file is created automatically on the first agent dispatch and resets after 2 hours of inactivity. Delete it manually to reset the spawn counter mid-session without restarting.

**Hook error logging:** Unexpected errors are logged to `.pmb-hook-errors.log`.

### 7. Review Gate (`PreToolUse` — Bash tool)

Fires before every Bash tool call and pattern-matches `git commit` / `git push` / `gh pr merge` (including compound commands like `cd X && git commit ...`). Denies the commit or push unless a matching, diff-bound review-ok marker exists in `.claude/`, mechanically enforcing WORKFLOW.md's "review before commit/push" phases instead of relying on Claude following the prose. `gh pr merge` is put to the user as a permission prompt in one exact form and denied in every other — see below. Implemented in `scripts/review-reminders.ps1` and `scripts/review-reminders.sh`.

**Marker files (single-use per diff, gitignored):**

- `.claude/.code-review-ok` — written by `/code-review`'s Opposition-review subagent (Step 5) when the Verdict is **Approve**. Contains a SHA-256 hash of `git diff HEAD` at review time, not an empty file.
- `.claude/.change-review-ok` — written by `/change-review`'s Job 9 (Opposition) subagent when no finding has `Blocking: Yes`. Contains a SHA-256 hash of `git diff origin/main...HEAD` (or `git diff HEAD` with no upstream).

**Why a hash, not an empty marker:** an empty marker is trivially fakeable with `touch` — anyone, or a rushed agent, can satisfy the gate without reviewing anything. Binding the marker to a hash of the exact diff means it only authorizes committing/pushing that specific diff; if the working tree changes after the review, the hash no longer matches and the gate re-engages. The hook recomputes the same hash fresh and compares it to the marker's stored value before allowing the commit/push through.

**A commit must be fully staged (added 2026-10-19):** the hash covers `git diff HEAD`, which is the working tree, but a commit records the index, so a commit holding only part of the reviewed change would still match. The commit gate therefore also refuses, before claiming the marker, while any tracked change is unstaged (`git diff --quiet --no-ext-diff --no-textconv` fails; the two flags stop a textconv filter or an exit-code-trusted external diff driver from hiding a difference). Stage in a command of its own before committing: the hook runs before a chained `git add X && git commit` stages anything, and before `git commit -a` does, so both are refused whenever tracked changes are unstaged. The check holds at hook time only. Not covered yet: commits that name paths (`git commit <path>`, `--only`), `--amend`, `--patch`, a chained command that edits or stages files before its `git commit`, `GIT_INDEX_FILE`/`GIT_DIR`/`GIT_WORK_TREE` set in the command's environment, and content a textconv filter or external diff driver hides from the reviewed diff itself (the marker still hashes plain `git diff HEAD`, so the two flags guard only the staging check).

**Atomic consumption:** the marker is claimed via an atomic rename (`Move-Item`/`mv`) rather than a separate existence-check followed by delete, closing the TOCTOU window between the two steps — if the source doesn't exist, the rename simply fails, collapsing "does it exist" and "claim it" into one filesystem operation. Only the path that allows the command consumes the marker: on a hash mismatch it is renamed back unconsumed, so a denial by this gate never burns an earned review (a later hook or a declined permission prompt can still burn it, because the allowing path has already consumed the marker; see the claim-then-restore comment in `review-reminders.sh`).

**Two significant fixes (2026-07-02), found via a real, unauthorized commit going through untouched:**

1. **`{"continue": false}` doesn't block execution.** The original design used the top-level `continue`/`stopReason` JSON fields to signal a deny. Empirically, this only interrupts the agent's *next turn* — the gated tool call had already run by the time the signal took effect. Fixed by switching to `hookSpecificOutput.permissionDecision: "deny"`, the field Claude Code actually reads to deny a tool call before it executes.
2. **Anchored regex missed real command shapes.** The original matcher required `git commit`/`git push` to follow the start of the command or a `;`/`&`/`|` operator. Since `$cmd` is already the exact, JSON-parsed command text (not raw payload noise), this anchoring bought little safety while missing multi-line Bash tool commands, a bare single `&`, and nested subshells. Simplified to an unanchored match — the only cost is an occasional unnecessary re-review if "git commit" appears as a substring elsewhere, the safe failure direction for a security gate.

The `.sh` version matches against the raw stdin payload rather than extracting the `command` field with `grep`/`sed`, because that extraction breaks on any JSON-escaped quote inside the command (e.g. `git commit -m "wip"`), silently truncating the match and letting anything after it — including a chained `&& git push` — through unchecked.

**`gh pr merge` — a permission prompt for one exact form, deny for everything else (changed 2026-10-20; was an unconditional deny from 2026-07-09):** unlike commit/push, this is not a diff-bound hash check. By the time a PR is mergeable its diff has passed the commit gate, the push gate and (with `required_status_checks.strict: true`) CI on the current head, so the gap at merge time is authorization: the user deciding, in that moment, to merge that PR. A hash can't encode that, and neither can any marker the agent writes. Claude Code's own Allow/Deny prompt can: the hook returns `permissionDecision: "ask"`, and only the user's click lets the merge run.

- **What is asked:** exactly `gh pr merge <N> -R <owner/repo> --squash --match-head-commit <40-hex SHA>` (or `--merge`), nothing before or after it, with the repo listed in `.claude/merge-gate.json`. The prompt's reason names the PR, repo, method and full SHA. `--match-head-commit` makes GitHub refuse the merge if the head moved after the prompt; `-R` stops `GH_REPO`, git remotes or `gh repo set-default` from redirecting it.
- **What is denied:** every other spelling (`--admin`, `--auto`, `--delete-branch`, `--rebase`, a `cd` prefix, a chained command…); a subagent's merge; any mode other than default/acceptEdits/auto; `GH_HOST`/`GH_REPO` in the hook's environment; an agent-written tool description other than the fixed one (the prompt shows it); and any checkout whose user, project or local settings configure a `PermissionRequest` hook or an allow rule wide enough to run a merge with no prompt (such a deny gives a generic message, so it doesn't point the agent at the silent route). A fallback verdict or a missing or crashing helper also denies. If the hook process itself fails in both shells, the wiring's `|| true` gives no decision; the ask rules below cover that case in this repo only.
- **Measured before shipping (2026-10-20, desktop app 2.1.299, auto mode):** every forced ask waited for the user's click, a subagent's ask reached the user too, and the prompt shows the command, the hook's reason and the agent's description. Headless (`-p`) refuses an ask in every mode, including `bypassPermissions`.
- **Belt and braces (PMB's own settings only):** `permissions.ask` rules for `gh pr merge` make a crashed hook still prompt, and `permissions.deny` rules block the desktop app's auto-merge tool and the GitHub plugin's merge tool, which no Bash hook sees. `mb upgrade` owns `permissions`, so adopters do not get these.
- **Not covered** (unchanged from before): escape spellings the classifier labels as not-a-merge (`docs/backlog/merge-gate-misses-gh-global-flags-graphql-and-powe.md`), and routes through rules that stay allowed, such as a git alias that shells out. Spec, threat model and every accepted residual: `docs/superpowers/specs/2026-10-20-merge-gate-user-approval-design.md`. Logic: `scripts/_review-gate-merge.py` / `.ps1`. Each ask is appended to `.claude/merge-asks.log` (gitignored; a convenience record, not tamper-evident).

### 8. Review Gate Failure Recovery (`PostToolUse` — Bash tool)

Companion to the Review Gate above. If a gated `git commit`/`git push` consumes a marker and then the command itself fails (a separate pre-commit hook rejects it, nothing is staged, a merge conflict), this hook reissues the marker so the rejected attempt doesn't force a pointless re-review — the diff hasn't changed, so the same review still applies. Implemented in `scripts/review-reminders-post.ps1` and `scripts/review-reminders-post.sh`.

**How it detects failure without depending on an unverified response schema:** the `PreToolUse` hook records the current git ref (`HEAD` for commit, `@{u}` for push) to a temp file immediately after consuming a marker. This `PostToolUse` hook compares that recorded ref to the ref's current value — if it didn't move, the command failed, full stop, regardless of what any tool-response field says. This was a deliberate choice over parsing `tool_response` for a success/failure field: the PreToolUse payload shape only became known through live empirical capture, and extending that same guesswork to PostToolUse's response schema risked repeating the same mistake. Ground-truth git state needs no schema assumption.

On detected failure, the hook recomputes the diff hash fresh (a failed commit/push can't have altered the working tree, so this reproduces the same value) and rewrites the marker.

### 9. Stale Review-Marker Warning (`PreToolUse` — Write + Edit tools)

Warns, before an edit happens, if a review-gate marker (`.claude/.code-review-ok` or `.claude/.change-review-ok`) currently exists and is about to be invalidated by that edit. Any tracked-file change alters `git diff HEAD`/`origin/main...HEAD`, which silently invalidates the marker's bound hash — without this hook, the only place that notices is the Review Gate above, at the moment of the *next* commit/push attempt, which can be many edits later.

Warn-only, no `permissionDecision` — the actual enforcement already exists and is airtight (the Review Gate recomputes the hash fresh at commit/push time and denies on any mismatch; a stale marker is already rejected the same as a missing one). This hook adds zero new safety; it only surfaces, before the edit, what would otherwise only be discovered after a failed commit attempt. The notice is `additionalContext` only — advice for Claude, not a message for you, since it fires on every edit while a marker exists.

Does not inspect the edited file or delete the marker — presence alone is the entire condition, and marker deletion stays the sole responsibility of the Review Gate's `consume_marker()` (an atomic `mv`, avoiding a second writer to the same security-relevant file). Implemented in `scripts/warn-stale-review-marker.ps1` and `scripts/warn-stale-review-marker.sh`.

## Git Hooks (versioned)

PMB distributes two git hooks through the `.githooks/` directory, which is versioned in the project repo. `mb init` and `mb upgrade` both install these hooks and activate them via `core.hooksPath`.

### How it works

`core.hooksPath = .githooks` is a per-project git local config (stored in `.git/config`, not committed). When set, git resolves all hooks from `.githooks/` instead of `.git/hooks/`. The hook *files* are committed and versioned; the *activation* is a local git config that each `mb init`/`mb upgrade` run sets automatically.

`mb upgrade` treats `.githooks/pre-push` and `.githooks/pre-commit` as `TEMPLATE_OWNED` — it overwrites them unconditionally if they differ from the template, so hook logic stays current across PMB version bumps.

### The two hooks

**`.githooks/pre-push`** — delegates to the 7-check push gate:
- Unresolved merge conflicts or conflict markers *(blocking)*
- Possible secrets in the push diff — AWS keys, API tokens, GitHub PATs *(blocking)*
- Uncommitted working tree changes *(warn)*
- Missing `.gitattributes` *(warn)*
- Files over 500 KB *(warn)*
- Memory-bank integrity via `mb doctor --check` *(warn, or UNKNOWN if `mb` is unavailable or predates `--check`)*
- Scans first pushes via `git log HEAD --not --remotes` when no upstream tracking ref exists

Dispatches to `scripts/pre-push-check.ps1` (Windows/pwsh) or `scripts/pre-push-check.sh` (POSIX/bash). Fails open — if the script errors unexpectedly, the push is allowed through.

#### Three result states

Only 3 of the 7 checks can block. The gate therefore reports **three** states, not two, so an
advisory finding is never rendered as a pass:

| Summary | Meaning | Exit |
|---|---|---|
| `[PASS] All pre-push checks passed` | every check ran and passed | 0 |
| `[PASS with N warning(s)]` | no blocking failure, but advisory findings exist | 0 |
| `[DEGRADED — N check(s) could not run]` | at least one check could not be evaluated | 0 |
| `[BLOCKED]` | a blocking check failed | 1 |

Set `ENFORCE=true` to promote warnings and unknowns to blocking. Advisory is the default,
matching `templates/.github/workflows/memory-bank-size.yml` — a gate that blocks on a stale
template tends to get disabled outright.

**Why UNKNOWN exists.** A check has three outcomes — passed, failed, or *could not run* — and an
exit code cannot distinguish the first from the last. `mb validate` was deprecated into a shim that
prints a redirect notice and exits **2** (measured 2026-08-23, not assumed), so the old Check 7
emitted a permanent false `[WARN]` on every push in every managed project while validating nothing.
An earlier version of this paragraph said the shim exited 0 and therefore printed a false `[OK]`;
that was wrong in the same way the code was, and `scripts/pre-push-check.sh` was corrected in the
same change without this file being updated alongside it. Check 7 now runs `mb doctor` and derives its
verdict from that command's structured output: counting `[OK]`/`[WARN]`/`[ERROR]` lines yields both
the result *and* positive evidence the command actually ran. Zero result lines means UNKNOWN, never
success. (`mb doctor`'s exit code would not have fixed this either: it is 1 only for a fatal
finding, and its advisory `[ERROR]` lines — checksum mismatch, startup-context ceiling — leave it
at 0.)

**Why `--check`.** Plain `mb doctor` rewrites `.pmb-checksums` at the end of every run, so a hook
that ran it re-baselined on every push: a memory-bank edit was reported once, by the run that then
erased it. Check 7 runs `mb doctor --check`, which compares without writing, and requires the
`Integrity check mode:` line it prints — an `mb.sh` older than the hook ignores the flag and
rewrites silently, so a run without that line is UNKNOWN. A checksum mismatch gets its own
`[WARN] memory-bank changed since the last accepted integrity baseline` line and keeps appearing on
every push until the edits are reviewed and accepted with `mb verify-integrity`. It counts as a
warning, so `ENFORCE=true` blocks until then. A missing baseline (fresh clone or worktree —
`.pmb-checksums` is gitignored) is reported as `[INFO]` and does not count.

Relatedly, deprecated redirect shims now exit **2** ("command moved") rather than 0, so a script
reading only an exit code can tell that nothing ran. `mb update` is deliberately excluded — it is a
live alias for the upgrade path, not a redirect.

**`.githooks/pre-commit`** — four-check gate before every `git commit`:
- **Blocks** if `handoff.md` is staged (`handoff.md` is ephemeral and must not be committed)
- **Blocks** `memory-bank/` changes committed from a linked git worktree. `memory-bank/` is edited and committed only in the main worktree; `mb commit` refuses in a linked worktree, and this is the check a plain `git commit` reaches. It covers `git commit`, `commit -a`, `commit -- <path>`, renames out of `memory-bank/`, and any casing of the directory name. When finishing a conflicted merge, files whose staged content matches the merged branch (`MERGE_HEAD`) pass, since they were not edited here; anything else in `memory-bank/` is refused, with `git checkout MERGE_HEAD -- <path>` as the way to take the merged version. A git submodule is its own main worktree and is not affected. Any error inside the check refuses rather than passes. It applies whether or not a project's `CLAUDE.md` states the rule.
- **Warns** if `CLAUDE_AUTOCOMPACT_PCT_OVERRIDE` is missing from `.claude/settings.json` (token budget auto-compaction may not be configured)
- **Runs the repo's format check, if it has one** (`[NS-58]`), last, so it never affects the checks above. See *The format check* below.

**Known gaps in the worktree check.** It is a tripwire on the `git commit` path, not a complete boundary: git does not record which worktree an edit was made in, so no hook can be one.
- **Which commands run `pre-commit`** (measured on git 2.55, each hook logging to a file): `git commit`, including one that concludes a conflicted merge; `git merge --continue`; and `git cherry-pick --continue` / `git revert --continue` after a conflict. These create commits without it: a clean `git merge` (runs `pre-merge-commit` instead, so a clean `git pull` too), a clean `git cherry-pick` or `git revert`, `git rebase --continue`, `git am` (runs `pre-applypatch` instead), and plumbing such as `git commit-tree` with `git update-ref`.
- **A clean `git revert` or a `git am` can author `memory-bank/` changes unchecked.** Reverting a main commit that touched `memory-bank/` writes new `memory-bank/` content in the worktree and rolls main back when the branch merges; `git am` applies whatever the patch contains. A conflicted cherry-pick or revert that touches `memory-bank/` does run the hook when finished, and by the hook's logic is refused, since there is no `MERGE_HEAD` to compare against (not covered by a test).
- A clean merge is not a way to author `memory-bank/` changes: it can only bring in the merged branch's content, because `git merge` refuses to start with changes staged unless it can fast-forward (measured; a fast-forward leaves a staged change staged, so it still meets this check at the next `git commit`). The one difference from the conflicted path: files git combines from both sides are refused there but committed by a clean merge, which can only happen when this branch already carries committed `memory-bank/` changes.
- `git commit --no-verify`, its short form `-n`, and `git -c core.hooksPath=<elsewhere> commit` skip the hook. The dangerous-command hook asks for confirmation only on the literal `--no-verify`.
- With the default relative `core.hooksPath = .githooks`, each linked worktree runs the hook from its own branch, so a worktree on a branch older than this check is unprotected until that branch picks it up. An absolute `core.hooksPath` makes every worktree run the main checkout's copy instead.
- A merge trusts `MERGE_HEAD`: content inherited from any merged branch passes, including branches whose `memory-bank/` commits skipped this check. Taking the merged branch's version with `git checkout MERGE_HEAD -- <path>` also discards your own branch's side of that file, which matters when your branch carries `memory-bank/` commits of its own. Octopus merges are untested; by the hook's logic they are compared against the first merged head only, which refuses rather than passes.
- In a bare repository with worktrees, every worktree is a linked one, so `memory-bank/` cannot be committed anywhere without skipping the hook. `mb commit` and `CLAUDE.md`'s `--git-common-dir/../memory-bank/` path already assumed a main worktree; this check turns that assumption into a hard block.
- It checks commits, not edits. Editing `memory-bank/` in a linked worktree is still against the rule, but is only caught when committed.
- For maintainers: `[NS-26]`'s plan to turn this hook into a thin wrapper around `scripts/pre-commit-check.{sh,ps1}` must carry this check forward, not only the review-marker check that plan was written for.

**The format check.** A repo opts in by adding `.githooks/format-check`. It is repo-owned: `mb upgrade` replaces only `pre-commit` and `pre-push` in `.githooks/`. With no such file the step does nothing and prints nothing.
- **What the hook does.** It lists the staged regular files and pipes them to `bash .githooks/format-check` on stdin, NUL-terminated, from the top of the working tree. The script needs no executable bit. Exit 0 lets the commit through; any other exit refuses it, naming the script and exit code. The script is not run when nothing is left to check (a deletion-only commit, for instance).
- **Which files.** Added, modified and type-changed files whose staged mode is a regular file (`100644`/`100755`). Renamed and copied files are checked under their new path whatever `diff.renames` is set to. Deleted files, submodules and symlinks are not passed. `commit -a` and `commit -- <path>` get exactly what they commit. Finishing a conflicted merge checks every file the merge brings in, since CI will see them too. `--amend` checks only what is newly staged.
- **Why stdin, not arguments.** No command-line length limit; Git for Windows does not rewrite path-like arguments (it turns `x=/y.json` into `x=C:/Program Files/Git/y.json` when passing it to a native program); and no path can be read as an option.
- **The script inherits git's hook environment**, including `GIT_INDEX_FILE` while `commit -a` or `commit -- <path>` runs. Git calls in the script therefore see the index being committed, and a git call aimed at a different repository needs that variable cleared.
- **A prettier example** for Node repos is in PMB's `templates/examples/format-check/`: copy both `format-check` and `format-check.mjs` into `.githooks/`. It checks each file's *staged* content with the repo's own prettier, through prettier's API in one process. Checking the file on disk instead blocks CRLF checkouts on Windows (`core.autocrlf=true`, Git for Windows' default) that CI passes, and passes a file fixed on disk but not re-staged that CI fails. It reports "not formatted" and "could not parse" separately. If prettier or node is not installed it warns and lets the commit through, since CI still runs; it never falls back to `npx`, which can pick up a global prettier of another version and whose Windows shims mangle file names. It targets npm and pnpm layouts: under Yarn Plug'n'Play it reads prettier as not installed. It is tested in `tests/test-pre-commit-hook.sh` against a stand-in prettier module, not against real prettier.
- **Not covered.** A format failure refuses the commit after any `/code-review` has run, and the fix changes the diff, so the review gate asks for a new review. Skipping the hook skips this step with the rest of it.

### Migration from `.git/hooks/`

Projects initialized before PMB 1.1.0 have the old PMB shim at `.git/hooks/pre-push`. Running `mb upgrade` on those projects:
1. Installs `.githooks/pre-push` and `.githooks/pre-commit` (TEMPLATE_OWNED)
2. Sets `core.hooksPath = .githooks` (git local config)
3. Removes `.git/hooks/pre-push` if it matches the PMB shim (detected by grepping for `pre-push-check`)

Custom hooks at `.git/hooks/` are unaffected — the migration only removes the PMB-managed shim.

### Verifying hook activation

```bash
git config core.hooksPath       # should print: .githooks
ls .githooks/                   # should show: pre-push  pre-commit
mb doctor                       # check 4 reports [OK] for both
```

## Adding Per-Project Hooks

Copy `.claude/settings.json` into your project, then add hooks as needed.

### Auto-Format After Edit (PostToolUse)

Add to the `PostToolUse` array in `settings.json`:

**Prettier (JavaScript/TypeScript):**
```json
{
  "matcher": "Write|Edit",
  "hooks": [{
    "type": "command",
    "command": "npx prettier --write \"$CLAUDE_TOOL_OUTPUT_PATH\" 2>/dev/null || true"
  }]
}
```

**Black (Python):**
```json
{
  "matcher": "Write|Edit",
  "hooks": [{
    "type": "command",
    "command": "python -m black \"$CLAUDE_TOOL_OUTPUT_PATH\" 2>/dev/null || true"
  }]
}
```

### Lint Before Commit (PreToolUse on Bash)

Add to the `PreToolUse` array (alongside the dangerous-command hook):
```json
{
  "matcher": "Bash",
  "hooks": [{
    "type": "command",
    "command": "HOOK_INPUT=$(cat 2>/dev/null); echo \"$HOOK_INPUT\" | grep -q 'git commit' && npm run lint 2>&1 || true"
  }]
}
```

## How to Add a Hook

1. Edit `.claude/settings.json` in your project root
2. Add the hook JSON to the appropriate lifecycle key
3. Test: run a command Claude would use and verify the hook fires correctly
4. Commit `settings.json` so the hook applies to all sessions in this project

## Reference

Full hook documentation: `claude hooks --help` or see the Claude Code docs.
