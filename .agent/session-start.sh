#!/bin/bash

# Session Start Script for iFlow CLI Long-Running Agents
# Run this at the beginning of each agent session to get oriented

set -e

echo "🔄 Starting new agent session..."
echo ""

# Get current working directory
echo "📍 Current directory: $(pwd)"
echo ""

# Check if progress file exists
if [ -f ".agent/progress.md" ]; then
    echo "📝 Recent Progress:"
    echo "----------------------------------------"
    head -50 .agent/progress.md
    echo "----------------------------------------"
    echo ""
fi

# Check git status
echo "📊 Git Status:"
git status --short 2>/dev/null || echo "Not a git repository"
echo ""

# Show recent commits
echo "📜 Recent Commits:"
git log --oneline -10 2>/dev/null || echo "No commits yet"
echo ""

# Check for features to work on
if [ -f ".agent/features.json" ]; then
    echo "📋 Pending Features:"
    # Use python to parse JSON and show incomplete features
    python3 << 'PYTHON'
import json
try:
    with open('.agent/features.json', 'r') as f:
        data = json.load(f)
    
    pending = [f for f in data.get('features', []) if not f.get('passes', False)]
    pending.sort(key=lambda x: {'critical': 0, 'high': 1, 'medium': 2, 'low': 3}.get(x.get('priority', 'medium'), 2))
    
    if pending:
        for i, feature in enumerate(pending[:5], 1):
            print(f"{i}. [{feature.get('priority', 'medium').upper()}] {feature.get('description', 'No description')}")
            print(f"   ID: {feature.get('id', 'unknown')}")
            if len(pending) > 5:
                print(f"   ... and {len(pending) - 5} more features pending")
    else:
        print("✅ All features complete!")
except Exception as e:
    print(f"Error reading features: {e}")
PYTHON
    echo ""
fi

# Check if init.sh exists for running the app
if [ -f "init.sh" ]; then
    echo "✅ init.sh found - You can run './init.sh' to start the development environment"
fi

echo ""
echo "🎯 Recommended Actions:"
echo "   1. Read the full .agent/progress.md file"
echo "   2. Review pending features in .agent/features.json"
echo "   3. Pick ONE feature to work on"
echo "   4. Run tests to ensure current state is stable"
echo "   5. Implement the feature incrementally"
echo "   6. Test thoroughly before marking as complete"
echo "   7. Commit changes with descriptive message"
echo "   8. Update .agent/progress.md"
echo ""
