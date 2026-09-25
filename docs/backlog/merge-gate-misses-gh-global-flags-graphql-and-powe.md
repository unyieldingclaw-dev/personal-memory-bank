---
status: open
created: 2026-09-22
last-reviewed: 2026-09-22
staleness-threshold: 90d
related_plan: null
---

# Merge gate misses flag-prefixed, GraphQL and wrapped gh merges

**This is a security gap, measured on 2026-09-22 at `ac63ccb`.** It existed before this item and is
not fixed. The rule "this agent never merges pull requests" is enforced only for commands that the
review-gate classifier labels MERGE, and several ways of asking `gh` to merge are not labelled that
way. (The file name keeps the slug it was created with, which named only part of the class.)

**What decays here, and what to re-verify before relying on it:**
- **Line numbers** were checked at `ac63ccb` and drift with any edit.
- **Machine-local, untracked configuration**, which has no history to diff against.
- **Version-gated tool behaviour**: measurements were taken with the `gh` and Claude Code versions
  installed on one machine on 2026-09-22.
- **Deliberately not in this public repo:** the GraphQL mutation name, the REST endpoint paths, and
  the local allow rule's exact shape and location — the three details that would make this file a
  ready-made bypass recipe. The *command shapes* are stated here — most of the table's rows can be
  reconstructed from this file alone; two tokens are printed in the table rows themselves and the
  rest are named elsewhere in the file. What is held back is the API and configuration detail, not
  the shapes. The specifics are in
  `C:/Users/Mizzo/Claude/pmb-session-artifacts/2026-09-22/merge-gate-probe/REDACTED-SPECIFICS.md`,
  beside the probe scripts and their recorded output.
  **That directory is the sole record of those specifics** — it is untracked by any repository, so
  if it is lost or cleaned they are gone, and nothing here preserves them. This follows the
  2026-09-11 precedent (`memory-bank/progress.md:264`) of preserving non-committable material in
  that same untracked tree — the mechanism is the same, the reason is not: there it was review
  cost, here it is disclosure risk.

## What was measured

Synthetic `PreToolUse` payloads were fed on stdin to the four hooks that serve the `Bash` and
`PowerShell` matchers: `review-reminders.ps1`, `review-reminders.sh`, `dangerous-commands.ps1` and
`dangerous-commands.sh`. (`.claude/settings.json` wires ten `PreToolUse` scripts in total; the other
six serve `Write|Edit` and `Agent`.) Each form ran under both tool names. Nothing was executed and
no merge was attempted.

| Form | review-reminders | dangerous-commands |
|---|---|---|
| `gh pr merge <N>` (control) | deny, both twins | no decision |
| `gh api` against the REST merge path for a PR (control) | deny, both twins | no decision |
| A repo flag (`-R`/`--repo`) placed **before** `pr merge` | no decision, both twins | no decision |
| Another flag that `gh pr merge` owns, before the subcommand | no decision, both twins | no decision |
| A flag it does **not** own, before the subcommand (gh refuses this one itself) | no decision, both twins | no decision |
| The subcommand in another letter case (`PR MERGE`, `Pr Merge`) | **`.sh` no decision; `.ps1` denies** | no decision; gh rejects the variant |
| A `gh api graphql` call carrying the merge mutation | no decision, both twins | no decision |
| A PowerShell string-evaluation wrapper around a `gh pr merge` | no decision, both twins | no decision |
| The same, via the short alias | no decision, both twins | no decision |
| A process-launcher call with the merge in its argument list | no decision, both twins | no decision |

- **"No decision"** means empty stdout with exit 0. The call then goes on to the normal permission
  flow, which is not the same as being allowed (see below).
- **The case variant splits the classifiers, but is not a working merge route.** PowerShell's
  `-match` ignores case, so `.ps1` denies it; the Python classifier is case-sensitive, so `.sh`
  makes no decision. On gh 2.92.0, `gh PR list`, `gh Pr list` and `gh pr LIST` all exit with
  `unknown command`. This is a parity and test-topology gap in synthetic hook input, not evidence
  that an adopter without pwsh can merge using a mixed-case subcommand.
- **The classifier's match breaks for *any* flag-shaped token before the subcommand.** That is the
  part that matters here, it is what the table records, and it has reproduced in every probe run.
  Whether gh would then *run* the command is a separate question, and a treacherous one — see
  below.
- **Which flag-prefixed forms gh actually accepts: measurements only.** **Three** general rules
  about gh's argument parsing were written into this bullet across review rounds, and **all three
  were wrong** — each one looked settled until the next round's measurement broke it. No rule is
  stated here now. What follows is the raw results; the spec should measure any case it depends on
  rather than extrapolating from these. All on gh 2.92.0, read-only subcommands, no merge attempted.

  | Invocation | Result |
  |---|---|
  | `gh --host github.com config list` | runs |
  | `gh --json number pr list -L 1` | runs |
  | `gh --json=number pr list -L 1` | runs |
  | `gh -R cli/cli pr list -L 1` | runs |
  | `gh --repo cli/cli pr list -L 1` | runs |
  | `gh --draft=true pr list -L 1` | runs |
  | `gh --draft pr list -L 1` | `unknown command "list" for "gh"` |
  | `gh --subject x config list` | `unknown flag: --subject` |
  | `gh --subject x pr list -L 1` | `unknown flag: --subject` |
  | `gh --match-head-commit deadbeef pr list -L 1` | `unknown flag: --match-head-commit` |
  | `gh --squash config list` | `unknown command "list" for "gh"` |
  | `gh --squash pr list -L 1` | `unknown command "list" for "gh"` |
  | `gh --squash=true pr list -L 1` | `unknown flag: --squash`, `Usage: gh pr list` |
  | `gh --admin` / `--auto` / `--delete-branch` / `--merge`, before `pr list -L 1` | `unknown command "list"`, each time |

  - **One observation that the fix depends on, so it is stated narrowly.** Compare the last three
    rows: `--squash pr list` reports `unknown command "list"`, meaning `pr` was consumed as if it
    were the flag's value, while `--squash=true pr list` reports `unknown flag` against
    `gh pr list`, meaning the subcommand resolved. A token carrying its value inline after `=` does
    not consume the token after it; a bare flag-shaped token can. `--draft` shows the same split on
    a flag the subcommand owns, where the `=` form runs and the bare form does not.
  - **This changes fix step 1.** "Skip any flag-shaped token *and its value*", implemented as
    skip-flag-plus-next-token, would consume `pr` out of `gh --squash=true pr merge 45` and miss
    the merge — reintroducing the gap step 1 exists to close. Step 1 is worded accordingly below.
  - Which flag-prefixed spellings `gh pr merge` itself would accept was **not** established. It
    cannot be without performing a merge. Treat it as an open question for the spec.
- **Harness trap.** On Windows, launching bare `bash` from Python's `subprocess` resolves to WSL's
  `System32\bash.exe`, not Git Bash. Every `.sh` hook then exits 1 with empty stdout and a WSL error
  on stderr. That is a failure to run, not a "no decision" (which is exit 0), and it is easy to
  misread as a result. Launch Git Bash by its full path.

## Why they get through

- **Both classifiers look for the subcommand at the first token after `gh`.** Anything before it
  breaks the match.
  - `scripts/_review-gate-classify.py:303` matches `^pr\s+merge` case-sensitively, on the bash path.
  - `scripts/_review-gate-classify.ps1:138` matches the same shape, but case-insensitively, on the
    pwsh path (`review-reminders.ps1:68` dot-sources it).
- **Only the REST merge path is matched** (`.py:305`, `.ps1:139`). The GraphQL route is not.
- **Neither classifier unwraps PowerShell string-evaluation or process-launch wrappers.**
- **The raw-text fallbacks** (`review-reminders.sh:154`, `.ps1:81`) run when the classifier does not
  return a verdict at all — `python3` missing, the classifier file missing, or malformed JSON
  (`review-reminders.sh:126-127`, `.ps1:74-85`). A confident but wrong NONE never reaches them.
- **`dangerous-commands` handles a local `git merge`, not a PR merge.** Its comment at
  `scripts/dangerous-commands.sh:655` says `gh pr merge` is "already denied elsewhere".

## Reach

- **Every adopter has the same gap.** Both classifiers are byte-identical to their
  `templates/scripts/` twins (`cmp`), and both are TEMPLATE_OWNED (the array at `scripts/mb.sh:2095`
  includes them at `:2128-2129`), so `mb upgrade` ships the gap to every adopter.
- **No test covers any of these forms.** The tests do cover flags placed *after* the subcommand
  (`tests/test-review-reminders.sh:192,203` uses `--repo` there, and `tests/test_classify.py:68`
  covers `--squash`). Scope searched: `grep -rnE "gh +(-R|--repo)" tests/` and a search of `tests/`
  for the GraphQL route both returned nothing; a reviewer's search of `tests/gate_matrix.py`,
  `tests/review-gate-classifier.Tests.ps1`, `tests/test_classifier_coverage.py`,
  `tests/test_classify.py`, `tests/test-dangerous-commands.sh` and `tests/mutate.py` found only the
  canonical, REST and MULTI cases. `templates/` has no test tree at all (`find templates -iname
  "*test*"` returns one unrelated command doc). The wrapper forms are uncovered too:
  `grep -rn "Invoke-Expression" tests/`, `grep -rnw "iex" tests/` and `grep -rn "Start-Process"
  tests/` each returned nothing.
- **A note on searching for the wrapper names.** `dangerous-commands.ps1:253-256` denies a command
  whose text contains a pipe-adjacent spelling of the two PowerShell eval names — those four
  patterns cover `Invoke-Expression` and `iex` only, not `Start-Process`, which appears in no block
  or confirm pattern in either twin. A bash alternation pattern produces a pipe-adjacent spelling
  by accident, so a grep written that way is refused while the bare word is not, and the `.sh` twin
  has no such rule at all. Two reviewers hit the refusal and reported the words themselves as
  unsearchable; they are not.

## What actually stands in the way today

Per form and per mode, rather than one blanket answer:

- **Default mode:** these forms match no allow rule in the tracked `.claude/settings.json`, so they
  prompt — **unless a machine-local rule matches**, which for one form it does (next bullet).
- **Auto mode:** they reach the auto-mode classifier. It was observed denying `gh pr create` as
  "Modify Shared Resources" on 2026-09-22, and allowing `gh pr update-branch`. Neither matches an
  allow rule, so the classifier itself made both calls. (`git push` was allowed the same day, but it
  matches `Bash(git *)` in `.claude/settings.json`, so it probably never reached the classifier.)
  How the classifier is ordered against the repo hooks, and how it treats these merge forms, is
  unmeasured.
- **Where a local allow rule matches, nothing intervenes.** The **main checkout's** untracked local
  settings carry a broad `gh` allow rule wide enough to cover one of the *escaping* forms above (it
  matches two rows in all, but the other is a control the hooks already deny). Specifics are in the
  artifacts file rather than here.
  - **Which checkout matters.** Linked worktrees under `.claude/worktrees/` have no
    `settings.local.json` of their own, and the user-level settings have an empty allow list.
    Whether a worktree session resolves settings back to the main checkout is **unmeasured** — and
    most of this repo's work, including the session that wrote this item, runs in a worktree. So
    the scope of this exposure is not yet established.
  - That a match yields a silent run is reasoned from the docs, not measured, and the installed CLI
    is older than the documented behaviour.
- Plus the agent's own instruction never to merge, and a platform refusal whose existence is not
  established (see the companion item).

## Not established

- **Whether the auto-mode classifier or a platform refusal stops these forms.** Settling it needs a
  real merge attempt. Make one only with the user's authorization, and only against a throwaway
  repository they own.
- **Whether the local allow rule makes its matching form silent.** Measure it with a harmless call
  rather than a merge.
- **Other routes, measured at both classifiers but not through the hooks:** the REST branch-merge
  endpoint, and ordinary HTTP clients (`curl`, `Invoke-RestMethod`) aimed at either merge endpoint.
  All classify as not-a-merge, under both classifiers and both tool names; recorded in
  `classify-probe.out` in the artifacts directory. On `main`, branch protection
  (`enforce_admins: true`, `strict: true`, 9 required contexts,
  `required_approving_review_count: 0`, so a PR is required but an approving review is not) would
  likely refuse the branch-merge endpoint, but that is inferred.
  - **Why these four are in the clear, per setting** — an earlier draft of this note claimed all
    four were already publicly observable, and that was wrong. Measured 2026-09-22, unauthenticated:
    `GET /repos/{owner}/{repo}/branches/main/protection` returns `401 Requires authentication`, so
    `enforce_admins`, `strict` and the required-context list are **not** publicly readable. Exactly
    one of the four is: PR #45's reviews endpoint returns `[]` on a merged PR, showing a merge with
    zero approvals. The check-runs API does return check names on a public commit — 10 of them at
    `ac63ccb` — but *which* are required is not public, so the count 9 is a disclosure, not an
    observation, and publishing it alongside the public list reveals that one visible check is
    optional.
    - The three that are not observable are also not weaknesses. `enforce_admins: true` discloses a
      *closed* avenue — that an admin cannot override the checks — `strict: true` only says a
      branch must be current before merging, and a count of required checks discloses a strength.
      None helps an attacker; all are load-bearing for the inference above and for the `--admin`
      discussion in the companion item.
    - The one that is a weakness, `required_approving_review_count: 0`, is the one a reader can
      already confirm from the public PR history, so withholding it here would conceal nothing.

## Fix outline

This is an enforcement-boundary change. It needs an Opus escalation prompt, a spec or plan, a task
contract, and a full `/code-review` and `/change-review`.

1. In **both** classifiers, skip **any** flag-shaped token before matching the subcommand, rather
   than enumerating gh's flags. **Skip a following value token only when the flag does not already
   carry one inline after `=`** — otherwise `gh --squash=true pr merge 45` loses `pr` to the skip
   and the merge is missed again (measured above). A separate value token cannot be distinguished
   from a subcommand by shape alone, which is the strongest argument for the alternative: treat a
   `gh` invocation carrying pre-subcommand flags as unanalyzable and deny it.
2. Match the subcommand case-insensitively on the Python side for classifier parity. The measured
   gh CLI rejects mixed-case subcommands, so this is hardening, not an executable merge bypass.
3. Classify a `gh api graphql` call carrying a merge mutation as MERGE.
4. For the PowerShell string-evaluation and process-launch wrappers, either unwrap and classify what
   is inside, or treat a wrapped `gh` as unanalyzable and deny. Denying fails closed but widens false
   positives ([NS-25]).
5. Decide the policy for arbitrary HTTP clients. A command-text classifier cannot cover every
   spelling ([NS-43]'s text-matching class). The layer that sees the real merge however it is
   spelled is GitHub-side (branch protection and required checks), not local.
   - **Operator housekeeping, tracked here but not part of this item's completion:** audit the
     local allow rule noted above, and first measure whether worktree sessions see it. That lives
     in one machine's untracked config, so no state in this repo can record it as done, and
     `[NS-50]`(a) puts the `permissions` block on the adopter's side of the line deliberately. If a
     repo-level deliverable is wanted, it is a documented audit procedure adopters can run against
     their own local settings — not a claim about this machine.
6. **Correct the four statements that are already false**, independently of any redesign:
   - `scripts/review-reminders.sh:16-17` and `.ps1:38-39` ("an unconditional deny is both correct
     and total");
   - `docs/HOOKS-GUIDE.md:231` ("it always denies, full stop, with no override");
   - `templates/docs/HOOKS-GUIDE.md:206` ("no override, not even an explicit user instruction").
7. **Tests.** Adding cases is not enough here, and **the test topology has to be settled in the
   spec, not here** — two attempts to prescribe the wiring from this item were both wrong, one of
   them destructively (see the note at the end of this step). What follows is measured state, which
   the spec needs as input; the mechanism is the spec's to choose.
   - **Measured: the Python classifier has no CI-enforced unit coverage; the PowerShell one does.**
     `tests/run.sh` registers suites as 26 hand-maintained `run_suite` lines (`:20-45`, and `:48`
     says so), each invoking `bash "$script"` (`:15`). A separate completeness check (`:66-83`)
     fails the run when a tracked `tests/test-*.sh` is not registered — it globs that pattern only
     (`:68`). CI's Pester job runs `Invoke-Pester -Path "tests/"`, which picks up
     `tests/review-gate-classifier.Tests.ps1`. Nothing in CI or `tests/run.sh` reaches
     `tests/test_classify.py`, `tests/test_classifier_coverage.py` or `tests/gate_matrix.py`:
     searching `.github/`, `scripts/`, `.claude/` and `tests/` for those three names finds only
     their own lines plus `tests/mutate.py:130,133`, and `grep -rniE "pytest|python" .github/`
     returns nothing. `gate_matrix.py` does have one caller, `tests/mutate.py:133`, but
     `grep -rn "mutate\.py"` over the repo returns only this backlog file — so that caller is
     itself invoked by nothing and the chain dead-ends.
     The Python classifier does have end-to-end coverage via `tests/test-review-reminders.sh`
     (registered at `run.sh:33`); what it lacks is unit-level coverage — and it is exactly where
     the letter-case classifier split lives.
   - **Neither obvious wiring route works as-is**, which is why this is the spec's problem:
     `run_suite` runs `bash`, so a `.py` suite fails immediately; `test_classifier_coverage.py:13`
     takes the classifier path as `sys.argv[1]`, which `run_suite` cannot supply; and neither
     Python file defines a `test_` function, so pytest collects nothing from either. Whatever route
     is chosen, note that the `:68` completeness check can never match an underscore-named `.py`
     file, so new Python coverage sits outside the one guard this repo built against a suite that
     is never invoked — the failure mode `run.sh:48-53` records being bitten by three times.
   - **`tests/gate_matrix.py` must not simply be "wired in".** It refuses to run without
     `--yes-rewrite-history-in-this-throwaway-clone` (`:55-67`) because it rewrites history in
     whatever tree it is given: it commits the working tree under a fabricated author, moves the
     classifier and review-gate library out of the tree and back, and deletes the review markers,
     all via git subprocesses that no PreToolUse hook sees (`:32-36`). Its correct harness is
     `tests/mutate.py`, which only ever points it at a `copytree` copy under a temp directory —
     and `mutate.py` is itself unwired. **Never point it at the working checkout.**
   - **Three acceptance criteria that hold whichever topology the spec picks.** Deferring the
     decision is not the same as deferring the success criterion, and each of these closes a
     green-by-absence mode that survives any choice of mechanism:
     - Adding a tracked suite of the chosen type and *not* registering it must make `tests/run.sh`
       fail. Today the completeness check (`:66-83`) globs `tests/test-*.sh` only, so it cannot
       reach an underscore-named `.py`; on the PowerShell side there is no completeness check at
       all, and `Invoke-Pester` discovers `*.Tests.ps1` by naming convention.
     - A `templates/` twin that drifts from its `scripts/` original must make the suite fail. See
       step 8 — this is currently an instruction with no test behind it.
     - An end-to-end merge-form case must pin **which** verdict path produced its result. Measured:
       feed `gh PR MERGE 45 --squash` to `review-reminders.sh` with `python3` on PATH and it
       returns no decision (the classifier split); with `python3` unreachable, the raw fallback
       (`:149-155`) denies it. So a case-variant case would pass, and stay green under mutation, on
       any machine without `python3`. This synthetic input does not establish a working gh merge.
       The suite already has a `command -v python3` SKIP convention
       (`tests/test-review-reminders.sh:278`, `:320`, `:387`) that the merge-gate block at
       `:191-198` does not use. Note this inverts the invariant stated at `review-reminders.sh:132-133`
       — for the case variant the fallback is *wider* than the classifier.
   - Once the topology is fixed, add every form to whichever classifier-level suite it wires
     (`tests/test_classify.py` defaults the classifier path; `tests/test_classifier_coverage.py:13`
     requires it as `sys.argv[1]` — their invocation contracts differ) **and** to the end-to-end
     suite `tests/test-review-reminders.sh`, which exercises both twins.
   - **What the wrapper forms need is production fidelity, not a single suite.** Both classifiers
     are reachable by command text alone, so both need unit cases. What differs is faithfulness:
     in production a wrapper arriving as a `PowerShell` tool call never reaches the `.sh` twin
     (`.claude/settings.json`'s `PowerShell` matcher has no bash fallback), so only the `.ps1` path
     is end-to-end-faithful for it — `review-gate-classifier.Tests.ps1` at the classifier level and
     `tests/test-review-reminders.sh`'s `invoke_hook_ps1` (`:37-41`, already used against the merge
     gate at `:200-213`) at the hook level. A Python-side wrapper case tests a path production
     never takes; it is defence in depth, not the assertion that matters.
   - **`tool_name` is not the mechanism.** It is read by neither classifier and neither hook
     (`grep -n "tool_name"` across all four returns nothing, and both probes return identical
     verdicts under either value), and `tests/test-review-reminders.sh` omits the field entirely.
     Parameterising it would add nothing. If the fix introduces `tool_name` branching, every suite
     needs revisiting.
   - Mutation-check each: remove the new handling and confirm the test goes red.
   - The exact payloads then live in the repo as tests, beside the fix, which is where they belong.
8. Mirror everything to `templates/`, and add a CHANGELOG note for adopters.
   - **Make the mirroring testable, not just instructed.** `tests/test-mirror-parity.sh` covers
     `.cursor/rules`, `.claude/commands` and `standards/` — not the classifiers or the hooks.
     Three sibling scripts assert their own twin with a `diff -q`
     (`tests/test-dangerous-commands.sh:958`, `tests/test-pre-compact-check.sh:188-190`,
     `tests/test-codex-compaction-hooks.sh:70,74`); the four files this fix touches have no such
     assertion. That drift has already shipped twice, as `tests/test-mirror-parity.sh:11-13`
     records. Add `diff -q` assertions for both classifier twins and both `review-reminders` twins
     to `tests/test-review-reminders.sh`, which is already registered and needs no new wiring.

## Related

`docs/backlog/replace-the-gh-pr-merge-deny-with-a-forced-permiss.md` proposes loosening this same
gate and must not proceed before this fix.

This file owns, and that one does not restate: how the classifiers match, the measured table, the
auto-mode observation, the adopter reach, and the branch-protection settings. That item does carry
a one-line summary of which forms escape, so that its own argument can be read without this file
open — if the table changes, that summary is the one place to check. Also [NS-25], [NS-26], [NS-43].
