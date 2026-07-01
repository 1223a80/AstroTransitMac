# PLANS

按 `AGENTS.md` 约定：开始任务前在此写计划，执行中更新状态；已完结的历史任务批次归档到 `docs/archive/`（如 `plans-frontend-refactor-2026-06.md`）。

---

# Vedic 恋爱窗口推算 — 已完成（2026-06-28）

## 执行计划

| 项目 | 状态 | 说明 |
|------|------|------|
| 01 确认数据来源 | ✅ | 已读取整理好的本命、Dasha、Chara、Mudda、过运、年返/月返资料；未使用既有恋爱报告作为依据 |
| 02 复核计算接口 | ✅ | 已确认 `/usr/local/bin/python3` 的 `pyswisseph 2.10.03` 可用，并查询项目 Vedic 后端结构 |
| 03 独立计算窗口 | ✅ | 已以 2026-06-28 至 2027-06-28 为未来一年，重算 Whole Sign 过运、精确合相/相位与日评分 |
| 04 输出结论 | ✅ | 已整理按机会强弱排序的恋爱窗口、关键日期、依据和谨慎段 |

---

# 审计确认 bug 修复 — 已完成（2026-06-16）

## 分支
`codex/fix-audit-confirmed-bugs`

## 执行计划

| 项目 | 状态 | 说明 |
|------|------|------|
| 01 确认工作区与目标位置 | ✅ | 已确认工作区仅有未跟踪 reasonix 本地配置，目标代码位置与审计描述一致 |
| 02 修复后端边界问题 | ✅ | 已修复 Horary 月亮异常速度 fallback、Whole Sign fallback、JSON NaN 输出、composite 吞异常、classical timing 零除保护 |
| 03 修复 Swift 超时与 ignore | ✅ | BackendClient 超时已改 300s，`.gitignore` 已加入 reasonix 本地配置 |
| 04 验证与 diff 复核 | ✅ | `bash check_vibe_changes.sh` 已通过；已检查 `git diff --stat` 与完整 diff |

---

# Horary 数据包增强方案评估 — 已完成（2026-06-12）

## 分支
`codex/fix-horary-perfection-timing`

## 执行计划

| 项目 | 状态 | 说明 |
|------|------|------|
| 01 盘点当前实现 | ✅ | 已核对 horary 后端、Swift 模型、Markdown 导出、fixture 与现有脏工作区状态 |
| 02 映射 A 中建议 | ✅ | 已按“已有底层数据 / 仅缺导出 / 需要新增计算 / 牵动契约”分类 |
| 03 评估难度与路线 | ✅ | 已完成按当前实现的分级难度、推荐迭代顺序、关键风险与测试边界评估 |

---

# Horary 慢行星成相窗口与高级判定补修 — 已完成（2026-06-12）

## 分支
`codex/fix-horary-perfection-timing`

## 执行计划

| 项目 | 状态 | 说明 |
|------|------|------|
| 01 确认问题 | ✅ | 已确认 exact 搜索窗口仍固定 30 天、Frustration 恒 not detected、`before_sign_exit_aspects` 截断会影响 key link 计算 |
| 02 修复慢行星成相窗口 | ✅ | 按双方最早换座时间动态决定搜索窗口，不再用 30 天硬上限 |
| 03 修复月亮列表截断 | ✅ | `before_sign_exit_aspects` 返回完整计算列表，显示截断留给前端；key link 不再吃截断数据 |
| 04 实现 Frustration | ✅ | 增加真实“主相位前较慢方先与第三方成相”检测与回归 |
| 05 回归、验证与打包 | ✅ | 已加真实木星-土星慢相位回归、列表截断回归、Frustration 回归；fixture 已刷新，门禁通过并已打包覆盖 `1.1.7 (26)` |

---

# Horary 月亮故事线边界修复与打包 — 已完成（2026-06-11）

## 分支
`codex/fix-horary-perfection-timing`

## 执行计划

| 项目 | 状态 | 说明 |
|------|------|------|
| 01 确认问题 | ✅ | 已确认月亮 VOC 过滤未检查对方先换座、分钟字符串排序丢秒、月亮特例 orb 被写成 0.0 |
| 02 修复 moon_storyline | ✅ | 改为内部 datetime 排序/过滤，并在 before-sign-exit 过滤里排除目标行星先换座的相位 |
| 03 修复月亮特例 orb | ✅ | `key_significator_links` 使用当前度数 orb，不再把未来 exact 显示为当前 0.0 |
| 04 回归与 fixture | ✅ | 新增目标先换座、同分钟先后顺序、月亮特例 orb 回归；已刷新 horary fixture |
| 05 验证与打包 | ✅ | Python/Swift/一键门禁均通过；版本已升至 1.1.6 (25) 并覆盖 `/Applications`，codesign verify 通过 |

---

# Horary xhigh 复查补修 — 已完成（2026-06-11）

## 分支
`codex/fix-horary-perfection-timing`

## 执行计划

| 项目 | 状态 | 说明 |
|------|------|------|
| 01 xhigh 复查 | ✅ | 复核 horary 计算链后追加确认：同星角色会产生 self-aspect 假成相，高级判定需排除同星主相位，逆行 ingress 标签用错目标星座，驻留阈值仍是一刀切 |
| 02 修复同星假成相 | ✅ | `key_significator_links` / `exact_datetime_for_signature` / 高级判定统一排除同一行星自相位 |
| 03 修复辅助计算口径 | ✅ | horary 驻留改行星独立阈值；scan 逆行换座目标星座显示改为实际进入的星座 |
| 04 补回归与 fixture | ✅ | 已增加同星角色、高级判定、驻留阈值、逆行 ingress 回归；已刷新 horary fixture |
| 05 验证与 diff 复核 | ✅ | horary/scan/classical pytest、horary smoke、Swift build/test、一键门禁与 diff 边界检查均通过 |

---

# Horary 成相时间与入离相修复 — 已完成（2026-06-11）

## 分支
`codex/fix-horary-perfection-timing`

## 执行计划

| 项目 | 状态 | 说明 |
|------|------|------|
| 01 复核现状 | ✅ | 已复现月日合相/冲相 30 天内找不到、月亮近精确拱相误判离相、degree key aspects 为空 |
| 02 修正计算链 | ✅ | 已改有符号相位分支扫描、瞬时入离相、精算换座与 before sign exit 判断 |
| 03 修正高级判定 | ✅ | Translation / Collection / Prohibition / Frustration 已按时间顺序和古典定义收口 |
| 04 补回归测试 | ✅ | 已覆盖合冲精确时间、degree geometry、月亮入相、换座前成相、高级判定误报 |
| 05 Fixture 与验证 | ✅ | 已刷新 horary fixture；pytest、swift build/test、check_vibe_changes.sh 均通过 |

---

# AI 修复合并推送打包 — 已完成（2026-06-11）

## 分支
`codex/ai-streaming-stutter-followup`

## 执行计划

| 项目 | 状态 | 说明 |
|------|------|------|
| 01 收口当前改动 | ✅ | 已复核 diff，当前分支包含 AI 流式性能修复、DeepSeek V4 输出预算修复与默认模型切换 |
| 02 完成验证 | ✅ | `swift test`（24 tests）、`bash check_vibe_changes.sh`、单独 rectify smoke 已通过 |
| 03 提交并合并到 `main` | ✅ | 已提交 `2ec3def fix: harden ai streaming for deepseek v4`，并 fast-forward 合并到 `main` |
| 04 推送远端 | ✅ | `main` 已推送到 `origin/main`，当前分支不再 ahead |
| 05 打包覆盖 | ✅ | `./package_app.sh` 已完成覆盖安装，`/Applications/TransitStudio.app` 为 `1.1.5 (24)` 且 codesign verify 通过 |

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
