# Error Knowledge Base Skill (error-knowledge-base)

[English](README_EN.md) | 简体中文

> 管理个人/项目的错误解决经验：遇到问题自动检索历史方案，解决问题后主动询问是否记录。

💡 **用法提示**：解决错误后直接说「搞定了」，我会主动问你记不记；也可以随时输入 `/error-knowledge-base` 手动触发。

## 它解决什么问题

开发过程中遇到的错误往往重复发生：

- 今天解决了的 npm ERESOLVE 冲突，下周换个项目又遇到
- 同样的 Docker 端口占用、数据库连接池爆满、内存泄漏
- 每次都要重新搜索 Stack Overflow 或翻聊天记录
- Agent 每次遇到同样的错误都要重新探索解决方案

这个 Skill 把你的错误解决经验变成可检索的知识库：

- **遇到问题时**：自动检索历史方案，避免重复踩坑
- **解决问题后**：主动询问是否记录，形成闭环
- **Agent 自主发现**：Agent 遇到新错误自行解决后主动提示记录

## 核心原则

1. **按需触发**：你说什么，Skill 就做什么，不会自动后台运行
2. **零输入记录**：解决后只需说"搞定了"，Skill 自动提取信息并询问是否记录（你也可直接 `/error-knowledge-base` 手动触发）
3. **Agent 协作**：Agent 遇到新错误可自行探索解决并记录
4. **隐私保护**：默认不读取本机数据，除非用户明确要求

## 安装

```bash
# 克隆仓库并安装
git clone https://github.com/xzw268688/error-knowledge-base.git
cd error-knowledge-base

# macOS / Linux
bash install.sh

# Windows (PowerShell)
powershell -NoProfile -ExecutionPolicy Bypass -File install.ps1
```

已安装过？加 `--force`（sh）或 `-Force`（ps1）覆盖。

---

## 验证安装

```bash
# 检查 skill 是否安装成功
ls ~/.claude/skills/error-knowledge-base/
# 应看到: SKILL.md
```

### 快速验证（推荐）

仓库自带 8 条示例记录，复制到你的知识库路径即可立刻试出效果：

```bash
# macOS / Linux
cp examples/knowledge-base/*.md ~/.claude/knowledge-base/

# Windows (PowerShell)
Copy-Item examples\knowledge-base\*.md $env:USERPROFILE\.claude\knowledge-base\
```

然后直接问一个和示例**措辞完全不同**的问题，验证语义检索是否生效：

```
内存爆了怎么办
```

它应该能同时命中示例中的 Python `MemoryError` 和 JVM `OOMKilled` 两条记录——
即使你的输入里没有任何一个字符和它们的 `search_keywords` 字面重合。

用完想清空，删掉这些文件即可。

---

## 首次使用配置

**第一步：配置知识库路径**

首次调用 skill 时，会自动询问你知识库存储位置。你也可以手动提前配置：

```json
// ~/.claude/error-knowledge-base-config.json
{
  "knowledge_base_path": "~/.claude/knowledge-base/"
}
```

**路径优先级**：
1. 配置文件 `~/.claude/error-knowledge-base-config.json`（优先）
2. 环境变量 `ERROR_KB_PATH`
3. 默认 `~/.claude/knowledge-base/`

**迁移说明**：
- 直接把知识库文件夹复制到任意位置
- 更新配置文件中的 `knowledge_base_path`
- 重启 Claude Code 即可
- **无需重建索引** —— 每次检索动态扫描，零配置迁移

## 使用

### 场景一：搜索错误

直接描述问题：
```
npm install 报 ERESOLVE 怎么办
```

### 场景二：Agent 自主发现

Agent 执行任务时遇到未知错误并自行解决后：
```
Agent：我刚刚解决了一个新错误，是否记录？
       [确认记录] [跳过] [稍后再说]
```

### 场景三：解决后记录

解决后说：
```
搞定了，用 --legacy-peer-deps 解决的
```

### 查看记录

```
我记了哪些错误
```

### 查看统计

```
知识库情况
```

输出：总记录数、有效/已过时分布、近 30 天新增、按月份、按标签 Top 10、按错误类型 Top 10。

## 存储位置配置

知识库路径优先级：

1. 配置文件 `~/.claude/error-knowledge-base-config.json`（仅含 `knowledge_base_path` 一个字段）
2. 环境变量 `ERROR_KB_PATH`
3. 默认 `~/.claude/knowledge-base/`

**首次使用流程**：检测到没有配置文件且未设置环境变量时，询问用户自定义知识库路径。

**每次保存**：显示完整存储路径，方便用户查找。

## 文件格式

每条记录是一个 markdown 文件：

```yaml
---
title: 错误标题
date: YYYY-MM-DD
tags: [标签 1, 标签 2]
error_type: 错误类型/错误码
files: [相关文件路径]
search_keywords: [检索关键词, 含英文原形]
draft: false
status: verified   # verified | draft | deprecated
---

# 错误现象
...

# 解决步骤
...

# 根因分析（可选）
...
```

文件命名规则：`YYYY-MM-DD-error-slug.md`（日期 + 错误简短描述）

## 匹配策略

- **语义理解为主** + 结构化字段（tags、error_type）辅助排序
- 覆盖模糊匹配（如"OOM" vs "内存溢出"）
- **关键词只影响排序，从不阻断召回**：`search_keywords`、`tags`、`error_type` 命中与否，
  决定的是候选记录的**排序权重**，不是"能不能被检索到"。
  即使关键词全部得分为 0，记录依然会交给 LLM 语义精排——
  早期版本把关键词匹配当作召回门槛，导致语义检索形同虚设，现已修正
- `status: deprecated` 的记录不参与检索，但仍保留作为历史参考

## 迁移与可移植性

**零配置迁移**：
1. 复制整个 `{knowledge_base_path}` 文件夹到任意位置
2. 更新配置文件中的 `knowledge_base_path`
3. 重启 Claude Code

**无需重建索引** — 每次检索动态扫描知识库目录，无状态设计。

---

## 故障排查

### 问题 1: 首次使用没有弹出配置向导

**可能原因**：
1. skill 未正确安装 — 运行 `ls ~/.claude/skills/error-knowledge-base/` 检查
2. 已有配置文件 — 检查 `~/.claude/error-knowledge-base-config.json` 是否存在

### 问题 2: 搜索不到任何记录

**可能原因**：
1. 知识库路径配置错误 — 检查配置文件中的路径是否存在
2. 知识库为空 — 先复制 `examples/knowledge-base/*.md` 到知识库路径快速验证
3. 新录入的记录缺少 `search_keywords` 字段 — 不影响召回，但排序会靠后
4. 记录全部被标记为 `status: deprecated` — 会返回"知识库中没有有效记录"

### 问题 3: 迁移后无法使用

**解决方案**：
1. 确认新路径下有 `.md` 文件 — `ls {新路径}/`
2. 检查配置文件路径是否更新 — `cat ~/.claude/error-knowledge-base-config.json`
3. 重启 Claude Code 以刷新环境

### 问题 4: 检测到疑似重复记录

这是正常行为，系统会提醒你可能存在重复：
- **[确认新建]** — 确实是新场景
- **[取消]** — 和已有记录重复
- **[查看旧记录]** — 先看看是否可以直接用旧方案

## 目录结构

```
仓库/
├── error-knowledge-base/
│   └── SKILL.md                  # skill 主文件（技能包）
├── examples/
│   └── knowledge-base/           # 示例记录，用于快速验证
├── README.md                     # 中文说明
├── README_EN.md                  # 英文说明
└── CLAUDE.md                     # 需求文档（开发用）

用户本地/
├── ~/.claude/skills/error-knowledge-base/   # skill 安装位置
└── {knowledge_base_path}/                   # 知识库数据
    ├── 2026-09-05-npm-eresolve.md
    ├── 2026-09-03-python-oom.md
    └── ...
```

## 相关文件

- `error-knowledge-base/SKILL.md` - 技能实现细节
- `CLAUDE.md` - 需求文档
- `README_EN.md` - English documentation
