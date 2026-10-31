---
status: open
created: 2026-10-05
last-reviewed: 2026-10-19
staleness-threshold: 90d
related_plan: null
---

# dangerous-commands follow-ups after NS-38 / NS-40

This file lists the known gaps that the reviews of `fix/ns40-ns38-dangerous-commands` (PR #52)
recorded and did not fix. **Item 1 was the merge condition** that review set: the gap had to be
tracked before the PR merged. It is now fixed (see item 1). The other items never blocked the
merge and are still open unless marked.

**IDs.** `J2-1` and `C-7` are review-finding IDs the user supplied with the 2026-10-14 task. IDs
from the reviews of item 1's fix carry a prefix naming the review, because the same short ID recurs
across reviews: `R2/` and `R3/` are /code-review rounds 2 and 3 (2026-10-14), `CHR/` is the
/change-review that followed (so `CHR/J2-1` is not `J2-1`), `R4/` is the /code-review of the
follow-up commit (2026-10-15), `R5/` and `R6/` are the /code-reviews of the round-4 fixes and of
the merge of `main` (2026-10-16), and `CHR2/` is the /change-review of the whole branch that
followed (2026-10-16). Every ID carries its prefix. None of those reports is in this repo;
each finding is described in full where it appears.

**What decays here, and what to re-verify before relying on it:**
- **Where item 1's fix lives.** It was written on `claude/sweet-lovelace-b4d2dc` (2026-10-14) and
  its review follow-ups on `claude/dc-round3-followups` (2026-10-15 and 2026-10-16). Both merged as
  PR #64, squashed into `0e05a6b`, so neither branch is in `main`'s history: find the fix by the
  CHANGELOG entry headed "Without python3, the sh dangerous-commands hook missed".
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

**Fixed 2026-10-14, with review follow-ups on 2026-10-15 and 2026-10-16; merged as PR #64
(`0e05a6b`).** What was wrong, what changed and why are in `CHANGELOG.md`: the entry headed
"Without python3, the sh dangerous-commands hook missed" and the two after it, headed "`git merge`
followed by a newline got no CONFIRM" and "On Git Bash, a carriage return inside a word". The
per-round fix log that stood here, citing about 50 review findings it closed, was collapsed on
2026-10-19 (CHR2/S-1). It is the only record of which finding each closed ID was, and of `J2-1`
and the `R2/` and `R4/` IDs, none of which appears below any more: read it with `git show
0e05a6b:docs/backlog/dangerous-commands-follow-ups-after-ns38-ns40.md`.

**Still open from item 1:**
- **The merge row's trailing boundary is still narrow.** A bare `git merge` straight before `;`,
  `&&`, `|`, `>` or `)` gets no verdict on either shell, with python3 present (measured 2026-10-14:
  `git merge;echo hi`, `git merge&&echo hi`, `(git merge)`, `git merge|cat`, `git merge>log`). A
  shell ends the word at each of these. **Wider than that list (found 2026-10-19):** `git merge`
  straight before `<`, a single `&`, `${IFS}`, `$(…)` or a backtick gets no verdict either (measured
  on Git Bash with python3 present, both hooks). Git Bash splits the word at each of these too:
  `<` and `&` are metacharacters, while `${IFS}`, `$(…)` and a backtick are unquoted expansions,
  which split when their result starts with a blank (measured: `a${IFS}b`, `a$(printf " b")` and
  the backtick form each reach `printf "[%s]"` as two words). So widening the boundary to shell
  metacharacters is not enough on its own: the fix, in `confirm_boundary()` in
  `scripts/dangerous-commands.sh` and the `git merge` row of `scripts/dangerous-commands.ps1`,
  must also treat `$` and a backtick as a boundary.
- **The sh fallback decodes before the length bound, so its cost is unbounded by it**
  (`scripts/dangerous-commands.sh`). Measured by
  the Performance review: about 1.6 to 1.9 s per MB of escape-dense payload, linear, fallback
  only. A raw-size cap before decoding would bound it, but would also refuse some payloads that
  decode below the bound, so it is a behaviour change to decide on, not a fix to slip in.
- **Decision: should the dangerous-commands hook entries in `.claude/settings.json` (and
  `templates/.claude/settings.json`) set `"onFailure": "block"`?** Read in the
  Claude Code hooks reference on 2026-10-15: with no `timeout`, a command hook gets 600 s; a
  PreToolUse command hook that times out does not block the call (its output is discarded); and
  `"onFailure": "block"` (Claude Code v2.1.295 or later) blocks it instead, on a timeout, a hook
  that cannot start, an exit code other than 0 or 2, or invalid output. The measured worst cases,
  all at the 50 KB bound, are far inside 600 s, so no `timeout` was set: the ps1 hook 19 to 21 s
  on a CR-free command and about 29 s with one CR (one machine, 2026-10-15 and 2026-10-16). The
  sh hook's CR test is now linear and after the bound, so its cost no longer grows past it.
  Setting `onFailure` would make the guard fail closed fleet-wide and needs that Claude Code
  version on every adopter; note the `|| true` wiring already turns a crash into exit 0, so it
  would mostly change the timeout case. Not decided.
- **ps1's parsed path keeps a NUL that every other path drops** (`scripts/dangerous-commands.ps1`;
  `r`, NUL, `m -rf` gets no verdict there). Whether a harness can deliver a NUL to bash at all is
  unverified, so this may be moot. Related (R3/F1, Security): decoding `\u0000` to nothing can
  remove a boundary the old raw view had (`x`, NUL, `git config …` lost its CONFIRM on the
  fallback); PowerShell runs `x` there and Bash runs `xgit`, so only false positives were lost.
- **The Pester suite writes to the repo's `.pmb-hook-errors.log`** (CHR/J3-2). Every fallback case
  logs a parse failure to the cwd-relative log, and `mb doctor` Check 16 then WARNs. The helper in
  `tests/dangerous-commands.Tests.ps1` should run the hook from a temp directory. One worktree's
  log held 2,485 lines on 2026-10-15, and it grows with every run.
- **The python3-absent mode skips when its probe fails, not only when python3 cannot be hidden**
  (CHR/J4-2, `tests/test-dangerous-commands.sh`). A new tool dependency in the hook's early path
  would drop the whole mode locally instead of failing; CI sets `PMB_REQUIRE_PARITY=1` and would
  catch it.
- **The suites prove policy, not the platform facts it rests on** (CHR/J5-3). That Git Bash deletes
  a CR, and that the decoder behaves the same under gawk, mawk, BusyBox and macOS awk, were measured
  by hand; CI (`.github/workflows/pmb-health.yml`) runs Ubuntu only. macOS/BSD awk was never
  measured. The negative rows also pass if the hook crashes (CHR/J5-2); the positive rows in the
  same loop catch a dead hook.
- **An NBSP or U+2028 after `|` is BLOCK on ps1 and no verdict on sh**, on both paths. It predates
  this change: the `\s` in `scripts/dangerous-commands.ps1` is Unicode-aware, and the
  `[[:space:]]` in `scripts/dangerous-commands.sh` runs under `LC_ALL=C`.
- **On Git Bash, the sh hook's parsed path misses an astral-character gap in the signing rows**
  (`scripts/dangerous-commands.sh`). 140 emoji
  in a `git config --file` path get no verdict there under `C.UTF-8`, though grep 3.0 matches the
  same 140 characters against one bounded group (measured; cause not established). Linux (GNU grep
  3.11) prompts. The fallback prompts on both.
- **PowerShell splits words at separators the ps1 hook does not fold**
  (`scripts/dangerous-commands.ps1`). Its tokenizer breaks
  `git push`, then NBSP, VT or U+2028, then `--force` into separate words, and the ps1 hook gives
  no verdict on any of those through the PowerShell tool (measured by the round-2 Security
  review). It predates this change; the "NBSP is a non-boundary everywhere" rationale reasons only
  about bash.
- **Cross-shell cases go through two separate per-shell lists, not `assert_parity`.** The suite's
  own parity block (`assert_parity` in `tests/test-dangerous-commands.sh`) exists to catch a sh/ps1
  divergence on one payload; the parsed-path CR and newline-boundary cases could feed it, and
  nothing yet asserts the two hooks agree on their BLOCK and CONFIRM verdicts. **CHR2/C-1:** that
  matters most for the CR
  shapes, because "a Bash command gets the same verdict from either hook" is the stated outcome of
  the third view. It held on 33 CR shapes run through both hooks (0 divergences, 2026-10-16), but
  two hand-kept tables are all that hold it. Feed these through `assert_parity`, which CI
  enforces, with the verdict each got from both hooks (Git Bash and pwsh, python3 present,
  2026-10-19): `git push --for`, CR, `ce` and `curl x | ba`, CR, `sh` (block); `git merge`, CR,
  `ls` and `git`, space, CR, space, `merge main` (confirm). Keep the spaces in the last one:
  `git`, CR, `merge main` gets no verdict from either hook. The WARN-tier CR shape, `cat
  ~/.ssh/id_r`, CR, `sa`, is already pinned: `tests/test-hook-warn-output.sh` byte-compares both
  hooks' output on it (`P_CR`, `P_CR_TWO`) in its cross-shell parity block, which CI runs under
  `PMB_REQUIRE_PARITY=1`. `assert_parity` could not take it, since its `pass` arm asserts only
  that neither CONFIRM nor BLOCK fired; a WARN arm would be needed only for more WARN shapes.
- **The decoder's rules and the CR and newline rationale are restated in four to six places**
  (the comments in `scripts/dangerous-commands.sh` and `.ps1`, `standards/SECURITY-GUARDRAILS.md`,
  `CHANGELOG.md`, `tests/test-dangerous-commands.sh`, `tests/dangerous-commands.Tests.ps1`). One
  copy had already drifted in review. Pointing the others at the sh hook's comment would cut the
  copies.
- **The shipped standard names PMB's open "no external dependencies" question.**
  `standards/SECURITY-GUARDRAILS.md` ships to adopters, who never see PMB's decision and keep the
  "open" wording once it is settled. Track it in PMB's own memory bank instead.
- **The worst-case figures disagree across shipped files** (R5/COR5-1, R5/COR5-2, R5/P5-1,
  CHR2/M-1). For one quantity, the ps1 hook's cost on a ~50 KB command. **Partly done
  2026-10-30** by the SQA port re-cut, which re-measured with its structural rows: the sh hook's
  WHOLE-HOOK table now has CR cases; the standard's "Residual cost" paragraph says about 33 s with
  one CR and about 23 s without, and points at the table; `docs/HOOKS-GUIDE.md` (and its
  template) says about 33 seconds and points at the standard. Still open:
  - the `onFailure` decision above still quotes 19 to 21 s CR-free and about 29 s with one CR;
  - the standard and the guide state the figure as well as pointing at it; keep it in one place.

  Before the re-cut, the sh comment called `17.55s` "the real number to reason about", the
  standard said about 17.5 s then 21 s and 29 s in one paragraph, and the guide said "under 30
  seconds". Five measured runs of the gated code with one CR took 27.2, 29.0, 30.8, 30.9 and
  34.3 s on one machine (R4 and R5, 2026-10-15 and 2026-10-16), so "under 30" was false for three
  of them, and the "about 29" in the standard, the CHANGELOG and the `onFailure` decision above
  quoted one round. One CR-free run took 22.2 s, outside "19 to 21 s".
- **R5/COR5-4:** the comment above the 400K timing row in `tests/test-dangerous-commands.sh` says
  that row stays green on a quadratic CR test placed after the bound because the difference is
  "under about a second". The figure is low: round-4 measurements of that expansion alone at 50K
  characters were 0.35, 1.16 and 1.2 s. The comment also leaves the main reason implicit: the 400K
  row stops at the length bound (`DC_MAX_CMD` in `scripts/dangerous-commands.sh`), so it never
  reaches code after the bound at any cost; the sub-second figure only explains why a row under
  the bound would not catch the mutant either. The 400K whole-hook figure is 47 s in that comment
  and was 51 s in round 4 (the fix log at `0e05a6b`).
- **A duplicated WARN on a CR-bearing escaped filename would ship green** (R6/T6-2, Medium).
  Deleting the `return` in the sh `warn()` arm for the de-escaped view makes `cat ~/.ssh/id\_rsa
  x`, CR, `y` emit the WARN twice in both `systemMessage` and the model-facing text, and every
  suite stays green: the one-notice count test feeds only CR-free commands, so the CR-deleted
  view is empty and that `return` is never needed. Add that command to the count loop in
  `tests/test-dangerous-commands.sh` and to the parity payloads in
  `tests/test-hook-warn-output.sh`; either kills the mutant.
- **The fallback decoder replaced the raw view instead of adding one** (R6/SEC-1). On malformed
  JSON only, `main`'s raw fallback matched shapes the decoder now misses: `git push --forc""e`,
  and a token split by an escaped backslash then a quote. Valid JSON always puts `:` or `,` between
  string delimiters, and Claude Code does not emit those payloads; the valid-JSON losses (a form
  feed or line feed inside a word) were false positives. It is still the one place the "views only
  add matches" rule does not hold. Accept it and say so in the fallback comment in
  `scripts/dangerous-commands.sh`, or keep the raw
  payload as an extra view on the fallback path.
- **R5/COR5-6:** the accepted false positive in `standards/SECURITY-GUARDRAILS.md` (and its
  template), "`git merge`, CR, then another word", is too broad. Only a CR followed directly by a
  character that continues the word is a false positive (Git Bash deletes the CR, so `git merge`,
  CR, `ls` runs `git mergels`). A CR followed by a space, a tab, a newline, the end, or a shell
  separator such as `;`, `&&` or `|` is a true positive, because Git Bash still splits or
  separates there and runs a bare merge (measured 2026-10-19 on Git Bash; both hooks CONFIRM each
  of these). The merge-row comments in both hooks (`confirm_boundary()` in
  `scripts/dangerous-commands.sh`, the `git merge` row in `scripts/dangerous-commands.ps1`) need
  the same fix: they list only a space, a newline or the end as true positives, and the sh comment
  says the CR arm decides a verdict alone "only when another character follows the CR". Before
  `;`, `&&` or `|` it decides alone too, because the CR-deleted view gives `git merge;…`, the
  narrow-boundary gap in the first entry above. The standard also names `mergels` without
  introducing `ls`. **Not yet the right class (found 2026-10-19):** "a character that continues
  the word" still misfiles `$` and a backtick. A CR followed by `${IFS}ls` or by a backtick
  expansion is a true positive, because the expansion splits the word (see the first entry above),
  and both hooks CONFIRM these today only because their CR arm fires whatever follows the CR
  (measured on Git Bash, both hooks). Settle the class against the first entry's boundary set
  before writing it into the standard or the hook comments; do not copy this entry's wording.
- **Smaller test and wording gaps:**
  - R6/T6-1, R6/C-2: the comment above the one-WARNING count test in
    `tests/test-dangerous-commands.sh` says `warn()` has "two case arms" that return "after
    printing". It has three, and each records.
  - R6/T6-3: the CR-only WARN rows in `tests/test-hook-warn-output.sh` assert `systemMessage` and
    the keys but not `additionalContext`, so a dropped `dc_warn_list` is caught only by the parity
    block, which does not run without pwsh.
  - CHR2/A-1, first found as CHR/J3-1: the deny message and the `dc_grep` comment in
    `scripts/dangerous-commands.sh`, `docs/HOOKS-GUIDE.md` and `CHANGELOG.md` point at the
    standard's bold "Platform requirement (sh hook)" label, and no test pins it. It matters to
    adopters because the two files update differently: `scripts/mb.sh` upgrade overwrites the
    hooks (TEMPLATE_OWNED) but only creates `standards/SECURITY-GUARDRAILS.md` when it is missing
    (ADVISORY_CREATE); when the file exists and differs, it prints a diff and asks for a manual
    review. So an adopter with an older standard gets the new deny message pointing at a label
    their copy lacks. `scripts/mb.ps1` overwrites both, so the gap is on the sh upgrade path.
  - CHR2/M-1: `docs/HOOKS-GUIDE.md` says "folding the two subjects once" costs two subshells,
    "three when the command holds a carriage return"; with the CR-deleted view there are three
    subjects.
- **The two timing tests may guard only on Git Bash** (CHR2/T-1, R5/COR5-5), both in
  `tests/test-dangerous-commands.sh`. The decoder's quadratic `gsub` was measured on Git Bash's
  gawk; the mawk tried on Ubuntu showed no such cost, and CI installs no gawk, so that guard likely
  cannot fail there. The 400K row calls `invoke_hook`, so with python3 present (CI included) it
  times only the parsed path, never the fallback. The mutant it guards, a quadratic CR test before
  the bound, was measured on Git Bash only: whether that row can fail on Linux is unmeasured, not
  shown to be local-only. Both print SKIPPED without `EPOCHREALTIME`, and `PMB_REQUIRE_PARITY`
  does not make that fatal. Measure both mutants on the CI runner's awk and bash (and on gawk)
  before stating either test as local-only or installing gawk in CI; then make the skip fatal
  under the flag.

## 2. Tests that do not discriminate, or never run in CI

- **The no-space pipe forms are not pinned.** Neither suite (`tests/test-dangerous-commands.sh`,
  `tests/dangerous-commands.Tests.ps1`) tests `|bash` or `|sh`, or a same-line
  `| sh` on the sh hook, or `|bash` / `|sh` on the ps1 hook. A mutation from `[[:space:]]*` to
  `[[:space:]]+` (or `\s*` to `\s+`) stays green.
- **The bound guard misses `{,n}`.** `tests/test-dangerous-commands.sh:757-766` extracts
  `\{[0-9]+(,[0-9]*)?\}`, so `{,300}` passes the guard, yet GNU `grep -E` treats `{,300}` as a
  bound. Widen the pattern to `\{[0-9]*(,[0-9]*)?\}`.
- **CI guards the confirm_regex C pass with one test that depends on the grep version.** The only
  test that killed the mutant that removes the C pass is the tr_TR one. It skips wherever no
  Turkish locale exists, and the Ubuntu CI runner has none. Run `locale-gen tr_TR.UTF-8` in the
  `mb-command-tests` job of `.github/workflows/pmb-health.yml`, or make that skip fatal under a
  flag, as `PMB_REQUIRE_PARITY` does for pwsh.
- **The 250-character `-C` figure is not pinned.** Assert in both suites
  (`tests/test-dangerous-commands.sh`, `tests/dangerous-commands.Tests.ps1`) that a 250-character
  path prompts and a 251-character path does not.
- **Only the opening words of the deny message are asserted.** Its remedy text, in
  `scripts/dangerous-commands.sh`, is not (read).

## 3. False positives and wording

- **An OR-list across a newline is now BLOCKed on sh.** `command -v pwsh >/dev/null ||`, then a
  newline, then `bash scripts/fallback.sh` got no verdict on `main` and is BLOCK now. The ps1 hook
  already blocked it on `main`. Either list it next to the same-line `|| sh` accepted false
  positive in `standards/SECURITY-GUARDRAILS.md`, or exclude a preceding `|`. On the ps1 hook,
  `echo x |`, then a newline, then `IExpress` is also newly BLOCKed.
- **C-7: the docs said a BusyBox host "prompts". It is refused.** With BusyBox grep and no pwsh,
  the hook emits `permissionDecision: deny` for every Bash command, so the Bash tool is unusable
  until GNU grep or pwsh is installed.
  - `standards/SECURITY-GUARDRAILS.md` and `docs/HOOKS-GUIDE.md`, with their template copies:
    corrected 2026-10-14, as part of item 1's rewrite.
  - `CHANGELOG.md`, the entry headed "The sh regex rows now prompt when `grep` fails.": corrected
    2026-10-15 to say every Bash command is refused. Its heading still says "prompt", which is
    right for the one failing grep it describes.
  - **Still open:** no `mb doctor` or `mb upgrade` check probes for `grep -z` before `mb upgrade`
    force-installs the hook. Add one: `printf 'a\0' | grep -qz a`.
- **The "Not covered" list in `standards/SECURITY-GUARDRAILS.md` reads as exhaustive.** It omits
  subshell, brace, `"$SHELL"`, `$'bash'` and `${X:-bash}` forms. These get no verdict on `main`
  either.
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
