---
status: open
created: 2026-10-05
last-reviewed: 2026-10-14
staleness-threshold: 90d
related_plan: null
---

# dangerous-commands follow-ups after NS-38 / NS-40

This file lists the known gaps that the reviews of `fix/ns40-ns38-dangerous-commands` (PR #52)
recorded and did not fix. **Item 1 was the merge condition** that review set: the gap had to be
tracked before the PR merged. It is now fixed (see item 1). The other items never blocked the
merge and are still open unless marked.

**IDs.** `J2-1` and `C-7` are review-finding IDs the user supplied with the 2026-10-14 task. The
report that defines them is not in this repo; each is described in full where it appears.

**What decays here, and what to re-verify before relying on it:**
- **Where item 1's fix lives.** It was written on branch `claude/sweet-lovelace-b4d2dc` on
  2026-10-14. PRs here are squash-merged, so once it merges the branch name stops resolving: find
  the fix by the CHANGELOG entry headed "Without python3, the sh dangerous-commands hook missed".
- **Line numbers in items 2 to 4 are from `ab2dbfe`** and drift with any edit. `ab2dbfe` is NOT in
  `main`'s history, because PR #52 was squash-merged as `e3c2f43`. It is still reachable from the
  PR's head ref: run `git fetch origin refs/pull/52/head`, then `git show ab2dbfe:<path>`.
- **`CHANGELOG.md` is cited by quoted text, never by line.** Its `[Unreleased]` section grows from
  the top, so line citations were already 38 or more lines off by `e3c2f43`. Each quote is a
  fragment that sits on one line, so `grep -F` finds it; a miss means the text changed.
- **Measured claims** name the grep build and host they ran on. Re-measure before relying on one
  for a different build. Items 1 to 3 were measured unless they say "read", "unverified" or
  "cause not established". Item 4 records session events and cannot be re-checked from the tree.

## 1. Without python3, the sh hook matched the raw JSON payload — core FIXED, follow-ups open

**Fixed 2026-10-14** (see "What decays here" for where). What was wrong, so the fix can be
checked against it:
- When python3 is missing or fails, `scripts/dangerous-commands.sh` matches the whole stdin
  payload. It matched it with the JSON escapes still encoded, so a newline was the two characters
  `\n` and a tab was `\t`. That happened on **every** command when python3 was absent, not only
  when the JSON was malformed.
- Measured with python3 off `PATH` (`PATH=/usr/bin:/bin` on Git Bash, GNU grep 3.0; earlier in
  Docker on python:3.12-slim and on Alpine 3.24 with bash and GNU grep 3.12), these got **no
  verdict**, though each is BLOCK or CONFIRM with python3:
  - a pipe to `bash` split across a newline, or across a tab;
  - `git config commit.gpgsign` or `git push`, then a backslash-newline, then `false` or `--force`;
  - `git config commit.gpgsign`, then a tab, then `false`;
  - **J2-1 (added 2026-10-14):** a `(^|[^a-z])git` row straight after an escaped newline or tab.
    `git fetch`, a newline, then `git merge main` is CONFIRM with python3 and got no verdict
    without it. The `-c`, `config` and `--no-gpg-sign` signing rows failed the same way, because
    the `n` or `t` of the escape is a letter, so the leading boundary never matched;
  - **found 2026-10-14:** a bare `git merge` at the end of the command, and `git fetch && git
    merge`. In the payload, the closing `"` follows the command, and the row's trailing boundary
    is a space or the end of the string.
- **The fix.** The sh fallback decodes every JSON escape before matching: `\" \\ \/ \b \f \n \r
  \t`, an ASCII `\uXXXX` to its character, and `\u0000` to nothing. A non-ASCII `\uXXXX` becomes
  `?`, and an escaped surrogate pair becomes one `?`, because awk cannot portably write UTF-8, and
  no row treats a non-ASCII character as a letter or a space. An unescaped `"` (a string delimiter)
  becomes a space. The ps1 hook falls back only when parsing fails, and now decodes the same way,
  except that it writes a non-ASCII escape as the real character. Tests: three modes in
  `tests/test-dangerous-commands.sh` (python3 works, fails, absent) and malformed-payload cases in
  `tests/dangerous-commands.Tests.ps1`.
- **Found and fixed in review, 2026-10-14: a carriage return inside a word.** Git Bash deletes a CR
  while parsing, even with `igncr` off (measured: `ab`, CR, `cd` reaches the command as `abcd`). So
  `git push --for`, CR, `ce` is a force push, and `git merge`, CR, LF runs a bare merge. Neither
  hook gave a verdict on these, on either path, before this change. The decoder made one case
  worse: the old raw fallback BLOCKed `r`, CR, `m -rf` only because the two characters `\r`
  contained `rm -rf`, and decoding them to a real CR lost that accidental match. The sh hook, which
  judges only Bash, now deletes CRs in its de-escaped view. The ps1 hook judges the PowerShell tool
  too, where a lone CR separates statements (measured with PowerShell's parser), so it keeps its
  de-escaped view and matches a third, CR-deleted view in addition. A first version deleted CRs in
  ps1's own de-escaped view; round-2 review (finding OPP-1) measured that it turned a PowerShell-tool
  BLOCK (`curl … | ba"sh"`, CR, `x`) and three CONFIRMs into no verdict, so it was replaced. An
  earlier draft of this file said "a real shell keeps" the CR; that was asserted, not measured, and
  it was wrong for Git Bash.
- **Test-writing trap, found in review:** the tool that wrote the test files decoded `\u00e9`,
  `\u00a0` and `\u0026` into the characters themselves, so three "escape" cases ran literal
  characters and the decoder's non-ASCII branch went untested. Both suites now carry a note to check
  the bytes, and the surrogate-pair test builds its escapes at run time.
- **Texts that were wrong about this, all corrected in the same change:**
  - the sh hook's fallback comment, which said raw matching "never misses a true positive";
  - the ps1 hook's catch-block comment, which said the same and also that its fallback "mirrors
    dangerous-commands.sh's identical fallback exactly" (it falls back only on a parse failure);
  - the "Not covered" bullet in `standards/SECURITY-GUARDRAILS.md` that gave the raw-payload
    fallback as a split-pipe miss;
  - **added 2026-10-14:** the header of `tests/test-dangerous-commands.sh`, which said "a
    genuinely dangerous command is never missed even on that fallback path";
  - **added 2026-10-14:** this file's own fix outline, which said to decode only `\n` and `\t`.
    That list was incomplete: a backslash continuation arrives as `\\` then `\n`, and a naive
    `\n` rewrite reads a literal `\\n` (a backslash, then n) as a newline. The decoder handles
    `\\` as a pair first, and a test pins it.
- **The remedy is now stated once.** Each review round had found another incomplete restatement
  of the requirement, every one leaving python3 out. The requirement and what each missing piece
  costs now live only in the "Platform requirement (sh hook)" bullet of
  `standards/SECURITY-GUARDRAILS.md`, which separates the hard requirement (pwsh, or bash plus a
  `-z` grep) from python3, whose absence costs precision, not coverage. The deny message, the
  `dc_grep` comment, `docs/HOOKS-GUIDE.md` (and its template copy) and the `CHANGELOG.md` entry
  that, at `e3c2f43`, read "The deny message says to install GNU" now point there.
- **Fixed alongside it, at the user's request:** `git merge`, a newline, then another command got
  no CONFIRM on either shell, **with** python3 too. The newline is now a trailing boundary in both,
  and so is a CR, which PowerShell reads as a statement break (on Bash it is an accepted false
  positive, kept so both hooks give one verdict).

**Still open from item 1:**
- **The merge row's trailing boundary is still narrow.** A bare `git merge` straight before `;`,
  `&&`, `|`, `>` or `)` gets no verdict on either shell, with python3 present (measured 2026-10-14:
  `git merge;echo hi`, `git merge&&echo hi`, `(git merge)`, `git merge|cat`, `git merge>log`). A
  shell ends the word at each of these. Widening the boundary to shell metacharacters is the fix.
- **The fallback decodes before the length bound, so its cost is unbounded by it.** Measured by
  the Performance review: about 1.6 to 1.9 s per MB of escape-dense payload, linear, fallback
  only. A raw-size cap before decoding would bound it, but would also refuse some payloads that
  decode below the bound, so it is a behaviour change to decide on, not a fix to slip in.
- **ps1's parsed path keeps a NUL that every other path drops** (`r`, NUL, `m -rf` gets no verdict
  there). Whether a harness can deliver a NUL to bash at all is unverified, so this may be moot.
- **An NBSP or U+2028 after `|` is BLOCK on ps1 and no verdict on sh**, on both paths. It predates
  this change: ps1's `\s` is Unicode-aware and sh's `[[:space:]]` runs under `LC_ALL=C`.
- **On Git Bash, the parsed path misses an astral-character gap in the signing rows.** 140 emoji
  in a `git config --file` path get no verdict there under `C.UTF-8`, though grep 3.0 matches the
  same 140 characters against one bounded group (measured; cause not established). Linux (GNU grep
  3.11) prompts. The fallback prompts on both.
- **PowerShell splits words at separators the ps1 hook does not fold.** Its tokenizer breaks
  `git push`, then NBSP, VT or U+2028, then `--force` into separate words, and the ps1 hook gives
  no verdict on any of those through the PowerShell tool (measured by the round-2 Security
  review). It predates this change; the "NBSP is a non-boundary everywhere" rationale reasons only
  about bash.
- **Cross-shell cases go through two separate per-shell lists, not `assert_parity`.** The suite's
  own parity block exists to catch a sh/ps1 divergence on one payload; the parsed-path CR and
  newline-boundary cases could feed it, and nothing yet asserts the two hooks agree on them.
- **The decoder's rules and the CR and newline rationale are restated in five to seven places**
  (hook comments, standard, CHANGELOG, this file, both test files). One copy had already drifted
  in review. Pointing the others at the sh hook's comment would cut the copies.
- **The shipped standard names PMB's open "no external dependencies" question.**
  `standards/SECURITY-GUARDRAILS.md` ships to adopters, who never see PMB's decision and keep the
  "open" wording once it is settled. Track it in PMB's own memory bank instead.

## 2. Tests that do not discriminate, or never run in CI

- **The no-space pipe forms are not pinned.** Neither suite tests `|bash` or `|sh`, or a same-line
  `| sh` on the sh hook, or `|bash` / `|sh` on the ps1 hook. A mutation from `[[:space:]]*` to
  `[[:space:]]+` (or `\s*` to `\s+`) stays green.
- **The bound guard misses `{,n}`.** `tests/test-dangerous-commands.sh:757-766` extracts
  `\{[0-9]+(,[0-9]*)?\}`, so `{,300}` passes the guard, yet GNU `grep -E` treats `{,300}` as a
  bound. Widen the pattern to `\{[0-9]*(,[0-9]*)?\}`.
- **CI guards the confirm_regex C pass with one test that depends on the grep version.** The only
  test that killed the mutant that removes the C pass is the tr_TR one. It skips wherever no
  Turkish locale exists, and the Ubuntu CI runner has none. Run `locale-gen tr_TR.UTF-8` in the
  `mb-command-tests` job, or make that skip fatal under a flag, as `PMB_REQUIRE_PARITY` does for
  pwsh.
- **The 250-character `-C` figure is not pinned.** Assert in both suites that a 250-character path
  prompts and a 251-character path does not.
- **Only the opening words of the deny message are asserted.** Its remedy text is not (read).

## 3. False positives and wording

- **An OR-list across a newline is now BLOCKed on sh.** `command -v pwsh >/dev/null ||`, then a
  newline, then `bash scripts/fallback.sh` got no verdict on `main` and is BLOCK now. The ps1 hook
  already blocked it on `main`. Either list it next to the same-line `|| sh` accepted false
  positive in the standard, or exclude a preceding `|`. On the ps1 hook, `echo x |`, then a
  newline, then `IExpress` is also newly BLOCKed.
- **C-7: the docs said a BusyBox host "prompts". It is refused.** With BusyBox grep and no pwsh,
  the hook emits `permissionDecision: deny` for every Bash command, so the Bash tool is unusable
  until GNU grep or pwsh is installed.
  - `standards/SECURITY-GUARDRAILS.md` and `docs/HOOKS-GUIDE.md`, with their template copies:
    corrected 2026-10-14, as part of item 1's rewrite.
  - **Still open:** the `CHANGELOG.md` entry headed "The sh regex rows now prompt when `grep`
    fails." says "Alpine with bash but without pwsh every Bash command prompts".
  - **Still open:** no `mb doctor` or `mb upgrade` check probes for `grep -z` before `mb upgrade`
    force-installs the hook. Add one: `printf 'a\0' | grep -qz a`.
- **The standard's "Not covered" list reads as exhaustive.** It omits subshell, brace, `"$SHELL"`,
  `$'bash'` and `${X:-bash}` forms. These get no verdict on `main` either.
- **`standards/SECURITY-GUARDRAILS.md:160` says "counts characters in all three".** .NET counts
  UTF-16 code units, so an astral character counts as 2 (read).
- **`standards/SECURITY-GUARDRAILS.md:139` misdates the bound change.** It says the bound was
  `{0,300}` "until 2026-09-30", but b76d08e, which lowered it, is dated 2026-10-03. The
  "(added 2026-09-30)" at `:152` is correct: it dates the bytes paragraph, which b5cfe33 added.
- **`CHANGELOG.md` still gives 295 for the `{0,300}` bound.** The entry that says "`{0,300}` bound
  admits is **295** characters" does not note that the final bound is 255,
  which allows a 250-character path.

## 4. The review gate burns markers on commands that never ran

This is [NS-24] Task #33, which is tracked under [NS-26]'s required port of the review gate. It
recurred twice on this branch on 2026-10-05:
- A `git commit` was denied by dangerous-commands because its heredoc message quoted guarded text.
  `scripts/review-reminders.sh` had already dropped the code-review marker before that denial.
- A `git push` lost the change-review marker even though git never ran: the output redirect
  failed first. The PUSH case drops the marker by design and declines to recover it.

Both times, the approving Opposition agent had to verify that nothing had changed and then rewrite
its own marker. The fix is for the gate to consume a marker only once the command has actually run.
