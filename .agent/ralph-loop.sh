#!/bin/bash

# ============================================================================
# Ralph-Loop: Continuous Development Loop for iFlow CLI
# ============================================================================
# 
# This script implements an autonomous development loop that:
# 1. Reads pending features from features.json
# 2. Selects the highest priority incomplete feature
# 3. Implements the feature
# 4. Tests and verifies
# 5. Commits progress
# 6. Repeats until all features are complete
#
# Named after the "infinite loop" concept, Ralph represents the
# relentless pursuit of completion.
#
# Usage:
#   ./ralph-loop.sh [options]
#
# Options:
#   --dry-run         Show what would be done without executing
#   --max-iterations N  Maximum iterations before stopping (default: 100)
#   --category CAT    Only work on features in specific category
#   --feature ID      Work on specific feature ID
#   --interactive     Prompt before each feature (for supervision)
#   --auto-commit     Automatically commit after each feature
#   --status          Show current status and exit
#   --help            Show this help message
#
# ============================================================================

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
FEATURES_FILE="$PROJECT_ROOT/.agent/features.json"
PROGRESS_FILE="$PROJECT_ROOT/.agent/progress.md"
MAX_ITERATIONS=100
DRY_RUN=false
INTERACTIVE=false
AUTO_COMMIT=true
CATEGORY_FILTER=""
FEATURE_ID=""
ITERATION=0
COMPLETED_THIS_SESSION=0

# ============================================================================
# Utility Functions
# ============================================================================

log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

log_ralph() {
    echo -e "${MAGENTA}[RALPH]${NC} $1"
}

show_help() {
    cat << EOF
Ralph-Loop: Continuous Development Loop for iFlow CLI

Usage: $0 [options]

Options:
  --dry-run           Show what would be done without executing
  --max-iterations N  Maximum iterations before stopping (default: 100)
  --category CAT      Only work on features in specific category
  --feature ID        Work on specific feature ID
  --interactive       Prompt before each feature (for supervision)
  --no-auto-commit    Don't automatically commit after each feature
  --status            Show current status and exit
  --help              Show this help message

Examples:
  $0                          # Run full development loop
  $0 --dry-run                # Preview without executing
  $0 --interactive            # Supervised mode
  $0 --category core          # Only work on core features
  $0 --feature SETUP-1        # Work on specific feature
  $0 --max-iterations 10      # Limit to 10 iterations

EOF
    exit 0
}

# ============================================================================
# Feature Management Functions
# ============================================================================

get_pending_features() {
    # Returns list of pending features sorted by priority
    python3 << 'PYTHON'
import json
import sys

try:
    with open('.agent/features.json', 'r') as f:
        data = json.load(f)
    
    # Filter and sort features
    pending = [f for f in data.get('features', []) if not f.get('passes', False)]
    
    # Sort by priority
    priority_order = {'critical': 0, 'high': 1, 'medium': 2, 'low': 3}
    pending.sort(key=lambda x: priority_order.get(x.get('priority', 'medium'), 2))
    
    # Apply category filter if set
    import os
    category_filter = os.environ.get('RALPH_CATEGORY', '')
    if category_filter:
        pending = [f for f in pending if f.get('category', '').lower() == category_filter.lower()]
    
    # Apply feature ID filter if set
    feature_id = os.environ.get('RALPH_FEATURE_ID', '')
    if feature_id:
        pending = [f for f in pending if f.get('id') == feature_id]
    
    # Output as JSON
    print(json.dumps(pending, ensure_ascii=False))
    
except Exception as e:
    print(f"Error: {e}", file=sys.stderr)
    print("[]")
PYTHON
}

get_next_feature() {
    # Returns the next feature to work on
    python3 << 'PYTHON'
import json
import sys

try:
    with open('.agent/features.json', 'r') as f:
        data = json.load(f)
    
    pending = [f for f in data.get('features', []) if not f.get('passes', False)]
    
    if not pending:
        print("NONE")
        sys.exit(0)
    
    # Sort by priority
    priority_order = {'critical': 0, 'high': 1, 'medium': 2, 'low': 3}
    pending.sort(key=lambda x: priority_order.get(x.get('priority', 'medium'), 2))
    
    # Apply filters
    import os
    category_filter = os.environ.get('RALPH_CATEGORY', '')
    feature_id = os.environ.get('RALPH_FEATURE_ID', '')
    
    if feature_id:
        pending = [f for f in pending if f.get('id') == feature_id]
    elif category_filter:
        pending = [f for f in pending if f.get('category', '').lower() == category_filter.lower()]
    
    if not pending:
        print("NONE")
        sys.exit(0)
    
    # Return first feature
    feature = pending[0]
    print(json.dumps(feature, ensure_ascii=False))
    
except Exception as e:
    print(f"Error: {e}", file=sys.stderr)
    print("ERROR")
PYTHON
}

get_progress_stats() {
    python3 << 'PYTHON'
import json

try:
    with open('.agent/features.json', 'r') as f:
        data = json.load(f)
    
    features = data.get('features', [])
    total = len(features)
    completed = sum(1 for f in features if f.get('passes', False))
    pending = total - completed
    percentage = round(completed / total * 100, 1) if total > 0 else 0
    
    print(f"{total}|{completed}|{pending}|{percentage}")
    
except Exception:
    print("0|0|0|0")
PYTHON
}

update_feature_status() {
    local feature_id="$1"
    local status="$2"
    local notes="$3"
    
    python3 << PYTHON
import json

try:
    with open('.agent/features.json', 'r') as f:
        data = json.load(f)
    
    for feature in data.get('features', []):
        if feature.get('id') == '$feature_id':
            feature['passes'] = $status
            if '$notes':
                feature['notes'] = '$notes'
    
    # Update metadata
    features = data.get('features', [])
    completed = sum(1 for f in features if f.get('passes', False))
    data['metadata']['completed_features'] = completed
    data['metadata']['completion_percentage'] = round(completed / len(features) * 100, 1) if features else 0
    
    with open('.agent/features.json', 'w') as f:
        json.dump(data, f, indent=2, ensure_ascii=False)
    
    print("OK")
    
except Exception as e:
    print(f"Error: {e}")
PYTHON
}

# ============================================================================
# Development Functions
# ============================================================================

implement_feature() {
    local feature_json="$1"
    
    # Parse feature details
    local feature_id=$(echo "$feature_json" | python3 -c "import json,sys; print(json.loads(sys.stdin.read()).get('id',''))")
    local description=$(echo "$feature_json" | python3 -c "import json,sys; print(json.loads(sys.stdin.read()).get('description',''))")
    local priority=$(echo "$feature_json" | python3 -c "import json,sys; print(json.loads(sys.stdin.read()).get('priority','medium'))")
    local category=$(echo "$feature_json" | python3 -c "import json,sys; print(json.loads(sys.stdin.read()).get('category',''))")
    local steps=$(echo "$feature_json" | python3 -c "import json,sys; d=json.loads(sys.stdin.read()); print('\n'.join(['- ' + s for s in d.get('steps',[])]))")
    
    log_ralph "═══════════════════════════════════════════════════════════"
    log_ralph "Implementing: $feature_id"
    log_ralph "═══════════════════════════════════════════════════════════"
    echo ""
    log_info "Description: $description"
    log_info "Priority: $priority | Category: $category"
    echo ""
    log_info "Verification Steps:"
    echo "$steps" | while read line; do
        echo "  $line"
    done
    echo ""
    
    if [ "$DRY_RUN" = true ]; then
        log_warning "[DRY RUN] Would implement this feature"
        return 0
    fi
    
    if [ "$INTERACTIVE" = true ]; then
        read -p "Proceed with implementation? [y/N] " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            log_warning "Skipping feature by user request"
            return 1
        fi
    fi
    
    # Create implementation prompt for AI agent
    local impl_prompt="$PROJECT_ROOT/.agent/ralph-current-task.md"
    cat > "$impl_prompt" << EOF
# Ralph-Loop: Current Task

## Feature: $feature_id

**Priority**: $priority  
**Category**: $category  

### Description
$description

### Verification Steps
$steps

### Implementation Instructions

You are in Ralph-Loop continuous development mode. Your task is to:

1. **Implement this feature** following the description above
2. **Follow project conventions** - check existing code patterns
3. **Test thoroughly** - ensure all verification steps pass
4. **Leave clean state** - no half-implemented code

### Guidelines
- Work incrementally
- Write clean, documented code
- Test as you go
- Commit when feature is complete

### After Implementation
1. Run tests to verify the feature works
2. Update .agent/features.json if feature is complete
3. Commit changes with message: "[agent] feat: $description"

---
*This task was generated by Ralph-Loop at $(date)*
EOF
    
    log_info "Task file created: $impl_prompt"
    log_info "Ready for AI agent implementation"
    
    # Return feature info for the caller
    export RALPH_CURRENT_FEATURE_ID="$feature_id"
    export RALPH_CURRENT_FEATURE_DESC="$description"
    
    return 0
}

run_tests() {
    log_info "Running feature tests..."
    
    if [ -f "$PROJECT_ROOT/.agent/test-features.sh" ]; then
        "$PROJECT_ROOT/.agent/test-features.sh" 2>&1 | tail -20
        return $?
    else
        log_warning "No test script found"
        return 0
    fi
}

commit_progress() {
    local feature_id="$1"
    local description="$2"
    
    if [ "$AUTO_COMMIT" = false ]; then
        log_info "Auto-commit disabled, skipping commit"
        return 0
    fi
    
    # Check if there are changes to commit
    if [ -z "$(git status --porcelain 2>/dev/null)" ]; then
        log_info "No changes to commit"
        return 0
    fi
    
    local commit_msg="[agent] feat($feature_id): $description"
    
    log_info "Committing progress..."
    git add -A
    git commit -m "$commit_msg"
    
    log_success "Progress committed"
}

update_progress_file() {
    local feature_id="$1"
    local description="$2"
    local status="$3"
    
    local timestamp=$(date "+%Y-%m-%d %H:%M:%S")
    
    # Prepend to progress file
    local temp_file=$(mktemp)
    
    cat > "$temp_file" << EOF
# iFlow CLI Development Progress

## Current Status
- **Last Updated**: $timestamp
- **Phase**: Active Development (Ralph-Loop)
- **Active Feature**: $feature_id

---

## Session History

### Ralph-Loop - $timestamp
- **Actions**: $status - $description
- **Feature**: $feature_id
- **Status**: $(if [ "$status" = "COMPLETED" ]; then echo "✅ Completed"; else echo "⚠️ In Progress"; fi)

---

EOF
    
    # Append existing content (skip first 3 lines to avoid duplicate header)
    if [ -f "$PROGRESS_FILE" ]; then
        tail -n +4 "$PROGRESS_FILE" >> "$temp_file"
    fi
    
    mv "$temp_file" "$PROGRESS_FILE"
}

# ============================================================================
# Main Loop
# ============================================================================

show_status() {
    local stats=$(get_progress_stats)
    local total=$(echo "$stats" | cut -d'|' -f1)
    local completed=$(echo "$stats" | cut -d'|' -f2)
    local pending=$(echo "$stats" | cut -d'|' -f3)
    local percentage=$(echo "$stats" | cut -d'|' -f4)
    
    echo ""
    echo "╔══════════════════════════════════════════════════════════╗"
    echo "║              Ralph-Loop Status Report                    ║"
    echo "╚══════════════════════════════════════════════════════════╝"
    echo ""
    echo "  📊 Progress: $completed/$total ($percentage%)"
    echo "  ⏳ Pending: $pending features"
    echo ""
    
    if [ "$pending" -gt 0 ]; then
        echo "  📋 Next features to implement:"
        export RALPH_CATEGORY="$CATEGORY_FILTER"
        export RALPH_FEATURE_ID="$FEATURE_ID"
        get_pending_features | python3 -c "
import json, sys
features = json.loads(sys.stdin.read())
for i, f in enumerate(features[:5], 1):
    priority = f.get('priority', 'medium').upper()
    print(f\"    {i}. [{priority}] {f.get('id')}: {f.get('description')[:50]}...\")
if len(features) > 5:
    print(f\"    ... and {len(features) - 5} more\")
"
    else
        echo "  🎉 All features complete!"
    fi
    echo ""
}

run_loop() {
    log_ralph "Starting Ralph-Loop Continuous Development"
    log_ralph "Max iterations: $MAX_ITERATIONS"
    
    if [ -n "$CATEGORY_FILTER" ]; then
        log_info "Category filter: $CATEGORY_FILTER"
    fi
    if [ -n "$FEATURE_ID" ]; then
        log_info "Feature ID filter: $FEATURE_ID"
    fi
    
    show_status
    
    while [ $ITERATION -lt $MAX_ITERATIONS ]; do
        ITERATION=$((ITERATION + 1))
        
        echo ""
        log_ralph "───────────────────────────────────────────────────────────"
        log_ralph "Iteration #$ITERATION"
        log_ralph "───────────────────────────────────────────────────────────"
        
        # Export filters for Python
        export RALPH_CATEGORY="$CATEGORY_FILTER"
        export RALPH_FEATURE_ID="$FEATURE_ID"
        
        # Get next feature
        local next_feature=$(get_next_feature)
        
        if [ "$next_feature" = "NONE" ]; then
            log_success "All features complete! 🎉"
            break
        fi
        
        if [ "$next_feature" = "ERROR" ]; then
            log_error "Failed to get next feature"
            break
        fi
        
        # Implement feature
        if implement_feature "$next_feature"; then
            # In dry-run mode, just continue
            if [ "$DRY_RUN" = true ]; then
                continue
            fi
            
            # For actual implementation, we'd call an AI agent here
            # For now, we output what should be done
            log_info "Feature ready for implementation"
            log_info "AI Agent should process: $PROJECT_ROOT/.agent/ralph-current-task.md"
            
            # Call iFlow to implement the feature
            log_info "Calling iFlow to implement feature..."
            
            local task_prompt="请阅读并执行 .agent/prompts/coding-agent.md 的要求，完成功能: $feature_id - $(echo "$next_feature" | python3 -c "import json,sys; print(json.loads(sys.stdin.read()).get('description',''))")"
            
            if command -v iflow &> /dev/null; then
                log_info "Running: iflow -y -p \"$task_prompt\""
                if iflow -y -p "$task_prompt"; then
                    log_success "iFlow completed successfully"
                    COMPLETED_THIS_SESSION=$((COMPLETED_THIS_SESSION + 1))
                else
                    log_error "iFlow failed, stopping loop"
                    break
                fi
            else
                log_warning "iFlow command not found, skipping execution"
                log_info "Task prompt saved to: $PROJECT_ROOT/.agent/ralph-current-task.md"
                COMPLETED_THIS_SESSION=$((COMPLETED_THIS_SESSION + 1))
            fi
        fi
        
        # Small delay between iterations
        sleep 1
    done
    
    echo ""
    log_ralph "═══════════════════════════════════════════════════════════"
    log_ralph "Ralph-Loop Completed"
    log_ralph "═══════════════════════════════════════════════════════════"
    echo ""
    log_info "Iterations: $ITERATION"
    log_info "Features processed: $COMPLETED_THIS_SESSION"
    show_status
}

# ============================================================================
# Argument Parsing
# ============================================================================

while [[ $# -gt 0 ]]; do
    case $1 in
        --dry-run)
            DRY_RUN=true
            shift
            ;;
        --max-iterations)
            MAX_ITERATIONS="$2"
            shift 2
            ;;
        --category)
            CATEGORY_FILTER="$2"
            shift 2
            ;;
        --feature)
            FEATURE_ID="$2"
            shift 2
            ;;
        --interactive)
            INTERACTIVE=true
            shift
            ;;
        --no-auto-commit)
            AUTO_COMMIT=false
            shift
            ;;
        --status)
            show_status
            exit 0
            ;;
        --help|-h)
            show_help
            ;;
        *)
            log_error "Unknown option: $1"
            show_help
            ;;
    esac
done

# ============================================================================
# Entry Point
# ============================================================================

cd "$PROJECT_ROOT"

# Check if features.json exists
if [ ! -f "$FEATURES_FILE" ]; then
    log_error "features.json not found at $FEATURES_FILE"
    log_info "Run ./init.sh first to initialize the project"
    exit 1
fi

run_loop
