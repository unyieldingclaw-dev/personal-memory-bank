---
status: open
created: 2026-10-14
last-reviewed: 2026-10-15
staleness-threshold: 90d
related_plan: null
---

# Agent-scoped network deny for the read-only review agents

**Decided by the user on 2026-10-14**, in the session that ported Side-Quest-Atlas's dangerous-commands
rules. This is the next branch after that port. Do it as its own branch, off a freshly pulled `main`,
because it edits `scripts/dangerous-commands.{sh,ps1}` too.

**What decays here:** the Claude Code version, the docs quotes and the transcript counts below.
Re-read the docs pages and re-measure before relying on them.

## The decision

- **No fleet-wide rule for `curl`, `wget`, `Invoke-WebRequest`/`iwr` or `Invoke-RestMethod`/`irm`.**
  The shipped standard ("Network Access") gives the reasons in general terms; the evidence is here:
  - CONFIRM in this hook is a hard deny;
  - a scan on 2026-10-14 of about 28,000 Bash and PowerShell tool calls in main-session transcripts
    under `~/.claude/projects` found about 120 that such a rule would have denied, about 60% of them
    localhost checks. Subagent transcripts (about 53,000 more calls) were not counted. Side-Quest-
    Atlas's own word boundary matches about 150 on the same calls, the extra ones being text that
    only names a tool. An earlier version of this line said "122 of 28,251": 28,251 was the
    denominator of a different, later scan;
  - the auto-mode classifier already blocks sending sensitive data to external endpoints.
- **Instead: deny network fetches only when the tool call comes from one of PMB's read-only review
  agents**, `opposition`, `researcher` and `security-reviewer`. None of them has a reason to fetch.
  `opposition` has already been observed running `curl` outside its grant
  (`.claude/agents/opposition.md`, SCOPE CAVEAT).
- **A fleet-wide hook `ask` was considered and rejected.** It forces a native prompt even in auto
  mode (docs, hooks: PreToolUse decision control, from v2.1.211), but it stalls unattended auto-mode
  runs on legitimate fetches.

## Spike first: does `agent_type` reach the hook?

The docs (hooks, "Common input fields") say `agent_type` is present "when the hook fires inside a
subagent", and that subagent tool calls fire the same PreToolUse hooks. **This is documented, not
measured.** The design rests on it, so measure it before writing any matcher:

1. Use a scratch directory with a logging PreToolUse hook. Run `claude -p --setting-sources
   project`, with a subagent that runs one Bash command.
2. **Pass:** the payload for the subagent's call carries `agent_type` equal to the agent name, and
   the main session's call does not.
3. Check both the CLI and the desktop app. A prior spike found that a desktop session in a worktree
   runs relative-path hooks from the *main* checkout.

## Design notes for when the spike passes

- **Extraction:**
  - sh: in the python3 step, alongside `tool_input.command`.
  - ps1: from `$data.agent_type`.
  - Decide the raw-JSON fallback, used when python3 is missing: a raw grep for
    `"agent_type":"opposition"` is spoofable by command text, so prefer failing open to the
    unscoped behaviour, and say so.
- **Rows:** the boundary-checked names from Side-Quest-Atlas's `confirm_boundary` rows.
  `curl.exe` and `wget.exe` need a trailing `.exe` alternative.
- **The test harness** needs a way to put `agent_type` in a payload. The escape-parity registry
  builds payloads with `tool_name` and `tool_input` only.
- **Mirrors:** both hooks and their `templates/` mirrors, plus the agent files' SCOPE CAVEAT, which
  should name the new enforcement.
- **Tell Side-Quest-Atlas** when this merges, so it can decide whether the scoped rule replaces its
  fleet-wide local copy.
