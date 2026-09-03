#!/usr/bin/env sh
# PreToolUse hook — agent spawn count advisory.
# Tracks cumulative Agent invocations per 2-hour window (not nesting depth).
# Warns when count exceeds budget (≤6). True nesting depth cannot be tracked —
# no PostToolUse:Agent hook exists. State in .pmb-delegation-depth (gitignored).
# Always exits 0 — advisory only, not blocking.

DEPTH_FILE=".pmb-delegation-depth"
MAX_AGE_MINUTES=120
BUDGET_LIMIT=6  # cumulative spawns per 2-hour window; see standards/PERFORMANCE-BUDGET.md

depth=0
if [ -f "$DEPTH_FILE" ]; then
    stored_depth=$(grep '^depth=' "$DEPTH_FILE" 2>/dev/null | cut -d= -f2 | tr -d '[:space:]')
    stored_ts=$(grep '^timestamp=' "$DEPTH_FILE" 2>/dev/null | cut -d= -f2- | tr -d '\r')
    if [ -n "$stored_depth" ]; then
        depth="$stored_depth"
    fi
    if [ -n "$stored_ts" ]; then
        ts_epoch=$(date -d "$stored_ts" +%s 2>/dev/null || date -j -f "%Y-%m-%d %H:%M" "$stored_ts" +%s 2>/dev/null || echo 0)
        now_epoch=$(date +%s)
        age_minutes=$(( (now_epoch - ts_epoch) / 60 ))
        if [ "$age_minutes" -gt "$MAX_AGE_MINUTES" ]; then
            depth=0
        fi
    fi
fi

if [ "$depth" -ge "$BUDGET_LIMIT" ]; then
    printf '[WARN] Agent spawn count: %d this session (budget: ≤%d per standards/PERFORMANCE-BUDGET.md)\n' "$((depth + 1))" "$BUDGET_LIMIT"
    printf '       High agent volume increases prompt-injection surface. Consider consolidating tasks.\n'
fi

ts=$(date '+%Y-%m-%d %H:%M')
printf 'depth=%d\ntimestamp=%s\n' "$((depth + 1))" "$ts" > "$DEPTH_FILE" 2>/dev/null || true
exit 0
