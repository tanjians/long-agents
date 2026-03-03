#!/bin/bash

# ============================================================================
# Ralph-Parallel: Multi-Agent Parallel Development Controller
# ============================================================================
#
# This script manages multiple ralph-worker.sh instances running in parallel
# using Git worktrees for isolation.
#
# Usage:
#   ./ralph-parallel.sh [options]
#
# Options:
#   --max-agents N    Maximum number of parallel agents (default: 5)
#   --dry-run         Show what would be done without executing
#   --status          Show current parallel status and exit
#   --stop            Stop all running agents
#   --help            Show this help message
#
# ============================================================================

set -e

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
PARALLEL_DIR="$PROJECT_ROOT/.agent/parallel"
FEATURES_FILE="$PROJECT_ROOT/.agent/features.json"
MAX_AGENTS=5
DRY_RUN=false
STOP_MODE=false

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m'

# Agent PIDs
AGENT_PIDS=()

# ============================================================================
# Utility Functions
# ============================================================================

log_info() { echo -e "${BLUE}[PARALLEL]${NC} $1"; }
log_success() { echo -e "${GREEN}[PARALLEL]${NC} $1"; }
log_warning() { echo -e "${YELLOW}[PARALLEL]${NC} $1"; }
log_error() { echo -e "${RED}[PARALLEL]${NC} $1"; }
log_ralph() { echo -e "${MAGENTA}[RALPH-PARALLEL]${NC} $1"; }

show_help() {
    cat << EOF
Ralph-Parallel: Multi-Agent Parallel Development Controller

Usage: $0 [options]

Options:
  --max-agents N    Maximum number of parallel agents (default: 5)
  --dry-run         Show what would be done without executing
  --status          Show current parallel status and exit
  --stop            Stop all running agents
  --help            Show this help message

Examples:
  $0                          # Start with 5 agents (default)
  $0 --max-agents 3           # Start with 3 agents
  $0 --status                 # Check current status
  $0 --stop                   # Stop all agents

EOF
    exit 0
}

# ============================================================================
# Status and Monitoring Functions
# ============================================================================

show_status() {
    log_ralph "═══════════════════════════════════════════════════════════"
    log_ralph "Ralph-Parallel Status Report"
    log_ralph "═══════════════════════════════════════════════════════════"
    echo ""
    
    # Check if features.json has parallel support
    if [ -f "$FEATURES_FILE" ]; then
        local stats=$(python3 << PYTHON
import json

try:
    with open('$FEATURES_FILE', 'r') as f:
        data = json.load(f)
    
    features = data.get('features', [])
    
    # Count by status
    pending = len([f for f in features if f.get('status', 'pending') == 'pending'])
    claimed = len([f for f in features if f.get('status') == 'claimed'])
    active = len([f for f in features if f.get('status') == 'active'])
    completed = len([f for f in features if f.get('status') == 'completed'])
    waiting = len([f for f in features if f.get('status') == 'waiting'])
    failed = len([f for f in features if f.get('status') == 'failed'])
    
    print(f"{pending}|{claimed}|{active}|{completed}|{waiting}|{failed}|{len(features)}")
    
except Exception as e:
    print("0|0|0|0|0|0|0")
PYTHON
)
        
        local pending=$(echo "$stats" | cut -d'|' -f1)
        local claimed=$(echo "$stats" | cut -d'|' -f2)
        local active=$(echo "$stats" | cut -d'|' -f3)
        local completed=$(echo "$stats" | cut -d'|' -f4)
        local waiting=$(echo "$stats" | cut -d'|' -f5)
        local failed=$(echo "$stats" | cut -d'|' -f6)
        local total=$(echo "$stats" | cut -d'|' -f7)
        
        local percentage=0
        if [ "$total" -gt 0 ]; then
            percentage=$((completed * 100 / total))
        fi
        
        echo -e "  ${BLUE}Task Statistics:${NC}"
        echo -e "    ⏳ Pending:   $pending"
        echo -e "    📋 Claimed:   $claimed"
        echo -e "    🔨 Active:    $active"
        echo -e "    ⏸️  Waiting:   $waiting"
        echo -e "    ✅ Completed: $completed"
        echo -e "    ❌ Failed:    $failed"
        echo -e "    ─────────────────────"
        echo -e "    📊 Total:     $total ($percentage%)"
    fi
    
    echo ""
    
    # Check running agents
    echo -e "  ${BLUE}Running Agents:${NC}"
    local running_count=0
    for i in $(seq 1 $MAX_AGENTS); do
        local agent_id="agent-$i"
        local pid_file="$PARALLEL_DIR/pids/$agent_id.pid"
        
        if [ -f "$pid_file" ]; then
            local pid=$(cat "$pid_file")
            if ps -p "$pid" > /dev/null 2>&1; then
                local worktree="$PARALLEL_DIR/worktrees/$agent_id"
                local status="🟢 Running"
                
                # Check if worktree exists and get current task
                if [ -d "$worktree/.agent" ]; then
                    local task_file="$worktree/.agent/ralph-current-task.md"
                    if [ -f "$task_file" ]; then
                        local task_line=$(grep "^# Ralph-Worker Task:" "$task_file" 2>/dev/null | head -1)
                        if [ -n "$task_line" ]; then
                            local task_id=$(echo "$task_line" | sed 's/.*Task: //')
                            status="🟢 $task_id"
                        fi
                    fi
                fi
                
                echo -e "    $agent_id: $status (PID: $pid)"
                running_count=$((running_count + 1))
            else
                echo -e "    $agent_id: 🔴 Stale PID file"
            fi
        else
            echo -e "    $agent_id: ⚪ Not running"
        fi
    done
    
    echo ""
    echo -e "  ${BLUE}Running Agents: $running_count/$MAX_AGENTS${NC}"
    echo ""
}

stop_all_agents() {
    log_warning "Stopping all agents..."
    
    local stopped=0
    for i in $(seq 1 $MAX_AGENTS); do
        local agent_id="agent-$i"
        local pid_file="$PARALLEL_DIR/pids/$agent_id.pid"
        
        if [ -f "$pid_file" ]; then
            local pid=$(cat "$pid_file")
            if ps -p "$pid" > /dev/null 2>&1; then
                log_info "Stopping $agent_id (PID: $pid)..."
                kill "$pid" 2>/dev/null || true
                stopped=$((stopped + 1))
            fi
            rm -f "$pid_file"
        fi
    done
    
    log_success "Stopped $stopped agents"
}

# ============================================================================
# Setup Functions
# ============================================================================

ensure_parallel_support() {
    log_info "Ensuring features.json has parallel support..."
    
    python3 << PYTHON
import json
import sys

try:
    with open('$FEATURES_FILE', 'r') as f:
        data = json.load(f)
    
    modified = False
    
    for feature in data.get('features', []):
        # Add parallel fields if missing
        if 'status' not in feature:
            feature['status'] = 'pending' if not feature.get('passes', False) else 'completed'
            modified = True
        if 'claimed_by' not in feature:
            feature['claimed_by'] = None
            modified = True
        if 'claimed_at' not in feature:
            feature['claimed_at'] = None
            modified = True
        if 'branch' not in feature:
            feature['branch'] = None
            modified = True
    
    if modified:
        with open('$FEATURES_FILE', 'w') as f:
            json.dump(data, f, indent=2, ensure_ascii=False)
        print("UPDATED")
    else:
        print("OK")
    
except Exception as e:
    print(f"Error: {e}", file=sys.stderr)
    sys.exit(1)
PYTHON
}

# ============================================================================
# Agent Management
# ============================================================================

start_agent() {
    local agent_id="$1"
    local worker_script="$SCRIPT_DIR/ralph-worker.sh"
    local log_file="$PARALLEL_DIR/logs/$agent_id.log"
    
    log_info "Starting $agent_id..."
    
    if [ "$DRY_RUN" = true ]; then
        log_warning "[DRY RUN] Would start $agent_id"
        return 0
    fi
    
    # Check if already running
    local pid_file="$PARALLEL_DIR/pids/$agent_id.pid"
    if [ -f "$pid_file" ]; then
        local pid=$(cat "$pid_file")
        if ps -p "$pid" > /dev/null 2>&1; then
            log_warning "$agent_id is already running (PID: $pid)"
            return 0
        fi
    fi
    
    # Start worker in background
    nohup "$worker_script" "$agent_id" > "$log_file" 2>&1 &
    local agent_pid=$!
    
    # Save PID
    echo $agent_pid > "$pid_file"
    AGENT_PIDS+=($agent_pid)
    
    log_success "$agent_id started (PID: $agent_pid)"
    
    # Small delay between agents
    sleep 1
}

start_all_agents() {
    log_ralph "═══════════════════════════════════════════════════════════"
    log_ralph "Starting Ralph-Parallel with $MAX_AGENTS agents"
    log_ralph "═══════════════════════════════════════════════════════════"
    echo ""
    
    # Setup
    ensure_parallel_support
    
    # Start agents
    for i in $(seq 1 $MAX_AGENTS); do
        start_agent "agent-$i"
    done
    
    echo ""
    log_success "All $MAX_AGENTS agents started!"
    echo ""
    log_info "Monitor logs with:"
    log_info "  tail -f $PARALLEL_DIR/logs/agent-*.log"
    echo ""
    log_info "Check status with:"
    log_info "  $0 --status"
    echo ""
}

# ============================================================================
# Main Loop
# ============================================================================

monitor_agents() {
    log_info "Monitoring agents... Press Ctrl+C to stop"
    
    while true; do
        sleep 10
        
        # Check if all agents are still running
        local running=0
        for pid in "${AGENT_PIDS[@]}"; do
            if ps -p "$pid" > /dev/null 2>&1; then
                running=$((running + 1))
            fi
        done
        
        # Show brief status
        log_info "Agents running: $running/${#AGENT_PIDS[@]}"
        
        # Check if all tasks are done
        local pending=$(python3 << PYTHON
import json
with open('$FEATURES_FILE', 'r') as f:
    data = json.load(f)
pending = [f for f in data.get('features', []) if f.get('status') not in ['completed', 'failed']]
print(len(pending))
PYTHON
)
        
        if [ "$pending" -eq 0 ] && [ "$running" -eq 0 ]; then
            log_success "All tasks completed and all agents stopped!"
            break
        fi
    done
}

# ============================================================================
# Signal Handling
# ============================================================================

cleanup() {
    echo ""
    log_warning "Received shutdown signal"
    stop_all_agents
    exit 0
}

trap cleanup SIGTERM SIGINT

# ============================================================================
# Argument Parsing
# ============================================================================

while [[ $# -gt 0 ]]; do
    case $1 in
        --max-agents)
            MAX_AGENTS="$2"
            shift 2
            ;;
        --dry-run)
            DRY_RUN=true
            shift
            ;;
        --status)
            show_status
            exit 0
            ;;
        --stop)
            STOP_MODE=true
            shift
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

# Create directories
mkdir -p "$PARALLEL_DIR"/{worktrees,logs,pids}

# Handle stop mode
if [ "$STOP_MODE" = true ]; then
    stop_all_agents
    exit 0
fi

# Start agents
start_all_agents

# If not dry run, monitor
if [ "$DRY_RUN" = false ]; then
    monitor_agents
fi
