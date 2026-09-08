---
description: "Deep code review covering security, correctness, maintainability, testing, and architecture drift. Uses Claude (cloud API) — sends diff content to Anthropic. Some environments may have a personal, machine-local /ai-review command (Ollama-based, not shipped by this repo) as an offline alternative; if unavailable, this cloud-based review is the supported path. Spawns separate subagents per domain so findings don't bias each other."
allowed-tools:
  - Bash(git diff *)
  - Bash(git log *)
  - Bash(git status *)
  - Bash(git grep *)
  - Bash(git cat-file *)
  - Bash(git ls-tree *)
  - Bash(find *)
  - Bash(grep *)
  - Bash(wc *)
  - Bash(awk *)
  - Read
  - Agent
---

# Code Review

You are a senior engineer orchestrating a thorough code review. Follow every step below in order. Do not skip any section. The review contract (domains, severity levels, finding schema, report sections, opposition review requirements, and failure criteria) is defined in `standards/CODE-REVIEW.md` — read it at Step 1 and apply it throughout.

## Step 1 — Load Review Contract

Read `standards/CODE-REVIEW.md` in full. This file defines:

- Required and conditional domains
- Severity levels and field value scales
- Required finding fields
- Required report sections
- Opposition review requirements
- Failure criteria
- Remediation policy

Do not proceed until you have read the standard. All subsequent steps must conform to it.

## Step 2 — Determine Scope

If the user specified a file or folder path, review that target. Otherwise run:

```
git diff HEAD
git status
```

If the diff is empty, let the user know and stop.

## Step 3 — Gather Context

```
git log --oneline -10
```

For each changed file run:

```
git log --oneline -5 -- <filename>
```

Use this to understand why the code exists and whether the change is consistent with past decisions.

Determine which conditional domains apply:

- Performance: does the diff touch tight loops, database queries, or I/O paths?
- Accessibility: does the diff touch HTML/JSX/TSX/Vue/Svelte files?

## Step 3.5 — Baseline Repo Health (deterministic; run BEFORE spawning anything)

**Why this step exists:** every domain in Step 4 reasons semantically over a diff. That is the
right instrument for "is this claim true" and the wrong one for "does this violate a mechanical
limit." On 2026-09-07 a change that would have pushed `CHANGELOG.md` past the markdown line cap in
`.github/workflows/pmb-health.yml`'s File Size job reached the commit point after seven adversarial
review rounds, and was caught only because the user asked for one more look. The committed file
stood at 792 lines against an 800-line cap — `git show 9890758~1:CHANGELOG.md | wc -l` — so it had
never breached in any commit; the pending addition was what would have taken it over. No amount of
semantic review finds that; `wc -l` finds it in milliseconds.

**Why it runs before Step 4 specifically:** Steps 4 and 5 together spawn six to eight subagents,
each reading the diff in full, and they are what this command spends its budget on. Running the
mechanical checks first avoids spending any of that on a change CI will reject regardless of what
the round concludes. (This is a cost argument, not a sequencing one — `/change-review`'s Step 3.5
also precedes its own subagent spawn. No ordering is claimed between Step 4's domain passes and
Step 5's single opposition pass; the models differ and the comparison has not been measured.)

Run these against the **whole working tree**, not just the diff. **Read each one's current
definition out of `.github/workflows/pmb-health.yml` — do not reproduce thresholds, path lists or
grep patterns from this file or from memory.** They are ratcheted deliberately, and a number copied
into prose is stale the moment CI moves; that is why none are restated here.

- The **"File Size" job in full** — enumerate its `FAIL=1` branches from the workflow rather than
  working from the two best-known ones. It currently has four distinct failure conditions:
  per-file line and byte caps on the memory-bank files, a byte cap on *relocation destinations*
  under `docs/`, the startup-context ratchet, and the general markdown line cap. The
  relocation-destination cap is the one reviewers forget, and it guards files that grow by design.
  Report "File Size: Pass" only if every branch passed; naming a subset is how this check returns a
  false negative. The ratchet is the one branch that may legitimately be unavailable (see below) —
  if it is skipped, say "Pass, ratchet skipped" rather than "Pass". Enumerate the memory-bank files the way the job does, with a recursive `find` —
  a `memory-bank/*.md` glob is not recursive, and the workflow's own comments record a file in a
  subdirectory going invisible for exactly that reason.
- The placeholder (`TBD`/`TODO`) scan over `docs/superpowers/specs/` — note it strips fenced and
  inline code before matching and skips some filenames, so a naive `grep` reports false hits
- The credential grep, and the 3 "Rules-File Integrity" greps (invisible Unicode, hidden HTML
  comments, LLM bypass phrases)

**If `.github/workflows/pmb-health.yml` is not present, record every row as Skipped and say so.**
Do not substitute remembered thresholds, and do not treat the checks as passed. This command is
delivered to adopter repositories that do not receive that workflow, and several paths above
(`docs/superpowers/specs/`, `templates/.claude/settings.json`) are specific to this repository.

Two checks that do **not** belong in the offline set, for different reasons. Semgrep,
PSScriptAnalyzer and gitleaks each need a registry fetch, module install or network action, and per
this repo's layering rule they are correctly CI-only. The **startup-context ratchet** compares
against `origin/main`, which CI reaches with `git fetch --depth=1` — so it is not offline either.
Run it only if a current `origin/main` ref is already available locally, and say which you did;
CI itself degrades to advisory when the fetch is unavailable.

**Report the results; do not act on them.** List each check as a one-line pass/fail in the Step 6
report, marking each failure diff-caused or pre-existing. If a cap fails on a file this diff
touches, say so before spawning Step 4 and tell the user the change cannot pass CI as written —
they decide whether to spend the round. **Do not fix it yourself.** Editing during a review is a
Failure Criterion in `standards/CODE-REVIEW.md` ("Repo mutation during review without explicit user
request") and is forbidden by this file's own closing rule; remediation needs an explicit request
after findings are presented.

**A check *result* never sets the Verdict; a *discrepancy* between reported and actual results
does.** Enforcement of these caps belongs to CI, and this step exists to make CI's answer visible
early rather than to duplicate its authority — so a genuine FAIL here, however serious, is
informational. But if Step 5's re-run finds this step reported a result the workflow does not
produce, that is not a cap finding at all: it is evidence the review's own reporting is unreliable,
it is eligible for `Blocking: true` on the ordinary Severity/Basis rules, and it must be reported
as a finding rather than reconciled quietly.

## Step 4 — Spawn Independent Domain Subagents

Spawn one subagent per required domain from the standard, plus any conditional domains that apply. Each subagent sees only the code and its own domain lens — not other subagents' findings.

For each subagent, provide:

- The diff/file being reviewed
- Pass the full text of the Severity, Blocking, and Basis field definitions from `standards/CODE-REVIEW.md` verbatim in each subagent prompt — do not paraphrase
- Instruction to populate all required finding fields: Domain, Severity, Location, Evidence, Basis, Impact, Recommendation, Blocking
- Instruction to return structured findings only — no remediation

Domains to spawn (always): Security, Correctness, Maintainability, Testing, Architecture Drift
Domains to spawn (if applicable): Performance, Accessibility

## Step 5 — Opposition Review, Verdict, and Marker Write

Spawn one final subagent as the opposition reviewer, using `subagent_type: opposition`
(`.claude/agents/opposition.md`). Pass an explicit `model` of **`opus`** — matching the pin in that
agent's frontmatter. Do NOT pass `sonnet`: an explicit `model` parameter OVERRIDES frontmatter, so
"sonnet or higher" (this file's wording until 2026-08-27) let a compliant orchestrator silently
downgrade the very pin added to stop exactly that. Never a cost-optimized model — this subagent is
the sole authority on whether the change ships.

**WHY the named agent:** `.claude/settings.json` sets `CLAUDE_CODE_SUBAGENT_MODEL=haiku`. Until
2026-08-26 the "capable model" requirement was prose in this file, addressed to whichever model
happened to be orchestrating — and an orchestrator that skipped the sentence got a haiku opposition
pass shaped exactly like a real one (verdict, findings table, confidence column), with nothing
anywhere recording that the gate had run cheap. `.claude/agents/opposition.md` pins `model: opus`,
moving the requirement from the advisory layer into config.

**Frontmatter beats the environment variable — verified 2026-08-26**, by spawning `opposition` with
no `model` parameter while `CLAUDE_CODE_SUBAGENT_MODEL=haiku` was set; it reported `claude-opus-5`.
So the pin alone is sufficient. Passing `model` explicitly is retained as cheap defence in depth
against the frontmatter being edited or lost, not because precedence is in doubt.

**If `subagent_type: opposition` errors with "agent type not found":** a newly created agent file is
picked up after a short refresh lag, not instantly (observed 2026-08-26: not found on first call,
available minutes later in the same session — so this is a lag, NOT a session boundary). The error is
loud rather than a silent downgrade. Retry; if it persists, fall back to
`subagent_type: general-purpose` **with `model` passed explicitly**, pasting the body of
`.claude/agents/opposition.md` in as the prompt. Never fall back to a default model.

Give it:
- All domain findings collected in Step 4
- The diff being reviewed (same scope as Step 4) — needed to produce genuine counter-evidence when
  answering the opposition questions, not just react to the findings table
- The full text of the Severity, Blocking, and Basis field definitions from `standards/CODE-REVIEW.md`, verbatim
- Read and Bash tool access

Instruct it to, in order:

1. Re-run Step 3.5's deterministic checks itself, reading each check's definition out of
   `.github/workflows/pmb-health.yml` rather than accepting this orchestrator's report that they
   passed. The orchestrator reporting PASS is a claim like any other, and this command's premise is
   that claims get checked rather than believed — an orchestrator's claim about its own work least
   of all. Re-running costs seconds. Report any disagreement with the orchestrator's Step 3.5
   results as a finding.

2. Answer all four questions from the standard's Opposition Review section:
   - Is any Critical/High finding overstated? Provide counter-evidence.
   - What was not reviewed that could matter?
   - Which findings might be false positives in this codebase's context?
   - What cross-domain risk did no single domain agent catch?
   A general statement that none apply is a failure — all four must be explicitly answered.

3. Determine the final verdict: before scanning, revise the `Blocking` field on any finding you
   concluded above is overstated or a false positive with specific counter-evidence — per the
   standard's exception, evidence that risk is contained downgrades it to `Blocking: false`. Then
   scan every finding — the Step 4 domain findings (with any revisions from this step applied) plus
   anything you surfaced yourself while answering the opposition questions — for any `Blocking:
   true`. If none survive, the verdict is **Approve**. Otherwise the verdict is **Request Changes**
   (if concrete fixes were identified) or **Needs Discussion** (if the disagreement itself needs a
   human call).

4. If, and only if, the verdict is **Approve**: independently compute a hash of the reviewed diff
   and write it to `.claude/.code-review-ok` (create the `.claude` directory first if it doesn't
   exist). Do not accept a hash from the orchestrator — recompute it from the actual diff via
   `git diff HEAD`, run from the same working directory as the rest of the review.

   Bash (redirect to a temp file and hash the file — do NOT capture via `$(git diff ...)` command
   substitution, which strips the trailing newline a redirect preserves; on any machine with both
   bash and pwsh installed, `review-reminders.ps1` runs first and always hashes a redirected file,
   so this must match its byte semantics exactly):
   ```
   tmp=$(mktemp)
   git diff HEAD > "$tmp" 2>/dev/null
   sha256sum "$tmp" | cut -d' ' -f1 > .claude/.code-review-ok
   rm -f "$tmp"
   ```

   PowerShell (do NOT pipe `git diff` directly into a hash cmdlet — PowerShell's pipeline
   re-tokenizes external-command output and will not match the hash `review-reminders.ps1`
   recomputes; redirect to a file first so the hash covers the exact raw bytes):
   ```
   git diff HEAD > "$env:TEMP\pmb-diff-hash.tmp"
   (Get-FileHash "$env:TEMP\pmb-diff-hash.tmp" -Algorithm SHA256).Hash.ToLower() | Set-Content .claude/.code-review-ok
   Remove-Item "$env:TEMP\pmb-diff-hash.tmp" -Force
   ```

   If the verdict is **Request Changes** or **Needs Discussion**, do not write the marker.

5. Return to the orchestrator: its answers to the four opposition questions, the verdict, whether it
   wrote the marker, and the full findings list with any `Blocking` revisions from instruction 3 applied
   (for each revised finding, note the original value, the new value, and the counter-evidence that
   justified the change), and its own Step 3.5 re-run results from instruction 1.

## Step 6 — Assemble Report

**Pre-escalation gate — satisfy every condition below before presenting this report or asking for
any approval.** These are falsifiable checks, not a confidence judgement: "I am satisfied this is
complete" is the state that preceded each failure they exist to catch, so it cannot be the test.

1. **Every deterministic gate in Step 3.5 has been run against the working tree** — actually
   executed, not reasoned about, and not taken from a subagent's report.
2. **Every number, line citation and `file:function` attribution *you* originate carries the
   command that produced it**, run by you against the current tree. Not "I derived this myself" —
   the command, in the report, so a second reader can re-run it. This is deliberate: the standard's
   own Evidence Integrity rule is that "a self-attested completion counts as UNMET", so a claim
   about your own diligence cannot discharge this condition, only a re-runnable command can.
   This applies to figures you introduce — scope counts, sizes, gate results, anything in your own
   prose — and **not** to the domain findings' own Evidence fields, which you relay unaltered and
   which instruction 1 of Step 5 exists to re-derive. Relaying a subagent's figure *into your own
   prose* without re-deriving it is the single most reliable predictor of a false statement in this
   repo's review history — a function name that does not exist, a line list stale by a fixed
   offset, a count no stated method reproduces: each entered the record by being copied.
3. **Every claim about a file has been checked against that file in its current state**, including
   claims inherited from a handoff, an earlier session, or your own earlier turn.
4. **The full diff has been read once end to end**, not only the hunks you edited.
5. **Any number written into a file under active edit was re-derived after the last edit to that
   file.** Line numbers and counts decay silently; a figure that was correct when measured can be
   wrong by the time it is committed.

If a condition cannot be met, say which one and why, in the report, rather than presenting the work
as complete. An acknowledged gap is a finding; an unacknowledged one is a false certificate.

Using the findings list returned by Step 5's subagent (which reflects any `Blocking` revisions made
during its opposition review — do not use the original, unrevised Step 4 output) and the opposition
answers/verdict it also returned, produce the report using the required sections from the standard.
The Verdict and Opposition Review answers are Step 5's subagent's determination — do not recompute or
override them here, and do not write or overwrite `.claude/.code-review-ok` in this step; it was
already written (or correctly not written) by Step 5's subagent.

**Scope:** [git diff HEAD or filename]
**Files reviewed:** N

**Baseline Repo Health (Step 3.5 — informational, never sets the Verdict):**
| Check | Status | Diff-caused or pre-existing |
|---|---|---|
| ... | Pass / Fail / Skipped | ... |

**Domain Coverage:**
| Domain | Status |
|---|---|
| Security | Reviewed |
| Correctness | Reviewed |
| Maintainability | Reviewed |
| Testing | Reviewed |
| Architecture Drift | Reviewed |
| Performance | Reviewed / Skipped (not applicable) |
| Accessibility | Reviewed / Skipped (not applicable) |

## Supported Findings

_(VERIFIED and INFERRED findings. Omit rows that belong in Predicted Risks.)_

| Domain | Severity | Location | Evidence | Basis      | Impact | Recommendation | Blocking   |
| ------ | -------- | -------- | -------- | ---------- | ------ | -------------- | ---------- |
| ...    | ...      | ...      | ...      | [VERIFIED] | ...    | ...            | true/false |

## Predicted Risks

_(SPECULATIVE findings only. Omit this entire section if none exist.)_

| Domain | Severity | Location | Evidence | Basis         | Impact | Recommendation | Blocking |
| ------ | -------- | -------- | -------- | ------------- | ------ | -------------- | -------- |
| ...    | ...      | ...      | ...      | [SPECULATIVE] | ...    | ...            | false    |

**Testing Gaps:**
List any missing tests identified by the Testing domain subagent.

**Opposition Review:**
[Step 5 subagent's answers to all four opposition review questions]

**Verdict:** [Step 5 subagent's verdict — Approve / Request Changes / Needs Discussion]

One paragraph summary of the most important confirmed findings.

---

Do NOT edit files, generate tests, or apply fixes during this review — the `.claude/.code-review-ok`
marker is written (or correctly not written) by Step 5's subagent as its own last action, never by
this orchestrating step. If the user wants remediation after seeing findings, they will ask
explicitly.

---

## Usage

```
/code-review                     # reviews current git diff
/code-review src/auth/login.py   # reviews a specific file
/code-review src/api/            # reviews a whole folder
```
