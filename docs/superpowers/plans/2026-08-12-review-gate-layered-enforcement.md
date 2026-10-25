# Review-Gate Layered Enforcement Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Close the structural review-gate bypass (a user-typed `git commit`/`git push` is invisible to the `PreToolUse` hook) by promoting the real git hooks (`.githooks/pre-commit`/`pre-push`) to sole marker-consumer, downgrading the Claude Code hook to a non-consuming peek, adding a durable `docs/review-log/` record + invocation-start log, and a new CI containment check as the only actually-unbypassable backstop.

**Architecture:** Four pieces per the spec — Layer 1 (CC `PreToolUse` hook, downgraded to peek), Layer 2 (real git hooks, promoted to sole consumer), Layer 3 (new CI required check), and a durable review-log + invocation-start log that Layer 3 reads. Marker-peek/consume logic is deduplicated into `_review-gate-lib.sh`/`.ps1` following this repo's existing lib-dedup precedent.

**Tech Stack:** POSIX sh + PowerShell (dual-shell hook parity), bash test suites (`tests/helpers/assert.sh`), GitHub Actions (`.github/workflows/pmb-health.yml`).

**Spec:** `docs/superpowers/specs/2026-08-12-review-gate-layered-enforcement-design.md`

---

## Design note carried into this plan (not in the spec verbatim — resolves an underspecified detail)

The spec says each review-log entry records "the exact commit SHA that was HEAD when the review ran" — i.e. the **parent** commit, since `/code-review` normally runs pre-commit (the reviewed commit doesn't exist yet). For the CI containment check (Task 13) this plan implements per-commit coverage for a `*-code-review.md` entry as: `entry.head-sha == C^` (C's parent) **and** `entry.diff-hash == sha256(git diff C^ C)` — i.e. the entry's recorded parent-anchor and the diff it reviewed both match commit C exactly. This is stricter than a bare SHA-equality check (a bare check couldn't tell whether a coincidentally-matching parent commit actually reviewed the same diff) and is the literal, computable reading of "exact commit SHA that was HEAD when the review ran." For `*-change-review.md` entries, head-sha is a real, already-committed tip (change-review runs on an existing branch, pre-push), so the spec's `git merge-base --is-ancestor <commit> <recorded-sha>` applies directly, unmodified.

**Three more gaps found during this plan's self-review, between the spec's own prose and its Files Changed table — resolved here, not silently:**

1. **File location for the new commit-gate script.** The Files Changed table lists `.githooks/pre-commit-check.sh` / `.ps1`, but the spec's "Component: git-hook relocation" prose says to add these files "matching `pre-push`'s existing shape" — and `pre-push`'s actual shape (confirmed by reading `.githooks/pre-push`) is a thin delegator in `.githooks/` calling into `scripts/pre-push-check.ps1`/`.sh`. This plan follows the prose (the more specific, verified-against-real-code instruction) and puts the new files at `scripts/pre-commit-check.sh`/`.ps1` (Task 3), not `.githooks/`. The table's path appears to be a drafting slip, not a deliberate divergence from the pre-push precedent it explicitly cites.
2. **New shared helpers in `_review-gate-lib.sh`/`.ps1` are not in the Files Changed table**, but the peek-vs-consume split (Layer 1 peeks, Layer 2 consumes) requires the logic to live somewhere, and the spec's own prose says the new hooks should "reuse its existing hash functions... same dedup pattern this repo already established." Adding `peek_marker`/`consume_marker` (and PowerShell equivalents) to the shared lib, rather than duplicating the atomic-mv logic across two new files, is the direct application of that stated dedup principle. Task 1.
3. **`scripts/mb.sh`/`mb.ps1` registration is entirely absent from the Files Changed table.** Without it, the new `scripts/pre-commit-check.sh`/`.ps1` files would never be distributed by `mb init`/`mb upgrade` — the exact class of gap the spec's own Problem section discusses (`review-reminders*.sh`/`.ps1` themselves were once missing from these same arrays). Task 7 fills this necessary, spec-implied gap.

**Six more real gaps found by an independent pre-implementation review (fresh agent, no context from writing this plan) — fixed here, not silently:**

1. **`set -e` would kill Task 5's push-gate fallback in the exact scenario it exists to handle** (`scripts/pre-push-check.sh` runs under `set -euo pipefail`; the original `EXPECTED_PUSH_HASH=$(diff_hash origin/main...HEAD); PUSH_RC=$?` pattern is safe in `review-reminders.sh` — plain `sh`, no errexit — but not here). Fixed by checking `origin/main`'s existence before choosing which diff to hash, instead of branching on `diff_hash`'s exit code after the fact.
2. **Task 9 missed a pre-existing assertion at `tests/test-review-reminders.sh:184`** (the worktree-root negative control) that Task 2's peek-only downgrade breaks — it proved correct root resolution via `consume_marker`'s file-removal side effect, which no longer happens under peek-only Layer 1. Fixed by testing `resolve_cd_root()` directly instead of inferring it from a side effect that no longer exists.
3. **Task 7's `docs/review-log/README.md` distribution fix was a no-op on both shells** — no task ever created the `templates/docs/review-log/README.md` template source `mb.sh`'s `ADVISORY_CREATE` needs, and the described `mb.ps1` fix (find and edit an "`ADVISORY_CREATE`-equivalent array") doesn't exist — `mb.ps1` auto-discovers flat files under `templates/docs/` and is non-recursive, so it would never see a nested file even once created. Fixed: Task 12 now creates the template mirror alongside the live file; Task 7 adds a second, narrowly-scoped `Get-TemplateDirFile` call for the `docs/review-log` subdirectory instead of inventing a hardcoded array.
4. **PowerShell path-separator bug in the new Task 3/Task 5 code** — `Join-Path` calls used backslash child segments (`"scripts\_review-gate-lib.ps1"`), which only resolve correctly on Windows; `.githooks/pre-commit`/`pre-push` prefer `pwsh` whenever present regardless of OS, and GitHub Actions `ubuntu-latest` runners ship `pwsh`, so this would have silently broken Layer 2 there. Fixed to forward slashes, matching the other `Join-Path` calls in the same new code.
5. **Off-by-one renumbering bug in Task 10** (`.claude/commands/code-review.md`) — the trailing "Return to the orchestrator" step was renumbered 4→6, skipping 5 entirely; the identical edit in Task 11 (`change-review.md`) correctly does 4→5. Fixed to match Task 11's arithmetic.
6. **No test coverage existed for Task 5's push-gate change at all** — Task 8's new Layer 2 suite only exercised `pre-commit-check.sh`. Added a parallel push-gate test block, including a dedicated regression test for gap #1 above (a valid marker on a first push, before `origin/main` is locally resolvable, must allow the push rather than crash).

**Two more, judged Low severity and handled accordingly:** `scripts/check-review-gate-lib-presence.sh` (used by `mb doctor` and CI) didn't cover the two new Layer 2 files' lib dependency — fixed in Task 5. The spec's Files Changed table attributes the push-side marker logic to `.githooks/pre-push` where this plan (correctly) puts it in `scripts/pre-push-check.sh` instead, the same category of drafting imprecision as gap #1 above but never called out for this row — noted here for completeness; no code changes needed since the plan already puts it in the right place.

---

### Task 1: Shared marker peek/consume helpers in `_review-gate-lib.sh` / `.ps1`

**Files:**
- Modify: `scripts/_review-gate-lib.sh`
- Modify: `scripts/_review-gate-lib.ps1`
- Test: `tests/test-review-gate-lib.sh`

**Why this task first:** Layer 1's downgrade (Task 2) and Layer 2's new consumption logic (Tasks 3, 5) both need these functions — building them first means later tasks call real, tested code instead of duplicating the atomic-mv/peek logic inline.

- [ ] **Step 1: Read the existing test suite to match its structure**

Run: `cat tests/test-review-gate-lib.sh | head -40`
This confirms the existing test helpers (`assert_contains`, `assert_equals`, etc.) and file layout to match.

- [ ] **Step 2: Add `peek_marker()` and `consume_marker()` to `scripts/_review-gate-lib.sh`**

Append to the end of `scripts/_review-gate-lib.sh` (after `resolve_cd_root()`):

```sh

# WHY these two functions live here, not in review-reminders.sh/pre-commit-check.sh
# individually: peek_marker() is called from both the commit and push branches of
# review-reminders.sh (Layer 1, now non-consuming); consume_marker() is called from both
# pre-commit-check.sh and pre-push-check.sh (Layer 2, the sole consumer now). Two call
# sites each, same dedup rationale as diff_hash()/sha256_file() above.
#
# WHY peek_marker() never touches the file: Layer 1 (the CC PreToolUse hook) fires before
# the agent's own Bash tool call runs, giving fast feedback -- but it must never be the
# thing that actually consumes the marker, since a user-run command never reaches Layer 1
# at all. If Layer 1 still consumed, an agent-run commit blocked by a LATER check (e.g. a
# separate PreToolUse hook denying for an unrelated reason) would burn the marker before
# Layer 2 (the real git hook) ever got a chance to be the authoritative gate.
peek_marker() {
    marker="$1"
    [ -f "$marker" ] || { printf ''; return 1; }
    cat "$marker" 2>/dev/null | tr -d '[:space:]'
}

# WHY consume_marker() is the atomic-mv version (unchanged logic from review-reminders.sh's
# prior inline consume_marker): Layer 2 is the sole consumer now, so this is the only place
# the atomic rename (TOCTOU-safe) needs to happen. Prints the claimed marker's content on
# success (rename succeeded), empty string if the marker didn't exist -- caller compares
# against the expected hash. Consumes whether or not the content matches, matching today's
# established "always consume, deny either way" behavior (see review-reminders.sh's own WHY
# comment for the security rationale: a stale marker from a changed diff shouldn't linger).
consume_marker() {
    marker="$1"
    claimed="$marker.claimed.$$"
    if ! mv "$marker" "$claimed" 2>/dev/null; then
        printf ''
        return 1
    fi
    content=$(cat "$claimed" 2>/dev/null | tr -d '[:space:]')
    rm -f "$claimed"
    printf '%s' "$content"
}
```

- [ ] **Step 3: Add `Test-MarkerPeek` and `Invoke-ConsumeMarker` to `scripts/_review-gate-lib.ps1`**

Append to the end of `scripts/_review-gate-lib.ps1` (after `Get-PushDiffHash`):

```powershell

# WHY these two functions: same dedup rationale as Get-CommitDiffHash/Get-PushDiffHash
# above -- Test-MarkerPeek is called from both review-reminders.ps1 branches (Layer 1, now
# non-consuming); Invoke-ConsumeMarker is called from both pre-commit-check.ps1 and
# pre-push-check.ps1 (Layer 2, the sole consumer). See _review-gate-lib.sh's matching
# comment for why Layer 1 must never consume.
function Test-MarkerPeek {
    param([string]$Marker, [string]$ExpectedHash)
    if (-not (Test-Path $Marker)) { return $false }
    $content = $null
    try { $content = (Get-Content $Marker -Raw -ErrorAction Stop).Trim() } catch { Write-Verbose "Could not read marker '$Marker'; treating as absent." }
    return ($content -and $content -eq $ExpectedHash)
}

function Invoke-ConsumeMarker {
    param([string]$Marker, [string]$ExpectedHash)
    $claimed = "$Marker.claimed"
    try {
        Move-Item -Path $Marker -Destination $claimed -Force -ErrorAction Stop
    } catch {
        return $false
    }
    $content = $null
    try { $content = (Get-Content $claimed -Raw -ErrorAction Stop).Trim() } catch { Write-Verbose "Could not read consumed marker '$claimed'; treating as empty." }
    Remove-Item $claimed -Force -ErrorAction SilentlyContinue
    return ($content -and $content -eq $ExpectedHash)
}
```

- [ ] **Step 4: Write failing tests for the new functions**

Append to `tests/test-review-gate-lib.sh` (find the end of the file first with `tail -20 tests/test-review-gate-lib.sh` to match its exact closing pattern, then insert before `print_summary`):

```sh
# ── peek_marker(): reads without consuming ──────────────────────────────────────────────────
echo ""
echo "--- peek_marker: reads marker content without deleting it ---"
TMPDIR_PEEK="$(mktemp -d 2>/dev/null || mktemp -d -t mb-peek-test)"
trap 'rm -rf "$TMPDIR_PEEK"' EXIT
printf 'abc123' > "$TMPDIR_PEEK/marker"
. "$REPO_ROOT/scripts/_review-gate-lib.sh"
result=$(peek_marker "$TMPDIR_PEEK/marker")
assert_equals "abc123" "$result" "peek_marker returns the marker's content"
assert_file_exists "$TMPDIR_PEEK/marker" "peek_marker does not delete the marker file"

echo ""
echo "--- peek_marker: returns empty string for a missing marker ---"
result=$(peek_marker "$TMPDIR_PEEK/does-not-exist")
assert_equals "" "$result" "peek_marker returns empty string when the marker is absent"

# ── consume_marker(): atomic claim, removes the file ────────────────────────────────────────
echo ""
echo "--- consume_marker: reads content and removes the marker ---"
printf 'def456' > "$TMPDIR_PEEK/marker2"
result=$(consume_marker "$TMPDIR_PEEK/marker2")
assert_equals "def456" "$result" "consume_marker returns the marker's content"
assert_file_not_exists "$TMPDIR_PEEK/marker2" "consume_marker removes the marker file"

echo ""
echo "--- consume_marker: returns empty string for a missing marker ---"
result=$(consume_marker "$TMPDIR_PEEK/does-not-exist")
assert_equals "" "$result" "consume_marker returns empty string when the marker is absent"

rm -rf "$TMPDIR_PEEK"
trap - EXIT
```

Check `tests/helpers/assert.sh` for `assert_equals` — if it doesn't exist, run:
```
grep -n "^assert_" tests/helpers/assert.sh
```
If `assert_equals` is missing, add it to `tests/helpers/assert.sh` following the file's existing pattern (mirror `assert_contains`'s structure but with `[ "$1" = "$2" ]`).

- [ ] **Step 5: Run the test to verify it fails (before PowerShell parity exists, bash-only functions should already pass since Step 2 already added them — verify the NEW assertions pass)**

Run: `bash tests/test-review-gate-lib.sh 2>&1 | tail -20`
Expected: all `peek_marker`/`consume_marker` assertions PASS (Step 2 already implemented them). If any fail, fix `_review-gate-lib.sh` before continuing.

- [ ] **Step 6: Add matching PowerShell tests**

Find `tests/test-review-gate-lib.sh`'s existing `pwsh` guard pattern (`if command -v pwsh`) and add a parallel block testing `Test-MarkerPeek`/`Invoke-ConsumeMarker` via `pwsh -NonInteractive -Command`. Insert after the bash block from Step 4:

```sh
if command -v pwsh >/dev/null 2>&1; then
  echo ""
  echo "--- PowerShell parity: Test-MarkerPeek / Invoke-ConsumeMarker ---"
  TMPDIR_PEEK_PS="$(mktemp -d 2>/dev/null || mktemp -d -t mb-peek-ps-test)"
  printf 'abc123' > "$TMPDIR_PEEK_PS/marker"
  result=$(pwsh -NonInteractive -Command ". '$REPO_ROOT/scripts/_review-gate-lib.ps1'; Test-MarkerPeek -Marker '$TMPDIR_PEEK_PS/marker' -ExpectedHash 'abc123'")
  assert_contains "$result" "True" "Test-MarkerPeek returns true for a matching marker (PowerShell)"
  assert_file_exists "$TMPDIR_PEEK_PS/marker" "Test-MarkerPeek does not delete the marker file (PowerShell)"

  result=$(pwsh -NonInteractive -Command ". '$REPO_ROOT/scripts/_review-gate-lib.ps1'; Invoke-ConsumeMarker -Marker '$TMPDIR_PEEK_PS/marker' -ExpectedHash 'abc123'")
  assert_contains "$result" "True" "Invoke-ConsumeMarker returns true for a matching marker (PowerShell)"
  assert_file_not_exists "$TMPDIR_PEEK_PS/marker" "Invoke-ConsumeMarker removes the marker file (PowerShell)"

  rm -rf "$TMPDIR_PEEK_PS"
else
  echo ""
  echo "--- PowerShell parity tests: SKIPPED (pwsh not installed) ---"
fi
```

- [ ] **Step 7: Run full test suite**

Run: `bash tests/test-review-gate-lib.sh`
Expected: all tests pass (0 failures in summary).

- [ ] **Step 8: Commit**

```bash
git add scripts/_review-gate-lib.sh scripts/_review-gate-lib.ps1 tests/test-review-gate-lib.sh tests/helpers/assert.sh
git commit -m "feat: add shared peek/consume marker helpers to _review-gate-lib"
```

---

### Task 2: Downgrade `review-reminders.sh` / `.ps1` to peek-only (Layer 1)

**Files:**
- Modify: `scripts/review-reminders.sh`
- Modify: `scripts/review-reminders.ps1`

**Why the commit and push branches change differently:** per the spec, pre-commit needs no reissue-on-failure companion (a git hook exiting 0 means the commit essentially always proceeds), so the commit branch's presha write (used only by `review-reminders-post.sh`'s reissue logic) becomes dead weight and is removed. The push branch keeps its presha write unchanged — `review-reminders-post.sh`'s existing reissue-on-failed-push logic still has a real job (Layer 2 now consumes the marker; if the push still fails after Layer 2 exits 0, the existing PostToolUse reissue mechanism is what recovers it — see spec's "pre-push — accepted limitation" section).

- [ ] **Step 1: Change the commit branch in `scripts/review-reminders.sh`**

Find this block (currently the `*'git commit'*)` case):
```sh
    *'git commit'*)
        expected=$(diff_hash HEAD)
        marker="$root/.claude/.code-review-ok"
        actual=$(consume_marker "$marker")
        if [ -n "$expected" ] && [ "$actual" = "$expected" ]; then
            presha=$(git rev-parse HEAD 2>/dev/null)
            [ -n "$presha" ] && printf '%s' "$presha" > "$root/.claude/.pending-commit-presha"
        else
            deny "Run /code-review before committing -- it writes a diff-bound review-ok marker this hook checks. If you already reviewed, the working tree changed since then; re-run /code-review."
        fi
        ;;
```

Replace with (peek instead of consume, no presha write since Layer 2's git hook is now the sole consumer and pre-commit needs no reissue):
```sh
    *'git commit'*)
        expected=$(diff_hash HEAD)
        marker="$root/.claude/.code-review-ok"
        actual=$(peek_marker "$marker")
        if [ -z "$expected" ] || [ "$actual" != "$expected" ]; then
            deny "Run /code-review before committing -- it writes a diff-bound review-ok marker this hook checks. If you already reviewed, the working tree changed since then; re-run /code-review."
        fi
        ;;
```

- [ ] **Step 2: Change the push branch in `scripts/review-reminders.sh`**

Find:
```sh
    *'git push'*)
        expected=$(diff_hash origin/main...HEAD)
        rc=$?
        if [ "$rc" -ne 0 ]; then
            expected=$(diff_hash HEAD)
        fi
        marker="$root/.claude/.change-review-ok"
        actual=$(consume_marker "$marker")
        if [ -n "$expected" ] && [ "$actual" = "$expected" ]; then
            presha=$(git rev-parse '@{u}' 2>/dev/null)
            [ -n "$presha" ] && printf '%s' "$presha" > "$root/.claude/.pending-push-presha"
        else
            deny "Run /change-review before pushing -- it writes a diff-bound review-ok marker this hook checks. If you already reviewed, the diff changed since then; re-run /change-review."
        fi
        ;;
```

Replace with (peek instead of consume; presha write is KEPT — still needed by `review-reminders-post.sh`'s reissue logic):
```sh
    *'git push'*)
        expected=$(diff_hash origin/main...HEAD)
        rc=$?
        if [ "$rc" -ne 0 ]; then
            expected=$(diff_hash HEAD)
        fi
        marker="$root/.claude/.change-review-ok"
        actual=$(peek_marker "$marker")
        if [ -n "$expected" ] && [ "$actual" = "$expected" ]; then
            presha=$(git rev-parse '@{u}' 2>/dev/null)
            [ -n "$presha" ] && printf '%s' "$presha" > "$root/.claude/.pending-push-presha"
        else
            deny "Run /change-review before pushing -- it writes a diff-bound review-ok marker this hook checks. If you already reviewed, the diff changed since then; re-run /change-review."
        fi
        ;;
```

- [ ] **Step 3: Same two changes in `scripts/review-reminders.ps1`**

Find:
```powershell
if ($cmd -match 'git\s+commit\b') {
    $expected = Get-CommitDiffHash
    $marker = Join-Path $root '.claude/.code-review-ok'
    if (Test-AndConsumeMarker $marker $expected) {
        $preSha = git rev-parse HEAD 2>$null
        if ($preSha) { $preSha | Set-Content (Join-Path $root '.claude/.pending-commit-presha') }
    } else {
        Deny "Run /code-review before committing -- it writes a diff-bound review-ok marker this hook checks. If you already reviewed, the working tree changed since then; re-run /code-review."
    }
} elseif ($cmd -match 'git\s+push\b') {
    $expected = Get-PushDiffHash
    $marker = Join-Path $root '.claude/.change-review-ok'
    if (Test-AndConsumeMarker $marker $expected) {
        $preSha = git rev-parse '@{u}' 2>$null
        if ($preSha) { $preSha | Set-Content (Join-Path $root '.claude/.pending-push-presha') }
    } else {
        Deny "Run /change-review before pushing -- it writes a diff-bound review-ok marker this hook checks. If you already reviewed, the diff changed since then; re-run /change-review."
    }
} elseif ($cmd -match 'gh\s+pr\s+merge\b') {
```

Replace with:
```powershell
if ($cmd -match 'git\s+commit\b') {
    $expected = Get-CommitDiffHash
    $marker = Join-Path $root '.claude/.code-review-ok'
    if (-not (Test-MarkerPeek $marker $expected)) {
        Deny "Run /code-review before committing -- it writes a diff-bound review-ok marker this hook checks. If you already reviewed, the working tree changed since then; re-run /code-review."
    }
} elseif ($cmd -match 'git\s+push\b') {
    $expected = Get-PushDiffHash
    $marker = Join-Path $root '.claude/.change-review-ok'
    if (Test-MarkerPeek $marker $expected) {
        $preSha = git rev-parse '@{u}' 2>$null
        if ($preSha) { $preSha | Set-Content (Join-Path $root '.claude/.pending-push-presha') }
    } else {
        Deny "Run /change-review before pushing -- it writes a diff-bound review-ok marker this hook checks. If you already reviewed, the diff changed since then; re-run /change-review."
    }
} elseif ($cmd -match 'gh\s+pr\s+merge\b') {
```

- [ ] **Step 4: Remove the now-unused `Test-AndConsumeMarker` function from `review-reminders.ps1`**

Find and delete this function (no longer called from this file; `Invoke-ConsumeMarker` in `_review-gate-lib.ps1` from Task 1 replaces its Layer-2 use case):
```powershell
function Test-AndConsumeMarker {
    param([string]$Marker, [string]$ExpectedHash)
    $claimed = "$Marker.claimed"
    try {
        Move-Item -Path $Marker -Destination $claimed -Force -ErrorAction Stop
    } catch {
        return $false
    }
    $content = $null
    try { $content = (Get-Content $claimed -Raw -ErrorAction Stop).Trim() } catch { Write-Verbose "Could not read consumed marker '$claimed'; treating as empty." }
    Remove-Item $claimed -Force -ErrorAction SilentlyContinue
    return ($content -and $content -eq $ExpectedHash)
}
```

- [ ] **Step 5: Remove the now-unused `consume_marker()` function from `review-reminders.sh`**

Find and delete (same reasoning — `consume_marker` now lives in `_review-gate-lib.sh` from Task 1):
```sh
consume_marker() {
    marker="$1"
    claimed="$marker.claimed.$$"
    if ! mv "$marker" "$claimed" 2>/dev/null; then
        printf ''
        return 1
    fi
    content=$(cat "$claimed" 2>/dev/null | tr -d '[:space:]')
    rm -f "$claimed"
    printf '%s' "$content"
}
```

- [ ] **Step 6: Update the file header comments in both files to describe peek-only behavior**

In `scripts/review-reminders.sh`, find the header comment block's line:
```
# WHY the marker is consumed via an atomic rename (mv), not a separate [ -f ] + rm: check-
```
Replace the whole paragraph (from `# WHY the marker is consumed...` through the blank line after it) with:
```
# WHY this hook only PEEKS at the marker now, never consumes it: this is Layer 1 of a
# 3-layer design (see docs/superpowers/specs/2026-08-12-review-gate-layered-enforcement-design.md).
# Layer 2 (the real git hooks, .githooks/pre-commit and pre-push via scripts/pre-commit-check.sh
# and pre-push-check.sh) is the sole authoritative marker consumer now, because it fires
# regardless of who runs git commit/push -- unlike this hook, which only ever sees the
# agent's own Bash tool calls. This hook still peeks and denies early for fast feedback
# (no point letting the agent's Bash call proceed to the git hook layer if the marker
# obviously doesn't match), but it must never be the thing that actually claims the marker.
#
```

Apply the equivalent edit to `scripts/review-reminders.ps1`'s matching header paragraph (the one starting `# WHY the marker is consumed via an atomic rename (Move-Item)`).

- [ ] **Step 7: Commit**

```bash
git add scripts/review-reminders.sh scripts/review-reminders.ps1
git commit -m "feat: downgrade review-reminders (Layer 1) to non-consuming peek"
```

(Full test coverage for this change happens in Task 9, after Layer 2 exists — a peek-only Layer 1 with no Layer 2 yet would fail today's `test-review-reminders.sh` "marker is single-use" test, since nothing consumes it. That's expected and fixed in Task 9.)

---

### Task 3: `scripts/pre-commit-check.sh` / `.ps1` — new Layer 2 commit gate

**Files:**
- Create: `scripts/pre-commit-check.sh`
- Create: `scripts/pre-commit-check.ps1`

- [ ] **Step 1: Write `scripts/pre-commit-check.sh`**

```sh
#!/usr/bin/env sh
# scripts/pre-commit-check.sh — pre-commit git hook logic (POSIX/bash fallback).
# Delegated to by .githooks/pre-commit. Runs the pre-existing handoff.md/autocompact
# checks first, then the review-gate marker consumption LAST.
#
# WHY marker consumption runs last, after the handoff.md and autocompact checks: consuming
# the marker and then failing a later check would burn a valid review marker for a commit
# that never actually happened. Ordering this last means every earlier check has already
# passed (or only warned) by the time the marker is touched.
#
# WHY the empty-diff guard before consumption: without it, a commit with nothing actually
# staged would let this hook consume the marker and then have git itself refuse the commit
# ("nothing to commit") -- wasting a valid marker on a no-op and forcing an unnecessary
# re-review for the next real commit.
#
# WHY this is Layer 2, the sole authoritative marker consumer: this is a real git hook
# (invoked via core.hooksPath), so it fires for a commit typed directly into the user's own
# terminal exactly the same as one run through the agent's Bash tool -- closing the
# structural bypass that Layer 1 (review-reminders.sh, a Claude Code PreToolUse hook) can
# never close on its own. See docs/superpowers/specs/2026-08-12-review-gate-layered-enforcement-design.md.
#
# diff_hash()/sha256_file()/consume_marker() are defined in _review-gate-lib.sh -- see that
# file for their WHY. Fails open (skips the gate) if the lib is missing or unreadable,
# matching review-reminders.sh's established fail-open convention.
. "$(dirname "$0")/_review-gate-lib.sh" 2>/dev/null || exit 0

if git diff --cached --name-only | grep -q "^handoff\.md$"; then
  echo "ERROR: handoff.md is staged for commit. This file is ephemeral and must not be committed."
  echo "Remove it from staging: git rm --cached handoff.md"
  exit 1
fi

if [ -f ".claude/settings.json" ] && ! grep -q "CLAUDE_AUTOCOMPACT_PCT_OVERRIDE" .claude/settings.json; then
  echo "WARNING: CLAUDE_AUTOCOMPACT_PCT_OVERRIDE not found in .claude/settings.json."
  echo "Token budget auto-compaction may not be configured. Add it to avoid mid-task context loss."
fi

root=$(git rev-parse --show-toplevel 2>/dev/null)
[ -z "$root" ] && exit 0
cd "$root" 2>/dev/null || exit 0

# Empty-diff guard: nothing staged means git itself will refuse the commit ("nothing to
# commit") -- don't burn a valid marker on a no-op.
staged=$(git diff --cached --name-only 2>/dev/null)
[ -z "$staged" ] && exit 0

marker="$root/.claude/.code-review-ok"
expected=$(diff_hash HEAD)
[ -z "$expected" ] && exit 0

actual=$(consume_marker "$marker")
if [ "$actual" != "$expected" ]; then
    echo "ERROR: Run /code-review before committing -- it writes a diff-bound review-ok marker this hook checks."
    echo "If you already reviewed, the working tree changed since then; re-run /code-review."
    exit 1
fi

exit 0
```

- [ ] **Step 2: Make it executable**

Run: `chmod +x scripts/pre-commit-check.sh`

- [ ] **Step 3: Write `scripts/pre-commit-check.ps1`**

```powershell
<#
.SYNOPSIS
    Pre-commit git hook — handoff.md/autocompact checks, then review-gate marker consumption.
.DESCRIPTION
    Delegated to by .githooks/pre-commit. Runs the pre-existing handoff.md/autocompact
    checks first, then the review-gate marker consumption LAST (see WHY in
    pre-commit-check.sh -- same rationale, PowerShell implementation).
    This is Layer 2 of the review-gate design: a real git hook, sole authoritative marker
    consumer, fires regardless of who runs `git commit`.
#>

param()

$ErrorActionPreference = 'Continue'

$staged = git diff --cached --name-only 2>$null
if ($staged -contains "handoff.md") {
    Write-Host "ERROR: handoff.md is staged for commit. This file is ephemeral and must not be committed." -ForegroundColor Red
    Write-Host "Remove it from staging: git rm --cached handoff.md" -ForegroundColor Red
    exit 1
}

if ((Test-Path ".claude/settings.json") -and -not (Select-String -Path ".claude/settings.json" -Pattern "CLAUDE_AUTOCOMPACT_PCT_OVERRIDE" -Quiet)) {
    Write-Host "WARNING: CLAUDE_AUTOCOMPACT_PCT_OVERRIDE not found in .claude/settings.json." -ForegroundColor Yellow
    Write-Host "Token budget auto-compaction may not be configured. Add it to avoid mid-task context loss." -ForegroundColor Yellow
}

try {
    $root = git rev-parse --show-toplevel 2>$null
    if (-not $root) { exit 0 }
    Set-Location $root
    # Forward slash, not backslash: Join-Path concatenates literally, and a backslash is only
    # a separator on Windows -- this hook also runs under non-Windows pwsh (preferred by
    # .githooks/pre-commit regardless of OS, and present on GitHub Actions ubuntu-latest).
    . (Join-Path $root "scripts/_review-gate-lib.ps1")
} catch { exit 0 }

# Empty-diff guard: nothing staged means git itself will refuse the commit -- don't burn a
# valid marker on a no-op.
$staged = git diff --cached --name-only 2>$null
if (-not $staged) { exit 0 }

$marker = Join-Path $root '.claude/.code-review-ok'
$expected = Get-CommitDiffHash
if (-not $expected) { exit 0 }

if (-not (Invoke-ConsumeMarker $marker $expected)) {
    Write-Host "ERROR: Run /code-review before committing -- it writes a diff-bound review-ok marker this hook checks." -ForegroundColor Red
    Write-Host "If you already reviewed, the working tree changed since then; re-run /code-review." -ForegroundColor Red
    exit 1
}

exit 0
```

- [ ] **Step 4: Verify both scripts parse/run standalone (no test suite yet — that's Task 8)**

Run:
```bash
cd /tmp && rm -rf pcc-smoke && mkdir pcc-smoke && cd pcc-smoke
git init -q -b main
git config user.email t@t.com && git config user.name t
echo hi > f.txt && git add f.txt && git commit -q -m init
echo bye >> f.txt && git add f.txt
bash "$OLDPWD/../scripts/pre-commit-check.sh" 2>&1 || true
```
Expected output: `ERROR: Run /code-review before committing...` (no marker present, correct denial) and exit code 1. (Use the actual repo-relative path to `scripts/pre-commit-check.sh` on your machine instead of `$OLDPWD/../scripts` — this is a manual smoke check, not the automated suite.)

- [ ] **Step 5: Commit**

```bash
git add scripts/pre-commit-check.sh scripts/pre-commit-check.ps1
git commit -m "feat: add scripts/pre-commit-check (Layer 2 commit gate)"
```

---

### Task 4: `.githooks/pre-commit` becomes a delegator

**Files:**
- Modify: `.githooks/pre-commit`

- [ ] **Step 1: Rewrite `.githooks/pre-commit` to match `.githooks/pre-push`'s delegator shape**

Replace the entire file content with:
```bash
#!/usr/bin/env bash
# Pre-commit hook — delegates to pre-commit-check.ps1 (Windows) or pre-commit-check.sh (Mac/Linux).
# Installed by: mb init / mb upgrade
# Template source: templates/.githooks/pre-commit

ROOT=$(git rev-parse --show-toplevel 2>/dev/null || pwd)

if command -v pwsh &>/dev/null; then
    pwsh -NonInteractive -File "$ROOT/scripts/pre-commit-check.ps1"
elif command -v powershell &>/dev/null; then
    powershell -NonInteractive -File "$ROOT/scripts/pre-commit-check.ps1"
else
    bash "$ROOT/scripts/pre-commit-check.sh"
fi
```

- [ ] **Step 2: Verify it's still executable**

Run: `ls -la .githooks/pre-commit` — should show `x` permission bits (already executable from before this edit; `git` preserves the mode across a content-only edit, but confirm).
If not executable: `chmod +x .githooks/pre-commit`

- [ ] **Step 3: Live smoke test — a real `git commit` in this repo, no marker present**

Run:
```bash
git status --short
```
If the working tree is clean, skip this step (nothing to test against right now — full live end-to-end coverage happens in Task 8, Testing item 5). If there are uncommitted changes, do NOT run a real commit here — that's covered deliberately in Task 8's test suite, not as an ad hoc step that could interfere with in-progress work.

- [ ] **Step 4: Commit**

```bash
git add .githooks/pre-commit
git commit -m "feat: .githooks/pre-commit becomes a delegator (matches pre-push's shape)"
```

---

### Task 5: Marker consumption in `scripts/pre-push-check.sh` / `.ps1` (Layer 2 push gate)

**Files:**
- Modify: `scripts/pre-push-check.sh`
- Modify: `scripts/pre-push-check.ps1`

- [ ] **Step 1: Add marker consumption to `scripts/pre-push-check.sh`**

Find the final block (Check 7, `mb validate`, ending right before the `echo ""` / `if [ "$FAILED" -ne 0 ]` summary block):
```sh
# Check 7: mb validate (warn if mb available)
if command -v mb &>/dev/null; then
    if ! mb validate &>/dev/null; then
        echo -e "${YELLOW}[WARN] mb validate reported issues — memory bank may be inconsistent:${RESET}"
        mb validate 2>&1 | while IFS= read -r line; do echo "       $line"; done
        echo ""
    else
        echo -e "${GREEN}[OK]   mb validate passed${RESET}"
    fi
else
    echo -e "${GRAY}[SKIP] mb not in PATH — skipping mb validate.${RESET}"
fi

echo ""
if [ "$FAILED" -ne 0 ]; then
```

Insert a new Check 8 between the `mb validate` block and the final summary:
```sh
# Check 7: mb validate (warn if mb available)
if command -v mb &>/dev/null; then
    if ! mb validate &>/dev/null; then
        echo -e "${YELLOW}[WARN] mb validate reported issues — memory bank may be inconsistent:${RESET}"
        mb validate 2>&1 | while IFS= read -r line; do echo "       $line"; done
        echo ""
    else
        echo -e "${GREEN}[OK]   mb validate passed${RESET}"
    fi
else
    echo -e "${GRAY}[SKIP] mb not in PATH — skipping mb validate.${RESET}"
fi

# Check 8: review-gate marker consumption (block) -- Layer 2 of the review-gate design.
# WHY this is the sole authoritative push-gate consumer now: this is a real git hook, fires
# regardless of who runs `git push`, unlike review-reminders.sh (a Claude Code PreToolUse
# hook, which only ever sees the agent's own Bash tool calls -- Layer 1 there now only peeks).
# See docs/superpowers/specs/2026-08-12-review-gate-layered-enforcement-design.md.
#
# WHY the ref-existence check happens BEFORE calling diff_hash, instead of branching on
# diff_hash's own exit code afterward (as review-reminders.sh's equivalent commit/push
# branches safely do): this file runs under `set -euo pipefail` (see the top of this
# script), unlike review-reminders.sh (`#!/usr/bin/env sh`, no errexit). Under set -e, a
# plain `VAR=$(cmd)` assignment where cmd exits non-zero terminates the script immediately --
# reproduced directly with a minimal set -e script. `diff_hash origin/main...HEAD` returns
# non-zero exactly when origin/main doesn't exist (the scenario the HEAD fallback below exists
# to handle), so the fallback line would never execute; deciding the branch up front sidesteps
# set -e entirely instead of relying on a $? check it would never let us reach.
REPO_ROOT_PPC="$(git rev-parse --show-toplevel 2>/dev/null)"
if [ -n "$REPO_ROOT_PPC" ] && [ -f "$REPO_ROOT_PPC/scripts/_review-gate-lib.sh" ]; then
    . "$REPO_ROOT_PPC/scripts/_review-gate-lib.sh"
    PUSH_MARKER="$REPO_ROOT_PPC/.claude/.change-review-ok"
    if git rev-parse --verify -q origin/main >/dev/null 2>&1; then
        EXPECTED_PUSH_HASH=$(diff_hash origin/main...HEAD 2>/dev/null || true)
    else
        EXPECTED_PUSH_HASH=$(diff_hash HEAD 2>/dev/null || true)
    fi
    if [ -n "$EXPECTED_PUSH_HASH" ]; then
        ACTUAL_PUSH_HASH=$(consume_marker "$PUSH_MARKER")
        if [ "$ACTUAL_PUSH_HASH" != "$EXPECTED_PUSH_HASH" ]; then
            echo -e "${RED}[ERROR] Run /change-review before pushing -- it writes a diff-bound review-ok marker this hook checks.${RESET}"
            echo -e "${RED}        If you already reviewed, the diff changed since then; re-run /change-review.${RESET}"
            FAILED=1
            echo ""
        fi
    fi
fi

echo ""
if [ "$FAILED" -ne 0 ]; then
```

- [ ] **Step 2: Add matching logic to `scripts/pre-push-check.ps1`**

Find the equivalent PowerShell block (Check 7, ending right before `} catch { ... }` / the final `if ($failed)` summary):
```powershell
# Check 7: mb validate (warn if mb available)
if (Get-Command mb -ErrorAction SilentlyContinue) {
    $validateOut = & mb validate 2>&1
    if ($LASTEXITCODE -ne 0) {
        Write-Host "[WARN] mb validate reported issues — memory bank may be inconsistent:" -ForegroundColor Yellow
        $validateOut | ForEach-Object { Write-Host "       $_" }
        Write-Host ""
    } else {
        Write-Host "[OK]   mb validate passed" -ForegroundColor Green
    }
} else {
    Write-Host "[SKIP] mb not in PATH — skipping mb validate." -ForegroundColor DarkGray
}

} catch {
```

Insert Check 8 before the closing `}`:
```powershell
# Check 7: mb validate (warn if mb available)
if (Get-Command mb -ErrorAction SilentlyContinue) {
    $validateOut = & mb validate 2>&1
    if ($LASTEXITCODE -ne 0) {
        Write-Host "[WARN] mb validate reported issues — memory bank may be inconsistent:" -ForegroundColor Yellow
        $validateOut | ForEach-Object { Write-Host "       $_" }
        Write-Host ""
    } else {
        Write-Host "[OK]   mb validate passed" -ForegroundColor Green
    }
} else {
    Write-Host "[SKIP] mb not in PATH — skipping mb validate." -ForegroundColor DarkGray
}

# Check 8: review-gate marker consumption (block) -- Layer 2 of the review-gate design.
# WHY this is the sole authoritative push-gate consumer now: see pre-push-check.sh's
# matching comment -- this is a real git hook, fires regardless of who runs `git push`.
# WHY forward slashes in the Join-Path child segments below, not backslashes: Join-Path
# concatenates literally -- a backslash is only a separator on Windows. `.githooks/pre-push`
# prefers pwsh whenever it's present regardless of OS, and GitHub Actions ubuntu-latest
# runners ship pwsh, so a backslash here would silently fail to resolve on non-Windows pwsh.
$repoRootPpc = git rev-parse --show-toplevel 2>$null
if ($repoRootPpc -and (Test-Path (Join-Path $repoRootPpc "scripts/_review-gate-lib.ps1"))) {
    . (Join-Path $repoRootPpc "scripts/_review-gate-lib.ps1")
    $pushMarker = Join-Path $repoRootPpc ".claude/.change-review-ok"
    $expectedPushHash = Get-PushDiffHash
    if ($expectedPushHash) {
        if (-not (Invoke-ConsumeMarker $pushMarker $expectedPushHash)) {
            Write-Host "[ERROR] Run /change-review before pushing -- it writes a diff-bound review-ok marker this hook checks." -ForegroundColor Red
            Write-Host "        If you already reviewed, the diff changed since then; re-run /change-review." -ForegroundColor Red
            $failed = $true
            Write-Host ""
        }
    }
}

} catch {
```

- [ ] **Step 3: Extend `check-review-gate-lib-presence.sh` to cover the two new Layer 2 files**

`scripts/check-review-gate-lib-presence.sh` (used by both `mb doctor` and CI's `template-integrity` job) only checks that `_review-gate-lib.sh`/`.ps1` exist alongside `review-reminders(.sh|.ps1|-post.sh|-post.ps1)`. By this point in the plan, `pre-commit-check.sh`/`.ps1` (Task 3) and `pre-push-check.sh`/`.ps1` (this task) also dot-source the lib and would silently fail open if it ever went missing from a downstream project, with no detection covering them — the exact gap class this script's own header comment says already bit `review-reminders*` once before.

Find (`scripts/check-review-gate-lib-presence.sh`):
```sh
if { [ -f "$dir/review-reminders.sh" ] || [ -f "$dir/review-reminders-post.sh" ]; } && [ ! -f "$dir/_review-gate-lib.sh" ]; then
    echo "ERROR: $dir/_review-gate-lib.sh missing but $dir/review-reminders.sh/-post.sh present -- the review-gate hook will fail open (gate silently disabled)"
    fail=1
fi
if { [ -f "$dir/review-reminders.ps1" ] || [ -f "$dir/review-reminders-post.ps1" ]; } && [ ! -f "$dir/_review-gate-lib.ps1" ]; then
    echo "ERROR: $dir/_review-gate-lib.ps1 missing but $dir/review-reminders.ps1/-post.ps1 present -- the review-gate hook will fail open (gate silently disabled)"
    fail=1
fi
```

Replace with:
```sh
if { [ -f "$dir/review-reminders.sh" ] || [ -f "$dir/review-reminders-post.sh" ] || [ -f "$dir/pre-commit-check.sh" ] || [ -f "$dir/pre-push-check.sh" ]; } && [ ! -f "$dir/_review-gate-lib.sh" ]; then
    echo "ERROR: $dir/_review-gate-lib.sh missing but a file that dot-sources it is present -- the review-gate hook will fail open (gate silently disabled)"
    fail=1
fi
if { [ -f "$dir/review-reminders.ps1" ] || [ -f "$dir/review-reminders-post.ps1" ] || [ -f "$dir/pre-commit-check.ps1" ] || [ -f "$dir/pre-push-check.ps1" ]; } && [ ! -f "$dir/_review-gate-lib.ps1" ]; then
    echo "ERROR: $dir/_review-gate-lib.ps1 missing but a file that dot-sources it is present -- the review-gate hook will fail open (gate silently disabled)"
    fail=1
fi
```

- [ ] **Step 4: Commit**

```bash
git add scripts/pre-push-check.sh scripts/pre-push-check.ps1 scripts/check-review-gate-lib-presence.sh
git commit -m "feat: add review-gate marker consumption to pre-push-check (Layer 2 push gate)"
```

---

### Task 6: Mirror all Task 1-5 changes to `templates/`

**Files:**
- Modify: `templates/scripts/_review-gate-lib.sh`, `.ps1`
- Modify: `templates/scripts/review-reminders.sh`, `.ps1`
- Create: `templates/scripts/pre-commit-check.sh`, `.ps1`
- Modify: `templates/scripts/pre-push-check.sh`, `.ps1`
- Modify: `templates/.githooks/pre-commit`

These are `TEMPLATE_OWNED` — byte-identical mirrors of the live `scripts/`/`.githooks/` versions (not trimmed, unlike `docs/HOOKS-GUIDE.md`'s mirror).

- [ ] **Step 1: Diff live vs. template to confirm they started identical**

Run:
```bash
diff scripts/_review-gate-lib.sh templates/scripts/_review-gate-lib.sh
diff scripts/_review-gate-lib.ps1 templates/scripts/_review-gate-lib.ps1
diff scripts/review-reminders.sh templates/scripts/review-reminders.sh
diff scripts/review-reminders.ps1 templates/scripts/review-reminders.ps1
diff scripts/pre-push-check.sh templates/scripts/pre-push-check.sh
diff scripts/pre-push-check.ps1 templates/scripts/pre-push-check.ps1
diff .githooks/pre-commit templates/.githooks/pre-commit
```
Before Tasks 1-5, all of these should show no diff (or only the pre-existing diff already present before this plan started, in which case note it and don't blindly overwrite unrelated pre-existing drift).

- [ ] **Step 2: Copy the live files over the template files**

```bash
cp scripts/_review-gate-lib.sh templates/scripts/_review-gate-lib.sh
cp scripts/_review-gate-lib.ps1 templates/scripts/_review-gate-lib.ps1
cp scripts/review-reminders.sh templates/scripts/review-reminders.sh
cp scripts/review-reminders.ps1 templates/scripts/review-reminders.ps1
cp scripts/pre-commit-check.sh templates/scripts/pre-commit-check.sh
cp scripts/pre-commit-check.ps1 templates/scripts/pre-commit-check.ps1
cp scripts/pre-push-check.sh templates/scripts/pre-push-check.sh
cp scripts/pre-push-check.ps1 templates/scripts/pre-push-check.ps1
cp .githooks/pre-commit templates/.githooks/pre-commit
chmod +x templates/scripts/pre-commit-check.sh templates/.githooks/pre-commit
```

- [ ] **Step 3: Verify no unintended diff remains**

```bash
diff scripts/_review-gate-lib.sh templates/scripts/_review-gate-lib.sh
diff scripts/pre-commit-check.sh templates/scripts/pre-commit-check.sh
```
Expected: no output (identical).

- [ ] **Step 4: Commit**

```bash
git add templates/scripts/_review-gate-lib.sh templates/scripts/_review-gate-lib.ps1 \
        templates/scripts/review-reminders.sh templates/scripts/review-reminders.ps1 \
        templates/scripts/pre-commit-check.sh templates/scripts/pre-commit-check.ps1 \
        templates/scripts/pre-push-check.sh templates/scripts/pre-push-check.ps1 \
        templates/.githooks/pre-commit
git commit -m "chore: mirror review-gate Layer 1/2 changes to templates/"
```

---

### Task 7: Register new files in `scripts/mb.sh` and `scripts/mb.ps1`

**Files:**
- Modify: `scripts/mb.sh`
- Modify: `scripts/mb.ps1`

- [ ] **Step 1: Add `pre-commit-check.sh`/`.ps1` to `mb.sh`'s init copy loop**

In `scripts/mb.sh`, find (around line 518-527):
```sh
                  pre-push-check.sh pre-push-check.ps1 \
                  delegation-depth-check.sh delegation-depth-check.ps1 \
                  pre-compact-check.sh pre-compact-check.ps1 \
                  review-reminders.sh review-reminders.ps1 \
                  review-reminders-post.sh review-reminders-post.ps1 \
                  _review-gate-lib.sh _review-gate-lib.ps1; do
```

Replace with:
```sh
                  pre-push-check.sh pre-push-check.ps1 \
                  pre-commit-check.sh pre-commit-check.ps1 \
                  delegation-depth-check.sh delegation-depth-check.ps1 \
                  pre-compact-check.sh pre-compact-check.ps1 \
                  review-reminders.sh review-reminders.ps1 \
                  review-reminders-post.sh review-reminders-post.ps1 \
                  _review-gate-lib.sh _review-gate-lib.ps1; do
```

- [ ] **Step 2: Add to `mb.sh`'s `TEMPLATE_OWNED` array**

Find (around line 1707-1708):
```sh
        "scripts/pre-push-check.sh"
        "scripts/pre-push-check.ps1"
```

Replace with:
```sh
        "scripts/pre-push-check.sh"
        "scripts/pre-push-check.ps1"
        "scripts/pre-commit-check.sh"
        "scripts/pre-commit-check.ps1"
```

- [ ] **Step 3: Add `docs/review-log/README.md` to `mb.sh`'s `ADVISORY_CREATE` array**

This requires a template source at `templates/docs/review-log/README.md` to exist (`_upgrade_src`'s target-to-source mapping) — Task 12 creates it alongside the live file, so this registration is inert (prints `[?] ... template source missing — skipped`) until Task 12 runs, which is fine since both land before this plan is complete.

Find (around line 1759-1760):
```sh
        "docs/CONTRACTS-GUIDE.md"
        "docs/HOOKS-GUIDE.md"
    )
```

Replace with:
```sh
        "docs/CONTRACTS-GUIDE.md"
        "docs/HOOKS-GUIDE.md"
        "docs/review-log/README.md"
    )
```

- [ ] **Step 4: Mirror all three changes in `scripts/mb.ps1`**

Find (around line 746, the `foreach ($script in @(...))` line) and add `"pre-commit-check.sh","pre-commit-check.ps1"` after `"pre-push-check.sh","pre-push-check.ps1"`:
```powershell
    foreach ($script in @("dangerous-commands.sh","dangerous-commands.ps1","check-contract.sh","check-contract.ps1","update-reviewed.sh","update-reviewed.ps1","pre-push-check.sh","pre-push-check.ps1","pre-commit-check.sh","pre-commit-check.ps1","delegation-depth-check.sh","delegation-depth-check.ps1","pre-compact-check.sh","pre-compact-check.ps1","review-reminders.sh","review-reminders.ps1","review-reminders-post.sh","review-reminders-post.ps1","_review-gate-lib.sh","_review-gate-lib.ps1")) {
```

Find (around line 1980-1981, inside the `TEMPLATE_OWNED` array) and add the two new entries:
```powershell
        "scripts/pre-push-check.sh"
        "scripts/pre-push-check.ps1"
        "scripts/pre-commit-check.sh"
        "scripts/pre-commit-check.ps1"
```

`mb.ps1` has no hardcoded `ADVISORY_CREATE`-equivalent array to add an entry to — its `$advisoryCreate` list is built by auto-discovering flat files under `templates/docs/` via `Get-TemplateDirFile -Subdir "docs"` (deliberately refactored away from a hardcoded list — see the WHY comment at `scripts/mb.ps1:2034-2044`). That auto-discovery is non-recursive (`Get-ChildItem $dir -File`, no `-Recurse` — `Get-TemplateDirFile`'s own definition, `scripts/mb.ps1:150-155`), so it would never pick up a nested `templates/docs/review-log/README.md` even after Task 12 creates it. Rather than making `Get-TemplateDirFile` recursive (which would also change its behavior for every other caller, including the `claude-commands` discovery a few lines above — out of scope here), add one more targeted auto-discovery call for the new subdirectory, keeping the same "no hardcoded filename to go stale" property for this one nested path.

Find (`scripts/mb.ps1`, immediately after the existing `$advisoryCreate += (Get-TemplateDirFile ... -Subdir "docs" ...)` line):
```powershell
    $advisoryCreate += (Get-TemplateDirFile -TemplatesDir $TemplatesDir -Subdir "docs" | ForEach-Object { "docs/$($_.Name)" })
```

Replace with:
```powershell
    $advisoryCreate += (Get-TemplateDirFile -TemplatesDir $TemplatesDir -Subdir "docs" | ForEach-Object { "docs/$($_.Name)" })

    # WHY a separate call instead of making Get-TemplateDirFile recursive: docs/review-log/ is
    # the only nested advisory-create subdirectory today. Recursing would change behavior for
    # every other Get-TemplateDirFile caller (e.g. claude-commands discovery above) -- a
    # targeted second call keeps this narrow while still avoiding a hardcoded filename.
    $advisoryCreate += (Get-TemplateDirFile -TemplatesDir $TemplatesDir -Subdir "docs/review-log" | ForEach-Object { "docs/review-log/$($_.Name)" })
```

- [ ] **Step 5: Verify with a dry-run `mb doctor` (or `mb upgrade --dry-run` if available) against a scratch project**

Run:
```bash
grep -c "pre-commit-check" scripts/mb.sh scripts/mb.ps1
```
Expected: `scripts/mb.sh:3` (copy loop + TEMPLATE_OWNED, appears twice per file plus the `.ps1` variant name — count may vary by exact wording; the important check is it's present, not absent) and similarly non-zero for `mb.ps1`.

- [ ] **Step 6: Commit**

```bash
git add scripts/mb.sh scripts/mb.ps1
git commit -m "feat: register pre-commit-check + docs/review-log/README.md for mb init/upgrade"
```

---

### Task 8: New test suite for Layer 2 git-hook behavior + live end-to-end

**Files:**
- Create: `tests/test-review-gate-git-hooks.sh`
- Modify: `tests/run.sh`

This covers spec Testing items 1-5 and 8 against the *relocated* (Layer 2) logic — the existing `tests/test-review-reminders.sh` only exercises Layer 1 (updated separately in Task 9).

- [ ] **Step 1: Write `tests/test-review-gate-git-hooks.sh`**

```sh
#!/usr/bin/env bash
# tests/test-review-gate-git-hooks.sh — Layer 2 (real git hook) marker-consumption tests.
#
# WHY this is a separate suite from test-review-reminders.sh: that suite exercises Layer 1
# (the Claude Code PreToolUse hook, review-reminders.sh/.ps1, JSON-stdin invocation). This
# suite exercises Layer 2 (the real git hooks, scripts/pre-commit-check.sh/.ps1 and
# scripts/pre-push-check.sh/.ps1) which have a completely different invocation shape --
# they run as actual git hooks via core.hooksPath during a real `git commit`/`git push`,
# with no stdin JSON at all.
set -u

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$REPO_ROOT/tests/helpers/assert.sh"

echo "=== review-gate git-hook (Layer 2) tests ==="

setup_repo() {
  local dir
  dir="$(mktemp -d 2>/dev/null || mktemp -d -t mb-l2-test)"
  git -C "$dir" init -q -b main
  git -C "$dir" config user.email "test@example.com"
  git -C "$dir" config user.name "Test"
  echo "line one" > "$dir/file.txt"
  git -C "$dir" add file.txt
  git -C "$dir" commit -q -m "initial"
  mkdir -p "$dir/.claude"
  mkdir -p "$dir/.githooks"
  cp "$REPO_ROOT/.githooks/pre-commit" "$dir/.githooks/pre-commit"
  chmod +x "$dir/.githooks/pre-commit"
  mkdir -p "$dir/scripts"
  cp "$REPO_ROOT/scripts/pre-commit-check.sh" "$dir/scripts/pre-commit-check.sh"
  cp "$REPO_ROOT/scripts/_review-gate-lib.sh" "$dir/scripts/_review-gate-lib.sh"
  chmod +x "$dir/scripts/pre-commit-check.sh"
  git -C "$dir" config core.hooksPath .githooks
  printf '%s' "$dir"
}

write_marker() {
  local dir="$1" marker="$2"
  local tmp
  tmp=$(mktemp)
  git -C "$dir" diff HEAD > "$tmp" 2>/dev/null
  sha256sum "$tmp" | cut -d' ' -f1 > "$dir/.claude/$marker"
  rm -f "$tmp"
}

# ── Testing #1: marker consumption case set (missing, mismatched, matching) ─────────────────
echo ""
echo "--- Layer 2 commit gate: missing marker denies ---"
D1="$(setup_repo)"
echo "line two" >> "$D1/file.txt"
git -C "$D1" add file.txt
if git -C "$D1" commit -q -m "should fail" 2>/tmp/l2-err.txt; then
  echo "FAIL: commit succeeded with no marker present"
  exit 1
else
  assert_contains "$(cat /tmp/l2-err.txt)" "Run /code-review" "Layer 2 denies a commit with no marker present"
fi

echo ""
echo "--- Layer 2 commit gate: mismatched marker denies ---"
printf '0000000000000000000000000000000000000000000000000000000000000000' > "$D1/.claude/.code-review-ok"
if git -C "$D1" commit -q -m "should fail" 2>/tmp/l2-err.txt; then
  echo "FAIL: commit succeeded with a mismatched marker"
  exit 1
else
  assert_contains "$(cat /tmp/l2-err.txt)" "Run /code-review" "Layer 2 denies a commit with a mismatched marker"
fi
assert_file_not_exists "$D1/.claude/.code-review-ok" "Layer 2 consumed the mismatched marker (consume-always semantics preserved)"

echo ""
echo "--- Layer 2 commit gate: matching marker allows the commit ---"
write_marker "$D1" ".code-review-ok"
if git -C "$D1" commit -q -m "should succeed"; then
  echo "PASS: Layer 2 allows a commit with a matching marker"
else
  echo "FAIL: commit was denied despite a matching marker"
  exit 1
fi
assert_file_not_exists "$D1/.claude/.code-review-ok" "Layer 2 consumed the matching marker"

# ── Testing #5: live end-to-end, a real user-run commit (not through any agent tool) ────────
echo ""
echo "--- Testing #5 (live end-to-end): a real git commit with no marker is denied, proving Layer 2 closes the user-run bypass ---"
D2="$(setup_repo)"
echo "line two" >> "$D2/file.txt"
git -C "$D2" add file.txt
if (cd "$D2" && git commit -q -m "user-run, no marker" 2>/tmp/l2-err2.txt); then
  echo "FAIL: a real, directly-invoked git commit succeeded with no marker present -- Layer 2 did not close the bypass"
  exit 1
else
  assert_contains "$(cat /tmp/l2-err2.txt)" "Run /code-review" "A real git commit run directly (not via any agent tool) is denied by Layer 2 -- the structural bypass this design targets is closed"
fi

# ── Testing #2: empty-diff race ──────────────────────────────────────────────────────────────
echo ""
echo "--- Testing #2: empty-diff race -- marker present, nothing staged, marker survives ---"
D3="$(setup_repo)"
echo "line two" >> "$D3/file.txt"
git -C "$D3" add file.txt
write_marker "$D3" ".code-review-ok"
git -C "$D3" reset -q  # unstage everything, leaving nothing to commit but the marker still present
if git -C "$D3" commit -q -m "nothing staged" 2>/dev/null; then
  echo "FAIL: git allowed a commit with nothing staged"
  exit 1
fi
assert_file_exists "$D3/.claude/.code-review-ok" "the marker survives an empty-diff commit attempt (not consumed on a no-op)"

# ── Testing #3: pre-commit ordering -- handoff.md block fires before marker consumption ─────
echo ""
echo "--- Testing #3: handoff.md block fires first; a valid marker is NOT consumed ---"
D4="$(setup_repo)"
echo "line two" >> "$D4/file.txt"
echo "some handoff content" > "$D4/handoff.md"
git -C "$D4" add file.txt handoff.md
write_marker "$D4" ".code-review-ok"
if git -C "$D4" commit -q -m "should fail on handoff.md" 2>/tmp/l2-err4.txt; then
  echo "FAIL: commit succeeded despite handoff.md being staged"
  exit 1
else
  assert_contains "$(cat /tmp/l2-err4.txt)" "handoff.md is staged" "the handoff.md block fires and produces its own error message"
fi
assert_file_exists "$D4/.claude/.code-review-ok" "the marker is NOT consumed when the commit is blocked by the earlier handoff.md check"

# ── Testing #4: Bash/PowerShell parity for the relocated hook logic ─────────────────────────
if command -v pwsh >/dev/null 2>&1; then
  echo ""
  echo "--- Testing #4: PowerShell parity -- pre-commit-check.ps1 denies/allows matching bash's behavior ---"
  D5="$(setup_repo)"
  cp "$REPO_ROOT/scripts/pre-commit-check.ps1" "$D5/scripts/pre-commit-check.ps1"
  cp "$REPO_ROOT/scripts/_review-gate-lib.ps1" "$D5/scripts/_review-gate-lib.ps1"
  cat > "$D5/.githooks/pre-commit" <<'HOOKEOF'
#!/usr/bin/env bash
ROOT=$(git rev-parse --show-toplevel 2>/dev/null || pwd)
pwsh -NonInteractive -File "$ROOT/scripts/pre-commit-check.ps1"
HOOKEOF
  chmod +x "$D5/.githooks/pre-commit"
  echo "line two" >> "$D5/file.txt"
  git -C "$D5" add file.txt
  if git -C "$D5" commit -q -m "should fail (ps1)" 2>/dev/null; then
    echo "FAIL: pre-commit-check.ps1 allowed a commit with no marker"
    exit 1
  fi
  write_marker "$D5" ".code-review-ok"
  if git -C "$D5" commit -q -m "should succeed (ps1)"; then
    echo "PASS: pre-commit-check.ps1 allows a commit with a matching marker"
  else
    echo "FAIL: pre-commit-check.ps1 denied a commit with a matching marker"
    exit 1
  fi
  rm -rf "$D5"
else
  echo ""
  echo "--- Testing #4 PowerShell parity: SKIPPED (pwsh not installed) ---"
fi

# ── Testing #8: merge-commit behavior (empirical, not assumed) ──────────────────────────────
echo ""
echo "--- Testing #8: explicit merge-commit test -- does Layer 2 fire on a real non-fast-forward merge? ---"
D6="$(setup_repo)"
git -C "$D6" checkout -q -b feature
echo "feature line" >> "$D6/file.txt"
git -C "$D6" commit -q -am "feature commit"
git -C "$D6" checkout -q main
echo "main line" >> "$D6/other.txt"
git -C "$D6" add other.txt
git -C "$D6" commit -q -m "main commit"
if git -C "$D6" merge -q --no-edit feature 2>/tmp/l2-merge.txt; then
  echo "RESULT: pre-commit did NOT fire for this non-fast-forward merge (merge succeeded with no marker present)."
  echo "This is empirically documented, not assumed -- see Known Limitations #4 in the spec."
else
  assert_contains "$(cat /tmp/l2-merge.txt)" "Run /code-review" "RESULT: pre-commit DID fire for this non-fast-forward merge and correctly denied it with no marker present."
fi

# ── Push-gate (Task 5) tests -- this suite otherwise only exercises pre-commit-check.sh; the
# push side (scripts/pre-push-check.sh/.ps1) had no dedicated test coverage at all, which is
# exactly how the set -e / origin-main-missing bug (see Task 5's WHY comment) went undetected.
setup_push_repo() {
  local dir remote
  dir="$(mktemp -d 2>/dev/null || mktemp -d -t mb-l2-push-test)"
  remote="$(mktemp -d 2>/dev/null || mktemp -d -t mb-l2-push-remote)"
  git init -q --bare "$remote"
  git -C "$dir" init -q -b main
  git -C "$dir" config user.email "test@example.com"
  git -C "$dir" config user.name "Test"
  echo "line one" > "$dir/file.txt"
  git -C "$dir" add file.txt
  git -C "$dir" commit -q -m "initial"
  git -C "$dir" remote add origin "$remote"
  mkdir -p "$dir/.claude" "$dir/.githooks" "$dir/scripts"
  cp "$REPO_ROOT/.githooks/pre-push" "$dir/.githooks/pre-push"
  chmod +x "$dir/.githooks/pre-push"
  cp "$REPO_ROOT/scripts/pre-push-check.sh" "$dir/scripts/pre-push-check.sh"
  cp "$REPO_ROOT/scripts/_review-gate-lib.sh" "$dir/scripts/_review-gate-lib.sh"
  chmod +x "$dir/scripts/pre-push-check.sh"
  git -C "$dir" config core.hooksPath .githooks
  printf '%s|%s' "$dir" "$remote"
}

write_push_marker() {
  local dir="$1" ref_range="$2" tmp
  tmp=$(mktemp)
  git -C "$dir" diff $ref_range > "$tmp" 2>/dev/null
  sha256sum "$tmp" | cut -d' ' -f1 > "$dir/.claude/.change-review-ok"
  rm -f "$tmp"
}

echo ""
echo "--- Layer 2 push gate: missing marker denies (first push, no origin/main ref yet) ---"
P1_PAIR="$(setup_push_repo)"
P1="${P1_PAIR%%|*}"; P1_REMOTE="${P1_PAIR##*|}"
if git -C "$P1" push -q origin main 2>/tmp/l2-push-err.txt; then
  echo "FAIL: first push succeeded with no marker present"
  exit 1
else
  assert_contains "$(cat /tmp/l2-push-err.txt)" "Run /change-review" "Layer 2 denies a first push (no origin/main ref resolvable yet) with no marker present"
fi

echo ""
echo "--- Layer 2 push gate: regression test for the set -e / no-origin-main bug (Finding #1) ---"
echo "--- a VALID marker present on a first push (origin/main not yet resolvable) must allow the push, not crash ---"
P2_PAIR="$(setup_push_repo)"
P2="${P2_PAIR%%|*}"
write_push_marker "$P2" "HEAD"
if git -C "$P2" push -q origin main 2>/tmp/l2-push-err2.txt; then
  echo "PASS: Layer 2 allows a first push with a matching HEAD-fallback marker (origin/main not yet resolvable)"
else
  echo "FAIL: first push was denied/crashed despite a matching marker -- see: $(cat /tmp/l2-push-err2.txt)"
  exit 1
fi
assert_file_not_exists "$P2/.claude/.change-review-ok" "Layer 2 consumed the matching push marker on the HEAD-fallback path"

echo ""
echo "--- Layer 2 push gate: mismatched marker denies and is consumed ---"
P3_PAIR="$(setup_push_repo)"
P3="${P3_PAIR%%|*}"
printf '0000000000000000000000000000000000000000000000000000000000000000' > "$P3/.claude/.change-review-ok"
if git -C "$P3" push -q origin main 2>/tmp/l2-push-err3.txt; then
  echo "FAIL: first push succeeded with a mismatched marker"
  exit 1
else
  assert_contains "$(cat /tmp/l2-push-err3.txt)" "Run /change-review" "Layer 2 denies a first push with a mismatched marker"
fi
assert_file_not_exists "$P3/.claude/.change-review-ok" "Layer 2 consumed the mismatched push marker (consume-always semantics preserved)"

echo ""
echo "--- Layer 2 push gate: origin/main path (ref already resolvable, not the HEAD fallback) ---"
P4_PAIR="$(setup_push_repo)"
P4="${P4_PAIR%%|*}"
write_push_marker "$P4" "HEAD"
git -C "$P4" push -q -u origin main  # establishes the origin/main tracking ref for the next push
echo "line two" >> "$P4/file.txt"
git -C "$P4" add file.txt
git -C "$P4" commit -q -m "second commit"
write_push_marker "$P4" "origin/main...HEAD"
if git -C "$P4" push -q origin main; then
  echo "PASS: Layer 2 allows a push with a matching marker via the origin/main path (ref already resolvable)"
else
  echo "FAIL: push was denied despite a matching marker via the origin/main path"
  exit 1
fi
assert_file_not_exists "$P4/.claude/.change-review-ok" "Layer 2 consumed the matching push marker on the origin/main path"

rm -rf "$P1" "$P1_REMOTE" "$P2" "$P3" "$P4"

rm -rf "$D1" "$D2" "$D3" "$D4" "$D6"

print_summary
```

- [ ] **Step 2: Run the new suite**

Run: `bash tests/test-review-gate-git-hooks.sh`
Expected: all assertions pass. The Testing #8 (merge-commit) block will print its RESULT either way — read the output and note which branch fired; this becomes the empirical answer to spec Known Limitation #4 (record it in the plan's completion notes, not as a failure).

- [ ] **Step 3: Register the new suite in `tests/run.sh`**

Find:
```sh
run_suite "review-reminders"     "$REPO_ROOT/tests/test-review-reminders.sh"
```

Add immediately after:
```sh
run_suite "review-reminders"     "$REPO_ROOT/tests/test-review-reminders.sh"
run_suite "review-gate-git-hooks" "$REPO_ROOT/tests/test-review-gate-git-hooks.sh"
```

- [ ] **Step 4: Run the full suite to confirm nothing else broke**

Run: `bash tests/run.sh 2>&1 | tail -30`
Expected: `All test suites passed.`

- [ ] **Step 5: Commit**

```bash
git add tests/test-review-gate-git-hooks.sh tests/run.sh
git commit -m "test: add Layer 2 git-hook test suite (marker consumption, ordering, live end-to-end)"
```

---

### Task 9: Update `tests/test-review-reminders.sh` for peek-only Layer 1

**Files:**
- Modify: `tests/test-review-reminders.sh`

The existing "marker is single-use" test (asserts a second commit attempt is denied because the first one consumed the marker) is now testing the WRONG layer — Layer 1 no longer consumes anything. It must be rewritten to prove peek behavior instead: the marker survives a Layer-1 peek-and-deny-early check.

- [ ] **Step 1: Replace the "marker is single-use" test**

Find:
```sh
# ── commit gate: consumed marker denies a second attempt ────────────────────────────────────
echo ""
echo "--- commit gate: marker is single-use ---"
resp=$(invoke_hook "review-reminders.sh" "git commit -m test2")
assert_contains "$resp" '"permissionDecision":"deny"' "review-reminders.sh denies a second commit with no new marker"
```

Replace with:
```sh
# ── commit gate: Layer 1 only peeks, never consumes (Layer 2 is the sole consumer now) ──────
echo ""
echo "--- commit gate: Layer 1 (review-reminders.sh) peeks without consuming the marker ---"
resp=$(invoke_hook "review-reminders.sh" "git commit -m test2")
assert_contains "$resp" '"permissionDecision":"deny"' "review-reminders.sh denies a second commit attempt (the diff has moved on since the marker's hash matched the FIRST diff, not this one)"
# The marker itself must still be present and unmodified after Layer 1's check -- Layer 1
# is peek-only now (Task 2), so re-invoking the hook against the ORIGINAL diff must produce
# the SAME allow/deny result both times, proving nothing was consumed.
assert_file_exists "$TMPDIR_RR/.claude/.code-review-ok" "Layer 1 did not consume the marker -- it is still present on disk after review-reminders.sh ran"
```

- [ ] **Step 2: Add a new explicit peek-does-not-consume test right after the existing "accepted" test**

Find:
```sh
resp=$(invoke_hook "review-reminders.sh" "git commit -m test")
assert_not_contains "$resp" '"permissionDecision":"deny"' "review-reminders.sh accepts a marker written via its own documented bash recipe"
```

Add immediately after:
```sh
resp=$(invoke_hook "review-reminders.sh" "git commit -m test")
assert_not_contains "$resp" '"permissionDecision":"deny"' "review-reminders.sh accepts a marker written via its own documented bash recipe"
assert_file_exists "$TMPDIR_RR/.claude/.code-review-ok" "review-reminders.sh (Layer 1) does not consume the marker on a successful peek -- it remains for Layer 2 to actually consume"
```

- [ ] **Step 3: Update the push-gate test similarly (marker should still be present after a successful Layer-1 peek)**

Find:
```sh
resp=$(invoke_hook "review-reminders.sh" "git push origin main")
assert_not_contains "$resp" '"permissionDecision":"deny"' "review-reminders.sh accepts a push-gate marker computed via the HEAD fallback (no origin/main ref exists)"
```

Add immediately after:
```sh
resp=$(invoke_hook "review-reminders.sh" "git push origin main")
assert_not_contains "$resp" '"permissionDecision":"deny"' "review-reminders.sh accepts a push-gate marker computed via the HEAD fallback (no origin/main ref exists)"
assert_file_exists "$TMPDIR_RR/.claude/.change-review-ok" "review-reminders.sh (Layer 1) does not consume the push marker on a successful peek"
```

- [ ] **Step 4: Fix the worktree-root negative-control test, whose proof technique breaks under peek-only Layer 1**

This is a separate, pre-existing test from the ones above (added by the 2026-07-22 worktree-root-resolution fix), not one of the three blocks already handled in Steps 1-3. It disambiguates "root resolved correctly to `$TMPDIR_RR` and rejected its stale marker" from "root resolution silently fell back to `$TMPDIR_WRONG_RR` and denied for finding no marker at all" by checking that `consume_marker`'s atomic `mv` removed the marker specifically at `$TMPDIR_RR`. That proof no longer works: Layer 1 is peek-only now (Step 1 of this task), so the marker is never removed by this code path regardless of which directory root resolution actually found — both scenarios now produce an identical deny with an untouched marker.

Find (in `tests/test-review-reminders.sh`):
```sh
  # The deny above is ambiguous by itself: it looks identical whether root resolution correctly
  # found $TMPDIR_RR and rejected its stale marker, OR silently fell back to $TMPDIR_WRONG_RR
  # (which has no .claude/ directory at all) and denied for finding no marker whatsoever --
  # confirmed by direct reproduction that this test previously couldn't tell the two apart.
  # consume_marker()'s atomic mv only removes the marker file it actually operates on, so
  # checking that the marker at $TMPDIR_RR/.claude/.code-review-ok is gone afterward proves the
  # hook really did resolve root to $TMPDIR_RR (not fall back), and denied because its content
  # didn't match -- not for the wrong reason.
  assert_file_not_exists "$TMPDIR_RR/.claude/.code-review-ok" "review-reminders.sh consumed the marker at the cd-derived root (not a wrong fallback directory), confirming the prior deny was a real hash mismatch rather than root-resolution silently failing"
```

Replace with (test `resolve_cd_root()` directly instead of inferring it from a Layer-1 side effect that no longer exists -- unambiguous regardless of what Layer 1 does with the result):
```sh
  # The deny above is ambiguous by itself: it looks identical whether root resolution correctly
  # found $TMPDIR_RR and rejected its stale marker, OR silently fell back to $TMPDIR_WRONG_RR
  # (which has no .claude/ directory at all) and denied for finding no marker whatsoever.
  # Previously disambiguated via consume_marker()'s side effect (the atomic mv removes whatever
  # marker it actually touches) -- but Layer 1 is peek-only now (Task 2 of the layered-enforcement
  # plan), so the marker is never removed either way and that proof no longer works. Testing
  # resolve_cd_root() directly instead: unambiguous regardless of Layer 1's peek/consume behavior.
  # resolve_cd_root() takes no argument -- it reads the caller's $input global (its own documented
  # contract, see _review-gate-lib.sh) as the raw PreToolUse JSON payload.
  . "$REPO_ROOT/scripts/_review-gate-lib.sh"
  input=$(printf '{"tool_input":{"command":"cd \\\"%s\\\" && git commit -m test7"}}' "$TMPDIR_RR")
  resolved_root=$(resolve_cd_root)
  assert_equals "$TMPDIR_RR" "$resolved_root" "resolve_cd_root() resolves to the cd-derived root, not a fallback directory, confirming the prior deny was a real hash mismatch rather than root-resolution silently failing"
  assert_file_exists "$TMPDIR_RR/.claude/.code-review-ok" "Layer 1 (peek-only) denied without consuming the wrong-hash marker -- it is still present on disk, unlike the old consume-based behavior this test used to check"
```

- [ ] **Step 5: The post-hook reissue tests (commit case) are now testing dead code — update their comment, don't delete them**

Find the header comment above:
```sh
# ── post-hook: reissues a marker after a failed commit attempt (diff_hash refactor) ─────────
```

Add a note directly below it explaining the new context (the presha file this test manually creates is no longer written by review-reminders.sh's commit branch per Task 2, but review-reminders-post.sh's reissue LOGIC itself is untouched and still correctly reissues if a presha file happens to exist — this test now validates that reissue logic stays correct in isolation, not that it fires in the live commit flow):
```sh
# ── post-hook: reissues a marker after a failed commit attempt (diff_hash refactor) ─────────
# NOTE (2026-08-12 Layer 1 downgrade): review-reminders.sh's commit branch no longer writes
# .pending-commit-presha (Layer 2's git hook is the sole consumer now, and pre-commit needs
# no reissue-on-failure companion per the spec). This test still manually creates the presha
# file to verify review-reminders-post.sh's reissue LOGIC remains correct in isolation --
# it no longer fires from the live commit flow, but the push-gate case below still depends
# on it, so the underlying function must stay correct.
```

- [ ] **Step 6: Run the updated suite**

Run: `bash tests/test-review-reminders.sh`
Expected: all tests pass.

- [ ] **Step 7: Run the full suite**

Run: `bash tests/run.sh 2>&1 | tail -30`
Expected: `All test suites passed.`

- [ ] **Step 8: Commit**

```bash
git add tests/test-review-reminders.sh
git commit -m "test: update review-reminders tests for Layer 1 peek-only behavior"
```

---

### Task 10: Durable review-log + invocation-start log in `code-review.md`

**Files:**
- Modify: `.claude/commands/code-review.md`

- [ ] **Step 1: Add invocation-start log write to Step 2**

Find:
```markdown
## Step 2 — Determine Scope

If the user specified a file or folder path, review that target. Otherwise run:

```
git diff HEAD
git status
```

If the diff is empty, let the user know and stop.
```

Replace with:
```markdown
## Step 2 — Determine Scope

If the user specified a file or folder path, review that target. Otherwise run:

```
git diff HEAD
git status
```

If the diff is empty, let the user know and stop.

**Invocation-start log:** once scope is known (this step, not Step 1 — Step 1 doesn't know scope yet), write a JSON file recording this invocation attempt to `docs/review-log/invocations/<epoch-ms>-<random-6char>.json`, before any findings work begins in Step 4. This makes a later reader able to tell "nobody reviewed this" apart from "someone tried and it silently failed" (subagent crash, session drop, classifier interference). Written independent of whether this review ever reaches a verdict.

Bash:
```
mkdir -p docs/review-log/invocations
ts=$(date +%s%3N 2>/dev/null || date +%s000)
rand=$(head -c4 /dev/urandom 2>/dev/null | od -An -tx1 | tr -d ' \n' | head -c6)
[ -z "$rand" ] && rand=$(( RANDOM % 1000000 ))
cat > "docs/review-log/invocations/${ts}-${rand}.json" <<EOF
{"type":"code-review","started_at":"$(date -u +%Y-%m-%dT%H:%M:%SZ)","scope":"$(git diff HEAD --name-only | tr '\n' ',' | sed 's/,$//')"}
EOF
git add "docs/review-log/invocations/${ts}-${rand}.json"
```

PowerShell:
```
New-Item -ItemType Directory -Force -Path "docs/review-log/invocations" | Out-Null
$ts = [DateTimeOffset]::UtcNow.ToUnixTimeMilliseconds()
$rand = -join ((48..57 + 97..102) | Get-Random -Count 6 | ForEach-Object {[char]$_})
$scope = (git diff HEAD --name-only) -join ","
$entry = @{ type = "code-review"; started_at = (Get-Date -AsUTC -Format "yyyy-MM-ddTHH:mm:ssZ"); scope = $scope } | ConvertTo-Json -Compress
$filename = "docs/review-log/invocations/${ts}-${rand}.json"
$entry | Set-Content $filename
git add $filename
```

Note the exact filename used — Step 5 does not need to reference it, but if scope changes mid-review it's useful context for the final report.
```

- [ ] **Step 2: Add review-log write + explicit staging to Step 5, before the marker write**

Find:
```markdown
2. Determine the final verdict: before scanning, revise the `Blocking` field on any finding you
   concluded above is overstated or a false positive with specific counter-evidence — per the
   standard's exception, evidence that risk is contained downgrades it to `Blocking: false`. Then
   scan every finding — the Step 4 domain findings (with any revisions from this step applied)
   plus anything you surfaced yourself while answering the opposition questions — for any `Blocking:
   true`. If none survive, the verdict is **Approve**. Otherwise the verdict is **Request Changes**
   (if concrete fixes were identified) or **Needs Discussion** (if the disagreement itself needs a
   human call).

3. If, and only if, the verdict is **Approve**: independently compute a hash of the reviewed diff
```

Replace with:
```markdown
2. Determine the final verdict: before scanning, revise the `Blocking` field on any finding you
   concluded above is overstated or a false positive with specific counter-evidence — per the
   standard's exception, evidence that risk is contained downgrades it to `Blocking: false`. Then
   scan every finding — the Step 4 domain findings (with any revisions from this step applied)
   plus anything you surfaced yourself while answering the opposition questions — for any `Blocking:
   true`. If none survive, the verdict is **Approve**. Otherwise the verdict is **Request Changes**
   (if concrete fixes were identified) or **Needs Discussion** (if the disagreement itself needs a
   human call).

3. **Write the durable review-log entry, on every verdict** (Approve, Request Changes, or Needs
   Discussion — a rejected review is still real audit history). Compute the diff hash and the
   current HEAD SHA (the commit that was HEAD when this review ran — not a future commit), then
   write `docs/review-log/<YYYY-MM-DD>-<hash7>-code-review.md`:

   ```
   ---
   type: code-review
   diff-hash: <full sha256 of git diff HEAD>
   head-sha: <full output of git rev-parse HEAD>
   verdict: <Approve|Request Changes|Needs Discussion>
   ---
   ```

   followed by the same Domain Coverage / Supported Findings / Predicted Risks / Testing Gaps /
   Opposition Review content that Step 6 assembles into the chat report. `head-sha` and
   `diff-hash` must be read directly from this frontmatter by any automated consumer (Layer 3's
   CI check) — no fuzzy text parsing. The findings table in the body, not the `verdict:` line
   alone, is what CI scans for `Blocking` rows, so it must be complete and accurate.

   **Explicitly stage the file** (`git add docs/review-log/<filename>`) so it lands in the same
   commit it documents — a review-log entry that's written but never staged doesn't survive a
   `git commit -am`.

4. If, and only if, the verdict is **Approve**: independently compute a hash of the reviewed diff
```

The "Replace with" block above already renumbers the original step 3 (marker write) to step 4 inline (one new step 3 was inserted before it). The trailing "Return to the orchestrator" step, originally numbered 4, becomes step 5 (same +1 shift, matching Task 11's identical edit to change-review.md). Find:
```markdown
4. Return to the orchestrator: its answers to the four opposition questions, the verdict, whether it
```
Replace with:
```markdown
5. Return to the orchestrator: its answers to the four opposition questions, the verdict, whether it
```

- [ ] **Step 3: Verify renumbering is internally consistent**

Run: `grep -n "^[0-9]\." .claude/commands/code-review.md`
Expected: sequential 1, 2, 3, 4, 5 within Step 5's block (no gaps, no duplicates).

- [ ] **Step 4: Commit**

```bash
git add .claude/commands/code-review.md
git commit -m "feat: code-review writes durable review-log entry + invocation-start log"
```

---

### Task 11: Durable review-log + invocation-start log in `change-review.md`; mirror both commands to `templates/`

**Files:**
- Modify: `.claude/commands/change-review.md`
- Modify: `templates/claude-commands/code-review.md`
- Modify: `templates/claude-commands/change-review.md` (if present — verify first)

- [ ] **Step 1: Add invocation-start log write to the end of Step 1**

Find:
```markdown
**`--pr <number>`:** Run `gh pr diff <number>` to fetch the PR diff. If `gh` is not installed, report it and fall back to local diff.

If no diff can be obtained, stop and tell the user.

## Step 2: Check for ACR
```

Replace with:
```markdown
**`--pr <number>`:** Run `gh pr diff <number>` to fetch the PR diff. If `gh` is not installed, report it and fall back to local diff.

If no diff can be obtained, stop and tell the user.

**Invocation-start log:** once the diff is obtained (this step, the moment scope is known), write a JSON file recording this invocation attempt to `docs/review-log/invocations/<epoch-ms>-<random-6char>.json`, before any of the 9 review jobs run. Written independent of whether this review ever reaches a verdict — same rationale as `/code-review`'s equivalent (see `docs/superpowers/specs/2026-08-12-review-gate-layered-enforcement-design.md`).

Bash:
```
mkdir -p docs/review-log/invocations
ts=$(date +%s%3N 2>/dev/null || date +%s000)
rand=$(head -c4 /dev/urandom 2>/dev/null | od -An -tx1 | tr -d ' \n' | head -c6)
[ -z "$rand" ] && rand=$(( RANDOM % 1000000 ))
cat > "docs/review-log/invocations/${ts}-${rand}.json" <<EOF
{"type":"change-review","started_at":"$(date -u +%Y-%m-%dT%H:%M:%SZ)"}
EOF
git add "docs/review-log/invocations/${ts}-${rand}.json"
```

PowerShell:
```
New-Item -ItemType Directory -Force -Path "docs/review-log/invocations" | Out-Null
$ts = [DateTimeOffset]::UtcNow.ToUnixTimeMilliseconds()
$rand = -join ((48..57 + 97..102) | Get-Random -Count 6 | ForEach-Object {[char]$_})
$entry = @{ type = "change-review"; started_at = (Get-Date -AsUTC -Format "yyyy-MM-ddTHH:mm:ssZ") } | ConvertTo-Json -Compress
$filename = "docs/review-log/invocations/${ts}-${rand}.json"
$entry | Set-Content $filename
git add $filename
```

## Step 2: Check for ACR
```

- [ ] **Step 2: Add review-log write + explicit staging to Job 9, before the marker write**

Find:
```markdown
2. Before scanning, revise the `Blocking` field on any finding from Jobs 1–8 you conclude above is
   overstated or a false positive, backed by specific counter-evidence from the diff — specific
   evidence that risk is contained downgrades it to `Blocking: No`. Then scan every finding —
   Jobs 1–8's findings (with any revisions from this step
   applied) plus anything you surface yourself during the opposition pass — for any `Blocking: Yes`.
   This determines whether the change package is clean.

3. If, and only if, no finding (from Jobs 1–8 as revised, or your own opposition pass) has
```

Replace with:
```markdown
2. Before scanning, revise the `Blocking` field on any finding from Jobs 1–8 you conclude above is
   overstated or a false positive, backed by specific counter-evidence from the diff — specific
   evidence that risk is contained downgrades it to `Blocking: No`. Then scan every finding —
   Jobs 1–8's findings (with any revisions from this step
   applied) plus anything you surface yourself during the opposition pass — for any `Blocking: Yes`.
   This determines whether the change package is clean.

3. **Write the durable review-log entry, regardless of outcome** (clean or blocked — a blocked
   change package is still real audit history). Compute the diff hash the same way Step 4 (below)
   does, and the current HEAD SHA (the commit that was HEAD when this review ran), then write
   `docs/review-log/<YYYY-MM-DD>-<hash7>-change-review.md`:

   ```
   ---
   type: change-review
   diff-hash: <full sha256 of the diff being reviewed, same value Step 4 computes>
   head-sha: <full output of git rev-parse HEAD>
   verdict: <Clean|Blocked>
   ---
   ```

   followed by the same Findings / Job Summary / Coverage Footer content that Step 5 assembles
   into the chat report (omit the Baseline Repo Health section — it's informational-only and
   never affects coverage). `head-sha` and `diff-hash` must be readable directly from this
   frontmatter by Layer 3's CI check, no fuzzy text parsing — the Findings table itself, not a
   summary line, is what CI scans for `Blocking: Yes` rows.

   **Explicitly stage the file** (`git add docs/review-log/<filename>`) so it lands in the same
   commit/push it documents.

4. If, and only if, no finding (from Jobs 1–8 as revised, or your own opposition pass) has
```

Renumber the original steps 4→5 and the trailing "Return to the orchestrator" step from 4→5... wait — since the ORIGINAL numbering was 1,2,3,4 and this insert makes 3 the new review-log step, the original step 3 (marker write) becomes step 4, and the original step 4 ("Return to the orchestrator") becomes step 5. Find:
```markdown
4. Return to the orchestrator: its opposition answers; the full findings list with any `Blocking`
```
Replace with:
```markdown
5. Return to the orchestrator: its opposition answers; the full findings list with any `Blocking`
```

- [ ] **Step 3: Verify renumbering**

Run: `grep -n "^[0-9]\." .claude/commands/change-review.md`
Expected: sequential 1, 2, 3, 4, 5 within Job 9's block.

- [ ] **Step 4: Mirror `code-review.md` to `templates/claude-commands/code-review.md`**

Run: `diff .claude/commands/code-review.md templates/claude-commands/code-review.md`
If they were byte-identical before Task 10 (verify against git history if unsure — `git log --oneline -- templates/claude-commands/code-review.md`), copy directly:
```bash
cp .claude/commands/code-review.md templates/claude-commands/code-review.md
```

- [ ] **Step 5: Mirror `change-review.md` — check first whether a template copy exists**

Run: `ls templates/claude-commands/change-review.md 2>&1`

If it exists and was previously kept in sync with the live file, copy it:
```bash
cp .claude/commands/change-review.md templates/claude-commands/change-review.md
```

If it does NOT exist, this is a pre-existing gap unrelated to this plan's scope (per this plan's research, `change-review.md` is not currently in `mb.sh`'s `TEMPLATE_OWNED` array at all — unlike `code-review.md`). Do not add new distribution wiring for it here; that's a separate, out-of-scope fix. Just leave `.claude/commands/change-review.md` as the sole copy, matching its current (pre-existing) distribution status.

- [ ] **Step 6: Commit**

```bash
git add .claude/commands/change-review.md templates/claude-commands/code-review.md
git add templates/claude-commands/change-review.md 2>/dev/null || true
git commit -m "feat: change-review writes durable review-log entry + invocation-start log; mirror commands to templates/"
```

---

### Task 12: `docs/review-log/README.md`

**Files:**
- Create: `docs/review-log/README.md`

- [ ] **Step 1: Write the README**

```markdown
# Review Log

Durable, git-tracked record of every `/code-review` and `/change-review` invocation's outcome —
written on **every** verdict (Approve/Clean, Request Changes, Needs Discussion, or Blocked), not
just passing ones. A rejected review is still real audit history.

See `docs/superpowers/specs/2026-08-12-review-gate-layered-enforcement-design.md` for the full
design this directory implements.

## Two kinds of entries

### Completion entries — `<YYYY-MM-DD>-<hash7>-code-review.md` / `-change-review.md`

Written at the end of `/code-review` Step 5 (the Opposition-review subagent's own last action)
or `/change-review` Job 9, immediately before (or in place of) the ephemeral marker write.
`<hash7>` is the first 7 characters of the entry's own `diff-hash` frontmatter field.

Format — a YAML frontmatter block, then the same report body already shown in the chat output:

```yaml
---
type: code-review        # or change-review
diff-hash: <full sha256>
head-sha: <full commit sha that was HEAD when the review ran>
verdict: Approve          # informational only -- automated consumers never trust this alone
---
```

**Why automated consumers (the CI containment check) never trust the `verdict:` line alone:**
this repo has already shipped a bug where a summary verdict string drifted out of sync with the
underlying findings table (the 2026-07-16 "Blocking-revision → report propagation gap," see
`memory-bank/progress.md`). Any automated check must scan the findings table itself for
`Blocking: true`/`Blocking: Yes` rows — zero such rows plus a matching SHA is what "passed"
means, not the presence of `verdict: Approve`.

### Invocation-start entries — `invocations/<epoch-ms>-<random-6char>.json`

Written the moment scope is known (before any findings work begins), independent of whether the
review ever reaches a verdict. Lets a later reader tell "nobody reviewed this" apart from
"someone tried and it silently failed" (subagent crash, session drop, classifier interference —
all documented, recurring failure modes in this repo's history).

**One file per invocation, never a shared growing log** — a single append-only file would
collide constantly across this repo's dominant workflow of many parallel worktree branches
independently invoking review commands (the same class of shared-mutable-state contention
`concurrent-session-claims` needed several bug-fix rounds to handle for a comparable file).

## Who reads this directory

**Layer 3 (CI, `.github/workflows/pmb-health.yml`'s containment check)** is the primary
consumer — see `scripts/ci-review-containment-check.sh`. For every commit between
`merge-base(HEAD, main)` and `HEAD`, it checks whether a `*-code-review.md` entry's `head-sha`
is that commit's parent AND its `diff-hash` matches that commit's own diff exactly, or whether
the commit is an ancestor of a `*-change-review.md` entry's `head-sha` with zero `Blocking` rows
in its findings table. The final merged diff must also match at least one passing
`change-review` entry's `diff-hash`.

Humans reading this directory directly: entries are plain markdown with YAML frontmatter, sorted
naturally by filename (date-prefixed).
```

- [ ] **Step 2: Verify the directory doesn't already conflict with anything**

Run: `ls docs/review-log 2>&1`
Expected (before this step): "No such file or directory". After writing the README, `docs/review-log/README.md` should be the only file present.

- [ ] **Step 3: Create the `templates/` mirror**

Task 7 registers `docs/review-log/README.md` in both shells' advisory-create mechanisms, which require a template source to exist at `templates/docs/review-log/README.md` (`mb.sh`'s `_upgrade_src` mapping / `mb.ps1`'s `Get-TemplateDirFile -Subdir "docs/review-log"`). Without this file, that registration is a permanent no-op — `mb init`/`mb upgrade` would print `[?] docs/review-log/README.md (template source missing — skipped)` forever.

```bash
mkdir -p templates/docs/review-log
cp docs/review-log/README.md templates/docs/review-log/README.md
```

- [ ] **Step 4: Commit**

```bash
git add docs/review-log/README.md templates/docs/review-log/README.md
git commit -m "docs: add docs/review-log/README.md documenting the durable review-log format"
```

---

### Task 13: CI containment check (Layer 3)

**Files:**
- Create: `scripts/ci-review-containment-check.sh`
- Modify: `.github/workflows/pmb-health.yml`
- Create: `tests/test-ci-review-containment.sh`
- Modify: `tests/run.sh`

- [ ] **Step 1: Write `scripts/ci-review-containment-check.sh`**

```sh
#!/usr/bin/env sh
# scripts/ci-review-containment-check.sh — Layer 3 of the review-gate design: verifies every
# commit between merge-base(HEAD, main) and HEAD is covered by a passing review-log entry,
# and that the final merged diff itself matches a passing change-review entry.
#
# WHY per-commit containment uses ancestor-checking for change-review entries but an exact
# parent+diff-hash match for code-review entries: /change-review typically runs on an
# already-committed branch tip (pre-push), so its recorded head-sha IS a real, existing
# commit -- an earlier commit C is validly "covered" if it's an ancestor of that tip, since
# the branch-level review already looked at everything up to and including C.
# /code-review typically runs PRE-commit (on staged/working changes), so its recorded
# head-sha is the commit's PARENT (the spec's own wording: "the exact commit SHA that was
# HEAD when the review ran"), not the commit itself, which doesn't exist yet at review time.
# A bare parent-SHA match alone isn't sufficient proof (a coincidentally-matching parent
# doesn't prove the SAME diff was reviewed), so code-review coverage additionally requires
# the entry's diff-hash to equal the hash of that specific commit's own diff
# (git diff <parent> <commit>) -- this is the exact SHA-256-binding property the old
# ephemeral marker already had, just made durable instead of single-use.
#
# WHY exit 0 for "no review-log entries exist at all yet": a repo/branch with zero prior
# review-log entries (e.g. this feature's own first rollout, before any commit has gone
# through the new /code-review flow) would otherwise fail every commit unconditionally --
# this check is meant to gate FUTURE commits once wired into required-status-checks, not
# retroactively fail history that predates this design. CI wiring is a separate, manual,
# CONFIRM-tier step per the spec -- see docs/superpowers/specs/2026-08-12-review-gate-layered-enforcement-design.md.
#
# Usage: ci-review-containment-check.sh [<repo-root>]
# Exit 0: every commit in range is covered, and the final diff matches a passing change-review
#         entry. Exit 1: at least one gap found; prints one line per gap.
set -u

ROOT="${1:-$(git rev-parse --show-toplevel 2>/dev/null)}"
[ -z "$ROOT" ] && { echo "ERROR: not a git repository"; exit 1; }
cd "$ROOT" || exit 1

REVIEW_LOG_DIR="docs/review-log"
[ -d "$REVIEW_LOG_DIR" ] || { echo "OK: no $REVIEW_LOG_DIR directory yet -- nothing to check"; exit 0; }

# WHY grep -c > 0 rather than a plain glob test: a glob with no matches expands to the
# literal pattern string under `sh` without nullglob -- checking the count from `find` avoids
# that footgun entirely.
entry_count=$(find "$REVIEW_LOG_DIR" -maxdepth 1 -name "*-code-review.md" -o -name "*-change-review.md" 2>/dev/null | grep -c . || true)
if [ "$entry_count" -eq 0 ]; then
    echo "OK: no review-log entries exist yet -- nothing to check (this gate applies to future commits)"
    exit 0
fi

BASE=$(git merge-base HEAD main 2>/dev/null)
if [ -z "$BASE" ]; then
    echo "ERROR: could not compute merge-base(HEAD, main) -- is 'main' fetched? (needs fetch-depth: 0)"
    exit 1
fi

# WHY extract frontmatter with grep/sed instead of a real YAML parser: every entry's
# frontmatter is a fixed 3-key block this script itself controls the format of (written by
# code-review.md/change-review.md per docs/review-log/README.md) -- a full YAML parser is
# unwarranted complexity for 3 known, single-line keys with no nesting.
extract_field() {
    file="$1" key="$2"
    sed -n "1,/^---$/{/^---$/d;p}" "$file" | grep "^${key}:" | head -1 | sed "s/^${key}:[[:space:]]*//"
}

findings_has_blocking() {
    # A finding row is Blocking if its Blocking column (last non-empty cell in a markdown
    # table row) is "true" or "Yes" -- matches this repo's own established rule (never trust
    # a summary verdict line, scan the findings table directly; see the 2026-07-16
    # propagation-gap bug this rule already exists to prevent).
    grep -E '^\|.*\|[[:space:]]*(true|Yes)[[:space:]]*\|?[[:space:]]*$' "$1" >/dev/null 2>&1
}

FAIL=0

commits=$(git rev-list "$BASE".."HEAD" 2>/dev/null)
for commit in $commits; do
    parent=$(git rev-parse "${commit}^" 2>/dev/null)
    covered=0

    # code-review: exact parent match + exact diff-hash match
    for entry in "$REVIEW_LOG_DIR"/*-code-review.md; do
        [ -f "$entry" ] || continue
        entry_head_sha=$(extract_field "$entry" "head-sha")
        [ "$entry_head_sha" = "$parent" ] || continue
        entry_diff_hash=$(extract_field "$entry" "diff-hash")
        commit_diff_hash=$(git diff "$parent" "$commit" 2>/dev/null | sha256sum | cut -d' ' -f1)
        if [ "$entry_diff_hash" = "$commit_diff_hash" ] && ! findings_has_blocking "$entry"; then
            covered=1
            break
        fi
    done

    # change-review: ancestor-containment against the recorded tip
    if [ "$covered" -eq 0 ]; then
        for entry in "$REVIEW_LOG_DIR"/*-change-review.md; do
            [ -f "$entry" ] || continue
            entry_head_sha=$(extract_field "$entry" "head-sha")
            [ -z "$entry_head_sha" ] && continue
            if git merge-base --is-ancestor "$commit" "$entry_head_sha" 2>/dev/null && ! findings_has_blocking "$entry"; then
                covered=1
                break
            fi
        done
    fi

    if [ "$covered" -eq 0 ]; then
        echo "ERROR: commit $commit is not covered by any passing review-log entry"
        FAIL=1
    fi
done

# Final merged diff must also match at least one passing change-review entry
final_diff_hash=$(git diff "$BASE"..HEAD 2>/dev/null | sha256sum | cut -d' ' -f1)
final_covered=0
for entry in "$REVIEW_LOG_DIR"/*-change-review.md; do
    [ -f "$entry" ] || continue
    entry_diff_hash=$(extract_field "$entry" "diff-hash")
    if [ "$entry_diff_hash" = "$final_diff_hash" ] && ! findings_has_blocking "$entry"; then
        final_covered=1
        break
    fi
done
if [ "$final_covered" -eq 0 ]; then
    echo "ERROR: the final merged diff (merge-base($BASE, HEAD)) does not match any passing change-review entry"
    FAIL=1
fi

[ "$FAIL" -eq 0 ] && echo "OK: all commits in range are covered by a passing review-log entry"
exit $FAIL
```

- [ ] **Step 2: Make it executable**

Run: `chmod +x scripts/ci-review-containment-check.sh`

- [ ] **Step 3: Add a new CI job to `.github/workflows/pmb-health.yml`**

Find the end of the `mb-doctor-self-check` job (the last job in the file):
```yaml
  mb-doctor-self-check:
    name: MB Doctor Self-Check
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v6.0.2

      - name: Run mb doctor on this repo
        shell: bash
        run: MB_HOME="$(pwd)" bash scripts/mb.sh doctor
```

Add a new job immediately after it (same indentation level as the other top-level jobs):
```yaml
  review-gate-containment:
    name: Review Gate Containment (Layer 3)
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v6.0.2
        with:
          fetch-depth: 0

      - name: Verify every commit is covered by a passing review-log entry
        shell: bash
        run: bash scripts/ci-review-containment-check.sh
```

**Manual step, not automated by this task:** wiring `review-gate-containment` into branch protection's required-status-checks list is a GitHub settings change — CONFIRM-tier per `standards/SECURITY-GUARDRAILS.md` ("CI/CD changes"). This job ships and runs (visibly, non-blocking) as part of this task; making it *required* needs explicit user action via `gh api` or the GitHub UI, same as the spec's "Manual step, not self-service" note.

- [ ] **Step 4: Write `tests/test-ci-review-containment.sh` (Testing item #6's fixtures)**

```sh
#!/usr/bin/env bash
# tests/test-ci-review-containment.sh — fixtures for scripts/ci-review-containment-check.sh
set -u

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$REPO_ROOT/tests/helpers/assert.sh"

echo "=== CI review-containment check tests ==="

setup_repo() {
  local dir
  dir="$(mktemp -d 2>/dev/null || mktemp -d -t mb-containment-test)"
  git -C "$dir" init -q -b main
  git -C "$dir" config user.email "test@example.com"
  git -C "$dir" config user.name "Test"
  echo "base" > "$dir/f.txt"
  git -C "$dir" add f.txt
  git -C "$dir" commit -q -m "base"
  mkdir -p "$dir/docs/review-log"
  printf '%s' "$dir"
}

write_code_review_entry() {
  # write_code_review_entry <dir> <parent-sha> <diff-hash> <blocking:true|false>
  local dir="$1" parent="$2" diffhash="$3" blocking="$4"
  local blocking_col="false"
  [ "$blocking" = "true" ] && blocking_col="true"
  cat > "$dir/docs/review-log/2026-08-12-${diffhash:0:7}-code-review.md" <<EOF
---
type: code-review
diff-hash: $diffhash
head-sha: $parent
verdict: Approve
---

| Domain | Severity | Location | Evidence | Basis | Impact | Recommendation | Blocking |
|---|---|---|---|---|---|---|---|
| Security | Low | f.txt:1 | n/a | VERIFIED | n/a | n/a | $blocking_col |
EOF
}

write_change_review_entry() {
  # write_change_review_entry <dir> <head-sha> <diff-hash> <blocking:true|false>
  local dir="$1" headsha="$2" diffhash="$3" blocking="$4"
  local blocking_col="No"
  [ "$blocking" = "true" ] && blocking_col="Yes"
  cat > "$dir/docs/review-log/2026-08-12-${diffhash:0:7}-change-review.md" <<EOF
---
type: change-review
diff-hash: $diffhash
head-sha: $headsha
verdict: Clean
---

| Domain | Severity | Location | Evidence | Basis | Impact | Recommendation | Blocking | Confidence |
|---|---|---|---|---|---|---|---|---|
| Security | Low | f.txt:1 | n/a | llm | n/a | n/a | $blocking_col | High |
EOF
}

# ── clean linear chain: each commit individually code-reviewed ──────────────────────────────
echo ""
echo "--- clean linear chain: every commit has its own passing code-review entry ---"
D1="$(setup_repo)"
parent1=$(git -C "$D1" rev-parse HEAD)
echo "line two" >> "$D1/f.txt"
git -C "$D1" add f.txt
diffhash1=$(git -C "$D1" diff --cached "$parent1" 2>/dev/null | sha256sum | cut -d' ' -f1)
# compute the diff the same way the check does: git diff <parent> <commit> AFTER commit exists
git -C "$D1" commit -q -m "c1"
commit1=$(git -C "$D1" rev-parse HEAD)
diffhash1=$(git -C "$D1" diff "$parent1" "$commit1" | sha256sum | cut -d' ' -f1)
write_code_review_entry "$D1" "$parent1" "$diffhash1" "false"

parent2="$commit1"
echo "line three" >> "$D1/f.txt"
git -C "$D1" add f.txt
git -C "$D1" commit -q -m "c2"
commit2=$(git -C "$D1" rev-parse HEAD)
diffhash2=$(git -C "$D1" diff "$parent2" "$commit2" | sha256sum | cut -d' ' -f1)
write_code_review_entry "$D1" "$parent2" "$diffhash2" "false"

# also need a passing change-review entry covering the final merged diff for the aggregate check
finaldiffhash=$(git -C "$D1" diff "$parent1" "$commit2" | sha256sum | cut -d' ' -f1)
write_change_review_entry "$D1" "$commit2" "$finaldiffhash" "false"

git -C "$D1" branch main "$commit2" -f 2>/dev/null || true
cd "$D1" && bash "$REPO_ROOT/scripts/ci-review-containment-check.sh" "$D1" > /tmp/cont1.txt 2>&1
rc=$?
cd - >/dev/null
assert_exit_zero $rc "clean linear chain (each commit individually code-reviewed) passes containment"

# ── orphan commit with no covering entry at all: must fail ──────────────────────────────────
echo ""
echo "--- orphan commit: no covering entry at all -- must fail ---"
D2="$(setup_repo)"
base2=$(git -C "$D2" rev-parse HEAD)
echo "orphan change" >> "$D2/f.txt"
git -C "$D2" add f.txt
git -C "$D2" commit -q -m "orphan, never reviewed"
git -C "$D2" branch main "$(git -C "$D2" rev-parse HEAD)" -f 2>/dev/null || true
bash "$REPO_ROOT/scripts/ci-review-containment-check.sh" "$D2" > /tmp/cont2.txt 2>&1
rc=$?
if [ "$rc" -eq 0 ]; then
  echo "FAIL: an orphan commit with no review-log entry passed containment"
  exit 1
fi
assert_contains "$(cat /tmp/cont2.txt)" "not covered" "an orphan commit with no covering entry at all fails containment"

# ── misleading verdict line: Blocking:true in the table despite verdict: Approve ────────────
echo ""
echo "--- misleading verdict: a Blocking:true row must not count as coverage, even with verdict: Approve ---"
D3="$(setup_repo)"
parent3=$(git -C "$D3" rev-parse HEAD)
echo "risky change" >> "$D3/f.txt"
git -C "$D3" add f.txt
git -C "$D3" commit -q -m "c1"
commit3=$(git -C "$D3" rev-parse HEAD)
diffhash3=$(git -C "$D3" diff "$parent3" "$commit3" | sha256sum | cut -d' ' -f1)
write_code_review_entry "$D3" "$parent3" "$diffhash3" "true"
bash "$REPO_ROOT/scripts/ci-review-containment-check.sh" "$D3" > /tmp/cont3.txt 2>&1
rc=$?
if [ "$rc" -eq 0 ]; then
  echo "FAIL: an entry with a Blocking:true finding row counted as coverage despite verdict: Approve"
  exit 1
fi
assert_contains "$(cat /tmp/cont3.txt)" "not covered" "a review-log entry with a Blocking:true row does not count as coverage, regardless of its verdict: line"

# ── squashed commit: no exact-SHA match, but ancestor-covered by a change-review entry ──────
echo ""
echo "--- squashed commit: covered via change-review ancestor-containment, not an exact code-review match ---"
D4="$(setup_repo)"
base4=$(git -C "$D4" rev-parse HEAD)
echo "squashed change" >> "$D4/f.txt"
git -C "$D4" add f.txt
git -C "$D4" commit -q -m "squashed, never individually code-reviewed"
squashed=$(git -C "$D4" rev-parse HEAD)
finaldiff4=$(git -C "$D4" diff "$base4" "$squashed" | sha256sum | cut -d' ' -f1)
write_change_review_entry "$D4" "$squashed" "$finaldiff4" "false"
bash "$REPO_ROOT/scripts/ci-review-containment-check.sh" "$D4" > /tmp/cont4.txt 2>&1
rc=$?
assert_exit_zero $rc "a squashed commit with no individual code-review entry is covered via change-review ancestor-containment"

rm -rf "$D1" "$D2" "$D3" "$D4"

print_summary
```

- [ ] **Step 5: Run the new suite**

Run: `bash tests/test-ci-review-containment.sh`
Expected: all assertions pass. If the "clean linear chain" fixture fails, double-check the diff-hash computation order matches exactly what the script computes (`git diff <parent> <commit>`, not `git diff --cached`) — this is the most likely source of a fixture/script mismatch.

- [ ] **Step 6: Register in `tests/run.sh`**

Find:
```sh
run_suite "review-gate-git-hooks" "$REPO_ROOT/tests/test-review-gate-git-hooks.sh"
```
Add immediately after:
```sh
run_suite "review-gate-git-hooks" "$REPO_ROOT/tests/test-review-gate-git-hooks.sh"
run_suite "ci-review-containment" "$REPO_ROOT/tests/test-ci-review-containment.sh"
```

- [ ] **Step 7: Run the full suite**

Run: `bash tests/run.sh 2>&1 | tail -30`
Expected: `All test suites passed.`

- [ ] **Step 8: Commit**

```bash
git add scripts/ci-review-containment-check.sh .github/workflows/pmb-health.yml \
        tests/test-ci-review-containment.sh tests/run.sh
git commit -m "feat: add Layer 3 CI containment check for review-log coverage"
```

---

### Task 14: Update `docs/HOOKS-GUIDE.md` (Review Gate + Git Hooks sections)

**Files:**
- Modify: `docs/HOOKS-GUIDE.md`
- Modify: `templates/docs/HOOKS-GUIDE.md`

- [ ] **Step 1: Rewrite the "Marker files" and atomic-consumption paragraphs in section 7 (Review Gate)**

Find:
```markdown
**Atomic consumption:** the marker is claimed via an atomic rename (`Move-Item`/`mv`) rather than a separate existence-check followed by delete, closing the TOCTOU window between the two steps — if the source doesn't exist, the rename simply fails, collapsing "does it exist" and "claim it" into one filesystem operation. The marker is consumed (renamed away and deleted) whether or not its hash matches — a stale marker from a diff that has since changed doesn't linger; a fresh review is required either way.
```

Replace with:
```markdown
**This hook only peeks now — it never consumes (added 2026-08-12).** Prior to the layered-enforcement redesign, this hook claimed the marker via an atomic rename (`Move-Item`/`mv`), the same TOCTOU-safe pattern still used today, just one layer down. The problem: this hook only ever sees the agent's own Bash tool calls — a command typed directly into the user's own terminal is structurally invisible to it, so the review-gate's actual enforcement provided no backstop for a user-run commit at all. The real git hooks (`.githooks/pre-commit`/`pre-push`, see "Git Hooks" below) are now the sole authoritative marker consumer, since they fire on `git commit`/`git push` regardless of who ran it. This hook still denies early with the same message, for fast feedback on the agent's own attempts — but it's a convenience layer now, not the security boundary. See `docs/superpowers/specs/2026-08-12-review-gate-layered-enforcement-design.md` for the full design and its explicitly accepted residual limitations (`--no-verify` and an unset `core.hooksPath` both still fully bypass the git-hook layer; only the CI containment check, described below, is genuinely unbypassable).
```

- [ ] **Step 2: Rewrite the "Git Hooks (versioned)" section's "The two hooks" subsection**

Find:
```markdown
**`.githooks/pre-push`** — delegates to the 7-check push gate:
- Unresolved merge conflicts or conflict markers
- Uncommitted working tree changes
- Missing `.gitattributes`
- Possible secrets in the push diff (AWS keys, API tokens, GitHub PATs)
- Files over 500 KB
- `mb validate` result (if `mb` is in PATH)
- Scans first pushes via `git log --not --remotes` when no upstream tracking ref exists

Dispatches to `scripts/pre-push-check.ps1` (Windows/pwsh) or `scripts/pre-push-check.sh` (POSIX/bash). Fails open — if the script errors unexpectedly, the push is allowed through.

**`.githooks/pre-commit`** — lightweight two-check gate before every commit:
- **Blocks** if `handoff.md` is staged (`handoff.md` is ephemeral and must not be committed)
- **Warns** if `CLAUDE_AUTOCOMPACT_PCT_OVERRIDE` is missing from `.claude/settings.json` (token budget auto-compaction may not be configured)
```

Replace with:
```markdown
**`.githooks/pre-push`** — delegates to the 8-check push gate:
- Unresolved merge conflicts or conflict markers
- Uncommitted working tree changes
- Missing `.gitattributes`
- Possible secrets in the push diff (AWS keys, API tokens, GitHub PATs)
- Files over 500 KB
- `mb validate` result (if `mb` is in PATH)
- Scans first pushes via `git log --not --remotes` when no upstream tracking ref exists
- **Review-gate marker consumption (added 2026-08-12)** — the sole authoritative consumer of `.claude/.change-review-ok`, fires regardless of who ran `git push`

Dispatches to `scripts/pre-push-check.ps1` (Windows/pwsh) or `scripts/pre-push-check.sh` (POSIX/bash). Fails open — if the script errors unexpectedly, the push is allowed through.

**`.githooks/pre-commit`** — became a delegator on 2026-08-12 (matching `pre-push`'s existing shape), dispatching to `scripts/pre-commit-check.ps1`/`.sh`, which runs three checks in order:
- **Blocks** if `handoff.md` is staged (`handoff.md` is ephemeral and must not be committed)
- **Warns** if `CLAUDE_AUTOCOMPACT_PCT_OVERRIDE` is missing from `.claude/settings.json`
- **Review-gate marker consumption (added 2026-08-12), ordered last** — the sole authoritative consumer of `.claude/.code-review-ok`, fires regardless of who ran `git commit`. Ordered last so that consuming the marker and then failing a later check doesn't burn a valid review for a commit that never happens; guards against consuming on an empty diff (nothing staged) so a no-op attempt doesn't waste a valid marker.
```

- [ ] **Step 3: Update "Verifying hook activation" mention of two hooks (no content change needed — already generic) and add a pointer to the new Layer 3 CI check**

Find:
```markdown
### Verifying hook activation

```bash
git config core.hooksPath       # should print: .githooks
ls .githooks/                   # should show: pre-push  pre-commit
mb doctor                       # check 4 reports [OK] for both
```

## Adding Per-Project Hooks
```

Replace with:
```markdown
### Verifying hook activation

```bash
git config core.hooksPath       # should print: .githooks
ls .githooks/                   # should show: pre-push  pre-commit
mb doctor                       # check 4 reports [OK] for both
```

### Layer 3 — CI containment check (the only genuinely unbypassable layer)

`--no-verify` bypasses Layer 2 for anyone (not just the agent), and `core.hooksPath` can be unset or never configured on a fresh clone — Layer 2 is best-effort, not hard enforcement. `scripts/ci-review-containment-check.sh`, wired into `.github/workflows/pmb-health.yml`'s `review-gate-containment` job, is the actual backstop: for every commit between `merge-base(HEAD, main)` and `HEAD`, it verifies a passing `docs/review-log/` entry covers it (see `docs/review-log/README.md` for the exact containment rule), independent of what any local hook did or didn't catch. This job is not yet wired into branch protection's required-status-checks as of this writing — that's a manual, CONFIRM-tier GitHub settings change (see `standards/SECURITY-GUARDRAILS.md`, "CI/CD changes") left for explicit user action.

## Adding Per-Project Hooks
```

- [ ] **Step 4: Mirror to `templates/docs/HOOKS-GUIDE.md` (trimmed — per its existing SYNC NOTE convention)**

Read the current trimmed content around the equivalent sections (`grep -n "Review Gate\|Git Hooks\|pre-commit\|pre-push" templates/docs/HOOKS-GUIDE.md`) and apply the same substance in trimmed form (no postmortem/bug-history prose, matching the file's existing style) — describe: Layer 1 now peek-only, Layer 2 (`.githooks/pre-commit` now a delegator) is the sole consumer, and a new Layer 3 CI containment check exists. Follow the exact trimming pattern already visible in the file (compare a section that already has both a full and trimmed version, e.g. "Review Gate," to see what level of detail the trimmed mirror keeps).

- [ ] **Step 5: Commit**

```bash
git add docs/HOOKS-GUIDE.md templates/docs/HOOKS-GUIDE.md
git commit -m "docs: document Layer 1 peek-only downgrade, Layer 2 pre-commit delegator, Layer 3 CI check"
```

---

## Final Verification (after all 14 tasks)

- [ ] Run the complete suite: `bash tests/run.sh 2>&1 | tail -40` — expect `All test suites passed.`
- [ ] Run `mb doctor` (or `MB_HOME="$(pwd)" bash scripts/mb.sh doctor`) — confirm no new WARN/FAIL introduced.
- [ ] Confirm Testing item #8's empirical merge-commit result (recorded in Task 8, Step 2) is written into `memory-bank/progress.md` as a completion note — this was explicitly unverified at design time (Known Limitation #4) and this plan is what resolves it from "unknown" to "documented fact."
- [ ] Re-read `docs/superpowers/specs/2026-08-12-review-gate-layered-enforcement-design.md`'s Files Changed table one more time and confirm every row has a corresponding task above — no silent scope drift.
