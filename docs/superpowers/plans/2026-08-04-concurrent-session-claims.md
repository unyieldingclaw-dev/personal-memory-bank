# Concurrent Session Claims Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Let multiple Claude Code sessions working the same PMB-managed repo at once (same main worktree, main+subworktrees, or several subworktrees) see what's already claimed, so a session reading a handoff doesn't duplicate or collide with another session's in-progress work.

**Architecture:** One gitignored JSON registry (`.claude/session-claims.json`), canonical in the main worktree, mutated under an `mkdir`-based lock with atomic temp-file-then-rename writes. Bash (`scripts/session-claims.sh`) and PowerShell (`scripts/session-claims.ps1`) twins expose `prune`/`list`/`claim`/`release`/`force-clear`/`notify`. A new read-only `SessionStart` hook prunes and surfaces live claims automatically (silent when empty). Next Steps items in `activeContext.md` get stable `[NS-N]` IDs so claims have something durable to reference instead of fuzzy-matching free text.

**Tech Stack:** POSIX shell + python3 (bash side, matching this repo's existing `check-contract.sh` convention), PowerShell 7+ native `ConvertFrom-Json`/`ConvertTo-Json` (no python3 dependency on that path), git.

**Correction from the design spec:** `docs/superpowers/specs/2026-08-04-concurrent-session-claims-design.md` said the new `SessionStart` hook should reuse `resolve_cd_root()`-style logic from `scripts/_review-gate-lib.sh`. That's not actually applicable — `resolve_cd_root()` extracts a path from a Bash tool's *gated command string* (e.g. a leading `cd "X" &&` before `git commit`), which doesn't exist in this context since nothing is being gated. The real need — "find the main worktree root from wherever this script is running" — already has an established, trusted primitive in this exact codebase: `git rev-parse --git-common-dir`, used identically in `mb.sh`'s `cmd_commit` subworktree check (`scripts/mb.sh:429`) and documented in `standards/MEMORY-BANK.md`'s Worktree Guidance section. This plan uses that instead.

---

## File Structure

| File | Responsibility |
|---|---|
| `scripts/session-claims.sh` | Bash implementation: root resolution, lock, prune/list/claim/release/force-clear/notify |
| `scripts/session-claims.ps1` | PowerShell twin, same CLI surface, native JSON (no python3 dependency) |
| `templates/scripts/session-claims.sh` / `.ps1` | Byte-identical mirrors shipped to adopted projects |
| `.claude/settings.json` / `templates/.claude/settings.json` | New `SessionStart` hook entry |
| `.gitignore` | New ignore entries for the claims file and lock directory |
| `scripts/mb.sh` / `scripts/mb.ps1` | Two new `doctor` checks (malformed claims file, stale lock) |
| `tests/test-session-claims.sh` | Full behavioral coverage, registered in `tests/run.sh` |
| `docs/SESSION-CLAIMS-GUIDE.md` | New guide, mirrors `docs/CONTRACTS-GUIDE.md`'s structure |
| `standards/MEMORY-BANK.md` | `[NS-N]` ID convention, claim-release-on-close-out rule |
| `CLAUDE.md` | Session-start / handoff protocol additions |
| `memory-bank/activeContext.md` | Retrofit existing Next Steps list with `[NS-N]` IDs |

---

## Task 1: Root resolution, lock primitives, `prune`/`list` (bash)

**Files:**
- Create: `scripts/session-claims.sh`
- Create: `tests/test-session-claims.sh`

- [ ] **Step 1: Write the failing test**

```bash
# tests/test-session-claims.sh
#!/usr/bin/env bash
# tests/test-session-claims.sh — tests for scripts/session-claims.sh (and, where noted,
# its PowerShell twin scripts/session-claims.ps1 — see the cross-tool section at the bottom).
set -u

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SC="$REPO_ROOT/scripts/session-claims.sh"
source "$REPO_ROOT/tests/helpers/assert.sh"
source "$REPO_ROOT/tests/setup.sh"

echo "=== session-claims.sh tests ==="

TMPDIR_SC="$(mktemp -d 2>/dev/null || mktemp -d -t sc-test)"
trap 'rm -rf "$TMPDIR_SC"' EXIT
setup_test_project "$TMPDIR_SC"
cd "$TMPDIR_SC" || exit 1

echo ""
echo "-- list on a repo with no claims file --"
OUT=$(bash "$SC" list)
CODE=$?
assert_exit_zero "$CODE" "list exits 0 with no claims file"
assert_contains "$OUT" '"claims": \[\]' "list prints an empty claims array"

echo ""
echo "-- prune creates the file --"
bash "$SC" prune >/dev/null
assert_file_exists ".claude/session-claims.json" "prune bootstraps the claims file"

echo ""
echo "-- prune drops expired entries, keeps live ones --"
python3 - <<'PYEOF'
import json
from datetime import datetime, timedelta, timezone
now = datetime.now(timezone.utc)
data = {"claims": [
    {"claim_id": "expired-owner", "ns_id": "NS-1", "item": "old",
     "claimed_at": (now - timedelta(hours=20)).isoformat(),
     "expires_at": (now - timedelta(hours=1)).isoformat()},
    {"claim_id": "live-owner", "ns_id": "NS-2", "item": "current",
     "claimed_at": now.isoformat(),
     "expires_at": (now + timedelta(hours=1)).isoformat()},
]}
with open(".claude/session-claims.json", "w") as f:
    json.dump(data, f)
PYEOF
OUT=$(bash "$SC" list)
assert_not_contains "$OUT" "expired-owner" "list/prune drops an expired entry"
assert_contains "$OUT" "live-owner" "list/prune keeps a live entry"

echo ""
echo "-- a stale lock directory (>30s) is stolen, not waited on forever --"
mkdir -p ".claude/session-claims.lock"
OLD_TS=$(date -d '@'$(( $(date +%s) - 60 )) '+%Y%m%d%H%M.%S' 2>/dev/null || date -j -f '%s' "$(( $(date +%s) - 60 ))" '+%Y%m%d%H%M.%S' 2>/dev/null)
touch -t "$OLD_TS" ".claude/session-claims.lock" 2>/dev/null || true
START=$(date +%s)
OUT=$(bash "$SC" list)
CODE=$?
END=$(date +%s)
assert_exit_zero "$CODE" "list succeeds after stealing a stale lock"
if [ $((END - START)) -lt 10 ]; then
  echo "  PASS: stale lock was stolen quickly, not waited out to a hang"
  PASS=$((PASS + 1))
else
  echo "  FAIL: took $((END - START))s — stale lock was not stolen"
  FAIL=$((FAIL + 1))
fi
assert_file_not_exists ".claude/session-claims.lock" "lock directory is removed after use"

echo ""
echo "-- a fresh (non-stale) lock is respected, not stolen --"
mkdir -p ".claude/session-claims.lock"
( sleep 1; rmdir ".claude/session-claims.lock" 2>/dev/null ) &
HOLDER_PID=$!
OUT=$(bash "$SC" list)
CODE=$?
wait "$HOLDER_PID" 2>/dev/null
assert_exit_zero "$CODE" "list eventually succeeds once a fresh lock is released"

echo ""
echo "-- resolving root from a subworktree points at the main worktree's claims file --"
git branch -q sub-branch 2>/dev/null
git worktree add -q "$TMPDIR_SC-sub" sub-branch 2>/dev/null
if [ -d "$TMPDIR_SC-sub" ]; then
  ( cd "$TMPDIR_SC-sub" && bash "$SC" claim --claim-id sub-session --item "from subworktree" >/dev/null )
  OUT=$(bash "$SC" list)
  assert_contains "$OUT" "from subworktree" "a claim written from a subworktree lands in the main worktree's file"
  ( cd "$TMPDIR_SC-sub" && git worktree remove --force "$TMPDIR_SC-sub" ) 2>/dev/null
fi

print_summary
exit $?
```

- [ ] **Step 2: Run test to verify it fails**

Run: `bash tests/test-session-claims.sh`
Expected: FAIL — `scripts/session-claims.sh` doesn't exist yet, every invocation errors.

- [ ] **Step 3: Write the implementation**

```bash
# scripts/session-claims.sh
#!/usr/bin/env bash
# scripts/session-claims.sh — coordinate multiple Claude Code sessions working the same repo.
# Maintains .claude/session-claims.json (canonical in the main worktree) recording which
# Next Steps item (or ad hoc task) each session currently claims, so a new session can tell
# what's already in progress instead of duplicating it. See docs/SESSION-CLAIMS-GUIDE.md.
#
# WHY resolve root via `git rev-parse --git-common-dir`, not resolve_cd_root(): that helper
# (scripts/_review-gate-lib.sh) extracts a path from a Bash tool's gated *command string* --
# irrelevant here, since no command is being gated. The actual need -- "find the main
# worktree root from wherever this is running" -- already has an established, trusted
# primitive in this repo: `git rev-parse --git-common-dir`, used identically in mb.sh's
# cmd_commit subworktree check (scripts/mb.sh:429) and documented in standards/MEMORY-BANK.md's
# Worktree Guidance.
#
# WHY no `set -e`: the `claim` action deliberately exits 1 on a real conflict (not an error),
# and the caller relies on capturing that via `$(...)`. Under `set -e`, a failing command
# substitution assignment aborts the script immediately, before the lock gets released --
# unlike a plain nonzero exit in a script without `-e`, this would leak the lock on every
# single conflict. `set -u` alone still catches unset-variable bugs.
#
# WHY python3 for JSON read/mutate: matches check-contract.sh's existing precedent for
# manipulating a JSON state file in this repo. Fails open (no-op, exit 0) if python3 is
# unavailable, same convention as check-contract.sh. session-claims.ps1 has no such
# dependency (native ConvertFrom-Json/ConvertTo-Json) -- on a Windows machine with pwsh
# available, the hook registration tries pwsh first, so this fallback rarely matters there.

set -u

resolve_claims_root() {
    common_git=$(git rev-parse --git-common-dir 2>/dev/null) || return 1
    [ -z "$common_git" ] && return 1
    realpath "$(dirname "$common_git")" 2>/dev/null
}

ROOT=$(resolve_claims_root) || exit 0
[ -z "$ROOT" ] && exit 0

CLAIMS_DIR="$ROOT/.claude"
CLAIMS_FILE="$CLAIMS_DIR/session-claims.json"
LOCK_DIR="$CLAIMS_DIR/session-claims.lock"

command -v python3 >/dev/null 2>&1 || exit 0

lock_mtime() {
    stat -c %Y "$LOCK_DIR" 2>/dev/null || stat -f %m "$LOCK_DIR" 2>/dev/null || echo 0
}

acquire_lock() {
    mkdir -p "$CLAIMS_DIR" 2>/dev/null
    tries=0
    while [ "$tries" -lt 20 ]; do
        if mkdir "$LOCK_DIR" 2>/dev/null; then
            return 0
        fi
        if [ -d "$LOCK_DIR" ]; then
            now=$(date +%s)
            age=$(( now - $(lock_mtime) ))
            if [ "$age" -gt 30 ]; then
                rmdir "$LOCK_DIR" 2>/dev/null
                continue
            fi
        fi
        tries=$((tries + 1))
        sleep 0.1
    done
    return 1
}

release_lock() {
    rmdir "$LOCK_DIR" 2>/dev/null || true
}

# Runs a python3 mutation against $CLAIMS_FILE under the lock. $1 = action
# (prune|list|claim|release|force-clear). Action-specific inputs are passed as PMB_* env
# vars by the caller. Prints the python script's stdout; caller checks the return code.
run_locked() {
    action="$1"
    acquire_lock || { echo "WARN: could not acquire session-claims lock, skipping" >&2; return 1; }
    out=$(PMB_CLAIMS_FILE="$CLAIMS_FILE" PMB_ACTION="$action" python3 - <<'PYEOF'
import json, os, sys
from datetime import datetime, timezone, timedelta

path = os.environ["PMB_CLAIMS_FILE"]
action = os.environ["PMB_ACTION"]

def now():
    return datetime.now(timezone.utc)

def parse(ts):
    return datetime.fromisoformat(ts.replace("Z", "+00:00"))

def load():
    try:
        with open(path) as f:
            data = json.load(f)
        claims = data.get("claims", [])
        return claims if isinstance(claims, list) else []
    except Exception:
        return []

def live(claims):
    result = []
    for c in claims:
        try:
            if parse(c["expires_at"]) > now():
                result.append(c)
        except Exception:
            continue  # malformed entry -- dropped by pruning, never preserved
    return result

def save(claims):
    tmp = path + ".tmp." + str(os.getpid())
    with open(tmp, "w") as f:
        json.dump({"claims": claims}, f, indent=2)
    os.replace(tmp, path)  # atomic on the same filesystem

try:
    claims = live(load())

    if action in ("prune", "list"):
        save(claims)
        print(json.dumps({"claims": claims}))

    elif action == "claim":
        claim_id = os.environ["PMB_CLAIM_ID"]
        item = os.environ["PMB_ITEM"]
        ns_id = os.environ.get("PMB_NS_ID", "")
        ttl_hours = float(os.environ.get("PMB_TTL_HOURS", "12"))

        def same_key(c):
            return c.get("ns_id") == ns_id if ns_id else c.get("item") == item

        conflict = next((c for c in claims if same_key(c) and c.get("claim_id") != claim_id), None)
        if conflict:
            print(json.dumps({"conflict": conflict}))
            sys.exit(1)

        # Drop any prior claim of our own on this same key -- re-claiming updates in
        # place instead of accumulating duplicate entries for the same session/item.
        remaining = [c for c in claims if not same_key(c)]
        entry = {
            "claim_id": claim_id,
            "ns_id": ns_id,
            "item": item,
            "claimed_at": now().isoformat(),
            "expires_at": (now() + timedelta(hours=ttl_hours)).isoformat(),
        }
        remaining.append(entry)
        save(remaining)
        print(json.dumps({"claim": entry}))

    elif action in ("release", "force-clear"):
        claim_id = os.environ.get("PMB_CLAIM_ID", "")
        ns_id = os.environ.get("PMB_NS_ID", "")
        item = os.environ.get("PMB_ITEM", "")
        # "release" with no ns_id/item is a bulk release of everything this session holds
        # (used at handoff, when the session is ending entirely). "force-clear" always
        # targets one specific entry -- clearing "everything owned by someone else" isn't
        # a real use case.
        bulk = action == "release" and not ns_id and not item

        removed = []
        remaining = []
        for c in claims:
            matches_owner = (action == "force-clear") or (c.get("claim_id") == claim_id)
            if bulk:
                matches_key = True
            else:
                matches_key = (ns_id and c.get("ns_id") == ns_id) or (not ns_id and item and c.get("item") == item)
            if matches_owner and matches_key and (bulk or not removed):
                removed.append(c)
                continue
            remaining.append(c)

        save(remaining)
        print(json.dumps({"removed": removed}))

    else:
        print(json.dumps({"error": "unknown action"}))
        sys.exit(2)

except SystemExit:
    raise
except Exception as e:
    print(json.dumps({"error": str(e)}))
    sys.exit(2)
PYEOF
)
    rc=$?
    release_lock
    printf '%s\n' "$out"
    return $rc
}

case "${1:-}" in
    prune)
        run_locked prune >/dev/null
        ;;
    list)
        run_locked list
        ;;
    *)
        echo "usage: session-claims.sh {prune|list} [options]" >&2
        exit 2
        ;;
esac
```

- [ ] **Step 4: Run test to verify it passes**

Run: `bash tests/test-session-claims.sh`
Expected: PASS for every assertion — the test file's `claim` invocation (in the subworktree
check) will fail at this point since `claim` isn't wired into the `case` statement yet; that's
expected and picked up in Task 2. For this step, comment out the "resolving root from a
subworktree" block's assertions temporarily is not necessary — `bash "$SC" claim ...` with an
unrecognized subcommand exits 2 and prints nothing to `$OUT`, so `assert_contains "$OUT" "from
subworktree"` correctly FAILs. Leave it failing; Task 2 makes it pass. All other assertions in
this file must PASS at this step.

- [ ] **Step 5: Commit**

```bash
git add scripts/session-claims.sh tests/test-session-claims.sh
git commit -m "feat: session-claims lock/prune/list primitives (bash)"
```

## Task 2: `claim` subcommand + conflict detection (bash)

**Files:**
- Modify: `scripts/session-claims.sh`
- Modify: `tests/test-session-claims.sh`

- [ ] **Step 1: Write the failing test**

Append to `tests/test-session-claims.sh`, immediately before the `print_summary` / `exit $?`
lines at the end of the file:

```bash
echo ""
echo "-- claim writes an entry with a 12h default TTL --"
rm -f ".claude/session-claims.json"
OUT=$(bash "$SC" claim --claim-id session-a --item "Resume mb backlog Tasks 2-5" --ns-id NS-3)
CODE=$?
assert_exit_zero "$CODE" "claim succeeds when nothing conflicts"
assert_contains "$OUT" "NS-3" "claim output includes the ns_id"
LIST_OUT=$(bash "$SC" list)
assert_contains "$LIST_OUT" "session-a" "the claim shows up in list"

echo ""
echo "-- a second session claiming the same ns_id gets a conflict, not a duplicate --"
OUT=$(bash "$SC" claim --claim-id session-b --item "Resume mb backlog Tasks 2-5" --ns-id NS-3)
CODE=$?
assert_exit_nonzero "$CODE" "conflicting claim exits non-zero"
assert_contains "$OUT" "session-a" "conflict output names the existing owner"
LIST_OUT=$(bash "$SC" list)
assert_not_contains "$LIST_OUT" "session-b" "the conflicting claim was never written"

echo ""
echo "-- re-claiming your own item updates in place, doesn't duplicate --"
bash "$SC" claim --claim-id session-a --item "Resume mb backlog Tasks 2-5" --ns-id NS-3 >/dev/null
LIST_OUT=$(bash "$SC" list)
COUNT=$(printf '%s' "$LIST_OUT" | python3 -c "import json,sys; print(len(json.load(sys.stdin)['claims']))")
if [ "$COUNT" = "1" ]; then
  echo "  PASS: re-claiming the same key leaves exactly one entry"
  PASS=$((PASS + 1))
else
  echo "  FAIL: expected 1 entry after re-claim, got $COUNT"
  FAIL=$((FAIL + 1))
fi

echo ""
echo "-- claiming without --claim-id or --item is a usage error, not a silent no-op --"
bash "$SC" claim --item "no id given" >/dev/null 2>/tmp/sc-usage-err.$$
CODE=$?
assert_exit_nonzero "$CODE" "missing --claim-id is rejected"
rm -f "/tmp/sc-usage-err.$$"
```

- [ ] **Step 2: Run test to verify it fails**

Run: `bash tests/test-session-claims.sh`
Expected: FAIL on every new assertion — `claim` isn't in the `case` statement yet, so `bash "$SC"
claim ...` hits the `*)` branch and exits 2 with a usage message, never writing anything.

- [ ] **Step 3: Write the implementation**

In `scripts/session-claims.sh`, replace the existing `case` statement (currently only handling
`prune`/`list`) with:

```bash
case "${1:-}" in
    prune)
        run_locked prune >/dev/null
        ;;
    list)
        run_locked list
        ;;
    claim)
        shift
        claim_id="" item="" ns_id="" ttl="12"
        while [ $# -gt 0 ]; do
            case "$1" in
                --claim-id) claim_id="$2"; shift 2 ;;
                --item) item="$2"; shift 2 ;;
                --ns-id) ns_id="$2"; shift 2 ;;
                --ttl-hours) ttl="$2"; shift 2 ;;
                *) shift ;;
            esac
        done
        if [ -z "$claim_id" ] || [ -z "$item" ]; then
            echo "usage: session-claims.sh claim --claim-id ID --item TEXT [--ns-id NS-n] [--ttl-hours N]" >&2
            exit 2
        fi
        PMB_CLAIM_ID="$claim_id" PMB_ITEM="$item" PMB_NS_ID="$ns_id" PMB_TTL_HOURS="$ttl" run_locked claim
        ;;
    *)
        echo "usage: session-claims.sh {prune|list|claim} [options]" >&2
        exit 2
        ;;
esac
```

- [ ] **Step 4: Run test to verify it passes**

Run: `bash tests/test-session-claims.sh`
Expected: PASS for every assertion, including the Task 1 subworktree-claim assertions that were
left failing on purpose.

- [ ] **Step 5: Commit**

```bash
git add scripts/session-claims.sh tests/test-session-claims.sh
git commit -m "feat: session-claims claim subcommand with conflict detection"
```

## Task 3: `release` and `force-clear` subcommands (bash)

**Files:**
- Modify: `scripts/session-claims.sh`
- Modify: `tests/test-session-claims.sh`

- [ ] **Step 1: Write the failing test**

Append to `tests/test-session-claims.sh`, before `print_summary` / `exit $?`:

```bash
echo ""
echo "-- release removes exactly the matching entry, nothing else --"
rm -f ".claude/session-claims.json"
bash "$SC" claim --claim-id session-a --item "Item one" --ns-id NS-10 >/dev/null
bash "$SC" claim --claim-id session-a --item "Item two" --ns-id NS-11 >/dev/null
bash "$SC" release --claim-id session-a --ns-id NS-10 >/dev/null
LIST_OUT=$(bash "$SC" list)
assert_not_contains "$LIST_OUT" "NS-10" "the released entry is gone"
assert_contains "$LIST_OUT" "NS-11" "an unrelated entry held by the same session survives"

echo ""
echo "-- releasing a claim_id you don't hold is a no-op, not an error --"
OUT=$(bash "$SC" release --claim-id session-a --ns-id NS-11)
CODE=$?
assert_exit_zero "$CODE" "release exits 0 even if there's nothing of yours to remove"
OUT2=$(bash "$SC" release --claim-id session-a --ns-id NS-11)
CODE2=$?
assert_exit_zero "$CODE2" "releasing the same claim twice is idempotent, not an error"

echo ""
echo "-- release with no --ns-id/--item releases everything that session_id holds (handoff) --"
rm -f ".claude/session-claims.json"
bash "$SC" claim --claim-id session-a --item "First" --ns-id NS-20 >/dev/null
bash "$SC" claim --claim-id session-a --item "Second" --ns-id NS-21 >/dev/null
bash "$SC" claim --claim-id session-b --item "Someone else's" --ns-id NS-22 >/dev/null
bash "$SC" release --claim-id session-a >/dev/null
LIST_OUT=$(bash "$SC" list)
assert_not_contains "$LIST_OUT" "NS-20" "bulk release removes the first of that session's claims"
assert_not_contains "$LIST_OUT" "NS-21" "bulk release removes the second of that session's claims"
assert_contains "$LIST_OUT" "NS-22" "bulk release does not touch a different session's claim"

echo ""
echo "-- force-clear removes a claim regardless of who holds it, and reports what it removed --"
rm -f ".claude/session-claims.json"
bash "$SC" claim --claim-id crashed-session --item "Abandoned work" --ns-id NS-30 >/dev/null
OUT=$(bash "$SC" force-clear --ns-id NS-30)
assert_contains "$OUT" "crashed-session" "force-clear's output names the entry it removed"
LIST_OUT=$(bash "$SC" list)
assert_not_contains "$LIST_OUT" "NS-30" "the force-cleared entry is gone"

echo ""
echo "-- force-clear with no --ns-id or --item is a usage error --"
bash "$SC" force-clear >/dev/null 2>/tmp/sc-fc-err.$$
CODE=$?
assert_exit_nonzero "$CODE" "force-clear requires a key to target"
rm -f "/tmp/sc-fc-err.$$"
```

- [ ] **Step 2: Run test to verify it fails**

Run: `bash tests/test-session-claims.sh`
Expected: FAIL on every new assertion — `release`/`force-clear` aren't in the `case` statement
yet.

- [ ] **Step 3: Write the implementation**

In `scripts/session-claims.sh`, extend the `case` statement (add these two arms alongside the
existing `prune`/`list`/`claim`, before the final `*)` fallback):

```bash
    release)
        shift
        claim_id="" item="" ns_id=""
        while [ $# -gt 0 ]; do
            case "$1" in
                --claim-id) claim_id="$2"; shift 2 ;;
                --item) item="$2"; shift 2 ;;
                --ns-id) ns_id="$2"; shift 2 ;;
                *) shift ;;
            esac
        done
        if [ -z "$claim_id" ]; then
            echo "usage: session-claims.sh release --claim-id ID [--ns-id NS-n] [--item TEXT]" >&2
            exit 2
        fi
        PMB_CLAIM_ID="$claim_id" PMB_ITEM="$item" PMB_NS_ID="$ns_id" run_locked release
        ;;
    force-clear)
        shift
        item="" ns_id=""
        while [ $# -gt 0 ]; do
            case "$1" in
                --item) item="$2"; shift 2 ;;
                --ns-id) ns_id="$2"; shift 2 ;;
                *) shift ;;
            esac
        done
        if [ -z "$ns_id" ] && [ -z "$item" ]; then
            echo "usage: session-claims.sh force-clear --ns-id NS-n | --item TEXT" >&2
            exit 2
        fi
        PMB_ITEM="$item" PMB_NS_ID="$ns_id" run_locked force-clear
        ;;
```

Also update the final `*)` fallback's usage message to list all five subcommands:

```bash
    *)
        echo "usage: session-claims.sh {prune|list|claim|release|force-clear} [options]" >&2
        exit 2
        ;;
```

- [ ] **Step 4: Run test to verify it passes**

Run: `bash tests/test-session-claims.sh`
Expected: PASS for every assertion in the file so far.

- [ ] **Step 5: Commit**

```bash
git add scripts/session-claims.sh tests/test-session-claims.sh
git commit -m "feat: session-claims release and force-clear subcommands"
```

## Task 4: Register the new suite in `tests/run.sh`

**Files:**
- Modify: `tests/run.sh`

**Why this is its own task, not folded into Task 1:** `mb backlog` shipped with a real test
file that was never wired into `tests/run.sh`'s `run_suite` list — CI showed green with zero
actual coverage of that feature (see `docs/superpowers/specs/2026-08-04-concurrent-session-
claims-design.md`'s Bash/PowerShell parity section). Making registration its own explicit,
checked-off step is a deliberate guard against repeating that.

- [ ] **Step 1: Write the failing check**

Run: `grep -c "test-session-claims" tests/run.sh`
Expected: `0` (not yet registered)

- [ ] **Step 2: Register the suite**

In `tests/run.sh`, add this line immediately after the existing `run_suite "dangerous-commands"`
line:

```bash
run_suite "session-claims"        "$REPO_ROOT/tests/test-session-claims.sh"
```

- [ ] **Step 3: Verify it's picked up**

Run: `bash tests/run.sh 2>&1 | grep -A2 "Suite: session-claims"`
Expected: shows the suite header followed by its test output, ending in `Results: N passed, 0
failed`.

- [ ] **Step 4: Run the full suite to confirm nothing else broke**

Run: `bash tests/run.sh`
Expected: `All test suites passed.`

- [ ] **Step 5: Commit**

```bash
git add tests/run.sh
git commit -m "test: register session-claims suite in tests/run.sh"
```

## Task 5: `scripts/session-claims.ps1` (PowerShell twin) + cross-tool interop test

**Files:**
- Create: `scripts/session-claims.ps1`
- Modify: `tests/test-session-claims.sh`

**Why a cross-tool test, not a separate Pester suite:** this repo's PowerShell test coverage is
inconsistent (only one existing `.Tests.ps1` file, for `mb-setup`) and both the bash tool and
the PowerShell tool are available side-by-side in this exact environment — meaning a bash
session and a pwsh session could genuinely race on the same lock directory, not just
hypothetically. The design spec's own Testing section calls this out specifically. Rather than
stand up a second, thinner test framework, this task adds a `pwsh`-if-available block to the
existing bash suite that invokes `session-claims.ps1` directly and checks it against the same
claims file bash writes — proving actual interop, not just "both scripts look similar."

- [ ] **Step 1: Write the failing test**

Append to `tests/test-session-claims.sh`, before `print_summary` / `exit $?`:

```bash
echo ""
echo "-- cross-tool: a claim written by the PowerShell twin is visible to the bash script --"
if command -v pwsh >/dev/null 2>&1; then
  rm -f ".claude/session-claims.json"
  pwsh -NonInteractive -File "$REPO_ROOT/scripts/session-claims.ps1" claim -ClaimId ps-session -Item "from powershell" -NsId NS-40 >/dev/null 2>&1
  LIST_OUT=$(bash "$SC" list)
  assert_contains "$LIST_OUT" "from powershell" "bash list sees a claim the .ps1 twin wrote"

  echo ""
  echo "-- cross-tool: the .ps1 twin sees a claim bash wrote, and detects the conflict --"
  OUT=$(pwsh -NonInteractive -File "$REPO_ROOT/scripts/session-claims.ps1" claim -ClaimId another-ps-session -Item "different text" -NsId NS-40 2>&1)
  assert_contains "$OUT" "ps-session" "the .ps1 twin's conflict output names the bash-side owner"

  echo ""
  echo "-- cross-tool: force-clear via bash removes a claim the .ps1 twin wrote --"
  bash "$SC" force-clear --ns-id NS-40 >/dev/null
  LIST_OUT=$(bash "$SC" list)
  assert_not_contains "$LIST_OUT" "from powershell" "bash force-clear removed the .ps1-written entry"
else
  echo "  SKIP: pwsh not available on this machine -- cross-tool interop not exercised"
fi
```

- [ ] **Step 2: Run test to verify it fails (or skips)**

Run: `bash tests/test-session-claims.sh`
Expected: on a machine with `pwsh` available, FAIL (`session-claims.ps1` doesn't exist). On a
machine without `pwsh`, the block prints `SKIP` and contributes no pass/fail — confirm the
overall suite still reports its prior (Task 1-3) pass count unchanged.

- [ ] **Step 3: Write the implementation**

```powershell
# scripts/session-claims.ps1 — coordinate multiple Claude Code sessions working the same repo.
# PowerShell twin of scripts/session-claims.sh. See that file's header for full rationale and
# docs/SESSION-CLAIMS-GUIDE.md for the mechanism. No python3 dependency -- uses native
# ConvertFrom-Json/ConvertTo-Json.

param(
    [Parameter(Position=0)] [string]$Action,
    [string]$ClaimId,
    [string]$Item,
    [string]$NsId,
    [double]$TtlHours = 12
)

function Resolve-ClaimsRoot {
    # WHY git rev-parse --git-common-dir, not a resolve_cd_root port: same reasoning as the
    # bash twin -- this needs "find the main worktree root from here", which
    # --git-common-dir already solves, matching mb.ps1's existing subworktree check
    # (scripts/mb.ps1:616).
    $commonGit = git rev-parse --git-common-dir 2>$null
    if (-not $commonGit) { return $null }
    $parent = [System.IO.Path]::GetDirectoryName($commonGit)
    if ([string]::IsNullOrEmpty($parent)) { $parent = "." }
    try { return (Resolve-Path $parent -ErrorAction Stop).Path } catch { return $null }
}

$Root = Resolve-ClaimsRoot
if (-not $Root) { exit 0 }

$ClaimsDir  = Join-Path $Root ".claude"
$ClaimsFile = Join-Path $ClaimsDir "session-claims.json"
$LockDir    = Join-Path $ClaimsDir "session-claims.lock"

function Get-LockAgeSeconds {
    try {
        $lockItem = Get-Item $LockDir -ErrorAction Stop
        return [int]((Get-Date).ToUniversalTime() - $lockItem.LastWriteTimeUtc).TotalSeconds
    } catch { return [int]::MaxValue }
}

function Invoke-AcquireLock {
    if (-not (Test-Path $ClaimsDir)) { New-Item -ItemType Directory -Path $ClaimsDir -Force | Out-Null }
    $tries = 0
    while ($tries -lt 20) {
        try {
            New-Item -ItemType Directory -Path $LockDir -ErrorAction Stop | Out-Null
            return $true
        } catch {
            if ((Test-Path $LockDir) -and (Get-LockAgeSeconds) -gt 30) {
                try { Remove-Item $LockDir -Recurse -Force -ErrorAction Stop } catch {}
                continue
            }
            $tries++
            Start-Sleep -Milliseconds 100
        }
    }
    return $false
}

function Invoke-ReleaseLock {
    try { Remove-Item $LockDir -Recurse -Force -ErrorAction Stop } catch {}
}

function Get-LiveClaims {
    if (-not (Test-Path $ClaimsFile)) { return @() }
    try {
        $data = Get-Content $ClaimsFile -Raw | ConvertFrom-Json
        $claims = @($data.claims)
    } catch { return @() }
    $now = (Get-Date).ToUniversalTime()
    $result = @()
    foreach ($c in $claims) {
        try {
            $expires = [datetime]::Parse($c.expires_at, $null, [System.Globalization.DateTimeStyles]::RoundtripKind)
            if ($expires -gt $now) { $result += $c }
        } catch { continue }
    }
    return $result
}

function Save-Claims {
    param($Claims)
    $tmp = "$ClaimsFile.tmp.$PID"
    @{ claims = $Claims } | ConvertTo-Json -Depth 5 | Set-Content -Path $tmp -Encoding utf8
    Move-Item -Path $tmp -Destination $ClaimsFile -Force  # atomic on the same filesystem
}

if (-not (Invoke-AcquireLock)) {
    Write-Warning "could not acquire session-claims lock, skipping"
    exit 1
}

try {
    $claims = Get-LiveClaims

    switch ($Action) {
        "prune" {
            Save-Claims $claims
        }
        "list" {
            Save-Claims $claims
            @{ claims = $claims } | ConvertTo-Json -Depth 5 -Compress
        }
        "claim" {
            if (-not $ClaimId -or -not $Item) {
                Write-Error "usage: session-claims.ps1 claim -ClaimId ID -Item TEXT [-NsId NS-n] [-TtlHours N]"
                exit 2
            }
            $sameKey = { param($c) if ($NsId) { $c.ns_id -eq $NsId } else { $c.item -eq $Item } }
            $conflict = $claims | Where-Object { (& $sameKey $_) -and $_.claim_id -ne $ClaimId } | Select-Object -First 1
            if ($conflict) {
                @{ conflict = $conflict } | ConvertTo-Json -Depth 5 -Compress
                exit 1
            }
            $remaining = @($claims | Where-Object { -not (& $sameKey $_) })
            $entry = [ordered]@{
                claim_id   = $ClaimId
                ns_id      = $NsId
                item       = $Item
                claimed_at = (Get-Date).ToUniversalTime().ToString("o")
                expires_at = (Get-Date).ToUniversalTime().AddHours($TtlHours).ToString("o")
            }
            $remaining += $entry
            Save-Claims $remaining
            @{ claim = $entry } | ConvertTo-Json -Depth 5 -Compress
        }
        { $_ -in @("release", "force-clear") } {
            $bulk = ($Action -eq "release") -and (-not $NsId) -and (-not $Item)
            $removed = @()
            $remaining = @()
            foreach ($c in $claims) {
                $matchesOwner = ($Action -eq "force-clear") -or ($c.claim_id -eq $ClaimId)
                if ($bulk) {
                    $matchesKey = $true
                } elseif ($NsId) {
                    $matchesKey = $c.ns_id -eq $NsId
                } elseif ($Item) {
                    $matchesKey = $c.item -eq $Item
                } else {
                    $matchesKey = $false
                }
                if ($matchesOwner -and $matchesKey -and ($bulk -or $removed.Count -eq 0)) {
                    $removed += $c
                    continue
                }
                $remaining += $c
            }
            Save-Claims $remaining
            @{ removed = $removed } | ConvertTo-Json -Depth 5 -Compress
        }
        default {
            Write-Error "usage: session-claims.ps1 {prune|list|claim|release|force-clear} [options]"
            exit 2
        }
    }
} finally {
    Invoke-ReleaseLock
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `bash tests/test-session-claims.sh`
Expected: PASS for every assertion on a machine with `pwsh`; on a machine without it, the
cross-tool block still prints `SKIP` and the rest of the suite passes.

- [ ] **Step 5: Commit**

```bash
git add scripts/session-claims.ps1 tests/test-session-claims.sh
git commit -m "feat: session-claims.ps1 PowerShell twin + cross-tool interop test"
```

## Task 6: Template mirrors

**Files:**
- Create: `templates/scripts/session-claims.sh`
- Create: `templates/scripts/session-claims.ps1`

**Why:** matches this repo's existing TEMPLATE_OWNED convention — `templates/scripts/` ships
byte-identical copies of hook/utility scripts to projects that adopt PMB via `mb init`/`mb
upgrade`. Confirmed as the live pattern via `templates/scripts/review-reminders.sh` etc.
already mirroring `scripts/review-reminders.sh`.

- [ ] **Step 1: Verify the check that will catch drift**

Run: `diff scripts/session-claims.sh templates/scripts/session-claims.sh`
Expected: FAIL — `templates/scripts/session-claims.sh` doesn't exist yet.

- [ ] **Step 2: Copy both files verbatim**

```bash
cp scripts/session-claims.sh templates/scripts/session-claims.sh
cp scripts/session-claims.ps1 templates/scripts/session-claims.ps1
```

- [ ] **Step 3: Verify byte-identical**

Run: `diff scripts/session-claims.sh templates/scripts/session-claims.sh && diff scripts/session-claims.ps1 templates/scripts/session-claims.ps1`
Expected: no output from either `diff` (exit 0, files identical).

- [ ] **Step 4: Confirm `mb doctor`'s existing hook-presence check doesn't choke on the new files**

Run: `bash scripts/mb.sh doctor 2>&1 | grep -i "session-claims"`
Expected: no `[ERROR]`/`[WARN]` mentioning `session-claims` yet (the hook isn't registered in
`.claude/settings.json` until Task 8, so this check has nothing to validate against at this
point — confirm it's silent, not erroring).

- [ ] **Step 5: Commit**

```bash
git add templates/scripts/session-claims.sh templates/scripts/session-claims.ps1
git commit -m "chore: mirror session-claims scripts into templates/scripts/"
```

## Task 7: `.gitignore` entries

**Files:**
- Modify: `.gitignore`

- [ ] **Step 1: Write the failing check**

Run: `git check-ignore -q .claude/session-claims.json; echo $?`
Expected: `1` (not ignored yet)

- [ ] **Step 2: Add the entries**

In `.gitignore`, immediately after the existing block:

```
# Task contract files — session artifacts, never committed
.claude/contracts/*.json
```

add:

```

# Session claims — local ephemeral coordination state, never committed
.claude/session-claims.json
.claude/session-claims.lock/
```

- [ ] **Step 3: Verify**

Run: `git check-ignore -q .claude/session-claims.json; echo $?`
Expected: `0` (now ignored)

Run: `mkdir -p .claude/session-claims.lock && git status --porcelain .claude/session-claims.lock; rmdir .claude/session-claims.lock`
Expected: no output from `git status` (the lock directory is ignored too)

- [ ] **Step 4: Commit**

```bash
git add .gitignore
git commit -m "chore: gitignore session-claims runtime state"
```

## Task 8: `SessionStart` hook — `notify` subcommand + registration

**Files:**
- Modify: `scripts/session-claims.sh`
- Modify: `scripts/session-claims.ps1`
- Modify: `templates/scripts/session-claims.sh` (mirror after Step 3)
- Modify: `templates/scripts/session-claims.ps1` (mirror after Step 3)
- Modify: `.claude/settings.json`
- Modify: `templates/.claude/settings.json`
- Modify: `tests/test-session-claims.sh`

**Why `notify` is a separate action from `list`:** `list` is the raw JSON API other subcommands
and callers parse. The hook needs human-readable output, and — per the design's explicit
requirement — must print *nothing* when there's nothing to report, or it becomes noise that
gets tuned out, defeating the reason this is hook-enforced instead of advisory. Keeping that
formatting/silence logic in its own action keeps `list`'s contract (always valid JSON) simple
for other callers.

- [ ] **Step 1: Write the failing test**

Append to `tests/test-session-claims.sh`, before `print_summary` / `exit $?`:

```bash
echo ""
echo "-- notify prints nothing when there are no live claims --"
rm -f ".claude/session-claims.json"
OUT=$(bash "$SC" notify)
if [ -z "$OUT" ]; then
  echo "  PASS: notify is silent with no claims"
  PASS=$((PASS + 1))
else
  echo "  FAIL: notify printed something with no claims: $OUT"
  FAIL=$((FAIL + 1))
fi

echo ""
echo "-- notify prints a human-readable line when a live claim exists --"
bash "$SC" claim --claim-id session-a --item "Resume mb backlog Tasks 2-5" --ns-id NS-3 >/dev/null
OUT=$(bash "$SC" notify)
assert_contains "$OUT" "NS-3" "notify output includes the ns_id"
assert_contains "$OUT" "session-a" "notify output includes the owner"
assert_not_contains "$OUT" '{"claims"' "notify prints human text, not raw JSON"

echo ""
echo "-- an expired claim is silent in notify too (prune happens first) --"
python3 - <<'PYEOF'
import json
from datetime import datetime, timedelta, timezone
now = datetime.now(timezone.utc)
data = {"claims": [
    {"claim_id": "old", "ns_id": "NS-99", "item": "stale",
     "claimed_at": (now - timedelta(hours=20)).isoformat(),
     "expires_at": (now - timedelta(hours=1)).isoformat()},
]}
with open(".claude/session-claims.json", "w") as f:
    json.dump(data, f)
PYEOF
OUT=$(bash "$SC" notify)
assert_not_contains "$OUT" "NS-99" "notify doesn't surface an already-expired claim"
```

- [ ] **Step 2: Run test to verify it fails**

Run: `bash tests/test-session-claims.sh`
Expected: FAIL — `notify` isn't in the `case` statement yet.

- [ ] **Step 3: Add `notify` to both scripts, then re-sync the template mirrors**

In `scripts/session-claims.sh`, add this arm to the `case` statement (alongside the others,
before the final `*)` fallback), and update that fallback's usage line:

```bash
    notify)
        out=$(run_locked list)
        printf '%s' "$out" | python3 -c "
import json, sys
try:
    d = json.load(sys.stdin)
except Exception:
    sys.exit(0)
claims = d.get('claims', [])
if not claims:
    sys.exit(0)
print('Active session claims:')
for c in claims:
    ns = c.get('ns_id') or '(ad hoc)'
    print(f\"  - [{ns}] {c.get('item','')} — held by {c.get('claim_id','?')}, expires {c.get('expires_at','?')}\")
" 2>/dev/null
        ;;
```

```bash
    *)
        echo "usage: session-claims.sh {prune|list|claim|release|force-clear|notify} [options]" >&2
        exit 2
        ;;
```

In `scripts/session-claims.ps1`, add this case to the `switch ($Action)` block (alongside the
others, before `default`), and update `default`'s usage message:

```powershell
        "notify" {
            $liveClaims = Get-LiveClaims
            Save-Claims $liveClaims
            if ($liveClaims.Count -eq 0) { return }
            Write-Output "Active session claims:"
            foreach ($c in $liveClaims) {
                $ns = if ($c.ns_id) { $c.ns_id } else { "(ad hoc)" }
                Write-Output "  - [$ns] $($c.item) — held by $($c.claim_id), expires $($c.expires_at)"
            }
        }
```

```powershell
        default {
            Write-Error "usage: session-claims.ps1 {prune|list|claim|release|force-clear|notify} [options]"
            exit 2
        }
```

Re-sync the template mirrors:

```bash
cp scripts/session-claims.sh templates/scripts/session-claims.sh
cp scripts/session-claims.ps1 templates/scripts/session-claims.ps1
```

- [ ] **Step 4: Register the `SessionStart` hook**

In `.claude/settings.json`, add a new top-level key inside `"hooks"`, alongside the existing
`"PreToolUse"`/`"PostToolUse"`/`"PreCompact"`/`"Stop"` keys:

```json
    "SessionStart": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "pwsh -NonInteractive -File scripts/session-claims.ps1 notify 2>/dev/null || bash scripts/session-claims.sh notify 2>/dev/null || true"
          }
        ]
      }
    ],
```

Mirror the same addition into `templates/.claude/settings.json`.

Then run the full test suite and verify it still passes:

Run: `bash tests/test-session-claims.sh`
Expected: PASS for every assertion, including the new `notify` ones.

- [ ] **Step 5: Commit**

```bash
git add scripts/session-claims.sh scripts/session-claims.ps1 templates/scripts/session-claims.sh templates/scripts/session-claims.ps1 .claude/settings.json templates/.claude/settings.json tests/test-session-claims.sh
git commit -m "feat: session-claims notify action + SessionStart hook registration"
```

## Task 9: `mb doctor` checks — malformed claims file, stale lock

**Files:**
- Modify: `scripts/mb.sh`
- Modify: `scripts/mb.ps1`
- Modify: `tests/test-mb-doctor.sh`

**Why this matters:** `.claude/contracts/active-task.json` has an `expires_at` field with no
integrity check behind it — it went stale unnoticed across multiple sessions (see
`memory-bank/activeContext.md`'s 2026-07-23/24 entries). A malformed `session-claims.json` or a
lock directory stuck well past its 30-second self-heal window is the same class of silent
structural failure; a doctor check catches it instead of repeating that precedent.

- [ ] **Step 1: Write the failing test**

Append to `tests/test-mb-doctor.sh`, after the existing baseline-check section (find the line
`# ── Baseline: clean project — no [ERROR] expected ────────────────────────────` and add the
new block after the baseline assertions that follow it, using the same `TMPDIR_DOC` project):

```bash
echo ""
echo "-- session-claims: malformed JSON is flagged --"
mkdir -p "$TMPDIR_DOC/.claude"
echo "{not valid json" > "$TMPDIR_DOC/.claude/session-claims.json"
OUT=$(cd "$TMPDIR_DOC" && bash "$MB" doctor 2>&1)
assert_contains "$OUT" "session-claims.json is not valid JSON" "doctor flags a malformed claims file"
rm -f "$TMPDIR_DOC/.claude/session-claims.json"

echo ""
echo "-- session-claims: a lock directory over 5 minutes old is flagged --"
mkdir -p "$TMPDIR_DOC/.claude/session-claims.lock"
OLD_TS=$(date -d '@'$(( $(date +%s) - 400 )) '+%Y%m%d%H%M.%S' 2>/dev/null || date -j -f '%s' "$(( $(date +%s) - 400 ))" '+%Y%m%d%H%M.%S' 2>/dev/null)
touch -t "$OLD_TS" "$TMPDIR_DOC/.claude/session-claims.lock" 2>/dev/null || true
OUT=$(cd "$TMPDIR_DOC" && bash "$MB" doctor 2>&1)
assert_contains "$OUT" "session-claims.lock is over 5 minutes old" "doctor flags a stuck lock directory"
rmdir "$TMPDIR_DOC/.claude/session-claims.lock"

echo ""
echo "-- session-claims: a fresh lock directory is not flagged --"
mkdir -p "$TMPDIR_DOC/.claude/session-claims.lock"
OUT=$(cd "$TMPDIR_DOC" && bash "$MB" doctor 2>&1)
assert_not_contains "$OUT" "session-claims.lock is over 5 minutes old" "doctor doesn't flag a fresh lock"
rmdir "$TMPDIR_DOC/.claude/session-claims.lock"

echo ""
echo "-- session-claims: a valid, short-lived claims file is not flagged --"
python3 - "$TMPDIR_DOC/.claude/session-claims.json" <<'PYEOF'
import json, sys
from datetime import datetime, timedelta, timezone
now = datetime.now(timezone.utc)
data = {"claims": [{"claim_id": "x", "ns_id": "NS-1", "item": "y",
                     "claimed_at": now.isoformat(),
                     "expires_at": (now + timedelta(hours=1)).isoformat()}]}
with open(sys.argv[1], "w") as f:
    json.dump(data, f)
PYEOF
OUT=$(cd "$TMPDIR_DOC" && bash "$MB" doctor 2>&1)
assert_not_contains "$OUT" "session-claims.json is not valid JSON" "doctor doesn't flag a well-formed claims file"
rm -f "$TMPDIR_DOC/.claude/session-claims.json"
```

- [ ] **Step 2: Run test to verify it fails**

Run: `bash tests/test-mb-doctor.sh`
Expected: FAIL on the two new positive assertions (malformed JSON, stale lock) — `mb doctor`
doesn't check for either yet. The two negative assertions may accidentally PASS already (nothing
to flag), which is fine; they exist to catch a false-positive regression once Step 3 lands.

- [ ] **Step 3: Write the implementation**

In `scripts/mb.sh`'s `show_doctor()` function, insert this block immediately before the existing:

```bash
    echo ""
    echo ""
    show_audit
```

(i.e. right after the `fi` that closes the `Stale but loaded` block, at the location currently
occupied by lines 1410-1414 in `scripts/mb.sh`):

```bash
    # N. Session claims integrity — same silent-structural-failure class that let
    # .claude/contracts/active-task.json go stale unnoticed; catch it here instead.
    CLAIMS_FILE=".claude/session-claims.json"
    if [ -f "$CLAIMS_FILE" ] && command -v python3 >/dev/null 2>&1; then
        if ! python3 -c "import json; json.load(open('$CLAIMS_FILE'))" >/dev/null 2>&1; then
            echo -e "${RED}[ERROR] .claude/session-claims.json is not valid JSON — delete it to reset${NC}"
        fi
    fi
    CLAIMS_LOCK=".claude/session-claims.lock"
    if [ -d "$CLAIMS_LOCK" ]; then
        LOCK_MTIME=$(stat -c %Y "$CLAIMS_LOCK" 2>/dev/null || stat -f %m "$CLAIMS_LOCK" 2>/dev/null || date +%s)
        LOCK_AGE=$(( $(date +%s) - LOCK_MTIME ))
        if [ "$LOCK_AGE" -gt 300 ]; then
            echo -e "${YELLOW}[WARN] .claude/session-claims.lock is over 5 minutes old — the 30s self-heal should have cleared it; safe to remove manually${NC}"
        fi
    fi
```

In `scripts/mb.ps1`'s doctor function, insert this block immediately before the existing:

```powershell
    Write-Host ""
    Show-Audit
```

(i.e. right after the `}` that closes the `Stale but loaded` block, at the location currently
occupied by lines 1707-1710 in `scripts/mb.ps1`):

```powershell
    # Session claims integrity — same reasoning as the bash check above.
    $claimsFile = ".claude/session-claims.json"
    if (Test-Path $claimsFile) {
        try {
            Get-Content $claimsFile -Raw | ConvertFrom-Json | Out-Null
        } catch {
            Write-Host "[ERROR] .claude/session-claims.json is not valid JSON — delete it to reset" -ForegroundColor Red
        }
    }
    $claimsLock = ".claude/session-claims.lock"
    if (Test-Path $claimsLock) {
        $lockAgeSeconds = [int]((Get-Date).ToUniversalTime() - (Get-Item $claimsLock).LastWriteTimeUtc).TotalSeconds
        if ($lockAgeSeconds -gt 300) {
            Write-Host "[WARN] .claude/session-claims.lock is over 5 minutes old — the 30s self-heal should have cleared it; safe to remove manually" -ForegroundColor Yellow
        }
    }
```

- [ ] **Step 4: Run test to verify it passes**

Run: `bash tests/test-mb-doctor.sh`
Expected: PASS for every assertion.

Run: `bash tests/run.sh`
Expected: `All test suites passed.`

- [ ] **Step 5: Commit**

```bash
git add scripts/mb.sh scripts/mb.ps1 tests/test-mb-doctor.sh
git commit -m "feat: mb doctor checks for malformed session-claims file and stale lock"
```

## Task 10: `docs/SESSION-CLAIMS-GUIDE.md`

**Files:**
- Create: `docs/SESSION-CLAIMS-GUIDE.md`

**Why a new file, not folded into `docs/CONTRACTS-GUIDE.md`:** related but distinct concepts —
a task contract declares *file scope* for one session's work; a session claim declares *which
Next Steps item* is being worked, visible across sessions. Mirrors `CONTRACTS-GUIDE.md`'s
structure so the two read as siblings.

- [ ] **Step 1: Write the file**

```markdown
# Session Claims Guide

Session claims let multiple Claude Code sessions working the same repo at once (same main
worktree, main+subworktrees, or several subworktrees) see what's already in progress, so a
session reading a handoff doesn't duplicate or collide with another session's work.

## How It Works

1. Before starting a Next Steps item (or ad hoc task worth coordinating on), Claude checks for
   a live claim on it: `session-claims.sh list` (or the `.ps1` twin).
2. If nothing conflicts, Claude claims it: `session-claims.sh claim --claim-id <id> --item
   "<text>" --ns-id <NS-n>`.
3. Claude does the work.
4. On completion, Claude releases the claim as part of the same step that marks the item
   complete/evicts it from `activeContext.md`: `session-claims.sh release --claim-id <id>
   --ns-id <NS-n>`.
5. At session end (handoff), Claude releases everything it holds in one call: `session-claims.sh
   release --claim-id <id>` (no `--ns-id`/`--item` — bulk release).

A new `SessionStart` hook runs `session-claims.sh notify` automatically, so live claims surface
at the start of every session without Claude needing to remember to check — it prints nothing
when there's nothing to report.

## Claim Schema

```json
{
  "claim_id": "worktree-mb-backlog-feature",
  "ns_id": "NS-3",
  "item": "Resume mb backlog Tasks 2-5",
  "claimed_at": "2026-08-04T14:00:00Z",
  "expires_at": "2026-08-05T02:00:00Z"
}
```

- `claim_id` — the session's worktree/branch name if it has one, otherwise a self-chosen slug
  reused for the whole conversation.
- `ns_id` — the item's stable `[NS-N]` id from `activeContext.md`'s Next Steps list. Omitted for
  ad hoc work never added to that list.
- `item` — free-text description, for human readability if `ns_id` and the list ever drift
  apart. Matching for conflict detection uses `ns_id` when present, `item` text otherwise.
- `expires_at` — 12 hours after `claimed_at` by default (`--ttl-hours` overrides). Chosen to
  cover any realistic single working session without needing renewal/heartbeat logic; an
  abandoned claim self-clears well within a day regardless.

## Storage and Locking

Canonical file: `.claude/session-claims.json`, in the **main worktree only** (subworktree
sessions resolve to it via `git rev-parse --git-common-dir`, same mechanism `memory-bank/`'s
worktree guidance uses, except claims get write access — memory-bank/ doesn't). Gitignored, like
`.claude/contracts/*.json` — pure local ephemeral state.

Every read or write is pruned first (expired entries dropped) and goes through an `mkdir`-based
lock (`.claude/session-claims.lock/`) with atomic temp-file-then-rename writes, so the file can
never grow past "currently concurrent sessions" and a crash mid-write can't corrupt it. A lock
held for more than 30 seconds is treated as abandoned and stolen by the next session. This is
best-effort concurrency control for human-paced parallel sessions, not a general distributed
lock service.

## Conflict Resolution

If `claim` finds a live claim on the same `ns_id`/`item` held by a different `claim_id`, it exits
non-zero and prints the conflicting claim instead of writing anything. Claude surfaces this via
`AskUserQuestion` — work on something else, or force-clear:

```
session-claims.sh force-clear --ns-id NS-3
```

Force-clearing also adds one line to `activeContext.md` ("force-cleared stale claim on X held by
Y, appeared abandoned as of Z") — otherwise a returning session would find its claim silently
gone with no explanation, which just relocates the confusion this exists to prevent.

## Non-Goals

- **Not a lock on the memory-bank files themselves.** Claims prevent two sessions from starting
  the same work twice; they do nothing about two sessions concurrently editing
  `activeContext.md` and losing an update. Different problem, not addressed here.
- **Not cross-repo.** Claims are per-repo, same as `.claude/contracts/active-task.json` — see
  the multi-session repo-boundary guidance for working across repos.

## Files

| File | Purpose |
|------|---------|
| `.claude/session-claims.json` | The live registry (gitignored) |
| `.claude/session-claims.lock/` | Mutex directory, held only during a read/write (gitignored) |
| `scripts/session-claims.sh` | POSIX implementation |
| `scripts/session-claims.ps1` | PowerShell implementation |
| `templates/scripts/session-claims.sh` / `.ps1` | Schema/behavior reference for adopted projects |

## Relationship to Other Layers

| Layer | What it does |
|-------|-------------|
| `standards/MEMORY-BANK.md` | Documents the `[NS-N]` id convention and the release-on-close-out rule |
| `SessionStart` hook | Surfaces live claims automatically, every session, no advisory dependency |
| `session-claims.sh`/`.ps1` | Enforces the lock/prune/conflict mechanics |
| `mb doctor` | Flags a malformed claims file or a stuck lock directory |
```

- [ ] **Step 2: Verify it reads cleanly**

Run: `grep -c "^## " docs/SESSION-CLAIMS-GUIDE.md`
Expected: `7` (seven `##` sections: How It Works, Claim Schema, Storage and Locking, Conflict
Resolution, Non-Goals, Files, Relationship to Other Layers).

- [ ] **Step 3: Commit**

```bash
git add docs/SESSION-CLAIMS-GUIDE.md
git commit -m "docs: add session claims guide"
```

## Task 11: `standards/MEMORY-BANK.md` — `[NS-N]` id convention + release-on-close-out rule

**Files:**
- Modify: `standards/MEMORY-BANK.md`

- [ ] **Step 1: Write the failing check**

Run: `grep -c "NS-" standards/MEMORY-BANK.md`
Expected: `0` (convention not documented yet)

- [ ] **Step 2: Add a new section**

In `standards/MEMORY-BANK.md`, insert a new section immediately after the existing `## Task
Decomposition` section (i.e. right before the `## Quick Commands` section — find that exact
heading as the insertion anchor):

```markdown
## Session Claims

Multiple Claude Code sessions can work the same repo at once. `[NS-N]` ids and session claims
prevent them from silently duplicating or colliding on the same work. Full mechanism:
`docs/SESSION-CLAIMS-GUIDE.md`.

**Next Steps ids:** every `activeContext.md` Next Steps line gets a short leading id (`[NS-3]`),
assigned sequentially when added, never reused even after the item is evicted. This gives claims
something stable to reference — free-text matching alone breaks the moment an item gets
reworded or reordered.

**Claim before starting, release at close-out:** before starting a Next Steps item, check for a
live claim on its `[NS-N]` id (`session-claims.sh list`); if clear, claim it
(`session-claims.sh claim`). Release the claim (`session-claims.sh release`) as part of the
*same* step that marks the item complete and evicts it from `activeContext.md` — not a
separately-remembered action. A claim release skipped anyway (forgotten, session crashed)
self-heals via the claim's own expiry; nothing is left permanently orphaned.

**At handoff:** release everything the session holds in one call
(`session-claims.sh release --claim-id <id>`, no `--ns-id`) as part of the existing Handoff
Protocol's step 2 (writing `handoff.md`) — see `CLAUDE.md`.
```

- [ ] **Step 3: Verify**

Run: `grep -c "NS-" standards/MEMORY-BANK.md`
Expected: `4` or more (non-zero — confirm the new section landed)

Run: `grep -A1 "^## Session Claims" standards/MEMORY-BANK.md`
Expected: shows the new section's opening line

- [ ] **Step 4: Commit**

```bash
git add standards/MEMORY-BANK.md
git commit -m "docs: document NS-id convention and claim release-on-close-out rule"
```

## Task 12: `CLAUDE.md` — protocol pointers

**Files:**
- Modify: `CLAUDE.md`

- [ ] **Step 1: Write the failing check**

Run: `grep -c "session-claims\|SESSION-CLAIMS" CLAUDE.md`
Expected: `0`

- [ ] **Step 2: Add a short addition to the existing `## Memory Bank` section**

In `CLAUDE.md`, immediately after the existing bullet list under `## Memory Bank` (the
`projectbrief.md` / `systemPatterns.md` / `techContext.md` / `activeContext.md` / `progress.md`
numbered list) and its `**Rules:**` line, add:

```markdown

**Session claims:** a `SessionStart` hook automatically surfaces any live session claims (other
sessions' in-progress Next Steps items) at the start of every conversation — no action needed to
see them. Before starting a Next Steps item yourself, claim it; release it as part of marking it
complete. Full protocol: `docs/SESSION-CLAIMS-GUIDE.md`.
```

- [ ] **Step 3: Extend the existing `## Handoff Protocol` section**

In `CLAUDE.md`, in the `## Handoff Protocol` section's numbered list, modify step 2 from:

```markdown
2. **CREATE** `handoff.md` in project root with: accomplishments, files modified, service state, commands to resume, pending tasks, context for next agent
```

to:

```markdown
2. **CREATE** `handoff.md` in project root with: accomplishments, files modified, service state, commands to resume, pending tasks, context for next agent. **Release every session claim this session holds** (`session-claims.sh release --claim-id <id>`, no `--ns-id` — bulk release) before writing `handoff.md`.
```

- [ ] **Step 4: Verify**

Run: `grep -c "session-claims\|SESSION-CLAIMS" CLAUDE.md`
Expected: `3` or more (non-zero — confirm both additions landed)

- [ ] **Step 5: Commit**

```bash
git add CLAUDE.md
git commit -m "docs: wire session-claims protocol into CLAUDE.md session-start and handoff steps"
```

## Task 13: Retrofit `memory-bank/activeContext.md`'s Next Steps list with `[NS-N]` ids

**Files:**
- Modify: `memory-bank/activeContext.md`

**Why a script, not hand-editing:** `activeContext.md` is volatile session state (per its own
`authority: volatile` frontmatter) and gets rewritten frequently — by the time this task
actually executes, its current Next Steps items may no longer match what an earlier planning
pass saw. A small idempotent script that operates on whatever numbered list actually exists at
execution time is more reliable than hardcoding today's item text into this plan.

- [ ] **Step 1: Write the failing check**

Run: `grep -c "^[0-9]\+\. \[NS-" memory-bank/activeContext.md`
Expected: `0` (no items retrofitted yet)

- [ ] **Step 2: Run the retrofit script**

```bash
python3 - <<'PYEOF'
import re

path = "memory-bank/activeContext.md"
with open(path, encoding="utf-8") as f:
    lines = f.readlines()

out = []
in_next_steps = False
for line in lines:
    if line.startswith("## "):
        in_next_steps = line.strip() == "## Next Steps"
        out.append(line)
        continue
    if in_next_steps:
        m = re.match(r"^(\d+)\. (?!\[NS-)(.*)$", line)
        if m:
            n, rest = m.groups()
            line = f"{n}. [NS-{n}] {rest}\n"
    out.append(line)

with open(path, "w", encoding="utf-8") as f:
    f.writelines(out)
PYEOF
```

This only touches lines inside the `## Next Steps` section (stops applying at the next `## `
heading), only matches top-level numbered items (`0. `, `1. `, …), and is idempotent — a line
already prefixed with `[NS-` is left untouched, so re-running it is harmless.

- [ ] **Step 3: Verify**

Run: `grep -c "^[0-9]\+\. \[NS-" memory-bank/activeContext.md`
Expected: matches the actual count of numbered Next Steps items in the file at this point (a
non-zero number — confirm it equals the number of `^[0-9]\+\. ` lines under `## Next Steps`
before this step ran).

Run: `git diff memory-bank/activeContext.md`
Expected: only the Next Steps section's numbered lines changed, each gaining a `[NS-N] ` prefix
immediately after its number; no other content altered.

- [ ] **Step 4: Update `last-reviewed` per this file's own convention**

`activeContext.md`'s frontmatter carries a `last-reviewed:` field (`review-cycle: 7d`). This
change is substantive enough to count as a review touch — update it manually to today's date if
the `PostToolUse` auto-stamp hook (`update-reviewed.sh`/`.ps1`) doesn't already cover this file
in this repo's current configuration.

- [ ] **Step 5: Commit**

```bash
git add memory-bank/activeContext.md
git commit -m "docs: retrofit Next Steps items with stable [NS-N] ids"
```

---

## Plan Self-Review

**Spec coverage** — every section of `docs/superpowers/specs/2026-08-04-concurrent-session-
claims-design.md` maps to a task: Storage/Concurrency control → Tasks 1-3; Session identity →
documented in Task 11/12 (no code — identity is a caller-supplied argument, not something the
script computes); Lifecycle → Tasks 2-3, 11; Conflict/override → Tasks 2-3, 10; Enforcement
(SessionStart hook) → Task 8; Next Steps stable IDs → Tasks 11, 13; `mb doctor` check → Task 9;
Bash/PowerShell parity → Tasks 5-6, throughout; Testing → woven into Tasks 1-3, 5, 8-9 rather
than a separate task, matching this repo's existing convention of testing each behavior where
it's introduced.

**Placeholder scan** — no TBD/TODO markers; every step has complete, real code or an exact
command; no step says "similar to Task N" without repeating the actual content.

**Type/name consistency, checked across tasks** — `claim_id`/`ns_id`/`item`/`claimed_at`/
`expires_at` field names match identically across the bash python heredoc (Task 1), the
PowerShell twin (Task 5), the doctor checks (Task 9), and the guide's schema (Task 10). CLI flag
names (`--claim-id`, `--item`, `--ns-id`, `--ttl-hours`) match between the bash `case` parsing
(Tasks 2-3) and the PowerShell `param()` block (Task 5) — bash uses kebab-case flags, PowerShell
uses `-ClaimId`/`-Item`/`-NsId`/`-TtlHours` (PascalCase, no hyphen), which is the correct,
idiomatic difference between the two shells' conventions, not an inconsistency. Subcommand names
(`prune`, `list`, `claim`, `release`, `force-clear`, `notify`) match exactly across both scripts'
usage messages, the guide, and `standards/MEMORY-BANK.md`.
