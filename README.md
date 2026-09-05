# 错误知识库 (error-knowledge-base)

> 管理个人/项目的错误解决经验：检索相似错误的历史解决方案，记录新解决的问题。

## 功能

- **遇到问题时**：自动检索知识库，返回相似错误的解决步骤
- **解决问题后**：自动识别"错误已解决"信号，建议记录到知识库
- **语义匹配**：理解不同表述但本质相同的错误
- **结构化记录**：错误信息按固定格式存储为 markdown 文件

## 安装（Claude Code）

克隆本仓库，然后将 `error-knowledge-base/` 目录复制到以下位置之一：

| 安装方式 | 复制到 | 适用范围 |
|---------|--------|---------|
| **全局** | `~/.claude/skills/` | 所有项目可用 |
| **项目** | `当前项目/.claude/skills/` | 仅当前项目可用 |

> **注意**：首次使用时，skill 会主动询问您自定义知识库位置。
> 建议设置到其他盘符（如 D 盘）以减轻 C 盘压力，同时方便知识库随项目一并迁移。默认存储至 `~/.claude/knowledge-base/`。

## 使用（Claude Code）

### 查询历史错误

当你在对话中描述错误（如："npm install 时报 ERESOLVE 错误"），Skill 会自动检索知识库，返回相似解决记录。

### 记录新错误

当会话中出现错误解决信号（如："搞定了"、"问题已修复"），Skill 会提示："是否记录此错误到知识库？"

## 知识库格式

每次保存错误时，skill 会显示完整的存储路径（默认：`~/.claude/knowledge-base/`），每条错误一个 markdown 文件：

```
~/.claude/knowledge-base/
├── 2026-09-05-npm-eresolve.md
├── 2026-09-03-python-oom.md
└── ...
```

每次记录都会自动生成结构化 markdown：

```yaml
---
title: npm 依赖冲突
error_type: ERESOLVE
tags: [npm, 依赖冲突]
files: [package.json]
---
## 解决步骤
...
```

## 贡献

欢迎提交你的错误记录，让更多人少走弯路。

## 许可

遵循 [LICENSE](LICENSE)。
