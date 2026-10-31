### Fixed
- **Text printed beside a hook's JSON could void its deny (per Claude Code's docs).** The hooks docs treat
  stdout that does not start with `{` as plain text and ignore the JSON, and two wiring defects in
  `.claude/settings.json` put text there. No `-NoProfile`: anything a PowerShell profile printed
  came first (measured on Linux pwsh 2026-10-16: a `$HOME/.config/powershell` profile prints under
  `-File`). With `pwsh` installed and the `.ps1` missing, `pwsh` printed its usage text (996 bytes,
  exit 64) and `|| bash` then printed the deny after it. The `PowerShell`-matcher entries had no bash
  fallback at all, so a missing `.ps1` left the PowerShell tool ungated. All 10 PreToolUse and
  PostToolUse strings (both settings copies) are now
  `[ -f scripts/X.ps1 ] && pwsh -NoProfile -NonInteractive -File scripts/X.ps1 2>/dev/null || bash scripts/X.sh 2>/dev/null || true`.
  Limits, stated:
  - On the `PowerShell` matcher the bash fallback is partial. `dangerous-commands.sh` has none of the
    five PowerShell-native BLOCK rows (`Remove-Item -Recurse`, `Format-Volume`, pipe-to-`iex`);
    before, that path checked nothing.
  - A `.ps1` that reads stdin and then crashes still leaves bash an empty stdin, so the call is
    allowed (plan `2026-08-20-hook-enforcement-integrity.md`, Task 4).
  - The form needs a POSIX shell (Claude Code's default for hooks); under PowerShell, `[ -f … ]`
    does not parse.
  - The `PreCompact` string is unchanged. It has its own missing-`.ps1` fail-open (exit 64 is a
    non-blocking error, so compaction proceeds) and no `-NoProfile`; whether that gate stays at all
    is an open decision, and its wiring is left to it.
  - PMB's own Stop entry (`pre-approval-check`, on trial, not in the template) is unchanged: it
    already passes `-NoProfile`, but a missing `.ps1` still puts `pwsh`'s usage text before its JSON.

  New `tests/test-hook-wiring.sh` runs the exact strings, with each `.ps1` present, deleted, broken,
  and behind a printing profile, each mode with a positive control, and checks statically that every
  string is the exact guarded form for its own script. `docs/HOOKS-GUIDE.md` (both copies) explains the form, and its `PreCompact` snippet, a
  `|| … || true` chain that would never block, now shows the real wiring.
