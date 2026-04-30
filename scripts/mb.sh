#!/bin/bash
#
# Memory Bank utility commands.
#
# Usage:
#   ./mb.sh <command>
#
# Commands:
#   status   Show file sizes, timestamps, and health check
#   update   Reminder to update Memory Bank (manual action)
#   archive  Show instructions for archiving old content
#   slim     Check if activeContext.md needs trimming
#   commit   Stage and commit Memory Bank changes
#   help     Show this help message

# WHY: set -e makes the script fail fast on unexpected errors rather than
# silently continuing with broken state.
set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
GRAY='\033[0;37m'
NC='\033[0m'

# WHY: Hardcoded relative path assumes script runs from project root.
# This matches the expected usage pattern (developers run "mb" from their project).
MEMORY_BANK_PATH="memory-bank"

COMMAND="${1:-help}"

show_help() {
    echo ""
    echo -e "${CYAN}Memory Bank Utility Commands${NC}"
    echo -e "${CYAN}=============================${NC}"
    echo ""
    echo -e "${YELLOW}Usage: mb <command>${NC}"
    echo ""
    echo "Commands:"
    echo "  status   Show file sizes, timestamps, and health check"
    echo "  update   Reminder to update Memory Bank (manual action)"
    echo "  archive  Show instructions for archiving old content"
    echo "  slim     Check if activeContext.md needs trimming"
    echo "  commit   Stage and commit Memory Bank changes"
    echo "  help     Show this help message"
    echo ""
}

# WHY: Files are declared in an explicit ordered array rather than globbed from
# disk because display order is part of the UX (projectbrief first, progress last
# matches how a reader would onboard) and each file carries its own Target/Max
# metadata that globbing cannot supply. A missing file shows as MISSING rather
# than silently vanishing from the report — only an explicit list can detect that.
show_status() {
    echo ""
    echo -e "${CYAN}Memory Bank Status${NC}"
    echo -e "${CYAN}==================${NC}"
    echo ""

    if [ ! -d "$MEMORY_BANK_PATH" ]; then
        echo -e "${RED}Error: memory-bank/ directory not found${NC}"
        echo -e "${YELLOW}Run init-memory-bank.sh to set up Memory Bank${NC}"
        return
    fi

    # WHY: activeContext.md is capped hardest (100/150) because it represents only
    # in-flight state. progress.md and techContext.md get more headroom (250/400)
    # because they legitimately accumulate history. projectbrief.md stays smallest
    # (80/150) because non-negotiable requirements should be crisp, not prose.
    declare -a FILES=("projectbrief.md:80:150" "systemPatterns.md:180:300" "techContext.md:250:400" "activeContext.md:100:150" "progress.md:250:400")

    printf "%-22s %5s   %6s   %5s     %s\n" "File" "Lines" "Target" "Max" "Status"
    printf "%-22s %5s   %6s   %5s     %s\n" "----" "-----" "------" "---" "------"

    HAS_ISSUES=false

    for entry in "${FILES[@]}"; do
        NAME="${entry%%:*}"
        rest="${entry#*:}"
        TARGET="${rest%%:*}"
        MAX="${rest#*:}"
        PATH_="$MEMORY_BANK_PATH/$NAME"

        if [ -f "$PATH_" ]; then
            LINES=$(wc -l < "$PATH_")

            if [ "$LINES" -gt "$MAX" ]; then
                STATUS="OVER LIMIT"
                COLOR=$RED
                HAS_ISSUES=true
            elif [ "$LINES" -gt "$TARGET" ]; then
                STATUS="Consider trimming"
                COLOR=$YELLOW
            else
                STATUS="OK"
                COLOR=$GREEN
            fi

            printf "%-22s %5d   %6d   %5d     " "$NAME" "$LINES" "$TARGET" "$MAX"
            echo -e "${COLOR}${STATUS}${NC}"
        else
            printf "%-22s %5s   %6s   %5s     " "$NAME" "-" "-" "-"
            echo -e "${RED}MISSING${NC}"
            HAS_ISSUES=true
        fi
    done

    echo ""

    if [ -f "handoff.md" ]; then
        echo -e "${YELLOW}Note: handoff.md exists - merge into Memory Bank and delete${NC}"
    fi

    if [ "$HAS_ISSUES" = true ]; then
        echo -e "${YELLOW}Issues detected. Run 'mb slim' or 'mb archive' to fix.${NC}"
    else
        echo -e "${GREEN}All files healthy.${NC}"
    fi
    echo ""
}

# WHY: Show-update / show_archive / show_slim print terminal instructions instead
# of living as documentation files. The friction of opening a browser or README
# mid-session is exactly the moment developers skip the Memory Bank discipline —
# surfacing the canonical AI prompt at the shell (copy-paste ready) is what makes
# the workflow stick. These commands are guidance, not automation, because the
# actual edits require AI judgement about what to keep vs. archive.
show_update() {
    echo ""
    echo -e "${CYAN}Update Memory Bank${NC}"
    echo -e "${CYAN}==================${NC}"
    echo ""
    echo -e "${YELLOW}To update Memory Bank, tell the AI:${NC}"
    echo ""
    echo '  "Update memory-bank files with the progress from this session"'
    echo ""
    echo -e "${YELLOW}The AI will update:${NC}"
    echo "  - activeContext.md  (current focus, next steps)"
    echo "  - progress.md       (completed items)"
    echo "  - techContext.md    (if dependencies changed)"
    echo "  - systemPatterns.md (if new patterns established)"
    echo ""
}

show_archive() {
    echo ""
    echo -e "${CYAN}Archive Old Content${NC}"
    echo -e "${CYAN}===================${NC}"
    echo ""
    echo -e "${YELLOW}To archive old content from activeContext.md:${NC}"
    echo ""
    echo "1. Move detailed session history to docs/ARCHIVE.md"
    echo "2. Keep only current state in activeContext.md"
    echo "3. Completed 'Next Steps' should move to progress.md"
    echo ""
    echo -e "${YELLOW}Tell the AI:${NC}"
    echo ""
    echo '  "Archive old content from activeContext.md to docs/ARCHIVE.md"'
    echo ""
}

show_slim() {
    echo ""
    echo -e "${CYAN}Slim activeContext.md${NC}"
    echo -e "${CYAN}=====================${NC}"
    echo ""

    SLIM_PATH="$MEMORY_BANK_PATH/activeContext.md"
    if [ -f "$SLIM_PATH" ]; then
        LINES=$(wc -l < "$SLIM_PATH" | tr -d ' ')
        echo -e "${YELLOW}Current size: $LINES lines${NC}"
        echo "Target: 50-100 lines"
        echo "Maximum: 150 lines"
        echo ""

        if [ "$LINES" -gt 150 ]; then
            echo -e "${RED}ACTION NEEDED: File is over limit!${NC}"
        elif [ "$LINES" -gt 100 ]; then
            echo -e "${YELLOW}RECOMMENDED: Consider trimming${NC}"
        else
            echo -e "${GREEN}File is within target range${NC}"
        fi

        echo ""
        echo -e "${YELLOW}To slim the file, tell the AI:${NC}"
        echo ""
        echo '  "Trim activeContext.md to essentials - move history to docs/ARCHIVE.md"'
    else
        echo -e "${RED}Error: activeContext.md not found${NC}"
    fi
    echo ""
}

# WHY: Separate Memory Bank commits from feature commits for cleaner git history.
# Context updates are chore commits — they don't change functionality.
# Confirmation prevents accidental commits of incomplete context.
# Scoping to memory-bank/ prevents accidentally staging other changes.
invoke_commit() {
    echo ""
    echo -e "${CYAN}Commit Memory Bank Changes${NC}"
    echo -e "${CYAN}==========================${NC}"
    echo ""

    # WHY: 2>/dev/null suppresses git errors if not in a repo (graceful handling).
    # --porcelain gives machine-readable output stable across git versions.
    STATUS=$(git status --porcelain "$MEMORY_BANK_PATH" 2>/dev/null)

    if [ -z "$STATUS" ]; then
        echo -e "${YELLOW}No changes in memory-bank/ to commit${NC}"
        return
    fi

    echo -e "${YELLOW}Changes to commit:${NC}"
    echo "$STATUS" | while read -r line; do echo "  $line"; done
    echo ""

    # WHY: Explicit confirmation prevents accidental commits during rapid iteration.
    printf "Commit these changes? (y/n): "
    read -r CONFIRM
    if [ "$CONFIRM" = "y" ] || [ "$CONFIRM" = "Y" ]; then
        git add "$MEMORY_BANK_PATH"
        # WHY: "chore:" prefix follows conventional commits — makes it clear this
        # is maintenance, not a feature/fix. Helps with changelog generation.
        git commit -m "chore: Update Memory Bank context"
        echo ""
        echo -e "${GREEN}Committed!${NC}"
    else
        echo -e "${YELLOW}Cancelled${NC}"
    fi
    echo ""
}

case "$COMMAND" in
    status)  show_status ;;
    update)  show_update ;;
    archive) show_archive ;;
    slim)    show_slim ;;
    commit)  invoke_commit ;;
    help)    show_help ;;
    *)
        echo -e "${RED}Unknown command: $COMMAND${NC}"
        show_help
        exit 1
        ;;
esac
