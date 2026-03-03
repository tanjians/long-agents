#!/bin/bash
#
# Ralph Parallel V2 - Multi-Agent Controller with File Locking
# 
# Usage:
#   ./ralph-parallel-v2.sh [options]
#
# Options:
#   --max-agents N    Number of parallel agents (default: 3)
#   --change NAME     Change name to work on (default: tank-battle-game)
#   --status          Show current status
#   --stop            Stop all agents
#   --cleanup         Clean up orphan locks
#   --dry-run         Preview without executing

set -e

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
MAX_AGENTS=3
CHANGE_NAME="tank-battle-game"
DRY_RUN=false

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging
log() {
    local level="$1"
    local message="$2"
    local color="$NC"
    
    case "$level" in
        INFO) color="$BLUE" ;;
        SUCCESS) color="$GREEN" ;;
        WARNING) color="$YELLOW" ;;
        ERROR) color="$RED" ;;
    esac
    
    echo -e "${color}[RALPH-V2] $message${NC}"
}

# Function definitions (must be defined before use)

show_help() {
    cat << EOF
Ralph Parallel V2 - Multi-Agent Development Controller

Usage: $0 [options]

Options:
  --max-agents N    Number of parallel agents (default: 3)
  --change NAME     Change name to work on (default: tank-battle-game)
  --status          Show current status
  --stop            Stop all agents
  --cleanup         Clean up orphan locks (older than 1 hour)
  --dry-run         Preview without executing
  --help            Show this help message

Examples:
  # Start 3 agents working on tank-battle-game
  $0

  # Start single agent (recommended to avoid rate limits)
  $0 --max-agents 1

  # Work on different change
  $0 --change ralph-parallel-v2 --max-agents 2

  # Check status
  $0 --status

  # Stop all agents
  $0 --stop
EOF
}

show_status() {
    log "INFO" "═══════════════════════════════════════════════════════════"
    log "INFO" "Ralph Parallel V2 Status Report"
    log "INFO" "═══════════════════════════════════════════════════════════"
    
    local change_dir="$PROJECT_ROOT/openspec/changes/$CHANGE_NAME"
    local features_file="$change_dir/features.json"
    local lock_dir="$change_dir/current_tasks"
    
    if [ ! -f "$features_file" ]; then
        log "WARNING" "Features file not found: $features_file"
        return
    fi
    
    # Count statistics
    local stats=$(python3 << EOF
import json
import os

features_file = "$features_file"
lock_dir = "$lock_dir"

try:
    with open(features_file, 'r') as f:
        data = json.load(f)
    
    features = data.get('features', [])
    total = len(features)
    completed = sum(1 for f in features if f.get('passes') or f.get('status') == 'completed')
    pending = total - completed
    
    # Count locks
    locked = 0
    if os.path.exists(lock_dir):
        locked = len([d for d in os.listdir(lock_dir) if d.endswith('.lock')])
    
    print(f"{total}|{completed}|{pending}|{locked}")
except Exception as e:
    print(f"ERROR: {e}")
EOF
)
    
    if [[ "$stats" == ERROR* ]]; then
        log "ERROR" "Failed to get stats: $stats"
        return
    fi
    
    local total=$(echo "$stats" | cut -d'|' -f1)
    local completed=$(echo "$stats" | cut -d'|' -f2)
    local pending=$(echo "$stats" | cut -d'|' -f3)
    local locked=$(echo "$stats" | cut -d'|' -f4)
    
    local percentage=0
    if [ "$total" -gt 0 ]; then
        percentage=$((completed * 100 / total))
    fi
    
    echo ""
    echo "  Change: $CHANGE_NAME"
    echo "  Progress: $completed/$total ($percentage%)"
    echo ""
    echo "  📋 Total:     $total"
    echo "  ✅ Completed: $completed"
    echo "  ⏳ Pending:   $pending"
    echo "  🔒 Locked:    $locked"
    echo ""
    
    # Show running agents
    echo "  Running Agents:"
    local running=0
    for i in $(seq 1 $MAX_AGENTS); do
        local pid_file="$PROJECT_ROOT/.agent/parallel/pids/agent-$i.pid"
        if [ -f "$pid_file" ]; then
            local pid=$(cat "$pid_file")
            if ps -p "$pid" > /dev/null 2>&1; then
                echo "    agent-$i: 🟢 Running (PID: $pid)"
                ((running++))
            else
                echo "    agent-$i: ⚪ Not running (stale PID file)"
                rm -f "$pid_file"
            fi
        else
            echo "    agent-$i: ⚪ Not running"
        fi
    done
    
    echo ""
    echo "  Active Locks:"
    if [ -d "$lock_dir" ]; then
        for lock in "$lock_dir"/*.lock; do
            if [ -d "$lock" ]; then
                local task_name=$(basename "$lock" .lock)
                local agent=$(cat "$lock/agent.txt" 2>/dev/null || echo "unknown")
                local started=$(cat "$lock/started_at.txt" 2>/dev/null || echo "unknown")
                echo "    $task_name - $agent (started: $started)"
            fi
        done
    fi
    
    echo ""
    echo "  Total: $running/$MAX_AGENTS agents running"
}

stop_agents() {
    log "INFO" "Stopping all agents..."
    
    local stopped=0
    for i in $(seq 1 10); do
        local pid_file="$PROJECT_ROOT/.agent/parallel/pids/agent-$i.pid"
        if [ -f "$pid_file" ]; then
            local pid=$(cat "$pid_file")
            if ps -p "$pid" > /dev/null 2>&1; then
                log "INFO" "Stopping agent-$i (PID: $pid)..."
                kill "$pid" 2>/dev/null || true
                ((stopped++))
            fi
            rm -f "$pid_file"
        fi
    done
    
    log "SUCCESS" "Stopped $stopped agents"
}

cleanup_locks() {
    log "INFO" "Cleaning up orphan locks..."
    
    local change_dir="$PROJECT_ROOT/openspec/changes/$CHANGE_NAME"
    local lock_dir="$change_dir/current_tasks"
    
    if [ ! -d "$lock_dir" ]; then
        log "INFO" "No locks to clean"
        return
    fi
    
    local cleaned=0
    local one_hour_ago=$(date -v-1H +%s 2>/dev/null || date -d '1 hour ago' +%s)
    
    for lock in "$lock_dir"/*.lock; do
        if [ -d "$lock" ]; then
            local started_file="$lock/started_at.txt"
            if [ -f "$started_file" ]; then
                local started=$(cat "$started_file")
                # Convert ISO format to timestamp
                local started_ts=$(date -j -f "%Y-%m-%dT%H:%M:%SZ" "$started" +%s 2>/dev/null || date -d "$started" +%s)
                
                if [ "$started_ts" -lt "$one_hour_ago" ]; then
                    local task_name=$(basename "$lock" .lock)
                    log "WARNING" "Removing orphan lock: $task_name (started: $started)"
                    rm -rf "$lock"
                    ((cleaned++))
                fi
            fi
        fi
    done
    
    log "SUCCESS" "Cleaned up $cleaned orphan locks"
}

# Parse arguments (after all functions are defined)
while [[ $# -gt 0 ]]; do
    case $1 in
        --max-agents)
            MAX_AGENTS="$2"
            shift 2
            ;;
        --change)
            CHANGE_NAME="$2"
            shift 2
            ;;
        --status)
            show_status
            exit 0
            ;;
        --stop)
            stop_agents
            exit 0
            ;;
        --cleanup)
            cleanup_locks
            exit 0
            ;;
        --dry-run)
            DRY_RUN=true
            shift
            ;;
        --help|-h)
            show_help
            exit 0
            ;;
        *)
            log "ERROR" "Unknown option: $1"
            show_help
            exit 1
            ;;
    esac
done

# Main execution
log "INFO" "═══════════════════════════════════════════════════════════"
log "INFO" "Ralph Parallel V2 Controller"
log "INFO" "═══════════════════════════════════════════════════════════"
log "INFO" "Configuration:"
log "INFO" "  Change: $CHANGE_NAME"
log "INFO" "  Max Agents: $MAX_AGENTS"
log "INFO" "  Dry Run: $DRY_RUN"
log "INFO" "═══════════════════════════════════════════════════════════"

# Check if features.json exists
CHANGE_DIR="$PROJECT_ROOT/openspec/changes/$CHANGE_NAME"
FEATURES_FILE="$CHANGE_DIR/features.json"

if [ ! -f "$FEATURES_FILE" ]; then
    log "ERROR" "Features file not found: $FEATURES_FILE"
    log "INFO" "Please run: ./.agent/openspec-features.sh -i $CHANGE_DIR/tasks.md"
    exit 1
fi

# Check for worker script
WORKER_SCRIPT="$SCRIPT_DIR/ralph-worker-v2.sh"
if [ ! -f "$WORKER_SCRIPT" ]; then
    log "ERROR" "Worker script not found: $WORKER_SCRIPT"
    exit 1
fi

# Create necessary directories
mkdir -p "$PROJECT_ROOT/.agent/parallel/worktrees"
mkdir -p "$PROJECT_ROOT/.agent/parallel/logs"
mkdir -p "$PROJECT_ROOT/.agent/parallel/pids"
mkdir -p "$CHANGE_DIR/current_tasks"

if [ "$DRY_RUN" = true ]; then
    log "INFO" "[DRY RUN] Would start $MAX_AGENTS agents"
    for i in $(seq 1 $MAX_AGENTS); do
        log "INFO" "[DRY RUN] Would start agent-$i"
    done
    exit 0
fi

# Check if agents are already running
running_count=0
for i in $(seq 1 $MAX_AGENTS); do
    pid_file="$PROJECT_ROOT/.agent/parallel/pids/agent-$i.pid"
    if [ -f "$pid_file" ]; then
        pid=$(cat "$pid_file")
        if ps -p "$pid" > /dev/null 2>&1; then
            ((running_count++))
        fi
    fi
done

if [ $running_count -gt 0 ]; then
    log "WARNING" "$running_count agents already running"
    log "INFO" "Use --stop to stop them first, or check status with --status"
    exit 1
fi

# Start agents
log "INFO" "Starting $MAX_AGENTS agents..."

for i in $(seq 1 $MAX_AGENTS); do
    log "INFO" "Starting agent-$i..."
    
    # Start worker in background
    "$WORKER_SCRIPT" "agent-$i" "$CHANGE_NAME" &
    
    # Small delay between agents to avoid race conditions
    sleep 1
done

log "SUCCESS" "All $MAX_AGENTS agents started!"
echo ""
log "INFO" "Monitor logs with:"
log "INFO" "  tail -f $PROJECT_ROOT/.agent/parallel/logs/agent-*.log"
echo ""
log "INFO" "Check status with:"
log "INFO" "  $0 --status"
echo ""
log "INFO" "Stop all agents with:"
log "INFO" "  $0 --stop"
