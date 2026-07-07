# 任务书 02：工作台布局重构——顶栏 + 导航精简 + 参数抽屉（1.2.1 / 37）

> 先读 `00-overview.md` 的全局强约束。本期在任务书 01 验收通过后施工。
> 目标：档案信息 / 流派切换 / 运行按钮升到顶部常驻栏；左导航只管功能；参数栏计算成功后自动收起。
> **不改任何结果视图内容、不改任何计算逻辑与请求组装。**

## 允许改动的文件（超出即停）

- 新建 `Sources/TransitStudio/ContentView+TopBar.swift`
- `Sources/TransitStudio/ContentView.swift`（body 结构）
- `Sources/TransitStudio/AppNavigationRail.swift`（删品牌块与流派分段器）
- `Sources/TransitStudio/ContentView+SidebarColumn.swift`（收起条重做 + 图钉）
- `Sources/TransitStudio/ContentView+SidebarSections.swift`（仅删 scan 头部按钮）
- `Sources/TransitStudio/ContentView+ResultsPanes.swift`（runSection 调整 + 错误横幅）
- `Sources/TransitStudio/ContentView+RunActions.swift`（仅 performRun 末尾的自动收起钩子）
- `Sources/TransitStudio/DesignTokens.swift`（仅允许在 `TS.Layout` 新增 `topBarHeight` 一个常量）
- `CHANGELOG.md`、`PLANS.md`、`package_app.sh`（版本号两行）

## 1. 新建 ContentView+TopBar.swift（顶部常驻栏）

按现有 `ContentView+SidebarColumn.swift` 的模式写成 `extension ContentView`，新增计算属性 `var appTopBar: some View`。从左到右：

1. **品牌块**：从 `AppNavigationRail.brandBlock` 迁移（金圈 + `sun.max` 图标 + "Transit / STUDIO" 两行字），整体缩小到单行高度可用即可。
2. **档案胶囊**：一个 `Menu`，label 是圆角胶囊（`TS.SemanticColor.card` 底 + `line` 描边）：
   - 有当前档案（`natalProfiles.first { $0.id.uuidString == selectedNatalProfileID }` 非 nil）时显示：`person.crop.circle` 图标（gold 色）+ 档案名（semibold）+ 摘要 `"YYYY-MM-DD HH:mm UTC±N · 纬度, 经度"`（`TS.Font.monoSmall`、inkSoft 色；月/日/时/分补零两位；gmtOffset ≥ 0 显示 `+`）+ `chevron.down`。
   - 无档案时显示 "未保存档案"。
   - Menu 内容：`ForEach(natalProfiles)` 每项一个按钮（当前项加 `checkmark`），点击执行 `selectedNatalProfileID = profile.id.uuidString; loadSelectedNatalProfile()`；然后 `Divider()`；最后 "管理档案…" 按钮执行 `isShowingAppSettingsPage = false; mode = .settings`，且当 `practiceMode == .modern` 时同时 `modernSubMode = .natal`。
3. `Spacer()`
4. **流派分段器**：把 `AppNavigationRail` 里 `practiceSegmented` 展开态的三段样式（选中 ink 底 paper 字）迁移过来，绑定逻辑用 `practiceModeBinding`（它已处理 `isShowingSettingsPage` 复位）。
5. **运行按钮**：
   ```swift
   Button {
       Task { await runCurrentMode() }
   } label: {
       HStack(spacing: TS.Spacing.md) {
           if calcVM.isRunning {
               ProgressView().controlSize(.small)
           } else {
               Image(systemName: "play.fill")
           }
           Text(calcVM.isRunning ? "计算中" : runButtonTitle)
       }
   }
   .buttonStyle(.borderedProminent)
   .disabled(runDisabled || isShowingAppSettingsPage)
   ```

整条顶栏：`padding(.horizontal, TS.Padding.sidebarContent)`，高度用新常量 `TS.Layout.topBarHeight = 52`，背景 `TS.SemanticColor.paperRaised`。

## 2. ContentView.swift：body 结构

把现在的 `HStack(spacing: 0) { ... }` 包进：

```swift
VStack(spacing: 0) {
    appTopBar
    Rectangle().fill(TS.SemanticColor.line).frame(height: 1)
    HStack(spacing: 0) { /* 现有三栏原样 */ }
}
```

其余修饰符（`.background`、`.task`、`.environmentObject` 等）保持在最外层不动。

## 3. AppNavigationRail.swift：精简

- 删除 `brandBlock`、`practiceSegmented`、`practiceSegment(_:)`、`practiceIcon(_:icon:)` 及 body 里对应两行。
- `selectedPracticeMode` 绑定**保留**（`modeButtons` 仍按流派分支）。
- 其余（收起按钮、模式按钮、设置按钮）不动。

## 4. 参数抽屉行为（ContentView+SidebarColumn / +RunActions / +ResultsPanes）

### 4.1 计算成功自动收起

- `ContentView.swift` 新增 `@State var isParamDrawerPinned = false`。
- `ContentView+RunActions.swift` 的 `performRun` 中，`try await operation()` 成功返回后追加：

  ```swift
  if calcVM.errorMessage == nil && !isParamDrawerPinned {
      collapseMiddleSidebar()
  }
  ```

  放在 `do` 块内 `operation()` 之后，不进 `catch`。

### 4.2 图钉

`middleSidebarCollapseButton` 旁（同一 overlay 的 HStack 里）加一个图钉按钮：`pin.fill`（已钉，gold 色）/ `pin`（未钉，inkFaint 色），点击切换 `isParamDrawerPinned`，`.help("固定参数面板（计算后不自动收起）")`。

### 4.3 收起条重做

`collapsedMiddleSidebarToggle` 改为宽 28（更新 `collapsedMiddleSidebarHandleWidth`）的整条可点竖条：背景 `TS.SemanticColor.paperRaised`，内容自上而下：`slider.horizontal.3` 图标、竖排文字（`VStack` 两个 `Text("参")` `Text("数")`，`TS.Font.label`、inkSoft 色）、`chevron.right`，整条 `contentShape(Rectangle())` 点击执行 `expandMiddleSidebar()`，`.help("展开参数面板")`。

### 4.4 runSection 与错误横幅

- `ContentView+ResultsPanes.swift` 的 `runSection`：**删除大运行按钮和 errorMessage 文本块**，保留进度条、进度文本和 `asteroidPreparationMessage`。三者都为空时该卡片自然为空——在 `runSection` 外层加条件：仅当 `calcVM.calculationProgress != nil || !calcVM.asteroidPreparationMessage.isEmpty` 才显示整个卡片（各 sidebar 调用处不用改）。
- `resultsPane` 的 `header` + `Divider()` 之后插入错误横幅：

  ```swift
  if let message = calcVM.errorMessage {
      HStack(spacing: TS.Spacing.md) {
          Image(systemName: "exclamationmark.triangle.fill")
          Text(message).textSelection(.enabled)
          Spacer(minLength: 0)
          Button { calcVM.errorMessage = nil } label: {
              Image(systemName: "xmark")
          }.buttonStyle(.plain)
      }
      .font(TS.Font.body)
      .foregroundStyle(TS.SemanticColor.error)
      .padding(TS.Padding.cardInner)
      .background(TS.SemanticColor.error.opacity(TS.Opacity.subtle))
  }
  ```

- `ContentView+SidebarSections.swift` 的 `sidebar` 头部：删除 `if mode == .scan { Button(...) }` 那段（运行按钮已上顶栏）。

## 5. 禁止修 / 不要动

- 各 `run*()` 的请求组装、`calcVM` 状态语义、`runButtonTitle` / `runDisabled` 的逻辑一律不动。
- rectify 侧栏与 `PrimaryDirectionRectifierView` 的级联滑杆逻辑不动（自动收起对 rectify 同样生效，属预期）。
- 结果视图、导出、AI 相关文件不动。
- 中栏拖拽调宽/收起阈值逻辑（`updateMiddleSidebarWidth` 等）不动。
- 吠陀/现代各子模式的侧栏表单内容不动。

## 6. 验收标准（DoD）

1. `bash check_vibe_changes.sh` 全绿。
2. 顶栏常驻：品牌块、档案胶囊（可切换档案、"管理档案…"跳转正确）、流派分段器、运行按钮齐全；左导航不再有品牌块与流派分段器。
3. 五种模式（古典/现代/吠陀排盘、Horary、时间点、扫描、矫正）下顶栏按钮标题与可用状态跟随现有 `runButtonTitle` / `runDisabled`。
4. 运行成功 → 参数抽屉自动收起；按下图钉后不再自动收起；收起条为竖排"参数"窄条，点击展开。
5. 计算错误显示为结果区顶部横幅，可点 × 关闭；侧栏不再出现重复的错误文本。
6. 设置页打开时运行按钮禁用；从设置页切回流派/功能正常。
7. 浅色与深色外观下顶栏、横幅、收起条样式均正常。
8. `CHANGELOG.md`、`PLANS.md` 更新；`package_app.sh` 版本改为 `1.2.1` / `37`。
