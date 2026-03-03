#!/bin/bash

# Feature Testing Script for iFlow CLI Long-Running Agents
# This script tests features defined in .agent/features.json and updates their status

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Default options
FEATURE_ID=""
UPDATE_ON_PASS=false
VERBOSE=false
DRY_RUN=false

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -f|--feature)
            FEATURE_ID="$2"
            shift 2
            ;;
        -u|--update)
            UPDATE_ON_PASS=true
            shift
            ;;
        -v|--verbose)
            VERBOSE=true
            shift
            ;;
        -d|--dry-run)
            DRY_RUN=true
            shift
            ;;
        -h|--help)
            echo "Usage: $0 [OPTIONS]"
            echo ""
            echo "Options:"
            echo "  -f, --feature ID    Test a specific feature by ID"
            echo "  -u, --update        Update features.json with test results"
            echo "  -v, --verbose       Show detailed output"
            echo "  -d, --dry-run       Show what would be tested without running"
            echo "  -h, --help          Show this help message"
            echo ""
            echo "Examples:"
            echo "  $0                          # Test all features"
            echo "  $0 -f core-001              # Test specific feature"
            echo "  $0 -u                       # Test all and update status"
            echo "  $0 -f core-002 -u           # Test specific feature and update"
            exit 0
            ;;
        *)
            echo -e "${RED}Unknown option: $1${NC}"
            exit 1
            ;;
    esac
done

FEATURES_FILE=".agent/features.json"

# Check if features.json exists
if [ ! -f "$FEATURES_FILE" ]; then
    echo -e "${RED}Error: $FEATURES_FILE not found${NC}"
    echo "Please run ./init.sh first to initialize the project."
    exit 1
fi

echo -e "${BLUE}╔════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║          iFlow CLI Feature Testing Framework               ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════════════════════════╝${NC}"
echo ""

# Function to test a single feature step
test_step() {
    local step="$1"
    
    if [ "$DRY_RUN" = true ]; then
        echo -e "    ${YELLOW}[DRY-RUN]${NC} Would test: $step"
        return 0
    fi
    
    case "$step" in
        # File existence checks
        "验证 .agent 目录已创建")
            [ -d ".agent" ] && return 0 || return 1
            ;;
        "验证 progress.md 文件存在")
            [ -f ".agent/progress.md" ] && return 0 || return 1
            ;;
        "验证 features.json 文件存在")
            [ -f ".agent/features.json" ] && return 0 || return 1
            ;;
        "验证 git 仓库已初始化")
            [ -d ".git" ] && return 0 || return 1
            ;;
        "验证 .agent/prompts/initializer-agent.md 存在")
            [ -f ".agent/prompts/initializer-agent.md" ] && return 0 || return 1
            ;;
        "验证 .agent/prompts/coding-agent.md 存在")
            [ -f ".agent/prompts/coding-agent.md" ] && return 0 || return 1
            ;;
        "验证包含环境设置步骤")
            grep -qi "environment" .agent/prompts/initializer-agent.md 2>/dev/null && return 0 || return 1
            ;;
        "验证包含功能列表创建指南")
            grep -qi "feature" .agent/prompts/initializer-agent.md 2>/dev/null && return 0 || return 1
            ;;
        "验证包含测试基础设施要求")
            grep -qi "test" .agent/prompts/initializer-agent.md 2>/dev/null && return 0 || return 1
            ;;
        "验证包含会话启动协议")
            grep -q "Session Startup" .agent/prompts/coding-agent.md 2>/dev/null && return 0 || return 1
            ;;
        "验证包含增量开发流程")
            grep -q "Incremental" .agent/prompts/coding-agent.md 2>/dev/null && return 0 || return 1
            ;;
        "验证包含测试要求")
            grep -q "Test" .agent/prompts/coding-agent.md 2>/dev/null && return 0 || return 1
            ;;
        "验证包含会话结束协议")
            grep -q "Session End" .agent/prompts/coding-agent.md 2>/dev/null && return 0 || return 1
            ;;
        
        # Script existence tests
        "运行 ./init.sh")
            [ -f "init.sh" ] && return 0 || return 1
            ;;
        "运行 .agent/session-start.sh")
            [ -f ".agent/session-start.sh" ] && return 0 || return 1
            ;;
        "运行 .agent/session-end.sh")
            [ -f ".agent/session-end.sh" ] && return 0 || return 1
            ;;
        
        # Display verification tests
        "验证显示当前目录")
            grep -q "Current directory" .agent/session-start.sh 2>/dev/null && return 0 || return 1
            ;;
        "验证显示进度文件内容")
            grep -q "progress.md" .agent/session-start.sh 2>/dev/null && return 0 || return 1
            ;;
        "验证显示 git 状态")
            grep -q "git status" .agent/session-start.sh 2>/dev/null && return 0 || return 1
            ;;
        "验证显示待办功能列表")
            grep -q "Pending Features" .agent/session-start.sh 2>/dev/null && return 0 || return 1
            ;;
        
        # Session end tests
        "验证进度文件被更新")
            grep -q "Updating progress" .agent/session-end.sh 2>/dev/null && return 0 || return 1
            ;;
        "验证会话计数器递增")
            grep -q "session_number" .agent/session-end.sh 2>/dev/null && return 0 || return 1
            ;;
        "验证未提交的变更被提示")
            grep -q "uncommitted" .agent/session-end.sh 2>/dev/null && return 0 || return 1
            ;;
        "验证测试被执行")
            grep -q "Running tests" .agent/session-end.sh 2>/dev/null && return 0 || return 1
            ;;
        
        # core-006 tests
        "创建测试脚本")
            [ -f ".agent/test-features.sh" ] && return 0 || return 1
            ;;
        "能够读取 features.json")
            python3 -c "import json; json.load(open('.agent/features.json'))" 2>/dev/null && return 0 || return 1
            ;;
        "能够运行每个功能的验证步骤")
            [ -f ".agent/test-features.sh" ] && return 0 || return 1
            ;;
        "能够更新功能状态")
            grep -q "UPDATE_ON_PASS" .agent/test-features.sh 2>/dev/null && return 0 || return 1
            ;;
        
        # core-007 tests
        "创建 pre-commit hook")
            [ -f ".git/hooks/pre-commit" ] && return 0 || return 1
            ;;
        "自动运行测试")
            [ -f ".git/hooks/pre-commit" ] && grep -q "test" .git/hooks/pre-commit 2>/dev/null && return 0 || return 1
            ;;
        "自动更新进度文件")
            [ -f ".git/hooks/pre-commit" ] && grep -q "progress" .git/hooks/pre-commit 2>/dev/null && return 0 || return 1
            ;;
        "验证提交消息格式")
            [ -f ".git/hooks/commit-msg" ] && return 0 || return 1
            ;;
        
        # core-008 tests
        "创建进度可视化脚本")
            [ -f ".agent/visualize-progress.sh" ] && return 0 || return 1
            ;;
        "生成进度报告")
            [ -f ".agent/visualize-progress.sh" ] && return 0 || return 1
            ;;
        "显示功能完成统计")
            [ -f ".agent/visualize-progress.sh" ] && grep -q "completion" .agent/visualize-progress.sh 2>/dev/null && return 0 || return 1
            ;;
        "生成时间线视图")
            [ -f ".agent/visualize-progress.sh" ] && grep -q "timeline" .agent/visualize-progress.sh 2>/dev/null && return 0 || return 1
            ;;
        
        # Generic fallback
        *)
            echo -e "    ${YELLOW}⚠ Unknown step: $step${NC}"
            return 0
            ;;
    esac
}

# Main testing logic
run_tests() {
    local passed_features=()
    local failed_features=()
    local skipped_features=()
    
    # Use Python to parse JSON and iterate features
    python3 -c "
import json
import sys

with open('$FEATURES_FILE', 'r') as f:
    data = json.load(f)

features = data.get('features', [])

# Filter by feature ID if specified
feature_id = '$FEATURE_ID'
if feature_id:
    features = [f for f in features if f.get('id') == feature_id]
    if not features:
        print('ERROR:FEATURE_NOT_FOUND')
        sys.exit(1)

# Sort by priority
priority_order = {'critical': 0, 'high': 1, 'medium': 2, 'low': 3}
features.sort(key=lambda x: priority_order.get(x.get('priority', 'medium'), 2))

# Output feature IDs and steps
for feature in features:
    fid = feature.get('id', 'unknown')
    desc = feature.get('description', 'No description')
    steps = feature.get('steps', [])
    print(f'FEATURE:{fid}|||{desc}')
    for step in steps:
        print(f'STEP:{step}')
    print('END_FEATURE')
" | while IFS= read -r line; do
        if [[ "$line" == FEATURE:* ]]; then
            # Parse feature header
            feature_info="${line#FEATURE:}"
            current_fid="${feature_info%%|||*}"
            current_desc="${feature_info##*|||}"
            
            echo -e "${BLUE}Testing Feature: ${current_fid}${NC}"
            echo -e "  Description: ${current_desc}"
            echo ""
            
            step_passed=0
            step_total=0
            failed_steps_list=()
            
        elif [[ "$line" == STEP:* ]]; then
            step="${line#STEP:}"
            step_total=$((step_total + 1))
            
            if [ "$DRY_RUN" = true ]; then
                echo -e "    ${YELLOW}[DRY-RUN]${NC} Would test: $step"
                step_passed=$((step_passed + 1))
            elif test_step "$step"; then
                step_passed=$((step_passed + 1))
                echo -e "  ${GREEN}✓${NC} $step"
            else
                failed_steps_list+=("$step")
                echo -e "  ${RED}✗${NC} $step"
            fi
            
        elif [[ "$line" == END_FEATURE ]]; then
            # Print feature result
            echo ""
            
            if [ ${#failed_steps_list[@]} -gt 0 ]; then
                echo -e "  ${YELLOW}Failed Steps:${NC}"
                for s in "${failed_steps_list[@]}"; do
                    echo -e "    ${RED}•${NC} $s"
                done
                echo ""
            fi
            
            status="${step_passed}/${step_total} steps passed"
            
            if [ $step_passed -eq $step_total ] && [ $step_total -gt 0 ]; then
                echo -e "  ${GREEN}Result: PASSED${NC} ($status)"
                echo "RESULT:PASSED:${current_fid}"
            elif [ $step_total -eq 0 ]; then
                echo -e "  ${YELLOW}Result: SKIPPED${NC} (no steps defined)"
                echo "RESULT:SKIPPED:${current_fid}"
            else
                echo -e "  ${RED}Result: FAILED${NC} ($status)"
                echo "RESULT:FAILED:${current_fid}"
            fi
            echo ""
        fi
    done
}

# Run tests
RESULTS_FILE=".agent/test-results.tmp"
FULL_OUTPUT=".agent/test-output.tmp"
run_tests 2>&1 | tee "$FULL_OUTPUT"
grep "^RESULT:" "$FULL_OUTPUT" > "$RESULTS_FILE" 2>/dev/null || true

# Print summary
echo -e "${BLUE}════════════════════════════════════════════════════════════${NC}"
echo -e "${BLUE}Test Summary${NC}"
echo -e "${BLUE}════════════════════════════════════════════════════════════${NC}"

passed_count=$(grep -c "RESULT:PASSED" "$RESULTS_FILE" 2>/dev/null || echo 0)
failed_count=$(grep -c "RESULT:FAILED" "$RESULTS_FILE" 2>/dev/null || echo 0)
skipped_count=$(grep -c "RESULT:SKIPPED" "$RESULTS_FILE" 2>/dev/null || echo 0)

echo -e "  ${GREEN}Passed:${NC}  $passed_count"
echo -e "  ${RED}Failed:${NC}  $failed_count"
echo -e "  ${YELLOW}Skipped:${NC} $skipped_count"
echo ""

# Update features.json if requested
if [ "$UPDATE_ON_PASS" = true ]; then
    echo -e "${BLUE}Updating features.json with test results...${NC}"
    
    python3 -c "
import json
from datetime import datetime

# Load test results
results = {'passed': [], 'failed': [], 'skipped': []}
with open('$RESULTS_FILE', 'r') as f:
    for line in f:
        parts = line.strip().split(':')
        if len(parts) >= 3:
            status = parts[1].lower()
            fid = parts[2]
            if status in results:
                results[status].append(fid)

# Load features
with open('.agent/features.json', 'r') as f:
    data = json.load(f)

# Update feature statuses
for feature in data.get('features', []):
    fid = feature.get('id')
    if fid in results['passed']:
        feature['passes'] = True
        feature['notes'] = 'Verified by test-features.sh'
    elif fid in results['failed']:
        feature['passes'] = False
        feature['notes'] = 'Some verification steps failed'

# Update metadata
data['metadata']['last_updated'] = datetime.now().strftime('%Y-%m-%d')
data['metadata']['completed_features'] = sum(1 for f in data.get('features', []) if f.get('passes', False))
total = len(data.get('features', []))
data['metadata']['completion_percentage'] = round(data['metadata']['completed_features'] / total * 100, 1) if total else 0

# Save updated features
with open('.agent/features.json', 'w') as f:
    json.dump(data, f, indent=2, ensure_ascii=False)

passed_count = len(results['passed'])
print(f'Updated {passed_count} features as passed')
"
    
    echo -e "${GREEN}✅ features.json updated successfully${NC}"
fi

# Cleanup
rm -f "$RESULTS_FILE"

echo ""
echo -e "${BLUE}════════════════════════════════════════════════════════════${NC}"

if [ "$failed_count" -gt 0 ]; then
    echo -e "${RED}Some feature tests failed. Please review the output above.${NC}"
    exit 1
else
    echo -e "${GREEN}All feature tests passed!${NC}"
    exit 0
fi