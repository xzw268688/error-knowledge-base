---
title: "Node 服务启动时报 EADDRINUSE"
date: "2026-09-14"
tags: ["node", "端口", "进程"]
error_type: "EADDRINUSE"
files: ["server.js"]
search_keywords: ["eaddrinuse", "address already in use", "端口占用", "端口被占", "listen 失败", "node 端口"]
draft: false
status: "deprecated"
---

# 错误现象

启动 Node 服务时：

```
Error: listen EADDRINUSE: address already in use :::3000
```

# 解决步骤

> ⚠️ **已过时**：以下步骤只适用于 macOS / Linux。Windows 用户请改用本仓库的 `2026-09-22-docker-port-conflict.md`，其中给出了 PowerShell 的查询方式。

1. 找出占用进程：
   ```bash
   lsof -nP -iTCP:3000 -sTCP:LISTEN
   ```
2. 杀掉它：
   ```bash
   kill -9 $(lsof -t -i:3000)
   ```
3. 或者干脆改用环境变量指定端口：
   ```bash
   PORT=3001 node server.js
   ```

# 根因分析

进程正常退出时内核会释放监听端口，但进程被强杀前未关闭的 socket、或容器/IDE 残留的后台进程会继续占用。