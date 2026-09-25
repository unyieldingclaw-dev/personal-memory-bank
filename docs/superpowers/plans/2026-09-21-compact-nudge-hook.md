# Compact/Clear Nudge Hook Implementation Plan

> **SUPERSEDED — do not execute Tasks 3 onward.** The spec was revised on 2026-09-21 after Task 2's
> spike. The metric changed from transcript byte size to the API-reported token count, reset moved
> into the hook itself, and `pre-compact-check.{sh,ps1}` is no longer touched. Tasks 3–13 below
> implement the superseded design. Tasks 1–2 and their recorded findings remain valid. Regenerate the
> plan from the revised spec once it is re-approved.

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a `UserPromptSubmit` hook that advises `/compact` or `/clear` once the session transcript crosses a size threshold, with the state reset piggybacked onto the existing `PreCompact` gate.

**Architecture:** A new script pair (`compact-nudge-check.{sh,ps1}`) reads `transcript_path` and `session_id` from each turn's hook payload, compares the transcript's byte size against an escalating threshold stored in a **per-session**, gitignored state file, and prints an advisory when crossed. `pre-compact-check.{sh,ps1}` gets a new capability (parsing its own stdin JSON, which it doesn't do today) at each of its existing exit-0 paths, to delete that session's own state file when compaction actually proceeds. Full design and rationale: `docs/superpowers/specs/2026-09-21-compact-nudge-hook-design.md` — read it before starting; this plan does not re-derive its decisions.

**Tech Stack:** POSIX shell + PowerShell (dual-shell mirrors, this repo's established convention), `python3` for JSON parsing on the `.sh` side (matching `check-contract.sh`'s established pattern), native `ConvertFrom-Json` on the `.ps1` side.

**Revision note (2026-09-21):** this plan originally assumed one shared `.pmb-compact-nudge` file. Task 1's live verification spike found that `.claude/settings.json` hooks fire for *every* Claude Code session rooted in the same directory, not just the session that wired them — a temporary diagnostic hook fired for a concurrent peer session mid-spike. A single shared state file has the identical exposure: unrelated sessions would read and write each other's escalation threshold. Revised throughout to a per-`session_id` state file. See the spec's State and escalation logic section for the full account.

---

## File Structure

| File | Responsibility |
|---|---|
| `scripts/compact-nudge-check.sh` / `.ps1` | New hook: reads transcript size, prints advisory, manages `.pmb-compact-nudge-<session_id>` |
| `templates/scripts/compact-nudge-check.sh` / `.ps1` | Distribution mirrors |
| `scripts/pre-compact-check.sh` / `.ps1` | Existing gate; gets a reset call at each exit-0 site, and new session_id-parsing capability |
| `templates/scripts/pre-compact-check.sh` / `.ps1` | Distribution mirrors |
| `.claude/settings.json` / `templates/.claude/settings.json` | New `UserPromptSubmit` hook registration |
| `.gitignore` | New `.pmb-compact-nudge-*` wildcard entry |
| `standards/PERFORMANCE-BUDGET.md` | Documents `FIRST_THRESHOLD` / `RENUDGE_INTERVAL` |
| `docs/HOOKS-GUIDE.md` / `templates/docs/HOOKS-GUIDE.md` | New numbered hook entry |
| `tests/test-compact-nudge-check.sh` | New: threshold/escalation behavior, per-session independence |
| `tests/test-pre-compact-check.sh` | Existing: new cases for the reset behavior, cross-session isolation |

Each task below produces one self-contained, committable change.

---

### Task 1: Verification Spike — confirm `transcript_path` is in the real `UserPromptSubmit` payload

**Status: DONE (2026-09-21).** Recorded here for the record; no further action needed.

**Result:** confirmed present. Two independent live captures, both including `transcript_path` and `session_id`:
- This session (`session_id` ending `...6f79-4dd3-8a21-62fd5081a05d`): `transcript_path` pointed at that session's own `.jsonl` transcript file.
- A concurrent peer session (`session_id` ending `...934c-4bbb-9f91-db4e13f4c174`, title "PMB full review and PR #12 disposition"): a *different* `transcript_path`, correctly scoped to that session.

**This second capture was not intentional — it is the finding that drove this plan's per-session revision.** The diagnostic hook was wired into `.claude/settings.json`, which is per-directory, not per-session; the peer session's own `UserPromptSubmit` fired the same hook and overwrote the capture before this session's own turn could be read back reliably. The diagnostic script and its temporary `.claude/settings.json` wiring were removed immediately afterward — both because the spike's purpose was served and because the captured file contained another session's private prompt content, which was deleted rather than kept. **Do not re-run Task 1** — Task 2 below sets up its own (improved) diagnostic wiring from scratch, since Task 1's was torn down.

---

### Task 2: Verification Spikes 2 & 3 — `transcript_path` across a real `/compact`, and `session_id` in `PreCompact`'s payload

**Why combined:** both questions are best answered from the *same* real `/compact` event — it's the one genuinely disruptive manual step in this plan, and there's no reason to trigger it twice. **Why session-ID-checked this time:** Task 1 showed hook payloads in this repo can come from a different session than expected. Every step below verifies the captured `session_id` before trusting anything else in the same payload.

**Files:**
- Create (temporary): `scripts/_diag-hook-payload.sh`
- Modify (temporary): `.claude/settings.json`

- [ ] **Step 1: Write the diagnostic hook (session-ID-aware this time)**

```sh
#!/usr/bin/env sh
# TEMPORARY diagnostic hook for Task 2 of the compact-nudge-hook plan.
# Appends raw stdin JSON as one line to a scratch log, tagged with the firing event, so multiple
# captures (including from other sessions) don't silently overwrite each other like Task 1's did.
INPUT=$(cat 2>/dev/null)
printf '%s\n' "$INPUT" >> ".pmb-diag-payload.jsonl" 2>/dev/null
exit 0
```

Save as `scripts/_diag-hook-payload.sh`.

- [ ] **Step 2: Wire it into both `UserPromptSubmit` and `PreCompact` temporarily**

Add to `.claude/settings.json`'s `hooks` object:

```json
"UserPromptSubmit": [
  {
    "hooks": [
      {
        "type": "command",
        "command": "bash scripts/_diag-hook-payload.sh 2>/dev/null || true"
      }
    ]
  }
]
```

And add a second entry to the *existing* `PreCompact` array (alongside `pre-compact-check`, not replacing it — this must run in addition to the real gate, never instead of it):

```json
{
  "hooks": [
    {
      "type": "command",
      "command": "bash scripts/_diag-hook-payload.sh 2>/dev/null || true"
    }
  ]
}
```

- [ ] **Step 3: Note this session's own `session_id` before triggering anything**

```bash
cd "C:\Users\Mizzo\Claude\Personal-Memory-Bank"
rm -f .pmb-diag-payload.jsonl   # start clean, so line count is unambiguous
```

Send any next message in this session (e.g. "continue"). Then:

```bash
cat .pmb-diag-payload.jsonl
python3 -c "
import json
for line in open('.pmb-diag-payload.jsonl'):
    line = line.strip()
    if not line: continue
    d = json.loads(line)
    print(d.get('session_id'), d.get('hook_event_name'), d.get('transcript_path'))
"
```

Record **this session's own `session_id`** from the output — every later step in this task must check captured lines against this exact value before trusting them, exactly the safeguard Task 1 didn't have.

- [ ] **Step 4: Capture pre-compact transcript size, for THIS session's own line only**

```bash
python3 -c "
import json
my_session_id = 'PASTE THE SESSION_ID FROM STEP 3 HERE'
for line in open('.pmb-diag-payload.jsonl'):
    line = line.strip()
    if not line: continue
    d = json.loads(line)
    if d.get('session_id') == my_session_id and d.get('hook_event_name') == 'UserPromptSubmit':
        print(d['transcript_path'])
" > /tmp/pmb-pre-compact-path.txt
cat /tmp/pmb-pre-compact-path.txt
wc -c "$(cat /tmp/pmb-pre-compact-path.txt)"
```

If this prints nothing, the session-ID filter excluded every captured line (possibly another session's turn arrived first again) — send another message and retry rather than trusting an unfiltered read.

- [x] **Step 5: Run `/compact` (manual — requires live interaction)**

Trigger a real `/compact` in this session. This should fire the `PreCompact` diagnostic entry.

**Status: DONE.** `/compact` ran 2026-09-21. Local command output confirmed both `PreCompact` hook entries fired successfully (`pre-compact-check` and the diagnostic).

- [x] **Step 6: Trigger another turn and capture post-compact state, session-ID-filtered again**

Send any next message, then:

```bash
python3 -c "
import json
my_session_id = 'PASTE THE SAME SESSION_ID FROM STEP 3'
for line in open('.pmb-diag-payload.jsonl'):
    line = line.strip()
    if not line: continue
    d = json.loads(line)
    if d.get('session_id') == my_session_id and d.get('hook_event_name') == 'UserPromptSubmit':
        print(d['transcript_path'])
" | tail -1 > /tmp/pmb-post-compact-path.txt
cat /tmp/pmb-post-compact-path.txt
wc -c "$(cat /tmp/pmb-post-compact-path.txt)" 2>&1
diff /tmp/pmb-pre-compact-path.txt /tmp/pmb-post-compact-path.txt && echo "SAME PATH" || echo "DIFFERENT PATH"
```

- [x] **Step 7: Check whether the `PreCompact` payload included `session_id`**

```bash
python3 -c "
import json
my_session_id = 'PASTE THE SAME SESSION_ID FROM STEP 3'
found = False
for line in open('.pmb-diag-payload.jsonl'):
    line = line.strip()
    if not line: continue
    d = json.loads(line)
    if d.get('hook_event_name') == 'PreCompact' and d.get('session_id') == my_session_id:
        print('PreCompact payload has session_id:', d.get('session_id'))
        found = True
if not found:
    print('NO MATCHING PreCompact LINE FOUND FOR THIS SESSION')
"
```

- [x] **Step 8: Record both findings**

Edit this section of the plan directly with the actual results:

*Transcript-path-across-`/compact` finding:*
- Same path, smaller size → Reset section's assumption holds as designed.
- Same path, size kept growing (summary appended, not shrunk) → wrong; the state file must reset to the **post-compact size**, not to absent/zero, or the next turn immediately re-nudges. Fix before Task 3/4.
- Different path → note the new path pattern.

**Result: second branch hit.** Same path both times
(`26736dfa-6f79-4dd3-8a21-62fd5081a05d.jsonl`). Pre-compact size: **19,521,648 bytes** (captured
Task 2 spike, prior turn). Post-compact size, measured immediately after `/compact` returned:
**19,930,408 bytes** — **408,760 bytes larger, not smaller.** `/compact` does not shrink (or even
preserve) the on-disk transcript file; it is an append-only session log, decoupled from whatever
representation is actually sent to the model as context. Compaction summaries and all subsequent
turns keep appending to the same file forever. **The design correction the plan's own contingency
text calls for is required**: the reset (piggybacked on `pre-compact-check`'s exit-0 paths) must
write the **size at reset time as a new baseline**, not delete the state file to absent/zero, and
`compact-nudge-check`'s comparison must become **(current size − baseline) vs. threshold**, not
(current size vs. threshold). This changes Task 3/4's implementation contract (state file stores a
byte offset, not just a "have I nudged" marker) and Task 7/8's reset logic (write current size, not
`rm` the file) — both need the spec's Metric and Reset sections revised before proceeding.
**This compounds the earlier live finding that `FIRST_THRESHOLD=400000` is ~48x smaller than a
single ordinary session's observed transcript growth** — the threshold recalibration and this
delta-vs-absolute correction are the same root problem (the spec conflated "raw transcript byte
count" with "current effective context size") and should be fixed together, not sequentially.

*`PreCompact` `session_id` finding:*
- Present → Task 7/8 can proceed as designed (parse `session_id` from `PreCompact`'s own stdin).
- Absent → **STOP.** The Reset section's per-session-scoped delete has no way to know which file to delete. This needs a design correction (e.g., matching by matching `transcript_path`'s directory/session instead, if that's derivable) before Task 7/8 — do not fall back to deleting all `.pmb-compact-nudge-*` files indiscriminately, which would silently reintroduce cross-session interference in the opposite direction.

**Result: first branch hit — present.** The captured `PreCompact` payload for this session was
`{"session_id":"26736dfa-6f79-4dd3-8a21-62fd5081a05d", "transcript_path":"...26736dfa....jsonl",
"hook_event_name":"PreCompact","trigger":"manual","custom_instructions":null, ...}`. `session_id`
is present and matches. Task 7/8's plan to parse `session_id` from `PreCompact`'s own stdin is
confirmed viable — no design correction needed on this axis.

**Net verdict for Task 2: BLOCKED on a design correction, not clear to proceed to Task 3/4 as
written.** The session_id-matching mechanism is sound; the absolute-size-vs-threshold metric and
delete-based reset are not. See spec/plan revision needed before implementation resumes.

- [x] **Step 9: Clean up the diagnostic hook (completed 2026-09-22)**

```bash
rm -f scripts/_diag-hook-payload.sh .pmb-diag-payload.jsonl
```

Remove **both** temporary entries from `.claude/settings.json` (the `UserPromptSubmit` key added in Step 2, and the diagnostic entry added to the `PreCompact` array — leave `pre-compact-check`'s own entry there, remove only the one this task added). Verify:

```bash
grep -n "_diag-hook-payload" .claude/settings.json
```

Expected: no output.

**Recorded result:** the temporary script, payload, and both temporary settings entries were
removed after the spike. Re-checked 2026-09-24: none exists or is referenced in this worktree.

---

### Task 3: `compact-nudge-check.sh` — implement and test

**Files:**
- Create: `scripts/compact-nudge-check.sh`
- Test: `tests/test-compact-nudge-check.sh`

- [ ] **Step 1: Write the failing test**

```sh
#!/usr/bin/env bash
# tests/test-compact-nudge-check.sh — tests for the UserPromptSubmit compact/clear nudge hook
set -u

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
HOOK="$REPO_ROOT/scripts/compact-nudge-check.sh"
source "$REPO_ROOT/tests/helpers/assert.sh"

echo "=== compact-nudge-check tests ==="

TMPDIR_CN="$(mktemp -d 2>/dev/null || mktemp -d -t mb-compactnudge-test)"
trap 'rm -rf "$TMPDIR_CN"' EXIT

# Makes a fake transcript file of exactly $2 bytes at $1.
make_transcript() {
    local path="$1" bytes="$2"
    python3 -c "open('$path','wb').write(b'x' * $bytes)"
}

run_hook() {
    local dir="$1" transcript="$2" session="${3:-test-session-aaa}"
    ( cd "$dir" && printf '{"transcript_path":"%s","session_id":"%s"}' "$transcript" "$session" | bash "$HOOK" 2>&1 )
}
hook_code() {
    local dir="$1" transcript="$2" session="${3:-test-session-aaa}"
    ( cd "$dir" && printf '{"transcript_path":"%s","session_id":"%s"}' "$transcript" "$session" | bash "$HOOK" >/dev/null 2>&1; echo $? )
}

# ── cold start, below threshold: silent ────────────────────────────────────────────────────
echo ""
echo "--- cold start, transcript below FIRST_THRESHOLD: no advisory ---"
D="$TMPDIR_CN/below"; mkdir -p "$D"
T="$D/transcript.jsonl"; make_transcript "$T" 1000
out="$(run_hook "$D" "$T")"
assert_equals "$out" "" "no output when transcript is far below threshold"
assert_file_not_exists "$D/.pmb-compact-nudge-test-session-aaa" "no state file written when nothing crossed"

# ── cold start, above threshold: fires once ────────────────────────────────────────────────
echo ""
echo "--- cold start, transcript above FIRST_THRESHOLD (400000): advisory fires ---"
D="$TMPDIR_CN/above"; mkdir -p "$D"
T="$D/transcript.jsonl"; make_transcript "$T" 450000
out="$(run_hook "$D" "$T")"
assert_contains "$out" "ADVISORY" "advisory printed when transcript crosses FIRST_THRESHOLD"
assert_contains "$out" "compact" "advisory mentions /compact"
assert_file_exists "$D/.pmb-compact-nudge-test-session-aaa" "state file written after firing, named for the session"

# ── does not re-fire before the next threshold ─────────────────────────────────────────────
echo ""
echo "--- same size again: does NOT re-fire (fire-once-per-crossing) ---"
out2="$(run_hook "$D" "$T")"
assert_equals "$out2" "" "no advisory on a repeat call at the same size — the negative case delegation-depth-check.sh does not guard against"

# ── re-fires once RENUDGE_INTERVAL further ─────────────────────────────────────────────────
echo ""
echo "--- transcript grows past next_nudge_at: fires again ---"
# After the first fire at 450000, next_nudge_at became 450000 + RENUDGE_INTERVAL (150000) = 600000.
# 610000 is comfortably past that new threshold, not a sum of the two constants itself.
make_transcript "$T" 610000
out3="$(run_hook "$D" "$T")"
assert_contains "$out3" "ADVISORY" "advisory fires again after crossing the escalated threshold"

# ── two different sessions get independently-tracked state ─────────────────────────────────
# WHY this test exists: the direct regression test for the cross-session collision found during
# Task 1's live verification spike, which drove this hook's whole per-session redesign.
echo ""
echo "--- two different session_ids: independent state, no cross-talk ---"
D="$TMPDIR_CN/multisession"; mkdir -p "$D"
T_BIG="$D/transcript-big.jsonl"; make_transcript "$T_BIG" 500000
T_SMALL="$D/transcript-small.jsonl"; make_transcript "$T_SMALL" 1000
out_a="$(run_hook "$D" "$T_BIG" "session-A")"
assert_contains "$out_a" "ADVISORY" "session A (large transcript) gets its own advisory"
out_b="$(run_hook "$D" "$T_SMALL" "session-B")"
assert_equals "$out_b" "" "session B (small transcript) is NOT affected by session A's threshold -- the actual bug this design fixes"
assert_file_exists "$D/.pmb-compact-nudge-session-A" "session A has its own state file"
assert_file_not_exists "$D/.pmb-compact-nudge-session-B" "session B has no state file yet (never crossed FIRST_THRESHOLD itself)"

# ── malformed transcript_path: fails open ──────────────────────────────────────────────────
echo ""
echo "--- transcript_path points nowhere: fails open silently ---"
D="$TMPDIR_CN/missing"; mkdir -p "$D"
code="$(hook_code "$D" "$D/does-not-exist.jsonl")"
assert_equals "$code" "0" "missing transcript file: exits 0 (fail open)"

# ── malformed JSON stdin: fails open ───────────────────────────────────────────────────────
echo ""
echo "--- malformed stdin JSON: fails open silently ---"
D="$TMPDIR_CN/badjson"; mkdir -p "$D"
code="$(cd "$D" && printf 'not json' | bash "$HOOK" >/dev/null 2>&1; echo $?)"
assert_equals "$code" "0" "malformed JSON: exits 0 (fail open)"

# ── missing session_id: fails open, writes nothing ─────────────────────────────────────────
echo ""
echo "--- payload has transcript_path but no session_id: fails open, writes no file ---"
D="$TMPDIR_CN/nosession"; mkdir -p "$D"
T="$D/transcript.jsonl"; make_transcript "$T" 500000
code="$(cd "$D" && printf '{"transcript_path":"%s"}' "$T" | bash "$HOOK" >/dev/null 2>&1; echo $?)"
assert_equals "$code" "0" "missing session_id: exits 0 (fail open)"
files_written="$(find "$D" -maxdepth 1 -name '.pmb-compact-nudge-*' | wc -l | tr -d ' ')"
assert_equals "$files_written" "0" "missing session_id must never fall back to an un-scoped filename"

# ── \r-contaminated state file: parsed correctly ───────────────────────────────────────────
echo ""
echo "--- state file with embedded \\r (cross-shell contamination): still parsed ---"
D="$TMPDIR_CN/crlf"; mkdir -p "$D"
T="$D/transcript.jsonl"; make_transcript "$T" 100000
printf 'next_nudge_at=50000\r\n' > "$D/.pmb-compact-nudge-test-session-aaa"
out="$(run_hook "$D" "$T")"
assert_contains "$out" "ADVISORY" "a \\r-contaminated next_nudge_at value is still parsed and crossed correctly"

print_summary
exit $?
```

- [ ] **Step 2: Run test to verify it fails**

```bash
cd "C:\Users\Mizzo\Claude\Personal-Memory-Bank"
bash tests/test-compact-nudge-check.sh
```

Expected: FAIL — `scripts/compact-nudge-check.sh` does not exist yet.

- [ ] **Step 3: Write the implementation**

```sh
#!/usr/bin/env sh
# UserPromptSubmit hook -- nudges toward /compact or /clear based on transcript size.
# Fires once per user turn. Advisory only, never blocks. Fails open on any error.
# See docs/superpowers/specs/2026-09-21-compact-nudge-hook-design.md for the full design.

FIRST_THRESHOLD=400000   # ~400 KB; see standards/PERFORMANCE-BUDGET.md
RENUDGE_INTERVAL=150000  # ~150 KB; see standards/PERFORMANCE-BUDGET.md

# WHY no .pmb-hook-errors.log writes here: that logging is a .ps1-side convention in this repo
# (via try/catch) -- check-contract.sh, delegation-depth-check.sh and warn-stale-review-marker.sh
# all fail open silently on their .sh side too, with no equivalent log write. Matching that,
# not omitting it by oversight.
command -v python3 >/dev/null 2>&1 || exit 0  # fail open: no python3, skip entirely

HOOK_INPUT=$(cat 2>/dev/null)
[ -z "$HOOK_INPUT" ] && exit 0

# WHY .get(...,'') for both fields: matches check-contract.sh's established pattern for pulling a
# flat field out of the hook payload without crashing on absence.
PARSED=$(echo "$HOOK_INPUT" | python3 -c "
import sys, json
try:
    data = json.load(sys.stdin)
    print(data.get('transcript_path', ''))
    print(data.get('session_id', ''))
except Exception:
    print('')
    print('')
" 2>/dev/null | tr -d '\r')

TRANSCRIPT_PATH=$(echo "$PARSED" | sed -n '1p')
SESSION_ID=$(echo "$PARSED" | sed -n '2p')

[ -z "$TRANSCRIPT_PATH" ] && exit 0
[ -f "$TRANSCRIPT_PATH" ] || exit 0
# Missing session_id must never fall back to an un-scoped filename -- that would silently
# reintroduce the cross-session collision this design exists to close. Absence means "do nothing."
[ -z "$SESSION_ID" ] && exit 0

STATE_FILE=".pmb-compact-nudge-${SESSION_ID}"

CURRENT_SIZE=$(wc -c < "$TRANSCRIPT_PATH" 2>/dev/null | tr -d '[:space:]')
case "$CURRENT_SIZE" in
    ''|*[!0-9]*) exit 0 ;;  # not a clean integer -- fail open rather than risk a bad comparison
esac

NEXT_NUDGE_AT="$FIRST_THRESHOLD"
if [ -f "$STATE_FILE" ]; then
    # WHY tr -d '\r': python3's print() on Windows emits \r\n; the state file may also have been
    # written by the .ps1 twin. Same fix as check-contract.sh's established convention.
    STORED=$(grep '^next_nudge_at=' "$STATE_FILE" 2>/dev/null | cut -d= -f2 | tr -d '\r' | tr -d '[:space:]')
    case "$STORED" in
        ''|*[!0-9]*) ;;  # not a clean integer -- keep the default rather than crash on comparison
        *) NEXT_NUDGE_AT="$STORED" ;;
    esac
fi

if [ "$CURRENT_SIZE" -ge "$NEXT_NUDGE_AT" ]; then
    KB=$((CURRENT_SIZE / 1024))
    printf '[ADVISORY] Session transcript ~%sKB. Consider /compact at a natural boundary, or /clear if switching to unrelated work -- see CLAUDE.md Token Budget section.\n' "$KB"
    NEW_NEXT=$((CURRENT_SIZE + RENUDGE_INTERVAL))
    printf 'next_nudge_at=%d\n' "$NEW_NEXT" > "$STATE_FILE" 2>/dev/null || true
fi

exit 0
```

Save as `scripts/compact-nudge-check.sh`.

**Note on the `PARSED`/`sed -n` two-line extraction:** a single `python3` invocation prints both fields on separate lines rather than two separate invocations, to halve the process-spawn cost on a hook that fires every turn. If either field is genuinely absent, its line is still emitted (empty), so `sed -n '1p'`/`'2p'` stay positionally correct — this is why the `except` branch above prints two empty lines, not one.

- [ ] **Step 4: Run test to verify it passes**

```bash
bash tests/test-compact-nudge-check.sh
```

Expected: `Results: 16 passed, 0 failed`, exit 0.

- [ ] **Step 5: Commit**

```bash
git add scripts/compact-nudge-check.sh tests/test-compact-nudge-check.sh
git commit -m "feat: add compact-nudge-check.sh, a per-session UserPromptSubmit advisory"
```

---

### Task 4: `compact-nudge-check.ps1` — implement to match the proven `.sh` logic

**Files:**
- Create: `scripts/compact-nudge-check.ps1`

- [ ] **Step 1: Write the implementation**

```powershell
<#
.SYNOPSIS
    UserPromptSubmit hook -- nudges toward /compact or /clear based on transcript size.
.DESCRIPTION
    Fires once per user turn. Advisory only, never blocks. Fails open on any error.
    State is scoped per session_id -- a single shared file was found to collide across
    concurrent sessions rooted in the same directory during this feature's own verification spike.
    See docs/superpowers/specs/2026-09-21-compact-nudge-hook-design.md for the full design.
#>

param()

$FirstThreshold = 400000   # ~400 KB; see standards/PERFORMANCE-BUDGET.md
$RenudgeInterval = 150000  # ~150 KB; see standards/PERFORMANCE-BUDGET.md

try {
    $hookInput = [Console]::In.ReadToEnd()
    if ([string]::IsNullOrWhiteSpace($hookInput)) { exit 0 }

    $data = $hookInput | ConvertFrom-Json -ErrorAction Stop
    $transcriptPath = $data.transcript_path
    $sessionId = $data.session_id
    if ([string]::IsNullOrWhiteSpace($transcriptPath)) { exit 0 }
    if (-not (Test-Path $transcriptPath)) { exit 0 }
    # Missing session_id must never fall back to an un-scoped filename -- see the .sh twin's
    # identical comment. Absence means "do nothing," not "guess."
    if ([string]::IsNullOrWhiteSpace($sessionId)) { exit 0 }

    $stateFile = ".pmb-compact-nudge-$sessionId"
    $currentSize = (Get-Item $transcriptPath).Length

    $nextNudgeAt = $FirstThreshold
    if (Test-Path $stateFile) {
        $line = Get-Content $stateFile -ErrorAction SilentlyContinue | Where-Object { $_ -match '^next_nudge_at=' } | Select-Object -First 1
        if ($line -match '^next_nudge_at=(\d+)') {
            $nextNudgeAt = [int64]$Matches[1]
        }
    }

    if ($currentSize -ge $nextNudgeAt) {
        $kb = [math]::Floor($currentSize / 1024)
        Write-Host "[ADVISORY] Session transcript ~${kb}KB. Consider /compact at a natural boundary, or /clear if switching to unrelated work -- see CLAUDE.md Token Budget section."
        $newNext = $currentSize + $RenudgeInterval
        "next_nudge_at=$newNext" | Set-Content $stateFile -ErrorAction SilentlyContinue
    }

    exit 0
} catch {
    try { Add-Content ".pmb-hook-errors.log" "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] [HOOK] compact-nudge-check.ps1: $_" -ErrorAction SilentlyContinue } catch { Write-Verbose "Could not write .pmb-hook-errors.log; ignoring." }
    exit 0
}
```

Save as `scripts/compact-nudge-check.ps1`.

- [ ] **Step 2: Manual structural verification**

No Pester twin exists for this pair (see spec's Files Changed note — `pre-compact-check` and `delegation-depth-check` don't have one either). Verify structurally instead:

```powershell
cd "C:\Users\Mizzo\Claude\Personal-Memory-Bank"
'{"transcript_path":"scripts/compact-nudge-check.ps1","session_id":"ps-test-session"}' | pwsh -NonInteractive -File scripts/compact-nudge-check.ps1
```

Expected: exits 0, no output (the script file itself is far under 400 KB, so no crossing).

```powershell
$env:TEMP_TRANSCRIPT = Join-Path $env:TEMP "pmb-fake-transcript.txt"
[byte[]]$bytes = New-Object byte[] 450000
[System.IO.File]::WriteAllBytes($env:TEMP_TRANSCRIPT, $bytes)
$payload = @{ transcript_path = $env:TEMP_TRANSCRIPT; session_id = "ps-test-session" } | ConvertTo-Json -Compress
$payload | pwsh -NonInteractive -File scripts/compact-nudge-check.ps1
Test-Path ".pmb-compact-nudge-ps-test-session"
Remove-Item $env:TEMP_TRANSCRIPT, ".pmb-compact-nudge-ps-test-session" -ErrorAction SilentlyContinue
```

Expected: prints `[ADVISORY] Session transcript ~439KB...`, then `True`, exits 0.

- [ ] **Step 3: Commit**

```bash
git add scripts/compact-nudge-check.ps1
git commit -m "feat: add compact-nudge-check.ps1, PowerShell twin of the compact-nudge hook"
```

---

### Task 5: `templates/scripts/` mirrors

**Files:**
- Create: `templates/scripts/compact-nudge-check.sh`, `templates/scripts/compact-nudge-check.ps1`

- [ ] **Step 1: Copy both scripts verbatim**

```bash
cd "C:\Users\Mizzo\Claude\Personal-Memory-Bank"
cp scripts/compact-nudge-check.sh templates/scripts/compact-nudge-check.sh
cp scripts/compact-nudge-check.ps1 templates/scripts/compact-nudge-check.ps1
```

- [ ] **Step 2: Confirm byte-identity**

```bash
diff scripts/compact-nudge-check.sh templates/scripts/compact-nudge-check.sh && echo "IDENTICAL"
diff scripts/compact-nudge-check.ps1 templates/scripts/compact-nudge-check.ps1 && echo "IDENTICAL"
```

Expected: `IDENTICAL` twice, no diff output.

- [ ] **Step 3: Commit**

```bash
git add templates/scripts/compact-nudge-check.sh templates/scripts/compact-nudge-check.ps1
git commit -m "feat: mirror compact-nudge-check into templates/scripts/"
```

---

### Task 6: Wire `UserPromptSubmit` into settings

**Files:**
- Modify: `.claude/settings.json`
- Modify: `templates/.claude/settings.json`

- [ ] **Step 1: Add the hook entry to `.claude/settings.json`**

Add a new top-level key inside `"hooks": { ... }`, alongside the existing `PostToolUse`/`PreToolUse`/`PreCompact`/`Stop` keys:

```json
"UserPromptSubmit": [
  {
    "hooks": [
      {
        "type": "command",
        "command": "pwsh -NonInteractive -File scripts/compact-nudge-check.ps1 2>/dev/null || bash scripts/compact-nudge-check.sh 2>/dev/null || true"
      }
    ]
  }
]
```

No `matcher` field — `UserPromptSubmit` is inherently turn-scoped, not tool-scoped.

- [ ] **Step 2: Verify the JSON is still valid**

```bash
python3 -c "import json; json.load(open('.claude/settings.json')); print('VALID')"
```

Expected: `VALID`.

- [ ] **Step 3: Mirror into `templates/.claude/settings.json`**

Apply the identical addition to `templates/.claude/settings.json`, then verify:

```bash
python3 -c "import json; json.load(open('templates/.claude/settings.json')); print('VALID')"
```

- [ ] **Step 4: Live smoke test (manual)**

Send a message in this session and confirm no error surfaces and no unexpected advisory fires. If a leftover `.pmb-compact-nudge-*` file exists from Task 2's spike (check `ls -a .pmb-compact-nudge-* 2>/dev/null`), delete it first so it doesn't carry a stale threshold from testing into real use.

- [ ] **Step 5: Commit**

```bash
git add .claude/settings.json templates/.claude/settings.json
git commit -m "feat: wire compact-nudge-check into UserPromptSubmit"
```

---

### Task 7: Reset logic in `pre-compact-check.sh` + new test cases

**Files:**
- Modify: `scripts/pre-compact-check.sh`
- Modify: `tests/test-pre-compact-check.sh`

- [ ] **Step 1: First, fix a latent hang risk in the EXISTING `run_hook`/`hook_code` helpers**

Task 7 Step 3 adds an unconditional `cat` on stdin inside `pre-compact-check.sh` (needed to read `session_id`). The script's *existing* tests invoke it as `bash "$HOOK"` with nothing piped in and no stdin redirection at all — that subshell inherits whatever stdin the test script itself has. In a real hook invocation Claude Code always provides JSON on stdin, so this is fine in production; but run this test file interactively (stdin attached to a terminal, not piped or redirected) and the new `cat` would block waiting for EOF, hanging the entire suite. Fix the existing helpers to redirect stdin explicitly, matching what any real invocation always has — some stdin, never a terminal:

```sh
run_hook() { ( cd "$1" && bash "$HOOK" < /dev/null 2>&1 ); }
hook_code() { ( cd "$1" && bash "$HOOK" < /dev/null >/dev/null 2>&1; echo $? ); }
```

Locate the current definitions (`grep -n "^run_hook\|^hook_code" tests/test-pre-compact-check.sh`) and add ` < /dev/null` to both — every pre-existing test that calls these two functions keeps working unchanged, since an empty stdin read is exactly what "no session_id in this call" should mean.

- [ ] **Step 2: Write the failing test cases**

Append to `tests/test-pre-compact-check.sh`, before the final `print_summary` call (check the file's current end to place these correctly — do not duplicate an existing `print_summary` call):

```sh
# ── compact-nudge-hook reset: exit-0 paths delete THIS session's state file only ──────────
run_hook_with_session() {
    local dir="$1" session="$2"
    ( cd "$dir" && printf '{"session_id":"%s"}' "$session" | bash "$HOOK" 2>&1 )
}
hook_code_with_session() {
    local dir="$1" session="$2"
    ( cd "$dir" && printf '{"session_id":"%s"}' "$session" | bash "$HOOK" >/dev/null 2>&1; echo $? )
}

echo ""
echo "--- .pmb-compact-nudge-<session> is deleted when the gate allows compaction (checks-passed path) ---"
D="$TMPDIR_PC/reset-allow"; make_bank "$D" fresh
printf 'next_nudge_at=999999\n' > "$D/.pmb-compact-nudge-sess-allow"
hook_code_with_session "$D" "sess-allow" >/dev/null
assert_file_not_exists "$D/.pmb-compact-nudge-sess-allow" "checks-passed exit-0 path deletes this session's own state file"

echo ""
echo "--- .pmb-compact-nudge-<session> is deleted when a fresh handoff.md bypasses the gate ---"
D="$TMPDIR_PC/reset-bypass"; make_bank "$D" thin
printf '# Handoff\n\nin-flight state\n' > "$D/handoff.md"
printf 'next_nudge_at=999999\n' > "$D/.pmb-compact-nudge-sess-bypass"
hook_code_with_session "$D" "sess-bypass" >/dev/null
assert_file_not_exists "$D/.pmb-compact-nudge-sess-bypass" "handoff-bypass exit-0 path deletes this session's own state file"

echo ""
echo "--- .pmb-compact-nudge-<session> is NOT touched when the gate blocks compaction ---"
D="$TMPDIR_PC/reset-block"; make_bank "$D" thin
printf 'next_nudge_at=999999\n' > "$D/.pmb-compact-nudge-sess-block"
hook_code_with_session "$D" "sess-block" >/dev/null
assert_file_exists "$D/.pmb-compact-nudge-sess-block" "blocked (exit 2) path leaves the state file untouched -- compaction did not happen"

echo ""
echo "--- a DIFFERENT session's state file is left untouched by this session's reset ---"
# WHY this test exists: the direct regression test for the cross-session collision found during
# this feature's own verification spike -- a happy-path deletion test alone would not catch a
# reset that deletes the wrong file, or every file, instead of just this session's own.
D="$TMPDIR_PC/reset-isolated"; make_bank "$D" fresh
printf 'next_nudge_at=999999\n' > "$D/.pmb-compact-nudge-sess-mine"
printf 'next_nudge_at=888888\n' > "$D/.pmb-compact-nudge-sess-other"
hook_code_with_session "$D" "sess-mine" >/dev/null
assert_file_not_exists "$D/.pmb-compact-nudge-sess-mine" "this session's own file is deleted"
assert_file_exists "$D/.pmb-compact-nudge-sess-other" "a different session's file is left completely untouched"
```

- [ ] **Step 3: Run test to verify it fails**

```bash
bash tests/test-pre-compact-check.sh
```

Expected: the new assertions FAIL (no session_id parsing exists yet, so nothing is ever deleted); prior assertions still pass, and — thanks to Step 1's fix — nothing hangs.

- [ ] **Step 4: Add stdin JSON parsing and the reset calls to `scripts/pre-compact-check.sh`**

This script currently reads no stdin at all. Add parsing near the top, right after the existing `today=$(date +%Y-%m-%d)` line:

```sh
today=$(date +%Y-%m-%d)

# WHY this exists: compact-nudge-check.sh's state file is scoped per session_id (see
# docs/superpowers/specs/2026-09-21-compact-nudge-hook-design.md's Reset section) -- resetting it
# here requires knowing which session this PreCompact invocation belongs to. This script parsed no
# stdin before this addition.
SESSION_ID=""
if command -v python3 >/dev/null 2>&1; then
    HOOK_INPUT=$(cat 2>/dev/null)
    if [ -n "$HOOK_INPUT" ]; then
        SESSION_ID=$(echo "$HOOK_INPUT" | python3 -c "
import sys, json
try:
    print(json.load(sys.stdin).get('session_id', ''))
except Exception:
    print('')
" 2>/dev/null | tr -d '\r')
    fi
fi

reset_compact_nudge() {
    # Missing session_id: do nothing rather than guess which file to delete, or delete all of
    # them -- either would reintroduce cross-session interference in a different shape.
    [ -n "$SESSION_ID" ] && rm -f ".pmb-compact-nudge-${SESSION_ID}" 2>/dev/null
    true
}
```

**Reading stdin here changes this script's calling convention** — it previously read no input at all. Confirm `.claude/settings.json`'s `PreCompact` wiring already pipes hook input to it the same way `PostToolUse`/`PreToolUse` entries do (Claude Code hooks receive their JSON payload on stdin uniformly; this is not a new assumption specific to this script).

Then two call sites. First, the handoff-bypass `exit 0`:

```sh
    if [ -n "$handoff_date" ] && [ "$handoff_date" = "$today" ]; then
        reset_compact_nudge
        exit 0
    fi
```

Second, the checks-passed `exit 0`:

```sh
if [ "${#BLOCK_REASONS[@]}" -eq 0 ]; then
    reset_compact_nudge
    exit 0
fi
```

`reset_compact_nudge`'s own internal `rm -f ... 2>/dev/null` plus the trailing `true` mean its failure can never change this script's exit code — a failed delete of an advisory state file is not grounds to accidentally block compaction.

- [ ] **Step 5: Run test to verify it passes**

```bash
bash tests/test-pre-compact-check.sh
```

Expected: all assertions pass, including the four new ones, with no hang — Step 1's `< /dev/null` fix is what makes the pre-existing no-session_id tests still terminate cleanly now that the script actually reads stdin.

```bash
bash tests/test-pre-compact-check.sh 2>&1 | grep -c "PASS"
```

Should match the total assertion count from before this task plus the 4 new ones.

- [ ] **Step 6: Commit**

```bash
git add scripts/pre-compact-check.sh tests/test-pre-compact-check.sh
git commit -m "feat: reset this session's own .pmb-compact-nudge-<session_id> on pre-compact-check.sh's exit-0 paths"
```

---

### Task 8: Reset logic in `pre-compact-check.ps1`

**Files:**
- Modify: `scripts/pre-compact-check.ps1`

- [ ] **Step 1: Add stdin JSON parsing near the top of the `try` block**

Right after `param()`, before the existing `try {` block's first line:

```powershell
param()

# WHY this exists: compact-nudge-check.ps1's state file is scoped per session_id (see
# docs/superpowers/specs/2026-09-21-compact-nudge-hook-design.md's Reset section) -- resetting it
# here requires knowing which session this PreCompact invocation belongs to. This script parsed no
# stdin before this addition.
$script:SessionId = $null
try {
    $hookInput = [Console]::In.ReadToEnd()
    if (-not [string]::IsNullOrWhiteSpace($hookInput)) {
        $script:SessionId = ($hookInput | ConvertFrom-Json -ErrorAction Stop).session_id
    }
} catch {
    $script:SessionId = $null
}

function Reset-CompactNudge {
    # Missing session_id: do nothing rather than guess which file to delete, or delete all of
    # them -- either would reintroduce cross-session interference in a different shape.
    if (-not [string]::IsNullOrWhiteSpace($script:SessionId)) {
        Remove-Item ".pmb-compact-nudge-$script:SessionId" -ErrorAction SilentlyContinue
    }
}

try {
    $today = Get-Date -Format 'yyyy-MM-dd'
```

(The existing `try { $today = ... ` line is kept, just now preceded by the session-ID pre-read — this script already reads `[Console]::In` nowhere, so this is new ground exactly as it is in the `.sh` twin.)

- [ ] **Step 2: Add the reset calls at all 3 exit-0 sites**

Handoff-bypass:

```powershell
        if ($handoffDate -eq $today) {
            Reset-CompactNudge
            exit 0
        }
```

Checks-passed:

```powershell
    if ($blockReasons.Count -eq 0) {
        Reset-CompactNudge
        exit 0
    }
```

Fail-open `catch` block:

```powershell
} catch {
    Write-Host "[HOOK ERROR] pre-compact-check.ps1 failed unexpectedly. Proceeding in fails-open mode."
    try { Add-Content ".pmb-hook-errors.log" "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] [HOOK] pre-compact-check.ps1: $_" -ErrorAction SilentlyContinue } catch { Write-Verbose "Could not write .pmb-hook-errors.log; ignoring." }
    Reset-CompactNudge
    exit 0
}
```

This third site is genuinely separate from the `.sh` version (which has no equivalent fail-open branch) — see the spec's Reset section for why both still correctly mean "compaction proceeds." Note `$script:SessionId` was captured *before* entering the main `try` block specifically so it's still available inside this `catch` block if the main body throws.

- [ ] **Step 3: Manual verification, including cross-session isolation**

```powershell
cd "C:\Users\Mizzo\Claude\Personal-Memory-Bank"
New-Item -ItemType Directory -Force -Path "$env:TEMP\pmb-precompact-ps-test\memory-bank" | Out-Null
Set-Content "$env:TEMP\pmb-precompact-ps-test\memory-bank\activeContext.md" @"
# Active Context
This is a substantive line of session state that is comfortably over twenty characters.
This is a second substantive line of session state, also well over the threshold length.
This is a third substantive line of session state, likewise over the threshold length.
"@
$today = Get-Date -Format 'yyyy-MM-dd'
Set-Content "$env:TEMP\pmb-precompact-ps-test\memory-bank\progress.md" "# Progress`n`n## $today -- did some work`n"
Set-Content "$env:TEMP\pmb-precompact-ps-test\.pmb-compact-nudge-mine" "next_nudge_at=999999"
Set-Content "$env:TEMP\pmb-precompact-ps-test\.pmb-compact-nudge-other" "next_nudge_at=888888"
Push-Location "$env:TEMP\pmb-precompact-ps-test"
'{"session_id":"mine"}' | pwsh -NonInteractive -File "C:\Users\Mizzo\Claude\Personal-Memory-Bank\scripts\pre-compact-check.ps1"
$mineGone = -not (Test-Path ".pmb-compact-nudge-mine")
$otherStillThere = Test-Path ".pmb-compact-nudge-other"
Pop-Location
Write-Host "Own state file deleted: $mineGone / Other session's file untouched: $otherStillThere"
```

Expected: exit 0, `Own state file deleted: True / Other session's file untouched: True`.

- [ ] **Step 4: Commit**

```bash
git add scripts/pre-compact-check.ps1
git commit -m "feat: reset this session's own .pmb-compact-nudge-<session_id> on pre-compact-check.ps1's 3 exit-0 paths"
```

---

### Task 9: `templates/scripts/` mirrors for `pre-compact-check`

**Files:**
- Modify: `templates/scripts/pre-compact-check.sh`, `templates/scripts/pre-compact-check.ps1`

- [ ] **Step 1: Apply the identical edits from Tasks 7 and 8**

Apply the same stdin-parsing and reset-call additions (Task 7 Step 3, Task 8 Steps 1-2) to the `templates/scripts/` copies.

- [ ] **Step 2: Confirm byte-identity**

```bash
diff scripts/pre-compact-check.sh templates/scripts/pre-compact-check.sh && echo "IDENTICAL"
diff scripts/pre-compact-check.ps1 templates/scripts/pre-compact-check.ps1 && echo "IDENTICAL"
```

- [ ] **Step 3: Commit**

```bash
git add templates/scripts/pre-compact-check.sh templates/scripts/pre-compact-check.ps1
git commit -m "feat: mirror pre-compact-check reset logic into templates/scripts/"
```

---

### Task 10: `.gitignore` entry

**Files:**
- Modify: `.gitignore`

- [ ] **Step 1: Add the entry**

Add a line near the existing `.pmb-delegation-depth`/`.pmb-hook-errors.log` entries (find them first: `grep -n "\.pmb-" .gitignore`). A wildcard, not a literal filename, since the state file is now suffixed per session:

```
.pmb-compact-nudge-*
```

- [ ] **Step 2: Verify**

```bash
git check-ignore -v .pmb-compact-nudge-some-session-id
```

Expected: prints the `.gitignore` line that matched.

- [ ] **Step 3: Commit**

```bash
git add .gitignore
git commit -m "chore: gitignore .pmb-compact-nudge-* per-session state files"
```

---

### Task 11: Document constants in `standards/PERFORMANCE-BUDGET.md`

**Files:**
- Modify: `standards/PERFORMANCE-BUDGET.md`

- [ ] **Step 1: Read the file's existing agent-spawn budget entry for format**

```bash
grep -n -B2 -A2 "BUDGET_LIMIT" standards/PERFORMANCE-BUDGET.md
```

- [ ] **Step 2: Add a matching entry**

In the same style/section, add:

```markdown
**Compact/clear nudge thresholds** (`scripts/compact-nudge-check.sh`/`.ps1`): `FIRST_THRESHOLD=400000`
bytes (~400 KB), `RENUDGE_INTERVAL=150000` bytes (~150 KB), tracked per session
(`.pmb-compact-nudge-<session_id>`). Estimates, not measurements — back-of-envelope from a ~200K-token
context window at 65% (`CLAUDE_AUTOCOMPACT_PCT_OVERRIDE`), ~4 characters/token, plus allowance for
JSON transcript overhead. Calibrate against real observed transcript sizes once this hook has run
across real sessions; see `docs/superpowers/specs/2026-09-21-compact-nudge-hook-design.md`.
```

- [ ] **Step 3: Commit**

```bash
git add standards/PERFORMANCE-BUDGET.md
git commit -m "docs: document compact-nudge threshold constants in PERFORMANCE-BUDGET.md"
```

---

### Task 12: New hook entry in `docs/HOOKS-GUIDE.md`

**Files:**
- Modify: `docs/HOOKS-GUIDE.md`
- Modify: `templates/docs/HOOKS-GUIDE.md`

- [ ] **Step 1: Add a new numbered entry**

Following the existing format (see entries 1-9 in the "Default Hooks in This Standard" section), add entry 10 after the Stale Review-Marker Warning entry:

```markdown
### 10. Compact/Clear Nudge (`UserPromptSubmit`)

Fires once per user turn, before that turn's tool calls begin. Reads `transcript_path` and
`session_id` from the hook payload, compares the transcript file's byte size against an escalating
threshold stored in `.pmb-compact-nudge-<session_id>` (gitignored, one file per session — see below
for why), and prints an advisory once crossed — recommending `/compact` at a natural boundary or
`/clear` if switching to unrelated work. Fires once per crossing, then pushes the threshold forward by
`RENUDGE_INTERVAL`; never fires on every turn once past the first threshold. Implemented in
`scripts/compact-nudge-check.ps1` and `scripts/compact-nudge-check.sh`.

Advisory only — never blocks a prompt. Fails open on any error (missing `transcript_path`, missing
`session_id`, unreadable file, malformed state file), logging to `.pmb-hook-errors.log`.

**Why per-session, not one shared file:** `.claude/settings.json` hooks fire for every Claude Code
session rooted in the same directory, not just the session that wired them — confirmed live when a
diagnostic hook built during this feature's own design fired for a concurrent peer session and
captured its payload instead. A single shared state file would let one session's transcript size set
the escalation threshold an unrelated session's turns get compared against.

**Reset:** `pre-compact-check.ps1`/`.sh` deletes `.pmb-compact-nudge-<session_id>` — only the
compacting session's own file — at each of its exit-0 paths (2 in `.sh`, 3 in `.ps1`, including the
`.ps1` fail-open `catch` branch). The counter resets only when compaction actually proceeds, never
when the gate blocks it, and never touches another session's file. `/clear` has no corresponding hook
event, so the counter does not reset on a manual `/clear`; this is an accepted, documented limitation
(worst case: one stale advisory shortly after a `/clear`).

Full design and rationale: `docs/superpowers/specs/2026-09-21-compact-nudge-hook-design.md`.
```

- [ ] **Step 2: Mirror into `templates/docs/HOOKS-GUIDE.md`**

Per that file's own sync note at the top ("a manually-trimmed copy... PMB's own postmortem/bug-history prose removed, everything else kept"), add the same entry but trim the "confirmed live when a diagnostic hook..." incident sentence (PMB-specific postmortem narrative) while keeping the structural "why per-session" reasoning that follows it.

- [ ] **Step 3: Commit**

```bash
git add docs/HOOKS-GUIDE.md templates/docs/HOOKS-GUIDE.md
git commit -m "docs: add compact-nudge hook entry to HOOKS-GUIDE.md"
```

---

### Task 13: Calibrate thresholds against the real spike data

**Files:**
- Modify: `standards/PERFORMANCE-BUDGET.md`, `scripts/compact-nudge-check.sh`, `scripts/compact-nudge-check.ps1` (+ `templates/` mirrors), only if the spike data warrants a change

- [ ] **Step 1: Compare Task 2's captured transcript size against the estimate**

```bash
wc -c "$(cat /tmp/pmb-pre-compact-path.txt 2>/dev/null || echo /dev/null)" 2>/dev/null
```

Cross-reference against `CLAUDE_AUTOCOMPACT_PCT_OVERRIDE=65` in `.claude/settings.json` and the session's approximate context usage at the point `/compact` was run in Task 2, to sanity-check whether `FIRST_THRESHOLD=400000` is a reasonable checkpoint meaningfully below the 65% auto-compact line, or wildly off.

- [ ] **Step 2: Adjust if warranted**

If the real data shows the estimate is off by a large factor, update `FIRST_THRESHOLD`/`RENUDGE_INTERVAL` consistently across `scripts/compact-nudge-check.sh`, `scripts/compact-nudge-check.ps1`, both `templates/scripts/` mirrors, and the documented values in `standards/PERFORMANCE-BUDGET.md`. Re-run `tests/test-compact-nudge-check.sh` after any change — its test data (450000/610000/500000 byte fixtures) assumes the original defaults and needs matching updates if the constants move.

If the estimate looks reasonable, leave the values as shipped and note in `standards/PERFORMANCE-BUDGET.md` that they were spot-checked against one real session's data point on today's date.

- [ ] **Step 3: Final full test run**

```bash
bash tests/test-compact-nudge-check.sh
bash tests/test-pre-compact-check.sh
```

Expected: both suites fully pass.

- [ ] **Step 4: Commit**

```bash
git add -A
git commit -m "chore: calibrate compact-nudge thresholds against real session data"
```

(Skip this commit if Step 2 made no changes — nothing to commit.)

---

## Notes for the executing agent

- This repo gates every `git commit`/`git push` behind a diff-bound review marker (`.claude/.code-review-ok` / `.claude/.change-review-ok`), written only by `/code-review`'s or `/change-review`'s opposition step. The `git commit` steps above are written the way `writing-plans` template steps normally look; in practice each will need a review pass run first, per this repo's own `standards/WORKFLOW.md` and `docs/HOOKS-GUIDE.md` — that process is not re-specified here since it's a repo-wide mechanism, not specific to this feature.
- Task 2 requires live interaction within an actual Claude Code session (sending real messages, running a real `/compact`) — it cannot be executed by a fully unattended subagent with no way to prompt the operator. If running via `subagent-driven-development`, flag this explicitly rather than having a subagent silently skip or fabricate the spike's findings. Task 1 is already done (see its own section).
- **General caution for whoever executes this plan:** `.claude/settings.json` in this repo is shared by every Claude Code session rooted in this directory. Any temporary diagnostic hook wired in for testing purposes (as Task 2 does) will fire for concurrent sessions too, and may capture their private prompt content — clean it up promptly and never commit a captured payload file. This was discovered the hard way during this plan's own design, not anticipated in advance.
