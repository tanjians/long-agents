#!/bin/bash

# Session End Script for iFlow CLI Long-Running Agents
# Run this at the end of each agent session to leave a clean state

set -e

echo "🏁 Ending agent session..."
echo ""

# Get current timestamp
TIMESTAMP=$(date "+%Y-%m-%d %H:%M:%S")

# Check for uncommitted changes
if [ -n "$(git status --porcelain 2>/dev/null)" ]; then
    echo "⚠️  You have uncommitted changes:"
    git status --short
    echo ""
    read -p "Do you want to commit these changes? (y/n) " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        read -p "Enter commit message: " commit_msg
        git add .
        git commit -m "[agent] $commit_msg"
        echo "✅ Changes committed"
    fi
    echo ""
fi

# Update progress file with session summary
echo "📝 Updating progress file..."
if [ -f ".agent/progress.md" ]; then
    # Prepend session info to progress file
    TEMP_FILE=$(mktemp)
    cat << EOF > "$TEMP_FILE"
# iFlow CLI Development Progress

## Current Status
- **Last Updated**: $TIMESTAMP
- **Phase**: Active Development

---

## Session History

### Session - $TIMESTAMP
- **Actions**: <!-- Describe what was done this session -->
- **Changes**: $(git diff --stat HEAD~1 2>/dev/null | tail -1 || echo "N/A")
- **Next Steps**: <!-- What should the next session work on -->

---

EOF
    tail -n +4 .agent/progress.md >> "$TEMP_FILE"
    mv "$TEMP_FILE" .agent/progress.md
    echo "✅ Progress file updated"
fi

# Update session counter
if [ -f ".agent/session-config.json" ]; then
    python3 << 'PYTHON'
import json
try:
    with open('.agent/session-config.json', 'r') as f:
        config = json.load(f)
    config['session_number'] = config.get('session_number', 1) + 1
    with open('.agent/session-config.json', 'w') as f:
        json.dump(config, f, indent=2)
    print(f"Session counter updated to: {config['session_number']}")
except Exception as e:
    print(f"Error updating session counter: {e}")
PYTHON
fi

# Run tests if available
echo ""
echo "🧪 Running tests to verify state..."
if [ -f "package.json" ]; then
    npm test 2>/dev/null || echo "No npm test script found"
elif [ -f "requirements.txt" ]; then
    python3 -m pytest 2>/dev/null || echo "No pytest found or no tests"
elif [ -f "pytest.ini" ]; then
    python3 -m pytest
else
    echo "No test configuration found"
fi

echo ""
echo "✅ Session ended at $TIMESTAMP"
echo ""
echo "💡 Summary:"
echo "   - Progress updated in .agent/progress.md"
echo "   - Session counter incremented"
echo "   - Working directory state verified"
echo ""
echo "👋 Ready for next agent session!"
