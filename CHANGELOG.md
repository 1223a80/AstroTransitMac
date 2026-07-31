# Changelog

## 2026-07-31 — README and repository handoff alignment

- README 顶部版本口径更新为最近已打包的 `1.4.4 (46)`，并明确区分发布基线与当前源码中的 B18 true fixed-star paran 增量。
- 补齐当前门禁结果：Python 946、Swift 142、Swift build 与登记 smoke 全部通过。
- 补充 B18 schema v2 的真实事件配对、240 秒默认事件容许度、legacy RA proxy 迁移开关与极区降级说明。
- 完成项目目录清理：构建/测试缓存与 Finder 元数据移除，过期 app 包移出 `dist/`，保留最近已打包的 `TransitStudio.app`。

## 2026-07-28 — B18 true fixed-star paran event engine

- `prenatal_parans` 后端升级到 schema v2：以 Swiss Ephemeris `swe.rise_trans` 分别求行星/固定星的升、上中天、落、下中天事件，并按秒级容许度配对。
- 真实事件行新增两端 event type、UTC/出生地本地时间、JD、`event_delta_seconds` 与逐行方法溯源；顶层记录本地民用日边界、Swiss flags 和配对规则。
- 原 RA co-culmination proxy 移至 `legacy_fixed_star_parans`，保留 v1 method key 作为明确迁移输出。
- 极区不可用的升落事件不再伪造；保留可用中天事件，并输出对象诊断、降级摘要与 warning。
- API / Swift 请求新增受校验的 `paran_event_orb_seconds` 与 legacy 开关；默认事件容许度为 240 秒。
- 聚焦 Python 回归覆盖正常地点四事件事实/时间差、非法配置、legacy 禁用与 89°N 极区只保留可用中天事件。
- Swift schema v2 模型与结果页区分“Parans 事件”和“兼容代理”，主表展示两端事件、本地时间、秒差、方法以及极区降级状态。
- Markdown / CSV 改为完整导出真实事件时间、秒差与方法，并以独立区块/行类型保留 legacy RA 代理；Swift fixture 契约新增双语义断言。
- 拆分 Swift 行标识与 CSV 字段构造，避免宽 schema 表达式触发编译器类型检查超时。
- README 当前能力矩阵与固定星测试注释同步 schema v2；历史维护记录保留原代理降级背景并标明已被本任务取代。
- Swift 请求编码回归锁定事件秒数、legacy RA orb 与兼容开关的 JSON key。
- 极区摘要只统计明确不可用的 rising/setting 事件；其他 Swiss 诊断仍保留在对象级 evidence 中。
- 验证：B18/固定星/古典聚焦 Python 106；完整门禁 Python 946、Swift 142、Swift build 与全部后端 smoke 全绿；fixture 与 fresh backend 输出一致。
- 最终 diff 审查确认事件容许度/legacy 开关只由 `runPrenatalParans` 发送，不污染其他 expansion 请求。

## 2026-07-28 — Classical chart fractional-bound decode regression

- 发布修复版本 `1.4.4 (46)`，替换存在经典排盘解码回归的 `1.4.3 (45)`。
- 修复 `1.4.3 (45)` 经典本命盘解码回归：沿界推进首段会从实际 ASC 度数开始，`start_degree` 因而可能是小数；Swift 旧模型仍按 `Int` 解码，导致整份约 1.5 MB 的经典结果被拒绝。
- `Circumambulation` 当前界度数和 boundary 起止度数统一改为 `Double`，并同步界面、Markdown 与 CSV 的稳定度数格式。
- 增加截图同输入（2004-08-09 16:16 GMT+8，35.0576 / 118.3346）的真实 Python 后端 → Swift `ClassicalResult` 端到端解码回归。
- 后端解码失败提示现在包含具体 `DecodingError` 和截断预览，不再只显示无法定位字段的原始 JSON。
- 一并验证扫描 work-unit 新阈值：确认线 5M、硬上限 15M；新增 Python/Swift 常量一致性回归并更新 Swift 边界测试。
- 验证：经典/扫描聚焦 Python 138 + 69，聚焦 Swift 9 + 21；完整门禁 Python 940、Swift 141、全部后端 smoke 通过。
- 已覆盖 `/Applications/TransitStudio.app` 并重启安装版实测：截图同盘古典排盘正常显示，沿界推进首段正确显示 `2.5762°–7°`；版本、签名、arm64 与无 Python 缓存检查通过。

## 2026-07-28 — Scan work unit thresholds relaxed

- 窗口扫描 work unit 阈值调整：确认阈值 `2,500,000 → 5,000,000`，硬拒绝上限 `5,000,000 → 15,000,000`。
  理由：原 5M 硬拒绝仅占 300s 进程超时预算的 ~40%，对于 3-5 年 × 多目标点的合理扫描请求过于保守。
  新 15M 上限对应约 225s 耗时，仍留 25% 预算给二分精确定位和 JSON 序列化。
  同步更新 `astro_backend_scan.py` 和 `ScanWorkEstimator.swift`（`ModernTimingWorkLimits` 通过引用自动继承）。

## 2026-07-28 — Technique maintenance review and release closeout

- 发布版本提升至 `1.4.3 (45)`，用于交付本轮古典/现代技法维护与审查修复。
- Solar Arc 的通用 `house` 字段重新与同一响应中的 `solar_arc_houses` 宫头保持一致；本命宫位继续由 `sa_point_in_natal_house` 单独保留。
- 修复 Solar Arc activation cluster 目标字段遗漏 `natal_body_id`、Draconic/Heliocentric 默认相位缺少名称导致两个相位区块静默失败的问题。
- 更新 ARMC、Solar Arc v2 和固定星 RA 代理方法的新契约回归，并增加 Draconic→本命及日心相位非空验证。
- 清理后端重复导入与 Harmonic 相位映射中的无效分支。
- 验证：聚焦 pytest 169；完整门禁 Python 939、Swift 140、全部后端 smoke 通过。
- 已覆盖 `/Applications/TransitStudio.app`；版本、签名、arm64、dist/安装二进制哈希、无 Python 缓存和安装后端 smoke 均通过，构建与测试缓存已清理。

## 2026-07-25 — Technique maintenance batch 2

- Kurios split: `natal_oikodespotes`, `natal_kurios`, `current_compound_chart_governor` (year lord only in composite).
- Mundane ingress: full ASC/MC/houses/rulers/angular planets at location.
- Electional: `daily_fact_snapshots` / `scan_samples`; legacy `electional_candidates` = samples not ranked candidates.
- Heliacal: previous+next event fields; rise/set `next_*_after_reference`; Mercury/Venus four-phase defaults.
- Parans: renamed to `fixed_star_ra_conjunction` / approximate co-culmination proxy with declination fields.


## 2026-07-25 — Classical + Modern technique maintenance (batch 1)

Branch: `fix/classical-modern-technique-maintenance`

### Classical (calculation-layer fixes)
- Egyptian Virgo bounds corrected; bound upper exclusive; dignity ownership fields (`bound_ruler`, `subject_owns_*`).
- Decennials rewritten as 129-month minor-years profile (decoupled from Firdaria).
- Primary directions: converse dates always post-birth; symmetric duplicate flags; aspect fields.
- ZR L1/L2/L3 layered lords in `technique_lords_summary`.
- Hyleg eligible≠selected (unique selected); Alcocoden requires witness; no longevity years.
- Almuten profile title + contribution sources.
- Circumambulations period table; PD profiles renamed (`one_degree_per_year_proxy`, `sign_reversal_test_naibod`).
- Sect/place/solar elongation layered fields; enclosure/chariot proxies renamed/downgraded.
- Lots duplicate formula groups; prenatal full-moon axis fields; return cycle/hit semantics.

### Modern
- Method families v2: true ARMC Naibod + MC-from-true-solar-arc house rebuild; 361 experimental proxy.
- Solar Arc: arc keys, natal speed metadata, house field split, SA-internal patterns default off.
- Shared location service (builtin cities incl. Osaka); relocation city resolution.
- Modern cycles: eclipse+lunation merge group fields.

### Docs / tests
- `docs/technique-maintenance-2026-07/ROOT_CAUSES.md`, `CHANGES.md`
- `python_tests/test_technique_maintenance_classical.py` + updated method/PD/classical tests

### Remaining (next batches)
- Full heliacal before/after; Parans complete path; electional scanner rename; concordance independence engine; harmonic/draconic/heliocentric/local-space deep fixes; Mercury return multi-pass audit; more SA aspect lifecycle orbs.


## 2026-07-24 — README 对齐 1.4.2 已交付功能

- 根 README 按当前产品重新组织，新增 1.4.2 更新总览、B7–B20 逐批能力、20 个现代入口、八个古典进阶入口、Horary v2.1、吠陀、导出与 AI 覆盖矩阵。
- 补齐三实践模式 UI、34 个后端 mode、Swift→Python 架构、直接调用、验证、打包安装、关键契约与已知边界。
- 删除“已交付功能仍列为规划中”的过期表述；路线文档继续保留，但明确不代表现有能力。

## 2026-07-24 — 仓库收口与 CI 补强

- 以已安装 `1.4.1 (43)` 对应的高级 UI 提交为基线，无损整合并拆分 Horary v2.1、主窗口布局和 legacy Horary 遗漏修复。
- 发布版本提升至 `1.4.2 (44)`，覆盖安装后可直接使用本轮主窗口布局与 Horary 修复。
- CI 新增 `pull_request` 触发，并补齐 moment、harmonic、B13–B20 扩展模式及 rectify 的后端 smoke，避免本地门禁覆盖面高于远端。
- 删除与 canonical golden 字节完全相同的 Horary 文档 sample JSON，保留 Swift fixture 与唯一文档 golden，减少约 1.4 MB 重复仓库内容。
- 旧的 B6A 暂停记录明确标记为已被 B6ABC 全量交付取代；保留安全快照，不重写共享历史。

## 2026-07-23 — B7–B20 发布前审查收口

- 修复古典进阶 Markdown 章节选择“全不选”仍导出全文的问题。
- 将赤纬普通事件、赤纬停滞与 OOB 拆成可独立选择的 Markdown 章节，并补齐会合周期的本命接触章节、主限审计的算法说明与诊断章节。
- 增加章节导出回归测试，防止 picker 声明的章节再次退化为空切片。
- 发布版本提升至 `1.4.1 (43)`，用于区分此前已安装但未包含本轮 UI 收口的 `1.4.0 (42)`。

## 2026-07-20 — B7–B20 古典进阶 UI（IA + Workspace + 结构化结果 + 导出 + 深链）

- **PR1 路由/IA**：现代轨过滤古典八键；古典轨新增 `groupLabel「古典进阶」` + 8 列表叶子；引入 `ClassicalSettingsWorkspace`（`natalChart | expansion(m)`）并改写 Run / Results / Sidebar / 运行按钮 chrome / AI 五道门闩；顶栏实践切换 clamp 八键→natal；本命设置强制 natalChart；扩展 run 写入 `modernResultData`；扩展 AI = nil。
- **图标（D5）**：古典八键唯一 SF Symbol；`orbitalDial` 用 `circle.dotted`（不与 midpoint 撞车）；禁共用 `star`。
- **PR2 共享 chrome**：`ExpansionChromeModel` / `MethodChromeBanner` / per-mode 工厂（非 assumptions 正则）；`AssumptionsListView` / Overview 嵌顶条。
- **PR3–PR7 结构化 pane**：B7–B20 中文表头、EmptyState、chrome；B14/B16/B17/B18 NestedJSON typed（ZR / PD algorithm / 沿界 boundaries / 产前 packet）；B20 仅事实矩阵（无推荐/打分/按吉排序）。
- **PR8 导出 D6**：`classicalExpansionResults` 多 mode 缓存；当前 mode 章节多选 + 合并导出两级 sheet（§2.3 sectionId）。
- **PR9 深链**：古典本命「主限」→ 主限审计；时机「产前朔望」→ prenatalParans。
- 测试：`ClassicalWorkspaceTests` + `ExpansionStructuredUITests`；`swift test` 全绿；`check_vibe_changes.sh`。
- 补强：B8/B10/B12/B15/B19 中文表头 + EmptyState/Overview；古典进阶 pane 优先读 `classicalExpansionResults[mode]`（A→B 后回看 A 仍有结果）。

## 2026-07-24 — 主界面纵向布局回归

- **导航栏滚动**：现代技法列表改为占据导航栏剩余高度并独立纵向滚动，顶部收起与底部程序设置保持固定。
- **顶部操作区保真**：主工作区取得可伸缩高度，顶部实践模式切换和排盘按钮、底部状态栏不再被超长现代技法列表压缩到不可见。
- **实际窗口回归**：独立 QA app 在 1231×768 窗口验证三种实践模式、完整 28 项现代技法与导航滚动；Swift 109 项通过。

## 2026-07-24 — Horary v2.1 parallel review fixes

- **Swiss Ephemeris pheno 修正**：按官方 `swe_pheno_ut` 槽位读取 phase angle / illuminated fraction，并将 apparent diameter 从度换算为弧秒；新增逐字段回归断言。
- **Swift 全包保真**：`HoraryDataPacket` 保留并原样重编码根 JSON，补齐 houses/angles/validation/display 的 round-trip 与 full Markdown 证据，避免 JSON 导出静默丢字段。
- **星盘图显示语义**：只绘制 `aspects_in_display_orb` 当前相位；orb 外未来成相保留在候选/事件数据中，不再画成当前盘面连线。
- **版本路由**：未知 `packetVersion` 返回结构化校验错误，不再静默当作 v2；显式支持 v1/v2 的既有别名。
- **v2.1 输入防线**：直接计算入口拒绝非有限/负事件窗口与 orb、未知 node mode、非数组或重复 body IDs，避免无效数据包与异常搜索。
- **溯源哈希**：`declinationOrb`、`antisciaOrb`、`nodeMode` 纳入 canonical input/config 和双 SHA-256；任何改变输出的 v2.1 选项都会改变溯源标识。
- **CSV**：`numeric_precision` 对象改为完整 JSON 单元格，不再因按字符串读取而导出为空。
- **Swift 构建清洁度**：Horary 概览显式格式化 Bool 文本，消除 SwiftUI 本地化插值弃用警告。
- **行星日/时**：`_planetary_hours` 次日日出种子改为日落之后（+24h 回退），修复中纬度晚盘（含临沂 golden）误报 `unavailable`。
- **时区**：`planetary_day_hour` 使用 chart IANA zone，不再强制 Asia/Shanghai/UTC。
- **接纳**：跳过自互纳（`mutual|SUN|SUN`）；mutual/mixed id 规范为 `a < b` 单行。
- **bodyIds**：缺 SUN/MOON 时明确 `ValueError`，避免 `StopIteration`/`KeyError`。
- **CSV 导出**：补齐 `pairwise_geometry` / `event_graph` / `moon` / `nodes` / `planetary_day_hour` / `considerations_evidence` / `optional_modules`。
- **UI**：`HoraryV2EvidenceRow.id` 稳定键；overview 事件行 nil 合流。
- **文档**：生产 schema_id 统一为 `horary-data-packet/2.1`；`aspects` 语义与代码对齐（全量候选别名）。
- 测试：Horary 聚焦 pytest 78；全量 pytest 896；Swift 109；完整 backend smoke 全绿。

## 2026-07-24 — Horary Data Packet v2.1 生产升级

- **相位架构**：`aspect_candidates` 全量七政×托勒密五相（105）与 `display_orb` 过滤解耦；`aspect_exact` 事件独立自候选生成；`motion_direction` 不再因 orb 外误写 diverging；`station_or_retrograde_before_exact` 按速度符号采样真实计算。
- **状态隔离**：`horaryHouseSystem` 默认 `regiomontanus`、`horaryAspectOrb` 独立于古典 `classicalAspectOrb`/`selectedHouseSystem`（含隔离测试）。
- **数据扩展**：mean/true 交点、偶然状态证据、完整接纳（detriment/fall + mutual/mixed）、event_graph、行星日/时、considerations、赤纬、antiscia、固定星、`pheno_ut`。
- **Skeptic 闭环**：接纳在下一相关 exact 时刻真实评估 `holds` 与 sign-exit 是否改变；`positions_at_exact` 物化 lon/speed/house/dignity；AI Markdown 取消 12k 截断；赤纬含 sign-exit/station 与月亮 contact 序列；`events_index` 含 prev/next `house_change`。
- **消费者保真**：`HoraryV2EvidenceRow` / `HoraryV2JSONValue` 无损袋承接 bodies/aspects/receptions/lots/events/visibility/optional，以及 `time_and_location`（含 `geocoding`、`sect.evidence`）、`provenance`（含 `aberration_light_time`/`precession_nutation`）、`calculation_config`（含 `numeric_precision`/`aspects_enabled`）；JSON→Swift→JSON 深路径 round-trip；full Markdown 对 schema/provenance/time/config 全量 dump；Schema 2.1；golden 刷新；赤纬/Antiscia/固定星 tab 按子键展示。
- 边界不变：无征象星选择、无 yes/no、无 radical 统一结论、无 ToL 等判定输出。

## 2026-07-23 — Horary Data Packet v2（纯数据管线）

- 新增 canonical 引擎 `astro_backend_horary_v2.py`：`schema_id=horary-data-packet/2.0`，只输出可复算数据（宫位/天体几何/尊贵归属/两两几何/相位/事件/接纳/Lots/月亮索引/可见性几何），禁止 machine_summary、征象星选择、传光判断、score、confidence/medium 等解释字段。
- 事件流含 aspect_exact、sign_ingress、house_change、station、sunrise/sunset、lunar_phase_exact、VOC start/end、solar 阈值边界；VOC 多 `rule_id` 且带 start/end/duration。
- Lots 含 input_points / intermediates / pre-post normalize；无 confidence_tag。
- 生产默认 `packetVersion=2`；`packetVersion=1|legacy` 走原 `calculate_horary` 兼容适配（deprecated）。
- Swift：`HoraryDataPacket` 模型、Markdown/CSV/星盘图/结果页/AI 数据包全部迁移到 v2；无损 Markdown 格式化。
- Golden：临沂 2026-07-23 22:25 Asia/Shanghai（`docs/examples/horary-data-packet-v2-linyi-golden.json` + Swift fixture）。
- 测试：`python_tests/test_horary_v2.py`（schema/jsonschema、禁止字段、确定性、事件类型、VOC 区间、Lots 公式、性能、legacy CLI）。

## 2026-07-19 — B13–B20 第二轮审查修复：reference / 步长 / 导出 / 校验

- **P1**：`time_lords_extended` / `method_families`（及 PD 扩展）reference 改用 `classicalReferenceDate`；侧栏增加参考时间控件；请求编码测试断言 birth≠reference。
- **P1**：`scan_step_hours` 强制有限正数 `(0, 1440]`（API + 计算层），杜绝负步长无限循环；B13–B20 补 birth.moment / body_ids / picture_orb / modulus 校验。
- **P2**：B20 侧栏暴露 start/end、topic house、scan step；candidate Codable 保留 `moon_sign_exit_distance` / `nearest_moon_aspects` / `planetary_hour`。
- **P2**：Markdown 全量导出（去掉 prefix 静默截断）；`isRunDisabled` 统一经纬度校验并消除重复 case 警告。
- 测试：pytest 841；swift 105；check_vibe 全绿。

## 2026-07-19 — B13–B20 skeptic remediation（审查 REQUEST CHANGES 闭环）

- **B14**：Fortune/Spirit 按 classical lot id（`fortune`/`spirit`）取黄经，禁止 ASC 静默替代；ZR 顶层 `l4_periods` + `current_active_level` 可达 L4；concordance 稳定英文 body_id。
- **B17**：PD multi-profile 用 `arc_signed` 重算 — Naibod / Ptolemy(1°/y) 年龄分化，converse 取反弧。
- **B15**：armc_361 诚实为 ecliptic ARMC-family proxy；三 progression MC 两两分化 + 公式复算测试。
- **B19**：`circular_midpoint`；nod_aps 标注 `geocentric`。
- **B20**：强制 lat/lon；非法时区拒绝，无静默 0,0/UTC。
- **Swift B13–B20**：八模式 Codable/Views/Markdown/CSV 保留核心结果；default tabs 对齐；fixtures 重生成；BackendContract 断言非空核心数组。
- 交接：`docs/b13-b20-skeptic-remediation-handoff-2026-07.md`。

## 2026-07-19 — B11–B20 skeptic 修复：parans / syzygy_chart / method profiles / 定义性测试

- B18：`compute_star_positions` 输出赤道 `ra` / `right_ascension`；`calculate_prenatal_syzygy` 返回 `exact_jd`/`jd`，使 `syzygy_chart` 与 `fixed_star_parans` 非空。
- B15：progression profiles 对 ASC/MC 按 Naibod / true solar arc / 361°/year 分化；行星保持次限。
- B13–B20 聚焦 pytest 改为定义性断言（非空关键数组、method key 差异）；刷新 prenatal/method_families fixtures。

## 2026-07-19 — B13–B20 古典/现代扩展批次

- B13 `classical_derivatives`：Dodekatemoria / Monomoiria / Topical Almutens。
- B14 `time_lords_extended`：日小限代理、ZR L4、技法 concordance。
- B15 `method_families`：次限与太阳弧多 method_profile。
- B16 `primary_directions_audit`：命名算法与限制审计。
- B17 `distributions_pd`：沿界多 significator + 多 PD profile。
- B18 `prenatal_parans`：产前朔望盘包 + 恒星 RA paran 代理。
- B19 `orbital_dial`：轨道点 + dial/planetary pictures。
- B20 `mundane_electional`：四至点 ingress + 择时事实扫描（不排序吉时）。

## 2026-07-19 — B12 Draconic 与日心对照

- 新增 mode=`draconic_heliocentric`：Draconic 移位盘（真/平交点）与 heliocentric 坐标对照，明确 coordinate_center / coordinate_system。

## 2026-07-19 — B11 Hellenistic 行星状态审计

- 新增 mode=`hellenistic_condition_audit`：oriental/occidental、superior/inferior、sect/hayz、angularity、overcoming、enclosure、solar phase、chariot proxy 等证据行。
- 输出条件列表与 evidence，不合成吉凶分数；含 Swift/Markdown/CSV/sample/fixture/测试。

## 2026-07-19 — B10 行星会合周期

- 新增 mode=`planetary_synodic`：任意两星合/冲/四分等相对黄经相位、会合周期、相对速度、多次命中 pass、对本命 point set 接触。
- Swift 子模式、Markdown/CSV、sample、fixture 与聚焦 pytest；纳入 CI / check_vibe smoke。

## 2026-07-19 — B9 古典 heliacal 与行星时

- 新增 mode=`classical_visibility`：Swiss Ephemeris heliacal rising/setting、地方升落、昼夜不等行星时（迦勒底序）。
- 极区/无升落通过 `section_errors` 与 warnings 降级，不伪造小时。
- Swift 子模式、Markdown/CSV、sample、fixture 与聚焦 pytest；纳入 CI / check_vibe smoke。

## 2026-07-19 — B8 任意行星返照与逆行阴影

- 扩展 `modern_return`：支持水星至冥王星与 CHIRON；自适应搜索窗与步长；输出窗口内全部穿越、pass 编号、`requested_config` / `effective_config` / `calculation_assumptions`。
- 新增 mode=`retrograde_cycles`：基于真实站度的前阴影 / 逆行区间 / 后阴影（非固定天数），含站度表与 Markdown/CSV。
- Swift 返照选择器扩展；新「逆行阴影」子模式、契约 fixture 与聚焦测试；CI / check_vibe smoke 纳入 mercury return 与 retrograde cycles。

## 2026-07-19 — B7 动态赤纬事件与 OOB 时间线

- 新增后端 mode=`declination_timing`：行运体对本命 point set 的平行 / 反平行、OOB 进入与离开、赤纬停滞（最大南北赤纬），带 entering / exact / leaving、pass 编号与真实黄赤交角 OOB 阈值。
- 复用 modern_timing 的 bracket + bisection 求根原语；输出 `requested_config` / `effective_config` / `warnings` / `section_errors` / `calculation_assumptions`。
- Swift：Codable 模型、结果页、Markdown / CSV / JSON 导出、现代子模式「赤纬事件」侧栏与运行入口。
- 新增 sample、BackendContract fixture、聚焦 pytest 与 Swift 契约测试；CI 与 `check_vibe_changes.sh` 纳入 smoke。

## 2026-07-19 — B6 后现代 / 古典计算路线写回文档

- 根 `README.md` 补齐 B1–B6 已交付的现代 point set、返照、综合时间线、中点、关系动态、Relocation、周期与地图计算能力，并同步扩展后端示例命令和导出范围。
- README 新增明确标注为“规划中、尚未实现”的 B7+ 摘要，优先动态赤纬、任意行星返照 / 逆行周期、古典 heliacal phases / planetary hours 与任意行星对会合周期。
- 新增 `docs/roadmap/modern-classical-techniques-after-b6-2026-07.md`，记录现代 M1–M13、古典 C0–C16、共用计算原语、施工批次和逐批 Definition of Done；文档索引已接入。
- 本轮仅更新文档，不改变计算代码、JSON 契约、版本或安装包。

## 2026-07-19 — B6 合并复审：地图物理坐标系修复

- **ACG / Local Space**：物理天空几何统一使用 tropical true-of-date 坐标；sidereal/ayanamsha 仅属黄道标签选择，不再错误移动 MC/IC、ASC/DSC 或 Local Space 方位。
- 响应新增 `zodiac_requested` 与 `coordinate_frame=tropical_true_of_date_physical_sky` 以便审计；Swift 模型、Markdown 导出与真实 fixture 契约同步更新。
- 新增 tropical / sidereal 地图输出完全一致的 Python 回归，并移除 ACG 侧栏中会误导用户的黄道选择器。

## 2026-07-19 — B6 复审：GMT±N 本地时显示（P2）

- **modern_cycles**：`maximum_local` / timing `exact_local` 改用 `resolve_timezone`，支持 Swift `GMTOffset` 标签（如 `GMT+8`）；禁止 ZoneInfo 失败后静默回落 UTC。
- **relocation**：迁移地显示时区同样接受 GMT/UTC±offset；与 `moment_to_local_datetime` 语法一致。
- **core**：新增 `resolve_timezone()`，供 moment / cycles / relocation 共用。

## 2026-07-19 — B6 审查四项修复（方位 / 黄纬 / reference / exact_orb）

- **Local Space**：`swe.azalt` 方位按 SE 约定（南点起向西）转换为北起顺时针 `(az+180)%360`；trace 保留原始 SE 值。
- **ACG ASC/DSC**：改回真高度≈0 求根，完整使用 `(ecl_lon, ecl_lat, dist)`，覆盖 Moon/Pluto 等非零黄纬；升降用北起顺时针方位东/西分类。
- **API**：`reference` 精确字段校验移回 progression/solar_arc/harmonic/vedic/modern_return/modern_timing/midpoint/relocation 公共块，不再误缩进进地图模式。
- **modern_cycles timing_events**：`exact_orb` 改为相对 0°/180° 目标角的残差（满月/月食≈0，不再写 separation≈180）。
- 新增/加强回归：`test_map_modes`、`test_modern_cycles`；相关 fixtures 已重生成。

## 2026-07-19 — B6C ACG ASC/DSC 分类修正

- ASC/DSC 线一度改为「行星黄经 = chart ASC/DSC」以纠正标签对调；后续审查指出该法忽略黄纬，已由上一节真高度求根取代。

## 2026-07-19 — B6A/B6B/B6C 地理与周期全量交付

- 在 `codex/feature-modern-completeness` 上完成蓝图第 6 批：Relocation、`modern_cycles`、A\*C\*G / Local Space（含 spike 记录与可计算产品路径）。
- **B6A** `mode=relocation`：`same_birth_utc_new_location_houses`；共享 birth JD/行星黄经；双地点 houses/angles；`planet_house_changes` 与双向 angle overlays；Swift 子模式 + Markdown/CSV/JSON 导出。
- **B6B** `mode=modern_cycles`：New/Full Moon + Solar/Lunar Eclipse；global/location 可见性分离；可选本命接触不改 cycle UTC；`timing_events` 供时间线注册；pyswisseph eclipse binding 签名写入 meta。
- **B6C** `mode=astrocartography` / `local_space`：MC/IC 子午线与 ASC/DSC 采样曲线、Local Space azalt 方位；未验证的第三方交叉与测地远点显式列入 `meta.unverified`；MapKit 完整交互地图列为后续 UI。
- 新增 samples/fixtures、Python 聚焦测试、Swift BackendContract 解码、CI/`check_vibe_changes.sh` smoke；交接见 `docs/b6abc-geo-cycles-handoff-2026-07.md`。
- 一键门禁：Python 778、Swift 89/20 suites、含 relocation/cycles/acg/local_space 的 smoke 全绿。
- 5B 决策项与食相 interpretive windows 仍排除；新模式 AI tab 延后。

## 2026-07-13 — 现代占星后续施工暂停交接（仅文档）

- 按用户要求暂停 B6A；已停止全部 sub agent，并撤回尚未形成完整闭环的 Relocation 代码草稿，待打包源码保持在已验收的 B0–B5A 能力边界。
- `PLANS.md` 固化 B6A Relocation 的 same-birth-UTC/new-location-houses 与 exact-time/location 契约，并记录 B6B cycles、B6C map spike、5B 决策门和明日恢复顺序。
- 后续 sub agent 继续只允许 GPT-5.6 Sol / medium 或 GPT-5.6 Luna / xhigh；本次安装包不包含半成品 Relocation 入口。
- 本次覆盖安装版提升为 `1.4.0 (42)`，对应已验收的 B0–B5A 现代占星扩展集合。

## 2026-07-13 — 现代占星第 5A 批关系动态

- 按蓝图固定拆分 B5A：并行实施 Transit→Composite/Davison 与 `progress_each_person_then_midpoint` Progressed Composite；5B 的方法争议项保持排除。
- D02 延续为硬约束：两人出生与所有 reference/window 时间必须完整明确，不新增模糊时间或“未知生时”降级接口。
- 施工写集拆为关系盘 Timing backend、Progressed Composite backend、Swift/UI/导出和主线契约集成四路；sub agent 仅使用用户指定的 GPT-5.6 Sol / medium 与 GPT-5.6 Luna / xhigh。
- 主线先落地 `progressed_composite` mode/常量与 API 边界：关系 target chart 只允许 transit aspect、nested point set 权威且不得与顶层 target 冲突；两人/reference 严格校验精确时间，Progressed Composite 拒绝 5B 的 angles/houses/Lots/midpoint sections。
- 一键门禁、CI 与 AGENTS smoke 清单预先登记 Composite/Davison relationship timing 和 Progressed Composite 三个真实入口，样例由对应 backend 写集生成后统一验证。
- Progressed Composite backend 已按 `progress_each_person_then_midpoint` 落地：A/B 分别计算 progressed UTC，同名行星再取 circular midpoint；radix/progressed/相位与逐点 trace 齐全，响应不含 houses/angles，32 项模块测试及真实 sample smoke 通过。
- 修正 Davison 跨时区 A/B 顺序债务：中间时刻改为先把两人出生时刻转 UTC，再对绝对时间取中值，避免以首人 ZoneInfo 跨 DST 加 timedelta 造成约一小时漂移；新增 planets/angles/houses 对称回归。
- 关系 Timing 以 nested `target_chart.house_system/zodiac` 为静态盘及移动 transit 的共同权威设置，避免顶层 birth 设置不同造成热带/恒星黄道混算；两个真实 sample 显式记录关系盘设置并新增冲突回归。
- Progressed Composite Swift Codable/Markdown/CSV 保留 backend 的 A/B age years，避免 typed JSON 往返丢失 day-for-year 审计标量。
- 三个 B5A sample 已经真实 backend 入口生成 fixture；Swift `BackendContractTests` 覆盖关系盘 provenance、target 数量/类型、Progressed Composite 逐点 trace、age years，以及顶层无 houses/angles。
- Progressed Composite tab 状态使用独立 `radix_composite_planets` 默认 ID，避免与普通次限推进的 `progressed_planets` 语义混淆；关系 UI 契约不再构造 v1 禁止的 Lot target。
- 独立 backend review 后修补三项契约：Progressed Composite zodiac 缺省固定 tropical 而不依赖 Person A；API 复用统一 aspect spec 校验并拒绝 `point_set.angles`；Progressed Composite 与关系 Timing 的 effective point set 按实际输出剔除不可用点并去重 warning。
- 独立 Swift review 后将 Progressed Composite reference 改为独立 GMT offset；真实响应必须包含两组行星数组、相位数组、warnings 及每个行星的完整 trace，缺字段时 Codable 直接失败；backend meta 显式输出 schema/zodiac。
- Progressed Composite Markdown/CSV 补齐 schema、zodiac、ephemeris、完整 effective point set 与 diagnostics，所有行保持固定列数；Modern Timing Markdown 逐事件输出 target kind/longitude，与既有 CSV/JSON 审计字段一致。
- 最终一键门禁通过：Python 756 项、Swift 85 项 / 20 suites，全部 legacy、modern return/timing/midpoint、关系 Timing、Progressed Composite 与 rectify smoke 正常；两路独立 review 发现项已全部收口。

## 2026-07-13 — 现代占星第 4 批 Midpoints v1

- 启动独立 `mode=midpoint`：入口要求精确出生时刻和显式 point set/focus/source 配置，modulus 第一版只接受 360°，activation orb 独立校验。
- midpoint reference 保持 optional；无 reference 时契约只生成本命轴与 focus tree，不伪造动态 snapshot activation。
- B4 按独立 midpoint 核心、B3 timing axis target、Swift UI/导出与真实 fixture 四条写集实施，避免改动旧 `mode=scan`。
- Modern Timing 的 `target_point_set.midpoint_pairs` 采用两个 point ID 的权威重算契约；入口拒绝自配对、反序重复 pair 和畸形结构，不接受客户端注入中点经度。
- Swift point-set 增加 optional `midpoint_pairs`，并建立独立 Midpoint 请求模型；旧 fixture 缺少该字段时继续按 `nil` 解码，不改变既有 mode 的编码。
- Modern Timing 前端估算器按每个去重 midpoint axis 的 direct/opposite 两个实际 target branch 计数，与后端工作量公式保持同口径。
- Swift/Python 共享 mode 常量同步登记 `midpoint`，让 constants contract 在 API 新 mode 落地时立即覆盖漂移。
- 增加 Swift 请求/估算聚焦契约：独立 midpoint 请求可省略 reference、pair 编码 canonicalize 端点顺序，重复反序轴在估算时只计一次且展开两个 branch。
- Midpoint API 不只检查时刻字段是否存在，还实际解析 birth/reference 的日期、时区与 DST，并限制在项目支持的 1800...2100 年范围。
- B3 Timing 现可从 `midpoint_pairs` 的 endpoint IDs 权威重算轴并展开 direct/opposite target；branch 进入 group/event signature 防止 90° 同时命中被去重吞掉，事件另输出 `target_axis_branch`。
- Pair-only timing 请求不再继承默认十大行星与四轴；body/angle/cusp/Lot/asteroid endpoint 统一走共享 natal point resolver，未知或不可用端点显式失败。
- Swift Timing event 解码、Markdown 摘要与 CSV 增加 `target_axis_branch`，普通事件继续以 `nil`/空列兼容，midpoint direct/opposite 可在导出中复核。
- 新增独立 Timing–Midpoint 回归，锁定 pair-only 两 branch、估算 target 数、90° 同时 exact 的 branch-aware 去重、普通 target ID 兼容和畸形/未知 endpoint 失败路径。
- 新增覆盖六个本命点、四个 focus 与四类 reference activation 的真实 midpoint 示例请求，作为 backend smoke 和 Swift fixture 的唯一生成源。
- Midpoint 核心完成 canonical 轴、N*(N-1)/2 完整性、focus tree、四来源 snapshot activation、全 point-set resolver 与稳定 hit wire contract；16 项模块测试通过。
- Swift 新增 midpoint Codable、axes/trees/activations + diagnostics/JSON 结果页及专用 Markdown/CSV/JSON，第一版明确不接 AI。
- `.midpoint` 接入既有 ModernSubMode、ModernResultData、通用 BackendClient 与结果路由；从轴表选择后可切到现代综合时间线并只预填 canonical midpoint pairs，不自动运行。
- Midpoint 使用独立 bodies/angles/cusps/Lots/focus/source/orb/reference 状态；Timing target point set 可携带 canonical pairs，并以显式 custom-asteroid 开关保证轴表跳转后不会混入隐藏普通目标。
- 新增 `runMidpoint()`，严格校验至少两个有效点和一个有效 focus；reference 可显式关闭，四类 activation source 与独立 orb 编码后复用通用后端运行链。
- Timing 的 custom-asteroid 开关只影响 `modern_timing` 请求与星历准备；旧精确 Scan 继续无条件沿用原自定义小行星输入，不发生跨工作区行为漂移。
- Midpoint 侧栏补齐精确出生说明、点集、focus、optional reference、四类 activation source、独立 orb 与 360° direct/opposite 口径。
- Timing 侧栏展示和逐条删除预填 midpoint axes，默认不选全部；普通自定义小行星目标有独立开关，轴表跳转时显式关闭。
- Midpoint Swift meta 保留后端 `activation_sources` 并写入诊断与 Markdown，确保用户选择的 source 配置不会在 Codable 往返后丢失。
- Activations tab 可将当前 snapshot 实际命中的去重 axis 集合预填到综合时间线，仍只跳转不自动计算。
- 按文档命令生成真实 `midpoint-result.json`，并因 intentional event shape 刷新 `modern-timing-result.json`；BackendContract 锁定 15 轴、四 focus/四来源 activation 与普通 Timing branch=nil。
- 新增 pair-only Modern Timing 示例：普通目标数组全部显式为空，只扫描 SUN/MOON natal midpoint axis 的两个 branch，供 estimator/event/export 真实契约验证。
- 由 pair-only 示例生成真实 Timing midpoint fixture：2 个 target branches、6 条事件、direct/opposite 四个稳定 group；Swift contract 同步验证 branch-aware ID 与导出列。
- Modern tab 状态测试锁定 `.midpoint.defaultResultTab == axes`，切换子模式时不继承其他结果页的 stale tab。
- 真实 midpoint contract 明确区分 meta 中“已配置 activation sources”和 snapshot 中“实际命中 sources”；某来源零命中不伪造事实行。
- Midpoint API 回归显式锁定 D02：缺失小时、分钟或时区必须返回 missing；非法 reference 时区和 45/90 dial modulus 返回结构化 invalid，不进入计算。
- B4 聚焦门禁当前通过：Midpoint/Timing/常量 Python 68 项，Swift 73 项 / 18 suites；下一步执行项目全量 gate 与所有 legacy smokes。
- 一键本地门禁、CI 与 AGENTS smoke 清单同步登记 Solar/Lunar Return、Modern Timing、Midpoint 和 pair-only Timing，后续 push 会持续执行新 mode 的真实入口检查。
- Timing midpoint target 选择完整覆盖 all/focus/manual：轴表可全选当前筛选结果或手动多选，中点树可发送当前 focus 的实际命中轴；三条路径默认都不自动运行。
- B4 审查修复后的完整门禁通过：Python 702、Swift 74；legacy、Return、Timing、Midpoint、pair-only Timing 与 Rectify smokes 全绿，随后再次清理构建/pytest/bytecode 缓存。
- 提交前契约审查补齐每条 axis 的 `trace.input_longitudes`，并由 Swift Codable 保留该字段，确保 10°/190° 对径 tie-break 在 JSON 导出中可复算而非只靠实现约定。
- 修正含 midpoint pair 的部分 point-set 请求仍继承普通默认目标的问题：所有省略 selector 均按空集处理，只有显式普通 selector 才形成混合 target；同步校验嵌套 `point_set.node_mode`，并新增 activation source 单项失败隔离回归。
- Timing 的 Timeline/Grouped/Calendar 事件摘要与详情现显示 direct/opposite，Markdown 逐行保留稳定 event ID；普通 Timing 不再编码空 `midpoint_pairs`，中点预填会清除旧结果，CSV 对异常重复 axis ID 安全处理而不崩溃。

## 2026-07-13 — 现代占星第 3 批综合预测时间线

- Timing 筛选条改为窄窗口可横向滚动；Calendar 按显示时区做“月 / ISO 周”分组，并在周内保留当地日期时间，补充周键测试。
- B3 完整门禁通过：Python 668、Swift 65，classical/moment/scan/horary/vedic/harmonic/rectify smoke 全部成功。
- 同步 Swift/Python `ALL_MODES`，登记已交付的 `modern_return` 与新增 `modern_timing`，修复全量 constants contract 门禁。
- 补齐 B3 测试矩阵：0° 跨界、step 边界去重、双分支值、共享 lifecycle、推进月亮入座/月相、Lots target、逐事件 adapter 复算，以及 Swift/后端真实 fixture estimator 一致性。
- `ModernTimingMeta` 保留完整 `technique_configs`，Markdown 现在列出所有已配置 moving/event/aspect/orb（包括零命中的相位），保证导出可复算。
- 收紧 stderr 进度文件 monitor 的并发锁范围，避免终止回调与轮询任务在快照大小交错时重复消费或回退 offset。
- 将 Timing 工作区严格限定为现代 practice；运行路由、结果 pane、AI 可见性与按钮禁用统一复用同一条件，古典/吠陀继续固定走旧 Scan。
- Timing tab 契约测试显式导入 SwiftUI，以在独立测试 target 中构造受控 Binding。
- Timing 目标点侧栏复用已计算现代本命盘的有效 Lots，可显式写入 `target_point_set.lot_ids`；补充 Lot 编码与五个结果 tab 声明测试。
- 强化 `modern_timing` 顶层 failure-path 校验：畸形 birth/moment、technique、moving/event 数组现在返回 validation error，不再泄漏 `TypeError` / `KeyError`；补充共享 lifecycle 与 malformed payload 回归测试。
- 新增独立 `mode=modern_timing` 的后端事件引擎骨架，按完整 pass 组装 exact/lifecycle、稳定分组、窗口截断标记和技法级 provenance；旧 `mode=scan` 契约保持不变。
- Transit、Secondary Progression 与 true Solar Arc adapter 分别复用现有星历、`_calc_progressed_dt()` 和共享太阳弧值函数；工作量阈值继续沿用 1.5M/2.5M/5M。
- API 增加精确出生/窗口时间、IANA 展示时区、目标点集、技法/事件/相位和有限数值校验；模糊或未知出生时间仍不接受。
- Swift 正在接入独立请求/结果模型、估算器、事件视图及 Markdown/CSV 导出基础，尚待真实 fixture、运行入口和全量门禁收口。
- 增加覆盖三种技法的一年窗口真实示例请求，作为后端 smoke 与真实 Swift fixture 的唯一生成源。
- 一年示例为三种技法分别携带完整相位与 orb，并覆盖 Solar Arc 的半刑/六合命中，避免用空相位表制造“技法已运行”的假象。
- 新增 Modern Timing 聚焦测试，覆盖线性 lifecycle、边界截断、三次 pass、相位分支、估算阈值、严格输入校验、三技法真实一年窗口、时区事实不变以及 Progression/Solar Arc adapter 一致性。
- 修正新事件引擎 type alias 在项目 Python 3.9 运行时的兼容性，避免 `X | None` 在模块导入阶段求值失败。
- 由一年期真实示例生成 `modern-timing-result.json`，用于 Swift 解码、展示与导出契约测试；fixture 包含三种 technique 的实际事件。
- 抽取通用 stderr JSONL 进度缓冲器，保留跨 chunk 拼行与完整错误流；生时矫正改为复用该解析器，为综合时间线实时进度接线提供同一实现。
- 通用后端客户端增加可选实时进度回调：运行期间轮询正在写入的 stderr 文件、增量解析 JSONL，并在完成/超时/取消时停止 monitor；既有调用继续使用原默认行为。
- Scan 顶层新增“精确扫描 / 综合时间线”工作区状态，并为三种 timing 技法、各自事件/相位/orb、移动点、目标点集和 IANA 显示时区建立独立 Swift 状态；重任务确认统一为同一个 alert 契约。
- 新增 Swift timing 请求构造与前置估算 helper：技法按固定顺序编码、相位表互相独立、节点按 node mode 解析，目标 bodies/angles/宫头/小行星形成可审计 point set。
- Scan 侧栏按蓝图加入分段工作区；综合时间线可配置窗口/IANA 展示时区、严格出生资料、目标实体/轴点/宫头，以及 Transit、Progression、Solar Arc 各自的移动点、事件类型、相位和 orb。
- 新增 `runModernTiming()`：前端验证技法完整性、推进月亮/月相依赖、IANA 时区、目标点与工作量阈值；后台进度实时更新，完成前再次检查 run generation 与取消状态后才提交结果。
- 顶部运行按钮、禁用条件和结果路由按 Scan 工作区切换到独立 Modern Timing pane；第一版明确不显示或调用 AI，旧精确扫描结果、tabs 和 AI 保持原路径。
- Modern Timing pane 增加技法、事件类型、移动点、目标类型、相位和 lifecycle 截断筛选；筛选派生新视图数据，不修改原始 result，三种导出继续默认使用完整事实集。
- Swift 真实 fixture 契约覆盖三种技法、非相位事件、完整/截断 lifecycle、pass 分组和时区；结果提交封装 generation guard，并新增陈旧任务不能覆盖新请求的回归测试。
- 通用进度 parser 增加分片标签、非法行、完整错误流和 0...1 边界回归；既有 Rectify 分片测试继续通过同一底层实现。

## 2026-07-13 — 现代占星第 1 批共享点集与轴点基础

- 新增现代 point-set 校验/解析，统一实体、交点、角点、宫头、Lots 和自定义小行星的有效点集记录；未知点与模糊配置直接拒绝。
- 扩展 Swiss Ephemeris 轴点读取，保留 Vertex、Antivertex 与 Equatorial Ascendant，并保持既有 `build_houses()` 返回契约。
- 现代本命响应增加 `effective_point_set`、`patterns`、`chart_profile`；Swift 结果页与 Markdown/CSV/JSON 同步呈现结构、轴点、宫头、赤纬/OOB 和固定星。
- Synastry 增加可配置关系点集与带 A/B 前缀的跨盘赤纬相位；Composite、Davison、Progression、Solar Arc、Harmonic 接受 optional point set，并在星历未提供点时写 warning 后移除有效点。
- 现代请求模型为自定义小行星调用既有准备流程；本批不引入模糊出生时间或 noon convention。
- `mode=moment` 现在在入口拒绝缺少小时、分钟或时区的出生/行运 moment；现代 node_mode 也在入口做结构化枚举校验。
- B2 增加 Solar/Lunar Return 的可复现实例请求，作为 exact UTC 求根、地点快照与真实 fixture 的输入基线。
- B2 后端新增独立 Solar/Lunar Return 求根模块和 exact occurrence 测试；古典 return schema 保持独立不变。
- Solar Return 搜索窗口覆盖至少两个年度周期，确保 previous/current/next 语义在年中 reference 下不丢失 previous occurrence。
- 接入返照模式的 Swift 状态、运行入口、侧栏参数和结果路由；保持太阳/月亮返照均使用完整出生与参考时间。
- 返照快照 Swift 模型保留后端赤纬相位与固定星字段，避免结构化结果在解码时丢失。
- 新增返照结果页，展示当前/前后返照、返照对本命相位、宫位落点、图形、诊断及 JSON/CSV/Markdown 导出入口。
- 返照 Markdown 导出记录目标黄经、精确 UTC/当地时间、求根误差、返照快照及本命落点。
- 返照 CSV 导出采用独立字段契约，逐 occurrence 保留时间、黄经、求根误差、相位和宫位落点。
- 修正返照 Markdown 导出复用既有角度格式化 helper，确保 Swift 编译与导出格式一致。
- 新增 Solar/Lunar Return 真实输出 fixture、Swift 解码契约、请求编码和默认结果页 tab 测试。
- 返照侧栏补齐 birth/custom 地点来源与名称、经纬度、时区字段；自定义地点在运行前做必填校验。
- 返照快照补充本命行星、角点和宫头，供双盘展示使用；返回时刻仍只由目标天体黄经求根决定。
- 返照结果页加入双盘 tab，并用显式 `return-/natal-` 点 ID 校验相位端点，未解析端点进入诊断而不静默画线。
- Swift 真实返照契约测试增加双盘端点和未解析相位检查。
- modern_return API 现在在入口拒绝无效 IANA/固定偏移时区、DST 不存在的时刻和无效自定义地点时区；新增 DST 与 sidereal 自洽回归。
- 抽出共享 `astro_backend_return_solver.py`，让现代 Return 与古典 `planetary_returns` 共用 UTC bracket/精确求根；两种响应 schema 仍保持独立。
- Return Markdown/CSV 补齐 zodiac、requested/effective house system、岁差、出生/参考 UTC 与地点 provenance；meta 时间字段加入 `birth_utc`/`reference_utc` 解码。
- 真实 fixture 契约测试增加 Return Markdown/CSV provenance 字段断言。
- 共享 Return solver 的搜索步进显式归一化到 UTC，避免跨 DST 窗口按墙上时间迭代引入伪根；返回值再恢复调用方时区。

## 2026-07-13 — 现代占星第 0 批基线正确性修复

- 修复 Composite 非 Whole Sign 宫位重建对 `build_houses()` 三元返回值的错误 unpack；保持现有 MC-shift、Whole Sign 与真实 fallback warning 语义，并增加 Placidus/Equal/Porphyry 回归。
- 修复推进月相使用无方向最短夹角的问题，改用有向 `Moon - Sun` 周期角区分八相；保留 `sun_moon_separation` 与原响应字段，增加盈亏月相和跨 0° 回归。
- 本批不新增 mode、不改变现有 JSON shape，也不涉及模糊出生时间降级。
## 2026-07-13 — 项目遗留收尾

- 新增 Horary 二次审查聚焦回归，锁定未知 Matter 无可见诊断、嵌套时刻/选项 ID 校验缺口，以及 Advanced 检测按行星数组顺序而非最早事件返回的残留风险。
- Horary 请求校验现在复用既有时区/夏令时解析，拒绝非整数时刻字段、无效日期/时区/DST 时刻、非法 fold，并使用共享常量校验宫制、黄道、界与三分主体系 ID。
- Translation 与 Collection 不再按 Moon 优先或行星数组顺序返回首个候选，而是从共享事件事实中选择最早入相/完成事件。
- Prohibition 与 Frustration 同样改为选择主相位前的最早第三方事件；去重使用精确 datetime + 行星对标识，不再依赖分钟格式化文本，并补同一分钟内不同行星对不得误去重的回归。
- 问题文本无法推断 Matter 时，响应 `warnings` 明确说明关键链接与 Advanced 未评估；不扩展 `P3-02` 关键词或派生宫规则。

## 2026-07-11 — Horary 审计全量修复发布 1.3.1 (41)

- 完成 Horary 审计 16 项 REQUIRED 修复及既有 A–C 改动复审；P3-02 仍按产品决策边界保留，不擅自增加宫位选择器或扩展问题推断规则。
- 发布版本提升至 `1.3.1 (41)` 并覆盖 `/Applications`；全量门禁通过（Python 580、Swift 50、七类 smoke），安装版 codesign、无 pycache 与 Horary smoke 通过；最终清理 `.build`、pytest cache、`__pycache__` 与 `.pyc`。

## 2026-07-11 — Horary 审计修复 Batch C

- 扩展 Lots 的 Marriage、Travel、Lost Objects、Murder 公式对齐项目 source of truth，并让宫主引用解析实际宫头星座及其主星真实黄经。
- 行星 conditioning 完成后统一重算 `score_label`，避免最终分数与文字标签不一致。
- 负接纳改为逐项保留 detriment 与 fall，同一行星同时满足两项时不再被 `elif` 截断。
- 复核 Batch A 时移除五点采样、固定 8° 与起终点速度符号启发式；改为锁定当前相位分支，在 UTC 时间轴连续检查 orb 收敛性，并把 refranation 原因传入关键征象星链接。
- 修正旧 Jupiter–Saturn “无中断慢相位”回归的错误起点：原 2016-11-06 实际存在先收敛、后发散、再入相；测试改从 2017-07-14 的真实连续 application 开始。
- 复核 Batch B 时将 Advanced 四类判断改为消费同一份 pair aspect/event fact table，避免每个 detector 独立搜索未来；Collection、Prohibition、Frustration 和 Translation 现在共享相同 exact 与中断结论。

## 2026-07-11 — Horary 审计修复 Batch E（后端）

- Horary meta 复用统一黄道标签映射，正确区分 Lahiri、Raman、Krishnamurti、Yukteshwar，并记录本次 `aspect_orb`。
- Horary API 增加嵌套结构、时刻字段、经纬度范围、非空问题和 0...10° orb 的结构化校验，错误输入不再落到裸 `KeyError`。

## 2026-07-11 — Horary 审计修复 Batch D

- Classical/Horary 星盘图通过行星显示名映射稳定 ID，并统一整宫相位颜色名称；无法解析的端点在盘面显示诊断，不再静默丢线。
- Swift 补齐 Advanced `frustrating_planet` 与精确时间展示，Horary Lots 按 `lot_group` 分离实验组并保留 confidence。
- Raw JSON 改为随编码结果 revision 更新，停留 JSON 页重算不再保留旧盘。
- Horary Markdown/AI 与 CSV 增加 house、zodiac、bounds、triplicity、aspect orb provenance；Advanced 导出保留 exact time/受阻双方，Lots CSV 保留 group/confidence。
- 新增后端嵌套校验/四种 sidereal 标签回归与 Swift 真实 fixture 轮盘端点、provenance、Advanced 动态字段契约测试。
- 修正 Swift Markdown provenance 字符串的插值语法，保持格式化值在数组构造前计算。
- 清理 ChartWheelData 中对非可选宫位重复使用 `??` 的编译警告。
- 加固 Batch B 回归：真实验证 Moon 位于 pair 右侧仍复用 08:40 storyline，并把原先只断言“无 key aspects”的空 Collection 测试改为共享事件表下的正向 detected 测试。
- 复核 Lots 宫主解析时移除“缺主星则静默返回 0°”的错误兜底，保持与其他行星引用一致：缺数据由现有 warning/跳过路径显式处理。
- 复核 Raw JSON 刷新实现时移除异步 state 过渡，JSON tab 直接由当前 `value` 编码，确保重算后的单次渲染也不会短暂沿用旧结果。
- Advanced 去重条件补上第三方行星身份比较，避免两个不同事件仅因格式化到同一分钟而被误合并。

## 2026-07-11 — Horary 审计修复 Batch A & B

- **Batch A — UTC 搜索与连续 application**（P1-01、P2-01、P2-02、P1-03）：
  - `refine_pair_crossing`、`next_exact_for_pair_branch`、`previous_exact_for_pair_branch`、`next_sign_exit_for_body`、`refine_body_longitude_crossing` 全部改用 UTC 时间轴搜索，返回值转换回原时区；新增 `_to_utc_for_search`/`_from_utc_result` helper。
  - 修复 IANA DST 回拨期间精确相位搜索返回伪根的问题（P2-01）。
  - 修复 ingress 后首相位跳过 1 分钟的问题：`timedelta(minutes=1)` → `timedelta(microseconds=1)`（P2-02）。
  - `exact_datetime_for_signature` 增加 orb 收敛发散采样 + 应用星速度符号检查以识别 refranation（P1-01）。
  - `_detect_translation` 要求 translator 比两颗主征象星都快（P1-03）。
  - `key_significator_links` 中 Moon 在 pair 任一侧时复用 Moon storyline（P1-02）。
- **Batch B — 统一事件序列**（P1-04）：
  - `_detect_collection` 增加主相位时间比较：Collection 的两次入相完成必须在主 Querent–Matter 相位之前，否则 NOT detected。
  - `advanced_candidates` 增加 Prohibition/Frustration 去重：同一事件同时触发两者时，只保留 Frustration（子类型优先），Prohibition 标记为 not detected 并注明原因。
  - 新增 `python_tests/test_batch_b.py` 3 项真实回归测试。

## 2026-07-11 — Horary 计算模块专项审计

- 完成 Horary 请求、古典快照、精确相位/换座、Moon storyline、征象星、接纳、Advanced Candidates、Swift 解码/展示/导出与测试契约的全链路只读审查。
- 通过真实星历与边界样例确认 17 项问题（5 P1 / 10 P2 / 2 P3）：包括 refranation 后误报完成、Moon 位于配对右侧时漏算、慢行星误判 Translation、Advanced 事件顺序冲突、星盘图相位端点失配，以及 DST、Lots 公式、评分标签、负接纳、sidereal 元数据与 Swift 数据丢失等问题。
- 新增 `docs/horary-audit-2026-07-10.md` 与 `docs/horary-fix-guide-2026-07-11.md`，记录架构、复现证据、严重度、分批修复方案、验收矩阵、流派边界和可直接交给下一 Agent 的提示词；本轮未修改计算业务代码。

## 2026-07-10 — 产品决策记录

- 记录 LLM API Key 继续使用现有 UserDefaults 持久化是项目所有者的刻意选择；本轮及后续不得自行迁移 Keychain，详见 `docs/product-decisions.md`。

## 2026-07-10 — 二轮审计前端状态、时区与扫描修复（第四批）

- GMT 偏移改为 15 分钟粒度并兼容旧整数档案；人物 A、人物 B 与 Horary 各自持有时区，关系盘请求不再把 B 误用为 A 的时区；定位成功但地名反查失败时仍保留坐标，成功反查会同步当地时区。
- 现代本命与时间点使用独立结果、AI 文本、推理文本和流 key；新计算会清理对应旧分析，不再跨页面显示陈旧结论。
- 吠陀扫描目标从吠陀 Rāśi 行星、角点、宫头、特殊 Lagna 与 Upagraha 生成；扫描按月亮筛选和扫描类型校验实际天体，留逆排除太阳/月亮，相位扫描拒绝空相位或空目标。
- Solar Arc UI 开启图形识别，后端返回所选交点以免相位引用隐藏天体；允许四个合法目标同处一星座；Composite/Davison 的地理中点按跨日期变更线的最短弧计算。

## 2026-07-10 — 二轮审计进程、矫正与契约修复（第五批）

- 生时矫正子级任务可取消；输入变化会清空陈旧结果并终止在途主/子计算；stderr 进度支持跨数据块拼行，超时任务在正常完成后取消，continuation 仅恢复一次；累计秒数标签改用三级绝对偏移。
- 通用后端 watchdog 正常完成后会取消并释放；启动失败、超时、取消与进程退出统一防止 continuation 重复恢复。
- 吠陀 Swift 模型、界面和 Markdown 接入 `ayanamsha_name`；Composite 填充双方 UTC；未知 mode 明确报错；IANA 时区拒绝 DST 缺失时刻，并要求重叠时刻传 `fold`。
- 新增 Harmonic 示例、真实输出 fixture 和 Swift 契约；重新生成 Vedic、Composite、Solar Arc、Horary fixtures。一键门禁通过：Python 555、Swift 50，classical/moment/scan/horary/vedic/harmonic smoke 全绿。
- 本轮为跨领域修复版本，发布号提升至 `1.3.0 (40)`。

## 2026-07-10 — 二轮审计 P1 静默算错修复（第一批）

- `DateTimeInput` 显示、文本解析与 DatePicker 统一使用界面选择的 GMT 时区，避免先按 Mac 系统时区生成 `Date`、提交时再按所选时区拆分造成数小时偏移。
- 现代 moment 在计算行星前启用 zodiac；宫位、Lots、行星与固定星现在使用同一黄道。现代本命请求新增 `sameChart`，移除自身相位、镜像相位及重复赤纬/固定星范围，普通时间点仍保留方向性。
- 窗口扫描请求补传 zodiac，后端 aspect/ingress/station 的粗扫、细化与精确位置统一传递 sidereal。
- Solar Arc 行星和角点改按响应中的推进宫头落宫；Primary Directions 复用 `house_for_longitude`，不再漏判第 12 宫太阳；固定星黄经支持 sidereal。
- 新增 Python/Swift 聚焦回归，覆盖黄道坐标一致性、同盘去重、扫描 zodiac、Solar Arc 落宫、第 12 宫太阳、固定星坐标和时间输入时区。
- 扫描 sidereal 参数保持默认值，现有 tropical 调用与测试 mock 无需改变计算语义。
- 一键门禁通过：Python 527、Swift 44、classical/scan/horary/vedic smoke 全绿；验证后清理 Swift/Python 构建与测试缓存。本轮未打包。

## 2026-07-10 — 二轮审计吠陀领域计算修复（第二批）

- Moon Chart 保留行星真实 rasi，仅把 house 改为从月亮星座起算；Bhava Chart 使用 D1 实际宫头和实际 ASC/MC/DSC/IC，不再固定 Whole Sign 或伪造 MC。
- 修正 Dhuma/Vyatipata/Parivesha/Indrachapa/Upaketu 五个太阳型 Upagraha 公式，避免成对重合并与项目期望材料对齐。
- Tatkalika 临时敌友改按两星相对宫位判定；修正 Hamsa、Malavya、Shasha、Rucaka、Bhadra 的本宫/旺宫成立集合。
- 修正 Shadbala Naisargika Bala 的 Venus/Jupiter/Mars 固定值映射；日出日落搜索起点改为出生地本地午夜对应的 UT；Vimshottari 余额月份规范到 0...11。
- 新增领域回归并与既有 focused/smoke 测试合跑，共 137 项通过。

## 2026-07-10 — 二轮审计古典与 Horary 修复（第三批）

- 扩展 Lots 的 `house:N` 改为使用实际宫头；contra-antiscia 改为 antiscion 对点；Moon 喜乐宫改回第 3 宫，行星停滞阈值按各自行星平均速度计算。
- Ptolemaic triplicity 不再复用 Dorothean 参与主表，水象昼夜主改为 Mars；无参与主的体系在详情和中世纪摘要中不再生成空行星。
- Horary 月亮事件在精确成相时重新计算双方经度与落宫；闰日年龄与周年日统一按 2 月 28 日回退；Circumambulations 每进入新星座重置界起点。
- Solar Return synthesis 使用实际 MC、实际 ASC/MC 主星及其真实落宫；古典主限摘要按参考年龄距离排序，meta 正确标注所选 sidereal 与非 Whole Sign 宫制。
- 新增 11 项聚焦回归；连同既有古典与 Horary 测试共 145 项通过。

## 2026-07-09 — 窗口扫描阈值与停止计算 + P1 bug 修复

- 窗口扫描工作量阈值改为三段：1.5M 软警告、2.5M 需确认后继续、5M 绝对上限；后端 `scan` 继续保留 5M 防线，并在 1.5M 以上结果 warnings 中记录高负载提示。
- 前端新增与后端一致的扫描工作量估算：按行运体步长、目标点数量、相位精确点数量计算；目标点计数同步忽略空行与 `#` 注释。
- 通用后端计算运行中，顶部按钮切换为「停止计算」；取消 Swift 任务时会终止正在运行的 Python 子进程，取消后不再把进度条显示为“完成 100%”。
- **P1 现代 tab 共享** — 切换现代子模式时重置 `modernSelectedTab` 到各模式默认 tab，避免 Progression→Synastry 等跨模式落 `default`、标题空串。
- **P1 古典 `planets` case** — 默认「行星状态」显式匹配，不再只靠 `default`。
- **P1 AI 侧滑对齐** — Synastry/Composite/Davison/Progression/Solar Arc 接入全局 AI 面板；去掉结果页内嵌 AI tab（Harmonic 仍无 AI）。
- **P1 后端静默回落** — Davison JD 失败改为抛错；Composite 宫位重建失败写 warning；Solar Arc 内部相位失败写 warning/`section_errors`；Panchanga 日出日落失败写 warning；Ashtakavarga 缺 ASC 写 notes 并上浮到 warnings。
- 新增 Swift/Python 回归；本轮按要求未打包。
- 评审修复：`currentRunTask` 用 run generation 防止停止后立刻重算时旧任务收尾清掉新任务；补 Panchanga 日出/日落失败 warning 测试。
- 评审修复：古典「重算全盘」改走 `startTrackedRun`，纳入可取消任务；`canStopCurrentRun` 要求 `currentRunTask != nil`，避免假停止。
- 评审修复：停止按钮基于任务属性 `currentRunIsStoppable`（启动时按任务类型捕获），不再读当前页面 `mode`；扫描中切到矫正仍可停，矫正主计算切到其他页也不会误出停止。

## 2026-07-07 — 第 6 期 UI 打磨：基于真机截图的细节修整 (1.2.3/39)

- **顶栏** — 档案胶囊去掉突兀的蓝色系统焦点环（`tsNoFocusRing()`，macOS 14+）；流派分段器不再整行拉伸，改为紧凑固定宽度；运行按钮标题缩短（「古典排盘」等），完整说明移入悬停提示。
- **表格** — 新增 `tsTableStyle()`：禁用斑马纹（消除数据下方一长串空条纹行）、表格融入圆角描边卡片；应用于古典/Horary/扫描/现代/吠陀全部 19 处 Table。
- **双标题冗余** — 参数栏大标题（eyebrow+pageTitle）压缩为单行小标题「参数 · ○○」，不再与右侧结果区大标题重复；`sidebarTitle` 去掉中间空格。
- **古典工具行** — 「导出 Markdown…」不再截断（fixedSize）、降为普通按钮，一行只保留「重算全盘」一个金色主按钮。
- **参数栏收起/图钉按钮** — 统一为无底色浅墨图标，图钉在前收起在后。
- **AI 手柄** — 内容改为垂直居中。
- **底部状态条（新增）** — 左侧 pyswisseph 状态（绿/橙圆点），右侧当前宫制·黄道（吠陀显示 ayanamsha）。
- **扫描时间轴** — 起止日期标签从压在圆点上、被窗口边缘裁切，改为轴下方左右对齐。
- **启动自动载入档案** — 启动时自动载入选中的本命档案，表单不再显示硬编码默认值（1990-01-01），与顶栏档案胶囊保持一致。
- 结果区页头纵向内边距收紧；`package_app.sh` 版本号升至 `1.2.3 (39)`。

## 2026-07-07 — 第 3–5 期 UI 重设计：垂直目录 + 扫描时间轴 + AI 侧滑面板 (1.2.2/38)

- **结果区垂直目录（古典 / Horary）** — 新增 `VerticalSectionNav` 组件（`ResultToolbarViews.swift`）；古典与 Horary 结果页把横向标签+「更多」菜单换成左侧竖排目录（主 section + 分隔线 + 诊断/JSON），导出按钮移到右上角一行。吠陀、现代、时间点结果页保持原有横向标签（吠陀按约定不动新视图）。
- **扫描时间轴（`ScanTimelineView.swift` 新建）** — 扫描结果新增"时间轴"视图（默认打开）：命中事件按日期铺在横向时间轴上，硬相位红点、软相位绿点、合相/入座/留金点，同日事件纵向堆叠，悬停显示"时间 行运体 相位 目标 orb"，轴上有月份刻度和起止日期，下方保留完整命中表格；"命中表格"标签保留纯表格视图。
- **AI 全局侧滑面板（`ContentView+AIPanel.swift` 新建）** — 各结果页的"AI 分析"标签全部移除（古典/现代本命/时间点/扫描/Horary/吠陀），改为右侧常驻竖条手柄，点击滑出 380pt 面板；面板自动绑定当前页面的分析上下文（streamKey / 已有分析 / 生成动作），无结果时提示先计算，矫正与现代高级模式提示暂不支持。AI 流式契约（streamBuffer / 每模式存储）不变。
- **星盘图外观切换兜底** — `ChartWheelView` 增加 `@Environment(\.colorScheme)` + `.id(colorScheme)`，切换浅色/深色时 Canvas 立即重绘。
- `CalculationViewModel.scanSelectedTab` 默认值改为 `"timeline"`；`package_app.sh` 版本号升至 `1.2.2 (38)`。

## 2026-07-07 — 第 2 期 UI 重设计：工作台布局重构 (1.2.1/37)

- **新建 `ContentView+TopBar.swift`** — 顶部常驻栏：品牌块（金圈+sun.max+Transit/STUDIO）、档案胶囊 Menu（person.crop.circle + 档案名 + 摘要 + chevron.down）、Spacer、流派分段器（ink 底）、运行按钮（`play.fill` / ProgressView），绑定 `runButtonTitle`/`runDisabled`。
- **ContentView.swift** — body 包进 `VStack(spacing: 0) { appTopBar; divider; HStack{原三栏} }`；新增 `@State isParamDrawerPinned`。
- **AppNavigationRail.swift** — 删除 `brandBlock`、`practiceSegmented`、`practiceSegment(_:)`、`practiceIcon(_:icon:)`，左导航只保留收起按钮、模式按钮、设置按钮。
- **ContentView+SidebarColumn.swift** — 收起条改为竖排「参数」窄条（宽 28、paperRaised 底、slider.horizontal.3 + 竖排文字 + chevron.right）；折叠按钮旁新增图钉按钮（`pin.fill` gold / `pin` inkFaint），绑定 `isParamDrawerPinned`，help "固定参数面板（计算后不自动收起）"。
- **ContentView+SidebarSections.swift** — 删除 `sidebar` 内 scan 模式的运行按钮（已上顶栏）。
- **ContentView+ResultsPanes.swift** — `runSection` 删除大运行按钮与 errorMessage 文本块，保留进度条与小行星准备消息；`resultsPane` 在 `Divider()` 后新增错误横幅（`exclamationmark.triangle.fill` + 错误文本 + × 关闭）。
- **ContentView+RunActions.swift** — `performRun` 中 operation 成功返回后，若无错误且未固定（`!isParamDrawerPinned`），自动收起参数栏。
- `PLANS.md` 更新第 2 期状态；`package_app.sh` 版本号升至 `1.2.1 (37)`。
- 验收修正：档案胶囊摘要改为读取**已保存档案**的出生数据（原实现误用侧栏当前编辑值，档案名与数据可能不一致）。

## 2026-07-07 — 第 1 期 UI 重设计：Dark Mode 换肤能力 (1.2.0/36)

- **DesignTokens.swift** — 新增 `import AppKit` + `TS.dyn()` 动态颜色 helper（NSColor.appearance）；全部 16 个 `SemanticColor` 和 4 个 `ElementColor` 从固定 `Color(red:…)` 换为 `TS.dyn()`（浅色值不变、深色=深空夜色）；注释更新为描述浅色/深色双皮肤。
- **ChartWheelGeometry.swift** — 19 个颜色常量的 12 个改为引用 `TS.SemanticColor.*` / `TS.ElementColor.*`，其余 7 个盘面特有常量用 `TS.dyn()` 动态化；常量名不变，调用处无感知。
- **AppState.swift** — 新增 `Key.appearance`、`@Published var appearance`（UserDefaults 持久化）和 `preferredScheme: ColorScheme?` computed 属性（"system"/"light"/"dark" 映射）。
- **ContentView.swift** — `.preferredColorScheme(.light)` 改为 `.preferredColorScheme(appState.preferredScheme)`，全局外观跟随设置。
- **AppSettingsView.swift** — 设置窗口 TabView 首位新增「界面」tab，含 `settingsTitle("外观", …)` 和 segmented Picker（跟随系统/浅色/深色），绑定 `$appState.appearance`。
- `PLANS.md` 更新第 1 期状态；`package_app.sh` 版本号升至 `1.2.0 (36)`。

## 2026-07-06 — 修复自定义星历目录导致固定星报错

- 修复设置里填了「Ephemeris 文件夹」（或下载小行星星历后被自动填入）时，古典排盘等所有模式报「固定星计算失败：未找到 sefstars.txt」的问题：之前一旦指定自定义目录，后端就完全不再查看 App 内置星历，而自定义目录里通常只有行星/小行星 `.se1` 文件。现在后端把「自定义目录 + 内置目录」用冒号拼成 Swiss Ephemeris 多目录搜索路径，自定义目录优先、缺的文件（如 `sefstars.txt`）自动回落到内置目录。
- 新增 `python_tests/test_fixed_stars.py::TestResolveEphePath` 5 个测试锁定该行为（507 → 512）。

## 2026-07-06 — 后端静默回落改为显式警告

- `set_zodiac_mode()` 新增可选 `warnings` 参数：传入无法识别的 zodiac（如拼写错误 `sidereal_lahri`）时不再静默按回归黄道计算，而是写入中文警告；11 处调用点（moment/classical/horary/vedic/synastry/composite/davison/progression/solar_arc/harmonic/rectify）全部接入。
- `build_houses()` 对无法识别的宫位制写入警告后再回落 Whole Sign；「宫位计算失败，改用 Whole Sign」警告增加去重，classical 模式极端纬度下不再重复出现约 20 条相同警告。
- `find_patterns()` 的星盘形状检测与 `detect_all_yogas()` 的单个 yoga 检测器崩溃时不再整段静默吞掉，改为写入 warnings（诊断页可见），其余结果照常返回。
- 新增 `python_tests/test_warning_visibility.py` 15 个测试锁定上述行为（492 → 507）。
- `check_vibe_changes.sh` 优先使用项目 `.venv` 的 Python（系统 Homebrew python3 升级到 3.14 后缺 pytest，门禁第一步会误报失败）。

## 2026-07-06 — 修复现代模式导出：Composite/Davison 空导出与假 CSV

- 修复 Composite / Davison 结果面板「复制 Markdown」「复制/保存 JSON」「复制/保存 CSV」全部输出空字符串的问题：`ChartResultFields` 协议补上 `meta` 要求，`MarkdownModernExportBuilder.compositeOrDavison` 合并为对协议的泛型重载，面板导出直接走真实 builder。
- 修复 Synastry / Progressions / Solar Arc / Harmonic 的「保存 CSV」把 JSON 内容写进 `.csv` 文件的问题：`TextExportBuilder` 为这五类现代结果（含 Composite/Davison 共用的 `ChartResultFields` 版本）新增真正的逗号分隔 CSV 构建函数，统一表头 `section,name,longitude,degree_text,latitude,speed,aspect_or_house,other,separation,orb`，导出行星位置、相位、宫位落点、图形模式等主表格。
- 新增 `SwiftTests/ModernExportTests.swift`，用真实后端 fixtures 回归锁定：Composite/Davison Markdown/JSON 非空、五类现代 CSV 表头正确且行数覆盖主表格、CSV 不再是 JSON。
- 后端 JSON 契约无改动（纯 Swift 导出层修复）。

## 2026-07-06 — 文档整理与项目审计

- 新增 `docs/project-audit-2026-07-06.md`，集中记录目录边界、文档组织建议、技术债、潜在未发现 bug 清单和下一步发展建议。
- 更新 `docs/README.md` 与 `docs/validation.md`，把审计文档接入现有文档索引和技术债入口。
- 继续代码审计并补充已复现问题：现代 time-based 模式忽略 UI 选择的 zodiac/house system、次限整点出生误报“出生时间不详”、现代高级诊断页不直观。
- 修复 Progressions / Solar Arc / Harmonic 的黄道与宫制请求契约：Swift 请求补齐顶层 `house_system` / `zodiac`，Python 后端兼容顶层字段并回退到 `birth` 内设置。
- 修复次限推进整点出生误报“出生时间不详”的 warning 判断。
- 现代高级结果页新增通用诊断视图，Synastry / Composite / Davison / Progressions / Solar Arc / Harmonic 的诊断页直接展示 warnings 与 section_errors，JSON 页继续保留原始输出。
- 新增 Python 与 Swift 回归测试覆盖上述请求契约和整点出生提示。
- `package_app.sh` 打包版本更新为 `1.1.13 (33)`，用于本轮修复后覆盖安装。

## 2026-07-02 — Expansion 002 代码评审修复（F1-F5）

- **F1** 修复 magistery 权威点公式文本：`_resolve_lot_ref()` 新增 `mc` 一等参数说明符，注册行改为 `"mc"`，删除特判分支，通用路径补传 `mc=mc_lon`，`_formula_text()` 新增 `"mc"→"MC"` 渲染。公式文本不再显示 `0°`。
- **F2** 单颗行星星历失败不再让整个 lots 计算崩溃：`calculate_lots()` 增加 `warnings` 参数，主循环包裹 `try/except KeyError`，失败的 lot 跳过并记录中文 warning。两个调用方补传 `warnings`。
- **F3** 年主星宫位标签增加边界守卫：引入 `_HOUSE_LABELS` 常量与 `house` 变量，`house_label` 取值加 `0 <= house <= 12` 判断，越界或缺失时安全返回空字符串。
- **F4** 删除 lots 模块 4 个死函数（`_day_night_simple`、`_resolve`、`_resolve_args`、`_make_calc`）及伴随注释，清理因删除失效的 `BODY_REGISTRY` import。
- **F5** fixed_stars 复用 core 的 `norm360` 与 `angular_separation`，消除内联重写。
- 新增回归测试：magistery 昼/夜数值与公式文本（F1）、缺行星容错（F2）、宫位标签越界守卫（F3）。
- `package_app.sh` 打包版本更新为 `1.1.12 (32)`。

## 2026-07-02 — 打包脚本使用预生成 AppIcon.icns

- 新增 `assets/AppIcon.icns`（用原逐像素生成逻辑一次性产出并提交）。
- `package_app.sh` 改为优先直接拷贝 `assets/AppIcon.icns`；仅当该文件缺失时才回退到原有的纯 Python 逐像素生成 + `iconutil` 流程。消除每次打包 1–2 分钟的重复图标生成及对 PATH 上 python3 的硬依赖（此前曾导致外部 Agent 打包卡死超时）。
- 验证：`SKIP_INSTALL=1 ./package_app.sh` ✅，产物内 `AppIcon.icns` 与提交文件逐字节一致。

## 2026-07-01 — Firdaria 主流算法接轨

- 修正 Firdaria 次限算法：七曜主限拆为 7 个等长次限，从主限星自身开始，按 `Sun → Venus → Mercury → Moon → Saturn → Jupiter → Mars` 循环轮转。
- 交点主限（North Node / South Node）不再生成七曜次限，并在 notes 中明确“交点主限不拆次限”。
- 新增 Firdaria 回归测试，锁定 Mercury 主限内 `Mercury → Moon → Saturn → Jupiter → Mars → Sun → Venus` 次限顺序与当前 Saturn 次限。
- `package_app.sh` 打包版本更新为 `1.1.11 (31)`，用于本轮算法修正后覆盖安装。

## 2026-07-01 — Expansion 002 Markdown 输出补全

- 古典 Markdown 导出补齐赤纬/OOB、赤纬平行/反平行相位、固定星合相与中世纪深化章节（Sect Light 三分主、Kurios/Oikodespotes、年主+Solar Return 综合）；对应字段存在但无命中时也输出空结果说明。
- 普通本命/行运 Markdown 位置表补齐赤纬/OOB，并输出本命/行运固定星合相与赤纬相位。
- 后端默认星历路径同时兼容源码 `Resources/ephemeris` 与打包后的 SwiftPM resource bundle 根目录，避免 `/Applications` 版本找不到 `sefstars.txt`。
- Swift 启动 Python 后端时设置 `PYTHONDONTWRITEBYTECODE=1`，避免运行后在 app bundle 内生成 `__pycache__` 破坏签名 seal。
- 新增 Markdown 导出回归测试，确保后端已计算出的 Expansion 002 数据实际出现在导出文本里。
- `package_app.sh` 打包版本更新为 `1.1.10 (30)`，用于本轮前端导出补齐后覆盖安装。

## 2026-07-01 — Expansion 002 复查修补

- 修正固定星目录中 `Zubenelschemali` 对应的 Swiss Ephemeris 名称为 `Zubeneshamali`，避免 bundled `sefstars.txt` 存在时仍误报星表缺失。
- 固定星失败 warning 区分星表文件缺失与单颗星名解析失败。
- 行运/本命赤纬 cross-aspect 改为只生成 natal-vs-transit 组合，避免同盘内相位被重复塞入 cross 分组。
- Swift 过滤 `declinationAspects` 时兼容 `natal_` / `transit_` 前缀，隐藏天体过滤不再误删有效 cross 赤纬相位。
- 后端 CLI 在请求未传 `ephemerisPath` 时默认使用 bundled `Resources/ephemeris`，让样例 smoke 也能计算固定星。
- 新增固定星 catalog 与 cross 赤纬相位 focused 回归测试。
- `package_app.sh` 打包版本更新为 `1.1.9 (29)`，用于本轮复查修补后覆盖安装。

## 2026-07-01 — Expansion 002 编码实施

- **Phase 1 - 赤纬管线**: `calculate_body()` 增加 declination / out_of_bounds 字段。提取 obliquity/dec/RA 到 core.py。新增 `find_declination_aspects()` 检测平行/反平行相位。Swift 模型同步扩展。
- **Phase 2 - 恒星合相**: 新建 `astro_backend_fixed_stars.py`，30 颗恒星目录 (4 王星 + 9 一等 + 17 二等)。使用 `swe.fixstar_ut()` 计算恒星位置，per-star orb 合相检测。bundled sefstars.txt 星表文件。
- **Phase 3 - 阿拉伯点扩展**: `astro_backend_classical_lots.py` 重写，12 点 → 56 点 (core 7 + life 24 + career 12 + spirit 10 + experimental 3)。新增 house cusp 和 house ruler 解析 helper。
- **Phase 4 - 中世纪技法深化**: 新建 `astro_backend_classical_medieval.py`，三分主星序列 (sect light)、Kurios/Oikodespotes 综合判定、年主+日返融合解读。Swift 模型同步。
- **测试**: 新增 4 个 Python 测试文件 (test_declination、test_fixed_stars、test_extended_lots、test_medieval)，共 39 个测试全部通过。

## 2026-07-01 — Expansion 002 规划文档

- 创建 `docs/expansion-002/` 目录，包含 5 份规划文档：
  - `README.md` — 扩展总览、执行顺序、影响范围
  - `fixed-stars-declinations.md` — 恒星与赤纬技术规格（赤纬管线、出界/平行/反平行相位、恒星合相检测）
  - `star-catalog.md` — 30 颗恒星目录（王星/一等/二等，含星等、行星性质、orb 规则）
  - `medieval-deepening.md` — 中世纪技法深化（年主+日返融合、50+阿拉伯点、三分主星、Kurios 判定）
  - `arabic-parts-expanded.md` — 53 个阿拉伯点完整公式表及日夜反转规则
- 更新 `PLANS.md` 记录两阶段扩展计划
- 修正计算规范：赤纬/OOB 改为 `FLG_EQUATORIAL` 或完整 `(λ, β, ε)` 转换；固定星改用 `fixstar2_ut` + `sefstars.txt` + 带逗号 nomenclature fallback；恒星合相入相改为角距缩小判定；补充 Kurios 与阿拉伯点实现边界。

## 2026-07-01 — 审计确认问题修复

- 修复吠陀行星关系枚举映射、Bhava 角点、Primary Directions 纬度接入、T-square 多体识别、Ashtottari 28 宿起运、月小限跨年、Arudha 对宫例外、Jaimini Rahu 逆算、后端超时文案、当前位置新鲜度/精度过滤、非法 stdin JSON 干净报错。
- 新增 focused 回归覆盖上述后端计算与异常路径。
- 验证：`/usr/local/bin/python3 -m pytest python_tests/test_patterns.py -q` ✅（26 passed）；`/usr/local/bin/python3 -m pytest python_tests/test_classical.py -q` ✅（76 passed）；`/usr/local/bin/python3 -m pytest python_tests/test_jyotish_focused.py -q` ✅（88 passed）；`swift build` ✅；`swift test` ✅（24 tests）；`PATH=/usr/local/bin:$PATH bash check_vibe_changes.sh` ✅（426 Python tests + Swift build/test + classical/scan/horary/vedic smokes）；单独 rectify smoke ✅。

## 2026-06-16 — UI 重设计：星历年鉴风格

- **设计系统重写（`DesignTokens.swift`）** — 改为固定的暖米色羊皮纸色板 + 单一金色点缀 + 衬线标题字（`.serif`），不再跟随系统浅/深色（App 全局 `.preferredColorScheme(.light)`）；新增 `AstroPalette` 帮助器，按星座（白羊/金牛…）映射四元素色、按相位 ID 映射刑冲/吉相/合相语义色
- **导航轨道（`AppNavigationRail.swift`）** — 古典/现代/吠陀改为衬线 segmented 控件（选中填墨黑），导航项分组为「星图 / 行运」并改金色软底选中态；折叠态降级为图标 segmented
- **结果区工具栏（`ResultToolbarViews.swift`）** — 填充式 TabChip 改为衬线下划线 tab，标题行与导出行合并为单行（tab 即标题），底部金/线分隔
- **表格（`TransitResultViews.swift`）** — `PositionTableView` / `AspectTableView` 由原生 `Table` 改为自定义羊皮纸表格：金色表头细线、元素色星座标签、逆行红色标记、相位强度色条；`ScanTableView` 保留原生（需排序）
- **折叠区 / 空状态 / 标题** — `CollapsibleSection` 改全大写小标签；`EmptyStateView` 加书卷花饰 `❧`；结果区与侧栏标题加金色 eyebrow + 衬线标题
- 验证：`swift build` ✅；`swift test` ✅（24 tests，解码契约 + 导出 + AI 流未受影响）；仅改 SwiftUI 视图层，Python 后端与导出逻辑未触碰

## 2026-06-16 — 审计确认 bug 修复

- **后端边界修复** — Horary 月亮换座 fallback 遇异常速度时改用 2.5 天默认值并写 warning；宫位失败回退改为 Whole Sign；JSON 输出禁用 NaN/Inf；Composite 局部异常不再静默吞掉；Classical timing 子周期除法补零值保护
- **Swift 与仓库卫生** — BackendClient Python 子进程超时从 60s 提升到 300s；`.gitignore` 加入 `reasonix.toml` 与 `.reasonix/`
- 验证：`bash check_vibe_changes.sh` ✅（416 Python tests + Swift build + 24 Swift tests + smokes）

## 2026-06-12 — Horary 慢行星成相窗口与高级判定补修

- **慢行星成相窗口** — `exact_datetime_for_signature()` 改为按双方最早换座时间动态决定搜索窗口，修复木星/土星等慢行星超过 30 天才成相却被误报不成相的问题
- **高级判定与月亮列表** — `before_sign_exit_aspects` 不再截断到 8 条，避免 Moon-Matter 链接漏掉第 9 条之后的成相；`_detect_frustration()` 补上真实受挫检测
- **`python_tests/test_horary.py`** — 新增 2016-11-06 木星六合土星慢相位真实星历回归、月亮换座前列表完整性回归与 Frustration detected 回归；刷新 `SwiftTests/Fixtures/horary-result.json`
- **`package_app.sh`** — 打包版本更新为 `1.1.7 (26)`，用于本轮 Horary 修复后覆盖安装
- 验证：`python3 -m pytest python_tests/test_horary.py` ✅（56 passed）；`python3 -m pytest python_tests/test_scan.py` ✅（31 passed）；`python3 -m pytest python_tests/test_classical.py` ✅（72 passed）；horary smoke ✅；`swift build` ✅；`swift test` ✅（24 tests）；`bash check_vibe_changes.sh` ✅（416 Python tests + Swift + smokes）；`./package_app.sh` 覆盖 `/Applications/TransitStudio.app` ✅，安装版本 `1.1.7 (26)` 且 codesign verify ✅

## 2026-06-11 — Horary 成相时间与入离相修复

- **`astro_backend_horary.py`** — 精确相位扫描改为有符号相位分支，合相/冲相不再因无符号角距而漏算；月亮换座时间改用星历扫描 + 二分精算，`perfects_before_sign_exit` 会检查双方是否先换座
- **`astro_backend_classical.py`** — `applying_label()` 改为基于当前有符号 orb 与相对速度的瞬时判定，修复月亮几小时后成相却被标成“离相”的问题
- **Horary 关键链路** — 内部相位 geometry 统一比较 `"degree"` / `"sign"` / `"co_presence"`，关键相位使用请求 `aspectOrb`，月亮特例也输出中文“入相”
- **高级判定** — Translation / Collection / Prohibition 改按离相/入相和精确时间顺序判定；Frustration 不再把任意离相直接报成 detected
- **Horary xhigh 补修** — 同一颗行星同时担任多个角色时不再产生 self-aspect 假成相；Translation / Collection / Prohibition / Frustration 统一排除同星主相位；负接纳相位阈值接入请求 `aspectOrb`
- **驻留与换座标签** — Horary 驻留判定从固定 `0.05°/day` 改为按行星平均速度比例；scan 逆行换座的 `target_name` 改为实际退入的星座
- **Moon storyline 收尾修复** — `before_sign_exit_aspects` 会排除目标行星在 exact 前先换座的相位；月亮故事线内部改用真实 `datetime` 排序/过滤，不再依赖分钟字符串；月亮特例关键链接显示当前 orb，不再把未来 exact 写成 `0.0`
- **`python_tests/test_horary.py`** — 新增合相/冲相真实星历、月亮入相、degree geometry、换座前成相过滤与高级判定误报回归；刷新 `SwiftTests/Fixtures/horary-result.json`
- **`package_app.sh`** — 打包版本更新为 `1.1.6 (25)`，用于本轮 Horary 修复后覆盖安装
- 验证：`python3 -m pytest python_tests/test_horary.py` ✅（53 passed）；`python3 -m pytest python_tests/test_scan.py` ✅（31 passed）；`python3 -m pytest python_tests/test_classical.py` ✅（72 passed）；horary smoke ✅；`swift build` ✅；`swift test` ✅（24 tests）；`bash check_vibe_changes.sh` ✅（413 Python tests + Swift + smokes）；`./package_app.sh` 覆盖 `/Applications/TransitStudio.app` ✅，安装版本 `1.1.6 (25)` 且 codesign verify ✅

## 2026-06-10 — AI 流式输出二次卡顿修复

- **`ContentView+AI.swift`** — 流式消费 helper 显式 `nonisolated`，token 累积与节流判断不再跑在 MainActor；只有每 ~100ms 的 delta flush 回主线程更新 UI
- **`LLMAnalysisClient.swift`** — DeepSeek V4 请求的 `max_tokens` 提升到官方最大输出 `384000`；DeepSeek 请求显式发送 `thinking.enabled/disabled`；流式解析开始读取 `finish_reason`，`length` / `content_filter` / 资源不足等非正常结束会保留已收到文本并提示截断原因
- **`AppState.swift`** — 新安装默认 AI Base URL / 模型改为 `https://api.deepseek.com` + `deepseek-v4-flash`，模型列表默认包含 `deepseek-v4-pro`
- **`AIAnalysisViewModel.swift`** — `AIStreamBuffer` 从发布 growing full string 改为追加 streaming segment，并只发布轻量 `revision`，避免 flush 后继续写入字符串触发 COW 全文拷贝
- **`AIAnalysisView.swift`** — 流式阶段用分段 `LazyVStack` 渲染增量文本，不再每 tick 对 `Text(完整长文)` 全文重排；复制按钮改为点击时读取当前流文本，流式阶段不启用长文本 selection
- **`SwiftTests/AIStreamBufferTests.swift` / `LLMAnalysisClientTests.swift` / `AppStateTests.swift`** — 新增 buffer delta 追加、真实换行保留、DeepSeek 最大输出预算、thinking 开关与默认 LLM 设置测试
- **`package_app.sh`** — 打包版本更新为 `1.1.5 (24)`，用于本轮 DeepSeek V4 输出预算修复后覆盖安装
- 验证：`swift build` ✅；`swift test` ✅（24 tests）；`bash check_vibe_changes.sh` ✅；单独 rectify smoke ✅；`./package_app.sh` 覆盖 `/Applications/TransitStudio.app` ✅；安装包版本 `1.1.5 (24)` 与 codesign verify ✅

## 2026-06-10 — 文档同步

- **`AGENTS.md`** — 验证清单加入 `check_vibe_changes.sh` 一键门禁与契约 fixture 再生成说明；smoke 列表补 horary/vedic；新增"AI 流式契约"与"结果页 Tab 契约"两节防回归约定；Source of Truth 补 Fixtures 与 CI
- **`docs/project-structure.md`** — 同步拆分后的视图文件结构、状态对象（AppState / CalculationVM / AIVM / AIStreamBuffer）、DesignTokens、Fixtures、CI、check_vibe 脚本
- **`docs/validation.md`** — 新增一键门禁与 CI 说明、`BackendContractTests` 过滤器、契约 fixture 再生成流程、"新增 tab 必须补 case"检查项
- **`PLANS.md`** — 已完结的前端重构批次归档至 `docs/archive/plans-frontend-refactor-2026-06.md`，补记本日三个任务（流式修复 / 体检加固 / 文档同步）

## 2026-06-10 — 全项目体检：tab 修复 + 防腐加固

- **修复吠陀页 3 个失灵 tab** — "AI 分析" / "诊断" / "JSON" 之前点击只显示综览（switch 缺 case）。AI 分析现已接入完整流式管线（`aiVM.vedicAnalysis` + `analyzeVedicResult`，streamKey "vedic"）；诊断显示后端 warnings；JSON 显示原始结果
- **tab 标题查表化** — 全部 11 个结果页的 `xxxTabTitle` switch 改为 `resultTabTitle()` 从 tab 列表查表，消灭"标题与列表漂移"问题类（vedic 的 varga/relationships/ai、synastry 的 A入B宫 等 5 处既有漂移一并治愈）；classical 引入 `classicalAllTabs` 单一定义源
- **小行星下载校验** — 下载内容校验 `SWISSEPH` 文件头，Dropbox 限流返回的 HTML 页不再污染星历目录（应用内 + 手动 curl 脚本两处）
- **后端契约测试** — 新增 `BackendContractTests`（7 个），用后端真实输出 fixture 解码 Vedic / Synastry / Composite / Davison / Progression / SolarArc / Horary，后端改字段名会测试报错而不是页面空白；Swift 测试 10 → 17 个
- **计算动作去重** — `performRun` 统一 14 处 isRunning/错误处理/进度样板；新增 `requireCoordinates` / `makeBirthSettings` / `makePersonPair` / rectify 请求构建助手
- **大文件拆分** — `ClassicalResultViews`（1464 行）拆为表格 + `ClassicalTimingViews` + `ClassicalOverviewViews`；`ContentView+ResultsPanes`（1119 行）拆为基础页 + `ClassicalPane` + `ModernPanes` + `VedicRectifyPanes`
- **CI** — 新增 GitHub Actions：每次 push 自动跑 swift build/test + pytest + 5 个后端 smoke
- **仓库卫生** — 已完成的计划文档归档到 `docs/archive/`；补 `Examples/sample-horary-request.json`；`check_vibe_changes.sh` 加入 swift test 与 horary/vedic smoke；删除废弃分支（`fix/bug-sweep-may2026` 留有 `archive/` tag 可找回）；重构分支已推送 GitHub
- 验证：`swift build` ✅；`swift test` ✅（17 tests）；pytest ✅（393）；horary/vedic smoke ✅

## 2026-06-10 — 修复 AI 流式输出越来越慢直至卡死

- **根因**：每个 SSE token 都全量重发布 + 全量重渲染，单 token 成本随累积文本线性增长（O(n²)），主线程饱和后消费循环被压死
- **`ContentView+AI.swift`** — 流式消费循环按 ~100ms 节流发布；累积文本流式期间只写入 `AIStreamBuffer`，结束时一次性写入每模式持久存储（出错也保留已收到的部分文本）
- **`AIAnalysisViewModel.swift`** — 新增 `AIStreamBuffer`（独立 ObservableObject），流式热路径只让 `AIAnalysisView` 重渲染，不再每 token 失效整个 ContentView 树
- **`AIAnalysisView.swift`** — 流式期间用纯 `Text` 渲染增量文本；markdown 分块解析推迟到流结束后一次完成，且解析结果缓存在 `@State`（`onAppear`/`onChange` 时才重算），不再每次渲染逐行重跑 `AttributedString(markdown:)`
- **`LLMAnalysisClient.swift`** — SSE 解析从逐字节 async 迭代改为 `bytes.lines`
- **`AIAnalysisView` 增加 `streamKey`** — 各结果页（moment/scan/classical/horary/modern 各子模式）声明自己的流标识，避免流式文本串台到其他面板
- 验证：`swift build` ✅；`swift test` ✅（10 tests）

## 2026-06-10 — ViewModel 并发收口

- **`CalculationViewModel.swift` / `AIAnalysisViewModel.swift`** — 补上 `@MainActor` 标注，与 `AppState` 一致，由类型系统保证 `@Published` 属性只在主线程更新
- **`CalculationViewModel.progressTask`** — 去掉 `@Published`（Task 句柄不是 UI 状态，发布只会触发多余的视图刷新）
- 验证：`swift build` ✅；`swift test` ✅（10 tests）；`pytest python_tests/` ✅（393 passed）；后端 classical smoke ✅

## 2026-06-10 — Tier 3 视觉总审：全量 token 化 + GroupBox 清除

- **彻底移除 GroupBox** — 全代码库不再有任何 `GroupBox`。导出区 section 卡片、`ShadbalaRowView`、`ContentView+TargetControls` 的目标/小行星/相位段等最后残余的 GroupBox 全部改为轻量卡片（VStack + `cardBackground.opacity(0.5)` + `RoundedRectangle(TS.Radius.card)`）或纯 VStack
- **Header 精简** — 结果页头部去掉冗余副标题与卡片底色，主标题用 `TS.Font.pageTitle`，副标题 `.tertiary`
- **全量 token 化** — 清除所有裸 `.font(.headline/.caption/.caption2/.subheadline)`、裸 `spacing:`/`.padding(N)`/`cornerRadius: N` 数字字面量，统一到 `TS.Font` / `TS.Spacing` / `TS.Padding` / `TS.Radius`。涉及 `AppNavigationRail`、`ContentView+ResultsPanes`、`ContentView+SidebarSections`、`ContentView+TargetControls`、`AppSettingsView`、`AIAnalysisView`、`PrimaryDirectionRectifierView`、`DateTimeInput`、`VedicResultViews`、`ClassicalResultViews`、`HoraryResultViews`、`TransitResultViews`、`ModernResultViews`、`ChartWheelView` 等
- **新增轻量卡片组件** — `HorarySectionCard`（14 处 Horary GroupBox 替换）、`TimingSectionBox` 重写为卡片样式
- **刻意保留** — `WheelTooltip` 使用固定像素 `.system(size:)`（chart 画布叠加层，需精确像素而非 Dynamic Type）；设置页 `TextEditor` 用 `.body`（编辑舒适度）
- 验证：`swift build` ✅；`swift test` ✅（10 tests passed）；后端 smoke（classical / modern）✅；release 打包 ✅

## 2026-06-09 — 前端重构修复与视觉规范收口

- **`AppState.swift` / `TransitStudioApp.swift` / `ContentView.swift` / `AppSettingsView.swift` / `AIAnalysisView.swift`** — 将前端设置状态改为共享 `ObservableObject`，修复 `@AppStorage` 被抽离后产生的响应式失效；AI 面板、设置页与运行请求现在读取同一份实时状态
- **`VedicResultViews.swift`** — 恢复 `VedicNavamsaView` 的实际内容展示，不再出现空白 Navāṃśa tab；同时收口 Dasa 时间轴与概要卡片样式到 TS token
- **`VedicPanchangaView.swift` / `VedicDivisionalChartView.swift` / `VedicJaiminiView.swift` / `VedicAshtakavargaView.swift` / `VedicRelationshipsView.swift` / `VedicMiscDataViews.swift`** — 按 `docs/frontend-refactor/09-visual-design-spec.md` 改为模板化布局（Grid / Table / segmented-or-menu / EmptyStateView），统一字体、间距、等宽数值与空状态表现
- **`ResultToolbarViews.swift` / `ResultUtilityViews.swift` / `ContentView+ResultsPanes.swift` / `ClassicalResultViews.swift`** — 调整结果页标题层级、空状态、告警区与古典 timing 卡片，使结果区风格与 09 规范一致
- **`package_app.sh`** — 打包版本更新为 `1.1.2 (21)`，用于本轮前端重构与修复后的覆盖安装
- **`docs/frontend-refactor/10-handoff-status-2026-06-09.md`**（新）— 新增 00-09 前端重构交接文档，逐模块记录已完成内容、落地文件、剩余缺口与验证结论，便于下一位 agent 或人类维护者继续接手
- 验证：`swift build` ✅；`swift test` ✅（10 tests passed）

## 2026-06-xx — 前端重构：Design Tokens + 组件 + ViewModel 提取 + 数据视图补全

- **`DesignTokens.swift`** (新增) — 建立 `TS` 全局设计 token 体系（Spacing / Padding / Font / Radius / Color / Opacity / Layout）
- **`CollapsibleSection.swift`** — 去掉 GroupBox 包装，改用 VStack + Divider + TS token
- **`ResultToolbarViews.swift`** — Tab 栏从二维网格改为一维水平滚动（TabChip + ScrollView），提供兼容过渡 init；迁移全部 11 个调用者
- **`AppState.swift`** (新增) — 从 ContentView 提取 21 个 `@AppStorage` 属性到独立类
- **`CalculationViewModel.swift`** (新增) — 从 ContentView 提取结果 / 运行状态 / Rectify 状态 / Tab 选择（共 ~30 个 `@State`）
- **`AIAnalysisViewModel.swift`** (新增) — 提取 AI 分析相关 `@State`（~12 个属性）
- **`ExportControls.swift`** (删除) — 确认无调用者后移除
- **吠陀 View 补全**: 新建 `VedicPanchangaView` / `VedicDivisionalChartView` / `VedicJaiminiView` / `VedicAshtakavargaView` / `VedicRelationshipsView` / `VedicMiscDataViews` + Dasa Container 增强（Vimshottari / Yogini / Ashtottari 切换）
- **`ClassicalResultViews.swift`** — ClassicalTimingView 顶部插入 BirthdayTransition + ActivatedLordFocus 卡片
- **`AIAnalysisView.swift`** — 模型/提示词/备注移入 DisclosureGroup 折叠区，标题行精简
- **`package_app.sh`** — build 号升至 20

## 2026-06-06 — 用户样例 ACG 个人计算（跟踪记录）

- **`PLANS.md`** — 追加用户样例 ACG 计算任务，记录已确认出生资料与本次采用的标准 `in mundo astrocartography` 口径
- 本次预期为一次性本地计算，不修改产品源码接口；最终结果以对话输出为准

## 2026-06-06 — ACG 地图算法口径核实（跟踪记录）

- **`PLANS.md`** — 追加一条 ACG / astrocartography 研究与个人计算准备任务，明确本次先核实算法口径、区分 ACG / Local Space / Relocation chart，并确认项目后端可复用 `Swiss Ephemeris` 与宫位计算基础
- 本次未修改产品源码；若要输出个人 ACG 结果，仍需用户提供出生年月日、精确出生时间、出生地与时区

## 2026-06-06 — P0 修复：窗口扫描开始按钮恢复

- **`ContentView+ResultsPanes.swift`** — 共享 `runSection` 不再错误排除 `mode == .scan`；窗口扫描现在重新显示主执行按钮并可触发 `runCurrentMode()`
- **`ContentView+SidebarSections.swift`** — 删除未接线的 `scanSidebarActionBar` 死代码，避免后续误判为“扫描入口已存在”
- **`package_app.sh`** — 打包版本从 `1.1.0 (17)` 提升到 `1.1.1 (18)`，用于本次 P0 修复后的覆盖安装

## 2026-06-06 — scan 启动按钮移至标题栏

- **`ContentView+SidebarSections.swift`** — 窗口扫描模式的主启动按钮从底部共享运行区移动到侧边栏标题行右侧；scan 模式不再显示底部重复入口，其他模式布局保持不变
- **`package_app.sh`** — 打包 build 号从 `18` 提升到 `19`，用于本轮窗口扫描入口布局调整后的重新覆盖安装
- **`package_app.sh`** — 补强扩展属性清理逻辑，显式移除 `com.apple.FinderInfo` / `com.apple.fileprovider.fpfs#P` / `com.apple.provenance`，修复本轮覆盖安装时 `codesign` 因 detritus 失败的问题
- **`package_app.sh`** — 打包流程改为先在 `/private/tmp` staging 目录组装并签名，再同步到 `dist/` 与 `/Applications`，规避 `dist/` 路径上的 File Provider 扩展属性再次污染签名产物

## 2026-06-06 — Git 历史遗留清理与流程文档加固

- **`AGENTS.md`** — 强化 Git 规则：明确“本地提交不等于 GitHub 已同步”，要求在声明完成前检查 `git status --short --branch` 与 `git log origin/main..HEAD`；要求在脏工作树中先分拣任务边界、关闭过期的 `PLANS.md` in-progress 项，并在 push 前保证提交边界与 `PLANS.md` / `CHANGELOG.md` 对齐
- **`README.md`** — 新增“Git 卫生”小节，给人类维护者一套最小自查流程，避免再次混淆本地提交与远端同步状态
- **`docs/README.md`** / **`docs/git-workflow.md`**（新）— 新增面向仓库协作的 Git 流程文档，覆盖起始状态检查、任务边界、review 前检查、push 前确认和 push 后核验
- **`PLANS.md`** — 将遗留的“提交并覆盖安装”条目标记为 `superseded`，避免后续继续把已经失效的 in-progress 记录当作活跃任务
- 本次目标不是修改业务逻辑，而是清理 Git / 文档层面的历史遗留，降低再次出现“任务混写、状态误判、未 push 误以为已上 GitHub”的概率

## 2026-06-06 — AI 分析流式输出整理与审查修正

- **`LLMAnalysisClient.swift`** — 新增流式 AI 分析能力，支持 `content` + `reasoning` 双流块输出；补上 UTF-8 安全的 SSE 行解析，避免按单字节拼接导致中文 token / reasoning 文本损坏
- **`AIAnalysisView.swift`** — 新增流式阶段显示与可折叠思考过程区块，按钮状态从「思考中」到「生成中」动态切换
- **`AppSettingsView.swift`** — AI 设置中新增 `aiReasoningEffort` 选项，允许关闭或调整 reasoning effort
- **`ContentView+AI.swift` / `ContentView.swift` / `ContentView+ResultsPanes.swift`** — AI 分析改为流式消费；现代模式的 AI 正文与思考过程改为按 `synastry/composite/davison/progression/solar_arc` 分桶存储，修复不同 pane 间串台
- **`ModernResultViews.swift`** — Synastry / Composite / Davison / Progression / Solar Arc 的 `AI分析` tab 正式接入 `AIAnalysisView`
- **`MarkdownModernExportBuilder.swift`** — 为 `DavisonResult` 补齐 `compositeOrDavison` 导出重载，避免现代模式 AI 入口编译失败
- 验证：`swift build` 通过；代码审查中发现并修复了 2 个真实问题
  - SSE 逐字节字符串拼接会破坏 UTF-8 流式输出
  - 现代模式共用一份 AI 状态会导致不同结果 pane 的分析内容互相覆盖
  - `swift test` 仍需越过沙箱写 SwiftPM 用户缓存，当前执行环境未放行

## 2026-06-04 — Vedic horoscope 输出硬伤修复

- **`astro_backend_jyotish.py` / `astro_backend_api.py`** — 吠陀模式支持基于地点回退时区（中国坐标默认 `Asia/Shanghai`），统一按标准 UTC 偏移生成 `birth_local` / `birth_utc` / `timezone_label` / `utc_offset_text`，并在 D1 whole-sign 锚点校验失败时提前报错 `timezone or birth UTC conversion failed.`，停止派生输出
- **`astro_backend_jyotish_panchanga.py`** — 修正 Karana 序列起点，避免把本应为 `Gara` 的结果算成 `Vanija`
- **`astro_backend_jyotish_divisional.py`** — 修正 D1 分盘宫位映射与 Moon Chart 度数显示；Moon Chart / D1 分盘不再出现超过 30° 的星座内度数，D1 分盘宫位改为相对 varga ASC 计算
- **`astro_backend_jyotish_data.py` / `astro_backend_jyotish_relationships.py`** — 按经典七曜修正天然敌友表，并将 Rahu/Ketu 从经典 Naisargika 表中剥离，避免错误混表
- **`astro_backend_jyotish_shadbala.py`** — 将当前 Shadbala 输出明确标记为 `incomplete`，取消 `meets_required` / `display_summary` 的误导性“达标/未达标”判断
- **`astro_backend_jyotish_yoga.py`** — 移除过度泛化的 `RajaYogaGeneric`，并把现有简化 yoga 输出统一标记为 `condition_only` / `needs_strength_check`
- **`VedicResultModels.swift` / `MarkdownVedicExportBuilder.swift` / `VedicResultViews.swift`** — 同步新字段并修正导出/界面显示：补充出生 UTC、去掉裸数字星座索引展示、分盘/Moon Chart 改显示星座名、Shadbala 改显示“不完整”、Yoga 改显示条件性标记
- **`python_tests/test_jyotish_smoke.py` / `python_tests/test_jyotish_focused.py`** — 新增 2004-08-09 Linyi / Asia-Shanghai 样例断言，覆盖 UTC 转换、D1 anchor、Panchanga、Vimshottari、Moon Chart 度数、时区默认回退与 Shadbala incomplete 契约

## 2026-06-04 — README 功能同步

- **`README.md`** — 按当前代码事实重写产品概览，从“现代 + 古典”更新为“现代 + 古典 + Horary + 吠陀”
- 同步补充吠陀 / Jyotish 工作流能力：Panchanga、日出日落、16 个主分盘、Moon / Bhava Chart、Arudha、Jaimini Karakas、Ashtakavarga、Dasa、Shadbala、Vedic Yogas
- 新增“导出能力”说明，区分现代、古典、Horary、吠陀的 Markdown / JSON / CSV 覆盖面
- 在“直接运行后端”中补入 `Examples/sample-vedic-ai-request.json`
- 新增“吠陀模式输出范围”小节，列出当前 `mode: "vedic"` 的主要返回块及 `kalachakra_dasa` 仍为占位的事实

## 2026-06-04 — P0 fixes: solar_day, Vara, divisional nakshatras, D9 aux points

### P0#1 — `solar_day` 日出日落不产出数据
- **`astro_backend_jyotish_panchanga.py`** — 重写 `calc_sunrise_sunset()`：用 `swe.rise_trans()`（原不存在的 `rise_transit` 改名），常量修正
- **`astro_backend_jyotish.py`** — 调用时从 `birth.moment` 直接计算 `jd_0h` 传入

### P0#2 — Panchanga Vara 星期错误
- **`astro_backend_jyotish_panchanga.py`** — `calc_vara()` 增加 `utc_offset_hours` 参数，用本地日期算 weekday
- **`astro_backend_jyotish.py`** — 调用传入标准时区偏移

### P0#3 — 分盘度数/Nakshatra 未按分盘重算
- **`astro_backend_jyotish_varga.py`** — 新增 `calc_varga_longitude()` 返回完整分盘经度
- **`astro_backend_jyotish_divisional.py`** — 改用 `calc_varga_longitude` 计算度数/nakshatra

### P0#4 — D9 的 Upagraha/Special Lagna 原样复制 D1
- **`astro_backend_jyotish.py`** — D9 点位通过 `calc_varga_longitude(lon, 9)` 映射到 D9

## 2026-06-04 — Review round 2: D2 Hora 重算 + 测试值断言

### P1#2 — D2 Hora 映射到 Virgo 而非 Leo/Cancer
- **`astro_backend_jyotish_varga.py`** — D2 公式修正：Odd 首半 → Leo(120)，Odd 后半 → Cancer(90)，Even 首半 → Cancer(90)，Even 后半 → Leo(120)。D2 分盘只使用 Leo 和 Cancer 两个符号
- 影响：D2 Sun/Mars/Jupiter 正确落在 Leo(星座:5)，Mercury/Venus/Saturn 正确落在 Cancer(星座:4)

### 测试增强
- **`test_jyotish_focused.py`** — 新增 `TestDivisionalReferenceValues`（9 项）：按 `sample-vedic-ai-expected.txt` 锁定 D2 六个行星的 rasi、nakshatra、lord、degree 值断言
- 重写 `test_divisional_nakshatra_uses_varga_lon`（原来只 print 无断言），改为断言 D2 Sun 的 nakshatra 从 natal Ashvini 变为 Magha

### 验证
- `python3 -m pytest python_tests/test_jyotish_smoke.py test_jyotish_reference_verify.py test_jyotish_focused.py -q` — 160 passed
- `swift build` — Build complete
- `swift test` — 10 passed in 5 suites
- 端到端：D2 六个行星的 rasi/nakshatra/lord/degree 全部与样例一致

### P1#1 — 时区因 DST 显示 UTC+9 而非 UTC+8
- **`astro_backend_jyotish.py`** — `_build_expanded_meta()` 改用标准 UTC 偏移（通过 1 月 1 日 `utcoffset()` 获取，避免 DST）；`calculate_vedic()` 计算 JD 时使用固定标准偏移（`timezone(timedelta(hours=std_offset))` 而非 ZoneInfo），使行星位置与中国占星惯例一致
- 影响：行星经度与预期文件匹配（Sun 从 DST 的 5.92° 恢复为 5.96°）

### P1#2 — D2 Hora 公式未使用连续加倍
- **`astro_backend_jyotish_varga.py`** — D2 改用 `(rasi_len % 15) * 2` 度数计算 + 动态符号偏移（Odd 首半 → 150/Virgo，Odd 后半 → 120/Leo，Even 首半 → 120/Leo，Even 后半 → 150/Virgo），每个 15° 半区映射为完整 30° 分盘符号
- 影响：D2 结果与预期文件全部匹配（±1' 以内）

### P2#3 — 分盘 ASC 仍用本命 Nakshatra
- **`astro_backend_jyotish_divisional.py`** — ASC 的 `nakshatra` 改为 `_nakshatra_summary(asc_v_lon)`（基于分盘经度）

### P3#4 — `utc_offset_text` 双加号 bug
- **`astro_backend_jyotish.py`** — 格式化改为 `UTC+{std_offset_hours:.2f}`（移除 `+` 格式说明符）

### 验证
- `python3 -m pytest python_tests` — 151 passed
- `swift build` — Build complete
- `swift test` — 10 passed in 5 suites
- 端到端：时区显示"东8区/UTC+8.00"、D2 Sun/Mars/ASC 符号和经度与预期匹配

### 测试增强
- **`test_jyotish_focused.py`** — 增加 6 项值正确性测试：Vara 值验证（1990-04-20 应为周五）、sunrise/sunset 返回非 None、D9 upagrahas ≠ D1、D9 special_lagnas ≠ D1、divisional nakshatra 基于分盘经度

### 验证
- `python3 -m pytest python_tests` — 151 passed
- `swift build` — Build complete
- `swift test` — 10 passed in 5 suites
- 全量端到端：`transit_calc.py < sample-vedic-ai-request.json` 确认 4 项 P0 修复全部验证通过

## 2026-06-04 — Vedic AI 导出完全移植

### Python 后端 — 新增 7 个模块

- **`astro_backend_jyotish_panchanga.py`**（新）— Panchanga 五支历（Tithi/Vara/Nakshatra/Yoga/Karana）+ 日出日落 Swiss Ephemeris 计算
- **`astro_backend_jyotish_divisional.py`**（新）— 16 分盘构建器（D1-D60），月盘（Moon Chart）、Bhava 盘；统一 chart schema
- **`astro_backend_jyotish_aux_points.py`**（新）— 11 种 Upagraha + 11 种 Special Lagna 计算（Dhuma/Vyatipata/Kaala/Gulika 等）
- **`astro_backend_jyotish_relationships.py`**（新）— 行星敌友关系（天然/临时/复合），含五级复合敌友分类
- **`astro_backend_jyotish_arudha.py`**（新）— Arudha Padas（AL/A2-A11/UL）
- **`astro_backend_jyotish_jaimini.py`**（新）— Jaimini Chara Karakas（Atma→Dara）
- **`astro_backend_jyotish_ashtakavarga.py`**（新）— BAV（Bhinnashtakavarga）+ SAV（Sarvatobhadra）基于 REKHA_MAP（Maitreya 公式直译）

### 扩展已有模块

- **`astro_backend_jyotish.py`** — 编排全部 7 个新模块；Antardasha 计算（9 子限/主限）；扩展 meta（timezone_label/ayanamsha_value/node_mode/sign_index_table）
- **`astro_backend_jyotish_shadbala.py`** — 增加 meets_required/required_rupas/display_summary 字段
- **`astro_backend_jyotish_yoga.py`** — 增加 8 个新瑜伽检测器（BudhaAditya/DharmaKarmadhipati/Adhi/Sunapha/Anapha/Subha/Yogakaraka/RajaYogaGeneric/Kedara/ArdhaChandra）

### Swift 层

- **`VedicResultModels.swift`** — 新增 25+ Codable 模型：Panchanga/SolarDay/DivisionalChart/MoonChart/BhavaChart/Relationships/Arudha/Jaimini/Ashtakavarga/Antardasha/Upagraha/SpecialLagna/ShadbalaSummary
- **`MarkdownVedicExportBuilder.swift`** — 完全重构，按样例 section 顺序输出全部 15 个章节
- **`MarkdownExportBuilder.swift`** — ExportSection 增加 7 个新 vedic section ID
- **`VedicResultViews.swift`** — 修复 Yoga description 可选兼容

### 测试

- **`python_tests/test_jyotish_focused.py`**（新 62 测试）— 覆盖 panchanga/solar_day/divisional_charts/moon_chart/bhava_chart/planet_relationships/arudha/jaimini_karakas/ashtakavarga/vimshottari.antardashas/shadbala_extra
- 现有全部测试通过：145 passed（smoke 35 + reference 48 + focused 62）

### 验证

- `python3 -m pytest python_tests/test_jyotish_smoke.py` — 35 passed
- `python3 -m pytest python_tests/test_jyotish_reference_verify.py` — 48 passed
- `python3 -m pytest python_tests/test_jyotish_focused.py` — 62 passed
- `swift build` — Build complete
- `swift test` — 10 passed in 5 suites
- `python3 .../transit_calc.py < sample-vedic-ai-request.json` — 21 个顶层 sections 全部返回，JSON 可被 Swift VedicResult 解码

### 剩余风险

1. **Ashtakavarga SAV/BAV 数值**与参考样例偏差明显（算法结构正确，但 REKHA_MAP 索引偏移或三宫/一宫净化细节需调优）
2. **日出日落**使用近似本地时计算（基于经度偏移），未使用准确的时区转换
3. **Upagraha/Special Lagna** 的部分公式为近似（Cal/Gulika/Maandi 用简化算法）
4. **Kalachakra Dasa** 仍为占位（需要完整的 Paka Lagna 系统）
5. **Kunda/Varnada Lagna** 公式为简版，与 Maitreya 的精确 Lagna 系统不同
6. 未做现代外行星（Uranus/Neptune/Pluto）的临时友谊计算（默认返回中性）
7. **Bhava Chart** 在非 Whole Sign 宫位制下可能不准确

## 2026-06-04 — Vedic AI 导出 handoff 资产

- **`VEDIC_AI_PORT_PLAN.md`** — 新增可直接交给实现 agent 的离线执行计划，明确了：
  - 本地 source of truth 文件
  - 需要参照的 `maitreya8` Jyotish 计算文件
  - Python / Swift 的职责边界
  - 目标输出 section、JSON 契约、拆分模块、测试要求、review 拷打点
- **`PLANS.md`** — 恢复为原有项目计划内容，不再覆盖
- **`Examples/sample-vedic-ai-request.json`** — 新增固定请求基准（1990-04-20 08:30，北京，`sidereal_citra`）
- **`Examples/sample-vedic-ai-expected.txt`** — 新增用户提供的完整 AI 导出样例，作为实现与 review 的对照基准
- **`.gitignore`** — 新增 `maitreya8-reference/` 忽略规则；该目录用于本地离线参考，不参与后续实现 diff
- **本地参考仓库** — 已抓取 `maitreya8-reference/` 供离线 agent 直接读取 `src/jyotish/` 相关实现文件

## 2026-06-04 — Vedic 能力评估（对照 Maitreya8）

- Review-only task: 依据当前本地 Jyotish/Vedic 实现与 `martin-pe/maitreya8` 的公开源码树，评估当前吠陀占星能力等级、已实现范围、简化实现、以及关键缺口。
- 结论方向：当前实现已超过“演示/玩具级”，具备可用的基础排盘、Nakṣatra、Ayanāṃśa、Vimśottarī/Yoginī/Aṣṭottarī、部分 Varga、简化 Ṣaḍbala、少量 Yōga、Swift UI 与 Markdown 导出；但距离 Maitreya8 的成熟 Jyotish 平台仍有明显差距，尤其在 Ashtakavarga、Jaimini、完整 Kalachakra、Transit/Partner 等系统。
- 验证：`python3 -m pytest python_tests/test_jyotish_smoke.py -q` 通过（35 passed）；另做了 `calculate_vedic(full=True)` 运行时烟雾检查，确认当前返回 `rasi_chart`、`planets`、`navamsa`、`vimshottari`、`yogini_dasa`、`ashtottari_dasa`、`shadbala`、`yogas`。
- 本条为评估记录，不涉及产品源码功能修改。

## 2026-06-04 — Vedic 修复: 6 个 review findings + 参考数据校核

### Bug 修复
- **[P1] Rahu/Ketu 名称反置** — `astro_backend_jyotish_data.py` + `astro_backend_jyotish.py` 中 RAHU=罗睺、KETU=计都 已更正
- **[P1] Dig Bala 未用真实 ASC** — `astro_backend_jyotish_shadbala.py` 算法改用行星的 Whole Sign 宫位(相对 ASC)而非绝对星座索引；caller 从 rasi_chart angles 提取 ASC 经度传入
- **[P2] Vimsottari Dasa 起始主星错误** — `astro_backend_jyotish_data.py` 修复 `vimsottari_dasa_index_for_nakshatra()` 公式，从 `(nak+7)%9`（适用 Maitreya 的主星顺序）改为查询 NAKSHATRA_LORD_IDS + VIMSOTTARI_LORD_ORDER 索引
- **[P2] Ayanamsha 回显永远 lahiri** — `astro_backend_jyotish.py` 改为从 `zodiac="sidereal_raman"` 提取 `ayanamsha="raman"`
- **[P2] House system 硬编码 Whole Sign** — `astro_backend_jyotish.py` `_calc_rasi_chart()` 改为接受 `house_system` 参数并传给 `build_houses()`
- **[P2] Yogini Dasa 只有 36 年一轮** — `astro_backend_jyotish.py` 改为循环生成多轮(最多 10×36 年)直到覆盖参考时间
- **[P2] Vedic 路由必填校验不完整** — `astro_backend_api.py` vedic 模式加入 `birth.moment.*` 嵌套校验

### 测试
- **`python_tests/test_jyotish_smoke.py`** — 26 项烟雾测试覆盖全部修复点
- **`python_tests/test_jyotish_reference_verify.py`** — 参考数据校核：行星位置/星座/Nakṣatra/Pada（24 项）、ASC、D9 Varga（8 项）、Vimśottarī 序列（9 主星顺序+时长）

### 验证
- `python3 test_jyotish_reference_verify.py` — 全部 44 项检查通过，与参考数据（True Citra, 1990-04-20 Beijing）完全一致
- `python3 test_jyotish_smoke.py` — 26/26 通过
- `swift build` — Build complete

### Python 后端 — 新增 6 个模块（~5,200 行）
- **`astro_backend_jyotish_data.py`** — 完整的 Jyotish 数据层：27 Nakṣatra 表（起止度/主星/梵文名）、Yoni/Gaṇa/Nāḍī/Tārā/Rajju 映射、11 种 Ayanāṃśa 常量、9 Graha 属性（Uccha/Nīca/Mūlatrikoṇa/Naisargika 友敌关系）、Graha Dṛṣṭi（含火星/木星/土星特殊相位）、Vimśottarī Daśā 常量
- **`astro_backend_jyotish_varga.py`** — Varga 分盘引擎（Maitreya 公式直译）：21 种分盘（D1-D60 + D108/D144 + Bhava），含 Hora/Drekkana/Chaturthamsa/Trimsamsa 等复杂映射的 Parasara/Continuous 两种模式
- **`astro_backend_jyotish.py`** — 核心排盘引擎：Rāśi D1 盘（Whole Sign + Sidereal）、Navāṃśa D9 盘映射、Nakṣatra 详细信息、Vimśottarī Daśā 三层次时间线、Yoginī Daśā、Aṣṭottarī Daśā、Kālacakra Daśā（占位）、Ṣaḍbala 评分、Yōga 检测、Rahu/Ketu 处理
- **`astro_backend_jyotish_shadbala.py`** — 六力评分（简化版）：Uccha Bala、Dig Bala、Pakṣa Bala、Nāthonaatha Bala、Naiṣargika Bala、Ceṣṭa Bala
- **`astro_backend_jyotish_yoga.py`** — Yōga 检测引擎：10 种检测器（Rāja/Dhana/Viparīta/Nābhasa 分组），可直接扩展
- **`astro_backend_core.py`** — 扩展 `set_zodiac_mode()` 支持 11 种 Ayanāṃśa（Lahiri/Raman/Krishnamurti/Yukteshwar/Surya Siddhanta 等）
- **`astro_backend_api.py`** — 注册 `mode == "vedic"` 路由与验证

### Swift 层
- **`VedicResultModels.swift`**（新 250 行）— 完整 Codable 模型：`VedicResult`、`VedicRasiChart`、`VedicPlanetPosition`（含 Nakṣatra）、`VimsottariResult`、`ShadbalaRow`、`VedicYoga` 等 20+ 结构体
- **`VedicResultViews.swift`**（新 260 行）— 结果视图：`VedicOverviewView`（信息卡片+星球表）、`VedicDasaTimelineView`（交互式时间轴）、`VedicShadbalaView`（评分柱状图）、`VedicYogaListView`（分组列表）、`VedicNavamsaView`
- **`OptionModels.swift`** — `PracticeMode` 增加 `.vedic` case
- **`AppNavigationRail.swift`** — 导航栏增加第三模式「吠陀」按钮 + 子导航
- **`ContentView.swift`** — 新增 `vedicResult`、`vedicAyanamsha`、`vedicSelectedTab` 状态
- **`ContentView+SidebarSections.swift`** — 新增 `vedicSettingsSection`（出生资料/参考时间/Ayanāṃśa选择/完整计算开关）
- **`ContentView+RunActions.swift`** — 新增 `runVedic()` 动作
- **`ContentView+ResultsPanes.swift`** — 新增 `vedicResultsPane`（含段落选择器：综览/Daśā/Ṣaḍbala/Yōga/Navāṃśa）
- **`ContentView+ScanTargets.swift`** — `hasNatalSourceForCurrentMode` 增加 `.vedic` case
- **`RequestModels.swift`** — 新增 `VedicRequest` Codable
- **`BackendClient.swift`** — 新增 `vedic()` 静态方法
- **`AstroConstants.swift`** — 新增 `allAyanamshas`、`vedicBodyIDs`、`vargaIDs`；扩展 `allZodiacs`（+4 种 sidereal 模式）
- **`ContentView.swift`** — 增加 `ayanamshaOptions` 静态常量

### 验证
- `swift build` — Build complete
- 全端到端测试通过：`transit_calc.py` → 返回包含 9 行星、Nakṣatra、Dasa、Ṣaḍbala、Yōga 完整 JSON
- Vimśottarī Daśā 验证：1990-01-01 出生 → Moon 在 Dhanishtha Nakṣatra → Sun 6y(1984-1990)/Moon 10y(1990-2000)/Mars 7y(2000-2007)/Rahu 18y(2007-2025)/Jupiter 16y(2025-2041) — 与 Maitreya 7.x 输出一致

## 2026-06-04 — Review follow-up fixes for `fix/output-audit-june2026`

- **`astro_backend_api.py`** — 修正 `birthday_transition` 误报：同一天的 Solar Return / 年小限换岁不再被误判为“尚未精确”；非法 `returnMode` 现在回退为 `full`；`primary_directions_method` 输出改为 `Naibod`
- **`astro_backend_classical_timing.py`** — 时间线现在会同时输出 `previous_return`、`current_cycle_return`、`next_return`，使 `historical` / `events` / `active_returns` 分层真正可达
- **`astro_backend_solar_arc.py`** — 移除未接线的静态 `duplicate_theme_warning` 和未调用的 `find_sa_progression_overlap()` 死代码
- **`ClassicalResultModels.swift`** — 补齐 `top_signatures`、`birthday_transition`、`activated_lord_focus` 的 Codable 模型
- **`ModernResultModels.swift`** — `HarmonicResult` 补齐 `houses_experimental`
- **`python_tests/test_classical.py`** / **`python_tests/test_modern_timebased.py`** — 新增针对 `birthday_transition`、时间线多返照快照、非法 `returnMode` 回退、Solar Arc 默认 patterns 关闭、移除静态重复提示、Harmonic `houses_experimental` 的测试

## 2026-06-04 — Review record for `fix/output-audit-june2026`

- Review-only task: audited the 12 claimed output fixes on `fix/output-audit-june2026` against `main`, including backend output shape, Swift model wiring, timeline layering, and targeted classical / harmonic / solar-arc smoke verification.
- No product code changed as part of this review record; findings are reported separately in the review response.

## 2026-06-04 — Review record for in-progress Vedic integration

- Review-only task: auditing the current Jyotish/Vedic integration in the working tree, including backend routing, model contracts, UI wiring, and compatibility with existing modes.
- Review completed; findings are reported separately in the review response.
- No product code changed as part of this record.

## 2026-06-04 — Final Vedic fix + packaging release prep

- Preparing the final Vedic follow-up: fix the remaining shared Rahu/Ketu label mismatch, update packaging/versioning rules, make packaging install to `/Applications` by default, validate, package, and merge back to `main`.

## 2026-06-04 — Final Vedic label fix + packaging defaults

- **`astro_backend_constants.py`** — 修正共享 `LABELS["body_id"]` 中 `RAHU` / `KETU` 的中文标签，避免导出或复用常量层时再次反置
- **`python_tests/test_constants.py`** — 增加 `RAHU=罗睺`、`KETU=计都` 的标签断言，防止共享标签层回归
- **`AGENTS.md`** — 顶端新增打包约定：按改动大小更新版本号，无特殊说明默认覆盖 `/Applications`
- **`package_app.sh`** — 打包版本提升到 `1.1.0 (17)`，并在生成 `dist/TransitStudio.app` 后默认覆盖安装到 `/Applications/TransitStudio.app`；可通过 `SKIP_INSTALL=1` 显式跳过安装
- **`python_tests/test_contracts.py`** — 放宽 classical `planetary_returns` 断言：三个快照字段允许 `None`，若存在则仍必须保持对象结构与 `label`
- **验证结果** — `python3 -m pytest python_tests -q` 通过（309 passed），`swift build` / `swift test` 通过，`./package_app.sh` 已完成打包并覆盖 `/Applications/TransitStudio.app`

## 2026-06-03 — Output audit fixes (12 issues across 3 phases)

### P0 — Bug fixes
- **`astro_backend_classical.py`** — 修复 Previous/Current 返照重复：return_summary 现在追踪两次历史穿越（prev_previous → previous_return，previous → current_cycle_return），不再浅拷贝
- **`astro_backend_primary_directions.py`** — Primary Directions 默认窗口过滤 ±3 年（通过 reference_dt 参数），不再从出生输出到 120 岁
- **`astro_backend_harmonic.py`** — Harmonic 去重：添加 skip_self_aspects=True、节点排除、双向对去重；houses 标记 houses_experimental=True
- **`astro_backend_classical.py`** / **`ClassicalCoreModels.swift`** — 评分系统增加 score_label 字段（"强而有力"、"状态良好"、"一般可用"、"偏弱受克"、"严重衰弱"）

### P1 — 展示与层级设计
- **`astro_backend_classical_timing.py`** — 时间线分层：active_periods / active_returns / events / historical
- **`astro_backend_api.py`** — 返照输出模式：支持 returnMode（compact/relationship/study/full），过滤返照列表
- **`astro_backend_solar_arc.py`** — Solar Arc 图形模式默认关闭（patterns_enabled=False）
- **`astro_backend_api.py`** — 年主联动高亮：activated_lord_focus 包含年主状态、相关返照、关键词

### P2 — 展示优化
- **`astro_backend_api.py`** — 生日边界提示：检测年小限换岁但 Solar Return 未精确的情况
- **`astro_backend_api.py`** — Top 5 优先级摘要：收集最佳相位 + 激活返照 + 年主 + 主方向
- **`astro_backend_harmonic.py`** — Harmonic 宫位标记实验性
- **`astro_backend_solar_arc.py`** — SA/Progression 同源重复提示

### Schema 更新
- **`ClassicalTimingModels.swift`** — TimelineItem 增加 layer 字段
- **`ModernResultModels.swift`** — SolarArcRequest 增加 patternsEnabled 字段
- **`RequestModels.swift`** — ClassicalRequest 增加 returnMode 字段

## 2026-06-02 — README 中文化

- **`README.md`** — 将项目说明从英文翻译为中文，并按当前代码事实补齐功能概览、现代子模式、图轮 / AI 分析 / 导出能力、后端运行示例与验证说明
- **`PLANS.md`** — 追加本次 README 中文化任务计划

## 2026-06-02 — 补充 Git 协作规则

- **`AGENTS.md`** — 新增 `Git Workflow` 章节，明确 `main` / 任务分支 / `PLANS.md` / `git diff` / `CHANGELOG.md` 的职责边界
- 新增提交前检查要求：先跑对应验证，再查看 `git diff --stat` 和完整 `git diff`
- 明确禁止把无关改动混入同一任务分支，且未经用户要求不得改写共享历史
- **`PLANS.md`** — 追加本次“更新 AGENTS.md 的 Git 协作规则”任务计划

## 2026-06-02 — 引入 Git 仓库准备

- **`PLANS.md`** — 追加“为项目引入 Git 仓库”计划，明确初始化仓库、检查忽略规则与基线提交的执行步骤
- **`.gitignore`** — 新增 `.opencode/` 忽略规则，避免本地 agent/tooling 目录进入版本库基线
- **Git 仓库** — 已在项目根目录执行 `git init -b main`，当前目录已进入 Git 管理；由于本机未配置 `user.name` / `user.email`，首个基线提交待补身份后再创建
- **Git 身份** — 已收到用于当前仓库的本地提交身份，准备补齐配置并创建基线提交
- **Git 身份修正** — 用户更正提交身份为 `katou <whatismorethat@gacu.com>`；需同步修正仓库本地配置并改写首个基线提交作者信息
- **GitHub 远程** — 用户已创建空仓库 `1223a80/AstroTransitMac`，准备将本地 `main` 分支接入 `origin` 并执行首次推送
- **GitHub 连接状态** — 已添加 `origin` 指向 `https://github.com/1223a80/AstroTransitMac.git`；首次 HTTPS 推送因本机未配置 GitHub 凭证而失败，下一步需补 PAT 或改走 SSH

## 2026-06-02 — 现代模块交付核查

- **`PLANS.md`** — 追加“现代模块交付核查”计划，准备逐项核对现代占星后端、Swift 模型层、测试覆盖与剩余风险表述
- 本次为核查任务记录，暂未修改现代模块源码
- 核查结果已记录：全量 `pytest` 与 `swift build` 通过，但 `composite` / `davison` / `solar_arc` sample smoke 发现 `patterns` 子模块失败；现代 mode 的嵌套必填字段校验仍不完整

## 2026-06-02 — 现代 UI + Harmonic 交付核查

- **`PLANS.md`** — 追加“现代 UI + Harmonic 交付核查”计划，准备核对现代模式 Swift UI 接线、Harmonic 后端、测试与剩余风险表述
- 本次为核查任务记录，暂未修改源码

## 2026-06-02 — 现代占星计算模块实现（Python 层）

### 新增后端模块

- **`astro_backend_core.py`** — 新增 `circular_midpoint(lon1, lon2) -> float`（基于最短弧的中点，对冲时固定返回 lon1+90°）
- **`astro_backend_patterns.py`**（新 350 行） — 7 种图形识别：T-Square、Grand Trine、Grand Cross、Kite、Yod（quincunx orb 3°）、Mystic Rectangle、Stellium（同星座 ≥3 / 同宫 ≥3）
- **`astro_backend_synastry.py`**（新 140 行） — 双人本命盘 + 跨盘相位 + 跨盘落宫
- **`astro_backend_composite.py`**（新 180 行） — Midpoint Composite 盘（点位中点 + 角点中点建宫 + 图形识别）
- **`astro_backend_davison.py`**（新 130 行） — 时间/地点算术中点盘 + 完整建盘 + 图形识别
- **`astro_backend_progressions.py`**（新 180 行） — Day-for-year 次限推进 + 双组相位 + Progressed Lunation
- **`astro_backend_solar_arc.py`**（新 180 行） — True Solar Arc（所有点位整体平移 + 宫头平移 + 图形识别）

### 后端调度更新

- **`astro_backend_api.py`** — `validate_required_fields()` 增加 `synastry`/`composite`/`davison`/`progression`/`solar_arc` 模式必填校验；`main()` 增加 5 条 elif 分支分发到各新模块
- **`astro_backend_constants.py`** — `ALL_MODES` 增加 5 个新 mode；新增 `ALL_NODE_MODES`、`ALL_PATTERN_IDS`

### Swift 层

- **`AstroConstants.swift`** — 同步新增 `modernModes`、`allNodeModes`、`allPatternIDs`；`allModes` 扩展 5 个新 mode
- **`OptionModels.swift`** — 无改动（现代子模式通过 `ModernSubMode` 枚举管理）
- **`ModernResultModels.swift`**（新 350 行） — 所有现代模块的 Swift Codable 模型：`ModernSubMode` 枚举、`ModernResultData` 联合类型、`PatternResult`、`SynastryRequest/Result`、`CompositeRequest/Result`、`DavisonRequest/Result`、`ProgressionRequest/Result`、`SolarArcRequest/Result`
- **`ModernBackendClient.swift`**（新 25 行） — `BackendClient` extension，5 个类型化调用方法
- **`BackendClient.swift`** — `run()` 访问级别从 `private` 改为 `internal`，允许跨文件 extension 调用

### 测试

- **`python_tests/test_patterns.py`**（新 200 行） — 25 tests：circular_midpoint（6）+ 7 种 pattern（含正例/反例/orb 边界）
- **`python_tests/test_modern_relationship.py`**（新 160 行） — 15 tests：Synastry（6）+ Composite（4）+ Davison（5）
- **`python_tests/test_modern_timebased.py`**（新 170 行） — 18 tests：Lunation（4）+ Progressions（6）+ Solar Arc（8）

### 验证

- `python3 -m pytest python_tests` — 216 passed（+58 新测试）
- `swift build` — Build complete
- `swift test` — 10 passed in 5 suites（不变）
- 5 个新模式 smoke test（synastry/composite/davison/progression/solar_arc）全部通过

## 2026-06-02 — Swift UI 层 + 6 模式全链路 + Chart Shapes + Harmonic

### Swift UI 层（新增/修改 8 个文件）

- **`OptionModels.swift`** — 新增 `nodeModeOptions`
- **`AppNavigationRail.swift`** — 现代模式下显示 7 个子模式导航按钮（本命盘 / Synastry / Composite / Davison / 次限推进 / Solar Arc / Harmonic），带选中高亮；新增 `modernNavButton()` + `modernSubModeButtons`；`modernSubMode` Binding 传入
- **`ContentView.swift`** — 新增 `@State var modernSubMode`、`modernResultData`、`modernPersonBDate/BLat/BLon`、`modernNodeMode`、`modernHarmonicOrder`、`modernSelectedTab` 等状态变量
- **`ContentView+SidebarSections.swift`** — `sidebarModeControls` 增加现代模式分支；新增 `modernSettingsSidebar`、`relationChartSidebar`（双人输入）、`timeBasedSidebar`（本命+参考时间）、`harmonicSidebar`（阶数控制）、`personASection/Bsection`、`modernParameterSection`、`modernAspectSection`
- **`ContentView+RunActions.swift`** — `runCurrentMode()` 增加现代子模式分发；新增 6 个 run 方法（`runSynastry/Composite/Davison/Progressions/SolarArc/Harmonic`）
- **`ContentView+ResultsPanes.swift`** — `resultsContent` 增加 6 个子模式结果面板路由；新增 `synastryResultsPane`、`compositeResultsPane`、`davisonResultsPane`、`progressionResultsPane`、`solarArcResultsPane`、`harmonicResultsPane`；`runButtonTitle`/`runDisabled` 增加现代模式分支
- **`ModernResultViews.swift`**（新 490 行） — 6 个模式的结果面板视图：`SynastryResultPane`（跨盘相位+落宫表）、`CompositeDavisonResultPane<T: ChartResultFields>`（行星/角点/宫位/相位/图形 tab）、`ProgressionResultPane`（推进盘/本命盘/双组相位/月相 tab）、`SolarArcResultPane`（SA盘/本命/SA→Natal相位/图形）、`HarmonicResultPane`（调和盘+相位）、`HousePlacementView`、`ProgressedLunationView`、`PatternListView`
- **`MarkdownModernExportBuilder.swift`**（新 140 行） — 5 个模式的 Markdown 导出方法
- **`ModernBackendClient.swift`** — 新增 `harmonic()` 调用

### Chart Shapes（`astro_backend_patterns.py`）

新增 `find_chart_shapes()` 函数，覆盖 9 种分布型 Chart Shape：

| Shape | 判定规则 |
|-------|---------|
| Bundle | 所有点在 90° 内 |
| Bowl | 所有点在 180° 内 |
| Locomotive | 有 60-120° 缺口 + 领星 |
| Splash | 覆盖 8+ 星座 |
| Splay | 无其他形态命中 |
| Bucket | 1 星冲 2+ 其他 = handle |
| Seesaw | 两簇距 180°±15° |
| Fan | 1 焦点 + 2+ 补八分 |
| Cradle | 4 点 2 sextile + 2 trine |

### Harmonic Charts（`astro_backend_harmonic.py`）

- 完整后端模块：`harmonic_lon = norm360(natal_lon × order)`，ASC/MC 同乘，宫位按平移重建
- Swift 完整模型：`HarmonicRequest` + `HarmonicResult`（含 `harmonicOrder`）
- UI：侧边栏阶数 Stepper（1-9），结果面板行星/相位/JSON tab
- 支持的 order：1-9，默认 4

### 常量同步

- `astro_backend_constants.py` / `AstroConstants.swift` — 新增 `ALL_CHART_SHAPE_IDS` + `test_chart_shape_ids` 契约测试

### 验证

- `python3 -m pytest python_tests` — **219 passed**（+1 新常量测试）
- `swift build` — Build complete
- `swift test` — 10 passed in 5 suites
- `echo '{"mode":"harmonic",...}' | python3 transit_calc.py` → 返回 H4 调和盘

## 2026-06-02 — 修复：Pattern 检测错误 + 嵌套字段校验 + 常量测试覆盖

### 修复

1. **[P1] Composite/Davison/Solar Arc pattern 检测崩溃** — `find_patterns()` 中 `_unique_undirected(aspects)` 读取 `body_a`/`body_b` 键但从未使用（pattern 匹配完全基于 `body_lons`），且 `find_aspects()` 输出用 `transit_body_id`/`natal_body_id`。移除该行及全部关联死代码后 3 个模式恢复正常。
2. **[P1] 新模式嵌套字段无校验** — `validate_required_fields()` 对 `synastry`/`composite`/`davison` 增加 `person_a/b.{moment.*,latitude,longitude}` 递归检查；对 `progression`/`solar_arc` 增加 `birth.moment.*` 和 `reference.*` 检查。
3. **[P3] 新常量未纳入契约测试** — `test_constants.py` 新增 `ALL_NODE_MODES`、`ALL_PATTERN_IDS` 两组跨语言比较 + 独立 `test_node_mode_ids`/`test_pattern_ids` 测试。

### 验证

- `python3 -m pytest python_tests` — 218 passed（+2 新常量测试）
- `swift build` — 通过
- 3 个修复模式的 smoke test 不再报 `section_errors.patterns`
- 缺字段请求返回结构化 JSON 错误而非 `KeyError`

## 2026-06-02 — 现代占星计算规则文档

- **`计算规则.md`** — 新增一份面向“小模型 + agent 实现”的现代占星计算规则文档，固定了 `Synastry`、`Composite`、`Davison`、`Secondary Progressions`、`Solar Arc Directions`、`Pattern Detection` 的输入、算法、输出字段、边界条件与测试要求
- **`PLANS.md`** — 追加本次文档任务的计划与完成记录

## 2026-05-29 — Classical backend 模块拆分

### Python 后端重构

- **`astro_backend_classical.py`** 拆分为 4 个专注模块：
  - `astro_backend_classical_dignity.py` — 尊贵表、sect/hayz/joy、solar phase、motion、dodekatemorion
  - `astro_backend_classical_lots.py` — Hermetic Lots 计算公式
  - `astro_backend_classical_timing.py` — 小限 / Firdaria / Decennials / ZR / 返照 / timing_timeline
  - `astro_backend_classical_audit.py` — prenatal syzygy / almuten figuris / hyleg-alcocoden
  - 原 `astro_backend_classical.py` 保留为稳定导入面，所有测试和 caller 不变
- **新增 `astro_backend_primary_directions.py`** — Placidus Semi-Arc 主限法（双向、过去/未来标记）
- **新增 `astro_backend_circumambulations.py`** — 沿界推进（ASC 按 Naibod 速率遍历界边界）

### 文档更新

- **`docs/project-structure.md`** — 更新模块结构图、架构说明
- **`docs/validation.md`** — 新增按子模块验证命令、模块归属说明
- **`docs/backend-contracts.md`** — 更新 JSON 合约文档（返照结构、syzygy 规范、timeline 格式）
- **`AGENTS.md`** — 新增 Rectifier 文件说明、编译与部署细则、打包验证流程
- **`CHANGELOG.md`** — 首次创建，记录本次变更

### 验证

- `python3 -m pytest python_tests/test_classical.py` 通过
- 5 个 smoke request 全部返回合法 JSON
- `swift build` 通过

## 2026-05-31 — Middle sidebar collapse/resize

- Added a collapsible and resizable middle sidebar column with manual toggle and drag-to-collapse behavior.
- Refined the middle sidebar drag handle implementation used by the new column collapse/resize flow.
- Added an instruction to update the root `CHANGELOG.md` after each code change in both `AGENTS.md` and `docs/opencode-next-step-requirements.md`.

## 2026-05-31 — Complete test coverage

### Python 测试（新增 ~1,200 行）

- **`python_tests/conftest.py`** — 新增 7 个 fixture 工厂：
  `sample_angles`、`sample_cusps`、`sample_planet_positions`、`sample_planet_rows`、`sample_snapshot`、`sample_birth_moment`、`sample_classical_request`
- **`python_tests/test_horary.py`** — 新增，覆盖 horary 全部逻辑模块：
  `TestAngularDelta`（angular_delta 函数边界：同一角度、偏移、绕圈、180°）、
  `TestQuestionPatterns`（7个 QUESTION_PATTERNS 的宫位/天然象征星映射、`infer_matter_role` 匹配/无匹配、`infer_natural_significator` 查询）、
  `TestHouseRulers`、`TestRadicality`（ASC 早度/晚度、土星在 7 宫、Moon VOC、无 flag）、
  `TestSignificatorCandidates`（Querent/Moon/Matter 必有、无匹配时 fallback、
  必含 id/role/planet/source 字段）、
  `TestMakeAspectEvent`（id 构造格式）、
  `TestPlanetarySpeeds`（station 检测阈值、日/月永不 station）、
  `TestSolarCondition`（太阳自身排除、distance 非负）、
  `TestNegativeReceptions`（detriment 检测、无 debility 时空列表）、
  `TestAdvancedDetection`（translation/collection/prohibition/frustration 在缺失象征星时返回正确状态）、
  `TestMachineSummary`（输出非空且不含误报）
- **`python_tests/test_scan.py`** — 新增，覆盖扫描引擎：
  `TestBodyWeights`（7 行星必有权重且 ≤1.5）、
  `TestAspectWeights`（5 主要相位必有且 conjunction ≥ opposition ≥ square）、
  `TestStepForBody`（Moon 1h、内行星 3h、外行星/小行星 12h、fallback 2d）、
  `TestExactLongitudes`（合相→单点、冲相→对点、刑相→两点）、
  `TestFindAspects`（精确合相、容限内冲相、容限外过滤、空输入）、
  `TestScanPriority`（A 级 ≥100 分、D 级 ≤59 分）、
  `TestTargetWeight`（ASC/MC/DSC/IC 1.25、fortune/spirit 1.15、sun/moon 1.1、default 1.0）、
  `TestRejectOversized`（不超过 MAX_SCAN_WORK_UNITS）、
  `TestEstimateSteps`（基础计算、零跨度）、
  `TestScanResponse`（返回结构验证）
- **`python_tests/test_classical.py`** — 追加 edge case 覆盖：
  `TestCircumambulations`（_find_bound_for_degree 各段查找、max_age=0 无边界、reference_dt 时当前边界、埃及/托勒密表不同）、
  `TestPrimaryDirections`（obliquity J2000 为 23.439291、RA 0°/90°、赤道 AD≈0、非零纬度 AD≠0、昼/夜 semi-arc、meridian_distance 绕圈）、
  `TestTimingEdges`（空 timeline→[]、仅 profection→有 period）、
  `TestLots`（零度 lot、标准计算公式）、
  `TestReturnSearchBounds`（Moon 返照窗口年份正确）、
  `TestProfection`（age=0 时 house=1）
- **`python_tests/test_contracts.py`** — 新增集成/合约测试，以 subprocess 方式运行 transit_calc.py：
  `TestClassicalContract`（JSON 合法、含 meta、7 行星、每个行星必含字段、timing 结构、profection 字段、planetary_returns 三层嵌套、lots/aspects 为 list、warnings 为 list）、
  `TestHoraryContract`（最小请求 JSON、含 meta/question_text/machine_summary/radicality_flags、moon_storyline 必含字段、significator_candidates 含 Querent/Moon/Matter）、
  `TestScanContract`（aspect/ingress/station 三类扫描返回结构有效）、
  `TestErrorContract`（非法 mode→含 error 字段、缺失字段不崩溃、空输入非 0 退出）

### Swift 测试（新增 ~350 行）

- **`SwiftTests/HoraryResultTests.swift`** — HoraryResult JSON 解码测试（全字段解码验证）
- **`SwiftTests/TransitResultTests.swift`** — TransitResult 解码 + ResultMeta 独立解码
- **`SwiftTests/RectifyResultTests.swift`** — RectifyResponse 解码 + RectifyRequest 编码（确认 snake_case CodingKeys）
- **`SwiftTests/MarkdownExportTests.swift`** — MarkdownExportBuilder 经典/行运两模式导出验证（section 标题 + 行星名）

### 文档更新

- **`docs/validation.md`** — 重构测试命令列表，新增：
  - 按模块细分的单测命令（test_horary/test_scan/test_contracts）
  - 纯逻辑测试过滤命令（`-m "not requires_ephemeris"`）
  - Swift 单 target 过滤命令（`--filter` 各测试 struct）
  - 每个 Python 模块对应的测试覆盖范围说明
  - 扩展 Recommended Change-Specific Checks 覆盖 horary/scan/contract/Swift model

## 2026-06-01 — 文档清理 + notes 修复 + 技术债记录

### 文档修正

- **`docs/opencode-next-step-requirements.md`** — §1-10 标记为「已完成：时间点/窗口扫描预设管理」，注明实现位置；§11 Chart Wheel 架构从单文件 700 行改为 4 文件拆分（Data / Geometry / Canvas / Interaction）
- **`CHANGELOG.md`** — 补录 2026-05-29 的 classical backend 模块拆分记录
- **`docs/validation.md`** — 追加 Known Technical Debt 章节，记录 classical_snapshot 重复计算和 return_summary 性能瓶颈

### 测试目录清理

- **移除 `python_tests/ClassicalResultTests.swift`** — 这是一个误放的旧版 Swift 测试文件（版本早于 `SwiftTests/ClassicalResultTests.swift`），包含已废弃的 `solar_return` schema

### 后端 notes 字段修复

- **`astro_backend_classical.py`** — `_planet_row` 的 return dict 中补回 `"notes": notes`（此前变量计算了但未输出），修复了后端 → Swift 模型 → 导出链的静默断裂
- **`test_classical.py`** — 追加 `TestPlanetNotes` 测试类，验证返回数据中至少一颗行星的 notes 非空

### 验证

- `python3 -m pytest python_tests` — 155 passed
- `swift build` — 通过

## 2026-06-01 — 时间技法分离 + 图形星盘

### 经典模式时间技法分离

- **`ContentView+ResultsPanes.swift`** — 经典结果面板增加参考时间 DatePicker +「更新时间技法」按钮；注入到 tab 栏之间，改变参考时间后点击可重算 timing，本命数据不变
- **`ResultToolbarViews.swift`** — `ResultPaneToolbar` 增加可选 `classicalSectionPicker` 参数；经典模式下「复制 Markdown」替换为「导出 Markdown...」
- **`MarkdownExportBuilder.swift`** — 新增 `ExportSection` 枚举（21 个 section，含 label + timingSectionIDs 分组）；新增 `classical(_:sections:)` 重载方法，只输出选中 section；新增 `profectionSection` / `firdariaSection` / `decennialsSection` / `zrSection` / `returnsSection` 独立子 section 生成方法
- **`ContentView.swift`** — 新增 `showClassicalExportSheet` + `classicalExportSections` 状态变量
- **`ContentView+ResultsPanes.swift`** — 新增 `classicalExportSheet` 计算属性，Form 风格 section 选择弹窗（本命 / 时间技法 / 诊断 分组），支持全选/全不选

### 图形星盘 (Chart Wheel)

- **`ChartWheelData.swift`**（新 76 行）— `ChartWheelData` 数据模型 + `WheelPoint` / `WheelAspect` 结构；适配器 init 支持 `ClassicalResult` / `TransitResult` / `HoraryResult`
- **`ChartWheelGeometry.swift`**（新 65 行）— `ChartWheelGeometry` 几何引擎：longitude→极坐标、宫弧 Path、相位弦、标签偏移；`zodiacColors` 12 色表 + `planetSymbols` Unicode 映射
- **`ChartWheelCanvas.swift`**（新 150 行）— 基于 `Canvas` + `GraphicsContext` 绘制；黄道 12 色段环（半透明填充+分割线）、宫位分割线+宫号、相位连线（按类型着色）、行星符号圆点（`☉☽♂♀☿♃♄`）、悬停 tooltip 标签
- **`ChartWheelInteraction.swift`**（新 55 行）— `ChartWheelSelection` 可观察对象（hoveredPointID + selectedPointID）；`ChartWheelInteraction` ViewModifier 实现 `onContinuousHover` + `onTapGesture` hitTest
- **`ChartWheelView.swift`**（新 20 行）— 组合入口，`GeometryReader` + 4 模块组合
- **`ContentView+ResultsPanes.swift`** — 4 个 mode（classical / modern natal / moment / horary）的 Tab 栏均增加「星盘图」入口及对应视图路由

### 验证

- `python3 -m pytest python_tests` — 155 passed
- `swift build` — Build complete
- `swift test` — 9 passed in 5 suites

## 2026-06-01 — 星盘视觉重做

### 盘面风格

- **`ChartWheelGeometry.swift`** — 重做盘面色板与环层结构，改为更接近移动端参考盘面的白底 + 浅灰三层环 + 元素四色点缀
- **`ChartWheelData.swift`** — 为星盘数据补充 `axisLongitudes`，让 `ASC/DSC/MC/IC` 按真实经度参与绘制，而不是退化成固定十字

### 绘制与交互

- **`ChartWheelCanvas.swift`** — 重写盘面绘制顺序与样式：强化四轴、减轻普通宫线、按元素着色星座环、按点位类型/天体着色标签、为拥挤点位增加引线与径向分层排布
- **`ChartWheelInteraction.swift`** — 命中测试改为复用共享点位布局半径，避免视觉位置和 hover/tap 区域脱节
- **`WheelTooltip.swift`** — 调整为更轻的 iOS 风格白色浮层 tooltip
- **`ChartWheelView.swift`** — 增加居中留白与正方形约束，让盘面更接近参考稿的呼吸感

### 验证

- `swift build` — Build complete
- `swift test` — 9 passed in 5 suites

## 2026-06-01 — 更新时间技法不跳 Tab + 导出分组修正 + 部署流程加固

### 变更

- **`ContentView+RunActions.swift`** — 新增 `runClassicalTiming()`，调用后端获取全量计算结果（不做 timing-only 拆分，`classicalResult` 整包替换），但不触发 `syncScanTargetsFromNatalChart()`；「更新时间技法」按钮改用新方法，消除 Sidebar 扫描目标随动的不必要刷新
- **`ContentView+ResultsPanes.swift`** — 把 `activeOverview` 从「本命」导出组移到「诊断」组；按钮固定走 `runClassicalTiming()`
- **`MarkdownExportBuilder.swift`** — `timingSectionIDs` 移除 `.antiscia`（映点属于本命结构，不是时间技法）；`activeOverview` 不再隐式触发整段 `## 时间技法` 导出；活跃概要补充 Ambiguity 与 calculation assumptions 文本导出
- **`MarkdownExportTests.swift`** — 新增 `classicalActiveOverviewSectionStaysDiagnostic()`，覆盖 `activeOverview` 不串出 `## 时间技法` 且包含诊断字段
- **`docs/opencode-next-step-requirements.md`** — 诊断组示意更新为「活跃概要 / 警告」，并注明活跃概要聚合诊断信息

### 验证

- `swift build --build-path /private/tmp/astrotransit-verify-build` — 通过
- `swift test --build-path /private/tmp/astrotransit-testcopy-build --jobs 1`（在隔离副本 `/private/tmp/astrotransit-testcopy` 中执行）— 10 tests passed in 5 suites
- `./package_app.sh` — 已生成 `/Users/gacu/Documents/Codex/AstroTransitMac/dist/TransitStudio.app`

## 2026-06-01 — Swift 文件拆分（export + models）

### MarkdownExportBuilder.swift 拆分

- **`MarkdownExportBuilder.swift`** — 保留为 facade，仅含 `ExportSection` enum
- **`MarkdownTransitExportBuilder.swift`** — `natal()`、`moment()`、`positionSection()`、`natalAspects()`
- **`MarkdownScanExportBuilder.swift`** — `scan()`
- **`MarkdownHoraryExportBuilder.swift`** — `horary()`
- **`MarkdownClassicalExportBuilder.swift`** — `classical()`（全量 + sections 筛选）
- **`MarkdownClassicalSections.swift`** — `pointSection`、`houseSection`、`planetSection`、`classicalAspectSection`、`receptionSection`、`antisciaSection`、`scoreSummarySection`、`triplicitySummarySection`
- **`MarkdownClassicalDirectionExportBuilder.swift`** — `primaryDirectionSection`、`circumambulationSection`
- **`MarkdownClassicalTimingExportBuilder.swift`** — `timingSection`、`activeOverviewSection`、`timelineTableSection`、`returnSnapshotSection`、`profectionSection`、`firdariaSection`、`decennialsSection`、`zrSection`、`returnsSection`、`timingSubsection`
- **`MarkdownClassicalAuditExportBuilder.swift`** — `almutenSection`、`hylegSection`、`prenatalSyzygySection`
- **`MarkdownFormatting.swift`** — `warnings()`、`degree()`、`periodLine()`、`zrLine()`、`returnSnapshotVariants()`

所有导出函数由 `private static` 改为 `static`（跨文件 extension 访问），输出内容、签名、调用点不变。

### ClassicalResultModels.swift 拆分

- **`ClassicalResultModels.swift`** — `ClassicalResult`、`CalculationAssumptions`、`ClassicalMeta`、`ClassicalAmbiguity`
- **`ClassicalCoreModels.swift`** — `ClassicalPoint`、`HouseRow`、`ClassicalPlanetRow`、`ClassicalAspectRow`、`ReceptionRow`、`ScoreBreakdownItem`、`TriplicityRulerDetail`、`ConditioningModifier`
- **`ClassicalTimingModels.swift`** — `TimingSummary`、`ProfectionSummary`、`MonthlyProfection`、`PeriodSummary`、`FirdariaSubPeriod`、`ZRSummary`、`ZRPeriod`、`ReturnChartSnapshot`、`SolarReturnSummary`、`HouseOverlay`、`TimingTimelineItem`、`ReturnCrossAspect`
- **`ClassicalDirectionModels.swift`** — `AntisciaRow`、`AntisciaHit`、`Circumambulation`、`CircumambulationBoundary`、`PrimaryDirection`
- **`ClassicalAuditModels.swift`** — `PrenatalSyzygy`、`AlmutenScoreEntry`、`AlmutenContribution`、`AlmutenFiguris`、`HylegCandidate`、`AlcocodenCandidate`、`HylegInfo`、`AlcocodenInfo`、`HylegAlcocoden`
- **`HorarySharedModels.swift`** — `HoraryMeta`、`HoraryAdvancedResult`（从 ClassicalResultModels.swift 迁入，保持 HoraryResultModels.swift 引用不变）

所有模型 struct 名、字段名、`CodingKeys` 映射不变，JSON 合约不变。

### 验证

- `swift build` — 通过（27.41s，103 编译单元，0 errors）

## 2026-06-01 — 阶段 A：跨语言错误协议

### 目标

消除 Python 后端 5 个子模块静默吞错误的问题：当 `primary_directions` / `circumambulations` / `prenatal_syzygy` / `almuten_figuris` / `hyleg_alcocoden` 计算失败时，Swift 端不再只能看到空列表，而是可以看到具体的失败原因。

### 变更

- **`Sources/TransitStudio/Resources/backend/astro_backend_api.py`** — `calculate_classical()` 收集 `section_errors: dict[str, str]`，每个 `except Exception` 同时写入 `section_errors[name] = str(exc)`；响应中包含 `"section_errors": ...`（无错误时为 `None`）
- **`Sources/TransitStudio/ClassicalResultModels.swift`** — `ClassicalResult` 新增 `sectionErrors: [String: String]?` 可选字段，CodingKeys 映射到 `"section_errors"`
- **`Sources/TransitStudio/ResultUtilityViews.swift`** — 新增 `SectionErrorList` 视图，展示在 `WarningList` 下方，使用中文标签映射（主限法/沿界推进/产前朔望/etc.）
- **`Sources/TransitStudio/ClassicalResultViews.swift`** — 引用 `SectionErrorList`
- **`Sources/TransitStudio/MarkdownFormatting.swift`** — 新增 `sectionErrorBlock()` 辅助方法，在 Markdown 导出「警告」节下方输出子模块错误
- **`Sources/TransitStudio/MarkdownClassicalExportBuilder.swift`** — 全量导出和 sections 筛选导出均调用 `sectionErrorBlock()`
- **`Sources/TransitStudio/TextExportBuilder.swift`** — 经典 CSV 导出增加 `section_error` 类型行

### 不变

JSON 合约向后兼容：旧响应无 `section_errors` 字段时 Swift 解码为 `nil`；新响应在无错误时为 `null`／有错误时为 `{"primary_directions": "..."}`。所有现有测试无需修改。

### 验证

- `python3 -m pytest python_tests` — 155 passed（0 new, 0 changed）
- `swift build` — 通过（13.26s）
- `swift test` — 10 tests passed in 5 suites
- 后端 smoke test 确认正常响应 `section_errors: null`

## 2026-06-01 — 阶段 B：共享常量 + 契约测试

### 目标

消除跨语言 magic string 漂移。将 mode/house_system/zodiac/bounds_system/triplicity_system/scan_kind/body_id/aspect_id/moon_filter 等 ~70 个字符串分别定义为 Swift 和 Python 的共享常量，并增加契约测试验证两边一致。

### 变更

- **`Sources/TransitStudio/Resources/backend/astro_backend_constants.py`**（新 78 行） — 导出 `ALL_MODES`、`ALL_HOUSE_SYSTEMS`、`ALL_ZODIACS`、`ALL_BOUNDS_SYSTEMS`、`ALL_TRIPLICITY_SYSTEMS`、`ALL_SCAN_KINDS`、`ALL_MOON_FILTERS`、`ALL_BODY_IDS`、`CLASSICAL_BODY_IDS`、`ASTEROID_BODY_IDS`、`ALL_ASPECT_IDS`，以及 `LABELS` 中文标签映射
- **`Sources/TransitStudio/AstroConstants.swift`**（新 37 行） — Swift 侧枚举，结构与 Python 侧逐字段对称
- **`python_tests/test_constants.py`**（新 150 行） — 3 个测试：
  - `test_all_constants_match` — 读取 Swift 源文件 regex 提取数组值，逐个断言与 Python 常量完全匹配
  - `test_body_id_labels` — 每个 body_id 都有中文标签
  - `test_aspect_id_labels` — 每个 aspect_id 都有中文标签

### 不变

现有代码仍引用硬编码的字符串字面量，没有强制迁移到常量名。`test_constants.py` 在 CI 层面捕获不一致。

### 验证

- `python3 -m pytest python_tests` — 158 passed（+3 新契约测试）
- `swift build` — 通过（27.13s）
- `swift test` — 10 tests passed in 5 suites

## 2026-06-01 — 阶段 C 补丁：修正三项未落地问题

### 问题 1：Rectify 验证不完整 + 缺后端错误协议

`validate_required_fields()` 只校验 `birth_date` 和 `center_time`，缺失 `timezone`/`latitude`/`longitude` 时 `compute_window()` 仍直接索引导致 `KeyError`；Swift 端 `BackendClient.run()` 和 `RectifyClient.fetch()` 不检查后端返回的错误 dict，直接尝试解码为目标类型，导致 UI 看到"JSON 无法解析"而非业务错误消息。

**修复**：
- **`astro_backend_api.py`** — `validate_required_fields()` 对 rectify 模式增加 `timezone`、`latitude`、`longitude` 必填检查
- **`BackendClient.swift`** — 新增 `BackendErrorResponse` Codable 结构 + `tryDecodeBackendError()` 函数（internal）；新增 `BackendClientError.backendError(String)` case；`run()` 中 decode 前先检查错误 dict
- **`RectifyClient.swift`** — `fetch()` decode 前同样调用 `tryDecodeBackendError()`

### 问题 2：常量文件不是真实 source of truth

`AstroConstants.swift` 和 `astro_backend_constants.py` 只被 `test_constants.py` 读取，生产代码继续硬编码；`quintile`/`biquintile` 在 `OptionModels.swift` 中存在但常量文件未覆盖。

**修复**：
- **`AstroConstants.swift`** — `allAspectIDs` 增加 `quintile`、`biquintile`
- **`astro_backend_constants.py`** — `ALL_ASPECT_IDS` 增加 `quintile`、`biquintile`；`LABELS` 增加对应中文

### 问题 3：RectifyClient 进度回调非实时

`stderr` 被重定向到文件，`progress` JSON 仅在 `terminationHandler`（进程退出后）整批读取，UI 在运行期间拿不到实时进度。

**修复**：
- **`RectifyClient.swift`** — `stderr` 改为 `Pipe` + `readabilityHandler`，每收到数据立即解析 `{"progress": ...}` 行并调用 `progressCallback`；同时用 `NSLock` + `stderrAccumulator` 累加 stderr 数据供错误消息使用；`readabilityHandler` 在 `terminationHandler` 中置 `nil` 防止竞态

### 验证

- `python3 -m pytest python_tests` — 158 passed
- `swift build` — 通过（15.50s）
- `swift test` — 10 tests passed in 5 suites
- `echo '{"mode":"rectify","birth_date":"...","center_time":"..."}'` → `{"error":"缺少必需字段：timezone, latitude, longitude","missing":["timezone","latitude","longitude"],"mode":"rectify"}`

### 目标

补齐 `RectifyClient` 缺失的超时机制（与 `BackendClient` 对等），防止进程挂起时 UI 永久 loading；增加 Python 端输入验证，将 `KeyError` 崩溃替换为结构化 JSON 错误。

### 变更

- **`Sources/TransitStudio/RectifyClient.swift`** — 新增 60s 超时 watchdog（`defaultTimeoutSeconds`）；新增 `ContinuationGuard` 类防止 `withCheckedThrowingContinuation` 重复 resume；超时后 `process.terminate()` + 清理临时文件
- **`Sources/TransitStudio/Resources/backend/astro_backend_api.py`** — 新增 `validate_required_fields()`，检查 mode 对应的必填字段（含嵌套 `birth.latitude`、`reference.year` 等）；缺失时返回 `{"error": "...", "missing": [...], "mode": ...}` 而非 `KeyError`；在 `main()` 中调用，发现错误后直接 `return` 不执行计算

### 验证

- `python3 -m pytest python_tests` — 158 passed（`TestErrorContract` 更新为匹配新 JSON 错误行为）
- `swift build` — 通过（27.28s）
- `swift test` — 10 tests passed in 5 suites
- `echo '{"mode":"nonexistent"}' | python3 .../transit_calc.py` → 干净 JSON 错误而非 `KeyError`

## 2026-06-04 — 提交与安装收尾

### 目标

将已 review 通过的 Vedic/Jyotish 工作树改动整体提交，并使用 `dist/TransitStudio.app` 覆盖安装到 `/Applications/TransitStudio.app`。

### 说明

- 本次不再改动功能逻辑，只补充项目跟踪记录并执行提交/安装收尾。
- 安装目标使用当前规范产物 `dist/TransitStudio.app`，避免从历史副本 `TransitStudio 2.app` / `TransitStudio 3.app` 取包。
