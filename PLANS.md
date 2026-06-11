# PLANS

按 `AGENTS.md` 约定：开始任务前在此写计划，执行中更新状态；已完结的历史任务批次归档到 `docs/archive/`（如 `plans-frontend-refactor-2026-06.md`）。

---

# AI 修复合并推送打包 — 进行中（2026-06-11）

## 分支
`codex/ai-streaming-stutter-followup`

## 执行计划

| 项目 | 状态 | 说明 |
|------|------|------|
| 01 收口当前改动 | ✅ | 已复核 diff，当前分支包含 AI 流式性能修复、DeepSeek V4 输出预算修复与默认模型切换 |
| 02 完成验证 | ✅ | `swift test`（24 tests）、`bash check_vibe_changes.sh`、单独 rectify smoke 已通过 |
| 03 提交并合并到 `main` | ⏳ | 提交当前分支改动，切回 `main` 做 fast-forward 合并 |
| 04 推送远端 | ⏳ | 推送 `main` 到 `origin/main` 并核对不再 ahead |
| 05 打包覆盖 | ⏳ | 运行 `./package_app.sh`，确认 `/Applications/TransitStudio.app` 为 `1.1.5 (24)` |

---

# AI 思考过程截断修复与打包 — 进行中（2026-06-10）

## 分支
`codex/ai-streaming-stutter-followup`

## 执行计划

| 项目 | 状态 | 说明 |
|------|------|------|
| 01 查询请求参数 | ✅ | 已看到 `LLMAnalysisClient` 固定 `max_tokens=4096`，默认 `reasoning_effort=max` |
| 02 查询 SSE 结束处理 | ✅ | 当前代码未解析 `finish_reason`，服务端 `length` 等结束原因会被误判为正常完成 |
| 03 调整 DeepSeek V4 请求 | ✅ | DeepSeek V4 请求改用官方最大输出 `384000`，并显式发送 `thinking` enabled/disabled |
| 04 更新默认模型 | ✅ | 新安装默认 Base URL / 模型改为 DeepSeek V4 Flash，保留 V4 Pro 选项 |
| 05 验证与打包 | ✅ | `swift build`、`swift test`（24 tests）、`bash check_vibe_changes.sh` 与单独 rectify smoke 已通过；版本已递增到 `1.1.5 (24)` |

---

# AI 流式性能修复打包覆盖 — 已完成（2026-06-10）

## 分支
`codex/ai-streaming-stutter-followup`

## 执行计划

| 项目 | 状态 | 说明 |
|------|------|------|
| 01 确认打包版本 | ✅ | 当前脚本为 `1.1.3 (22)`；本轮 AI 流式性能修复递增为 patch 版本 |
| 02 更新打包脚本与记录 | ✅ | `package_app.sh` 已更新为 `1.1.4 (23)`，`CHANGELOG.md` 已同步 |
| 03 执行覆盖安装 | ✅ | 第二次运行 `./package_app.sh` 成功，已覆盖 `/Applications/TransitStudio.app` |
| 04 验证产物 | ✅ | `/Applications/TransitStudio.app` Info.plist 为 `1.1.4 (23)`，codesign verify 通过 |

---

# AI 流式输出二次卡顿定位 — 已完成（2026-06-10）

## 分支
`codex/ai-streaming-stutter-followup`

## 执行计划

| 项目 | 状态 | 说明 |
|------|------|------|
| 01 复查当前流式路径 | ✅ | 已查询 `ContentView+AI` / `AIAnalysisView` / `AIStreamBuffer` / SSE 客户端与调用点 |
| 02 定位剩余卡顿来源 | ✅ | 剩余热区是 MainActor per-token 消费、flush 后 growing string COW 拷贝、`Text(全文)` 长文重排与流式 text selection |
| 03 最小修复 | ✅ | 流消费 helper 显式 `nonisolated`；buffer 改追加 delta segment；流式视图改分段 `LazyVStack` |
| 04 验证与记录 | ✅ | `swift build`、`swift test`、`bash check_vibe_changes.sh`（提权跑完整门禁）与单独 rectify smoke 已通过；`CHANGELOG.md` 已更新 |

---

# AI 流式输出性能修复 — 已完成（2026-06-10）

## 分支
`refactor/frontend-tokens-views-vm`

## 执行计划

| 项目 | 状态 | 说明 |
|------|------|------|
| 01 定位根因 | ✅ | 每 token 全量重发布 + 全文 markdown 重解析，O(n²) 压死主线程 |
| 02 消费端节流 | ✅ | `analyze()` 100ms 合并发布，结束时一次性落盘最终文本 |
| 03 失效范围隔离 | ✅ | 新增 `AIStreamBuffer`，流式热文本只触发 `AIAnalysisView` 重渲染 |
| 04 渲染降级与缓存 | ✅ | 流式期间纯 Text；结束后一次性分块解析并缓存于 `@State` |
| 05 SSE 解析提速 | ✅ | 逐字节迭代改 `bytes.lines` |
| 06 验证与记录 | ✅ | swift build/test 通过；CHANGELOG 已更新；提交 `2a7ec9a` |

---

# 全项目体检与防腐加固 — 已完成（2026-06-10）

## 分支
`refactor/frontend-tokens-views-vm`

## 执行计划

| 项目 | 状态 | 说明 |
|------|------|------|
| 01 全项目扫描 | ✅ | 危险写法/重复/超长文件/依赖/仓库卫生全量排查，报告见会话记录 |
| 02 分支与备份 | ✅ | 删除废弃分支（bug-sweep 留 archive tag）；重构分支推送 GitHub |
| 03 小行星下载校验 | ✅ | 下载内容校验 SWISSEPH 文件头，HTML 错误页不再污染星历目录 |
| 04 后端契约测试 | ✅ | `BackendContractTests` 7 个，fixture 为后端真实输出；Swift 测试 10 → 17 |
| 05 计算样板去重 | ✅ | `performRun` 收口 14 处 isRunning/错误/进度样板 |
| 06 大文件拆分 | ✅ | ClassicalResultViews / ContentView+ResultsPanes 按页面边界拆为 7 个文件 |
| 07 吠陀死 tab 修复 | ✅ | AI 分析/诊断/JSON 三个 tab 接通（含完整流式 AI 管线） |
| 08 tab 标题查表化 | ✅ | 11 个结果页 `resultTabTitle()` 查表，治愈 5 处标题漂移并消灭该 bug 类 |
| 09 CI | ✅ | GitHub Actions：push 即跑 swift build/test + pytest + 5 个 smoke |
| 10 仓库卫生 | ✅ | 计划文档归档、horary 样例补齐、check_vibe 升级、git gc |
| 11 打包覆盖 | ✅ | `1.1.3 (22)` 已覆盖安装 /Applications |

## 跳过项（用户决定）

- 本命档案导出/备份（建议后续单独做：当前档案只存 UserDefaults，无迁移机制）
- LLM API key 迁 Keychain；后端 60 秒硬超时调整

---

# 文档同步 — 已完成（2026-06-10）

## 执行计划

| 项目 | 状态 | 说明 |
|------|------|------|
| 01 PLANS.md 归档与补记 | ✅ | 旧批次移入 docs/archive，本轮任务补记 |
| 02 project-structure.md | ✅ | 同步拆分后的文件结构、状态对象、Fixtures、CI |
| 03 validation.md | ✅ | 补 BackendContractTests、fixture 再生成、CI、check_vibe |
| 04 AGENTS.md | ✅ | 验证清单与 Source of Truth 更新，新增 AI 流式与 tab 约定 |
