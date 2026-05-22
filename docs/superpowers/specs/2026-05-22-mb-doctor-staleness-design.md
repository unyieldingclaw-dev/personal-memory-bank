# mb doctor Check #9 — Staleness Summary Integration

**Date:** 2026-05-22  
**Status:** Approved  
**Scope:** `scripts/mb.sh`, `scripts/mb.ps1` (Check #9 addition only)

---

## Problem

`mb audit` already detects stale memory-bank files using `staleness-threshold` and `last-reviewed` frontmatter. `mb doctor` has 8 health checks but doesn't surface this signal. A user running `mb doctor` for a quick health snapshot gets no warning about stale context files — they have to remember to run `mb audit` separately.

The gap is not detection (it exists in `show_audit()`) — it's integration at the right layer.

---

## Design

Add **Check #9 — Staleness summary** to `show_doctor()` in both `scripts/mb.sh` and `scripts/mb.ps1`.

### What it does

Reads the 5 memory-bank files directly (`memory-bank/projectbrief.md`, `systemPatterns.md`, `techContext.md`, `activeContext.md`, `progress.md`), extracts `last-reviewed`, `staleness-threshold`, and `authority` frontmatter, and emits a single-line summary.

### Output

```
[OK]   All memory-bank files within staleness threshold
```
or:
```
[WARN] 2 stale memory-bank file(s) detected (1 volatile/accumulating, 1 stable) — run 'mb audit' for details
```

### Severity mapping

| Authority | Stale → | Color |
|-----------|---------|-------|
| `immutable` | skip | — |
| `stable` | `[CAUTION]` | yellow |
| `volatile` | `[WARN]` | yellow |
| `accumulating` | `[WARN]` | yellow |

`immutable` files have a 365d threshold by design — they are meant to be permanent and flagging them creates noise.

### Skip conditions

- File does not exist → skip silently (uninitialized repo, not an error)
- `last-reviewed` is `YYYY-MM-DD` placeholder or missing → skip silently (fresh install)
- `staleness-threshold` missing → skip silently

### What it does NOT do

- Does not call `mb audit` as a subprocess (no sub-command invocation from doctor)
- Does not list individual stale files (that is `mb audit`'s job)
- Does not block or exit non-zero (WARN tier — always exit 0)
- Does not add new date arithmetic logic (reuses the `date -d` / `date -j -f` cross-platform pattern already in `show_audit()`)

---

## Implementation Location

### `scripts/mb.sh`

Insert after the compaction integrity block closes (after line 517, before the `echo ""` at line 519):

```bash
  # 9. Staleness summary
  echo "9. Staleness summary"
  STALE_VOLATILE=0; STALE_STABLE=0
  TODAY=$(date +%s)
  for f in projectbrief.md systemPatterns.md techContext.md activeContext.md progress.md; do
    p="memory-bank/$f"
    [ ! -f "$p" ] && continue
    last_reviewed=$(grep -m1 '^last-reviewed:' "$p" 2>/dev/null | sed 's/last-reviewed:[[:space:]]*//' | tr -d ' \r')
    threshold=$(grep -m1 '^staleness-threshold:' "$p" 2>/dev/null | sed 's/staleness-threshold:[[:space:]]*//' | sed 's/d$//' | tr -d ' \r')
    authority=$(grep -m1 '^authority:' "$p" 2>/dev/null | sed 's/authority:[[:space:]]*//' | tr -d ' \r')
    [ -z "$last_reviewed" ] || [ "$last_reviewed" = "YYYY-MM-DD" ] && continue
    [ -z "$threshold" ] && continue
    [ "$authority" = "immutable" ] && continue
    REVIEWED_EPOCH=$(date -d "$last_reviewed" +%s 2>/dev/null || date -j -f "%Y-%m-%d" "$last_reviewed" +%s 2>/dev/null || echo "0")
    DAYS_SINCE=$(( (TODAY - REVIEWED_EPOCH) / 86400 ))
    if [ "$DAYS_SINCE" -gt "$threshold" ]; then
      if [ "$authority" = "stable" ]; then
        STALE_STABLE=$((STALE_STABLE + 1))
      else
        STALE_VOLATILE=$((STALE_VOLATILE + 1))
      fi
    fi
  done
  STALE_TOTAL=$((STALE_VOLATILE + STALE_STABLE))
  if [ "$STALE_TOTAL" -eq 0 ]; then
    echo -e "${GREEN}[OK]   All memory-bank files within staleness threshold${NC}"
  else
    DETAIL=""
    [ "$STALE_VOLATILE" -gt 0 ] && DETAIL="${STALE_VOLATILE} volatile/accumulating"
    [ "$STALE_STABLE" -gt 0 ] && DETAIL="${DETAIL:+$DETAIL, }${STALE_STABLE} stable"
    echo -e "${YELLOW}[WARN] ${STALE_TOTAL} stale memory-bank file(s) detected (${DETAIL}) — run 'mb audit' for details${NC}"
  fi
```

### `scripts/mb.ps1`

Insert after the compaction integrity block closes (~line 598):

```powershell
    # 9. Staleness summary
    Write-Host "9. Staleness summary"
    $staleVolatile = 0; $staleStable = 0
    foreach ($f in @("projectbrief.md","systemPatterns.md","techContext.md","activeContext.md","progress.md")) {
        $p = "memory-bank/$f"
        if (-not (Test-Path $p)) { continue }
        $content = Get-Content $p -Raw
        $lastReviewed = if ($content -match '(?m)^last-reviewed:\s*(\d{4}-\d{2}-\d{2})') { $Matches[1] } else { $null }
        $thresholdStr = if ($content -match '(?m)^staleness-threshold:\s*(\d+)d') { $Matches[1] } else { $null }
        $authority = if ($content -match '(?m)^authority:\s*(\S+)') { $Matches[1] } else { $null }
        if (-not $lastReviewed -or -not $thresholdStr) { continue }
        if ($authority -eq 'immutable') { continue }
        try {
            $lastDate = [datetime]::ParseExact($lastReviewed, 'yyyy-MM-dd', $null)
            $daysSince = ([datetime]::Today - $lastDate).Days
            $thresholdDays = [int]$thresholdStr
            if ($daysSince -gt $thresholdDays) {
                if ($authority -eq 'stable') { $staleStable++ } else { $staleVolatile++ }
            }
        } catch { continue }
    }
    $staleTotal = $staleVolatile + $staleStable
    if ($staleTotal -eq 0) {
        Write-Host "[OK]   All memory-bank files within staleness threshold" -ForegroundColor Green
    } else {
        $parts = @()
        if ($staleVolatile -gt 0) { $parts += "$staleVolatile volatile/accumulating" }
        if ($staleStable -gt 0) { $parts += "$staleStable stable" }
        $detail = $parts -join ", "
        Write-Host "[WARN] $staleTotal stale memory-bank file(s) detected ($detail) — run 'mb audit' for details" -ForegroundColor Yellow
    }
```

---

## Constraints

- WARN tier only — always exit 0
- Reads frontmatter directly — no subprocess calls
- Single output line — doctor is a health check, not a report
- Reuses existing date arithmetic pattern from `show_audit()`
- Skips immutable files by design
- Skips uninitialized placeholders silently

---

## Testing

1. Run `mb doctor` with all `last-reviewed` fields set to today → expect `[OK]`
2. Set `activeContext.md` `last-reviewed` to `2020-01-01` → expect `[WARN] 1 stale... (1 volatile/accumulating)`
3. Set `systemPatterns.md` `last-reviewed` to `2020-01-01` → expect `[WARN] 2 stale... (1 volatile/accumulating, 1 stable)`
4. Set `projectbrief.md` `last-reviewed` to `2020-01-01` → count unchanged (immutable, skipped)
5. Set `last-reviewed` to `YYYY-MM-DD` placeholder → count unchanged (skipped silently)
