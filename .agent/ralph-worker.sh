#!/bin/bash

# ============================================================================
# Ralph-Worker: Individual Agent Worker for Parallel Development
# ============================================================================
#
# This script runs as a worker process managed by ralph-parallel.sh
# Each worker operates in its own Git worktree to avoid conflicts
#
# Usage:
#   ./ralph-worker.sh <agent-id>
#
# Environment:
#   AGENT_ID        - Unique agent identifier (e.g., agent-1, agent-2)
#   WORKTREE_DIR    - Git worktree directory for this agent
#   LOG_FILE        - Log file path
#
# ============================================================================

set -e

# Get agent ID
AGENT_ID="${1:-agent-1}"

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
PARALLEL_DIR="$PROJECT_ROOT/.agent/parallel"
WORKTREE_DIR="$PARALLEL_DIR/worktrees/$AGENT_ID"
LOG_FILE="$PARALLEL_DIR/logs/$AGENT_ID.log"
PID_FILE="$PARALLEL_DIR/pids/$AGENT_ID.pid"
FEATURES_FILE="$PROJECT_ROOT/.agent/features.json"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# ============================================================================
# Logging Functions
# ============================================================================

log() {
    local level="$1"
    shift
    local message="$*"
    local timestamp=$(date "+%Y-%m-%d %H:%M:%S")
    echo "[$timestamp] [$AGENT_ID] [$level] $message" | tee -a "$LOG_FILE"
}

log_info() { log "INFO" "$@"; }
log_success() { log "SUCCESS" "$@"; }
log_warning() { log "WARNING" "$@"; }
log_error() { log "ERROR" "$@"; }

# ============================================================================
# Feature Management Functions
# ============================================================================

update_feature_status() {
    local feature_id="$1"
    local status="$2"
    local notes="${3:-}"
    
    python3 << PYTHON
import json
import sys
from datetime import datetime

try:
    with open('$FEATURES_FILE', 'r') as f:
        data = json.load(f)
    
    for feature in data.get('features', []):
        if feature.get('id') == '$feature_id':
            feature['status'] = '$status'
            feature['claimed_by'] = '$AGENT_ID'
            feature['claimed_at'] = datetime.now().isoformat()
            if '$notes':
                feature['notes'] = '$notes'
    
    with open('$FEATURES_FILE', 'w') as f:
        json.dump(data, f, indent=2, ensure_ascii=False)
    
    print("OK")
    
except Exception as e:
    print(f"Error: {e}", file=sys.stderr)
    sys.exit(1)
PYTHON
}

get_next_task() {
    python3 << PYTHON
import json
import sys

try:
    with open('$FEATURES_FILE', 'r') as f:
        data = json.load(f)
    
    # Priority order
    priority_order = {'critical': 0, 'high': 1, 'medium': 2, 'low': 3}
    
    # Find tasks that are pending or waiting and have all dependencies met
    available_tasks = []
    
    for feature in data.get('features', []):
        status = feature.get('status', 'pending')
        
        # Skip already claimed or completed tasks
        if status in ['claimed', 'active', 'completed']:
            continue
        
        # Check dependencies
        depends_on = feature.get('depends_on', [])
        deps_completed = True
        waiting_for = []
        
        for dep_id in depends_on:
            dep = next((f for f in data.get('features', []) if f.get('id') == dep_id), None)
            if not dep or dep.get('status') != 'completed':
                deps_completed = False
                waiting_for.append(dep_id)
        
        # If dependencies not met, mark as waiting
        if not deps_completed:
            if status != 'waiting':
                feature['status'] = 'waiting'
                feature['waiting_for'] = waiting_for
            continue
        
        # Task is available
        available_tasks.append(feature)
    
    # Sort by priority
    available_tasks.sort(key=lambda x: priority_order.get(x.get('priority', 'medium'), 2))
    
    if available_tasks:
        task = available_tasks[0]
        print(f"{task['id']}|{task.get('priority', 'medium')}|{task.get('category', '')}|{task.get('description', '')}")
        for step in task.get('steps', []):
            print(f"STEP:{step}")
    else:
        print("NO_TASK")
    
except Exception as e:
    print(f"Error: {e}", file=sys.stderr)
    print("ERROR")
PYTHON
}

mark_task_completed() {
    local feature_id="$1"
    local branch_name="feature/$(echo "$feature_id" | tr '[:upper:]' '[:lower:]')"
    
    log_info "Marking task $feature_id as completed"
    
    # Update features.json
    update_feature_status "$feature_id" "completed" "Completed by $AGENT_ID"
    
    # Merge branch to main
    cd "$PROJECT_ROOT"
    git checkout main 2>/dev/null || git checkout master 2>/dev/null
    git merge "$branch_name" -m "[agent] feat($feature_id): completed by $AGENT_ID" || {
        log_warning "Merge had conflicts, resolving..."
        git add -A
        git commit -m "[agent] feat($feature_id): completed by $AGENT_ID (with conflict resolution)"
    }
    
    # Remove worktree
    git worktree remove "$WORKTREE_DIR" 2>/dev/null || true
    git branch -d "$branch_name" 2>/dev/null || true
    
    log_success "Task $feature_id completed and merged"
}

# ============================================================================
# Worktree Management
# ============================================================================

setup_worktree() {
    local feature_id="$1"
    local branch_name="feature/$(echo "$feature_id" | tr '[:upper:]' '[:lower:]')"
    
    log_info "Setting up worktree for $feature_id"
    
    # Create branch
    cd "$PROJECT_ROOT"
    git branch "$branch_name" 2>/dev/null || true
    
    # Create or update worktree
    if [ -d "$WORKTREE_DIR" ]; then
        log_info "Worktree already exists, updating..."
        cd "$WORKTREE_DIR"
        git checkout "$branch_name" 2>/dev/null || true
        git pull origin "$branch_name" 2>/dev/null || true
    else
        git worktree add "$WORKTREE_DIR" "$branch_name"
    fi
    
    log_success "Worktree ready at $WORKTREE_DIR"
}

# ============================================================================
# Task Execution
# ============================================================================

execute_task() {
    local feature_data="$1"
    
    # Parse feature data
    local feature_id=$(echo "$feature_data" | head -1 | cut -d'|' -f1)
    local priority=$(echo "$feature_data" | head -1 | cut -d'|' -f2)
    local category=$(echo "$feature_data" | head -1 | cut -d'|' -f3)
    local description=$(echo "$feature_data" | head -1 | cut -d'|' -f4)
    
    log_info "Starting task: $feature_id"
    log_info "Priority: $priority | Category: $category"
    log_info "Description: $description"
    
    # Setup worktree
    setup_worktree "$feature_id"
    
    # Mark as claimed
    update_feature_status "$feature_id" "active" "Claimed by $AGENT_ID"
    
    # Generate task file in worktree
    local task_file="$WORKTREE_DIR/.agent/ralph-current-task.md"
    mkdir -p "$(dirname "$task_file")"
    
    cat > "$task_file" << EOF
# Ralph-Worker Task: $feature_id

## Agent: $AGENT_ID

**Priority**: $priority  
**Category**: $category  

### Description
$description

### Your Task

Implement this feature following the coding-agent.md guidelines.

Work in this worktree: $WORKTREE_DIR

After completion:
1. Commit your changes
2. The parent process will handle merging

---
*Generated by Ralph-Worker at $(date)*
EOF
    
    log_info "Task file created: $task_file"
    
    # Call iflow to implement
    local iflow_prompt="请阅读并执行 .agent/prompts/coding-agent.md 的要求，完成功能: ${feature_id} - ${description}"
    
    log_info "Calling iflow for implementation..."
    
    cd "$WORKTREE_DIR"
    
    if command -v iflow &> /dev/null; then
        if iflow -y -p "$iflow_prompt"; then
            log_success "iflow completed successfully"
            
            # Commit changes
            git add -A
            git commit -m "[agent] feat($feature_id): $description" || {
                log_warning "No changes to commit"
            }
            
            # Mark as completed
            mark_task_completed "$feature_id"
            return 0
        else
            log_error "iflow failed"
            update_feature_status "$feature_id" "failed" "Failed during implementation"
            return 1
        fi
    else
        log_error "iflow command not found"
        update_feature_status "$feature_id" "failed" "iflow not available"
        return 1
    fi
}

# ============================================================================
# Main Loop
# ============================================================================

main_loop() {
    log_info "Worker $AGENT_ID started"
    log_info "Features file: $FEATURES_FILE"
    log_info "Worktree dir: $WORKTREE_DIR"
    
    # Save PID
    echo $$ > "$PID_FILE"
    
    while true; do
        log_info "Looking for next task..."
        
        # Get next task
        local task_data=$(get_next_task)
        
        if [ "$task_data" = "NO_TASK" ]; then
            log_info "No available tasks. Checking if all complete..."
            
            # Check if all tasks are done
            local pending_count=$(python3 << PYTHON
import json
with open('$FEATURES_FILE', 'r') as f:
    data = json.load(f)
pending = [f for f in data.get('features', []) if f.get('status') not in ['completed', 'failed']]
print(len(pending))
PYTHON
)
            
            if [ "$pending_count" -eq 0 ]; then
                log_success "All tasks completed! Worker $AGENT_ID shutting down."
                break
            else
                log_info "$pending_count tasks still pending (waiting for dependencies). Sleeping..."
                sleep 30
            fi
        elif [ "$task_data" = "ERROR" ]; then
            log_error "Error getting next task"
            sleep 10
        else
            # Execute task
            execute_task "$task_data"
            
            # Small delay before next task
            sleep 2
        fi
    done
    
    # Cleanup
    rm -f "$PID_FILE"
    log_info "Worker $AGENT_ID stopped"
}

# ============================================================================
# Signal Handling
# ============================================================================

cleanup() {
    log_info "Received shutdown signal"
    rm -f "$PID_FILE"
    exit 0
}

trap cleanup SIGTERM SIGINT

# ============================================================================
# Entry Point
# ============================================================================

if [ -z "$AGENT_ID" ]; then
    echo "Usage: $0 <agent-id>"
    echo "Example: $0 agent-1"
    exit 1
fi

# Create log directory
mkdir -p "$(dirname "$LOG_FILE")"

# Start main loop
main_loop
