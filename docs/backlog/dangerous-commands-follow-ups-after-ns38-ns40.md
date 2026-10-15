---
status: open
created: 2026-10-05
last-reviewed: 2026-10-05
staleness-threshold: 90d
related_plan: null
---

# dangerous-commands follow-ups after NS-38 / NS-40

This file lists the known gaps that the reviews of `fix/ns40-ns38-dangerous-commands` (PR #52)
recorded and did not fix. **Item 1 is the merge condition** that review set: the gap had to be
tracked before the PR merges, and this file is that tracking. The other items do not block the
merge.

**What decays here, and what to re-verify before relying on it:**
- **Line numbers** are from `ab2dbfe` and drift with any edit.
- **Measured claims** name the grep build and host they ran on. Re-measure before relying on one
  for a different build. Everything in item 1 was measured. Items 2 and 3 were measured unless
  they say "read". Item 4 records session events and cannot be re-checked from the tree.

## 1. If python3 is missing or fails, the sh hook matches the raw JSON payload

- `scripts/dangerous-commands.sh:94-109` extracts `tool_input.command` with python3 and keeps it
  only when python3 succeeds. Otherwise `cmd` stays the raw stdin JSON. That happens on **every**
  command when python3 is absent, not only when the JSON is malformed.
- Raw JSON escapes whitespace: a newline becomes the two characters `\n`, and a tab becomes `\t`.
  So no row that needs real whitespace other than a space can match. In Docker, with python3
  absent, these all got no verdict (python:3.12-slim with python3 off PATH; Alpine 3.24 with bash
  and GNU grep 3.12). With python3 present they are BLOCK or CONFIRM:
  - a pipe to `bash` split across a newline;
  - `curl x |`, then a tab, then `bash`, on one line;
  - `git config commit.gpgsign` with a backslash-newline before `false`;
  - `git config commit.gpgsign`, then a tab, then `false`.
- This predates the branch: `main` without python3 gives no verdict on these too. But the branch's
  new newline-pipe BLOCK row does nothing without python3, and Alpine ships without it.
- **Texts that are wrong about this.** Each has a byte-identical copy under `templates/`.
  - Fixed 2026-10-15 on `feat/port-sqa-dangerous-commands`: the fallback comments in
    `scripts/dangerous-commands.sh` and `.ps1` said raw matching "never misses a true positive",
    and the ps1 one called its fallback identical to the sh one's. Both now say a JSON-escaped
    separator can be missed, and the ps1 one notes that only the sh hook falls back when python3
    is missing.
  - `standards/SECURITY-GUARDRAILS.md:242-243` gives only "the JSON cannot be parsed" as the
    trigger.
- **Every statement of the remedy leaves python3 out.** Each review round found a new incomplete
  restatement of this remedy, because it lives in several places:
  - the deny message at `scripts/dangerous-commands.sh:429`, which says "Install GNU grep or
    PowerShell";
  - `docs/HOOKS-GUIDE.md:98-99` and its template copy;
  - `standards/SECURITY-GUARDRAILS.md:251-252`;
  - `CHANGELOG.md:41-45`.
- **Fix outline.**
  - State the whole sh-hook requirement once, in the standard's "Platform requirement (sh hook)"
    bullet: pwsh, **or** bash plus a grep that supports `-z` plus python3.
  - Point every other copy at that bullet instead of restating it.
  - Either decode JSON escapes (`\n`, `\t`) in the raw fallback before matching, or document the
    misses.
  - Add a test that runs the hook with python3 off PATH, with newline and tab cases.

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
- **The docs say a BusyBox host "prompts". It is denied.** With BusyBox grep and no pwsh, the hook
  emits `permissionDecision: deny` for every Bash command, so the Bash tool is unusable until GNU
  grep or pwsh is installed. The wording is at `CHANGELOG.md:43`,
  `standards/SECURITY-GUARDRAILS.md:249` and `docs/HOOKS-GUIDE.md:97`, plus the template copies.
  No `mb doctor` or `mb upgrade` check probes for `grep -z` before `mb upgrade` force-installs the
  hook. Add one: `printf 'a\0' | grep -qz a`.
- **The standard's "Not covered" list reads as exhaustive.** It omits subshell, brace, `"$SHELL"`,
  `$'bash'` and `${X:-bash}` forms. These get no verdict on `main` either.
- **`standards/SECURITY-GUARDRAILS.md:160` says "counts characters in all three".** .NET counts
  UTF-16 code units, so an astral character counts as 2 (read).
- **`standards/SECURITY-GUARDRAILS.md:139` misdates the bound change.** It says the bound was
  `{0,300}` "until 2026-09-30", but b76d08e, which lowered it, is dated 2026-10-03. The
  "(added 2026-09-30)" at `:152` is correct: it dates the bytes paragraph, which b5cfe33 added.
- **`CHANGELOG.md:565-566` still gives 295 for the `{0,300}` bound.** It does not note that the
  final bound is 255, which allows a 250-character path.

## 4. The review gate burns markers on commands that never ran

This is [NS-24] Task #33, which is tracked under [NS-26]'s required port of the review gate. It
recurred twice on this branch on 2026-10-05:
- A `git commit` was denied by dangerous-commands because its heredoc message quoted guarded text.
  `scripts/review-reminders.sh` had already dropped the code-review marker before that denial.
- A `git push` lost the change-review marker even though git never ran: the output redirect
  failed first. The PUSH case drops the marker by design and declines to recover it.

Both times, the approving Opposition agent had to verify that nothing had changed and then rewrite
its own marker. The fix is for the gate to consume a marker only once the command has actually run.
