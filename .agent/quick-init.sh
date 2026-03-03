#!/bin/bash

# ============================================================================
# iFlow CLI 长期运行开发环境 - 快速初始化脚本
# ============================================================================
#
# 用法:
#   方式一：在新目录中运行
#   cd /path/to/new-project
#   /path/to/long-agents/.agent/quick-init.sh
#
#   方式二：指定目标目录
#   /path/to/long-agents/.agent/quick-init.sh /path/to/new-project
#
#   方式三：克隆模式（复制整个框架）
#   /path/to/long-agents/.agent/quick-init.sh /path/to/new-project --clone
#
# ============================================================================

set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# 获取脚本所在目录（框架源目录）
FRAMEWORK_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
AGENT_DIR="$FRAMEWORK_DIR/.agent"
OPENSPEC_DIR="$FRAMEWORK_DIR/openspec"

# 默认目标目录为当前目录
TARGET_DIR="${1:-.}"
CLONE_MODE=false

# 解析参数
while [[ $# -gt 0 ]]; do
    case $1 in
        --clone|-c)
            CLONE_MODE=true
            shift
            ;;
        --help|-h)
            cat << EOF
iFlow CLI 长期运行开发环境 - 快速初始化

用法:
  $0 [目标目录] [选项]

选项:
  --clone, -c    克隆模式：复制整个框架文件
  --help, -h     显示此帮助信息

示例:
  # 在当前目录初始化
  $0

  # 在指定目录初始化
  $0 /path/to/my-project

  # 克隆模式（包含示例文件）
  $0 /path/to/my-project --clone

框架目录: $FRAMEWORK_DIR
EOF
            exit 0
            ;;
        -*)
            echo -e "${RED}未知选项: $1${NC}"
            exit 1
            ;;
        *)
            TARGET_DIR="$1"
            shift
            ;;
    esac
done

# 转换为绝对路径
if [ -d "$TARGET_DIR" ]; then
    TARGET_DIR="$(cd "$TARGET_DIR" && pwd)"
else
    # 目录不存在，创建它
    mkdir -p "$TARGET_DIR"
    TARGET_DIR="$(cd "$TARGET_DIR" && pwd)"
fi

echo ""
echo -e "${CYAN}╔══════════════════════════════════════════════════════════╗${NC}"
echo -e "${CYAN}║     iFlow CLI 长期运行开发环境 - 快速初始化              ║${NC}"
echo -e "${CYAN}╚══════════════════════════════════════════════════════════╝${NC}"
echo ""
echo -e "  ${BLUE}框架源:${NC} $FRAMEWORK_DIR"
echo -e "  ${BLUE}目标目录:${NC} $TARGET_DIR"
echo ""

# ============================================================================
# 创建目录结构
# ============================================================================

echo -e "${YELLOW}📁 创建目录结构...${NC}"

mkdir -p "$TARGET_DIR/.agent/prompts"
mkdir -p "$TARGET_DIR/.agent/sessions"
mkdir -p "$TARGET_DIR/.agent/backups"
mkdir -p "$TARGET_DIR/openspec/changes"
mkdir -p "$TARGET_DIR/openspec/specs"
mkdir -p "$TARGET_DIR/openspec/schemas/iflow-features/templates"
mkdir -p "$TARGET_DIR/src"
mkdir -p "$TARGET_DIR/tests"

echo -e "  ${GREEN}✓${NC} .agent/"
echo -e "  ${GREEN}✓${NC} openspec/"
echo -e "  ${GREEN}✓${NC} src/"
echo -e "  ${GREEN}✓${NC} tests/"

# ============================================================================
# 复制核心文件
# ============================================================================

echo ""
echo -e "${YELLOW}📋 复制核心文件...${NC}"

# 必需文件列表
CORE_FILES=(
    ".agent/session-start.sh"
    ".agent/session-end.sh"
    ".agent/ralph-loop.sh"
    ".agent/ralph-loop-ai.sh"
    ".agent/ralph-loop-agent.py"
    ".agent/openspec-features.py"
    ".agent/openspec-features.sh"
    ".agent/prompts/initializer-agent.md"
    ".agent/prompts/coding-agent.md"
    "openspec/config.yaml"
    "openspec/schemas/iflow-features/schema.yaml"
    "openspec/schemas/iflow-features/templates/proposal.md"
    "openspec/schemas/iflow-features/templates/specs.md"
    "openspec/schemas/iflow-features/templates/tasks.md"
)

for file in "${CORE_FILES[@]}"; do
    src="$FRAMEWORK_DIR/$file"
    dst="$TARGET_DIR/$file"
    if [ -f "$src" ]; then
        cp "$src" "$dst"
        echo -e "  ${GREEN}✓${NC} $file"
    else
        echo -e "  ${YELLOW}⚠${NC} $file (源文件不存在)"
    fi
done

# ============================================================================
# 创建初始化脚本
# ============================================================================

echo ""
echo -e "${YELLOW}📝 创建初始化脚本...${NC}"

cat > "$TARGET_DIR/init.sh" << 'INITEOF'
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
  "incremental_mode": true
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

# Set executable permissions
chmod +x .agent/*.sh .agent/*.py 2>/dev/null || true

# Initialize git with initial commit if this is a fresh repo
if [ -z "$(git status --porcelain 2>/dev/null)" ]; then
    echo "📸 Creating initial commit..."
    git add .
    git commit -m "[agent] Initial project setup for long-running agent environment" 2>/dev/null || true
    echo "✅ Initial commit created"
fi

echo ""
echo "✨ Initialization complete!"
echo ""
echo "📊 Next steps:"
echo ""
echo "   🚀 With OpenSpec (Recommended):"
echo "   1. Describe your feature: /opsx:propose \"your feature description\""
echo "   2. Review generated proposal, specs, and tasks"
echo "   3. Convert to features.json: ./.agent/openspec-features.sh"
echo "   4. Start your coding agent session"
echo ""
echo "   📝 Manual approach:"
echo "   1. Edit .agent/features.json to define your project features"
echo "   2. Edit .agent/progress.md to describe your project goal"
echo "   3. Start your coding agent session"
echo ""
INITEOF

chmod +x "$TARGET_DIR/init.sh"
echo -e "  ${GREEN}✓${NC} init.sh"

# ============================================================================
# 创建快速启动脚本
# ============================================================================

cat > "$TARGET_DIR/.agent/quick-init.sh" << 'QUICKEOF'
#!/bin/bash
# 快速启动开发环境
echo "🔄 快速启动开发环境..."
echo ""
echo "1️⃣  初始化环境"
./init.sh

echo ""
echo "2️⃣  启动 Ralph-Loop"
echo "   运行: ./.agent/ralph-loop-ai.sh"
echo ""
echo "或者手动开发:"
echo "   1. ./.agent/session-start.sh  # 查看状态"
echo "   2. # 开发功能..."
echo "   3. ./.agent/session-end.sh    # 保存进度"
QUICKEOF

chmod +x "$TARGET_DIR/.agent/quick-init.sh"
echo -e "  ${GREEN}✓${NC} .agent/quick-init.sh"

# ============================================================================
# 克隆模式：复制额外文件
# ============================================================================

if [ "$CLONE_MODE" = true ]; then
    echo ""
    echo -e "${YELLOW}📦 克隆模式：复制示例文件...${NC}"
    
    # 复制 README
    if [ -f "$FRAMEWORK_DIR/README.md" ]; then
        cp "$FRAMEWORK_DIR/README.md" "$TARGET_DIR/"
        echo -e "  ${GREEN}✓${NC} README.md"
    fi
    
    # 复制示例 openspec 变更
    if [ -d "$FRAMEWORK_DIR/openspec/changes" ]; then
        for change_dir in "$FRAMEWORK_DIR/openspec/changes"/*; do
            if [ -d "$change_dir" ]; then
                change_name=$(basename "$change_dir")
                mkdir -p "$TARGET_DIR/openspec/changes/$change_name"
                cp -r "$change_dir"/* "$TARGET_DIR/openspec/changes/$change_name/" 2>/dev/null || true
                echo -e "  ${GREEN}✓${NC} openspec/changes/$change_name/"
            fi
        done
    fi
fi

# ============================================================================
# 设置权限
# ============================================================================

echo ""
echo -e "${YELLOW}🔒 设置文件权限...${NC}"
find "$TARGET_DIR/.agent" -name "*.sh" -exec chmod +x {} \; 2>/dev/null || true
find "$TARGET_DIR/.agent" -name "*.py" -exec chmod +x {} \; 2>/dev/null || true
echo -e "  ${GREEN}✓${NC} 所有脚本已设置为可执行"

# ============================================================================
# 完成
# ============================================================================

echo ""
echo -e "${GREEN}╔══════════════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║                 ✅ 初始化完成！                           ║${NC}"
echo -e "${GREEN}╚══════════════════════════════════════════════════════════╝${NC}"
echo ""
echo -e "  ${BLUE}目标目录:${NC} $TARGET_DIR"
echo ""
echo -e "  ${CYAN}快速开始:${NC}"
echo ""
echo "    cd $TARGET_DIR"
echo "    ./init.sh"
echo ""
echo -e "  ${CYAN}或者使用 OpenSpec:${NC}"
echo ""
echo "    cd $TARGET_DIR"
echo "    /opsx:propose \"your feature description\""
echo "    ./.agent/openspec-features.sh"
echo "    ./.agent/ralph-loop-ai.sh"
echo ""
echo -e "  ${CYAN}查看状态:${NC}"
echo ""
echo "    ./.agent/ralph-loop.sh --status"
echo ""
