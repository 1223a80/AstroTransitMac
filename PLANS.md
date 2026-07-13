# Horary 审计问题全量修复（2026-07-11）

## 分支

`codex/fix-horary-audit-2026-07`（基于 `49002fe`，包含审计文档及修复改动）

## 范围

修复 `docs/horary-audit-2026-07-10.md` 确认的 16 项 REQUIRED 问题；P3-02 为 DECISION_REQUIRED，未经用户确认不实现。

## 执行状态

| 批次 | 状态 | 结果 |
|---|---|---|
| A：UTC / refranation / ingress | ✅ | 完成并复审；移除五点启发式，改为当前相位分支的 UTC 连续收敛检查 |
| B：Moon 对称 / Advanced 事件 | ✅ | 完成并复审；四类 detector 共用同一 pair event facts，补 Moon 右侧与正向 Collection 回归 |
| C：Lots / score / negative reception | ✅ | 四项公式、最终 score label、detriment + fall 已修复 |
| D：Wheel / Swift / Lots / Raw JSON | ✅ | 稳定端点 ID、动态字段、实验组、同步 JSON 刷新及导出已完成 |
| E：meta / provenance / API validation | ✅ | sidereal 标签、aspect orb、全导出 provenance 和嵌套校验已完成 |
| F：全量门禁 | ✅ | Python 580；Swift 50；classical/moment/scan/horary/vedic/harmonic/rectify smoke 全绿 |
| F：版本 / 打包 / 安装 | ✅ | 1.3.1 (41) 已覆盖 /Applications；codesign、无 pycache、安装包 Horary smoke 均通过 |
| F：本地缓存清理 | ✅ | 已清理 `.build`、pytest cache、全部 `__pycache__` 与 `.pyc` |

## 明确边界

- P3-02 保持 DECISION_REQUIRED：未增加 quesited-house picker，也未擅自扩展 derived-house 关键词。
- 未改变 VOC、out-of-sign、mutual reception、moiety、默认宫制或 Hayz/ASC 业务口径。
- 未 push；分支改动在本地提交后交付。

# PLANS

按 `AGENTS.md` 约定：开始任务前在此写计划，执行中更新状态；已完结的历史任务批次归档到 `docs/archive/`（如 `plans-frontend-refactor-2026-06.md`）。

---

# 现代占星扩展实施蓝图 — 已完成（2026-07-13）

## 分支

`codex/modern-astrology-expansion-assessment`（延续同一现代占星规划任务；只落文档）

## 范围

- 将现有能力评估细化为可直接拆分施工分支的实施蓝图，不修改 Swift、Python、JSON fixture、版本或安装包。
- 为基线修复、现代本命补全、现代返照、综合预测时间线、中点、关系推运、地理与周期七个批次定义口径、契约草案、文件落点、测试和验收条件。
- 明确跨批次共享模型、迁移兼容策略、出生时间不确定降级、性能门槛及需要人类确认的产品决策。

## 执行计划

| 阶段 | 状态 | 范围 |
|---|---|---|
| 01 边界与资料复核 | ✅ | 已读取 `AGENTS.md`、当前评估、分支状态与文档索引；确认本轮只改文档 |
| 02 现有实现落点核对 | ✅ | 已核对 mode 分发、Swift 请求/结果、结果页、导出、scan/return/pattern/point-set 可复用路径 |
| 03 共享架构与契约草案 | ✅ | 已定义 point set、chart snapshot、动态事件、return、method/meta、兼容与错误语义 |
| 04 七批详细任务书 | ✅ | 已逐批写明目标、非目标、计算规则、后端/Swift/导出、测试、验收、依赖与风险 |
| 05 文档校验与交付 | ✅ | 已更新索引，检查本地链接/代码围栏/标题层级/空白，并复核 staged 完整 diff；本轮只含 4 个文档文件 |

## 本轮边界

- 文档中的字段名和模块拆分均为施工前确认用的契约草案，不在本轮写入生产代码。
- 已识别的 Composite 与推进月相正确性债务只写修复规格，不在本轮修复。
- 不打包、不覆盖 `/Applications`、不更新版本、不 push。

## 结果

- 新增 1315 行实施蓝图，覆盖七批路线、共享 point set/chart/event 契约、逐批计算与 UI/导出规格、测试矩阵、文件落点、DoD 和 16 项决策登记。
- 明确 Equatorial Ascendant/East Point 与 Antivertex 命名边界；地图只先做方法 spike。
- 未修改任何 Swift/Python/fixture/版本；文档校验通过，未运行会生成缓存的构建或打包。

---

# 现代占星扩展能力评估 — 已完成（2026-07-13）

## 分支

`codex/modern-astrology-expansion-assessment`

## 范围

- 盘点现代占星现有的后端模式、请求/响应契约、Swift 展示、导出与测试覆盖。
- 对照成熟现代占星工作流，识别尚未加入且具有计算、解释或产品价值的技法。
- 按用户价值、复用程度、实现成本、出生时间敏感性与解释争议给出优先级；本轮不修改业务实现、不打包。

## 执行计划

| 阶段 | 状态 | 范围 |
|---|---|---|
| 01 规则与任务边界 | ✅ | 已读取 `AGENTS.md`、仓库状态和历史计划，切出独立评估分支 |
| 02 现有能力盘点 | ✅ | 已核对现代本命、行运/扫描、次限、太阳弧、关系盘、调和盘、展示与导出 |
| 03 技法缺口与资料校准 | ✅ | 已对照 Astrodienst、Solar Fire 与 Swiss Ephemeris 官方资料校准定义与计算原语 |
| 04 可行性与优先级 | ✅ | 已形成 P0–P3 清单、七批推荐顺序、复用点、方法口径与出生时间降级要求 |
| 05 记录与交付 | ✅ | 已新增现代扩展评估文档；45 项现代聚焦回归通过，并以边界探针确认两项基线债务 |

## 结论

- 扩展可行性高，不需要重写当前 Swift→Python JSON 架构。
- 第 0 批先修 Composite 非整宫制必然回退与推进月相无法区分盈亏；本轮按评估任务边界只记录，不修改算法。
- 第一批推荐补齐现代本命结构/轴点/赤纬展示；随后依次做现代返照、综合预测时间线、中点、关系推运和地理/食相周期。

---

# 二轮审计问题全量修复、合并、打包与推送 — 已完成（2026-07-10）

## 分支与交付
- 当前施工分支：`codex/fix-audit-p1-batch`。
- 最终要求：全部审计问题修复并验证；上一批扫描任务与本轮修复拆成清晰提交；合并 `main`；更新版本；打包覆盖 `/Applications/TransitStudio.app`；验证安装包；推送远端。

## 执行计划

| 阶段 | 状态 | 范围 |
|------|------|------|
| A 坐标系与落宫第一批 | ✅ | 时间输入、moment/scan 黄道、同盘去重、Solar Arc、PD 第12宫、固定星 |
| B 吠陀领域计算 | ✅ | 领域修复完成；聚焦回归 137 项通过 |
| C 古典与 Horary | ✅ | 领域修复完成；新增 11 项回归，连同原测试共 145 项通过 |
| D 前端状态与时区 | ✅ | 独立/小数时区、结果与 AI 隔离、Vedic 扫描目标、SA 图形/节点、扫描校验、定位与日期变更线均已修复 |
| E 矫正/进程/契约 | ✅ | rectify 取消/陈旧态/分片流、watchdog、ayanamsha、UTC、mode/DST、fixtures/Harmonic 已完成；API Key 按决策不改 |
| F 完成审计与发布 | ✅ | 已完成 diff 审核、拆分提交、合并、1.3.1 打包覆盖、安装验证、缓存清理与 push |

---

# 二轮审计 P1 静默算错修复（第一批）— 已完成（2026-07-10）

## 分支
`codex/fix-audit-p1-batch`

## 工作树边界
- 上一批 `scan-threshold-cancel` 改动已完成但尚未提交；本轮保留其内容，不回退、不覆盖。
- 本轮先处理可通过现有契约明确修复的坐标系、落宫与同盘去重问题；人物独立时区、半小时区 UI 等需要较大模型迁移的项目放到下一批。
- 提交或推送前，必须把上一批与本轮改动拆成独立提交并复核完整 diff。

## 执行计划

| 项目 | 状态 | 说明 |
|------|------|------|
| 01 读取约束与划清 dirty diff | ✅ | 已复读 `AGENTS.md`，确认上一批 28 个文件的任务边界并新建独立分支 |
| 02 现代 moment 黄道一致性与本命去重 | ✅ | 行星、宫位、Lots、固定星统一 zodiac；本命同盘移除自身/镜像相位与重复赤纬范围 |
| 03 scan 黄道贯通 | ✅ | Swift 请求增加 zodiac；aspect/ingress/station 全链路传递 sidereal |
| 04 Solar Arc 落宫一致性 | ✅ | 推进行星与角点按响应中的推进宫头落宫 |
| 05 Primary Directions 与固定星 | ✅ | 修第 12 宫太阳昼夜判定；固定星支持 sidereal 坐标 |
| 06 前端时间输入显示/解析 | ✅ | `DateTimeInput` 使用当前选择时区，消除系统时区二次解释 |
| 07 回归测试与记录 | ✅ | 聚焦 Python 85、Swift 44 通过；一键门禁 Python 527、Swift 44、四类 smoke 全绿；diff/check 与缓存清理完成 |

---

# 窗口扫描阈值与停止计算 + P1 bug 修复 — 已完成（2026-07-09）

## 分支
`codex/scan-threshold-cancel`

## 用户确认的范围
- 不打包。
- 扫描工作量：1.5M 软警告，2.5M 需确认后计算，5M 绝对上限。
- 增加运行中的停止计算按钮，避免长扫描只能等到 300 秒超时。
- 在本分支已完成的 scan 改动上继续修此前定位的 P1 bugs。

## 执行计划

| 项目 | 状态 | 说明 |
|------|------|------|
| 01 读取约束与现有链路 | ✅ | 已复查 `AGENTS.md`、扫描后端、顶部运行按钮、BackendClient 子进程管理 |
| 02 后端阈值调整 | ✅ | scan 绝对上限提高到 5M；2.5M 以上要求 `confirmedHeavyScan`；1.5M 以上写入 warning |
| 03 前端精确预估与确认 | ✅ | 新增与后端一致的步长/相位精确点估算；1.5M 软提示、2.5M 确认弹窗、5M 前端拦截 |
| 04 停止计算链路 | ✅ | 通用后端计算运行中切换为停止，取消 Swift Task 并终止 Python 子进程；生时矫正仍沿用原进度链路 |
| 05 scan 验证与记录 | ✅ | 已补 CHANGELOG 条目；估算/阈值测试已写 |
| 06 现代 tab 共享状态 | ✅ | `defaultResultTab` + `onChange` 重置 |
| 07 古典 planets 显式 case | ✅ | `case "planets"` 显式渲染行星表 |
| 08 AI 侧滑对齐现代高级 | ✅ | 侧滑接入 5 个现代高级；去掉内嵌 AI tab |
| 09 后端静默回落改 warning | ✅ | Davison/Composite/SA/Panchanga/Ashtakavarga |
| 10 回归验证 | ✅ | pytest 相关 69+27 通过；`swift build` + `swift test` 38 通过；未打包 |
| 11 评审修复 | ✅ | run generation 防停止竞态；Panchanga 失败路径测试 |
| 12 评审修复：重算全盘可停 | ✅ | `startTrackedRun` + `canStop` 需 tracked task |
| 13 评审修复：可停性跟任务 | ✅ | `currentRunIsStoppable` 启动时捕获，不跟当前页面 mode |

---

# 窗口扫描超量报错定位 — 已完成（2026-07-08）

## 分支
`main`

## 执行计划

| 项目 | 状态 | 说明 |
|------|------|------|
| 01 读取项目约束与当前计划 | ✅ | 已读取 `AGENTS.md`、`PLANS.md`、`CHANGELOG.md`，确认本轮先做定位不改计算规则 |
| 02 定位 scan 报错来源 | ✅ | 已确认错误来自 `astro_backend_scan.py` 的 `reject_oversized_scan()` 上限保护，而非 Python 进程崩溃 |
| 03 回溯前端请求与触发条件 | ✅ | 已确认前端把扫描窗口、行运体、目标点、相位原样送入后端；超量由 `steps × targets × exact-aspects` 组合触发 |
| 04 输出结论与后续建议 | ✅ | 本轮回复将给出触发公式、截图对应的量级含义，以及可选修复方向 |

---

# 前端重设计 2026-07（观星台布局 + Dark Mode）— 已完成（2026-07-07）

## 分支
`codex/frontend-redesign-2026-07`（任务书在 `main` 上，施工在该分支）

## 用户确认的范围
- 重点：古典排盘、Horary、行运扫描；吠陀只保证不回归，不做新视图。
- 配色：羊皮纸保留为浅色主题，深空夜色做成 Dark Mode（程序设置可选 跟随系统/浅色/深色）。

## 执行计划

| 项目 | 状态 | 说明 |
|------|------|------|
| 01 设计方案与用户确认 | ✅ | 布局：档案胶囊+流派+运行按钮上顶栏、参数抽屉自动收起、结果区垂直目录、扫描时间轴、AI 侧滑 |
| 02 任务书 00/01/02 + 交接提示词 | ✅ | `docs/frontend-redesign-2026-07/`（00 总览、01 Dark Mode、02 顶栏布局、HANDOFF_PROMPT） |
| 03 第 1 期施工（Dark Mode，1.2.0/36） | ✅ | 施工完成，等待验收。门禁 check_vibe_changes.sh 全绿，版本 1.2.0/36 |
| 04 第 1 期验收 | ✅ | diff 与任务书逐项一致（strongLineGray 用 inkSoft 引用属等价实现）；门禁复跑全绿 |
| 05 第 2 期施工（顶栏布局，1.2.1/37） | ✅ | 施工完成，等待验收。门禁全绿，版本 1.2.1/37 |
| 06 第 2 期验收 | ✅ | 唯一偏离（档案胶囊摘要误用编辑态数据）已由评审模型修正并复建通过；待手测深色下星盘图即时刷新 |
| 07 第 3–5 期（垂直目录/扫描时间轴/AI 侧滑） | ✅ | 用户改为让评审模型直接施工，三期合并一笔完成（1.2.2/38）：古典/Horary 垂直目录、扫描时间轴（含表格切换）、AI 全局侧滑面板、星盘图外观切换兜底 |
| 08 合并 main + 打包覆盖 /Applications | ✅ | 门禁全绿（Python 512 / Swift 33 / 4 smoke）；main 快进合并；安装版 `1.2.2 (38)`，codesign 通过、无 pyc、安装后端 classical smoke 通过 |
| 09 第 6 期打磨（1.2.3/39） | ✅ | 用户反馈"细节不够打磨"后，用真机截图定位：焦点环/分段器拉伸/按钮截断/表格空斑马纹/双标题冗余/时间轴标签裁切/启动不载入档案等 10 项，逐项修复；浅色+深色截图核对 |

---

# 代码审计续查 — 已完成（2026-07-06）

## 分支
`codex/fix-modern-timebased-contract`

## 执行计划

| 项目 | 状态 | 说明 |
|------|------|------|
| 01 核对规则与当前改动边界 | ✅ | 已读取 `AGENTS.md`；当前仅有上一轮文档改动 |
| 02 复查现代时基模式请求契约 | ✅ | 已确认 progression / solar_arc / harmonic UI 请求不传顶层 zodiac/house_system，后端忽略 birth 内设置 |
| 03 扫描结果页 tab / section_errors 风险 | ✅ | 已确认 tab case 基本对应；现代高级诊断页多为 Raw JSON，harmonic 无诊断页 |
| 04 扫描后端 silent fallback 高风险点 | ✅ | 已记录 silent fallback 审计策略，并补充次限整点出生误报 warning |
| 05 输出代码审计结论 | ✅ | 已更新审计文档，并将在本轮回复按严重度列 findings、复现依据、建议验证 |
| 06 修复并补回归 | ✅ | 已修现代时基请求契约、次限整点 warning、现代诊断页，并补 Python/Swift 回归 |
| 07 验证与打包覆盖 | ✅ | Python 492、Swift 27、一键门禁通过；已打包覆盖 `/Applications` 为 `1.1.13 (33)`，签名/无 pyc/安装后端 smoke 通过 |

---

# 文档整理与技术债审计 — 已完成（2026-07-06）

## 分支
`main`

## 执行计划

| 项目 | 状态 | 说明 |
|------|------|------|
| 01 核对项目规则与仓库状态 | ✅ | 已读取 `AGENTS.md`；当前 `main` 领先 `origin/main` 15 个提交 |
| 02 梳理文档目录与源/生成边界 | ✅ | 已扫描 tracked 文件、source-of-truth、生成产物与历史文档 |
| 03 汇总技术债与历史遗留 bug | ✅ | 已汇总文档已知债务、历史 bug 主题、占位实现与契约风险 |
| 04 记录潜在未发现 bug 风险 | ✅ | 已记录异常吞噬、占位实现、schema 漂移、测试空白与现代时基模式契约风险 |
| 05 补全文档与下一步建议 | ✅ | 已更新 docs/README 与 validation，新增 `docs/project-audit-2026-07-06.md` 并记录演进路线 |

---

# main 合并后打包覆盖 /Applications — 已完成（2026-07-02）

## 分支
`main`

## 执行计划

| 项目 | 状态 | 说明 |
|------|------|------|
| 01 核对当前状态 | ✅ | 工作区干净；`package_app.sh` 版本为 `1.1.12 (32)` |
| 02 执行打包覆盖 | ✅ | 已运行 `./package_app.sh`，覆盖 `/Applications/TransitStudio.app` |
| 03 验证安装产物 | ✅ | 安装版 `1.1.12 (32)`；codesign 通过；无 `.pyc`/`__pycache__`；AppIcon 与仓库文件一致；classical smoke 通过 |

---

# 合并 expansion-002 与 Claude 图标优化入 main — 已完成（2026-07-02）

## 分支
- 当前分支：`codex/expansion-002`
- 额外合并分支：`claude/confident-leavitt-08051a`
- 目标分支：`main`

## 执行计划

| 项目 | 状态 | 说明 |
|------|------|------|
| 01 核对分支与工作区 | ✅ | 当前工作区干净；`main` 在 `4aa7b68`，两个待合并分支均存在 |
| 02 预判冲突面 | ✅ | 已确认 `CHANGELOG.md`、`PLANS.md`、`package_app.sh` 会在第二次合并时需要重点核对 |
| 03 合并当前分支到 main | ✅ | `main` 已快进合并 `codex/expansion-002`，包含本地计划提交 `9ec9d80` |
| 04 合并 Claude 分支到 main | ✅ | 已保留最新版本号 `1.1.12 (32)`，并叠加 AppIcon 预生成优化 |
| 05 验证结果 | ✅ | `PATH=/usr/local/bin:$PATH bash check_vibe_changes.sh` 通过：486 Python、Swift build/test、5 个 smoke |

---

# 打包脚本图标预生成 — 已完成（2026-07-02）

## 分支

`claude/confident-leavitt-08051a`（worktree）

## 背景

`package_app.sh` 每次打包都用纯 Python 逐像素重新生成 10 张完全相同的 PNG（最大 1024×1024，纯 CPython 需 1–2 分钟），且依赖 PATH 上的 python3。曾导致外部修复 Agent 在此步骤卡死超时（iconset 目录为空）。

## 执行计划

| 项目 | 状态 | 说明 |
|------|------|------|
| 01 一次性生成 AppIcon.icns 并提交到 `assets/` | ✅ | 用现有生成逻辑产出，`iconutil` 打包为 icns |
| 02 `package_app.sh` 优先拷贝已提交的 icns | ✅ | 仅当 `assets/AppIcon.icns` 缺失时回退到原生成逻辑 |
| 03 `SKIP_INSTALL=1 ./package_app.sh` 验证产物 | ✅ | 确认 app 内 AppIcon.icns 正常且与提交文件一致 |

---

# Expansion 002 代码评审修复（F1-F5）— 已完成（2026-07-02）

## 分支
`codex/expansion-002`

## 执行计划

| 项目 | 状态 | 说明 |
|------|------|------|
| F1 magistery 公式文本修复 | ✅ | 5 处代码修改 + 2 个回归测试，昼/夜公式文本正确显示 MC |
| F2 lots 容错（KeyError 守卫） | ✅ | 加 warnings 参数 + try/except KeyError + 2 调用方补传 + 4 个回归测试 |
| F3 宫位标签边界守卫 | ✅ | 引入 _HOUSE_LABELS + 守卫式取值 + 3 个回归测试 |
| F4 删除死代码 | ✅ | 删除 4 个函数 + 清理 BODY_REGISTRY import，零回归 |
| F5 fixed_stars 复用 core 工具 | ✅ | import + 2 处替换，恒星测试全绿 |
| 门禁验证 | ✅ | 聚焦 45 通过、全量 Python 486 通过、Swift 24 通过、5 个后端 smoke 通过 |
| 记录与打包 | ✅ | CHANGELOG.md/PLANS.md 已更新，版本号 1.1.12 (32) |

---

# Firdaria 主流算法接轨 — 已完成（2026-07-01）

## 分支
`codex/expansion-002`

## 执行计划

| 项目 | 状态 | 说明 |
|------|------|------|
| 01 核对主流口径 | ✅ | 已对照本地 Sira Uysal Firdaria PDF：主限昼/夜序列、七曜次限从主限星开始、七等分，交点不拆次限 |
| 02 修正后端算法 | ✅ | `firdaria_sub_periods()` 已改为七曜 7 等分、主限星起始、交点不拆次限 |
| 03 补回归与记录 | ✅ | 已更新 Python 测试、`CHANGELOG.md` 与打包版本 `1.1.11 (31)` |
| 04 验证与打包 | ✅ | 全量 Python、Swift build/test、后端 smokes 均通过；已覆盖 `/Applications/TransitStudio.app` 为 `1.1.11 (31)` |

---

# Expansion 002 Markdown 数据补全与打包覆盖 — 已完成（2026-07-01）

## 分支
`codex/expansion-002`

## 执行计划

| 项目 | 状态 | 说明 |
|------|------|------|
| 01 确认导出缺口 | ✅ | 已确认后端/Codable 有赤纬、固定星与 medieval 数据，但 Markdown 导出未渲染 |
| 02 补齐 Markdown 渲染 | ✅ | 增加赤纬/OOB、赤纬相位、固定星合相、中世纪深化章节，并修正 packaged ephemeris 默认路径与 pycache 签名污染 |
| 03 补测试与记录 | ✅ | 增加 Markdown 导出与 packaged ephemeris path 回归测试，更新 `CHANGELOG.md` |
| 04 运行验证 | ✅ | pycache 签名污染修复后 `swift test` 与 `check_vibe_changes.sh` 均通过 |
| 05 打包覆盖 `/Applications` | ✅ | 已覆盖 `/Applications/TransitStudio.app`，安装版本 `1.1.10 (30)`；codesign、无 pycache、installed backend smoke 均通过 |

---

# Expansion 002 复查与打包覆盖 — 已完成（2026-07-01）

## 分支
`codex/expansion-002`

## 执行计划

| 项目 | 状态 | 说明 |
|------|------|------|
| 01 最新提交与工作区核对 | ✅ | 当前 HEAD 为 `85ac41f` 起继续复查，工作区仅本轮计划/修补改动 |
| 02 复查新增修复 | ✅ | 已修固定星名称/warning、cross 赤纬生成、Swift 前缀过滤与 backend 默认 ephemeris path |
| 03 运行本地门禁 | ✅ | focused pytest、全量 pytest、`swift build`、`swift test`、`check_vibe_changes.sh` 均通过 |
| 04 无阻断问题后打包覆盖 | ✅ | `package_app.sh` 版本递增到 `1.1.9 (29)` 并覆盖 `/Applications/TransitStudio.app` |
| 05 记录结果 | ✅ | `CHANGELOG.md` 已记录，安装产物 Info.plist 与 codesign 已验证 |

---

# Expansion 002: 恒星与赤纬 + 中世纪技法深化 — 规划中（2026-07-01）

## 状态
✅ 全部 Phase 已完成（编码 + 测试）

## 计算规范核对修订（2026-07-01）

| 项目 | 状态 | 说明 |
|------|------|------|
| 01 核对联网资料与本地接口 | ✅ | 已确认 Swiss Ephemeris 固定星接口、`FLG_EQUATORIAL`、黄道/赤道转换与 OOB 判定口径 |
| 02 修正文档计算方式 | ✅ | 修正赤纬公式、OOB 示例、固定星调用、恒星合相入相判定与中世纪技法实现边界 |
| 03 复核 diff 与记录 | ✅ | 核对文档差异，补充 CHANGELOG 记录 |

## 分支
`codex/expansion-002`（已完成）

## 执行计划

### Phase 1：恒星与赤纬

| 项目 | 状态 | 说明 |
|------|------|------|
| 1.1 赤纬管线 | ✅ | `calculate_body()` 增加 declination / out_of_bounds 字段 |
| 1.2 平行/反平行 | ✅ | `astro_backend_core.py` 新增 `find_declination_aspects()` |
| 1.3 恒星模块 | ✅ | 新建 `astro_backend_fixed_stars.py`，30 颗恒星合相检测 |
| 1.4 Swift 模型 | ✅ | `PositionRow` 扩展 + `FixedStarConjunction` / `DeclinationAspect` |
| 1.6 测试 | ✅ | 赤纬验算、出界、平行/反平行、恒星合相单元测试已添加 |

### Phase 2：中世纪技法深化

| 项目 | 状态 | 说明 |
|------|------|------|
| 2.1 阿拉伯点扩展 | ✅ | 12 → 56 点 |
| 2.2 三分主星序列 | ✅ | Sect light 三分主星 + ASC 三分主星 |
| 2.3 Kurios / Oikodespotes | ✅ | 综合权重判定盘主星 |
| 2.4 年主+日返融合 | ✅ | 返照 ASC vs 小限 + 年主在返照盘的状态 + 机器摘要 |
| 2.5 月小限增强 | 🔲 | 推迟（前端改动为主） |
| 2.6 界推进深化 | 🔲 | 推迟（前端改动为主） |
| 2.7 测试 | ✅ | 10 个中世纪技法单元测试已添加 |
| 2.2 三分主星序列 | ⬜ | Sect light 三分主星 + ASC 三分主星 |
| 2.3 Kurios / Oikodespotes | ⬜ | 综合权重判定盘主星 |
| 2.4 年主+日返融合 | ⬜ | 返照 ASC vs 小限 + 年主在返照盘的状态 + 机器摘要 |
| 2.5 月小限增强 | ⬜ | 月主条件 + 当月行运触发 |
| 2.6 界推进深化 | ⬜ | 当前界主突出 + 与其他技法交叉标注 |
| 2.7 测试 | ⬜ | 扩展阿拉伯点、三分主星、Kurios、日返融合回归测试 |

## 详细文档
见 `docs/expansion-002/`

---


# 审计确认问题修复 — 已完成（2026-07-01）

## 分支
`codex/fix-audit-bugs`

## 执行计划

| 项目 | 状态 | 说明 |
|------|------|------|
| 01 建立任务边界 | ✅ | 已切到 `codex/fix-audit-bugs`，忽略无关未跟踪 OCR Markdown |
| 02 修复 P0/P1 计算错误 | ✅ | 已修复关系页映射、Bhava 角点、Primary Directions 纬度、T-square、Ashtottari、月小限 |
| 03 修复 P2/P3/P4 边界问题 | ✅ | 已修复 Arudha 对宫例外、Jaimini Rahu 逆算、超时文案、定位新鲜度/精度、非法 JSON |
| 04 补回归测试与记录 | ✅ | 已新增 focused pytest 回归，更新 `CHANGELOG.md` |
| 05 运行门禁并复核 diff | ✅ | targeted pytest、`swift build`、`swift test`、一键门禁和单独 rectify smoke 已通过 |

# 审计问题真实性核验 — 已完成（2026-07-01）

## 执行计划

| 项目 | 状态 | 说明 |
|------|------|------|
| 01 记录工作区边界 | ✅ | 当前在 `main`，仅有一个未跟踪 OCR Markdown，与本轮核验无关 |
| 02 读取前端/后端目标实现 | ✅ | 已对照用户列出的 11 个位置与实际数据契约、调用路径 |
| 03 判断真实性与影响面 | ✅ | 已将每项标记为真实/部分真实/需口径确认，并记录源码与最小复现依据 |
| 04 形成修复优先级建议 | ✅ | 本轮不改业务代码，只输出后续修复与验证建议 |

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

# AI 思考过程截断修复与打包 — 已完成（2026-06-10）

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
- LLM API key 迁 Keychain（用户明确否决并要求长期保留 UserDefaults；见 `docs/product-decisions.md`）；后端 60 秒硬超时调整

---

# 文档同步 — 已完成（2026-06-10）

## 执行计划

| 项目 | 状态 | 说明 |
|------|------|------|
| 01 PLANS.md 归档与补记 | ✅ | 旧批次移入 docs/archive，本轮任务补记 |
| 02 project-structure.md | ✅ | 同步拆分后的文件结构、状态对象、Fixtures、CI |
| 03 validation.md | ✅ | 补 BackendContractTests、fixture 再生成、CI、check_vibe |
| 04 AGENTS.md | ✅ | 验证清单与 Source of Truth 更新，新增 AI 流式与 tab 约定 |

---

# 现代占星扩展实际施工 — 第 0 批（2026-07-13）

## 分支

`codex/fix-modern-baseline-correctness`（从已推送的 `main` 新建）

## 已确认的产品边界

- D02：原则上不接受模糊出生时间输入；本轮不新增 `time_accuracy`，不引入 unknown/approximate 的静默降级路径。
- 现代扩展继续要求明确出生日期、时间、时区和地点；后续依赖角点/宫位的功能不得假装支持模糊生时。
- 当前先完成第 0 批基线正确性修复；D05、D10、D12 在各自批次前逐次确认。

## 七批工作拆分与依赖

| 批次 | 具体工作 | 前置 | 并行安排 |
|---|---|---|---|
| 0 | B0-01 Composite 非整宫 unpack/fallback 回归；B0-02 推进月相有向周期角修复 | 无 | 两项分属不同后端模块，可由两个 sub-agent 并行；主 Agent 负责契约复核、整合和门禁 |
| 1 | shared point set/chart snapshot、Vertex/East Point/Antivertex、结构统计、赤纬/OOB、Synastry 高级点集、六个高级现代 mode 的 optional point set、Swift 展示与三种导出 | 0、D02 | 后端共享 helper、Swift 模型/结果页、测试/fixture 可在接口稳定后并行；不得先猜字段 |
| 2 | Solar/Lunar Return、地点与 exact solver、Return snapshot/overlay、Swift 与导出 | 0、1；D05 | solver、现代 Return 后端契约、Swift pane/导出可分工；古典 schema 回归独立验证 |
| 3 | 独立 `modern_timing`、Transit/Progression/Solar Arc adapter、lifecycle、多次命中、估算/取消、timeline UI/导出 | 0、1 | technique adapter、事件模型/UI、性能与取消测试可并行；共用动态事件契约后整合 |
| 4 | 360° midpoint axis/tree、静态激活、对时间线 target 的接入和导出 | 1、3 | midpoint 数学/后端与 UI/导出可并行；事件引擎接入必须等第 3 批契约 |
| 5A | Transit→Composite/Davison、`progressed_composite` 行星/相位与独立 submode | 0、1、3 | 关系 target adapter 与 progressed composite 可并行；不实现 5B 争议方法 |
| 5B | Progression/SA→Composite/Davison、关系盘角点/宫位变体、Davison reference place | D10、D12 确认 | 暂不施工 |
| 6A | Relocation：同一 birth UTC、重算地点宫位/角点、overlay、导出 | 1 | 可独立于 6B；地图不与本批混做 |
| 6B | 朔望/日月食 exact 周期、global/local visibility、可选本命点 contacts | 1；可选接 3 | 周期计算与独立导出可并行；接入 timing 需等第 3 批 |
| 6C | A*C*G/Local Space 方法 spike、Swiss binding/MapKit 验证，之后再定正式 API | 方法 spike；不阻塞 6A/6B | 独立 epic，先只读验证 |

## 第 0 批执行计划

| 阶段 | 状态 | 范围 |
|---|---|---|
| 01 分支与计划 | ✅ | 当前分支已从已推送的 `main` 新建；本计划已写入 |
| 02 现状核对 | ✅ | 已核对实现、所有 `build_houses()` 调用点、入口校验、现代测试和 sample |
| 03 B0-01 Composite 修复 | ✅ | 按 `(cusps, angles, system_label)` 接收 `build_houses()`；保持当前 MC-shift 方法，不重定义宫位算法 |
| 04 B0-02 推进月相修复 | ✅ | 使用有向 `Moon - Sun` 周期角选择八相；保留旧字段语义 |
| 05 聚焦与跨模式验证 | ✅ | 现代关系/时基 52 项、全量 Python 587 项、Swift 50 项、六个 modern sample 与项目 smoke 全部通过 |
| 06 记录与交付 | ✅ | `CHANGELOG.md` 已同步；完整 diff/stat 已复核；`.build`、pytest cache、`__pycache__`、`.pyc` 已清理；本批不打包、不 push |

## 第 0 批验收口径

- Composite Placidus/Equal/Porphyry 不再因 unpack 错误进入 fallback；真实 fallback 仍显式 warning；Whole Sign 不漂移。
- 推进月相正确区分 0/45/90/135/180/225/270/315°，跨 0° 采用圆周距离；现有 `sun_moon_separation` 和字段兼容。
- 不改变古典 `planetary_returns`、Horary、Vedic、现有 `scan` 契约；不新增现代功能字段。
- 聚焦测试、必要跨模式测试和 `bash check_vibe_changes.sh` 通过；生成的 `.build`、pytest cache、`__pycache__`、`.pyc` 清理。

---

# 现代占星扩展实际施工 — 第 1 批（2026-07-13）

## 分支

`codex/feature-modern-completeness`（从已推送的 B0 `main` 新建）

## 已确认边界

- D02 已确认：不接受模糊出生时间；现代请求继续要求完整出生 moment，B1 不新增 `time_accuracy` 或 noon convention。
- 本批只做现代完整性、共享 point set/chart snapshot、轴点、结构层、赤纬/OOB 和关系点集；不做 Return、动态时间线、中点、Relocation、食相或 AI。
- 现有 `mode=moment` 与六个高级现代 mode 的旧默认点集必须保持兼容；新增字段优先 optional。

## 具体工作与并行边界

| 工作包 | 内容 | 主要写集 | 依赖 |
|---|---|---|---|
| 1A 共享 point set | `astro_backend_modern_points.py`、共享 chart snapshot、请求校验/effective point set、custom asteroid 与 node 兼容 | 新 helper + API 小范围接入 | 先完成现状查询 |
| 1B 轴点与现代本命 | Vertex、Antivertex、Equatorial Ascendant/East Point；sameChart structure/chart_profile、patterns、declination/OOB | ephemeris/patterns/moment backend + Python tests | 1A 契约稳定后 |
| 1C 高级现代点集 | Synastry 跨盘轴点/赤纬；Progression/Solar Arc/Harmonic/Composite/Davison optional point set | 现有六个 mode backend + focused tests | 1A |
| 1D Swift 契约与 UI | Request/Result models、run action、sidebar/state、tabs、现代本命/关系结果页 | Swift modern/request/result/sidebar/results/export | 1A/1B JSON 形状稳定后 |
| 1E 导出与 fixture | Markdown/CSV/JSON、真实 backend fixtures、contract/tab/export tests、Examples | export/tests/fixtures | 1B/1D |

1A 与 1B/1C 的纯查询和部分实现可并行；涉及同一个 API dispatch 或共享模型的修改必须由主 Agent 统一整合。1D 不在后端契约未确认前猜字段。1E 在真实响应稳定后执行。

## B1 执行状态

| 阶段 | 状态 | 说明 |
|---|---|---|
| 01 分支与计划 | ✅ | 已从包含 B0 的 `main` 新建；本计划已写入 |
| 02 现状与调用点查询 | ✅ | 已核对后端点集/轴点、Swift 链路和 fixture/测试 |
| 03 共享 point set/chart snapshot | ✅ | 新增共享解析/校验与 `effective_point_set`；复用现有 registry、positions/houses 入口 |
| 04 现代本命结构/轴点/赤纬 | ✅ | 完成本命 `chart_profile`、patterns、轴点、赤纬/OOB 与固定星结果入口；D02 无降级 |
| 05 高级现代 mode 点集迁移 | ✅ | Synastry、Composite、Davison、Progression、Solar Arc、Harmonic 支持 optional point set，旧默认保持 |
| 06 Swift 展示、导出、fixture | ✅ | 新增请求/结果字段、结构/赤纬/固定星/关系赤纬 tab，三种导出和六个真实 fixture 已同步 |
| 07 门禁与交付 | ✅ | 聚焦与全量门禁通过；Python 634、Swift 52、六个 modern smoke 已通过；缓存清理、diff 复核与 B1 提交均已完成 |

## B1 验收口径

- `effective_point_set` 与结构、图形、相位实际使用的 subset 一致；unknown body/angle/node 冲突返回 validation error，不静默忽略。
- Vertex/East Point 与 Swiss `ascmc[3]/[4]` 在容差内一致；Antivertex 为 Vertex 对点；非 finite/高纬 fallback 写 warning 并移除有效点。
- 现代本命 structure/chart_profile 默认只统计十大行星；隐藏 Chiron/小行星后不得污染统计或图形；可靠出生时间以外不做降级分支。
- declination position、OOB、declination aspects 分区输出；declination orb 独立默认 1°；Synastry 跨盘 ID 不歧义。
- 现有 moment/synastry/composite/davison/progression/solar_arc/harmonic 默认 sample 与旧 schema 不漂移。
- Swift 默认 tab、每个 tab case、Markdown/CSV/JSON、真实 fixture 和 `BackendContractTests` 同批通过；不接 AI。

---

# 现代占星扩展实际施工 — 第 2 批 Return（2026-07-13）

## 分支与边界

- 继续在 `codex/feature-modern-completeness` 上按独立提交推进；B1 已提交，B2 不回改已确认的 point-set 语义。
- 新增独立 `mode=modern_return`，只开放 `return_body_id=SUN|MOON`；不扩展 Mercury/Venus/Mars/Jupiter/Saturn Return。
- D02 继续生效：birth/reference/location timezone 必须是完整、明确的 exact moment/地点；不增加 approximate/unknown/noon convention。
- `precession_correction` v1 只允许 `none`；地点只改变返照 snapshot 的角点/宫位，不改变 exact UTC。

## 工作包与写集

| 工作包 | 内容 | 写集 | 状态 |
|---|---|---|---|
| 2A solver/backend | UTC 精确求根、previous/current/next、现代 snapshot、return→natal、house overlay、effective point set | 新 `astro_backend_modern_return.py` + Python tests | ✅ |
| 2B Swift 契约/UI | Request/Result、ModernSubMode、运行入口、sidebar、tabs、Markdown/CSV/JSON | Swift modern/request/result/pane/export 文件 | ✅ |
| 2C API/Examples | mode 注册、结构化校验、两个 sample、真实 fixture、contract tests | API、Examples、Fixtures、Swift tests | ✅ |
| 2D 门禁 | exact longitude、地点不改 UTC、DST local offset、古典回归、全量 gate、缓存清理 | PLANS/CHANGELOG/验证输出 | ✅ |

## B2 验收口径

- Solar target 与 natal Sun exact longitude error ≤ 1e-5°；Lunar previous/current/next 时间严格排序，current 为 reference 前最近命中、next 为其后首个命中。
- 同一请求只切换返照地点时 exact UTC 与行星黄经不变，角点/宫位可变；local ISO 保留 timezone offset。
- tropical/sidereal、DST、本地地点、invalid body/location/timezone/precession 均有测试；无命中返回 null occurrence + warning/suggested window，不伪造空盘。
- Swift 默认 tab 有明确 list/case；Return occurrence、exact UTC/local、house system、误差和地点在 Markdown/CSV/JSON 中可复核。

---

# 现代占星扩展实际施工 — 第 3 批 Modern Timing（2026-07-13）

## 分支与边界

- 继续在 `codex/feature-modern-completeness` 上形成独立 B3 commit；B2 已提交为 `d2a9644`。
- 新增独立 `mode=modern_timing` 与事件合同，不改变旧 `mode=scan`、`ScanHit`、Examples 或阈值语义。
- D02 继续生效：birth/start/end/display timezone 均要求完整明确时间，不增加模糊生时降级。
- v1 注册 Transit→Natal aspect、Transit ingress/station、Secondary Progression→Natal aspect、Progressed Moon ingress/lunation、Solar Arc→Natal aspect；Return/食相后续注册。
- 每个 technique 自带 aspects/orb；第一版不接 AI。

## 工作包与并行边界

| 工作包 | 内容 | 写集 | 状态 |
|---|---|---|---|
| 3A 事件核心 | TargetPoint、adapter、UTC bracket/refine、entering/exact/leaving、clipped、多 pass、dedupe | 新 `astro_backend_modern_timing.py` + focused tests | ✅ |
| 3B Technique adapters | Transit、secondary progression、solar arc；复用既有 progression/solar arc 方法 | timing 模块 + 既有 helper 的只读复用 | ✅ |
| 3C API/估算/进度 | mode 校验、work units、1.5M/2.5M/5M 阈值、stderr progress、Examples/fixture | API/timing/client | ✅ |
| 3D Swift/UI/导出 | request/result、独立 submode、sidebar、timeline/grouped/calendar、filters、CSV/Markdown/JSON | Swift modern/result/export 文件 | ✅ |
| 3E 验收 | Python/Swift contract、旧 scan 不漂移、取消/迟到结果、完整 gate、缓存清理与提交 | tests/PLANS/CHANGELOG | ✅ |

## B3 当前验证记录

- `python_tests/test_modern_timing.py`：34 passed；Timing + 旧 Scan +现代 timebased 联合回归：98 passed。
- 全量 `python_tests/`：668 passed；classical/moment/scan/horary/vedic/harmonic/rectify/modern_timing 入口 smoke 均通过。
- `swift build`、`swift build --build-tests` 与 `swift test` 通过；Swift 共 65 tests / 17 suites，包含真实 fixture、导出、tab、estimator 和 stale generation 契约。
- 真实一年 fixture 返回 Transit / Secondary Progression / Solar Arc 三种来源、34 条事件、5 条合法边界截断；`technique_configs` 与 Example 完全一致，estimated work units 为 152244。
- `bash check_vibe_changes.sh` 完整门禁通过：Python 668、Swift 65、classical/moment/scan/horary/vedic/harmonic/rectify smokes 全部成功。

## B3 验收口径

- 每个 aspect event 表示完整 pass，entering/exact/leaving 由独立根求得；边界截断使用 `null + clipped`，不伪造边界时间。
- 0°/180° 单分支和 60/90/120/150° 双分支均可复算；逆行多次命中按稳定 group/index/count 呈现。
- Progression 与 Solar Arc adapter 在同 reference 与单点模式位置一致；Transit ingress/station 不重复。
- estimator 前后端同口径，2.5M 要确认、5M 拒绝；进度/取消复用现有子进程与 generation 保护。
- timeline/grouped/calendar 的 tab list 与 case 齐全；事件专用 Markdown/CSV/JSON 和真实 fixture/contract tests 同批交付。

---

# 现代占星扩展实际施工 — 第 4 批 Midpoints v1（2026-07-13）

## 分支与边界

- 继续在 `codex/feature-modern-completeness` 上形成独立 B4 commit；B3 已提交为 `52f2069`。
- 新增独立 `mode=midpoint`，只实现 360° natal midpoint axis、focus tree 与 reference snapshot activation；不实现 hypothetical planets、midpoint-to-midpoint、45°/90° dial 或自动解释。
- D02 继续生效：birth/reference 均要求完整明确时间；没有 reference 时只返回 axes 与 natal trees，动态 activation 必须为空。
- 每个无序点对只生成一个稳定 `axis_id=midpoint|A|B`；direct/opposite 是同一轴的两个 branch，不复制成两个业务轴。
- B3 时间线只接收用户明确选择的 midpoint pairs；后端根据 pair point IDs 与 natal snapshot 权威重算轴，不信任客户端传入经度，也不默认选择全部轴。

## 工作包与并行边界

| 工作包 | 内容 | 写集 | 状态 |
|---|---|---|---|
| 4A midpoint 核心 | canonical pair、circular midpoint、direct/opposite axis、focus tree、四类 snapshot activation、请求校验 | 新 `astro_backend_midpoints.py` + focused Python tests | ✅；真实 sample 15 axes / 4 trees / 9 activations |
| 4B Timing 接入 | `target_point_set.midpoint_pairs`、两 branch 展开、稳定 axis ID、`target_axis_branch`、估算与事件分组 | `astro_backend_modern_timing.py`、共享 point-set/Swift timing models + tests | ✅；含 pair-only 真实 fixture 与预填 |
| 4C API/fixture | mode 注册、sample、真实 backend fixture、contract tests | API、Examples、SwiftTests/Fixtures | ✅；standalone + timing midpoint fixtures |
| 4D Swift/UI/导出 | ModernSubMode、请求/结果、sidebar、axes/trees/activations tabs、时间线预填、Markdown/CSV/JSON | Swift modern/result/export 文件 + tests | ✅；Swift 74 tests / 18 suites |
| 4E 验收 | 边界数学、pair 去重、point-set 缩减、时间线 branch/event、旧模式回归、完整 gate、缓存清理与独立提交 | tests/PLANS/CHANGELOG | ✅；待独立 commit |

## B4 最终验证记录

- Midpoint + Timing-midpoint + 旧 Timing + constants 聚焦 Python：74 passed；全量 Python：702 passed。
- Swift 全量：74 tests / 18 suites；真实 standalone midpoint 与 pair-only Timing fixtures、tabs、导出、estimator、branch-aware IDs 与审查修复全部通过。
- `bash check_vibe_changes.sh` 完整门禁通过；classical/moment/scan/horary/vedic/harmonic、Solar/Lunar Return、Modern Timing、Midpoint、pair-only Timing、Rectify smokes 全部成功。
- `.build`、所有 pytest cache、`__pycache__`、`.pyc`、`.pyo` 已清理；B4 未打包、不安装应用。
- 提交前完整 diff 审查补齐 axis `trace.input_longitudes`，让 10°/190° 对径 tie-break 可从 backend JSON 与 Swift JSON 导出复算；重生成 midpoint fixture 后重新执行门禁。
- 独立后端审查补齐含 pair 时所有“省略的普通 selector 视为空”的默认语义、嵌套 `point_set.node_mode` 校验优先级，以及 activation source 单项失败不影响其余来源的回归；90° 对 direct/opposite 的同时命中按 branch 事实契约保留。
- 独立 Swift 审查补齐 Timing UI branch、Markdown event ID、普通请求省略空 `midpoint_pairs`、预填后清空 stale Timing result，以及重复 axis ID 下 CSV 安全降级；全部纳入重新执行的 Swift/全量门禁。

## B4 接口落实口径

- `mode=midpoint` 的 `modulus` 只接受 `360`；`activation_orb` 独立默认 `1°`，不得复用普通相位 orb。
- `point_set` 决定可参与配对与 activation 的点；N 个有效点必须恰好返回 `N*(N-1)/2` 个轴，A=B、重复 pair 与输入顺序不得产生重复轴。
- 轴经度使用现有 `circular_midpoint()`：`m1` 为 circular midpoint，`m2=norm360(m1+180)`；10°/190° 的歧义边界沿现有 helper 的确定性结果并由测试锁定。
- B3 `target_point_set.midpoint_pairs` 使用 `{point_a_id, point_b_id}`；后端 canonicalize 后从 birth snapshot 解算 direct/opposite 两个 TargetPoint，事件保持同一 `target_point_id`，另以 `target_axis_branch=direct|opposite` 区分。
- Swift 默认 midpoint selection 为空；用户可从 axes/focus/manual 明确选择并预填 Modern Timing，estimator 按实际展开的 branch 数量计数。

## B4 验收口径

- 350°/10° 返回 direct=0°、opposite=180°；10°/190°、0°边界、direct/opposite 命中均有聚焦测试。
- 无序 pair canonical ID、pair 数量、point-set 缩减、无 reference 行为、四类 activation source 与 orb 独立性均可由真实输出复核。
- Timing midpoint target 的估算、event/group ID、branch 字段及 CSV/Markdown/JSON 可复算；普通 natal target 与旧 `scan` 契约不漂移。
- Swift axes 支持 A/B 搜索与度数排序，trees 可切 focus，activations 展示 source/reference；tabs 列表与 switch case 一致。
- 聚焦测试、全量 `bash check_vibe_changes.sh`、backend smoke、完整 diff 审查与缓存清理通过后再独立提交 B4。

---

# 现代占星扩展实际施工 — 第 5A 批关系动态（2026-07-13）

## 分支、决策与非目标

- 继续在 `codex/feature-modern-completeness` 上形成独立 B5A commit；B4 已提交为 `bd8ed51`。
- 只施工蓝图 5A：Transit→Composite/Davison 与 `progress_each_person_then_midpoint` 的 Progressed Composite；5B 的 SA/Progression→关系盘、推进关系盘宫位/角点、Composite method variants 与 Davison reference-place 变体全部排除。
- D02 按用户确认执行：Person A、Person B、reference、Timing start/end 一律要求日期、小时、分钟、时区完整明确；不接受“时间不可靠”标记，也不实现模糊时间自动降级。关系盘角点/宫头只有在精确时间与现有计算实际可用时进入 target。
- 复用现有 Composite/Davison、secondary progression、`modern_timing` lifecycle、point-set 与事件导出契约；不创建第三套事件 schema，不把 Composite 伪装成一个普通出生盘再推进。

## 固定接口口径

### Transit→关系盘

- `modern_timing` 新增 optional `target_chart`；省略时保持 B3 natal target 完全兼容。
- `target_chart.type` 接受 `natal|composite|davison`；关系类型必须携带精确 `person_a/person_b` 与 nested `point_set`，该 nested point set 是静态 target snapshot 的权威配置。
- 关系盘请求只接受 `transit` 的 `aspect` lifecycle；secondary progression / solar arc→关系盘留给 5B，不在施工中拍板。
- 静态 snapshot 必须调用现有 `calculate_composite()` / `calculate_davison()`，再把实际可用 planets、angles、显式 house cusps 归一化为 `TargetPoint`；不复制另一套关系盘算法。
- response meta 与每条 target-related event 保留 `target_chart_type`、`target_chart_method`；snapshot warnings 原样保留，section errors 以 `target_chart.<section>` 合并，不能静默丢失。
- A/B 交换后 target longitude、method 与对应 transit event 保持对称；Composite 非整宫沿用 B0 已锁定的 MC-shift baseline，不触碰 D10。
- 集成实测确认既有 Davison 用首人的本地 ZoneInfo 跨年加 timedelta 会在 DST 下产生 A/B 顺序差；B5A 以“先转 UTC、再取绝对中间时刻”的最小修复恢复独立 snapshot 对称性，并加 planets/angles/houses 回归。

### Progressed Composite

- 新增独立 `mode=progressed_composite` / `ModernSubMode.progressedComposite`，方法 key 固定 `progress_each_person_then_midpoint`。
- 对同一现实 reference，分别以 A/B 自己的 birth UTC 计算 day-for-year progressed UTC；在各自 progressed UTC 计算同名行星，再做 circular midpoint。
- 同时输出 radix composite planets、progressed composite planets、progressed→radix aspects；每个行星 trace 至少保留 A/B birth/progressed UTC、A/B 输入经度和合成经度，能够逐点复算。
- v1 响应模型不定义 `houses` 或 `angles`；point set 若请求 angles/house cusps/Lots 必须 validation error，而不是返回实验值或静默伪造。
- UI/导出不接 AI；未来若接入必须使用独立 `progressed_composite` stream key。

## 工作包与并行写集

| 工作包 | 内容 | 写集 | 状态 |
|---|---|---|---|
| 5A-T 关系盘 Timing backend | target_chart snapshot、TargetPoint 归一化、provenance、错误合并、对称性与 lifecycle tests | `astro_backend_modern_timing.py` + 新 focused tests/sample | ✅；关系 target、权威设置、对称性、错误合并及真实 samples 已通过 |
| 5A-P Progressed Composite backend | 双人独立 progressed UTC、同名行星 midpoint、trace、相位、无 houses/angles | 新 backend module + 新 focused tests/sample | ✅；32 项模块测试、真实 sample smoke 通过 |
| 5A-S Swift/UI/导出 | target_chart 请求、独立 submode/result、关系盘动态跳转、sidebar、Markdown/CSV/JSON | Swift models/views/export/integration + tests | ✅；严格 trace/数组解码、独立 reference 时区与完整导出，85 tests / 20 suites 通过 |
| 5A-I 主线集成 | API/constants/validation、fixture/CI/smoke、跨写集审查与冲突收口 | API、fixtures、scripts、docs | ✅；3 份真实 fixtures、CI/smoke 与 Codable contract 已对齐 |
| 5A-V 验收 | DST/跨日期线、A/B 对称、trace 复算、无 5B 字段、旧 Timing 回归、完整 gate/缓存清理 | tests/PLANS/CHANGELOG | ✅；双路独立 review 已收口，最终 gate 为 Python 756 项、Swift 85 项 / 20 suites，全部 smokes 通过 |

## 测试矩阵与 DoD

- Transit→Composite/Davison 单点 target 与各自独立 snapshot 同输入复算一致；A/B swap 后 planets/angles/显式宫头与事件签名对称。
- target snapshot warning/section error 有失败注入测试；旧 natal Timing fixture 的 type/method 与 event lifecycle 不漂移。
- Person A/B 使用不同时区、DST 与跨日期线 reference 时，各自 progressed UTC 分别正确；所有 progressed composite longitude 可从 trace 按 `circular_midpoint()` 复算。
- Progressed Composite JSON/Swift model/Markdown/CSV 明确只有行星、相位和 trace；不存在 houses/angles key 或 UI tab。
- Composite/Davison 结果页“动态”只预填并导航，不自动运行；Progressed Composite 是独立 submode，不共享 Composite stale result state。
- 聚焦 Python/Swift、真实 backend fixtures、`bash check_vibe_changes.sh`、新增 smokes、完整 diff 审查和缓存清理全部通过后，形成独立 B5A commit。
