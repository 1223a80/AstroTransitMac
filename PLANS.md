# GitHub Actions Modern Timing CSV 编译修复（2026-08-01）

分支：`codex/feature-real-prenatal-parans`。目标是修复 GitHub Actions macOS 15 ARM runner 在 `ModernTimingExports.swift` 的 29 字段 CSV 数组表达式上发生的 Swift 类型推导超时，不改变导出字段、顺序或数据语义。

## 执行计划

| 阶段 | 状态 | 范围 |
|---|---|---|
| 01 失败复核与任务隔离 | 已完成 | 已确认 Actions run `30620846981` 失败于 `ModernTimingExports.swift:133`；现有 Horary 计划已原样独立提交 |
| 02 CSV schema 重构 | 已完成 | 用命名列枚举与定长 row builder 统一 header、meta、event 行，移除巨大数组表达式和魔法索引 |
| 03 回归测试 | 已完成 | 覆盖精确表头、各行列数、event/meta provenance 优先级与 RFC 4180 转义；聚焦 14 tests 通过 |
| 04 本地门禁 | 已完成 | 无缓存 Swift build、聚焦 14 tests、完整 Swift 144 / Python 946 与全部登记 smoke 通过；完整 diff 无边界外改动，缓存已清理 |
| 05 GitHub 收口 | 已完成 | Actions run `30681991389` 的 Swift build/test、Python tests 与 backend smoke 全绿；修复提交已同步，进入最终文档收口 |

## 边界

- 不修改 Modern Timing JSON 模型、后端数据结构、CSV 字段名及字段顺序。
- 不通过修改 CI 超时、Xcode 版本或并发数掩盖编译器热点。
- 不顺带批量重构其他导出器；如发现相似风险，另行记录。

---

# Horary Markdown 重构与导出形状测试（2026-08-01）

分支：`codex/feature-horary-markdown-readable`（基于 7690db2 创建）。本条目随进展更新。

## 背景与动机

- Swift `MarkdownExportBuilder.horary`（`Sources/TransitStudio/MarkdownHoraryExportBuilder.swift`）目前是「markdown 标题骨架 + 每节整行 JSON dump」：文件内 25 处 `stringifyJSON`/`rawValue` 灌装，除 `## N. Section` 标题外几乎全是 JSON，人不可读。
- 同一功能存在双实现分裂：app 使用 Swift `MarkdownExportBuilder.horary`；后端 Python `format_horary_v2_markdown`（`astro_backend_horary_v2.py:2310`）是独立诊断 formatter，仍含部分序列化证据片段，Swift 端不调用、两端也不承诺字节一致。
- 痛点（用户已确认）：该函数同时供「复制 Markdown」与人阅读和 AI 上下文（`ContentView+AI.swift:89`）使用；原始 JSON 一次约 **40 万 tokens**，可读 markdown 约 **9K tokens**。
- 已确认决策：**markdown 输出仅保留 markdown 格式可表达的信息**；项目已有独立的 JSON / CSV 导出功能，不需要在 markdown 里内嵌 JSON。
- **关键发现（2026-08-01）**：孤立分支 `codex/fix-horary-markdown-token-budget`（commit `f3c236e`，2026-07-24）已实现过完全相同的方案（可读表格 + 顶部提示词注入 + 体积/形状测试），但从未合并进主线；主线（32a7453→HEAD）从未动过该 builder 文件。本任务改为**移植 f3c236e 修正后合并**，不再从零重写。

## f3c236e 审查结论（2026-08-01，已 review）

**需修正后合并**。已核实：约 30 个 `HoraryV2EvidenceRow` 属性在 7690db2 全部存在（编译兼容），紧凑表格方案可复用；同时确认 nil prompt 重复注入、接纳字段映射、测试覆盖和文档表述仍需修复。除 CHANGELOG/PLANS/BackendContractTests/package_app.sh 外，其余原提交文件主线未动（移植边界清晰）。

修正清单（移植时必须处理）：
1. **版本号（Blocking）**：跳过 f3c236e 的 `package_app.sh` 版本号改动（1.4.3 (45) 是倒退，主线已是 1.4.4 (46)）。
2. **AI 提示词去重（Should-fix）**：`ContentView+AI.swift:89` 传 data-only Markdown，当前选中的提示词仅作为 system message 发送；复制/保存路径才在报告顶部显式注入 `appState.aiPromptHorary`。
3. **文档同步（Should-fix）**：`docs/horary-v2/FIELD_DICTIONARY.md:86` 与 `docs/horary-v2/README.md:50` 仍称 formatter 为 lossless，移植后矛盾，需更新。
4. **如实记录裁剪**：新版本有意不输出 `event_graph`、`pairwise_geometry`、provenance 完整证据与 display metadata（无损走 JSON 导出），CHANGELOG 须写明，不沿用「不改变 AI 分析链路」的说法。

## 执行计划

| 阶段 | 状态 | 范围 |
|---|---|---|
| 01 现状核对 + f3c236e review | ✅ | 冲突面检查（仅 4 个文件两边都改过）；review 完成，结论「需修正后合并」，修正清单见上 |
| 02 移植 f3c236e | ✅ | 7 个文件检出（BackendContractTests 手工保留主线 eec6bbd prenatal parans 断言）；跳过 package_app.sh 版本号；复制/保存路径显式传 `appState.aiPromptHorary`；同步 Horary 文档；`swift build` 通过 |
| 03 全模式 markdown 形状测试 | ✅ | 新增 `SwiftTests/MarkdownShapeContractTests.swift`：27 个有 fixture 的模式 + 反向 JSON 断言；统一断言「以 `# ` 标题开头、无裸 JSON 行、无 `- full: {`、体积 < 100KB」；localSpace/astrocartography/modernCycles 为合法的「# 标题+表格」风格，不强制 `## `；28 tests 全绿 |
| 04 更新旧断言 | ✅ | HoraryResultTests 的 `md.contains("geocoding")` 等 JSON 字段名断言替换为可读节断言（`## 接纳`/`## Lots`/`## 月亮进程与 VOC` 等 + `!contains("{\"")`）；BackendContractTests horary 断言改 `## 相位`/`显示容许度`；CSV/JSON 断言不动 |
| 05 ExportMenu 修复 | ✅ | `ExportMenu` 补「复制/保存 Markdown」（.md 扩展名），markdownProvider 死参数正式消费；classical/horary/通用工具栏三调用点自动受益 |
| 06 全量门禁 | ✅ | Python 946 passed；Swift build + 172 tests 全绿（本环境需 `--disable-sandbox`）；33 个 backend smoke + rectify（total_candidates=3）全过；CHANGELOG 已追加；本条目收口 |
| 07 review 后修复 | ✅ | 裸 JSON 检测加强（整行 / `- {` / `: {` 三形态 + ```json 代码块豁免）；AI 路径提示词去重（customSystemPrompt 单一承担）；结构断言收紧；全量 172 tests 全绿 |
| 08 仓库收口复审 | ✅ | 修复 nil prompt 重复文案、接纳映射失真、双份 AI 默认文案漂移；35/35 fixture + 合成 JSON detector 全覆盖；聚焦 74 项及完整 Python 946 / Swift 181 / build / 33 smokes / rectify 全绿 |

## 边界与风险

- 不动后端、不动 fixture：后端输出无变化，`jsonSwiftRoundTripPreservesEvidenceKeys` 的 JSON 保真契约不受影响。
- `HoraryDataPacket` 的 raw JSON 访问器保留（JSON/CSV 导出依赖），只改 markdown 呈现层。
- AI 上下文随重构变化（体积大减、内容为字段级），需人工抽查 AI 面板输出质量。
- 老用户 UserDefaults 已存的 `aiPromptHorary` 不会被新默认文案覆盖（`defaults ?? default` 语义），可接受，不迁移。
- 工作量估算（移植路径）：移植 1–2h + 形状测试 3–4h + 修正与门禁 1h ≈ 1 天（含调试）。


---

# 仓库现状盘点与收口清理（2026-07-31）

目标：在保留现有用户工作与 B18 分支成果的前提下，确认仓库当前所在分支、提交边界、未提交改动和本地产物；只清理可确认的缓存/生成物，完成必要验证并让项目目录保持可交接状态。

| 阶段 | 状态 | 范围 |
|---|---|---|
| 01 现状盘点 | ✅ | 已确认项目位置、分支/基线、未提交改动、远端关系、计划/变更记录与本地产物 |
| 02 边界分类 | ✅ | 保留用户月运记录、运行环境、离线参考仓库和工具状态；标出过期 app 包、Finder 元数据与验证缓存 |
| 03 安全清理 | ✅ | 清除 `.build`、Python 字节码、pytest cache、Finder 元数据；过期 1.1.1 app 包移至可恢复临时目录，保留 1.4.4 包 |
| 04 验证 | ✅ | Python 946、Swift build、Swift 142、`git diff --check` 均通过 |
| 05 收口记录 | ✅ | 已记录清理范围与原有用户月运记录；README 口径问题转入 06 处理 |
| 06 README 对齐 | ✅ | 已同步 1.4.4 (46) 发布基线、当前 B18 schema v2 增量、门禁数字与 B18 请求/迁移契约 |
| 07 提交与推送 | ✅ | `b26f3f0` 已提交并推送；当前分支已跟踪 `origin/codex/feature-real-prenatal-parans`，本地与远端无差异 |

## 盘点结论

- 当前目录：`/Users/gacu/Documents/Codex/AstroTransitMac`；当前分支：`codex/feature-real-prenatal-parans`；HEAD：`eec6bbd`。
- 当前分支相对本地 `main` 多 7 个提交；本地 `main` 相对记录中的 `origin/main` 多 28 个提交；当前分支没有对应远端分支。
- 源码与测试基线正常：Python 946 项、Swift 142 项全部通过，Swift 可构建。
- 保留 `.venv`、`maitreya8-reference`、`.reasonix`、`.claude`、`.opencode` 等运行环境/参考/工具状态，不将其误判为垃圾。
- `README.md` 已对齐 `CHANGELOG.md`、`package_app.sh` 和当前分支：最近已打包版本为 1.4.4/46，当前源码增量为真实事件 B18；发布基线与未重新打包的源码增量已明确区分。

---

# 个人月运分析（Astrodienst 2026 年 8 月月讯，2026-07-28）

## 范围

- 提取并核对用户提供的 Astrodienst 2026 年 8 月大众月讯。
- 只使用可确认的个人出生资料；调用项目现有后端、星历与计算模式生成 2026 年 8 月个人行运证据。
- 将大众天象与个人盘接触整合为一份面向个人、注明计算口径与不确定性的中文月运。
- 不修改计算代码、JSON 契约、版本号或安装包。

## 执行计划

| 阶段 | 状态 | 范围 |
|---|---|---|
| 01 资料与出生参数确认 | 已完成 | 5 页 PDF 已提取并逐页视觉核对；使用 TransitStudio 唯一已保存本命资料 |
| 02 后端计算 | 已完成 | natal moment、modern timing、modern cycles、secondary progression、solar arc 均已运行并核验 |
| 03 交叉核对与成文 | 已完成 | 已按 Asia/Shanghai 校正本地日期，区分月内触发与长期背景并完成中文月运 |

---

# B18 True Fixed-star Parans（2026-07-28）

分支：`codex/feature-real-prenatal-parans`
基线：`fix/classical-json-decode-regression` 的 `4b7a333`（包含已审查的 B18 RA 代理兼容语义）。

## 目标与迁移合同

- `fixed_star_parans` 默认升级为出生地本地民用日内的真实事件配对：行星与固定星各自的 rising / culminating / setting / lower-culminating 事件由 `swe.rise_trans` 独立求得，再按 `paran_event_orb_seconds` 配对。
- 每行保留两端 event type、UTC / 出生地本地 timestamp、`event_delta_seconds`、完整/代理标记与 Swiss Ephemeris 方法溯源。
- 旧 ΔRA co-culmination proxy 移至明确的 `legacy_fixed_star_parans`，保留原字段和 `method_key_legacy=fixed_star_paran_ra_proxy_v1`；不把代理行混入真实事件计数。
- 升落不可得（含极区 circumpolar）时不伪造事件：保留可求得的上下中天事件，输出对象级缺失诊断、顶层 polar degradation 摘要和 warnings。
- Swift 默认展示真实事件，并提供独立兼容代理页；Markdown / CSV 同时导出真实事件与 legacy 迁移信息。

## 执行计划

| 阶段 | 状态 | 范围 |
|---|---|---|
| 01 合同与 Swiss 调用核验 | ✅ | 已阅读 B18 后端、API、Swift/fixture、导出和 `pyswisseph.rise_trans` 本机签名/flags |
| 02 后端与输入合同 | ✅ | 四事件求解、配对、UTC/local 时间、方法溯源、legacy 输出、极区降级、参数校验 |
| 03 聚焦 Python 测试与 sample | ✅ | 正常地点事件事实、时间差、legacy 迁移、极区无伪造事件、sample smoke |
| 04 Swift / fixture / 导出 | ✅ | Codable、真实事件 UI、legacy 页、Markdown/CSV、真实后端 fixture、契约测试 |
| 05 门禁与独立提交 | ✅ | focused pytest 106；完整 Python 946、Swift 142、build 与全部 smoke 全绿；diff/fixture 已复核并清理缓存 |

完成条件：真实事件行可追溯且时间字段自洽；旧代理语义可迁移读取；极区只降级不伪造；相关门禁全绿；不打包、不合并，工作树以独立可审查提交收口。

---

# B7–B20 古典进阶 UI（2026-07-20）

真源：`docs/ui-design-b7-b20-2026-07.md` Confirmed r4。

| PR | 状态 | 说明 |
|---|---|---|
| PR1 | ✅ | 古典进阶列表 + 现代轨过滤 + Workspace 五门闩 + clamp + 图标 + 单元测试 |
| PR2 | ✅ | ExpansionChrome / MethodChromeBanner 工厂 / AssumptionsListView |
| PR3 | ✅ | B7/B8/B10 现代周期 pane 结构化（中文表头 + chrome + Overview 嵌顶） |
| PR4 | ✅ | B9/B11/B13 古典条件/可见/派生 |
| PR5 | ✅ | B14/B16/B17 NestedJSON typed + 结构化 UI |
| PR6 | ✅ | B12/B15/B19 chrome + 中文/空态 |
| PR7 | ✅ | B18 typed packet；B20 事实矩阵 only |
| PR8 | ✅ | classicalExpansionResults 缓存 + 章节多选 + 合并导出 sheet |
| PR9 | ✅ | DL1 主限→主限审计；DL2 产前→prenatalParans；门禁全绿 |

非目标遵守：不改 Python 算法 / 不新增 mode 字符串 / 扩展无 AI / 不重做吠陀。

---

# B13–B20 expansion batches (2026-07-19)

All of B13–B20 implemented with independent backends, samples, fixtures, Swift panes, and gates.

## Skeptic remediation (2026-07-19)

| 项 | 状态 | 说明 |
|---|---|---|
| B18 star RA | ✅ | `compute_star_positions` 写入 `ra`/`right_ascension` |
| B18 syzygy exact_jd | ✅ | prenatal syzygy 返回 `exact_jd`/`jd` → `syzygy_chart` |
| B15 profile 分化 | ✅ | ASC/MC 两两分化；armc 诚实为 ecliptic proxy（非完整 361° RAMC） |
| B13–B20 定义性测试 | ✅ | lot 黄经、PD arc 分化、circular mid、B20 reject、Swift 核心数组 |
| smoke 证据 | ✅ | B11–B20 transit_calc + check_vibe 全绿 |

## Review REQUEST CHANGES 闭环（2026-07-19）

| 项 | 状态 | 说明 |
|---|---|---|
| B14 lot + L4 | ✅ | fortune/spirit 真 lot；无 ASC 替代；l4_periods + current_active_level |
| B17 PD profiles | ✅ | arc_signed → Naibod/Ptolemy/converse 真实重算 |
| B19/B20 | ✅ | circular midpoint + geocentric nodes；location/tz 校验 |
| Swift 八模式载荷 | ✅ | Models/Views/Exports + fixtures + BackendContract |
| 门禁 | ✅ | pytest 839 / swift 103 / check_vibe |
| 交接文档 | ✅ | `docs/b13-b20-skeptic-remediation-handoff-2026-07.md` |

## 第二轮审查 REQUEST CHANGES（2026-07-19）

| 项 | 状态 | 说明 |
|---|---|---|
| UI reference age=0 | ✅ | classicalReferenceDate + expansion sidebar |
| B20 负步长无限循环 | ✅ | API + calculate 拒绝 ≤0 / 非有限步长 |
| B20 侧栏时间窗 | ✅ | start/end/topic/step 可见 |
| Candidate 证据字段 | ✅ | Codable + JSON round-trip 测试 |
| Markdown 全量导出 | ✅ | 去掉静默 prefix |
| isRunDisabled 经纬度 | ✅ | 统一校验、无重复 case |
| 门禁 | ✅ | pytest 841 / swift 105 / check_vibe |

---

# B12 Draconic/日心（2026-07-19）

| 阶段 | 状态 |
|---|---|
| 完成 | ✅ |

---

# B11 Hellenistic 行星状态审计（2026-07-19）

## 范围
- mode=`hellenistic_condition_audit`：oriental/occidental、superior/inferior、overcoming、enclosure、bonification/maltreatment 证据行等。
- 证据列表，非吉凶分数；profile 显式；JSON/Swift/Markdown/CSV/sample/fixture/测试/门禁。

## 执行计划
| 阶段 | 状态 | 范围 |
|---|---|---|
| 01 实现 | ✅ | 后端 + API + Swift + 测试 + 门禁 |

---

# B10 行星会合周期（2026-07-19）

## 范围

- mode=`planetary_synodic`：任意两星相对黄经相位、会合周期、相对速度、pass、本命接触。
- 全门禁 + 独立 commit。

## 执行计划

| 阶段 | 状态 | 范围 |
|---|---|---|
| 01 后端 | ✅ | planetary_synodic 模块 |
| 02 测试/Swift/门禁 | ✅ | 完成 |

---

# B9 古典 heliacal 与行星时（2026-07-19）

## 范围

- mode=`classical_visibility`：heliacal rising/setting（及 morning/evening first/last 可用项）、地方升落、planetary hours（昼夜不等时）。
- 极区/无升落：warnings + section_errors 降级，不伪造小时。
- JSON/Swift/Markdown/CSV/sample/fixture/测试/门禁。

## 执行计划

| 阶段 | 状态 | 范围 |
|---|---|---|
| 01 实现后端 | ✅ | visibility 模块 + API |
| 02 测试 sample fixture | ✅ | pytest + smoke |
| 03 Swift | ✅ | Codable/UI/export |
| 04 门禁提交 | ✅ | 全门禁 |

---

# B8 任意行星返照与逆行阴影（2026-07-19）

## 范围

- 扩展 modern_return：水星至冥王星（可选 CHIRON）返照；保留全部精确穿越与 previous/current/next。
- 新 mode=`retrograde_cycles`：基于真实站度的前阴影 / 逆行区间 / 后阴影与重复触发。
- 复用 return_solver、scan station 求根；JSON/Swift/Markdown/CSV/sample/fixture/测试/门禁。

## 执行计划

| 阶段 | 状态 | 范围 |
|---|---|---|
| 01 契约发现 | ✅ | modern_return / return_solver / station / UI |
| 02 返照扩展 | ✅ | 多行星 half-window + multi-pass |
| 03 逆行阴影 | ✅ | retrograde_cycles 模块 |
| 04 测试与 Swift | ✅ | pytest/sample/fixture/Swift |
| 05 门禁与提交 | ✅ | 全门禁 + 独立 commit |

---

# B7 动态赤纬事件与 OOB 时间线（2026-07-19）

## 范围

- 新 mode=`declination_timing`：行运体对本命 point set 的平行 / 反平行、OOB 进出、赤纬停滞（最大南北赤纬）。
- 复用 modern_timing 的 `_find_roots` / `_refine_root` / `_lifecycle_bounds` / pass 编号；OOB 阈值使用事件时刻真实黄赤交角。
- JSON + SwiftUI + Markdown + CSV；requested/effective config、warnings、section_errors、calculation_assumptions。
- 聚焦 pytest、sample、BackendContract fixture、Swift 契约/导出测试；`check_vibe_changes.sh` 纳入 smoke。

## 执行计划

| 阶段 | 状态 | 范围 |
|---|---|---|
| 01 契约发现 | ✅ | modern_timing 求根原语、静态赤纬/OOB、point-set、导出与 fixture 路径已查清 |
| 02 后端实现 | ✅ | `astro_backend_declination_timing.py` + API 白名单 |
| 03 测试与 sample | ✅ | pytest + sample smoke + fixture |
| 04 Swift 契约与 UI | ✅ | Codable / 视图 / 导出 / 侧栏 / 运行 |
| 05 门禁与提交 | ✅ | pytest / smoke / swift build+test / check_vibe / 清理 / 独立 commit |

## 边界

- 保留「外部宠物升级 — プリルン」PLANS 条目，不混入本批次说明。
- 不改 dist/.build/缓存/backups。
- B7 门禁未绿前不宣称 B8 开始完成。

---

# B6 后现代 / 古典技法路线写回仓库（2026-07-19）

## 范围

- 将项目外完成的现代 / 古典占星计算扩展讨论稿整理为仓库路线文档。
- 更新根 `README.md`：补齐 B1–B6 已交付现代能力，并增加明确标注为“规划中、尚未实现”的后续路线摘要。
- 更新 `docs/README.md` 索引与 `CHANGELOG.md`；不修改计算代码、JSON 契约、版本和安装包。
- 保留现有未提交的外部宠物计划条目，不纳入本任务边界。

## 执行计划

| 阶段 | 状态 | 范围 |
|---|---|---|
| 01 现状与边界确认 | ✅ | B6 已提交并同步，HEAD 与 main/origin/main 一致；仅有无关宠物计划改动 |
| 02 路线文档写回 | ✅ | 完整规划进入 `docs/roadmap/`，去除项目外临时状态说明 |
| 03 README 与索引更新 | ✅ | 用户首页保留能力现状与精简路线，详细规格走文档链接 |
| 04 文档校验与 diff 复核 | ✅ | 相对链接、标题、围栏、`git diff --check` 与完整 diff/stat 均已复核；纯文档改动未运行代码构建 |

---

# 现代占星扩展 — B6ABC 地理与周期全量施工（2026-07-19）

## 分支

`codex/feature-modern-completeness`（自 B5A `d110b45` / 暂停文档 `2187a4e` 继续）

## 范围

按蓝图 12A–12C 一次完成：

| 子批 | 状态 | 交付 |
|---|---|---|
| B6A Relocation | ✅ | `mode=relocation` backend + Swift UI/export + tests/fixtures/smoke |
| B6B modern_cycles | ✅ | 朔望/食相 + visibility + contacts + timing_events |
| B6C spike + product | ✅ | 方法答案写入 handoff/map 模块 docstring；ACG/LS 可计算几何与导出；MapKit 完整交互 UI 后续 |
| 5B | 排除 | 决策门不变 |

## 工作包

| 包 | 状态 |
|---|---|
| 6A-B Backend | ✅ `astro_backend_relocation.py` |
| 6A-C/U Swift | ✅ models/export/views + ContentView 接线 |
| 6B Backend/Swift | ✅ `astro_backend_cycles.py` + UI |
| 6C map | ✅ `astro_backend_map.py` + UI + unverified 清单 |
| 6-I 集成 | ✅ API/samples/fixtures/CI/check_vibe |
| 6-V 验收 | ✅ 聚焦 pytest + BackendContract + `bash check_vibe_changes.sh`（778 Python / 89 Swift） |

## 交接

`docs/b6abc-geo-cycles-handoff-2026-07.md`

## 明确非目标（仍成立）

- 5B Composite/Progression 方法争议
- interpretive eclipse windows、parans、固定星线、自动选址
- 模糊生时降级
- 新模式 AI 分析

---

# 现代占星扩展实际施工 — 第 6A 批 Relocation Chart（2026-07-13）— 已由 2026-07-19 B6ABC 全量交付 supersede

原暂停交接内容保留供历史；状态以本节上方 B6ABC 条目为准。

---

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
- 修复分支后续已并入 `main` 并推送；当前基线 `4f55ad0` 与 `origin/main` 对齐。

# PLANS

按 `AGENTS.md` 约定：开始任务前在此写计划，执行中更新状态；已完结的历史任务批次归档到 `docs/archive/`（如 `plans-frontend-refactor-2026-06.md`）。

---

# B7–B20 古典进阶 UI 接手审计与发布收口（2026-07-23）

## 目标

- 对照 2026-07-20 设计稿、计划、变更记录与完整 diff，确认未提交的 B7–B20 Swift UI / 导出 / 深链改动是否完整。
- 修复审查或验证发现的问题，补齐必要测试和记录；不改 Python 算法、不扩展既定业务范围。
- 全量门禁通过后更新发布版本，打包并覆盖 `/Applications`，验证安装包，最后清理构建与测试缓存。

## 执行计划

| 阶段 | 状态 | 范围 |
|---|---|---|
| 01 工作树与任务边界审计 | ✅ | 已确认独立功能分支及单一 B7–B20 改动集 |
| 02 代码 / 契约 / 测试 review | ✅ | workspace 五门闩、tab、typed model、缓存、导出与深链已核对 |
| 03 必要修复与聚焦验证 | ✅ | 章节空切片/全不选回退已修复；Swift 136 项通过 |
| 04 全量门禁与 diff 复核 | ✅ | Python 841、Swift 136、32 类 smoke 全绿；`git diff --check` 无告警 |
| 05 版本、打包、覆盖与安装验证 | ✅ | 1.4.1 (43) 已覆盖 `/Applications`；codesign、arm64、无 pyc、安装包主限审计 smoke 通过 |
| 06 缓存清理与最终交接 | ✅ | 已清理约 656MB `.build` / release staging / Python 缓存；工作树仅保留本任务源码与文档 |

---

# B6ABC 分支复审、合并与推送（2026-07-19）

## 目标

- 复审当前 `codex/feature-modern-completeness` 相对 `main` 的提交与未提交改动，重点复核上一轮审查记录的 4 项问题。
- 若存在阻断问题，在当前任务边界内完成修复、测试与提交；若无阻断问题或修复通过，则合并到 `main` 并推送远端。
- 合并后核对本地/远端同步状态，并按项目要求清理构建与测试缓存。

## 执行计划

| 阶段 | 状态 | 范围 |
|---|---|---|
| 01 分支、远端与任务边界确认 | ✅ | 已确认 B6ABC 工作树边界；外部宠物计划条目属于无关改动，不纳入提交 |
| 02 完整 diff 与既有 findings 复审 | ✅ | 四项既有 finding 均已复核；另发现并修复地图物理坐标误受 ayanamsha 影响 |
| 03 必要修复与变更记录 | ✅ | 方位、黄纬、reference、exact_orb、GMT offset、地图 physical frame 均有回归与 changelog |
| 04 本地验收与缓存清理 | ✅ | `check_vibe_changes.sh` 全绿：778 Python / 89 Swift / 全 smoke；已清理 386MB `.build` 与 Python 测试缓存 |
| 05 提交、合并与推送 | ✅ | B6ABC 提交 `ea00675`；功能分支与快进后的 `main` 已推送，随后补交本计划收尾状态 |

---

# B6A/B6B/B6C 交付代码审查（2026-07-19）

## 范围

- 只审查当前 `codex/feature-modern-completeness` 工作树中的 Relocation、modern cycles、ACG / Local Space 及其交接文档，不实现修复、不打包、不推送。
- 以 `d110b45` 后的 B6ABC 未提交 diff 为主要边界，同时核对 API/Swift Codable/UI/导出/fixtures/tests/CI 的端到端契约。

## 执行计划

| 阶段 | 状态 | 范围 |
|---|---|---|
| 01 规则、边界与交接核对 | ✅ | 已读取 `AGENTS.md`、仓库状态、现有计划与 B6ABC handoff |
| 02 后端算法与 API 审查 | ✅ | 确认 Local Space 方位基准、ACG 黄纬遗漏、旧模式 reference 校验缩进回归、cycles 时间线 orb 语义问题 |
| 03 Swift/UI/导出契约审查 | ✅ | 已核对 Codable、请求映射、tab switch、状态隔离与导出接线；未发现额外阻断项 |
| 04 测试与门禁复核 | ✅ | 聚焦 pytest 17 项、Swift 89 项通过；四个最小探针复现现有测试未覆盖的问题；已清理 `.build`/pycache |
| 05 Findings 交付 | ✅ | 按严重度报告 4 项可操作问题并附精确文件/行号；本轮不实施修复 |

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
| 06 第 2 期验收 | ✅ | 档案胶囊摘要偏离已修正并复建通过；星盘图外观刷新兜底与浅/深色截图核对在后续第 3–6 期完成 |
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

# Expansion 002: 恒星与赤纬 + 中世纪技法深化 — 已完成（2026-07-01）

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
| 2.5 月小限增强 | ⏸️ | 明确延期（前端改动为主，不属本批验收） |
| 2.6 界推进深化 | ⏸️ | 明确延期（前端改动为主，不属本批验收） |
| 2.7 测试 | ✅ | 10 个中世纪技法单元测试已添加 |

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

---

# 现代占星扩展实际施工 — 第 6A 批 Relocation Chart（2026-07-13）

## 分支、边界与非目标

- 继续在 `codex/feature-modern-completeness` 上形成 B6A 独立 commit；B5A 已提交为 `d110b45`。
- 本批只实现蓝图 12A Relocation；12B 朔望/食相周期在 B6A 提交后另开，12C A*C*G / Local Space 只允许先做方法与 MapKit spike，不混入本批。
- D02 延续用户决定：birth 必须包含年月日、小时、分钟和明确 timezone；relocation 必须包含有效经纬度、地点名和 timezone，不提供未知/模糊生时降级。
- 原出生时间只在出生 timezone 解释一次；birth UTC/JD 固定。新地点 timezone 只做同一 UTC 的当地显示，不得改变 JD 或行星经度。

## 固定接口口径

- 新增独立 `mode=relocation` / `ModernSubMode.relocation`，method 固定 `same_birth_utc_new_location_houses`。
- 请求字段固定为 exact `birth`、`relocation{name,latitude,longitude,timezone}`、`house_system`、`zodiac`、`point_set`、`aspects`；point set 继续使用 B1 contract。
- backend 只计算一次 birth JD 与行星 positions；natal / relocated chart 复用同一行星经度，再分别以出生地点和新地点调用现有 `build_houses()`，杜绝重新解释新地点 timezone。
- 响应包含 `meta`、`natal_chart`、`relocated_chart`、`planet_house_changes`、`relocated_angles_in_natal_houses`、`natal_angles_in_relocated_houses`、warnings/section errors；不制造 relocation planets→natal planets 相位表。
- meta 至少保留 schema、method、birth UTC、relocation local、原/新地点、requested/effective house system、zodiac、ephemeris、effective point set；两张 chart 的 houses/angles/fallback provenance 可审计。
- 所有 shared planet longitude 必须在 1e-9° 内相同；compare row 只记录 `body_id/name/natal_house/relocated_house/changed`，overlay 只记录角点落入对方宫位。
- UI 为独立 submode；primary tabs 固定 biwheel / relocated houses+angles / overlays / compare，more 为 diagnostics / json；AI 延后并返回 nil。

## 工作包与并行写集

| 工作包 | 内容 | 写集 | 状态 |
|---|---|---|---|
| 6A-B Backend | same-JD 双地点 houses/angles、point set、overlay/change、fallback/meta | 新 relocation module + Python tests/sample | ✅ 2026-07-19 |
| 6A-C Swift contract/export | request/result Codable、backend client、Markdown/CSV/JSON、fixture contract | models/client/new exports/Swift tests | ✅ 2026-07-19 |
| 6A-U Swift UI | submode/state/sidebar/run/result tabs、biwheel/compare、stale result/AI 边界 | ContentView/ModernResultViews/new view/UI tests | ✅ 2026-07-19 |
| 6A-I 主线集成 | API/constants/validation、CI/smoke、真实 fixture、跨写集审查 | API/constants/scripts/docs/fixtures | ✅ 2026-07-19 |
| 6A-V 验收 | UTC/JD/longitude invariance、DST/±180°/高纬 fallback、导出与完整 gate | tests/PLANS/CHANGELOG | ✅ 与 B6B/B6C 一并验收 |

## 测试矩阵与 DoD

- Shanghai birth→London relocation：meta birth UTC 与独立 natal 一致，relocation local 正确处理 DST；两 chart 同 body longitude 逐点相等。
- 同地点 relocation 行星/角点/宫头及 house assignment 稳定；跨经度 ±180° 只改变 houses/angles，不改变 JD/行星。
- 高纬 Placidus fallback 必须通过现有 house helper 暴露 requested/effective method 与 warning，不能 silent fallback。
- point set 减少后两盘 planets/angles 与 effective point set 同步减少；缺星历点按实际结果剔除。
- planet house changes 与双向 angle overlays 可从 chart rows 独立复算；响应没有伪造的跨盘 planetary aspects。
- Swift tabs 与 switch case 一一对应，biwheel endpoint 完整；Markdown/CSV/JSON 记录原地点、新地点、同一 birth UTC、house fallback 与 compare/overlay。
- 聚焦 Python/Swift、真实 backend fixture、`bash check_vibe_changes.sh`、新增 smoke、双路 review、完整 diff 与缓存清理通过后形成独立 B6A commit。

## 2026-07-13 暂停交接与明日恢复点（历史记录；已由 2026-07-19 B6ABC 全量交付取代）

- 当前可打包源码的功能终点是 B5A commit `d110b45`：B0 基线、B1 point set/现代完整性、B2 Solar/Lunar Return、B3 综合时间线、B4 中点、B5A 关系动态均已完成；B6A 未完成代码不进入安装包。
- 2026-07-13 已停止 B6A 的 3 个并行 sub agent，撤回未闭环的 API/Swift contract 草稿；工作区只保留本交接文档，不存在可见但调用必坏的半成品 Relocation mode。
- 明日第一步先从最新已验收 commit 新开/确认 B6A 独立任务边界，再按 6A-B、6A-C、6A-U 并行，主 agent 负责 6A-I；不得跨写集，sub agent 只用 GPT-5.6 Sol / medium 或 GPT-5.6 Luna / xhigh。
- B6A 完成并独立提交后，顺序进入 B6B `modern_cycles`：New/Full Moon、Solar/Lunar Eclipse、global/location visibility、可选 natal contacts、导出与时间线 source 接入。
- B6B 完成后只先做 B6C 只读方法/MapKit spike，回答 Swiss Ephemeris binding、ACG/Local Space 公式、极区与 ±180° 断线、MapKit 命中/性能、10 点权威交叉验证；spike 验收前不得直接做产品地图。
- 5B 仍是明确决策门，不属于已交付 5A：D10 Composite 非整宫正式方法、D12 Progression/SA→Composite、Progressed Composite angles/houses 和 Davison reference place 均需用户确认后另开工作，不得在施工中代替用户拍板。
- 以当前蓝图工程量粗估，B0–B5A 已完成约 70%，整体剩余约 30%：B6A 约 8%、B6B 约 10%、B6C spike/后续产品化约 8%、5B 决策与最终全局收口约 4%。该比例是相对工作量，不是日历工期承诺。

### 明日恢复检查单

1. 读取 `AGENTS.md`、本节和蓝图 12A；确认分支/工作区仅有预期文档差异。
2. 先写/复核当日 B6A plan 与独立 commit 边界，再启动允许模型的三个互斥 worker。
3. 主线先查现有接口，随后实现严格 exact birth/location API；不得先登记一个没有 calculation module 的 dispatch。
4. 用真实 sample 生成 fixture，禁止手改；完成 Python/Swift 聚焦测试、smoke、双路 review 和 `bash check_vibe_changes.sh`。
5. 检查完整 diff/stat、清理 `.build`/pytest/`__pycache__`，更新本计划状态与 changelog，再形成 B6A 独立 commit。
# 外部宠物升级 — プリルン（2026-07-19）

- [completed] 保留 `~/.codex/pets/mint-patchi` 的既有 8×9 动画，升级为带 16 个环视方向的 v2 8×11 图集。
- [completed] 完成方向语义、连续性、三路隔离盲测、v2 图集与色键清理校验。
- [completed] 将显示名改为「プリルン」，通过校验后覆盖原宠物包并清理中间缓存。

---

# Horary Data Packet v2 重构（2026-07-23）

分支：`codex/refactor-horary`
目标：版本化、可复算、机器可读、只含数据、不含占星判断的 v2 数据管线。

## 执行计划

| 阶段 | 状态 | 范围 |
|---|---|---|
| 01 基线与库存 | ✅ | AGENTS、调用链、pytest/smoke 基线 |
| 02 Schema + domain | ✅ | schema_version, JSON Schema, 顶层结构 |
| 03 计算管线 | ✅ | 溯源/时间/宫位/天体/尊贵/几何/事件/接纳/Lots |
| 04 Legacy 适配 | ✅ | packetVersion=1 保留旧输出；v2 默认 |
| 05 序列化与 Markdown | ✅ | 无损格式化；禁止判断字段 |
| 06 消费者迁移 | ✅ | API/Swift/UI/AI/fixtures |
| 07 测试与文档 | ✅ | 合同/golden/确定性/禁止字段 |
| 08 全量门禁与清理 | ✅ | check_vibe + 缓存清理 + 交付报告 |

## 兼容策略

- 默认 `packetVersion=2` → `calculate_horary_v2`
- `packetVersion=1|legacy` → 现有 `calculate_horary`（解释层/旧合同）
- 共享求根与星历 helper 不平行复制

## 边界

- v2 禁止 machine_summary / radicality 评价 / significators / advanced judgment / score
- 规则状态仅输出带 rule_id/阈值/证据 的中性标签

---

# Horary Data Packet v2.1 生产升级（2026-07-24）

分支：`codex/refactor-horary`
目标：可复算、判断无关、足以支持严谨人工/AI Horary 分析的生产数据包。

## 阶段

| 阶段 | 状态 | 范围 |
|---|---|---|
| 01 计划与库存 | ✅ | 调用链、orb 漏相位根因、宫制耦合 |
| 02 相位计算/显示拆分 | ✅ | 全量候选 + events 独立扫描 + converging 修正 |
| 03 Horary 状态隔离 | ✅ | horaryHouseSystem / horaryAspectOrb 默认 |
| 04 数据扩展 | ✅ | 节点/偶然/接纳/事件图/行星时/considerations |
| 05 几何扩展 | ✅ | 赤纬/antiscia 接触/固定星/pheno |
| 06 消费者与 Schema | ✅ | Swift 保真、tabs、Markdown full/summary、Schema 2.1 |
| 07 测试门禁与交付 | ✅ | pytest 42+79、swift 108、check_vibe 全绿 |

## 保真收口（本会话）

| 项 | 状态 |
|---|---|
| `previous_house_change` 后端 + MOON 非空 | ✅ |
| `HoraryV2EvidenceRow` / JSONValue 无损袋 | ✅ |
| 深路径 JSON→Swift→JSON round-trip | ✅ |
| full Markdown 全量 dump（无截断） | ✅ |
| optional tab 按子键（decl/antiscia/stars） | ✅ |
| time/provenance/config 无损袋（geocoding/sect.evidence/aberration/numeric_precision） | ✅ |
| round-trip 根含 time_and_location/provenance/calculation_config | ✅ |
| check_vibe + smokes | ✅ |

## 边界（不实现）

interpretation_context / NLP 事项宫 / 自动征象星 / 转宫矩阵 / yes-no / radical 统一结论 / ToL 等直接判定

---

# Horary v2.1 当前分支审查与修复（2026-07-24）

分支：`codex/refactor-horary`
审查基线：`main` 当前提交 `cc861ca`；审查对象为该分支尚未提交的 Horary v2/v2.1 工作区改动。

| 阶段 | 状态 | 范围 |
|---|---|---|
| 01 边界与差异盘点 | ✅ | 已分类 Horary v2/v2.1 工作区改动并核对接口、调用链与文档契约 |
| 02 自动化门禁 | ✅ | 聚焦 Python 78 项；完整 Python 896、Swift 109、build 与 backend smokes 全绿 |
| 03 代码审查与修复 | ✅ | 已修复 Swiss pheno、版本/输入防线、Codable/导出保真、星盘显示和溯源哈希问题 |
| 04 回归与交付复核 | ✅ | 完整门禁、diff/stat 与 whitespace 复核完成；`.build`、pytest、pyc 和 QA 临时包已清理 |

完成条件：确认的审查问题均有回归覆盖；项目要求的相关测试通过；最终差异仅包含本 Horary 重构及其审查修复。

---

# 主界面纵向布局回归修复（2026-07-24）

优先级：阻断级，先于 Horary 其余审查。
截图基线：约 1470×928 pt 的窗口中，技法导航吞掉“现代 / 古典 / 吠陀”切换，中间参数栏吞掉“开始排盘”，现代技法列表向下溢出。

| 阶段 | 状态 | 范围 |
|---|---|---|
| 01 布局调用链定位 | ✅ | 确认超长现代技法列表抬高主工作区最小高度并压缩顶部工具栏 |
| 02 独立滚动与固定区修复 | ✅ | 技法列表占剩余高度独立滚动；收起/设置区固定；顶部实践模式和排盘操作区固定 |
| 03 尺寸回归与测试 | ✅ | Swift build + 109 tests；独立 QA app 实测顶部操作区、三模式切换、28 项导航与滚动值 |
| 04 审查任务恢复 | ✅ | 已记录 CHANGELOG，并恢复 Horary 审查、最终门禁和缓存清理 |

完成条件：现代 / 古典 / 吠陀切换和开始排盘始终可见；现代技法列表不再撑破窗口且可上下滚动；紧凑窗口仍保持三栏结构可用。

---

# 仓库与分支全局体检（2026-07-24）

目标：解释当前项目、分支与工作区为什么显得混乱，区分提交历史问题、未提交任务混杂、远端不同步、生成物/缓存和真实代码缺陷；本阶段只检查与报告，不擅自提交、拆分、丢弃或推送。

| 阶段 | 状态 | 范围 |
|---|---|---|
| 01 Git 拓扑盘点 | ✅ | origin 已刷新；本地 main ahead 18，advanced UI 再 ahead 1；单 worktree、无 stash/merge/rebase |
| 02 工作区任务分类 | ✅ | 24 个 tracked + 16 个 untracked；Horary v2.1、主布局修复、文档/fixture 混在同一未提交工作区 |
| 03 项目健康检查 | ✅ | 最近完整门禁全绿；确认版本/安装包错位、CI smoke 漏项、计划陈旧段落和重复大 fixture |
| 04 风险排序与收口方案 | ✅ | 已形成先保护快照、再以 1.4.1 UI 为基线拆分 Horary/UI/legacy 修复、最后同步 main 的无损步骤 |

完成条件：每个“乱点”都有证据、影响和建议动作；明确哪些问题需要立即修、哪些只是尚未提交；不以破坏性 Git 操作代替整理。

## 体检结论

- P0：当前 24 个已跟踪修改和 16 个未跟踪文件均未提交、未暂存、无 upstream；分支指针本身不能保护这些工作。
- P0：当前源码基线为 1.4.0(42)，而已安装 app 和 `feature/b7-b20-classical-advanced-ui` 为 1.4.1(43)；直接从当前工作区打包会发生功能/版本回退。
- P1：`codex/refactor-horary` 与 local main 同指针，未基于最新 advanced UI 提交；双方重叠 9 个文件，必须人工整合。
- P1：`codex/project-cleanup-2026-07` 的 `b014709` 仍是非等价未合并提交，legacy Horary 输入校验、最早事件选择和精确去重修复尚未进入当前代码。
- P1：刷新 origin 后，本地 main 仍领先 origin/main 18 个提交；advanced UI 再领先 1 个，GitHub 不代表当前本地产品。
- P2：CI smoke 比本地 gate 少 moment、harmonic、B13–B20 多个模式和 rectify，且无 `pull_request` 触发。
- P2：三份 Horary JSON 内容相同、每份约 1.4 MB；PLANS/CHANGELOG 各约 1.4k 行且保留过期“当前状态”描述。
- P3：三个已合并本地分支可在主线同步后清理；8 个 B13–B20 commit subject 含字面量 `\n\n`，只影响历史可读性，不应为此重写共享历史。

---

# 仓库无损收口与分支整理（2026-07-24）

分支：`codex/integrate-horary-ui-cleanup`
目标：以 `1.4.1 (43)` 高级 UI 为基线，保全并拆分混合工作区，补回遗漏修复，完成门禁后整理本地分支；不重写共享历史。

| 阶段 | 状态 | 范围 |
|---|---|---|
| 01 安全快照 | ✅ | 原混合工作区已保全为 `e3d95ba`，无文件丢失 |
| 02 干净整合 | ✅ | 以高级 UI `7cd1097` 为基线，拆出 Horary v2.1 与主布局两个独立提交 |
| 03 Legacy Horary 遗漏 | ✅ | 已移植输入校验、最早事件选择、精确去重；Horary 127 项通过 |
| 04 CI 与记录清理 | ✅ | 已补齐 PR 触发、moment/harmonic/B13–B20/rectify smoke 与过期计划标记 |
| 05 完整验证 | ✅ | Python 912、Swift 140、全部 smoke 通过；发布并验证 1.4.2 (44)，构建与 Python 缓存已清理 |
| 06 分支整理 | ✅ | 本地 main 快进至最终提交；删除已吸收的本地任务枝，原混合工作区保留为命名明确的安全归档枝 |

---

# README 最新状态重写（2026-07-24）

分支：`codex/update-readme-current-state`
目标：依据当前 1.4.2 (44) 源码、实际模式路由、Horary v2.1 契约、验证门禁和安装流程，详细更新根 README；清除“已交付仍写成规划中”等过期描述。

| 阶段 | 状态 | 范围 |
|---|---|---|
| 01 现状盘点 | ✅ | 已核对 1.4.2、三实践导航、34 个后端 mode、Examples、导出、AI、门禁与 Horary v2.1 |
| 02 README 重写 | ✅ | 已重构产品定位、1.4.2 更新、B7–B20/现代/古典/Horary/吠陀矩阵、架构、运行与发布 |
| 03 事实校验 | ✅ | 本地链接、示例文件、34 个 mode、20+8 导航分流、版本、测试数字与 roadmap 边界均已核对 |
| 04 diff 与交付 | ✅ | 已更新 CHANGELOG/计划，README 结构、空白、完整 diff 与工作树边界通过复核 |

---

# Classical + Modern Technique Maintenance (2026-07-25)

Branch: `fix/classical-modern-technique-maintenance`
Sources: `Desktop/古典技法维护.md`, `Desktop/现代技法维护.md`
Fixed fixture chart: 2004-08-09T08:16:00Z / 35.0576N 118.3346E / Whole Sign / Egyptian / Dorothean / ref 2026-07-25T08:44:00Z

## Progress tracker

### Classical (priority order)

| ID | Item | Status | Notes |
|---|---|---|---|
| C1 | Egyptian bounds + dignity ownership | done | Virgo fixed; ownership fields |
| C2 | Decennials 129-month rewrite | done | 129-month profile |
| C3 | PD converse dates + symmetry + aspects | done | |
| C4 | ZR L1/L2/L3 summary | done | |
| C5 | Return cycle/hit semantics | done | cycle clustering |
| C6 | Hyleg eligible vs selected | done | |
| C7 | Alcocoden witness rejection | done | |
| C8 | Almuten profile | done | |
| C9 | Kurios / Oikodespotes / composite split | done | natal/current roles split |
| C10 | Circumambulations period format | done | |
| C11 | PD multi-profile rename/downgrade | done | |
| C12 | Sect layered fields | done | partial |
| C13 | Angularity vs place quality | done | |
| C14 | Solar elongation vs visibility | done | |
| C15 | Enclosure/chariot proxy rename | done | |
| C16 | Bonification/maltreatment proxy | pending | |
| C17 | Lots source + duplicate groups | done | |
| C18 | Prenatal syzygy axis | done | |
| C19 | Heliacal before/after events | done | previous/next fields |
| C20 | Parans complete or downgrade | done | 2026-07-25 proxy downgrade；已由上方 2026-07-28 B18 true-event 任务 supersede |
| C21 | Ingress mundane chart | done | full ingress chart |
| C22 | Electional scanner rename | done | daily fact snapshots |
| C23 | Concordance independence | pending | |
| C24 | Return cross-noise split | pending | |
| C25 | Unified timeline semantics | pending | |

### Modern (after classical)

| ID | Item | Status |
|---|---|---|
| M1 | Location service | done |
| M2 | Placidus natal foundation | pending |
| M3 | Solar Arc restructure | done |
| M4 | Harmonic chart mapping | done |
| M5 | Planetary return (esp Mercury) | pending |
| M6 | Relocation | done |
| M7 | Modern cycles / eclipses | done |
| M8 | Declination / OOB | pending |
| M9 | Retrograde cycles | pending |
| M10 | Planetary synodic | pending |
| M11 | Draconic | done |
| M12 | Heliocentric | done |
| M13 | Method families (true ARMC) | done |
| M14 | 90° Dial / orbital | pending |
| M15 | Local Space | pending |

## Implementation rules

- Fix calculation layer first, then Markdown/export
- No hardcoding fixture answers
- All proxies marked explicitly
- Add automated regression tests per item
- Document root causes in `docs/technique-maintenance-2026-07/`

---

# Classical + Modern Technique Maintenance Review & Release (2026-07-28)

Branch: `fix/classical-modern-technique-maintenance`
Scope: review commits `df9c589`, `8dbb874`, and `f83a6f5`; repair confirmed defects; validate, package over `/Applications/TransitStudio.app`, and commit the review/release closeout.

| Phase | Status | Scope |
|---|---|---|
| 01 Boundary and contract review | done | Reviewed full branch boundary, call sites, schemas, tests, and task-record alignment |
| 02 Focused review and fixes | done | Fixed Solar Arc house/cluster defects and default Draconic/Heliocentric aspect failures; synchronized contract tests |
| 03 Validation | done | Focused pytest 169; full gate: Python 939, Swift 140, build and all backend smokes green |
| 04 Version and packaging | done | `1.4.3 (45)` packaged over `/Applications/TransitStudio.app`; metadata, signature, arm64 binary, hashes, no-pyc check, and installed-backend smoke verified |
| 05 Cleanup and commit | done | Removed `.build`, pytest cache, backend bytecode, and temporary package build/staging directories; records synchronized for final commit |

Completion criteria: no unresolved review findings in the three maintenance commits; required validation is green; installed app matches the new version and passes verification; caches are cleaned; worktree is clean after the final commit.

---

# Classical Chart JSON Decode Regression (2026-07-28)

Branch target: `fix/classical-json-decode-regression`
Reproduction: classical natal chart for 2004-08-09 16:16 GMT+8, 35.0576N / 118.3346E, Whole Sign / Tropical / Egyptian / Dorothean, reference 2026-07-28 21:19 GMT+8.

| Phase | Status | Scope |
|---|---|---|
| 01 Installed-app reproduction | done | Installed backend reproduced a 1,478,960-byte valid JSON response; Swift rejected fractional Circumambulation `start_degree=2.5762` as non-Int |
| 02 Root cause and repair | done | Circumambulation bound degrees now decode as `Double`; UI/Markdown/CSV formatting and actionable decode diagnostics updated |
| 03 Regression coverage | done | Added the reported chart as a real Python backend → Swift `ClassicalResult` test; added Python/Swift scan-limit consistency coverage |
| 04 Validation | done | Focused Python 138 + 69, focused Swift 9 + 21; full gate Python 940, Swift 141, build and all backend smokes green |
| 05 Patch release | done | Installed `1.4.4 (46)`; metadata/signature/arm64/no-pyc verified; fresh UI launch rendered the reported chart and `2.5762°–7°` first bound period |
| 06 Cleanup and commit | done | Build/test/package caches removed; records and final diff synchronized for the regression fix plus authorized scan-limit changes |

Completion criteria: the reported classical chart decodes and renders without the raw-JSON error; full validation is green; the corrected app replaces the broken installation; the final worktree is clean.

---

# Repository Full Review, Mainline Integration, and Cleanup (2026-08-01)

Target: review every tracked and untracked working-tree change plus every local branch not yet represented on `main`; preserve valid work, repair confirmed defects, integrate the final logical commits into `main`, synchronize the remote only after validation, and leave the repository free of build/test caches and pending Git changes.

| Phase | Status | Scope |
|---|---|---|
| 01 Inventory and task boundaries | completed | Git topology, staged/unstaged/untracked changes, local-only commits, stale branches, generated artifacts, and existing records classified |
| 02 Code and contract review | completed | All 15 tracked files plus the untracked shape-contract test reviewed against call sites, Horary v2.1, AI prompt, export, and documentation contracts |
| 03 Repairs and validation | completed | Confirmed defects repaired; focused 74 tests and full Python 946 / Swift 181 / build / 33 smokes / rectify gate passed; full diff and whitespace reviewed |
| 04 Commit and mainline integration | in progress | Create intentional commits per task, integrate all non-superseded work into `main`, fetch/reconcile safely, and push without rewriting history |
| 05 Repository cleanup and final audit | pending | Remove build/test caches and stale generated output, retire only fully absorbed local branches, and verify clean/synchronized `main` |

Completion criteria: all useful local work is represented by reviewed commits on `main`; superseded branch-only work is explicitly accounted for; required validation is green; caches/generated residue are removed; `git status --short --branch` is clean and local/remote state is verified.

## Branch accounting

| Ref | Disposition |
|---|---|
| `codex/feature-horary-markdown-readable` | Current reviewed work; commit once records are closed, then fast-forward into `main` |
| `codex/fix-horary-markdown-token-budget` (`f3c236e`) | Useful implementation ported and repaired; obsolete `1.4.3 (45)` packaging change deliberately excluded because main is `1.4.4 (46)` |
| `codex/archive-pre-cleanup-20260724` (`e3d95ba`) | Pre-integration safety snapshot; semantically absorbed by the later Horary/layout/legacy commits; direct merge would regress newer UI and is therefore superseded, not mergeable work |
| Other local `fix/*` / `codex/feature-real-prenatal-parans` refs | Their tips are ancestors of the current reviewed line and will be retired after `main` advances |
| Remote `codex/*` refs | All except the current prenatal-parans line are already ancestors of local `main`; remote cleanup follows successful main synchronization |
