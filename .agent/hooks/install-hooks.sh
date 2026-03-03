#!/bin/bash
#
# iFlow CLI Git Hooks Installer
# Installs Git hooks for the project
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
AGENT_HOOKS_DIR="$SCRIPT_DIR"

echo -e "${BLUE}══════════════════════════════════════════════════════════${NC}"
echo -e "${BLUE}        iFlow CLI Git Hooks Installer                    ${NC}"
echo -e "${BLUE}══════════════════════════════════════════════════════════${NC}"

# Check if .git directory exists
if [ ! -d "$PROJECT_ROOT/.git" ]; then
    echo -e "${RED}✗ Not a git repository${NC}"
    exit 1
fi

# Create git hooks directory if it doesn't exist
mkdir -p "$GIT_HOOKS_DIR"

# Install pre-commit hook
install_hook() {
    local hook_name="$1"
    local source_file="$AGENT_HOOKS_DIR/$hook_name"
    local target_file="$GIT_HOOKS_DIR/$hook_name"
    
    if [ -f "$source_file" ]; then
        # Backup existing hook if it exists
        if [ -f "$target_file" ]; then
            backup_file="$target_file.backup.$(date +%Y%m%d%H%M%S)"
            cp "$target_file" "$backup_file"
            echo -e "${YELLOW}⚠ Backed up existing $hook_name to $backup_file${NC}"
        fi
        
        # Copy the hook
        cp "$source_file" "$target_file"
        chmod +x "$target_file"
        echo -e "${GREEN}✓ Installed $hook_name${NC}"
    else
        echo -e "${RED}✗ Source file not found: $source_file${NC}"
        return 1
    fi
}

# Install hooks
echo -e "\n${YELLOW}Installing Git hooks...${NC}"
install_hook "pre-commit"
install_hook "commit-msg"

echo -e "\n${BLUE}══════════════════════════════════════════════════════════${NC}"
echo -e "${GREEN}✓ Git hooks installation complete${NC}"
echo ""
echo "Installed hooks:"
echo "  - pre-commit: Runs tests and updates progress file"
echo "  - commit-msg: Validates commit message format"
echo ""
echo "To skip hooks for a commit, use:"
echo "  git commit --no-verify"
echo -e "${BLUE}══════════════════════════════════════════════════════════${NC}"
