---
title: "MySQL 连接数耗尽（Too many connections）"
date: "2026-10-08"
tags: ["mysql", "数据库", "连接池", "性能"]
error_type: "Too many connections"
files: ["application.yml"]
search_keywords: ["too many connections", "连接数超限", "连接池", "max_connections", "1040", "mysql 连接失败", "连接被拒绝", "连接耗尽"]
draft: false
status: "verified"
---

# 错误现象

应用批量导入时报：

```
ERROR 1040 (HY000): Too many connections
```

或连接建立很慢、大量 `Communications link failure`。

# 解决步骤

1. 先确认是**服务端上限**还是**客户端连接泄漏**，两者现象相似但解法完全不同：
   ```sql
   SHOW STATUS LIKE 'Threads_connected';
   SHOW VARIABLES LIKE 'max_connections';
   ```
2. 若是客户端连接泄漏——每个请求新建连接却不归还，特征是连接数**只增不减**。改用连接池并设上限：
   ```yaml
   datasource:
     hikari:
       maximum-pool-size: 10
       minimum-idle: 2
       connection-timeout: 30000
   ```
3. 若确需提高服务端上限，先看是否有大量 `Sleep` 状态的空闲连接：
   ```sql
   SELECT user, host, COUNT(*) FROM information_schema.processlist GROUP BY user, host;
   ```
   有长期 Sleep 的连接应先调 `wait_timeout` 回收，而不是直接调大 `max_connections`。
4. 确有必要再改（注意重启生效，且会加大内存占用）：
   ```sql
   SET GLOBAL max_connections = 500;
   ```

# 根因分析

`max_connections` 常被当成"不够就调大"的问题，但连接数打满通常是连接生命周期管理失控的**症状**。盲目调大会把瓶颈从"连不上"推迟到"数据库整体变慢"。