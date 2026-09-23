# R-P1-2 / W02 证据化关闭（2026-09-23）

状态：已完成；本任务仅纠正审查/计划文档，不改业务代码、测试、fixture 或 schema。

- [x] 核对当前 `codex/bugfix-plan-v2` 分支、工作区状态及项目规则。
- [x] 检查 `_display_zone` 全部调用点与 `calculate_declination_timing` 生产时区解析路径。
- [x] 对 `Examples/sample-declination-timing-request.json` 分别以 GMT+8、UTC 运行真实 `transit_calc.py` 入口，对比事件数、UTC 精确时刻与当地时刻。
- [x] 修订 v2 的 EV-04、R-P1-2 来源登记、W02 任务卡和执行顺序；在原审查报告 P1-2 后追加仲裁说明，保留历史正文。
- [x] 更新 CHANGELOG 与本文完成记录；核对 87 个来源 ID、18 个工作包、Markdown 链接/编号/围栏和完整 diff。
- [x] 提交一个本地 docs 逻辑提交；不推送。

证据摘要：`_display_zone` 只有定义，没有生产调用。生产函数先尝试 `ZoneInfo(display_timezone)`，再由 `resolve_timezone` 解析固定偏移。真实入口 GMT+8 / UTC 均返回 262 个事件；首事件 `exact_utc` 均为 `2026-01-02T08:10:49.525Z`，`exact_local` 分别为 `2026-01-02T16:10:49.525+08:00` 与 `2026-01-02T08:10:49.525+00:00`。结论：R-P1-2 是生产误报，关闭为已证明非缺陷；未调用 helper 的局部错误不构成 P1，也不作为 P1 修复项。

# 后端缺陷修复总体计划（2026-09-22）

状态：**计划已产出，未开始修复**。授权范围：汇总 `docs/` 内全部 bug/审查文档待修项并写出可执行修复计划；本轮**不修改任何业务代码**。详细计划：`docs/bugfix-master-plan-20260922.md`。

- [x] 通读 `docs/backend-calculation-review-20260908.md`、`docs/backend-calculation-bug-scan-20260826.md`、`docs/horary-remaining-fixes.md`、`docs/calculation-audit-repair-spec.md`、`docs/current-status.md`、`docs/horary-audit-2026-07-10.md`、`docs/horary-fix-guide-2026-07-11.md`。
- [x] 对照源码核验关键位置（`EGYPTIAN_BOUNDS`、`_display_zone`、composite 重建、Hayz、PD 单方向、orbital_dial modulus、method_families `or 1.0`/`bool()`、Krittika、patterns kite/去重、horary 速度缺失、Frustration 速度约束、declination_parallels 半球、旧扫描 11 项等）。
- [x] 状态分流：已关闭/误报/待修复/需口径决策；产出批次 A–G 任务卡（修法、影响面、测试、fixture、风险）。
- [x] 写出 PR 切分、影响面总表、验证门禁与剩余风险登记。
- [ ] 批次 A（2 项 P1）——待授权开工。
- [ ] 批次 B/C/D（P2）——待授权开工。
- [ ] 批次 E/F（P3）——待授权开工。
- [ ] 批次 G（口径决策）——待人类确认。

## 计划摘要

- **P1 来源线索 2 项**：埃及界 Aries 误用托勒密数值仍待独立来源复核（`astro_backend_classical_dignity.py:57`，对应 W01）；R-P1-2 已通过真实生产入口证明为误报并关闭（未调用的 `_display_zone` helper 局部返回 UTC，不影响 `*_local` 输出）。来源登记仍保留两条以维持可追溯性，当前待修 P1 为 1 项。
- **P2 27 项**（新 16 + 旧 11，去重后）：composite ASC/宫头不一致、Mercury Hayz、PD converse 缺失、orbital_dial modulus、Krittika 译名、Shadbala Jupiter+15/Drik=0、method_families 参数吞噬、horary 速度缺失判离相、station 采样过稀、mundane 无 orb 阈值与 count 矛盾、body 中文名两套、阈值不统一、Frustration 速度约束、declination_parallels 半球、恒星 ARMC flag、hellenistic 证据行恒空、出生瞬间当返照、Yogini 起算、upagraha 占位、approaching_sun 反转、mundane 日时主键名、scan 入离相、Kite 标签、图形去重、Davison 大圆中点。
- **P3 约 54 项**（新 30 + 旧 24）：按输入校验/时间精度/契约静默/horary 语义四组分批。
- **误报 4 项不修**；**已关闭** SAV-337、horary A–J、13 项 audit；**8 项 DECISION_REQUIRED**（PTOLEMAIC_BOUNDS 版本、Shadbala 完整度、PD 双向、moiety orb、年长常数、upagraha 方案、Frustration 变体/事件 id/morning_evening、composite ASC/MC 权威）。
- 执行纪律：先失败测试→最小修复→模块回归；每批独立分支 + CHANGELOG；JSON 形状变更必须同步 Swift 模型/导出/fixture + LiveBackendContractTests；收尾 `bash check_vibe_changes.sh`。

---

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


# 修复总计划编写模型能力评价（2026-09-22）

状态：完成。范围：阅读指定计划，抽查接口与方案自洽性，在聊天中评价作者体现的能力；不执行修复。现有未提交变更属于此前审查与计划任务，保留。

- [x] 阅读项目规范与指定计划全文。
- [x] 抽查关键修法、验证设计与任务覆盖：本机 houses_armc 不接受 flags；用现有函数验证 C-1 两相位分支可同号；源报告 P2-j 未获独立任务卡。
- [x] 完成能力评价：组织与工程流程较强，接口核验、数学约束和完整性收口不足；结论交付聊天。


# 修复总计划 v2（2026-09-22）

状态：完成（文档交付，业务修复未开始）。授权范围：保留原版，新建更完善的修复计划；核对全部来源条目、技术方案、决策依赖与验收条件，不实施业务修复。现有 CHANGELOG/PLANS 与两份未跟踪文档属于此前审查任务，保持原样；本任务仅追加记录并新增 v2 文档。

- [x] 通读来源、项目验证及已关闭边界，建立 87 条来源登记（包含候选与可能误报，不代表 87 个确认缺陷）。
- [x] 核验 houses_armc、PD 同号反例、时区、27 宿/Yogini、mundane facts-only、schema 与发布资源，记录 12 条证据。
- [x] 新建 docs/bugfix-master-plan-20260922-v2.md，登记 18 个工作包、14 个决策议题，补充独立验收与完整包发布要求。
- [x] 校验 87 个唯一来源 ID、单一工作包归属、18 个包/14 个决策引用、本地链接、真实测试与 Swift 文件名、代码围栏及 diff；未跑全量业务测试或构建。

# 修复总计划 v2 工作路线分析（2026-09-23）

状态：完成（路线分析）。范围：通读 v2 文档，对照项目现状与依赖关系，给出分阶段执行路线；本轮不修改业务代码。

- [x] 阅读 v2 全文，核对 18 个工作包、14 个决策议题和验证门禁。
- [x] 对照当前工作区与 P1、输入校验、mundane 事实字段和完整门禁脚本，整理可立即开工、待决策和发布收口的顺序。
- [x] 在聊天中交付路线与主要风险；未运行测试或构建，未声称业务缺陷已修复。

# 当前分支文档收尾与验证（2026-09-23）

状态：完成本地收尾。范围：把当前 `codex/bugfix-plan-v2` 的既有审查和计划文档按任务边界提交，验证整条分支并清理本轮缓存；未实施计划中的业务修复或重新打包应用。

- [x] 核对分支与远端基线；将后端/前端审查、原版计划、v2 修订分别提交，原版增加历史版本提示。
- [x] 核验 v2 的 87 个唯一来源 ID、18 个工作包、14 个决策、本地链接及代码围栏；`git diff --check` 通过。
- [x] 完整门禁通过：Python 1091 项、Swift 227 项（31 个 suite），其中 43 个 Examples 实时后端解码样例通过。
- [x] 清理 `/private/tmp/astrotransit-bugfix-plan-v2-validation-20260923` 构建缓存。
