# Changelog

## [Unreleased]

### Fixed
- **`mb commit` never worked on Windows, and now does.** `mb.ps1` compared two `Resolve-Path`
  results with `-ne`. `Resolve-Path` returns a `PathInfo`, which has no value equality, so that
  compared **references** and was unconditionally true — it returned `True` even where both sides
  resolved to the identical string in a healthy main worktree. The subworktree guard therefore
  fired in **every repository**, so `mb commit` refused everywhere on the documented Windows entry
  point (`install.bat` → `mb.bat` → `pwsh mb.ps1`). `mb.sh` was never affected; it compares
  `realpath` strings. Logged since 2026-06-18 as audit finding C5 with a root cause — "symlinks or
  UNC paths … in some cases" — that was wrong in both halves: incidence was 100%, and no symlink
  or UNC path was involved. Comparing `.Path` fixes it. **A refusal-only test cannot catch this**
  (it passes against the broken form), so the new coverage asserts the main-worktree happy path.
- **`mb commit` also broke, both ways, on any repository path containing `[` or `]`** — legal on
  Windows. `Resolve-Path` treats its argument as a **wildcard**, so a bracketed path resolves to
  `$null`. With a bracket on one side only, one real string faced a `$null` and the subworktree
  guard fired in a healthy main worktree: `mb.ps1` refused with "You are in a git subworktree"
  (exit 1) where `mb.sh` correctly reported "No changes" (exit 0). With a bracket on **both**
  sides — a bracketed main repo and a bracketed subworktree — both resolved to `$null`, `$null -ne
  $null` is false, and the guard did not fire at all: `mb commit` returned "No changes" and exit 0
  from inside a genuine subworktree. That second direction is the more dangerous one, a refusal
  that should have fired and silently did not, and it was found only after the first was fixed.
  Both are closed by `-LiteralPath`, which disables globbing.
- **`mb doctor` aborted at exit 128 in any non-git directory, skipping checks 15–25.** Three bare
  command-substitution assignments ran under `set -e`, where a non-zero `git` exit kills the
  script; `2>/dev/null` hides git's message but not its status. Two of the three predate this
  release. `mb.ps1` was never affected — PowerShell does not abort on a native command's exit code.
- **`mb doctor` check 15 reported `[OK]` for a repository measuring 27 KB against a 25 KB hard
  limit** (27,607 B versus a 25,600 B ceiling — 27 KB in total, not 27 KB in excess), whenever
  it ran inside a subworktree whose main repo path contains `[` or `]`. That check resolved
  `--git-common-dir` with a wildcard `Resolve-Path` carrying no `-ErrorAction`, so a bracketed path
  resolved to `$null` and `Split-Path -Parent $null`
  threw `ParameterBindingValidationException`. The throw is the visible half and the lesser one:
  doctor does not die on it. It prints a raw stack trace, continues with the startup root still at
  `"."`, and therefore measures the **subworktree's own** memory-bank instead of the main
  worktree's — the phantom-reduction failure that check's worktree-awareness exists to prevent.
  Measured with the main worktree inflated past the ceiling and the subworktree left small:
  pre-fix printed `[OK] Startup context: 0.6 KB`, post-fix printed `[ERROR] 27 KB exceeds 25 KB`,
  and a non-bracketed path printed the `[ERROR]` either way — so the bracket is the cause, not
  mere absence. The `Test-Path`, `Get-ChildItem` and `Get-Item` calls in the same check are the
  same wildcard class and never threw at all; they were the silent half of the same wrong-root
  measurement. All five calls in that check — four cmdlet kinds, `Test-Path` appearing twice — are
  now `-LiteralPath`.
- **`mb.ps1` would not start at all at an `MB_HOME` containing `[` or `]`, while `mb.sh` worked.**
  The startup guard (top-level script scope in `scripts/mb.ps1`, above the first function
  definition; no line number, for the reason the bullet below gives) tests
  `Test-Path (Join-Path $RepoRoot 'templates')` with `$RepoRoot = $env:MB_HOME`. Wildcard
  `Test-Path` cannot match a bracketed path, so mb refused to start against its own installation
  with `[ERROR] MB_HOME '...' is not a valid PMB installation (templates/ not found)` and exit 1 —
  measured rc=1 versus `mb.sh` rc=0 at the same `MB_HOME`, and rc=0 for both at a non-bracketed one.
  Now `-LiteralPath`, which is also a security sharpening rather than only a usability fix: a
  wildcard `Test-Path` can be satisfied by some *other* directory the pattern happens to match, so
  the guard could pass for a path that is not the one about to be used. Measured — with
  `$RepoRoot` set to `<base>\evil*` and a real `evilX\templates`, wildcard `Test-Path` returns
  `True` and `-LiteralPath` returns `False`.
- **The bracketed-`MB_HOME` divergence is NARROWED BY THIS CHANGE, NOT CLOSED — do not read the
  entry above as closing it.** `mb.ps1` now starts, but further `Test-Path` calls on
  `$RepoRoot`-derived paths still glob. **Neither a count nor line numbers are given for that
  subset, deliberately** — both decay, and several attempts at each were wrong; the figure to act on
  is the AST-exact superset below (115). Regenerate the current set from the PowerShell AST:
  variables assigned from an expression containing `$RepoRoot`, followed transitively through
  path-valued derivations of `$TemplatesDir`, then every `Test-Path` lacking `-LiteralPath` that
  references one — then **audit the result by scope, not by variable name**, which is where every
  count attempted here went wrong: `$dir` enters the closure from a single template-path assignment
  and then name-collides with three unrelated destination-path variables in other functions. Report
  the procedure and the superset; do not quote a subset integer.
  Measured against the **fixed** build at a bracketed `MB_HOME` whose `templates/`, `standards/`,
  `fixtures/` and `VERSION` all genuinely exist, versus a plain one — **five** doctor checks give
  different results, not the three an earlier draft claimed:
  check 0 `[OK] Memory Bank v1.2.1` → `[WARN] VERSION file not found`; check 2 `[OK] Templates
  found` → `[ERROR] Templates not found`; check 12's `[WARN] No .pmb-version found` line **absent
  entirely**; check 13 `[OK] Security regression fixtures present (9/9)` → `[WARN] fixtures/security/
  not found`; check 14's `[OK] Standards count: 15 (budget: <= 20)` line **absent entirely**. Checks
  12 and 14 do not fail — they silently disappear, because neither has an `else` branch. `mb.sh doctor`
  at the same bracketed `MB_HOME` prints the same results it prints at a plain one — check 12 is a
  `[WARN]` in both, so it is not literally `[OK]` across the board. So the symptom
  moved from an exit-1 at startup into false and missing results across five governance checks — a
  smaller blast radius, the same class, and by this entry's own standard (a false OK outranks a
  crash) not obviously an improvement in kind.
- **A separate bracketed-path defect, found while checking the above and recorded rather than
  fixed: `mb doctor` cannot write `.pmb-checksums` when the CURRENT WORKING DIRECTORY contains `[`
  or `]`, in `mb.ps1` only.** The path is passed to `Set-Content -Path` as a bare CWD-relative
  string, so PowerShell wildcard-resolves it against a bracketed `$PWD`. Measured, `mb.ps1` against
  `mb.sh` at the same CWD:
  - With **no** `.pmb-checksums` present, the write fails on every run and the file is never
    created: `[OK] Integrity checksums - baseline established on this run` followed immediately by
    `[WARN] Could not write .pmb-checksums: An object at the specified path ... does not exist, or
    has been filtered`. Because nothing is persisted, the next run baselines again — so on such a
    project the check can never detect a modification, though it never claims to have verified one
    either.
  - With a `.pmb-checksums` already present (written by `mb.sh`, which is unaffected), verification
    **does** work — `[OK] Integrity checksums verified - no external modifications detected`. A CWD
    containing `[` still fails to refresh it, warning every run; a CWD containing only `]` refreshes
    successfully. So `]` breaks creation but not refresh, and `[` breaks both.
  - `mb.sh` writes and verifies correctly at all three CWD shapes. The read path is unaffected in
    both runtimes — only the write fails.
  It matters for scoping that this is neither `$RepoRoot`-derived nor argument-driven, so it lies
  outside every derivation audit finding C9 gives, and project paths are likelier to contain
  brackets than install paths. The CWD-relative population is deliberately not enumerated here.
- **Also still open, deliberately:** `mb setup <path>` and `mb init <path>` reject an existing
  bracketed directory as nonexistent, and **115 of `mb.ps1`'s 118 `Test-Path` calls still glob**
  (AST-counted; the 118 occupy 116 distinct lines and the globbing 115 occupy 113 — the three
  exceptions were all added by this change).
  Neither command has coverage exercising its `<path>` argument, which is the branch carrying the
  defect — though both have *some* pwsh coverage: `mb init` runs as a subprocess at
  `tests/mb-setup.Tests.ps1:122,163,196,246`, and `mb setup`'s helpers `Get-MbMode`,
  `Get-MbUpgradeAnalysis` and `Invoke-MbVerify` — each reachable only through `Invoke-Setup` — are
  unit-tested in the same file, all run in CI via `Invoke-Pester`. The deferral rests on that
  argument-level gap alone, not on an absence of coverage. Recorded as audit finding C9 in
  `docs/superpowers/specs/2026-06-18-mb-commands-audit.md`, which carries the derivation for the
  remaining population rather than a snapshot of it.
- **A failed `git status` was mishandled in `mb commit` — differently in each runtime, so the two
  are described separately rather than blended.** On a corrupt or unreadable index, `mb.ps1`
  reported "No changes in memory-bank/ to commit" and exited **0**, claiming a clean tree it had
  never successfully inspected; `mb.sh` did *not* do that — being a bare assignment under `set -e`,
  it aborted at exit **128** with only its banner printed, the same class as the `mb doctor` abort
  above. Both now print an explicit error and exit 1. Stated per-runtime because an earlier draft
  of this entry attributed the false-success symptom to both, and only `mb.ps1` ever had it.

### Changed
- **BREAKING (exit codes): `mb commit`'s refusal paths now exit `1` instead of `0`,** in both
  runtimes. Previously "not a git repository" and "you are in a git subworktree" printed an
  `[ERROR]` and exited **0**, so `mb commit && <next>` ran the success branch having committed
  nothing. No rule distinguished the two paths from any other failure; both mean the command did
  not commit. **If you script `mb commit`, check the exit code** — a wrapper relying on `0` will
  now see a failure where it previously saw silent success. Note this arrives quietly: `mb.sh` and
  `mb.ps1` are not in `TEMPLATE_OWNED` and `templates/scripts/` ships no `mb.*`, so `mb upgrade`
  does **not** deliver them — you receive this when your PMB clone updates, with no diff shown.

### Added
- **`tests/test-mirror-parity.sh` now cross-checks the two runtimes' `TEMPLATE_OWNED` sets against
  each other, and compares hooks structurally.** The previous sweep derived its guarded set from
  `scripts/mb.sh` alone and guarded it with `count > 0` — a floor that cannot detect erosion:
  truncating the array from 29 entries to 1 left the suite green while assertions silently fell
  123 to 81. `scripts/mb.ps1`'s `$templateOwned` is an independent, hand-maintained declaration of
  the same intent, so the two anchor each other. They **deliberately differ** — `mb.ps1`
  force-overwrites `standards/*.md` and `mb.sh` leaves them advisory — so the assertion pins the
  *shape* of that difference rather than demanding equality: every `mb.ps1`-only entry must be a
  `standards/*` file, `mb.sh` must own nothing `mb.ps1` lacks, and the divergence must still exist.
  It therefore also goes red if someone reconciles the runtimes, forcing that to be a decision
  rather than a drift. No count appears anywhere in it — "they differ by 15 entries" would have been
  the same decaying absolute this release removes elsewhere. The `settings.json`
  check also compares `(event, matcher, commands)` triples rather than `"command":` lines only:
  moving the `dangerous-commands` matcher from `Bash` to `Write|Edit` — unhooking the BLOCK-tier
  guard from every Bash call — passed the old check and fails the new one.
- **`tests/test-pre-compact-check.sh` covers the BSD mtime fallback**, which no test could previously
  reach: every case ran where GNU `date -r` succeeds, so the fallback line never executed, on any
  runner (all CI jobs are `ubuntu-latest`). A stub `date` that rejects `-r` exactly as BSD does now
  exercises both outcomes, including the macOS bypass the fix promised — previously self-attested.
- **Startup-context ratchet — a new hard-failing CI check.** `CLAUDE.md` plus every
  `memory-bank/**/*.md` is summed and compared against the same total on `origin/main`; a pull
  request that increases it fails. The 25 KB ceiling this repo is still far over stays advisory —
  what is enforced is the *direction*, because "advisory" had been read as "may grow", and it did.
  Reductions are always free. If the baseline cannot be fetched the check degrades to advisory and
  says so, rather than failing on an unavailable baseline.
- **`tests/test-threshold-parity.sh` additionally asserts that `mb doctor` is never looser than the
  CI shipped to adopters** — the direction that produces a clean local check followed by a red
  build. Equality is deliberately *not* asserted; see the cap-sources entry under Changed.

### Changed
- **The Handoff Protocol's step 4 now requires a paste-able launch block.** It previously said to
  respond *only* "Handoff ready at `handoff.md`" — which withholds the session title, branch and
  worktree the next session is opened with, so the user has to ask for them every time.
  `templates/handoff.md` already labelled the title "the user pastes this when opening the next
  session", so the intent was there; only the response format had not caught up. Both `CLAUDE.md`
  and its template are updated. The block's facts must be verified with a command rather than
  transcribed — a wrong branch there sends the successor into the wrong worktree.
- **The agent-delegation hook's budget is documented as what it actually measures.**
  `standards/PERFORMANCE-BUDGET.md`, `standards/AGENTIC-SAFETY.md` and `docs/HOOKS-GUIDE.md` (plus
  `templates/` mirrors) said "≤1 delegation depth" while the shipped hook had warned above **6
  cumulative spawns** since `5c0e8c9` — and cited `PERFORMANCE-BUDGET.md` as the authority for a
  number that document contradicted. The change to 6 had never been disclosed here either. The
  docs now separate the two limits and say which is enforced: spawn count is checked, nesting depth
  is not and **cannot** be, because there is no `PostToolUse:Agent` event, so six parallel agents
  and a six-deep chain are indistinguishable to a hook. `AGENTIC-SAFETY.md` previously told
  operators a WARN meant "a subagent is attempting to spawn another subagent"; that reading sent
  them hunting for something the counter cannot see, on a signal ordinary fan-out produces.
- **`README.md`'s memory-bank cap paragraph corrected on two counts.** It called
  `.github/workflows/memory-bank-size.yml` "the workflow you receive" — but `mb init` delivers no
  `.github/` path at all; only `mb upgrade` adds it, so a project set up with `mb init` alone has no
  CI enforcement of these caps. And its unqualified "`mb doctor` is never looser than your CI" held
  only for the shipped defaults, one sentence before telling the reader to tune those defaults.
- **`/change-review` Job 7 no longer enumerates `ai-review-agent`'s internal fields; it states an
  invariant.** Exit `0` never earns an unqualified clean pass, the coverage-signal list is marked
  INDICATIVE rather than exhaustive, and per-field reliability is documented as build-dependent and
  to be re-derived rather than remembered. Four review rounds were spent keeping a precise
  description of that tool current; every version was correct when written and wrong within a day,
  because the local install is a link into another working tree that rebuilds without warning.
  The exit-code table also gained a catch-all, a version preflight (`--chunk` needs >= 1.10.0), and
  a mandatory `--format json`. A known gap is documented in place: that tool's security and
  adversarial agents exclude `**/*.md`, which on a markdown-dominant diff means they review only the
  remainder while the rendered report says nothing about it.
- **Cursor's handoff threshold lowered from 80% to 40%, matching Claude Code.** The 80% was
  documented and deliberate — justified on rule re-injection, which addresses the *continuity* cost
  of a full context but not the *quality* cost. **Adopters using Cursor: you will be prompted to
  hand off considerably earlier than before.** The reasoning is deliberately not restated here; it
  lives in `standards/MEMORY-BANK.md` under "Implications for Handoff Thresholds", including why a
  Cursor-specific number should not be re-derived from rule-persistence behaviour.

  A second, independent reason applies: `memory-bank/systemPatterns.md` already stated the trigger
  as 40% with no IDE qualifier, so two governing documents were in conflict with no stated
  arbitration between them. That reasoning is **not restated here** — it now lives alongside the
  rest in `standards/MEMORY-BANK.md`, which is the governed home for it. The *general* gap it
  exposes (nothing states whether a `standards/` document outranks a `memory-bank/` one) remains
  open and is tracked separately.

  **The two scaffold templates that also carried the old 80% are corrected here:**
  `templates/AGENTS.md` (three places) and `templates/memory-bank/README.md`. Note their
  distribution differs — `README.md` ships via `mb init`; **`AGENTS.md` has no `mb` CLI
  distribution path at all** and reaches projects only through the standalone
  `scripts/init-memory-bank.sh`, which is a separate pre-existing gap.
- **Review agents now pin their model in frontmatter.** `.claude/agents/security-reviewer.md`
  pins `sonnet`, the new `.claude/agents/opposition.md` pins `opus`, and `researcher.md` states
  `haiku` deliberately. Previously none declared a model, so all three silently inherited
  `CLAUDE_CODE_SUBAGENT_MODEL=haiku` from `.claude/settings.json` — a security review and the
  opposition gate were running cost-optimized, producing output shaped identically to a thorough
  pass with nothing recording which model produced it. **Adopters: your `security-reviewer` will
  now run on a more capable model than before.**
- **`mb doctor` check 25 additionally warns when `security-reviewer` or `opposition` is missing a
  `model:` field, or pins `haiku`.** `researcher` is deliberately exempt. Both shells.
- **Memory-bank line caps aligned to this repo's CI in both runtimes.** An audit found three
  divergences running in both directions. The figures below are the values **as of that audit**,
  not the shipped ones: `progress.md` was stricter at runtime (400) than in CI (600), while
  `projectbrief.md` (150 vs 120) and `techContext.md` (400 vs 300) were LOOSER at runtime than in
  CI — so a clean `mb doctor` could be followed by a red build. Only the first had been recorded.
  The caps have since been ratcheted down; read the shipped values from
  `.github/workflows/pmb-health.yml`, never from this entry.
  `tests/test-threshold-parity.sh` now fails if those sources drift again.
- **Scope limit, stated because the entry above is easy to over-read:** there are **four** cap
  sources, not three. `templates/.github/workflows/memory-bank-size.yml` — the CI adopters actually
  receive — is deliberately looser, because its caps are starting defaults an adopter tunes, and
  forcing this repo's ratcheted values onto a fresh install would red their first build. Equality
  across all four is therefore the wrong invariant. What is now asserted is the **direction**:
  `mb doctor` must never be looser than the CI it ships beside, since that is the combination that
  produces a clean local check followed by a red build.
- **`standards/MEMORY-BANK.md` eviction criteria amended.** The two age-based `progress.md` rows
  (>6 months, >3 months) were removed: they had never fired and could not, since the repo is four
  months old while `progress.md` measurably grows ~8 KB/day. They are replaced by a
  citation-survival test, chosen because it reproduces all four historical relocation outcomes
  including the one that was reverted. Destinations that are living documents must now carry a
  registered size cap.

### Fixed
- **The PreCompact handoff-bypass validates the mtime it reads by SHAPE, not merely by emptiness.**
  The fallback's comment claimed "if both fail the variable stays empty." False on GNU: `2>/dev/null
  || printf ''` discards stderr and the exit code but not stdout already written, and GNU `stat -f`
  means `--file-system`, so it consumed the format arguments as file operands while the real operand
  succeeded — printing ~108 bytes of filesystem fields that command substitution captured.
  Reproduced on coreutils 8.32. The gate never mis-fired (a 108-byte string cannot equal today's
  date), so this was diagnostic, not a bypass: the stale-handoff note printed the filesystem dump
  where a date belongs instead of saying the date could not be read. Anything not exactly
  `YYYY-MM-DD` is now discarded, which makes the stated invariant true on every platform rather
  than only where the fallback happens to be unreachable. The `.ps1` twin never had this defect —
  it reads `LastWriteTime` and yields either a formatted date or `$null`.
- **`mb init` never delivered `.claude/agents/*.md`, so a fresh adopter's review gate was dead on
  arrival.** `init` copied every `templates/claude-commands/*` — including `code-review.md` and
  `change-review.md`, which each dispatch `subagent_type: opposition` **by name** — while containing
  zero references to `.claude/agents`. The documented fallback was broken by the same gap:
  `code-review.md:98` says to fall back to `general-purpose` "pasting the body of
  `.claude/agents/opposition.md` in as the prompt", a file `init` also never delivered. So the gate
  failed at Opposition — its sole authority on whether a change ships — with no graceful
  degradation. Latent while the commands asked for "a capable model" in prose; **live from the
  moment agents became a named dependency** earlier in this same release. Both shells now
  auto-discover `templates/.claude/agents/*.md`, matching the delivery already present in
  `mb upgrade`. **Adopters who ran `mb init` on an affected version: run `mb upgrade` to receive the
  agent definitions**, or re-run `mb init` — it creates only what is missing and preserves existing
  files.

  Cause worth naming, because it is the recurring one: agent delivery *was* fixed, for `mb upgrade`,
  and scoped to the single path that prompted it. `init` is the path adopters actually take. The
  regression tests added on both shells derive their expected set from `templates/.claude/agents/`
  at runtime and assert that set is non-empty, so neither a newly added agent nor an empty template
  directory can pass silently.
- **`templates/CLAUDE.md` described the PreCompact hook as warning when it blocks.** The shipped
  copy still documented the original 2026-05-28 design ("the hook always exits 0 — compaction is
  never blocked"); the behaviour changed to a hard exit-2 block and the template was never updated,
  so adopters were told to expect a warning and got a refused compaction with no explanation. Now
  states the real conditions, including the dated-handoff bypass.
- **`standards/MEMORY-BANK.md` instructed `mb compact`, which exits 2.** The command was folded into
  `mb clean` and now only prints a redirect. Inverted drift: `templates/standards/MEMORY-BANK.md`
  already carried the correct instruction, so adopters were right and this repo's own copy was wrong.
- **The `.cursor/rules` mirrors had no drift guard.** Those files are `TEMPLATE_OWNED` — `mb upgrade`
  overwrites the live copies from `templates/cursor/rules/` unconditionally — yet nothing verified
  the two agreed, so a stale governance rule could ship to every adopter with no signal.
  `tests/test-mirror-parity.sh` now compares them in both directions, auto-discovering the files
  rather than hard-coding a list.
- **The PreCompact memory-bank freshness gate was bypassed by any `handoff.md`, however old.**
  `pre-compact-check.sh`/`.ps1` short-circuited on a bare existence check with no staleness test, so a
  spent handoff left in the repo root silently disabled the gate for every compaction. Both shells now
  require the handoff to be dated today. A stale handoff removes only the *bypass* — it is not itself a
  failure, so a genuinely fresh memory bank still passes. The hook had **no test coverage in either
  shell**; `tests/test-pre-compact-check.sh` now covers it.
- **`mb upgrade` would never have delivered a newly-added agent.** `ADVISORY_DIFF` hard-coded two
  agent paths in both shells — the same stale-list bug already documented for slash commands in
  1.2.0. Agents are now auto-discovered from `templates/.claude/agents/*.md` into
  `ADVISORY_CREATE` (not `ADVISORY_DIFF`, which skips targets that are missing — and a
  newly-shipped agent is missing for every adopter by definition).
- **`mb upgrade` (PowerShell only) could deliver non-agent files into `.claude/agents/`.**
  `Get-TemplateDirFile` had no extension filter while the bash glob used `*.md`, so a stray
  `README`, `.txt` or editor backup in the template directory would be copied by pwsh and not by
  bash. The helper now takes an opt-in `-Filter`, passed `*.md` at the agents call site only.
- `.claude/agents/opposition.md`'s description advertised "never writes review markers"
  unconditionally, contradicting both its own body and the marker write that
  `.claude/commands/code-review.md` Step 5.3 requires of it on an Approve verdict.
- Both review commands instructed the orchestrator to pass "`sonnet` or higher" to the opposition
  agent. An explicit `model` parameter overrides frontmatter, so a compliant orchestrator would
  have silently downgraded the `opus` pin added to prevent exactly that. Both now specify `opus`.

### Documentation
- **Recorded a cross-project provenance gap.** The ACR session holds a memory-bank entry attributing
  a specific `ai-review-agent` timeout measurement (a 616 s agent runtime against a 282,240 ms
  ceiling) to a brief from this project. That measurement exists nowhere in PMB — not in
  `memory-bank/`, `docs/`, `docs/archive/`, or the ACR brief in the operator's Downloads. It was
  reported back as unsourced rather than reconstructed from the formula, and ACR was advised to
  re-derive it with instrumentation rather than treat it as evidence.
- `memory-bank/activeContext.md` stated `progress.md` was at "599/60,000 — ZERO bytes of headroom,
  deadlock is live". The file was well under both caps by then; the claim was stale from the
  moment the relocation landed, in the same branch that left the paragraph unedited. No
  replacement byte count is recorded here — two attempts to pin one went stale inside this very
  branch, so the number is left to `wc -c` and the CI caps. Its `mb.sh:831` /
  `mb.ps1:1090` citations were also simply wrong (`mb.sh:409,410,967`, `mb.ps1:1189`).
- `memory-bank/progress.md` recorded the relocation as taking the file to a specific byte count.
  Two successive attempts to state that number (40,063, then 46,956) were each already stale when
  written, because entries kept being appended after the measurement. No byte count is recorded in
  any of the three files any more — the relocation's effect is stated as bytes REMOVED (20,953),
  which does not decay, and current size is left to `wc -c` and the CI caps.
- New `[NS-42]` (write-rate control — eviction is symptom relief; the file grew +24,355 bytes in
  three days and `docs/archive/` already holds 149,711 relocated bytes) and `[NS-43]` (the review
  gate structurally forbids commit-splitting, and its purely textual matcher denies any command
  that merely mentions a guarded pattern).
- Agent definitions now carry a scope caveat: their `Bash(...)` entries declare intent and were
  observed not to constrain Bash in practice, so they must not be relied on as a security boundary.

### Security
- **`scripts/dangerous-commands.ps1` (and its `templates/` mirror) now decodes hook stdin with an
  explicit `StreamReader`+`UTF8Encoding` instead of `$input | Out-String`,** which was re-decoding
  bytes through the console code page and mangling non-ASCII payloads before any tier could match
  them. **This is a measured trade, not a pure win, and the losing side is stated deliberately.**
  Across a 10-case byte matrix: the new path correctly matches UTF-16 LE/BE and UTF-32 LE/BE input
  carrying a BOM — four encodings the old path silently failed to match — but it no longer matches
  two *malformed hybrids* (a `FF FE` or `FE FF` prefix followed by UTF-8 bytes) that the old path
  did match. Those hybrids are not emitted by the documented producer, which writes byte 0 of this
  stream; that containment is INFERRED about a third-party binary, not verified here. Coverage is
  3 of the 10 cases; UTF-16 BE, UTF-32 LE/BE and both hybrids are asserted nowhere. Adopters running
  hooks under `pwsh` get the four gained encodings and the two lost hybrids.
- **A word-splitting bug could silently disable a required CI check.** The startup-context job
  enumerated files with an unquoted command substitution, so any tracked path containing a space
  word-split into nonexistent paths, the baseline lookup failed, and the check reported PASS while
  skipping its own work. Now NUL-delimited (`git ls-tree -rz`). Demonstrated against a real tree.
- **`mb doctor`'s worktree path resolution is fixed** (`git rev-parse --git-common-dir`): from a
  subworktree it previously measured whichever `memory-bank/` sat beside it, which is stale by
  construction, and reported a large false margin on the one check meant to be unfoolable.

- `scripts/dangerous-commands.sh`/`.ps1` (and `templates/` mirrors): commit-signing bypass is now
  CONFIRM-tier, alongside the existing `--no-verify` entry. Covers `commit.gpgsign` set to any
  value git resolves as false (`false`/`0`/`no`/`off`, any case, quoted or bare) via `git -c` or
  any `git config` subcommand including `--global`/`--system`/`--local`/`--file`/`--replace-all`,
  plus `--unset`/`--unset-all commit.gpgsign` and `--no-gpg-sign`. Reported from
  `ai-code-review-agent`: an agent disabled signing twice in one session and the gate never
  fired, because the class was governed only advisorily by `CLAUDE.md` with no deterministic
  layer behind it. Commands that *enable* signing are deliberately not gated.
- **Fixed a bypass that predated this feature and survived three review rounds:** backslash-newline
  continuations are now removed before any tier matches. The shell removes a backslash-newline before
  git sees the command, so `git config commit.gpgsign \`⏎`false` ran as the one-line form while the
  hook — matching the raw two-line text — stayed silent. Verified live: `commit.gpgsign` moved
  `true` → `false` with no prompt. This applies to **every** tier, because the same evasion defeated
  literal BLOCK substrings: a wrapped `git push --force` was equally uncaught.
- The continuation is **deleted**, with runs of blanks collapsed separately — matching shell elision,
  which inserts nothing, and shell tokenization, which treats any run of blanks as one separator.
  Two earlier attempts substituted a space instead and each shipped its own bypass, both caught by
  review: leaving the continuation indent broke `git push \`⏎`  --force`, and stripping the indent
  broke the no-whitespace case, letting a line break placed **mid-token** split every literal BLOCK
  substring (`rm -r\`⏎`f` → `rm -r f`). Both are now pinned by tests in each suite.
- The signing patterns accept an optional quote around the **key** as well as the value. A
  backslash-newline inside double quotes concatenates with no space at all, so
  `git config "commit.gpg`⏎`sign" false` is a working persistent bypass — and the join fix alone
  did not close it, because the closing quote after the key blocked the match.
- The signing key patterns anchor to the flag or subcommand that actually **sets** config, rather
  than to any `git` token. An earlier version required only a leading `git`, which left every git
  command carrying the key as *text* firing a CONFIRM — including, self-demonstrably, `git commit -m`
  with a message describing this feature.
- Documented, in `standards/SECURITY-GUARDRAILS.md`, what the gate does **not** cover:
  `GIT_CONFIG_COUNT`/`GIT_CONFIG_KEY_n`/`GIT_CONFIG_VALUE_n` env vars, direct `.git/config`
  writes, and `tag.gpgsign`/`push.gpgSign`. Gating the first two would not raise the floor — a
  plain `>> .git/config` append is simpler and stays open — so they are stated rather than
  matched, keeping the coverage claim honest. The accepted false positives are listed there too:
  a quoted git invocation as text, a git command naming `--no-gpg-sign` in free text, and prose
  containing the word `config` near the key.
- An argument-stripping mechanism that removed `-m`/`--message`/`-S`/`--grep` payloads before
  matching was built for those false positives and then **withdrawn**. Making the hook's view of a
  command deliberately differ from what the shell will run introduced two defects of its own:
  `sed` is line-based while .NET `-replace` is not, so the two shells returned different verdicts
  on a multi-line commit message; and an unquoted multi-word argument was only partly removed.
  Anchoring alone had already resolved three of the four cases it was built for.
- New `confirm_regex()` helper in the `.sh` twin. The `.ps1` CONFIRM loop already supported a
  `regex` flag; the `.sh` side had no regex path. The two shells share the same regexes,
  restricted to the subset valid in both GNU ERE and .NET; only the string escaping differs
  (sh needs `\"`, PowerShell needs `''`), and the parity block asserts equal behaviour.
- `tests/test-dangerous-commands.sh` now runs 124 assertions and `tests/dangerous-commands.Tests.ps1`
  58 tests (16 assertions and 13 tests respectively on `main`). Both figures are measured, not
  estimated; an earlier version of this entry said 74 and 37, which was wrong in both halves and
  disagreed with `memory-bank/progress.md` in the same commit. The sh total is environment-
  dependent: the cross-shell `assert_parity` block is skipped when `pwsh` is not on `PATH`. Both
  suites carry false-positive controls with a **git** carrier rather than only non-git ones, pin
  every accepted limit so a future pattern change cannot move one silently, and pin the
  continuation join at BLOCK tier as well as CONFIRM.

- **Fixed a second bypass that predated this feature: the `.sh` hook's `python3` extraction ran
  text-mode I/O under a `cp1252` locale on Windows, so any non-ASCII command silently degraded to
  raw-stdin matching** — the exact false-positive mode the extraction exists to prevent. A CJK
  payload made the `.sh` twin DENY (reporting the byte length of the whole JSON file as the command
  length) while the `.ps1` twin allowed it: opposite verdicts on ordinary input. Extraction now reads
  and writes binary with explicit UTF-8. **Both halves were required.** `stdin`/`stdout` carry
  `errors='surrogateescape'`, so the two JSON encodings fail in opposite directions: `\uXXXX` escapes
  break a text-mode write, while raw UTF-8 bytes break a text-mode read, and the original code only
  survived raw payloads because `print()` re-encoded the mojibake through the same codec and it
  round-tripped. Fixing only the write side — the form this branch carried as "designed and proven" —
  passes the escaped case and reintroduces the bypass on the raw one.
- `confirm_boundary()` now checks the de-escaped view of the command like the other four matchers.
  It was the one function the retrofit missed, so `git m\erge main` and `git "merge" main` were
  silent in `.sh` while `.ps1` confirmed both. The mutation proof had verified the mechanism where it
  was wired, which says nothing about whether every matcher is wired to it.
- **The two nested-gap CONFIRM regexes are bounded (`[^|;&]*` → `.{0,300}`), removing a hang.**
  Backtracking on the `git (gap)config (gap)` shape is cubic (~8x per doubling, measured), so the
  50,000-character length bound permitted roughly **47 minutes** of matching per pattern — and a
  `PreToolUse` hook blocks the tool call, so this was a hang rather than a slow path, reachable by an
  ordinary large heredoc writing prose about `git config`. Now ~0.75s at 50,000 characters, still
  matching a 296-character `-C` path. `{0,300}` is valid in GNU ERE and .NET alike, so one regex still
  serves both shells.
- **Only the nested pair is bounded.** The `-c` and `--no-gpg-sign` patterns nest a single gap group,
  measure ~4.3s at 50,000 characters on the payload shape that is worst for them, and are left
  unbounded on purpose: in `git <gap> --no-gpg-sign`
  that gap holds the **commit message**. Bounding all six groups uniformly — the first form of this
  change — silently disabled the signing CONFIRM for any commit message longer than about 185
  characters, on both shells, which is ordinary rather than adversarial. Bounding a gap is safe only
  where the gap holds flags. Regression tests now pin 50-, 250- and 600-character messages.
- A runtime regex timeout was rejected — it converts the hang into a denial and would be .NET-only.
  The suites assert the *shape* instead (no pattern may carry more than one unbounded gap group),
  structurally, on both platforms, in constant time.
- **Fixed a live bypass in the gap character class itself: a shell separator in an ordinary commit
  message silently defeated the signing gate on both shells.** The gaps were `[^|;&]*`, so any `|`,
  `;` or `&` between `git` and the flag made the pattern unmatchable — and for the `-c` and
  `--no-gpg-sign` patterns that gap holds the **commit message**. Verified: `git commit -m "docs: R&D
  notes" --no-gpg-sign` was allowed with no prompt, as was `git -c "alias.x=a|b" -c
  commit.gpgsign=false commit`. An ampersand in English prose is not an evasion attempt. The class
  also never achieved its purpose — newline was never excluded, so the gap already spanned commands.
  Those two gaps are now `.*`. The two nested-gap `config` patterns kept the separator-excluding
  class for one round, on the argument that their gap holds flags and paths — see the following
  entry, where that argument did not survive contact with `core.pager`.
- The PowerShell twin now matches regex patterns with `Singleline` set. Under `grep -z` the bash
  twin treats the payload as one record, so its `.` matches a newline while .NET's does not — latent
  while no pattern contained a bare `.`, and activated by the change above. This is the third
  appearance of the same line-vs-string mismatch in this file (`sed` vs `-replace`, then `grep` vs
  `-imatch`, now `.` vs `.`), so it is fixed in the same commit as the change that would expose it.
- **The same hole in the two `config` patterns is now closed too.** A separator between `git` and
  `config` defeated them the same way — `git -c core.pager='less | head' config --global
  commit.gpgsign false` permanently unsigns every commit in every repo, and `core.pager` with a pipe
  is an ordinary configuration. Those gaps are now `.{0,300}`: still length-bounded, because these
  two are the quadratic pair and bounding is what contains that, but no longer excluding separators.
  Measured at 50,000 characters the bounded-dot form is **0.795s, slightly faster** than the class it
  replaced (0.942s). **Accepted cost, now asserted in both suites so the trade stays visible:**
  `git config user.name x | grep commit.gpgsign false` prompts. Telling that apart from the real
  bypass requires tokenizing the shell, so the choice is only which way to be wrong — and a spurious
  prompt is the honest direction where a silent miss is not.
- Corrected two measured figures that were wrong in the shipped comments: the longest `-C` path the
  `{0,300}` bound admits is **295** characters, not 490; and the single-gap patterns cost ~4.3s
  rather than 1.6s at 50,000 characters, because the earlier measurement used the payload shape
  that is worst for the *nested* patterns. The whole-hook worst case at the length bound is **17.5s**
  — quadratic, not the former cubic hang, and now stated rather than left to be rediscovered.
- The `.ps1` length bound counts UTF-8 bytes (`UTF8.GetByteCount`) rather than UTF-16 code units, so
  it agrees with the `.sh` twin, which measures with `wc -c`. (`${#cmd}` counts characters in the
  CURRENT LOCALE, not bytes — believing otherwise is what made the first version of this fix invert
  the divergence instead of closing it.) The divergence ran
  fail-open: `.Length` counted low, admitting payloads the `.sh` side refused.
- Removed the redundant early tab-to-space normalization, leaving the blank-run collapse as the
  single folding site. Two sufficient paths for one property meant the tab regression tests could not
  discriminate either — neutering the original line left them byte-identically green, so the guard
  for the NBSP platform-parity bug was already dead while still looking healthy. Redundant
  normalization in a matcher does not add safety; it removes testability.
- **Closed a case-sensitivity bypass that spanned three tiers on the `.sh` side** (`[NS-37]`).
  `block()`, `block_boundary()`, `confirm()` and `warn()` all matched with a bare POSIX `case`,
  which is case-sensitive, while **every** corresponding site in the `.ps1` twin uses
  `OrdinalIgnoreCase` or `RegexOptions.IgnoreCase`. Only `confirm_regex()` (`grep -i`) and
  `confirm_boundary()` (which folded per call) already agreed. So a mixed-case payload got **no
  verdict at all** from bash and a verdict from PowerShell — `DrOp TaBlE`, `Rm -Rf`, `| BASH`,
  `--NO-VERIFY` and `SUDO RM` were each live on the shell that runs wherever `pwsh` is absent,
  which includes CI. Not cosmetic: SQL keywords are case-insensitive to the engine, and on the
  default case-insensitive Windows and macOS filesystems a shell resolves `RM` to the same
  binary as `rm`.
- Fixed at the **mechanism**, not per entry: both command views are folded once, hoisted beside
  `cmd_loose`, and all six matchers now read the same pair. The two lowercase SQL literals
  (`drop table`, `drop database`) added by an earlier per-instance patch are **removed** — they
  fixed the two entries someone thought of, left every other pattern and both other tiers
  evadable by one shifted keystroke, and were themselves evaded by a *mixed*-case spelling.
  Their removal also restores structural parity with `$blockPatterns` on the `.ps1` side, which
  never carried them.
- **Why widening the fix past the BLOCK tier could not open a new hole:** folding both sides of
  an ASCII comparison is monotone — it can only ever *add* a match, never remove one. The whole
  risk is therefore false positives, bounded by the existing word-boundary checks and pinned by
  negative controls (`| SHA256SUM`, `| Shasum` — the collision that forced `block_boundary()` to
  exist, and which this repo's own review-gate hash verification depends on). One accepted cost
  is now pinned rather than left implicit: a mixed-case trigger quoted inside a commit message
  blocks, exactly as the upper-case spelling already did.
- Added a **completeness invariant** to both suites: no matcher may match against a non-lowered
  view, asserted structurally over `scripts/` *and* `templates/scripts/`, plus a byte-identity
  check between the two mirrors. This is the check payload cases cannot make — round 9's lesson
  in this same file is that a mutation proof shows a mechanism works *where it is wired* and
  says nothing about whether every matcher is wired to it. The de-escaped-view retrofit missed
  one matcher of five; the case-folding retrofit then missed four of six.
- The cross-shell `assert_parity` helper gained a `block` arm — every parity case in the suite
  had been a CONFIRM case, so the entire BLOCK tier went unchecked for divergence, which is
  where this defect lived. Its `pass` arm now also asserts no *false* BLOCK, the failure mode a
  folding change actually risks. Absolute (non-parity) assertions were added on the `.ps1` side
  so that dropping `IgnoreCase` there cannot make the two shells agree at the wrong answer while
  the parity block stays green.

## Pending — NOT part of any release

**This section is not release notes and must not be renamed at tag-cut.** It was previously a
`### Added` block inside `[Unreleased]`, carrying a note that its contents were unshipped. The note
was correct but structurally unsafe: renaming `## [Unreleased]` to a version number — the one
mechanical step of cutting a release — would have swept four features that do not exist in this
repository into the release notes for a tag that does not contain them. Moved to its own
`##`-level section on 2026-09-02 so that rename cannot reach it.

Everything below is implemented and committed on the not-yet-merged branch
`worktree-concurrent-session-claims`, not on this branch or tag — see `[NS-18]` in
`memory-bank/activeContext.md`. Move these items into a release section only when that branch
actually merges.

### Pending — session-claims (branch `worktree-concurrent-session-claims`)
- `scripts/session-claims.sh`/`.ps1`: coordinate multiple Claude Code sessions working the same
  repo at once via a gitignored, self-pruning `.claude/session-claims.json` registry —
  `prune`/`list`/`claim`/`release`/`force-clear`/`notify`, `mkdir`-based lock with 30s staleness
  theft, atomic writes. Mirrored into `templates/scripts/`.
- New `SessionStart` hook (`notify`) auto-surfaces live claims at session start; silent when
  there's nothing to report.
- Two new `mb doctor` checks: malformed `session-claims.json`, stuck `session-claims.lock`
  directory.
- `docs/SESSION-CLAIMS-GUIDE.md`; `[NS-N]` stable-id convention for `activeContext.md`'s Next
  Steps list, documented in `standards/MEMORY-BANK.md` and wired into `CLAUDE.md`'s
  session-start/handoff protocol.

## Released history

Versions **0.1.0 (2026-04-29) through 1.2.1 (2026-08-03)** live in
`docs/archive/changelog-0.1.0-to-1.2.1.md`. They were moved there on 2026-09-07 because this file
had reached 901 lines against the 800-line hard cap in `.github/workflows/pmb-health.yml`'s File
Size job — with only 8 lines of headroom before this change. Add new released sections there, not
here.
