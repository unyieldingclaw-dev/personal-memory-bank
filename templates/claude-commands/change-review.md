---
allowed-tools:
  - Agent
  - Bash(bash scripts/baseline-health.sh*)
  - Bash(git diff *)
  - Bash(gh pr diff *)
  - Bash(which *)
  - Bash(grep *)
  - Bash(find *)
  - Bash(ai-review-agent *)
---

# /change-review

Review the current branch, PR, or diff as a complete change package using 9 parallel review jobs.

## Usage

```
/change-review
/change-review --diff path/to/change.diff
/change-review --base <ref>
/change-review --pr <number>
```

## Step 1: Determine the diff

**Default (no flags):** Run `git diff origin/main...HEAD` (or `git diff HEAD` if no upstream). If that yields nothing, run `git diff --cached`.

**`--diff <path>`:** Load the diff from the specified file.

**`--base <ref>`:** Run `git diff <ref>...HEAD`.

**`--pr <number>`:** Run `gh pr diff <number>` to fetch the PR diff. If `gh` is not installed, report it and fall back to local diff.

If no diff can be obtained, stop and tell the user.

## Step 2: Check for ACR

Run `which ai-review-agent 2>/dev/null` (bash) or `Get-Command ai-review-agent -ErrorAction SilentlyContinue` (PowerShell).

- **Found:** Note it for use in job 7 (security).
- **Not found:** Print exactly:
  > ACR not found in PATH. Skipping local LLM swarm. Continuing with PMB-native review.

## Step 3: Load context (if available)

Look for an active plan at `docs/plans/*.md` with `status: active`. If found, note its path — it informs claim mapping in job 2. Do not load all plans.

## Step 3.5: Baseline Repo Health (informational — not a review job)

**Why this step exists:** every job in this skill reasons over the diff only (Step 1's `git diff`). That's deliberate — this repo's own `docs/HOOKS-GUIDE.md` assigns "codebase invariants" to CI and says the reviewer layer should not duplicate CI's mechanical pattern-matching. But a purely diff-scoped review can silently approve a change sitting on top of a base branch that's already failing repo-wide CI checks — the diff looks clean, CI still goes red, and it's not obvious why. This step closes that visibility gap without duplicating CI's authority: it's a cheap, local, informational spot-check, not a tenth review job, and it never blocks.

Run only checks that are **fully local and offline** (no registry fetch, no module install, no network call) against the **whole working tree**, not the diff:

- The 3 greps from `.github/workflows/pmb-health.yml`'s "Rules-File Integrity" job (invisible Unicode, hidden HTML comments, LLM bypass phrases) against `standards/`, `CLAUDE.md`, `templates/CLAUDE.md`
- The credential grep and the placeholder (`TBD`/`TODO`) grep from the "Forbidden Patterns" job against the same file sets that job covers
- "Template Integrity"'s check that hook scripts referenced in `templates/.claude/settings.json` exist under `templates/`
**Run them with `bash scripts/baseline-health.sh --no-fetch` rather than by hand.** That script contains no copy of any check — it locates each one by name in `.github/workflows/pmb-health.yml`, lifts the body of its `run:` block and executes it verbatim under CI's own shell flags, so a ratcheted cap takes effect here with no edit anywhere. It covers the three greps, the credential and placeholder greps, Template Integrity, and the **whole** File Size job including the relocation-destination byte cap that hand-written lists forget. **Read its exit code and do not collapse the four:** `0` all passed; `1` a real check failed; `2` the workflow is absent, so every row is **Skipped** and nothing was verified — do not substitute remembered thresholds and do not report a pass, since this command ships to repositories that do not receive `pmb-health.yml`; `3` a step could not be extracted because the workflow was renamed or re-indented, which is **not** a passing tree. `--no-fetch` is what makes the "offline" rule above actually true: without it, the File Size job's startup-context ratchet makes one shallow `git fetch --depth=1 origin main`; the flag neutralizes that line before the body runs, so the ratchet compares against whatever `origin/main` is already resolvable locally — understating growth on a stale baseline, never overstating it — instead of reaching the network.

Do **not** attempt to replicate Semgrep (registry fetch), PSScriptAnalyzer (`Install-Module` fetch), or gitleaks (network action) — those are correctly CI-only per this repo's own layering rule, and this skill can't reliably or quickly reproduce a network-dependent tool.

Report results in their own section (see Step 5's report template) with a one-line pass/fail per check. If a check fails, note whether the offending file(s) are touched by the current diff or pre-existing — this is the detail that would have flagged PR #7's situation immediately. This section never sets `Blocking: Yes` and never factors into the Verdict.

**A check *result* never sets the Verdict; a *discrepancy* between reported and actual results does.** The sentence above is about results, and it holds without exception — a cap failure here is informational however serious it is, because enforcing those caps is CI's job. But Job 9's opposition subagent re-runs these checks and is given this section's reported results to compare against. If what was reported is not what the checks produce, that is not a Step 3.5 result at all: it is evidence this review's own reporting is unreliable, it is a finding on the ordinary Severity/Basis rules, and it is eligible to block. Reporting honestly costs nothing; the rule exists so that misreporting is not free.

**The diff-caused vs pre-existing distinction carries more weight for the size caps than for the greps above, so state it explicitly for them.** A grep hit is usually a pre-existing repo condition and often a judgement call. A cap breach in a file this diff edits is neither: it is arithmetic, and it is caused by the change under review. Reporting it as one more undifferentiated informational line understates it — say plainly which file, at what count, and that the File Size job will fail on it. Per the rule above this still does not set the Verdict, and that is not a contradiction to paper over: **this review's Verdict and CI's gate are separate answers.** A report may legitimately read "Verdict: Approve" beside "the File Size job will fail" — the review found nothing wrong with the change's substance, and CI independently enforces a limit the author must still clear. Say both, rather than muting one to make them agree.

## Step 4: Run 9 review jobs

Work through all 9 jobs. For each finding, use this schema:

| Field              | Description                                                                                                        |
| ------------------ | ------------------------------------------------------------------------------------------------------------------ |
| **Domain**         | Security / Correctness / Performance / Testing / Maintainability / Architecture / Accessibility / Scope / Coverage |
| **Severity**       | Critical / High / Medium / Low / Info                                                                              |
| **Location**       | `file:line` or `file:line–line`                                                                                    |
| **Evidence**       | Specific lines or patterns. For an ABSENCE claim ("no test covers X", "referenced nowhere") or an ATTRIBUTION claim ("X cost Y bytes"), the scope actually searched, **stated as the command**, in the finding itself — the conclusion alone is not evidence, and the command's reach must match the assertion. See NOTE below. |
| **Basis**          | `llm` / `heuristic` / `policy` / `semgrep` / `acr`                                                                 |
| **Impact**         | What breaks or degrades if not addressed                                                                           |
| **Recommendation** | Concrete fix — not "consider improving"                                                                            |
| **Blocking**       | Yes / No — should this block merge?                                                                                |
| **Confidence**     | High / Medium / Low                                                                                                |

> **NOTE on absence and attribution claims.** The Evidence rule above is the operative form here of
> `standards/CODE-REVIEW.md`'s "Absence and attribution claims" subsection; read it there for the
> full statement and worked example. It is restated in the schema rather than imported wholesale
> because **this command's `Basis` field is not that document's `Basis` field.** Here `Basis` records
> which detector produced a finding (`llm`/`heuristic`/`policy`/`semgrep`/`acr`); there it records
> evidentiary strength (`VERIFIED`/`INFERRED`/`SPECULATIVE`). Same name, orthogonal axes — do not
> substitute one vocabulary for the other, and do not report a `VERIFIED` in this command's Basis
> column. Use the **Confidence** column for strength.

---

### Job 1 — Scope Sanity

Check: Is the diff size proportionate to the stated change? Are there unrelated files, generated files that should be gitignored, or bulk reformatting mixed with logic changes?

Flag:

- Diff touches files that appear unrelated to the stated purpose
- Generated files (lock files, build artifacts, minified output) committed without explicit reason
- Unexplained large deletions or file renames

---

### Job 2 — Claim Mapping

Read the PR description, commit message, or plan (if loaded). Check:

- Every claim in the description maps to at least one changed file
- Every major changed file maps to at least one claim
- New public API surface has documentation or a comment explaining its contract

Flag when a claim has no corresponding change, or a significant file change has no stated justification.

---

### Job 3 — Seam Integrity

Check architectural boundaries:

- Layer violations (e.g., UI code importing from data layer directly, domain logic in a controller)
- Dependency injection broken (hardcoded singletons, global state introduced)
- API/service/data seam contracts — are inputs validated at the seam, not deep inside?
- Cross-module coupling introduced without abstraction

---

### Job 4 — Runtime Semantics

Check behavior at runtime:

- Changed defaults or env var handling — what is the effect when the env var is absent?
- Async patterns — unhandled promise rejections, missing `await`, incorrect error propagation
- Startup/shutdown ordering affected by the change
- Rollback safety — can this change be reverted without data loss or downtime?
- Race conditions or time-of-check/time-of-use issues

---

### Job 5 — Test Assertion Strength

For each new or modified test:

- Does it assert observable behavior, not just types or truthiness?
- Does it assert the _right_ thing (not a side effect that could pass even if the feature is broken)?
- Snapshot tests — is the snapshot actually meaningful, or is it testing the wrong thing?
- Mocks — are they verifed? Could they pass even if the real implementation regresses?

---

### Job 6 — Claim-to-Test Coverage

Cross-reference job 2 claims against the test changes:

- Every behavioral claim has either a test or an explicit waiver comment (`// not tested: <reason>`)
- New code paths (branches, error handlers, edge cases) have test coverage or a noted gap
- Deleted tests — were they covering something that still needs coverage elsewhere?

---

### Job 7 — Security

**If ACR is available:**

1. Write the diff from Step 1 to a temp file:
   - Bash: `git diff origin/main...HEAD > /tmp/cr-diff.patch` (or replay the Step 1 command that produced the diff)
   - If Step 1 used `--diff <path>`, copy that file to `/tmp/cr-diff.patch`
   - If Step 1 used `gh pr diff <number>`, re-run: `gh pr diff <number> > /tmp/cr-diff.patch`
2. **Preflight the version — `--chunk` requires ACR >= 1.10.0, and nothing else in this workflow pins it.** Run `ai-review-agent --version`. If it is below 1.10.0, ACR **cannot** run this job: `--chunk` is mandatory (below), and an older build rejects the flag with a usage error — exit 1 and no report. **`--chunk` was introduced in ACR `CHANGELOG.md` `[1.10.0]`, 2026-08-17**, which is the source of the pin. **If `--version` errors, times out, or its output cannot be parsed as a version, treat ACR as unavailable too** — the safe direction, stated rather than assumed. Treat ACR as **unavailable**, go straight to the inline `/security-review` logic, and record `basis: llm` in the Coverage Footer — `too old (<version>)` when a version parsed, `version unreadable` when none did. **Do not fall back to a non-chunked run** — that reintroduces the silent truncation this job exists to prevent.
3. Run `ai-review-agent --profile security --chunk --format json --diff /tmp/cr-diff.patch` and read its exit code. **Neither `--chunk` nor `--format json` is optional here.** `--chunk` prevents silent truncation (note below). `--format json` is what makes row `0`'s signals READABLE: `formatJson()` is a raw `JSON.stringify(result)`, so every signal below is a field on the result object. **One run yields all four** — an earlier draft of this step omitted `--format json`, which made row `0` instruct a check the procedure could not produce.
4. **Map the exit code. Do NOT collapse to zero/non-zero, and do NOT assume this list is complete — treat any code not listed as `2`:**

   | Exit | Meaning | What to do |
   |------|---------|-----------|
   | `0` | Nothing met the threshold — **`0` does NOT establish that coverage was complete** | **Never record an unqualified clean pass from exit `0`.** Inspect the JSON for any indication of reduced coverage (`filteredFiles`, an `agentStatus` entry that is not `ok`, `earlyExit`, `truncation`). **That list is INDICATIVE, not exhaustive, and individual fields are unreliable to a degree that varies by ACR build** — under the mandatory `--chunk` the merge has been observed to drop some fields and union others, and which is which has changed between builds. **Do not rely on a remembered per-field verdict; treat any field's absence as inconclusive rather than as evidence of clean coverage.** (The prior version of this row named two specific fields as unreliable. One of those verdicts was falsified within a day by an upstream change — which is this row's own thesis demonstrated against itself, and the reason the enumeration is gone rather than corrected.) Any indication, **or any inability to establish coverage**, → fall through per item 5. Otherwise record `basis: acr` **with an explicit coverage caveat** in the footer. See **Why this row stopped enumerating signals** below. |
   | `1` | Something met `--fail-on` (default `high`) — **or the invocation was rejected** | **Check a findings object exists BEFORE reading this as findings.** **With findings:** use them, `basis: acr`, and apply the `0` row's coverage caveat — exit `1` says nothing about coverage. **With none:** this is a usage error — measured 2026-09-01, an unknown flag, a bad `--fail-on` value and an unknown profile each exit `1` with one stderr line and no report (a missing diff file exits `4`, not `1`). Read the stderr line, fix the invocation, and fall through per item 5 as `basis: llm`. **Do not retry** — these are deterministic. |
   | `2` | An agent failed internally (takes priority over `1`) | Not a clean pass. Fall through to the inline logic below. |
   | `3` | The diff was TRUNCATED — coverage was partial | Not a clean pass. **`--chunk` is already mandatory above, so there is nothing to re-run differently** — fall through. (This row previously said "re-run with `--chunk`", which became dead advice once `--chunk` was made mandatory.) |
   | `4` | Startup failure — no review ran at all (Ollama unreachable, model missing, diff file absent) | **RETRY, do not triage.** This is infrastructure, not a finding about the code. On stderr with no report produced, so there is no empty findings list to misread. If it recurs, fall through. |
   | any other | Unknown | Treat as `2`. An earlier version of this step said "if the exit code is non-zero" and was replaced by an explicit table; the table then omitted `4`, which was hit in practice on 2026-08-30 when a server restart killed a run mid-chunk. Enumerating without a catch-all reintroduced the gap the enumeration was meant to close. |

> **Why this row stopped enumerating signals.** Four review rounds were spent trying to state precisely which field
> of ACR's output proves coverage. Every version of that list was correct when written and wrong within a day, and the
> corrections kept introducing new contradictions — first a signal the invocation could not produce, then one the chunk
> merge silently drops. **The cause is structural: `ai-review-agent` here is an `npm link` into another session's
> working tree, on an arbitrary branch, rebuilt without warning — its behaviour changed at least three times during a
> single session, and `--version` does not identify what ran.** A precise static description of a moving target cannot
> converge. So this table states an INVARIANT (exit `0` never earns an unqualified clean pass) and treats the field
> list as indicative. Before relying on any specific field, re-derive it against `npm pack ai-review-agent@<version>`,
> not against the linked build.
>
> **KNOWN GAP this row does NOT detect reliably — do not read the table as reassurance.** ACR's `security` and
> `adversarial` agents carry `exclude: ['**/*.md']`, and the "skipped by agentPolicy" line renders only when EVERY
> changed file matches. On a mostly-markdown diff they review only the non-markdown files and the rendered report says
> nothing. Measured 2026-09-01 on a 6-`.md`-plus-1-`.sh` diff: **all six markdown files were excluded**, leaving one
> file reviewed — including both copies of this command file, i.e. the definition of the gate itself.
>
> **Do NOT "fix" that by deleting the exclude.** ACR's source records those two agents as having zero file-type
> awareness with a REPRODUCED failure: misreading a `.md` file's prose description of a vulnerability as executable
> code. This repo's `standards/` and `memory-bank/` are exactly that content, so a blanket removal is worse than the
> gap. The real axis is inert prose vs executable instruction, and a file extension is a failing proxy for it here.
> Note `loadConfig` does a SHALLOW merge — setting `agentPolicy` for any agent replaces the whole default object.
> Tracked as `[NS-48]`; NOT applied.

5. **On exit 2, 3, 4, any unlisted code, or an exit `0`/`1` whose BODY declares the run incomplete:** never read an empty findings list as clean — that reports "reviewed, nothing found" when it means "did not review all of it." Record the exit code verbatim in this job's output, then fall through to the inline `/security-review` logic as the actual coverage, attributed `basis: llm` (not `basis: acr`, since ACR did not genuinely complete). State the reduced coverage in the Coverage Footer.
6. **Never pass `--allow-truncation` in this workflow.** It converts exit 3 into exit 0, which is precisely the signal this step exists to preserve.

> **Why:** Without `--diff`, ACR defaults to `git diff --cached` (staged changes), which is a different surface than the PR or branch diff computed in Step 1.
>
> **Why `--chunk`, measured not assumed:** `--max-lines` defaults to **2000**. On 2026-08-30 a
> 6,578-line branch diff was truncated to 2,000 lines — four agents returned **0 findings in 13.6s**
> and exited 3. The same diff with `--chunk` (4 full-coverage passes, 200s) returned **15 findings
> including 2 High**. Any diff over 2,000 lines is affected, which is most branch diffs.
>
> **ACR was NOT silent about it — the reader was.** An earlier draft of this note claimed the report
> body gave no signal and that only the exit code showed truncation. That was false, and the
> correction matters more than the original point. The run announced it THREE times: a `[ai-review]
> Diff truncated: 4579 of 6579 lines were excluded` line as the **first line of output**, a
> `⚠️ Diff truncated: reviewed 2000/6579 lines` banner in the report, and — because the finding count
> was zero — an `⚠️ INCOMPLETE` headline replacing the usual clean checkmark. The reviewer missed all
> three by running `tail` and a grep for agent lines instead of reading the report.
>
> So the real hazard this step guards is not a silent tool; it is a reviewer who greps a report
> instead of reading it. `--chunk` is mandatory because it removes the situation rather than relying
> on anyone noticing a banner — a control that depends on attention is not a control.
>
> **Why the exit codes are enumerated rather than tested as non-zero:** an earlier version of this
> step said "if the exit code is non-zero ... do not treat an empty findings list as a clean pass."
> That rule is right for 2 and 3 and **wrong for 1**, which means the run succeeded and found
> something at or above the fail threshold. Under that rule a run that correctly surfaced two High
> findings would have been discarded as "did not actually run" and replaced with weaker inline
> coverage — throwing away the tool's most valuable output at exactly the moment it mattered.
>
> **Why check the exit code, not just presence:** a presence-only check (`which ai-review-agent`, Step 2) can't distinguish "ACR ran and found nothing" from "ACR was invoked but every agent inside it failed or timed out" — the latter also produces zero findings, and without an exit-code check both look identical: a clean security review. That's a silently skipped security check reading as a pass.

**If ACR is not available, or was available but failed (see above):** Run the PMB `/security-review` logic inline:

- Hardcoded secrets, credentials, API keys, tokens
- Injection vectors: SQL, shell, path traversal, template injection
- Auth bypass or privilege escalation
- Unsafe deserialization, prototype pollution
- Dependency changes — are new deps audited?
- Secrets in logs, error messages, or stack traces

---

### Job 8 — Accessibility (conditional)

**Skip this job if no UI files are touched** (no `.html`, `.jsx`, `.tsx`, `.vue`, `.svelte`, `.css` in the diff). Note in the coverage footer: `Accessibility: skipped — no UI files`.

**If UI files are present:**

- Interactive elements have accessible labels (aria-label, aria-labelledby, or visible text)
- Color is not the sole conveyor of information
- Focus management correct for new modals, dialogs, or route changes
- Keyboard navigation works for new interactive components
- Images have alt text

---

### Job 9 — Opposition, Verdict, and Marker Write

Spawn one subagent using `subagent_type: opposition` (`.claude/agents/opposition.md`) **and** passing
an explicit `model` of **`opus`**, matching that agent's frontmatter pin — NOT `sonnet`, which as an
explicit parameter would override the pin and silently downgrade the gate (this file's wording until
2026-08-27). Never a cost-optimized model, since this subagent
is the sole authority on whether the change ships.

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
- The full findings tables from Jobs 1–8. **Not** the Step 3.5 Baseline Repo Health results as
  findings to weigh — that section is informational only and never affects Blocking.
- **This orchestrator's Step 3.5 Baseline Repo Health results, verbatim — as claims to re-run, not
  as findings to weigh.** The distinction carries the whole design: a Step 3.5 *result* never
  affects Blocking however bad it is, because enforcing those caps is CI's job and not this
  review's. But a *discrepancy* between what this orchestrator reported and what the checks actually
  produce is not a Step 3.5 result at all — it is evidence that this review's own reporting is
  unreliable, which is a different category of thing and is a finding on the ordinary rules.
  Without these in the payload the section is entirely self-attested, with nothing anywhere
  verifying it.
- The finding schema (Domain, Severity, Location, Evidence, Basis, Impact, Recommendation, Blocking,
  Confidence)
- The diff being reviewed (same scope as Step 1) — needed to produce genuine counter-evidence when
  answering the opposition questions, not just react to the findings tables
- Read and Bash tool access

Instruct it to, in order:

1. Re-run Step 3.5's Baseline Repo Health checks yourself: `bash scripts/baseline-health.sh
   --no-fetch`. Pass `--no-fetch` — you must not perform a repository write, and the flag neutralizes
   the one `git fetch` an extracted body would otherwise run without disabling the check that fetch
   feeds. Do not decline the run or fall back to hand-deriving the checks from
   `.github/workflows/pmb-health.yml` instead — that is exactly the unreliable reimplementation Step
   3.5 exists to avoid. Compare against the results handed over above. A **result** that differs from
   CI is informational, exactly as Step 3.5 says. A **discrepancy between what was reported and what
   the checks actually produce** is not: report it as a finding on the ordinary Severity/Basis rules.
   **If this orchestrator did not supply its Step 3.5 results at all, report that omission as a
   finding**, and apply the same rule to any other item the `Give it:` list requires that you did
   not receive — a disagreement is loud, a missing payload item is silent, and the report looks
   equally complete either way.

2. Play devil's advocate against the entire change:
   - What assumptions does this change make that could be wrong?
   - What edge cases does it not handle?
   - Are there performance implications at scale that the change doesn't address?
   - Are any findings from jobs 1–8 overstated — flag false positives explicitly, with specific
     counter-evidence from the diff
   - Cross-domain risks: a correctness issue that also has security implications, or a test gap
     that also affects a claim

3. Before scanning, revise the `Blocking` field on any finding from Jobs 1–8 you conclude above is
   overstated or a false positive, backed by specific counter-evidence from the diff — specific
   evidence that risk is contained downgrades it to `Blocking: No`. Then scan every finding —
   Jobs 1–8's findings (with any revisions from this step
   applied) plus anything you surface yourself during the opposition pass — for any `Blocking: Yes`.
   This determines whether the change package is clean.

4. If, and only if, no finding (from Jobs 1–8 as revised, or your own opposition pass) has
   `Blocking: Yes` (including the case where there are no findings at all): independently recompute
   a hash of the reviewed diff and write it to `.claude/.change-review-ok` (create the `.claude`
   directory first if it doesn't exist). Do not accept this hash from the orchestrator — recompute
   it from the actual git state, always via this exact command regardless of which flag (if any)
   Step 1 used to gather findings:

   Bash (redirect `git diff` to a temp file and hash the file — do NOT capture it via
   `$(git diff ...)` command substitution, which strips the trailing newline a redirect preserves;
   on any machine with both bash and pwsh installed, `review-reminders.ps1` runs first and always
   hashes a redirected file, so a command-substitution-based hash won't match it):
   ```
   tmp=$(mktemp)
   git diff origin/main...HEAD > "$tmp" 2>/dev/null
   if [ $? -ne 0 ]; then
     git diff HEAD > "$tmp" 2>/dev/null
   fi
   sha256sum "$tmp" | cut -d' ' -f1 > .claude/.change-review-ok
   rm -f "$tmp"
   ```

   PowerShell (do NOT pipe `git diff` directly into a hash cmdlet — PowerShell's pipeline
   re-tokenizes external-command output and will not match the hash `review-reminders.ps1`
   recomputes; redirect to a file first so the hash covers the exact raw bytes):
   ```
   git diff origin/main...HEAD > "$env:TEMP\pmb-diff-hash.tmp" 2>$null
   if ($LASTEXITCODE -ne 0) {
     git diff HEAD > "$env:TEMP\pmb-diff-hash.tmp" 2>$null
   }
   (Get-FileHash "$env:TEMP\pmb-diff-hash.tmp" -Algorithm SHA256).Hash.ToLower() | Set-Content .claude/.change-review-ok
   Remove-Item "$env:TEMP\pmb-diff-hash.tmp" -Force
   ```

5. Return to the orchestrator: its opposition answers; its own Step 3.5 re-run results from
   instruction 1, including any discrepancy or missing-payload finding; the full findings list with
   any `Blocking` revisions from instruction 3 applied (for each revised finding, note the original
   value, the new value, and the counter-evidence that justified the change) plus any findings it
   surfaced itself during the opposition pass; and whether it wrote the marker.

---

## Step 5: Output the report

```markdown
# Change Review

## Findings

| Domain | Severity | Location | Evidence | Basis | Impact | Recommendation | Blocking | Confidence   |
| ------ | -------- | -------- | -------- | ----- | ------ | -------------- | -------- | ------------ |
| ...    | ...      | ...      | ...      | ...   | ...    | ...            | Yes/No   | High/Med/Low |

_(If no findings: "No findings. Change package looks clean.")_

## Baseline Repo Health (informational — not scoped to this diff)

| Check | Status | Notes |
| ----- | ------ | ----- |
| Invisible Unicode characters | ✅ Pass / ❌ Fail | ... |
| Hidden HTML comments | ✅ Pass / ❌ Fail | ... |
| LLM bypass phrases | ✅ Pass / ❌ Fail | ... |
| Credential grep | ✅ Pass / ❌ Fail | ... |
| Spec placeholder grep | ✅ Pass / ❌ Fail | ... |
| Template Integrity | ✅ Pass / ❌ Fail | ... |
| File Size job (markdown cap, memory-bank caps, relocation destinations) | ✅ Pass / ❌ Fail | ... |

_(This section is informational only — it never sets `Blocking: Yes` and never affects the Verdict. If any check fails, state whether the affected file(s) are touched by this diff or pre-existing on the base branch.)_

## Job Summary

| Job                       | Status                              | Notes |
| ------------------------- | ----------------------------------- | ----- |
| 1 Scope Sanity            | ✅ Clean / ⚠️ N findings            | ...   |
| 2 Claim Mapping           | ...                                 | ...   |
| 3 Seam Integrity          | ...                                 | ...   |
| 4 Runtime Semantics       | ...                                 | ...   |
| 5 Test Assertion Strength | ...                                 | ...   |
| 6 Claim-to-Test Coverage  | ...                                 | ...   |
| 7 Security                | ...                                 | ...   |
| 8 Accessibility           | ✅ Clean / ⏭ Skipped — no UI files | ...   |
| 9 Opposition              | ...                                 | ...   |

## Coverage Footer

- **Review target:** local diff | branch (`<name>`) | PR #<number>
- **Base ref:** `<ref>` or unavailable
- **Files changed:** <count>
- **Plan/spec loaded:** none | `<path>`
- **Security review:** reviewed (PMB-native) | reviewed (ACR) | skipped
- **Accessibility:** reviewed | skipped — no UI files
- **ACR backend:** used | not installed | too old (`<version>`, needs >= 1.10.0) | version unreadable | disabled
- **Baseline repo health:** all checks pass | N check(s) failing (pre-existing)
```

_(Render the Findings table above using the findings list returned by Job 9's subagent — which
reflects any `Blocking` revisions made during its opposition pass — do not use the original,
unrevised Jobs 1–8 output. The `.claude/.change-review-ok` marker was already written — or correctly
not written — by Job 9 above. Do not write it, or overwrite it, in this step.)_

## Final instruction

Stop after displaying the report. Do NOT edit files, push commits, or post PR comments unless the
user explicitly asks — writing the `.claude/.change-review-ok` marker per Job 9 is the sole
exception.
