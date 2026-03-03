#!/bin/bash

# iFlow CLI Long-Running Agent Environment Initializer
# This script sets up the development environment for long-running agent sessions

set -e

echo "🚀 Initializing iFlow CLI Long-Running Agent Environment..."

# Check if we're in a git repository, if not initialize one
if [ ! -d ".git" ]; then
    echo "📦 Initializing git repository..."
    git init
    echo "✅ Git repository initialized"
fi

# Create necessary directories
echo "📁 Creating directory structure..."
mkdir -p .agent
mkdir -p .agent/sessions
mkdir -p .agent/backups
mkdir -p tests
mkdir -p src
mkdir -p openspec/changes
mkdir -p openspec/specs
mkdir -p openspec/schemas

# Create progress tracking file if it doesn't exist
if [ ! -f ".agent/progress.md" ]; then
    echo "📝 Creating progress tracking file..."
    cat > .agent/progress.md << 'EOF'
# iFlow CLI Development Progress

## Project Overview
<!-- Describe the overall project goal here -->

## Current Status
- **Phase**: Initialization
- **Last Updated**: <!-- Will be updated automatically -->
- **Active Feature**: None

## Session History

### Session 1 - Initialization
- **Date**: $(date +%Y-%m-%d)
- **Actions**: Environment setup complete
- **Next Steps**: Define feature requirements

## Active Work
<!-- Current work in progress -->

## Blockers
<!-- Any issues or blockers -->

## Notes
<!-- Additional notes -->
EOF
    echo "✅ Progress tracking file created"
fi

# Create feature list template if it doesn't exist
if [ ! -f ".agent/features.json" ]; then
    echo "📋 Creating feature list template..."
    cat > .agent/features.json << 'EOF'
{
  "project_name": "",
  "description": "",
  "features": [
    {
      "id": "setup-001",
      "category": "setup",
      "description": "Project initialization and environment setup",
      "priority": "critical",
      "steps": [
        "Verify all dependencies are installed",
        "Set up development environment",
        "Run initial tests"
      ],
      "passes": false,
      "notes": ""
    }
  ]
}
EOF
    echo "✅ Feature list template created"
fi

# Create session config
if [ ! -f ".agent/session-config.json" ]; then
    echo "⚙️  Creating session configuration..."
    cat > .agent/session-config.json << 'EOF'
{
  "session_number": 1,
  "max_context_windows": 10,
  "auto_commit": true,
  "test_before_feature": true,
  "incremental_mode": true,
  "testing": {
    "browser_automation": false,
    "unit_tests": true,
    "integration_tests": true,
    "e2e_tests": false
  },
  "git": {
    "auto_commit": true,
    "commit_prefix": "[agent]",
    "branch_strategy": "feature"
  }
}
EOF
    echo "✅ Session configuration created"
fi

# Create .agentignore file
if [ ! -f ".agentignore" ]; then
    echo "🔒 Creating .agentignore file..."
    cat > .agentignore << 'EOF'
# Agent-specific files to ignore
.agent/sessions/*
.agent/backups/*
*.log
.env
.env.local
node_modules/
__pycache__/
*.pyc
.DS_Store
EOF
    echo "✅ .agentignore created"
fi

# Initialize git with initial commit if this is a fresh repo
if [ -z "$(git status --porcelain 2>/dev/null)" ]; then
    echo "📸 Creating initial commit..."
    git add .
    git commit -m "[agent] Initial project setup for long-running agent environment" 2>/dev/null || true
    echo "✅ Initial commit created"
fi

# Check if OpenSpec is installed
OPENSPEC_INSTALLED=false
if command -v openspec &> /dev/null; then
    OPENSPEC_INSTALLED=true
    echo ""
    echo "🔍 OpenSpec detected. Setting up OpenSpec integration..."
    
    # Initialize OpenSpec if not already initialized
    if [ ! -f "openspec/config.yaml" ]; then
        echo "⚙️  Creating OpenSpec configuration..."
        # Create default config if template exists
        if [ -f "openspec/config.yaml.template" ]; then
            cp openspec/config.yaml.template openspec/config.yaml
        fi
        echo "✅ OpenSpec configuration created"
    fi
fi

echo ""
echo "✨ Initialization complete!"
echo ""
echo "📊 Next steps:"
echo ""
if [ "$OPENSPEC_INSTALLED" = true ]; then
    echo "   🚀 With OpenSpec (Recommended):"
    echo "   1. Describe your feature: /opsx:propose \"your feature description\""
    echo "   2. Review generated proposal, specs, and tasks"
    echo "   3. Convert to features.json: ./.agent/openspec-features.sh"
    echo "   4. Start your coding agent session"
    echo ""
    echo "   📝 Manual approach:"
fi
echo "   1. Edit .agent/features.json to define your project features"
echo "   2. Edit .agent/progress.md to describe your project goal"
echo "   3. Start your coding agent session"
echo ""
echo "💡 Tips:"
echo "   - Each agent session should work on ONE feature at a time"
echo "   - Always commit progress with descriptive messages"
echo "   - Update .agent/progress.md at the end of each session"
echo "   - Mark features as 'passes: true' only after thorough testing"
echo ""
if [ "$OPENSPEC_INSTALLED" = true ]; then
    echo "🔧 OpenSpec commands:"
    echo "   /opsx:propose <feature>  - Create a new feature proposal"
    echo "   /opsx:apply              - Apply the current change"
    echo "   /opsx:archive            - Archive completed change"
    echo ""
fi
