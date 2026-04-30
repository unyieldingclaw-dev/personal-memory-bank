#!/bin/bash
#
# Initialize Memory Bank Standard in a project.
#
# Usage:
#   ./init-memory-bank.sh [options] [project-path]
#
# Options:
#   --skip-cursor    Skip creating .cursor/rules/ files
#   --skip-claude    Skip creating CLAUDE.md file
#   --force          Overwrite existing files
#   -h, --help       Show this help message
#

# WHY: set -e makes script fail fast on any error, preventing partial setup.
# Without this, a failed mkdir could go unnoticed and cause confusing downstream errors.
set -e

# WHY: ANSI color codes improve UX by making success/warning/error states visually distinct.
# These specific codes work across most terminals (macOS, Linux, WSL).
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
GRAY='\033[0;37m'
NC='\033[0m' # No Color

# WHY: Default to current directory for convenience - most users run from project root.
# Boolean flags default to false so script does everything unless explicitly skipped.
PROJECT_PATH="."
SKIP_CURSOR=false
SKIP_CLAUDE=false
FORCE=false

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --skip-cursor)
            SKIP_CURSOR=true
            shift
            ;;
        --skip-claude)
            SKIP_CLAUDE=true
            shift
            ;;
        --force|-f)
            FORCE=true
            shift
            ;;
        -h|--help)
            head -20 "$0" | tail -18
            exit 0
            ;;
        *)
            PROJECT_PATH="$1"
            shift
            ;;
    esac
done

# WHY: BASH_SOURCE[0] gives script path even when sourced or symlinked.
# We cd to dirname and pwd to get absolute path, handling relative paths and symlinks.
# This ensures templates/ is found regardless of how the script is invoked.
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TEMPLATES_DIR="$(dirname "$SCRIPT_DIR")/templates"

# WHY: Resolve to absolute path to avoid confusion with relative paths.
# 2>/dev/null suppresses errors if path doesn't exist yet (graceful fallback to pwd).
# This allows "./init-memory-bank.sh" to work without specifying a path.
PROJECT_PATH="$(cd "$PROJECT_PATH" 2>/dev/null && pwd)" || PROJECT_PATH="$(pwd)"

echo ""
echo -e "${CYAN}============================================${NC}"
echo -e "${CYAN}  Memory Bank Standard - Project Setup${NC}"
echo -e "${CYAN}============================================${NC}"
echo ""
echo -e "${YELLOW}Project: $PROJECT_PATH${NC}"
echo ""

# WHY: Fail fast if templates missing - better to error immediately than create
# partial setup. This catches the common mistake of running script from wrong directory
# or after moving it without the templates/ folder.
if [ ! -d "$TEMPLATES_DIR" ]; then
    echo -e "${RED}Error: Templates directory not found at $TEMPLATES_DIR${NC}"
    echo -e "${RED}Make sure you're running this from the memory-bank-standard directory.${NC}"
    exit 1
fi

# WHY: Centralized copy function enforces consistent behavior across all file operations.
# The FORCE flag respects user intent (overwrite vs skip), preventing accidental data loss
# while still allowing intentional updates. We auto-create parent dirs because cp doesn't,
# and failing on missing directories is confusing for users.
# WHY: Operates on a single file rather than a directory tree. Callers iterate source
# files and invoke copy_template per file so the skip-if-exists decision can be made
# independently for each destination -- a recursive `cp -r` would be all-or-nothing and
# would clobber any Memory Bank file a user had already customized, defeating the whole
# point of preserving user edits across re-runs.
copy_template() {
    local src="$1"
    local dst="$2"
    
    # WHY: mkdir -p creates parent directories recursively without error if they exist.
    # This prevents cryptic "No such file or directory" errors from cp.
    mkdir -p "$(dirname "$dst")"
    
    if [ -e "$dst" ]; then
        if [ "$FORCE" = true ]; then
            echo -e "  ${YELLOW}Overwriting: $dst${NC}"
            cp -r "$src" "$dst"
        else
            # WHY: Skip existing files by default to preserve user customizations.
            # Memory Bank files often get hand-edited, and we don't want to clobber them.
            echo -e "  ${GRAY}Skipping (exists): $dst${NC}"
        fi
    else
        echo -e "  ${GREEN}Creating: $dst${NC}"
        cp -r "$src" "$dst"
    fi
}

# 1. Create memory-bank directory
echo -e "${CYAN}1. Setting up Memory Bank files...${NC}"
mkdir -p "$PROJECT_PATH/memory-bank"

for file in "$TEMPLATES_DIR/memory-bank"/*; do
    if [ -f "$file" ]; then
        copy_template "$file" "$PROJECT_PATH/memory-bank/$(basename "$file")"
    fi
done

# 2. Create .cursor/rules if not skipped
if [ "$SKIP_CURSOR" = false ]; then
    echo ""
    echo -e "${CYAN}2. Setting up Cursor rules...${NC}"
    mkdir -p "$PROJECT_PATH/.cursor/rules"
    
    for file in "$TEMPLATES_DIR/cursor/rules"/*; do
        if [ -f "$file" ]; then
            copy_template "$file" "$PROJECT_PATH/.cursor/rules/$(basename "$file")"
        fi
    done
else
    echo ""
    echo -e "${GRAY}2. Skipping Cursor rules (--skip-cursor)${NC}"
fi

# 3. Create CLAUDE.md, AGENTS.md, and .claude/commands/ if not skipped
if [ "$SKIP_CLAUDE" = false ]; then
    echo ""
    echo -e "${CYAN}3. Setting up Claude Code...${NC}"
    copy_template "$TEMPLATES_DIR/CLAUDE.md" "$PROJECT_PATH/CLAUDE.md"
    # WHY: AGENTS.md is the cross-tool rules file readable by Claude Code, Cursor, Codex,
    # and Gemini CLI. Copying it per-project ensures any tool can pick up the rules even
    # without the global ~/.claude/AGENTS.md setup.
    copy_template "$TEMPLATES_DIR/AGENTS.md" "$PROJECT_PATH/AGENTS.md"

    # Copy .claude/commands/ slash commands
    mkdir -p "$PROJECT_PATH/.claude/commands"
    for file in "$TEMPLATES_DIR/claude-commands"/*; do
        if [ -f "$file" ]; then
            copy_template "$file" "$PROJECT_PATH/.claude/commands/$(basename "$file")"
        fi
    done
else
    echo ""
    echo -e "${GRAY}3. Skipping CLAUDE.md, AGENTS.md, and .claude/commands/ (--skip-claude)${NC}"
fi

# 4. Copy handoff and plan templates
echo ""
echo -e "${CYAN}4. Copying utility templates...${NC}"
mkdir -p "$PROJECT_PATH/templates"
copy_template "$TEMPLATES_DIR/handoff.md" "$PROJECT_PATH/templates/handoff.md"
copy_template "$TEMPLATES_DIR/plan.md" "$PROJECT_PATH/templates/plan.md"

# WHY: We modify .gitignore to prevent committing temporary AI files.
# .superpowers/ contains brainstorming sessions (can be large, not needed in repo).
# handoff.md is ephemeral - only exists between context switches, should never be committed.
# We check for existing entries to avoid duplicate lines on repeated runs (idempotent).
echo ""
echo -e "${CYAN}5. Updating .gitignore...${NC}"
GITIGNORE="$PROJECT_PATH/.gitignore"

if [ -f "$GITIGNORE" ]; then
    # WHY: grep -q checks silently if pattern exists. We check for .superpowers/ as
    # the unique marker - if it exists, assume we've already added our entries.
    if ! grep -q ".superpowers/" "$GITIGNORE"; then
        echo "" >> "$GITIGNORE"
        echo "# Memory Bank Standard" >> "$GITIGNORE"
        echo ".superpowers/" >> "$GITIGNORE"
        echo "handoff.md" >> "$GITIGNORE"
        echo -e "  ${GREEN}Added .superpowers/ to .gitignore${NC}"
    else
        echo -e "  ${GRAY}.gitignore already configured${NC}"
    fi
else
    # WHY: Create .gitignore if missing - many projects forget this file initially.
    # Better to create it with our entries than skip this step.
    echo "# Memory Bank Standard" > "$GITIGNORE"
    echo ".superpowers/" >> "$GITIGNORE"
    echo "handoff.md" >> "$GITIGNORE"
    echo -e "  ${GREEN}Created .gitignore${NC}"
fi

# Summary
echo ""
echo -e "${CYAN}============================================${NC}"
echo -e "${GREEN}  Setup Complete!${NC}"
echo -e "${CYAN}============================================${NC}"
echo ""
echo -e "${YELLOW}Created files:${NC}"
echo "  memory-bank/"
echo "    projectbrief.md    - Fill in your project requirements"
echo "    systemPatterns.md  - Document your architecture"
echo "    techContext.md     - Specify your tech stack"
echo "    activeContext.md   - Track current work"
echo "    progress.md        - Track progress"
if [ "$SKIP_CURSOR" = false ]; then
    echo "  .cursor/rules/"
    echo "    memory-bank.mdc        - Memory Bank loading"
    echo "    security.mdc           - Security guardrails"
    echo "    code-quality.mdc       - Quality standards"
    echo "    enterprise-logging.mdc - Structured logging"
    echo "    workflow.mdc           - Feature development workflow"
    echo "    accessibility.mdc      - WCAG 2.1 AA (glob-scoped to UI files)"
    echo "    rules-file-integrity.mdc - Anti-prompt-injection hygiene for rule files (glob-scoped)"
fi
if [ "$SKIP_CLAUDE" = false ]; then
    echo "  CLAUDE.md            - Claude Code instructions"
    echo "  AGENTS.md            - Cross-tool rules (Claude Code + Cursor + Codex + Gemini)"
    echo "  .claude/commands/"
    echo "    code-review.md          - /code-review slash command (security, perf, style, tests)"
    echo "    accessibility-review.md - /accessibility-review slash command (WCAG 2.1 AA)"
fi
echo ""
echo -e "${YELLOW}Next steps:${NC}"
echo "  1. Fill in memory-bank/projectbrief.md with your project details"
echo "  2. Fill in memory-bank/techContext.md with your tech stack"
echo "  3. Start coding - AI will automatically have context!"
echo ""
echo -e "${CYAN}Tip: For one-time global setup (rules + plugins for ALL projects),${NC}"
echo -e "${CYAN}     see docs/CLAUDE-CODE-PLUGINS.md${NC}"
echo ""
echo -e "${YELLOW}Quick commands:${NC}"
echo "  mb status  - Check Memory Bank health (Windows: mb.ps1, Mac/Linux: mb.sh)"
echo "  mb update  - Update Memory Bank files"
echo "  Handoff    - Create handoff for context continuation"
echo ""
