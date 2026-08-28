#!/usr/bin/env sh
# PreCompact hook — quality gate before context compaction.
# Blocks compaction unless the memory bank shows substantive session work:
#   1. activeContext.md has ≥3 substantive content lines (not just a last-reviewed touch)
#   2. progress.md contains at least one entry dated today
# A handoff.md dated TODAY bypasses both; a stale one does not (see the bypass block below).
# Exits 2 to block compaction; exits 0 to allow. Fails open on errors.

today=$(date +%Y-%m-%d)

BLOCK_REASONS=()

# Bypass: a handoff.md means state is captured via the Handoff Protocol -- but ONLY if the handoff
# is from today.
#
# WHY the staleness test exists: until 2026-08-27 this was a bare `[ -f handoff.md ]` existence
# check. A handoff is written immediately before a context boundary and is meant to be deleted once
# merged into memory-bank/ (Handoff Protocol step 5). One that outlives its session is therefore
# either consumed or abandoned -- in both cases it no longer represents captured state, yet it kept
# handing out a free pass. That was not hypothetical: a handoff dated 2026-08-26 was found still
# sitting in the repo root on 2026-08-27, silently disabling this entire gate for every compaction
# in a long session. The bypass was doing the opposite of its job -- the staler the handoff, the
# more likely the memory bank actually needed the check.
#
# WHY today rather than an age in hours: it matches check 2's own "entry dated today" convention, so
# the gate has one notion of freshness rather than two.
#
# WHY an unreadable mtime falls through instead of bypassing: a bypass that cannot be verified must
# not be honoured. Falling through is safe -- it runs the ordinary checks, it does not hard-block.
if [ -f "handoff.md" ]; then
    handoff_date=$(date -r "handoff.md" +%Y-%m-%d 2>/dev/null || printf '')
    if [ -n "$handoff_date" ] && [ "$handoff_date" = "$today" ]; then
        exit 0
    fi
    # WHY a note rather than a BLOCK_REASON: a stale handoff REMOVES THE BYPASS, it is not itself a
    # failure. If the memory bank is genuinely fresh the gate must still pass. Appending this to
    # BLOCK_REASONS instead was the first implementation and it hard-blocked a healthy bank -- caught
    # by tests/test-pre-compact-check.sh's "stale but fresh" case, which exists for that reason.
    if [ -n "$handoff_date" ]; then
        STALE_HANDOFF_NOTE="handoff.md is dated $handoff_date, not today ($today) — a stale handoff no longer represents captured state, so it did not bypass this gate. Merge it into memory-bank/ and delete it (Handoff Protocol step 5)."
    else
        STALE_HANDOFF_NOTE="handoff.md is present but its modification date could not be read — an unverifiable bypass is not honoured. Delete it if it is spent."
    fi
fi

# Check 1: activeContext.md — must have ≥3 substantive lines
# Substantive = non-frontmatter, non-heading, non-empty, ≥20 chars
ACTIVE_CTX="memory-bank/activeContext.md"
if [ -f "$ACTIVE_CTX" ]; then
    substantive=0
    in_fm=0
    fm_count=0
    while IFS= read -r line; do
        if [ "$line" = "---" ]; then
            fm_count=$((fm_count + 1))
            [ "$fm_count" -eq 1 ] && in_fm=1 || in_fm=0
            continue
        fi
        [ "$in_fm" -eq 1 ] && continue
        case "$line" in
            \#*|'') continue ;;
        esac
        length=${#line}
        # WHY: pure bash expansion avoids spawning sed per line (~100 processes saved)
        trimmed="${line#"${line%%[! ]*}"}"
        trimlen=${#trimmed}
        [ "$trimlen" -ge 20 ] && substantive=$((substantive + 1))
    done < "$ACTIVE_CTX"
    if [ "$substantive" -lt 3 ]; then
        BLOCK_REASONS+=("activeContext.md has only ${substantive} substantive line(s) (need ≥3) — update it with current session state before compacting")
    fi
else
    BLOCK_REASONS+=("activeContext.md missing — run 'mb init'")
fi

# Check 2: progress.md — must contain at least one entry dated today
PROGRESS_FILE="memory-bank/progress.md"
if [ -f "$PROGRESS_FILE" ]; then
    if ! grep -qE "(^|^#+ |^- )${today}" "$PROGRESS_FILE" 2>/dev/null; then
        BLOCK_REASONS+=("progress.md has no entry dated $today — add today's progress before compacting")
    fi
else
    BLOCK_REASONS+=("progress.md missing — run 'mb init'")
fi

if [ "${#BLOCK_REASONS[@]}" -eq 0 ]; then
    exit 0
fi

printf '[PreCompact] Compaction quality gate: %d check(s) failed.\n' "${#BLOCK_REASONS[@]}"
for reason in "${BLOCK_REASONS[@]}"; do
    printf '  - %s\n' "$reason"
done
# Printed only alongside a real failure: it explains why the handoff did not save them.
[ -n "${STALE_HANDOFF_NOTE:-}" ] && printf '  note: %s\n' "$STALE_HANDOFF_NOTE"
printf 'Fix the above, then compact. Or create a handoff.md dated today to bypass via the Handoff Protocol.\n'
exit 2
