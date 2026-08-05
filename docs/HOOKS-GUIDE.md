# Hooks Guide

<!-- SYNC NOTE: templates/docs/HOOKS-GUIDE.md is a manually-trimmed copy of this file (PMB's
     own postmortem/bug-history prose removed, everything else kept). Edits to shared content
     here (hook tables, config snippets, per-hook descriptions) must be mirrored there by hand. -->

Hooks run deterministically at Claude Code lifecycle points. Unlike `CLAUDE.md` (which is advisory — Claude can drift), hooks **always execute** and can block or modify Claude's actions.

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

## Default Hooks in This Standard

Configured in `.claude/settings.json`:

### 1. Dangerous-Command Blocker (`PreToolUse` — Bash + PowerShell tools)

Intercepts both Bash and PowerShell tool calls before they run using `scripts/dangerous-commands.ps1`. Enforces 3-tier safety:

**BLOCK** (19 patterns — command exits non-zero, Claude stops):\
*Shell:* `rm -rf` · `mkfs` · `dd if=` · `git push --force` · `git push -f` · `DROP TABLE` · `DROP DATABASE` · `| bash` · `| sh` · `|bash` · `|sh`\
*PowerShell-native:* `Remove-Item -Recurse -Force` · `Remove-Item -Force -Recurse` · `Format-Volume` · `| Invoke-Expression` · `|Invoke-Expression` · `| iex` · `|iex`

**CONFIRM** (7 patterns — surfaces confirmation dialog):
`git filter-branch` · `git update-ref` · `sudo rm` · `chmod -R 777` · `--no-verify` · `TRUNCATE TABLE` · `DELETE FROM`

**WARN** (4 patterns — exits 0, surfaces access alert):
`id_rsa` · `.pem` · `.env.production` · `credentials.json`

If BLOCK or CONFIRM is triggered, the tool call is denied before it executes. WARN surfaces the access as advisory text and lets the command proceed.

Implemented in `scripts/dangerous-commands.ps1` (Windows/pwsh) and `scripts/dangerous-commands.sh` (POSIX/bash). Configured in `.claude/settings.json` with two matchers — one for `Bash` (with sh fallback) and one for `PowerShell` (PS-only):

```json
{ "matcher": "Bash",       "command": "pwsh -NonInteractive -File scripts/dangerous-commands.ps1 2>/dev/null || bash scripts/dangerous-commands.sh 2>/dev/null || true" },
{ "matcher": "PowerShell", "command": "pwsh -NonInteractive -File scripts/dangerous-commands.ps1 2>/dev/null || true" }
```

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
- **Out-of-scope write (default):** prints a warning and exits 0. Claude sees it and should pause.
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

**Why silent failure?** The hook must never block agent work. If the update fails (e.g. file not found, malformed frontmatter), the agent continues and the user can run `mb audit` to find stale files. Implemented in `scripts/update-reviewed.ps1` and `scripts/update-reviewed.sh`.

**Hook error logging (G2):** unexpected errors are logged to `.pmb-hook-errors.log`.

### 5. PreCompact Memory Gate (`PreCompact`)

Fires before Claude Code compacts context. Runs two content-based quality checks on the memory bank **or** bypasses via `handoff.md`.

**Exit codes:**
- **Exits 0** — both checks pass (or `handoff.md` bypass is present). Compaction proceeds normally.
- **Exits 2** — one or more checks fail. **Compaction is blocked.** Claude Code treats a non-zero exit from a PreCompact hook as a block signal. The hook prints an actionable message explaining what to do.

**To unblock:** address the failing check (see below), then retry. Alternatively, create `handoff.md` to bypass the gate (the handoff file signals that session state has been captured via the Handoff Protocol).

**Detection logic (content-based, not mtime):**
- **Check 1 — `activeContext.md` substantive content:** counts non-frontmatter, non-heading, non-empty lines with ≥20 characters. Requires ≥3 such lines. A file that was only touched (e.g. `last-reviewed` timestamp updated) fails this check.
- **Check 2 — `progress.md` dated entry:** looks for at least one line starting with today's date (or a markdown heading/list prefix followed by today's date). The date must appear at the start of a line — embedded dates in prose do not count.
- **Bypass:** `handoff.md` present in the project root skips both checks.

**Fails open:** unexpected errors (missing runtimes, unreadable files) exit 0 silently and log to `.pmb-hook-errors.log`.

Implemented in `scripts/pre-compact-check.ps1` (Windows/pwsh) and `scripts/pre-compact-check.sh` (POSIX/sh):

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

Note: `PreCompact` hooks have no `matcher` field — the hook type applies to the compaction event itself, not to a specific tool.

### 6. Agent Delegation Depth Check (`PreToolUse` — Agent tool)

Fires before every `Agent` tool call. Tracks nested agent delegation depth and emits a WARN when depth exceeds the budget defined in `standards/PERFORMANCE-BUDGET.md` (default: ≤1 subagent deep). Implemented in `scripts/delegation-depth-check.ps1` and `scripts/delegation-depth-check.sh`.

**Runtime state file:** The hook stores its counter in `.pmb-delegation-depth` in the project root (gitignored). This file is created automatically on the first agent dispatch and resets after 2 hours of inactivity. Delete it manually to reset the depth counter mid-session without restarting.

**Hook error logging:** Unexpected errors are logged to `.pmb-hook-errors.log`.

### 7. Review Gate (`PreToolUse` — Bash + PowerShell tools)

Fires before every Bash *and* PowerShell tool call and pattern-matches `git commit` / `git push` / `gh pr merge` (including compound commands like `cd X && git commit ...`). Denies the commit or push unless a matching, diff-bound review-ok marker exists in `.claude/`, mechanically enforcing WORKFLOW.md's "review before commit/push" phases instead of relying on Claude following the prose. `gh pr merge` is denied unconditionally — see below. Implemented in `scripts/review-reminders.ps1` and `scripts/review-reminders.sh`. Wired into both the `Bash` and `PowerShell` tool matchers in `.claude/settings.json` — a commit/push run via the PowerShell tool is gated identically to one run via Bash; earlier, only the `Bash` matcher was wired, so `powershell -Command "git commit ..."` bypassed the gate entirely.

**Marker files (single-use per diff, gitignored):**

- `.claude/.code-review-ok` — written by `/code-review`'s Opposition-review subagent (Step 5) when the Verdict is **Approve**. Contains a SHA-256 hash of `git diff HEAD` at review time, not an empty file.
- `.claude/.change-review-ok` — written by `/change-review`'s Job 9 (Opposition) subagent when no finding has `Blocking: Yes`. Contains a SHA-256 hash of `git diff origin/main...HEAD` (or `git diff HEAD` with no upstream).

**Why a hash, not an empty marker:** an empty marker is trivially fakeable with `touch` — anyone, or a rushed agent, can satisfy the gate without reviewing anything. Binding the marker to a hash of the exact diff means it only authorizes committing/pushing that specific diff; if the working tree changes after the review, the hash no longer matches and the gate re-engages. The hook recomputes the same hash fresh and compares it to the marker's stored value before allowing the commit/push through.

**Atomic consumption:** the marker is claimed via an atomic rename (`Move-Item`/`mv`) rather than a separate existence-check followed by delete, closing the TOCTOU window between the two steps — if the source doesn't exist, the rename simply fails, collapsing "does it exist" and "claim it" into one filesystem operation. The marker is consumed (renamed away and deleted) whether or not its hash matches — a stale marker from a diff that has since changed doesn't linger; a fresh review is required either way.

**Commit and push are classified and validated independently, not via one first-match branch:** a compound command chaining both — `git commit -m x && git push origin main` — contains both trigger substrings. Branching on the first match alone would validate only the commit half and never even look at the push marker, letting an unreviewed push ride through on the strength of a valid commit marker. Both `.sh` and `.ps1` compute independent `needs_commit`/`needs_push` flags and check each against its own marker; a compound command must satisfy both to proceed.

**Two significant fixes (2026-07-02), found via a real, unauthorized commit going through untouched:**

1. **`{"continue": false}` doesn't block execution.** The original design used the top-level `continue`/`stopReason` JSON fields to signal a deny. Empirically, this only interrupts the agent's *next turn* — the gated tool call had already run by the time the signal took effect. Fixed by switching to `hookSpecificOutput.permissionDecision: "deny"`, the field Claude Code actually reads to deny a tool call before it executes.
2. **Anchored regex missed real command shapes.** The original matcher required `git commit`/`git push` to follow the start of the command or a `;`/`&`/`|` operator. Since `$cmd` is already the exact, JSON-parsed command text (not raw payload noise), this anchoring bought little safety while missing multi-line Bash tool commands, a bare single `&`, and nested subshells. Simplified to an unanchored match — the only cost is an occasional unnecessary re-review if "git commit" appears as a substring elsewhere, the safe failure direction for a security gate.

Both the `.sh` and `.ps1` versions extract `tool_input.command` via real JSON parsing (`extract_command()` using python3 in `.sh`; `ConvertFrom-Json` in `.ps1`) rather than matching against the raw stdin payload. Matching raw stdin is unsafe in two directions: the real Bash tool payload also carries `tool_input.description` alongside `command` (e.g. a read-only `git log` call described as "remember to git commit these staged changes later" would falsely trigger the gate), and a JSON-escaped quote inside the command (e.g. `git commit -m "wip"`) can silently truncate a naive `grep`/`sed` extraction, letting anything after it — including a chained `&& git push` — through unchecked. Both scripts fall back to raw-stdin matching only when JSON parsing genuinely fails (missing python3, malformed payload) — the safe failure direction being an occasional unnecessary re-review, never silently under-gating.

**Detection is layered and additive, never a single exclusive match.** The quote/backslash-stripped, lowercased substring/regex check (see the quote-stripping/case-folding fixes below) always runs first, unconditionally, on whatever command text is available — extracted or raw-stdin fallback alike — and forms the coverage floor. On top of it, a real tokenizer — `classify_targets()` in `.sh` (python3's `shlex`, POSIX mode) and `Get-CommandTargets` in `.ps1` (a native equivalent) — splits the command on shell control operators (`&&`/`||`/`;`/`|`) and walks each resulting simple command's tokens past git's/`gh`'s own documented global options (`-C <path>`, `-c <name>=<value>`, `--opt=value` forms, `-R`/`--repo`, etc.) to find the actual subcommand, whenever it can run (no python3 missing in `.sh`; no unexpected exception in `.ps1`). Its findings are OR'd into the floor's result, never replacing it. This closes a gap the substring check alone can't: `git -C /path commit -m x` and `git -c user.name=z commit -m x` are ordinary, idiomatic git invocations — not adversarial obfuscation, an agent naturally reaches for `-C` when working across directories — whose text never contains "git commit" as a contiguous run (found via this session's opposition-review pass, present even on `origin/main` before any of this branch's fixes). The tokenizer is also strictly more precise on its own: it correctly ignores `git log --grep=commit` (a real subcommand match, not a substring hit), and naturally handles any whitespace run (tabs, multiple spaces, newlines) since it splits on whitespace rather than a literal single space.

**Why additive, not the tokenizer as an exclusive primary with the substring check demoted to a fallback:** an earlier draft of this fix did exactly that — treated "the tokenizer ran without error" as authoritative and skipped the substring check whenever it succeeded. But the tokenizer only recognizes a head token of *exactly* `git`/`gh`; it does not match `/usr/bin/git commit`, `env git commit`, or any other ordinary indirect invocation, so on those inputs it "successfully" finds nothing — which silently suppressed the substring check that DID contain "git commit" as a literal substring and would have caught them. Reproduced directly: that draft let `/usr/bin/git commit -m x` through with no deny at all, a real regression versus the substring check's own pre-existing coverage. Running both checks unconditionally and OR'ing the results means the tokenizer can only ever ADD detection (the `-C`/`-c`/whitespace-variant forms it understands), never remove coverage the substring check already had — locked in by the `/usr/bin/git commit`/`env git commit` regression tests in `tests/test-review-reminders.sh`.

**`.ps1`'s flag-recognition must be case-sensitive, not PowerShell's default:** `Get-NextSubcommand`'s `$OptsWithValue -contains $t.ToLower()` check used PowerShell's default case-*insensitive* `-contains`, which silently treated a lowercase `-r` (not a real `gh` global option) as matching the real `-R` entry in `$ghOptsWithValue`. That misclassified `-r` as a value-consuming flag, causing `gh -r pr merge 8` to have `pr` consumed as `-r`'s "value" — leaving `merge` looking like the (wrong) subcommand and silently defeating the `sub -eq 'pr'` check. Reproduced directly: that exact payload was **not denied at all** by the unconditional `gh pr merge` control, on `.ps1`, the preferred runtime — a live bypass, not a hypothetical one. Bash's equivalent Python `in` check was never affected (Python's `in` is inherently case-sensitive), so this was PowerShell-only. Fixed by switching to `-ccontains` against the raw (non-lowered) token in both `review-reminders.ps1` and `review-reminders-post.ps1` — matching real git's/`gh`'s own case-sensitive flag grammar (`-c`/`-C` are different git options; `gh` has no `-r` at all) as well as bash's already-correct behavior.

**Quote-stripping and case-folding (found via empirical reproduction, present even on `origin/main`):** a command like `git c"o"mmit -m "x"` executes, after the real shell's own quote removal, as a genuine `git commit -m x` — but the literal command text never contains "git commit" as a contiguous substring, so raw matching missed it silently. Both hooks now also match against a copy of the command with quote/backslash characters stripped and lowercased before applying the fallback substring check — stripping and lowercasing can only ever make a match MORE likely to fire, never less, so this closes the gap without being able to introduce a new bypass, only the same accepted false-positive cost this file's design already makes elsewhere. The lowercasing separately closes a bash/PowerShell parity gap: `.ps1`'s `-match` was already case-insensitive by default while `.sh`'s `case`/esac wasn't, so `Git Commit` (capitalized) passed the bash hook unmatched — on the default case-insensitive Windows/macOS filesystem, `Git`/`GIT` can resolve to the same git binary as `git`, so this wasn't merely cosmetic.

**`gh pr merge` — unconditional deny, no marker (added 2026-07-09):** unlike commit/push, this is not a diff-bound hash check — it always denies, full stop, with no override. By the time a PR is mergeable, its diff has already passed the commit gate, the push gate, and (assuming branch protection's `required_status_checks.strict: true`) CI on the current head; a third hash gate here would mostly re-verify what's already verified, while adding real fragility (PR-number/`--repo` parsing, a `gh pr diff` API call inside a hook). The actual gap at merge time isn't diff integrity, it's authorization: merging changes shared history and should never happen without the user deciding to do it in that moment — a hash can't encode "the user meant this right now," only an explicit human action can. This hook only ever sees commands the agent itself runs (a human's own terminal usage is invisible to it), so an unconditional deny is total: if this hook fires at all, it's the agent attempting the merge, never the user, so there's no legitimate case to let through — not even an explicit in-conversation instruction from the user, since honoring that would mean the agent still performs the merge action itself. The user always runs `gh pr merge` directly. This check matches unconditionally against whatever command text is available — the reliably parsed value, or the raw-stdin fallback when parsing fails — deliberately accepting the same over-triggering risk commit/push already accept on that fallback path (an occasional unnecessary deny of an unrelated command whose payload merely mentions "gh pr merge" somewhere, e.g. in `tool_input.description`) rather than the alternative: silently disabling the one control in this file explicitly designed to have zero override.

### 8. Review Gate Failure Recovery (`PostToolUse` — Bash + PowerShell tools)

Companion to the Review Gate above. If a gated `git commit`/`git push` consumes a marker and then the command itself fails (a separate pre-commit hook rejects it, nothing is staged, a merge conflict), this hook reissues the marker so the rejected attempt doesn't force a pointless re-review — the diff hasn't changed, so the same review still applies. Implemented in `scripts/review-reminders-post.ps1` and `scripts/review-reminders-post.sh`. Same independent commit/push classification as the PreToolUse hook, and wired into both the `Bash` and `PowerShell` tool matchers.

**How it detects failure without depending on an unverified response schema:** the `PreToolUse` hook records the current git ref (`HEAD` for commit, `@{u}` for push) to a temp file immediately after consuming a marker. This `PostToolUse` hook compares that recorded ref to the ref's current value — if it didn't move, the command failed, full stop, regardless of what any tool-response field says. This was a deliberate choice over parsing `tool_response` for a success/failure field: the PreToolUse payload shape only became known through live empirical capture, and extending that same guesswork to PostToolUse's response schema risked repeating the same mistake. Ground-truth git state needs no schema assumption.

**On detected failure, the hook replays the persisted `.pending-commit-hash`/`.pending-push-hash` value — it does not recompute the diff hash fresh.** An earlier version recomputed fresh, on the assumption that a failed commit/push can't have altered the working tree. That assumption is false whenever a downstream project's own pre-commit hook mutates files and then rejects the commit (an auto-formatter running `black --check`/`prettier --check` is a common, unexceptional example): `HEAD` doesn't move in that case, but the diff does, so a fresh recompute would reissue a marker for a diff `/code-review` or `/change-review` never actually saw. The `PreToolUse` hook now persists the exact hash it validated (`.pending-commit-hash` / `.pending-push-hash`, alongside the existing `.pending-*-presha` ref files) at the moment it authorizes the attempt, and this hook replays that value verbatim on reissue — the reissued marker always corresponds to a diff that was genuinely reviewed, never a freshly-derived value reflecting whatever the tree looks like now.

**Fails closed (skips reissuing) if the hash file is missing or torn**, rather than falling back to a fresh recompute — falling back would silently reintroduce the exact bug this fix closes for that one anomalous case. A missing hash file (a presha file present without its paired hash, or vice versa) means the pending state doesn't fully describe a validated attempt this hook can safely vouch for, so the safe direction is no reissue, forcing an explicit re-review. This pairing also bounds the impact of overlapping commit/push attempts racing on these unkeyed files (e.g. two subagent sessions, or a retry while a prior attempt's hooks are still running): even if one attempt's presha/hash pair gets clobbered by another's, whatever pair survives is still some genuinely-validated hash from a real prior review — the race can misattribute which attempt's marker gets reissued, but can't manufacture an unreviewed one.

## Git Hooks (versioned)

PMB distributes two git hooks through the `.githooks/` directory, which is versioned in the project repo. `mb init` and `mb upgrade` both install these hooks and activate them via `core.hooksPath`.

### How it works

`core.hooksPath = .githooks` is a per-project git local config (stored in `.git/config`, not committed). When set, git resolves all hooks from `.githooks/` instead of `.git/hooks/`. The hook *files* are committed and versioned; the *activation* is a local git config that each `mb init`/`mb upgrade` run sets automatically.

`mb upgrade` treats `.githooks/pre-push` and `.githooks/pre-commit` as `TEMPLATE_OWNED` — it overwrites them unconditionally if they differ from the template, so hook logic stays current across PMB version bumps.

### The two hooks

**`.githooks/pre-push`** — delegates to the 7-check push gate:
- Unresolved merge conflicts or conflict markers
- Uncommitted working tree changes
- Missing `.gitattributes`
- Possible secrets in the push diff (AWS keys, API tokens, GitHub PATs)
- Files over 500 KB
- `mb validate` result (if `mb` is in PATH)
- Scans first pushes via `git log --not --remotes` when no upstream tracking ref exists

Dispatches to `scripts/pre-push-check.ps1` (Windows/pwsh) or `scripts/pre-push-check.sh` (POSIX/bash). Fails open — if the script errors unexpectedly, the push is allowed through.

**`.githooks/pre-commit`** — lightweight two-check gate before every commit:
- **Blocks** if `handoff.md` is staged (`handoff.md` is ephemeral and must not be committed)
- **Warns** if `CLAUDE_AUTOCOMPACT_PCT_OVERRIDE` is missing from `.claude/settings.json` (token budget auto-compaction may not be configured)

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
