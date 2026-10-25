# Hook Enforcement Integrity Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make PMB's hook enforcement layer fail *visibly* instead of silently, and put its wiring — not just its scripts — under test.

**Architecture:** Three moves, in dependency order. First add a test harness that executes hooks the way Claude Code executes them (through the `settings.json` command string), which turns the fail-open defect from an argument into a red test. Then replace the fragile `A || B || true` invocation chain with the `if command -v pwsh` form the repo already uses in one place. Then close the observability gap so any future fail-open leaves evidence.

**Tech Stack:** bash + POSIX sh (hook scripts), PowerShell 7 (`.ps1` twins), `python3` for JSON extraction in tests, existing `tests/helpers/assert.sh` harness.

---

## BLOCKING PREREQUISITE — do not start this plan yet

`[NS-32]` (enforcement-integrity bundle 1) touches the same security boundary as this plan. Starting
this plan while that work is unmerged puts two security-boundary changes in one tree — the hazard
`[NS-26]` exists to prevent.

**Gate:** `[NS-32]` committed, reviewed through the full gate, and merged. Then branch fresh from `main`.

**Status as of 2026-08-21:** committed as `4bc107c` on `feat/enforcement-integrity-bundle-1` and passed
the full gate (6 domains + opposition, Approve). **Still unmerged** — that branch's PR waits on PR #20
merging first, so the gate above is NOT yet satisfied and this plan remains blocked. The original
wording of this section said `[NS-32]` was "uncommitted in the main working tree"; that was true when
written and is no longer, but the blocking condition itself is unchanged.

## Scope note

Downstream finding 4 (`mb upgrade` cannot distinguish a local fix from version lag,
`scripts/mb.sh:1847`) and finding 9 (staleness never surfaces) are a **separate subsystem** —
template propagation, not hook enforcement. They need their own plan. They are sequenced *before*
this one for shipping purposes (fixes here don't reach downstream installs until propagation works),
but they share no files with these tasks and must not be merged into this plan.

Findings 5 and 6 belong with the `[NS-18]` / review-gate port, already sequenced there.

## Verified baseline (measured 2026-08-20, not assumed)

| Fact | Evidence |
|---|---|
| `.ps1` drains stdin | `scripts/dangerous-commands.ps1:31` — `$raw = $input \| Out-String` |
| `.sh` exits 0 on empty stdin | `scripts/dangerous-commands.sh:37-40` — `input=$(cat)`; `[ -z "$input" ] && exit 0` |
| Both block via stdout JSON, not exit code | `.sh` `deny()` at line ~69; `.ps1` `permissionDecision` at line ~79 |
| Correct pattern already exists in-repo | `templates/.claude/settings.json:81` (`pre-compact-check`) |
| 7 of 8 hook entries use the fragile chain | `templates/.claude/settings.json` lines 16,25,36,40,58,62,71 |
| 1 entry has no fallback at all | line 49, matcher `PowerShell` |
| 8 of 8 `.sh` hook scripts have zero error logging | `grep -c pmb-hook-errors scripts/*.sh` → 0 for all 8 |
| 2 of 8 `.ps1` lost their logging | `review-reminders.ps1`, `review-reminders-post.ps1` → 0 |
| **No test executes a hook via its settings.json command** | `tests/test-dangerous-commands.sh:22` invokes `bash scripts/…` directly |

**The fail-open is now proven, not inferred.** `tests/test-hook-wiring.sh` was written and run against
this tree on 2026-08-20 — Task 1 Steps 1, 2 and 4 are therefore already done; the file exists and is
red. Result:

```
--- pwsh absent: the bash fallback still denies a dangerous command ---
  PASS: pwsh absent: fallback denies rm -rf
--- pwsh drains stdin then fails: the chain must STILL deny ---
  FAIL: pwsh fails after draining stdin: chain still denies rm -rf
--- every enforcement hook selects its interpreter explicitly ---
    verdict: FRAGILE: PostToolUse/Write|Edit, PostToolUse/Bash, PreToolUse/Bash, PreToolUse/Bash,
             PreToolUse/PowerShell, PreToolUse/Write|Edit, PreToolUse/Write|Edit, PreToolUse/Agent
Results: 1 passed, 2 failed
```

The control passing is what makes the failure meaningful: the harness denies correctly on the
designed fallback path, so the second failure isolates the drain-then-fail case rather than
reflecting a broken test.

**One entry this surfaced that no prior count included: `PreToolUse/Agent`** (`delegation-depth-check`).
Eight fragile entries total — the seven in Task 2 plus the no-fallback `PreToolUse/PowerShell` in Task 3.

**Not yet registered in `tests/run.sh`.** That file is modified by the uncommitted `[NS-32]` bundle, so
registering now would mix two changes. Task 1 Step 3 remains outstanding and must be done once the tree
is clean — until then this suite does not run in CI or in `bash tests/run.sh`.

---

## File Structure

- **Create** `tests/test-hook-wiring.sh` — the missing layer. Executes hook command strings from
  `.claude/settings.json` under a controlled `PATH`. Sole responsibility: the *wiring*, never pattern logic.
- **Create** `tests/helpers/stub-pwsh.sh` — builds a throwaway `pwsh` stub on `PATH`. Separate file
  because Tasks 1 and 3 both need it and duplicating it would let the two copies drift.
- **Modify** `.claude/settings.json` and `templates/.claude/settings.json` — invocation pattern. Paired mirrors; always edit both.
- **Modify** the 8 `scripts/*.sh` hook scripts — add the shared logging helper call.
- **Create** `scripts/lib/hook-log.sh` — one logging function, sourced by all 8. DRY: eight inline
  `printf >> .pmb-hook-errors.log` lines is the duplication that let the `.ps1` side drift out of sync.
- **Modify** `scripts/review-reminders.ps1`, `scripts/review-reminders-post.ps1` — restore logging.
- **Modify** `tests/run.sh` — register the new suite.

---

### Task 1: Wiring test harness — prove the fail-open

**Files:**
- Create: `tests/helpers/stub-pwsh.sh`
- Create: `tests/test-hook-wiring.sh`
- Modify: `tests/run.sh:38` (append one line after the `pre-push-check` entry)

- [ ] **Step 1: Write the pwsh stub helper**

```bash
# tests/helpers/stub-pwsh.sh — builds a fake `pwsh` for wiring tests.
#
# WHY: the fail-open in question needs pwsh to START, consume stdin, and THEN fail.
# "pwsh not installed" (exit 127, stdin untouched) is the case the || chain handles
# correctly, so testing that proves nothing. This stub reproduces the case that breaks.

make_stub_pwsh() {
    # make_stub_pwsh <exit-code> — prints a dir to prepend to PATH.
    local code="$1" dir
    dir="$(mktemp -d)"
    cat > "$dir/pwsh" <<STUB
#!/usr/bin/env bash
cat >/dev/null   # mimic \`\$input | Out-String\` draining stdin
exit $code
STUB
    chmod +x "$dir/pwsh"
    printf '%s' "$dir"
}
```

- [ ] **Step 2: Write the failing test**

```bash
#!/usr/bin/env bash
# tests/test-hook-wiring.sh — tests how hooks are INVOKED, not what they match.
#
# WHY this test exists: every other test in tests/ runs hook scripts directly
# (tests/test-dangerous-commands.sh:22). Claude Code runs them through the command
# string in .claude/settings.json. That seam has never been executed by any test,
# and it is where the fail-open lives.
set -u

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$REPO_ROOT/tests/helpers/assert.sh"
source "$REPO_ROOT/tests/helpers/stub-pwsh.sh"

echo "=== hook wiring tests ==="

hook_command() {
    # hook_command <event> <matcher> — first hook command string for that event+matcher.
    python3 -c '
import json, sys
d = json.load(open(sys.argv[1]))
for g in d["hooks"][sys.argv[2]]:
    if g.get("matcher") == sys.argv[3]:
        print(g["hooks"][0]["command"]); break
' "$REPO_ROOT/.claude/settings.json" "$1" "$2"
}

DANGEROUS='{"tool_name":"Bash","tool_input":{"command":"rm -rf /tmp/some-dir"}}'

echo ""
echo "--- a dangerous command is denied when pwsh is absent (fallback path) ---"
stub="$(make_stub_pwsh 127)"
cmd="$(hook_command PreToolUse Bash)"
output=$(printf '%s' "$DANGEROUS" | PATH="$stub:$PATH" sh -c "$cmd" 2>/dev/null)
assert_contains "$output" '"permissionDecision":"deny"' "pwsh absent: bash fallback still denies rm -rf"

echo ""
echo "--- a dangerous command is denied when pwsh drains stdin then fails ---"
stub="$(make_stub_pwsh 1)"
cmd="$(hook_command PreToolUse Bash)"
output=$(printf '%s' "$DANGEROUS" | PATH="$stub:$PATH" sh -c "$cmd" 2>/dev/null)
assert_contains "$output" '"permissionDecision":"deny"' "pwsh fails after draining stdin: chain still denies rm -rf"

echo ""
echo "--- no enforcement hook uses the stdin-losing fallback chain ---"
bad=$(python3 -c '
import json, sys
d = json.load(open(sys.argv[1]))
bad = []
for event, groups in d["hooks"].items():
    if event == "Stop":
        continue          # notification only, not an enforcement control
    for g in groups:
        for h in g["hooks"]:
            c = h["command"]
            if "||" in c and "command -v" not in c:
                bad.append(event + "/" + str(g.get("matcher")) + ": " + c)
print("\n".join(bad))
' "$REPO_ROOT/.claude/settings.json")
assert_contains "" "$bad" "every enforcement hook selects its interpreter with 'command -v'"

print_summary
```

- [ ] **Step 3: Register the suite**

Append to `tests/run.sh` immediately after line 38:

```bash
run_suite "hook-wiring"          "$REPO_ROOT/tests/test-hook-wiring.sh"
```

- [ ] **Step 4: Run and verify it FAILS**

Run:
```bash
bash tests/test-hook-wiring.sh
```
Expected: first assertion PASSES (the pwsh-absent path genuinely works). Second and third FAIL —
second because the fallback receives 0 bytes and emits nothing, third because 7 entries use the
fallback chain. A green run here means the test is not reproducing the defect; stop and fix the
test, not the hooks.

- [ ] **Step 5: Commit the red test**

Stage `tests/test-hook-wiring.sh`, `tests/helpers/stub-pwsh.sh`, `tests/run.sh`.
Message: `test: add hook wiring tests, reproducing the stdin-drain fail-open`

---

### Task 2: Replace the invocation chain

**Files:**
- Modify: `.claude/settings.json` (7 enforcement entries)
- Modify: `templates/.claude/settings.json` (same 7 — paired mirror)

- [ ] **Step 1: Rewrite each enforcement entry**

For every entry of the form
`pwsh -NonInteractive -File scripts/X.ps1 2>/dev/null || bash scripts/X.sh 2>/dev/null || true`
substitute:

```bash
if command -v pwsh >/dev/null 2>&1; then pwsh -NonInteractive -File scripts/X.ps1 2>>.pmb-hook-errors.log; else bash scripts/X.sh 2>>.pmb-hook-errors.log; fi
```

Apply to `X` in: `update-reviewed`, `review-reminders-post`, `dangerous-commands`, `review-reminders`,
`check-contract`, `warn-stale-review-marker`, `delegation-depth-check`.

For `update-reviewed` only, the current entry uses `powershell`, not `pwsh`. Use
`command -v pwsh` and the `pwsh` binary as above — Windows PowerShell 5.1 is not a supported target
for these scripts and the mixed binary is itself drift.

Leave the `Stop` notification entry (line ~91) alone: it is a message box, not an enforcement control,
and its trailing `true` is correct.

**Two behavior changes to state plainly rather than discover in production:**
1. Exactly one interpreter runs. There is no second chance, which is the point — the second chance was
   the thing that silently allowed dangerous commands.
2. Dropping the trailing `true` lets a crashing hook surface a non-zero exit to Claude Code instead of
   vanishing. That is the intended outcome. If it proves disruptive, the fix is to make the script not
   crash, not to reinstate the swallow.

> **CORRECTION 2026-08-21 — what this task does NOT do.** Applied to a scratch copy and tested, this
> change does **not** make a crashed hook fail closed. When the selected interpreter drains stdin and
> dies, no fallback runs, the hook emits nothing, and the dangerous command is still ALLOWED. What
> changes is that the failure becomes *visible*: one interpreter is chosen deterministically, the exit
> code propagates instead of being forced to 0, and stderr lands in `.pmb-hook-errors.log` instead of
> `/dev/null`.
>
> That is the correct target — a PreToolUse hook that has died cannot emit a deny decision, and making
> every hook crash block every tool call would lock the user out of their own tooling, against this
> repo's documented fail-open-on-missing-dependency convention. It matches Task 6's rule exactly:
> *fail-open is acceptable, silent fail-open is not.*
>
> **Do not write a test asserting that a crashed interpreter still denies.** The first draft of
> `tests/test-hook-wiring.sh` did, and it was asserting something the design deliberately does not
> provide. Assert instead: (a) with pwsh genuinely absent from PATH the bash branch denies, and (b) a
> crashed interpreter propagates a non-zero exit. Note that a stub which exits 127 does NOT simulate
> absence once `command -v` is doing the selection — `command -v` tests existence, not exit status.

- [ ] **Step 2: Mirror to templates**

Apply the identical 7 substitutions in `templates/.claude/settings.json`, then verify parity:

```bash
python3 - <<'PY'
import json
def cmds(p):
    d = json.load(open(p))
    return sorted(h["command"] for gs in d["hooks"].values() for g in gs for h in g["hooks"])
a = cmds(".claude/settings.json")
b = cmds("templates/.claude/settings.json")
print("MATCH" if a == b else "DRIFT:\n" + "\n".join(sorted(set(a) ^ set(b))))
PY
```

Expected output: `MATCH`

- [ ] **Step 3: Run the wiring tests**

Run: `bash tests/test-hook-wiring.sh`
Expected: all three assertions PASS.

- [ ] **Step 4: Run the full suite for regressions**

Run: `bash tests/run.sh`
Expected: all suites pass, exit 0. Takes several minutes; run it in the background.

- [ ] **Step 5: Commit**

Stage both settings files.
Message: `fix: select hook interpreter with command -v, not a stdin-losing fallback chain`

---

### Task 3: Give the PowerShell-matcher entry a fallback

**Files:**
- Modify: `.claude/settings.json:49`, `templates/.claude/settings.json:49`
- Modify: `tests/test-hook-wiring.sh` (add one assertion)

- [ ] **Step 1: Write the failing assertion**

Add to `tests/test-hook-wiring.sh` before `print_summary`:

```bash
echo ""
echo "--- the PowerShell-matcher hook still denies when pwsh is missing ---"
stub="$(make_stub_pwsh 127)"
cmd="$(hook_command PreToolUse PowerShell)"
output=$(printf '%s' '{"tool_name":"PowerShell","tool_input":{"command":"rm -rf /tmp/x"}}' | PATH="$stub:$PATH" sh -c "$cmd" 2>/dev/null)
assert_contains "$output" '"permissionDecision":"deny"' "PowerShell matcher denies rm -rf even without pwsh"
```

- [ ] **Step 2: Run it and verify it FAILS**

Run: `bash tests/test-hook-wiring.sh`
Expected: the new assertion FAILS — the entry has no fallback, so a missing pwsh means the
BLOCK-tier control does not run at all.

- [ ] **Step 3: Fix both files**

Replace line 49 in both `.claude/settings.json` and `templates/.claude/settings.json`:

```bash
if command -v pwsh >/dev/null 2>&1; then pwsh -NonInteractive -File scripts/dangerous-commands.ps1 2>>.pmb-hook-errors.log; else bash scripts/dangerous-commands.sh 2>>.pmb-hook-errors.log; fi
```

- [ ] **Step 4: Run and verify it PASSES**

Run: `bash tests/test-hook-wiring.sh`
Expected: all four assertions PASS.

- [ ] **Step 5: Commit**

Stage both settings files and the test.
Message: `fix: add bash fallback to the PowerShell-matcher dangerous-commands hook`

---

### Task 4: One logging helper, sourced by all 8 `.sh` hooks

**Files:**
- Create: `scripts/lib/hook-log.sh`
- Modify: `scripts/update-reviewed.sh`, `scripts/review-reminders-post.sh`, `scripts/dangerous-commands.sh`, `scripts/review-reminders.sh`, `scripts/check-contract.sh`, `scripts/warn-stale-review-marker.sh`, `scripts/delegation-depth-check.sh`, `scripts/pre-compact-check.sh`
- Modify: `tests/test-hook-wiring.sh`

- [ ] **Step 1: Write the failing test**

Add to `tests/test-hook-wiring.sh` before `print_summary`:

```bash
echo ""
echo "--- every .sh hook script can log a hook error ---"
for s in update-reviewed review-reminders-post dangerous-commands review-reminders \
         check-contract warn-stale-review-marker delegation-depth-check pre-compact-check; do
    if grep -q "hook_log" "$REPO_ROOT/scripts/$s.sh"; then
        assert_contains "yes" "yes" "$s.sh logs hook errors"
    else
        assert_contains "no" "yes" "$s.sh logs hook errors"
    fi
done
```

- [ ] **Step 2: Run it and verify 8 FAILURES**

Run: `bash tests/test-hook-wiring.sh`
Expected: 8 new assertions FAIL — none of the `.sh` hooks logs anything today.

- [ ] **Step 3: Write the helper**

```bash
# scripts/lib/hook-log.sh — shared hook error logging.
#
# WHY a shared helper rather than an inline printf in each script: the .ps1 side used
# inline logging and drifted -- 2 of 8 lost it entirely between releases with nothing
# catching the regression. One function, one place to keep correct.

hook_log() {
    # hook_log <script-name> <message>
    printf '[%s] [HOOK] %s: %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$1" "$2" \
        >> .pmb-hook-errors.log 2>/dev/null || true
}
```

- [ ] **Step 4: Wire it into each of the 8 scripts**

After the `set -u` line in each, add:

```bash
. "$(dirname "$0")/lib/hook-log.sh"
```

Then replace each silent bail-out with a logged one. In `scripts/dangerous-commands.sh`, lines 37-40
currently read:

```bash
input=$(cat 2>/dev/null)
if [ -z "$input" ]; then
    exit 0
```

Change to:

```bash
input=$(cat 2>/dev/null)
if [ -z "$input" ]; then
    hook_log "dangerous-commands.sh" "empty stdin -- guardrail did not evaluate, failing open"
    exit 0
```

For the other 7, first enumerate every exit point:

```bash
grep -n "exit 0" scripts/update-reviewed.sh scripts/review-reminders-post.sh \
    scripts/review-reminders.sh scripts/check-contract.sh \
    scripts/warn-stale-review-marker.sh scripts/delegation-depth-check.sh \
    scripts/pre-compact-check.sh
```

Classify each hit by one question: **did the hook actually evaluate its input?**

- *No* — empty stdin, parse failure, a missing file it needed, an unreadable config. Add a
  `hook_log` line naming the script and the reason, immediately before the `exit 0`.
- *Yes, and nothing matched* — the normal quiet path. Leave it alone. Logging these would
  produce a line on every tool call and the log would be ignored within a day.

The distinction is the whole point of the task: the log must mean "a control did not run,"
never "a control ran and was satisfied."

- [ ] **Step 5: Run and verify PASS**

Run: `bash tests/test-hook-wiring.sh`
Expected: all assertions PASS.

- [ ] **Step 6: Commit**

Stage `scripts/lib/hook-log.sh`, the 8 modified `.sh` scripts, and the test.
Message: `fix: log hook errors from all 8 .sh enforcement scripts`

---

### Task 5: Restore logging to the two regressed `.ps1` scripts

**Files:**
- Modify: `scripts/review-reminders.ps1`, `scripts/review-reminders-post.ps1`

- [ ] **Step 1: Locate the silent catches**

Run:
```bash
grep -n "catch { exit 0 }" scripts/review-reminders.ps1 scripts/review-reminders-post.ps1
```
Expected: 4 hits, 2 per file.

- [ ] **Step 2: Replace each with the logging form already used by the other six**

```powershell
} catch {
    try { Add-Content ".pmb-hook-errors.log" "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] [HOOK] review-reminders.ps1: $_" -ErrorAction SilentlyContinue } catch { Write-Verbose "Could not write .pmb-hook-errors.log; ignoring." }
    exit 0
}
```

Use the correct script name in each file's message.

- [ ] **Step 3: Verify no silent catches remain**

Run:
```bash
grep -c "catch { exit 0 }" scripts/*.ps1
```
Expected: 0 for every file.

- [ ] **Step 4: Run PSScriptAnalyzer**

Run:
```bash
pwsh -NonInteractive -Command "Invoke-ScriptAnalyzer -Path scripts/ -Recurse -Settings PSScriptAnalyzerSettings.psd1"
```
Expected: no output.

- [ ] **Step 5: Commit**

Stage both `.ps1` scripts.
Message: `fix: restore hook error logging to the two regressed .ps1 scripts`

---

### Task 6: Make the rule explicit so it stops regressing

**Files:**
- Modify: `standards/SECURITY-GUARDRAILS.md`
- Modify: `.gitignore`

- [ ] **Step 1: Add the rule**

Append to `standards/SECURITY-GUARDRAILS.md`:

```markdown
## Hook failure policy

**Fail-open is acceptable. Silent fail-open is not.**

Every code path where an enforcement hook declines to evaluate — empty stdin, parse failure,
missing interpreter, unhandled exception — MUST write a line to `.pmb-hook-errors.log` naming
the script and the reason before exiting 0.

- Hooks select their interpreter with `command -v`, never with a fallback chain. Such a chain hands
  the second command a stdin that the first already drained.
- Hook stderr goes to `.pmb-hook-errors.log`, never to `/dev/null`.
- A bare `catch { exit 0 }` or `[ -z "$input" ] && exit 0` with no log line is a review failure.

**WHY:** measured 2026-08-20, 8 of 8 `.sh` hooks and 2 of 8 `.ps1` hooks could fail without
producing any evidence anywhere. Each omission was individually defensible ("don't break the
user's workflow"), which is exactly how it accumulated to cover the whole layer.
```

- [ ] **Step 2: Ignore the log file**

Append `.pmb-hook-errors.log` to `.gitignore`.

- [ ] **Step 3: Verify it is ignored**

Run:
```bash
git check-ignore -v .pmb-hook-errors.log
```
Expected: a line naming `.gitignore` and the pattern.

- [ ] **Step 4: Commit**

Stage `standards/SECURITY-GUARDRAILS.md` and `.gitignore`.
Message: `docs: add hook failure policy -- fail-open must never be silent`

---

### Task 7: Extract the command field in `review-reminders`, as its sibling already does

**Files:**
- Modify: `scripts/review-reminders.sh`, `scripts/review-reminders.ps1`
- Modify: `tests/test-review-reminders.sh`

> **CORRECTION 2026-08-21 — this task's fix is wrong as written, and this task must run FIRST.**
>
> Extraction does NOT solve the observed failures. Four over-matches were hit live on 2026-08-20/21:
> a quoted `grep -E` pattern containing `| bash`, two heredocs containing `git commit`, and a Python
> regex literal containing `\|\| bash`. In every case the trigger text sat *inside the command being
> run*, so `tool_input.command` extraction returns it too — `dangerous-commands.sh:44` already does
> that extraction and still matched. Telling these apart requires **shell-aware tokenization** (is
> `| bash` a real pipeline operator, or text inside a quoted string / heredoc body?), not JSON
> parsing. Redesign this task before executing it.
>
> **Bootstrap ordering:** editing the hook command strings in Tasks 2 and 3 means writing text that
> contains the very patterns these matchers block. The matcher must be fixed before the wiring can
> be. This task therefore runs BEFORE Task 2, immediately after Task 1.
>
> **Caution on the redesign:** a parser bug in a BLOCK-tier control is worse than an over-match.
> Over-matching fails safe. Prefer a narrow, well-tested tokenizer, or an explicit user-authorized
> escape path, over clever matching.

**Why this is not finding 8.** Finding 8 is about `dangerous-commands` platform parity. This is a
distinct defect in the *review gate itself*, and it rests on a premise written into the file.
`scripts/review-reminders.sh:36-40` states:

> "Since `git commit`/`git push` only plausibly appear in this hook's stdin inside the command
> field, matching the raw payload directly is robust to that escaping edge case."

Falsified twice on 2026-08-20: a heredoc writing a *document* that contained example commit
commands tripped the gate. The phrase appeared in the payload without any commit occurring.

The author rejected field extraction because `grep -o` breaks on escaped quotes — correct, but
`scripts/dangerous-commands.sh:44` already solved exactly this with `python3` `json.load`, and its
header at line 7 gives the same rationale in reverse. The fix exists in the repo and was never
propagated to its sibling.

- [ ] **Step 1: Write the failing test**

Add to `tests/test-review-reminders.sh`:

```bash
echo ""
echo "--- a document containing an example commit command does not trip the gate ---"
payload='{"tool_name":"Bash","tool_input":{"command":"cat > plan.md <<EOF\ngit commit -m \"example\"\nEOF"}}'
output=$(printf '%s' "$payload" | bash "$REPO_ROOT/scripts/review-reminders.sh" 2>/dev/null)
assert_not_contains "$output" '"permissionDecision":"deny"' "writing a doc that mentions committing is not gated as a commit"
```

- [ ] **Step 2: Run it and verify it FAILS**

Run: `bash tests/test-review-reminders.sh`
Expected: FAIL — raw-payload matching sees the phrase inside the heredoc body.

- [ ] **Step 3: Port the extraction from the sibling**

Read `scripts/dangerous-commands.sh:44` and reuse its structure verbatim: extract
`tool_input.command` via `python3` `json.load` when `python3` is available, fall back to
raw-payload matching when it is not — never to no matching at all. Match the gate patterns
against the extracted command only.

Keep the fallback direction identical to the sibling's: a real commit must never slip through
because extraction failed. Over-matching on the fallback path is acceptable; under-matching is not.

- [ ] **Step 4: Verify both the new test and the existing gate behavior**

Run: `bash tests/test-review-reminders.sh`
Expected: the new assertion PASSES and every pre-existing assertion still PASSES — in particular
the ones proving a real `git commit` is still gated. If any of those flip, the extraction is
under-matching and the gate is now weaker than before; revert rather than adjust the test.

- [ ] **Step 5: Mirror to the `.ps1` twin**

Apply the same extraction to `scripts/review-reminders.ps1`, using the `ConvertFrom-Json`
approach already present in `scripts/dangerous-commands.ps1`.

- [ ] **Step 6: Update the stale comment**

Replace the falsified premise at `scripts/review-reminders.sh:36-40` with the reason the
extraction is now used, citing the 2026-08-20 falsification. Leaving the old comment in place
would re-argue the wrong design to the next reader.

- [ ] **Step 7: Commit**

Stage both scripts and the test.
Message: `fix: extract tool_input.command in review-reminders instead of matching raw payload`

---

## Out of scope, deliberately

- **Findings 4 and 9** (template propagation / staleness) — separate subsystem, own plan, sequenced first for shipping.
- **Findings 5 and 6** — belong with the `[NS-18]` / review-gate port.
- **Finding 7** (PostToolUse does not fire on non-zero tool exit) — peek-only fixes it structurally; no separate work here.
- **Finding 8** (per-platform matching semantics) — real, but a parity audit is its own effort. Task 1's
  harness is the prerequisite: it is the first place both implementations can be exercised on one machine.
  Three false positives were observed live on 2026-08-20 (a quoted `grep` pattern and two heredocs
  containing example commit commands), all in the safe over-matching direction.
- **The 11 unaudited scripts** — the downstream report covered ~5 of 16 and found defects in nearly
  every file opened. Task 4 touches all 8 `.sh` hooks, so it partially closes this, but a real audit
  is still owed and must not be marked done by this plan.
