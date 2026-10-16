---
title: "Python 处理大数据集时内存溢出（MemoryError）"
date: "2026-09-10"
tags: ["python", "内存", "性能"]
error_type: "MemoryError"
files: ["etl/loader.py"]
search_keywords: ["memoryerror", "内存溢出", "内存不足", "out of memory", "oom", "内存爆了", "python 内存", "killed process"]
draft: false
status: "verified"
---

# 错误现象

跑离线 ETL 时进程被系统直接杀掉，或抛出：

```
MemoryError
```

用 `tracemalloc` 定位后发现：单个 2GB 的 CSV 被 `pd.read_csv()` 一次性读进了内存，而容器内存上限只有 1GB。

# 解决步骤

1. 先分清是 Python 抛的 `MemoryError`（进程内分配失败）还是被 OOM Killer 杀的（进程无声消失、退出码 137）。后者看 `dmesg | grep -i "killed process"`。
2. 改成分块流式处理，不要整文件载入：
   ```python
   for chunk in pd.read_csv(path, chunksize=10_000):
       process(chunk)
   ```
3. 非 pandas 场景用生成器逐行处理：`with open(path) as f: for line in f:`
4. 容器场景确认内存上限后，再按比例设置解释器上限，避免内核杀进程前先让 Python 抛可捕获的异常：
   ```bash
   python -X mx=800m etl/loader.py
   ```

# 根因分析

数据量增长后，原先"一次性读入"的假设不再成立。分块处理把峰值内存从 O(文件大小) 降到 O(块大小)。