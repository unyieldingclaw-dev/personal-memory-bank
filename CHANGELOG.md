# Changelog

## [Unreleased]

### Added
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

## [1.2.1] — 2026-08-03 (mb.ps1 review-reminders export gap)

### Fixed
- `scripts/mb.ps1`: `Invoke-Init`'s hook-scripts copy loop excluded `review-reminders.sh`/`.ps1` and `review-reminders-post.sh`/`.ps1` — only `Invoke-Upgrade`'s `$templateOwned`/gap-detection got the 1.2.0 (review-gate hardening) fix, so a fresh PowerShell `mb init` shipped a `settings.json` referencing hook scripts never actually copied into `scripts/` (they'd only appear on a subsequent `mb upgrade`). This closes the PowerShell-side twin of the same-day `mb.sh` fix below. Added regression coverage: `tests/mb-setup.Tests.ps1` asserts `mb init` (subprocess) creates all 4 files.

## [1.2.1] — 2026-08-03 (mb.sh review-reminders export gap)

### Fixed
- `scripts/mb.sh`: `templates/.claude/settings.json` invokes `scripts/review-reminders.sh`/`.ps1` and `scripts/review-reminders-post.sh`/`.ps1` directly for the commit/push review gate, but none of the 4 files were in `mb init`'s hook-scripts copy loop or `mb upgrade`'s `TEMPLATE_OWNED` array — a fresh `mb init`/`mb upgrade` shipped a `settings.json` referencing hook scripts that were never actually copied into the target project's `scripts/` directory, silently disabling the review gate for every project onboarded via `mb.sh` (only this repo's own native copies worked). `scripts/mb.ps1` got the `TEMPLATE_OWNED` half of this fix in 1.2.0 (review-gate hardening) but not the corresponding `mb.sh` change — this closes that parity gap. Added regression coverage: `tests/test-mb-init.sh` asserts all 4 files are created by `mb init`; `tests/test-mb-upgrade.sh` asserts `mb upgrade` restores them via `TEMPLATE_OWNED`.

### Known gap, not fixed here (closed above)
- `scripts/mb.ps1`'s `Invoke-Init` copy loop also excludes these 4 files (only its `TEMPLATE_OWNED`/gap-detection got the 1.2.0 fix) — PowerShell `mb init` on a fresh project has the same bug. Tracked separately.

### Changed
- `scripts/review-reminders.sh/.ps1` + `-post.sh/.ps1`: `sha256_file`/`diff_hash`/`resolve_cd_root` (bash) and `Get-FileHashHex`/`Get-CommitDiffHash`/`Get-PushDiffHash` (PowerShell) were duplicated verbatim across all 4 files (a fix to one had to be manually ported to the others, and had already missed once — see the 2026-07-09 trailing-newline bug). Extracted into new shared dot-sourced libs, `scripts/_review-gate-lib.sh`/`.ps1` (mirrored in `templates/scripts/`); all 4 hook files now dot-source instead of defining locally. `review-reminders-post.ps1` also now calls the shared `Get-CommitDiffHash`/`Get-PushDiffHash` instead of inlining its own third copy of the same pattern (confirmed byte-identical output before and after — a structural dedup, not a behavior fix).
- A missing/corrupt lib file makes the sourcing hook fail open (gate skipped), matching this repo's established convention — but since a dot-sourced file is invisible to the existing settings.json-derived hook-existence checks, added a new hardcoded check (`scripts/check-review-gate-lib-presence.sh`, called by both `mb doctor` and the CI `template-integrity` job) so this new failure mode doesn't slip through undetected the way `review-reminders*.sh/.ps1` themselves briefly did.

## [1.2.1] — 2026-07-04 (template scaffolding gap)

### Fixed
- `templates/CLAUDE.md` references `docs/CONTRACTS-GUIDE.md` and `docs/HOOKS-GUIDE.md`, but neither file existed anywhere under `templates/` — `mb init`/`mb upgrade`/`mb setup` never scaffolded them into downstream projects, leaving every project's `CLAUDE.md` pointing at docs that don't exist. Discovered via `mb-setup.bat` flagging governance gaps on an existing project.
- Added `templates/docs/CONTRACTS-GUIDE.md` (verbatim copy of PMB's own guide, already generic) and `templates/docs/HOOKS-GUIDE.md` (trimmed — dropped PMB-repo-specific "bug found and fixed" postmortem prose, kept the reusable hook reference).
- `scripts/mb.ps1`: `Invoke-Init`, `Invoke-Upgrade`'s `$templateOwned`, and `Get-MbUpgradeAnalysis`'s gap-detection now all auto-discover `templates/docs/*.md` (same pattern already used for `templates/claude-commands/*` — a hardcoded list of these went stale before, per the existing comment on that fix).
- `scripts/mb.sh`: `invoke_init` now copies `templates/docs/*`; `invoke_upgrade`'s `ADVISORY_CREATE` now includes both doc files (create-if-missing, matching how `mb.sh` already handles other reference docs).

### Remediation for already-scaffolded projects
Any project that ran `mb init`/`mb setup` before this fix has a `CLAUDE.md` with dangling doc references. Re-running `mb upgrade` in that project after upgrading to PMB 1.2.1 will create the two missing files (now template-owned / advisory-create, so "create if missing" applies retroactively).

## [1.2.0] — 2026-07-03 (review-gate hardening)

### Fixed
- `scripts/dangerous-commands.ps1/.sh`, `scripts/check-contract.ps1/.sh`: read the wrong JSON field path (flat `.command`/`.file_path` instead of nested `tool_input.command`/`tool_input.file_path`) and signaled denial via exit codes, which `settings.json`'s fail-open wrapper silently erased — both hooks were near-total no-ops. Fixed to use `hookSpecificOutput.permissionDecision: "deny"`.
- `scripts/check-contract.ps1/.sh`: schema bug — read `scope.files` instead of the documented `scope: [{file, op}]` array. `.sh` version also had a Windows CRLF bug from Python's `print()` breaking exact-match comparisons.
- `scripts/dangerous-commands.ps1/.sh`: pipe-to-shell BLOCK pattern collided with `sha256sum`/`shasum` — fixed with word-boundary matching.
- Hash mismatch between documented review-gate commands and hook verification: PowerShell's pipeline re-tokenizes external-command output, so array-join hashing didn't reproduce the byte stream a raw shell pipe sees. Fixed by hashing a file written via redirection instead.
- `.claude/settings.json` + `templates/.claude/settings.json`: stale `CLAUDE_AUTOCOMPACT_PCT_OVERRIDE=40` bumped to `65` to match current guidance.

### Added
- `scripts/review-reminders.ps1/.sh` + `-post.ps1/.sh`: `PreToolUse`/`PostToolUse` hook pair mechanically enforcing review-before-commit/push via a SHA-256 diff-hash marker (see ai-code-review-agent CHANGELOG for full design). Wired into PMB's own live `.claude/settings.json` (dogfooding) and added to `scripts/mb.ps1`'s `$templateOwned` list so `mb init`/`mb upgrade` distribute it to downstream projects.
- `docs/HOOKS-GUIDE.md`: documented the fixed dangerous-commands/check-contract mechanisms and the review-gate hash-binding/atomic-consume/reissue design.

## [1.2.0] — 2026-07-04 (CI health fixes)

### Fixed
- **`.github/workflows/pmb-health.yml` SAST job** — `semgrep --config "p/bash"` returned HTTP 404 (no longer a resolvable registry ruleset); switched to `--config auto`.
- **Rules-File Integrity "hidden HTML comments" check** — false-positived on `standards/RULES-FILE-INTEGRITY.md`'s own backtick-wrapped documentation examples. Refined to strip fenced code blocks and paired inline-code spans before matching, with two guard rails found necessary through two rounds of adversarial review: (1) an odd count of ``` fence markers falls back to inline-only stripping, so a malformed fence can't hide the rest of a file from the check; (2) an odd count of backticks *on a single line* leaves that line unstripped entirely, since a naive `` s/`[^`]*`//g `` still pairs a stray backtick with an unrelated later one and silently deletes everything between — including a real hidden comment placed right after the stray backtick. (Two earlier variants — a single-character negative lookbehind, then a stripper without the per-line parity guard — were each found bypassable in review and replaced before shipping.)
- **Forbidden Patterns "spec placeholder grep"** — false-positived on two spec docs' own code-formatted examples of the TBD/TODO pattern. Uses the identical strip-fenced-code-and-paired-backticks helper (with both guard rails) as the fix above.
- **PowerShell Lint** — added `scripts/PSScriptAnalyzerSettings.psd1` excluding `PSAvoidUsingWriteHost` project-wide (every `.ps1` here is a CLI/hook script whose job is console output); added `Write-Verbose` diagnostics to 22 previously-empty `catch {}` blocks; added a UTF-8 BOM to the 17 `.ps1` files that needed it; renamed `Normalize-MbLine` → `Format-MbLine` in `mb.ps1` (not an approved PowerShell verb); removed the dead `Invoke-InstallHooks` function (~92 lines, zero call sites); added targeted suppressions for `$DryRun`/`$Force` false-positive unused-parameter warnings (both read via script-scope chaining in nested functions).
- **`.claude/commands/change-review.md` marker-hash commands** — both the Bash and PowerShell snippets were missing the `git diff HEAD` fallback that `scripts/review-reminders.sh`/`.ps1` actually use when no `origin/main` upstream exists; added to match exactly.

### Added
- **`.claude/commands/change-review.md` Step 3.5 — Baseline Repo Health** — a new informational-only, offline-only spot-check against the whole working tree (not diff-scoped), so a diff-clean review doesn't silently approve a change sitting on a CI-red base branch. Never blocking; explicitly excludes network-dependent tools (Semgrep, PSScriptAnalyzer, gitleaks), which remain CI-only per this repo's layered-enforcement design.

## [1.2.0] — 2026-07-03 (agent frontmatter fix)

### Fixed
- **`.claude/agents/*.md` missing `name:` field** — Claude Code silently fails to register a custom subagent without a `name:` frontmatter field; `researcher.md` and `security-reviewer.md` (plus their `templates/.claude/agents/` copies) had this bug. Added `name:` to all 4 files.
- **`.claude/commands/health-check.md`** — corrected a mislabeled "Check 24" reference to the actual staleness check (check 9); removed the only non-functional `@agent-name` invocation-syntax mention in the repo.
- **`mb doctor` check 25 ("Agent frontmatter") elif-suppression** — a directory with both a missing-`name:` agent and a mismatched-`name:` agent only reported the first; now both report independently.
- **`mb doctor` check 25 `name:` extraction** — now scoped to the frontmatter block only (was scanning the whole file), strips surrounding quotes, and no longer over-strips internal spaces from multi-word values, on both `mb.sh` and `mb.ps1`.
- **`mb.ps1` check 24 (Plan hygiene) port** — was previously missing entirely from `mb.ps1`, leaving `mb.sh`/`mb.ps1` doctor check counts out of sync; ported, including a `ParseExact` try/catch guard matching sibling call sites (was unguarded, could abort the rest of `mb doctor` on an unparseable git date) and a frontmatter-presence match aligned with `mb.sh`'s looser `grep -c '^---'` behavior.
- **"24 checks" → "25 checks"** — updated `README.md` (both occurrences), `.claude/commands/health-check.md`, `docs/COMMANDS-REFERENCE.md` (was already stale at "20 checks"; table extended through check 25), and `tests/test-mb-doctor.sh` header.

### Added
- **`mb doctor` check 25 ("Agent frontmatter")** — scans `.claude/agents/*.md`, warns on missing or filename-mismatched `name:` fields, in both `mb.sh` and `mb.ps1`.
- **`mb doctor` check 25 live/template parity check** — in the PMB source repo (where `templates/.claude/agents/` exists), warns if a live agent file diverges from its template copy.

## [1.2.0] — 2026-06-26 (additional hardening)

### Fixed
- `scripts/mb.sh`: doctor check 5 token budget drift — replaced `grep -c` with `grep -q` + explicit 0/1 assignment (was permanently SKIP in Git Bash due to double-output bug)
- `tests/test-mb-doctor.sh`: added EXIT trap guards to all 4 sites that mutated `$REPO_ROOT` directly — git status now clean after any test outcome
- `scripts/check-contract.sh` + `.ps1`: empty scope `[]` no longer fires spurious out-of-scope warning; malformed JSON now emits visible warning instead of silent pass; handles both ACR `[{file,op}]` and PMB `{files:[]}` scope schemas
- `.claude/commands/health-check.md`: removed deprecated `mb validate` and `mb audit` (now aliases for `mb doctor`); replaced with `mb status` and doctor staleness review
- `.github/workflows/pmb-health.yml`: PSScriptAnalyzer now checks `-Severity Error,Warning`; gitleaks-action pinned to commit SHA `ff98106e`

### Added
- `.github/dependabot.yml`: weekly GitHub Actions version tracking
- `.claude/commands/change-review.md` Job 7: now passes `--diff <tmpfile>` to ACR (was reviewing wrong diff surface for non-default invocations)

---

## 1.2.0 — 2026-06-24

### Added
- **Comprehensive bash test suite** — expanded from 3 tested commands to all 11 `mb` commands. Added 8 new test files covering `mb doctor` (25 cases — all 24 checks + clean baseline), `mb status` (6 cases), `mb verify-integrity` (3 cases), `mb query` (4 cases), `mb init` (3 cases), `mb clean` (2 cases), `mb commit` (2 cases), and `mb upgrade` (3 cases). Total test count: 115 assertions across 11 suites.
- **CI: `powershell-lint` job** — PSScriptAnalyzer at Error severity on all `.ps1` files in `scripts/` and `templates/scripts/`. CI now has 9 jobs total.
- **CI: `mb-doctor-self-check` job** — runs `mb doctor` against the PMB repo itself on every push, surfacing drift in memory-bank, standards count, plan hygiene, and hook config.

### Fixed
- **`mb doctor` check 2 + check 13 fixture restore hardened** — test previously renamed entire `templates/` or `fixtures/security/` directories; now renames a single subdirectory with conditional restore, preventing data loss if interrupted.

### Changed
- **`mb doctor` checks 22 & 23: O(n²) → pre-cached normalization** — normalized strings are now pre-built once before the outer loop in both `mb.sh` and `mb.ps1`, eliminating ~10,000 subprocess spawns per doctor run on 100-line files.
- **`show_budget` find pipe** — replaced `find | xargs wc -c` with `find -exec wc -c {} +` (single `wc` call instead of one per file) in `mb.sh`.
- **`mb help` deprecated aliases** — both `mb.sh` and `mb.ps1` now show a `Deprecated aliases` section at the bottom of help output. `mb.ps1` Show-Help also gains `plan`, `preflight`, and `change-check` in the active commands list (parity with `mb.sh`).

### Documentation
- **`docs/HOOKS-GUIDE.md`** — added section 6 (Agent Delegation Depth Check) documenting the `.pmb-delegation-depth` runtime state file, 2-hour reset behavior, and error logging.
- **`.claude/commands/health-check.md`** — corrected `mb doctor` check count from 20 to 24.

---

## 1.1.2 — 2026-06-24

### Fixed
- **`settings.json` invalid JSON** — missing comma in the `permissions.allow` array (after `"Bash(python -m ruff *)"`) caused strict JSON parsers to reject the file. Added the missing comma.
- **`pre-compact-check` false positives** — the progress.md date check used a free substring search (`grep -q "$today"`), which matched dates embedded in prose (e.g. "see spec from 2026-06-24") and incorrectly allowed compaction. Fixed to require the date at the start of a line (optionally preceded by a markdown heading or list prefix). Applied to `scripts/pre-compact-check.sh`, `scripts/pre-compact-check.ps1`, and their template copies.
- **Missing `TRUNCATE TABLE` and `DELETE FROM` guardrails** — both patterns were listed as CONFIRM-tier in `standards/SECURITY-GUARDRAILS.md` but absent from the dangerous-commands scripts. Added to `scripts/dangerous-commands.sh`, `scripts/dangerous-commands.ps1`, and their template copies. Shell scripts include explicit lowercase variants for POSIX case-sensitivity parity; PowerShell uses its native case-insensitive matching.
- **`templates/scripts/pre-compact-check.sh` stale whitespace trimming** — template was still using a `sed` subprocess per line; synced with the live script's pure bash parameter expansion (~100 fewer process spawns per compaction check).

### Documentation
- **`docs/HOOKS-GUIDE.md`** — updated CONFIRM pattern count from 5 to 7; corrected PreCompact detection logic description from mtime-based to content-based (the actual implementation).

---

## 1.1.1 — 2026-06-18

### Fixed
- **`check-contract.ps1` / `check-contract.sh` stdin fix** — both live and template copies were reading tool input from `$env:CLAUDE_TOOL_INPUT` (PowerShell) / `os.environ.get('CLAUDE_TOOL_INPUT')` (bash), an env var that Claude Code never sets. Hooks were silently failing open on every invocation. Fixed to read stdin: `$input | Out-String` (PowerShell) and `HOOK_INPUT=$(cat 2>/dev/null)` (bash).
- **`mb.sh` TEMPLATE_OWNED parity** — `scripts/pre-push-check.sh` and `scripts/pre-push-check.ps1` were missing from the bash `TEMPLATE_OWNED` array; `mb upgrade` on bash systems would silently skip overwriting these files. `mb.ps1` and the `invoke_init` for-loop already had them. Now consistent across all four sites.
- **`docs/HOOKS-GUIDE.md` per-project example** — "Lint Before Commit" example used `echo "$CLAUDE_TOOL_INPUT"` (same broken env-var pattern). Fixed to `HOOK_INPUT=$(cat 2>/dev/null); echo "$HOOK_INPUT"`.
- **`docs/QUICK-REFERENCE.md` doctor check count** — description read "16-point diagnostic"; doctor has had 20 checks since v1.0.8.

---

## 1.1.0 — 2026-06-11

### Changed
- **Git hooks migrated to `core.hooksPath = .githooks`** — hooks are now versioned in the project repo (`.githooks/pre-push`, `.githooks/pre-commit`) and distributed via `mb upgrade` (TEMPLATE_OWNED). `mb init` and `mb upgrade` set `core.hooksPath = .githooks` automatically. `mb upgrade` performs one-shot cleanup of the old `.git/hooks/pre-push` shim on legacy projects.
- **Pre-commit hook now active** — `.githooks/pre-commit` existed in the PMB repo but was dead (`core.hooksPath` not set). Now fires on every commit: blocks `handoff.md` staging, warns if `CLAUDE_AUTOCOMPACT_PCT_OVERRIDE` is missing from `.claude/settings.json`.
- **`mb doctor` check 4 updated** — verifies `.githooks/pre-push` presence and `core.hooksPath = .githooks`; bash doctor gains equivalent check (previously missing).
- **`docs/HOOKS-GUIDE.md`** — new "Git Hooks (versioned)" section documents the two hooks, `core.hooksPath` activation, and migration path from `.git/hooks/`.

### Breaking
- Projects using PMB hooks must run `mb upgrade` to activate the new layout. After upgrade, `.git/hooks/pre-push` is removed (if it is the PMB shim) and hooks run from `.githooks/` instead.

---

## 1.0.9 — 2026-06-11

### Added
- **`mb update` alias** — `mb update` now runs the same upgrade logic as `mb upgrade`; documented in `docs/COMMANDS-REFERENCE.md`

### Changed
- **Hook script performance** — behavioral no-ops, same output, fewer processes:
  - `check-contract.sh`: 3 Python spawns + 6 sed subshells → single Python heredoc invocation
  - `pre-compact-check.sh`: sed subprocess per line → bash parameter expansion
  - `mb doctor` check 10: 7 grep calls per file → 1 combined grep per file
  - `mb doctor` check 17: echo|grep per line (~400 subshells) → grep directly on file (2 calls)

---

## 1.0.8 — 2026-06-06

### Added
- **Command consolidation finalized** — `mb verify-integrity` added as an explicit command; all 8 deprecated aliases updated to clearer redirect messages; `mb clean` output references corrected from `mb slim`/`mb archive`/`mb compact`
- **`mb doctor` Check 17 — Semantic drift detection** — scans `activeContext.md` and `progress.md` for transition/removal language (`deprecated`, `migrated from`, `replaced by`, `no longer`, `switching from`, etc.) and surfaces matching lines for human review against stable files; heuristic, low-noise (skips frontmatter, headings, blank lines)
- **`mb doctor` Check 18 — Old stable decisions** — flags `authority:stable` or `authority:immutable` files whose `last-reviewed` date is >180 days ago; prompts review to confirm decisions are still accurate
- **`mb doctor` Check 19 — Cross-file contradiction detection** — verifies authority hierarchy is consistent with PMB conventions (`projectbrief.md=immutable`, `systemPatterns.md/techContext.md=stable`, `activeContext.md=volatile`, `progress.md=accumulating`); also checks for negation language under shared `##` headings across stable vs. volatile files
- **`mb doctor` Check 20 + `mb verify-integrity` — Integrity checksums** — computes SHA-256 of all 5 memory-bank files; stores in `.pmb-checksums` (gitignored); on next run, compares against baseline and reports [ERROR] for any file modified outside mb tooling; `mb verify-integrity` runs this check standalone
- **Compaction quality gate** — `pre-compact-check.ps1`/`.sh` now BLOCK compaction (exit 2) unless: (1) `activeContext.md` has ≥3 substantive content lines and (2) `progress.md` has an entry dated today; `handoff.md` bypasses the gate; errors remain fails-open (exit 0)
- **Agent delegation depth enforcement** — new `scripts/delegation-depth-check.ps1`/`.sh`; wired as `PreToolUse` hook on the `Agent` tool in `.claude/settings.json`; emits WARN when delegation depth exceeds budget (≤1 per `PERFORMANCE-BUDGET.md`); state stored in `.pmb-delegation-depth` (gitignored), resets after 2h inactivity
- **`mb doctor` checks 15–16 added to `mb.sh`** — previously only in PowerShell; bash script now has parity on startup context ceiling and hook error log checks
- **`.gitignore` entries** — `.pmb-checksums`, `.pmb-delegation-depth`, and `.pmb-hook-errors.log` added to project root `.gitignore`; `mb init` now adds all three to new project `.gitignore`
- **`standards/AGENTIC-SAFETY.md`** — new "Agent Delegation Depth Enforcement" section documenting the hook behavior, threat model, budget limit, and how to disable

### Changed
- `mb init` allowlist expanded: `delegation-depth-check.ps1`/`.sh` added to exported hook scripts
- `mb upgrade` `TEMPLATE_OWNED` expanded: `delegation-depth-check.ps1`/`.sh` now overwritten on upgrade
- `docs/COMMANDS-REFERENCE.md` — updated to 20-check doctor table; `mb verify-integrity` added to command table
- All deprecated alias redirect messages changed from past-tense to present-tense ("has been integrated" → "is now part of")

---

## 1.0.7 — 2026-06-06

### Added
- **G1 — PowerShell tool hook** — `dangerous-commands.ps1` now intercepts both the Bash and PowerShell Claude Code tools; 8 PowerShell-native BLOCK patterns added: `Remove-Item -Recurse -Force`, `Remove-Item -Force -Recurse`, `Format-Volume`, `| Invoke-Expression`, `|Invoke-Expression`, `| iex`, `|iex`; both `.claude/settings.json` and `templates/.claude/settings.json` updated
- **G2 — Hook failure alerting** — all 4 hook scripts (`dangerous-commands`, `check-contract`, `pre-compact-check`, `update-reviewed`) append a timestamped entry to `.pmb-hook-errors.log` on unexpected error; `mb doctor` Check 16 reports log presence and recent entries as WARN; `mb init` adds `.pmb-hook-errors.log` to `.gitignore` for new projects
- **G3 — Contract scope hard-block mode** — `PMB_CONTRACT_HARD_BLOCK=1` env var promotes contract scope warnings to hard blocks (exit 2) in both `check-contract.ps1` and `check-contract.sh`; documented in `standards/SECURITY-GUARDRAILS.md` with `env` block example
- **G4 — First-push secret scan** — `pre-push-check.ps1` / `.sh` now falls back to `git log --not --remotes -p` when no upstream tracking ref exists, scanning all commits not yet on any remote; large-files check (Check 6) also fixed for the no-upstream case; replaces the previous `[SKIP]` behavior
- **G5 — Rules-file integrity CI** — new `rules-file-integrity` job in `pmb-health.yml`: three steps — invisible Unicode characters (U+200B/C/D/FEFF/202E/00AD/2066-2069), hidden HTML comments (`<!--`), LLM bypass phrases in `CLAUDE.md` / `templates/CLAUDE.md`
- **G6 — SAST CI** — new `sast` job in `pmb-health.yml`: Semgrep CLI with `p/bash` ruleset scanning `scripts/` and `templates/scripts/`; exits non-zero on any finding
- **`mb doctor` Check 15** — startup context size ceiling: WARN if `CLAUDE.md` + `memory-bank/` total exceeds 15 KB, ERROR if over 25 KB
- **`mb doctor` Check 16** — hook error log: WARN with entry count and last 3 lines if `.pmb-hook-errors.log` exists and is non-empty
- **`install.bat`** — GUI folder picker to init first project at install time; `mb-new-project.bat` launcher; `pick-folder.ps1` helper

### Changed
- **mb commands redesigned (8 primary commands)** — `mb doctor` now absorbs `audit`, `validate`, and `budget`; `mb clean` added (absorbs `compact`, `update`, `archive`, `slim`); `mb upgrade` absorbs `install-hooks`; deprecated commands still work as redirects; `mb help` updated to show 8 primary commands
- **`.pmb-version`** initialized in the PMB repo itself (was missing)

---

## 1.0.6 — 2026-06-03

### Changed
- **`standards/CODE-REVIEW.md`** — replaced `Confidence: High|Medium|Low` with `Basis: VERIFIED|INFERRED|SPECULATIVE`; added Basis Classification and Evidence Requirements sections with per-basis evidence rules; tightened blocking semantics (`Blocking: true` requires `Severity >= High AND Basis != SPECULATIVE`); updated Required Report Sections to `Supported Findings` + `Predicted Risks`; added three new Failure Criteria (missing `file:line`, evidence not materially supporting claim, SPECULATIVE marked blocking); added Compatibility Note
- **`templates/standards/CODE-REVIEW.md`** — mirrors `standards/CODE-REVIEW.md` (distribution template)
- **`.claude/commands/code-review.md`** — Step 4 updated to reference `Basis` field definitions; Step 6 report template split into `## Supported Findings` (VERIFIED/INFERRED) and `## Predicted Risks` (SPECULATIVE, omitted if empty)
- **`templates/claude-commands/code-review.md`** — mirrors `.claude/commands/code-review.md`

**Breaking change:** `Confidence` field removed from the code review finding schema. Consumers parsing review output must update to `Basis`.

*(Note: VERSION 1.0.5 was not bumped at the time of that release; version counter corrected here.)*

---

## 1.0.5 — 2026-06-03

### Added
- **`/pmb-status` slash command** — fast state check (the `git status` of PMB); answers "can I work?" with 5 signals: Initialized, Core Memory Present, Active Context Current, Standards Available, Tasks Present; surfaces attention items with one-line remediation hints; no deep validation (that belongs in `/health-check`); distributed via `mb init` and `mb upgrade`
- **`templates/claude-commands/pmb-status.md`** — distribution template for `/pmb-status`

### Changed
- **`mb status`** — replaced file-size table with the same 5-signal state check that backs `/pmb-status`; now answers "can I work?" rather than "are files within size limits?" (size budget info remains available via `mb doctor`)

---

## 1.0.4 — 2026-05-31

### Added
- `standards/SECURITY-RULES.md` — rule registry (SEC-001–009) for structured security findings
- `standards/TRUST-CLASSIFICATION.md` — TRUSTED/SEMI_TRUSTED/UNTRUSTED source classification reference
- `standards/PERFORMANCE-BUDGET.md` — explicit limits for standards count, memory entries, agent delegation depth
- `fixtures/security/` — 9 known-bad code samples for security regression testing (SEC-001–009)
- `mb doctor` Check 13: verifies `fixtures/security/` structure (9 subdirectories)
- `mb doctor` Check 14: counts `standards/*.md` files; warns if > 20
- `/health-check` step 5: runs `/security-review` against security fixtures, reports caught/missed per rule ID
- Structured finding format for `/security-review` command and security-reviewer agent: Rule ID, Evidence, Confidence, Fix
- Trust level note in security-reviewer agent for prompt-injection and rules-file-integrity findings
- All 3 new standards distributed via `mb init` and `mb upgrade` (ADVISORY_CREATE)

---

## 1.0.3 — 2026-05-29

### Added
- **Standards distribution** — `mb init` now copies 12 `standards/` files (`CODE-REVIEW.md`, `WORKFLOW.md`, `SECURITY-GUARDRAILS.md`, `CODE-QUALITY.md`, `ACCESSIBILITY.md`, `AGENTIC-SAFETY.md`, `LOGGING.md`, `MCP-SECURITY.md`, `MEMORY-BANK.md`, `RULES-FILE-INTEGRITY.md`, `SECRETS.md`, `SUPPLY-CHAIN.md`) into new projects so slash commands can reference governance contracts at runtime
- **`ADVISORY_CREATE` category in `mb upgrade`** — standards files are created if missing in adopted projects; shows advisory diff if the file has been customized rather than silently overwriting
- **`.pmb-version` tracking** — `mb init` writes `.pmb-version` to the target project; `mb upgrade` writes and checks it against the local PMB version
- **Remote version check in `mb upgrade`** — soft non-blocking check against GitHub `VERSION` at upgrade time; warns if a newer PMB version is available; silently skips if unreachable
- **`mb doctor` check 11** — warns if any of the 4 required standards files (`CODE-REVIEW.md`, `WORKFLOW.md`, `SECURITY-GUARDRAILS.md`, `CODE-QUALITY.md`) are missing; advises `mb upgrade` to install
- **`mb doctor` check 12** — warns if `.pmb-version` is absent or drifted from the local PMB version; advises `mb upgrade`
- **Pre-push git hook** — `scripts/pre-push-check.ps1` (Windows/pwsh) and `scripts/pre-push-check.sh` (POSIX/bash) with 7 checks: merge conflicts, conflict markers, dirty tree, missing `.gitattributes`, secrets scan (blocks on AWS/API/PAT patterns), large files >500 KB, and `mb validate`; distributed via `mb init`; `templates/hooks/pre-push` shim auto-detects pwsh/bash at runtime
- **`mb install-hooks`** — retrofit subcommand for projects that ran `mb init` before the pre-push hook was added; copies hook scripts and installs `.git/hooks/pre-push`; supports `--dry-run`

---

## 1.0.2 — 2026-05-27

### Added
- **`/test-audit` command** — inline diagnostic for test coverage gaps; covers scope detection, framework auto-detect (Jest, Vitest, pytest, Go, RSpec, Rust), source-to-test mapping, empty test file check, framework config check, and CI test step check; severity: [HIGH] missing, [MEDIUM] empty/CI gap, [LOW] no framework/config/CI
- **`/health-check` command** — PMB-specific repo health check; runs `mb doctor` + `mb validate` + `mb audit` and prints a labeled summary with overall status (PMB repo only, not distributed via `mb init`)
- **`docs/COMMANDS-REFERENCE.md`** — comprehensive reference for all `mb` CLI commands, slash commands, Claude Code built-in commands, and `mb doctor` check details

### Fixed
- `mb upgrade` now includes `.claude/commands/test-audit.md` in `$templateOwned` so adopted projects receive the test-audit command on upgrade
- README version badge corrected from `1.0.0` to `1.0.2`

---

## 1.0.1 — 2026-05-27

### Fixed
- Stop hook documentation: heading now reads "excluded from install template"; clarified that PMB's own `.claude/settings.json` keeps it deliberately for interactive Windows sessions
- Contract threshold: raised from "more than one file" to "4 or more files" with sensitive-domain list
- Compaction/handoff language: corrected numerically backwards sentence about 50%/40% thresholds
- CI workflow renamed: `governance.yml` → `pmb-health.yml`; internal `name:` updated to "PMB Health"

---

## 1.0.0 — 2026-05-14

First stable personal release. Crossed from "organized prompt files" into governed operational memory infrastructure.

### Added
- **Authority hierarchy** — deterministic conflict resolution between memory-bank files (immutable → stable → volatile → accumulating)
- **3-dimension frontmatter** — `review-cycle`, `retention`, `staleness-threshold` replacing a coarse single `ttl` field
- **Hierarchical tags** — `domain/concept` format (`auth/session`, `infra/postgres`) replacing flat tags
- **Automated `last-reviewed`** — PostToolUse hook updates frontmatter whenever a memory-bank file is edited
- **Partitioned archive** — `docs/archive/context/`, `docs/archive/progress/`, `docs/archive/decisions/` replacing a single monolithic ARCHIVE.md
- **`mb audit`** — freshness audit flagging stale and overdue files by staleness-threshold
- **`mb query`** — tag-based retrieval with partial hierarchical matching
- **`mb compact`** — AI-driven compaction prompt for deduplication and summarization
- **`mb init`** — zero-config project initializer with checkmark UX
- **`mb validate`** — required-file and frontmatter health check
- **`mb doctor`** — full diagnostic (git, templates, hooks, file sizes, handoff state)
- **`mb budget`** — token overhead check (CLAUDE.md + memory-bank/ sizes)
- **Worktree guard** — `mb commit` refuses mutations from git subworktrees
- **`install.bat`** — Windows double-click installer (sets MB_HOME, registers `mb` globally)
- **`install.sh`** — Mac/Linux installer (sets MB_HOME in shell rc, registers `mb` globally)
- **`scripts/update-reviewed.ps1` + `.sh`** — PostToolUse hook scripts for auto last-reviewed
- **AGENTIC-SAFETY.md** — indirect prompt injection defense and task boundary standard
- **`task-boundary.md` template** — agentic session scoping

### Changed
- **README** — rewritten outcomes-first with progressive disclosure (advanced features behind collapsible sections)
- **MEMORY-BANK.md** — added authority tiers, eviction criteria, archive structure, worktree guidance, tag-based retrieval, and memory compaction sections
- **Archive strategy** — all references to monolithic `docs/ARCHIVE.md` replaced with partitioned `docs/archive/`
- **`mb help`** — reorganized with new commands listed first; examples added

### Removed
- Monolithic archive pattern (`docs/ARCHIVE.md`) — replaced by partitioned subdirectories

---

## 0.2.0 — 2026-05-01

Personal standard modernization. Added 2025 Claude Code features.

### Added
- Hooks template with dangerous-command blocker (PreToolUse)
- `.claude/agents/` — `researcher.md` and `security-reviewer.md` subagent definitions
- AI antipatterns + dependency validation in `/code-review` command
- Verification-first pattern in WORKFLOW.md phase 4
- `external-content-is-data` rule in CLAUDE.md and AGENTIC-SAFETY cross-reference
- Token budget section in CLAUDE.md and global `~/.claude/CLAUDE.md`
- Karpathy coding principles
- `mb budget` command

---

## 0.1.0 — 2026-04-29

Initial personal fork from enterprise Memory Bank standard.

### Changed
- Stripped Eric Nolan branding, binary assets, enterprise training materials
- Removed compliance-only standards (Data Classification, Model Governance, OWASP LLM Top 10)
- Removed incident runbooks, team onboarding scripts
- Trimmed CLAUDE.md, LOGGING.md to personal-use scope

### Kept
- Memory Bank 5-file system + handoff protocol
- Security Guardrails (BLOCK/CONFIRM/WARN)
- Code Quality, Workflow, Logging standards
- Supply Chain, MCP Security, Rules-File Integrity (reference)
- Claude Code commands (`/code-review`, `/feature-dev`, `/security-review`)
- Cursor rules
- Init scripts, mb utility
