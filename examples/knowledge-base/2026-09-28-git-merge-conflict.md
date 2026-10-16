---
title: "Git 合并冲突无法自动解决"
date: "2026-09-28"
tags: ["git", "版本控制", "协作"]
error_type: "merge conflict"
files: []
search_keywords: ["merge conflict", "CONFLICT", "合并冲突", "冲突未解决", "both modified", "git 冲突", "<<<<<<<"]
draft: false
status: "verified"
---

# 错误现象

`git pull` 后停在合并中间态：

```
Auto-merging src/config.ts
CONFLICT (content): Merge conflict in src/config.ts
Automatic merge failed; fix conflicts and then commit the result.
```

# 解决步骤

1. 先看清冲突涉及哪些文件，以及**双方各自改了什么**——不要直接打开编辑器挑一个：
   ```bash
   git status              # 列出冲突文件
   git diff --diff-filter=U
   ```
2. 三方对比同一文件的三个版本（共同祖先 / 你的版本 / 对方版本）：
   ```bash
   git checkout --conflict=diff3 src/config.ts
   ```
   `diff3` 模式会额外显示 `<<<<<<<` 之外的共同祖先版本，多数冲突看一眼就能判断该保留哪边。
3. 手动改完，删掉 `<<<<<<<` / `=======` / `>>>>>>>` 标记，然后：
   ```bash
   git add src/config.ts
   git merge --continue
   ```
4. 想**放弃这次合并**回到操作前状态：
   ```bash
   git merge --abort     # 合并中
   git rebase --abort    # 变基中
   ```

# 根因分析

两条分支修改了同一区域的同一行，Git 无法在不理解意图的前提下自动合并，只能交给人。养成 `pull --rebase` + 短分支的习惯能显著减少冲突频率。