#!/bin/bash
#
# Memory Bank - Mac/Linux Installer
#
# Run once from the cloned repository. Registers "mb" as a global command.
# After install, open a new terminal and run "mb init" in any project.
#
# Usage:
#   chmod +x install.sh && ./install.sh

set -e

BOLD='\033[1m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

MB_REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MB_BIN="$HOME/.mb/bin"
MB_WRAPPER="$MB_BIN/mb"

echo ""
echo -e "${BOLD} Memory Bank${NC}"
echo  " ==========="
echo ""

# Verify this is the right directory
if [ ! -f "$MB_REPO/scripts/mb.sh" ]; then
    echo -e "${RED} [ERROR] Cannot find scripts/mb.sh in $MB_REPO${NC}"
    echo  "  Run install.sh from the cloned memory-bank repository."
    echo ""
    exit 1
fi

# 1. Create bin directory and mb wrapper script
mkdir -p "$MB_BIN"
cat > "$MB_WRAPPER" << 'WRAPPER'
#!/bin/bash
if [ -z "$MB_HOME" ]; then
    echo "[ERROR] MB_HOME not set. Run install.sh again."
    exit 1
fi
exec bash "$MB_HOME/scripts/mb.sh" "$@"
WRAPPER
chmod +x "$MB_WRAPPER"
echo -e "${GREEN} [OK] mb command installed to $MB_BIN${NC}"

# 2. Detect shell and rc file
detect_rc() {
    if [ -n "$ZSH_VERSION" ] || [ "$(basename "$SHELL")" = "zsh" ]; then
        echo "$HOME/.zshrc"
    elif [ -f "$HOME/.bashrc" ]; then
        echo "$HOME/.bashrc"
    else
        echo "$HOME/.bash_profile"
    fi
}
RC_FILE="$(detect_rc)"

# 3. Write MB_HOME and PATH entries to rc file (idempotent)
if grep -q "MB_HOME=" "$RC_FILE" 2>/dev/null; then
    # Update existing MB_HOME line in case repo moved
    sed -i.bak "s|export MB_HOME=.*|export MB_HOME=\"$MB_REPO\"|" "$RC_FILE" 2>/dev/null || \
    perl -i -pe "s|export MB_HOME=.*|export MB_HOME=\"$MB_REPO\"|" "$RC_FILE"
    echo -e "${GREEN} [OK] MB_HOME updated in $RC_FILE${NC}"
else
    {
        echo ""
        echo "# Memory Bank"
        echo "export MB_HOME=\"$MB_REPO\""
        echo "export PATH=\"\$PATH:$MB_BIN\""
    } >> "$RC_FILE"
    echo -e "${GREEN} [OK] MB_HOME=$MB_REPO added to $RC_FILE${NC}"
    echo -e "${GREEN} [OK] $MB_BIN added to PATH${NC}"
fi

echo ""
echo  " Open a new terminal window (or run: source $RC_FILE)"
echo  " Then in any project:"
echo ""
echo  "     mb init"
echo  "     mb status"
echo ""
echo  " Done."
echo ""
