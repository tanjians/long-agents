#!/bin/bash
#
# iFlow CLI Git Hooks Uninstaller
# Removes Git hooks from the project
#

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Get the project root directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
GIT_HOOKS_DIR="$PROJECT_ROOT/.git/hooks"

echo -e "${BLUE}══════════════════════════════════════════════════════════${NC}"
echo -e "${BLUE}        iFlow CLI Git Hooks Uninstaller                  ${NC}"
echo -e "${BLUE}══════════════════════════════════════════════════════════${NC}"

# Check if .git directory exists
if [ ! -d "$PROJECT_ROOT/.git" ]; then
    echo -e "${RED}✗ Not a git repository${NC}"
    exit 1
fi

# Uninstall hook
uninstall_hook() {
    local hook_name="$1"
    local target_file="$GIT_HOOKS_DIR/$hook_name"
    
    if [ -f "$target_file" ]; then
        # Check if it's our hook
        if head -n 3 "$target_file" | grep -q "iFlow CLI"; then
            rm "$target_file"
            echo -e "${GREEN}✓ Removed $hook_name${NC}"
        else
            echo -e "${YELLOW}⚠ $hook_name exists but is not an iFlow CLI hook, skipping${NC}"
        fi
    else
        echo -e "${YELLOW}⚠ $hook_name not found${NC}"
    fi
}

# Uninstall hooks
echo -e "\n${YELLOW}Removing Git hooks...${NC}"
uninstall_hook "pre-commit"
uninstall_hook "commit-msg"

echo -e "\n${BLUE}══════════════════════════════════════════════════════════${NC}"
echo -e "${GREEN}✓ Git hooks uninstallation complete${NC}"
echo -e "${BLUE}══════════════════════════════════════════════════════════${NC}"
