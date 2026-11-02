---
status: open
created: 2026-10-19
last-reviewed: 2026-10-19
staleness-threshold: 90d
related_plan: null
---

# Review-gate classifier gaps beyond culture comparison

Found 2026-10-19 while making `scripts/_review-gate-classify.ps1` compare ordinally (that fix closed
the culture-comparison class only). Each gap below lets a real commit or push through as NONE. NONE
means the review gate allows the command without a review marker. Measured on Windows, pwsh 7.6.6,
GNU xargs 4.10, OpenSSH 10.3 and git 2.55, unless marked inferred. Strings were built from UTF-8
bytes. Same class as [the variable-verb gap](review-gate-is-bypassed-by-a-git-verb-held-in-a-va.md):
a command-text parser models one shell, and real programs parse differently. The git-level marker
check planned in NS-26 Bundle A sees every one of these commits however it was spelled.

## ps1 only (the hook that runs first everywhere)

- **CR inside a word.** For `echo x | xargs -I<CR>{} git commit -m m` the ps1 twin gives NONE and py
  gives COMMIT. ps1 splits segments on a lone CR; py does not. Git Bash deletes the CR, so this runs
  `xargs -I{} git commit`. Dropping CR from the ps1 operator set is wrong: a lone CR separates
  PowerShell statements. Fail-closed option: classify with CR as a separator and with CR deleted, and
  take the union. Pinned as a known difference in `tests/test-review-gate-classify-parity.sh`.

## PowerShell tool (its matcher has no sh fallback; see powershell-matcher-hooks-have-no-bash-fallback-so.md)

Both classifiers apply bash quoting rules, and PowerShell's rules differ:
- `echo <U+201C>abc" ; git commit -m x ; echo <U+201C>def"`: PowerShell treats U+201C as a double quote
  that an ASCII `"` closes, so the middle statement runs. The classifier gives NONE.
- `` echo `"; git commit -m x ``: the backtick escapes the quote, the commit runs, the classifier gives NONE
  (opposition review, measured).
- `& 'git ' commit -m x`: pwsh resolves a trailing space, U+0085 or U+00A0 to git (opposition review, measured).

## Both twins

- **Whitespace bash does not split on.** Both tokenizers use `\S+`. So in `git -c a.b=c<U+00A0>x commit`
  (also U+3000, and VT/FF), both see `x` as the verb. Bash keeps it one word, and the commit ran.
- **Option forms the twins do not model** (opposition review; the xargs forms ran with echo):
  - xargs: `xargs --replace git commit` and `--eof` (optional attached argument), `xargs -tI {} git commit`
    (bundled flags), and `xargs --max-a 1 git commit` (getopt prefix abbreviation).
  - ssh: `ssh -tl u host git commit` (bundled; `ssh -G` confirms the host parse). Also inferred: ssh options
    placed after the host.
  - pwsh: `pwsh -comm "..."` and `pwsh --command "..."` (prefix and double-dash forms; both ran).
  - git: `git -c help.autocorrect=immediate comit` (inferred from the measured `staus` case).
- **Launcher switch spellings the twins do not model** (the opposition review measured that they run;
  both twins give NONE for `git commit -m x` behind each, measured):
  - pwsh on Windows: `pwsh /c "..."` and `pwsh /command "..."`;
  - pwsh with an en or em dash: `pwsh <U+2013>c "..."` and `pwsh <U+2014>Command "..."`;
  - cmd with the command attached to the switch: `cmd /cgit commit -m x`;
  - cmd under Git Bash: `cmd //c git commit -m x` (MSYS turns `//c` into `/c`).

## Python only (the sh hook)

- Python's `\s` includes U+001C..U+001F, while .NET's and bash's do not. So `git -c a.b=c<U+001C>x commit`
  is NONE in py and COMMIT in ps1. Pinned as a known difference.
- The wrapper check is `t.strip('"\'') in WRAPPERS`, with no basename and no case folding. So `/usr/bin/env git commit`
  and `ENV git commit` are NONE in py and COMMIT in ps1 (measured).

## Other enforcement scripts

- `scripts/check-contract.ps1:105` uses `$targetFile.StartsWith($pattern)` (culture), and `:111` uses
  `-like`. Both compare paths taken from tool input. Whether that is exploitable is untested.
- The classifier's two callers still compare with culture `-eq`/`-ne`. Against fixed verdict tokens
  this is harmless: `scripts/review-reminders.ps1:86-91` and `scripts/review-reminders-post.ps1:27,63`.
  Against SHAs read from files or git it is untested: `review-reminders.ps1:239,255,268,275` (255
  and 275 compare the review marker's content with the expected SHA) and
  `review-reminders-post.ps1:72,74`. Whoever can write the marker can write the exact SHA, so no
  gain for an attacker is known.
