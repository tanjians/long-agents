# iFlow CLI 长时间运行开发环境

基于 [Anthropic 的最佳实践](https://www.anthropic.com/engineering/effective-harnesses-for-long-running-agents)，为 iFlow CLI 打造的长时间运行开发环境框架。

**✨ 新增：集成 [OpenSpec](https://github.com/Fission-AI/OpenSpec) 实现零手动编辑功能拆解！**

## 🎯 核心问题

AI Agent 在多个上下文窗口中工作时面临两个主要问题：
1. **试图一次性完成太多** - 导致上下文耗尽，留下半成品
2. **过早宣布完成** - 后续会话误以为项目已完成
3. **手动编辑功能列表困难** - 用户不知道如何拆解需求

## 💡 解决方案

采用双 Agent 架构 + OpenSpec 自动化：
- **Initializer Agent** - 首次会话，搭建环境和功能列表
- **Coding Agent** - 后续会话，增量开发，一次一个功能
- **OpenSpec** - 自动拆解需求，生成结构化功能列表

## 🚀 快速开始

### 方式一：OpenSpec 自动拆解（推荐）

```bash
# 1. 初始化项目
./init.sh

# 2. 用自然语言描述需求
/opsx:propose "构建用户认证系统，包含注册、登录、密码重置功能"

# 3. AI 自动生成：
#    openspec/changes/add-user-auth/
#    ├── proposal.md   # 为什么做
#    ├── specs/        # 详细规范
#    └── tasks.md      # 实现步骤

# 4. 一键转换为 features.json
./.agent/openspec-features.sh

# 5. 开始开发
./.agent/session-start.sh
```

**优势**：
- ✅ 零手动 JSON 编辑
- ✅ 自然语言输入
- ✅ 自动拆解验证步骤
- ✅ 完整的需求追踪

### 方式二：手动编辑

```bash
# 运行初始化脚本
./init.sh

# 手动编辑功能列表
vim .agent/features.json
```

### 开发工作流

每次开发会话遵循以下流程：

```bash
# 1. 启动会话 - 获取当前状态
./.agent/session-start.sh

# 2. 查看待办功能，选择一个工作
cat .agent/features.json

# 3. 开发...（一次只做一个功能）

# 4. 测试验证
npm test  # 或你的测试命令

# 5. 提交代码
git add .
git commit -m "[agent] feat: 具体功能描述"

# 6. 更新功能状态
# 编辑 .agent/features.json，将完成的功能标记为 "passes": true

# 7. 结束会话 - 保存进度
./.agent/session-end.sh
```

## 📁 项目结构

```
.agent/
├── features.json          # 功能列表（核心！）
├── progress.md            # 进度追踪
├── session-config.json    # 会话配置
├── session-start.sh       # 会话启动脚本
├── session-end.sh         # 会话结束脚本
├── openspec-features.py   # tasks.md → features.json 转换器
├── openspec-features.sh   # 转换脚本入口
└── prompts/
    ├── initializer-agent.md   # Initializer Agent 提示词
    └── coding-agent.md        # Coding Agent 提示词

openspec/
├── config.yaml            # OpenSpec 项目配置
├── schemas/iflow-features/ # 自定义 schema
│   ├── schema.yaml
│   └── templates/
├── changes/               # 变更提案目录
└── specs/                 # 长期规范
```

## 🔑 核心文件说明

### `.agent/features.json`

最重要的文件！定义所有功能及其状态：

```json
{
  "id": "unique-id",
  "category": "functional",
  "description": "清晰的、可测试的功能描述",
  "priority": "critical|high|medium|low",
  "steps": [
    "验证步骤 1",
    "验证步骤 2"
  ],
  "passes": false,  // 只有经过完整测试后才能改为 true
  "notes": "备注"
}
```

**重要规则**：
- ❌ 不要删除或修改现有功能
- ❌ 不要为了通过测试而修改功能定义
- ✅ 只有测试通过后才能将 `passes` 改为 `true`

### OpenSpec tasks.md 格式

```markdown
- [ ] **SETUP-1**: 创建数据库 schema
  - Priority: critical
  - Verification:
    - [ ] Schema 创建无错误
    - [ ] 所有表有正确的列
  - Depends on: None
```

这个格式会被自动解析并转换为 features.json。

## 📝 Agent 提示词使用

### Initializer Agent（首次会话）

使用 `.agent/prompts/initializer-agent.md` 作为提示词：

```
你是 Initializer Agent，负责：
1. 运行 ./init.sh 设置环境
2. 使用 /opsx:propose 创建需求提案
3. 运行转换脚本生成 features.json
4. 设置测试基础设施
5. 创建初始 git 提交
```

### Coding Agent（后续会话）

使用 `.agent/prompts/coding-agent.md` 作为提示词：

```
你是 Coding Agent，负责：
1. 运行会话启动脚本了解状态
2. 选择一个功能工作
3. 增量开发
4. 测试验证
5. 提交代码
6. 更新进度
7. 运行会话结束脚本
```

## ⚙️ OpenSpec 命令

| 命令 | 说明 |
|------|------|
| `/opsx:propose <需求>` | 创建新的功能提案 |
| `/opsx:apply` | 应用当前变更（开始编码） |
| `/opsx:archive` | 归档已完成的变更 |
| `./.agent/openspec-features.sh` | 转换 tasks.md → features.json |
| `./.agent/openspec-features.sh -m` | 合并模式（保留现有功能） |

## ✅ 最佳实践

### 增量开发
- 每个会话只处理 **一个功能**
- 完成后再开始下一个

### 测试驱动
- 功能必须经过测试才能标记为完成
- 每次会话开始验证当前状态
- 每次会话结束运行所有测试

### 清晰文档
- 进度文件记录所有工作
- Git commit 详细描述变更

### 干净状态
- 会话结束时代码库应可工作
- 所有测试通过
- 没有未提交变更

## 🛠 问题对照表

| 问题 | Initializer Agent | Coding Agent |
|------|------------------|--------------|
| 过早宣布完成 | 创建详细功能列表 | 读取列表，一次一个功能 |
| 留下半成品 | 初始化 git 和进度文件 | 开始读取进度，结束提交代码 |
| 功能未测试完成 | 设置功能列表 | 自我验证，测试后才标记通过 |
| 不知道如何运行 | 编写 init.sh | 开始时运行 init.sh |
| 手动编辑困难 | 使用 OpenSpec 自动拆解 | 无需手动编辑 |

## 🎓 学习资源

- [Anthropic: Effective harnesses for long-running agents](https://www.anthropic.com/engineering/effective-harnesses-for-long-running-agents)
- [OpenSpec: Spec-driven development for AI](https://github.com/Fission-AI/OpenSpec)
- [Claude 4 Prompting Guide](https://docs.anthropic.com/claude/docs/prompting)

## 📄 License

MIT
