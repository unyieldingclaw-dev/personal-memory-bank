# Archived Progress — escalation guidance and enforcement bundle 1, 2026-08-19 through 2026-08-21

Relocated **verbatim** from `memory-bank/progress.md` on 2026-08-28 to clear the 60,000-byte CI cap
(`.github/workflows/pmb-health.yml`). Nothing was summarised, condensed, or reworded — a 2026-08-25
pass that summarised instead of moving was reverted for exactly that reason, and
`standards/MEMORY-BANK.md` now requires verbatim relocation.

**Recorded as a delta, not a level: 16,670 bytes moved out of `progress.md`.** A level would be
false the moment anything else in that file changed, which is the rule this archive's predecessor
violated and then documented.
**Citation survival was grep-verified before the move**, per `standards/MEMORY-BANK.md`'s eviction
criteria. The citation surface is larger than a list here would usefully capture: `activeContext.md`
alone carries **five** references to the 2026-08-19/20 entries (`:78`, `:89`, `:110`, `:113`, `:123`),
plus `[NS-32]` citing 2026-08-20 (continued) and 2026-08-21. **All of them resolve by matching the
heading *text*, so the check that matters is that the text survives, not that any list is complete.**
Each original heading's text is retained verbatim in `progress.md`'s pointer stub — as bold bullets
rather than `##` headers, matching the 2026-08-12 stub's existing shape — so every citation still
resolves there and lands on a pointer naming this file. (An earlier draft of this paragraph named
only two references and claimed each original `##` *heading* was retained. Both were wrong in detail
while the underlying guarantee held: the enumeration was 5x short, and the headings are demoted to
bullets. Corrected rather than quietly dropped, because a stale "verified" claim is worse than none.)

**Why this block and not another:** these four sections are the oldest contiguous run in the file,
and the *bundle-1 enforcement work* they centre on is closed — it shipped in `4bc107c` and reached
`main` in `030662c` (PR #21). **Not everything inside the range is closed**, and the header should
not be read as saying so: the 2026-08-21 section records a hook-wiring fix **withdrawn by its own
gate** (`command -v pwsh` tests existence, not viability) with its patch left in a scratchpad, and
the 2026-08-20 (continued) section carries a "Deferred, disclosed" list including cross-shell
divergence and missing pwsh coverage. Those remain open; they are archived here because the
surrounding narrative is finished, not because the items are.

---

## 2026-08-19 — Model/Effort Escalation Guidance; Review-Gate Port Design Corrected (Opus deep dive)

- 🔴 **A Sonnet-authored port design was found to be repo-breaking, on an Opus re-examination.** It split the Layer 1 (`review-reminders.sh` PreToolUse) and Layer 2 (git-hook) marker changes into two independent steps — but `consume_marker()` destroys the marker at PreToolUse time, so adding a Layer 2 marker check while Layer 1 still consumes would deny *every* agent commit and push. The flaw survived several self-review passes because the premise (that the two were separable) was never questioned. Also found: `feature/review-gate-layered-enforcement` is *behind* `main` on shared files — it still carries the unsafe `diff_hash()` trap logic reverted 2026-08-18 and predates `write_marker_atomic` — so any port must be main-forward, never a wholesale file copy. Full corrected design in `activeContext.md`'s `[NS-26]`, which supersedes `[NS-15]`'s rebase/replay approach.
- ✅ **Model- and effort-escalation guidance added to `CLAUDE.md` + `templates/CLAUDE.md`** (Token Budget section). Reframed around the user's point that quality up front *saves* tokens: rework costs a revert plus a debugging pass plus a redesign, far more than one careful pass. Escalation is now something Claude must proactively prompt for, keyed to *observable* triggers (cross-branch reconciliation, enforcement-boundary changes, 5+ files, 3+ failed fixes, spec authoring, cross-shell semantics) rather than introspection — since a model out of its depth is a poor judge that it is. Effort documented as a separate, cheaper dial: raise effort for care, raise model for premise risk. **Verified live, with a self-correction:** first pass reported `CLAUDE_CODE_EFFORT_LEVEL` as "unset everywhere" and concluded the level came from a UI selector only — an independent review caught that an effort var *is* live in the environment, just under a different name (`CLAUDE_EFFORT=high`), absent from every `settings.json` and evidently harness-injected. That is the actual reason selecting Opus left effort below its nominal default. Docs now name the real variable and tell readers to check `env | grep -i effort` rather than trusting a config file. `MAX_THINKING_TOKENS=10000` also flagged, with its interaction explicitly hedged as unverifiable from inside the repo rather than asserted. Template mirror deliberately genericized (no PMB-specific incident narrative), per the established portability convention.

- 🔴 **PreCompact freshness gate found switched off for ~2 weeks (`[NS-22]`, escalated).** `scripts/pre-compact-check.sh:10-13` bypasses the whole gate on a bare `[ -f "handoff.md" ]` check with no staleness test. The untracked 2026-08-03/04 root `handoff.md` therefore disabled it continuously, including every compaction in this session. The 2026-08-17 pass had logged those stale files as clutter and missed that their *presence* is what disables the gate. Content verified fully committed (`2fa1b63`, `fac4976`), so deletion is safe — held for user approval as a CONFIRM-tier action.
- 🔴 **Session-continuity thresholds do not cohere.** Handoff is specified at 40% but is user-triggered with nothing automating it; auto-compact fires at 65%; the global `~/.claude/CLAUDE.md` claims 50%, which is factually wrong. Consequence: sessions never hand off — they pass 40% unnoticed, compact in place at 65%, and continue indefinitely, with the only gate on that boundary bypassed. Answers the user's "shouldn't we have moved to a new session?" — auto-compact summarizes *within* a session; it never starts a new one, and nothing links the two mechanisms.
- 📌 **Overnight/unattended implication:** compaction, not handoff, is the only mechanism that survives without a human (handoff requires someone to start the next session), which makes the PreCompact gate load-bearing for autonomous runs — it must work before any overnight operation is trusted. Scheduler-driven session chaining (headless session reading memory-bank + `handoff.md`) is feasible but undesigned.
- 📌 **`[NS-27]` recovered, not newly invented:** an explicit 2026-08-15 design discussion about ACR taking over the Opposition pass (with DeepSeek as candidate backend) was never written to memory-bank and was consequently lost to compaction — the agent twice told the user no such decision existed before recovering it from the raw session transcript. A direct, self-demonstrating case for the memory-bank discipline this repo already mandates.

- 🔴 **`[NS-28]` — measured PMB's SessionStart cost at ~22,072 tokens, matching the enterprise MB figure (~21,897) the external findings doc calls a context crisis**, despite PMB being forked to be lighter. Caps are enforced on lines, not bytes; `activeContext.md` runs ~208 chars/line, so the 150-line limit permits ~2.4x its intent. Proven gameable the same day: a cap breach was resolved by reflowing 158→134 lines with identical content and zero bytes saved, CI green throughout. Stale root `handoff.md` deleted (content verified already committed) and the PreCompact gate confirmed re-activated and passing.

- 🔴 **`[NS-30]` — the memory-bank cost driver is distributed but its guardrail is not.** `templates/CLAUDE.md` ships "read ALL files in `memory-bank/`" three times while `templates/.github/workflows/` does not exist, so adopting projects inherit the mandate with no CI cap — only `mb doctor`'s ignorable warning. ACR's own audit measured the result: 190,798 bytes / ~47.7K tokens, 2.5x PMB's own footprint. PMB stays bounded solely because it holds CI its adopters never receive. Three independent audits converged on the same four systemic items, so this is a distribution defect rather than one repo's neglect.
- ✅ **`[NS-31]` shipped: PR #15 merged** (`5d573fd`). Two platform guardrails confirmed live, not
  just repo convention: push-gate marker writes are classifier-denied even from a separate
  non-authoring subagent (user wrote the marker instead); this agent hard-refuses `gh pr merge`
  regardless of explicit permission. Relevant to `[NS-26]`/`[NS-27]`'s Opposition-authority design.
- 🔴 **Branch-audit method + a self-caught evidence error (`[NS-26]` scope extension, Opus).** `git merge-tree`'s "changed in both" lines are NOT conflicts and its markers are diff-prefixed, so `grep '^<<<<<<<'` silently returns 0 — count unanchored, and count files carrying markers (16 for cross-repo-write-boundary) not "changed in both" sections (17); both errors were made here. The first draft also cited `_review-gate-lib.sh` as that branch's regression vector, but the file does not exist on it at all — the zero `write_marker_atomic` count came from absence, not staleness, and an earlier command's "FILE ABSENT" output was wrongly rationalized as a grep exit-code artifact. Caught by two independent review domains converging; the real vector is `review-reminders-post.sh`. Port-only conclusion survived; its evidence did not. **`progress.md` is now at its 400-line cap — next entry needs an archive pass first.**

## 2026-08-20 — Archive Pass; Session-Crossed-Midnight Dating Error Caught by the Gate It Broke

- ✅ **`progress.md` archive pass shipped** (PR #18, `8847714`): 400→302 lines, 41,492→31,239 bytes.
  Three completed 2026-08-18 sections moved verbatim to
  `docs/archive/progress-2026-08-18-tasks-33-35-and-handoff-redesign.md`, byte-identical, zero loss.
  Motivated by `progress.md` sitting at exactly 400/400 against a `-gt 400` FAIL cap while the
  PreCompact hook demands a fresh entry from that same file every compaction — `[NS-30]`'s F2 in practice.
- 🔴 **Dating error: this session crossed midnight and kept writing the previous day's date.** Commits
  through `716fa09` were genuinely 2026-08-19; `8847714` landed 2026-08-20 08:28, but its content
  (archive header, the inline `*(Correction …)*` marker, the `progress.md` stub, and `[NS-25]`'s
  instances 4-5) was dated 2026-08-19. **Found because the PreCompact gate began blocking** (`exit 2`,
  "no entry dated 2026-08-20") — it caught a memory-bank accuracy defect that four review domains had
  not, which argues for keeping it strict. Corrected in the stub above and in `[NS-25]`. The merged
  archive file's own `Archived 2026-08-19` provenance line is likewise off by a day and is deliberately
  left alone — rewriting merged history for a one-day slip is not worth the churn, but note the
  exemption covers only that provenance line, not the archived body (whose dates are genuinely 08-18).
- 📌 **`scripts/pre-compact-check.sh` would fail OPEN under a real POSIX `sh` — latent, not live.**
  Pre-existing, not introduced here: it declares `#!/usr/bin/env sh` but uses bash-only arrays
  (`BLOCK_REASONS=()`, `+=`, `${#…[@]}`); `dash scripts/pre-compact-check.sh` reproduces
  `Syntax error: "(" unexpected`. **Not currently reachable:** `.claude/settings.json` hardcodes
  `bash scripts/pre-compact-check.sh`, and where `pwsh` exists the `.ps1` sibling fires instead — so the
  shebang is never consulted. Worth recording anyway because `[NS-22]` makes this gate load-bearing for
  unattended operation, and the mismatch is one config edit away from mattering. One-word fix
  (shebang → `bash`), not applied here to keep this docs-only. **The severity correction is itself the
  lesson:** all four review domains read the script statically and rated it live; only tracing
  hook-config → invocation site showed it was not. Static reads over-rate reachability.
- 🔴 **Task #33's defect recurred (third occurrence) — in its milder form.** Staging the
  previously-untracked archive file *genuinely* changed `git diff HEAD`, so the commit gate correctly
  denied and re-review was warranted regardless; the marker was already stale for the new diff. What
  the defect still cost: `consume_marker()` (`scripts/review-reminders.sh:74`) does its destructive `mv`
  at line 77 **before** reading the content at line 81, so *any* denial consumes the marker whether or
  not it was valid.
  Distinct from the 2026-08-18 occurrence, where an unrelated hook (`dangerous-commands.sh`, matching
  commit-*message* text) denied a commit whose diff had NOT changed — destroying a genuinely valid
  marker, pure waste. Same root cause, different severity; an earlier draft of this entry conflated
  them, corrected on independent review. **Fresh evidence for `[NS-26]`'s non-destructive
  `peek_marker()` design, not only for `[NS-24]`.** Recorded because `[NS-24]` asserted this occurrence
  and review found it uncorroborated here.
- 📌 **`activeContext.md` archived the same day** (148→110 lines, 980→5,078 bytes of headroom), clearing
  the same deadlock. Five narrative sections evicted to
  `docs/archive/context-2026-08-20-narrative-sections.md`, each duplicating a live `[NS-N]` entry; four
  resolved entries condensed. A first pass promoted the user-as-bypass rule into Architecture
  Constraints; three review domains independently found it redundant against
  `standards/SECURITY-GUARDRAILS.md:88`, and it was dropped. The "no lite path" rule *was* promoted —
  verified absent from `standards/` entirely, so archiving it would have deleted it from the
  always-read corpus.
- 📌 **Still open after today:** the two branch-protection branches remain on `origin` despite an earlier
  record claiming deletion (`d864d99`, `8646bf3`) — `[NS-4]` carried that false claim until today too.

## 2026-08-20 (continued) — Enforcement Integrity Bundle 1 (committed 2026-08-21 as `4bc107c`)

Task contract (24 files, user-approved) governed this work. Working tree carried the full
implementation, uncommitted as of this entry; committed 2026-08-21 as `4bc107c`. Lint + suite green.

- 🔴 **The originating defect: the push gate reported success without checking.** `mb validate` was
  deprecated into a shim that prints a notice and exits 0; Check 7 read only the exit code, so
  `[OK] mb validate passed` printed on every push in every managed project while validating nothing.
  Root cause is broader than that one check: the gate modelled two outcomes (pass/fail) where there
  are three (passed / failed / **could not run**), so "could not run" rendered as "passed" — and only
  3 of 7 checks can set `FAILED`, meaning four checks could never affect their own summary.
- ✅ **Fix:** three-state model (`PASS` / `PASS with N warning(s)` / `DEGRADED`), advisory by default
  with an `ENFORCE=true` opt-in matching `memory-bank-size.yml`'s precedent. Check 7 now runs
  `mb doctor` and derives its verdict from that command's **structured output** — counting
  `[OK]/[WARN]/[ERROR]` lines gives both the result and positive evidence the command ran (real run
  ~51 lines, dead shim 0). Necessary because `mb doctor` *also* exits 0 regardless of findings, so
  switching commands alone would have preserved the bug. Dead redirect shims now `exit 2`; `update`
  deliberately excluded (live alias on POSIX).
- 🔴 **Second, more serious defect found during implementation: a secret-scanning bypass.**
  `git log --not --remotes` has no positive rev to walk from and returns NOTHING when no
  remote-tracking refs exist — silently skipping the scan in exactly the first-push case that branch
  exists to cover, while printing "no commits to push". Verified against a fresh repo with a planted
  AKIA key: 0 lines before, caught after adding explicit `HEAD`. Mutation-tested.
- 🔴 **A vacuous assertion had been hiding a broken test for the life of the file.**
  `assert_contains` uses `grep -qi`, so an unescaped `[ERROR]` is a character *class* — it matched
  almost any output. `test-mb-doctor.sh`'s check-2 assertion passed regardless of what doctor said.
  Escaping it revealed the expectation was always wrong: the fixture renamed `templates/memory-bank`
  (a subdirectory) while doctor tests the `templates/` **parent**, so `[ERROR]` never appeared.
  Re-pointed `MB_HOME` at an empty temp dir — exercises the real branch and removes the rename/restore
  data-loss window entirely. **Repo-wide implication: any test asserting a bracketed `[TAG]` may be
  passing vacuously.** Only this one instance was found, but the class is worth a sweep.
- ✅ First-ever test coverage for `pre-push-check` (28 assertions, mutation-tested against both the
  `HEAD` fix and the UNKNOWN branch). Review found and fixed: a `catch` in the `.ps1` that discarded a
  confirmed blocking finding when a later check threw; `ENFORCE` case-sensitivity divergence between
  shells; a lines-vs-matches counting divergence; and the gate reporting "51 checks" when doctor has 25
  — an unearned assertion inside the change that exists to stop unearned assertions.
- 📌 **Deferred, disclosed:** no pwsh test suite (bash-only, against repo convention); `mb update`
  cross-shell divergence documented but unresolved (live in `mb.sh`, dead shim in `mb.ps1`); extracting
  "a check that could not run must never render as PASS" into `standards/`.

## 2026-08-21 — Bundle 1 Committed; Hook-Wiring Fix Withdrawn by Its Own Review

- ✅ **`[NS-32]` committed `4bc107c`.** Full gate (6 domains + opposition); opposition falsified all 3
  blocking findings by experiment — the 58s `mb doctor` was Git-Bash fork overhead, ~0.65s on Linux.
- 🔴 **Review-gate hole, proved:** the marker hashes `git diff HEAD`, excluding untracked files — a
  reviewed new file cannot be committed, and post-review edits to it are invisible. Marker re-issued.
- ❌ **Hook-wiring fix withdrawn by its own gate:** `command -v pwsh` tests existence, not viability —
  worse than the chain it replaced. WIP patch in scratchpad; detail in the plan doc (untracked).
- ✅ **`progress.md` archive pass, clearing `[NS-33]` (d):** cleared the 400/400-line deadlock by moving
  the 2026-08-17 (continued) section verbatim to
  `docs/archive/progress-2026-08-17-branch-ancestry-and-review-gate-audit.md`, leaving a condensed
  pointer block — the swap itself removed ~54 lines net. (Deliberately no current line count here:
  a self-referential total goes stale on the next edit, which is how the first draft of this entry got
  it wrong.) Second cap deadlock in three days (`8847714` was the first); `mb clean` only prints advice
  (`scripts/mb.sh:378`), so every breach is a manual pass behind a full gate. Note the line cap is the
  **only** binding control on this file today — it runs near its 400-line cap while sitting around half
  its 60 KB byte cap — so `[NS-28]`'s retire-the-line-cap idea needs its own pass; it would remove the
  sole active constraint, not a redundant one.

