# iFlow CLI 长时间运行开发环境 - 使用说明

## 快速开始

### 1. 初始化项目

```bash
# 在新项目中初始化 iFlow CLI 环境
/path/to/long-agents/.agent/quick-init.sh .

# 或手动初始化
./init.sh
```

### 2. 使用 OpenSpec 定义需求

```bash
# 步骤 1: 创建提案
/opsx:propose "构建一个用户认证系统"

# 步骤 2: 生成详细规范
/opsx:spec

# 步骤 3: 生成技术设计
/opsx:design

# 步骤 4: 生成任务清单
/opsx:tasks

# 步骤 5: 转换为 features.json（自动执行）
/opsx:features
```

生成的目录结构：
```
openspec/changes/add-user-auth/
├── proposal.md          # 需求提案
├── specs/               # 详细规范
├── design.md            # 技术设计
├── tasks.md             # 任务清单
└── features.json        # 功能列表（自动转换）
```

### 3. 并行开发

#### 方式一：串行开发（Ralph-Loop）

```bash
# 单 Agent 循环开发
./.agent/ralph-loop-ai.sh
```

#### 方式二：并行开发（Ralph-Parallel）⭐推荐

```bash
# 启动 5 个 Agent 并行开发
./.agent/ralph-parallel.sh

# 或指定 Agent 数量
./.agent/ralph-parallel.sh --max-agents 3

# 查看状态
./.agent/ralph-parallel.sh --status

# 停止所有 Agent
./.agent/ralph-parallel.sh --stop
```

## 核心概念

### features.json 结构

```json
{
  "id": "SETUP-1",
  "description": "创建项目目录结构",
  "priority": "critical",
  "status": "pending",        // pending/claimed/active/completed
  "claimed_by": null,         // Agent ID
  "claimed_at": null,         // 认领时间
  "branch": null,             // Git 分支
  "depends_on": "...",        // 依赖任务
  "waiting_for": ["..."]      // 等待中的依赖
}
```

### 任务生命周期

```
pending → claimed → active → completed
   ↑         ↓        ↓
   └──── waiting ─────┘
```

- **pending**: 等待认领
- **claimed**: 已被 Agent 认领
- **active**: 正在开发
- **waiting**: 等待依赖完成
- **completed**: 已完成

## 常用命令

### OpenSpec 命令

| 命令 | 说明 |
|------|------|
| `/opsx:propose "描述"` | 创建需求提案 |
| `/opsx:spec` | 生成详细规范 |
| `/opsx:design` | 生成技术设计 |
| `/opsx:tasks` | 生成任务清单 |
| `/opsx:features` | 转换为 features.json |
| `/opsx:apply` | 开始开发 |
| `/opsx:archive` | 归档变更 |

### Ralph-Parallel 命令

| 命令 | 说明 |
|------|------|
| `ralph-parallel.sh` | 启动并行开发（默认5个Agent） |
| `ralph-parallel.sh --status` | 查看当前状态 |
| `ralph-parallel.sh --stop` | 停止所有 Agent |
| `ralph-parallel.sh --max-agents N` | 指定Agent数量 |

### 转换脚本

```bash
# 手动转换 tasks.md 为 features.json
./.agent/openspec-features.sh -i openspec/changes/<change-name>/tasks.md

# 查看帮助
./.agent/openspec-features.sh --help
```

## 工作流程示例

### 场景 1：新功能开发

```bash
# 1. 创建需求
/opsx:propose "添加用户登录功能"

# 2. 生成所有文档
/opsx:spec && /opsx:design && /opsx:tasks

# 3. 转换功能列表（自动）
/opsx:features

# 4. 启动并行开发
./.agent/ralph-parallel.sh

# 5. 等待完成...
```

### 场景 2：快速启动开发

```bash
# 如果已有 tasks.md，直接转换
./.agent/openspec-features.sh -i openspec/changes/my-feature/tasks.md

# 启动开发
./.agent/ralph-parallel.sh
```

### 场景 3：查看进度

```bash
# 查看并行开发状态
./.agent/ralph-parallel.sh --status

# 输出示例：
# ╔══════════════════════════════════════════════════════════╗
# ║              Ralph-Parallel Status Report                ║
# ╚══════════════════════════════════════════════════════════╝
#
#   📊 Progress: 15/30 (50%)
#   ⏳ Pending: 15 features
#
#   📋 Running Agents:
#     agent-1: 🟢 SETUP-1 (PID: 12345)
#     agent-2: 🟢 CORE-1 (PID: 12346)
#     agent-3: ⚪ Not running
```

## 目录结构

```
project/
├── .agent/
│   ├── session-start.sh          # 会话启动
│   ├── session-end.sh            # 会话结束
│   ├── ralph-loop.sh             # 串行开发
│   ├── ralph-loop-ai.sh          # AI集成串行
│   ├── ralph-parallel.sh         # 并行开发 ⭐
│   ├── ralph-worker.sh           # Worker脚本
│   ├── openspec-features.sh      # 转换脚本
│   ├── openspec-features.py      # 转换核心
│   ├── parallel/                 # 并行运行时
│   │   ├── worktrees/            # Git worktrees
│   │   ├── logs/                 # Agent日志
│   │   └── pids/                 # 进程PID
│   └── prompts/
│       ├── initializer-agent.md
│       └── coding-agent.md
├── openspec/
│   ├── config.yaml               # OpenSpec配置
│   ├── changes/                  # 变更目录
│   │   ├── change-1/
│   │   │   ├── proposal.md
│   │   │   ├── tasks.md
│   │   │   └── features.json     # 功能列表
│   │   └── change-2/
│   │       └── ...
│   └── schemas/
│       └── iflow-features/       # 自定义schema
├── src/                          # 源代码
└── tests/                        # 测试
```

## 最佳实践

### 1. 任务粒度

- 每个任务应在 **1-2 个开发会话**内完成
- 任务描述应 **可测试、可验证**
- 复杂任务应拆分为多个子任务

### 2. 依赖管理

```markdown
- [ ] **CORE-1**: 实现核心功能
  - Priority: critical
  - Depends on: SETUP-1    ← 明确依赖
```

### 3. 并行开发原则

- ✅ 无依赖的任务可以并行
- ✅ 独立文件可以并行修改
- ❌ 同一文件避免并行修改
- ❌ 依赖任务未完成前不能开始

### 4. 状态检查

```bash
# 定期查看状态
watch -n 5 './.agent/ralph-parallel.sh --status'

# 查看 Agent 日志
tail -f .agent/parallel/logs/agent-*.log
```

## 故障排除

### Agent 崩溃

```bash
# 清理孤儿进程
./.agent/ralph-parallel.sh --stop

# 重新启动
./.agent/ralph-parallel.sh
```

### Git 冲突

```bash
# 手动解决冲突后
git add .
git commit -m "[agent] fix: resolve merge conflict"
git push
```

### 功能未生成

```bash
# 检查 tasks.md 格式
# 确保任务 ID 是大写字母+数字，如：SETUP-1, CORE-2

# 手动重新转换
./.agent/openspec-features.sh -i openspec/changes/<name>/tasks.md
```

## 高级用法

### 自定义 Agent 数量

```bash
# 根据 CPU 核心数调整
CPU_CORES=$(sysctl -n hw.ncpu)
./.agent/ralph-parallel.sh --max-agents $CPU_CORES
```

### 选择性开发

```bash
# 只开发特定 change
./.agent/ralph-parallel.sh --change tank-battle-game
```

### 干跑模式

```bash
# 预览但不执行
./.agent/ralph-parallel.sh --dry-run
```

## 参考

- [Anthropic 长运行 Agent 最佳实践](https://www.anthropic.com/engineering/effective-harnesses-for-long-running-agents)
- [OpenSpec 文档](https://github.com/Fission-AI/OpenSpec)
- [Anthropic C 编译器项目](https://www.anthropic.com/engineering/building-c-compiler)

---

**提示**: 使用 `ralph-parallel.sh` 进行并行开发可以显著加速项目完成！
