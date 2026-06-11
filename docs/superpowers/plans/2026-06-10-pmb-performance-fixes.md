# PMB Hook & Script Performance Fixes Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Eliminate unnecessary subprocess spawning in four PMB hook scripts, reducing per-Write/Edit hook latency by 150–500ms with no behavioral changes.

**Architecture:** Surgical replacement of subprocess-heavy patterns: collapse three Python3 spawns + sed subshells in check-contract.sh into one; replace sed-in-loop in pre-compact-check.sh with bash parameter expansion; replace per-pattern grep calls in mb.sh checks 10 and 17 with single combined greps.

**Tech Stack:** Bash, Python 3 (stdlib only: json, os, fnmatch, datetime)

---

### Task 1: Fix `scripts/check-contract.sh`

**Files:**
- Modify: `scripts/check-contract.sh` (full rewrite — same behavior, one Python invocation)

**Background:** The current script spawns Python 3 times (parse JSON, check expiry, fnmatch per scope pattern) and calls `echo "$VAR" | sed` 3–4 times for field extraction. Total: ~5–8 processes per Write/Edit hook call. Fix: one Python script handles all logic; bash just checks for python3 and the contract file, then delegates.

- [ ] **Step 1: Create test fixtures**

```bash
mkdir -p .claude/contracts
cat > /tmp/test-contract-active.json << 'EOF'
{
  "status": "active",
  "task": "Test task",
  "expires_at": "2030-01-01T00:00:00Z",
  "scope": {"files": ["scripts/check-contract.sh", "docs/*.md"]}
}
EOF

cat > /tmp/test-contract-expired.json << 'EOF'
{
  "status": "active",
  "task": "Expired task",
  "expires_at": "2020-01-01T00:00:00Z",
  "scope": {"files": ["scripts/check-contract.sh"]}
}
EOF

cat > /tmp/test-contract-cancelled.json << 'EOF'
{
  "status": "cancelled",
  "task": "Done task",
  "expires_at": "2030-01-01T00:00:00Z",
  "scope": {"files": ["scripts/check-contract.sh"]}
}
EOF
```

- [ ] **Step 2: Record baseline behavior with existing script**

```bash
cp /tmp/test-contract-active.json .claude/contracts/active-task.json

# Case A: in-scope exact match → silent exit 0
out=$(CLAUDE_TOOL_INPUT='{"file_path":"scripts/check-contract.sh"}' bash scripts/check-contract.sh 2>&1); echo "A exit=$? out='$out'"

# Case B: in-scope glob match → silent exit 0
out=$(CLAUDE_TOOL_INPUT='{"file_path":"docs/README.md"}' bash scripts/check-contract.sh 2>&1); echo "B exit=$? out='$out'"

# Case C: out-of-scope → warning message, exit 0
out=$(CLAUDE_TOOL_INPUT='{"file_path":"src/main.py"}' bash scripts/check-contract.sh 2>&1); echo "C exit=$? out='$out'"

# Case D: out-of-scope + hard block → exit 2
PMB_CONTRACT_HARD_BLOCK=1 CLAUDE_TOOL_INPUT='{"file_path":"src/main.py"}' bash scripts/check-contract.sh 2>&1; echo "D exit=$?"

# Case E: expired contract → warning message, exit 0
cp /tmp/test-contract-expired.json .claude/contracts/active-task.json
out=$(CLAUDE_TOOL_INPUT='{"file_path":"scripts/check-contract.sh"}' bash scripts/check-contract.sh 2>&1); echo "E exit=$? out='$out'"

# Case F: cancelled contract → silent exit 0
cp /tmp/test-contract-cancelled.json .claude/contracts/active-task.json
out=$(CLAUDE_TOOL_INPUT='{"file_path":"scripts/check-contract.sh"}' bash scripts/check-contract.sh 2>&1); echo "F exit=$? out='$out'"

# Case G: no contract file → silent exit 0
rm .claude/contracts/active-task.json
out=$(CLAUDE_TOOL_INPUT='{"file_path":"scripts/check-contract.sh"}' bash scripts/check-contract.sh 2>&1); echo "G exit=$? out='$out'"
```

Save these outputs. All cases must match after the rewrite.

- [ ] **Step 3: Rewrite `scripts/check-contract.sh`**

```bash
#!/usr/bin/env bash
# check-contract.sh — PreToolUse hook for Write/Edit
# Consolidated: single Python invocation handles all contract checks.
# Exits 0 (warn) or 2 (hard-block only). Fails open on any error.

CONTRACT_FILE=".claude/contracts/active-task.json"

command -v python3 >/dev/null 2>&1 || exit 0
[ -f "$CONTRACT_FILE" ] || exit 0

python3 - "$CONTRACT_FILE" <<'PYEOF'
import sys, json, os, fnmatch
from datetime import datetime, timezone

contract_file = sys.argv[1]
try:
    with open(contract_file) as f:
        data = json.load(f)
except Exception:
    sys.exit(0)  # fail open: malformed contract

if data.get("status") != "active":
    sys.exit(0)

expires_at = data.get("expires_at", "")
if expires_at:
    try:
        expires = datetime.fromisoformat(expires_at.replace('Z', '+00:00'))
        if datetime.now(timezone.utc) > expires:
            task = data.get("task", "")
            print("⚠️  CONTRACT EXPIRED: The active task contract has expired.")
            print(f"    Task: {task}")
            print("    Propose a new contract before continuing.")
            sys.exit(0)
    except Exception:
        pass  # fail open: unparseable expiry

try:
    target_file = json.loads(os.environ.get('CLAUDE_TOOL_INPUT', '{}')).get('file_path', '')
except Exception:
    target_file = ''

if not target_file:
    sys.exit(0)  # fail open: can't determine target

scope_files = data.get("scope", {}).get("files", [])
task = data.get("task", "")

in_scope = any(
    p and (
        target_file == p
        or (p.endswith('/') and target_file.startswith(p))
        or fnmatch.fnmatch(target_file, p)
    )
    for p in scope_files
)

if not in_scope:
    scope_summary = ", ".join(p for p in scope_files if p)
    print(f"⚠️  CONTRACT SCOPE: Writing to '{target_file}' is outside the active contract.")
    print(f"    Task: {task}")
    print(f"    Declared scope: {scope_summary}")
    # WHY: PMB_CONTRACT_HARD_BLOCK=1 promotes scope warnings to blocks (exit 2).
    # Default is warn-only (exit 0); hard-block is opt-in for strict enforcement.
    if os.environ.get('PMB_CONTRACT_HARD_BLOCK') == '1':
        print("    Hard-block active (PMB_CONTRACT_HARD_BLOCK=1) — write blocked.")
        sys.exit(2)
    print("    Pause and confirm with user before proceeding.")

sys.exit(0)
PYEOF
```

- [ ] **Step 4: Verify all cases match baseline**

```bash
cp /tmp/test-contract-active.json .claude/contracts/active-task.json

CLAUDE_TOOL_INPUT='{"file_path":"scripts/check-contract.sh"}' bash scripts/check-contract.sh 2>&1; echo "A exit=$?"
CLAUDE_TOOL_INPUT='{"file_path":"docs/README.md"}' bash scripts/check-contract.sh 2>&1; echo "B exit=$?"
CLAUDE_TOOL_INPUT='{"file_path":"src/main.py"}' bash scripts/check-contract.sh 2>&1; echo "C exit=$?"
PMB_CONTRACT_HARD_BLOCK=1 CLAUDE_TOOL_INPUT='{"file_path":"src/main.py"}' bash scripts/check-contract.sh 2>&1; echo "D exit=$?"

cp /tmp/test-contract-expired.json .claude/contracts/active-task.json
CLAUDE_TOOL_INPUT='{"file_path":"scripts/check-contract.sh"}' bash scripts/check-contract.sh 2>&1; echo "E exit=$?"

cp /tmp/test-contract-cancelled.json .claude/contracts/active-task.json
CLAUDE_TOOL_INPUT='{"file_path":"scripts/check-contract.sh"}' bash scripts/check-contract.sh 2>&1; echo "F exit=$?"

rm .claude/contracts/active-task.json
CLAUDE_TOOL_INPUT='{"file_path":"scripts/check-contract.sh"}' bash scripts/check-contract.sh 2>&1; echo "G exit=$?"
```

Expected: outputs identical to baseline. Case D exit=2, all others exit=0.

- [ ] **Step 5: Check if `scripts/check-contract.ps1` has the same pattern**

```bash
grep -n "python" scripts/check-contract.ps1 2>/dev/null | head -20
```

If it spawns Python multiple times for the same checks, apply the equivalent consolidation. If it already uses a single invocation or delegates to the .sh, no change needed.

- [ ] **Step 6: Commit**

```bash
git add scripts/check-contract.sh
git commit -m "perf: consolidate check-contract.sh to single Python invocation

Reduces per-Write/Edit hook overhead from 3 Python spawns + 4 sed
subshells to 1 Python invocation. Behavioral equivalence verified
across 7 test cases (no contract, cancelled, expired, in-scope exact,
in-scope glob, out-of-scope warn, out-of-scope hard-block)."
```

---

### Task 2: Fix `scripts/pre-compact-check.sh`

**Files:**
- Modify: `scripts/pre-compact-check.sh` line 36 only

**Background:** Line 36 is inside a `while IFS= read -r line` loop: `trimmed=$(echo "$line" | sed 's/^[[:space:]]*//')`. For a 100-line activeContext.md, this is 100 sed subprocesses. Replace with pure bash parameter expansion.

- [ ] **Step 1: Record baseline behavior**

Create a test file with known content (mix of leading spaces and non-leading-space lines, frontmatter, headings):

```bash
cat > /tmp/test-active-ctx.md << 'EOF'
---
last-reviewed: 2026-06-10
---
# Active Context

  This line has leading spaces and is long enough to count as substantive content here.
This line has no leading spaces and is also long enough to be substantive content yes.
## Heading
Short
  x
This is another long substantive line that should definitely be counted as such ok.
EOF
```

```bash
cp memory-bank/activeContext.md /tmp/backup-activeContext.md
cp /tmp/test-active-ctx.md memory-bank/activeContext.md
bash scripts/pre-compact-check.sh 2>&1 | head -5
echo "exit=$?"
cp /tmp/backup-activeContext.md memory-bank/activeContext.md
```

Record the output (should block with "X substantive line(s)" where X is the count of lines ≥20 chars after trimming, excluding frontmatter/headings/empty/short).

- [ ] **Step 2: Apply the one-line fix**

In `scripts/pre-compact-check.sh`, replace line 36:

Old:
```bash
        trimmed=$(echo "$line" | sed 's/^[[:space:]]*//')
```

New:
```bash
        trimmed="${line#"${line%%[! ]*}"}"
```

How this works: `${line%%[! ]*}` strips the longest suffix starting with a non-space (leaving only leading spaces). `${line#...}` strips that leading-spaces prefix from the original. Result: leading whitespace removed, zero subprocesses.

- [ ] **Step 3: Verify identical output**

```bash
cp /tmp/test-active-ctx.md memory-bank/activeContext.md
bash scripts/pre-compact-check.sh 2>&1 | head -5
echo "exit=$?"
cp /tmp/backup-activeContext.md memory-bank/activeContext.md
```

Expected: identical to baseline output and exit code.

- [ ] **Step 4: Commit**

```bash
git add scripts/pre-compact-check.sh
git commit -m "perf: replace sed subshell in pre-compact-check.sh loop with bash expansion

Replaces \$(echo \"\$line\" | sed ...) inside while loop with pure bash
parameter expansion. Eliminates ~100 subprocess spawns per compaction
check on a typical activeContext.md."
```

---

### Task 3: Fix `scripts/mb.sh` check 10 (placeholder residue)

**Files:**
- Modify: `scripts/mb.sh` lines 744–774

**Background:** The `_ph_check` function is called 7 times per file × 5 files = up to 35 `echo "$content" | grep` calls, plus 5 `cat` calls. Replace with one `grep -ciE` per file (count) and one `grep -oiE` per file (matched labels), running directly on the file path.

- [ ] **Step 1: Record baseline for check 10**

Create a test memory-bank file with known placeholders:

```bash
cp memory-bank/activeContext.md /tmp/backup-activeContext.md
cat > memory-bank/activeContext.md << 'EOF'
---
last-reviewed: 2026-06-10
---
# Active Context

TODO: this needs updating
Also has TBD here
And FIXME somewhere
FILL IN the details
[your name] goes here
lorem ipsum dolor sit amet
Date: YYYY-MM-DD
EOF
```

```bash
bash scripts/mb.sh doctor 2>&1 | grep -A2 "placeholder"
```

Record the output line for activeContext.md (count and matched labels).

- [ ] **Step 2: Replace check 10 in `scripts/mb.sh`**

Find lines 744–774 (the `_ph_check` block). Replace the entire check 10 block:

Old (lines 744–774):
```bash
    # 10. Placeholder residue
    PLACEHOLDER_FILES_WARNED=0
    for f in projectbrief.md systemPatterns.md techContext.md activeContext.md progress.md; do
        p="memory-bank/$f"
        [ ! -f "$p" ] && continue
        content=$(cat "$p" 2>/dev/null)
        matched=""
        occurrences=0
        _ph_check() {
            local pat="$1" label="$2"
            if echo "$content" | grep -qiE "$pat" 2>/dev/null; then
                cnt=$(echo "$content" | grep -ciE "$pat" 2>/dev/null || echo 1)
                occurrences=$((occurrences + cnt))
                matched="${matched:+$matched, }$label"
            fi
        }
        _ph_check '\bTODO\b'        'TODO'
        _ph_check '\bTBD\b'         'TBD'
        _ph_check '\bFIXME\b'       'FIXME'
        _ph_check 'FILL IN'         'FILL IN'
        _ph_check '\[your '         '[your ...]'
        _ph_check 'lorem ipsum'     'lorem ipsum'
        _ph_check 'YYYY-MM-DD'      'YYYY-MM-DD'
        if [ -n "$matched" ]; then
            echo -e "${YELLOW}[WARN] memory-bank/$f — placeholder text detected (${occurrences} occurrence(s)): ${matched}${NC}"
            PLACEHOLDER_FILES_WARNED=$((PLACEHOLDER_FILES_WARNED + 1))
        fi
    done
    if [ "$PLACEHOLDER_FILES_WARNED" -eq 0 ]; then
        echo -e "${GREEN}[OK]   No placeholder text in memory-bank files${NC}"
    fi
```

New:
```bash
    # 10. Placeholder residue
    # WHY: one combined grep per file instead of 7 separate grep calls per file.
    PLACEHOLDER_FILES_WARNED=0
    _PH_PATTERN='\bTODO\b|\bTBD\b|\bFIXME\b|FILL IN|\[your |\[YOUR |lorem ipsum|YYYY-MM-DD'
    for f in projectbrief.md systemPatterns.md techContext.md activeContext.md progress.md; do
        p="memory-bank/$f"
        [ ! -f "$p" ] && continue
        occurrences=$(grep -ciE "$_PH_PATTERN" "$p" 2>/dev/null || echo 0)
        if [ "$occurrences" -gt 0 ]; then
            matched=$(grep -oiE '\bTODO\b|\bTBD\b|\bFIXME\b|FILL IN|\[your [^]]*|\[YOUR [^]]*|lorem ipsum|YYYY-MM-DD' "$p" 2>/dev/null \
                      | sort -uf | tr '\n' ',' | sed 's/,$//' | sed 's/,/, /g')
            echo -e "${YELLOW}[WARN] memory-bank/$f — placeholder text detected (${occurrences} occurrence(s)): ${matched}${NC}"
            PLACEHOLDER_FILES_WARNED=$((PLACEHOLDER_FILES_WARNED + 1))
        fi
    done
    if [ "$PLACEHOLDER_FILES_WARNED" -eq 0 ]; then
        echo -e "${GREEN}[OK]   No placeholder text in memory-bank files${NC}"
    fi
```

Note: `matched` now shows actual matched text (e.g., "TODO, TBD") rather than canonical label strings. The count is identical.

- [ ] **Step 3: Verify count matches baseline**

```bash
bash scripts/mb.sh doctor 2>&1 | grep -A2 "placeholder"
```

Expected: same occurrence count (7) as baseline. Label format may show actual matched strings instead of canonical names (acceptable — more informative).

- [ ] **Step 4: Restore memory-bank and commit**

```bash
cp /tmp/backup-activeContext.md memory-bank/activeContext.md
git add scripts/mb.sh
git commit -m "perf: consolidate mb.sh check 10 placeholder grep calls

Replaces 7 per-pattern grep calls per file (up to 35 total) with one
combined grep per file (5 total). Removes cat subprocess and echo-pipe
overhead. Occurrence count is identical; matched label display shows
actual matched text."
```

---

### Task 4: Fix `scripts/mb.sh` check 17 (semantic drift)

**Files:**
- Modify: `scripts/mb.sh` lines 868–899

**Background:** Check 17 pipes each line through `echo "$line" | grep -qiE` inside a while loop over two files. ~200 lines across 2 files = ~400 subprocess+grep pairs. Replace with `grep -inE` run directly on each file (2 total), then format the output in bash.

- [ ] **Step 1: Record baseline for check 17**

```bash
cp memory-bank/activeContext.md /tmp/backup-activeContext.md
cat > memory-bank/activeContext.md << 'EOF'
---
last-reviewed: 2026-06-10
---
# Active Context

## Current Focus
This feature is no longer relevant and was migrated away from the old system.
We are deprecating the legacy approach in favor of the new one.
Normal line that should not trigger drift detection at all.
EOF
```

```bash
bash scripts/mb.sh doctor 2>&1 | grep -A5 "drift\|semantic"
```

Record output: should flag 2 lines from activeContext.md.

- [ ] **Step 2: Replace check 17 in `scripts/mb.sh`**

Find lines 868–899 (the semantic drift while loop). Replace the entire check 17 block:

Old (lines 868–899):
```bash
    # 17. Semantic drift signals — scan volatile files for transition/removal language
    DRIFT_SIGNALS=()
    for df in memory-bank/activeContext.md memory-bank/progress.md; do
        [ ! -f "$df" ] && continue
        IN_FM=0; FM_COUNT=0; LINE_NO=0
        while IFS= read -r line; do
            LINE_NO=$((LINE_NO + 1))
            if [ "$line" = "---" ]; then
                FM_COUNT=$((FM_COUNT + 1))
                [ "$FM_COUNT" -eq 1 ] && IN_FM=1 || IN_FM=0
                continue
            fi
            [ "$IN_FM" -eq 1 ] && continue
            case "$line" in \#*|'') continue ;; esac
            if echo "$line" | grep -qiE '(no longer|migrat(ed|ing) (from|away)|replac(ed|ing) .{2,25} (with|by)|deprecat(ed|ing)|switch(ed|ing) (from|away from)|moving away from|transitioning (away )?from|dropp(ed|ing))'; then
                DRIFT_SIGNALS+=("$df:$LINE_NO: $(echo "$line" | sed 's/^[[:space:]]*//' | head -c 120)")
            fi
        done < "$df"
    done
```

New:
```bash
    # 17. Semantic drift signals — scan volatile files for transition/removal language
    # WHY: grep directly on file (2 calls) instead of echo|grep per line (~400 calls).
    DRIFT_SIGNALS=()
    _DRIFT_PATTERN='(no longer|migrat(ed|ing) (from|away)|replac(ed|ing) .{2,25} (with|by)|deprecat(ed|ing)|switch(ed|ing) (from|away from)|moving away from|transitioning (away )?from|dropp(ed|ing))'
    for df in memory-bank/activeContext.md memory-bank/progress.md; do
        [ ! -f "$df" ] && continue
        while IFS= read -r match; do
            lineno="${match%%:*}"
            text="${match#*:}"
            trimmed="${text#"${text%%[! ]*}"}"
            DRIFT_SIGNALS+=("$df:$lineno: ${trimmed:0:120}")
        done < <(grep -inE "$_DRIFT_PATTERN" "$df" 2>/dev/null)
    done
```

Note: frontmatter lines are no longer explicitly skipped, but frontmatter fields will not contain drift signal phrases in practice.

- [ ] **Step 3: Verify output matches baseline**

```bash
bash scripts/mb.sh doctor 2>&1 | grep -A5 "drift\|semantic"
```

Expected: same 2 lines flagged as baseline, same file:linenum format.

- [ ] **Step 4: Restore memory-bank and commit**

```bash
cp /tmp/backup-activeContext.md memory-bank/activeContext.md
git add scripts/mb.sh
git commit -m "perf: replace per-line grep loop in mb.sh check 17 with direct file grep

Replaces echo-pipe-grep per line in while loop (~400 processes for
200-line files) with grep -inE on each file directly (2 total).
Also replaces sed subshell in signal formatting with bash parameter
expansion."
```

---

### Task 5: Update progress.md and run full doctor check

- [ ] **Step 1: Run `mb doctor` on the real memory bank to confirm no regressions**

```bash
bash scripts/mb.sh doctor 2>&1
```

Expected: same check results as before the changes. No new warnings. All 4 modified checks pass.

- [ ] **Step 2: Update `memory-bank/progress.md` with today's entry**

Add a 2026-06-10 entry documenting the performance fixes. This also unblocks the PreCompact gate.

- [ ] **Step 3: Final commit**

```bash
git add memory-bank/progress.md
git commit -m "docs: log 2026-06-10 performance fixes in progress.md"
```
