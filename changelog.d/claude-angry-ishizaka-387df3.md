### Fixed
- **`mb upgrade` silently deleted a project's permission rules.** `.claude/settings.json` was
  overwritten wholesale, so an adopter's `deny` rules (signing bypass, `--no-verify`, `gh pr merge`)
  and its own `allow` rules vanished on upgrade with no diff or backup. Both `mb.sh` and `mb.ps1` now
  merge `permissions`: the template's entries plus every `allow`/`deny`/`ask`/`additionalDirectories`
  entry the project added, and `disableBypassPermissionsMode`. Hooks, `env` and `model` still come
  from the template; any other project key (such as `disableAllHooks`) is still dropped, now by
  name. Kept rules are listed on every upgrade, with `[!]` flags for rules PMB has withdrawn, allow
  rules mentioning "merge", and broad allows. If the merge cannot run, the file is left untouched.
  `--dry-run` now shows `+A/-B lines` for each template-owned file it would overwrite, and the
  merged diff for `settings.json`. The template gains `deny` rules for signing bypass and
  `--no-verify` (Bash and PowerShell forms; a backstop for a failed hook process, not coverage) and
  for the two MCP merge tools PMB's own settings already deny. No `gh pr merge` deny: a deny rule
  beats the merge gate's `"ask"`.
