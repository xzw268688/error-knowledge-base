---
title: "Python 打印中文报 UnicodeEncodeError"
date: "2026-10-02"
tags: ["python", "编码", "windows", "中文"]
error_type: "UnicodeEncodeError"
files: ["scripts/report.py"]
search_keywords: ["unicodeencodeerror", "编码错误", "gbk", "utf-8", "中文乱码", "codec can't encode", "print 中文", "stdout encoding"]
draft: false
status: "verified"
---

# 错误现象

Windows 上运行脚本打印中文：

```
UnicodeEncodeError: 'gbk' codec can't encode character '中' in position 0
```

同样的脚本在 Linux CI 上正常。

# 解决步骤

1. 确认当前标准输出编码，Windows 控制台默认常是 GBK：
   ```python
   import sys
   print(sys.stdout.encoding)
   ```
2. **首选**：强制 Python 使用 UTF-8 读写所有流，无需改代码：
   ```bash
   python -X utf8 scripts/report.py
   ```
3. 需要固化时，写进 `PYTHONUTF8=1` 环境变量或脚本入口：
   ```python
   import os
   if os.name == "nt":
       os.environ["PYTHONUTF8"] = "1"
   ```
4. Windows 终端本身要显示中文，还需要终端代码页为 UTF-8：`chcp 65001`。
5. **不要**用 `.encode('gbk', errors='ignore')` 绕过——那会把中文静默丢成问号。

# 根因分析

Windows 控制台默认代码页是 GBK，而 Python 源文件里的字符串是 Unicode，写出时无法用 GBK 表示的字符就会报错。这和文件读写是两回事——文件读写请显式指定 `encoding="utf-8"`。