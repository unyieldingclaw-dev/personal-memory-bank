# Investigation Integrity — Mechanisms 1 & 2 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build the two unshipped mechanisms of the approved investigation-integrity design — grounding discipline and coverage discipline — as a discoverable, fleet-distributed skill.

**Architecture:** One new skill file at `.claude/skills/investigation-integrity/SKILL.md`, mirrored to `templates/`, plus the `skills/` category wired into both shells' `mb init` copy loop and `TEMPLATE_OWNED` upgrade list so it reaches every PMB-managed repo. Distribution uses auto-discovery over `templates/.claude/skills/*/SKILL.md` in both shells — no hardcoded per-skill list.

**Tech Stack:** Bash 4+ (`scripts/mb.sh`), PowerShell 7 (`scripts/mb.ps1`), bash test harness (`tests/run.sh` + `tests/helpers/assert.sh`), Markdown skill files with YAML frontmatter.

**Spec:** [`docs/superpowers/specs/2026-08-12-investigation-integrity-design.md`](../specs/2026-08-12-investigation-integrity-design.md) (Status: Approved)

**Tracked as:** `[NS-16]` in `memory-bank/activeContext.md`

---

## Corrections to the spec — verified 2026-08-26, before writing this plan

The spec is 2 weeks old and three of its stated premises have changed or were wrong. Per the discipline the spec itself defines, each was checked rather than carried forward:

1. **`VERIFIED` — the path-mapping problem does not exist.** The spec assumed `skills/` needs a new source-path mapping. It does not. `scripts/mb.sh:1959-1966` (`_upgrade_src`) and `scripts/mb.ps1:2201-2210` (`Get-TemplateSrc`) both fall through to `$TEMPLATES_DIR/$target` by default, so a target of `.claude/skills/X/SKILL.md` already resolves to `templates/.claude/skills/X/SKILL.md` with **zero changes to either function**. This is why the plan places templates at `templates/.claude/skills/`, not a flattened `templates/claude-skills/`. **Do not add a new `case`/`elseif` branch** — it would be dead code.

2. **`VERIFIED` — the bash/PowerShell asymmetry the spec said it would inherit is gone.** The spec (finding 2) states bash's `TEMPLATE_OWNED` "still hardcodes each command filename individually." That was true on 2026-08-12; it was fixed in `b0490ef` (PR #8, 2026-08-18). `scripts/mb.sh:1907-1911` now auto-discovers commands exactly as `mb.ps1:2173` does. **Both shells therefore get auto-discovery for skills too** — the spec's "bash will still need an explicit per-skill entry" is obsolete, and following it would reintroduce the stale-list bug that comment block exists to warn about.

3. **`VERIFIED` — `Get-TemplateDirFile` really is flat.** `scripts/mb.ps1:188-193` is `Get-ChildItem $dir -File`, non-recursive, and is shared with the working `claude-commands` and `docs` call sites. The spec's call for a separate nested helper stands. Do not make the existing one recursive.

4. **`VERIFIED` — no CI mirror-parity check covers `.claude/skills/`.** `.github/workflows/pmb-health.yml` checks `templates/scripts/` and `templates/CLAUDE.md` only. It does run `bash tests/run.sh` (line 471), so a new suite registered in `run.sh` gets CI coverage for free. That is the route this plan takes rather than adding a workflow step.

5. **`INFERRED` — bash has no `Get-MbUpgradeAnalysis` equivalent.** `grep -n "gov_missing\|GOV_MISSING" scripts/mb.sh` returns nothing, so the "governance artifact missing" pre-upgrade analysis exists only in PowerShell. This is a pre-existing asymmetry, **out of scope here** — do not build a bash counterpart as part of this work.

---

## What this plan deliberately does not attempt

Stated up front so no task silently pretends otherwise:

- **Mechanisms 1 and 2 cannot be mechanically tested for effectiveness.** The spec says so directly: "There's no exit code for 'did this catch enough'." Task 5's tests are *structural* checks on the artifact (does the file contain the anti-theater warning, is the mirror byte-identical, does distribution work) — they verify the skill ships and is well-formed, not that it changes behavior. Any claim beyond that would be exactly the overstated-confidence failure this skill exists to prevent.
- **The spec's Testing items 1, 2 and 4** (regression against the original review-gate draft, planted-gap design fixtures, planted-gap plan fixtures) are LLM-behavioral evaluations, not unit tests. They are not built here. If they are wanted, they are a separate plan.
- **No hook enforcement.** Established in the spec's Out of Scope section as structurally impossible for this class of problem.
- **`mb-drift/SKILL.md` is not touched.**

---

## File Structure

| File | Responsibility |
|---|---|
| `.claude/skills/investigation-integrity/SKILL.md` | **Create.** The skill itself: grounding discipline, coverage discipline, trigger, proportionality, anti-theater, output format, cross-references |
| `templates/.claude/skills/investigation-integrity/SKILL.md` | **Create.** Byte-identical mirror, distributed via `TEMPLATE_OWNED` |
| `scripts/mb.sh` | **Modify.** Nested skills glob in `invoke_init`'s copy loop (~line 660) + auto-discovery append to `TEMPLATE_OWNED` (~line 1911) |
| `scripts/mb.ps1` | **Modify.** New `Get-TemplateSkillDir` helper (~line 194) + wire into `Invoke-Init` (~line 879) and `Invoke-Upgrade`'s `$templateOwned` (~line 2174) |
| `tests/test-mb-init.sh` | **Modify.** Assert `mb init` installs the skill into a fresh project |
| `tests/test-mb-upgrade.sh` | **Modify.** Assert `mb upgrade` restores a deleted skill file |
| `tests/test-skill-artifacts.sh` | **Create.** Structural checks: frontmatter well-formed, anti-theater warning present, live/template mirror byte-identical |
| `tests/run.sh` | **Modify.** Register the new suite so CI runs it |
| `docs/HOOKS-GUIDE.md` + `templates/docs/HOOKS-GUIDE.md` | **Modify.** Document the skill and why it is advisory-only |
| `memory-bank/activeContext.md`, `memory-bank/progress.md` | **Modify.** Close `[NS-16]`, record the work |

**Task order is load-bearing:** the skill file must exist (Task 1) and be mirrored (Task 2) before the distribution tests in Tasks 3–4 can pass.

---

## Task 1: Write the skill (mechanisms 1 & 2)

**Files:**
- Create: `.claude/skills/investigation-integrity/SKILL.md`

- [ ] **Step 1: Verify the directory layout requirement before writing**

Run:
```bash
cd "C:/Users/Mizzo/Claude/Personal-Memory-Bank" && ls .claude/skills/
```
Expected: `mb-drift` (a directory, not `mb-drift.md`). This confirms the `<name>/SKILL.md` layout — a flat `.md` file is silently undiscoverable, which is the exact ~2-month latent bug fixed in `15df2c2`.

- [ ] **Step 2: Create the skill file**

Create `.claude/skills/investigation-integrity/SKILL.md` with exactly this content:

````markdown
---
name: investigation-integrity
description: Use before presenting any conclusion, finding, recommendation, root cause, design, or "this is complete/correct" claim. Requires per-claim VERIFIED/INFERRED/SPECULATIVE grounding and an explicit adversarial coverage pass with a stated "what was not checked" section.
---

# Investigation Integrity

Your first pass on a nontrivial claim is not your best-effort pass. It is a plausible-sounding
draft delivered in the tone appropriate for something fully scrutinized. This skill exists because
that gap was measured: across one session a user asked for "one more look" **six separate times**,
and every single one surfaced real defects — a verification check that counted a *rejected* review
as passing, `--no-verify` defeating an entire enforcement layer, a shared state file that would
collide under the project's own normal workflow, a new hardening rule that directly contradicted an
existing one.

**The target is not zero gaps.** That is unachievable and pretending otherwise produces worse
outcomes. The target is narrower and fully achievable: **the confidence you express must reflect
what you actually checked.** When a gap surfaces later, it should be because a disclosed limitation
turned out to matter — not because something was silently assumed and asserted as settled.

## When this fires

Trigger on the **linguistic shape** of what you are about to say, not on a stakes assessment:

- "here's what I found" / "the root cause is" / "I recommend" / "this should work"
- "the design is" / "this is complete" / "that's fixed" / "nothing else is affected"

Judging "is this important enough to be careful about" is the same unreliable judgment this skill
exists to correct. Recognizing "I am about to make a *conclusion-shaped* statement" is narrower and
far less prone to motivated reasoning.

**When genuinely uncertain whether something counts, apply the discipline.** Under-triggering is the
failure mode that actually happened six times. Over-triggering costs proportionality friction, which
is not a trust failure.

**Carve-out, deliberately narrow:** a direct answer with no investigative content behind it (a
factual lookup, a mechanical action with no judgment call) does not need this. Anything presented as
a conclusion, finding, recommendation, or completeness claim does. Ambiguous cases default to firing.

## Mechanism 1 — Grounding discipline

Applied **as the work happens**, not bolted on at the end. Every material claim carries its actual
basis, using this project's existing vocabulary from `standards/CODE-REVIEW.md` — do not invent new
terms:

| Tag | Means | Must include |
|---|---|---|
| `VERIFIED` | Directly observed just now — a file read, a command run, an actual grep result | `file:line` + excerpt, or the command and its real output |
| `INFERRED` | Reasoned from a pattern; behavior not directly confirmed | `file:line` + the reasoning chain, stated not implied |
| `SPECULATIVE` | Suspected risk, genuinely uncertain consequence | An explicit statement that it is unconfirmed |

A claim carried over from earlier in the same conversation is `VERIFIED` only with an explicit
reference to when it was checked. "I recall reading" is `INFERRED`.

This catches individual claims stated above their basis. It does **not** catch omissions.

## Mechanism 2 — Coverage discipline

Grounding cannot catch a category that was never raised as a claim. `--no-verify` was not a
mis-cited fact in the first review-gate draft — it was **absent entirely**, and no amount of "cite
your sources" touches an absence.

Before presenting anything as final:

1. **Generate a fresh list of "what could be wrong or missing here," domain-appropriate to this
   specific task.** Not a fixed universal checklist — the categories for a debugging session and a
   design review are genuinely different. For shell/enforcement work, that list should reach things
   like: error-handling and `set -e`/pipefail behavior, the dual-shell twin, `templates/` mirror
   drift, what happens on the empty/missing input, and who else can reach this code path.
2. **Work through each category explicitly, with results visible** — not silently absorbed into the
   final answer.
3. **Apply mechanism 1 to each category you checked.** "I considered X" is not a claim with a
   basis. "I checked X by reading `file:line`, here is what I found" is.

## Anti-theater — read this part twice

A checklist can be satisfied by going through the motions: write the headers, assert each was
"considered," move on. **This is not hypothetical. It happened inside the document that created this
skill.** While drafting the fix, the draft used the word "checklist" in two incompatible senses —
first to explain why a checklist alone does not work, then a few paragraphs later to name the
proposed solution — with no acknowledgment they were different things. The user caught it, not the
assistant.

The precise failure mode under discussion recurred *inside the discussion of how to prevent it*.
Assume it will happen to you at least once. Specifically check new content against your own recent
claims for self-contradiction, not only against the codebase.

This does not make theater impossible — a sufficiently unwilling instance could fabricate a
plausible `VERIFIED` tag. It makes theater **visible and spot-checkable** rather than
indistinguishable from genuine work. That is the actual guarantee; do not claim more.

## Output format

- Every material claim in a conclusion-shaped response carries a `VERIFIED` / `INFERRED` /
  `SPECULATIVE` tag with the content that tag requires.
- An **always-present** "What I did not check / open risk" section. When there is genuinely nothing,
  it must say so explicitly ("nothing identified as unchecked") rather than being omitted — same
  rule `mb-drift` already applies to clean results.
- Coverage categories are generated fresh per investigation; the *requirement* to generate and work
  through them is fixed.

## Why this makes interaction better, not slower

Every gap in that six-instance session was extracted by the user's own repeated interrogation — the
human doing detection work the assistant should have done. Stating limits upfront, unprompted, moves
the user from *catching* undisclosed gaps to *deciding whether to accept* disclosed ones. That is the
concrete definition of "fluid" this targets, not a vague aspiration toward fewer mistakes.

## Relationship to adjacent mechanisms

- **Mechanism 3 of this design — independent review discipline — is not in this file.** It lives in
  `standards/WORKFLOW.md` "Phase 3.5 — Independent Plan Review" (advisory, not one of the 7 phases).
  It reviews a *plan* via a separately dispatched agent; this skill governs *your own* claims.
- **`superpowers:systematic-debugging`** governs *how* to debug. This governs whether the conclusion
  is presented with calibrated confidence. Complementary.
- **`superpowers:verification-before-completion`** covers claims that have a command and an exit
  code. Its Iron Law is a special case of grounding discipline restricted to mechanically verifiable
  claims. This skill covers claims with no single command to run.
- **`/code-review`'s Opposition Review and `/change-review`'s Job 9** already do this pattern, scoped
  to code diffs. **If you are already inside `/code-review` or `/change-review`, their Opposition
  pass satisfies coverage discipline for that diff — do not run a second pass on top.**
- **`mb-drift`** is the closest precedent in this repo: auto-triggering, domain-scoped, required
  citations, "clean is a valid result." This generalizes that structure beyond memory-bank files.

## Known limitations — disclose these, do not paper over them

1. **Advisory only.** No hook can verify genuine reasoning quality. A compacted session can drift
   back to the exact pattern documented here with this file present and unchanged.
2. **Citation requirements raise the cost of theater; they do not eliminate it.**
3. **The trigger relies on recognizing linguistic shape.** An unusually phrased conclusion can slip
   past. Mitigated by defaulting to fire, not solved.
4. **This skill reviews claims, not premises.** A false premise that no diff touches stays invisible
   to any artifact-level review (measured 2026-08-25, `[NS-39]`). When repeated friction shows up,
   go read the mechanism rather than treating another instance.
````

- [ ] **Step 3: Verify the frontmatter parses and the layout is discoverable**

Run:
```bash
cd "C:/Users/Mizzo/Claude/Personal-Memory-Bank" && head -4 .claude/skills/investigation-integrity/SKILL.md && ls .claude/skills/
```
Expected: the `---` / `name:` / `description:` / `---` block, and `investigation-integrity` listed as a directory alongside `mb-drift`.

- [ ] **Step 4: Commit**

```bash
git add .claude/skills/investigation-integrity/SKILL.md && git commit -m "feat: add investigation-integrity skill (grounding + coverage discipline)"
```

---

## Task 2: Mirror the skill into templates/

**Files:**
- Create: `templates/.claude/skills/investigation-integrity/SKILL.md`

- [ ] **Step 1: Confirm `templates/.claude/` already exists**

Run:
```bash
cd "C:/Users/Mizzo/Claude/Personal-Memory-Bank" && ls templates/.claude/
```
Expected: at least `agents` and `settings.json`. `skills` will not exist yet — that is correct.

- [ ] **Step 2: Copy the live file verbatim**

The mirror is byte-identical — this skill has no PMB-specific content to trim, unlike `HOOKS-GUIDE.md`.

```bash
mkdir -p templates/.claude/skills/investigation-integrity && cp .claude/skills/investigation-integrity/SKILL.md templates/.claude/skills/investigation-integrity/SKILL.md
```

- [ ] **Step 3: Verify byte-identity**

Run:
```bash
cd "C:/Users/Mizzo/Claude/Personal-Memory-Bank" && cmp .claude/skills/investigation-integrity/SKILL.md templates/.claude/skills/investigation-integrity/SKILL.md && echo "IDENTICAL"
```
Expected: `IDENTICAL`

- [ ] **Step 4: Confirm the file is not caught by .gitignore**

This is a real, previously-hit failure: `templates/handoff.md` has never been in git because of an unanchored `.gitignore` pattern (`[NS-33]`).

Run:
```bash
cd "C:/Users/Mizzo/Claude/Personal-Memory-Bank" && git check-ignore -v templates/.claude/skills/investigation-integrity/SKILL.md; echo "exit=$?"
```
Expected: `exit=1` with no output (not ignored). If it prints a matching rule, stop and fix the `.gitignore` anchor before continuing — the file cannot ship otherwise.

- [ ] **Step 5: Commit**

```bash
git add templates/.claude/skills/investigation-integrity/SKILL.md && git commit -m "feat: mirror investigation-integrity skill into templates/"
```

---

## Task 3: Bash distribution — `mb init` and `TEMPLATE_OWNED`

**Files:**
- Modify: `tests/test-mb-init.sh`
- Modify: `tests/test-mb-upgrade.sh`
- Modify: `scripts/mb.sh:657-660` (init copy loop) and `scripts/mb.sh:1907-1911` (TEMPLATE_OWNED)

- [ ] **Step 1: Write the failing init test**

In `tests/test-mb-init.sh`, immediately after the `_review-gate-lib` block (ends ~line 52, before the `# ── Re-init` separator), add:

```bash
# Skills are one level nested (.claude/skills/<name>/SKILL.md), unlike .claude/commands/'s flat
# layout -- a flat glob silently installs nothing, and a skill file at the wrong path is
# undiscoverable rather than broken, so it fails without any error.
assert_file_exists "$TMPDIR_INIT/.claude/skills/investigation-integrity/SKILL.md" \
  "mb init creates .claude/skills/investigation-integrity/SKILL.md"
```

- [ ] **Step 2: Run it and confirm it fails**

Run:
```bash
cd "C:/Users/Mizzo/Claude/Personal-Memory-Bank" && bash tests/test-mb-init.sh
```
Expected: FAIL on `mb init creates .claude/skills/investigation-integrity/SKILL.md`. All other assertions pass.

- [ ] **Step 3: Write the failing upgrade test**

In `tests/test-mb-upgrade.sh`, after the `_review-gate-lib` block (ends ~line 54), add:

```bash
# ── Template sync: skills are TEMPLATE_OWNED via nested auto-discovery ───────
echo ""
echo "--- template sync: restores TEMPLATE_OWNED skill file ---"

rm -rf "$TMPDIR_UP/.claude/skills/investigation-integrity"
assert_file_not_exists "$TMPDIR_UP/.claude/skills/investigation-integrity/SKILL.md" \
  "skill absent before upgrade"

output=$(cd "$TMPDIR_UP" && MB_HOME="$REPO_ROOT" bash "$MB" upgrade 2>&1)
assert_exit_zero $? "mb upgrade exits 0"
assert_file_exists "$TMPDIR_UP/.claude/skills/investigation-integrity/SKILL.md" \
  "upgrade restores TEMPLATE_OWNED skill file"
```

- [ ] **Step 4: Run it and confirm it fails**

Run:
```bash
cd "C:/Users/Mizzo/Claude/Personal-Memory-Bank" && bash tests/test-mb-upgrade.sh
```
Expected: FAIL on `upgrade restores TEMPLATE_OWNED skill file`.

- [ ] **Step 5: Add the init copy loop**

In `scripts/mb.sh`, directly after the `.claude/commands/` loop (ends at line 660 with `done`), insert:

```bash
    # .claude/skills/<name>/SKILL.md
    # WHY nested rather than flat: Claude Code only discovers a skill at <name>/SKILL.md. A skill
    # written as a flat .md file is silently invisible -- this repo shipped mb-drift.md that way for
    # ~2 months before it was caught. The trailing-slash glob plus the -d guard handles the
    # no-matches case, where the literal pattern would otherwise be passed through.
    if [ -d "$TEMPLATES_DIR/.claude/skills" ]; then
        for d in "$TEMPLATES_DIR/.claude/skills"/*/; do
            [ -d "$d" ] || continue
            [ -f "${d}SKILL.md" ] || continue
            skill_name="$(basename "${d%/}")"
            copy_if_new "${d}SKILL.md" \
                "$TARGET/.claude/skills/$skill_name/SKILL.md" \
                ".claude/skills/$skill_name/SKILL.md"
        done
    fi
```

`copy_if_new` (`scripts/mb.sh:593-602`) already does `mkdir -p "$(dirname "$dst")"`, so the nested target directory is created for you.

- [ ] **Step 6: Add the TEMPLATE_OWNED auto-discovery**

In `scripts/mb.sh`, directly after the `claude-commands` auto-discovery block (ends at line 1911 with `fi`), insert:

```bash
    # WHY: Skills auto-discovered on the same principle as claude-commands directly above -- a
    # hardcoded list goes stale the moment a second skill is added, which is the exact bug that
    # comment block documents. Nested one level, so it needs its own loop rather than the flat glob.
    # No _upgrade_src case is required: .claude/skills/X/SKILL.md already resolves through the
    # default branch to $TEMPLATES_DIR/.claude/skills/X/SKILL.md.
    if [ -d "$TEMPLATES_DIR/.claude/skills" ]; then
        for d in "$TEMPLATES_DIR/.claude/skills"/*/; do
            [ -d "$d" ] || continue
            [ -f "${d}SKILL.md" ] && TEMPLATE_OWNED+=(".claude/skills/$(basename "${d%/}")/SKILL.md")
        done
    fi
```

- [ ] **Step 7: Run both tests and confirm they pass**

Run:
```bash
cd "C:/Users/Mizzo/Claude/Personal-Memory-Bank" && bash tests/test-mb-init.sh && bash tests/test-mb-upgrade.sh
```
Expected: both suites pass with no failures.

- [ ] **Step 8: Verify the upgrade path resolves without a mapping change**

This directly checks correction 1 above rather than trusting it.

Run:
```bash
cd "C:/Users/Mizzo/Claude/Personal-Memory-Bank" && grep -n "claude/skills" scripts/mb.sh
```
Expected: exactly the two blocks added in Steps 5 and 6 — **no new `case` branch inside `_upgrade_src`**. If a mapping branch was added, remove it; it is dead code.

- [ ] **Step 9: Commit**

```bash
git add scripts/mb.sh tests/test-mb-init.sh tests/test-mb-upgrade.sh && git commit -m "feat: distribute .claude/skills/ via mb init and TEMPLATE_OWNED (bash)"
```

---

## Task 4: PowerShell distribution — new nested helper

**Files:**
- Modify: `scripts/mb.ps1:188-193` (add helper after `Get-TemplateDirFile`), `:876-879` (`Invoke-Init`), `:2173` (`Invoke-Upgrade`'s `$templateOwned`)

- [ ] **Step 1: Confirm `Get-TemplateDirFile` is flat before deciding not to reuse it**

Run:
```bash
cd "C:/Users/Mizzo/Claude/Personal-Memory-Bank" && sed -n '188,193p' scripts/mb.ps1
```
Expected: `return @(Get-ChildItem $dir -File)` — non-recursive, and shared with the working `claude-commands` and `docs` call sites. Do not modify it.

- [ ] **Step 2: Add the nested helper**

In `scripts/mb.ps1`, insert directly after `Get-TemplateDirFile`'s closing brace (line 193), before `function Get-MbUpgradeAnalysis`:

```powershell
# WHY a separate helper rather than making Get-TemplateDirFile recursive: templates/.claude/skills/
# is one level nested (<name>/SKILL.md), but Get-TemplateDirFile is deliberately flat and is shared
# with the claude-commands and docs call sites, which work correctly today. Making it recursive to
# serve this one case would change behavior for two callers that never asked for it.
function Get-TemplateSkillDir {
    param([string]$TemplatesDir)
    $dir = Join-Path $TemplatesDir ".claude/skills"
    if (-not (Test-Path $dir)) { return @() }
    return @(Get-ChildItem $dir -Directory | Where-Object { Test-Path (Join-Path $_.FullName "SKILL.md") })
}
```

- [ ] **Step 3: Wire it into `Invoke-Init`**

In `scripts/mb.ps1`, directly after the `.claude/commands/` foreach loop (ends line 879), insert:

```powershell
    # .claude/skills/<name>/SKILL.md — nested one level; a flat .md file is undiscoverable
    foreach ($d in (Get-TemplateSkillDir -TemplatesDir $TemplatesDir)) {
        Copy-IfNew -Src (Join-Path $d.FullName "SKILL.md") `
                   -Dst (Join-Path $Target ".claude\skills\$($d.Name)\SKILL.md") `
                   -Label ".claude/skills/$($d.Name)/SKILL.md"
    }
```

`Copy-IfNew` (`scripts/mb.ps1:819-829`) creates the parent directory via `New-Item -ItemType Directory -Force`, so the nested path is handled.

- [ ] **Step 4: Wire it into `Invoke-Upgrade`'s `$templateOwned`**

In `scripts/mb.ps1`, directly after line 2173 (the `claude-commands` append), insert:

```powershell
    # Skills auto-discovered on the same principle as claude-commands above; nested one level.
    # Get-TemplateSrc needs no new branch — .claude/skills/X/SKILL.md resolves through its default.
    $templateOwned += (Get-TemplateSkillDir -TemplatesDir $TemplatesDir | ForEach-Object { ".claude/skills/$($_.Name)/SKILL.md" })
```

- [ ] **Step 5: Wire it into `Get-MbUpgradeAnalysis`'s gov-missing detection**

In `scripts/mb.ps1`, directly after the `docs` foreach block (ends line 243), insert:

```powershell
    # WHY: a project scaffolded before skills existed has none, and unlike a missing hook script
    # this produces no error at all — the skill is simply never invoked. Detect it here the same
    # way missing slash commands are detected above.
    foreach ($d in (Get-TemplateSkillDir -TemplatesDir $TemplatesDir)) {
        if (-not (Test-Path (Join-Path $ProjectPath ".claude\skills\$($d.Name)\SKILL.md"))) {
            $govMissing += ".claude/skills/$($d.Name)/SKILL.md"
        }
    }
```

- [ ] **Step 6: Verify the PowerShell parses and lints clean**

Run:
```powershell
cd "C:\Users\Mizzo\Claude\Personal-Memory-Bank"
$PSStyle.OutputRendering = 'PlainText'
$null = [System.Management.Automation.Language.Parser]::ParseFile("$PWD\scripts\mb.ps1", [ref]$null, [ref]$errs); $errs
Invoke-ScriptAnalyzer -Path scripts/mb.ps1 -Severity Error,Warning
```
Expected: no parse errors, and no new PSScriptAnalyzer findings. `PSUseSingularNouns` is the rule that has bitten this repo before (`a350aa6`) — `Get-TemplateSkillDir` is singular, matching `Get-TemplateDirFile`.

- [ ] **Step 7: Verify init parity between the two shells**

Run:
```powershell
cd "C:\Users\Mizzo\Claude\Personal-Memory-Bank"
$t = Join-Path $env:TEMP "mb-ps-skills-test"
Remove-Item -Recurse -Force $t -ErrorAction SilentlyContinue
New-Item -ItemType Directory -Path $t -Force | Out-Null
Push-Location $t; git init -q; git config user.email "t@t.com"; git config user.name "T"; git commit -q --allow-empty -m init
$env:MB_HOME = "C:\Users\Mizzo\Claude\Personal-Memory-Bank"
pwsh -NoProfile -File "$env:MB_HOME\scripts\mb.ps1" init
Test-Path ".claude\skills\investigation-integrity\SKILL.md"
Pop-Location
```
Expected: `True`. If `False`, the helper or the `Invoke-Init` wiring is wrong — do not proceed.

- [ ] **Step 8: Commit**

```bash
git add scripts/mb.ps1 && git commit -m "feat: distribute .claude/skills/ via mb init and upgrade (PowerShell)"
```

---

## Task 5: Structural artifact tests

**Files:**
- Create: `tests/test-skill-artifacts.sh`
- Modify: `tests/run.sh:39` (register the suite)

These are the spec's Testing item 3 — a structural check on the artifact itself, so a future edit cannot quietly reduce the skill to a generic "be thorough" instruction.

- [ ] **Step 1: Write the test file**

Create `tests/test-skill-artifacts.sh`:

```bash
#!/usr/bin/env bash
# tests/test-skill-artifacts.sh — structural checks on .claude/skills/*/SKILL.md
#
# These verify the artifacts are well-formed and shippable. They deliberately do NOT claim to
# verify that a skill changes model behavior — there is no exit code for that, which is precisely
# why investigation-integrity is an advisory mechanism (see its "Known limitations" section).
set -u

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$REPO_ROOT/tests/helpers/assert.sh"

echo "=== skill artifact tests ==="

# ── Every skill uses the discoverable <name>/SKILL.md layout ─────────────────
echo ""
echo "--- layout: every skill is a directory containing SKILL.md ---"

for d in "$REPO_ROOT"/.claude/skills/*/; do
  [ -d "$d" ] || continue
  name="$(basename "${d%/}")"
  assert_file_exists "${d}SKILL.md" "skill '$name' has SKILL.md"
done

# A flat .claude/skills/*.md file is silently undiscoverable — mb-drift.md shipped that way for
# roughly two months before anyone noticed. Fail loudly instead.
flat_count=$(find "$REPO_ROOT/.claude/skills" -maxdepth 1 -type f -name "*.md" | wc -l)
assert_contains "$flat_count" "0" "no flat .md files directly under .claude/skills/"

# ── investigation-integrity: required sections are present ───────────────────
echo ""
echo "--- investigation-integrity: anti-theater content present ---"

II="$REPO_ROOT/.claude/skills/investigation-integrity/SKILL.md"
assert_file_exists "$II" "investigation-integrity/SKILL.md exists"

ii_content="$(cat "$II" 2>/dev/null || echo "")"
assert_contains "$ii_content" "VERIFIED"     "grounding vocabulary: VERIFIED present"
assert_contains "$ii_content" "INFERRED"     "grounding vocabulary: INFERRED present"
assert_contains "$ii_content" "SPECULATIVE"  "grounding vocabulary: SPECULATIVE present"
assert_contains "$ii_content" "Anti-theater" "anti-theater section present"
assert_contains "$ii_content" "checklist"    "anti-theater worked example present"
assert_contains "$ii_content" "did not check" "mandatory unchecked-risk section documented"
assert_contains "$ii_content" "Known limitations" "limitations disclosed"

# ── Live/template mirror parity ──────────────────────────────────────────────
# No CI job compares .claude/skills/ against its templates/ mirror (pmb-health.yml covers
# templates/scripts and templates/CLAUDE.md only), so the drift check lives here.
echo ""
echo "--- mirror: live and template skills are byte-identical ---"

for d in "$REPO_ROOT"/.claude/skills/*/; do
  [ -d "$d" ] || continue
  name="$(basename "${d%/}")"
  mirror="$REPO_ROOT/templates/.claude/skills/$name/SKILL.md"
  assert_file_exists "$mirror" "templates mirror exists for skill '$name'"
  if [ -f "$mirror" ] && [ -f "${d}SKILL.md" ]; then
    if cmp -s "${d}SKILL.md" "$mirror"; then
      assert_contains "identical" "identical" "skill '$name' matches its templates mirror"
    else
      assert_contains "DIFFERS" "identical" "skill '$name' matches its templates mirror"
    fi
  fi
done

print_summary
```

- [ ] **Step 2: Run it and confirm it passes**

Run:
```bash
cd "C:/Users/Mizzo/Claude/Personal-Memory-Bank" && bash tests/test-skill-artifacts.sh
```
Expected: all assertions pass. Tasks 1 and 2 already created both files, so this suite is green on first run — that is intentional; its job is regression protection, not driving new code.

- [ ] **Step 3: Prove the mirror check actually discriminates**

A test that cannot fail is not a test. Break the mirror deliberately and confirm the suite catches it.

Run:
```bash
cd "C:/Users/Mizzo/Claude/Personal-Memory-Bank" && printf '\ndrift\n' >> templates/.claude/skills/investigation-integrity/SKILL.md && bash tests/test-skill-artifacts.sh; echo "exit=$?"
```
Expected: **non-zero exit**, with `skill 'investigation-integrity' matches its templates mirror` reported as a failure.

Then restore:
```bash
cd "C:/Users/Mizzo/Claude/Personal-Memory-Bank" && git checkout templates/.claude/skills/investigation-integrity/SKILL.md && bash tests/test-skill-artifacts.sh; echo "exit=$?"
```
Expected: `exit=0`.

- [ ] **Step 4: Register the suite in the runner**

In `tests/run.sh`, after the `pre-push-check` line (line 39), add:

```bash
run_suite "skill-artifacts"      "$REPO_ROOT/tests/test-skill-artifacts.sh"
```

CI runs `bash tests/run.sh` at `.github/workflows/pmb-health.yml:471`, so registering here is the only step needed for CI coverage.

- [ ] **Step 5: Run the full suite**

Run:
```bash
cd "C:/Users/Mizzo/Claude/Personal-Memory-Bank" && bash tests/run.sh > "$TMPDIR/pmb-tests.txt" 2>&1; echo "exit=$?"; tail -20 "$TMPDIR/pmb-tests.txt"
```
Expected: `exit=0` and `All test suites passed.`

- [ ] **Step 6: Commit**

```bash
git add tests/test-skill-artifacts.sh tests/run.sh && git commit -m "test: structural checks for skill layout, anti-theater content, mirror parity"
```

---

## Task 6: Document the skill

**Files:**
- Modify: `docs/HOOKS-GUIDE.md`
- Modify: `templates/docs/HOOKS-GUIDE.md`

- [ ] **Step 1: Find the insertion point and confirm the file's convention**

Run:
```bash
cd "C:/Users/Mizzo/Claude/Personal-Memory-Bank" && grep -n "^## " docs/HOOKS-GUIDE.md
```
Expected: a section list. Note that this file documents real incidents rather than abstract failure modes — match that. Insert the new section at the end, before any appendix or reference section.

- [ ] **Step 2: Add the section to `docs/HOOKS-GUIDE.md`**

```markdown
## Investigation Integrity — an advisory skill, and why it cannot be a hook

`.claude/skills/investigation-integrity/SKILL.md` requires per-claim `VERIFIED`/`INFERRED`/`SPECULATIVE`
grounding and an explicit adversarial coverage pass before any conclusion-shaped statement.

**Why it is not a hook.** Every other mechanism in this guide fires on a tool call and does not care
about the assistant's judgment. This one cannot: no deterministic check can evaluate whether
reasoning was actually thorough. It sits at the advisory tier permanently, alongside the review
gate's own advisory pieces.

**The incident behind it.** Across one session a user asked for "one more look" six separate times,
and every one produced real defects — including a verification check that would have counted a
*rejected* review as passing, and `--no-verify` defeating an entire enforcement layer. A seventh
instance happened while drafting the fix: the draft used "checklist" in two incompatible senses in
the same document. The failure recurred inside the discussion of how to prevent it.

**What holds it up, given that it cannot be enforced.** Three structural checks in
`tests/test-skill-artifacts.sh`: the skill must use the discoverable `<name>/SKILL.md` layout (a flat
`.md` file is invisible — `mb-drift.md` shipped that way for ~2 months), it must still contain the
anti-theater section and worked example, and it must stay byte-identical to its `templates/` mirror.
Those are checks on the artifact, not on behavior, and the distinction is deliberate.

**Related, and separately enforced:** mechanism 3 of the same design — independent plan review — is
`standards/WORKFLOW.md` Phase 3.5, advisory and not one of the 7 counted phases.
```

- [ ] **Step 3: Mirror to `templates/docs/HOOKS-GUIDE.md`**

`templates/docs/HOOKS-GUIDE.md` is a **trimmed** mirror, not byte-identical — check before copying.

Run:
```bash
cd "C:/Users/Mizzo/Claude/Personal-Memory-Bank" && diff <(grep "^## " docs/HOOKS-GUIDE.md) <(grep "^## " templates/docs/HOOKS-GUIDE.md)
```
Add the same section manually at the equivalent position, dropping the "The incident behind it" paragraph (PMB-specific history) and keeping the rest.

- [ ] **Step 4: Verify both files still pass the docs checks**

Run:
```bash
cd "C:/Users/Mizzo/Claude/Personal-Memory-Bank" && bash tests/run.sh > "$TMPDIR/pmb-tests2.txt" 2>&1; echo "exit=$?"; tail -8 "$TMPDIR/pmb-tests2.txt"
```
Expected: `exit=0`.

- [ ] **Step 5: Commit**

```bash
git add docs/HOOKS-GUIDE.md templates/docs/HOOKS-GUIDE.md && git commit -m "docs: document investigation-integrity skill and why it stays advisory"
```

---

## Task 7: Close `[NS-16]` in the memory bank

**Files:**
- Modify: `memory-bank/activeContext.md` (`[NS-16]`, line ~103)
- Modify: `memory-bank/progress.md` (new dated entry)

- [ ] **Step 1: Check headroom before writing — the caps are live**

`progress.md` sits near its line cap and has effectively zero byte headroom (`[NS-35]`). Writing blind has already distorted this repo's record once.

Run:
```bash
cd "C:/Users/Mizzo/Claude/Personal-Memory-Bank" && wc -lc memory-bank/progress.md memory-bank/activeContext.md
```
Expected: compare against the FAIL thresholds (600 lines / 60,000 bytes for `progress.md`). If there is no room, **stop and raise it with the user** — do not perform an archive pass unilaterally; a 2026-08-25 archive pass was reverted as unauthorized.

- [ ] **Step 2: Rewrite `[NS-16]` to reflect completion**

Replace the `[NS-16]` entry's stale tail (`Run superpowers:writing-plans on the investigation-integrity spec next (still not started — .claude/skills/investigation-integrity/SKILL.md does not exist)`) with:

```markdown
16. [NS-16] **Investigation-integrity mechanisms 1 & 2 SHIPPED** — `.claude/skills/investigation-integrity/SKILL.md` plus its `templates/` mirror, distributed via nested auto-discovery in both shells' `mb init` and `TEMPLATE_OWNED`. Mechanism 3 (independent plan review) shipped earlier as `standards/WORKFLOW.md` Phase 3.5 (`70a06c1`). Plan: `docs/superpowers/plans/2026-08-26-investigation-integrity-mechanisms-1-2.md`. **Still open:** confirm with the user when the current 3-brief set (`docs/WORK-MB-INVESTIGATION-BRIEF.md`, `-HOOKS-AND-SKILLS-`, `-DOCUMENT-STRUCTURE-`) should be delivered to the work-MB session — that specific set has never been sent in this form.
```

- [ ] **Step 3: Add the `progress.md` entry**

Add under a `## 2026-08-26` heading (or append to the existing one if today's entry exists):

```markdown
- **Investigation-integrity mechanisms 1 & 2 implemented** — the two-week-old approved spec's
  unshipped two-thirds. Three spec premises were falsified before implementation rather than carried
  forward: the source-path mapping problem does not exist (both shells' default branch already
  resolves `.claude/skills/X/SKILL.md`), the bash/PowerShell `TEMPLATE_OWNED` asymmetry the spec said
  it would inherit was fixed in `b0490ef`, and `Get-TemplateDirFile` is genuinely flat so the new
  nested helper was needed. Distribution auto-discovers in both shells — a hardcoded per-skill list
  is the exact staleness bug `b0490ef` fixed for slash commands. Structural tests only
  (`tests/test-skill-artifacts.sh`): layout, anti-theater content, mirror parity. Effectiveness is
  deliberately untested — there is no exit code for "did this catch enough," which is why the
  mechanism is advisory.
```

- [ ] **Step 4: Verify the caps still pass**

Run:
```bash
cd "C:/Users/Mizzo/Claude/Personal-Memory-Bank" && wc -lc memory-bank/progress.md memory-bank/activeContext.md
```
Expected: `progress.md` under 600 lines / 60,000 bytes; `activeContext.md` under 150 lines.

- [ ] **Step 5: Commit**

```bash
git add memory-bank/activeContext.md memory-bank/progress.md && git commit -m "docs: close NS-16, record investigation-integrity mechanisms 1 and 2"
```

---

## Merge

- [ ] **Step 1: Run the full test suite one more time**

```bash
cd "C:/Users/Mizzo/Claude/Personal-Memory-Bank" && bash tests/run.sh > "$TMPDIR/pmb-final.txt" 2>&1; echo "exit=$?"; tail -10 "$TMPDIR/pmb-final.txt"
```
Expected: `exit=0`, `All test suites passed.`

- [ ] **Step 2: Full `/code-review`, no lite path**

Standing rule from `memory-bank/progress.md` 2026-08-12: full review every time, no size exemption. A 3-file mostly-cosmetic diff went through 4 review rounds and surfaced 16 findings — that is the precedent, not the exception.

- [ ] **Step 3: PR against `main`**

`main` is protected (PR + passing checks, `enforce_admins: true`). **This agent cannot merge** — `review-reminders.sh` denies the merge command unconditionally, by design. Hand the merge to the user.

**Sequencing constraint:** this branch touches `scripts/mb.sh` / `scripts/mb.ps1` / `tests/`. `[NS-37]` and `[NS-38]` touch `scripts/dangerous-commands.sh`. No file overlap, so this can proceed in parallel with those — but branch off a freshly-pulled `main` either way.

---

## Self-review

**Spec coverage.** Walked the spec's "Files Changed" table row by row:

| Spec row | Task | Note |
|---|---|---|
| `.claude/skills/investigation-integrity/SKILL.md` | 1 | ✅ |
| `templates/.claude/skills/.../SKILL.md` | 2 | ✅ |
| `scripts/mb.sh` init loop + TEMPLATE_OWNED | 3 | ✅ — auto-discovery on both, not the spec's hardcoded bash entry (correction 2) |
| `scripts/mb.ps1` nested helper + wiring | 4 | ✅ — plus `Get-MbUpgradeAnalysis`, which the spec named |
| `docs/HOOKS-GUIDE.md` + trimmed mirror | 6 | ✅ |
| `tests/test-mb-init.sh` / `test-mb-upgrade.sh` | 3 | ✅ |
| `standards/WORKFLOW.md` Phase 3.5 | — | Already shipped `70a06c1`; verified present at `standards/WORKFLOW.md:69` |
| `.claude/commands/feature-dev.md` + mirror | — | Already shipped `70a06c1`; verified at `feature-dev.md:24` |
| `docs/WORK-MB-INVESTIGATION-BRIEF.md` | — | Already shipped `15df2c2`/`70a06c1` |

Spec Testing items 1, 2 and 4 have **no task** — that is deliberate and disclosed in "What this plan does not attempt," not an oversight. Item 3 is Task 5.

**Placeholder scan.** No TBD/TODO, no "add appropriate error handling," no "similar to Task N." Every code step carries complete code; every command step states expected output.

**Type/name consistency.** `Get-TemplateSkillDir` is used identically in Tasks 4 Steps 2, 3, 4 and 5 with the same `-TemplatesDir` parameter and the same `.Name`/`.FullName` property access. Bash uses `${d%/}` + `${d}SKILL.md` consistently in both loops. Target path string `.claude/skills/<name>/SKILL.md` is identical across bash `TEMPLATE_OWNED`, PowerShell `$templateOwned`, `$govMissing`, and both test files.

**Open risk / what I did not check.**
- `INFERRED` — that Claude Code discovers `templates/`-installed skills in a *downstream* project the same way it does here. The layout requirement is verified for this repo; the downstream case is inferred from the identical path shape, not tested in a real adopter repo.
- `SPECULATIVE` — whether `templates/.claude/skills/` trips any `.gitignore` rule. Task 2 Step 4 exists specifically because `templates/handoff.md` hit exactly this and has never been in git; the check is in the plan rather than pre-run.
- **Not checked:** whether `mb doctor` should gain a check for skill-layout correctness. Deliberately out of scope — the structural test covers this repo, and `mb doctor` scope expansion was not in the spec.
