---
status: open
created: 2026-10-14
last-reviewed: 2026-10-15
staleness-threshold: 90d
related_plan: null
---

# Shipped allow rules skip the auto-mode classifier

Found 2026-10-14 while porting Side-Quest-Atlas's dangerous-commands rules.

**What decays here:** the docs quotes, the file and line references, and which grants each
template ships. Re-read them before relying on them.

## The mechanism

Claude Code's auto mode resolves allow, ask and deny rules *before* the classifier (docs,
permission-modes, "How the classifier evaluates actions", step 1). Only broad code-execution rules
are dropped on entering auto mode: `Bash(*)`, interpreter wildcards, package-manager run commands,
and `Agent` and `Monitor`. A slash command's `allowed-tools` is also a permission grant, for the turn
that invokes it (docs, skills, "Pre-approve tools for a skill").

So anything a shipped allow rule matches runs with **no review at all** in auto mode, unless
`scripts/dangerous-commands.*` stops it. The port blocks common spellings (not every spelling; see
"Observed gaps" below) of:
- a force push;
- a `!` git alias;
- awk `system()` / `| getline` / `|& getline`.

The rest of the surface is still open.

## Still open

- **`Bash(git *)`** ships in `templates/.claude/settings.json` and covers git's own ways to run a
  command or reach the network:
  - config keys that run a command: `core.sshCommand`, `core.pager`, `diff.external`,
    `credential.helper`, `core.fsmonitor`, `--upload-pack=`, `--exec=`, and `ext::` remote URLs (with
    `protocol.ext.allow`);
  - the same set through `GIT_CONFIG_COUNT`/`GIT_CONFIG_KEY_n`/`GIT_CONFIG_VALUE_n`;
  - network verbs to a URL that is not a configured remote: `git ls-remote https://host/<data>`,
    `git fetch <url>` and `git clone <url>`. Data can ride in the URL path, so this is an
    exfiltration channel.
- **`/code-review`'s `allowed-tools`** grants `Bash(awk *)` and `Bash(find *)`, and
  `/change-review`'s grants `Bash(find *)`.
  - The port covers awk's `system()` and `getline`, but not `print ... | "cmd"`, gawk's indirect
    `@f()` calls or `@load`.
  - Narrowing the grant itself may be the better fix: decide what those commands actually need awk
    for.
- **Agent `tools:` lists.** `templates/.claude/agents/opposition.md` names `Bash(sed *)`,
  `Bash(awk *)` and `Bash(find *)`, and `researcher.md` names `Bash(find *)`. Unresolved: whether a
  subagent's `tools:` entry acts as an allow rule or only makes the tool available. The answer
  decides whether "no shipped rule approves sed" (the reason the port skipped sed's `e` command)
  holds inside those agents. Found by the port's /code-review (Correctness F3).
- **A force push the hook cannot see.** A push alias in user config (`pf = push --force`),
  `remote.<name>.mirror` or a `+` push refspec turns a plain `git push` / `git pf` into a forced or
  mirror push, all under `Bash(git *)`. A text hook sees only the command; closing this would need
  a check of the effective git config.

## Observed gaps in the structural rows (observed, NOT exhaustive)

Moved here from the shipped standard on 2026-10-15, which now says only that the matching is not
exhaustive. Found by the port's three review rounds. "(fixture)" means a KNOWN GAP row in
`tests/test-dangerous-commands.sh` pins it; anything else is unpinned.
- Push:
  - `--mi`, `--m` for `--mirror` (fixture). Git documents unique-prefix abbreviation; not executed,
    because the review gate refuses a scratch push.
  - An argument `stash` just before `push`, any case: `-C stash`, `-C STASH` (fixture),
    `--namespace stash` (fixture), `--work-tree stash`, `--git-dir stash`, `--attr-source stash`.
    Also a bare first word `h`/`sh`/`ash`/`tash` (fixture: `git h push`). The cost of not matching
    `git stash push`; see the row comment.
  - `git send-pack --force` (fixture).
  - A quoted backslash path to the binary, e.g. `& "C:\Program Files\Git\cmd\git.exe" push ... --force`
    (fixture). A forward-slash path blocks.
- rm:
  - More than 32 letters before the `r`/`f`, or between them (fixtures). 30 + 30 still blocks.
  - Flags padded far apart (fixture: 300 characters). The 255 bound runs from `rm`/`push` or from the
    other flag; it counts bytes in the sh hook and characters in the ps1 hook.
  - PowerShell spellings other than the `rm` alias: `Remove-Item` with the path first (fixture),
    `del`, `erase`, `rd`, `ri`, `rmdir` (the Remove-Item aliases `Get-Alias` lists on PowerShell 7.6.6,
    Windows); an en-dash parameter (fixture); a backtick escape in a PowerShell-tool payload.
- Both: a quoted `;` `&` `|` inside the segment (fixture); flags in a variable (fixture) or
  `GIT_CONFIG_*`; tab-separated forms when the JSON cannot be parsed and the raw text is matched.
- awk: `print ... | "cmd"` (fixture), `awk -f` (fixture), gawk `@f()` (fixture) and `@load`.

## Deferred from the port's reviews

- **Bound-edge fixtures (round-2 Testing T1).** Mutants that shrink a `{0,32}` or `{0,255}` bound
  survive the fixture table. Closing it needs an exact-edge BLOCK / N+1 SILENT pair per bound site
  (15 sites), each proven by its own shrink-by-one mutant; the leading space sits outside some
  quantifiers, so edges are easy to misplace.
- **A committed claims check.** A test that runs every backticked example in the standard's hook
  sections through both hooks and fails when the verdict disagrees with the text. Ran as a scratch
  script for the round-3 commit.
- **Rule changes not made:** match `--m`/`--mi` with a word boundary; narrow the `stash` exclusion to
  the subcommand position; unbound the single flag-letter runs (no measured performance need,
  and the bound opens the 32-letter gap).

## Options

1. **More hook rows.** Each is a denylist of spellings. Keep them structural, and measure false
   positives against real transcripts the way the port did.
2. **Narrow the shipped grants**, for example `Bash(git status *)` rather than `Bash(git *)`. This
   costs prompts for every adopter, and needs fleet data on which git subcommands agents actually run.
3. **Move broad grants to `ask` rules.** The docs say explicit ask rules prompt in every mode,
   including `bypassPermissions`.

Related: `docs/backlog/agent-scoped-network-deny-for-review-agents.md`, [NS-50](a) (`mb upgrade`
overwrites the `permissions` block of `.claude/settings.json`).
