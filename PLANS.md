# 后端计算代码整体审查（2026-09-08）

状态：完成（只读审查，未改业务代码）。授权范围：`Sources/TransitStudio/Resources/backend/` 全部 61 个 Python 模块（约 31.7k 行），目标找出真实计算 bug，每条给文件:行号与可复现验证。详细报告：`docs/backend-calculation-review-20260908.md`。

- [x] 分组派出 sub agent 深读全部后端模块（12 组：core/classical×2/modern×2/vedic/horary×2/rectify-scan/techniques/api/跨模块一致性）。
- [x] 汇总疑似 bug 清单，逐条在主会话复现验证（pytest 基线 1091 passed + pyswisseph 数值对拍 + 权威资料核对）。
- [x] 输出分级结论并更新本文件状态。

## 结论摘要

基线 `pytest` 1091 passed；核心行星数据、ASC/MC、6 种宫位制、prenatal syzygy、solar return 求解均与 pyswisseph 独立对拍一致。新发现 **2 项 P1**、约 16 项 P2、约 20 项 P3，并确认 2026-08-26 旧扫描文档 11 项仍未修复；仲裁 2 项误报。

- **P1 埃及界 Aries 用了托勒密数值**（`astro_backend_classical_dignity.py:57`）：Aries 12–14°/20–21°/25–26° 界主判错，波及 bound/score/almuten/circumambulations 等全部 Egyptian 口径输出；`test_classical.py:100-105` 固化了错误值；其余 11 星座与 Tetrabiblos I.21 逐界一致。
- **P1 declination_timing 固定偏移时区被静默改成 UTC**（`astro_backend_declination_timing.py:199-205`）：`display_timezone="GMT+8"` 时所有 `*_local` 输出 UTC。
- P2 新发现：composite 非等宫制 ASC 轴与宫头不一致（实测差 18.8°）、Mercury Hayz 判定失效、primary_directions 非合相只取单方向、orbital_dial 忽略 modulus、Krittika 中文名错、Shadbala Jupiter +15/Drik 恒 0、method_families `or 1.0`/`bool()`、horary v2 速度缺失判 separating、mundane 无 orb 阈值、body 中文名两套、orb/阈值跨模块不统一等。
- horary 补审（首轮 `horary.py` 1–1000 行等缺口已补齐）：新增 P2 Frustration 第三方速度约束导致漏报（`horary.py:1483`）、`declination_parallels` 未校验同半球致双判/异号误判（`horary_v2_modules.py:906-947`），另有 10 项 P3；`lot_ruler_condition` 经复核实为误报。
- 误报仲裁：`armc_from_mc` 实为精确（MC 黄纬=0，与 swe ARMC 差 6e-14）；scan 无进度与 Swift 端一致（`BackendClient.scan` 不传回调）。
- 旧项复核仍未修复：hellenistic applying/separating 恒 0 行、Yogini 起算、approaching_sun 反转、scan 相位标签、patterns Kite、Davison 中点、visibility fallback 互换等（详见报告第二节）。

# 前端与桥接层问题审查（2026-09-08）

状态：完成（只读审查，未改业务代码）。授权范围：遍历 SwiftUI 前端与 Swift↔Python 桥接代码，找出真实问题并给出文件:行号证据。

- [x] 审查桥接层（进程调用、进度解析、超时/取消）。
- [x] 审查运行流程与状态管理（CalculationViewModel、RunActions、RunGeneration）。
- [x] 审查 AI 流式链路（SSE、节流、取消）。
- [x] 审查结果面板 tab 契约、请求/响应编解码与导出。
- [x] 汇总分级问题清单并更新本文件状态。

## 结论摘要

桥接契约本身健康：stderr 进度 JSONL 前后端格式一致（`astro_backend_rectify.py:382`、`astro_backend_modern_timing.py:1228`、`astro_backend_rectify_evidence.py:495` ↔ `BackendProgressBuffer.swift`）；scan 工作量阈值前后端一致（`ScanWorkEstimator.swift:4-6` ↔ `astro_backend_scan.py:38-40`）；30 个结果面板的 tab id 全部有渲染路径（8 个主 tab 靠 `default:` 兜底，行为正确）。发现的问题集中在状态清理、AI 流生命周期与固定超时：

- P1 切到吠陀时 Horary/生时矫正页面残留（`ClassicalWorkspace.swift:120-126` 缺重置，vedic rail 无对应按钮 `AppNavigationRail.swift:143-148`；`ClassicalWorkspaceTests.swift:183` 只覆盖 clamp）。
- P1 AI 流式分析无取消路径（`LLMAnalysisClient.swift:94-122` 非结构化 Task + 未处理 onTermination；`AIAnalysisView.swift:80-86` 无停止按钮）。
- P2 `analyze` 无并发防护 + `AIStreamBuffer.append` 不校验 activeKey，并发会串流（`ContentView+AI.swift:141-149`、`AIAnalysisViewModel.swift:41-56`）。
- P2 `RectifyClient` 在 terminationHandler 读 stderr 可能不完整（`RectifyClient.swift:54-71`，对比 `BackendClient.swift:376-388`）。
- P2 固定超时无进度续期：rectify 60s（`RectifyClient.swift:4`）、通用 300s（`BackendClient.swift:412-419`）。
- P3 `finishProgress` 延迟清理无代际检查（`ContentView+Progress.swift:37-43`）；`runModernTiming` 回调中 `!Task.isCancelled` 恒真（`ContentView+RunActions.swift:1458`）；`terminatedByTimeout` 无锁读（`BackendClient.swift:150/438`）；expansion 运行未走 `prepareAsteroidsIfNeeded`（8 处）。

验证：`swift build --disable-sandbox` 通过（35.50s）；tab 契约用一次性脚本核对（脚本在 /tmp，未入库）。未运行 `swift test` / `pytest`。

# 当前版本收尾与实时解码契约修复（2026-09-06）

状态：完成，已发布到本机。授权范围：整理当前未提交分支与待办文档，审查并收口已有计算修复，复现/修复后端真实 JSON 与前端解码不一致，完成验证、逻辑提交、主线收口及必要的版本发布清理。架构重设计仅整理状态，不按草案实施大规模重构。

当前改动分类：古典计算修复、现代计算修复、吠陀计算修复、架构提案/评审、后续计算审计清单和历史工作记录。先保留所有已有内容，依据源码与测试审查后分别提交。

- [x] 盘点完整差异、分支拓扑、文档与验证工具；建立真实后端输出解码基线。
- [x] 审查已有计算改动并完成基线验证；提交阶段按古典、现代、吠陀整理。
- [x] 修复 JSON 契约漂移，加入可重复运行的真实输出→Swift 解码检查，核对展示与导出。
- [x] 整理文档权威入口与已完成/待实施状态，保留后续提案和审计证据。
- [x] 完整验证与差异复核，核实最终源码差异与测试结果。
- [x] 单一逻辑提交并整合远端主线；已打包安装 `1.5.2 (51)` 到 `/Applications/TransitStudio.app`，并清理本轮构建、测试和封装缓存。

## 已取得的证据

- 未修复基线：Python 1088 / Swift 223 全绿，新增实时测试复现太阳弧 null speed 解码失败，其余 42 个样例可解码。
- 太阳弧修复后：43 个实时样例均可解码；日速度与年推运率分别保留，CSV/Markdown/JSON 专项回归补齐。
- SAV 独立回归先确认三组输入总分错误为 386，再修复七曜汇总为 337；相关吠陀测试 231 项通过。
- 完整验证：Python 1091 项通过（本轮复跑）；Swift 227 项、31 个 suite 通过；其中实时后端→Swift 解码样例 43 个全部通过；`git diff --check` 通过。本轮复跑 Swift 时被沙盒拒绝写入 `~/.cache/clang/ModuleCache`，属于环境权限限制；不改变此前成功的完整 Swift 结果。
- 远端主线的 `VIBE_WORKFLOW.md` 更新已无冲突整合。
- 本轮之前的任务记录移至 docs/archive/plans-through-2026-09-06.md；后续设计和审计状态见 docs/current-status.md。
- 已验证安装包 `CFBundleShortVersionString=1.5.2`、`CFBundleVersion=51`；清理 `.build`、`/private/tmp/astrotransit-package-build`、封装暂存目录及测试 scratch，保留 `dist/TransitStudio.app`。
