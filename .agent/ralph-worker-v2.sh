#!/bin/bash
#
# Ralph Worker V2 - File Lock Based Task Worker
# Based on Anthropic's C compiler agent team design
#
# Key features:
# - File-based locking (mkdir is atomic)
# - No complex state management
# - Git worktree isolation
# - Simple retry logic

set -e

# Configuration
AGENT_ID="${1:-agent-1}"
PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CHANGE_NAME="${2:-tank-battle-game}"
CHANGE_DIR="$PROJECT_ROOT/openspec/changes/$CHANGE_NAME"
FEATURES_FILE="$CHANGE_DIR/features.json"
LOCK_DIR="$CHANGE_DIR/current_tasks"
WORKTREE_BASE="$PROJECT_ROOT/.agent/parallel/worktrees"
AGENT_WORKTREE="$WORKTREE_BASE/$AGENT_ID"
LOG_FILE="$PROJECT_ROOT/.agent/parallel/logs/${AGENT_ID}.log"
PID_FILE="$PROJECT_ROOT/.agent/parallel/pids/${AGENT_ID}.pid"

# Create necessary directories
mkdir -p "$WORKTREE_BASE" "$(dirname "$LOG_FILE")" "$(dirname "$PID_FILE")" "$LOCK_DIR"

# Write PID
echo $$ > "$PID_FILE"

# Logging function
log() {
    local level="$1"
    local message="$2"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo "[$timestamp] [$AGENT_ID] [$level] $message" | tee -a "$LOG_FILE"
}

# Cleanup on exit
cleanup() {
    log "INFO" "Worker shutting down..."
    rm -f "$PID_FILE"
}
trap cleanup EXIT

log "INFO" "=========================================="
log "INFO" "Ralph Worker V2 Started"
log "INFO" "Agent ID: $AGENT_ID"
log "INFO" "Change: $CHANGE_NAME"
log "INFO" "=========================================="

# Check if features.json exists
if [ ! -f "$FEATURES_FILE" ]; then
    log "ERROR" "Features file not found: $FEATURES_FILE"
    log "INFO" "Run: ./.agent/openspec-features.sh -i $CHANGE_DIR/tasks.md"
    exit 1
fi

# Function to get next available task
get_next_task() {
    local features_file="$1"
    
    # Parse features.json and find first pending task with no dependencies
    python3 << EOF
import json
import sys
import os

features_file = "$features_file"
lock_dir = "$LOCK_DIR"

try:
    with open(features_file, 'r') as f:
        data = json.load(f)
    
    features = data.get('features', [])
    
    # Priority order
    priority_order = {'critical': 0, 'high': 1, 'medium': 2, 'low': 3}
    
    # Sort by priority
    features.sort(key=lambda x: priority_order.get(x.get('priority', 'medium'), 2))
    
    for feature in features:
        if feature.get('passes') or feature.get('status') == 'completed':
            continue
        
        # Check if task is already locked
        task_id = feature['id']
        lock_path = os.path.join(lock_dir, f"{task_id}.lock")
        
        if os.path.exists(lock_path):
            continue
        
        # Check dependencies
        depends_on = feature.get('depends_on', '')
        if depends_on:
            deps = [d.strip() for d in depends_on.split(',')]
            deps_completed = True
            for dep in deps:
                # Find dependency status
                dep_completed = False
                for f in features:
                    if f['id'] == dep:
                        if f.get('passes') or f.get('status') == 'completed':
                            dep_completed = True
                        break
                if not dep_completed:
                    deps_completed = False
                    break
            
            if not deps_completed:
                continue
        
        # Found available task
        print(f"{task_id}|{feature['description']}|{feature['priority']}")
        sys.exit(0)
    
    print("NO_TASK")
except Exception as e:
    print(f"ERROR: {e}")
    sys.exit(1)
EOF
}

# Function to claim task (atomic)
claim_task() {
    local task_id="$1"
    local lock_path="$LOCK_DIR/${task_id}.lock"
    
    # Try to create lock directory (atomic operation)
    if mkdir "$lock_path" 2>/dev/null; then
        # Lock acquired
        echo "$AGENT_ID" > "$lock_path/agent.txt"
        echo "$(date -u +%Y-%m-%dT%H:%M:%SZ)" > "$lock_path/started_at.txt"
        log "SUCCESS" "Claimed task: $task_id"
        return 0
    else
        # Lock already exists
        return 1
    fi
}

# Function to release task
release_task() {
    local task_id="$1"
    local lock_path="$LOCK_DIR/${task_id}.lock"
    
    if [ -d "$lock_path" ]; then
        rm -rf "$lock_path"
        log "INFO" "Released task: $task_id"
    fi
}

# Function to mark task as completed
complete_task() {
    local task_id="$1"
    local features_file="$2"
    
    # Update features.json
    python3 << EOF
import json
import sys

features_file = "$features_file"
task_id = "$task_id"

try:
    with open(features_file, 'r') as f:
        data = json.load(f)
    
    for feature in data['features']:
        if feature['id'] == task_id:
            feature['passes'] = True
            feature['status'] = 'completed'
            break
    
    with open(features_file, 'w') as f:
        json.dump(data, f, indent=2, ensure_ascii=False)
    
    print("OK")
except Exception as e:
    print(f"ERROR: {e}")
    sys.exit(1)
EOF
}

# Function to setup worktree
setup_worktree() {
    local task_id="$1"
    local task_id_lower=$(echo "$task_id" | tr '[:upper:]' '[:lower:]')
    local branch_name="feature/${task_id_lower}"
    
    log "INFO" "Setting up worktree for $task_id"
    
    # Remove old worktree if exists
    if [ -d "$AGENT_WORKTREE" ]; then
        git worktree remove "$AGENT_WORKTREE" --force 2>/dev/null || true
        rm -rf "$AGENT_WORKTREE"
    fi
    
    # Create new worktree
    cd "$PROJECT_ROOT"
    git worktree add "$AGENT_WORKTREE" -b "$branch_name" 2>/dev/null || git worktree add "$AGENT_WORKTREE" "$branch_name"
    
    # Configure origin remote in worktree
    cd "$AGENT_WORKTREE"
    if ! git remote get-url origin > /dev/null 2>&1; then
        git remote add origin "https://github.com/tanjians/long-agents.git"
    fi
    
    log "SUCCESS" "Worktree ready at $AGENT_WORKTREE"
}

# Function to implement task using iflow
implement_task() {
    local task_id="$1"
    local task_desc="$2"
    
    log "INFO" "Starting implementation of $task_id"
    
    # Create task file for iflow
    cat > "$AGENT_WORKTREE/.agent/ralph-current-task.md" << EOF
# Current Task: $task_id

**Description**: $task_desc

**Change**: $CHANGE_NAME

**Instructions**:
1. Read and understand the task requirements
2. Implement the feature in the worktree
3. Run tests to verify
4. Commit changes with message: "[agent] feat: complete $task_id - $task_desc"
5. Update features.json to mark task as completed

**Working Directory**: $AGENT_WORKTREE
EOF
    
    log "INFO" "Calling iflow for implementation..."
    
    # Change to worktree and run iflow
    cd "$AGENT_WORKTREE"
    
    # Run iflow with timeout
    timeout 600 iflow -y -p "请阅读并执行 .agent/prompts/coding-agent.md 的要求，完成功能: $task_id - $task_desc" || {
        log "WARNING" "iflow timed out or failed, will retry"
        return 1
    }
    
    return 0
}

# Function to merge changes back to main
merge_changes() {
    local task_id="$1"
    
    log "INFO" "Merging changes for $task_id"
    
    cd "$AGENT_WORKTREE"
    
    # Pull latest from main
    git fetch origin master
    
    # Merge (may have conflicts)
    if ! git merge origin/master -m "[agent] Merge master before completing $task_id"; then
        log "WARNING" "Merge conflicts detected, attempting to resolve..."
        # Let iflow resolve conflicts
        iflow -y -p "Resolve merge conflicts and complete the merge" || {
            log "ERROR" "Failed to resolve conflicts"
            return 1
        }
    fi
    
    # Push changes
    git push origin "$(git branch --show-current)" || true
    
    # Checkout master and merge
    cd "$PROJECT_ROOT"
    git fetch origin
    local task_id_lower=$(echo "$task_id" | tr '[:upper:]' '[:lower:]')
    git merge "feature/${task_id_lower}" -m "[agent] feat: complete $task_id" || {
        log "WARNING" "Merge to master failed, may need manual intervention"
        return 1
    }
    
    git push origin master
    
    log "SUCCESS" "Changes merged to master"
}

# Main loop
log "INFO" "Starting main loop..."

while true; do
    log "INFO" "Looking for next task..."
    
    # Get next available task
    task_info=$(get_next_task "$FEATURES_FILE")
    
    if [ "$task_info" = "NO_TASK" ]; then
        log "INFO" "No available tasks found. Waiting..."
        sleep 10
        continue
    fi
    
    if [[ "$task_info" == ERROR* ]]; then
        log "ERROR" "Failed to parse features: $task_info"
        sleep 30
        continue
    fi
    
    # Parse task info
    task_id=$(echo "$task_info" | cut -d'|' -f1)
    task_desc=$(echo "$task_info" | cut -d'|' -f2)
    task_priority=$(echo "$task_info" | cut -d'|' -f3)
    
    log "INFO" "Found task: $task_id (Priority: $task_priority)"
    
    # Try to claim task
    if ! claim_task "$task_id"; then
        log "INFO" "Task $task_id already claimed by another agent"
        sleep 2
        continue
    fi
    
    log "INFO" "=========================================="
    log "INFO" "Working on: $task_id"
    log "INFO" "Description: $task_desc"
    log "INFO" "=========================================="
    
    # Setup worktree
    setup_worktree "$task_id"
    
    # Implement task
    if implement_task "$task_id" "$task_desc"; then
        # Merge changes to master
        if merge_changes "$task_id"; then
            # Complete task
            complete_task "$task_id" "$FEATURES_FILE"
            release_task "$task_id"
            log "SUCCESS" "Task $task_id completed and merged successfully"
        else
            log "ERROR" "Task $task_id completed but merge failed"
            release_task "$task_id"
        fi
    else
        log "ERROR" "Task $task_id failed, releasing lock"
        release_task "$task_id"
    fi
    
    # Cleanup worktree
    if [ -d "$AGENT_WORKTREE" ]; then
        git worktree remove "$AGENT_WORKTREE" --force 2>/dev/null || rm -rf "$AGENT_WORKTREE"
    fi
    
    # Brief pause before next task
    sleep 2
done
