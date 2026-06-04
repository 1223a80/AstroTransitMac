# Changelog

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
