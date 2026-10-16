---
title: "容器被 OOMKilled（JVM 堆溢出）"
date: "2026-09-18"
tags: ["java", "docker", "内存", "jvm", "容器"]
error_type: "OOMKilled"
files: ["Dockerfile", "application.yml"]
search_keywords: ["oomkilled", "outofmemoryerror", "内存溢出", "内存不足", "oom", "heap space", "exit code 137", "容器被杀", "jvm 内存"]
draft: false
status: "verified"
---

# 错误现象

服务运行几小时后被重启，日志末尾：

```
java.lang.OutOfMemoryError: Java heap space
```

`docker inspect` 显示容器状态是 `OOMKilled`，退出码 137。

# 解决步骤

1. 确认 JVM 堆不是被默认值锁死。JDK 8 时代容器里不显式设 `-Xmx`，堆上限只取物理内存的 1/4：
   ```bash
   java -XX:+PrintFlagsFinal -version | grep MaxHeapSize
   ```
2. 显式指定堆上限，且**始终小于容器内存上限**（留出 metaspace、线程栈、直接内存的空间）：
   ```
   # Dockerfile
   ENV JAVA_OPTS="-XX:MaxRAMPercentage=70"
   ```
3. 开启 OOM 时自动 dump 堆快照，事后用 MAT 分析是哪种对象在堆积：
   ```
   -XX:+HeapDumpOnOutOfMemoryError -XX:HeapDumpPath=/tmp/heap.hprof
   ```
4. 如果 dump 显示是缓存无上限增长，那是代码问题不是参数问题——给缓存加上界，而不是继续加内存。

# 根因分析

JVM 早期按物理内存比例推断堆大小，进入容器后这个"物理内存"是宿主机内存，容器限额根本不起作用，于是要么堆开太大被内核杀，要么堆太小抛异常。