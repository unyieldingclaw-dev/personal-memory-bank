---
status: approved
created: 2026-06-24
approved: 2026-06-24
related_spec: null
scope: local
risk: low
source: ai-draft
---

# PMB Performance + Docs Cleanup — Workstream 4

## Context

Full-project audit on 2026-06-24 identified 5 low-severity improvements deferred from WS1–WS3. All are surgical edits. No architecture changes.

---

## Fix 1: O(n²) normalization in mb doctor checks 22 & 23

**Files:** `scripts/mb.sh` (lines 1037–1106), `scripts/mb.ps1` (equivalent section)

**Problem:** Check 22 (`completed-but-still-planned`) and Check 23 (`stale next steps`) both call `_mb_normalize` inside the innermost loop — spawning 4–5 subprocesses per comparison. On 100-line files, this is ~10,000 subprocess spawns per doctor run.

**Fix:** Pre-build a list of normalized strings before the outer loop. The inner loop then iterates over an in-memory array instead of re-normalizing on every iteration.

### sh fix (Check 22)

Before the outer `while` loop (line 1044), build the planned-lines cache:

```sh
    # Pre-normalize all ⏸ lines once to avoid O(n²) subprocess spawning
    declare -a _PLANNED_CACHE=()
    declare -a _PLANNED_FILES=()
    for _pf in projectbrief.md systemPatterns.md techContext.md activeContext.md progress.md; do
        _pp="memory-bank/$_pf"
        [ ! -f "$_pp" ] && continue
        while IFS= read -r _pl; do
            _PLANNED_CACHE+=("$(_mb_normalize "$_pl")")
            _PLANNED_FILES+=("$_pf")
        done < <(grep '⏸' "$_pp" 2>/dev/null)
    done
```

Replace the inner file-reading loop (lines 1052–1066) with an array scan:

```sh
                for _ci in "${!_PLANNED_CACHE[@]}"; do
                    if echo "${_PLANNED_CACHE[$_ci]}" | grep -qF "$window"; then
                        echo -e "${YELLOW}[WARN] Drift: \"$window\" marked ✅ in progress.md but ⏸ in ${_PLANNED_FILES[$_ci]}${NC}"
                        echo "       One of these is stale — resolve before next compaction."
                        C22_FOUND=true
                        DRIFT_FOUND=true
                        matched=true
                        break
                    fi
                done
```

### sh fix (Check 23)

Before the outer `while` loop for check 23 (line 1077), build the done-lines cache:

```sh
    # Pre-normalize all ✅ lines from progress.md once
    declare -a _DONE_CACHE=()
    while IFS= read -r _dl; do
        _DONE_CACHE+=("$(_mb_normalize "$_dl")")
    done < <(grep '✅' "$PROGRESS_FILE" 2>/dev/null)
```

Replace the inner `while IFS= read -r done_line` loop (lines 1090–1101) with:

```sh
                    for _di in "${!_DONE_CACHE[@]}"; do
                        if echo "${_DONE_CACHE[$_di]}" | grep -qF "$swindow"; then
                            trimmed_step=$(echo "$line" | sed 's/^[[:space:]]*//')
                            echo -e "${YELLOW}[WARN] Drift: Next Step appears completed — \"$trimmed_step\"${NC}"
                            echo "       Remove from activeContext.md Next Steps or verify the progress entry."
                            C23_FOUND=true
                            DRIFT_FOUND=true
                            matched_step=true
                            break
                        fi
                    done
```

### ps1 fix

Apply the equivalent pre-cache pattern in `scripts/mb.ps1` for the same two checks — build a `$PlannedCache` and `$DoneCache` array before the outer loops, replace inner file-reading loops with array iterations.

---

## Fix 2: show_budget find pipe

**Files:** `scripts/mb.sh` (lines 1258, 1423)

**Problem:** `find "$MEMORY_BANK_PATH" -maxdepth 1 -type f | xargs wc -c` spawns one `wc` process per file. `find ... -exec wc -c {} +` batches all files into a single `wc` call.

**Fix:**

```sh
# BEFORE (line 1258):
MB_BYTES=$(find "$MEMORY_BANK_PATH" -maxdepth 1 -type f | xargs wc -c 2>/dev/null | tail -1 | awk '{print $1}' || echo "0")

# AFTER:
MB_BYTES=$(find "$MEMORY_BANK_PATH" -maxdepth 1 -type f -exec wc -c {} + 2>/dev/null | tail -1 | awk '{print $1}' || echo "0")
```

Apply the same change at line 1423 (identical pattern in `show_query`).

No `mb.ps1` equivalent — the PowerShell port uses `Get-ChildItem | Measure-Object -Sum Length` which is already a single call.

---

## Fix 3: Stale doctor check count in health-check.md

**File:** `.claude/commands/health-check.md`

**Problem:** The command description says "mb doctor (20 checks)" — doctor now has 24 checks. Same stale count appears in the example output line.

**Fix:** Change both occurrences of `20` → `24` in `.claude/commands/health-check.md`.

Also apply to `templates/claude-commands/health-check.md` (TEMPLATE_OWNED — must stay in sync).

---

## Fix 4: Document .pmb-delegation-depth runtime file

**File:** `docs/HOOKS-GUIDE.md`

**Problem:** `.pmb-delegation-depth` is listed in `.gitignore` and created by `scripts/delegation-depth-check.sh/.ps1`, but is never mentioned in the documentation. Users who see it in their project root have no way to know what it is.

**Fix:** Add one paragraph to the `### 6. Agent Delegation Depth Check` section in `docs/HOOKS-GUIDE.md`:

```
**Runtime state file:** The hook stores its counter in `.pmb-delegation-depth` in the project root (gitignored). This file is created automatically and resets after 2 hours of inactivity. Delete it manually to reset the depth counter mid-session without restarting.
```

---

## Fix 5: mb help — mark deprecated aliases

**File:** `scripts/mb.sh` (show_help function, lines ~44–68)

**Problem:** `mb help` lists only active commands and says nothing about deprecated aliases. Users who try `mb validate` (a common prior command) get a redirect message but have no upfront warning.

**Fix:** Add a `Deprecated aliases:` section at the bottom of the help output:

```sh
    echo "Deprecated aliases (all redirect to current commands):"
    echo "  validate, audit  → mb doctor"
    echo "  update           → mb upgrade"
    echo "  compact, slim, archive, budget  → mb clean"
    echo "  install-hooks    → mb upgrade"
    echo ""
```

Apply the same to `scripts/mb.ps1` show_help equivalent.

---

## Files Modified

| File | Change |
|---|---|
| `scripts/mb.sh` | Fix 1 (checks 22+23 pre-cache), Fix 2 (find pipe), Fix 5 (help aliases) |
| `scripts/mb.ps1` | Fix 1 (ps1 port), Fix 5 (help aliases) |
| `.claude/commands/health-check.md` | Fix 3 (20→24) |
| `templates/claude-commands/health-check.md` | Fix 3 (20→24) |
| `docs/HOOKS-GUIDE.md` | Fix 4 (.pmb-delegation-depth docs) |

---

## Verification

```bash
cd "C:\Users\Mizzo\Claude\Personal-Memory-Bank"

# 1. Tests still pass
bash tests/run.sh 2>&1 | tail -3

# 2. mb doctor still runs
MB_HOME="$(pwd)" bash scripts/mb.sh doctor > /dev/null 2>&1 && echo "doctor: ok"

# 3. mb help shows deprecated aliases
bash scripts/mb.sh help | grep -i deprecated

# 4. health-check.md has 24
grep "24" .claude/commands/health-check.md

# 5. find pipe updated
grep "exec wc" scripts/mb.sh
```
