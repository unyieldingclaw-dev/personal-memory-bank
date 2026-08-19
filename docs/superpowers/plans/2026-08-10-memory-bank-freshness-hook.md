# Memory Bank Freshness Hook Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a new `TEMPLATE_OWNED` `PreToolUse` hook pair that warns on 1-2 consecutive `git commit`s with no `memory-bank/` touch and hard-blocks on 3+, so this doesn't require a human to notice and ask.

**Architecture:** `scripts/memory-bank-freshness.sh`/`.ps1` dot-source `_review-gate-lib.sh`/`.ps1` for worktree-safe root resolution, walk `git log` backward from HEAD (capped at 20 commits) counting how many consecutive commits didn't touch `memory-bank/`, and warn/deny based on that count — no persisted state. Registered exactly like `review-reminders`: `.claude/settings.json` + `templates/` mirror, `mb.sh`/`mb.ps1`'s init-copy and `TEMPLATE_OWNED` lists, `docs/HOOKS-GUIDE.md`.

**Tech Stack:** POSIX `sh` (bash-invoked) + PowerShell 7 (`pwsh`), matching every existing hook pair in this repo.

**Spec:** `docs/superpowers/specs/2026-08-10-memory-bank-freshness-hook-design.md` (committed `3e475ae`) — read it for full rationale on every design decision below; this plan does not re-justify them.

---

### Task 1: Bash hook (`scripts/memory-bank-freshness.sh`) + test suite

**Files:**
- Create: `scripts/memory-bank-freshness.sh`
- Create: `tests/test-memory-bank-freshness.sh`
- Modify: `tests/run.sh:33` (register the new suite)

- [ ] **Step 1: Write the test file (will fail — the hook doesn't exist yet)**

Create `tests/test-memory-bank-freshness.sh`:

```sh
#!/usr/bin/env bash
# tests/test-memory-bank-freshness.sh — behavior tests for memory-bank-freshness.sh/.ps1
#
# WHY this test exists: the hook (scripts/memory-bank-freshness.sh/.ps1) is a stateless
# git-log lookback that warns on 1-2 consecutive commits with no memory-bank/ touch and
# blocks on 3+, skips entirely inside worktrees or when the commit about to happen already
# touches memory-bank/ itself. See
# docs/superpowers/specs/2026-08-10-memory-bank-freshness-hook-design.md for the full design.
set -u

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$REPO_ROOT/tests/helpers/assert.sh"

echo "=== memory-bank-freshness tests ==="

TMPDIR_MBF="$(mktemp -d 2>/dev/null || mktemp -d -t mb-mbf-test)"
trap 'rm -rf "$TMPDIR_MBF"' EXIT

git -C "$TMPDIR_MBF" init -q -b main
git -C "$TMPDIR_MBF" config user.email "test@example.com"
git -C "$TMPDIR_MBF" config user.name "Test"
mkdir -p "$TMPDIR_MBF/memory-bank" "$TMPDIR_MBF/.claude"
echo "brief" > "$TMPDIR_MBF/memory-bank/activeContext.md"
echo "line one" > "$TMPDIR_MBF/file.txt"
git -C "$TMPDIR_MBF" add memory-bank file.txt
git -C "$TMPDIR_MBF" commit -q -m "initial (touches memory-bank)"

invoke_hook() {
  # invoke_hook <spawn-dir> <git-command-text>
  local spawn_dir="$1" command="$2"
  printf '{"tool_input":{"command":"%s"}}' "$command" \
    | (cd "$spawn_dir" && bash "$REPO_ROOT/scripts/memory-bank-freshness.sh" 2>/dev/null)
}

invoke_hook_ps1() {
  local spawn_dir="$1" command="$2"
  printf '{"tool_input":{"command":"%s"}}' "$command" \
    | (cd "$spawn_dir" && pwsh -NonInteractive -File "$REPO_ROOT/scripts/memory-bank-freshness.ps1" 2>/dev/null)
}

commit_non_mb() {
  # commit_non_mb <label> — appends to file.txt and commits, WITHOUT touching memory-bank/
  local label="$1"
  echo "$label" >> "$TMPDIR_MBF/file.txt"
  git -C "$TMPDIR_MBF" add file.txt
  git -C "$TMPDIR_MBF" commit -q -m "$label"
}

# ── streak 0: last commit touched memory-bank/ → silent ─────────────────────────────────────
echo ""
echo "--- streak 0: silent when the last commit already touched memory-bank/ ---"
echo "pending change" >> "$TMPDIR_MBF/file.txt"
git -C "$TMPDIR_MBF" add file.txt
resp=$(invoke_hook "$TMPDIR_MBF" "git commit -m test")
assert_not_contains "$resp" '"permissionDecision":"deny"' "streak 0 does not deny"
assert_not_contains "$resp" "MEMORY BANK" "streak 0 prints no warning text"
git -C "$TMPDIR_MBF" commit -q -m "streak-setup-1"   # lands it — HEAD is now 1 commit past the mb touch

# ── streak 1: warns, does not block ──────────────────────────────────────────────────────────
echo ""
echo "--- streak 1: warns but allows ---"
echo "pending change" >> "$TMPDIR_MBF/file.txt"
git -C "$TMPDIR_MBF" add file.txt
resp=$(invoke_hook "$TMPDIR_MBF" "git commit -m test")
assert_not_contains "$resp" '"permissionDecision":"deny"' "streak 1 does not deny"
assert_contains "$resp" "MEMORY BANK" "streak 1 prints a warning"
git -C "$TMPDIR_MBF" commit -q -m "streak-setup-2"

# ── streak 2: still warns, does not block ────────────────────────────────────────────────────
echo ""
echo "--- streak 2: still warns, still allows ---"
echo "pending change" >> "$TMPDIR_MBF/file.txt"
git -C "$TMPDIR_MBF" add file.txt
resp=$(invoke_hook "$TMPDIR_MBF" "git commit -m test")
assert_not_contains "$resp" '"permissionDecision":"deny"' "streak 2 does not deny"
assert_contains "$resp" "MEMORY BANK" "streak 2 prints a warning"
git -C "$TMPDIR_MBF" commit -q -m "streak-setup-3"

# ── streak 3: blocks (this commit does not touch memory-bank/) ──────────────────────────────
echo ""
echo "--- streak 3: blocks when this commit doesn't touch memory-bank/ ---"
echo "pending change" >> "$TMPDIR_MBF/file.txt"
git -C "$TMPDIR_MBF" add file.txt
resp=$(invoke_hook "$TMPDIR_MBF" "git commit -m test")
assert_contains "$resp" '"permissionDecision":"deny"' "streak 3 denies"
git -C "$TMPDIR_MBF" restore --staged --worktree file.txt

# ── current-commit exemption: streak 3, but THIS commit touches memory-bank/ ────────────────
echo ""
echo "--- current-commit exemption: allowed when this commit itself touches memory-bank/ ---"
echo "updated" >> "$TMPDIR_MBF/memory-bank/activeContext.md"
git -C "$TMPDIR_MBF" add memory-bank/activeContext.md
resp=$(invoke_hook "$TMPDIR_MBF" "git commit -m test")
assert_not_contains "$resp" '"permissionDecision":"deny"' "current-commit exemption allows a memory-bank-touching commit despite a stale streak"
assert_not_contains "$resp" "MEMORY BANK" "current-commit exemption prints no warning"
git -C "$TMPDIR_MBF" commit -q -m "memory-bank update"   # lands it — streak resets to 0

# ── -am handling: git diff HEAD (not --cached) catches an unstaged memory-bank/ edit ────────
echo ""
echo "--- -am handling: unstaged (but tracked) memory-bank/ edit is still detected ---"
for i in 1 2 3; do commit_non_mb "am-setup-$i"; done   # streak back to 3
echo "unstaged update" >> "$TMPDIR_MBF/memory-bank/activeContext.md"   # NOT staged
resp=$(invoke_hook "$TMPDIR_MBF" "git commit -am test")
assert_not_contains "$resp" '"permissionDecision":"deny"' "an unstaged memory-bank/ edit still satisfies the exemption (git diff HEAD, not --cached)"
git -C "$TMPDIR_MBF" checkout -q -- memory-bank/activeContext.md   # discard — don't actually commit

# ── worktree exemption: always skip inside a linked worktree ────────────────────────────────
echo ""
echo "--- worktree exemption: always skips, even with a stale streak ---"
WORKTREE_MBF="$(mktemp -d 2>/dev/null || mktemp -d -t mb-mbf-wt)"
rmdir "$WORKTREE_MBF"   # git worktree add requires the target not already exist
git -C "$TMPDIR_MBF" worktree add -q -b mbf-worktree-branch "$WORKTREE_MBF" main >/dev/null 2>&1
echo "pending change" >> "$WORKTREE_MBF/file.txt"
git -C "$WORKTREE_MBF" add file.txt
resp=$(invoke_hook "$WORKTREE_MBF" "git commit -m test")
assert_not_contains "$resp" '"permissionDecision":"deny"' "worktree exemption: no deny despite a >=3 streak on the shared history"
assert_not_contains "$resp" "MEMORY BANK" "worktree exemption: no warning either"
git -C "$TMPDIR_MBF" worktree remove -f "$WORKTREE_MBF" >/dev/null 2>&1
git -C "$TMPDIR_MBF" branch -D mbf-worktree-branch >/dev/null 2>&1

# ── no memory-bank/ directory: silent skip ───────────────────────────────────────────────────
echo ""
echo "--- no memory-bank/ directory: silent skip ---"
TMPDIR_NOMB="$(mktemp -d 2>/dev/null || mktemp -d -t mb-nomb-test)"
git -C "$TMPDIR_NOMB" init -q -b main
git -C "$TMPDIR_NOMB" config user.email "test@example.com"
git -C "$TMPDIR_NOMB" config user.name "Test"
echo "a" > "$TMPDIR_NOMB/a.txt"
git -C "$TMPDIR_NOMB" add a.txt
git -C "$TMPDIR_NOMB" commit -q -m "one"
echo "b" > "$TMPDIR_NOMB/b.txt"
git -C "$TMPDIR_NOMB" add b.txt
git -C "$TMPDIR_NOMB" commit -q -m "two"
echo "c" >> "$TMPDIR_NOMB/a.txt"
git -C "$TMPDIR_NOMB" add a.txt
resp=$(invoke_hook "$TMPDIR_NOMB" "git commit -m test")
assert_not_contains "$resp" '"permissionDecision":"deny"' "no memory-bank/ directory: does not deny"
assert_not_contains "$resp" "MEMORY BANK" "no memory-bank/ directory: does not warn"
rm -rf "$TMPDIR_NOMB"

# ── malformed/empty stdin: fails open ────────────────────────────────────────────────────────
echo ""
echo "--- malformed/empty stdin: fails open ---"
resp=$(printf '' | (cd "$TMPDIR_MBF" && bash "$REPO_ROOT/scripts/memory-bank-freshness.sh" 2>/dev/null))
rc=$?
assert_exit_zero $rc "empty stdin exits 0"
assert_not_contains "$resp" '"permissionDecision":"deny"' "empty stdin does not deny"

# ── PMB_MB_FRESHNESS_DISABLE=1: skips regardless of streak ─────────────────────────────────
echo ""
echo "--- PMB_MB_FRESHNESS_DISABLE=1: skips even with a >=3 streak ---"
echo "pending change" >> "$TMPDIR_MBF/file.txt"
git -C "$TMPDIR_MBF" add file.txt
resp=$(printf '{"tool_input":{"command":"git commit -m test"}}' \
  | (cd "$TMPDIR_MBF" && PMB_MB_FRESHNESS_DISABLE=1 bash "$REPO_ROOT/scripts/memory-bank-freshness.sh" 2>/dev/null))
assert_not_contains "$resp" '"permissionDecision":"deny"' "PMB_MB_FRESHNESS_DISABLE=1 suppresses the deny"
assert_not_contains "$resp" "MEMORY BANK" "PMB_MB_FRESHNESS_DISABLE=1 suppresses the warning too"
git -C "$TMPDIR_MBF" restore --staged --worktree file.txt

# ── lookback cap: streak clamps at 20, still denies ──────────────────────────────────────────
echo ""
echo "--- lookback cap: a history that never touches memory-bank/ within the cap still denies ---"
TMPDIR_CAP="$(mktemp -d 2>/dev/null || mktemp -d -t mb-cap-test)"
git -C "$TMPDIR_CAP" init -q -b main
git -C "$TMPDIR_CAP" config user.email "test@example.com"
git -C "$TMPDIR_CAP" config user.name "Test"
mkdir -p "$TMPDIR_CAP/memory-bank"
echo "brief" > "$TMPDIR_CAP/memory-bank/activeContext.md"
echo "0" > "$TMPDIR_CAP/file.txt"
git -C "$TMPDIR_CAP" add memory-bank file.txt
git -C "$TMPDIR_CAP" commit -q -m "initial (touches memory-bank, falls outside the 20-commit window)"
for i in $(seq 1 24); do
  echo "$i" >> "$TMPDIR_CAP/file.txt"
  git -C "$TMPDIR_CAP" add file.txt
  git -C "$TMPDIR_CAP" commit -q -m "non-mb-$i"
done
echo "pending" >> "$TMPDIR_CAP/file.txt"
git -C "$TMPDIR_CAP" add file.txt
resp=$(invoke_hook "$TMPDIR_CAP" "git commit -m test")
assert_contains "$resp" '"permissionDecision":"deny"' "lookback cap: still denies when memory-bank/ falls outside the 20-commit window"
rm -rf "$TMPDIR_CAP"

# ── bash/PowerShell parity ───────────────────────────────────────────────────────────────────
if command -v pwsh >/dev/null 2>&1; then
  echo ""
  echo "--- cross-shell parity: memory-bank-freshness.ps1 matches .sh on a >=3 streak ---"
  echo "pending change" >> "$TMPDIR_MBF/file.txt"
  git -C "$TMPDIR_MBF" add file.txt
  resp=$(invoke_hook_ps1 "$TMPDIR_MBF" "git commit -m test")
  assert_contains "$resp" '"permissionDecision":"deny"' "memory-bank-freshness.ps1 denies on the same >=3 streak the .sh hook denies on"
  git -C "$TMPDIR_MBF" restore --staged --worktree file.txt
else
  echo ""
  echo "--- cross-shell parity: SKIPPED (pwsh not installed on this machine) ---"
fi

print_summary
```

- [ ] **Step 2: Run the test to verify it fails**

Run:
```bash
cd "C:\Users\Mizzo\Claude\Personal-Memory-Bank"
chmod +x tests/test-memory-bank-freshness.sh
bash tests/test-memory-bank-freshness.sh
```
Expected: every `invoke_hook` call errors (bash: "No such file or directory") because `scripts/memory-bank-freshness.sh` doesn't exist yet — the `resp` variable ends up empty, and several `assert_contains`-for-deny/-for-warning checks FAIL (empty string contains neither).

- [ ] **Step 3: Write the implementation**

Create `scripts/memory-bank-freshness.sh`:

```sh
#!/usr/bin/env sh
# scripts/memory-bank-freshness.sh — PreToolUse hook for git commit. Warns when recent
# commits haven't touched memory-bank/, hard-blocks after 3 consecutive. Design rationale
# (why stateless git-log lookback, why worktree-exempt, why git commit only, why git diff
# HEAD not --cached) is in
# docs/superpowers/specs/2026-08-10-memory-bank-freshness-hook-design.md.
#
# WHY dot-source _review-gate-lib.sh for resolve_cd_root(): this hook needs the same
# worktree-safe root resolution review-reminders.sh already solved -- deriving root from the
# gated command's own leading `cd "<path>" &&` prefix, falling back to ambient
# `git rev-parse --show-toplevel`. Reusing it instead of reimplementing avoids drifting from
# that fix if it's ever corrected again.
. "$(dirname "$0")/_review-gate-lib.sh" 2>/dev/null || exit 0

BLOCK_THRESHOLD=3
LOOKBACK_CAP=20

input=$(cat 2>/dev/null)
[ -z "$input" ] && exit 0

# WHY match raw stdin instead of extracting the "command" field: same rationale as
# review-reminders.sh -- a grep/sed field extraction breaks on JSON-escaped quotes inside
# the command, silently truncating the match.
case "$input" in
    *'git commit'*) : ;;
    *) exit 0 ;;
esac

# Explicit opt-out, mirroring PMB_CONTRACT_HARD_BLOCK's env-var convention in check-contract.sh.
[ "${PMB_MB_FRESHNESS_DISABLE:-}" = "1" ] && exit 0

root=$(resolve_cd_root)
[ -z "$root" ] && root=$(git rev-parse --show-toplevel 2>/dev/null)
[ -z "$root" ] && exit 0
cd "$root" 2>/dev/null || exit 0

# No memory-bank/ at all -- harmless no-op outside a PMB-init'd repo.
[ -d "memory-bank" ] || exit 0

# Worktree check: --git-dir and --git-common-dir differ inside a linked worktree, match in
# the main checkout. This repo's own dominant workflow (subagent-driven-development on
# worktree branches) deliberately never touches memory-bank/ from inside a worktree -- see
# memory-bank/activeContext.md's "Never update or commit memory-bank/ from a subworktree"
# rule. Enforcing the streak inside worktrees would misfire on nearly every commit this
# repo itself makes.
git_dir=$(git rev-parse --git-dir 2>/dev/null)
git_common_dir=$(git rev-parse --git-common-dir 2>/dev/null)
[ -z "$git_dir" ] && exit 0
git_dir_abs=$(cd "$git_dir" 2>/dev/null && pwd)
git_common_dir_abs=$(cd "$git_common_dir" 2>/dev/null && pwd)
[ -z "$git_dir_abs" ] && exit 0
[ "$git_dir_abs" != "$git_common_dir_abs" ] && exit 0

deny() {
    printf '{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"deny","permissionDecisionReason":"%s"}}\n' "$1"
}

# Current-commit exemption: git diff HEAD (not --cached) captures staged AND unstaged
# tracked changes, so `git commit -am` picking up an unstaged memory-bank/ edit is handled
# correctly -- matches diff_hash()'s existing precedent in _review-gate-lib.sh. If this
# commit already touches memory-bank/, it IS the update; skip regardless of streak.
touched_now=$(git diff HEAD --name-only 2>/dev/null | grep -c '^memory-bank/')
[ "${touched_now:-0}" -gt 0 ] && exit 0

# Walk commits backward from HEAD, counting how many in a row have NOT touched
# memory-bank/, stopping at the first one that has (or at LOOKBACK_CAP). Written to a temp
# file first, not piped directly into `while read`, so the loop runs in the current shell
# instead of a pipe subshell -- a pipe subshell can't mutate $streak in the parent shell,
# so the count would silently reset to 0 after the loop otherwise.
tmp_log=$(mktemp)
git log --format=%H -n "$LOOKBACK_CAP" > "$tmp_log" 2>/dev/null

streak=0
while IFS= read -r sha; do
    touched=$(git show --name-only --format= "$sha" 2>/dev/null | grep -c '^memory-bank/')
    if [ "${touched:-0}" -gt 0 ]; then
        break
    fi
    streak=$((streak + 1))
done < "$tmp_log"
rm -f "$tmp_log"

if [ "$streak" -eq 0 ]; then
    exit 0
elif [ "$streak" -lt "$BLOCK_THRESHOLD" ]; then
    echo "⚠️  MEMORY BANK: $streak commit(s) in a row haven't touched memory-bank/. If this was significant work, update activeContext.md/progress.md before continuing."
else
    deny "MEMORY BANK STALE: $streak consecutive commits with no memory-bank/ update. Stage a memory-bank/ change (activeContext.md and/or progress.md) as part of this commit, or make a memory-bank-only commit first, then retry. (If you just merged a branch, this is expected -- write the merge summary now.)"
fi
exit 0
```

- [ ] **Step 4: Run the test to verify it passes**

Run:
```bash
cd "C:\Users\Mizzo\Claude\Personal-Memory-Bank"
chmod +x scripts/memory-bank-freshness.sh
bash tests/test-memory-bank-freshness.sh
```
Expected: `Results: N passed, 0 failed` for every non-pwsh-guarded assertion (the parity block prints "SKIPPED" until Task 2 lands `memory-bank-freshness.ps1`).

- [ ] **Step 5: Register the suite in `tests/run.sh`**

In `tests/run.sh`, after line 33 (`run_suite "review-reminders" ...`):

```bash
run_suite "review-reminders"     "$REPO_ROOT/tests/test-review-reminders.sh"
run_suite "memory-bank-freshness" "$REPO_ROOT/tests/test-memory-bank-freshness.sh"
```

- [ ] **Step 6: Run the full suite to confirm no regressions**

Run: `bash tests/run.sh`
Expected: all suites pass, including the new `memory-bank-freshness` one.

- [ ] **Step 7: Commit**

Hand this to the user (this repo's commit-review gate blocks the agent's own `git commit`):

```bash
cd "C:\Users\Mizzo\Claude\Personal-Memory-Bank"
git add scripts/memory-bank-freshness.sh tests/test-memory-bank-freshness.sh tests/run.sh
git commit -m "feat: add memory-bank-freshness.sh hook (bash) + tests"
```

---

### Task 2: PowerShell hook (`scripts/memory-bank-freshness.ps1`)

**Files:**
- Create: `scripts/memory-bank-freshness.ps1`
- Modify: `tests/test-memory-bank-freshness.sh` (parity block already written in Task 1 — no change needed, it activates automatically once this file exists)

- [ ] **Step 1: Confirm the parity test currently reports SKIPPED (or fails if pwsh is installed)**

Run: `bash tests/test-memory-bank-freshness.sh`
Expected: if `pwsh` is installed, the "cross-shell parity" block FAILS (`memory-bank-freshness.ps1` doesn't exist, so `invoke_hook_ps1` returns empty, the `assert_contains ... deny` check fails). If `pwsh` isn't installed, it prints SKIPPED — in that case, verify manually via `pwsh -NonInteractive -File scripts/memory-bank-freshness.ps1` after Step 2 that it at least parses without a syntax error (`pwsh -NonInteractive -Command "& { . 'scripts/memory-bank-freshness.ps1' }" ` is unnecessary; a bare execution with no stdin is enough to catch syntax errors, since it will hit `ReadToEnd()` and exit 0 on empty input).

- [ ] **Step 2: Write the implementation**

Create `scripts/memory-bank-freshness.ps1`:

```powershell
# scripts/memory-bank-freshness.ps1 — PreToolUse hook for git commit. Warns when recent
# commits haven't touched memory-bank/, hard-blocks after 3 consecutive. Design rationale
# (why stateless git-log lookback, why worktree-exempt, why git commit only, why git diff
# HEAD not --cached) is in
# docs/superpowers/specs/2026-08-10-memory-bank-freshness-hook-design.md.
$BlockThreshold = 3
$LookbackCap = 20

# Resolve-CdRoot is defined in _review-gate-lib.ps1 -- the same worktree-safe root
# resolution review-reminders.ps1 already needed for dispatched-subagent sessions. Dot-sourced
# inside the same try/catch so a missing/corrupt lib fails open, matching every other hook.
try {
    $raw = [Console]::In.ReadToEnd()
    if ([string]::IsNullOrWhiteSpace($raw)) { exit 0 }
    $cmd = ($raw | ConvertFrom-Json).tool_input.command
    . (Join-Path $PSScriptRoot "_review-gate-lib.ps1")
} catch { exit 0 }

if (-not $cmd) { exit 0 }
if ($cmd -notmatch 'git\s+commit\b') { exit 0 }

# Explicit opt-out, mirroring PMB_CONTRACT_HARD_BLOCK's env-var convention in check-contract.ps1.
if ($env:PMB_MB_FRESHNESS_DISABLE -eq '1') { exit 0 }

$cdRoot = Resolve-CdRoot -Cmd $cmd
$root = if ($cdRoot) { $cdRoot } else { git rev-parse --show-toplevel 2>$null }
if (-not $root) { exit 0 }

try { Set-Location $root } catch { exit 0 }

# No memory-bank/ at all -- harmless no-op outside a PMB-init'd repo.
if (-not (Test-Path "memory-bank" -PathType Container)) { exit 0 }

# Worktree check: --git-dir and --git-common-dir differ inside a linked worktree, match in
# the main checkout. This repo's own dominant workflow (subagent-driven-development on
# worktree branches) deliberately never touches memory-bank/ from inside a worktree -- see
# memory-bank/activeContext.md's "Never update or commit memory-bank/ from a subworktree"
# rule. Enforcing the streak inside worktrees would misfire on nearly every commit this
# repo itself makes.
$gitDir = git rev-parse --git-dir 2>$null
$gitCommonDir = git rev-parse --git-common-dir 2>$null
if (-not $gitDir) { exit 0 }
$gitDirAbs = (Resolve-Path $gitDir -ErrorAction SilentlyContinue).Path
$gitCommonDirAbs = (Resolve-Path $gitCommonDir -ErrorAction SilentlyContinue).Path
if (-not $gitDirAbs -or $gitDirAbs -ne $gitCommonDirAbs) { exit 0 }

function Deny {
    param([string]$Reason)
    @{
        hookSpecificOutput = @{
            hookEventName            = "PreToolUse"
            permissionDecision       = "deny"
            permissionDecisionReason = $Reason
        }
    } | ConvertTo-Json -Compress | Write-Output
}

# Current-commit exemption: git diff HEAD (not --cached) captures staged AND unstaged
# tracked changes, so `git commit -am` picking up an unstaged memory-bank/ edit is handled
# correctly -- matches Get-CommitDiffHash's existing precedent in _review-gate-lib.ps1.
$touchedNow = git diff HEAD --name-only 2>$null | Where-Object { $_ -like 'memory-bank/*' }
if ($touchedNow) { exit 0 }

# WHY @(...) around git log's output: a single-line result from an external command
# unwraps to a bare string in PowerShell, not a 1-element array -- foreach over a bare
# string iterates its CHARACTERS, not the (one) line. This exact unwrap class bit
# concurrent-session-claims' own build (2026-08-08, this repo) in a comparable spot; @(...)
# forces array coercion regardless of how many lines git log actually returns.
$shas = @(git log --format=%H -n $LookbackCap 2>$null)
$streak = 0
foreach ($sha in $shas) {
    $touched = git show --name-only --format= $sha 2>$null | Where-Object { $_ -like 'memory-bank/*' }
    if ($touched) { break }
    $streak++
}

if ($streak -eq 0) {
    exit 0
} elseif ($streak -lt $BlockThreshold) {
    Write-Host "⚠️  MEMORY BANK: $streak commit(s) in a row haven't touched memory-bank/. If this was significant work, update activeContext.md/progress.md before continuing."
} else {
    Deny "MEMORY BANK STALE: $streak consecutive commits with no memory-bank/ update. Stage a memory-bank/ change (activeContext.md and/or progress.md) as part of this commit, or make a memory-bank-only commit first, then retry. (If you just merged a branch, this is expected -- write the merge summary now.)"
}
exit 0
```

- [ ] **Step 3: Run the test suite to verify it passes**

Run: `bash tests/test-memory-bank-freshness.sh`
Expected: `Results: N passed, 0 failed` — the "cross-shell parity" block now runs (not SKIPPED, if `pwsh` is installed) and passes.

- [ ] **Step 4: Run the full suite to confirm no regressions**

Run: `bash tests/run.sh`
Expected: all suites pass.

- [ ] **Step 5: Commit**

```bash
cd "C:\Users\Mizzo\Claude\Personal-Memory-Bank"
git add scripts/memory-bank-freshness.ps1
git commit -m "feat: add memory-bank-freshness.ps1 hook (PowerShell)"
```

---

### Task 3: `templates/scripts/` mirrors

**Files:**
- Create: `templates/scripts/memory-bank-freshness.sh`
- Create: `templates/scripts/memory-bank-freshness.ps1`

- [ ] **Step 1: Copy both files byte-identical**

Run:
```bash
cd "C:\Users\Mizzo\Claude\Personal-Memory-Bank"
cp scripts/memory-bank-freshness.sh templates/scripts/memory-bank-freshness.sh
cp scripts/memory-bank-freshness.ps1 templates/scripts/memory-bank-freshness.ps1
chmod +x templates/scripts/memory-bank-freshness.sh
```

- [ ] **Step 2: Verify byte-identical**

Run:
```bash
cd "C:\Users\Mizzo\Claude\Personal-Memory-Bank"
diff scripts/memory-bank-freshness.sh templates/scripts/memory-bank-freshness.sh && echo "sh IDENTICAL"
diff scripts/memory-bank-freshness.ps1 templates/scripts/memory-bank-freshness.ps1 && echo "ps1 IDENTICAL"
```
Expected: both print `IDENTICAL`, `diff` prints nothing before it.

- [ ] **Step 3: Commit**

```bash
cd "C:\Users\Mizzo\Claude\Personal-Memory-Bank"
git add templates/scripts/memory-bank-freshness.sh templates/scripts/memory-bank-freshness.ps1
git commit -m "feat: mirror memory-bank-freshness hooks into templates/scripts/"
```

---

### Task 4: Wire into `.claude/settings.json` + template mirror

**Files:**
- Modify: `.claude/settings.json`
- Modify: `templates/.claude/settings.json`

- [ ] **Step 1: Add the hook to `.claude/settings.json`'s `PreToolUse` → `"Bash"` matcher**

In `.claude/settings.json`, the `PreToolUse` array's first entry (matcher `"Bash"`) currently has two hooks (`dangerous-commands`, `review-reminders`). Add a third:

```json
      {
        "matcher": "Bash",
        "hooks": [
          {
            "type": "command",
            "command": "pwsh -NonInteractive -File scripts/dangerous-commands.ps1 2>/dev/null || bash scripts/dangerous-commands.sh 2>/dev/null || true"
          },
          {
            "type": "command",
            "command": "pwsh -NonInteractive -File scripts/review-reminders.ps1 2>/dev/null || bash scripts/review-reminders.sh 2>/dev/null || true"
          },
          {
            "type": "command",
            "command": "pwsh -NonInteractive -File scripts/memory-bank-freshness.ps1 2>/dev/null || bash scripts/memory-bank-freshness.sh 2>/dev/null || true"
          }
        ]
      },
```

- [ ] **Step 2: Same addition to `templates/.claude/settings.json`**

Same third hook entry, same matcher, same position (this file's `PreToolUse` → `"Bash"` array today has `dangerous-commands` then `review-reminders`, identical structure to the file above).

- [ ] **Step 3: Validate both are well-formed JSON**

Run:
```bash
cd "C:\Users\Mizzo\Claude\Personal-Memory-Bank"
python3 -c "import json; json.load(open('.claude/settings.json'))" && echo ".claude/settings.json OK"
python3 -c "import json; json.load(open('templates/.claude/settings.json'))" && echo "templates/.claude/settings.json OK"
```
Expected: both print `OK`, no `json.decoder.JSONDecodeError`.

- [ ] **Step 4: Live-verify the hook actually fires through the real settings.json chain**

Run (simulates exactly what Claude Code's hook runner invokes, from a scratch repo with a stale memory-bank, using the same command string as settings.json):

```bash
cd "C:\Users\Mizzo\Claude\Personal-Memory-Bank"
TMPDIR_LIVE="$(mktemp -d)"
git -C "$TMPDIR_LIVE" init -q -b main
git -C "$TMPDIR_LIVE" config user.email "test@example.com"
git -C "$TMPDIR_LIVE" config user.name "Test"
mkdir -p "$TMPDIR_LIVE/memory-bank"
echo "brief" > "$TMPDIR_LIVE/memory-bank/activeContext.md"
echo "1" > "$TMPDIR_LIVE/file.txt"
git -C "$TMPDIR_LIVE" add memory-bank file.txt
git -C "$TMPDIR_LIVE" commit -q -m "initial"
for i in 1 2 3; do echo "$i" >> "$TMPDIR_LIVE/file.txt"; git -C "$TMPDIR_LIVE" add file.txt; git -C "$TMPDIR_LIVE" commit -q -m "non-mb-$i"; done
echo "pending" >> "$TMPDIR_LIVE/file.txt"
git -C "$TMPDIR_LIVE" add file.txt
printf '{"tool_input":{"command":"git commit -m test"}}' | (cd "$TMPDIR_LIVE" && pwsh -NonInteractive -File "$PWD/../../scripts/memory-bank-freshness.ps1" 2>/dev/null || bash "$PWD/../../scripts/memory-bank-freshness.sh" 2>/dev/null || true)
rm -rf "$TMPDIR_LIVE"
```
Expected: prints a line containing `"permissionDecision":"deny"` and `"MEMORY BANK STALE"`.

- [ ] **Step 5: Commit**

```bash
cd "C:\Users\Mizzo\Claude\Personal-Memory-Bank"
git add .claude/settings.json templates/.claude/settings.json
git commit -m "feat: wire memory-bank-freshness hook into PreToolUse Bash matcher"
```

---

### Task 5: `mb.sh` registration (init copy loop, TEMPLATE_OWNED, lib-presence check)

**Files:**
- Modify: `scripts/mb.sh:518-524` (`invoke_init`'s copy loop)
- Modify: `scripts/mb.sh:1713-1716` (`invoke_upgrade`'s `TEMPLATE_OWNED` array)
- Modify: `scripts/check-review-gate-lib-presence.sh` (extend the shared lib-presence check)
- Modify: `tests/test-mb-init.sh` (regression test, same pattern as the existing `review-reminders.sh` one)
- Modify: `tests/test-mb-upgrade.sh` (regression test, same pattern as the existing `review-reminders.sh` one)

- [ ] **Step 1: Add to `invoke_init`'s copy loop**

In `scripts/mb.sh`, find:

```bash
                  review-reminders.sh review-reminders.ps1 \
                  review-reminders-post.sh review-reminders-post.ps1 \
                  _review-gate-lib.sh _review-gate-lib.ps1; do
```

Replace with:

```bash
                  review-reminders.sh review-reminders.ps1 \
                  review-reminders-post.sh review-reminders-post.ps1 \
                  memory-bank-freshness.sh memory-bank-freshness.ps1 \
                  _review-gate-lib.sh _review-gate-lib.ps1; do
```

- [ ] **Step 2: Add to `invoke_upgrade`'s `TEMPLATE_OWNED` array**

In `scripts/mb.sh`, find:

```bash
        "scripts/review-reminders-post.sh"
        "scripts/review-reminders-post.ps1"
        "scripts/_review-gate-lib.sh"
        "scripts/_review-gate-lib.ps1"
```

Replace with:

```bash
        "scripts/review-reminders-post.sh"
        "scripts/review-reminders-post.ps1"
        "scripts/memory-bank-freshness.sh"
        "scripts/memory-bank-freshness.ps1"
        "scripts/_review-gate-lib.sh"
        "scripts/_review-gate-lib.ps1"
```

- [ ] **Step 3: Extend `check-review-gate-lib-presence.sh` to also cover this hook**

This hook has the same dot-sourced-lib dependency `review-reminders.sh`/`.ps1` already have — extend the existing shared check rather than adding a parallel one. In `scripts/check-review-gate-lib-presence.sh`, replace:

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

with:

```sh
if { [ -f "$dir/review-reminders.sh" ] || [ -f "$dir/review-reminders-post.sh" ] || [ -f "$dir/memory-bank-freshness.sh" ]; } && [ ! -f "$dir/_review-gate-lib.sh" ]; then
    echo "ERROR: $dir/_review-gate-lib.sh missing but a hook that dot-sources it is present -- that hook will fail open (gate silently disabled)"
    fail=1
fi
if { [ -f "$dir/review-reminders.ps1" ] || [ -f "$dir/review-reminders-post.ps1" ] || [ -f "$dir/memory-bank-freshness.ps1" ]; } && [ ! -f "$dir/_review-gate-lib.ps1" ]; then
    echo "ERROR: $dir/_review-gate-lib.ps1 missing but a hook that dot-sources it is present -- that hook will fail open (gate silently disabled)"
    fail=1
fi
```

- [ ] **Step 4: Verify the presence check still passes against this repo's own `scripts/`**

Run: `bash scripts/check-review-gate-lib-presence.sh scripts`
Expected: exit code 0, no ERROR lines (both `_review-gate-lib.sh`/`.ps1` and `memory-bank-freshness.sh`/`.ps1` are present after Tasks 1-2).

- [ ] **Step 5: Add a regression test to `tests/test-mb-init.sh`**

Both `mb.sh`'s copy loop AND `mb.ps1`'s copy loop are exercised here — `test-mb-init.sh` only invokes the bash entrypoint, but that entrypoint's copy loop is responsible for placing both the `.sh` and `.ps1` variants on disk, so this one test covers both extensions. Following the exact pattern already used for `_review-gate-lib.sh`/`.ps1` (the file's own comment explains why: a file only reachable via dot-sourcing, not referenced directly in `settings.json`, needs its own explicit init-copy-loop entry or a fresh `mb init` ships a settings.json referencing a hook that never actually gets copied — the same class of gap this new hook has too), insert after that block:

```bash
# memory-bank-freshness.sh/.ps1 are invoked directly by templates/.claude/settings.json,
# same as review-reminders.sh/.ps1 above -- needs the same explicit copy-loop entry or a
# fresh mb init ships a settings.json referencing a hook script that was never copied.
for f in memory-bank-freshness.sh memory-bank-freshness.ps1; do
  assert_file_exists "$TMPDIR_INIT/scripts/$f" "mb init creates scripts/$f"
done
```

- [ ] **Step 6: Add a regression test to `tests/test-mb-upgrade.sh`**

Following the exact pattern already used for the `_review-gate-lib.sh`/`.ps1` block, insert after it:

```bash
# ── Template sync: memory-bank-freshness.sh/.ps1 are TEMPLATE_OWNED too ──────
echo ""
echo "--- template sync: restores memory-bank-freshness TEMPLATE_OWNED scripts ---"

rm -f "$TMPDIR_UP/scripts/memory-bank-freshness.sh" "$TMPDIR_UP/scripts/memory-bank-freshness.ps1"
assert_file_not_exists "$TMPDIR_UP/scripts/memory-bank-freshness.sh" "memory-bank-freshness.sh absent before upgrade"

output=$(cd "$TMPDIR_UP" && MB_HOME="$REPO_ROOT" bash "$MB" upgrade 2>&1)
assert_exit_zero $? "mb upgrade exits 0"
assert_file_exists "$TMPDIR_UP/scripts/memory-bank-freshness.sh" "upgrade restores TEMPLATE_OWNED memory-bank-freshness.sh"
assert_file_exists "$TMPDIR_UP/scripts/memory-bank-freshness.ps1" "upgrade restores TEMPLATE_OWNED memory-bank-freshness.ps1"
```

- [ ] **Step 7: Run both test suites to confirm they pass**

Run: `bash tests/test-mb-init.sh && bash tests/test-mb-upgrade.sh`
Expected: both pass, including the two new regression blocks.

- [ ] **Step 8: Commit**

```bash
cd "C:\Users\Mizzo\Claude\Personal-Memory-Bank"
git add scripts/mb.sh scripts/check-review-gate-lib-presence.sh tests/test-mb-init.sh tests/test-mb-upgrade.sh
git commit -m "feat: register memory-bank-freshness hook in mb.sh init/upgrade + lib-presence check"
```

---

### Task 6: `mb.ps1` registration (upgrade-analysis, init copy, TEMPLATE_OWNED, lib-presence check)

**Files:**
- Modify: `scripts/mb.ps1:157-186` (`Get-MbUpgradeAnalysis`'s `$templateOwned`)
- Modify: `scripts/mb.ps1:692-747` (`Invoke-Init`'s copy loop)
- Modify: `scripts/mb.ps1:1921-1990` (`Invoke-Upgrade`'s `TEMPLATE_OWNED` array)
- Modify: `scripts/mb.ps1:985-1007` (`Show-Doctor`'s lib-presence check)

- [ ] **Step 1: Add to `Get-MbUpgradeAnalysis`'s `$templateOwned`**

In `scripts/mb.ps1`, find:

```powershell
        'scripts/review-reminders.ps1',   'scripts/review-reminders.sh',
        'scripts/review-reminders-post.ps1', 'scripts/review-reminders-post.sh',
        'scripts/_review-gate-lib.sh',    'scripts/_review-gate-lib.ps1'
    )
```

Replace with:

```powershell
        'scripts/review-reminders.ps1',   'scripts/review-reminders.sh',
        'scripts/review-reminders-post.ps1', 'scripts/review-reminders-post.sh',
        'scripts/memory-bank-freshness.ps1', 'scripts/memory-bank-freshness.sh',
        'scripts/_review-gate-lib.sh',    'scripts/_review-gate-lib.ps1'
    )
```

- [ ] **Step 2: Add to `Invoke-Init`'s copy loop**

In `scripts/mb.ps1`, find:

```powershell
    foreach ($script in @("dangerous-commands.sh","dangerous-commands.ps1","check-contract.sh","check-contract.ps1","update-reviewed.sh","update-reviewed.ps1","pre-push-check.sh","pre-push-check.ps1","delegation-depth-check.sh","delegation-depth-check.ps1","pre-compact-check.sh","pre-compact-check.ps1","review-reminders.sh","review-reminders.ps1","review-reminders-post.sh","review-reminders-post.ps1","_review-gate-lib.sh","_review-gate-lib.ps1")) {
```

Replace with:

```powershell
    foreach ($script in @("dangerous-commands.sh","dangerous-commands.ps1","check-contract.sh","check-contract.ps1","update-reviewed.sh","update-reviewed.ps1","pre-push-check.sh","pre-push-check.ps1","delegation-depth-check.sh","delegation-depth-check.ps1","pre-compact-check.sh","pre-compact-check.ps1","review-reminders.sh","review-reminders.ps1","review-reminders-post.sh","review-reminders-post.ps1","memory-bank-freshness.sh","memory-bank-freshness.ps1","_review-gate-lib.sh","_review-gate-lib.ps1")) {
```

- [ ] **Step 3: Add to `Invoke-Upgrade`'s `TEMPLATE_OWNED`-equivalent array**

In `scripts/mb.ps1`, find (inside `Invoke-Upgrade`, same block already shown in the earlier `mb.sh` task's excerpt but this is the PowerShell array):

```powershell
        "scripts/review-reminders.sh"
        "scripts/review-reminders.ps1"
        "scripts/review-reminders-post.sh"
        "scripts/review-reminders-post.ps1"
        "scripts/_review-gate-lib.sh"
        "scripts/_review-gate-lib.ps1"
```

Replace with:

```powershell
        "scripts/review-reminders.sh"
        "scripts/review-reminders.ps1"
        "scripts/review-reminders-post.sh"
        "scripts/review-reminders-post.ps1"
        "scripts/memory-bank-freshness.sh"
        "scripts/memory-bank-freshness.ps1"
        "scripts/_review-gate-lib.sh"
        "scripts/_review-gate-lib.ps1"
```

- [ ] **Step 4: Extend `Show-Doctor`'s inline lib-presence check**

In `scripts/mb.ps1`, find:

```powershell
        if ((Test-Path "scripts/review-reminders.ps1") -or (Test-Path "scripts/review-reminders-post.ps1")) {
            if (-not (Test-Path "scripts/_review-gate-lib.ps1")) {
                Write-Host "[ERROR] scripts/_review-gate-lib.ps1 missing but scripts/review-reminders.ps1/-post.ps1 present -- the review-gate hook will fail open (gate silently disabled)" -ForegroundColor Red
            }
        }
        if ((Test-Path "scripts/review-reminders.sh") -or (Test-Path "scripts/review-reminders-post.sh")) {
            if (-not (Test-Path "scripts/_review-gate-lib.sh")) {
                Write-Host "[ERROR] scripts/_review-gate-lib.sh missing but scripts/review-reminders.sh/-post.sh present -- the review-gate hook will fail open (gate silently disabled)" -ForegroundColor Red
            }
        }
```

Replace with:

```powershell
        if ((Test-Path "scripts/review-reminders.ps1") -or (Test-Path "scripts/review-reminders-post.ps1") -or (Test-Path "scripts/memory-bank-freshness.ps1")) {
            if (-not (Test-Path "scripts/_review-gate-lib.ps1")) {
                Write-Host "[ERROR] scripts/_review-gate-lib.ps1 missing but a hook that dot-sources it is present -- that hook will fail open (gate silently disabled)" -ForegroundColor Red
            }
        }
        if ((Test-Path "scripts/review-reminders.sh") -or (Test-Path "scripts/review-reminders-post.sh") -or (Test-Path "scripts/memory-bank-freshness.sh")) {
            if (-not (Test-Path "scripts/_review-gate-lib.sh")) {
                Write-Host "[ERROR] scripts/_review-gate-lib.sh missing but a hook that dot-sources it is present -- that hook will fail open (gate silently disabled)" -ForegroundColor Red
            }
        }
```

- [ ] **Step 5: Run `mb doctor`/`mb upgrade` tests**

Run: `bash tests/test-mb-doctor.sh && bash tests/test-mb-upgrade.sh`
Expected: both pass. `test-mb-upgrade.sh`'s regression coverage for both `memory-bank-freshness.sh` and `.ps1` was already added in Task 5 Step 6 — that suite is bash-driven but exercises `mb.sh`'s copy loop, which places both extensions on disk, so no separate PowerShell-specific test file is needed here.

- [ ] **Step 6: Commit**

```bash
cd "C:\Users\Mizzo\Claude\Personal-Memory-Bank"
git add scripts/mb.ps1
git commit -m "feat: register memory-bank-freshness hook in mb.ps1 init/upgrade/doctor"
```

---

### Task 7: Documentation (`docs/HOOKS-GUIDE.md` + trimmed template mirror)

**Files:**
- Modify: `docs/HOOKS-GUIDE.md` (new section 9, after section 8)
- Modify: `templates/docs/HOOKS-GUIDE.md` (trimmed mirror, per its existing SYNC NOTE convention)

- [ ] **Step 1: Add the new section to `docs/HOOKS-GUIDE.md`**

Insert immediately after the "Review Gate Failure Recovery" section (before `## Git Hooks (versioned)`):

```markdown
### 9. Memory Bank Freshness Check (`PreToolUse` — Bash tool)

Fires before every Bash tool call matching `git commit`. Walks `git log` backward from HEAD, counting how many consecutive recent commits have not touched `memory-bank/`. Warns (advisory text, allows the commit) on a streak of 1-2; denies on a streak of 3 or more, unless the commit about to happen already touches `memory-bank/` itself. Mechanically enforces CLAUDE.md's "update memory-bank after significant work" instruction instead of relying on advisory text alone — see `docs/superpowers/specs/2026-08-10-memory-bank-freshness-hook-design.md` for the full incident and design rationale. Implemented in `scripts/memory-bank-freshness.ps1` and `scripts/memory-bank-freshness.sh`.

**Stateless by design:** no counter file, no persisted state — every invocation re-derives the streak fresh from `git log`, bounded to the most recent 20 commits. This avoids the class of state-corruption bug a persisted counter would risk (see the concurrent-session-claims feature's own build history for examples of exactly that bug class in a comparable state file).

**Current-commit exemption:** checked via `git diff HEAD --name-only`, not `--cached` — this correctly captures a `git commit -am` picking up an unstaged, tracked `memory-bank/` edit, matching `Get-CommitDiffHash`'s existing precedent in `_review-gate-lib.ps1`/`.sh`.

**Skipped entirely inside a git worktree** (detected via `git rev-parse --git-dir` vs `--git-common-dir`): this repo's own dominant workflow (`subagent-driven-development` on worktree branches) deliberately never touches `memory-bank/` from inside a worktree, so enforcing the streak there would misfire on nearly every commit made that way. A worktree-merged branch's commits still count toward the streak once they land on the main checkout via fast-forward merge — if the habitual post-merge memory-bank commit is skipped, the very next unrelated commit on main can jump straight to a block with no graduated warning first. This is intentional, not a defect — see the deny message and the spec's "Interaction with fast-forward merges" section.

**Opt-out:** `PMB_MB_FRESHNESS_DISABLE=1` skips the check entirely, mirroring `PMB_CONTRACT_HARD_BLOCK`'s env-var convention in the Contract Scope Check above.
```

- [ ] **Step 2: Add the trimmed mirror to `templates/docs/HOOKS-GUIDE.md`**

Insert immediately after that file's own "Review Gate Failure Recovery" section (before `## Git Hooks (versioned)`), in this file's established shorter-form style (compare to how section 8 is trimmed there relative to the source):

```markdown
### 9. Memory Bank Freshness Check (`PreToolUse` — Bash tool)

Fires before every Bash tool call matching `git commit`. Walks `git log` backward from HEAD, counting consecutive recent commits that haven't touched `memory-bank/`. Warns (advisory, allows the commit) on a streak of 1-2; denies on 3+, unless the commit about to happen already touches `memory-bank/` itself. Stateless — no counter file, re-derived fresh from `git log` each time, bounded to 20 commits. Implemented in `scripts/memory-bank-freshness.ps1` and `scripts/memory-bank-freshness.sh`.

**Skipped entirely inside a git worktree** (`--git-dir` vs `--git-common-dir` differ there): worktree-based feature branches in this workflow deliberately never touch `memory-bank/` directly.

**Opt-out:** `PMB_MB_FRESHNESS_DISABLE=1` skips the check entirely.
```

- [ ] **Step 3: Commit**

```bash
cd "C:\Users\Mizzo\Claude\Personal-Memory-Bank"
git add docs/HOOKS-GUIDE.md templates/docs/HOOKS-GUIDE.md
git commit -m "docs: document the memory-bank-freshness hook in HOOKS-GUIDE.md"
```

---

### Task 8: Final full-suite verification

**Files:** none (verification only)

- [ ] **Step 1: Run the full test suite**

Run: `bash tests/run.sh`
Expected: every suite passes, including `memory-bank-freshness`, `mb init`, `mb upgrade`, `mb doctor`, `review-gate-lib-presence`.

- [ ] **Step 2: Run `mb doctor` against this repo itself**

Run: `pwsh -NonInteractive -File scripts/mb.ps1 doctor 2>&1 | grep -i "memory-bank-freshness\|_review-gate-lib" ` (or the bash equivalent if `pwsh` isn't installed: `bash scripts/mb.sh doctor 2>&1 | grep -i "memory-bank-freshness\|_review-gate-lib"`)
Expected: no `[ERROR]`/`ERROR` lines mentioning either file — both the hook and its lib dependency are present and correctly registered.

- [ ] **Step 3: Update the memory bank**

Update `memory-bank/activeContext.md`: mark `[NS-13]` as shipped (change its line from "Not started" to a brief shipped-summary, following this file's own established style for closing out a Next Steps item), and add a dated entry to `memory-bank/progress.md` summarizing the build (files touched, test count, any deviations from the spec found during implementation — if none, say so explicitly rather than omitting the note).

- [ ] **Step 4: Commit**

```bash
cd "C:\Users\Mizzo\Claude\Personal-Memory-Bank"
git add memory-bank/activeContext.md memory-bank/progress.md
git commit -m "docs: memory-bank entries for the memory-bank-freshness hook ship"
```

---

## Post-plan: this repo's own commit-review gate

Every commit above will be blocked by this repo's own `review-reminders.sh`/`.ps1` unless a `/code-review` (or `/change-review`) pass has run and written the matching marker first — and per this repo's established session pattern (see `memory-bank/progress.md`'s recurring notes on this), the agent's own attempts to write that marker have repeatedly hit the harness's self-attestation classifier. The reliable workaround used throughout this repo's history: run the real review command, then hand the exact `git add`/`git commit` commands to the user to run in their own terminal rather than attempting them as the agent.
