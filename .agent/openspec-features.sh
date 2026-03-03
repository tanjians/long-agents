#!/bin/bash

# OpenSpec tasks.md to features.json Converter Wrapper
# This script provides a simple interface to the Python converter
#
# Features:
# - Preserves passes state in .agent/features-state.json
# - Only keeps unpassed features in features.json
# - Uses unique ID prefixes per change (e.g., TANK-SETUP-1, AUTH-SETUP-1)

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

# Default values
INPUT=""
OUTPUT="$PROJECT_ROOT/.agent/features.json"
STATE_FILE="$PROJECT_ROOT/.agent/features-state.json"
PROJECT_NAME="Long-Running Agent Environment"

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -i|--input)
            INPUT="$2"
            shift 2
            ;;
        -o|--output)
            OUTPUT="$2"
            shift 2
            ;;
        -s|--state-file)
            STATE_FILE="$2"
            shift 2
            ;;
        -p|--project-name)
            PROJECT_NAME="$2"
            shift 2
            ;;
        -h|--help)
            echo "OpenSpec to features.json Converter"
            echo ""
            echo "Usage: $0 [options]"
            echo ""
            echo "Options:"
            echo "  -i, --input FILE      Input tasks.md file or directory"
            echo "  -o, --output FILE     Output features.json file (default: .agent/features.json)"
            echo "  -s, --state-file      State file for passed features (default: .agent/features-state.json)"
            echo "  -p, --project-name    Project name for features.json"
            echo "  -h, --help            Show this help message"
            echo ""
            echo "Features:"
            echo "  - Preserves passes state in a separate file"
            echo "  - Only keeps unpassed features in features.json"
            echo "  - Uses unique ID prefixes per change"
            echo ""
            echo "Examples:"
            echo "  $0                              # Auto-detect tasks.md in openspec/changes/"
            echo "  $0 -i openspec/changes/add-auth/tasks.md"
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            exit 1
            ;;
    esac
done

# Build command
CMD="python3 \"$SCRIPT_DIR/openspec-features.py\" --output \"$OUTPUT\" --state-file \"$STATE_FILE\" --project-name \"$PROJECT_NAME\""

if [ -n "$INPUT" ]; then
    CMD="$CMD --input \"$INPUT\""
fi

# Run converter
eval $CMD

echo ""
echo "💡 Next steps:"
echo "   1. Review .agent/features.json for pending features"
echo "   2. Review .agent/features-state.json for passed features"
echo "   3. Run ./.agent/session-start.sh to see your features"
echo "   4. Start working on one feature at a time"