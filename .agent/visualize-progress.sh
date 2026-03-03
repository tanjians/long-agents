#!/bin/bash

# Progress Visualization Script for iFlow CLI Long-Running Agents
# Generates progress reports, statistics, and timeline views

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
NC='\033[0m' # No Color

# Default options
OUTPUT_FORMAT="terminal"
OUTPUT_FILE=""
SHOW_TIMELINE=false
SHOW_STATISTICS=true
SHOW_REPORT=true

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -f|--format)
            OUTPUT_FORMAT="$2"
            shift 2
            ;;
        -o|--output)
            OUTPUT_FILE="$2"
            shift 2
            ;;
        -t|--timeline)
            SHOW_TIMELINE=true
            shift
            ;;
        -s|--stats)
            SHOW_STATISTICS=true
            shift
            ;;
        -r|--report)
            SHOW_REPORT=true
            shift
            ;;
        --all)
            SHOW_TIMELINE=true
            SHOW_STATISTICS=true
            SHOW_REPORT=true
            shift
            ;;
        -h|--help)
            echo "Usage: $0 [OPTIONS]"
            echo ""
            echo "Options:"
            echo "  -f, --format FORMAT  Output format: terminal, json, markdown (default: terminal)"
            echo "  -o, --output FILE    Write output to file instead of stdout"
            echo "  -t, --timeline       Show timeline view"
            echo "  -s, --stats          Show statistics (default)"
            echo "  -r, --report         Show progress report (default)"
            echo "  --all                Show all views"
            echo "  -h, --help           Show this help message"
            echo ""
            echo "Examples:"
            echo "  $0                          # Show default report"
            echo "  $0 --all                    # Show all views"
            echo "  $0 -f markdown -o report.md # Export to markdown file"
            echo "  $0 -f json                  # Output as JSON"
            exit 0
            ;;
        *)
            echo -e "${RED}Unknown option: $1${NC}"
            exit 1
            ;;
    esac
done

FEATURES_FILE=".agent/features.json"
PROGRESS_FILE=".agent/progress.md"

# Check if features.json exists
if [ ! -f "$FEATURES_FILE" ]; then
    echo -e "${RED}Error: $FEATURES_FILE not found${NC}"
    echo "Please run ./init.sh first to initialize the project."
    exit 1
fi

# Main visualization logic using Python
generate_output() {
    python3 << 'PYTHON'
import json
import os
import re
from datetime import datetime

# Load features
with open('.agent/features.json', 'r') as f:
    data = json.load(f)

features = data.get('features', [])
metadata = data.get('metadata', {})

# Load progress file for timeline
progress_content = ""
if os.path.exists('.agent/progress.md'):
    with open('.agent/progress.md', 'r') as f:
        progress_content = f.read()

# Parse format from environment (set by bash wrapper)
output_format = os.environ.get('OUTPUT_FORMAT', 'terminal')
show_timeline = os.environ.get('SHOW_TIMELINE', 'false').lower() == 'true'
show_statistics = os.environ.get('SHOW_STATISTICS', 'true').lower() == 'true'
show_report = os.environ.get('SHOW_REPORT', 'true').lower() == 'true'

# Calculate statistics
total_features = len(features)
completed_features = sum(1 for f in features if f.get('passes', False))
pending_features = total_features - completed_features
completion_percentage = round(completed_features / total_features * 100, 1) if total_features else 0

# Priority breakdown
priority_stats = {'critical': {'total': 0, 'done': 0}, 'high': {'total': 0, 'done': 0}, 
                  'medium': {'total': 0, 'done': 0}, 'low': {'total': 0, 'done': 0}}
for f in features:
    p = f.get('priority', 'medium').lower()
    if p in priority_stats:
        priority_stats[p]['total'] += 1
        if f.get('passes', False):
            priority_stats[p]['done'] += 1

# Category breakdown
category_stats = {}
for f in features:
    c = f.get('category', 'other')
    if c not in category_stats:
        category_stats[c] = {'total': 0, 'done': 0}
    category_stats[c]['total'] += 1
    if f.get('passes', False):
        category_stats[c]['done'] += 1

# Parse timeline from progress file
def parse_timeline(content):
    sessions = []
    # Match session entries
    pattern = r'### Session - (\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2})'
    matches = re.findall(pattern, content)
    for match in matches:
        try:
            dt = datetime.strptime(match, '%Y-%m-%d %H:%M:%S')
            sessions.append(dt)
        except:
            pass
    return sorted(sessions)

timeline_sessions = parse_timeline(progress_content)

# Output formatting
if output_format == 'json':
    output = {
        'metadata': metadata,
        'statistics': {
            'total_features': total_features,
            'completed_features': completed_features,
            'pending_features': pending_features,
            'completion_percentage': completion_percentage,
            'priority_breakdown': priority_stats,
            'category_breakdown': category_stats
        },
        'features': features,
        'timeline': {
            'total_sessions': len(timeline_sessions),
            'sessions': [s.isoformat() for s in timeline_sessions]
        }
    }
    print(json.dumps(output, indent=2, ensure_ascii=False))

elif output_format == 'markdown':
    print("# iFlow CLI Progress Report")
    print("")
    print(f"**Generated:** {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}")
    print("")
    
    # Statistics section
    if show_statistics:
        print("## Statistics")
        print("")
        print(f"- **Total Features:** {total_features}")
        print(f"- **Completed:** {completed_features}")
        print(f"- **Pending:** {pending_features}")
        print(f"- **Completion:** {completion_percentage}%")
        print("")
        
        # Progress bar
        bar_length = 40
        filled = int(bar_length * completion_percentage / 100)
        bar = '█' * filled + '░' * (bar_length - filled)
        print(f"```\n[{bar}] {completion_percentage}%\n```")
        print("")
        
        # Priority breakdown
        print("### Priority Breakdown")
        print("")
        print("| Priority | Total | Done | Progress |")
        print("|----------|-------|------|----------|")
        for p in ['critical', 'high', 'medium', 'low']:
            stats = priority_stats[p]
            pct = round(stats['done'] / stats['total'] * 100) if stats['total'] else 0
            print(f"| {p.capitalize()} | {stats['total']} | {stats['done']} | {pct}% |")
        print("")
        
        # Category breakdown
        print("### Category Breakdown")
        print("")
        print("| Category | Total | Done | Progress |")
        print("|----------|-------|------|----------|")
        for c, stats in sorted(category_stats.items()):
            pct = round(stats['done'] / stats['total'] * 100) if stats['total'] else 0
            print(f"| {c.capitalize()} | {stats['total']} | {stats['done']} | {pct}% |")
        print("")
    
    # Features list
    if show_report:
        print("## Features")
        print("")
        for f in features:
            status = "✅" if f.get('passes', False) else "⬜"
            priority = f.get('priority', 'medium').upper()
            print(f"### {status} {f.get('id', 'unknown')}: {f.get('description', 'No description')}")
            print(f"- **Priority:** {priority}")
            print(f"- **Category:** {f.get('category', 'other')}")
            if f.get('notes'):
                print(f"- **Notes:** {f.get('notes')}")
            print("")
    
    # Timeline
    if show_timeline and timeline_sessions:
        print("## Timeline")
        print("")
        print(f"Total sessions: {len(timeline_sessions)}")
        print("")
        for i, session in enumerate(timeline_sessions[-10:], 1):
            print(f"{i}. {session.strftime('%Y-%m-%d %H:%M:%S')}")
        print("")

else:  # terminal format
    # ANSI color codes
    RED = '\033[0;31m'
    GREEN = '\033[0;32m'
    YELLOW = '\033[1;33m'
    BLUE = '\033[0;34m'
    MAGENTA = '\033[0;35m'
    CYAN = '\033[0;36m'
    WHITE = '\033[1;37m'
    NC = '\033[0m'
    
    # Header
    print(f"{BLUE}╔════════════════════════════════════════════════════════════╗{NC}")
    print(f"{BLUE}║          iFlow CLI Progress Visualization                  ║{NC}")
    print(f"{BLUE}╚════════════════════════════════════════════════════════════╝{NC}")
    print("")
    
    # Statistics section
    if show_statistics:
        print(f"{CYAN}📊 Completion Statistics{NC}")
        print(f"{BLUE}───────────────────────────────────────────────────────────{NC}")
        print(f"  {WHITE}Total Features:{NC}    {total_features}")
        print(f"  {GREEN}Completed:{NC}         {completed_features}")
        print(f"  {YELLOW}Pending:{NC}           {pending_features}")
        print(f"  {WHITE}Completion:{NC}        {completion_percentage}%")
        print("")
        
        # Visual progress bar
        bar_length = 40
        filled = int(bar_length * completion_percentage / 100)
        bar = f"{GREEN}{'█' * filled}{NC}{'░' * (bar_length - filled)}"
        print(f"  [{bar}] {completion_percentage}%")
        print("")
        
        # Priority breakdown
        print(f"{CYAN}📋 Priority Breakdown{NC}")
        print(f"{BLUE}───────────────────────────────────────────────────────────{NC}")
        for p in ['critical', 'high', 'medium', 'low']:
            stats = priority_stats[p]
            pct = round(stats['done'] / stats['total'] * 100) if stats['total'] else 0
            color = RED if p == 'critical' else YELLOW if p == 'high' else WHITE
            bar_len = int(20 * pct / 100) if pct else 0
            bar = f"{GREEN}{'█' * bar_len}{NC}{'░' * (20 - bar_len)}"
            print(f"  {color}{p.upper():8}{NC} [{bar}] {stats['done']}/{stats['total']} ({pct}%)")
        print("")
        
        # Category breakdown
        print(f"{CYAN}📁 Category Breakdown{NC}")
        print(f"{BLUE}───────────────────────────────────────────────────────────{NC}")
        for c, stats in sorted(category_stats.items()):
            pct = round(stats['done'] / stats['total'] * 100) if stats['total'] else 0
            bar_len = int(20 * pct / 100) if pct else 0
            bar = f"{GREEN}{'█' * bar_len}{NC}{'░' * (20 - bar_len)}"
            print(f"  {c.capitalize():12} [{bar}] {stats['done']}/{stats['total']} ({pct}%)")
        print("")
    
    # Features report
    if show_report:
        print(f"{CYAN}📝 Feature Status{NC}")
        print(f"{BLUE}───────────────────────────────────────────────────────────{NC}")
        
        # Sort features: incomplete first, then by priority
        priority_order = {'critical': 0, 'high': 1, 'medium': 2, 'low': 3}
        sorted_features = sorted(features, 
            key=lambda x: (x.get('passes', False), priority_order.get(x.get('priority', 'medium'), 2)))
        
        for f in sorted_features:
            status = f"{GREEN}✅{NC}" if f.get('passes', False) else f"{YELLOW}⬜{NC}"
            priority = f.get('priority', 'medium').upper()
            priority_color = RED if priority == 'CRITICAL' else YELLOW if priority == 'HIGH' else WHITE
            fid = f.get('id', 'unknown')
            desc = f.get('description', 'No description')[:45]
            if len(f.get('description', '')) > 45:
                desc += "..."
            print(f"  {status} {priority_color}[{priority:8}]{NC} {fid}: {desc}")
        print("")
    
    # Timeline view
    if show_timeline:
        print(f"{CYAN}📅 Timeline View{NC}")
        print(f"{BLUE}───────────────────────────────────────────────────────────{NC}")
        
        if timeline_sessions:
            print(f"  Total sessions: {len(timeline_sessions)}")
            print("")
            
            # Show last 10 sessions
            for i, session in enumerate(timeline_sessions[-10:], 1):
                date_str = session.strftime('%Y-%m-%d')
                time_str = session.strftime('%H:%M:%S')
                print(f"  {i:2}. {WHITE}{date_str}{NC} {time_str}")
        else:
            print("  No session history found")
        print("")
    
    # Summary
    print(f"{BLUE}════════════════════════════════════════════════════════════{NC}")
    if completion_percentage == 100:
        print(f"{GREEN}🎉 All features complete! Project is ready.{NC}")
    elif completion_percentage >= 75:
        print(f"{GREEN}🚀 Great progress! Almost there.{NC}")
    elif completion_percentage >= 50:
        print(f"{YELLOW}💪 Good progress! Keep going.{NC}")
    else:
        print(f"{WHITE}🔨 Work in progress. Stay focused!{NC}")
    print(f"{BLUE}════════════════════════════════════════════════════════════{NC}")

PYTHON
}

# Set environment variables for Python script
export OUTPUT_FORMAT
export SHOW_TIMELINE
export SHOW_STATISTICS
export SHOW_REPORT

# Generate output
if [ -n "$OUTPUT_FILE" ]; then
    generate_output > "$OUTPUT_FILE"
    echo -e "${GREEN}✅ Report saved to $OUTPUT_FILE${NC}"
else
    generate_output
fi
