#!/usr/bin/env sh
# PreCompact hook — memory gate check before context compaction.
# Checks whether memory-bank volatile files were modified today OR handoff.md exists.
# Warns if neither. Always exits 0 — compaction is never blocked. Fails open on errors.

today=$(date +%Y-%m-%d)

memory_bank_fresh=0
for file in memory-bank/activeContext.md memory-bank/progress.md; do
    if [ -f "$file" ]; then
        # GNU date (Linux): date -r file +%Y-%m-%d
        # BSD/macOS stat: stat -f "%Sm" -t "%Y-%m-%d" file
        if mtime=$(date -r "$file" +%Y-%m-%d 2>/dev/null); then
            :
        elif mtime=$(stat -f "%Sm" -t "%Y-%m-%d" "$file" 2>/dev/null); then
            :
        else
            # Cannot determine mtime — fail open
            exit 0
        fi
        if [ "$mtime" = "$today" ]; then
            memory_bank_fresh=1
            break
        fi
    fi
done

if [ "$memory_bank_fresh" -eq 1 ]; then
    exit 0
fi

if [ -f "handoff.md" ]; then
    exit 0
fi

printf '[PreCompact] Memory bank has not been updated this session and no handoff.md exists.\n'
printf 'Update memory-bank/activeContext.md with current state, or run the Handoff Protocol\n'
printf '(create handoff.md) before compaction proceeds.\n'
exit 0
