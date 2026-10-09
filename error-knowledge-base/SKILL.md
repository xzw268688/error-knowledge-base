---
name: error-knowledge-base
description: "错误知识库：检索历史错误或记录新错误"
---

# 错误知识库 (error-knowledge-base)

管理个人/项目的错误解决经验：检索相似错误的历史解决方案，记录新解决的问题。

**核心特性**：
- **零配置迁移** — 无状态索引，每次动态扫描
- **轻量关键词匹配 + LLM 精排** — 兼顾速度与精度
- **重复检测** — 录入时自动提示疑似重复

---

## 存储位置

知识库路径优先级：
1. 配置文件 `~/.claude/error-knowledge-base-config.json`
2. 环境变量 `ERROR_KB_PATH`
3. 默认 `~/.claude/knowledge-base/`

首次使用时自动询问配置。

---

## 使用方式

### 搜索错误

直接描述遇到的问题：
```
npm install 报 ERESOLVE 怎么办
```

技能会检索知识库，返回相似记录和解决方案。

### 记录错误

解决问题后说：
```
搞定了，用 --legacy-peer-deps 解决的
```

技能会提取信息并提示确认。

### 查看记录

```
我记了哪些错误
```

### 查看统计

```
知识库情况
```

---

## 核心流程

### 流程 1: 检索错误

#### Step 1: 获取知识库路径

```pseudo
if exists("~/.claude/error-knowledge-base-config.json"):
    kb_path = read_json("~/.claude/error-knowledge-base-config.json").knowledge_base_path
elif env("ERROR_KB_PATH"):
    kb_path = env("ERROR_KB_PATH")
else:
    kb_path = "~/.claude/knowledge-base/"

# 首次使用检测
if not exists(kb_path):
    ask_user("知识库路径 {kb_path} 不存在，是否创建？")
    if user_confirm:
        mkdir(kb_path)
    else:
        ask_user("请指定新的知识库路径")
        kb_path = user_input()
        # 询问是否保存配置
        ask_user("是否保存此路径到配置文件？")
```

#### Step 2: 扫描并提取元数据

```pseudo
files = glob(kb_path + "/*.md")

if len(files) == 0:
    return "知识库为空，暂无历史记录"

candidates = []
for file in files:
    content = read(file)
    
    # 解析 YAML frontmatter
    if not contains(content, "---"):
        log_warning("{file} 缺少 YAML frontmatter，已跳过")
        continue
    
    frontmatter_str = extract_between(content, "---", "---")
    frontmatter = parse_yaml(frontmatter_str)
    
    # 提取关键字段
    candidates.append({
        "file": file,
        "title": frontmatter.title,
        "date": frontmatter.date,
        "tags": frontmatter.tags or [],
        "error_type": frontmatter.error_type,
        "search_keywords": frontmatter.search_keywords or [],
        "full_content": content
    })
```

#### Step 3: 关键词匹配（快速筛选）

```pseudo
query_keywords = extract_keywords(user_query)  # 提取用户 query 中的关键词
filtered_candidates = []

for candidate in candidates:
    match_score = 0
    
    # 匹配 error_type
    if any(kw in candidate.error_type for kw in query_keywords):
        match_score += 30
    
    # 匹配 tags
    for tag in candidate.tags:
        if any(kw in tag for kw in query_keywords):
            match_score += 20
    
    # 匹配 search_keywords
    for kw in candidate.search_keywords:
        if any(kw in q for q in query_keywords) or any(q in kw for q in query_keywords):
            match_score += 10
    
    if match_score > 0:
        candidate["match_score"] = match_score
        filtered_candidates.append(candidate)

# 按分数排序，取前 20 个候选
filtered_candidates.sort_by("match_score", desc=True)
candidate_list = filtered_candidates[:20]
```

#### Step 4: LLM 语义精排

```pseudo
if len(candidate_list) == 0:
    return "知识库中无相似错误记录"

# 构造精排 prompt
prompt = """
以下是一份错误知识库中的候选记录。
用户查询："{user_query}"

请评估每条记录与用户查询的相关性，给出 0-100 的匹配度分数。

候选记录：
{candidate_list_formatted}

请按相关性从高到低排序，返回 Top 5。
"""

ranked_results = llm_rerank(prompt)
```

#### Step 5: 返回结果

```pseudo
if len(ranked_results) == 0:
    return "知识库中无相似错误记录"

print(f"找到 {len(ranked_results)} 条相似记录:")
for i, result in enumerate(ranked_results, 1):
    print(f"\n### {i}. {result.title} [匹配度 {result.score}%]")
    print(f"📅 {result.date} | 🏷️ {', '.join(result.tags)} | 🔧 {result.error_type}")
    print(f"\n**错误现象**：{extract_error_phenomenon(result.full_content)}")
    print(f"**解决方案**：{extract_solution(result.full_content)}")

print("\n要我现在帮你执行解决方案吗？")
```

---

### 流程 2: 记录错误

#### Step 1: 检测解决信号

```pseudo
# 监听用户消息，检测解决信号
resolution_indicators = ["解决了", "搞定了", "弄好了", "fixed", "resolved", "working now"]

if any(indicator in user_message for indicator in resolution_indicators):
    # 从上下文中提取错误信息和解决方案
    error_info = extract_from_conversation("错误现象")
    solution_info = extract_from_conversation("解决方案")
    
    if error_info and solution_info:
        ask_user("是否记录此错误？")
        if user_confirm:
            proceed_to_generate_record(error_info, solution_info)
```

#### Step 2: 生成记录内容

```pseudo
# 构造 LLM prompt 提取信息
prompt = """
根据以下对话上下文，提取以下信息：

1. 错误标题（简短描述，如"npm 依赖冲突"）
2. 错误现象（详细的现象描述）
3. 解决步骤（具体的操作步骤或命令）
4. 根因分析（如果有明确的原因说明）
5. error_type（错误类型或错误码，如"ERESOLVE"）
6. tags（3-5 个标签，如 ["npm", "peer-dependencies"]）
7. search_keywords（5-8 个搜索关键词，用于快速检索）

对话上下文：
{conversation_history}

以 YAML 格式返回 frontmatter，然后是 Markdown 正文。
"""

record_content = llm_extract(prompt)
```

#### Step 3: 重复检测

```pseudo
# 解析生成的 frontmatter
frontmatter = parse_yaml(extract_frontmatter(record_content))
new_keywords = frontmatter.search_keywords
new_error_type = frontmatter.error_type
new_tags = frontmatter.tags

# 扫描现有记录
existing_files = glob(kb_path + "/*.md")
potential_duplicates = []

for file in existing_files:
    existing_content = read(file)
    existing_frontmatter = parse_yaml(extract_frontmatter(existing_content))
    
    # 规则 A: error_type 相同 + 至少 1 个 tags 重合
    score_a = 0
    if new_error_type == existing_frontmatter.error_type:
        score_a += 50
        common_tags = set(new_tags) & set(existing_frontmatter.tags)
        if len(common_tags) >= 1:
            score_a += 30
    
    # 规则 B: search_keywords 重叠 ≥ 3
    score_b = 0
    common_keywords = set(new_keywords) & set(existing_frontmatter.search_keywords)
    if len(common_keywords) >= 3:
        score_b = 80
    
    if score_a >= 80 or score_b >= 80:
        potential_duplicates.append({
            "file": file,
            "title": existing_frontmatter.title,
            "date": existing_frontmatter.date,
            "match_score": max(score_a, score_b)
        })

# 按分数排序
potential_duplicates.sort_by("match_score", desc=True)
```

#### Step 4: 提示重复检测

```pseudo
if len(potential_duplicates) > 0:
    print("⚠️ 检测到可能重复的记录:")
    for dup in potential_duplicates[:3]:  # 只显示前 3 条
        print(f"   - {dup.file} (匹配度 {dup.match_score}%)")
    
    action = ask_user("确定要新建这条记录吗？", options=["确认新建", "取消", "查看旧记录"])
    
    if action == "取消":
        return
    elif action == "查看旧记录":
        display(potential_duplicates[0].file)
        # 用户看完后再决定是否新建
```

#### Step 5: 写入文件

```pseudo
# 生成文件名
today = format_date(today, "YYYY-MM-DD")
slug = generate_slug(frontmatter.title)  # 如 "npm-eresolve"
filename = f"{today}-error-{slug}.md"
file_path = join(kb_path, filename)

# 写入文件
write(file_path, record_content)

print(f"✅ 已保存到: {file_path}")
print(f"   路径：{kb_path}/{filename}")
```

---

## 文件格式

每条记录是一个 markdown 文件：

```yaml
---
title: "npm 依赖冲突"
date: "2026-09-05"
tags: ["npm", "peer-dependencies", "ERESOLVE"]
error_type: "ERESOLVE"
files: ["package.json"]
search_keywords: ["npm install", "eresolve", "peer dependency", "--legacy-peer-deps", "npm conflict"]
draft: false
---

# 错误现象

在执行 `npm install` 时出现以下错误：
```
npm ERR! code ERESOLVE
npm ERR! ERESOLVE could not resolve
...
```

# 解决步骤

1. 检查 package.json 中的 peerDependencies 版本冲突
2. 使用 `--legacy-peer-deps` 忽略 peer 依赖检查：
   ```bash
   npm install --legacy-peer-deps
   ```

# 根因分析

两个相互依赖的包要求同一依赖的不同版本，npm 无法自动解析。
```

**文件命名规则**：`YYYY-MM-DD-error-slug.md`

---

## 异常情况处理

### 场景 1: 知识库路径不存在

**行为**：提示用户"知识库路径 {path} 不存在，是否创建？"
- [创建] — 自动创建目录并使用此路径
- [重新配置] — 输入新路径
- [取消] — 中止本次操作

### 场景 2: 扫描到空目录

**行为**：提示"知识库为空，要现在开始记录第一条错误吗？"
- [好的，教我如何记录] — 进入记录引导流程
- [暂时不需要] — 结束对话

### 场景 3: 文件格式损坏（缺少 frontmatter）

**行为**：跳过该文件，记录日志：
```
⚠️ 警告：{file} 缺少 YAML frontmatter，已跳过
```

并在返回结果中说明：
```
找到 X 条有效记录（另有 Y 条格式异常已被跳过）
```

### 场景 4: 检测到疑似重复记录

**行为**：轻量提示，用户自选：
```
⚠️ 检测到可能重复的记录：
   - 2026-09-05-npm-eresolve.md (匹配度 75%)
   
   确定要新建这条记录吗？
   [确认新建] [取消] [查看旧记录]
```

### 场景 5: LLM 无法提取关键信息

**行为**：回退到手动填写模式：
```
⚠️ 自动提取失败，请手动补充以下信息：

1. 错误标题：[用户输入]
2. 错误现象：[用户输入]
3. 解决步骤：[用户输入]
4. error_type（可选）：[用户输入]
5. tags（逗号分隔）：[用户输入]
```

---

## 故障排查

### 问题 1: 首次使用没有弹出配置向导

**可能原因**：
1. skill 未正确安装 — 运行 `ls ~/.claude/skills/error-knowledge-base/` 检查
2. 已有配置文件 — 检查 `~/.claude/error-knowledge-base-config.json` 是否存在

### 问题 2: 搜索不到任何记录

**可能原因**：
1. 知识库路径配置错误 — 检查配置文件中的路径是否存在
2. 知识库为空 — 先手动创建几条测试记录
3. 记录缺少 `search_keywords` 字段

### 问题 3: 迁移后无法使用

**解决方案**：
1. 确认新路径下有 `.md` 文件 — `ls {新路径}/`
2. 检查配置文件路径是否更新 — `cat ~/.claude/error-knowledge-base-config.json`
3. 重启 Claude Code 以刷新环境

---

## 相关文件

- `README.md` - 用户使用说明
- `README_EN.md` - English user guide
- `CLAUDE.md` - 需求文档
