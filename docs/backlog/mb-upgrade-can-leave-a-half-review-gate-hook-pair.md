---
status: open
created: 2026-09-26
last-reviewed: 2026-09-27
staleness-threshold: 90d
related_plan: null
---

# mb upgrade can leave a half review-gate hook pair (non-atomic, skip-on-missing-source)

**Measured 2026-09-26 against `origin/main` at `739f0eb`.** The review-gate hook scripts depend on
two dot-sourced companions per shell. Nothing declares that dependency to `mb upgrade`, and three
separate paths can leave one half installed. Both `mb` implementations detect the half state in
`mb doctor`, but `mb upgrade` itself never checks for it.

**Correction, 2026-09-26 (step-00 `/code-review`, before first commit):** the first draft of this
item said the pair check existed only in `mb.ps1`, and proposed porting it to `mb.sh`. That was
false. The evidence was `git show origin/main:scripts/mb.sh | grep -c "hook pair is incomplete"`
returning `0`; the strings live in a separate script `mb.sh` calls, so a grep of `mb.sh` alone
could not establish the check's absence. The detection section below is the corrected picture.

**What decays here, and what to re-verify before relying on it:**
- **Line numbers** were read from `origin/main:scripts/mb.sh`, `:scripts/mb.ps1` and the other
  cited files at `739f0eb`. Read the blob, not a working tree, when re-checking.
- **Measured vs read:** paths 1 and 3 were reproduced in a scratch copy (2026-09-26); path 2
  and `mb.ps1`'s upgrade path are read from the code only. See "Not established".

## The dependency that is not declared

Each `review-reminders` twin reaches two companions, by two different mechanisms.
`scripts/review-reminders.sh` **pipes** a payload to `_review-gate-classify.py` (`:120`, guarded by a
`[ -f … ]` test at `:119`) and **dot-sources** `_review-gate-lib.sh` (`:177`).
`scripts/review-reminders.ps1` dot-sources `_review-gate-classify.ps1` (`:68`) and
`_review-gate-lib.ps1` (`:98`). All eight files — the four `review-reminders{,-post}.{sh,ps1}` and
their four companions — are flat, independent entries in `TEMPLATE_OWNED`
(`scripts/mb.sh:2095` opens the array; the companions are at `:2126-2129`). Nothing in the array or
the copy loop expresses "this target requires that target", so no mechanism can refuse a half set.

## Three ways the half state can arise

1. **A missing template source degrades to skip-and-continue.** The `TEMPLATE_OWNED` loop
   (`scripts/mb.sh:2253-2278`) starts with:

   ```
   if [ ! -f "$src" ]; then
       echo -e "${YELLOW}[?] $target (template-owned source missing — skipped)${NC}"
       continue
   fi
   ```

   So upgrading from a PMB tree that is missing `templates/scripts/_review-gate-classify.py` installs
   `review-reminders.sh` and skips its companion, printing one yellow advisory line inside a long
   per-file report, then continues and completes. **This is the path that matters**, because
   upgrading from an incomplete tree is a thing that happens — see "Why this is not hypothetical".
2. **An interrupted or failing copy leaves a partial set with no rollback.** `set -e` is active
   (`scripts/mb.sh:21`) and the loop is a bare per-file `cp`. A permission error, a full disk or a
   Ctrl-C part-way through aborts with whatever was already copied in place. There is no staging
   directory, no transaction and no cleanup path.
3. **`mb init` uses `copy_if_new` for the same list** (`scripts/mb.sh:696-709`), so a pre-existing
   file is skipped rather than completed. With a missing source it does not converge either:
   `copy_if_new`'s bare `cp` (`:669`) aborts `mb init` under `set -e` with rc=1, leaving
   `review-reminders.*` installed and both classifiers absent (reproduced 2026-09-26 in a scratch
   copy). The set is handled file-at-a-time everywhere, not as a unit.

A *completed* `mb upgrade` does converge the set — every `TEMPLATE_OWNED` target missing or stale is
force-copied — so the steady state is fine. The exposure is entirely in the failure and
incomplete-source paths.

## Detection: both `mb doctor`s see it, `mb upgrade` does not

- **Bash.** `mb doctor` runs the shared `scripts/check-review-gate-lib-presence.sh` against
  `scripts/` (relative to the current directory) at `scripts/mb.sh:954`. Its four checks
  (`:26-41`) print one `ERROR` line per missing companion; `mb.sh:955-961` turns any output into
  `[ERROR]` lines and sets `FATAL_FOUND`, and `mb.sh:1823` returns non-zero. The checker's header
  explains why it is hardcoded rather than derived from `settings.json`: the companions are
  dot-sourced and never appear in a `"command":` string.
- **PowerShell.** `mb.ps1` inlines the same four checks (`:1252-1271`), each setting
  `$fatalFound`, which exits 1 at `:2135-2136`. Its own comment (`:1249`) names the shared script as
  `mb.sh`'s equivalent.
- **CI and tests** run the checker too: `.github/workflows/pmb-health.yml:628` against
  `templates/scripts`, and `tests/run.sh:31` runs `tests/test-review-gate-lib-presence.sh`.

The real residual gaps:

- **`mb upgrade` never runs the checker.** The only call site is `scripts/mb.sh:954`, in
  `mb doctor`. A half state from path 1 or 2 surfaces only if someone runs `mb doctor` afterwards.
- **Both twins run the check only when `.claude/settings.json` exists** — it sits inside the
  hooks section's `if [ -f ".claude/settings.json" ]` block (`scripts/mb.sh:920` → `:954`, and the
  equivalent block in `mb.ps1`). Inferred from the block structure; not exercised.
- **`mb.ps1` duplicates the checker's logic inline** instead of calling it, which is the drift the
  checker's own header ("WHY one shared script") exists to prevent. The strings match today.
- **The checker is blind to the reverse split** — a `review-reminders*` script absent while
  `settings.json` wires it — and so is `mb doctor` when only one twin is gone: its hook-script
  check passes a name if any `<name>.*` exists (`mb.sh:940`, `mb.ps1:1235`), so it prints
  `[OK] Hook scripts present` (reproduced 2026-09-26 with `mb.sh`, scratch copy, `review-reminders.ps1`
  absent) and warns (`mb.sh:951`) only when both twins are absent. A missing
  `review-reminders.ps1` leaves the PowerShell tool ungated (`templates/.claude/settings.json:62`,
  `… || true`). Path 1 produces exactly this one-file gap for an adopter with no earlier copy.
  Item 1 does not detect it; items 3-4 do if the declared set includes the hook scripts and
  `settings.json`.

## What actually degrades, per file — the severity is not uniform

Worth stating because the `mb doctor` wording ("can bypass classification") reads as fail-open, and
for one of the two files it is the opposite:

- **A missing `_review-gate-lib.*` fails CLOSED on both pre-hook twins.** `review-reminders.ps1:98`
  dot-sources it in a try/catch whose catch calls `Deny`; `review-reminders.sh:177` wraps the
  dot-source in `if ! . … ; then deny "… This is a broken installation, not a passed review …"`.
  The post hooks fail open by design (`review-reminders-post.sh:16` `|| exit 0`;
  `review-reminders-post.ps1:14-25`, `catch { exit 0 }`). That is harmless here: the lib is missing
  for both, and the pre hook denies before any commit exists for the post hook to see.
- **A missing `_review-gate-classify.*` fails NARROWER, not open.** `classify_payload()` guards on
  `[ -f … ]` (`scripts/review-reminders.sh:119-120`) and returns non-zero, so the raw-substring
  fallback runs (`:152-156`) and still denies plain `git commit`, `git push` and `gh pr merge`. What
  is lost is the structural forms — which is what the `mb doctor` message says, and no more.

So of the four `mb doctor` `[ERROR]`s, the two about `_review-gate-lib.*` describe a repository that
refuses all guarded commands, and the two about `_review-gate-classify.*` describe reduced coverage.
Neither is a fully open gate. That distinction should survive into whatever wording the fix uses,
because "can bypass classification" has already been read once as fail-open.

## Why this is not hypothetical

An adopter repository (Side Quest Atlas) ran `mb upgrade` against a mid-PR PMB tree, reviewed the
output, found blocking defects and its user held the commit. A worktree there then reported all four
`mb doctor` `[ERROR]`s, relayed 2026-09-25/26. **That specific case was a hand-split** — an earlier
commit landed `review-reminders.*` while the companions stayed in the held batch — so it does *not*
demonstrate path 1. It demonstrates that half states occur in the field, and that `mb doctor`
catches them; the bash twin would have reported the same four errors.

Related and probably the same root cause: `git ls-remote --tags origin` shows only `v1.0.1` and
`v1.0.4`, so the decided tagged-release policy has never cut a tag and `mb upgrade` still sources
adopters from a moving `main`. An adopter upgrading mid-PR is the normal case, not an edge case.

## Not established

- **Path 2 was not reproduced.** Path 1 was, once (2026-09-26, scratch copy): a real `mb upgrade`
  exited 0 with one yellow skip line and left `review-reminders.sh` without its classifier.
- **Whether `mb.ps1`'s upgrade path has the same three exposures.** Its `TEMPLATE_OWNED` loop has the
  same skip-and-continue (`scripts/mb.ps1:2525-2527`, read, not run); paths 2 and 3 there are unchecked.

## Fix outline

This touches the upgrade path and a review-gate health check, so it needs a spec, a task contract and
a full `/code-review` and `/change-review`.

1. **Run the checker at the end of `mb upgrade`** in both twins, and exit non-zero on a gap. This is
   the cheap version of item 5's "detect and report" option, and it closes the upgrade-time gap for
   the companions. Do **not** port the checks into `mb.sh` — it already runs them. Gating it on
   `.claude/settings.json` like `mb doctor` buys nothing: the checker already self-gates — each check
   fires only when a `review-reminders*` file is present (`:26-41`) — and exits 0 on a repo with none.
   `mb.ps1` has no callable checker today (its four checks are inline in `mb doctor`, `:1252-1271`),
   so its half means extracting them into a function both commands call — item 2's twinned option.
2. **Keep `mb.ps1`'s inline checks in step with the shared script** — either a parity test in the
   style of `tests/test-threshold-parity.sh`, or have `mb.ps1` call a shared or twinned checker. A
   literal-extraction test like that one can compare file names and messages, not logic; a
   behavioural test would drive both from one fixture directory and compare exit codes and output.
3. **Declare the dependency.** Give `TEMPLATE_OWNED` a way to express "these targets install or fail
   together", then make the copy loop honour it.
4. **Make a missing template source fatal for a dependent set**, rather than a yellow skip. A missing
   source for a security-relevant hook is a broken release, not an advisory.
5. **Decide the atomicity policy for `mb upgrade`.** Either stage to a temp directory and move into
   place only once every target in a set has copied, or detect and report the partial state (item 1).
6. Mirror to `templates/` and add a CHANGELOG note. Verify `mb.ps1`'s upgrade path against items 3-5.

## Done when

- `mb upgrade` in both twins fails with a non-zero exit when it leaves a half pair (item 1), shown by
  a test that copies `templates/` into a scratch directory, removes one companion there, and sets
  `MB_HOME` to that scratch directory (the one *containing* `templates/`: `mb.sh:39,2075`,
  `mb.ps1:49,63`) — never the real tree, which every current `tests/test-mb-upgrade.sh` call uses.
  Assert the companion's `ERROR` line, not only the exit code: a wrong `MB_HOME` also exits 1, so an
  exit-code-only test passes before the fix. The test must fail on unmodified code; and
- items 3-5 are either implemented or explicitly declined in the spec, with the reason recorded.

## Related

`docs/backlog/merge-gate-misses-gh-global-flags-graphql-and-powe.md` owns which merge forms escape
the classifier when it *is* installed; this item is about the classifier being absent. `[NS-19]`
(template drift) is a different failure — the adopter's report conflated the two. `[NS-50]`(a) is the
precedent for per-file ownership classes.
