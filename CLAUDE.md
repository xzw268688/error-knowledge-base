# 错误知识库 Skill 需求文档

## 0. Agent 常驻约定

> 以下约定优先级高于本文件其余内容。

**遇到并解决了任何错误时，主动询问用户「要记录到知识库吗？」，不要等用户手动调用 `/error-knowledge-base`。**

- 包括用户自己解决的（用户说"搞定了""解决了""跑通了"）
- 也包括你自己解决的（排查后自行修复的未知错误）
- 措辞上用「询问」，不要用「自动记录」——实际行为是询问后等用户确认，README 已按此措辞对齐
- 判断该不该记录时优先考虑知识库（可复现的、有排查价值的），环境/机器专属配置（如本机代理端口）归 memory

## 1. 概述

设计一个 Claude Code Skill，用于管理个人/项目的错误解决经验。

- **检索**：用户描述错误或贴出错误信息时，检索知识库返回相似解决方案
- **记录**：解决错误后，主动询问用户是否记录到知识库

## 2. 核心功能

### 2.1 错误检索
- **触发时机**：用户在对话中描述错误或贴出错误信息时触发
- **检索范围**：配置的知识库路径下所有 markdown 文件
- **匹配策略**：语义理解为主 + 结构化字段（tags、error_type、files）辅助过滤
- **返回结果**：
  - 命中：返回相似错误的解决步骤
  - 未命中：告知"知识库中无相似错误记录"

### 2.2 错误记录
- **触发时机**：在对话中识别"错误已解决"信号（如"解决了"、"搞定了"），主动询问用户"是否记录此错误？"
- **用户确认后**：自动生成结构化 markdown 文档并写入知识库，显示完整文件路径
- **文件命名**：`YYYY-MM-DD-error-slug.md`（日期 + 错误简短描述）
- **文档结构**：
  ```yaml
  ---
  title: 错误标题
  date: YYYY-MM-DD
  tags: [标签 1, 标签 2]
  error_type: 错误类型/错误码
  files: [相关文件路径]
  search_keywords: [检索关键词，含英文原形]
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

### 2.3 Agent 自主发现
- Agent 在执行任务时遇到未知错误并自行解决后，主动提示是否记录

## 3. 设计决策

| 需求点 | 方案 | 理由 |
|--------|------|------|
| 相似性判断 | 语义理解 + 结构化字段辅助**排序** | 覆盖模糊匹配（"OOM" vs "内存溢出"）；关键词匹配**不得**作为召回门槛，否则语义层形同虚设 |
| 记录时效 | `status` 字段 + 检索/统计时主动提示 12 个月前的记录 | 状态字段若无维护机制，三个月后必然全是 `verified`，等于没加 |
| 记录触发 | 自动识别"错误已解决"，主动询问 | 比纯手动更主动，比全自动更可控 |
| 检索触发 | 检测到错误类型即检索 | 符合"下次遇到问题先调用 skill"需求 |
| 存储组织 | 一个 markdown 文件一条记录 | 结构清晰，独立管理 |
| 存储位置 | 自定义路径，默认 `~/.claude/knowledge-base/` | 首次使用询问用户，全局共享所有项目 |

## 4. 存储位置配置

知识库路径优先级：

1. 配置文件 `~/.claude/error-knowledge-base-config.json`（仅含 `knowledge_base_path` 一个字段）
2. 环境变量 `ERROR_KB_PATH`
3. 默认 `~/.claude/knowledge-base/`

**首次使用流程**：检测到没有配置文件且未设置环境变量时，询问用户自定义知识库路径。

**每次保存**：显示完整存储路径，方便用户查找。

## 5. 目录结构

```
仓库/
├── error-knowledge-base/
│   └── SKILL.md                  # skill 主文件（技能包）
├── examples/
│   └── knowledge-base/           # 示例记录，供新用户快速验证
├── README.md                     # 使用说明
├── README_EN.md                  # 英文说明
└── CLAUDE.md                     # 需求文档（本文件）

用户本地/
├── ~/.claude/skills/error-knowledge-base/   # skill 安装位置
└── {knowledge_base_path}/                   # 知识库数据（用户自定义）
    ├── 2026-09-05-npm-eresolve.md
    ├── 2026-09-03-python-oom.md
    └── ...
```

## 6. 验收标准

- [ ] 用户描述错误时，skill 能检索知识库
- [ ] 语义匹配能找到表述不同但本质相似的错误
- [ ] 结构化字段（tags、error_type）能正确辅助过滤
- [ ] 错误解决后能识别并询问记录
- [ ] 首次使用时能主动询问并保存知识库路径
- [ ] 生成的 markdown 文件符合预定结构
- [ ] 每次保存后显示完整文件路径
- [ ] Agent 自主解决错误后能提示记录

## 7. 相关文件

- `README.md` - 用户使用说明
- `README_EN.md` - English user guide
- `error-knowledge-base/SKILL.md` - 技能实现细节

## Agent skills

### Issue tracker

Issue 记录在 GitHub Issues（github.com/xzw268688/error-knowledge-base），通过 `gh` CLI 读写。详见 `docs/agents/issue-tracker.md`。

### Triage labels

使用五个规范角色名作为标签：`needs-triage`、`needs-info`、`ready-for-agent`、`ready-for-human`、`wontfix`。详见 `docs/agents/triage-labels.md`。

### Domain docs

单 context 布局：`CONTEXT.md` + `docs/adr/` 位于仓库根目录。详见 `docs/agents/domain.md`。
