# Pre-Approval Protocol Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make the adversarial "poke holes" pass mandatory before any approval ask. The procedure
goes in `standards/WORKFLOW.md`, enforced by a PMB-only Stop hook that sends back a turn ending in
an ask without a Findings section and a Recommendation.

**Architecture:** A Stop hook script pair, `scripts/pre-approval-check.{sh,ps1}`, reads the Stop
payload's `last_assistant_message` and classifies the ending. It then returns a JSON block decision,
or allows the turn and launches the "Claude has paused" notification detached and self-closing
(600 s). It replaces the existing modal popup Stop entry.
- That live entry differs from the template's, so `tests/test-mirror-parity.sh` gains a narrow,
  dated trial exemption (spec §5, option A+).
- A new "Pre-Approval Protocol" section in `WORKFLOW.md` holds the procedure, and supersedes
  Phase 3.5.

**Tech Stack:** Bash plus `python3` for JSON and regex on the `.sh` side; PowerShell 7 with .NET
regex on the `.ps1` side. The bash test harness is `tests/helpers/assert.sh`.

**Spec:** `docs/superpowers/specs/2026-09-21-pre-approval-protocol-design.md` (approved 2026-09-21,
amended 2026-09-22 with the user's A+ and self-closing-popup decisions).
Read it before starting; this plan does not re-derive its decisions.

---

## Before You Start: Constraints That Are Easy to Miss

1. **Run the whole plan from a session rooted in the worktree** (review finding P1). Task 1 creates
   the worktree and moves the session into it with `EnterWorktree`.
   - The commit gate and `/code-review` compute the review hash from their working directory
     (`code-review.md:232`), and `_review-gate-lib.sh:112-122` records that a dispatched subagent's
     ambient working directory can be wrong.
   - A session left in the main checkout could therefore hash that checkout's diff, which holds
     another session's uncommitted edits, and certify a worktree commit nobody reviewed.
   - **Never touch the main checkout** (`C:\Users\Mizzo\Claude\Personal-Memory-Bank`) after Task 1
     Step 1. It holds another session's uncommitted edits. Never edit, stash, commit, or restore
     anything there.
2. **Start every gated command with the literal
   `cd "C:/Users/Mizzo/Claude/Personal-Memory-Bank/.claude/worktrees/pre-approval-protocol" &&`**
   (`git commit`, `git push`). The gate derives the repo root from that leading `cd`. Around each
   review, prove its marker landed in the worktree and binds the worktree's diff.
   - **Never a variable.** The gate reads the command's literal text and never expands it. Checked
     2026-09-21 against `resolve_cd_root` and its PowerShell twin `Resolve-CdRoot`: `cd "$WT" &&`
     fails to resolve (`rc=1`) and silently falls back to the ambient root, and the literal path
     resolves. Shell variables also don't persist between Bash tool calls, and `cd ""` fails with
     "null directory". **No value in this plan is carried from one tool call to the next** (review
     finding N1).
   - Compare both checkouts' markers against the worktree diff's hash, not the main checkout's
     marker before and after. The other session may legitimately rewrite its own marker there.
   - The exact commands are in Tasks 7 and 10 (commits) and Task 11 (push).
3. **The spikes (Tasks 2–3) wire the worktree's `.claude/settings.json`,** which loads only for
   sessions rooted in the worktree, so peer sessions are never affected (review finding P2). The
   spike script still records and blocks only for your own `session_id`, as defense in depth.
4. **Stop-hook data is read on the NEXT turn.** Tasks 2–3 need the user to send a reply between
   turns. Tell them what to watch for before each spike turn.
5. **Every commit is gated.** `review-reminders` denies `git commit` without a diff-bound marker,
   which only `/code-review` or `/change-review` writes. Each commit step runs `/code-review` first.
   Never bypass the gate. This plan has two commits (Tasks 7 and 10) to keep the review count down.
6. **If compaction is blocked in the worktree session,** that is the known worktree-root defect in
   `pre-compact-check`: it reads the worktree's own `memory-bank/`, which another session is fixing.
   Do not edit the worktree's `memory-bank/` to satisfy it. Write a `handoff.md` dated today in the
   worktree root, per the Handoff Protocol.
7. **No `CLAUDE.md` or `memory-bank/` edits on this branch.** The startup-context ratchet fails any
   growth. `memory-bank/` updates happen from the main checkout after merge (Task 11).
8. **`tests/run.sh` moves `VERSION` aside and is not concurrency-safe.** Run it only inside this
   plan's own worktree, which nothing else uses.
9. **The dangerous-command hook blocks `rm -rf` in Bash tool commands.** Delete single files with
   `rm`; test scripts may use `rm -rf` internally on their own `mktemp` directories.
10. **The protocol applies to your own asks during execution.** Every question to the user carries a
   Recommendation, and every approval ask carries a Findings table too.
   - The rule applies from the start.
   - **The hook goes live for this session at Task 7 Step 1** (review finding F13). A mid-session
     settings edit took effect without a restart in the compact-nudge spike
     (`docs/superpowers/plans/2026-09-21-compact-nudge-hook.md:44-48`).
   - From then on, expect your own unsectioned asks to be blocked once. Add the sections, or use the
     escape, as the reason text says.
11. **Never trust the tree after a review.** On 2026-09-21 a `/code-review` domain subagent got past
   the gate with `git $VAR` and committed into the real worktree. Tasks 7 and 10 snapshot HEAD and
   the staged state to a file before each review and compare after it.
12. **Get an approved task contract before Task 1.** This plan changes more than four files, including
    hook wiring and CI tests. Propose the exact scope from the File Structure table, this plan and
    its spec if edited, and `.claude/contracts/active-task.json` itself. Wait for the user's approval.
    Task 1 writes the implementation contract in its worktree before editing files. It excludes the
    post-merge main-checkout memory-bank update: that is a separate task with its own approval and
    contract. If either contract expires, renew it before continuing.

## File Structure

| File | Responsibility |
|---|---|
| `scripts/pre-approval-check.sh` | Stop hook (bash): classify the ending, emit block JSON or notify, log blocks |
| `scripts/pre-approval-check.ps1` | Its twin (pwsh 7). Same rules, same outputs. This is what runs first on Windows |
| `tests/test-pre-approval-check.sh` | Behavior for both twins, plus the `settings.json` command chain |
| `.claude/settings.json` | The single `Stop` entry, replacing the modal popup |
| `.gitignore` | `.pmb-pre-approval.log` |
| `tests/test-mirror-parity.sh` | The dated trial exemption for the PMB-only Stop line (spec §5) |
| `tests/run.sh` | Register the suite (it has a completeness check) |
| `standards/WORKFLOW.md` | The Pre-Approval Protocol section; Phase 3.5 becomes a pointer |
| `docs/HOOKS-GUIDE.md`, `templates/docs/HOOKS-GUIDE.md` | §2 and the hook-types row. The template is hand-mirrored per its sync note |
| `scripts/_spike-stop.sh` (worktree, **temporary**, never committed) | Tasks 2–3 only. Deleted in Task 3 |

---

### Task 1: Create the worktree and move the session into it

- [ ] **Step 1: Create the worktree from a fresh `origin/main`** (per `superpowers:using-git-worktrees`)

This is the last command that runs in the main checkout. The reviewed spec and plan must be on
`origin/main` before execution; if either is missing, stop and land the docs PR first. Do not copy
an older plan from local `main` into the new worktree.

```bash
cd "C:/Users/Mizzo/Claude/Personal-Memory-Bank"
git fetch origin main
git cat-file -e origin/main:docs/superpowers/specs/2026-09-21-pre-approval-protocol-design.md || { echo "STOP: reviewed spec is not on origin/main"; exit 1; }
git cat-file -e origin/main:docs/superpowers/plans/2026-09-21-pre-approval-protocol.md || { echo "STOP: reviewed plan is not on origin/main"; exit 1; }
git show origin/main:docs/superpowers/plans/2026-09-21-pre-approval-protocol.md | grep -Fq 'Get an approved task contract before Task 1' || { echo "STOP: origin/main has an older plan; land the reviewed docs PR first"; exit 1; }
git worktree add .claude/worktrees/pre-approval-protocol -b feat/pre-approval-protocol origin/main
```

- [ ] **Step 2: Move the session into it**

Call `EnterWorktree` with `path` set to
`C:\Users\Mizzo\Claude\Personal-Memory-Bank\.claude\worktrees\pre-approval-protocol`. **If this
session was opened in that directory directly, skip the call.** That is the preferred route, because
it doesn't depend on whether `EnterWorktree` reloads hooks, which is unverified (review finding N3).
Either way, then:

```bash
pwd
git log -1 --oneline && git status --short
grep -c "Claude has paused and is waiting for input" .claude/settings.json
```

Expected:
- `pwd` ends in `.claude/worktrees/pre-approval-protocol`;
- `HEAD` is the tip of `origin/main`;
- no status lines;
- a count of `1`.

If the count is not `1`, `origin/main`'s Stop entry has changed since this plan was written. Re-read
it before Task 2 Step 4 and Task 7.

Every later task runs in this session, from the worktree. Commands below spell its path out in full
rather than through a variable, for the reason in constraint 2.

- [ ] **Step 3: Write the approved task contract in the worktree**

Follow `docs/CONTRACTS-GUIDE.md`: write `.claude/contracts/active-task.json` with the approved
scope, `status: "active"`, and `expires_at` eight hours from now. Do not start Step 4 or the spikes
until it exists. Task 11 marks it complete when this branch's work is finished.

- [ ] **Step 4: Confirm the spec and this plan are tracked in the worktree**

Task 1 Step 1 required both files on `origin/main`, so the new worktree inherits them. Confirm
that they are tracked and clean. From now on, record results in the worktree copy of this plan.

```bash
git ls-files --error-unmatch docs/superpowers/specs/2026-09-21-pre-approval-protocol-design.md docs/superpowers/plans/2026-09-21-pre-approval-protocol.md
git status --short -- docs/superpowers/
```

Expected: both paths from `git ls-files`, and no status lines. If either condition fails, stop
before Task 2.

---

### Task 2: Spike 1, capture a real Stop payload (worktree, temporary)

**Files:**
- Create (temporary, never committed): `scripts/_spike-stop.sh` in the worktree
- Modify (temporary): the worktree's `.claude/settings.json`, the `Stop` command
- Capture (outside the repo): `C:/Users/Mizzo/Claude/pmb-session-artifacts/pre-approval-spikes/spike-stop.jsonl`

- [ ] **Step 1: Confirm the session id this plan's commands use, and prepare the capture directory**

Every command in Tasks 2–3 spells its values out literally. Shell variables do not survive between
tool calls, so a value set in one step would be empty in the next (review finding N1). The commands
use session id `26736dfa-6f79-4dd3-8a21-62fd5081a05d`. Your system prompt names your scratchpad
directory, and its parent directory's name is your session id.

If the two differ (for example, because you started a fresh session in the worktree), substitute
yours throughout the worktree copy of this plan by replacing `YOUR-SESSION-ID` below with it. Then
re-read Tasks 2–3 before continuing:

```bash
cd "C:/Users/Mizzo/Claude/Personal-Memory-Bank/.claude/worktrees/pre-approval-protocol"
sed -i 's/26736dfa-6f79-4dd3-8a21-62fd5081a05d/YOUR-SESSION-ID/g' docs/superpowers/plans/2026-09-21-pre-approval-protocol.md
```

Then, whether or not you substituted:

```bash
mkdir -p "C:/Users/Mizzo/Claude/pmb-session-artifacts/pre-approval-spikes"
rm -f "C:/Users/Mizzo/Claude/pmb-session-artifacts/pre-approval-spikes/spike-stop.jsonl"
ls "C:/Users/Mizzo/Claude/pmb-session-artifacts/pre-approval-spikes"
```

Expected: no output from `ls`. A capture file left over from an earlier run would otherwise pass
Step 6's check.

- [ ] **Step 2: Confirm the worktree's `settings.json` is clean and still has the popup**

```bash
cd "C:/Users/Mizzo/Claude/Personal-Memory-Bank/.claude/worktrees/pre-approval-protocol"
git diff --quiet -- .claude/settings.json && echo CLEAN || echo DIRTY
grep -c "Claude has paused and is waiting for input" .claude/settings.json
```

Expected: `CLEAN`, then `1`. The Task 3 cleanup proves its restore with `git diff --quiet`, so it
needs a clean starting point.

- [ ] **Step 3: Write the spike script**

```bash
cd "C:/Users/Mizzo/Claude/Personal-Memory-Bank/.claude/worktrees/pre-approval-protocol"
cat > scripts/_spike-stop.sh <<'SPIKE'
#!/usr/bin/env bash
# TEMPORARY: Tasks 2-3 of docs/superpowers/plans/2026-09-21-pre-approval-protocol.md. Deleted in Task 3.
# Stands in for the worktree's Stop popup entry while the spikes run, so it notifies (detached) on
# every stop except its own block. It records and blocks ONLY for MY_SESSION_ID. Another session's
# payload is never written anywhere, and the capture goes to a fixed directory outside the repo.
MY_SESSION_ID="26736dfa-6f79-4dd3-8a21-62fd5081a05d"
MY_OUT_DIR="C:/Users/Mizzo/Claude/pmb-session-artifacts/pre-approval-spikes"
SENTINEL_A="PMB-SPIKE-"; SENTINEL_B="BLOCK-NOW"   # joined at runtime, so quoting this file never matches
BLOCKED=0
notify() {
    ( powershell.exe -NoProfile -Command "(New-Object -ComObject WScript.Shell).Popup('Claude has paused and is waiting for input.', 600, 'Claude Code', 64) | Out-Null"
      osascript -e 'display notification "Claude has paused and is waiting for input." with title "Claude Code"'
      notify-send 'Claude Code' 'Claude has paused and is waiting for input.'
    ) >/dev/null 2>&1 </dev/null &
}
trap '[ "$BLOCKED" = "1" ] || notify; exit 0' EXIT
INPUT=$(cat 2>/dev/null)
RESULT=$(printf '%s' "$INPUT" | MY_SID="$MY_SESSION_ID" OUT_DIR="$MY_OUT_DIR" SENTINEL="${SENTINEL_A}${SENTINEL_B}" KILL="${PMB_PRE_APPROVAL:-}" python3 -c '
import datetime, json, os, sys
try:
    d = json.load(sys.stdin)
except Exception:
    print("allow"); sys.exit(0)
if not isinstance(d, dict) or d.get("session_id") != os.environ["MY_SID"]:
    print("allow"); sys.exit(0)
m = d.get("last_assistant_message")
msg = m if isinstance(m, str) else None
rec = {"ts": datetime.datetime.now().isoformat(timespec="seconds"), "keys": sorted(d.keys()),
       "stop_hook_active": d.get("stop_hook_active"), "prompt_id": d.get("prompt_id"),
       "msg_present": msg is not None, "msg_len": len(msg or ""),
       "msg_head": (msg or "").replace(os.environ["SENTINEL"], "<SENTINEL>")[:60],
       "msg_tail": (msg or "").replace(os.environ["SENTINEL"], "<SENTINEL>")[-60:],
       "env_PMB_PRE_APPROVAL": os.environ.get("KILL", "")}
with open(os.path.join(os.environ["OUT_DIR"], "spike-stop.jsonl"), "a", encoding="utf-8") as f:
    f.write(json.dumps(rec) + "\n")
blk = bool(msg) and os.environ["SENTINEL"] in msg and d.get("stop_hook_active") is not True
print("block" if blk else "allow")
' 2>/dev/null)
if [ "$RESULT" = "block" ]; then
    BLOCKED=1
    printf '%s\n' '{"decision":"block","reason":"SPIKE: sentinel seen. Reply with one line: spike continuation received."}'
fi
exit 0
SPIKE
bash -n scripts/_spike-stop.sh && grep -c '^MY_SESSION_ID="26736dfa-6f79-4dd3-8a21-62fd5081a05d"$' scripts/_spike-stop.sh
```

Expected: `1`. The script parses and carries your session id.

**Why bash-only for the spike:** what is under test is "JSON on stdout plus `2>/dev/null || true`
wiring blocks the stop", not the pwsh-first ordering. A `.ps1` spike twin would double the work
without testing anything more.

- [ ] **Step 4: Point the `Stop` entry at the spike**

Edit `.claude/settings.json`, replacing this `command` value:

```
"command": "powershell.exe -Command \"Add-Type -AssemblyName System.Windows.Forms; [System.Windows.Forms.MessageBox]::Show('Claude has paused and is waiting for input.','Claude Code',[System.Windows.Forms.MessageBoxButtons]::OK,[System.Windows.Forms.MessageBoxIcon]::Information)\" 2>/dev/null; osascript -e 'display notification \"Claude has paused and is waiting for input.\" with title \"Claude Code\"' 2>/dev/null; notify-send 'Claude Code' 'Claude has paused and is waiting for input.' 2>/dev/null; true"
```

with:

```
"command": "bash scripts/_spike-stop.sh 2>/dev/null || true"
```

Keep the original line. Task 3 Step 6 restores it byte for byte.

```bash
python3 -c "import json; json.load(open('.claude/settings.json', encoding='utf-8')); print('valid json')"
```

Expected: `valid json`.

- [ ] **Step 5: End a turn with two text blocks around a tool call**

Tell the user: "Next turn is spike 1. Reply `continue` when it ends; watch that the paused popup
still appears." Then, in one turn:
1. Write text containing `SPIKE-FIRST-BLOCK`.
2. Make one trivial tool call (`date`).
3. Write text containing `SPIKE-LAST-BLOCK`, and end the turn.

- [ ] **Step 6: On the next turn, read the capture**

```bash
F="C:/Users/Mizzo/Claude/pmb-session-artifacts/pre-approval-spikes/spike-stop.jsonl"
test -s "$F" && tail -n 1 "$F" || echo "NO CAPTURE FILE"
```

**If it prints `NO CAPTURE FILE`, STOP** (review finding P3). Either the worktree's hooks did not
load for this session, or the session id in the spike script is wrong. Do Task 3 Step 6 (cleanup)
and report to the user. Do not retry by wiring the main checkout.

The likely cause is that `EnterWorktree` switched the directory without reloading hooks (review
finding N3: its schema confirms it enters an existing worktree by `path`, but says nothing about
hook reload). The fallback is for the user to open a fresh session whose working directory is the
worktree. That session starts again from Task 2 Step 1, where the session-id substitution applies.

Otherwise, expect one JSON record with `keys`, `stop_hook_active`, `prompt_id`, `msg_present`,
`msg_head` and `msg_tail`. Answer three questions:
- Is `last_assistant_message` in `keys`, with `msg_present: true`?
- Is `stop_hook_active` in `keys`?
- Does `msg_head` contain `SPIKE-FIRST-BLOCK`? If yes, the field holds the whole turn's text. If it
  starts at `SPIKE-LAST-BLOCK`, it holds only the last text block, which the spec already requires
  the sections to be in.

- [ ] **Step 7: Record the results in this plan**

Add a `**Results (date):**` line under this task: `last_assistant_message` present yes/no, its
scope (whole turn or last block), and `stop_hook_active` present yes/no. **If
`last_assistant_message` is absent, STOP:** do Task 3 Step 6 (cleanup) only, and report to the user
that the spec's input assumption failed.

---

### Task 3: Spike 2, block mechanics, loop guard, kill switch, then cleanup (worktree)

**Files:** the same two temporary files as Task 2, restored and deleted at the end.

- [ ] **Step 1: Tell the user exactly what to watch**

"Next turn triggers a deliberate block. Please watch for three things:
1. Did a 'Claude has paused' popup appear *before* I continued on my own? (It should not.)
2. Did I continue without you clicking anything? (I should.)
3. Did a popup appear once I finally stopped? (It should.)

Reply `continue` afterwards."

- [ ] **Step 2: End a turn whose text contains the joined sentinel**

The sentinel is `PMB-SPIKE-` immediately followed by `BLOCK-NOW`, written as one word. It appears
split here so that quoting this plan doesn't trigger it.

**Put it in the turn's final text block** (review finding F12). If `last_assistant_message` turns out
to hold only the last block (spike 1), a sentinel placed earlier is never seen, and Step 5 would
falsely record "No block". The capture file replaces the sentinel with `<SENTINEL>`, so quoting a
record in a later reply can't re-trigger the block.

Expected:
- The harness returns the reason "SPIKE: sentinel seen…".
- You reply with one line, `spike continuation received`, and the turn ends.
- The Stop hook fires again, this time with `stop_hook_active` true, and allows.

- [ ] **Step 3: On the next turn, read the last two records and ask the user**

```bash
tail -n 2 "C:/Users/Mizzo/Claude/pmb-session-artifacts/pre-approval-spikes/spike-stop.jsonl"
```

Expected:
- **First record:** the sentinel turn, with `stop_hook_active` false or absent.
- **Second record:** the continuation. Note whether `stop_hook_active` is `true`, and whether
  `prompt_id` equals the first record's.

Ask the user their three observations from Step 1.

- [ ] **Step 4: Check the kill switch's reach (review finding N5)**

Add `"PMB_PRE_APPROVAL": "off"` to the `env` block of the worktree's `.claude/settings.json`,
directly after `"DISABLE_NON_ESSENTIAL_MODEL_CALLS": "1"` (add a comma to that line). End a normal
turn. On the next turn:

```bash
tail -n 1 "C:/Users/Mizzo/Claude/pmb-session-artifacts/pre-approval-spikes/spike-stop.jsonl"
```

Read `env_PMB_PRE_APPROVAL`:
- `off` means the env block reaches hooks without a restart.
- Empty means it needs a session restart. Do not restart; record it.

Then remove the line you added, and the comma.

- [ ] **Step 5: Apply the go/no-go gate**

| Observation | Action |
|---|---|
| No block: no reason came back, no continuation | **STOP.** Do Step 6, then report to the user. The spec's block channel needs redesign before anything else |
| A popup appeared on the block, or the continuation waited for a click | **STOP.** Do Step 6, then report. Detaching did not solve F1 |
| No popup at the final stop (observation 3) | **STOP.** Do Step 6, then report. The harness may kill a detached child when the hook exits, so the notifier design needs changing (review finding P3) |
| Fewer than two new records in the capture file | **STOP.** Do Step 6, then report. The hook did not fire on the block and on the continuation, and the other rows cannot be judged |
| `stop_hook_active` not `true` on the continuation's record | **STOP.** Do Step 6, then report whether `prompt_id` stayed the same, since that's the candidate alternative guard. See the note below the table |
| All as expected | **GO** to Step 6, then Task 4 |

**Stated deviation from the spec on the `stop_hook_active` row.** The spec's contingency is a
log-only hook "until a guard is proven". Building one here would deliver only trial data, and
choosing the guard that could ever enable blocking is a design decision. So the plan stops and hands
the user the evidence rather than building a speculative variant.

- [ ] **Step 6: Clean up the worktree (always, GO or STOP)**

Restore the `Stop` command to the exact original line quoted in Task 2 Step 4. Make sure the
`PMB_PRE_APPROVAL` line from Step 4 is gone. Then:

```bash
cd "C:/Users/Mizzo/Claude/Personal-Memory-Bank/.claude/worktrees/pre-approval-protocol"
rm scripts/_spike-stop.sh
git diff --quiet -- .claude/settings.json && echo "settings restored" || git diff -- .claude/settings.json
git status --short -- scripts/_spike-stop.sh .claude/settings.json
python3 -c "import json; json.load(open('.claude/settings.json', encoding='utf-8')); print('valid json')"
```

Expected: `settings restored`, no status lines, `valid json`.

- [ ] **Step 7: Record the results in this plan**

Add a `**Results (date):**` line under this task. Record:
- whether the block worked;
- the user's three popup observations;
- `stop_hook_active` on the continuation, and whether `prompt_id` changed;
- kill-switch reach: "next turn" or "needs restart";
- GO or STOP.

Then delete the capture, which holds the first and last 60 characters of this session's messages
and has no further use once the results are written down (review finding B):

```bash
rm -f "C:/Users/Mizzo/Claude/pmb-session-artifacts/pre-approval-spikes/spike-stop.jsonl"
rmdir "C:/Users/Mizzo/Claude/pmb-session-artifacts/pre-approval-spikes" && echo "capture removed"
```

Task 8 Step 3 and Task 9 Step 2 use the kill-switch result.

---

### Task 4: Write the failing tests (script level)

**Files:**
- Create: `tests/test-pre-approval-check.sh`

- [ ] **Step 1: Write the test file**

````bash
#!/usr/bin/env bash
# tests/test-pre-approval-check.sh -- the Stop hook that enforces the Pre-Approval Protocol.
#
# WHY both shells: settings.json runs the .ps1 first wherever pwsh exists, so the .sh passing alone
# would leave the code path that actually runs on Windows untested. The .ps1 block is skipped loudly
# (fatal under PMB_REQUIRE_PARITY=1) where pwsh is absent, matching test-pre-compact-check.sh.
#
# WHY every notification assertion waits: the notifier is launched detached by design, so it lands
# after the hook returns. "Not notified" waits too, or it would pass vacuously.
set -u

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$REPO_ROOT/tests/helpers/assert.sh"

echo "=== pre-approval-check tests ==="

SB="$(mktemp -d 2>/dev/null || mktemp -d -t pmb-preapproval-test)"
trap 'rm -rf "$SB"' EXIT
mkdir -p "$SB/scripts"
cp "$REPO_ROOT/scripts/pre-approval-check.sh" "$REPO_ROOT/scripts/pre-approval-check.ps1" "$SB/scripts/" 2>/dev/null

# A fresh stub file per case (review finding T2): a detached notifier from the previous case can land
# ~200 ms after its hook returns, and must not satisfy the next case's "notified" check.
CASE=0
new_stub() {
    CASE=$((CASE + 1))
    STUB="$SB/notify-$CASE.log"
    STUB_NATIVE="$STUB"
    command -v cygpath >/dev/null 2>&1 && STUB_NATIVE="$(cygpath -w "$STUB")"
}
new_stub

now_ms() { python3 -c 'import time; print(int(time.time() * 1000))'; }

# payload MESSAGE [STOP_HOOK_ACTIVE 0|1] -- the message travels in argv, never into Python source.
payload() {
    python3 -c 'import json, sys
print(json.dumps({"session_id": "testsess-0001-aaaa", "prompt_id": "p-1", "hook_event_name": "Stop",
                  "stop_hook_active": sys.argv[2] == "1", "last_assistant_message": sys.argv[1]}))' "$1" "${2:-0}"
}

# payload_utf8_dashes -- a tier A ask followed by 150 em dashes, sent as raw UTF-8 rather than
# \u-escaped, as the harness may send it (review finding F5). Built inside Python so no non-ASCII
# text crosses argv or a console encoding on the way.
payload_utf8_dashes() {
    python3 -c 'import json, sys
msg = "Want me to push it now? " + "\u2014" * 150 + " ok."
sys.stdout.buffer.write(json.dumps({"session_id": "testsess-0001-aaaa", "stop_hook_active": False,
                  "last_assistant_message": msg}, ensure_ascii=False).encode("utf-8"))'
}

# run_case SHELL BODY [ENV=VALUE...] -- fresh state, then one hook run. Sets OUT, CODE, MS.
run_case() {
    rm -f "$SB/.pmb-pre-approval.log" "$SB/.pmb-hook-errors.log"
    new_stub
    rerun_case "$@"
}
# rerun_case -- the same, but keeps the log files from the previous run.
rerun_case() {
    local shell="$1" body="$2" t0 t1
    shift 2
    t0=$(now_ms)
    if [ "$shell" = "ps1" ]; then
        OUT=$(cd "$SB" && printf '%s' "$body" | env PMB_NOTIFY_STUB="$STUB_NATIVE" "$@" pwsh -NoProfile -NonInteractive -File scripts/pre-approval-check.ps1 2>/dev/null)
    else
        OUT=$(cd "$SB" && printf '%s' "$body" | env PMB_NOTIFY_STUB="$STUB" "$@" bash scripts/pre-approval-check.sh 2>/dev/null)
    fi
    CODE=$?
    t1=$(now_ms)
    MS=$((t1 - t0))
}

# notified TIMEOUT_S -- 0 if the detached notifier wrote its stub line within the timeout.
notified() {
    local i=0 max=$(( ${1:-6} * 4 ))
    while [ "$i" -lt "$max" ]; do
        [ -s "$STUB" ] && return 0
        sleep 0.25
        i=$((i + 1))
    done
    return 1
}

log_text() { cat "$SB/.pmb-pre-approval.log" 2>/dev/null; }

check_shell() {
    local S="$1" ask
    echo ""
    echo "--- [$S] classification ---"

    run_case "$S" "$(payload 'Done. The file is updated and the suite is green.')"
    assert_equals "$OUT" "" "[$S] a statement is allowed silently"
    notified 6; assert_exit_zero "$?" "[$S] a statement still shows the paused notification"

    run_case "$S" "$(payload 'I checked it. Want me to push it now? Zanzibar')"
    assert_contains "$OUT" '"decision":"block"' "[$S] a tier A ask without sections is blocked"
    assert_contains "$OUT" 'Not an approval ask:' "[$S] a tier A block carries the tier A escape"
    assert_contains "$(log_text)" 'event=block tier=A missing=both' "[$S] a tier A block is logged with what was missing"
    assert_not_contains "$(log_text)" 'Zanzibar' "[$S] the log never contains message text"
    sleep 3; assert_file_not_exists "$STUB" "[$S] no notification on a block"

    for ask in 'Type "approved" to begin, or tell me what to adjust.' \
               'Review the spec and approve it or tell me what to change.' \
               'Say the word and I will push the branch.' \
               'Since it is a deletion, I will wait for your go-ahead.' \
               'Please review it and let me know if you want any changes before we move to the implementation plan.'; do
        run_case "$S" "$(payload "$ask")"
        assert_contains "$OUT" '"decision":"block"' "[$S] tier A: $ask"
    done

    run_case "$S" "$(payload $'Review complete.\n\n**Verdict:** Approve')"
    assert_equals "$OUT" "" "[$S] a bare Verdict: Approve line is not an ask"
    run_case "$S" "$(payload 'The protocol covers anything I ask you to approve.')"
    assert_equals "$OUT" "" "[$S] mentioning approve in prose is not an ask"

    run_case "$S" "$(payload 'Which should we brainstorm first?')"
    assert_contains "$OUT" 'No recommendation applies:' "[$S] a tier B question without a Recommendation is blocked"
    assert_contains "$(log_text)" 'tier=B missing=recommendation' "[$S] a tier B block is logged"

    run_case "$S" "$(payload '**Which should we brainstorm first?**')"
    assert_contains "$OUT" '"decision":"block"' "[$S] trailing markdown after the ? is still a question"

    run_case "$S" "$(payload $'## Recommendation\nStart with the hook, because it unblocks the rest.\n\nWhich should we brainstorm first?')"
    assert_equals "$OUT" "" "[$S] tier B with a Recommendation heading is allowed"

    run_case "$S" "$(payload $'**My recommendation:** start with the hook.\n\nWhich should we brainstorm first?')"
    assert_equals "$OUT" "" "[$S] a lower-case recommendation in a bold label counts (case-insensitive)"

    run_case "$S" "$(payload $'## Findings\n| # | Question | How | Result |\n|---|---|---|---|\n| 1 | x | `ls` | ok |\n\n## Recommendation\nShip it.\n\nWant me to proceed?')"
    assert_equals "$OUT" "" "[$S] tier A with Findings and Recommendation is allowed"
    notified 6; assert_exit_zero "$?" "[$S] an allowed ask shows the notification"

    run_case "$S" "$(payload $'## FINDINGS\n| 1 | x | `ls` | ok |\n\n## RECOMMENDATION\nShip it.\n\nWant me to proceed?')"
    assert_equals "$OUT" "" "[$S] upper-case section headings count (review finding F10)"

    # 150 em dashes are 150 characters but 450 bytes. Decoded as UTF-8, the ask stays inside the
    # 400-character window; decoded byte by byte (the ibm437/cp1252 bug), it falls outside and is missed.
    run_case "$S" "$(payload_utf8_dashes)"
    assert_contains "$OUT" '"decision":"block"' "[$S] raw UTF-8 input is decoded as UTF-8 (review finding F5)"

    run_case "$S" "$(payload $'## Findings\n| 1 | x | `ls` | ok |\n\nWant me to proceed?')"
    assert_contains "$(log_text)" 'missing=recommendation' "[$S] Findings without a Recommendation is blocked"

    run_case "$S" "$(payload $'## Supported Findings\n| Domain | Severity |\n\n**Verdict:** Approve\n\nWant me to commit?')"
    assert_equals "$OUT" "" "[$S] a /code-review-shaped report (Supported Findings + Verdict) is allowed"

    echo "--- [$S] loop guard and post-block logging ---"
    run_case "$S" "$(payload 'Not an approval ask: that was a status update.' 1)"
    assert_equals "$OUT" "" "[$S] stop_hook_active true is always allowed"
    assert_contains "$(log_text)" 'event=post-block findings=no recommendation=no escape=not_an_approval_ask' "[$S] the tier A escape is logged"
    notified 6; assert_exit_zero "$?" "[$S] the post-block stop shows the notification"

    run_case "$S" "$(payload 'I checked it. Want me to push it now?' 1)"
    assert_equals "$OUT" "" "[$S] stop_hook_active true allows even an unsectioned tier A ask (review finding F8)"

    run_case "$S" "$(payload 'No recommendation applies: I need the repo URL from you.' 1)"
    assert_contains "$(log_text)" 'escape=no_recommendation_applies' "[$S] the tier B escape is logged separately"

    run_case "$S" "$(payload $'## Findings\n| 1 | x | `ls` | ok |\n\n## Recommendation\nShip it.\n\nWant me to proceed?' 1)"
    assert_contains "$(log_text)" 'findings=yes recommendation=yes escape=none' "[$S] sections added after a block are logged"

    echo "--- [$S] kill switch, fail-open, detachment ---"
    run_case "$S" "$(payload 'Want me to push it now?')" PMB_PRE_APPROVAL=off
    assert_equals "$OUT" "" "[$S] PMB_PRE_APPROVAL=off allows even a tier A ask"
    assert_file_not_exists "$SB/.pmb-pre-approval.log" "[$S] PMB_PRE_APPROVAL=off logs nothing"
    notified 6; assert_exit_zero "$?" "[$S] PMB_PRE_APPROVAL=off still notifies"

    run_case "$S" "$(payload '')"
    assert_equals "$OUT" "" "[$S] an empty message is allowed"

    run_case "$S" 'this is not json'
    assert_equals "$OUT" "" "[$S] malformed JSON is allowed"
    assert_exit_zero "$CODE" "[$S] malformed JSON exits 0"
    notified 6; assert_exit_zero "$?" "[$S] malformed JSON still notifies"
    assert_contains "$(log_text)" 'event=failopen kind=parse' "[$S] a parse fail-open is recorded in the trial log (review finding F6)"
    rerun_case "$S" 'this is not json'
    assert_equals "$(grep -c 'kind=parse' "$SB/.pmb-hook-errors.log" 2>/dev/null)" "1" "[$S] a repeated parse error is logged once"

    run_case "$S" "$(payload 'Want me to push it now?')" PMB_PRE_APPROVAL_TEST_FAULT=1
    assert_equals "$OUT" "" "[$S] an unexpected fault allows the turn"
    assert_exit_zero "$CODE" "[$S] an unexpected fault exits 0"
    notified 6; assert_exit_zero "$?" "[$S] an unexpected fault still notifies"
    assert_contains "$(log_text)" 'event=failopen kind=' "[$S] an unexpected fault is recorded in the trial log (review finding F6)"

    run_case "$S" "$(payload 'Done.')" PMB_NOTIFY_STUB_DELAY=6
    assert_contains "fast=$([ "$MS" -lt 3000 ] && echo yes || echo no) ms=$MS" "fast=yes" "[$S] a 6 s notifier does not delay the hook (under 3 s)"
    notified 10; assert_exit_zero "$?" "[$S] the slow notifier still ran after the hook returned"
}

check_shell sh

if command -v pwsh >/dev/null 2>&1; then
    check_shell ps1
else
    echo ""
    echo "--- [ps1] SKIPPED (pwsh not on PATH) ---"
    echo "!!! WARNING: the .ps1 twin did NOT run. Set PMB_REQUIRE_PARITY=1 to make this a failure."
    if [ "${PMB_REQUIRE_PARITY:-0}" = "1" ]; then
        assert_contains "pwsh-missing" "pwsh-present" "PMB_REQUIRE_PARITY=1 but pwsh is not on PATH"
    fi
fi

print_summary
````

Four deviations from the spec's wording are deliberate. The fifth, about `stop_hook_active`, is
stated in Task 3's gate.
- **The timing bound is 3 s against a 6 s stub**, not 1.5 s against 5 s. `pwsh` cold start
  measured 335–730 ms on this machine, and `Start-Process` about 680 ms, so 1.5 s would be flaky.
  The test still proves the hook returns long before its notifier finishes.
- **The forced-fault case uses `PMB_PRE_APPROVAL_TEST_FAULT=1`**, a test-only switch in both
  scripts. There is no payload that reliably makes both classifiers throw.
- **Per-case tests call each script directly**, not through the exact `settings.json` command. The
  exact string is covered by Task 7's chain tests (the synchronous primary path and the fallback),
  which is where the wiring can break.
- **Error-log deduplication is per log file, not per session, for errors where the session can't
  be read.** A parse failure has no readable `session_id` by definition, so its key uses
  `session=-`. In practice each kind of error is logged once, until someone deletes
  `.pmb-hook-errors.log`, which `mb doctor` already tells them to do once it's resolved. This is
  stricter than the spec's "once per session", never noisier.

- [ ] **Step 2: Run it and confirm it fails**

```bash
bash tests/test-pre-approval-check.sh 2>&1 | tail -5
```

Expected: FAIL lines, and `Results: N passed, M failed` with M > 0. The scripts don't exist yet.
Assertions that expect silence still pass vacuously; a review measured 18 passed and 28 failed on
the `[sh]` half (review finding L5).

---

### Task 5: Implement `scripts/pre-approval-check.sh`

**Files:**
- Create: `scripts/pre-approval-check.sh`

- [ ] **Step 1: Write the script**

```bash
#!/usr/bin/env bash
# pre-approval-check.sh -- Stop hook enforcing the Pre-Approval Protocol (standards/WORKFLOW.md).
#
# Tier A: a turn ending in an approve-or-choose ask must carry a "Findings" heading AND a
# Recommendation. Tier B: a turn ending in any other question must carry a Recommendation.
# Spec: docs/superpowers/specs/2026-09-21-pre-approval-protocol-design.md
#
# WHY a JSON decision on stdout and exit 0, never exit 2: settings.json wires hooks as
# `... 2>/dev/null || true`, which erases an exit code and discards stderr -- the same finding
# dangerous-commands.sh records for PreToolUse.
#
# WHY this script owns the "Claude has paused" notification: the old popup was a separate, modal
# Stop entry the harness waited on, so a block would have shown "waiting for input" about an ask
# that was about to be replaced, and the redo could not start until the user clicked OK.

LOG=".pmb-pre-approval.log"
ERR_LOG=".pmb-hook-errors.log"
BLOCKED=0

REASON_A='Pre-approval protocol: this message asks the user to approve or choose, but lacks a Findings section and/or a Recommendation. Run the checks the options depend on (standards/WORKFLOW.md, Pre-Approval Protocol) and re-send the ask with both. If it does not ask for approval or a choice, reply `Not an approval ask:` with one line of why, and stop.'
REASON_B='Pre-approval protocol: this message ends in a question but gives no Recommendation. Add what you recommend and why. If no recommendation can apply (for example, you need a fact only the user has), reply `No recommendation applies:` with one line of why, and stop.'

notify() {
    # WHY one backgrounding line shared by the stub and the real popup (review finding T1): the tests
    # swap only the inner command, so they exercise the exact launch production uses.
    # WHY the redirects: a Git Bash background job that keeps the hook's pipes open holds the hook
    # until the child exits (measured 3,126 ms without, 194 ms with).
    (
        if [ -n "${PMB_NOTIFY_STUB:-}" ]; then
            sleep "${PMB_NOTIFY_STUB_DELAY:-0}"
            echo notify >> "$PMB_NOTIFY_STUB"
        else
            # WHY WScript.Shell.Popup with a 600 s timeout, not a MessageBox: nothing else closes a
            # detached popup, so ignored ones would pile up (user decision 2026-09-22, spec section 3).
            powershell.exe -NoProfile -Command "(New-Object -ComObject WScript.Shell).Popup('Claude has paused and is waiting for input.', 600, 'Claude Code', 64) | Out-Null"
            osascript -e 'display notification "Claude has paused and is waiting for input." with title "Claude Code"'
            notify-send 'Claude Code' 'Claude has paused and is waiting for input.'
        fi
    ) >/dev/null 2>&1 </dev/null &
    return 0
}

# One line per session per kind, so a persistent fault cannot bury other hooks' errors in
# `mb doctor`'s `tail -3` of the shared log.
log_error_once() {
    local key="pre-approval-check.sh: session=$1 kind=$2"
    grep -qF -- "$key" "$ERR_LOG" 2>/dev/null && return 0
    printf '[%s] [HOOK] %s %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$key" "$3" >> "$ERR_LOG" 2>/dev/null
    return 0
}

# Every fail-open also goes to the trial log (review finding F6): a truncated payload would otherwise
# let exactly the long, Findings-heavy asks through while the trial counted only blocks.
log_failopen() {
    printf '%s session=%s event=failopen kind=%s\n' "$(date '+%Y-%m-%dT%H:%M:%S')" "$1" "$2" >> "$LOG" 2>/dev/null
    return 0
}

trap '[ "$BLOCKED" = "1" ] || notify; exit 0' EXIT

[ "${PMB_PRE_APPROVAL:-}" = "off" ] && exit 0

INPUT=$(cat 2>/dev/null)

if ! command -v python3 >/dev/null 2>&1; then
    log_error_once "-" "no-python3" "python3 not found; turn allowed without checking"
    log_failopen "-" "no-python3"
    exit 0
fi

# The classifier. The payload reaches it only on stdin, never interpolated into this source.
# pre-approval-check.ps1 implements the same rules; tests/test-pre-approval-check.sh holds them in parity.
PY_SRC=$(cat <<'PY'
import json, re, sys
FLAGS = re.I | re.M
ASK = re.compile(r'should I (proceed|continue)|want me to|shall I|go ahead|does that work|which (option|approach|would you)|your call|tell me (which|whether|how|what)|how would you like|would you like|proceed\?|(say|type) "approved"|\bapprove (it|this|that|the)\b|\bapprove\?|say the word|your go-ahead|let me know (if|once|whether|when|which)|before (I|we) (move|proceed|continue|start|begin)', FLAGS)
FINDINGS = re.compile(r'^#{1,4}[ \t].*\bfindings\b', FLAGS)
RECOMMEND = re.compile(r'^#{1,4}[ \t].*recommend|\*\*[^*\n]*recommend|\*\*verdict:', FLAGS)
ESC_A = re.compile(r'^\W*not an approval ask:', re.I)
ESC_B = re.compile(r'^\W*no recommendation applies:', re.I)
try:
    # WHY bytes decoded as UTF-8: on Windows sys.stdin uses the locale code page, which splits each
    # non-ASCII character into several and shrinks the 400-character window (review finding F5).
    d = json.loads(sys.stdin.buffer.read().decode("utf-8", "replace"))
    if not isinstance(d, dict):
        raise ValueError("payload is not a JSON object")
except Exception:
    print("ERROR - parse")
    sys.exit(0)
sid = str(d.get("session_id") or "-")[:8]
msg = d.get("last_assistant_message")
msg = msg if isinstance(msg, str) else ""
has_f = bool(FINDINGS.search(msg))
has_r = bool(RECOMMEND.search(msg))
if d.get("stop_hook_active") is True:
    esc = "not_an_approval_ask" if ESC_A.search(msg) else ("no_recommendation_applies" if ESC_B.search(msg) else "none")
    print("POSTBLOCK %s findings=%s recommendation=%s escape=%s" % (sid, "yes" if has_f else "no", "yes" if has_r else "no", esc))
    sys.exit(0)
if not msg.strip():
    print("ALLOW " + sid)
    sys.exit(0)
end = msg[-400:]
tier_a = bool(ASK.search(end))
lines = [l for l in re.split(r'\r\n|\n|\r', end) if l.strip()]
tier_b = (not tier_a) and bool(lines) and lines[-1].rstrip().rstrip("*_`'\")").rstrip().endswith("?")
if tier_a and not (has_f and has_r):
    missing = "both" if not (has_f or has_r) else ("findings" if not has_f else "recommendation")
    print("BLOCK %s A %s" % (sid, missing))
elif tier_b and not has_r:
    print("BLOCK %s B recommendation" % sid)
else:
    print("ALLOW " + sid)
PY
)

if [ "${PMB_PRE_APPROVAL_TEST_FAULT:-}" = "1" ]; then
    RESULT=""   # test-only: simulates a classifier failure (tests/test-pre-approval-check.sh)
else
    RESULT=$(printf '%s' "$INPUT" | python3 -c "$PY_SRC" 2>/dev/null)
fi

read -r KIND SID REST <<EOF
$RESULT
EOF
NOW=$(date '+%Y-%m-%dT%H:%M:%S')

case "$KIND" in
    BLOCK)
        read -r TIER MISSING <<EOF
$REST
EOF
        BLOCKED=1
        printf '%s session=%s event=block tier=%s missing=%s\n' "$NOW" "$SID" "$TIER" "$MISSING" >> "$LOG" 2>/dev/null
        if [ "$TIER" = "A" ]; then REASON="$REASON_A"; else REASON="$REASON_B"; fi
        printf '{"decision":"block","reason":"%s"}\n' "$REASON"
        ;;
    POSTBLOCK)
        printf '%s session=%s event=post-block %s\n' "$NOW" "$SID" "$REST" >> "$LOG" 2>/dev/null
        ;;
    ALLOW)
        ;;
    ERROR)
        log_error_once "$SID" "$REST" "payload could not be parsed; turn allowed without checking"
        log_failopen "$SID" "$REST"
        ;;
    *)
        log_error_once "-" "no-result" "classifier produced no result; turn allowed without checking"
        log_failopen "-" "no-result"
        ;;
esac
exit 0
```

The reason texts contain no `"` or `\`, so `printf` into the JSON needs no escaping. Keep it that
way if you ever edit them.

- [ ] **Step 2: Syntax check, then run the suite**

```bash
bash -n scripts/pre-approval-check.sh && echo "syntax ok"
bash tests/test-pre-approval-check.sh 2>&1 | grep -E "^\s+FAIL: \[sh\]|Results:"
```

Expected: `syntax ok`, and **no** `FAIL: [sh]` lines. `[ps1]` failures are expected until Task 6.
The `Results:` line still shows failures from the `[ps1]` block.

---

### Task 6: Implement `scripts/pre-approval-check.ps1`

**Files:**
- Create: `scripts/pre-approval-check.ps1`

- [ ] **Step 1: Write the script**

```powershell
<#
.SYNOPSIS
    Stop hook enforcing the Pre-Approval Protocol (standards/WORKFLOW.md). Twin of
    pre-approval-check.sh; tests/test-pre-approval-check.sh holds the two in parity.
.DESCRIPTION
    Tier A: a turn ending in an approve-or-choose ask must carry a "Findings" heading AND a
    Recommendation. Tier B: a turn ending in any other question must carry a Recommendation.
    Emits {"decision":"block",...} on stdout and always exits 0: settings.json wires hooks as
    `... 2>/dev/null || true`, which erases exit codes. Owns the "Claude has paused" notification,
    launched detached on every exit except a block.
    Spec: docs/superpowers/specs/2026-09-21-pre-approval-protocol-design.md
#>
$ErrorActionPreference = 'Stop'
$script:blocked = $false
$logPath = '.pmb-pre-approval.log'
$errLogPath = '.pmb-hook-errors.log'
$reasonA = 'Pre-approval protocol: this message asks the user to approve or choose, but lacks a Findings section and/or a Recommendation. Run the checks the options depend on (standards/WORKFLOW.md, Pre-Approval Protocol) and re-send the ask with both. If it does not ask for approval or a choice, reply `Not an approval ask:` with one line of why, and stop.'
$reasonB = 'Pre-approval protocol: this message ends in a question but gives no Recommendation. Add what you recommend and why. If no recommendation can apply (for example, you need a fact only the user has), reply `No recommendation applies:` with one line of why, and stop.'

# WHY explicit IgnoreCase rather than relying on -match's default: the .sh twin's Python `re` is
# case-sensitive unless told otherwise, and a silent difference let "**My recommendation:**" pass
# one twin and fail the other (review finding N3). Both twins now pin it.
$rxOpts = [System.Text.RegularExpressions.RegexOptions]::IgnoreCase -bor [System.Text.RegularExpressions.RegexOptions]::Multiline
$askRx = [regex]::new('should I (proceed|continue)|want me to|shall I|go ahead|does that work|which (option|approach|would you)|your call|tell me (which|whether|how|what)|how would you like|would you like|proceed\?|(say|type) "approved"|\bapprove (it|this|that|the)\b|\bapprove\?|say the word|your go-ahead|let me know (if|once|whether|when|which)|before (I|we) (move|proceed|continue|start|begin)', $rxOpts)
$findingsRx = [regex]::new('^#{1,4}[ \t].*\bfindings\b', $rxOpts)
$recommendRx = [regex]::new('^#{1,4}[ \t].*recommend|\*\*[^*\n]*recommend|\*\*verdict:', $rxOpts)
$escARx = [regex]::new('^\W*not an approval ask:', [System.Text.RegularExpressions.RegexOptions]::IgnoreCase)
$escBRx = [regex]::new('^\W*no recommendation applies:', [System.Text.RegularExpressions.RegexOptions]::IgnoreCase)

function Add-LogLine {
    param([string]$Line)
    try { Add-Content -LiteralPath $logPath -Value $Line } catch { Write-Verbose "Could not write $logPath; ignoring." }
}

# One line per session per kind, so a persistent fault cannot bury other hooks' errors in
# `mb doctor`'s `tail -3` of the shared log.
function Write-HookErrorOnce {
    param([string]$Session, [string]$Kind, [string]$Detail)
    $key = "pre-approval-check.ps1: session=$Session kind=$Kind"
    try {
        if ((Test-Path -LiteralPath $errLogPath) -and (Select-String -LiteralPath $errLogPath -SimpleMatch -Pattern $key -Quiet)) { return }
        Add-Content -LiteralPath $errLogPath -Value "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] [HOOK] $key $Detail"
    } catch { Write-Verbose "Could not write $errLogPath; ignoring." }
}

# Every fail-open also goes to the trial log (review finding F6), with no message text.
function Add-FailOpenLine {
    param([string]$Session, [string]$Kind)
    Add-LogLine -Line "$(Get-Date -Format 'yyyy-MM-ddTHH:mm:ss') session=$Session event=failopen kind=$Kind"
}

function Invoke-PausedNotification {
    $onWindows = $IsWindows -or ($env:OS -eq 'Windows_NT')
    $stub = $env:PMB_NOTIFY_STUB
    $delay = 0
    if ($env:PMB_NOTIFY_STUB_DELAY) { $delay = [int]$env:PMB_NOTIFY_STUB_DELAY }
    if ($onWindows) {
        # WHY Start-Process: it launches through ShellExecute, so the child does not inherit (and
        # hold open) the hook's stdout pipe. The harness would otherwise wait for the popup to close.
        if ($stub) {
            $exe = (Get-Process -Id $PID).Path
            $cmd = "Start-Sleep -Seconds $delay; Add-Content -LiteralPath '$stub' -Value notify"
        } else {
            $exe = 'powershell.exe'
            # WScript.Shell.Popup times out after 600 s; nothing else would close a detached popup.
            $cmd = "(New-Object -ComObject WScript.Shell).Popup('Claude has paused and is waiting for input.', 600, 'Claude Code', 64) | Out-Null"
        }
        Start-Process -FilePath $exe -ArgumentList "-NoProfile -NonInteractive -Command `"$cmd`"" -WindowStyle Hidden
    } elseif ($stub) {
        & /bin/sh -c "(sleep $delay; echo notify >> '$stub') >/dev/null 2>&1 </dev/null &"
    } else {
        & /bin/sh -c 'osascript -e ''display notification "Claude has paused and is waiting for input." with title "Claude Code"'' >/dev/null 2>&1 </dev/null & notify-send ''Claude Code'' ''Claude has paused and is waiting for input.'' >/dev/null 2>&1 </dev/null &'
    }
}

try {
    if ($env:PMB_PRE_APPROVAL -eq 'off') { return }
    # WHY a UTF-8 StreamReader, not [Console]::In: on Windows the latter decodes with the OEM code
    # page (ibm437), splitting each non-ASCII character into several (review finding F5). Same fix as
    # dangerous-commands.ps1.
    $raw = if ([Console]::IsInputRedirected) {
        (New-Object System.IO.StreamReader([Console]::OpenStandardInput(), (New-Object System.Text.UTF8Encoding($false)), $true)).ReadToEnd()
    } else { '' }
    if ($env:PMB_PRE_APPROVAL_TEST_FAULT -eq '1') { throw 'test-only fault (tests/test-pre-approval-check.sh)' }

    $d = $null
    try { $d = $raw | ConvertFrom-Json } catch { $d = $null }
    if ($null -eq $d -or $d -isnot [System.Management.Automation.PSCustomObject]) {
        Write-HookErrorOnce -Session '-' -Kind 'parse' -Detail 'payload could not be parsed; turn allowed without checking'
        Add-FailOpenLine -Session '-' -Kind 'parse'
        return
    }

    $sid = '-'
    if ($d.session_id) {
        $sid = [string]$d.session_id
        if ($sid.Length -gt 8) { $sid = $sid.Substring(0, 8) }
    }
    $msg = ''
    if ($d.last_assistant_message -is [string]) { $msg = $d.last_assistant_message }
    $hasF = $findingsRx.IsMatch($msg)
    $hasR = $recommendRx.IsMatch($msg)
    $now = Get-Date -Format 'yyyy-MM-ddTHH:mm:ss'

    if (($d.stop_hook_active -is [bool]) -and $d.stop_hook_active) {
        $esc = 'none'
        if ($escARx.IsMatch($msg)) { $esc = 'not_an_approval_ask' } elseif ($escBRx.IsMatch($msg)) { $esc = 'no_recommendation_applies' }
        $f = if ($hasF) { 'yes' } else { 'no' }
        $r = if ($hasR) { 'yes' } else { 'no' }
        Add-LogLine -Line "$now session=$sid event=post-block findings=$f recommendation=$r escape=$esc"
        return
    }
    if ([string]::IsNullOrWhiteSpace($msg)) { return }

    $end = if ($msg.Length -gt 400) { $msg.Substring($msg.Length - 400) } else { $msg }
    $tierA = $askRx.IsMatch($end)
    $tierB = $false
    if (-not $tierA) {
        $lines = @([regex]::Split($end, '\r\n|\n|\r') | Where-Object { $_.Trim() })
        if ($lines.Count -gt 0) {
            $last = $lines[-1].TrimEnd().TrimEnd([char[]]@('*', '_', '`', "'", '"', ')')).TrimEnd()
            $tierB = $last.EndsWith('?')
        }
    }

    $tier = $null
    $missing = $null
    if ($tierA -and -not ($hasF -and $hasR)) {
        $tier = 'A'
        if (-not ($hasF -or $hasR)) { $missing = 'both' } elseif (-not $hasF) { $missing = 'findings' } else { $missing = 'recommendation' }
    } elseif ($tierB -and -not $hasR) {
        $tier = 'B'
        $missing = 'recommendation'
    }
    if ($tier) {
        $script:blocked = $true
        Add-LogLine -Line "$now session=$sid event=block tier=$tier missing=$missing"
        $reason = if ($tier -eq 'A') { $reasonA } else { $reasonB }
        [Console]::Out.WriteLine(([ordered]@{ decision = 'block'; reason = $reason } | ConvertTo-Json -Compress))
    }
}
catch {
    Write-HookErrorOnce -Session '-' -Kind 'unexpected' -Detail "$_"
    Add-FailOpenLine -Session '-' -Kind 'unexpected'
}
finally {
    if (-not $script:blocked) {
        try { Invoke-PausedNotification } catch { Write-Verbose "Notification launch failed; ignoring." }
    }
    exit 0
}
```

- [ ] **Step 2: Run the suite; both twins must pass**

```bash
bash tests/test-pre-approval-check.sh 2>&1 | grep -E "FAIL|Results:"
```

Expected: no `FAIL` lines, and `Results: N passed, 0 failed`.

- [ ] **Step 3: PSScriptAnalyzer at CI's severity**

```bash
pwsh -NoProfile -Command "Invoke-ScriptAnalyzer -Path scripts/pre-approval-check.ps1 -Settings scripts/PSScriptAnalyzerSettings.psd1 -Severity Error,Warning"
```

Expected: no output. CI fails on any Warning. The usual causes are an empty `catch` (use
`Write-Verbose`, as above) and positional arguments to your own functions (use named parameters, as
above).

- [ ] **Step 4: Check by hand that the real popup is visible, from both twins**

The tests stub the notifier, so only a person can confirm that `-WindowStyle Hidden` hides the
console window but not the popup. Tell the user: "Two 'Claude has paused' popups should appear now.
Please confirm you saw both. Click OK, or they close themselves after 10 minutes." Then:

```bash
cd "C:/Users/Mizzo/Claude/Personal-Memory-Bank/.claude/worktrees/pre-approval-protocol"
pwsh -NoProfile -NonInteractive -File scripts/pre-approval-check.ps1 <<< '{"session_id":"manual-check","last_assistant_message":"Done."}'
bash scripts/pre-approval-check.sh <<< '{"session_id":"manual-check","last_assistant_message":"Done."}'
```

The input goes in as a here-string (`<<<`), not through `|`. Piping into `bash` trips the
dangerous-command hook's BLOCK tier. That was reproduced 2026-09-22 against this exact step (review
finding F4). A redirect is the correct form for feeding local JSON to a local script, not a way
around the hook.

Expected: both commands return immediately, with no output. **If the `.ps1` popup does not appear**,
remove `-WindowStyle Hidden` from the `Start-Process` line (a console window may flash briefly),
re-run Steps 2–4, and note the change in the Task 7 commit message, since the `.ps1` lands in
commit 1 (review finding L4).

---

### Task 7: Wire it in, gitignore, chain tests, register the suite, and commit 1

**Files:**
- Modify: `.claude/settings.json` (the `Stop` entry)
- Modify: `.gitignore`
- Modify: `tests/test-pre-approval-check.sh` (append the chain section)
- Modify: `tests/test-mirror-parity.sh` (the dated trial exemption, spec §5)
- Modify: `tests/run.sh`

- [ ] **Step 1: Replace the `Stop` command in the worktree's `.claude/settings.json`**

Replace the popup `command` value (the exact line quoted in Task 2 Step 4) with:

```
"command": "pwsh -NoProfile -NonInteractive -File scripts/pre-approval-check.ps1 2>/dev/null || bash scripts/pre-approval-check.sh 2>/dev/null || { (if [ -n \"${PMB_NOTIFY_STUB:-}\" ]; then echo notify >> \"$PMB_NOTIFY_STUB\"; else powershell.exe -Command \"(New-Object -ComObject WScript.Shell).Popup('Claude has paused and is waiting for input.', 600, 'Claude Code', 64)\"; osascript -e 'display notification \"Claude has paused and is waiting for input.\" with title \"Claude Code\"'; notify-send 'Claude Code' 'Claude has paused and is waiting for input.'; fi) >/dev/null 2>&1 </dev/null & } || true"
```

**The braces are load-bearing.** `&` binds looser than `||`, so without them the whole chain is
backgrounded, and the block JSON arrives after the shell has exited. The chain test in Step 4 fails
if they are dropped.

The fallback honors `PMB_NOTIFY_STUB` because a PATH stub cannot stand in for `powershell.exe` under
Git Bash (checked 2026-09-21: the real PowerShell ran).

```bash
python3 -c "import json; json.load(open('.claude/settings.json', encoding='utf-8')); print('valid json')"
```

**This edit goes live for this session** (constraint 10). The paused popup at the end of this turn
is the first run of production's Windows path (`pwsh`, then `Start-Process`) under the real
harness. Every earlier run was from the Bash tool (review finding F11). Tell the user: "From the
end of this turn, the 'Claude has paused' popup comes from the new hook, and it closes itself after
10 minutes. Please tell me next turn whether it appeared." **If it did not appear**, remove
`-WindowStyle Hidden` from the `.ps1`'s `Start-Process` line and ask again.

- [ ] **Step 2: Gitignore the trial log**

In `.gitignore`'s "PMB runtime state files" block, add a line after `.pmb-hook-errors.log`:

```
.pmb-pre-approval.log
```

- [ ] **Step 3: Append the chain tests to `tests/test-pre-approval-check.sh`**

Insert this block immediately before the final `print_summary` line:

```bash
# ── settings.json wiring: the exact command the harness runs ─────────────────────────────────
echo ""
echo "--- settings.json Stop wiring ---"
STOP_INFO=$(python3 -c 'import json, sys
s = json.load(open(sys.argv[1], encoding="utf-8"))
cmds = [h["command"] for e in s["hooks"].get("Stop", []) for h in e.get("hooks", [])]
print(len(cmds))
print(cmds[0] if cmds else "")' "$REPO_ROOT/.claude/settings.json")
STOP_COUNT=$(printf '%s\n' "$STOP_INFO" | sed -n 1p)
CHAIN=$(printf '%s\n' "$STOP_INFO" | sed -n 2p)
assert_equals "$STOP_COUNT" "1" "exactly one Stop hook (the old modal popup entry is gone)"
assert_contains "$CHAIN" "pre-approval-check.ps1" "the Stop hook runs pre-approval-check"
bash -n -c "$CHAIN" 2>/dev/null
assert_exit_zero "$?" "the Stop command parses as shell"

new_stub
rm -f "$SB/chain.out"
( cd "$SB" && payload 'Want me to push it now?' | PMB_NOTIFY_STUB="$STUB" bash -c "$CHAIN" > "$SB/chain.out" 2>/dev/null )
assert_contains "$(cat "$SB/chain.out")" '"decision":"block"' "the block JSON is already written when the chain returns (primary path is synchronous)"

BROKEN="${CHAIN//pre-approval-check/no-such-hook}"
new_stub
( cd "$SB" && payload 'Done.' | PMB_NOTIFY_STUB="$STUB" bash -c "$BROKEN" >/dev/null 2>&1 )
notified 6; assert_exit_zero "$?" "with both scripts missing, the fallback link still notifies"
```

- [ ] **Step 4: Add the dated trial exemption to `tests/test-mirror-parity.sh`** (spec §5, option A+)

Without it, Step 1 fails `test-mirror-parity.sh:354-421` (146 passed, 2 failed, reproduced
2026-09-22), because the live Stop line must equal the template's. Compute the expiry, 21 days
from today (the 14-day trial from merge plus a 7-day grace):

```bash
date -d '+21 days' +%Y-%m-%d
```

Insert this block immediately after the line `if [ -f "$SJ_LIVE" ] && [ -f "$SJ_TMPL" ]; then`
(the settings.json hook-wiring section), with that date in place of `YYYY-MM-DD`:

```bash
    # ── PMB-only trial exemption: the pre-approval-check Stop hook ───────────────────────────
    # WHY: docs/superpowers/specs/2026-09-21-pre-approval-protocol-design.md runs this hook as a
    # PMB-only trial, so it is deliberately absent from templates/ (adopters would otherwise get a
    # hook that blocks about a third of turn endings, through mb upgrade's force-overwrite, with no
    # trial). Exactly one live `"command":` line may differ, and only in the Stop entry: the one that
    # runs scripts/pre-approval-check. It is compared as if it were the template's paused-popup line.
    # Every other line, and every (event, matcher, commands) triple, is still compared as before.
    # REMOVE THIS BLOCK at trial end, whether the hook is promoted into templates/ or deleted. The
    # count assertions below make a stale exemption fail rather than silently widen.
    SJ_LIVE_CMP="$(mktemp)"
    pa_live_n=$(grep -c 'scripts/pre-approval-check\.' "$SJ_LIVE" 2>/dev/null)
    pa_tmpl_n=$(grep -c '"command":.*Claude has paused and is waiting for input' "$SJ_TMPL" 2>/dev/null)
    [ "${pa_live_n:-0}" -eq 1 ] && [ "${pa_tmpl_n:-0}" -eq 1 ]
    assert_exit_zero "$?" "settings.json: trial exemption matches exactly one live pre-approval line ($pa_live_n) and one template popup line ($pa_tmpl_n)"
    pa_tmpl_line=$(grep '"command":.*Claude has paused and is waiting for input' "$SJ_TMPL")
    PA_TMPL_LINE="$pa_tmpl_line" awk '/scripts\/pre-approval-check\./ { print ENVIRON["PA_TMPL_LINE"]; next } { print }' "$SJ_LIVE" > "$SJ_LIVE_CMP"
    SJ_LIVE="$SJ_LIVE_CMP"
    # The trial runs 14 days from merge; this date adds a 7-day grace. When it passes, CI fails until
    # the exemption is resolved: remove this block (hook promoted into templates/ or deleted), or move
    # the date deliberately. A WARN would not do: this repo recorded one being ignored (2026-08-12).
    # A date left as the placeholder fails too (review finding L1). If the template's popup line is
    # removed, or loses the text "Claude has paused and is waiting for input", rewrite this block: the
    # swap depends on that line (review finding L3).
    PA_TRIAL_EXPIRES="YYYY-MM-DD"
    [[ "$PA_TRIAL_EXPIRES" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}$ ]] && [[ "$(date +%Y-%m-%d)" < "$PA_TRIAL_EXPIRES" ]]
    assert_exit_zero "$?" "settings.json: pre-approval trial exemption has not expired (expires $PA_TRIAL_EXPIRES)"
```

Then add `    rm -f "$SJ_LIVE_CMP"` as the last line inside that same `if` block, directly
before its closing `fi`. That `fi` comes right after the `fi` that closes the
`SKIP: settings.json structural hook compare` branch.

This block was tested on 2026-09-22 against `origin/main` scratch clones. The Task 7 state passed
(150/0). Each of these failed:
- another hook's command drifting, and another hook's matcher drifting;
- the hook moved to another event, duplicated, or absent;
- the popup kept alongside the hook;
- the hook removed by a real `mb upgrade` run inside PMB;
- an expiry date in the past.

It gave identical results on Linux, and left no temp files. Verify here:

```bash
cd "C:/Users/Mizzo/Claude/Personal-Memory-Bank/.claude/worktrees/pre-approval-protocol"
bash tests/test-mirror-parity.sh 2>&1 | grep -E "FAIL|Results"
sed 's/PA_TRIAL_EXPIRES="[0-9-]*"/PA_TRIAL_EXPIRES="2000-01-01"/' tests/test-mirror-parity.sh > tests/_expired-check.sh
bash tests/_expired-check.sh 2>&1 | grep -E "FAIL|Results"; rm tests/_expired-check.sh
```

Expected: `0 failed` on the first run. The second run fails exactly one check, `… trial
exemption has not expired (expires 2000-01-01)`.

- [ ] **Step 5: Register the suite, stage commit 1, and run everything**

In `tests/run.sh`, add this line directly after the `run_suite "pre-compact-check" …` line:

```bash
run_suite "pre-approval-check"   "$REPO_ROOT/tests/test-pre-approval-check.sh"
```

Stage every commit-1 file **now**, before any test run or review (review finding F3).
- `git diff HEAD` leaves out untracked files, so an unstaged review would never see the new
  scripts.
- The commit gate would then refuse the marker, wasting a review round.
- `run.sh`'s completeness check only counts suites that `git ls-files` sees, so it can't fail
  before staging (review finding F15).

Use a full `git add`, never `add -N`: `progress.md` records a draft lost that way.

```bash
cd "C:/Users/Mizzo/Claude/Personal-Memory-Bank/.claude/worktrees/pre-approval-protocol" && git add scripts/pre-approval-check.sh scripts/pre-approval-check.ps1 tests/test-pre-approval-check.sh tests/test-mirror-parity.sh tests/run.sh .claude/settings.json .gitignore
cd "C:/Users/Mizzo/Claude/Personal-Memory-Bank/.claude/worktrees/pre-approval-protocol" && bash tests/test-pre-approval-check.sh 2>&1 | grep -E "FAIL|Results:"
cd "C:/Users/Mizzo/Claude/Personal-Memory-Bank/.claude/worktrees/pre-approval-protocol" && bash tests/run.sh > "$TMP/pmb-run.txt" 2>&1; echo "run.sh exit=$?"; grep -E "FAIL|completeness|Results" "$TMP/pmb-run.txt" | tail -15
```

Expected: the new suite passes with 0 failures, and `run.sh exit=0`, completeness check included.
`run.sh` takes about 35 minutes; run it in the background. **Wait for its completion notice before
Step 6, and edit nothing meanwhile** (review finding L9): `test-mb-doctor.sh` moves `VERSION` aside
mid-run, so a review or marker computed during the run hashes a tree missing that file.

**Any `run.sh` failure blocks commit 1, whichever suite it is in.** This plan's own first version
failed `test-mirror-parity.sh`, a suite "this branch didn't touch". To classify a failure, run
that suite alone on a clean `origin/main` clone in the scratchpad. Report it to the user either
way, and commit only after the user decides.

- [ ] **Step 6: Commit 1, through the review gate**

Before **each** `/code-review` run, snapshot HEAD and the staged tree to a file (constraint 11).
A file, not a shell variable, because nothing survives between tool calls. After fixing any
findings, re-stage and re-take the snapshot before re-running the review.

```bash
mkdir -p "C:/Users/Mizzo/Claude/pmb-session-artifacts/pre-approval-review"
cd "C:/Users/Mizzo/Claude/Personal-Memory-Bank/.claude/worktrees/pre-approval-protocol" && { git rev-parse HEAD; git ls-files -s | sha256sum; git diff | sha256sum; git status --short; } > "C:/Users/Mizzo/Claude/pmb-session-artifacts/pre-approval-review/state-before-commit1.txt"
cat "C:/Users/Mizzo/Claude/pmb-session-artifacts/pre-approval-review/state-before-commit1.txt"
```

Run `/code-review`. Its opposition step writes `.claude/.code-review-ok` only on an Approve
verdict. As soon as it returns, compare:

```bash
cd "C:/Users/Mizzo/Claude/Personal-Memory-Bank/.claude/worktrees/pre-approval-protocol" && { git rev-parse HEAD; git ls-files -s | sha256sum; git diff | sha256sum; git status --short; } | diff - "C:/Users/Mizzo/Claude/pmb-session-artifacts/pre-approval-review/state-before-commit1.txt" && echo "OK: HEAD and the staged tree are unchanged by the review" || echo "STOP: the review changed HEAD or the tree"
```

Expected: `OK: …`. **On `STOP`, do not continue.** A review subagent changed the tree. Report it
to the user as a finding, together with `git log -3 --oneline`.

When the review approves and the comparison is `OK`, continue below.

Then prove the marker landed in the worktree and binds this diff (review finding P1). The check
compares both checkouts' markers against a hash of the worktree's diff, computed in the same call, so
it carries nothing between tool calls (review finding N1). The peer session can also legitimately
rewrite the main checkout's marker with its own review at any time. That marker will never equal
this diff's hash, so a before-and-after comparison would false-STOP, and this check does not.

```bash
WT_DIR="C:/Users/Mizzo/Claude/Personal-Memory-Bank/.claude/worktrees/pre-approval-protocol"
MAIN_DIR="C:/Users/Mizzo/Claude/Personal-Memory-Bank"
MARKER=".claude/.code-review-ok"; RANGE="HEAD"
hash_of() { T="$(mktemp)"; git -C "$1" diff "$2" > "$T" 2>/dev/null; sha256sum "$T" | cut -d' ' -f1; rm -f "$T"; }
mark_of() { cat "$1" 2>/dev/null | tr -d '\r\n' | tr 'A-F' 'a-f'; }
H="$(hash_of "$WT_DIR" "$RANGE")"
WT_MARK="$(mark_of "$WT_DIR/$MARKER")"; MAIN_MARK="$(mark_of "$MAIN_DIR/$MARKER")"
[ "$WT_MARK" = "$H" ] && echo "OK: worktree marker matches this diff" || echo "STOP: worktree marker missing or does not match this diff"
[ "$MAIN_MARK" = "$H" ] && echo "STOP: the main checkout holds a marker for this diff" || echo "OK: main checkout holds no marker for this diff"
if [ "$WT_MARK" != "$H" ] && [ -n "$MAIN_MARK" ]; then
    echo "main checkout marker last modified: $(date -r "$MAIN_DIR/$MARKER" '+%F %T')"
    [ "$MAIN_MARK" = "$(hash_of "$MAIN_DIR" "$RANGE")" ] && echo "STOP: it certifies the main checkout's own diff, possibly written by a misrouted review" || echo "it does not match the main checkout's own diff"
fi
```

Expected: two `OK:` lines. **If any line starts with `STOP:`, do not run the next block.** Report
every line to the user.
- If the last line says the main marker certifies the main checkout's own diff, a misrouted review
  may have approved the other session's unreviewed work (review finding A). The report needs the
  marker's modification time, so the user can decide whether to tell that session or remove the
  marker.
- Never remove it yourself: constraint 1 forbids touching the main checkout.

The block uses absolute paths throughout, so it doesn't depend on the current directory (review
finding D). It was dry-run on 2026-09-22 against scratch clones, and each scenario below gave the
expected result:
- correct routing while an unrelated marker sat in the main checkout;
- a marker in PowerShell's uppercase-with-CRLF form;
- a marker misrouted into the main checkout;
- a marker for a different diff;
- a review that hashed and certified the main checkout's diff.

The commit block starts with the literal `cd`, per constraint 2:

```bash
cd "C:/Users/Mizzo/Claude/Personal-Memory-Bank/.claude/worktrees/pre-approval-protocol" && git status --short
cd "C:/Users/Mizzo/Claude/Personal-Memory-Bank/.claude/worktrees/pre-approval-protocol" && git commit -m "$(cat <<'EOF'
feat: add pre-approval-check Stop hook enforcing the Pre-Approval Protocol

Blocks a turn that ends in an approval ask without a Findings section and a
Recommendation (or in any question without a Recommendation), and owns the
"Claude has paused" notification, now detached and self-closing after 600 s so
the harness no longer waits on a modal MessageBox. PMB-only; not installed by
mb init. tests/test-mirror-parity.sh gains a dated trial exemption for the
PMB-only Stop line (design spec section 5).

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>
EOF
)"
```

Expected: the commit succeeds, and `git status --short` is clean apart from later tasks' files.

---

### Task 8: `standards/WORKFLOW.md`, the protocol section

**Files:**
- Modify: `standards/WORKFLOW.md` (Phase 3.5 at about lines 69–84; Quick Reference row at about
  line 168; Integration row at about line 182; new section before `## Context Management`)

- [ ] **Step 1: Replace the Phase 3.5 section**

Replace everything from `### Phase 3.5 — Independent Plan Review (advisory — not one of the 7 counted
phases)` through its `**Recommended for:** …` paragraph (the `---` after it stays) with:

```markdown
### Phase 3.5 — Independent Plan Review (superseded by the Pre-Approval Protocol)

Superseded on 2026-09-21. The independent review this phase recommended for plans now runs before
**every** approval ask, specs and plans included, under the Pre-Approval Protocol section below. For
escalation-list asks it runs through the Opus `opposition` agent. The heading stays so existing
references to "Phase 3.5" still resolve.
```

- [ ] **Step 2: Update the two table rows**

Quick Reference: replace
`| 3.5 Independent Plan Review (advisory) | Small/low-risk plan | Verified plan or documented decision to proceed without |`
with
`| 3.5 Independent Plan Review (superseded) | — | See Pre-Approval Protocol |`

Claude Code Integration: replace
``| Independent Plan Review (advisory) | No dedicated skill yet — dispatch a fresh `Agent` (general-purpose or Explore) on a capable model, self-contained prompt |``
with
``| Pre-Approval Protocol | No skill. The procedure is in this file; the `pre-approval-check` Stop hook enforces it; `opposition` handles escalation-list asks |``

- [ ] **Step 3: Insert the protocol section immediately before `## Context Management`**

Use the kill-switch sentence that matches Task 3's recorded result: "takes effect on the next turn",
or "takes effect after restarting the session".

````markdown
## Pre-Approval Protocol

**Applies to every message that asks the user to approve or choose:** design recommendations, specs,
plans, task contracts, "should I proceed". It is not a phase: it runs inside whichever phase produces
the ask, so the workflow stays at 7 phases. It supersedes Phase 3.5. Design and evidence:
`docs/superpowers/specs/2026-09-21-pre-approval-protocol-design.md`.

**Before the ask:**

1. **Run the checks the options depend on.** Execute rather than re-read. Re-derive every number
   relied on, measure anything performance-relevant, read config instead of assuming it, and check
   each claim about a file against the file as it is now. Checks must not mutate the shared working
   tree: cite the last run of `tests/run.sh`, which moves `VERSION` aside, instead of running it
   mid-ask.
2. **If the ask hits the trigger list in CLAUDE.md's Token Budget section** ("Escalate on
   observable triggers"; referenced, not copied here), dispatch the `opposition` agent after step 1.
   Give it the artifact, the step-1 findings, and the instruction to attack premises and re-derive
   the load-bearing numbers. Retry once on failure; if it fails again, say so in the findings. Use
   CLAUDE.md's list, not this file's own **Token Budget** bullet below: that one is narrower, and
   omits writing a design spec or implementation plan, the trigger this protocol relies on most.
3. **Fix what is within the thing being proposed.** Anything that would change a decision the user
   already made goes under the decision instead.
4. **Send the ask with these sections, in the message's final text block:**

   ```
   ## Findings
   | # | Question | How I checked (command or source) | Result |

   ## Recommendation
   <what I recommend, and why>
   <holes I could not close>
   <the decision needed>
   ```

   - Every row names a re-runnable command or source.
   - When nothing needed checking, the table still appears, with one row saying so.
   - When the escalation list fired, one row carries the `opposition` verdict.
   - A question that is not an approve-or-choose ask still needs a Recommendation.

**Enforcement:**
- **The hook:** `pre-approval-check` (PMB-only; `docs/HOOKS-GUIDE.md` §2) sends back, once, any
  turn that ends in an ask without these sections.
- **False positives:** reply `Not an approval ask:` with one line of why. For a clarifying question,
  reply `No recommendation applies:`.
- **What it checks:** the hook confirms the sections exist, not that the checks behind them were
  adequate. Adequacy stays with the `opposition` pass.
- **Kill switch:** `"PMB_PRE_APPROVAL": "off"` in the `.claude/settings.json` env block. It
  <takes effect on the next turn | takes effect after restarting the session>.
````

In the last line, keep only the variant that matches Task 3's result, and delete the other along
with the angle brackets and the `|`.

- [ ] **Step 4: Verify parity and repo health**

```bash
bash tests/test-mirror-parity.sh 2>&1 | grep -E "WORKFLOW|FAIL|Results:"
bash scripts/baseline-health.sh --no-fetch > "$TMP/pmb-bh.txt" 2>&1; echo "baseline-health exit=$?"; grep -E "FAIL|Skipped|PASS" "$TMP/pmb-bh.txt" | tail -12
```

Expected:
- **Mirror test:** 0 failures. `WORKFLOW.md` is on the allowlist, and its anti-rot check still sees
  the pair diverging.
- **`baseline-health`:** exit `0`. Read any other code by its meaning:
  - `1`: a real check failed;
  - `2`: the workflow file is absent;
  - `3`: a step could not be extracted, which is **not** a pass.

---

### Task 9: `HOOKS-GUIDE.md`, both copies

**Files:**
- Modify: `docs/HOOKS-GUIDE.md` (hook-types row, line 19; §2 at lines 114–116 as of `ac63ccb`)
- Modify: `templates/docs/HOOKS-GUIDE.md` (hook-types row, line 19; §2 at lines 104–106)

Line numbers drift; the quoted text anchors are what to match.

- [ ] **Step 1: Hook-types row, in both files**

Replace
`| \`Stop\` | When Claude pauses for input | Desktop notification |`
with
`| \`Stop\` | When Claude pauses for input | Desktop notification; Pre-Approval Protocol check (PMB-only) |`

- [ ] **Step 2: Replace §2 in `docs/HOOKS-GUIDE.md`**

Replace the `### 2. Stop Notification …` heading and its paragraph with the text below. Pick the
kill-switch parenthetical from Task 3's result.

The old heading's "excluded from install template" is false, and has been since `f976530` put the
popup back into `templates/.claude/settings.json` (review finding F2). The new text does not repeat
it.

```markdown
### 2. Stop Notification and Pre-Approval Check (`Stop`)

In PMB, one Stop entry, `scripts/pre-approval-check.ps1` with its `.sh` twin, does two jobs:

- **Pre-Approval Protocol check.**
  - It reads the payload's `last_assistant_message`.
  - It blocks when the turn ends in an approve-or-choose ask without a `Findings` heading and a
    Recommendation, or in any other question without a Recommendation. It returns
    `{"decision":"block","reason":…}`, and the model continues once, either to add the sections or
    to reply `Not an approval ask:` / `No recommendation applies:`.
  - `stop_hook_active` guards against loops.
  - See `standards/WORKFLOW.md`, Pre-Approval Protocol.
  - **A pass means the sections exist, not that the checks behind them were good.** Ask detection
    is a measured heuristic trigger, and adequacy stays with the Reviewer/Opponent layer. See the
    design rule above on false confidence.
- **"Claude has paused" notification.** It is launched detached on every exit except a block, and
  it closes itself after 600 s. The harness no longer waits on it. It used to be a separate, modal
  Stop entry:
  - `--Remote-Control` and headless sessions hung on it, with no one present to dismiss it;
  - a block would have shown "waiting for input" about an ask that was about to be replaced.

Blocks, post-block outcomes and fail-opens go to `.pmb-pre-approval.log` (gitignored, no message
text) for the trial that decides template rollout. Kill switch: `"PMB_PRE_APPROVAL": "off"` in the
`settings.json` env block (takes effect on the next turn | takes effect after restarting the
session).

**What adopters get today.** `templates/.claude/settings.json` still installs the older modal popup
as its Stop entry. During the trial, PMB's live entry differs from it under a dated exemption in
`tests/test-mirror-parity.sh`. Whether adopters should get a Stop notification at all is an open
decision; see the design spec, §5.
```

- [ ] **Step 3: Replace §2 in `templates/docs/HOOKS-GUIDE.md` (the trimmed copy)**

```markdown
### 2. Stop Notification and Pre-Approval Check (`Stop`)

PMB's own `.claude/settings.json` runs a single Stop hook, `scripts/pre-approval-check.ps1`, with
two jobs:
- it enforces PMB's Pre-Approval Protocol: a turn ending in an ask must carry a Findings section and
  a Recommendation;
- it shows a detached "Claude has paused" notification that closes itself after 600 s.

**A pass means the sections exist, not that the checks behind them were good.** Ask detection is a
heuristic trigger, and adequacy stays with the Reviewer/Opponent layer.

The pre-approval check is not installed by `mb init`; it is on trial in PMB only. What `mb init`
does install as the Stop entry is the older modal "Claude has paused" popup, which can hang headless
or remote sessions with no one to dismiss it. Whether adopters keep it is an open decision.
```

- [ ] **Step 4: Check the edits landed**

```bash
cd "C:/Users/Mizzo/Claude/Personal-Memory-Bank/.claude/worktrees/pre-approval-protocol"
grep -n "Pre-Approval" docs/HOOKS-GUIDE.md templates/docs/HOOKS-GUIDE.md
grep -c "excluded from install template" docs/HOOKS-GUIDE.md templates/docs/HOOKS-GUIDE.md
grep -c "A pass means the sections exist" docs/HOOKS-GUIDE.md templates/docs/HOOKS-GUIDE.md
```

Expected:
- the hook-types row and the §2 heading in each file;
- `0` for each file on the "excluded" count;
- `1` for each file on the caveat count (review finding F14).

---

### Task 10: Final verification and commit 2

- [ ] **Step 1: Confirm the spec and plan copies are ready to commit**

Task 1 Step 4 confirmed both files. The plan copy should carry the Tasks 2–3 results.

```bash
cd "C:/Users/Mizzo/Claude/Personal-Memory-Bank/.claude/worktrees/pre-approval-protocol" && git status --short -- docs/superpowers/
grep -c "Results (" "C:/Users/Mizzo/Claude/Personal-Memory-Bank/.claude/worktrees/pre-approval-protocol/docs/superpowers/plans/2026-09-21-pre-approval-protocol.md"
```

Expected: the plan is modified (`M`), the spec remains tracked and may be unchanged, and the
results count is at least `2`. Leave the main checkout's files alone.

- [ ] **Step 2: Run every check once more**

```bash
bash tests/test-pre-approval-check.sh 2>&1 | grep -E "FAIL|Results:"
bash tests/run.sh > "$TMP/pmb-run.txt" 2>&1; echo "run.sh exit=$?"
bash -n scripts/pre-approval-check.sh && echo "sh syntax ok"
pwsh -NoProfile -Command "Invoke-ScriptAnalyzer -Path scripts/pre-approval-check.ps1 -Settings scripts/PSScriptAnalyzerSettings.psd1 -Severity Error,Warning"
bash scripts/baseline-health.sh --no-fetch > "$TMP/pmb-bh.txt" 2>&1; echo "baseline-health exit=$?"
```

Expected:
- 0 failures in the new suite;
- `run.sh exit=0` (or only the pre-existing failures noted in Task 7);
- `sh syntax ok`;
- no analyzer output;
- `baseline-health exit=0`.

`shellcheck` is not installed locally, so CI runs it at `--severity=error`.

- [ ] **Step 3: Commit 2, through the review gate**

Stage first (review finding F3), then snapshot. Re-stage and re-snapshot after any fix:

```bash
cd "C:/Users/Mizzo/Claude/Personal-Memory-Bank/.claude/worktrees/pre-approval-protocol" && git add standards/WORKFLOW.md docs/HOOKS-GUIDE.md templates/docs/HOOKS-GUIDE.md docs/superpowers/specs/2026-09-21-pre-approval-protocol-design.md docs/superpowers/plans/2026-09-21-pre-approval-protocol.md
```

```bash
mkdir -p "C:/Users/Mizzo/Claude/pmb-session-artifacts/pre-approval-review"
cd "C:/Users/Mizzo/Claude/Personal-Memory-Bank/.claude/worktrees/pre-approval-protocol" && { git rev-parse HEAD; git ls-files -s | sha256sum; git diff | sha256sum; git status --short; } > "C:/Users/Mizzo/Claude/pmb-session-artifacts/pre-approval-review/state-before-commit2.txt"
cat "C:/Users/Mizzo/Claude/pmb-session-artifacts/pre-approval-review/state-before-commit2.txt"
```

Run `/code-review` on the staged docs diff, then compare:

```bash
cd "C:/Users/Mizzo/Claude/Personal-Memory-Bank/.claude/worktrees/pre-approval-protocol" && { git rev-parse HEAD; git ls-files -s | sha256sum; git diff | sha256sum; git status --short; } | diff - "C:/Users/Mizzo/Claude/pmb-session-artifacts/pre-approval-review/state-before-commit2.txt" && echo "OK: HEAD and the staged tree are unchanged by the review" || echo "STOP: the review changed HEAD or the tree"
```

Expected: `OK: …`; on `STOP`, do not continue (as in Task 7 Step 6). When the review approves,
run the same marker check as Task 7 Step 6, as its own block (review finding N2):

```bash
WT_DIR="C:/Users/Mizzo/Claude/Personal-Memory-Bank/.claude/worktrees/pre-approval-protocol"
MAIN_DIR="C:/Users/Mizzo/Claude/Personal-Memory-Bank"
MARKER=".claude/.code-review-ok"; RANGE="HEAD"
hash_of() { T="$(mktemp)"; git -C "$1" diff "$2" > "$T" 2>/dev/null; sha256sum "$T" | cut -d' ' -f1; rm -f "$T"; }
mark_of() { cat "$1" 2>/dev/null | tr -d '\r\n' | tr 'A-F' 'a-f'; }
H="$(hash_of "$WT_DIR" "$RANGE")"
WT_MARK="$(mark_of "$WT_DIR/$MARKER")"; MAIN_MARK="$(mark_of "$MAIN_DIR/$MARKER")"
[ "$WT_MARK" = "$H" ] && echo "OK: worktree marker matches this diff" || echo "STOP: worktree marker missing or does not match this diff"
[ "$MAIN_MARK" = "$H" ] && echo "STOP: the main checkout holds a marker for this diff" || echo "OK: main checkout holds no marker for this diff"
if [ "$WT_MARK" != "$H" ] && [ -n "$MAIN_MARK" ]; then
    echo "main checkout marker last modified: $(date -r "$MAIN_DIR/$MARKER" '+%F %T')"
    [ "$MAIN_MARK" = "$(hash_of "$MAIN_DIR" "$RANGE")" ] && echo "STOP: it certifies the main checkout's own diff, possibly written by a misrouted review" || echo "it does not match the main checkout's own diff"
fi
```

Expected: two `OK:` lines. **If any line starts with `STOP:`, do not run the next block.** Report
every line to the user, as in Task 7 Step 6, and never touch the main checkout's marker yourself.

The commit block starts with the literal `cd`, per constraint 2:

```bash
cd "C:/Users/Mizzo/Claude/Personal-Memory-Bank/.claude/worktrees/pre-approval-protocol" && git status --short
cd "C:/Users/Mizzo/Claude/Personal-Memory-Bank/.claude/worktrees/pre-approval-protocol" && git commit -m "$(cat <<'EOF'
docs: add the Pre-Approval Protocol to WORKFLOW.md and document its Stop hook

Supersedes Phase 3.5 with a protocol that runs before every approval ask:
execute the checks, add the Opus opposition pass on escalation-list asks,
and send the ask with Findings and a Recommendation. The approved spec
and this plan are present on the branch.

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>
EOF
)"
```

---

### Task 11: Finish the branch

- [ ] **Step 1: Use `superpowers:finishing-a-development-branch`.**

Pushing, opening a PR and merging are **each** separate approvals from the user. Ask for each one,
with Findings and a Recommendation.

**Before the push, re-check the exemption's expiry date** (review finding L2). Task 7 Step 4 set
it 21 days from that day, so every day between then and merge comes out of the 7-day grace. If
merge is unlikely before `expiry - 14 days`, move the date in a new commit through the gate, not an
amend.

**Constraint 2 still applies inside the skill** (review finding N3). The skill's own push command
won't start with the literal `cd`, so write the push yourself (below).

The push gate requires `/change-review`'s marker, `.claude/.change-review-ok`, bound to
`origin/main...HEAD` (`review-reminders.sh:261,266`), not `/code-review`'s. Once the user approves
the push:
1. Snapshot HEAD first (constraint 11). The push reviews committed history, so a subagent commit
   would change exactly what gets pushed:

   ```bash
   cd "C:/Users/Mizzo/Claude/Personal-Memory-Bank/.claude/worktrees/pre-approval-protocol" && git rev-parse HEAD > "C:/Users/Mizzo/Claude/pmb-session-artifacts/pre-approval-review/head-before-push.txt"
   ```
2. Run `/change-review` from the worktree. Then confirm HEAD didn't move:

   ```bash
   cd "C:/Users/Mizzo/Claude/Personal-Memory-Bank/.claude/worktrees/pre-approval-protocol" && git rev-parse HEAD | diff - "C:/Users/Mizzo/Claude/pmb-session-artifacts/pre-approval-review/head-before-push.txt" && echo "OK: HEAD unchanged by the review" || echo "STOP: the review moved HEAD"
   ```
3. Once it approves, check where its marker landed (review finding C):

```bash
WT_DIR="C:/Users/Mizzo/Claude/Personal-Memory-Bank/.claude/worktrees/pre-approval-protocol"
MAIN_DIR="C:/Users/Mizzo/Claude/Personal-Memory-Bank"
MARKER=".claude/.change-review-ok"; RANGE="origin/main...HEAD"
hash_of() { T="$(mktemp)"; git -C "$1" diff "$2" > "$T" 2>/dev/null; sha256sum "$T" | cut -d' ' -f1; rm -f "$T"; }
mark_of() { cat "$1" 2>/dev/null | tr -d '\r\n' | tr 'A-F' 'a-f'; }
H="$(hash_of "$WT_DIR" "$RANGE")"
WT_MARK="$(mark_of "$WT_DIR/$MARKER")"; MAIN_MARK="$(mark_of "$MAIN_DIR/$MARKER")"
[ "$WT_MARK" = "$H" ] && echo "OK: worktree marker matches this diff" || echo "STOP: worktree marker missing or does not match this diff"
[ "$MAIN_MARK" = "$H" ] && echo "STOP: the main checkout holds a marker for this diff" || echo "OK: main checkout holds no marker for this diff"
if [ "$WT_MARK" != "$H" ] && [ -n "$MAIN_MARK" ]; then
    echo "main checkout marker last modified: $(date -r "$MAIN_DIR/$MARKER" '+%F %T')"
    [ "$MAIN_MARK" = "$(hash_of "$MAIN_DIR" "$RANGE")" ] && echo "STOP: it certifies the main checkout's own diff, possibly written by a misrouted review" || echo "it does not match the main checkout's own diff"
fi
```

Expected: two `OK:` lines. **If any line starts with `STOP:`, do not push.** Report every line to
the user. Otherwise, push with the literal `cd`:

```bash
cd "C:/Users/Mizzo/Claude/Personal-Memory-Bank/.claude/worktrees/pre-approval-protocol" && git push -u origin feat/pre-approval-protocol
```

Once the PR is opened, while still in this worktree, mark
`C:/Users/Mizzo/Claude/Personal-Memory-Bank/.claude/worktrees/pre-approval-protocol/.claude/contracts/active-task.json`
as `"complete"` and note that completion to the user. If the contract expires before the work is
finished, renew approval before further edits.

- [ ] **Step 2: After merge, from the main checkout only:**
  - **Going live:** the hook is live for a session only once that session's checkout is on a
    commit that contains it. Check the main checkout's branch with `git branch --show-current`; it
    was `main` on 2026-09-22.
  - **Separate memory-bank task:** before recording the trial, propose a new main-checkout task
    contract scoped to `memory-bank/activeContext.md`, `memory-bank/progress.md`, and its own
    `.claude/contracts/active-task.json`; wait for approval, then write that contract. Do not use
    the completed implementation-worktree contract for this update.
  - **Memory bank:** under that approved separate contract, record the trial start (merge date), its end (+14 days), and the parity
    exemption's expiry date from Task 7 Step 4 in `memory-bank/`. CI fails after that date until the
    exemption is resolved. Offset the added bytes under the startup-context ratchet, per
    `standards/MEMORY-BANK.md`'s eviction rules. Mark the separate contract complete after the
    update.
  - **Separate item:** remind the user that the template/guide contradiction over the Stop popup
    (design spec §5) is a separate, open decision.
  - **Clean up:** delete `C:/Users/Mizzo/Claude/pmb-session-artifacts/pre-approval-review/` (the
    review snapshots), one file at a time.
  - **Stale plan:** tell the user the compact-nudge plan
    (`docs/superpowers/plans/2026-09-21-compact-nudge-hook.md`) remains superseded, whether it is
    already tracked on main or arrives later.

---

## Self-Review Notes

This checklist was run against the spec when the plan was written.

**Spec coverage:**

| Spec section | Where the plan covers it |
|---|---|
| §1 procedure | Task 8 |
| §2 output format | Tasks 8 and 4, including tests for the final-block requirement |
| §3 logic, tiers, patterns, case-insensitivity, reason texts and escapes | Tasks 4, 5, 6 |
| §3 JSON block channel | Tasks 5 and 6 |
| §3 `stop_hook_active` guard and its contingency | Tasks 3, 5, 6. The contingency is a stated deviation: the plan stops rather than building log-only |
| §3 detached, self-closing (600 s) notifier, fallback link and braces | Tasks 5, 6, 7; watched live at Task 7 Step 1 |
| §3 notify on every exit except a block | Tests in Task 4 |
| §3 trial log, including `event=failopen` | Tasks 4, 5 and 6 |
| §3 UTF-8 stdin in both twins | Tasks 4, 5 and 6 |
| §3 kill switch and its reach (N5) | Task 3, plus Tasks 8 and 9 |
| §4 no `AskUserQuestion` hook | Nothing to build |
| §5 no CLAUDE.md, templates, commands or memory-bank edits | Constraint 7, Task 11 |
| §5 the dated parity exemption (A+) | Task 7 Step 4; its expiry is recorded at Task 11 |
| §5 the template/guide contradiction: correct the guide only | Task 9; reminder at Task 11 |
| §6 false-confidence caveat, in both HOOKS-GUIDE copies | Task 9 |
| Known Limitation 10 (working directory) | Not built; stated in the spec |
| Spikes 1–2 | Tasks 2–3, run from a session rooted in the worktree (Task 1) |
| Testing list | Tasks 4 and 7 |
| Files Changed | All tasks |

The trial-end provenance audit is deliberately **not** in this plan. It runs at the end of the
trial, which is after merge.

**Placeholder scan:** none left unresolved. Two values are filled in at execution time, each with
the command that produces it:
- `YOUR-SESSION-ID` in Task 2 Step 1, needed only when the executing session differs from the one
  that wrote this plan;
- `YYYY-MM-DD` in Task 7 Step 4, the expiry date, computed there with `date -d '+21 days'`.

Every other value is literal.
- The kill-switch wording in Tasks 8 and 9 offers two literal variants to pick from, based on
  Task 3's recorded result.

**Name consistency:**
- Environment variables: `PMB_NOTIFY_STUB`, `PMB_NOTIFY_STUB_DELAY`, `PMB_PRE_APPROVAL`,
  `PMB_PRE_APPROVAL_TEST_FAULT`.
- Log files: `.pmb-pre-approval.log` and `.pmb-hook-errors.log`.
- Log keys: `event=block tier= missing=`, `event=post-block findings= recommendation= escape=`,
  and `event=failopen kind=`.
- These are identical in both scripts and the tests.
