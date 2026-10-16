---
name: error-knowledge-base
description: "错误知识库：检索历史错误或记录新错误"
---

# 错误知识库 (error-knowledge-base)

管理个人/项目的错误解决经验：检索相似错误的历史解决方案，记录新解决的问题。

**核心特性**：
- **零配置迁移** — 无状态索引，每次动态扫描
- **关键词加权 + LLM 语义精排** — 关键词只影响排序，永远不会阻断语义召回
- **重复检测** — 录入时自动提示疑似重复
- **状态标记** — 记录可标记为已验证 / 已过时，检索时优先呈现有效方案

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

### 标记记录状态

```
这个方案过时了
上面第一条验证过了
```

### 快速验证（知识库为空时）

仓库 `examples/knowledge-base/` 下有 8 条示例记录，可复制到知识库路径试跑完整流程。

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
        "status": frontmatter.status or "verified",
        "full_content": content
    })
```

#### Step 3: 关键词加权（仅影响排序，不做召回）

> ⚠️ **设计约束**：关键词匹配的结果**只能用于提高排序权重，绝不能用来决定"有没有候选"**。
> 早期版本把关键词匹配当作召回门槛，导致"OOM"检索"内存溢出"这类表述不同但本质相同的错误时筛出 0 条，
> Step 4 的语义精排根本不会执行，直接返回"无相似记录"。语义能力被前置的字面过滤器掐死了。

```pseudo
query_keywords = extract_keywords(user_query)  # 提取用户 query 中的关键词

# 有效性过滤：已标记过时的记录不参与召回
active_candidates = [c for c in candidates if c.status != "deprecated"]

for candidate in active_candidates:
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
    
    candidate["match_score"] = match_score

# 按关键词得分排序（得分相同则按日期倒序，新的优先）
active_candidates.sort_by([("match_score", desc), ("date", desc)])

# 截断上限：知识库规模增长后避免把上千条记录塞进 prompt
# 上限放宽到 50 —— 语义精排本身很便宜，召回率比省这点 token 重要
candidate_list = active_candidates[:50]
```

**兜底规则**：若 `candidate_list` 中**所有记录得分都是 0**
（典型场景：用户用完全不同的表述提问），仍然照常进入 Step 4——
关键词得分为 0 只意味着排序上靠后，**不意味着不相关**。语义精排正是为这种输入准备的。

#### Step 4: LLM 语义精排

```pseudo
# 注意：此处不设"候选为空即返回"的早退分支。
# 唯一允许早退的情况是知识库确实一条有效记录都没有。
if len(active_candidates) == 0:
    return "知识库中没有有效记录（可能全部被标记为已过时）"

# 构造精排 prompt
prompt = """
以下是一份错误知识库中的候选记录。
用户查询："{user_query}"

请评估每条记录与用户查询的相关性，给出 0-100 的匹配度分数。
判断时忽略措辞差异，只看**问题本身是否同类**——
"OOM"、"内存溢出"、"OutOfMemoryError"、"内存爆了"应当视为同一个问题。

候选记录：
{candidate_list_formatted}

请按相关性从高到低排序，返回 Top 5。
若没有任何一条相关度超过 30 分，返回空列表。
"""

ranked_results = llm_rerank(prompt)
```

#### Step 5: 返回结果

```pseudo
if len(ranked_results) == 0:
    print("知识库中无相似错误记录。")
    print("可以换个说法再问一次，或用「记录这个错误」把这次的解决方案存进来。")
    return

print(f"找到 {len(ranked_results)} 条相似记录:")
for i, result in enumerate(ranked_results, 1):
    print(f"\n### {i}. {result.title} [匹配度 {result.score}%]")
    print(f"📅 {result.date} | 🏷️ {', '.join(result.tags)} | 🔧 {result.error_type}")
    if result.status == "verified":
        print(f"✅ 状态：已验证有效")
    print(f"\n**错误现象**：{extract_error_phenomenon(result.full_content)}")
    print(f"**解决方案**：{extract_solution(result.full_content)}")

# 时效性提醒：超过 12 个月的记录，其解决方案可能已随版本变化失效
stale_results = [r for r in ranked_results if is_older_than(r.date, months=12)]
if len(stale_results) > 0:
    print(f"\n⚠️ 其中 {len(stale_results)} 条记录已超过 12 个月：")
    for r in stale_results:
        print(f"   - {r.title}（{r.date}）")
    print("   如果方案已失效，请告诉我，我会帮你标记为「已过时」。")

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
7. search_keywords（5-8 个搜索关键词，**必须包含英文/错误码原形**，例如 OOM 与 内存溢出 要能互相命中）
8. status（"verified" 或 "draft"：信息完整、已实际验证过 → verified；否则 → draft）

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

### 流程 3: 查看知识库统计

触发方式：用户说「知识库情况」「我的错误统计」「看看有多少条记录」等。

> **口径说明**：这里的"解决量"= **入库记录数**，即用户实际记录过的错误条数。
> 刻意**不统计检索命中次数**——知识库是纯 markdown 文件夹，没有任何埋点，
> 为了统计命中而引入写入计数文件会破坏"零配置迁移、无状态"的核心设计。

```pseudo
# Step 1: 扫描（与流程 1 Step 2 共用）
candidates = scan_and_extract(kb_path)   # 含 title/date/tags/error_type/status

if len(candidates) == 0:
    print("知识库为空，暂无记录。")
    return

# Step 2: 聚合
total = len(candidates)
active = count(c.status != "deprecated")
deprecated = total - active

by_month = group_count(candidates, key=lambda c: c.date[:7])   # "2026-09" → n
by_tag = group_count(candidates, key=lambda c: c.tags)          # 每个标签独立计数
by_error_type = group_count(candidates, key=lambda c: c.error_type)

recent_30d = count(c.is_within_days(30))

# Step 3: 输出
print(f"📊 知识库统计（共 {total} 条记录，路径：{kb_path}）\n")

print(f"有效记录：{active} 条    已过时：{deprecated} 条    近 30 天新增：{recent_30d} 条\n")

print("按月份：")
for month, n in sorted(by_month.items(), reverse=True):
    print(f"  {month}  {'█' * n} {n}")

print("\n按标签（前 10）：")
for tag, n in sorted(by_tag.items(), key=lambda kv: kv[1], reverse=True)[:10]:
    print(f"  {tag:<20} {n}")

print("\n按错误类型（前 10）：")
for et, n in sorted(by_error_type.items(), key=lambda kv: kv[1], reverse=True)[:10]:
    print(f"  {et:<30} {n}")

# 覆盖度提示：只出现过一次的标签说明分类粒度可能太细
singleton_tags = [t for t, n in by_tag.items() if n == 1]
if len(singleton_tags) > len(by_tag) * 0.6 and len(by_tag) > 5:
    print(f"\n💡 {len(singleton_tags)}/{len(by_tag)} 个标签只用过一次，标签体系可能偏碎，建议合并同类项。")
```

**处理边界情况**：
- 某条记录缺 `date` → 归入 `unknown` 分组，不中断统计
- 某条记录缺 `tags` → 不计入标签统计，但计入总数
- `by_error_type` 中的空值统一显示为 `未分类`

---

### 流程 4: 更新记录状态

状态字段是知识库能否长期可信的关键。**没有维护机制的状态字段，三个月后会全是 `verified`，等于没加。**
因此状态变更必须由明确触发，不允许静默发生。

```pseudo
# 触发信号
mark_stale_signals = ["过时", "不管用了", "失效了", "没用了", "已修复", "升级后好了"]
mark_verified_signals = ["验证过了", "确实有效", "按这个解决了", "验证通过"]

# Step 1: 定位目标记录
# 优先级：① 上一轮检索结果中用户明确指认的那条
#        ② 用户给的文件名或标题（模糊匹配，列出候选让用户选）
#        ③ 都不明确 → 列出最近的记录让用户选，绝不猜

# Step 2: 确认变更
print(f"将 {file} 的 status 从 {old_status} 改为 {new_status}")
action = ask_user("确认？", options=["确认", "取消"])

# Step 3: 改写frontmatter（只动 status 一行，正文与格式保持不变）
frontmatter = parse_yaml(extract_frontmatter(content))
frontmatter["status"] = new_status
new_content = replace_frontmatter(content, frontmatter)
write(file, new_content)

print(f"✅ 已更新：{file}")
if new_status == "deprecated":
    print("   该记录不再参与检索，但仍保留在知识库中作为历史参考。")
```

**`status` 的语义**：

| 值 | 含义 | 是否参与检索 |
|----|------|-------------|
| `verified` | 方案已实际验证有效（默认） | 是 |
| `draft` | 信息不全，方案未经验证 | 是，但在结果中提示 |
| `deprecated` | 已确认过时或失效 | 否 |

**维护节奏**：流程 3 的统计输出和流程 1 的检索结果都会主动列出超过 12 个月的记录，
用户一旦反馈"这个不管用了"即走本流程，形成闭环。**不要试图自动把旧记录改成 `deprecated`**——
自动判定"过时"必然误伤，正确性只能来自用户的确认。

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
status: "verified"
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
2. 知识库为空 — 先手动创建几条测试记录，或复制仓库中的 `examples/knowledge-base/*.md` 快速验证
3. 记录缺少 `search_keywords` 字段 — **不影响召回**（语义精排兜底），但排序会靠后
4. 记录全部被标记为 `deprecated` — 此时会返回"知识库中没有有效记录"，用流程 4 恢复

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
