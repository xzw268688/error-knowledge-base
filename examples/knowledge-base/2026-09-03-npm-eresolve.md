---
title: "npm install 依赖树冲突（ERESOLVE）"
date: "2026-09-03"
tags: ["npm", "node", "依赖管理", "peer-dependencies"]
error_type: "ERESOLVE"
files: ["package.json", "package-lock.json"]
search_keywords: ["npm install", "eresolve", "could not resolve", "peer dependency", "legacy-peer-deps", "npm 冲突", "依赖树", "peer dep"]
draft: false
status: "verified"
---

# 错误现象

执行 `npm install` 时失败：

```
npm ERR! code ERESOLVE
npm ERR! ERESOLVE could not resolve
npm ERR! While resolving: react@17.0.2
npm ERR! Found: react-dom@16.0.0
npm ERR! node_modules/react-dom
npm ERR!   react@"^16.0.0" from the root project
npm ERR! Conflicting peer dependency: react@"^17.0.0"
```

删除 `node_modules` 和 `package-lock.json` 重装无效。

# 解决步骤

1. 先看报错里的 `Found` 和 `Conflicting peer dependency` 两行，确认是哪两个包在互斥——**不要跳过这步直接上忽略参数**。
2. 确认下游包确实已发布支持新主版本的版本，能升则升：
   ```bash
   npm info <冲突包> peerDependencies
   ```
3. 如果依赖方短期内不会发版（常见于企业内网包、已归档的库），用忽略 peer 检查绕过：
   ```bash
   npm install --legacy-peer-deps
   ```
4. 把该参数写进项目 `.npmrc`，避免其他人 clone 后踩同一个坑：
   ```
   legacy-peer-deps=true
   ```

# 根因分析

两个包对同一个传递依赖声明了互斥的主版本范围，npm 的解析器无法同时满足，选择直接报错而不是降级。`--legacy-peer-deps` 关闭的正是这项检查。