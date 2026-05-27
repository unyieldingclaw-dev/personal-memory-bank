#!/bin/bash
#
# Memory Bank utility commands.
#
# Usage:
#   ./mb.sh <command>
#
# Commands:
#   status   Show file sizes, timestamps, and health check
#   audit    Freshness audit — flag stale or overdue files
#   query    Search memory-bank by tag or section header
#   compact  Print AI prompt to compact (deduplicate + summarize) memory
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
ARG="${2:-}"

# WHY: Find templates via MB_HOME (set by install.sh) or relative to script location.
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${MB_HOME:-$(dirname "$SCRIPT_DIR")}"

show_help() {
    echo ""
    echo -e "${CYAN}Memory Bank Utility Commands${NC}"
    echo -e "${CYAN}=============================${NC}"
    echo ""
    echo -e "${YELLOW}Usage: mb <command>${NC}"
    echo ""
    echo "Commands:"
    echo "  init     Initialize Memory Bank in the current project"
    echo "  validate Check that required files and frontmatter are present"
    echo "  doctor   Full health check (git, hooks, file sizes, staleness)"
    echo "  status   Show file sizes, timestamps, and health check"
    echo "  audit    Freshness audit — flag stale or overdue files"
    echo "  query    Search memory-bank by tag or section header"
    echo "  compact  Print AI prompt to compact (deduplicate + summarize) memory"
    echo "  update   Reminder to update Memory Bank (manual action)"
    echo "  archive  Show instructions for archiving old content"
    echo "  slim     Check if activeContext.md needs trimming"
    echo "  commit   Stage and commit Memory Bank changes"
    echo "  upgrade  Propagate current governance templates to this project"
    echo "  budget   Check token budget health (CLAUDE.md + memory-bank/ sizes)"
    echo "  help     Show this help message"
    echo ""
    echo "Examples:"
    echo "  mb audit              Check freshness of all memory-bank files"
    echo "  mb query auth         Find files tagged auth/* or sections mentioning auth"
    echo "  mb compact            Get AI prompt to compact memory"
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

    # WHY: Detect subworktrees so we refuse memory-bank/ mutations from the wrong root.
    COMMON_GIT=$(git rev-parse --git-common-dir 2>/dev/null || true)
    LOCAL_GIT="$PWD/.git"
    if [ -n "$COMMON_GIT" ] && [ "$(realpath "$COMMON_GIT" 2>/dev/null)" != "$(realpath "$LOCAL_GIT" 2>/dev/null)" ]; then
        echo -e "${RED}[ERROR] You are in a git subworktree.${NC}"
        echo -e "${YELLOW}Commit memory-bank/ from the main worktree root instead.${NC}"
        echo ""
        return
    fi

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

invoke_init() {
    echo ""
    echo -e "${CYAN}Memory Bank${NC}"
    echo -e "${CYAN}===========${NC}"
    echo ""

    TEMPLATES_DIR="$REPO_ROOT/templates"
    if [ ! -d "$TEMPLATES_DIR" ]; then
        echo -e "${RED}[ERROR] Templates not found at $TEMPLATES_DIR${NC}"
        echo -e "${YELLOW}Run install.sh from the memory-bank repo, or set MB_HOME.${NC}"
        return
    fi

    TARGET="$(pwd)"
    CREATED=()
    SKIPPED=()

    copy_if_new() {
        local src="$1" dst="$2" label="$3"
        mkdir -p "$(dirname "$dst")"
        if [ ! -e "$dst" ]; then
            cp "$src" "$dst"
            CREATED+=("$label")
        else
            SKIPPED+=("$label")
        fi
    }

    # memory-bank/ files
    for f in "$TEMPLATES_DIR/memory-bank"/*; do
        [ -f "$f" ] && copy_if_new "$f" "$TARGET/memory-bank/$(basename "$f")" "memory-bank/$(basename "$f")"
    done

    # CLAUDE.md
    copy_if_new "$TEMPLATES_DIR/CLAUDE.md" "$TARGET/CLAUDE.md" "CLAUDE.md"

    # .claude/settings.json
    copy_if_new "$TEMPLATES_DIR/.claude/settings.json" "$TARGET/.claude/settings.json" ".claude/settings.json"

    # Hook scripts (explicit allowlist — prevents accidental export of future internal files)
    # NOTE: These are the only portable governance scripts exported by mb init.
    # Additions require a corresponding entry in templates/scripts/ AND a CI integrity update.
    for script in dangerous-commands.sh dangerous-commands.ps1 \
                  check-contract.sh check-contract.ps1 \
                  update-reviewed.sh update-reviewed.ps1; do
        copy_if_new "$TEMPLATES_DIR/scripts/$script" "$TARGET/scripts/$script" "scripts/$script"
    done

    # .claude/commands/
    for f in "$TEMPLATES_DIR/claude-commands"/*; do
        [ -f "$f" ] && copy_if_new "$f" "$TARGET/.claude/commands/$(basename "$f")" ".claude/commands/$(basename "$f")"
    done

    # .gitignore
    if [ -f "$TARGET/.gitignore" ]; then
        if ! grep -q "handoff\.md" "$TARGET/.gitignore"; then
            printf "\n# Memory Bank\nhandoff.md\n" >> "$TARGET/.gitignore"
            CREATED+=(".gitignore (added handoff.md)")
        fi
    else
        printf "# Memory Bank\nhandoff.md\n" > "$TARGET/.gitignore"
        CREATED+=(".gitignore")
    fi

    for item in "${CREATED[@]}"; do echo -e "  ${GREEN}[+] $item${NC}"; done
    for item in "${SKIPPED[@]}"; do echo -e "  ${GRAY}[=] $item (kept existing)${NC}"; done

    echo ""
    if [ ${#CREATED[@]} -gt 0 ]; then
        echo -e "${GREEN}Ready. Open Claude Code and start your first session.${NC}"
    else
        echo -e "${GRAY}Already initialized — no files changed.${NC}"
    fi
    echo ""
    echo -e "${YELLOW}Next:${NC}"
    echo "  Edit memory-bank/projectbrief.md  -- what does this project do?"
    echo "  Edit memory-bank/techContext.md   -- what is your stack?"
    echo "  Run: mb status"
    echo ""
}

show_validate() {
    echo ""
    echo -e "${CYAN}Validation${NC}"
    echo -e "${CYAN}==========${NC}"
    echo ""

    PASS=true

    echo -e "${YELLOW}Required files${NC}"
    for item in \
        "memory-bank/projectbrief.md" \
        "memory-bank/systemPatterns.md" \
        "memory-bank/techContext.md" \
        "memory-bank/activeContext.md" \
        "memory-bank/progress.md" \
        "CLAUDE.md"
    do
        if [ -f "$item" ]; then
            echo -e "  ${GREEN}[OK]      $item${NC}"
        else
            echo -e "  ${RED}[MISSING] $item${NC}"
            PASS=false
        fi
    done

    echo ""
    echo -e "${YELLOW}Frontmatter${NC}"
    for name in projectbrief.md systemPatterns.md techContext.md activeContext.md progress.md; do
        path="memory-bank/$name"
        [ ! -f "$path" ] && continue
        HAS_AUTH=$(grep -c '^authority:' "$path" 2>/dev/null || echo 0)
        HAS_REV=$(grep  -c '^last-reviewed:' "$path" 2>/dev/null || echo 0)
        if [ "$HAS_AUTH" -gt 0 ] && [ "$HAS_REV" -gt 0 ]; then
            echo -e "  ${GREEN}[OK]   $name${NC}"
        else
            MISSING=""
            [ "$HAS_AUTH" -eq 0 ] && MISSING="authority"
            [ "$HAS_REV"  -eq 0 ] && MISSING="$MISSING last-reviewed"
            echo -e "  ${YELLOW}[WARN] $name -- missing:$MISSING${NC}"
        fi
    done

    echo ""
    [ -f "handoff.md" ] && echo -e "  ${YELLOW}[WARN] handoff.md present -- merge and delete${NC}"

    echo ""
    if [ "$PASS" = true ]; then
        echo -e "${GREEN}All checks passed.${NC}"
    else
        echo -e "${RED}Issues found. Run 'mb init' to create missing files.${NC}"
    fi
    echo ""
}

# mb doctor reports mechanically observable integrity signals,
# not semantic correctness or workflow compliance.
# Keep checks deterministic, explainable, and low-noise.
show_doctor() {
    echo ""
    echo -e "${CYAN}Doctor${NC}"
    echo -e "${CYAN}======${NC}"
    echo ""

    # 0. Version
    VERSION_FILE="$REPO_ROOT/VERSION"
    if [ -f "$VERSION_FILE" ]; then
        VERSION=$(cat "$VERSION_FILE" | tr -d '[:space:]')
        echo -e "${GREEN}[OK]   Memory Bank v${VERSION}${NC}"
    else
        echo -e "${YELLOW}[WARN] VERSION file not found${NC}"
    fi

    # 1. Git repo
    if git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
        echo -e "${GREEN}[OK]   Git repository detected${NC}"
    else
        echo -e "${YELLOW}[WARN] Not a git repository — mb commit won't work${NC}"
    fi

    # 2. Templates
    if [ -d "$REPO_ROOT/templates" ]; then
        echo -e "${GREEN}[OK]   Templates found (REPO_ROOT = $REPO_ROOT)${NC}"
    else
        echo -e "${RED}[ERROR] Templates not found — run install.sh from memory-bank repo${NC}"
    fi

    # 3. Required files
    ALL_PRESENT=true
    for f in projectbrief.md systemPatterns.md techContext.md activeContext.md progress.md; do
        [ ! -f "memory-bank/$f" ] && ALL_PRESENT=false && break
    done
    if [ "$ALL_PRESENT" = true ]; then
        echo -e "${GREEN}[OK]   All memory-bank files present${NC}"
    else
        echo -e "${RED}[ERROR] One or more memory-bank files missing — run 'mb init'${NC}"
    fi

    if [ -f "CLAUDE.md" ]; then
        echo -e "${GREEN}[OK]   CLAUDE.md present${NC}"
    else
        echo -e "${RED}[ERROR] CLAUDE.md missing — run 'mb init'${NC}"
    fi

    # 4. Hooks
    if [ -f ".claude/settings.json" ]; then
        if grep -q "PostToolUse" ".claude/settings.json" 2>/dev/null; then
            echo -e "${GREEN}[OK]   PostToolUse hook active (last-reviewed auto-updates)${NC}"
        else
            echo -e "${YELLOW}[WARN] No PostToolUse hook — last-reviewed won't auto-update${NC}"
        fi
        # Hook script existence: extract full relative paths from "command": lines,
        # deduplicate by logical name (basename), check any implementation file exists.
        # Works for both adopted projects (scripts/X) and this repo (templates/scripts/X).
        SEEN_HOOK_NAMES=""
        MISSING_HOOKS=()
        PRESENT_HOOKS=()
        HOOK_PATHS=$(grep '"command":' ".claude/settings.json" 2>/dev/null \
            | grep -oE '[A-Za-z][A-Za-z0-9_/-]*\.(sh|ps1)' \
            | sort -u)
        for hook_path in $HOOK_PATHS; do
            base="${hook_path%.*}"
            name="$(basename "$base")"
            case " $SEEN_HOOK_NAMES " in *" $name "*) continue ;; esac
            SEEN_HOOK_NAMES="$SEEN_HOOK_NAMES $name"
            if compgen -G "${base}.*" > /dev/null 2>&1; then
                PRESENT_HOOKS+=("$name")
            else
                MISSING_HOOKS+=("$name")
            fi
        done
        if [ ${#MISSING_HOOKS[@]} -eq 0 ] && [ ${#PRESENT_HOOKS[@]} -gt 0 ]; then
            _joined=$(printf '%s, ' "${PRESENT_HOOKS[@]}"); _joined="${_joined%, }"
            echo -e "${GREEN}[OK]   Hook scripts present (${_joined})${NC}"
        elif [ ${#MISSING_HOOKS[@]} -gt 0 ]; then
            for h in "${MISSING_HOOKS[@]}"; do
                echo -e "${YELLOW}[WARN] Hook script missing: $h — run 'mb init' to install${NC}"
            done
        fi
    else
        echo -e "${YELLOW}[WARN] No .claude/settings.json — safety hooks inactive${NC}"
    fi

    # 5. Token Budget drift
    GLOBAL_CLAUDE="$HOME/.claude/CLAUDE.md"
    if [ -f "CLAUDE.md" ] && [ -f "$GLOBAL_CLAUDE" ]; then
        LOCAL_HAS=$(grep -c "CLAUDE_AUTOCOMPACT_PCT_OVERRIDE" "CLAUDE.md" 2>/dev/null || echo 0)
        GLOBAL_HAS=$(grep -c "CLAUDE_AUTOCOMPACT_PCT_OVERRIDE" "$GLOBAL_CLAUDE" 2>/dev/null || echo 0)
        if [ "$GLOBAL_HAS" -gt 0 ] && [ "$LOCAL_HAS" -eq 0 ]; then
            echo -e "${YELLOW}[WARN] Token Budget section may have drifted from ~/.claude/CLAUDE.md${NC}"
            echo -e "       Run 'mb init' to refresh or manually copy the Token Budget section"
        elif [ "$LOCAL_HAS" -gt 0 ]; then
            echo -e "${GREEN}[OK]   Token Budget section current${NC}"
        fi
    fi

    # 6. File sizes
    OVER_LIMIT=false
    check_size() { local f="$1" max="$2" lines; lines=$(wc -l < "$f" 2>/dev/null || echo 0); [ "$lines" -gt "$max" ] && echo -e "${YELLOW}[WARN] $f is $lines lines (max $max) — run 'mb slim'${NC}" && OVER_LIMIT=true || true; }
    [ -f "memory-bank/projectbrief.md"   ] && check_size "memory-bank/projectbrief.md"   150
    [ -f "memory-bank/systemPatterns.md" ] && check_size "memory-bank/systemPatterns.md" 300
    [ -f "memory-bank/techContext.md"    ] && check_size "memory-bank/techContext.md"    400
    [ -f "memory-bank/activeContext.md"  ] && check_size "memory-bank/activeContext.md"  150
    [ -f "memory-bank/progress.md"       ] && check_size "memory-bank/progress.md"       400
    [ "$OVER_LIMIT" = false ] && echo -e "${GREEN}[OK]   File sizes within limits${NC}"

    # 7. Handoff
    if [ -f "handoff.md" ]; then
        echo -e "${YELLOW}[WARN] handoff.md found — merge into memory-bank/ and delete${NC}"
    else
        echo -e "${GREEN}[OK]   No pending handoff${NC}"
    fi

    # 8. Compaction integrity
    INTEGRITY_ISSUES=()
    for f in projectbrief.md systemPatterns.md techContext.md activeContext.md progress.md; do
        p="memory-bank/$f"
        [ ! -f "$p" ] && continue

        # Compaction depth
        GEN=$(grep -m1 '^compaction_generation:' "$p" 2>/dev/null | sed 's/compaction_generation:\s*//' | tr -d ' \r' || echo "")
        if [ -n "$GEN" ] && [ "$GEN" -ge 3 ] 2>/dev/null; then
            INTEGRITY_ISSUES+=("${YELLOW}[WARN] memory-bank/$f compaction_generation=$GEN (degraded — regenerate from canonical sources)${NC}")
        elif [ -n "$GEN" ] && [ "$GEN" -eq 2 ] 2>/dev/null; then
            INTEGRITY_ISSUES+=("${YELLOW}[CAUTION] memory-bank/$f compaction_generation=$GEN (recursive abstraction risk)${NC}")
        fi

        # Canonical-source absence: check lineage entries in frontmatter only.
        # Extract the frontmatter block (between the first two '---' delimiters) so
        # that document-body list items are never mistaken for lineage file paths.
        fm=$(awk 'NR==1{next} /^---$/{exit} {print}' "$p" 2>/dev/null)
        # Only process multi-line lineage; 'lineage: []' (inline empty) has no list items.
        if echo "$fm" | grep -q '^lineage: *$'; then
            IN_LINEAGE_FM=false
            while IFS= read -r line; do
                if echo "$line" | grep -q '^lineage: *$'; then
                    IN_LINEAGE_FM=true
                    continue
                fi
                if [ "$IN_LINEAGE_FM" = true ]; then
                    if ! echo "$line" | grep -qE '^\s+-\s'; then
                        break
                    fi
                    ancestor=$(echo "$line" | sed 's/^\s*-\s*//' | sed 's/@.*//' | tr -d ' \r')
                    if echo "$ancestor" | grep -q '/'; then continue; fi
                    if [ -n "$ancestor" ] && [ ! -e "$ancestor" ]; then
                        INTEGRITY_ISSUES+=("${RED}[ERROR] memory-bank/$f lineage root missing: $ancestor (recovery impossible)${NC}")
                    fi
                fi
            done <<< "$fm"
        fi
    done

    if [ ${#INTEGRITY_ISSUES[@]} -eq 0 ]; then
        echo -e "${GREEN}[OK]   Compaction integrity — all files at generation 0-1${NC}"
    else
        for issue in "${INTEGRITY_ISSUES[@]}"; do
            echo -e "$issue"
        done
        echo -e "       Run 'mb compact' to regenerate from lower-generation sources"
    fi

    # 9. Staleness summary
    STALE_VOLATILE=0
    STALE_STABLE=0
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
        [ "$REVIEWED_EPOCH" = "0" ] && continue
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

    # Startup context — observability section (not a numbered health check)
    echo ""
    echo "  Startup Context"
    STARTUP_FILES=()
    [ -f "CLAUDE.md" ] && STARTUP_FILES+=("CLAUDE.md")
    for f in projectbrief.md systemPatterns.md techContext.md activeContext.md progress.md; do
        [ -f "memory-bank/$f" ] && STARTUP_FILES+=("memory-bank/$f")
    done
    TOTAL_BYTES=0
    for f in "${STARTUP_FILES[@]}"; do
        b=$(wc -c < "$f" 2>/dev/null || echo 0)
        TOTAL_BYTES=$((TOTAL_BYTES + b))
    done
    TOTAL_TOKENS=$((TOTAL_BYTES / 4))
    printf "  Files loaded:      %d\n" "${#STARTUP_FILES[@]}"
    printf "  Estimated tokens:  ~%d\n" "$TOTAL_TOKENS"
    echo "  Largest contributors:"
    for f in "${STARTUP_FILES[@]}"; do
        b=$(wc -c < "$f" 2>/dev/null || echo 0)
        echo "$b $f"
    done | sort -rn | head -3 | while IFS=' ' read -r bytes file; do
        tokens=$((bytes / 4))
        printf "    %-37s ~%d tokens\n" "$file" "$tokens"
    done
    COMMIT_30D=$(git log --before="30 days ago" -1 --format="%H" -- "${STARTUP_FILES[@]}" 2>/dev/null)
    if [ -n "$COMMIT_30D" ]; then
        TOTAL_30D=0
        for f in "${STARTUP_FILES[@]}"; do
            b30=$(git show "${COMMIT_30D}:${f}" 2>/dev/null | wc -c 2>/dev/null || echo 0)
            TOTAL_30D=$((TOTAL_30D + b30))
        done
        if [ "$TOTAL_30D" -gt 0 ]; then
            GROWTH=$(( (TOTAL_BYTES - TOTAL_30D) * 100 / TOTAL_30D ))
            if [ "$GROWTH" -gt 20 ]; then
                echo -e "${YELLOW}  30-day growth:     +${GROWTH}% [WARN] — context expanding faster than 20%/month${NC}"
            else
                SIGN=""
                [ "$GROWTH" -ge 0 ] && SIGN="+"
                echo -e "${GREEN}  30-day growth:     ${SIGN}${GROWTH}% [OK]${NC}"
            fi
        else
            echo "  30-day growth:     (files added in last 30 days, no baseline)"
        fi
    else
        echo "  30-day growth:     (no git history older than 30 days)"
    fi
    if [ "$STALE_TOTAL" -gt 0 ]; then
        echo -e "${YELLOW}  Stale but loaded:  $STALE_TOTAL file(s) [WARN]${NC}"
    else
        echo -e "${GREEN}  Stale but loaded:  none [OK]${NC}"
    fi

    echo ""
}

show_budget() {
    echo ""
    echo -e "${CYAN}Token Budget Health${NC}"
    echo -e "${CYAN}===================${NC}"
    echo ""

    CLAUDE_FILE="CLAUDE.md"
    if [ -f "$CLAUDE_FILE" ]; then
        CLAUDE_KB=$(awk 'END {printf "%.1f", NR * 4 / 1024}' "$CLAUDE_FILE")
        CLAUDE_TOKENS=$(awk "BEGIN {printf \"%d\", $CLAUDE_KB * 250}")
        if awk "BEGIN {exit ($CLAUDE_KB > 8) ? 0 : 1}"; then
            echo -e "${YELLOW}  CLAUDE.md      ${CLAUDE_KB} KB  ~${CLAUDE_TOKENS} tokens  [WARN] (loads every session)${NC}"
        else
            echo -e "${GREEN}  CLAUDE.md      ${CLAUDE_KB} KB  ~${CLAUDE_TOKENS} tokens  [OK] (loads every session)${NC}"
        fi
    else
        echo -e "${RED}  CLAUDE.md      not found${NC}"
    fi

    if [ -d "$MEMORY_BANK_PATH" ]; then
        MB_BYTES=$(find "$MEMORY_BANK_PATH" -maxdepth 1 -type f | xargs wc -c 2>/dev/null | tail -1 | awk '{print $1}' || echo "0")
        MB_KB=$(awk "BEGIN {printf \"%.1f\", $MB_BYTES / 1024}")
        MB_TOKENS=$(awk "BEGIN {printf \"%d\", $MB_KB * 250}")
        if awk "BEGIN {exit ($MB_KB > 40) ? 0 : 1}"; then
            echo -e "${YELLOW}  memory-bank/   ${MB_KB} KB  ~${MB_TOKENS} tokens  [WARN] (re-read after every compaction)${NC}"
        else
            echo -e "${GREEN}  memory-bank/   ${MB_KB} KB  ~${MB_TOKENS} tokens  [OK] (re-read after every compaction)${NC}"
        fi
    fi

    AUTOCOMPACT="${CLAUDE_AUTOCOMPACT_PCT_OVERRIDE:-not set (~95%)}"
    [ -n "$CLAUDE_AUTOCOMPACT_PCT_OVERRIDE" ] && AUTOCOMPACT="${CLAUDE_AUTOCOMPACT_PCT_OVERRIDE}%"
    echo -e "${CYAN}  Auto-compact:  ${AUTOCOMPACT}  (CLAUDE_AUTOCOMPACT_PCT_OVERRIDE)${NC}"
    echo ""
    echo -e "${CYAN}  Quota tips:${NC}"
    echo "    /compact Focus on decisions and file paths   (after planning/debugging)"
    echo "    /clear                                       (between unrelated tasks)"
    echo "    /cost                                        (check usage mid-session)"
    echo "    /model opus  ->  /model sonnet               (escalate then return)"
    echo ""
}

show_audit() {
    echo ""
    echo -e "${CYAN}Memory Bank Freshness Audit${NC}"
    echo -e "${CYAN}===========================${NC}"
    echo ""

    if [ ! -d "$MEMORY_BANK_PATH" ]; then
        echo -e "${RED}Error: memory-bank/ directory not found${NC}"
        return
    fi

    TODAY=$(date +%s)
    FILES=("projectbrief.md" "systemPatterns.md" "techContext.md" "activeContext.md" "progress.md")

    printf "%-22s %-16s %-17s %s\n" "File" "Last Reviewed" "Stale Threshold" "Status"
    printf "%-22s %-16s %-17s %s\n" "----" "-------------" "---------------" "------"

    TOTAL_BYTES=0
    STALE_COUNT=0

    for NAME in "${FILES[@]}"; do
        PATH_="$MEMORY_BANK_PATH/$NAME"
        if [ ! -f "$PATH_" ]; then
            printf "%-22s %-16s %-17s " "$NAME" "-" "-"
            echo -e "${RED}MISSING${NC}"
            continue
        fi

        TOTAL_BYTES=$((TOTAL_BYTES + $(wc -c < "$PATH_")))

        LAST_REVIEWED=$(grep -m1 'last-reviewed:' "$PATH_" | sed 's/last-reviewed:\s*//' | tr -d ' \r' || true)
        STALE_DAYS=$(grep -m1 'staleness-threshold:' "$PATH_" | sed 's/staleness-threshold:\s*//' | sed 's/d//' | tr -d ' \r' || echo "90")
        REVIEW_DAYS=$(grep -m1 'review-cycle:' "$PATH_" | sed 's/review-cycle:\s*//' | sed 's/d//' | tr -d ' \r' || true)

        if [ -z "$LAST_REVIEWED" ] || [ "$LAST_REVIEWED" = "YYYY-MM-DD" ]; then
            printf "%-22s %-16s %-17s " "$NAME" "no frontmatter" "${STALE_DAYS}d"
            echo -e "${YELLOW}NO FRONTMATTER${NC}"
            continue
        fi

        # WHY: Convert date to epoch for arithmetic. date -d works on Linux;
        # date -j -f works on macOS. Try both and fall back to awk.
        REVIEWED_EPOCH=$(date -d "$LAST_REVIEWED" +%s 2>/dev/null || date -j -f "%Y-%m-%d" "$LAST_REVIEWED" +%s 2>/dev/null || echo "0")
        DAYS_SINCE=$(( (TODAY - REVIEWED_EPOCH) / 86400 ))

        if [ "$DAYS_SINCE" -gt "${STALE_DAYS:-90}" ]; then
            STATUS="[STALE] ${DAYS_SINCE}d ago"
            COLOR=$RED
            STALE_COUNT=$((STALE_COUNT + 1))
        elif [ -n "$REVIEW_DAYS" ] && [ "$DAYS_SINCE" -gt "$REVIEW_DAYS" ]; then
            STATUS="[DUE] ${DAYS_SINCE}d ago"
            COLOR=$YELLOW
        else
            STATUS="OK (${DAYS_SINCE}d ago)"
            COLOR=$GREEN
        fi

        printf "%-22s %-16s %-17s " "$NAME" "$LAST_REVIEWED" "${STALE_DAYS}d"
        echo -e "${COLOR}${STATUS}${NC}"
    done

    TOTAL_KB=$(( TOTAL_BYTES / 1024 ))
    echo ""
    if [ "$TOTAL_KB" -gt 60 ]; then
        echo -e "${YELLOW}Total memory-bank/ size: ${TOTAL_KB} KB${NC}"
    else
        echo -e "${GRAY}Total memory-bank/ size: ${TOTAL_KB} KB${NC}"
    fi

    if [ "$TOTAL_KB" -gt 60 ] && [ "$STALE_COUNT" -ge 2 ]; then
        echo -e "${YELLOW}Compaction recommended: run 'mb compact' to get a cleanup prompt.${NC}"
    elif [ "$STALE_COUNT" -gt 0 ]; then
        echo -e "${YELLOW}Run 'mb archive' or evict stale entries per MEMORY-BANK.md criteria.${NC}"
    else
        echo -e "${GREEN}All files current.${NC}"
    fi
    echo ""
}

show_query() {
    local KEYWORD="$1"

    if [ -z "$KEYWORD" ]; then
        echo -e "${YELLOW}Usage: mb query <keyword>${NC}"
        echo -e "${YELLOW}Example: mb query auth${NC}"
        return
    fi

    echo ""
    echo -e "${CYAN}Query: $KEYWORD${NC}"
    echo ""

    if [ ! -d "$MEMORY_BANK_PATH" ]; then
        echo -e "${RED}Error: memory-bank/ directory not found${NC}"
        return
    fi

    FILES=("projectbrief.md" "systemPatterns.md" "techContext.md" "activeContext.md" "progress.md")
    FOUND=false

    for NAME in "${FILES[@]}"; do
        PATH_="$MEMORY_BANK_PATH/$NAME"
        if [ ! -f "$PATH_" ]; then continue; fi

        # WHY: Two-pass search — tags in frontmatter, then ## section headers.
        # Frontmatter ends at second --- delimiter; grep -A handles partial matches.
        MATCHED_TAGS=$(awk '
            /^---/ { fm_count++; next }
            fm_count == 1 && /^\s+-\s+/ {
                tag = $0; gsub(/^\s+-\s+/, "", tag)
                if (tag ~ kw) print "  " tag
            }
            fm_count >= 2 { exit }
        ' kw="$KEYWORD" "$PATH_" 2>/dev/null || true)

        MATCHED_SECTIONS=$(grep -n "^## .*$KEYWORD" "$PATH_" 2>/dev/null | sed 's/^/  ## /' || true)

        if [ -n "$MATCHED_TAGS" ] || [ -n "$MATCHED_SECTIONS" ]; then
            FOUND=true
            echo -e "${WHITE}$NAME${NC}"
            [ -n "$MATCHED_TAGS" ] && echo -e "${CYAN}  Tags:${NC}$MATCHED_TAGS"
            [ -n "$MATCHED_SECTIONS" ] && echo -e "${CYAN}$MATCHED_SECTIONS${NC}"
            echo ""
        fi
    done

    if [ "$FOUND" = false ]; then
        echo -e "${YELLOW}No matches for '$KEYWORD' in tags or section headers.${NC}"
        echo -e "${YELLOW}Check your tag vocabulary in standards/MEMORY-BANK.md.${NC}"
    fi
    echo ""
}

show_compact() {
    echo ""
    echo -e "${CYAN}Memory Compaction${NC}"
    echo -e "${CYAN}=================${NC}"
    echo ""

    TOTAL_BYTES=0
    if [ -d "$MEMORY_BANK_PATH" ]; then
        TOTAL_BYTES=$(find "$MEMORY_BANK_PATH" -maxdepth 1 -type f | xargs wc -c 2>/dev/null | tail -1 | awk '{print $1}' || echo "0")
    fi
    TOTAL_KB=$(( TOTAL_BYTES / 1024 ))

    if [ "$TOTAL_KB" -lt 60 ]; then
        echo -e "${GREEN}memory-bank/ is ${TOTAL_KB} KB — below the 60 KB compaction threshold.${NC}"
        echo -e "${YELLOW}Compaction is most valuable when size > 60 KB and mb audit shows stale files.${NC}"
        echo ""
    fi

    echo -e "${YELLOW}Paste this prompt to the AI to compact your memory:${NC}"
    echo ""
    echo "---"
    cat << 'EOF'
Read all files in memory-bank/ in this authority order:
  1. projectbrief.md (immutable — never remove)
  2. systemPatterns.md
  3. techContext.md
  4. activeContext.md
  5. progress.md

Then compact the memory bank:
  - Identify and remove duplicate decisions (keep the most recent / authoritative copy)
  - Flag and surface any contradictions between files for my review
  - Remove entries from activeContext.md that are already captured in progress.md
  - Remove progress.md entries for work completed more than 6 months ago (archive them to docs/archive/progress/)
  - Condense verbose descriptions to their essential decision + rationale
  - Preserve all unique architectural decisions, constraints, and active work

After compacting, show me:
  - What was removed from each file and why
  - Any contradictions found (do not resolve them — surface them for my decision)
  - New line counts for each file

Do not commit the changes until I confirm.
EOF
    echo "---"
    echo ""
}

invoke_upgrade() {
    DRY_RUN=false
    if [ "$ARG" = "--dry-run" ]; then
        DRY_RUN=true
    fi

    echo ""
    echo -e "${CYAN}mb upgrade${NC}"
    echo -e "${CYAN}==========${NC}"
    if [ "$DRY_RUN" = true ]; then
        echo -e "${YELLOW}(dry run — no files will be written)${NC}"
    fi
    echo ""

    # WHY: upgrade requires an mb-managed project; memory-bank/ is the sentinel.
    # Without this gate, upgrade could silently run in unrelated directories.
    if [ ! -d "memory-bank" ]; then
        echo -e "${RED}Error: No memory-bank/ directory found. Run 'mb upgrade' from the root of an mb-managed project.${NC}"
        exit 1
    fi

    TEMPLATES_DIR="$REPO_ROOT/templates"
    if [ ! -d "$TEMPLATES_DIR" ]; then
        echo -e "${RED}Error: Templates not found at $TEMPLATES_DIR${NC}"
        echo -e "${YELLOW}Set MB_HOME or run from the memory-bank repo.${NC}"
        exit 1
    fi

    # WHY: Ownership is hardcoded as explicit arrays — NOT a config file.
    # Ownership semantics are behavior, not data. A config file would invite
    # accidental expansion of overwrite scope. Rationale comments are per-group.
    TEMPLATE_OWNED=(
        # Cursor governance rules — pure governance substrate, no project customization expected
        ".cursor/rules/code-quality.mdc"
        ".cursor/rules/memory-bank.mdc"
        ".cursor/rules/workflow.mdc"
        ".cursor/rules/security.mdc"
        ".cursor/rules/code-review.mdc"
        ".cursor/rules/rules-file-integrity.mdc"
        # Claude Code settings — hook wiring, not project-specific
        ".claude/settings.json"
        # Hook scripts — deterministic enforcement scripts, no project customization
        "scripts/dangerous-commands.sh"
        "scripts/dangerous-commands.ps1"
        "scripts/check-contract.sh"
        "scripts/check-contract.ps1"
        "scripts/update-reviewed.sh"
        "scripts/update-reviewed.ps1"
        # Slash commands — governance workflow commands from templates, not project-specific
        ".claude/commands/code-review.md"
        ".claude/commands/feature-dev.md"
        ".claude/commands/security-review.md"
    )

    ADVISORY_DIFF=(
        # CLAUDE.md is a user cognition surface — users annotate it with project-specific guidance
        "CLAUDE.md"
        # Agent definitions likely contain project-specific tool lists and instructions
        ".claude/agents/researcher.md"
        ".claude/agents/security-reviewer.md"
    )

    # WHY: Template source paths are NOT a 1:1 mirror of target paths.
    # .cursor/rules/X lives at templates/cursor/rules/X (no dot prefix) because
    # the templates directory uses non-hidden layout. .claude/commands/X maps to
    # templates/claude-commands/X (different directory name). All other targets
    # resolve directly under $TEMPLATES_DIR.
    _upgrade_src() {
        local target="$1"
        case "$target" in
            .cursor/rules/*)    echo "$TEMPLATES_DIR/cursor/rules/${target#.cursor/rules/}" ;;
            .claude/commands/*) echo "$TEMPLATES_DIR/claude-commands/${target#.claude/commands/}" ;;
            *)                  echo "$TEMPLATES_DIR/$target" ;;
        esac
    }

    # Process TEMPLATE_OWNED — overwrite unconditionally if stale
    for target in "${TEMPLATE_OWNED[@]}"; do
        src="$(_upgrade_src "$target")"
        if [ ! -f "$src" ]; then
            echo -e "${YELLOW}[?] $target (template-owned source missing — skipped)${NC}"
            continue
        fi
        if [ ! -f "$target" ]; then
            if [ "$DRY_RUN" = true ]; then
                echo -e "${GREEN}[+?] $target (would add)${NC}"
            else
                mkdir -p "$(dirname "$target")"
                cp "$src" "$target"
                echo -e "${GREEN}[+] $target (added)${NC}"
            fi
        elif cmp -s "$src" "$target"; then
            echo -e "${GRAY}[=] $target (unchanged)${NC}"
        else
            if [ "$DRY_RUN" = true ]; then
                echo -e "${YELLOW}[~?] $target (would update)${NC}"
            else
                cp "$src" "$target"
                echo -e "${YELLOW}[~] $target (updated)${NC}"
            fi
        fi
    done

    # Process ADVISORY_DIFF — compare and emit advisory diff, never write
    for target in "${ADVISORY_DIFF[@]}"; do
        src="$(_upgrade_src "$target")"
        if [ ! -f "$src" ]; then
            echo -e "${YELLOW}[?] $target (advisory source missing — cannot compare)${NC}"
            continue
        fi
        if [ ! -f "$target" ]; then
            echo -e "${GRAY}[=] $target (not present in project — no action needed)${NC}"
            continue
        fi
        if cmp -s "$src" "$target"; then
            echo -e "${GRAY}[=] $target (matches template)${NC}"
        else
            echo -e "${YELLOW}[!] $target (differs from template — review manually)${NC}"
            if command -v diff >/dev/null 2>&1; then
                # WHY: diff exits 1 when files differ; || true prevents set -e from aborting.
                DIFF_OUTPUT=$(diff -u "$src" "$target" 2>/dev/null || true)
                DIFF_LINES=$(printf '%s' "$DIFF_OUTPUT" | wc -l)
                if [ "$DIFF_LINES" -le 20 ]; then
                    printf '%s\n' "$DIFF_OUTPUT" | sed 's/^/    /'
                else
                    printf '%s\n' "$DIFF_OUTPUT" | head -n 20 | sed 's/^/    /'
                    REMAINING=$((DIFF_LINES - 20))
                    echo "    ... ($REMAINING more lines — compare manually with: diff $src $target)"
                fi
            else
                echo "    (diff not available — compare manually with: diff $src $target)"
            fi
        fi
    done

    echo ""
}

case "$COMMAND" in
    init)     invoke_init ;;
    validate) show_validate ;;
    doctor)   show_doctor ;;
    status)   show_status ;;
    audit)    show_audit ;;
    query)    show_query "$ARG" ;;
    compact)  show_compact ;;
    update)   show_update ;;
    archive)  show_archive ;;
    slim)     show_slim ;;
    commit)   invoke_commit ;;
    upgrade)  invoke_upgrade ;;
    budget)   show_budget ;;
    help)     show_help ;;
    *)
        echo -e "${RED}Unknown command: $COMMAND${NC}"
        show_help
        exit 1
        ;;
esac
