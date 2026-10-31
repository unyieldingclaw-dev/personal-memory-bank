### Changed

- **What the sh hook's signing rows guarantee is now stated once, in
  `standards/SECURITY-GUARDRAILS.md`** ([NS-38]), as the conditions under which it holds, not a
  list of cases. `docs/HOOKS-GUIDE.md`, the comment on `dc_grep` in `scripts/dangerous-commands.sh`
  and the tests point there. The comment on `dc_grep` keeps the measured record of where the
  caller's-locale pass misses. The standard now also gives the PowerShell hook's unit as UTF-16 code
  units, and records that GNU grep 3.0 reads `GREP_OPTIONS`.
- **`dc_grep` denies when called without a subject** (CONFIRM), rather than answering "no match" and
  letting every command through. No call site does that today; the guard is for a future caller.

### Added

- `tests/test-dangerous-commands.sh` pins that guarantee: each bounded gap group prompts at 255
  bytes and not at 256, in both hooks, and the guarantee holds in every locale the machine has. The
  locale cells include upper-case and quote-split keys, an emoji and a lone surrogate. Two known
  limits are pinned as current behaviour. `tests/dangerous-commands.Tests.ps1` checks that a plain
  `cat ~/.ssh/id_rsa` warns once, not once per view.
