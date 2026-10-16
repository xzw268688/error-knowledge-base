---
title: "Docker 容器端口已被占用"
date: "2026-09-22"
tags: ["docker", "网络", "端口", "开发环境"]
error_type: "bind: address already in use"
files: ["docker-compose.yml"]
search_keywords: ["address already in use", "port is already allocated", "端口占用", "端口冲突", "bind failed", "docker 端口", "3000 被占用", "端口被占"]
draft: false
status: "verified"
---

# 错误现象

`docker compose up` 失败：

```
Error response from daemon: driver failed programming external connectivity:
Bind for 0.0.0.0:3000 failed: port is already allocated
```

或者不加 `-d` 时报 `bind: address already in use`。

# 解决步骤

1. 找出占用者是谁，别急着杀：
   - macOS / Linux：
     ```bash
     lsof -nP -iTCP:3000 -sTCP:LISTEN
     ```
   - Windows（PowerShell）：
     ```powershell
     Get-NetTCPConnection -LocalPort 3000 | Select-Object OwningProcess
     Get-Process -Id <上一步的ID>
     ```
2. 如果占用者是**上一次没退干净的自己**的容器，直接移除：
   ```bash
   docker compose down --remove-orphans
   ```
3. 如果占用者是宿主机上的无关进程（常见于本机开发服务器），**优先改映射端口而不是杀进程**：
   ```yaml
   ports:
     - "3001:3000"   # 宿主机 3001 → 容器 3000
   ```
4. 确认端口是否被容器模式占着：
   ```bash
   docker ps --filter "publish=3000"
   ```

# 根因分析

Docker 的端口映射走的是宿主机网络栈，谁先占住 3000 谁就赢。容器内监听 3000 和宿主机 3000 被占用是两回事——改映射端口解决前者，杀进程只能解决后者。