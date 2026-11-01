# Hooks Guide

<!-- SYNC NOTE: this is a manually-trimmed copy of the source-of-truth docs/HOOKS-GUIDE.md
     (PMB's own postmortem/bug-history prose and maintainer notes about PMB's internal plans
     removed, everything else kept). If you edit
     shared content there, mirror the change here by hand — no generation step enforces this. -->

PMB uses native lifecycle hooks where the platform exposes an enforceable event. Claude Code can
block compaction; Codex provides deterministic post-compaction recovery; Cursor's `preCompact` event
is observational, so its handoff rule remains advisory. Unlike instruction files, configured hooks execute outside the
model's discretion, subject to platform enablement and trust settings.

## Hook Types

| Hook | When it fires | Primary use |
|------|--------------|-------------|
| `PreToolUse` | Before Claude runs a tool | Block dangerous operations, validate inputs |
| `PostToolUse` | After Claude runs a tool | Auto-format, run lint, log actions |
| `Stop` | When Claude pauses for input | Desktop notification; Pre-Approval Protocol check (PMB-only) |
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

**Why "was this authorized?" stays advisory, not a hook:** A `PreToolUse` hook sees only the tool call about to run, never the chat turn that did or didn't authorize it — so it can't tell a genuine "yes" from an ambiguous non-answer being misread as one. The tempting fix, a marker file the agent writes after concluding "the user approved this," is exactly as fakeable as a self-written code-review marker, which is why `/code-review` and `/change-review` bind their markers to a SHA-256 of the actual reviewed diff instead of an unverifiable claim. There's no equivalent artifact to hash for "the user meant this right now," so this stays a `standards/SECURITY-GUARDRAILS.md` rule (see "What Counts as Approval") — caught by discipline, not a gate that always fires.

**Why "have the user run it themselves" also stays advisory:** asking the user to run a blocked command directly is a legitimate resolution for CONFIRM/BLOCK-tier commands designed to require a human's own hands (force-push, `filter-branch`, `--no-verify`) — but not for a block whose purpose is verifying some other step (review) already happened, since the user running it themselves doesn't make that true. No tool call exists to hook for the difference — asking the user something is plain text, invisible to `PreToolUse`. Stays a `standards/SECURITY-GUARDRAILS.md` rule (see "The User Is Never the Compliance Bypass") for the same structural reason as above.

## Default Hooks in This Standard

Configured in `.claude/settings.json`:

**How a `PreToolUse` hook is heard.** Plain text a `PreToolUse` hook prints never reaches Claude (measured), and Claude Code's docs say it is not shown in the visible transcript — it is only recorded (debug log, session file). So each hook prints at most ONE JSON object: `permissionDecision: "deny"` to block, top-level `systemMessage` for you, `hookSpecificOutput.additionalContext` for Claude. Any text beside that object makes Claude Code ignore it. The Contract Scope Check (§3) still prints plain text, so its warning is currently not seen.

### 1. Dangerous-Command Blocker (`PreToolUse` — Bash + PowerShell tools)

Intercepts both Bash and PowerShell tool calls before they run using `scripts/dangerous-commands.ps1`. Enforces 3-tier safety:

**BLOCK** (17 patterns — command exits non-zero, Claude stops):\
*Shell:* `rm -rf`, and `rm` with recursive and force flags in common reordered spellings · `mkfs` · `dd if=` · `git push --force` · `git push -f`, and common spellings of a force push elsewhere in the command (`--force`, `--mirror`, `-f`, `+refspec`) · `DROP TABLE` · `DROP DATABASE` · `| bash` · `| sh` · `|bash` · `|sh` · a git alias whose value starts with `!` · awk `system()` or `cmd | getline`\
*PowerShell-native:* `Remove-Item -Recurse -Force` · `Remove-Item -Force -Recurse` · `Format-Volume` · `| Invoke-Expression` · `|Invoke-Expression` · `| iex` · `|iex`

The reordered and abbreviated forms are matched in common spellings only, not exhaustively: a deliberately respelled command can get through. `standards/SECURITY-GUARDRAILS.md` describes what is matched, the accepted false positives and what is not covered by design.

**CONFIRM** (10 patterns — surfaces confirmation dialog):
`git filter-branch` · `git update-ref` · `sudo rm` · `chmod -R 777` · `--no-verify` · `git merge <branch>` (boundary-matched: excludes `git merge-base`) · commit-signing bypass (regex, four patterns: `commit.gpgsign` set to any falsey value — key or value quoted or bare — via `git -c`, the same via a `git config` subcommand, `--unset`/`--unset-all commit.gpgsign`, and `--no-gpg-sign`)

The signing key patterns anchor to the flag or subcommand that actually sets config, so
`git commit -m "...commit.gpgsign false..."`, `git log -S "..."` and trailing `#` comments do not
fire. Before any tier matches, backslash-newline continuations are deleted and runs of blanks
collapsed, so a wrapped command is matched as the shell will actually run it — this applies to
every tier, since the same evasion defeated literal BLOCK substrings. See
`standards/SECURITY-GUARDRAILS.md` for the accepted false positives and for what the gate
deliberately does not cover (`GIT_CONFIG_*` env vars, direct `.git/config` writes,
`tag.gpgsign`/`push.gpgSign`).

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
This is why `chmod -R 777` is spelled `chmod -r 777` in the script's pattern list, while the tier
lists above show the command as an operator would actually type it. The real `chmod -R 777` is
still caught, because the *subject* is folded before comparison.

`confirm_regex` and `block_regex` are the exception — their patterns go to `grep -qziE`, which folds via `-i`, so case
there is unconstrained.

**Regex rows and locale.** Case-insensitive regex matching follows the locale unless it is pinned.
The `.ps1` regexes set `RegexOptions.CultureInvariant`. Under tr-TR, `IgnoreCase` alone does not
fold `I` to `i`: measured on a copy without it, the signing rows and the `iex` regexes returned no
verdict. On the sh side, `block_regex` runs under `LC_ALL=C` only. `confirm_regex` runs twice, under
the caller's locale and then under `LC_ALL=C`, because each alone misses a bypass. Under a UTF-8
locale the caller's pass counts the signing rows' `{0,255}` gaps in characters, and the
`LC_ALL=C` pass always counts them in bytes. What that guarantees, and when, is stated once in
`standards/SECURITY-GUARDRAILS.md`. So a new sh regex row inherits its matcher's
locale rule, which can change what it matches.

**Platform requirement (sh hook):** stated once, with what each missing piece costs, in
`standards/SECURITY-GUARDRAILS.md` under "Platform requirement (sh hook)". Keep regex repetition bounds at 255 or below, the POSIX `RE_DUP_MAX` guarantee, so
a grep that supports `-z` but caps bounds there can still compile every row. The test suite fails on
any row above 255.

**Why `$1` is not simply folded per call:** that costs a `printf | tr` subshell per matcher *call*,
roughly 25 per invocation, on a hook that runs on every single Bash tool call — measured at
1.07s → 2.33s per invocation. Folding the subjects once costs two subshells total, three when the
command holds a carriage return.

The shipped test suites assert this structurally, so the fail-open trap is a red test rather than a
silent hole: no matcher may match against an unfolded view, and no pattern argument may contain an
upper-case letter — checked in both `scripts/` and `templates/scripts/`, plus a byte-identity
assertion between the two mirrors.

Implemented in `scripts/dangerous-commands.ps1` (Windows/pwsh) and `scripts/dangerous-commands.sh` (POSIX/bash). Configured in `.claude/settings.json` with two matchers, `Bash` and `PowerShell`, wired identically:

```json
{ "matcher": "Bash",       "command": "[ -f scripts/dangerous-commands.ps1 ] && pwsh -NoProfile -NonInteractive -File scripts/dangerous-commands.ps1 2>/dev/null || bash scripts/dangerous-commands.sh 2>/dev/null || true" },
{ "matcher": "PowerShell", "command": "[ -f scripts/dangerous-commands.ps1 ] && pwsh -NoProfile -NonInteractive -File scripts/dangerous-commands.ps1 2>/dev/null || bash scripts/dangerous-commands.sh 2>/dev/null || true" }
```

**Timeout (checked against the Claude Code hooks reference on 2026-10-15):** neither entry sets
`timeout`, so each gets the default for a command hook, 600 seconds. A PreToolUse hook that times
out does not block the tool call: its output is discarded and the call continues through the
normal permission flow, unless the entry sets `"onFailure": "block"` (Claude Code v2.1.295 or
later). The PowerShell hook's slowest measured case, a ~50 KB command, took about 33 seconds (the
figures are in `standards/SECURITY-GUARDRAILS.md`), far inside the default; the sh hook's, about 100 seconds
on one non-periodic shape, is inside it too.

**Why the guard and `-NoProfile`.** Claude Code's hooks docs treat stdout that does not start with
`{` as plain text and ignore the JSON, so anything printed beside a deny silently allows the call.
Two wiring defects did that: without `-NoProfile`, whatever a PowerShell profile prints lands on
stdout ahead of the deny; and with `pwsh` installed but the `.ps1` missing, `pwsh` prints its usage
text (exit 64) before `||` runs bash. `[ -f X.ps1 ]` sends a missing `.ps1` straight to bash, and
`-NoProfile` must precede `-File` (after it, it is a script argument and the profile still loads).
The `||` chain is kept over an `if command -v pwsh` pick because a `.ps1` that fails to parse exits
without reading stdin, so bash still receives the full payload. Every hook in `settings.json` except
`PreCompact` and `Stop` uses this form. The form needs a POSIX shell, which is Claude Code's default
for hooks (Git Bash on Windows; per the hooks reference, checked 2026-10-15). Under a hook `"shell": "powershell"`, or on Windows without Git
Bash, where Claude Code falls back to PowerShell, `[ -f … ]` does not parse and the hook runs nothing.

**The `PowerShell` matcher's bash fallback is partial.** When it falls back (`.ps1` missing, `pwsh`
absent, or `pwsh` failing before it reads stdin), `dangerous-commands.sh` applies only its own rows:
the PowerShell-native BLOCK rows (`Remove-Item -Recurse`, `Format-Volume`, pipe-to-`iex`) are not
checked, and a few `.sh` patterns match more broadly (e.g. `| sh2`), so they can deny a command
the `.ps1` would allow. Before the fallback
existed, that path checked nothing.

**Hook error logging (G2):** if `dangerous-commands.ps1` fails unexpectedly, the catch block appends a timestamped entry to `.pmb-hook-errors.log` (gitignored). `mb doctor` Check 16 surfaces entries from this log as WARN.

### 2. Stop Notification and Pre-Approval Check (`Stop`)

PMB's own `.claude/settings.json` runs a single Stop hook, `scripts/pre-approval-check.ps1`, with
two jobs:
- it enforces PMB's Pre-Approval Protocol: a turn ending in an approve-or-choose ask must carry a
  Findings section and a Recommendation, and a turn ending in any other question a Recommendation;
- it shows a detached "Claude has paused" notification that, on Windows, is set to close itself
  after 600 s; popups have been seen still open well past that, cause unknown.

**A pass means the sections exist, not that the checks behind them were good.** Ask detection is a
heuristic trigger, and adequacy stays with the Reviewer/Opponent layer.

The pre-approval check is not installed by `mb init`; it is on trial in PMB only. What `mb init`
does install as the Stop entry is the older modal "Claude has paused" popup, which can hang headless
or remote sessions with no one to dismiss it. Whether adopters keep it is an open decision.

### 3. Contract Scope Check (`PreToolUse` — Write + Edit tools)

Checks whether a file being written is within the scope declared in the active task contract (`.claude/contracts/active-task.json`). Implemented in `scripts/check-contract.ps1` and `scripts/check-contract.sh`. See `docs/CONTRACTS-GUIDE.md` for the full contract schema.

- **No contract / inactive contract:** exits 0 silently.
- **Out-of-scope write (default):** prints a warning and exits 0. The warning is plain text, so it currently reaches neither you nor Claude (see "How a `PreToolUse` hook is heard" above; a known gap in this release).
- **Out-of-scope write (hard-block mode):** the tool call is denied when `PMB_CONTRACT_HARD_BLOCK=1` is set in the `env` block of `.claude/settings.json`.

Set `PMB_CONTRACT_HARD_BLOCK=1` for sessions where scope discipline is critical. See `standards/SECURITY-GUARDRAILS.md` for the full env-block example.

**Hook error logging (G2):** unexpected errors are logged to `.pmb-hook-errors.log` via a `trap {}` wrapper.

### 4. Auto-Reviewed Update (`PostToolUse` — Write + Edit tools)

Fires after every `Write` or `Edit` tool call. Reads the edited file path from the tool input JSON, checks whether it is inside `memory-bank/`, and updates the `last-reviewed:` frontmatter line to today's date if present.

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
        "command": "if command -v pwsh >/dev/null 2>&1; then pwsh -NonInteractive -File scripts/pre-compact-check.ps1 2>/dev/null; else bash scripts/pre-compact-check.sh 2>/dev/null; fi"
      }
    ]
  }
]
```

Not an `||` chain like the other hooks: this gate blocks by exiting 2, and `|| bash … || true` would
run the bash twin after a deliberate block and then turn the exit status into 0, so the gate would
never block.

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

Fires before every Bash tool call and pattern-matches `git commit` / `git push` / `gh pr merge` (including compound commands like `cd X && git commit ...`). Denies the commit or push unless a matching, diff-bound review-ok marker exists in `.claude/` (a tag-only push of an already-merged commit is checked by where its tags point instead; see below), mechanically enforcing WORKFLOW.md's "review before commit/push" phases instead of relying on Claude following the prose. `gh pr merge` is put to the user as a permission prompt in one exact form and denied in every other — see below. Implemented in `scripts/review-reminders.ps1` and `scripts/review-reminders.sh`.

**Marker files (single-use per diff, gitignored):**

- `.claude/.code-review-ok` — written by `/code-review`'s Opposition-review subagent (Step 5) when the Verdict is **Approve**. Contains a SHA-256 hash of `git diff HEAD` at review time, not an empty file.
- `.claude/.change-review-ok` — written by `/change-review`'s Job 9 (Opposition) subagent when no finding has `Blocking: Yes`. Contains a SHA-256 hash of `git diff origin/main...HEAD` (or `git diff HEAD` with no upstream).

**Why a hash, not an empty marker:** an empty marker is trivially fakeable with `touch` — anyone, or a rushed agent, can satisfy the gate without reviewing anything. Binding the marker to a hash of the exact diff means it only authorizes committing/pushing that specific diff; if the working tree changes after the review, the hash no longer matches and the gate re-engages. The hook recomputes the same hash fresh and compares it to the marker's stored value before allowing the commit/push through.

**A commit must be fully staged (added 2026-10-19):** the hash covers `git diff HEAD`, which is the working tree, but a commit records the index, so a commit holding only part of the reviewed change would still match. The commit gate therefore also refuses, before claiming the marker, while any tracked change is unstaged (`git diff --quiet --no-ext-diff --no-textconv` fails; the two flags stop a textconv filter or an exit-code-trusted external diff driver from hiding a difference). Stage in a command of its own before committing: the hook runs before a chained `git add X && git commit` stages anything, and before `git commit -a` does, so both are refused whenever tracked changes are unstaged. The check holds at hook time only. Not covered yet: commits that name paths (`git commit <path>`, `--only`), `--amend`, `--patch`, a chained command that edits or stages files before its `git commit`, `GIT_INDEX_FILE`/`GIT_DIR`/`GIT_WORK_TREE` set in the command's environment, and content a textconv filter or external diff driver hides from the reviewed diff itself (the marker still hashes plain `git diff HEAD`, so the two flags guard only the staging check).

**Atomic consumption:** the marker is claimed via an atomic rename (`Move-Item`/`mv`) rather than a separate existence-check followed by delete, closing the TOCTOU window between the two steps. Only the path that allows the command consumes the marker: on a hash mismatch it is renamed back unconsumed, so a denial by this gate never burns an earned review (a later hook or a declined permission prompt can still burn it, because the allowing path has already consumed the marker; see the claim-then-restore comment in `review-reminders.sh`).

**A tag-only push of a merged commit needs no marker:** the push marker binds `git diff origin/main...HEAD`, which says nothing about what a tag push publishes. Before this, pushing a release tag needed a fresh `/change-review` of whatever branch was checked out, and from main it could not pass at all (that diff is empty). The gate now lets a push through with no marker, and without touching one, when all of these hold:

- **The whole command is `cd "<absolute path>" && git push <remote>` followed only by `refs/tags/<tag>` or `tag <tag>` words.** Words are separated by spaces or tabs.
  - It takes exactly one quoted cd, to an absolute path: `C:/…`, or `/…` outside Windows.
  - The cd is meant to tie the repository the gate checks to the one the shell pushes from. A relative path, a second cd, or a leading `-`, `+` or `~` would be read differently by the shell. On Windows the PowerShell twin also refuses `/…`.
  - The path must be printable ASCII without its own quote, `$`, a backtick, `\`, `[`, `]`, `*` or `?`. Use `C:/…` paths. Otherwise the shell's `cd` (expansion, escapes, pwsh wildcards, or pwsh's typographic quotes such as ’) could disagree with the gate's literal reading of the path.
  - Remote and tag names are letters, digits, `.`, `_` and `-` (tags also `/`), starting with a letter, digit or `_`.
- **Every tag exists as `refs/tags/<tag>`, is not a symbolic ref, and is on a commit in `refs/remotes/origin/main`.** Replace grafts are ignored. Run `git fetch origin` first if the merge is recent.
- **No `remote.<name>.push` is configured.** Through one, git can map a tag refspec onto a branch.

A tag-shaped push that fails the check is denied with a reason naming the tag. Everything else still needs the marker:

- a bare name such as `git push origin v1.3.0` (the denial names the accepted spelling)
- `--tags`, `--follow-tags`, `--mirror`, `--all`
- force or delete forms
- `src:dst` or wildcard refspecs
- mixed tag and branch refspecs
- `git -c`/`-C` or an environment assignment
- no cd, a relative cd or a second cd, and anything else chained

The check trusts the local `refs/remotes/origin/main`: anything that moves that ref lets a tag on any commit through with no marker. It is about review, not about authorizing the publish. Logic: `TAG_PUSH` in `scripts/_review-gate-classify.py` (`--tag-push`), with the same pattern in `_review-gate-classify.ps1`.

**`gh pr merge` — a permission prompt for one exact form, deny for everything else:** unlike commit/push, this isn't a hash check. By merge time the diff already passed the commit gate, push gate, and CI; the remaining gap is authorization — the user deciding, now, to merge this PR — which no agent-written marker can encode, but Claude Code's own Allow/Deny prompt can. The hook returns `"ask"` only for exactly `gh pr merge <N> -R <owner/repo> --squash --match-head-commit <40-hex SHA>` (or `--merge`), with the repo listed in `.claude/merge-gate.json`, from the main agent, in default/acceptEdits/auto mode, when no settings file configures a `PermissionRequest` hook or an allow rule wide enough to run a merge silently. Everything else — other flags, chained commands, subagents, other modes, a missing or crashing helper — is denied. **One gap:** if the hook process itself fails (in both shells, for either matcher: the PowerShell matcher falls back to bash too), the wiring's `|| true` gives no decision, and the call goes to Claude Code's normal permission flow. `permissions.ask` rules for `Bash(gh pr merge:*)` and `PowerShell(gh pr merge:*)` are meant to make that case prompt too, for those spellings only (the REST route `gh api …/pulls/N/merge` matches neither); whether they prompt in auto mode is not yet measured. Put them in `.claude/settings.json` (`mb upgrade` keeps a project's permission rules; see below), `.claude/settings.local.json`, or your user settings. **Create `.claude/merge-gate.json` (`{"repos": ["owner/repo"]}`) to enable it; without it every merge is denied, as before.** Logic: `scripts/_review-gate-merge.py` / `.ps1`.

### 8. Review Gate Failure Recovery (`PostToolUse` — Bash tool)

Companion to the Review Gate above. If a gated `git commit`/`git push` consumes a marker and then the command itself fails (a separate pre-commit hook rejects it, nothing is staged, a merge conflict), this hook reissues the marker so the rejected attempt doesn't force a pointless re-review — the diff hasn't changed, so the same review still applies. Implemented in `scripts/review-reminders-post.ps1` and `scripts/review-reminders-post.sh`.

**How it detects failure:** the `PreToolUse` hook records the current git ref (`HEAD` for commit, `@{u}` for push) to a temp file immediately after consuming a marker. This `PostToolUse` hook compares that recorded ref to the ref's current value — if it didn't move, the command failed, regardless of what any tool-response field says.

On detected failure, the hook recomputes the diff hash fresh (a failed commit/push can't have altered the working tree, so this reproduces the same value) and rewrites the marker.

### 9. Stale Review-Marker Warning (`PreToolUse` — Write + Edit tools)

Warns, before an edit happens, if a review-gate marker (`.claude/.code-review-ok` or `.claude/.change-review-ok`) currently exists and is about to be invalidated by that edit. Any tracked-file change alters the reviewed diff, which silently invalidates the marker's bound hash — without this hook, the only place that notices is the Review Gate above, at the moment of the next commit/push attempt.

Warn-only, no `permissionDecision` — the Review Gate already recomputes the hash fresh at commit/push time and denies on any mismatch, so this hook adds zero new safety; it only surfaces the fact earlier. The notice is `additionalContext` only — advice for Claude, not a message for you, since it fires on every edit while a marker exists. Does not inspect the edited file or delete the marker — marker deletion stays the sole responsibility of the Review Gate's `consume_marker()`. Implemented in `scripts/warn-stale-review-marker.ps1` and `scripts/warn-stale-review-marker.sh`.

## Git Hooks (versioned)

PMB distributes two git hooks through the `.githooks/` directory, which is versioned in the project repo. `mb init` and `mb upgrade` both install these hooks and activate them via `core.hooksPath`.

### How it works

`core.hooksPath = .githooks` is a per-project git local config (stored in `.git/config`, not committed). When set, git resolves all hooks from `.githooks/` instead of `.git/hooks/`. The hook *files* are committed and versioned; the *activation* is a local git config that each `mb init`/`mb upgrade` run sets automatically.

`mb upgrade` treats `.githooks/pre-push` and `.githooks/pre-commit` as `TEMPLATE_OWNED` — it overwrites them unconditionally if they differ from the template, so hook logic stays current across PMB version bumps.

`.claude/settings.json` is `TEMPLATE_OWNED` for its hook wiring, `env` and `model`, but `mb upgrade` merges its `permissions` instead of overwriting them: every `allow`, `deny`, `ask` and `additionalDirectories` entry the project added is kept, as is `disableBypassPermissionsMode`. Any other key the template does not define (for example `disableAllHooks` or `apiKeyHelper`) is dropped, and named in the output. Each upgrade lists the kept rules and flags with `[!]` any rule PMB has since withdrawn from its template, any allow rule mentioning "merge", and any allow that is a bare tool name or `Tool()`, `Tool(*)` or `Tool(:*)`. If the merge cannot run (no runnable `python3`/`python` for `mb.sh`, or invalid JSON), the file is left untouched and a `[!] … not updated` line says to merge by hand. `mb upgrade --dry-run` prints the merged file's diff. The template's `deny` rules for signing bypass and `--no-verify` are a backstop for a failed hook process only: they match a command prefix, case-sensitively, so `git commit -m x --no-verify` passes them; the dangerous-commands hook is the control.

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

Set `ENFORCE=true` to promote warnings and unknowns to blocking. Advisory is the default —
a gate that blocks on a stale template tends to get disabled outright.

**Why UNKNOWN exists.** A check has three outcomes — passed, failed, or *could not run* — and an
exit code cannot distinguish the first from the last: a command that does nothing and returns 0
looks exactly like success. Check 7 therefore derives its verdict from `mb doctor`'s structured
output rather than its exit code, counting `[OK]`/`[WARN]`/`[ERROR]` lines to get both the result
*and* positive evidence the command actually ran. Zero result lines means UNKNOWN, never success.

**Why `--check`.** Plain `mb doctor` rewrites `.pmb-checksums` at the end of every run, so a hook
that ran it re-baselined on every push: a memory-bank edit was reported once, by the run that then
erased it. Check 7 runs `mb doctor --check`, which compares without writing, and requires the
`Integrity check mode:` line it prints — an older `mb` that ignores the flag is UNKNOWN. A checksum
mismatch gets its own warning and keeps appearing on every push until the edits are reviewed and
accepted with `mb verify-integrity`; `ENFORCE=true` blocks until then. A missing baseline (fresh
clone — `.pmb-checksums` is gitignored) is reported as `[INFO]` and does not count.

Relatedly, deprecated redirect shims exit **2** ("command moved") rather than 0, so a script reading
only an exit code can tell that nothing ran. Aliases that still perform real work keep exit 0 —
check the implementation before assuming a deprecated name is inert.

**`.githooks/pre-commit`** — four-check gate before every `git commit`:
- **Blocks** if `handoff.md` is staged (`handoff.md` is ephemeral and must not be committed)
- **Blocks** `memory-bank/` changes committed from a linked git worktree. `memory-bank/` is edited and committed only in the main worktree; `mb commit` refuses in a linked worktree, and this is the check a plain `git commit` reaches. It covers `git commit`, `commit -a`, `commit -- <path>`, renames out of `memory-bank/`, and any casing of the directory name. When finishing a conflicted merge, files whose staged content matches the merged branch (`MERGE_HEAD`) pass, since they were not edited here; anything else in `memory-bank/` is refused, with `git checkout MERGE_HEAD -- <path>` as the way to take the merged version. A git submodule is its own main worktree and is not affected. Any error inside the check refuses rather than passes. It applies whether or not a project's `CLAUDE.md` states the rule.
- **Warns** if `CLAUDE_AUTOCOMPACT_PCT_OVERRIDE` is missing from `.claude/settings.json` (token budget auto-compaction may not be configured)
- **Runs the repo's format check, if it has one**, last, so it cannot change the checks' verdicts, and refuses the commit if the script changes what is staged. See *The format check* below.

**Known gaps in the worktree check.** It is a tripwire on the `git commit` path, not a complete boundary: git does not record which worktree an edit was made in, so no hook can be one.
- **Which commands run `pre-commit`** (measured on git 2.55, each hook logging to a file): `git commit`, including one that concludes a conflicted merge; `git merge --continue`; and `git cherry-pick --continue` / `git revert --continue` after a conflict. These create commits without it: a clean `git merge` (runs `pre-merge-commit` instead, so a clean `git pull` too), a clean `git cherry-pick` or `git revert`, `git rebase --continue`, `git am` (runs `pre-applypatch` instead), and plumbing such as `git commit-tree` with `git update-ref`.
- **A clean `git revert` or a `git am` can author `memory-bank/` changes unchecked.** Reverting a main commit that touched `memory-bank/` writes new `memory-bank/` content in the worktree and rolls main back when the branch merges; `git am` applies whatever the patch contains. A conflicted cherry-pick or revert that touches `memory-bank/` does run the hook when finished, and by the hook's logic is refused, since there is no `MERGE_HEAD` to compare against (not covered by a test).
- A clean merge is not a way to author `memory-bank/` changes: it can only bring in the merged branch's content, because `git merge` refuses to start with changes staged unless it can fast-forward (measured; a fast-forward leaves a staged change staged, so it still meets this check at the next `git commit`). The one difference from the conflicted path: files git combines from both sides are refused there but committed by a clean merge, which can only happen when this branch already carries committed `memory-bank/` changes.
- `git commit --no-verify`, its short form `-n`, and `git -c core.hooksPath=<elsewhere> commit` skip the hook. The dangerous-command hook asks for confirmation only on the literal `--no-verify`.
- With the default relative `core.hooksPath = .githooks`, each linked worktree runs the hook from its own branch, so a worktree on a branch older than this check is unprotected until that branch picks it up. An absolute `core.hooksPath` makes every worktree run the main checkout's copy instead.
- A merge trusts `MERGE_HEAD`: content inherited from any merged branch passes, including branches whose `memory-bank/` commits skipped this check. Taking the merged branch's version with `git checkout MERGE_HEAD -- <path>` also discards your own branch's side of that file, which matters when your branch carries `memory-bank/` commits of its own. Octopus merges are untested; by the hook's logic they are compared against the first merged head only, which refuses rather than passes.
- In a bare repository with worktrees, every worktree is a linked one, so `memory-bank/` cannot be committed anywhere without skipping the hook. `mb commit` and `CLAUDE.md`'s `--git-common-dir/../memory-bank/` path already assumed a main worktree; this check turns that assumption into a hard block.
- It checks commits, not edits. Editing `memory-bank/` in a linked worktree is still against the rule, but is only caught when committed.

**The format check.** A repo opts in by adding `.githooks/format-check`. It is repo-owned: `mb upgrade` replaces only `pre-commit` and `pre-push` in `.githooks/`. With no such file the step does nothing and prints nothing.
- **What the hook does.** It lists the staged regular files and pipes them to `bash .githooks/format-check` on stdin, NUL-terminated, from the top of the working tree. The script needs no executable bit. Exit 0 lets the commit through; any other exit refuses it, naming the script and exit code. The script is not run when nothing is left to check (a deletion-only commit, for instance). The script must not change what is staged: the checks above ran on the index before it, so if the staged tree differs afterwards (a formatter that re-adds what it fixed, a `git add -u`) the commit is refused. After a plain `git commit`, what the script staged stays staged, and committing again runs every check on it. `git commit -a` and `git commit -- <path>` commit through a temporary index that git discards on refusal, so only the script's edits on disk remain.
- **Which files.** Added, modified and type-changed files whose staged mode is a regular file (`100644`/`100755`). Renamed and copied files are checked under their new path whatever `diff.renames` is set to. Deleted files, submodules and symlinks are not passed. `commit -a` and `commit -- <path>` get exactly what they commit. Finishing a conflicted merge checks every file the merge brings in, since CI will see them too. `--amend` checks only what is newly staged.
- **Why stdin, not arguments.** No command-line length limit; no path can be read as an option; and nothing is rewritten. Git for Windows' bash rewrites path-like arguments it passes to a native program (`x=/y.json` arrives as `x=C:/Program Files/Git/y.json`), but it never touches stdin.
- **The script inherits git's hook environment**, including `GIT_INDEX_FILE` while `commit -a` or `commit -- <path>` runs. Git calls in the script therefore see the index being committed, and a git call aimed at a different repository needs that variable cleared.
- **A prettier example** for Node repos is in your clone of Personal Memory Bank (the folder you installed from), under `templates/examples/format-check/`: copy both `format-check` and `format-check.mjs` into `.githooks/`, then run your repo's own prettier on the copied `format-check.mjs` (or list `.githooks/` in `.prettierignore`). It ships in prettier 3's default style, so under any other style the commit that adds it would be refused by the check itself. It checks each file's *staged* content with the repo's own prettier, through prettier's API in one process. Checking the file on disk instead blocks CRLF checkouts on Windows (`core.autocrlf=true`, Git for Windows' default) that CI passes, and passes a file fixed on disk but not re-staged that CI fails. It reports "not formatted" and "could not parse" separately. If prettier or node is not installed it warns and lets the commit through, since CI still runs; it never falls back to `npx`, which can pick up a global prettier of another version and whose Windows shims mangle file names. It targets npm and pnpm layouts: under Yarn Plug'n'Play it reads prettier as not installed.
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
