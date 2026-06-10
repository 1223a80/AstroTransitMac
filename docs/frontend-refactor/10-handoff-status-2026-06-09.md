# 前端重构 00-09 交接状态（2026-06-09）

## 背景

- 工作分支：`refactor/frontend-tokens-views-vm`
- 当前打包版本：`1.1.2 (21)`
- 当前状态：模块 01-08 已落地；模块 09 作为视觉规范文档已被部分到大部分应用；模块 00 为总览/约束文档，已作为本轮实现的执行基线

## 本轮新增/关键修复

1. 修复了 `VedicNavamsaView` 空白页回归
2. 修复了 `AppState` 从 `@AppStorage` 抽离后不再响应式刷新的问题
3. 重新打包并覆盖安装到 `/Applications/TransitStudio.app`

## 模块状态总表

| 模块 | 状态 | 结论 |
|------|------|------|
| 00 Overview | ✅ 已遵循 | 作为重构总索引使用，执行顺序和约束已参考 |
| 01 Design Tokens | ✅ 已完成 | `TS` token 体系已建立并在主要新/改视图中采用 |
| 02 CollapsibleSection | ✅ 已完成 | 已去掉 `GroupBox`，改为轻量 section |
| 03 Tab Bar | ✅ 已完成 | 结果区 tab 已改为单行水平滚动 |
| 04 Export Controls | ✅ 已完成 | `ExportControls.swift` 已删除，导出收口到 toolbar |
| 05 ViewModel Extraction | ✅ 已完成 | `AppState` / `CalculationViewModel` / `AIAnalysisViewModel` 已落地 |
| 06 Vedic Views | ✅ 已完成 | 缺失吠陀视图已补齐并接线 |
| 07 Classical Fields | ✅ 已完成 | `birthdayTransition` / `activatedLordFocus` 已显示 |
| 08 AI Analysis Cleanup | ✅ 已完成 | AI 设置折叠、标题行精简、共享状态已接通 |
| 09 Visual Design Spec | 🟡 部分到大部分完成 | 新增/重构页面基本按规范收口，但全应用尚未完全统一 |

---

## 00 Overview

### 已做

- 按 [00-overview.md](/Users/gacu/Documents/Codex/AstroTransitMac/docs/frontend-refactor/00-overview.md) 的依赖顺序推进
- 遵守“先 token，再组件，再 ViewModel，再具体页面”的改造思路
- `PLANS.md` / `CHANGELOG.md` 已持续更新

### 未做

- 没有把 00 文档里的全部 smoke 命令每轮都跑满；本轮主要执行的是 `swift build` / `swift test`

---

## 01 Design Tokens

### 已做

- 新增 [DesignTokens.swift](/Users/gacu/Documents/Codex/AstroTransitMac/Sources/TransitStudio/DesignTokens.swift)
- 提供：
  - `TS.Spacing`
  - `TS.Padding`
  - `TS.Radius`
  - `TS.Font`
  - `TS.SemanticColor`
  - `TS.Opacity`
  - `TS.Layout`

### 主要采用位置

- [ResultToolbarViews.swift](/Users/gacu/Documents/Codex/AstroTransitMac/Sources/TransitStudio/ResultToolbarViews.swift)
- [CollapsibleSection.swift](/Users/gacu/Documents/Codex/AstroTransitMac/Sources/TransitStudio/CollapsibleSection.swift)
- [AIAnalysisView.swift](/Users/gacu/Documents/Codex/AstroTransitMac/Sources/TransitStudio/AIAnalysisView.swift)
- [VedicResultViews.swift](/Users/gacu/Documents/Codex/AstroTransitMac/Sources/TransitStudio/VedicResultViews.swift)
- [VedicPanchangaView.swift](/Users/gacu/Documents/Codex/AstroTransitMac/Sources/TransitStudio/VedicPanchangaView.swift)
- [VedicDivisionalChartView.swift](/Users/gacu/Documents/Codex/AstroTransitMac/Sources/TransitStudio/VedicDivisionalChartView.swift)
- [VedicJaiminiView.swift](/Users/gacu/Documents/Codex/AstroTransitMac/Sources/TransitStudio/VedicJaiminiView.swift)
- [VedicAshtakavargaView.swift](/Users/gacu/Documents/Codex/AstroTransitMac/Sources/TransitStudio/VedicAshtakavargaView.swift)
- [VedicRelationshipsView.swift](/Users/gacu/Documents/Codex/AstroTransitMac/Sources/TransitStudio/VedicRelationshipsView.swift)
- [VedicMiscDataViews.swift](/Users/gacu/Documents/Codex/AstroTransitMac/Sources/TransitStudio/VedicMiscDataViews.swift)
- [AppNavigationRail.swift](/Users/gacu/Documents/Codex/AstroTransitMac/Sources/TransitStudio/AppNavigationRail.swift)

### 剩余缺口

- 老的 Classical/Modern 结果表和部分设置控件里仍有裸 `.font(.caption)` / 裸间距值

---

## 02 CollapsibleSection

### 已做

- 重写 [CollapsibleSection.swift](/Users/gacu/Documents/Codex/AstroTransitMac/Sources/TransitStudio/CollapsibleSection.swift)
- 去掉 `GroupBox`
- 改为：
  - `Divider`
  - 文本标题
  - `chevron` 展开/折叠
  - TS token 化间距/字体

### 影响

- 中间侧边栏的所有 `collapsible(...)` 调用者都吃到了新样式

---

## 03 Tab Bar

### 已做

- 重写 [ResultToolbarViews.swift](/Users/gacu/Documents/Codex/AstroTransitMac/Sources/TransitStudio/ResultToolbarViews.swift)
- `tabRows` 二维布局迁移为 `tabs` 单行水平滚动
- `moreTabs` 统一收进 `Menu("更多")`

### 已迁移调用者

- [ContentView+ResultsPanes.swift](/Users/gacu/Documents/Codex/AstroTransitMac/Sources/TransitStudio/ContentView+ResultsPanes.swift)
- [ModernResultViews.swift](/Users/gacu/Documents/Codex/AstroTransitMac/Sources/TransitStudio/ModernResultViews.swift)

### 当前效果

- 结果区 tab 已更接近 macOS 单行工具条
- 标题行已使用 `TS.Font.pageTitle`

---

## 04 Export Controls

### 已做

- 删除 [ExportControls.swift](/Users/gacu/Documents/Codex/AstroTransitMac/Sources/TransitStudio/ExportControls.swift)
- 导出入口保留在 [ResultToolbarViews.swift](/Users/gacu/Documents/Codex/AstroTransitMac/Sources/TransitStudio/ResultToolbarViews.swift) 的：
  - `CopyMarkdownButton`
  - `ExportMenu`
  - classical/vedic 的自定义 markdown section picker

---

## 05 ViewModel Extraction

### 已做

#### 05-P1 AppState

- 新增 [AppState.swift](/Users/gacu/Documents/Codex/AstroTransitMac/Sources/TransitStudio/AppState.swift)
- 最终实现不是文档里最初那种“纯 `@AppStorage` 包装类”，而是进一步收敛成共享 `ObservableObject`
- 由 [TransitStudioApp.swift](/Users/gacu/Documents/Codex/AstroTransitMac/Sources/TransitStudio/TransitStudioApp.swift) 注入 `environmentObject`

#### 05-P2 CalculationViewModel

- 新增 [CalculationViewModel.swift](/Users/gacu/Documents/Codex/AstroTransitMac/Sources/TransitStudio/CalculationViewModel.swift)
- 提取内容包括：
  - run state
  - progress
  - error
  - 所有结果对象
  - rectify 中间状态
  - 各结果 pane tab 选择

#### 05-P3 AIAnalysisViewModel

- 新增 [AIAnalysisViewModel.swift](/Users/gacu/Documents/Codex/AstroTransitMac/Sources/TransitStudio/AIAnalysisViewModel.swift)
- 提取内容包括：
  - `isAnalyzing`
  - moment/scan/classical/horary 文本与 reasoning
  - modern 各子模式分析桶

### 关键偏差/补充

- 为修复 review 发现的问题，`AppState` 已进一步改造成实时共享状态源
- [AppSettingsView.swift](/Users/gacu/Documents/Codex/AstroTransitMac/Sources/TransitStudio/AppSettingsView.swift)、[AIAnalysisView.swift](/Users/gacu/Documents/Codex/AstroTransitMac/Sources/TransitStudio/AIAnalysisView.swift)、[ContentView.swift](/Users/gacu/Documents/Codex/AstroTransitMac/Sources/TransitStudio/ContentView.swift) 现在都走同一份 `AppState`

---

## 06 Vedic Views

### 已做

- 新增或重构：
  - [VedicPanchangaView.swift](/Users/gacu/Documents/Codex/AstroTransitMac/Sources/TransitStudio/VedicPanchangaView.swift)
  - [VedicDivisionalChartView.swift](/Users/gacu/Documents/Codex/AstroTransitMac/Sources/TransitStudio/VedicDivisionalChartView.swift)
  - [VedicJaiminiView.swift](/Users/gacu/Documents/Codex/AstroTransitMac/Sources/TransitStudio/VedicJaiminiView.swift)
  - [VedicAshtakavargaView.swift](/Users/gacu/Documents/Codex/AstroTransitMac/Sources/TransitStudio/VedicAshtakavargaView.swift)
  - [VedicRelationshipsView.swift](/Users/gacu/Documents/Codex/AstroTransitMac/Sources/TransitStudio/VedicRelationshipsView.swift)
  - [VedicMiscDataViews.swift](/Users/gacu/Documents/Codex/AstroTransitMac/Sources/TransitStudio/VedicMiscDataViews.swift)
- 在 [VedicResultViews.swift](/Users/gacu/Documents/Codex/AstroTransitMac/Sources/TransitStudio/VedicResultViews.swift) 内增强：
  - `VedicOverviewView`
  - `VedicNavamsaView`
  - `VedicDasaContainerView`
  - `VedicDasaTimelineView`

### 已接入的 tab

- `panchanga`
- `dasa`
- `shadbala`
- `yoga`
- `navamsa`
- `varga`
- `jaimini`
- `ashtakavarga`
- `relationships`
- `moon_chart`
- `bhava`
- `upagrahas`
- `special_lagnas`

### 关键修复

- `navamsa` tab 不再空白
- 多数 Vedic 子页已按 09 文档改为 `Grid` / `Table` / `EmptyStateView`

### 剩余缺口

- 仍有部分旧 Vedic 视图（例如若干旧表/列表）没有完全统一到 09 的三层字体规则

---

## 07 Classical Fields

### 已做

- 在 [ClassicalResultViews.swift](/Users/gacu/Documents/Codex/AstroTransitMac/Sources/TransitStudio/ClassicalResultViews.swift) 的 `ClassicalTimingView` 顶部插入：
  - `birthdayTransitionCard(_:)`
  - `activatedLordCard(_:)`

### 当前展示内容

- `birthday_transition`
  - note
  - profection age/start
  - current/next solar return
- `activated_lord_focus`
  - lord name
  - natal score
  - natal condition
  - natal house
  - return title / exact local
  - keywords

### 额外视觉收口

- 两张卡片已部分按模块 09 改用 `Grid` / `TS.Font` / `TS.SemanticColor`

---

## 08 AI Analysis Cleanup

### 已做

- 重构 [AIAnalysisView.swift](/Users/gacu/Documents/Codex/AstroTransitMac/Sources/TransitStudio/AIAnalysisView.swift)
- 标题行从“标题 + 多个配置控件”收敛为：
  - 分析操作标题
  - 复制按钮
  - 生成按钮
- 配置项折叠到 `DisclosureGroup("AI 设置")`
  - 模型
  - 提示词
  - 备注

### 同步完成

- AI 面板已改为读取共享 `AppState`
- `ContentView+AI.swift` 继续负责 streaming 分析逻辑

### 结果

- UI 更干净
- AI 设置、设置页、真正发请求时读取的是同一份实时配置

---

## 09 Visual Design Spec

### 已应用的内容

- 在主要新/改页面采用了：
  - `TS.Font.pageTitle / sectionTitle / body / label / detail / mono / monoSmall`
  - `TS.Spacing / TS.Padding / TS.Radius`
  - `TS.SemanticColor`
- 空状态已大范围收敛为 [EmptyStateView](/Users/gacu/Documents/Codex/AstroTransitMac/Sources/TransitStudio/ResultUtilityViews.swift)
- 新增/重构的 Vedic 页面大多已按模板改写：
  - `Panchanga`：混合内容 + 键值区块
  - `DivisionalChart`：picker + `Table`
  - `Jaimini`：`Grid` + `Table`
  - `Ashtakavarga`：数字矩阵
  - `Relationships`：segmented + `Table`
  - `Derived/Misc`：`Table`
- 主框架层已做额外收口：
  - [AppNavigationRail.swift](/Users/gacu/Documents/Codex/AstroTransitMac/Sources/TransitStudio/AppNavigationRail.swift)
  - [ContentView+SidebarColumn.swift](/Users/gacu/Documents/Codex/AstroTransitMac/Sources/TransitStudio/ContentView+SidebarColumn.swift)
  - [ContentView+SidebarSections.swift](/Users/gacu/Documents/Codex/AstroTransitMac/Sources/TransitStudio/ContentView+SidebarSections.swift)
  - [ContentView+ResultsPanes.swift](/Users/gacu/Documents/Codex/AstroTransitMac/Sources/TransitStudio/ContentView+ResultsPanes.swift)

### 明确未完成

- 09 规范还没有“全应用 100% 扫平”
- 目前更接近：
  - 新增/重构区域：大部分完成
  - 老的现代/古典结果表：部分完成
  - 一些旧控件/输入区：仍保留旧风格

### 对下一位接手者的建议

如果继续做 09，优先顺序建议是：

1. `ContentView+TargetControls.swift`
2. `ContentView+ConfigTemplates.swift`
3. `ContentView+SidebarSections.swift` 内所有老 Grid / TextEditor 区块
4. `ModernResultViews.swift` 内旧表格和 pane 标题
5. `ClassicalResultViews.swift` 内剩余未 token 化段落

---

## 验证记录

本轮确认跑过：

```bash
swift build
swift test
./package_app.sh
```

结果：

- `swift build` 通过
- `swift test` 通过（10 tests）
- 已覆盖安装到 `/Applications/TransitStudio.app`
- 当前安装版本：`1.1.2 (21)`

---

## 交接结论

如果只问“00-09 做到了什么程度”，结论是：

- **01-08：已完成并接线**
- **09：已明显推进，但还没全仓统一**
- **当前最重要的剩余工作不是补功能，而是继续把老页面样式收敛到 09**
