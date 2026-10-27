# 汉堡占星接入 TransitStudio 现有架构（计划）

状态：**计划，尚未实施**。本文只描述接入方案，不修改 App 代码。Swift 核心与 CLI 已存在于 `Sources/HamburgCore/`、`Sources/HamburgCLI/`，见 [`hamburg-astrology.md`](hamburg-astrology.md)。

## 1. 结论先行

推荐把汉堡盘做成 **新的页面级 `CalculationMode.hamburg`**，放在「现代」实践模式的「星图」导航组中：

```text
现代 practice
  └─ 星图
       ├─ 本命盘
       ├─ 合盘
       ├─ ...
       ├─ 中点
       └─ 汉堡盘   ← 新增 CalculationMode.hamburg

模式：现代 / 古典 / 吠陀   ← 不新增 practice mode
```

不推荐第一版把汉堡加进 `ModernSubMode`，也不推荐先新增 `PracticeMode`。

理由：

| 方案 | 优点 | 问题 | 结论 |
|---|---|---|---|
| `ModernSubMode.hamburg` | 复用现代侧栏、结果页和 rail；改动看似最少 | `ModernSubMode` 同时是 Python mode 字符串、`ModernResultData`、导出和缓存键；把 native 结果塞进去会污染现有 Python 契约 | 不作为第一版 |
| `PracticeMode.hamburg` | 学校级 IA 最纯粹，顶栏直接出现「汉堡」 | 顶栏变成四段；所有 practice 门控、导航、状态栏、AI 都要分支；改动面最大 | 可作为后续产品升级 |
| `CalculationMode.hamburg` | 页面级、边界清晰；复用 Horary/KP/rectify 的独立页面模式；不碰 Python API 和 `ModernSubMode` | 需要在若干 `switch mode` 中加一个 case（漏掉会编译失败，不会静默） | **推荐** |
| 独立窗口/Sheet | 对主界面零侵入 | 无法自然复用侧栏、结果 tabs、导出、AI、取消和 generation | 不推荐 |

汉堡盘本质上是“一个本命盘 + 一套汉堡计算 + 一个结果页”，不是一个新的 Python mode，也不是必须与古典/吠陀并列的学校入口。先做页面，后续如果产品上要独立学校，再提升为 practice mode。

## 2. 目标数据流

```text
ContentView 的出生资料 / 地点 / 宫制 / 黄道
        │
        ▼
HamburgChartRequest（现有 Python moment 请求）
  mode=moment
  natal == transit, sameChart=true
  birth = 出生资料
  natalBodies = 10 行星 + TRUE_NODE
  point_set.angle_ids = [ASC, MC]
  aspects = []
        │  BackendClient.run
        ▼
Python transit_calc.py + Swiss Ephemeris
        │  natal_positions / angles / houses / meta.natal_utc
        ▼
HamburgChartAdapter（App 层，import HamburgCore）
  - 用 meta.natal_utc 得到 JD，而不是重新解释本地时间
  - 映射标准点、ASC/MC、backend cusps
  - 用 SUN 构造 SolarReference
  - HamburgChart.addingTransneptunians(...)
        │
        ▼
HamburgEngine(options: HamburgOptions)
  - 8 TNP
  - 90°/45°/22.5° dial
  - 中点轴/树
  - 行星图像
  - 太阳弧
  - 映点
  - Witte 等宫
        │
        ▼
HamburgReport
  - calcVM.hamburgReport
  - HamburgResultPane
  - Markdown / JSON / CSV / AI
```

关键原则：

- **标准星历仍由 Python + Swiss Ephemeris 提供**，不重写本命星历。
- **汉堡增量计算全部在 Swift 内**：TNP、dial、midpoint、picture、solar arc、antiscia、Hamburg houses。
- **不新增 Python mode**。使用现有 `moment` 请求，避免 `astro_backend_api.py`、`Examples/` live contract、Python 测试和发布资源同步。
- **App 只依赖 `HamburgCore`，不把 UI 类型放进核心**。

## 3. 页面与导航接入

### 3.1 `CalculationMode`

在 `OptionModels.swift` 增加：

```swift
case hamburg

var title: String {
    case .hamburg: return "汉堡盘"
}
```

在 `AppNavigationRail` 的现代「星图」组里，放在现代 sub-mode 列表之后：

```swift
if selectedPracticeMode == .modern {
    modernSubModeButtons
    navigationButton(
        title: "汉堡盘",
        icon: "circle.grid.3x3",
        mode: .hamburg
    )
}
```

按钮只出现在现代 rail；`navigationButton` 已有 `isShowingSettingsPage == false && selectedMode == mode` 的选中规则，不需要新增状态。

### 3.2 practice 切换

`PracticeModeTransition.apply` 增加一条：

```swift
if calculationMode == .hamburg && next != .modern {
    result.calculationMode = .settings
}
```

否则用户停在汉堡页时切到古典/吠陀，会留下一个不属于该 practice 的页面。切回现代时默认落在 `.natal` 或原 modern sub-mode，符合现有规则。

### 3.3 需要补 case 的开关

新增 `CalculationMode.hamburg` 后，以下位置必须同步（漏一个会编译失败）：

- `OptionModels.swift`：`title`
- `AppNavigationRail.swift`：现代 rail 按钮
- `ContentView+RunActions.swift`：`runCurrentMode`、`clearAnalysisForCurrentMode`
- `ContentView+ResultsPanes.swift`：`runButtonTitle`、`runButtonHelp`、`runDisabled`、`resultsContent`
- `ContentView+SidebarSections.swift`：`sidebarModeControls`
- `ContentView+AIPanel.swift`：AI context（第一版可返回 nil）
- `ContentView.swift`：如果加入 practice 切换保护，也在 `PracticeModeTransition` 内处理
- `ContentView+TopBar.swift`：不需要新按钮，顶栏仍显示「现代」

`runDisabled` 第一版：

```swift
case .hamburg:
    return parseDouble(birthLatitude) == nil
        || parseDouble(birthLongitude) == nil
        || selectedZodiac != "tropical"
```

如果允许无出生时间，仍可输出 TNP/中点，但不输出 ASC/MC；第一版沿用 App 现有“总是有时间”的假设，后续再加“时间未知”开关。

## 4. App 层新增文件

建议新增以下文件，保持与现有模块边界一致：

| 文件 | 职责 |
|---|---|
| `HamburgChartAdapter.swift` | `HamburgChartRequest` / `HamburgBackendChart` Codable；把 Python `moment` 输出转换成 `HamburgChart` |
| `HamburgOptionsState.swift` | 侧栏可调参数的默认值、校验、`HamburgOptions` 构造（可并入 Adapter） |
| `ContentView+Hamburg.swift` | `hamburgSidebar`、`runHamburg()`、tab 状态和结果存取 |
| `HamburgResultPane.swift` | 结果页、tabs、表格、筛选、`ResultPaneToolbar` |
| `HamburgExports.swift` | Markdown/JSON/CSV provider；优先复用 `HamburgMarkdownRenderer` |
| `HamburgTabContractTests.swift` | tabs 列表与 `selectedResultView` 的源码级契约测试 |

`HamburgResultPane` 建议沿用 `MidpointResultPane` / `OrbitalDialResultPane` 的结构：

```swift
struct HamburgResultPane: View {
    let result: HamburgReport
    @Binding var selectedTab: String

    var body: some View {
        VStack(alignment: .leading, spacing: TS.Spacing.lg) {
            ResultPaneToolbar(
                selection: $selectedTab,
                tabs: tabs,
                moreTabs: moreTabs,
                currentTabTitle: tabTitle,
                markdownProvider: { HamburgExports.markdown(result) },
                jsonProvider: { HamburgExports.json(result) },
                csvProvider: { HamburgExports.csv(result) },
                basename: "hamburg"
            )
            selectedResultView
        }
        .padding(TS.Padding.resultContent)
    }

    var tabs: [(String, String)] {
        [
            ("positions", "星体"),
            ("midpoints", "中点"),
            ("pictures", "行星图像"),
            ("solar_arc", "太阳弧"),
            ("antiscia", "映点"),
            ("houses", "宫位"),
        ]
    }

    var moreTabs: [(String, String)] {
        [("diagnostics", "诊断"), ("json", "JSON")]
    }
}
```

每个 tab id 必须在 `selectedResultView` 有显式 case；这是 AGENTS 的 result-pane tab contract。默认 tab `positions` 要与 `CalculationViewModel.hamburgSelectedTab` 的初始值一致。

## 5. 状态与运行

### 5.1 `CalculationViewModel`

```swift
@Published var hamburgReport: HamburgReport?
@Published var hamburgSelectedTab = "positions"

func clearHamburgResult() {
    hamburgReport = nil
    hamburgSelectedTab = "positions"
}
```

不使用 `ModernResultData` / `classicalExpansionResults`：

- 汉堡是 native 报告，不是 Python mode 结果；
- 不参与 D6 古典合并导出；
- 不污染 `ExpansionExportCatalog` 的 Python mode 穷举 switch。

结果保留策略与现有模式一致：新计算开始时不清旧结果，成功后替换；失败/取消时保留旧结果并在 `errorMessage` 显示原因。

### 5.2 `runHamburg()`

放在 `ContentView+Hamburg.swift`，用现有 `performRun`：

```swift
@MainActor
func runHamburg() async {
    guard let coords = requireCoordinates(birthLatitude, birthLongitude) else { return }
    guard selectedZodiac == "tropical" else {
        calcVM.errorMessage = "汉堡盘第一版只支持热带黄经；恒星黄道将在后续版本接入。"
        return
    }

    await performRun {
        let moment = makeMoment(from: natalDate)
        let request = HamburgChartRequest(
            natal: moment,
            birth: makeBirthSettings(latitude: coords.latitude, longitude: coords.longitude),
            bodyIDs: modernDefaultBodyIDs + ["TRUE_NODE"],
            angleIDs: ["ASC", "MC"]
        )
        let backend: HamburgBackendChart = try await BackendClient.run(
            request: request,
            pythonPath: appState.pythonPath
        )
        try Task.checkCancellation()

        let options = makeHamburgOptions()
        let chart = try HamburgChartAdapter.makeChart(
            from: backend,
            moment: moment,
            location: .init(
                latitude: coords.latitude,
                longitude: coords.longitude,
                timezone: timezoneLabel,
                backendHouseSystem: "placidus"
            ),
            options: options
        )
        try Task.checkCancellation()

        let report = HamburgEngine(options: options).report(
            chart: chart,
            referenceJulianDay: hamburgReferenceEnabled
                ? try hamburgReferenceDate.julianDayUT
                : nil,
            referenceMoment: hamburgReferenceEnabled
                ? makeHamburgMoment(from: hamburgReferenceDate)
                : nil
        )
        calcVM.hamburgReport = report
        calcVM.hamburgSelectedTab = "positions"
    }
}
```

要点：

- 使用 `performRun`，复用 `isRunning`、错误、取消、generation、侧栏收起逻辑。
- `BackendClient.run` 已经处理 Python 进程超时/取消；native 计算前检查 `Task.checkCancellation()`。
- `HamburgEngine` 很快（22 点、7k 四元组级别），不需要进度条；Python `moment` 调用是主要等待，沿用现有无进度运行即可。若希望有反馈，可在 `performRun` 前设置 `calculationProgressText = "读取本命星历..."`，但不要让 native 阶段跑伪进度。
- 不要在这里把 `HamburgReport` 转成 `ModernResultData`。

### 5.3 参数字段

第一版建议在 `ContentView` 增加：

```swift
@State var hamburgDialModulus = 90.0
@State var hamburgOrbUnit = "zodiac"
@State var hamburgMidpointOrb = 1.0
@State var hamburgPictureOrb = 1.0
@State var hamburgSolarArcOrb = 1.0
@State var hamburgFocusIDs: Set<String> = ["SUN", "MOON", "ASC", "MC", "ARIES_POINT"]
@State var hamburgIncludeAntiscia = true
@State var hamburgIncludePictures = true
@State var hamburgIncludeConverse = false
@State var hamburgReferenceDate = Date()
@State var hamburgReferenceEnabled = true
@State var hamburgMaxPictures = 300
```

后续可把 dial/orb 放入 `AppState` / `@AppStorage`，与现有用户偏好一致；第一版 `@State` 与多数现代参数保持一致。

## 6. Python 请求契约

### 6.1 请求

复用 `moment`，不新增后端 mode：

```json
{
  "mode": "moment",
  "natal": { "year": 1990, "month": 1, "day": 1, "hour": 12, "minute": 0, "timezone": "Asia/Shanghai" },
  "transit": { "year": 1990, "month": 1, "day": 1, "hour": 12, "minute": 0, "timezone": "Asia/Shanghai" },
  "sameChart": true,
  "birth": {
    "moment": { "year": 1990, "month": 1, "day": 1, "hour": 12, "minute": 0, "timezone": "Asia/Shanghai" },
    "latitude": 31.2304,
    "longitude": 121.4737,
    "houseSystem": "placidus",
    "zodiac": "tropical",
    "boundsSystem": "egyptian",
    "triplicitySystem": "dorothean"
  },
  "natalBodies": ["SUN","MOON","MERCURY","VENUS","MARS","JUPITER","SATURN","URANUS","NEPTUNE","PLUTO","TRUE_NODE"],
  "transitBodies": ["SUN","MOON","MERCURY","VENUS","MARS","JUPITER","SATURN","URANUS","NEPTUNE","PLUTO","TRUE_NODE"],
  "point_set": {
    "body_ids": ["SUN","MOON","MERCURY","VENUS","MARS","JUPITER","SATURN","URANUS","NEPTUNE","PLUTO"],
    "include_nodes": true,
    "node_mode": "true_node",
    "custom_asteroids": [],
    "angle_ids": ["ASC","MC"],
    "house_cusps": [],
    "lot_ids": []
  },
  "aspects": []
}
```

为什么请求 Placidus 而不是 Hamburg 宫：

- Python 没有 `hamburg` 宫制；
- 汉堡宫制是 Swift 端固定的 0° 天秤等宫；
- 仍需要 Python 计算 ASC/MC；
- Placidus cusps 可作为报告中的 `backend_cusps` 对照，不用于 `house` 字段。

如果将来要允许“后端宫制对照”，把 `houseSystem` 改成用户选择的系统即可，但 `HamburgChart.houseAssignment` 仍为 `.hamburg`。

### 6.2 响应

建议不要复用 `TransitResult`，而是定义最小响应模型：

```swift
struct HamburgBackendChart: Decodable {
    let meta: Meta
    let natalPositions: [Position]
    let angles: [Angle]
    let houses: [House]
    let warnings: [String]?

    struct Meta: Decodable {
        let natalUTC: String?
        let ephemeris: String?
    }
    struct Position: Decodable {
        let bodyID: String
        let name: String
        let longitude: Double
        let latitude: Double?
        let speed: Double?
    }
    struct Angle: Decodable {
        let id: String
        let name: String
        let longitude: Double
    }
    struct House: Decodable {
        let house: Int
        let cuspLongitude: Double
    }
}
```

理由：

- `TransitResult` 带 transit/aspect/pattern 等汉堡不需要的字段；
- 出错时 `BackendClient` 仍返回统一错误；
- 字段少，fixture 小，未来 Python `moment` 增加字段不会破坏解码；
- 与 `HamburgCLI/PythonBackend.swift` 的解码模型几乎一致，可把 CLI 的 adapter 逻辑抽到共享位置（但 App 不应依赖 CLI target，建议复制最小模型或把 adapter 放进 `HamburgCore` 的独立 `HamburgSupport` target）。第一版在 App 层保留一个小模型即可。

### 6.3 Adapter 规则

```swift
enum HamburgChartAdapter {
    static func makeChart(
        from response: HamburgBackendChart,
        moment: ChartMoment,
        location: ChartLocation,
        options: HamburgOptions
    ) throws -> HamburgChart {
        // 1. JD：优先 meta.natal_utc，绝不重新解释本地时区
        // 2. 标准点 + ASC/MC -> [ChartPoint]
        // 3. 用 SUN 构造 SolarReference
        // 4. HamburgChart.addingTransneptunians(
        //        houseAssignment: .hamburg,
        //        backendCusps: response.houses.map(\.cuspLongitude),
        //        solar: solar
        //    )
    }
}
```

必须遵守：

- 点 ID 大写，与 `HamburgCore` 的 rank/canonical order 一致。
- `nameLocal` 保留 Python 中文名；`name` 用 Adapter 的英文名或 Python 名。
- `kind`：`NODE` → `.node`；ASC/MC → `.angle`；其余 → `.planet`。
- 只用后端返回的 `meta.natal_utc` 计算 JD；如果缺失，回退到 `Moment.julianDayUT` 并加 warning。
- 太阳参考：`SolarReference(longitude: sun.longitude, latitude: sun.latitude ?? 0, distanceAU: SolarEphemeris.distanceAU(julianDay: jd))`。
- 不把 Python 返回的 `house` 直接抄进 `ChartPoint`；`HamburgChart` 用 `.hamburg` 重新分宫。
- 不把 TNP 写回 Python 请求。

## 7. 结果页设计

第一版结果 tabs：

| tab | 内容 |
|---|---|
| `positions` | 标准行星 + 8 TNP + ASC/MC + Aries Point；黄经、星座度数、Hamburg 宫、dial、来源 |
| `midpoints` | 焦点选择（SUN/MOON/ASC/MC/Aries/全部）；中点树表：公式、轴、branch/harmonic、orb 360°、orb dial |
| `pictures` | `A + B = C + D` 表；orb、dial 位置；按 orb 排序 |
| `solar_arc` | 方法/年龄/弧；SA→本命点、SA→本命中点 |
| `antiscia` | 映点→本命点、映点→本命中点 |
| `houses` | Hamburg 等宫 cusps；backend Placidus cusps 对照 |
| `diagnostics` | warnings、TNP 模型、精度边界、orb 单位说明 |
| `json` | `RawJSONView(value: report)` |

推荐复用：

- `ResultPaneToolbar`、`ExportMenu`、`TabChip`、`resultTabTitle`
- `EmptyStateView`
- `ModernDiagnosticsView`（如果它能接受 `warnings` + `sectionErrors`；汉堡没有 `section_errors`，可传 nil）
- `RawJSONView`

筛选/交互第一版：

- 星体：按 keyword 搜索、只看 TNP、按 orb 排序。
- 中点：focus picker、orb slider、排序；暂不做“发送至综合时间线”（汉堡图像不是现代 midpoint axis 的同一契约）。
- 图像：orb slider、公式搜索、限制条数。
- 太阳弧：method/arc 摘要，列表过滤 direct/converse。
- 映点：类型筛选（antiscion/contra-antiscion）。

## 8. 导出

`HamburgCore` 已有 `HamburgMarkdownRenderer`，第一版直接复用：

```swift
enum HamburgExports {
    static func markdown(_ report: HamburgReport, sections: Set<String>? = nil) -> String {
        // 第一版：完整 Markdown
        // 第二版：按 "## " 标题过滤 sections，或给 HamburgMarkdownRenderer 增加 section API
    }
    static func json(_ report: HamburgReport) -> String { ... }
    static func csv(_ report: HamburgReport) -> String { ... }
}
```

注意：

- JSON 用 `TextExportBuilder.json(report)` 或本地 `JSONEncoder`；报告是 Codable。
- CSV 第一版至少输出 positions/pictures/midpoint hits；不要伪造不存在的字段。
- Markdown 的 `orb` 是谐波等价 360° 值，不是原始黄经差；导出说明中保留这句话。
- 如果以后加 section picker，建议在 `HamburgCore` 给 `HamburgMarkdownRenderer` 加 `sections: Set<HamburgSection>` 参数，App 只做 UI，不在字符串上做脆弱的 heading 正则。

## 9. AI 接入（第二阶段）

第一版可以返回 `nil`（像 `midpoint` 一样），不影响主流程。

第二阶段：

- `AIAnalysisViewModel` 增加 `hamburgAnalysis` / `hamburgReasoning`，或复用 `modeKey` 存储。
- `AIPanelContext` 增加：

```swift
case .hamburg:
    AIPanelContext(
        streamKey: "hamburg",
        title: "汉堡盘",
        analysis: aiVM.hamburgAnalysis,
        reasoning: aiVM.hamburgReasoning,
        hasResult: calcVM.hamburgReport != nil
    ) { Task { await analyzeHamburgResult() } }
```

- `analyzeHamburgResult()` 使用 `HamburgExports.markdown(report)` 作为上下文。
- 必须遵守现有流式契约：发布到 `aiVM.streamBuffer`（~100ms 节流），结束后一次性写 per-mode storage；不要在 `body` 中解析 Markdown。
- 新增 `AIPromptDefaults` 的 `hamburg` 提示词；如果不加，用 `general` 或 `midpoint` 提示词，但要在 UI 标注。

## 10. 测试计划

### 10.1 新增 App 测试

- `HamburgAdapterTests`：从 `SwiftTests/Fixtures/hamburg-moment-result.json`（现有 `moment` 输出）解码，断言：
  - `meta.natal_utc` → JD；
  - 22 个点（10 + 真交点 + 8 TNP + ASC/MC + Aries）；
  - 8 个 TNP ID；
  - `houseAssignment == .hamburg`，backend cusps 12 个；
  - SUN 的 solar reference 非空。
- `HamburgTabContractTests`：tabs 列表 ID 与 `selectedResultView` 的 case 集合一致；默认 tab 在列表中。
- `HamburgExportTests`：Markdown 包含标题/位置/TNP/中点/图像/太阳弧/映点；JSON round-trip；CSV 表头。
- `HamburgRunStateTests`：generation 旧结果不写；取消不落结果；无坐标时 `runDisabled`。
- `CalculationMode` 契约：`hamburg.rawValue == "hamburg"`，title。
- 不在 `Examples/` 增加汉堡请求；否则 `LiveBackendContractTests` 会要求 Python mode 和 Swift decoder。

### 10.2 现有测试

- `swift build`、`swift test` 全量。
- `bash check_vibe_changes.sh`：Python 1232 / Swift 现有 + 新增 / 44 个 live examples。
- 手工 smoke：用样例出生数据，确认 22 点、8 TNP、pictures/trees/arc 正常；取消/重跑；切换古典/吠陀再回现代；旧结果不串页。

### 10.3 数值验收

- TNP 与 Swiss Ephemeris 静态 fixture 对照（核心已有 33 项测试）。
- 汉堡盘标准行星与现有 `moment` 输出一致（Adapter 只做映射，不改黄经）。
- 太阳弧 true_sun 与现有 `solar_arc` mode 的弧值在 0.01° 内。
- 90° dial 折叠、跨 0°、180° tie-break 由核心测试覆盖。

## 11. 分阶段实施

### Phase 0 — 冻结契约（0.5 天）

- 确认走 `CalculationMode.hamburg`。
- 冻结 `HamburgBackendChart` 最小字段和 Adapter 规则。
- 确认第一版只支持 tropical；确认默认 orb 口径。
- 不写 App 代码。

### Phase 1 — 能算、能看（2–3 天）

- `Package.swift` 把 `HamburgCore` 链接进 `TransitStudio`。
- `CalculationMode.hamburg` + rail 按钮 + practice transition 保护。
- `HamburgChartRequest`、`HamburgBackendChart`、`HamburgChartAdapter`。
- `calcVM.hamburgReport` / `hamburgSelectedTab`。
- `runHamburg()` + `performRun`。
- `hamburgSidebar`（出生资料、dial/orb、focus、solar arc 开关）。
- `HamburgResultPane` 的 positions/pictures/diagnostics/json 四个 tab。
- 基础 Markdown/JSON/CSV provider。
- Adapter fixture + tab contract tests。

Phase 1 验收：样例出生数据能出 22 点、8 TNP、pictures；不新增 Python mode；现有功能不回归。

### Phase 2 — 完整分析页（2–3 天）

- 中点树、太阳弧、映点、Hamburg houses 四个 tab。
- 筛选、排序、空状态、警告展示。
- section 导出 / CSV 完整化。
- 侧栏参数补全（converse、max pictures、reference date、focus 全选）。
- 手工 UI smoke + 截图检查。

### Phase 3 — 可视化与 AI（2–4 天）

- 90° dial 可视化（可先用 `ChartWheelCanvas` 的简化 dial 视图，或新增 `DialWheelView`）。
- 本命轮盘叠加 TNP 标签（`planetShortLabels` 增加 8 个 TNP；`ChartWheelData` 接受 `HamburgReport`）。
- AI panel context / prompt / markdown 上下文。
- 可选：把 Hamburg midpoint axes 发到现代 timing（需要新的 axis 契约，不建议第一版做）。

### Phase 4 — 产品级提升（按需）

- 如果用户要求把汉堡作为独立学校：新增 `PracticeMode.hamburg`，把现有页面移动到该 practice；核心/Adapter/结果页不变。
- 如果其他客户端需要汉堡 JSON：新增 Python `mode=hamburg`，复用同一 Swift CLI 契约作为参考；这不是 App 接入的必要条件。
- 恒星黄道：给 TNP/标准点应用 ayanamsha 偏移，补 sidereal fixture。
- 出生时间未知：支持无 ASC/MC 的汉堡盘，UI 明确降级。

## 12. 风险与决策点

| 风险/决策 | 处理 |
|---|---|
| `ModernSubMode` 是 Python 契约 | 不把 hamburg 加进 `ModernSubMode`；用 `CalculationMode.hamburg` |
| 顶栏四段 practice 的 IA 成本 | 第一版不加 `PracticeMode`；后续按产品需要提升 |
| `CalculationMode` 穷举 switch 漏改 | Swift 编译器会报错；新增 case 后按第 3.3 节逐一补 |
| Python `moment` 请求字段漂移 | 用最小 `HamburgBackendChart` 解码；只依赖 `natal_positions/angles/houses/meta/warnings` |
| 本地时区 vs 后端 UTC | JD 优先用 `meta.natal_utc`；reference 用 App 本地 `Moment`，两者分开记录 |
| 无出生时间 | 第一版要求现有出生时间；后续加“时间未知”降级 |
| 恒星黄道 | 第一版禁用并明确提示；Phase 4 再支持 |
| 90° dial orb 误读 | UI 必须显示 `orb_unit`，表格同时给 `orb` 和 `orb_dial`；默认 `zodiac` 并写帮助 |
| TNP 模型争议 | 报告 meta/diagnostics 明示 Neely 1980、假想点、精度边界 |
| 结果与现有 midpoint/orbital_dial 重叠 | 汉堡页是独立组合视图，不替换现有 mode；不共享 axis ID/契约 |
| 取消/旧结果 | 复用 `performRun` + generation；native 前后检查 `Task.isCancelled` |
| `Examples/` live gate | 不把汉堡请求放进 `Examples/`；fixture 放 `SwiftTests/Fixtures/` |
| App 包体积/签名 | `HamburgCore` 是纯 Swift 小库，不增加资源；打包时按 AGENTS 更新版本 |

## 13. 验收清单

- [ ] `CalculationMode.hamburg` 出现在现代 rail，选中状态正确。
- [ ] 切到古典/吠陀时不会停留在汉堡页。
- [ ] 样例出生数据返回 22 点、8 TNP、pictures/trees；标准行星与 `moment` 输出一致。
- [ ] 汉堡结果页 tabs 完整，默认 tab 与初始状态一致；每个 tab id 都有显式 case。
- [ ] Markdown/JSON/CSV 可复制/保存；Markdown 含 TNP、dial、pictures、solar arc、antiscia。
- [ ] 取消、重跑、切换页面不会把旧结果写进新 generation。
- [ ] 无坐标、非热带黄道、后端失败均有明确错误/警告。
- [ ] 不新增 Python mode；`Examples/` live contract 不增加汉堡样例。
- [ ] `swift build`、`swift test`、`bash check_vibe_changes.sh` 通过。
- [ ] `PLANS.md` / `CHANGELOG.md` 记录本阶段实际改动。

## 14. 相关文件

核心与 CLI：

- [`Sources/HamburgCore/HamburgEngine.swift`](../Sources/HamburgCore/HamburgEngine.swift)
- [`Sources/HamburgCore/Chart.swift`](../Sources/HamburgCore/Chart.swift)
- [`Sources/HamburgCore/Report.swift`](../Sources/HamburgCore/Report.swift)
- [`Sources/HamburgCLI/main.swift`](../Sources/HamburgCLI/main.swift)
- [`docs/hamburg-astrology.md`](hamburg-astrology.md)

现有 App 接入点：

- [`Sources/TransitStudio/OptionModels.swift`](../Sources/TransitStudio/OptionModels.swift)
- [`Sources/TransitStudio/AppNavigationRail.swift`](../Sources/TransitStudio/AppNavigationRail.swift)
- [`Sources/TransitStudio/ContentView+RunActions.swift`](../Sources/TransitStudio/ContentView+RunActions.swift)
- [`Sources/TransitStudio/ContentView+ResultsPanes.swift`](../Sources/TransitStudio/ContentView+ResultsPanes.swift)
- [`Sources/TransitStudio/ContentView+SidebarSections.swift`](../Sources/TransitStudio/ContentView+SidebarSections.swift)
- [`Sources/TransitStudio/CalculationViewModel.swift`](../Sources/TransitStudio/CalculationViewModel.swift)
- [`Sources/TransitStudio/MidpointViews.swift`](../Sources/TransitStudio/MidpointViews.swift)（结果页模式参考）
- [`Sources/TransitStudio/OrbitalDialViews.swift`](../Sources/TransitStudio/OrbitalDialViews.swift)（dial 结果页参考）
