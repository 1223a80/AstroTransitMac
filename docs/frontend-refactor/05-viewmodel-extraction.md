# 模块 05：ViewModel 提取（三阶段）

> **依赖**：01 (Design Tokens)  
> **风险**：🔴 高（修改 ContentView 核心）  
> **产出文件**：  
> - Phase 1: `Sources/TransitStudio/AppState.swift`  
> - Phase 2: `Sources/TransitStudio/CalculationViewModel.swift`  
> - Phase 3: `Sources/TransitStudio/AIAnalysisViewModel.swift`  
> **修改文件**：`ContentView.swift` 和所有 `ContentView+*.swift` 扩展

## 目标

将 ContentView 的 125 个属性（104 @State + 21 @AppStorage）分三阶段提取到 ViewModel 中，每阶段独立可测、不破坏现有功能。

## 铁律

- **每移动 5-7 个属性就 `swift build` 一次**
- **每个 Phase 完成后跑完整验证**
- **永远不要一次性移动所有属性**
- 如果 build 失败，立刻回退最近的一批移动，定位问题

---

## Phase 1：AppState（@AppStorage 属性）

### 创建文件

```swift
// Sources/TransitStudio/AppState.swift
import SwiftUI

@Observable
final class AppState {
    // MARK: - Backend Settings
    @ObservationIgnored @AppStorage("pythonPath") var pythonPath = BackendClient.suggestedPythonPath()
    @ObservationIgnored @AppStorage("ephemerisPath") var ephemerisPath = ""
    @ObservationIgnored @AppStorage("noAsteroids") var noAsteroids = false
    @ObservationIgnored @AppStorage("requireEphemeris") var requireEphemeris = "warn"
    @ObservationIgnored @AppStorage("autoDownloadAsteroids") var autoDownloadAsteroids = true

    // MARK: - AI Settings
    @ObservationIgnored @AppStorage("llmBaseURL") var llmBaseURL = "https://open.bigmodel.cn/api/paas/v4"
    @ObservationIgnored @AppStorage("llmModel") var llmModel = "glm-4.7-flash"
    @ObservationIgnored @AppStorage("llmAPIKey") var llmAPIKey = ""
    @ObservationIgnored @AppStorage("savedLLMModels") var savedLLMModels = "glm-4.7-flash"
    @ObservationIgnored @AppStorage("aiPromptStyle") var aiPromptStyle = "general"
    @ObservationIgnored @AppStorage("aiPromptGeneral") var aiPromptGeneral = AIPromptDefaults.text(for: "general")
    @ObservationIgnored @AppStorage("aiPromptNatal") var aiPromptNatal = AIPromptDefaults.text(for: "natal")
    @ObservationIgnored @AppStorage("aiPromptTransit") var aiPromptTransit = AIPromptDefaults.text(for: "transit")
    @ObservationIgnored @AppStorage("aiPromptScan") var aiPromptScan = AIPromptDefaults.text(for: "scan")
    @ObservationIgnored @AppStorage("aiPromptClassical") var aiPromptClassical = AIPromptDefaults.text(for: "classical")
    @ObservationIgnored @AppStorage("aiPromptHorary") var aiPromptHorary = AIPromptDefaults.text(for: "horary")
    @ObservationIgnored @AppStorage("aiNote") var aiNote = ""
    @ObservationIgnored @AppStorage("aiReasoningEffort") var aiReasoningEffort = "max"

    // MARK: - Presets & Profiles
    @ObservationIgnored @AppStorage("natalProfilesJSON") var natalProfilesJSON = ""
    @ObservationIgnored @AppStorage("momentPresetsJSON") var momentPresetsJSON = ""
    @ObservationIgnored @AppStorage("scanPresetsJSON") var scanPresetsJSON = ""
    @ObservationIgnored @AppStorage("natalChartStyle") var practiceModeStorage = PracticeMode.modern.rawValue
}
```

### 修改 ContentView

```swift
struct ContentView: View {
    @State private var appState = AppState()   // ← 新增

    // 删除以下 21 个 @AppStorage 属性：
    // @AppStorage("pythonPath") var pythonPath = ...
    // @AppStorage("ephemerisPath") var ephemerisPath = ...
    // ... (全部 21 个)

    // 保留所有 @State 属性不变
```

### 迁移技巧

在 ContentView 及其扩展中，所有 `self.pythonPath` 变为 `appState.pythonPath`。由于 `@AppStorage` 底层是 UserDefaults，迁移不影响持久化。

**搜索替换顺序**（每批 build 一次）：

1. 批次 1：Backend settings（pythonPath, ephemerisPath, noAsteroids, requireEphemeris, autoDownloadAsteroids）→ `swift build`
2. 批次 2：AI settings 前半（llmBaseURL, llmModel, llmAPIKey, savedLLMModels）→ `swift build`
3. 批次 3：AI settings 后半（aiPromptStyle, aiPromptGeneral...Horary, aiNote, aiReasoningEffort）→ `swift build`
4. 批次 4：Presets & profiles（natalProfilesJSON, momentPresetsJSON, scanPresetsJSON, practiceModeStorage）→ `swift build`

### 传递 AppState 给子视图

`AppSettingsView` 和 `AIAnalysisView` 需要访问 AppState。通过 `.environment()` 传递：

```swift
// ContentView.body 中
.environment(appState)
```

子视图中：
```swift
@Environment(AppState.self) private var appState
```

**注意**：`AppNavigationRail` 目前通过 `@Binding var selectedPracticeMode` 操作 practiceMode。迁移后改为 binding 到 `appState.practiceModeStorage`，或继续用 Binding 传递（更安全）。

### Phase 1 验证

```bash
swift build
swift test
# 打开 app，确认设置页修改 Python 路径 / API Key 后仍然持久化
```

---

## Phase 2：CalculationViewModel（计算结果 + 运行状态）

### 创建文件

```swift
// Sources/TransitStudio/CalculationViewModel.swift
import SwiftUI

@Observable
final class CalculationViewModel {
    // MARK: - Run State
    var isRunning = false
    var calculationProgress: Double?
    var calculationProgressText = ""
    var asteroidPreparationMessage = ""
    var progressTask: Task<Void, Never>?
    var errorMessage: String?

    // MARK: - Results
    var momentResult: TransitResult?
    var fullNatalResult: TransitResult?
    var scanResult: ScanResult?
    var classicalResult: ClassicalResult?
    var horaryResult: HoraryResult?
    var rectifyResponse: RectifyResponse?
    var rectifyLevel2Response: RectifyResponse?
    var rectifyLevel3Response: RectifyResponse?
    var vedicResult: VedicResult?
    var modernResultData: ModernResultData?

    // MARK: - Rectify State
    var rectifyS1Index = 0
    var rectifyS2Index = 0
    var rectifyActiveLevel = 1
    var rectifyLevel2Gen = 0
    var rectifyLevel3Gen = 0
    var rectifyLevel3ResponseID = 0

    // MARK: - Tab Selection
    var classicalSelectedTab = "planets"
    var horarySelectedTab = "overview"
    var modernNatalSelectedTab = "natal_positions"
    var momentSelectedTab = "aspects"
    var scanSelectedTab = "hits"
    var vedicSelectedTab = "overview"
    var modernSelectedTab = "planets"
}
```

### 迁移策略

1. **先移动结果属性**（momentResult, scanResult 等）— 风险最低，只是读写
2. **再移动运行状态**（isRunning, progress 等）
3. **再移动 tab 选择状态**
4. **最后移动 `ContentView+RunActions.swift` 中的方法**

每一步都要 `swift build`。

### 方法迁移

`ContentView+RunActions.swift` 中的方法（`runCurrentMode`, `runModernNatal`, `runSynastry` 等）最终应迁移到 `CalculationViewModel`，但这一步比较大。可以先保持方法在 ContentView extension 中，只让它们读写 `calcVM.xxxResult` 而不是 `self.xxxResult`。方法本身的完整迁移可以作为后续优化。

### ContentView 改动

```swift
struct ContentView: View {
    @State private var appState = AppState()           // Phase 1
    @State private var calcVM = CalculationViewModel() // Phase 2 新增

    // 删除以下属性：
    // @State var isRunning = false                    → calcVM.isRunning
    // @State var momentResult: TransitResult?         → calcVM.momentResult
    // ... (约 30 个)
```

### Phase 2 验证

```bash
swift build
swift test
# 打开 app，执行各模式的计算，确认结果正常显示
# 特别验证：rectify 三级滑块、scan 进度条、error message 显示
```

---

## Phase 3：AIAnalysisViewModel

### 创建文件

```swift
// Sources/TransitStudio/AIAnalysisViewModel.swift
import SwiftUI

@Observable
final class AIAnalysisViewModel {
    var isAnalyzing = false

    // 按模式存储分析结果
    var momentAnalysis = ""
    var momentReasoning = ""
    var scanAnalysis = ""
    var scanReasoning = ""
    var classicalAnalysis = ""
    var classicalReasoning = ""
    var horaryAnalysis = ""
    var horaryReasoning = ""

    // 现代子模式的分析（字典存储）
    var modernAnalysisByMode: [String: String] = [:]
    var modernReasoningByMode: [String: String] = [:]
}
```

### 迁移

从 ContentView 删除：
- `@State var momentAIAnalysis / momentAIReasoning`
- `@State var scanAIAnalysis / scanAIReasoning`
- `@State var classicalAIAnalysis / classicalAIReasoning`
- `@State var horaryAIAnalysis / horaryAIReasoning`
- `@State var isAnalyzingAI`
- `@State var modernAIAnalysisByMode / modernAIReasoningByMode`

`ContentView+AI.swift` 中的 `analyze(...)` 方法最终迁移到 `AIAnalysisViewModel`。

### Phase 3 验证

```bash
swift build
swift test
# 打开 app，对任意模式点击"生成分析"，确认 AI 流式输出正常
```

---

## 提取后 ContentView 剩余属性（约 40 个）

提取完三阶段后，ContentView 保留的属性都是**表单输入状态**——日期、坐标、天体选择、相位选择等。这些属于视图层的临时输入状态，留在 ContentView 是合理的。

| 类别 | 属性数 | 示例 |
|------|--------|------|
| 模式/导航 | ~5 | mode, modernSubMode, isNavigationCollapsed |
| 日期输入 | ~7 | natalDate, transitDate, horaryDate, scanStartDate... |
| 坐标/地点 | ~6 | birthLatitude, birthLongitude, gmtOffset... |
| 天体/相位选择 | ~8 | selectedNatalBodies, selectedAspects, customAsteroids... |
| UI 杂项 | ~10 | collapsedSections, middleSidebarWidth, configText... |
| 现代子模式 | ~5 | modernPersonBDate, modernHarmonicOrder... |

## 不要做的事

- ❌ 不要在一个 commit 中移动超过 10 个属性
- ❌ 不要移动 `static let` 常量（houseSystemOptions 等）——它们是纯数据，留在 ContentView 无害
- ❌ 不要尝试把日期/坐标输入也搬到 ViewModel——表单状态留在 View 层是 SwiftUI 的正确做法
- ❌ 不要把 `@StateObject var currentLocationManager` 搬走——它是 View 层的 lifecycle 对象
